import QtQuick
import qs.config
import qs.services
import qs.components.ui

Rectangle {
    id: root
    property bool active: false
    signal clicked()
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 24
    radius: Theme.radiusControl
    color: active ? Theme.silver : ma.containsMouse ? Theme.hover : "transparent"
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4
        MonoIcon { name: BatteryService.iconName(); size: 14; anchors.verticalCenter: parent.verticalCenter
            color: root.active ? Theme.inverse : BatteryService.low ? Theme.silverBright : Theme.silver }
        Label { visible: BatteryService.present; text: Math.round(BatteryService.percentage) + "%"; mono: true; font.pixelSize: Theme.fontXs
            anchors.verticalCenter: parent.verticalCenter; color: root.active ? Theme.inverse : Theme.silver }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
