# ============================================================
#  equipo_escudos.py  (06/11, rework visual a pixel) LOS TRES ESCUDOS en pixel art de verdad para la celda, de frente:
#    pequeno  LA RODELA: disco de tablas, casi todo aro, y un UMBO gordo de metal en el centro.
#    normal   EL DE CABALLERO: arriba recto, los lados bajan y se cierran en punta; aro y una franja de metal.
#    grande   LA PUERTA: alto, arriba en arco; aro gordo, dos bandas de metal y una arista por el medio.
#  (las mismas siluetas que el muñeco, escudo_sprites.gd). La CARA es MADERA en tablas y el ARO es METAL, cada uno con su
#  escala de tier; el metal con el contraste de siempre (BRILLO y HONDO) y la madera con luz blanda.
#
#  Tonos (EscudoSprites.ROLES y los del icono): 3/4/5 madera, 6 metal, 7 metal luz, 8 BRILLO, 9 HONDO, 10 metal sombra.
#    python tools/equipo_escudos.py [salida.png]   (la lamina, para su visto bueno)
#    python tools/equipo_escudos.py --hornear      (los PNG en assets/sprites/equipo/escudo; SOLO tras su ok)
# ============================================================
import colorsys
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
from equipo_pixel import Lienzo
from PIL import Image, ImageDraw, ImageFont

MAD_S, MAD, MAD_L, MET, MET_L, BRI, HON, MET_S = 3, 4, 5, 6, 7, 8, 9, 10


def derivar(c, f, sat):
    h, s, v = colorsys.rgb_to_hsv(*c[:3])
    return colorsys.hsv_to_rgb(h, min(1.0, s * sat), min(1.0, v * f)) + (1.0,)


def paleta(pal_arma):
    # La del escudo sale de la del ARMA de metal del mismo tier: alli estan el metal (5/6/7) y la madera (8/9/10).
    p = [None] * 11
    p[2] = pal_arma[2]
    p[MAD_S], p[MAD], p[MAD_L] = pal_arma[8], pal_arma[9], pal_arma[10]
    p[MET_S], p[MET], p[MET_L] = pal_arma[5], pal_arma[6], pal_arma[7]
    p[BRI] = derivar(pal_arma[6], 1.55, 0.30)
    p[HON] = derivar(pal_arma[6], 0.36, 1.20)
    return p


def metal_en(cv, x, y, u, v):
    # El metal del aro segun donde cae: luz arriba a la izquierda, hondo abajo a la derecha (u, v = -1..1).
    l = -u * 0.6 - v * 0.8
    if l > 0.85:
        return BRI
    if l > 0.25:
        return MET_L
    if l > -0.45:
        return MET
    if l > -0.85:
        return MET_S
    return HON


def cara_de_tablas(cv, m, cx, ancho_tabla):
    # La cara de madera en TABLAS verticales: cada tabla con su luz a la izquierda y su junta oscura.
    for (x, y) in m:
        fx = (x + 0.5) / cv.n
        k = (fx - cx) / ancho_tabla
        pos = k - math.floor(k)
        t = MAD
        if pos < 0.18:
            t = MAD_S if pos < 0.09 else MAD_L
        elif pos > 0.80:
            t = MAD_S
        cv.pon(x, y, t)


def aro(cv, dentro, fuera, cx, cy, rx, ry):
    for y in range(cv.n):
        for x in range(cv.n):
            fx, fy = (x + 0.5) / cv.n, (y + 0.5) / cv.n
            if fuera(fx, fy) and not dentro(fx, fy):
                cv.pon(x, y, metal_en(cv, x, y, (fx - cx) / rx, (fy - cy) / ry))


def remaches(cv, puntos):
    for fx, fy in puntos:
        x, y = int(fx * cv.n), int(fy * cv.n)
        cv.pon(x, y, BRI)
        cv.pon(x + 1, y + 1, HON)


# ---- RODELA ----
def rodela(cv):
    cx, cy, R = 0.5, 0.5, 0.40
    fuera = lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= R * R
    dentro = lambda x, y: (x - cx) ** 2 + (y - cy) ** 2 <= (R - 0.10) ** 2
    cara_de_tablas(cv, cv.mascara(dentro), cx, 0.12)
    aro(cv, dentro, fuera, cx, cy, R, R)
    r = 0.13                                                                   # el UMBO, una media esfera
    for y in range(cv.n):
        for x in range(cv.n):
            fx, fy = (x + 0.5) / cv.n, (y + 0.5) / cv.n
            d = math.hypot(fx - cx, fy - cy)
            if d <= r:
                dl = math.hypot(fx - cx + r * 0.40, fy - cy + r * 0.40) / r
                if dl < 0.35:
                    t = BRI
                elif dl < 0.70:
                    t = MET_L
                elif (fx - cx) + (fy - cy) < r * 0.5:
                    t = MET
                elif d < r * 0.85:
                    t = MET_S
                else:
                    t = HON
                cv.pon(x, y, t)
    remaches(cv, [(cx + math.cos(a) * (R - 0.05), cy + math.sin(a) * (R - 0.05))
                  for a in (math.pi * 1.25, math.pi * 1.75, math.pi * 0.25, math.pi * 0.75)])


