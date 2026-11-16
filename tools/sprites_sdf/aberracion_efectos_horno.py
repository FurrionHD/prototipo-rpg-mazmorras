#!/usr/bin/env python3
# ============================================================
#  aberracion_efectos_horno.py -- HORNEA LOS EFECTOS DE LA ABERRACION Y SUS MUTANTES, los de su lamina aprobada (13/11/2026:
#  "si mucho mejor", tools/sprites_sdf/aberracion_efectos_pixel.py), SIN REJILLA (transparencia de verdad: 4 pasadas, alfa en
#  4 escalones). Lo que mide lo dice cada pelea (los latigazos, el Chispazo, el Rayo del ojo...) NO va aqui: lo pinta el
#  juego por celdas (CintaPixel, RayoPixel) con las mismas paletas; aqui va todo lo de tamaño fijo.
#  SOBRE QUIEN RECIBE, (CX, CY) = sus pies:
#    latigo_golpe   5 dirs: el destello violeta y el verdugon rojo del azote
#    chispas        el Electrizado que entra: chispazos cortos alrededor y el fogonazo (violeta fuera, cian dentro)
#    vibra          el Alarido que le llega: el sonido le vibra alrededor
#    mirada_ojo     la Mirada del vacio: el ojo negro que se le abre encima y los jirones del Miedo
#  DEL GESTO DE QUIEN LO LANZA (TacticoPixel.al_gesto), origen = el CENTRO DE SU SPRITE, 5 direcciones (+ espejo):
#    cono_mirada    el cono oscuro de la Mirada del vacio, desde su ojo, con motas violetas
#    cono_chispas   la Mirada chispeante de la Masa: el cono lleno de chispas
#  EN EL SUELO, origen = el centro del circulo (sus pies):
#    alarido        5 dirs: los frentes rotos del Alarido, saliendo de sus FAUCES (por eso con direccion)
#    descarga       el anillo de chispas de la Descarga, con el fogonazo en su cuerpo
#    aro_carga      (en bucle) la copia del aro del ojo en el suelo, encendiendose punto a punto (El ojo se abre)
#    aro_estalla    el estallido: el aro hecho anillo de rayos, el fogonazo y el anillo de chispas
#  SOBRE ELLA (origen = el centro de su sprite):
#    carne          la Carne que se cierra: bultos que se hinchan y se hunden
#    grietas        (en bucle) la Luz le corta la cura: rajas doradas que chisporrotean
#  Y LAS PUNTAS: donde esta en su sprite el tentaculo de DELANTE en el golpe (base y Masa) y el OJO (el Ojo de la tormenta),
#  por direccion, en pixeles del lienzo desde su centro -> scripts/fx/aberracion3d_sprites.gd (PUNTAS), para que el juego
#  saque de ahi el latigazo, el Chispazo y el Rayo.
#    python tools/sprites_sdf/aberracion_efectos_horno.py
# ============================================================
import math
import random

import aberracion_efectos_pixel as xe      # (trae su lienzo: va antes que los demas)
import miconido_efectos_pixel as mi
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import ciempies_efectos_pixel as ce
import horno_efectos as ho
import transparencia as tr
from slime_efectos_pixel import nuevo, estrella

LA = 'aberracion'
W, H = xe.W, xe.H
CX, CY = W // 2, H // 2 + 20
MODS = [ce, ep, sl, rt, mi, xe]


def V():
    return (CX, CY)


def guardar(nombre, gen, fps, n_filas=1, bucle=False, origen=None):
    filas = tr.filas_con_alfa(gen, MODS)
    return ho.guardar_efecto(LA, nombre, filas, [origen or (CX, CY)] * n_filas, fps, bucle)


def _filas5(fn, n):
    def gen():
        return [[fn(fila, e) for e in range(n)] for fila in range(5)]
    return gen


def _fila1(fn, n):
    def gen():
        return [[fn(e) for e in range(n)]]
    return gen


# ------------------------------------------------------------
#  SOBRE QUIEN RECIBE
# ------------------------------------------------------------
def latigo_golpe(fila, e):
    s, a = nuevo(), nuevo()
    dx, dy = xe._dir(fila)
    hx, hy = xe.cabeza(V())
    xe.verdugon(a, CX, CY, dx, dy, e)
    if e < 2:
        estrella(a, hx, hy + 7, (10, 6)[e], xe.ALARIDO)
    return (s, a)


def chispas(e):
    s, a = nuevo(), nuevo()
    xe.chispas_en(a, CX, CY - 10, e, 7, 3, 9)
    return (s, a)


def vibra(e):
    s, a = nuevo(), nuevo()
    xe.vibra(a, V(), e)
    return (s, a)


def mirada_ojo(e):
    s, a = nuevo(), nuevo()
    hx, hy = xe.cabeza(V())
    xe.ojo_negro(a, hx, hy - 9, e)
    xe.miedo(a, V(), e - 1)
    return (s, a)


