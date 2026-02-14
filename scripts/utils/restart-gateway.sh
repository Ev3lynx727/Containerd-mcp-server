#!/bin/bash
#
# restart-gateway.sh - Restart MCP Gateway and auto-update Bearer token
#
# This script:
# 1. Kills any running MCP gateway
# 2. Starts a new gateway instance
# 3. Waits for it to generate a Bearer token
# 4. Extracts the token from logs
# 5. Updates opencode.jsonc with the new token
#

set -e

# Configuration
GATEWAY_PORT=8090
GATEWAY_LOG="gateway.log"
OPENCODE_CONFIG="$HOME/.config/opencode/opencode.jsonc"
TIMEOUT_SECONDS=30

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

# Function to kill existing gateway
kill_gateway() {
    log_info "Stopping existing gateway..."
    
    # Find and kill gateway processes
    if pkill -f "docker-mcp.*gateway" 2>/dev/null; then
        sleep 2
        log_success "Gateway stopped"
    else
        log_warn "No running gateway found"
    fi
}

# Function to start gateway
start_gateway() {
    log_info "Starting MCP gateway on port $GATEWAY_PORT..."
    
    # Clear old log file
    if [ -f "$GATEWAY_LOG" ]; then
        rm -f "$GATEWAY_LOG"
    fi
    
    # Start gateway in background
    nohup docker mcp gateway run --port $GATEWAY_PORT --transport streaming > "$GATEWAY_LOG" 2>&1 &
    
    log_info "Gateway started with PID $!"
}

# Function to wait for and extract Bearer token
wait_for_token() {
    log_info "Waiting for Bearer token (timeout: ${TIMEOUT_SECONDS}s)..."
    
    local start_time=$(date +%s)
    local token=""
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $TIMEOUT_SECONDS ]; then
            log_error "Timeout waiting for Bearer token"
            return 1
        fi
        
        if [ -f "$GATEWAY_LOG" ]; then
            token=$(grep -oE 'Bearer [a-zA-Z0-9]+' "$GATEWAY_LOG" | tail -1 | awk '{print $2}')
            if [ -n "$token" ]; then
                log_success "Bearer token found: $token"
                echo "$token"
                return 0
            fi
        fi
        
        sleep 1
    done
}

# Function to update opencode.jsonc
update_opencode_config() {
    local token=$1
    
    log_info "Updating opencode.jsonc..."
    
    if [ ! -f "$OPENCODE_CONFIG" ]; then
        log_error "Config file not found: $OPENCODE_CONFIG"
        return 1
    fi
    
    if [ -z "$token" ]; then
        log_error "Token is empty"
        return 1
    fi
    
    # Create a backup
    cp "$OPENCODE_CONFIG" "$OPENCODE_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Update the Bearer token using sed
    # Match: "Authorization": "Bearer <old-token>"
    # Replace with: "Authorization": "Bearer <new-token>"
    if sed -i "s/\"Authorization\": \"Bearer [a-zA-Z0-9]*/\"Authorization\": \"Bearer $token/g" "$OPENCODE_CONFIG"; then
        log_success "Updated $OPENCODE_CONFIG"
        return 0
    else
        log_error "Failed to update config"
        return 1
    fi
}

# Function to verify gateway
verify_gateway() {
    log_info "Verifying gateway..."
    
    # Check if process is running
    if ! pgrep -f "docker-mcp.*gateway" > /dev/null; then
        log_error "Gateway process not found"
        return 1
    fi
    
    # Check if port is listening
    if ! netstat -tlnp 2>/dev/null | grep -q ":$GATEWAY_PORT"; then
        log_error "Port $GATEWAY_PORT not listening"
        return 1
    fi
    
    log_success "Gateway is running and listening on port $GATEWAY_PORT"
    return 0
}

# Main execution
main() {
    echo "============================================================"
    echo " MCP Gateway Restart & Token Update Script"
    echo "============================================================"
    echo
    
    # Step 1: Kill existing gateway
    kill_gateway
    
    # Step 2: Start new gateway
    start_gateway
    
    # Step 3: Wait for token
    TOKEN=$(wait_for_token)
    if [ -z "$TOKEN" ]; then
        log_error "Failed to get Bearer token"
        exit 1
    fi
    
    # Step 4: Verify gateway is running
    sleep 2
    if ! verify_gateway; then
        log_error "Gateway verification failed"
        exit 1
    fi
    
    # Step 5: Update opencode.jsonc
    if ! update_opencode_config "$TOKEN"; then
        log_error "Failed to update configuration"
        exit 1
    fi
    
    echo
    echo "============================================================"
    echo " RESTART COMPLETE"
    echo "============================================================"
    echo "Gateway URL: http://localhost:$GATEWAY_PORT/mcp"
    echo "Bearer Token: $TOKEN"
    echo "Config updated: $OPENCODE_CONFIG"
    echo
    echo -e "${YELLOW}NOTE:${NC} You may need to restart opencode for changes to take effect."
}

# Run main function
main "$@"
