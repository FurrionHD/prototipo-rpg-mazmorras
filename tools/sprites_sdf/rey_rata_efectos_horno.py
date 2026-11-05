#!/usr/bin/env python3
# ============================================================
#  rey_rata_efectos_horno.py -- HORNEA LOS EFECTOS DEL REY RATA Y SUS MUTANTES (cloacas y desguace). Sus mordiscos son los de la rata
#  (hoja 'mordisco', ver rata_efectos_horno.py); aqui lo suyo: el Chillido, el polvo de la Yugular, la grieta de la Llamada, el
#  Tapazo (campanazo y chatarra), las chispas del Frente blindado y la Furia de Rey.
#    python tools/sprites_sdf/rey_rata_efectos_horno.py
# ============================================================
import math
import random

import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import slime_veneno_efectos_pixel as vn
import escarabajo_efectos_pixel as ep
import rey_rata_efectos_pixel as rr
import horno_efectos as ho
from slime_efectos_pixel import W, H, nuevo, estrella, punto, seco, cometa_dir

sl.victima = rt.victima = vn.victima = rr.victima = lambda a, x, y: None
rt.escena = rr.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'rey_rata'
CX, CY = W // 2, H // 2
DIRS = sl.DIRS[:5]
ORIGENES = [(CX, CY)] * 5


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


def marcos(pintar, n):
    out = []
    for f_ in range(n):
        s, a = nuevo(), nuevo()
        pintar(s, a, f_)
        out.append((s, a))
    return [out], [(CX, CY)]


def por_dirs(funcion, *args, desde=0, **kw):
    filas, origenes = [], []
    for d_ in range(5):
        m, _t = funcion(d_, *args, **kw)
        filas.append(m[desde:])
        origenes.append(sl.ORIGEN)
    return filas, origenes


d = {}
f, o = por_dirs(rr.chillido, escala=1.0, con_temblor=False)
d['chillido'] = ho.guardar_efecto(LA, 'chillido', f, o, 18.0 / 0.72)


# A quien le llega el Chillido, el sonido le vibra a los lados: (CX, CY) = su cabeza.
def temblor(s, a, e):
    tiembla = (e % 2) * 2 - 1
    for lado in (-1, 1):
        for j in range(-3, 4):
            punto(a, CX + lado * (8 + abs(j) * 0.3) + tiembla, CY + j * 1.3, rr.SONIDO[2 if abs(j) < 2 else 1], 2 if abs(j) < 2 else 1)


f, o = marcos(temblor, 7)
d['temblor'] = ho.guardar_efecto(LA, 'temblor', f, o, 7.0 / 0.45)
L = 55.0 / rr.UNIDAD


def huellas(s, a, f_, dx, dy, i):
    u = min(1.0, (f_ + 1) / 4.0)
    tmp = nuevo()
    ep._huellas_polvo(tmp, CX, CY + 10, dx, dy, L * u, 13, 7.0)   # (a la altura de sus pies)
    mascara = (tmp[:, :, 3] > 0) & (rr.TRAMA < seco(f_, 8, 6))
    s[mascara] = tmp[mascara]


f, o = filas_dir(huellas, 14)
d['yugular_polvo'] = ho.guardar_efecto(LA, 'yugular_polvo', f, o, 4.0 / 0.2, False, 4, 12.0)


# La Llamada: (CX, CY) = la grieta. Ha de estar abierta a los ReyRataAire.t_abierto() y durar agujero_dur().
def grieta(s, a, f_):
    k = min(1.0, (f_ + 1) / 6.0)
    cierra = 0.0 if f_ < 18 else (f_ - 18) / 7.0
    rr.grieta_suelo(s, CX, CY, k, 5, cierra)
    rr.boquete(s, CX, CY, (min(1.0, max(0.0, (f_ - 4) / 3.0)) * (1 - cierra)) * 8.0)
    if 6 <= f_ <= 8:
        for q in range(6):
            ang = q / 6 * math.tau
            ep.bolita(a, CX + math.cos(ang) * (5 + (f_ - 6) * 3), CY + math.sin(ang) * (3 + (f_ - 6) * 2) - (f_ - 6) * 2, 2.5, ep.POLVO)


