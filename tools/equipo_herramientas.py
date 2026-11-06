# ============================================================
#  equipo_herramientas.py  (06/11, rework visual a pixel) LAS HERRAMIENTAS DE FAENA en pixel art de verdad, con el mismo
#  lenguaje que las armas (tools/equipo_armas.py): en diagonal, el metal con BRILLO y HONDO, mango de madera.
#    pico, hacha de talar, hoz, caña y cuchillo de desollar.
#  Hoy salen de las facetas de sprites_objeto.gd (poligonos rasterizados a partir de UN color). Lamina de prueba: no toca
#  el juego hasta su visto bueno.
#    python tools/equipo_herramientas.py [salida.png]
# ============================================================
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
import equipo_armas as A
from equipo_armas import diag, puno, BRI, HON, CUERDA
from equipo_pixel import MANGO_S, MANGO, MET_S, MET, MET_L, MAD_S, MAD, MAD_L
from PIL import Image, ImageDraw, ImageFont


def asta(s, p, s0, s1):
    if s0 <= s <= s1 and -1 <= p <= 0:
        return MAD_L if p == -1 else MAD_S
    return 0


def pico(cv):
    # PICO: la cabeza curva atravesada arriba, con las dos puntas cayendo hacia el mango
    def f(s, p, e):
        c = 10.0 * e
        for lado in (-1, 1):
            if lado * p >= 0 and abs(p) <= 11:
                centro = c - 0.045 * p * p / max(e, 0.5)
                grueso = 2.4 - abs(p) * 0.12
                if abs(s - centro) <= grueso:
                    arriba = s > centro
                    if abs(p) >= 10:
                        return MET_L                                        # la punta
                    if arriba:
                        return BRI if lado < 0 and abs(p) < 7 else MET_L
                    return HON if abs(s - centro) > grueso - 0.6 else MET
        if abs(s - c) <= 2.2 and -2 <= p <= 1:
            return MET_S                                                     # el ojo
        return primero(puno(s, p, -15 * e, -11 * e, -1, 0), asta(s, p, -11 * e, c))
    diag(cv, f)


def primero(*v):
    for x in v:
        if x:
            return x
    return 0


def hacha_talar(cv):
    # HACHA DE TALAR: la de una mano, cabeza de un solo filo, mas pequeña que la de guerra, asta larga
    def f(s, p, e):
        eh = e / A.LARGO * 1.0
        c, r = 9.5 * e, 4.6 * eh
        q = -p
        if q >= 1:
            hw = 1.4 * eh if q <= 2 else min(r, 1.4 * eh + (q - 2) * 1.1 * eh)
            borde = 2 + 4.2 * eh + 1.2 * eh * math.sqrt(max(0.0, 1.0 - ((s - c) / r) ** 2))
            if abs(s - c) <= hw and q <= borde:
                if q >= borde - 1.2:
                    return BRI if s < c else MET_L
                if abs(s - c) >= hw - 0.6:
                    return HON if s > c else MET_S
                return MET
        if 1 <= p <= 2 and abs(s - c) <= 1.6 * eh:
            return MET_S if p == 1 else HON                                   # el talon
        if abs(s - c) <= 1.6 * eh and -1 <= p <= 0:
            return MET
        return primero(puno(s, p, -15 * e, -11 * e, -1, 0), asta(s, p, -11 * e, c + 1.5))
    diag(cv, f)


def hoz(cv):
    # HOZ: el mango corto de madera y la hoja en MEDIA LUNA que se abre hacia la luz, con el filo por dentro
    def f(s, p, e):
        cs, cp, R = 4.0 * e, -6.0, 8.0 * e
        d = math.hypot((s - cs) * 1.0, (p - cp) * 0.72)
        ang = math.atan2(p - cp, s - cs)
        if R - 2.2 <= d <= R and -2.2 <= ang <= 1.2:
            if d < R - 1.4:
                return BRI if ang < -0.4 else MET_L                          # el filo, por dentro
            return HON if ang > 0.4 else (MET if d < R - 0.6 else MET_S)
        return primero(puno(s, p, -14 * e, -6 * e, -1, 0), asta(s, p, -6 * e, cs + R * 0.98 - 1))
    diag(cv, f)


