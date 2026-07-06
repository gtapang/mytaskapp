# Hermes Notes

A calm, single-user, offline-first **desktop** app for notes + tasks: quick
capture into an Inbox, a **Today** day-starter, in-app **Calendar**, dedicated
**Eisenhower** planning, markdown notes with tightly linked (but separate)
tasks — with optional local-AI assists and **Hermes** as the orchestration
backend (email/calendar importance, Telegram capture, wiki routing).

Cross-platform (macOS / Linux / Windows) via Electron + TypeScript + React.
No Xcode, no platform lock-in. Design rationale in
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md); machine setup in
[`docs/SETUP.md`](docs/SETUP.md).

> v0.1 was Apple-native (SwiftUI/SwiftData/Foundation Models); it lives in
> git history up to `0a7ce66`. v0.2 removed the Apple-native requirement.

## Run it

```sh
npm install
npm start
```

Requires Node 22+. Quick capture from anywhere: ⌘⇧Space / Ctrl+Shift+Space.

## Layout

```
src/core/       Pure TypeScript, no Electron: domain types, markdown block +
                inline parser, front-matter note codec, markdown file mirror,
                Hermes client + durable offline outbox, day-start logic,
                ICS parser. Fully unit-tested.
src/main/       Electron main: JSON store (atomic writes), mirror bridge,
                Hermes sync service, local-AI layer (Ollama or fallbacks),
                ICS fetching, global shortcut, typed IPC.
src/preload/    contextBridge exposing the typed API (src/shared/api.ts).
src/renderer/   React UI: Today · Notes · Calendar · Tasks · Eisenhower ·
                Inbox, note editor with read mode, quick capture, settings.
tests/          Vitest suite (38 tests).
scripts/smoke.cjs  Boots the real app (Xvfb in CI), screenshots, fails on
                   renderer errors.
```

## The six screens

| Screen | Purpose |
|---|---|
| Today | Calm day starter: briefing, due tasks, events, Hermes-important items, quick capture |
| Notes | Markdown notes — edit/read toggle, search, pin, archive; organization behind a sheet |
| Calendar | Month grid + day list merging ICS events, due tasks, Hermes time context |
| Tasks | Separate first-class tasks: due dates, reminders, priority, note links |
| Eisenhower | Dedicated 2×2 planning matrix with drag-and-drop |
| Inbox | Process captures (local + Telegram) into notes, tasks, or both |

## Local-first storage

App state lives in an atomic JSON store; every note is mirrored as a
markdown file with YAML front matter under `~/Desktop/M/HermesNotes`
(configurable) — human-readable, durable, and aligned with the Hermes wiki
workflow.

## Intelligence

- **Local (optional):** point Settings at any Ollama-compatible endpoint for
  summaries, tag suggestions, task extraction, inbox classification, and the
  day-start briefing. Without a model, honest rule-based fallbacks apply.
- **Hermes:** important email/calendar surfacing, Telegram capture in and
  structured pushback out, wiki routing — all writes through a durable
  offline outbox, so the app never blocks on the network.

## Verify

```sh
npm run typecheck && npm test && npm run build
```

CI runs those plus a full Electron boot-smoke under Xvfb on every push.
