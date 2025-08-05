import AppKit
import Common

public class TrayMenuModel: ObservableObject {
    @MainActor public static let shared = TrayMenuModel()

    private init() {}

    @Published var trayText: String = ""
    @Published var trayItems: [TrayItem] = []
    /// Is "layouting" enabled
    @Published var isEnabled: Bool = true
    @Published var workspaces: [WorkspaceViewModel] = []
    @Published var monitors: [MonitorViewModel] = []
    @Published var experimentalUISettings: ExperimentalUISettings = ExperimentalUISettings()
    @Published var sponsorshipMessage: String = sponsorshipPrompts.randomElement().orDie()
}

@MainActor func updateTrayText() {
    let sortedMonitors = sortedMonitors
    let focus = focus
    TrayMenuModel.shared.trayText = (activeMode?.takeIf { $0 != mainModeId }?.first.map { "[\($0.uppercased())] " } ?? "") +
        sortedMonitors
        .map {
            ($0.activeWorkspace == focus.workspace && sortedMonitors.count > 1 ? "*" : "") + $0.activeWorkspace.name
        }
        .joined(separator: " │ ")
    TrayMenuModel.shared.workspaces = Workspace.all.map {
        let apps = $0.allLeafWindowsRecursive.map { $0.app.name?.takeIf { !$0.isEmpty } }.filterNotNil().toSet()
        let dash = " - "
        let suffix = switch true {
            case !apps.isEmpty: dash + apps.sorted().joinTruncating(separator: ", ", length: 25)
            case $0.isVisible: dash + $0.workspaceMonitor.name
            default: ""
        }
        return WorkspaceViewModel(
            name: $0.name,
            suffix: suffix,
            isFocused: focus.workspace == $0,
            isEffectivelyEmpty: $0.isEffectivelyEmpty,
            isVisible: $0.isVisible,
        )
    }
    // Get workspaces from the first monitor for trayItems
    var items: [TrayItem] = []
    if let firstMonitor = sortedMonitors.first {
        // Get all non-empty workspaces for first monitor
        let firstMonitorWorkspaces = Workspace.all
            .filter { !$0.isEffectivelyEmpty && $0.workspaceMonitor.monitorId == firstMonitor.monitorId }
            .map { workspace in
                TrayItem(type: .workspace, name: workspace.name, isActive: workspace == focus.workspace)
            }
        
        // Add focused workspace if it's empty and on first monitor
        var allFirstMonitorItems = firstMonitorWorkspaces
        if focus.workspace.isEffectivelyEmpty && focus.workspace.workspaceMonitor.monitorId == firstMonitor.monitorId {
            allFirstMonitorItems.append(TrayItem(type: .workspace, name: focus.workspace.name, isActive: true))
        }
        
        items = allFirstMonitorItems.sorted { item1, item2 in
            return item1.name.localizedStandardCompare(item2.name) == .orderedAscending
        }
    }
    let mode = activeMode?.takeIf { $0 != mainModeId }?.first.map { TrayItem(type: .mode, name: $0.uppercased(), isActive: true) }
    if let mode {
        items.insert(mode, at: 0)
    }
    TrayMenuModel.shared.trayItems = items
    TrayMenuModel.shared.monitors = sortedMonitors.map { monitor in
        MonitorViewModel(monitorId: monitor.monitorId ?? 0)
    }
}

struct WorkspaceViewModel: Hashable {
    let name: String
    let suffix: String
    let isFocused: Bool
    let isEffectivelyEmpty: Bool
    let isVisible: Bool
}

struct MonitorViewModel: Hashable {
    let monitorId: Int
}

enum TrayItemType: String, Hashable {
    case mode
    case workspace
}

private let validLetters = "A" ... "Z"

struct TrayItem: Hashable, Identifiable {
    let type: TrayItemType
    let name: String
    let isActive: Bool
    var systemImageName: String? {
        // System image type is only valid for numbers 0 to 50 and single capital char workspace name
        if let number = Int(name) {
            guard number >= 0 && number <= 50 else { return nil }
        } else if name.count == 1 {
            guard validLetters.contains(name) else { return nil }
        } else {
            return nil
        }
        let lowercasedName = name.lowercased()
        switch type {
            case .mode:
                return "\(lowercasedName).circle"
            case .workspace:
                if isActive {
                    return "\(lowercasedName).square.fill"
                } else {
                    return "\(lowercasedName).square"
                }
        }
    }
    var id: String {
        return type.rawValue + name
    }
}
