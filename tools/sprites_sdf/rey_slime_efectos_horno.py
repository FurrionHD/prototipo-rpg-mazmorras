#!/usr/bin/env python3
# ============================================================
#  rey_slime_efectos_horno.py -- HORNEA LOS EFECTOS DEL REY SLIME Y SUS MUTANTES (tirano y destronado). Su gel sale del color de cada Rey
#  (indices, ver slime_efectos_horno.py); el cristal de su corona lleva su paleta. Se suman a las hojas de 'slime'. Lo que recorre una
#  distancia que cambia en cada pelea (los trozos, las crias, el Tributo, las clavadas) lo lleva EfectoPixel.poner_vuelo.
#    python tools/sprites_sdf/rey_slime_efectos_horno.py
# ============================================================
import math

import slime_efectos_pixel as sl
import rey_slime_efectos_pixel as rs   # (trae el lienzo grande: va antes que los demas)
import slime_veneno_efectos_pixel as vn
import horno_efectos as ho
from slime_efectos_pixel import nuevo, estrella, gota, charco, seco, sombra, punto, cristal, cometa_dir

IDX = [(40, 0, 0), (80, 0, 0), (120, 0, 0), (160, 0, 0)]
BORDE = (200, 0, 0)
sl.GEL, vn.GEL, rs.GEL = IDX, IDX, IDX
sl.GEL_BORDE = BORDE
for m_ in (sl, vn, rs):
    m_.victima = lambda a, x, y: None
    m_.escena = lambda suelo, cuerpos, aire: (suelo[0], aire[0])
LA = 'slime'
CX, CY = rs.W // 2, rs.H // 2
CARGA_SALTO = 12      # los marcos del salto, que en el juego hace su cuerpo
C = rs.CRISTAL
DIRS = sl.DIRS


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


def marcos(pintar, n):
    out = []
    for f_ in range(n):
        s, a = nuevo(), nuevo()
        pintar(s, a, f_)
        out.append((s, a))
    return [out]


def filas_dir(pintar, n):
    """Lo que vuela orientado: una fila por cada una de las 5 direcciones."""
    filas = []
    for dx, dy in DIRS[:5]:
        fila = []
        for f_ in range(n):
            s, a = nuevo(), nuevo()
            pintar(s, a, f_, dx, dy)
            fila.append((s, a))
        filas.append(fila)
    return filas, [(CX, CY)] * 5


d = {}
# (corte + fps2: lo que llega al golpe, al ritmo de SlimeAire; lo que queda despues, sin prisa)
f, o = uno(rs.aplastamiento, desde=CARGA_SALTO)
d['aplasta'] = ho.guardar_efecto(LA, 'aplasta', f, o, 5.0 / 0.3, False, 5, 14.0)
f, o = uno(rs.marea, desde=2, escala=1.0)
d['marea_rey'] = ho.guardar_efecto(LA, 'marea_rey', f, o, 12.0)
f, o = por_dirs(rs.esquirlas_corona, desde=3, escala=1.0, al_borde=True)
d['esq_corona'] = ho.guardar_efecto(LA, 'esq_corona', f, o, 7.0 / 0.2, False, 7, 14.0)
f, o = uno(rs.decreto)
d['decreto'] = ho.guardar_efecto(LA, 'decreto', f, o, 18.0 / 1.25)


# --- LO QUE VUELA: el trozo del Rey (tenido) y lo que le vuelve ---
d['trozo_bola'] = ho.guardar_efecto(LA, 'trozo_bola', marcos(lambda s, a, f_: gota(a, CX, CY, 5.0), 1), [(CX, CY)], 10.0)
d['trozo_gota'] = ho.guardar_efecto(LA, 'trozo_gota', marcos(lambda s, a, f_: gota(a, CX, CY, 3.0), 1), [(CX, CY)], 10.0)
# Al volver al Rey, se le junta: una estrellita de su gel.
d['trozo_junta'] = ho.guardar_efecto(LA, 'trozo_junta', marcos(lambda s, a, f_: estrella(a, CX, CY, (6, 3)[f_], IDX), 2), [(CX, CY)], 14.0)


