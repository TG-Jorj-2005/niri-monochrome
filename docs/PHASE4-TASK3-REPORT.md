# Phase 4 — Task 3/6: glass, contrast and blur reliability

Date: 2026-11-12, Europe/Bucharest. Authoritative project: `~/.config/quickshell/niri-monochrome`.

## A. Result and checkpoint

Task 3 implementation and available automated verification are complete. Physical compositor appearance and end-to-end frame timing retain the manual limits below. Task 4 was not started.

The current Phase 4/Task 1/Task 2 reports, Theme/UserConfig, appearance generator, Settings controls, bar, dock, overlay, relevant panels and tests were inspected. Existing uncommitted work was preserved. No other collaboration agent was active; files were compared against the checkpoint before application. Git was not reset, committed or pushed. The older `~/niri-monochrome` project was untouched.

Reversible checkpoint: `/home/jorj/.config/niri-monochrome-phase4-task3-backups/20261112-175224` (project including Git metadata, Niri files, user settings, initial Git status). Baseline tests and a 30-second sample were recorded before runtime changes.

## B. Confirmed findings and corrections

The new rendering fixture reproduced **five contrast failures**, with 13/18 targeted assertions passing before correction:

1. At minimum supported opacity 0.82, secondary text `#A0A0A0` fell below the 4.5:1 reference on almost-white wallpaper and white pattern cells. In the actual rendered fixture the ratios were **4.484** and **4.417**. Cause: the secondary token was chosen without allowing for the brightest permitted composited background. Correction: refine the existing secondary token to `#A4A4A4`; measured ratios become **4.704** and **4.633**.
2. Enabled small section headings and informational labels used the muted icon color or disabled-text color. Headings measured only **2.618/2.579** on those bright backgrounds. Correction: use the existing secondary-text token for enabled headings, launcher descriptions/help/counts, calendar weekdays, media labels, notification history/app labels, Settings information/logs, workspace numbers, bar date and nonfocused window titles. Actual disabled-control opacity and the `#666666` disabled token remain unchanged. Settings palette captions now choose light/dark text appropriate to their swatch.
3. Muted icons and the actual slider focus outline used `#777777`, falling below 3:1 on bright glass. Correction: refine existing `silverMuted` to `#888888` (approximately 3.26:1 against the sampled white-pattern panel background). This retains the grayscale hierarchy and existing focus handlers.
4. The enabled text field's placeholder used disabled `#666666` on opaque `#191919`, approximately **3.06:1**. Correction: use secondary text for the actual MonoTextField placeholder. Disabled controls continue using their existing opacity rules.

These are palette/semantic-color corrections. No layout, opacity preference/range, dock geometry, animation duration, shader, persistent timer or helper process was added. The five failing checks now pass, together with the full prior regression suite. Blur generation and persistence already behaved correctly in the exercised paths and were preserved.

The numeric references use [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) as an engineering check for small text. They are not a claim of complete accessibility conformance or subjective readability certification.

## C. Design, transparency and rendering

Inspected BottomBar, AutoHideDock, Launcher, ControlCenter, NotificationCenter, Settings, CalendarPopover, MediaControls, ShortcutCheatSheet, TrayMenu, shared Panel/PopoverFrame and reusable controls. Existing shared surface/radius/border tokens remain authoritative. Selected silver surfaces retain dark inverse text. Opaque nested cards/inputs retain their dark surfaces; disabled states retain their opacity reduction. Popovers retain the existing screen scrim and local chrome. Tooltip strings do not introduce a separate custom glass surface in these controls.

The isolated QtTest fixture instantiates actual **Panel, Label, SectionTitle, MonoTextField and MonoSlider**, renders them into images, samples composited pixels and calculates relative-luminance ratios using actual foreground colors. Backgrounds: almost black `#080808`, dark gray `#303030`, medium gray `#808080`, almost white `#FAFAFA`, and a black/white checkerboard. Both black and white extrema are covered without touching real wallpapers. At opacity 0.82 the measured secondary/heading ratios are 7.848, 7.391, 6.383, 4.704, and 4.633.

The fixture verifies actual alpha composition, focus-outline color contrast, enabled placeholder contrast, opacity bounds/type recovery, glass on/off/on, and opaque fallback. In glass-off mode sampled panels are opaque `#111111` over all five backgrounds. PNG artifacts show minimum opacity, default 0.92, and opaque mode in `phase4-task3-evidence/`; these are synthetic offscreen renders, **not screenshots of Niri blur**. Reviewing them does not replace checking the real display, antialiasing and compositor.

The normal surface hierarchy, nested opaque input/cards, one-pixel borders, radii and subtle outline/highlight shadows were retained. Existing MultiEffect use is for grayscale imagery; no desktop capture, new offscreen effect or full-screen fake blur was introduced. Overlay/dock reveal remains state-driven and hidden surfaces stop displaying. No new continuous redraw or polling was introduced by the correction.

