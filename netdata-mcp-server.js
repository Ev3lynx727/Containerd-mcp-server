#!/usr/local/bin/node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { SSEServerTransport } from '@modelcontextprotocol/sdk/server/sse.js';
import { CallToolRequestSchema, ListToolsRequestSchema } from '@modelcontextprotocol/sdk/types.js';

class NetdataMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: 'netdata-mcp-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    this.setupRequestHandlers();
  }

  setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'get_system_info',
            description: 'Get basic system information from Netdata',
            inputSchema: {
              type: 'object',
              properties: {},
            },
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
                  default: '1h',
                },
              },
            },
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
                  default: '1h',
                },
              },
            },
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
                  default: '1h',
                },
              },
            },
          },
        ],
      };
    });

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'get_system_info':
            return await this.getSystemInfo();
          case 'get_cpu_usage':
            return await this.getCpuUsage(args?.timeframe || '1h');
          case 'get_memory_usage':
            return await this.getMemoryUsage(args?.timeframe || '1h');
          case 'get_disk_usage':
            return await this.getDiskUsage(args?.timeframe || '1h');
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [{ type: 'text', text: `Error: ${error.message}` }],
          isError: true,
        };
      }
    });
  }

  setupRequestHandlers() {
    // Initialize is handled automatically by the Server class
  }

  async fetchNetdata(endpoint) {
    const response = await fetch(`http://localhost:19999/api/v1${endpoint}`);
    if (!response.ok) {
      throw new Error(`Netdata API error: ${response.status} ${response.statusText}`);
    }
    return await response.json();
  }

  async getSystemInfo() {
    const info = await this.fetchNetdata('/info');
    return {
      content: [
        {
          type: 'text',
          text: `System Info:\n- Version: ${info.version}\n- Hostname: ${info.mirrored_hosts[0] || 'Unknown'}\n- OS: ${info.os_name || 'Unknown'}\n- Architecture: ${info.architecture || 'Unknown'}`,
        },
      ],
    };
  }

  async getCpuUsage(timeframe) {
    const data = await this.fetchNetdata(`/data?chart=system.cpu&format=json&points=10&after=-${this.parseTimeframe(timeframe)}`);
    const latest = data.data[0];
    return {
      content: [
        {
          type: 'text',
          text: `CPU Usage (${timeframe}):\n- User: ${latest[1]?.toFixed(2)}%\n- System: ${latest[2]?.toFixed(2)}%\n- Nice: ${latest[3]?.toFixed(2)}%\n- Idle: ${latest[4]?.toFixed(2)}%`,
        },
      ],
    };
  }

  async getMemoryUsage(timeframe) {
    const data = await this.fetchNetdata(`/data?chart=system.ram&format=json&points=10&after=-${this.parseTimeframe(timeframe)}`);
    const latest = data.data[0];
    return {
      content: [
        {
          type: 'text',
          text: `Memory Usage (${timeframe}):\n- Used: ${((latest[1] / latest[0]) * 100).toFixed(2)}%\n- Free: ${((latest[2] / latest[0]) * 100).toFixed(2)}%\n- Cached: ${((latest[3] / latest[0]) * 100).toFixed(2)}%`,
        },
      ],
    };
  }

  async getDiskUsage(timeframe) {
    const data = await this.fetchNetdata(`/data?chart=disk_space._&format=json&points=10&after=-${this.parseTimeframe(timeframe)}`);
    const latest = data.data[0];
    return {
      content: [
        {
          type: 'text',
          text: `Disk Usage (${timeframe}):\n- Used: ${((latest[1] / (latest[1] + latest[2])) * 100).toFixed(2)}%\n- Available: ${latest[2]} bytes`,
        },
      ],
    };
  }

  parseTimeframe(timeframe) {
    // Convert timeframe like "1h", "24h" to seconds
    const match = timeframe.match(/^(\d+)([smhd])$/);
    if (!match) return 3600; // default 1h

    const [, num, unit] = match;
    const multipliers = { s: 1, m: 60, h: 3600, d: 86400 };
    return parseInt(num) * multipliers[unit];
  }

  async run() {
    // Check if running in SSE mode (has port argument)
    const portIndex = process.argv.indexOf('--port');
    if (portIndex !== -1 && process.argv[portIndex + 1]) {
      const port = parseInt(process.argv[portIndex + 1]);
      console.log(`Starting Netdata MCP server on port ${port}`);
      const transport = new SSEServerTransport(port);
      await this.server.connect(transport);
      console.log('Netdata MCP server started');
    } else {
      // Default to stdio
      console.log('Starting Netdata MCP server on stdio');
      const transport = new StdioServerTransport();
      await this.server.connect(transport);
    }
  }
}

// Run the server
const server = new NetdataMCPServer();
server.run().catch(console.error);