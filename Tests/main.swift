import Foundation
import AppKit
import Carbon.HIToolbox

// ---------- HostsFile ----------

let sys = """
##
# Host Database
##
127.0.0.1       localhost
::1             localhost
"""

// 1. 干净文件原样返回
assert(HostsFile.base(from: sys) == sys)

// 2. 剥掉 SwitchHosts 块（无结束标记，之后全归它）
let withSW = sys + "\n\n" + HostsFile.swMarker + "\n\n127.0.0.1  a.local\n127.0.0.1  b.local"
assert(HostsFile.base(from: withSW) == sys, HostsFile.base(from: withSW))

// 3. 剥掉自己的块，块后手写的内容必须保留
let withUs = sys + "\n\n" + HostsFile.marker + "\n# x\n127.0.0.1 x.local\n"
    + HostsFile.markerEnd + "\n10.0.0.1  keepme"
let stripped = HostsFile.base(from: withUs)
assert(stripped.contains("10.0.0.1  keepme"), stripped)
assert(!stripped.contains("x.local"), stripped)
assert(stripped.hasPrefix(sys), stripped)

// 4. 反复 render+base 不累积空行（幂等），有手写内容时也要稳定
let once = HostsFile.render(base: sys, blocks: [("shark", "127.0.0.1 shark.local")])
assert(HostsFile.base(from: once) == sys, HostsFile.base(from: once))
let twice = HostsFile.render(base: HostsFile.base(from: once), blocks: [("shark", "127.0.0.1 shark.local")])
assert(once == twice)

var cur = withUs
for _ in 0..<5 {
    cur = HostsFile.render(base: HostsFile.base(from: cur), blocks: [("shark", "127.0.0.1 shark.local")])
}
let again = HostsFile.render(base: HostsFile.base(from: cur), blocks: [("shark", "127.0.0.1 shark.local")])
assert(cur == again, "反复应用后内容还在变")
assert(cur.contains("10.0.0.1  keepme"))

// 5. 关掉全部方案后，回到系统原样
let none = HostsFile.render(base: sys, blocks: [])
assert(HostsFile.base(from: none) == sys)
assert(none.contains("localhost"))

// 6. 真实 /etc/hosts 不能被吃掉系统行
if let real = try? String(contentsOfFile: "/etc/hosts", encoding: .utf8) {
    let b = HostsFile.base(from: real)
    assert(b.contains("127.0.0.1"), "base 把 localhost 弄丢了")
    assert(b.contains("broadcasthost"))
    assert(!b.contains("SWITCHHOSTS"))
    assert(!b.contains("DEVKIT"))
}

// ---------- PinGeometry ----------

let screen = CGSize(width: 1440, height: 900)

// 7. Retina 图要除以缩放因子
let s1 = PinGeometry.initialSize(pixels: CGSize(width: 400, height: 300),
                                 scaleFactor: 2, screen: screen)
assert(s1 == CGSize(width: 200, height: 150), "\(s1)")

// 8. 超宽的图缩到屏幕一半，且宽高比不变
let s2 = PinGeometry.initialSize(pixels: CGSize(width: 4000, height: 2000),
                                 scaleFactor: 2, screen: screen)
assert(s2.width == 720, "\(s2)")
assert(abs(s2.height / s2.width - 0.5) < 0.001, "宽高比变了: \(s2)")

// 9. 摆放不能超出屏幕
let vis = CGRect(x: 0, y: 25, width: 1440, height: 875)
let sz = CGSize(width: 200, height: 150)
let o1 = PinGeometry.origin(mouse: CGPoint(x: 720, y: 500), size: sz, visible: vis)
assert(o1 == CGPoint(x: 620, y: 425), "\(o1)")

// 贴右上角时被夹住
let o2 = PinGeometry.origin(mouse: CGPoint(x: 1440, y: 900), size: sz, visible: vis)
assert(o2.x + sz.width <= vis.maxX, "\(o2) 超出右边")
assert(o2.y + sz.height <= vis.maxY, "\(o2) 超出上边")

// 贴左下角时被夹住
let o3 = PinGeometry.origin(mouse: CGPoint(x: 0, y: 0), size: sz, visible: vis)
assert(o3.x >= vis.minX && o3.y >= vis.minY, "\(o3) 跑到屏幕外")

