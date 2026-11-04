#!/usr/bin/env python3
# ============================================================
#  slime_profundo_efectos_pixel.py -- LOS EFECTOS DEL SLIME PROFUNDO (y sus mutantes, el de arrecife y el de escarcha)
#  EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art). Los mismos que hoy pinta ProfundoAire (MAREA, CHORRO, CORAL,
#  ESTALLIDO, ALIENTO, CARAMBANOS, ANEMONA, HELADA) y NeblinaFria: el AGUA del arrecife es agua de mar (azul verdoso con
#  espuma blanca) con sus CORALES; el FRIO de la escarcha es blanco azulado, con cristalitos y copos.
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/slime_profundo_efectos_pixel.py
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
                                 victima, gota, charco, seco, Gotas, marco, escena, sombra, lamina, elegir, cristal,
                                 DIRS, NOM_DIR)
from slime_fuego_efectos_pixel import alrededor, lengua

GRIS = [(30, 38, 48), (78, 96, 116), (146, 166, 186), (226, 236, 246)]
AGUA = [(14, 54, 76), (32, 114, 144), (92, 194, 214), (226, 252, 255)]
AGUA_BORDE = (6, 26, 40)
HIELO = [(64, 96, 140), (142, 182, 222), (212, 236, 255), (255, 255, 255)]
HIELO_BORDE = (30, 48, 80)
CORALES = [[(120, 30, 52), (222, 82, 112), (255, 152, 172), (255, 232, 236)],
           [(122, 52, 20), (232, 122, 50), (255, 190, 120), (255, 242, 212)],
           [(110, 90, 20), (226, 196, 60), (255, 236, 140), (255, 252, 226)]]
ANEMONA = [(26, 74, 40), (68, 156, 80), (150, 220, 140), (255, 140, 190)]

PROFUNDO, ARRECIFE, ESCARCHA = 's150', 'arr180', 'esc198'


def gel(pal, borde):
    sl.GEL, sl.GEL_BORDE = pal, borde
    vn.GEL = pal


