import Foundation

// MARK: - 中文关键词 → 英文
// Pexels / Pixabay 的索引都是英文的，直接搜中文基本是零结果。
// 这里内置一份「头像常见题材」的小词表，命中就替换，没命中就原样透传
// （用户自己输英文时不受影响）。词表故意只覆盖高频词，不追求完备。

enum Keywords {
    static let table: [String: String] = [
        // 动物
        "猫": "cat", "猫咪": "cat", "小猫": "kitten", "橘猫": "orange cat",
        "狗": "dog", "小狗": "puppy", "柴犬": "shiba inu", "柯基": "corgi",
        "熊猫": "panda", "狐狸": "fox", "兔子": "rabbit", "老虎": "tiger",
        "狮子": "lion", "狼": "wolf", "鹿": "deer", "鸟": "bird",
        "水母": "jellyfish", "章鱼": "octopus", "鲸鱼": "whale", "恐龙": "dinosaur",
        // 自然 / 风景
        "山": "mountain", "雪山": "snow mountain", "海": "ocean", "海洋": "ocean",
        "海浪": "wave", "沙滩": "beach", "森林": "forest", "树": "tree",
        "花": "flower", "樱花": "cherry blossom", "向日葵": "sunflower",
        "星空": "starry sky", "银河": "galaxy", "月亮": "moon", "太阳": "sun",
        "云": "clouds", "日落": "sunset", "日出": "sunrise", "极光": "aurora",
        "湖": "lake", "沙漠": "desert", "雨": "rain", "雪": "snow",
        // 质感 / 抽象
        "抽象": "abstract", "渐变": "gradient", "纹理": "texture", "极简": "minimal",
        "几何": "geometric", "大理石": "marble", "液体": "liquid art",
        "烟雾": "smoke", "光影": "light and shadow", "霓虹": "neon",
        "水彩": "watercolor", "油画": "oil painting", "像素": "pixel art",
        "国风": "chinese ink painting", "水墨": "ink painting",
        // 人物 / 氛围
        "人像": "portrait", "剪影": "silhouette", "背影": "back view person",
        "宇航员": "astronaut", "机器人": "robot", "赛博朋克": "cyberpunk",
        "复古": "retro", "胶片": "film photography", "黑白": "black and white",
        "咖啡": "coffee", "书": "books", "音乐": "music", "吉他": "guitar",
        "城市": "city", "夜景": "night city", "街道": "street", "旅行": "travel",
        "游戏": "gaming", "电脑": "computer", "键盘": "keyboard", "代码": "code",
        // 情绪 / 风格词
        "治愈": "cozy calm", "孤独": "lonely", "梦幻": "dreamy", "酷": "cool",
        "可爱": "cute", "帅气": "cool portrait", "温暖": "warm tone",
        "高级感": "elegant minimal", "科技": "technology", "未来": "futuristic",
    ]

    /// 整句命中优先；否则按词表里出现的词做子串替换；一个中文字符都没有就原样返回。
    static func toEnglish(_ raw: String) -> String {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.contains(where: { $0.unicodeScalars.contains { (0x4E00...0x9FFF).contains($0.value) } }) else {
            return q   // 纯英文/数字，直接用
        }
        if let hit = table[q] { return hit }
        // 长词优先替换，避免「小猫」被「猫」抢先
        var result = q
        for (zh, en) in table.sorted(by: { $0.key.count > $1.key.count }) {
            if result.contains(zh) {
                result = result.replacingOccurrences(of: zh, with: " \(en) ")
            }
        }
        let cleaned = result
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty && $0.allSatisfy { c in c.isASCII } }
            .joined(separator: " ")
        return cleaned.isEmpty ? q : cleaned
    }

    /// 首页展示的灵感词，点一下直接搜。
    static let suggestions = [
        "猫", "柴犬", "宇航员", "抽象渐变", "雪山", "水母",
        "赛博朋克", "水墨", "极简几何", "星空", "复古胶片", "霓虹",
    ]
}

// MARK: - 随机主题
// 点开菜单栏就自动来一批，靠的是这里的主题池：随机主题 → 随机关键词 → 随机页码。

enum RandomTheme: String, CaseIterable, Identifiable {
    case anyTheme, anime, animal, nature, abstract, tech

    var id: String { rawValue }

    var label: String {
        switch self {
        case .anyTheme: return "随机"
        case .anime:    return "二次元"
        case .animal:   return "动物"
        case .nature:   return "风景"
        case .abstract: return "抽象"
        case .tech:     return "科技感"
        }
    }

    var emoji: String {
        switch self {
        case .anyTheme: return "🎲"
        case .anime:    return "🌸"
        case .animal:   return "🐱"
        case .nature:   return "🏔"
        case .abstract: return "🌀"
        case .tech:     return "🤖"
        }
    }

    /// 二次元/卡通只有插画库里才有（Pexels 是纯摄影库），走 illustration
    var preferIllustration: Bool { self == .anime }

    private var pool: [String] {
        switch self {
        case .anime:
            return ["anime girl", "anime boy", "anime character", "chibi character",
                    "manga portrait", "kawaii character", "cartoon avatar", "cute mascot"]
        case .animal:
            return ["cat portrait", "shiba inu", "corgi", "fox", "panda",
                    "owl", "penguin", "rabbit", "tiger portrait", "jellyfish"]
        case .nature:
            return ["snow mountain", "aurora", "starry sky", "sunset ocean",
                    "cherry blossom", "forest fog", "desert dune", "lavender field"]
        case .abstract:
            return ["abstract gradient", "liquid art", "marble texture", "geometric pattern",
                    "smoke art", "ink in water", "holographic texture", "minimal shapes"]
        case .tech:
            return ["cyberpunk neon", "robot", "astronaut", "circuit board",
                    "neon light", "futuristic city", "space nebula", "hologram"]
        case .anyTheme:
            return []
        }
    }

    /// 随机主题时从所有主题的池子里抽
    func randomKeyword() -> String {
        if self == .anyTheme {
            let all = RandomTheme.allCases.filter { $0 != .anyTheme }.flatMap(\.pool)
            return all.randomElement() ?? "abstract gradient"
        }
        return pool.randomElement() ?? "portrait"
    }
}
