# DOEWAH - Claude Code Instructions

## Project Overview

**DOEWAH** (Digital Ocean Workstation for Executing Automated Helpers) is a mobile-first DevOps control plane with three interfaces:
- **Telegram Bot** - Command-based chat for quick actions
- **Flutter App** - Native mobile app with deployment dashboard + Claude threads
- **WebSocket Server** - Real-time communication backbone

---

## Integration: DOA ↔ ORCHON

### MOU (Memorandum of Understanding)

| Project | Role | Consumes | Provides |
|---------|------|----------|----------|
| **ORCHON** | Infrastructure Observatory | GitHub webhooks, provider APIs | Deployment status API |
| **DOA** | DevOps Control Plane | ORCHON deployment data | Fix actions via Claude threads |

**Data Flow:**
```
GitHub/Cloudflare/Fly.io → ORCHON (monitors) → DOA (displays + acts)
                                                    ↓
                                              Claude Code (fixes)
```

### Handshake Configuration

| DOA Side | ORCHON Side | Notes |
|----------|-------------|-------|
| `ORCHON_API_SECRET` (dart-define at build) | `API_SECRET` (Fly.io secret) | **Must match** |
| `ORCHON_URL` (defaults to prod) | Backend URL | `https://observatory-backend.fly.dev` |

**To update the shared secret:**
1. Generate new secret: `openssl rand -hex 32`
2. DOA: Rebuild app with `--dart-define=ORCHON_API_SECRET=<new>`
3. ORCHON: `fly secrets set API_SECRET=<new> -a observatory-backend`

### API Endpoints Consumed

| Endpoint | Purpose | Used By |
|----------|---------|---------|
| `GET /api/deployments/recent?limit=100` | Recent deployments | Flutter home screen |
| `GET /api/deployments/failures?limit=5` | Failed deployments | Failure alerts |

### Files to Update When Changing Integration

**DOA:**
- `app/lib/core/config.dart` - ORCHON URL + secret config
- `app/lib/core/orchon/orchon_service.dart` - API client + endpoints
- `app/lib/models/deployment.dart` - Data model (must match ORCHON schema)

**ORCHON:**
- `observatory-backend/.env.example` - Document API_SECRET
- `observatory-backend/src/config/env.ts` - Secret validation
- `observatory-backend/src/routes/api.ts` - Deployment endpoints

---

## Infrastructure Choices

| Component | Platform | Why |
|-----------|----------|-----|
| Bot + WebSocket | DigitalOcean Droplet (209.38.85.244) | Persistent SSH, systemd services, tmux sessions for Claude Code |
| Flutter OTA | Self-hosted on droplet (port 8406) | Bypass Play Store, instant updates |
| ORCHON Backend | Fly.io | Free tier, Postgres included, auto-sleep |
| ORCHON Frontend | Cloudflare Pages | Free, global CDN, direct wrangler deploys |

**Ports on Droplet:**
| Port | Service |
|------|---------|
| 8405 | WebSocket server (doewah-ws) |
| 8406 | OTA update server (doewah-updates) |
| 22 | SSH |

---

## Deployment

### IMPORTANT: Git Push ≠ Production Deploy

| Action | What it does | Does NOT do |
|--------|--------------|-------------|
| `git push` | Backs up code to GitHub | Deploy to droplet, publish APK |
| `npm run app:ship` | Build + publish APK to OTA | Push to git |
| `npm run droplet:deploy` | Pull code + restart services | Build/publish APK |

**To fully deploy changes, you need BOTH git push AND the relevant deploy command.**

### Backend (Bot + WebSocket)
```bash
# 1. Push to git (backup)
git push

# 2. Deploy to droplet (production)
npm run droplet:deploy
# OR manually:
ssh root@209.38.85.244 "cd /root/doewah && git pull && systemctl restart claude-bot doewah-ws doewah-updates"
```

### Flutter App (OTA Auto-Update)
```bash
# 1. Bump version in app/pubspec.yaml

# 2. Build + publish (gets secret from /home/chip/orchon/.env)
cd app
flutter build apk --release \
  --dart-define=ORCHON_API_SECRET=$(grep API_SECRET /home/chip/orchon/.env | cut -d= -f2) \
  --dart-define=WS_URL=ws://209.38.85.244:8405

# 3. Publish to OTA server
cd .. && npm run app:publish

# OR all-in-one (if you set up .env with secrets):
npm run app:ship
```

Existing installed apps will prompt to update on next launch.

**First-time install / APK download:**
```
http://209.38.85.244:8406/download
```

**Check current OTA version:**
```
curl http://209.38.85.244:8406/version
```

---

## Architecture

- `bot/` - Telegram bot interface
- `orchestrator/` - Brain that interprets messages and routes actions
- `app/` - Flutter mobile app
- `ws/` - WebSocket + OTA update servers
- `contexts/` - Project context files (one per project)

## Other Integrations

| Service | Config | Purpose |
|---------|--------|---------|
| Sentry | `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_BASE_URL` | Error tracking queries |

## Adding New Integrations

Follow the ORCHON/Sentry pattern in `orchestrator/index.js`:
1. Add config constants at top
2. Add API query function
3. Add `execute*` function(s) for actions
4. Add detection patterns in `detectAction()`
5. Add cases in `executeAction()` switch
