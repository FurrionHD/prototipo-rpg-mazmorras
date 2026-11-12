#!/usr/bin/env python3
# ============================================================
#  polilla_efectos_pixel.py -- LOS EFECTOS DE LA POLILLA Y SUS MUTANTES EN PIXEL ART (12/11/2026, memorias
#  efectos-a-pixel-art y polilla-mutante). La receta de la del miconido (miconido_efectos_pixel.py): misma rejilla que
#  los sprites, paleta de 4 tonos, lo que se va a TRAMA y sin rejilla (transparencia de verdad), sobre sus sprites.
#  LA NORMAL (pavon y Polilla de luto, mismo kit), POLVO DE ALAS lila palido con motas que brillan (los de SimaAire del 30/09):
#    ROCE        el basico: media luna blanda y polvorienta que barre la cara, motas brillando al caer
#    ALETEO      tres bocanadas de polvo en la cara, una por batido; y el velo de la Ceguera
#    NUBE        el anillo gordo de polvo que sale de ella y se abre por todo el circulo; a cada uno, polvo en la cara
#    PASIVA      pegarle de cerca: el polvo te salta a la cara
#  VIGILIA DORADA (Luz, oro): ROCE de luz, POLVO DORADO (la nube en oro), DESTELLO DE ESCAMAS (cono) y LLUVIA DE ESCAMAS
#    (le caen escamas de luz en el circulo donde apunta)
#  MORTAJA ALADA (Oscuridad, ceniza): ROCE de sombra, NUBE DE CENIZA, ALETEO SOMBRIO (cono oscuro, Miedo) y AMORTAJARSE
#    (el humo la envuelve de abajo arriba)
#  POLILLA INSOMNE (rojo): OJO QUE SE ABRE (carga: motas rojas a sus ojos; estallido: un anillo de luz roja por todo su
#    circulo), PARPADO NEGRO (cono negro con brasas rojas, Miedo), INSOMNIO (motas rojas que tiran de los de cerca) y
#    MIRADA QUE DEVUELVE (le pegan un hechizo de frente: destello en sus ojos y el hechizo vuelve a quien lo lanzo)
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/polilla_efectos_pixel.py [--solo-normal]
# ============================================================
import math
import os
import random
import sys

import numpy as np

import ciempies_efectos_pixel as ce
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import miconido_efectos_pixel as mi

W, H = 330, 280
YY, XX = np.mgrid[0:H, 0:W]
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
for _m in (ce, ep, sl, rt, mi):
    _m.W, _m.H, _m.YY, _m.XX, _m.TRAMA = W, H, YY, XX, TRAMA

from slime_efectos_pixel import UNIDAD, SALIDA, nuevo, estrella, elegir, DIRS, NOM_DIR  # noqa: E402
from rata_efectos_pixel import marco, escena  # noqa: E402

poner, punto, bolita = ep.poner, ep.punto, ep.bolita
nube, motas, tos, velo, abanico, cabeza, caja_dibujo, pies, _dir = (mi.nube, mi.motas, mi.tos, mi.velo, mi.abanico,
                                                                    mi.cabeza, mi.caja_dibujo, mi.pies, mi._dir)

NORMAL, LUTO = 'polilla_sdf_a', 'polilla_sdf_d'
VIGILIA, MORTAJA, INSOMNE = 'polilla_sdf_vigilia', 'polilla_sdf_mortaja', 'polilla_sdf_insomne'

POLVO = [(84, 74, 96), (146, 134, 160), (204, 194, 216), (244, 240, 250)]
ORO = [(96, 66, 20), (176, 128, 48), (232, 190, 96), (255, 240, 190)]
CENIZA = [(30, 28, 34), (70, 68, 76), (130, 128, 136), (226, 226, 232)]
ROJO = [(64, 6, 10), (150, 20, 22), (234, 64, 40), (255, 196, 150)]
NEGRO = [(8, 6, 10), (26, 18, 28), (60, 26, 34), (200, 40, 34)]
# El humo de Amortajarse: mas OSCURO que la Mortaja (que ya es gris), con el filo claro para que se lea encima de ella.
SUDARIO = [(10, 8, 12), (34, 30, 38), (90, 86, 96), (200, 198, 206)]
MIEDO = [(30, 12, 44), (70, 34, 96), (130, 80, 170), (210, 180, 240)]


