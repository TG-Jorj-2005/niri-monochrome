# Phase 4 — Task 4/6: real-audio capture and resource investigation

Date: 2026-11-12, Europe/Bucharest. Project: `~/.config/quickshell/niri-monochrome`.

## A. Result and checkpoint

Task 4 is complete for the available automated/backend verification. Two reproduced audio correctness defects were fixed; the general desktop transient remains unattributed and an independent Settings warning is documented below. Remaining physical device/policy/frame-pacing checks are explicitly limited. Tasks 5 and 6 were not begun.

Existing uncommitted Phase 4 and Tasks 1–3 work was preserved. The current reports, audio/default-node service, PCM helper, MediaControls/AudioVisualizer, configuration and tests were inspected. No other collaboration agent was active. Checkpoint before edits: `/home/jorj/.config/niri-monochrome-phase4-task4-backups/20261112-231911`, containing the project including Git metadata, Niri/user configuration, shell state and initial Git status. The older `~/niri-monochrome` project was not modified. The full pre-change baseline passed **93/93**; the first run interrupted by the resumed conversation was incomplete and was rerun to completion. Its identified orphan private test bus was cleaned up; it was not an audio capture process.

## B. Capture correctness and confirmed defects

The visualizer remains an **RMS/dB amplitude history or level meter**, not an FFT or independent frequency bands. The real helper explicitly records a named output monitor, 16 kHz signed 16-bit mono PCM, 533 samples per 1066-byte frame. Its logarithmic normalization has a -60 dB floor and clamps to 0–1. Incomplete final frames exit without emitting a partial/spurious level. Buffers and history remain bounded. No random animation or microphone fallback was added, and no audio samples are retained by the shell.

**Wrong-target fallback after output removal.** Before correction, a real temporary sink monitor was linked to the requested virtual output. After that sink was removed, `pw-dump` showed the same capture node silently relinked to the physical default output, while the Python helper stayed running. Cause: the helper used `stream.dont-reconnect`, which the installed WirePlumber linking policy does not read, and omitted protection against initial fallback. Small correction: use **`node.dont-reconnect=true` and `node.dont-fallback=true`**, retaining `stream.capture.sink=true`, passive capture and explicit target selection. Repeating the real removal test produced no capture nodes/links and helper exit code 3. A real QML/backend integration test also verifies that removing the selected virtual sink never relinks it to hardware.

