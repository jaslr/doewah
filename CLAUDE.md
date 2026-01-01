# DOEWAH - Claude Code Instructions

## Deployment

### Backend (Bot + WebSocket)
Push to main, then deploy to droplet:
```bash
git push && ssh root@209.38.85.244 "cd /root/doewah && git pull && systemctl restart claude-bot doewah-ws doewah-updates"
```

### Flutter App (OTA Auto-Update)
The app auto-updates via the self-hosted OTA server. To deploy a new version:

```bash
# 1. Build release APK with secrets
cd app
flutter build apk --release \
  --dart-define=ORCHON_API_SECRET=<secret> \
  --dart-define=WS_URL=ws://209.38.85.244:8405

# 2. Publish to OTA server
npm run publish:apk
```

Existing installed apps will prompt to update on next launch.

**First-time install / APK download:**
```
http://209.38.85.244:8406/download
```

### ORCHON Integration
The Flutter app fetches deployments from ORCHON at `https://observatory-backend.fly.dev`.

| DOA Config | ORCHON Config | Purpose |
|------------|---------------|---------|
| `ORCHON_API_SECRET` (dart-define) | `API_SECRET` (env) | Bearer token auth |

Both must have the same value. Set in Fly.io secrets for ORCHON backend.

## Architecture

- `bot/` - Telegram bot interface
- `orchestrator/` - Brain that interprets messages and routes actions
- `contexts/` - Project context files (one per project)

## Integrations

| Service | Config | Purpose |
|---------|--------|---------|
| ORCHON | `OBSERVATORY_API_SECRET` | Deployment status queries |
| Sentry | `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_BASE_URL` | Error tracking queries |

## Adding New Integrations

Follow the ORCHON/Sentry pattern in `orchestrator/index.js`:
1. Add config constants at top
2. Add API query function
3. Add `execute*` function(s) for actions
4. Add detection patterns in `detectAction()`
5. Add cases in `executeAction()` switch
