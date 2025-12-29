# DOEWAH - Claude Code Instructions

## Deployment

**DOEWAH should auto-deploy on push to main.**

Current state: Manual (`git pull` on droplet required)

TODO: Set up GitHub Actions workflow to SSH into droplet and restart bot on push:
```yaml
# .github/workflows/deploy.yml
name: Deploy to Droplet
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: 209.38.85.244
          username: root
          key: ${{ secrets.DROPLET_SSH_KEY }}
          script: |
            cd /root/doewah
            git pull
            systemctl restart claude-bot
```

**Until auto-deploy is set up**, after pushing changes:
```bash
ssh root@209.38.85.244 "cd /root/doewah && git pull && systemctl restart claude-bot"
```

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
