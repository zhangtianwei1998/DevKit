import SwiftUI

struct SnipView: View {
    @EnvironmentObject var settings: Settings
    @State private var recording = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("截图钉图").font(.title2).bold()

            Button {
                Snip.capture()
            } label: {
                Label("截图并钉住", systemImage: "camera.viewfinder")
            }
            .controlSize(.large)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("快捷键").font(.headline)
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(recording ? Color.accentColor.opacity(0.15)
                                            : Color(nsColor: .controlBackgroundColor))
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(recording ? Color.accentColor : Color(nsColor: .separatorColor))
                        Text(recording ? "按下组合键…" : settings.snipHotKey.display)
                            .font(.system(.body, design: recording ? .default : .monospaced))
                            .foregroundStyle(recording ? .secondary : .primary)
                        // 透明层负责接收点击和按键
                        HotKeyField(spec: $settings.snipHotKey, recording: $recording)
                    }
                    .frame(width: 150, height: 28)

                    Button("恢复默认") { settings.snipHotKey = .default }
                        .disabled(settings.snipHotKey == .default)
                }
                if let err = settings.hotKeyError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
                Text("点方框后按下想用的组合键，Esc 取消。必须带 ⌘⇧⌥⌃ 中至少一个。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("钉住的图怎么操作").font(.headline)
                Text("鼠标移上去 = 左上角出现关闭按钮")
                Text("拖动图片 = 移动")
                Text("滚轮 = 缩放")
                Text("双击 或 Esc = 关闭")
                Text("Cmd+C = 复制到剪贴板")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
