#!/usr/bin/env python3
# ============================================================
#  rata_efectos_pixel.py -- LOS EFECTOS DE LA RATA (y sus mutantes sombria, drusa y cuarzo ahumado) EN PIXEL ART
#  (04/11/2026, memoria efectos-a-pixel-art). La receta de la del escarabajo y las piezas de la del slime
#  (slime_efectos_pixel.py). Los mismos efectos que hoy pintan BestiaAire (las mandibulas) y RataAire, pasados a pixel:
#    mordisco y Mordisco sangrante (mandibulas + sangre), Frenesi de dentelladas (salto, polvo y bocados),
#    SOMBRIA: Mordisco sombrio (jirones), Frenesi en la sombra (jirones en el salto y la mancha), Mordisco a traicion
#    (remolino donde estaba y reaparece detras), y la ONDA del sigilo;
#    DRUSA: Mordisco de cristal (esquirlas), Frenesi de esquirlas (anillo), Embestida de cristal (surco y corte);
#    CUARZO AHUMADO: el mismo cristal en ahumado y el Destello (abanico de luz y el velo de la ceguera).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/rata_efectos_pixel.py
# ============================================================
import json
import math
import os
import random

import numpy as np
from PIL import Image

import slime_efectos_pixel as sl
from slime_efectos_pixel import (W, H, XX, YY, TRAMA, UNIDAD, SALIDA, RAIZ, nuevo, poner, punto, disco, estrella,
                                 cometa_dir, victima, gota, charco, seco, Gotas, coletazo, cristal, sombra, lamina,
                                 elegir, DIRS, NOM_DIR)
import escarabajo_efectos_pixel as ep

SANGRE = [(70, 8, 14), (146, 18, 26), (206, 46, 44), (255, 150, 128)]
SANGRE_BORDE = (34, 4, 8)
HUESO = [(92, 86, 78), (168, 162, 150), (226, 222, 208), (255, 255, 248)]
HUESO_BORDE = (34, 30, 28)
# NUESTRA oscuridad (la Voragine): formas negras rellenas con la pincelada clara rota en el borde.
NEGRO = [(8, 6, 14), (24, 20, 36), (62, 52, 88), (150, 136, 184)]
NEGRO_BORDE = (4, 3, 8)
CIAN = sl.CRISTAL
AHUMADO = [(12, 16, 38), (34, 46, 94), (90, 114, 178), (200, 216, 252)]


# --- Sus hojas: el lienzo de la rata va centrado (los pies en el medio) ---
_hojas = {}


def marco(var, anim, f, fila=0):
    clave = (var, anim)
    if clave not in _hojas:
        carpeta = os.path.join(RAIZ, 'assets/sprites/enemigos/%s' % var)
        with open(os.path.join(carpeta, 'hojas.json'), encoding='utf-8') as fh:
            lw, lh = json.load(fh)['lienzo']
        _hojas[clave] = (Image.open(os.path.join(carpeta, '%s.png' % anim)).convert('RGBA'), lw, lh)
    h, lw, lh = _hojas[clave]
    n = h.size[0] // lw
    return h.crop(((f % n) * lw, fila * lh, (f % n) * lw + lw, fila * lh + lh))


