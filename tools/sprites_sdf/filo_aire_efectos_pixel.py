# ============================================================
#  filo_aire_efectos_pixel.py -- COMO SE VE EL SET FILO DE AIRE EN CADA FORMA (05/11/2026, el jefe: "no me has puesto
#  lamina mostrando los efectos del corte de viento de la runa"). El corte es el mismo de la Segadora (la media luna
#  verde palido que se deshace en trama detras, segadora_efectos_pixel.corte_viento) y nace en el BORDE de la forma
#  normal (el contorno tenue) para seguir hasta el borde de la alargada; al que esta en esa franja le revienta encima.
#    CONO           radio +30 %: tres cortes salen del arco del cono hacia fuera
#    CIRCULO EN TI  radio +30 %: un anillo de cortes que se abre desde el borde
#    CIRCULO LEJOS  radio +30 %: el mismo anillo, con un instante de retraso (sale tras el golpe)
#    LINEA          40 % mas larga: el corte sigue desde la punta
#    A UNO          50 px por detras de a quien le pegas
#    ARCO/BALLESTA  un corte corto tras el impacto de la flecha
#  Solo la lamina y el gif, para que la mire.
#    python tools/sprites_sdf/filo_aire_efectos_pixel.py
# ============================================================
import math
import os

import segadora_efectos_pixel as sg  # (deja W, H y la trama puestos para todos)
import escarabajo_efectos_pixel as ep
import ciempies_efectos_pixel as ce
from segadora_efectos_pixel import VIENTO, METAL, corte_viento, nuevo, estrella, escena, elegir, SALIDA, W, H

HUELLA = (90, 150, 210)        # el contorno de la forma normal (lo que ya pegaba)
HUELLA_EXT = (120, 200, 170)   # el de la alargada
FPS = 14


def enemigo(a, x, y):
    """Un bicho de muestra: una bola roja con su borde oscuro."""
    for yy in range(-7, 1):
        for xx in range(-6, 7):
            d = math.hypot(xx / 6.5, (yy + 3.5) / 4.2)
            if d <= 1.0:
                col = (60, 14, 18) if d > 0.82 else ((214, 70, 60) if yy < -4 else (170, 40, 40))
                ep.punto(a, x + xx, y + yy, col, 1)


def contorno(s, pts, col):
    for i, (x, y) in enumerate(pts):
        if i % 2 == 0:
            ep.punto(s, x, y, col, 1)


def arco_pts(cx, cy, r, a0, a1, n=48):
    return [(cx + math.cos(a0 + (a1 - a0) * i / n) * r, cy + math.sin(a0 + (a1 - a0) * i / n) * r) for i in range(n + 1)]


def cono_pts(cx, cy, r, ap):
    a0, a1 = -math.radians(ap / 2), math.radians(ap / 2)
    pts = arco_pts(cx, cy, r, a0, a1)
    for k in range(0, int(r), 3):
        pts.append((cx + math.cos(a0) * k, cy + math.sin(a0) * k))
        pts.append((cx + math.cos(a1) * k, cy + math.sin(a1) * k))
    return pts


def linea_pts(x0, y0, largo, ancho):
    pts = []
    for k in range(0, int(largo), 3):
        pts += [(x0 + k, y0 - ancho / 2), (x0 + k, y0 + ancho / 2)]
    for j in range(int(-ancho / 2), int(ancho / 2) + 1, 3):
        pts.append((x0 + largo, y0 + j))
    return pts


