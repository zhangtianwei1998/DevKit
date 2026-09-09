import CoreGraphics

/// 钉图窗口的尺寸与位置计算。纯函数，方便测。
enum PinGeometry {
    /// 像素尺寸 → 初始逻辑尺寸。Retina 要除以缩放因子，太大的图缩到屏幕一半宽。
    static func initialSize(pixels: CGSize, scaleFactor: CGFloat, screen: CGSize) -> CGSize {
        let f = max(scaleFactor, 1)
        var s = CGSize(width: pixels.width / f, height: pixels.height / f)
        guard s.width > 0 else { return s }
        let aspect = s.height / s.width
        let maxW = screen.width / 2
        if s.width > maxW {
            s = CGSize(width: maxW, height: maxW * aspect)
        }
        return s
    }

    /// 以鼠标为中心摆放，但不许超出屏幕可视区域。
    static func origin(mouse: CGPoint, size: CGSize, visible: CGRect) -> CGPoint {
        // 图比屏幕还大时，紧贴左下角，不要往负方向跑
        let maxX = max(visible.maxX - size.width, visible.minX)
        let maxY = max(visible.maxY - size.height, visible.minY)
        return CGPoint(
            x: min(max(mouse.x - size.width / 2, visible.minX), maxX),
            y: min(max(mouse.y - size.height / 2, visible.minY), maxY))
    }

    /// 滚轮缩放后的新尺寸，倍率夹在 0.1~8 之间。
    static func zoom(base: CGSize, scaleFactor: CGFloat,
                     current: CGFloat, deltaY: CGFloat) -> (scale: CGFloat, size: CGSize) {
        let next = min(max(current * (1 + deltaY * 0.005), 0.1), 8)
        let f = max(scaleFactor, 1)
        let aspect = base.width > 0 ? base.height / base.width : 1
        let w = (base.width / f) * next
        return (next, CGSize(width: w, height: w * aspect))
    }
}
