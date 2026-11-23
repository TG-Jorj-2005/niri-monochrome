# Changelog

## 2026-11-13 — lock screen redesign

- New `components/lock/LockContent.qml`: blurred greyscale wallpaper, large clock and date, account avatar and full name, password field with shake on failure, network/Bluetooth/battery status, now-playing controls and key hints. `LockScreen.qml` keeps the same WlSessionLock + PAM logic.
- `security.useShellLock` is now on. Super+Alt+L, lid-close and swayidle call `~/.local/bin/niri-lock`, which locks through the shell and falls back to `swaylock -f` if the shell does not confirm the lock within 3 s. New IPC `lock isSecure`.
- Recovery if the shell ever dies while locked: Ctrl+Alt+F3, log in, run `WAYLAND_DISPLAY=wayland-1 XDG_RUNTIME_DIR=/run/user/$(id -u) swaylock`, return with Ctrl+Alt+F2 and unlock in swaylock. Revert: set `security.useShellLock` to false.

## Phase 4 — monochrome UI polish

- Added shared motion/reduced-motion controls, glass panels and bounded native Niri bar/dock blur.
- Added a searchable informational shortcut overlay and real PipeWire output-level history/meter with visibility-scoped capture.
- Passed IPC 16/16, core 14/14, image fallback 2/2, Phase 4 10/10 and live lifecycle/reload checks. Measurements and manual limits: [PHASE4-REPORT.md](PHASE4-REPORT.md).

## Screenshot integration

- Added native Niri capture buttons and screenshot IPC commands, an installed launcher entry, and optional Swappy clipboard annotation. Existing Print bindings remain effective.
- Swappy 1.5.1 was installed from Fedora repositories; QML loading, shell startup/reloads, desktop entry, ShellCheck and Niri validation passed.

## 2026-11-12 — Phase 3 stabilization

- Fixed the missing ShellRoot brace that caused live reload failures while the old generation kept running; the validator now loads the actual entrypoint and checks three reloads.
- Hardened Niri event schema validation, synchronization, reconnect lifecycle and cross-output action ordering.
- Added defensive config/state typing, literal monitor keys, collision fallbacks, wallpaper decoder-error recovery and explicit notification migration consent.
- Corrected power-backend refresh/AC state, bounded nmcli requests, brightness failure refresh, overlay/dock state and experimental PAM cancellation guards.
- Final regression: IPC 16/16, core 14/14, image decoder 2/2, component load and shell startup/reloads passed. Live overlays passed 80 open/close cycles; measured idle/resource data and exact limits are in [PHASE3-RELEASE.md](PHASE3-RELEASE.md).
- No package installs or desktop ownership migration; swaylock remains default.

## 2026-11-12 — Phase 2 reliability follow-up

- Fixed Niri event-stream recovery for Quickshell 0.2.1 peer-close errors that do not reliably emit a connection-state transition. Recovery is idempotent per socket, clears stale workspace/window state, and exposes a lifetime reconnect counter.
- Corrected the IPC fixture to accept concurrent `EventStream` and `Outputs` connections, matching Niri's socket usage. The reconnect test now verifies that the replacement stream receives initial state.
- Fixed the validator's empty `scripts/*.sh` glob and made ShellCheck report no findings.
- Changed the Control Center's unavailable power-profile text so it does not imply that only `power-profiles-daemon` is supported.
- Verification: IPC test 14/14; validator passed all checks and loaded 17 component groups; `niri validate` and ShellCheck passed. `qmllint` and real hardware/session scenarios remain unverified.

## 2026-11-12 — Engineering review (takeover)

Backups: `~/.config/quickshell/niri-monochrome.bak-20261112-review/`, `~/.config/niri-monochrome/config.json.bak-20261112-review`,
`~/.config/niri/rules.kdl.bak-20261112-review`, `~/.local/state/niri-monochrome/state.json.bak-20261112-review`.

### Fixed
- **Lock routed to swaylock.** Power menu, Control Center and `qs ipc call lock lock` used the shell's
  WlSessionLock/PAM screen even though `security.useShellLock` is false. `LockService.lock()` now runs
  `security.systemLockCommand` (`swaylock -f`); `LockService.lockShell()` / `ipc call lock lockShell` is the
  explicit shell lock (Settings → Security → "Test shell lock").
- **Mod+N / Mod+Shift+N hijacked.** `niri-monochrome.kdl` (included after `binds.kdl`, so it overrides)
  rebound both keys to the shell's empty notification center. Defaults are now empty, so the user's
  `makoctl dismiss --all` / `makoctl mode -t dnd` bindings apply again.
- **Competing notification server.** `NotificationServer` was instantiated unconditionally (Quickshell
  retries registration whenever the active daemon unregisters). It is now created only after the D-Bus
  ownership probe reports that nobody owns `org.freedesktop.Notifications`, and never retried.
- **Mako bridge.** While mako owns the service: DND state is read from `makoctl mode`, the bell/Control
  Center toggle calls `makoctl mode -t dnd`, `ipc call notifications dismissAll` calls `makoctl dismiss --all`.
- **Transient wallpaper monitor keys.** The wallpaper layer scanned before niri's output list arrived, creating
  state under `default` / `0x7EAD` and switching image at startup. `MonitorService.ready` gates scanning;
  stale keys removed from `state.json`.
- **Dock placeholders.** Favorites without a desktop entry (`org.gnome.Music`) are hidden; a
  `niri-monochrome-settings.desktop` entry was added so the Settings favorite resolves.
- Settings window now opens floating (window-rule for `org.quickshell` + title in `rules.kdl`).
- Bar gets niri's drop shadow (layer-rule namespace `^(waybar|nm-bar)$`).

### Bottom bar
- Geometry from config: `height 40`, `widthPercent 92`, `maxWidth 1760`, `marginBottom 12`, `radius 9`,
  `marginX 24` (minimum side margin). Exclusive zone = height + bottom margin.

### Performance
- Brightness sysfs polling (every 5 s, always) now runs only while the Control Center is open (2 s).
- `niri-monochrome.kdl` is rewritten only when its content changes (previously on every shell start,
  which made niri reload its config).

### Cleanup
- Unreferenced parallel implementation (flat `BottomBar.qml`, `Dock.qml`, `Launcher.qml`, `PowerMenu.qml`,
  `NiriService.qml`, `Theme.qml`, `Icons.qml`, `MonoIcon.qml`, `AppIcon.qml`, `Wallpaper*.qml` next to
  `shell.qml`) moved to `legacy/root-duplicates/`; `tests/smoke.qml` moved to `legacy/`.
- `QuickTile.enabled` renamed `tileEnabled` (shadowed `Item.enabled`).

### Known / not changed
- `~/niri-monochrome` is an older development copy; the live project is this directory.
- Remaining `propertyCache` warnings come from Quickshell's own Widgets module.
- Lock, suspend, reboot and shutdown were not executed during the review (destructive on a live session).
