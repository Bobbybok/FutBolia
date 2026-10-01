from PIL import Image

src_user = r"C:\Users\Bobby\.cursor\projects\d-Logiciels-Developpement-FutBolia\assets\c__Users_Bobby_AppData_Roaming_Cursor_User_workspaceStorage_dc76c67af5dde960261d941c044839d6_images_Logo-fd8a6b48-ffc8-4df5-9b49-9870e3572266.png"
dst = r"D:\Logiciels\Developpement\FutBolia\apps\mobile\assets\images\logo_matcharena.png"

img = Image.open(src_user).convert("RGBA")
pixels = img.load()
w, h = img.size

for y in range(h):
    for x in range(w):
        r, g, b, a = pixels[x, y]
        brightness = max(r, g, b)
        # Near-black background -> fully transparent
        if brightness < 30 and abs(r - g) < 12 and abs(g - b) < 12:
            pixels[x, y] = (0, 0, 0, 0)
            continue
        # Soft edge fade for dark fringe around the mark
        if brightness < 50 and abs(r - g) < 18 and abs(g - b) < 18:
            alpha = int((brightness / 50) * 200)
            pixels[x, y] = (r, g, b, alpha)

img.save(dst, optimize=True)
opaque = sum(1 for y in range(h) for x in range(w) if pixels[x, y][3] > 10)
print(f"saved {dst} size={w}x{h} opaque={opaque}/{w*h}")
