# Phase 4 — Task 1/6 verification and regression audit

Date: 2026-11-12, Europe/Bucharest. Scope: Task 1 only. Task 2 was not started.

## Result

The current Phase 4 implementation is working with one confirmed pointer regression corrected. The existing 42/42 assertion result was reproduced before changes. The final integrated suite is **48/48**, because it now includes six regression checks for overlay input. Seven additional isolated lifecycle/binding probes also passed. No failed cases remain in the executed checks.

The shell is running on the existing Niri session. Tests used safe Quickshell reloads; Niri was never restarted. No dependencies or system security changes were made.

## Checkpoint and preservation

The initial Git tree already contained the uncommitted Phase 4 implementation. It was treated as authoritative and preserved. A complete pre-edit checkpoint is at `/home/jorj/.config/niri-monochrome-phase4-task1-backups/20261112-171652` (project including Git metadata, settings and Niri config).

User `config.json`, the main Niri config, `binds.kdl`, the generated shortcut include and appearance include are byte-identical to this Task 1 checkpoint. No shortcuts were rebound, and no user preference was reset. No commits, pushes or unrelated project changes were performed.

## Verified features

| Feature | Verification | Limits |
|---|---|---|
| Micro-animations | Inspected Theme motion gating, focus/pressed/disabled states, toggle signal ownership and slider input. Automated checks verify reduced-motion durations, slider write-through and continued response to external backend changes. | Physical hover, all keyboard combinations and subjective 144 Hz smoothness are not certified. |
| Glass | Verified grayscale palette, validated opacity/radius/shadow ranges, translucent/opaque switching and installed Niri 26.04 `background-effect` documentation. Actual generated rules target only `nm-bar`/`nm-dock`, use `blur true`, saturation 0, and pass full Niri validation. | Full-screen popovers intentionally use transparency without background blur; contrast over arbitrary content still warrants visual checking. No GPU frame-time benchmark. |
| Audio visualizer | Real sink-monitor PCM path inspected; no microphone/auto-input fallback or random data. Repeated virtual-output test produced 57 real PipeWire frames, peak 0.6783. Bounded history and invalid-frame checks pass. Separate actual-backend probes confirm stop on disable and hide, and no start when re-enabled while hidden. | Output-device hotplug/PipeWire-daemon restart were not induced. |
| Shortcut overlay | Inspected real-file registry and local filtering, Mod/Super duplicate resolution and documented two-file coverage. Search/conflict tests pass. New synthetic Qt events verify Up/Down, Escape, Close, padding and outside clicks on the actual overlay component. | These are targeted Qt events in a private test overlay, not physical user input. Arbitrary external KDL includes remain outside registry coverage by design. |

## Confirmed regression and minimal fix

**Cause:** `OverlayLayer.qml` put a full-screen dismissal MouseArea beneath the content, but panel rectangles do not consume mouse presses. A click on empty panel padding therefore propagated to the dismissal backdrop and closed the panel.

**Reproduction before correction:** the targeted Qt event probe failed `click inside panel padding keeps overlay open`; its outside-click check passed. This established the problem independently of the original component-loading tests.

**Correction:** add one MouseArea, bounded to the content Loader's rectangle and below its child controls. It consumes otherwise unhandled presses within the panel while allowing controls to receive input first. It is disabled when the overlay is not active. No service/backend or animation rewrite was needed.

**Verification:** the original probe now passes both cases. The permanent six-case regression test also confirms that the Close button, Up/Down, Escape and real outside dismissal continue working.

## Files changed in Task 1

- `components/OverlayLayer.qml`: the bounded interior input shield (only runtime-code change).
- `selftest-overlay.qml`: six isolated synthetic-pointer/key assertions on the real overlay.
- `tests/run-qml.py`: add the test's Wayland backend selection and two harmless shortcut fixtures in its temporary config.
- `tests/validate.sh`: include the new overlay regression.
- `docs/PHASE4-TASK1-REPORT.md` and `docs/phase4-task1-evidence/`: this report, logs, measurements, temporary-probe source and a task-only diff.

