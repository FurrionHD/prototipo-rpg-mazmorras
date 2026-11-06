# ============================================================
#  equipo_placas_juego.py  (06/11) EL JUEGO DE PLACAS ENTERO en el estilo elegido por el jefe ("los dos B me molan"):
#  el ARMET (yelmo B) y el peto de LAMAS (peto B) de tools/equipo_placas_versiones.py, y con el mismo lenguaje las
#  tres piezas que faltaban: guanteletes, grebas con rodillera y escarpes. Lamas horizontales con su canto en luz y su
#  hueco hondo debajo, sombreado en cilindro, contrarreflejo y piezas montadas con su hueco oscuro.
#    python tools/equipo_placas_juego.py [salida.png]
# ============================================================
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
import equipo_placas_versiones as V
from equipo_placas_versiones import BRI, HON, rellenar_cilindro, rellenar_esfera, anillo_oscuro
from equipo_pixel import MAT_S, MAT, MAT_L, OSC, ACE
from PIL import Image, ImageDraw, ImageFont


def lamas(cv, f, y0, y1, alto_px=3, brillo_x=None):
    # Rellena 'f' entre y0 e y1 como lamas solapadas: cilindro, canto de arriba en luz (con su punto de brillo) y el
    # hueco hondo en la fila de abajo de cada lama.
    alto = alto_px / cv.n
    k = 0
    while y0 + k * alto < y1:
        ya, yb = y0 + k * alto, min(y1, y0 + (k + 1) * alto)
        m = cv.mascara(lambda x, y: f(x, y) and ya <= y < yb)
        if m:
            rellenar_cilindro(cv, m)
            xs = [x for x, _ in m]
            x0, x1 = min(xs), max(xs)
            for (x, y) in m:
                if y == min(yy for _, yy in m):
                    u = (x - x0 + 0.5) / max(1, x1 - x0 + 1)
                    cv.pon(x, y, BRI if (brillo_x is None and 0.22 <= u < 0.34) else MAT_L)
                if y == max(yy for _, yy in m) and yb - ya >= 2.5 / cv.n:
                    cv.pon(x, y, HON)
        k += 1


# ---- GUANTELETES: el par, de frente. Puño acampanado, dorso en lamas y los dedos en lamas mas finas ----
def guanteletes(cv):
    for cx, hacia in ((0.25, 1), (0.75, -1)):             # 'hacia' = donde cae el pulgar (hacia el centro)
        puno = lambda x, y, cx=cx: abs(x - cx) <= 0.08 + (0.36 - y) * 0.35 and 0.14 <= y <= 0.36
        m = cv.mascara(puno)
        rellenar_cilindro(cv, m)
        cv.mancha(lambda x, y, cx=cx: puno(x, y) and y < 0.14 + 1.0 / cv.n, MAT_L)            # el canto del puño
        cv.mancha(lambda x, y, cx=cx: puno(x, y) and y > 0.36 - 1.0 / cv.n, HON)
        mano = lambda x, y, cx=cx: abs(x - cx) <= 0.13 and 0.37 <= y <= 0.60
        anillo_oscuro(cv, cv.mascara(mano))
        lamas(cv, mano, 0.37, 0.60, 3)
        def dedos(x, y, cx=cx):
            if not (abs(x - cx) <= 0.13 and 0.61 <= y <= 0.86):
                return False
            u = (x - (cx - 0.13)) / 0.26                     # 0..1 a lo ancho: cuatro dedos con la punta redonda
            k = min(3, int(u * 4))
            centro = (k + 0.5) / 4
            largo = 0.86 - (0.05 if k in (0, 3) else 0.0)
            if y > largo - 0.04:
                return abs(u - centro) <= 0.08
            return y <= largo
        lamas(cv, dedos, 0.61, 0.86, 3)
        for k in (1, 2, 3):                                                                    # las rajas entre dedos
            fx = cx - 0.13 + 0.26 * k / 4
            cv.mancha(lambda x, y, fx=fx: dedos(x, y) and abs(x - fx) < 0.5 / cv.n, HON)
        # EL PULGAR, ENCIMA de la mano (pintado antes, la mano se lo comia): sale hacia el centro, con su hueco oscuro
        pulgar = lambda x, y, cx=cx, h=hacia: ((x - cx - h * 0.15) / 0.06) ** 2 + ((y - 0.54) / 0.10) ** 2 <= 1.0
        m = cv.mascara(pulgar)
        anillo_oscuro(cv, m)
        lamas(cv, pulgar, 0.44, 0.64, 2)
        EP.punto(cv, cx, 0.42, ACE)


