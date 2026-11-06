# ============================================================
#  libros_pixel.py  (06/11, rework visual: "hay que hacer dibujos pixel art propios para los libros y si pueden
#  representar a su magia especifica mejor, y los otros tambien, que se sepan de que son solo con verlos")
#  LAMINA DE PRUEBA de los LIBROS en pixel art de verdad, hecho pixel a pixel a 32 x 32: TRES estilos de libro (A, B, C)
#  y en cada uno seis grimorios con el emblema de SU magia y la tapa del color de su elemento, y tres tochos con el
#  de su tema. No toca el juego: saca una lamina para que el jefe elija.
#    python tools/libros_pixel.py [salida.png]
# ============================================================
import sys
from PIL import Image, ImageDraw, ImageFont

N = 32

# ---- LOS EMBLEMAS, 12 x 12 ----
# '#' el tono claro del emblema, '+' el medio, '=' el oscuro, '*' blanco (el destello), '.' nada.
EMBLEMAS = {
    "bola_fuego": [
        ".....+......",
        "....+#+..+..",
        "...+##+.+#..",
        "..+##*#+#+..",
        ".+##**##+...",
        ".+#****#+...",
        ".+#*##*#+...",
        ".+######+...",
        "..+####+=...",
        "...+##+=....",
        "....==......",
        "............",
    ],
    "chorro_agua": [
        ".....#......",
        "....###.....",
        "....#*#.....",
        "...##*##....",
        "...#*###....",
        "..###*###...",
        "..##*####...",
        "..#######=..",
        "..+#####+=..",
        "...+###+=...",
        "....+++=....",
        "............",
    ],
    "descarga": [
        "......####..",
        ".....###=...",
        "....###=....",
        "...###=.....",
        "..########..",
        "......###=..",
        ".....###=...",
        "....##*=....",
        "...##*=.....",
        "..##=.......",
        "..#=........",
        "............",
    ],
    "estallido_solar": [
        ".....*......",
        "..*..#..*...",
        "...+###+....",
        "..+#####+...",
        "*##**#**##*.",
        "..+#*#*#+...",
        "..+#####+...",
        "...+###+....",
        "..*..#..*...",
        ".....*......",
        "............",
        "............",
    ],
    "voragine_sombra": [
        "....====....",
        "..==++++==..",
        ".=+#####++=.",
        ".=+#====#+=.",
        "=+#=+##+=#+=",
        "=+#+#**=+#+=",
        "=+#+=##=+#+=",
        ".=+#=++=#+=.",
        ".=+##====+=.",
        "..==+###+=..",
        "....====....",
        "............",
    ],
    "vendaje_de_luz": [
        "............",
        "....####....",
        "....#**#....",
        "....#**#....",
        ".####**####.",
        ".#********#.",
        ".#********#.",
        ".####**####.",
        "....#**#....",
        "....#**#....",
        "....####....",
        "............",
    ],
    # tochos
    "rata": [
        "............",
        "..==....==..",
        ".=++=..=++=.",
        ".=+#====#+=.",
        "..=######=..",
        ".=##*##*##=.",
        ".=########=.",
        "..=##==##=..",
        "...=#++#=...",
        "....=##=....",
        ".....==..=..",
        "........==..",
    ],
    "sopa": [
        "...+..+.....",
        "....+..+....",
        "...+..+.....",
        "............",
        ".==========.",
        "=+########+=",
        "=##*######+=",
        ".=########=.",
        "..=######=..",
        "...======...",
        "....====....",
        "............",
    ],
    "setas": [
        "....====....",
        "..==####==..",
        ".=##*##*###=",
        "=##########=",
        "=+###*####+=",
        ".==========.",
        "....=**=....",
        "....=**=....",
        "....=**=....",
        "...=****=...",
        "...======...",
        "............",
    ],
}

