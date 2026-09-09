import AppKit
import SwiftUI

/// 需要 AppKit 运行环境的检查：视图能否布局、钉图记账是否正确。
/// ponytail: 只看控件树和状态，不比对像素。视觉效果还是得靠截图。
@MainActor func check() {
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)

    var bad: [String] = []

    // --- SnipView 布局 ---
    let snip = NSHostingView(rootView: SnipView().environmentObject(Settings()))
    snip.frame = NSRect(x: 0, y: 0, width: 600, height: 560)
    let w1 = NSWindow(contentRect: snip.frame, styleMask: [.titled],
                      backing: .buffered, defer: false)
    w1.contentView = snip
    snip.layoutSubtreeIfNeeded()

    var buttons = 0
    func countButtons(_ v: NSView) {
        if v is NSButton { buttons += 1 }
        v.subviews.forEach(countButtons)
    }
    countButtons(snip)
    if buttons < 2 { bad.append("SnipView 按钮少了，应有截图和全部关闭") }
    if snip.fittingSize.width < 100 { bad.append("SnipView 布局塌了: \(snip.fittingSize)") }

    // --- HostsView 能否构建并布局（不崩、能找到列表）---
    // ponytail: 这里测不出"detail 栏被压成一条缝"那个 bug —— 它只在
    // NavigationSplitView 的异步布局里出现，离屏 host 复现不了。布局靠截图人眼确认。
    let hosts = NSHostingView(rootView: HostsView().environmentObject(HostsStore()))
    hosts.frame = NSRect(x: 0, y: 0, width: 660, height: 560)
    let w2 = NSWindow(contentRect: hosts.frame, styleMask: [.titled],
                      backing: .buffered, defer: false)
    w2.contentView = hosts
    hosts.layoutSubtreeIfNeeded()

    var scrolls: [NSScrollView] = []
    func findScroll(_ v: NSView) {
        if let s = v as? NSScrollView { scrolls.append(s) }
        v.subviews.forEach(findScroll)
    }
    findScroll(hosts)
    if scrolls.isEmpty { bad.append("HostsView 里找不到方案列表") }

    // --- 钉图记账 ---
    func img(_ c: NSColor) -> NSImage {
        let i = NSImage(size: NSSize(width: 200, height: 100))
        i.lockFocus(); c.setFill(); NSRect(x: 0, y: 0, width: 200, height: 100).fill(); i.unlockFocus()
        return i
    }
    Snip.show(img(.red)); Snip.show(img(.green)); Snip.show(img(.blue))
    if Snip.pinned.count != 3 { bad.append("show 没记账: \(Snip.pinned.count)") }

    let mid = Snip.pinned[1]
    Snip.close(mid)
    if Snip.pinned.count != 2 { bad.append("close 后数量不对: \(Snip.pinned.count)") }
    if Snip.pinned.contains(where: { $0 === mid }) { bad.append("close 删错了对象") }
    if mid.isVisible { bad.append("close 后窗口还显示着") }

    Snip.closeAll()
    if !Snip.pinned.isEmpty { bad.append("closeAll 没清空") }
    Snip.close(mid)   // 重复 close 不能崩
    if !Snip.pinned.isEmpty { bad.append("重复 close 出问题") }

    // --- 钉图必须能拖动：NSImageView 会吃掉鼠标事件导致拖不动 ---
    Snip.show(img(.systemTeal))
    if let w = Snip.pinned.first, let cv = w.contentView {
        if !w.isMovableByWindowBackground { bad.append("窗口没开启背景拖动") }
        if !cv.mouseDownCanMoveWindow { bad.append("contentView 吃掉拖动事件，图拖不动") }
        let hit = cv.hitTest(NSPoint(x: cv.bounds.midX, y: cv.bounds.midY))
        if let hit, !hit.mouseDownCanMoveWindow {
            bad.append("命中的视图 \(type(of: hit)) 不允许拖动窗口")
        }
        let before = w.frame.origin
        w.setFrameOrigin(CGPoint(x: before.x + 60, y: before.y + 40))
        if abs(w.frame.origin.x - before.x - 60) > 1 { bad.append("窗口移不动") }

        // --- 左上角关闭按钮 ---
        // 它是唯一不允许拖窗口的子视图
        if let btn = cv.subviews.first(where: { !$0.mouseDownCanMoveWindow }) {
            if btn.frame.minX > 12 { bad.append("关闭按钮不在左边: x=\(btn.frame.minX)") }
            let gap = cv.bounds.height - btn.frame.maxY
            if gap > 12 || gap < 0 { bad.append("关闭按钮不在顶部: 距顶 \(gap)") }

            // 按钮位置不能被图片抢走，否则点不到
            let p = NSPoint(x: btn.frame.midX, y: btn.frame.midY)
            if let hit = cv.hitTest(cv.convert(p, to: cv.superview)), hit.mouseDownCanMoveWindow {
                bad.append("关闭按钮被图片抢走了，点不到")
            }

            // 窗口改尺寸后按钮要跟到新的左上角
            w.setContentSize(NSSize(width: 800, height: 600))
            cv.layoutSubtreeIfNeeded()
            let gap2 = w.contentView!.bounds.height - btn.frame.maxY
            if gap2 > 12 || gap2 < 0 { bad.append("缩放后关闭按钮没跟上: 距顶 \(gap2)") }

            // 点一下要真的关掉
            let n = Snip.pinned.count
            let inWindow = btn.convert(NSPoint(x: btn.bounds.midX, y: btn.bounds.midY), to: nil)
            if let ev = NSEvent.mouseEvent(with: .leftMouseUp, location: inWindow,
                                          modifierFlags: [], timestamp: 0,
                                          windowNumber: w.windowNumber, context: nil,
                                          eventNumber: 0, clickCount: 1, pressure: 1) {
                btn.mouseUp(with: ev)
            }
            if Snip.pinned.count != n - 1 { bad.append("点关闭按钮没关掉窗口") }
        } else {
            bad.append("找不到左上角关闭按钮")
        }
    } else {
        bad.append("钉图窗口没建立")
    }
    Snip.closeAll()

    // --- 全局快捷键注册 ---
    if !HotKey.shared.register(.default, action: {}) { bad.append("默认热键注册失败") }
    if !HotKey.shared.register(.default, action: {}) { bad.append("重复注册失败") }
    let bare = HotKeySpec(keyCode: 0, modifierRaw: 0)
    if HotKey.shared.register(bare, action: {}) { bad.append("裸按键竟然注册成功") }
    HotKey.shared.unregister()
    HotKey.shared.unregister()   // 重复注销不能崩

    // --- 滚动：无权限时必须优雅失败，不能崩也不能谎报成功 ---
    let tap = ScrollTap.shared
    if !ScrollTap.hasPermission {
        if tap.start() { bad.append("没权限竟然报成功了") }
        if tap.isRunning { bad.append("没权限却自称在运行") }
    }
    // 两个开关都关时要停掉，不白占系统资源
    var offTuning = ScrollTuning.default
    offTuning.reverse = false; offTuning.smooth = false
    tap.update(offTuning)
    if tap.isRunning { bad.append("开关全关了 tap 还在跑") }
    tap.stop()
    tap.stop()   // 重复 stop 不能崩

    // --- 滚动面板能构建 ---
    let sv = NSHostingView(rootView: ScrollSettingsView().environmentObject(Settings()))
    sv.frame = NSRect(x: 0, y: 0, width: 600, height: 560)
    let w3 = NSWindow(contentRect: sv.frame, styleMask: [.titled],
                      backing: .buffered, defer: false)
    w3.contentView = sv
    sv.layoutSubtreeIfNeeded()
    var sliders = 0, toggles = 0
    func countControls(_ v: NSView) {
        // SwiftUI 的 Toggle 在 macOS 上渲染成 NSButton 的 checkbox，不是 NSSwitch
        if v is NSSlider { sliders += 1 }
        if let b = v as? NSButton, b.allowsMixedState || b.bezelStyle == .regularSquare
            || String(describing: type(of: v)).contains("FocusRing") { toggles += 1 }
        v.subviews.forEach(countControls)
    }
    countControls(sv)
    if toggles < 3 { bad.append("滚动面板开关不够: \(toggles)") }
    if sliders < 2 { bad.append("滚动面板滑块不够: \(sliders)") }

    if bad.isEmpty { print("ui pass"); exit(0) }
    bad.forEach { print("FAIL: \($0)") }
    exit(1)
}

DispatchQueue.main.async { check() }
NSApplication.shared.run()