# ---- GREBAS (pantalones): la falda de lamas arriba y las dos piernas con quijote, RODILLERA en esfera y greba ----
def grebas(cv):
    falda = lambda x, y: abs(x - 0.5) <= 0.34 and 0.10 <= y <= 0.26
    lamas(cv, falda, 0.10, 0.26, 3)
    for cx in (0.34, 0.66):
        muslo = lambda x, y, cx=cx: abs(x - cx) <= 0.12 - (y - 0.27) * 0.06 and 0.27 <= y <= 0.50
        m = cv.mascara(muslo)
        anillo_oscuro(cv, m)
        rellenar_cilindro(cv, m)
        greba = lambda x, y, cx=cx: abs(x - cx) <= 0.10 - (y - 0.60) * 0.04 and 0.58 <= y <= 0.90
        m = cv.mascara(greba)
        anillo_oscuro(cv, m)
        rellenar_cilindro(cv, m)
        cv.mancha(lambda x, y, cx=cx: greba(x, y) and abs(x - cx) < 0.5 / cv.n, MAT_L)         # la arista de la greba
        r = 0.09
        rod = cv.mascara(lambda x, y, cx=cx: ((x - cx) / r) ** 2 + ((y - 0.54) / (r * 0.9)) ** 2 <= 1.0)
        anillo_oscuro(cv, rod)
        rellenar_esfera(cv, rod, cx, 0.54, r)


# ---- ESCARPES (botas): de perfil, mirando a la izquierda. Caña en cilindro y el pie en lamas que bajan a la punta ----
def escarpes(cv):
    def pieza(dx, dy):
        cana = lambda x, y: 0.40 <= x - dx <= 0.62 and 0.16 <= y - dy <= 0.64
        pie = lambda x, y: 0.62 <= y - dy <= 0.82 and 0.18 + max(0.0, 0.70 - (y - dy)) * 1.6 <= x - dx <= 0.64
        return cana, pie
    for dx, dy in ((0.14, -0.04), (-0.06, 0.06)):
        cana, pie = pieza(dx, dy)
        m = cv.mascara(cana)
        anillo_oscuro(cv, m)
        rellenar_cilindro(cv, m)
        cv.mancha(lambda x, y: cana(x, y) and y - dy < 0.16 + 1.0 / cv.n, MAT_L)
        cv.mancha(lambda x, y: cana(x, y) and abs(x - dx - 0.51) < 0.5 / cv.n, MAT_L)        # la arista
        anillo_oscuro(cv, cv.mascara(pie))
        lamas(cv, pie, 0.62 + dy, 0.82 + dy, 2)
        cv.mancha(lambda x, y: pie(x, y) and y - dy > 0.80, OSC)                                # la suela
        EP.punto(cv, 0.51 + dx, 0.30 + dy, ACE)


PIEZAS = [
    ("Casco: armet", V.yelmo_b),
    ("Pecho: lamas", V.peto_b),
    ("Manos: guanteletes", guanteletes),
    ("Pantalones: grebas", grebas),
    ("Botas: escarpes", escarpes),
]


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else "placas_juego.png"
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
    h = 80 + fila * len(PIEZAS)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "JUEGO DE PLACAS (estilo B): 32 px, x4 y tamano real", fill=(240, 190, 100), font=f1)
    for i, (_t, _m, nom) in enumerate(EP.COLUMNAS):
        d.text((x0 + i * cw, 52), nom, fill=(200, 200, 210), font=f2)
    for j, (nombre, fn) in enumerate(PIEZAS):
        y = 76 + j * fila
        d.text((16, y + 56), nombre, fill=(220, 220, 228), font=f2)
        cv = EP.dibujar(fn, N)
        for i, (t, m, _n) in enumerate(EP.COLUMNAS):
            im = EP.teñir(cv, V.paleta_ampliada(PAL["armadura|metal|%d|%d" % (t, m)]))
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            x = x0 + i * cw
            lam.paste(g, (x, y), g)
            lam.paste(im, (x + N * ESC + 6, y + N * ESC - N), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
