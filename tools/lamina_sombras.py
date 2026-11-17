#!/usr/bin/env python3
"""lamina_sombras.py -- LAMINA PARA ELEGIR la sombra que proyectan las luces (16/11, memoria sombras-fuera-del-sprite).

Dos versiones sobre el personaje y el jabali, con UNA antorcha y con DOS luces de fuerza parecida:
  A) SILUETA REAL: la silueta del propio fotograma, tumbada en el suelo y estirada lejos de cada luz, en tres tonos fijos
     (oscura junto a los pies, clara al final) + la mancha de contacto bajo los pies.
  B) MANCHA ESTIRADA: la elipse de contacto estirada y desplazada lejos de cada luz, en los mismos tres tonos.
Varias luces: cada pixel se queda con el tono MAS OSCURO de las sombras que le caen (tonos fijos, no se suman).

  python tools/lamina_sombras.py   -> Desktop/sombras/lamina_sombras.png
"""
import json
import math
import os

import numpy as np
from PIL import Image, ImageDraw

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
SALIDA = os.path.join(os.path.expanduser('~'), 'Desktop', 'sombras', 'lamina_sombras.png')
TONOS = [0.55, 0.40, 0.25]          # los mismos que SombraSuelo (17/11: la B)
CORTES = [0.55, 0.80, 1.0]
APLASTADO = 0.42
ESC = 4                              # zoom de la lamina
SUELO = (58, 52, 44)


def _hornada(base, anim):
    """Primer fotograma de 'anim' de una hoja horneada del jugador (json + png recortado), en su lienzo."""
    d = json.load(open(base + '.json'))
    im = Image.open(base + '.png').convert('RGBA')
    a = [x for x in d['anims'] if x['n'] == anim][0]
    x, y, w, h, mx, my = a['f'][0]
    lienzo = Image.new('RGBA', (d['w'], d['h']), (0, 0, 0, 0))
    lienzo.paste(im.crop((x, y, x + w, y + h)), (mx, my))
    return lienzo


def personaje():
    p = os.path.join(RAIZ, 'assets/sprites/player/')
    img = _hornada(p + 'cuerpo_1.00', 'idle_1')
    for capa in ('arma_espada_larga_mano_der_1.00',):
        try:
            c = _hornada(p + capa, 'idle_1')
            img = Image.alpha_composite(img, c)
        except Exception:
            pass
    return img, (img.width / 2.0, 67.5)


def jabali():
    c = os.path.join(RAIZ, 'assets/sprites/enemigos/jabali_sdf/')
    d = json.load(open(c + 'hojas.json'))
    W, H = d['lienzo']
    hoja = Image.open(c + 'idle.png').convert('RGBA')
    fila = 1   # una diagonal
    return hoja.crop((0, fila * H, W, fila * H + H)), tuple(d['pies'])


def _sin_sombra_vieja(img):
    a = np.array(img)
    vieja = (a[..., :3].astype(int).sum(-1) == 0) & (a[..., 3] < 100)
    a[vieja] = 0
    return Image.fromarray(a)


def _tono(f):
    for k, c in enumerate(CORTES):
        if f <= c:
            return TONOS[k]
    return 0.0


def contacto(sombra, cx, cy, rx):
    ry = max(1, round(rx * APLASTADO))
    for j in range(int(cy - ry), int(cy + ry) + 1):
        for i in range(int(cx - rx), int(cx + rx) + 1):
            r = math.hypot((i + 0.5 - cx) / rx, (j + 0.5 - cy) / ry)
            if r <= 1.0 and 0 <= j < sombra.shape[0] and 0 <= i < sombra.shape[1]:
                sombra[j, i] = max(sombra[j, i], _tono(r))


def silueta(sombra, img, ox, oy, pies, luz, largo):
    """La silueta del fotograma tumbada en el suelo lejos de 'luz' (en coordenadas de la escena)."""
    a = np.asarray(img)[..., 3]
    px, py = pies
    fx, fy = ox + px, oy + py
    d = np.array([fx - luz[0], (fy - luz[1])])
    d = d / (np.linalg.norm(d) + 1e-6)
    ys, xs = np.nonzero(a > 100)
    if len(ys) == 0:
        return
    hmax = max(1.0, py - ys.min())
    for x, y in zip(xs, ys):
        h = max(0.0, py - y)
        for t in np.arange(0.0, 1.01, 0.5):
            hh = h + t
            sx = fx + (x - px) + d[0] * hh * largo
            sy = fy + d[1] * hh * largo * APLASTADO * 1.6
            i, j = int(round(sx)), int(round(sy))
            if 0 <= j < sombra.shape[0] and 0 <= i < sombra.shape[1]:
                sombra[j, i] = max(sombra[j, i], _tono(h / hmax))


