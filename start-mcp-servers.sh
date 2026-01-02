#!/bin/bash

# Start MCP servers in HTTP mode for remote access

echo "Starting MCP servers..."

# Pre-warm server-everything to avoid first-connection latency
echo "Pre-warming server-everything..."
timeout 5 npx @modelcontextprotocol/server-everything sse > /dev/null 2>&1 &
sleep 2
kill %1 2>/dev/null || true
echo "Pre-warm complete"

# Start server-everything in SSE mode (default port 3001)
npx @modelcontextprotocol/server-everything sse &
echo "server-everything started (SSE on port 3001) PID $!"

echo "MCP servers started. Container is running."
echo "Note: Playwright and REST API servers are handled by mcp-stdio-proxy"
# Keep the container alive
tail -f /dev/null