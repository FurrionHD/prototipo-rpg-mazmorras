#!/usr/bin/env python3
# ============================================================
#  rey_slime_efectos_pixel.py -- LOS EFECTOS DEL REY SLIME (y sus mutantes, el Rey tirano y el Rey destronado) EN PIXEL
#  ART (04/11/2026, memoria efectos-a-pixel-art). Los mismos que hoy pintan SlimeAire (APLASTA, MAREA, TROZO, CRIA) y
#  ReyAire (ESQUIRLAS, CLAVADA, PEDAZO, DECRETO, TRIBUTO): el GEL de su cuerpo y el CRISTAL de su corona (cian con el
#  blanco del reflejo). El Rey es enorme: esta lamina va en un lienzo mas grande (las piezas leen el lienzo al llamarlas).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/rey_slime_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO GRANDE: antes de traer nada mas, que las demas piezas lo cojan ya.
W, H = 300, 250
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import slime_veneno_efectos_pixel as vn  # noqa: E402
from slime_efectos_pixel import (UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella, cometa_dir, victima, gota,  # noqa: E402
                                 charco, seco, Gotas, marco, escena, sombra, elegir, cristal, DIRS, NOM_DIR)

GEL = [(24, 70, 120), (72, 160, 230), (156, 214, 255), (236, 248, 255)]
GEL_BORDE = (10, 30, 56)
CRISTAL = [(24, 74, 100), (70, 196, 236), (178, 244, 255), (255, 255, 255)]
GRIETA = (22, 20, 26)
REY, TIRANO, DESTRONADO = 'rey280', 'tir308', 'des308'


def gel():
    sl.GEL, sl.GEL_BORDE = GEL, GEL_BORDE
    vn.GEL = GEL


def lienzo_lamina(filas, ruta, zoom=2):
    from PIL import ImageDraw
    ancho_rotulo = 170
    columnas = max(len(m) for _, m in filas)
    img = Image.new('RGB', (ancho_rotulo + columnas * (W * zoom + 4), len(filas) * (H * zoom + 8)), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, marcos) in enumerate(filas):
        y = j * (H * zoom + 8)
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, mm in enumerate(marcos):
            img.paste(mm.convert('RGB').resize((W * zoom, H * zoom), Image.NEAREST), (ancho_rotulo + i * (W * zoom + 4), y))
    img.save(ruta)


def rad_de(var):
    return marco(var, 'idle', 0, 0).size[0] * 0.3


# --- APLASTAMIENTO: salta y cae con todo su peso: el charco grande, la onda de choque que corre hasta el borde, las losas
# que se rajan y la corona de gotas ---
def grietas(s, x, y, R, k, sem):
    rnd = random.Random(sem)
    for i in range(9):
        ang = i / 9 * math.tau + rnd.uniform(-0.2, 0.2)
        px, py = x + math.cos(ang) * R * 0.35, y + math.sin(ang) * R * 0.35
        largo = R * rnd.uniform(0.55, 0.95) * k
        pasos = int(largo / 3)
        for p in range(pasos):
            ang += rnd.uniform(-0.35, 0.35)
            nx, ny = px + math.cos(ang) * 3, py + math.sin(ang) * 3
            for q in range(3):
                punto(s, px + (nx - px) * q / 3, py + (ny - py) * q / 3, GRIETA, 2)
            px, py = nx, ny


