#!/bin/bash

# Build and run MCP Server container using docker-compose

echo "Building and running MCP Server container with docker compose..."
docker compose up -d --build

echo "MCP Server container is running with volumes configured."
echo " - Docker socket mounted (read-only)"
echo " - VS Code server data shared"
echo " - .env mounted (read-only)"
echo " - Named volume 'mcp-data' for shared data"
echo "Access MCP servers on localhost:3000-3005 and MCP Inspector on localhost:6274"
echo " - MCP Inspector available for testing and debugging"

# Auto-update OpenCode config
CONFIG_FILE="$HOME/.config/opencode/opencode.jsonc"
if [ -f "$CONFIG_FILE" ]; then
    echo "Updating OpenCode config with Netdata MCP server..."
    # Check if netdata is already configured
    if ! grep -q '"netdata"' "$CONFIG_FILE"; then
        # Use sed to add netdata config before the closing brace of mcp object
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