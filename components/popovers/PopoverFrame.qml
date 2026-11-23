import QtQuick
import qs.config
import qs.components.ui

// Common chrome for anchored popovers: dark panel, silver-muted border, title row.
Panel {
    id: frame
    property string title: ""
    property string icon: ""
    default property alias content: body.data
    property alias headerExtra: extra.data
    property int padding: 16
    implicitWidth: 360
    implicitHeight: header.height + body.implicitHeight + padding * 2 + (title !== "" ? 6 : 0)
    border.color: Theme.border
    radius: Theme.radiusPanel
    color: Theme.surface
    // soft shadow
    Rectangle { anchors.fill: parent; anchors.margins: -1; z: -1; radius: parent.radius + 1; color: "transparent"; border.color: Qt.rgba(0,0,0,0.5); border.width: 1 }

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: frame.padding }
        height: frame.title !== "" ? 22 : 0
        visible: frame.title !== ""
        Row { spacing: 8; anchors.verticalCenter: parent.verticalCenter
            MonoIcon { visible: frame.icon !== ""; name: frame.icon; size: 14; color: Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter }
            SectionTitle { text: frame.title.toUpperCase(); anchors.verticalCenter: parent.verticalCenter } }
        Row { id: extra; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 4 }
    }
    Column {
        id: body
        anchors { left: parent.left; right: parent.right; top: header.bottom; margins: frame.padding; topMargin: frame.title !== "" ? 6 : 0 }
        spacing: 10
    }
}
