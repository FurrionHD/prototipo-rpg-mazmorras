#!/usr/bin/env python3
# ============================================================
#  trent_efectos_horno.py -- HORNEA LOS EFECTOS DEL TRENT, SUS MUTANTES (Tocon ambarino y Espantajo) Y LOS BICHOS DE LA COSTRA. Cada cosa con su
#  paleta de la lamina; el charco, en indices (lo tine la savia, la savia negra o la baba de un slime). Lo que mide lo que toque en cada pelea
#  va por codigo: el goteron (EfectoPixel.poner_vuelo), el chorro del Geiser y los hilos de Chupar (CintaPixel), el latido de sus grietas
#  (GrietaPixel, sobre su sprite).
#    python tools/sprites_sdf/trent_efectos_horno.py
# ============================================================
import math
import random

import escarabajo_efectos_pixel as ep
import trent_efectos_pixel as tr       # (trae el lienzo grande: va antes que los demas)
import slime_efectos_pixel as sl
import slime_veneno_efectos_pixel as vn
import horno_efectos as ho
from slime_efectos_pixel import nuevo, estrella, punto, gota, charco, seco, Gotas, cometa_dir, coletazo, disco

sl.victima = vn.victima = tr.victima = ep.victima = lambda a, x, y: None
tr.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'trent'
W, H = tr.W, tr.H
CX, CY = W // 2, H // 2
DIRS = sl.DIRS[:5]
ORIGENES = [(CX, CY)] * 5
IDX = [(40, 0, 0), (80, 0, 0), (120, 0, 0), (160, 0, 0)]
BORDE = (200, 0, 0)


def filas_dir(pintar, n):
    filas = []
    for i, (dx, dy) in enumerate(DIRS):
        fila = []
        for f_ in range(n):
            s, a = nuevo(), nuevo()
            pintar(s, a, f_, dx, dy, i)
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


def uno(funcion, *args, desde=0, **kw):
    m, _t = funcion(*args, **kw)
    return [m[desde:]], [sl.ORIGEN]


d = {}


# --- SOBRE EL CUERPO: (CX, CY) = los pies del que lo recibe ---
# El ramalazo: la media luna de madera que cae (toca en el marco 2), astillas y hojas.
def ramalazo(s, a, e, dx, dy, i):
    pecho = (CX, CY - 10)
    lado = 1 if dx >= 0 else -1
    if e < 5:
        coletazo(a, pecho[0], pecho[1] + 12, -math.pi / 2, 20.0, (-0.8 + 1.6 * (e + 1) / 5.0) * lado, 1.5, lado, 9.0, tr.MADERA, tr.MADERA_BORDE)
    if e in (2, 3):
        estrella(a, pecho[0], pecho[1], (10, 6)[e - 2], tr.MADERA)
    if e >= 2:
        tr.astillas(a, pecho[0], pecho[1], e - 2, 3 + i)
        tr.hojitas(a, pecho[0], pecho[1] - 6, e - 2, 5 + i)


f, o = filas_dir(ramalazo, 13)
d['ramalazo'] = ho.guardar_efecto(LA, 'ramalazo', f, o, 14.0)
f, o = marcos(lambda s, a, e: tr.pegote(a, CX, CY - 11, e), 13)
d['pegote'] = ho.guardar_efecto(LA, 'pegote', f, o, 14.0)

# --- POR EL SUELO ---
f, o = por_dirs(tr.ramazo, desde=3, con_victimas=False)
d['ramazo'] = ho.guardar_efecto(LA, 'ramazo', f, o, 30.0, False, 12, 14.0)
f, o = uno(tr.raices, con_atado=False)
d['raices'] = ho.guardar_efecto(LA, 'raices', f, o, 14.0 / 0.8, False, 14, 12.0)


# Las raices que atan (mientras dure el Enraizado): se enroscan, aguantan y se hunden.
def enrosca(a, q):
    for k in range(3):
        yy = CY - 2 - k * 3
        for j in range(-5, 6):
            if abs(j) < 6 * q:
                punto(a, CX + j, yy + math.sin(j * 0.9 + k) * 1.0, tr.MADERA[1] if j % 3 else tr.MADERA[2], 2)