def _cuadro(suelo, cuerpos, aire, m, t):
    m.append(escena(suelo, cuerpos, aire))
    t.append(1000 // FPS)


def _base(huellas, quien, bichos):
    s = nuevo()
    for pts, col in huellas:
        contorno(s, pts, col)
    ep.victima(s, *quien)
    for b in bichos:
        enemigo(s, *b)
    return s


def _revienta(a, x, y, f, f_llega):
    if f_llega <= f < f_llega + 3:
        estrella(a, x, y - 4, 9 - 2 * (f - f_llega), VIENTO)


def _golpe_normal(a, x, y, f):
    if 1 <= f < 4:
        estrella(a, x, y - 4, 10 - 2 * (f - 1), METAL)


def cono():
    A = (W * 0.32, H * 0.55)
    r, ap = 50.0, 90.0
    r2 = r * 1.3
    E1, E2 = (A[0] + 34, A[1] + 2), (A[0] + r + 9, A[1] - 16)
    h = [(cono_pts(A[0], A[1], r, ap), HUELLA), (cono_pts(A[0], A[1], r2, ap), HUELLA_EXT)]
    m, t = [], []
    for f in range(12):
        a = nuevo()
        _golpe_normal(a, *E1, f)
        g = f - 2
        if 0 <= g < 7:
            for ang in (-32, -16, 0, 16, 32):
                rad = math.radians(ang)
                rr = r + g * (r2 - r) / 5.0
                if rr <= r2 + 2:
                    corte_viento(a, A[0] + math.cos(rad) * rr, A[1] + math.sin(rad) * rr, math.cos(rad), math.sin(rad),
                                 6.0, g / 7.0)
        _revienta(a, *E2, f, 5)
        _cuadro([_base(h, A, [E1, E2])], [], [a], m, t)
    return m, t


def anillo(lejos):
    A = (W * 0.3, H * 0.55)
    C = (A[0] + 80, A[1]) if lejos else A
    r = 30.0 if lejos else 36.0
    r2 = r * 1.3
    E1 = (C[0] + r * 0.5, C[1] + 4) if lejos else (C[0] + 26, C[1] + 2)
    E2 = (C[0] - r - 5, C[1] - 6)
    h = [(arco_pts(C[0], C[1], r, 0, math.tau, 64), HUELLA), (arco_pts(C[0], C[1], r2, 0, math.tau, 80), HUELLA_EXT)]
    retraso = 3 if lejos else 2
    m, t = [], []
    for f in range(13):
        a = nuevo()
        _golpe_normal(a, *E1, f)
        g = f - retraso
        if 0 <= g < 7:
            for k in range(10):
                rad = math.tau * k / 10.0 + 0.2
                rr = r + g * (r2 - r) / 5.0
                if rr <= r2 + 2:
                    corte_viento(a, C[0] + math.cos(rad) * rr, C[1] + math.sin(rad) * rr * 0.9, math.cos(rad),
                                 math.sin(rad), 5.0, g / 7.0)
        _revienta(a, *E2, f, retraso + 4)
        _cuadro([_base(h, A, [E1, E2])], [], [a], m, t)
    return m, t


def linea():
    A = (W * 0.22, H * 0.55)
    largo, ancho = 80.0, 14.0
    E1, E2 = (A[0] + 50, A[1] + 3), (A[0] + largo + 20, A[1] + 3)
    h = [(linea_pts(A[0], A[1], largo, ancho), HUELLA), (linea_pts(A[0], A[1], largo * 1.4, ancho), HUELLA_EXT)]
    m, t = [], []
    for f in range(12):
        a = nuevo()
        _golpe_normal(a, *E1, f)
        g = f - 2
        if 0 <= g < 7:
            x = A[0] + largo + g * (largo * 0.4) / 5.0
            if x <= A[0] + largo * 1.4 + 2:
                corte_viento(a, x, A[1] - 3, 1.0, 0.0, 7.0, g / 7.0)
        _revienta(a, *E2, f, 4)
        _cuadro([_base(h, A, [E1, E2])], [], [a], m, t)
    return m, t


def a_uno(arco=False):
    A = (W * 0.2, H * 0.55)
    dist = 92.0 if arco else 26.0
    E1 = (A[0] + dist, A[1] + 2)
    detras = 24.0 if arco else 50.0
    E2 = (E1[0] + detras - 6, E1[1])
    h = [(linea_pts(E1[0] + 8, E1[1] - 3, detras, 14.0), HUELLA_EXT)]
    m, t = [], []
    llega = 2
    for f in range(12):
        a = nuevo()
        if arco and f < llega:
            # la flecha de muestra volando hasta el primero
            x = A[0] + (E1[0] - A[0]) * (f + 1) / (llega + 1)
            for k in range(6):
                ep.punto(a, x - k, A[1] - 7, (150, 110, 70) if k else (220, 224, 232), 1)
        _golpe_normal(a, *E1, f)
        g = f - llega
        if 0 <= g < 6:
            x = E1[0] + 8 + g * detras / 4.0
            if x <= E1[0] + 8 + detras + 2:
                corte_viento(a, x, E1[1] - 6, 1.0, 0.0, 6.0 if arco else 7.0, g / 6.0)
        _revienta(a, *E2, f, llega + 3)
        _cuadro([_base(h, A, [E1, E2])], [], [a], m, t)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    filas, gifs = [], []

    def fila(nombre, mt, idx):
        filas.append((nombre, elegir(mt[0], idx)))
        gifs.append(mt)

    fila('FILO DE AIRE · CONO\nradio +30 %', cono(), (1, 2, 3, 4, 5, 6, 8))
    fila('FILO DE AIRE · CIRCULO\nalrededor tuyo +30 %', anillo(False), (1, 2, 3, 4, 5, 6, 8))
    fila('FILO DE AIRE · CIRCULO\nelegido +30 % (con retraso)', anillo(True), (1, 3, 4, 5, 6, 7, 9))
    fila('FILO DE AIRE · LINEA\n40 % mas larga', linea(), (1, 2, 3, 4, 5, 6, 8))
    fila('FILO DE AIRE · A UNO\n50 px por detras', a_uno(), (1, 2, 3, 4, 5, 6, 8))
    fila('FILO DE AIRE · ARCO\ncorte corto tras el impacto', a_uno(True), (0, 1, 2, 3, 4, 5, 7))
    ruta = os.path.join(SALIDA, 'filo_aire.png')
    ce.lamina(filas, ruta)
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'filo_aire.gif'), 2)
    print(ruta)


if __name__ == '__main__':
    principal()
