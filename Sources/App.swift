import SwiftUI

@main
struct DevKitApp: App {
    @StateObject private var hosts = HostsStore()
    @StateObject private var settings = Settings()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        Window("DevKit", id: "main") {
            RootView()
                .environmentObject(hosts)
                .environmentObject(settings)
        }
        .defaultSize(width: 820, height: 560)

        MenuBarExtra("DevKit", systemImage: "hammer.fill") {
            Button("截图并钉住") { Snip.capture() }
            if !Snip.pinned.isEmpty {
                Button("关闭全部钉图") { Snip.closeAll() }
            }
            Divider()
            ForEach(hosts.schemes) { s in
                Button {
                    hosts.toggle(s)
                } label: {
                    Text("\(hosts.isEnabled(s) ? "✓ " : "")\(s.name)")
                }
            }
            Divider()
            Button("打开主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            Button("退出") { NSApplication.shared.terminate(nil) }
        }
    }
}
