import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.services
import qs.components.ui

// Visual content of the lock screen. Used by the WlSessionLock surface in
// LockScreen.qml and, with `preview: true`, by a screenshot preview window.
// In preview mode nothing talks to PAM and the password field is inert.
Item {
    id: root
    property string wallpaper: ""
    property bool preview: false
    property string previewText: ""
    property bool shown: false
    readonly property string clockFormat: UserConfig.data.security.lockClockFormat
    readonly property string displayName: SystemService.realName !== "" ? SystemService.realName : SystemService.user
    readonly property string initials: displayName.split(/\s+/).filter(w => w.length).map(w => w[0].toUpperCase()).slice(0, 3).join("")
    readonly property var btConnected: BluetoothService.devices.filter(d => d && d.connected)

    function focusInput() { if (!preview) input.forceActiveFocus() }
    Component.onCompleted: Qt.callLater(() => root.shown = true)

    SystemClock { id: clock; precision: root.clockFormat.indexOf("s") >= 0 ? SystemClock.Seconds : SystemClock.Minutes }

    // ---- Background: monochrome, blurred wallpaper with a soft vignette ----
    Rectangle { anchors.fill: parent; color: Theme.background }
    Image {
        id: wall
        anchors.fill: parent
        anchors.margins: -48                       // hides the blur fall-off at the edges
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))
        visible: false
    }
    MultiEffect {
        anchors.fill: wall
        source: wall
        visible: wall.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: 1.0
        blurMax: 64
        blurMultiplier: 0.5
        saturation: UserConfig.data.appearance.grayscaleWallpaper ? -1.0 : 0.0   // follows Settings → Grayscale wallpaper
        brightness: -0.12
        opacity: root.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.motionEnabled ? 600 : 0; easing.type: Easing.OutCubic } }
    }
    Rectangle { anchors.fill: parent; color: Qt.rgba(0, 0, 0, 0.42) }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: Qt.rgba(0, 0, 0, 0.40) }
            GradientStop { position: 0.38; color: Qt.rgba(0, 0, 0, 0.0) }
            GradientStop { position: 0.70; color: Qt.rgba(0, 0, 0, 0.10) }
            GradientStop { position: 1.0;  color: Qt.rgba(0, 0, 0, 0.78) }
        }
    }

    // ---- Foreground, revealed with a short fade/lift ----
    Item {
        id: stage
        anchors.fill: parent
        opacity: root.shown ? 1 : 0
        property real lift: root.shown || !Theme.motionEnabled ? 0 : 18
        transform: Translate { y: stage.lift }
        Behavior on opacity { NumberAnimation { duration: Theme.motionEnabled ? 420 : 0; easing.type: Easing.OutCubic } }
        Behavior on lift { NumberAnimation { duration: Theme.motionEnabled ? 520 : 0; easing.type: Easing.OutCubic } }

        // Top-left: brand
        Row {
            anchors { top: parent.top; left: parent.left; topMargin: 34; leftMargin: 40 }
            spacing: 10
            Rectangle { width: 8; height: 8; color: Theme.silverBright; anchors.verticalCenter: parent.verticalCenter }
            Label { text: "NIRI"; font.pixelSize: Theme.fontSm; font.weight: Font.Bold; font.letterSpacing: 3.5; color: Theme.silverBright }
            Label { text: "MONOCHROME"; font.pixelSize: Theme.fontSm; font.weight: Font.Light; font.letterSpacing: 3.5; color: Theme.silverMuted }
        }

        // Top-right: system status
        Row {
            anchors { top: parent.top; right: parent.right; topMargin: 32; rightMargin: 40 }
            spacing: 22
            StatusItem {
                visible: NetworkService.available
                icon: NetworkService.wifiConnected ? "wifi" : NetworkService.wiredConnected ? "ethernet" : "wifi-off"
                text: NetworkService.wifiConnected ? NetworkService.ssid : NetworkService.wiredConnected ? "Ethernet" : "Offline"
            }
            StatusItem {
                visible: root.btConnected.length > 0
                icon: "bluetooth-connected"
                text: root.btConnected.length === 1 ? (root.btConnected[0].name || "Bluetooth") : root.btConnected.length + " devices"
            }
            StatusItem {
                visible: UserConfig.data.security.showBattery && BatteryService.present
                icon: BatteryService.iconName()
                text: Math.round(BatteryService.percentage) + "%"
                mono: true
            }
        }

        // Centre: date, clock, identity, password
        Column {
            id: centre
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -24
            spacing: 0

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDate(clock.date, UserConfig.data.security.lockDateFormat)
                font.pixelSize: Theme.fontLg
                font.weight: Font.Medium
                font.letterSpacing: 1.2
                color: Theme.silver
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatTime(clock.date, root.clockFormat)
                font.pixelSize: 132
                font.weight: Font.ExtraLight
                font.letterSpacing: -3
                color: Theme.text
                height: 150
            }
            Item { width: 1; height: 44 }

            // Avatar: AccountsService picture (greyscale), initials as fallback
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 72; height: 72
                // The frame only shows behind the initials fallback; a real picture keeps its own shape.
                radius: Theme.radiusControl
                color: avatar.status === Image.Ready ? "transparent" : Theme.surface2
                border.width: avatar.status === Image.Ready ? 0 : 1
                border.color: Theme.border
                Label {
                    anchors.centerIn: parent
                    visible: avatar.status !== Image.Ready
                    text: root.initials
                    font.pixelSize: 22; font.weight: Font.Medium; font.letterSpacing: 1.5
                    color: Theme.silverBright
                }
                Image {
                    id: avatar
                    anchors.fill: parent
                    source: "file://" + SystemService.avatarPath
                    sourceSize: Qt.size(144, 144)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                    layer.enabled: visible
                    layer.effect: MultiEffect { saturation: -1.0 }
                }
            }
            Item { width: 1; height: 14 }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.displayName
                font.pixelSize: Theme.fontXl
                font.weight: Font.Medium
                color: Theme.text
            }
            Item { width: 1; height: 4 }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: SystemService.user + "@" + SystemService.hostname
                mono: true
                font.pixelSize: Theme.fontXs
                color: Theme.silverMuted
            }
            Item { width: 1; height: 22 }

            // Password field (shakes on failure)
            Item {
                id: fieldHolder
                anchors.horizontalCenter: parent.horizontalCenter
                width: 340; height: 46
                property real shift: 0
                transform: Translate { x: fieldHolder.shift }
                SequentialAnimation {
                    id: shake
                    NumberAnimation { target: fieldHolder; property: "shift"; to: 11;  duration: 45; easing.type: Easing.OutQuad }
                    NumberAnimation { target: fieldHolder; property: "shift"; to: -9;  duration: 70; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: fieldHolder; property: "shift"; to: 6;   duration: 60; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: fieldHolder; property: "shift"; to: -3;  duration: 50; easing.type: Easing.InOutQuad }
                    NumberAnimation { target: fieldHolder; property: "shift"; to: 0;   duration: 45; easing.type: Easing.OutQuad }
                }
                Connections {
                    target: PamService
                    enabled: !root.preview
                    function onFailed() { if (Theme.motionEnabled) shake.restart() }
                }

                Rectangle {
                    id: field
                    anchors.fill: parent
                    radius: Theme.radiusControl
                    color: Qt.rgba(0.06, 0.06, 0.06, 0.78)
                    border.width: 1
                    border.color: !root.preview && PamService.messageIsError ? Theme.silverBright
                                : (input.activeFocus || root.preview) ? Theme.silver : Theme.border
                    Behavior on border.color { enabled: Theme.motionEnabled; ColorAnimation { duration: Theme.durFast } }

                    MonoIcon {
                        id: lockIcon
                        anchors { left: parent.left; leftMargin: 15; verticalCenter: parent.verticalCenter }
                        name: !root.preview && PamService.authenticating ? "refresh" : "lock"
                        size: 16
                        color: Theme.silverMuted
                        RotationAnimation on rotation { running: !root.preview && PamService.authenticating && Theme.motionEnabled; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                        onNameChanged: rotation = 0
                    }
                    TextInput {
                        id: input
                        anchors { left: lockIcon.right; right: submit.left; leftMargin: 12; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        passwordMaskDelay: 0
                        color: Theme.text
                        font.family: Theme.fontMono
                        font.pixelSize: 16
                        font.letterSpacing: 2
                        clip: true
                        readOnly: root.preview
                        enabled: root.preview || (!PamService.authenticating && !PamService.delayed)
                        text: root.preview ? root.previewText : LockService.password
                        onTextChanged: if (!root.preview) LockService.password = text
                        onAccepted: if (!root.preview) LockService.submit()
                        Keys.onEscapePressed: { if (!root.preview) { text = ""; LockService.password = "" } }
                        renderType: Text.NativeRendering
                        Text {
                            visible: input.text === ""
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.preview ? "Password"
                                : PamService.delayed ? "Please wait…"
                                : PamService.authenticating ? "Verifying…" : "Password"
                            color: Theme.textDisabled
                            font.family: Theme.fontSans
                            font.pixelSize: Theme.fontLg
                            renderType: Text.NativeRendering
                        }
                        Connections {
                            target: LockService
                            enabled: !root.preview
                            function onPasswordChanged() { if (input.text !== LockService.password) input.text = LockService.password }
                        }
                    }
                    IconButton {
                        id: submit
                        anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                        icon: "arrow-right"
                        iconSize: 16
                        opacity: input.text !== "" ? 1 : 0
                        enabled: input.text !== "" && !root.preview && !PamService.authenticating
                        activeFocusOnTab: false
                        Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
                        onClicked: { LockService.submit(); root.focusInput() }
                    }
                    // Authentication progress line
                    Rectangle {
                        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }
                        height: 2
                        color: Theme.silverBright
                        opacity: !root.preview && PamService.authenticating ? 1 : 0
                        SequentialAnimation on opacity {
                            running: !root.preview && PamService.authenticating && Theme.motionEnabled
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 500 }
                            NumberAnimation { to: 1; duration: 500 }
                        }
                    }
                }
            }
            Item { width: 1; height: 12 }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                height: 18
                text: root.preview ? "" : PamService.message !== "" && PamService.message !== "Verifying…"
                      ? PamService.message + (PamService.failures > 1 ? "  ·  " + PamService.failures + " attempts" : "")
                      : ""
                color: PamService.messageIsError ? Theme.silverBright : Theme.silverMuted
                font.pixelSize: Theme.fontSm
            }
        }

        // Bottom-left: now playing
        Row {
            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 40; bottomMargin: 30 }
            spacing: 12
            visible: MediaService.hasPlayer && MediaService.title !== ""
            MonoIcon { name: "music"; size: 14; color: Theme.silverMuted; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Label { text: MediaService.title; width: Math.min(implicitWidth, 300); font.pixelSize: Theme.fontSm; font.weight: Font.Medium; color: Theme.silverBright }
                Label { text: MediaService.artist; visible: text !== ""; width: Math.min(implicitWidth, 300); font.pixelSize: Theme.fontXs; color: Theme.silverMuted }
            }
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                IconButton { icon: "skip-back"; iconSize: 14; implicitWidth: 28; implicitHeight: 28; activeFocusOnTab: false; onClicked: { MediaService.previous(); root.focusInput() } }
                IconButton { icon: MediaService.playing ? "pause" : "play"; iconSize: 14; implicitWidth: 28; implicitHeight: 28; activeFocusOnTab: false; onClicked: { MediaService.toggle(); root.focusInput() } }
                IconButton { icon: "skip-forward"; iconSize: 14; implicitWidth: 28; implicitHeight: 28; activeFocusOnTab: false; onClicked: { MediaService.next(); root.focusInput() } }
            }
        }

        // Bottom-centre: key hints
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 34 }
            spacing: 18
            KeyHint { key: "ENTER"; text: "unlock" }
            KeyHint { key: "ESC"; text: "clear" }
        }

        // Bottom-right: lock state
        Row {
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: 40; bottomMargin: 34 }
            id: lockState
            spacing: 9
            readonly property bool secure: root.preview || LockService.secure
            Rectangle {
                width: 6; height: 6
                anchors.verticalCenter: parent.verticalCenter
                color: lockState.secure ? Theme.silverBright : Theme.silverMuted
                SequentialAnimation on opacity {
                    running: !lockState.secure && Theme.motionEnabled
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 450 }
                    NumberAnimation { to: 1; duration: 450 }
                }
            }
            Label {
                text: lockState.secure ? "SESSION LOCKED" : "LOCKING…"
                mono: true
                font.pixelSize: Theme.fontXs
                font.letterSpacing: 2
                color: Theme.silverMuted
            }
        }
    }

    component StatusItem: Row {
        property string icon: ""
        property alias text: lbl.text
        property alias mono: lbl.mono
        spacing: 7
        MonoIcon { name: parent.icon; size: 14; color: Theme.silver; anchors.verticalCenter: parent.verticalCenter }
        Label { id: lbl; font.pixelSize: Theme.fontSm; color: Theme.silver; anchors.verticalCenter: parent.verticalCenter }
    }
    component KeyHint: Row {
        property string key: ""
        property alias text: hintText.text
        spacing: 7
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: keyText.implicitWidth + 12; height: 18
            radius: 3
            color: "transparent"
            border.width: 1
            border.color: Theme.border
            Label { id: keyText; anchors.centerIn: parent; text: parent.parent.key; mono: true; font.pixelSize: 9; font.letterSpacing: 1; color: Theme.silverMuted }
        }
        Label { id: hintText; anchors.verticalCenter: parent.verticalCenter; font.pixelSize: Theme.fontXs; color: Theme.textDisabled }
    }
}
