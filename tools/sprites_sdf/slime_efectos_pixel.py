#!/usr/bin/env python3
# ============================================================
#  slime_efectos_pixel.py -- LOS EFECTOS DEL SLIME (y sus mutantes brotado, punzante y brotado punzante) EN PIXEL ART
#  (04/11/2026, memoria efectos-a-pixel-art). La misma receta que la muestra aprobada del escarabajo
#  (escarabajo_efectos_pixel.py, de donde salen las piezas): rejilla de los sprites (1 celda = 1,15 de mundo), paleta
#  cerrada de 4 tonos, sin suavizado ni alfa parcial, lo que se desvanece a trama de 2 celdas. Los mismos efectos que
#  hoy pinta SlimeAire, pasados a pixel: basico (salpicon), Placaje (rastro + choque), Doble/Triple embate (coletazos),
#  Reventon (salto + charco con corona de gotas) y Expandir puas (cristales desde la piel).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/slime_efectos_pixel.py
# ============================================================
import json
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep

RAIZ = ep.RAIZ
SALIDA = ep.SALIDA
UNIDAD = ep.UNIDAD

# El slime es pequeño: lienzo propio (las piezas de ep leen estos globales al llamarlas).
W, H = 180, 150
ep.W, ep.H = W, H
YY, XX = np.mgrid[0:H, 0:W]
ep.YY, ep.XX = YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
ep.TRAMA = TRAMA

nuevo, poner, punto, disco = ep.nuevo, ep.poner, ep.punto, ep.disco
estrella, cometa_dir, componer = ep.estrella, ep.cometa_dir, ep.componer


# EL QUE RECIBE va SIEMPRE por debajo de lo que ya hay pintado en su capa: en el juego los efectos sobre un cuerpo van en
# Z_ENCIMA (por encima de todos los personajes) y se ven desde cualquier angulo; la lamina tiene que enseñar lo mismo
# (lo vio el, 04/11: el mordisco hacia el norte salia tapado por el objetivo).
def victima(a, x, y):
    tmp = nuevo()
    ep.victima(tmp, x, y)
    m = (tmp[:, :, 3] > 0) & (a[:, :, 3] == 0)
    a[m] = tmp[m]
DIRS, NOM_DIR = ep.DIRS, ep.NOM_DIR
SOMBRA = ep.SOMBRA

# EL GEL, del rojo en que estan pintadas sus hojas (ff2b2b); en el juego saldra del color de cada slime.
GEL = [(96, 12, 22), (200, 34, 44), (255, 104, 96), (255, 216, 200)]
GEL_BORDE = (46, 6, 14)
# Las puas: el cristal de las suyas.
CRISTAL = [(20, 58, 82), (52, 140, 172), (140, 232, 250), (236, 255, 255)]


# --- Sus hojas de verdad ---
_hojas = {}


def marco(var, anim, f, fila=0):
    clave = (var, anim)
    if clave not in _hojas:
        carpeta = os.path.join(RAIZ, 'assets/sprites/enemigos/slime_sdf_%s' % var)
        with open(os.path.join(carpeta, 'hojas.json'), encoding='utf-8') as fh:
            lw, lh = json.load(fh)['lienzo']
        _hojas[clave] = (Image.open(os.path.join(carpeta, '%s.png' % anim)).convert('RGBA'), lw, lh)
    h, lw, lh = _hojas[clave]
    n = h.size[0] // lw
    return h.crop(((f % n) * lw, fila * lh, (f % n) * lw + lw, fila * lh + lh))


# Los pies en su lienzo: SlimeSprites._lienzo (LIENZO_ARRIBA 1,12 de 1,52 del alto).
def pies(spr):
    w, h = spr.size
    return w // 2, int(round(h * 1.12 / 1.52))


def pegar(img, spr, x, y, alto=0):
    ox, oy = pies(spr)
    img.paste(spr, (int(round(x)) - ox, int(round(y - alto)) - oy), spr)


