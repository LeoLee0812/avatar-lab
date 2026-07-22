import Foundation
import AppKit

// MARK: - 搜图（本 App 的主打功能）
// 两个免费图库并发搜索：Pexels + Pixabay。
// 两家都是免费商用授权（Pexels License / Pixabay Content License），无需署名，
// 但结果里仍带上作者名，方便想标注出处的人自取。

enum Provider: String {
    case pexels = "Pexels"
    case pixabay = "Pixabay"
}

struct Photo: Identifiable, Hashable {
    let id: String
    /// 网格缩略图地址（小图，省流量）
    let thumbURL: URL
    /// 裁切用的大图地址
    let fullURL: URL
    let width: Int
    let height: Int
    /// 作者 / 平台
    let credit: String
    let provider: Provider

    /// 是否接近方形（头像友好，裁切时几乎不损失画面）
    var isSquarish: Bool {
        guard width > 0, height > 0 else { return false }
        let r = Double(width) / Double(height)
        return r > 0.85 && r < 1.18
    }
}

/// 搜什么类型的图：头像要么用照片，要么用插画（二次元/卡通头像走这条）。
enum SearchKind: String, CaseIterable, Identifiable {
    case photo, illustration
    var id: String { rawValue }
    var label: String {
        switch self {
        case .photo:        return "照片"
        case .illustration: return "插画"
        }
    }
}

