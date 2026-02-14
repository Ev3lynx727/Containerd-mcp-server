#!/bin/bash

# setup_mcp_gateway.sh - MCP Gateway Setup Script
# This script must be run BEFORE other MCP server scripts
# It installs and configures the Docker MCP Gateway for enterprise MCP management

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

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Docker availability
check_docker() {
    log_info "Checking Docker installation..."

    if ! command_exists docker; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running or you don't have permissions."
        log_error "Please start Docker and ensure your user has Docker permissions."
        exit 1
    fi

    log_success "Docker is installed and running"
}

# Function to check Go installation
check_go() {
    log_info "Checking Go installation..."

    if ! command_exists go; then
        log_error "Go is not installed. Installing Go 1.24..."

        # Install Go
        wget -q https://go.dev/dl/go1.24.1.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz
        rm go1.24.1.linux-amd64.tar.gz

        # Add to PATH
        export PATH=$PATH:/usr/local/go/bin
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc

        log_success "Go 1.24.1 installed"
    fi

    # Check Go version
    GO_VERSION=$(go version | grep -oE 'go[0-9]+\.[0-9]+')
    if [[ "$GO_VERSION" < "go1.24" ]]; then
        log_warning "Go version $GO_VERSION detected. MCP Gateway requires Go 1.24+"
        log_info "Attempting to install Go 1.24..."

        wget -q https://go.dev/dl/go1.24.1.linux-amd64.tar.gz
        sudo rm -rf /usr/local/go
        sudo tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz
        rm go1.24.1.linux-amd64.tar.gz

        export PATH=/usr/local/go/bin:$PATH
        echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc

        source ~/.bashrc
    fi

    log_success "Go $(go version | cut -d' ' -f3) is available"
}

# Function to install Docker MCP CLI plugin
install_mcp_cli() {
    log_info "Installing Docker MCP CLI plugin..."

    # Create CLI plugins directory
    mkdir -p ~/.docker/cli-plugins

    # Check if already installed
    if command_exists docker && docker mcp --help >/dev/null 2>&1; then
        log_success "Docker MCP CLI plugin already installed"
        return
    fi

    # Clone and build
    if [ ! -d "mcp-gateway-repo" ]; then
        log_info "Cloning Docker MCP Gateway repository..."
        git clone https://github.com/docker/mcp-gateway.git mcp-gateway-repo
    fi

    cd mcp-gateway-repo

    log_info "Building Docker MCP CLI plugin..."
    make docker-mcp

    # Check if build was successful
    if [ ! -f "dist/docker-mcp" ]; then
        log_error "Failed to build Docker MCP CLI plugin"
        exit 1
    fi

    log_success "Docker MCP CLI plugin built successfully"

    cd ..
}

# Function to initialize MCP environment
initialize_mcp() {
    log_info "Initializing MCP environment..."

    # Initialize catalog
    log_info "Initializing MCP catalog..."
    docker mcp catalog init

    # Pull gateway image
    log_info "Pulling Docker MCP Gateway image..."
    docker pull docker/mcp-gateway

    # Enable essential servers
    log_info "Enabling essential MCP servers..."
    docker mcp server enable filesystem git 2>/dev/null || log_warning "Some servers may not be available in catalog"

    log_success "MCP environment initialized"
}

# Function to start MCP Gateway
start_gateway() {
    log_info "Starting Docker MCP Gateway..."

    # Check if already running
    if ps aux | grep -q "[d]ocker-mcp.*gateway.*run"; then
        log_warning "MCP Gateway appears to already be running"
        return
    fi

    # Start gateway in background
    log_info "Starting gateway on port 8090..."
    docker mcp gateway run --port 8090 --transport streaming > gateway.log 2>&1 &

    # Wait for startup
    sleep 5

    # Check if running
    if ps aux | grep -q "[d]ocker-mcp.*gateway.*run"; then
        log_success "MCP Gateway started successfully"

        # Extract Bearer token
        GATEWAY_TOKEN=$(grep "Bearer" gateway.log | tail -1 | grep -oE "Bearer [a-zA-Z0-9]+" || echo "")

        if [ -n "$GATEWAY_TOKEN" ]; then
            log_info "Gateway Bearer token: $GATEWAY_TOKEN"
            echo "MCP_GATEWAY_TOKEN=$GATEWAY_TOKEN" > .env.gateway
        fi
    else
        log_error "Failed to start MCP Gateway"
        log_info "Check gateway.log for details"
        exit 1
    fi
}

# Function to verify setup
verify_setup() {
    log_info "Verifying MCP Gateway setup..."

    # Check if gateway is running
    if ! ps aux | grep -q "[d]ocker-mcp.*gateway.*run"; then
        log_error "MCP Gateway is not running"
        return 1
    fi

    # Check port
    if ! netstat -tlnp 2>/dev/null | grep -q :8090; then
        log_error "Gateway port 8090 is not listening"
        return 1
    fi

    # Test health endpoint
    if curl -s --connect-timeout 5 http://localhost:8090/health >/dev/null 2>&1; then
        log_success "Gateway health check passed"
    else
        log_warning "Gateway health check failed - may require authentication"
    fi

    # Check available tools
    TOOL_COUNT=$(docker mcp tools ls 2>/dev/null | grep -c "^ -" || echo "0")
    if [ "$TOOL_COUNT" -gt 0 ]; then
        log_success "Gateway provides $TOOL_COUNT MCP tools"
    else
        log_warning "No MCP tools detected"
    fi

    log_success "MCP Gateway verification completed"
}

# Function to display usage information
show_usage() {
    cat << EOF
Docker MCP Gateway Setup Script

This script sets up the Docker MCP Gateway, which provides enterprise-grade
MCP server management. It must be run BEFORE deploying other MCP servers.

USAGE:
    ./setup_mcp_gateway.sh [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    --skip-go-check     Skip Go version check
    --port PORT         Gateway port (default: 8090)

REQUIREMENTS:
    - Docker installed and running
    - Internet connection for downloading dependencies
    - sudo access for system installations

OUTPUT:
    - Docker MCP CLI plugin installed
    - MCP catalog initialized
    - Gateway running on specified port
    - Bearer token for authentication (saved to .env.gateway)

EXAMPLES:
    ./setup_mcp_gateway.sh                    # Standard setup
    ./setup_mcp_gateway.sh --port 9090        # Custom port
    ./setup_mcp_gateway.sh --skip-go-check    # Skip Go verification

EOF
}

# Main execution
main() {
    echo "========================================"
    echo " Docker MCP Gateway Setup Script"
    echo "========================================"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            --skip-go-check)
                SKIP_GO_CHECK=true
                shift
                ;;
            --port)
                GATEWAY_PORT="$2"
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    # Set defaults
    GATEWAY_PORT=${GATEWAY_PORT:-8090}

    log_info "Starting Docker MCP Gateway setup..."
    log_info "Gateway will run on port: $GATEWAY_PORT"

    # Run setup steps
    check_docker

    if [ "$SKIP_GO_CHECK" != "true" ]; then
        check_go
    fi

    install_mcp_cli
    initialize_mcp
    start_gateway
    verify_setup

    echo ""
    log_success "Docker MCP Gateway setup completed!"
    log_info "Gateway is running on port $GATEWAY_PORT"
    log_info "You can now run other MCP server deployment scripts"

    if [ -f ".env.gateway" ]; then
        log_info "Gateway authentication token saved in .env.gateway"
    fi
}

# Run main function
main "$@"