# NIRI MONOCHROME — System & project audit

Refreshed: 2026-11-12 (engineering review). The 2026-11-11 pre-build audit is superseded by this document.

> Phase 3 update (2026-11-12): the current implementation and fresh measurements are documented in [PHASE3-RELEASE.md](PHASE3-RELEASE.md). The sections below retain historical Phase 1/2 evidence. Phase 3 found and fixed a source entrypoint parse failure that the earlier component-only check missed. tuned-ppd is now verified active, and the notification server requires explicit migration approval even if mako is absent.

## 1. Environment (historical live audit)

| Component | State |
|---|---|
| OS / kernel | Fedora Linux 45 Workstation · Linux 7.2.11 |
| Compositor | niri 26.04 · IPC via `$NIRI_SOCKET` event stream (`WorkspacesChanged`, `WindowFocusChanged`, `OverviewOpenedOrClosed`, …) |
| Shell runtime | Quickshell 0.2.1 (Fedora package) · Qt 6.11.2 · QtQuick.Effects available |
| Display | eDP-1 · AU Optronics 0x7EAD · 1920×1080 @ 144 Hz · scale 1 · stable key `AU Optronics|0x7EAD|0x00007EAD` |
| Audio | PipeWire 1.6.9 + WirePlumber · sink "Built-in Audio Analog Stereo" |
| Network | NetworkManager · wlp8s0 connected (Quickshell.Networking backend = NetworkManager) |
| Bluetooth | BlueZ active, adapter powered |
| Power | UPower BAT1 (72 %, charging at original audit time) · `power-profiles-daemon` package absent; `tuned-ppd` package is installed, but service and D-Bus ownership could not be checked from this review environment |
| Backlight | `nvidia_wmi_ec_backlight` via `brightnessctl` (max 800) |
| PAM | `/etc/pam.d/login` (used by PamContext; untouched) |
| Fonts | Inter (UI), JetBrains Mono (technical). Geist absent. |
| Icons | Papirus-Dark-Mono (user), Papirus, Adwaita; app icons desaturated in-shell |

## 2. Running desktop services (session started 2026-11-12, ~07:05)

| Service | PID / state | Owner of | Notes |
|---|---|---|---|
| `qs -c niri-monochrome` | running (RSS ≈ 200–235 MB, CPU ≈ 0 % idle) | `org.kde.StatusNotifierWatcher` (SNI host) | Layer surfaces: `nm-wallpaper` (Background), `nm-bar` (Top), `nm-dock-trigger` (Overlay); overlay/dock/toast surfaces are mapped on demand |
| mako | running | `org.freedesktop.Notifications` | Shell never starts its NotificationServer while mako owns the name; DND / dismiss bridged through `makoctl` |
| swayidle (`idle-manager start`) | running | — | dim / lock (swaylock) / screen off / suspend thresholds unchanged |
| swaylock | on demand | — | Super+Alt+L, lid-close, swayidle, shell "Lock" (while `security.useShellLock` = false) |
| nm-applet, blueman-applet | running | tray items | shown in the bar tray; not started or stopped by the shell |
| mate-polkit agent, `wl-paste --watch cliphist store` | running | — | preserved |
| waybar, swaybg, fuzzel | **not running** | — | replaced by bar / WallpaperLayer / Launcher; lines commented in `startup.kdl` |

## 3. Project layout (`~/.config/quickshell/niri-monochrome`, 62 QML files)

```
shell.qml                 entry: per-screen Variants + IPC handlers
config/   Theme (tokens) · Constants · UserConfig (config.json, validation) · MonitorProfiles · Keybindings (writes niri include) · Icons (SVG set)
services/ NiriService (socket event stream, actions via `niri msg action`) · MonitorService (make|model|serial keys, ready flag)
          Audio (PipeWire) · Network (NM) · Bluetooth (BlueZ) · Battery (UPower) · Media (MPRIS) · Notification (server gate + mako bridge, history)
          Wallpaper (per-monitor collections, wall-clock rotation) · Pam · Lock (swaylock unless opted-in) · System (brightness, power, probes)
          ShellState (which overlay is open, where) · StateStore (state.json)
components/ BottomBar (+ bar/*) · AutoHideDock · OverlayLayer (hosts popovers/*: Launcher, ControlCenter, NotificationCenter,
          MediaControls, CalendarPopover, PowerMenu, TrayMenu) · NotificationToasts · WallpaperLayer · LockScreen · Settings (+ settings/*) · ui/*
legacy/   unreferenced earlier implementation (root-duplicates/) and the original smoke test — nothing imports it
docs/     AUDIT.md (this file) · CHANGELOG.md
```

Persistent files: `~/.config/niri-monochrome/config.json` (settings, per-monitor overrides), `~/.local/state/niri-monochrome/state.json`
(wallpaper order/current/nextAt per monitor, recent apps), `~/.local/state/niri-monochrome/notifications.json` (only when the shell is the
notification server), `~/.config/niri/niri-monochrome.kdl` (generated binds), `~/.local/share/applications/niri-monochrome-settings.desktop`.

`~/niri-monochrome` is an older development copy and is not used.

## 4. Keybindings (effective)

