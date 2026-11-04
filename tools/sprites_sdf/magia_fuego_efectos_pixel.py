#!/usr/bin/env python3
# ============================================================
#  magia_fuego_efectos_pixel.py -- LAS MAGIAS DE FUEGO EN PIXEL ART (04/11/2026, memoria efectos-pixel-personajes).
#  Las mismas que hoy pinta MagiaAire / MagiaMayor, pasadas a la receta de los efectos en pixel (rejilla de los sprites,
#  paleta cerrada, sin alfa a medias, lo que se va a trama de 2 celdas), con las piezas de fuego ya aprobadas del slime de
#  fuego (llama = silueta que cambia cada fotograma, lengua, humo a trama, estrella maciza):
#    Brasa (aliento en cono) · Andanada ignea (bolas que caen) · Mar de brasas (el suelo se raja en lava) ·
#    Shock termico fulminante (fuego + gota de agua: vapor y roca negra) · Filo ardiente · Manto de brasas.
#  Sobre el PERSONAJE DE VERDAD: tools/sacar_jugador_png.tscn -- lanzar varita (la floritura, 1 pixel = 1 celda).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/magia_fuego_efectos_pixel.py
# ============================================================
import json
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO: el Mar de brasas mide 130 celdas de largo.
W, H = 300, 240
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import slime_veneno_efectos_pixel as vn  # noqa: E402
import slime_fuego_efectos_pixel as sf  # noqa: E402
from slime_efectos_pixel import UNIDAD, nuevo, poner, punto, disco, estrella, charco, seco, DIRS, NOM_DIR  # noqa: E402
from slime_fuego_efectos_pixel import FUEGO, LAVA, HUMO, CHAMUSCADO, OBSIDIANA, llama, lengua, chispas  # noqa: E402

for m in (vn, sf):
    m.XX, m.YY, m.TRAMA, m.W, m.H = XX, YY, TRAMA, W, H

SALIDA = os.path.join(ep.SALIDA, 'personajes')
JUG = os.path.join(ep.RAIZ, 'tools', 'salida', 'jugador_png', 'lanzar_varita')
SUELTA = 6                 # el fotograma de la floritura en que la varita suelta el hechizo
ALTO_MANO = 12.0 / UNIDAD  # (celdas) a que altura sale lo que lanzas
ALTO_PECHO = 13.0 / UNIDAD
AGUA = [(20, 60, 120), (52, 130, 220), (150, 210, 255), (240, 250, 255)]
VAPOR = [(120, 124, 132), (168, 172, 180), (214, 218, 224), (246, 248, 250)]
ROCA = [(26, 20, 22), (48, 36, 34), (74, 56, 50), (104, 80, 68)]
PUAS = [(30, 18, 44), (70, 40, 104), (140, 96, 196), (226, 206, 255)]

# --- EL PERSONAJE ---
with open(JUG + '.json', encoding='utf-8') as fh:
    _J = json.load(fh)
_JIMG = Image.open(JUG + '.png').convert('RGBA')
LW, LH = _J['lienzo']
PX, PY = _J['pies']


def jugador(f, fila):
    n = _J['marcos']
    f = max(0, min(f, n - 1))
    return _JIMG.crop((f * LW, fila * LH, f * LW + LW, fila * LH + LH))


def mano(A, dx, dy):
    """De donde sale lo que lanza: delante del cuerpo, a la altura de la mano."""
    return A[0] + dx * 5.0, A[1] + dy * 3.0 - ALTO_MANO


# --- LA ESCENA: suelo, lo de aire que queda DETRAS de los cuerpos, los cuerpos (por su y) y el aire de delante ---
def escena(suelo, detras, cuerpos, aire):
    img = ep.fondo()
    for c in suelo:
        sl.volcar(img, c, True)
    for c in detras:
        img.alpha_composite(Image.fromarray(c, 'RGBA'))
    for spr, x, y in sorted(cuerpos, key=lambda c: c[2]):
        if spr is None:
            v = nuevo()
            ep.victima(v, x, y)
            img.alpha_composite(Image.fromarray(v, 'RGBA'))
        else:
            img.paste(spr, (int(round(x)) - PX, int(round(y)) - PY), spr)
    for c in aire:
        sl.volcar(img, c, False)
    sl._PEND.clear()
    return img


def capas():
    return nuevo(), nuevo(), nuevo()   # suelo, detras, aire


