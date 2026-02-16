#!/bin/bash

set -e

echo "Starting MCP servers..."

echo "Pre-caching npm packages for server-everything..."
npx -y @modelcontextprotocol/server-everything --help > /dev/null 2>&1 || true
echo "Pre-cache complete"

echo "Starting server-everything in SSE mode (port 3001)..."
npx -y @modelcontextprotocol/server-everything sse &
SERVER_EVERYTHING_PID=$!
echo "server-everything started PID $SERVER_EVERYTHING_PID"

sleep 2

echo "Starting Playwright MCP (port 3002)..."
npx -y @playwright/mcp --port 3002 --host 0.0.0.0 &
PLAYWRIGHT_PID=$!
echo "playwright started PID $PLAYWRIGHT_PID"

echo "Starting REST API Tester (port 3003)..."
npx -y dkmaker-mcp-rest-api --port 3003 --host 0.0.0.0 &
REST_API_PID=$!
echo "rest_api_tester started PID $REST_API_PID"

echo "Starting MarkdownLint MCP (port 3005)..."
if [ -f "/app/markdownlint-mcp-server.js" ]; then
    if [ -d "/app/node_modules" ]; then
        export NODE_PATH=/app/node_modules
    fi
    node /app/markdownlint-mcp-server.js --port 3005 &
    MARKDOWN_PID=$!
    echo "markdownlint started PID $MARKDOWN_PID"
else
    echo "WARNING: /app/markdownlint-mcp-server.js not found"
fi

cleanup() {
    echo "Shutting down MCP servers..."
    kill $SERVER_EVERYTHING_PID 2>/dev/null || true
    kill $PLAYWRIGHT_PID 2>/dev/null || true
    kill $REST_API_PID 2>/dev/null || true
    kill $MARKDOWN_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

echo "All MCP servers started. Container is running."
tail -f /dev/null
