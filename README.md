# Containerd MCP Server

A containerized MCP (Model Context Protocol) server suite for VM and cloud deployments. Uses pre-built GHCR images for fast deployment with remote MCP servers accessible by local agents or applications.

## Quick Start

```bash
# Clone and deploy with pre-built images
git clone https://github.com/Ev3lynx727/Containerd-mcp-server.git
cd Containerd-mcp-server

# Optional: Create .env with API keys
echo "CONTEXT7_API_KEY=your_key" > .env

# Run deployment script
./run-container.sh
```

## Files

- `Dockerfile`: Container definition with MCP servers
- `docker-compose.yml`: Service definitions (MCP servers, Netdata, MCP Inspector)
- `run-container.sh`: Pulls GHCR images and starts containers
- `rebuild-and-deploy.sh`: Full deployment with health checks
- `start-mcp-servers.sh`: MCP server startup script inside container

## MCP Servers

| Server | Port | Transport | Description |
|--------|------|-----------|-------------|
| mcp_everything | 3001 | SSE | General utilities (file ops, git, memory, fetch, time) |
| playwright | 3002 | Streamable HTTP | Browser automation and testing |
| rest_api_tester | 3003 | Streamable HTTP | REST API testing and debugging |
| markdownlint | local | stdio | Markdown linting (local stdio connection) |
| netdata | 19999 | SSE | Infrastructure monitoring and observability |
| mcp-inspector | 6274 | HTTP | Web-based MCP testing tool |

## Usage

1. Ensure Docker and docker-compose are installed
2. Run `./run-container.sh` or `./rebuild-and-deploy.sh`
3. MCP servers accessible at localhost:3001-3003
4. Update opencode config to connect to MCP servers
5. Access MCP Inspector at http://localhost:6274

## Volumes

- **Docker Socket** (`/var/run/docker.sock:ro`): Docker MCP and Netdata monitoring
- **VS Code Server** (`~/.vscodeserver:/root/.vscodeserver`): VS Code extensions/settings
- **.env**: Environment file for API keys
- **mcp-data**: Named volume for persistent MCP data
- **netdata-lib/netdata-cache**: Netdata persistent storage

## Deployment Options

### Option 1: Using Scripts (Recommended)

```bash
# Quick deployment
./run-container.sh

# Full deployment with health checks
./rebuild-and-deploy.sh
```

### Option 2: Manual Docker Compose

```bash
# Pull images
docker pull ghcr.io/ev3lynx727/containerd-mcp-server:latest
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-proxy:latest
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-stdio-proxy:latest

# Start containers
docker-compose up -d
```

### Option 3: Build from Source

```bash
docker-compose up -d --build
```

## Configuration

### Environment Variables

Create `.env` file:

```bash
CONTEXT7_API_KEY=your_context7_api_key
AUTH_BEARER=your_bearer_token  # For rest_api_tester
```

### OpenCode Config

Add to `~/.config/opencode/opencode.jsonc`:

```json
{
  "mcp": {
    "mcp_everything": {
      "type": "remote",
      "url": "http://localhost:3001/sse",
      "enabled": true
    },
    "playwright": {
      "type": "remote",
      "url": "http://localhost:3002/mcp",
      "enabled": true
    },
    "rest_api_tester": {
      "type": "remote",
      "url": "http://localhost:3003/mcp",
      "enabled": true
    },
    "markdownlint": {
      "type": "local",
      "command": ["node", "/app/markdownlint-mcp-server.js"],
      "enabled": true
    },
    "netdata": {
      "type": "remote",
      "url": "http://localhost:19999/sse",
      "enabled": true
    },
    "context7": {
      "type": "remote",
      "url": "https://mcp.context7.com/mcp",
      "headers": { "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}" },
      "enabled": true
    },
    "gh_grep": {
      "type": "remote",
      "url": "https://mcp.grep.app",
      "enabled": true
    }
  }
}
```

## Troubleshooting

### MCP Server Connection Issues

```bash
# Check running containers
docker ps

# Check container logs
docker logs mcp-server-container

# Check specific service health
curl http://localhost:3001/sse
curl http://localhost:3002/mcp
curl http://localhost:3003/mcp
```

### Memory Issues

- Netdata limited to 256MB RAM
- MCP server limited to 2GB RAM
- See memory optimization section in full docs

### Build Status

Automated GHCR builds active:
- Multi-image: Main server, Netdata proxy, STDIO proxy
- Multi-platform: AMD64/ARM64
- Registry: `ghcr.io/ev3lynx727/containerd-mcp-server*`

See [Actions tab](https://github.com/Ev3lynx727/Containerd-mcp-server/actions) for status.