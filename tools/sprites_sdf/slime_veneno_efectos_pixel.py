#!/usr/bin/env python3
# ============================================================
#  slime_veneno_efectos_pixel.py -- LOS EFECTOS DEL SLIME VENENOSO (y sus mutantes, el de miasma y el pestilente) EN
#  PIXEL ART (04/11/2026, memoria efectos-a-pixel-art). Piezas de slime_efectos_pixel.py en su verde. Los mismos que hoy
#  pintan SlimeAire (ROCIADA, ESCUPE), MagiaAire/SlimeAire (la bocanada del Exhalar), SlimeBurbuja y HumoToxico:
#    basico y Placaje corrosivo (los del slime, en verde), Rociada (abanico de gotas que dejan manchas), Escupitajo
#    (bola de baba en parabola que revienta en el pecho), Exhalar (nube de gas desde su cuerpo), Burbujas pestilentes
#    (salen, flotan, tiemblan y revientan) y lo que les sale solo del cuerpo (la bocanada del de miasma, la burbuja del
#    pestilente).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/slime_veneno_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image

import slime_efectos_pixel as sl
import escarabajo_efectos_pixel as ep
from slime_efectos_pixel import (W, H, XX, YY, TRAMA, UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella, cometa_dir,
                                 victima, gota, charco, seco, Gotas, marco, escena, sombra, lamina, elegir, DIRS, NOM_DIR)

# SU VERDE (el 47d552 en que estan pintadas sus hojas); en el juego, el del color de cada uno.
sl.GEL = [(20, 80, 34), (58, 170, 70), (150, 232, 130), (232, 255, 212)]
sl.GEL_BORDE = (8, 36, 16)
GEL = sl.GEL
GAS = [(48, 92, 44), (96, 160, 72), (158, 214, 110), (222, 248, 180)]

NORMAL, MIASMA, PESTE = 's115', 'mia138', 'pes152'
BOCA = 7.0     # de donde sale lo que escupe, sobre sus pies (ALTO_BOCA de SlimeAire en celdas)


# Una BOCANADA de gas: bulto de tres tonos con el borde deshecho a trama (el gas no tiene borde duro).
def nube(a, x, y, r, fuerza=1.0, pal=GAS):
    """El gas se lee a TRAMA: nunca una bola maciza; claro por arriba y mas ralo hacia el borde."""
    if r < 1.0 or fuerza <= 0.0:
        return
    d = np.hypot(XX - x, YY - y)
    d2 = np.hypot(XX - (x - r * 0.2), YY - (y - r * 0.3))
    poner(a, (d < r) & (d >= r * 0.65) & (TRAMA < 0.3 * fuerza), pal[0])
    poner(a, (d < r * 0.65) & (TRAMA < 0.55 * fuerza), pal[1])
    poner(a, (d2 < r * 0.4) & (TRAMA < 0.5 * fuerza), pal[2])
    poner(a, (d2 < r * 0.18) & (TRAMA < 0.35 * fuerza) & (fuerza > 0.5), pal[3])


def boca(A, dx, dy, rad):
    return A[0] + dx * rad * 0.7, A[1] + dy * rad * 0.5 - BOCA


# --- LA ROCIADA: un abanico de gotas que salen de su boca, vuelan bajas por el cono y caen haciendo mancha ---
def rociada(fila, var=NORMAL, radio_mundo=45.0, apertura=70.0):
    dx, dy = DIRS[fila]
    R = radio_mundo / UNIDAD
    A = (W * 0.5 - dx * R * 0.4, H * 0.58 - dy * R * 0.35)
    rad = marco(var, 'escupir', 0, fila).size[0] * 0.3
    bx, by = boca(A, dx, dy, rad)
    eje = math.atan2(dy, dx)
    gotas = Gotas(20, 13 + fila, R * 0.35, R, (eje, math.radians(apertura) * 0.45), sube=(4.0, 11.0), tam=(1.3, 2.2))
    sl.ORIGEN = A
    vict = [(A[0] + math.cos(eje + k) * R * 0.8, A[1] + math.sin(eje + k) * R * 0.8 + 3) for k in (-0.35, 0.3)]
    m, t = [], []
    sale = 3
    for f in range(sale + 16):
        s, a = nuevo(), nuevo()
        if f >= sale:
            e = f - sale
            if e < 2:
                gota(a, bx, by, (3.5, 2.5)[e])
            gotas.pintar(s, a, bx, by + BOCA, min(1.0, e / 5.0), rad * 0.5, 1.0, e - 5)
        for v in vict:
            victima(s if v[1] < A[1] else s, *v)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- EL ESCUPITAJO: una bola de baba en parabola, con estela de gotas, que revienta en el pecho y deja un charquito ---
