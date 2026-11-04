#!/usr/bin/env python3
# ============================================================
#  slime_fuego_efectos_pixel.py -- LOS EFECTOS DEL SLIME DE FUEGO (y sus mutantes, Ceniza y brasa y Obsidiana) EN
#  PIXEL ART (04/11/2026, memoria efectos-a-pixel-art). Los mismos que hoy pinta SlimeAire (LLAMARADA, SALPICA,
#  COMBUSTION, IGNICION, ESCUPE...), con las piezas del slime y del venenoso.
#  EL FUEGO, como la llama del altar (memoria fuego-fotogramas-no-particulas): SILUETAS de llama que cambian un poco en cada
#  fotograma (borde irregular, punta que se mece, corazon claro), nunca bolitas sueltas; las particulas solo para chispas y
#  humo. Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/slime_fuego_efectos_pixel.py
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

FUEGO = [(120, 22, 8), (222, 70, 16), (255, 150, 36), (255, 222, 96), (255, 248, 214)]
FUEGO_BORDE = (60, 10, 4)
LAVA = [(110, 22, 8), (220, 76, 18), (255, 160, 44), (255, 236, 160)]
LAVA_BORDE = (44, 8, 4)
HUMO = [(30, 26, 26), (58, 52, 52), (96, 90, 88), (140, 134, 130)]
CENIZA = [(52, 48, 48), (98, 92, 90), (154, 148, 142), (212, 206, 198)]
CHAMUSCADO = [(14, 10, 10), (30, 22, 20), (52, 40, 34), (80, 60, 46)]
# (mas clara que su cuerpo: con sus tonos de verdad las esquirlas eran del color del suelo y no se veian)
OBSIDIANA = [(30, 24, 44), (66, 56, 92), (134, 122, 176), (232, 226, 255)]
OBS_BORDE = (10, 6, 18)

LAVA_SPR, CENIZA_SPR, OBS_SPR = 'lava160', 'cen192', 'obs211'


def gel(pal, borde):
    sl.GEL, sl.GEL_BORDE = pal, borde
    vn.GEL = pal


# --- LA LLAMA: una silueta de gota con la punta que se mece y el borde irregular en cada fotograma ---
def llama(a, x, y, alto, ancho, f, fuerza=1.0, sem=0.0):
    """(x, y) = la base. alto/ancho en celdas. 'fuerza' < 1 la apaga desde fuera (se queda el corazon y luego nada)."""
    if alto < 2 or fuerza <= 0.0:
        return
    j = (y - YY).astype(float)                  # celdas por encima de la base
    u = j / alto
    en = (u >= -0.08) & (u <= 1.0)
    sway = np.sin(u * 2.6 + f * 1.3 + sem) * alto * 0.13 * u
    w = ancho * np.where(u < 0.25, 0.75 + u, np.clip(1.0 - (u - 0.25) / 0.75, 0, 1) ** 0.85)
    w = w * (1.0 + 0.16 * np.sin(j * 0.9 + f * 1.9 + sem * 3) + 0.08 * np.sin(j * 2.1 - f * 2.7))
    w = w * fuerza
    dx = np.abs(XX - x - sway)
    dentro = en & (dx <= w)
    rel = dx / np.maximum(w, 0.01)
    poner(a, dentro, FUEGO[0])
    poner(a, dentro & (rel < 0.82), FUEGO[1])
    poner(a, dentro & (rel < 0.6) & (u < 0.8), FUEGO[2])
    poner(a, dentro & (rel < 0.38) & (u < 0.55), FUEGO[3])
    poner(a, dentro & (rel < 0.2) & (u < 0.3) & (fuerza > 0.5), FUEGO[4])


def chispas(a, x, y, n, f, sem, alto=16.0, radio=8.0):
    rnd = random.Random(sem)
    for _ in range(n):
        fase = rnd.random()
        k = (f / 10.0 + fase) % 1.0
        px = x + rnd.uniform(-radio, radio) + math.sin(k * 6 + fase * 9) * 2
        py = y - k * alto
        punto(a, px, py, FUEGO[3] if k < 0.5 else FUEGO[1], 2 if k < 0.3 else 1)


