#!/bin/bash
#
# organize-repo.sh - Reorganize repository into clean folder structure
#

set -e

echo "============================================================"
echo " Repository Organization Script"
echo "============================================================"
echo

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create directory structure
create_structure() {
    log_info "Creating directory structure..."
    
    mkdir -p scripts/{setup,utils,testing}
    mkdir -p mcp-servers/{shellcheck,ruff}
    mkdir -p docker
    mkdir -p config
    mkdir -p docs
    mkdir -p logs
    
    log_success "Directory structure created"
}

# Move files to appropriate directories
organize_files() {
    log_info "Organizing files..."
    
    # Scripts - Setup
    [ -f "setup_mcp_gateway.sh" ] && mv setup_mcp_gateway.sh scripts/setup/ && log_info "Moved setup_mcp_gateway.sh"
    [ -f "setup-mcp-catalog.sh" ] && mv setup-mcp-catalog.sh scripts/setup/ && log_info "Moved setup-mcp-catalog.sh"
    [ -f "setup-zsh-shell.sh" ] && mv setup-zsh-shell.sh scripts/setup/ && log_info "Moved setup-zsh-shell.sh"
    [ -f "install-mcp-servers.sh" ] && mv install-mcp-servers.sh scripts/setup/ && log_info "Moved install-mcp-servers.sh"
    
    # Scripts - Utils
    [ -f "restart-gateway.sh" ] && mv restart-gateway.sh scripts/utils/ && log_info "Moved restart-gateway.sh"
    [ -f "restart-gateway.py" ] && mv restart-gateway.py scripts/utils/ && log_info "Moved restart-gateway.py"
    [ -f "rebuild-and-deploy.sh" ] && mv rebuild-and-deploy.sh scripts/utils/ && log_info "Moved rebuild-and-deploy.sh"
    [ -f "run-container.sh" ] && mv run-container.sh scripts/utils/ && log_info "Moved run-container.sh"
    
    # Scripts - Testing
    [ -f "test-mcp-tools.sh" ] && mv test-mcp-tools.sh scripts/testing/ && log_info "Moved test-mcp-tools.sh"
    
    # MCP Servers
    [ -f "shellcheck-mcp-server.py" ] && mv shellcheck-mcp-server.py mcp-servers/shellcheck/ && log_info "Moved shellcheck-mcp-server.py"
    [ -f "ruff-mcp-wrapper.py" ] && mv ruff-mcp-wrapper.py mcp-servers/ruff/ && log_info "Moved ruff-mcp-wrapper.py"
    [ -f "markdownlint-mcp-server.js" ] && mv markdownlint-mcp-server.js mcp-servers/ && log_info "Moved markdownlint-mcp-server.js"
    [ -f "start-mcp-servers.sh" ] && mv start-mcp-servers.sh mcp-servers/ && log_info "Moved start-mcp-servers.sh"
    
    # Docker
    [ -f "Dockerfile" ] && mv Dockerfile docker/ && log_info "Moved Dockerfile"
    [ -f "Dockerfile.stdio-proxy" ] && mv Dockerfile.stdio-proxy docker/ && log_info "Moved Dockerfile.stdio-proxy"
    [ -f "docker-compose.yml" ] && mv docker-compose.yml docker/ && log_info "Moved docker-compose.yml"
    [ -f ".dockerignore" ] && mv .dockerignore docker/ && log_info "Moved .dockerignore"
    
    # Config
    [ -f ".env" ] && mv .env config/ && log_info "Moved .env"
    
    # Docs
    [ -f "agent.md" ] && mv agent.md docs/ && log_info "Moved agent.md"
    
    # Logs
    for log in gateway.log gateway-catalog.log gateway-final.log gateway-new.log; do
        [ -f "$log" ] && mv "$log" logs/ && log_info "Moved $log"
    done
    
    log_success "Files organized"
}

# Create README for new structure
create_readme() {
    log_info "Creating README..."
    
    cat > README.md << 'EOF'
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
EOF

    log_success "Created README.md"
}

# Update .gitignore
update_gitignore() {
    log_info "Updating .gitignore..."
    
    cat > .gitignore << 'EOF'
# Dependencies
node_modules/

# Logs
logs/*.log
*.log

# Environment
config/.env
.env.local

# Cache
.ruff_cache/
__pycache__/
*.pyc

# Data
mcp-data/*
!mcp-data/.gitkeep

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Temporary
tmp/
temp/
*.tmp
EOF

    log_success "Updated .gitignore"
}

# Create .gitkeep for empty directories
create_gitkeep() {
    log_info "Creating .gitkeep files..."
    touch logs/.gitkeep
    log_success "Created .gitkeep files"
}

# Main execution
main() {
    echo "This will reorganize the repository structure."
    echo "Make sure you have committed any changes before proceeding."
    echo
    read -p "Continue? (y/n) " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_warn "Aborted"
        exit 0
    fi
    
    create_structure
    organize_files
    create_readme
    update_gitignore
    create_gitkeep
    
    echo
    echo "============================================================"
    echo " Repository Organization Complete"
    echo "============================================================"
    echo
    log_success "Structure created:"
    echo "  📁 scripts/setup/     - Setup scripts"
    echo "  📁 scripts/utils/     - Utility scripts"
    echo "  📁 scripts/testing/   - Testing scripts"
    echo "  📁 mcp-servers/       - MCP server implementations"
    echo "  📁 docker/            - Docker configuration"
    echo "  📁 config/            - Configuration files"
    echo "  📁 docs/              - Documentation"
    echo "  📁 logs/              - Log files"
    echo
    log_info "Next steps:"
    echo "  1. Review the changes"
    echo "  2. Update any hardcoded paths in scripts"
    echo "  3. Test the setup: ./scripts/setup/install-mcp-servers.sh"
    echo "  4. Commit the reorganization"
}

main "$@"
