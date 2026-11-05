# ============================================================
#  glifos_varios_tonos.py -- LOS SELLOS VIEJOS DE LOS SETS DE RUNAS, REHECHOS A VARIOS TONOS (05/11/2026). Al elegir la
#  guadaña del Filo de aire (9 x 9 a tres tonos) el jefe pidio: "podemos remirar las viejas y quizas no hacer unicolor
#  como antes porque este nuevo concepto me ha molado". Dos versiones de cada uno (A y B) junto al de ahora.
#  Letras: '#' blanco (lo principal), '+' el tono claro del set, '=' su acento.
#  Uso: python tools/glifos_varios_tonos.py -> Desktop/taller_runas/glifos_varios_tonos.png
# ============================================================
import os
import re
from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# (set, nombre, color de su runa, acento '=' (None = su color oscurecido), A, B)
GLIFOS = [
    ("slime", "Gota (Masa)", (0.45, 0.85, 0.45), None,
     ("....+....", "...+++...", "..++#++..", ".++#+++=.", ".+#++++=.", "++++++++=", "+++++++==", ".+++++==.", "..=====.."),
     ("....+....", "...+++...", "..+++++..", ".+#+++++.", ".+=+++=+.", "++=+++=++", "+++++++++", ".+++++++.", "..=====..")),
    ("profundo", "Olas (Marea)", (0.2, 0.65, 0.75), None,
     (".........", ".###.....", "#+++#...#", "+===+###+", ".........", ".###.....", "#+++#...#", "+===+###+", "........."),
     ("...####..", "..#++++#.", ".#+==..+#", ".#+=.....", "#++=..#..", "#++==+#..", "#+++++#..", ".=+++==..", "..=====..")),
    ("rey", "Corona (Corona)", (0.95, 0.8, 0.3), (0.85, 0.2, 0.25),
     (".........", "#...#...#", "#+..#..+#", "#++###++#", "#+++++++#", "++=+=+=++", "+++++++++", "#########", "........."),
     (".........", ".#..#..#.", ".##.#.##.", ".#######.", ".++===++.", ".++=#=++.", ".+++++++.", ".#######.", ".........")),
    ("fuego", "Llama (Ignición)", (1.0, 0.5, 0.15), (0.75, 0.15, 0.08),
     ("....=....", "...==....", "...=+=...", "..=++=.=.", "..=+#+==.", ".=+##++=.", "=+####+=.", "=+####+=.", ".=++++==."),
     ("....=....", "....=....", "...=+=...", "...=+=...", "..=+#+=..", "..=+#+=..", ".=+###+=.", ".=+###+=.", "..=+++=..")),
    ("venenoso", "Calavera (Miasma)", (0.55, 0.8, 0.25), (0.5, 1.0, 0.25),
     (".#######.", "#########", "#==###==#", "#==###==#", "####+####", ".#######.", ".#+#+#+#.", "..+.+.+..", "........."),
     ("...###...", "...#+#...", "...#+#...", "..#+++#..", ".#+====#.", "#==#=#==#", "#===#===#", ".#=====#.", "..#####..")),
    ("abisal", "Estrella (Cielo)", (0.3, 0.35, 0.85), (0.6, 0.85, 1.0),
     ("....#....", "....#....", ".#..+..#.", "..#+=+#..", "##+===+##", "..#+=+#..", ".#..+..#.", "....#....", "....#...."),
     ("....#....", "...#+#...", "..#+++#..", ".#++=++#.", "#++===++#", ".#++=++#.", "..#+++#..", "...#+#...", "....#....")),
    ("rata", "Rejilla (Alcantarilla)", (0.55, 0.45, 0.6), (0.15, 0.12, 0.18),
     (".#######.", "#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#", "#=#=#=#=#", ".#######."),
     (".##...##.", "#+=#.#=+#", ".#######.", "#########", "##=###=##", "#########", ".#######.", "..##+##..", "...#+#...")),
    ("rey_rata", "Colmillos (Sangre real)", (0.62, 0.22, 0.2), (0.9, 0.15, 0.15),
     (".........", "#.#.#.#.#", "#########", "#+=+=+=+#", "#########", ".#.#.#.#.", ".#.#.#.#.", "..#...#..", "........."),
     ("##.....##", "##+...+##", "###+=+###", ".##+=+##.", ".##+=+##.", "..#+=+#..", "..##+##..", "...###...", "....#....")),
    ("jabali", "Helecho (Musgo viejo)", (0.32, 0.5, 0.22), (0.45, 0.32, 0.18),
     ("....#....", ".#..#..#.", "..#+#+#..", "#..+#+..#", ".#++#++#.", "..+=#=+..", "...=#=...", "....=....", "....=...."),
     ("#.......#", "#+.....+#", ".#+...+#.", "..##=##..", "...#=#...", "..#+=+#..", ".#++=++#.", "..#+=+#..", "...#=#...")),
    ("ciempies", "Dos cabezas (Dos mentes)", (0.86, 0.38, 0.1), (0.25, 0.9, 0.85),
     ("#.#...#.#", ".#.....#.", "##=...=##", "#+#...#+#", "#+#...#+#", "#+#...#+#", ".#+#.#+#.", "..#+#+#..", "...###..."),
     (".#.....#.", "..#####..", "=.#+=+#.=", ".=#####=.", "=.#+=+#.=", ".=#####=.", "=.#+=+#.=", ".=#####=.", "...#.#...")),
    ("escarabajo", "Imán (Campo magnético)", (0.8, 0.19, 0.13), (0.85, 0.87, 0.92),
     (".#######.", "#+++++++#", "#+#####+#", "#+#...#+#", "#+#...#+#", "#+#...#+#", "#+#...#+#", "===...===", "===...==="),
     ("...#.#...", "..#####..", ".##+#+##.", "#++=#=++#", "#++=#=++#", "#+++#+++#", "#+++#+++#", ".#++#++#.", "..##.##..")),
    ("trent", "Ámbar (Ámbar)", (0.95, 0.62, 0.15), (0.35, 0.2, 0.08),
     ("...###...", "..#+++#..", ".#+#+++#.", "#++=+=++#", "#+++=+++#", "#++=+=++#", ".#+++++#.", "..#+++#..", "...###..."),
     ("....#....", "...###...", "..#+#+#..", ".#++#++#.", "#+++#+++#", ".#++#++#.", "...=#=...", "...=#=...", "..=====..")),
    ("arana", "Rayo (Hilo conductor)", (0.36, 0.8, 0.92), (0.95, 0.9, 0.4),
     ("....###..", "...##+...", "..##+....", ".#####=..", "...=##=..", "...##=...", "..##=....", ".##=.....", ".#......."),
     ("#..#.#..#", ".#.#.#.#.", "..##=##..", "####=####", "..#===#..", ".#+===+#.", "#..#=#..#", "..#...#..", ".#.....#.")),
]


