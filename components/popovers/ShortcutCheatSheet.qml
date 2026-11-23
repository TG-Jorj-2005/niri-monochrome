import QtQuick
import qs.config
import qs.services
import qs.components.ui
Panel {
    id: sheet
    implicitWidth: 820
    implicitHeight: 560
    property string category: "All"
    readonly property var results: ShortcutService.filter(search.text,category)
    property int selected: 0
    onResultsChanged: selected=0
    function navigate(delta) { if (!results.length) { selected=0; return }; selected=Math.max(0,Math.min(results.length-1,selected+delta)); list.positionViewAtIndex(selected,ListView.Contain) }
    onActiveFocusChanged: if (activeFocus) search.input.forceActiveFocus()
    Component.onCompleted: { ShortcutService.refresh(); search.input.forceActiveFocus() }
    Column {
        anchors.fill: parent; anchors.margins: 20; spacing: 12
        Row { id:heading; width: parent.width
            Label { width: parent.width-32; text: "Keyboard Shortcuts"; font.pixelSize: Theme.fontXl; font.weight: Font.DemiBold }
            IconButton { icon:"x"; tooltip:"Close"; onClicked: ShellState.close() }
        }
        MonoTextField { id: search; width: parent.width; icon: "search"; placeholder: "Search action, keys or category"
            input.activeFocusOnTab: true
            input.Keys.onDownPressed: sheet.navigate(1)
            input.Keys.onUpPressed: sheet.navigate(-1)
            input.Keys.onEscapePressed: ShellState.close()
        }
        Flow { id:categories; width: parent.width; spacing: 5
            Repeater { model: ShortcutService.categories
                delegate: MonoButton { required property string modelData; text:modelData; implicitHeight:26; padding:8; active:sheet.category===modelData; onClicked:sheet.category=modelData }
            }
        }
        ListView {
            id:list; width:parent.width; height:Math.max(0,sheet.height-40-y-footer.implicitHeight-12); clip:true
            model:sheet.results; spacing:4; currentIndex:sheet.selected
            delegate: Rectangle {
                required property var modelData
                required property int index
                id:row; width:list.width; height:Math.max(description.implicitHeight,caps.implicitHeight)+16; radius:Theme.radiusControl
                color:sheet.selected===index ? Theme.accentSubtle : "transparent"
                border.width:sheet.selected===index ? 1:0; border.color:Theme.accent
                Behavior on color { ColorAnimation { duration:Theme.durFast } }
                Row { anchors.fill:parent; anchors.margins:8; spacing:12
                    Column { id:description; width:Math.max(40,parent.width-caps.width-12); anchors.verticalCenter:parent.verticalCenter; spacing:2
                        Label { text:row.modelData.label; width:parent.width; font.weight:Font.Medium; wrapMode:Text.Wrap; elide:Text.ElideNone; textFormat:Text.PlainText }
                        Label { text:row.modelData.category + " · " + row.modelData.description; width:parent.width; secondary:true; font.pixelSize:Theme.fontXs; wrapMode:Text.WrapAnywhere; elide:Text.ElideNone; textFormat:Text.PlainText }
                    }
                    Flow { id:caps; width:Math.max(40,parent.width*0.48); spacing:4; anchors.verticalCenter:parent.verticalCenter
                        Repeater { model:row.modelData.key.split("+")
                            delegate: Rectangle { required property string modelData; width:Math.min(key.implicitWidth+12,caps.width); height:Math.max(26,key.implicitHeight+8); radius:4; color:Theme.surface2; border.width:1; border.color:Theme.border
                                Label { id:key; anchors.centerIn:parent; width:parent.width-12; text:modelData; mono:true; font.pixelSize:Theme.fontSm; wrapMode:Text.WrapAnywhere; elide:Text.ElideNone; textFormat:Text.PlainText }
                            }
                        }
                    }
                }
                MouseArea { anchors.fill:parent; hoverEnabled:true; onEntered:sheet.selected=parent.index }
            }
            Label { anchors.centerIn:parent; visible:sheet.results.length===0; text:"No matching shortcuts"; secondary:true }
        }
        Label { id:footer; width:parent.width; text:"Informational • " + ShortcutService.scopeNote; font.pixelSize:Theme.fontXs; secondary:true; wrapMode:Text.Wrap }
    }
}
