# ============================================================
#  glifos_contagio.py -- EL GLIFO DEL SET CONTAGIO (micónido), propuestas (09/11/2026, miconido-mutante). El jefe: "saca
#  varias versiones". 9 x 9 y TRES TONOS como los demas sellos: '#' las ESPORAS (claras), '+' el SOMBRERO / la nube,
#  '=' el PIE (oscuro). Disco ocre, el del micónido.
#  Uso: python tools/glifos_contagio.py -> Desktop/taller_runas/glifos_contagio.png
# ============================================================
import os
from PIL import Image, ImageDraw

COL = (0.52, 0.46, 0.30)     # el ocre del micónido (el disco)
TONOS = {'#': (236, 240, 170), '+': (196, 168, 110), '=': (110, 84, 60)}

GLIFOS = {
    'A seta soltando esporas': ("#.#...#..", "...#.#...", "..+++++..", ".+++++++.", "+++++++++", "...===...",
                                "...===...", "...===...", "..=====.."),
    'B seta con esporas alrededor': ("#.......#", "..+++++..", ".+++++++.", "+++++++++", "#..===..#", "...===...",
                                     ".#.===.#.", "...===...", "..=====.."),
    'C calavera con esporas': ("#..+++..#", "..+++++..", ".+++++++.", ".+=+++=+.", ".+=+++=+.", "..+++++..",
                               "#..+=+..#", "...+++...", ".#.....#."),
    'D nube con gotas': (".........", "..++.++..", ".+++++++.", "+++++++++", ".+++++++.", "..#.#.#..",
                         ".#.#.#.#.", "..#...#..", "........."),
    'E seta que revienta': ("#..#.#..#", ".#.....#.", "...+++...", "#.+++++.#", ".+++++++.", "....=....",
                            "...===...", "...===...", "..=====.."),
}


def sello(glifo, r):
    n = len(glifo)
    lado = int(r * 2 + 8)
    im = Image.new('RGB', (lado, lado), (13, 15, 20))
    d = ImageDraw.Draw(im)
    c = lado / 2
    osc = tuple(int(v * 255 * 0.65) for v in COL)
    cla = tuple(int(min(1.0, v + (1 - v) * 0.45) * 255) for v in COL)
    d.ellipse([c - r + 2, c - r + 2, c + r + 2, c + r + 2], fill=(0, 0, 0))
    d.ellipse([c - r, c - r, c + r, c + r], fill=osc, outline=cla, width=max(2, int(r * 0.17)))
    lg = r * 1.25
    px = lg / n
    x0 = c - lg / 2
    y0 = c - lg / 2
    for j, f in enumerate(glifo):
        for i, ch in enumerate(f):
            if ch in TONOS:
                d.rectangle([x0 + i * px, y0 + j * px, x0 + (i + 1) * px - 1, y0 + (j + 1) * px - 1], fill=TONOS[ch])
    return im


lam = Image.new('RGB', (260 * len(GLIFOS) + 20, 140), (40, 42, 50))
d = ImageDraw.Draw(lam)
for i, (nombre, g) in enumerate(GLIFOS.items()):
    x = 20 + i * 260
    lam.paste(sello(g, 40), (x, 10))
    peq = sello(g, 14)
    lam.paste(peq.resize((peq.width * 2, peq.height * 2), Image.NEAREST), (x + 100, 30))
    d.text((x, 110), nombre, fill=(220, 220, 220))
ruta = os.path.join(os.path.expanduser('~'), 'Desktop', 'taller_runas', 'glifos_contagio.png')
os.makedirs(os.path.dirname(ruta), exist_ok=True)
lam.save(ruta)
print(ruta)
