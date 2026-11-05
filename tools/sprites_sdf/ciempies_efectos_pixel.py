#!/usr/bin/env python3
# ============================================================
#  ciempies_efectos_pixel.py -- LOS EFECTOS DEL CIEMPIES CARMESI Y SUS MUTANTES EN PIXEL ART (05/11/2026, memorias
#  efectos-a-pixel-art y ciempies-mutante). Los del normal, los que hoy pinta InsectoAire con lo aprobado el 29/09:
#    FORCIPULAS  dos ganchos que entran por los lados y SE CRUZAN como una tijera, rojo oscuro con filo ambar
#    OLEADA      te pasa por encima y una rafaga de patitas te recorre de arriba abajo, con gotas si entra el veneno
#    APRETON     el Enrosque: dos medias lunas que se cierran sobre la presa, que tiembla
#  Y los de sus mutantes, cada cabeza con SU color (naranja y turquesa):
#    BASICO EN U  primero un gancho de una cabeza y luego otro de la otra, al mismo
#    PINZA        cada cabeza barre SU mitad del cono, hasta encontrarse delante
#    CABEZA LIBRE el mordisco de la que no enrosca
#    DERRUMBE     (Nudo) polvo y piedrecitas mientras se alza; al caer, grietas, onda de polvo y destellos
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/ciempies_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

# EL LIENZO MAS GRANDE: el Nudo y su Derrumbe (r70 = 61 celdas).
W, H = 260, 210
sl.W, sl.H, ep.W, ep.H = W, H, W, H
YY, XX = np.mgrid[0:H, 0:W]
sl.YY, sl.XX, ep.YY, ep.XX = YY, XX, YY, XX
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
sl.TRAMA = ep.TRAMA = TRAMA

import rata_efectos_pixel as rt  # noqa: E402
from slime_efectos_pixel import UNIDAD, SALIDA, nuevo, poner, estrella, cometa_dir, gota, elegir, DIRS, NOM_DIR  # noqa: E402
from rata_efectos_pixel import marco, escena  # noqa: E402

NORMAL, BICEFALO, NUDO = 'ciempies_sdf', 'ciempies_sdf_bicefalo', 'ciempies_sdf_nudo'
GANCHO = [(70, 18, 14), (150, 40, 26), (214, 110, 40), (255, 214, 130)]
NARANJA = [(120, 44, 10), (220, 100, 26), (255, 170, 66), (255, 232, 170)]
TURQUESA = [(12, 70, 74), (30, 140, 136), (100, 210, 190), (220, 255, 240)]
VENENO = [(52, 92, 30), (96, 160, 44), (160, 216, 80), (226, 250, 170)]
TIERRA = [(34, 28, 24), (62, 50, 40), (104, 86, 66), (146, 124, 96)]
POLVO = ep.POLVO


def arco(a, cx, cy, r, punta, barrido, sentido, grueso, pal):
    """Un filo de arco que acaba en 'punta' (angulo) y deja detras 'barrido' radianes: vivo delante, oscuro y a trama detras."""
    dist = np.hypot(XX - cx, YY - cy)
    ang = np.arctan2(YY - cy, XX - cx)
    d = ((ang - punta) * sentido + math.pi) % (2 * math.pi) - math.pi
    u = -d / max(barrido, 0.01)
    en = (u >= 0.0) & (u <= 1.0)
    ancho = grueso * (1.0 - u * 0.75)
    dentro = en & (np.abs(dist - r) < ancho * 0.5) & (TRAMA < (1.0 - u) * 2.0)
    poner(a, dentro, pal[0])
    poner(a, dentro & (u < 0.8), pal[1])
    poner(a, dentro & (u < 0.45), pal[2])
    poner(a, dentro & (u < 0.2) & (np.abs(dist - r) < ancho * 0.28), pal[3])
    return cx + math.cos(punta) * r, cy + math.sin(punta) * r


def gancho(a, x, y, lado, ang, e, n, pal, r=11.0):
    """Un gancho que entra por un lado de la victima y se cierra sobre ella: 'lado' +1/-1; 'ang' = eje del golpe."""
    u = (e + 1) / float(n)
    centro = ang + lado * math.pi / 2
    cx, cy = x + math.cos(centro) * r * 0.75, y + math.sin(centro) * r * 0.75
    salida = centro + math.pi
    punta = salida + lado * (-1.2 + 2.0 * u)
    return arco(a, cx, cy, r, punta, 1.5 * min(1.0, u * 1.6), -lado, 5.0, pal)


