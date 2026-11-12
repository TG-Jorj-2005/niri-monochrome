# Changelog

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
