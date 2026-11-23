# Phase 4 — Premium UI and interaction verification

Date: 2026-11-12 (Europe/Bucharest). Target: the existing Niri 26.04 / Quickshell 0.2.1 desktop.

## Feature status

| Feature | Status | Evidence / limit |
|---|---|---|
| Micro-interactions | IMPLEMENTED — MANUAL VERIFICATION REQUIRED | Shared motion gate, button compression/focus, keyboard toggles/sliders, preserved slider backend bindings, dock/popup reveal and dismissal, moving launcher selection. Automated loads/state checks pass; physical pointer/key testing remains manual. |
| Monochrome glass | IMPLEMENTED — MANUAL VERIFICATION REQUIRED | Translucent grayscale Panel base, thin highlight/border, bounded native Niri blur and soft shadows on bar/dock only. Actual cheat sheet screenshot inspected. No desktop capture or full-screen blur shader is used. |
| Real audio visualizer | COMPLETE AND TESTED | Genuine sink-monitor PCM amplitude history/meter, not frequency bands. A virtual PipeWire output with a 440 Hz PCM stimulus produced 57 frames with peak normalized amplitude 0.6783. Live media lifecycle and reload cleanup passed. |
| Shortcut cheat sheet | IMPLEMENTED — MANUAL VERIFICATION REQUIRED | Search, categories, keycaps, Up/Down navigation, Tab focus, close/Escape wiring and existing click-outside system. Parser/filter/conflict assertions pass; real typing/click-outside checks remain manual. |

## Implementation

- `config/Theme.qml`: central motion durations/gating, glass surface and panel radius; Inter preferred, JetBrains Mono retained. `appearance.reduceMotion` or animations off sets motion duration/intensity to zero.
- `config/UserConfig.qml`: merges and validates `glassEnabled`, panel opacity (0.82–1), panel radius (0–24), shadow strength (0–0.65), animation intensity (0–1.5), reduced motion; visualizer enable/style and bar count (16–32).
- Existing `MonoButton`, `IconButton`, `MonoToggle`, `MonoSlider`, `MonoTextField`, `Panel`: consistent states, keyboard focus feedback, press compression, smooth track/thumb/value transitions. Slider interaction emits the requested value without overwriting the live backend binding. No animation is applied during dragging.
- `OverlayLayer`, `AutoHideDock`, `Launcher`: lightweight opacity/translation, retained content only during dismissal, moving launcher selection and corrected dock trigger hover cleanup. Overlay input is released immediately when closing. Existing bar geometry and shortcuts are preserved.
- `AppearanceService`: generates `~/.config/niri/niri-monochrome-appearance.kdl`, writes only when content changes, and uses documented Niri 26.04 layer rules for namespaces `nm-bar` and `nm-dock`. The main Niri config includes this file. Other popovers use translucent surfaces without compositor blur, because their layer surface spans the screen and Quickshell's installed API does not expose shaped background-effect regions. `MultiEffect` is not treated as desktop-background blur.
- `ShortcutService`, `ShortcutCheatSheet`: read actual `binds.kdl` and the generated shell include, watch file changes, normalize Mod/Super for duplicate resolution, keep later effective bindings, and filter locally. This intentionally covers the standard one-line bindings in these two files, not arbitrary KDL or every external include. Rows are informational and never run destructive commands.
- `VisualizerService`, `AudioVisualizer`, `scripts/audio-levels.py`: use existing `pw-cat` and Python's standard library. Capture explicitly targets the current Audio/Sink with `stream.capture.sink=true`; there is no microphone or automatic input fallback. 533 signed 16-bit mono samples at 16 kHz yield approximately 30 updates/s. Normalized RMS/dB values feed bounded history with attack/release smoothing. History and level-meter styles are honest amplitude views, not an FFT.
- A single owned helper starts only while Media's visualizer is visible/enabled. Normal stop vs failure is distinguished; retries are bounded. Python terminates/reaps pw-cat, with Linux parent-death signals as crash protection. No audio samples are saved. Silence with a suspended sink is displayed as waiting, without fake motion.
- `Settings` and Control Center provide visible access to Keyboard Shortcuts. No new global binding was assigned: `Mod+Shift+Slash` already opens Niri's native hotkey overlay. IPC: `qs -c niri-monochrome ipc call shortcuts toggle`.

