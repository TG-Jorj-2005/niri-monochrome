# NIRI MONOCHROME — Phase 3 release verification

Date: 2026-11-12 (Europe/Bucharest). Authoritative project: `~/.config/quickshell/niri-monochrome`.

## A. Executive result

**READY WITH MANUAL VERIFICATION REQUIRED** for the existing single-monitor desktop and existing mako/swaylock ownership model. This is a tested release candidate, not certification of experimental locking or untested hardware transitions.

Baseline investigation found that the active Quickshell process was retaining its last valid configuration: `shell.qml` was missing its closing brace. Its log repeatedly reported `Expected token '}'`. The old component-only validator passed because it did not load that entrypoint. This is fixed; actual entrypoint startup and three isolated reloads now form part of validation. Deployment also produced a successful reload of the existing live process, without restarting Niri.

## B. Implemented changes

| Files / area | Concrete correction | Verification |
|---|---|---|
| `shell.qml` | Close ShellRoot correctly; defer per-monitor construction until configuration loads; expose read-only diagnostics | Actual entrypoint startup, 3 isolated reloads, live reload and diagnostics |
| `services/NiriService.qml` | Validate event payload shapes before accessing fields; wait for both workspace and window snapshots; cancel obsolete recovery timers; cap reconnect backoff; suppress duplicate disconnect handling; clear stale focus/output state; bound initial sync to 5 s; stop obsolete output request on disconnect; sequence cross-output workspace actions | 16 simulated socket assertions, including malformed payloads and duplicate disconnects; live ready state and one persistent Niri connection |
| `config/UserConfig.qml`, `services/StateStore.qml` | Normalize invalid section/field types; preserve last valid config on invalid JSON; prevent string values enabling experimental lock; normalize corrupt saved collections | Core tests with malformed JSON, null/array sections and wrong boolean types |
| `config/MonitorProfiles.qml`, `services/MonitorService.qml` | Treat identity keys containing dots as literal keys; validate effective overrides; use connector suffixes for missing/duplicate EDID identities; guard absent logical output geometry | Simulated missing EDID, identical monitor, existing monitor-key and dotted-key tests; current eDP-1 preserved |
| `services/WallpaperService.qml`, `components/WallpaperLayer.qml` | Reject invalid image entries until explicit rescan; advance to another candidate; clear both slots for an empty collection; avoid decoding an already visible image again; encode file URL components | 2 real Qt image-decoder tests with corrupt/missing files, plus fallback model assertions |
| `services/NotificationService.qml`, notification/settings UI | Require a separate explicit migration approval flag; legacy `server:true` does not authorize takeover; release evicted toast objects; respect zero timeout; refresh mako state when controls open | Core test ensures no unsolicited server; live mako PID remains the sole notification owner |
| `services/BatteryService.qml`, settings/control UI | Detect both PowerProfiles bus names independently and refresh availability on demand; remove shell/paste helper; distinguish AC idle from discharging; reset low-battery warning on AC | Installed API metadata, QML loads and live service diagnostics; tuned-ppd owns both bus names and offers three profiles |
| `services/BrightnessService.qml`, `services/NetworkService.qml` | Reject non-finite brightness values and refresh after a failed write; fix missing Log import; bound interactive nmcli connection timeout | Component load, ShellCheck where applicable, live ready states; no live network/brightness changes |
| `services/PamService.qml`, `services/LockService.qml` | Ignore completed authentication after cancellation; clear credentials before abort; stop delay timer on reset; require compositor-secure lock before submitting/unlocking | Import/runtime loading and code inspection only; real PAM authentication remains manual |
| `services/ShellState.qml`, `components/AutoHideDock.qml` | Clear dock keyboard state when opening an overlay; dismiss state on monitor removal; clamp selection after model changes and ignore absent items | Core overlay-state test and 80 automated live open/close cycles |
| Tests | Private session bus without desktop service activation; temporary config/state/runtime; UI load checks use Wayland with surfaces disabled; nonvisual tests use offscreen platform; add actual shell startup/reload coverage | Full final regression passed on the exact deployed sources |

No packages were installed, no source files removed, and no global PAM/network/display configuration was modified. Existing uncommitted changes were preserved. The old development copy was not touched.

