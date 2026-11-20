#!/usr/bin/env python3
# ============================================================
#  acechador_mut_efectos_horno.py -- HORNEA LOS EFECTOS DE LOS MUTANTES DEL ACECHADOR (20/11/2026), los elegidos por el
#  jefe en tools/sprites_sdf/acechador_efectos_lamina.py, SIN REJILLA. Se SUMAN a las hojas del acechador (las del normal
#  las hornea acechador_efectos_horno.py; cada lamina tiene su lienzo y por eso van en dos hornos).
#    marca                (bucle) la MARCA DE LA LUNA (B): la creciente grande con su resplandor y motas, sobre la cabeza.
#                         Origen = lo alto de la cabeza del marcado
#    media_luna           5 dirs: la MEDIA LUNA (A), la hoja de luna en arco de 150 grados. Origen = su frente
#    charco_sombra / charco_cazador   FUNDIRSE (A): el charco de humo (violeta / niebla azul) que sube en bocanadas y se
#                         deshace. Origen = sus pies
#    emerge_sombra / emerge_cazador   EMERGER (A): los ojos que se encienden en el charco (ambar / hielo) y el charco que
#                         se abre. Origen = sus pies
#    python tools/sprites_sdf/acechador_mut_efectos_horno.py
# ============================================================
import math

import acechador_efectos_lamina as la     # (trae su lienzo: va antes que los demas)
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import horno_efectos as ho
import transparencia as tr
from slime_efectos_pixel import nuevo

LA = 'acechador'
W, H = la.W, la.H
CX, CY = W // 2, H // 2 + 20
MODS = [ep, sl, rt, la]
VARIANTES = {'sombra': la.SOMBRA_V, 'cazador': la.CAZ}


def guardar(nombre, gen, fps, n_filas=1, bucle=False, origen=None):
    filas = tr.filas_con_alfa(gen, MODS)
    return ho.guardar_efecto(LA, nombre, filas, [origen or (CX, CY)] * n_filas, fps, bucle)


def g_marca():
    out = []
    for f in range(16):
        s, a = nuevo(), nuevo()
        la.marca_b(a, CX, CY + 14, f)   # marca_b la pone 14 por encima de lo que se le pasa
        out.append((s, a))
    return [out]


def g_media_luna():
    filas = []
    for fila in range(5):
        dx, dy = la.DIRS[fila] if hasattr(la, 'DIRS') else sl.DIRS[fila]
        out = []
        for f in range(4, 15):
            s, a = nuevo(), nuevo()
            la.media_luna(a, s, CX, CY, f, 'A', math.atan2(dy * 0.8, dx))
            out.append((s, a))
        filas.append(out)
    return filas


def g_charco(var):
    def gen():
        out = []
        n = 10
        for f in range(20):
            s, a = nuevo(), nuevo()
            nivel = min(1.0, f / 6.0) * (1.0 if f < n + 2 else max(0.0, 1 - (f - n - 2) / 8.0))
            la._charco(s, a, var, CX, CY, nivel, f)
            out.append((s, a))
        return [out]
    return gen


def g_emerge(var):
    def gen():
        out = []
        ojo = (CX + 8, CY - 3)
        for f in range(10):
            s, a = nuevo(), nuevo()
            if f < 3:
                la._charco(s, a, var, CX, CY, 1.0 - f * 0.1, f, sube=False)
                la._par_ojos(a, var, ojo[0], ojo[1], (f + 1) / 3.0)
            else:
                e = f - 3
                nivel = max(0.0, 1 - e / 6.0)
                rx = 34 + e * 8
                d = ((la.XX - CX) / rx) ** 2 + ((la.YY - CY) / (rx * 0.38)) ** 2
                la.mezcla(s, (d <= 1) & (d > 0.5), la.HUMO[var][1], 0.75 * nivel)
                la._charco(s, a, var, CX, CY, nivel * 0.8, f)
            out.append((s, a))
        return [out]
    return gen


def principal():
    d = {}
    d['marca'] = guardar('marca', g_marca, 10.0, bucle=True)
    d['media_luna'] = guardar('media_luna', g_media_luna, 18.0, 5)
    for nom, var in VARIANTES.items():
        d['charco_' + nom] = guardar('charco_' + nom, g_charco(var), 12.0)
        d['emerge_' + nom] = guardar('emerge_' + nom, g_emerge(var), 14.0)
    ho.sumar(LA, d)


if __name__ == '__main__':
    principal()
