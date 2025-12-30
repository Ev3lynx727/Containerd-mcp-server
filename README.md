# Containerd MCP Server

A containerized MCP (Model Context Protocol) server suite for VM and cloud deployments. Provides remote MCP servers that can be accessed by local agents or other applications.

## Files
- `Dockerfile`: Builds the container with MCP servers.
- `docker-compose.yml`: Defines services with volume mounts.
- `run-container.sh`: Script to build and run with docker-compose.
- `start-mcp-servers.sh`: Starts the MCP servers in the container.

## Usage
1. Ensure Docker and docker-compose are installed.
2. Run `./run-container.sh` to build and start the container.
3. Container exposes MCP servers on ports 3000-3005.
4. Update local opencode config to connect to `http://localhost:3001` (etc.).

## Volumes & Shared Data
- **Docker Socket** (`/var/run/docker.sock:ro`): Read-only mount for Docker MCP to manage host containers.
- **VS Code Server** (`~/.vscodeserver:/root/.vscode-server`): Shares VS Code extensions/settings.
- **.env** (`.env`): Optional environment file for API keys (Context7, etc.).
- **Shared Data** (`mcp-data:/app/data`): Named volume for persistent MCP data.
- **Netdata Lib** (`netdata-lib:/var/lib/netdata`): Persistent storage for Netdata data.
- **Netdata Cache** (`netdata-cache:/var/cache/netdata`): Cache for Netdata.

## MCP Servers Included

### Local Servers (Built-in)
- **mcp_everything**: General utilities (file ops, git, SQLite)
- **playwright**: Browser automation and testing
- **rest_api_tester**: REST API testing and debugging
- **docker**: Docker container management

### Remote Servers (Configured)
- **context7**: Code context and analysis (requires API key)
- **gh_grep**: GitHub code search
- **github**: GitHub repository operations
- **netdata**: Infrastructure monitoring and observability data access

### Tools
- **mgrep**: Semantic search for code and documents
- **MCP SDK**: Model Context Protocol framework

## Environment
- Includes: MCP SDK, mgrep (semantic search), Playwright (browser automation), REST API Tester, Docker MCP, Netdata (monitoring).

## Development Setup

### VS Code Extensions (Recommended)
- **GitHub Actions** (by GitHub): Monitor build status and workflow runs directly in VS Code
- **Docker** (by Microsoft): Work with Docker files and containers

### Automated Builds
This repository includes GitHub Actions for automated Docker builds:
- Builds on push to main branch
- Pushes to GitHub Container Registry (ghcr.io)
- Multi-platform support (AMD64/ARM64)

### Manual Deployment
```bash
# Clone and build
git clone https://github.com/Ev3lynx727/Containerd-mcp-server.git
cd Containerd-mcp-server

# Optional: Create .env with API keys
echo "CONTEXT7_API_KEY=your_key" > .env
echo "NETDATA_MCP_API_KEY=your_netdata_key" >> .env

# Build and run
docker-compose up -d --build
```

### Kubernetes/Cloud
Pull from registry: `ghcr.io/ev3lynx727/containerd-mcp-server:latest`

### Build Status
Automated builds are configured via GitHub Actions. Check the Actions tab for build status.

## Configuration

### Environment Variables
Create a `.env` file for API keys:

```bash
# Context7 API key for enhanced code analysis
CONTEXT7_API_KEY=your_context7_api_key_here

# Optional: Other API keys as needed
# GITHUB_TOKEN=your_github_token
```

### Connecting to MCP Servers
Update your local MCP client config (e.g., opencode) to connect to the containerized servers.

**Config File Location**: Place the config in `~/.config/opencode/opencode.jsonc` (create the directory if it doesn't exist).

**Example Config for OpenCode**:
```json
{
  "$schema": "https://opencode.ai/config.json",
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
    "netdata": {
      "type": "remote",
      "url": "http://localhost:19999/sse",
      "enabled": true
    }
  }
}
```

This connects to the running container's MCP servers via HTTP/SSE. Restart your MCP client after updating the config.

## Customization
- Edit `Dockerfile` to add/remove MCP servers.
- Modify `docker-compose.yml` for volume adjustments.
- Update `start-mcp-servers.sh` for server startup.