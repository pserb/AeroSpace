import Common
import Foundation
import SwiftUI

@MainActor
struct MenuBarLabel: View {
    @Environment(\.colorScheme) var menuColorScheme: ColorScheme
    var text: String
    var textStyle: MenuBarTextStyle
    var color: Color?
    var trayItems: [TrayItem]?
    var workspaces: [WorkspaceViewModel]?
    var monitors: [MonitorViewModel]?

    let hStackSpacing = CGFloat(6)
    let itemSize = CGFloat(40)
    let itemBorderSize = CGFloat(4)
    let itemPadding = CGFloat(8)
    let itemCornerRadius = CGFloat(6)

    private var finalColor: Color {
        return color ?? (menuColorScheme == .dark ? Color.white : Color.black)
    }

    init(_ text: String, textStyle: MenuBarTextStyle = .monospaced, color: Color? = nil, trayItems: [TrayItem]? = nil, workspaces: [WorkspaceViewModel]? = nil, monitors: [MonitorViewModel]? = nil) {
        self.text = text
        self.textStyle = textStyle
        self.color = color
        self.trayItems = trayItems
        self.workspaces = workspaces
        self.monitors = monitors
    }

    var body: some View {
        if #available(macOS 14, *) { // https://github.com/nikitabobko/AeroSpace/issues/1122
            let renderer = ImageRenderer(content: menuBarContent)
            if let cgImage = renderer.cgImage {
                // Using scale: 1 results in a blurry image for unknown reasons
                Image(cgImage, scale: 2, label: Text(text))
            } else {
                // In case image can't be rendered fallback to plain text
                Text(text)
            }
        } else { // macOS 13 and lower
            Text(text)
        }
    }

    var menuBarContent: some View {
        return ZStack {
            if let trayItems {
                HStack(spacing: hStackSpacing) {
                    ForEach(trayItems, id: \.id) { item in
                        let isEmptyFocused = item.isActive && (workspaces?.first { $0.name == item.name }?.isEffectivelyEmpty ?? false)
                        itemView(for: item)
                            .opacity(isEmptyFocused ? 0.6 : 1.0)
                        if item.type == .mode {
                            Text(":")
                                .font(.system(.largeTitle, design: textStyle.design))
                                .foregroundStyle(finalColor)
                                .bold()
                        }
                    }
                    if let workspaces, let monitors {
                        // Simple approach: for each remaining monitor, show its workspaces with a pipe
                        
                        ForEach(Array(monitors.dropFirst()), id: \.monitorId) { monitor in
                            // Compute all workspaces for this monitor (non-empty + empty focused)
                            let nonEmptyWorkspaces = workspaces.filter { workspace in
                                !workspace.isEffectivelyEmpty &&
                                Workspace.get(byName: workspace.name).workspaceMonitor.monitorId == monitor.monitorId
                            }
                            
                            let focusedWorkspace = workspaces.first { $0.isFocused }
                            let emptyFocusedWorkspace: [WorkspaceViewModel] = {
                                if let focused = focusedWorkspace,
                                   focused.isEffectivelyEmpty,
                                   Workspace.get(byName: focused.name).workspaceMonitor.monitorId == monitor.monitorId {
                                    return [focused]
                                }
                                return []
                            }()
                            
                            let monitorWorkspaces = nonEmptyWorkspaces + emptyFocusedWorkspace
                            
                            if !monitorWorkspaces.isEmpty {
                                Group {
                                    Text("|")
                                        .font(.system(.largeTitle))
                                        .foregroundStyle(finalColor)
                                        .opacity(0.6)
                                        .bold()
                                        .padding(.bottom, 6)
                                    ForEach(monitorWorkspaces.sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending }), id: \.name) { workspace in
                                        let isEmptyFocused = workspace.isFocused && workspace.isEffectivelyEmpty
                                        itemView(for: TrayItem(type: .workspace, name: workspace.name, isActive: workspace.isFocused))
                                            .opacity(isEmptyFocused ? 0.6 : 1.0)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(height: itemSize)
            } else {
                HStack(spacing: hStackSpacing) {
                    Text(text)
                        .font(.system(.largeTitle, design: textStyle.design))
                        .foregroundStyle(finalColor)
                }
            }
        }
    }

    @ViewBuilder
    fileprivate func itemView(for item: TrayItem) -> some View {
        // If workspace name contains emojis we use the plain emoji in text to avoid visibility issues scaling the emoji to fit the squares
        if item.name.containsEmoji() {
            Text(item.name)
                .font(.system(.largeTitle))
                .foregroundStyle(finalColor)
                .frame(height: itemSize)
        } else {
            if let imageName = item.systemImageName {
                Image(systemName: imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(finalColor)
                    .frame(width: itemSize, height: itemSize)
            } else {
                let text = Text(item.name)
                    .font(.system(.largeTitle))
                    .bold()
                    .frame(width: itemSize, height: itemSize)
                if item.isActive {
                    ZStack {
                        text.background {
                            RoundedRectangle(cornerRadius: itemCornerRadius, style: .circular)
                        }
                        text.blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .foregroundStyle(finalColor)
                    .frame(width: itemSize, height: itemSize)
                } else {
                    text.background {
                        RoundedRectangle(cornerRadius: itemCornerRadius, style: .circular)
                            .strokeBorder(lineWidth: itemBorderSize)
                    }
                    .foregroundStyle(finalColor)
                    .frame(width: itemSize, height: itemSize)
                }
            }
        }
    }
}

enum MenuBarTextStyle: String {
    case monospaced
    case system
    var design: Font.Design {
        switch self {
            case .monospaced:
                return .monospaced
            case .system:
                return .default
        }
    }
}

extension String {
    fileprivate func containsEmoji() -> Bool {
        unicodeScalars.contains { $0.properties.isEmoji && $0.properties.isEmojiPresentation }
    }
}
