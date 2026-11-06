# ============================================================
#  equipo_placas_versiones.py  (06/11, el jefe: "los de placas no se ven muy de placas, busca alguna referencia god")
#  VERSIONES del PETO y el YELMO de placas, con lo que dicen las referencias de metal en pixel art:
#    - el metal es CONTRASTE: un brillo casi blanco y una sombra honda, no tres tonos parecidos;
#    - el CONTRARREFLEJO: junto al borde en sombra, una franja algo mas clara (la luz que rebota);
#    - se sombrea como un CILINDRO con la luz de arriba a la izquierda, no con el bisel "almohada" en cada borde;
#    - las PLACAS SON PIEZAS: hombreras montadas encima con su hueco oscuro, gorjal, escarcelas, lamas.
#  Referencias: wiki.wesnoth.org/Armour_Tutorial (contrarreflejo), pixnote.net/en/learn/shading (metal),
#  eoserv.net/forum/topic/8441 (contra el pillow shading), otland.net/threads/first-steps.259105 (cilindro, 32x32).
#
#  Usa DOS TONOS MAS que la armadura de hoy: BRILLO (casi blanco) y HONDO (sombra profunda). En el juego serian dos
#  papeles nuevos de PaletaEquipo (MATERIAL_B y MATERIAL_O) que salen del mismo color base con _derivar.
#    python tools/equipo_placas_versiones.py [salida.png]
# ============================================================
import colorsys
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
from equipo_pixel import Lienzo, MAT_S, MAT, MAT_L, OSC, ACE, B
from PIL import Image, ImageDraw, ImageFont

BRI, HON = 11, 12   # los dos tonos nuevos


def derivar(c, f, sat):
    # El mismo PaletaEquipo._derivar: valor x f y saturacion x sat sobre el color base.
    h, s, v = colorsys.rgb_to_hsv(*c[:3])
    return colorsys.hsv_to_rgb(h, min(1.0, s * sat), min(1.0, v * f)) + (1.0,)


def paleta_ampliada(pal):
    base = pal[MAT]
    pal = list(pal) + [None] * (13 - len(pal))
    pal[BRI] = derivar(base, 1.55, 0.30)
    pal[HON] = derivar(base, 0.36, 1.20)
    return pal


# EL CILINDRO: el tono segun lo lejos que este el pixel del borde izquierdo de SU fila (u = 0..1).
#   luz | BRILLO | base | sombra | HONDO | contrarreflejo (sombra) | borde
def cilindro(u):
    if u < 0.10:
        return MAT
    if u < 0.24:
        return MAT_L
    if u < 0.32:
        return BRI
    if u < 0.56:
        return MAT_L if u < 0.40 else MAT
    if u < 0.74:
        return MAT_S
    if u < 0.88:
        return HON
    return MAT_S


def rellenar_cilindro(cv, m, desplaza=0.0):
    filas = {}
    for (x, y) in m:
        filas.setdefault(y, []).append(x)
    for y, xs in filas.items():
        x0, x1 = min(xs), max(xs)
        for x in xs:
            u = (x - x0 + 0.5) / max(1, x1 - x0 + 1) + desplaza
            cv.pon(x, y, cilindro(min(0.99, max(0.0, u))))


# LA ESFERA (hombreras, la cupula del yelmo): brillo arriba a la izquierda, hondo abajo a la derecha y contrarreflejo.
def rellenar_esfera(cv, m, cx, cy, r):
    for (x, y) in m:
        dx, dy = (x + 0.5) / cv.n - cx, (y + 0.5) / cv.n - cy
        d = (dx * 0.7 + dy * 0.7) / r                    # hacia abajo-derecha
        dl = ((dx + r * 0.45) ** 2 + (dy + r * 0.45) ** 2) ** 0.5 / r
        if dl < 0.28:
            t = BRI
        elif dl < 0.55:
            t = MAT_L
        elif d < 0.25:
            t = MAT
        elif d < 0.55:
            t = MAT_S
        elif d < 0.85:
            t = HON
        else:
            t = MAT_S
        cv.pon(x, y, t)


def anillo_oscuro(cv, m):
    # El HUECO entre dos placas: un pixel de borde alrededor de la pieza que va encima.
    for (x, y) in m:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in m and cv.get(x + dx, y + dy) not in (0,):
                cv.pon(x + dx, y + dy, B)


def torso(x, y, ancho=0.33, cintura=0.24):
    if y < 0.20 or y > 0.74:
        return False
    if ((x - 0.5) / 0.12) ** 2 + ((y - 0.18) / 0.10) ** 2 <= 1.0:
        return False
    semi = ancho - max(0.0, y - 0.40) * (ancho - cintura) / 0.34
    return abs(x - 0.5) <= semi


