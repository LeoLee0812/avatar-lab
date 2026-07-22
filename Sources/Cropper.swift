import Foundation
import AppKit
import CoreGraphics
import UniformTypeIdentifiers

// MARK: - 方形裁切与导出
// 图库里的图什么比例都有，头像要 1:1。这里在本地做裁切，不依赖任何服务端：
// 先按缩放取一个正方形取景框，再按焦点位置在原图上平移，最后缩放到目标边长。

struct CropOptions {
    /// 放大倍数，1.0 = 取景框贴住短边（取到最多画面）
    var zoom: Double = 1.0
    /// 水平焦点：0 最左，0.5 居中，1 最右
    var focusX: Double = 0.5
    /// 垂直焦点：0 最上，0.5 居中，1 最下。人脸多在上半部，所以默认略偏上
    var focusY: Double = 0.42
    /// 是否切成圆形（透明角），有些平台不自动裁圆
    var circular: Bool = false
}

enum Cropper {
    /// 按裁切参数产出一张边长 `size` 的方形图。
    static func square(_ image: NSImage, options: CropOptions, size: Int) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        let zoom = max(1.0, min(3.0, options.zoom))
        // 取景框边长：短边 / 缩放
        let side = (min(w, h) / CGFloat(zoom)).rounded(.down)
        guard side >= 1 else { return nil }
        // CGImage 的坐标原点在左上角，focusY 越大取景框越靠下，直接乘即可
        let x = ((w - side) * CGFloat(clamp(options.focusX))).rounded()
        let y = ((h - side) * CGFloat(clamp(options.focusY))).rounded()
        guard let cropped = cg.cropping(to: CGRect(x: x, y: y, width: side, height: side)) else { return nil }

        let out = CGSize(width: size, height: size)
        guard let ctx = CGContext(
            data: nil, width: size, height: size,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .high
        let rect = CGRect(origin: .zero, size: out)
        if options.circular {
            ctx.addEllipse(in: rect)
            ctx.clip()
        }
        ctx.draw(cropped, in: rect)
        guard let result = ctx.makeImage() else { return nil }
        return NSImage(cgImage: result, size: out)
    }

    private static func clamp(_ v: Double) -> Double { max(0, min(1, v)) }

    /// 存成 PNG 到 桌面/AvatarLab/，返回文件地址。
    @discardableResult
    static func savePNG(_ image: NSImage, tag: String) throws -> URL {
        guard let data = pngData(image) else { throw AppError("图片编码 PNG 失败") }
        let url = Output.newFileURL(tag: tag)
        try data.write(to: url)
        return url
    }

    /// 直接写盘失败时的兜底：弹「存储为」面板让用户自己挑位置。
    ///
    /// 为什么需要这条退路：本 app 是 ad-hoc 签名，每跑一次 build.sh 代码标识就变一次，
    /// 系统之前授予的「访问桌面」授权会跟着作废。而 LSUIElement 应用没有 Dock 图标，
    /// 重新授权的弹窗未必抢得到焦点，结果就是写盘被静默拒绝、用户完全不知道发生了什么。
    /// 「存储为」面板走的是系统 powerbox，用户选中的位置天然带授权，绕开 TCC。
    /// 返回 nil 表示用户主动点了取消。
    @discardableResult
    static func savePNGWithPanel(_ image: NSImage, tag: String) throws -> URL? {
        guard let data = pngData(image) else { throw AppError("图片编码 PNG 失败") }
        // 菜单栏应用默认不是前台，不激活的话面板会藏到别的窗口后面。
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSSavePanel()
        panel.title = "保存头像"
        panel.nameFieldStringValue = Output.newFileURL(tag: tag).lastPathComponent
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try data.write(to: url)
        return url
    }

    static func pngData(_ image: NSImage) -> Data? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        rep.size = image.size
        return rep.representation(using: .png, properties: [:])
    }

    /// 复制到剪贴板——上传头像时直接 ⌘V，比翻文件夹快。
    static func copyToPasteboard(_ image: NSImage) {
        let pb = NSPasteboard.general
        pb.clearContents()
        if let data = pngData(image), let rep = NSImage(data: data) {
            pb.writeObjects([rep])
        } else {
            pb.writeObjects([image])
        }
    }
}
