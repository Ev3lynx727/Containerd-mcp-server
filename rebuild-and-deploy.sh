#!/bin/bash

# Rebuild and Deploy Script for Containerd MCP Server
# This script rebuilds containers, updates configurations, and redeploys

set -e  # Exit on any error

echo "=== Containerd MCP Server Rebuild and Deploy ==="
echo "Using GHCR pre-built images for faster deployment"

# Function to check if container is running
check_container() {
    if docker ps --format 'table {{.Names}}' | grep -q "^$1$"; then
        echo "✓ $1 is running"
        return 0
    else
        echo "✗ $1 is not running"
        return 1
    fi
}

# Stop and remove existing containers
echo "Stopping existing containers..."
docker-compose down --remove-orphans

# Remove any orphaned containers with matching names
echo "Removing orphaned containers..."
docker rm -f mcp-server-container netdata-container mcp-netdata-proxy-container mcp-inspector-container 2>/dev/null || true

# Rebuild images if needed (uncomment if Dockerfile changes)
# echo "Rebuilding images..."
# docker-compose build --no-cache

# Verify GHCR images are available
echo "Verifying GHCR images..."
docker pull ghcr.io/ev3lynx727/containerd-mcp-server:latest >/dev/null 2>&1 && echo "✓ Main image ready" || echo "⚠ Main image pull failed"
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-proxy:latest >/dev/null 2>&1 && echo "✓ Proxy image ready" || echo "⚠ Proxy image pull failed"
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-stdio-proxy:latest >/dev/null 2>&1 && echo "✓ STDIO proxy image ready" || echo "⚠ STDIO proxy image pull failed"

# Start containers
echo "Starting containers..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 10

# Check container status
echo "Checking container status..."
check_container "netdata-container"
check_container "mcp-server-container"
check_container "mcp-netdata-proxy-container"
check_container "mcp-inspector-container"

# Test Netdata access
echo "Testing Netdata access..."
if curl -f -s http://localhost:19999/api/v1/info > /dev/null; then
    echo "✓ Netdata API accessible"
else
    echo "✗ Netdata API not accessible"
fi

# Test MCP Netdata proxy
echo "Testing MCP Netdata proxy..."
if curl -f -s http://localhost:3051/health > /dev/null; then
    echo "✓ MCP Netdata proxy accessible"
else
    echo "✗ MCP Netdata proxy not accessible"
fi

# Test MCP Inspector access
echo "Testing MCP Inspector access..."
if curl -f -s http://localhost:6274 > /dev/null; then
    echo "✓ MCP Inspector accessible"
else
    echo "✗ MCP Inspector not accessible"
fi

echo "=== Deployment Complete ==="
echo "✅ Using GHCR pre-built images for optimal performance"
echo "Netdata Dashboard: http://localhost:19999"
echo "MCP Inspector: http://localhost:6274"
echo "MCP Server: Running with Netdata integration and Inspector"