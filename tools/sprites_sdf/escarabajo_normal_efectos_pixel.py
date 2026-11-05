#!/usr/bin/env python3
# ============================================================
#  escarabajo_normal_efectos_pixel.py -- LOS EFECTOS DEL ESCARABAJO NORMAL (el de hierro) EN PIXEL ART (04/11/2026,
#  memoria efectos-a-pixel-art). La lamina aprobada del escarabajo era solo de sus tres mutantes; estos son los suyos, los
#  que hoy pinta InsectoAire: PALA (el basico: un golpe chato y ancho, la pala empuja, no corta), la Embestida rodante
#  (RODADA en el suelo: la banda de tierra aplastada con su labio y el polvo; ARROLLA en cada uno que atraviesa) y el
#  Caparazon (un reflejo que le barre el lomo y un anillo de polvo a ras del suelo).
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/escarabajo_normal_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image

import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
from slime_efectos_pixel import (W, H, XX, YY, TRAMA, UNIDAD, SALIDA, nuevo, poner, punto, estrella, victima, elegir,
                                 lamina, DIRS, NOM_DIR)
from rata_efectos_pixel import marco, escena

HIERRO, POLVO = ep.HIERRO, ep.POLVO
TIERRA = [(34, 31, 33), (43, 39, 42), (104, 94, 82), (140, 128, 110)]
VAR = 'escarabajo_sdf'


def chispas(a, x, y, sem, n=4):
    ep.chispas(a, x, y, HIERRO, sem, n)


# --- EL BASICO: la pala, una media luna GRUESA y aplastada cruzada a la linea del golpe que se hunde en el cuerpo, con su
# destello de metal y chispas ---
def pala(a, x, y, dx, dy, r, aplasta):
    """Media luna rellena y achatada en la linea del golpe ('aplasta' 0..1 la va hundiendo)."""
    px, py = -dy, dx
    s_ = (XX - x) * dx + (YY - y) * dy
    l_ = (XX - x) * px + (YY - y) * py
    # la curva: una parabola muy abierta, combada hacia delante, que se aplasta al tocar
    comba = (1.0 - (l_ / r) ** 2) * r * 0.35 * (1.0 - aplasta * 0.6)
    grueso = 4.0 * (1.0 - (np.abs(l_) / r) ** 2) + 1.0
    dentro = (np.abs(l_) < r) & (s_ <= comba) & (s_ > comba - grueso)
    borde = s_ - (comba - grueso)
    poner(a, dentro, HIERRO[0])
    poner(a, dentro & (borde > 1.0), HIERRO[1])
    poner(a, dentro & (borde > grueso - 2.2), HIERRO[2])
    poner(a, dentro & (borde > grueso - 1.0) & (np.abs(l_) < r * 0.6), HIERRO[3])