def escena(suelo, cuerpos, aire):
    """cuerpos = [(spr, x, y, alto)]; sus sombras van al suelo cuando estan en el aire."""
    img = ep.fondo()
    for c in suelo:
        img.alpha_composite(Image.fromarray(c, 'RGBA'))
    for spr, x, y, alto in sorted(cuerpos, key=lambda c: c[2]):
        pegar(img, spr, x, y, alto)
    for c in aire:
        img.alpha_composite(Image.fromarray(c, 'RGBA'))
    return img


def sombra(a, x, y, r):
    m = ((XX - x) / r) ** 2 + ((YY - y) / (r * 0.5)) ** 2 <= 1.0
    poner(a, m, SOMBRA)


# --- LAS PIEZAS DEL GEL ---
# Una gota en el aire: borde oscuro, cuerpo, luz arriba a la izquierda y un brillo de una celda. Nunca una canica lisa.
def gota(a, x, y, r, pal=None, borde=None):
    pal, borde = pal or GEL, borde or GEL_BORDE
    r *= 0.75
    if r < 1.2:
        punto(a, x - 1, y - 1, borde, 2)
        punto(a, x - 1, y - 1, pal[1], 1)
        return
    disco(a, x, y, r + 0.6, borde)
    disco(a, x, y, r, pal[1])
    disco(a, x - r * 0.25, y - r * 0.3, r * 0.6, pal[2])
    punto(a, x - r * 0.45, y - r * 0.5, pal[3], 1 if r < 3 else 2)


# EL CHARCO de gel en el suelo: contorno blando (no un circulo), labio oscuro, cuerpo, el brillo como una media luna
# arriba a la izquierda y un par de destellos. 'vivo' 1 = recien caido; al secarse se deshace a trama desde dentro.
def charco(a, cx, cy, r, sem, vivo=1.0, pal=None, borde_col=None):
    pal, borde_col = pal or GEL, borde_col or GEL_BORDE
    if r < 1.0:
        return
    if r < 3.0:
        borde_col = pal[0]   # las manchitas: sin el labio negro (salian puntos negros)
    d = np.hypot(XX - cx, YY - cy)
    ang = np.arctan2(YY - cy, XX - cx)
    rr = r * (1.0 + 0.13 * np.sin(ang * 5.0 + sem) + 0.07 * np.sin(ang * 9.0 + sem * 2.3))
    dentro = d < rr
    borde = rr - d
    queda = TRAMA < vivo * 1.15 - (1.0 - np.clip(borde / max(r, 1.0), 0, 1)) * 0.25 * (1.0 - vivo)
    poner(a, dentro & queda, borde_col)
    poner(a, dentro & (borde > 1.2) & queda, pal[0])
    poner(a, dentro & (borde > 2.2) & queda & (TRAMA < 0.25 + vivo * 0.75), pal[1])
    # el brillo: media luna clara en el borde de arriba a la izquierda
    d2 = np.hypot(XX - (cx + r * 0.18), YY - (cy + r * 0.22))
    luz = dentro & (borde > 1.5) & (d2 > r * 0.82) & ((XX - cx) + (YY - cy) < 0) & queda
    poner(a, luz & (vivo > 0.35), pal[2])
    if vivo > 0.55 and r > 4:
        punto(a, cx - r * 0.45, cy - r * 0.3, pal[3], 2)
        punto(a, cx + r * 0.25, cy - r * 0.55, pal[3], 1)


def seco(edad, queda=6, dura=6):
    """De 1 a 0: entero durante 'queda' marcos, luego se seca en 'dura'."""
    return 1.0 if edad < queda else max(0.0, 1.0 - (edad - queda) / float(dura))


