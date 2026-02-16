# Shellcheck MCP Server Investigation

## Problem Statement

The shellcheck MCP server is not working in OpenCode. The tool `shellcheck_shellcheck` is not available even though:
1. The configuration has `"shellcheck_shellcheck": true` in agent tools
2. The MCP server is defined in opencode.jsonc
3. The shellcheck-mcp-server.py file exists in the container at `/app/shellcheck-mcp-server.py`

## Investigation Timeline

### 2026-02-16

#### Initial Discovery
- OpenCode MCP tools require prefix `{server}_{tool}` format (e.g., `ruff_ruff_check`, `shellcheck_shellcheck`)
- Ruff MCP was working with `ruff_check` and `ruff_format` tools
- Shellcheck was failing with "Tool not found" errors

#### Configuration Fixes Applied
1. Changed all agent tool configurations from `"shellcheck": true` to `"shellcheck_shellcheck": true`
2. Changed all agent tool configurations from `"ruff": true` to `"ruff_ruff_check": true`
3. Changed all agent tool configurations from `"ruff_format": true` to `"ruff_ruff_format": true`

#### Server-Side Bug Fix
Found and fixed a bug in the ruff MCP server (`ruff-mcp-wrapper.py`):

**Original code (broken):**
```python
method = message.get("method", "")
params = {
    k: v
    for k, v in message.items()
    if k not in ["jsonrpc", "method", "id"]
}
params["id"] = message.get("id")
```

**Fixed code:**
```python
method = message.get("method", "")
params = message.get("params", {})
if not isinstance(params, dict):
    params = {}
params["id"] = message.get("id")
```

The server was not properly extracting the `params` object from the MCP request, causing tool calls to fail with "Tool not found: ".

#### Applied Same Fix to Shellcheck
Applied the same fix to `shellcheck-mcp-server.py`:
- Changed from filtering message items to using `message.get("params", {})`
- Added check to ensure params is a dict

#### Timeout Configuration
- Reduced shellcheck timeout from 120000ms to 60000ms in opencode.jsonc

## Current Status

| Component | Status | Notes |
|-----------|--------|-------|
| ruff_ruff_check | ✅ WORKING | Fixed params extraction bug |
| ruff_ruff_format | ✅ WORKING | Fixed params extraction bug |
| shellcheck_shellcheck | ❌ NOT WORKING | MCP server fails to connect |

## Symptoms

1. When calling `shellcheck_shellcheck` tool:
   - Error: "Model tried to call unavailable tool 'shellcheck_shellcheck'"
   - Available tools list does NOT include shellcheck_shellcheck

2. MCP server connection:
   - The shellcheck MCP server runs on-demand (not persistent)
   - Each tool call spawns a new process via `docker exec -i mcp-server-container python3 /app/shellcheck-mcp-server.py`
   - Server times out during initialization

3. The server IS working when tested manually:
   ```bash
   echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' | docker exec -i mcp-server-container python3 /app/shellcheck-mcp-server.py
   # Returns valid response
   ```

## Root Cause Analysis

### Hypothesis 1: On-Demand Execution Timeout
The shellcheck MCP server runs on-demand (stdin/stdout), while ruff runs persistently. The 60-second timeout may not be enough for the initial connection handshake.

### Hypothesis 2: Protocol Incompatibility
The shellcheck server may not be properly implementing the MCP protocol that OpenCode expects.

### Hypothesis 3: Server Not Sending Response for tools/list
The server needs to respond to `tools/list` method during initialization, but may be failing silently.

## Configuration Details

### opencode.jsonc - MCP Server Definition
```jsonc
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
}
```

### opencode.jsonc - Agent Tools
```jsonc
"shellcheck_shellcheck": true,
```

## Next Steps to Debug

1. **Check container logs**: Look at OpenCode logs for shellcheck MCP connection errors
2. **Test MCP protocol manually**: Verify the server responds correctly to all MCP methods
3. **Compare with working ruff server**: Use the working ruff implementation as reference
4. **Try persistent mode**: Run shellcheck server as persistent process instead of on-demand
5. **Add debug logging**: Add print statements to shellcheck-mcp-server.py to trace execution

## Files Modified

1. `/home/ev3lynx/Project/Containerd-mcp-server/mcp-servers/shellcheck/shellcheck-mcp-server.py` - Fixed params extraction
2. `/home/ev3lynx/.config/opencode/opencode.jsonc` - Updated tool names to use prefix format
3. `/home/ev3lynx/Project/Containerd-mcp-server/mcp-servers/ruff/ruff-mcp-wrapper.py` - Fixed params extraction

## References

- Ruff MCP server working implementation: `/home/ev3lynx/Project/Containerd-mcp-server/mcp-servers/ruff/ruff-mcp-wrapper.py`
- Shellcheck MCP server: `/home/ev3lynx/Project/Containerd-mcp-server/mcp-servers/shellcheck/shellcheck-mcp-server.py`
- OpenCode config: `/home/ev3lynx/.config/opencode/opencode.jsonc`
