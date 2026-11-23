"""Update the initial blocked-session report with verified deployment evidence."""
from pathlib import Path
import json
import re

e = Path(__file__).resolve().parent
report = e.parent/'PHASE4-FINAL-REPORT.md'
s = (e/'initial-review-report.md').read_text()
def section(letter, next_letter, body):
    global s
    start = s.index('## '+letter+'. ')
    end = s.index('## '+next_letter+'. ', start)
    s = s[:start]+body.rstrip()+'\n\n'+s[end:]

section('A','B', '''## A. Executive result

**READY WITH MANUAL VERIFICATION REQUIRED.**

Both reproducible Settings defects are corrected in the authoritative project. The complete deployed-source regression passes **207/207**, including native activated-window focus. The separate real PipeWire integration passes **24/24**. No existing assertion or warning check was weakened.

The user explicitly confirmed that normal unlocking with the real password succeeded. IPC then independently showed `locked:false`. A fresh full checkpoint and source/concurrency check preceded applying the four-file task-only patch. Automatic QML reload recovered, and a later supported live reload was performed only while unlocked. This task did not perform authentication, submit credentials, force a lock or change the active lock preference.

The initial locked-session review and its 206/207 private result are retained in `phase4-task6-evidence/initial-review-report.md`. They explain why deployment was deferred earlier; they are superseded by the successful deployment and full 207/207 run described here. The applied patch is `phase4-task6-evidence/task6.patch`; the `pending/` directory is the retained pre-deployment bundle, not unfinished work.

Basic real-password unlocking is now **user-verified**, not inferred from QML loading. Physical input/display checks and security failure/crash/recovery cases remain manual limitations. No Phase 5 work or remote publication was performed.''')
s = s.replace('Checkpoint: `/home/jorj/.config/niri-monochrome-phase4-task6-backups/20261113-005808`.',
    'Original checkpoint: `/home/jorj/.config/niri-monochrome-phase4-task6-backups/20261113-005808`.\n\nFresh checkpoint immediately before deployment: `'+json.loads((e/'preapply-checkpoint.json').read_text())['path']+'`. It also preserves the newer settings/state and complete Git metadata before the patch.')
s = s.replace('Repeated source-hash comparisons found **no preexisting project file changed after the checkpoint**.',
    'Before deployment, repeated source-hash comparisons found no independent source changes since the original checkpoint. After deployment, only the three intended preexisting source/test files differ, plus the new Settings test and this task\'s documentation/evidence.')
s = s.replace('Real settings, Niri files and persistent shell state compared byte-for-byte equal to their checkpoint copies at the preservation check. This task changed only its new report/evidence in the authoritative project.',
    'Real settings, Niri files and persistent shell state matched the original checkpoint during the initial review. Current settings/Niri preservation is checked against the fresh pre-deployment checkpoint; normal shell state updates are preserved. The applied runtime/test scope is exactly the four files listed below, plus Task 6 report/evidence.')
s = s.replace('## C. Settings investigation and prepared correction','## C. Settings investigation and applied correction')
s = s.replace('The prepared fix changes','The applied fix changes').replace('The prepared fix delegates','The applied fix delegates')
s = s.replace('Prepared files:','Files changed:').replace('unchanged by the prepared patch.','unchanged by the applied patch.')
s = s.replace('pass in the final private suite.','pass in the deployed-source suite.')
s = s.replace('Actual native window activation is unavailable under the real session lock; focus restoration to a real application was not newly certified.',
    'The deployed native focus test passes 1/1 with an active window and focused search. Four live cycles per UI group return to the same application focus ID (75 → 75). This does not replace physical input/multi-monitor testing.')
section('E','F', '''## E. Actual regression results

| Suite/run | Result |
|---|---|
| Initial locked-session baseline | 180/183; validator exit 1. Raw failures retained. |
| Initial corrected private copy while locked | 206/207; native activation remained unavailable. |
| Final deployed `tests/niri-ipc-test.sh` | **16/16**, exit 0. |
| Final deployed `tests/validate.sh` | **191/191**, exit 0; combined **207/207**. |
| New Settings regression + fresh-process restore | **24/24**, included in 207. |
| Separate real PipeWire integration | **24/24**, exit 0; separate from 207. Audio sources are unchanged by deployment. |
| Component/entrypoint loading | Pass, including actual shell entrypoint, three isolated supported reloads and generated native KDL validation. |
| Final static checks | ShellCheck, Python AST, shell syntax, JSON/desktop validation, `niri validate`, `git diff --check` and task-only reverse-patch check pass. |

The actual total is **183 + 24 = 207 assertions**, including fresh-process precondition/restoration checks. Repeated diagnostic/benchmark/lifecycle runs are not added to this total.

The initial baseline had two small-viewport assertion failures and native activation/focus failure. The unchanged viewport assertions passed in the next complete private run. The final complete deployed run passes all 30 UI, six geometry and one native focus assertions. Earlier failures remain recorded; no viewport or focus implementation/test assertion was changed to obtain this result. The unlocked native observation is `windowActive:true`, `inputFocus:true`, `inputActive:true`, `waitTicks:0`.

Known upstream property-cache warnings, missing portals on private buses, intentional malformed-JSON/image-fallback diagnostics and the preexisting Swappy desktop-entry escape warning are distinguished from defects. No warning filter was added. Corrected Settings and benchmark logs have no binding loops or QML exceptions. Fresh live logs are inspected after the lifecycle check. `qmllint`, perf and pidstat remain unavailable and were not installed or claimed as run.''')
s = s.replace('Current locked session, five minutes','Initial locked session, five minutes').replace('Current locked session, final repeat','Initial locked session, repeat')
s = s.replace('These current live samples are **locked-session measurements**','These initial live samples are **locked-session measurements**')
s = s.replace('A later standalone memory snapshot reports','The initial review\'s later standalone memory snapshot reports')
s = s.replace('The active locked shell was not subjected to UI/reload workloads. Instead,','During the initial locked pass, the real shell was not subjected to UI/reload workloads. Instead,')
s = s.replace('The historical ~7.993% post-cycle transient was not reproduced as sustained recovery activity in this private run.',
    'The historical ~7.993% post-cycle transient was not reproduced as sustained recovery activity in the private or unlocked live run. The real shell\'s first closed recovery interval after all 28 live open/close cycles measures about 0.066% CPU.')
