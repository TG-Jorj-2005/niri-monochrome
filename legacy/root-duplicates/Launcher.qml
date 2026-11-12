import QtQuick
import Quickshell
import Quickshell.Wayland

// Full-screen overlay launcher with app search. Opened via Mod+D / IPC.
Scope {
    id: launcher
    required property var modelData
    property bool visible_: false

    // ---- App search logic ----
    property var allApps: []
    property var results: []
    property int selected: 0

    function rebuild() {
        const list = []
        for (const e of DesktopEntries.applications.values) {
            if (!e || e.noDisplay) continue
            list.push(e)
        }
        list.sort((a, b) => a.name.localeCompare(b.name))
        allApps = list
    }
    Connections { target: DesktopEntries; function onApplicationsChanged() { launcher.rebuild() } }
    Component.onCompleted: rebuild()

    function score(query, text) {
        if (!query) return 1
        const q = query.toLowerCase(), t = text.toLowerCase()
        if (t === q) return 1000
        if (t.startsWith(q)) return 800 - t.length
        const idx = t.indexOf(q)
        if (idx >= 0) return 600 - idx
        // Subsequence match
        let ti = 0, s = 0, streak = 0
        for (let qi = 0; qi < q.length; qi++) {
            const pos = t.indexOf(q[qi], ti)
            if (pos < 0) return 0
            streak = (pos === ti) ? streak + 1 : 0
            s += 10 + streak * 5 - (pos - ti) * 0.5
            ti = pos + 1
        }
        return Math.max(1, s)
    }

    function search(query) {
        const q = (query || "").trim()
        const out = []
        for (const e of allApps) {
            let s = score(q, e.name)
            if (s === 0 && e.genericName) s = score(q, e.genericName) * 0.7
            if (s === 0 && e.comment) s = score(q, e.comment) * 0.5
            if (s > 0) out.push({ entry: e, score: s })
        }
        out.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name))
        return out.slice(0, 8).map(x => x.entry)
    }

    function refresh() {
        if (allApps.length === 0) rebuild()
        results = search(searchField.text)
        selected = 0
    }

    function launchSelected() {
        if (results.length === 0) return
        const entry = results[Math.min(selected, results.length - 1)]
        if (entry) { entry.execute(); launcher.visible_ = false }
    }

    function open() {
        visible_ = true
        searchField.text = ""
        refresh()
    }
    function close() { visible_ = false }
    function toggle() { if (visible_) close(); else open() }

    // ---- Overlay window ----
    PanelWindow {
        id: overlay
        screen: launcher.modelData
        visible: launcher.visible_
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        WlrLayershell.namespace: "nm-launcher"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: launcher.visible_ ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        // Scrim — click to close
        MouseArea {
            anchors.fill: parent
            onClicked: launcher.close()
            Rectangle { anchors.fill: parent; color: Theme.scrim }
        }

        // Launcher panel
        Rectangle {
            id: panel
            width: 600
            height: col.implicitHeight + 28
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(parent.height * 0.28)
            radius: Theme.radius
            color: Theme.surface
            border.width: 1
            border.color: Theme.muted
            antialiasing: true

            // Entrance animation
            opacity: launcher.visible_ ? 1 : 0
            transform: Translate { id: panelTr; y: launcher.visible_ ? 0 : 8 }
            Behavior on opacity { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }
            Behavior on transform { NumberAnimation { duration: Theme.animNormal; easing.type: Theme.easing } }

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                spacing: 10

                // Search field
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.radiusSmall
                    color: Theme.surface2
                    border.width: 1
                    border.color: searchField.activeFocus ? Theme.silver : Theme.border
                    Behavior on border.color { ColorAnimation { duration: Theme.animFast } }

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"
                        font.pixelSize: 16
                        color: Theme.muted
                        renderType: Text.NativeRendering
                    }

                    TextInput {
                        id: searchField
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 36
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        font.family: Theme.sans
                        font.pixelSize: 15
                        clip: true
                        renderType: Text.NativeRendering
                        onTextChanged: launcher.refresh()
                        onAccepted: launcher.launchSelected()
                        Keys.onDownPressed: launcher.selected = Math.min(launcher.results.length - 1, launcher.selected + 1)
                        Keys.onUpPressed: launcher.selected = Math.max(0, launcher.selected - 1)
                        Keys.onTabPressed: launcher.selected = (launcher.selected + 1) % Math.max(1, launcher.results.length)
                        Keys.onEscapePressed: launcher.close()

                        Text {
                            visible: searchField.text === ""
                            text: "Search applications"
                            color: Theme.muted
                            font: searchField.font
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Divider
                Rectangle { width: parent.width; height: 1; color: Theme.border }

                // Results
                Column {
                    width: parent.width
                    spacing: 2
                    Repeater {
                        model: launcher.results
                        delegate: Rectangle {
                            id: row
                            required property var modelData
                            required property int index
                            readonly property bool sel: launcher.selected === index
                            width: parent.width
                            height: 44
                            radius: Theme.radiusSmall
                            color: sel ? Theme.silver : rowMa.containsMouse ? Theme.hover : "transparent"

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 12
                                AppIcon {
                                    icon: row.modelData.icon
                                    size: 26
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 1
                                    Text {
                                        text: row.modelData.name
                                        color: row.sel ? Theme.inverse : Theme.text
                                        font.family: Theme.sans
                                        font.pixelSize: 13
                                        font.weight: Font.Medium
                                        width: row.width - 90
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        visible: text !== ""
                                        text: row.modelData.comment || row.modelData.genericName || ""
                                        color: row.sel ? Qt.rgba(0,0,0,0.6) : Theme.muted
                                        font.family: Theme.sans
                                        font.pixelSize: 11
                                        width: row.width - 90
                                        elide: Text.ElideRight
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }

                            // Return hint
                            Text {
                                visible: row.sel
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↵"
                                font.family: Theme.mono
                                font.pixelSize: 12
                                color: Theme.inverse
                                renderType: Text.NativeRendering
                            }

                            MouseArea {
                                id: rowMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: launcher.selected = row.index
                                onClicked: { launcher.selected = row.index; launcher.launchSelected() }
                            }
                        }
                    }

                    // Empty state
                    Item {
                        visible: launcher.results.length === 0
                        width: parent.width; height: 64
                        Text {
                            anchors.centerIn: parent
                            text: launcher.allApps.length === 0
                                ? "No applications found on this system"
                                : "No application matches \"" + searchField.text + "\""
                            color: Theme.muted
                            font.family: Theme.sans
                            font.pixelSize: 12
                            renderType: Text.NativeRendering
                        }
                    }
                }

                // Footer
                Row {
                    spacing: 14
                    Text {
                        text: launcher.results.length + " / " + launcher.allApps.length
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.muted
                        renderType: Text.NativeRendering
                    }
                    Text {
                        text: "↑↓ navigate · ↵ launch · esc close"
                        font.family: Theme.mono
                        font.pixelSize: 11
                        color: Theme.muted
                        renderType: Text.NativeRendering
                    }
                }
            }
        }

        onVisibleChanged: {
            if (visible) {
                searchField.text = ""
                launcher.refresh()
                searchField.forceActiveFocus()
            }
        }
    }
}
