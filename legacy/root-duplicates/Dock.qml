import QtQuick
import Quickshell
import Quickshell.Wayland

// Auto-hide dock. Shown by hovering bottom edge or Mod+A.
Scope {
    id: dock
    required property var modelData
    readonly property string screenName: modelData.name

    property bool keyboardMode: false
    property bool hoverShown: false
    readonly property bool shown: keyboardMode || hoverShown
    property int selected: 0

    // Favorites list — desktop entry IDs
    readonly property var favoriteIds: [
        "Alacritty.desktop",
        "org.gnome.Nautilus.desktop",
        "org.mozilla.firefox.desktop",
        "com.microsoft.VSCode.desktop",
        "org.gnome.TextEditor.desktop",
        "org.gnome.Settings.desktop"
    ]

    readonly property var favorites: favoriteIds.map(id => ({
        id: id,
        entry: DesktopEntries.byId(id) || DesktopEntries.byId(id.replace(/\.desktop$/, ""))
    }))

    // Running apps not in favorites
    readonly property var extra: {
        const seen = {}
        for (const f of favorites) if (f.entry) seen[f.entry.id] = true
        const out = []; const ids = {}
        for (const w of NiriService.windowList) {
            const entry = w.app_id ? (DesktopEntries.byId(w.app_id) || DesktopEntries.heuristicLookup(w.app_id)) : null
            const key = entry ? entry.id : w.app_id
            if (!key || ids[key] || (entry && seen[entry.id])) continue
            ids[key] = true
            out.push({ id: key, entry: entry, appId: w.app_id })
        }
        return out
    }

    readonly property var items: favorites.concat(extra)

    function windowsFor(item) {
        return NiriService.windowList.filter(w => {
            if (item.entry) {
                const e = w.app_id ? (DesktopEntries.byId(w.app_id) || DesktopEntries.heuristicLookup(w.app_id)) : null
                return e && e.id === item.entry.id
            }
            return w.app_id === item.appId
        })
    }

    function activate(item) {
        const wins = windowsFor(item)
        const focused = wins.find(w => w.is_focused)
        if (wins.length > 0 && !focused) NiriService.focusWindow(wins[0].id)
        else if (wins.length > 1 && focused) {
            const i = wins.indexOf(focused)
            NiriService.focusWindow(wins[(i + 1) % wins.length].id)
        } else if (item.entry) item.entry.execute()
        if (keyboardMode) keyboardMode = false
    }

    Timer { id: hideTimer; interval: 350; onTriggered: if (!trigger.hovered && !dockBody.hovered) dock.hoverShown = false }
    function scheduleHide() { hideTimer.restart() }

    // ---- Edge trigger (full width, 2px, invisible) ----
    PanelWindow {
        id: trigger
        property bool hovered: false
        screen: dock.modelData
        visible: !dock.shown
        anchors { bottom: true; left: true; right: true }
        implicitHeight: 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "nm-dock-trigger"
        WlrLayershell.layer: WlrLayer.Overlay
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: { trigger.hovered = true; dock.hoverShown = true }
            onExited: { trigger.hovered = false; dock.scheduleHide() }
        }
    }

    // ---- Dock window ----
    PanelWindow {
        id: dockWin
        property bool hovered: false
        screen: dock.modelData
        visible: dock.shown
        anchors.bottom: true
        margins.bottom: 78    // 14 (bar margin) + 54 (bar height) + 10 (gap)
        implicitWidth: dockBody.width + 2
        implicitHeight: dockBody.height + 2
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "nm-dock"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: dock.keyboardMode ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { dock.selected = 0; dockBody.forceActiveFocus() }

        Rectangle {
            id: dockBody
            property alias hovered: dockHover.hovered
            width: dockRow.implicitWidth + 20
            height: 68
            x: 1; y: 1
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.muted
            antialiasing: true
            focus: true

            Keys.onLeftPressed: dock.selected = (dock.selected + dock.items.length - 1) % Math.max(1, dock.items.length)
            Keys.onRightPressed: dock.selected = (dock.selected + 1) % Math.max(1, dock.items.length)
            Keys.onReturnPressed: if (dock.items.length) dock.activate(dock.items[dock.selected])
            Keys.onEnterPressed: if (dock.items.length) dock.activate(dock.items[dock.selected])
            Keys.onEscapePressed: dock.keyboardMode = false

            HoverHandler { id: dockHover; onHoveredChanged: { if (!hovered) dock.scheduleHide(); else hideTimer.stop() } }

            // Entrance animation
            opacity: 0
            transform: Translate { id: dockTr; y: 10 }
            Component.onCompleted: { opacity = 1; dockTr.y = 0 }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

            Row {
                id: dockRow
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
                        readonly property bool isActive: wins.some(w => w.is_focused)
                        readonly property bool sel: dock.keyboardMode && dock.selected === index
                        width: 56; height: 56
                        radius: Theme.radiusSmall
                        color: sel ? Theme.silver : isActive ? Theme.elevated : cellMa.containsMouse ? Theme.hover : "transparent"
                        border.width: isActive && !sel ? 1 : 0
                        border.color: Theme.muted
                        Behavior on color { ColorAnimation { duration: Theme.animFast } }
                        scale: cellMa.containsMouse ? 1.06 : 1.0
                        Behavior on scale { NumberAnimation { duration: Theme.animFast; easing.type: Theme.easing } }

                        AppIcon {
                            anchors.centerIn: parent
                            size: 40
                            icon: cell.modelData.entry ? cell.modelData.entry.icon : ""
                        }

                        // Running indicator dots
                        Row {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: Math.min(3, cell.wins.length)
                                delegate: Rectangle {
                                    width: cell.isActive ? 10 : 4; height: 2; radius: 1
                                    color: cell.sel ? Theme.inverse : cell.isActive ? Theme.silverBright : Theme.muted
                                }
                            }
                        }

                        MouseArea {
                            id: cellMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            onClicked: mouse => {
                                if (mouse.button === Qt.MiddleButton && cell.modelData.entry)
                                    cell.modelData.entry.execute()
                                else
                                    dock.activate(cell.modelData)
                            }
                        }

                        // Tooltip
                        Rectangle {
                            visible: cellMa.containsMouse || cell.sel
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 8
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: tipText.implicitWidth + 14; height: 22
                            radius: 3
                            color: Theme.elevated
                            border.width: 1
                            border.color: Theme.border
                            Text {
                                id: tipText
                                anchors.centerIn: parent
                                text: cell.modelData.entry ? cell.modelData.entry.name : (cell.modelData.appId || cell.modelData.id)
                                font.family: Theme.sans
                                font.pixelSize: 11
                                color: Theme.text
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }
    }
}
