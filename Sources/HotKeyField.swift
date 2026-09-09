import AppKit
import SwiftUI

/// 点一下开始录制，然后按下想要的组合键。
/// 用 NSView 而不是 SwiftUI，因为要在按键被系统菜单吃掉之前拦住它。
private final class RecorderView: NSView {
    var onRecord: (HotKeySpec) -> Void = { _ in }
    var onStateChange: (Bool) -> Void = { _ in }

    private(set) var recording = false {
        didSet { onStateChange(recording) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with e: NSEvent) {
        recording = true
        window?.makeFirstResponder(self)
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        return true
    }

    override func keyDown(with e: NSEvent) {
        guard recording else { super.keyDown(with: e); return }
        // Esc 取消录制
        if e.keyCode == 53 {
            recording = false
            window?.makeFirstResponder(nil)
            return
        }
        let spec = HotKeySpec(keyCode: UInt32(e.keyCode),
                              modifierRaw: e.modifierFlags
                                .intersection(.deviceIndependentFlagsMask).rawValue)
        // 没有修饰键的话会抢掉正常打字，不接受
        guard spec.isValid else { NSSound.beep(); return }
        recording = false
        window?.makeFirstResponder(nil)
        onRecord(spec)
    }

    /// 只按修饰键不算，等真正的字母数字键。
    override func flagsChanged(with e: NSEvent) {}
}

struct HotKeyField: NSViewRepresentable {
    @Binding var spec: HotKeySpec
    @Binding var recording: Bool

    func makeNSView(context: Context) -> NSView {
        let v = RecorderView()
        v.onRecord = { spec = $0 }
        v.onStateChange = { recording = $0 }
        return v
    }

    func updateNSView(_ v: NSView, context: Context) {}
}