# Un salto como el del Reventon (se hincha, salta, cae y se deshincha) con lo que pasa al caer en 'al_caer(s, a, B, e)'.
def salto(fila, var, al_caer, vict_r, n_caer=16):
    dx, dy = DIRS[fila]
    rango = 70.0 / UNIDAD
    A = (W * 0.5 - dx * rango * 0.5, H * 0.58 - dy * rango * 0.45)
    B = (A[0] + dx * rango, A[1] + dy * rango)
    sl.ORIGEN = B
    vict = [(B[0] + vict_r * 0.8, B[1] - vict_r * 0.3), (B[0] - vict_r * 0.75, B[1] + vict_r * 0.45)]
    m, t = [], []
    carga, vuelo = 6, 6
    for f in range(carga + vuelo + n_caer):
        s, a = nuevo(), nuevo()
        if f < carga:
            anim, fr, x, y, alto = ('inflar' if f < 4 else 'hinchado'), f * 2 % 8, A[0], A[1], 0
        elif f < carga + vuelo:
            u = (f - carga + 1) / float(vuelo)
            x, y = A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u
            alto = 34.0 * 4 * u * (1 - u)
            anim, fr = 'hinchado', f % 8
            sombra(s, x, y, 9.0 - alto * 0.08)
        else:
            e = f - carga - vuelo
            x, y, alto = B[0], B[1], 0
            anim, fr = ('aplaston', min(e, 7)) if e < 8 else ('deshincharse', min(e - 8, 7))
            al_caer(s, a, B, e)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, anim, fr, fila), x, y, alto)], [a]))
        t.append(1000 // 14)
    return m, t


# --- REVENTON DE MAREA: donde cae, una OLA en anillo que se abre (la cresta de espuma, el agua detras y el suelo mojado
# que brilla) y gotas que saltan de la cresta ---
def marea(fila=1):
    R = 40.0 / UNIDAD
    gotas = Gotas(16, 7, R * 0.5, R * 1.1, sube=(8.0, 16.0), tam=(1.2, 2.0), pal=AGUA, borde=AGUA_BORDE)

    def al_caer(s, a, B, e):
        k = 1.0 - (1.0 - min(1.0, (e + 1) / 6.0)) ** 2
        vivo = seco(e, 6, 7)
        d = np.hypot(XX - B[0], YY - B[1])
        poner(s, (d < R * k) & (TRAMA < 0.55 * vivo), AGUA[0])
        poner(s, (d < R * k * 0.8) & (TRAMA < 0.18 * vivo), AGUA[2])
        if e < 7:
            ep.banda(s, B[0], B[1], R * k, 6.0 * (1 - e / 9.0) + 2.0, AGUA, False, e)
        gotas.pintar(s, a, B[0], B[1], min(1.0, e / 6.0), R * 0.4, 1.0, 99)
        if e < 2:
            estrella(a, B[0], B[1] - 4, (12, 18)[e], AGUA)
    return salto(fila, ARRECIFE, al_caer, R)


# --- CHORRO A PRESION: un chorro de agua desde su frente a la altura de la boca que cruza la linea (nucleo claro, agua
# alrededor, el suelo mojado debajo); al llegar rompe en salpicaduras ---
def chorro(fila, var=ARRECIFE, escala=0.85):
    dx, dy = DIRS[fila]
    L = 110.0 / UNIDAD * escala
    A = (W * 0.5 - dx * L * 0.5, H * 0.58 - dy * L * 0.42)
    rad = marco(var, 'escupir', 0, fila).size[0] * 0.3
    bx, by = vn.boca(A, dx, dy, rad)
    sl.ORIGEN = (bx, by + vn.BOCA)   # donde empieza su huella, a ras de suelo
    V = (bx + dx * L * 0.75, by + dy * L * 0.75 + 9)
    fin = (bx + dx * L, by + dy * L)
    salpica = Gotas(10, 4 + fila, 4.0, 14.0, (math.atan2(dy, dx), 1.5), sube=(8.0, 16.0), tam=(1.2, 2.0), pal=AGUA, borde=AGUA_BORDE)
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        u = min(1.0, (f + 1) / 4.0)
        fuerza = 1.0 if f < 9 else max(0.0, 1.0 - (f - 9) / 4.0)
        s_ = (XX - bx) * dx + (YY - by - 7) * dy
        l_ = (XX - bx) * (-dy) + (YY - by - 7) * dx
        poner(s, (s_ > 0) & (s_ < L * u) & (np.abs(l_) < 4) & (TRAMA < 0.5 * seco(f, 9, 5)), AGUA[0])
        if fuerza > 0:
            capa = a if dy > -0.2 else s
            s2 = (XX - bx) * dx + (YY - by) * dy
            l2 = (XX - bx) * (-dy) + (YY - by) * dx
            g = 3.2 * fuerza * (1 + 0.15 * np.sin(s2 * 0.7 - f * 2))
            en = (s2 >= 0) & (s2 <= L * u) & (np.abs(l2) <= g)
            poner(capa, en, AGUA[1])
            poner(capa, en & (np.abs(l2) <= g * 0.6), AGUA[2])
            poner(capa, en & (np.abs(l2) <= g * 0.25), AGUA[3])
            poner(capa, en & (np.abs(l2) > g - 1.0) & (np.sin(s2 * 0.9 + f) > 0.6), AGUA[3])   # espuma en el borde
        if u >= 1.0:
            e = f - 3
            salpica.pintar(s, a, fin[0], fin[1] + 7, min(1.0, e / 5.0), 1.0, 1.0, e - 6)
            if e < 2:
                estrella(a, fin[0], fin[1], (10, 7)[e], AGUA)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- ESQUIRLAS DE CORAL: trozos de coral de colores que salen volando en abanico, girando, con su estela, y al caer se
# parten en motas ---
def trozo_coral(a, x, y, giro, pal, r=2.6):
    for k in range(3):
        ang = giro + k * 2.1
        px, py = x + math.cos(ang) * r * 0.6, y + math.sin(ang) * r * 0.6
        disco(a, px, py, r * 0.75 + 0.6, sl.GEL_BORDE if False else (40, 16, 20))
    for k in range(3):
        ang = giro + k * 2.1
        px, py = x + math.cos(ang) * r * 0.6, y + math.sin(ang) * r * 0.6
        disco(a, px, py, r * 0.75, pal[1])
        punto(a, px - 1, py - 1, pal[2])
    punto(a, x - 1, y - 1, pal[3])


def coral(fila, var=ARRECIFE, desde_borde=False):
    """desde_borde: el origen es ya el vertice de su huella (en el juego), no el centro de su cuerpo."""
    dx, dy = DIRS[fila]
    R = 60.0 / UNIDAD
    A = (W * 0.5 - dx * R * 0.4, H * 0.58 - dy * R * 0.35)
    sl.ORIGEN = A
    eje = math.atan2(dy, dx)
    rnd = random.Random(2 + fila)
    trozos = [(eje + rnd.uniform(-1, 1) * math.radians(80) * 0.45, rnd.uniform(0.45, 1.0), rnd.randrange(3), rnd.uniform(0, 6), rnd.uniform(8, 16)) for _ in range(10)]
    rad = marco(var, 'sacudir', 0, fila).size[0] * 0.3
    vict = [(A[0] + math.cos(eje + k) * max(R * 0.75, rad + 12), A[1] + math.sin(eje + k) * max(R * 0.75, rad + 12) + 3) for k in (-0.3, 0.3)]
    m, t = [], []
    for f in range(17):
        s, a = nuevo(), nuevo()
        e = f - 3
        if e >= 0:
            k = min(1.0, (e + 1) / 6.0)
            for ang, uu, c, gi, sube in trozos:
                r0 = 0.0 if desde_borde else rad * 0.6
                d = r0 + (R * uu - r0) * k
                x = A[0] + math.cos(ang) * d
                y = A[1] + math.sin(ang) * d - 6 - sube * 4 * k * (1 - k)
                if k < 1.0:
                    trozo_coral(a, x, y, gi + e * 1.3, CORALES[c])
                else:
                    g = e - 5
                    for q in range(3):
                        if g < 6:
                            ep.bolita(s, x + (q - 1) * (2 + g), y + 6 + g * 0.3, 1.6 - g * 0.2, CORALES[c])
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'sacudir', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LA ANEMONA (pasiva del arrecife): de su cuerpo salen tres tentaculos verdes con la punta rosa que se estiran
# ondulando hasta quien le ha pegado, PICAN (destello rosa) y se recogen; quedan motas urticantes ---
def pinchazo(a, V, f):
    """Donde pica, con f los marcos de la lamina (pica en el 5): el destello rosa y las motas urticantes."""
    if f in (5, 6):
        estrella(a, V[0], V[1] - 10, (10, 6)[f - 5], [(140, 40, 90), (230, 90, 160), (255, 160, 210), (255, 235, 245)])
    if f >= 6:
        e = f - 6
        rnd = random.Random(3)
        for _ in range(6):
            x, y = V[0] + rnd.uniform(-7, 7) + e * rnd.uniform(-0.5, 0.5), V[1] - 12 + rnd.uniform(-6, 6) - e * 0.6
            if e < 9:
                punto(a, x, y, ANEMONA[3] if e < 5 else (200, 100, 150), 2)


def anemona(var=ARRECIFE):
    A = (W * 0.42, H * 0.56)
    rad = marco(var, 'idle', 0, 1).size[0] * 0.3
    V = (A[0] + rad + 26, A[1] + 8)
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        sale = min(1.0, (f + 1) / 5.0) if f < 9 else max(0.0, 1.0 - (f - 9) / 5.0)
        for k in range(3):
            base = (A[0] + rad * 0.6, A[1] - 8 - (k - 1) * 5)
            fin = (V[0] - 2, V[1] - 10 - (k - 1) * 3)
            n = 34
            for i in range(int(n * sale) + 1):
                u = i / n
                # una onda que viaja por el tentaculo, mas suelta hacia la punta (no un palo recto)
                onda = math.sin(u * 9 - f * 1.6 + k * 2) * 4.0 * math.sin(u * math.pi)
                x = base[0] + (fin[0] - base[0]) * u
                y = base[1] + (fin[1] - base[1]) * u + onda
                g = 2.0 * (1 - u * 0.55)
                disco(a, x, y, g + 0.7, (16, 44, 24))
                disco(a, x, y, g, ANEMONA[1])
                punto(a, x - 0.5, y - 0.8, ANEMONA[2])
                if i == int(n * sale):
                    disco(a, x, y, 1.6, ANEMONA[3])
        pinchazo(a, V, f)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'idle', f % 8, 2), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- EL FRIO ---
