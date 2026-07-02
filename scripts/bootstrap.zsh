#!/usr/bin/env zsh
#
# bootstrap.zsh — set up a Mac to build Hermes Notes.
#
# Installs/verifies: Xcode Command Line Tools, Homebrew, XcodeGen — then
# generates HermesNotes.xcodeproj and (optionally) runs the core tests.
#
# Safe to re-run: every step is a check-then-install, so nothing is
# reinstalled if it's already present.
#
# Usage:
#   ./scripts/bootstrap.zsh            # install deps + generate project
#   ./scripts/bootstrap.zsh --open     # ...and open the project in Xcode
#   ./scripts/bootstrap.zsh --test     # ...and run the core Swift tests
#
set -euo pipefail

# --- pretty output -----------------------------------------------------------

autoload -U colors && colors
info()  { print -P "%F{cyan}▸%f $*" }
ok()    { print -P "%F{green}✓%f $*" }
warn()  { print -P "%F{yellow}!%f $*" }
die()   { print -P "%F{red}✗%f $*" >&2; exit 1 }

# Resolve repo root from this script's location (works from any CWD).
SCRIPT_DIR=${0:A:h}
REPO_ROOT=${SCRIPT_DIR:h}
cd "$REPO_ROOT"

# Minimum Xcode major version (Foundation Models / iOS 26 SDK).
MIN_XCODE_MAJOR=26

OPEN_PROJECT=false
RUN_TESTS=false
for arg in "$@"; do
  case "$arg" in
    --open) OPEN_PROJECT=true ;;
    --test) RUN_TESTS=true ;;
    -h|--help)
      print "Usage: $0 [--open] [--test]"
      exit 0
      ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

# --- 0. sanity: this is a Mac ------------------------------------------------

[[ "$(uname -s)" == "Darwin" ]] || die "This script only runs on macOS."
info "Setting up Hermes Notes build environment in $REPO_ROOT"

# --- 1. Xcode Command Line Tools ---------------------------------------------

if xcode-select -p >/dev/null 2>&1; then
  ok "Xcode Command Line Tools present ($(xcode-select -p))"
else
  warn "Installing Xcode Command Line Tools (a GUI dialog will appear)…"
  xcode-select --install || true
  info "Finish the CLT install dialog, then re-run this script."
  exit 1
fi

# --- 2. Full Xcode + version check -------------------------------------------

if ! command -v xcodebuild >/dev/null 2>&1; then
  die "Xcode not found. Install Xcode ${MIN_XCODE_MAJOR}+ from the App Store, then re-run."
fi

# `xcodebuild -version` → "Xcode 26.5" on the first line.
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1 | awk '{print $2}')
XCODE_MAJOR=${XCODE_VERSION%%.*}

if [[ -z "$XCODE_MAJOR" ]]; then
  warn "Could not determine Xcode version; make sure the full Xcode (not just CLT) is selected:"
  warn "  sudo xcode-select -s /Applications/Xcode.app"
elif (( XCODE_MAJOR < MIN_XCODE_MAJOR )); then
  die "Xcode $XCODE_VERSION found, but $MIN_XCODE_MAJOR+ is required (Foundation Models / iOS 26 SDK). Update via the App Store."
else
  ok "Xcode $XCODE_VERSION"
fi

# Make sure a full Xcode (with SDKs) is selected, not the bare CLT path.
if [[ "$(xcode-select -p)" == *"CommandLineTools"* ]]; then
  warn "Command Line Tools are selected instead of full Xcode. Point xcode-select at Xcode:"
  warn "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
fi

# Accept the license if it hasn't been (build fails otherwise).
if ! xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
  warn "Xcode needs a first-launch setup / license acceptance:"
  warn "  sudo xcodebuild -runFirstLaunch"
fi

# --- 3. Homebrew -------------------------------------------------------------

if command -v brew >/dev/null 2>&1; then
  ok "Homebrew present ($(brew --version | head -1))"
else
  warn "Installing Homebrew…"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Load brew into this shell for the rest of the script (Apple Silicon path).
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  command -v brew >/dev/null 2>&1 || die "Homebrew install did not complete."
  ok "Homebrew installed"
fi

# --- 4. XcodeGen -------------------------------------------------------------

if command -v xcodegen >/dev/null 2>&1; then
  ok "XcodeGen present ($(xcodegen --version 2>/dev/null))"
else
  info "Installing XcodeGen via Homebrew…"
  brew install xcodegen
  ok "XcodeGen installed"
fi

# --- 5. Generate the Xcode project -------------------------------------------

info "Generating HermesNotes.xcodeproj from project.yml…"
xcodegen generate
ok "Project generated"

# --- 6. Optional: run the pure-Swift core tests ------------------------------

if $RUN_TESTS; then
  info "Running HermesNotesCore tests…"
  ( cd HermesNotesCore && swift test )
  ok "Core tests passed"
fi

# --- 7. Optional: open in Xcode ----------------------------------------------

if $OPEN_PROJECT; then
  info "Opening HermesNotes.xcodeproj…"
  open HermesNotes.xcodeproj
fi

print
ok "Done. Next steps:"
print "  • Open the project:      open HermesNotes.xcodeproj"
print "  • Pick the HermesNotes scheme and an iOS ${MIN_XCODE_MAJOR} simulator, then Run (⌘R)."
print "  • Foundation Models features need a device/sim with Apple Intelligence;"
print "    the app degrades gracefully everywhere else."