# Una gota que vuela de p0 a p1 con su salto: la cabeza (gota) y la cola en cometa; al caer queda su manchita.
class Gotas:
    def __init__(self, n, semilla, r_min, r_max, abanico=None, sube=(10.0, 22.0), tam=(1.6, 2.6), pal=None, borde=None):
        self.pal, self.borde = pal or GEL, borde or GEL_BORDE
        rnd = random.Random(semilla)
        self.g = []
        for i in range(n):
            if abanico is None:
                ang = (i + rnd.uniform(0.0, 0.8)) / n * math.tau
            else:
                ang = abanico[0] + rnd.uniform(-abanico[1], abanico[1])
            self.g.append((ang, rnd.uniform(r_min, r_max), rnd.uniform(*sube), rnd.uniform(*tam), rnd.uniform(0.0, 0.18)))

    def pintar(self, s, a, cx, cy, u, r0=0.0, dur=1.0, edad_suelo=0):
        """u de 0 a 1 = el vuelo; despues, manchas en el suelo que se secan (edad_suelo en marcos)."""
        for ang, d, sube, tam, t0 in self.g:
            k = (u - t0) / (dur - t0)
            dx, dy = math.cos(ang), math.sin(ang)
            if k <= 0.0:
                continue
            if k >= 1.0:
                vivo = seco(edad_suelo, 3, 5)
                if vivo > 0:
                    charco(s, cx + dx * d, cy + dy * d, tam * 1.3, ang * 7, vivo, self.pal, self.borde)
                continue
            dist = r0 + (d - r0) * k
            alto = sube * 4.0 * k * (1.0 - k)
            x, y = cx + dx * dist, cy + dy * dist - alto
            k2 = max(0.0, k - 0.16)
            xa, ya = cx + dx * (r0 + (d - r0) * k2), cy + dy * (r0 + (d - r0) * k2) - sube * 4.0 * k2 * (1.0 - k2)
            vx, vy = x - xa, y - ya
            n = math.hypot(vx, vy)
            if n > 1.5:
                cometa_dir(a, x, y, vx / n, vy / n, min(n * 1.3, 10.0), 0, self.pal)
            gota(a, x, y, tam, self.pal, self.borde)


# --- EL BASICO: salpicon de gel en el pecho del que recibe, hacia atras de donde viene el golpe ---
def basico(fila, var='s100'):
    dx, dy = DIRS[fila]
    A = (W * 0.5 - dx * 22, H * 0.62 - dy * 18)
    V = (A[0] + dx * 36, A[1] + dy * 34)
    gotas = Gotas(8, 11 + fila, 10.0, 24.0, (math.atan2(dy, dx), 0.75), sube=(6.0, 14.0), tam=(1.4, 2.4))
    m, t = [], []
    toca = 3
    for f in range(12):
        s, a = nuevo(), nuevo()
        delante = a
        pecho = (V[0], V[1] - 10)
        if f >= toca:
            e = f - toca
            if e < 3:
                gota(delante, pecho[0], pecho[1], (3.0, 4.6, 3.4)[e])
            if e == 0:
                estrella(a, pecho[0], pecho[1], 9, GEL)
            elif e == 1:
                estrella(a, pecho[0], pecho[1], 6, GEL)
            gotas.pintar(s, a, pecho[0], V[1], min(1.0, e / 5.0), 2.0, 1.0, e - 5)
        victima(s if dy >= 0 else a, *V)
        cuerpos = [(marco(var, 'embestida', min(f, 7), fila), A[0], A[1], 0)]
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 12)
    return m, t


