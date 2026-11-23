import QtQuick
import Quickshell
import qs.config
import qs.services
import qs.components.ui

Rectangle {
    id: root
    property bool active: false
    property bool showDate: true
    property bool showSeconds: false
    property string clockFormat: "HH:mm"
    property string dateFormat: "ddd d MMM"
    signal clicked()
    SystemClock { id: clock; precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes }
    implicitWidth: row.implicitWidth + 12
    implicitHeight: 24
    radius: Theme.radiusControl
    color: active ? Theme.accentFill(ma.containsMouse, ma.pressed) : ma.containsMouse ? Theme.accentSubtle : "transparent"
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Label { text: Qt.formatDateTime(clock.date, root.showSeconds && root.clockFormat === "HH:mm" ? "HH:mm:ss" : root.clockFormat); mono: true; font.pixelSize: Theme.fontSm; font.weight: Font.DemiBold
            anchors.verticalCenter: parent.verticalCenter; color: root.active ? Theme.textOnAccent(root.color) : Theme.text }
        Label { visible: root.showDate; text: Qt.formatDateTime(clock.date, root.dateFormat); font.pixelSize: Theme.fontXs
            anchors.verticalCenter: parent.verticalCenter; color: root.active ? Theme.textOnAccent(root.color) : Theme.textSecondary }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
