# Phase 4 — Task 6/6: stabilization and release assessment

Date: 2026-11-13, Europe/Bucharest. Authoritative project: `/home/jorj/.config/quickshell/niri-monochrome`.

## A. Executive result

**PARTIALLY VERIFIED. No unconditional release approval.**

Two Settings defects have been reproduced and corrected in a private copy of the actual project. Their focused regression passes **24/24**. The complete corrected private suite executes **207 assertions: 206 pass, one fails its native window activation/focus check**. The separate real PipeWire suite passes **24/24**. Existing assertions and warning checks have not been removed or weakened.

**The runtime correction is prepared, but is NOT deployed to the active project.** Throughout verification, the real shell reported `locked:true` and `lock isSecure:true`. Its QML files can trigger automatic reload when saved. Editing/reloading the shell that currently owns the session lock would introduce an unnecessary session-security/recovery risk. Work therefore continued in an isolated copy; the real lock was never activated, dismissed, authenticated, reloaded or replaced by this task. The user's requested authentication confirmation remains unanswered.

The reviewable, task-only correction is [phase4-task6-evidence/task6.patch](phase4-task6-evidence/task6.patch), with its four resulting files under `phase4-task6-evidence/pending/`. `git apply --check` succeeds against the current authoritative project. Applying it requires an unlocked session and a fresh concurrency check. Until then, **the original live Settings defects remain unresolved in the active shell**. This is an explicit deployment limitation, not a claim that the running shell is fixed.

**Security verification is incomplete:** `security.useShellLock` was already enabled before Task 6. Compositor confirmation does not establish successful real-password PAM authentication. Phase 4 is complete only to the extent supported by this evidence; no Phase 5 work was begun.

## B. Checkpoint and preservation

Checkpoint: `/home/jorj/.config/niri-monochrome-phase4-task6-backups/20261113-005808`.

It contains the complete project including `.git` and untracked files, the full Niri directory (including generated shortcut/appearance files), user settings, persistent shell state, the initial Git status and binary working diff, source hashes, the effective runtime/security snapshot and the current external `niri-lock` wrapper. The preexisting working diff is approximately 83 kB; existing Phase 4/Tasks 1–5 work and independent lock-screen changes were retained.

The existing reports, current code, tests and working changes were reviewed. No additional agent was active in this thread. A VS Code/Codex process existed separately; this cannot establish whether an editor is idle. Repeated source-hash comparisons found **no preexisting project file changed after the checkpoint**. No reset, clean, staging, commit, push, dependency installation or old-development-copy modification was performed.

Real settings, Niri files and persistent shell state compared byte-for-byte equal to their checkpoint copies at the preservation check. This task changed only its new report/evidence in the authoritative project. In particular, the independent lock implementation, Settings security text, PAM service, user lock preference and generated keybindings were preserved.

## C. Settings investigation and prepared correction

### Binding loop

The original actual hidden Settings/Dock fixture produced **three binding-loop warnings for three distinct query assignments** at `Settings.qml:141`. It used private config/state and did not select favorites or launch applications. The original probe fails the strict runner, as expected. Its corrected diagnostic rerun has no binding-loop warnings but still lacks a result marker; it is not counted as a passing regression test.

The `Repeater.model` binding calls `ApplicationService.search()`. That function reads reactive `_lastQuery`/`_lastLimit`/`_lastResult` and then assigns the cache properties synchronously on a miss. QML tracks those reads while evaluating the model; changing `_lastQuery` during that same evaluation invalidates the binding currently being evaluated. Different ordinary search strings reproduce the cycle. Configuration/visible-entry invalidation can also make a subsequent memoized call miss; it is not necessary to provoke the basic defect.

The prepared fix changes this binding to the existing pure `searchUncached(favSearch.text.trim(), 6)` path. It retains normalization, scoring, bounds and favorite filtering. The launcher's imperative memoized `search()` and all existing cache invalidation connections remain unchanged. No production timer, delayed callback, daemon, extra subscription, cache rewrite or logging suppression is added.

Two alternating before/after benchmark pairs each execute the same 200 queries against 80 visible installed applications. Each original run produces 200 binding-loop warnings and fails the strict runner; each corrected run produces zero and passes. The regression also verifies that Settings queries leave the launcher's cache unchanged. This controlled change establishes the cache mutation as the cause for the reproduced path; it does not establish the cause of historical whole-shell CPU transients.

### Favorite selection

