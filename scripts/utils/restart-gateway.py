#!/usr/bin/env python3
"""
restart-gateway.py - Restart MCP Gateway and auto-update Bearer token

This script:
1. Kills any running MCP gateway
2. Starts a new gateway instance
3. Waits for it to generate a Bearer token
4. Extracts the token from logs
5. Updates opencode.jsonc with the new token
"""

import subprocess
import time
import json
import re
import sys
import os
from pathlib import Path

# Configuration
GATEWAY_PORT = 8090
GATEWAY_LOG = "gateway.log"
OPENCODE_CONFIG = Path.home() / ".config/opencode/opencode.jsonc"
TIMEOUT_SECONDS = 30


def log_info(msg):
    print(f"[INFO] {msg}")


def log_success(msg):
    print(f"[SUCCESS] {msg}")


def log_error(msg):
    print(f"[ERROR] {msg}", file=sys.stderr)


def kill_gateway():
    """Kill any running MCP gateway processes."""
    log_info("Stopping existing gateway...")
    try:
        # Find and kill gateway processes
        result = subprocess.run(
            ["pkill", "-f", "docker-mcp.*gateway"], capture_output=True, text=True
        )
        time.sleep(2)  # Wait for processes to terminate
        log_success("Gateway stopped")
        return True
    except Exception as e:
        log_error(f"Failed to stop gateway: {e}")
        return False


def start_gateway():
    """Start the MCP gateway."""
    log_info(f"Starting MCP gateway on port {GATEWAY_PORT}...")
    try:
        # Clear old log file
        if os.path.exists(GATEWAY_LOG):
            os.remove(GATEWAY_LOG)

        # Start gateway in background
        process = subprocess.Popen(
            [
                "docker",
                "mcp",
                "gateway",
                "run",
                "--port",
                str(GATEWAY_PORT),
                "--transport",
                "streaming",
            ],
            stdout=open(GATEWAY_LOG, "w"),
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )

        log_info(f"Gateway started with PID {process.pid}")
        return process
    except Exception as e:
        log_error(f"Failed to start gateway: {e}")
        return None


def wait_for_token(timeout=TIMEOUT_SECONDS):
    """Wait for and extract Bearer token from gateway logs."""
    log_info(f"Waiting for Bearer token (timeout: {timeout}s)...")

    start_time = time.time()
    token = None

    while time.time() - start_time < timeout:
        if os.path.exists(GATEWAY_LOG):
            with open(GATEWAY_LOG, "r") as f:
                content = f.read()
                # Look for Bearer token pattern
                match = re.search(r"Bearer\s+([a-zA-Z0-9]+)", content)
                if match:
                    token = match.group(1)
                    log_success(f"Bearer token found: {token}")
                    return token

        time.sleep(1)

    log_error("Timeout waiting for Bearer token")
    return None


def update_opencode_config(token):
    """Update opencode.jsonc with new Bearer token."""
    log_info("Updating opencode.jsonc...")

    if not OPENCODE_CONFIG.exists():
        log_error(f"Config file not found: {OPENCODE_CONFIG}")
        return False

    try:
        # Read the config file
        with open(OPENCODE_CONFIG, "r") as f:
            content = f.read()

        # Update the Bearer token using regex
        # Match the Authorization header in mcp-gateway section
        pattern = r'("Authorization":\s*"Bearer\s+)[a-zA-Z0-9]+(")'
        replacement = rf"\g<1>{token}\g<2>"

        new_content = re.sub(pattern, replacement, content)

        if new_content == content:
            log_error("Could not find Bearer token in config to update")
            return False

        # Write back
        with open(OPENCODE_CONFIG, "w") as f:
            f.write(new_content)

        log_success(f"Updated {OPENCODE_CONFIG}")
        return True

    except Exception as e:
        log_error(f"Failed to update config: {e}")
        return False


def verify_gateway():
    """Verify gateway is running and accessible."""
    log_info("Verifying gateway...")

    # Check if process is running
    result = subprocess.run(
        ["pgrep", "-f", "docker-mcp.*gateway"], capture_output=True, text=True
    )

    if result.returncode != 0:
        log_error("Gateway process not found")
        return False

    # Check if port is listening
    result = subprocess.run(["netstat", "-tlnp"], capture_output=True, text=True)

    if f":{GATEWAY_PORT}" not in result.stdout:
        log_error(f"Port {GATEWAY_PORT} not listening")
        return False

    log_success("Gateway is running and listening")
    return True


def main():
    print("=" * 60)
    print(" MCP Gateway Restart & Token Update Script")
    print("=" * 60)
    print()

    # Step 1: Kill existing gateway
    kill_gateway()

    # Step 2: Start new gateway
    process = start_gateway()
    if not process:
        sys.exit(1)

    # Step 3: Wait for token
    token = wait_for_token()
    if not token:
        log_error("Failed to get Bearer token")
        sys.exit(1)

    # Step 4: Verify gateway is running
    time.sleep(2)
    if not verify_gateway():
        log_error("Gateway verification failed")
        sys.exit(1)

    # Step 5: Update opencode.jsonc
    if not update_opencode_config(token):
        log_error("Failed to update configuration")
        sys.exit(1)

    print()
    print("=" * 60)
    print(" RESTART COMPLETE")
    print("=" * 60)
    print(f"Gateway URL: http://localhost:{GATEWAY_PORT}/mcp")
    print(f"Bearer Token: {token}")
    print(f"Config updated: {OPENCODE_CONFIG}")
    print()
    print("You may need to restart opencode for changes to take effect.")


if __name__ == "__main__":
    main()