def actuales():
    """Los sellos de ahora (7 x 7, de un color), leidos de scripts/ui/celda_objeto.gd."""
    s = open(os.path.join(RAIZ, 'scripts', 'ui', 'celda_objeto.gd'), encoding='utf-8').read()
    out = {}
    for m in re.finditer(r'&"([a-z_]+)": \[([^\]]*)\]', s):
        filas = re.findall(r'"([.#+=]+)"', m.group(2))
        if filas:
            out[m.group(1)] = filas
    return out


def tonos(color, acento):
    def lig(c, t):
        return tuple(int(min(1.0, v + (1 - v) * t) * 255) for v in c)
    def osc(c, t):
        return tuple(int(v * (1 - t) * 255) for v in c)
    return {'#': (250, 250, 250), '+': lig(color, 0.55), '=': tuple(int(v * 255) for v in acento) if acento else osc(color, 0.45)}


def sello(filas, color, acento, r):
    n = max(7, len(filas))
    lado = int(r * 2 + 8)
    im = Image.new('RGB', (lado, lado), (13, 15, 20))
    d = ImageDraw.Draw(im)
    c = lado / 2
    disco = tuple(int(v * 255 * 0.65) for v in color)
    aro = tuple(int(min(1.0, v + (1 - v) * 0.45) * 255) for v in color)
    d.ellipse([c - r + 2, c - r + 2, c + r + 2, c + r + 2], fill=(0, 0, 0))
    d.ellipse([c - r, c - r, c + r, c + r], fill=disco, outline=aro, width=max(2, int(r * 0.17)))
    lg = r * 1.25
    px = lg / n
    x0 = c - lg / 2
    y0 = c - lg / 2
    t = tonos(color, acento)
    for j, f in enumerate(filas):
        for i, ch in enumerate(f):
            if ch in t:
                d.rectangle([x0 + i * px, y0 + j * px, x0 + (i + 1) * px - 1, y0 + (j + 1) * px - 1], fill=t[ch])
    return im


def comprobar():
    for s, nombre, _c, _a, a, b in GLIFOS:
        for v, filas in (("A", a), ("B", b)):
            assert len(filas) == 9, "%s %s: %d filas" % (s, v, len(filas))
            for j, f in enumerate(filas):
                assert len(f) == 9, "%s %s fila %d mide %d: '%s'" % (s, v, j, len(f), f)


def lamina():
    comprobar()
    ahora = actuales()
    try:
        fuente = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        fuente = None
    col_w, fila_h = 440, 118
    por_col = 7
    lam = Image.new('RGB', (40 + col_w * 2, 50 + fila_h * por_col), (40, 42, 50))
    d = ImageDraw.Draw(lam)
    d.text((20, 12), "ahora (7x7, un color)        A                    B          (grande y a tamaño de celda)", fill=(170, 170, 180), font=fuente)
    for k, (s, nombre, color, acento, a, b) in enumerate(GLIFOS):
        x = 20 + (k // por_col) * col_w
        y = 40 + (k % por_col) * fila_h
        if s in ahora:
            lam.paste(sello(ahora[s], color, None, 30), (x, y))
        for v, filas in enumerate((a, b)):
            gx = x + 95 + v * 160
            lam.paste(sello(filas, color, acento, 34), (gx, y))
            peq = sello(filas, color, acento, 11)
            lam.paste(peq.resize((peq.width * 2, peq.height * 2), Image.NEAREST), (gx + 80, y + 20))
        d.text((x, y + 82), nombre, fill=(225, 225, 225), font=fuente)
    carpeta = os.path.join(os.path.expanduser('~'), 'Desktop', 'taller_runas')
    os.makedirs(carpeta, exist_ok=True)
    ruta = os.path.join(carpeta, 'glifos_varios_tonos.png')
    lam.save(ruta)
    return ruta


if __name__ == '__main__':
    print(lamina())
