# ============================================================
#  equipo_armas.py  (06/11, rework visual a pixel; el jefe: "va dale")
#  LAS ARMAS EN PIXEL ART DE VERDAD para la celda del inventario, con lo aprendido en las armaduras: el metal se lee
#  por CONTRASTE (BRILLO casi blanco en el filo de la luz, HONDO en el de la sombra), la luz viene de arriba a la
#  izquierda y cada arma va en DIAGONAL (pomo abajo a la izquierda, punta arriba a la derecha).
#
#  Tonos = los de ArmaSprites.ROLES (2 borde, 3/4 mango de cuero, 5/6/7 metal, 8/9/10 madera, 11 cuerda, 12/13 pluma)
#  y DOS NUEVOS: 14 BRILLO y 15 HONDO del material (ArmaSprites.ROLES_ICONO, Rol.MATERIAL_B / MATERIAL_O). En el
#  baston, la varita y el arco el "material" es MADERA (ArmaSprites.familia_de), asi que su piedra va en pluma (roja).
#    python tools/equipo_armas.py [salida.png]   (la lamina)
#    python tools/equipo_armas.py --hornear      (los PNG del juego en assets/sprites/equipo/arma)
# ============================================================
import colorsys
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
from equipo_pixel import B, MANGO_S, MANGO, MET_S, MET, MET_L, MAD_S, MAD, MAD_L, diag
from PIL import Image, ImageDraw, ImageFont

CUERDA, PLUMA, PLUMA_S = 11, 12, 13
BRI, HON = 14, 15


def derivar(c, f, sat):
    h, s, v = colorsys.rgb_to_hsv(*c[:3])
    return colorsys.hsv_to_rgb(h, min(1.0, s * sat), min(1.0, v * f)) + (1.0,)


def paleta(pal):
    pal = list(pal) + [None] * (16 - len(pal))
    pal[BRI] = derivar(pal[MET], 1.55, 0.30)
    pal[HON] = derivar(pal[MET], 0.36, 1.20)
    return pal


# ---- las piezas de siempre ----
def hoja(p, arriba, abajo, s=0.0, brillo=(-99, 99), acanalada=False):
    # Una hoja de 'arriba' a 'abajo' filas de diagonal: filo de la luz en BRILLO (en su tramo) o luz, cuerpo, la
    # acanaladura en sombra y el filo de la sombra en HONDO.
    if p == arriba:
        return BRI if brillo[0] <= s <= brillo[1] else MET_L
    if p == abajo and abajo - arriba >= 2:
        return HON
    if acanalada and p == (arriba + abajo) // 2 + (0 if (abajo - arriba) % 2 else 0) and abajo - arriba >= 3:
        return MET_S
    if p < (arriba + abajo) / 2.0:
        return MET_L if p == arriba + 1 and abajo - arriba >= 4 else MET
    return MET if abajo - arriba <= 2 else MET_S


def pomo(s, p, s0, s1, r=1):
    if s0 <= s < s1 and -r - 1 <= p <= r:
        return BRI if (p == -r - 1 and s < (s0 + s1) / 2) else (MET_L if p < 0 else (MET if p == 0 else HON))
    return 0


def puno(s, p, s0, s1, a=-1, b=1):
    if s0 <= s < s1 and a <= p <= b:
        return MANGO_S if (p == b or int((s + 40) * 1.4) % 3 == 0) else MANGO
    return 0


def guarda(s, p, s0, s1, ancho):
    if s0 <= s < s1 and abs(p) <= ancho:
        if p == -ancho:
            return BRI
        return MET_L if p < 0 else (MET if p < ancho else HON)
    return 0


def primero(*vals):
    for v in vals:
        if v:
            return v
    return 0


# ---- LAS ESPADAS ----
def daga(cv):
    def f(s, p, e):
        return primero(pomo(s, p, -13 * e, -10.5 * e), puno(s, p, -10.5 * e, -5 * e),
                       guarda(s, p, -5 * e, -3 * e, 4),
                       hoja(p, -2 if s < 7 * e else (-1 if s < 10 * e else 0), 1 if s < 10 * e else 0, s,
                            (-1 * e, 5 * e)) if -3 * e <= s <= 12.5 * e and
                       (-2 if s < 7 * e else (-1 if s < 10 * e else 0)) <= p <= (1 if s < 10 * e else 0) else 0)
    diag(cv, f)


