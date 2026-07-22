import SwiftUI
import AppKit

// MARK: - 应用入口（常驻菜单栏，无 Dock 图标）
// 手机相册里随手就有头像，电脑上却总也翻不出一张能用的方图。
// AvatarLab 就干这一件事：点开菜单栏 → 立刻给一批头像候选 → 不满意就换一批或自己输词 → 裁成 1:1 存桌面。

@main
struct AvatarLabApp: App {
    /// 提到 App 层：菜单栏浮窗关掉再打开，上一批结果还在，不用重搜。
    @StateObject private var search = SearchModel()

    var body: some Scene {
        // 图标必须选 SF Symbols 早期就有、且 macOS 13 一定存在的名字。
        // 之前用的 person.crop.square.badge.magnifyingglass 压根不存在，
        // MenuBarExtra 拿到 nil 就画了一块空白——图标"隐身"，只剩一块看不见的可点区域。
        MenuBarExtra("AvatarLab", systemImage: "person.crop.square") {
            RootView(search: search)
        }
        .menuBarExtraStyle(.window)
    }
}

/// 待裁切的对象：搜来的图和 AI 生成的图共用同一套裁切/导出流程。
struct CropSubject: Identifiable {
    let id = UUID()
    let image: NSImage
    /// 导出文件名前缀
    let tag: String
    /// 出处说明（搜图有，生图没有）
    let credit: String?
}

enum Panel {
    case search      // 搜图（主界面）
    case generate    // AI 生成
    case settings
}

struct RootView: View {
    @ObservedObject var search: SearchModel

    @State private var panel: Panel = .search
    @State private var subject: CropSubject?

    var body: some View {
        VStack(spacing: 0) {
            // 裁切态占满整个浮窗，其余都藏起来，保持轻量
            if let s = subject {
                CropPane(subject: s, onBack: { subject = nil })
            } else {
                header
                Divider()
                switch panel {
                case .search:
                    SearchPane(m: search, subject: $subject, openSettings: { panel = .settings })
                case .generate:
                    GeneratePane(subject: $subject, openSettings: { panel = .settings })
                case .settings:
                    SettingsPane(onDone: {
                        panel = .search
                        search.bootstrapIfNeeded()   // 刚填完 key，顺手来一批
                    })
                }
            }
        }
        .frame(width: 400)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.crop.square.badge.magnifyingglass")
                .foregroundStyle(.tint)
            Text("AvatarLab").font(.system(size: 13, weight: .semibold))

            Spacer()

            // 搜图 / AI 生成 切换
            Picker("", selection: Binding(
                get: { panel == .generate ? 1 : 0 },
                set: { panel = $0 == 1 ? .generate : .search }
            )) {
                Text("搜图").tag(0)
                Text("AI").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 96)
            .labelsHidden()

            Button { panel = .settings } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("设置密钥与导出尺寸")
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                .buttonStyle(.borderless)
                .help("退出")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }
}

// MARK: - 小组件

/// 空态 / 引导卡片（浮窗版，比窗口版紧凑）
struct Hint: View {
    let icon: String
    let title: String
    let detail: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(.secondary)
            Text(title).font(.system(size: 12, weight: .medium))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
    }
}
