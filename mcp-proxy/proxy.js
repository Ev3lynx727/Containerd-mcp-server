#!/usr/bin/env node

const { spawn } = require('child_process');
const express = require('express');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());

const MAX_SESSIONS = 20;
const SESSION_TIMEOUT = 300000;
const CLEANUP_INTERVAL = 60000;

const sessions = new Map();

function killProcess(session) {
  if (session && session.process && !session.process.killed) {
    try {
      session.process.stdin.end();
    } catch (e) {}
    setTimeout(() => {
      if (!session.process.killed) {
        session.process.kill('SIGTERM');
      }
    }, 1000);
  }
}

function createMCPSession(sessionId, command, args, env = {}) {
  if (sessions.size >= MAX_SESSIONS) {
    const oldestKey = sessions.keys().next().value;
    console.log(`Max sessions reached (${MAX_SESSIONS}), cleaning up oldest: ${oldestKey}`);
    const oldSession = sessions.get(oldestKey);
    if (oldSession) {
      killProcess(oldSession);
      sessions.delete(oldestKey);
    }
  }

  const child = spawn(command, args, {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: { ...process.env, NODE_OPTIONS: '--max-old-space-size=512', ...env }
  });

  const session = {
    process: child,
    lastActivity: Date.now(),
    buffer: ''
  };

  child.on('exit', (code) => {
    console.log(`Process exited for session ${sessionId}, code: ${code}`);
    sessions.delete(sessionId);
  });

  child.on('error', (err) => {
    console.error(`Process error for session ${sessionId}: ${err.message}`);
    sessions.delete(sessionId);
  });

  return session;
}

function setupSessionHandler(session, res, sessionId) {
  session.process.stdout.on('data', (data) => {
    session.buffer += data.toString();
    
    let newlineIndex;
    while ((newlineIndex = session.buffer.indexOf('\n')) !== -1) {
      const line = session.buffer.slice(0, newlineIndex);
      session.buffer = session.buffer.slice(newlineIndex + 1);
      
      if (line.trim()) {
        try {
          const message = JSON.parse(line);
          if (!res.headersSent) {
            res.json(message);
            res.end();
          }
        } catch (e) {
        }
      }
    }
  });

  session.process.stderr.on('data', (data) => {
    console.error(`[${sessionId}] stderr: ${data}`);
  });

  session.process.stdin.on('error', (err) => {
    console.error(`[${sessionId}] stdin error: ${err.message}`);
  });
}

const mcpServers = {
  'shellcheck': {
    command: 'python3',
    args: ['/app/shellcheck-mcp-server.py']
  },
  'ruff': {
    command: 'python3',
    args: ['/app/ruff-mcp-wrapper.py']
  },
  'git': {
    command: 'python3',
    args: ['-m', 'mcp_server_git', '--repository', '/home/ev3lynx']
  },
  'fetch': {
    command: 'python3',
    args: ['-m', 'mcp_server_fetch']
  }
};

Object.keys(mcpServers).forEach(serverName => {
  app.post(`/${serverName}`, (req, res) => {
    const sessionId = req.headers['session-id'] || 'default';
    const key = `${serverName}-${sessionId}`;

    let session = sessions.get(key);

    if (!session || !session.process || session.process.killed) {
      console.log(`Starting ${serverName} server for session ${sessionId}`);
      const serverConfig = mcpServers[serverName];
      session = createMCPSession(key, serverConfig.command, serverConfig.args);
      setupSessionHandler(session, res, key);
      sessions.set(key, session);
    }

    session.lastActivity = Date.now();

    if (req.body) {
      try {
        session.process.stdin.write(JSON.stringify(req.body) + '\n');
      } catch (e) {
        if (!res.headersSent) {
          res.status(500).json({ error: e.message });
        }
      }
    }

    res.on('close', () => {
      session.lastActivity = Date.now();
    });
  });
});

app.post('/playwright', (req, res) => {
  const sessionId = req.headers['session-id'] || 'default';
  const key = `playwright-${sessionId}`;

  let session = sessions.get(key);

  if (!session || !session.process || session.process.killed) {
    console.log(`Starting Playwright server for session ${sessionId}`);
    session = createMCPSession(key, 'npx', ['-y', '@playwright/mcp']);
    setupSessionHandler(session, res, key);
    sessions.set(key, session);
  }

  session.lastActivity = Date.now();

  if (req.body) {
    try {
      session.process.stdin.write(JSON.stringify(req.body) + '\n');
    } catch (e) {
      if (!res.headersSent) {
        res.status(500).json({ error: e.message });
      }
    }
  }

  res.on('close', () => {
    session.lastActivity = Date.now();
  });
});

app.post('/rest-api', (req, res) => {
  const sessionId = req.headers['session-id'] || 'default';
  const key = `rest-${sessionId}`;

  let session = sessions.get(key);

  if (!session || !session.process || session.process.killed) {
    console.log(`Starting REST API server for session ${sessionId}`);
    session = createMCPSession(key, 'npx', ['-y', 'dkmaker-mcp-rest-api']);
    setupSessionHandler(session, res, key);
    sessions.set(key, session);
  }

  session.lastActivity = Date.now();

  if (req.body) {
    try {
      session.process.stdin.write(JSON.stringify(req.body) + '\n');
    } catch (e) {
      if (!res.headersSent) {
        res.status(500).json({ error: e.message });
      }
    }
  }

  res.on('close', () => {
    session.lastActivity = Date.now();
  });
});

app.get('/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    sessions: sessions.size,
    maxSessions: MAX_SESSIONS,
    servers: Object.keys(mcpServers)
  });
});

app.post('/cleanup', (req, res) => {
  const now = Date.now();
  let cleaned = 0;
  
  for (const [sessionId, session] of sessions.entries()) {
    if (now - session.lastActivity > SESSION_TIMEOUT) {
      console.log(`Cleaning up inactive session ${sessionId}`);
      killProcess(session);
      sessions.delete(sessionId);
      cleaned++;
    }
  }
  
  res.json({ cleaned, remaining: sessions.size });
});

setInterval(() => {
  const now = Date.now();
  
  for (const [sessionId, session] of sessions.entries()) {
    if (now - session.lastActivity > SESSION_TIMEOUT) {
      console.log(`Auto-cleaning inactive session ${sessionId}`);
      killProcess(session);
      sessions.delete(sessionId);
    }
  }
}, CLEANUP_INTERVAL);

const PORT = process.env.PORT || 3004;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`MCP STDIO Proxy listening on port ${PORT}`);
  console.log(`Max sessions: ${MAX_SESSIONS}, Session timeout: ${SESSION_TIMEOUT}ms`);
  console.log(`Available servers: ${Object.keys(mcpServers).join(', ')}`);
});
