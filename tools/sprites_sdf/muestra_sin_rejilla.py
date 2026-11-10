#!/usr/bin/env python3
# ============================================================
#  muestra_sin_rejilla.py -- LA MUESTRA DE LA TRANSPARENCIA DE VERDAD (10/11/2026, memoria transparencia-de-verdad):
#  el slime venenoso (mucho gas) ANTES (trama) y AHORA (4 escalones de alfa), fila con fila, para compararlos.
#    python tools/sprites_sdf/muestra_sin_rejilla.py -> Desktop/ataques_mapa/efectos_pixel/slime_venenoso_sin_rejilla.png
# ============================================================
import os

import slime_veneno_efectos_pixel as sv
import slime_efectos_pixel as sl
import escarabajo_efectos_pixel as ep
import transparencia as tr

MODS = [sv, sl, ep]


def principal():
    filas = []
    casos = [
        ('ROCIADA CORROSIVA', sv.rociada, (1,), (3, 4, 5, 7, 9, 17)),
        ('EXHALAR MIASMA', sv.exhalar, (sv.MIASMA, 50.0), (3, 6, 8, 10, 14, 22)),
        ('ESCUPITAJO TOXICO', sv.escupitajo, (1,), (4, 6, 8, 9, 11, 18)),
        ('MIASMA (cuerpo)', sv.humo_cuerpo, (sv.MIASMA, False), (0, 2, 4, 6, 9, 12)),
    ]
    for nombre, fn, args, idx in casos:
        antes = fn(*args)
        ahora = tr.con_alfa(fn, MODS, *args)
        filas.append((nombre + '\nANTES (trama)', sl.elegir(antes[0], idx)))
        filas.append((nombre + '\nAHORA (sin rejilla)', sl.elegir(ahora[0], idx)))
    ruta = os.path.join(sl.SALIDA, 'slime_venenoso_sin_rejilla.png')
    sl.lamina(filas, ruta)
    print(ruta)


if __name__ == '__main__':
    principal()