# ---- EL DE CABALLERO ----
def _heater(x, y, margen=0.0):
    top, mid, bot = 0.12 + margen, 0.50, 0.90 - margen
    semi = 0.36 - margen
    if y < top or y > bot:
        return False
    if y <= mid:
        return abs(x - 0.5) <= semi
    t = (y - mid) / (bot - mid)                        # los lados se cierran en curva hasta la punta
    return abs(x - 0.5) <= semi * math.sqrt(max(0.0, 1.0 - t * t))


def caballero(cv):
    fuera = lambda x, y: _heater(x, y)
    dentro = lambda x, y: _heater(x, y, 0.07)
    cara_de_tablas(cv, cv.mascara(dentro), 0.5, 0.11)
    aro(cv, dentro, fuera, 0.5, 0.48, 0.36, 0.42)
    franja = lambda x, y: dentro(x, y) and abs(x - 0.5) <= 0.08            # la franja de metal del medio
    anillo = cv.mascara(lambda x, y: dentro(x, y) and 0.08 < abs(x - 0.5) <= 0.08 + 1.0 / cv.n)
    for (x, y) in anillo:
        cv.pon(x, y, HON)                                                     # su hueco contra la madera
    for (x, y) in cv.mascara(franja):
        u = ((x + 0.5) / cv.n - 0.5) / 0.08
        cv.pon(x, y, BRI if u < -0.5 and y < cv.n * 0.5 else (MET_L if u < 0 else (MET if u < 0.6 else HON)))
    remaches(cv, [(0.24, 0.20), (0.76, 0.20), (0.5, 0.20), (0.5, 0.72)])


# ---- LA PUERTA ----
def _torre(x, y, margen=0.0):
    semi = 0.30 - margen
    top, bot = 0.06 + margen, 0.94 - margen
    if y > bot or abs(x - 0.5) > semi:
        return False
    arco_y = top + 0.12 * (1.0 - math.sqrt(max(0.0, 1.0 - ((x - 0.5) / max(semi, 0.01)) ** 2)))
    return y >= arco_y


def puerta(cv):
    fuera = lambda x, y: _torre(x, y)
    dentro = lambda x, y: _torre(x, y, 0.08)
    cara_de_tablas(cv, cv.mascara(dentro), 0.5, 0.10)
    aro(cv, dentro, fuera, 0.5, 0.5, 0.30, 0.44)
    for by in (0.34, 0.70):                                                 # las dos bandas
        banda = lambda x, y, by=by: dentro(x, y) and abs(y - by) <= 0.035
        for (x, y) in cv.mascara(banda):
            v = ((y + 0.5) / cv.n - by) / 0.035
            cv.pon(x, y, MET if v < -0.3 else (MET_S if v < 0.5 else HON))
    # la ARISTA: un lomo de dos pixeles, en luz el de la izquierda y en hondo el de la derecha (no una raya blanca:
    # con las bandas formaba una cruz y el escudo parecia una ventana)
    arista = lambda x, y: dentro(x, y) and abs((x - 0.5) + 0.5 / cv.n) <= 1.0 / cv.n
    for (x, y) in cv.mascara(arista):
        cv.pon(x, y, MET_L if (x + 0.5) / cv.n < 0.5 else HON)
    remaches(cv, [(0.28, 0.34), (0.72, 0.34), (0.28, 0.70), (0.72, 0.70)])


ESCUDOS = [("Rodela (pequeno)", "pequeno", rodela), ("De caballero (normal)", "normal", caballero),
           ("La puerta (grande)", "grande", puerta)]
RAMPA_TONOS = 16


def hornear(carpeta):
    os.makedirs(carpeta, exist_ok=True)
    for _n, clave, fn in ESCUDOS:
        cv = EP.dibujar(fn, 32)
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for y in range(32):
            for x in range(32):
                t = cv.p[y][x]
                if t:
                    g = int(round(t / (RAMPA_TONOS - 1) * 255))
                    im.putpixel((x, y), (g, g, g, 255))
        im.save(os.path.join(carpeta, "%s.png" % clave))
    print("%d escudos en %s" % (len(ESCUDOS), carpeta))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--hornear":
        hornear(sys.argv[2] if len(sys.argv) > 2 else "assets/sprites/equipo/escudo")
        return
    salida = sys.argv[1] if len(sys.argv) > 1 else "escudos_lamina.png"
    with open(os.path.join(EP.AQUI, "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC, N = 4, 32
    COLS = EP.COLUMNAS
    cw = N * ESC + 12
    x0 = 200
    fila = N * ESC + 20
    w = x0 + cw * len(COLS) + N + 30
    h = 70 + fila * len(ESCUDOS)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "ESCUDOS EN PIXEL (32 px): T1, T2, T3 y T3+12 a x4, y T2 a tamano real", fill=(240, 190, 100), font=f1)
    for i, (_t, _m, nom) in enumerate(COLS):
        d.text((x0 + i * cw, 44), nom, fill=(200, 200, 210), font=f2)
    for j, (nombre, clave, fn) in enumerate(ESCUDOS):
        y = 66 + j * fila
        d.text((16, y + 56), nombre, fill=(220, 220, 228), font=f2)
        cv = EP.dibujar(fn, N)
        for k, (t, m, _n) in enumerate(COLS):
            im = EP.teñir(cv, paleta(PAL["arma|metal|%d|%d" % (t, m)]))
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            lam.paste(g, (x0 + k * cw, y), g)
            if t == 2 and m == 0:
                lam.paste(im, (x0 + len(COLS) * cw + 6, y + N * ESC - N), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
