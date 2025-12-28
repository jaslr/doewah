#!/bin/bash
set -e

# =============================================================================
# DOEWAH - DigitalOcean Droplet Setup for Claude Code Remote Execution
# =============================================================================
# 
# This script sets up a fresh Ubuntu 24.04 droplet with:
# - Claude Code CLI
# - All deploy CLIs (wrangler, flyctl, gcloud, firebase)
# - Multiple GitHub account SSH access
# - Telegram bot for remote triggering
#
# Run as root on a fresh droplet:
#   curl -fsSL https://raw.githubusercontent.com/jaslr/doewah/main/setup.sh | bash
#
# Or clone and run:
#   git clone https://github.com/jaslr/doewah.git
#   cd doewah
#   ./setup.sh
# =============================================================================

echo "=========================================="
echo "DOEWAH Setup - Starting..."
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# =============================================================================
# STEP 1: System Update & Essential Tools
# =============================================================================
echo ""
echo "[1/8] Updating system and installing essentials..."

apt update && apt upgrade -y
apt install -y git curl wget tmux htop unzip jq build-essential

# =============================================================================
# STEP 2: Install Node.js v22
# =============================================================================
echo ""
echo "[2/8] Installing Node.js v22..."

curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs

echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"

# =============================================================================
# STEP 3: Install Claude Code
# =============================================================================
echo ""
echo "[3/8] Installing Claude Code..."

npm install -g @anthropic-ai/claude-code

echo "Claude Code version: $(claude --version)"

# =============================================================================
# STEP 4: Install Deploy CLIs
# =============================================================================
echo ""
echo "[4/8] Installing deploy CLIs..."

# Cloudflare Wrangler
echo "  - Installing Wrangler..."
npm install -g wrangler

# Fly.io
echo "  - Installing Fly.io CLI..."
curl -L https://fly.io/install.sh | sh
export FLYCTL_INSTALL="/root/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"

# Firebase
echo "  - Installing Firebase CLI..."
npm install -g firebase-tools

# Supabase (use brew or npx - npm global install not supported)
echo "  - Supabase CLI: use 'npx supabase' or install via brew"

# Sentry
echo "  - Installing Sentry CLI..."
npm install -g @sentry/cli

# Google Cloud SDK
echo "  - Installing Google Cloud SDK..."
if [ ! -d "/root/google-cloud-sdk" ]; then
  curl -o /tmp/google-cloud-sdk.tar.gz https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-cli-linux-x86_64.tar.gz
  tar -xf /tmp/google-cloud-sdk.tar.gz -C /root
  /root/google-cloud-sdk/install.sh --quiet --path-update true
  rm /tmp/google-cloud-sdk.tar.gz
fi

# =============================================================================
# STEP 5: Set up directory structure
# =============================================================================
echo ""
echo "[5/8] Creating directory structure..."

mkdir -p /root/projects
mkdir -p /root/claude-bot
mkdir -p /root/.ssh
mkdir -p /root/logs

# =============================================================================
# STEP 6: Set up shell profile
# =============================================================================
echo ""
echo "[6/8] Configuring shell profile..."

cat >> /root/.bashrc << 'BASHRC'

# DOEWAH Configuration
export FLYCTL_INSTALL="/root/.fly"
export PATH="$FLYCTL_INSTALL/bin:$PATH"
export PATH="/root/google-cloud-sdk/bin:$PATH"

# Load environment variables
if [ -f /root/.env ]; then
  set -a
  source /root/.env
  set +a
fi

# Useful aliases
alias ll='ls -la'
alias projects='cd /root/projects'
alias logs='cd /root/logs'
alias bot-logs='journalctl -u claude-bot -f'
alias bot-restart='systemctl restart claude-bot'
alias sessions='tmux list-sessions'

BASHRC

# =============================================================================
# STEP 7: Create .env template if not exists
# =============================================================================
echo ""
echo "[7/8] Setting up environment template..."

if [ ! -f /root/.env ]; then
  cat > /root/.env << 'ENVFILE'
# =============================================================================
# DOEWAH Environment Variables
# =============================================================================
# Fill in your actual values below

# -----------------------------------------------------------------------------
# Anthropic (Claude)
# Get from: https://console.anthropic.com/settings/keys
# -----------------------------------------------------------------------------
export ANTHROPIC_API_KEY=""

