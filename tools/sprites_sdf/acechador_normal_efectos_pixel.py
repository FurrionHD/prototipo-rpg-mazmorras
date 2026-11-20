#!/usr/bin/env python3
# ============================================================
#  acechador_normal_efectos_pixel.py -- LOS EFECTOS DEL ACECHADOR NORMAL EN PIXEL ART (20/11/2026, memorias
#  efectos-a-pixel-art y efectos-pixel-lamina-por-enemigo: "rehacerlos visualmente iguales pero en pixel art"; se hace al
#  hacerle sus mutantes). Los mismos que hoy (capturas en Desktop/ataques_mapa/enemigos/acechador/*.png), en pixel y con
#  las piezas ya aprobadas de la rata y el Rey Rata (mandibula, bocado, sangre). La Sombra sin rostro pega con este mismo
#  kit (fisico), asi que le sirven tambien.
#    BASICO               las fauces se cierran sobre el objetivo y destello (sin sangre, como hoy)
#    ZARPAZO DOBLE        tres zarpazos de garra (estelas gruesas, nada de rayas finas), uno con cada mano
#    SALTO A LA YUGULAR   la estela oscura del salto, el bocado y la sangre
#    DENTELLADA           dos bocados seguidos y la sangre que salta (deja Sangrado)
#    OLOR A SANGRE        de quien sangra suben motas rojas ondulando hacia su hocico (su pasiva: va a por el)
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/acechador_normal_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np

import slime_efectos_pixel as sl
import escarabajo_efectos_pixel as ep
import rata_efectos_pixel as rt

# Lienzo propio (el acechador es largo y salta): las piezas de ep/sl/rt leen estos globales.
W, H = 240, 190
YY, XX = np.mgrid[0:H, 0:W]
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
for _m in (ep, sl, rt):
    _m.W, _m.H, _m.YY, _m.XX, _m.TRAMA = W, H, YY, XX, TRAMA

from slime_efectos_pixel import (UNIDAD, SALIDA, nuevo, punto, disco, estrella, Gotas, victima,  # noqa: E402
                                 lamina, elegir, DIRS, NOM_DIR)
from rata_efectos_pixel import marco, escena, bocado, SANGRE, SANGRE_BORDE, HUESO  # noqa: E402

NORMAL = 'acechador_sdf'
SOMBRA_P = [(10, 8, 14), (26, 22, 34), (46, 40, 58), (70, 62, 86)]   # la estela del salto (oscura, como hoy)
GARRA = [(70, 68, 84), (190, 194, 210), (236, 238, 248), (255, 255, 255)]
OLOR = [(110, 14, 18), (180, 30, 34), (230, 70, 70), (255, 150, 140)]


def sangre(n, sem, eje, tam=(1.2, 2.0)):
    return Gotas(n, sem, 6.0, 18.0, (eje, 0.8), sube=(5.0, 12.0), tam=tam, pal=SANGRE, borde=SANGRE_BORDE)


def pareja(fila, dist=44):
    dx, dy = DIRS[fila]
    A = (W * 0.5 - dx * dist * 0.55, H * 0.56 - dy * dist * 0.45)
    V = (A[0] + dx * dist, A[1] + dy * dist + 6)
    return dx, dy, A, V


def hocico(A, dx, dy):
    return (A[0] + dx * 24, A[1] + dy * 18 - 6)


