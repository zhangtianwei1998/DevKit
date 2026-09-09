import SwiftUI

struct Scheme: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var content: String
    var enabled: Bool = false
}

/// 按 id 安全取方案。删掩方案后界面可能还抽着旧 id，
/// 这时必须返回 nil 而不是拿旧下标去索引数组（会越界崩）。
enum SchemeLookup {
    static func find(_ id: Scheme.ID?, in list: [Scheme]) -> Scheme? {
        guard let id else { return nil }
        return list.first { $0.id == id }
    }

    static func index(_ id: Scheme.ID?, in list: [Scheme]) -> Int? {
        guard let id else { return nil }
        return list.firstIndex { $0.id == id }
    }
}

@MainActor
final class HostsStore: ObservableObject {
    @Published var schemes: [Scheme] = []
    @Published var lastError: String?

    private let file = URL.applicationSupportDirectory
        .appending(path: "DevKit/hosts.json")

    init() {
        load()
        if schemes.isEmpty { importFromSwitchHosts() }
    }

    func isEnabled(_ s: Scheme) -> Bool { s.enabled }

    func toggle(_ s: Scheme) {
        guard let i = schemes.firstIndex(where: { $0.id == s.id }) else { return }
        schemes[i].enabled.toggle()
        save()
        apply()
    }

    func add() {
        schemes.append(Scheme(name: "新方案", content: "127.0.0.1  example.local"))
        save()
    }

    func remove(_ s: Scheme) {
        schemes.removeAll { $0.id == s.id }
        save()
        apply()
    }

    func update(_ s: Scheme) {
        guard let i = schemes.firstIndex(where: { $0.id == s.id }) else { return }
        schemes[i] = s
        save()
        if s.enabled { apply() }
    }

    // MARK: - 持久化

    private func load() {
        guard let data = try? Data(contentsOf: file),
              let list = try? JSONDecoder().decode([Scheme].self, from: data)
        else { return }
        schemes = list
    }

    func save() {
        try? FileManager.default.createDirectory(
            at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? JSONEncoder().encode(schemes).write(to: file)
    }

    /// 首次启动时把 SwitchHosts 的方案搬过来，省得手抄。
    private func importFromSwitchHosts() {
        let root = URL.homeDirectory.appending(path: ".SwitchHosts/data")
        guard let treeData = try? Data(contentsOf: root.appending(path: "list/tree.json")),
              let tree = try? JSONSerialization.jsonObject(with: treeData) as? [[String: Any]]
        else { return }

        // data/*.json 里的 id 字段才是 tree 里的 id，文件名无关
        var byID: [String: String] = [:]
        let dir = root.appending(path: "collection/hosts/data")
        for f in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? [] {
            guard let d = try? Data(contentsOf: f),
                  let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                  let id = o["id"] as? String, let c = o["content"] as? String
            else { continue }
            byID[id] = c
        }

        schemes = tree.compactMap { node in
            guard let id = node["id"] as? String,
                  let title = node["title"] as? String,
                  let content = byID[id] else { return nil }
            return Scheme(name: title, content: content, enabled: node["on"] as? Bool ?? false)
        }
        if !schemes.isEmpty { save() }
    }

    // MARK: - 写入 /etc/hosts

    /// 去掉我们和 SwitchHosts 的托管块，剩下的是系统自带内容。
    private func baseHosts() -> String {
        HostsFile.base(from: (try? String(contentsOfFile: "/etc/hosts", encoding: .utf8)) ?? "")
    }

    func apply() {
        let text = HostsFile.render(
            base: baseHosts(),
            blocks: schemes.filter(\.enabled).map { ($0.name, $0.content) })

        let tmp = URL.temporaryDirectory.appending(path: "devkit-hosts")
        do {
            try text.write(to: tmp, atomically: true, encoding: .utf8)
            try runAsAdmin("cp '\(tmp.path)' /etc/hosts && dscacheutil -flushcache")
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// ponytail: 每次写入弹一次系统授权框。要免密就得装特权 helper，先不上。
    private func runAsAdmin(_ cmd: String) throws {
        let escaped = cmd.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "\"", with: "\\\"")
        let p = Process()
        p.executableURL = URL(filePath: "/usr/bin/osascript")
        p.arguments = ["-e", "do shell script \"\(escaped)\" with administrator privileges"]
        let err = Pipe()
        p.standardError = err
        try p.run()
        let msg = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "DevKit", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: msg.isEmpty ? "写入被取消" : msg])
        }
    }
}
