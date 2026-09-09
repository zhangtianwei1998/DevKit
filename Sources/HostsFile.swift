import Foundation

/// /etc/hosts 的纯文本处理。不碰磁盘，方便测。
enum HostsFile {
    static let marker = "# --- DEVKIT_START ---"
    static let markerEnd = "# --- DEVKIT_END ---"
    /// SwitchHosts 只写起始标记，没有结束标记，所以它之后的内容全归它管。
    static let swMarker = "# --- SWITCHHOSTS_CONTENT_START ---"

    /// 剥掉所有托管块，只留系统自带内容。
    static func base(from text: String) -> String {
        var out: [String] = []
        var skipping = false
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t == marker || t == swMarker { skipping = true; continue }
            if t == markerEnd { skipping = false; continue }
            if !skipping { out.append(line) }
        }
        while out.last?.trimmingCharacters(in: .whitespaces).isEmpty == true { out.removeLast() }
        return out.joined(separator: "\n")
    }

    /// 生成完整的新 hosts 内容。
    static func render(base: String, blocks: [(name: String, content: String)]) -> String {
        var text = base + "\n\n" + marker + "\n"
        for b in blocks {
            text += "\n# \(b.name)\n\(b.content)\n"
        }
        return text + "\n" + markerEnd + "\n"
    }
}