def copos(a, x, y, n, f, sem, alto=14.0, radio=10.0, sube=True):
    rnd = random.Random(sem)
    for _ in range(n):
        fase = rnd.random()
        k = (f / 12.0 + fase) % 1.0
        px = x + rnd.uniform(-radio, radio) + math.sin(k * 6 + fase * 9) * 1.5
        py = y - k * alto if sube else y + k * alto * 0.5
        punto(a, px, py, HIELO[3] if (int(f + fase * 5) % 3) else HIELO[2], 2 if k < 0.6 else 1)


def escarcha_suelo(s, x, y, r, vivo, sem):
    charco(s, x, y, r, sem, vivo, HIELO, HIELO_BORDE)


def estallido(fila=1):
    R = 45.0 / UNIDAD
    rnd = random.Random(5)
    picos = [(rnd.uniform(0, math.tau), rnd.uniform(0.3, 0.9), rnd.uniform(6, 10)) for _ in range(9)]

    def al_caer(s, a, B, e):
        k = 1.0 - (1.0 - min(1.0, (e + 1) / 5.0)) ** 2
        vivo = seco(e, 8, 7)
        escarcha_suelo(s, B[0], B[1], R * 0.85 * k, vivo, 2.0)
        for ang, uu, largo in picos:
            x, y = B[0] + math.cos(ang) * R * uu * k, B[1] + math.sin(ang) * R * uu * k
            tmp = nuevo()
            cristal(tmp, x, y - largo * 0.5 * k, 0.15 * math.cos(ang), -1.0, largo * k, 1.8, HIELO)
            mascara = (tmp[:, :, 3] > 0) & (TRAMA < vivo)
            (a if math.sin(ang) > -0.2 else s)[mascara] = tmp[mascara]
        copos(a, B[0], B[1] - 4, 8, e, 3, 22.0, R * 0.7)
        if e < 2:
            estrella(a, B[0], B[1] - 6, (14, 20)[e], HIELO)
    return salto(fila, ESCARCHA, al_caer, R)


