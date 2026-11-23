import os
import numpy as np
from PIL import Image, ImageDraw

def generate_textures():
    out_dir = os.path.join("godot", "textures")
    os.makedirs(out_dir, exist_ok=True)
    
    # 1. Floor Grid Texture (1024x1024)
    # 2x2 meter tile representation with 1m and 0.5m grid lines and crosshairs
    size = 1024
    img_floor = Image.new("RGBA", (size, size), (22, 26, 34, 255))
    draw = ImageDraw.Draw(img_floor)
    
    # Subtle tile noise
    arr = np.array(img_floor)
    noise = np.random.randint(-3, 4, (size, size), dtype=np.int16)
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c].astype(np.int16) + noise, 0, 255).astype(np.uint8)
    img_floor = Image.fromarray(arr, "RGBA")
    draw = ImageDraw.Draw(img_floor)
    
    # Sub-grid lines (every 256 pixels = 0.5m)
    for x in range(0, size, 256):
        draw.line([(x, 0), (x, size)], fill=(38, 48, 64, 255), width=2)
    for y in range(0, size, 256):
        draw.line([(0, y), (size, y)], fill=(38, 48, 64, 255), width=2)
        
    # Major grid lines (every 512 pixels = 1.0m)
    for x in range(0, size, 512):
        draw.line([(x, 0), (x, size)], fill=(0, 160, 220, 255), width=4)
        draw.line([(x-1, 0), (x-1, size)], fill=(0, 100, 150, 160), width=1)
        draw.line([(x+1, 0), (x+1, size)], fill=(0, 100, 150, 160), width=1)
    for y in range(0, size, 512):
        draw.line([(0, y), (size, y)], fill=(0, 160, 220, 255), width=4)
        draw.line([(0, y-1), (size, y-1)], fill=(0, 100, 150, 160), width=1)
        draw.line([(0, y+1), (size, y+1)], fill=(0, 100, 150, 160), width=1)
        
    # Intersection crosshairs
    for x in range(0, size + 1, 256):
        for y in range(0, size + 1, 256):
            arm = 16 if (x % 512 == 0 and y % 512 == 0) else 8
            col = (0, 220, 255, 255) if (x % 512 == 0 and y % 512 == 0) else (45, 65, 85, 255)
            w = 3 if (x % 512 == 0 and y % 512 == 0) else 1
            draw.line([(x - arm, y), (x + arm, y)], fill=col, width=w)
            draw.line([(x, y - arm), (x, y + arm)], fill=col, width=w)
            
    floor_path = os.path.join(out_dir, "floor_grid.png")
    img_floor.save(floor_path)
    print("Saved", floor_path)
    
    # 2. Wall Panel Texture (1024x1024)
    # Modular dark metallic laboratory wall panels with recessed seams
    img_wall = Image.new("RGBA", (size, size), (28, 32, 40, 255))
    draw_wall = ImageDraw.Draw(img_wall)
    
    # Panel subdivisions (4 wide x 2 tall)
    w_p = size // 4  # 256
    h_p = size // 2  # 512
    for px in range(4):
        for py in range(2):
            x0 = px * w_p
            y0 = py * h_p
            x1 = x0 + w_p
            y1 = y0 + h_p
            
            # Panel body with bevel
            draw_wall.rectangle([x0 + 4, y0 + 4, x1 - 4, y1 - 4], fill=(32, 38, 48, 255))
            # Panel highlight top/left
            draw_wall.line([(x0 + 4, y0 + 4), (x1 - 4, y0 + 4)], fill=(48, 56, 70, 255), width=2)
            draw_wall.line([(x0 + 4, y0 + 4), (x0 + 4, y1 - 4)], fill=(48, 56, 70, 255), width=2)
            # Panel shadow bottom/right
            draw_wall.line([(x0 + 4, y1 - 4), (x1 - 4, y1 - 4)], fill=(18, 22, 28, 255), width=2)
            draw_wall.line([(x1 - 4, y0 + 4), (x1 - 4, y1 - 4)], fill=(18, 22, 28, 255), width=2)
            # Dark recessed seam
            draw_wall.rectangle([x0, y0, x1, y1], outline=(14, 16, 22, 255), width=4)
            # Corner rivets
            for rx, ry in [(x0 + 12, y0 + 12), (x1 - 12, y0 + 12), (x0 + 12, y1 - 12), (x1 - 12, y1 - 12)]:
                draw_wall.ellipse([rx - 2, ry - 2, rx + 2, ry + 2], fill=(60, 70, 85, 255), outline=(15, 18, 24, 255))
                
    wall_path = os.path.join(out_dir, "wall_panel.png")
    img_wall.save(wall_path)
    print("Saved", wall_path)
    
    # 3. Safety Hazard Stripes (512x512)
    # Diagonal 45-degree yellow and black safety stripes
    size_h = 512
    img_h = Image.new("RGBA", (size_h, size_h), (20, 22, 26, 255))
    draw_h = ImageDraw.Draw(img_h)
    stripe_w = 48
    for i in range(-size_h, size_h * 2, stripe_w * 2):
        # Draw 45 degree polygon
        pts = [
            (i, 0),
            (i + stripe_w, 0),
            (i + stripe_w + size_h, size_h),
            (i + size_h, size_h)
        ]
        draw_h.polygon(pts, fill=(240, 180, 20, 255))
    hazard_path = os.path.join(out_dir, "hazard_stripes.png")
    img_h.save(hazard_path)
    print("Saved", hazard_path)

if __name__ == "__main__":
    generate_textures()
