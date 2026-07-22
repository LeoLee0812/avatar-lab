import Foundation
import AppKit

// MARK: - 运行时配置
// 所有密钥都由用户自己在设置页填写，存本地 UserDefaults。
// 仓库里不内置任何默认密钥——这是开源项目，代码里出现 key 就等于泄漏。

enum Settings {
    private static let d = UserDefaults.standard

    private enum K {
        static let pexels    = "avatarlab.pexelsKey"
        static let pixabay   = "avatarlab.pixabayKey"
        static let genKey    = "avatarlab.genKey"
        static let genBase   = "avatarlab.genBase"
        static let genModel  = "avatarlab.genModel"
        static let outSize   = "avatarlab.outputSize"
        static let onboarded = "avatarlab.onboarded"
    }

    /// 生图接口默认走 OpenAI 官方地址，用中转的人自行改成中转 base。
    static let defaultGenBase  = "https://api.openai.com/v1"
    static let defaultGenModel = "gpt-image-1"

    private static func str(_ key: String) -> String {
        (d.string(forKey: key) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func set(_ key: String, _ value: String) {
        let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.isEmpty { d.removeObject(forKey: key) } else { d.set(v, forKey: key) }
    }

    static var pexelsKey: String {
        get { str(K.pexels) }
        set { set(K.pexels, newValue) }
    }

    static var pixabayKey: String {
        get { str(K.pixabay) }
        set { set(K.pixabay, newValue) }
    }

    static var genKey: String {
        get { str(K.genKey) }
        set { set(K.genKey, newValue) }
    }

    /// 生图接口地址，末尾斜杠统一去掉，避免拼出 `//images/generations`。
    static var genBase: String {
        get {
            let v = str(K.genBase)
            let base = v.isEmpty ? defaultGenBase : v
            return base.hasSuffix("/") ? String(base.dropLast()) : base
        }
        set { set(K.genBase, newValue) }
    }

    static var genModel: String {
        get {
            let v = str(K.genModel)
            return v.isEmpty ? defaultGenModel : v
        }
        set { set(K.genModel, newValue) }
    }

    /// 导出头像的边长（像素），默认 512——各家网站头像上传的常见上限档。
    static var outputSize: Int {
        get {
            let v = d.integer(forKey: K.outSize)
            return v == 0 ? 512 : v
        }
        set { d.set(newValue, forKey: K.outSize) }
    }

    /// 是否已经过首次引导（没配任何搜图密钥时会弹引导卡片）。
    static var onboarded: Bool {
        get { d.bool(forKey: K.onboarded) }
        set { d.set(newValue, forKey: K.onboarded) }
    }

    /// 搜图至少要有一把 key 才能用。
    static var canSearch: Bool { !pexelsKey.isEmpty || !pixabayKey.isEmpty }

    /// 生图要有 key 才能用。
    static var canGenerate: Bool { !genKey.isEmpty }
}

// MARK: - 输出目录（桌面 / AvatarLab）

enum Output {
    static var folder: URL {
        let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let dir = desktop.appendingPathComponent("AvatarLab", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// 生成一个不重名的输出路径：`avatar-20260722-153012.png`
    static func newFileURL(tag: String) -> URL {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let safe = tag
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "-")
            .prefix(16)
        let name = safe.isEmpty
            ? "avatar-\(fmt.string(from: Date())).png"
            : "\(safe)-\(fmt.string(from: Date())).png"
        return folder.appendingPathComponent(name)
    }
}

// MARK: - 通用错误

struct AppError: LocalizedError {
    let msg: String
    var errorDescription: String? { msg }
    init(_ msg: String) { self.msg = msg }
}
