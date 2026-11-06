# ============================================================
#  equipo_faroles.py  (06/11, rework visual a pixel) EL FAROLILLO Y LA MOCHILA en pixel art de verdad, para la celda.
#  Hoy salen de las facetas de sprites_objeto.gd (_farol_1/2/3 y _mochila). LAMINA DE PRUEBA con versiones: no toca el
#  juego hasta su visto bueno.
#
#  EL FAROLILLO cambia de aspecto con el tier (las tres referencias del jefe): T1 farol cuadrado, T2 candil con asa,
#  T3 farol labrado de luz azul. Sus colores son FIJOS por tier (cobre, laton, hierro negro), como ahora: se dibuja ya
#  en color. Dos versiones de cada uno.
#  LA MOCHILA se tiñe por tier y +N con el CUERO de la armadura (paletas_equipo.json "armadura|cuero|t|m"), asi que se
#  dibuja en los tonos de ArmaduraSprites.ROLES_ICONO. Tres versiones.
#    python tools/equipo_faroles.py [salida.png]
#    python tools/equipo_faroles.py --hornear   (lo elegido, a assets/sprites/equipo/herramienta)
# ============================================================
import colorsys
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import equipo_pixel as EP
from equipo_pixel import Lienzo, B
from PIL import Image, ImageDraw, ImageFont

N = 32

# ---- tonos del FAROL (colores propios, no los de PaletaEquipo) ----
M_S, M, M_L, M_B, M_H = 3, 4, 5, 6, 7            # metal: sombra, base, luz, brillo, hondo
V_S, V, V_L = 8, 9, 10                           # el cristal encendido: borde, cuerpo, reflejo
LL, LL_C = 11, 12                                # la llama y su corazon
CH = 13                                          # chispa suelta (fuera del contorno)


def hsv(c, f, sat):
    h, s, v = colorsys.rgb_to_hsv(*c)
    return colorsys.hsv_to_rgb(h, min(1.0, s * sat), min(1.0, v * f))


def paleta_farol(metal, cristal, llama, llama_c):
    p = [None] * 16
    p[B] = (0.08, 0.08, 0.10)
    p[M] = metal
    p[M_S] = hsv(metal, 0.62, 1.12)
    p[M_L] = hsv(metal, 1.24, 0.68)
    p[M_B] = hsv(metal, 1.55, 0.30)
    p[M_H] = hsv(metal, 0.36, 1.20)
    p[V] = cristal
    p[V_S] = hsv(cristal, 0.62, 1.15)
    p[V_L] = hsv(cristal, 1.25, 0.55)
    p[LL] = llama
    p[LL_C] = llama_c
    p[CH] = llama_c
    return p


# Los de ahora (FAROL_COLOR de sprites_objeto.gd): cobre, laton y hierro negro; luz calida, calida y AZUL.
PAL_FAROL = [
    paleta_farol((0.70, 0.44, 0.22), (0.95, 0.58, 0.20), (1.00, 0.80, 0.30), (1.00, 0.97, 0.80)),
    paleta_farol((0.78, 0.56, 0.26), (0.98, 0.66, 0.24), (1.00, 0.84, 0.36), (1.00, 0.98, 0.84)),
    paleta_farol((0.30, 0.31, 0.38), (0.26, 0.56, 0.95), (0.55, 0.85, 1.00), (0.92, 0.98, 1.00)),
]


# ---- primitivas en PIXELES (no normalizadas: a 32 px se manda pixel a pixel) ----
def rect(cv, x0, y0, x1, y1, t):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            cv.pon(x, y, t)


def elipse(cv, cx, cy, rx, ry, t):
    m = set()
    for y in range(N):
        for x in range(N):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1.0:
                m.add((x, y))
                cv.pon(x, y, t)
    return m


def metal_caja(cv, x0, y0, x1, y1):
    # Una pieza de metal: luz arriba/izquierda con un pixel de BRILLO, sombra abajo/derecha con HONDO en la esquina.
    rect(cv, x0, y0, x1, y1, M)
    for x in range(x0, x1 + 1):
        cv.pon(x, y0, M_L)
        cv.pon(x, y1, M_S)
    for y in range(y0, y1 + 1):
        cv.pon(x0, y, M_L)
        cv.pon(x1, y, M_S)
    cv.pon(x0, y0, M_B)
    cv.pon(x1, y1, M_H)


