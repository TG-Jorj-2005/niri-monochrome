# Phase 4 — Task 5/6: shortcut registry and cheat sheet

Date: 2026-11-13, Europe/Bucharest. Task began before midnight on 2026-11-12. Authoritative project: `~/.config/quickshell/niri-monochrome`.

## A. Result

Task 5 is complete within the documented source coverage and available UI verification. The final complete regression passed **183/183 named checks**, preserving the original 116. The actual current registry audit found 136 unique entries. Known independent Settings warnings and physical/compositor limits remain documented below. No Task 6 implementation was started by this agent.

Checkpoint: `/home/jorj/.config/niri-monochrome-phase4-task5-backups/20261112-235737` (complete project including Git metadata, Niri directory, user settings and initial Git status). Existing uncommitted work was retained. No parallel agent was present in this thread; independently arriving lock-related changes were detected later and preserved, as detailed in K. No Git reset/clean/commit/push was performed. The old `~/niri-monochrome` project was untouched.

## B. Source accuracy and boundaries

The read-only audit of the actual current files produced **136 entries / 136 unique canonical keys**. `Mod+Comma` correctly shows the generated Settings action rather than the earlier native column action. Final groups: Applications 6, Media 10, NIRI MONOCHROME 6, Navigation 32, Screenshots 4, System 9, Windows 34, Workspaces 35. Mod maps to Super in the current native session.

The registry now reads direct `binds` blocks in **config.kdl**, and the known direct **binds.kdl / niri-monochrome.kdl** includes in their main-file order. It also reads direct **input.kdl / main input.mod-key** for modifier normalization. It recognizes the project's literal relative names, `./` prefix and direct absolute paths under the config directory. It does not traverse arbitrary recursive includes, resolve symlinks/home/other path aliases, or compute complete XKB/layout symbol equivalence. Nested-winit modifier defaults and modifiers set through unresolved includes are outside verified coverage.

The footer explicitly calls this a saved **source view, not a live compositor snapshot**. Installed `niri msg --help` exposes no binding snapshot command. Niri may retain its last accepted configuration after an invalid edit; the sheet cannot reconstruct that state solely from saved files. Unknown action text is retained literally and never executed; the reader is not a Niri action-enum or XKB validator. Pango title formatting is displayed as plain text. Full current config validity was checked separately with Niri.

The old line regex was replaced by a bounded structural KDL reader local to this registry. It handles node boundaries, quoted/escaped/raw strings, multiline actions, comments including nested block comments, slash-dash disabled nodes and balanced children. It refuses structurally broken sources, sources above 1 MiB or nesting beyond 64; this is a documented subset, not a replacement global configuration framework. Native 26.04 fixtures verify the supported syntax.

Modifier aliases Control/Ctrl, Win/Super and Mod5/ISO_Level3_Shift normalize correctly; only modifier tokens are rewritten, preserving trigger names such as Mode_switch. Multiple keys for one action remain distinct. Later supported sources override conflicting canonical keys. Disabled nodes do not contribute. `hotkey-overlay-title=null` hides an informational row and its override remains a tombstone through merging; it does **not** unbind the actual action. Same-block duplicates and duplicate binds nodes fail closed, matching native validation, instead of pretending an invalid file is a valid override.