## C. Performance comparison

CPU is derived from the live process's `/proc/PID/stat` CPU ticks divided by monotonic elapsed time (100% = one CPU core). RSS comes from resident pages; child PIDs and open descriptors are sampled from `/proc`. Raw samples and the sampler are in `phase3-evidence/`.

| Metric | Before | After | Verification method |
|---|---|---|---|
| Idle CPU | 0.050% over 60.0 s | 0.017% over 60.1 s | Same live QS PID 12157, 1 s samples |
| RSS during idle | 217.30 → 217.30 MiB | 219.14 → 219.14 MiB | Resident pages; after reload and interaction warm-up |
| RSS after repeated operations | NOT MEASURED before changes | Batch 1: 221.18 MiB; batch 2: 221.16 MiB | Each batch: 10 open/close cycles for each of 4 panels |
| CPU during repeated operations | NOT MEASURED before changes | 19.18% / 18.88% | Deliberately rapid automated interactions with animations; not idle CPU |
| Persistent child processes | 1 | 1 | One `nmcli monitor` process |
| File descriptors | 64 | 65 | Baseline vs after warm-up; stable at 70 at both interaction-batch ends |
| Niri IPC reconnect | Existing 14 simulated checks passed | Extended 16 checks passed; 0 live reconnects during verification | Fake socket suite; live diagnostics; `ss -xapn` shows one persistent connection |
| Startup/reload | Source entrypoint failed; old live generation retained | Actual entrypoint + 3 isolated reloads passed; live reload succeeded | QML log and bounded IPC readiness checks |
| 5-minute / 15-minute idle | NOT MEASURED | NOT MEASURED | 5-minute sampler was interrupted before final output; a complete comparable 60 s sample was taken instead |
| Full-size wallpaper rotation stress | Historical only | NOT MEASURED | Invalid/missing image decoder behavior was tested; no new full-size rotation benchmark |

No speedup or RAM reduction is claimed. The measured baseline was already quiet. The second interaction batch did not retain additional memory, and the final idle sample remains the evidence for idle behavior; these finite samples do not prove absence of all long-term leaks. The two image slots remain a bounded cache and continue using asynchronous, screen-sized decoding. Brightness watchers return to zero when Control Center closes. Existing wallpaper (30 s), notification prune (1 h) and conditional UI timers were retained.

## D. Executed tests

- Baseline: original IPC 14/14; existing component validator, ShellCheck and `niri validate` passed. The live log separately exposed the missing entrypoint brace.
- Final: Niri IPC **16/16**; core config/state/monitor/fallback **14/14**; actual Qt wallpaper decoder **2/2**.
- Component loader: 16 instantiated component groups plus an 18-service check (17 success records).
- Actual `shell.qml`: fresh isolated start and **3 reloads** passed. Initial test-environment failures (offscreen has no PanelWindow backend, PipeWire runtime path, transient non-JSON IPC readiness response) were corrected in the harness; final run passed.
- Live shell: successful reload; **20 open/close cycles each** for launcher, dock, Control Center and Notification Center (80 total); no overlays left open, brightness watchers zero, same one persistent child process.
- ShellCheck and `git diff --check`: clean. Niri configuration: valid.
- `qmllint`: unavailable in PATH and checked Qt tool locations; not run.
- Expected test warnings: hidden items outside a scene, upstream Quickshell property-cache warnings, deliberately invalid config/image warnings, absent desktop portal on private test bus. No unexpected QML load errors in the successful final suite.

The UI tests use the installed Wayland backend with disabled surfaces and a private D-Bus session; they are not real mouse/keyboard interaction tests. No active compositor restart, real authentication, suspend, pairing, network reconnection or audio device switching was performed.

## E. Manual verification still required

