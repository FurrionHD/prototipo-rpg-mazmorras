#!/usr/bin/env python3
# ============================================================
#  escarabajo_efectos_pixel.py -- MUESTRA DE EFECTOS EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art).
#  Pulso magnetico, Picado y Picado magnetico, pintados celda a celda en la MISMA rejilla que los sprites (1 celda = 1,15
#  unidades de mundo): paleta cerrada, sin suavizado y sin semitransparencias (lo que se desvanece, a trama). Lleva encima las
#  hojas de verdad del escarabajo para ver si casan. Solo la lamina y los gif: todavia no van al juego.
#    python tools/sprites_sdf/escarabajo_efectos_pixel.py
# ============================================================
import json
import math
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
# Una lamina por enemigo (memoria efectos-pixel-lamina-por-enemigo).
SALIDA = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'efectos_pixel')
W, H = 200, 230
UNIDAD = 1.15

HIERRO = [(40, 42, 50), (84, 88, 100), (148, 154, 168), (216, 222, 232)]
ROJO = [(92, 20, 18), (178, 38, 28), (240, 96, 58), (255, 226, 190)]
VERDE = [(24, 78, 66), (62, 150, 118), (150, 226, 186), (238, 255, 240)]
POLVO = [(66, 60, 54), (100, 90, 78), (144, 130, 110), (190, 176, 152)]
SOMBRA = (18, 14, 22)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
YY, XX = np.mgrid[0:H, 0:W]
# La trama va a bloques de 2 celdas: a 1 celda se lee como ruido fino, no como pixel art.
TRAMA = BAYER[(YY // 2) % 4, (XX // 2) % 4]


def nuevo():
    return np.zeros((H, W, 4), np.uint8)


def poner(a, mascara, col):
    a[mascara] = (*col, 255)


def punto(a, x, y, col, t=1):
    x, y = int(round(x)), int(round(y))
    a[max(y, 0):max(y + t, 0), max(x, 0):max(x + t, 0)] = (*col, 255)


def fondo():
    a = np.zeros((H, W, 3), np.uint8)
    cuadro = ((XX // 28 + YY // 28) % 2) == 0
    a[cuadro] = (56, 52, 58)
    a[~cuadro] = (50, 46, 52)
    a[(XX % 28 == 0) | (YY % 28 == 0)] = (43, 40, 46)
    return Image.fromarray(a, 'RGB').convert('RGBA')


# Disco con trama: 'densidad' de 0 a 1 elige cuantas celdas se pintan.
def disco(a, cx, cy, r, col, densidad=1.0):
    m = (XX - cx) ** 2 + (YY - cy) ** 2 <= r * r
    poner(a, m & (TRAMA < densidad), col)


# Nube de polvo: tres discos de sombreado, la luz arriba a la izquierda: se lee como bulto, no como canica.
def bolita(a, x, y, r, pal):
    if r < 1.0:
        punto(a, x, y, pal[1])
        return
    disco(a, x, y, r, pal[0])
    disco(a, x - r * 0.15, y - r * 0.2, r * 0.8, pal[1])
    disco(a, x - r * 0.3, y - r * 0.4, r * 0.45, pal[2])


# Una banda rellena: el filo en lo mas vivo con varias celdas de grueso, y detras se oscurece y se deshace a trama.
def banda(a, cx, cy, radio, ancho, pal, hacia_fuera, f, ondas=5):
    d = np.hypot(XX - cx, YY - cy)
    ang = np.arctan2(YY - cy, XX - cx)
    d = d + np.round(np.sin(ang * ondas + f * 0.9) * 1.0)
    p = (d - radio) if hacia_fuera else (radio - d)   # celdas desde el filo
    dentro = (p >= 0.0) & (p < ancho)
    u = p / max(ancho, 1.0)
    poner(a, dentro & (p >= 7.0) & (TRAMA < (1.0 - u) * 1.6), pal[0])
    poner(a, dentro & (p >= 4.0) & (p < 7.0), pal[1])
    poner(a, dentro & (p >= 2.0) & (p < 4.0), pal[2])
    poner(a, dentro & (p < 2.0), pal[3])


# EL CAMPO mientras carga: ondas rotas de bloques que van hacia dentro, nada de un aro cerrado.
def campo(a, cx, cy, R, t):
    d = np.hypot(XX - cx, YY - cy)
    ang = np.arctan2(YY - cy, XX - cx)
    poner(a, (d < R) & (d > R - 16.0) & (TRAMA < (d - (R - 16.0)) / 16.0 * 0.5), ROJO[0])
    for k in range(3):
        r = R - 3.0 - ((t + k / 3.0) % 1.0) * (R * 0.72)
        tramo = np.sin(ang * 11.0 + k * 2.1 + t * math.tau) > -0.15
        m = (np.abs(d - r) < 1.6) & tramo
        poner(a, m, ROJO[1] if r > R * 0.45 else ROJO[0])
        poner(a, (np.abs(d - r) < 0.7) & tramo & (r > R * 0.7), ROJO[2])


# Estrella de cuatro puntas maciza en pixeles: nucleo blanco, cuerpo vivo, puntas largas (nunca un circulo con borde).
def estrella(a, cx, cy, r, pal):
    cx, cy = int(cx), int(cy)
    n = int(r)
    for i in range(-n, n + 1):
        ancho = max(0, int((1.0 - abs(i) / max(r, 1)) ** 2 * r * 0.34))
        for j in range(-ancho, ancho + 1):
            col = pal[3] if abs(j) <= ancho * 0.45 else pal[2]
            punto(a, cx + i, cy + j, col)
            punto(a, cx + j, cy + i, col)
    disco(a, cx, cy, r * 0.22, pal[3])


# Limaduras: trocitos de 2-3 celdas con luz y sombra, EN RADIOS como las de un iman de verdad, que van hacia el centro.
class Limaduras:
    def __init__(self, n, radio, semilla, radios=30):
        rnd = random.Random(semilla)
        self.p = []
        for _ in range(n):
            ang = rnd.randrange(radios) / radios * math.tau + rnd.uniform(-0.035, 0.035)
            self.p.append((ang, rnd.random(), rnd.uniform(0.82, 1.0), rnd.choice((2, 2, 3))))
        self.radio = radio

    def carga(self, a, cx, cy, t, vueltas=1.0):
        for ang, fase, largo, grueso in self.p:
            u = (t * vueltas + fase) % 1.0
            r = self.radio * largo * (1.0 - u ** 1.5)
            if r < 18.0:
                continue
            dx, dy = math.cos(ang), math.sin(ang)
            brinco = int(abs(math.sin(u * 14.0 + fase * 9.0)) * 3.0)   # erizadas: saltan a tirones
            x, y = cx + dx * r, cy + dy * r - brinco
            if brinco:
                punto(a, cx + dx * r, cy + dy * r + 1, HIERRO[0], 2)
            punto(a, x + dx * 2, y + dy * 2, HIERRO[1], grueso)
            punto(a, x, y, HIERRO[2], grueso)
            punto(a, x, y, HIERRO[3], 1)

    def tiron(self, a, cx, cy, e):
        for ang, fase, largo, grueso in self.p:
            r = self.radio * largo * (1.0 - min(1.0, e * (1.0 + fase * 0.5)))
            if r < 5.0:
                continue
            dx, dy = math.cos(ang), math.sin(ang)
            cola = 4.0 + 9.0 * e
            for k, col, g in ((1.0, HIERRO[0], 1), (0.6, HIERRO[1], grueso), (0.25, HIERRO[2], grueso), (0.0, HIERRO[3], grueso)):
                punto(a, cx + dx * (r + cola * k), cy + dy * (r + cola * k), col, g)


def cometa(a, x, y, largo, ancho, pal):
    # Cae hacia abajo: cabeza opaca, cola que se afila y se deshace.
    for i in range(int(largo)):
        u = i / max(largo - 1.0, 1.0)
        media = int(round(ancho * (1.0 - u) ** 0.7))
        col = pal[3] if u < 0.2 else (pal[2] if u < 0.5 else pal[1])
        for j in range(-media, media + 1):
            if u < 0.7 or (int(x + j) + int(y - i)) % 2 == 0:
                punto(a, x + j, y - i, col)


def chispas(a, x, y, pal, semilla, n=4):
    rnd = random.Random(semilla)
    for _ in range(n):
        ang = rnd.uniform(0, math.tau)
        px, py = x + math.cos(ang) * rnd.uniform(9, 17), y + math.sin(ang) * rnd.uniform(5, 12)
        for k in range(rnd.randint(3, 5)):
            punto(a, px, py, pal[3] if k == 0 else pal[2] if k < 3 else pal[1])
            px += rnd.choice((-2, -1, 1, 2))
            py += rnd.choice((-1, 0, 1))


def victima(a, x, y):
    x, y = int(x), int(y)
    a[y - 19:y - 13, x - 3:x + 4] = (222, 182, 150, 255)
    a[y - 13:y - 3, x - 5:x + 6] = (58, 96, 180, 255)
    a[y - 13:y - 3, x + 3:x + 6] = (36, 66, 130, 255)
    a[y - 3:y, x - 4:x - 1] = (38, 40, 58, 255)
    a[y - 3:y, x + 1:x + 4] = (38, 40, 58, 255)


# --- Las hojas de verdad ---
_hojas = {}


def marco(var, anim, f, fila=0):
    clave = (var, anim)
    if clave not in _hojas:
        _hojas[clave] = Image.open(os.path.join(RAIZ, 'assets/sprites/enemigos/escarabajo_sdf_%s/%s.png' % (var, anim))).convert('RGBA')
    h = _hojas[clave]
    n = h.size[0] // 136
    return h.crop(((f % n) * 136, fila * 224, (f % n) * 136 + 136, fila * 224 + 224))


# EL CENTRO DE SU DIBUJO en este marco, desde los pies (sin la sombra, que es casi negra). Lo que sale del cuerpo se centra
# con esto y no con una altura fija: la altura solo cuadra de arriba a abajo; de lado saca el efecto del eje (lo vio el, 04/11).
def centro_dibujo(spr):
    a = np.asarray(spr).astype(int)
    m = (a[:, :, 3] > 128) & (a[:, :, :3].sum(axis=2) > 110)
    if not m.any():
        return 0.0, 0.0
    ys, xs = np.nonzero(m)
    return float(xs.mean()) - 68.0, float(ys.mean()) - 112.0


def componer(capas_suelo, cuerpo, capas_aire):
    img = fondo()
    for c in capas_suelo:
        img.alpha_composite(Image.fromarray(c, 'RGBA'))
    if cuerpo is not None:
        spr, x, y = cuerpo
        img.paste(spr, (int(x) - 68, int(y) - 112), spr)
    for c in capas_aire:
        img.alpha_composite(Image.fromarray(c, 'RGBA'))
    return img


# --- PULSO MAGNETICO ---
def pulso():
    cx, cy = 100, 140
    R = 80.0 / UNIDAD
    lim = Limaduras(90, R, 7)
    salida = []
    v0 = [(cx + 46, cy + 24), (cx - 52, cy - 16)]
    for f in range(12):   # la carga: 12 fps, en bucle mientras dura
        t = f / 12.0
        s, a = nuevo(), nuevo()
        campo(s, cx, cy, R, t)
        lim.carga(s, cx, cy, t)
        for v in v0:
            victima(s, *v)
        chispas(a, cx, cy - 20, ROJO, f * 13 + 1)
        salida.append(componer([s], (marco('iman', 'pulso_carga', f), cx, cy), [a]))
    for f in range(10):   # el tiron
        e = min(1.0, f / 6.0) ** 1.7
        s, a = nuevo(), nuevo()
        radio = R * (1.0 - e)
        if f <= 6:
            banda(s, cx, cy, radio, 9.0 + 12.0 * (1.0 - e), ROJO, True, f)
            lim.tiron(s, cx, cy, e)
        elif f <= 8:
            lim2 = Limaduras(40, 16.0 + (f - 6) * 7.0, 11 + f)
            for ang, fase, largo, grueso in lim2.p:
                r = lim2.radio * largo
                punto(s, cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.9, HIERRO[1 + (f == 7)], grueso)
        for x, y in v0:
            k = 1.0 - min(1.0, max(e, 0.0)) * 0.72
            victima(s, cx + (x - cx) * k, cy + (y - cy) * k)
        if f == 5:
            estrella(a, cx, cy - 8, 12, ROJO)
        elif f == 6:
            estrella(a, cx, cy - 8, 26, ROJO)
        elif f == 7:
            estrella(a, cx, cy - 8, 15, ROJO)
        cuerpo = marco('iman', 'pulso', min(f, 5))
        salida.append(componer([s], (cuerpo, cx, cy), [a]))
    return salida, [1000 // 12] * 12 + [1000 // 14] * 10


# --- EL PICADO (y el magnetico, en el mismo trazado) ---
def _impacto(a_suelo, a_aire, x, y, f, R, pal, semilla):
    """f = marcos desde que toca."""
    rnd = random.Random(semilla)
    e = min(1.0, (f + 1) / 6.0) ** 0.7
    # (el polvo no acaba en un aro fino: a partir de ahi solo quedan las bolitas)
    if f < 3:
        banda(a_suelo, x, y, R * e, 8.0 + 7.0 * (1.0 - e), pal, False, f)
    elif f == 3:
        d = np.hypot(XX - x, YY - y)
        poner(a_suelo, (d < R * e) & (d > R * e - 12.0) & (TRAMA < 0.45), POLVO[1])
    for i in range(14):
        ang = i / 14.0 * math.tau + rnd.uniform(-0.2, 0.2)
        d = R * (0.45 + 0.75 * e) * rnd.uniform(0.7, 1.05)
        rad = rnd.uniform(2.5, 5.5) * (1.0 - min(1.0, f / 8.0))
        if rad > 0.6:
            bolita(a_suelo, x + math.cos(ang) * d, y + math.sin(ang) * d - f * 0.6, rad, POLVO)
    for i in range(8):
        ang = rnd.uniform(0, math.tau)
        v = rnd.uniform(0.6, 1.0)
        u = f / 6.0
        if u <= 1.0:
            sx = x + math.cos(ang) * R * 0.9 * v * u
            sy = y + math.sin(ang) * R * 0.6 * v * u - math.sin(u * math.pi) * 14.0 * v
            punto(a_aire, sx, sy, HIERRO[2], 2)
            punto(a_aire, sx, sy + 1, HIERRO[1], 2)
    if f == 0:
        estrella(a_aire, x, y - 6, 18, pal)
    elif f == 1:
        estrella(a_aire, x, y - 6, 30, pal)
    elif f == 2:
        estrella(a_aire, x, y - 6, 14, pal)


def picado(var, magnetico):
    A = (42, 168)
    B0, B1 = (118, 128), (150, 154)
    R = (70.0 if magnetico else 30.0) / UNIDAD
    pal = ROJO if magnetico else VERDE
    lim = Limaduras(100, R, 19)
    salida, tiempos = [], []
    for f in range(8):   # sube: el polvo que levanta el aleteo
        s = nuevo()
        for i in range(10):
            ang = i / 10.0 * math.tau + 0.3
            d = 10.0 + f * 3.0
            bolita(s, A[0] + math.cos(ang) * d, A[1] + math.sin(ang) * d * 0.75, max(0.0, 4.5 - f * 0.55), POLVO)
        victima(s, *B0)
        salida.append(componer([s], (marco(var, 'subir', f), A[0], A[1]), []))
        tiempos.append(1000 // 12)
    n = 12
    for f in range(n):   # arriba: su sombra se te pega a los pies aunque andes
        u = f / (n - 1.0)
        bx, by = B0[0] + (B1[0] - B0[0]) * u, B0[1] + (B1[1] - B0[1]) * u
        s = nuevo()
        centro = (bx, by)
        if magnetico:
            centro = B0   # el magnetico no persigue: arrastra hacia su punto
            campo(s, centro[0], centro[1], R, f / 12.0)
            lim.carga(s, centro[0], centro[1], f / 12.0)
            k = 1.0 - u * 0.5
            bx, by = centro[0] + (B1[0] - centro[0]) * k, centro[1] + (B1[1] - centro[1]) * k
        rs = 6.0 + 4.0 * u + round(math.sin(f * 1.1))
        disco(s, centro[0], centro[1], rs, SOMBRA, 0.3 + 0.2 * u)
        disco(s, centro[0], centro[1], rs * 0.55, SOMBRA, 0.65)
        victima(s, bx, by)
        salida.append(componer([s], (marco(var, 'aire', f), A[0], A[1]), []))
        tiempos.append(1000 // 14)
    objetivo = B0 if magnetico else B1
    golpe = 4   # el marco en el que toca (0,6 de 8)
    fin_presa = (objetivo[0] + 15, objetivo[1] + 8)
    for f in range(13):
        s, a = nuevo(), nuevo()
        u = min(1.0, f / golpe)
        x = A[0] + (objetivo[0] - A[0]) * u
        y = A[1] + (objetivo[1] - A[1]) * u
        px, py = objetivo if f < golpe else fin_presa
        if magnetico and f < golpe:
            lim.tiron(s, objetivo[0], objetivo[1], u)
        if f >= golpe:
            _impacto(s, a, objetivo[0], objetivo[1], f - golpe, R, pal, 41)
        else:
            disco(s, objetivo[0], objetivo[1], 10.0 + 4.0 * u, SOMBRA, 0.5 + 0.3 * u)
        if f < golpe:
            # Detras de el, que cae: arrancan de lo alto de SU dibujo en este marco (medido, el cuerpo sube y baja en la hoja).
            caja = marco(var, 'picado', min(f, 7)).getchannel('A').getbbox()
            alto = y - 112 + (caja[1] if caja else 80)
            for dx, largo in ((-8, 16), (0, 24), (8, 14)):
                cometa(a, x + dx, alto + 4, largo, 2, pal)
        victima(s, px, py)
        salida.append(componer([s], (marco(var, 'picado', min(f, 7)), x, y), [a]))
        tiempos.append(1000 // 14)
    return salida, tiempos


# --- LO QUE VA EN UNA DIRECCION: una fila de la hoja por direccion (0 = S, 2 = E, 4 = N...), como los sprites ---
DIRS = [(0.0, 1.0), (0.707, 0.707), (1.0, 0.0), (0.707, -0.707), (0.0, -1.0), (-0.707, -0.707), (-1.0, 0.0), (-0.707, 0.707)]
RADIO_CUERPO = 27.0   # de sus pies a la punta de la herradura, y lo que ocupa el arrastrado


def cometa_dir(a, x, y, dx, dy, largo, ancho, pal):
    # Cabeza opaca en (x, y), cola hacia (-dx, -dy) que se afila y se deshace a trama.
    px, py = -dy, dx
    for i in range(int(largo)):
        u = i / max(largo - 1.0, 1.0)
        media = ancho * (1.0 - u) ** 0.7
        col = pal[3] if u < 0.07 else (pal[2] if u < 0.4 else pal[1] if u < 0.72 else pal[0])
        cx, cy = x - dx * i, y - dy * i
        for j in range(-int(round(media)), int(round(media)) + 1):
            qx, qy = int(round(cx + px * j)), int(round(cy + py * j))
            if u < 0.72 or ((qx // 2 + qy // 2) % 2 == 0):
                punto(a, qx, qy, col, 2)


# La media luna maciza de delante de lo que empuja: el filo vivo, y detras se oscurece.
def media_luna(a, x, y, dx, dy, r, pal):
    d = np.hypot(XX - x, YY - y)
    d2 = np.hypot(XX - (x - dx * r * 0.62), YY - (y - dy * r * 0.62))
    delante = (XX - x) * dx + (YY - y) * dy > -r * 0.25
    luna = (d <= r) & (d2 > r * 0.86) & delante
    borde = r - d
    poner(a, luna, pal[0])
    poner(a, luna & (borde < 6.0), pal[1])
    poner(a, luna & (borde < 3.5), pal[2])
    poner(a, luna & (borde < 1.5), pal[3])


# (x, y) = donde nace, delante del cuerpo; se abre hacia atras hasta 'ancho' y acaba a 'largo'. El borde en lo vivo, hebras
# de aire por dentro (que ondulan con 'f') y el suelo se sigue viendo a traves. 'fuerza' 1 = entera, 0 = ya deshecha.
def estela(a, x, y, dx, dy, largo, ancho, pal, f, fuerza=1.0):
    atras = -((XX - x) * dx + (YY - y) * dy)
    lado = (XX - x) * (-dy) + (YY - y) * dx
    u = np.clip(atras / max(largo, 1.0), 0.0, 1.0)
    perfil = ancho * np.sin(np.pi * u ** 0.55)
    dentro = (atras > 0.0) & (atras < largo) & (np.abs(lado) < perfil)
    rel = np.abs(lado) / np.maximum(perfil, 0.01)
    # Se deshace hacia la cola, y entera antes cuanto menos 'fuerza' le queda.
    vivo = TRAMA < (1.15 - u * 1.25) * fuerza * 1.6
    # Hebras de distinto grueso y que no van paralelas: con una sola onda salia un melon a rayas.
    hebra = np.sin(lado * 0.42 + np.sin(atras * 0.13 + lado * 0.2) * 1.5 - f * 0.9) + np.sin(lado * 1.05 - atras * 0.07) * 0.45 > 0.72
    poner(a, dentro & vivo & hebra & (TRAMA < 0.6), pal[0])
    poner(a, dentro & vivo & hebra & (u < 0.55), pal[1])
    poner(a, dentro & vivo & (rel > 0.74), pal[1])
    poner(a, dentro & vivo & (rel > 0.74) & (u < 0.6), pal[2])
    poner(a, dentro & (rel > 0.84) & (u < 0.3) & (fuerza > 0.5), pal[3])


def _huellas_polvo(a, x0, y0, dx, dy, avance, semilla, paso=9.0):
    rnd = random.Random(semilla)
    for k in range(int(avance / paso)):
        d = k * paso
        edad = (avance - d) / paso
        rad = rnd.uniform(3.0, 5.0) * max(0.0, 1.0 - edad * 0.16)
        lado = rnd.uniform(-7.0, 7.0)
        if rad > 0.7:
            bolita(a, x0 + dx * d - dy * lado, y0 + dy * d + dx * lado - edad, rad, POLVO)


def embestida(fila):
    dx, dy = DIRS[fila]
    largo = 100.0 / UNIDAD
    A = (100 - dx * largo * 0.5, 140 - dy * largo * 0.5)
    vict = (A[0] + dx * 26.0, A[1] + dy * 26.0)
    m, t = [], []
    for f in range(8):   # la carga: baja la herradura, y las limaduras se le juntan delante
        s, a = nuevo(), nuevo()
        rnd = random.Random(f // 2 + 3)
        for _ in range(26):
            ang, d = rnd.uniform(-0.9, 0.9), rnd.uniform(14.0, 40.0) * (1.0 - f / 11.0)
            c, n = math.cos(ang), math.sin(ang)
            hx, hy = dx * c - dy * n, dy * c + dx * n
            punto(s, A[0] + hx * d, A[1] + hy * d, HIERRO[rnd.randint(1, 3)], 2)
        chispas(a, A[0] + dx * 14, A[1] + dy * 14 - 8, ROJO, f * 7 + 1, 3)
        victima(s, *vict)
        m.append(componer([s], (marco('iman', 'embestir_carga', f, fila), A[0], A[1]), [a]))
        t.append(1000 // 8)
    for f in range(9):   # sale: lo primero que pilla se lo lleva hasta el final
        u = min(1.0, f / 6.0)
        d = largo * u
        s, a = nuevo(), nuevo()
        x, y = A[0] + dx * d, A[1] + dy * d
        _huellas_polvo(s, A[0], A[1], dx, dy, d, 23)
        rnd = random.Random(f * 3 + 17)
        for _ in range(7):
            atras, lado = rnd.uniform(16.0, 40.0), rnd.uniform(-13.0, 13.0)
            if atras < d + 6.0:
                cometa_dir(s, x - dx * atras - dy * lado, y - dy * atras + dx * lado, dx, dy, rnd.uniform(6.0, 13.0), 0, HIERRO)
        ox, oy = centro_dibujo(marco('iman', 'embestir', f, fila))
        al_eje = ox * dx + oy * dy
        lx, ly = ox - dx * al_eje, oy - dy * al_eje
        pega = d >= 26.0 - RADIO_CUERPO
        vx, vy = (x + lx + dx * RADIO_CUERPO, y + ly + dy * RADIO_CUERPO + 9.0 * abs(dx)) if pega else vict
        victima(s if dy <= 0 else a, vx, vy)
        if f < 7:
            media_luna(s, x + lx + dx * (RADIO_CUERPO + 5), y + ly + dy * (RADIO_CUERPO + 5), dx, dy, 13, ROJO)
        if pega and f < 7:
            chispas(a, vx, vy - 8, ROJO, f * 5 + 2, 3)
        m.append(componer([s], (marco('iman', 'embestir', f, fila), x, y), [a]))
        t.append(1000 // 18)
    return m, t


def pasada(fila):
    dx, dy = DIRS[fila]
    largo = 140.0 / UNIDAD
    A = (100 - dx * largo * 0.5, 140 - dy * largo * 0.5)
    vict = (100.0 - dy * 6.0, 140.0 + dx * 6.0)
    m, t = [], []
    for f in range(9):
        u = min(1.0, f / 5.0)
        d = largo * u
        s, a = nuevo(), nuevo()
        x, y = A[0] + dx * d, A[1] + dy * d
        victima(s, *vict)
        if f < 3:
            for i in range(6):
                ang = i / 6.0 * math.tau
                bolita(s, A[0] + math.cos(ang) * (7 + f * 4), A[1] + math.sin(ang) * (5 + f * 3), 4.0 - f, POLVO)
        cola = 1.0 if f <= 5 else max(0.0, 1.0 - (f - 5) * 0.3)
        largo_e = min(68.0, d + 22.0)
        if cola > 0.05 and f >= 1:
            ox, oy = centro_dibujo(marco('saeta', 'pasada', f, fila))
            estela(s, x + ox + dx * 12, y + oy + dy * 12, dx, dy, largo_e, 17.0, VERDE, f, cola)
        cruza = (d - largo * 0.5) / 12.0
        if -0.2 < cruza < 1.1:
            estrella(a, vict[0], vict[1] - 8, 16 if cruza < 0.5 else 9, VERDE)
        m.append(componer([s], (marco('saeta', 'pasada', f, fila), x, y), [a]))
        t.append(1000 // 18)
    return m, t


def coraza():
    cx, cy = 100, 140
    rnd = random.Random(31)
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(20.0, 46.0), rnd.random() * 0.35, rnd.choice((2, 2, 3))) for _ in range(70)]
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        u = f / 7.0
        for ang, d0, retardo, g in motas:
            v = (u - retardo) / (1.0 - retardo)
            if v >= 1.0:
                continue
            v = max(v, 0.0)
            v2 = v * v
            x = cx + math.cos(ang) * d0 * (1.0 - v2)
            y = cy + math.sin(ang) * d0 * (1.0 - v2) - 12.0 * v2 - math.sin(v * math.pi) * 10.0
            capa = a if v > 0.2 else s
            punto(capa, x, y, HIERRO[2], g)
            punto(capa, x, y, HIERRO[3], 1)
        if 6 <= f <= 8:
            estrella(a, cx, cy - 14, (22, 30, 14)[f - 6], HIERRO)
        if f >= 6:
            e = (f - 5) / 7.0
            if f < 9:
                banda(s, cx, cy, 14.0 + 22.0 * e, 7.0, ROJO, False, f)
            else:
                dis = np.hypot(XX - cx, YY - cy)
                poner(s, (dis < 14.0 + 22.0 * e) & (dis > 2.0 + 22.0 * e) & (TRAMA < 0.55 - (f - 9) * 0.16), HIERRO[1])
        m.append(componer([s], (marco('iman', 'caparazon', min(f, 7)), cx, cy), [a]))
        t.append(1000 // 12)
    return m, t


def elitros():
    cx, cy = 100, 140
    m, t = [], []
    rnd = random.Random(5)
    rayos = [(i / 10.0 * math.tau + rnd.uniform(-0.15, 0.15), rnd.uniform(0.8, 1.2)) for i in range(10)]
    for f in range(11):
        s, a = nuevo(), nuevo()
        if f >= 3:
            e = (f - 2) / 7.0
            for ang, v in rayos:
                dx, dy = math.cos(ang), math.sin(ang)
                d = 12.0 + 42.0 * e * v
                cometa_dir(a, cx + dx * d, cy - 14 + dy * d * 0.8, dx, dy, max(4.0, 20.0 * (1.0 - e)), 1, VERDE)
                if f <= 5:
                    bolita(s, cx + dx * d * 0.7, cy + dy * d * 0.55, 4.0 - (f - 3), POLVO)
        if f == 3:
            estrella(a, cx, cy - 18, 13, VERDE)
        m.append(componer([s], (marco('saeta', 'elitros', min(f, 7)), cx, cy), [a]))
        t.append(1000 // 12)
    return m, t


def caida(var):
    cx, cy = 100, 150
    m, t = [], []
    toca = 4
    rnd = random.Random(9)
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(0.6, 1.0), rnd.uniform(4.0, 7.0)) for _ in range(14)]
    for f in range(14):
        s, a = nuevo(), nuevo()
        if f >= toca:
            e = (f - toca) / 7.0
            for ang, v, rad in motas:
                r2 = rad * max(0.0, 1.0 - e * 1.1)
                if r2 > 0.6:
                    bolita(s, cx + math.cos(ang) * (9.0 + 28.0 * e * v), cy + math.sin(ang) * (6.0 + 15.0 * e * v) - e * 5.0, r2, POLVO)
            for ang, v, _r in motas[:6]:
                if e < 0.8:
                    punto(a, cx + math.cos(ang) * 24.0 * e * v, cy - math.sin(e * math.pi * 1.2) * 14.0 * v, HIERRO[2], 2)
        spr = marco(var, 'caer', f) if f < 8 else marco(var, 'volteado', f - 8)
        m.append(componer([s], (spr, cx, cy), [a]))
        t.append(1000 // 14)
    return m, t


def lamina(filas, ruta):
    zoom, ancho_rotulo = 2, 150
    columnas = max(len(m) for _, m in filas)
    img = Image.new('RGB', (ancho_rotulo + columnas * (W * zoom + 4), len(filas) * (H * zoom + 10)), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, marcos) in enumerate(filas):
        y = j * (H * zoom + 10)
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, m in enumerate(marcos):
            img.paste(m.convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST), (ancho_rotulo + i * (W * zoom + 4), y))
    img.save(ruta)


NOM_DIR = ['SUR', 'SURESTE', 'ESTE', 'NORESTE', 'NORTE']


def elegir(m, n=6):
    return [m[int(i * (len(m) - 1) / (n - 1))] for i in range(n)]


def gif(marcos, tiempos, ruta, zoom=3):
    fotos = [m.convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST).quantize(64, dither=Image.NONE) for m in marcos]
    fotos[0].save(ruta, save_all=True, append_images=fotos[1:], duration=tiempos, loop=0, optimize=False)


# --- LAS HOJAS DEL JUEGO: solo el efecto, sin escarabajo ni fondo. Origen = los pies de quien lo lanza, o el centro de su marca ---
CX, CY = 100, 115
ASSETS = os.path.join(RAIZ, 'assets', 'sprites', 'efectos', 'escarabajo')
DATOS = os.path.join(RAIZ, 'scripts', 'fx', 'efectos_pixel_datos.gd')
FILAS_DIR = range(5)   # S, SE, E, NE, N: las otras tres, en espejo


def _h_pulso_carga(R):
    lim = Limaduras(90, R, 7)
    out = []
    for f in range(12):
        s, a = nuevo(), nuevo()
        campo(s, CX, CY, R, f / 12.0)
        lim.carga(s, CX, CY, f / 12.0)
        chispas(a, CX, CY - 20, ROJO, f * 13 + 1)
        out.append((s, a))
    return [out]


def _h_mag_carga():
    R = 70.0 / UNIDAD
    lim = Limaduras(100, R, 19)
    out = []
    for f in range(12):
        s = nuevo()
        campo(s, CX, CY, R, f / 12.0)
        lim.carga(s, CX, CY, f / 12.0)
        out.append((s, nuevo()))
    return [out]


def _h_pulso_tiron():
    R = 80.0 / UNIDAD
    lim = Limaduras(90, R, 7)
    out = []
    for f in range(10):
        e = min(1.0, f / 6.0) ** 1.7
        s, a = nuevo(), nuevo()
        if f <= 6:
            banda(s, CX, CY, R * (1.0 - e), 9.0 + 12.0 * (1.0 - e), ROJO, True, f)
            lim.tiron(s, CX, CY, e)
        elif f <= 8:
            lim2 = Limaduras(40, 16.0 + (f - 6) * 7.0, 11 + f)
            for ang, _fase, largo, grueso in lim2.p:
                r = lim2.radio * largo
                punto(s, CX + math.cos(ang) * r, CY + math.sin(ang) * r * 0.9, HIERRO[1 + (f == 7)], grueso)
        if f in (5, 6, 7):
            estrella(a, CX, CY - 8, {5: 12, 6: 26, 7: 15}[f], ROJO)
        out.append((s, a))
    return [out]


def _h_impacto(R, pal, previos):
    # 'previos' marcos antes de que toque: las limaduras del magnetico, que van hacia su punto mientras cae.
    lim = Limaduras(100, R, 19)
    out = []
    for f in range(previos):
        s = nuevo()
        lim.tiron(s, CX, CY, (f + 1) / float(previos))
        out.append((s, nuevo()))
    for f in range(10):
        s, a = nuevo(), nuevo()
        _impacto(s, a, CX, CY, f, R, pal, 41)
        out.append((s, a))
    return [out]


def _h_sombra():
    out = []
    for f in range(8):
        s = nuevo()
        rs = 9.0 + round(math.sin(f / 8.0 * math.tau))
        disco(s, CX, CY, rs, SOMBRA, 0.42)
        disco(s, CX, CY, rs * 0.55, SOMBRA, 0.7)
        out.append((s, nuevo()))
    return [out]


def _h_estela_picado(pal, var):
    out = []
    for f in range(5):
        a = nuevo()
        caja = marco(var, 'picado', f).getchannel('A').getbbox()
        alto = CY - 112 + (caja[1] if caja else 80)
        for dx, largo in ((-8, 16), (0, 24), (8, 14)):
            cometa(a, CX + dx, alto + 4, largo, 2, pal)
        out.append((nuevo(), a))
    return [out]


def _h_polvo_subir():
    out = []
    for f in range(8):
        s = nuevo()
        for i in range(10):
            ang = i / 10.0 * math.tau + 0.3
            d = 10.0 + f * 3.0
            bolita(s, CX + math.cos(ang) * d, CY + math.sin(ang) * d * 0.75, max(0.0, 4.5 - f * 0.55), POLVO)
        out.append((s, nuevo()))
    return [out]


def _h_polvo_paso():
    rnd = random.Random(23)
    motas = [(rnd.uniform(-5.0, 5.0), rnd.uniform(-3.0, 3.0), rnd.uniform(2.5, 4.5)) for _ in range(3)]
    out = []
    for f in range(6):
        s = nuevo()
        for x, y, r in motas:
            bolita(s, CX + x, CY + y - f, r * (1.0 - f / 6.0), POLVO)
        out.append((s, nuevo()))
    return [out]


def _h_emb_carga():
    filas = []
    for d in FILAS_DIR:
        dx, dy = DIRS[d]
        fila = []
        for f in range(8):
            s, a = nuevo(), nuevo()
            rnd = random.Random(f // 2 + 3)
            for _ in range(26):
                ang, dist = rnd.uniform(-0.9, 0.9), rnd.uniform(14.0, 40.0) * (1.0 - f / 11.0)
                c, n = math.cos(ang), math.sin(ang)
                punto(s, CX + (dx * c - dy * n) * dist, CY + (dy * c + dx * n) * dist, HIERRO[rnd.randint(1, 3)], 2)
            chispas(a, CX + dx * 14, CY + dy * 14 - 8, ROJO, f * 7 + 1, 3)
            fila.append((s, a))
        filas.append(fila)
    return filas


def _h_emb_sale():
    filas = []
    for d in FILAS_DIR:
        dx, dy = DIRS[d]
        fila = []
        for f in range(9):
            s, a = nuevo(), nuevo()
            ox, oy = centro_dibujo(marco('iman', 'embestir', f, d))
            al_eje = ox * dx + oy * dy
            lx, ly = ox - dx * al_eje, oy - dy * al_eje
            rnd = random.Random(f * 3 + 17)
            for _ in range(7):
                atras, lado = rnd.uniform(16.0, 40.0), rnd.uniform(-13.0, 13.0)
                cometa_dir(s, CX - dx * atras - dy * lado, CY - dy * atras + dx * lado, dx, dy, rnd.uniform(6.0, 13.0), 0, HIERRO)
            if f < 7:
                media_luna(s, CX + lx + dx * (RADIO_CUERPO + 5), CY + ly + dy * (RADIO_CUERPO + 5), dx, dy, 13, ROJO)
                chispas(a, CX + lx + dx * RADIO_CUERPO, CY + ly + dy * RADIO_CUERPO - 4, ROJO, f * 5 + 2, 3)
            fila.append((s, a))
        filas.append(fila)
    return filas


def _h_pasada():
    filas = []
    for d in FILAS_DIR:
        dx, dy = DIRS[d]
        fila = []
        for f in range(9):
            s = nuevo()
            cola = 1.0 if f <= 5 else max(0.0, 1.0 - (f - 5) * 0.3)
            if f >= 1 and cola > 0.05:
                ox, oy = centro_dibujo(marco('saeta', 'pasada', f, d))
                estela(s, CX + ox + dx * 12, CY + oy + dy * 12, dx, dy, min(68.0, 22.0 + f * 12.0), 17.0, VERDE, f, cola)
            fila.append((s, nuevo()))
        filas.append(fila)
    return filas


def _h_coraza():
    rnd = random.Random(31)
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(20.0, 46.0), rnd.random() * 0.35, rnd.choice((2, 2, 3))) for _ in range(70)]
    out = []
    for f in range(12):
        s, a = nuevo(), nuevo()
        u = f / 7.0
        for ang, d0, retardo, g in motas:
            v = (u - retardo) / (1.0 - retardo)
            if v >= 1.0:
                continue
            v = max(v, 0.0)
            v2 = v * v
            x = CX + math.cos(ang) * d0 * (1.0 - v2)
            y = CY + math.sin(ang) * d0 * (1.0 - v2) - 12.0 * v2 - math.sin(v * math.pi) * 10.0
            capa = a if v > 0.2 else s
            punto(capa, x, y, HIERRO[2], g)
            punto(capa, x, y, HIERRO[3], 1)
        if 6 <= f <= 8:
            estrella(a, CX, CY - 14, (22, 30, 14)[f - 6], HIERRO)
        if f >= 6:
            e = (f - 5) / 7.0
            if f < 9:
                banda(s, CX, CY, 14.0 + 22.0 * e, 7.0, ROJO, False, f)
            else:
                dis = np.hypot(XX - CX, YY - CY)
                poner(s, (dis < 14.0 + 22.0 * e) & (dis > 2.0 + 22.0 * e) & (TRAMA < 0.55 - (f - 9) * 0.16), HIERRO[1])
        out.append((s, a))
    return [out]


def _h_elitros():
    rnd = random.Random(5)
    rayos = [(i / 10.0 * math.tau + rnd.uniform(-0.15, 0.15), rnd.uniform(0.8, 1.2)) for i in range(10)]
    out = []
    for f in range(11):
        s, a = nuevo(), nuevo()
        if f >= 3:
            e = (f - 2) / 7.0
            for ang, v in rayos:
                dx, dy = math.cos(ang), math.sin(ang)
                d = 12.0 + 42.0 * e * v
                cometa_dir(a, CX + dx * d, CY - 14 + dy * d * 0.8, dx, dy, max(4.0, 20.0 * (1.0 - e)), 1, VERDE)
                if f <= 5:
                    bolita(s, CX + dx * d * 0.7, CY + dy * d * 0.55, 4.0 - (f - 3), POLVO)
        if f == 3:
            estrella(a, CX, CY - 18, 13, VERDE)
        out.append((s, a))
    return [out]


def _h_caer():
    rnd = random.Random(9)
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(0.6, 1.0), rnd.uniform(4.0, 7.0)) for _ in range(14)]
    out = []
    for f in range(10):
        s, a = nuevo(), nuevo()
        e = f / 7.0
        for ang, v, rad in motas:
            r2 = rad * max(0.0, 1.0 - e * 1.1)
            if r2 > 0.6:
                bolita(s, CX + math.cos(ang) * (9.0 + 28.0 * e * v), CY + math.sin(ang) * (6.0 + 15.0 * e * v) - e * 5.0, r2, POLVO)
        for ang, v, _r in motas[:6]:
            if e < 0.8:
                punto(a, CX + math.cos(ang) * 24.0 * e * v, CY - math.sin(e * math.pi * 1.2) * 14.0 * v, HIERRO[2], 2)
        out.append((s, a))
    return [out]


def _guardar_capa(nombre, sufijo, filas, indice):
    caja = None
    for fila in filas:
        for marcos in fila:
            b = Image.fromarray(marcos[indice], 'RGBA').getbbox()
            if b:
                caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
    if caja is None:
        return None
    w, h = caja[2] - caja[0], caja[3] - caja[1]
    hoja = Image.new('RGBA', (w * len(filas[0]), h * len(filas)), (0, 0, 0, 0))
    for j, fila in enumerate(filas):
        for i, marcos in enumerate(fila):
            hoja.paste(Image.fromarray(marcos[indice], 'RGBA').crop(caja), (i * w, j * h))
    hoja.save(os.path.join(ASSETS, '%s_%s.png' % (nombre, sufijo)), optimize=True)
    return [w, h, CX - caja[0], CY - caja[1]]


def hornear_todo():
    os.makedirs(ASSETS, exist_ok=True)
    # nombre: (filas de marcos, fps, en bucle)
    lista = {
        'pulso_carga': (_h_pulso_carga(80.0 / UNIDAD), 12.0, True), 'pulso_tiron': (_h_pulso_tiron(), 18.0, False),
        'mag_carga': (_h_mag_carga(), 12.0, True), 'mag_impacto': (_h_impacto(70.0 / UNIDAD, ROJO, 5), 14.0, False),
        'picado_impacto': (_h_impacto(30.0 / UNIDAD, VERDE, 0), 14.0, False), 'sombra': (_h_sombra(), 12.0, True),
        'estela_verde': (_h_estela_picado(VERDE, 'saeta'), 14.0, False), 'estela_roja': (_h_estela_picado(ROJO, 'errante'), 14.0, False),
        'polvo_subir': (_h_polvo_subir(), 12.0, False), 'polvo_paso': (_h_polvo_paso(), 12.0, False),
        'emb_carga': (_h_emb_carga(), 8.0, True), 'emb_sale': (_h_emb_sale(), 18.0, False), 'pasada': (_h_pasada(), 18.0, False),
        'coraza': (_h_coraza(), 12.0, False), 'elitros': (_h_elitros(), 12.0, False), 'caer': (_h_caer(), 14.0, False),
    }
    datos = {}
    for nombre, (filas, fps, bucle) in lista.items():
        datos[nombre] = {'n': len(filas[0]), 'filas': len(filas), 'fps': fps, 'bucle': bucle,
                         's': _guardar_capa(nombre, 's', filas, 0), 'a': _guardar_capa(nombre, 'a', filas, 1)}
        print(nombre, datos[nombre])
    texto = ('# GENERADO por tools/sprites_sdf/escarabajo_efectos_pixel.py --hornear: no tocar a mano. Las hojas de assets/sprites/efectos/:\n'
             '# n marcos x filas (1 o las 5 direcciones S, SE, E, NE, N); s = capa del suelo, a = capa de encima; [ancho, alto, origen x, origen y].\n'
             'extends RefCounted\n\nconst HOJAS := {\n\t"escarabajo": ' + json.dumps(datos) + ',\n}\n')
    with open(DATOS, 'w', encoding='utf-8', newline='\n') as f:
        f.write(texto)


if __name__ == '__main__':
    if '--hornear' in sys.argv:
        hornear_todo()
        sys.exit(0)
    os.makedirs(SALIDA, exist_ok=True)
    m1, t1 = pulso()
    m2, t2 = picado('saeta', False)
    m3, t3 = picado('errante', True)
    em = {d: embestida(d) for d in range(5)}
    pa = {d: pasada(d) for d in range(5)}
    co, tc = coraza()
    el, te = elitros()
    ca, tca = caida('saeta')
    filas = [('PULSO\ncarga (en bucle)', m1[0:6]), ('PULSO\nel tiron', [m1[12], m1[14], m1[15], m1[16], m1[18], m1[19]]),
             ('PICADO (saeta)\nsube, sombra, cae', [m2[3], m2[14], m2[21], m2[24], m2[25], m2[28]]),
             ('PICADO MAGNETICO\n(errante)', [m3[14], m3[19], m3[21], m3[24], m3[25], m3[28]]),
             *[('EMBESTIDA IMANTADA\nhacia el ' + NOM_DIR[d], [em[d][0][i] for i in (3, 8, 10, 11, 13, 15)]) for d in range(5)],
             *[('PASADA EN VUELO\nhacia el ' + NOM_DIR[d], elegir(pa[d][0])) for d in range(5)],
             ('CORAZA IMANTADA', elegir(co)), ('ELITROS CERRADOS', elegir(el)),
             ('DERRIBADO\nel polvo al caer', elegir(ca))]
    lamina(filas, os.path.join(SALIDA, 'escarabajo.png'))
    # Todos seguidos, en un solo gif, con una pausa entre uno y otro.
    todos, tiempos = [], []
    for marcos, ts in [(m1 + m1[:12] + m1[12:], t1 + t1[:12] + t1[12:]), (m2, t2), (m3, t3), em[1], em[2], em[3], pa[0], pa[1], pa[2], pa[3], pa[4], (co, tc), (el, te), (ca, tca)]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    gif(todos, tiempos, os.path.join(SALIDA, 'escarabajo.gif'), 2)
    print('hecho en', SALIDA)