// 图比屏幕还大时也不能跑到负坐标
let huge = CGSize(width: 2000, height: 1500)
let o4 = PinGeometry.origin(mouse: CGPoint(x: 700, y: 400), size: huge, visible: vis)
assert(o4.x >= vis.minX && o4.y >= vis.minY, "\(o4) 大图跑到屏幕外")

// 10. 缩放夹在 0.1~8，宽高比保持
let base = CGSize(width: 800, height: 400)
let z1 = PinGeometry.zoom(base: base, scaleFactor: 2, current: 1, deltaY: 100)
assert(z1.scale == 1.5, "\(z1.scale)")
assert(abs(z1.size.height / z1.size.width - 0.5) < 0.001, "宽高比变了")

let zMax = PinGeometry.zoom(base: base, scaleFactor: 2, current: 8, deltaY: 10000)
assert(zMax.scale == 8, "上限没夹住: \(zMax.scale)")
let zMin = PinGeometry.zoom(base: base, scaleFactor: 2, current: 0.1, deltaY: -10000)
assert(zMin.scale == 0.1, "下限没夹住: \(zMin.scale)")

// 11. 缩放 1 倍时应等于初始尺寸
let z0 = PinGeometry.zoom(base: base, scaleFactor: 2, current: 1, deltaY: 0)
assert(z0.size == CGSize(width: 400, height: 200), "\(z0.size)")

// ---------- HotKeySpec ----------

// 12. 默认快捷键是 ⌘⇧2，合法
assert(HotKeySpec.default.isValid)
assert(HotKeySpec.default.display == "⇧⌘2", HotKeySpec.default.display)

// 13. 没有修饰键不合法（否则会抢掉普通打字）
let bare = HotKeySpec(keyCode: UInt32(kVK_ANSI_A), modifierRaw: 0)
assert(!bare.isValid, "裸按键竟然合法")

// 只有 capsLock 之类的也不算
let caps = HotKeySpec(keyCode: UInt32(kVK_ANSI_A),
                      modifierRaw: NSEvent.ModifierFlags.capsLock.rawValue)
assert(!caps.isValid, "capsLock 不该算修饰键")

// 14. 四个修饰键都要正确翻译成 Carbon 常量
let all = HotKeySpec(keyCode: UInt32(kVK_ANSI_X),
                     modifierRaw: NSEvent.ModifierFlags([.command, .shift, .option, .control]).rawValue)
assert(all.carbonModifiers == UInt32(cmdKey | shiftKey | optionKey | controlKey), "\(all.carbonModifiers)")
assert(all.display == "⌃⌥⇧⌘X", all.display)

let ctrlOnly = HotKeySpec(keyCode: UInt32(kVK_Space),
                          modifierRaw: NSEvent.ModifierFlags.control.rawValue)
assert(ctrlOnly.carbonModifiers == UInt32(controlKey), "\(ctrlOnly.carbonModifiers)")
assert(ctrlOnly.display == "⌃空格", ctrlOnly.display)

// 15. 存下来再读回来要一模一样
let enc = try! JSONEncoder().encode(all)
let dec = try! JSONDecoder().decode(HotKeySpec.self, from: enc)
assert(dec == all, "存取后变了: \(dec)")

// 16. 认不出的键码不能崩，给个兜底名字
assert(HotKeySpec.keyName(9999) == "键码9999", HotKeySpec.keyName(9999))

// ---------- ScrollCore ----------

// 17. 触控板 vs 鼠标要能分辨
assert(ScrollFilter.source(isContinuous: true) == .trackpad)
assert(ScrollFilter.source(isContinuous: false) == .mouse)

// 18. mouseOnly 开启时不碰触控板
var t = ScrollTuning.default
assert(t.mouseOnly, "默认应该只管鼠标，别动触控板手感")
assert(ScrollFilter.shouldHandle(source: .mouse, tuning: t))
assert(!ScrollFilter.shouldHandle(source: .trackpad, tuning: t), "触控板不该被接管")

// 关掉 mouseOnly 后两者都管
t.mouseOnly = false
assert(ScrollFilter.shouldHandle(source: .trackpad, tuning: t))

// 19. 反转和平滑都关掉时不该拦事件（省电，也少一层风险）
var off = ScrollTuning.default
off.reverse = false; off.smooth = false
assert(!ScrollFilter.shouldHandle(source: .mouse, tuning: off))
off.reverse = true
assert(ScrollFilter.shouldHandle(source: .mouse, tuning: off))

