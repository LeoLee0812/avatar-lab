import SwiftUI
import AppKit

// MARK: - 裁切面板（浮窗内嵌，不弹独立窗口）
// 搜来的图和 AI 生成的图都走这里：调好取景 → 存桌面 或 复制到剪贴板 → 直接去上传。

struct CropPane: View {
    let subject: CropSubject
    let onBack: () -> Void

    @State private var opts = CropOptions()
    @State private var size = Settings.outputSize
    @State private var status = ""
    @State private var isError = false

    private let sizes = [128, 256, 512, 1024]

    /// 实时预览：直接拿一张 220px 的裁切结果显示，所见即所得
    private var preview: NSImage? {
        Cropper.square(subject.image, options: opts, size: 220)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    onBack()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.left")
                        Text("返回")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                Spacer()
                Text("裁成 1:1 头像").font(.system(size: 12, weight: .semibold))
                Spacer()
                Button("复位") { opts = CropOptions() }
                    .buttonStyle(.borderless)
                    .font(.system(size: 11))
            }

            if let img = preview {
                Image(nsImage: img)
                    .resizable()
                    .frame(width: 190, height: 190)
                    .background(CheckerBoard())
                    .clipShape(RoundedRectangle(cornerRadius: opts.circular ? 95 : 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: opts.circular ? 95 : 10)
                            .stroke(Color.gray.opacity(0.25))
                    )
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 190, height: 190)
                    .overlay(Text("这张图没法裁切").font(.system(size: 11)).foregroundStyle(.secondary))
            }

            VStack(spacing: 4) {
                slider("缩放", $opts.zoom, 1...3, String(format: "%.1f×", opts.zoom))
                slider("左右", $opts.focusX, 0...1, nil)
                slider("上下", $opts.focusY, 0...1, nil)
            }

            HStack(spacing: 8) {
                Picker("", selection: $size) {
                    ForEach(sizes, id: \.self) { Text("\($0)px").tag($0) }
                }
                .labelsHidden()
                .frame(width: 100)
                Toggle("圆形", isOn: $opts.circular)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                Spacer()
            }

            HStack(spacing: 8) {
                // 存完直接在访达里选中文件：浮窗一失焦就关，底部那行状态文字根本来不及看，
                // 加上图是落在「桌面/AvatarLab/」子文件夹里，光看桌面会以为没存上。
                Button("存到桌面", action: { save(reveal: true) })
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [])
                Button("复制", action: copy)
                    .keyboardShortcut("c", modifiers: .command)
                Button("打开文件夹", action: { NSWorkspace.shared.open(Output.folder) })
            }
            .controlSize(.small)

            if let credit = subject.credit {
                Text("来自 \(credit)（可免费商用、无需署名）")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            if !status.isEmpty {
                Text(status)
                    .font(.system(size: 10))
                    .foregroundStyle(isError ? .red : .secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
    }

    private func slider(_ label: String, _ value: Binding<Double>, _ range: ClosedRange<Double>, _ hint: String?) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .frame(width: 26, alignment: .leading)
            Slider(value: value, in: range)
            if let hint {
                Text(hint)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }

    /// 按当前参数出成品（导出尺寸，不是预览尺寸）
    private func result() -> NSImage? {
        Settings.outputSize = size
        return Cropper.square(subject.image, options: opts, size: size)
    }

    private func copy() {
        guard let img = result() else { status = "裁切失败"; isError = true; return }
        Cropper.copyToPasteboard(img)
        status = "已复制，去上传框 ⌘V"
        isError = false
    }

    private func save(reveal: Bool) {
        guard let img = result() else { status = "裁切失败"; isError = true; return }
        do {
            let url = try Cropper.savePNG(img, tag: subject.tag)
            status = "已存到 桌面/AvatarLab/\(url.lastPathComponent)"
            isError = false
            if reveal { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        } catch {
            // 直接写桌面失败，多半是系统权限拦的，退到「存储为」面板让用户挑位置。
            do {
                guard let url = try Cropper.savePNGWithPanel(img, tag: subject.tag) else {
                    status = "已取消保存"
                    isError = false
                    return
                }
                status = "已存到 \(url.lastPathComponent)"
                isError = false
                if reveal { NSWorkspace.shared.activateFileViewerSelecting([url]) }
            } catch let fallbackError {
                status = "保存失败：\(fallbackError.localizedDescription)"
                isError = true
            }
        }
    }
}

/// 透明背景的棋盘格（切圆形时能看清透明区域）
struct CheckerBoard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 8
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = 0
                var col = 0
                while x < size.width {
                    if (row + col) % 2 == 0 {
                        ctx.fill(Path(CGRect(x: x, y: y, width: s, height: s)),
                                 with: .color(.gray.opacity(0.16)))
                    }
                    x += s; col += 1
                }
                y += s; row += 1
            }
        }
    }
}
