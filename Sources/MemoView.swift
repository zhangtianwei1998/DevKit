import SwiftUI

struct MemoView: View {
    @EnvironmentObject var store: MemoStore
    @State private var selected: Category.ID?
    /// 待确认删除的分类（只有非空分类才会走到这里）
    @State private var pendingDelete: Category?
    @FocusState private var focused: Todo.ID?

    /// 当前分类在数组里的下标。每次重新按 id 查，不能把下标捕获进闭包，
    /// 否则删掉分类后数组缩短，旧下标会越界直接崩。
    private var currentIndex: Int? {
        CategoryLookup.index(selected, in: store.categories)
    }

    var body: some View {
        // ponytail: 照抄 HostsView 的 HStack + Divider。HSplitView 在
        // NavigationSplitView 的 detail 里拿不到确定高度，会塌成一条缝。
        HStack(spacing: 0) {
            categoryColumn
                .frame(width: 220)
            Divider()
            todoColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 三个加减全放右上角工具栏，跟 Hosts 一致。
        // 工具栏图标默认比正文大，再用 .imageScale(.large) 抬一级。
        // 图标没文字，.help 又不会传给辅助功能，所以两个都要写。
        .toolbar {
            Button { store.addCategory() } label: { Image(systemName: "folder.badge.plus") }
                .help("新建分类")
                .accessibilityLabel("新建分类")
            Button(action: deleteSelectedCategory) { Image(systemName: "trash") }
                .help("删除选中分类")
                .accessibilityLabel("删除选中分类")
                .disabled(selected == nil)
            Button { if let i = currentIndex { addTodo(i) } } label: { Image(systemName: "plus") }
                .help("加一条")
                .accessibilityLabel("加一条")
                .disabled(currentIndex == nil)
        }
        .imageScale(.large)
        .confirmationDialog(
            "删除「\(pendingDelete?.name ?? "")」？",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { c in
            Button("删除分类和 \(c.todos.count) 条内容", role: .destructive) {
                selected = nil
                store.remove(c.id)
                pendingDelete = nil
            }
        } message: { c in
            Text("里面还有 \(c.todos.count) 条内容，删了找不回来。")
        }
    }

    // MARK: - 左：分类

    private var categoryColumn: some View {
        List(selection: $selected) {
            ForEach(store.categories) { c in
                HStack(spacing: 10) {
                    Circle()
                        .fill(c.color.color)
                        .frame(width: 9, height: 9)
                    Text(c.name)
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    if let badge = c.badge {
                        Text(badge)
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 3)
                .tag(c.id)
            }
            .onMove { from, to in store.categories.move(fromOffsets: from, toOffset: to) }
        }
    }

    /// 空分类直接删，有内容的先弹确认。这是唯一会丢数据的操作。
    private func deleteSelectedCategory() {
        guard let c = CategoryLookup.find(selected, in: store.categories) else { return }
        if c.todos.isEmpty {
            // 先清选中再删，否则右栏会在这一帧拿着已删除的 id 去读数组
            selected = nil
            store.remove(c.id)
        } else {
            pendingDelete = c
        }
    }

    // MARK: - 右：条目

    @ViewBuilder private var todoColumn: some View {
        if let i = currentIndex {
            VStack(spacing: 0) {
                header(i)
                Divider()
                todoList(i)
            }
        } else {
            VStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 34))
                    .foregroundStyle(.tertiary)
                Text("选一个分类")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// 分类的名字和颜色放在右栏顶部，省一整列编辑器。
    private func header(_ i: Int) -> some View {
        HStack(spacing: 12) {
            TextField("分类名称", text: Binding(
                get: { store.categories[safe: i]?.name ?? "" },
                set: { if i < store.categories.count { store.categories[i].name = $0 } }))
                .textFieldStyle(.plain)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 7) {
                ForEach(MemoColor.allCases) { c in
                    // 真 Button，不用 Circle().onTapGesture。
                    // onTapGesture 不是辅助功能动作，那样既不能用键盘选色，
                    // 旁白也点不到，而颜色是区分分类的主要手段。
                    let picked = store.categories[safe: i]?.color == c
                    Button {
                        if i < store.categories.count { store.categories[i].color = c }
                    } label: {
                        Circle()
                            .fill(c.color)
                            .frame(width: 12, height: 12)
                            // 选中的套一圈同色细环，靠间距区分。
                            // 白环在浅色背景上看不见，黑环在 8 个强色块旁边又太抗。
                            .overlay {
                                if picked {
                                    Circle()
                                        .strokeBorder(c.color, lineWidth: 1.5)
                                        .padding(-4)
                                }
                            }
                            .frame(width: 21, height: 21)
                    }
                    .buttonStyle(.plain)
                    .help(c.label)
                    .accessibilityLabel(c.label)
                    .accessibilityAddTraits(picked ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func todoList(_ i: Int) -> some View {
        List {
            ForEach(store.categories[i].todos) { t in
                row(categoryIndex: i, todo: t)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 6, bottom: 5, trailing: 10))
            }
            .onMove { from, to in
                guard i < store.categories.count else { return }
                store.categories[i].todos.move(fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.plain)
        // 回车现在是换行，不再提交，所以空条目靠“离开时清掉”回收，
        // 不然点了加号又不写就会攒下一堆空行。
        .onChange(of: focused) { _ in dropEmpties(i) }
    }

    /// 清掉没在编辑的空条目。正在编辑的那条不动，否则刚建就没了。
    private func dropEmpties(_ i: Int) {
        guard i < store.categories.count else { return }
        let keep = focused
        store.categories[i].todos.removeAll {
            $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && $0.id != keep
        }
    }

    private func row(categoryIndex i: Int, todo t: Todo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // 小圆点只是行首标记，不可点，颜色跟分类一致。
            Circle()
                .fill(store.categories[safe: i]?.color.color ?? .secondary)
                .frame(width: 6, height: 6)
                .padding(.top, 7)
                .accessibilityHidden(true)
            editor(i, t)
        }
        .contextMenu {
            Button("删除", role: .destructive) { removeTodo(i, t.id) }
        }
    }

    /// 条目的输入区。
    /// 用 TextEditor 而不是 TextField：回车要在同一条里换行，不能变成新建一条。
    /// TextEditor 自己不会根据内容长高，所以垫一份透明 Text 在下面撑出高度。
    /// 两边的 font / lineSpacing 必须一致，否则高度算错，文字会被截掉。
    /// 外面那层 contentShape + onTapGesture 是必需的：
    /// List 会把行内的点击当成“选中这行”吃掉，不手动抢回来就点不进去编辑。
    private func editor(_ i: Int, _ t: Todo) -> some View {
        let text = Binding(
            get: { todo(i, t.id)?.title ?? "" },
            set: { new in withTodo(i, t.id) { $0.title = new } })
        return ZStack(alignment: .topLeading) {
            // 空字串测不出高度，给个空格占一行
            Text(text.wrappedValue.isEmpty ? " " : text.wrappedValue)
                .font(.body)
                .lineSpacing(Self.lineSpacing)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .opacity(0)
                .accessibilityHidden(true)
            TextEditor(text: text)
                .font(.body)
                .lineSpacing(Self.lineSpacing)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .focused($focused, equals: t.id)
                .accessibilityLabel("条目内容")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { focused = t.id }
    }

    /// 条目内部的行距。撑高度的透明文字和输入框共用这一个值。
    private static let lineSpacing: CGFloat = 5

    // MARK: - 条目增删改
    // 全部按 id 定位，不信任传进来的下标（列表可能刚被拖动或删除过）

    private func todo(_ i: Int, _ id: Todo.ID) -> Todo? {
        store.categories[safe: i]?.todos.first { $0.id == id }
    }

    private func withTodo(_ i: Int, _ id: Todo.ID, _ change: (inout Todo) -> Void) {
        guard i < store.categories.count,
              let j = store.categories[i].todos.firstIndex(where: { $0.id == id })
        else { return }
        change(&store.categories[i].todos[j])
    }

    private func removeTodo(_ i: Int, _ id: Todo.ID) {
        guard i < store.categories.count else { return }
        if focused == id { focused = nil }
        store.categories[i].todos.removeAll { $0.id == id }
    }

    private func addTodo(_ i: Int) {
        guard i < store.categories.count else { return }
        let new = Todo(title: "")
        store.categories[i].todos.append(new)
        focused = new.id
    }
}
