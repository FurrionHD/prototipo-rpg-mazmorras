#!/usr/bin/env python3
# ============================================================
#  arana_efectos_pixel.py -- LOS EFECTOS DE LA ARAÑA (y sus mutantes, Tejedora y Tormentosa) EN PIXEL ART (04/11/2026,
#  memoria efectos-a-pixel-art). Los mismos que hoy pintan InsectoAire (QUELICEROS, PONZONA, VENENO, HEBRAS, TELARANA, RED)
#  y AranaAire (RAYOS, FOGONAZO, CARGA) con su Hilo y su Arco. Cada una en SU paleta: la Tormentosa en azul y cian (NO el
#  amarillo del rayo de siempre, lo pidio el jefe) y la Tejedora en naranja de ascuas.
#  Lo que sale del cuerpo se MIDE en su dibujo. Las anims con loop false no se repiten.
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/arana_efectos_pixel.py
# ============================================================
import json
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO: antes de traer nada mas, que las demas piezas lo cojan ya.
W, H = 250, 210
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import slime_veneno_efectos_pixel as vn  # noqa: E402
from slime_efectos_pixel import (RAIZ, UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella, cometa_dir, victima, gota,  # noqa: E402
                                 charco, seco, Gotas, lamina, elegir, coletazo, sombra, DIRS, NOM_DIR)

ARANA, TEJEDORA, TORMENTOSA = 'arana_sdf', 'arana_sdf_tejedora', 'arana_sdf_tormentosa'
HUESO = [(92, 86, 78), (168, 162, 150), (226, 222, 208), (255, 255, 248)]
HUESO_B = (34, 30, 28)
VENENO = [(24, 78, 34), (64, 160, 62), (150, 226, 106), (232, 255, 190)]
VENENO_B = (10, 38, 16)
SEDA = [(120, 120, 128), (176, 176, 184), (222, 222, 228), (255, 255, 255)]
BRASA = [(120, 34, 8), (226, 90, 20), (255, 164, 56), (255, 236, 170)]
BRASA_B = (52, 14, 4)
RAYO = [(20, 40, 130), (40, 92, 214), (96, 204, 236), (236, 250, 255)]
RAYO_B = (8, 16, 60)
POLVO = ep.POLVO
CARBON = [(30, 26, 28), (58, 52, 54), (96, 90, 88), (140, 134, 130)]

_hojas, _datos, _pies = {}, {}, {}


def marco(var, anim, f, fila=0):
    clave = (var, anim)
    carpeta = os.path.join(RAIZ, 'assets/sprites/enemigos/%s' % var)
    if var not in _datos:
        with open(os.path.join(carpeta, 'hojas.json'), encoding='utf-8') as fh:
            _datos[var] = json.load(fh)
    if clave not in _hojas:
        _hojas[clave] = Image.open(os.path.join(carpeta, '%s.png' % anim)).convert('RGBA')
    d = _datos[var]
    lw, lh = d['lienzo']
    a = d['anims'][anim]
    n = a['fotogramas']
    f = f % n if a['loop'] else min(f, n - 1)
    return _hojas[clave].crop((f * lw, fila * lh, (f + 1) * lw, (fila + 1) * lh))


