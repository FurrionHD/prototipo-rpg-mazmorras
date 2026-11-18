#!/usr/bin/env python3
# ============================================================
#  chupasimas_efectos_pixel.py -- LOS EFECTOS DE LA CHUPASIMAS Y SUS MUTANTES EN PIXEL ART (18/11/2026, memorias
#  efectos-a-pixel-art y chupasimas-mutante). La receta de la de la polilla (polilla_efectos_pixel.py): misma rejilla que
#  los sprites, paletas de 4 tonos, lo que se va a TRAMA y sin rejilla (transparencia de verdad), sobre sus sprites.
#  LA NORMAL (hoy a mano: capa_hechizos VENTOSA/DRENAR y SimaAire): la VENTOSA (su basico y el Adherirse: llega abierta y
#    se cierra en la cara) y la CHUPADA (gotas de sangre que suben de la victima a su boca).
#  COAGULO (eligio el jefe): la costra SE CUAJA al chupar (gotas rojas que le suben por el lomo y se oscurecen a marron),
#    CHORREA con el agua (el x1,3: gotas rojas que bajan) y suelta POSTILLAS QUE SALTAN al romperse.
#  VIDRIADA: el MORDISCO VIDRIADO y el SORBO beben MANA (gotas AZULES que suben, como la chupada pero en azul); el RAYO DE
#    MANA, un haz azul con nucleo blanco y GROSOR SEGUN LA CARGA (fino con poca, gordo y con chispas lleno).
#  MADRE: el Drenaje con sangre Y mana (y la costra que se cuaja), y el rayo lleno.
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/chupasimas_efectos_pixel.py
# ============================================================
import math
import os
import random
import sys

import numpy as np

import ciempies_efectos_pixel as ce
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import miconido_efectos_pixel as mi

W, H = 330, 240
YY, XX = np.mgrid[0:H, 0:W]
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
for _m in (ce, ep, sl, rt, mi):
    _m.W, _m.H, _m.YY, _m.XX, _m.TRAMA = W, H, YY, XX, TRAMA

from slime_efectos_pixel import SALIDA, nuevo, estrella, elegir, NOM_DIR  # noqa: E402
from rata_efectos_pixel import marco, escena  # noqa: E402

poner, punto, bolita = ep.poner, ep.punto, ep.bolita
cabeza, caja_dibujo, pies, _dir = mi.cabeza, mi.caja_dibujo, mi.pies, mi._dir

NORMAL = 'chupasimas_sdf'
COAGULO, COAGULO_C = 'chupasimas_sdf_coagulo', 'chupasimas_sdf_coagulo_costra'
VIDRIADA = 'chupasimas_sdf_vidriada'
MADRE, MADRE_C = 'chupasimas_sdf_madre', 'chupasimas_sdf_madre_costra'

SANGRE = [(70, 8, 14), (150, 20, 28), (214, 44, 44), (255, 150, 140)]
COSTRA = [(40, 16, 14), (96, 52, 40), (150, 90, 64), (196, 136, 104)]
MANA = [(16, 40, 110), (40, 100, 220), (84, 168, 255), (226, 242, 255)]
AGUA = [(20, 60, 110), (50, 120, 190), (120, 190, 240), (230, 246, 255)]
DIENTE = [(80, 60, 50), (180, 160, 140), (238, 228, 206), (255, 255, 250)]


def frente(spr, pos, dx, dy, k=0.45):
    """El borde de su dibujo hacia donde mira: su boca."""
    x0, y0, x1, y1 = caja_dibujo(spr, pos)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return cx + dx * (x1 - x0) * k, cy + dy * (y1 - y0) * k - 2


def _mezcla(p, q, k):
    return tuple(int(p[i] + (q[i] - p[i]) * k) for i in range(3))


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
def gotas(a, desde, hasta, e, pal, n=5, sem=0, vuelo=4.0):
    """LA CHUPADA: gotas que salen de 'desde' (la victima), suben en arco y entran en 'hasta' (su boca), una tras otra."""
    rnd = random.Random(sem)
    for i in range(n):
        t0 = i * 0.9 + rnd.uniform(0, 0.4)
        k = (e - t0) / vuelo
        if k < 0 or k > 1:
            continue
        ox, oy = rnd.uniform(-4, 4), rnd.uniform(-3, 3)
        x = desde[0] + ox + (hasta[0] - desde[0] - ox) * k
        y = desde[1] + oy + (hasta[1] - desde[1] - oy) * k - math.sin(math.pi * k) * 9
        bolita(a, x, y, 1.6 - 0.5 * k, pal)