def aliento(fila, var=ESCARCHA, escala=0.85):
    dx, dy = DIRS[fila]
    R = 70.0 / UNIDAD * escala
    A = (W * 0.5 - dx * R * 0.42, H * 0.56 - dy * R * 0.38)
    rad = marco(var, 'soplar', 0, fila).size[0] * 0.3
    bx, by = vn.boca(A, dx, dy, rad)
    sl.ORIGEN = (bx, by + vn.BOCA)   # el vertice de su huella, a ras de suelo
    eje = math.atan2(dy, dx)
    rnd = random.Random(7 + fila)
    bocanadas = [(eje + rnd.uniform(-1, 1) * math.radians(70) * 0.42, rnd.uniform(0.25, 1.0), rnd.uniform(6, 10), rnd.uniform(0, 0.35)) for _ in range(14)]
    vict = [(A[0] + math.cos(eje + k) * max(R * 0.75, rad + 12), A[1] + math.sin(eje + k) * max(R * 0.75, rad + 12) + 3) for k in (-0.3, 0.3)]
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        e = f - 2
        if e >= 0:
            k = min(1.0, (e + 1) / 7.0)
            fuerza = seco(e, 8, 6)
            d = np.hypot(XX - bx, YY - by - 7)
            ang = np.arctan2(YY - by - 7, XX - bx)
            rel = np.abs((ang - eje + np.pi) % (2 * np.pi) - np.pi)
            poner(s, (rel < math.radians(35)) & (d < R * k) & (d > rad * 0.5) & (TRAMA < 0.32 * fuerza), HIELO[1])
            for a0, uu, r, t0 in bocanadas:
                kk = max(0.0, min(1.0, (k - t0) / (1 - t0)))
                if kk <= 0:
                    continue
                dd = rad * 0.4 + (R * uu - rad * 0.4) * kk
                x, y = bx + math.cos(a0) * dd, by + math.sin(a0) * dd - e * 0.3
                vn.nube(a if dy > -0.2 else s, x, y, r * (0.5 + 0.6 * kk), fuerza * 1.2, HIELO)
            copos(a, bx + dx * R * 0.5, by + dy * R * 0.5, 7, e, 5, 10.0, R * 0.4)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'soplar', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# Carambanos: en cada circulo de la fila, uno tras otro: su sombra crece en el suelo, el carambano cae del aire y se rompe
