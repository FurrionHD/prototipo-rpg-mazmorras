#!/usr/bin/env python3
# ============================================================
#  miconido_efectos_horno.py -- HORNEA LOS EFECTOS DEL MICONIDO Y SUS MUTANTES, los de su lamina aprobada (10/11/2026:
#  "estan bien"), SIN REJILLA (memoria transparencia-de-verdad: 4 pasadas promediadas, alfa en 4 escalones).
#  SOBRE QUIEN RECIBE, (CX, CY) = sus pies:
#    porrazo            el aplaston y las esporas pardas (el basico del normal)
#    tos_espora|luz|seta  la tos de esporas en la cara (Bocanada / Esporas luminosas / Esporas de infeccion)
#    filamentos_golpe   el latigazo de luz en la cara (el basico de la Campana) y el velo
#    tajo_golpe         el golpe de la espada oxidada: destello, escamas de oxido, sangre (el basico del Florecido)
#    estocada_golpe     5 dirs: destello, esquirlas POR DETRAS, el agujero y sangre (la Estocada del muerto)
#    destello_golpe     el velo de Ciego del Destello
#  DEL GESTO DE QUIEN LO LANZA (TacticoPixel.al_gesto), (CX, CY) = sus pies, 5 direcciones (las otras tres en espejo),
#  siguiendo al cuerpo:
#    tajo, estocada      la estela de la PUNTA de su espada (medida en el modelo: miconido_puntas.py)
#    filamentos          las tres hebras de luz que salen de las puntas de sus filamentos y azotan al frente
#    campana_destello_carga / florecido_destello_carga  (en bucle) las motas de luz que se juntan en el nucleo
#    campana_destello / florecido_destello              el cono de luz desde el nucleo
#    atrae               (sobre la Campana, al empezar su turno) motas de luz que vuelven a su nucleo
#  LO QUE SE QUEDA (PiezaPixel): atado_sale / atado_dura / atado_vete, los cordones de micelio en las piernas.
#    python tools/sprites_sdf/miconido_efectos_horno.py
# ============================================================
import math
import random
import sys

import miconido_efectos_pixel as me      # (trae su lienzo: va antes que los demas)
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import ciempies_efectos_pixel as ce
import horno_efectos as ho
import transparencia as tr
from slime_efectos_pixel import nuevo, estrella

LA = 'miconido'
W, H = me.W, me.H
CX, CY = W // 2, H // 2 + 20
MODS = [ce, ep, sl, rt, me]
PIES = {me.NORMAL: (94.5, 125.7), me.CAMPANA: (140.0, 236.0), me.FLORECIDO: (140.0, 236.0)}