def segun_y(y, ref, detras, aire):
    return detras if y < ref else aire


# Un anillo RELLENO (banda de varias celdas que se oscurece hacia dentro), nunca un aro fino.
def anillo(a, cx, cy, r, grueso, pal, fuerza=1.0, achata=1.0):
    if r < 1.0 or fuerza <= 0.0:
        return
    d = np.hypot(XX - cx, (YY - cy) / achata)
    dentro = (d <= r) & (d > r - grueso)
    rel = (r - d) / max(grueso, 0.01)
    q = TRAMA < fuerza * 1.1
    poner(a, dentro & q, pal[0])
    poner(a, dentro & (rel < 0.66) & q, pal[1])
    poner(a, dentro & (rel < 0.33) & q, pal[2])


# Una bola de fuego: corazon claro, cuerpo naranja y borde rojo oscuro, con el borde que tiembla.
def bola(a, x, y, r, f, pal=FUEGO):
    if r < 1.0:
        return
    d = np.hypot(XX - x, YY - y)
    ang = np.arctan2(YY - y, XX - x)
    rr = r * (1.0 + 0.12 * np.sin(ang * 5 + f * 1.7))
    poner(a, d < rr, pal[0])
    poner(a, d < rr * 0.78, pal[1])
    d2 = np.hypot(XX - (x - r * 0.2), YY - (y - r * 0.25))
    poner(a, d2 < rr * 0.5, pal[2])
    poner(a, d2 < rr * 0.28, pal[3])