The task-only diff in `phase4-task1-evidence/task1.patch` separates these changes from the pre-existing uncommitted Phase 4 work.

## Executed tests and actual counts

| Test | Before | Final |
|---|---|---|
| `tests/niri-ipc-test.sh` | 16/16 | 16/16 |
| Core config/state/monitor checks | 14/14 | 14/14 |
| Real Qt wallpaper fallback checks | 2/2 | 2/2 |
| Existing Phase 4 assertions | 10/10 | 10/10 |
| New overlay input regression | Not present; temporary padding reproduction failed | 6/6 |
| **Integrated assertion total** | **42/42** | **48/48** |

`tests/validate.sh` also passed shell/JSON/desktop-entry validation, component loading, generated appearance KDL validation, actual shell startup and three isolated reloads. ShellCheck, `git diff --check` and `niri validate` passed. `qmllint` is unavailable and was not claimed to run.

Additional isolated probes: **7/7** (real backend start, stop on disable, hidden re-enable, stop on hide, slider write-through, external binding retention, reduced motion/opaque fallback). These seven checks are separate evidence and are not added to the integrated 48/48 count.

Live check: **20 open/close cycles**, including **5 Media cycles**; at most one capture helper. Reload with a capture active succeeded, and the captured helper PID did not survive. No capture helper remained at the end. Repeated cycles returned watchers to zero. The real audio stimulus used a temporary virtual sink with no speaker playback/default-output change, then removed the sink and processes.

No duplicate signal subscriptions, unbounded collections or persistent capture processes were observed in the tested paths. Component/shell checks found no unexpected QML errors or binding loops. Existing known upstream property-cache warnings and deliberate invalid-input test warnings remain distinguishable from failures.

## Performance and memory investigation

CPU is one-core-normalized usage from `/proc/12157/stat` and monotonic elapsed time. RSS is resident pages. This is the same live Quickshell process; only the shell configuration was reloaded. Measurements are finite samples, not a long-term heap-leak proof.

| Metric | Historical Phase 4 | Task 1 initial idle (30.0 s) | After lifecycle (30.0 s) | Final quiet sample (60.1 s) |
|---|---|---|---|---|
| Mean CPU | 0.067% | 0.067% | 0.167% | 0.067% |
| RSS start → end | Reference end: 221.34 MiB | 247.28 → 247.28 MiB | 221.53 → 212.19 MiB | 216.38 → 215.53 MiB |
| Persistent child processes at end | 1 | 1 | 1 | 1 |
| File descriptors at end | 65 | 67 | 65 | 64 |

The initial RSS was roughly 25.94 MiB above the historical reference. It was stable over the initial sample. RSS after repeated interaction cycles (KiB) was `[255260, 255740, 254636, 255564, 255456]`, which did not show continuous growth. It fell after a safe reload/cache settling, so this verification did not establish a memory leak or justify an optimization. The pointer correction is not credited with reducing memory or CPU. Idle CPU remained near zero; short-window variation should not be interpreted as a speedup/regression.

## Remaining manual verification

- Physical hover traversal into/out of the dock and pointer press/release feel.
- Full Tab/Shift+Tab flow, switch Space/Return behavior, and slider dragging/wheel interaction with actual volume/brightness hardware.
- Appearance/contrast over varied bright/dark backgrounds and subjective motion at the configured 144 Hz refresh rate.
- Optional real output-device changes to exercise backend recovery; the daemon/session were not restarted for this audit.

The six overlay event tests cover local Qt delivery; they do not certify every physical input or compositor condition. No PAM authentication, lock, suspend, reboot or destructive shortcut action was invoked.

## Final working state

The existing shell remains operational, configuration and blur rules validate, and normal ownership/fallbacks are preserved. The final state is checked for no active visualizer/capture process while Media is closed. The functional change is the nine-line bounded mouse input shield, backed by a reproducible failure and passing regression tests. Task 1 stops here; no Task 2 work was started.