def pos_sprite(var):
    """Donde poner el sprite (por su centro, como hace escena/punta) para que sus pies caigan en (CX, CY)."""
    lw, lh = me._lienzo(var)
    px, py = PIES[var]
    return (CX - px + lw // 2, CY - py + lh // 2)


def V():
    return (CX, CY)


def guardar(nombre, gen, fps, n_filas=1, bucle=False, origen=None):
    """origen: por defecto los pies (CX, CY). Lo que SALE DEL CUERPO (estelas, filamentos, destello, atrae) va con origen en el
    CENTRO DE SU SPRITE (pos_sprite) y el juego lo lanza desde el centro del sprite de verdad (TacticoPixel.centro_sprite):
    asi casa pixel a pixel, sin depender de donde pone los pies la ficha (10/11: el destello salia por encima de la cabeza)."""
    filas = tr.filas_con_alfa(gen, MODS)
    return ho.guardar_efecto(LA, nombre, filas, [origen or (CX, CY)] * n_filas, fps, bucle)


# ------------------------------------------------------------
#  SOBRE QUIEN RECIBE
# ------------------------------------------------------------
def g_porrazo():
    out = []
    hx, hy = me.cabeza(V())
    for e in range(9):
        s, a = nuevo(), nuevo()
        if e < 3:
            r = (9, 11, 8)[e]
            m_ = me.np.hypot((me.XX - hx) / r, (me.YY - hy + 2) / (r * 0.45)) < 1.0
            me.poner(a, m_ & (me.TRAMA < (0.9, 0.6, 0.35)[e]), me.ESPORA[1])
            me.poner(a, m_ & (me.np.hypot((me.XX - hx) / (r * 0.6), (me.YY - hy + 3) / (r * 0.25)) < 1.0) & (me.TRAMA < 0.6),
                     me.ESPORA[3])
        for lado in (-1, 1):
            me.nube(a, hx + lado * (5 + e * 2.2), hy + 1 + e * 0.4, 3 + min(e, 4) * 1.1, max(0.0, 1.0 - e / 8.0))
        me.motas(a, hx, hy - 2, e, 11, me.ESPORA, 5, 1.0, 10)
        out.append((s, a))
    return [out]


def g_tos(pal, brillan):
    def gen():
        out = []
        for e in range(10):
            s, a = nuevo(), nuevo()
            me.tos(a, V(), e, 3, pal, brillan)
            out.append((s, a))
        return [out]
    return gen


def g_filamentos_golpe():
    out = []
    hx, hy = me.cabeza(V())
    for e in range(9):
        s, a = nuevo(), nuevo()
        if e < 2:
            estrella(a, hx, hy, (10, 6)[e], me.LUZ)
        me.motas(a, hx, hy, e, 2, me.LUZ, 4, 0.8, 7, True)
        me.velo(a, V(), e - 1)
        out.append((s, a))
    return [out]


def g_tajo_golpe():
    out = []
    hx, hy = me.cabeza(V())
    hy += 4
    for e in range(7):
        s, a = nuevo(), nuevo()
        if e < 2:
            estrella(a, hx, hy, 11 if e < 1 else 7, me.OXIDO)
        me.escamas(a, hx, hy, e, 4)
        me.sangre(a, hx, hy + 2, e, 1, n=3)
        out.append((s, a))
    return [out]


def g_estocada_golpe():
    filas = []
    for fila in range(5):
        dx, dy = me._dir(fila)
        hit = (CX, CY - 12)
        out = []
        for e in range(8):
            s, a = nuevo(), nuevo()
            if e < 2:
                estrella(a, hit[0], hit[1], 10 if e < 1 else 7, me.OXIDO)
                rnd = random.Random(fila + e)
                for _i in range(5):
                    kk = rnd.uniform(5, 14) + e * 5
                    lado = rnd.uniform(-5, 5)
                    me.punto(a, hit[0] + dx * kk - dy * lado, hit[1] + dy * kk + dx * lado, me.OXIDO[2], 2)
            me.bolita(s, hit[0] + dx * 2, hit[1] + 2, 2.0 if e < 4 else 1.3, [me.OSCURO, me.OSCURO, (60, 14, 12), (90, 24, 20)])
            me.sangre(a, hit[0], hit[1] + 2, e, fila + 3, n=2)
            out.append((s, a))
        filas.append(out)
    return filas


def g_destello_golpe():
    out = []
    hx, hy = me.cabeza(V())
    for e in range(10):
        s, a = nuevo(), nuevo()
        if e < 1:
            estrella(a, hx, hy, 6, me.LUZ)
        me.velo(a, V(), e)
        out.append((s, a))
    return [out]


# ------------------------------------------------------------
#  DEL GESTO
# ------------------------------------------------------------
def g_estela(anim, n, desde, hasta_extra, grueso, largo):
    var = me.FLORECIDO
    A = pos_sprite(var)
    pos_de = lambda fr: A

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = me._dir(fila)
            fr_i, _q = me._impacto(var, anim, fila, 'espada', pos_de, (dx, dy), n)
            marcos = []
            for f in range(n):
                s, a = nuevo(), nuevo()
                if n * desde <= f <= fr_i + hasta_extra:
                    me.estela(a, var, anim, fila, 'espada', pos_de, f, me.OXIDO, grueso, min(largo, f - n * desde))
                marcos.append((s, a))
            filas.append(marcos)
        return filas
    return gen


def g_filamentos():
    var = me.CAMPANA
    A = pos_sprite(var)
    n = 8

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = me._dir(fila)
            cara = (CX + dx * 40, CY + dy * 36 - 16)
            marcos = []
            for f in range(n):
                s, a = nuevo(), nuevo()
                if 2 <= f < 6:
                    u = min(1.0, (f - 1) / 3.0)
                    for j, k in enumerate((2, 3, 4)):
                        q = me.punta(var, 'embestida', fila, f, 'fil%d' % k, A)
                        if q is None:
                            continue
                        fin = (q[0] + (cara[0] - 4 + j * 4 - q[0]) * u, q[1] + (cara[1] - q[1]) * u)
                        me.cuentas(a, me._curva(q, fin, 3, 10, f + j), 1.1, me.LUZ, me.LUZ[0])
                marcos.append((s, a))
            filas.append(marcos)
        return filas
    return gen


def g_destello_carga(var):
    A = pos_sprite(var)
    rnd = random.Random(5)
    llegan = [(rnd.uniform(0, math.tau), rnd.uniform(14, 26)) for _ in range(8)]

    def gen():
        filas = []
        for fila in range(5):
            marcos = []
            for f in range(8):
                s, a = nuevo(), nuevo()
                nuc, _b = me.campana_de(me.marco(var, 'destello_carga', f, fila), A, var)
                for j, (ang, d0) in enumerate(llegan):
                    k = ((f + j * 0.6) % 4) / 4.0
                    d = d0 * (1.0 - k)
                    me.punto(a, nuc[0] + math.cos(ang) * d, nuc[1] + math.sin(ang) * d * 0.7,
                             me.LUZ[2] if k > 0.5 else me.LUZ[1], 2)
                marcos.append((s, a))
            filas.append(marcos)
        return filas
    return gen


def g_destello(var):
    A = pos_sprite(var)
    R = 60.0 / me.UNIDAD

    def gen():
        filas = []
        for fila in range(5):
            dx, dy = me._dir(fila)
            eje = math.atan2(dy, dx)
            marcos = []
            for e in range(10):
                s, a = nuevo(), nuevo()
                nuc, _b = me.campana_de(me.marco(var, 'destello', min(e, 7), fila), A, var)
                capa = a if dy > -0.2 else s
                me.abanico(capa, nuc[0], nuc[1] + 6, eje, R, 90.0, e, me.LUZ)
                if e < 2:
                    estrella(a, nuc[0], nuc[1], (16, 10)[e], me.LUZ)
                marcos.append((s, a))
            filas.append(marcos)
        return filas
    return gen


def g_atrae():
    var = me.CAMPANA
    A = pos_sprite(var)
    rnd = random.Random(9)
    desde = [(rnd.uniform(0, math.tau), rnd.uniform(30, 46)) for _ in range(10)]
    out = []
    for f in range(10):
        s, a = nuevo(), nuevo()
        nuc, _b = me.campana_de(me.marco(var, 'idle', 0, 1), A, var)
        for j, (ang, d0) in enumerate(desde):
            u = min(1.0, max(0.0, (f - j * 0.3) / 6.0))
            if u <= 0.0 or u >= 1.0:
                continue
            d = d0 * (1.0 - u)
            me.punto(a, nuc[0] + math.cos(ang) * d, nuc[1] + 30 * (1.0 - u) + math.sin(ang) * d * 0.4,
                     me.LUZ[2] if u > 0.5 else me.LUZ[1], 2)
        if 5 <= f < 8:
            estrella(a, nuc[0], nuc[1], (6, 9, 6)[f - 5], me.LUZ)
        out.append((s, a))
    return [out]


# ------------------------------------------------------------
#  LO QUE SE QUEDA: el atado de micelio
# ------------------------------------------------------------
def g_atado(fase):
    def gen():
        out = []
        n = 4 if fase != 'dura' else 8
        for f in range(n):
            s, a = nuevo(), nuevo()
            if fase == 'sale':
                me.enrosque(a, V(), f, me.CARNE, me.CARNE_BORDE)
            elif fase == 'dura':
                me.enrosque(a, V(), 3, me.CARNE, me.CARNE_BORDE)
                if f % 4 < 2:
                    me.punto(a, CX + 6, CY - 6 - (f % 4), me.CARNE[3], 1)
            else:
                me.enrosque(a, V(), 3 - f, me.CARNE, me.CARNE_BORDE)
            out.append((s, a))
        return [out]
    return gen


def principal():
    d = {}
    d['porrazo'] = guardar('porrazo', g_porrazo, 12.0)
    for suf, pal, br in (('espora', me.ESPORA, False), ('luz', me.LUZ, True), ('seta', me.SETA, False)):
        d['tos_' + suf] = guardar('tos_' + suf, g_tos(pal, br), 12.0)
    d['filamentos_golpe'] = guardar('filamentos_golpe', g_filamentos_golpe, 12.0)
    d['tajo_golpe'] = guardar('tajo_golpe', g_tajo_golpe, 12.0)
    d['estocada_golpe'] = guardar('estocada_golpe', g_estocada_golpe, 13.0, 5)
    d['destello_golpe'] = guardar('destello_golpe', g_destello_golpe, 12.0)
    d['tajo'] = guardar('tajo', g_estela('embestida', 8, 0.33, 1.5, 6.0, 1.5), 8.0, 5, origen=pos_sprite(me.FLORECIDO))
    d['estocada'] = guardar('estocada', g_estela('estocada', 8, 0.3, 1.0, 5.0, 1.0), 13.0, 5, origen=pos_sprite(me.FLORECIDO))
    d['filamentos'] = guardar('filamentos', g_filamentos(), 8.0, 5, origen=pos_sprite(me.CAMPANA))
    for var, pref in ((me.CAMPANA, 'campana'), (me.FLORECIDO, 'florecido')):
        d[pref + '_destello_carga'] = guardar(pref + '_destello_carga', g_destello_carga(var), 12.0, 5, True, origen=pos_sprite(var))
        d[pref + '_destello'] = guardar(pref + '_destello', g_destello(var), 12.0, 5, origen=pos_sprite(var))
    d['atrae'] = guardar('atrae', g_atrae, 10.0, origen=pos_sprite(me.CAMPANA))
    d['atado_sale'] = guardar('atado_sale', g_atado('sale'), 10.0)
    d['atado_dura'] = guardar('atado_dura', g_atado('dura'), 6.0, 1, True)
    d['atado_vete'] = guardar('atado_vete', g_atado('vete'), 10.0)
    ho.apuntar(LA, d)


if __name__ == '__main__':
    principal()
