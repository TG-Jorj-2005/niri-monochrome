import QtQuick
import Quickshell
import qs.config
import qs.components.ui
import qs.services

// Renders a StatusNotifierItem DBus menu (one level, submenus open in place).
PopoverFrame {
    id: menu
    property var item
    property var handle: item ? item.menu : null
    implicitWidth: 240
    QsMenuOpener { id: opener; menu: menu.handle }
    Column {
        width: parent.width
        spacing: 2
        Repeater {
            model: opener.children
            delegate: Item {
                required property var modelData
                width: parent.width
                height: modelData.isSeparator ? 9 : 30
                Divider { visible: modelData.isSeparator; anchors.centerIn: parent; width: parent.width }
                Rectangle {
                    visible: !modelData.isSeparator
                    anchors.fill: parent
                    radius: Theme.radiusControl
                    color: ma.containsMouse && modelData.enabled ? Theme.hover : "transparent"
                    opacity: modelData.enabled ? 1 : 0.4
                    Row { anchors.left: parent.left; anchors.leftMargin: 8; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                        MonoIcon { visible: modelData.buttonType !== QsMenuButtonType.None; name: modelData.checkState === Qt.Checked ? "check" : "minus"; size: 12; color: Theme.silver; anchors.verticalCenter: parent.verticalCenter; opacity: modelData.checkState === Qt.Checked ? 1 : 0.25 }
                        Label { text: modelData.text; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter } }
                    MonoIcon { visible: modelData.hasChildren; name: "chevron-right"; size: 12; anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; color: Theme.silverMuted }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; enabled: modelData.enabled
                        onClicked: { if (modelData.hasChildren) opener.menu = modelData; else { modelData.triggered(); ShellState.close() } } }
                }
            }
        }
        Label { visible: opener.children.values.length === 0; text: "No menu entries"; secondary: true; font.pixelSize: Theme.fontSm }
    }
}
