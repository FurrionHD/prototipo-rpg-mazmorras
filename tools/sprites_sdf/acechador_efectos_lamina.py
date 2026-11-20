#!/usr/bin/env python3
# ============================================================
#  acechador_efectos_lamina.py -- LOS EFECTOS DEL CAZADOR LUNAR SOBRE SUS SPRITES DE VERDAD (20/11/2026, memoria
#  acechador-mutante). La luna del cielo ya esta elegida (acechador_efectos_pixel.luna_viva); aqui lo demas, DOS VERSIONES
#  de cada uno para que elija el jefe:
#    MARCA DE LA LUNA  (su encargo: "se tiene que ver una luna creciente sobre el personaje con la marca")
#      A  la creciente y la estrella del icono, flotando sobre su cabeza con un brillito
#      B  una creciente mas grande con su resplandor y motas que la rodean
#    MEDIA LUNA        (cono ancho y corto delante, 150 grados, 64 de radio: "un zarpazo que deja una luna creciente")
#      A  HOJA DE LUNA  una media luna de luz que sale del zarpazo, se abre hasta el borde y se deshace en motas
#      B  LUNA DE COLORES  la misma con los remolinos pastel de la foto de referencia por dentro
#    CAIDA DE LA LUNA  (circulo de 48 donde apunte; el haz cae DESDE LA LUNA DEL CIELO)
#      A  COLUMNA DE LUZ  un haz ancho y transparente que baja, golpea y deja un anillo de luz
#      B  LA LUNA CAE    una lunita baja del cielo y revienta en crecientes
#  Transparencia de verdad (alfa por niveles de 1/8). Solo la lamina y los gif: todavia no van al juego.
#    python tools/sprites_sdf/acechador_efectos_lamina.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

import slime_efectos_pixel as sl
import escarabajo_efectos_pixel as ep
import rata_efectos_pixel as rt

W, H = 260, 200
YY, XX = np.mgrid[0:H, 0:W]
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
for _m in (ep, sl, rt):
    _m.W, _m.H, _m.YY, _m.XX, _m.TRAMA = W, H, YY, XX, TRAMA

from slime_efectos_pixel import UNIDAD, nuevo, victima  # noqa: E402
from rata_efectos_pixel import marco, escena  # noqa: E402

CAZ = 'acechador_sdf_cazador'
ESTE = 2
SALIDA = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'acechador')
LUNA = [(92, 108, 170), (150, 168, 222), (210, 222, 252), (246, 250, 255)]
PASTEL = [(150, 190, 255), (190, 160, 245), (250, 180, 220), (140, 230, 225)]
ESTRELLA = (190, 170, 240)


def mezcla(a, m, col, alfa):
    """'col' con 'alfa' (0..1, escalar o mapa) encima de lo que haya: alfa de verdad por niveles de 1/8."""
    al = np.round(np.clip(alfa, 0, 1) * 8) / 8
    if np.isscalar(al) or np.ndim(al) == 0:
        al = np.full((H, W), float(al))
    m = m & (al > 0)
    base = a[..., :3].astype(float)
    ab = a[..., 3].astype(float) / 255.0
    nuevo_al = al + ab * (1 - al)
    rgb = (np.array(col, float) * al[..., None] + base * (ab * (1 - al))[..., None]) / np.maximum(nuevo_al, 1e-6)[..., None]
    a[m, :3] = rgb[m].astype(np.uint8)
    a[m, 3] = (nuevo_al[m] * 255).astype(np.uint8)


def disco_m(cx, cy, r):
    return (XX - cx) ** 2 + (YY - cy) ** 2 <= r * r


def creciente_m(cx, cy, r, abre=0.62, giro=0.0):
    """Una creciente: el disco menos otro corrido (hacia 'giro' radianes)."""
    ox, oy = math.cos(giro) * r * abre, math.sin(giro) * r * abre
    return disco_m(cx, cy, r) & ~disco_m(cx - ox, cy - oy, r)