## D. Niri blur and appearance persistence

Verified installed **Niri 26.04** and its local `Configuration:-Layer-Rules.md` / `Configuration:-Miscellaneous.md` documentation. Actual supported `background-effect` syntax is used. The generated include is loaded by the real main Niri config and contains exactly two anchored namespace rules: `^nm-bar$` and `^nm-dock$`, each with glass-controlled `blur true/false`, `saturation 0`, `noise 0.01` and existing bounded shadows. The older bar-shadow rule is separate; no duplicate blur rule was found. No rule targets `nm-overlay`, unrelated applications or the full screen.

Live layer inspection confirmed `nm-bar` and, while explicitly shown, `nm-dock`; after dismissal only the normal wallpaper/bar/dock-trigger surfaces remained. Bar and dock windows are sized to their local content. Rules, compositor settings and geometry were not changed. `niri validate` and generated-file validation passed. A perceptual blur/corner check remains manual; layer inspection proves namespaces and valid configuration, not rendered blur pixels.

Appearance controls already exist for glass, opacity, radius, shadow, reduced motion and animation intensity. UserConfig normalizes types, clamps opacity 0.82–1, radius 0–24, shadow 0–0.65, and persists through its existing atomic write/debounce. The private test exercises missing-file defaults, malformed opacity types/nonfinite values, invalid JSON retaining the last valid appearance, settings changes and file reload.

The generated rules switch off and back on after actual UserConfig.set calls; radius and shadow updates propagate. Nondefault preferences are persisted and restored by a **new Quickshell process** using the same private config. Repeated write requests leave generated KDL mtime unchanged; process restart also leaves that mtime unchanged. Reduced motion and intensity survive persistence/restart independently of glass. All tests use private config/state/runtime directories and a private session bus. User configuration was never reset.

## E. Files changed by Task 3

| File | Purpose |
|---|---|
| `config/Theme.qml` | Refine secondary text and muted icon tokens. |
| `components/ui/SectionTitle.qml` | Readable enabled section headings. |
| `components/ui/MonoTextField.qml` | Readable placeholder. |
| `components/bar/WorkspaceIndicator.qml` | Readable inactive workspace numbers. |
| `components/bar/ClockIndicator.qml` | Readable date label. |
| `components/bar/FocusedWindow.qml` | Readable nonfocused title. |
| `components/popovers/Launcher.qml` | Descriptions, result count and navigation instructions. |
| `components/popovers/ControlCenter.qml` | Enabled tile subtitles. |
| `components/popovers/NotificationCenter.qml` | History metadata. |
| `components/popovers/CalendarPopover.qml` | Weekday labels. |
| `components/popovers/MediaControls.qml` | Playback/player metadata. |
| `components/Settings.qml` | Informational labels, logs and swatch captions. |
| `components/NotificationToasts.qml` | App-name labels. |
| `selftest-glass.qml` | 18 rendering/configuration checks plus one process-restore check. |
| `tests/run-qml.py` | Existing runner: missing-config fixture, real process restart, generated KDL validation/mtime check. |
| `tests/validate.sh` | Include glass fixture in existing suite. |
| `docs/PHASE4-TASK3-REPORT.md` | This report. |
| `docs/phase4-task3-evidence/` | Raw logs/metrics, synthetic renders, preservation checks and task-only patch. |

The task-only patch distinguishes these changes from older uncommitted Phase 4 work. Task 1 OverlayLayer/input shield and six tests, Task 2 MonoToggle keypad-Enter fix and 26 tests, existing Phase 4 tests, UserConfig, AppearanceService, dock implementation, shortcut registry, audio backend and LockScreen are byte-identical to the checkpoint. All Niri/user-setting files also match checkpoint bytes (`preservation.json`).

## F. Performance

Same live Quickshell PID **12157**, Niri PID **12079** remained running. CPU uses process ticks normalized to one core and monotonic elapsed time; RSS uses resident pages. No source edits were performed during samples. Historical Task 2 final values were 0.200% / approximately 209 MiB; the earlier Phase 4 reference was 0.067% / 221.34 MiB. These are references, not thresholds.

| Observation | Seconds | Mean CPU | RSS MiB start → end | Descriptors start → end |
|---|---|---|---|---|
| Before changes, closed-shell idle | 30.0 | 0.100% | 207.90 → 207.90 | 66 → 66 |
| After changes, before live panel cycles | 30.0 | 0.067% | 207.34 → 207.16 | 64 → 64 |
| First post-cycle observation | 30.0 | 7.993% | 209.90 → 242.69 | 71 → 77 |
| Follow-up observation | 30.0 | 2.498% | 240.12 → 237.77 | 77 → 67 |
| After second cycle batch | 30.0 | 0.666% | 238.81 → 237.90 | 70 → 67 |
| Final, 30 s following supported live reload | 30.0 | 0.466% | 215.20 → 210.24 | 65 → 64 |

