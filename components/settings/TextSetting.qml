import QtQuick
import qs.config
import qs.components.ui
SettingRow {
    id: ts
    property string path: ""
    property string value: UserConfig.get(path, "")
    property bool mono: true
    property int fieldWidth: 220
    property var validate: null       // function(text) -> bool
    property bool valid: true
    signal changed(string v)
    MonoTextField { width: ts.fieldWidth; implicitHeight: 30; text: ts.value; mono: ts.mono; input.font.pixelSize: Theme.fontSm
        border.color: !ts.valid ? Theme.silverBright : input.activeFocus ? Theme.accent : Theme.border
        onTextChanged: ts.valid = ts.validate ? ts.validate(text) : true
        onAccepted: { if (ts.valid) { if (ts.path !== "") UserConfig.set(ts.path, text); ts.changed(text) } }
        input.onEditingFinished: { if (ts.valid && text !== ts.value) { if (ts.path !== "") UserConfig.set(ts.path, text); ts.changed(text) } } }
}
