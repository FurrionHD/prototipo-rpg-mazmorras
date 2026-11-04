#!/usr/bin/env python3
# ============================================================
#  slime_abisal_efectos_pixel.py -- LOS EFECTOS DEL SLIME ABISAL (y sus mutantes, el de cielo nocturno y el de mil ojos)
#  EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art). Los mismos que hoy pintan SlimeAire (PRESION, TROMBA) y
#  AbisalAire (LLUVIA, RAYO, MIRADA, PARPADEO, ECLIPSE, AGUJERO, ESTRELLA):
#    el abisal es de OSCURIDAD con NUESTRO lenguaje (medias lunas negras rellenas con la pincelada clara rota, nada de
#    fuego negro); las estrellas y los rayos de sus mutantes son LUZ (blanco azulado, destellos de cuatro puntas).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/slime_abisal_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image

import slime_efectos_pixel as sl
import slime_veneno_efectos_pixel as vn
import escarabajo_efectos_pixel as ep
from slime_efectos_pixel import (W, H, XX, YY, TRAMA, UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella, cometa_dir,
                                 victima, gota, charco, seco, Gotas, marco, escena, sombra, lamina, elegir, coletazo,
                                 DIRS, NOM_DIR)
from slime_fuego_efectos_pixel import alrededor

NEGRO = [(8, 6, 14), (24, 20, 36), (62, 52, 88), (150, 136, 184)]
NEGRO_BORDE = (4, 3, 8)
NOCHE = [(10, 12, 30), (22, 30, 70), (46, 62, 134), (146, 176, 244)]
LUZ = [(64, 96, 206), (122, 162, 255), (204, 222, 255), (255, 255, 255)]
CIAN = (90, 240, 255)
MAGENTA = (255, 104, 240)
AZUL_GEL = [(26, 40, 90), (70, 104, 176), (140, 176, 236), (226, 238, 255)]

ABISAL, CIELO, OJOS = 's170', 'cie204', 'ojo224'