# --- LA CRIA: la bola cae, se aplasta y crece un montoncito de gel que se deshace mientras ella se hace opaca (SlimeAire.T_CRECE) ---
def nace(s, a, f_):
    k = (f_ + 1) / 6.0
    charco(s, CX, CY, 9.0, 3.0, seco(f_, 2, 4) * 0.8)
    if f_ < 2:
        estrella(a, CX, CY - 6, (10, 6)[f_], IDX)
    e = 1.0 - (1.0 - k) * (1.0 - k)
    r = 5.0 + 5.0 * e
    tmp = nuevo()
    gota(tmp, CX, CY - r * 0.6, r)
    mascara = (tmp[:, :, 3] > 0) & (rs.TRAMA < (1.0 - max(0.0, (k - 0.35) / 0.65)))
    a[mascara] = tmp[mascara]


d['cria_nace'] = ho.guardar_efecto(LA, 'cria_nace', marcos(nace, 6), [(CX, CY)], 6.0 / 0.4)


# --- EL TRIBUTO: el cristal sube del caido, vuela orientado y al llegar al Rey da un destello ---
def sube_tributo(s, a, f_):
    charco(s, CX, CY, 7, 2.0, seco(f_, 2, 2))
    cristal(a, CX, CY - 4 - f_ * 3, 0.0, -1.0, 6, 2.0, C)


f, o = filas_dir(lambda s, a, f_, dx, dy: (cometa_dir(a, CX, CY, dx, dy, 12, 1, C), cristal(a, CX, CY, dx, dy, 6, 2.0, C)), 1)
d['cristal_vuela'] = ho.guardar_efecto(LA, 'cristal_vuela', f, o, 10.0)
d['tributo_sube'] = ho.guardar_efecto(LA, 'tributo_sube', marcos(sube_tributo, 3), [(CX, CY)], 3.0 / 0.18)
d['tributo_llega'] = ho.guardar_efecto(LA, 'tributo_llega', marcos(lambda s, a, f_: estrella(a, CX, CY, (14, 8)[f_], C), 2), [(CX, CY)], 2.0 / 0.3)


# --- LA CLAVADA: vuela orientada (cristal_vuela), se clava con un destello, brilla a ratos y al pisarla se parte en motas ---
def clavada(s, a, f_, brillo=False):
    sombra(s, CX, CY + 1, 3.0)
    cristal(a, CX, CY - 5, 0.15, -1.0, 9, 2.2, C)
    if brillo:
        punto(a, CX - 1, CY - 9, C[3], 2)


def clavada_vete(s, a, f_):
    for q in range(5):
        ang = q / 5.0 * math.tau
        punto(a, CX + math.cos(ang) * (2 + f_ * 2), CY - 4 - f_ * 0.5 + math.sin(ang) * (1 + f_), C[2 if f_ < 2 else 1], 2)


d['clavada_sale'] = ho.guardar_efecto(LA, 'clavada_sale', marcos(lambda s, a, f_: (clavada(s, a, f_), estrella(a, CX, CY - 4, 7, C)), 1), [(CX, CY)], 10.0)
d['clavada_dura'] = ho.guardar_efecto(LA, 'clavada_dura', marcos(lambda s, a, f_: clavada(s, a, f_, f_ == 0), 10), [(CX, CY)], 12.0, True)
d['clavada_vete'] = ho.guardar_efecto(LA, 'clavada_vete', marcos(clavada_vete, 4), [(CX, CY)], 12.0)


# --- EL PEDAZO (tenido): cae, rebota y se queda temblando; al pisarlo o al volver al Rey se aplasta ---
def pedazo(s, a, g):
    rebote = abs(math.sin(min(g, 6) * 1.2)) * max(0, 6 - g) * 0.8
    sombra(s, CX, CY + 1, 4.5)
    gota(a, CX, CY - 3 - rebote, 3.6)


def pedazo_vete(s, a, f_):
    gota(a, CX, CY - 2, max(1.0, 3.6 - f_ * 0.9))


d['pedazo_sale'] = ho.guardar_efecto(LA, 'pedazo_sale', marcos(pedazo, 7), [(CX, CY)], 7.0 / 0.32)
d['pedazo_dura'] = ho.guardar_efecto(LA, 'pedazo_dura', marcos(lambda s, a, f_: pedazo(s, a, 7), 1), [(CX, CY)], 8.0, True)
d['pedazo_vete'] = ho.guardar_efecto(LA, 'pedazo_vete', marcos(pedazo_vete, 4), [(CX, CY)], 10.0)
ho.sumar(LA, d)
