# Hermes Notes — Architecture

Single-user, offline-first, Apple-native note-taking app with tightly linked
tasks, a calm Today day-starter, in-app calendar, Eisenhower planning, Apple
on-device intelligence (Foundation Models), and Hermes as the higher-order
orchestration backend.

## Stack

| Concern | Choice |
|---|---|
| Language / UI | Swift 6, SwiftUI |
| App state persistence | SwiftData (source of truth for structured state) |
| File persistence | Markdown mirror of notes into the preferred `~/Desktop/M` directory (macOS) / user-picked bookmarked folder (iOS) |
| On-device AI | Foundation Models framework (`LanguageModelSession` + `@Generable` typed outputs), iOS 26+ |
| System integration | App Intents (Siri, Spotlight, Apple Intelligence) |
| Calendar | EventKit, read-focused in v1, rendered in-app |
| Reminders | Local `UserNotifications`, optional per note/task |
| Rendering polish | SwiftUI `ShaderLibrary` Metal shaders, used sparingly |
| Orchestration | Hermes HTTP API + durable offline outbox |

Minimum deployment target: **iOS 26** (required by Foundation Models). All
Foundation Models call sites are availability-gated behind a protocol so the
app degrades gracefully when Apple Intelligence is unavailable on device.

## Layering: a Linux-buildable core under an Apple shell

The codebase splits into two layers so most of the logic can be built and
tested from any environment (including the Linux containers this project is
developed in), while the product stays fully Apple-native:

```
┌──────────────────────────────────────────────────────────┐
│ HermesNotesApp — Apple shell (Xcode 26 / macOS only)     │
│                                                          │
│  Features (SwiftUI)                                      │
│  Today · Notes · Calendar · Tasks · Eisenhower · Inbox   │
│  ──────────────────────────────────────────────────────  │
│  AppEnvironment (composition root, @Observable services) │
│  ─────────────┬───────────────────┬────────────────────  │
│  Apple AI     │ HermesSyncService │ Platform             │
│  Foundation   │ NoteMirrorService │ EventKit calendar    │
│  Models       │ (bridges to core) │ UNNotifications      │
│  (@Generable) │                   │ App Intents · Metal  │
│  ──────────────────────────────────────────────────────  │
│  SwiftData ModelContainer (operational source of truth)  │
├──────────────────────────────────────────────────────────┤
│ HermesNotesCore — pure Swift package (builds on Linux)   │
│                                                          │
│  Domain types (TaskStatus, EisenhowerQuadrant, …)        │
│  NoteSnapshot value model · Markdown block parser        │
│  FrontMatter + NoteFileCodec + MarkdownFileStore mirror  │
│  HermesClient + payloads + durable HermesOutbox (actor)  │
│  DayStart digest/prompt/fallback logic                   │
│  → `cd HermesNotesCore && swift test` (28 tests, any OS) │
└──────────────────────────────────────────────────────────┘
```

CI runs the core tests in a Linux Swift container on every push and builds
the full app on a macOS runner (`.github/workflows/ci.yml`), so the repo
never needs a local Mac mid-iteration — only for running the app itself.

## Object model (SwiftData)

- **Note** — id, title, markdown body, timestamps, tags, folder, notebook,
  project, pinned, archived, optional reminder, linked tasks.