With the pure binding in place, the actual favorite-row click handler exposed another real defect: `win.addFav(modelData.id)` synchronously changes the model and destroys the clicked delegate. Its next statement, `favSearch.text = ""`, then runs in the destroyed context and raises `ReferenceError: favSearch is not defined`. The favorite is written, but search clearing fails. The intermediate targeted run was **20/21**, with the exception retained in `settings-regression-probe.log`.

The prepared fix delegates selection to a small `selectFavorite(id)` function on the persistent search field. That function clears the query and adds the already-evaluated ID from a surviving QML context. The corrected run passes **21/21**, followed by **3/3** assertions in a fresh process using the same private persisted configuration. No application launch occurs.

Coverage includes distinct/whitespace/empty/missing/rapid queries, correct installed results, unchanged memoized result identity, recent/config invalidation, real DesktopEntries file-watcher discovery of a newly installed private `.desktop` entry, cache invalidation on that update, unique IDs, actual favorite selection, exclusion of existing favorites, saved JSON and fresh-process restoration. It uses private `XDG_DATA_HOME`, config and state; the user's real favorites are untouched.

Prepared files:

| File | Reason |
|---|---|
| `components/Settings.qml` | Pure search binding and surviving-context favorite selection; the only runtime correction. |
| `selftest-settings-search.qml` | Actual Settings regression with private installed entries and persistence checks. |
| `tests/run-qml.py` | Private application directory/config setup and fresh-process Settings restore run; strict warning checks retained. |
| `tests/validate.sh` | Register the new regression without changing earlier assertions. |

`ApplicationService.qml`, Launcher, OverlayLayer, MonoToggle, Theme, UserConfig, Keybindings, appearance generation, shortcut reader, audio backend and lock files are unchanged by the prepared patch.

## D. Integrated Phase 4 status

| Area | Verified evidence and limits |
|---|---|
| Micro-interactions | Existing 26 interaction assertions pass, including keyboard/keypad Enter, focus, slider behavior and reduced motion. Motion durations are centralized; transition animations are bounded. Physical input and perceived 144 Hz smoothness remain manual. |
| Glass/contrast | Existing 18 checks plus one fresh-process restore pass; current native appearance include validates. Native blur rules match only `^nm-bar$`/`^nm-dock$`; no unsupported compositor API or full-screen blur is introduced. Actual wallpaper readability remains subjective/manual. |
| Audio | Deterministic component 14/14 and helper 9/9 pass. Real PipeWire 24/24 covers actual PCM, silence/stale expiry, target removal/reconnection, no fallback, bounded retry, hidden/disabled/exit cleanup and helper death. Defaults and existing playback routes are preserved. |
| Shortcuts | Parser/filter 23/23, UI 30/30, fresh-process restore 1/1, geometry 6/6 and native syntax oracle 6/6 pass in the final private suite. Existing supported direct-source coverage is retained; arbitrary recursive includes/full XKB equivalence remain outside scope. Saved source data is not a live compositor binding snapshot. |
| Overlay/dock/Settings | Existing overlay 6/6 passes; final shortcut UI confirms interior shielding, dismissal, keyboard traversal and entry-point transitions. Private lifecycle exercises all requested non-destructive UI groups. Actual native window activation is unavailable under the real session lock; focus restoration to a real application was not newly certified. |
| Notifications/tray | Real Mako PID 12139 retains `org.freedesktop.Notifications`; real QS PID 12157 retains `org.kde.StatusNotifierWatcher`. DND is `default`. Ownership gates and existing bridge code were reviewed; live dismiss/DND mutations were not needed. Private buses prevent ownership competition. |

`ShellState.open` remains the single overlay selector; loading/unloading and watcher counts recover in tested cycles. Brightness capture/watchers return to zero after Control Center, and audio capture/watchers return to zero after Media. The existing lazy shortcut service owns four FileViews; its one-time watcher increase is bounded, as measured below.

## E. Actual regression results

| Suite/run | Result |
|---|---|
| Baseline `tests/niri-ipc-test.sh` | 16/16; exit 0. |
| Baseline `tests/validate.sh` | Exit 1; combined baseline **180/183**, not 183/183. |
| Corrected private `tests/niri-ipc-test.sh` | 16/16; exit 0. |
| Corrected private `tests/validate.sh` | Exit 1; combined **206/207**. |
| Settings focused regression + new-process restore | **24/24**; strict runner exit 0. These 24 are included in 207, not added again. |
| Separate real PipeWire integration | **24/24**; exit 0. Not included in the integrated total. |
| Actual entrypoint/component loading | Pass, including three isolated supported reloads and generated native KDL validation. |
| Static checks | ShellCheck, Python AST parsing, current `niri validate`, shell syntax, JSON/desktop validation and `git diff --check` pass. External `niri-lock` syntax/ShellCheck also pass. |