def _espada(cv, pomo_s, puno_s, guarda_s, punta_s, ancho_g, arriba, abajo, pomo_r=1, puno_ab=(-1, 1)):
    def f(s, p, e):
        v = primero(pomo(s, p, pomo_s[0] * e, pomo_s[1] * e, pomo_r),
                    puno(s, p, puno_s[0] * e, puno_s[1] * e, *puno_ab),
                    guarda(s, p, guarda_s[0] * e, guarda_s[1] * e, ancho_g))
        if v:
            return v
        if guarda_s[1] * e <= s <= punta_s * e:
            # la punta: las ultimas filas se estrechan hacia la del centro
            falta = punta_s * e - s
            a = arriba if falta > 2.5 else max(arriba, -1 if falta > 1 else 0)
            b = abajo if falta > 2.5 else min(abajo, 0)
            if a <= p <= b:
                return hoja(p, a, b, s, (guarda_s[1] * e + 1, guarda_s[1] * e + 7 * e), acanalada=falta > 6)
        return 0
    diag(cv, f)


def espada_corta(cv):
    _espada(cv, (-14, -11.5), (-11.5, -7), (-7, -5), 13, 4, -2, 1)


def espada_larga(cv):
    _espada(cv, (-15.5, -13.5), (-13.5, -8), (-8, -6), 15.5, 5, -2, 1)


def mandoble(cv):
    # el de dos manos: puño largo, guarda ancha, hoja de cinco filas
    _espada(cv, (-15.5, -13.5), (-13.5, -6), (-6, -4), 15.5, 6, -3, 1, pomo_r=1)


def estoque(cv):
    # hoja muy fina y larga y la CAZOLETA: un aro de metal que envuelve la mano
    def f(s, p, e):
        v = primero(pomo(s, p, -15 * e, -13 * e), puno(s, p, -13 * e, -8.5 * e, 0, 1))
        if v:
            return v
        # la cazoleta: media luna alrededor del puño, del lado de la luz, y el gavilan cruzado
        d = math.hypot((s + 8.5 * e) * 1.0, (p + 0.5) * 0.75)
        if -11.5 * e <= s <= -6.5 * e and p <= 0 and 3.2 * e <= d <= 4.6 * e:
            return BRI if d < 3.6 * e and p < -2 else (MET_L if p < -1 else MET)
        v = guarda(s, p, -8.5 * e, -7.3 * e, 4)
        if v:
            return v
        if -7.3 * e <= s <= 15.5 * e and -1 <= p <= 0 and not (s > 13 * e and p == -1):
            return (BRI if s < 3 * e else MET_L) if p == -1 else MET_S
        return 0
    diag(cv, f)


# ---- LAS DE ASTA ----
def hacha_grande(cv):
    def f(s, p, e):
        c, r = 8.5 * e, 6.0 * e
        q = -p
        if q >= 1:
            hw = 1.6 * e if q <= 3 else min(r, 1.6 * e + (q - 3) * 1.25 * e)
            borde = 3 + 5.5 * e + 1.6 * e * math.sqrt(max(0.0, 1.0 - ((s - c) / r) ** 2))
            if abs(s - c) <= hw and q <= borde:
                if q >= borde - 1.2:
                    return BRI if s < c else MET_L                         # el filo
                if abs(s - c) >= hw - 0.6:
                    return HON if s > c else MET_S
                return MET_L if q > borde - 2.5 else MET
        if 2 <= p <= 4 and abs(s - c) <= (2.2 - (p - 2) * 0.6) * e:
            return HON if p > 2 else MET_S
        if -15 * e <= s <= 13 * e and -1 <= p <= 1:
            if abs(s - c) <= 2.2 * e:
                return MET_L if p == -1 else (MET if p == 0 else HON)
            if s < -11.5 * e:
                return puno(s, p, -15 * e, -11.5 * e)
            return MAD_L if p == -1 else (MAD if p == 0 else MAD_S)
        return 0
    diag(cv, f)


def maza_peq(cv):
    # MAZA DE ALETAS: la cabeza redonda con sus aletas y el mango corto forrado
    def f(s, p, e):
        c = 8.5 * e
        d = math.hypot(s - c, p * 0.72)
        ang = math.atan2(p, s - c)
        aleta = abs(math.sin(ang * 3)) > 0.80
        if d <= (5.4 if aleta else 4.0) * e:
            luz = -(s - c) * 0.5 - p * 0.7                                 # hacia arriba-izquierda
            if aleta and d > 4.0 * e:
                return BRI if luz > 1.5 else (MET_L if luz > -1 else HON)
            if luz > 2.2 * e:
                return BRI
            if luz > 0.8 * e:
                return MET_L
            if luz > -1.5 * e:
                return MET
            return MET_S if d < 3.0 * e else HON
        if 4 * e <= s - c <= 6.5 * e and abs(p) <= 0:
            return MET_L                                                   # la punta de arriba
        return primero(pomo(s, p, -13 * e, -11 * e), puno(s, p, -11 * e, -2 * e),
                       (MET_L if p == -1 else (MET if p == 0 else HON)) if -2 * e <= s <= c and -1 <= p <= 1 else 0)
    diag(cv, f)


