import os
from PIL import Image

SIZE = 1024
SAFE = 600  # the logo must fit inside this, or Android crops it

logo = Image.open("assets/images/logo.png").convert("RGBA")
ratio = min(SAFE / logo.width, SAFE / logo.height)
logo = logo.resize((round(logo.width * ratio), round(logo.height * ratio)), Image.LANCZOS)

foreground = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
foreground.paste(logo, ((SIZE - logo.width) // 2, (SIZE - logo.height) // 2), logo)

background = Image.new("RGBA", (SIZE, SIZE), (1, 16, 39, 255))  # #011027
icon = Image.alpha_composite(background, foreground)

os.makedirs("assets/icon", exist_ok=True)
foreground.save("assets/icon/app_icon_foreground.png")
icon.convert("RGB").save("assets/icon/app_icon.png")
print("Done")