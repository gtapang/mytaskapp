# Setup — from zero to running Hermes Notes on your Mac

The app is now a cross-platform Electron desktop app: **no Xcode, no Apple
developer tooling** — just Node.js. The same steps work on Linux and Windows.

## 1. Prepare the machine (one-time)

**macOS:**

```sh
# Command Line Tools (provides git). Skip if `git --version` already works.
xcode-select --install

# Homebrew (skip if `brew --version` works)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Node.js 22+
brew install node
node --version   # expect v22 or newer
```

## 2. Configure git (one-time)

```sh
git config --global user.name  "Giovanni Tapang"
git config --global user.email "gtapang@nip.upd.edu.ph"
git config --global init.defaultBranch main
git config --global pull.rebase true
```

## 3. Authenticate to GitHub (one-time)

Easiest path:

```sh
brew install gh
gh auth login        # GitHub.com → HTTPS → login via browser
```

(Or set up an SSH key: `ssh-keygen -t ed25519 -C "gtapang@nip.upd.edu.ph"`,
add `~/.ssh/id_ed25519.pub` to GitHub → Settings → SSH keys.)

## 4. Clone and run

```sh
git clone https://github.com/gtapang/mytaskapp.git
cd mytaskapp
git checkout claude/apple-native-notes-app-wl96he   # until PR #1 is merged

npm install     # downloads dependencies incl. the Electron runtime
npm start       # builds and launches the app
```

That's it. `npm start` rebuilds and launches; run it after every `git pull`.

## 5. Optional integrations (in-app Settings, gear icon)

| Feature | Setup |
|---|---|
| **Markdown mirror** | Defaults to `~/Desktop/M/HermesNotes`; change the folder in Settings |
| **Local AI assists** | Install [Ollama](https://ollama.com) (`brew install ollama`), pull a model (`ollama pull llama3.2`), set the model name in Settings |
| **Hermes** | Enter your Hermes base URL + bearer token |
| **Calendar** | Paste ICS feed URLs (Google Calendar → Settings → "Secret address in iCal format"; iCloud → public calendar link) |

## 6. Everyday workflow

```sh
git pull origin claude/apple-native-notes-app-wl96he
npm install          # only needed when dependencies changed
npm start
```

Quick capture from anywhere: **⌘⇧Space** (Ctrl+Shift+Space on Linux/Windows).

## Verifying a checkout

```sh
npm run typecheck    # strict TypeScript
npm test             # 39 unit tests
npm run build        # production build of main + renderer
```

## Packaging a standalone .app (optional)

```sh
npm run package      # electron-builder --dir → ./dist and ./out
```

(Signing/notarization for distribution is out of scope for a single-user v1;
`npm start` is the intended daily path.)
