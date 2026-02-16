#!/usr/bin/env node

import { McpServer } from '/app/node_modules/@modelcontextprotocol/sdk/dist/esm/server/mcp.js';
import { StreamableHTTPServerTransport } from '/app/node_modules/@modelcontextprotocol/sdk/dist/esm/server/streamableHttp.js';
import { createMcpExpressApp } from '/app/node_modules/@modelcontextprotocol/sdk/dist/esm/server/express.js';
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const CACHE_TTL = 60000;
const fileCache = new Map();

function getCachedFiles(directory) {
  const now = Date.now();
  const cached = fileCache.get(directory);
  
  if (cached && now - cached.timestamp < CACHE_TTL) {
    return cached.files;
  }
  
  try {
    const result = execSync(`find "${directory}" -name "*.md" -type f 2>/dev/null`, {
      encoding: 'utf8',
      timeout: 10000,
      maxBuffer: 1024 * 1024
    });
    const files = result.trim().split('\n').filter(Boolean);
    
    fileCache.set(directory, { files, timestamp: now });
    return files;
  } catch (error) {
    return [];
  }
}

function clearCache() {
  fileCache.clear();
}

class MarkdownLintMCPServer {
  constructor() {
    this.server = new McpServer(
      {
        name: 'markdownlint-mcp-server',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
  }

  setupToolHandlers() {
    this.server.registerTool('lint_markdown', {
      description: 'Lint markdown files for formatting issues and optionally fix them',
      inputSchema: {
        type: 'object',
        properties: {
          files: {
            type: 'array',
            items: { type: 'string' },
            description: 'Array of markdown file paths to lint (supports glob patterns)',
          },
          fix: {
            type: 'boolean',
            description: 'Automatically fix linting issues when possible',
            default: false,
          },
          config: {
            type: 'string',
            description: 'Path to custom markdownlint configuration file',
          },
          directory: {
            type: 'string',
            description: 'Directory to scan for markdown files (if no files specified)',
            default: '/app',
          },
        },
        required: ['files'],
      },
    }, async (args) => {
      try {
        return await this.lintMarkdownFiles(args);
      } catch (error) {
        return {
          content: [{ type: 'text', text: `Error: ${error.message}` }],
          isError: true,
        };
      }
    });

    this.server.registerTool('lint_markdown_directory', {
      description: 'Lint all markdown files in a directory recursively',
      inputSchema: {
        type: 'object',
        properties: {
          directory: {
            type: 'string',
            description: 'Directory to scan for markdown files',
            default: '/app',
          },
          fix: {
            type: 'boolean',
            description: 'Automatically fix linting issues when possible',
            default: false,
          },
          config: {
            type: 'string',
            description: 'Path to custom markdownlint configuration file',
          },
          pattern: {
            type: 'string',
            description: 'File pattern to match (default: **/*.md)',
            default: '**/*.md',
          },
        },
      },
    }, async (args) => {
      try {
        return await this.lintMarkdownDirectory(args);
      } catch (error) {
        return {
          content: [{ type: 'text', text: `Error: ${error.message}` }],
          isError: true,
        };
      }
    });
  }

  async lintMarkdownFiles(args) {
    const { files, fix = false, config } = args;

    if (!files || !Array.isArray(files) || files.length === 0) {
      throw new Error('At least one file path is required');
    }

    const results = [];

    for (const filePattern of files) {
      const matchingFiles = this.filterByPattern(filePattern);

      if (matchingFiles.length === 0) {
        results.push(`No markdown files found matching: ${filePattern}`);
        continue;
      }

      for (const file of matchingFiles) {
        const result = this.lintSingleFile(file, fix, config);
        results.push(result);
      }
    }

    return {
      content: [
        {
          type: 'text',
          text: results.join('\n\n'),
        },
      ],
    };
  }

  async lintMarkdownDirectory(args) {
    const { directory = '/app', fix = false, config, pattern = '**/*.md' } = args;

    try {
      const files = this.filterByPattern(pattern, directory);

      if (files.length === 0) {
        return {
          content: [
            {
              type: 'text',
              text: `No markdown files found in ${directory} matching pattern ${pattern}`,
            },
          ],
        };
      }

      const results = files.slice(0, 100).map(file => this.lintSingleFile(file, fix, config));
      const total = files.length;
      const shown = results.length;

      return {
        content: [
          {
            type: 'text',
            text: `Found ${total} markdown files in ${directory} (showing first ${shown}):\n\n${results.join('\n\n')}`,
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: 'text',
            text: `Error scanning directory ${directory}: ${error.message}`,
          },
        ],
        isError: true,
      };
    }
  }

  filterByPattern(pattern, directory = '/app') {
    const files = getCachedFiles(directory);
    
    if (pattern.includes('*')) {
      const regex = this.globToRegex(pattern.replace(/\\/g, ''));
      return files.filter(file => regex.test(path.basename(file)));
    }
    
    return files.includes(pattern) ? [pattern] : [];
  }

  globToRegex(glob) {
    const escaped = glob
      .replace(/[.+^${}()|[\]\\]/g, '\\$&')
      .replace(/\*/g, '.*')
      .replace(/\?/g, '.');
    return new RegExp(`^${escaped}$`, 'i');
  }

  lintSingleFile(filePath, fix = false, configPath = null) {
    try {
      if (!fs.existsSync(filePath)) {
        return `File not found: ${filePath}`;
      }

      let cmd = 'markdownlint';

      if (configPath && fs.existsSync(configPath)) {
        cmd += ` --config ${configPath}`;
      }

      if (fix) {
        cmd += ' --fix';
      }

      cmd += ` "${filePath}"`;

      const result = execSync(cmd, {
        encoding: 'utf8',
        timeout: 30000,
        maxBuffer: 1024 * 1024
      });

      if (result.trim()) {
        return `${filePath}:\n${result.trim()}`;
      } else {
        return `${filePath}: No issues found`;
      }

    } catch (error) {
      if (error.status === 1) {
        return `${filePath}:\n${error.stdout || error.stderr}`;
      } else {
        return `${filePath}: Error: ${error.message}`;
      }
    }
  }

  async run() {
    const args = process.argv.slice(2);
    const portArgIndex = args.indexOf('--port');
    const port = portArgIndex !== -1 ? parseInt(args[portArgIndex + 1], 10) : 3005;

    console.log('Starting MarkdownLint MCP server...');
    const transport = new StreamableHTTPServerTransport();
    await this.server.connect(transport);
    const app = createMcpExpressApp(this.server, transport);
    app.listen(port, () => {
      console.log(`MarkdownLint MCP server started on port ${port}`);
    });
  }
}

const server = new MarkdownLintMCPServer();
server.run().catch(console.error);
