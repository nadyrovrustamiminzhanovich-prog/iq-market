import sys
from PIL import Image

def remove_black_background(img_path, out_path):
    img = Image.open(img_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    for item in data:
        # If the pixel is very dark (almost black), make it transparent
        if item[0] < 25 and item[1] < 25 and item[2] < 25:
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    img.save(out_path, "PNG")

in_file = r"C:\Users\AaA\.gemini\antigravity\brain\659d3087-e2d1-4118-b0ba-d43d91e0ea4f\media__1780605198590.png"
remove_black_background(in_file, r"d:\iqmarket\assets\logo.png")
remove_black_background(in_file, r"d:\iqmarket\assets\icon.png")
print("Image processing complete")
