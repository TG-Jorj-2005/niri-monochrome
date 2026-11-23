import QtQuick
import qs.config
import qs.services
Item {
    id: visualizer
    implicitHeight: 68
    property bool active: false
    property bool subscribed: false
    readonly property bool wanted: active && visible && UserConfig.data.media.visualizerEnabled
    readonly property int count: UserConfig.data.media.visualizerBarCount
    function sync() { if (wanted!==subscribed) { VisualizerService.watchers += wanted?1:-1; subscribed=wanted } }
    onWantedChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if(subscribed) VisualizerService.watchers--
    Row {
        anchors { left:parent.left;right:parent.right;top:parent.top;bottom:caption.top;bottomMargin:6 }
        spacing:3
        Repeater {
            model:visualizer.count
            delegate:Item {
                required property int index
                width:(visualizer.width-(visualizer.count-1)*3)/visualizer.count; height:parent.height
                readonly property real amount: UserConfig.data.media.visualizerStyle==="meter" ? (index/visualizer.count < VisualizerService.amplitude ? 0.85:0) : (VisualizerService.levels[index-(visualizer.count-VisualizerService.levels.length)] || 0)
                Rectangle {
                    anchors.bottom:parent.bottom; width:parent.width; radius:2
                    height:Math.max(2,parent.height*parent.amount)
                    color:parent.amount>0.02 ? Theme.silver : Theme.border
                    Behavior on height { enabled:Theme.motionEnabled; NumberAnimation { duration:60; easing.type:Easing.OutQuad } }
                }
            }
        }
    }
    Label { id:caption; anchors.bottom:parent.bottom; width:parent.width; font.pixelSize:Theme.fontXs; mono:true; secondary:true
        text:VisualizerService.status==="unavailable" ? "Output capture unavailable" : VisualizerService.status==="initializing" ? "Connecting to output…" : VisualizerService.status==="listening" ? "OUTPUT LEVEL · WAITING FOR AUDIO" : "OUTPUT LEVEL · " + (UserConfig.data.media.visualizerStyle==="history"?"AMPLITUDE HISTORY":"METER") }
}
