#!/usr/bin/env python3
# ============================================================
#  chillon_efectos_pixel.py -- LOS EFECTOS DEL CHILLON Y SUS MUTANTES EN PIXEL ART (18/11/2026, memorias
#  efectos-a-pixel-art y chillon-mutante). La receta de las otras laminas (rey_rata_efectos_pixel.py): misma rejilla que
#  los sprites, paletas de 4 tonos, transparencia de verdad (sin rejilla), sobre sus sprites de verdad.
#  EL NORMAL (hoy a mano, SimaAire PALETOS/OIDOS), las mismas ideas en pixel: los PALETOS del basico y del Picado (dos
#    pinchazos gemelos que se clavan) y los OIDOS EN BLANCO del Chillido (onda en cono; al que le llega, fogonazo blanco
#    en la cabeza y tiembla).
#  EL CHILLIDO DE OSCURIDAD (Apagaluces y Piña, circulo de 70; la cria, de 45): TRES VERSIONES para que elija el jefe:
#    A  ANILLO DE TINTA  un anillo negro relleno que se abre hasta el borde, con la pincelada clara rota en el filo (el
#                        lenguaje de la Voragine de sombra), y se deshace en gotas de tinta
#    B  ONDAS NEGRAS     tres ondas finas y negras seguidas, cada una mas debil
#    C  SOMBRA EN EL SUELO la sombra se extiende por el suelo hasta el borde y se retira
#  A OSCURAS (elegido A): sobre el que queda a oscuras, su lucecita amarilla tiembla, se encoge y se apaga echando humo.
#  BEBE LA LUZ (elegido A): de ese mismo, motas de luz amarilla vuelan al bicho y se las traga.
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/chillon_efectos_pixel.py
# ============================================================
import math
import os
import random
import sys

import numpy as np

import slime_efectos_pixel as sl
import escarabajo_efectos_pixel as ep
import rata_efectos_pixel as rt
from slime_efectos_pixel import (W, H, XX, YY, TRAMA, UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella,
                                 victima, lamina, elegir, DIRS, NOM_DIR)
from rata_efectos_pixel import marco, escena

NORMAL, APAGA, PINA, CRIA = 'chillon_sdf', 'chillon_sdf_apagaluces', 'chillon_sdf_pina', 'chillon_sdf_cria'

# La tinta de la Voragine (slime_abisal_efectos_pixel.NEGRO) y su pincelada clara
NEGRO = [(8, 6, 14), (24, 20, 36), (62, 52, 88), (150, 136, 184)]
SONIDO = [(70, 70, 84), (130, 132, 150), (196, 198, 214), (246, 246, 255)]
LUZ_FAROL = [(120, 70, 10), (230, 160, 40), (255, 214, 110), (255, 246, 210)]
HUMO = [(40, 40, 46), (78, 78, 86), (120, 120, 130), (170, 170, 180)]
DIENTE = [(80, 60, 50), (180, 160, 140), (238, 228, 206), (255, 255, 250)]


def caja(spr, pos):
    """La caja de lo dibujado del fotograma 'spr' puesto en 'pos' (como lo pega escena: centrado)."""
    bb = spr.getbbox() or (0, 0, spr.size[0], spr.size[1])
    w, h = spr.size
    x0, y0 = pos[0] - w // 2, pos[1] - h // 2
    return x0 + bb[0], y0 + bb[1], x0 + bb[2], y0 + bb[3]


def centro(spr, pos):
    x0, y0, x1, y1 = caja(spr, pos)
    return (x0 + x1) / 2, (y0 + y1) / 2


def cabeza_v(v):
    """La cabeza del muñeco victima (ep.victima: la cara va de y-19 a y-13)."""
    return v[0], v[1] - 16


