import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import Quickshell.Io
import qs.config
import qs.services
import qs.components.ui

// Real Panel rendering over private synthetic backgrounds; never changes desktop wallpaper.
ShellRoot {
    id: root
    property int passed: 0
    property int failed: 0
    function check(name, ok) { if (ok) passed++; else failed++; console.info((ok ? "PASS " : "FAIL ") + name) }
    function linear(c) { return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4) }
    function luminance(c) { return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b) }
    function contrast(a, b) { const x = luminance(a), y = luminance(b); return (Math.max(x,y) + 0.05) / (Math.min(x,y) + 0.05) }
    function frame(name) {
        events.wait(80)
        const img = events.grabImage(scene)
        const out = Quickshell.env("NM_GLASS_EVIDENCE")
        if (out) img.save(out + "/" + name + ".png")
        return img
    }
    Window {
        id: window
        visible: true
        width: 1100; height: 300
        Rectangle {
            id: scene
            anchors.fill: parent
            color: "#111214"
            Row {
                Repeater {
                    id: columns
                    model: ["#080808", "#303030", "#808080", "#fafafa", "#000000"]
                    delegate: Rectangle {
                        required property string modelData
                        required property int index
                        width: 220; height: 300; color: modelData
                        Repeater {
                            model: index === 4 ? 165 : 0
                            Rectangle { required property int index; x: (index % 11) * 20; y: Math.floor(index / 11) * 20
                                width: 20; height: 20; color: ((index % 11) + Math.floor(index / 11)) % 2 ? "white" : "black" }
                        }
                        Label { x: 12; y: 8; text: ["Almost black", "Dark gray", "Medium gray", "Almost white", "B/W pattern"][parent.index]
                            color: parent.index === 2 || parent.index === 3 ? "black" : "white" }
                        Panel {
                            x: 10; y: 42; width: 200; height: 240
                            Label { x: 14; y: 14; text: "Primary text" }
                            Label { x: 14; y: 44; text: "Secondary text"; secondary: true }
                            SectionTitle { x: 14; y: 74; text: "SECTION TITLE" }
                            MonoTextField { x: 12; y: 106; width: 176; placeholder: "Search applications" }
                            MonoSlider { x: 12; y: 166; width: 176; value: 0.6 }
                            Label { x: 14; y: 204; text: "Inactive control"; color: Theme.textDisabled }
                        }
                    }
                }
            }
        }
    }
    TestCase { id: events; parent: scene; when: false; optional: true }
    FileView { id: saved; path: UserConfig.path; blockAllReads: true; printErrors: false }
    FileView { id: rules; path: AppearanceService.path; blockAllReads: true; printErrors: false }
    Process { id: stamp; command: ["stat", "-c", "%y", AppearanceService.path]
        property string value: ""
        stdout: StdioCollector { onStreamFinished: stamp.value = text.trim() } }
    Timer { interval: 800; running: true; onTriggered: {
        AppearanceService.path // initialize actual singleton and generator
        if (Quickshell.env("NM_GLASS_RESTORE") === "1") {
            const a = UserConfig.data.appearance
            events.wait(450); rules.reload()
            root.check("new process restores appearance and generated rules", UserConfig.loaded && a.glassEnabled && a.panelOpacity === 0.92 && a.panelRadius === 18 && a.shadowStrength === 0.5 && a.reduceMotion && a.animationIntensity === 1.2 && !Theme.motionEnabled && rules.text() === AppearanceService.text())
            console.info("RESULT " + root.passed + "/" + (root.passed + root.failed) + " passed")
            Qt.quit(); return
        }
        root.check("missing appearance config safely initializes defaults", UserConfig.loaded && UserConfig.data.appearance.panelOpacity === 0.92)
        let d = UserConfig.deepClone(UserConfig.data)
        d.appearance.panelOpacity = -1
        let lo = UserConfig.validate(d).appearance.panelOpacity
        d.appearance.panelOpacity = 2
        root.check("opacity lower and upper bounds", lo === 0.82 && UserConfig.validate(d).appearance.panelOpacity === 1)
        let valid = true
        for (const bad of ["0.5", null, false, {}, NaN, Infinity]) {
            d.appearance.panelOpacity = bad
            valid = valid && UserConfig.validate(d).appearance.panelOpacity === 0.92
        }
        root.check("invalid opacity types recover to default", valid)
        d.appearance.panelRadius = 100; d.appearance.shadowStrength = 2; d.appearance.glassEnabled = "false"
        d = UserConfig.validate(d)
        root.check("geometry shadow and glass types bounded", d.appearance.panelRadius === 24 && d.appearance.shadowStrength === 0.65 && d.appearance.glassEnabled === true)
        UserConfig.set("appearance.panelOpacity", 0.82)
        const img = root.frame("glass-minimum")
        let pixels = true, text = true, headings = true, icons = true, focus = true
        for (let i = 0; i < 5; i++) {
            const p = columns.itemAt(i).children.find(c => c.width === 200)
            const background = img.pixel(i * 220 + 30, 240)
            const wall = i === 4 ? 1 : [8,48,128,250][i] / 255
            const expected = wall * 0.18 * 255
            pixels = pixels && Math.abs(img.red(i * 220 + 30, 240) - expected) <= 2
            text = text && root.contrast(Theme.textSecondary, background) >= 4.5
            headings = headings && root.contrast(p.children.find(c => c.text === "SECTION TITLE").color, background) >= 4.5
            icons = icons && root.contrast(Theme.silverMuted, background) >= 3
            // Actual slider's focus outline color; do not assume it matches button focus.
            const slider = p.children.find(c => c.frac !== undefined)
            const outline = slider.children.find(c => c.border && c.radius === Theme.radiusControl)
            focus = focus && root.contrast(outline.border.color, background) >= 3
            console.info("CONTRAST " + i + " secondary=" + root.contrast(Theme.textSecondary,background).toFixed(3) + " heading=" + root.contrast(p.children.find(c => c.text === "SECTION TITLE").color,background).toFixed(3))
        }
        root.check("actual Panel alpha composition across five backgrounds", pixels)
        root.check("secondary text contrast across five rendered backgrounds", text)
        root.check("actual section headings readable over bright glass", headings)
        root.check("muted icons contrast over bright glass", icons)
        root.check("slider focus outline contrast over bright glass", focus)
        const input = columns.itemAt(0).children.find(c => c.width === 200).children.find(c => c.placeholder !== undefined)
        root.check("enabled placeholder readable on opaque input", root.contrast(input.input.children.find(c => c.text === "Search applications").color, input.color) >= 4.5)
        UserConfig.set("appearance.panelOpacity", 0.92); root.frame("glass-default")
        UserConfig.set("appearance.glassEnabled", false); events.wait(500)
        const opaque = root.frame("opaque")
        root.check("glass off renders opaque fallback across backgrounds", Theme.surface.a === 1 && [0,1,2,3,4].every(i => {
            const x = i * 220 + 30
            return Math.abs(opaque.red(x,240) - 27) <= 1 && Math.abs(opaque.green(x,240) - 29) <= 1
                && Math.abs(opaque.blue(x,240) - 31) <= 1
        }))
        rules.reload()
        const off = rules.text()
        root.check("glass off disables both compositor blur rules", (off.match(/blur false/g) || []).length === 2 && !off.includes("blur true"))
        UserConfig.set("appearance.glassEnabled", true)
        UserConfig.set("appearance.panelRadius", 18)
        UserConfig.set("appearance.shadowStrength", 0.5)
        UserConfig.set("appearance.reduceMotion", true)
        UserConfig.set("appearance.animationIntensity", 1.2)
        events.wait(650); rules.reload(); saved.reload()
        const on = rules.text()
        root.check("generated blur rules anchored to bar and dock only", (on.match(/layer-rule/g)||[]).length === 2 && on.includes('namespace="^nm-bar$"') && on.includes('namespace="^nm-dock$"') && (on.match(/blur true/g)||[]).length === 2 && (on.match(/saturation 0/g)||[]).length === 2 && !on.includes("nm-overlay"))
        root.check("appearance geometry and shadow propagate to generated KDL", on.includes("geometry-corner-radius 18") && on.includes('color "#00000080"'))
        const persisted = saved.text()
        const a = JSON.parse(persisted).appearance
        root.check("appearance preferences saved to private JSON", a.glassEnabled && a.panelRadius === 18 && a.shadowStrength === 0.5 && a.reduceMotion && a.animationIntensity === 1.2)
        UserConfig.data = UserConfig.deepClone(UserConfig.defaults)
        UserConfig.applyText(persisted)
        root.check("file reload restores nondefault appearance and motion", UserConfig.data.appearance.panelRadius === 18 && Theme.radiusPanel === 18 && !Theme.motionEnabled && Theme.durFast === 0 && Theme.surface.a < 1)
        const before = JSON.stringify(UserConfig.data)
        UserConfig.applyText("{invalid json")
        root.check("corrupt JSON preserves last valid appearance", JSON.stringify(UserConfig.data) === before && UserConfig.lastError !== "")
        UserConfig.applyText(persisted)
        stamp.running = true; events.wait(150); const first = stamp.value
        AppearanceService.write(); AppearanceService.write(); events.wait(300)
        stamp.value = ""; stamp.running = true; events.wait(150)
        root.check("unchanged appearance does not rewrite KDL", first !== "" && first === stamp.value)
        console.info("RESULT " + root.passed + "/" + (root.passed + root.failed) + " passed")
        Qt.quit()
    } }
}