The actual increase is **183 + 24 = 207 assertions**, including the fresh-process precondition/restoration checks. Opt-in benchmarks and lifecycle observations are reported separately.

Baseline failures were two small-viewport assertions in the shortcut UI test and the native initial-focus test. The unchanged viewport assertions pass in the complete corrected private run; the separate rendering suite passes 6/6 in both. No viewport runtime fix or test relaxation was made, and the earlier failures remain recorded as timing/environment-sensitive observations with no conclusively isolated cause.

The remaining final failure is `selftest-shortcut-focus.qml`: it observes `windowActive:false`, `inputFocus:false`, `inputActive:false`, `waitTicks:61`. The actual session is locked/secure, so this test cannot establish focus after native activation. It was executed and failed; it is neither skipped nor presented as passed. An unlocked rerun remains required.

Known upstream property-cache warnings, missing portals on private buses, intentional malformed-JSON/image-fallback diagnostics and the preexisting Swappy desktop-entry escape warning are distinguished from genuine errors. No warning filter was added. Corrected Settings, benchmark and private lifecycle logs contain no binding loops or QML exceptions. The original Settings warnings remain reproducible in the unmodified live code. `qmllint`, perf and pidstat are unavailable and were not installed or claimed as run.

## F. Performance and lifecycle

CPU is process ticks divided by monotonic elapsed seconds, normalized to one core. RSS is reported in MiB. Private profiling also reads `smaps_rollup`; memory mappings/shared-page accounting and initialization history limit cross-process comparisons. No source files were edited during either monitored process's sample windows. Raw results, scripts and logs are under `phase4-task6-evidence/`.

| Live/reference sample | Seconds | One-core CPU | RSS MiB start → end | FDs | Persistent children |
|---|---:|---:|---|---|---|
| Historical Phase 4, unlocked | 30 | 0.067% | final 221.34 | 65 final | 1 |
| Current locked session, five minutes | 300.278 | 0.706% | 224.42 → 224.42 | 70 → 70 | 1 → 1 |
| Current locked session, final repeat | 30.029 | 0.666% | 227.20 → 227.20 | 70 → 70 | 1 → 1 |

The historical 0.067% / 221.34 MiB reference describes a different unlocked closed-UI state. These current live samples are **locked-session measurements**, with private verification activity elsewhere on the host, and cannot establish an unlocked idle regression. Live descriptors and the persistent child identity remain stable. A later standalone memory snapshot reports private clean+dirty memory of 150.56 MiB; no matching pre-change private-memory sample exists.

The active locked shell was not subjected to UI/reload workloads. Instead, the actual corrected entrypoint was copied to an owned private instance with private bus/config/state, shell lock/server disabled, wallpaper/bar disabled and Niri IPC unavailable. The dock and real UI components were retained. A test-only IPC adapter assigns Dock search text and observes Settings state. These results establish the tested private lifecycle, not equivalent live-session input latency or compositor/GPU performance.

| Private scenario | Seconds | One-core CPU | RSS MiB start → end | Private MiB start → end | FDs |
|---|---:|---:|---|---|---|
| private-closed-initial-30s | 30.162 | 0.398% | 143.21 → 162.33 | 55.62 → 74.77 | 46 → 54 |
| launcher-12-open-close | 7.124 | 6.878% | 162.49 → 159.96 | 74.94 → 70.39 | 54 → 55 |
| settings-12-open-close | 7.092 | 1.692% | 160.12 → 167.31 | 70.56 → 75.55 | 55 → 56 |
| controlcenter-12-open-close | 7.100 | 6.198% | 167.31 → 170.01 | 75.55 → 78.20 | 56 → 57 |
| notifications-12-open-close | 7.069 | 5.517% | 170.01 → 170.37 | 78.22 → 78.72 | 57 → 57 |
| shortcuts-12-open-close | 7.047 | 9.650% | 170.17 → 183.12 | 78.40 → 91.04 | 57 → 60 |
| dock-12-open-close | 7.116 | 3.373% | 182.08 → 186.80 | 90.00 → 94.39 | 60 → 58 |
| media-12-open-close | 7.118 | 6.322% | 186.80 → 179.88 | 94.39 → 87.30 | 58 → 56 |
| settings-dock-80-search-assignments | 3.866 | 9.829% | 179.88 → 182.04 | 87.30 → 89.92 | 56 → 56 |
| closed-recovery-30s | 30.185 | 0.199% | 182.04 → 181.87 | 89.92 → 89.17 | 56 → 52 |
| closed-recovery-next-60s | 60.349 | 0.182% | 182.02 → 182.02 | 89.18 → 89.21 | 52 → 52 |
| supported-private-reload | 1.724 | 15.663% | 182.02 → 165.66 | 89.21 → 73.96 | 52 → 51 |
| post-reload-closed-60s | 60.335 | 0.298% | 165.66 → 179.78 | 74.01 → 88.01 | 51 → 47 |

