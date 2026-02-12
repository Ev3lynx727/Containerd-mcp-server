# MCP Server Agent Setup Guide

## Overview

This guide provides comprehensive instructions for setting up and using the MCP (Model Context Protocol) server ecosystem. The setup requires a running MCP Gateway on `localhost:8090` for enterprise-grade server management and integration.

## Prerequisites

### System Requirements
- **Operating System**: Linux (Ubuntu/Debian recommended)
- **Docker**: Version 24.0+ with CLI plugins support
- **Go**: Version 1.24+ (for building MCP CLI tools)
- **Git**: For cloning repositories
- **sudo access**: Required for system installations

### Required Services
- **MCP Gateway**: Must be running on `localhost:8090`
  - Provides unified access to MCP servers
  - Handles authentication and security
  - Manages server lifecycle

## Quick Start

### Step 1: Setup MCP Gateway (REQUIRED)
```bash
# Clone the repository
git clone https://github.com/Ev3lynx727/Containerd-mcp-server.git
cd Containerd-mcp-server

# Setup MCP Gateway (critical first step)
./setup_mcp_gateway.sh

# Verify gateway is running on port 8090
curl -s http://localhost:8090/health
```

### Step 2: Configure Environment (Optional)
```bash
# Create environment file for API keys
echo "CONTEXT7_API_KEY=your_context7_api_key" > .env
```

### Step 3: Deploy MCP Servers
```bash
# Deploy MCP server containers
./run-container.sh
```

### Step 4: Verify Setup
```bash
# Check all services are running
./rebuild-and-deploy.sh

# Verify OpenCode integration
opencode agent list
```

## Detailed Setup Instructions

### MCP Gateway Setup

The MCP Gateway is the foundation of the ecosystem and must be running before any MCP servers.

#### Automated Setup
```bash
./setup_mcp_gateway.sh --help
# Output: Shows all available options

./setup_mcp_gateway.sh
# Standard setup on port 8090

./setup_mcp_gateway.sh --port 9090 --verbose
# Custom port with detailed logging
```

#### Manual Setup (Alternative)
If automated setup fails:
```bash
# 1. Install Go 1.24+
go version

# 2. Install Docker MCP CLI
mkdir -p ~/.docker/cli-plugins
git clone https://github.com/docker/mcp-gateway.git
cd mcp-gateway
make docker-mcp

# 3. Initialize environment
docker mcp catalog init
docker pull docker/mcp-gateway

# 4. Start gateway
docker mcp gateway run --port 8090 --transport streaming
```

#### Gateway Verification
```bash
# Check gateway process
ps aux | grep "docker-mcp.*gateway"

# Check port 8090
netstat -tlnp | grep :8090

# Test health endpoint
curl http://localhost:8090/health

# Check available tools
docker mcp tools ls
```

### MCP Server Deployment

Once the gateway is running, deploy the MCP server containers.

#### Standard Deployment
```bash
# Deploy all MCP services
./run-container.sh
```

#### Deployment with Options
```bash
# Skip OpenCode config updates
./run-container.sh --no-config-update

# Show help
./run-container.sh --help
```

#### Service Verification
```bash
# Check container status
docker compose ps

# Verify endpoints
curl http://localhost:3001/sse  # MCP servers
```

### OpenCode Integration

Configure OpenCode to use the MCP server ecosystem.

#### Automatic Configuration
The deployment scripts automatically update OpenCode configuration. To verify:

```bash
# Check OpenCode config
cat ~/.config/opencode/opencode.jsonc

# List configured agents
opencode agent list
```

#### Manual Configuration (if needed)
```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "mcp-gateway": {
      "type": "remote",
      "url": "http://localhost:8090/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      },
      "enabled": true,
      "timeout": 60000
    },
    "filesystem": {
      "type": "remote",
      "url": "http://localhost:8090/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      },
      "enabled": true,
      "timeout": 60000
    },
    "git": {
      "type": "remote",
      "url": "http://localhost:8090/mcp",
      "headers": {
        "Authorization": "Bearer YOUR_TOKEN"
      },
      "enabled": true,
      "timeout": 60000
    },
    "sequential-thinking": {
      "type": "local",
      "command": ["docker", "exec", "-i", "mcp-server-sequential-container", "npx", "-y", "@modelcontextprotocol/server-sequential-thinking"],
      "enabled": true,
      "timeout": 60000
    },
    "memory": {
      "type": "local",
      "command": ["docker", "exec", "-i", "mcp-server-sequential-container", "npx", "-y", "@modelcontextprotocol/server-memory"],
      "enabled": true,
      "timeout": 60000
    },
    "fetch": {
      "type": "local",
      "command": ["docker", "exec", "-i", "mcp-server-sequential-container", "python3", "-m", "mcp_server_fetch"],
      "enabled": true,
      "timeout": 60000
    },
    "time": {
      "type": "local",
      "command": ["docker", "exec", "-i", "mcp-server-sequential-container", "python3", "-m", "mcp_server_time"],
      "enabled": true,
      "timeout": 60000
    },
    "formatter": {
      "type": "local",
      "command": ["docker", "exec", "-i", "mcp-server-sequential-container", "npx", "-y", "editorconfig-mcp-server"],
      "enabled": true,
      "timeout": 60000
    },
    "code-assistant": {
      "type": "remote",
      "url": "http://localhost:3112/sse",
      "enabled": true,
      "timeout": 60000
    },
    "everything": {
      "type": "remote",
      "url": "http://localhost:3001/sse",
      "enabled": true,
      "timeout": 60000
    },
    "code-analysis-agent": {
      "type": "local",
      "command": ["docker", "exec", "-i", "mcp-agent", "/usr/local/bin/node", "/app/dist/code-analysis-mcp.js"],
      "enabled": true,
      "timeout": 60000
    },
    "deployment-agent": {
      "type": "local",
      "command": ["docker", "exec", "-i", "mcp-agent", "/usr/local/bin/node", "/app/dist/deployment-mcp.js"],
      "enabled": true,
      "timeout": 60000
    },
    "ripgrep": {
      "type": "local",
      "command": ["npx", "-y", "mcp-ripgrep@latest"],
      "enabled": true,
      "timeout": 60000
    }
  }
}
```

