from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "assets"
OUT.mkdir(parents=True, exist_ok=True)
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"


def font(size):
    return ImageFont.truetype(FONT, size=size, index=0)


def draw_card(draw, xy, alpha=255, title="GPT NEEDS YOU", subtitle="확인이 필요한 대화"):
    x, y, w, h = xy
    fill = (15, 28, 47, alpha)
    draw.rounded_rectangle((x, y, x+w, y+h), 24, fill=fill, outline=(79, 214, 194, alpha), width=3)
    draw.rounded_rectangle((x+22, y+20, x+46, y+44), 9, fill=(108, 239, 210, alpha))
    draw.text((x+60, y+17), title, font=font(19), fill=(218, 255, 245, alpha))
    draw.text((x+26, y+67), subtitle, font=font(23), fill=(255, 255, 255, alpha))
    draw.rounded_rectangle((x+25, y+115, x+w-25, y+164), 10, fill=(255, 255, 255, 22), outline=(255, 255, 255, 36), width=1)
    draw.text((x+42, y+125), "GitHub 인증 · 계정 확인 예시", font=font(17), fill=(197, 216, 230, alpha))
    draw.rounded_rectangle((x+25, y+h-59, x+190, y+h-22), 10, fill=(108, 239, 210, alpha))
    draw.text((x+52, y+h-54), "채팅 열기", font=font(17), fill=(8, 30, 28, alpha))


def make(variant):
    width, height = 1200, 675
    image = Image.new("RGBA", (width, height))
    pixels = image.load()
    for y in range(height):
        for x in range(width):
            t = x / width
            glow = max(0.0, 1 - (((x - 930) / 500) ** 2 + ((y - 80) / 500) ** 2) ** 0.5)
            pixels[x, y] = (
                int(9 + 17*t + 17*glow),
                int(17 + 25*t + 61*glow),
                int(31 + 27*t + 63*glow),
                255,
            )
    draw = ImageDraw.Draw(image, "RGBA")
    draw.rounded_rectangle((62, 54, 420, 94), 18, fill=(100, 226, 196, 32), outline=(114, 236, 205, 100), width=1)
    draw.text((82, 59), "OPEN SOURCE  ·  macOS + Windows", font=font(19), fill=(158, 246, 222, 255))
    draw.text((62, 144), "놓칠 뻔한 알림을", font=font(48), fill=(247, 250, 255, 255))
    draw.text((62, 204), "붙잡아 두세요", font=font(57), fill=(138, 244, 215, 255))
    draw.text((65, 292), "채팅 제목과 요청을 확인할 때까지", font=font(25), fill=(213, 224, 241, 255))
    draw.text((65, 331), "화면에 남는 ChatGPT · Codex 데스크톱 알림", font=font(23), fill=(213, 224, 241, 255))
    draw.rounded_rectangle((66, 412, 366, 474), 16, fill=(117, 238, 210, 255))
    draw.text((98, 425), "무료로 다운로드", font=font(25), fill=(9, 36, 32, 255))
    draw.text((67, 536), "대화 내용을 수집하지 않는 로컬 동반 앱", font=font(18), fill=(159, 178, 203, 255))

    if variant == "a":
        # Problem-led composition: a short-lived system toast beside the persistent alert.
        shadow = Image.new("RGBA", image.size)
        sdraw = ImageDraw.Draw(shadow, "RGBA")
        sdraw.rounded_rectangle((690, 128, 1018, 202), 15, fill=(0, 0, 0, 95))
        image.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
        draw = ImageDraw.Draw(image, "RGBA")
        draw.rounded_rectangle((676, 114, 1004, 188), 15, fill=(238, 244, 250, 115), outline=(255, 255, 255, 95), width=1)
        draw.text((700, 125), "일반 배너 예시", font=font(16), fill=(102, 117, 135, 210))
        draw.text((700, 149), "짧게 표시되는 알림", font=font(18), fill=(77, 91, 110, 210))
        draw_card(draw, (648, 236, 430, 279), subtitle="확인할 작업이 있어요")
        draw.rounded_rectangle((635, 222, 1093, 527), 29, outline=(115, 244, 214, 95), width=2)
    else:
        # Task-led composition: the service, account context, and action stay grouped.
        draw_card(draw, (640, 212, 430, 279), subtitle="어느 대화인지 한눈에")
        draw.rounded_rectangle((635, 207, 1093, 500), 29, outline=(115, 244, 214, 130), width=2)
        draw.rounded_rectangle((686, 129, 1018, 186), 15, fill=(27, 44, 67, 240), outline=(90, 119, 151, 125), width=1)
        draw.text((710, 145), "계정 확인  ·  요청 내용", font=font(18), fill=(218, 230, 247, 255))

    image.convert("RGB").save(OUT / f"preview-kr-{variant}.png", optimize=True)


make("a")
make("b")