def cristal(cv, m, cx, cy, alto, chispa=True):
    # El cristal encendido: cuerpo, borde de dentro en sombra, reflejo arriba a la izquierda, y la llama en medio.
    xs = [x for x, _ in m]
    ys = [y for _, y in m]
    for (x, y) in m:
        cv.pon(x, y, V)
    for (x, y) in m:
        if (x + 1, y) not in m or (x, y + 1) not in m:
            cv.pon(x, y, V_S)
    x0, y0 = min(xs), min(ys)
    for (x, y) in m:
        if (x - x0) + (y - y0) <= 1 and (x - 1, y) in m:
            cv.pon(x, y, V_L)
    # la llama: una gota de 'alto' px con su corazon blanco
    for k in range(alto):
        y = cy - k
        ancho = 1 if k >= alto - 1 else (2 if k < alto // 2 + 1 else 1)
        for dx in range(ancho):
            cv.pon(cx + dx - (ancho // 2), y, LL)
    cv.pon(cx, cy - 1, LL_C)
    if alto >= 4:
        cv.pon(cx, cy - 2, LL_C)


def anilla(cv, cx, y):
    # La anilla de colgar, de 4 x 4 hueca.
    for (x, yy) in [(cx - 1, y), (cx, y), (cx - 2, y + 1), (cx + 1, y + 1), (cx - 2, y + 2), (cx + 1, y + 2),
                    (cx - 1, y + 3), (cx, y + 3)]:
        cv.pon(x, yy, M_L if x < cx else M_S)


# ================= EL FAROLILLO =================
# T1 A: EL FAROL CUADRADO de la referencia: tejadillo en punta, alero, dos cristales con su llama, pie con patas.
def farol1_a(cv):
    anilla(cv, 16, 0)
    for k, y in enumerate(range(4, 10)):                           # el tejadillo en punta
        a = 1 + k * 1.4
        for x in range(int(16 - a), int(16 + a)):
            cv.pon(x, y, M_L if x < 15 else (M if x < 17 else M_S))
    cv.pon(15, 4, M_B)
    metal_caja(cv, 7, 10, 24, 11)                                  # el alero
    metal_caja(cv, 9, 12, 22, 25)                                  # el bastidor
    for (x0, x1) in [(11, 14), (17, 20)]:
        m = {(x, y) for x in range(x0, x1 + 1) for y in range(13, 25)}
        cristal(cv, m, (x0 + x1 + 1) // 2, 22, 4)
    rect(cv, 15, 12, 16, 25, M)
    cv.pon(15, 12, M_L)
    metal_caja(cv, 8, 26, 23, 27)                                  # el pie
    rect(cv, 9, 28, 10, 28, M_S)
    rect(cv, 21, 28, 22, 28, M_H)


# T1 B: EL FAROL DE HOJALATA PERFORADA: cono, cuerpo redondo y la luz saliendo por los agujeritos en filas.
def farol1_b(cv):
    anilla(cv, 16, 0)
    for k, y in enumerate(range(4, 11)):                           # el cono
        a = 1 + k * 1.2
        for x in range(int(16 - a), int(16 + a)):
            cv.pon(x, y, M_L if x < 14 else (M if x < 18 else M_S))
    cv.pon(15, 4, M_B)
    metal_caja(cv, 8, 11, 23, 12)
    rect(cv, 9, 13, 22, 25, M)                                     # el cuerpo: cilindro, luz a la izquierda
    for y in range(13, 26):
        cv.pon(9, y, M_S)
        cv.pon(10, y, M_L)
        cv.pon(11, y, M_B if y in (14, 15) else M_L)
        cv.pon(21, y, M_S)
        cv.pon(22, y, M_H)
    for fila, y in enumerate(range(14, 25, 2)):                    # los agujeritos encendidos, al tresbolillo
        for x in range(12 + (fila % 2), 21, 2):
            cv.pon(x, y, LL_C if (y in (18, 20) and 14 <= x <= 18) else (LL if 13 <= x <= 19 else V_S))
    rect(cv, 13, 17, 18, 21, 0)                                    # la puerta abierta, con la vela dentro
    m = {(x, y) for x in range(13, 19) for y in range(17, 22)}
    cristal(cv, m, 16, 20, 3)
    metal_caja(cv, 8, 26, 23, 27)
    rect(cv, 10, 28, 21, 28, M_S)


# T2 A: EL CANDIL de la referencia: asa en arco, tapa, globo de cristal con varillas y pie.
def farol2_a(cv):
    import math
    for k in range(60):                                            # el asa en arco, seguida
        a = math.pi * (1.06 + 0.88 * k / 59.0)
        x = int(round(15.5 + math.cos(a) * 8.5))
        y = int(round(9.5 + math.sin(a) * 8.0))
        cv.pon(x, y, M_L if x <= 15 else M_S)
    rect(cv, 12, 6, 19, 7, M)                                      # la tapa
    cv.pon(12, 6, M_B)
    rect(cv, 13, 5, 18, 5, M_L)
    metal_caja(cv, 11, 8, 20, 9)
    m = elipse(cv, 16, 17, 7.6, 7.2, V)                            # el globo
    cristal(cv, m, 16, 20, 5)
    for (x0, xm) in [(12, 9), (20, 23)]:                           # las varillas
        for y in range(10, 25):
            u = abs(y - 17) / 7.0
            x = int(round(xm + (x0 - xm) * u * u))
            cv.pon(x, y, M_L if x < 16 else M_S)
    for y in range(10, 25):
        cv.pon(16, y, M_S if (16, y) in m else M)
    metal_caja(cv, 10, 24, 21, 25)                                 # el pie
    metal_caja(cv, 9, 26, 22, 27)
    rect(cv, 11, 28, 20, 28, M_S)


# T2 B: EL QUINQUE DE TORMENTA: asa de alambre, chimenea arriba, cristal en bulbo, dos guardas a los lados y el
# deposito redondo del aceite con su ruedecita.
def farol2_b(cv):
    import math
    for k in range(60):                                            # el asa de alambre, seguida
        a = math.pi * (1.0 + k / 59.0)
        cv.pon(int(round(15.5 + math.cos(a) * 7.5)), int(round(8.5 + math.sin(a) * 7)), M_L if k < 30 else M_S)
    metal_caja(cv, 13, 3, 18, 7)                                   # la chimenea
    rect(cv, 14, 4, 17, 4, M_B)
    metal_caja(cv, 10, 8, 21, 9)                                   # la tapa del cristal
    m = elipse(cv, 16, 16.5, 6.6, 6.6, V)                          # el bulbo
    cristal(cv, m, 16, 19, 5)
    for x in (8, 23):                                              # las guardas laterales
        for y in range(9, 25):
            cv.pon(x, y, M_L if x == 8 else M_S)
        cv.pon(x + (1 if x == 8 else -1), 9, M)
        cv.pon(x + (1 if x == 8 else -1), 24, M)
    md = elipse(cv, 16, 26.5, 9.2, 3.6, M)                         # el deposito
    for (x, y) in md:
        cv.pon(x, y, M_L if y <= 25 else (M_S if y >= 28 else M))
    cv.pon(10, 25, M_B)
    cv.pon(11, 25, M_B)
    rect(cv, 24, 25, 25, 26, M_S)                                  # la ruedecita de la mecha
    cv.pon(24, 25, M_L)


# T3 A: EL FAROL LABRADO de la referencia: anilla, tejado con los aleros VUELTOS hacia arriba, cristal azul con su
# cruz de varillas y la luz suelta por fuera.
def farol3_a(cv):
    anilla(cv, 16, 0)
    rect(cv, 15, 4, 16, 5, M)
    for k, y in enumerate(range(6, 10)):                           # el tejado
        a = 3 + k * 2
        for x in range(16 - a, 16 + a):
            cv.pon(x, y, M_L if x < 14 else (M if x < 18 else M_S))
    for (x, y) in [(6, 9), (5, 8), (25, 9), (26, 8), (7, 10), (24, 10)]:   # los aleros vueltos
        cv.pon(x, y, M_L if x < 16 else M_S)
    rect(cv, 7, 10, 24, 10, M_S)
    metal_caja(cv, 9, 11, 22, 25)
    m = {(x, y) for x in range(11, 21) for y in range(13, 24)}
    cristal(cv, m, 16, 21, 5)
    for y in range(13, 24):                                        # la cruz labrada
        cv.pon(15, y, M_S)
    for x in range(11, 21):
        cv.pon(x, 16, M_S)
    for (x, y) in [(12, 14), (19, 14), (12, 22), (19, 22)]:
        cv.pon(x, y, M_H)
    metal_caja(cv, 8, 26, 23, 27)
    rect(cv, 9, 28, 11, 28, M_S)
    rect(cv, 20, 28, 22, 28, M_H)


# T3 B: EL FAROL GOTICO: aguja en punta, ventana de ARCO APUNTADO en azul y una flor de lis en el pie.
def farol3_b(cv):
    cv.pon(16, 0, M_B)
    rect(cv, 15, 1, 16, 3, M)
    cv.pon(15, 1, M_L)
    for k, y in enumerate(range(4, 11)):                           # la aguja
        a = 1 + k
        for x in range(16 - a, 16 + a):
            cv.pon(x, y, M_L if x < 15 else (M if x < 17 else M_S))
    rect(cv, 8, 11, 23, 11, M_S)
    metal_caja(cv, 9, 12, 22, 25)
    m = set()
    for y in range(14, 25):                                        # el arco apuntado
        for x in range(11, 21):
            if y >= 18 or abs(x + 0.5 - 16) <= (y - 13) * 1.25:
                m.add((x, y))
    cristal(cv, m, 16, 22, 5)
    for y in range(17, 25):
        cv.pon(13, y, M_S)
        cv.pon(18, y, M_S)
    metal_caja(cv, 8, 26, 23, 27)
    for (x, y) in [(15, 28), (16, 28), (14, 29), (17, 29), (15, 30), (16, 30)]:   # la flor del pie
        cv.pon(x, y, M_L if x < 16 else M_S)


FAROLES = [("T1 farol cuadrado", [("A", farol1_a), ("B hojalata", farol1_b)]),
           ("T2 candil", [("A", farol2_a), ("B quinque", farol2_b)]),
           ("T3 labrado azul", [("A", farol3_a), ("B gotico", farol3_b)])]


def chispas(cv, tier):
    # La luz SUELTA por fuera (solo el T3, como ahora): fuera del contorno, se pone despues.
    if tier == 3:
        for (x, y) in [(4, 16), (27, 20), (26, 13)]:
            if cv.get(x, y) == 0:
                cv.p[y][x] = CH


# ================= LA MOCHILA (tonos de ArmaduraSprites.ROLES_ICONO) =================
C_S, C, C_L, OSC, ACE = 3, 4, 5, 6, 7


def cuero(cv, m):
    EP.volumen(cv, m, C, C_L, C_S)


def hebilla(cv, x, y):
    cv.pon(x, y, ACE)
    cv.pon(x + 1, y, ACE)
    cv.pon(x, y + 1, ACE)
    cv.pon(x + 1, y + 1, OSC)


# A: LA CARTERA de ahora: asa, cuerpo, solapa con dos correas y hebillas, dos bolsillos.
def mochila_a(cv):
    for (x, y) in [(12, 3), (13, 2), (14, 2), (15, 2), (16, 2), (17, 2), (18, 2), (19, 3), (11, 4), (20, 4),
                   (11, 5), (20, 5), (11, 6), (20, 6)]:
        cv.pon(x, y, C_L if x < 16 else C_S)
    cuerpo = {(x, y) for x in range(5, 27) for y in range(8, 28)} - {(5, 8), (26, 8), (5, 27), (26, 27)}
    cuero(cv, cuerpo)
    solapa = {(x, y) for x in range(6, 26) for y in range(8, 16)} - {(6, 15), (25, 15), (7, 15), (24, 15)}
    EP.volumen(cv, solapa, C_L, C_L, C)
    for x in range(7, 25):
        cv.pon(x, 16, C_S)
    for xx in (10, 20):                                            # las correas
        for y in range(9, 19):
            cv.pon(xx, y, OSC if y < 18 else C_S)
            cv.pon(xx + 1, y, C_S)
        hebilla(cv, xx, 15)
    for (x0, x1) in [(6, 13), (18, 25)]:                           # los bolsillos
        rect(cv, x0, 19, x1, 26, C_S)
        rect(cv, x0, 19, x1, 21, C)
        for x in range(x0, x1 + 1):
            cv.pon(x, 21, C_S)
        hebilla(cv, (x0 + x1) // 2, 21)


# B: LA MOCHILA DE AVENTURERO: la manta enrollada encima con sus dos correas, solapa redonda, bolsillo y cantimplora
# colgada al lado.
def mochila_b(cv):
    for y in range(2, 8):                                          # la manta enrollada (tela clara: el ACENTO no; luz)
        for x in range(6, 26):
            cv.pon(x, y, C_L if y < 4 else (C if y < 6 else C_S))
    for y in range(3, 7):
        cv.pon(6, y, C_S)
        cv.pon(25, y, C_S)
        cv.pon(7, y, OSC if y in (4, 5) else C_S)                  # la espiral del extremo
    for x in range(6, 26):                                         # la raya entre la manta y el saco
        cv.pon(x, 7, OSC)
    for xx in (11, 20):
        for y in range(1, 9):
            cv.pon(xx, y, OSC)
    cuerpo = {(x, y) for x in range(7, 25) for y in range(8, 29)} - {(7, 28), (24, 28), (7, 8), (24, 8)}
    cuero(cv, cuerpo)
    solapa = set()
    for y in range(8, 18):
        for x in range(7, 25):
            if y < 15 or abs(x + 0.5 - 16) <= 8 - (y - 14) * 2:
                solapa.add((x, y))
    EP.volumen(cv, solapa, C_L, C_L, C)
    for (x, y) in solapa:
        if (x, y + 1) not in solapa:
            cv.pon(x, y + 1, C_S)
    hebilla(cv, 15, 16)
    rect(cv, 10, 21, 21, 27, C_S)                                  # el bolsillo
    rect(cv, 10, 21, 21, 22, C)
    hebilla(cv, 15, 22)
    elipse(cv, 26.5, 21, 3.0, 4.2, OSC)                            # la cantimplora
    for y in range(18, 25):
        for x in range(24, 30):
            if cv.get(x, y) == OSC:
                cv.pon(x, y, ACE if (x == 25 and y < 21) else (C_S if x > 27 else OSC))
    rect(cv, 26, 15, 27, 16, C_S)


# C: EL HATILLO: un saco de cuero atado con su cordon, la boca fruncida arriba y una correa en bandolera.
def mochila_c(cv):
    import math
    m = set()
    for y in range(9, 30):
        v = (y - 9) / 20.0
        r = 6 + 6 * math.sin(min(1.0, v * 1.25) * math.pi * 0.62)
        if y > 26:
            r -= (y - 26) * 1.6
        for x in range(N):
            if abs(x + 0.5 - 16) <= r:
                m.add((x, y))
    cuero(cv, m)
    for (x, y) in [(13, 4), (14, 5), (15, 5), (16, 5), (17, 5), (18, 4), (12, 6), (19, 6), (13, 7), (14, 7), (17, 7),
                   (18, 7), (14, 8), (15, 8), (16, 8), (17, 8)]:   # la boca fruncida
        cv.pon(x, y, C_L if x < 16 else C)
    for x in range(12, 21):                                        # el cordon
        cv.pon(x, 9, ACE if x % 2 else OSC)
    cv.pon(21, 10, ACE)
    cv.pon(22, 11, ACE)
    cv.pon(21, 12, OSC)
    for y in range(12, 27, 3):                                     # los pliegues
        cv.pon(12 + (y % 2), y, C_S)
        cv.pon(19, y + 1, C_S)
    for (x, y) in [(22, 12), (23, 12), (24, 11), (25, 10), (25, 9), (24, 8), (23, 7)]:   # el cabo suelto del cordon
        cv.pon(x, y, ACE if (x + y) % 2 else OSC)


MOCHILAS = [("A cartera", mochila_a), ("B aventurero", mochila_b), ("C hatillo", mochila_c)]


# (06/11) LO ELEGIDO ("todas me gustan, elige tu"): T1 A cuadrado, T2 B quinque, T3 A labrado y la mochila A cartera.
ELEGIDOS_FAROL = [farol1_a, farol2_b, farol3_a]
ELEGIDA_MOCHILA = mochila_a
RAMPA_TONOS = 16


def hornear(carpeta):
    # El farol YA EN COLOR (sus colores son fijos por tier): farol_1..3.png. La mochila en GRISES DE INDICE (tono t ->
    # gris t/15), que el juego tiñe con el cuero de su tier y su +N: mochila.png.
    os.makedirs(carpeta, exist_ok=True)
    for t, fn in enumerate(ELEGIDOS_FAROL):
        cv = EP.dibujar(fn, N)
        chispas(cv, t + 1)
        EP.teñir(cv, PAL_FAROL[t]).save(os.path.join(carpeta, "farol_%d.png" % (t + 1)))
    cv = EP.dibujar(ELEGIDA_MOCHILA, N)
    im = Image.new("RGBA", (N, N), (0, 0, 0, 0))
    for y in range(N):
        for x in range(N):
            t = cv.p[y][x]
            if t:
                g = int(round(t / (RAMPA_TONOS - 1) * 255))
                im.putpixel((x, y), (g, g, g, 255))
    im.save(os.path.join(carpeta, "mochila.png"))
    print("3 faroles y la mochila en %s" % carpeta)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--hornear":
        hornear(sys.argv[2] if len(sys.argv) > 2 else "assets/sprites/equipo/herramienta")
        return
    salida = sys.argv[1] if len(sys.argv) > 1 else "faroles_lamina.png"
    with open(os.path.join(EP.AQUI, "paletas_equipo.json"), encoding="utf-8") as f:
        PAL = json.load(f)
    try:
        f1 = ImageFont.truetype("arial.ttf", 20)
        f2 = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        f1 = f2 = None
    ESC = 4
    cw = N * ESC + 14
    x0 = 190
    fila = N * ESC + 22
    w = x0 + cw * 4 + N + 40
    h = 80 + fila * (len(FAROLES) + len(MOCHILAS)) + 40
    lam = Image.new("RGBA", (w, h), (16, 16, 20, 255))
    d = ImageDraw.Draw(lam)
    d.text((16, 12), "FAROLILLO (un dibujo por tier, dos versiones) y MOCHILA (tres versiones, T1-T3 y T3+12)",
           fill=(240, 190, 100), font=f1)
    y = 50
    d.text((x0, y), "version A", fill=(200, 200, 210), font=f2)
    d.text((x0 + cw, y), "version B", fill=(200, 200, 210), font=f2)
    y += 20
    for t, (nombre, versiones) in enumerate(FAROLES):
        d.text((16, y + 56), nombre, fill=(220, 220, 228), font=f2)
        for k, (vn, fn) in enumerate(versiones):
            cv = EP.dibujar(fn, N)
            chispas(cv, t + 1)
            im = EP.teñir(cv, PAL_FAROL[t])
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            lam.paste(g, (x0 + k * cw, y), g)
            lam.paste(im, (x0 + 2 * cw + 10 + k * (N + 10), y + N * ESC - N), im)
        y += fila
    y += 10
    for i, (_t, _m, nom) in enumerate(EP.COLUMNAS):
        d.text((x0 + i * cw, y), nom, fill=(200, 200, 210), font=f2)
    y += 20
    for nombre, fn in MOCHILAS:
        d.text((16, y + 56), nombre, fill=(220, 220, 228), font=f2)
        cv = EP.dibujar(fn, N)
        for k, (t, m, _n) in enumerate(EP.COLUMNAS):
            pal = PAL["armadura|cuero|%d|%d" % (t, m)] + [None] * 8
            im = EP.teñir(cv, pal)
            g = im.resize((N * ESC, N * ESC), Image.NEAREST)
            lam.paste(g, (x0 + k * cw, y), g)
            if t == 2:
                lam.paste(im, (x0 + 4 * cw + 6, y + N * ESC - N), im)
        y += fila
    lam.save(salida)
    print(salida)


if __name__ == "__main__":
    main()
