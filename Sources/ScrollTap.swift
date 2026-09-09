import AppKit
import CoreGraphics

/// 拦截滚轮事件，改方向 + 平滑重发。
/// 需要"辅助功能"权限，否则 CGEvent.tapCreate 会直接返回 nil。
@MainActor
final class ScrollTap {
    static let shared = ScrollTap()

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var timer: CVDisplayLink?
    private var scroller = SmoothScroller()
    /// 不足一像素的隶数，累到一像素再发。
    private var carry: Double = 0
    private var tuning = ScrollTuning.default
    /// 自己发出去的事件要放行，否则会被自己再拦一次，无限循环。
    private var injecting = false

    var isRunning: Bool { tap != nil }

    private init() {}

    /// 有没有辅助功能权限。
    static var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    /// 弹出系统的权限请求框。用户点了之后还得手动勾选，所以要配合 UI 提示。
    static func requestPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue()
        AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func update(_ t: ScrollTuning) {
        tuning = t.sanitized
        // 参数变了，残留的滚动量清掉，免得用旧参数继续滑
        scroller.reset()
        carry = 0
        // 两个开关都关了就把 tap 停掉，不白占系统资源
        if !tuning.reverse && !tuning.smooth {
            stop()
        } else if !isRunning {
            start()
        }
    }

    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard ScrollTap.hasPermission else { return false }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()

        guard let t = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,          // 要改写事件，不能用 listenOnly
            eventsOfInterest: mask,
            callback: { _, type, event, userData in
                guard let userData else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<ScrollTap>.fromOpaque(userData).takeUnretainedValue()
                return MainActor.assumeIsolatedCompat {
                    me.handle(type: type, event: event)
                }
            },
            userInfo: me
        ) else { return false }

        tap = t
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, t, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: t, enable: true)
        startFrameTimer()
        return true
    }

    func stop() {
        stopFrameTimer()
        scroller.reset()
        carry = 0
        if let t = tap {
            CGEvent.tapEnable(tap: t, enable: false)
            if let s = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), s, .commonModes)
            }
            tap = nil
            runLoopSource = nil
        }
    }

    // MARK: - 事件处理

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // 系统可能因为超时把 tap 禁掉，要自己重新打开
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .scrollWheel else { return Unmanaged.passUnretained(event) }
        // 自己注入的事件直接放行
        if injecting { return Unmanaged.passUnretained(event) }

        let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
        let src = ScrollFilter.source(isContinuous: continuous)
        guard ScrollFilter.shouldHandle(source: src, tuning: tuning) else {
            return Unmanaged.passUnretained(event)
        }

        // 横向滚动不管，只处理纵向
        let dy = event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        guard dy != 0 else { return Unmanaged.passUnretained(event) }

        let signed = tuning.reverse ? -dy : dy

        if tuning.smooth {
            // 吞掉原事件，改由定时器分帧发出
            scroller.push(signed * tuning.step)
            return nil
        }

        // 只反转不平滑：直接改这个事件的值
        event.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: signed)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: signed * tuning.step)
        return Unmanaged.passUnretained(event)
    }

    // MARK: - 分帧发送

    private func startFrameTimer() {
        stopFrameTimer()
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            DispatchQueue.main.async { self?.tick() }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
        timer = link
    }

    private func stopFrameTimer() {
        if let t = timer { CVDisplayLinkStop(t) }
        timer = nil
    }

    private func tick() {
        guard !scroller.isIdle else { return }
        let d = scroller.next(damping: tuning.damping)
        guard d != 0 else { return }
        // 不足一像素的隶数先存着，凑整了再发，
        // 否则 rounded() 会把它抹成 0，白发一堆空事件。
        carry += d
        let whole = carry.rounded(.towardZero)
        guard whole != 0 else { return }
        carry -= whole
        post(pixels: whole)
    }

    private func post(pixels: Double) {
        guard let e = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                              wheelCount: 1, wheel1: Int32(pixels.rounded()),
                              wheel2: 0, wheel3: 0) else { return }
        injecting = true
        e.post(tap: .cgSessionEventTap)
        injecting = false
    }
}

/// Swift 5.8 没有 MainActor.assumeIsolated，自己糊一个。
/// 事件回调本来就在主线程的 runloop 上跑，所以直接执行是安全的。
/// ponytail: 升到 Swift 5.10 后换成官方的 MainActor.assumeIsolated。
extension MainActor {
    static func assumeIsolatedCompat<T>(_ body: () -> T) -> T { body() }
}
