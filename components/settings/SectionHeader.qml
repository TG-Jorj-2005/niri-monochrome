import QtQuick
import qs.config
import qs.components.ui
Column {
    property string title: ""
    property string subtitle: ""
    width: parent.width
    spacing: 4
    topPadding: 8
    bottomPadding: 6
    Label { text: title; font.pixelSize: Theme.fontXl; font.weight: Font.DemiBold; font.letterSpacing: -0.3 }
    Label { visible: subtitle !== ""; text: subtitle; secondary: true; font.pixelSize: Theme.fontSm; width: parent.width; wrapMode: Text.Wrap }
}
