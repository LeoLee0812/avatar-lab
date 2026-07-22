# AvatarLab — 给电脑找一张能当头像的图

[![Swift](https://img.shields.io/badge/Swift-5.9+-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![macOS](https://img.shields.io/badge/macOS-13.0+-000000?style=flat-square&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![SwiftUI](https://img.shields.io/badge/SwiftUI-native-0A84FF?style=flat-square&logo=swift&logoColor=white)](https://developer.apple.com/xcode/swiftui/)
[![License](https://img.shields.io/badge/License-MIT-green?style=flat-square)](LICENSE)
[![Last commit](https://img.shields.io/github/last-commit/LeoLee0812/avatar-lab?style=flat-square&logo=github)](https://github.com/LeoLee0812/avatar-lab/commits)

手机上传头像很轻松，相册里翻两下就有；电脑上要传个头像，往往翻遍硬盘也找不出一张像样的方图。

AvatarLab 是一个**常驻菜单栏的轻量小工具**：点一下图标，浮窗里已经给你搜好了一批头像候选；不满意就点骰子换一批，或者自己输个关键词。选中一张 → 裁成 1:1 → 存桌面或直接复制去上传。

原生 SwiftUI，无 Dock 图标、无第三方依赖，`./build.sh` 编译即用。

```
点菜单栏 → 自动来一批头像 → 换一批 / 输关键词 / 挑主题 → 点一张 → 裁 1:1 → 存桌面 or ⌘V
```

## 核心功能：网络搜图

- **打开就有货**：点开菜单栏自动随机搜一批，不用先想关键词
- **换一批**：骰子按钮，随机主题 + 随机页码，每次都不一样；搜过词的话就翻下一页
- **六个主题一键切**：🎲 随机 / 🌸 二次元 / 🐱 动物 / 🏔 风景 / 🌀 抽象 / 🤖 科技感
- **两个免费图库并发搜**：[Pexels](https://www.pexels.com/) + [Pixabay](https://pixabay.com/)，结果交错混排，一家限流或没结果不影响另一家
- **照片 / 插画切换**：二次元、卡通头像走插画库（Pixabay 的 illustration），写实的走照片
- **方图优先**：Pexels 直接按 `orientation=square` 搜，接近 1:1 的排在最前，裁切时几乎不损失画面
- **中文直接搜**：内置约 90 个头像常见题材的中英词表（猫 / 雪山 / 赛博朋克 / 水墨 / 抽象渐变……），命中自动换英文，没命中原样透传
- 两家图库都是免费商用授权（Pexels License / Pixabay Content License），**无需署名**，界面里仍显示作者名，想标出处随时可取

## 裁成头像

选中任意一张图，浮窗直接切到裁切面板：

- 缩放 + 左右 / 上下焦点三个滑块调取景（默认焦点略偏上，因为主体多在画面上半部）
- 可切成圆形（透明角），预览带棋盘格背景
- 导出 128 / 256 / 512 / 1024 px
- **默认存到 `桌面/AvatarLab/`**（回车），或 **⌘C 复制到剪贴板**——上传框里 ⌘V 就完事，连文件夹都不用翻

## 补充功能：AI 生成

搜不到合适的就自己画一张。内置 12 个头像风格预设，全部按 1:1 构图、主体居中、干净背景、无文字水印来出图：

| | | | |
|---|---|---|---|
| 🧸 3D 卡通 | 🌸 日系动漫 | 🎨 扁平插画 | 👾 像素风 |
| ✏️ 极简线条 | 💧 水彩 | 🖌 国风水墨 | 🌃 赛博朋克 |
| 📷 写实摄影 | 🔷 低多边形 | 🏷 贴纸涂鸦 | 🌀 抽象质感 |

走标准的 OpenAI 兼容 `/images/generations` 接口，**接口地址和模型名都在设置里改**，官方、Azure、各类中转都能接。生成的图同样进裁切面板。

这是付费能力，纯白嫖的话只用「搜图」就够了。

## 安装

```bash
git clone https://github.com/LeoLee0812/avatar-lab.git
cd avatar-lab
./build.sh                          # 编译并打包成 build/AvatarLab.app
cp -R "build/AvatarLab.app" /Applications/
open "/Applications/AvatarLab.app"   # 图标出现在菜单栏，没有 Dock 图标
```

要求 macOS 13+、已装 Xcode 命令行工具（`xcode-select --install`）。ad-hoc 本地签名，首次打开若被 Gatekeeper 拦，右键 →「打开」。

开机自启：系统设置 → 通用 → 登录项 → 加上 `AvatarLab.app`。

## 配置密钥

**仓库里不含任何密钥**，全部由你自己在 App 的设置页（右上角齿轮）填写，存在本机 UserDefaults，不上传任何地方。

| 用途 | 去哪申请 | 免费额度 |
|------|----------|----------|
| Pexels（搜图，主用） | https://www.pexels.com/api/ | 200 次/小时、2 万次/月 |
| Pixabay（搜图，并发补充） | https://pixabay.com/api/docs/ | 100 次/分钟 |
| OpenAI 兼容生图（可选） | 你自己的服务商 | 付费 |

两把图库 key 填任意一家就能开始搜，都填搜得更全。

## 源码结构

```
Sources/
  Config.swift        密钥与输出目录（无内置默认值）
  ImageSearch.swift   ★ Pexels + Pixabay 并发搜图
  Cropper.swift       1:1 裁切、圆形遮罩、PNG 导出、剪贴板
  ImageGen.swift      OpenAI 兼容生图 + 12 个头像风格预设
  Keywords.swift      中文词表 + 六个随机主题的关键词池
  App.swift           菜单栏入口与浮窗骨架
  SearchView.swift    搜图页    GenerateView.swift  生成页
  CropSheet.swift     裁切面板  SettingsView.swift  设置
build.sh              编译 + 打包 + ad-hoc 签名
```

## 许可

代码 [MIT](LICENSE)。搜到的图片版权归各图库与作者，按 Pexels / Pixabay 各自的 License 使用。
