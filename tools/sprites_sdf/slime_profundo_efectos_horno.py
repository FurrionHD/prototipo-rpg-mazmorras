#!/usr/bin/env python3
# ============================================================
#  slime_profundo_efectos_horno.py -- HORNEA LOS EFECTOS DEL SLIME PROFUNDO Y SUS MUTANTES (arrecife y escarcha). Su agua, su coral y su
#  hielo llevan su paleta de la lamina (no se tinen). Se suman a las hojas de 'slime'. Lo que cambia en cada pelea va por codigo:
#  los tentaculos los pinta TentaculosPixel, la neblina su shader y cada carambano cae donde diga ProfundoAire.
#    python tools/sprites_sdf/slime_profundo_efectos_horno.py
# ============================================================
import numpy as np

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO GRANDE (el Chorro mide 110): antes de traer nada mas, que las demas piezas lo cojan ya.
W, H = 300, 260
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import slime_veneno_efectos_pixel as vn  # noqa: E402
import slime_fuego_efectos_pixel as fg  # noqa: E402
import slime_profundo_efectos_pixel as pr  # noqa: E402
import horno_efectos as ho  # noqa: E402
from slime_efectos_pixel import nuevo  # noqa: E402

for m_ in (sl, vn, fg, pr):
    m_.victima = lambda a, x, y: None
    m_.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'slime'
CX, CY = W // 2, H // 2
CARGA_SALTO = 12      # los marcos de salto de pr.salto(), que en el juego hace su cuerpo


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
# (corte + fps2: lo que llega al golpe, al ritmo de ProfundoAire; lo que queda despues, sin prisa)
f, o = uno(pr.marea, desde=CARGA_SALTO)
d['marea'] = ho.guardar_efecto(LA, 'marea', f, o, 6.0 / 0.32, False, 6, 14.0)
f, o = por_dirs(pr.chorro, escala=1.0)
d['chorro'] = ho.guardar_efecto(LA, 'chorro', f, o, 4.0 / 0.16, False, 4, 14.0)
f, o = por_dirs(pr.coral, desde=3, desde_borde=True)
d['coral'] = ho.guardar_efecto(LA, 'coral', f, o, 6.0 / 0.22, False, 6, 14.0)
f, o = uno(pr.estallido, desde=CARGA_SALTO)
d['estallido'] = ho.guardar_efecto(LA, 'estallido', f, o, 5.0 / 0.2, False, 5, 14.0)
f, o = por_dirs(pr.aliento, desde=2, escala=1.0)
d['aliento'] = ho.guardar_efecto(LA, 'aliento', f, o, 7.0 / 0.32, False, 7, 14.0)
# Un carambano: rompe en el marco 5, que ha de coincidir con ProfundoAire.T_MARCA + T_CAE; su escarcha llena el circulo de su huella.
d['carambano'] = ho.guardar_efecto(LA, 'carambano', marcos(lambda s, a, e: pr.carambano(s, a, CX, CY, e, 0, 13.0), 17), [(CX, CY)], 5.0 / 0.42, False, 5, 14.0)
# Donde pica la anemona: (CX, CY) = el sitio; lo que estira lo pinta TentaculosPixel.
d['pica'] = ho.guardar_efecto(LA, 'pica', marcos(lambda s, a, f_: pr.pinchazo(a, (CX, CY + 10), f_ + 5), 11), [(CX, CY)], 14.0)
f, o = uno(pr.helada)
d['helada'] = ho.guardar_efecto(LA, 'helada', f, o, 12.0)
ho.sumar(LA, d)
