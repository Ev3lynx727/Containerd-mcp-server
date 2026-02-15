#!/bin/bash

# Rebuild and Deploy Script for Containerd MCP Server
# Uses GHCR pre-built images - no local build required

set -e

echo "=== Containerd MCP Server Rebuild and Deploy ==="

check_container() {
    if docker ps --format 'table {{.Names}}' | grep -q "^$1$"; then
        echo "✓ $1 is running"
        return 0
    else
        echo "✗ $1 is not running"
        return 1
    fi
}

check_mcp_server() {
    local server_name=$1
    local port=$2
    local retries=3
    while [ $retries -gt 0 ]; do
        if timeout 2 bash -c "echo > /dev/tcp/localhost/$port" 2>/dev/null; then
            echo "✓ $server_name accessible on port $port"
            return 0
        fi
        retries=$((retries - 1))
        sleep 2
    done
    echo "✗ $server_name not accessible on port $port"
    return 1
}

# Stop and remove existing containers
echo "Stopping existing containers..."
docker-compose down --remove-orphans 2>/dev/null || true

# Remove any orphaned containers
echo "Removing orphaned containers..."
docker rm -f mcp-server-container mcp-stdio-proxy-container 2>/dev/null || true

# Pull latest GHCR images
echo "Pulling latest GHCR images..."
docker pull ghcr.io/ev3lynx727/containerd-mcp-server:master && echo "✓ Main image pulled" || echo "✗ Main image pull failed"
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-stdio-proxy:latest && echo "✓ STDIO proxy image pulled" || echo "✗ STDIO proxy image pull failed"

# Start containers
echo "Starting containers..."
docker-compose up -d

# Wait for services to be ready
echo "Waiting for services to start..."
sleep 15

# Check container status
echo ""
echo "=== Container Status ==="
check_container "mcp-server-container"
check_container "mcp-stdio-proxy-container"

# Test services
echo ""
echo "=== Service Accessibility ==="
check_mcp_server "MCP Everything" "3001"
check_mcp_server "Playwright" "3002"
check_mcp_server "REST API Tester" "3003"
check_mcp_server "Fabric MCP" "3004"

echo ""
echo "=== Deployment Complete ==="
echo "✓ Using GHCR pre-built images"
echo ""
echo "Access points:"
echo "  - MCP Everything: http://localhost:3001"
echo "  - Playwright: http://localhost:3002"
echo "  - REST API Tester: http://localhost:3003"
echo "  - Fabric MCP: http://localhost:3004"
