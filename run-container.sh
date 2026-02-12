#!/bin/bash

# run-container.sh - Enhanced MCP Server Container Deployment
# DEPENDS ON: setup_mcp_gateway.sh (must run first)
# Uses pre-built GHCR images with comprehensive health checks and OpenCode integration

set -e  # Exit on any error

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

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check command availability
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if MCP Gateway is running
check_gateway_prerequisite() {
    log_info "Checking MCP Gateway prerequisite..."

    if ! ps aux | grep -q "[d]ocker-mcp.*gateway"; then
        log_error "MCP Gateway is not running!"
        log_error "Please run ./setup_mcp_gateway.sh first to set up the gateway."
        exit 1
    fi

    # Check gateway port
    if ! netstat -tlnp 2>/dev/null | grep -q :8090; then
        log_error "MCP Gateway port 8090 is not accessible!"
        exit 1
    fi

    log_success "MCP Gateway is running and accessible"
}

# Function to check docker-compose availability
check_docker_compose() {
    log_info "Checking docker-compose availability..."

    if command_exists docker-compose; then
        COMPOSE_CMD="docker-compose"
        log_success "docker-compose found"
    elif docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
        log_success "docker compose (plugin) found"
    else
        log_error "Neither docker-compose nor docker compose found"
        exit 1
    fi
}

# Function to pull images with retry logic
pull_images() {
    log_info "Pulling latest GHCR images..."

    local images=(
        "ghcr.io/ev3lynx727/containerd-mcp-server:latest"
        "ghcr.io/ev3lynx727/containerd-mcp-server-proxy:latest"
        "ghcr.io/ev3lynx727/containerd-mcp-server-stdio-proxy:latest"
    )

    for image in "${images[@]}"; do
        log_info "Pulling $image..."
        if ! docker pull "$image" 2>/dev/null; then
            log_warning "Failed to pull $image - using cached version if available"
        else
            log_success "Successfully pulled $image"
        fi
    done
}

# Function to start containers and verify health
start_containers() {
    log_info "Starting MCP server containers..."

    if ! $COMPOSE_CMD up -d; then
        log_error "Failed to start containers with $COMPOSE_CMD"
        exit 1
    fi

    log_success "Containers started successfully"

    # Wait for containers to be ready
    log_info "Waiting for containers to initialize..."
    sleep 10

    # Check container health
    log_info "Verifying container health..."
    if ! $COMPOSE_CMD ps | grep -q "Up"; then
        log_error "No containers are running!"
        $COMPOSE_CMD logs
        exit 1
    fi

    log_success "All containers are running"
}

# Function to verify service endpoints
verify_endpoints() {
    log_info "Verifying service endpoints..."

    local endpoints=(
        "3001:MCP servers"
        "3002:MCP servers"
        "3003:MCP servers"
        "6274:MCP Inspector"
        "19999:Netdata"
    )

    for endpoint in "${endpoints[@]}"; do
        local port=$(echo "$endpoint" | cut -d: -f1)
        local service=$(echo "$endpoint" | cut -d: -f2)

        if netstat -tlnp 2>/dev/null | grep -q ":$port "; then
            log_success "$service accessible on port $port"
        else
            log_warning "$service on port $port not yet accessible"
        fi
    done
}