# --- BASICO ---
def basico(fila):
    dx, dy, A, V = pareja(fila)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        e = f - 2
        if 0 <= e < 5:
            bocado(s, a, V, dx, dy, min(e, 4))
        victima(s if dy >= 0 else a, *V)
        m.append(escena([s], [(marco(NORMAL, 'basico', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 16)
    return m, t


# --- ZARPAZO DOBLE ---
def trazo(a, p0, p1, curva, ancho, hasta, pal, densidad=1.0):
    """Un trazo curvo de p0 a p1 (combado 'curva' px hacia su normal), grueso en el medio y afilado en las puntas,
    dibujado hasta 'hasta' (0..1): borde oscuro, cuerpo y nucleo claro. Por discos: nada de lineas de 1 celda."""
    nx, ny = -(p1[1] - p0[1]), p1[0] - p0[0]
    n = math.hypot(nx, ny) or 1
    nx, ny = nx / n, ny / n
    pasos = int(math.hypot(p1[0] - p0[0], p1[1] - p0[1]) * 1.5) + 2
    for k in range(pasos + 1):
        t = k / pasos
        if t > hasta:
            break
        b = math.sin(t * math.pi)
        x = p0[0] + (p1[0] - p0[0]) * t + nx * curva * b
        y = p0[1] + (p1[1] - p0[1]) * t + ny * curva * b
        w = ancho * b ** 0.7
        if w < 0.5:
            continue
        disco(a, x, y, w + 0.5, pal[1], densidad)
        disco(a, x, y, w, pal[2], densidad)
        if w > 0.9:
            disco(a, x, y, w * 0.55, pal[3], densidad)


def zarpa(a, V, dx, dy, e, lado):
    """Tres ZARPAZOS curvos sobre el objetivo (uno con cada mano: 'lado'): se dibujan de arriba a abajo en dos marcos,
    aguantan y se deshacen (trama)."""
    if e < 0 or e > 7:
        return
    cx, cy = V[0], V[1] - 11
    hasta = min(1.0, (e + 1) / 2.0)
    dens = 1.0 if e < 4 else max(0.0, 1.0 - (e - 3) / 4.0)
    for k in (-1, 0, 1):
        x0 = cx - lado * 11 + k * 6
        p0 = (x0, cy - 14 + abs(k) * 2)
        p1 = (x0 + lado * 16, cy + 11 + abs(k) * 2)
        trazo(a, p0, p1, -lado * 3.5, 1.7, hasta, GARRA, dens)
    if e == 2:
        estrella(a, cx, cy, 4, HUESO)


def zarpazo(fila):
    dx, dy, A, V = pareja(fila, 40)
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        zarpa(a, V, dx, dy, f - 3, -1)
        zarpa(a, V, dx, dy, f - 7, 1)
        victima(s if dy >= 0 else a, *V)
        m.append(escena([s], [(marco(NORMAL, 'zarpazo', min(f, 11), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 20)
    return m, t


# --- SALTO A LA YUGULAR ---
def estela_salto(s, a, A, x, y, dx, dy, f):
    """La estela oscura del salto: bocanadas de sombra a lo largo de lo recorrido que se deshacen (trama)."""
    dist = math.hypot(x - A[0], y - A[1])
    if dist < 3:
        return
    # UNA estela CURVA que sigue el arco del salto (sube y baja), gruesa en su lomo y afilada hacia atras; al aterrizar se
    # deshace (trama)
    dens = 1.0 if f <= 6 else max(0.0, 1.0 - (f - 6) / 5.0)
    if dens <= 0:
        return
    # desde DETRAS de donde salto hasta su lomo, en arco por ENCIMA del cuerpo (asi asoma: el cuerpo tapa lo de abajo)
    x0, y0 = A[0] - dx * 26, A[1] - dy * 20
    x1, y1 = x - dx * 6, y - dy * 4
    dist = math.hypot(x1 - x0, y1 - y0)
    pasos = int(dist * 1.5) + 2
    for k in range(pasos + 1):
        u = k / pasos
        px = x0 + (x1 - x0) * u
        py = y0 + (y1 - y0) * u - 16 - math.sin(u * math.pi) * 12
        w = 0.6 + 3.2 * u ** 1.4
        disco(a, px, py, w + 0.6, SOMBRA_P[0], dens * (0.4 + 0.6 * u))
        disco(a, px, py, w, SOMBRA_P[2], dens * (0.4 + 0.6 * u))


def yugular(fila):
    dx, dy = DIRS[fila]
    L = 58.0 / UNIDAD
    A = (W * 0.5 - dx * L * 0.6, H * 0.56 - dy * L * 0.5)
    V = (A[0] + dx * (L + 8), A[1] + dy * (L + 8) + 6)
    sg = sangre(10, 7 + fila, math.atan2(dy, dx), (1.2, 2.2))
    m, t = [], []
    corre = 6
    for f in range(corre + 12):
        s, a = nuevo(), nuevo()
        u = min(1.0, max(0.0, (f - 1) / float(corre - 1)))
        x, y = A[0] + dx * L * 0.7 * u, A[1] + dy * L * 0.7 * u
        if f >= 2:
            estela_salto(s, s, A, x, y, dx, dy, f)   # en la capa de abajo: el cuerpo va ENCIMA de su estela
        e = f - corre
        if 0 <= e < 5:
            bocado(s, a, V, dx, dy, min(e + 1, 4))
        if e >= 1:
            sg.pintar(s, a, V[0], V[1] - 4, min(1.0, (e - 1) / 7.0), 2.0, 1.0, e - 9)
        victima(s if dy >= 0 else a, *V)
        m.append(escena([s], [(marco(NORMAL, 'yugular', min(f, 13), fila), x, y, 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- DENTELLADA DESGARRADORA ---
def dentellada(fila):
    dx, dy, A, V = pareja(fila, 42)
    g1 = sangre(9, 3 + fila, math.atan2(dy, dx))
    g2 = sangre(12, 11 + fila, math.atan2(dy, dx) + 0.4, (1.4, 2.4))
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        for k, (ini, g) in enumerate(((2, g1), (6, g2))):
            e = f - ini
            if 0 <= e < 5:
                bocado(s, a, V, dx, dy, min(e, 4))
            if e >= 3:
                g.pintar(s, a, V[0] + k * 2, V[1] - 3, min(1.0, (e - 3) / 5.0), 2.0, 1.0, e - 9)
        victima(s if dy >= 0 else a, *V)
        m.append(escena([s], [(marco(NORMAL, 'desgarrar', min(f, 11), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 16)
    return m, t


# --- OLOR A SANGRE (la pasiva) ---
def olor(fila):
    dx, dy, A, V = pareja(fila, 70)
    nariz = hocico(A, dx, dy)
    rnd = random.Random(4)
    hilos = [(rnd.uniform(0, math.tau), rnd.uniform(-5, 5)) for _ in range(3)]
    m, t = [], []
    for f in range(20):
        s, a = nuevo(), nuevo()
        # la herida de quien sangra: unas gotas
        if f % 5 == 0 or f % 5 == 1:
            punto(s, V[0] + 2, V[1] - 6 + (f % 5) * 2, SANGRE[1], 2)
        for k, (fase, lado) in enumerate(hilos):
            for i in range(6):
                u = ((f / 20.0) + i / 6.0 + k * 0.11) % 1.0
                x = V[0] + (nariz[0] - V[0]) * u
                y = V[1] - 12 + (nariz[1] - V[1] + 12) * u - math.sin(u * math.pi) * 10
                ox = -dy * math.sin(u * 9 + fase) * 4 + lado * (1 - u)
                oy = dx * math.sin(u * 9 + fase) * 4
                vida = math.sin(u * math.pi)
                col = OLOR[3] if u > 0.8 else (OLOR[2] if u > 0.4 else OLOR[1])
                disco(a, x + ox, y + oy, 1.6 + 0.6 * (1 - u), col, 0.35 + 0.65 * vida)
        victima(s, *V)
        m.append(escena([s], [(marco(NORMAL, 'idle', f % 8, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: basico(d) for d in (1, 4)}
    za = {d: zarpazo(d) for d in (1, 4)}
    yu = {d: yugular(d) for d in (1, 2)}
    de = {d: dentellada(d) for d in (1, 4)}
    ol = {d: olor(d) for d in (1, 2)}
    filas = [
        *[('BASICO\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 6, 9))) for d in (1, 4)],
        *[('ZARPAZO DOBLE\nhacia el ' + NOM_DIR[d], elegir(za[d][0], (3, 4, 5, 7, 8, 10))) for d in (1, 4)],
        *[('SALTO A LA YUGULAR\nhacia el ' + NOM_DIR[d], elegir(yu[d][0], (1, 3, 5, 7, 9, 13))) for d in (1, 2)],
        *[('DENTELLADA\nhacia el ' + NOM_DIR[d], elegir(de[d][0], (2, 5, 7, 9, 11, 15))) for d in (1, 4)],
        *[('OLOR A SANGRE\n(pasiva) hacia el ' + NOM_DIR[d], elegir(ol[d][0], (0, 3, 6, 9, 12, 15))) for d in (1, 2)],
    ]
    ruta = os.path.join(SALIDA, 'acechador.png')
    lamina(filas, ruta, 3)
    # la tira tambien para Paint (no anima los gif) y los gif
    from PIL import Image
    for nombre, (mm, tt) in (('basico', ba[1]), ('zarpazo', za[1]), ('yugular', yu[2]), ('dentellada', de[1]),
                             ('olor', ol[2])):
        fotos = [x.convert('RGB').resize((W * 3, H * 3), Image.NEAREST) for x in mm]
        fotos[0].save(os.path.join(SALIDA, 'acechador_%s.gif' % nombre), save_all=True, append_images=fotos[1:],
                      duration=tt, loop=0)
    print(ruta)
    return ruta


if __name__ == '__main__':
    principal()
