import AppKit

/// 左上角的关闭按钮，仿 macOS 窗口的红色小圆点。
/// 自己画而不用 NSButton，因为要精确控制 hover 时才显示。
private final class CloseButton: NSView {
    var onClick: () -> Void = {}
    var showing = false { didSet { needsDisplay = true } }
    private var hovering = false { didSet { needsDisplay = true } }

    /// 按钮不能跟着拖窗口，否则点不到
    override var mouseDownCanMoveWindow: Bool { false }

    override func draw(_ dirty: NSRect) {
        guard showing else { return }
        let r = bounds.insetBy(dx: 2, dy: 2)
        NSColor(calibratedRed: 1, green: 0.35, blue: 0.33, alpha: 1).setFill()
        NSBezierPath(ovalIn: r).fill()
        NSColor.black.withAlphaComponent(0.18).setStroke()
        let ring = NSBezierPath(ovalIn: r)
        ring.lineWidth = 0.5
        ring.stroke()

        // 鼠标移到按钮上才显示中间的叉
        guard hovering else { return }
        let x = NSBezierPath()
        let i = r.insetBy(dx: r.width * 0.3, dy: r.height * 0.3)
        x.move(to: CGPoint(x: i.minX, y: i.minY))
        x.line(to: CGPoint(x: i.maxX, y: i.maxY))
        x.move(to: CGPoint(x: i.minX, y: i.maxY))
        x.line(to: CGPoint(x: i.maxX, y: i.minY))
        x.lineWidth = 1.4
        x.lineCapStyle = .round
        NSColor.black.withAlphaComponent(0.55).setStroke()
        x.stroke()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                      options: [.mouseEnteredAndExited, .activeAlways],
                                      owner: self))
    }

    override func mouseEntered(with e: NSEvent) { hovering = true }
    override func mouseExited(with e: NSEvent) { hovering = false }

    override func mouseDown(with e: NSEvent) {}   // 吃掉，不要传给窗口
    override func mouseUp(with e: NSEvent) {
        // 注意：locationInWindow 要转成本视图坐标再判断是否命中
        if bounds.contains(convert(e.locationInWindow, from: nil)) { onClick() }
    }
}

/// 图片容器。NSImageView 会自己吃掉鼠标事件，导致
/// isMovableByWindowBackground 收不到拖动，所以换成自己画图的普通 NSView。
private final class DragImageView: NSView {
    var image: NSImage? { didSet { needsDisplay = true } }
    var onHover: (Bool) -> Void = { _ in }
    /// 尺寸变了要重摆关闭按钮。resizeSubviews 比在窗口侧
    /// 监听可靠：不管是滚轮缩放还是直接改窗口尺寸都会调到。
    var onResize: () -> Void = {}

    override var mouseDownCanMoveWindow: Bool { true }

    override func draw(_ dirty: NSRect) {
        image?.draw(in: bounds, from: .zero, operation: .sourceOver, fraction: 1)
    }

    override func resizeSubviews(withOldSize old: NSSize) {
        super.resizeSubviews(withOldSize: old)
        onResize()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                      options: [.mouseEnteredAndExited, .activeAlways],
                                      owner: self))
    }

    override func mouseEntered(with e: NSEvent) { onHover(true) }
    override func mouseExited(with e: NSEvent) { onHover(false) }
}

/// 钉在屏幕最上层的无边框图片窗口。拖动移动，滚轮缩放，Esc/双击关闭。
final class PinWindow: NSWindow {
    private let imageView = DragImageView()
    private let closeButton = CloseButton()
    private let aspect: CGFloat
    private let pixelSize: CGSize
    private var scale: CGFloat = 1
    private static let buttonSize: CGFloat = 18
    private static let buttonInset: CGFloat = 6

    init(image: NSImage) {
        let f = NSScreen.main?.backingScaleFactor ?? 2
        let px = image.representations.first.map {
            CGSize(width: $0.pixelsWide, height: $0.pixelsHigh)
        } ?? image.size
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let size = PinGeometry.initialSize(pixels: px, scaleFactor: f, screen: screen.size)
        aspect = size.width > 0 ? size.height / size.width : 1
        pixelSize = px

        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless, .resizable],
                   backing: .buffered, defer: false)

        level = .floating              // 浮在普通窗口上面
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true   // 直接拖图片就能移动
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        imageView.image = image
        imageView.frame = CGRect(origin: .zero, size: size)
        imageView.autoresizingMask = [.width, .height]
        imageView.wantsLayer = true
        imageView.layer?.cornerRadius = 6
        imageView.layer?.masksToBounds = true
        contentView = imageView

        closeButton.onClick = { [weak self] in
            guard let self else { return }
            Snip.close(self)
        }
        imageView.addSubview(closeButton)
        layoutCloseButton()

        // 鼠标进入整张图时才显示关闭按钮
        imageView.onHover = { [weak self] inside in
            self?.closeButton.showing = inside
        }
        imageView.onResize = { [weak self] in self?.layoutCloseButton() }

        // 出现在鼠标附近，而不是屏幕角落
        setFrameOrigin(PinGeometry.origin(
            mouse: NSEvent.mouseLocation, size: size, visible: screen))
    }

    /// 按钮固定在左上角（AppKit 坐标原点在左下，所以 y 要从顶部算）。
    private func layoutCloseButton() {
        let s = PinWindow.buttonSize
        let i = PinWindow.buttonInset
        closeButton.frame = CGRect(x: i,
                                   y: imageView.bounds.height - s - i,
                                   width: s, height: s)
    }

    override var canBecomeKey: Bool { true }

    /// 滚轮缩放，保持宽高比。
    override func scrollWheel(with e: NSEvent) {
        let f = NSScreen.main?.backingScaleFactor ?? 2
        let r = PinGeometry.zoom(base: pixelSize, scaleFactor: f,
                                current: scale, deltaY: e.scrollingDeltaY)
        scale = r.scale
        setContentSize(r.size)
        layoutCloseButton()
    }

    override func mouseDown(with e: NSEvent) {
        if e.clickCount == 2 { Snip.close(self) }
        super.mouseDown(with: e)
    }

    override func keyDown(with e: NSEvent) {
        switch e.keyCode {
        case 53: Snip.close(self)                       // Esc 关闭
        case 8 where e.modifierFlags.contains(.command): copyImage()  // Cmd+C 复制
        default: super.keyDown(with: e)
        }
    }

    private func copyImage() {
        guard let img = imageView.image else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([img])
    }
}
