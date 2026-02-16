#!/usr/bin/env node

import { McpServer } from '/app/node_modules/@modelcontextprotocol/sdk/dist/esm/server/mcp.js';
import { StreamableHTTPServerTransport } from '/app/node_modules/@modelcontextprotocol/sdk/dist/esm/server/streamableHttp.js';
import { createMcpExpressApp } from '/app/node_modules/@modelcontextprotocol/sdk/dist/esm/server/express.js';
import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

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

  setupRequestHandlers() {
    // Initialize is handled automatically by the Server class
  }

  async lintMarkdownFiles(args) {
    const { files, fix = false, config } = args;

    if (!files || !Array.isArray(files) || files.length === 0) {
      throw new Error('At least one file path is required');
    }

    const results = [];

    for (const filePattern of files) {
      try {
        // Expand glob patterns and find matching files
        const matchingFiles = this.findMarkdownFiles(filePattern);

        if (matchingFiles.length === 0) {
          results.push(`No markdown files found matching: ${filePattern}`);
          continue;
        }

        for (const file of matchingFiles) {
          const result = this.lintSingleFile(file, fix, config);
          results.push(result);
        }
      } catch (error) {
        results.push(`Error processing ${filePattern}: ${error.message}`);
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
      const fullPattern = path.join(directory, pattern);
      const files = this.findMarkdownFiles(fullPattern);

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

      const results = files.map(file => this.lintSingleFile(file, fix, config));

      return {
        content: [
          {
            type: 'text',
            text: `Found ${files.length} markdown files in ${directory}:\n\n${results.join('\n\n')}`,
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

  findMarkdownFiles(pattern) {
    try {
      // Use find command to locate markdown files
      const result = execSync(`find /app -name "*.md" -type f 2>/dev/null`, { encoding: 'utf8' });
      return result.trim().split('\n').filter(Boolean);
    } catch (error) {
      // Fallback to a simple glob approach
      return this.simpleGlob(pattern);
    }
  }

  simpleGlob(pattern) {
    // Simple glob implementation for markdown files
    try {
      const result = execSync(`find /app -name "*.md" -type f 2>/dev/null`, { encoding: 'utf8' });
      return result.trim().split('\n').filter(file => {
        // Simple pattern matching - could be enhanced
        return file.includes('.md');
      });
    } catch (error) {
      return [];
    }
  }

  lintSingleFile(filePath, fix = false, configPath = null) {
    try {
      // Check if file exists
      if (!fs.existsSync(filePath)) {
        return `File not found: ${filePath}`;
      }

      // Build markdownlint command
      let cmd = 'markdownlint';

      if (configPath && fs.existsSync(configPath)) {
        cmd += ` --config ${configPath}`;
      }

      if (fix) {
        cmd += ' --fix';
      }

      cmd += ` "${filePath}"`;

      // Run markdownlint
      const result = execSync(cmd, {
        encoding: 'utf8',
        timeout: 30000,
        maxBuffer: 1024 * 1024
      });

      if (result.trim()) {
        return `${filePath}:\n${result.trim()}`;
      } else {
        return `${filePath}: ✅ No issues found`;
      }

    } catch (error) {
      if (error.status === 1) {
        // markdownlint found issues (exit code 1)
        return `${filePath}:\n${error.stdout || error.stderr}`;
      } else {
        return `${filePath}: Error running markdownlint: ${error.message}`;
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

// Run the server
const server = new MarkdownLintMCPServer();
server.run().catch(console.error);