# --- PRESION DEL ABISMO: una ola de GARRAS NEGRAS en media luna que barre su linea, con la pincelada clara rota en el
# filo, y deja tinta salpicada y sombra ---
def presion(fila, var=ABISAL):
    dx, dy = DIRS[fila]
    L = 60.0 / UNIDAD
    A = (W * 0.5 - dx * L * 0.45, H * 0.55 - dy * L * 0.4)
    rad = marco(var, 'encogido', 0, fila).size[0] * 0.28
    sl.ORIGEN = (A[0] + dx * rad * 0.6, A[1] + dy * rad * 0.6)   # donde empieza la huella: su borde, no sus pies
    V = (A[0] + dx * (rad + L * 0.5), A[1] + dy * (rad + L * 0.5) + 4)
    tinta = Gotas(8, 3 + fila, 4.0, 14.0, (math.atan2(dy, dx), 1.4), sube=(5.0, 10.0), tam=(1.2, 2.0), pal=NEGRO, borde=NEGRO_BORDE)
    m, t = [], []
    carga = 4
    for f in range(carga + 16):
        s, a = nuevo(), nuevo()
        if f < carga:
            anim, fr = 'encogido', f * 2
        else:
            e = f - carga
            anim, fr = 'escupir', min(e, 7)
            for k in range(3):
                u = (e - k * 1.2) / 7.0
                if 0.0 <= u <= 1.0:
                    d = rad * 0.6 + L * u
                    lado = (-1, 1, 0)[k] * 3.5
                    x, y = A[0] + dx * d - dy * lado, A[1] + dy * d + dx * lado - 3
                    ep.media_luna(a if dy > -0.2 else s, x, y, dx, dy, 9 - k, NEGRO)
                    # la pincelada clara ROTA del filo
                    for q in range(-5, 6, 3):
                        punto(a, x + dx * (9 - k) - dy * q, y + dy * (9 - k) + dx * q, NEGRO[3])
            # detras: la sombra que deja y la tinta
            hecho = min(1.0, e / 7.0) * L
            for k in range(int(hecho / 6.0)):
                d = rad * 0.6 + k * 6.0
                charco(s, A[0] + dx * d, A[1] + dy * d, 4.0, k * 1.7, seco(e - k, 8, 5) * 0.7, NEGRO, NEGRO_BORDE)
            if e >= 5:
                tinta.pintar(s, a, V[0], V[1] - 6, min(1.0, (e - 5) / 5.0), 2.0, 1.0, e - 10)
        victima(s, *V)
        m.append(escena([s], [(marco(var, anim, fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- TROMBA ABISAL: sobre cada uno cae un EMBUDO de medias lunas negras que gira y se estrecha (cabeza negra con el ojo
# claro del eclipse) y a sus pies se abre un remolino de brazos negros ---
def aro(a, cx, cy, rx, ry, giro, grueso, abertura=4.4):
    ang = np.arctan2((YY - cy) / max(ry, 0.5), (XX - cx) / max(rx, 0.5))
    d = np.hypot((XX - cx) / max(rx, 0.5), (YY - cy) / max(ry, 0.5))
    rel = (ang - giro) % (2 * np.pi)
    en = (rel < abertura) & (d <= 1.0) & (d >= 1.0 - grueso / max(rx, 1.0))
    poner(a, en, NEGRO[1])
    poner(a, en & (rel < abertura * 0.25), NEGRO[2])
    poner(a, en & (rel < abertura * 0.08), NEGRO[3])


def remolino_negro(a, cx, cy, r, giro, fuerza, pal=NEGRO, borde=NEGRO_BORDE):
    if fuerza <= 0:
        return
    gordo = max(1.0, r / 23.0)   # (engordan con el remolino: si no, a su tamano de verdad son aros finos)
    for k in range(3):
        coletazo(a, cx, cy, giro + k * math.tau / 3.0, r, 0.0, 2.2 * fuerza, 1.0, (4.0 * fuerza + 1.0) * gordo, pal, borde)   # (solo el grueso: 2,2 es el angulo)


def tromba_en(s, a, vx, vy, e):
    """La tromba sobre UN objetivo, con (vx, vy) = sus pies; e = marcos desde que empieza a caer."""
    baja = min(1.0, (e + 1) / 4.0)
    fuerza = seco(e, 8, 5)
    if fuerza <= 0:
        return
    for k in range(6):
        alto = (40 - k * 6) * baja + 8
        r = 3.0 + k * 1.6
        aro(a, vx, vy - alto, r, r * 0.45, e * 0.9 + k, 2.0 * fuerza + 0.5)
    if e < 6:
        disco(a, vx, vy - 48 * baja - 6, 3.0, NEGRO[0])
        punto(a, vx - 1, vy - 48 * baja - 7, LUZ[2], 2)
    if e >= 3:
        remolino_negro(s, vx, vy + 1, 6.0 + (e - 3) * 1.2, -e * 0.8, fuerza)
    if e == 3:
        estrella(a, vx, vy - 9, 8, NEGRO)


def tromba(var=ABISAL):
    A = (W * 0.32, H * 0.42)
    vict = [(W * 0.62, H * 0.72), (W * 0.82, H * 0.5)]
    m, t = [], []
    for f in range(22):
        s, a = nuevo(), nuevo()
        for i, (vx, vy) in enumerate(vict):
            e = f - 3 - i * 2
            if e >= 0:
                tromba_en(s, a, vx, vy, e)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), 1), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LAS ESTRELLAS Y LOS RAYOS (luz) ---
def rayo(a, p0, p1, u, grueso, pal=LUZ, bordes=None):
    """Un rayo GORDO de p0 a p1 trazado hasta 'u'; nucleo blanco, cuerpo azul claro y borde (o cian/magenta)."""
    x0, y0 = p0
    vx, vy = p1[0] - x0, p1[1] - y0
    L = math.hypot(vx, vy) or 1.0
    dx, dy = vx / L, vy / L
    s_ = (XX - x0) * dx + (YY - y0) * dy
    l_ = (XX - x0) * (-dy) + (YY - y0) * dx
    en = (s_ >= 0) & (s_ <= L * u)
    poner(a, en & (np.abs(l_) <= grueso), pal[1])
    if bordes:
        poner(a, en & (l_ > grueso * 0.5) & (l_ <= grueso), bordes[0])
        poner(a, en & (l_ < -grueso * 0.5) & (l_ >= -grueso), bordes[1])
    poner(a, en & (np.abs(l_) <= grueso * 0.55), pal[2])
    poner(a, en & (np.abs(l_) <= grueso * 0.25), pal[3])


def estrellas_alrededor(A, n, r, sem=1):
    rnd = random.Random(sem)
    return [(A[0] + math.cos(i / n * math.tau + rnd.uniform(-0.3, 0.3)) * r * rnd.uniform(0.8, 1.0),
             A[1] + math.sin(i / n * math.tau + rnd.uniform(-0.3, 0.3)) * r * 0.8 * rnd.uniform(0.8, 1.0)) for i in range(n)]


def estrella_suelo(s, a, x, y, f, fuerza=1.0):
    """La estrella pequeña que flota un pelo sobre el suelo y titila, con su resplandor en el suelo."""
    d = np.hypot(XX - x, YY - y)
    poner(s, (d < 5) & (TRAMA < 0.35 * fuerza), LUZ[0])
    estrella(a, x, y - 4 + (f % 4 == 0), (5, 4, 6, 4)[f % 4] * fuerza, LUZ)


def constelacion(var=CIELO, mirada=False):
    A = (W * 0.5, H * 0.5)
    rad = marco(var, 'idle', 0, 0).size[0] * 0.3
    pts = estrellas_alrededor(A, 5, rad + 22.0, 3)
    vict = alrededor(A, var, 30.0, 3, 1.0)
    centro = (A[0] + 4, A[1] + 30)
    m, t = [], []
    anim = 'fijar' if mirada else 'constelar'
    for f in range(18):
        s, a = nuevo(), nuevo()
        traza = min(1.0, (f - 1) / 4.0)
        fuerza = seco(f - 5, 6, 5)
        for i, p in enumerate(pts):
            estrella_suelo(s, a, p[0], p[1], f, 1.0 if f < 12 else max(0.0, 1 - (f - 12) / 4))
            if traza > 0 and fuerza > 0:
                q = centro if mirada else pts[(i + 1) % len(pts)]
                g = (1.2 if f < 5 else 2.6) * fuerza + (1.4 if mirada else 0.0)
                rayo(a, (p[0], p[1] - 4), (q[0], q[1] - 4), traza, g, LUZ, (CIAN, MAGENTA) if mirada else None)
                if 5 <= f <= 6:
                    estrella(a, q[0], q[1] - 4, 9, LUZ)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, anim if not mirada or f < 5 else 'mirada', min(f, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LLUVIA DE ESTRELLAS: en cada punto del circulo primero se enciende su marca en el suelo y crece; una estrella fugaz
# baja en diagonal con su cola y cae ahi, una tras otra: destello, luz que se abre por el suelo y motas que suben ---
def fugaz(s, a, px, py, e, i=0):
    """Una estrella fugaz que cae en (px, py); e = marcos desde que se enciende su marca (a los 6 toca el suelo)."""
    if e < 6:
        d = np.hypot(XX - px, YY - py)
        poner(s, (d < 2 + e * 0.8) & (TRAMA < 0.45), LUZ[0])
        poner(s, (d < 1 + e * 0.4) & (TRAMA < 0.6), LUZ[1])
        u = (e + 1) / 6.0
        sx, sy = px - 40 * (1 - u), py - 60 * (1 - u)
        cometa_dir(a, sx, sy, 0.55, 0.83, 16, 1, LUZ)
        estrella(a, sx, sy, 4, LUZ)
    else:
        g = e - 6
        if g < 3:
            estrella(a, px, py - 3, (12, 18, 9)[g], LUZ)
        vivo = seco(g, 3, 5)
        d = np.hypot(XX - px, YY - py)
        poner(s, (d < 4 + g * 1.5) & (TRAMA < 0.5 * vivo * (1 - g / 9.0)), LUZ[1])
        poner(s, (d < 2 + g * 0.6) & (TRAMA < 0.6 * vivo), LUZ[2])
        for k in range(5):
            ang = k / 5 * math.tau + i
            if g < 8:
                punto(a, px + math.cos(ang) * (3 + g * 1.5), py - g * 2.2 + math.sin(ang) * 2, LUZ[3 if g < 4 else 2], 2)


def lluvia(var=CIELO, radio_mundo=70.0, n=5):
    A = (W * 0.25, H * 0.38)
    R = radio_mundo / UNIDAD * 0.55
    C = (W * 0.62, H * 0.62)
    rnd = random.Random(9)
    puntos = [(C[0] + math.cos(i * 2.4) * R * math.sqrt((i + 0.5) / n), C[1] + math.sin(i * 2.4) * R * 0.8 * math.sqrt((i + 0.5) / n)) for i in range(n)]
    vict = [(C[0] - 10, C[1] + 6), (C[0] + 22, C[1] - 12)]
    m, t = [], []
    for f in range(26):
        s, a = nuevo(), nuevo()
        for i, (px, py) in enumerate(puntos):
            e = f - i * 3
            if e >= 0:
                fugaz(s, a, px, py, e, i)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'estrellas' if f < 4 else 'lluvia', min(f, 7), 1), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- ECLIPSE: sobre su cabeza se enciende una estrella y una LUNA NEGRA se le pone delante hasta dejar solo el anillo de
# luz; a la vez SU NOCHE se derrama por el suelo desde sus pies (cielo oscuro con estrellas que se van apagando y un borde
# de medias lunas negras con la pincelada rota). Aguanta y se le recoge dentro ---
def eclipse(var=CIELO, radio_mundo=80.0):
    A = (W * 0.5, H * 0.52)
    sl.ORIGEN = A
    R = radio_mundo / UNIDAD * 0.85
    spr0 = marco(var, 'eclipse', 0, 0)
    cabeza = (A[0], A[1] - spr0.size[1] * 0.62)
    rnd = random.Random(4)
    cielo = [(rnd.uniform(0, math.tau), rnd.uniform(0.2, 0.95), rnd.random()) for _ in range(18)]
    vict = alrededor(A, var, R * 0.7, 3, 0.7)
    m, t = [], []
    for f in range(22):
        s, a = nuevo(), nuevo()
        sube = min(1.0, (f + 1) / 6.0)
        baja = 1.0 if f < 15 else max(0.0, 1.0 - (f - 15) / 6.0)
        r = R * sube * baja
        if r > 1:
            d = np.hypot(XX - A[0], YY - A[1])
            poner(s, (d < r) & (TRAMA < 0.85), NOCHE[1])
            poner(s, (d < r) & (TRAMA < 0.35), NOCHE[0])
            for ang, uu, fase in cielo:
                if uu * R < r and ((f * 0.2 + fase) % 1.0) < 0.7 - f * 0.02:
                    punto(s, A[0] + math.cos(ang) * uu * R, A[1] + math.sin(ang) * uu * R * 0.85, LUZ[2], 2)
            for k in range(9):
                ang = k / 9 * math.tau + f * 0.15
                # (crecen con su noche: en la grande, si no, se quedan en palitos)
                g_ = max(1.0, r / 59.0)
                coletazo(s, A[0] + math.cos(ang) * r, A[1] + math.sin(ang) * r, ang + 1.57, 5.0 * g_, 0.0, 1.6, 1.0, 3.0 * g_, NEGRO, NEGRO_BORDE)
        # la estrella y la luna negra
        if f < 19:
            luz = min(1.0, (f + 1) / 3.0)
            disco(a, cabeza[0], cabeza[1], 7 * luz, LUZ[2])
            disco(a, cabeza[0], cabeza[1], 5 * luz, LUZ[3])
            cubre = min(1.0, max(0.0, (f - 2) / 5.0))
            disco(a, cabeza[0] + 12 * (1 - cubre), cabeza[1] - 2 * (1 - cubre), 5.6, NEGRO[0])
            if f < 3:
                estrella(a, cabeza[0], cabeza[1], 10, LUZ)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'eclipse', min(f, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- AGUJERO NEGRO: una bolita de noche sale de el y cae en el sitio; alli se abre un REMOLINO de cielo nocturno (brazos
# azul noche con el filo claro) que se traga las estrellas en espiral hacia un centro negro con su anillo de luz; tira dos
# veces y se cierra en un punto con un destello ---
def agujero(var=CIELO, radio_mundo=70.0):
    A = (W * 0.27, H * 0.42)
    C = (W * 0.64, H * 0.62)
    sl.ORIGEN = C
    R = radio_mundo / UNIDAD * 0.55
    rnd = random.Random(6)
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(0.5, 1.0)) for _ in range(12)]
    vict = [(C[0] - R * 0.7, C[1] + 4), (C[0] + R * 0.6, C[1] - R * 0.4)]
    m, t = [], []
    vuelo = 5
    for f in range(vuelo + 22):
        s, a = nuevo(), nuevo()
        if f < vuelo:
            u = (f + 1) / vuelo
            x, y = A[0] + (C[0] - A[0]) * u, A[1] - 8 + (C[1] - A[1] + 8) * u - 20 * 4 * u * (1 - u)
            gota(a, x, y, 3.5, NOCHE, NEGRO_BORDE)
            punto(a, x - 1, y - 1, LUZ[3])
        else:
            e = f - vuelo
            abre = min(1.0, (e + 1) / 4.0) * (1.0 if e < 16 else max(0.0, 1 - (e - 16) / 4.0))
            tiron = 1.0 + 0.15 * math.sin(e * 0.8)
            remolino_negro(s, C[0], C[1], R * 0.7 * abre * tiron, -e * 0.5, abre, NOCHE, NOCHE[0])
            remolino_negro(s, C[0], C[1], R * 0.4 * abre * tiron, -e * 0.5 + 1.0, abre, NOCHE, NOCHE[0])
            if abre > 0.05:
                d = np.hypot(XX - C[0], YY - C[1])
                nucleo = max(1.0, R * 0.7 / 23.0)
                poner(s, d < (4.5 * abre + 0.5) * nucleo, LUZ[1])
                poner(s, d < 3.5 * abre * nucleo, NEGRO[0])
            for ang, uu in motas:
                k = ((e / 10.0) + uu) % 1.0
                rr = R * 0.7 * (1.0 - k) * abre   # (dentro del remolino: no mas alla de su borde)
                aa = ang + k * 4.0
                if rr > 3:
                    punto(a, C[0] + math.cos(aa) * rr, C[1] + math.sin(aa) * rr * 0.8, LUZ[3 if k > 0.5 else 2], 2)
            if 20 <= e <= 21:
                estrella(a, C[0], C[1] - 2, (12, 7)[e - 20], LUZ)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), 1), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- PARPADEO CEGADOR: un FOGONAZO de luz en abanico que sale de el por el cono, con rayos y motas ---
def abanico_luz(a, cx, cy, eje, R, apertura, e):
    d = np.hypot(XX - cx, YY - cy)
    ang = np.arctan2(YY - cy, XX - cx)
    rel = np.abs((ang - eje + np.pi) % (2 * np.pi) - np.pi)
    dentro = (rel < math.radians(apertura) * 0.5) & (d < R * min(1.0, (e + 1) / 3.0))
    u = d / max(R, 1.0)
    rayo_m = np.sin(ang * 19.0 + e * 0.6) > 0.3
    fuerza = max(0.0, 1.0 - e / 8.0)
    poner(a, dentro & (TRAMA < (1.0 - u) * fuerza * 1.1) & (u > 0.5), LUZ[0])
    poner(a, dentro & (TRAMA < (1.0 - u) * fuerza * 1.5) & (u <= 0.5), LUZ[1])
    poner(a, dentro & rayo_m & (u < 0.8) & (TRAMA < fuerza * 1.2), LUZ[2])
    poner(a, dentro & (u < 0.16) & (fuerza > 0.4), LUZ[3])


def parpadeo(fila, var=OJOS, motas_objetivos=True, escala=0.85, alto_ojo=None):
    dx, dy = DIRS[fila]
    R = 70.0 / UNIDAD * escala
    A = (W * 0.5 - dx * R * 0.4, H * 0.52 - dy * R * 0.35)
    spr0 = marco(var, 'cegar', 0, fila)
    rad = spr0.size[0] * 0.28
    alto = rad * 0.8 if alto_ojo is None else alto_ojo
    ojo = (A[0] + dx * rad * 0.6, A[1] + dy * rad * 0.4 - alto)
    sl.ORIGEN = (ojo[0], ojo[1] + alto)   # el vertice de su huella, a ras de suelo
    eje = math.atan2(dy, dx)
    vict = [(A[0] + math.cos(eje + k) * (rad + 18), A[1] + math.sin(eje + k) * (rad + 18) + 3) for k in (-0.4, 0.35)]
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        e = f - 2
        if e >= 0:
            abanico_luz(a if dy > -0.2 else s, ojo[0], ojo[1], eje, R, 120.0, e)
            if e < 3:
                estrella(a, ojo[0], ojo[1], (12, 18, 10)[e], LUZ)
            for v in vict if motas_objetivos else []:
                sl_v = e - 1
                if 0 <= sl_v < 8:
                    for k in range(3):
                        punto(a, v[0] - 5 + k * 5, v[1] - 22 - sl_v, LUZ[3] if sl_v < 4 else LUZ[2], 2)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'cegar', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def estrella_quieta():
    A = (W * 0.5, H * 0.55)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        if f < 9:
            estrella_suelo(s, a, A[0], A[1], f)
        elif f < 11:
            estrella(a, A[0], A[1] - 4, (10, 6)[f - 9], LUZ)
        m.append(escena([s], [], [a]))
        t.append(1000 // 8)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    sl.GEL, sl.GEL_BORDE = AZUL_GEL, (10, 16, 40)
    vn.GEL = AZUL_GEL
    ba = {d: sl.basico(d, ABISAL) for d in (1, 4)}
    rv = sl.reventon(1, 35.0, ABISAL)
    pr = {d: presion(d) for d in range(5)}
    tr = tromba()
    ll = lluvia()
    co = constelacion()
    ec = eclipse()
    ag = agujero()
    es = estrella_quieta()
    pa = {d: parpadeo(d) for d in (0, 2, 4)}
    mi = constelacion(OJOS, True)
    filas = [
        *[('ABISAL\nbasico\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        ('ABISAL\nReventon', elegir(rv[0], (3, 8, 12, 14, 17, 25))),
        *[('ABISAL\nPresion del abismo\nhacia el ' + NOM_DIR[d], elegir(pr[d][0], (2, 5, 7, 9, 12, 17))) for d in range(5)],
        ('ABISAL\nTromba abisal', elegir(tr[0], (3, 4, 6, 8, 11, 15))),
        ('CIELO NOCTURNO\nLluvia de estrellas\n(mil ojos: igual,\nmas grande)', elegir(ll[0], (2, 5, 8, 11, 15, 21))),
        ('CIELO NOCTURNO\nConstelacion', elegir(co[0], (0, 2, 4, 6, 9, 14))),
        ('CIELO NOCTURNO\nEclipse\n(mil ojos: igual,\nmas grande)', elegir(ec[0], (1, 3, 6, 10, 15, 19))),
        ('CIELO NOCTURNO\nAgujero negro\n(mil ojos: igual,\nmas grande)', elegir(ag[0], (2, 6, 9, 13, 19, 25))),
        ('CIELO NOCTURNO\nla estrella que deja', elegir(es[0], (0, 2, 4, 6, 9, 10))),
        *[('MIL OJOS\nParpadeo cegador\nhacia el ' + NOM_DIR[d], elegir(pa[d][0], (2, 3, 4, 6, 8, 11))) for d in (0, 2, 4)],
        ('MIL OJOS\nMirada estelar', elegir(mi[0], (0, 2, 4, 6, 9, 14))),
    ]
    lamina(filas, os.path.join(SALIDA, 'slime_abisal.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], rv, pr[1], pr[2], tr, ll, co, ec, ag, es, pa[2], mi]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'slime_abisal.gif'), 3)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
