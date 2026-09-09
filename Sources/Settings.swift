import SwiftUI

/// 用户可配置项。
@MainActor
final class Settings: ObservableObject {
    @Published var snipHotKey: HotKeySpec {
        didSet {
            guard snipHotKey != oldValue else { return }
            save()
            applyHotKey()
        }
    }
    @Published var scroll: ScrollTuning {
        didSet {
            guard scroll != oldValue else { return }
            save()
            ScrollTap.shared.update(scroll)
        }
    }
    /// 注册失败时给界面看的提示（一般是被别的应用占用了）。
    @Published var hotKeyError: String?

    private let file = URL.applicationSupportDirectory
        .appending(path: "DevKit/settings.json")

    private struct Stored: Codable {
        var snipHotKey: HotKeySpec
        var scroll: ScrollTuning?
    }

    init() {
        let stored = (try? Data(contentsOf: file)).flatMap {
            try? JSONDecoder().decode(Stored.self, from: $0)
        }
        snipHotKey = stored?.snipHotKey ?? .default
        scroll = stored?.scroll ?? .default
        applyHotKey()
        ScrollTap.shared.update(scroll)
    }

    func applyHotKey() {
        let ok = HotKey.shared.register(snipHotKey) { Snip.capture() }
        hotKeyError = ok ? nil : "\(snipHotKey.display) 注册失败，可能被其他应用占用了"
    }

    private func save() {
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(Stored(snipHotKey: snipHotKey, scroll: scroll)).write(to: file)
    }
}