1. Dock/overlays: hover the bottom edge, move into and out of the dock; use arrows/Enter; verify Escape and click-outside dismissal on launcher and popovers.
2. Physical second monitor: connect/disconnect/reconnect it; verify workspace mapping, bar placement, wallpaper restoration and focused output. Identical or missing EDIDs use connector fallback; swapping physical ports cannot establish hardware identity without a unique serial.
3. Power/audio/network/Bluetooth: change a power profile and restore Balanced; switch an available audio device; exercise a known Wi-Fi/Bluetooth device. Readiness and current state are verified, actual transitions are not.
4. Suspend/resume: during a convenient user-controlled session, verify swaylock-before-sleep and restoration of displays/services.
5. Experimental shell lock: only if the user chooses to test it, verify both wrong and correct passwords using the existing explicit test entry. Keep swaylock bindings and idle fallback until this succeeds; no password belongs in logs or this chat.
6. On the next normal session restart, verify shell startup and Niri event sync. Simulated reconnect is covered; do not terminate the active compositor solely for a test.

## F. Subsystem status

| Area | Classification | Boundary |
|---|---|---|
| Entrypoint/reload, IPC parser/recovery, validation harness | COMPLETE AND TESTED | Recovery simulated; one live connection verified |
| Config/state validation, literal monitor keys, wallpaper error fallback | COMPLETE AND TESTED | Synthetic corrupt inputs and actual Qt decoder |
| Current single-monitor runtime, native backend state, mako/tray ownership | COMPLETE AND TESTED | Live status and owners checked |
| Pointer/keyboard behavior, physical hotplug, device changes, suspend/resume | COMPLETE — MANUAL VERIFICATION REQUIRED | No physical/user input test |
| Experimental shell lock authentication | COMPLETE — MANUAL VERIFICATION REQUIRED | Existing experimental implementation only; not approved for production/default use |
| qmllint, second physical display | UNAVAILABLE DUE TO ENVIRONMENT | No tool / hardware available |
| Automatic notification migration | NOT IMPLEMENTED | Intentionally requires explicit approval; mako retained |
| Installer/uninstaller | NOT IMPLEMENTED | Not present in this authoritative config project; not added in stabilization |

No action remained blocked by a rejected permission request. System-bus reads succeeded after leaving the filesystem/network sandbox with approved, narrowly scoped tool calls.

## G. Final project and recovery

The live shell is PID 12157; Niri is PID 12079. Live diagnostics after deployment: Niri/audio/network/Bluetooth/brightness ready, PowerProfiles available through tuned-ppd (Balanced), mako authoritative, shell lock disabled. The one StatusNotifierWatcher is the existing Quickshell process. nm-applet, blueman-applet, swayidle and mako remain running.

The full pre-change backup, including Git metadata and pre-existing uncommitted files, Niri config, user settings and state, is:
`~/.config/niri-monochrome-phase3-backups/20261112-101059/`.

User `config.json` and generated `niri-monochrome.kdl` match their backup hashes exactly. Recent applications, wallpaper ordering and monitor identity are preserved. During the review the regular 30-minute wallpaper timer advanced `current` and `nextAt`; that natural rotation was not undone. No wallpaper files were changed.

Deployment copied only verified changed files, checked for concurrent edits first, and wrote `shell.qml` last. No implementation change was reverted. No Git reset/clean or commit was performed. To inspect/recover a particular file, compare it with `backup/project/<path>` and restore that file after preserving any newer edits. Do not blindly restore the entire pre-change shell: its `shell.qml` has the missing-brace defect documented above. System settings/state do not need restoration for this release.

Runtime code files changed in Phase 3 (includes test files; documentation/evidence added separately):

- `components/AutoHideDock.qml`
- `components/Settings.qml`
- `components/WallpaperLayer.qml`
- `components/popovers/ControlCenter.qml`
- `components/popovers/NotificationCenter.qml`
- `config/MonitorProfiles.qml`
- `config/UserConfig.qml`
- `selftest-core.qml`
- `selftest-niri.qml`
- `selftest-wallpaper.qml`
- `services/BatteryService.qml`
- `services/BrightnessService.qml`
- `services/LockService.qml`
- `services/MonitorService.qml`
- `services/NetworkService.qml`
- `services/NiriService.qml`
- `services/NotificationService.qml`
- `services/PamService.qml`
- `services/ShellState.qml`
- `services/StateStore.qml`
- `services/WallpaperService.qml`
- `shell.qml`
- `tests/fake-niri-server.py`
- `tests/niri-ipc-test.sh`
- `tests/run-qml.py`
- `tests/validate.sh`
