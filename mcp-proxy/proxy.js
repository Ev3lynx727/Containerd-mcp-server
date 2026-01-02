#!/usr/bin/env node

const { spawn } = require('child_process');
const express = require('express');
const bodyParser = require('body-parser');

const app = express();
app.use(bodyParser.json());

// Store active sessions
const sessions = new Map();

// Playwright MCP server
app.post('/playwright', (req, res) => {
  const sessionId = req.headers['session-id'] || 'default';

  if (!sessions.has(sessionId)) {
    console.log(`Starting Playwright server for session ${sessionId}`);
    const child = spawn('npx', ['@playwright/mcp'], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    sessions.set(sessionId, {
      process: child,
      lastActivity: Date.now()
    });

    // Handle MCP protocol over STDIO
    let buffer = '';
    child.stdout.on('data', (data) => {
      buffer += data.toString();
      // Process MCP messages (simplified)
      if (buffer.includes('\n')) {
        try {
          const message = JSON.parse(buffer.trim());
          // Forward to HTTP response
          res.json(message);
        } catch (e) {
          // Not a complete message yet
        }
      }
    });

    child.stderr.on('data', (data) => {
      console.error(`Playwright stderr: ${data}`);
    });

    child.on('exit', () => {
      sessions.delete(sessionId);
    });
  }

  // Forward request to STDIO process
  const session = sessions.get(sessionId);
  if (session && req.body) {
    session.process.stdin.write(JSON.stringify(req.body) + '\n');
    session.lastActivity = Date.now();
  }
});

// REST API Tester MCP server
app.post('/rest-api', (req, res) => {
  const sessionId = req.headers['session-id'] || 'default';

  if (!sessions.has(`rest-${sessionId}`)) {
    console.log(`Starting REST API server for session ${sessionId}`);
    const child = spawn('npx', ['dkmaker-mcp-rest-api'], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    sessions.set(`rest-${sessionId}`, {
      process: child,
      lastActivity: Date.now()
    });

    let buffer = '';
    child.stdout.on('data', (data) => {
      buffer += data.toString();
      if (buffer.includes('\n')) {
        try {
          const message = JSON.parse(buffer.trim());
          res.json(message);
        } catch (e) {
          // Not a complete message yet
        }
      }
    });

    child.stderr.on('data', (data) => {
      console.error(`REST API stderr: ${data}`);
    });

    child.on('exit', () => {
      sessions.delete(`rest-${sessionId}`);
    });
  }

  const session = sessions.get(`rest-${sessionId}`);
  if (session && req.body) {
    session.process.stdin.write(JSON.stringify(req.body) + '\n');
    session.lastActivity = Date.now();
  }
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', sessions: sessions.size });
});

// Cleanup inactive sessions
setInterval(() => {
  const now = Date.now();
  for (const [sessionId, session] of sessions.entries()) {
    if (now - session.lastActivity > 300000) { // 5 minutes
      console.log(`Cleaning up inactive session ${sessionId}`);
      session.process.kill();
      sessions.delete(sessionId);
    }
  }
}, 60000);

app.listen(3004, '0.0.0.0', () => {
  console.log('MCP STDIO Proxy listening on port 3004');
});