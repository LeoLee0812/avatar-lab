import SwiftUI
import AppKit

// MARK: - 设置（浮窗版）
// 密钥全部存在本机 UserDefaults，仓库里不带任何默认值。

struct SettingsPane: View {
    let onDone: () -> Void

    @State private var pexels = Settings.pexelsKey
    @State private var pixabay = Settings.pixabayKey
    @State private var genKey = Settings.genKey
    @State private var genBase = Settings.genBase
    @State private var genModel = Settings.genModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                group("图库密钥（搜图用，免费）") {
                    field("Pexels", $pexels, secure: true)
                    field("Pixabay", $pixabay, secure: true)
                    HStack(spacing: 10) {
                        Link("申请 Pexels", destination: URL(string: "https://www.pexels.com/api/")!)
                        Link("申请 Pixabay", destination: URL(string: "https://pixabay.com/api/docs/")!)
                    }
                    .font(.system(size: 10))
                    Text("填任意一家就能搜，都填搜得更全；二次元/插画类结果来自 Pixabay。")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                group("AI 生图（可选，付费）") {
                    field("API Key", $genKey, secure: true)
                    field("接口地址", $genBase, secure: false, placeholder: Settings.defaultGenBase)
                    field("模型名", $genModel, secure: false, placeholder: Settings.defaultGenModel)
                    Text("走 OpenAI 兼容的 /images/generations，官方或中转都行。")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }

                Text("密钥只存本机 UserDefaults，不上传任何地方，也不进代码仓库。")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)

                HStack {
                    Spacer()
                    Button("取消", action: onDone)
                        .controlSize(.small)
                    Button("保存") {
                        Settings.pexelsKey = pexels
                        Settings.pixabayKey = pixabay
                        Settings.genKey = genKey
                        Settings.genBase = genBase
                        Settings.genModel = genModel
                        Settings.onboarded = true
                        onDone()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .keyboardShortcut(.return, modifiers: [])
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 400)
    }

    private func group<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.system(size: 11, weight: .medium))
            content()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 7).fill(Color.gray.opacity(0.08)))
    }

    private func field(_ label: String, _ text: Binding<String>, secure: Bool, placeholder: String = "") -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .frame(width: 62, alignment: .leading)
            if secure {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
            } else {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10, design: .monospaced))
            }
        }
    }
}
