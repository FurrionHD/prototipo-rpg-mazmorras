#!/usr/bin/env python3
# ============================================================
#  chillon_efectos_horno.py -- HORNEA LOS EFECTOS DEL CHILLON Y SUS MUTANTES, los de su lamina aprobada (18/11/2026: "si la
#  verdad que estan bien", tools/sprites_sdf/chillon_efectos_pixel.py), SIN REJILLA (transparencia de verdad: 4 pasadas,
#  alfa en 4 escalones). La receta de chupasimas_efectos_horno.py.
#  EN EL SUELO (los pinta SueloRoto, centrados en su forma):
#    sombra70 / sombra45   el CHILLIDO DE OSCURIDAD (C3 MAREA): la sombra con el borde vivo, remolinos y gotas de tinta,
#                          y se recoge en el. Origen = el centro del circulo (sus pies). 70 el Apagaluces y la Piña, 45 la cria
#    cono                  5 dirs: las ondas del CHILLIDO normal (cono de 60 y 100 grados). Origen = el vertice (su boca)
#  SOBRE QUIEN RECIBE, (CX, CY) = sus pies:
#    paletos               5 dirs: los dos paletos del basico y del Picado, que entran por la linea del mordisco
#    oidos                 los oidos en blanco del Chillido normal (fogonazo y rayitas que tiemblan)
#    farol                 A OSCURAS: su lucecita tiembla, se encoge y se apaga echando humo
#  LO QUE VIAJA (EfectoPixel.poner_vuelo: la distancia la dice cada pelea), de quien se apaga al bicho (Bebe la luz):
#    mota / mota_entra     la mota de luz en vuelo, y al llegar: se encoge y entra
#    python tools/sprites_sdf/chillon_efectos_horno.py
# ============================================================
import math

import chillon_efectos_pixel as cp      # (trae su lienzo: va antes que los demas)
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import horno_efectos as ho
import transparencia as tr
from slime_efectos_pixel import nuevo

LA = 'chillon'
W, H = cp.W, cp.H
CX, CY = W // 2, H // 2 + 10
MODS = [ep, sl, rt, cp]
# Los frames de la lamina: el chillido arranca en su f=2 (pieza(..., f - 2)); aqui desde el 0.
T_SOMBRA = cp.NACE + cp.QUIETA + cp.RECOGE + 1


def guardar(nombre, gen, fps, n_filas=1, bucle=False, origen=None):
    filas = tr.filas_con_alfa(gen, MODS)
    return ho.guardar_efecto(LA, nombre, filas, [origen or (CX, CY)] * n_filas, fps, bucle)


def g_sombra(radio_mundo):
    R = radio_mundo / cp.UNIDAD

    def gen():
        out = []
        for e in range(T_SOMBRA):
            s, a = nuevo(), nuevo()
            cp.sombra_viva(s, CX, CY, R, e, 'C3', 3)
            out.append((s, a))
        return [out]
    return gen


def g_cono():
    R = 60.0 / cp.UNIDAD
    mitad = math.radians(100.0) * 0.5

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = cp.DIRS[fila]
            eje = math.atan2(dy, dx)
            out = []
            for f in range(14):
                s, a = nuevo(), nuevo()
                cp.ondas_cono(a, CX, CY, eje, R, mitad, f)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_paletos():
    def gen():
        filas = []
        hx, hy = cp.cabeza_v((CX, CY))
        for fila in range(5):
            dx, dy = cp.DIRS[fila]
            L = max(1e-3, math.hypot(dx, dy))
            out = []
            for e in range(6):
                s, a = nuevo(), nuevo()
                cp.paletos(a, hx, hy, dx / L, dy / L, e)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_oidos():
    hx, hy = cp.cabeza_v((CX, CY))
    out = []
    for e in range(7):
        s, a = nuevo(), nuevo()
        cp.oidos(a, hx, hy, e)
        out.append((s, a))
    return [out]


def g_farol():
    hx, hy = cp.cabeza_v((CX, CY))
    out = []
    for e in range(12):
        s, a = nuevo(), nuevo()
        cp.farol(a, hx, hy, e)
        out.append((s, a))
    return [out]


def g_mota():
    s, a = nuevo(), nuevo()
    cp.punto(a, CX, CY, cp.LUZ_FAROL[3], 2)
    return [[(s, a)]]


def g_mota_entra():
    out = []
    for col in (cp.LUZ_FAROL[2], cp.LUZ_FAROL[1]):
        s, a = nuevo(), nuevo()
        cp.punto(a, CX, CY, col, 1)
        out.append((s, a))
    return [out]


def principal():
    d = {}
    d['sombra70'] = guardar('sombra70', g_sombra(70.0), 12.0)
    d['sombra45'] = guardar('sombra45', g_sombra(45.0), 12.0)
    d['cono'] = guardar('cono', g_cono(), 14.0, 5)
    d['paletos'] = guardar('paletos', g_paletos(), 12.0, 5)
    d['oidos'] = guardar('oidos', g_oidos, 14.0)
    d['farol'] = guardar('farol', g_farol, 12.0)
    d['mota'] = guardar('mota', g_mota, 12.0)
    d['mota_entra'] = guardar('mota_entra', g_mota_entra, 12.0)
    ho.apuntar(LA, d)


if __name__ == '__main__':
    principal()
