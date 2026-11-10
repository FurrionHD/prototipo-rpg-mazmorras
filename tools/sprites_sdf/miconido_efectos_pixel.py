#!/usr/bin/env python3
# ============================================================
#  miconido_efectos_pixel.py -- LOS EFECTOS DEL MICONIDO Y SUS MUTANTES EN PIXEL ART (10/11/2026, memorias
#  efectos-a-pixel-art y miconido-mutante; el jefe: "si en pixel tanto el normal como los mutantes").
#  Los del NORMAL, los de SimaAire aprobados el 30/09, pasados a pixel (mismo dibujo, otra rejilla):
#    PORRAZO     el basico: el sombrero le cae encima; un aplaston blando sobre la cabeza y esporas pardas a los lados
#    BOCANADA    la nube parda que sale del sombrero; a cada uno que pilla, tos en la cara y motas que suben; y la nube
#                que SE QUEDA a la altura de la cara, cada vez mas rala
#    MICELIO     el latigo: una cadena de cuentas de SU carne que sale de SU MANO (medida en el modelo), ondea, se
#                enrosca en la pierna y se recoge; y el ATADO (cordones en las piernas mientras dure el Enraizado)
#  Los de la CAMPANA PALIDA (luz cian de medusa):
#    FILAMENTOS  el basico: tres hebras de luz que salen de las puntas de SUS filamentos (medidas) y azotan; a veces
#                Ciego: un velo blanco sobre los ojos
#    ESPORAS     las luminosas: la nube cian con motas que BRILLAN
#    DESTELLO    la carga (motas de luz que se juntan en el nucleo: el brillo ya lo pone su sprite) y el cono de luz
#    LUZ QUE ATRAE  al empezar su turno: los de cerca se deslizan hacia ella, con motas de luz tirando
#  Los del AVENTURERO FLORECIDO:
#    TAJO        la estela de la PUNTA de su espada oxidada (medida), escamas de oxido y sangre (Sangrado)
#    ESTOCADA    la estocada recta que ATRAVIESA: estela, y en cada uno su golpe y esquirlas por detras
#    INFECCION   la nube naranja de seta, con motas naranjas de punta cian
#  Las puntas: python tools/sprites_sdf/miconido_puntas.py (tools/salida/sdf/puntas_miconido_<var>.json).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/miconido_efectos_pixel.py
# ============================================================
import json
import math
import os
import random

import numpy as np

import ciempies_efectos_pixel as ce
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt

W, H = 330, 280
YY, XX = np.mgrid[0:H, 0:W]
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
for _m in (ce, ep, sl, rt):
    _m.W, _m.H, _m.YY, _m.XX, _m.TRAMA = W, H, YY, XX, TRAMA

from slime_efectos_pixel import UNIDAD, SALIDA, nuevo, estrella, gota, elegir, DIRS, NOM_DIR  # noqa: E402
from rata_efectos_pixel import marco, escena, SANGRE  # noqa: E402

poner, punto, bolita = ep.poner, ep.punto, ep.bolita
NORMAL, CAMPANA, FLORECIDO = 'miconido_sdf', 'miconido_sdf_campana', 'miconido_sdf_florecido'

ESPORA = [(70, 54, 36), (122, 96, 62), (176, 148, 104), (226, 206, 160)]
CARNE = [(96, 84, 66), (160, 146, 120), (212, 202, 178), (244, 238, 222)]
CARNE_BORDE = (40, 32, 26)
LUZ = [(16, 74, 82), (40, 160, 162), (120, 232, 214), (232, 255, 250)]
OXIDO = [(64, 30, 16), (132, 64, 28), (192, 106, 48), (238, 172, 112)]
SETA = [(110, 44, 12), (196, 98, 26), (236, 150, 60), (255, 226, 180)]
VELO = [(150, 170, 176), (210, 228, 230), (244, 252, 252), (255, 255, 255)]
OSCURO = (24, 10, 8)