def martillo_grande(cv):
    # MARTILLO DE GUERRA: una cabeza de bloque atravesada en el asta, con la cara plana y el pico detras
    def f(s, p, e):
        c = 9.5 * e
        if abs(s - c) <= 3.4 * e and -8 * e <= p <= 7 * e:
            if p < -5 * e:                                                  # la cara de golpear
                return BRI if p < -7 * e and s < c else (MET_L if s < c + 1 else MET_S)
            if p > 3 * e:                                                   # el pico, que se estrecha
                if abs(s - c) <= 3.4 * e - (p - 3 * e) * 0.8:
                    return MET if s < c else HON
                return 0
            if s - c > 2.2 * e:
                return HON
            return MET_L if s - c < -2.2 * e else MET
        if c + 3.4 * e < s <= c + 5.5 * e and -1 <= p <= 0:
            return MET_L if p == -1 else MET                                # la punta de arriba
        if -15 * e <= s <= c and -1 <= p <= 1:
            if s < -11 * e:
                return puno(s, p, -15 * e, -11 * e)
            return MAD_L if p == -1 else (MAD if p == 0 else MAD_S)
        return 0
    diag(cv, f)


# ---- LAS DE MADERA (su "material" es madera) ----
def baston(cv):
    # BASTON: asta nudosa, la cabeza que abraza una PIEDRA roja y una vuelta de cuerda
    def f(s, p, e):
        c = 10.5 * e
        if math.hypot(s - c, p * 0.8) <= 2.3 * e:                         # la piedra
            luz = -(s - c) - p
            return BRI if luz > 2.0 * e else (PLUMA if luz > -1.0 * e else PLUMA_S)
        d = math.hypot(s - c, p * 0.8)
        if 2.3 * e < d <= 4.0 * e and s > c - 3.5 * e:                     # las garras que la sujetan
            return MET_L if p < 0 else (MET if p <= 1 else MET_S)
        if -15 * e <= s <= c - 3 * e and -1 <= p <= 1:
            if -2 * e <= s <= 0.5 * e:
                return CUERDA if int(s * 2) % 2 == 0 or p == -1 else MANGO_S
            nudo = abs(math.sin(s * 0.9)) > 0.93
            if nudo and p == 1:
                return MET_S
            return MET_L if p == -1 else (MET if p == 0 else MET_S)
        return 0
    diag(cv, f)


def varita(cv):
    # VARITA: corta y fina, el puño de cuero y la punta con su chispa
    def f(s, p, e):
        if math.hypot(s - 10 * e, p) <= 1.5 * e:
            return BRI if p < 0 else PLUMA
        if -9 * e <= s < -3 * e and -1 <= p <= 1:
            return puno(s, p, -9 * e, -3 * e)
        if -3 * e <= s <= 9 * e and -1 <= p <= 0:
            return MET_L if p == -1 else MET_S
        if -10.5 * e <= s < -9 * e and -1 <= p <= 1:
            return MET
        return 0
    diag(cv, f)


def arco(cv):
    # ARCO: las palas en curva (madera), el puño de cuero en medio y la CUERDA tensa de punta a punta; de pie.
    n = cv.n
    punta_x = 0.30 + 0.24                                     # donde acaban las palas: ahi se ata la cuerda
    for y in range(n):
        for x in range(n):
            fx, fy = (x + 0.5) / n, (y + 0.5) / n
            v = fy - 0.5                                       # -0.5 .. 0.5 de arriba a abajo
            if abs(v) <= 0.43:
                curva = 0.30 + 0.24 * (v / 0.43) ** 2          # la pala, abierta hacia la derecha
                grueso = 0.10 - abs(v) * 0.10
                d = fx - curva
                if 0.0 <= d <= grueso:
                    if abs(v) < 0.09:
                        cv.pon(x, y, MANGO if d < grueso * 0.6 else MANGO_S)
                    else:
                        cv.pon(x, y, BRI if d < 0.02 and v < -0.15 else
                               (MET_L if d < grueso * 0.4 else (MET if d < grueso * 0.75 else MET_S)))
            if abs(v) <= 0.42 and abs(fx - punta_x - 0.01) < 0.5 / n:
                cv.pon(x, y, CUERDA)
    for k in (-1, 1):                                          # los remates de las puntas
        EP.punto(cv, punta_x, 0.5 + k * 0.43, MET_S)