def alrededor(A, R, n=3, giro=0.5):
    return [(A[0] + math.cos(giro + k * math.tau / n) * R, A[1] + math.sin(giro + k * math.tau / n) * R * 0.8 + 6)
            for k in range(n)]


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
def paletos(a, hx, hy, ux, uy, e):
    """Dos pinchazos gemelos, juntos y paralelos, que entran por la linea del mordisco y se clavan."""
    if e < 0 or e > 5:
        return
    nx, ny = -uy, ux
    entra = min(1.0, e / 2.0)
    for lado in (-1, 1):
        bx, by = hx + nx * lado * 2.2, hy + ny * lado * 2.2
        largo = 7.0
        for i in range(int(largo)):
            k = i / largo
            x = bx - ux * (largo - i) * (1.0 - entra * 0.6)
            y = by - uy * (largo - i) * (1.0 - entra * 0.6)
            if e <= 3:
                punto(a, x, y, DIENTE[2 if k > 0.5 else 1], 2 if k > 0.6 else 1)
        if e >= 2:
            punto(a, bx + ux, by + uy, (200, 30, 30), 1)
    if e == 2:
        estrella(a, hx, hy, 4, DIENTE)


def oidos(a, hx, hy, e):
    """Le llega el pulso: fogonazo blanco en la cabeza y unas rayitas a los lados que tiemblan."""
    if e < 0 or e > 6:
        return
    tiembla = (e % 2) * 2 - 1
    if e < 2:
        disco(a, hx, hy, 4 - e, SONIDO[3])
    for lado in (-1, 1):
        for j in range(-3, 4):
            punto(a, hx + lado * (7 + abs(j) * 0.3) + tiembla, hy + j * 1.3, SONIDO[2 if abs(j) < 2 else 1],
                  2 if abs(j) < 2 else 1)


def farol(a, hx, hy, e):
    """A OSCURAS: su lucecita encima tiembla, se encoge y se apaga echando un hilo de humo."""
    if e < 0 or e > 11:
        return
    x, y = hx, hy - 9
    if e < 6:
        r = 3.0 * (1.0 - e / 6.0) + 0.6
        tiembla = ((e * 7) % 3 - 1) * 0.6
        disco(a, x + tiembla, y, r + 1.2, LUZ_FAROL[1], 0.5)
        disco(a, x + tiembla, y, r, LUZ_FAROL[2])
        disco(a, x + tiembla, y, max(0.6, r - 1.4), LUZ_FAROL[3])
    else:
        k = e - 6
        fuerza = 1.0 - k / 6.0
        for i in range(4):
            yy = y - k * 1.4 - i * 2.0
            xx = x + math.sin((k + i) * 1.1) * 1.4
            if TRAMA[int(yy) % H, int(xx) % W] < fuerza:
                punto(a, xx, yy, HUMO[2 - min(i, 2)], 1)


def motas(a, desde, hasta, e, n=6, sem=0, vuelo=4.0):
    """BEBE LA LUZ: motas de luz amarilla que salen de 'desde' (el que se apaga) y vuelan a 'hasta' (el bicho)."""
    rnd = random.Random(sem)
    for i in range(n):
        t0 = i * 0.7 + rnd.uniform(0, 0.3)
        k = (e - t0) / vuelo
        if k < 0 or k > 1:
            continue
        ox, oy = rnd.uniform(-3, 3), rnd.uniform(-3, 3)
        x = desde[0] + ox + (hasta[0] - desde[0] - ox) * k
        y = desde[1] + oy + (hasta[1] - desde[1] - oy) * k - math.sin(math.pi * k) * 10
        if k < 0.85:
            punto(a, x, y, LUZ_FAROL[3 if i % 2 else 2], 2 if k < 0.4 else 1)
        else:
            punto(a, x, y, LUZ_FAROL[1], 1)