def basico(fila):
    dx, dy = DIRS[fila]
    A = (W * 0.5 - dx * 16, H * 0.55 - dy * 14)
    V = (A[0] + dx * 30, A[1] + dy * 28 + 4)
    m, t = [], []
    for f in range(11):
        s, a = nuevo(), nuevo()
        pecho = (V[0], V[1] - 9)
        e = f - 2
        if 0 <= e < 5:
            ida = (-7.0, -3.5, 0.0, 0.5, 0.5)[e]
            pala(a, pecho[0] + dx * ida, pecho[1] + dy * ida, dx, dy, 9.0, (0, 0, 0.5, 1, 1)[e])
        if e in (2, 3):
            estrella(a, pecho[0], pecho[1], (12, 7)[e - 2], HIERRO)
            chispas(a, pecho[0], pecho[1], f * 7 + fila)
        victima(s, *V)
        m.append(escena([s], [(marco(VAR, 'basico', min(max(f - 1, 0), 5), fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


# --- LA EMBESTIDA RODANTE: se hace bola y rueda por su linea; detras queda la banda de tierra aplastada con su labio a los
# lados y se levanta polvo; a cada uno que atraviesa, el frente redondo de la bola le cruza con destello y chispas ---
def rodada_suelo(s, A, dx, dy, hecho, f, corre, largo):
    s_ = (XX - A[0]) * dx + (YY - A[1]) * dy
    l_ = (XX - A[0]) * (-dy) + (YY - A[1]) * dx
    u = np.clip(s_ / max(largo, 1.0), 0, 1)
    edad = f - u * corre
    vivo = np.clip(1.0 - (edad - 9.0) / 6.0, 0.0, 1.0)
    en = (s_ >= 0) & (s_ <= hecho) & (TRAMA < vivo * 1.1)
    media = 6.0 + np.sin(s_ * 0.3) * 0.6
    poner(s, en & (np.abs(l_) < media) & (TRAMA < 0.7), TIERRA[1])
    poner(s, en & (np.abs(l_) < media) & (np.abs(l_) > media - 1.2), TIERRA[0])
    labio = en & (np.abs(l_) >= media) & (np.abs(l_) < media + 1.6)
    poner(s, labio & (l_ < 0), TIERRA[3])
    poner(s, labio & (l_ >= 0), TIERRA[2])


def rodar(fila):
    dx, dy = DIRS[fila]
    largo = 100.0 / UNIDAD
    A = (W * 0.5 - dx * largo * 0.5, H * 0.55 - dy * largo * 0.45)
    vict = [(A[0] + dx * largo * k - dy * 3, A[1] + dy * largo * k + dx * 3 + 4) for k in (0.4, 0.75)]
    m, t = [], []
    carga, corre = 6, 9
    for f in range(carga + corre + 8):
        s, a = nuevo(), nuevo()
        if f < carga:
            spr, x, y = marco(VAR, 'hacerse_bola', f, fila), A[0], A[1]
        else:
            e = f - carga
            u = min(1.0, (e + 1) / float(corre))
            d = largo * u
            x, y = A[0] + dx * d, A[1] + dy * d
            spr = marco(VAR, 'rodar', e, fila) if e < corre else marco(VAR, 'desenroscarse', e - corre, fila)
            rodada_suelo(s, A, dx, dy, d, e, corre, largo)
            ep._huellas_polvo(s, A[0], A[1], dx, dy, d, 23, 8.0)
            for vx, vy in vict:
                pasa = d - ((vx - A[0]) * dx + (vy - A[1]) * dy)
                if -4.0 < pasa < largo / corre * 2.0:
                    pala(a, vx, vy - 9, dx, dy, 8.0, 0.3)
                    estrella(a, vx, vy - 9, 10 if pasa < 4 else 6, HIERRO)
                    chispas(a, vx - dy * 6, vy - 9 + dx * 6, f * 3, 3)
                    chispas(a, vx + dy * 6, vy - 9 - dx * 6, f * 5, 3)
        capa_v = nuevo()   # los que reciben, ENCIMA de la tierra aplastada (si no, la banda se los comia)
        for v in vict:
            victima(capa_v, *v)
        m.append(escena([s, capa_v], [(spr, x, y, 0)], [a]))
        t.append(1000 // 16)
    return m, t


# --- EL CAPARAZON: se cierra y, cerrado del todo, un REFLEJO le barre el lomo de punta a punta y un anillo de polvo sale a
# ras del suelo ---
def caparazon(fila=1):
    A = (W * 0.5, H * 0.55)
    rnd = random.Random(8)
    motas = [(i / 16.0 * math.tau + rnd.uniform(-0.15, 0.15), rnd.uniform(3.0, 4.5)) for i in range(16)]
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        spr = marco(VAR, 'caparazon', min(f, 7), fila)
        e = f - 6
        if e >= 0:
            for ang, r in motas:
                d = 14.0 + e * 3.2
                rr = r * max(0.0, 1.0 - e / 7.0)
                if rr > 0.7:
                    ep.bolita(s if math.sin(ang) < 0 else a, A[0] + math.cos(ang) * d, A[1] + 6 + math.sin(ang) * d * 0.55, rr, POLVO)
        img = escena([s], [(spr, A[0], A[1], 0)], [])
        if 0 <= e < 5:
            # el reflejo: una franja diagonal clara que cruza su caparazon
            arr = np.array(img)
            w, h = spr.size
            x0, y0 = int(A[0]) - w // 2, int(A[1]) - h // 2
            sp = np.array(spr)
            ys, xs = np.mgrid[0:h, 0:w]
            pos = (xs + ys * 0.6) - (e / 4.0) * (w + h * 0.6)
            franja = (np.abs(pos) < 3.0) & (sp[:, :, 3] > 0) & (sp[:, :, :3].sum(axis=2) > 90)
            sub = arr[y0:y0 + h, x0:x0 + w]
            sub[franja, :3] = HIERRO[3]
            sub[(np.abs(pos) < 5.0) & ~franja & (sp[:, :, 3] > 0) & (sp[:, :, :3].sum(axis=2) > 90), :3] = HIERRO[2]
            img = Image.fromarray(arr, 'RGBA')
        if e == 4:
            ar = nuevo()
            estrella(ar, A[0] + 10, A[1] - 14, 9, HIERRO)
            img.alpha_composite(Image.fromarray(ar, 'RGBA'))
        img.alpha_composite(Image.fromarray(a, 'RGBA'))
        m.append(img)
        t.append(1000 // 12)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    ba = {d: basico(d) for d in (1, 2, 4)}
    ro = {d: rodar(d) for d in range(5)}
    ca = caparazon()
    filas = [
        *[('BASICO (la pala)\nhacia el ' + NOM_DIR[d], elegir(ba[d][0], (1, 2, 3, 4, 5, 8))) for d in (1, 2, 4)],
        *[('EMBESTIDA RODANTE\nhacia el ' + NOM_DIR[d], elegir(ro[d][0], (3, 8, 10, 12, 15, 21))) for d in range(5)],
        ('CAPARAZON', elegir(ca[0], (2, 5, 6, 8, 10, 12))),
    ]
    lamina(filas, os.path.join(SALIDA, 'escarabajo_normal.png'))
    todos, tiempos = [], []
    for marcos, ts in [ba[1], ba[4], ro[1], ro[2], ro[4], ca]:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'escarabajo_normal.gif'), 3)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
