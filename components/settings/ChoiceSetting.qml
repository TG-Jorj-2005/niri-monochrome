import QtQuick
import qs.config
import qs.components.ui
SettingRow {
    id: cs
    property string path: ""
    property var options: []          // [{value, label}]
    property var value: UserConfig.get(path, null)
    signal changed(var v)
    Repeater { model: cs.options
        delegate: MonoButton { required property var modelData; text: modelData.label; implicitHeight: 28; padding: 10; active: cs.value === modelData.value
            onClicked: { if (cs.path !== "") UserConfig.set(cs.path, modelData.value); cs.changed(modelData.value) } } }
}