def chillido_a(a, s, cx, cy, R, e, sem=0):
    """A: anillo de tinta relleno que se abre hasta R con la pincelada clara rota en el filo; al final, gotas."""
    if e < 0 or e > 10:
        return
    d = np.hypot(XX - cx, (YY - cy) / 0.8)
    ang = np.arctan2((YY - cy) / 0.8, XX - cx)
    if e <= 6:
        r = 6 + (R - 6) * min(1.0, e / 5.0)
        grueso = 4.5 - e * 0.35
        fuerza = 1.0 if e < 5 else 0.6
        anillo = (d > r - grueso) & (d < r)
        poner(a, anillo & (TRAMA < fuerza), NEGRO[1])
        poner(a, anillo & (d < r - grueso + 1.2) & (TRAMA < fuerza), NEGRO[0])
        # la pincelada clara, ROTA: solo a tramos del filo
        rota = (np.sin(ang * 7 + sem + e * 0.7) > 0.15)
        poner(a, (np.abs(d - r + 0.5) < 0.7) & rota & (TRAMA < fuerza), NEGRO[3])
        poner(a, (np.abs(d - r + 1.4) < 0.5) & rota & (TRAMA < fuerza * 0.6), NEGRO[2])
    if e >= 5:
        rnd = random.Random(sem)
        k = e - 5
        for i in range(14):
            g = rnd.uniform(0, math.tau)
            x = cx + math.cos(g) * (R - 1 + k * 1.2)
            y = cy + math.sin(g) * (R - 1 + k * 1.2) * 0.8 + k * k * 0.35
            if TRAMA[int(y) % H, int(x) % W] < 1.0 - k / 6.0:
                disco(a, x, y, 1.3, NEGRO[0])
                punto(a, x - 0.5, y - 0.5, NEGRO[2])


def chillido_b(a, s, cx, cy, R, e, sem=0):
    """B: tres ondas negras finas seguidas, cada una mas debil."""
    d = np.hypot(XX - cx, (YY - cy) / 0.8)
    for k in range(3):
        ek = e - k * 2.2
        if ek < 0:
            continue
        r = 6 + ek * (R - 6) / 5.0
        if r > R + 1:
            continue
        fuerza = (1.0 - k * 0.3) * (1.0 - max(0.0, r - R * 0.7) / (R * 0.4))
        borde = np.abs(d - r)
        poner(a, (borde < 1.3) & (TRAMA < fuerza), NEGRO[1])
        poner(a, (borde < 0.6) & (TRAMA < fuerza), NEGRO[2])


def chillido_c(a, s, cx, cy, R, e, sem=0):
    """C: la sombra se extiende por el SUELO hasta R y se retira (nada en el aire)."""
    if e < 0 or e > 12:
        return
    sube = min(1.0, (e + 1) / 5.0)
    baja = 1.0 if e < 8 else max(0.0, 1.0 - (e - 8) / 4.0)
    r = R * sube
    d = np.hypot(XX - cx, (YY - cy) / 0.8)
    borde = r * (1.0 + 0.06 * np.sin(np.arctan2(YY - cy, XX - cx) * 9 + sem))
    poner(s, (d < borde) & (TRAMA < 0.75 * baja), NEGRO[1])
    poner(s, (d < borde * 0.7) & (TRAMA < 0.5 * baja), NEGRO[0])
    poner(s, (np.abs(d - borde) < 0.8) & (TRAMA < 0.6 * baja), NEGRO[2])


# ------------------------------------------------------------
#  LA C MEJORADA (18/11, eligio la C y "todo me gusta, haz varios ejemplos"): la sombra en el suelo con
#    BRAZOS en el borde (los de la Voragine: negros, en media luna, con la pincelada clara rota), REMOLINOS que giran
#    dentro, GOTAS DE TINTA que salpica al nacer, y al acabar SE RECOGE EN EL (se la traga, como Bebe la luz).
#  Tres caracteres:  C1 ZARPAS (7 brazos cortos y gordos)  C2 TENTACULOS (5 largos y finos que ondulan)
#                    C3 MAREA (14 cortitos como un borde vivo, mas gotas y remolino fuerte)
#  Todo va en el SUELO (debajo de los muñecos): es su sombra.
# ------------------------------------------------------------
VARIANTES_C = {
    'C1': {'brazos': 7, 'largo': 0.38, 'grueso': 3.6, 'onda': 0.10, 'curva': 0.55, 'remolinos': 2, 'giro': 0.10, 'gotas': 10},
    'C2': {'brazos': 5, 'largo': 0.62, 'grueso': 2.4, 'onda': 0.35, 'curva': 0.9, 'remolinos': 3, 'giro': 0.16, 'gotas': 8},
    'C3': {'brazos': 14, 'largo': 0.22, 'grueso': 2.6, 'onda': 0.18, 'curva': 0.35, 'remolinos': 3, 'giro': 0.22, 'gotas': 18},
}
NACE, QUIETA, RECOGE = 5, 7, 6   # fotogramas de cada fase