Two bounded live batches each opened/closed shortcuts, launcher, Control Center and Notification Center four times (**32 panel cycles total**) and showed/hid the dock once. No device actions, audio playback, settings edits or application launches were invoked. First batch CPU averaged **24.924%** during 11.68 seconds; the warm repeat averaged **6.591%** during 10.47 seconds. There is no matched pre-change interaction measurement, so neither value establishes a styling improvement/regression.

The first post-cycle observation contains a real transient: CPU **7.993%**, RSS reaching approximately **242.94 MiB**. It is retained in the evidence, not discarded. Follow-up CPU declined to 2.498%, then 0.666%. Warm repeat RSS ended 238.81 MiB and returned to 237.90 MiB after observation; descriptors returned to 67. One supported live Quickshell reload then completed successfully; its 30-second sample includes initialization and ended at **210.24 MiB**, CPU **0.466%**, descriptors 64. Reload was a lifecycle check, not a memory-leak fix. The first pre-cycle idle sample after the palette correction was **0.067% / 207.16 MiB**, comparable to baseline **0.100% / 207.90 MiB**.

Investigation checked visible layers, actual process/descriptor types and backend subscriptions. No overlay/dock remained open, brightness watchers and visualizer watchers returned to zero, capture remained off, and the persistent child remained one `nmcli monitor`. No helper count growth was observed. Descriptors declined after the transient; repeated batches did not show cumulative growth at each dismissal. The retained RSS/activity variance is not attributable to the two color tokens from these observations, and its exact source was not established. No speculative optimization or unrelated cache rewrite was attempted. These finite measurements do not prove absence of long-term leaks, ideal idle on every workload, GPU speedups or perfect 144 Hz rendering.

Focus returned to the same real Niri window **4 → 4** in the first batch. The repeat had no focused normal window at both boundaries; that repeat is not counted as evidence of restoring an application window. No Niri restart occurred. No persistent runtime timer/process or new render effect was added by Task 3.


## G. Actual test results

| Assertion suite | Baseline | Final |
|---|---|---|
| Niri IPC fake-socket integration | 16/16 | 16/16 |
| Core config/state/monitor | 14/14 | 14/14 |
| Wallpaper decoder/fallback | 2/2 | 2/2 |
| Existing Phase 4 | 10/10 | 10/10 |
| Task 1 overlay input | 6/6 | 6/6 |
| Task 2 interactions/focus/motion | 26/26 | 26/26 |
| Task 3 rendering/config | Not present; pre-fix probe 13/18 | 18/18 |
| Task 3 new-process restore | Not present | 1/1 |
| **Total integrated assertions** | **74/74** | **93/93** |

`tests/niri-ipc-test.sh` and `tests/validate.sh` exited 0. QML component loading, actual shell entrypoint, three isolated reloads, generated appearance validation, desktop-entry/JSON/shell checks passed. ShellCheck and `git diff --check` exited 0. Installed `qmllint` was not found and is not reported as run. No dependencies were installed.

No unexpected QML errors, broken bindings or binding loops were found in the successful final tests/runtime logs. Intentional invalid-JSON warnings are expected test stimuli. Known Quickshell property-cache warnings and the pre-existing Swappy desktop-entry Exec escaping warning recur; they were already present in the baseline and prior reports. They were not treated as new glass defects or silently fixed outside this scope.

## H. Remaining manual verification

- Actual bar/dock blur, corner alignment, saturation and shadow appearance against the user's wallpapers; automated snapshots do not sample compositor blur.
- Physical visual comfort of small antialiased text, checkerboard backgrounds and disabled/selected states on the real display.
- Physical dock-edge traversal/hover, tray submenu interaction and focus under other applications/monitor arrangements.
- Frame pacing and subjective motion at 144 Hz; no reliable end-to-end GPU/frame-time measurement was available.

## I. Final working state

The live shell is running and reports Niri/audio/network/Bluetooth/brightness ready; notifications remain with Mako, experimental shell notification ownership and shell locking remain disabled. Overlay and keyboard dock state are closed, temporary watchers are zero and audio capture is off. One normal persistent `nmcli monitor` child remains; no test capture/backend is enabled. Niri configuration validates and its session PID is unchanged.

User settings, wallpapers, Niri bindings and generated appearance contents are preserved. Task 1/2 code/tests remain intact, all 93 integrated assertions pass, and no incomplete feature or temporary test UI remains active. The checkpoint above and task-only patch make the corrections reversible. Stop after Task 3.