## Usage Examples

### Basic OpenCode Usage
```bash
# Start OpenCode terminal interface
opencode

# Run a specific command
opencode run "Help me refactor this function"

# Start ACP server for external integrations
opencode acp --port 3000
```

### MCP Server Interaction
```bash
# List available MCP tools via gateway
docker mcp tools ls

# Use filesystem operations
# (Available through OpenCode interface)

# Use git operations
# (Available through OpenCode interface)
```

### Monitoring and Health Checks
```bash
# Check all services
./rebuild-and-deploy.sh

# Monitor containers
ctop

# Check gateway status
curl http://localhost:8090/health

# View OpenCode agent status
opencode agent list
```

## Troubleshooting

### MCP Gateway Issues
```bash
# Check if gateway is running
ps aux | grep "docker-mcp.*gateway"

# Restart gateway
docker mcp gateway run --port 8090 --transport streaming

# Check gateway logs
tail -f gateway.log
```

### Container Issues
```bash
# Check container status
docker compose ps

# View container logs
docker compose logs

# Restart containers
docker compose restart
```

### OpenCode Integration Issues
```bash
# Check config file
cat ~/.config/opencode/opencode.jsonc

# Validate JSON syntax
python3 -m json.tool ~/.config/opencode/opencode.jsonc

# Restart OpenCode
pkill -f opencode
opencode
```

### Network Issues
```bash
# Check port availability
netstat -tlnp | grep -E ':300[0-9]|:8090'

# Test service endpoints
curl http://localhost:3001/sse
curl http://localhost:8090/health
```

## Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   OpenCode      │────│  MCP Gateway     │────│ MCP Servers     │
│   (Terminal)    │    │ (localhost:8090) │    │ (Containers)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                    ┌──────────────────┐
                    │  Docker MCP CLI  │
                    │  (Management)    │
                    └──────────────────┘
```

### Component Descriptions

- **OpenCode**: Terminal-based AI coding agent with MCP integration
- **MCP Gateway**: Unified proxy for MCP server management and security
- **MCP Servers**: Individual specialized servers (filesystem, git, memory, etc.)
- **Docker MCP CLI**: Command-line tools for MCP ecosystem management

## Security Considerations

- **Bearer Token Authentication**: Gateway requires valid tokens for access
- **Container Isolation**: MCP servers run in separate containers
- **Network Restrictions**: Services bound to localhost only
- **API Key Management**: Sensitive keys stored in `.env` files

## Performance Optimization

- **Resource Limits**: Containers have defined CPU and memory limits
- **Health Monitoring**: Netdata provides system observability
- **Lazy Loading**: Services start on-demand to conserve resources
- **Caching**: Docker layer caching for faster deployments

## Support and Resources

### Documentation
- [OpenCode Documentation](https://opencode.ai/docs)
- [MCP Specification](https://spec.modelcontextprotocol.io/)
- [Docker MCP Gateway](https://github.com/docker/mcp-gateway)

### Community Support
- [OpenCode GitHub Issues](https://github.com/opencode-ai/opencode/issues)
- [Docker MCP Discussions](https://github.com/docker/mcp-gateway/discussions)

### Health Check Commands
```bash
# Complete system health check
./rebuild-and-deploy.sh

# Individual service checks
curl http://localhost:8090/health    # Gateway
curl http://localhost:3001/sse       # MCP servers
opencode agent list                  # OpenCode agents
```

---

**Note**: This setup requires the MCP Gateway to be running on `localhost:8090`. Always run `./setup_mcp_gateway.sh` before deploying MCP servers.