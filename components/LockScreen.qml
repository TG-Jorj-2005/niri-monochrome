import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services
import qs.components.ui

// Secure lock: Wayland ext-session-lock via WlSessionLock + PAM via PamService.
// One surface per connected display; typing on any surface feeds the shared buffer.
WlSessionLock {
    id: lock
    locked: LockService.locked
    onSecureChanged: { LockService.secure = secure; if (secure) console.info("[Lock] session lock confirmed by compositor") }
    onLockedChanged: if (!locked) PamService.reset()

    surface: WlSessionLockSurface {
        id: surf
        color: Theme.background
        readonly property string monitorKey: MonitorService.keyFor(screen)
        readonly property string wallpaper: WallpaperService.current(monitorKey)
        SystemClock { id: clock; precision: SystemClock.Seconds }

        Image { anchors.fill: parent; source: surf.wallpaper ? "file://" + surf.wallpaper : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true
            sourceSize: Qt.size(surf.width, surf.height); opacity: 0.55 }
        Rectangle { anchors.fill: parent; color: "transparent"
            gradient: Gradient { GradientStop { position: 0.0; color: Qt.rgba(0,0,0,0.15) } GradientStop { position: 1.0; color: Qt.rgba(0,0,0,0.75) } } }

        // Brand
        Row { anchors { top: parent.top; left: parent.left; margins: 40 } spacing: 10
            Label { text: "NIRI"; font.weight: Font.Bold; font.letterSpacing: 3; color: Theme.silver }
            Label { text: "MONOCHROME"; font.weight: Font.Light; font.letterSpacing: 3; color: Theme.silverMuted } }
        Row { anchors { top: parent.top; right: parent.right; margins: 40 } spacing: 8; visible: UserConfig.data.security.showBattery && BatteryService.present
            MonoIcon { name: BatteryService.iconName(); size: 16; color: Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter }
            Label { text: Math.round(BatteryService.percentage) + "%"; mono: true; color: Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter } }

        Column {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -40
            spacing: 10
            Label { text: Qt.formatTime(clock.date, UserConfig.data.security.lockClockFormat); font.pixelSize: 96; font.weight: Font.Light; font.letterSpacing: -2; color: Theme.text; anchors.horizontalCenter: parent.horizontalCenter; mono: true }
            Label { text: Qt.formatDate(clock.date, UserConfig.data.security.lockDateFormat); font.pixelSize: Theme.fontLg; color: Theme.silver; anchors.horizontalCenter: parent.horizontalCenter; font.letterSpacing: 1 }
            Item { width: 1; height: 28 }
            Rectangle {
                width: 340; height: 46; radius: Theme.radiusControl
                anchors.horizontalCenter: parent.horizontalCenter
                color: Qt.rgba(0.07, 0.07, 0.07, 0.9)
                border.width: 1
                border.color: PamService.messageIsError ? Theme.silverBright : input.activeFocus ? Theme.silver : Theme.border
                MonoIcon { anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: PamService.authenticating ? "refresh" : "lock"; size: 16; color: Theme.silverMuted }
                TextInput {
                    id: input
                    anchors { left: parent.left; right: parent.right; leftMargin: 40; rightMargin: 14; verticalCenter: parent.verticalCenter }
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    color: Theme.text
                    font.family: Theme.fontMono; font.pixelSize: 16
                    focus: true
                    enabled: !PamService.authenticating && !PamService.delayed
                    text: LockService.password
                    onTextChanged: LockService.password = text
                    onAccepted: LockService.submit()
                    Keys.onEscapePressed: { text = ""; LockService.password = "" }
                    renderType: Text.NativeRendering
                    Text { visible: input.text === "" ; text: PamService.delayed ? "Wait…" : PamService.authenticating ? "Verifying…" : "Password"; color: Theme.textDisabled; font: input.font; anchors.verticalCenter: parent.verticalCenter; renderType: Text.NativeRendering }
                    Connections { target: LockService; function onPasswordChanged() { if (input.text !== LockService.password) input.text = LockService.password } }
                }
                // Silver authentication indicator
                Rectangle { anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 1; height: 2; radius: 1
                    color: Theme.silverBright; opacity: PamService.authenticating ? 1 : 0
                    SequentialAnimation on opacity { running: PamService.authenticating; loops: Animation.Infinite; NumberAnimation { to: 0.2; duration: 500 } NumberAnimation { to: 1; duration: 500 } } }
            }
            Label { text: PamService.message; color: PamService.messageIsError ? Theme.silverBright : Theme.silverMuted; font.pixelSize: Theme.fontSm; anchors.horizontalCenter: parent.horizontalCenter; height: 20 }
            Label { text: SystemService.user + "@" + SystemService.hostname; mono: true; font.pixelSize: Theme.fontXs; color: Theme.textDisabled; anchors.horizontalCenter: parent.horizontalCenter }
        }
        Label { anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; margins: 32 } mono: true; font.pixelSize: Theme.fontXs; color: Theme.textDisabled
            text: LockService.secure ? "SESSION LOCKED" : "LOCKING…"; font.letterSpacing: 2 }
        Component.onCompleted: input.forceActiveFocus()
        onVisibleChanged: if (visible) input.forceActiveFocus()
    }
}
