# DOEWAH

**D**igital**O**cean **W**orkstation for **E**xecuting **A**utomated **H**elpers

A cloud Ubuntu environment for running Claude Code tasks remotely, triggered from your phone via Telegram.

## What This Does

- Run Claude Code from your phone while away from your computer
- Get notified when tasks complete
- Support multiple GitHub accounts (jaslr, jvp-ux)
- Support multiple Cloudflare accounts
- Deploy to Cloudflare, Fly.io, Firebase, GCP
- Continue work from your PC via VS Code Remote SSH

## Architecture

```
┌─────────────────┐      ┌──────────────────────────────────────────┐
│  Your Phone     │      │  DigitalOcean Droplet (DOEWAH)           │
│  (Telegram)     │─────▶│                                          │
└─────────────────┘      │  ┌─────────────────┐                     │
                         │  │  Telegram Bot   │                     │
┌─────────────────┐      │  └────────┬────────┘                     │
│  Your PC        │      │           │                              │
│  (VS Code SSH)  │─────▶│  ┌────────▼────────┐    ┌─────────────┐  │
└─────────────────┘      │  │   Claude Code   │───▶│  tmux       │  │
                         │  └────────┬────────┘    │  sessions   │  │
                         │           │             └─────────────┘  │
                         │  ┌────────▼────────┐                     │
                         │  │  Deploy CLIs    │                     │
                         │  │  wrangler, fly  │                     │
                         │  │  firebase, gcp  │                     │
                         │  └─────────────────┘                     │
                         └──────────────────────────────────────────┘
```

## Quick Start

### 1. Create Droplet

- Ubuntu 24.04 LTS
- Basic $6/mo (1GB RAM) or $12/mo (2GB RAM)
- Sydney region
- Add your SSH key

### 2. Run Setup

SSH into your droplet and run:

```bash
ssh -i ~/.ssh/id_jaslr root@209.38.85.244

# Clone this repo
git clone https://github.com/jaslr/doewah.git
cd doewah

# Run setup
chmod +x setup.sh
./setup.sh
```

### 3. Configure Credentials

```bash
nano /root/.env
# Fill in all your API keys and tokens
```

### 4. Set Up SSH Keys for GitHub

```bash
# For jaslr account
ssh-keygen -t ed25519 -f ~/.ssh/id_jaslr -C "jaslr-github"
cat ~/.ssh/id_jaslr.pub
# Add this to https://github.com/settings/keys (logged in as jaslr)

# For jvp-ux account
ssh-keygen -t ed25519 -f ~/.ssh/id_jvpux -C "jvpux-github"
cat ~/.ssh/id_jvpux.pub
# Add this to https://github.com/settings/keys (logged in as jvp-ux)

# Test
ssh -T git@github.com-jaslr
ssh -T git@github.com-jvpux
```

### 5. Log In to Cloud Services

```bash
wrangler login              # Cloudflare
fly auth login              # Fly.io
firebase login --no-localhost
gcloud auth login --no-launch-browser
```

### 6. Create Telegram Bot

1. Message @BotFather on Telegram
2. Send `/newbot`
3. Name it (e.g., "DOEWAH")
4. Get the bot token
5. Start a chat with your bot, send "hello"
6. Get your chat ID from: `https://api.telegram.org/bot<TOKEN>/getUpdates`
7. Add both to `/root/.env`

### 7. Install Bot

```bash
cd /root/doewah
chmod +x scripts/install-bot.sh
./scripts/install-bot.sh
```

## Usage

### Telegram Commands

| Command | Description |
|---------|-------------|
| `/fix <project> <task>` | Fix bug, auto-commit, push, deploy |
| `/task <project> <task>` | Run task without auto-deploy |
| `/projects` | List cloned projects |
| `/clone <account> <repo>` | Clone repo (jaslr or jvpux) |
| `/status` | List active tmux sessions |
| `/logs <session>` | View session logs |
| `/kill <session>` | Kill a session |
| `/help` | Show all commands |

### Examples

```
/clone jaslr flashlight-db
/fix flashlight-db Fix the pagination bug on brand list page
/task flashlight-db Add loading skeletons to all list views
/status
/logs flashlight-db-1704067200
```

## File Locations

| Path | Description |
|------|-------------|
| `/root/.env` | All credentials and API keys |
| `/root/projects/` | Cloned git repositories |
| `/root/logs/` | Task execution logs |
| `/root/claude-bot/` | Telegram bot |
| `/root/.ssh/config` | SSH config for multiple GitHub accounts |

## VS Code Remote SSH

**Quick connect:**
```bash
ssh -i ~/.ssh/id_jaslr root@209.38.85.244
```

**Or add to local `~/.ssh/config`:**
```
Host doewah
    HostName 209.38.85.244
    User root
    IdentityFile ~/.ssh/id_jaslr
```

Then in VS Code:
1. Install "Remote - SSH" extension
2. Ctrl+Shift+P → "Remote-SSH: Connect to Host"
3. Select "doewah"

## Monitoring

```bash
# Bot status
systemctl status claude-bot

# Bot logs (live)
journalctl -u claude-bot -f

# Active sessions
tmux list-sessions

# Attach to session
tmux attach -t session-name

# Detach from session
Ctrl+B, then D
```

## ORCHON Integration

DoeWah works with [ORCHON](https://github.com/jaslr/orchon) (the Infrastructure Observatory) to answer questions about deployments across all projects.

### What DoeWah Asks ORCHON

When a user asks "what failed last?" or "how are deployments looking?", DoeWah queries ORCHON's backend:

| Endpoint | Purpose |
|----------|---------|
| `GET /api/deployments/last-failure` | Most recent failed deployment |
| `GET /api/deployments/failures?limit=N` | Last N failures |
| `GET /api/status/summary` | Overall health + counts |

### Authentication

DoeWah authenticates to ORCHON using:
```
Authorization: Bearer <OBSERVATORY_API_SECRET>
```

The `OBSERVATORY_API_SECRET` in DoeWah's `.env` must match the `API_SECRET` in ORCHON's observatory-backend.

### Response Format

ORCHON returns deployment data like:
```json
{
  "deployment": {
    "projectId": "livna",
    "projectName": "Livna",
    "status": "failure",
    "provider": "fly",
    "branch": "main",
    "completedAt": "2025-12-29T10:30:00Z"
  }
}
```

### For ORCHON Developers

If you're here from ORCHON to integrate:

1. DoeWah lives at `/home/chip/doewah`
2. Bot code is in `bot/bot.js`
3. Add `OBSERVATORY_API_SECRET` to `.env` (same value as your `API_SECRET`)
4. DoeWah will call your endpoints at `https://observatory-backend.fly.dev`

## Cost

- DigitalOcean Droplet: **$6-12/mo** (hard cap, won't exceed)
- Telegram: Free
- Claude Code: Your existing Anthropic API usage

## Portability

This setup is documented in code. If you want to move to another provider:

1. Spin up Ubuntu 24.04 VM
2. Clone this repo
3. Run setup.sh
4. Configure .env
5. Done

The only DigitalOcean-specific thing is the VM itself.

.
..
