#!/usr/bin/env python3
"""트로트안부 아이콘: 보라 반짝 배경 + 크림 카드 + '트로트안부' 큰 글씨."""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ICON = "/Users/leentj/IdeaProjects/trotcard/app/assets/icon"
S = 1024
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

CREAM = (251, 243, 220, 255)
GOLD = (227, 188, 85, 255)
RED = (225, 29, 72, 255)      # 하트/글씨 크림슨
INK = (150, 22, 48, 255)      # 글씨 진한 자주

# ── 카드(라운드 사각) + 그림자를 그려 넣는 함수 ──
CARD_L, CARD_T, CARD_R, CARD_B = 150, 168, 874, 856
RAD = 66
BORDER = 24


def draw_heart(d, cx, cy, w, color):
    """세 조각(두 원+삼각)으로 하트."""
    r = w / 4
    d.ellipse([cx - w / 2, cy - r, cx - w / 2 + 2 * r, cy + r], fill=color)
    d.ellipse([cx + w / 2 - 2 * r, cy - r, cx + w / 2, cy + r], fill=color)
    d.polygon([(cx - w / 2 + 0.06 * w, cy + 0.20 * r),
               (cx + w / 2 - 0.06 * w, cy + 0.20 * r),
               (cx, cy + w * 0.62)], fill=color)


def draw_card(base):
    # 그림자
    sh = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sh)
    ds.rounded_rectangle([CARD_L, CARD_T + 14, CARD_R, CARD_B + 20], RAD,
                         fill=(0, 0, 0, 90))
    sh = sh.filter(ImageFilter.GaussianBlur(22))
    base.alpha_composite(sh)

    card = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    dc = ImageDraw.Draw(card)
    dc.rounded_rectangle([CARD_L, CARD_T, CARD_R, CARD_B], RAD, fill=CREAM,
                         outline=GOLD, width=BORDER)
    base.alpha_composite(card)

    d = ImageDraw.Draw(base)
    cx = (CARD_L + CARD_R) // 2
    cy = (CARD_T + CARD_B) // 2

    # '트로트' / '안부' 두 줄, 크게 (하트 제거 → 편지 가득)
    def line(text, cy_, size, color):
        f = ImageFont.truetype(FONT, size, index=6)  # Bold
        bb = d.textbbox((0, 0), text, font=f)
        w, h = bb[2] - bb[0], bb[3] - bb[1]
        d.text((cx - w / 2 - bb[0], cy_ - h / 2 - bb[1]), text, font=f, fill=color)

    line("트로트", cy - 155, 255, INK)
    line("안부", cy + 155, 255, RED)


# ── icon.png (iOS 풀 아이콘): 보라 배경 위에 카드+글씨 ──
bg = Image.open(f"{ICON}/icon_bg.png").convert("RGBA").resize((S, S))
full = bg.copy()
draw_card(full)
full.convert("RGB").save(f"{ICON}/icon.png")

# ── icon_fg.png (안드 어댑티브 전경): 투명 위에 카드+글씨 ──
fg = Image.new("RGBA", (S, S), (0, 0, 0, 0))
draw_card(fg)
fg.save(f"{ICON}/icon_fg.png")

# 미리보기
full.convert("RGB").save("/private/tmp/claude-501/-Users-leentj-IdeaProjects-trotcard/c940fd81-8751-442c-970f-fc82c4d0de1a/scratchpad/icon_preview.png")
print("생성 완료: icon.png, icon_fg.png (icon_bg.png 유지)")