# El COLOR de cada libro: la tapa (su elemento) y el del emblema.
LIBROS = [
    ("Bola de fuego", "bola_fuego", (0.72, 0.20, 0.12), (1.00, 0.66, 0.20)),
    ("Chorro de agua", "chorro_agua", (0.16, 0.36, 0.68), (0.56, 0.84, 1.00)),
    ("Descarga", "descarga", (0.36, 0.22, 0.58), (1.00, 0.88, 0.30)),
    ("Estallido solar", "estallido_solar", (0.80, 0.60, 0.18), (1.00, 0.95, 0.62)),
    ("Voragine de sombra", "voragine_sombra", (0.20, 0.14, 0.30), (0.66, 0.44, 0.92)),
    ("Vendaje de luz", "vendaje_de_luz", (0.86, 0.82, 0.66), (1.00, 0.86, 0.40)),
    ("Tocho: la rata", "rata", (0.42, 0.30, 0.20), (0.70, 0.62, 0.56)),
    ("Tocho: la sopa", "sopa", (0.30, 0.42, 0.26), (0.92, 0.62, 0.30)),
    ("Tocho: las setas", "setas", (0.46, 0.20, 0.18), (0.92, 0.30, 0.26)),
]


def mezcla(c, k):  # k > 0 aclara, k < 0 oscurece
    if k >= 0:
        return tuple(min(1.0, x + (1.0 - x) * k) for x in c)
    return tuple(max(0.0, x * (1.0 + k)) for x in c)


def rgb(c):
    return tuple(int(round(x * 255)) for x in c) + (255,)


CONTORNO = (0.06, 0.05, 0.07)
PAPEL = (0.93, 0.89, 0.78)
PAPEL_S = (0.70, 0.64, 0.52)
METAL = (0.80, 0.76, 0.62)
METAL_S = (0.48, 0.44, 0.36)
CUERO = (0.40, 0.26, 0.16)


def lienzo():
    return Image.new("RGBA", (N, N), (0, 0, 0, 0))


def px(im, x, y, c):
    if 0 <= x < N and 0 <= y < N:
        im.putpixel((x, y), rgb(c))


