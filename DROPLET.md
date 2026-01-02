# Doewah Server (DigitalOcean Droplet)

**IP:** `209.38.85.244`
**User:** `root`
**SSH Key:** `~/.ssh/id_jaslr`

## Quick Reference

```bash
# SSH into the droplet (using ~/.ssh/config alias)
ssh droplet

# Or the full command:
ssh -i ~/.ssh/id_jaslr root@209.38.85.244
```

## What Lives on This Droplet

| Service | Port | Description |
|---------|------|-------------|
| SSH | 22 | Shell access, Claude Code |
| WebSocket | 8405 | Real-time app communication |
| Updates | 8406 | OTA update server for app |

### Systemd Services

```bash
# View status
systemctl status claude-bot        # Telegram bot
systemctl status doewah-updates    # Update server (port 8406)
systemctl status doewah-ws         # WebSocket server (port 8405)

# Restart services
systemctl restart claude-bot
systemctl restart doewah-updates
systemctl restart doewah-ws

# View logs
journalctl -u claude-bot -f
journalctl -u doewah-updates -f
journalctl -u doewah-ws -f
```

### Directory Structure on Droplet

```
/root/
├── doewah/                    # Main repo (git clone)
│   ├── bot/                   # Telegram bot
│   ├── ws/                    # WebSocket + Updates servers
│   └── releases/              # Published APKs
│       ├── version.json       # Current version info
│       └── doewah-x.x.x.apk   # APK files
├── termux-key.b64             # SSH key for app (base64 encoded)
├── logs/                      # Server logs
└── projects/                  # Other project repos
```

## Connection Methods

### 1. From Terminal (Local Machine)

```bash
# Standard SSH
ssh -i ~/.ssh/id_jaslr root@209.38.85.244

# Run Claude Code on droplet
ssh -i ~/.ssh/id_jaslr root@209.38.85.244 -t "claude"
```

### 2. From Doewah App

1. Open app
2. Tap **Settings** (gear icon)
3. Choose **Launch Claude** or **Launch Bash**
4. App fetches SSH key from server and connects automatically

### 3. From Any Device (With SSH Client)

The app's SSH key is served at: `http://209.38.85.244:8406/termux-key`

```bash
# Download and use the key
curl -s http://209.38.85.244:8406/termux-key | base64 -d > /tmp/key
chmod 600 /tmp/key
ssh -i /tmp/key root@209.38.85.244
```

## Update Server Endpoints

| Endpoint | Purpose |
|----------|---------|
| `GET /version` | Returns current app version JSON |
| `GET /download` | Downloads latest APK |
| `GET /termux-key` | Returns base64-encoded SSH private key |

```bash
# Check current version
curl http://209.38.85.244:8406/version

# Example response:
# {"version":"0.2.9","buildNumber":20,"apkFile":"doewah-0.2.9-release.apk",...}
```

## SSH Key Setup (If You Need to Regenerate)

On the droplet:

```bash
# Generate new ed25519 key
ssh-keygen -t ed25519 -f /root/termux-key -N "" -C "termux-access"

# Add public key to authorized_keys
cat /root/termux-key.pub >> ~/.ssh/authorized_keys

# Base64 encode for the update server
base64 -w0 /root/termux-key > /root/termux-key.b64

# Restart update server
systemctl restart doewah-updates
```

## Common Tasks

### Deploy Code Changes to Droplet

```bash
# From local machine
source .env
ssh -i $DROPLET_SSH_KEY root@$DROPLET_IP "cd /root/doewah && git pull && systemctl restart claude-bot"
```

### Publish New App Version

```bash
# 1. Bump version in app/pubspec.yaml
# 2. Build APK
npm run app:build

# 3. Publish to droplet
npm run app:publish
```

### Check What's Running

```bash
# On the droplet
ps aux | grep node
systemctl list-units --type=service --state=running | grep doewah
```

## Troubleshooting

### SSH "Broken Pipe" Disconnects

Idle SSH connections get dropped. Fix by adding keep-alive to `~/.ssh/config`:

```bash
# In ~/.ssh/config
Host droplet
  HostName 209.38.85.244
  User root
  IdentityFile ~/.ssh/id_jaslr
  ServerAliveInterval 60
  ServerAliveCountMax 3

# Global fallback for all hosts
Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
```

Now just use `ssh droplet` instead of the full command.

### Random Characters on Mouse Click (Terminal Garbage)

This happens when tmux/vim/htop enable mouse reporting mode and don't clean it up on exit.

**Quick fix:** Run `reset` in terminal.

**Permanent fix:** Add to `~/.bashrc`:
```bash
# Reset mouse reporting mode on shell start
printf '\e[?1000l\e[?1002l\e[?1003l\e[?1006l' 2>/dev/null
```

### Can't Connect via SSH

```bash
# Check if SSH is running
ssh -v -i ~/.ssh/id_jaslr root@209.38.85.244

# Common issues:
# - Wrong key: Make sure you're using id_jaslr
# - Key permissions: chmod 600 ~/.ssh/id_jaslr
```

### App Says "Failed to Fetch SSH Key"

```bash
# Check if update server is running
curl http://209.38.85.244:8406/version

# If not responding, restart it
ssh -i ~/.ssh/id_jaslr root@209.38.85.244 "systemctl restart doewah-updates"
```

### Update Server Returns 404

```bash
# Check if version.json exists
ssh -i ~/.ssh/id_jaslr root@209.38.85.244 "cat /root/doewah/releases/version.json"

# Republish if missing
npm run app:publish
```

## Environment Variables

Required in `.env` for local development:

```bash
DROPLET_IP="209.38.85.244"
DROPLET_SSH_KEY="$HOME/.ssh/id_jaslr"
WS_PORT="8405"
UPDATES_PORT="8406"
```

## Threads and Project Directories

When you create a thread in the app, you can select a project. This sets the working directory for Claude:

| Project Selection | Working Directory |
|-------------------|-------------------|
| Livna | `/root/projects/livna` |
| Brontiq | `/root/projects/brontiq` |
| ORCHON | `/root/projects/orchon` |
| Doewah | `/root/projects/doewah` |
| Other (no selection) | `/root` |

The orchestrator uses project context files in `/root/doewah/contexts/*.md` to understand each project.

### Adding a New Project

```bash
# On the droplet:
# 1. Clone the repo
cd /root/projects
git clone git@github.com:jaslr/your-repo.git

# 2. Create a context file (optional but helpful)
cat > /root/doewah/contexts/your-repo.md << 'EOF'
## Description
What this project does

## Aliases
- repo
- your-repo

## Deploy
**Platform**: Fly.io / Vercel / etc.
EOF

# 3. Restart WS server to reload contexts
systemctl restart doewah-ws
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     YOUR PHONE / DEVICE                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    DOEWAH APP                            │   │
│  │  • Check for updates (port 8406)                         │   │
│  │  • SSH terminal to droplet (port 22)                     │   │
│  │  • Launch Claude Code remotely                           │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                 DIGITALOCEAN DROPLET (209.38.85.244)            │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   SSH :22    │  │  WS :8405    │  │ Updates :8406│          │
│  │              │  │              │  │              │          │
│  │ • Shell      │  │ • Real-time  │  │ • /version   │          │
│  │ • Claude     │  │   messaging  │  │ • /download  │          │
│  │              │  │              │  │ • /termux-key│          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│  Systemd Services:                                               │
│  • claude-bot (Telegram bot)                                     │
│  • doewah-updates (Update server)                                │
└─────────────────────────────────────────────────────────────────┘
```