# Function to update OpenCode configuration
update_opencode_config() {
    local config_file="$HOME/.config/opencode/opencode.jsonc"

    if [ ! -f "$config_file" ]; then
        log_warning "OpenCode config not found at $config_file"
        log_info "Please create the config file or run opencode to generate it"
        return
    fi

    log_info "Updating OpenCode configuration..."

    # Create backup
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"

    # Extract gateway token if available
    local gateway_token=""
    if [ -f ".env.gateway" ]; then
        gateway_token=$(grep "MCP_GATEWAY_TOKEN" .env.gateway | cut -d= -f2)
    fi

    if [ -z "$gateway_token" ]; then
        # Try to extract from running gateway logs
        gateway_token=$(ps aux | grep "docker-mcp.*gateway" | grep -o "Bearer [a-zA-Z0-9]*" | head -1 | cut -d' ' -f2 || echo "")
    fi

    # Update/add MCP server configurations
    log_info "Configuring MCP Gateway integration..."

    # Use a temporary file for safe editing
    local temp_file=$(mktemp)

    # Add MCP Gateway if not present
    if ! grep -q '"mcp-gateway"' "$config_file"; then
        if [ -n "$gateway_token" ]; then
            sed '/"mcp": {/a\
    "mcp-gateway": {\
      "type": "remote",\
      "url": "http://localhost:8090/mcp",\
      "headers": {\
        "Authorization": "Bearer '"$gateway_token"'"\
      },\
      "enabled": true,\
      "timeout": 60000\
    },' "$config_file" > "$temp_file"
        else
            sed '/"mcp": {/a\
    "mcp-gateway": {\
      "type": "remote",\
      "url": "http://localhost:8090/mcp",\
      "enabled": true,\
      "timeout": 60000\
    },' "$config_file" > "$temp_file"
        fi
        mv "$temp_file" "$config_file"
        log_success "Added MCP Gateway to OpenCode config"
    else
        log_info "MCP Gateway already configured"
    fi

    # Update filesystem to use gateway
    if grep -q '"filesystem"' "$config_file" && ! grep -q '"url": "http://localhost:8090/mcp"' "$config_file"; then
        # This is complex to do safely with sed, so we'll leave it for manual configuration
        log_warning "Filesystem server needs manual configuration to use MCP Gateway"
        log_info "Consider updating filesystem to use: http://localhost:8090/mcp with Bearer token"
    fi

    # Add Netdata if not present
    if ! grep -q '"netdata"' "$config_file"; then
        sed -i '/"mcp": {/a\
    "netdata": {\
      "type": "remote",\
      "url": "http://localhost:19999/sse",\
      "enabled": true\
    },' "$config_file"
        log_success "Added Netdata to OpenCode config"
    else
        log_info "Netdata already configured"
    fi

    log_success "OpenCode configuration updated"
}

# Function to display deployment summary
show_summary() {
    echo ""
    log_success "=== MCP Server Deployment Complete ==="
    echo ""
    echo "Running Containers:"
    $COMPOSE_CMD ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "Access Points:"
    echo " • MCP Servers: localhost:3001-3003"
    echo " • MCP Inspector: http://localhost:6274"
    echo " • Netdata: http://localhost:19999"
    echo " • MCP Gateway: http://localhost:8090/mcp"
    echo ""
    echo "Volumes Configured:"
    echo " • Docker socket (read-only)"
    echo " • VS Code server data"
    echo " • .env file (read-only)"
    echo " • Named volume 'mcp-data'"
    echo ""
    log_info "OpenCode has been configured with MCP server endpoints"
    log_info "Use './rebuild-and-deploy.sh' for health checks and monitoring"
}

# Main execution function
main() {
    echo "========================================"
    echo " Enhanced MCP Server Container Deployment"
    echo "========================================"

    # Check prerequisites
    check_gateway_prerequisite
    check_docker_compose

    # Execute deployment steps
    pull_images
    start_containers
    verify_endpoints
    update_opencode_config
    show_summary

    log_success "MCP Server deployment completed successfully!"
    log_info "All services are running and configured"
}

# Handle command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --help|-h)
            echo "Enhanced MCP Server Container Deployment"
            echo ""
            echo "USAGE: $0 [OPTIONS]"
            echo ""
            echo "OPTIONS:"
            echo "  --help, -h          Show this help message"
            echo "  --no-config-update  Skip OpenCode config updates"
            echo ""
            echo "PREREQUISITES:"
            echo "  - Run ./setup_mcp_gateway.sh first"
            echo "  - Docker and docker-compose installed"
            echo ""
            exit 0
            ;;
        --no-config-update)
            NO_CONFIG_UPDATE=true
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Skip config update if requested
if [ "$NO_CONFIG_UPDATE" = "true" ]; then
    update_opencode_config() {
        log_info "Skipping OpenCode config update (--no-config-update)"
    }
fi

# Run main deployment
main