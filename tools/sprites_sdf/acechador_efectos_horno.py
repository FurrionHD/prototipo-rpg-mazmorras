#!/usr/bin/env python3
# ============================================================
#  acechador_efectos_horno.py -- HORNEA LOS EFECTOS DEL ACECHADOR NORMAL (y de la Sombra sin rostro, que pega con su mismo
#  kit), los de su lamina aprobada (20/11/2026: "si estan bien, puedes meterlos en el juego",
#  tools/sprites_sdf/acechador_normal_efectos_pixel.py), SIN REJILLA (transparencia de verdad). La receta del chillon.
#  SOBRE QUIEN RECIBE, (CX, CY) = sus pies:
#    fauces         5 dirs: el basico, las fauces que se cierran y el destello (sin sangre)
#    fauces_sangre  5 dirs: el bocado de la Yugular y de la Dentellada, con la sangre que salta
#    zarpa_i/zarpa_d los tres zarpazos de cada mano del Zarpazo doble
#  DESDE DONDE SALTA, (CX, CY) = sus pies al despegar:
#    estela         5 dirs: la estela oscura del Salto a la yugular, en arco por encima del lomo
#  EL OLOR A SANGRE (lo que viaja, EfectoPixel.poner_vuelo; de quien sangra a su hocico):
#    olor / olor_entra  la mota roja en vuelo, y al llegar
#    python tools/sprites_sdf/acechador_efectos_horno.py
# ============================================================
import math

import acechador_normal_efectos_pixel as an     # (trae su lienzo: va antes que los demas)
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import horno_efectos as ho
import transparencia as tr
from slime_efectos_pixel import nuevo

LA = 'acechador'
W, H = an.W, an.H
CX, CY = W // 2, H // 2 + 20
MODS = [ep, sl, rt, an]


def guardar(nombre, gen, fps, n_filas=1, bucle=False, origen=None):
    filas = tr.filas_con_alfa(gen, MODS)
    return ho.guardar_efecto(LA, nombre, filas, [origen or (CX, CY)] * n_filas, fps, bucle)


def g_fauces(con_sangre):
    def gen():
        filas = []
        for fila in range(5):
            dx, dy = an.DIRS[fila]
            g = an.sangre(10, 7 + fila, math.atan2(dy, dx), (1.2, 2.2))
            out = []
            for f in range(14 if con_sangre else 6):
                s, a = nuevo(), nuevo()
                if f < 5:
                    an.bocado(s, a, (CX, CY), dx, dy, min(f, 4))
                if con_sangre and f >= 3:
                    g.pintar(s, a, CX, CY - 4, min(1.0, (f - 3) / 7.0), 2.0, 1.0, f - 11)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_zarpa(lado):
    def gen():
        out = []
        for e in range(8):
            s, a = nuevo(), nuevo()
            an.zarpa(a, (CX, CY), 1.0, 0.0, e, lado)
            out.append((s, a))
        return [out]
    return gen


def g_estela():
    L = 58.0 / an.UNIDAD

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = an.DIRS[fila]
            out = []
            corre = 6
            for f in range(corre + 6):
                s, a = nuevo(), nuevo()
                u = min(1.0, max(0.0, (f - 1) / float(corre - 1)))
                x, y = CX + dx * L * 0.7 * u, CY + dy * L * 0.7 * u
                if f >= 2:
                    an.estela_salto(s, s, (CX, CY), x, y, dx, dy, f)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_olor():
    s, a = nuevo(), nuevo()
    an.disco(a, CX, CY, 1.8, an.OLOR[2])
    an.disco(a, CX - 0.5, CY - 0.5, 0.9, an.OLOR[3])
    return [[(s, a)]]


def g_olor_entra():
    out = []
    for r, col in ((1.4, an.OLOR[2]), (0.9, an.OLOR[1])):
        s, a = nuevo(), nuevo()
        an.disco(a, CX, CY, r, col)
        out.append((s, a))
    return [out]


def principal():
    d = {}
    d['fauces'] = guardar('fauces', g_fauces(False), 16.0, 5)
    d['fauces_sangre'] = guardar('fauces_sangre', g_fauces(True), 14.0, 5)
    d['zarpa_i'] = guardar('zarpa_i', g_zarpa(-1), 16.0)
    d['zarpa_d'] = guardar('zarpa_d', g_zarpa(1), 16.0)
    d['estela'] = guardar('estela', g_estela(), 14.0, 5)
    d['olor'] = guardar('olor', g_olor, 10.0)
    d['olor_entra'] = guardar('olor_entra', g_olor_entra, 10.0)
    ho.apuntar(LA, d)


if __name__ == '__main__':
    principal()
