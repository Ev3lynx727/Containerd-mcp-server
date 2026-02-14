# Containerd MCP Server

A Docker-based MCP (Model Context Protocol) server setup with multiple integrations.

## Directory Structure

```
.
├── scripts/           # Utility scripts
│   ├── setup/        # Setup and installation scripts
│   ├── utils/        # Utility and maintenance scripts
│   └── testing/      # Testing scripts
├── mcp-servers/      # MCP server implementations
│   ├── shellcheck/   # ShellCheck MCP server
│   ├── ruff/         # Ruff Python linter MCP server
│   └── start-mcp-servers.sh
├── docker/           # Docker configuration
│   ├── Dockerfile
│   ├── Dockerfile.stdio-proxy
│   └── docker-compose.yml
├── config/           # Configuration files
│   └── .env
├── docs/             # Documentation
│   └── agent.md
├── logs/             # Log files
├── mcp-data/         # MCP data directory
├── mcp-proxy/        # MCP proxy directory
└── .github/          # GitHub configuration
```

## Quick Start

### Setup
```bash
# Setup MCP Gateway
./scripts/setup/setup_mcp_gateway.sh

# Setup MCP servers
./scripts/setup/install-mcp-servers.sh
```

### Restart Gateway
```bash
./scripts/utils/restart-gateway.sh
```

## Scripts Reference

### Setup Scripts
- `setup_mcp_gateway.sh` - Setup MCP Gateway
- `setup-mcp-catalog.sh` - Setup MCP catalog
- `setup-zsh-shell.sh` - Configure zsh shell for opencode
- `install-mcp-servers.sh` - Install MCP servers (ruff, shellcheck)

### Utility Scripts
- `restart-gateway.sh` - Restart MCP Gateway with Bearer token update
- `restart-gateway.py` - Python version of restart script
- `rebuild-and-deploy.sh` - Rebuild and deploy containers
- `run-container.sh` - Run container scripts

### Testing Scripts
- `test-mcp-tools.sh` - Test MCP tools (ruff, shellcheck)

## MCP Servers

### Included Servers
- **ShellCheck** - Shell script linting (`mcp-servers/shellcheck/`)
- **Ruff** - Python linting and formatting (`mcp-servers/ruff/`)
- **Markdownlint** - Markdown linting (`mcp-servers/`)

## Docker

Build and run:
```bash
cd docker
docker-compose up -d
```

## License

See LICENSE file for details.
