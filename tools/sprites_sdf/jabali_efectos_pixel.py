#!/usr/bin/env python3
# ============================================================
#  jabali_efectos_pixel.py -- LOS EFECTOS DEL JABALI (y sus mutantes, Colmillo de cristal y Jabali ancestral) EN PIXEL
#  ART (04/11/2026, memoria efectos-a-pixel-art). Los mismos que hoy pinta BestiaAire (COLMILLO, CORNADA, SURCO, CHOQUE,
#  PISOTON) y lo que eligio el jefe el 31/10 para los mutantes: el SURCO de esquirlas cian y el ESTALLIDO de los colmillos
#  en la Cornada de cristal, las ESPORAS del musgo, las DRUSAS (el reflejo) y la QUEMA de la chepa: arde poco a poco con
#  llamas por fotogramas, no de golpe y nunca bolas (lo rechazo asi, memoria jabali-mutante).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/jabali_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO MAS GRANDE: el ancestral mide 132: antes de traer nada mas, que las demas piezas lo cojan ya.
W, H = 250, 200
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import slime_veneno_efectos_pixel as vn  # noqa: E402
import slime_fuego_efectos_pixel as fg  # noqa: E402
import rata_efectos_pixel as rt  # noqa: E402
from slime_efectos_pixel import (UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella, cometa_dir, victima, gota,  # noqa: E402
                                 charco, seco, Gotas, lamina, elegir, coletazo, cristal, DIRS, NOM_DIR)
from rata_efectos_pixel import marco, escena  # noqa: E402

NORMAL, COLMILLO, ANCESTRAL = 'jabali_sdf', 'jabali_sdf_colmillo', 'jabali_sdf_ancestral'
HUESO = [(112, 100, 80), (186, 174, 148), (232, 224, 204), (255, 255, 246)]
HUESO_BORDE = (40, 34, 28)
TIERRA = [(34, 28, 24), (62, 50, 40), (104, 86, 66), (146, 124, 96)]
POLVO = ep.POLVO
CIAN = sl.CRISTAL
ESPORA = [(70, 72, 34), (122, 122, 52), (176, 170, 84), (228, 224, 150)]
GRIETA_C = (16, 14, 18)
SANGRE = rt.SANGRE
SANGRE_BORDE = rt.SANGRE_BORDE


# EL HOCICO medido en su dibujo: el pixel mas adelantado hacia donde mira, relativo a sus pies (nada de cuentas a ojo).
def frente_de(var, anim, fila, dx, dy, f=0):
    spr = np.array(marco(var, anim, f, fila))
    ys, xs = np.nonzero(spr[:, :, 3] > 0)
    h0, w0 = spr.shape[:2]
    i = int(np.argmax((xs - w0 / 2) * dx + (ys - h0 / 2) * dy))
    return xs[i] - w0 // 2, ys[i] - h0 // 2


def alcance(var, anim, fila, dx, dy):
    fx, fy = frente_de(var, anim, fila, dx, dy)
    return math.hypot(fx, fy)


# --- EL COLMILLO: media luna de hueso que engancha de ABAJO ARRIBA por el lado de quien embiste (filo vivo delante, y
# detras se oscurece y se deshace), con su destello en la punta ---
def enganche(a, x, y, dx, dy, r, e, n, pal=HUESO, borde=HUESO_BORDE, grueso=8.0):
    lado = 1.0 if dx >= 0 else -1.0
    eje = math.atan2(dy, dx) - lado * math.pi / 2     # gira hacia arriba
    u = (e + 1) / float(n)
    frente = (-1.3 + 2.6 * u) * lado
    coletazo(a, x - dx * r * 0.4, y - dy * r * 0.4, eje + lado * math.pi / 2 - lado * 1.0, r, frente, 1.8 * min(1.0, u * 1.8), lado, grueso, pal, borde)
    ang = eje + lado * math.pi / 2 - lado * 1.0 + frente
    return x - dx * r * 0.4 + math.cos(ang) * r, y - dy * r * 0.4 + math.sin(ang) * r


