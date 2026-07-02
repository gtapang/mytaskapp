# MacBook setup — from zero to building Hermes Notes

This walks a fresh (or existing) MacBook through everything needed to clone,
build, and run the app. Do the **prep steps** once in order, then the **git**
and **bootstrap** steps.

---

## 0. Prepare the MacBook (manual, one-time)

These can't be scripted — they involve the App Store, Apple ID, and system
settings.

1. **macOS version.** Xcode 26 needs a recent macOS. Update first:
    - Apple menu →  → System Settings → General → Software Update → install
      everything, reboot.

2. **Disk space.** Xcode + the iOS 26 simulator runtime need roughly **40 GB
   free**. Check: Apple menu →  → System Settings → General → Storage.

3. **Apple ID.** Required to download Xcode from the App Store. Sign in:
   System Settings → *Sign in with your Apple ID* (top of the sidebar).

4. **Install Xcode 26+.** Open the **App Store**, search **Xcode**, install
   (large download — do it on good WiFi). When it finishes, **launch Xcode
   once** and let it install additional components / accept the license.

5. **(Optional) Apple Intelligence** — only needed to exercise the on-device
   Foundation Models features (summarize, tag suggest, task extract, inbox
   classify, day-start briefing). The app runs fine without it, using
   rule-based fallbacks.
    - Requires Apple-silicon hardware (any M-series Mac; on iPhone, 15 Pro or
      newer).
    - Enable: System Settings → **Apple Intelligence & Siri** → turn on.

6. **(Optional) Physical-device runs.** To run on your own iPhone rather than
   the simulator you need a **free Apple Developer account** (just your Apple
   ID) added in Xcode → Settings → Accounts. Not needed for simulator builds.

---

## 1. Command Line Tools + git

macOS ships git via the Xcode Command Line Tools. If you installed full Xcode
above you already have them; otherwise trigger the install:

```sh
xcode-select --install     # skip if `git --version` already works
```

Verify:

```sh
git --version
```

---

## 2. Configure your git identity

Set the name/email your commits are attributed to (once, globally):

```sh
git config --global user.name  "Giovanni Tapang"
git config --global user.email "gtapang@nip.upd.edu.ph"

# Sensible defaults
git config --global init.defaultBranch main
git config --global pull.rebase true
```

---

## 3. Authenticate to GitHub

Pick **one** of these. SSH is the least-friction long term.

### Option A — SSH key (recommended)

```sh
# Generate a key (press Enter to accept the default path; set a passphrase)
ssh-keygen -t ed25519 -C "gtapang@nip.upd.edu.ph"

# Start the agent and add the key
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy the PUBLIC key to your clipboard
pbcopy < ~/.ssh/id_ed25519.pub
```

Then paste it into GitHub → **Settings → SSH and GPG keys → New SSH key**.
Test:

```sh
ssh -T git@github.com     # expect: "Hi gtapang! You've successfully authenticated…"
```

### Option B — GitHub CLI over HTTPS

```sh
brew install gh           # requires Homebrew (the bootstrap script installs it too)
gh auth login             # choose GitHub.com → HTTPS → login via browser
```

---

## 4. Clone the repo and check out the branch

**With SSH (Option A):**

```sh
git clone git@github.com:gtapang/mytaskapp.git
cd mytaskapp
```

**With HTTPS (Option B):**

```sh
git clone https://github.com/gtapang/mytaskapp.git
cd mytaskapp
```

Check out the feature branch that has the app:

```sh
git fetch origin claude/apple-native-notes-app-wl96he
git checkout claude/apple-native-notes-app-wl96he
```

> Once PR #1 is merged, the app will be on `main` and you can skip the
> `fetch`/`checkout` and just work on `main`.

---

## 5. Install build tools + generate the project

The bootstrap script installs Homebrew and XcodeGen (if missing), verifies
Xcode is 26+, and generates `HermesNotes.xcodeproj`:

```sh
./scripts/bootstrap.zsh --open        # add --test to also run the core tests
```

If you'd rather do it by hand:

```sh
brew install xcodegen
xcodegen generate
open HermesNotes.xcodeproj
```

---

## 6. Build and run

In Xcode: pick the **HermesNotes** scheme and an **iOS 26 simulator** (or your
device), then **Run** (⌘R).

Run the pure-Swift core tests any time — no simulator needed, works on Linux
too:

```sh
cd HermesNotesCore && swift test
```

---

## 7. Everyday git workflow

```sh
git checkout claude/apple-native-notes-app-wl96he   # your working branch
git pull origin claude/apple-native-notes-app-wl96he

# …make changes…

git add -A
git commit -m "Describe your change"
git push origin claude/apple-native-notes-app-wl96he
```

After editing `project.yml` (adding files, changing settings), regenerate:

```sh
xcodegen generate
```

`.xcodeproj` is git-ignored — it's always regenerated from `project.yml`, so
you never commit it and never hit merge conflicts on it.

---

## Quick reference — the whole thing

```sh
# after Xcode 26 is installed from the App Store and launched once:
xcode-select --install
git config --global user.name  "Giovanni Tapang"
git config --global user.email "gtapang@nip.upd.edu.ph"

# auth (SSH shown; see §3 for the gh alternative)
ssh-keygen -t ed25519 -C "gtapang@nip.upd.edu.ph"
eval "$(ssh-agent -s)"; ssh-add ~/.ssh/id_ed25519
pbcopy < ~/.ssh/id_ed25519.pub        # paste into GitHub → SSH keys

# clone + branch + build
git clone git@github.com:gtapang/mytaskapp.git
cd mytaskapp
git checkout claude/apple-native-notes-app-wl96he
./scripts/bootstrap.zsh --open
```
