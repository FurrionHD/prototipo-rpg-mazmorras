#!/usr/bin/env python3
# ============================================================
#  jabali_efectos_horno.py -- HORNEA LOS EFECTOS DEL JABALI Y SUS MUTANTES (Colmillo de cristal y Jabali ancestral). Cada cosa con su paleta
#  de la lamina. La bola del reflejo la lleva EfectoPixel.poner_vuelo. EL FUEGO DE LA QUEMA LO TRAE SU SPRITE: aqui solo el humo.
#    python tools/sprites_sdf/jabali_efectos_horno.py
# ============================================================
import math
import random

import escarabajo_efectos_pixel as ep
import jabali_efectos_pixel as jb       # (trae el lienzo grande: va antes que los demas)
import slime_efectos_pixel as sl
import slime_veneno_efectos_pixel as vn
import rata_efectos_pixel as rt
import horno_efectos as ho
import numpy as np
from slime_efectos_pixel import nuevo, estrella, punto, disco, cometa_dir, cristal, seco

sl.victima = rt.victima = vn.victima = jb.victima = ep.victima = lambda a, x, y: None
rt.escena = jb.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'jabali'
W, H = jb.W, jb.H
CX, CY = W // 2, H // 2
DIRS = sl.DIRS[:5]
ORIGENES = [(CX, CY)] * 5
CIAN = jb.CIAN


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


# El colmillazo del basico: (CX, CY) = los pies del que recibe.
def colmillo(s, a, e, dx, dy, i):
    px, py = jb.enganche(a, CX, CY - 9, dx, dy, 10.0, e, 5)
    if e in (2, 3):
        estrella(a, px, py, 7, jb.HUESO)


f, o = filas_dir(colmillo, 5)
d['colmillo'] = ho.guardar_efecto(LA, 'colmillo', f, o, 14.0)
f, o = por_dirs(jb.cornada, desde=4)
d['cornada'] = ho.guardar_efecto(LA, 'cornada', f, o, 12.0)


# El choque de la Embestida: el frente y el chorro de polvo hacia donde sale despedido.
def choque(s, a, e, dx, dy, i):
    if e < 2:
        estrella(a, CX, CY - 9, (12, 8)[e], jb.HUESO)
    k = e / 8.0
    for q in range(5):
        ep.bolita(s, CX - dx * q * 3 + dy * q, CY - dy * q * 3 - dx * q - k * 3, 3.5 * (1 - k) + 0.4, jb.POLVO)


f, o = filas_dir(choque, 8)
d['choque'] = ho.guardar_efecto(LA, 'choque', f, o, 16.0)
f, o = por_dirs(jb.embestida, con_choque=False)
d['surco'] = ho.guardar_efecto(LA, 'surco', f, o, 8.0 / 0.2, False, 8, 16.0)
m_, _t = jb.pisoton(0, con_objetivos=False)
d['pisoton'] = ho.guardar_efecto(LA, 'pisoton', [m_[4:]], [sl.ORIGEN], 7.0 / 0.2, False, 7, 12.0)


# El surco de esquirlas de la Cornada de cristal, a su largo (la de la rata mide otro).
def surco_de(largo_mundo):
    L = largo_mundo / jb.UNIDAD
    filas, corre = [], 6
    for i, (dx, dy) in enumerate(DIRS):
        rnd = random.Random(7 + i)
        clavadas = [(rnd.uniform(0.0, 1.0), rnd.uniform(-7.0, 7.0), rnd.uniform(5.0, 9.0), rnd.uniform(-0.5, 0.5)) for _ in range(12)]
        fila = []
        for f_ in range(corre + 14):
            s, a = nuevo(), nuevo()
            u = min(1.0, (f_ + 1) / float(corre))
            for uu, lado, alto, incl in clavadas:
                if uu > u:
                    continue
                queda = seco(f_ - uu * corre, 8, 5)
                tmp = nuevo()
                n = math.hypot(incl, 1.0)
                px, py = CX + dx * L * uu - dy * lado, CY + dy * L * uu + dx * lado
                cristal(tmp, px, py - alto * 0.5, incl / n, -1.0 / n, alto, 1.7, CIAN)
                mas = (tmp[:, :, 3] > 0) & (jb.TRAMA < queda)
                s[mas] = tmp[mas]
            fila.append((s, a))
        filas.append(fila)
    return filas, ORIGENES


for largo in (50, 60):
    f, o = surco_de(float(largo))
    d['surco_%d' % largo] = ho.guardar_efecto(LA, 'surco_%d' % largo, f, o, 6.0 / 0.2, False, 6, 14.0)

# Se le parten los colmillos: (CX, CY) = el morro.
_rnd = random.Random(19)
LLUVIA = [(_rnd.uniform(0, math.tau), _rnd.uniform(8, 24), _rnd.uniform(10, 22)) for _ in range(12)]


def estallido(s, a, e):
    if e < 2:
        estrella(a, CX, CY, (16, 10)[e], CIAN)
    k = min(1.0, (e + 1) / 7.0)
    for ang, dist, sube in LLUVIA:
        if e < 11:
            px = CX + math.cos(ang) * dist * k
            py = CY + math.sin(ang) * dist * 0.7 * k - sube * 4 * k * (1 - k) + k * 6
            cristal(a, px, py, math.cos(ang + e), math.sin(ang + e), 5, 1.4, CIAN)


f, o = marcos(estallido, 11)
d['estallido'] = ho.guardar_efecto(LA, 'estallido', f, o, 11.0)
m_, _t = jb.esporas(0, radio_mundo=40.0)
d['esporas'] = ho.guardar_efecto(LA, 'esporas', [m_], [sl.ORIGEN], 20.0 / 1.6)


# El reflejo: el destello en el morro, la bola cian (la mueve el codigo) y donde le da.
def bola(s, a, f_, dx, dy, i):
    cometa_dir(a, CX, CY, dx, dy, 16, 2, CIAN)
    disco(a, CX, CY, 4.2, CIAN[0])
    disco(a, CX, CY, 3.2, CIAN[2])
    disco(a, CX - 1, CY - 1, 1.6, CIAN[3])


def llega(s, a, e):
    if e < 2:
        estrella(a, CX, CY, (14, 8)[e], CIAN)
    for q in range(6):
        ang = q / 6 * math.tau
        punto(a, CX + math.cos(ang) * (3 + e * 2.2), CY + math.sin(ang) * (2 + e * 1.5) + e, CIAN[2], 2)


f, o = marcos(lambda s, a, f_: estrella(a, CX, CY, (10, 18, 12)[f_], CIAN), 3)
d['reflejo_sale'] = ho.guardar_efecto(LA, 'reflejo_sale', f, o, 3.0 / 0.18)
f, o = filas_dir(bola, 1)
d['reflejo_bola'] = ho.guardar_efecto(LA, 'reflejo_bola', f, o, 10.0)
f, o = marcos(llega, 6)
d['reflejo_llega'] = ho.guardar_efecto(LA, 'reflejo_llega', f, o, 12.0)
# La quema: solo el humo que sale de donde arde su dibujo; una fila por direccion, medido en cada una.
f, o = por_dirs(jb.quema)
d['quema'] = ho.guardar_efecto(LA, 'quema', f, o, 10.0)
ho.sumar(LA, d)
