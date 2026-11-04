#!/usr/bin/env python3
# ============================================================
#  slime_abisal_efectos_horno.py -- HORNEA LOS EFECTOS DEL SLIME ABISAL Y SUS MUTANTES (cielo nocturno y mil ojos). Su oscuridad y su
#  luz llevan su paleta de la lamina (no se tinen). Se suman a las hojas de 'slime'. Lo que cambia en cada pelea va por codigo: los
#  rayos los pinta RayoPixel, la bola del Agujero la mueve EfectoPixel.poner_vuelo y cada estrella fugaz cae donde diga AbisalAire.
#    python tools/sprites_sdf/slime_abisal_efectos_horno.py
# ============================================================
import numpy as np

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO GRANDE (el Eclipse del de mil ojos mide 100 de radio): antes de traer nada mas, que las demas piezas lo cojan ya.
W, H = 300, 260
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import slime_veneno_efectos_pixel as vn  # noqa: E402
import slime_fuego_efectos_pixel as fg  # noqa: E402
import slime_abisal_efectos_pixel as ab  # noqa: E402
import horno_efectos as ho  # noqa: E402
from slime_efectos_pixel import nuevo, estrella, gota, punto  # noqa: E402

for m_ in (sl, vn, fg, ab):
    m_.victima = lambda a, x, y: None
    m_.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'slime'
CX, CY = W // 2, H // 2


def por_dirs(funcion, *args, desde=0, **kw):
    filas, origenes = [], []
    for d_ in range(5):
        m, _t = funcion(d_, *args, **kw)
        filas.append(m[desde:])
        origenes.append(sl.ORIGEN)
    return filas, origenes


def uno(funcion, *args, desde=0, **kw):
    m, _t = funcion(*args, **kw)
    return [m[desde:]], [sl.ORIGEN]


def marcos(pintar, n):
    out = []
    for f_ in range(n):
        s, a = nuevo(), nuevo()
        pintar(s, a, f_)
        out.append((s, a))
    return [out]


d = {}
f, o = por_dirs(ab.presion, desde=4)
d['presion'] = ho.guardar_efecto(LA, 'presion', f, o, 14.0)
# La tromba, sobre un objetivo: (CX, CY) = sus pies. Toca el suelo en el marco 3.
d['tromba'] = ho.guardar_efecto(LA, 'tromba', marcos(lambda s, a, e: ab.tromba_en(s, a, CX, CY, e), 16), [(CX, CY)], 14.0)
# La estrella fugaz: toca el suelo en el marco 6, que ha de coincidir con AbisalAire.T_MARCA + T_CAE; su destello, mas rapido.
d['fugaz'] = ho.guardar_efecto(LA, 'fugaz', marcos(lambda s, a, e: ab.fugaz(s, a, CX, CY, e), 16), [(CX, CY)], 6.0 / 0.57, False, 6, 20.0)
# (a su radio de verdad y casi a ras: ha de llenar su huella, que empieza en el borde de su cuerpo)
f, o = por_dirs(ab.parpadeo, desde=2, motas_objetivos=False, escala=1.0, alto_ojo=6.0)
d['parpadeo'] = ho.guardar_efecto(LA, 'parpadeo', f, o, 14.0)
# El radio de la lamina se escala (R = 0,85 del suyo; el remolino, 0,55 x 0,7): aqui ha de llenar su huella.
for nombre, var, radio in (('eclipse', ab.CIELO, 80.0), ('eclipse_mil', ab.OJOS, 100.0)):
    f, o = uno(ab.eclipse, var, radio / 0.85)
    d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 12.0)
for nombre, var, radio in (('agujero', ab.CIELO, 70.0), ('agujero_mil', ab.OJOS, 85.0)):
    f, o = uno(ab.agujero, var, radio / (0.55 * 0.7), desde=5)
    d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 12.0)


# La bolita de noche del Agujero, que lleva el codigo hasta el sitio.
def bola(s, a, f_):
    gota(a, CX, CY, 3.5, ab.NOCHE, ab.NEGRO_BORDE)
    punto(a, CX - 1, CY - 1, ab.LUZ[3] if f_ % 2 == 0 else ab.LUZ[2])


d['agujero_bola'] = ho.guardar_efecto(LA, 'agujero_bola', marcos(bola, 4), [(CX, CY)], 10.0)
# La estrella que deja al moverse: nace en un destello, titila mientras dura y se apaga en otro.
d['estrella_sale'] = ho.guardar_efecto(LA, 'estrella_sale', marcos(lambda s, a, f_: estrella(a, CX, CY - 4, (10, 7)[f_], ab.LUZ), 2), [(CX, CY)], 8.0)
d['estrella_dura'] = ho.guardar_efecto(LA, 'estrella_dura', marcos(lambda s, a, f_: ab.estrella_suelo(s, a, CX, CY, f_), 4), [(CX, CY)], 8.0, True)
d['estrella_vete'] = ho.guardar_efecto(LA, 'estrella_vete', marcos(lambda s, a, f_: estrella(a, CX, CY - 4, (6, 11, 5)[f_], ab.LUZ), 3), [(CX, CY)], 10.0)
ho.sumar(LA, d)
