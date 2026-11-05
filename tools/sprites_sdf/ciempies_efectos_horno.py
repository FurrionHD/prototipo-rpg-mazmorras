#!/usr/bin/env python3
# ============================================================
#  ciempies_efectos_horno.py -- HORNEA LOS EFECTOS DEL CIEMPIES Y SUS MUTANTES (Bicefalo y Nudo carmesi), los de su lamina aprobada.
#  Sobre el cuerpo que recibe, (CX, CY) = sus pies: la tijera y las patitas del normal, el gancho de cada cabeza, los apretones.
#  Desde quien lo hace, (CX, CY) = sus pies: la Pinza y el Derrumbe (salen de su gesto, TacticoPixel).
#    python tools/sprites_sdf/ciempies_efectos_horno.py
# ============================================================
import math
import random

import escarabajo_efectos_pixel as ep
import ciempies_efectos_pixel as ce       # (trae su lienzo: va antes que los demas)
import slime_efectos_pixel as sl

import horno_efectos as ho
from slime_efectos_pixel import nuevo, estrella

LA = 'ciempies'
W, H = ce.W, ce.H
CX, CY = W // 2, H // 2
DIRS = sl.DIRS[:5]
ORIGENES = [(CX, CY)] * 5
ALTO = 10     # el pecho de quien recibe, sobre sus pies


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


d = {}


# --- EL BASICO DEL NORMAL: los dos ganchos se cruzan como una tijera (se cierran en el marco 3) ---
def tijera(s, a, e, dx, dy, i):
    ang = math.atan2(dy, dx)
    if e < 5:
        ce.gancho(a, CX, CY - ALTO, 1.0, ang, e, 5, ce.GANCHO)
        ce.gancho(a, CX, CY - ALTO, -1.0, ang, e, 5, ce.GANCHO)
    if e in (3, 4):
        estrella(a, CX, CY - ALTO, (11, 7)[e - 3], ce.GANCHO)
    if e >= 3:
        ce.gotas(a, CX, CY - ALTO + 2, e - 3, i * 5 + 1, n=2)


f, o = filas_dir(tijera, 7)
d['tijera'] = ho.guardar_efecto(LA, 'tijera', f, o, 14.0)


# --- CADA CABEZA, SU GANCHO: naranja por un lado y turquesa por el otro (se cierra en el marco 2) ---
def gancho_de(pal, lado):
    def pintar(s, a, e, dx, dy, i):
        ang = math.atan2(dy, dx)
        if e < 4:
            ce.gancho(a, CX, CY - ALTO, lado, ang, e, 4, pal)
        if e == 2:
            estrella(a, CX, CY - ALTO, 9, pal)
        if e >= 2:
            ce.gotas(a, CX, CY - ALTO + 2, e - 2, i + 4, n=2)
    return pintar


f, o = filas_dir(gancho_de(ce.NARANJA, 1.0), 6)
d['gancho_a'] = ho.guardar_efecto(LA, 'gancho_a', f, o, 14.0)
f, o = filas_dir(gancho_de(ce.TURQUESA, -1.0), 6)
d['gancho_b'] = ho.guardar_efecto(LA, 'gancho_b', f, o, 14.0)


# --- LA OLEADA: la rafaga de patitas, de arriba abajo ---
def patitas(s, a, e):
    ce._patitas(a, CX, CY, e, 11, ce.GANCHO)
    if e in (2, 4):
        ce.gotas(a, CX, CY - 8, e - 2, 3, n=2)


f, o = marcos(patitas, 9)
d['patitas'] = ho.guardar_efecto(LA, 'patitas', f, o, 18.0)


# --- EL APRETON: dos medias lunas que se cierran sobre la presa ---
def apreton_de(pal):
    def pintar(s, a, e):
        ce._apreton(a, CX, CY, e, pal)
    return pintar


for nombre, pal in (('apreton', ce.GANCHO), ('apreton_a', ce.NARANJA), ('apreton_b', ce.TURQUESA)):
    f, o = marcos(apreton_de(pal), 5)
    d[nombre] = ho.guardar_efecto(LA, nombre, f, o, 14.0)

# --- LA PINZA: cada cabeza barre SU mitad del cono y se encuentran delante. R = forma_radio ---
R_PINZA = 40.0 / ce.UNIDAD
MED = math.radians(60)


def pinza(s, a, e, dx, dy, i):
    ang = math.atan2(dy, dx)
    if e < 4:
        u = (e + 1) / 4.0
        ce.arco(a, CX, CY - 4, R_PINZA * 0.78, ang - MED + MED * u, MED * min(1.0, u * 1.4), 1.0, 8.0, ce.NARANJA)
        ce.arco(a, CX, CY - 4, R_PINZA * 0.78, ang + MED - MED * u, MED * min(1.0, u * 1.4), -1.0, 8.0, ce.TURQUESA)
    if e in (3, 4):
        estrella(a, CX + dx * R_PINZA * 0.78, CY - 4 + dy * R_PINZA * 0.78, 12 if e == 3 else 8, ce.NARANJA if e == 3 else ce.TURQUESA)


f, o = filas_dir(pinza, 6)
d['pinza'] = ho.guardar_efecto(LA, 'pinza', f, o, 14.0)

# --- EL DERRUMBE: mientras se alza, piedrecitas que saltan a ras de suelo; al caer, grietas y onda de polvo ---
_rnd = random.Random(5)
PIEDRAS = [(_rnd.uniform(0, math.tau), _rnd.uniform(26, 40), _rnd.uniform(1.3, 2.4), _rnd.uniform(2.0, 3.0)) for _i in range(12)]
MOTAS = [(i / 22.0 * math.tau + _rnd.uniform(-0.12, 0.12), _rnd.uniform(3.2, 5.0)) for i in range(22)]
R_DERRUMBE = 70.0 / ce.UNIDAD


def derrumbe_carga(s, a, f_):
    for ang, r, tam, vel in PIEDRAS:
        ph = (f_ * 0.125 * round(vel) + ang) % 1.0
        alto = math.sin(ph * math.pi) * 7.0
        ep.bolita(s, CX + math.cos(ang) * r, CY + math.sin(ang) * r * 0.62 - alto, tam * 0.8, ce.TIERRA)


f, o = marcos(derrumbe_carga, 8)
d['derrumbe_carga'] = ho.guardar_efecto(LA, 'derrumbe_carga', f, o, 10.0, True)


def derrumbe(s, a, g):
    ce._grietas(s, CX, CY, R_DERRUMBE, 3, max(0.0, 1.0 - max(g - 7, 0) / 6.0))
    for ang, rr in MOTAS:
        dist = 30.0 + g * 5.0
        tam = rr * max(0.0, 1.0 - g / 10.0)
        if tam > 0.7 and dist < R_DERRUMBE + 6:
            ep.bolita(s if math.sin(ang) < 0 else a, CX + math.cos(ang) * dist, CY + 2 + math.sin(ang) * dist * 0.62, tam, ce.POLVO)


f, o = marcos(derrumbe, 14)
d['derrumbe'] = ho.guardar_efecto(LA, 'derrumbe', f, o, 12.0)

ho.sumar(LA, d)