def _p(cx, cy, r, th):
    return cx + math.cos(th) * r, cy + math.sin(th) * r * 0.8


def _fase(e):
    """El tamaño de la sombra (0..1) segun el fotograma: crece, se queda, se recoge en el."""
    if e < 0:
        return 0.0
    if e < NACE:
        return 1.0 - (1.0 - (e + 1) / NACE) ** 2
    if e < NACE + QUIETA:
        return 1.0
    k = (e - NACE - QUIETA) / RECOGE
    return max(0.0, 1.0 - k * k * 1.0) if k < 1 else 0.0


def sombra_viva(s, cx, cy, R, e, v, sem=3):
    cfg = VARIANTES_C[v]
    u = _fase(e)
    if u <= 0.0:
        return
    rnd = random.Random(sem)
    r = R * (1.0 - cfg['largo'] * 0.6) * u      # el cuerpo de la sombra (los brazos llegan al borde R)
    d = np.hypot(XX - cx, (YY - cy) / 0.8)
    ang = np.arctan2((YY - cy) / 0.8, XX - cx)
    borde = r * (1.0 + 0.05 * np.sin(ang * 7 + sem + e * 0.3))
    poner(s, (d < borde) & (TRAMA < 0.85), NEGRO[1])
    poner(s, (d < borde * 0.72) & (TRAMA < 0.6), NEGRO[0])
    # REMOLINOS: espirales algo mas claras que giran despacio dentro
    for k in range(cfg['remolinos']):
        g0 = k * math.tau / cfg['remolinos'] + e * cfg['giro']
        for i in range(26):
            q = i / 26
            rr = r * (0.18 + 0.7 * q)
            th = g0 + q * 2.4
            x, y = _p(cx, cy, rr, th)
            if q < 0.85:
                punto(s, x, y, NEGRO[2], 2 if 0.3 < q < 0.7 else 1)
    # BRAZOS: del borde hacia fuera, curvos, gordos en la base y afilados en la punta, ondulando
    n = cfg['brazos']
    for k in range(n):
        th0 = k * math.tau / n + rnd.uniform(-0.2, 0.2)
        largo = R * cfg['largo'] * u * rnd.uniform(0.8, 1.15)
        lado = 1 if k % 2 else -1
        pasos = max(6, int(largo * 1.6))
        for i in range(pasos):
            q = i / pasos
            th = th0 + lado * cfg['curva'] * q * q + cfg['onda'] * math.sin(e * 0.9 + k + q * 4) * q
            x, y = _p(cx, cy, r * 0.92 + largo * q, th)
            w = cfg['grueso'] * (1.0 - q) ** 0.7 * min(1.0, u * 1.5)
            if w < 0.5:
                continue
            disco(s, x, y, w, NEGRO[1])
            disco(s, x, y, max(0.5, w - 1.0), NEGRO[0])
            # la pincelada clara, ROTA: solo en el lado de fuera de la curva y a tramos
            if 0.15 < q < 0.8 and math.sin(q * 9 + k) > -0.2:
                nx, ny = -math.sin(th) * lado, math.cos(th) * 0.8 * lado
                punto(s, x + nx * w * 0.8, y + ny * w * 0.8, NEGRO[3])
    # la pincelada clara rota en el filo del cuerpo
    rota = np.sin(ang * 9 + sem - e * 0.4) > 0.3
    poner(s, (np.abs(d - borde + 0.6) < 0.6) & rota & (TRAMA < u), NEGRO[3])
    # GOTAS DE TINTA al nacer: salen por delante del borde, caen y se quedan un rato como manchitas
    if e < NACE + QUIETA:
        for i in range(cfg['gotas']):
            th = rnd.uniform(0, math.tau)
            lejos = R * rnd.uniform(0.95, 1.25)
            t0 = rnd.uniform(0, 2)
            k = (e - t0) / 3.0
            if k < 0:
                continue
            kk = min(1.0, k)
            x, y = _p(cx, cy, r * 0.5 + (lejos - r * 0.5) * kk, th)
            y -= math.sin(math.pi * kk) * 6 if k < 1 else 0
            fuerza = 1.0 - max(0.0, e - NACE - 2) / 5.0
            if TRAMA[int(y) % H, int(x) % W] < fuerza:
                disco(s, x, y, 1.4 if k >= 1 else 1.1, NEGRO[0])
                punto(s, x - 0.5, y - 0.5, NEGRO[2])


