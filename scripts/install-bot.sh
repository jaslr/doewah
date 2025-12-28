#!/bin/bash
# =============================================================================
# Install DOEWAH Bot
# Run this after setup.sh and after filling in /root/.env
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo "Installing DOEWAH bot..."

# Copy bot to correct location
mkdir -p /root/claude-bot
cp "$REPO_DIR/bot/bot.js" /root/claude-bot/

# Install systemd service
cp "$REPO_DIR/systemd/claude-bot.service" /etc/systemd/system/

# Reload systemd
systemctl daemon-reload

# Enable and start
systemctl enable claude-bot
systemctl start claude-bot

# Check status
sleep 2
systemctl status claude-bot --no-pager

echo ""
echo "Bot installed! Check Telegram for the startup message."
echo ""
echo "Useful commands:"
echo "  systemctl status claude-bot   # Check status"
echo "  journalctl -u claude-bot -f   # View logs"
echo "  systemctl restart claude-bot  # Restart bot"
