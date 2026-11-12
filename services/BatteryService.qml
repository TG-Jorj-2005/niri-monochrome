pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// UPower display device + power profiles (when power-profiles-daemon exists).
Singleton {
    id: bat
    readonly property var device: UPower.displayDevice
    readonly property bool present: device && device.ready && device.isLaptopBattery && device.isPresent
    readonly property real percentage: device ? device.percentage * 100 : 0
    readonly property int state: device ? device.state : UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0
    readonly property bool low: present && !charging && percentage <= 15

    // Power profiles: probe for the daemon on the system bus.
    property bool profilesAvailable: false
    readonly property int profile: PowerProfiles.profile
    function setProfile(p) { if (profilesAvailable) PowerProfiles.profile = p }
    Process {
        id: probe
        command: ["busctl", "--system", "--no-pager", "--timeout=2", "status", "org.freedesktop.UPower.PowerProfiles"]
        running: true
        onExited: code => { bat.profilesAvailable = (code === 0) || bat.profilesAvailable }
    }
    Process {
        id: probe2
        command: ["busctl", "--system", "--no-pager", "--timeout=2", "status", "net.hadess.PowerProfiles"]
        running: true
        onExited: code => { bat.profilesAvailable = (code === 0) || bat.profilesAvailable }
    }

    function iconName() {
        if (!present) return "power-plug"
        if (charging) return "battery-charging"
        if (percentage > 87) return "battery-full"
        if (percentage > 60) return "battery-high"
        if (percentage > 35) return "battery-medium"
        if (percentage > 10) return "battery-low"
        return "battery-empty"
    }
    function stateText() {
        if (!present) return "AC power"
        if (full) return "Fully charged"
        if (charging) return "Charging" + (timeToFull > 0 ? " · " + fmt(timeToFull) + " to full" : "")
        if (timeToEmpty > 0) return "Discharging · " + fmt(timeToEmpty) + " left"
        return "Discharging"
    }
    function fmt(seconds) {
        const h = Math.floor(seconds / 3600), m = Math.floor((seconds % 3600) / 60)
        return h > 0 ? h + "h " + m + "m" : m + "m"
    }
    function profileName(p) {
        switch (p) { case PowerProfile.PowerSaver: return "Power saver"; case PowerProfile.Performance: return "Performance"; default: return "Balanced" }
    }
}
