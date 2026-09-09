import SwiftUI

/// 滚动设置面板。名字加 2 是为了不和 SwiftUI 自带的 ScrollView 撞车。
struct ScrollSettingsView: View {
    @EnvironmentObject var settings: Settings
    @State private var granted = ScrollTap.hasPermission
    /// 用户去系统设置里勾选后要能自动感知，所以定时查一下。
    @State private var poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("鼠标滚动").font(.title2).bold()

            if !granted {
                permissionBanner
            }

            Toggle("反转滚动方向", isOn: binding(\.reverse))
            Toggle("平滑滚动", isOn: binding(\.smooth))
            Toggle("只作用于鼠标滚轮，不改触控板", isOn: binding(\.mouseOnly))

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("滚动距离")
                    Spacer()
                    Text("\(Int(settings.scroll.step)) 像素/格")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: binding(\.step), in: 5...300)
            }
            .disabled(!settings.scroll.smooth)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("滑动持续感")
                    Spacer()
                    Text(String(format: "%.2f", settings.scroll.damping))
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Slider(value: binding(\.damping), in: 0.1...0.95)
                Text("越大越顺滑但停得越慢，越小越干脆")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .disabled(!settings.scroll.smooth)

            HStack {
                Button("恢复默认") { settings.scroll = .default }
                    .disabled(settings.scroll == .default)
                Spacer()
                Text(ScrollTap.shared.isRunning ? "已生效" : "未启用")
                    .font(.caption)
                    .foregroundStyle(ScrollTap.shared.isRunning ? .green : .secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(poll) { _ in
            let now = ScrollTap.hasPermission
            if now != granted {
                granted = now
                // 刚拿到权限，把 tap 起起来
                if now { ScrollTap.shared.update(settings.scroll) }
            }
        }
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("需要辅助功能权限", systemImage: "lock.shield")
                .font(.headline)
            Text("滚动改写要拦截系统事件，必须先授权。点下面的按钮，然后在系统设置里勾选 DevKit。")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("请求授权") { ScrollTap.requestPermission() }
                Button("打开系统设置") {
                    let u = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                    if let url = URL(string: u) { NSWorkspace.shared.open(url) }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    /// 把 ScrollTuning 的某个字段接成 Binding，改完自动存盘并应用。
    private func binding<V>(_ key: WritableKeyPath<ScrollTuning, V>) -> Binding<V> {
        Binding(
            get: { settings.scroll[keyPath: key] },
            set: { settings.scroll[keyPath: key] = $0 })
    }
}
