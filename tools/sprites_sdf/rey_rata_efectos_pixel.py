#!/usr/bin/env python3
# ============================================================
#  rey_rata_efectos_pixel.py -- LOS EFECTOS DEL REY RATA (y sus mutantes, el Rey de las cloacas y el Rey del desguace)
#  EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art). Los mismos que hoy pintan BestiaAire (mordiscos, Chillido,
#  Yugular) y ReyRataAire (lo que eligio el jefe el 31/10: el AGUJERO de la Llamada como la GRIETA de los brotes, el
#  CAMPANAZO y la CHATARRA del Tapazo, las CHISPAS del Frente blindado y la FURIA), con las piezas de la rata.
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/rey_rata_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image

import slime_efectos_pixel as sl
import slime_veneno_efectos_pixel as vn
import escarabajo_efectos_pixel as ep
import rata_efectos_pixel as rt
from slime_efectos_pixel import (W, H, XX, YY, TRAMA, UNIDAD, SALIDA, nuevo, poner, punto, disco, estrella, cometa_dir,
                                 victima, gota, charco, seco, Gotas, lamina, elegir, coletazo, DIRS, NOM_DIR)
from rata_efectos_pixel import marco, escena, mandibula, bocado, SANGRE, SANGRE_BORDE, HUESO

REY, CLOACAS, DESGUACE, RATA = 'rata_rey_sdf', 'rata_sdf_cloacas', 'rata_sdf_desguace', 'rata_sdf'
HIERRO = ep.HIERRO
NARANJA = [(120, 40, 10), (230, 110, 30), (255, 180, 70), (255, 240, 180)]
OXIDO = [(70, 34, 20), (140, 70, 36), (190, 110, 60), (230, 170, 120)]
SONIDO = [(70, 70, 84), (130, 132, 150), (196, 198, 214), (246, 246, 255)]
GRIETA_C = (14, 12, 16)
ROJO_OJO = [(120, 10, 10), (230, 30, 30), (255, 110, 90), (255, 220, 200)]


def rad_de(var):
    return marco(var, 'idle', 0, 1).size[0] * 0.25


def sangre(n, sem, eje, tam=(1.2, 2.0)):
    return Gotas(n, sem, 6.0, 18.0, (eje, 0.8), sube=(5.0, 12.0), tam=tam, pal=SANGRE, borde=SANGRE_BORDE)


# --- DENTELLADA REAL: un bocado a cada uno que pilla en su cono, uno tras otro, y la sangre que salta ---
def dentellada(fila, var=REY):
    dx, dy = DIRS[fila]
    rad = rad_de(var)
    A = (W * 0.5 - dx * 18, H * 0.52 - dy * 16)
    eje = math.atan2(dy, dx)
    vict = [(A[0] + math.cos(eje + k) * (rad + 14), A[1] + math.sin(eje + k) * (rad + 14) + 6) for k in (-0.55, 0.0, 0.55)]
    gs = [sangre(6, 3 + i, math.atan2(v[1] - A[1], v[0] - A[0])) for i, v in enumerate(vict)]
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        for i, v in enumerate(vict):
            e = f - 2 - i * 2
            if e < 0:
                continue
            ddx, ddy = v[0] - A[0], v[1] - A[1]
            n = math.hypot(ddx, ddy) or 1
            if e < 5:
                bocado(s, a, v, ddx / n, ddy / n, min(e, 4))
            if e >= 3:
                gs[i].pintar(s, a, v[0], v[1] - 2, min(1.0, (e - 3) / 5.0), 2.0, 1.0, e - 8)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'dentellada', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- CHILLIDO: ondas de sonido en el cono, en dos tramos: bandas gruesas que se abren y se deshacen (nada de rayas), y