# ------------------------------------------------------------------ LA MARCA
def marca_a(a, hx, hy, f):
    dy = round(1.2 * math.sin(f / 16 * math.tau))
    cx, cy = hx, hy - 11 + dy
    mezcla(a, disco_m(cx, cy, 7), (170, 190, 255), 0.25 + 0.1 * math.sin(f / 16 * math.tau))
    m = creciente_m(cx, cy, 4.6, 0.55, 0.0)
    a[m] = (*LUNA[3], 255)
    a[m & ~creciente_m(cx, cy, 3.6, 0.5, 0.0)] = (*LUNA[2], 255)
    if (f // 4) % 2 == 0:
        a[int(cy), int(cx + 4)] = (*ESTRELLA, 255)
        for dx, dy2 in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            a[int(cy + dy2), int(cx + 4 + dx)] = (*ESTRELLA, 255)


def marca_b(a, hx, hy, f):
    dy = round(1.5 * math.sin(f / 16 * math.tau))
    cx, cy = hx, hy - 14 + dy
    dist = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2)
    mezcla(a, dist < 12, (170, 190, 255), np.clip(1 - dist / 12, 0, 1) * 0.5)
    m = creciente_m(cx, cy, 6.5, 0.55, 0.0)
    a[m] = (*LUNA[2], 255)
    a[m & creciente_m(cx - 1, cy - 1, 5.0, 0.6, 0.0)] = (*LUNA[3], 255)
    for k in range(5):
        ang = f / 16 * math.tau * 0.5 + k / 5 * math.tau
        x, y = cx + math.cos(ang) * 10, cy + math.sin(ang) * 6
        if (k + f // 3) % 2 == 0:
            a[int(y), int(x)] = (*((255, 255, 255) if k % 2 else ESTRELLA), 255)


# ------------------------------------------------------------------ LA MEDIA LUNA
def media_luna(a, s, bx, by, f, version, eje=0.0):
    """La hoja de luna en arco de 150 grados delante (hacia el ESTE): sale del zarpazo (f 4), se abre hasta el borde (R) y
    se deshace en motas."""
    R = 64.0 / UNIDAD
    e = f - 4
    if e < 0:
        return
    t = min(1.0, e / 5.0)
    r = 8 + (R - 8) * (1 - (1 - t) ** 2)
    vida = 1.0 if e < 6 else max(0.0, 1.0 - (e - 6) / 4.0)
    if vida <= 0:
        return
    dist = np.sqrt((XX - bx) ** 2 + ((YY - by) / 0.8) ** 2)
    ang = (np.arctan2((YY - by) / 0.8, XX - bx) - eje + math.pi) % math.tau - math.pi   # respecto a hacia donde ataca
    mitad = math.radians(75)
    dentro = np.abs(ang) <= mitad
    # el grosor: gruesa en el medio, afilada en las puntas (forma de creciente)
    u = np.clip(1 - np.abs(ang) / mitad, 0, 1)
    grueso = 1.0 + 6.0 * u ** 0.8
    banda = dentro & (dist <= r) & (dist >= r - grueso)
    if version == 'A':
        mezcla(a, banda, LUNA[3], vida)
        mezcla(a, banda & (dist < r - grueso * 0.5), LUNA[2], vida)
    else:
        onda = np.sin(ang * 6 + dist * 0.25 + e * 0.6)
        idx = np.clip(((onda + 1) / 2 * 4).astype(int), 0, 3)
        for k in range(4):
            mezcla(a, banda & (idx == k), PASTEL[k], vida)
        mezcla(a, banda & (dist > r - 1.5), (250, 252, 255), vida)
    # la estela clara por detras de la hoja
    estela = dentro & (dist < r - grueso) & (dist > r - grueso - 10)
    mezcla(a, estela, (170, 190, 255), np.clip(1 - (r - grueso - dist) / 10, 0, 1) * 0.35 * vida)
    if e >= 6:
        rnd = random.Random(5)
        for _ in range(16):
            an = rnd.uniform(-mitad, mitad) + eje
            rr = rnd.uniform(R * 0.6, R)
            x, y = bx + math.cos(an) * rr, by + math.sin(an) * rr * 0.8 - (e - 6) * 1.5
            if rnd.random() < vida:
                a[int(y), int(x)] = (*(LUNA[3] if version == 'A' else PASTEL[rnd.randrange(4)]), 255)


# ------------------------------------------------------------------ LA CAIDA DE LA LUNA
def caida(a, s, tx, ty, f, version):
    """El haz desde la luna del cielo sobre el circulo de 48 (tx, ty). f 0..5 aviso (se enciende el circulo en el suelo),
    6.. cae y golpea."""
    R = 48.0 / UNIDAD
    suelo = ((XX - tx) / R) ** 2 + ((YY - ty) / (R * 0.8)) ** 2 <= 1
    borde = suelo & ~(((XX - tx) / (R - 1.5)) ** 2 + ((YY - ty) / ((R - 1.5) * 0.8)) ** 2 <= 1)
    aviso = min(1.0, f / 5.0)
    mezcla(s, suelo, (90, 110, 190), 0.18 * aviso)
    mezcla(s, borde, (200, 214, 255), 0.6 * aviso)
    e = f - 6
    if e < 0:
        return
    if version == 'A':
        vida = 1.0 if e < 5 else max(0.0, 1 - (e - 5) / 5)
        ancho = R * (0.55 + 0.35 * min(1, e / 2))
        col = (np.abs(XX - tx) < ancho) & (YY < ty + 2)
        alfa = np.clip(1 - np.abs(XX - tx) / ancho, 0, 1) ** 0.7 * 0.55 * vida
        mezcla(a, col, (190, 206, 255), alfa)
        mezcla(a, col & (np.abs(XX - tx) < ancho * 0.25), (246, 250, 255), 0.6 * vida)
        # el golpe: anillo que se abre por el suelo
        rr = R * (0.4 + 0.7 * min(1, e / 4))
        anillo = (((XX - tx) / rr) ** 2 + ((YY - ty) / (rr * 0.8)) ** 2 <= 1) & \
                 ~(((XX - tx) / (rr - 2.5)) ** 2 + ((YY - ty) / ((rr - 2.5) * 0.8)) ** 2 <= 1)
        mezcla(s, anillo, (230, 238, 255), 0.8 * vida)
    else:
        if e < 4:
            cy = ty - 90 + e * 22
            m = disco_m(tx, cy, 7)
            a[m] = (*LUNA[2], 255)
            a[m & disco_m(tx - 2, cy - 2, 4)] = (*LUNA[3], 255)
            mezcla(a, (np.abs(XX - tx) < 5) & (YY < cy) & (YY > cy - 30), (190, 206, 255),
                   np.clip(1 - (cy - YY) / 30, 0, 1) * 0.5)
        else:
            k = e - 4
            vida = max(0.0, 1 - k / 7)
            for i in range(6):
                an = i / 6 * math.tau + 0.3
                d = 4 + k * 5
                x, y = tx + math.cos(an) * d, ty + math.sin(an) * d * 0.8 - 6
                m = creciente_m(x, y, 4.0, 0.55, an)
                mezcla(a, m, LUNA[3], vida)
            dist = np.sqrt((XX - tx) ** 2 + ((YY - ty) / 0.8) ** 2)
            mezcla(s, dist < R * min(1, 0.3 + k / 4), (200, 214, 255), np.clip(1 - dist / R, 0, 1) * 0.5 * vida)


# ------------------------------------------------------------------ LA CAIDA C, LA SUYA (20/11)
# "Literal cae la luna que esta en la batalla (la que ilumina), cae sobre los personajes haciendo daño y luego vuelve
# lentamente flotando a su lugar". La luna es la aprobada (acechador_efectos_pixel.luna_viva) en su sitio del cielo:
#   f 0-5    AVISO: mientras aulla, la luna tiembla y el circulo se enciende en el suelo
#   f 6-9    CAE acelerando, con una estela de luz detras
#   f 10-15  EL GOLPE: destello, anillo que se abre por el suelo y esquirlas de luna; rebota un poco
#   f 16-37  VUELVE flotando despacio a su sitio (frena al llegar), soltando motas
import acechador_efectos_pixel as lv  # noqa: E402

CIELO = (130, 34)
N_CAIDA = 38


def _luna_en(a, x, y, f):
    lv.W, lv.H, lv.XX, lv.YY = W, H, XX, YY
    lv.TRAMA = lv.BAYER[YY % 4, XX % 4]
    lv.CX, lv.CY = int(round(x)), int(round(y))
    lv.luna_viva(a, 'llena', f)


def _ease_in(t):
    return t * t * t


def _ease_out(t):
    return 1 - (1 - t) ** 3


def caida_luna(a, s, tx, ty, f):
    R = 48.0 / UNIDAD
    suelo = ((XX - tx) / R) ** 2 + ((YY - ty) / (R * 0.8)) ** 2 <= 1
    borde = suelo & ~(((XX - tx) / (R - 1.5)) ** 2 + ((YY - ty) / ((R - 1.5) * 0.8)) ** 2 <= 1)
    destino = (tx, ty - 14)   # se planta encima de ellos
    if f <= 5:
        aviso = f / 5.0
        mezcla(s, suelo, (90, 110, 190), 0.18 * aviso)
        mezcla(s, borde, (200, 214, 255), 0.6 * aviso)
        tiembla = (1 if f % 2 else -1) * (1 if f >= 2 else 0)
        _luna_en(a, CIELO[0] + tiembla, CIELO[1], f)
        return
    if f <= 9:
        t = _ease_in((f - 5) / 4.0)
        x = CIELO[0] + (destino[0] - CIELO[0]) * t
        y = CIELO[1] + (destino[1] - CIELO[1]) * t
        mezcla(s, suelo, (90, 110, 190), 0.25)
        mezcla(s, borde, (220, 230, 255), 0.8)
        # la estela: de donde viene, ancha y transparente
        dx, dy = x - CIELO[0], y - CIELO[1]
        largo = max(1.0, math.hypot(dx, dy))
        ux, uy = dx / largo, dy / largo
        proy = (XX - x) * -ux + (YY - y) * -uy
        lado = np.abs((XX - x) * -uy + (YY - y) * ux)
        estela = (proy > 0) & (proy < min(largo, 60)) & (lado < 14 * (1 - proy / 70))
        mezcla(a, estela, (190, 206, 255), np.clip(1 - proy / 60, 0, 1) * 0.45)
        _luna_en(a, x, y, f)
        return
    e = f - 10
    if e <= 5:
        # EL GOLPE
        vida = 1 - e / 6.0
        dist = np.sqrt((XX - tx) ** 2 + ((YY - ty) / 0.8) ** 2)
        if e <= 1:
            mezcla(a, dist < R * 1.3, (235, 242, 255), (0.7 if e == 0 else 0.4) * np.clip(1 - dist / (R * 1.3), 0, 1))
        rr = R * (0.5 + 0.8 * _ease_out(min(1, e / 4)))
        anillo = (dist <= rr) & (dist > rr - 3)
        mezcla(s, anillo, (230, 238, 255), 0.9 * vida)
        mezcla(s, suelo, (90, 110, 190), 0.25 * vida)
        rnd = random.Random(2)
        for i in range(8):
            an = rnd.uniform(0, math.tau)
            d = 6 + e * rnd.uniform(4, 7)
            x, y = tx + math.cos(an) * d, ty + math.sin(an) * d * 0.8 - 10 + e * e * 0.6
            mezcla(a, creciente_m(x, y, 2.6, 0.55, an), LUNA[3], vida)
        rebote = [0, -4, -6, -5, -3, -1][e]
        _luna_en(a, destino[0], destino[1] + rebote, f)
        return
    # VUELVE flotando despacio a su sitio
    t = _ease_out(min(1.0, (f - 16) / (N_CAIDA - 1 - 16)))
    x = destino[0] + (CIELO[0] - destino[0]) * t
    y = destino[1] - 1 + (CIELO[1] - destino[1] + 1) * t
    rnd = random.Random(f)
    for _ in range(3):
        mx, my = x + rnd.uniform(-14, 14), y + 16 + rnd.uniform(0, 14)
        if 0 <= int(mx) < W and 0 <= int(my) < H:
            mezcla(a, disco_m(mx, my, 1.0), LUNA[3], 0.5 * (1 - t))
    _luna_en(a, x, y, f)


def escena_caida_c(f):
    s, a = nuevo(), nuevo()
    tx, ty = 185, 140
    for v in ((tx - 12, ty - 6), (tx + 14, ty + 4)):
        victima(s, *v)
    caida_luna(a, s, tx, ty, f)
    spr = marco(CAZ, 'aullido', min(f, 13), ESTE)
    return escena([s], [(spr, 60, 150, 0)], [a])


def principal_caida():
    os.makedirs(SALIDA, exist_ok=True)
    sel = (2, 6, 8, 9, 10, 11, 13, 18, 24, 37)
    zoom = 2
    img = Image.new('RGB', (len(sel) * (W * zoom + 4), H * zoom + 30), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for i, f in enumerate(sel):
        img.paste(escena_caida_c(f).convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST), (i * (W * zoom + 4), 0))
        pinta.text((i * (W * zoom + 4) + 6, H * zoom + 8), 'f%d' % f, fill=(220, 220, 230))
    ruta = os.path.join(SALIDA, 'cazador_caida_de_la_luna.png')
    img.save(ruta)
    fotos = [escena_caida_c(f).convert('RGB').resize((W * 2, H * 2), Image.NEAREST) for f in range(N_CAIDA)]
    fotos[0].save(os.path.join(SALIDA, 'cazador_caida_de_la_luna.gif'), save_all=True, append_images=fotos[1:],
                  duration=[110] * 6 + [70] * 4 + [90] * 6 + [100] * (N_CAIDA - 16), loop=0)
    print(ruta)
    return ruta


# ------------------------------------------------------------------ FUNDIRSE Y EMERGER (20/11), dos versiones
#   A  CHARCO DE NIEBLA  al fundirse, el humo cae y se extiende por el suelo y sube en bocanadas; al emerger, la niebla se
#                        junta, se encienden los ojos dentro y sale de golpe (la niebla se abre)
#   B  SOLO LOS OJOS     sin charco: se deshace (su animacion) y SOLO QUEDAN LOS OJOS brillando un momento; al volver, los
#                        ojos primero en la oscuridad y luego el cuerpo
# La Sombra: humo gris violeta y ojos AMBAR; el Cazador: niebla AZUL y ojos de HIELO.
SOMBRA_V = 'acechador_sdf_sombra'
HUMO = {SOMBRA_V: [(56, 51, 77), (84, 79, 110), (117, 112, 148)], CAZ: [(51, 61, 102), (77, 92, 140), (112, 133, 184)]}
OJO = {SOMBRA_V: [(240, 170, 40), (255, 226, 140)], CAZ: [(150, 215, 255), (235, 250, 255)]}
LIENZO = {SOMBRA_V: (150, 75, 80), CAZ: (180, 90, 98)}


def _pies(var, x, y):
    L, px, py = LIENZO[var]
    return x - L // 2 + px, y - L // 2 + py


def _ojos(var, x, y):
    """Donde quedan los ojos (mirando al ESTE): la cabeza, arriba y delante de su caja de quieto."""
    spr = marco(var, 'idle', 0, ESTE)
    bb = spr.getbbox()
    L = LIENZO[var][0]
    x0, y0 = x - L // 2, y - L // 2
    return x0 + bb[2] - (9 if var == CAZ else 7), y0 + bb[1] + (13 if var == CAZ else 10)


def _par_ojos(a, var, hx, hy, alfa):
    for dx in (0, -4):
        mezcla(a, disco_m(hx + dx, hy, 2.6), OJO[var][0], alfa * 0.45)
        mezcla(a, (XX >= hx + dx - 1) & (XX <= hx + dx) & (YY == hy), OJO[var][1], alfa)


def _charco(s, a, var, fx, fy, nivel, f, sube=True):
    """La niebla del suelo (nivel 0..1) y sus bocanadas redondas que suben y se deshacen."""
    if nivel <= 0:
        return
    hum = HUMO[var]
    rx, ry = 36 * (0.5 + 0.5 * nivel), 13 * (0.5 + 0.5 * nivel)
    d = ((XX - fx) / rx) ** 2 + ((YY - fy) / ry) ** 2
    mezcla(s, d <= 1, hum[0], 0.75 * nivel * np.clip(1.3 - d, 0, 1))
    mezcla(s, d <= 0.5, hum[1], 0.6 * nivel)
    rnd = random.Random(9)
    for i in range(12):
        x0 = fx + rnd.uniform(-rx * 0.8, rx * 0.8)
        fase = (f / 10.0 + i / 7.0) % 1.0
        y = fy - 2 - fase * 30 if sube else fy - 2 - (1 - fase) * 30
        r = 5.0 * (1 - fase * 0.55)
        mezcla(a, disco_m(x0 + math.sin(fase * 5 + i) * 3, y, r), hum[2], 0.65 * nivel * (1 - fase))
        mezcla(a, disco_m(x0 + math.sin(fase * 5 + i) * 3 - 1, y - 1, r * 0.5), hum[1], 0.5 * nivel * (1 - fase))


def escena_fundirse(var, version, f):
    s, a = nuevo(), nuevo()
    x, y = 120, 110
    fx, fy = _pies(var, x, y)
    hx, hy = _ojos(var, x, y)
    n = 10
    spr = marco(var, 'fundirse', min(f, n - 1), ESTE) if f < n else None
    if version in ('A', 'C'):
        nivel = min(1.0, f / 6.0) * (1.0 if f < n + 2 else max(0.0, 1 - (f - n - 2) / 8.0))
        _charco(s, a, var, fx, fy, nivel, f)
    if version == 'C':
        # LA MEZCLA (20/11): los ojos BAJAN con la cabeza (la de cada fotograma) hasta el charco y se quedan ahi abajo,
        # brillando un momento, antes de apagarse
        suelo = (fx + (hx - fx) * 0.6, fy - 3)
        if spr is not None and spr.getbbox():
            bb = spr.getbbox()
            L = LIENZO[var][0]
            cab = (x - L // 2 + bb[2] - (9 if var == CAZ else 7), y - L // 2 + bb[1] + (13 if var == CAZ else 10))
            pos = (cab[0], min(cab[1], suelo[1]))
        else:
            pos = suelo
        if f >= n - 4:
            al = 1.0 if f < n + 4 else max(0.0, 1 - (f - n - 4) / 5.0)
            _par_ojos(a, var, int(pos[0]), int(pos[1]), al)
    elif version == 'B':
        # se queda la mirada: los ojos brillan un momento donde estaba la cabeza y se apagan
        if f >= n - 3:
            al = 1.0 if f < n + 3 else max(0.0, 1 - (f - n - 3) / 5.0)
            _par_ojos(a, var, hx, hy + (f - n + 3) // 2, al)
    cuerpos = [(spr, x, y, 0)] if spr is not None else []
    return escena([s], cuerpos, [a])


def escena_emerger(var, version, f):
    s, a = nuevo(), nuevo()
    x, y = 120, 110
    fx, fy = _pies(var, x, y)
    hx, hy = _ojos(var, x, y)
    espera = 6   # los primeros fotogramas aun no esta: se anuncia
    spr = marco(var, 'emerger', min(f - espera, 9), ESTE) if f >= espera else None
    if version in ('A', 'C'):
        if f < espera:
            _charco(s, a, var, fx, fy, f / espera, f, sube=False)   # la niebla se junta (baja hacia el suelo)
            if f >= 3:
                # (20/11, el jefe: "los ojos no se ven donde deberian, el cuerpo ya esta fundido en el suelo") DENTRO del
                # charco, a ras de suelo, por delante (donde saldra la cabeza)
                _par_ojos(a, var, fx + (hx - fx) * 0.6, fy - 3, (f - 2) / 3.0)
        else:
            e = f - espera
            nivel = max(0.0, 1 - e / 5.0)
            # se abre: la niebla sale hacia fuera
            rx = 34 + e * 8
            d = ((XX - fx) / rx) ** 2 + ((YY - fy) / (rx * 0.38)) ** 2
            mezcla(s, (d <= 1) & (d > 0.5), HUMO[var][1], 0.75 * nivel)
            _charco(s, a, var, fx, fy, nivel * 0.8, f)
    else:
        if f < espera:
            _par_ojos(a, var, hx, hy, min(1.0, (f + 1) / 3.0))
    cuerpos = [(spr, x, y, 0)] if spr is not None else []
    return escena([s], cuerpos, [a])


def principal_sombras():
    os.makedirs(SALIDA, exist_ok=True)
    filas = []
    for var, nom in ((SOMBRA_V, 'SOMBRA'), (CAZ, 'CAZADOR')):
        for v, desc in (('A', 'charco de niebla'), ('C', 'LA MEZCLA: charco y los ojos que bajan')):
            filas.append(('%s FUNDIRSE %s\n%s' % (nom, v, desc), [escena_fundirse(var, v, f) for f in (0, 3, 6, 9, 11, 15)]))
            filas.append(('%s EMERGER %s\n%s' % (nom, v, desc), [escena_emerger(var, v, f) for f in (1, 4, 6, 8, 11, 15)]))
    zoom = 2
    rot = 200
    img = Image.new('RGB', (rot + 6 * (W * zoom + 4), len(filas) * (H * zoom + 8)), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, marcos) in enumerate(filas):
        y = j * (H * zoom + 8)
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, mm in enumerate(marcos):
            img.paste(mm.convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST), (rot + i * (W * zoom + 4), y))
    ruta = os.path.join(SALIDA, 'sombras_fundirse_emerger.png')
    img.save(ruta)
    for var, nom in ((SOMBRA_V, 'sombra'), (CAZ, 'cazador')):
        for v in 'AC':
            fotos = [escena_fundirse(var, v, f) for f in range(20)] + [escena_emerger(var, v, f) for f in range(18)]
            fotos = [m.convert('RGB').resize((W * 2, H * 2), Image.NEAREST) for m in fotos]
            fotos[0].save(os.path.join(SALIDA, '%s_fundirse_emerger_%s.gif' % (nom, v)), save_all=True,
                          append_images=fotos[1:], duration=85, loop=0)
    print(ruta)
    return ruta


# ------------------------------------------------------------------ LAS ESCENAS
def pies_cazador():
    return (70, 130)


def escena_marca(version, f):
    s, a = nuevo(), nuevo()
    vx, vy = 180, 130
    victima(s, vx, vy)
    (marca_a if version == 'A' else marca_b)(a, vx, vy - 16, f)
    spr = marco(CAZ, 'marca' if f < 10 else 'idle', min(f, 9) if f < 10 else f % 8, ESTE)
    return escena([s], [(spr, *pies_cazador(), 0)], [a])


def escena_media_luna(version, f):
    s, a = nuevo(), nuevo()
    bx, by = pies_cazador()
    for v in ((bx + 45, by - 20), (bx + 55, by + 10), (bx + 30, by + 30)):
        victima(s, *v)
    media_luna(a, s, bx + 14, by - 8, f, version)
    spr = marco(CAZ, 'media_luna', min(f, 11), ESTE)
    return escena([s], [(spr, bx, by, 0)], [a])


def escena_caida(version, f):
    s, a = nuevo(), nuevo()
    tx, ty = 185, 130
    for v in ((tx - 12, ty - 6), (tx + 14, ty + 4)):
        victima(s, *v)
    caida(a, s, tx, ty, f, version)
    spr = marco(CAZ, 'aullido', min(f, 13), ESTE)
    return escena([s], [(spr, *pies_cazador(), 0)], [a])


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    filas = [
        ('MARCA DE LA LUNA A\nla creciente y la estrella', [escena_marca('A', f) for f in (10, 12, 14, 16, 18, 20)]),
        ('MARCA DE LA LUNA B\nmas grande, resplandor y motas', [escena_marca('B', f) for f in (10, 12, 14, 16, 18, 20)]),
        ('MEDIA LUNA A\nhoja de luna', [escena_media_luna('A', f) for f in (3, 5, 6, 8, 10, 13)]),
        ('MEDIA LUNA B\nluna de colores', [escena_media_luna('B', f) for f in (3, 5, 6, 8, 10, 13)]),
        ('CAIDA DE LA LUNA A\ncolumna de luz', [escena_caida('A', f) for f in (3, 6, 7, 9, 12, 15)]),
        ('CAIDA DE LA LUNA B\nla luna cae', [escena_caida('B', f) for f in (3, 6, 8, 10, 12, 15)]),
    ]
    zoom = 2
    rot = 200
    img = Image.new('RGB', (rot + 6 * (W * zoom + 4), len(filas) * (H * zoom + 8)), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, marcos) in enumerate(filas):
        y = j * (H * zoom + 8)
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, mm in enumerate(marcos):
            img.paste(mm.convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST), (rot + i * (W * zoom + 4), y))
    ruta = os.path.join(SALIDA, 'cazador_efectos_versiones.png')
    img.save(ruta)
    for nombre, fn, n in (('media_luna', escena_media_luna, 16), ('caida', escena_caida, 20), ('marca', escena_marca, 26)):
        for v in 'AB':
            fotos = [fn(v, f).convert('RGB').resize((W * 2, H * 2), Image.NEAREST) for f in range(n)]
            fotos[0].save(os.path.join(SALIDA, 'cazador_%s_%s.gif' % (nombre, v)), save_all=True, append_images=fotos[1:],
                          duration=80, loop=0)
    print(ruta)
    return ruta


if __name__ == '__main__':
    principal()
