#!/usr/bin/env bash
set -euo pipefail

APP_NAME="clicker-rust"
BIN_TARGET="target/release/$APP_NAME"
BIN_DEST="$HOME/.local/bin/$APP_NAME"
DESKTOP_DEST="$HOME/.local/share/applications/rust-clicker.desktop"

echo "Budowanie wersji release..."
cargo build --release

echo "Instalowanie binarki do $BIN_DEST..."
mkdir -p "$HOME/.local/bin"
install -m 755 "$BIN_TARGET" "$BIN_DEST"

echo "Tworzenie wpisu .desktop w $DESKTOP_DEST..."
mkdir -p "$HOME/.local/share/applications"
cat > "$DESKTOP_DEST" <<EOF
[Desktop Entry]
Type=Application
Name=Rust Autoclicker
Comment=Linux rust autoclicker
Exec=$BIN_DEST
Terminal=false
Categories=Utility;
StartupNotify=true
EOF

if command -v update-desktop-database >/dev/null 2>&1; then
    update-desktop-database "$HOME/.local/share/applications" >/dev/null 2>&1 || true
fi

echo "Gotowe! Binarka: $BIN_DEST"
if ! id -nG "$USER" | grep -qw "input"; then
    echo "UWAGA: Twój użytkownik ($USER) nie jest w grupie 'input'."
    echo "Dodaj go poleceniem: sudo usermod -aG input $USER (potem przeloguj się)."
fi