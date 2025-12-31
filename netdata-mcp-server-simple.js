const express = require('express');
const app = express();
const PORT = process.env.PORT || 3051;

// Middleware
app.use(express.json());

// In-memory session storage (simple implementation)
const sessions = new Map();

// MCP Tool definitions
const TOOLS = [
  {
    name: 'get_system_info',
    description: 'Get basic system information from Netdata',
    inputSchema: {
      type: 'object',
      properties: {},
      required: []
    }
  },
  {
    name: 'get_cpu_usage',
    description: 'Get CPU usage metrics from Netdata',
    inputSchema: {
      type: 'object',
      properties: {
        timeframe: {
          type: 'string',
          description: 'Timeframe for data (e.g., "1h", "24h")',
          default: '1h'
        }
      },
      required: []
    }
  },
  {
    name: 'get_memory_usage',
    description: 'Get memory usage metrics from Netdata',
    inputSchema: {
      type: 'object',
      properties: {
        timeframe: {
          type: 'string',
          description: 'Timeframe for data (e.g., "1h", "24h")',
          default: '1h'
        }
      },
      required: []
    }
  },
  {
    name: 'get_disk_usage',
    description: 'Get disk usage metrics from Netdata',
    inputSchema: {
      type: 'object',
      properties: {
        timeframe: {
          type: 'string',
          description: 'Timeframe for data (e.g., "1h", "24h")',
          default: '1h'
        }
      },
      required: []
    }
  }
];

// Helper function to fetch from Netdata
async function fetchNetdata(endpoint) {
  const url = `http://localhost:19999/api/v1${endpoint}`;
  console.log(`Fetching: ${url}`);
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Netdata API error: ${response.status} ${response.statusText}`);
  }
  return await response.json();
}

// Parse timeframe to seconds
function parseTimeframe(timeframe) {
  const match = timeframe.match(/^(\d+)([smhd])$/);
  if (!match) return 3600; // default 1h

  const [, num, unit] = match;
  const multipliers = { s: 1, m: 60, h: 3600, d: 86400 };
  return parseInt(num) * multipliers[unit];
}

// Tool handlers
async function handleGetSystemInfo() {
  const info = await fetchNetdata('/info');
  return {
    content: [
      {
        type: 'text',
        text: `System Info:\n- Version: ${info.version}\n- Hostname: ${info.mirrored_hosts?.[0] || 'Unknown'}\n- OS: ${info.os_name || 'Unknown'}\n- Architecture: ${info.architecture || 'Unknown'}`
      }
    ]
  };
}

async function handleGetCpuUsage(timeframe = '1h') {
  const data = await fetchNetdata(`/data?chart=system.cpu&format=json&points=10&after=-${parseTimeframe(timeframe)}`);
  const latest = data.data[0];
  return {
    content: [
      {
        type: 'text',
        text: `CPU Usage (${timeframe}):\n- User: ${(latest[1] || 0).toFixed(2)}%\n- System: ${(latest[2] || 0).toFixed(2)}%\n- Nice: ${(latest[3] || 0).toFixed(2)}%\n- Idle: ${(latest[4] || 0).toFixed(2)}%`
      }
    ]
  };
}

async function handleGetMemoryUsage(timeframe = '1h') {
  const data = await fetchNetdata(`/data?chart=system.ram&format=json&points=10&after=-${parseTimeframe(timeframe)}`);
  const latest = data.data[0];
  return {
    content: [
      {
        type: 'text',
        text: `Memory Usage (${timeframe}):\n- Used: ${((latest[1] / latest[0]) * 100).toFixed(2)}%\n- Free: ${((latest[2] / latest[0]) * 100).toFixed(2)}%\n- Cached: ${((latest[3] / latest[0]) * 100).toFixed(2)}%`
      }
    ]
  };
}

async function handleGetDiskUsage(timeframe = '1h') {
  const data = await fetchNetdata(`/data?chart=disk_space._&format=json&points=10&after=-${parseTimeframe(timeframe)}`);
  const latest = data.data[0];
  return {
    content: [
      {
        type: 'text',
        text: `Disk Usage (${timeframe}):\n- Used: ${((latest[1] / (latest[1] + latest[2])) * 100).toFixed(2)}%\n- Available: ${latest[2] || 0} bytes`
      }
    ]
  };
}

// MCP HTTP endpoints
app.post('/mcp', async (req, res) => {
  try {
    const { jsonrpc, id, method, params } = req.body;

    console.log(`MCP Request: ${method}`, params);

    let result;

    switch (method) {
      case 'initialize':
        result = {
          protocolVersion: '2024-11-05',
          capabilities: {
            tools: {
              listChanged: false
            }
          },
          serverInfo: {
            name: 'netdata-mcp-server',
            version: '1.0.0'
          }
        };
        break;

      case 'tools/list':
        result = {
          tools: TOOLS
        };
        break;

      case 'tools/call':
        const { name, arguments: args = {} } = params;
        switch (name) {
          case 'get_system_info':
            result = await handleGetSystemInfo();
            break;
          case 'get_cpu_usage':
            result = await handleGetCpuUsage(args.timeframe);
            break;
          case 'get_memory_usage':
            result = await handleGetMemoryUsage(args.timeframe);
            break;
          case 'get_disk_usage':
            result = await handleGetDiskUsage(args.timeframe);
            break;
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
        break;

      default:
        throw new Error(`Unknown method: ${method}`);
    }

    res.json({
      jsonrpc: '2.0',
      id,
      result
    });

  } catch (error) {
    console.error('MCP Error:', error);
    res.status(500).json({
      jsonrpc: '2.0',
      id: req.body.id,
      error: {
        code: -32603,
        message: error.message
      }
    });
  }
});

// SSE endpoint for streaming (basic implementation)
app.get('/sse', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');

  // Send initial connection event
  res.write('data: {"type": "connection", "data": "connected"}\n\n');

  // Keep connection alive
  const keepAlive = setInterval(() => {
    res.write(': keepalive\n\n');
  }, 30000);

  req.on('close', () => {
    clearInterval(keepAlive);
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'netdata-mcp-server' });
});

app.listen(PORT, () => {
  console.log(`Netdata MCP Server listening on port ${PORT}`);
  console.log(`HTTP endpoint: http://localhost:${PORT}/mcp`);
  console.log(`SSE endpoint: http://localhost:${PORT}/sse`);
});