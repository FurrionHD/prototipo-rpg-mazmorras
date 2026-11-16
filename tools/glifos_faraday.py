# ============================================================
#  glifos_faraday.py -- EL GLIFO DEL SET JAULA DE FARADAY (la aberracion mutante), propuestas (13/11/2026, memoria
#  aberracion-mutante). Elegido en texto: BURBUJA CON RAYO. El efecto: al lanzar un hechizo, un escudo del 200 % de su
#  coste de mana base (se queda el mas grande, dura la pelea, los DoT pasan por debajo).
#  9 x 9 y TRES TONOS como los demas sellos: '#' el CIAN del rayo, '+' el LILA de la membrana, '=' un MORADO medio.
#  Disco del COLOR DE SU RUNA (violeta electrico, como el juego) y al lado los que ya hay. OJO: la araña (Hilo conductor) ya es un RAYO: aqui manda la BURBUJA.
#  Uso: python tools/glifos_faraday.py [--abrir] -> Desktop/taller_runas/glifos_faraday.png
# ============================================================
import os
import subprocess
import sys
from PIL import Image, ImageDraw

# EL COLOR DE SU RUNA (propuesto 13/11): VIOLETA ELECTRICO. El disco sale de aqui como en el juego (runa.color). Ojo con
# los vecinos: la runa de la ARAÑA ya es CIAN (0.36, 0.8, 0.92) y la de la RATA un morado gris (0.55, 0.45, 0.6).
COL = (0.62, 0.30, 0.90)
# Dos juegos de tonos para cada version: los PROPIOS (como la polilla y el micónido) y los de la REGLA de siempre
# (CeldaObjeto.tonos_glifo: '#' blanco, '+' su runa aclarada, '=' el acento; aqui el acento seria el cian del rayo).
PROPIOS = {'#': (110, 235, 255), '+': (205, 165, 240), '=': (125, 78, 172)}


def _aclara(c, f):
    return tuple(int(min(1.0, v + (1 - v) * f) * 255) for v in c)


REGLA = {'#': (255, 255, 255), '+': _aclara(COL, 0.55), '=': (92, 214, 240)}
TONOS = PROPIOS

GLIFOS = {
    'A burbuja': ("..+++++..", ".+.....+.", "+....#..+", "+...#...+", "+..###..+", "+...#...+", "+..#....+",
                  ".+.....+.", "..+++++.."),
    'B burbuja llena': ("..+++++..", ".+=====+.", "+====#==+", "+===#===+", "+==###==+", "+===#===+", "+==#====+",
                        ".+=====+.", "..+++++.."),
    'C rayo que la cruza': ("..+++.#..", ".+...#.+.", "+....#..+", "+...###.+", "+....#..+", "+...#...+",
                            "+..#....+", ".+.#...+.", "..#+++..."),
    'D doble burbuja': ("..+++++..", ".+.....+.", "+..===..+", "+.=.#.=.+", "+.=###=.+", "+.=.#.=.+", "+..===..+",
                        ".+.....+.", "..+++++.."),
    'E jaula': ("....#....", "...#.....", "....#=...", "..+++++..", ".+.+.+.+.", "+..+.+..+", "+..+.+..+",
                "+..+.+..+", "+++++++++"),
    'F rayo que rebota': ("#........", ".#.......", "..#=.....", "..=++++..", ".+.....+.", "+.......+", "+...=...+",
                          ".+.....+.", "..+++++.."),
    'G burbuja con nervios': ("..+++++..", ".+..#..+.", "+..#.#..+", "+.#...#.+", "+#..#..#+", "+.#...#.+",
                              "+..#.#..+", ".+..#..+.", "..+++++.."),
}


def sello(glifo, r, col=None, tonos=None):
    col = COL if col is None else col
    tonos = TONOS if tonos is None else tonos
    n = len(glifo)
    lado = int(r * 2 + 8)
    lado += lado % 2
    im = Image.new('RGB', (lado, lado), (13, 15, 20))
    d = ImageDraw.Draw(im)
    c = lado / 2
    osc = tuple(int(v * 255 * 0.65) for v in col)
    cla = tuple(int(min(1.0, v + (1 - v) * 0.45) * 255) for v in col)
    d.ellipse([c - r + 2, c - r + 2, c + r + 2, c + r + 2], fill=(0, 0, 0))
    d.ellipse([c - r, c - r, c + r, c + r], fill=osc, outline=cla, width=max(2, int(r * 0.17)))
    lg = r * 1.25
    px = lg / n
    x0 = c - lg / 2
    y0 = c - lg / 2
    for j, f in enumerate(glifo):
        assert len(f) == n, (glifo, f)
        for i, ch in enumerate(f):
            if ch in tonos:
                d.rectangle([round(x0 + i * px), round(y0 + j * px), round(x0 + (i + 1) * px) - 1,
                             round(y0 + (j + 1) * px) - 1], fill=tonos[ch])
    return im