## Test results

- Existing Niri IPC: **16/16**.
- Existing configuration/state/monitor cases: **14/14**.
- Actual Qt image decoder fallback: **2/2**.
- New Phase 4 state/config/search/lifecycle checks: **10/10**.
- All component loads, actual shell entrypoint and three isolated reloads passed. Generated appearance KDL and current full Niri configuration passed `niri validate`. ShellCheck and whitespace checks passed.
- Live final integration: **20 panel cycles**, including **5 audio open/close cycles**, at most one capture helper; zero after close. Reload with a capture running also left zero capture helpers. A transient non-JSON IPC reply during reload is handled with bounded readiness retries.
- Initial checks caught an invalid readonly-property Behavior assignment and a normal-stop/reopen lifecycle race; both were fixed and rechecked. One temporary test counter and reload-readiness assumption were corrected rather than counting incomplete runs as passes.
- The real PipeWire data test used a temporary virtual sink, without sound in speakers or changing the default output. Sink and capture/playback processes were removed afterwards. A PipeWire graph warning occurred during that temporary sink removal; live audio readiness was confirmed after reload.
- `qmllint` remains unavailable. Physical pointer/key behavior and actual 144 Hz frame-time smoothness were not benchmarked; no FPS claim is made.

## Performance

Same live Quickshell PID 12157, 1 s `/proc` samples. Raw measurements and successful logs are in `phase4-evidence/`.

| Metric | Before | After |
|---|---|---|
| Idle CPU | 0.067% over 30.0 s | 0.067% over 30.0 s |
| Idle RSS | 223.23 → 223.23 MiB | 226.70 → 221.34 MiB |
| Persistent child processes | 1 | 1 (`nmcli monitor`) |
| End-of-idle open descriptors | 64 | 65 |
| CPU during rapid UI test | NOT MEASURED | 25.19% (active scripted animations, not idle) |
| Capture processes while hidden | 0 before feature | 0 after close and reload |

RSS after successive final interaction cycles (KiB): [229564, 229512, 229768, 225628, 227584]. These finite samples show no continuous growth in the tested sequence; they are not proof against all long-term leaks. Idle activity is essentially unchanged. The lower ending RSS is not claimed as an optimization result: cache settling and reload history affect RSS. The compositor/GPU cost of blur was not separately profiled.

## Manual verification

1. Settings → Appearance: toggle Reduced motion and Glass; adjust opacity and radius. Verify clear immediate states with reduced motion, readable text over bright/dark content, and bounded bar/dock blur.
2. Open launcher/dock/Control Center; test hover traversal, press/release, slider dragging/arrows, switch Space key, Escape and click-outside. Existing keybindings should behave as before.
3. Settings → Shortcuts → Open cheat sheet (or the keyboard button in Control Center). Search action/key/category, change categories, navigate Up/Down and Tab; verify no destructive action is executed by Enter on a row.
4. Open Media while actual audio plays: history should move; pause to check calm silence, then close Media and verify capture disappears. Switch output devices to exercise reconnection. Both styles and bar-count settings are connected.

## Final state and recovery

No package dependency was added. Mako, tray ownership, swaylock/PAM behavior, wallpaper files and networking configuration are retained. Existing user config.json is byte-identical to the pre-change backup; new preferences are merged defaults until saved through Settings. Niri's main config gains only the appearance include. No other project's files were modified.

Backup: `~/.config/niri-monochrome-phase4-backups/20261112-160633/` contains the full pre-change project, Niri config and settings. To roll back, preserve any later edits and restore the affected project and Niri files together from that checkpoint. No automatic rollback or destructive Git command was used. Work is saved locally; this phase did not publish a new remote commit.