def gotas(a, x, y, f, sem, pal=VENENO, n=3):
    rnd = random.Random(sem)
    for _i in range(n):
        ox, vy = rnd.uniform(-7, 7), rnd.uniform(1.0, 1.8)
        gota(a, x + ox, y + rnd.uniform(-5, 2) + f * vy * 2.0, 1.7, pal, pal[0])


def _a_y_v(fila, dist=26.0):
    dx, dy = DIRS[fila]
    A = (W * 0.5 - dx * dist * 0.5, H * 0.56 - dy * dist * 0.45)
    V = (A[0] + dx * dist, A[1] + dy * dist * 0.9 + 3)
    return A, V, dx, dy


# --- EL NORMAL ---
def basico_normal(fila):
    A, V, dx, dy = _a_y_v(fila, 28.0)
    ang = math.atan2(dy, dx)
    m, t = [], []
    for f in range(11):
        s, a = nuevo(), nuevo()
        pecho = (V[0], V[1] - 10)
        e = f - 3
        if 0 <= e < 5:
            gancho(a, pecho[0], pecho[1], 1.0, ang, e, 5, GANCHO)
            gancho(a, pecho[0], pecho[1], -1.0, ang, e, 5, GANCHO)
        if e in (3, 4):
            estrella(a, pecho[0], pecho[1], (11, 7)[e - 3], GANCHO)
        if e >= 3:
            gotas(a, pecho[0], pecho[1] + 2, e - 3, fila * 5 + 1, n=2)
        ep.victima(s, *V)
        m.append(escena([s], [(marco(NORMAL, 'basico', min(max(f - 1, 0), 5), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def _patitas(a, x, y, f, sem, pal, tips=7):
    """La rafaga: patitas que se clavan escalonadas de arriba abajo; la punta clara, y al salir se deshacen."""
    rnd = random.Random(sem)
    for k in range(tips):
        vida = f - k * 0.7
        if vida < 0.0 or vida > 4.0:
            continue
        ox = rnd.uniform(-7.5, 7.5)
        oy = -20.0 + k * (22.0 / tips)
        lado = -1.0 if ox > 0 else 1.0
        largo = 8.0 * (1.0 - vida / 5.0) + 3.0
        cometa_dir(a, x + ox, y + oy, lado * 0.55, 0.85, largo, 2.6, pal)


def oleada(fila, var=NORMAL, pal=GANCHO):
    dx, dy = DIRS[fila]
    largo = 45.0 / UNIDAD
    A = (W * 0.5 - dx * largo * 0.6, H * 0.56 - dy * largo * 0.55)
    V = (A[0] + dx * largo * 0.6 - dy * 2, A[1] + dy * largo * 0.55 + dx * 2 + 3)
    m, t = [], []
    corre = 9
    for f in range(corre + 6):
        s, a = nuevo(), nuevo()
        u = min(1.0, (f + 1) / float(corre))
        d = largo * u
        x, y = A[0] + dx * d, A[1] + dy * d
        ep.victima(s, *V)
        pasa = d - ((V[0] - A[0]) * dx + (V[1] - A[1]) * dy)
        if pasa > -9.0:
            e = int(pasa + 9.0) // 2
            _patitas(a, V[0], V[1], e, 11 + fila, pal)
            if e in (2, 4):
                gotas(a, V[0], V[1] - 8, e - 2, 3 + fila, n=2)
        m.append(escena([s], [(marco(var, 'oleada', f, fila), x, y, 0)], [a]))
        t.append(1000 // 18)
    return m, t


# Las dos medias lunas que se cierran sobre la presa cuando aprieta.
def _apreton(a, x, y, e, pal):
    cierra = (1.0, 0.7, 0.45, 0.45, 0.7)[min(e, 4)]
    r = 15.0 * cierra + 3.0
    arco(a, x, y - 12, r, math.pi * 1.25, 1.6, -1.0, 5.0, pal)
    arco(a, x, y - 12, r, -math.pi * 0.25, 1.6, 1.0, 5.0, pal)
    if e == 2:
        estrella(a, x, y - 12, 8, pal)


def _enrosque_tira(var, sufs, libre=False, pal=GANCHO, muerde=False):
    """Trepa, respira, aprieta y se suelta. 'sufs': las presas, cada una con su ('' o '_b', x relativa); 'libre': lo que no enrosca."""
    plan = [('enroscarse', i) for i in range(6)] + [('enroscado', i) for i in range(3)] + [('apreton', i) for i in range(5)] + \
        [('enroscado', 4), ('desenroscarse', 0), ('desenroscarse', 2), ('desenroscarse', 4), ('desenroscarse', 5)]
    A = (W * 0.5, H * 0.66)
    otro = (A[0] + 44, A[1] - 2)
    m, t = [], []
    for f, (anim, i) in enumerate(plan):
        img = ep.fondo()
        for suf, ox in sufs:
            x = A[0] + ox
            det = marco(var, '%s%s_detras' % (anim, suf), i, 0)
            img.paste(det, (int(x) - det.size[0] // 2, int(A[1]) - det.size[1] // 2), det)
        if libre:
            e = f - 10
            nom = 'libre_muerde' if muerde and 0 <= e < 6 else 'libre_idle'
            li = marco(var, nom, max(e, 0) if nom == 'libre_muerde' else f, 2)
            img.paste(li, (int(A[0]) - li.size[0] // 2, int(A[1]) - li.size[1] // 2), li)
        v = nuevo()
        for _suf, ox in sufs:
            ep.victima(v, A[0] + ox, A[1])
        if muerde:
            ep.victima(v, otro[0], otro[1])
        img.alpha_composite(Image.fromarray(v, 'RGBA'))
        for suf, ox in sufs:
            x = A[0] + ox
            dl = marco(var, '%s%s_delante' % (anim, suf), i, 0)
            img.paste(dl, (int(x) - dl.size[0] // 2, int(A[1]) - dl.size[1] // 2), dl)
        a = nuevo()
        if anim == 'apreton':
            for suf, ox in sufs:
                _apreton(a, A[0] + ox, A[1], i, TURQUESA if suf == '_b' else (NARANJA if var != NORMAL else pal))
        if muerde and 2 <= f - 10 < 5:
            gancho(a, otro[0], otro[1] - 10, 1.0, 0.0, f - 12, 3, TURQUESA)
            if f - 10 == 3:
                estrella(a, otro[0], otro[1] - 10, 9, TURQUESA)
        img.alpha_composite(Image.fromarray(a, 'RGBA'))
        m.append(img)
        t.append(1000 // 12)
    return m, t


# --- EL BASICO EN U ---
def basico_u(fila, var=BICEFALO):
    A, V, dx, dy = _a_y_v(fila, 24.0 if var == BICEFALO else 34.0)
    ang = math.atan2(dy, dx)
    m, t = [], []
    for f in range(11):
        s, a = nuevo(), nuevo()
        p = (V[0], V[1] - 10)
        e1, e2 = f - 2, f - 5
        if 0 <= e1 < 4:
            gancho(a, p[0], p[1], 1.0, ang, e1, 4, NARANJA)
        if e1 == 2:
            estrella(a, p[0], p[1], 9, NARANJA)
        if 0 <= e2 < 4:
            gancho(a, p[0], p[1], -1.0, ang, e2, 4, TURQUESA)
        if e2 == 2:
            estrella(a, p[0], p[1], 10, TURQUESA)
        if e2 >= 2:
            gotas(a, p[0], p[1] + 2, e2 - 2, fila + 4, n=2)
        ep.victima(s, *V)
        m.append(escena([s], [(marco(var, 'basico', min(f, 7), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LA PINZA: cada cabeza barre SU mitad del cono, de fuera a dentro, y se encuentran delante ---
def pinza(fila, var=BICEFALO):
    dx, dy = DIRS[fila]
    R = 40.0 / UNIDAD
    A = (W * 0.5 - dx * R * 0.4, H * 0.58 - dy * R * 0.35)
    ang = math.atan2(dy, dx)
    med = math.radians(60)
    v_centro = (A[0] + dx * R * 0.75, A[1] + dy * R * 0.68 + 3)
    v_lado = (A[0] + math.cos(ang + 0.7) * R * 0.75, A[1] + math.sin(ang + 0.7) * R * 0.68 + 3)
    m, t = [], []
    for f in range(11):
        s, a = nuevo(), nuevo()
        e = f - 2
        if 0 <= e < 4:
            u = (e + 1) / 4.0
            arco(a, A[0], A[1] - 4, R * 0.78, ang - med + med * u, med * min(1.0, u * 1.4), 1.0, 8.0, NARANJA)
            arco(a, A[0], A[1] - 4, R * 0.78, ang + med - med * u, med * min(1.0, u * 1.4), -1.0, 8.0, TURQUESA)
        if e == 3 or e == 4:
            estrella(a, A[0] + dx * R * 0.78, A[1] - 4 + dy * R * 0.78, 12 if e == 3 else 8, NARANJA if e == 3 else TURQUESA)
            estrella(a, v_lado[0], v_lado[1] - 10, 7, TURQUESA)
        if e >= 3:
            gotas(a, v_centro[0], v_centro[1] - 8, e - 3, fila + 9, n=2)
        ep.victima(s, *v_centro)
        ep.victima(s, *v_lado)
        m.append(escena([s], [(marco(var, 'pinza', min(f, 6), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- EL DERRUMBE ---
def _grietas(s, x, y, R, sem, vida):
    """Grietas gruesas que salen del centro, a ras del suelo (aplastadas por la camara), y se apagan a trama."""
    rnd = random.Random(sem)
    for _k in range(9):
        ang = rnd.uniform(0, math.tau)
        px, py = x + math.cos(ang) * R * 0.45, y + math.sin(ang) * R * 0.45 * 0.62
        lar = rnd.uniform(R * 0.3, R * 0.55)
        for i in range(int(lar / 1.5)):
            ang += rnd.uniform(-0.28, 0.28)
            px += math.cos(ang) * 1.5
            py += math.sin(ang) * 1.5 * 0.62
            if rnd.random() < vida * 1.3:
                ep.punto(s, px, py, TIERRA[0], 2)


def derrumbe():
    A = (W * 0.5, H * 0.56)
    R = 70.0 / UNIDAD
    victimas = [(A[0] + 44, A[1] + 18), (A[0] - 40, A[1] + 22)]
    rnd = random.Random(5)
    piedras = [(rnd.uniform(0, math.tau), rnd.uniform(26, 40), rnd.uniform(1.3, 2.4), rnd.uniform(2.0, 3.0)) for _i in range(12)]
    motas = [(i / 22.0 * math.tau + rnd.uniform(-0.12, 0.12), rnd.uniform(3.2, 5.0)) for i in range(22)]
    m, t = [], []
    carga = 10
    for f in range(carga + 7 + 9):
        s, a = nuevo(), nuevo()
        if f < carga:
            spr = marco(NUDO, 'derrumbe_carga', f, 1)
            # tiembla: piedrecitas que saltan a ras del suelo y polvo en la base
            for ang, r, tam, vel in piedras:
                ph = (f * 0.25 * vel + ang) % 1.0
                alto = math.sin(ph * math.pi) * 7.0
                ep.bolita(s, A[0] + math.cos(ang) * r, A[1] + math.sin(ang) * r * 0.62 - alto, tam * 0.8, TIERRA)
        else:
            e = f - carga
            spr = marco(NUDO, 'derrumbe', min(e, 6), 1)
            g = e - 2     # toca en el tercer marco
            if g >= 0:
                _grietas(s, A[0], A[1], R, 3, max(0.0, 1.0 - max(g - 7, 0) / 6.0))
                for ang, rr in motas:
                    d = 30.0 + g * 5.0
                    tam = rr * max(0.0, 1.0 - g / 10.0)
                    if tam > 0.7 and d < R + 6:
                        destino = s if math.sin(ang) < 0 else a
                        ep.bolita(destino, A[0] + math.cos(ang) * d, A[1] + 2 + math.sin(ang) * d * 0.62, tam, POLVO)
            if g in (0, 1):
                for vx, vy in victimas:
                    estrella(a, vx, vy - 12, 11 if g == 0 else 7, TIERRA)
        v = nuevo()
        for vv in victimas:
            ep.victima(v, *vv)
        img = escena([s], [], [])
        img.alpha_composite(Image.fromarray(v, 'RGBA'))
        w, h = spr.size
        img.paste(spr, (int(A[0]) - w // 2, int(A[1]) - h // 2), spr)
        img.alpha_composite(Image.fromarray(a, 'RGBA'))
        m.append(img)
        t.append(1000 // 12)
    return m, t


def lamina(filas, ruta, zoom=4):
    """Recortada a lo que cambia respecto al suelo, fila a fila (a lienzo entero el bicho sale minusculo y no se ve nada)."""
    from PIL import ImageDraw
    fondo = np.array(ep.fondo().convert('RGB')).astype(int)
    recortes = []
    for nombre, marcos in filas:
        x0, y0, x1, y1 = W, H, 0, 0
        for mm in marcos:
            d = np.abs(np.array(mm.convert('RGB')).astype(int) - fondo).sum(axis=2) > 0
            ys, xs = np.nonzero(d)
            if len(xs):
                x0, y0, x1, y1 = min(x0, xs.min()), min(y0, ys.min()), max(x1, xs.max()), max(y1, ys.max())
        recortes.append((nombre, marcos, (max(x0 - 3, 0), max(y0 - 3, 0), min(x1 + 4, W), min(y1 + 4, H))))
    rotulo = 170
    ancho = rotulo + max((c[2] - c[0]) * zoom * len(m) + 4 * len(m) for _, m, c in recortes)
    alto = sum((c[3] - c[1]) * zoom + 8 for _, _, c in recortes)
    img = Image.new('RGB', (ancho, alto), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    y = 0
    for nombre, marcos, c in recortes:
        cw, ch = c[2] - c[0], c[3] - c[1]
        pinta.text((8, y + 8), nombre, fill=(230, 226, 214))
        for i, mm in enumerate(marcos):
            img.paste(mm.convert('RGB').crop(c).resize((cw * zoom, ch * zoom), Image.NEAREST), (rotulo + i * (cw * zoom + 4), y))
        y += ch * zoom + 8
    img.save(ruta)
    print(ruta, img.size)


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    bas = {d: basico_normal(d) for d in (1, 2, 4)}
    ole = {d: oleada(d) for d in (1, 4)}
    enr = _enrosque_tira(NORMAL, [('', 0)])
    bu = {d: basico_u(d) for d in (1, 2, 4)}
    pi = {d: pinza(d) for d in (1, 2, 4)}
    enr_b = _enrosque_tira(BICEFALO, [('', 0)], True, muerde=True)
    filas = [
        *[('NORMAL basico (tijera)\nhacia el ' + NOM_DIR[d], elegir(bas[d][0], (3, 4, 5, 6, 7, 9))) for d in bas],
        *[('NORMAL Oleada\nhacia el ' + NOM_DIR[d], elegir(ole[d][0], (2, 4, 6, 8, 10, 13))) for d in ole],
        ('NORMAL Enrosque', elegir(enr[0], (2, 5, 8, 10, 11, 12))),
        *[('BICEFALO basico en U\nhacia el ' + NOM_DIR[d], elegir(bu[d][0], (2, 4, 5, 6, 7, 8))) for d in bu],
        *[('BICEFALO Pinza\nhacia el ' + NOM_DIR[d], elegir(pi[d][0], (2, 3, 4, 5, 6, 8))) for d in pi],
        ('BICEFALO Enrosque\ny cabeza libre', elegir(enr_b[0], (5, 8, 11, 12, 13, 15))),
    ]
    gifs = [bas[1], ole[1], enr, bu[1], pi[1], enr_b]
    if os.path.exists(os.path.join(rt.RAIZ, 'assets/sprites/enemigos/%s/derrumbe.png' % NUDO)):
        der = derrumbe()
        enr_n = _enrosque_tira(NUDO, [('', -22), ('_b', 34)])
        un = {d: basico_u(d, NUDO) for d in (1, 4)}
        pn = {d: pinza(d, NUDO) for d in (1, 4)}
        filas += [
            ('NUDO Derrumbe\ncarga', elegir(der[0], (0, 3, 6, 9))),
            ('NUDO Derrumbe\ncae', elegir(der[0], (10, 12, 13, 14, 16, 19))),
            ('NUDO Enrosque doble', elegir(enr_n[0], (2, 5, 8, 10, 11, 12))),
            *[('NUDO basico en U\nhacia el ' + NOM_DIR[d], elegir(un[d][0], (2, 4, 5, 6, 7, 8))) for d in un],
            *[('NUDO Pinza\nhacia el ' + NOM_DIR[d], elegir(pn[d][0], (2, 3, 4, 5, 6, 8))) for d in pn],
        ]
        gifs += [der, enr_n, un[1], pn[1]]
    else:
        print('(el Nudo aun no esta horneado: lamina sin el)')
    lamina(filas, os.path.join(SALIDA, 'ciempies.png'))
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'ciempies.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
