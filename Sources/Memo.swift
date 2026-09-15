import SwiftUI

/// 分类的颜色，只给固定色板里的 8 个。
/// 存字符串名字，`Codable` 白送，也不会被调出一坨看不清的灰。
enum MemoColor: String, Codable, CaseIterable, Identifiable {
    case red, orange, yellow, green, mint, blue, purple, pink

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .mint: return .mint
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        }
    }

    var label: String {
        switch self {
        case .red: return "红"
        case .orange: return "橙"
        case .yellow: return "黄"
        case .green: return "绿"
        case .mint: return "薄荷"
        case .blue: return "蓝"
        case .purple: return "紫"
        case .pink: return "粉"
        }
    }

    /// 认不出的颜色名退回蓝色。默认的 RawRepresentable 解码会直接抛错，
    /// 那样整个 memo.json 读不进来，所有条目一起丢。
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MemoColor(rawValue: raw) ?? .blue
    }
}

/// 备忘的一条待办。只有内容，没有完成状态。
struct Todo: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
}

/// 备忘分类：名字 + 颜色 + 底下的条目。
/// ponytail: 条目直接嵌在分类里，整体一个 json。跨分类汇总所有待办的需求没提，
/// 真要做再拆成两张平表、给 Todo 加 categoryID。
struct Category: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var color: MemoColor = .blue
    var todos: [Todo] = []

    /// 列表右侧的条数。空分类不显示。
    var badge: String? { todos.isEmpty ? nil : "\(todos.count)" }
}

/// 按 id 安全取分类。跟 `SchemeLookup` 同一个道理：
/// 删掉分类后界面可能还攥着旧 id，这时必须返回 nil 而不是拿旧下标去索引数组。
enum CategoryLookup {
    static func find(_ id: Category.ID?, in list: [Category]) -> Category? {
        guard let id else { return nil }
        return list.first { $0.id == id }
    }

    static func index(_ id: Category.ID?, in list: [Category]) -> Int? {
        guard let id else { return nil }
        return list.firstIndex { $0.id == id }
    }
}

@MainActor
final class MemoStore: ObservableObject {
    /// ponytail: didSet 自动存盘，每敲一个字写一次小 json。
    /// 换成防抖等文件真的大到卡手再说，现在这样改完就落盘，丢不了。
    @Published var categories: [Category] = [] { didSet { save() } }

    private let file: URL

    /// file 可注入，只为了自检时别写到真的备忘文件上。
    init(file: URL = URL.applicationSupportDirectory.appending(path: "DevKit/memo.json")) {
        self.file = file
        if let data = try? Data(contentsOf: file),
           let list = try? JSONDecoder().decode([Category].self, from: data) {
            categories = list
        }
    }

    func addCategory() {
        categories.append(Category(name: "新分类", color: MemoColor.allCases.randomElement() ?? .blue))
    }

    func remove(_ id: Category.ID) {
        categories.removeAll { $0.id == id }
    }

    private func save() {
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(categories).write(to: file)
    }
}

extension Array {
    /// 越界返回 nil。SwiftUI 的视图闭包会在数据已经变短的那一帧再读一次下标。
    subscript(safe i: Int) -> Element? {
        indices.contains(i) ? self[i] : nil
    }
}
