import SwiftUI
import AppKit

// MARK: - 搜图（主界面）
// 点开菜单栏就已经有一批头像候选了（随机主题自动搜）；
// 不满意点「换一批」，还不行就自己输关键词。

@MainActor
final class SearchModel: ObservableObject {
    @Published var query = ""
    @Published var photos: [Photo] = []
    @Published var isLoading = false
    @Published var status = ""
    @Published var isError = false
    @Published var kind: SearchKind = .photo
    /// 方图优先：接近 1:1 的排前面。之所以不做成「只显示方图」，是因为一过滤经常只剩一两张。
    @Published var squareFirst = true
    /// 当前这批是随机来的还是搜出来的，决定「换一批」按钮换什么
    @Published var lastRandomTheme: RandomTheme?

    private var page = 1

    var visible: [Photo] {
        guard squareFirst else { return photos }
        return photos.enumerated()
            .sorted { a, b in
                if a.element.isSquarish != b.element.isSquarish { return a.element.isSquarish }
                return a.offset < b.offset          // 同类保持原顺序，避免每次刷新乱跳
            }
            .map(\.element)
    }

    /// 首次打开（或刚填完 key）自动来一批，不用用户先动手。
    func bootstrapIfNeeded() {
        guard photos.isEmpty, !isLoading, Settings.canSearch else { return }
        random(theme: .anyTheme)
    }

    /// 随机一批：随机主题词 + 随机页码，每次点都不一样。
    func random(theme: RandomTheme) {
        lastRandomTheme = theme
        query = ""
        let word = theme.randomKeyword()
        kind = theme.preferIllustration ? .illustration : .photo
        load(keyword: word, page: Int.random(in: 1...4), note: "「\(word)」")
    }

    /// 用户自己输的词
    func search() {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        lastRandomTheme = nil
        page = 1
        load(keyword: q, page: 1, note: nil)
    }

    /// 换一批：随机来的就换个随机主题，搜出来的就翻下一页。
    func shuffle() {
        if let theme = lastRandomTheme {
            random(theme: theme)
        } else if photos.isEmpty || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            random(theme: .anyTheme)
        } else {
            page += 1
            load(keyword: query, page: page, note: nil)
        }
    }

    private func load(keyword: String, page: Int, note: String?) {
        isLoading = true
        isError = false
        status = note.map { "换了一批：\($0)" } ?? ""
        let k = kind
        Task {
            do {
                let result = try await ImageSearch.search(keyword, page: page, kind: k)
                photos = result
                if result.isEmpty {
                    status = "没搜到，换个词试试"
                    isError = true
                }
            } catch {
                status = error.localizedDescription
                isError = true
            }
            isLoading = false
        }
    }
}

struct SearchPane: View {
    @ObservedObject var m: SearchModel
    @Binding var subject: CropSubject?
    let openSettings: () -> Void

    @State private var picking: String?     // 正在下载大图的 photo id

    private let columns = [GridItem(.adaptive(minimum: 106, maximum: 130), spacing: 6)]

    var body: some View {
        VStack(spacing: 0) {
            if !Settings.canSearch {
                Hint(icon: "key",
                     title: "先填一把免费图库密钥",
                     detail: "Pexels / Pixabay 都能免费申请 API key，填任意一家就能开始找头像。",
                     actionTitle: "去填",
                     action: openSettings)
            } else {
                controls
                Divider()
                grid
                if !m.status.isEmpty {
                    Text(m.status)
                        .font(.system(size: 10))
                        .foregroundStyle(m.isError ? .red : .secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                }
            }
        }
        .onAppear { m.bootstrapIfNeeded() }
    }

    // 搜索框 + 换一批 + 主题
    private var controls: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("输个关键词，比如 猫 / 雪山 / 二次元", text: $m.query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit { m.search() }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(Color.gray.opacity(0.12)))

                Button {
                    m.shuffle()
                } label: {
                    if m.isLoading {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "dice")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(m.isLoading)
                .help("换一批")
            }

            // 主题：点一下直接随机来一批该主题的头像
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(RandomTheme.allCases) { t in
                        Button {
                            m.random(theme: t)
                        } label: {
                            Text("\(t.emoji) \(t.label)")
                                .font(.system(size: 10))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule().fill(m.lastRandomTheme == t
                                                   ? Color.accentColor.opacity(0.2)
                                                   : Color.gray.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 1)
            }

            HStack(spacing: 8) {
                Picker("", selection: $m.kind) {
                    ForEach(SearchKind.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 130)
                .labelsHidden()

                Toggle("方图优先", isOn: $m.squareFirst)
                    .toggleStyle(.checkbox)
                    .font(.system(size: 11))
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var grid: some View {
        ScrollView {
            if m.visible.isEmpty && m.isLoading {
                ProgressView().controlSize(.small).padding(.vertical, 40)
            } else if m.visible.isEmpty {
                Hint(icon: "photo.on.rectangle.angled",
                     title: "点骰子来一批头像",
                     detail: "或者上面输个关键词。图来自 Pexels / Pixabay 免费图库，可免费商用。")
            } else {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(m.visible) { photo in
                        Cell(photo: photo, busy: picking == photo.id) { pick(photo) }
                    }
                }
                .padding(10)
            }
        }
        .frame(height: gridHeight)
    }

    /// 结果少时不留大片空白，多时最高 300
    private var gridHeight: CGFloat {
        let rows = ceil(Double(max(m.visible.count, 1)) / 3)
        return min(300, CGFloat(rows) * 112 + 20)
    }

    private func pick(_ photo: Photo) {
        guard picking == nil else { return }
        picking = photo.id
        Task {
            let img = await ImageSearch.load(photo.fullURL)
            picking = nil
            guard let img else {
                m.status = "这张图下载失败，换一张"
                m.isError = true
                return
            }
            subject = CropSubject(image: img,
                                  tag: m.query.isEmpty ? "avatar" : m.query,
                                  credit: photo.credit)
        }
    }
}

/// 网格里的一格
private struct Cell: View {
    let photo: Photo
    let busy: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                AsyncImage(url: photo.thumbURL) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.gray.opacity(0.12)
                            .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                    default:
                        Color.gray.opacity(0.08).overlay(ProgressView().controlSize(.small))
                    }
                }
                .frame(width: 106, height: 106)
                .clipped()

                if busy {
                    Color.black.opacity(0.35)
                    ProgressView().controlSize(.small).tint(.white)
                }
            }
            .frame(width: 106, height: 106)
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("\(photo.credit) · \(photo.width)×\(photo.height)")
    }
}
