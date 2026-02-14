#!/bin/bash
#
# test-mcp-tools.sh - Test ruff and shellcheck MCP tools
#

echo "============================================================"
echo " Testing MCP Tools: ruff and shellcheck"
echo "============================================================"
echo

# Create test files
echo "[INFO] Creating test files..."

# Test Python file with issues
cat > /tmp/test_python.py << 'EOF'
import os
import sys

x = 1
y=2
z = x+y

print("Hello World")
EOF

# Test shell script with issues
cat > /tmp/test_shell.sh << 'EOF'
#!/bin/bash

echo $1
cd $(dirname $0)
EOF

echo "[INFO] Test files created"
echo

# Test ruff
echo "------------------------------------------------------------"
echo " Testing ruff tool"
echo "------------------------------------------------------------"
echo "Command: docker exec -i mcp-server-container python3 /app/ruff-mcp-wrapper.py"
echo

# Send MCP initialize request to ruff
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}' | docker exec -i mcp-server-container python3 /app/ruff-mcp-wrapper.py &
sleep 1
echo

# Test shellcheck
echo "------------------------------------------------------------"
echo " Testing shellcheck tool"
echo "------------------------------------------------------------"
echo "Command: docker exec -i mcp-server-container python3 /app/shellcheck-mcp-server.py"
echo

# Send MCP initialize request to shellcheck
echo '{"jsonrpc": "2.0", "id": 1, "method": "initialize", "protocolVersion": "2024-11-05", "capabilities": {}, "clientInfo": {"name": "test", "version": "1.0"}}' | docker exec -i mcp-server-container python3 /app/shellcheck-mcp-server.py &
sleep 1
echo

# Cleanup
rm -f /tmp/test_python.py /tmp/test_shell.sh

echo "============================================================"
echo " Test Complete"
echo "============================================================"
echo
echo "To use these tools in agents:"
echo "  - lint agent: automatically has shellcheck and ruff"
echo "  - build agent: automatically has shellcheck and ruff"
echo
echo "Example usage:"
echo '  @lint Check this shell script for issues: /path/to/script.sh'
echo '  @lint Lint this Python file: /path/to/file.py'
