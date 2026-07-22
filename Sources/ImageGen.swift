import Foundation
import AppKit

// MARK: - AI 生成头像（搜图之外的补充）
// 走 OpenAI 兼容的 /images/generations 接口：官方、Azure、各种中转都能用，
// 地址和模型名都在设置里改，代码不绑定任何一家。

/// 头像风格预设。每个预设是一段追加到用户描述后面的英文风格提示词，
/// 统一强制 1:1 构图、主体居中、留白干净——这三条是头像好不好用的关键。
struct AvatarStyle: Identifiable, Hashable {
    let id: String
    let name: String
    let emoji: String
    let prompt: String

    static let all: [AvatarStyle] = [
        .init(id: "3d",      name: "3D 卡通", emoji: "🧸",
              prompt: "3D cartoon character avatar, Pixar-like stylized render, soft studio lighting, rounded shapes, vivid but harmonious colors"),
        .init(id: "anime",   name: "日系动漫", emoji: "🌸",
              prompt: "Japanese anime style avatar illustration, clean cel shading, expressive eyes, soft gradient background"),
        .init(id: "flat",    name: "扁平插画", emoji: "🎨",
              prompt: "flat vector illustration avatar, bold simple shapes, limited color palette, thick clean outlines, no gradients"),
        .init(id: "pixel",   name: "像素风", emoji: "👾",
              prompt: "16-bit pixel art avatar, crisp pixel grid, retro game palette, solid background"),
        .init(id: "line",    name: "极简线条", emoji: "✏️",
              prompt: "minimal single-line art avatar, monochrome ink strokes on off-white background, lots of negative space"),
        .init(id: "water",   name: "水彩", emoji: "💧",
              prompt: "watercolor painting avatar, soft bleeding pigments, visible paper texture, gentle pastel tones"),
        .init(id: "ink",     name: "国风水墨", emoji: "🖌",
              prompt: "Chinese ink wash painting avatar, expressive brush strokes, rice paper texture, restrained color, elegant negative space"),
        .init(id: "cyber",   name: "赛博朋克", emoji: "🌃",
              prompt: "cyberpunk avatar, neon rim light, magenta and cyan glow, dark moody background, futuristic detail"),
        .init(id: "photo",   name: "写实摄影", emoji: "📷",
              prompt: "photorealistic portrait-style avatar, shallow depth of field, natural soft light, clean blurred background, shot on 85mm lens"),
        .init(id: "lowpoly", name: "低多边形", emoji: "🔷",
              prompt: "low poly geometric avatar, faceted triangular shading, cool gradient background, crisp edges"),
        .init(id: "sticker", name: "贴纸涂鸦", emoji: "🏷",
              prompt: "die-cut sticker style avatar, thick white border, playful doodle linework, flat bright colors"),
        .init(id: "abstract", name: "抽象质感", emoji: "🌀",
              prompt: "abstract textured avatar, no human figure, organic gradient blobs, grainy risograph texture, calm color harmony"),
    ]

    /// 拼出最终提示词：用户描述 + 风格 + 头像通用约束。
    func fullPrompt(_ userInput: String) -> String {
        let subject = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = subject.isEmpty ? "an appealing abstract subject" : subject
        return "\(base). \(prompt). Square 1:1 profile picture composition, subject centered and clearly readable when displayed small, simple uncluttered background, no text, no watermark, no logo."
    }
}

enum GenQuality: String, CaseIterable, Identifiable {
    case auto, low, medium, high
    var id: String { rawValue }
    var label: String {
        switch self {
        case .auto:   return "默认（不指定）"
        case .low:    return "快（低）"
        case .medium: return "标准（中）"
        case .high:   return "精细（高）"
        }
    }
}

enum ImageGen {
    private static var session: URLSession {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 280    // 生图普遍 1-2 分钟，超时给足
        c.timeoutIntervalForResource = 300
        return URLSession(configuration: c)
    }

    /// 生成一张 1024x1024 的头像原图（还没裁切，交给 Cropper 出成品）。
    static func generate(prompt: String, quality: GenQuality) async throws -> NSImage {
        guard Settings.canGenerate else {
            throw AppError("还没填生图密钥，去设置里填一个 OpenAI 兼容的 API key")
        }
        guard let url = URL(string: "\(Settings.genBase)/images/generations") else {
            throw AppError("生图接口地址无效：\(Settings.genBase)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(Settings.genKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 280

        var body: [String: Any] = [
            "model": Settings.genModel,
            "prompt": prompt,
            "size": "1024x1024",     // 头像固定 1:1
            "n": 1,
        ]
        // dall-e-3 之类的模型不认 low/medium/high，所以「默认」档干脆不传这个字段
        if quality != .auto { body["quality"] = quality.rawValue }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AppError("生图接口无响应") }
        guard (200..<300).contains(http.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw AppError("生图接口返回 \(http.statusCode)：\(text.prefix(300))")
        }
        // 返回优先 b64_json，部分中转只回 url（要再拉一次）
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let arr = json["data"] as? [[String: Any]],
              let first = arr.first else {
            throw AppError("生图返回格式无法解析")
        }
        if let b64 = first["b64_json"] as? String,
           let d = Data(base64Encoded: b64),
           let img = NSImage(data: d) {
            return img
        }
        if let urlStr = first["url"] as? String, let imgURL = URL(string: urlStr) {
            let (d, _) = try await session.data(from: imgURL)
            if let img = NSImage(data: d) { return img }
        }
        throw AppError("生图返回里既没有 b64_json 也没有可用的 url")
    }
}