def escupitajo(fila, var=NORMAL):
    dx, dy = DIRS[fila]
    dist = 64.0
    A = (W * 0.5 - dx * dist * 0.5, H * 0.58 - dy * dist * 0.45)
    V = (A[0] + dx * dist, A[1] + dy * dist + 4)
    sl.ORIGEN = V
    rad = marco(var, 'escupir', 0, fila).size[0] * 0.3
    bx, by = boca(A, dx, dy, rad)
    pecho = (V[0], V[1] - 10)
    salpica = Gotas(8, 5 + fila, 4.0, 13.0, sube=(8.0, 16.0), tam=(1.2, 2.0))
    m, t = [], []
    vuelo = 6
    for f in range(3 + vuelo + 14):
        s, a = nuevo(), nuevo()
        e = f - 3
        if 0 <= e < vuelo:
            u = (e + 1) / float(vuelo)
            x = bx + (pecho[0] - bx) * u
            y = by + (pecho[1] - by) * u - 16.0 * 4 * u * (1 - u)
            ua = max(0.0, u - 0.2)
            xa = bx + (pecho[0] - bx) * ua
            ya = by + (pecho[1] - by) * ua - 16.0 * 4 * ua * (1 - ua)
            n = math.hypot(x - xa, y - ya) or 1.0
            cometa_dir(a, x, y, (x - xa) / n, (y - ya) / n, min(n * 1.4, 12.0), 1, GEL)
            for k in (1, 2):
                gota(a, x - (x - xa) / n * 5 * k, y - (y - ya) / n * 5 * k + k, 1.4 - 0.4 * k)
            gota(a, x, y, 3.4)
            sombra(s, x, V[1] - (V[1] - A[1]) * (1 - u), 3.0)
        elif e >= vuelo:
            g = e - vuelo
            if g < 2:
                estrella(a, pecho[0], pecho[1], (10, 6)[g], GEL)
                gota(a, pecho[0], pecho[1], (4.2, 3.0)[g])
            salpica.pintar(s, a, pecho[0], pecho[1], min(1.0, g / 4.0), 1.0, 1.0, 99)
            abre = min(1.0, (g + 1) / 4.0)
            charco(s, V[0] + 2, V[1] + 1, 5.5 * abre, 3.0, seco(g, 7, 6))
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- EXHALAR: aspira (el aire se le mete) y suelta una NUBE de gas que se abre desde su cuerpo hasta el borde, se queda
# un momento y se deshace; a los que pilla, una bocanadita encima ---
def exhalar(var=MIASMA, radio_mundo=50.0, n_vict=4):
    A = (W * 0.5, H * 0.56)
    R = radio_mundo / UNIDAD
    rnd = random.Random(21)
    puffs = [(rnd.uniform(0, math.tau), rnd.uniform(0.15, 1.0), rnd.uniform(9.0, 14.0), rnd.uniform(0.0, 0.25)) for _ in range(30)]
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(0.6, 1.0), rnd.random()) for _ in range(16)]
    vict = [(A[0] + math.cos(k * 1.7 + 0.4) * R * 0.7, A[1] + math.sin(k * 1.7 + 0.4) * R * 0.6 + 3) for k in range(n_vict)]
    m, t = [], []
    carga = 7
    for f in range(carga + 18):
        s, a = nuevo(), nuevo()
        if f < carga:
            anim, fr = 'aspirar', f
            # el aire que se le mete: motas de gas que van hacia su boca
            for ang, uu, fase in motas:
                k = ((f / carga) + fase) % 1.0
                d = R * uu * (1.0 - k)
                if d > 8:
                    punto(a, A[0] + math.cos(ang) * d, A[1] - 6 + math.sin(ang) * d * 0.8, GAS[2 if k > 0.5 else 1], 2)
        else:
            e = f - carga
            anim, fr = 'exhalar', min(e, 7)
            k = 1.0 - (1.0 - min(1.0, (e + 1) / 6.0)) ** 2
            fuerza = seco(e, 9, 8)
            for ang, uu, r, t0 in puffs:
                kk = max(0.0, min(1.0, (k - t0) / (1 - t0)))
                if kk <= 0:
                    continue
                d = R * uu * kk
                x, y = A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d * 0.85 - 4 - e * 0.3
                nube(a if math.sin(ang) > -0.2 else s, x, y, r * (0.5 + 0.5 * kk), fuerza)
            for i, v in enumerate(vict):
                llega = e - int(4 * math.hypot(v[0] - A[0], v[1] - A[1]) / R)
                if 0 <= llega < 6:
                    nube(a, v[0], v[1] - 12 - llega, 3.0 + llega, 1.0 - llega / 6.0)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, anim, fr, 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- LAS BURBUJAS PESTILENTES: salen de el en arco creciendo, flotan sobre su sombra, tiemblan cuando les queda poco y
