# Phase 4 — Task 2/6: micro-interactions and focus reliability

Date: 2026-11-12, Europe/Bucharest. Scope completed: Task 2 only. Task 3 was not started.

## 1. Initial state and safety checkpoint

The authoritative code was `~/.config/quickshell/niri-monochrome`. Git already contained uncommitted Phase 4 and Task 1 work; those changes were preserved. Current code, reports, audit, input components, motion configuration and tests were inspected. No concurrent source changes were observed; the runtime correction was checked against the checkpoint immediately before application.

Checkpoint: `/home/jorj/.config/niri-monochrome-phase4-task2-backups/20261112-173221` (project with Git metadata, Niri files, user settings and initial Git status).

The baseline suite passed **48/48** before any runtime edit: IPC 16, core 14, wallpaper 2, Phase 4 10, Task 1 overlay 6. Existing component loading, three isolated reloads and Niri validation passed.

## 2. Pointer behavior

Synthetic Qt events on actual MonoButton, IconButton, MonoToggle and MonoSlider components verified:

- Hover feedback after fixture layout settlement.
- Exactly one button action per click/release; press compression changes scale without changing layout width; release returns to scale 1.
- Disabled buttons, switches and sliders reject pointer actions.
- Nested button, switch and slider input does not dismiss the containing overlay.
- Slider dragging updates only its mock backend and retains the external backend binding.

Task 1's bounded interior MouseArea and its **six assertions are byte-identical to the checkpoint**. That test again verifies panel padding, Close, Up/Down, Escape and outside dismissal.

Dock code was reviewed: one parent HoverHandler, one-shot hide timer, hover scaling without layout-size changes, and existing trigger cleanup. An attempted deeper synthetic hover traversal could not enumerate the private window bodies through `Scope.children`: installed Quickshell 0.2.1 reports `List doesn't define a Count function`. This is a limitation of the temporary probe, not evidence of dock flicker. Dock runtime code was left unchanged; physical edge-to-dock and child-boundary traversal remain manual.

## 3. Keyboard and focus behavior

The isolated control fixture verified Tab → icon button → toggle → slider and Shift+Tab back to the toggle, with actual `activeFocus` checks. Space/Return/keypad Enter each activate the regular button exactly once; icon-button Return works. Slider Right, Home and End update its mock backend within bounds.

Shortcut overlay's existing Up/Down/Escape and Close checks remain passing. Launcher search-focus entry and bounded selection handlers, Control Center/Notification Center nesting, Settings loader/focus routing and overlay dismissal were inspected; no layout/service redesign was made. Automated activation uses mock counters and never launches applications or invokes destructive actions.

A safe live open/close cycle observed focused Niri window ID **27 → 27**; automatic restoration to the same window was **True**. This one sample does not certify every compositor, monitor or physical-input condition.

## 4. Confirmed bug and minimal correction

**Original issue:** MonoToggle accepted Space and main Return but ignored keypad Enter (`Qt.Key_Enter`). The other reusable buttons already accepted both Return and Enter. This made keyboard activation inconsistent for an existing control.

**Reproduction:** after stabilizing the test fixture, **25/26** interaction assertions passed; `toggle keypad Enter activation` failed. Pointer, Tab/Shift+Tab, main Return and slider cases passed.

**Fix:** append `Qt.Key_Enter` to the existing MonoToggle activation condition. No new keybinding, service, visual state or handler was introduced.

**Evidence:** the targeted fixture then passed **26/26**, including exactly one keypad-Enter toggle and all prior controls. Final full regression also passed.

An initial hover check ran before the injected Row was polished; another temporary run could not locate its mapped overlay. Those rejected runs were not treated as production failures. After layout settlement and input isolation, hover passed and only the keypad-Enter case failed reproducibly. The final fixture waits for layout, uses a physical-input passthrough mask and disables compositor-exclusive keyboard focus; synthetic events are delivered directly to that test window. This distinction prevents interference with normal desktop input and does not claim physical/compositor-level verification.

## 5. Motion and reduced motion

No animation timing/style change was justified. Existing state-driven durations remain: hover 140 ms, press/release 100 ms, toggle 180 ms, overlay opening 190 ms and closing 140 ms. Dock's existing 190 ms reveal was retained. Opacity/translation/scale are used for panel/dock motion; local slider fill/thumb and launcher highlight movement remain bounded. No new runtime timer, shader, polling loop or hover-created object was added.