def hombrera(cv, lado, cx_off=0.27, cy=0.31, r=0.16):
    # La hombrera MONTA sobre el hombro: una lama de debajo (mas estrecha, en cilindro) y la cupula encima, cada una con
    # su hueco oscuro. Con la cupula sola y cortada en plano parecian setas.
    cx = 0.5 + lado * cx_off
    lama = cv.mascara(lambda x, y: abs(x - cx - lado * 0.02) <= r * 0.85 and cy + r * 0.30 <= y <= cy + r * 0.95)
    anillo_oscuro(cv, lama)
    rellenar_cilindro(cv, lama)
    m = cv.mascara(lambda x, y: ((x - cx) / r) ** 2 + ((y - cy) / (r * 0.80)) ** 2 <= 1.0 and y <= cy + r * 0.45)
    anillo_oscuro(cv, m)
    rellenar_esfera(cv, m, cx, cy, r)
    return m


def escarcelas(cv, y0=0.75, n=2, alto=0.07):
    # Las lamas que cuelgan de la cintura, cada una un pelo mas ancha.
    for i in range(n):
        ya, yb = y0 + i * alto, y0 + (i + 1) * alto - 0.5 / cv.n
        semi = 0.24 + i * 0.02
        m = cv.mascara(lambda x, y: abs(x - 0.5) <= semi and ya <= y <= yb)
        rellenar_cilindro(cv, m)
        cv.mancha(lambda x, y: abs(x - 0.5) <= semi and abs(y - yb) < 0.5 / cv.n, HON)


# ---- PETO A: CILINDRO + hombreras redondas + gorjal + escarcelas ----
def peto_a(cv):
    m = cv.mascara(torso)
    rellenar_cilindro(cv, m)
    cv.mancha(lambda x, y: torso(x, y) and abs(y - 0.58) < 0.5 / cv.n, HON)                    # la union del peto y la falda
    escarcelas(cv)
    g = cv.mascara(lambda x, y: abs(x - 0.5) <= 0.15 and 0.16 <= y <= 0.23 and
                   ((x - 0.5) / 0.10) ** 2 + ((y - 0.14) / 0.08) ** 2 > 1.0)                    # el gorjal
    rellenar_cilindro(cv, g)
    for lado in (-1, 1):
        hombrera(cv, lado)


# ---- PETO B: LAMAS horizontales solapadas (cada lama con su luz arriba y su hondo debajo) ----
def peto_b(cv):
    alto = 3.0 / cv.n
    for k in range(9):
        ya = 0.20 + k * alto
        yb = ya + alto
        m = cv.mascara(lambda x, y: torso(x, y) and ya <= y < yb)
        rellenar_cilindro(cv, m)
        cv.mancha(lambda x, y: torso(x, y) and ya <= y < ya + 1.0 / cv.n, MAT_L)               # el canto de la lama
        cv.mancha(lambda x, y: torso(x, y) and ya <= y < ya + 1.0 / cv.n and abs(x - 0.36) < 1.5 / cv.n, BRI)
        cv.mancha(lambda x, y: torso(x, y) and yb - 1.0 / cv.n <= y < yb, HON)                 # el hueco de debajo
    for lado in (-1, 1):
        hombrera(cv, lado, 0.27, 0.30, 0.15)


# ---- PETO C: CABALLERO, peto con ARISTA central (mitad en luz, mitad en sombra), hombreras grandes y remaches ----
def peto_c(cv):
    m = cv.mascara(lambda x, y: torso(x, y, 0.32, 0.25))
    for (x, y) in m:
        fx = (x + 0.5) / cv.n
        d = fx - 0.5
        if abs(d) < 0.6 / cv.n:
            t = BRI                                         # la arista
        elif d < 0:
            t = MAT_L if d > -0.10 else (MAT if d > -0.22 else MAT_S)
        else:
            t = HON if d < 0.08 else (MAT_S if d < 0.24 else MAT)
        cv.pon(x, y, t)
    # el brillo del pecho, en forma de coma bajo la clavicula izquierda
    cv.mancha(lambda x, y: ((x - 0.40) / 0.05) ** 2 + ((y - 0.34) / 0.07) ** 2 <= 1.0 and torso(x, y), BRI)
    cv.mancha(lambda x, y: torso(x, y, 0.32, 0.25) and abs(y - 0.62) < 0.5 / cv.n, HON)
    escarcelas(cv, 0.75, 2, 0.07)
    for lado in (-1, 1):
        hombrera(cv, lado, 0.28, 0.30, 0.17)
        EP.punto(cv, 0.5 + lado * 0.28, 0.42, ACE)
    for fx in (0.38, 0.62):
        EP.punto(cv, fx, 0.70, ACE)


# ---- YELMOS ----
def yelmo_a(cv):
    # GRAN YELMO en cilindro: mirilla en cruz, respiraderos y la cresta de laton.
    def y_(x, y):
        if not (0.22 <= x <= 0.78 and 0.14 <= y <= 0.86):
            return False
        return not (y < 0.32 and ((x - 0.5) / 0.28) ** 2 + ((y - 0.32) / 0.18) ** 2 > 1.0)
    rellenar_cilindro(cv, cv.mascara(y_))
    cv.mancha(lambda x, y: 0.27 <= x <= 0.73 and 0.43 <= y <= 0.49, OSC)
    cv.mancha(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.43 <= y <= 0.70, OSC)             # la cruz de la mirilla
    cv.mancha(lambda x, y: abs(x - 0.5) < 0.5 / cv.n and 0.10 <= y <= 0.42, ACE)
    cv.mancha(lambda x, y: 0.22 <= x <= 0.78 and abs(y - 0.40) < 0.5 / cv.n, HON)             # la banda de la frente
    for fy in (0.60, 0.68, 0.76):
        for fx in (0.34, 0.40, 0.60, 0.66):
            EP.punto(cv, fx, fy, OSC, 0.5)


