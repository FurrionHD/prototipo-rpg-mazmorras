#!/usr/bin/env python3
# ============================================================
#  rata_efectos_horno.py -- HORNEA LOS EFECTOS DE LA RATA Y SUS MUTANTES (sombria, drusa y cuarzo ahumado). Cada cosa lleva su paleta de
#  la lamina (no se tinen; el cristal, una hoja por color). Lo que se hace por trozos segun lo lejos que salte va por codigo, en RataAire.
#    python tools/sprites_sdf/rata_efectos_horno.py
# ============================================================
import math

import slime_efectos_pixel as sl
import rata_efectos_pixel as ra
import horno_efectos as ho
from slime_efectos_pixel import W, H, nuevo, estrella, coletazo

sl.victima = ra.victima = lambda a, x, y: None
ra.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'rata'
CX, CY = W // 2, H // 2
DIRS = sl.DIRS[:5]
ORIGENES = [(CX, CY)] * 5


def filas_dir(pintar, n):
    """Una fila por cada una de las 5 direcciones: pintar(s, a, f, dx, dy)."""
    filas = []
    for dx, dy in DIRS:
        fila = []
        for f_ in range(n):
            s, a = nuevo(), nuevo()
            pintar(s, a, f_, dx, dy)
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
V = (CX, CY)
# --- LO DE SOBRE EL CUERPO: (CX, CY) = los pies del que lo recibe ---
# El mordisco: cierra en 3 marcos y muerde en el 3; la sangre sale de ahi.
sangre = {i: ra.Gotas(7, 4 + i, 8.0, 20.0, (math.atan2(DIRS[i][1], DIRS[i][0]), 0.8), sube=(5.0, 12.0), tam=(1.2, 2.0), pal=ra.SANGRE, borde=ra.SANGRE_BORDE) for i in range(5)}


def mordisco(s, a, e, dx, dy):
    ra.bocado(s, a, V, dx, dy, min(e, 4))
    if e >= 3:
        i = DIRS.index((dx, dy))
        sangre[i].pintar(s, a, V[0], V[1] - 2, min(1.0, (e - 3) / 5.0), 2.0, 1.0, e - 8)


f, o = filas_dir(mordisco, 11)
d['mordisco'] = ho.guardar_efecto(LA, 'mordisco', f, o, 14.0)


# Lo del Frenesi sobre el que recibe: los bocados, uno tras otro, y su sangre.
def frenesi(s, a, e, dx, dy):
    if e < 10:
        q = e % 3
        ang = (e // 3) * 2.1
        bx, by = math.cos(ang) * 0.6 + dx * 0.8, math.sin(ang) * 0.6 + dy * 0.8
        n = math.hypot(bx, by)
        ra.mandibula(a, V[0] + math.cos(ang) * 2, V[1] - 9, bx / n, by / n, (4.0, 1.5, 0.0)[q], 4)
    i = DIRS.index((dx, dy))
    sangre[i].pintar(s, a, V[0], V[1] - 4, min(1.0, e / 8.0), 2.0, 1.0, e - 8)


f, o = filas_dir(frenesi, 14)
d['frenesi'] = ho.guardar_efecto(LA, 'frenesi', f, o, 14.0)
f, o = filas_dir(lambda s, a, e, dx, dy: ra.jirones(s, a, V, dx, dy, e), 8)
d['jirones'] = ho.guardar_efecto(LA, 'jirones', f, o, 14.0)
for nombre, pal in (('esq_c', ra.CIAN), ('esq_a', ra.AHUMADO)):
    pinta = ra.esquirlas(pal)
    f, o = filas_dir(lambda s, a, e, dx, dy: pinta(s, a, V, dx, dy, e), 7)
    d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 14.0)


# El corte de cristal al que atraviesa la Embestida.
def corte(pal):
    def pinta(s, a, e, dx, dy):
        coletazo(a, V[0] - dy * 3, V[1] - 9 + dx * 3, math.atan2(dy, dx) + math.pi / 2, 7.0, 0.6, 2.0 * (1 - e / 6.0), -1.0, 4.0 * (1 - e / 7.0) + 1.0, pal, pal[0])
        if e < 2:
            estrella(a, V[0], V[1] - 9, (8, 5)[e], pal)
    return pinta


for nombre, pal in (('corte_c', ra.CIAN), ('corte_a', ra.AHUMADO)):
    f, o = filas_dir(corte(pal), 6)
    d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 14.0)
f, o = marcos(lambda s, a, e: ra.velo(a, V, e), 10)
d['velo'] = ho.guardar_efecto(LA, 'velo', f, o, 12.0)

# --- POR EL SUELO ---
f, o = marcos(lambda s, a, e: ra.polvo_frenesi(s, a, V, 25.0 / ra.UNIDAD, e), 12)
d['polvo'] = ho.guardar_efecto(LA, 'polvo', f, o, 14.0)
f, o = marcos(lambda s, a, e: ra.mancha_sombra(s, V, 25.0 / ra.UNIDAD, e), 14)
d['mancha'] = ho.guardar_efecto(LA, 'mancha', f, o, 14.0)
# El jiron que se queda en el aire por donde pasa el salto del Frenesi en la sombra.
f, o = filas_dir(lambda s, a, e, dx, dy: coletazo(a, CX, CY, math.atan2(dy, dx) + 1.6, 4.0 + e, 0.2, 1.4 * max(0.0, 1.0 - e / 5.0), 1.0, 3.0, ra.NEGRO, ra.NEGRO_BORDE), 5)
d['jiron'] = ho.guardar_efecto(LA, 'jiron', f, o, 10.0)
for nombre, pal in (('anillo_c', ra.CIAN), ('anillo_a', ra.AHUMADO)):
    # (el anillo llega al borde en 4 marcos, lo que dice RataAire.T_ANILLO; se queda sin prisa)
    f, o = marcos(lambda s, a, e: ra.anillo_esquirlas(s, a, V, 40.0 / ra.UNIDAD, e, pal), 12)
    d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 4.0 / 0.26, False, 4, 14.0)
for nombre, var in (('surco_c', ra.DRUSA), ('surco_a', ra.CUARZO)):
    f, o = por_dirs(ra.embestida, var, con_corte=False)
    d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 7.0 / 0.2, False, 7, 16.0)
f, o = por_dirs(ra.destello, desde=5, con_velo=False)
d['destello'] = ho.guardar_efecto(LA, 'destello', f, o, 3.0 / 0.16, False, 3, 14.0)
# El remolino de la Traicion: se abre y se cierra (T_REMOLINO).
f, o = marcos(lambda s, a, e: ra.remolino(s, CX, CY + 2, (8.0 + e * 1.5) if e < 4 else 14.0, e * 0.9, min(1.0, (e + 1) / 3.0) if e < 4 else max(0.0, 1.0 - (e - 3) / 4.0)), 8)
d['remolino'] = ho.guardar_efecto(LA, 'remolino', f, o, 8.0 / 0.32)
ho.sumar(LA, d)
