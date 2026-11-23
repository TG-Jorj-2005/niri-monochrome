import QtQuick
import qs.config
import qs.services
import qs.components.ui

// Center section: icon · app name · title (single line, elided).
// On a non-focused output the output's active window is shown in a neutral muted style.
Item {
    id: root
    required property string output
    property bool isFocusedOutput: true
    property int maxChars: 64
    property bool showAppName: true
    property real maxWidth: 600

    readonly property var win: isFocusedOutput ? NiriService.focusedWindow : NiriService.activeWindowOn(output)
    readonly property var entry: win ? ApplicationService.forAppId(win.app_id) : null
    readonly property string appName: entry ? entry.name : (win ? (win.app_id || "") : "")
    readonly property string title: win ? (win.title || "") : ""
    readonly property string display: {
        if (!win) return isFocusedOutput ? "" : ""
        let t = title
        if (t.length > maxChars) t = t.substring(0, maxChars - 1) + "…"
        if (showAppName && appName && t && !t.toLowerCase().includes(appName.toLowerCase())) return appName + "  ·  " + t
        return t || appName
    }

    implicitWidth: row.implicitWidth
    implicitHeight: 24
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        AppIcon { visible: root.win !== null; icon: root.entry ? root.entry.icon : ""; size: 16; anchors.verticalCenter: parent.verticalCenter
            dim: root.isFocusedOutput ? 1.0 : 0.6; fallbackGlyph: "app" }
        MonoIcon { visible: root.win === null; name: root.isFocusedOutput ? "layers" : "monitor"; size: 13; color: Theme.textDisabled; anchors.verticalCenter: parent.verticalCenter }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, root.maxWidth - 40)
            text: root.win ? root.display : (root.isFocusedOutput ? "Desktop" : "Inactive display")
            color: root.win ? (root.isFocusedOutput ? Theme.text : Theme.textSecondary) : Theme.textSecondary
            font.pixelSize: Theme.fontSm
            font.weight: root.isFocusedOutput && root.win ? Font.Medium : Font.Normal
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