live_intro = '''### Deployment follow-up: real unlocked shell

The 30 s pre-application sample measures 0.000% sampled CPU ticks, RSS 222.31 → 222.31 MiB, FDs 69 → 69 and one child. Zero sampled ticks is a finite-resolution observation, not a claim of permanently zero CPU.

After deployment, the real shell completes four cycles each of launcher, Dock Settings, Control Center, Notification Center, shortcuts, dock and Media: **28 open/close cycles**. No playback or application is launched by the workload. Focus returns 75 → 75 for every group. Config bytes are checked unchanged, closed-state capture/brightness watchers are zero, and the supported reload runs only while unlocked.

@LIVE_TABLE@

@QUIET_RESULT@

The old private/locked observations below are retained for context. Their process/backend/working-set differences prevent direct idle or memory comparisons with this live deployment. No drop across reload is claimed as a leak fix or optimization result.

'''
s = s.replace('| Live/reference sample |',live_intro+'| Live/reference sample |',1)
s = s.replace('no real-password authentication success has been established by the user in this task.',
    'the user has now confirmed successful normal real-password unlocking. IPC independently showed unlocked before deployment.')
s = s.replace('Shell-lock crash/recovery, PAM success/failure and the recovery command suggested in the independent changelog have not been validated here.',
    'PAM normal success is user-confirmed. Failed-authentication behavior, shell-lock crash/recovery and the recovery command suggested in the independent changelog have not been validated here.')
s = s.replace('The secure active lock was left intact. **Unverified authentication and fallback/recovery coverage prevent unconditional release readiness.**',
    'The initially secure lock was left intact until the user unlocked normally; later reloads were guarded by the unlocked state. **Basic unlocking is user-verified; failure/crash and fallback/recovery coverage still require manual verification before unconditional release approval.**')
section('H','I', '''## H. Remaining safe manual verification

1. Physically traverse the dock edge/gaps; exercise hover, interior buttons, click-outside and Escape. Check Tab/Shift+Tab, Space, Return/keypad Enter, slider dragging/arrows/wheel, favorite selection/clearing and persistence. Automated component events and live IPC cycles passed; physical input is not certified by those results.
2. Inspect text/focus contrast over actual bright/dark wallpapers with glass on/off and reduced motion on/off. Judge 144 Hz smoothness directly; no frame-time/FPS certification was made. Exercise physical multi-monitor placement/hotplug only if another display is available; only eDP-1 was observed.
3. Check cheat-sheet search/navigation/categories and saved-source refresh. It remains informational; arbitrary external include layouts require independent native verification.
4. During normal real playback, verify amplitude, pause/stop/stale expiry, close-to-stop capture and normal physical output-device changes. Automated virtual-sink tests do not certify every physical device.
5. Basic real-password unlocking has already been confirmed by the user; no repeat is needed solely for this audit. Before any future failed-authentication/crash/recovery experiment, save work and establish a previously tested recovery path, including accessible alternate TTY login. Only the user should perform authentication checks, without sending credentials. An installed swaylock binary or an untested changelog command is insufficient evidence of recovery; defer such experiments if recovery is not established.''')
s = s.replace('The real QS has its original one `nmcli monitor` child (PID 197630).',
    'The real QS retains one `nmcli monitor` child; supported reloads replace its PID. Final child PID(s): @FINAL_CHILD@.')
s = s.replace('Temporary Task 6 working copies are removed after preserving the patch, all four pending files and raw evidence.',
    'Temporary Task 6 working copies are removed after preserving the applied patch, all four source snapshots and raw evidence. No test service is intentionally left running.')
s = s.replace('There is no deployed Task 6 runtime correction to roll back. Removing this task\'s newly added report/evidence would undo its authoritative-project additions; it would not affect prior work. If the prepared patch is subsequently applied, rollback scope is **only**',
    'Rollback scope for the deployed correction is **only**')
s = s.replace('The observed real session remains locked/secure; real authentication remains unverified.',
    'Final observed lock state: @FINAL_LOCK_STATE@. Normal real-password authentication is user-confirmed; security failure/recovery cases remain unverified.')
s = s.replace('Previous feature source is preserved, private correction/regression evidence is complete, and no new persistent helper or unexpected corrected-path QML exception was observed. **The Settings correction and unlocked native/live validation remain pending.**',
    'Previous feature source and independent lock work are preserved. Both Settings corrections are applied and the full 207/207 deployed regression passes. The live lifecycle/resource outcome and remaining manual limits are stated above. No new persistent helper or unexpected corrected-path QML exception was observed.')
(e/'final-report-template.md').write_text(s)
print('Prepared updated report template; live metrics will be inserted after sampling.')