def ballesta(cv):
    # BALLESTA: la culata de madera en diagonal, el ARCO DE METAL atravesado arriba, la cuerda y el virote
    def f(s, p, e):
        c = 7.0 * e
        if abs(s - c) <= 1.0 * e and abs(p) <= 11:                         # el arco de metal
            curva = abs(p) * 0.10
            if abs(s - c + curva) <= 1.0 * e:
                return BRI if p < -6 else (MET_L if p < 0 else (MET if p < 6 else HON))
        if abs(s - (c - 2.6 * e + abs(p) * 0.22)) < 0.6 and 1 <= abs(p) <= 10:
            return CUERDA                                                    # la cuerda, en V hacia la nuez
        if c - 1 * e < s <= 14 * e and -2 <= p <= -2:
            return MET_L if s < 12.5 * e else MET                          # el virote
        if 12.5 * e < s <= 14.5 * e and -3 <= p <= -1:
            return PLUMA if p != -1 else PLUMA_S
        if -14 * e <= s <= c and -1 <= p <= 1:                              # la culata
            if s < -9 * e and p >= 0:
                return MAD_S
            return MAD_L if p == -1 else (MAD if p == 0 else MAD_S)
        if -3 * e <= s <= -1 * e and 2 <= p <= 4:                           # el gatillo
            return MET_S
        return 0
    diag(cv, f)


ARMAS = [
    ("Daga", "daga", daga), ("Espada corta", "espada_corta", espada_corta),
    ("Espada larga", "espada_larga", espada_larga), ("Mandoble", "mandoble", mandoble),
    ("Estoque", "estoque", estoque), ("Hacha grande", "hacha_grande", hacha_grande),
    ("Maza", "maza_peq", maza_peq), ("Martillo grande", "martillo_grande", martillo_grande),
    ("Baston", "baston", baston), ("Varita", "varita", varita),
    ("Arco", "arco", arco), ("Ballesta", "ballesta", ballesta),
]
MADERA = ["baston", "varita", "arco"]   # ArmaSprites.familia_de
RAMPA_TONOS = 16


def hornear(carpeta):
    os.makedirs(carpeta, exist_ok=True)
    for _n, clave, fn in ARMAS:
        cv = EP.dibujar(fn, 32)
        im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
        for y in range(32):
            for x in range(32):
                t = cv.p[y][x]
                if t:
                    g = int(round(t / (RAMPA_TONOS - 1) * 255))
                    im.putpixel((x, y), (g, g, g, 255))
        im.save(os.path.join(carpeta, "%s.png" % clave))
    print("%d armas en %s" % (len(ARMAS), carpeta))


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--hornear":
        hornear(sys.argv[2] if len(sys.argv) > 2 else "assets/sprites/equipo/arma")
        return
    salida = sys.argv[1] if len(sys.argv) > 1 else "armas_lamina.png"
    with open(os.path.join(EP.AQUI, "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC, N = 3, 32
    COLS = EP.COLUMNAS
    celda = N * ESC + 6
    grupo = celda * len(COLS) + N + 24
    POR_FILA = 2
    x0 = 20
    fila = N * ESC + 34
    w = x0 + grupo * POR_FILA + 10
    filas = (len(ARMAS) + POR_FILA - 1) // POR_FILA
    h = 70 + fila * filas
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "ARMAS EN PIXEL (32 px): T1, T2, T3 y T3+12 a x3, y T2 a tamano real", fill=(240, 190, 100), font=f1)
    for i, (nombre, clave, fn) in enumerate(ARMAS):
        gx = x0 + (i % POR_FILA) * grupo
        y = 50 + (i // POR_FILA) * fila
        d.text((gx, y), nombre, fill=(220, 220, 228), font=f2)
        cv = EP.dibujar(fn, N)
        fam = "madera" if clave in MADERA else "metal"
        for k, (t, m, nom) in enumerate(COLS):
            im = EP.teñir(cv, paleta(PAL["arma|%s|%d|%d" % (fam, t, m)]))
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            lam.paste(g, (gx + k * celda, y + 18), g)
            if t == 2 and m == 0:
                lam.paste(im, (gx + len(COLS) * celda + 4, y + 18 + N * ESC - N), im)
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
