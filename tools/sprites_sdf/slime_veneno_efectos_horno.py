#!/usr/bin/env python3
# ============================================================
#  slime_veneno_efectos_horno.py -- HORNEA LOS EFECTOS DEL SLIME VENENOSO Y SUS MUTANTES, Y LO QUE SE QUEDA DE LOS SLIMES (la baba,
#  la nube y la burbuja: lo que en la lamina dura unos marcos, aqui son tres hojas: sale, dura y se va; ver PiezaPixel).
#  Las hojas se suman a las del slime: SU color lo pone el shader (ver slime_efectos_horno.py).
#    python tools/sprites_sdf/slime_veneno_efectos_horno.py
# ============================================================
import math
import random
import re

import numpy as np

import slime_efectos_pixel as sl
import slime_veneno_efectos_pixel as vn
import horno_efectos as ho
from slime_efectos_pixel import XX, YY, TRAMA, UNIDAD, nuevo, DIRS, charco, cristal, gota, estrella, cometa_dir, sombra, punto

IDX = [(40, 0, 0), (80, 0, 0), (120, 0, 0), (160, 0, 0)]
BORDE = (200, 0, 0)
sl.GEL, vn.GEL = IDX, IDX
sl.GEL_BORDE = BORDE
sl.victima = vn.victima = lambda a, x, y: None
sl.escena = vn.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'slime'
CX, CY = 90, 80     # el origen en el lienzo de lo que no sale de una funcion de la lamina


def por_dirs(funcion, *args, desde=0):
    filas, origenes = [], []
    for d in range(5):
        m, _t = funcion(d, *args)
        filas.append(m[desde:])
        origenes.append(sl.ORIGEN)
    return filas, origenes


def apagar(capas, q):
    """Se deshace a trama: lo que queda con q de 1 a 0."""
    out = []
    for c in capas:
        n = c.copy()
        n[TRAMA >= q] = 0
        out.append(n)
    return tuple(out)


d = {}
f, o = por_dirs(vn.rociada, 's115', 45.0, 70.0, desde=3)
d['rociada_45'] = ho.guardar_efecto(LA, 'rociada_45', f, o, 14.0)
f, o = por_dirs(vn.rociada, 'mia138', 55.0, 90.0, desde=3)
d['rociada_55'] = ho.guardar_efecto(LA, 'rociada_55', f, o, 14.0)
# El Escupitajo: al reventar, en los pies de quien lo recibe; la bola la mueve EfectoPixel.poner_vuelo.
m, _t = vn.escupitajo(2, 's115')
d['escupe'] = ho.guardar_efecto(LA, 'escupe', [m[9:]], [sl.ORIGEN], 14.0)


def bola():
    filas = []
    for fila in range(5):
        dx, dy = DIRS[fila]
        marcos = []
        for f_ in range(4):
            a = nuevo()
            cometa_dir(a, CX, CY, dx, dy, 11 + f_ % 2, 1, IDX)
            for k in (1, 2):
                gota(a, CX - dx * (5 * k + f_ % 2), CY - dy * (5 * k + f_ % 2) + k, 1.4 - 0.4 * k)
            gota(a, CX, CY, 3.4)
            marcos.append((nuevo(), a))
        filas.append(marcos)
    return filas


filas_b = bola()
d['bola'] = ho.guardar_efecto(LA, 'bola', filas_b, [(CX, CY)] * 5, 12.0, True)


# --- LA NUBE DE MIASMA: se abre, se queda removiendose y se deshace (hasta su borde de verdad: su circulo) ---
def nube(radio_mundo):
    R = radio_mundo / UNIDAD
    rnd = random.Random(21)
    puffs = [(rnd.uniform(0, math.tau), rnd.uniform(0.15, 1.0), rnd.uniform(9.0, 14.0), rnd.uniform(0.0, 0.25)) for _ in range(int(30 * radio_mundo / 50.0))]

    def capa(k, fuerza, giro):
        s, a = nuevo(), nuevo()
        for ang, uu, r, t0 in puffs:
            kk = max(0.0, min(1.0, (k - t0) / (1 - t0)))
            if kk <= 0:
                continue
            an = ang + giro * (0.5 + uu)
            vn.nube(a if math.sin(an) > -0.2 else s, CX + math.cos(an) * R * uu * kk, CY + math.sin(an) * R * uu * kk * 0.85 - 4, r * (0.5 + 0.5 * kk), fuerza)
        return s, a
    sale = [capa(1.0 - (1.0 - (i + 1) / 6.0) ** 2, 1.0, 0.0) for i in range(6)]
    dura = [capa(1.0, 1.0, i / 8.0 * 0.5) for i in range(8)]
    vete = [capa(1.0, 1.0 - (i + 1) / 8.0, 0.5) for i in range(8)]
    return sale, dura, vete


