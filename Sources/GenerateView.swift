import SwiftUI
import AppKit

// MARK: - AI 生成（浮窗版，搜不到合适的就自己画一张）

@MainActor
final class GenerateModel: ObservableObject {
    @Published var input = ""
    @Published var style: AvatarStyle = AvatarStyle.all[0]
    @Published var isLoading = false
    @Published var status = ""
    @Published var isError = false
    @Published var result: NSImage?

    func run() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            status = "先写一句想要什么，比如「戴耳机的橘猫」"
            isError = true
            return
        }
        isLoading = true
        isError = false
        status = "生成中… 通常 1-2 分钟"
        result = nil
        let prompt = style.fullPrompt(text)
        Task {
            do {
                result = try await ImageGen.generate(prompt: prompt, quality: .auto)
                status = "生成好了，点「裁成头像」"
            } catch {
                status = error.localizedDescription
                isError = true
            }
            isLoading = false
        }
    }
}

struct GeneratePane: View {
    @Binding var subject: CropSubject?
    let openSettings: () -> Void

    @StateObject private var m = GenerateModel()

    private let styleCols = [GridItem(.adaptive(minimum: 84, maximum: 120), spacing: 5)]

    var body: some View {
        if !Settings.canGenerate {
            Hint(icon: "wand.and.stars",
                 title: "AI 生成需要一把生图密钥",
                 detail: "任何 OpenAI 兼容的 /images/generations 服务都能接。只想白嫖的话用「搜图」就够。",
                 actionTitle: "去填",
                 action: openSettings)
        } else {
            VStack(spacing: 8) {
                TextField("想要什么？例如：戴耳机的橘猫", text: $m.input)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { m.run() }

                LazyVGrid(columns: styleCols, spacing: 5) {
                    ForEach(AvatarStyle.all) { s in
                        Button {
                            m.style = s
                        } label: {
                            Text("\(s.emoji) \(s.name)")
                                .font(.system(size: 10))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(m.style == s ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    if let img = m.result {
                        Image(nsImage: img)
                            .resizable()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        Button("裁成头像") {
                            subject = CropSubject(image: img, tag: m.style.id, credit: nil)
                        }
                        .controlSize(.small)
                    }
                    Spacer()
                    Button {
                        m.run()
                    } label: {
                        if m.isLoading { ProgressView().controlSize(.small) } else { Text("生成") }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(m.isLoading)
                }

                if !m.status.isEmpty {
                    Text(m.status)
                        .font(.system(size: 10))
                        .foregroundStyle(m.isError ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
    }
}