def _c_mejorada(v):
    def pieza(a, s, cx, cy, R, e, sem=0):
        sombra_viva(s, cx, cy, R, e, v, sem)
    return pieza


CHILLIDOS = {'A': chillido_a, 'B': chillido_b, 'C': chillido_c,
             'C1': _c_mejorada('C1'), 'C2': _c_mejorada('C2'), 'C3': _c_mejorada('C3')}


# ------------------------------------------------------------
#  LAS FILAS
# ------------------------------------------------------------
def mordisco(fila, var=NORMAL, anim='embestida'):
    """El basico y cada mordisco del Picado: los paletos en la cara."""
    dx, dy = DIRS[fila]
    A = (W * 0.42 - dx * 14, H * 0.55 - dy * 10)
    V = (A[0] + dx * 26, A[1] + dy * 22 + 10)
    L = max(1e-3, math.hypot(dx, dy))
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        spr = marco(var, anim, min(f, 7), fila)
        victima(s, *V)
        hx, hy = cabeza_v(V)
        paletos(a, hx, hy, dx / L, dy / L, f - 4)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def chillido_normal(fila):
    """El Chillido de hoy en pixel: onda en cono y los oidos en blanco del que pilla."""
    dx, dy = DIRS[fila]
    R = 100.0 / UNIDAD * 0.8
    A = (W * 0.5 - dx * R * 0.45, H * 0.5 - dy * R * 0.4)
    eje = math.atan2(dy, dx)
    boca = (A[0] + dx * 10, A[1] + dy * 6 - 4)
    vict = [(A[0] + math.cos(eje + k) * R * u, A[1] + math.sin(eje + k) * R * u + 6) for k, u in ((-0.45, 0.5), (0.35, 0.6), (0.0, 0.9))]
    mitad = math.radians(120) * 0.5
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        d = np.hypot(XX - boca[0], YY - boca[1])
        ang = np.arctan2(YY - boca[1], XX - boca[0])
        rel = np.abs((ang - eje + np.pi) % (2 * np.pi) - np.pi)
        for k in range(3):
            e = f - 1 - k * 2.5
            if e < 0:
                continue
            r = 8 + e * 6.0
            if r > R:
                continue
            fuerza = 1.0 - r / R
            borde = np.abs(d - r)
            en = (rel < mitad * (0.4 + 0.6 * min(1.0, r / 30.0))) & (borde < 2.0)
            poner(a, en & (TRAMA < fuerza * 1.4), SONIDO[1])
            poner(a, en & (borde < 0.9) & (TRAMA < fuerza * 1.6), SONIDO[2])
        for v in vict:
            victima(s, *v)
            llega = f - 1 - int(math.hypot(v[0] - boca[0], v[1] - boca[1]) / 6.0)
            oidos(a, *cabeza_v(v), llega)
        m.append(escena([s], [(marco(NORMAL, 'chillido', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def chillido_oscuro(version, var=APAGA, radio_mundo=70.0, con_farol=True, con_motas=True, fila=1):
    """El Chillido de oscuridad en circulo alrededor suyo; los que pilla se quedan A oscuras (y se les bebe la luz)."""
    pieza = CHILLIDOS[version]
    R = radio_mundo / UNIDAD
    A = (W * 0.5, H * 0.5 + (8 if var == PINA else 4))
    spr0 = marco(var, 'idle', 0, fila)
    c = centro(spr0, A)
    cx, cy = c[0], c[1] + 3   # centrado en su cuerpo (vuela: el circulo es suyo, no de un punto bajo el)
    vict = alrededor((cx, cy), R * 0.7, 3)
    m, t = [], []
    for f in range(24):
        s, a = nuevo(), nuevo()
        spr = marco(var, 'chillido_oscuro', min(f, 7), fila)
        pieza(a, s, cx, cy, R, f - 2, 3)
        for i, v in enumerate(vict):
            victima(s, *v)
            dist = math.hypot(v[0] - cx, (v[1] - cy) / 0.8)
            llega = f - 2 - int(5.0 * dist / R)
            hx, hy = cabeza_v(v)
            if con_farol:
                farol(a, hx, hy, llega)
            if con_motas:
                motas(a, (hx, hy - 9), c, llega - 3, 4, i * 5)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def _sin_rejilla(fn):
    import transparencia as tr

    def envuelto(*a, **k):
        return tr.con_alfa(fn, [ep, sl, rt, sys.modules[__name__]], *a, **k)
    return envuelto


def principal():
    global mordisco, chillido_normal, chillido_oscuro
    if os.environ.get('CON_REJILLA') != '1':
        mordisco, chillido_normal, chillido_oscuro = map(_sin_rejilla, (mordisco, chillido_normal, chillido_oscuro))
    os.makedirs(SALIDA, exist_ok=True)
    if os.environ.get('SOLO_C') == '1':
        return _lamina_c()
    filas, gifs = [], []

    def fila(nombre, mt, idx):
        filas.append((nombre, elegir(mt[0], idx)))
        gifs.append(mt)

    for d in (1, 4):
        fila('NORMAL basico y Picado\n(los paletos)\nhacia el ' + NOM_DIR[d], mordisco(d), (3, 4, 5, 6, 7, 9, 12))
    for d in (2, 4):
        fila('NORMAL Chillido\n(oidos en blanco)\nhacia el ' + NOM_DIR[d], chillido_normal(d), (1, 3, 5, 8, 11, 14, 17))
    pasos = (2, 4, 6, 8, 10, 13, 17)
    for v in ('A', 'B', 'C'):
        nom = {'A': 'A anillo de tinta', 'B': 'B ondas negras', 'C': 'C sombra en el suelo'}[v]
        fila('APAGALUCES Chillido\nde oscuridad\n' + nom, chillido_oscuro(v), pasos)
    for v in ('A', 'B', 'C'):
        fila('PIÑA Chillido de\noscuridad (r 70)\nversion ' + v, chillido_oscuro(v, PINA), pasos)
    for v in ('A', 'B', 'C'):
        fila('CRIA Chillido de\noscuridad (r 45)\nversion ' + v, chillido_oscuro(v, CRIA, 45.0), pasos)
    lamina(filas, os.path.join(SALIDA, 'chillon.png'))
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'chillon.gif'), 2)
    print('hecho en', SALIDA, 'chillon')


def _lamina_c():
    """La C mejorada en tres caracteres, en los tres bichos: chillon_c.png/.gif."""
    filas, gifs = [], []
    pasos = (1, 3, 5, 8, 11, 14, 17, 19)
    nombres = {'C1': 'C1 ZARPAS', 'C2': 'C2 TENTACULOS', 'C3': 'C3 MAREA'}
    for v in ('C1', 'C2', 'C3'):
        for var, r, nom in ((APAGA, 70.0, 'APAGALUCES'), (PINA, 70.0, 'PIÑA'), (CRIA, 45.0, 'CRIA (r 45)')):
            mt = chillido_oscuro(v, var, r)
            filas.append(('%s\n%s' % (nombres[v], nom), elegir(mt[0], pasos)))
            gifs.append(mt)
    lamina(filas, os.path.join(SALIDA, 'chillon_c.png'))
    todos, tiempos = [], []
    for marcos, ts in gifs[::3] + gifs[1::3]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'chillon_c.gif'), 2)
    print('hecho en', SALIDA, 'chillon_c')


if __name__ == '__main__':
    principal()
