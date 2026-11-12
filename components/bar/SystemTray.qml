import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.config
import qs.services
import qs.components.ui

// StatusNotifierItem host. Icons are desaturated like everything else.
Row {
    id: root
    property var bar
    spacing: 2
    Repeater {
        model: SystemTray.items
        delegate: Rectangle {
            id: cell
            required property var modelData
            width: 24; height: 24
            radius: Theme.radiusControl
            color: ma.containsMouse ? Theme.hover : "transparent"
            AppIcon { anchors.centerIn: parent; size: 14; icon: cell.modelData.icon; dim: cell.modelData.status === Status.Passive ? 0.6 : 1 }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const it = cell.modelData
                    if (mouse.button === Qt.RightButton || (mouse.button === Qt.LeftButton && it.onlyMenu)) {
                        if (it.hasMenu) root.bar.openPopover("tray", cell, it)
                    } else if (mouse.button === Qt.MiddleButton) it.secondaryActivate()
                    else it.activate()
                }
                onWheel: w => cell.modelData.scroll(w.angleDelta.y, false)
            }
        }
    }
}