def ventosa(a, hx, hy, e, pal):
    """LA VENTOSA: llega ABIERTA (un aro con el anillo de dientes) y se CIERRA de golpe en la cara."""
    if e < 0 or e > 5:
        return
    r = 8.0 - min(e, 2) * 2.0
    fuerza = 1.0 if e < 3 else 1.0 - (e - 2) / 3.5
    d = np.hypot(XX - hx, (YY - hy) * 1.5)
    poner(a, (np.abs(d - r) < 1.4) & (TRAMA < fuerza), pal[1])
    poner(a, (np.abs(d - r + 0.6) < 0.6) & (TRAMA < fuerza), pal[2])
    for i in range(8):
        ang = i / 8 * math.tau
        x, y = hx + math.cos(ang) * (r - 2.2), hy + math.sin(ang) * (r - 2.2) / 1.5
        if TRAMA[int(y) % H, int(x) % W] < fuerza:
            punto(a, x, y, DIENTE[2])
    if e == 2:
        estrella(a, hx, hy, 4, pal)


def cuaja(a, box, e, sem, n=7):
    """LA COSTRA SE CUAJA: gotas rojas que suben por el lomo, se posan arriba y se OSCURECEN poco a poco hasta marron."""
    x0, y0, x1, y1 = box
    rnd = random.Random(sem)
    for i in range(n):
        u = (i + 0.5) / n
        # sobre el LOMO: la mitad de arriba de su dibujo, repartidas a lo ancho
        tx = x0 + (x1 - x0) * (0.2 + 0.6 * u) + rnd.uniform(-1.5, 1.5)
        ty = y0 + (y1 - y0) * (0.12 + 0.18 * math.sin(math.pi * u)) + rnd.uniform(-1, 1)
        t0 = i * 0.5
        k = e - t0
        if k < 0:
            continue
        if k < 3:   # sube desde la panza
            y = ty + (1.0 - k / 3.0) * 10
            bolita(a, tx, y, 1.5, SANGRE)
        else:       # posada: de rojo a marron
            o = min(1.0, (k - 3) / 4.0)
            pal = [_mezcla(SANGRE[j], COSTRA[j], o) for j in range(4)]
            bolita(a, tx, ty, 1.7 + 0.4 * o, pal)


def chorrea(a, box, e, sem, n=6):
    """EL AGUA LA DISUELVE: salpica el agua arriba y la costra CHORREA: gotas rojas que bajan por los lados."""
    x0, y0, x1, y1 = box
    cx = (x0 + x1) / 2
    if 0 <= e <= 2:
        for j in range(7):
            ang = math.radians(200 + j * 20)
            r = 3 + e * 3
            bolita(a, cx + math.cos(ang) * r * 1.4, y0 + 2 + math.sin(ang) * r * 0.6, 1.3, AGUA)
    rnd = random.Random(sem)
    for i in range(n):
        t0 = 1 + i * 0.7
        k = e - t0
        if k < 0 or k > 6:
            continue
        x = x0 + (x1 - x0) * (0.15 + 0.7 * rnd.random())
        y = y0 + (y1 - y0) * 0.3 + k * 2.6
        fuerza = 1.0 - max(0.0, k - 4) / 2.5
        if TRAMA[int(y) % H, int(x) % W] < fuerza:
            bolita(a, x, y, 1.3, SANGRE)
            punto(a, x, y - 2, SANGRE[1])


def postillas(a, cx, cy, e, sem, n=6):
    """LA COSTRA SE ROMPE: cinco o seis trozos marrones salen despedidos y caen; una salpicadura roja pequeña."""
    if e < 0 or e > 9:
        return
    if e <= 2:
        d = np.hypot(XX - cx, (YY - cy) * 1.4)
        r = 3 + e * 3
        poner(a, (np.abs(d - r) < 1.0) & (TRAMA < 0.8), SANGRE[2])
    rnd = random.Random(sem)
    for i in range(n):
        ang = math.radians(-160 + i * (140 / (n - 1)) + rnd.uniform(-8, 8))
        v = rnd.uniform(2.4, 3.4)
        x = cx + math.cos(ang) * v * e * 1.3
        y = cy + math.sin(ang) * v * e + 0.45 * e * e
        fuerza = 1.0 - max(0.0, e - 6) / 3.5
        if TRAMA[int(y) % H, int(x) % W] < fuerza:
            ep.disco(a, x, y, 1.8, COSTRA[0])
            ep.disco(a, x - 0.4, y - 0.4, 1.2, COSTRA[2])
            punto(a, x + 1, y, SANGRE[2])