# -----------------------------------------------------------------------------
# GitHub Personal Access Tokens
# Get from: https://github.com/settings/tokens (use "classic" tokens)
# Permissions needed: repo, read:org
# -----------------------------------------------------------------------------
export GITHUB_TOKEN_JASLR=""
export GITHUB_TOKEN_JVPUX=""

# -----------------------------------------------------------------------------
# Cloudflare - Account 1 (jasonleslieroberts@gmail.com)
# API Token: https://dash.cloudflare.com/profile/api-tokens
# Account ID: Found in dashboard URL or Overview page
# -----------------------------------------------------------------------------
export CLOUDFLARE_API_TOKEN_PERSONAL=""
export CLOUDFLARE_ACCOUNT_ID_PERSONAL=""

# -----------------------------------------------------------------------------
# Cloudflare - Account 2 (jason@vastpuddle.com.au)
# -----------------------------------------------------------------------------
export CLOUDFLARE_API_TOKEN_VASTPUDDLE=""
export CLOUDFLARE_ACCOUNT_ID_VASTPUDDLE=""

# -----------------------------------------------------------------------------
# Fly.io
# Get token: fly tokens create
# -----------------------------------------------------------------------------
export FLY_API_TOKEN=""

# -----------------------------------------------------------------------------
# Sentry
# Auth Token: https://sentry.io/settings/account/api/auth-tokens/
# -----------------------------------------------------------------------------
export SENTRY_AUTH_TOKEN=""

# -----------------------------------------------------------------------------
# Telegram Bot
# Create bot: Message @BotFather on Telegram, use /newbot
# Get chat ID: Send message to bot, then visit:
#   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
# -----------------------------------------------------------------------------
export TELEGRAM_BOT_TOKEN=""
export TELEGRAM_CHAT_ID=""

# -----------------------------------------------------------------------------
# Default GitHub account for cloning (jaslr or jvpux)
# -----------------------------------------------------------------------------
export DEFAULT_GITHUB_ACCOUNT="jaslr"
ENVFILE

  echo "Created /root/.env template - YOU MUST FILL IN YOUR VALUES"
else
  echo "/root/.env already exists, skipping..."
fi

# =============================================================================
# STEP 8: Set up SSH config for multiple GitHub accounts
# =============================================================================
echo ""
echo "[8/8] Setting up SSH config..."

cat > /root/.ssh/config << 'SSHCONFIG'
# GitHub - jaslr account
Host github.com-jaslr
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_jaslr
    IdentitiesOnly yes

# GitHub - jvp-ux account  
Host github.com-jvpux
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_jvpux
    IdentitiesOnly yes

# Default GitHub (jaslr)
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_jaslr
    IdentitiesOnly yes
SSHCONFIG

chmod 600 /root/.ssh/config

# =============================================================================
# DONE - Print next steps
# =============================================================================
echo ""
echo "=========================================="
echo "DOEWAH Setup Complete!"
echo "=========================================="
echo ""
echo "NEXT STEPS:"
echo ""
echo "1. Fill in your credentials:"
echo "   nano /root/.env"
echo ""
echo "2. Generate SSH keys for GitHub accounts:"
echo "   ssh-keygen -t ed25519 -f ~/.ssh/id_jaslr -C 'jaslr-github'"
echo "   ssh-keygen -t ed25519 -f ~/.ssh/id_jvpux -C 'jvpux-github'"
echo ""
echo "3. Add the public keys to each GitHub account:"
echo "   cat ~/.ssh/id_jaslr.pub  # Add to github.com/jaslr"
echo "   cat ~/.ssh/id_jvpux.pub  # Add to github.com/jvp-ux"
echo ""
echo "4. Test GitHub connections:"
echo "   ssh -T git@github.com-jaslr"
echo "   ssh -T git@github.com-jvpux"
echo ""
echo "5. Log in to cloud services:"
echo "   wrangler login"
echo "   fly auth login"
echo "   firebase login --no-localhost"
echo "   gcloud auth login --no-launch-browser"
echo ""
echo "6. Set up the Telegram bot:"
echo "   cd /root/claude-bot"
echo "   # Copy bot.js here (from doewah repo)"
echo "   systemctl enable claude-bot"
echo "   systemctl start claude-bot"
echo ""
echo "7. Clone your first project:"
echo "   cd /root/projects"
echo "   git clone git@github.com-jaslr:jaslr/your-project.git"
echo ""
echo "=========================================="
