# Containerd MCP Server

A containerized MCP (Model Context Protocol) server suite for VM and cloud deployments. Provides remote MCP servers that can be accessed by local agents or other applications.

## Files
- `Dockerfile`: Builds the container with MCP servers.
- `docker-compose.yml`: Defines services including MCP servers, Netdata, and MCP Inspector.
- `run-container.sh`: Script to build and run with docker-compose.
- `start-mcp-servers.sh`: Starts the MCP servers in the container.

## Usage
1. Ensure Docker and docker-compose are installed.
2. Run `./run-container.sh` to build and start the container.
3. Container exposes MCP servers on ports 3000-3005 and MCP Inspector on port 6274.
4. Update local opencode config to connect to `http://localhost:3001` (etc.).
5. Access MCP Inspector at `http://localhost:6274` for testing and debugging.

## Volumes & Shared Data
- **Docker Socket** (`/var/run/docker.sock:ro`): Read-only mount for Docker MCP to manage host containers, and Netdata Docker monitoring.
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
- **netdata**: Infrastructure monitoring, Docker container monitoring, and observability data access

### Tools
- **mgrep**: Semantic search for code and documents
- **MCP SDK**: Model Context Protocol framework
- **MCP Inspector**: Web-based UI for testing and debugging MCP servers (available at http://localhost:6274)

## MCP Inspector

The MCP Inspector is a web-based developer tool for testing and debugging your MCP servers. It provides an interactive interface to inspect server capabilities, test tools, resources, and prompts, and monitor server behavior.

### Accessing the Inspector
- **URL**: http://localhost:6274
- **Authentication**: Requires a session token (automatically handled in containerized setup)
- **Auto-open**: Disabled in container mode to prevent browser interference

### Connecting to MCP Servers
Use the Inspector's web interface to connect to your stack's MCP servers:

| Server | Transport | Endpoint |
|--------|-----------|----------|
| mcp_everything | SSE | http://localhost:3001/sse |
| playwright | Streamable HTTP | http://localhost:3002/mcp |
| rest_api_tester | Streamable HTTP | http://localhost:3003/mcp |
| netdata | SSE | http://localhost:19999/sse |

### Features
- **Server Connection Pane**: Configure transport and connection settings
- **Resources Tab**: List and inspect available resources
- **Prompts Tab**: Test prompt templates with custom arguments
- **Tools Tab**: Execute tools with custom inputs and view results
- **Notifications Pane**: Monitor server logs and notifications

### Best Practices
- Use for iterative development and debugging of MCP servers
- Test edge cases like invalid inputs and concurrent operations
- Monitor server responses and error handling
- Export server configurations for use in other MCP clients

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

#### Option 1: Using Pre-built GHCR Images (Recommended)
```bash
# Clone repository
git clone https://github.com/Ev3lynx727/Containerd-mcp-server.git
cd Containerd-mcp-server

# Optional: Create .env with API keys
echo "CONTEXT7_API_KEY=your_key" > .env
echo "NETDATA_MCP_API_KEY=your_netdata_key" >> .env

# Pull pre-built images from GHCR
docker pull ghcr.io/ev3lynx727/containerd-mcp-server:latest
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-proxy:latest
docker pull ghcr.io/ev3lynx727/containerd-mcp-server-stdio-proxy:latest

# Run with pre-built images
docker-compose up -d
```

#### Option 2: Build Locally
```bash
# Clone and build from source
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
✅ **Automated GHCR builds are active and working!**

- **Multi-image builds**: Main server, Netdata proxy, and STDIO proxy
- **Multi-platform**: Linux AMD64 and ARM64 support
- **Automated**: Builds trigger on every push to main branch
- **Registry**: `ghcr.io/ev3lynx727/containerd-mcp-server*`

Check the [Actions tab](https://github.com/Ev3lynx727/Containerd-mcp-server/actions) for build status.

**Latest Update**: Netdata MCP server integration with Docker container monitoring enabled. Ready for cloud deployment.

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

**Complete Config with All Servers**:
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
    "rest_api_tester": {
      "type": "remote",
      "url": "http://localhost:3003/mcp",
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
      "headers": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      },
      "enabled": true
    },
    "gh_grep": {
      "type": "remote",
      "url": "https://mcp.grep.app",
      "enabled": true
    },
    "github": {
      "type": "remote",
      "url": "https://mcp.github.com",
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

## Troubleshooting

### Memory and Swap Issues

#### Symptoms
- High memory usage (>90% RAM)
- 100% swap utilization
- System slowdown or unresponsiveness
- OOM (Out of Memory) errors

#### Diagnosis
```bash
# Check memory and swap usage
free -h

# Check top memory-consuming processes
ps aux --sort=-%mem | head -10

# Check Docker container resource usage
docker stats --no-stream

# Check current swap configuration
swapon -s
```

#### Common Causes
1. **Netdata Memory Usage**: Default configuration can consume 100-300MB+
2. **Memory-Intensive Applications**: VS Code, IDEs, or multiple browser tabs
3. **Insufficient RAM**: VM with only 4GB RAM running multiple services
4. **No Memory Limits**: Containers without resource constraints

#### Solutions

##### Optimize Netdata Configuration
The project includes an optimized Netdata configuration (`netdata-optimized.conf`) that reduces memory usage:

```bash
# Memory mode instead of dbengine
mode = memory

# Reduced update frequency
update every = 5

# Disabled memory-intensive plugins
apps = no
ebpf = no
cgroups = yes
```

Netdata container is limited to 256MB RAM with CPU limits.

##### Monitor Memory Usage
Use the Netdata MCP server to monitor system resources:
- `get_memory_usage` - Check RAM utilization
- `get_system_info` - System overview
- `get_cpu_usage` - CPU monitoring

##### Add Additional Swap Space
If swap exhaustion persists:

```bash
# Create additional swap file (2GB example)
fallocate -l 2G ~/swapfile
chmod 600 ~/swapfile
mkswap ~/swapfile

# Enable swap (requires sudo)
sudo swapon ~/swapfile

# Make permanent
echo '/home/user/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

##### Optimize Host System
- Close unused VS Code/opencode instances
- Increase VM RAM if possible (8GB+ recommended)
- Adjust swappiness: `echo 10 | sudo tee /proc/sys/vm/swappiness`

##### Emergency Actions
If system becomes unresponsive:
```bash
# Kill memory-intensive processes
kill -9 <PID>

# Restart containers with new limits
docker-compose down
docker-compose up -d

# Clear system cache
echo 3 | sudo tee /proc/sys/vm/drop_caches
```

#### Prevention
- Monitor memory usage regularly
- Set up alerts for high memory usage (>80% RAM, >50% swap)
- Use memory limits in docker-compose.yml
- Keep system and containers updated

### Web Interface Malfunction

#### Symptoms
- Netdata dashboard shows "No charts to display" error
- Web interface returns HTTP 400 Bad Request or malformed HTML
- API endpoints work correctly but dashboard fails to load
- Browser console shows JavaScript errors or missing static files
- Charts appear blank despite Netdata daemon running

#### Root Cause
The `mode = static-threaded` web server configuration in `netdata-optimized.conf` prevents proper static file serving, causing Netdata's embedded web server to return malformed HTML responses or fail to serve dashboard assets.

#### Solution
1. Edit `netdata-optimized.conf` and remove or comment out the problematic line:
   ```ini
   [web]
   # Remove or comment out this line:
   # mode = static-threaded
   listen backlog = 10
   ```

2. Restart the Netdata container:
   ```bash
   docker-compose restart netdata
   ```

3. Clear browser cache and hard refresh (Ctrl+F5) the dashboard

#### Verification
- Access `http://localhost:19999/` - should display proper Netdata dashboard
- Charts should load and display real-time metrics
- API calls should work: `curl http://localhost:19999/api/v1/info`
- Browser developer tools should show no JavaScript errors

#### Prevention
- Avoid using `mode = static-threaded` in Netdata configuration
- Test web interface after making configuration changes
- Keep Netdata configuration minimal to prevent web server issues