def centro(spr, pos):
    """El centro de su dibujo (va volando: lo que importa es el cuerpo, no los pies)."""
    x0, y0, x1, y1 = caja_dibujo(spr, pos)
    return (x0 + x1) / 2, (y0 + y1) / 2


def frente(spr, pos, dx, dy, k=0.45):
    """El borde de su dibujo hacia donde mira (de ahi sale lo que suelta)."""
    x0, y0, x1, y1 = caja_dibujo(spr, pos)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    return cx + dx * (x1 - x0) * k, cy + dy * (y1 - y0) * k


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
def media_luna(a, hx, hy, e, lado, pal):
    """EL ROCE: una media luna ancha y blanda que barre la cara de un lado al otro (poco filo, mucho polvo)."""
    if e < 0 or e > 4:
        return
    barre = min(1.0, (e + 1) / 2.0)
    fuerza = 1.0 - max(0.0, e - 1) / 3.5
    n = 9
    for i in range(n):
        u = i / (n - 1)
        if u > barre:
            break
        ang = math.radians(-150 + 120 * u) if lado > 0 else math.radians(-30 - 120 * u)
        r = 9.0
        x, y = hx + math.cos(ang) * r, hy + 2 + math.sin(ang) * r * 0.7
        grueso = 2.6 * math.sin(math.pi * (0.15 + 0.7 * u))
        if TRAMA[int(y) % H, int(x) % W] > fuerza * 1.2:
            continue
        bolita(a, x, y, max(1.2, grueso), pal)


def anillo(a, cx, cy, R, e, pal, dura=10):
    """EL ANILLO del suelo (la Nube): un anillo GORDO de polvo que sale de ella y se abre por todo el circulo."""
    if e < 0 or e > dura:
        return
    k = min(1.0, (e + 1) / 5.0)
    r = R * k
    gordo = 5.0
    fuerza = 1.0 if e < 5 else max(0.0, 1.0 - (e - 5) / (dura - 4))
    d = np.hypot(XX - cx, (YY - cy) * 2.0)
    banda = np.abs(d - r) < gordo
    poner(a, banda & (TRAMA < 0.55 * fuerza), pal[1])
    poner(a, (np.abs(d - r) < gordo * 0.45) & (TRAMA < 0.6 * fuerza), pal[2])
    poner(a, (d < r - gordo) & (TRAMA < 0.12 * fuerza), pal[0])
    rnd = random.Random(int(R))
    for j in range(10):
        ang = j / 10 * math.tau + rnd.uniform(-0.2, 0.2)
        px, py = cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.5 - rnd.uniform(0, 4)
        if (j + e) % 3 == 0 and fuerza > 0.3:
            estrella(a, px, py, 3, pal)


def bocanada(a, desde, hasta, e, pal, brillan=True):
    """Una bocanada que vuela de 'desde' a la cara y alli se abre."""
    if e < 0 or e > 8:
        return
    k = min(1.0, e / 2.5)
    x, y = desde[0] + (hasta[0] - desde[0]) * k, desde[1] + (hasta[1] - desde[1]) * k
    nube(a, x, y, 4 + min(e, 4) * 2.2, max(0.0, 1.0 - e / 8.5), pal)
    motas(a, x, y, e, int(desde[0] + e), pal, 3, 0.8, 5, brillan)


