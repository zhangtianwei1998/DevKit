import AppKit
import Carbon.HIToolbox

/// 注册系统级全局快捷键。用 Carbon 的 RegisterEventHotKey，
/// 它不需要辅助功能权限，比 CGEventTap 省事得多。
/// ponytail: 只支持一个热键，够用。要多个就把 ref 换成字典。
final class HotKey {
    static let shared = HotKey()

    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var action: () -> Void = {}
    private static let signature: OSType = 0x444B4854   // 'DKHT'

    private init() {}

    /// 注册（或重新注册）快捷键。返回是否成功。
    @discardableResult
    func register(_ spec: HotKeySpec, action: @escaping () -> Void) -> Bool {
        unregister()
        guard spec.isValid else { return false }
        self.action = action

        // 事件回调只能是 C 函数，这里通过 userData 把 self 传进去
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let me = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let userData else { return noErr }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard id.signature == HotKey.signature else { return noErr }
            let me = Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &type, me, &handler)

        let id = EventHotKeyID(signature: HotKey.signature, id: 1)
        let status = RegisterEventHotKey(spec.keyCode, spec.carbonModifiers,
                                        id, GetApplicationEventTarget(), 0, &ref)
        if status != noErr {
            unregister()
            return false
        }
        return true
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref); self.ref = nil }
        if let handler { RemoveEventHandler(handler); self.handler = nil }
    }
}