# ------------------------------------------------------------
#  DONDE ESTAN LAS COSAS
# ------------------------------------------------------------
_PUNTAS = {}
_LIENZO = {}


def _lienzo(var):
    if var not in _LIENZO:
        _LIENZO[var] = tuple(json.load(open(os.path.join(rt.RAIZ, 'assets/sprites/enemigos/%s/hojas.json' % var)))['lienzo'])
    return _LIENZO[var]


def punta(var, anim, d, fr, nombre, pos):
    """La punta medida en el modelo (miconido_puntas.py) en el fotograma 'fr' (en cuartos), con el sprite puesto en 'pos'."""
    clave = {NORMAL: 'normal', CAMPANA: 'campana', FLORECIDO: 'florecido'}[var]
    if clave not in _PUNTAS:
        _PUNTAS[clave] = json.load(open(os.path.join(rt.RAIZ, 'tools/salida/sdf/puntas_miconido_%s.json' % clave)))
    fr = round(fr * 4) / 4.0
    q = _PUNTAS[clave].get('%s|%d|%.2f|%s' % (anim, d, fr, nombre))
    if q is None:
        return None
    w, h = _lienzo(var)
    return (int(round(pos[0])) - w // 2 + q[0], int(round(pos[1])) - h // 2 + q[1])


def caja_dibujo(spr, pos):
    """La caja de su dibujo (sin la sombra) en el lienzo de la lamina."""
    a = np.asarray(spr).astype(int)
    m = (a[:, :, 3] > 128) & (a[:, :, :3].sum(axis=2) > 90)
    ys, xs = np.nonzero(m)
    w, h = spr.size
    ox, oy = int(round(pos[0])) - w // 2, int(round(pos[1])) - h // 2
    return ox + xs.min(), oy + ys.min(), ox + xs.max(), oy + ys.max()


def pies(var, pos, fila=1):
    x0, y0, x1, y1 = caja_dibujo(marco(var, 'idle', 0, fila), pos)
    return (x0 + x1) / 2, y1


def campana_de(spr, pos, var):
    """Donde esta la campana (su nucleo y su borde de abajo): la parte de arriba de su dibujo."""
    x0, y0, x1, y1 = caja_dibujo(spr, pos)
    alto = y1 - y0
    k = 0.42 if var == CAMPANA else 0.30
    return ((x0 + x1) / 2, y0 + alto * k * 0.45), ((x0 + x1) / 2, y0 + alto * k)


def sombrero_de(spr, pos):
    x0, y0, x1, y1 = caja_dibujo(spr, pos)
    return (x0 + x1) / 2, y0 + (y1 - y0) * 0.22, (x1 - x0) / 2


def _dir(fila):
    dx, dy = DIRS[fila]
    return dx, dy * 0.9


def cabeza(v):
    return v[0], v[1] - 16


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
def nube(a, x, y, r, fuerza=1.0, pal=ESPORA):
    """El gas se lee a TRAMA: nunca una bola maciza; claro por arriba y mas ralo hacia el borde (la del venenoso)."""
    if r < 1.0 or fuerza <= 0.0:
        return
    d = np.hypot(XX - x, (YY - y) * 1.15)
    d2 = np.hypot(XX - (x - r * 0.2), YY - (y - r * 0.3))
    poner(a, (d < r) & (d >= r * 0.65) & (TRAMA < 0.3 * fuerza), pal[0])
    poner(a, (d < r * 0.65) & (TRAMA < 0.55 * fuerza), pal[1])
    poner(a, (d2 < r * 0.4) & (TRAMA < 0.5 * fuerza), pal[2])
    poner(a, (d2 < r * 0.18) & (TRAMA < 0.35 * fuerza) & (fuerza > 0.5), pal[3])


def motas(a, x, y, e, sem, pal, n=5, sube=1.6, abre=9.0, brillan=False):
    rnd = random.Random(sem)
    for _i in range(n):
        ox = rnd.uniform(-abre, abre)
        vy = rnd.uniform(0.6, 1.0) * sube
        t0 = rnd.uniform(0, 2)
        k = e - t0
        if k < 0 or k > 7:
            continue
        px, py = x + ox + math.sin(k * 0.9 + ox) * 1.5, y - k * vy * 2.0
        if brillan and (int(k * 2) + _i) % 3 == 0:
            estrella(a, px, py, 3, pal)
        else:
            punto(a, px, py, pal[2] if k < 4 else pal[1], 2)


def tos(a, v, e, sem, pal=ESPORA, brillan=False):
    """A cada uno que pilla: una nubecilla en la cara que se abre y motas que suben."""
    if e < 0 or e > 9:
        return
    cx, cy = cabeza(v)
    nube(a, cx, cy, 4 + min(e, 4) * 2.0, max(0.0, 1.0 - e / 9.0), pal)
    motas(a, cx, cy - 2, e, sem, pal, 4, 1.2, 6, brillan)


def velo(a, v, e, pal=VELO):
    """CIEGO: un velo palido sobre los ojos un momento."""
    if e < 0 or e > 8:
        return
    x, y = cabeza(v)
    y -= 1
    f = 1.0 - e / 9.0
    m = (np.abs(XX - x) <= 5) & (np.abs(YY - y) <= 1)
    poner(a, m & (TRAMA < f * 1.1), pal[1])
    poner(a, (np.abs(XX - x) <= 4) & (YY == y) & (TRAMA < f * 0.9), pal[3])


def cuentas(a, pts, grueso, pal, borde):
    """Un cordon de cuentas (el latigo, los filamentos): borde oscuro, relleno y un brillo, afilandose al final."""
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        u = i / max(1, n - 1)
        r = grueso * (1.0 - 0.55 * u)
        if borde is not None:
            ep.disco(a, x, y, r + 0.9, borde)
    for i, (x, y) in enumerate(pts):
        u = i / max(1, n - 1)
        r = grueso * (1.0 - 0.55 * u)
        bolita(a, x, y, r, pal)


def _curva(p0, p1, onda, n=14, fase=0.0, combo=1.0):
    """De p0 a p1, ondeando de lado como un latigo."""
    dx, dy = p1[0] - p0[0], p1[1] - p0[1]
    L = math.hypot(dx, dy) or 1.0
    nx, ny = -dy / L, dx / L
    out = []
    for i in range(n + 1):
        u = i / n
        o = math.sin(u * math.pi * combo + fase) * onda * math.sin(u * math.pi)
        out.append((p0[0] + dx * u + nx * o, p0[1] + dy * u + ny * o))
    return out


def enrosque(a, v, vueltas, pal, borde, grueso=1.6, alto=8):
    """Los cordones enroscados en las piernas (el ATADO)."""
    x, y = v
    for k in range(vueltas):
        yy = y - 2 - k * (alto / max(1, vueltas))
        pts = [(x + math.cos(t) * 5.5, yy + math.sin(t) * 1.6) for t in np.linspace(0, math.pi, 7)]
        cuentas(a, pts, grueso, pal, borde)


def abanico(a, cx, cy, eje, R, apertura, e, pal):
    """El cono de luz (el destello de la rata, con su paleta)."""
    d = np.hypot(XX - cx, YY - cy)
    ang = np.arctan2(YY - cy, XX - cx)
    rel = np.abs((ang - eje + np.pi) % (2 * np.pi) - np.pi)
    mitad = math.radians(apertura) * 0.5
    llega = R * min(1.0, (e + 1) / 3.0)
    dentro = (rel < mitad) & (d < llega)
    u = d / max(R, 1.0)
    rayo = np.sin(ang * 23.0 + e * 0.7) > 0.25
    fuerza = max(0.0, 1.0 - e / 9.0)
    poner(a, dentro & (TRAMA < (1.0 - u) * fuerza * 1.2) & (u > 0.55), pal[0])
    poner(a, dentro & (TRAMA < (1.0 - u) * fuerza * 1.6) & (u > 0.3) & (u <= 0.55), pal[1])
    poner(a, dentro & (u <= 0.3) & (TRAMA < fuerza * 1.4), pal[2])
    poner(a, dentro & rayo & (u < 0.75) & (TRAMA < fuerza * 1.2), pal[2])
    poner(a, dentro & (u < 0.14) & (fuerza > 0.5), pal[3])


def estela(a, var, anim, d, nombre, pos_de, fr, pal, grueso=6.0, largo=1.5):
    """EL CORTE: por donde ha pasado la punta en el ultimo 'largo' de fotograma (la de la segadora). 'pos_de(fr)' = donde
    esta el sprite en ese fotograma (la estocada avanza)."""
    pts = []
    k = fr - largo
    while k <= fr + 1e-6:
        if k >= 0:
            q = punta(var, anim, d, k, nombre, pos_de(k))
            if q is not None:
                pts.append(q)
        k += 0.25
    if len(pts) < 2 or sum(math.hypot(b[0] - c[0], b[1] - c[1]) for c, b in zip(pts, pts[1:])) < 6:
        return
    total = len(pts) - 1
    for idx in range(total):
        (x0, y0), (x1, y1) = pts[idx], pts[idx + 1]
        pasos = max(2, int(math.hypot(x1 - x0, y1 - y0)))
        for s_ in range(pasos):
            w = s_ / pasos
            x, y = x0 + (x1 - x0) * w, y0 + (y1 - y0) * w
            u = 1.0 - (idx + w) / total
            if u > 0.6 and TRAMA[int(y) % H, int(x) % W] > (1.0 - u) * 2.2:
                continue
            r = grueso * 0.5 * (0.35 + 0.65 * (1.0 - u))
            col = pal[3] if u < 0.12 else pal[2] if u < 0.4 else pal[1] if u < 0.72 else pal[0]
            bolita(a, x, y, r, [col, col, col, col])


def sangre(a, x, y, f, sem, n=3):
    rnd = random.Random(sem)
    for _i in range(n):
        ox, vy = rnd.uniform(-5, 5), rnd.uniform(1.0, 1.9)
        gota(a, x + ox, y + rnd.uniform(-3, 2) + f * vy * 2.0, 1.6, SANGRE, rt.SANGRE_BORDE)


def escamas(a, x, y, e, sem, n=6):
    """Escamas de oxido que saltan del golpe y caen."""
    rnd = random.Random(sem)
    for _i in range(n):
        vx, vy = rnd.uniform(-1.6, 1.6), rnd.uniform(-2.2, -0.8)
        k = e
        px, py = x + vx * k * 2.2, y + vy * k * 2.0 + 0.5 * k * k
        if k > 6:
            continue
        punto(a, px, py, OXIDO[2] if (_i + e) % 2 else OXIDO[1], 2)


# ------------------------------------------------------------
#  EL NORMAL
# ------------------------------------------------------------
def _yo_y_victima(var, fila, dist):
    dx, dy = _dir(fila)
    A = (W * 0.42 - dx * dist * 0.5, H * 0.52 - dy * dist * 0.4)
    px, py = pies(var, A, fila)
    V = (px + dx * dist, py + dy * dist + 2)
    return A, V, dx, dy


def porrazo(fila):
    A, V, dx, dy = _yo_y_victima(NORMAL, fila, 30)
    n = 8
    toca = 4
    m, t = [], []
    for f in range(n + 6):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        e = f - toca
        ep.victima(s, *V)
        hx, hy = cabeza(V)
        if 0 <= e < 3:
            # el aplaston: un disco blando y chato sobre la cabeza
            r = (9, 11, 8)[e]
            m_ = np.hypot((XX - hx) / r, (YY - hy + 2) / (r * 0.45)) < 1.0
            poner(a, m_ & (TRAMA < (0.9, 0.6, 0.35)[e]), ESPORA[1])
            poner(a, m_ & (np.hypot((XX - hx) / (r * 0.6), (YY - hy + 3) / (r * 0.25)) < 1.0) & (TRAMA < 0.6), ESPORA[3])
        if e >= 0:
            for lado in (-1, 1):
                nube(a, hx + lado * (5 + e * 2.2), hy + 1 + e * 0.4, 3 + min(e, 4) * 1.1, max(0.0, 1.0 - e / 8.0))
            motas(a, hx, hy - 2, e, fila + 11, ESPORA, 5, 1.0, 10)
        m.append(escena([s], [(marco(NORMAL, 'embestida', fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def bocanada(fila, var=NORMAL, pal=ESPORA, brillan=False, anim='esporas'):
    dx, dy = _dir(fila)
    R = 40.0 / UNIDAD
    A = (W * 0.42 - dx * R * 0.6, H * 0.5 - dy * R * 0.5)
    px, py = pies(var, A, fila)
    C = (px + dx * R * 1.15, py + dy * R * 1.0)
    vict = [(C[0] - R * 0.45, C[1] + 2), (C[0] + R * 0.4, C[1] - R * 0.25)]
    n = 8
    sale = 3
    m, t = [], []
    for f in range(n + 16):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        spr = marco(var, anim, fr, fila)
        for v in vict:
            ep.victima(s, *v)
        e = f - sale
        if e >= 0:
            if var == NORMAL:
                ox, oy, _r = sombrero_de(marco(var, anim, min(sale, n - 1), fila), A)
            else:
                _n, (ox, oy) = campana_de(marco(var, anim, min(sale, n - 1), fila), A, var)
            # lo que sale: bolitas de nube que vuelan de la boca al centro y alli se abren
            k = min(1.0, e / 4.0)
            cx, cy = ox + (C[0] - ox) * k, oy + (C[1] - 14 - oy) * k
            rr = 5 + R * 0.75 * min(1.0, e / 5.0)
            fuerza = 1.0 if e < 8 else max(0.25, 1.0 - (e - 8) / 12.0)
            nube(a, cx, cy, rr, fuerza, pal)
            if e < 5:
                for j in range(3):
                    kk = max(0.0, k - 0.18 * (j + 1))
                    nube(a, ox + (C[0] - ox) * kk, oy + (C[1] - 14 - oy) * kk, 4 - j, 0.8, pal)
            motas(a, cx, cy, e, fila + 5, pal, 7, 0.8, rr * 0.8, brillan)
            for j, v in enumerate(vict):
                tos(a, v, e - 4, j + fila * 3, pal, brillan)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def micelio(fila):
    A, V, dx, dy = _yo_y_victima(NORMAL, fila, 46)
    n = 8
    lanza = 2.0
    m, t = [], []
    for f in range(n + 12):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        ep.victima(s, *V)
        mano = punta(NORMAL, 'micelio', fila, min(f, n - 1), 'mano', A)
        e = f - lanza
        if mano is not None and e >= 0:
            pierna = (V[0], V[1] - 4)
            if e < 2:
                k = (e + 1) / 2.0
                fin = (mano[0] + (pierna[0] - mano[0]) * k, mano[1] + (pierna[1] - mano[1]) * k)
                cuentas(a, _curva(mano, fin, 6, 12, e * 1.5), 2.0, CARNE, CARNE_BORDE)
            elif e < 7:
                cuentas(a, _curva(mano, pierna, 3.5 - e * 0.4, 14, e), 2.0, CARNE, CARNE_BORDE)
                enrosque(a, V, min(3, int(e - 1)), CARNE, CARNE_BORDE)
            elif e < 10:
                k = 1.0 - (e - 7) / 3.0
                fin = (mano[0] + (pierna[0] - mano[0]) * k, mano[1] + (pierna[1] - mano[1]) * k)
                cuentas(a, _curva(mano, fin, 4, 10, e), 1.8, CARNE, CARNE_BORDE)
        m.append(escena([s], [(marco(NORMAL, 'micelio' if f < n else 'idle', fr if f < n else f - n, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def atado():
    V = (W * 0.5, H * 0.6)
    m, t = [], []
    for f in range(8):
        s, a = nuevo(), nuevo()
        ep.victima(s, *V)
        enrosque(a, V, 3, CARNE, CARNE_BORDE)
        if f % 4 < 2:
            punto(a, V[0] + 6, V[1] - 6 - (f % 4), CARNE[3], 1)
        m.append(escena([s], [], [a]))
        t.append(1000 // 6)
    return m, t


# ------------------------------------------------------------
#  LA CAMPANA PALIDA
# ------------------------------------------------------------
def filamentos(fila):
    A, V, dx, dy = _yo_y_victima(CAMPANA, fila, 40)
    n = 8
    toca = 4
    m, t = [], []
    for f in range(n + 8):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        ep.victima(s, *V)
        hx, hy = cabeza(V)
        e = f - toca
        if f < n:
            for j, k in enumerate((2, 3, 4)):
                q = punta(CAMPANA, 'embestida', fila, fr, 'fil%d' % k, A)
                if q is None:
                    continue
                if f >= 2 and e < 2:
                    # se lanzan hasta la cara: hebras de luz en cuentas finas
                    u = min(1.0, (f - 1) / 3.0)
                    fin = (q[0] + (hx - 4 + j * 4 - q[0]) * u, q[1] + (hy - q[1]) * u)
                    cuentas(a, _curva(q, fin, 3, 10, f + j), 1.1, LUZ, LUZ[0])
        if 0 <= e < 2:
            estrella(a, hx, hy, (10, 6)[e], LUZ)
        if e >= 0:
            motas(a, hx, hy, e, fila + 2, LUZ, 4, 0.8, 7, True)
        velo(a, V, e - 1)
        m.append(escena([s], [(marco(CAMPANA, 'embestida', fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def destello(fila, var=CAMPANA):
    dx, dy = _dir(fila)
    R = 60.0 / UNIDAD
    A = (W * 0.42 - dx * R * 0.55, H * 0.55 - dy * R * 0.45)
    eje = math.atan2(dy, dx)
    _n0, _b = campana_de(marco(var, 'destello', 0, fila), A, var)
    vict = [(A[0] + math.cos(eje - 0.3) * R * 0.75, A[1] + math.sin(eje - 0.3) * R * 0.75 + 24),
            (A[0] + math.cos(eje + 0.35) * R * 0.55, A[1] + math.sin(eje + 0.35) * R * 0.55 + 24)]
    rnd = random.Random(fila)
    llegan = [(rnd.uniform(0, math.tau), rnd.uniform(14, 26)) for _ in range(8)]
    m, t = [], []
    carga = 8
    for f in range(carga + 12):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        if f < carga:
            spr = marco(var, 'destello_carga', f, fila)
            nuc, _b2 = campana_de(spr, A, var)
            for j, (ang, d0) in enumerate(llegan):
                k = ((f + j * 0.6) % 4) / 4.0
                d = d0 * (1.0 - k)
                punto(a, nuc[0] + math.cos(ang) * d, nuc[1] + math.sin(ang) * d * 0.7, LUZ[2] if k > 0.5 else LUZ[1], 2)
        else:
            e = f - carga
            spr = marco(var, 'destello', min(e, 7), fila)
            nuc, _b2 = campana_de(spr, A, var)
            capa = a if dy > -0.2 else s
            abanico(capa, nuc[0], nuc[1] + 6, eje, R, 90.0, e, LUZ)
            if e < 2:
                estrella(a, nuc[0], nuc[1], (16, 10)[e], LUZ)
            for v in vict:
                velo(a, v, e - 1)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def atrae():
    A = (W * 0.45, H * 0.48)
    px, py = pies(CAMPANA, A, 1)
    vict0 = [(px - 46, py + 10), (px + 44, py + 18), (px + 6, py + 44)]
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        spr = marco(CAMPANA, 'idle', f, 1)
        nuc, _b = campana_de(spr, A, CAMPANA)
        k = min(1.0, max(0.0, (f - 3) / 4.0))
        for j, v0 in enumerate(vict0):
            vx, vy = v0[0] - px, v0[1] - py
            d = math.hypot(vx, vy) or 1.0
            v = (v0[0] - vx / d * 15 / UNIDAD * k, v0[1] - vy / d * 15 / UNIDAD * k)
            ep.victima(s, *v)
            # motas de luz que van de cada uno a la campana
            if 1 <= f < 10:
                for i in range(3):
                    u = ((f + i * 1.3 + j) % 4) / 4.0
                    hx, hy = cabeza(v)
                    punto(a, hx + (nuc[0] - hx) * u, hy + (nuc[1] - hy) * u, LUZ[2] if u > 0.5 else LUZ[1], 2)
        if 2 <= f < 5:
            estrella(a, nuc[0], nuc[1], (6, 9, 6)[f - 2], LUZ)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


# ------------------------------------------------------------
#  EL AVENTURERO FLORECIDO
# ------------------------------------------------------------
def _impacto(var, anim, d, nombre, pos_de, hacia, n):
    mejor, fr_m = -1e9, 0.0
    for k in range((n - 1) * 4 + 1):
        q = punta(var, anim, d, k / 4.0, nombre, pos_de(k / 4.0))
        if q is not None:
            p = pos_de(k / 4.0)
            v = (q[0] - p[0]) * hacia[0] + (q[1] - p[1]) * hacia[1]
            if v > mejor:
                mejor, fr_m = v, k / 4.0
    return fr_m, punta(var, anim, d, fr_m, nombre, pos_de(fr_m))


def tajo(fila):
    dx, dy = _dir(fila)
    A = (W * 0.42, H * 0.5)
    pos_de = lambda fr: A
    n = 8
    fr_i, q = _impacto(FLORECIDO, 'embestida', fila, 'espada', pos_de, (dx, dy), n)
    V = (q[0], q[1] + 12)
    m, t = [], []
    for f in range(n + 5):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        ep.victima(s, *V)
        # solo la BAJADA: alzarla (hasta el 0,35 de la anim) no corta nada
        if f < n and n * 0.33 <= fr <= fr_i + 1.5:
            estela(a, FLORECIDO, 'embestida', fila, 'espada', pos_de, fr, OXIDO, 6.0, min(1.5, fr - n * 0.33))
        e = f - fr_i
        if 0 <= e < 2:
            estrella(a, q[0], q[1], 11 if e < 1 else 7, OXIDO)
        if e >= 0:
            escamas(a, q[0], q[1], e, fila + 4)
            sangre(a, q[0], q[1] + 2, e, fila * 3 + 1, n=3)
        m.append(escena([s], [(marco(FLORECIDO, 'embestida', fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def estocada(fila):
    dx, dy = _dir(fila)
    A = (W * 0.36 - dx * 20, H * 0.5 - dy * 18)
    pos_de = lambda fr: A
    n = 8
    fr_i, q = _impacto(FLORECIDO, 'estocada', fila, 'espada', pos_de, (dx, dy), n)
    vics = [(q[0] - dx * 4, q[1] + 12 - dy * 4), (q[0] + dx * 22, q[1] + 12 + dy * 22)]
    m, t = [], []
    for f in range(n + 6):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        for v in vics:
            ep.victima(s, *v)
        # solo el AVANCE recto: echarla atras (hasta el 0,3) no corta nada
        if f < n and n * 0.3 <= fr <= fr_i + 1.0:
            estela(a, FLORECIDO, 'estocada', fila, 'espada', pos_de, fr, OXIDO, 5.0, min(1.0, fr - n * 0.3))
        e = f - fr_i
        for k, v in enumerate(vics):
            ek = e - k * 0.5
            hit = (v[0], v[1] - 12)
            if 0 <= ek < 2:
                estrella(a, hit[0], hit[1], 10 if ek < 1 else 7, OXIDO)
                rnd = random.Random(fila + f + k)
                for _i in range(5):
                    kk = rnd.uniform(5, 14) + ek * 5
                    lado = rnd.uniform(-5, 5)
                    punto(a, hit[0] + dx * kk - dy * lado, hit[1] + dy * kk + dx * lado, OXIDO[2], 2)
            if ek >= 0:
                bolita(s, hit[0] + dx * 2, hit[1] + 2, 2.0 if ek < 4 else 1.3, [OSCURO, OSCURO, (60, 14, 12), (90, 24, 20)])
                sangre(a, hit[0], hit[1] + 2, ek, fila + 3 + k, n=2)
        m.append(escena([s], [(marco(FLORECIDO, 'estocada', fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 13)
    return m, t


# (10/11) TRANSPARENCIA DE VERDAD, sin rejilla (memoria transparencia-de-verdad): cada efecto, 4 pasadas promediadas.
def _sin_rejilla(fn):
    import sys
    import transparencia as tr

    def envuelto(*a, **k):
        return tr.con_alfa(fn, [ce, ep, sl, rt, sys.modules[__name__]], *a, **k)
    return envuelto


def principal():
    global porrazo, bocanada, micelio, atado, filamentos, destello, atrae, tajo, estocada
    if os.environ.get('CON_REJILLA') != '1':
        porrazo, bocanada, micelio, atado = map(_sin_rejilla, (porrazo, bocanada, micelio, atado))
        filamentos, destello, atrae, tajo, estocada = map(_sin_rejilla, (filamentos, destello, atrae, tajo, estocada))
    os.makedirs(SALIDA, exist_ok=True)
    filas, gifs = [], []

    def fila(nombre, mt, idx):
        filas.append((nombre, elegir(mt[0], idx)))
        gifs.append(mt)

    for d in (1, 4):
        fila('NORMAL porrazo\nhacia el ' + NOM_DIR[d], porrazo(d), (2, 4, 5, 6, 7, 8, 10))
    for d in (1, 2):
        fila('NORMAL Bocanada\nhacia el ' + NOM_DIR[d], bocanada(d), (3, 5, 7, 9, 11, 15, 21))
    for d in (1, 2):
        fila('NORMAL Latigazo de\nmicelio hacia el ' + NOM_DIR[d], micelio(d), (2, 3, 4, 6, 8, 10, 12))
    fila('NORMAL atado\n(Enraizado)', atado(), (0, 1, 2, 3))
    for d in (1, 4):
        fila('CAMPANA Latigazo de\nfilamentos hacia el ' + NOM_DIR[d], filamentos(d), (2, 3, 4, 5, 6, 8, 10))
    fila('CAMPANA Esporas\nluminosas', bocanada(1, CAMPANA, LUZ, True), (3, 5, 7, 9, 11, 15, 21))
    for d in (1, 4):
        fila('CAMPANA Destello\nhacia el ' + NOM_DIR[d], destello(d), (1, 4, 7, 8, 9, 11, 14))
    fila('CAMPANA Luz que atrae', atrae(), (0, 2, 4, 6, 8, 10, 13))
    for d in (1, 2, 4):
        fila('FLORECIDO Tajo oxidado\nhacia el ' + NOM_DIR[d], tajo(d), (1, 2, 3, 4, 5, 7, 9))
    for d in (1, 2):
        fila('FLORECIDO Estocada\ndel muerto hacia el ' + NOM_DIR[d], estocada(d), (1, 2, 3, 4, 5, 7, 9))
    fila('FLORECIDO Esporas\nde infeccion', bocanada(1, FLORECIDO, SETA, False), (3, 5, 7, 9, 11, 15, 21))
    fila('FLORECIDO Destello', destello(1, FLORECIDO), (1, 4, 7, 8, 9, 11, 14))
    ce.lamina(filas, os.path.join(SALIDA, 'miconido.png'), 3)
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'miconido.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