def escamas_caen(a, cx, cy, R, e, pal, sem):
    """LA LLUVIA DE ESCAMAS: escamas de luz que caen del cielo dentro del circulo y destellan al tocar el suelo."""
    rnd = random.Random(sem)
    for j in range(14):
        ox, oy = rnd.uniform(-R, R), rnd.uniform(-R, R) * 0.5
        if (ox / R) ** 2 + (oy / (R * 0.5)) ** 2 > 1.0:
            continue
        t0 = rnd.uniform(0, 4)
        k = e - t0
        if k < 0 or k > 6:
            continue
        caida = max(0.0, 26 - k * 9)
        x, y = cx + ox, cy + oy - caida
        if caida > 0:
            bolita(a, x, y, 1.6, pal)
            punto(a, x, y - 3, pal[1], 2)
        elif k < 5:
            estrella(a, x, y, 4 if k < 4 else 3, pal)


def humo_sube(a, cx, cy, alto, e, pal, sem):
    """AMORTAJARSE: humo que la envuelve de abajo arriba, en espiral, y se queda a trama."""
    rnd = random.Random(sem)
    sube = min(1.0, (e + 1) / 6.0)
    for j in range(12):
        u = j / 12
        if u > sube:
            break
        ang = u * math.tau * 1.6 + e * 0.5
        r = 20 * (1.0 - 0.4 * u)
        x, y = cx + math.cos(ang) * r, cy + alto * 0.5 - alto * u + math.sin(ang) * r * 0.35
        nube(a, x, y, 5.5 + rnd.uniform(0, 2.0), 1.0 if e < 8 else max(0.0, 1.0 - (e - 8) / 6.0), pal)


def motas_hacia(a, desde, hasta, f, pal, n=3, sem=0):
    for i in range(n):
        u = ((f + i * 1.3 + sem) % 4) / 4.0
        punto(a, desde[0] + (hasta[0] - desde[0]) * u, desde[1] + (hasta[1] - desde[1]) * u,
              pal[2] if u > 0.5 else pal[1], 2)


def miedo(a, v, e):
    """Miedo: jirones morados que suben de la cabeza y tiemblan."""
    if e < 0 or e > 8:
        return
    hx, hy = cabeza(v)
    for j in range(3):
        k = e - j * 0.6
        if k < 0:
            continue
        x = hx + (j - 1) * 5 + math.sin(k * 2 + j) * 1.5
        bolita(a, x, hy - 6 - k * 1.6, 1.4, MIEDO)


# ------------------------------------------------------------
#  ESCENAS (comunes a las cuatro, cada una con su paleta)
# ------------------------------------------------------------
def _yo_y_victima(var, fila, dist):
    dx, dy = _dir(fila)
    A = (W * 0.42 - dx * dist * 0.5, H * 0.5 - dy * dist * 0.4)
    px, py = pies(var, A, fila)
    return A, (px + dx * dist, py + dy * dist + 2), dx, dy