- **TaskItem** — id, title, status, due date, optional reminder, priority,
  Eisenhower quadrant, linked note, tags, project, timestamps. (`TaskItem`
  avoids colliding with Swift Concurrency's `Task`.)
- **Project** — name, description, active, linked notes/tasks.
- **InboxItem** — source (local capture | Telegram), raw content, processed
  flag, resulting note link, on-device classification result.
- **HermesContextItem** — type (email | calendar | summary), title, summary,
  source metadata, importance score / rule hit, optional note/task link.
- **OutboxAction** — durable queue entry for Hermes calls made while offline.

Notes and tasks are *separate first-class objects*; linking is a relationship,
never an embedding. Enum-typed fields are stored as raw strings for schema
stability, with typed computed accessors.

## Hybrid intelligence split

**Apple Foundation Models (on-device, fast, private):**
- note summarization (`NoteSummary`)
- task extraction from note text (`ExtractedTaskList`)
- tag suggestion (`TagSuggestions`)
- inbox classification (`InboxClassification`: note / task / both / reference)
- lightweight day-start synthesis for the Today header

All of these use `@Generable` structs so model output lands directly in typed
app data — no string parsing. Gated by `SystemLanguageModel.default.availability`.

**Hermes (server, durable, cross-system):**
- important email surfacing
- important calendar item surfacing (hybrid rules + inferred importance)
- wiki routing of selected notes into the markdown knowledge workflow
- Telegram capture in (→ Inbox) and structured pushback out
- any cross-system workflow orchestration

The app never blocks on Hermes: reads populate `HermesContextItem` rows when a
sync succeeds; writes go through `HermesOutbox`, which persists actions in
SwiftData and drains them with retry whenever the app is foregrounded or a
call succeeds. Offline the app is fully usable; Hermes context is simply stale.

### Hermes API contract (v1, expected by `HermesClient`)

```
GET  /v1/context/important?since=<iso8601>     → [HermesContextPayload]
GET  /v1/capture/telegram?since=<iso8601>      → [TelegramCapturePayload]
POST /v1/wiki/route          {noteID, title, markdown, tags}
POST /v1/telegram/push       {text, replyToCaptureID?}
```

Bearer-token auth; base URL + token are user-configurable in Settings and kept
in `UserDefaults` (token in Keychain is a fast follow).

## Local-first storage

SwiftData is the operational store. `MarkdownFileStore` mirrors every note as
a markdown file with YAML front matter (id, title, tags, timestamps, links)
under the preferred directory:

- **macOS-class environments:** `~/Desktop/M/HermesNotes/…`
- **iOS:** a user-selected folder (security-scoped bookmark), defaulting to the
  app's Documents container until one is chosen.

The mirror is write-through on save and is the human-readable/exportable
representation aligned with the Hermes wiki workflow. SwiftData remains the
source of truth for v1; if two-way file sync is ever added it must preserve
the local-first model.

## App Intents

- `CaptureToInboxIntent` — frictionless capture from Siri/Spotlight/Action button.
- `CreateNoteIntent`, `CreateTaskIntent` — structured creation.
- `OpenScreenIntent` + `AppScreen` enum — deep-link to Today/Inbox/etc.
- `NoteEntity` (IndexedEntity) — notes surface in Spotlight and are available
  to Apple Intelligence.
- `HermesNotesShortcuts` — curated phrases ("Capture a thought", "Start my day").

## Metal usage (deliberately small)

A single `CalmEffects.metal` file exposes SwiftUI-compatible `stitchable`
shaders:

- `calmGrain` — a very subtle animated paper grain on the Today header card.
- `quadrantWash` — a soft radial wash behind Eisenhower quadrants that keeps
  drag-and-drop feeling fluid without stacked translucent layers.

Both respect Reduce Motion / Reduce Transparency and are trivially removable —
they are polish, not structure.

## Calm-UI rules encoded in `CalmTheme`

- One accent color, neutral surfaces, generous whitespace.
- Progressive disclosure: organization (tags/folders/notebooks/projects) lives
  behind an organizer sheet, never inline chrome on the note list.
- Reminders render as a single quiet glyph, never a banner.
- No badges/counters except Inbox unprocessed count.

## v1 open questions → current decisions

| Question | Decision |
|---|---|
| DB + file strategy | SwiftData + write-through markdown mirror |
| Linux buildability | Split architecture: `HermesNotesCore` SwiftPM package builds/tests on Linux; Apple shell builds via Xcode locally or on macOS CI runners |
| Desktop path | Same SwiftUI codebase; Mac Catalyst is enabled in project.yml, native macOS target is additive later |
| Calendar provider | EventKit only in v1 (system-configured accounts) |
| Hermes offline auth/queue | Bearer token + SwiftData-backed outbox with retry |
| FM vs Hermes split | FM = anything answerable from on-device text; Hermes = anything needing email/calendar/Telegram/wiki context |
| How much Metal | Two shaders, both optional |

## Building

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
xcodegen generate
open HermesNotes.xcodeproj
```

Requires Xcode 26+ (Foundation Models SDK).
