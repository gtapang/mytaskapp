# Hermes Notes — Architecture

Single-user, offline-first, cross-platform desktop app: markdown notes with
tightly linked tasks, a calm Today day-starter, in-app calendar, Eisenhower
planning, local AI assists, and Hermes as the higher-order orchestration
backend.

> **History.** v0.1 was an Apple-native implementation (SwiftUI, SwiftData,
> Foundation Models, App Intents) — it lives in git history up to commit
> `0a7ce66`. v0.2 removed the Apple-native requirement: the app now runs on
> macOS, Linux, and Windows with no Xcode dependency, and the whole codebase
> builds and verifies on Linux.

## Stack

| Concern | Choice |
|---|---|
| Shell | Electron (main + preload + renderer, strict context isolation) |
| Language | TypeScript everywhere |
| UI | React + a single small calm-theme CSS file |
| App state persistence | Plain JSON store with atomic writes (single user; no native deps) |
| File persistence | Markdown mirror of notes into `~/Desktop/M/HermesNotes` (configurable) |
| Local AI | Optional Ollama-compatible endpoint; honest rule-based fallbacks without one |
| Calendar | In-app month grid + day list; optional ICS feed subscriptions |
| Quick capture | In-app + global shortcut (⌘/Ctrl+Shift+Space) from anywhere on the desktop |
| Orchestration | Hermes HTTP API + durable offline outbox |
| Tests | Vitest (38 tests) + an Electron boot-smoke under Xvfb in CI |

## Layering

```
┌────────────────────────────────────────────────────────────┐
│ renderer (React)                                           │
│ Today · Notes · Calendar · Tasks · Eisenhower · Inbox      │
│ + NoteEditor, QuickCapture, Settings, Eisenhower drag/drop │
├────────────────────────────────────────────────────────────┤
│ preload: typed contextBridge (window.hermes ≙ shared/api)  │
├────────────────────────────────────────────────────────────┤
│ main (Electron)                                            │
│  JsonStore (atomic JSON, source of truth)                  │
│  MarkdownMirror bridge (write-through on note saves)       │
│  HermesSyncService (pull context/captures, drain outbox)   │
│  Intelligence (Ollama chat w/ JSON output, or fallbacks)   │
│  ICS fetch + cache · global shortcut · IPC handlers        │
├────────────────────────────────────────────────────────────┤
│ core (pure TS, no Electron imports — fully unit-tested)    │
│  types · markdown block/inline parser · front matter       │
│  note file codec · MarkdownMirror · slug                   │
│  HermesClient + HermesOutbox · DayStart digest/prompt/     │
│  fallback · ICS parser                                     │
└────────────────────────────────────────────────────────────┘
```

`src/core` is dependency-free, portable TypeScript ported 1:1 (same tests)
from the original Swift core. `src/main` touches Electron and the filesystem.
The renderer only talks through the typed `window.hermes` bridge.

## Object model (`src/core/types.ts`)

- **Note** — id, title, markdown body, timestamps, tags, folder, notebook,
  project, pinned, archived, optional reminder.
- **TaskItem** — id, title, status, priority, Eisenhower quadrant, due date,
  optional reminder, `noteId` link, project, tags, timestamps.
- **Project**, **InboxItem** (local capture | Telegram, with dedupe
  `sourceId` and classification suggestion), **HermesContextItem** (email |
  calendar | summary with importance score / rule hit).

Notes and tasks are *separate first-class objects*; linking is a foreign key
(`task.noteId`), never an embedding. Dates are ISO strings so the store stays
plain JSON.

## Hybrid intelligence split

**Local model (optional, Ollama-compatible endpoint in Settings):**
note summarization, tag suggestion, task extraction, inbox classification,
day-start briefing. All prompts request strict JSON (`format: "json"`), are
validated on arrival, and every feature degrades to a deterministic fallback
(markdown checkbox extraction, rule-based day-start summary) — the app never
fabricates intelligence and never requires a model.

**Hermes (server, durable, cross-system):** important email surfacing,
important calendar surfacing (hybrid rules + inferred importance), wiki
routing of notes into the markdown knowledge workflow, Telegram capture in
(→ Inbox) and structured pushback out, cross-system orchestration.

The app never blocks on Hermes: reads populate `HermesContextItem` rows when
a sync succeeds (on launch, window focus, pull-to-refresh); writes go through
a **durable outbox** persisted as JSON, drained with retry, ordering
preserved, poisoned actions dropped after 8 attempts.

### Hermes API contract (v1, expected by `core/hermes.ts`)

```
GET  /v1/context/important?since=<iso8601>   → HermesContextPayload[]
GET  /v1/capture/telegram?since=<iso8601>    → TelegramCapturePayload[]
POST /v1/wiki/route          {noteID, title, document, tags}
POST /v1/telegram/push       {text, replyToCaptureID?}
```

Bearer-token auth; base URL + token configurable in Settings.

## Local-first storage

The JSON store (`<userAppData>/hermes-notes/data.json`, atomic tmp+rename
writes) is the operational store. `MarkdownMirror` mirrors every note as a
markdown file with YAML front matter (id, title, tags, timestamps, links)
under the preferred directory — default `~/Desktop/M/HermesNotes`, changeable
in Settings. Layout:

```
<root>/Notes/<notebook|folder|Unfiled>/<slug>-<id8>.md
<root>/Archive/…                       (archived notes)
```

The mirror is write-through on save, human-readable, and aligned with the
Hermes wiki workflow (wiki routing sends the exact same document format).

## Calendar

The Calendar screen merges three sources per day: events from subscribed
**ICS feeds** (tolerant minimal parser, 10-minute cache), **tasks due** that
day, and **Hermes time context** (`occursAt`). Event creation stays in the
user's real calendar app in v1; events can spawn linked notes/tasks.

## Calm-UI rules (`theme.css`)

One accent, neutral surfaces, generous whitespace, progressive disclosure
(organization lives in the note's Organize sheet), reminders as a single
quiet glyph, no badges except the Inbox count.

## Verification

- `npm run typecheck` — strict TS across renderer + main configs.
- `npm test` — 38 Vitest tests over the core (markdown, front matter, codec,
  mirror on a real temp fs, Hermes client/outbox with a mock transport,
  day-start, ICS) and the JSON store.
- `scripts/smoke.cjs` — boots the **real app** under Xvfb, fails on any
  renderer error, captures a screenshot. Runs in CI on every push.
