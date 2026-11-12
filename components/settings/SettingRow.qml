import QtQuick
import qs.config
import qs.components.ui

// Label + description on the left, control on the right.
Item {
    id: row
    property string label: ""
    property string description: ""
    default property alias control: slot.data
    width: parent ? parent.width : 400
    height: Math.max(44, col.implicitHeight + 16)
    Column { id: col; anchors.left: parent.left; anchors.right: slot.left; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; spacing: 2
        Label { text: row.label; font.pixelSize: Theme.fontMd; width: parent.width }
        Label { visible: row.description !== ""; text: row.description; secondary: true; font.pixelSize: Theme.fontXs; width: parent.width; wrapMode: Text.Wrap } }
    Row { id: slot; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6 }
    Divider { anchors.bottom: parent.bottom; width: parent.width; opacity: 0.6 }
}
