import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components

// Actual Settings/Dock binding, private installed desktop entries and persisted config.
ShellRoot {
    id: root
    property int passed: 0
    property int failed: 0
    property int launches: 0
    function check(name, ok) { if (ok) passed++; else failed++; console.info((ok ? "PASS " : "FAIL ") + name) }
    function find(item, predicate) {
        if (predicate(item)) return item
        for (const child of item.children || []) { const found = find(child, predicate); if (found) return found }
        return null
    }
    function until(predicate) { for (let i = 0; i < 80 && !predicate(); i++) events.wait(50); return predicate() }
    function ids(rows) { return rows.map(e => e.id).join(",") }
    Settings { id: settings; visible: false }
    TestCase { id: events; parent: settings.contentItem; when: false; optional: true }
    Connections { target: ApplicationService; function onLaunched(name) { root.launches++ } }
    FileView { id: installed; path: Quickshell.env("XDG_DATA_HOME") + "/applications/nm-task6-gamma.desktop"; printErrors: false }
    FileView { id: saved; path: UserConfig.path; blockAllReads: true; printErrors: false }
    Timer { interval: 800; running: true; onTriggered: {
        ShellState.settingsSection = settings.sections.findIndex(x => x.t === "Dock")
        events.wait(100)
        const field = root.find(settings.contentItem, x => x.placeholder === "Add application…")
        // The results column follows the field; the earlier column contains saved favorites.
        const resultColumn = field.parent.children[field.parent.children.indexOf(field) + 1]
        const repeater = resultColumn.children.find(x => typeof x.itemAt === "function")
        root.check("actual Dock search controls loaded", !!field && !!repeater)
        root.check("real private desktop entries loaded", root.until(() => ApplicationService.visible.some(e => e.id === "nm-task6-alpha") && ApplicationService.visible.some(e => e.id === "nm-task6-beta")))
        if (Quickshell.env("NM_SETTINGS_RESTORE") === "1") {
            field.text = "NM Task6 Alpha"; events.wait(50)
            root.check("fresh process restores favorite and filters actual Settings results", UserConfig.data.dock.favorites.indexOf("nm-task6-alpha") >= 0 && repeater.count === 0)
            console.info("RESULT " + root.passed + "/" + (root.passed + root.failed) + " passed"); Qt.quit(); return
        }
        root.check("empty Dock query has no results", field.text === "" && repeater.count === 0 && !resultColumn.visible)
        const cached = ApplicationService.search("NM Task6 Beta", 6)
        root.check("launcher memoization reuses the same result", ApplicationService.search("NM Task6 Beta", 6) === cached)
        field.text = "NM Task6 Alpha"; events.wait(40)
        root.check("first query returns matching installed application", repeater.count === 1 && repeater.itemAt(0).modelData.id === "nm-task6-alpha")
        root.check("Settings query does not mutate launcher cache", ApplicationService._lastQuery === "NM Task6 Beta" && ApplicationService._lastResult === cached)
        field.text = "  NM Task6 Beta  "; events.wait(40)
        root.check("different query and surrounding whitespace produce correct result", repeater.count === 1 && repeater.itemAt(0).modelData.id === "nm-task6-beta")
        field.text = "no matching nm task6 xyz"; events.wait(20)
        root.check("missing query produces empty results", repeater.count === 0)
        field.text = ""; events.wait(20)
        root.check("clearing query clears and hides result rows", repeater.count === 0 && !resultColumn.visible)
        for (let i = 0; i < 80; i++) field.text = i % 2 ? "NM Task6 Alpha" : "NM Task6 Beta"
        events.wait(40)
        root.check("rapid distinct queries settle to latest results", repeater.count === 1 && repeater.itemAt(0).modelData.id === "nm-task6-alpha")
        root.check("rapid Settings queries preserve useful memoization", ApplicationService._lastResult === cached && ApplicationService._lastQuery === "NM Task6 Beta")
        ApplicationService.search("", 8)
        StateStore.set("recentApps", ["nm-task6-beta"])
        root.check("recent-app changes invalidate memoized launcher search", ApplicationService._lastQuery === "\u0000" && ApplicationService.search("", 8)[0].id === "nm-task6-beta")
        ApplicationService.search("NM Task6 Alpha", 6)
        UserConfig.set("launcher.showDescriptions", !UserConfig.data.launcher.showDescriptions)
        root.check("configuration changes invalidate cache", ApplicationService._lastQuery === "\u0000")
        field.text = "NM Task6 Gamma"; events.wait(30)
        root.check("not-yet-installed application is absent", repeater.count === 0)
        ApplicationService.search("NM Task6 Gamma", 6)
        installed.setText("[Desktop Entry]\nType=Application\nName=NM Task6 Gamma\nExec=true\nIcon=application-x-executable\n")
        root.check("supported DesktopEntries file watcher refreshes actual Settings results", root.until(() => repeater.count === 1 && repeater.itemAt(0).modelData.id === "nm-task6-gamma"))
        root.check("installed-app update invalidates launcher cache", ApplicationService._lastQuery === "\u0000" && ApplicationService.search("NM Task6 Gamma", 6)[0].id === "nm-task6-gamma")
        root.check("visible application IDs stay unique", new Set(ApplicationService.visible.map(e => e.id)).size === ApplicationService.visible.length)
        field.text = "NM Task6 Alpha"; events.wait(30)
        const row = repeater.itemAt(0)
        const click = row.children.find(x => typeof x.clicked === "function" && x.acceptedButtons !== undefined)
        click.clicked(null); events.wait(350)
        root.check("actual favorite selection adds once and clears query", UserConfig.data.dock.favorites.filter(x => x === "nm-task6-alpha").length === 1 && field.text === "" && repeater.count === 0)
        field.text = "NM Task6 Alpha"; events.wait(30)
        root.check("existing favorite is excluded reactively", repeater.count === 0)
        saved.reload()
        root.check("favorite is persisted in private configuration", JSON.parse(saved.text()).dock.favorites.indexOf("nm-task6-alpha") >= 0)
        root.check("search and favorite selection never launch applications", root.launches === 0)
        console.info("RESULT " + root.passed + "/" + (root.passed + root.failed) + " passed"); Qt.quit()
    } }
}
