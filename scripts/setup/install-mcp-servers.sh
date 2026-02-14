#!/bin/bash
#
# install-mcp-servers.sh - Install MCP servers in mcp-server-container
#
# This script installs:
# 1. ruff-mcp-server from GitHub
# 2. shellcheck-mcp-server wrapper
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to check if container is running
check_container() {
    if ! docker ps --format 'table {{.Names}}' | grep -q "^mcp-server-container$"; then
        log_error "mcp-server-container is not running!"
        log_info "Start it with: docker-compose up -d"
        exit 1
    fi
    log_success "mcp-server-container is running"
}

# Function to copy ruff MCP wrapper to container
copy_ruff_wrapper() {
    log_info "Copying ruff MCP wrapper to container..."
    
    # Check if wrapper exists locally
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    WRAPPER_FILE="$REPO_ROOT/mcp-servers/ruff/ruff-mcp-wrapper.py"
    
    if [ ! -f "$WRAPPER_FILE" ]; then
        log_error "ruff-mcp-wrapper.py not found in: $REPO_ROOT/mcp-servers/ruff/"
        return 1
    fi
    
    # Copy to container
    if docker cp "$WRAPPER_FILE" mcp-server-container:/app/ 2>&1; then
        docker exec mcp-server-container chmod +x /app/ruff-mcp-wrapper.py 2>&1
        
        # Verify it was copied
        if docker exec mcp-server-container test -f /app/ruff-mcp-wrapper.py; then
            log_success "ruff MCP wrapper copied to container"
            return 0
        else
            log_error "Failed to verify ruff wrapper in container"
            return 1
        fi
    else
        log_error "Failed to copy ruff wrapper"
        return 1
    fi
}

# Function to copy shellcheck MCP wrapper to container
copy_shellcheck_wrapper() {
    log_info "Copying shellcheck MCP wrapper to container..."
    
    # Check if wrapper exists locally
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    WRAPPER_FILE="$REPO_ROOT/mcp-servers/shellcheck/shellcheck-mcp-server.py"
    
    if [ ! -f "$WRAPPER_FILE" ]; then
        log_error "shellcheck-mcp-server.py not found in: $REPO_ROOT/mcp-servers/shellcheck/"
        return 1
    fi
    
    # Copy to container
    if docker cp "$WRAPPER_FILE" mcp-server-container:/app/ 2>&1; then
        docker exec mcp-server-container chmod +x /app/shellcheck-mcp-server.py 2>&1
        
        # Verify it was copied
        if docker exec mcp-server-container test -f /app/shellcheck-mcp-server.py; then
            log_success "shellcheck MCP wrapper copied to container"
            return 0
        else
            log_error "Failed to verify shellcheck wrapper in container"
            return 1
        fi
    else
        log_error "Failed to copy shellcheck wrapper"
        return 1
    fi
}

# Main execution
main() {
    echo "============================================================"
    echo " MCP Servers Installation Script"
    echo "============================================================"
    echo
    
    # Step 1: Check container is running
    check_container
    
    # Step 2: Copy ruff wrapper
    if copy_ruff_wrapper; then
        log_success "ruff MCP server ready"
    else
        log_warn "ruff wrapper setup failed"
    fi
    
    # Step 3: Copy shellcheck wrapper
    if copy_shellcheck_wrapper; then
        log_success "shellcheck MCP server ready"
    else
        log_warn "shellcheck wrapper setup failed"
    fi
    
    echo
    echo "============================================================"
    echo " INSTALLATION COMPLETE"
    echo "============================================================"
    echo
    echo "Installed MCP servers:"
    docker exec mcp-server-container test -f /app/ruff-mcp-wrapper.py && echo "  ✓ ruff-mcp-server"
    docker exec mcp-server-container test -f /app/shellcheck-mcp-server.py && echo "  ✓ shellcheck-mcp-server"
    echo
    echo -e "${YELLOW}NOTE:${NC} Restart opencode to use the new MCP servers"
}

# Run main function
main "$@"