def cana(cv):
    # CAÑA: la vara larga y fina, el puño de corcho, el CARRETE de metal y el sedal que cae desde la punta
    n = cv.n
    def f(s, p, e):
        if -15 * e <= s < -9 * e and -1 <= p <= 0:
            return puno(s, p, -15 * e, -9 * e, -1, 0)
        if math.hypot(s + 7.5 * e, (p - 2.5) * 0.9) <= 2.2:                  # el carrete
            return BRI if p < 2 and s < -7.5 * e else (MET if p < 3.5 else HON)
        if -9 * e <= s <= 15 * e and p == 0:
            return MAD_L if s < 4 * e else MAD
        if -9 * e <= s <= 6 * e and p == 1:
            return MAD_S
        return 0
    diag(cv, f)
    # el sedal: de la punta hacia abajo, en curva
    for k in range(int(n * 0.55)):
        x = int(n * 0.92 - k * 0.12)
        y = int(n * 0.10 + k)
        if 0 <= x < n and 0 <= y < n and cv.p[y][x] == 0:
            cv.pon(x, y, CUERDA)


def cuchillo(cv):
    # CUCHILLO DE DESOLLAR: hoja ancha de un solo filo que se curva a la punta y mango de madera con dos remaches
    def f(s, p, e):
        if -13 * e <= s < -2 * e and -1 <= p <= 1:
            if abs(s + 10 * e) < 0.6 or abs(s + 5 * e) < 0.6:
                return MET_L if p <= 0 else MET_S                           # los remaches
            return MAD_L if p == -1 else (MAD if p == 0 else MAD_S)
        if -2 * e <= s < -1 * e and -2 <= p <= 1:
            return MET_S                                                     # el tope
        if -1 * e <= s <= 9 * e:
            falta = 9 * e - s
            arriba = -5 if falta > 5 else (-4 if falta > 3.5 else (-3 if falta > 2 else -2))
            abajo = 0 if falta > 1.5 else -1
            if arriba <= p <= abajo:
                if p == arriba:
                    return BRI if s < 5 * e else MET_L                      # el filo
                if p == abajo:
                    return HON                                               # el lomo
                return MET
        return 0
    diag(cv, f)


HERRAMIENTAS = [("Pico", pico), ("Hacha de talar", hacha_talar), ("Hoz", hoz), ("Caña", cana),
                ("Cuchillo", cuchillo)]


def main():
    salida = sys.argv[1] if len(sys.argv) > 1 else "herramientas_lamina.png"
    with open(os.path.join(EP.AQUI, "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC, N = 4, 32
    COLS = EP.COLUMNAS[:3]
    cw = N * ESC + 12
    x0 = 160
    fila = N * ESC + 16
    w = x0 + cw * len(COLS) + N + 30
    h = 66 + fila * len(HERRAMIENTAS)
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "HERRAMIENTAS EN PIXEL (32 px): T1, T2 y T3 a x4, y T2 a tamano real", fill=(240, 190, 100), font=f1)
    for i, (_t, _m, nom) in enumerate(COLS):
        d.text((x0 + i * cw, 42), nom, fill=(200, 200, 210), font=f2)
    for j, (nombre, fn) in enumerate(HERRAMIENTAS):
        y = 62 + j * fila
        d.text((16, y + 56), nombre, fill=(220, 220, 228), font=f2)
        cv = EP.dibujar(fn, N)
        for k, (t, m, _n) in enumerate(COLS):
            im = EP.teñir(cv, A.paleta(PAL["arma|metal|%d|%d" % (t, m)]))
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            lam.paste(g, (x0 + k * cw, y), g)
            if t == 2:
                lam.paste(im, (x0 + len(COLS) * cw + 6, y + N * ESC - N), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
