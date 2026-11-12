import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components.ui

// Compact OSD above the bar on the focused output. Mapped only while visible.
PanelWindow {
    id: win
    required property var modelData
    readonly property bool onFocused: NiriService.focusedOutput === modelData.name || (NiriService.focusedOutput === "" && Quickshell.screens[0] === modelData)
    readonly property var barCfg: MonitorProfiles.profile(MonitorService.keyFor(modelData)).bar
    screen: modelData
    visible: OsdService.visible && onFocused
    anchors.bottom: true
    margins.bottom: (barCfg.enabled ? barCfg.marginBottom + barCfg.height : 12) + 16
    implicitWidth: UserConfig.data.osd.width
    implicitHeight: 44
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.namespace: "nm-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    mask: Region {}          // click-through
    Panel {
        anchors.fill: parent
        border.color: Theme.silverMuted
        Row {
            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 12
            MonoIcon { name: OsdService.iconName(); size: 18; anchors.verticalCenter: parent.verticalCenter; color: OsdService.muted ? Theme.silverMuted : Theme.silver }
            Item { width: parent.width - 18 - 12 - 44 - 12; height: parent.height
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1; color: Theme.border }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.max(0, Math.min(1, OsdService.value)); height: 3; radius: 1
                    color: OsdService.muted ? Theme.silverMuted : Theme.silverBright
                    Behavior on width { enabled: UserConfig.data.appearance.animations; NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing } } } }
            Label { text: OsdService.muted ? "MUTE" : Math.round(OsdService.value * 100) + "%"; mono: true; width: 44; horizontalAlignment: Text.AlignRight; font.pixelSize: Theme.fontSm; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
