# MCP Servers Documentation

This document provides comprehensive documentation for the MCP (Model Context Protocol) servers available in this project.

## Overview

MCP servers extend the capabilities of AI assistants by providing specialized tools. This project includes four MCP servers:

1. **ShellCheck** - Shell script linting and analysis
2. **Ruff** - Python linting and formatting
3. **Markdownlint** - Markdown linting
4. **Fabric MCP** - Microsoft Fabric integration (HTTP mode on port 3004)

## Table of Contents

- [ShellCheck MCP Server](#shellcheck-mcp-server)
- [Ruff MCP Server](#ruff-mcp-server)
- [Markdownlint MCP Server](#markdownlint-mcp-server)
- [Fabric MCP Server](#fabric-mcp-server)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage Examples](#usage-examples)
- [Troubleshooting](#troubleshooting)

---

## ShellCheck MCP Server

### Purpose

ShellCheck is a static analysis tool for shell scripts that provides warnings and suggestions for bash/sh shell scripts. It helps identify bugs, syntax issues, and potential problems in shell scripts.

### Location

- **Wrapper:** `mcp-servers/shellcheck/shellcheck-mcp-server.py`
- **Container Path:** `/app/shellcheck-mcp-server.py`

### Features

- Supports multiple shell dialects: bash, sh, dash, ksh
- Detects syntax errors and bugs
- Identifies deprecated or non-portable constructs
- Provides suggestions for improvements
- Uses GCC-style output format for easy parsing

### Tool: `shellcheck`

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `file_path` | string | Yes | Path to the shell script to check |
| `shell` | string | No | Shell dialect (bash, sh, dash, ksh). Default: bash |

#### Example Usage

```json
{
  "name": "shellcheck",
  "arguments": {
    "file_path": "/path/to/script.sh",
    "shell": "bash"
  }
}
```

#### Example Output

```
/path/to/script.sh:10:5: warning: Variable appears unused. Verify use (or export if used externally). [SC2034]
/path/to/script.sh:15:10: error: Double quote to prevent globbing and word splitting. [SC2086]
```

---

## Ruff MCP Server

### Purpose

Ruff is an extremely fast Python linter and code formatter, written in Rust. It provides comprehensive Python code analysis and formatting capabilities.

### Location

- **Wrapper:** `mcp-servers/ruff/ruff-mcp-wrapper.py`
- **Container Path:** `/app/ruff-mcp-wrapper.py`

### Features

- 10-100x faster than traditional Python linters
- Compatible with Black formatting
- Supports auto-fixing of issues
- Implements flake8 rules and more
- Built-in formatter

### Tools

#### 1. `ruff_check`

Lint Python files and directories.

##### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Path to Python file or directory |
| `fix` | boolean | No | Apply auto-fixes. Default: false |

##### Example Usage

```json
{
  "name": "ruff_check",
  "arguments": {
    "path": "./my_project",
    "fix": true
  }
}
```

##### Example Output

```
my_project/main.py:15:1: E402 Module level import not at top of file
my_project/utils.py:23:5: F841 Local variable `x` is assigned but never used
Found 2 errors.
```

#### 2. `ruff_format`

Format Python files and directories.

##### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `path` | string | Yes | Path to Python file or directory |
| `check` | boolean | No | Check only, don't modify. Default: false |

##### Example Usage

```json
{
  "name": "ruff_format",
  "arguments": {
    "path": "./my_project",
    "check": false
  }
}
```

##### Example Output

```
1 file reformatted
```

---

## Markdownlint MCP Server

### Purpose

Markdownlint is a Node.js-based linter for Markdown files that helps enforce consistent style and detect issues in Markdown documentation.

### Location

- **Implementation:** `mcp-servers/markdownlint-mcp-server.js`
- **Container Path:** `/app/markdownlint-mcp-server.js`

### Features

- Enforces Markdown style consistency
- Detects common Markdown errors
- Configurable rules
- Supports auto-fixing

### Tools

The Markdownlint MCP server provides tools for linting and fixing Markdown files.

---

## Fabric MCP Server

### Purpose

Fabric MCP Server provides integration with Microsoft Fabric, allowing AI assistants to interact with Fabric workspaces, datasets, reports, and other resources.

### Installation

Installed via pip in the Dockerfile:
```dockerfile
RUN pip3 install ms-fabric-mcp-server --break-system-packages
```

### Location

- **Package:** `ms-fabric-mcp-server`
- **Container Path:** Available as Python module
- **Port:** 3004 (HTTP mode)

### Features

- Microsoft Fabric workspace management
- Dataset operations
- Report interactions
- Data pipeline management
- Real-time connectivity via HTTP

### Configuration

The Fabric MCP server is configured in the container's MCP config:

```json
"fabric_mcp": {
  "type": "local",
  "command": ["python3", "-m", "ms_fabric_mcp_server"],
  "enabled": true
}
```

### Startup

The server starts automatically on port 3004:
```bash
python3 -m ms_fabric_mcp_server --port 3004 --host 0.0.0.0
```

### Access

When running, the Fabric MCP server is accessible at:
- **HTTP:** `http://localhost:3004`

---

## Installation

### Automated Installation

Run the installation script to copy all MCP server wrappers to the container:

```bash
./scripts/setup/install-mcp-servers.sh
```

This script will:
1. Check if the mcp-server-container is running
2. Copy ruff-mcp-wrapper.py to the container
3. Copy shellcheck-mcp-server.py to the container
4. Verify the wrappers are in place

### Manual Installation

If you need to install individual MCP servers:

#### ShellCheck

```bash
docker cp mcp-servers/shellcheck/shellcheck-mcp-server.py mcp-server-container:/app/
docker exec mcp-server-container chmod +x /app/shellcheck-mcp-server.py
```

#### Ruff

```bash
docker cp mcp-servers/ruff/ruff-mcp-wrapper.py mcp-server-container:/app/
docker exec mcp-server-container chmod +x /app/ruff-mcp-wrapper.py
```

#### Markdownlint

```bash
docker cp mcp-servers/markdownlint-mcp-server.js mcp-server-container:/app/
```

### Verification

Verify the MCP servers are installed:

```bash
docker exec mcp-server-container ls -la /app/*.py /app/*.js
```

You should see:
- `/app/shellcheck-mcp-server.py`
- `/app/ruff-mcp-wrapper.py`
- `/app/markdownlint-mcp-server.js`

---

## Configuration

### opencode.jsonc Configuration

Add the following to your `~/.config/opencode/opencode.jsonc`:

```json
{
  "mcp": {
    "shellcheck": {
      "type": "local",
      "command": [
        "docker",
        "exec",
        "-i",
        "mcp-server-container",
        "python3",
        "/app/shellcheck-mcp-server.py"
      ],
      "enabled": true,
      "timeout": 60000
    },
    "ruff": {
      "type": "local",
      "command": [
        "docker",
        "exec",
        "-i",
        "mcp-server-container",
        "python3",
        "/app/ruff-mcp-wrapper.py"
      ],
      "enabled": true,
      "timeout": 60000
    }
  }
}
```

### Agent Configuration

To enable linting tools for agents, add them to the agent's tools section:

```json
{
  "agent": {
    "lint": {
      "tools": {
        "shellcheck": true,
        "ruff": true
      }
    }
  }
}
```

---

## Usage Examples

### Using with @lint Agent

The @lint agent is specifically designed for linting tasks:

```
@lint Check this shell script: ./scripts/setup/install-mcp-servers.sh
```

```
@lint Lint all Python files in the project
```

```
@lint Format the Python file: ./mcp-servers/ruff/ruff-mcp-wrapper.py
```

### Using with @build Agent

The @build agent can use linting tools during development:

```
@build Create a Python script and run ruff on it
```

```
@build Check this shell script for issues before committing
```

### Direct Tool Usage

You can also invoke the tools directly:

```
Run shellcheck on ./docker/docker-compose.yml
```

```
Use ruff to check ./scripts/utils/restart-gateway.sh
```

---

## Troubleshooting

### Issue: "Connection closed" Error

**Cause:** Using the CLI tool directly instead of the MCP wrapper.

**Solution:** Ensure you're using the Python wrappers:
- `/app/shellcheck-mcp-server.py` (not `shellcheck`)
- `/app/ruff-mcp-wrapper.py` (not `ruff`)

### Issue: "401 Unauthorized" Error

**Cause:** Bearer token has expired after gateway restart.

**Solution:** Run the restart script to update the token:
```bash
./scripts/utils/restart-gateway.sh
```

### Issue: "Container not found"

**Cause:** The mcp-server-container is not running.

**Solution:** Start the containers:
```bash
cd docker && docker-compose up -d
```

### Issue: Wrapper Not Found

**Cause:** MCP wrappers haven't been copied to the container.

**Solution:** Run the install script:
```bash
./scripts/setup/install-mcp-servers.sh
```

### Issue: Python Version Error

**Cause:** Some MCP servers require Python 3.12+, but the container has 3.11.

**Solution:** The wrappers are designed to be compatible with Python 3.11+. If you encounter version issues, ensure you're using the wrapper scripts, not the upstream packages.

---

## Architecture

### Why Wrappers?

ShellCheck and Ruff are command-line tools, not native MCP servers. The wrappers:

1. Implement the MCP protocol (JSON-RPC over stdio)
2. Translate MCP tool calls to CLI commands
3. Format CLI output as MCP responses
4. Handle errors gracefully

### Wrapper Design

Each wrapper:
- Reads JSON-RPC requests from stdin
- Parses the tool name and parameters
- Executes the underlying CLI tool
- Formats output as JSON-RPC responses
- Writes responses to stdout

### Container Integration

The wrappers are copied into the mcp-server-container at `/app/` and executed via `docker exec`. This ensures:
- Consistent environment
- Access to installed tools
- Proper isolation

---

## Additional Resources

- [ShellCheck Documentation](https://www.shellcheck.net/)
- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)
- Project Scripts: `./scripts/setup/`, `./scripts/utils/`

---

## Contributing

To add a new MCP server:

1. Create a wrapper script in `mcp-servers/<name>/`
2. Implement the MCP protocol (JSON-RPC over stdio)
3. Add installation steps to `install-mcp-servers.sh`
4. Update this documentation
5. Test with `test-mcp-tools.sh`

---

**Last Updated:** 2026-02-15
**Version:** 1.1.0