Each UI group performs 12 open/close cycles; Dock search performs 80 assignments. Private Media reports no playback and no playback is launched. The endpoint checks show closed overlays/dock, zero brightness/audio watchers, capture off, and one persistent `nmcli monitor`. Reload replaces that child's PID while retaining a count of one.

The initial closed sample includes deferred initialization (descriptors increase), so it is not called a fully settled idle target. Recovery reaches approximately 0.18–0.20% CPU with stable RSS in the longer interval. The last 30.16 s of post-reload recovery measures 0.199% CPU and unchanged 179.78 MiB RSS; deferred descriptors fall 55 → 47. Reload and a colder/lazier working set explain why this is not evidence of a leak fix or optimization gain.

Inotify watch records in the private instance start at 104 and rise once to 112 when the shortcut registry is first used, consistent with its four fixed FileViews and their file/directory watches. They stay at 112 across subsequent workloads/recovery, returning to the lazy initial set on reload. This is bounded initialization, not an observed per-cycle subscription increase. The real shell's existing watch set is separate.

Timer code review found the existing 30 s wallpaper tick and hourly history pruning; bounded save/appearance debounces; a one-shot dock hide delay; brightness polling scoped to Control Center; and the visibility-scoped audio freshness/retry machinery. Media's position timer belongs to the loaded panel, and the lock's indefinite status pulse is gated off once secure. No new permanent invisible animation/poll loop was found. Diagnostics expose service watcher counts rather than every internal Qt timer; complete timer/thread attribution was not measured.

| Equivalent Settings run | Seconds | CPU seconds | One-core CPU | RSS MiB start → end | Binding warnings |
|---|---:|---:|---:|---|---:|
| before #1 | 5.414 | 1.45 | 26.782% | 92.02 → 93.45 | 200 |
| after #1 | 5.372 | 1.37 | 25.503% | 92.48 → 93.66 | 0 |
| before #2 | 5.392 | 1.42 | 26.335% | 92.17 → 93.09 | 200 |
| after #2 | 5.379 | 1.37 | 25.469% | 92.96 → 93.83 | 0 |

The Settings benchmark includes active query/model/delegate work and 20 ms event waits; it is not idle or a physical typing-latency benchmark. The modest CPU differences are observations, not a general optimization claim. Memoization is retained where it was useful. The historical ~7.993% post-cycle transient was not reproduced as sustained recovery activity in this private run. Its original cause remains **unexplained**; there is no evidence to attribute it to the Settings loop or audio. No speculative optimization was introduced, and finite stable windows do not prove absence of all long-term leaks.

## G. Non-destructive security assessment

- Effective `security.useShellLock:true` predates this task. The current WlSessionLock reports secure; no real-password authentication success has been established by the user in this task.
- Lock submission requires the compositor-secure state and successful PAM completion; the existing PAM service clears its pending buffer on completion/error/abort and uses `/etc/pam.d/login`. Its configuration was not modified. This code review is not a successful authentication test.
- `/usr/bin/swaylock` and executable `~/.local/bin/niri-lock` remain present. Super+Alt+L, lid-close and swayidle use that wrapper. Swayidle remains running with its existing lock/dim/off/suspend rules. None was disabled or executed for testing.
- The wrapper falls back to swaylock if shell confirmation is unavailable. It exits when `isSecure` reports true; therefore it does not verify PAM and does not automatically recover from an authentication failure after secure acquisition. Its 30 × 0.1 s polling sleeps are not a guaranteed three-second total: individual IPC calls also have two-second timeouts.
- **The current Settings security description overstates universal fallback coverage.** Control Center, Power Menu and `lock lock` call `LockService.lock()` directly; with the current preference they call `lockShell()` without going through the external fallback wrapper. This preexisting independent lock-work discrepancy is documented, not silently redesigned or routed differently.
- Shell-lock crash/recovery, PAM success/failure and the recovery command suggested in the independent changelog have not been validated here. They must not be represented as a proven recovery procedure.