// 20. 参数越界要夹住，否则滚动会卡死或飞出去
var wild = ScrollTuning.default
wild.step = 99999; wild.damping = 5
assert(wild.sanitized.step == 300, "\(wild.sanitized.step)")
assert(wild.sanitized.damping == 0.95, "\(wild.sanitized.damping)")
wild.step = -10; wild.damping = -1
assert(wild.sanitized.step == 5)
assert(wild.sanitized.damping == 0.1)

// 21. 平滑积分器：总量守恒，不能凭空多滚或少滚
var sc0 = SmoothScroller()
assert(sc0.isIdle)
sc0.push(100)
var total = 0.0
var frames = 0
while !sc0.isIdle && frames < 1000 {
    total += sc0.next(damping: 0.75)
    frames += 1
}
assert(abs(total - 100) < 0.01, "总量不守恒: \(total)")
assert(frames > 3, "只用了 \(frames) 帧，根本没平滑")
assert(frames < 200, "拖了 \(frames) 帧，太久了")

// 22. 第一帧要立刻有反馈，不能等
var sc1 = SmoothScroller()
sc1.push(100)
let first = sc1.next(damping: 0.75)
assert(first > 0, "第一帧没动，会觉得卡顿")
assert(first < 100, "第一帧就吐完了，等于没平滑")

// 23. damping 越大滑得越久
func framesToStop(_ d: Double) -> Int {
    var x = SmoothScroller(); x.push(100)
    var n = 0
    while !x.isIdle && n < 5000 { _ = x.next(damping: d); n += 1 }
    return n
}
assert(framesToStop(0.9) > framesToStop(0.5), "damping 大反而更快停？")

// 24. 反向滚动要抵消掉残留，不能继续往原方向滑
var sc2 = SmoothScroller()
sc2.push(100)
_ = sc2.next(damping: 0.75)
sc2.push(-200)
assert(sc2.remaining < 0, "反向滚动后仍在往正方向滑: \(sc2.remaining)")

// 25. 同向连续滚动要叠加（快速滚多下应该滚得更远）
var sc3 = SmoothScroller()
sc3.push(50); sc3.push(50)
assert(abs(sc3.remaining - 100) < 0.01, "\(sc3.remaining)")

// 26. 空转不能吐出数值，也不能卡在非零残留
var sc4 = SmoothScroller()
assert(sc4.next(damping: 0.75) == 0)
sc4.push(0.001)   // 小于 epsilon
assert(sc4.next(damping: 0.75) == 0 || sc4.isIdle)
assert(sc4.isIdle, "残留没清干净")

// ---------- SchemeLookup（删除方案导致崩溃的那个 bug）----------

let sA = Scheme(name: "a", content: "1")
let sB = Scheme(name: "b", content: "2")
let sC = Scheme(name: "c", content: "3")
let list3 = [sA, sB, sC]

// 27. 正常查找
assert(SchemeLookup.find(sB.id, in: list3)?.name == "b")
assert(SchemeLookup.index(sC.id, in: list3) == 2)

// 28. 关键：选中的方案被删掉后，必须返回 nil 而不是旧下标
//     以前这里用 firstIndex 捕获下标，删完数组变短就越界崩溃
let afterDelete = [sA, sB]          // sC 被删了
assert(SchemeLookup.find(sC.id, in: afterDelete) == nil, "删掉的方案还能查到")
assert(SchemeLookup.index(sC.id, in: afterDelete) == nil, "删掉的方案还返回下标，会越界")

// 29. 删掉的是中间那个，后面的下标要跟着变，不能用缓存的
let afterMid = [sA, sC]             // sB 被删了
assert(SchemeLookup.index(sC.id, in: afterMid) == 1, "下标没跟着更新")
assert(SchemeLookup.find(sB.id, in: afterMid) == nil)

// 30. 全删空 / 空列表 / id 为 nil 都不能崩
assert(SchemeLookup.find(sA.id, in: []) == nil)
assert(SchemeLookup.index(sA.id, in: []) == nil)
assert(SchemeLookup.find(nil, in: list3) == nil)
assert(SchemeLookup.index(nil, in: list3) == nil)

// 31. 同名不同 id 不能混淆（名字不是主键）
let dup = Scheme(name: "a", content: "9")
assert(dup.id != sA.id)
assert(SchemeLookup.find(dup.id, in: list3) == nil, "按名字误匹配了")

print("all pass")