def aplastamiento(var=REY):
    R = 70.0 / UNIDAD
    A = (W * 0.32, H * 0.38)
    B = (W * 0.6, H * 0.6)
    corona = Gotas(26, 3, R * 0.55, R * 1.0, sube=(12.0, 24.0), tam=(1.6, 2.6))
    rnd = random.Random(17)
    manchas = [(rnd.uniform(0, math.tau), rnd.uniform(0.5, 1.0), rnd.uniform(0.1, 0.16) * R) for _ in range(9)]
    vict = [(B[0] + R * 0.8, B[1] - R * 0.25), (B[0] - R * 0.75, B[1] + R * 0.4), (B[0] + R * 0.1, B[1] + R * 0.85)]
    m, t = [], []
    carga, vuelo = 6, 6
    for f in range(carga + vuelo + 18):
        s, a = nuevo(), nuevo()
        if f < carga:
            anim, fr, x, y, alto = 'inflar', f, A[0], A[1], 0
        elif f < carga + vuelo:
            u = (f - carga + 1) / float(vuelo)
            x, y = A[0] + (B[0] - A[0]) * u, A[1] + (B[1] - A[1]) * u
            alto = 60.0 * 4 * u * (1 - u)
            anim, fr = 'hinchado', f % 8
            sombra(s, x, y, 22.0 - alto * 0.12)
        else:
            e = f - carga - vuelo
            x, y, alto = B[0], B[1], 0
            anim, fr = ('aplaston', min(e, 7)) if e < 8 else ('deshincharse', min(e - 8, 7))
            abre = 1.0 - (1.0 - min(1.0, (e + 1) / 4.0)) ** 2
            vivo = seco(e, 10, 8)
            grietas(s, B[0], B[1], R, min(1.0, (e + 1) / 3.0), 5)
            charco(s, B[0], B[1], R * 0.55 * abre, 1.0, vivo)
            for ang, uu, r in manchas:
                charco(s, B[0] + math.cos(ang) * uu * R * 0.85 * abre, B[1] + math.sin(ang) * uu * R * 0.85 * abre, r * abre, ang, vivo * 0.95)
            if e < 6:
                ep.banda(s, B[0], B[1], R * min(1.0, (e + 1) / 5.0), 7.0 * (1 - e / 8.0) + 2.0, GEL, False, e)
            corona.pintar(s, a, B[0], B[1], min(1.0, e / 7.0), R * 0.45, 1.0, e - 7)
            if e < 3:
                estrella(a, B[0], B[1] - 6, (20, 32, 16)[e], GEL)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, anim, fr, 1), x, y, alto)], [a]))
        t.append(1000 // 14)
    return m, t


# --- ESCISION: un trozo del Rey sale disparado hacia cada uno, le revienta encima y lo que queda vuelve a el ---
def escision(var=REY, pedazos=False):
    A = (W * 0.42, H * 0.5)
    rad = rad_de(var)
    vict = [(A[0] + rad + 40, A[1] + 22), (A[0] - rad - 30, A[1] + 30), (A[0] + 10, A[1] + rad + 44)]
    salpica = [Gotas(8, 4 + i, 3.0, 11.0, sube=(8.0, 14.0), tam=(1.2, 2.0)) for i in range(3)]
    rnd = random.Random(2)
    m, t = [], []
    vuelo = 6
    for f in range(4 + vuelo + 18):
        s, a = nuevo(), nuevo()
        lomo = (A[0], A[1] - rad * 1.1)
        for i, v in enumerate(vict):
            e = f - 4 - i
            pecho = (v[0], v[1] - 10)
            if 0 <= e < vuelo:
                u = (e + 1) / vuelo
                x, y = lomo[0] + (pecho[0] - lomo[0]) * u, lomo[1] + (pecho[1] - lomo[1]) * u - 30 * 4 * u * (1 - u)
                gota(a, x, y, 5.0)
            elif e >= vuelo:
                g = e - vuelo
                if g < 2:
                    estrella(a, pecho[0], pecho[1], (12, 7)[g], GEL)
                salpica[i].pintar(s, a, pecho[0], pecho[1], min(1.0, g / 4.0), 1.0, 1.0, 99)
                if pedazos:
                    # el destronado: el pedazo se queda en el suelo, rebota y tiembla
                    px, py = v[0] + 6 + i * 2, v[1] + 6
                    rebote = abs(math.sin(min(g, 6) * 1.2)) * max(0, 6 - g) * 0.8
                    tiembla = (g % 2) if g > 6 else 0
                    sombra(s, px, py + 1, 4.5)
                    gota(a, px + tiembla, py - 3 - rebote, 3.6)
                elif 4 <= g < 4 + vuelo:
                    u = (g - 4 + 1) / vuelo
                    x, y = pecho[0] + (lomo[0] - pecho[0]) * u, pecho[1] + (lomo[1] - pecho[1]) * u - 20 * 4 * u * (1 - u)
                    gota(a, x, y, 3.0)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- MAREA CORROSIVA: tres anillos de baba que se abren desde el Rey, uno por tramo, con sus gotas; el suelo queda mojado ---
def marea(var=REY):
    A = (W * 0.5, H * 0.5)
    R = 120.0 / UNIDAD * 0.85
    rad = rad_de(var)
    vict = [(A[0] + R * 0.45, A[1] - R * 0.1), (A[0] - R * 0.7, A[1] + R * 0.2), (A[0] + R * 0.15, A[1] + R * 0.7), (A[0] - R * 0.2, A[1] - R * 0.6)]
    gotas = [Gotas(14, 30 + k, 0.0, 0.0, sube=(6.0, 12.0), tam=(1.2, 2.0)) for k in range(3)]
    m, t = [], []
    for f in range(26):
        s, a = nuevo(), nuevo()
        d = np.hypot(XX - A[0], YY - A[1])
        mojado = 0.0
        for k in range(3):
            e = f - 2 - k * 4
            if e < 0:
                continue
            u = min(1.0, (e + 1) / 9.0)
            r = rad * 0.8 + (R - rad * 0.8) * u
            mojado = max(mojado, r)
            if u < 1.0:
                ep.banda(s, A[0], A[1], r, 6.0, GEL, False, e + k)
                for ang, _d, sube, tam, t0 in gotas[k].g:
                    x, y = A[0] + math.cos(ang) * r, A[1] + math.sin(ang) * r - abs(math.sin(e * 0.9 + ang * 3)) * 6
                    gota(a if math.sin(ang) > -0.2 else s, x, y, tam)
        if mojado > 0:
            vivo = seco(f, 18, 7)
            poner(s, (d < mojado) & (d > rad * 0.6) & (TRAMA < 0.12 * vivo), GEL[0])
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'escupir', min(f, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- INVOCACION: se hincha y le brotan bolas de gel que vuelan en arco y, al caer, NACEN como slimes ---
def invocacion(var=REY):
    A = (W * 0.45, H * 0.45)
    rad = rad_de(var)
    sitios = [(A[0] + rad + 30, A[1] + 30), (A[0] - rad - 20, A[1] + 40), (A[0] + 20, A[1] + rad + 40)]
    m, t = [], []
    carga, vuelo = 5, 6
    for f in range(carga + vuelo + 12):
        s, a = nuevo(), nuevo()
        cuerpos = []
        if f < carga:
            anim, fr = 'inflar', f + 2
        else:
            anim, fr = 'brote', min(f - carga, 7)
        lomo = (A[0], A[1] - rad * 1.1)
        for i, (px, py) in enumerate(sitios):
            e = f - carga - i
            if 0 <= e < vuelo:
                u = (e + 1) / vuelo
                x, y = lomo[0] + (px - lomo[0]) * u, lomo[1] + (py - 6 - lomo[1]) * u - 34 * 4 * u * (1 - u)
                gota(a, x, y, 4.5)
                sombra(s, px, py, 3 + 4 * u)
            elif e >= vuelo:
                g = e - vuelo
                if g < 2:
                    estrella(a, px, py - 6, (10, 6)[g], GEL)
                cria = marco('s100', 'nacer', min(g, 7), 0)
                r_, g_, b_, a_ = cria.split()
                cuerpos.append((Image.merge('RGBA', (b_, g_, r_, a_)), px, py, 0))   # (en la lamina, en su azul: sus hojas son rojas)
        m.append(escena([s], [(marco(var, anim, fr, 0), A[0], A[1], 0)] + cuerpos, [a]))
        t.append(1000 // 12)
    return m, t


# --- TIRANO: el DECRETO (sobre la cabeza del señalado se forma una coronita de cristal: las motas se juntan, late y se
# deshace en motas que le caen encima) y el TRIBUTO (el cristal del subdito caido sube y vuela en arco hasta el rey) ---
def coronita(a, x, y, tam, pal=CRISTAL):
    base = int(tam * 3)
    for i in range(-base, base + 1):
        punto(a, x + i, y, pal[1])
        punto(a, x + i, y + 1, pal[0])
    for k in (-1, 0, 1):
        alto = int(tam * (3 if k == 0 else 2))
        for j in range(alto):
            punto(a, x + k * base * 0.8, y - 1 - j, pal[2] if j < alto - 1 else pal[3])
    punto(a, x, y - 1, pal[3])


def decreto(var=TIRANO):
    A = (W * 0.38, H * 0.5)
    rad = rad_de(var)
    V = (A[0] + rad + 46, A[1] + 18)
    rnd = random.Random(5)
    motas = [(rnd.uniform(0, math.tau), rnd.uniform(14, 26)) for _ in range(10)]
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        cabeza = (V[0], V[1] - 24)
        if f < 6:
            k = f / 6.0
            for ang, d in motas:
                punto(a, cabeza[0] + math.cos(ang + k * 2) * d * (1 - k), cabeza[1] + math.sin(ang + k * 2) * d * (1 - k) * 0.6, CRISTAL[2], 2)
        elif f < 12:
            late = 1.0 + 0.25 * (f % 2)
            coronita(a, cabeza[0], cabeza[1], 2.0 * late)
            if f == 6:
                estrella(a, cabeza[0], cabeza[1] - 3, 9, CRISTAL)
        else:
            g = f - 12
            for ang, d in motas[:7]:
                punto(a, cabeza[0] + math.cos(ang) * 5, cabeza[1] + g * 2.5 + math.sin(ang) * 2, CRISTAL[2 if g < 3 else 1], 2)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'decreto', min(f, 7), 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def tributo(var=TIRANO):
    A = (W * 0.36, H * 0.5)
    rad = rad_de(var)
    C = (A[0] + rad + 60, A[1] + 30)       # el subdito caido
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        charco(s, C[0], C[1], 7, 2.0, seco(f, 10, 5))
        if f < 3:
            cristal(a, C[0], C[1] - 4 - f * 3, 0.0, -1.0, 6, 2.0, CRISTAL)
        elif f < 11:
            u = (f - 2) / 8.0
            lomo = (A[0], A[1] - rad * 1.2)
            x, y = C[0] + (lomo[0] - C[0]) * u, C[1] - 10 + (lomo[1] - C[1] + 10) * u - 40 * 4 * u * (1 - u)
            ux, uy = (lomo[0] - C[0]), (lomo[1] - C[1])
            n = math.hypot(ux, uy) or 1
            cometa_dir(a, x, y, ux / n, uy / n - (1 - 2 * u) * 0.8, 12, 1, CRISTAL)
            cristal(a, x, y, ux / n, uy / n, 6, 2.0, CRISTAL)
        elif f < 13:
            estrella(a, A[0], A[1] - rad * 1.2, (14, 8)[f - 11], CRISTAL)
        m.append(escena([s], [(marco(var, 'idle', f % 8, 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# --- DESTRONADO: ESQUIRLAS DE LA CORONA (trozos de cristal que salen de lo alto en abanico, girando con su estela; al caer
# estallan en un destello y motas), las CLAVADAS (una vuela en arco y se queda clavada de punta, brillando a ratos) ---
def esquirlas_corona(fila, var=DESTRONADO):
    dx, dy = DIRS[fila]
    R = 90.0 / UNIDAD * 0.9
    A = (W * 0.5 - dx * R * 0.4, H * 0.52 - dy * R * 0.35)
    rad = rad_de(var)
    corona = (A[0], A[1] - rad * 1.25)
    eje = math.atan2(dy, dx)
    rnd = random.Random(3 + fila)
    lista = [(eje + rnd.uniform(-1, 1) * math.radians(60) * 0.45, rnd.uniform(0.55, 1.0), rnd.uniform(0, 6)) for _ in range(9)]
    vict = [(A[0] + math.cos(eje + k) * max(R * 0.8, rad + 16), A[1] + math.sin(eje + k) * max(R * 0.8, rad + 16) + 3) for k in (-0.25, 0.25)]
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        e = f - 3
        if e >= 0:
            k = min(1.0, (e + 1) / 7.0)
            for ang, uu, gi in lista:
                fx, fy = A[0] + math.cos(ang) * R * uu, A[1] + math.sin(ang) * R * uu
                x = corona[0] + (fx - corona[0]) * k
                y = corona[1] + (fy - corona[1]) * k - 26 * 4 * k * (1 - k)
                if k < 1.0:
                    cristal(a, x, y, math.cos(gi + e * 1.4), math.sin(gi + e * 1.4), 6, 2.0, CRISTAL)
                else:
                    g = e - 6
                    if g < 2:
                        estrella(a, fx, fy - 3, (8, 5)[g], CRISTAL)
                    for q in range(4):
                        if g < 6:
                            punto(a, fx + math.cos(q * 1.6) * (2 + g * 1.5), fy - g * 1.2 + math.sin(q * 1.6), CRISTAL[2], 2)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'esquirlas', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def clavadas(var=DESTRONADO):
    A = (W * 0.38, H * 0.48)
    rad = rad_de(var)
    corona = (A[0], A[1] - rad * 1.25)
    sitios = [(A[0] + rad + 40, A[1] + 26), (A[0] + rad + 20, A[1] + 50), (A[0] - 10, A[1] + rad + 34)]
    m, t = [], []
    for f in range(20):
        s, a = nuevo(), nuevo()
        for i, (px, py) in enumerate(sitios):
            e = f - i * 2
            if e < 0:
                continue
            if e < 6:
                u = (e + 1) / 6.0
                x, y = corona[0] + (px - corona[0]) * u, corona[1] + (py - 6 - corona[1]) * u - 30 * 4 * u * (1 - u)
                cristal(a, x, y, (px - corona[0]) / 60, 0.6 + u, 7, 2.0, CRISTAL)
            else:
                g = e - 6
                if g == 0:
                    estrella(a, px, py - 4, 7, CRISTAL)
                sombra(s, px, py + 1, 3.0)
                cristal(a, px, py - 5, 0.15, -1.0, 9, 2.2, CRISTAL)
                if (g + i) % 5 == 0:
                    punto(a, px - 1, py - 9, CRISTAL[3], 2)
        if f >= 16:   # la de mas cerca la pisan: se parte en motas
            pass
        m.append(escena([s], [(marco(var, 'idle', f % 8, 0), A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    gel()
    ba = {d: sl.basico(d, REY, rad_de(REY) + 16.0) for d in (1, 4)}
    ap = aplastamiento()
    es = escision()
    ma = marea()
    inv = invocacion()
    de = decreto()
    tr = tributo()
    eq = {d: esquirlas_corona(d) for d in (0, 2, 4)}
    cl = clavadas()
    pe = escision(DESTRONADO, True)
    filas = [
        *[('REY SLIME\nbasico\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        ('REY SLIME\nAplastamiento\n(tirano y destronado:\nigual)', elegir(ap[0], (3, 9, 12, 14, 17, 26))),
        ('REY SLIME\nEscision\n(tirano: igual)', elegir(es[0], (4, 7, 10, 12, 16, 21))),
        ('REY SLIME\nMarea corrosiva\n(tirano y destronado:\nigual)', elegir(ma[0], (3, 6, 9, 13, 17, 24))),
        ('REY SLIME\nInvocacion', elegir(inv[0], (3, 7, 10, 12, 15, 21))),
        ('REY TIRANO\nDecreto', elegir(de[0], (1, 4, 6, 9, 13, 16))),
        ('REY TIRANO\nTributo\n(el subdito caido)', elegir(tr[0], (1, 4, 6, 8, 11, 12))),
        *[('REY DESTRONADO\nEsquirlas de la corona\nhacia el ' + NOM_DIR[d], elegir(eq[d][0], (3, 5, 7, 9, 11, 15))) for d in (0, 2, 4)],
        ('REY DESTRONADO\nlas clavadas', elegir(cl[0], (2, 5, 7, 9, 12, 18))),
        ('REY DESTRONADO\nEscision: los pedazos\nse quedan temblando', elegir(pe[0], (4, 8, 11, 14, 18, 26))),
    ]
    lienzo_lamina(filas, os.path.join(SALIDA, 'rey_slime.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], ap, es, ma, inv, de, tr, eq[2], cl, pe]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'rey_slime.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