No password was requested, read, submitted or stored by the audit. No authentication, real lock/unlock cycle, PAM change, lock-preference change, fallback replacement, swayidle change, power action or Niri/PipeWire/WirePlumber restart was performed. The secure active lock was left intact. **Unverified authentication and fallback/recovery coverage prevent unconditional release readiness.**

## H. Remaining safe manual verification

1. First unlock the current session normally, if possible, and confirm whether your own real password worked; never send credentials. Until the session is unlocked, do not reload/edit the QML that owns the lock.
2. Once unlocked, recheck concurrent changes, apply/review the four-file task-only patch, run the complete 207-assertion regression again, and inspect fresh runtime logs. Native focus, ordinary close-to-application focus restoration and a five-minute **unlocked**, settled live sample remain outstanding.
3. Physically traverse the dock edge and gaps; exercise hover, interior buttons, click-outside and Escape. Check Tab/Shift+Tab, Space, Return/keypad Enter, slider dragging/arrows/wheel, favorite selection/clearing and persistence.
4. Inspect text/focus contrast over actual bright/dark wallpapers with glass on/off and reduced motion on/off. Judge 144 Hz smoothness directly; no frame-time/FPS certification was made. Test physical multi-monitor placement/hotplug only if another display is available; only eDP-1 was observed here.
5. Check cheat-sheet filtering/navigation/category keys and saved-source refresh. It must remain informational; unsupported external include layouts need independent native verification.
6. During normal real playback, open Media, verify actual amplitude, pause/stop to verify calm/stale expiry, close to verify capture stops, and manually exercise normal output-device changes. Automated virtual-sink tests do not certify every physical device.
7. Before any future lock-authentication experiment, save work and establish a **previously tested** fallback/recovery path (including accessible alternate TTY login). Only the user should perform successful/failed authentication checks. Merely finding the swaylock binary or an untested changelog recovery command is insufficient; if recovery is not established, defer that experiment. No additional lock test should be forced to obtain a passing result.

## I. Cleanup and rollback

The private lifecycle instance and isolated test buses exit; owned virtual sinks/capture trees are removed by the PipeWire suite. Final scanning finds no test QS, `audio-levels.py` or `pw-cat` process. The real QS has its original one `nmcli monitor` child (PID 197630).

Five additional `nmcli monitor` processes (183864, 184135, 184377, 184879, 185161) predate Task 6: start times 00:12:16–00:13:37, adopted by user systemd in the VS Code cgroup. They were not introduced by these tests and were not killed as unrelated processes. Their original purpose is unverified. The lifecycle evidence does not falsely claim that only one monitor exists globally.

Temporary Task 6 working copies are removed after preserving the patch, all four pending files and raw evidence. The checkpoint remains. No incomplete runtime experiment was enabled in the authoritative project.

There is no deployed Task 6 runtime correction to roll back. Removing this task's newly added report/evidence would undo its authoritative-project additions; it would not affect prior work. If the prepared patch is subsequently applied, rollback scope is **only** `components/Settings.qml`, `selftest-settings-search.qml`, `tests/run-qml.py`, `tests/validate.sh`: first check the reverse patch against any newer edits, and operate only in an unlocked session. Do not restore the whole checkpoint over newer independent work or change lock settings as part of rollback.

## J. Final working state

QS PID **12157**, Niri PID **12079**, Mako **12139**, PipeWire **3817**, WirePlumber **3818** and pipewire-pulse **4123** remain running. Current Niri configuration validates. Real diagnostics report Niri/audio/network/brightness ready, reconnect count 0, Mako authoritative, overlay empty, dock closed, capture off and zero brightness/visualizer watchers. The observed real session remains locked/secure; real authentication remains unverified.

Previous feature source is preserved, private correction/regression evidence is complete, and no new persistent helper or unexpected corrected-path QML exception was observed. **The Settings correction and unlocked native/live validation remain pending.** No Phase 5 work was started and no remote publication was performed.