def rayo(a, desde, hasta, e, carga, pal=MANA, sem=0):
    """EL RAYO DE MANA: la boca se carga y suelta un HAZ azul con nucleo blanco; su GROSOR es la carga (0..1)."""
    if e < 0 or e > 8:
        return
    if e < 2:   # se carga en la boca
        bolita(a, desde[0], desde[1], 1.5 + e * (1.0 + 2.0 * carga), pal)
        return
    k = e - 2
    fuerza = 1.0 if k < 3 else 1.0 - (k - 2) / 4.0
    grueso = (1.2 + 3.6 * carga) * (1.0 if k < 3 else max(0.3, 1.0 - (k - 2) / 4.0))
    dx, dy = hasta[0] - desde[0], hasta[1] - desde[1]
    L = max(1.0, math.hypot(dx, dy))
    ux, uy = dx / L, dy / L
    # distancia de cada pixel al segmento
    px, py = XX - desde[0], YY - desde[1]
    t = np.clip(px * ux + py * uy, 0, L)
    dist = np.hypot(px - t * ux, py - t * uy)
    poner(a, (dist < grueso + 1.0) & (TRAMA < fuerza * 0.7), pal[1])
    poner(a, (dist < grueso) & (TRAMA < fuerza), pal[2])
    poner(a, (dist < grueso * 0.45) & (TRAMA < fuerza), pal[3])
    rnd = random.Random(sem + e)
    if carga > 0.6 and k < 4:   # lleno: chispas a lo largo
        for _i in range(int(4 * carga)):
            s = rnd.uniform(0.2, 1.0) * L
            estrella(a, desde[0] + ux * s + rnd.uniform(-4, 4), desde[1] + uy * s + rnd.uniform(-4, 4), 3, pal)
    if k < 3:   # el golpe en la cara
        bolita(a, hasta[0], hasta[1], grueso + 1.5, pal)


# ------------------------------------------------------------
#  LAS FILAS
# ------------------------------------------------------------
def _yo_y_victima(var, fila, dist):
    dx, dy = _dir(fila)
    A = (W * 0.42 - dx * dist * 0.5, H * 0.56 - dy * dist * 0.4)
    px, py = pies(var, A, fila)
    return A, (px + dx * dist, py + dy * dist + 2), dx, dy


def mordisco(fila, var, pal_gotas=None, anim='embestida'):
    """El basico (y el Adherirse de la normal): la ventosa en la cara; si bebe, gotas de vuelta a su boca."""
    A, V, dx, dy = _yo_y_victima(var, fila, 30)
    n, toca = 8, 4
    m, t = [], []
    for f in range(n + 8):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        spr = marco(var, anim, fr, fila)
        ep.victima(s, *V)
        hx, hy = cabeza(V)
        ventosa(a, hx, hy, f - toca, DIENTE if pal_gotas is None else pal_gotas)
        if pal_gotas is not None:
            gotas(a, (hx, hy + 2), frente(marco(var, 'idle', 0, fila), A, dx, dy), f - toca - 1, pal_gotas, 4, fila)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def chupada(fila, var, pals, cuaja_costra=False):
    """El DRENAJE: gotas que suben de la victima a su boca (de sangre, de mana o de las dos); con costra, se le cuaja."""
    A, V, dx, dy = _yo_y_victima(var, fila, 26)
    n = 8
    m, t = [], []
    for f in range(n + 10):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        spr = marco(var, 'drenaje', fr, fila)
        ep.victima(s, *V)
        hx, hy = cabeza(V)
        boca = frente(marco(var, 'idle', 0, fila), A, dx, dy)
        for j, pal in enumerate(pals):
            gotas(a, (hx, hy + 3), boca, f - j * 0.6, pal, 6, fila * 7 + j)
        if cuaja_costra:
            # SOBRE EL FOTOGRAMA DE VERDAD: en el drenaje se arquea, y con la caja de quieta se quedaban flotando delante.
            cuaja(a, caja_dibujo(spr, A), f - 3, fila)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 11)
    return m, t