for r_ in (50, 65):
    sa, du, ve = nube(float(r_))
    d['nube_%d_sale' % r_] = ho.guardar_efecto(LA, 'nube_%d_sale' % r_, [sa], [(CX, CY)], 12.0)
    d['nube_%d_dura' % r_] = ho.guardar_efecto(LA, 'nube_%d_dura' % r_, [du], [(CX, CY)], 8.0, True)
    d['nube_%d_vete' % r_] = ho.guardar_efecto(LA, 'nube_%d_vete' % r_, [ve], [(CX, CY)], 10.0)


# --- LA BURBUJA: del tamaño de su radio de verdad (22), flota sobre su sombra y revienta en gotas y gas ---
R_B = 22.0 / UNIDAD
ALTO = 12


def burbuja_dura():
    marcos = []
    for f_ in range(8):
        s, a = nuevo(), nuevo()
        sombra(s, CX, CY + 10, R_B * 0.6)
        vn.burbuja(a, CX, CY - ALTO + round(math.sin(f_ / 8.0 * math.tau)), R_B, f_ * 0.8)
        marcos.append((s, a))
    return marcos


def burbuja_vete():
    marcos = []
    y = CY - ALTO
    for g in range(9):
        s, a = nuevo(), nuevo()
        if g < 2:
            estrella(a, CX, y, (18, 11)[g], IDX)
        if g < 8:
            for k in range(12):
                an = k / 12.0 * math.tau
                dd = R_B * 0.5 + g * 3.2
                gota(a, CX + math.cos(an) * dd, y + math.sin(an) * dd * 0.8 + g * g * 0.4, 1.8 - g * 0.15)
            vn.nube(a, CX, y - g, R_B * 0.5 + g * 1.8, 1.0 - g / 8.0)
        marcos.append((s, a))
    return marcos


def burbuja_brota():
    marcos = []
    for f_ in range(4):
        s, a = nuevo(), nuevo()
        r = R_B * (0.55 + 0.15 * f_)
        sombra(s, CX, CY + 10, r * 0.6)
        vn.burbuja(a, CX, CY - ALTO, r, f_)
        marcos.append((s, a))
    return marcos


def burbuja_vuela():
    filas = []
    a = nuevo()
    vn.burbuja(a, CX, CY, R_B * 0.45, 1.0)
    return [[(nuevo(), a)]]


d['burbuja_sale'] = ho.guardar_efecto(LA, 'burbuja_sale', [burbuja_brota()], [(CX, CY)], 14.0)
d['burbuja_dura'] = ho.guardar_efecto(LA, 'burbuja_dura', [burbuja_dura()], [(CX, CY)], 8.0, True)
d['burbuja_vete'] = ho.guardar_efecto(LA, 'burbuja_vete', [burbuja_vete()], [(CX, CY)], 14.0)
d['burbuja_vuela'] = ho.guardar_efecto(LA, 'burbuja_vuela', burbuja_vuela(), [(CX, CY)], 12.0, True)


# --- LA BABA de los mutantes (estilo 3 y 4): el charco redondo y el rastro; la 4, con pinchos de cristal clavados ---
def pinchos(s, a, sitios, q=1.0):
    for x, y, alto, incl in sitios:
        tmp = nuevo()
        n = math.hypot(incl, 1.0)
        cristal(tmp, x, y - alto * 0.5, incl / n, -1.0 / n, alto, 1.8, sl.CRISTAL)
        m = (tmp[:, :, 3] > 0) & (TRAMA < q)
        (a if y >= CY else s)[m] = tmp[m]


def burbujitas(s, sitios, f_):
    for i, (x, y) in enumerate(sitios):
        if (f_ + i) % 4 < 2:
            sl.disco(s, x, y, 1.6, BORDE)
            punto(s, x - 1, y - 1, IDX[3])


