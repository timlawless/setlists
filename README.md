# Band setlist app

A mobile app for bands (iOS and Android): setlists with tempo, key, chords and notes, a metronome with an
optional flash, several setlists per band, several bands per user, change history, and offline use.

## Layout
| Folder | What it is |
|---|---|
| `prototype/` | Interactive UI prototype (sample data). The UI reference for the app. |
| `core/` | TypeScript library with the logic that must be right: change history, offline queue, metronome scheduler. Tested. |
| `docs/architecture.md` | Decisions, data model, privacy, versioning, offline, open questions. |
| `docs/roadmap.md` | What is done and what to do next, in order. |
| `AGENTS.md` | Ground rules for AI coding agents and new contributors. |

## Run the tests
```bash
cd core
npm install
npm test          # 23 tests
npm run typecheck
```

## Not built yet
The Expo app itself, the backend, sign-in and invites, and the catalog service. The prototype shows what the
screens should do, and `docs/architecture.md` lists the decisions still open.