# en esquirlas con un destello y una mancha de escarcha.
def carambano(s, a, px, py, e, i=0, r_escarcha=6.0):
    """Un carambano que cae en (px, py); e = marcos desde que crece su sombra (a los 5 rompe)."""
    if e < 5:
        u = (e + 1) / 5.0
        poner(s, ((((XX - px) / (2 + 5 * u)) ** 2 + ((YY - py) / (1 + 2.5 * u)) ** 2) <= 1) & (TRAMA < 0.7), ep.SOMBRA)
        cristal(a, px, py - 50 * (1 - u) - 8, 0.0, 1.0, 14, 2.4, HIELO)
    else:
        g = e - 5
        vivo = seco(g, 5, 6)
        escarcha_suelo(s, px, py, r_escarcha * min(1.0, (g + 1) / 2.0), vivo, i)
        if g < 2:
            estrella(a, px, py - 5, (12, 8)[g], HIELO)
        if g < 6:
            for q in range(5):
                ang = q / 5 * math.tau + i
                cristal(a, px + math.cos(ang) * (3 + g * 2.2), py - 4 + math.sin(ang) * (2 + g) - g * (3 - g * 0.6), math.cos(ang), math.sin(ang), 4, 1.2, HIELO)


def carambanos(fila, var=ESCARCHA):
    dx, dy = DIRS[fila]
    L = 140.0 / UNIDAD * 0.8
    A = (W * 0.5 - dx * L * 0.5, H * 0.56 - dy * L * 0.45)
    rad = marco(var, 'carambanos', 0, fila).size[0] * 0.3
    puntos = [(A[0] + dx * (rad + 6 + (L - rad) * i / 4.0), A[1] + dy * (rad + 6 + (L - rad) * i / 4.0)) for i in range(5)]
    vict = [puntos[1], puntos[3]]
    vict = [(x - dy * 6, y + dx * 6 + 3) for x, y in vict]
    m, t = [], []
    for f in range(26):
        s, a = nuevo(), nuevo()
        for i, (px, py) in enumerate(puntos):
            e = f - 2 - i * 3
            if e >= 0:
                carambano(s, a, px, py, e, i)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'carambanos', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# La NEBLINA del aura fria (siempre puesta): vaho pegado al suelo que gira despacio alrededor, con chispitas que titilan.