def basico(fila, var=NORMAL):
    dx, dy = DIRS[fila]
    al = alcance(var, 'basico', fila, dx, dy)
    A = (W * 0.5 - dx * al * 0.7, H * 0.55 - dy * al * 0.6)
    V = (A[0] + dx * (al + 8), A[1] + dy * (al + 8) + 6)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        e = f - 3
        if 0 <= e < 5:
            px, py = enganche(a, V[0], V[1] - 9, dx, dy, 10.0, e, 5)
            if e in (2, 3):
                estrella(a, px, py, 7, HUESO)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'basico', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LA CORNADA: lo mismo, mas grande y mas lento, con terrones, un desgarro en la punta, y al que engancha lo LEVANTA un
# palmo (sube y cae) ---
def cornada(fila, var=NORMAL):
    dx, dy = DIRS[fila]
    al = alcance(var, 'cornada', fila, dx, dy)
    A = (W * 0.5 - dx * al * 0.7, H * 0.55 - dy * al * 0.6)
    V = (A[0] + dx * (al + 8), A[1] + dy * (al + 8) + 6)
    terrones = Gotas(8, 5 + fila, 8.0, 22.0, (math.atan2(dy, dx), 1.0), sube=(8.0, 16.0), tam=(1.2, 2.0), pal=TIERRA, borde=TIERRA[0])
    sang = Gotas(5, 8 + fila, 6.0, 14.0, (-1.57, 0.8), sube=(5.0, 10.0), tam=(1.0, 1.6), pal=SANGRE, borde=SANGRE_BORDE)
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        e = f - 4
        sube = 0.0
        if e >= 2:
            k = (e - 2) / 8.0
            sube = 12.0 * 4 * k * (1 - k) if k < 1 else 0.0
            if k < 1:
                sl.sombra(s, V[0], V[1] + 1, 5.0)
        if 0 <= e < 7:
            px, py = enganche(a, V[0], V[1] - 11, dx, dy, 15.0, e, 7, grueso=11.0)
            if e in (3, 4):
                estrella(a, px, py, (10, 7)[e - 3], HUESO)
        if e >= 0:
            terrones.pintar(s, a, V[0], V[1], min(1.0, e / 6.0), 3.0, 1.0, e - 6)
        if e >= 3:
            sang.pintar(s, a, V[0], V[1] - 12 - sube, min(1.0, (e - 3) / 5.0), 1.0, 1.0, 99)
        capa = nuevo()
        ep.victima(capa, V[0], V[1] - sube)
        s[capa[:, :, 3] > 0] = capa[capa[:, :, 3] > 0]
        m.append(escena([s], [(marco(var, 'cornada', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- LA EMBESTIDA: arrolla su linea: las rodadas de las pezuñas, terrones que saltan a los lados y polvo; a quien arrolla,
# el frente del choque y un chorro de polvo hacia donde sale despedido ---
def rodadas(s, A, dx, dy, hecho, f, corre, largo, medio=6.5):
    s_ = (XX - A[0]) * dx + (YY - A[1]) * dy
    l_ = (XX - A[0]) * (-dy) + (YY - A[1]) * dx
    u = np.clip(s_ / max(largo, 1.0), 0, 1)
    vivo = np.clip(1.0 - (f - u * corre - 9.0) / 6.0, 0.0, 1.0)
    en = (s_ >= 0) & (s_ <= hecho) & (TRAMA < vivo * 1.15)
    for lado in (-1, 1):
        c = lado * medio + np.sin(s_ * 0.5 + lado) * 0.7
        d = np.abs(l_ - c)
        poner(s, en & (d < 2.2), TIERRA[0])
        poner(s, en & (d >= 2.2) & (d < 3.2), TIERRA[2])


def embestida(fila, var=NORMAL):
    dx, dy = DIRS[fila]
    L = 90.0 / UNIDAD
    al = alcance(var, 'arrollar', fila, dx, dy)
    A = (W * 0.5 - dx * L * 0.5, H * 0.55 - dy * L * 0.45)
    V = (A[0] + dx * (L * 0.45 + al) - dy * 2, A[1] + dy * (L * 0.45 + al) + 6 + dx * 2)
    rnd = random.Random(3 + fila)
    terrones = [(rnd.uniform(0.05, 1.0), rnd.choice((-1, 1)), rnd.uniform(8, 16)) for _ in range(14)]
    m, t = [], []
    corre = 8
    pegado = False
    for f in range(corre + 12):
        s, a = nuevo(), nuevo()
        u = min(1.0, (f + 1) / float(corre))
        d = L * u
        x, y = A[0] + dx * d, A[1] + dy * d
        rodadas(s, A, dx, dy, d, f, corre, L)
        ep._huellas_polvo(s, A[0], A[1], dx, dy, d, 23 + fila, 8.0)
        for uu, lado, sube in terrones:
            e = f - uu * corre
            if 0 <= e < 6:
                k = e / 5.0
                ox = -dy * lado * (7 + k * 9)
                oy = dx * lado * (7 + k * 9)
                gota(a, A[0] + dx * L * uu + ox, A[1] + dy * L * uu + oy - sube * 4 * k * (1 - k), 1.5, TIERRA, TIERRA[0])
        # el choque: cuando su hocico llega al que esta en medio
        dist = (V[0] - A[0]) * dx + (V[1] - A[1]) * dy
        e = (d + al - dist) / (L / corre)
        vx, vy = V
        if e >= 0:
            lleva = min(1.0, e / 5.0) * 26
            # sale despedido A UN LADO de su linea, que el cuerpo no se lo coma
            lado = 24 * min(1.0, e / 3.0)
            vx, vy = V[0] + dx * lleva * 0.5 - dy * lado, V[1] + dy * lleva * 0.5 + dx * lado * 0.8
            if e < 2:
                estrella(a, vx, vy - 9, (12, 8)[int(e)], HUESO)
            if e < 8:
                k = e / 8.0
                for q in range(5):
                    ep.bolita(s, vx - dx * q * 3 + dy * q, vy - dy * q * 3 - dx * q - k * 3, 3.5 * (1 - k) + 0.4, POLVO)
        victima(s, vx, vy)
        m.append(escena([s], [(marco(var, 'arrollar', f, fila), x, y, 0)], [a]))
        t.append(1000 // 16)
    return m, t


# --- EL PISOTON: los dos pisotones: grietas cortas desde sus patas y un anillo de polvo a ras; el segundo agranda las
# grietas del primero ---
def grietas(s, x, y, largo, sem, n=7):
    rnd = random.Random(sem)
    for i in range(n):
        ang = i / n * math.tau + rnd.uniform(-0.3, 0.3)
        px, py = x + math.cos(ang) * 12, y + math.sin(ang) * 8
        pasos = int(largo * rnd.uniform(0.6, 1.0) / 2.5)
        for p in range(pasos):
            ang += rnd.uniform(-0.45, 0.45)
            px, py = px + math.cos(ang) * 2.5, py + math.sin(ang) * 2.0
            punto(s, px, py, GRIETA_C, 2 if p < pasos * 0.6 else 1)


def anillo_polvo(s, a, x, y, e, r0, sem):
    rnd = random.Random(sem)
    for i in range(14):
        ang = i / 14 * math.tau + rnd.uniform(-0.15, 0.15)
        d = r0 + e * 3.0
        rr = rnd.uniform(3.2, 4.8) * max(0.0, 1.0 - e / 7.0)
        if rr > 0.7:
            ep.bolita(s if math.sin(ang) < 0 else a, x + math.cos(ang) * d, y + math.sin(ang) * d * 0.7 - e * 0.5, rr, POLVO)


def pisoton(fila=1, var=NORMAL):
    A = (W * 0.5, H * 0.52)
    al = alcance(var, 'pisoton', fila, *DIRS[fila])
    R = max(30.0 / UNIDAD, al + 6)
    vict = [(A[0] + math.cos(0.8 + k * math.tau / 3) * (R + 8), A[1] + math.sin(0.8 + k * math.tau / 3) * (R + 8) * 0.8 + 4) for k in range(3)]
    m, t = [], []
    golpes = (4, 11)
    for f in range(24):
        s, a = nuevo(), nuevo()
        for k, g in enumerate(golpes):
            e = f - g
            if e >= 0:
                vivo = seco(f - golpes[1], 8, 4)
                if vivo > 0:
                    grietas(s, A[0], A[1] + 2, 12.0 if k == 0 else 22.0, 5)
                anillo_polvo(s, a, A[0], A[1] + 2, e, 12.0, 3 + k)
                if e < 2:
                    estrella(a, A[0] + DIRS[fila][0] * al * 0.6, A[1] + 4, (10, 6)[e], HUESO)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'pisoton', min(f, 7) if f < 8 else (f - 8) % 8, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- LA CORNADA DE CRISTAL (mutantes): corre su linea dejando un SURCO DE ESQUIRLAS cian y, al acabar, le ESTALLAN los
# colmillos: lluvia de cristal alrededor de la cabeza ---
def cornada_cristal(fila, var=COLMILLO, largo_mundo=50.0):
    dx, dy = DIRS[fila]
    L = largo_mundo / UNIDAD
    al = alcance(var, 'cornada', fila, dx, dy)
    A = (W * 0.5 - dx * (L + al) * 0.5, H * 0.55 - dy * (L + al) * 0.42)
    fx, fy = frente_de(var, 'cornada', fila, dx, dy)
    V = (A[0] + dx * (L + al + 6), A[1] + dy * (L + al + 6) + 6)
    rnd = random.Random(7 + fila)
    clavadas = [(rnd.uniform(0.0, 1.0), rnd.uniform(-7.0, 7.0), rnd.uniform(5.0, 9.0), rnd.uniform(-0.5, 0.5)) for _ in range(12)]
    lluvia = [(rnd.uniform(0, math.tau), rnd.uniform(8, 24), rnd.uniform(10, 22)) for _ in range(12)]
    m, t = [], []
    corre = 6
    for f in range(corre + 16):
        s, a = nuevo(), nuevo()
        u = min(1.0, (f + 1) / float(corre))
        x, y = A[0] + dx * L * u, A[1] + dy * L * u
        for uu, lado, alto, incl in clavadas:
            if uu > u:
                continue
            queda = seco(f - uu * corre, 8, 5)
            tmp = nuevo()
            n = math.hypot(incl, 1.0)
            px, py = A[0] + dx * (al * 0.4 + L * uu) - dy * lado, A[1] + dy * (al * 0.4 + L * uu) + dx * lado
            cristal(tmp, px, py - alto * 0.5, incl / n, -1.0 / n, alto, 1.7, CIAN)
            mas = (tmp[:, :, 3] > 0) & (TRAMA < queda)
            s[mas] = tmp[mas]
        e = f - corre
        if e >= 0:
            cx, cy = x + fx, y + fy - 2
            if e < 2:
                estrella(a, cx, cy, (16, 10)[e], CIAN)
            k = min(1.0, (e + 1) / 7.0)
            for ang, d, sube in lluvia:
                if e < 11:
                    px = cx + math.cos(ang) * d * k
                    py = cy + math.sin(ang) * d * 0.7 * k - sube * 4 * k * (1 - k) + k * 6
                    cristal(a, px, py, math.cos(ang + e), math.sin(ang + e), 5, 1.4, CIAN)
            if e < 6:
                enganche(a, V[0], V[1] - 11, dx, dy, 14.0, e, 6, CIAN, CIAN[0], 10.0)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'cornada', min(f, 7), fila), x, y, 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LAS ESPORAS (del musgo): polvo ocre-verdoso que se expande y se posa, con motitas claras flotando ---
def esporas(fila=1, var=ANCESTRAL):
    A = (W * 0.5, H * 0.54)
    al = alcance(var, 'idle', fila, *DIRS[fila])
    rnd = random.Random(21)
    puffs = [(rnd.uniform(0, math.tau), rnd.uniform(0.3, 1.0), rnd.uniform(7, 11), rnd.uniform(0, 0.3)) for _ in range(20)]
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(0.2, 1.1), rnd.random()) for _ in range(14)]
    R = al + 18
    m, t = [], []
    for f in range(20):
        s, a = nuevo(), nuevo()
        k = 1.0 - (1.0 - min(1.0, (f + 1) / 8.0)) ** 2
        fuerza = seco(f, 10, 9)
        for ang, uu, r, t0 in puffs:
            kk = max(0.0, min(1.0, (k - t0) / (1 - t0)))
            if kk > 0:
                vn.nube(a if math.sin(ang) > -0.2 else s, A[0] + math.cos(ang) * R * uu * kk, A[1] + math.sin(ang) * R * uu * kk * 0.8 - 6 + f * 0.4, r * (0.5 + 0.5 * kk), fuerza * 1.2, ESPORA)
        for ang, uu, fase in motas:
            if ((f / 7.0 + fase) % 1.0) < 0.7 and f > 2 and f < 19:
                punto(a, A[0] + math.cos(ang + f * 0.05) * R * uu * k, A[1] + math.sin(ang + f * 0.05) * R * uu * k * 0.8 - 10 - math.sin(f * 0.4 + fase * 6) * 3, ESPORA[3], 2)
        m.append(escena([s], [(marco(var, 'idle', f % 8, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


# --- LAS DRUSAS (el reflejo de magia): destello cian en el morro y una bola de luz cian que vuelve al lanzador ---
def drusas(fila=2, var=COLMILLO):
    dx, dy = DIRS[fila]
    al = alcance(var, 'idle', fila, dx, dy)
    fx, fy = frente_de(var, 'idle', fila, dx, dy)
    A = (W * 0.32, H * 0.55)
    morro = (A[0] + fx, A[1] + fy)
    V = (A[0] + dx * (al + 66), A[1] + dy * (al + 66) + 6)
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        if f < 3:
            estrella(a, morro[0], morro[1], (10, 18, 12)[f], CIAN)
        if 1 <= f < 9:
            u = (f - 0) / 8.0
            x, y = morro[0] + (V[0] - morro[0]) * u, morro[1] + (V[1] - 10 - morro[1]) * u
            ux, uy = V[0] - morro[0], V[1] - 10 - morro[1]
            n = math.hypot(ux, uy) or 1
            cometa_dir(a, x, y, ux / n, uy / n, 16, 2, CIAN)
            disco(a, x, y, 4.2, CIAN[0])
            disco(a, x, y, 3.2, CIAN[2])
            disco(a, x - 1, y - 1, 1.6, CIAN[3])
        if f >= 9:
            e = f - 9
            if e < 2:
                estrella(a, V[0], V[1] - 10, (14, 8)[e], CIAN)
            if e < 6:
                for q in range(6):
                    ang = q / 6 * math.tau
                    punto(a, V[0] + math.cos(ang) * (3 + e * 2.2), V[1] - 10 + math.sin(ang) * (2 + e * 1.5) + e, CIAN[2], 2)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'idle', f % 8, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- LA QUEMA de la chepa (ancestral): arde POCO A POCO: las llamas (siluetas por fotograma) le van prendiendo por el lomo
# de atras a delante, humo negro arriba y ceniza y brasas por los flancos ---
def quema(fila=1, var=ANCESTRAL):
    dx, dy = DIRS[fila]
    A = (W * 0.5, H * 0.58)
    spr = np.array(marco(var, 'quemandose', 0, fila))
    ys, xs = np.nonzero(spr[:, :, 3] > 0)
    h0, w0 = spr.shape[:2]
    # el lomo medido: la franja alta de su dibujo, de atras a delante
    arriba = ys.min() + (ys.max() - ys.min()) * 0.22
    izq, der = xs.min() + 8, xs.max() - 8
    orden = -1 if dx >= 0 else 1
    puntos = [izq + (der - izq) * (i / 6.0 if orden < 0 else 1 - i / 6.0) for i in range(7)]
    m, t = [], []
    for f in range(30):
        s, a = nuevo(), nuevo()
        prende = f / 3.0
        fuerza = 1.0 if f < 24 else max(0.0, 1.0 - (f - 24) / 6.0)
        for i, px in enumerate(puntos):
            e = prende - i
            if e < 0:
                continue
            alto = min(1.0, e / 2.0) * (11 + 4 * math.sin(f * 0.9 + i * 1.7))
            x = A[0] + px - w0 // 2
            y = A[1] + arriba - h0 // 2 + abs(i - 3) * 1.5 + 8
            fg.llama(a, x, y, alto, 3.6, f, fuerza, i * 1.3)
            if f % 7 == i % 7 and e > 1:
                vn.nube(a, x + 2, y - alto - 3, 4.0, 1.1 * fuerza, fg.CENIZA)
        for k in range(4):
            g = (f + k * 5) % 12
            if prende > 2:
                vn.nube(a, A[0] + (k - 1.5) * 12 + g * 0.4, A[1] + arriba - h0 // 2 - 12 - g * 2.2, 3.5 + g * 0.7, (1 - g / 12.0) * fuerza * 1.6, fg.CENIZA)
        if prende > 3:
            fg.chispas(a, A[0], A[1] - 6, 8, f, 9, 22.0, (der - izq) * 0.55)
        m.append(escena([s], [(marco(var, 'quemandose', f, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: basico(d) for d in (1, 2, 4)}
    co = {d: cornada(d) for d in (1, 2, 4)}
    em = {d: embestida(d) for d in range(5)}
    pi = pisoton()
    cc = {d: cornada_cristal(d) for d in (1, 2, 4)}
    ca = cornada_cristal(2, ANCESTRAL, 60.0)
    dr = drusas()
    es = esporas()
    qu = quema()
    z = 2
    filas = [
        *[('JABALI\nbasico (el colmillo)\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (2, 4, 5, 6, 7, 10))) for d in (1, 2, 4)],
        *[('JABALI\nCornada (lo levanta)\nhacia el ' + NOM_DIR[d], elegir(co[d][0], (3, 5, 7, 9, 11, 15))) for d in (1, 2, 4)],
        *[('JABALI\nEmbestida\nhacia el ' + NOM_DIR[d], elegir(em[d][0], (1, 3, 5, 7, 10, 16))) for d in range(5)],
        ('JABALI\nPisoton (dos)', elegir(pi[0], (3, 5, 8, 11, 13, 20))),
        *[('COLMILLO DE CRISTAL\nCornada de cristal\nhacia el ' + NOM_DIR[d], elegir(cc[d][0], (2, 5, 6, 8, 11, 16))) for d in (1, 2, 4)],
        ('ANCESTRAL\nCornada de cristal', elegir(ca[0], (2, 5, 6, 8, 11, 16))),
        ('COLMILLO Y ANCESTRAL\nlas Drusas (reflejo)', elegir(dr[0], (1, 3, 6, 9, 11, 14))),
        ('ANCESTRAL\nlas Esporas', elegir(es[0], (1, 4, 7, 10, 14, 18))),
        ('ANCESTRAL\nla chepa se quema\n(poco a poco)', elegir(qu[0], (1, 5, 10, 16, 22, 28))),
    ]
    lamina(filas, os.path.join(SALIDA, 'jabali.png'), z)
    todos, tiempos = [], []
    for marcos, ts in [ba[1], co[1], em[1], em[2], pi, cc[1], cc[2], dr, es, qu]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'jabali.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