def atado(s, a, e, sale=True):
    q = min(1.0, (e + 1) / 4.0) if sale else max(0.0, 1.0 - (e + 1) / 5.0)
    tr.raiz(a, CX - 7, CY + 1, 12 * q, 1)
    tr.raiz(a, CX + 7, CY + 1, 10 * q, 3)
    enrosca(a, q)


f, o = marcos(lambda s, a, e: atado(s, a, e), 4)
d['atado_sale'] = ho.guardar_efecto(LA, 'atado_sale', f, o, 12.0)
f, o = marcos(lambda s, a, e: atado(s, a, 3), 1)
d['atado_dura'] = ho.guardar_efecto(LA, 'atado_dura', f, o, 4.0, True)
f, o = marcos(lambda s, a, e: atado(s, a, e, False), 5)
d['atado_vete'] = ho.guardar_efecto(LA, 'atado_vete', f, o, 10.0)


# --- LOS GOTERONES: la gota que vuela (la mueve el codigo, orientada) y donde revienta ---
PALS = {'savia': (tr.SAVIA, tr.SAVIA_BORDE), 'ambar': (tr.AMBAR, tr.AMBAR_BORDE), 'negra': (tr.NEGRA, tr.NEGRA_BORDE)}
for nombre, (pal, borde) in PALS.items():
    f, o = filas_dir(lambda s, a, f_, dx, dy, i, pal=pal, borde=borde: (cometa_dir(a, CX, CY, dx, dy, 14, 1, pal), gota(a, CX, CY, 5.0, pal, borde)), 1)
    d['gota_' + nombre] = ho.guardar_efecto(LA, 'gota_' + nombre, f, o, 10.0)
    salpica = Gotas(10, 3, 5.0, 16.0, sube=(8.0, 16.0), tam=(1.3, 2.2), pal=pal, borde=borde)

    def cae(s, a, g, pal=pal, salpica=salpica):
        if g < 2:
            estrella(a, CX, CY - 8, (12, 7)[g], pal)
        salpica.pintar(s, a, CX, CY - 6, min(1.0, g / 4.0), 2.0, 1.0, 99)
    f, o = marcos(cae, 9)
    d['cae_' + nombre] = ho.guardar_efecto(LA, 'cae_' + nombre, f, o, 14.0)


