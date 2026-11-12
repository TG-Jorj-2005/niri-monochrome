pragma Singleton
import QtQuick
import Quickshell
import qs.config

// Structured logging with levels and a bounded in-memory ring (shown in Settings → System).
// Level order: debug < info < warn < error. Default minimum comes from config `system.logLevel`.
Singleton {
    id: log
    readonly property var levels: ({ debug: 0, info: 1, warn: 2, error: 3 })
    readonly property int minLevel: levels[(UserConfig.data.system && UserConfig.data.system.logLevel) || "info"] ?? 1
    readonly property int ringSize: 200
    property var entries: []          // [{t, level, tag, msg}]
    property int errorCount: 0
    property int warnCount: 0

    function fmt(args) { return Array.prototype.slice.call(args).map(a => typeof a === "object" ? JSON.stringify(a) : String(a)).join(" ") }
    function emit(level, tag, args) {
        if (levels[level] < minLevel) return
        const msg = fmt(args)
        const line = "[" + tag + "] " + msg
        switch (level) {
        case "error": console.error(line); errorCount++; break
        case "warn": console.warn(line); warnCount++; break
        default: console.info(line)
        }
        const next = entries.length >= ringSize ? entries.slice(entries.length - ringSize + 1) : entries.slice()
        next.push({ t: Date.now(), level: level, tag: tag, msg: msg })
        entries = next
    }
    function debug(tag) { emit("debug", tag, Array.prototype.slice.call(arguments, 1)) }
    function info(tag)  { emit("info",  tag, Array.prototype.slice.call(arguments, 1)) }
    function warn(tag)  { emit("warn",  tag, Array.prototype.slice.call(arguments, 1)) }
    function error(tag) { emit("error", tag, Array.prototype.slice.call(arguments, 1)) }
    function clear() { entries = []; errorCount = 0; warnCount = 0 }
}