def rect(im, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(im, x, y, c)


def contorno(im):
    # El contorno de un pixel alrededor de la silueta (como el muñeco): donde hay hueco tocando algo pintado.
    datos = im.load()
    marcar = []
    for y in range(N):
        for x in range(N):
            if datos[x, y][3] == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < N and 0 <= yy < N and datos[xx, yy][3] > 0 and datos[xx, yy][:3] != rgb(CONTORNO)[:3]:
                        marcar.append((x, y))
                        break
    for x, y in marcar:
        px(im, x, y, CONTORNO)


def emblema(im, nombre, cx, cy, col):
    e = EMBLEMAS[nombre]
    tonos = {"#": col, "+": mezcla(col, -0.35), "=": mezcla(col, -0.65), "*": mezcla(col, 0.75)}
    for j, fila in enumerate(e):
        for i, ch in enumerate(fila):
            if ch in tonos:
                px(im, cx - 6 + i, cy - 6 + j, tonos[ch])


# ---- A. TOMO CON CORREA, de frente ----
def libro_a(tapa, col_e, nombre):
    im = lienzo()
    luz, base, sombra, honda = mezcla(tapa, 0.25), tapa, mezcla(tapa, -0.30), mezcla(tapa, -0.55)
    rect(im, 26, 4, 27, 28, PAPEL)          # el canto de las hojas
    for y in range(6, 28, 3):
        px(im, 27, y, PAPEL_S)
    rect(im, 7, 3, 25, 29, base)            # la tapa
    rect(im, 7, 3, 25, 3, luz)
    rect(im, 7, 3, 7, 29, luz)
    rect(im, 7, 29, 25, 29, sombra)
    rect(im, 25, 4, 25, 29, sombra)
    rect(im, 4, 2, 7, 30, honda)            # el lomo, con sus nervios
    for y in (7, 15, 23):
        rect(im, 4, y, 7, y, sombra)
    rect(im, 10, 6, 22, 6, sombra)          # el marco hundido de la tapa
    rect(im, 10, 6, 10, 26, sombra)
    rect(im, 10, 26, 22, 26, luz)
    rect(im, 22, 6, 22, 26, luz)
    emblema(im, nombre, 16, 15, col_e)
    rect(im, 20, 21, 29, 23, CUERO)         # la correa y su hebilla
    rect(im, 20, 21, 29, 21, mezcla(CUERO, 0.25))
    rect(im, 26, 20, 28, 24, METAL)
    rect(im, 27, 21, 27, 23, METAL_S)
    contorno(im)
    return im


# ---- B. TOMO DE LADO, con el grosor ----
def libro_b(tapa, col_e, nombre):
    im = lienzo()
    luz, base, sombra, honda = mezcla(tapa, 0.25), tapa, mezcla(tapa, -0.30), mezcla(tapa, -0.55)
    for k in range(5):                      # el grosor de las hojas, en diagonal
        rect(im, 9 + k, 27 + k // 2, 28 + k // 3, 27 + k // 2, PAPEL if k % 2 == 0 else PAPEL_S)
    rect(im, 26, 5, 29, 28, PAPEL)
    for y in range(7, 28, 2):
        px(im, 28, y, PAPEL_S)
    rect(im, 6, 2, 26, 27, base)            # la tapa
    rect(im, 6, 2, 26, 3, luz)
    rect(im, 6, 2, 7, 27, luz)
    rect(im, 26, 4, 26, 27, sombra)
    rect(im, 6, 27, 26, 27, sombra)
    rect(im, 3, 3, 6, 29, honda)            # el lomo
    rect(im, 3, 3, 3, 29, sombra)
    for y in (6, 28):
        rect(im, 3, y, 6, y, METAL_S)
    for cx, cy in ((9, 5), (23, 5), (9, 24), (23, 24)):   # cuatro clavos
        px(im, cx, cy, METAL)
    emblema(im, nombre, 16, 15, col_e)
    contorno(im)
    return im


# ---- C. GRIMORIO CON MEDALLON y cantoneras ----
def libro_c(tapa, col_e, nombre):
    im = lienzo()
    luz, base, sombra, honda = mezcla(tapa, 0.25), tapa, mezcla(tapa, -0.30), mezcla(tapa, -0.55)
    rect(im, 26, 4, 27, 28, PAPEL)
    for y in range(6, 28, 3):
        px(im, 27, y, PAPEL_S)
    rect(im, 5, 2, 25, 29, base)
    rect(im, 5, 2, 25, 2, luz)
    rect(im, 5, 2, 5, 29, honda)
    rect(im, 6, 2, 6, 29, luz)
    rect(im, 5, 29, 25, 29, sombra)
    rect(im, 25, 3, 25, 29, sombra)
    for (x0, y0, sx, sy) in ((6, 3, 1, 1), (24, 3, -1, 1), (6, 28, 1, -1), (24, 28, -1, -1)):   # cantoneras
        for k in range(4):
            px(im, x0 + sx * k, y0, METAL)
            px(im, x0, y0 + sy * k, METAL)
        px(im, x0 + sx, y0 + sy, METAL_S)
    # el MEDALLON: un circulo de metal con el fondo hondo, y el emblema dentro
    for y in range(N):
        for x in range(N):
            d2 = (x - 15.5) ** 2 + (y - 15.0) ** 2
            if d2 <= 8.6 ** 2:
                px(im, x, y, METAL if d2 > 7.4 ** 2 else honda)
    for y in range(N):
        for x in range(N):
            d2 = (x - 15.5) ** 2 + (y - 15.0) ** 2
            if 7.4 ** 2 < d2 <= 8.6 ** 2 and (x + y) > 31:
                px(im, x, y, METAL_S)
    emblema(im, nombre, 16, 15, col_e)
    contorno(im)
    return im


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else "libros_lamina.png"
    estilos = [("A. Tomo con correa", libro_a), ("B. Tomo de lado", libro_b), ("C. Grimorio con medallon", libro_c)]
    ESC = 4
    celda = N * ESC + 28
    alto_fila = N * ESC + 40 + 70
    w = 280 + celda * len(LIBROS)
    h = 60 + alto_fila * len(estilos)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    try:
        f = ImageFont.truetype("arial.ttf", 20)
        fp = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        f = fp = None
    d.text((16, 16), "LIBROS EN PIXEL ART (32 x 32). Arriba x4; debajo, a tamaño de celda (x2).", fill=(240, 190, 100), font=f)
    for i, (n, _e, _t, _c) in enumerate(LIBROS):
        d.text((280 + i * celda, 44), n, fill=(200, 200, 210), font=fp)
    for j, (titulo, fn) in enumerate(estilos):
        y = 70 + j * alto_fila
        d.text((16, y + 50), titulo, fill=(240, 190, 100), font=f)
        for i, (_n, e, tapa, col) in enumerate(LIBROS):
            im = fn(tapa, col, e)
            x = 280 + i * celda
            grande = im.resize((N * ESC, N * ESC), Image.NEAREST)
            lam.paste(grande, (x, y), grande)
            peq = im.resize((N * 2, N * 2), Image.NEAREST)
            lam.paste(peq, (x + 32, y + N * ESC + 8), peq)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
