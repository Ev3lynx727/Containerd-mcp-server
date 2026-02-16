#!/bin/bash

set -e

echo "Starting MCP servers..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${LOG_DIR:-/app/logs}"
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_DIR/mcp-servers.log"
}

cleanup() {
    log "Shutting down MCP servers..."
    kill 0 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

log "Pre-caching npm packages..."
npx -y @modelcontextprotocol/server-everything --help > /dev/null 2>&1 || true
npx -y @modelcontextprotocol/server-memory --help > /dev/null 2>&1 || true
npx -y @modelcontextprotocol/server-sequential-thinking --help > /dev/null 2>&1 || true
npx -y @modelcontextprotocol/server-github --help > /dev/null 2>&1 || true
npx -y @modelcontextprotocol/server-filesystem --help > /dev/null 2>&1 || true
npx -y mcp-ripgrep --help > /dev/null 2>&1 || true
npx -y editorconfig-mcp-server --help > /dev/null 2>&1 || true
log "Pre-cache complete"

# Port allocation:
# 3001 - server-everything (SSE)
# 3002 - playwright
# 3003 - rest-api-tester  
# 3004 - mcp-proxy (stdio)
# 3005 - markdownlint
# 3006 - memory
# 3007 - sequential-thinking
# 3008 - github
# 3009 - filesystem
# 3010 - ripgrep
# 3011 - formatter/editorconfig

log "Starting server-everything (port 3001)..."
npx -y @modelcontextprotocol/server-everything sse --port 3001 --host 0.0.0.0 > "$LOG_DIR/server-everything.log" 2>&1 &
log "server-everything started PID $!"

log "Starting memory server (port 3006)..."
npx -y @modelcontextprotocol/server-memory --port 3006 --host 0.0.0.0 > "$LOG_DIR/memory.log" 2>&1 &
log "memory started PID $!"

log "Starting sequential-thinking (port 3007)..."
npx -y @modelcontextprotocol/server-sequential-thinking --port 3007 --host 0.0.0.0 > "$LOG_DIR/sequential-thinking.log" 2>&1 &
log "sequential-thinking started PID $!"

log "Starting github server (port 3008)..."
export GITHUB_PERSONAL_ACCESS_TOKEN="${GITHUB_TOKEN:-}"
npx -y @modelcontextprotocol/server-github --port 3008 --host 0.0.0.0 > "$LOG_DIR/github.log" 2>&1 &
log "github started PID $!"

log "Starting filesystem server (port 3009)..."
npx -y @modelcontextprotocol/server-filesystem /home/ev3lynx --port 3009 --host 0.0.0.0 > "$LOG_DIR/filesystem.log" 2>&1 &
log "filesystem started PID $!"

log "Starting ripgrep server (port 3010)..."
npx -y mcp-ripgrep --port 3010 --host 0.0.0.0 > "$LOG_DIR/ripgrep.log" 2>&1 &
log "ripgrep started PID $!"

log "Starting formatter/editorconfig (port 3011)..."
npx -y editorconfig-mcp-server --port 3011 --host 0.0.0.0 > "$LOG_DIR/formatter.log" 2>&1 &
log "formatter started PID $!"

log "Starting Playwright MCP (port 3002)..."
npx -y @playwright/mcp --port 3002 --host 0.0.0.0 > "$LOG_DIR/playwright.log" 2>&1 &
log "playwright started PID $!"

log "Starting REST API Tester (port 3003)..."
npx -y dkmaker-mcp-rest-api --port 3003 --host 0.0.0.0 > "$LOG_DIR/rest-api.log" 2>&1 &
log "rest_api_tester started PID $!"

log "Starting MarkdownLint MCP (port 3005)..."
if [ -f "/app/markdownlint-mcp-server.js" ]; then
    [ -d "/app/node_modules" ] && export NODE_PATH=/app/node_modules
    node /app/markdownlint-mcp-server.js --port 3005 > "$LOG_DIR/markdownlint.log" 2>&1 &
    log "markdownlint started PID $!"
fi

log "Starting mcp-proxy (port 3004)..."
if [ -f "/app/proxy.js" ]; then
    node /app/proxy.js > "$LOG_DIR/proxy.log" 2>&1 &
    log "mcp-proxy started PID $!"
fi

log "All MCP servers started. Container is running."
log "Endpoints:"
log "  3001 - server-everything"
log "  3002 - playwright"
log "  3003 - rest-api-tester"
log "  3004 - mcp-proxy"
log "  3005 - markdownlint"
log "  3006 - memory"
log "  3007 - sequential-thinking"
log "  3008 - github"
log "  3009 - filesystem"
log "  3010 - ripgrep"
log "  3011 - formatter"

tail -f /dev/null
