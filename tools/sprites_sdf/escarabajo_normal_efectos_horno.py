#!/usr/bin/env python3
# ============================================================
#  escarabajo_normal_efectos_horno.py -- HORNEA LOS EFECTOS DEL ESCARABAJO NORMAL (el de hierro): la pala del basico, la banda de la
#  Embestida rodante, el cruce de la bola sobre cada uno y el anillo de polvo del Caparazon. (El reflejo del Caparazon se le enciende
#  sobre su propio sprite: GrietaPixel.reflejo.) Se suman a las hojas del 'escarabajo' (sus mutantes).
#    python tools/sprites_sdf/escarabajo_normal_efectos_horno.py
# ============================================================
import math
import random

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import escarabajo_normal_efectos_pixel as en
import horno_efectos as ho
from slime_efectos_pixel import nuevo, estrella

sl.victima = en.victima = ep.victima = lambda a, x, y: None
LA = 'escarabajo'
W, H = sl.W, sl.H
CX, CY = W // 2, H // 2
DIRS = sl.DIRS[:5]
ORIGENES = [(CX, CY)] * 5
UNIDAD = sl.UNIDAD


def filas_dir(pintar, n):
    filas = []
    for i, (dx, dy) in enumerate(DIRS):
        fila = []
        for f_ in range(n):
            s, a = nuevo(), nuevo()
            pintar(s, a, f_, dx, dy, i)
            fila.append((s, a))
        filas.append(fila)
    return filas, ORIGENES


d = {}


# La pala: (CX, CY) = los pies del que recibe; se hunde en el marco 2.
def pala(s, a, e, dx, dy, i):
    pecho = (CX, CY - 9)
    if e < 5:
        ida = (-7.0, -3.5, 0.0, 0.5, 0.5)[e]
        en.pala(a, pecho[0] + dx * ida, pecho[1] + dy * ida, dx, dy, 9.0, (0, 0, 0.5, 1, 1)[e])
    if e in (2, 3):
        estrella(a, pecho[0], pecho[1], (12, 7)[e - 2], en.HIERRO)
        en.chispas(a, pecho[0], pecho[1], e * 7 + i)


f, o = filas_dir(pala, 6)
d['pala'] = ho.guardar_efecto(LA, 'pala', f, o, 14.0)


# El cruce de la bola sobre el que atraviesa.
def arrolla(s, a, e, dx, dy, i):
    if e < 3:
        en.pala(a, CX, CY - 9, dx, dy, 8.0, 0.3)
        estrella(a, CX, CY - 9, (10, 6, 4)[e], en.HIERRO)
        en.chispas(a, CX - dy * 6, CY - 9 + dx * 6, e * 3 + i, 3)
        en.chispas(a, CX + dy * 6, CY - 9 - dx * 6, e * 5 + i, 3)


f, o = filas_dir(arrolla, 3)
d['arrolla'] = ho.guardar_efecto(LA, 'arrolla', f, o, 16.0)

# La banda de tierra aplastada y el polvo, por su linea (100 de mundo); la bola la recorre en InsectoAire.T_RODADA.
L = 100.0 / UNIDAD
CORRE = 9


def rodada(s, a, f_, dx, dy, i):
    dd = L * min(1.0, (f_ + 1) / float(CORRE))
    en.rodada_suelo(s, (CX, CY), dx, dy, dd, f_, CORRE, L)
    ep._huellas_polvo(s, CX, CY, dx, dy, dd, 23, 8.0)


f, o = filas_dir(rodada, CORRE + 16)
d['rodada'] = ho.guardar_efecto(LA, 'rodada', f, o, CORRE / (8.0 / 18.0), False, CORRE, 12.0)

# El anillo de polvo del Caparazon, a ras del suelo: (CX, CY) = sus pies.
_rnd = random.Random(8)
MOTAS = [(i / 16.0 * math.tau + _rnd.uniform(-0.15, 0.15), _rnd.uniform(3.0, 4.5)) for i in range(16)]


def polvo(s, a, e):
    for ang, r in MOTAS:
        dist = 14.0 + e * 3.2
        rr = r * max(0.0, 1.0 - e / 7.0)
        if rr > 0.7:
            ep.bolita(s if math.sin(ang) < 0 else a, CX + math.cos(ang) * dist, CY + 6 + math.sin(ang) * dist * 0.55, rr, en.POLVO)


f, o = [[]], [(CX, CY)]
for e in range(8):
    s, a = nuevo(), nuevo()
    polvo(s, a, e)
    f[0].append((s, a))
d['capa_polvo'] = ho.guardar_efecto(LA, 'capa_polvo', f, o, 12.0)
ho.sumar(LA, d)