The installed Niri include/key-binding documentation was consulted, including positional includes, and native `niri validate` fixtures were used as the oracle. [Official modifier/binding reference](https://github.com/niri-wm/niri/wiki/Configuration:-Key-Bindings); local installed include reference: `/usr/share/doc/niri/wiki/Configuration:-Include.md`.

## C. Search and filtering

Filtering remains local and case-insensitive across key, label, category and raw description. Literal special characters such as `[work]` and `.*` are not interpreted as regular expressions. Empty results, category changes, updated sources and multiple bindings for one action are tested. No subprocess is launched per keystroke; no query polling or unbounded search-result cache was added.

The synthetic 5,000-row benchmark executes 100 queries over actual service filtering. Final elapsed time: 944 ms total (approximately 9.44 ms/query); this is a bounded stress observation, not a physical input-latency or GPU benchmark.

## D. Keyboard and pointer

The genuine keyboard defect was the search TextInput missing `activeFocusOnTab`. One local property now makes Tab enter category controls and Shift+Tab return to search. Initial mapped search focus already passed before correction and was not falsely called a production defect. The native focus test now waits for compositor window activation before asserting the same focus/typed-character behavior.

Actual synthetic Qt events verified typing without focus theft, Up/Down selection, bounded empty navigation, literal search, category selection, Return/keypad Enter/Space safe activation, Escape, Close, interior padding and outside dismissal. Informational rows never execute configured commands. List wheel scrolling was checked after forcing pending ListView layout; no runtime wheel rewrite was necessary. Task 1's pointer shield and Task 2's keypad-Enter control correction are unchanged.

Settings → Shortcuts was exercised through the actual hidden Settings page's button signal, verifying that it closes Settings state and opens the sheet; this is a wiring test, not a physical click claim. The Control Center keyboard button was exercised by synthetic pointer events on the actual component. The live supported IPC command `qs -c niri-monochrome ipc call shortcuts toggle` was verified through 12 cycles, a supported Quickshell reload and reopening.

A separate ordinary live IPC open/close sample restored Niri focus **4 → 4**. The longer mixed-session/reload observation recorded **4 → 75**; it is not presented as proof of universal focus restoration. Physical input, multiple monitors and application transitions remain manual limits.

## E. Layout and accessibility

Confirmed old keycap overflow was reproduced: the original renderer passed only **3/6** checks, failing horizontal keycap containment at all three tested sizes. The correction uses wrapping keycaps with bounded widths, dynamic row heights, wrapped descriptions and a list height that reserves the measured footer. It retains the shared Theme and grayscale hierarchy, including Task 3's readable secondary text and existing focus outlines. No separate palette, blur or animation system was introduced.

Offscreen snapshots instantiate the real sheet at its normal 820×560 panel in an 860×600 scene, and within **640×480 / 384×480** windows. Corrected geometry/render checks pass **6/6**. Key labels do not truncate horizontally; rows taller than a small list viewport remain vertically scrollable, as expected for a clipped ListView. These are synthetic Qt renders, not compositor screenshots or a 144 Hz smoothness certification. The actual overlay was also exercised on the current screen; no monitor resolution was changed.

## F. Refresh, persistence and lifecycle

There are four owned reactive FileViews, no new polling timer and no capture/helper process. File removal/load failure now clears stale rows and exposes source status. Reopening requests a bounded refresh, allowing missing/recreated sources to recover without permanent polling. Tests cover atomic edits, deletion, recreation, generated updates, main include reordering, disabling a generated binding, and opening again.

Private Settings shortcut changes were written by the unchanged Keybindings generator and reflected by the sheet. A fresh QML process loaded the same private saved files and verified restored entries/no duplicates; the resulting private config passed native Niri validation. Actual shell startup and three isolated reloads also passed. A real supported reload with the sheet open completed and allowed reopening. Latest-state behavior was verified over eight reduced-motion rapid transitions, with event-loop settlement and one final sheet.

## G. Corrections and evidence

| Confirmed problem | Minimal correction / verification |
|---|---|
| Commented/disabled bindings shown; multiline or quoted-brace actions lost/misread | Structural registry reader. Initial targeted data probe was **5/13**, then **13/13** after correction; expanded coverage is in the final suite. |
| Valid modifier aliases dropped; substring Mod replacement damaged trigger names | Alias-aware token normalization; native alias fixtures and Mode_switch regression. |
| Hidden overrides could show/resurrect earlier rows; invalid duplicates misrepresented | Hidden tombstones resolved after merging; invalid same-block duplicates rejected according to native oracle. |
| Missing source retained old rows; fixed source order ignored actual main order/activation | Clear failed sources, retain visible scope/status, reactive known-source merge in main-file order. |
| Search absent from Tab traversal | Set only this search input's activeFocusOnTab; actual Tab/Shift+Tab checks pass. |
| Long key combinations overflowed fixed-width rows | Bounded wrapping keycaps and measured row/list/footer layout; old 3/6 → corrected 6/6 rendering checks. |
| Classification matched command arguments (e.g. file manager `--new-window`) rather than native action, and missed current niri-lock wrapper | Classify workspace/window/navigation by action name and recognize the current lock wrapper as System; targeted category case and current-source audit pass. No lock command/binding was changed. |

Runtime files: `services/ShortcutService.qml`, new `services/ShortcutParser.js`, `components/popovers/ShortcutCheatSheet.qml`.

Tests: `selftest-shortcut-data.qml`, `selftest-shortcut-ui.qml`, `selftest-shortcut-layout.qml`, `selftest-shortcut-focus.qml`, `selftest-shortcut-restore.qml`, `tests/shortcut-native-test.py`, registrations in `tests/run-qml.py` and `tests/validate.sh`. Report/evidence: `docs/PHASE4-TASK5-REPORT.md`, `docs/phase4-task5-evidence/`. The task-only patch isolates these changes from older and concurrent work.

## H. Tests and test limitations

| Named checks | Baseline | Final |
|---|---|---|
| Previous Phase 4 / Tasks 1–4 integrated checks | **116/116** | **116/116** |
| Task 5 parser, merge, category and filter cases | — | 23/23 |
| Actual overlay input/refresh/entry-point cases | — | 30/30 |
| Fresh-process registry restoration | — | 1/1 |
| Actual Qt rendering/geometry cases | — | 6/6 |
| Native activated-window initial focus | — | 1/1 |
| Installed Niri syntax/semantics oracle | — | 6/6 |
| **Integrated total** | **116/116** | **183/183** |

`tests/niri-ipc-test.sh` and `tests/validate.sh` exited 0 in the final complete run (`final4*.log`). QML component loading, actual shell startup + three isolated reloads, private configuration restore validation, JSON/desktop-entry/shell syntax, ShellCheck, Python AST checks, `niri validate` and `git diff --check` passed. All prior test assertions remain intact.

Earlier repeated runs are retained honestly: one unchanged original overlay test failed its fixed-time “panel loaded” precondition and timed out; its unchanged isolated rerun passed all six checks. Another early native-focus probe checked at a fixed instant before demonstrating window activation and failed. The new test now waits up to three seconds for actual native window activation, then asserts search focus and typed input without forcing them. The final complete run passed all 183. These earlier failures are not called successful tests or conclusively attributed to a production defect.

Rejected fixture assumptions were also corrected: anchored full-screen layer size was not a valid small-monitor simulation, so actual standard offscreen windows provide the rendering evidence; deferred ListView layout and zero-delay incubation cancellation were allowed to settle in test fixtures. A fresh-process observer now initializes the lazy registry before checking it, and a synthetic benchmark expected-count error was corrected. No old assertion was weakened, and no unrelated runtime rewrite was made to silence a test.

Known property-cache and unavailable private-portal warnings, and the pre-existing Swappy Exec escaping warning, were distinguished from regressions. No warning was suppressed in the existing runner. The separate Task 4 24/24 real PipeWire suite is historical and was not rerun in Task 5; its code and capture properties were not changed. Current deterministic audio checks remain included in the 116 preserved cases. `qmllint` is unavailable and was not reported as executed. No dependency was installed.

## I. Performance

Same live QS PID **12157**. CPU is process ticks divided by monotonic elapsed time, normalized to one core; RSS is resident pages in MiB. No source edits occurred during samples.

| Sample | Actual seconds | CPU | RSS MiB start → end | Descriptors | Persistent children |
|---|---|---|---|---|---|
| Before Task 5 | 30.022 | 0.100% | 207.80 → 207.80 | 64 → 64 | 1 |
| Final closed sheet after final warm open/close | 30.024 | 0.167% | 216.34 → 214.72 | 81 → 69 | 1 |

The 12-cycle live sample plus reload/reopen took 11.493 s, CPU **33.847%**, RSS **179.66 → 190.74 MiB**, FDs **64 → 72**. It includes cold component work and reload, and has no matched pre-change interaction baseline; it is not treated as an optimization/regression result. Child identity changed on reload, but count remained one (`nmcli monitor`).

The source reader has four fixed file observers and no runtime process or polling timer. Search reads cached source entries and filters locally. Repeated finite cycles and stable closed-state measurements show no persistent helper growth in the observed workload, but do not prove absence of all long-term leaks or quantify private Qt listener allocations. Lower RSS across reload history and independent concurrent lock work is not attributed to a Task 5 optimization. No GPU/frame-time improvement is claimed.

## J. Independent Settings warning — carry to Task 6

The baseline retained runtime tail contained **24 occurrences** of `Binding loop detected for property "model"` at `Settings.qml:141`; this bounded log count is not an event rate. A private invisible Settings Dock page reproduced **three occurrences from three search assignments**, without changing favorites or launching applications. The expected probe failed the strict QML warning check and is not counted among passing regression tests.

The Dock “Add application” search calls the stateful memoized `ApplicationService.search()`. Its cache writes during binding evaluation remain a candidate explanation, not a completed root-cause proof. No ApplicationService or Dock search fix was made. This finding is explicitly carried forward to Task 6. No causal claim connects it to Task 3's historical CPU/RAM transient. The final runtime tail had zero binding-loop occurrences after the supported reload; that does not resolve the reproducible Settings issue.

## K. Preservation and final state

The task-only patch lists the 11 implementation/test files in G; all protected previous-task files (audio helper/service/component, overlay shield, MonoToggle, Theme, UserConfig, Keybindings writer, appearance service and prior regression tests) match the checkpoint. No user shortcut, compositor, PAM, Mako or lock action was modified or invoked by Task 5. Niri PID 12079 and QS PID 12157 remained running; only supported Quickshell reloads were used.

Unrelated changes arrived during this task in **shell.qml, components/LockScreen.qml, components/Settings.qml, services/SystemService.qml and docs/CHANGELOG.md**, with new lock-related work outside the Task 5 patch. Their modification timestamps precede the final full verification. They were preserved rather than reverted or misrepresented as this task's work. The real user preference `security.useShellLock` changed during the session and remains at its current value; Task 5 writes configuration only in private test directories. Actual Niri/binding files match the hashes captured before final verification. The earlier whole-session checkpoint comparison therefore deliberately does not pretend all unrelated files/preferences stayed unchanged.

Final diagnostics report ready Niri/audio/network/Bluetooth/brightness, overlay closed, visualizer stopped with zero subscribers, and Mako retained. Only the normal nmcli monitor child remains. All test-generated native configuration edits were private. The independent Settings warning remains open for Task 6, without an unfinished Task 5 feature left active. Cleanup checks and raw evidence are stored beside this report.

Rollback must preserve concurrent work: use the Task 5 patch/affected files, not a blanket restoration of the entire initial checkpoint over later edits.

## L. Remaining physical checks

- Physical Tab/Shift+Tab, keypad Enter, wheel/trackpad and pointer dismissal in the real session, including click-release behavior over another application's controls.
- Focus restoration while another application/monitor or session state changes; synthetic events are not physical keyboard certification.
- High-DPI and additional monitor arrangements, very long vertically scrolling rows and subjective readability/144 Hz pacing.
- Advanced recursive includes, other path aliases, unsupported KDL forms and full XKB alias/layout resolution remain outside the stated registry coverage; use native Niri validation for compositor acceptance.

Task 5 stops here. This agent did not begin Task 6.
