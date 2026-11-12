import QtQuick
import qs.config
import qs.components.ui

// Minimal NIRI wordmark. Click → native overview.
Rectangle {
    id: root
    signal clicked()
    implicitWidth: t.implicitWidth + 12
    implicitHeight: 22
    radius: Theme.radiusControl
    color: ma.containsMouse ? Theme.hover : "transparent"
    Label { id: t; anchors.centerIn: parent; text: "NIRI"; font.pixelSize: Theme.fontXs; font.weight: Font.Bold; font.letterSpacing: 2
        color: ma.containsMouse ? Theme.text : Theme.silver }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.clicked() }
}