The 26-case fixture verifies that reduced motion applies immediately without reload, press feedback remains usable without compression, and the preference persists as valid JSON in the isolated test config. Eight rapid close/reopen transitions retain the latest overlay state, and final reduced-motion dismissal releases the surface immediately. No user setting was changed by these checks.

No reliable end-to-end 144 Hz frame-time mechanism was used, so no FPS/GPU performance is claimed. Physical motion quality remains a user check.

## 6. Files changed in Task 2

- `components/ui/MonoToggle.qml`: one activation-condition correction (only runtime-code change).
- `selftest-interactions.qml`: 26 targeted checks using real reusable controls inside the existing overlay and safe mock actions/backends.
- `tests/run-qml.py`: include that test in existing Wayland/private-config selection and shortcut fixtures.
- `tests/validate.sh`: run the new test with the existing suite.
- `docs/PHASE4-TASK2-REPORT.md`, `docs/phase4-task2-evidence/`: report, raw measurements/logs and a task-only diff.

No audio architecture, glass styling, shortcut registry, Niri blur settings, bindings, lock/PAM behavior, or other project was modified. Existing user settings and Niri configuration files match checkpoint bytes exactly. No dependency installation, Git reset, commit or push was performed.

## 7. Test results

| Check | Baseline | Final |
|---|---|---|
| `tests/niri-ipc-test.sh` | 16/16 | 16/16 |
| Core config/state/monitor checks | 14/14 | 14/14 |
| Actual Qt wallpaper fallback | 2/2 | 2/2 |
| Existing Phase 4 checks | 10/10 | 10/10 |
| Task 1 overlay regressions | 6/6 | 6/6 |
| Task 2 input/focus/motion regression | Not present; settled pre-fix probe 25/26 | 26/26 |
| **Integrated assertion total** | **48/48** | **74/74** |

`tests/validate.sh` also passed the available QML component-loading checks, actual shell startup and three isolated reloads, desktop/JSON/shell validation and generated appearance KDL validation. ShellCheck, `git diff --check` and `niri validate` passed. No unexpected runtime QML errors or binding loops were found in the successful run. Deliberate malformed-input and known upstream property-cache/private-portal warnings are distinguished from failures. The baseline and final runs also contain the same pre-existing Swappy desktop-entry Exec escaping warning; that external launcher entry is outside Task 2 and was not modified.

`qmllint` is unavailable and was not reported as executed. The failed temporary dock introspection probe is retained as a clearly marked limitation, not included in passing assertion counts.

## 8. CPU/RAM measurements

Same live QS PID 12157. CPU is one-core-normalized ticks from `/proc`, sampled with monotonic elapsed time; RSS uses resident pages. No editing was performed during the samples.

| Metric | Historical Task 1 reference | Before Task 2 (30.0 s) | Final (60.0 s) |
|---|---|---|---|
| Mean idle CPU | approximately 0.067% | 0.100% | 0.200% |
| Idle RSS start → end | approximately 215–221 MiB | 226.30 → 226.30 MiB | 209.19 → 209.00 MiB |
| Persistent child processes at end | 1 | 1 | 1 |
| Open descriptors at end | 64 in final historical sample | 64 | 66 |

No optimization result is claimed from finite samples across reload/cache history. The keypad correction adds no continuing work. These samples do not establish absence of all long-term memory leaks. Raw results are in `phase4-task2-evidence/`.

## 9. Remaining physical checks

- Real pointer traversal from the bottom-edge strip into the dock and across its children; verify no flicker and correct delayed hide.
- Physical mouse drag/wheel and keyboard use on actual audio/brightness controls; synthetic tests intentionally use mock backends.
- Full Settings/sidebar Tab flow and broader launcher navigation on the user's applications.
- Subjective press/release, rapid dismissal and smoothness at configured 144 Hz; no end-to-end frame-time result is claimed.
- Focus restoration under other applications/monitor layouts and physical input racing with overlay dismissal.

## 10. Final state

The existing shell remains operational and Niri configuration validates. Task 1's input shield/tests are preserved. All integrated assertions pass, and no incomplete feature or persistent test helper is enabled. Task 2 stops here; no Task 3 work was begun.
