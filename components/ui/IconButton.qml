import QtQuick
import qs.config

// Square icon-only button used in the bar, popovers and toasts.
Rectangle {
    id: root
    property string icon: "info"
    property real iconSize: 16
    property bool active: false
    property string tooltip: ""
    property alias hovered: ma.containsMouse
    signal clicked()
    signal rightClicked()
    signal middleClicked()
    signal wheel(int delta)
    implicitWidth: 30
    implicitHeight: 30
    radius: Theme.radiusControl
    color: active ? Theme.silver : ma.pressed ? Theme.pressed : ma.containsMouse ? Theme.hover : "transparent"
    opacity: enabled ? 1 : 0.4
    Behavior on color { enabled: UserConfig.data.appearance.animations; ColorAnimation { duration: Theme.durFast } }
    MonoIcon { anchors.centerIn: parent; name: root.icon; size: root.iconSize
        color: root.active ? Theme.inverse : (ma.containsMouse ? Theme.silverBright : Theme.silver) }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        enabled: root.enabled
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => { if (mouse.button === Qt.RightButton) root.rightClicked(); else if (mouse.button === Qt.MiddleButton) root.middleClicked(); else root.clicked() }
        onWheel: w => root.wheel(w.angleDelta.y)
    }
}