def costra_se_rompe(var_c, var_sin):
    """Un golpe le rompe la costra: las postillas saltan y queda el cuerpo sin ellas."""
    fila = 1
    A = (W * 0.5, H * 0.55)
    m, t = [], []
    for f in range(14):
        a = nuevo()
        var = var_c if f < 3 else var_sin
        spr = marco(var, 'encaje', min(f, 3), fila) if f < 7 else marco(var, 'idle', 0, fila)
        x0, y0, x1, y1 = caja_dibujo(marco(var_c, 'idle', 0, fila), A)
        postillas(a, (x0 + x1) / 2, (y0 + y1) / 2 - 2, f - 3, 5)
        m.append(escena([], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def costra_chorrea(var_c):
    """Le pega agua con la costra puesta: salpica y la costra chorrea (le entra x1,3)."""
    fila = 1
    A = (W * 0.5, H * 0.55)
    m, t = [], []
    for f in range(14):
        a = nuevo()
        spr = marco(var_c, 'encaje', min(f, 3), fila) if f < 5 else marco(var_c, 'idle', 0, fila)
        chorrea(a, caja_dibujo(marco(var_c, 'idle', 0, fila), A), f - 1, 9)
        m.append(escena([], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def sorbo(fila):
    """El SORBO: salta, muerde, bebe (gotas azules) y se aparta (la hoja ya lleva el salto y la vuelta)."""
    A, V, dx, dy = _yo_y_victima(VIDRIADA, fila, 40)
    n = 10
    m, t = [], []
    for f in range(n + 4):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        spr = marco(VIDRIADA, 'sorbo', fr, fila)
        ep.victima(s, *V)
        hx, hy = cabeza(V)
        ventosa(a, hx, hy, f - 4, MANA)
        gotas(a, (hx, hy + 2), (hx - dx * 6, hy - 8), f - 5, MANA, 4, fila, vuelo=2.5)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def rayo_fila(fila, var, carga):
    A, V, dx, dy = _yo_y_victima(var, fila, 70)
    n = 10
    m, t = [], []
    for f in range(n + 4):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        spr = marco(var, 'rayo', fr, fila)
        ep.victima(s, *V)
        boca = frente(marco(var, 'idle', 0, fila), A, dx, dy)
        rayo(a, boca, cabeza(V), f - 4, carga, MANA, fila)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 11)
    return m, t


def _sin_rejilla(fn):
    import transparencia as tr

    def envuelto(*a, **k):
        return tr.con_alfa(fn, [ce, ep, sl, rt, mi, sys.modules[__name__]], *a, **k)
    return envuelto


def principal():
    global mordisco, chupada, costra_se_rompe, costra_chorrea, sorbo, rayo_fila
    if os.environ.get('CON_REJILLA') != '1':
        mordisco, chupada, costra_se_rompe, costra_chorrea, sorbo, rayo_fila = map(
            _sin_rejilla, (mordisco, chupada, costra_se_rompe, costra_chorrea, sorbo, rayo_fila))
    os.makedirs(SALIDA, exist_ok=True)
    filas, gifs = [], []

    def fila(nombre, mt, idx):
        filas.append((nombre, elegir(mt[0], idx)))
        gifs.append(mt)

    for d in (1, 4):
        fila('NORMAL ventosa (basico)\nhacia el ' + NOM_DIR[d], mordisco(d, NORMAL), (3, 4, 5, 6, 7, 9, 11))
    fila('NORMAL Drenaje\n(sangre)', chupada(1, NORMAL, [SANGRE]), (1, 3, 5, 7, 9, 12, 15))
    fila('COAGULO Drenaje:\nse le cuaja la costra', chupada(1, COAGULO, [SANGRE], True), (2, 4, 6, 8, 10, 13, 17))
    fila('COAGULO le rompen\nla costra', costra_se_rompe(COAGULO_C, COAGULO), (2, 3, 4, 5, 7, 9, 12))
    fila('COAGULO le pega agua\ncon costra (x1,3)', costra_chorrea(COAGULO_C), (0, 1, 2, 4, 6, 8, 11))
    for d in (1, 4):
        fila('VIDRIADA Mordisco\nvidriado hacia el ' + NOM_DIR[d], mordisco(d, VIDRIADA, MANA), (3, 4, 5, 6, 8, 10, 12))
    fila('VIDRIADA Sorbo', sorbo(1), (1, 3, 4, 5, 6, 8, 11))
    fila('VIDRIADA Drenaje\nde mana', chupada(1, VIDRIADA, [MANA]), (1, 3, 5, 7, 9, 12, 15))
    fila('VIDRIADA Rayo de mana\ncon poca carga', rayo_fila(1, VIDRIADA, 0.15), (1, 3, 5, 6, 7, 9, 12))
    fila('VIDRIADA Rayo de mana\nLLENO', rayo_fila(1, VIDRIADA, 1.0), (1, 3, 5, 6, 7, 9, 12))
    fila('MADRE Drenaje:\nsangre y mana', chupada(1, MADRE, [SANGRE, MANA], True), (2, 4, 6, 8, 10, 13, 17))
    fila('MADRE le rompen\nla costra', costra_se_rompe(MADRE_C, MADRE), (2, 3, 4, 5, 7, 9, 12))
    fila('MADRE Rayo de mana\nLLENO hacia el ' + NOM_DIR[4], rayo_fila(4, MADRE, 1.0), (1, 3, 5, 6, 7, 9, 12))
    ce.lamina(filas, os.path.join(SALIDA, 'chupasimas.png'), 3)
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'chupasimas.gif'), 2)
    print('hecho en', SALIDA, 'chupasimas')


if __name__ == '__main__':
    principal()
