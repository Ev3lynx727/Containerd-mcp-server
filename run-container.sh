#!/bin/bash

# Build and run MCP Server container using docker-compose
# Uses pre-built GHCR images - no local build required

echo "=== Containerd MCP Server Deployment ==="

# Pull GHCR images
echo "Pulling latest GHCR images..."
echo "Pulling main MCP server image..."
docker pull ghcr.io/ev3lynx727/containerd-mcp-server:latest || echo "Warning: Could not pull main image"

echo "Pulling Netdata proxy image..."
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-proxy:latest || echo "Warning: Could not pull proxy image"

echo "Pulling STDIO proxy image..."
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-stdio-proxy:latest || echo "Warning: Could not pull stdio-proxy image"

echo "GHCR images ready. Starting containers..."
docker compose up -d

echo ""
echo "MCP Server container is running with volumes configured."
echo " - Docker socket mounted (read-only)"
echo " - VS Code server data shared"
echo " - .env mounted (read-only)"
echo " - Named volume 'mcp-data' for shared data"
echo ""
echo "Access points:"
echo " - MCP servers: localhost:3001-3003"
echo " - MCP Inspector: localhost:6274"
echo " - Netdata: localhost:19999"

# Auto-update OpenCode config
CONFIG_FILE="$HOME/.config/opencode/opencode.jsonc"
if [ -f "$CONFIG_FILE" ]; then
    echo ""
    echo "Updating OpenCode config with Netdata MCP server..."
    if ! grep -q '"netdata"' "$CONFIG_FILE"; then
        sed -i '/"mcp": {/a\
    "netdata": {\
      "type": "remote",\
      "url": "http://localhost:19999/sse",\
      "enabled": true\
    },' "$CONFIG_FILE"
        echo "Added Netdata to OpenCode config."
    else
        echo "Netdata already configured in OpenCode."
    fi
else
    echo "OpenCode config not found at $CONFIG_FILE. Please create it manually."
fi