def yelmo_b(cv):
    # ARMET redondo: cupula en esfera, visera con rendijas y el gorjal debajo.
    cup = cv.mascara(lambda x, y: ((x - 0.5) / 0.30) ** 2 + ((y - 0.46) / 0.34) ** 2 <= 1.0 and y <= 0.70)
    rellenar_esfera(cv, cup, 0.5, 0.46, 0.32)
    vis = cv.mascara(lambda x, y: 0.26 <= x <= 0.74 and 0.44 <= y <= 0.66 and
                     ((x - 0.5) / 0.26) ** 2 + ((y - 0.50) / 0.20) ** 2 <= 1.0)
    anillo_oscuro(cv, vis)
    rellenar_cilindro(cv, vis)
    for fy in (0.50, 0.56):
        cv.mancha(lambda x, y, fy=fy: 0.32 <= x <= 0.68 and abs(y - fy) < 0.5 / cv.n, OSC)
    gor = cv.mascara(lambda x, y: abs(x - 0.5) <= 0.24 - (y - 0.72) * 0.3 and 0.71 <= y <= 0.86)
    rellenar_cilindro(cv, gor)
    cv.mancha(lambda x, y: abs(x - 0.5) <= 0.24 and abs(y - 0.79) < 0.5 / cv.n, HON)
    EP.punto(cv, 0.28, 0.48, ACE)
    EP.punto(cv, 0.72, 0.48, ACE)


def yelmo_c(cv):
    # BACINETE en punta con nasal: cupula apuntada en cilindro, la nasal en brillo y la cota debajo.
    def cup(x, y):
        if not (0.24 <= x <= 0.76 and 0.12 <= y <= 0.62):
            return False
        semi = 0.26 * min(1.0, (y - 0.10) / 0.30) ** 0.6
        return abs(x - 0.5) <= semi
    rellenar_cilindro(cv, cv.mascara(cup))
    cv.mancha(lambda x, y: 0.24 <= x <= 0.76 and 0.56 <= y <= 0.62, MAT_S)                    # el aro de la frente
    cv.mancha(lambda x, y: 0.24 <= x <= 0.76 and abs(y - 0.56) < 0.5 / cv.n, MAT_L)
    cota = cv.mascara(lambda x, y: (abs(x - 0.5) <= 0.27 and 0.62 < y <= 0.86) and not
                      (abs(x - 0.5) <= 0.14 and y < 0.80))
    for (x, y) in cota:                                                                           # la malla, a cuadros
        cv.pon(x, y, MAT if (x + y) % 2 else HON)
    cv.mancha(lambda x, y: abs(x - 0.5) <= 0.14 and 0.62 < y < 0.80, OSC)                     # la cara, en sombra
    cv.mancha(lambda x, y: abs(x - 0.5) < 1.0 / cv.n and 0.50 <= y <= 0.74, BRI)              # la nasal
    for fx in (0.32, 0.68):
        EP.punto(cv, fx, 0.59, ACE)


FILAS = [
    ("Peto (el de antes)", EP.pecho_placas, False),
    ("Peto A: cilindro", peto_a, True),
    ("Peto B: lamas", peto_b, True),
    ("Peto C: caballero", peto_c, True),
    ("Yelmo (el de antes)", EP.casco_placas, False),
    ("Yelmo A: gran yelmo", yelmo_a, True),
    ("Yelmo B: armet", yelmo_b, True),
    ("Yelmo C: bacinete", yelmo_c, True),
]


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else "placas_versiones.png"
    with open(os.path.join(EP.AQUI, "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC, N = 4, 32
    cw = N * ESC + 50
    x0 = 190
    fila = N * ESC + 16
    w = x0 + cw * len(EP.COLUMNAS) + 20
    h = 80 + fila * len(FILAS)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "ARMADURA DE PLACAS: versiones (32 px, x4 y tamano real)", fill=(240, 190, 100), font=f1)
    for i, (_t, _m, nom) in enumerate(EP.COLUMNAS):
        d.text((x0 + i * cw, 52), nom, fill=(200, 200, 210), font=f2)
    for j, (nombre, fn, ampliada) in enumerate(FILAS):
        y = 76 + j * fila
        d.text((16, y + 56), nombre, fill=(220, 220, 228), font=f2)
        cv = EP.dibujar(fn, N)
        for i, (t, m, _n) in enumerate(EP.COLUMNAS):
            pal = PAL["armadura|metal|%d|%d" % (t, m)]
            im = EP.teñir(cv, paleta_ampliada(pal) if ampliada else pal)
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            x = x0 + i * cw
            lam.paste(g, (x, y), g)
            lam.paste(im, (x + N * ESC + 6, y + N * ESC - N), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
