import QtQuick
import qs.config
import qs.services
import qs.components.ui

// Numeric workspace pills for one output. Numbers = position in this output's workspace list.
Row {
    id: root
    required property string output
    spacing: 3
    readonly property var workspaces: NiriService.workspacesOn(output)

    Repeater {
        model: root.workspaces
        delegate: Rectangle {
            id: pill
            required property var modelData
            required property int index
            readonly property bool active: modelData.is_active
            readonly property bool urgent: modelData.is_urgent
            width: 22; height: 22
            radius: Theme.radiusControl
            color: active ? Theme.accentFill(ma.containsMouse, ma.pressed) : ma.containsMouse ? Theme.accentSubtle : "transparent"
            border.width: urgent && !active ? 1 : 0
            border.color: Theme.silverBright
            Behavior on color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.durFast } }
            Label {
                anchors.centerIn: parent
                text: String(index + 1)
                mono: true
                font.pixelSize: Theme.fontSm
                font.weight: pill.active ? Font.Bold : Font.Medium
                color: pill.active ? Theme.textOnAccent(pill.color) : pill.urgent ? Theme.silverBright : (ma.containsMouse ? Theme.text : Theme.textSecondary)
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: NiriService.focusWorkspaceById(pill.modelData.id)
                onWheel: w => NiriService.action([w.angleDelta.y < 0 ? "focus-workspace-down" : "focus-workspace-up"]) }
        }
    }
    // Empty state while niri is unreachable.
    Label { visible: !NiriService.connected; text: "niri —"; secondary: true; font.pixelSize: Theme.fontXs; mono: true }
}