# EL RASTRO de baba: una franja seguida por donde ha pasado, con los bordes blandos, labio oscuro, cuerpo con trama y
# una veta de luz a un lado; nace estrecho detras y se seca empezando por lo mas viejo.
def rastro(a, A, dx, dy, hecho, media, f, corre, largo, sem):
    if hecho < 1.0:
        return
    s_ = (XX - A[0]) * dx + (YY - A[1]) * dy
    l_ = (XX - A[0]) * (-dy) + (YY - A[1]) * dx
    # Las dos PUNTAS redondas (lo vio el, 04/11: el final se cortaba recto y al recular el cuerpo se veia el corte):
    # cada celda mira al punto mas cercano del eje ya pintado, asi la franja acaba en media gota.
    sc = np.clip(s_, 0.0, hecho)
    u = np.clip(sc / max(largo, 1.0), 0.0, 1.0)
    ancho = media * (0.45 + 0.55 * np.clip(sc / 10.0, 0, 1)) * (1.0 + 0.12 * np.sin(sc * 0.2 + sem) + 0.07 * np.sin(sc * 0.47 + sem * 2))
    d = np.hypot(s_ - sc, l_)
    dentro = d < ancho
    borde = ancho - d
    edad = f - u * corre
    vivo = np.clip(1.0 - (edad - 8.0) / 6.0, 0.0, 1.0)
    queda = TRAMA < vivo * 1.15
    poner(a, dentro & queda, GEL_BORDE)
    poner(a, dentro & queda & (borde > 1.1), GEL[0])
    poner(a, dentro & queda & (borde > 2.1) & ((borde < 4.0) | (TRAMA < 0.55 * vivo)), GEL[1])
    poner(a, dentro & queda & (borde > 1.5) & (borde < 3.0) & (l_ < 0) & (vivo > 0.4), GEL[2])
    brillo = dentro & (vivo > 0.6) & (np.abs(l_ + ancho * 0.35) < 0.8) & (np.sin(s_ * 0.5 + sem) > 0.6)
    poner(a, brillo, GEL[3])


# --- EL PLACAJE: se lanza por su linea dejando el RASTRO de baba y al chocar salpica hacia delante ---
def placaje(fila, largo_mundo=40.0, ancho_mundo=16.0, var='s100'):
    dx, dy = DIRS[fila]
    largo, ancho = largo_mundo / UNIDAD, ancho_mundo / UNIDAD
    A = (W * 0.5 - dx * largo * 0.55, H * 0.6 - dy * largo * 0.5)
    # el cuerpo se para con su borde en el que recibe (radio del slime: su lienzo)
    rad = marco(var, 'embestida', 0, fila).size[0] * 0.3
    fin = (A[0] + dx * largo, A[1] + dy * largo)
    V = (fin[0] + dx * (rad + 4), fin[1] + dy * (rad + 4))
    choque = Gotas(9, 21 + fila, 8.0, 20.0, (math.atan2(dy, dx), 1.1), sube=(8.0, 16.0))
    m, t = [], []
    corre = 5
    for f in range(18):
        s, a = nuevo(), nuevo()
        u = min(1.0, f / corre)
        x, y = A[0] + dx * largo * u, A[1] + dy * largo * u
        rastro(s, A, dx, dy, largo * u, min(ancho * 0.5, rad * 0.75), f, corre, largo, fila)
        delante = a
        if f >= corre:
            e = f - corre
            gx, gy = fin[0] + dx * (rad + 1), fin[1] + dy * (rad + 1)
            if e < 2:
                estrella(a, gx, gy - 9, (11, 7)[e], GEL)
            choque.pintar(s, delante, gx, gy, min(1.0, e / 5.0), 2.0, 1.0, e - 5)
        victima(s if dy >= 0 else a, *V)
        vuelve = min(1.0, max(0.0, (f - corre - 3) / 5.0))
        x, y = x - dx * largo * 0.35 * vuelve, y - dy * largo * 0.35 * vuelve
        cuerpos = [(marco(var, 'embestida', min(f, 7), fila), x, y, 0)]
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 14)
    return m, t


