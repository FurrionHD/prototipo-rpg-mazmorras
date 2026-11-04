#!/usr/bin/env python3
# ============================================================
#  slime_efectos_horno.py -- HORNEA LOS EFECTOS DEL SLIME NORMAL Y SUS MUTANTES (los de la lamina slime_efectos_pixel.py).
#  El gel va en INDICES: rojo puro 40/80/120/160 (sus cuatro tonos) y 200 (el borde), y el shader de EfectoPixel le pone el
#  color de cada slime. Asi la misma hoja vale para todos, en todas las pantallas y sin mandar nada por red.
#    python tools/sprites_sdf/slime_efectos_horno.py
# ============================================================
import slime_efectos_pixel as sl
import horno_efectos as ho

sl.GEL = [(40, 0, 0), (80, 0, 0), (120, 0, 0), (160, 0, 0)]
sl.GEL_BORDE = (200, 0, 0)
sl.victima = lambda a, x, y: None
sl.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'slime'
OBSIDIANA = [(30, 24, 44), (66, 56, 92), (134, 122, 176), (232, 226, 255)]   # (la de slime_fuego_efectos_pixel)


def por_dirs(funcion, *args, desde=0):
    filas, origenes = [], []
    for d in range(5):
        m, _t = funcion(d, *args)
        filas.append(m[desde:])
        origenes.append(sl.ORIGEN)
    return filas, origenes


def uno(funcion, *args, desde=0):
    m, _t = funcion(*args)
    return [m[desde:]], [sl.ORIGEN]


d = {}
f, o = por_dirs(sl.basico, 's100', 36.0, desde=3)
d['golpe'] = ho.guardar_efecto(LA, 'golpe', f, o, 14.0)
# El Placaje: los primeros marcos los corre con el cuerpo (T_PLACAJE 0,2 s); el rastro se seca sin prisa.
f, o = por_dirs(sl.placaje, 40.0, 16.0, 's100')
d['placaje_c'] = ho.guardar_efecto(LA, 'placaje_c', f, o, 25.0, False, 6, 11.0)
f, o = por_dirs(sl.placaje, 70.0, 41.0, 'mut120')
d['placaje_g'] = ho.guardar_efecto(LA, 'placaje_g', f, o, 25.0, False, 6, 11.0)
# Los coletazos: cada pase, T_ENTRE (0,2 s).
f, o = por_dirs(sl.embate, 2, 100.0, 's100')
d['embate_2'] = ho.guardar_efecto(LA, 'embate_2', f, o, 25.0)
f, o = por_dirs(sl.embate, 3, 120.0, 'mut120')
d['embate_3'] = ho.guardar_efecto(LA, 'embate_3', f, o, 25.0)
# El Reventon: desde que toca (se hincha y salta con su gesto).
f, o = uno(sl.reventon, 1, 35.0, 's100', desde=12)
d['splat_35'] = ho.guardar_efecto(LA, 'splat_35', f, o, 14.0)
f, o = uno(sl.reventon, 1, 46.0, 'evo2', desde=12)
d['splat_46'] = ho.guardar_efecto(LA, 'splat_46', f, o, 14.0)
f, o = uno(sl.puas, 'pun120', 56.0, desde=6)
d['puas'] = ho.guardar_efecto(LA, 'puas', f, o, 14.0)
sl.CRISTAL = OBSIDIANA
f, o = uno(sl.puas, 'obs211', 60.0, desde=6)
d['puas_obs'] = ho.guardar_efecto(LA, 'puas_obs', f, o, 14.0)
ho.apuntar(LA, d)