def roce(fila, var, pal):
    A, V, dx, dy = _yo_y_victima(var, fila, 34)
    n, toca = 8, 4
    m, t = [], []
    for f in range(n + 6):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        ep.victima(s, *V)
        hx, hy = cabeza(V)
        e = f - toca
        media_luna(a, hx, hy, e, 1 if dx >= 0 else -1, pal)
        if e >= 0:
            motas(a, hx, hy, e, fila + 3, pal, 5, -0.6, 8, True)   # caen brillando
        m.append(escena([s], [(marco(var, 'embestida', fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def aleteo(fila, var, pal):
    """El ALETEO de la normal: tres bocanadas, una por batido, y la Ceguera."""
    A, V, dx, dy = _yo_y_victima(var, fila, 46)
    n = 8
    m, t = [], []
    for f in range(n + 8):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        spr = marco(var, 'aletear', fr, fila)
        ep.victima(s, *V)
        boca = frente(marco(var, 'aletear', 0, fila), A, dx, dy)
        for b, sale in enumerate((1, 3, 5)):
            bocanada(a, boca, cabeza(V), f - sale, pal)
        velo(a, V, f - 7)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def cono(fila, var, pal, ciega=True, asusta=False):
    """Los CONOS de las mutantes (Destello de escamas, Aleteo sombrio, Parpado negro): el abanico con su paleta."""
    dx, dy = _dir(fila)
    R = 60.0 / UNIDAD
    A = (W * 0.42 - dx * R * 0.5, H * 0.52 - dy * R * 0.45)
    eje = math.atan2(dy, dx)
    vict = [(A[0] + math.cos(eje - 0.25) * R * 0.75, A[1] + math.sin(eje - 0.25) * R * 0.75 + 24),
            (A[0] + math.cos(eje + 0.3) * R * 0.5, A[1] + math.sin(eje + 0.3) * R * 0.5 + 24)]
    n, sale = 8, 2
    m, t = [], []
    for f in range(n + 9):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        spr = marco(var, 'aletear', fr, fila)
        for v in vict:
            ep.victima(s, *v)
        e = f - sale
        if e >= 0:
            o = frente(marco(var, 'aletear', 0, fila), A, dx, dy, 0.3)
            abanico(a if dy > -0.2 else s, o[0], o[1], eje, R, 70.0, e, pal)
            motas(a, o[0] + dx * R * 0.5, o[1] + dy * R * 0.5, e, fila + 9, ROJO if pal is NEGRO else pal, 8 if pal is NEGRO else 6,
                  0.5, R * 0.35, True)   # el Parpado negro lleva BRASAS rojas: negro sobre el suelo oscuro no se leia
            for v in vict:
                if ciega:
                    velo(a, v, e - 2)
                if asusta:
                    miedo(a, v, e - 2)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 13)
    return m, t


def nube_suelo(var, pal):
    """La NUBE (y el Polvo dorado y la Nube de ceniza): el anillo que se abre por su circulo y polvo en cada cara."""
    R = 60.0 / UNIDAD
    A = (W * 0.5, H * 0.45)
    px, py = pies(var, A, 1)
    vict = [(px - R * 0.55, py + 6), (px + R * 0.6, py + 2), (px + 10, py + R * 0.35)]
    n, sale = 8, 4
    m, t = [], []
    for f in range(n + 12):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        for v in vict:
            ep.victima(s, *v)
        e = f - sale
        anillo(s, px, py, R, e, pal)
        for j, v in enumerate(vict):
            tos(a, v, e - 2, j, pal, True)
        m.append(escena([s], [(marco(var, 'nube', fr, 1), A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def pasiva(var, pal):
    """Le pegan de cerca: el polvo le salta a la cara al que pega."""
    A = (W * 0.52, H * 0.48)
    px, py = pies(var, A, 1)
    V = (px - 62, py + 6)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        ep.victima(s, *V)
        spr = marco(var, 'encaje', min(f, 3), 1)
        c = centro(spr, A)
        bocanada(a, c, cabeza(V), f - 1, pal)
        velo(a, V, f - 4)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def lluvia():
    R = 40.0 / UNIDAD
    A = (W * 0.3, H * 0.42)
    C = (W * 0.66, H * 0.66)
    vict = [(C[0] - R * 0.4, C[1] + 2), (C[0] + R * 0.45, C[1] - 4)]
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        spr = marco(VIGILIA, 'nube', min(f, 7), 1)
        e = f - 3
        if e >= 0:
            d = np.hypot(XX - C[0], (YY - C[1]) * 2.0)
            fuerza = 1.0 if e < 8 else max(0.0, 1.0 - (e - 8) / 6.0)
            poner(s, (np.abs(d - R) < 2.2) & (TRAMA < 0.6 * fuerza), ORO[1])
            escamas_caen(a, C[0], C[1], R, e, ORO, 7)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def amortajarse():
    A = (W * 0.5, H * 0.48)
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        spr = marco(MORTAJA, 'nube', min(f, 7), 1)
        cx, cy = centro(spr, A)
        humo_sube(a, cx, cy + 6, 46, f, SUDARIO, 3)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def ojo_que_se_abre():
    R = 70.0 / UNIDAD
    A = (W * 0.5, H * 0.42)
    px, py = pies(INSOMNE, A, 1)
    vict = [(px - R * 0.6, py + 4), (px + R * 0.55, py + 8), (px - 6, py + R * 0.4)]
    rnd = random.Random(5)
    llegan = [(rnd.uniform(0, math.tau), rnd.uniform(20, 34)) for _ in range(10)]
    carga = 8
    m, t = [], []
    for f in range(carga + 12):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        if f < carga:
            spr = marco(INSOMNE, 'ojo_carga', f, 1)
            c = centro(spr, A)
            for j, (ang, d0) in enumerate(llegan):
                k = ((f + j * 0.6) % 4) / 4.0
                d = d0 * (1.0 - k)
                punto(a, c[0] + math.cos(ang) * d, c[1] + math.sin(ang) * d * 0.7, ROJO[2] if k > 0.5 else ROJO[1], 2)
        else:
            e = f - carga
            spr = marco(INSOMNE, 'ojo', min(e, 7), 1)
            c = centro(spr, A)
            if e < 2:
                estrella(a, c[0], c[1], (18, 12)[e], ROJO)
            anillo(s, px, py, R, e, ROJO, 11)
            for v in vict:
                velo(a, v, e - 3)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def insomnio():
    A = (W * 0.48, H * 0.46)
    px, py = pies(INSOMNE, A, 1)
    vict0 = [(px - 48, py + 12), (px + 46, py + 16), (px + 4, py + 44)]
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        spr = marco(INSOMNE, 'idle', f, 1)
        c = centro(spr, A)
        k = min(1.0, max(0.0, (f - 3) / 4.0))
        for j, v0 in enumerate(vict0):
            vx, vy = v0[0] - px, v0[1] - py
            d = math.hypot(vx, vy) or 1.0
            v = (v0[0] - vx / d * 15 / UNIDAD * k, v0[1] - vy / d * 15 / UNIDAD * k)
            ep.victima(s, *v)
            if 1 <= f < 10:
                motas_hacia(a, cabeza(v), c, f, ROJO, 3, j)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def mirada():
    """Le lanzan un hechizo de frente: destello en sus ojos y el hechizo vuelve (una bola roja) a quien lo lanzo."""
    A = (W * 0.62, H * 0.44)
    px, py = pies(INSOMNE, A, 1)
    Y = (px - 90, py + 30)   # quien lanza
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        ep.victima(s, *Y)
        spr = marco(INSOMNE, 'idle', f, 1)
        c = centro(spr, A)
        mano = cabeza(Y)
        if f < 5:     # el hechizo que llega (lila, el de quien lo lanza)
            u = f / 5.0
            bolita(a, mano[0] + (c[0] - mano[0]) * u, mano[1] + (c[1] - mano[1]) * u, 4.5, POLVO)
        elif f < 7:
            estrella(a, c[0], c[1], (14, 9)[f - 5], ROJO)
        if 6 <= f < 12:   # lo que devuelve: mas pequeño y ROJO
            u = (f - 6) / 5.0
            x, y = c[0] + (mano[0] - c[0]) * u, c[1] + (mano[1] - c[1]) * u
            bolita(a, x, y, 3.8, ROJO)
            for k in (1, 2):   # su cola
                bolita(a, x - (mano[0] - c[0]) * 0.06 * k, y - (mano[1] - c[1]) * 0.06 * k, 2.6 - k * 0.7, ROJO)
        if f == 11:
            estrella(a, mano[0], mano[1], 8, ROJO)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def _sin_rejilla(fn):
    import transparencia as tr

    def envuelto(*a, **k):
        return tr.con_alfa(fn, [ce, ep, sl, rt, mi, sys.modules[__name__]], *a, **k)
    return envuelto


def principal(solo_normal=False):
    global roce, aleteo, cono, nube_suelo, pasiva, lluvia, amortajarse, ojo_que_se_abre, insomnio, mirada
    if os.environ.get('CON_REJILLA') != '1':
        roce, aleteo, cono, nube_suelo, pasiva = map(_sin_rejilla, (roce, aleteo, cono, nube_suelo, pasiva))
        lluvia, amortajarse, ojo_que_se_abre, insomnio, mirada = map(
            _sin_rejilla, (lluvia, amortajarse, ojo_que_se_abre, insomnio, mirada))
    os.makedirs(SALIDA, exist_ok=True)
    filas, gifs = [], []

    def fila(nombre, mt, idx):
        filas.append((nombre, elegir(mt[0], idx)))
        gifs.append(mt)

    for d in (1, 4):
        fila('NORMAL roce de ala\nhacia el ' + NOM_DIR[d], roce(d, NORMAL, POLVO), (2, 4, 5, 6, 7, 8, 10))
    for d in (1, 2):
        fila('NORMAL Aleteo cegador\nhacia el ' + NOM_DIR[d], aleteo(d, NORMAL, POLVO), (1, 2, 4, 6, 8, 10, 13))
    fila('NORMAL Nube de esporas', nube_suelo(NORMAL, POLVO), (3, 5, 7, 9, 11, 14, 18))
    fila('NORMAL polvo al\npegarle de cerca', pasiva(NORMAL, POLVO), (0, 1, 2, 3, 5, 7, 10))
    fila('LUTO (mismo kit)\nroce de ala', roce(1, LUTO, POLVO), (2, 4, 5, 6, 7, 8, 10))
    if not solo_normal:
        for d in (1, 4):
            fila('VIGILIA roce de luz\nhacia el ' + NOM_DIR[d], roce(d, VIGILIA, ORO), (2, 4, 5, 6, 7, 8, 10))
        fila('VIGILIA Polvo dorado', nube_suelo(VIGILIA, ORO), (3, 5, 7, 9, 11, 14, 18))
        for d in (1, 2):
            fila('VIGILIA Destello de\nescamas hacia el ' + NOM_DIR[d], cono(d, VIGILIA, ORO), (2, 3, 5, 7, 9, 12, 15))
        fila('VIGILIA Lluvia\nde escamas', lluvia(), (3, 5, 7, 9, 11, 13, 16))
        for d in (1, 4):
            fila('MORTAJA roce de\nsombra hacia el ' + NOM_DIR[d], roce(d, MORTAJA, CENIZA), (2, 4, 5, 6, 7, 8, 10))
        fila('MORTAJA Nube\nde ceniza', nube_suelo(MORTAJA, CENIZA), (3, 5, 7, 9, 11, 14, 18))
        for d in (1, 2):
            fila('MORTAJA Aleteo sombrio\nhacia el ' + NOM_DIR[d], cono(d, MORTAJA, CENIZA, False, True),
                 (2, 3, 5, 7, 9, 12, 15))
        fila('MORTAJA Amortajarse', amortajarse(), (0, 2, 4, 6, 8, 11, 14))
        fila('INSOMNE Ojo que\nse abre', ojo_que_se_abre(), (1, 4, 7, 8, 9, 12, 16))
        for d in (1, 2):
            fila('INSOMNE Parpado negro\nhacia el ' + NOM_DIR[d], cono(d, INSOMNE, NEGRO, False, True),
                 (2, 3, 5, 7, 9, 12, 15))
        fila('INSOMNE Insomnio', insomnio(), (0, 2, 4, 6, 8, 10, 13))
        fila('INSOMNE Mirada\nque devuelve', mirada(), (1, 3, 5, 6, 8, 10, 12))
    nombre = 'polilla' + ('_normal' if solo_normal else '')
    ce.lamina(filas, os.path.join(SALIDA, nombre + '.png'), 3)
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, nombre + '.gif'), 2)
    print('hecho en', SALIDA, nombre)


if __name__ == '__main__':
    principal('--solo-normal' in sys.argv)