# --- EL EMBATE: coletazos de gel, la ida y vuelta del Segar: una MEDIA LUNA RELLENA que barre el cono a la altura de
# su cuerpo, con el filo vivo delante y detras el gel que se oscurece y se deshace; de la punta salen gotas ---
def coletazo(a, cx, cy, eje, radio, frente, tras, sentido, grueso, pal=None, borde_col=None):
    pal, borde_col = pal or GEL, borde_col or GEL_BORDE
    ang = np.arctan2(YY - cy, XX - cx)
    rel = (ang - eje + np.pi) % (2 * np.pi) - np.pi
    b = (frente - rel) * sentido                       # cuanto va por detras del filo
    d = np.hypot(XX - cx, YY - cy)
    u = np.clip(b / tras, 0.0, 1.0)
    # gorda cerca del filo y afilada en las dos puntas: una media luna, no una raya
    w = grueso * (1.0 - u) ** 0.55 * np.clip(u * 7.0 + 0.3, 0.0, 1.0)
    dentro = (b >= 0.0) & (b < tras) & (np.abs(d - radio) < w * 0.5 + 0.5)
    exterior = (d - radio) > w * 0.1
    poner(a, dentro & (u >= 0.55) & (TRAMA < (1.0 - u) * 2.0), pal[0])
    poner(a, dentro & (u >= 0.25) & (u < 0.55), pal[1])
    poner(a, dentro & (u >= 0.25) & (u < 0.55) & exterior, pal[2])
    poner(a, dentro & (u < 0.25), pal[2])
    poner(a, dentro & (u < 0.1), pal[3])
    poner(a, dentro & (np.abs(d - radio) >= w * 0.5 - 0.6) & (u >= 0.1) & (u < 0.55) & ~exterior, borde_col)


def embate(fila, golpes=2, apertura=100.0, var='s100'):
    dx, dy = DIRS[fila]
    A = (W * 0.5 - dx * 10, H * 0.6 - dy * 8)
    eje = math.atan2(dy, dx)
    mitad = math.radians(apertura) * 0.5
    R = 35.0 / UNIDAD * 0.85
    alto = 7
    vict = [(A[0] + math.cos(eje + k) * 36, A[1] + math.sin(eje + k) * 36) for k in (-0.5, 0.4)]
    m, t = [], []
    pasa = 5
    total = golpes * pasa + 5
    for f in range(total):
        s, a = nuevo(), nuevo()
        g, e = divmod(f, pasa)
        sentido = 1.0 if g % 2 == 0 else -1.0
        capa = a if dy >= -0.2 else s
        if g < golpes:
            u = (e + 1) / pasa
            frente = (-mitad + 2 * mitad * u) * sentido
            coletazo(capa, A[0], A[1] - alto, eje, R, frente, 1.9 * min(1.0, u * 1.6), sentido, 12.0)
            # de la punta salen gotas despedidas
            fx = A[0] + math.cos(eje + frente) * R
            fy = A[1] - alto + math.sin(eje + frente) * R
            tg = (-math.sin(eje + frente) * sentido, math.cos(eje + frente) * sentido)
            for k in range(2):
                gota(a, fx + tg[0] * (4 + 5 * k) + math.cos(eje + frente) * 3 * k, fy + tg[1] * (4 + 5 * k) + k * 2, 1.4 - 0.3 * k)
        # lo que queda del ultimo pase: la cola que se deshace
        if g >= golpes and e < 3:
            sentido = 1.0 if (golpes - 1) % 2 == 0 else -1.0
            coletazo(capa, A[0], A[1] - alto, eje, R, mitad * sentido, 1.9 * (1.0 - e / 3.0), sentido, 12.0 * (1.0 - e / 4.0))
        for v in vict:
            victima(s if v[1] < A[1] else a, *v)
        cuerpos = [(marco(var, 'embestida', min(f % pasa + 2, 7), fila), A[0], A[1], 0)]
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 16)
    return m, t