# ------------------------------------------------------------
#  LOS QUE YA HAY, leidos del juego (CeldaObjeto.GLIFO_SET + el color de cada runa), para verlo AL LADO.
# ------------------------------------------------------------
import re
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _existentes():
    src = open(os.path.join(RAIZ, 'scripts/ui/celda_objeto.gd'), encoding='utf-8').read()
    bloque = src[src.index('const GLIFO_SET := {'):src.index('const GLIFO_ACENTO')]
    acento = {}
    for m in re.finditer(r'&"(\w+)": Color\(([\d.]+), ([\d.]+), ([\d.]+)\)', src[src.index('const GLIFO_ACENTO'):]):
        acento[m.group(1)] = tuple(float(m.group(k)) for k in (2, 3, 4))
    propios = {'polilla': {'#': (236, 62, 52), '+': (238, 234, 240), '=': (22, 16, 24)},
               'miconido': {'#': (236, 240, 170), '+': (196, 168, 110), '=': (110, 84, 60)},
               'segadora': {'+': (179, 196, 191), '=': (150, 117, 84)}}
    runa_de = {}
    for sf in os.listdir(os.path.join(RAIZ, 'resources/runas')):
        t = open(os.path.join(RAIZ, 'resources/runas', sf), encoding='utf-8').read()
        idm = re.search(r'^id = &"(\w+)"', t, re.M)
        rm = re.search(r'path="res://(resources/materials/runa_\w+\.tres)"', t)
        if idm and rm:
            c = re.search(r'^color = Color\(([\d.]+), ([\d.]+), ([\d.]+)', open(os.path.join(RAIZ, rm.group(1)),
                          encoding='utf-8').read(), re.M)
            runa_de[idm.group(1)] = tuple(float(c.group(k)) for k in (1, 2, 3))
    out = []
    for m in re.finditer(r'&"(\w+)": \[([^\]]+)\]', bloque):
        sid = m.group(1)
        filas = re.findall(r'"([.#+=]+)"', m.group(2))
        col = runa_de.get(sid, (0.6, 0.6, 0.9))
        ton = propios.get(sid) or {'+': _aclara(col, 0.55),
                                   '=': tuple(int(v * 255) for v in acento.get(sid, tuple(v * 0.55 for v in col)))}
        ton = dict({'#': (255, 255, 255)}, **ton)
        out.append((sid, filas, col, ton))
    return out


YA = _existentes()
ANCHO = max(180 * len(GLIFOS), 78 * len(YA)) + 40
lam = Image.new('RGB', (ANCHO, 420), (40, 42, 50))
d = ImageDraw.Draw(lam)
d.text((20, 4), 'TONOS PROPIOS (cian / lila / morado)', fill=(220, 220, 220))
d.text((20, 146), 'TONOS DE LA REGLA (blanco / runa aclarada / acento cian)', fill=(220, 220, 220))
for i, (nombre, g) in enumerate(GLIFOS.items()):
    x = 20 + i * 180
    for fila, ton in ((0, PROPIOS), (1, REGLA)):
        y = 20 + fila * 142
        lam.paste(sello(g, 40, COL, ton), (x, y))
        peq = sello(g, 14, COL, ton)
        lam.paste(peq.resize((peq.width * 2, peq.height * 2), Image.NEAREST), (x + 96, y + 8))
        d.text((x, y + 96), nombre, fill=(220, 220, 220))
d.text((20, 290), 'LOS QUE YA HAY (al lado, mismo tamaño que en la celda)', fill=(220, 220, 220))
for i, (sid, filas, col, ton) in enumerate(YA):
    x = 20 + i * 78
    lam.paste(sello(filas, 26, col, ton), (x, 306))
    d.text((x, 372), sid, fill=(200, 200, 200))
ruta = os.path.join(os.path.expanduser('~'), 'Desktop', 'taller_runas', 'glifos_faraday.png')
os.makedirs(os.path.dirname(ruta), exist_ok=True)
lam.save(ruta)
print(ruta)
if '--abrir' in sys.argv:
    subprocess.Popen(['mspaint', ruta])