This follows the installed WirePlumber scripts (`linking/prepare-link.lua`, `linking/find-defined-target.lua`) and the [PipeWire property reference](https://docs.pipewire.org/page_man_pipewire-props_7.html). The installed [pw-cat interface](https://docs.pipewire.org/page_man_pw-cat_1.html) supports explicit target names and raw rate/channel/format selection.

**Stale amplitude when passive PCM stops.** With real tone playback, stopping the player caused the passive virtual sink to stop producing PCM without closing the capture stream. The direct helper probe received 15 levels during playback and **zero frames in the next four seconds**. The original QML service still showed amplitude **0.401895**, `status=ready`, and old history after four seconds. Cause: silence handling existed only for received zero samples, with no expiration when samples stop entirely. Small correction: a **750 ms one-shot freshness timer** is restarted only by valid frames from a running recorder. If frames cease, it clears stale amplitude/history and returns the caption to waiting. It does not synthesize PCM or append artificial history. It stops when capture is no longer desired or the helper exits. There is no persistent idle polling or continuous zero-frame generator.

The corrected real test verifies abrupt playback stop becomes calm/waiting, playback resumes, and actual silent PCM also decays to exact zero. Attack/release coefficients, bar count/style, normal motion gating and the existing 60 ms height interpolation remain unchanged.

## C. Lifecycle verification

Actual MediaControls, AudioVisualizer, VisualizerService, Python helper and pw-cat were exercised in a private project/config/state/runtime and private session bus with temporary null sinks. Only AudioService selection/availability was replaced by a test fixture so output switching could be exercised without changing the user's default. Transport/PCM and graph links were real; selection/error control-plane simulation is explicitly distinguished from physical hotplug.

Verified closed/no capture; open/one helper plus one pw-cat; two visible views sharing that one capture; disable stopping capture; hidden re-enable staying stopped; reopen; appearance changes retaining the same helper PID; repeated open/close; backend unavailable/reavailable; target replacement; target removal/reconnection; exhausted recovery; and isolated shell exit while capturing. The first helper failure uses SIGKILL on the **owned private test helper** to verify the existing kernel parent-death guard terminates pw-cat. Further intentional helper exits verify exactly three retries, two-second one-shot delays, then unavailable/no restart loop. Closing resets recovery state; reopening works. No audio daemon was killed or restarted.

The deterministic component test additionally checks idempotent subscription, effective ancestor visibility, destruction, 20 deferred create/destroy cycles, invalid amplitudes, deterministic attack/release, exact-zero silence, bounded history/actual bar heights and reduced motion. QObject destruction is checked after returning to the event loop, rather than treating deferred deletion as a leak.

On the **real live shell**, capture graph links were verified to the current default output (`Audio/Sink`, not the input device), with the corrected properties. A supported Quickshell reload while Python/pw-cat PIDs **175092/175102** were active terminated both, restored ready diagnostics and left zero watchers/capture. The current audio defaults and real user config were identical immediately before/after this test. Niri was not restarted. A final strengthened private test also verifies automatic monitor reconnection when the removed sink returns with the **same name**; the retry-exhaustion scenario begins from a fresh visibility activation, matching the existing per-activation retry budget.

Initial attempts to reload an offscreen QtTest fixture exposed installed test-environment limitations (`QTestRootObject` on engine recreation and Quickshell's reload popup lacking a PanelWindow backend). Those probes were rejected as passes. The final transport fixture is QtTest-free, the deterministic fixture does not reload, and active-capture reload is verified through the supported real shell instead. These probe limitations did not justify modifying production UI or suppressing unexpected errors.

## D. Output/device and failure coverage

The production target still binds to `AudioService.sink.name`, whose sink is `Pipewire.defaultAudioSink`. The deterministic test checks this actual binding. Private control-plane changes between **two real virtual outputs** restart capture on the newly selected monitor; graph links verify it leaves the old one. Real null-sink removal, recreation, unexpected process exit and an unavailable PipeWire endpoint were tested. No unavailable target was allowed to fall back to a microphone or other output after correction.

During the first long profile, a real Bluetooth output/input appeared and the session defaults changed from built-in audio to that device. The strict preservation assertion correctly aborted that run; its partial measurements/logs are retained. The test issued no default-selection or existing-stream-move command. The current Bluetooth choice was **preserved**, not reset to the earlier baseline, and the completed run uses a fresh baseline. This observation is not claimed as an active-capture physical hotplug test: the production visualizer was closed at that time.

Physical unplug/replug, Bluetooth profile changes under an active production capture, permission denial imposed by real session policy, and PipeWire/WirePlumber daemon restart are not fully exercised. Neither user audio service was restarted for testing. Standard backend connection failure is tested against a nonexistent private endpoint and emits no fabricated amplitude.

## E. Performance and Task 3 transient

CPU uses `/proc` ticks normalized to one core (100% = one fully occupied core), monotonic elapsed time and resident pages. Measurements are observations, not arbitrary targets. No source edits occurred during samples. Private audio runs use an offscreen actual MediaControls window, so their absolute RSS/render CPU must not be compared directly with the complete live desktop shell. Each private profile polls test IPC once per second; this bounded instrumentation is identical across its scenarios.

| Isolated audio scenario | Actual seconds | QS CPU | QS + stable children CPU | QS RSS MiB start → end | FDs start → end |
|---|---|---|---|---|---|
| Closed | 31.789 | 0.031% | 0.031% | 67.93 → 68.11 | 15 → 14 |
| Open, no playback | 31.926 | 0.063% | 0.063% | 86.45 → 86.45 | 24 → 21 |
| Open, real virtual-sink tone | 32.189 | 9.320% | 9.910% | 86.67 → 89.37 | 21 → 29 |
| Closed after playback | 32.037 | 0.000% | 0.000% | 89.49 → 89.49 | 26 → 17 |
| Recovery after 12 media cycles | 64.098 | 0.031% | 0.031% | 89.49 → 89.28 | 22 → 17 |

Real PCM/history updates measured **30.006 Hz** during the steady tone window; QS had one Python helper and one pw-cat while open, none after closing. No levels changed during either closed recovery window. Suspended/no-playback capture was passive and produced no frames or invented motion. Existing height interpolation is motion-gated; no frame-rate cap or 144 Hz screen-frame benchmark is claimed.

Before the freshness correction, a completed tone window in the subsequently interrupted profile measured QS **9.012%**, group **9.640%**, over **31.846 s** (RSS 87.09 → 89.25 MiB). The corrected comparable virtual-tone window measured **9.320% / 9.910% over 32.189 s**. This is a correctness fix, not a demonstrated CPU optimization. Ambient desktop/device conditions differ, so the small difference is not given a causal performance interpretation. Retained component/font/render caches are plausible contributors to post-open RSS, but their exact allocation source was not proven. Stable recovery and descriptor cleanup do not prove absence of all long-term leaks.

| Full live shell, separate non-media workload | Actual seconds | CPU | RSS MiB start → end | FDs |
|---|---|---|---|---|
| Before-cycle observation (includes user UI activity) | 30.003 | 2.966% | 244.63 → 244.54 | 65 → 66 |
| 16 original non-media panel cycles + dock | 11.781 | 23.851% | 244.54 → 247.30 | 66 → 71 |
| Closed recovery | 30.004 | 0.867% | 248.23 → 243.52 | 72 → 69 |
| Further closed recovery | 60.006 | 0.133% | 243.52 → 241.64 | 69 → 67 |

All samples in that workload had visualizer capture **false** and watchers **0**. The before-cycle window included two samples with the Power overlay open and is therefore **not a pure idle benchmark**; recovery windows had no overlay in all 30/60 samples. Per-thread snapshots are retained, but are not sufficient to attribute allocations or all CPU (short-lived threads are not included in common-thread deltas). The initial Task 4 30.023-second observation was also capture-off, CPU **8.194%**, RSS **243.81 → 240.59 MiB**; it did not continuously prove an idle user interface.

**Out-of-scope finding:** the retained live log contains 19 warnings `Binding loop detected for property "model"` at **Settings.qml:141**, the Dock “Add application” search Repeater. That component and ApplicationService are unchanged by Task 4. The binding calls a stateful memoized `ApplicationService.search()`; cache writes during binding evaluation are a plausible cause, requiring a separate targeted UI investigation. This is not an established cause of Task 3's historical transient. The warnings preceded the final supported reload; no recurrence/error appeared in its subsequent retained log segment. Both the full tail and the segment after the last reload are saved, so the finding is not hidden.

The exact **Task 3 CPU/RAM transient remains unattributed**. It was not reproduced as a sustained post-media capture workload: private post-close CPU recovered to about 0.03%, and the live non-media recovery reached 0.133% with capture off. Other UI activity and the independent Settings warning are concrete confounders/candidates, not proof of the historical cause. No unrelated UI/cache rewrite, security change or speculative optimization was made.

Final supported-reload live sample: **30.030 s, 0.100% CPU, 216.80 → 212.67 MiB RSS, FDs 74 → 65**, one persistent `nmcli monitor` child. This includes initialization/recovery; the lower RSS after reload is not described as a leak fix or an optimization gain.

## F. Files changed

- `scripts/audio-levels.py`: replace the ineffective reconnect property and prohibit fallback to a different target.
- `services/VisualizerService.qml`: expire stale display state with one bounded freshness timer; stop it on lifecycle transitions.
- `selftest-visualizer.qml`: 14 deterministic checks on the real component/service, with actual capture disabled in that fixture.
- `tests/audio-helper-test.py`: 9 standard-library tests of real RMS/helper processing, fragmented/truncated PCM, shutdown and unavailable endpoint. The fragmented PCM transport is explicitly simulated with a private pw-cat fixture.
- `tests/visualizer-integration.py`: opt-in real null-sink capture/graph/lifecycle tests and comparable workload profiling; cleanup is scoped to owned test processes/modules.
- `tests/fixtures/visualizer-live.qml`: QtTest-free actual MediaControls/backend fixture for private lifecycle testing.
- `tests/validate.sh`: run the additional deterministic QML/helper cases with the existing suite.
- `docs/PHASE4-TASK4-REPORT.md`, `docs/phase4-task4-evidence/`: this report, raw logs/profiles, task-only patch, preservation checks and bounded probe scripts.

No appearance, shortcut registry/binding, dock, workspace, lock/PAM, Mako or compositor rewrite was made. No dependency was installed. Existing tests were not weakened. No commit, reset or push was performed.

## G. Actual tests

| Named integrated checks | Baseline | Final |
|---|---|---|
| Niri IPC | 16/16 | 16/16 |
| Core | 14/14 | 14/14 |
| Wallpaper | 2/2 | 2/2 |
| Existing Phase 4 | 10/10 | 10/10 |
| Task 1 overlay | 6/6 | 6/6 |
| Task 2 input/focus/motion | 26/26 | 26/26 |
| Task 3 glass + process restore | 19/19 | 19/19 |
| Task 4 deterministic component | — | 14/14 |
| Task 4 PCM/helper test methods | — | 9/9 |
| **Integrated total** | **93/93** | **116/116** |

The separate real PipeWire suite passed **24/24** in its completed profile and **24/24** in the final strengthened reconnection/lifecycle run. These are separate scenario runs, not additional integrated assertion totals. The supported real-shell active-capture reload passed as described above.

`tests/niri-ipc-test.sh` and `tests/validate.sh` exited 0, including all previous tests, QML component loads, the actual shell entrypoint and three isolated reloads, generated appearance KDL validation, current JSON, desktop entry and shell syntax. ShellCheck, Python AST parsing, `niri validate`, and `git diff --check` passed. `qmllint`, perf and pidstat were not available; none was installed or falsely reported as run.

No unexpected audio QML errors or binding loops occurred in the successful private tests. The distinct real Settings binding-loop warning is recorded above. Known property-cache override and pre-existing Swappy desktop-entry escaping warnings remain distinguished from new audio defects. Failed probes (stale state, unsupported offscreen reload, deferred-deletion timing and the test retry-budget setup) are retained/explained rather than counted as passes.

## H. Safety

Niri PID **12079**, QS PID **12157**, PipeWire PID **3817**, WirePlumber PID **3818** and pipewire-pulse PID **4123** remained running; no audio/compositor daemon was restarted. No volume, mute, brightness, default-device setter or preexisting-stream-move operation was used. All synthetic playback targeted temporary null sinks. Their modules and all owned helpers were removed; actual routing/defaults matched each completed run's baseline.

The initial real defaults changed naturally when a Bluetooth device appeared during the interactive session. That change was preserved rather than reverted. The real user JSON also differs from the checkpoint at **dock.favorites** during this session; Task 4 writes configuration only in private test directories and retained the current favorites. Live reload's before/after user JSON was identical. All Niri files match checkpoint bytes. All existing project files other than the two audio implementation files and test-suite registration remain byte-identical, including prior Theme/overlay/keypad-Enter/appearance/shortcut fixes and tests. The preservation artifact records these distinctions instead of falsely claiming the user's interactive preferences never changed.

No raw user audio was written to disk; only synthetic test tone/silence files existed temporarily. No dependency/security/PAM/Mako/shortcut changes were made.

## I. Remaining manual verification

- Physical removal/reconnection and Bluetooth profile transitions while the production visualizer is already capturing; confirm the new current output is followed.
- Actual session-policy permission denial and audio daemon interruption/recovery; these were not forced on the user's session.
- Perceptual response, very quiet material and UI smoothness on the real display. PCM ingestion is approximately 30 Hz; this is not a measured screen-frame rate or a claim of perfect 144 Hz pacing.

## J. Final state

The shell is operational; Niri configuration validates. Final diagnostics report Niri/audio/network/Bluetooth/brightness ready, Mako retained, overlay/dock closed, capture false and both temporary watcher counts zero. Only the normal `nmcli monitor` child persists. No test sink or running pw-cat/audio-levels helper remains in the verified final state. The unrelated Settings favorite-search warning remains recorded for a separate targeted task, without an unfinished audio feature left enabled.

The checkpoint above and the task-only patch make the changes reversible. Task 4 stops here; no Task 5/6 implementation was started.