# --- EL REVENTON: se hincha, salta y cae reventando en un CHARCO con la corona de gotas ---
def reventon(fila, radio_mundo=35.0, var='s100'):
    dx, dy = DIRS[fila]
    rango = 70.0 / UNIDAD
    A = (W * 0.5 - dx * rango * 0.5, H * 0.58 - dy * rango * 0.45)
    B = (A[0] + dx * rango, A[1] + dy * rango)
    R = radio_mundo / UNIDAD
    corona = Gotas(18, 3 + fila, R * 0.55, R * 1.02, sube=(10.0, 20.0), tam=(1.2, 2.1))
    rnd = random.Random(17)
    manchas = [(rnd.uniform(0, math.tau), rnd.uniform(0.5, 1.0), rnd.uniform(0.1, 0.18) * R) for _ in range(7)]
    vict = [(B[0] + R * 0.75, B[1] - R * 0.3), (B[0] - R * 0.7, B[1] + R * 0.45)]
    m, t = [], []
    carga, vuelo = 6, 6
    for f in range(carga + vuelo + 16):
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
            abre = 1.0 - (1.0 - min(1.0, (e + 1) / 3.0)) ** 2
            vivo = seco(e, 8, 7)
            charco(s, B[0], B[1], R * 0.62 * abre, 1.0, vivo)
            for ang, uu, r in manchas:
                charco(s, B[0] + math.cos(ang) * uu * R * 0.85 * abre, B[1] + math.sin(ang) * uu * R * 0.85 * abre, r * abre, ang, vivo * 0.95)
            corona.pintar(s, a, B[0], B[1], min(1.0, e / 6.0), R * 0.45, 1.0, e - 6)
            if e < 3:
                estrella(a, B[0], B[1] - 4, (14, 22, 10)[e], GEL)
        for v in vict:
            victima(s if v[1] < B[1] else a, *v)
        cuerpos = [(marco(var, anim, fr, fila), x, y, alto)]
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 14)
    return m, t


# --- EXPANDIR PUAS: se eriza y le salen de la PIEL nueve cristales de dos puntas, grandes, hasta el borde; se clavan
# un momento y se deshacen ---
def cristal(a, x, y, dx, dy, largo, ancho, pal=None):
    """Pua de dos puntas: el centro en (x, y) mirando a (dx, dy). Luz por un lado, sombra por el otro, borde oscuro."""
    pal = pal or CRISTAL
    px, py = -dy, dx
    for i in range(int(largo) + 1):
        u = i / max(largo, 1.0)
        media = ancho * math.sin(math.pi * u) ** 0.8
        cx, cy = x + dx * (i - largo * 0.5), y + dy * (i - largo * 0.5)
        for j in range(-int(round(media + 1)), int(round(media + 1)) + 1):
            qx, qy = cx + px * j * 0.9, cy + py * j * 0.9
            if abs(j) > media:
                punto(a, qx, qy, pal[0])
            elif j <= 0:
                punto(a, qx, qy, pal[3] if (abs(j) < 0.7 and 0.2 < u < 0.7) else pal[2])
            else:
                punto(a, qx, qy, pal[1])


