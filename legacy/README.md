# legacy/

`root-duplicates/` holds an earlier, parallel implementation (flat files that lived next to
`shell.qml`: BottomBar, Dock, Launcher, PowerMenu, NiriService, Theme, Icons, Wallpaper*).
They were never referenced by `shell.qml` (which imports `qs.components` / `qs.services`) and
used a different Theme API. Kept for reference only; nothing imports this directory.
`smoke.qml` was the original API feasibility test.