def humo(a, x, y, r, fuerza):
    vn.nube(a, x, y, r, fuerza, HUMO)


# --- LLAMARADA: el aliento de fuego por su linea: una lengua de fuego que sale de la boca, con llamas que le suben
# encima, y que al apagarse deja humo ---
def lengua(a, x0, y0, dx, dy, largo, ancho, f, fuerza):
    s_ = (XX - x0) * dx + (YY - y0) * dy
    l_ = (XX - x0) * (-dy) + (YY - y0) * dx
    u = s_ / max(largo, 1.0)
    w = ancho * (0.35 + 0.65 * np.sin(np.pi * np.clip(u * 0.85 + 0.1, 0, 1)) ** 0.7)
    w = w * (1.0 + 0.2 * np.sin(s_ * 0.6 - f * 2.3) + 0.1 * np.sin(s_ * 1.4 + f * 1.1)) * fuerza
    dentro = (s_ >= 0) & (s_ <= largo) & (np.abs(l_) <= w)
    rel = np.abs(l_) / np.maximum(w, 0.01)
    poner(a, dentro, FUEGO[0])
    poner(a, dentro & (rel < 0.8), FUEGO[1])
    poner(a, dentro & (rel < 0.55) & (u < 0.85), FUEGO[2])
    poner(a, dentro & (rel < 0.32) & (u < 0.6), FUEGO[3])
    poner(a, dentro & (rel < 0.18) & (u < 0.25) & (fuerza > 0.6), FUEGO[4])


def llamarada(fila, var=LAVA_SPR):
    dx, dy = DIRS[fila]
    L = 70.0 / UNIDAD
    A = (W * 0.5 - dx * L * 0.45, H * 0.58 - dy * L * 0.4)
    rad = marco(var, 'escupir', 0, fila).size[0] * 0.3
    bx, by = vn.boca(A, dx, dy, rad)
    V = (A[0] + dx * L * 0.7, A[1] + dy * L * 0.7 + 3)
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        crece = min(1.0, (f + 1) / 5.0)
        fuerza = 1.0 if f < 9 else max(0.0, 1.0 - (f - 9) / 4.0)
        capa = a if dy > -0.2 else s
        if fuerza > 0:
            lengua(capa, bx, by, dx, dy, L * crece, 8.0, f, fuerza)
            for k in range(1, 5):
                uk = k / 5.0
                if uk < crece:
                    llama(a, bx + dx * L * uk, by + dy * L * uk + 2, 12 + 4 * math.sin(k + f), 4.2, f, fuerza, k)
        if f >= 7:
            for k in range(4):
                uk = 0.45 + k * 0.17
                e = f - 7
                humo(a, bx + dx * L * uk + e * 0.5, by + dy * L * uk - 6 - e * 2.2, 4 + e * 0.9, max(0.0, 1.0 - e / 9.0))
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- SALPICADURA ARDIENTE: se sacude y le saltan gotas de lava en anillo; donde caen chisporrotean un momento ---
def alrededor(A, var, R, n=2, giro=0.4):
    rad = marco(var, 'idle', 0, 0).size[0] * 0.3
    d = max(R * 0.8, rad + 12.0)
    return [(A[0] + math.cos(giro + k * math.tau / n + 0.3) * d, A[1] + math.sin(giro + k * math.tau / n + 0.3) * d * 0.8 + 4) for k in range(n)]