enum ImageSearch {
    private static let session: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 15
        c.requestCachePolicy = .returnCacheDataElseLoad   // 缩略图重复滚动时走本地缓存
        return URLSession(configuration: c)
    }()

    /// 并发搜两家，把结果交错合并（一条 Pexels 一条 Pixabay），保证网格里两家都露脸。
    /// 任何一家失败都不影响另一家；两家都没配 key 时抛错。
    /// 插画类只有 Pixabay 有（Pexels 是纯摄影库），所以这时只搜 Pixabay。
    static func search(_ query: String, page: Int = 1, kind: SearchKind = .photo) async throws -> [Photo] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        guard Settings.canSearch else {
            throw AppError("还没填图库密钥，点右上角齿轮去设置里填 Pexels 或 Pixabay 的 key（都免费）")
        }
        // 图库只认英文，中文关键词先查内置词表翻一下
        let keyword = Keywords.toEnglish(q)

        async let a = safeSearch {
            kind == .photo ? try await searchPexelsSquareFirst(keyword, page: page) : []
        }
        async let b = safeSearch { try await searchPixabay(keyword, page: page, kind: kind) }
        let (pexels, pixabay) = await (a, b)

        if pexels.isEmpty && pixabay.isEmpty { return [] }
        return interleave(pexels, pixabay)
    }

    /// 单家搜索失败只当作「没结果」，不打断整体（key 没填 / 限流 / 网络抖动都归这里）。
    private static func safeSearch(_ work: () async throws -> [Photo]) async -> [Photo] {
        do { return try await work() } catch {
            NSLog("[AvatarLab] 搜图失败：%@", error.localizedDescription)
            return []
        }
    }

    private static func interleave(_ a: [Photo], _ b: [Photo]) -> [Photo] {
        var out: [Photo] = []
        var i = 0
        while i < max(a.count, b.count) {
            if i < a.count { out.append(a[i]) }
            if i < b.count { out.append(b[i]) }
            i += 1
        }
        return out
    }

    // MARK: Pexels

    private struct PexelsResp: Decodable {
        struct Photo: Decodable {
            struct Src: Decodable {
                let original: String?
                let large2x: String?
                let large: String?
                let medium: String?
            }
            let id: Int
            let width: Int
            let height: Int
            let photographer: String
            let src: Src
        }
        let photos: [Photo]
    }

    /// 头像优先要方图：先用 orientation=square 搜一遍，结果太少再补一遍不限比例的。
    private static func searchPexelsSquareFirst(_ keyword: String, page: Int) async throws -> [Photo] {
        let square = try await searchPexels(keyword, page: page, orientation: "square")
        if square.count >= 8 { return square }
        let rest = (try? await searchPexels(keyword, page: page, orientation: nil)) ?? []
        let seen = Set(square.map(\.id))
        return square + rest.filter { !seen.contains($0.id) }
    }

    private static func searchPexels(_ keyword: String, page: Int, orientation: String?) async throws -> [Photo] {
        let key = Settings.pexelsKey
        guard !key.isEmpty else { return [] }
        var comp = URLComponents(string: "https://api.pexels.com/v1/search")!
        comp.queryItems = [
            .init(name: "query", value: keyword),
            .init(name: "per_page", value: "30"),
            .init(name: "page", value: String(page)),
        ]
        if let orientation { comp.queryItems?.append(.init(name: "orientation", value: orientation)) }
        var req = URLRequest(url: comp.url!)
        // Pexels 的 Authorization 直接放 key 值，不带 Bearer 前缀
        req.setValue(key, forHTTPHeaderField: "Authorization")
        let data = try await request(req, who: "Pexels")
        let resp = try JSONDecoder().decode(PexelsResp.self, from: data)
        return resp.photos.compactMap { p in
            guard let full = URL(string: p.src.large2x ?? p.src.large ?? p.src.original ?? ""),
                  let thumb = URL(string: p.src.medium ?? p.src.large ?? full.absoluteString)
            else { return nil }
            return Photo(id: "pexels-\(p.id)", thumbURL: thumb, fullURL: full,
                         width: p.width, height: p.height,
                         credit: "\(p.photographer) / Pexels", provider: .pexels)
        }
    }

    // MARK: Pixabay

    private struct PixabayResp: Decodable {
        struct Hit: Decodable {
            let id: Int
            let imageWidth: Int
            let imageHeight: Int
            let user: String
            let largeImageURL: String?
            let webformatURL: String?
            let previewURL: String?
        }
        let hits: [Hit]
    }

    private static func searchPixabay(_ keyword: String, page: Int, kind: SearchKind) async throws -> [Photo] {
        let key = Settings.pixabayKey
        guard !key.isEmpty else { return [] }
        var comp = URLComponents(string: "https://pixabay.com/api/")!
        comp.queryItems = [
            .init(name: "key", value: key),
            .init(name: "q", value: keyword),
            .init(name: "image_type", value: kind == .illustration ? "illustration" : "photo"),
            .init(name: "per_page", value: "30"),
            .init(name: "page", value: String(page)),
            .init(name: "safesearch", value: "true"),
        ]
        let data = try await request(URLRequest(url: comp.url!), who: "Pixabay")
        let resp = try JSONDecoder().decode(PixabayResp.self, from: data)
        return resp.hits.compactMap { h in
            guard let full = URL(string: h.largeImageURL ?? h.webformatURL ?? ""),
                  let thumb = URL(string: h.webformatURL ?? h.previewURL ?? full.absoluteString)
            else { return nil }
            return Photo(id: "pixabay-\(h.id)", thumbURL: thumb, fullURL: full,
                         width: h.imageWidth, height: h.imageHeight,
                         credit: "\(h.user) / Pixabay", provider: .pixabay)
        }
    }

    // MARK: 公共

    private static func request(_ req: URLRequest, who: String) async throws -> Data {
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw AppError("\(who)：无响应") }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 || http.statusCode == 403 {
                throw AppError("\(who) 密钥无效或已过期（HTTP \(http.statusCode)）")
            }
            if http.statusCode == 429 {
                throw AppError("\(who) 触发限流，等一会儿再搜")
            }
            throw AppError("\(who) 返回 HTTP \(http.statusCode)")
        }
        return data
    }

    /// 下载一张图（缩略图和大图共用），失败返回 nil。
    static func load(_ url: URL) async -> NSImage? {
        do {
            let (data, _) = try await session.data(from: url)
            return NSImage(data: data)
        } catch {
            return nil
        }
    }
}