# ------------------------------------------------------------
#  DEL GESTO (el sprite puesto con su centro en A, como hace la lamina)
# ------------------------------------------------------------
A = (CX, CY - 10)


def g_cono(var, chispas_=False):
    R = 120.0 / xe.UNIDAD

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = xe._dir(fila)
            eje = math.atan2(dy * 0.72, dx)
            oj = xe.ojo_de(xe.marco(var, 'mirada', 3, fila), A, dx, dy)
            out = []
            for e in range(12):
                s, a = nuevo(), nuevo()
                if e < 3:
                    estrella(a, oj[0], oj[1], (6, 9, 6)[e], xe.NEGRO if not chispas_ else xe.RAYO)
                if not chispas_:
                    o = (oj[0], oj[1] + 6)
                    mi.abanico(a if dy > -0.2 else s, o[0], o[1], eje, R, 30.0, e, xe.OSCURO)
                    mi.motas(a, o[0] + dx * R * 0.5, o[1] + dy * R * 0.4, e, fila + 9, xe.SONIDO, 7, 0.5, R * 0.3, True)
                else:
                    rnd = random.Random(fila * 13 + e // 2)
                    for k in range(9):
                        if e > 9:
                            break
                        r0 = rnd.uniform(8, R * min(1.0, 0.35 + e / 7.0))
                        aa = eje + rnd.uniform(-math.radians(15), math.radians(15))
                        x, y = oj[0] + math.cos(aa) * r0, oj[1] + 6 + math.sin(aa) * r0 * 0.72 - 4
                        bb = aa + rnd.uniform(-1.4, 1.4)
                        xe.arco(a, x, y, x + math.cos(bb) * 9, y + math.sin(bb) * 7, k * 7 + e // 2, 1.2, amp=2.5, paso=4)
                        if k % 3 == 0:
                            estrella(a, x, y, 4, xe.RAYO)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


# ------------------------------------------------------------
#  EN EL SUELO (el sprite con su ORIGEN -sus pies- en el centro del circulo)
# ------------------------------------------------------------
def g_alarido():
    R = 70.0 / xe.UNIDAD

    def gen():
        filas = []
        for fila in range(5):
            b = xe.boca_de(xe.BASE, 'alarido', fila, 3, (CX, CY))
            out = []
            for f in range(16):
                s, a = nuevo(), nuevo()
                xe.frentes_grito(a, b, R, f, sem=1)
                out.append((s, a))
            filas.append(out)
        return filas
    return gen


def g_descarga():
    R = 70.0 / xe.UNIDAD
    out = []
    for f in range(13):
        s, a = nuevo(), nuevo()
        c = xe.centro(xe.marco(xe.GALVANICA, 'alarido', 3, 1), (CX, CY))
        if f < 2:
            estrella(a, c[0], c[1], (16, 22)[f], xe.RAYO)
        xe.anillo_chispas(a, s, CX, CY, R, f, 7)
        out.append((s, a))
    return [out]


def g_aro_carga():
    R = 70.0 / xe.UNIDAD
    out = []
    for f in range(10):
        s, a = nuevo(), nuevo()
        xe.aro_suelo(s, a, CX, CY, R, int(round(16 * (f + 1) / 10)), True)
        out.append((s, a))
    return [out]


def g_aro_estalla():
    R = 70.0 / xe.UNIDAD
    out = []
    for e in range(12):
        s, a = nuevo(), nuevo()
        c = xe.centro(xe.marco(xe.TORMENTA, 'ojo', min(e, 7), 1), (CX, CY))
        if e < 2:
            estrella(a, c[0], c[1], (18, 24)[e], xe.RAYO)
        if e < 3:
            xe.aro_suelo(s, a, CX, CY, R, 16, False)
        if e < 8:
            rnd = random.Random(e // 2 * 13)
            for j in range(0, 16, 2):
                ang = -math.pi * 0.5 + j / 16 * math.tau
                x, y = CX + math.cos(ang) * R, CY + math.sin(ang) * R * 0.6
                ang2 = ang + math.tau / 16 * 2
                x2, y2 = CX + math.cos(ang2) * R, CY + math.sin(ang2) * R * 0.6
                xe.arco(a, x, y, x2, y2, j + e // 2 * 5, 2.4 * (1 - e / 9.0) + 0.5, amp=4.0, paso=6)
                if e < 3 and j % 4 == 0:
                    xe.arco(a, c[0], c[1], x, y, 70 + j + e, 1.6, amp=6.0, paso=9)
                if rnd.random() < 0.4:
                    estrella(a, x, y, 5, xe.RAYO)
        xe.anillo_chispas(a, s, CX, CY, R, e - 1, 3)
        out.append((s, a))
    return [out]


# ------------------------------------------------------------
#  SOBRE ELLA
# ------------------------------------------------------------
def g_carne():
    rnd = random.Random(3)
    bultos = [(rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.2), rnd.uniform(0, 4)) for _ in range(6)]
    x0, y0, x1, y1 = xe.caja_dibujo(xe.marco(xe.BASE, 'idle', 0, 1), A)
    cx, cy, w, h = (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0
    out = []
    for f in range(12):
        s, a = nuevo(), nuevo()
        for bx, by, fase in bultos:
            u = (f - fase) / 8.0
            if 0 <= u <= 1:
                r = 3.2 * math.sin(math.pi * u)
                if r > 0.6:
                    xe.bolita(a, cx + bx * w, cy + by * h, r, xe.PUSTULA)
        out.append((s, a))
    return [out]


def g_grietas():
    rnd = random.Random(9)
    rajas = [(rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.15), rnd.uniform(0, math.tau)) for _ in range(4)]
    x0, y0, x1, y1 = xe.caja_dibujo(xe.marco(xe.BASE, 'idle', 0, 1), A)
    cx, cy, w, h = (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0
    out = []
    for f in range(10):
        s, a = nuevo(), nuevo()
        for j, (x, y, ang) in enumerate(rajas):
            px, py = cx + x * w, cy + y * h
            xe.arco(a, px, py, px + math.cos(ang) * 8, py + math.sin(ang) * 5, j * 3 + 1, 1.0 + 0.3 * ((f + j) % 2),
                    pal=xe.ORO, borde=(60, 40, 10), amp=2.0, paso=3)
            if (f + j * 2) % 5 == 0:
                estrella(a, px, py, 4, xe.ORO)
        out.append((s, a))
    return [out]


# ------------------------------------------------------------
#  LAS PUNTAS (para el juego)
# ------------------------------------------------------------
def puntas():
    """Donde esta, en cada una de las 8 direcciones de la hoja, el tentaculo de delante en el golpe (base y Masa: fotograma 3
    de 'basico') y el ojo del Ojo de la tormenta (en 'basico' y 'rayo'), en pixeles desde el CENTRO de su lienzo."""
    import numpy as np
    sal = {}
    for var, nombre in ((xe.BASE, ''), (xe.GALVANICA, 'galvanica')):
        mo = xe._modelo_de(var)
        filas = []
        for fila in range(8):
            dx, dy = xe._dir(fila)
            hacia = (mo.W / 2 + dx * 60, mo.H / 2 + dy * 45)
            p = xe.punta_tentaculo(var, 'basico', fila, 3, (mo.W / 2, mo.H / 2), hacia)
            filas.append((round(float(p[0] - mo.W // 2), 1), round(float(p[1] - mo.H // 2), 1)))
        sal[nombre] = filas
    filas = []
    for fila in range(8):
        dx, dy = xe._dir(fila)
        spr = xe.marco(xe.TORMENTA, 'rayo', 4, fila)
        w, h = spr.size
        oj = xe.ojo_de(spr, (w / 2, h / 2), dx, dy)
        filas.append((round(float(oj[0] - w // 2), 1), round(float(oj[1] - h // 2), 1)))
    sal['ojo'] = filas
    # y donde acaban los tentaculos colgando (de ahi bajan las chispas a los de debajo): el fondo de su dibujo
    spr = xe.marco(xe.TORMENTA, 'tentaculos', 3, 1)
    x0, y0, x1, y1 = xe.caja_dibujo(spr, (spr.size[0] / 2, spr.size[1] / 2))
    sal['cuelgan'] = (0.0, round(float(y1 - spr.size[1] // 2 - 2), 1))
    return sal


def principal():
    d = {}
    d['latigo_golpe'] = guardar('latigo_golpe', _filas5(latigo_golpe, 8), 14.0, 5)
    d['chispas'] = guardar('chispas', _fila1(chispas, 7), 12.0)
    d['vibra'] = guardar('vibra', _fila1(vibra, 7), 12.0)
    d['mirada_ojo'] = guardar('mirada_ojo', _fila1(mirada_ojo, 11), 12.0)
    d['cono_mirada'] = guardar('cono_mirada', g_cono(xe.BASE), 12.0, 5, origen=A)
    d['cono_chispas'] = guardar('cono_chispas', g_cono(xe.GALVANICA, True), 12.0, 5, origen=A)
    d['alarido'] = guardar('alarido', g_alarido(), 14.0, 5)
    d['descarga'] = guardar('descarga', lambda: g_descarga(), 12.0)
    d['aro_carga'] = guardar('aro_carga', lambda: g_aro_carga(), 10.0, 1, True)
    d['aro_estalla'] = guardar('aro_estalla', lambda: g_aro_estalla(), 12.0)
    d['carne'] = guardar('carne', lambda: g_carne(), 10.0, origen=A)
    d['grietas'] = guardar('grietas', lambda: g_grietas(), 10.0, 1, True, origen=A)
    ho.apuntar(LA, d)
    print('PUNTAS', puntas())


if __name__ == '__main__':
    principal()
