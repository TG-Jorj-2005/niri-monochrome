import QtQuick
import qs.config

Text {
    property bool mono: false
    property bool secondary: false
    color: secondary ? Theme.textSecondary : Theme.text
    font.family: mono ? Theme.fontMono : Theme.fontSans
    font.pixelSize: Theme.fontMd
    elide: Text.ElideRight
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
}