def puas(var='pun120', radio_mundo=56.0):
    A = (W * 0.5, H * 0.56)
    R = radio_mundo / UNIDAD
    rnd = random.Random(8)
    giro = rnd.uniform(0, math.tau)
    lista = [(giro + math.tau * (i + rnd.uniform(-0.18, 0.18)) / 9.0, rnd.uniform(0.86, 1.0), rnd.uniform(11.0, 14.0),
              rnd.uniform(2.2, 2.8), rnd.uniform(0.0, 0.25)) for i in range(9)]
    vict = [(A[0] + 36, A[1] + 14), (A[0] - 30, A[1] - 22), (A[0] - 8, A[1] + 40)]
    m, t = [], []
    carga = 6
    piel = 13.0
    for f in range(carga + 16):
        s, a = nuevo(), nuevo()
        if f < carga:
            anim, fr = 'erizar', min(f + 2, 7)
        else:
            e = f - carga
            anim, fr = 'expandir', min(e, 7)
            u = min(1.0, (e + 1) / 3.0)
            queda = seco(e, 7, 6)
            for ang, uu, largo, ancho, t0 in lista:
                dxx, dyy = math.cos(ang), math.sin(ang)
                d = piel + (R * uu - piel) * (1.0 - (1.0 - u) ** 2)
                alto = 9.0 * (1.0 - u) + 2.0
                x, y = A[0] + dxx * d, A[1] + dyy * d - alto
                capa = a if dyy > -0.3 else s
                if queda >= 1.0:
                    cristal(capa, x, y, dxx, dyy, largo, ancho)
                elif queda > 0.0:
                    # se deshace a trama de bloques, de la punta hacia dentro
                    tmp = nuevo()
                    cristal(tmp, x, y, dxx, dyy, largo, ancho)
                    mascara = (tmp[:, :, 3] > 0) & (TRAMA < queda)
                    capa[mascara] = tmp[mascara]
            if e < 3:
                # el polvo de cristal que levanta al clavarse
                for ang, uu, _l, _w, _t in lista:
                    if e >= 1:
                        ep.bolita(s, A[0] + math.cos(ang) * R * uu, A[1] + math.sin(ang) * R * uu, 3.0 - e, ep.POLVO)
        for v in vict:
            victima(s if v[1] < A[1] else a, *v)
        m.append(escena([s], [(marco(var, anim, fr, 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def elegir(m, idx):
    return [m[min(i, len(m) - 1)] for i in idx]


def lamina(filas, ruta, zoom=3):
    ancho_rotulo = 170
    columnas = max(len(m) for _, m in filas)
    img = Image.new('RGB', (ancho_rotulo + columnas * (W * zoom + 4), len(filas) * (H * zoom + 8)), (24, 22, 26))
    from PIL import ImageDraw
    pinta = ImageDraw.Draw(img)
    for j, (nombre, marcos) in enumerate(filas):
        y = j * (H * zoom + 8)
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, mm in enumerate(marcos):
            img.paste(mm.convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST), (ancho_rotulo + i * (W * zoom + 4), y))
    img.save(ruta)


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: basico(d) for d in (1, 4)}
    pv = {d: placaje(d) for d in range(5)}
    pb, tpb = placaje(2, 70.0, 41.0, 'mut120')
    de = {d: embate(d) for d in range(5)}
    tr, ttr = embate(1, 3, 120.0, 'mut120')
    rv, trv = reventon(1)
    rp, trp = reventon(1, 46.0, 'evo2')
    pu, tpu = puas()
    filas = [
        *[('BASICO (salpicon)\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        *[('PLACAJE VISCOSO\nhacia el ' + NOM_DIR[d], elegir(pv[d][0], (1, 3, 5, 6, 8, 14))) for d in range(5)],
        ('PLACAJE BABOSO\n(y espinoso: igual)\nbrotado, hacia el ESTE', elegir(pb, (1, 3, 5, 6, 8, 14))),
        *[('DOBLE EMBATE\nhacia el ' + NOM_DIR[d], elegir(de[d][0], (1, 3, 4, 7, 9, 12))) for d in range(5)],
        ('TRIPLE EMBATE\nbrotado, hacia el SURESTE', elegir(tr, (2, 4, 7, 9, 12, 16))),
        ('REVENTON\nse hincha, salta y revienta', elegir(rv, (3, 8, 12, 14, 17, 25))),
        ('REVENTON ESPINOSO\n(y pegajoso: igual)\nbrotado punzante', elegir(rp, (3, 8, 12, 14, 17, 25))),
        ('EXPANDIR PUAS\npunzante', elegir(pu, (3, 6, 7, 9, 13, 18))),
    ]
    lamina(filas, os.path.join(SALIDA, 'slime.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], ba[4], pv[1], pv[2], pv[4], (pb, tpb), de[0], de[2], de[4], (tr, ttr), (rv, trv), (rp, trp), (pu, tpu)]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'slime.gif'), 3)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
