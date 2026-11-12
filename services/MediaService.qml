pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// MPRIS players. The "active" player is the one playing, else the user's pick, else the first.
Singleton {
    id: media
    readonly property var players: Mpris.players.values.filter(p => p && p.dbusName !== "org.mpris.MediaPlayer2.playerctld")
    property var selected: null
    readonly property var active: {
        if (selected && players.indexOf(selected) !== -1) return selected
        const playing = players.find(p => p.isPlaying)
        return playing || (players.length > 0 ? players[0] : null)
    }
    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active ? active.isPlaying : false
    readonly property string title: active ? (active.trackTitle || "") : ""
    readonly property string artist: active ? (active.trackArtist || "") : ""
    readonly property string album: active ? (active.trackAlbum || "") : ""
    readonly property string artUrl: active ? (active.trackArtUrl || "") : ""
    readonly property string playerName: active ? (active.identity || active.desktopEntry || "Player") : ""

    function select(p) { selected = p }
    function toggle() { if (active && active.canTogglePlaying) active.togglePlaying() }
    function next() { if (active && active.canGoNext) active.next() }
    function previous() { if (active && active.canGoPrevious) active.previous() }
    function raise() { if (active && active.canRaise) active.raise() }
}
