# Livna

## Aliases
- livna-app

## Description
Job quoting and management application for tradies/contractors.

## Repository
- **GitHub Account**: jaslr
- **Repo Name**: livna
- **Local Path**: /root/projects/livna

## Tech Stack
- SvelteKit
- Supabase (database + auth)
- TypeScript

## Deploy Target
- **Platform**: vercel
- **Deploy Command**: Auto-deploys on git push
- **Production URL**: https://livna.app (or similar)

## Monitoring
- **Sentry Project**: livna-stable-construction

## Key Files
- Entry point: src/routes/+page.svelte
- Config: svelte.config.js
- Environment: .env.production

## Notes
- Quote-to-job conversion is a key feature
- Has job_line_items for products in jobs
- Uses feature flags stored in Supabase
