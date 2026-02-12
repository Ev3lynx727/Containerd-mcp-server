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
    libnspr4 \
    libnss3 \
    libdbus-1-3 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libxkbcommon0 \
    libatspi2.0-0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libgbm1 \
    libasound2 \
    libx11-xcb1 \
    libxcursor1 \
    libxi6 \
    libgtk-3-0 \
    && rm -rf /var/lib/apt/lists/*

# Install mgrep (semantic grep tool for code and documents)
RUN curl -L https://github.com/mixedbread-ai/mgrep/releases/latest/download/mgrep-linux-x64 -o /usr/local/bin/mgrep && \
    chmod +x /usr/local/bin/mgrep

# Install global Node packages for MCP servers
RUN npm install -g \
    @modelcontextprotocol/sdk@1.25.1 \
    @playwright/mcp \
    dkmaker-mcp-rest-api \
    @0xshariq/docker-mcp-server \
    markdownlint

# Install Playwright browsers
RUN npx playwright install

# Create app directory
WORKDIR /app

# Set NODE_PATH for local module resolution
ENV NODE_PATH=/usr/local/lib/node_modules:/app/node_modules

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
      "url": "http://localhost:3051/mcp",
      "enabled": true
    }
    // Docker MCP removed - it's a CLI tool, not HTTP server
  }
}
EOF

# Expose ports for remote MCP servers
EXPOSE 3000-3005

# Copy MCP server files
COPY markdownlint-mcp-server.js /app/markdownlint-mcp-server.js

# Install local dependencies for MCP servers
WORKDIR /app
RUN npm init -y && \
    npm install @modelcontextprotocol/sdk@1.25.1 markdownlint-cli && \
    npm pkg set type=module

# Reset working directory
WORKDIR /app

# Copy startup script
COPY start-mcp-servers.sh /app/start-mcp-servers.sh
RUN chmod +x /app/start-mcp-servers.sh

# Default command: start MCP servers
CMD ["/app/start-mcp-servers.sh"]