def escena(suelo, cuerpos, aire):
    img = ep.fondo()
    for c in suelo:
        img.alpha_composite(Image.fromarray(c, 'RGBA'))
    for spr, x, y, alto in sorted(cuerpos, key=lambda c: c[2]):
        if spr is None:
            continue
        w, h = spr.size
        img.paste(spr, (int(round(x)) - w // 2, int(round(y - alto)) - h // 2), spr)
    for c in aire:
        img.alpha_composite(Image.fromarray(c, 'RGBA'))
    return img


RATA, SOMBRIA, DRUSA, CUARZO = 'rata_sdf', 'rata_sdf_sombria', 'rata_sdf_drusa', 'rata_sdf_cuarzo'


# --- LA MANDIBULA: dos filas de dientes que se cierran sobre el que muerde, abiertas a lo largo del golpe ---
def mandibula(a, x, y, dx, dy, abre, ancho=7):
    px, py = -dy, dx
    for k in (-1, 1):
        # LA ENCIA: una banda curva de 3 celdas (borde, hueso, luz), y los DIENTES, triangulos gordos hacia el centro.
        for j in range(-ancho, ancho + 1):
            curva = (j * j) / float(ancho * ancho) * 3.5
            bx = x + dx * k * (abre + 3.0 + curva) + px * j
            by = y + dy * k * (abre + 3.0 + curva) + py * j
            punto(a, bx + dx * k * 2, by + dy * k * 2, HUESO_BORDE)
            punto(a, bx + dx * k, by + dy * k, HUESO[1])
            punto(a, bx, by, HUESO[2])
        for j in range(-ancho + 2, ancho - 1, 3):
            curva = (j * j) / float(ancho * ancho) * 3.5
            bx = x + dx * k * (abre + 3.0 + curva) + px * j
            by = y + dy * k * (abre + 3.0 + curva) + py * j
            for t in range(1, 4):
                w = 1 if t < 3 else 0
                for q in range(-w, w + 1):
                    col = HUESO[3] if (t == 3 or q == -w) else HUESO[2]
                    punto(a, bx - dx * k * t + px * q, by - dy * k * t + py * q, col)
                punto(a, bx - dx * k * t + px * (w + 1), by - dy * k * t + py * (w + 1), HUESO[0])


def bocado(s, a, V, dx, dy, e, sangra=True, sem=0, pal=SANGRE, borde=SANGRE_BORDE):
    """e = marcos desde que empieza a cerrar (0-2 se cierra, 3 muerde)."""
    pecho = (V[0], V[1] - 9)
    if e < 4:
        mandibula(a, pecho[0], pecho[1], dx, dy, (6.0, 3.5, 1.2, 0.0)[e])
    if e == 3:
        estrella(a, pecho[0], pecho[1], 6, HUESO)


def rata_y_victima(fila, dist=22):
    dx, dy = DIRS[fila]
    A = (W * 0.5 - dx * dist * 0.6, H * 0.55 - dy * dist * 0.5)
    V = (A[0] + dx * dist, A[1] + dy * dist + 6)
    return dx, dy, A, V


# --- MORDISCO (el basico y el sangrante, y los de sus mutantes: lo que cambia es lo que sale del bocado) ---
def mordisco(fila, var=RATA, anim='basico', extra=None, sangre=True):
    dx, dy, A, V = rata_y_victima(fila)
    sangre_g = Gotas(7, 4 + fila, 8.0, 20.0, (math.atan2(dy, dx), 0.8), sube=(5.0, 12.0), tam=(1.2, 2.0),
                     pal=SANGRE, borde=SANGRE_BORDE)
    m, t = [], []
    for f in range(13):
        s, a = nuevo(), nuevo()
        e = f - 2
        if e >= 0:
            bocado(s, a, V, dx, dy, min(e, 4))
        if e >= 3:
            if sangre:
                sangre_g.pintar(s, a, V[0], V[1] - 2, min(1.0, (e - 3) / 5.0), 2.0, 1.0, e - 8)
            if extra:
                extra(s, a, V, dx, dy, e - 3)
        victima(s if dy >= 0 else a, *V)
        m.append(escena([s], [(marco(var, anim, min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# Lo que le pone cada mutante encima del bocado:
def jirones(s, a, V, dx, dy, e, n=5, sem=3):
    """Medias lunas negras rellenas que salen del bocado, se abren y se deshacen."""
    if e < 0 or e > 6:
        return
    rnd = random.Random(sem)
    for i in range(n):
        ang = math.atan2(dy, dx) + rnd.uniform(-1.6, 1.6)
        r = 5.0 + e * 2.2
        cx, cy = V[0] + math.cos(ang) * e * 1.5, V[1] - 9 + math.sin(ang) * e * 1.2 - e
        sentido = 1.0 if i % 2 else -1.0
        coletazo(a, cx, cy, ang, r, 0.3 * sentido, 1.6 * (1.0 - e / 7.0), sentido, 4.0 * (1.0 - e / 8.0) + 1.0,
                 NEGRO, NEGRO_BORDE)


def esquirlas(pal):
    def f(s, a, V, dx, dy, e, n=7, sem=5):
        if e < 0 or e > 6:
            return
        rnd = random.Random(sem)
        if e == 0:
            estrella(a, V[0], V[1] - 9, 7, pal)
        for i in range(n):
            ang = math.atan2(dy, dx) + rnd.uniform(-1.4, 1.4)
            v = rnd.uniform(0.7, 1.0)
            k = e / 6.0
            d = 4.0 + 18.0 * v * k
            x, y = V[0] + math.cos(ang) * d, V[1] - 9 + math.sin(ang) * d * 0.8 - math.sin(k * math.pi) * 8.0 + k * 9.0
            if e < 6:
                cristal(a, x, y, math.cos(ang + e * 0.6), math.sin(ang + e * 0.6), 5.0, 1.4, pal)
    return f


# --- EL FRENESI: se agazapa, salta encima y muerde sin parar entre una nube de polvo (y lo de cada mutante) ---
def frenesi(fila, var=RATA, radio_mundo=25.0, modo=None, dist=46):
    dx, dy = DIRS[fila]
    A = (W * 0.5 - dx * dist * 0.55, H * 0.56 - dy * dist * 0.5)
    V = (A[0] + dx * dist, A[1] + dy * dist + 4)
    B = (V[0] - dx * 7, V[1] - dy * 7 - 2)
    R = radio_mundo / UNIDAD
    rnd = random.Random(11)
    nubes = [(rnd.uniform(0, math.tau), rnd.uniform(0.5, 1.0), rnd.uniform(3.0, 5.0)) for _ in range(12)]
    sangre_g = Gotas(10, 9, 6.0, R * 0.9, sube=(5.0, 12.0), tam=(1.2, 2.0), pal=SANGRE, borde=SANGRE_BORDE)
    pal_cristal = AHUMADO if var == CUARZO else CIAN
    anillo = [(i / 14.0 * math.tau + rnd.uniform(-0.15, 0.15), rnd.uniform(0.85, 1.0), rnd.uniform(6.0, 8.0)) for i in range(14)]
    m, t = [], []
    carga, vuelo = 5, 5
    for f in range(carga + vuelo + 14):
        s, a = nuevo(), nuevo()
        if f < carga:
            spr, x, y, alto = marco(var, 'agazapado', f + 2, fila), A[0], A[1], 0
        elif f < carga + vuelo:
            u = (f - carga + 1) / float(vuelo)
            x, y = A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u
            alto = 22.0 * 4 * u * (1 - u)
            spr = marco(var, 'salto_rata', f - carga + 2, fila)
            sombra(s, x, y + 4, 5.0)
            if modo == 'sombra':
                # jirones de sombra que se quedan en el aire por donde pasa
                for k in range(f - carga + 1):
                    uk = (k + 0.5) / vuelo
                    xk, yk = A[0] + (B[0] - A[0]) * uk, A[1] + (B[1] - A[1]) * uk - 22.0 * 4 * uk * (1 - uk)
                    edad = f - carga - k
                    coletazo(a, xk, yk - 2, math.atan2(dy, dx) + 1.6 * (1 if k % 2 else -1), 4.0 + edad,
                             0.2, 1.4 * max(0.0, 1.0 - edad / 5.0), 1.0, 3.0, NEGRO, NEGRO_BORDE)
        else:
            e = f - carga - vuelo
            spr, x, y, alto = marco(var, 'frenesi', e, fila), B[0], B[1], 0
            if modo == 'sombra':
                # la mancha de sombra que se abre donde cae
                abre = min(1.0, (e + 1) / 3.0)
                charco(s, V[0], V[1], R * 0.55 * abre, 2.0, seco(e, 7, 6) * 0.75, NEGRO, NEGRO_BORDE)
            elif modo == 'esquirlas':
                if e < 2:
                    estrella(a, V[0], V[1] - 8, (10, 14)[e], pal_cristal)
                k = min(1.0, (e + 1) / 4.0)
                queda = seco(e, 6, 5)
                for ang, uu, largo in anillo:
                    d = 6.0 + (R * uu - 6.0) * (1 - (1 - k) ** 2)
                    xx, yy = V[0] + math.cos(ang) * d, V[1] + math.sin(ang) * d - 3.0 * (1 - k)
                    tmp = nuevo()
                    cristal(tmp, xx, yy, math.cos(ang), math.sin(ang), largo, 1.8, pal_cristal)
                    mascara = (tmp[:, :, 3] > 0) & (TRAMA < queda)
                    (a if math.sin(ang) > -0.3 else s)[mascara] = tmp[mascara]
            else:
                # el polvo de la pelea, que gira alrededor y se deshace
                for ang, uu, rad in nubes:
                    r2 = rad * max(0.0, 1.0 - e / 12.0)
                    ang2 = ang + e * 0.25
                    if r2 > 0.7:
                        ep.bolita(s if math.sin(ang2) < 0 else a, V[0] + math.cos(ang2) * R * uu,
                                  V[1] + math.sin(ang2) * R * uu * 0.7 - 2, r2, ep.POLVO)
            # los bocados, uno tras otro
            if e < 10:
                q = e % 3
                ang = (e // 3) * 2.1
                bx, by = math.cos(ang) * 0.6 + dx * 0.8, math.sin(ang) * 0.6 + dy * 0.8
                n = math.hypot(bx, by)
                mandibula(a, V[0] + math.cos(ang) * 2, V[1] - 9, bx / n, by / n, (4.0, 1.5, 0.0)[q], 4)
            if modo != 'esquirlas':
                sangre_g.pintar(s, a, V[0], V[1] - 4, min(1.0, e / 8.0), 2.0, 1.0, e - 8)
        victima(s if dy >= 0 else a, *V)
        m.append(escena([s], [(spr, x, y, alto)], [a]))
        t.append(1000 // 14)
    return m, t


# --- EL REMOLINO de sombra de la Traicion: tres brazos negros que giran y se cierran ---
def remolino(a, cx, cy, r, giro, fuerza):
    if fuerza <= 0.0:
        return
    for k in range(3):
        eje = giro + k * math.tau / 3.0
        coletazo(a, cx, cy, eje, r, 0.0, 2.2 * fuerza, 1.0, 4.5 * fuerza + 1.0, NEGRO, NEGRO_BORDE)


def traicion(fila):
    dx, dy = DIRS[fila]
    dist = 40
    A = (W * 0.5 - dx * dist * 0.5, H * 0.56 - dy * dist * 0.5)
    V = (A[0] + dx * dist, A[1] + dy * dist + 4)
    B = (V[0] + dx * 12, V[1] + dy * 12 - 4)          # detras de su presa
    sangre_g = Gotas(7, 12, 8.0, 18.0, (math.atan2(-dy, -dx), 0.8), sube=(5.0, 12.0), tam=(1.2, 2.0),
                     pal=SANGRE, borde=SANGRE_BORDE)
    m, t = [], []
    for f in range(20):
        s, a = nuevo(), nuevo()
        cuerpos = []
        if f < 4:
            remolino(s, A[0], A[1] + 2, 8.0 + f * 1.5, f * 0.9, min(1.0, (f + 1) / 3.0))
            fade = nuevo()
            spr = marco(SOMBRIA, 'agazapado', f + 2, fila)
            if f < 3:
                cuerpos.append((spr, A[0], A[1], 0))
        elif f < 8:
            remolino(s, A[0], A[1] + 2, 14.0, f * 0.9, 1.0 - (f - 4) / 4.0)
            remolino(s, B[0], B[1] + 2, 6.0 + (f - 4) * 2.0, -f * 0.9, min(1.0, (f - 3) / 3.0))
            if f >= 6:
                cuerpos.append((marco(SOMBRIA, 'salto_rata', f, (fila + 4) % 8), B[0], B[1], 0))
        else:
            e = f - 8
            remolino(s, B[0], B[1] + 2, 14.0, -f * 0.9, max(0.0, 1.0 - e / 4.0))
            cuerpos.append((marco(SOMBRIA, 'basico', min(e, 7), (fila + 4) % 8), B[0], B[1], 0))
            if e < 5:
                bocado(s, a, V, -dx, -dy, min(e, 4))
            if e >= 3:
                sangre_g.pintar(s, a, V[0], V[1] - 2, min(1.0, (e - 3) / 5.0), 2.0, 1.0, e - 8)
                jirones(s, a, V, -dx, -dy, e - 3)
        victima(s if dy <= 0 else a, *V)
        cuerpos.sort(key=lambda c: c[2])
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 14)
    return m, t


# --- LA EMBESTIDA DE CRISTAL: atraviesa su linea; por donde pasa quedan esquirlas clavadas que brillan y se apagan,
# y al que atraviesa le deja un corte de cristal ---
def embestida(fila, var=DRUSA):
    dx, dy = DIRS[fila]
    pal = AHUMADO if var == CUARZO else CIAN
    largo = 70.0 / UNIDAD
    A = (W * 0.5 - dx * largo * 0.5, H * 0.56 - dy * largo * 0.5)
    V = (A[0] + dx * largo * 0.55, A[1] + dy * largo * 0.55 + 4)
    rnd = random.Random(7 + fila)
    clavadas = [(rnd.uniform(0.05, 1.0), rnd.uniform(-6.0, 6.0), rnd.uniform(5.0, 8.0), rnd.uniform(-0.5, 0.5)) for _ in range(11)]
    m, t = [], []
    corre = 7
    for f in range(corre + 12):
        s, a = nuevo(), nuevo()
        u = min(1.0, f / float(corre))
        x, y = A[0] + dx * largo * u, A[1] + dy * largo * u
        for uu, lado, alto, incl in clavadas:
            if uu > u:
                continue
            edad = f - uu * corre
            queda = seco(edad, 6, 5)
            px, py = A[0] + dx * largo * uu - dy * lado, A[1] + dy * largo * uu + dx * lado
            tmp = nuevo()
            n = math.hypot(incl, 1.0)
            cristal(tmp, px, py - alto * 0.5, incl / n, -1.0 / n, alto, 1.6, pal)
            if edad < 2:
                punto(tmp, px + incl * alto * 0.5, py - alto, pal[3], 2)
            mascara = (tmp[:, :, 3] > 0) & (TRAMA < queda)
            s[mascara] = tmp[mascara]
        pasa = (largo * u) - largo * 0.55
        if pasa >= 0:
            e = int(pasa / (largo / corre))
            if e < 6:
                coletazo(a, V[0] - dy * 3, V[1] - 9 + dx * 3, math.atan2(dy, dx) + math.pi / 2, 7.0, 0.6, 2.0 * (1 - e / 6.0),
                         -1.0, 4.0 * (1 - e / 7.0) + 1.0, pal, pal[0])
            if e < 2:
                estrella(a, V[0], V[1] - 9, (8, 5)[e], pal)
        victima(s if dy >= 0 else a, *V)
        m.append(escena([s], [(marco(var, 'embestida', min(f, 7), fila), x, y, 0)], [a]))
        t.append(1000 // 16)
    return m, t


# --- EL DESTELLO del cuarzo ahumado: un fogonazo en abanico desde los cristales de su pecho, blanco azulado en el
# centro y humo azul oscuro hacia el borde; al que le da, un velo oscuro en los ojos ---
def abanico(a, cx, cy, eje, R, apertura, e):
    d = np.hypot(XX - cx, YY - cy)
    ang = np.arctan2(YY - cy, XX - cx)
    rel = np.abs((ang - eje + np.pi) % (2 * np.pi) - np.pi)
    mitad = math.radians(apertura) * 0.5
    llega = R * min(1.0, (e + 1) / 3.0)
    dentro = (rel < mitad) & (d < llega)
    u = d / max(R, 1.0)
    rayo = np.sin(ang * 23.0 + e * 0.7) > 0.25
    fuerza = max(0.0, 1.0 - e / 9.0)
    poner(a, dentro & (TRAMA < (1.0 - u) * fuerza * 1.2) & (u > 0.55), AHUMADO[0])
    poner(a, dentro & (TRAMA < (1.0 - u) * fuerza * 1.6) & (u > 0.3) & (u <= 0.55), AHUMADO[1])
    poner(a, dentro & (u <= 0.3) & (TRAMA < fuerza * 1.4), AHUMADO[2])
    poner(a, dentro & rayo & (u < 0.75) & (TRAMA < fuerza * 1.2), AHUMADO[2])
    poner(a, dentro & (u < 0.14) & (fuerza > 0.5), AHUMADO[3])


def velo(a, V, e):
    if e < 0 or e > 9:
        return
    x, y = V[0], V[1] - 16
    m = (np.abs(XX - x) <= 5) & (np.abs(YY - y) <= 1)
    poner(a, m & (TRAMA < 0.6 - e / 16.0), NEGRO[1])
    poner(a, (np.abs(XX - x) <= 5) & (YY == y - 2) & (TRAMA < 0.6 - e / 15.0), NEGRO[2])
    rnd = random.Random(e // 2)
    for _ in range(3):
        punto(a, x + rnd.randint(-6, 6), y - rnd.randint(2, 6) - e, AHUMADO[3])


def destello(fila):
    dx, dy = DIRS[fila]
    R = 70.0 / UNIDAD
    A = (W * 0.5 - dx * R * 0.45, H * 0.56 - dy * R * 0.4)
    vict = [(A[0] + dx * 36 - dy * 8, A[1] + dy * 36 + dx * 8 + 4), (A[0] + dx * 50 + dy * 12, A[1] + dy * 50 - dx * 12 + 4)]
    rnd = random.Random(3)
    motas = [(rnd.uniform(-0.55, 0.55), rnd.uniform(0.2, 1.0)) for _ in range(9)]
    m, t = [], []
    carga = 5
    for f in range(carga + 13):
        s, a = nuevo(), nuevo()
        pecho = (A[0] + dx * 6, A[1] + dy * 6 - 6)
        if f < carga:
            if f >= 2:
                estrella(a, pecho[0], pecho[1], 3 + (f - 2) * 3, AHUMADO)
        else:
            e = f - carga
            capa = a if dy > -0.2 else s
            abanico(capa, pecho[0], pecho[1], math.atan2(dy, dx), R, 70.0, e)
            if e < 2:
                estrella(a, pecho[0], pecho[1], (16, 10)[e], AHUMADO)
            for ang, uu in motas:
                k = min(1.0, (e + 1) / 4.0)
                if e < 7:
                    d = R * uu * k
                    punto(a, pecho[0] + math.cos(math.atan2(dy, dx) + ang) * d, pecho[1] + math.sin(math.atan2(dy, dx) + ang) * d,
                          AHUMADO[3] if e < 4 else AHUMADO[2], 2)
            for v in vict:
                velo(a, v, e - 2)
        for v in vict:
            victima(s if v[1] < A[1] else a, *v)
        m.append(escena([s], [(marco(CUARZO, 'destello', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LA ONDA DEL SIGILO: la que esta en las sombras no se ve; de vez en cuando el aire ondula donde esta y se le
# insinua la silueta a franjas, temblando, y se vuelve a ir ---
def onda(fila=1):
    A = (W * 0.5, H * 0.56)
    m, t = [], []
    for f in range(16):
        img = ep.fondo()
        spr = np.array(marco(SOMBRIA, 'idle', f % 8, fila))
        fuerza = math.sin(min(1.0, max(0.0, (f - 2) / 11.0)) * math.pi)
        if fuerza > 0.05:
            h, w = spr.shape[:2]
            out = np.zeros_like(spr)
            for y in range(h):
                franja = (y // 2 + f) % 3
                desp = (-1, 0, 1)[franja] * (1 + int(fuerza * 1.5))
                fila_px = np.roll(spr[y], desp, axis=0)
                out[y] = fila_px
            ys, xs = np.mgrid[0:h, 0:w]
            tr = ep.BAYER[(ys // 2) % 4, (xs // 2) % 4]
            vis = (out[:, :, 3] > 0) & (tr < fuerza * 0.95) & (((ys // 2) + f) % 3 != 0)
            # se ve como un velo del color del aire, no la rata entera: aclarada y fria
            col = out[:, :, :3].astype(int) * 0.3 + np.array([150, 150, 182]) * 0.7
            capa = np.zeros_like(out)
            capa[vis, :3] = col[vis].astype(np.uint8)
            capa[vis, 3] = 255
            im = Image.fromarray(capa, 'RGBA')
            img.paste(im, (int(A[0]) - w // 2, int(A[1]) - h // 2), im)
        m.append(img)
        t.append(1000 // 12)
    return m, t


# La rata es pequeña: en la lamina se recorta alrededor de la pelea y se amplia mas.
CAJA = (25, 18, 155, 128)


def lamina_rata(filas, ruta, zoom=4):
    from PIL import ImageDraw
    cw, ch = CAJA[2] - CAJA[0], CAJA[3] - CAJA[1]
    ancho_rotulo = 170
    columnas = max(len(m) for _, m in filas)
    img = Image.new('RGB', (ancho_rotulo + columnas * (cw * zoom + 4), len(filas) * (ch * zoom + 8)), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, marcos) in enumerate(filas):
        y = j * (ch * zoom + 8)
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, mm in enumerate(marcos):
            img.paste(mm.crop(CAJA).convert('RGB').resize((cw * zoom, ch * zoom), Image.NEAREST), (ancho_rotulo + i * (cw * zoom + 4), y))
    img.save(ruta)


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    mo = {d: mordisco(d) for d in (1, 4)}
    ms = mordisco(2, RATA, 'desgarro')
    fr = {d: frenesi(d) for d in (1, 4)}
    msom = mordisco(2, SOMBRIA, 'desgarro', jirones)
    fsom = frenesi(2, SOMBRIA, 25.0, 'sombra')
    tr = {d: traicion(d) for d in (2, 0)}
    on = onda()
    mcr = mordisco(2, DRUSA, 'desgarro', esquirlas(CIAN))
    fes = frenesi(1, DRUSA, 40.0, 'esquirlas')
    em = {d: embestida(d) for d in range(5)}
    fah = frenesi(2, CUARZO, 40.0, 'esquirlas')
    emc = embestida(1, CUARZO)
    de = {d: destello(d) for d in range(5)}
    filas = [
        *[('MORDISCO (basico)\nhacia el ' + NOM_DIR[d], elegir(mo[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        ('MORDISCO SANGRANTE\nhacia el ESTE', elegir(ms[0], (2, 4, 5, 6, 8, 11))),
        *[('FRENESI DE DENTELLADAS\nhacia el ' + NOM_DIR[d], elegir(fr[d][0], (2, 7, 10, 12, 15, 21))) for d in (1, 4)],
        ('SOMBRIA\nMordisco sombrio', elegir(msom[0], (3, 5, 6, 7, 9, 11))),
        ('SOMBRIA\nFrenesi en la sombra', elegir(fsom[0], (6, 8, 10, 12, 15, 21))),
        *[('SOMBRIA\nMordisco a traicion\nhacia el ' + NOM_DIR[d], elegir(tr[d][0], (1, 3, 5, 7, 11, 14))) for d in (2, 0)],
        ('SOMBRIA\nla onda del sigilo', elegir(on[0], (1, 4, 6, 8, 10, 14))),
        ('DRUSA\nMordisco de cristal', elegir(mcr[0], (3, 5, 6, 7, 9, 11))),
        ('DRUSA\nFrenesi de esquirlas', elegir(fes[0], (6, 9, 10, 11, 13, 18))),
        *[('DRUSA\nEmbestida de cristal\nhacia el ' + NOM_DIR[d], elegir(em[d][0], (2, 4, 6, 8, 11, 15))) for d in range(5)],
        ('CUARZO AHUMADO\nFrenesi de esquirlas', elegir(fah[0], (6, 9, 10, 11, 13, 18))),
        ('CUARZO AHUMADO\nEmbestida de cristal', elegir(emc[0], (2, 4, 6, 8, 11, 15))),
        *[('CUARZO AHUMADO\nDestello\nhacia el ' + NOM_DIR[d], elegir(de[d][0], (3, 5, 6, 8, 11, 15))) for d in range(5)],
    ]
    lamina_rata(filas, os.path.join(SALIDA, 'rata.png'))
    todos, tiempos = [], []
    for marcos, ts in [mo[1], ms, fr[1], msom, fsom, tr[2], on, mcr, fes, em[1], em[2], fah, emc, de[1], de[2]]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    fotos = [m.crop(CAJA).convert('RGB').resize(((CAJA[2] - CAJA[0]) * 4, (CAJA[3] - CAJA[1]) * 4), Image.NEAREST)
             .quantize(64, dither=Image.NONE) for m in todos]
    fotos[0].save(os.path.join(SALIDA, 'rata.gif'), save_all=True, append_images=fotos[1:], duration=tiempos, loop=0)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
