# clicker-rust

Autoclicker na Linuxa oparty o `evdev` i `uinput` z interfejsem QML (`qtbridge`).

## Requirements

- **Rust** (`cargo`, edycja `2024` — zalecany aktualny `rustup` / `rust`)
- **Qt6 + QML** (`qt6-base`, `qt6-declarative` — moduły `QtQuick`, `QtQuick.Controls`, `QtQuick.Layouts`) oraz typowe narzędzia budowania (`cmake`, `pkgconf` / `clang`, jeśli wymagane przez środowisko)
- **Permissions (`evdev` & `uinput`):**
  - członkostwo w grupie `input` (odczyt urządzeń wejściowych):
    ```sh
    sudo usermod -aG input $USER
    ```
    *(po dodaniu do grupy wymagane jest ponowne zalogowanie)*
  - dostęp do `/dev/uinput` (tworzenie wirtualnego urządzenia wejściowego) — jeśli zwykły użytkownik nie ma uprawnień zapisu do `/dev/uinput`, potrzebna jest reguła `udev` (np. nadająca dostęp grupie `input` lub `uaccess`) i przeładowanie reguł `udev`.

### Arch Linux
```sh
sudo pacman -S --needed rust qt6-base qt6-declarative cmake pkgconf
```

## Install
```sh 
chmod +x install.sh && ./install.sh
```

## Uninstall
```sh
chmod +x uninstall.sh && ./uninstall.sh                                                                                                                                         
```