# a quien le llega, el sonido le vibra alrededor ---
def chillido(fila, var=REY):
    dx, dy = DIRS[fila]
    R = 100.0 / UNIDAD * 0.8
    rad = rad_de(var)
    A = (W * 0.5 - dx * R * 0.45, H * 0.52 - dy * R * 0.4)
    eje = math.atan2(dy, dx)
    boca = (A[0] + dx * rad * 0.9, A[1] + dy * rad * 0.6 - 4)
    vict = [(A[0] + math.cos(eje + k) * R * u, A[1] + math.sin(eje + k) * R * u + 4) for k, u in ((-0.5, 0.45), (0.3, 0.55), (0.0, 0.9))]
    mitad = math.radians(120) * 0.5
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        d = np.hypot(XX - boca[0], YY - boca[1])
        ang = np.arctan2(YY - boca[1], XX - boca[0])
        rel = np.abs((ang - eje + np.pi) % (2 * np.pi) - np.pi)
        for k in range(4):
            e = f - 1 - k * 2.5
            if e < 0:
                continue
            r = 8 + e * 6.0
            if r > R:
                continue
            fuerza = 1.0 - r / R
            borde = np.abs(d - r)
            en = (rel < mitad * (0.4 + 0.6 * min(1.0, r / 30.0))) & (borde < 2.2)
            poner(a, en & (TRAMA < fuerza * 1.4), SONIDO[1])
            poner(a, en & (borde < 1.0) & (TRAMA < fuerza * 1.6), SONIDO[2])
            poner(a, en & (borde < 0.6) & (rel < mitad * 0.3) & (fuerza > 0.5), SONIDO[3])
        for i, v in enumerate(vict):
            llega = f - 1 - int(math.hypot(v[0] - boca[0], v[1] - boca[1]) / 6.0)
            if 0 <= llega < 7:
                tiembla = (llega % 2) * 2 - 1
                for lado in (-1, 1):
                    for j in range(-3, 4):
                        punto(a, v[0] + lado * (8 + abs(j) * 0.3) + tiembla, v[1] - 10 + j * 1.3, SONIDO[2 if abs(j) < 2 else 1], 2 if abs(j) < 2 else 1)
        for v in vict:
            victima(s, *v)
        m.append(escena([s], [(marco(var, 'chillido', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- A LA YUGULAR: se lanza por su linea dejando el polvo del salto, le muerde el cuello y lo ZARANDEA ---
def yugular(fila, var=REY):
    dx, dy = DIRS[fila]
    L = 55.0 / UNIDAD
    A = (W * 0.5 - dx * L * 0.55, H * 0.55 - dy * L * 0.5)
    rad = rad_de(var)
    V = (A[0] + dx * (L + 4), A[1] + dy * (L + 4) + 6)
    sg = sangre(10, 7 + fila, math.atan2(dy, dx), (1.2, 2.2))
    m, t = [], []
    corre = 4
    for f in range(corre + 14):
        s, a = nuevo(), nuevo()
        u = min(1.0, (f + 1) / float(corre))
        x, y = A[0] + dx * (L - rad) * u, A[1] + dy * (L - rad) * u
        ep._huellas_polvo(s, A[0], A[1], dx, dy, (L - rad) * u, 13, 7.0)
        if f < corre:
            anim, fr = 'yugular', f * 2
        else:
            e = f - corre
            anim, fr = 'zarandeo', e
            sacude = (e % 2) * 2 - 1
            x += -dy * sacude * 1.5
            y += dx * sacude * 1.5
            if e < 4:
                bocado(s, a, V, dx, dy, min(e + 1, 4))
            if e >= 1:
                sg.pintar(s, a, V[0], V[1] - 4, min(1.0, (e - 1) / 7.0), 2.0, 1.0, e - 9)
        victima(s, *V)
        m.append(escena([s], [(marco(var, anim, fr, fila), x, y, 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LA LLAMADA (cloacas y desguace): el suelo se RAJA junto al rey como en los brotes: grietas que corren, el boquete se
# abre, salen sus ratas y se vuelve a cerrar ---
def grieta_suelo(s, x, y, k, sem, cierra=0.0):
    rnd = random.Random(sem)
    for i in range(6):
        ang = i / 6 * math.tau + rnd.uniform(-0.3, 0.3)
        px, py = x, y
        largo = 22 * k * (1 - cierra)
        pasos = int(largo / 2.5)
        for p in range(pasos):
            ang += rnd.uniform(-0.5, 0.5)
            px, py = px + math.cos(ang) * 2.5, py + math.sin(ang) * 2.5 * 0.8
            punto(s, px, py, GRIETA_C, 2)
            if p == pasos // 2 and rnd.random() < 0.6:   # una rama
                bx, by, ba = px, py, ang + rnd.choice((-1, 1)) * 0.9
                for q in range(int(pasos * 0.4)):
                    bx, by = bx + math.cos(ba) * 2.5, by + math.sin(ba) * 2.0
                    punto(s, bx, by, GRIETA_C, 1 if q > 2 else 2)


def boquete(s, x, y, r):
    if r < 1:
        return
    m = ((XX - x) / r) ** 2 + ((YY - y) / (r * 0.6)) ** 2
    poner(s, m <= 1.25, (40, 36, 34))
    poner(s, m <= 1.0, GRIETA_C)
    poner(s, (m <= 1.0) & (YY < y - r * 0.25), (6, 5, 8))


def llamada(var=CLOACAS):
    A = (W * 0.35, H * 0.45)
    rad = rad_de(var)
    G = (A[0] + rad + 30, A[1] + 22)
    salidas = [(G[0] + 26, G[1] - 14), (G[0] + 18, G[1] + 20)]
    m, t = [], []
    for f in range(26):
        s, a = nuevo(), nuevo()
        cuerpos = [(marco(var, 'chillido' if f < 8 else 'idle', min(f, 7) if f < 8 else f % 8, 1), A[0], A[1], 0)]
        k = min(1.0, (f + 1) / 6.0)
        cierra = 0.0 if f < 18 else (f - 18) / 7.0
        grieta_suelo(s, G[0], G[1], k, 5, cierra)
        hueco = (min(1.0, max(0.0, (f - 4) / 3.0)) * (1 - cierra)) * 8.0
        boquete(s, G[0], G[1], hueco)
        if 6 <= f <= 8:
            for q in range(6):
                ang = q / 6 * math.tau
                ep.bolita(a, G[0] + math.cos(ang) * (5 + (f - 6) * 3), G[1] + math.sin(ang) * (3 + (f - 6) * 2) - (f - 6) * 2, 2.5, ep.POLVO)
        for i, (sx, sy) in enumerate(salidas):
            e = f - 8 - i * 3
            if 0 <= e:
                u = min(1.0, e / 6.0)
                x, y = G[0] + (sx - G[0]) * u, G[1] + (sy - G[1]) * u
                fila = 1 if i else 3
                cuerpos.append((marco(RATA, 'walk', e, fila), x, y, 0))
        m.append(escena([s], cuerpos, [a]))
        t.append(1000 // 12)
    return m, t


# --- EL TAPAZO (desguace): al tocar, el CAMPANAZO (un aro de metal que se abre desde la tapa como una onda de sonido, con
# chispas naranjas) y la CHATARRA (tornillos, remaches y oxido que saltan hacia donde empuja, caen y se quedan un momento) ---
def tornillo(a, x, y, giro, pal):
    c, s_ = math.cos(giro), math.sin(giro)
    for j in range(-2, 3):
        punto(a, x + c * j, y + s_ * j, pal[1] if j else pal[2])
    punto(a, x + c * 2, y + s_ * 2, pal[3])
    punto(a, x - c * 2 - s_, y - s_ * 2 + c, pal[0])


def tapazo(fila, var=DESGUACE):
    dx, dy = DIRS[fila]
    rad = rad_de(var)
    A = (W * 0.5 - dx * 22, H * 0.54 - dy * 18)
    tapa = (A[0] + dx * rad * 0.9, A[1] + dy * rad * 0.6 - 6)
    V0 = (A[0] + dx * (rad + 12), A[1] + dy * (rad + 12) + 6)
    rnd = random.Random(4 + fila)
    trozos = [(math.atan2(dy, dx) + rnd.uniform(-0.9, 0.9), rnd.uniform(12, 30), rnd.uniform(8, 18), rnd.uniform(0, 6), rnd.random() < 0.6) for _ in range(9)]
    m, t = [], []
    golpe = 5
    for f in range(golpe + 16):
        s, a = nuevo(), nuevo()
        e = f - golpe
        empuje = 0 if e < 0 else min(1.0, (e + 1) / 3.0) * 12
        V = (V0[0] + dx * empuje, V0[1] + dy * empuje)
        if e >= 0:
            if e < 6:
                ep.banda(a, tapa[0], tapa[1], 6 + e * 5.0, 5.0 * (1 - e / 7.0) + 1.5, HIERRO, True, e)
            if e < 2:
                estrella(a, tapa[0], tapa[1], (14, 9)[e], HIERRO)
            if e < 5:
                ep.chispas(a, tapa[0], tapa[1], NARANJA, e * 7 + fila, 5)
            for ang, dist, sube, gi, es_t in trozos:
                k = min(1.0, (e + 1) / 6.0)
                x = tapa[0] + math.cos(ang) * dist * k
                y = tapa[1] + 6 + math.sin(ang) * dist * k * 0.8 - sube * 4 * k * (1 - k)
                queda = seco(e, 9, 4)
                if queda <= 0:
                    continue
                if es_t:
                    tornillo(a if k < 1 else s, x, y, gi + (0 if k >= 1 else e * 1.5), HIERRO)
                else:
                    punto(a if k < 1 else s, x, y, OXIDO[1], 2)
                    punto(a if k < 1 else s, x, y, OXIDO[2], 1)
        victima(s, *V)
        m.append(escena([s], [(marco(var, 'tapazo', min(f, 8), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- EL FRENTE BLINDADO (desguace): le pegas por delante y la chatarra se lo come: chispas naranjas de la tapa hacia quien
# pega y un brillo de metal en el borde ---
def frente(fila=1, var=DESGUACE):
    dx, dy = DIRS[fila]
    rad = rad_de(var)
    A = (W * 0.5 - dx * 16, H * 0.54 - dy * 14)
    tapa = (A[0] + dx * rad * 0.9, A[1] + dy * rad * 0.6 - 6)
    V = (A[0] + dx * (rad + 16), A[1] + dy * (rad + 16) + 6)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        e = f - 2
        if e >= 0 and e < 6:
            if e < 2:
                estrella(a, tapa[0], tapa[1], (10, 6)[e], HIERRO)
            rnd = random.Random(9)
            for q in range(7):
                ang = math.atan2(dy, dx) + rnd.uniform(-0.8, 0.8)
                d = 3 + e * rnd.uniform(3, 5)
                x, y = tapa[0] + math.cos(ang) * d, tapa[1] + math.sin(ang) * d * 0.8 - math.sin(e * 0.5) * 3
                cometa_dir(a, x, y, math.cos(ang), math.sin(ang) * 0.8, 5, 0, NARANJA)
        victima(s, *V)
        img = escena([s], [(marco(var, 'idle', f % 8, fila), A[0], A[1], 0)], [a])
        if 1 <= f <= 4:
            # el brillo del borde de la tapa
            arr = np.array(img)
            for j in range(-5, 6):
                x = int(tapa[0] - dy * j)
                y = int(tapa[1] + dx * j)
                if 0 <= x < W and 0 <= y < H:
                    arr[y, x, :3] = HIERRO[3] if abs(j) < 3 else HIERRO[2]
            img = Image.fromarray(arr, 'RGBA')
        m.append(img)
        t.append(1000 // 14)
    return m, t


# --- LA FURIA DE REY (nivel 1-3): le brillan los ojos en rojo y le sale vaho por el hocico, mas cuanto mas nivel ---
def furia(nivel, fila=1, var=CLOACAS):
    dx, dy = DIRS[fila]
    A = (W * 0.5, H * 0.55)
    # el HOCICO medido en su dibujo: el pixel mas adelantado hacia donde mira (no una cuenta a ojo: salia fuera de la cara)
    spr0 = np.array(marco(var, 'idle', 0, fila))
    ys, xs = np.nonzero(spr0[:, :, 3] > 0)
    h0, w0 = spr0.shape[:2]
    delante = (xs - w0 / 2) * dx + (ys - h0 / 2) * dy * 0.7 - (ys - h0 / 2) * 0.3
    i = int(np.argmax(delante))
    hocico = (A[0] + xs[i] - w0 // 2, A[1] + ys[i] - h0 // 2)
    ojo = (hocico[0] - dx * 7, hocico[1] - 3 - dy * 3)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        late = 1 if f % 4 < 2 else 0
        for lado in (-1, 1):
            ox, oy = ojo[0] - dy * lado * 2.5, ojo[1] + dx * lado * 1.5
            disco(a, ox, oy, 0.8 + nivel * 0.3 + late * 0.3, ROJO_OJO[1])
            punto(a, ox, oy, ROJO_OJO[3])
        if nivel >= 3 and late:
            estrella(a, ojo[0], ojo[1], 5, ROJO_OJO)
        for q in range(nivel):
            e = (f + q * 4) % 12
            vn.nube(a, hocico[0] + dx * e * 0.9 + q * 2, hocico[1] - e * 1.5, 2.5 + e * 0.45 * (0.7 + nivel * 0.25), (1.0 - e / 12.0) * 1.6, sl_gris())
        m.append(escena([s], [(marco(var, 'idle', f % 8, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def sl_gris():
    return [(70, 70, 76), (120, 120, 128), (176, 176, 184), (226, 226, 232)]


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: rt.mordisco(d, REY, 'basico') for d in (1, 4)}
    de = {d: dentellada(d) for d in (1, 2, 4)}
    ch = {d: chillido(d) for d in (0, 2, 4)}
    yu = {d: yugular(d) for d in (1, 2, 4)}
    ll = llamada()
    ta = {d: tapazo(d) for d in (1, 2, 4)}
    fr = frente()
    fu = {n: furia(n) for n in (1, 2, 3)}
    filas = [
        *[('REY RATA\nbasico\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 3, 4, 5, 7, 10))) for d in (1, 4)],
        *[('REY RATA\nDentellada real\nhacia el ' + NOM_DIR[d], elegir(de[d][0], (2, 4, 6, 8, 10, 14))) for d in (1, 2, 4)],
        *[('REY RATA\nChillido\nhacia el ' + NOM_DIR[d], elegir(ch[d][0], (1, 3, 5, 8, 11, 15))) for d in (0, 2, 4)],
        *[('REY RATA\nA la yugular\nhacia el ' + NOM_DIR[d], elegir(yu[d][0], (1, 3, 5, 7, 10, 15))) for d in (1, 2, 4)],
        ('CLOACAS y DESGUACE\nla Llamada\n(la grieta)', elegir(ll[0], (2, 5, 8, 12, 17, 23))),
        *[('DESGUACE\nTapazo\nhacia el ' + NOM_DIR[d], elegir(ta[d][0], (3, 5, 6, 8, 11, 16))) for d in (1, 2, 4)],
        ('DESGUACE\nFrente blindado', elegir(fr[0], (1, 2, 3, 4, 6, 9))),
        *[('CLOACAS y DESGUACE\nFuria nivel %d' % n, elegir(fu[n][0], (0, 2, 4, 6, 8, 10))) for n in (1, 2, 3)],
    ]
    lamina(filas, os.path.join(SALIDA, 'rey_rata.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], de[1], ch[2], yu[1], ll, ta[1], ta[2], fr, fu[3]]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'rey_rata.gif'), 3)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
