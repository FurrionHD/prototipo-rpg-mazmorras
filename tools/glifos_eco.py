# ============================================================
#  glifos_eco.py -- EL GLIFO DEL SET ECOLOCALIZACION (el chillon mutante), propuestas (16/11/2026, memoria
#  chillon-mutante). El efecto (decidido): ARMADURA 5p, inmune a Ceguera y A oscuras, ves el sigilo, +daño a lo escondido.
#  9 x 9 y TRES TONOS: '#' BLANCO AZULADO (las ondas del eco), '+' GRIS del chillon, '=' NEGRO. Disco pizarra oscuro.
#  Uso: python tools/glifos_eco.py [--abrir] -> Desktop/taller_runas/glifos_eco.png
# ============================================================
import os
import subprocess
import sys
from PIL import Image, ImageDraw

COL = (0.16, 0.19, 0.26)     # pizarra oscuro (el disco)
TONOS = {'#': (200, 228, 255), '+': (128, 140, 156), '=': (18, 18, 24)}

GLIFOS = {
    'A ondas del eco': ("....#....", "..#...#..", ".#..#..#.", "#..#.#..#", "#.#.+.#.#", "#..#.#..#", ".#..#..#.",
                        "..#...#..", "....#...."),
    'B cabeza y ondas': ("+.......+", "++.....++", "+++++++++", "+=+++++=+", ".+++++++.", "..+++++..", "...+=+...",
                         ".#.....#.", "#.#...#.#"),
    'C ojo cerrado': ("..#...#..", ".#.....#.", "#...#...#", "...+++...", "++=====++", "...+++...", "#...#...#",
                      ".#.....#.", "..#...#.."),
}


def sello(glifo, r):
    n = len(glifo)
    lado = int(r * 2 + 8)
    lado += lado % 2   # par: el centro cae entre dos pixeles, igual a los dos lados
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
        assert len(f) == n, (glifo, f)
        for i, ch in enumerate(f):
            if ch in TONOS:
                # Como el juego (CeldaObjeto._glifo): cada pixel ENTERO desde el centro. Antes se le quitaba 1 a cada uno
                # y el dibujo quedaba corrido arriba a la izquierda ("no esta centrado del todo").
                d.rectangle([round(x0 + i * px), round(y0 + j * px), round(x0 + (i + 1) * px) - 1,
                             round(y0 + (j + 1) * px) - 1], fill=TONOS[ch])
    return im


lam = Image.new('RGB', (260 * len(GLIFOS) + 20, 140), (40, 42, 50))
d = ImageDraw.Draw(lam)
for i, (nombre, g) in enumerate(GLIFOS.items()):
    x = 20 + i * 260
    lam.paste(sello(g, 40), (x, 10))
    peq = sello(g, 14)
    lam.paste(peq.resize((peq.width * 2, peq.height * 2), Image.NEAREST), (x + 100, 30))
    d.text((x, 110), nombre, fill=(220, 220, 220))
ruta = os.path.join(os.path.expanduser('~'), 'Desktop', 'taller_runas', 'glifos_eco.png')
os.makedirs(os.path.dirname(ruta), exist_ok=True)
lam.save(ruta)
print(ruta)
if '--abrir' in sys.argv:
    subprocess.Popen(['mspaint', ruta])
