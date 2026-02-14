#!/bin/bash
#
# setup-zsh-shell.sh - Configure opencode to use zsh shell
#

set -e

echo "============================================================"
echo " Configuring opencode to use zsh shell"
echo "============================================================"
echo

# Find zsh location
echo "[INFO] Searching for zsh installation..."

ZSH_PATH=""

# Check common zsh locations
if [ -x "/bin/zsh" ]; then
    ZSH_PATH="/bin/zsh"
elif [ -x "/usr/bin/zsh" ]; then
    ZSH_PATH="/usr/bin/zsh"
elif command -v zsh &> /dev/null; then
    ZSH_PATH=$(command -v zsh)
fi

if [ -z "$ZSH_PATH" ]; then
    echo "[ERROR] zsh not found! Please install zsh first:"
    echo "  sudo apt-get install zsh    # Debian/Ubuntu"
    echo "  sudo yum install zsh        # RHEL/CentOS"
    echo "  brew install zsh            # macOS"
    exit 1
fi

echo "[SUCCESS] Found zsh at: $ZSH_PATH"
echo

# Check if it's a symlink and get the real path
if [ -L "$ZSH_PATH" ]; then
    REAL_PATH=$(readlink -f "$ZSH_PATH")
    echo "[INFO] $ZSH_PATH is a symlink to: $REAL_PATH"
fi

# Determine config directory
if [ -n "$XDG_CONFIG_HOME" ]; then
    CONFIG_DIR="$XDG_CONFIG_HOME/opencode"
else
    CONFIG_DIR="$HOME/.config/opencode"
fi

echo "[INFO] Config directory: $CONFIG_DIR"

# Create directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

CONFIG_FILE="$CONFIG_DIR/.opencode.json"

# Check if config file already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "[INFO] Existing config found at: $CONFIG_FILE"
    echo "[INFO] Merging zsh configuration with existing config..."
    
    # Backup existing config
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    echo "[INFO] Backup created"
    
    # Use Python to merge JSON files
    python3 << EOF
import json
import sys

# Read existing config
with open("$CONFIG_FILE", "r") as f:
    existing = json.load(f)

# Add/Update shell configuration
existing["shell"] = {
    "path": "$ZSH_PATH",
    "args": ["-l"]
}

# Write merged config
with open("$CONFIG_FILE", "w") as f:
    json.dump(existing, f, indent=2)

print("[SUCCESS] Merged zsh configuration with existing config")
EOF
else
    # Create new config file
    cat > "$CONFIG_FILE" << EOF
{
  "shell": {
    "path": "$ZSH_PATH",
    "args": ["-l"]
  }
}
EOF
    echo "[SUCCESS] Created new config: $CONFIG_FILE"
fi
echo
echo "Configuration:"
echo "  Shell path: $ZSH_PATH"
echo "  Args: [-l]"
echo
echo "============================================================"
echo " Setup Complete"
echo "============================================================"
echo
echo "To verify zsh is working:"
echo "  1. Restart opencode"
echo "  2. Run: echo \$SHELL"
echo "  3. Should output: $ZSH_PATH"
echo
echo "The -l flag ensures zsh loads your .zshrc file"
