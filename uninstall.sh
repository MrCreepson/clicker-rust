#!/usr/bin/env bash
set -euo pipefail

APP_NAME="clicker-rust"
BIN_DEST="$HOME/.local/bin/$APP_NAME"
DESKTOP_DEST="$HOME/.local/share/applications/rust-clicker.desktop"

echo "Usuwanie binarki $BIN_DEST..."
rm -f "$BIN_DEST"

echo "Usuwanie wpisu .desktop $DESKTOP_DEST..."
rm -f "$DESKTOP_DEST"

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

echo "Odinstalowano $APP_NAME."