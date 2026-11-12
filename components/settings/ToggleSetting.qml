import QtQuick
import qs.config
import qs.components.ui
SettingRow {
    property string path: ""
    property bool value: UserConfig.get(path, false)
    signal changed(bool v)
    MonoToggle { checked: value; onToggled: c => { if (path !== "") UserConfig.set(path, c); changed(c) } }
}
