#!/usr/bin/env python3
# ============================================================
#  trent_efectos_pixel.py -- LOS EFECTOS DEL TRENT (y sus mutantes, Tocon ambarino y Espantajo, y los bichos de la costra)
#  EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art), sobre los cuerpos nuevos de brazos de rama. Los mismos que hoy
#  pintan BestiaAire (RAMALAZO, RAMAZO, RAICES, SAVIA, CHARCO, ATADO), TrentAire (lo que eligio el jefe: GEISER B nube y
#  CHUPAR A hilos; RESINA, ESTALLIDO, HUMO, CARGA, SECO, GOTERON) y AmbarAire (BOLA, PRINGUE, PICOR, REVIENTA).
#  LO QUE YA TRAE SU SPRITE NO SE REPITE: la grieta violeta se MIDE en su dibujo (lo que late y de donde sale el chorro).
#  Las anims con loop false no se repiten.
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/trent_efectos_pixel.py
# ============================================================
import json
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO GRANDE: el Espantajo mide 180 de alto: antes de traer nada mas, que las demas piezas lo cojan ya.
W, H = 330, 280
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import slime_veneno_efectos_pixel as vn  # noqa: E402
from slime_efectos_pixel import (RAIZ, UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella, cometa_dir, victima, gota,  # noqa: E402
                                 charco, seco, Gotas, lamina, elegir, coletazo, cristal, sombra, DIRS, NOM_DIR)

NORMAL, AMBARINO, SIN_COSTRA, ESPANTAJO = 'trent_sdf', 'trent_sdf_ambarino', 'trent_sdf_ambarino_sin_costra', 'trent_sdf_espantajo'
MADERA = [(52, 34, 22), (104, 72, 44), (156, 116, 74), (214, 176, 124)]
MADERA_BORDE = (28, 18, 12)
HOJA = [(30, 70, 34), (62, 122, 54), (118, 176, 76), (190, 224, 120)]
SAVIA = [(44, 78, 22), (92, 142, 34), (158, 200, 62), (226, 244, 140)]
SAVIA_BORDE = (20, 38, 10)
AMBAR = [(120, 62, 8), (214, 128, 20), (250, 184, 56), (255, 238, 170)]
AMBAR_BORDE = (60, 30, 6)
NEGRA = [(14, 8, 22), (34, 20, 54), (84, 56, 138), (190, 160, 250)]
NEGRA_BORDE = (6, 3, 10)
HUMO_V = [(44, 28, 74), (78, 52, 124), (126, 92, 188), (206, 186, 250)]
CACA = [(44, 28, 16), (86, 56, 30), (128, 88, 50), (172, 130, 84)]
RONCHA = [(120, 20, 24), (206, 50, 50), (250, 110, 96), (255, 200, 180)]

_hojas, _datos, _pies = {}, {}, {}


def marco(var, anim, f, fila=0):
    """Las anims con loop false se quedan en su ultimo marco: no vuelven a empezar."""
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


