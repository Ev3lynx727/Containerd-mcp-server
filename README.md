## Prerequisites

**IMPORTANT:** Before deploying any MCP server containers, you MUST install and configure the Docker MCP Gateway. This provides the unified management interface for all MCP servers and resolves connection issues.

### System Requirements

- **Docker:** Version 24.0+ with CLI plugins support
- **Go:** Version 1.24+ (for building CLI plugin)
- **Git:** For cloning repositories
- **sudo access:** For system installations

### Step 1: Verify System Readiness

```bash
# Check Docker installation and version
docker --version
docker info

# Check if Docker daemon is running
docker ps

# Verify Docker CLI plugins support
docker --help | grep -A 5 "Management Commands"
```

### Step 2: Install Go (if not present)

```bash
# Check current Go version
go version

# If Go < 1.24, install latest version
# Ubuntu/Debian:
sudo apt update && sudo apt install -y golang-go

# Or install manually:
wget https://go.dev/dl/go1.24.1.linux-amd64.tar.gz
sudo rm -rf /usr/local/go && sudo tar -C /usr/local -xzf go1.24.1.linux-amd64.tar.gz
echo 'export PATH=/usr/local/go/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# Verify Go installation
go version
```

### Step 3: Install Docker MCP CLI Plugin

```bash
# Create Docker CLI plugins directory (required)
mkdir -p ~/.docker/cli-plugins

# Clone the Docker MCP Gateway repository
git clone https://github.com/docker/mcp-gateway.git
cd mcp-gateway

# Build the CLI plugin
make docker-mcp

# If build fails due to Go version, the binary might still be created
# Check if binary exists
ls -la dist/docker-mcp

# If binary exists but installation failed, copy manually
cp dist/docker-mcp ~/.docker/cli-plugins/docker-mcp 2>/dev/null || \
sudo mkdir -p /usr/local/lib/docker/cli-plugins && \
sudo cp dist/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp && \
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-mcp
```

### Step 4: Verify CLI Plugin Installation

```bash
# Test CLI plugin
docker mcp --help

# Expected output should show available commands like:
# Available Commands:
#   catalog     Manage MCP server catalogs
#   client      Manage MCP clients
#   gateway     Run MCP gateway
#   server      Manage MCP servers
```

### Step 5: Initialize MCP Environment

```bash
# Initialize the Docker MCP catalog
docker mcp catalog init

# Verify catalog
docker mcp catalog ls

# Pull the official MCP Gateway image
docker pull docker/mcp-gateway

# Verify image
docker images | grep mcp-gateway
```

### Step 6: Configure MCP Gateway

```bash
# Enable essential MCP servers from catalog
docker mcp server enable sequential-thinking filesystem git memory fetch time

# List enabled servers
docker mcp server ls

# Start MCP Gateway on available port (8090)
docker mcp gateway run --port 8090 --transport streaming

# Verify gateway is running
curl -s http://localhost:8090/health
```

### Troubleshooting: Common Installation Issues

#### Issue: "unknown command 'mcp'" after installation
```bash
# Check if binary exists in CLI plugins directory
ls -la ~/.docker/cli-plugins/docker-mcp

# If not found, check system location
ls -la /usr/local/lib/docker/cli-plugins/docker-mcp

# Restart Docker daemon
sudo systemctl restart docker
```

#### Issue: Go version compatibility errors
```bash
# The binary might still be built successfully despite warnings
ls -la mcp-gateway/dist/docker-mcp

# Copy manually if needed
cp mcp-gateway/dist/docker-mcp ~/.docker/cli-plugins/docker-mcp
chmod +x ~/.docker/cli-plugins/docker-mcp
```

#### Issue: Permission denied errors
```bash
# Use system-wide installation
sudo mkdir -p /usr/local/lib/docker/cli-plugins
sudo cp mcp-gateway/dist/docker-mcp /usr/local/lib/docker/cli-plugins/docker-mcp
sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-mcp
```

### Validation Checklist

- [ ] Docker installed and running
- [ ] Go 1.24+ available
- [ ] Docker CLI plugins directory exists
- [ ] `docker mcp --help` works
- [ ] MCP catalog initialized
- [ ] MCP Gateway image pulled
- [ ] Gateway running on port 8090
- [ ] Health check passes: `curl http://localhost:8090/health`

## Automated Setup

### MCP Gateway Setup (Required First)

A comprehensive setup script is provided to automate the MCP Gateway installation:

```bash
# Run the automated MCP Gateway setup
./setup_mcp_gateway.sh

# Or with custom options
./setup_mcp_gateway.sh --port 9090 --verbose
```

**What the script does:**
- ✅ Verifies Docker and Go installations
- ✅ Installs Docker MCP CLI plugin
- ✅ Initializes MCP catalog and pulls images
- ✅ Enables essential servers (filesystem, git)
- ✅ Starts MCP Gateway on port 8090
- ✅ Performs comprehensive validation checks

**Script Options:**
- `--port PORT`: Custom gateway port (default: 8090)
- `--verbose`: Enable detailed logging
- `--skip-go-check`: Skip Go version verification
- `--help`: Show usage information

### Complete Deployment Workflow

```bash
# 1. Setup MCP Gateway (REQUIRED)
./setup_mcp_gateway.sh

# 2. Configure environment (optional)
echo "CONTEXT7_API_KEY=your_key" > .env

# 3. Deploy MCP servers
./run-container.sh

# 4. Verify deployment
./rebuild-and-deploy.sh
```