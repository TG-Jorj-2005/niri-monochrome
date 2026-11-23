import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components.ui

// Auto-hide dock above the bottom bar. Shown by hovering the screen's bottom edge
// or by the keyboard shortcut (then navigable with ←/→, Enter, Esc).
Scope {
    id: dock
    required property var modelData
    readonly property string screenName: modelData.name
    readonly property string monitorKey: MonitorService.keyFor(modelData)
    readonly property var profile: MonitorProfiles.profile(monitorKey)
    readonly property var cfg: profile.dock
    readonly property var barCfg: profile.bar
    readonly property bool keyboardMode: ShellState.dockKeyboard && ShellState.dockScreen === screenName
    property bool hoverShown: false
    readonly property bool shown: cfg.enabled && (keyboardMode || (cfg.autoHide ? hoverShown : true)) && ShellState.open === ""
    property int selected: 0

    // Favorites whose desktop entry is missing are hidden here (Settings → Dock lists them as "not installed").
    readonly property var favorites: cfg.favorites.map(id => ({ id: id, entry: ApplicationService.byId(id) })).filter(f => f.entry !== null)
    readonly property var running: cfg.showRunning ? NiriService.windowList.map(w => ({ win: w, entry: ApplicationService.forAppId(w.app_id) })) : []
    // Running apps not among favorites are appended.
    readonly property var extra: {
        const seen = {}
        for (const f of favorites) if (f.entry) seen[f.entry.id] = true
        const out = []; const ids = {}
        for (const r of running) {
            const key = r.entry ? r.entry.id : r.win.app_id
            if (r.entry && seen[r.entry.id]) continue
            if (ids[key]) continue
            ids[key] = true
            out.push({ id: key, entry: r.entry, appId: r.win.app_id })
        }
        return out
    }
    readonly property var items: favorites.concat(extra)
    function windowsFor(item) {
        return running.filter(r => (item.entry && r.entry && r.entry.id === item.entry.id) || (!item.entry && r.win.app_id === item.appId))
    }
    onItemsChanged: selected = Math.max(0, Math.min(selected, items.length - 1))
    function activate(item) {
        if (!item) return
        const wins = windowsFor(item)
        const focused = wins.find(w => w.win.is_focused)
        if (wins.length > 0 && !focused) NiriService.focusWindow(wins[0].win.id)
        else if (wins.length > 1 && focused) { const i = wins.indexOf(focused); NiriService.focusWindow(wins[(i + 1) % wins.length].win.id) }
        else if (item.entry) ApplicationService.launch(item.entry)
        if (keyboardMode) ShellState.hideDock()
    }

    Timer { id: hideTimer; interval: dock.cfg.hideDelay; onTriggered: if (!trigger.hovered && !body.hovered) dock.hoverShown = false }
    function scheduleHide() { hideTimer.restart() }

    // ---- Edge trigger strip (full width, a few px tall, click-through otherwise) ----
    PanelWindow {
        id: trigger
        property bool hovered: false
        onVisibleChanged: if (!visible) { hovered = false; dock.scheduleHide() }
        screen: dock.modelData
        visible: dock.cfg.enabled && dock.cfg.autoHide && !dock.shown
        anchors { bottom: true; left: true; right: true }
        implicitHeight: dock.cfg.triggerHeight
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: Constants.nsTrigger
        WlrLayershell.layer: WlrLayer.Overlay
        MouseArea { anchors.fill: parent; hoverEnabled: true; onEntered: { trigger.hovered = true; dock.hoverShown = true } onExited: { trigger.hovered = false; dock.scheduleHide() } }
    }

    // ---- Dock window ----
    PanelWindow {
        id: win
        screen: dock.modelData
        property real reveal: dock.shown ? 1 : 0
        Behavior on reveal { NumberAnimation { duration: Theme.durNormal; easing.type: Theme.easing } }
        visible: dock.shown || reveal > 0.001
        anchors.bottom: true
        margins.bottom: (dock.barCfg.enabled ? dock.barCfg.marginBottom + dock.barCfg.height : 12) + 10
        implicitWidth: body.width + 2
        implicitHeight: body.height + 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: Constants.nsDock
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: dock.keyboardMode && dock.shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { dock.selected = 0; body.forceActiveFocus() }

        Panel {
            id: body
            property alias hovered: hh.hovered
            width: row.implicitWidth + 20
            height: dock.cfg.iconSize + 28
            x: 1; y: 1
            border.color: Theme.silverMuted
            focus: true
            Keys.onLeftPressed: dock.selected = (dock.selected + dock.items.length - 1) % Math.max(1, dock.items.length)
            Keys.onRightPressed: dock.selected = (dock.selected + 1) % Math.max(1, dock.items.length)
            Keys.onTabPressed: dock.selected = (dock.selected + 1) % Math.max(1, dock.items.length)
            Keys.onReturnPressed: if (dock.items.length) dock.activate(dock.items[dock.selected])
            Keys.onEnterPressed: if (dock.items.length) dock.activate(dock.items[dock.selected])
            Keys.onEscapePressed: { ShellState.hideDock(); dock.hoverShown = false }
            Keys.onPressed: e => { const n = parseInt(e.text); if (n >= 1 && n <= dock.items.length) { dock.activate(dock.items[n - 1]); e.accepted = true } }
            HoverHandler { id: hh; onHoveredChanged: { if (!hovered) dock.scheduleHide(); else hideTimer.stop() } }
            // entrance: slide + fade
            opacity: win.reveal; transform: Translate { y: 8 * Theme.motionIntensity * (1-win.reveal) }


            Row {
                id: row
                anchors.centerIn: parent
                spacing: 6
                Repeater {
                    model: dock.items
                    delegate: Rectangle {
                        id: cell
                        required property var modelData
                        required property int index
                        readonly property var wins: dock.windowsFor(modelData)
                        readonly property bool isRunning: wins.length > 0
                        readonly property bool isActive: wins.some(w => w.win.is_focused)
                        readonly property bool sel: dock.keyboardMode && dock.selected === index
                        width: dock.cfg.iconSize + 16; height: dock.cfg.iconSize + 16
                        radius: Theme.radiusControl
                        color: sel || cma.containsMouse ? Theme.accentSubtle : isActive ? Theme.elevated : "transparent"
                        border.width: sel || isActive ? 1 : 0; border.color: Theme.accent
                        Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.durFast } }
                        scale: cma.containsMouse ? 1.06 : 1.0
                        Behavior on scale { enabled: Theme.motionEnabled; NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } }
                        AppIcon { anchors.centerIn: parent; size: dock.cfg.iconSize; icon: cell.modelData.entry ? cell.modelData.entry.icon : ""; fallbackGlyph: "app"
                            dim: cell.modelData.entry ? 1 : 0.7 }
                        // running indicator: 1 dot per window (max 3)
                        Row { anchors.bottom: parent.bottom; anchors.bottomMargin: 3; anchors.horizontalCenter: parent.horizontalCenter; spacing: 3
                            Repeater { model: Math.min(3, cell.wins.length)
                                delegate: Rectangle { width: cell.isActive ? 10 : 4; height: 2; radius: 1; color: cell.sel || cell.isActive ? Theme.accent : Theme.silverMuted } } }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: mouse => { if (mouse.button === Qt.MiddleButton && cell.modelData.entry) ApplicationService.launch(cell.modelData.entry); else dock.activate(cell.modelData) } }
                        // tooltip
                        Rectangle { visible: cma.containsMouse || cell.sel; anchors.bottom: parent.top; anchors.bottomMargin: 8; anchors.horizontalCenter: parent.horizontalCenter
                            width: tip.implicitWidth + 14; height: 22; radius: 3; color: Theme.elevated; border.width: 1; border.color: Theme.border
                            Label { id: tip; anchors.centerIn: parent; font.pixelSize: Theme.fontXs; text: cell.modelData.entry ? cell.modelData.entry.name : (cell.modelData.appId || cell.modelData.id) } }
                    }
                }
                Label { visible: dock.items.length === 0; text: "No favorites — add apps in Settings → Dock"; secondary: true; font.pixelSize: Theme.fontSm; padding: 10 }
            }
        }
    }
}