f, o = marcos(grieta, 26)
d['grieta'] = ho.guardar_efecto(LA, 'grieta', f, o, 26.0 / 1.85)


# El Tapazo al tocar: (CX, CY) = donde toca.
def campanazo(s, a, e, dx, dy, i):
    if e < 6:
        ep.banda(a, CX, CY, 6 + e * 5.0, 5.0 * (1 - e / 7.0) + 1.5, rr.HIERRO, True, e)
    if e < 2:
        estrella(a, CX, CY, (14, 9)[e], rr.HIERRO)
    if e < 5:
        ep.chispas(a, CX, CY, rr.NARANJA, e * 7 + i, 5)


f, o = filas_dir(campanazo, 6)
d['campanazo'] = ho.guardar_efecto(LA, 'campanazo', f, o, 14.0)


# La chatarra que salta hacia donde empuja, cae y se queda un momento: (CX, CY) = los pies del que recibe.
def trozos_de(i):
    dx, dy = DIRS[i]
    rnd = random.Random(4 + i)
    return [(math.atan2(dy, dx) + rnd.uniform(-0.9, 0.9), rnd.uniform(12, 30), rnd.uniform(8, 18), rnd.uniform(0, 6), rnd.random() < 0.6) for _ in range(9)]


TROZOS = [trozos_de(i) for i in range(5)]


def chatarra(s, a, e, dx, dy, i):
    for ang, dist, sube, gi, es_t in TROZOS[i]:
        k = min(1.0, (e + 1) / 6.0)
        x = CX + math.cos(ang) * dist * k
        y = CY + math.sin(ang) * dist * k * 0.8 - sube * 4 * k * (1 - k)
        if seco(e, 9, 4) <= 0:
            continue
        if es_t:
            rr.tornillo(a if k < 1 else s, x, y, gi + (0 if k >= 1 else e * 1.5), rr.HIERRO)
        else:
            punto(a if k < 1 else s, x, y, rr.OXIDO[1], 2)
            punto(a if k < 1 else s, x, y, rr.OXIDO[2], 1)


f, o = filas_dir(chatarra, 16)
d['chatarra'] = ho.guardar_efecto(LA, 'chatarra', f, o, 14.0)


# El Frente blindado: chispas de la tapa hacia quien pega, y el brillo de metal en el borde. (CX, CY) = donde toca.
def chispas(s, a, e, dx, dy, i):
    if e < 2:
        estrella(a, CX, CY, (10, 6)[e], rr.HIERRO)
    if e < 3:
        for j in range(-5, 6):
            punto(a, CX - dy * j, CY + dx * j, rr.HIERRO[3] if abs(j) < 3 else rr.HIERRO[2])
    rnd = random.Random(9)
    for q in range(7):
        ang = math.atan2(dy, dx) + rnd.uniform(-0.8, 0.8)
        dist = 3 + e * rnd.uniform(3, 5)
        cometa_dir(a, CX + math.cos(ang) * dist, CY + math.sin(ang) * dist * 0.8 - math.sin(e * 0.5) * 3, math.cos(ang), math.sin(ang) * 0.8, 5, 0, rr.NARANJA)


f, o = filas_dir(chispas, 6)
d['chispas'] = ho.guardar_efecto(LA, 'chispas', f, o, 14.0)

# La Furia de Rey: va pegada a su sprite, una por nivel; el hocico se mide en su dibujo.
for nivel in (1, 2, 3):
    filas, origenes = [], []
    for fila in range(5):
        m, _t = rr.furia(nivel, fila)
        filas.append(m)
        origenes.append(sl.ORIGEN)
    d['furia_%d' % nivel] = ho.guardar_efecto(LA, 'furia_%d' % nivel, filas, origenes, 10.0, True)
ho.sumar(LA, d)
