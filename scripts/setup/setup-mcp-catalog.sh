#!/bin/bash

# setup-mcp-catalog.sh - Enable MCP servers from Docker MCP Catalog
# This script enables MCP servers in the MCP Gateway and configures OpenCode
# Run this after setup_mcp_gateway.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
GATEWAY_PORT=8090
GATEWAY_URL="http://localhost:${GATEWAY_PORT}/mcp"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.jsonc"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if MCP Gateway is running
check_gateway() {
    log_info "Checking MCP Gateway..."

    if ! ps aux | grep -q "[d]ocker-mcp.*gateway"; then
        log_error "MCP Gateway is not running!"
        log_error "Please run ./setup_mcp_gateway.sh first."
        exit 1
    fi

    # Check gateway port
    if ! netstat -tlnp 2>/dev/null | grep -q ":${GATEWAY_PORT}"; then
        log_error "MCP Gateway port ${GATEWAY_PORT} is not accessible!"
        exit 1
    fi

    log_success "MCP Gateway is running on port ${GATEWAY_PORT}"
}

# Get current gateway token
get_gateway_token() {
    local gateway_log="gateway-catalog.log"
    if [ -f "$gateway_log" ]; then
        grep "Bearer" "$gateway_log" | tail -1 | awk '{print $NF}'
    else
        echo ""
    fi
}

# Configure mcp-registry
configure_registry() {
    log_info "Configuring MCP Registry..."
    
    local registry_file="$HOME/.docker/mcp/registry.yaml"
    
    # Enable SQLite in registry only (filesystem and git run in separate containers)
    docker mcp server enable SQLite 2>/dev/null || true
    docker mcp server disable filesystem 2>/dev/null || true
    docker mcp server disable git 2>/dev/null || true
    
    # Update registry.yaml - only SQLite (filesystem/git already in mcp-server-sequential-container)
    cat > "$registry_file" << 'EOF'
registry:
  SQLite:
    ref: ""
EOF
    
    log_success "MCP Registry configured (SQLite only - filesystem/git in separate container)"
}

# Configure SQLite persistent volume
configure_sqlite_volume() {
    log_info "Configuring SQLite persistent storage..."
    
    local SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local MCP_DATA_DIR="${SCRIPT_DIR}/mcp-data/SQLite"
    local config_file="$HOME/.docker/mcp/config.yaml"
    
    # Create directory if not exists
    mkdir -p "$MCP_DATA_DIR"
    
    log_info "SQLite data directory: $MCP_DATA_DIR"
    
    # Write config for persistent storage
    cat > "$config_file" << EOF
sqlite:
  volumes:
    - ${MCP_DATA_DIR}:/data
EOF
    
    log_success "SQLite volume configured: $MCP_DATA_DIR"
}

# Update OpenCode configuration
update_opencode_config() {
    log_info "Updating OpenCode configuration..."
    
    # Check if config exists
    if [ ! -f "$OPENCODE_CONFIG" ]; then
        log_warning "OpenCode config not found at $OPENCODE_CONFIG"
        log_info "Creating default config..."
        mkdir -p "$(dirname "$OPENCODE_CONFIG")"
        cat > "$OPENCODE_CONFIG" << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {}
}
EOF
    fi
    
    # Get gateway token
    local token=$(get_gateway_token)
    
    # Backup config
    cp "$OPENCODE_CONFIG" "${OPENCODE_CONFIG}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Check if mcp-gateway already exists
    if grep -q '"mcp-gateway"' "$OPENCODE_CONFIG"; then
        log_info "mcp-gateway already exists in config, updating token..."
        
        # Use Python for safer JSON update
        python3 << PYTHON_EOF
import json

token = "$token"

with open('$OPENCODE_CONFIG', 'r') as f:
    config = json.load(f)

if 'mcp' in config and 'mcp-gateway' in config['mcp']:
    config['mcp']['mcp-gateway']['headers'] = {'Authorization': 'Bearer ' + token}

with open('$OPENCODE_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
PYTHON_EOF
        log_success "OpenCode config updated with new token"
    else
        log_info "Adding mcp-gateway to config..."
        
        python3 << PYTHON_EOF
import json

token = "$token"

with open('$OPENCODE_CONFIG', 'r') as f:
    config = json.load(f)

if 'mcp' not in config:
    config['mcp'] = {}

config['mcp']['mcp-gateway'] = {
    'type': 'remote',
    'url': 'http://localhost:8090/mcp',
    'headers': {
        'Authorization': 'Bearer ' + token
    },
    'enabled': True,
    'timeout': 60000
}

with open('$OPENCODE_CONFIG', 'w') as f:
    json.dump(config, f, indent=2)
PYTHON_EOF
        log_success "OpenCode config updated"
    fi
    
    log_success "OpenCode config updated: $OPENCODE_CONFIG"
}

# Restart gateway to apply changes
restart_gateway() {
    log_info "Restarting MCP Gateway..."

    # Kill existing gateway
    pkill -f "docker-mcp.*gateway" 2>/dev/null || true
    sleep 2

    # Start gateway in background
    docker mcp gateway run --port ${GATEWAY_PORT} --transport streaming > gateway-catalog.log 2>&1 &
    sleep 8

    # Check if running
    if ps aux | grep -q "[d]ocker-mcp.*gateway"; then
        log_success "MCP Gateway restarted successfully"
    else
        log_error "Failed to restart MCP Gateway"
        log_info "Check gateway-catalog.log for details"
        exit 1
    fi
    
    # Extract new token
    sleep 2
    local new_token=$(get_gateway_token)
    if [ -n "$new_token" ]; then
        log_info "Gateway token: Bearer ${new_token}"
    fi
}

# Show enabled servers
show_status() {
    echo ""
    log_info "Current enabled servers:"
    docker mcp server ls 2>/dev/null | grep -v "Tip:" | grep -v "Warning:" || true
    
    echo ""
    echo "Access Points:"
    echo "  - Gateway URL: $GATEWAY_URL"
    echo "  - OpenCode Config: $OPENCODE_CONFIG"
}

# Main
main() {
    echo "========================================"
    echo " MCP Catalog Server Setup"
    echo "========================================"
    echo ""

    check_gateway
    
    # Step 1: Configure registry
    configure_registry
    
    # Step 2: Configure SQLite volume
    configure_sqlite_volume
    
    # Step 3: Restart gateway
    restart_gateway
    
    # Step 4: Update OpenCode config
    update_opencode_config

    echo ""
    log_success "=== MCP Catalog Setup Complete ==="
    echo ""
    echo "Enabled servers:"
    echo "  - SQLite (Database) - 25 tools"
    echo ""
    echo "Note: filesystem and git run in mcp-server-sequential-container"
    echo ""
    
    show_status
    
    echo ""
    log_info "Restart OpenCode to use the new MCP Gateway configuration"
}

main "$@"