def salpicadura(var=LAVA_SPR, radio_mundo=35.0, pal=LAVA, borde=LAVA_BORDE, chisporrotea=True, ascuas=False):
    A = (W * 0.5, H * 0.56)
    R = radio_mundo / UNIDAD
    gotas = Gotas(16, 31, R * 0.45, R, sube=(12.0, 22.0), tam=(1.5, 2.4), pal=pal, borde=borde)
    vict = alrededor(A, var, R)
    m, t = [], []
    for f in range(20):
        s, a = nuevo(), nuevo()
        e = f - 2
        if e >= 0:
            gotas.pintar(s, a, A[0], A[1] - 4, min(1.0, e / 7.0), 8.0, 1.0, 99)
            if e >= 7:
                g = e - 7
                for ang, d, sube, tam, t0 in gotas.g:
                    x, y = A[0] + math.cos(ang) * d, A[1] - 4 + math.sin(ang) * d
                    queda = seco(g, 4, 6)
                    if queda <= 0:
                        continue
                    charco(s, x, y, 2.4, ang, queda, CHAMUSCADO if g > 4 else pal, borde)
                    if chisporrotea and g < 8:
                        llama(a, x, y + 1, 5 + 2 * math.sin(g + ang * 5), 1.6, f, queda, ang)
                    if ascuas and g < 9:
                        chispas(a, x, y, 2, f, int(ang * 100), 10.0, 2.0)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'aplaston' if var != CENIZA_SPR else 'idle', min(f, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- COMBUSTION: se prende (carga), revienta en una bola de fuego encima y un ANILLO DE LLAMAS corre hasta el borde,
# dejando el suelo chamuscado y humo ---
def combustion(var=LAVA_SPR, radio_mundo=45.0):
    A = (W * 0.5, H * 0.56)
    R = radio_mundo / UNIDAD
    rnd = random.Random(2)
    anillo = [(i / 18.0 * math.tau + rnd.uniform(-0.1, 0.1), rnd.uniform(0.85, 1.0), rnd.uniform(0, 6)) for i in range(18)]
    vict = alrededor(A, var, R, 3)
    m, t = [], []
    carga = 6
    for f in range(carga + 18):
        s, a = nuevo(), nuevo()
        if f < carga:
            anim, fr = 'ignicion', f + 1
            for k in range(3):
                llama(a, A[0] - 8 + k * 8, A[1] - 6, 6 + f * 1.6, 3.0, f, 1.0, k * 2)
        else:
            e = f - carga
            anim, fr = 'aplaston', min(e, 7)
            if e < 3:
                estrella(a, A[0], A[1] - 12, (16, 26, 14)[e], FUEGO)
                disco(a, A[0], A[1] - 10, (8, 12, 8)[e], FUEGO[3], 0.9)
            k = 1.0 - (1.0 - min(1.0, (e + 1) / 6.0)) ** 2
            charco(s, A[0], A[1], R * k * 0.95, 4.0, seco(e, 10, 8) * 0.8, CHAMUSCADO, CHAMUSCADO[0])
            fuerza = seco(e, 7, 6)
            for ang, uu, sem in anillo:
                d = R * uu * k
                x, y = A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d
                llama(a if math.sin(ang) > -0.3 else s, x, y, (9 + 3 * math.sin(e + sem)) * (0.6 + 0.4 * k), 3.0, f, fuerza, sem)
            if e >= 5:
                g = e - 5
                for ang, uu, sem in anillo[::3]:
                    d = R * uu * 0.8
                    humo(a, A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d - 8 - g * 1.8, 4 + g * 0.7, max(0.0, 1.0 - g / 12.0))
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, anim, fr, 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- IGNICION (y Avivar brasas de la Ceniza): se PRENDE: llamas que le suben del cuerpo, el suelo calentado debajo y
# ascuas que suben ---
def ignicion(var=LAVA_SPR, brasas=False):
    A = (W * 0.5, H * 0.58)
    rad = marco(var, 'ignicion', 0, 0).size[0] * 0.26
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        e = f
        if e < 2:
            estrella(a, A[0], A[1] - rad * 0.9, (12, 18)[e], FUEGO)
        sube = min(1.0, (e + 1) / 4.0)
        fuerza = 1.0 if e < 11 else max(0.0, 1.0 - (e - 11) / 4.0)
        # el suelo calentado: un charco de brillo a trama, no un aro
        d = np.hypot(XX - A[0], YY - A[1])
        poner(s, (d < rad * 1.6) & (d > rad * 0.9) & (TRAMA < 0.18 * fuerza), FUEGO[1] if not brasas else LAVA[0])
        poner(s, (d < rad * 1.25) & (d > rad * 0.9) & (TRAMA < 0.12 * fuerza), FUEGO[2])
        n = 3 if brasas else 5
        for k in range(n):
            ox = (k - (n - 1) / 2.0) * rad * (0.5 if not brasas else 0.7)
            alto = (rad * (1.1 if not brasas else 0.7) + 4 * math.sin(e * 0.9 + k * 1.7)) * sube
            llama(a, A[0] + ox, A[1] - rad * 0.5 - abs(ox) * 0.3, alto, 3.4 if not brasas else 2.4, e, fuerza, k * 1.3)
        chispas(a, A[0], A[1] - rad, 6 if brasas else 4, e, 9, 26.0, rad)
        m.append(escena([s], [(marco(var, 'ignicion', min(e, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# La ceniza es polvo espeso, no gas: bulto MACIZO de tres tonos (luz arriba) y solo el borde se deshace a trama.
def bocanada_ceniza(a, x, y, r, fuerza):
    if r < 1.0 or fuerza <= 0.0:
        return
    d = np.hypot(XX - x, YY - y)
    rr = r * (0.6 + 0.4 * fuerza)
    poner(a, (d < rr) & (d >= rr * 0.75) & (TRAMA < 0.5 * fuerza), CENIZA[0])
    poner(a, (d < rr * 0.75) & (TRAMA < fuerza * 1.2), CENIZA[1])
    d2 = np.hypot(XX - (x - rr * 0.2), YY - (y - rr * 0.3))
    poner(a, (d2 < rr * 0.42) & (TRAMA < fuerza * 1.2), CENIZA[2])
    poner(a, (d2 < rr * 0.18) & (fuerza > 0.6), CENIZA[3])


# --- NUBE DE CENIZA: revienta en una nube de ceniza gris con ascuas que se abre hasta el borde y se va posando ---
def nube_ceniza(var=CENIZA_SPR, radio_mundo=50.0):
    A = (W * 0.5, H * 0.56)
    R = radio_mundo / UNIDAD
    rnd = random.Random(12)
    puffs = [(rnd.uniform(0, math.tau), rnd.uniform(0.15, 1.0), rnd.uniform(9.0, 13.0), rnd.uniform(0.0, 0.25)) for _ in range(28)]
    vict = alrededor(A, var, R, 3)
    m, t = [], []
    carga = 5
    for f in range(carga + 18):
        s, a = nuevo(), nuevo()
        if f < carga:
            anim, fr = 'ignicion', f + 2
            chispas(a, A[0], A[1] - 14, 4, f, 3, 16.0, 10.0)
        else:
            e = f - carga
            anim, fr = 'aplaston', min(e, 7)
            if e < 2:
                estrella(a, A[0], A[1] - 12, (12, 8)[e], CENIZA)
            k = 1.0 - (1.0 - min(1.0, (e + 1) / 6.0)) ** 2
            fuerza = seco(e, 9, 8)
            for ang, uu, r, t0 in puffs:
                kk = max(0.0, min(1.0, (k - t0) / (1 - t0)))
                if kk <= 0:
                    continue
                d = R * uu * kk
                bocanada_ceniza(a if math.sin(ang) > -0.2 else s, A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d * 0.85 - 4 + e * 0.2,
                                r * (0.5 + 0.5 * kk), fuerza)
            chispas(a, A[0], A[1], 10, e, 17, 20.0, R * 0.8)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, anim, fr, 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- OBSIDIANA ---
# Embestida cortante: arremete por su linea dejando esquirlas negras clavadas, y al que pasa le deja un tajo de obsidiana.
def embestida_cortante(fila, var=OBS_SPR):
    dx, dy = DIRS[fila]
    largo = 70.0 / UNIDAD
    A = (W * 0.5 - dx * largo * 0.5, H * 0.56 - dy * largo * 0.5)
    V = (A[0] + dx * largo * 0.38, A[1] + dy * largo * 0.38 + 4)
    rnd = random.Random(7 + fila)
    clavadas = [(rnd.uniform(0.05, 0.9), rnd.uniform(-10.0, 10.0), rnd.uniform(5.0, 8.0), rnd.uniform(-0.5, 0.5)) for _ in range(12)]
    m, t = [], []
    corre = 6
    for f in range(corre + 12):
        s, a = nuevo(), nuevo()
        u = min(1.0, f / float(corre))
        x, y = A[0] + dx * largo * u, A[1] + dy * largo * u
        for uu, lado, alto, incl in clavadas:
            if uu > u:
                continue
            queda = seco(f - uu * corre, 7, 5)
            tmp = nuevo()
            n = math.hypot(incl, 1.0)
            px, py = A[0] + dx * largo * uu - dy * lado, A[1] + dy * largo * uu + dx * lado
            cristal(tmp, px, py - alto * 0.5, incl / n, -1.0 / n, alto, 1.8, OBSIDIANA)
            mascara = (tmp[:, :, 3] > 0) & (TRAMA < queda)
            s[mascara] = tmp[mascara]
        e = f - int(corre * 0.4)
        if 0 <= e < 6:
            sl.coletazo(a, V[0] - dy * 4, V[1] - 9 + dx * 4, math.atan2(dy, dx) + math.pi / 2, 9.0, 0.6, 2.2 * (1 - e / 6.0),
                        -1.0, 5.0 * (1 - e / 7.0) + 1.0, OBSIDIANA, OBS_BORDE)
            if e < 2:
                estrella(a, V[0], V[1] - 9, (9, 6)[e], OBSIDIANA)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'embestida', min(f, 7), fila), x, y, 0)], [a]))
        t.append(1000 // 16)
    return m, t


# Esquirlas: se sacude y le salen esquirlas de obsidiana en abanico, que se clavan en el suelo y se deshacen.
def esquirlas_obs(fila, var=OBS_SPR, radio_mundo=60.0, apertura=70.0):
    dx, dy = DIRS[fila]
    R = radio_mundo / UNIDAD
    A = (W * 0.5 - dx * R * 0.4, H * 0.58 - dy * R * 0.35)
    eje = math.atan2(dy, dx)
    rnd = random.Random(5 + fila)
    lista = [(eje + rnd.uniform(-1, 1) * math.radians(apertura) * 0.45, rnd.uniform(0.4, 1.0), rnd.uniform(6.0, 8.0)) for _ in range(12)]
    rad = marco(var, 'idle', 0, 0).size[0] * 0.3
    dv = max(R * 0.75, rad + 12.0)
    vict = [(A[0] + math.cos(eje + k) * dv, A[1] + math.sin(eje + k) * dv + 3) for k in (-0.3, 0.25)]
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        e = f - 3
        if e >= 0:
            k = min(1.0, (e + 1) / 5.0)
            queda = seco(e, 8, 5)
            for ang, uu, largo in lista:
                d = 10 + (R * uu - 10) * k
                x, y = A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d - 8 * (1 - k) - 6 * 4 * k * (1 - k)
                tmp = nuevo()
                cristal(tmp, x, y, math.cos(ang), math.sin(ang), largo, 1.8, OBSIDIANA)
                mascara = (tmp[:, :, 3] > 0) & (TRAMA < queda)
                (a if math.sin(ang) > -0.3 else s)[mascara] = tmp[mascara]
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# Afilarse: un brillo que le recorre las aristas de arriba abajo y unas chispas de filo.
def afilarse(var=OBS_SPR):
    A = (W * 0.5, H * 0.58)
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        spr = marco(var, 'afilar', min(f, 7), 0)
        img = escena([s], [(spr, A[0], A[1], 0)], [])
        arr = np.array(img)
        w, h = spr.size
        ox, oy = sl.pies(spr)
        x0, y0 = int(A[0]) - ox, int(A[1]) - oy
        banda_y = y0 + int((f / 10.0) * h)
        sp = np.array(spr)
        borde = (sp[:, :, 3] > 0)
        lum = sp[:, :, :3].sum(axis=2) > 150   # sus aristas claras
        for yy in range(max(0, banda_y - 4), min(h + y0, banda_y + 4)):
            for xx in range(w):
                yl = yy - y0
                if 0 <= yl < h and borde[yl, xx] and lum[yl, xx]:
                    arr[yy, x0 + xx, :3] = OBSIDIANA[3]
        img = Image.fromarray(arr, 'RGBA')
        if f in (3, 4, 8, 9):
            ar = nuevo()
            estrella(ar, A[0] + (8 if f == 4 else -10), A[1] - 26 + f, 11, OBSIDIANA)
            img.alpha_composite(Image.fromarray(ar, 'RGBA'))
        m.append(img)
        t.append(1000 // 12)
    return m, t


def puas_obs(var=OBS_SPR, radio_mundo=60.0):
    viejo = sl.CRISTAL
    sl.CRISTAL = OBSIDIANA
    try:
        return sl.puas(var, radio_mundo)
    finally:
        sl.CRISTAL = viejo


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    gel(LAVA, LAVA_BORDE)
    ba = {d: sl.basico(d, LAVA_SPR) for d in (1, 4)}
    ll = {d: llamarada(d) for d in range(5)}
    sa = salpicadura()
    co = combustion()
    ig = ignicion()
    eb = {d: vn.escupitajo(d, CENIZA_SPR) for d in (1, 4)}
    sc = salpicadura(CENIZA_SPR, 40.0, CENIZA, CENIZA[0], False, True)
    nc = nube_ceniza()
    av = ignicion(CENIZA_SPR, True)
    gel(OBSIDIANA, OBS_BORDE)
    ec = {d: embestida_cortante(d) for d in range(5)}
    eo = {d: esquirlas_obs(d) for d in (1, 2, 4)}
    pu = puas_obs()
    af = afilarse()
    filas = [
        *[('FUEGO\nbasico (lava)\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        *[('FUEGO\nLlamarada\nhacia el ' + NOM_DIR[d], elegir(ll[d][0], (1, 3, 5, 8, 10, 13))) for d in range(5)],
        ('FUEGO\nSalpicadura ardiente', elegir(sa[0], (3, 5, 8, 10, 13, 17))),
        ('FUEGO\nCombustion\n(se prende y revienta)', elegir(co[0], (2, 6, 8, 11, 14, 20))),
        ('FUEGO\nIgnicion', elegir(ig[0], (0, 2, 4, 7, 10, 14))),
        *[('CENIZA Y BRASA\nEscupitajo de brasas\nhacia el ' + NOM_DIR[d], elegir(eb[d][0], (4, 6, 8, 9, 11, 18))) for d in (1, 4)],
        ('CENIZA Y BRASA\nSacudida de ceniza', elegir(sc[0], (3, 5, 8, 10, 13, 17))),
        ('CENIZA Y BRASA\nNube de ceniza', elegir(nc[0], (2, 6, 8, 11, 15, 21))),
        ('CENIZA Y BRASA\nAvivar brasas', elegir(av[0], (0, 2, 4, 7, 10, 14))),
        *[('OBSIDIANA\nEmbestida cortante\nhacia el ' + NOM_DIR[d], elegir(ec[d][0], (1, 3, 5, 7, 10, 15))) for d in range(5)],
        *[('OBSIDIANA\nEsquirlas\nhacia el ' + NOM_DIR[d], elegir(eo[d][0], (3, 5, 7, 9, 12, 16))) for d in (1, 2, 4)],
        ('OBSIDIANA\nEstallido de agujas', elegir(pu[0], (3, 6, 7, 9, 13, 18))),
        ('OBSIDIANA\nAfilarse', elegir(af[0], (0, 2, 4, 6, 8, 11))),
    ]
    lamina(filas, os.path.join(SALIDA, 'slime_fuego.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], ll[1], ll[2], sa, co, ig, eb[1], sc, nc, av, ec[1], ec[2], eo[2], pu, af]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'slime_fuego.gif'), 3)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