def mancha(sombra, cx, cy, rx, luz, largo):
    d = np.array([cx - luz[0], cy - luz[1]])
    d = d / (np.linalg.norm(d) + 1e-6)
    a = rx + rx * 1.6 * largo
    b = rx * APLASTADO * 1.4
    c = np.array([cx, cy]) + d * (a - rx * 0.6)
    v = np.array([-d[1], d[0]])
    for j in range(sombra.shape[0]):
        for i in range(sombra.shape[1]):
            q = np.array([i + 0.5, j + 0.5]) - c
            r = math.hypot(q.dot(d) / a, q.dot(v) / b)
            if r <= 1.0:
                sombra[j, i] = max(sombra[j, i], _tono(r))


def escena(sujetos, luces, modo, w=230, h=160):
    sombra = np.zeros((h, w))
    capas = []
    x0 = 30
    for (img, pies, rx) in sujetos:
        ox, oy = x0, h - 30 - pies[1]
        fx, fy = ox + pies[0], oy + pies[1]
        for (lx, ly, f) in luces:
            dist = math.hypot(fx - lx, fy - ly)
            largo = max(0.35, min(1.3, 70.0 / dist)) * f
            if modo == 'A':
                silueta(sombra, img, ox, oy, pies, (lx, ly), largo)
            else:
                mancha(sombra, fx, fy, rx, (lx, ly), largo)
        contacto(sombra, fx, fy, rx)
        capas.append((img, int(ox), int(oy)))
        x0 += img.width + 10
    base = Image.new('RGBA', (w, h), SUELO + (255,))
    arr = np.array(base).astype(float)
    arr[..., :3] *= (1.0 - sombra[..., None])
    out = Image.fromarray(arr.astype(np.uint8))
    for (img, ox, oy) in capas:
        out.alpha_composite(img, (ox, oy))
    dr = ImageDraw.Draw(out)
    for (lx, ly, f) in luces:   # la luz: una llama de pixel
        dr.rectangle([lx - 1, ly - 3, lx + 1, ly + 1], fill=(255, 196, 80))
        dr.point([(lx, ly - 4)], fill=(255, 240, 170))
        dr.rectangle([lx - 1, ly + 2, lx + 1, ly + 7], fill=(90, 60, 40))
    return out


def main():
    pj, pj_pies = personaje()
    pj = _sin_sombra_vieja(pj)
    jb, jb_pies = jabali()
    jb = _sin_sombra_vieja(jb)
    sujetos = [(pj, pj_pies, 7.0), (jb, jb_pies, 13.0)]
    luces_1 = [(98, 74, 1.0)]                       # entre los dos
    luces_2 = [(98, 74, 1.0), (14, 140, 1.0)]       # y otra abajo a la izquierda
    filas = [('UNA ANTORCHA', luces_1), ('DOS LUCES', luces_2)]
    cols = [('A) SILUETA REAL', 'A'), ('B) MANCHA ESTIRADA', 'B')]
    celdas = [[escena(sujetos, l, m) for (_, m) in cols] for (_, l) in filas]
    cw, ch = celdas[0][0].width * ESC, celdas[0][0].height * ESC
    marg = 40
    izq = 120
    lam = Image.new('RGB', (izq + 2 * cw + 20, marg + 2 * ch + 20), (24, 22, 26))
    dr = ImageDraw.Draw(lam)
    for c, (t, _) in enumerate(cols):
        dr.text((izq + c * (cw + 10) + 8, 12), t, fill=(240, 236, 220))
    for f, (t, _) in enumerate(filas):
        dr.text((6, marg + f * (ch + 10) + 8), t, fill=(240, 236, 220))
        for c in range(2):
            lam.paste(celdas[f][c].resize((cw, ch), Image.NEAREST), (izq + c * (cw + 10), marg + f * (ch + 10)))
    os.makedirs(os.path.dirname(SALIDA), exist_ok=True)
    lam.save(SALIDA)
    print('lamina:', SALIDA)


if __name__ == '__main__':
    main()