# La cola de lo que vuela: celdas de 2 que se oscurecen y se deshacen detras de la cabeza.
def estela(a, pts, pal=FUEGO, grueso=2):
    n = len(pts)
    for i, (x, y) in enumerate(pts):
        u = i / max(n - 1, 1)          # 0 = cola, 1 = cabeza
        if u < 0.35 and (int(x) // 2 + int(y) // 2) % 2:
            continue
        col = pal[0] if u < 0.35 else pal[1] if u < 0.7 else pal[2]
        punto(a, x - grueso // 2, y - grueso // 2, col, grueso if u > 0.3 else 1 + (grueso > 2))


# El vapor: bulto macizo de tres tonos (luz arriba) y solo el borde se deshace a trama, como la ceniza del slime de fuego.
def vapor_bulto(a, x, y, r, fuerza):
    if r < 1.0 or fuerza <= 0.0:
        return
    d = np.hypot(XX - x, YY - y)
    rr = r * (0.7 + 0.3 * fuerza)
    poner(a, (d < rr) & (d >= rr * 0.72) & (TRAMA < 0.6 * fuerza), VAPOR[0])
    poner(a, (d < rr * 0.72) & (TRAMA < fuerza * 1.3), VAPOR[1])
    d2 = np.hypot(XX - (x - rr * 0.2), YY - (y - rr * 0.3))
    poner(a, (d2 < rr * 0.45) & (TRAMA < fuerza * 1.3), VAPOR[2])
    poner(a, (d2 < rr * 0.2) & (fuerza > 0.5), VAPOR[3])


# --- LAS GRIETAS: el suelo en placas (Voronoi) con las juntas llenas de lava ---
class Placas:
    def __init__(self, sem, cx, cy, radio, n):
        rnd = random.Random(sem)
        p = []
        while len(p) < n:
            q = (cx + rnd.uniform(-radio, radio), cy + rnd.uniform(-radio, radio))
            # dos semillas casi encima dejan toda su placa en grieta (una mancha de lava maciza)
            if all(math.hypot(q[0] - x, q[1] - y) > 7.0 for x, y in p):
                p.append(q)
        d = np.stack([np.hypot(XX - x, YY - y) for x, y in p])
        d.sort(axis=0)
        self.junta = (d[1] - d[0])        # 0 en la grieta
        self.centros = p

    def pintar(self, a, zona, calor, enfria, fuerza=1.0, roca=ROCA):
        """calor 0..1 = cuanto brilla la lava; enfria 0..1 = de lava a costra negra. 'fuerza' la deshace a trama."""
        q = zona & (TRAMA < fuerza * 1.1)
        if not q.any():
            return
        poner(a, q, roca[1])
        poner(a, q & (self.junta > 2.5) & (self.junta < 4.0), roca[2])   # el canto de cada placa, un pelo mas claro
        g = q & (self.junta < 1.6)
        if enfria >= 1.0:
            poner(a, g, roca[0])
            return
        tonos = [LAVA[0], LAVA[1], LAVA[2], LAVA[3]]
        nivel = calor * (1.0 - enfria)
        poner(a, g, LAVA[0] if enfria < 0.7 else roca[0])
        if nivel > 0.25:
            poner(a, g & (self.junta < 1.1), tonos[1])
        if nivel > 0.55:
            poner(a, g & (self.junta < 0.6), tonos[2])
        if nivel > 0.85:
            poner(a, g & (self.junta < 0.3), tonos[3])
        # el brillo de la lava en el borde de las placas
        if nivel > 0.4:
            poner(a, q & (self.junta >= 1.6) & (self.junta < 2.4) & (TRAMA < nivel * 0.5), LAVA[0])


# ============================================================
#  BRASA: el aliento de dragon. Bocanadas que salen de la mano y se abren por el cono, crecen, suben en puntas y se hacen
#  humo; el suelo queda ennegrecido con ascuas que se apagan.
# ============================================================
def brasa(fila):
    dx, dy = DIRS[fila]
    L = 110.0 / UNIDAD
    medio = math.radians(25.0)
    A = (W * 0.5 - dx * L * 0.5, H * 0.56 - dy * L * 0.45)
    bx, by = mano(A, dx, dy)
    eje = math.atan2(dy, dx)
    rnd = random.Random(31 + fila)
    boc = []
    for i in range(30):
        u = 0.1 + 0.9 * math.sqrt(rnd.random())
        lat = rnd.uniform(-1.0, 1.0) * 0.8
        boc.append((u, lat, rnd.uniform(0, 6)))
    boc.sort()
    vict = [(A[0] + math.cos(eje + k) * L * d, A[1] + math.sin(eje + k) * L * d + 2) for k, d in ((-0.2, 0.55), (0.15, 0.85))]
    vict.append((A[0] + math.cos(eje + 1.3) * L * 0.5, A[1] + math.sin(eje + 1.3) * L * 0.5))
    m, t = [], []
    for f in range(SUELTA + 20):
        s, de, a = capas()
        e = f - SUELTA
        if e >= 0:
            frente = min(1.0, (e + 1) / 5.0)
            fuerza = 1.0 if e < 8 else max(0.0, 1.0 - (e - 8) / 5.0)
            if fuerza > 0:
                lengua(a if dy > -0.2 else de, bx, by, dx, dy, L * 0.4 * frente, 7.0, f, fuerza)
            for u, lat, sem in boc:
                if u > frente:
                    continue
                ang = eje + lat * medio
                dist = L * u
                x, y = A[0] + math.cos(ang) * dist, A[1] + math.sin(ang) * dist
                edad = e - u * 4.0
                # el suelo ennegrecido y sus ascuas
                queda = seco(e - 10, 4, 8) if e >= 10 else 1.0
                charco(s, x, y, 2.0 + u * 4.0, sem * 5, queda * 0.85, CHAMUSCADO, CHAMUSCADO[0])
                fz = fuerza * min(1.0, edad / 1.5 + 0.4)
                if fz > 0:
                    # bocanadas GORDAS que se juntan en una masa de fuego (no llamitas sueltas)
                    alto = (9.0 + 22.0 * u) * (0.75 + 0.25 * math.sin(e * 0.8 + sem))
                    llama(segun_y(y, A[1], de, a), x, y + 1, alto, 3.5 + 7.5 * u, f, fz, sem)
                if e >= 8:
                    g = e - 8
                    if int(sem * 10) % 3 == 0:
                        sf.humo(a, x + g * 0.4, y - 10 - g * 2.0 - u * 6, 3 + g * 0.8 + u * 3, max(0.0, 1.0 - g / 10.0))
                    if int(sem * 10) % 2 == 0 and g < 10:
                        chispas(a, x, y, 1, f, int(sem * 50), 8.0, 2.0)
        cuerpos = [(jugador(f, fila), A[0], A[1])] + [(None, *v) for v in vict]
        m.append(escena([s], [de], cuerpos, [a]))
        t.append(1000 // 14)
    return m, t


# ============================================================
#  ANDANADA IGNEA: cuatro bolas de fuego caen del cielo una tras otra en sus puntos del circulo; su sombra crece en el suelo
#  antes y cada una revienta en una bocanada que deja el suelo negro.
# ============================================================
def andanada():
    R = 65.0 / UNIDAD
    C = (W * 0.55, H * 0.6)
    A = (W * 0.08, H * 0.92)
    rnd = random.Random(4)
    puntos = []
    for k in range(4):
        ang = k * math.tau / 4 + 0.6 + rnd.uniform(-0.3, 0.3)
        d = R * rnd.uniform(0.25, 0.7)
        puntos.append((C[0] + math.cos(ang) * d, C[1] + math.sin(ang) * d, k * 3))
    vict = [(C[0] - R * 0.3, C[1] - R * 0.15), (C[0] + R * 0.45, C[1] + R * 0.1), (C[0] + R * 0.05, C[1] + R * 0.5)]
    m, t = [], []
    CAE = 5
    for f in range(SUELTA + 9 + CAE + 14):
        s, de, a = capas()
        e = f - SUELTA
        for x, y, t0 in puntos:
            k = e - t0
            if k < 0:
                continue
            if k < CAE:
                u = (k + 1) / CAE
                # la sombra crece en el suelo
                r = 2.0 + 6.0 * u
                m_ = ((XX - x) / r) ** 2 + ((YY - y) / (r * 0.55)) ** 2 <= 1.0
                poner(s, m_ & (TRAMA < 0.3 + 0.6 * u), ep.SOMBRA)
                alto = 120.0 * (1.0 - u) ** 1.3
                hy = y - 6 - alto
                ep.cometa(a, x, hy, 14 + 10 * (1 - u), 3, [FUEGO[0], FUEGO[1], FUEGO[2], FUEGO[3]])
                bola(a, x, hy, 4.5, f)
            else:
                g = k - CAE
                if g < 3:
                    estrella(a, x, y - 6, (16, 22, 12)[g], FUEGO)
                charco(s, x, y, 9.0 + min(g, 3) * 1.5, x, seco(g, 8, 8), CHAMUSCADO, CHAMUSCADO[0])
                fz = seco(g, 5, 5)
                for j in range(5):
                    ang = j * math.tau / 5 + x
                    px, py = x + math.cos(ang) * (3 + g * 1.2), y + math.sin(ang) * (2 + g * 0.8)
                    llama(segun_y(py, y, de, a), px, py, (12 - abs(j - 2) * 2) * (1.0 + 0.1 * g), 3.2, f, fz, j + x)
                anillo(s, x, y, 4 + g * 2.6, 3, [FUEGO[0], FUEGO[1], FUEGO[2]], seco(g, 2, 3))
                if g >= 4:
                    sf.humo(a, x, y - 10 - (g - 4) * 2.0, 4 + (g - 4) * 0.8, max(0.0, 1.0 - (g - 4) / 9.0))
                    chispas(a, x, y, 3, f, int(x), 14.0, 6.0)
        cuerpos = [(jugador(f, 3), A[0], A[1])] + [(None, *v) for v in vict]
        m.append(escena([s], [de], cuerpos, [a]))
        t.append(1000 // 14)
    return m, t


# ============================================================
#  MAR DE BRASAS: el suelo se raja desde ti por la franja, las grietas se llenan de lava, salen llamas y luego se enfria
#  (rojo -> negro) y se deshace.
# ============================================================
def mar_de_brasas(fila):
    dx, dy = DIRS[fila]
    L = 150.0 / UNIDAD
    media = 85.0 / UNIDAD * 0.5
    A = (W * 0.5 - dx * L * 0.5, H * 0.5 - dy * L * 0.5 + 4)
    pl = Placas(7 + fila, W * 0.5, H * 0.5, max(W, H) * 0.5, 150)
    s_ = (XX - A[0]) * dx + (YY - A[1]) * dy
    l_ = (XX - A[0]) * (-dy) + (YY - A[1]) * dx
    franja = (s_ >= -3) & (s_ <= L) & (np.abs(l_) <= media)
    rnd = random.Random(70 + fila)
    fuegos = [(rnd.uniform(0.04, 0.97), rnd.uniform(-0.85, 0.85), rnd.uniform(0, 6)) for _ in range(26)]
    vict = [(A[0] + dx * L * u - dy * w * media, A[1] + dy * L * u + dx * w * media) for u, w in ((0.35, 0.4), (0.7, -0.5), (0.9, 0.2))]
    m, t = [], []
    for f in range(SUELTA + 32):
        s, de, a = capas()
        e = f - SUELTA
        if e >= 0:
            frente = min(1.0, (e + 1) / 7.0)
            calor = min(1.0, (e + 1) / 4.0)
            enfria = 0.0 if e < 14 else min(1.0, (e - 14) / 8.0)
            fuerza = 1.0 if e < 24 else max(0.0, 1.0 - (e - 24) / 6.0)
            zona = franja & (s_ <= L * frente)
            pl.pintar(s, zona, calor, enfria, fuerza)
            if e < 3:
                anillo(s, A[0], A[1], 6 + e * 5, 3, [FUEGO[0], FUEGO[1], FUEGO[2]], 1.0 - e / 3.0)
                if e == 0:
                    estrella(a, A[0] + dx * 6, A[1] + dy * 6 - 4, 12, FUEGO)
            for u, w, sem in fuegos:
                if u > frente:
                    continue
                x, y = A[0] + dx * L * u - dy * w * media, A[1] + dy * L * u + dx * w * media
                edad = e - u * 7.0
                fz = min(1.0, edad / 2.0 + 0.3) * (1.0 if e < 12 else max(0.0, 1.0 - (e - 12) / 5.0))
                if fz > 0:
                    llama(segun_y(y, A[1], de, a), x, y, 14 + 5 * math.sin(e * 0.7 + sem), 4.5, f, fz, sem)
                if 12 <= e < 26 and int(sem * 10) % 3 == 0:
                    g = e - 12
                    sf.humo(a, x, y - 8 - g * 1.6, 3 + g * 0.6, max(0.0, 1.0 - g / 13.0))
        cuerpos = [(jugador(f, fila), A[0], A[1])] + [(None, *v) for v in vict]
        m.append(escena([s], [de], cuerpos, [a]))
        t.append(1000 // 12)
    return m, t


# ============================================================
#  SHOCK TERMICO FULMINANTE: el suelo del circulo arde en lava; cae una gota de agua; revienta en un fogonazo blanco y una
#  nube de vapor; la roca se queda negra, rajada, con puas oscuras que salen y se deshacen.
# ============================================================
def shock():
    R = 70.0 / UNIDAD
    C = (W * 0.55, H * 0.6)
    A = (W * 0.08, H * 0.92)
    pl = Placas(19, C[0], C[1], R, 46)
    d = np.hypot(XX - C[0], YY - C[1])
    rnd = random.Random(23)
    fuegos = [(rnd.uniform(0, math.tau), math.sqrt(rnd.random()) * 0.9, rnd.uniform(0, 6)) for _ in range(16)]
    puas = [(rnd.uniform(0, math.tau), math.sqrt(rnd.random()) * 0.85, rnd.uniform(11, 18), rnd.uniform(-0.5, 0.5)) for _ in range(14)]
    vapor = [(rnd.uniform(0, math.tau), math.sqrt(rnd.random()) * 0.8, rnd.uniform(0, 6)) for _ in range(12)]
    vict = [(C[0] - R * 0.35, C[1] - R * 0.2), (C[0] + R * 0.4, C[1] + R * 0.15), (C[0] - R * 0.05, C[1] + R * 0.5)]
    CAE0, CAE = 3, 5
    BUM = CAE0 + CAE
    m, t = [], []
    for f in range(SUELTA + BUM + 22):
        s, de, a = capas()
        e = f - SUELTA
        if e >= 0:
            if e < BUM:
                # 1) el suelo arde y se va abriendo desde el centro
                crece = min(1.0, (e + 1) / 4.0)
                pl.pintar(s, d <= R * crece, min(1.0, (e + 1) / 3.0), 0.0)
                anillo(s, C[0], C[1], R * crece, 3, [FUEGO[0], FUEGO[1], FUEGO[2]], 1.0)
                for ang, u, sem in fuegos:
                    if u > crece:
                        continue
                    x, y = C[0] + math.cos(ang) * R * u, C[1] + math.sin(ang) * R * u
                    llama(segun_y(y, C[1], de, a), x, y, 9 + 4 * math.sin(e + sem), 3.0, f, 1.0, sem)
                # 2) la gota de agua cae
                if e >= CAE0:
                    u = (e - CAE0 + 1) / CAE
                    hy = C[1] - 8 - 110 * (1 - u) ** 1.4
                    ep.cometa(a, C[0], hy - 2, 12, 2, AGUA)
                    sl.gota(a, C[0], hy, 7.0, AGUA, AGUA[0])
            else:
                g = e - BUM
                # 3) el fogonazo y la roca que se enfria de golpe
                if g < 3:
                    estrella(a, C[0], C[1] - 8, (34, 28, 16)[g], VAPOR)
                    anillo(s, C[0], C[1], R * (0.4 + 0.3 * g), 5, [VAPOR[1], VAPOR[2], VAPOR[3]], 1.0 - g / 3.0)
                fz = 1.0 if g < 14 else max(0.0, 1.0 - (g - 14) / 7.0)
                pl.pintar(s, d <= R, max(0.0, 0.8 - g * 0.12), min(1.0, g / 6.0), fz)
                for ang, u, alto, incl in puas:
                    sale = min(1.0, (g - u * 3) / 3.0)
                    if sale <= 0:
                        continue
                    x, y = C[0] + math.cos(ang) * R * u, C[1] + math.sin(ang) * R * u
                    tmp = nuevo()
                    n = math.hypot(incl, 1.0)
                    sl.cristal(tmp, x, y - alto * sale * 0.5, incl / n, -1.0 / n, alto * sale, 3.2, PUAS)
                    mk = (tmp[:, :, 3] > 0) & (TRAMA < fz * 1.1)
                    segun_y(y, C[1], de, a)[mk] = tmp[mk]
                for ang, u, sem in vapor:
                    if g > 9:
                        continue
                    # vapor ESPESO (a poca densidad la trama salia en puntitos sueltos): bulto que sube y se va rapido
                    x, y = C[0] + math.cos(ang) * R * u, C[1] + math.sin(ang) * R * u
                    vapor_bulto(a, x, y - 6 - g * 2.4, 5 + g * 1.1, max(0.0, 1.0 - g / 9.0))
        cuerpos = [(jugador(f, 3), A[0], A[1])] + [(None, *v) for v in vict]
        m.append(escena([s], [de], cuerpos, [a]))
        t.append(1000 // 12)
    return m, t


# ============================================================
#  FILO ARDIENTE y MANTO DE BRASAS: el fuego viaja en arco de tu mano a su arma; el Filo revienta en ella (anillo, llamitas
#  en la hoja y un destello); el Manto le envuelve entero y dos cintas de fuego le suben en espiral de los pies a la cabeza.
# ============================================================
def viaje(fila, manto):
    dx, dy = DIRS[fila]
    dist = 95.0
    A = (W * 0.5 - dx * dist * 0.5, H * 0.58 - dy * dist * 0.45)
    V = (A[0] + dx * dist, A[1] + dy * dist * 0.9)
    bx, by = mano(A, dx, dy)
    arma = (V[0] + 5, V[1] - 9)
    VUELA = 6
    m, t = [], []
    for f in range(SUELTA + VUELA + 18):
        s, de, a = capas()
        e = f - SUELTA
        if e == 0 or e == 1:
            estrella(a, bx, by, (8, 5)[e], FUEGO)
        if 0 <= e < VUELA:
            pts = []
            u1 = (e + 1) / VUELA
            for k in range(14):
                u = max(0.0, u1 - 0.35 * (1 - k / 13.0))
                x = bx + (arma[0] - bx) * u
                y = by + (arma[1] - by) * u - 22.0 * 4 * u * (1 - u)
                pts.append((x, y))
            estela(a, pts, FUEGO, 3)
            hx, hy = pts[-1]
            bola(a, hx, hy, 3.2, f)
            llama(a, hx, hy + 1, 7, 2.0, f, 1.0, e)
        elif e >= VUELA:
            g = e - VUELA
            if not manto:
                if g < 3:
                    estrella(a, arma[0], arma[1], (16, 12, 7)[g], FUEGO)
                if g < 5:
                    anillo(s, V[0], V[1], 6 + g * 3.0, 4, [FUEGO[0], FUEGO[1], FUEGO[2]], 1.0 if g < 3 else 0.5, 0.8)
                fz = seco(g, 8, 6)
                for j in range(3):
                    llama(a, arma[0] - 3 + j * 3, arma[1] + 2 - j * 2, 6 + 2 * math.sin(g + j), 1.8, f, fz, j)
                chispas(a, arma[0], arma[1], 3, f, 5, 12.0, 5.0)
                if g in (11, 12):
                    estrella(a, arma[0] + 1, arma[1] - 2, 10 - (g - 11) * 4, FUEGO)
            else:
                # la esfera que le envuelve (banda rellena) y las dos cintas en espiral
                if g < 5:
                    anillo(a if g < 2 else de, V[0], V[1] - ALTO_PECHO * 0.7, 13 - g * 0.5, 3, [FUEGO[0], FUEGO[1], FUEGO[2]], 1.0 - g / 5.0)
                if g < 2:
                    estrella(a, V[0], V[1] - ALTO_PECHO * 0.7, (14, 9)[g], FUEGO)
                sube = min(1.0, g / 9.0)
                fz = seco(g, 10, 5)
                for c in range(2):
                    for k in range(16):
                        u = sube - k * 0.035
                        if u < 0:
                            break
                        ang = u * 3 * math.tau + c * math.pi
                        x = V[0] + math.cos(ang) * 9.0
                        y = V[1] - u * 26.0 + math.sin(ang) * 3.0
                        col = FUEGO[3] if k == 0 else FUEGO[2] if k < 4 else FUEGO[1] if k < 9 else FUEGO[0]
                        if k >= 9 and (int(x) // 2 + int(y) // 2) % 2:
                            continue
                        if TRAMA[min(max(int(y), 0), H - 1), min(max(int(x), 0), W - 1)] >= fz * 1.1:
                            continue
                        punto(a if math.sin(ang) > 0 else de, x - 1, y - 1, col, 3 if k < 4 else 2)
                if 9 <= g < 12:
                    estrella(a, V[0], V[1] - 30, (14, 10, 6)[g - 9], FUEGO)
                if g >= 6:
                    chispas(a, V[0], V[1] - 8, 4, f, 9, 26.0, 8.0)
        cuerpos = [(jugador(f, fila), A[0], A[1]), (None, *V)]
        m.append(escena([s], [de], cuerpos, [a]))
        t.append(1000 // 14)
    return m, t


def lamina(filas, ruta, zoom=2):
    from PIL import ImageDraw
    ancho_rotulo = 170
    columnas = max(len(mm) for _, mm in filas)
    img = Image.new('RGB', (ancho_rotulo + columnas * (W * zoom + 4), len(filas) * (H * zoom + 8)), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, marcos) in enumerate(filas):
        y = j * (H * zoom + 8)
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, mm in enumerate(marcos):
            img.paste(mm.convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST), (ancho_rotulo + i * (W * zoom + 4), y))
    img.save(ruta)


def elegir(mm, idx):
    return [mm[min(i, len(mm) - 1)] for i in idx]


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    br = {d: brasa(d) for d in range(5)}
    an = andanada()
    ma = {d: mar_de_brasas(d) for d in range(5)}
    sh = shock()
    fi = {d: viaje(d, False) for d in (2, 4)}
    mt = {d: viaje(d, True) for d in (2, 4)}
    S = SUELTA
    filas = [
        *[('BRASA\naliento en cono\nhacia el ' + NOM_DIR[d], elegir(br[d][0], (S - 2, S + 1, S + 3, S + 6, S + 10, S + 15))) for d in range(5)],
        ('ANDANADA IGNEA\ncuatro bolas', elegir(an[0], (S + 2, S + 5, S + 8, S + 11, S + 15, S + 24))),
        *[('MAR DE BRASAS\nhacia el ' + NOM_DIR[d], elegir(ma[d][0], (S + 1, S + 4, S + 9, S + 16, S + 22, S + 27))) for d in range(5)],
        ('SHOCK TERMICO\nFULMINANTE', elegir(sh[0], (S + 2, S + 6, S + 9, S + 11, S + 17, S + 25))),
        *[('FILO ARDIENTE\nhacia el ' + NOM_DIR[d], elegir(fi[d][0], (S, S + 3, S + 6, S + 8, S + 12, S + 17))) for d in (2, 4)],
        *[('MANTO DE BRASAS\nhacia el ' + NOM_DIR[d], elegir(mt[d][0], (S + 3, S + 6, S + 8, S + 11, S + 14, S + 18))) for d in (2, 4)],
    ]
    lamina(filas, os.path.join(SALIDA, 'magia_fuego.png'))
    todos, tiempos = [], []
    for marcos, ts in [br[1], br[4], an, ma[2], sh, fi[2], mt[4]]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'magia_fuego.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
