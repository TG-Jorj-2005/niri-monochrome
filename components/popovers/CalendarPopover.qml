import QtQuick
import Quickshell
import qs.config
import qs.components.ui

// Month view with today highlighted. Minimal, numeric, monospace.
PopoverFrame {
    id: cal
    title: "Calendar"
    icon: "calendar"
    implicitWidth: 300
    property date shown: new Date()
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property date today: clock.date

    Item {
        width: parent.width; height: 28
        IconButton { icon: "chevron-left"; anchors.left: parent.left; onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth() - 1, 1) }
        Label { anchors.centerIn: parent; text: Qt.formatDate(cal.shown, "MMMM yyyy"); font.weight: Font.DemiBold; font.pixelSize: Theme.fontMd }
        IconButton { icon: "chevron-right"; anchors.right: parent.right; onClicked: cal.shown = new Date(cal.shown.getFullYear(), cal.shown.getMonth() + 1, 1) }
    }
    Grid {
        columns: 7; width: parent.width
        Repeater { model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
            delegate: Label { required property string modelData; width: cal.width / 7 - 4; height: 22; text: modelData; mono: true; font.pixelSize: Theme.fontXs; color: Theme.textSecondary; horizontalAlignment: Text.AlignHCenter } }
    }
    Grid {
        id: days
        columns: 7; width: parent.width
        readonly property int first: (new Date(cal.shown.getFullYear(), cal.shown.getMonth(), 1).getDay() + 6) % 7
        readonly property int count: new Date(cal.shown.getFullYear(), cal.shown.getMonth() + 1, 0).getDate()
        Repeater {
            model: 42
            delegate: Rectangle {
                required property int index
                readonly property int day: index - days.first + 1
                readonly property bool inMonth: day >= 1 && day <= days.count
                readonly property bool isToday: inMonth && day === cal.today.getDate() && cal.shown.getMonth() === cal.today.getMonth() && cal.shown.getFullYear() === cal.today.getFullYear()
                width: cal.width / 7 - 4; height: 30
                radius: Theme.radiusControl
                color: isToday ? Theme.accent : "transparent"
                Label { anchors.centerIn: parent; text: parent.inMonth ? String(parent.day) : ""; mono: true; font.pixelSize: Theme.fontSm
                    color: parent.isToday ? Theme.textOnAccent(parent.color) : Theme.text; font.weight: parent.isToday ? Font.Bold : Font.Normal }
            }
        }
    }
    Label { text: Qt.formatDateTime(cal.today, "dddd, d MMMM yyyy  ·  HH:mm"); secondary: true; font.pixelSize: Theme.fontSm; width: parent.width; horizontalAlignment: Text.AlignHCenter }
}