# --- EL CHARCO QUE SE QUEDA (savia, savia negra; y la baba de un slime cuando le toca): en indices, por tamano ---
def charco_de(r, fase):
    def sale(s, a, g):
        charco(s, CX, CY, r * min(1.0, (g + 1) / 3.0), 3.0, 1.0, IDX, BORDE)

    def dura(s, a, g):
        charco(s, CX, CY, r, 3.0, 1.0, IDX, BORDE)
        rnd = random.Random(g // 2 + fase)
        for _ in range(2):   # burbujea
            bx, by = CX + rnd.uniform(-r * 0.6, r * 0.6), CY + rnd.uniform(-r * 0.35, r * 0.35)
            if g % 2 == 0:
                disco(s, bx, by, 1.6, BORDE)
                punto(s, bx - 1, by - 1, IDX[3])

    def vete(s, a, g):
        charco(s, CX, CY, r, 3.0, seco(g, 0, 6), IDX, BORDE)
    return sale, dura, vete


for r in (6, 9, 13, 18):
    sa, du, ve = charco_de(r / tr.UNIDAD * 1.0, r)
    for parte, fn, n, fps, bucle in (('sale', sa, 3, 10.0, False), ('dura', du, 8, 6.0, True), ('vete', ve, 6, 10.0, False)):
        f, o = marcos(fn, n)
        nombre = 'charco_%d_%s' % (r, parte)
        d[nombre] = ho.guardar_efecto(LA, nombre, f, o, fps, bucle)


# El vaho violeta del charco de savia negra (va encima, sin tenir).
def vaho(s, a, g):
    for q in range(3):
        e = (g + q * 4) % 11
        vn.nube(a, CX + (q - 1) * 7, CY - 14 - e * 2, 3 + e * 0.6, (1 - e / 11.0) * 1.5, tr.HUMO_V)


f, o = marcos(vaho, 11)
d['vaho'] = ho.guardar_efecto(LA, 'vaho', f, o, 10.0, True)


# --- LO QUE SE QUEDA PEGADO A ALGUIEN: (CX, CY) = sus pies ---
# El cepo de la Resina: sale, aguanta (con un brillo) y al soltarle se agrieta y cae a trozos.
f, o = marcos(lambda s, a, g: tr.deja_cepo(s, a, (CX, CY), g), 3)
d['cepo_sale'] = ho.guardar_efecto(LA, 'cepo_sale', f, o, 10.0)
f, o = marcos(lambda s, a, g: (tr.deja_cepo(s, a, (CX, CY), 3), punto(a, CX - 8, CY - 2, tr.AMBAR[3], 2) if g == 0 else None), 6)
d['cepo_dura'] = ho.guardar_efecto(LA, 'cepo_dura', f, o, 6.0, True)
f, o = marcos(lambda s, a, g: tr.deja_cepo(s, a, (CX, CY), 13 + g), 8)
d['cepo_vete'] = ho.guardar_efecto(LA, 'cepo_vete', f, o, 12.0)


# El humo violeta de la Savia negra, mas espeso cuantas mas cargas: sube del cuerpo (de 10 a 46 sobre los pies).
def humo(nivel):
    rnd = random.Random(nivel)
    salidas = [(rnd.uniform(-9, 9), rnd.uniform(-44, -12)) for _ in range(nivel)]

    def pinta(s, a, f_):
        for q, (ox, oy) in enumerate(salidas):
            e = (f_ + q * 5) % 14
            vn.nube(a, CX + ox + e * 0.3, CY + oy - e * 2.0, 3 + e * 0.75, (1 - e / 14.0) * 1.5, tr.HUMO_V)
    return pinta


for nivel in range(1, 6):
    f, o = marcos(humo(nivel), 14)
    d['humo_%d' % nivel] = ho.guardar_efecto(LA, 'humo_%d' % nivel, f, o, 10.0, True)


# Los bichos de la costra: el PRINGADO (pegotes que gotean y dos moscas) y el PICOR (ronchas que laten).
def pringue(s, a, e):
    for ox, oy in ((-3, -14), (3, -9), (-2, -5)):
        gota(a, CX + ox, CY + oy, 2.2, tr.CACA, tr.CACA[0])
    punto(a, CX + 3, CY - 4 + e % 6, tr.CACA[1], 2)
    for k in range(2):
        ang = e * 0.9 + k * 3.1
        punto(a, CX + math.cos(ang) * 10, CY - 20 + math.sin(ang * 1.7) * 3, (14, 12, 16), 2)


f, o = marcos(pringue, 12)
d['pringue'] = ho.guardar_efecto(LA, 'pringue', f, o, 10.0, True)
_rnd = random.Random(3)
RONCHAS = [(_rnd.uniform(-5, 5), _rnd.uniform(-17, -3), _rnd.uniform(1.4, 2.2)) for _ in range(6)]


def picor(s, a, f_):
    late = 0.35 if f_ % 4 < 2 else 0.0
    for ox, oy, r in RONCHAS:
        disco(a, CX + ox, CY + oy, r + late + 0.6, tr.RONCHA[0])
        disco(a, CX + ox, CY + oy, r + late, tr.RONCHA[1])
        punto(a, CX + ox - 1, CY + oy - 1, tr.RONCHA[2])


f, o = marcos(picor, 4)
d['picor'] = ho.guardar_efecto(LA, 'picor', f, o, 10.0, True)

# --- EL TOCON Y SUS BICHOS ---
f, o = uno(tr.costra, solo_grumos=True)
d['costra'] = ho.guardar_efecto(LA, 'costra', f, o, 18.0)
f, o = por_dirs(tr.bola, largo_mundo=100.0, con_victima=False)
d['bola'] = ho.guardar_efecto(LA, 'bola', f, o, 10.0 / 0.6, False, 10, 14.0)
f, o = uno(tr.revienta)
d['revienta'] = ho.guardar_efecto(LA, 'revienta', f, o, 14.0 / 0.9)

# --- EL GEISER: la nube que llueve sobre su circulo (el chorro lo pinta CintaPixel). La 1a gota toca a los 10 marcos ---
f, o = uno(tr.geiser, solo_nube=True)
d['nube'] = ho.guardar_efecto(LA, 'nube', f, o, 10.0 / 0.55, False, 10, 12.0)
ho.sumar(LA, d)
