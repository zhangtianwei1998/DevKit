import SwiftUI

enum Module: String, CaseIterable, Identifiable {
    case hosts = "Hosts"
    case snip = "截图"
    case scroll = "滚动"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .hosts: return "network"
        case .snip: return "camera.viewfinder"
        case .scroll: return "computermouse"
        }
    }
}

struct RootView: View {
    @State private var selection: Module = .hosts

    var body: some View {
        NavigationSplitView {
            List(Module.allCases, selection: $selection) { m in
                Label(m.rawValue, systemImage: m.icon).tag(m)
            }
            .navigationSplitViewColumnWidth(160)
        } detail: {
            switch selection {
            case .hosts: HostsView()
            case .snip: SnipView()
            case .scroll: ScrollSettingsView()
            }
        }
    }
}
