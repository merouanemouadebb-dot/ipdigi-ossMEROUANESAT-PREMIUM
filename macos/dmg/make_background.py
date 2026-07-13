"""DMG arka planı üretici. 660x420 px @1x, 1320x840 @2x retina.

Stremio'nun installer'ı tarzında: hafif mor-mavi diyagonal gradient,
sağ üst köşeye küçük bir "ipdigi" wordmark; ortada uygulama ikonu ve
Applications klasörü için bırakılan alanı boş tutuyoruz (create-dmg
icon positioning'i tamamlıyor).
"""

from PIL import Image, ImageDraw, ImageFont
from pathlib import Path

OUT_DIR = Path(__file__).parent
W, H = 660, 420


def gradient(width: int, height: int) -> Image.Image:
    """Sol-üst → sağ-alt diyagonal yumuşak mor-mavi gradient."""
    img = Image.new("RGB", (width, height), (0, 0, 0))
    px = img.load()
    # Start (sol-üst): #E9E8FB (pastel mor-mavi), end (sağ-alt): #DCE5F7
    start = (233, 232, 251)
    end = (220, 229, 247)
    diag = width + height
    for y in range(height):
        for x in range(width):
            t = (x + y) / diag
            r = round(start[0] + (end[0] - start[0]) * t)
            g = round(start[1] + (end[1] - start[1]) * t)
            b = round(start[2] + (end[2] - start[2]) * t)
            px[x, y] = (r, g, b)
    return img


def best_font(size: int) -> ImageFont.FreeTypeFont:
    """macOS sistem fontlarından uygun bir wordmark fontu seç."""
    candidates = [
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Avenir Next.ttc",
        "/System/Library/Fonts/HelveticaNeue.ttc",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for p in candidates:
        if Path(p).exists():
            try:
                return ImageFont.truetype(p, size=size)
            except Exception:
                continue
    return ImageFont.load_default()


def render(scale: int = 1) -> Image.Image:
    w, h = W * scale, H * scale
    bg = gradient(w, h)
    draw = ImageDraw.Draw(bg)
    # "ipdigi" wordmark, hafif şeffaf mor-mavi, sağ üst.
    font = best_font(int(96 * scale))
    text = "ipdigi"
    # Pillow >= 9.2: textbbox kullan
    bbox = draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    x = w - tw - int(40 * scale)
    y = int(28 * scale)
    # iki katmanlı gölge yerine düz lila — Stremio'nun mor-mavi
    # tonuyla aynı atmosferi tutar.
    draw.text((x, y), text, font=font, fill=(157, 152, 220, 255))
    return bg


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    base = render(scale=1)
    base.save(OUT_DIR / "background.png", optimize=True)
    retina = render(scale=2)
    retina.save(OUT_DIR / "background@2x.png", optimize=True)
    # create-dmg tek bir tiff de kabul ediyor (1x + 2x). Çoğu kullanım
    # için ayrı png'ler yeterli.
    print(f"Wrote {OUT_DIR/'background.png'} ({base.size})")
    print(f"Wrote {OUT_DIR/'background@2x.png'} ({retina.size})")


if __name__ == "__main__":
    main()
