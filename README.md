# Hermes Notes

A single-user, offline-first, Apple-native note-taking app with tightly
linked tasks, a calm **Today** day-starter, in-app **Calendar**, a dedicated
**Eisenhower** planning screen, and an **Inbox** fed by quick capture and
Telegram (via Hermes). Apple's Foundation Models handle fast on-device
intelligence; **Hermes** stays the higher-order orchestration backend.

Built per [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) from the Hermes
Notes PRD.

## Layout

```
HermesNotesCore/   Pure-Swift package: domain types, markdown engine,
                   note file mirror (front matter + .md), Hermes client
                   + durable offline outbox, day-start logic.
                   Builds and tests on ANY platform, including Linux:
                       cd HermesNotesCore && swift test
HermesNotesApp/    Apple shell: SwiftUI screens, SwiftData models,
                   Foundation Models intelligence, App Intents, EventKit
                   calendar, notifications, Metal polish shaders.
project.yml        XcodeGen definition for the iOS app target.
```

This split is deliberate: the core is verifiable from Linux (CI runs it in a
Swift container), while everything Apple-only stays in a thin shell that
builds on a Mac — locally or on the `macos` CI job.

## Building the app (Mac, Xcode 26+)

```sh
brew install xcodegen
xcodegen generate
open HermesNotes.xcodeproj
```

Run the `HermesNotes` scheme on an iOS 26 simulator or device. Foundation
Models features require a device with Apple Intelligence enabled; the app
degrades gracefully (rule-based day-start, no suggestions) everywhere else.

> The core package was developed and tested on Linux (`swift test`, 28 tests
> passing). The SwiftUI shell was authored off-Mac and gets its build
> verification from the macOS CI job / your first local build.

## Running core tests anywhere

```sh
cd HermesNotesCore
swift test        # works on macOS or Linux (Swift 6+)
```

## The six screens

| Screen | Purpose |
|---|---|
| Today | Calm day starter: briefing, due tasks, events, Hermes-important items, quick capture |
| Notes | Markdown notes — edit/read toggle, search, pin, archive; organization behind a sheet |
| Calendar | In-app month grid + day list merging events, due tasks, Hermes time context |
| Tasks | Separate first-class tasks: due dates, reminders, priority, note links |
| Eisenhower | Dedicated 2×2 planning matrix with drag-and-drop |
| Inbox | Process captures (local + Telegram) into notes, tasks, or both |

## Hermes configuration

Settings (gear on Today) → base URL + bearer token. The expected API contract
is documented in `docs/ARCHITECTURE.md`. All Hermes writes go through a
durable offline outbox; the app never blocks on the network.

## Local-first storage

SwiftData is the operational store. Every note is mirrored as a markdown file
with YAML front matter — on Mac-class targets under `~/Desktop/M/HermesNotes`,
on iOS in a folder you pick in Settings (e.g. one that syncs to `~/Desktop/M`).
