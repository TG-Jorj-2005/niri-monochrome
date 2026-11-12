import QtQuick
import qs.config
import qs.components.ui
SettingRow {
    id: ns
    property string path: ""
    property real value: UserConfig.get(path, 0)
    property real from: 0
    property real to: 100
    property real step: 1
    property string unit: ""
    signal changed(real v)
    function commit(v) { v = Math.max(from, Math.min(to, Math.round(v / step) * step)); if (path !== "") UserConfig.set(path, v); changed(v) }
    IconButton { icon: "minus"; iconSize: 12; implicitWidth: 24; implicitHeight: 28; onClicked: ns.commit(ns.value - ns.step) }
    Rectangle { width: 72; height: 28; radius: Theme.radiusControl; color: Theme.surface2; border.width: 1; border.color: ti.activeFocus ? Theme.silver : Theme.border
        TextInput { id: ti; anchors.fill: parent; anchors.margins: 6; text: String(ns.value); color: Theme.text; font.family: Theme.fontMono; font.pixelSize: Theme.fontSm; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
            validator: DoubleValidator { bottom: ns.from; top: ns.to }
            onEditingFinished: { const v = parseFloat(text); if (!isNaN(v)) ns.commit(v); else text = String(ns.value) }
            Connections { target: ns; function onValueChanged() { if (!ti.activeFocus) ti.text = String(ns.value) } } } }
    Label { visible: ns.unit !== ""; text: ns.unit; secondary: true; font.pixelSize: Theme.fontXs; width: 28 }
    IconButton { icon: "plus"; iconSize: 12; implicitWidth: 24; implicitHeight: 28; onClicked: ns.commit(ns.value + ns.step) }
}
