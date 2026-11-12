import QtQuick
import qs.config

// Rectangular button with optional icon. `active` inverts to silver-on-dark.
Rectangle {
    id: root
    property string text: ""
    property string icon: ""
    property real iconSize: 16
    property bool active: false
    property bool flat: false
    property bool danger: false
    property int padding: 12
    property alias hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()
    signal wheel(int delta)

    implicitHeight: 32
    implicitWidth: row.implicitWidth + padding * 2
    radius: Theme.radiusControl
    color: !enabled ? "transparent" : active ? (ma.containsMouse ? Theme.silverBright : Theme.silver) : ma.pressed ? Theme.pressed : ma.containsMouse ? Theme.hover : (flat ? "transparent" : Theme.surface2)
    border.width: flat || active ? 0 : 1
    border.color: ma.containsMouse ? Theme.silverMuted : Theme.border
    opacity: enabled ? 1 : 0.45
    Behavior on color { enabled: UserConfig.data.appearance.animations; ColorAnimation { duration: Theme.durFast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 8
        MonoIcon { visible: root.icon !== ""; name: root.icon; size: root.iconSize; anchors.verticalCenter: parent.verticalCenter
            color: root.active ? Theme.inverse : (ma.containsMouse ? Theme.silverBright : Theme.silver) }
        Label { visible: root.text !== ""; text: root.text; anchors.verticalCenter: parent.verticalCenter
            color: root.active ? Theme.inverse : (ma.containsMouse ? Theme.text : Theme.silver); font.pixelSize: Theme.fontSm; font.weight: Font.Medium }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.rightClicked(); else root.clicked() }
        onWheel: w => root.wheel(w.angleDelta.y)
    }
}