def neblina(var=ESCARCHA):
    A = (W * 0.5, H * 0.56)
    rad = marco(var, 'idle', 0, 1).size[0] * 0.3
    R = rad + 30.0 / UNIDAD
    rnd = random.Random(11)
    vahos = [(rnd.uniform(0, math.tau), rnd.uniform(0.7, 1.0), rnd.uniform(5, 8)) for _ in range(14)]
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        for ang, uu, r in vahos:
            aa = ang + f * 0.06
            vn.nube(s, A[0] + math.cos(aa) * R * uu, A[1] + math.sin(aa) * R * uu * 0.85, r, 0.9, HIELO)
        rnd = random.Random(4)
        for _ in range(9):
            ang, uu, fase = rnd.uniform(0, math.tau), rnd.uniform(0.3, 1.0), rnd.random()
            if ((f / 6.0 + fase) % 1.0) < 0.5:   # titilan
                punto(s, A[0] + math.cos(ang) * R * uu, A[1] + math.sin(ang) * R * uu * 0.85, HIELO[3], 2)
        m.append(escena([s], [(marco(var, 'idle', f % 8, 1), A[0], A[1], 0)], [a]))
        t.append(1000 // 8)
    return m, t


# El destello helado (al que se queda congelado): la escarcha se abre a sus pies, le crecen cristales alrededor de las
# piernas, un destello blanco le cruza el cuerpo y suben copos; luego se funde.
def helada():
    V = (W * 0.5, H * 0.62)
    sl.ORIGEN = V
    rnd = random.Random(8)
    picos = [(rnd.uniform(0, math.tau), rnd.uniform(5, 8)) for _ in range(7)]
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        k = min(1.0, (f + 1) / 4.0)
        vivo = seco(f, 9, 6)
        escarcha_suelo(s, V[0], V[1], 9 * k, vivo, 1.0)
        for ang, largo in picos:
            x, y = V[0] + math.cos(ang) * 6, V[1] + math.sin(ang) * 3
            tmp = nuevo()
            cristal(tmp, x, y - largo * 0.5 * k, 0.2 * math.cos(ang), -1.0, largo * k, 1.6, HIELO)
            mascara = (tmp[:, :, 3] > 0) & (TRAMA < vivo)
            (a if math.sin(ang) > 0 else s)[mascara] = tmp[mascara]
        if 3 <= f <= 5:
            y = V[1] - (f - 3) * 7
            poner(a, (np.abs(YY - y) <= 1) & (np.abs(XX - V[0]) <= 6), HIELO[3])
            estrella(a, V[0], V[1] - 10, 9, HIELO)
        copos(a, V[0], V[1] - 6, 6, f, 2, 20.0, 8.0)
        victima(s, *V)
        m.append(escena([s], [], [a]))
        t.append(1000 // 12)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    gel(GRIS, (14, 18, 26))
    ba = {d: sl.basico(d, PROFUNDO) for d in (1, 4)}
    rv = sl.reventon(1, 35.0, PROFUNDO)
    de = sl.embate(1, 2, 100.0, PROFUNDO)
    ma = marea()
    ch = {d: chorro(d) for d in range(5)}
    co = {d: coral(d) for d in (1, 2, 4)}
    an = anemona()
    es = estallido()
    al = {d: aliento(d) for d in (1, 2, 4)}
    ca = {d: carambanos(d) for d in (1, 2)}
    ne = neblina()
    he = helada()
    filas = [
        *[('PROFUNDO\nbasico\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        ('PROFUNDO\nReventon', elegir(rv[0], (3, 8, 12, 14, 17, 25))),
        ('PROFUNDO\nDoble embate', elegir(de[0], (1, 3, 4, 7, 9, 12))),
        ('ARRECIFE\nReventon de marea', elegir(ma[0], (3, 8, 12, 14, 17, 24))),
        *[('ARRECIFE\nChorro a presion\nhacia el ' + NOM_DIR[d], elegir(ch[d][0], (1, 3, 5, 8, 10, 14))) for d in range(5)],
        *[('ARRECIFE\nEsquirlas de coral\nhacia el ' + NOM_DIR[d], elegir(co[d][0], (3, 5, 7, 9, 11, 15))) for d in (1, 2, 4)],
        ('ARRECIFE\nla anemona\n(al que le pega)', elegir(an[0], (1, 3, 5, 6, 9, 13))),
        ('ESCARCHA\nEstallido helado', elegir(es[0], (3, 8, 12, 14, 18, 25))),
        *[('ESCARCHA\nAliento gelido\nhacia el ' + NOM_DIR[d], elegir(al[d][0], (2, 4, 6, 9, 12, 16))) for d in (1, 2, 4)],
        *[('ESCARCHA\nCarambanos\nhacia el ' + NOM_DIR[d], elegir(ca[d][0], (4, 7, 9, 13, 17, 23))) for d in (1, 2)],
        ('ESCARCHA\nla neblina del aura', elegir(ne[0], (0, 3, 6, 9, 12, 15))),
        ('ESCARCHA\nel destello helado\n(al que se congela)', elegir(he[0], (1, 3, 4, 6, 9, 13))),
    ]
    lamina(filas, os.path.join(SALIDA, 'slime_profundo.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], rv, de, ma, ch[1], ch[2], co[2], an, es, al[2], ca[2], ne, he]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'slime_profundo.gif'), 3)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
