import SwiftUI

struct HostsView: View {
    @EnvironmentObject var store: HostsStore
    @State private var selected: Scheme.ID?

    /// 根据 id 取方案的 Binding。
    /// 注意：每次读写都重新按 id 查，不能把下标捕获进闭包。
    /// 否则删掩方案后数组缩短，旧下标会越界直接崩。
    private var binding: Binding<Scheme>? {
        guard let current = SchemeLookup.find(selected, in: store.schemes) else { return nil }
        return Binding(
            get: { SchemeLookup.find(selected, in: store.schemes) ?? current },
            set: { new in
                guard let i = SchemeLookup.index(selected, in: store.schemes) else { return }
                store.schemes[i] = new
            })
    }

    var body: some View {
        // ponytail: 用 HStack + Divider 而不是 HSplitView。
        // HSplitView 在 NavigationSplitView 的 detail 里拿不到确定高度，会塌成一条缝。
        HStack(spacing: 0) {
            list
                .frame(width: 220)
            Divider()
            editor
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            Button { store.add() } label: { Image(systemName: "plus") }
            Button {
                guard let s = store.schemes.first(where: { $0.id == selected }) else { return }
                // 先清选中，再删。反过来的话编辑器会在这一帧拿着
                // 已删除的 id 去读数组。
                selected = nil
                store.remove(s)
            } label: { Image(systemName: "minus") }
            .disabled(selected == nil)
        }
    }

    private var list: some View {
        List(store.schemes, selection: $selected) { s in
            HStack {
                Toggle("", isOn: Binding(get: { s.enabled }, set: { _ in store.toggle(s) }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                Text(s.name)
            }
            .tag(s.id)
        }
    }

    @ViewBuilder private var editor: some View {
        if let b = binding {
            VStack(alignment: .leading, spacing: 8) {
                TextField("名称", text: b.name)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: b.content)
                    .font(.system(.body, design: .monospaced))
                    .border(.separator)
                if let err = store.lastError {
                    Label(err, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.red)
                }
                HStack {
                    Spacer()
                    Button("保存并应用") { store.update(b.wrappedValue) }
                        .keyboardShortcut("s")
                }
            }
            .padding()
        } else {
            Text("选一个方案")
                .foregroundStyle(.secondary)
        }
    }
}
