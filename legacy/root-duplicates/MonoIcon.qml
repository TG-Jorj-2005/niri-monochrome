import QtQuick
import Quickshell

// Vector icon from the Icons set, colored with any palette token. Crisp at any DPR.
Item {
    id: root
    property string name: "info"
    property color color: Theme.silver
    property real size: 16
    property real strokeWidth: 1.75
    implicitWidth: size
    implicitHeight: size
    Image {
        anchors.fill: parent
        source: Icons.url(root.name, root.color, root.strokeWidth)
        sourceSize: Qt.size(Math.ceil(root.size * (typeof Screen !== "undefined" && Screen.devicePixelRatio ? Screen.devicePixelRatio : 1)), Math.ceil(root.size * (typeof Screen !== "undefined" && Screen.devicePixelRatio ? Screen.devicePixelRatio : 1)))
        fillMode: Image.PreserveAspectFit
        smooth: true
        antialiasing: true
        cache: true
    }
}
