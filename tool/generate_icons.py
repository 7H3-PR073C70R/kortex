import os
import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def create_base_icon():
    size = (1024, 1024)
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Background with radial dark gradient
    bg = Image.new("RGBA", size, (11, 15, 25, 255))
    bg_draw = ImageDraw.Draw(bg)
    
    # Gradient overlay
    for r in range(700, 0, -4):
        alpha = int(35 * (1 - r / 700.0))
        # subtle indigo/cyan radial glow in center
        color = (79, 70, 229, alpha)
        bg_draw.ellipse(
            [512 - r, 512 - r, 512 + r, 512 + r],
            fill=color
        )
    
    img.paste(bg, (0, 0))
    draw = ImageDraw.Draw(img)

    # 2. Outer decorative subtle glowing hex ring
    center = (512, 512)
    outer_r = 380
    hex_points = []
    for i in range(6):
        angle_deg = 60 * i - 30
        angle_rad = math.radians(angle_deg)
        x = center[0] + outer_r * math.cos(angle_rad)
        y = center[1] + outer_r * math.sin(angle_rad)
        hex_points.append((x, y))

    # Glow layer for hexagon
    glow = Image.new("RGBA", size, (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.polygon(hex_points, outline=(6, 182, 212, 140), width=28)
    glow = glow.filter(ImageFilter.GaussianBlur(16))
    img = Image.alpha_composite(img, glow)
    draw = ImageDraw.Draw(img)

    # Crisp Hexagon border with gradient-like look
    draw.polygon(hex_points, outline=(79, 70, 229, 255), width=22)
    # Inner accent
    inner_hex = []
    inner_r = 360
    for i in range(6):
        angle_deg = 60 * i - 30
        angle_rad = math.radians(angle_deg)
        x = center[0] + inner_r * math.cos(angle_rad)
        y = center[1] + inner_r * math.sin(angle_rad)
        inner_hex.append((x, y))
    draw.polygon(inner_hex, outline=(6, 182, 212, 90), width=4)

    # 3. Neural Synapse Connections and Central Core
    core_r = 100
    # Core glow
    core_glow = Image.new("RGBA", size, (0, 0, 0, 0))
    core_glow_draw = ImageDraw.Draw(core_glow)
    core_glow_draw.ellipse(
        [center[0] - core_r - 40, center[1] - core_r - 40, center[0] + core_r + 40, center[1] + core_r + 40],
        fill=(139, 92, 246, 120)
    )
    core_glow = core_glow.filter(ImageFilter.GaussianBlur(24))
    img = Image.alpha_composite(img, core_glow)
    draw = ImageDraw.Draw(img)

    # Node positions (6 surrounding vertices inside hexagon)
    node_r = 240
    nodes = []
    node_colors = [
        (79, 70, 229),   # Indigo
        (6, 182, 212),   # Cyan
        (139, 92, 246),  # Violet
        (79, 70, 229),   # Indigo
        (6, 182, 212),   # Cyan
        (139, 92, 246),  # Violet
    ]
    for i in range(6):
        angle_deg = 60 * i - 30
        angle_rad = math.radians(angle_deg)
        nx = center[0] + node_r * math.cos(angle_rad)
        ny = center[1] + node_r * math.sin(angle_rad)
        nodes.append((nx, ny))

    # Connecting Strands from center to nodes
    for i, node in enumerate(nodes):
        draw.line([center, node], fill=node_colors[i] + (220,), width=12)

    # Connecting strands between adjacent nodes
    for i in range(6):
        n1 = nodes[i]
        n2 = nodes[(i + 1) % 6]
        draw.line([n1, n2], fill=(6, 182, 212, 160), width=8)

    # Surrounding node circles
    for i, node in enumerate(nodes):
        nr = 42
        c = node_colors[i]
        # Glow
        draw.ellipse([node[0] - nr - 8, node[1] - nr - 8, node[0] + nr + 8, node[1] + nr + 8], fill=c + (80,))
        # Solid node
        draw.ellipse([node[0] - nr, node[1] - nr, node[0] + nr, node[1] + nr], fill=c + (255,))
        # Inner white center
        draw.ellipse([node[0] - nr // 2, node[1] - nr // 2, node[0] + nr // 2, node[1] + nr // 2], fill=(255, 255, 255, 220))

    # Central Core Circle
    draw.ellipse([center[0] - core_r, center[1] - core_r, center[0] + core_r, center[1] + core_r], fill=(139, 92, 246, 255))
    # Core inner accent
    draw.ellipse([center[0] - 65, center[1] - 65, center[0] + 65, center[1] + 65], fill=(6, 182, 212, 255))
    draw.ellipse([center[0] - 32, center[1] - 32, center[0] + 32, center[1] + 32], fill=(255, 255, 255, 240))

    return img

def add_diagonal_ribbon(base_img, text, bg_color, text_color=(255, 255, 255, 255)):
    # Create diagonal banner in top-right corner
    size = base_img.size
    overlay = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    # Ribbon dimensions
    # Top right diagonal polygon
    # (x1, y1) to (x2, y2)
    pts = [
        (650, 0),
        (1024, 0),
        (1024, 374),
        (1024, 520),
        (504, 0)
    ]
    # Triangle ribbon band:
    p1 = (600, 0)
    p2 = (1024, 424)
    p3 = (1024, 600)
    p4 = (424, 0)

    # Shadow under ribbon
    shadow = Image.new("RGBA", size, (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.polygon([p1, p2, p3, p4], fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    
    # Ribbon polygon
    draw.polygon([p1, p2, p3, p4], fill=bg_color)
    # Border stripes on ribbon
    draw.line([p1, p2], fill=(255, 255, 255, 120), width=4)
    draw.line([p4, p3], fill=(0, 0, 0, 80), width=4)

    # Render text onto rotated canvas
    txt_layer = Image.new("RGBA", (800, 200), (0, 0, 0, 0))
    txt_draw = ImageDraw.Draw(txt_layer)
    
    # Try system font or default
    font = None
    for font_name in ["/System/Library/Fonts/SFPro-Bold.ttf", "/System/Library/Fonts/Helvetica.ttc", "/System/Library/Fonts/Supplemental/Arial Bold.ttf"]:
        if os.path.exists(font_name):
            try:
                font = ImageFont.truetype(font_name, 110)
                break
            except Exception:
                pass
    if font is None:
        font = ImageFont.load_default()

    bbox = txt_draw.textbbox((0, 0), text, font=font)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    tx = (800 - tw) // 2
    ty = (200 - th) // 2 - 15

    # Text shadow
    txt_draw.text((tx + 4, ty + 4), text, font=font, fill=(0, 0, 0, 140))
    # Text
    txt_draw.text((tx, ty), text, font=font, fill=text_color)

    # Rotate by 45 degrees
    rotated_txt = txt_layer.rotate(45, expand=True, resample=Image.BICUBIC)
    
    # Paste centered on ribbon diagonal
    rx = 780 - rotated_txt.size[0] // 2
    ry = 244 - rotated_txt.size[1] // 2
    
    combined = Image.alpha_composite(base_img, shadow)
    combined = Image.alpha_composite(combined, overlay)
    combined.paste(rotated_txt, (rx, ry), rotated_txt)
    return combined

def main():
    os.makedirs("assets/icons", exist_ok=True)
    
    print("🎨 Generating Production App Icon (No Badge)...")
    prod_icon = create_base_icon()
    prod_icon.save("assets/icons/app_icon_production.png", "PNG")
    print("✅ Saved assets/icons/app_icon_production.png")

    print("🎨 Generating Development App Icon (DEV Badge)...")
    # Vibrant Emerald / Cyber Green Ribbon
    dev_icon = add_diagonal_ribbon(prod_icon.copy(), "DEV", (16, 185, 129, 245), (255, 255, 255, 255))
    dev_icon.save("assets/icons/app_icon_development.png", "PNG")
    print("✅ Saved assets/icons/app_icon_development.png")

    print("🎨 Generating Staging App Icon (STG Badge)...")
    # Warm Amber / Sunset Orange Ribbon
    stg_icon = add_diagonal_ribbon(prod_icon.copy(), "STG", (245, 158, 11, 245), (255, 255, 255, 255))
    stg_icon.save("assets/icons/app_icon_staging.png", "PNG")
    print("✅ Saved assets/icons/app_icon_staging.png")

if __name__ == "__main__":
    main()
