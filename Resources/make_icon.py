# 把 AI 生成的图标底图裁成标准 macOS squircle 图标（1024 画布 + 透明边距 + 平滑圆角）
from PIL import Image, ImageDraw

SRC = "icon_raw.png"
OUT = "icon_1024.png"

CANVAS = 1024      # 最终画布
CONTENT = 902      # 内容方块尺寸（四周留 ~61px 透明边距，贴近 Apple 规范）
RADIUS = 202       # squircle 圆角半径（约 content*0.2237）
SS = 4             # 超采样倍数，边缘更平滑

img = Image.open(SRC).convert("RGBA")

# 1) 去掉白色背景边：找非白像素的 bbox
rgb = img.convert("RGB")
w, h = rgb.size
px = rgb.load()
def is_white(p): return p[0] > 245 and p[1] > 245 and p[2] > 245
minx, miny, maxx, maxy = w, h, 0, 0
step = 2
for y in range(0, h, step):
    for x in range(0, w, step):
        if not is_white(px[x, y]):
            if x < minx: minx = x
            if y < miny: miny = y
            if x > maxx: maxx = x
            if y > maxy: maxy = y
# 稍微内缩，去掉底图自带圆角处残留的白角
pad = 4
minx, miny = max(0, minx + pad), max(0, miny + pad)
maxx, maxy = min(w, maxx - pad), min(h, maxy - pad)
content = img.crop((minx, miny, maxx, maxy))

# 2) 拉成正方形内容块
content = content.resize((CONTENT, CONTENT), Image.LANCZOS)

# 3) 超采样画 squircle 遮罩
mask = Image.new("L", (CONTENT * SS, CONTENT * SS), 0)
d = ImageDraw.Draw(mask)
d.rounded_rectangle([0, 0, CONTENT * SS - 1, CONTENT * SS - 1], radius=RADIUS * SS, fill=255)
mask = mask.resize((CONTENT, CONTENT), Image.LANCZOS)

# 4) 应用遮罩，居中贴到透明画布
content.putalpha(mask)
canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
off = (CANVAS - CONTENT) // 2
canvas.paste(content, (off, off), content)
canvas.save(OUT)
print("已生成", OUT)
