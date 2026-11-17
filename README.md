# Band setlist app

A free, non-commercial web app (PWA) for bands: setlists with tempo, key, chords, notes and links, a metronome with an optional flash, a full-screen gig mode, several setlists per band, several bands per user, change history, and offline use. It works on iPhone, Android, tablets and laptops, and can be installed from the browser.

Live app: https://timlawless.github.io/setlists/

## Repository layout

| Folder | Purpose |
|---|---|
| `app/` | Live PWA files published to GitHub Pages: `index.html`, `config.js`, service worker, manifest and icons. |
| `core/` | Platform-free TypeScript logic and tests. The web app does not yet import this library. |
| `docs/` | Project documentation: architecture, roadmap, tester guide and go-live checklist. Not published. |
| `sql/` | Supabase SQL files. Run in the documented order. Never publish these files. |
| `prototype/` | UI prototype/reference, not the live application. |
| `archive/` | Older experiments and previous app copies retained for reference; not deployed. |
| `backups/` | Existing backups. |
| `.github/workflows/` | GitHub Actions workflow that deploys `app/` to GitHub Pages. |

## Supabase setup

1. Create a Supabase project and run the SQL files in `sql/` in the order documented in `docs/architecture.md`.
2. Deploy the `lookup-song` Edge Function and configure its `GETSONGBPM_API_KEY` secret.
3. Configure the authentication email service and templates.
4. Put the project URL and the **publishable** key in `app/config.js`. Never use the secret or service-role key.

## Deployment

GitHub Actions publishes the contents of `app/` to GitHub Pages when changes are pushed to `main`. In the repository's GitHub settings, set Pages' build and deployment source to **GitHub Actions**. The site remains at https://timlawless.github.io/setlists/.

The `app/config.js` file contains the public Supabase project URL and publishable key. Do not put secrets, SQL files or private notes in `app/`.

## Tests

```bash
cd core
npm install
npm test
npm run typecheck
```

## Product status

See `docs/roadmap.md` for completed work, outstanding items and backlog. See `docs/architecture.md` for design and data decisions. `AGENTS.md` contains contribution and safety rules; `AI_HANDOFF.MD` is the current handoff snapshot.
