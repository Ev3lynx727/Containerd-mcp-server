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

# Start Playwright MCP in HTTP mode on port 3002
npx @playwright/mcp --port 3002 --host 0.0.0.0 &
echo "playwright started (HTTP on port 3002) PID $!"

# Start REST API Tester MCP on port 3003
npx dkmaker-mcp-rest-api --port 3003 --host 0.0.0.0 &
echo "rest_api_tester started (HTTP on port 3003) PID $!"

# Start Fabric MCP server on port 3011
python3 -m ms_fabric_mcp_server --port 3011 --host 0.0.0.0 &
echo "fabric_mcp started (HTTP on port 3011) PID $!"

# Start MarkdownLint MCP server (HTTP mode on port 3005)
if [ -f "/app/markdownlint-mcp-server.js" ]; then
    if [ -d "/app/node_modules" ]; then
        export NODE_PATH=/app/node_modules
        node /app/markdownlint-mcp-server.js --port 3005 &
        echo "markdownlint started (HTTP on port 3005) PID $!"
    else
        echo "WARNING: /app/node_modules not found. Skipping usage of NODE_PATH for markdownlint."
        node /app/markdownlint-mcp-server.js --port 3005 &
        echo "markdownlint started (HTTP on port 3005) PID $! (without NODE_PATH)"
    fi
else
    echo "ERROR: /app/markdownlint-mcp-server.js not found. Skipping markdownlint startup."
fi

echo "MCP servers started. Container is running."
# Keep the container alive
tail -f /dev/null
