#!/usr/bin/env python3
"""
shellcheck-mcp-server.py - MCP Server wrapper for ShellCheck

This provides shellcheck functionality as an MCP server that can be
used by opencode and other MCP clients.
"""

import asyncio
import json
import sys
import subprocess
import os
from typing import Any


class ShellCheckMCPServer:
    def __init__(self):
        self.tools = {
            "shellcheck": {
                "description": "Run ShellCheck on shell scripts",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "file_path": {
                            "type": "string",
                            "description": "Path to the shell script to check",
                        },
                        "shell": {
                            "type": "string",
                            "description": "Shell dialect (bash, sh, dash, ksh)",
                            "default": "bash",
                        },
                    },
                    "required": ["file_path"],
                },
            }
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
                "serverInfo": {"name": "shellcheck-mcp-server", "version": "1.0.0"},
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

        if tool_name in ["shellcheck", "shellcheck_shellcheck"]:
            return await self.run_shellcheck(params.get("id"), arguments)
        else:
            return {
                "jsonrpc": "2.0",
                "id": params.get("id"),
                "error": {"code": -32601, "message": f"Tool not found: {tool_name}"},
            }

    async def run_shellcheck(self, request_id: Any, arguments: dict) -> dict:
        """Run shellcheck on a file."""
        file_path = arguments.get("file_path", "")
        shell = arguments.get("shell", "bash")

        if not file_path or not os.path.exists(file_path):
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32602, "message": f"File not found: {file_path}"},
            }

        try:
            # Run shellcheck
            result = subprocess.run(
                ["shellcheck", "-f", "json", "-s", shell, file_path],
                capture_output=True,
                text=True,
                timeout=30,
            )

            # Parse the JSON output
            try:
                issues = json.loads(result.stdout) if result.stdout else []
            except json.JSONDecodeError:
                issues = []

            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "result": {
                    "content": [
                        {
                            "type": "text",
                            "text": json.dumps(
                                {
                                    "issues": issues,
                                    "exit_code": result.returncode,
                                    "file": file_path,
                                },
                                indent=2,
                            ),
                        }
                    ]
                },
            }
        except subprocess.TimeoutExpired:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32603, "message": "Shellcheck timed out"},
            }
        except Exception as e:
            return {
                "jsonrpc": "2.0",
                "id": request_id,
                "error": {"code": -32603, "message": f"Shellcheck error: {str(e)}"},
            }

    async def run(self):
        """Main server loop."""
        while True:
            try:
                line = await asyncio.get_event_loop().run_in_executor(
                    None, sys.stdin.readline
                )
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
            except json.JSONDecodeError:
                continue
            except Exception as e:
                await self.send_message(
                    {
                        "jsonrpc": "2.0",
                        "id": None,
                        "error": {"code": -32603, "message": str(e)},
                    }
                )


if __name__ == "__main__":
    server = ShellCheckMCPServer()
    asyncio.run(server.run())
