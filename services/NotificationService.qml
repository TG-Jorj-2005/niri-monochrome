pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import qs.services

// Desktop notification server + toast queue + persistent history + Do Not Disturb.
Singleton {
    id: ns

    readonly property bool serverEnabled: UserConfig.data.notifications.server && UserConfig.data.notifications.shellServerApproved
    readonly property string status: usingMako ? "mako" : serverStarted ? "server" : SystemService.notificationOwnedByOther ? "other-daemon" : serverEnabled ? "initializing" : "disabled"
    // ---- Mako bridge (active while mako owns the notification service) ----
    property bool makoAvailable: false
    property bool makoDnd: false
    readonly property bool usingMako: SystemService.notificationOwnedByOther && makoAvailable
    Process { id: makoMode; command: ["makoctl", "mode"]
        stdout: StdioCollector { onStreamFinished: { ns.makoDnd = text.split("\n").map(s => s.trim()).indexOf("dnd") !== -1 } }
        onExited: code => { ns.makoAvailable = (code === 0) } }
    function refreshMako() { if (!makoMode.running) makoMode.running = true }
    Connections { target: SystemService; function onNotificationProbedChanged() { if (SystemService.notificationOwnedByOther) ns.refreshMako() } }
    Component { id: makoCmd; Process { onExited: { ns.refreshMako(); destroy() } } }
    function makoRun(args) { const p = makoCmd.createObject(ns, { command: ["makoctl"].concat(args) }); p.running = true }

    readonly property bool dnd: usingMako ? makoDnd : UserConfig.data.notifications.doNotDisturb
    function setDnd(on) {
        if (usingMako) { if (!!on !== makoDnd) makoRun(["mode", "-t", "dnd"]); return }
        UserConfig.set("notifications.doNotDisturb", !!on)
    }
    function toggleDnd() { setDnd(!dnd) }
    function dismissAll() {
        if (usingMako) { makoRun(["dismiss", "--all"]); return }
        for (const t of toasts.slice()) t.dismiss()
    }

    // Live toasts (Notification objects, tracked while shown).
    property var toasts: []
    // History entries (plain objects, persisted).
    property var history: []
    readonly property int unreadCount: history.filter(h => !h.read).length

    signal toastAdded(var n)

    // Mako (or another daemon) owning org.freedesktop.Notifications is respected: the server is only
    // instantiated after the ownership probe reports that nobody owns the name. It is never retried
    // later, so the shell cannot silently take over if the other daemon restarts.
    readonly property bool serverActive: serverEnabled && SystemService.notificationProbed && !SystemService.notificationOwnedByOther && !SystemService.notificationOwnerPid
    property bool serverStarted: false
    onServerEnabledChanged: if (!serverEnabled) serverStarted = false
    onServerActiveChanged: if (serverActive) serverStarted = true
    Loader {
        active: ns.serverEnabled && ns.serverStarted
        sourceComponent: NotificationServer {
            keepOnReload: true
            bodySupported: true
            bodyMarkupSupported: false
            actionsSupported: true
            actionIconsSupported: false
            imageSupported: true
            persistenceSupported: true
            inlineReplySupported: false
            onNotification: n => ns.incoming(n)
        }
    }

    function incoming(n) {
        n.tracked = true
        const critical = n.urgency === NotificationUrgency.Critical
        addHistory(n)
        if (UserConfig.data.notifications.toasts && (!dnd || critical)) {
            const queued = toasts.filter(t => t !== n).concat([n])
            const overflow = queued.slice(0, Math.max(0, queued.length - UserConfig.data.notifications.maxToasts))
            toasts = queued.slice(-UserConfig.data.notifications.maxToasts)
            for (const old of overflow) old.tracked = false
            toastAdded(n)
        } else {
            // Not shown: keep the object only for history purposes.
            n.tracked = false
        }
        n.closed.connect(() => removeToast(n))
    }

    function removeToast(n) {
        if (toasts.indexOf(n) === -1) return
        toasts = toasts.filter(t => t !== n)
    }
    function dismissToast(n) { n.dismiss() }
    function expireToast(n) { n.expire() }

    function timeoutFor(n) {
        const c = UserConfig.data.notifications
        if (n.urgency === NotificationUrgency.Critical) return c.criticalTimeout
        if (n.expireTimeout === 0) return 0
        if (n.expireTimeout > 0) return Math.max(1500, n.expireTimeout)
        return c.toastTimeout
    }

    // ---- History (persisted) ----
    readonly property string historyPath: Constants.stateDir + "/notifications.json"
    property bool historyLoaded: false
    FileView {
        id: histFile
        path: ns.historyPath
        atomicWrites: true
        printErrors: false
        onLoaded: {
            try { const p = JSON.parse(text()); if (Array.isArray(p)) ns.history = ns.prune(p) } catch (e) { Log.warn("NotificationService", "history invalid, resetting") }
            ns.historyLoaded = true
        }
        onLoadFailed: ns.historyLoaded = true
    }
    Timer { id: histSave; interval: 500; onTriggered: mkdir.running = true }
    Process { id: mkdir; command: ["mkdir", "-p", Constants.stateDir]; onExited: histFile.setText(JSON.stringify(ns.history) + "\n") }
    function saveHistory() { if (UserConfig.data.notifications.historyEnabled) histSave.restart() }

    property int _seq: 0
    function addHistory(n) {
        if (!UserConfig.data.notifications.historyEnabled || n.transient) return
        const c = UserConfig.data.notifications
        const entry = {
            id: Date.now() + "-" + (_seq++),
            app: n.appName || n.desktopEntry || "Application",
            desktopEntry: n.desktopEntry || "",
            icon: n.appIcon || "",
            summary: String(n.summary || "").substring(0, 200),
            body: c.storeBodies ? String(n.body || "").substring(0, 500) : "",
            urgency: n.urgency,
            time: Date.now(),
            read: false
        }
        history = prune([entry].concat(history))
        saveHistory()
    }
    function prune(list) {
        const c = UserConfig.data.notifications
        const cutoff = c.historyRetentionDays > 0 ? Date.now() - c.historyRetentionDays * 86400000 : 0
        return list.filter(h => h && h.time >= cutoff).slice(0, c.historyMax)
    }
    function removeHistory(id) { history = history.filter(h => h.id !== id); saveHistory() }
    function clearHistory() { history = []; saveHistory() }
    function clearApp(app) { history = history.filter(h => h.app !== app); saveHistory() }
    function markAllRead() { if (unreadCount === 0) return; history = history.map(h => Object.assign({}, h, { read: true })); saveHistory() }

    // Grouped by application, newest first.
    function grouped() {
        const groups = {}, order = []
        for (const h of history) {
            if (!groups[h.app]) { groups[h.app] = { app: h.app, icon: h.icon, desktopEntry: h.desktopEntry, items: [] }; order.push(h.app) }
            groups[h.app].items.push(h)
        }
        return order.map(a => groups[a])
    }

    Timer { interval: 3600000; repeat: true; running: true; onTriggered: { const p = ns.prune(ns.history); if (p.length !== ns.history.length) { ns.history = p; ns.saveHistory() } } }

    // Safe plain-text rendering of untrusted bodies: strip markup, collapse whitespace.
    function plain(text) {
        return String(text || "").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/\s+/g, " ").trim()
    }
    function timeLabel(t) {
        const d = new Date(t), now = new Date()
        const same = d.toDateString() === now.toDateString()
        return same ? Qt.formatTime(d, "HH:mm") : Qt.formatDateTime(d, "d MMM HH:mm")
    }
}