# LOS PIES medidos: el centro del lienzo en x y lo mas bajo de su dibujo quieto de lado.
def pies(var):
    if var not in _pies:
        arr = np.array(marco(var, 'idle', 0, 2))
        ys, _x = np.nonzero(arr[:, :, 3] > 40)
        _pies[var] = (arr.shape[1] // 2, int(ys.max()) - 3)
    return _pies[var]


def escena(suelo, cuerpos, aire):
    img = ep.fondo()
    for c in suelo:
        sl.volcar(img, c, True)
    for spr, var, x, y, alto in sorted(cuerpos, key=lambda c: c[3]):
        ox, oy = pies(var) if var else (spr.size[0] // 2, spr.size[1] // 2)
        img.paste(spr, (int(round(x)) - ox, int(round(y - alto)) - oy), spr)
    for c in aire:
        sl.volcar(img, c, False)
    sl._PEND.clear()
    return img


def medida(var, anim, f, fila):
    """(frente del dibujo hacia donde mira, relativo a los pies), bbox alto, ancho."""
    arr = np.array(marco(var, anim, f, fila))
    ys, xs = np.nonzero(arr[:, :, 3] > 40)
    ox, oy = pies(var)
    return xs - ox, ys - oy, arr


def alcance(var, fila):
    dx, dy = DIRS[fila]
    xs, ys, _a = medida(var, 'idle', 0, fila)
    bajos = ys > ys.min() + (ys.max() - ys.min()) * 0.5     # lo de abajo: patas y tronco, no la copa
    return float(np.max(xs[bajos] * dx + ys[bajos] * dy))


def boca(var, anim, f, fila):
    """La boca: en la franja alta, el pixel mas adelantado hacia donde mira."""
    dx, dy = DIRS[fila]
    xs, ys, _a = medida(var, anim, f, fila)
    corte = ys.min() + (ys.max() - ys.min()) * 0.55
    alto = ys < corte
    v = xs[alto] * dx + ys[alto] * dy * 0.4
    i = int(np.argmax(v))
    return float(xs[alto][i]), float(ys[alto][i])


def pixeles_violeta(arr):
    a = arr.astype(int)
    return (a[:, :, 3] > 0) & (a[:, :, 2] > 120) & (a[:, :, 2] - a[:, :, 1] > 40) & (a[:, :, 0] > a[:, :, 1])


# --- EL BASICO (RAMALAZO): un ramalazo de madera que cae de arriba abajo, con astillas y hojas ---
def hojitas(a, x, y, e, sem, n=6, r=16.0):
    rnd = random.Random(sem)
    for _ in range(n):
        ang, d, fase = rnd.uniform(0, math.tau), rnd.uniform(0.4, 1.0) * r, rnd.random()
        k = min(1.0, e / 7.0)
        px = x + math.cos(ang) * d * k + math.sin(e * 0.8 + fase * 6) * 2
        py = y + math.sin(ang) * d * 0.6 * k + e * e * 0.12
        if e < 11:
            punto(a, px, py, HOJA[1], 3)
            punto(a, px, py, HOJA[2], 2)
            punto(a, px + 1, py, HOJA[3], 1)


def astillas(a, x, y, e, sem, n=5):
    rnd = random.Random(sem)
    for _ in range(n):
        ang, d = rnd.uniform(0, math.tau), rnd.uniform(8, 18)
        k = min(1.0, e / 5.0)
        if e < 7:
            px, py = x + math.cos(ang) * d * k, y + math.sin(ang) * d * 0.8 * k - math.sin(k * 3.14) * 8
            c, s_ = math.cos(ang + e), math.sin(ang + e)
            for j in range(-2, 3):
                punto(a, px + c * j, py + s_ * j, MADERA[2 if j else 3])


def basico(fila, var=NORMAL):
    dx, dy = DIRS[fila]
    al = alcance(var, fila)
    A = (W * 0.5 - dx * (al + 12) * 0.6, H * 0.68 - dy * (al + 12) * 0.5)
    V = (A[0] + dx * (al + 14), A[1] + dy * (al + 14) + 4)
    pecho = (V[0], V[1] - 10)
    m, t = [], []
    for f in range(15):
        s, a = nuevo(), nuevo()
        e = f - 4
        if 0 <= e < 5:
            # la media luna que CAE: el filo baja por delante del cuerpo
            coletazo(a, pecho[0], pecho[1] + 12, -math.pi / 2, 20.0, (-0.8 + 1.6 * (e + 1) / 5.0) * (1 if dx >= 0 else -1), 1.5, (1 if dx >= 0 else -1), 9.0, MADERA, MADERA_BORDE)
        if e in (2, 3):
            estrella(a, pecho[0], pecho[1], (10, 6)[e - 2], MADERA)
        if e >= 2:
            astillas(a, pecho[0], pecho[1], e - 2, 3 + fila)
            hojitas(a, pecho[0], pecho[1] - 6, e - 2, 5 + fila)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'basico', f, fila), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- EL RAMAZO: la rama que barre el cono dos veces, ida y vuelta, con hojas; a los que pilla, pegotes de savia escurriendo ---
def pegote(a, x, y, e, pal=SAVIA, borde=SAVIA_BORDE):
    if e < 0 or e > 12:
        return
    gota(a, x, y, 3.2, pal, borde)
    gota(a, x + 4, y + 3 + min(e, 6) * 0.8, 2.0, pal, borde)
    gota(a, x - 3, y + 4 + min(e, 8) * 1.1, 1.8, pal, borde)


def ramazo(fila, var=NORMAL):
    dx, dy = DIRS[fila]
    R = 55.0 / UNIDAD
    al = alcance(var, fila)
    A = (W * 0.5 - dx * (R + al) * 0.35, H * 0.68 - dy * (R + al) * 0.3)
    eje = math.atan2(dy, dx)
    mitad = math.radians(140) * 0.5
    r = max(R, al + 10)
    alto = 14
    vict = [(A[0] + math.cos(eje + k) * (r + 4), A[1] + math.sin(eje + k) * (r + 4) + 3) for k in (-0.6, 0.55)]
    m, t = [], []
    pasa = 6
    carga = 3
    for f in range(carga + pasa * 2 + 8):
        s, a = nuevo(), nuevo()
        e = f - carga
        g = e // pasa if e >= 0 else -1
        if f < carga + pasa:
            spr = marco(var, 'barrido_raiz', f, fila)
        else:
            spr = marco(var, 'barrido_vuelta', f - carga - pasa, fila)
        capa = a if dy >= -0.2 else s
        if g in (0, 1):
            sentido = 1.0 if g == 0 else -1.0
            u = (e % pasa + 1) / pasa
            frente = (-mitad + 2 * mitad * u) * sentido
            coletazo(capa, A[0], A[1] - alto, eje, r, frente, 2.8 * min(1.0, u * 1.6), sentido, 11.0, MADERA, MADERA_BORDE)
            px = A[0] + math.cos(eje + frente) * r
            py = A[1] - alto + math.sin(eje + frente) * r
            hojitas(a, px, py, e % pasa + 2, 11 + e, 3, 8.0)
        for i, v in enumerate(vict):
            pegote(a, v[0], v[1] - 11, e - 2 - i)
            victima(s, *v)
        m.append(escena([s], [(spr, var, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LAS RAICES ATENAZANTES: el suelo se agrieta y las raices ASOMAN y se vuelven a meter hasta que salen del todo y se
# enroscan en las piernas (ATADO) ---
def raiz(a, x, y, alto, sem, pal=MADERA, borde=MADERA_BORDE, g0=3.0):
    """Una raiz que sale del suelo: curvada, gorda abajo y afilada arriba, con luz a un lado."""
    if alto < 1:
        return
    n = int(alto)
    for j in range(n):
        u = j / max(alto, 1.0)
        cx = x + math.sin(u * 3.2 + sem) * 3.0 * u
        g = g0 * (1 - u) ** 0.7 + 0.4
        disco(a, cx, y - j, g + 0.7, borde)
    for j in range(n):
        u = j / max(alto, 1.0)
        cx = x + math.sin(u * 3.2 + sem) * 3.0 * u
        g = g0 * (1 - u) ** 0.7 + 0.4
        disco(a, cx, y - j, g, pal[1])
        punto(a, cx - g * 0.5, y - j, pal[2])


def grietas(s, x, y, largo, sem, n=6):
    rnd = random.Random(sem)
    for i in range(n):
        ang = i / n * math.tau + rnd.uniform(-0.3, 0.3)
        px, py = x + math.cos(ang) * 3, y + math.sin(ang) * 2
        pasos = int(largo * rnd.uniform(0.6, 1.0) / 2.5)
        for p in range(pasos):
            ang += rnd.uniform(-0.45, 0.45)
            px, py = px + math.cos(ang) * 2.5, py + math.sin(ang) * 2.0
            punto(s, px, py, (18, 14, 14), 2 if p < pasos * 0.6 else 1)


def raices(fila=1, var=NORMAL):
    dx, dy = DIRS[fila]
    al = alcance(var, fila)
    A = (W * 0.3, H * 0.62)
    C = (W * 0.68, H * 0.72)
    R = 30.0 / UNIDAD
    rnd = random.Random(9)
    brotes = [(C[0] + math.cos(i * 1.3) * R * 0.75, C[1] + math.sin(i * 1.3) * R * 0.5, rnd.uniform(0, 6), i) for i in range(6)]
    V = (C[0], C[1] - 1)
    m, t = [], []
    for f in range(28):
        s, a = nuevo(), nuevo()
        g = min(1.0, (f + 1) / 5.0)
        grietas(s, C[0], C[1], R * 1.1 * g, 4, 8)
        for x, y, sem, i in brotes:
            # asoman y se meten (dos amagos) y salen del todo
            e = f - 2 - i
            if e < 0:
                continue
            if e < 4:
                alto = (0, 5, 7, 3)[e]
            elif e < 7:
                alto = (0, 8, 4)[e - 4]
            else:
                alto = min(22, (e - 6) * 6)
            raiz(a if y >= V[1] else s, x, y, alto * seco(f, 22, 5), sem)
        # lo enroscado en las piernas
        if f >= 15:
            q = min(1.0, (f - 14) / 4.0) * seco(f, 22, 5)
            for k in range(3):
                yy = V[1] - 2 - k * 3
                for j in range(-5, 6):
                    punto(a, V[0] + j, yy + math.sin(j * 0.9 + k) * 1.0, MADERA[1] if j % 3 else MADERA[2], 2) if abs(j) < 6 * q else None
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'raices', f, fila), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- EL GOTERON (Savia corrosiva, Resina, Savia negra): vuela en parabola desde la boca y revienta al caer; lo que deja
# depende de cada uno: CHARCO que burbujea (savia), PEGOTE-CEPO en los pies (resina), HUMO y CHARCO (savia negra) ---
def goteron(fila, var, pal, borde, deja):
    dx, dy = DIRS[fila]
    dist = 100.0 / UNIDAD
    al = alcance(var, fila)
    A = (W * 0.5 - dx * (dist + al) * 0.48, H * 0.72 - dy * (dist + al) * 0.42)
    bx0, by0 = boca(var, 'escupir', 4, fila)
    B = (A[0] + bx0, A[1] + by0)
    V = (A[0] + dx * (dist + al), A[1] + dy * (dist + al) + 4)
    salpica = Gotas(10, 3 + fila, 5.0, 16.0, sube=(8.0, 16.0), tam=(1.3, 2.2), pal=pal, borde=borde)
    m, t = [], []
    sale, vuelo = 4, 6
    for f in range(sale + vuelo + 22):
        s, a = nuevo(), nuevo()
        e = f - sale
        if 0 <= e < vuelo:
            u = (e + 1) / vuelo
            x = B[0] + (V[0] - B[0]) * u
            y = B[1] + (V[1] - 8 - B[1]) * u - 22 * 4 * u * (1 - u)
            ua = max(0.0, u - 0.17)
            xa = B[0] + (V[0] - B[0]) * ua
            ya = B[1] + (V[1] - 8 - B[1]) * ua - 22 * 4 * ua * (1 - ua)
            n = math.hypot(x - xa, y - ya) or 1
            cometa_dir(a, x, y, (x - xa) / n, (y - ya) / n, min(n * 1.4, 14), 1, pal)
            gota(a, x, y, 5.0, pal, borde)
            sombra(s, A[0] + (V[0] - A[0]) * u, A[1] + (V[1] - A[1]) * u, 4.0)
        elif e >= vuelo:
            g = e - vuelo
            if g < 2:
                estrella(a, V[0], V[1] - 8, (12, 7)[g], pal)
            salpica.pintar(s, a, V[0], V[1] - 6, min(1.0, g / 4.0), 2.0, 1.0, 99)
            deja(s, a, V, g)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'escupir', f, fila), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def deja_charco(pal, borde, humo=False):
    def f(s, a, V, g):
        k = min(1.0, (g + 1) / 3.0)
        vivo = seco(g, 12, 7)
        charco(s, V[0], V[1] + 2, 12 * k, 3.0, vivo, pal, borde)
        rnd = random.Random(g // 3)
        if vivo > 0.3:   # burbujea
            for _ in range(2):
                bx, by = V[0] + rnd.uniform(-8, 8), V[1] + 2 + rnd.uniform(-4, 4)
                disco(s, bx, by, 1.6, borde)
                punto(s, bx - 1, by - 1, pal[3])
        if humo and g >= 2:
            for q in range(3):
                e = (g + q * 4) % 11
                vn.nube(a, V[0] + (q - 1) * 7, V[1] - 14 - e * 2, 3 + e * 0.6, (1 - e / 11.0) * 1.5 * vivo, HUMO_V)
    return f


def deja_cepo(s, a, V, g):
    """El pegote de ambar en los pies, como un cepo; al soltarle se agrieta y cae a trozos."""
    if g < 13:
        k = min(1.0, (g + 1) / 3.0)
        charco(s, V[0], V[1] + 1, 11 * k, 2.0, 1.0, AMBAR, AMBAR_BORDE)
        for j, ox in enumerate((-7, 7, 0)):
            gota(a, V[0] + ox, V[1] + (2 if j == 2 else 0), 3.8 * k, AMBAR, AMBAR_BORDE)
    else:
        e = g - 13
        grietas(s, V[0], V[1] + 1, 6 + e, 3, 5)
        for j in range(6):
            ang = j / 6 * math.tau
            if e < 7:
                gota(a, V[0] + math.cos(ang) * (5 + e * 2), V[1] + 1 + math.sin(ang) * (3 + e) + e * 0.4, 2.2 - e * 0.2, AMBAR, AMBAR_BORDE)


# --- LA COSTRA ROTA (ambarino): los grumos de ambar revientan hacia fuera y caen alrededor; se queda el tocon sin costra ---
def costra(fila=1, var=AMBARINO):
    A = (W * 0.5, H * 0.68)
    xs, ys, _a = medida(var, 'idle', 0, fila)
    top = ys.min()
    C = (A[0], A[1] + top + (ys.max() - top) * 0.3)
    rnd = random.Random(14)
    grumos = [(rnd.uniform(0, math.tau), rnd.uniform(28, 58), rnd.uniform(14, 30), rnd.uniform(2.2, 3.8)) for _ in range(18)]
    m, t = [], []
    for f in range(20):
        s, a = nuevo(), nuevo()
        if f < 2:
            spr, v = marco(var, 'encaje', f, fila), var
        else:
            spr, v = marco(SIN_COSTRA, 'encaje', min(f - 2, 3), fila) if f < 6 else marco(SIN_COSTRA, 'idle', f, fila), SIN_COSTRA
        e = f - 1
        if e >= 0:
            if e < 3:
                estrella(a, C[0], C[1], (20, 30, 16)[e], AMBAR)
            k = min(1.0, (e + 1) / 8.0)
            for ang, d, sube, r in grumos:
                x = C[0] + math.cos(ang) * d * k
                # caen hasta el suelo de alrededor de sus pies
                y0 = C[1] + (A[1] - C[1]) * k + math.sin(ang) * d * 0.45 * k
                y = y0 - sube * 4 * k * (1 - k)
                if k < 1.0:
                    gota(a, x, y, r, AMBAR, AMBAR_BORDE)
                else:
                    charco(s, x, y, r * 0.9, ang, seco(e, 12, 6), AMBAR, AMBAR_BORDE)
        m.append(escena([s], [(spr, v, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- EL GEISER (espantajo): carga (la grieta de SU dibujo late), sale el chorro por ella hacia arriba, forma una NUBE negra
# encima del area, y la nube LLUEVE gotas de savia que revientan en el circulo ---
def geiser(fila=2, var=ESPANTAJO):
    A = (W * 0.24, H * 0.82)
    C = (W * 0.72, H * 0.8)
    R = 45.0 / UNIDAD
    alto_nube = 96
    rnd = random.Random(5)
    bultos = [(rnd.uniform(-R * 0.9, R * 0.9), rnd.uniform(-6, 6), rnd.uniform(8, 13)) for _ in range(9)]
    lluvia = [(rnd.uniform(0, math.tau), rnd.uniform(0.1, 1.0), rnd.randrange(14)) for _ in range(20)]
    vict = [(C[0] - R * 0.5, C[1] + 2), (C[0] + R * 0.45, C[1] - R * 0.25)]
    m, t = [], []
    carga, chorro, nube_t = 8, 7, 16
    for f in range(carga + chorro + nube_t + 8):
        s, a = nuevo(), nuevo()
        if f < carga:
            spr = marco(var, 'geiser_carga', f, fila)
        else:
            spr = marco(var, 'geiser', f - carga, fila)
        arr = np.array(spr)
        vio = pixeles_violeta(arr)
        ox, oy = pies(var)
        if vio.any():
            ys_v, xs_v = np.nonzero(vio)
            G = (A[0] + xs_v.mean() - ox, A[1] + ys_v.min() - oy)
        else:
            G = (A[0], A[1] - 120)
        if f < carga:
            # la grieta late: se aclaran SUS pixeles
            late = f % 4 < 2
            if vio.any():
                arr[vio, :3] = NEGRA[3] if late else NEGRA[2]
                spr = Image.fromarray(arr, 'RGBA')
            if late:
                estrella(a, G[0], G[1] + 10, 7, NEGRA)
        e = f - carga
        if 0 <= e < chorro:
            # el chorro: sale de la grieta, SUBE en arco y baja hacia la nube. Primero todo el borde y luego el cuerpo: si no,
            # cada disco le pisa el relleno al anterior y sale un collar de cuentas.
            u = (e + 1) / chorro
            puntos = []
            for q in range(60):
                k = q / 60.0
                if k > u:
                    break
                x = G[0] + (C[0] - G[0]) * k
                y = G[1] + (C[1] - alto_nube - G[1]) * k - 46 * math.sin(k * math.pi) + math.sin(k * 14 - e) * 1.2
                puntos.append((x, y, 4.2 * (1 - k * 0.4)))
            for x, y, g in puntos:
                disco(a, x, y, g + 0.9, NEGRA_BORDE)
            for x, y, g in puntos:
                disco(a, x, y, g, NEGRA[1])
            for x, y, g in puntos:
                disco(a, x - 0.8, y - 0.8, g * 0.42, NEGRA[2])
        n0 = f - carga - 4
        if n0 >= 0:
            crece = min(1.0, (n0 + 1) / 6.0) * (1.0 if n0 < nube_t else max(0.0, 1 - (n0 - nube_t) / 8.0))
            if crece > 0.05:
                # UNA nube: los bultos se juntan (borde, cuerpo y luz por pasadas), no bolas sueltas
                for bx, by, r in bultos:
                    disco(a, C[0] + bx, C[1] - alto_nube + by, r * crece + 1, NEGRA_BORDE)
                for bx, by, r in bultos:
                    disco(a, C[0] + bx, C[1] - alto_nube + by, r * crece, NEGRA[0])
                for bx, by, r in bultos:
                    disco(a, C[0] + bx - r * 0.2, C[1] - alto_nube + by - r * 0.3, r * crece * 0.6, NEGRA[1])
                for bx, by, r in bultos[::2]:
                    punto(a, C[0] + bx - r * 0.4, C[1] - alto_nube + by - r * 0.6 * crece, NEGRA[2], 2)
            if crece > 0.2:
                d = ((XX - C[0]) / (R * crece)) ** 2 + ((YY - C[1]) / (R * crece * 0.7)) ** 2
                poner(s, (d <= 1.0) & (TRAMA < 0.45), ep.SOMBRA)
            ll = n0 - 5
            if ll >= 0:
                for ang, uu, t0 in lluvia:
                    g = ll - t0
                    px, py = C[0] + math.cos(ang) * R * uu, C[1] + math.sin(ang) * R * uu * 0.75
                    if 0 <= g < 5:
                        u = (g + 1) / 5.0
                        y = C[1] - alto_nube + (py - (C[1] - alto_nube)) * u
                        cometa_dir(a, px, y, 0, 1, 10, 1, NEGRA)
                        gota(a, px, y, 2.2, NEGRA, NEGRA_BORDE)
                    elif 5 <= g < 11:
                        charco(s, px, py, 3.6, ang, seco(g - 5, 3, 3), NEGRA, NEGRA_BORDE)
                        if g < 7:
                            estrella(a, px, py - 3, 4, NEGRA)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(spr, var, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- SECO Y HUMO (espantajo): cuanto mas seco, mas le laten las grietas violeta de SU dibujo; la Savia negra le saca humo
# violeta del cuerpo, mas denso cuantas mas cargas ---
def seco_humo(tramos, cargas, fila=1, var=ESPANTAJO):
    A = (W * 0.5, H * 0.82)
    rnd = random.Random(tramos * 7 + cargas)
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        spr = marco(var, 'idle', f, fila)
        arr = np.array(spr)
        ys, xs = np.nonzero(arr[:, :, 3] > 40)
        ox, oy = pies(var)
        late = (f % max(6 - tramos, 2)) < 2
        vio = pixeles_violeta(arr)
        if vio.any() and tramos > 0:
            arr[vio, :3] = NEGRA[3] if late else (NEGRA[2] if tramos > 1 else arr[vio, :3])
            # las grietas se extienden: lo de al lado tambien, con mas tramos
            if tramos >= 2 and late:
                dil = vio.copy()
                dil[1:] |= vio[:-1]
                dil[:-1] |= vio[1:]
                if tramos >= 3:
                    dil[:, 1:] |= vio[:, :-1]
                    dil[:, :-1] |= vio[:, 1:]
                dil &= arr[:, :, 3] > 0
                arr[dil, :3] = NEGRA[3]
        spr2 = Image.fromarray(arr, 'RGBA')
        for q in range(cargas):
            r2 = random.Random(q * 31)
            i = r2.randrange(len(xs))
            e = (f + q * 5) % 14
            vn.nube(a, A[0] + xs[i] - ox + e * 0.3, A[1] + ys[i] - oy - e * 2.0, 3 + e * 0.75, (1 - e / 14.0) * 1.5, HUMO_V)
        m.append(escena([s], [(spr2, var, A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


# --- CHUPAR (espantajo): le saca vida a un enraizado: HILOS violeta que reptan por el suelo hasta sus pies y BOLITAS de luz
# que suben por ellos ---
def chupar(fila=2, var=ESPANTAJO):
    dx, dy = DIRS[fila]
    al = alcance(var, fila)
    A = (W * 0.3, H * 0.8)
    V = (A[0] + al + 70, A[1] + 4)
    m, t = [], []
    for f in range(22):
        s, a = nuevo(), nuevo()
        u = min(1.0, (f + 1) / 6.0)
        vivo = seco(f, 15, 6)
        for k in range(3):
            lado = (k - 1) * 9
            for q in range(49):
                c = q / 48.0
                if (1 - c) > u:
                    continue
                x = A[0] + (V[0] - A[0]) * c
                y = A[1] + (V[1] - A[1]) * c + math.sin(c * 3.14) * lado + math.sin(c * 12 + f * 0.8 + k) * 1.5
                if TRAMA[int(y) % H, int(x) % W] < vivo * 1.15:
                    punto(s, x, y, HUMO_V[1], 2)
                    if q % 3 == 0:
                        punto(s, x, y, HUMO_V[2], 1)
            if f >= 5 and vivo > 0.4:
                for b in range(2):
                    c = 1 - (((f - 5) / 8.0 + b * 0.5 + k * 0.17) % 1.0)
                    x = A[0] + (V[0] - A[0]) * c
                    y = A[1] + (V[1] - A[1]) * c + math.sin(c * 3.14) * lado
                    disco(a, x, y, 2.4, HUMO_V[1])
                    disco(a, x, y, 1.5, HUMO_V[3])
        # el enraizado
        victima(s, *V)
        raiz(a, V[0] - 6, V[1] + 1, 12, 1)
        raiz(a, V[0] + 6, V[1] + 1, 10, 3)
        m.append(escena([s], [(marco(var, 'idle', f, fila), var, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- LOS BICHOS DE LA COSTRA ---
def bola(fila=2):
    dx, dy = DIRS[fila]
    A = (W * 0.25, H * 0.6)
    L = 110
    V = (A[0] + dx * L, A[1] + dy * L + 2)
    m, t = [], []
    corre = 10
    for f in range(corre + 14):
        s, a = nuevo(), nuevo()
        u = min(1.0, (f + 1) / corre)
        d = 14 + (L - 14) * u
        x, y = A[0] + dx * d, A[1] + dy * d
        for q in range(int(d / 5)):
            edad = f - (q * 5 / L) * corre
            if edad < 12 and TRAMA[int(A[1]) % H, (int(A[0]) + q * 5) % W] < 2:
                charco(s, A[0] + dx * (14 + q * 5), A[1] + dy * (14 + q * 5) + 3, 2.4, q, seco(edad, 6, 6), CACA, CACA[0])
        if u < 1:
            disco(a, x, y - 4, 7.8, CACA[0])
            disco(a, x, y - 4, 7, CACA[1])
            disco(a, x - 2, y - 6, 3.6, CACA[2])
            for k in range(3):   # las pajitas, que dan vueltas
                ang = f * 1.2 + k * 2.1
                for j in range(4, 9):
                    punto(a, x + math.cos(ang) * j, y - 4 + math.sin(ang) * j, (190, 160, 90))
        else:
            e = f - corre
            for k in range(7):
                ang = k / 7 * math.tau
                if e < 6:
                    gota(a, V[0] + math.cos(ang) * (3 + e * 2), V[1] - 10 + math.sin(ang) * (3 + e) + e * e * 0.3, 2.4, CACA, CACA[0])
            # EL PRINGADO: pegotes en el cuerpo que gotean y dos moscas
            if e >= 3:
                for ox, oy in ((-3, -14), (3, -9), (-2, -5)):
                    gota(a, V[0] + ox, V[1] + oy, 2.2, CACA, CACA[0])
                punto(a, V[0] + 3, V[1] - 4 + (e - 3) % 6, CACA[1], 2)
                for k in range(2):
                    ang = e * 0.9 + k * 3.1
                    punto(a, V[0] + math.cos(ang) * 10, V[1] - 20 + math.sin(ang * 1.7) * 3, (14, 12, 16), 2)
        victima(s, *V)
        m.append(escena([s], [(marco('pelotero_sdf', 'bola' if f < 6 else 'idle', f, fila), None, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def picor():
    V = (W * 0.5, H * 0.6)
    rnd = random.Random(3)
    ronchas = [(rnd.uniform(-5, 5), rnd.uniform(-17, -3), rnd.uniform(1.4, 2.2)) for _ in range(6)]
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        k = min(1.0, (f + 1) / 3.0)
        late = 0.35 if f % 4 < 2 else 0.0
        for ox, oy, r in ronchas:
            disco(a, V[0] + ox, V[1] + oy, (r + late) * k + 0.6, RONCHA[0])
            disco(a, V[0] + ox, V[1] + oy, (r + late) * k, RONCHA[1])
            punto(a, V[0] + ox - 1, V[1] + oy - 1, RONCHA[2])
        victima(s, *V)
        m.append(escena([s], [], [a]))
        t.append(1000 // 10)
    return m, t


def revienta():
    A = (W * 0.5, H * 0.6)
    rnd = random.Random(6)
    salp = Gotas(16, 7, 8.0, 26.0, sube=(10.0, 20.0), tam=(1.4, 2.4), pal=AMBAR, borde=(90, 26, 14))
    veneno = Gotas(8, 8, 10.0, 22.0, sube=(8.0, 16.0), tam=(1.2, 1.8), pal=SAVIA, borde=SAVIA_BORDE)
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        cuerpos = []
        if f < 4:
            cuerpos.append((marco('garrapata_h3_sdf', 'idle', f, 1), None, A[0], A[1], 0))
        else:
            e = f - 4
            if e < 2:
                estrella(a, A[0], A[1] - 6, (16, 10)[e], AMBAR)
            k = min(1.0, (e + 1) / 3.0)
            charco(s, A[0], A[1], 20 * k, 2.0, seco(e, 7, 6), [(96, 24, 14), (176, 60, 24), (226, 120, 40), (255, 210, 130)], (50, 12, 8))
            salp.pintar(s, a, A[0], A[1] - 4, min(1.0, e / 6.0), 3.0, 1.0, 99)
            veneno.pintar(s, a, A[0], A[1] - 4, min(1.0, e / 6.0), 3.0, 1.0, 99)
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 12)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: basico(d) for d in (1, 2, 4)}
    ra = {d: ramazo(d) for d in (1, 2, 4)}
    rc = raices()
    sv = {d: goteron(d, NORMAL, SAVIA, SAVIA_BORDE, deja_charco(SAVIA, SAVIA_BORDE)) for d in (1, 4)}
    re = {d: goteron(d, AMBARINO, AMBAR, AMBAR_BORDE, deja_cepo) for d in (1, 2)}
    co = costra()
    sn = {d: goteron(d, ESPANTAJO, NEGRA, NEGRA_BORDE, deja_charco(NEGRA, NEGRA_BORDE, True)) for d in (2, 4)}
    ge = geiser()
    sh = {n: seco_humo(n, n * 2 - 1 if n else 0) for n in (1, 3)}
    ch = chupar()
    bo = bola()
    pi = picor()
    rv = revienta()
    filas = [
        *[('TRENT\nbasico (ramalazo)\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (3, 5, 6, 7, 9, 12))) for d in (1, 2, 4)],
        *[('TRENT y mutantes\nRamazo (ida y vuelta)\nhacia el ' + NOM_DIR[d], elegir(ra[d][0], (3, 5, 7, 10, 13, 18))) for d in (1, 2, 4)],
        ('TRENT y mutantes\nRaices atenazantes', elegir(rc[0], (3, 7, 11, 15, 20, 26))),
        *[('TRENT\nSavia corrosiva\nhacia el ' + NOM_DIR[d], elegir(sv[d][0], (5, 8, 10, 12, 19, 28))) for d in (1, 4)],
        *[('TOCON AMBARINO\nResina (el cepo)\nhacia el ' + NOM_DIR[d], elegir(re[d][0], (5, 8, 10, 14, 24, 28))) for d in (1, 2)],
        ('TOCON AMBARINO\nse le rompe la costra', elegir(co[0], (0, 2, 4, 7, 10, 17))),
        *[('ESPANTAJO\nSavia negra\nhacia el ' + NOM_DIR[d], elegir(sn[d][0], (5, 8, 10, 13, 20, 28))) for d in (2, 4)],
        ('ESPANTAJO\nGeiser\ncarga, chorro, nube, lluvia', elegir(ge[0], (3, 10, 14, 19, 25, 32))),
        ('ESPANTAJO\nSeco 1 tramo\ny 1 carga de humo', elegir(sh[1][0], (0, 2, 4, 7, 10, 13))),
        ('ESPANTAJO\nSeco 3 tramos\ny 5 cargas de humo', elegir(sh[3][0], (0, 2, 4, 7, 10, 13))),
        ('ESPANTAJO\nChupar al enraizado', elegir(ch[0], (2, 5, 8, 11, 15, 20))),
        ('PELOTERO\nBola de caca\ny el Pringado', elegir(bo[0], (2, 6, 9, 12, 15, 21))),
        ('MOSQUITO\nel Picor', elegir(pi[0], (0, 1, 2, 3, 5, 7))),
        ('GARRAPATA\nrevienta al morir', elegir(rv[0], (2, 4, 5, 7, 10, 15))),
    ]
    lamina(filas, os.path.join(SALIDA, 'trent.png'), 2)
    todos, tiempos = [], []
    for marcos, ts in [ba[1], ra[1], rc, sv[1], re[1], co, sn[2], ge, sh[3], ch, bo, pi, rv]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'trent.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
