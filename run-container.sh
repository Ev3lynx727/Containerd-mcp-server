#!/bin/bash

# Build and run MCP Server container using docker-compose

echo "Building and running MCP Server container with docker compose..."
docker compose up -d --build

echo "MCP Server container is running with volumes configured."
echo " - Docker socket mounted (read-only)"
echo " - VS Code server data shared"
echo " - .env mounted (read-only)"
echo " - Named volume 'mcp-data' for shared data"
echo "Access MCP servers on localhost:3000-3005"