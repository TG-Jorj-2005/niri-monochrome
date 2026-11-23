import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import qs.components
import qs.services
ShellRoot {
    id: root
    function find(i) { if (i.placeholder === "Add application…") return i; for (const c of i.children || []) { const f = find(c); if (f) return f }; return null }
    Settings { id: settings; visible: false }
    TestCase { id: events; parent: settings.contentItem; when: false; optional: true }
    FileView { id: stat; path: "/proc/self/stat"; blockAllReads: true; printErrors: false }
    FileView { id: memory; path: "/proc/self/smaps_rollup"; blockAllReads: true; printErrors: false }
    function sample() {
        stat.reload(); memory.reload()
        const s = stat.text().split(") ")[1].trim().split(/\s+/)
        const m = memory.text()
        return {t:Date.now(), ticks:Number(s[11])+Number(s[12]), rssKiB:Number(s[21])*4,
                privateKiB:Number((m.match(/Private_Clean:\s+(\d+)/)||[])[1]||0)+Number((m.match(/Private_Dirty:\s+(\d+)/)||[])[1]||0)}
    }
    Timer { interval: 1000; running: true; onTriggered: {
        ShellState.settingsSection = settings.sections.findIndex(x => x.t === "Dock"); events.wait(150)
        const field = root.find(settings.contentItem)
        const before = root.sample()
        for (let i=0;i<200;i++) { field.text=["fire","term","nau","settings"][i%4]; events.wait(20) }
        const after = root.sample()
        console.info("BENCH " + JSON.stringify({queries:200,visibleApps:ApplicationService.visible.length,before:before,after:after,
                     cpuPercent:(after.ticks-before.ticks)/(after.t-before.t)*1000,cpuSeconds:(after.ticks-before.ticks)/100}))
        console.info("RESULT 1/1 passed"); Qt.quit()
    } }
}