def baba_redonda(con_pinchos):
    R = 46.0 / UNIDAD
    rnd = random.Random(7)
    manchas = [(rnd.uniform(0, math.tau), rnd.uniform(0.5, 1.0), rnd.uniform(0.1, 0.18) * R) for _ in range(7)]
    agu = [(CX + math.cos(a_) * R * u, CY + math.sin(a_) * R * u * 0.8, rnd.uniform(7, 11), rnd.uniform(-0.5, 0.5)) for a_, u, _r in manchas]
    bur = [(CX + rnd.uniform(-R, R) * 0.45, CY + rnd.uniform(-R, R) * 0.35) for _ in range(4)]

    def capa(abre, f_):
        s, a = nuevo(), nuevo()
        charco(s, CX, CY, R * 0.62 * abre, 1.0)
        for an, uu, r in manchas:
            charco(s, CX + math.cos(an) * uu * R * 0.85 * abre, CY + math.sin(an) * uu * R * 0.85 * abre, r * abre, an)
        burbujitas(s, bur, f_)
        if con_pinchos:
            pinchos(s, a, agu)
        return s, a
    sale = [capa((i + 1) / 3.0, 0) for i in range(3)]
    dura = [capa(1.0, i) for i in range(4)]
    vete = [apagar(capa(1.0, 0), 1.0 - (i + 1) / 6.0) for i in range(6)]
    return sale, dura, vete


def baba_rastro(con_pinchos):
    L = 70.0 / UNIDAD
    medio = 14.0
    res = ([], [], [])
    origenes = []
    for fila in range(5):
        dx, dy = DIRS[fila]
        A = (CX - dx * L * 0.5, CY - dy * L * 0.5)
        origenes.append(A)
        rnd = random.Random(3 + fila)
        agu = [(A[0] + dx * L * u - dy * v, A[1] + dy * L * u + dx * v, rnd.uniform(7, 11), rnd.uniform(-0.5, 0.5)) for u, v in [(rnd.uniform(0.05, 0.95), rnd.uniform(-9, 9)) for _ in range(9)]]
        bur = [(A[0] + dx * L * u - dy * v, A[1] + dy * L * u + dx * v) for u, v in [(rnd.uniform(0.1, 0.9), rnd.uniform(-6, 6)) for _ in range(4)]]

        def capa(hecho, f_):
            s, a = nuevo(), nuevo()
            sl.rastro(s, A, dx, dy, L * hecho, medio, 0, 0, L, fila)
            burbujitas(s, bur, f_)
            if con_pinchos:
                pinchos(s, a, agu)
            return s, a
        res[0].append([capa((i + 1) / 3.0, 0) for i in range(3)])
        res[1].append([capa(1.0, i) for i in range(4)])
        res[2].append([apagar(capa(1.0, 0), 1.0 - (i + 1) / 6.0) for i in range(6)])
    return res, origenes


for suf, pin in (('', False), ('_p', True)):
    sa, du, ve = baba_redonda(pin)
    n_ = 'baba_c' + suf
    d[n_ + '_sale'] = ho.guardar_efecto(LA, n_ + '_sale', [sa], [(CX, CY)], 14.0)
    d[n_ + '_dura'] = ho.guardar_efecto(LA, n_ + '_dura', [du], [(CX, CY)], 6.0, True)
    d[n_ + '_vete'] = ho.guardar_efecto(LA, n_ + '_vete', [ve], [(CX, CY)], 10.0)
    res, ori = baba_rastro(pin)
    n_ = 'baba_l' + suf
    d[n_ + '_sale'] = ho.guardar_efecto(LA, n_ + '_sale', res[0], ori, 14.0)
    d[n_ + '_dura'] = ho.guardar_efecto(LA, n_ + '_dura', res[1], ori, 6.0, True)
    d[n_ + '_vete'] = ho.guardar_efecto(LA, n_ + '_vete', res[2], ori, 10.0)

# (se suman a las del slime normal, sin pisarlas)
with open(ho.DATOS, encoding='utf-8') as fh:
    import json
    previo = json.loads(re.search(r'^\t"slime": (\{.*\}),$', fh.read(), re.M).group(1).replace('null', 'null'))
previo.update(d)
ho.apuntar(LA, previo)
