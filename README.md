# NIRI MONOCHROME

Monochrome Quickshell desktop for Niri: bottom bar, dock, launcher, Control Center, notifications, media controls with an output-level visualizer, Settings, keyboard-shortcut cheat sheet, wallpaper rotation and a PAM lock screen. Verification reports: [docs/PHASE3-RELEASE.md](docs/PHASE3-RELEASE.md) and [docs/PHASE4-FINAL-REPORT.md](docs/PHASE4-FINAL-REPORT.md).

The repository contains the shell itself, plus the reference desktop configuration it was built with. That configuration covers Niri, helper scripts, mako, fuzzel, swaylock and Alacritty. It does not include personal settings, saved state or wallpapers.

## Demo

https://github.com/user-attachments/assets/a9561b00-a2e3-4c0a-902d-f311245024af

The 70-second recording shows the bottom bar, wallpaper rotation, dock, launcher, Control Center, notifications, media controls, Settings, keyboard shortcuts, overview, power menu and lock screen. It was recorded in a nested Niri session with a private copy of the configuration, and every panel is opened over IPC (`qs -c niri-monochrome ipc call …`).

## Requirements

Tested on Fedora 45 with the packages from the official repositories:

| Component | Tested version | Fedora package |
|---|---|---|
| Niri | 26.04 | `niri` |
| Quickshell | 0.2.1 (git `dacfa9d`) | `quickshell` |

Niri 26.04 or newer is needed for the blurred bar and dock (`background-effect` in `niri-monochrome-appearance.kdl`).

```sh
# shell
sudo dnf install niri quickshell python3 pipewire-utils wireplumber NetworkManager brightnessctl libnotify \
    rsms-inter-fonts jetbrains-mono-fonts adwaita-sans-fonts
# reference desktop configuration (examples/)
sudo dnf install alacritty mako fuzzel swaylock swayidle cliphist wl-clipboard grim slurp ImageMagick \
    wf-recorder playerctl xwayland-satellite network-manager-applet blueman mate-polkit
# optional: screenshot annotation, night light, network editor
sudo dnf install swappy wlsunset nm-connection-editor
```

`bash scripts/install.sh --check` lists anything that is still missing.

## Installation

```sh
git clone https://github.com/TG-Jorj-2005/niri-monochrome ~/.config/quickshell/niri-monochrome
cd ~/.config/quickshell/niri-monochrome
bash scripts/install.sh --dry-run   # what would change
bash scripts/install.sh             # copy the reference configuration; changed files are backed up
```

`install.sh` copies these files into your home directory:
- `examples/niri/*.kdl` → `~/.config/niri/`
- `examples/bin/*` → `~/.local/bin/`
- `examples/{mako,fuzzel,swaylock,alacritty}` → `~/.config/…`
- the desktop entries → `~/.local/share/applications/`

An existing file that differs is renamed to `<file>.bak-<timestamp>` first. Then log in to a Niri session: `startup.kdl` starts the shell with `qs -c niri-monochrome`. On first start the shell writes default settings to `~/.config/niri-monochrome/config.json`. Put wallpapers in `~/Pictures/Wallpapers`.

To keep an existing Niri configuration instead, copy only what you need. The shell itself needs `include "niri-monochrome.kdl"` (generated keybindings) and `include "niri-monochrome-appearance.kdl"` (generated blur and shadows) in the main Niri config. The shell regenerates both files.

Helper scripts in `examples/bin/`:

| Script | Purpose |
|---|---|
| `idle-manager` | swayidle thresholds for battery and AC. It reads `/sys/class/power_supply/ACAD/online`; on other laptops, adjust the adapter name. |
| `niri-lock` | Locks with the shell's lock screen when `security.useShellLock` is on, otherwise with swaylock. |
| `volume-osd`, `bright-osd` | Volume and brightness keys, with an OSD shown through mako. |
| `clip-menu` | Clipboard history (cliphist + fuzzel). |
| `color-pick` | Copies the color of the pixel under the cursor. |
| `screen-record` | Starts or stops wf-recorder on a selected area. |
| `power-menu` | fuzzel power menu (the shell has its own, `Mod+X`). |

## Screenshots

Niri provides the capture backend; existing bindings are preserved:

- `Print`: interactive area selection.
- `Ctrl+Print`: focused screen.
- `Alt+Print`: focused window.

The existing Niri configuration saves to `~/Pictures/Screenshots` and copies captures to the clipboard. Control Center includes Area, Screen and Window buttons, plus **Annotate clipboard** when `swappy` is installed. The overlay closes before capture. Swappy opens the current PNG clipboard image for drawing, text, arrows and saving.

`install.sh` also installs the screenshot launcher entry; `bash scripts/install-screenshot-entry.sh` installs only that entry. `wl-clipboard` provides `wl-paste`.

Terminal commands:

```sh
qs -c niri-monochrome ipc call screenshot region
qs -c niri-monochrome ipc call screenshot screen
qs -c niri-monochrome ipc call screenshot window
qs -c niri-monochrome ipc call screenshot edit
```

## Appearance and media

Settings → Appearance controls reduced motion, monochrome glass, opacity, radius, shadow strength, motion intensity and the real output-level visualizer. Media shows amplitude history or a level meter; it does not invent frequency bands. Only the open Media panel owns a capture helper. No additional package is required beyond the existing `pw-cat` and Python 3.

Open Keyboard Shortcuts from Settings → Shortcuts or the keyboard button in Control Center. Terminal: `qs -c niri-monochrome ipc call shortcuts toggle`. The native `Mod+Shift+Slash` binding is preserved. The list covers `binds.kdl` and the generated shell include.

Once the shell has generated `niri-monochrome-appearance.kdl`, the main Niri config must include it: `include "niri-monochrome-appearance.kdl"`. The reference `examples/niri/config.kdl` already includes it. This enables native blur and shadows only for the bounded bar and dock surfaces on Niri 26.04; full-screen popover layers are not blurred. See [docs/PHASE4-REPORT.md](docs/PHASE4-REPORT.md).

## Scripting

Every panel can be driven from a terminal or a keybinding; `qs -c niri-monochrome ipc show` lists all targets and functions.

```sh
qs -c niri-monochrome ipc call launcher toggle
qs -c niri-monochrome ipc call controlcenter toggle
qs -c niri-monochrome ipc call settings section 0
qs -c niri-monochrome ipc call lock lock
```

## Validation

```sh
bash tests/niri-ipc-test.sh
bash tests/validate.sh
shellcheck scripts/*.sh tests/*.sh
niri validate
```

Tests isolate configuration, state and the session bus. Loading the UI requires an existing Wayland session. `validate.sh` also checks your installed `config.json`, desktop entry and Niri config when they exist. Experimental shell locking remains opt-in and needs manual PAM verification; mako remains the notification server.
