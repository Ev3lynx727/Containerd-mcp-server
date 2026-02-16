#!/usr/bin/env python3
"""
ruff-mcp-wrapper.py - MCP Server wrapper for Ruff

This provides ruff functionality as an MCP server that can be
used by opencode and other MCP clients.
Compatible with Python 3.11+
"""

import asyncio
import json
import sys
import subprocess
from typing import Any


class RuffMCPServer:
    def __init__(self):
        self.tools = {
            "ruff_check": {
                "description": "Run Ruff linter on Python files",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Path to Python file or directory to lint",
                        },
                        "fix": {
                            "type": "boolean",
                            "description": "Apply fixes automatically",
                            "default": False,
                        },
                    },
                    "required": ["path"],
                },
            },
            "ruff_format": {
                "description": "Format Python files using Ruff",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "path": {
                            "type": "string",
                            "description": "Path to Python file or directory to format",
                        },
                        "check": {
                            "type": "boolean",
                            "description": "Check formatting without modifying files",
                            "default": False,
                        },
                    },
                    "required": ["path"],
                },
            },
        }

    async def send_message(self, message: dict):
        """Send a JSON-RPC message to stdout."""
        print(json.dumps(message), flush=True)

    async def handle_initialize(self, params: dict) -> dict:
        """Handle initialize request."""
        return {
            "jsonrpc": "2.0",
            "id": params.get("id"),
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "ruff-mcp-wrapper", "version": "1.0.0"},
            },
        }

    async def handle_tools_list(self, params: dict) -> dict:
        """Handle tools/list request."""
        return {
            "jsonrpc": "2.0",
            "id": params.get("id"),
            "result": {
                "tools": [
                    {
                        "name": name,
                        "description": info["description"],
                        "inputSchema": info["inputSchema"],
                    }
                    for name, info in self.tools.items()
                ]
            },
        }

    async def handle_tool_call(self, params: dict) -> dict:
        """Handle tool call request."""
        tool_name = params.get("name", "")
        arguments = params.get("arguments", {})

        if tool_name == "ruff_check":
            return await self.run_ruff_check(params.get("id"), arguments)
        elif tool_name == "ruff_format":
            return await self.run_ruff_format(params.get("id"), arguments)
        else:
            return {
                "jsonrpc": "2.0",
                "id": params.get("id"),
                "error": {"code": -32601, "message": f"Tool not found: {tool_name}"},
            }

    async def run_ruff_check(self, request_id: Any, arguments: dict) -> dict:
        """Run ruff check on a file or directory."""
        path = arguments.get("path", "")
        fix = arguments.get("fix", False)

        if not path:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32602, "message": "Path is required"},
            }

        try:
            # Build ruff check command
            cmd = ["ruff", "check"]
            if fix:
                cmd.append("--fix")
            cmd.append(path)

            # Run ruff
            result = subprocess.run(cmd, capture_output=True, text=True)

            output = result.stdout if result.stdout else "No issues found!"
            if result.stderr:
                output += "\n" + result.stderr

            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{"type": "text", "text": output}],
                    "isError": result.returncode != 0,
                },
            }
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32603, "message": f"Ruff error: {str(e)}"},
            }

    async def run_ruff_format(self, request_id: Any, arguments: dict) -> dict:
        """Run ruff format on a file or directory."""
        path = arguments.get("path", "")
        check = arguments.get("check", False)

        if not path:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32602, "message": "Path is required"},
            }

        try:
            # Build ruff format command
            cmd = ["ruff", "format"]
            if check:
                cmd.append("--check")
            cmd.append(path)

            # Run ruff
            result = subprocess.run(cmd, capture_output=True, text=True)

            output = result.stdout if result.stdout else "Formatting complete!"
            if result.stderr:
                output += "\n" + result.stderr

            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [{"type": "text", "text": output}],
                    "isError": result.returncode != 0,
                },
            }
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32603, "message": f"Ruff error: {str(e)}"},
            }

    async def run(self):
        """Main server loop."""
        while True:
            try:
                line = await asyncio.get_event_loop().run_in_executor(
                    None, sys.stdin.readline
                )

                if not line:
                    break

                try:
                    message = json.loads(line.strip())
                except json.JSONDecodeError:
                    continue

                method = message.get("method", "")
                params = message.get("params", {})
                if not isinstance(params, dict):
                    params = {}
                params["id"] = message.get("id")

                if method == "initialize":
                    response = await self.handle_initialize(params)
                elif method == "tools/list":
                    response = await self.handle_tools_list(params)
                elif method == "tools/call":
                    response = await self.handle_tool_call(params)
                else:
                    # Unknown method - send error
                    response = {
                        "jsonrpc": "2.0",
                        "id": message.get("id"),
                        "error": {
                            "code": -32601,
                            "message": f"Method not found: {method}",
                        },
                    }

                if message.get("id") is not None:
                    await self.send_message(response)

            except Exception as e:
                print(f"Error: {e}", file=sys.stderr)
                continue


if __name__ == "__main__":
    server = RuffMCPServer()
    asyncio.run(server.run())
