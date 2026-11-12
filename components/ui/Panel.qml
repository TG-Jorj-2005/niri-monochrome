import QtQuick
import qs.config

// Base surface: dark, 1px border, panel radius.
Rectangle {
    property bool elevated: false
    color: elevated ? Theme.surface2 : Theme.surface
    radius: Theme.radiusPanel
    border.width: Theme.borderWidth
    border.color: Theme.border
    antialiasing: true
}