# LOS PIES: el centro del lienzo en x, y en y el centro de donde pisan sus patas (cuerpo cenital: 3/4 de su dibujo).
def pies(var):
    if var not in _pies:
        arr = np.array(marco(var, 'idle', 0, 2))
        ys, _x = np.nonzero(arr[:, :, 3] > 40)
        _pies[var] = (arr.shape[1] // 2, int(ys.min() + (ys.max() - ys.min()) * 0.72))
    return _pies[var]


def escena(suelo, cuerpos, aire):
    img = ep.fondo()
    for c in suelo:
        sl.volcar(img, c, True)
    for spr, var, x, y, alto in sorted(cuerpos, key=lambda c: c[3]):
        ox, oy = pies(var)
        img.paste(spr, (int(round(x)) - ox, int(round(y - alto)) - oy), spr)
    for c in aire:
        sl.volcar(img, c, False)
    sl._PEND.clear()
    return img


def alcance(var, fila):
    dx, dy = DIRS[fila]
    arr = np.array(marco(var, 'idle', 0, fila))
    ys, xs = np.nonzero(arr[:, :, 3] > 40)
    ox, oy = pies(var)
    return float(np.max((xs - ox) * dx + (ys - oy) * dy))


def centro_vivo(var, anim, f, fila, pal):
    """Donde SU dibujo tiene ese color (el abdomen de ascuas, el globo de luz): de ahi sale lo suyo."""
    arr = np.array(marco(var, anim, f, fila)).astype(int)
    if pal == 'brasa':
        m = (arr[:, :, 3] > 0) & (arr[:, :, 0] > 190) & (arr[:, :, 0] - arr[:, :, 2] > 110)
    else:
        m = (arr[:, :, 3] > 0) & (arr[:, :, 2] > 150) & (arr[:, :, 2] - arr[:, :, 0] > 70)
    ox, oy = pies(var)
    ys, xs = np.nonzero(m)
    if not len(xs):
        ys, xs = np.nonzero(arr[:, :, 3] > 40)
    return float(xs.mean()) - ox, float(ys.mean()) - oy


# --- LOS QUELICEROS: dos medias lunas que entran desde los lados y se cierran sobre el cuerpo (los colmillos los ensena su
# sprite; aqui solo el efecto) ---
def queliceros(a, x, y, dx, dy, e, pal=HUESO, borde=HUESO_B, r=11.0):
    abre = (1.3, 0.8, 0.3, 0.0, 0.0)[min(e, 4)]
    for lado in (-1, 1):
        # el centro de cada media luna, por FUERA del cuerpo: su curva queda mirando hacia el y se le va cerrando encima
        sx, sy = -dy * lado, dx * lado
        hueco = abre * 7 + 3
        coletazo(a, x + sx * (hueco + r), y + sy * (hueco + r), math.atan2(-sy, -sx), r, 0.9, 1.8, 1.0, 6.0, pal, borde)


def mordisco(fila, var=ARANA, anim='basico', pal=HUESO, borde=HUESO_B, efecto=None):
    dx, dy = DIRS[fila]
    al = alcance(var, fila)
    A = (W * 0.5 - dx * (al + 12) * 0.6, H * 0.6 - dy * (al + 12) * 0.5)
    V = (A[0] + dx * (al + 10), A[1] + dy * (al + 10) + 4)
    m, t = [], []
    for f in range(15):
        s, a = nuevo(), nuevo()
        e = f - 3
        if 0 <= e < 5:
            queliceros(a, V[0], V[1] - 10, dx, dy, e, pal, borde)
        if e == 3:
            estrella(a, V[0], V[1] - 10, 8, pal)
        if efecto and e >= 3:
            efecto(s, a, V, dx, dy, e - 3)
        victima(s, *V)
        m.append(escena([s], [(marco(var, anim, f, fila), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def veneno(s, a, V, dx, dy, e):
    g = Gotas(7, 5, 5.0, 14.0, sube=(5.0, 12.0), tam=(1.2, 1.9), pal=VENENO, borde=VENENO_B)
    g.pintar(s, a, V[0], V[1] - 8, min(1.0, e / 5.0), 2.0, 1.0, e - 5)
    charco(s, V[0], V[1] + 1, 7 * min(1.0, (e + 1) / 3.0), 2.0, seco(e, 4, 4), VENENO, VENENO_B)


def arco(a, x0, y0, x1, y1, sem, g=2.0, pal=RAYO, borde=RAYO_B, u=1.0):
    """Un rayo es una CINTA rellena en zigzag: gorda en medio y afilada en las puntas (nunca una raya). No se mueve: salta."""
    rnd = random.Random(sem)
    L = math.hypot(x1 - x0, y1 - y0) or 1
    px, py = -(y1 - y0) / L, (x1 - x0) / L
    n = max(3, int(L / 8))
    nodos = []
    for i in range(n + 1):
        c = i / n
        m_ = 0 if i in (0, n) else rnd.uniform(-5.5, 5.5)
        nodos.append((x0 + (x1 - x0) * c + px * m_, y0 + (y1 - y0) * c + py * m_))
    puntos = []
    for i in range(n):
        for q in range(int(L / n) + 1):
            c = q / max(int(L / n), 1)
            k = (i + c) / n
            if k > u:
                break
            puntos.append((nodos[i][0] + (nodos[i + 1][0] - nodos[i][0]) * c, nodos[i][1] + (nodos[i + 1][1] - nodos[i][1]) * c, g * math.sin(math.pi * min(max(k, 0.05), 0.95)) ** 0.6))
    for x, y, r in puntos:
        disco(a, x, y, r + 0.8, borde)
    for x, y, r in puntos:
        disco(a, x, y, r, pal[1])
    for x, y, r in puntos:
        disco(a, x, y, r * 0.5, pal[3] if r > 1 else pal[2])


def electrico(s, a, V, dx, dy, e):
    if e < 6:
        pecho = (V[0], V[1] - 10)
        for k in range(3):
            ang = k * 2.1 + e // 2
            arco(a, pecho[0], pecho[1], pecho[0] + math.cos(ang) * 14, pecho[1] + math.sin(ang) * 11, e // 2 * 7 + k, 1.3)
    if e < 2:
        estrella(a, V[0], V[1] - 10, (10, 6)[e], RAYO)


# --- LA TELARANA: el ovillo de seda vuela en parabola abriendose, revienta en hebras al caer y queda la RED tendida (radios y
# espiral), con hebras en las piernas de los que pilla. La de brasas: seda al rojo con ascuas. La electrificada: chispazos ---
def red(s, cx, cy, R, rota, sem, pal=SEDA, fase=0):
    """Radios y espiral en bloques; 'rota' 0..1 le va quitando trozos y la encoge."""
    rnd = random.Random(sem)
    R2 = R * (1 - rota * 0.3)
    n = 10
    for i in range(n):
        ang = i / n * math.tau + rnd.uniform(-0.1, 0.1)
        for q in range(int(R2 / 2)):
            d = q * 2 + 2
            if ((i * 7 + q * 3) % 11) / 11.0 >= rota * 1.2:
                punto(s, cx + math.cos(ang) * d, cy + math.sin(ang) * d * 0.72, pal[1])
    for k in range(1, 4):
        r = R2 * k / 3.5
        for i in range(n):
            a0 = i / n * math.tau
            a1 = (i + 1) / n * math.tau
            if ((i * 5 + k * 3) % 9) / 9.0 < rota * 1.2:
                continue
            x0, y0 = cx + math.cos(a0) * r, cy + math.sin(a0) * r * 0.72
            x1, y1 = cx + math.cos(a1) * r, cy + math.sin(a1) * r * 0.72
            # un poco combada hacia el centro
            for q in range(7):
                c = q / 6.0
                b = 1.0 - 0.1 * math.sin(c * math.pi)
                punto(s, cx + (x0 + (x1 - x0) * c - cx) * b, cy + (y0 + (y1 - y0) * c - cy) * b, pal[2] if q % 3 else pal[1])
    if rota < 0.5:   # el rocio
        for i in range(5):
            ang = rnd.uniform(0, math.tau)
            punto(s, cx + math.cos(ang) * R2 * 0.6, cy + math.sin(ang) * R2 * 0.42, pal[3], 2)


def telarana(fila, var=ARANA, pal=SEDA, tipo=None):
    dx, dy = DIRS[fila]
    dist = 120.0 / UNIDAD * 0.8
    A = (W * 0.5 - dx * dist * 0.5, H * 0.58 - dy * dist * 0.42)
    C = (A[0] + dx * dist, A[1] + dy * dist)
    R = 25.0 / UNIDAD * 1.1
    ox, oy = pies(var)
    arr = np.array(marco(var, 'telarana', 4, fila))
    ys, xs = np.nonzero(arr[:, :, 3] > 40)
    ALTO = (A[0] + xs.mean() - ox, A[1] + ys.min() - oy + 3)
    vict = [(C[0] - 6, C[1] + 3)]
    rnd = random.Random(4)
    m, t = [], []
    sale, vuelo = 4, 6
    for f in range(sale + vuelo + 20):
        s, a = nuevo(), nuevo()
        e = f - sale
        if 0 <= e < vuelo:
            u = (e + 1) / vuelo
            x, y = ALTO[0] + (C[0] - ALTO[0]) * u, ALTO[1] + (C[1] - 6 - ALTO[1]) * u - 26 * 4 * u * (1 - u)
            r = 2.5 + 3.0 * u
            disco(a, x, y, r + 0.7, pal[0])
            disco(a, x, y, r, pal[2])
            disco(a, x - 1, y - 1, r * 0.5, pal[3])
            for k in range(4):   # las hebras que se le abren
                ang = k * 1.57 + e * 0.6
                for q in range(int(r), int(r + 3 * u) + 2):
                    punto(a, x + math.cos(ang) * q, y + math.sin(ang) * q, pal[1])
            sombra(s, A[0] + (C[0] - A[0]) * u, A[1] + (C[1] - A[1]) * u, 3 + 2 * u)
        elif e >= vuelo:
            g = e - vuelo
            k = 1.0 - (1.0 - min(1.0, (g + 1) / 3.0)) ** 2
            rota = max(0.0, (g - 11) / 9.0)
            red(s, C[0], C[1], R * k, rota, 3, pal)
            if g < 2:
                estrella(a, C[0], C[1] - 3, (10, 6)[g], pal)
            if tipo == 'brasas' and rota < 0.6:
                # la seda al rojo: ascuas que suben de la red
                r2 = random.Random(7)
                for _ in range(7):
                    fx = C[0] + r2.uniform(-R, R) * 0.8
                    fy = C[1] + r2.uniform(-R, R) * 0.5
                    fase = r2.random()
                    h = ((g / 8.0 + fase) % 1.0)
                    punto(a, fx, fy - h * 16, BRASA[3] if h < 0.4 else BRASA[1], 2 if h < 0.5 else 1)
            elif tipo == 'rayo' and g % 3 != 2 and rota < 0.5:
                ang = (g // 3) * 2.4
                arco(a, C[0] + math.cos(ang) * R * 0.8, C[1] + math.sin(ang) * R * 0.55, C[0] + math.cos(ang + 2.2) * R * 0.7, C[1] + math.sin(ang + 2.2) * R * 0.5, g // 3 * 5, 1.2)
            # hebras en las piernas
            if rota < 0.6:
                for v in vict:
                    for j in (-3, 0, 3):
                        for q in range(6):
                            punto(a, v[0] + j + math.sin(q + j) * 1.0, v[1] - q * 1.2, pal[2 if q % 2 else 1])
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'telarana', f, fila), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- EL HILO AL ROJO (tejedora): dispara en el 0,4 del gesto: un hilo al rojo que cruza desde su abdomen, y le tira ---
def hilo(fila, var=TEJEDORA):
    dx, dy = DIRS[fila]
    L = 110.0 / UNIDAD * 0.8
    A = (W * 0.5 - dx * L * 0.5, H * 0.58 - dy * L * 0.42)
    V0 = (A[0] + dx * L, A[1] + dy * L + 4)
    m, t = [], []
    sale = 4
    for f in range(sale + 14):
        s, a = nuevo(), nuevo()
        spr = marco(var, 'hilo', f, fila)
        cx, cy = centro_vivo(var, 'hilo', f, fila, 'brasa')
        O = (A[0] + cx, A[1] + cy)
        e = f - sale
        tira = 0 if e < 3 else min(1.0, (e - 2) / 5.0) * 16
        V = (V0[0] - dx * tira, V0[1] - dy * tira)
        if 0 <= e < 9:
            u = min(1.0, (e + 1) / 2.0)
            arco(a, O[0], O[1], V[0], V[1] - 10, 3 + e // 2, 1.8 if e < 6 else 1.0, BRASA, BRASA_B, u)
        if e in (1, 2):
            estrella(a, V[0], V[1] - 10, (10, 7)[e - 1], BRASA)
        if e >= 2 and e < 8:
            for q in range(5):
                ang = q * 1.3
                punto(a, V[0] + math.cos(ang) * (3 + e), V[1] - 10 + math.sin(ang) * (2 + e) + e * 0.6, BRASA[2], 2)
        victima(s, *V)
        m.append(escena([s], [(spr, var, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- EL CAPULLO DE CENIZA (tejedora): teje cargando, el hilo le sale y al llegar lo encierra en el capullo (sprite suyo) ---
def capullo(fila=2, var=TEJEDORA):
    dx, dy = DIRS[fila]
    L = 92
    A = (W * 0.3, H * 0.6)
    V = (A[0] + dx * L, A[1] + dy * L + 2)
    m, t = [], []
    carga = 7
    for f in range(carga + 16):
        s, a = nuevo(), nuevo()
        e = f - carga
        anim = 'capullo_carga' if e < 0 else 'capullo'
        spr = marco(var, anim, f if e < 0 else e, fila)
        cx, cy = centro_vivo(var, anim, f if e < 0 else e, fila, 'brasa')
        O = (A[0] + cx, A[1] + cy)
        if e < 0:
            r2 = random.Random(f // 2)
            for _ in range(4):
                punto(a, O[0] + r2.uniform(-9, 9), O[1] + r2.uniform(-9, 9), BRASA[2], 2)
        cuerpos = [(spr, var, A[0], A[1], 0)]
        if 0 <= e < 6:
            arco(a, O[0], O[1], V[0], V[1] - 10, 4 + e // 2, 1.8, BRASA, BRASA_B, min(1.0, (e + 1) / 2.0))
        if e < 2:
            victima(s, *V)
        if e >= 2:
            # se va cerrando de abajo arriba: SU sprite de capullo, destapado por filas
            k = min(1.0, (e - 1) / 4.0)
            cap = np.array(marco('capullo_sdf', 'idle', 0, 0))
            ys_c, _xc = np.nonzero(cap[:, :, 3] > 40)
            corte = int(ys_c.max() - (ys_c.max() - ys_c.min()) * k)
            cap[:corte, :, 3] = 0
            cuerpos.append((Image.fromarray(cap, 'RGBA'), 'capullo_sdf', V[0], V[1], 0))
            if e == 2:
                estrella(a, V[0], V[1] - 12, 11, BRASA)
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 12)
    return m, t


# --- LA EXPLOSION DE BRASAS y su climax: el fogonazo (estrella maciza), un aro de fuego que se abre por el suelo con su cuerpo
# deshaciendose detras, y chispas que suben y caen ---
def explosion(var=TEJEDORA, radio_mundo=50.0):
    A = (W * 0.5, H * 0.58)
    R = radio_mundo / UNIDAD
    rnd = random.Random(3)
    chispas = [(rnd.uniform(0, math.tau), rnd.uniform(0.5, 1.2), rnd.uniform(16, 34)) for _ in range(22)]
    vict = [(A[0] + R + 8, A[1] + 6), (A[0] - R - 6, A[1] - 10)]
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        spr = marco(var, 'explosion', f, 1)
        cx, cy = centro_vivo(var, 'explosion', 0, 1, 'brasa')
        O = (A[0] + cx, A[1] + cy)
        e = f - 2
        if e >= 0:
            if e < 3:
                estrella(a, O[0], O[1], (20, 32, 18)[e], BRASA)
            k = min(1.0, (e + 1) / 6.0)
            if e < 7:
                ep.banda(s, A[0], A[1], R * k, 8.0 * (1 - e / 9.0) + 2.0, BRASA, False, e)
            d = np.hypot(XX - A[0], YY - A[1])
            poner(s, (d < R * k) & (TRAMA < 0.35 * seco(e, 6, 6)), CARBON[0])
            for ang, v, sube in chispas:
                u = min(1.0, (e + 1) / 10.0)
                if u < 1:
                    x, y = A[0] + math.cos(ang) * R * v * u, O[1] + math.sin(ang) * R * v * 0.7 * u - sube * 4 * u * (1 - u)
                    xa, ya = A[0] + math.cos(ang) * R * v * (u - 0.1), O[1] + math.sin(ang) * R * v * 0.7 * (u - 0.1) - sube * 4 * (u - 0.1) * (1.1 - u)
                    n = math.hypot(x - xa, y - ya) or 1
                    cometa_dir(a, x, y, (x - xa) / n, (y - ya) / n, 6, 0, BRASA)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(spr, var, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LA DESCARGA y su climax (tormentosa): rayos a todos lados que saltan por el suelo, con destellos donde caen ---
def descarga(var=TORMENTOSA, radio_mundo=60.0):
    A = (W * 0.5, H * 0.6)
    R = radio_mundo / UNIDAD
    vict = [(A[0] + R * 0.9, A[1] + 6), (A[0] - R * 0.85, A[1] - 10), (A[0] + 5, A[1] + R * 0.8)]
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        spr = marco(var, 'descarga', f, 1)
        cx, cy = centro_vivo(var, 'descarga', 0, 1, 'azul')
        O = (A[0] + cx, A[1] + cy)
        e = f - 2
        if 0 <= e < 10:
            if e < 2:
                estrella(a, O[0], O[1], (16, 24)[e], RAYO)
            salto_ = e // 2
            rnd = random.Random(salto_ * 13 + 1)
            for k in range(7):
                ang = k / 7 * math.tau + rnd.uniform(-0.3, 0.3)
                d = R * rnd.uniform(0.7, 1.1)
                x, y = A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d * 0.72
                arco(a, O[0], O[1], x, y, salto_ * 7 + k, 2.2 * (1 - e / 13.0) + 0.5)
                if e % 2 == 0:
                    estrella(a, x, y - 1, 6, RAYO)
                poner(s, (np.hypot(XX - x, YY - y) < 5) & (TRAMA < 0.5), RAYO[0])
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(spr, var, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- EL PISOTON DE TRUENO: grietas y anillo de polvo, como el del jabali, con chispazos azules en las grietas ---
def grietas(s, x, y, largo, sem, n=8):
    rnd = random.Random(sem)
    fin = []
    for i in range(n):
        ang = i / n * math.tau + rnd.uniform(-0.3, 0.3)
        px, py = x + math.cos(ang) * 12, y + math.sin(ang) * 8
        pasos = int(largo * rnd.uniform(0.6, 1.0) / 2.5)
        for p in range(pasos):
            ang += rnd.uniform(-0.45, 0.45)
            px, py = px + math.cos(ang) * 2.5, py + math.sin(ang) * 2.0
            punto(s, px, py, (14, 14, 22), 2 if p < pasos * 0.6 else 1)
        fin.append((px, py))
    return fin


def pisoton(var=TORMENTOSA, radio_mundo=45.0):
    A = (W * 0.5, H * 0.6)
    R = radio_mundo / UNIDAD
    rnd = random.Random(6)
    polvo = [(i / 14 * math.tau + rnd.uniform(-0.15, 0.15), rnd.uniform(3.2, 4.8)) for i in range(14)]
    vict = [(A[0] + R + 8, A[1] + 4), (A[0] - R - 8, A[1] - 12)]
    m, t = [], []
    golpe = 5
    for f in range(golpe + 15):
        s, a = nuevo(), nuevo()
        e = f - golpe
        if e >= 0:
            if seco(e, 10, 4) > 0:
                fin = grietas(s, A[0], A[1], R * min(1.0, (e + 2) / 3.0), 5)
                if e % 3 != 2 and e < 11:
                    for i, (x, y) in enumerate(fin[(e // 3) % 2::2]):
                        arco(a, A[0] + math.cos(i * 1.6) * 10, A[1] + math.sin(i * 1.6) * 7, x, y, e // 3 + i * 3, 1.3)
            for ang, r in polvo:
                rr = r * max(0.0, 1.0 - e / 7.0)
                if rr > 0.7:
                    d = 14 + e * 3.2
                    ep.bolita(s if math.sin(ang) < 0 else a, A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d * 0.7 - e * 0.5, rr, POLVO)
            if e < 2:
                estrella(a, A[0], A[1] - 2, (14, 9)[e], RAYO)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'pisoton', f, 1), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- EL SALTO DE ARCO: salta sobre el, deja el arco por donde va y cae con un chispazo, y salta a otro cercano (el rebote) ---
def salto(fila=2, var=TORMENTOSA):
    dx, dy = DIRS[fila]
    L = 90
    A = (W * 0.26 - dx * 0, H * 0.62)
    V = (A[0] + dx * L, A[1] + dy * L + 2)
    B = (V[0] - dx * 18, V[1] - dy * 18 - 2)
    V2 = (V[0] + 36, V[1] - 22)
    m, t = [], []
    carga, vuelo = 4, 5
    for f in range(carga + vuelo + 14):
        s, a = nuevo(), nuevo()
        if f < carga:
            x, y, alto, anim, fr = A[0], A[1], 0, 'salto', f
        elif f < carga + vuelo:
            u = (f - carga + 1) / vuelo
            x, y = A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u
            alto = 28 * 4 * u * (1 - u)
            anim, fr = 'salto', f
            sombra(s, x, y, 7)
            arco(a, A[0], A[1] - 6, x, y - alto - 6, f // 2, 1.4)
        else:
            e = f - carga - vuelo
            x, y, alto = B[0], B[1], 0
            anim, fr = 'mordisco', e
            if e < 5:
                queliceros(a, V[0], V[1] - 10, dx, dy, e, RAYO, RAYO_B)
            if e < 8:
                electrico(s, a, V, dx, dy, e)
            if 4 <= e < 9:
                arco(a, V[0], V[1] - 10, V2[0], V2[1] - 10, e // 2, 1.6)
                if e < 6:
                    estrella(a, V2[0], V2[1] - 10, 7, RAYO)
        victima(s, *V)
        victima(s, *V2)
        m.append(escena([s], [(marco(var, anim, fr, fila), var, x, y, alto)], [a]))
        t.append(1000 // 12)
    return m, t


# --- LAS CARGAS: chispazos (tormentosa) o ascuas (tejedora) alrededor del cuerpo, mas cuantas mas cargas, y el contador encima ---
def cargas(var, nivel, tope=4, fuego=False):
    A = (W * 0.5, H * 0.62)
    arr = np.array(marco(var, 'idle', 0, 1))
    ys, xs = np.nonzero(arr[:, :, 3] > 40)
    ox, oy = pies(var)
    arriba, r = ys.min() - oy, (xs.max() - xs.min()) * 0.45
    cy = (ys.min() + ys.max()) / 2 - oy
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        rnd = random.Random(nivel)
        if fuego:
            for _ in range(nivel * 5):
                fx, fase = rnd.uniform(-r, r), rnd.random()
                h = (f / 10.0 + fase) % 1.0
                punto(a, A[0] + fx, A[1] + cy + rnd.uniform(0, 8) - h * 26, BRASA[3] if h < 0.4 else BRASA[1], 2 if h < 0.5 else 1)
        else:
            salto_ = f // 2
            r2 = random.Random(salto_ * 3 + nivel)
            for k in range(nivel):
                ang = r2.uniform(0, math.tau)
                x0, y0 = A[0] + math.cos(ang) * r * 0.6, A[1] + cy + math.sin(ang) * r * 0.6
                arco(a, x0, y0, x0 + math.cos(ang) * 14, y0 + math.sin(ang) * 11, salto_ + k, 1.2)
        # el contador: un CIRCULO por carga encima, encendidos los que lleva (como en el juego, AranaAire._pinta_carga)
        pal = BRASA if fuego else RAYO
        for k in range(tope):
            x = A[0] + (k - (tope - 1) / 2) * 7
            y = A[1] + arriba - 8
            disco(a, x, y, 3.0, (14, 12, 16))
            disco(a, x, y, 2.1, pal[2] if k < nivel else CARBON[1])
            if k < nivel:
                punto(a, x - 1, y - 1, pal[3])
        m.append(escena([s], [(marco(var, 'idle', f, 1), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: mordisco(d) for d in (1, 2, 4)}
    po = {d: mordisco(d, ARANA, 'mordisco', VENENO, VENENO_B, veneno) for d in (1, 4)}
    te = {d: telarana(d) for d in (1, 2)}
    tb = {d: telarana(d, TEJEDORA, BRASA, 'brasas') for d in (1, 4)}
    hi = {d: hilo(d) for d in (1, 2, 4)}
    ca = capullo()
    ex = explosion()
    cf = {n: cargas(TEJEDORA, n, 4, True) for n in (1, 4)}
    re = {d: telarana(d, TORMENTOSA, SEDA, 'rayo') for d in (2, 4)}
    me = {d: mordisco(d, TORMENTOSA, 'mordisco', RAYO, RAYO_B, electrico) for d in (1, 4)}
    pi = pisoton()
    sa = salto()
    de = descarga()
    cr = {n: cargas(TORMENTOSA, n, 4, False) for n in (1, 4)}
    filas = [
        *[('ARANA\nbasico (queliceros)\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (2, 3, 4, 6, 7, 10))) for d in (1, 2, 4)],
        *[('ARANA\nMordisco ponzonoso\nhacia el ' + NOM_DIR[d], elegir(po[d][0], (3, 5, 6, 7, 9, 12))) for d in (1, 4)],
        *[('ARANA\nTelarana (y la red\nque se va rompiendo)\nhacia el ' + NOM_DIR[d], elegir(te[d][0], (5, 8, 11, 15, 22, 28))) for d in (1, 2)],
        *[('TEJEDORA\nTelarana de brasas\nhacia el ' + NOM_DIR[d], elegir(tb[d][0], (5, 8, 11, 15, 22, 28))) for d in (1, 4)],
        *[('TEJEDORA\nHilo al rojo\nhacia el ' + NOM_DIR[d], elegir(hi[d][0], (3, 5, 6, 8, 11, 14))) for d in (1, 2, 4)],
        ('TEJEDORA\nCapullo de ceniza', elegir(ca[0], (3, 8, 9, 11, 14, 20))),
        ('TEJEDORA\nExplosion de brasas', elegir(ex[0], (1, 3, 4, 6, 9, 14))),
        *[('TEJEDORA\nascuas y contador\n%d cargas' % n, elegir(cf[n][0], (0, 2, 4, 6, 8, 10))) for n in (1, 4)],
        *[('TORMENTOSA\nRed electrificada\nhacia el ' + NOM_DIR[d], elegir(re[d][0], (5, 8, 11, 15, 22, 28))) for d in (2, 4)],
        *[('TORMENTOSA\nMordisco electrico\nhacia el ' + NOM_DIR[d], elegir(me[d][0], (3, 5, 6, 7, 9, 12))) for d in (1, 4)],
        ('TORMENTOSA\nPisoton de trueno', elegir(pi[0], (3, 5, 7, 9, 12, 17))),
        ('TORMENTOSA\nSalto de arco\ny el rebote', elegir(sa[0], (2, 5, 8, 10, 13, 16))),
        ('TORMENTOSA\nDescarga', elegir(de[0], (1, 2, 4, 6, 9, 12))),
        *[('TORMENTOSA\nchispazos y contador\n%d cargas' % n, elegir(cr[n][0], (0, 2, 4, 6, 8, 10))) for n in (1, 4)],
    ]
    lamina(filas, os.path.join(SALIDA, 'arana.png'), 2)
    todos, tiempos = [], []
    for marcos, ts in [ba[1], po[1], te[1], tb[1], hi[2], ca, ex, cf[4], re[2], me[1], pi, sa, de, cr[4]]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'arana.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
