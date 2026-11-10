#!/usr/bin/env python3
# ============================================================
#  transparencia.py -- TRANSPARENCIA DE VERDAD EN LOS EFECTOS PIXEL, SIN REJILLA (10/11/2026, memoria
#  transparencia-de-verdad). El jefe: "que sean transparentes de verdad, no con pixeles sin poner como una rejilla".
#  Lo que se desvanece se pintaba a TRAMA Bayer ("pixel si, pixel no", TRAMA < fuerza). Sin tocar ni un dibujo: el efecto
#  se pinta 4 VECES con la trama CONSTANTE (0,125 / 0,375 / 0,625 / 0,875) y se promedia. Donde antes salia la mitad de
#  los pixeles, ahora salen TODOS con la mitad de opacidad: cada pixel con su color y 4 ESCALONES de alfa (25/50/75/100 %).
#  Lo macizo (sin trama) sale igual en las 4 pasadas: no cambia.
#    con_alfa(fn, modulos, *args)  -> (marcos, tiempos) como fn, pero sin rejilla
#  'modulos' = los que tienen un TRAMA global que usan las piezas (escarabajo, slime, rata, ciempies, el del enemigo...).
# ============================================================
import numpy as np
from PIL import Image

UMBRALES = (0.125, 0.375, 0.625, 0.875)


def _pasada(fn, modulos, t, args, kw):
    viejos = [m.TRAMA for m in modulos]
    try:
        for m, v in zip(modulos, viejos):
            m.TRAMA = np.full(v.shape, t)
        return fn(*args, **kw)
    finally:
        for m, v in zip(modulos, viejos):
            m.TRAMA = v


def con_alfa(fn, modulos, *args, **kw):
    pasadas = [_pasada(fn, modulos, t, args, kw) for t in UMBRALES]
    marcos0, tiempos = pasadas[0]
    out = []
    for i in range(len(marcos0)):
        suma = None
        for marcos, _t in pasadas:
            im = np.asarray(marcos[min(i, len(marcos) - 1)].convert('RGBA')).astype(np.float32)
            suma = im if suma is None else suma + im
        out.append(Image.fromarray(np.clip(suma / len(pasadas) + 0.5, 0, 255).astype(np.uint8), 'RGBA'))
    return out, tiempos


def capas_con_alfa(fn, modulos, *args, **kw):
    """Para HORNEAR: 'fn' devuelve una lista de capas RGBA (numpy, sin fondo). Devuelve las mismas capas con alfa en 4
    escalones: el color, la media de las pasadas en que el pixel sale; el alfa, en cuantas sale."""
    pasadas = [_pasada(fn, modulos, t, args, kw) for t in UMBRALES]
    out = []
    for i in range(len(pasadas[0])):
        col = np.zeros(pasadas[0][i].shape[:2] + (3,), np.float32)
        n = np.zeros(pasadas[0][i].shape[:2], np.float32)
        for p in pasadas:
            c = np.asarray(p[i]).astype(np.float32)
            hay = c[:, :, 3] > 0
            col[hay] += c[hay, :3]
            n[hay] += 1
        res = np.zeros(pasadas[0][i].shape[:2] + (4,), np.uint8)
        hay = n > 0
        res[hay, :3] = np.clip(col[hay] / n[hay, None] + 0.5, 0, 255).astype(np.uint8)
        res[:, :, 3] = np.round(n / len(pasadas) * 255).astype(np.uint8)
        out.append(res)
    return out


def filas_con_alfa(fn, modulos, *args, **kw):
    """Para HORNEAR con horno_efectos.guardar_efecto: 'fn' devuelve filas = [[(s, a), ...], ...] (capas numpy RGBA). Las
    devuelve igual pero con alfa en 4 escalones (sin rejilla)."""
    pasadas = [_pasada(fn, modulos, t, args, kw) for t in UMBRALES]
    out = []
    for j in range(len(pasadas[0])):
        fila = []
        for i in range(len(pasadas[0][j])):
            capas = []
            for k in range(2):
                col = np.zeros(pasadas[0][j][i][k].shape[:2] + (3,), np.float32)
                n = np.zeros(pasadas[0][j][i][k].shape[:2], np.float32)
                for p in pasadas:
                    c = np.asarray(p[j][i][k]).astype(np.float32)
                    hay = c[:, :, 3] > 0
                    col[hay] += c[hay, :3]
                    n[hay] += 1
                res = np.zeros(col.shape[:2] + (4,), np.uint8)
                hay = n > 0
                res[hay, :3] = np.clip(col[hay] / n[hay, None] + 0.5, 0, 255).astype(np.uint8)
                res[:, :, 3] = np.round(n / len(pasadas) * 255).astype(np.uint8)
                capas.append(res)
            fila.append(tuple(capas))
        out.append(fila)
    return out