| Key | Action | Source |
|---|---|---|
| Mod+D | Application launcher | niri-monochrome.kdl |
| Mod+A | Toggle dock (keyboard mode: ←/→, 1–9, Enter, Esc) | niri-monochrome.kdl |
| Mod+Shift+A | Control Center | niri-monochrome.kdl |
| Mod+X | Power menu | niri-monochrome.kdl |
| Mod+Comma | Settings window | niri-monochrome.kdl |
| Mod+Shift+W | Next wallpaper (focused monitor) | niri-monochrome.kdl |
| Mod+N / Mod+Shift+N | `makoctl dismiss --all` / `makoctl mode -t dnd` | binds.kdl (preserved; the include no longer overrides them) |
| Mod+Space | Keyboard layout us ⇄ ro | binds.kdl (preserved) |
| Mod+O | Native overview (also: click "NIRI" in the bar) | binds.kdl (preserved) |
| Super+Alt+L | swaylock | binds.kdl (preserved) |
| Ctrl+Shift+E / Mod+Shift+C | Clipboard history | binds.kdl (preserved) |

`niri-monochrome.kdl` is included after `binds.kdl`; niri gives later binds precedence, so the include must never contain user keys.
Shortcuts are edited in Settings → Shortcuts; the file is regenerated only when its content changes.

## 5. Bar geometry (config.json → bar)

height 40 · widthPercent 92 · maxWidth 1760 · marginX 24 (minimum) · marginBottom 12 · radius 9 · reserveSpace true
(exclusive zone = 52 px). On 1920×1080 the bar is 1760×40, centered, x = 80…1840. Shadow drawn by niri (`layer-rule` namespace `nm-bar`).

## 6. Integration boundaries

- **Notifications**: mako is authoritative. The shell's server is created only if the D-Bus probe finds no owner, and is never retried,
  so a mako restart cannot be raced. Notification history therefore stays empty until a mako → shell migration is approved.
- **Lock**: `LockService.lock()` → `security.systemLockCommand` (`swaylock -f`). `LockService.lockShell()` (Settings → Security → "Test shell lock",
  `qs ipc call lock lockShell`) is the WlSessionLock + PAM screen; its unlock path has **not** been verified with the real password.
- **Power actions**: argv arrays from `config.json → system.*`, executed with `Process`, no shell interpolation. Logout/reboot/shutdown
  require a second confirmation in the power menu.
- **Tray**: Quickshell is the only SNI host (waybar stopped).
- **Wallpaper**: swaybg removed; `WallpaperLayer` cross-fades two `Image` slots (sourceSize = screen size, async, no cache) under one
  MultiEffect layer for grayscale. Rotation is wall-clock based (`nextAt`), so suspend/resume does not burst.
- **Niri IPC recovery**: peer-close errors explicitly enter the guarded reconnect path; disconnect clears stale workspace/window state, reconnect uses capped exponential backoff, and initial state is re-read after the stream resumes.

## 7. Measurements (2026-11-12)

| Check | Result |
|---|---|
| QML errors after reload | none (only upstream `propertyCache` warnings from Quickshell Widgets) |
| RSS across 6 wallpaper rotations | 231.9 → 230.8 MB (no growth) |
| CPU idle (top, 5 s) | 0.0 % |
| Timers while idle | wallpaper tick 30 s, history prune 1 h; brightness poll only while Control Center is open |
| `niri validate` | config is valid |

## 8. Open risks / not verified

- Shell lock PAM success path (needs the user's password); swaylock remains the default.
- Hover activation of the dock edge strip, Escape / click-outside dismissal: verified in code only (cannot inject input from the agent shell).
- Multi-monitor paths (per-output workspaces, popover placement, profile persistence on reconnect) are implemented against
  `Quickshell.screens` + niri outputs but only one display was available to test.
- Quickshell auto-reloads the shell on any file save in the project directory; `qs ipc` calls during a reload return "Not ready to accept queries yet".

## 9. Phase 2 targeted verification (2026-11-12)

| Check | Result |
|---|---|
| `tests/niri-ipc-test.sh` | **14/14 passed**: initial state, workspace/window/focus/overview changes, unknown and malformed events, peer-close detection, reconnect, and resync. The fixture accepts both the persistent event stream and the separate `niri msg outputs` request. |
| `tests/validate.sh` | **Passed**: shell syntax, user JSON, desktop entry, `niri validate`, and headless loading of 17 component groups. The headless harness reports expected scene-placement warnings for hidden objects; no QML load errors. |
| `shellcheck tests/*.sh` | Passed with no findings after cleanup. |
| `qmllint` | Not run; executable is not installed. The headless Quickshell load check is the available QML validation. |
| Live compositor recovery / monitor hotplug | Not exercised in this verification run; covered only by the fake IPC test for stream recovery. |
| Power-profile backend state | Package query found `tuned-ppd` installed and `power-profiles-daemon` absent. Service and system-bus ownership are unverified because the review environment cannot access the system bus. |

The IPC test revealed that Quickshell 0.2.1 can report a peer-close socket error without a reliable connection-state transition. NiriService now routes socket errors through a single guarded disconnect handler and exposes a lifetime reconnect counter for diagnostics. The Control Center's unavailable label no longer incorrectly names only `power-profiles-daemon`.
