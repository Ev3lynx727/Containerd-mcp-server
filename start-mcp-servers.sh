#!/bin/bash

# Start MCP servers in HTTP mode for remote access

echo "Starting MCP servers..."

# Start server-everything in SSE mode (default port 3001)
npx @modelcontextprotocol/server-everything sse &
echo "server-everything started (SSE on port 3001) PID $!"

# Start Playwright MCP in HTTP/SSE mode on port 3002
npx @playwright/mcp --port 3002 &
echo "playwright started (HTTP/SSE on port 3002) PID $!"

echo "MCP servers started. Container is running."
# Keep the container alive
tail -f /dev/null