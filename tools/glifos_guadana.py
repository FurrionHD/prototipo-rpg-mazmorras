# ============================================================
#  glifos_guadana.py -- EL GLIFO DEL SET FILO DE AIRE (Segadora), propuestas (05/11/2026). El jefe: "la guadaña con el palo",
#  "dale el filo a la guadaña, que es una linea y ya no mola". En 7 x 7 de un solo tono salia un "7": aqui en dos tonos y
#  9 x 9 (y alguna en 7 x 7 para comparar):  '#' el FILO (blanco), '+' la HOJA (claro), '=' el MANGO (madera apagada).
#  Uso: python tools/glifos_guadana.py -> Desktop/taller_runas/glifos_segadora.png
# ============================================================
import os
from PIL import Image, ImageDraw

COL = (0.42, 0.7, 0.58)     # el verde palido del viento (el disco)
TONOS = {'#': (250, 250, 250), '+': (178, 196, 190), '=': (150, 118, 84)}

GLIFOS = {
    'H hoja ancha al viento (9)': ("..+++++=.", ".++####=.", "+##....=.", "##....=..", "#.....=..", "......=..",
                                   ".....=...", ".....=...", "....=...."),
    'I hoja gruesa (9)': ("...+++++=", ".++++++=.", "++####.=.", "##....=..", "#.....=..", "......=..",
                          ".....=...", ".....=...", "....=...."),
    'J hoja larga colgando (9)': ("...++++=.", ".+++###=.", "+##....=.", "+#....=..", "#.....=..", "#.....=..",
                                  ".....=...", ".....=...", "....=...."),
    'K mango recto (9)': ("+++++++=.", "+######=.", "##.....=.", "#......=.", "#......=.", ".......=.",
                          ".......=.", ".......=.", ".......=."),
    'L de la Parca (9)': ("....+++..", "..++####.", ".+#....=.", "+#....=..", "#....=...", "....=....",
                          "...=.....", "..=......", ".=......."),
    'M en 7 x 7': (".++++=.", "++###=.", "##..=..", "#...=..", "...=...", "...=...", "..=...."),
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
ruta = os.path.join(os.path.expanduser('~'), 'Desktop', 'taller_runas', 'glifos_segadora.png')
lam.save(ruta)
print(ruta)