# revientan (destello, gotas y su bocanada de gas) ---
def burbuja(a, x, y, r, fase, pal=None):
    pal = pal or GEL
    d = np.hypot(XX - x, YY - y)
    abajo = ((XX - x) + (YY - y)) > r * 0.3
    poner(a, (d < r) & (d >= r - 1.2), pal[1])
    poner(a, (d < r) & (d >= r - 1.2) & abajo, pal[0])
    # dentro, translucida: el gas que se remueve, a trama
    giro = np.sin(np.arctan2(YY - y, XX - x) * 2 + fase + d * 0.5)
    poner(a, (d < r - 1.2) & (TRAMA < 0.12 + 0.18 * (giro > 0.3)), GAS[1])
    poner(a, (d < r - 1.2) & (giro > 0.75) & (TRAMA < 0.35), GAS[2])
    # el brillo: media luna arriba a la izquierda y un punto
    d2 = np.hypot(XX - (x + r * 0.2), YY - (y + r * 0.2))
    poner(a, (d < r - 1.5) & (d2 > r * 0.95) & ((XX - x) + (YY - y) < 0), pal[2])
    punto(a, x - r * 0.45, y - r * 0.5, pal[3], 2)


def burbujas(var=PESTE):
    A = (W * 0.5, H * 0.55)
    rnd = random.Random(4)
    lista = [(rnd.uniform(0, math.tau), rnd.uniform(32.0, 46.0), rnd.uniform(0, 6), rnd.randint(0, 3)) for _ in range(4)]
    vict = [(A[0] + 44, A[1] + 18), (A[0] - 40, A[1] - 22)]
    m, t = [], []
    vuelo, flota = 5, 12
    for f in range(vuelo + flota + 10):
        s, a = nuevo(), nuevo()
        for i, (ang, d, fase, retraso) in enumerate(lista):
            px, py = A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d * 0.8
            if f < vuelo:
                u = (f + 1) / float(vuelo)
                x, y = A[0] + (px - A[0]) * u, A[1] - 8 + (py - A[1] + 8) * u - 18 * 4 * u * (1 - u) - 12 * u
                burbuja(a, x, y, 3 + 6 * u, fase + f)
            elif f < vuelo + flota + retraso:
                e = f - vuelo
                tiembla = 1 if (vuelo + flota + retraso - f) < 5 and f % 2 else 0
                x, y = px + tiembla, py - 12 + round(math.sin(e * 0.6 + fase))
                sombra(s, px, py + 2, 5.0)
                burbuja(a, x, y, 9, fase + f)
            else:
                g = f - vuelo - flota - retraso
                x, y = px, py - 12
                if g < 2:
                    estrella(a, x, y, (12, 7)[g], GEL)
                if g < 7:
                    for k in range(8):
                        an = k / 8.0 * math.tau
                        dd = 6 + g * 2.5
                        gota(a, x + math.cos(an) * dd, y + math.sin(an) * dd * 0.8 + g * g * 0.4, 1.6 - g * 0.15)
                    nube(a, x, y - g, 5.0 + g * 1.6, 1.0 - g / 7.0)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'soltar_burbujas' if f < 8 else 'idle', min(f, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- LO QUE LES SALE SOLO DEL CUERPO: al de miasma, una bocanada por un sitio al azar; al pestilente, una burbuja que se
# le hincha en la piel, revienta y suelta la bocanada ---
def humo_cuerpo(var, con_burbuja):
    A = (W * 0.5, H * 0.58)
    rad = marco(var, 'idle', 0, 0).size[0] * 0.28
    m, t = [], []
    sitio = (A[0] + rad * 0.45, A[1] - rad * 0.9)
    for f in range(16):
        s, a = nuevo(), nuevo()
        e = f
        if con_burbuja and e < 5:
            burbuja(a, sitio[0], sitio[1], 2 + e * 1.1, f)
        else:
            g = e - (5 if con_burbuja else 0)
            if con_burbuja and g < 2:
                for k in range(6):
                    an = k / 6.0 * math.tau
                    gota(a, sitio[0] + math.cos(an) * (3 + g * 3), sitio[1] + math.sin(an) * (3 + g * 3), 1.0)
            if 0 <= g < 11:
                nube(a, sitio[0] + g * 0.4, sitio[1] - g * 2.2, 4.0 + g * 1.1, 1.0 - g / 11.0)
        m.append(escena([s], [(marco(var, 'idle', f % 8, 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: sl.basico(d, NORMAL) for d in (1, 4)}
    pc = {d: sl.placaje(d, 40.0, 16.0, NORMAL) for d in (1, 4)}
    pm = sl.placaje(2, 70.0, 47.0, MIASMA)
    ro = {d: rociada(d) for d in range(5)}
    rm = rociada(1, MIASMA, 55.0, 90.0)
    es = {d: escupitajo(d) for d in range(5)}
    exm = exhalar(MIASMA, 50.0)
    exp_ = exhalar(PESTE, 65.0, 5)
    bu = burbujas()
    hm = humo_cuerpo(MIASMA, False)
    hp = humo_cuerpo(PESTE, True)
    filas = [
        *[('BASICO\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        *[('PLACAJE CORROSIVO\nhacia el ' + NOM_DIR[d], elegir(pc[d][0], (1, 3, 5, 6, 8, 14))) for d in (1, 4)],
        ('PLACAJE MIASMATICO\nmiasma y pestilente', elegir(pm[0], (1, 3, 5, 6, 8, 14))),
        *[('ROCIADA CORROSIVA\nhacia el ' + NOM_DIR[d], elegir(ro[d][0], (3, 4, 5, 7, 9, 17))) for d in range(5)],
        ('ROCIADA DE MIASMA\n(y pestilente: igual)', elegir(rm[0], (3, 4, 5, 7, 9, 17))),
        *[('ESCUPITAJO TOXICO\n(miasma y pestilente:\nigual)\nhacia el ' + NOM_DIR[d], elegir(es[d][0], (4, 6, 8, 9, 11, 18))) for d in range(5)],
        ('EXHALAR MIASMA\naspira y suelta', elegir(exm[0], (3, 6, 8, 10, 14, 22))),
        ('EXHALACION PESTILENTE', elegir(exp_[0], (3, 6, 8, 10, 14, 22))),
        ('BURBUJAS PESTILENTES\nsalen, flotan,\nrevientan', elegir(bu[0], (1, 3, 6, 14, 18, 22))),
        ('MIASMA\nla bocanada del cuerpo', elegir(hm[0], (0, 2, 4, 6, 9, 12))),
        ('PESTILENTE\nla burbuja del cuerpo', elegir(hp[0], (1, 3, 5, 6, 9, 13))),
    ]
    lamina(filas, os.path.join(SALIDA, 'slime_venenoso.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], pc[1], ro[1], ro[2], es[1], es[2], (exm[0], exm[1]), (exp_[0], exp_[1]), bu, hm, hp]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'slime_venenoso.gif'), 3)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
