#!/usr/bin/env python3
# ============================================================
#  arana_efectos_horno.py -- HORNEA LOS EFECTOS DE LA ARANA Y SUS MUTANTES (Tejedora y Tormentosa), y los contadores de cargas (y los
#  puntos de la costra del Trent, que son los mismos en ambar). Cada cosa con su paleta de la lamina. Los rayos que unen dos puntos que
#  cambian en cada pelea (el rebote, el hilo al rojo) los pinta RayoPixel con sus quiebros.
#    python tools/sprites_sdf/arana_efectos_horno.py
# ============================================================
import math
import random

import numpy as np

import escarabajo_efectos_pixel as ep
import arana_efectos_pixel as ar       # (trae su lienzo: va antes que los demas)
import slime_efectos_pixel as sl

import horno_efectos as ho
from slime_efectos_pixel import nuevo, estrella, punto, disco, gota, Gotas, charco, seco

sl.victima = ar.victima = ep.victima = lambda a, x, y: None
ar.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'arana'
W, H = ar.W, ar.H
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


def uno(funcion, *args, desde=0, **kw):
    m, _t = funcion(*args, **kw)
    return [m[desde:]], [sl.ORIGEN]


d = {}


# --- SOBRE EL CUERPO: (CX, CY) = los pies del que recibe. Los queliceros se cierran en el marco 3 ---
def queliceros(s, a, e, dx, dy, i):
    if e < 5:
        ar.queliceros(a, CX, CY - 10, dx, dy, e)
    if e == 3:
        estrella(a, CX, CY - 10, 8, ar.HUESO)


f, o = filas_dir(queliceros, 7)
d['queliceros'] = ho.guardar_efecto(LA, 'queliceros', f, o, 14.0)
f, o = filas_dir(lambda s, a, e, dx, dy, i: ar.veneno(s, a, (CX, CY), dx, dy, e), 10)
d['veneno'] = ho.guardar_efecto(LA, 'veneno', f, o, 12.0)

# --- LA TELARANA: el ovillo que vuela (lo mueve el codigo) y la red que se queda ---
R_RED = 25.0 / ar.UNIDAD * 1.1


def ovillo(s, a, e):
    r = 4.0
    disco(a, CX, CY, r + 0.7, ar.SEDA[0])
    disco(a, CX, CY, r, ar.SEDA[2])
    disco(a, CX - 1, CY - 1, r * 0.5, ar.SEDA[3])
    for k in range(4):
        ang = k * 1.57 + e * 0.6
        for q in range(int(r), int(r + 3) + 2):
            punto(a, CX + math.cos(ang) * q, CY + math.sin(ang) * q, ar.SEDA[1])


f, o = marcos(ovillo, 4)
d['ovillo'] = ho.guardar_efecto(LA, 'ovillo', f, o, 12.0, True)


def red_sale(s, a, g):
    ar.red(s, CX, CY, R_RED * (1.0 - (1.0 - min(1.0, (g + 1) / 3.0)) ** 2), 0.0, 3)
    if g < 2:
        estrella(a, CX, CY - 3, (10, 6)[g], ar.SEDA)


f, o = marcos(red_sale, 3)
d['red_sale'] = ho.guardar_efecto(LA, 'red_sale', f, o, 10.0)
f, o = marcos(lambda s, a, g: ar.red(s, CX, CY, R_RED, 0.0, 3), 1)
d['red_dura'] = ho.guardar_efecto(LA, 'red_dura', f, o, 4.0, True)
f, o = marcos(lambda s, a, g: ar.red(s, CX, CY, R_RED, (g + 1) / 9.0, 3), 8)
d['red_vete'] = ho.guardar_efecto(LA, 'red_vete', f, o, 14.0)

# --- LA DESCARGA, LA EXPLOSION Y EL PISOTON DE TRUENO (sus climax van con estas mismas) ---
f, o = uno(ar.descarga, desde=2)
d['descarga'] = ho.guardar_efecto(LA, 'descarga', f, o, 10.0 / 0.75)
f, o = uno(ar.explosion, desde=2, radio_mundo=60.0)
d['explosion'] = ho.guardar_efecto(LA, 'explosion', f, o, 16.0 / 0.8)
f, o = uno(ar.pisoton, desde=5)
d['pisoton'] = ho.guardar_efecto(LA, 'pisoton', f, o, 12.0)


# --- LAS CARGAS: chispazos (tormentosa) o ascuas (tejedora) alrededor del cuerpo, por nivel; el contador va aparte, encima ---
def alrededor(var, fuego, nivel):
    arr = np.array(ar.marco(var, 'idle', 0, 1))
    ys, xs = np.nonzero(arr[:, :, 3] > 40)
    ox, oy = ar.pies(var)
    r = (xs.max() - xs.min()) * 0.45
    cy = (ys.min() + ys.max()) / 2 - oy

    def pinta(s, a, f_):
        rnd = random.Random(nivel)
        if fuego:
            for _ in range(nivel * 5):
                fx, fase = rnd.uniform(-r, r), rnd.random()
                h = (f_ / 10.0 + fase) % 1.0
                punto(a, CX + fx, CY + cy + rnd.uniform(0, 8) - h * 26, ar.BRASA[3] if h < 0.4 else ar.BRASA[1], 2 if h < 0.5 else 1)
        else:
            salto_ = f_ // 2
            r2 = random.Random(salto_ * 3 + nivel)
            for k in range(nivel):
                ang = r2.uniform(0, math.tau)
                x0, y0 = CX + math.cos(ang) * r * 0.6, CY + cy + math.sin(ang) * r * 0.6
                ar.arco(a, x0, y0, x0 + math.cos(ang) * 14, y0 + math.sin(ang) * 11, salto_ + k, 1.2)
    return pinta


for nivel in range(1, 6):
    for nombre, var, fuego in (('chispas', ar.TORMENTOSA, False), ('ascuas', ar.TEJEDORA, True)):
        f, o = marcos(alrededor(var, fuego, nivel), 12)
        d['%s_%d' % (nombre, nivel)] = ho.guardar_efecto(LA, '%s_%d' % (nombre, nivel), f, o, 10.0, True)

# El contador: (CX, CY) = lo alto de su cuerpo. Un circulo por carga, encendidos los que lleva.
for tipo, pal in (('rayo', ar.RAYO), ('brasa', ar.BRASA), ("ambar", [(120, 62, 8), (214, 128, 20), (250, 184, 56), (255, 238, 170)])):
    for tope in range(1, 6):
        for nivel in range(0, tope + 1):
            def cont(s, a, f_, tope=tope, nivel=nivel, pal=pal):
                for k in range(tope):
                    x = CX + (k - (tope - 1) / 2) * 7
                    disco(a, x, CY - 8, 3.0, (14, 12, 16))
                    disco(a, x, CY - 8, 2.1, pal[2] if k < nivel else ar.CARBON[1])
                    if k < nivel:
                        punto(a, x - 1, CY - 9, pal[3])
            f, o = marcos(cont, 1)
            nombre = 'cont_%s_%d_%d' % (tipo, tope, nivel)
            d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 4.0, True)
ho.sumar(LA, d)
