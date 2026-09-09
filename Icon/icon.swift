import AppKit

// 画 DevKit 的应用图标。1024x1024 PNG。
// 用法: xcrun swiftc icon.swift -o /tmp/mkicon && /tmp/mkicon out.png

let side: CGFloat = 1024

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

/// macOS Big Sur 之后的图标是圆角矩形底板，圆角约边长的 22%。
func drawPlate() {
    let inset = side * 0.06
    let rect = NSRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)
    let radius = rect.width * 0.225
    let plate = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

    NSGradient(colors: [color(88, 132, 255), color(58, 74, 200)],
               atLocations: [0, 1], colorSpace: .sRGB)?
        .draw(in: plate, angle: -90)

    // 顶部一道很淡的高光，让底板不那么平
    plate.addClip()
    let glossHeight = rect.height * 0.42
    let gloss = NSRect(x: rect.minX, y: rect.maxY - glossHeight,
                       width: rect.width, height: glossHeight)
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.18),
                        NSColor.white.withAlphaComponent(0)],
               atLocations: [0, 1], colorSpace: .sRGB)?
        .draw(in: NSBezierPath(rect: gloss), angle: -90)
}

/// 一个符号就够。取景框 + 中间的开关滑块：
/// 框代表"工具的取景/范围"，滑块代表"切换开关"，合起来就是一套可切换的小工具。
/// 三个符号并排在 32 像素下必糊，所以只留一个。
func drawGlyphs() {
    let cx = side / 2, cy = side / 2
    let white = NSColor.white
    white.setStroke()
    white.setFill()

    let lw = side * 0.055

    // --- 取景框四角 ---
    let frameSide = side * 0.46
    let f = NSRect(x: cx - frameSide / 2, y: cy - frameSide / 2,
                   width: frameSide, height: frameSide)
    let corner = frameSide * 0.30

    let marks = NSBezierPath()
    marks.lineWidth = lw
    marks.lineCapStyle = .round
    marks.lineJoinStyle = .round
    // 左下
    marks.move(to: CGPoint(x: f.minX, y: f.minY + corner))
    marks.line(to: CGPoint(x: f.minX, y: f.minY))
    marks.line(to: CGPoint(x: f.minX + corner, y: f.minY))
    // 右下
    marks.move(to: CGPoint(x: f.maxX - corner, y: f.minY))
    marks.line(to: CGPoint(x: f.maxX, y: f.minY))
    marks.line(to: CGPoint(x: f.maxX, y: f.minY + corner))
    // 右上
    marks.move(to: CGPoint(x: f.maxX, y: f.maxY - corner))
    marks.line(to: CGPoint(x: f.maxX, y: f.maxY))
    marks.line(to: CGPoint(x: f.maxX - corner, y: f.maxY))
    // 左上
    marks.move(to: CGPoint(x: f.minX + corner, y: f.maxY))
    marks.line(to: CGPoint(x: f.minX, y: f.maxY))
    marks.line(to: CGPoint(x: f.minX, y: f.maxY - corner))
    marks.stroke()

    // --- 中间：开关滑块 ---
    let trackW = side * 0.215, trackH = side * 0.115
    let track = NSRect(x: cx - trackW / 2, y: cy - trackH / 2,
                       width: trackW, height: trackH)
    NSBezierPath(roundedRect: track,
                 xRadius: trackH / 2, yRadius: trackH / 2).fill()

    // 滑块的圆点挖空，用底板色，看起来像"已打开"
    let knob = trackH * 0.62
    let knobRect = NSRect(x: track.maxX - knob - (trackH - knob) / 2,
                          y: cy - knob / 2, width: knob, height: knob)
    color(72, 100, 228).setFill()
    NSBezierPath(ovalIn: knobRect).fill()
}

// 直接按像素画，不受屏幕缩放因子影响
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(side), pixelsHigh: Int(side),
    bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)
else {
    FileHandle.standardError.write(Data("创建位图失败\n".utf8))
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSGraphicsContext.current?.imageInterpolation = .high

drawPlate()
NSGraphicsContext.current?.restoreGraphicsState()
NSGraphicsContext.current?.saveGraphicsState()
drawGlyphs()

NSGraphicsContext.restoreGraphicsState()

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
guard let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write(Data("编码 PNG 失败\n".utf8))
    exit(1)
}
try png.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(Int(side))x\(Int(side)))")
