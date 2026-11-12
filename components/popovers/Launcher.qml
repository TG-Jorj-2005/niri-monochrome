import QtQuick
import qs.config
import qs.services
import qs.components.ui

// Application-only launcher: fuzzy search over desktop entries, keyboard driven.
Panel {
    id: launcher
    property string screenName: ""
    readonly property var cfg: UserConfig.data.launcher
    implicitWidth: cfg.width
    implicitHeight: col.implicitHeight + 28
    border.color: Theme.silverMuted

    property var results: []
    property int selected: 0
    property string error: ""
    // Easter egg: a tiny tribute hidden behind two names.
    readonly property bool egg: /^(petru|ardei)\b/i.test(field.text.trim())

    function refresh() {
        results = ApplicationService.search(field.text, cfg.maxResults)
        selected = 0
    }
    function launchSelected() {
        if (egg) { ShellState.close(); return }
        if (results.length === 0) return
        ApplicationService.launch(results[Math.min(selected, results.length - 1)])
    }
    Connections { target: ApplicationService
        function onLaunched(name) { ShellState.close() }
        function onLaunchFailed(name, reason) { launcher.error = name + ": " + reason } }
    Component.onCompleted: { refresh(); field.input.forceActiveFocus() }
    onActiveFocusChanged: if (activeFocus) field.input.forceActiveFocus()

    Column {
        id: col
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 10
        MonoTextField {
            id: field
            width: parent.width
            icon: "search"
            placeholder: "Search applications"
            onTextChanged: { launcher.error = ""; launcher.refresh() }
            onAccepted: launcher.launchSelected()
            input.Keys.onDownPressed: launcher.selected = Math.min(launcher.results.length - 1, launcher.selected + 1)
            input.Keys.onUpPressed: launcher.selected = Math.max(0, launcher.selected - 1)
            input.Keys.onTabPressed: launcher.selected = (launcher.selected + 1) % Math.max(1, launcher.results.length)
            input.Keys.onEscapePressed: ShellState.close()
        }
        Divider { width: parent.width }

        // Easter egg card
        Rectangle { visible: launcher.egg; width: parent.width; height: 44; radius: Theme.radiusControl; color: Theme.silver
            Label { anchors.centerIn: parent; text: "Petru și Ardei sunt șmecheri."; color: Theme.inverse; font.weight: Font.Bold; font.letterSpacing: 0.5 } }

        Column {
            width: parent.width
            spacing: 2
            visible: !launcher.egg
            Repeater {
                model: launcher.results
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool sel: launcher.selected === index
                    width: parent.width; height: 44
                    radius: Theme.radiusControl
                    color: sel ? Theme.silver : ma.containsMouse ? Theme.hover : "transparent"
                    Row {
                        anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        AppIcon { icon: row.modelData.icon; size: 26; anchors.verticalCenter: parent.verticalCenter; dim: row.sel ? 0.2 : 1 }
                        Column { anchors.verticalCenter: parent.verticalCenter; spacing: 1
                            Label { text: row.modelData.name; color: row.sel ? Theme.inverse : Theme.text; font.weight: Font.Medium; width: launcher.width - 120 }
                            Label { visible: launcher.cfg.showDescriptions && text !== ""; text: row.modelData.comment || row.modelData.genericName || ""; font.pixelSize: Theme.fontXs
                                color: row.sel ? Qt.rgba(0,0,0,0.6) : Theme.silverMuted; width: launcher.width - 120 } }
                    }
                    Label { visible: row.sel; text: "↵"; mono: true; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; color: Theme.inverse; font.pixelSize: Theme.fontSm }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onEntered: launcher.selected = row.index
                        onClicked: { launcher.selected = row.index; launcher.launchSelected() } }
                }
            }
            // Empty state
            Item { visible: launcher.results.length === 0; width: parent.width; height: 64
                Column { anchors.centerIn: parent; spacing: 4
                    MonoIcon { name: "inbox"; size: 20; color: Theme.textDisabled; anchors.horizontalCenter: parent.horizontalCenter }
                    Label { text: ApplicationService.visible.length === 0 ? "No applications found on this system" : "No application matches “" + field.text + "”"; secondary: true; font.pixelSize: Theme.fontSm; anchors.horizontalCenter: parent.horizontalCenter } } }
        }
        Label { visible: launcher.error !== ""; text: launcher.error; color: Theme.silverBright; font.pixelSize: Theme.fontSm; width: parent.width; wrapMode: Text.Wrap }
        Row { spacing: 14
            Label { text: launcher.results.length + " / " + ApplicationService.visible.length; mono: true; font.pixelSize: Theme.fontXs; color: Theme.textDisabled }
            Label { text: "↑↓ navigate · ↵ launch · esc close"; mono: true; font.pixelSize: Theme.fontXs; color: Theme.textDisabled } }
    }
}
