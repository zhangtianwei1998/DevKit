import AppKit

/// 截图 + 把图钉在屏幕上。
enum Snip {
    /// 已钉住的窗口，必须留引用，否则会被回收。
    static var pinned: [PinWindow] = []

    /// 交互式截一张图，选完自动钉住。用系统的 screencapture，
    /// 这样不用自己申请屏幕录制权限，选区手感也和系统一致。
    static func capture(pin: Bool = true) {
        let out = URL.temporaryDirectory.appending(path: "devkit-snip-\(UUID().uuidString).png")
        let p = Process()
        p.executableURL = URL(filePath: "/usr/sbin/screencapture")
        // -i 交互选区, -o 不要窗口阴影, -x 不播快门声
        p.arguments = ["-i", "-o", "-x", out.path]
        p.terminationHandler = { _ in
            DispatchQueue.main.async {
                defer { try? FileManager.default.removeItem(at: out) }
                // 用户按 Esc 取消时不会生成文件
                guard let img = NSImage(contentsOf: out), img.size.width > 0 else { return }
                if pin {
                    show(img)
                } else {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects([img])
                }
            }
        }
        try? p.run()
    }

    static func show(_ img: NSImage) {
        let w = PinWindow(image: img)
        w.orderFrontRegardless()
        pinned.append(w)
    }

    static func close(_ w: PinWindow) {
        w.orderOut(nil)
        pinned.removeAll { $0 === w }
    }

    static func closeAll() {
        pinned.forEach { $0.orderOut(nil) }
        pinned.removeAll()
    }
}
