#!/usr/bin/env bash
#
# install_plugin.sh — copy grammar_checker.vim from the current directory
#                     into ~/.vim/plugin/, creating the directory if needed.
#
# Usage:
#   ./install_plugin.sh                     # installs ./grammar_checker.vim
#   ./install_plugin.sh path/to/other.vim   # installs a specific file
#
set -euo pipefail

# ---- Configurable ----------------------------------------------------------
PLUGIN_NAME="${PLUGIN_NAME:-grammar_checker.vim}"
SRC="${1:-./$PLUGIN_NAME}"
DEST_DIR="$HOME/.vim/plugin"
DEST="$DEST_DIR/$(basename "$SRC")"
# ---------------------------------------------------------------------------

say()  { printf '\033[1;34m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[install]\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31m[install]\033[0m %s\n' "$*" >&2; exit 1; }

# 1. Sanity checks -----------------------------------------------------------
[[ -f "$SRC" ]] || die "Source file not found: $SRC"
[[ -r "$SRC" ]] || die "Source file not readable: $SRC"

# 2. Make sure the destination directory exists ------------------------------
if [[ ! -d "$DEST_DIR" ]]; then
    say "Creating $DEST_DIR"
    mkdir -p "$DEST_DIR" || die "Could not create $DEST_DIR"
else
    say "Destination dir exists: $DEST_DIR"
fi

# 3. Skip the copy if contents are identical ---------------------------------
if [[ -f "$DEST" ]] && cmp -s "$SRC" "$DEST"; then
    say "No change: $DEST is already up to date."
    exit 0
fi

# 4. Back up any existing plugin --------------------------------------------
if [[ -f "$DEST" ]]; then
    BACKUP="${DEST}.$(date +%Y%m%d-%H%M%S).bak"
    say "Backing up existing plugin to $BACKUP"
    cp -p "$DEST" "$BACKUP"
fi

# 5. Copy --------------------------------------------------------------------
say "Copying $SRC -> $DEST"
cp -p "$SRC" "$DEST"

# 6. Verify ------------------------------------------------------------------
if cmp -s "$SRC" "$DEST"; then
    say "Done. Sizes:"
    ls -l "$SRC" "$DEST"
    echo
    say "Reload it in Vim with:  :source $DEST"
else
    die "Verification failed — $DEST does not match $SRC"
fi
