# Dockerfile for MCP Server Container
# This container sets up MCP servers for opencode and other agents

FROM node:24

# Install system dependencies
RUN apt update && apt install -y \
    git \
    gh \
    curl \
    wget \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Install mgrep (semantic grep tool for code and documents)
RUN curl -L https://github.com/mixedbread-ai/mgrep/releases/latest/download/mgrep-linux-x64 -o /usr/local/bin/mgrep && \
    chmod +x /usr/local/bin/mgrep

# Install global Node packages for MCP servers
RUN npm install -g \
    @modelcontextprotocol/sdk \
    @playwright/mcp \
    dkmaker-mcp-rest-api \
    @0xshariq/docker-mcp-server

# Install Playwright browsers
RUN npx playwright install

# Create app directory
WORKDIR /app

# Copy environment file (if available)
COPY .env* ./

# Create opencode config directory
RUN mkdir -p /root/.config/opencode

# Generate MCP config (basic version; can be overridden)
RUN cat > /root/.config/opencode/config.jsonc << 'EOF'
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "mcp_everything": {
      "type": "local",
      "command": ["npx", "-y", "@modelcontextprotocol/server-everything"],
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
    },
    "playwright": {
      "type": "local",
      "command": ["npx", "@playwright/mcp"],
      "enabled": true
    },
    "rest_api_tester": {
      "type": "local",
      "command": ["npx", "dkmaker-mcp-rest-api"],
      "enabled": true
    },
    "mcp-netdata-proxy": {
      "type": "remote",
      "url": "http://localhost:3003/sse",
      "enabled": true
    }
    // Docker MCP removed - it's a CLI tool, not HTTP server
  }
}
EOF

# Expose ports for remote MCP servers
EXPOSE 3000-3005

# Copy startup script
COPY start-mcp-servers.sh /app/start-mcp-servers.sh
RUN chmod +x /app/start-mcp-servers.sh

# Default command: start MCP servers
CMD ["/app/start-mcp-servers.sh"]