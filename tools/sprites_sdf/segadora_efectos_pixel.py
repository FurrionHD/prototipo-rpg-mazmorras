#!/usr/bin/env python3
# ============================================================
#  segadora_efectos_pixel.py -- LOS EFECTOS DE LA SEGADORA Y SUS MUTANTES EN PIXEL ART (05/11/2026, memorias
#  efectos-a-pixel-art y segadora-mutante). Los de la normal, lo aprobado el 29/09:
#    TAJO          el corte de la garra que despliega, con destello y sangre
#    DOBLE GUADAÑA las dos caen, cada una por SU lado
#    ENSARTE       la marca roja a los pies de la presa mientras acecha; al soltar, la estocada, esquirlas que salen POR
#                  DETRAS de la victima y el agujero oscuro de la herida
#  Los de sus mutantes:
#    SIERRA        los mismos golpes con la hoja de METAL; y la SIEGA, un barrido de lado a lado con las dos juntas
#    VENDAVAL      sus golpes sueltan ademas un CORTE DE VIENTO (verde palido, sin tocar el suelo) desde la garra;
#                  el VENDAVAL DE CORTES, tres en abanico; y el corte del salto atras (Vuelo corto)
#  EL CORTE ES LA ESTELA DE LA PUNTA DE LA GARRA (05/11, el jefe: "de donde cojones has puesto el efecto del corte"): la
#  punta sale del modelo 3D cada cuarto de fotograma (sdf_comun.puntas_armas -> tools/salida/sdf/puntas_<var>.json:
#    python segadora_sdf.py puntas tools/salida/sdf/puntas_normal.json
#    SEG_VAR=sierra python segadora_mut_sdf.py puntas tools/salida/sdf/puntas_sierra.json   (y vendaval)
#  y la victima se pone donde LLEGA la garra. Nada en sitios inventados.
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/segadora_efectos_pixel.py
# ============================================================
import json
import math
import os
import random

import numpy as np

import ciempies_efectos_pixel as ce
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt

# EL LIENZO: el Vendaval de cortes llega a 140 (122 celdas).
W, H = 300, 240
YY, XX = np.mgrid[0:H, 0:W]
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
for _m in (ce, ep, sl):
    _m.W, _m.H, _m.YY, _m.XX, _m.TRAMA = W, H, YY, XX, TRAMA

from slime_efectos_pixel import UNIDAD, SALIDA, nuevo, estrella, gota, elegir, DIRS, NOM_DIR  # noqa: E402
from rata_efectos_pixel import marco, escena, SANGRE, HUESO  # noqa: E402

NORMAL, SIERRA, VENDAVAL = 'segadora_sdf', 'segadora_sdf_sierra', 'segadora_sdf_vendaval'
METAL = [(54, 58, 70), (110, 116, 132), (180, 186, 200), (246, 248, 255)]
VIENTO = [(70, 120, 100), (130, 196, 164), (196, 240, 214), (244, 255, 248)]
MARCA = [(96, 10, 14), (170, 24, 28), (230, 60, 52), (255, 160, 140)]
OSCURO = (24, 6, 10)


def _pal(var):
    return HUESO if var == NORMAL else METAL


# ------------------------------------------------------------
#  DONDE ESTA LA HOJA
# ------------------------------------------------------------
_PUNTAS = {}
_LIENZO = {}


def _carga(var):
    if var not in _PUNTAS:
        nom = {NORMAL: 'normal', SIERRA: 'sierra', VENDAVAL: 'vendaval'}[var]
        _PUNTAS[var] = json.load(open(os.path.join(rt.RAIZ, 'tools/salida/sdf/puntas_%s.json' % nom)))
        _LIENZO[var] = tuple(json.load(open(os.path.join(rt.RAIZ, 'assets/sprites/enemigos/%s/hojas.json' % var)))['lienzo'])
    return _PUNTAS[var]


def punta(var, anim, d, fr, g, pos):
    """La punta de la garra 'g' (-1 izquierda, 1 derecha) en el fotograma 'fr' (en cuartos), con el sprite puesto en 'pos'."""
    P = _carga(var)
    fr = round(fr * 4) / 4.0
    q = P.get('%s|%d|%.2f|guadana_%d' % (anim, d, fr, g))
    if q is None:
        return None
    w, h = _LIENZO[var]
    return (int(round(pos[0])) - w // 2 + q[0], int(round(pos[1])) - h // 2 + q[1])


def n_fotos(var, anim):
    P = _carga(var)
    return int(max(float(k.split('|')[2]) for k in P if k.startswith(anim + '|'))) + 1


def impacto(var, anim, d, g, pos, hacia):
    """El cuarto de fotograma en que la garra llega mas lejos hacia donde ataca (ahi esta la victima)."""
    n = n_fotos(var, anim)
    mejor, fr_m = -1e9, 0.0
    for k in range((n - 1) * 4 + 1):
        q = punta(var, anim, d, k / 4.0, g, pos)
        if q is not None:
            v = (q[0] - pos[0]) * hacia[0] + (q[1] - pos[1]) * hacia[1]
            if v > mejor:
                mejor, fr_m = v, k / 4.0
    return fr_m, punta(var, anim, d, fr_m, g, pos)


def estela(a, var, anim, d, g, pos, fr, pal, grueso=6.0, largo=1.5):
    """EL CORTE: por donde ha pasado la punta en el ultimo 'largo' de fotograma; el filo vivo en la punta y detras se
    oscurece y se deshace a trama. Si la hoja casi no se mueve, no hay corte."""
    pts = []
    k = fr - largo
    while k <= fr + 1e-6:
        if k >= 0:
            q = punta(var, anim, d, k, g, pos)
            if q is not None:
                pts.append(q)
        k += 0.25
    if len(pts) < 2 or sum(math.hypot(b[0] - c[0], b[1] - c[1]) for c, b in zip(pts, pts[1:])) < 6:
        return
    total = len(pts) - 1
    for idx in range(total):
        (x0, y0), (x1, y1) = pts[idx], pts[idx + 1]
        pasos = max(2, int(math.hypot(x1 - x0, y1 - y0)))
        for s_ in range(pasos):
            w = s_ / pasos
            x, y = x0 + (x1 - x0) * w, y0 + (y1 - y0) * w
            u = 1.0 - (idx + w) / total          # 0 = la punta, 1 = lo mas viejo
            if u > 0.6 and TRAMA[int(y) % H, int(x) % W] > (1.0 - u) * 2.2:
                continue
            r = grueso * 0.5 * (0.35 + 0.65 * (1.0 - u))
            col = pal[3] if u < 0.12 else pal[2] if u < 0.4 else pal[1] if u < 0.72 else pal[0]
            ep.bolita(a, x, y, r, [col, col, col, col])


def sangre(a, x, y, f, sem, n=3):
    rnd = random.Random(sem)
    for _i in range(n):
        ox, vy = rnd.uniform(-5, 5), rnd.uniform(1.0, 1.9)
        gota(a, x + ox, y + rnd.uniform(-3, 2) + f * vy * 2.0, 1.6, SANGRE, rt.SANGRE_BORDE)


def corte_viento(a, x, y, dx, dy, r, u_vida=0.0):
    """EL CORTE DE VIENTO: una media luna que vuela con la cara hacia donde va; detras se deshace a trama."""
    ep.media_luna(a, x, y, dx, dy, r, VIENTO)
    rnd = random.Random(int(x * 7 + y))
    for _i in range(5):
        k = rnd.uniform(4, 14)
        lado = rnd.uniform(-r * 0.8, r * 0.8)
        if rnd.random() > u_vida:
            ep.punto(a, x - dx * k - dy * lado, y - dy * k + dx * lado, VIENTO[1], 2)


def _dir(fila):
    dx, dy = DIRS[fila]
    return dx, dy * 0.9


def _vuela(a, x0, y0, dx, dy, k, r=9.0):
    """Un corte de viento que sale de (x0, y0) y lleva 'k' fotogramas volando."""
    n = math.hypot(dx, dy) or 1.0
    dx, dy = dx / n, dy / n
    corte_viento(a, x0 + dx * k * 13, y0 + dy * k * 13, dx, dy, r, k / 8.0)


# --- EL TAJO (basico): un brazo se despliega de golpe; su punta corta a la victima ---
def tajo(fila, var=NORMAL, lado=-1, viento=False):
    anim = 'basico' if lado < 0 else 'basico_der'
    pal = _pal(var)
    A = (W * 0.4, H * 0.5)
    hacia = _dir(fila)
    fr_i, q = impacto(var, anim, fila, lado, A, hacia)
    V = (q[0], q[1] + 10)
    n = n_fotos(var, anim)
    m, t = [], []
    for f in range(n + 4):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        if f < n:
            estela(a, var, anim, fila, lado, A, fr, pal)
        e = f - fr_i
        if 0 <= e < 2:
            estrella(a, q[0], q[1], 11 if e < 1 else 7, pal)
        if e >= 0:
            sangre(a, q[0], q[1] + 2, e, fila * 3 + 1, n=2)
        if viento and e >= 0:
            _vuela(a, q[0], q[1], hacia[0], hacia[1], e + 1)
        ep.victima(s, *V)
        m.append(escena([s], [(marco(var, anim, fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 16)
    return m, t


# --- LA DOBLE GUADAÑA: las dos suben y caen, cada una por SU lado ---
def guadana(fila, var=NORMAL, viento=False):
    anim = 'guadanas'
    pal = _pal(var)
    A = (W * 0.4, H * 0.55)
    hacia = _dir(fila)
    imp = {g: impacto(var, anim, fila, g, A, hacia) for g in (-1, 1)}
    n = n_fotos(var, anim)
    m, t = [], []
    for f in range(n + 4):
        s, a = nuevo(), nuevo()
        fr = min(f, n - 1)
        for g in (-1, 1):
            if f < n:
                estela(a, var, anim, fila, g, A, fr, pal, 7.0)
            fr_i, q = imp[g]
            e = f - fr_i
            if 0 <= e < 2:
                estrella(a, q[0], q[1], 10 if e < 1 else 7, pal)
            if e >= 0:
                sangre(a, q[0], q[1] + 2, e, fila + 7 + g, n=2)
            if viento and e >= 0:
                _vuela(a, q[0], q[1], q[0] - A[0], q[1] - A[1], e + 1)
            ep.victima(s, q[0], q[1] + 10)
        m.append(escena([s], [(marco(var, anim, fr, fila), A[0], A[1], 0)], [a]))
        t.append(1000 // 13)
    return m, t


# --- EL ENSARTE: acecha con la marca roja a los pies de la presa; sale de golpe y la atraviesa con la punta ---
def marca(s, x, y, f):
    r = 9.0 + (1.0 if f % 4 < 2 else 0.0)
    d = np.hypot((XX - x) / r, (YY - y) / (r * 0.55))
    ep.poner(s, (d > 0.72) & (d < 1.0) & (TRAMA < 0.9), MARCA[1])
    ep.poner(s, (d > 0.84) & (d < 1.0), MARCA[2])


def ensarte(fila, var=NORMAL, viento=False):
    anim = 'ensarte'
    pal = _pal(var)
    dx, dy = _dir(fila)
    corre = 26.0       # lo que se lanza hasta su presa (en el mapa se mueve el cuerpo)
    A0 = (W * 0.36 - dx * 10, H * 0.5 - dy * 10)
    n = n_fotos(var, anim)

    def pos_de(fr):
        u = min(1.0, max(0.0, (fr - 2.0) / 1.0))
        return (A0[0] + dx * corre * u, A0[1] + dy * corre * u)
    fr_i, _q = impacto(var, anim, fila, 1, pos_de(3.0), (dx, dy))
    q = punta(var, anim, fila, fr_i, 1, pos_de(fr_i))
    V = (q[0] + dx * 4, q[1] + 10)
    m, t = [], []
    acecha = 6
    for f in range(acecha + n + 4):
        s, a = nuevo(), nuevo()
        ep.victima(s, *V)
        if f < acecha:
            marca(s, V[0], V[1], f)
            spr, pos = marco(var, 'acecho', f, fila), A0
        else:
            e = f - acecha
            fr = min(e, n - 1)
            pos = pos_de(fr)
            spr = marco(var, anim, fr, fila)
            if e < n:
                estela(a, var, anim, fila, 1, pos, fr, pal, 5.0, 1.0)
            g = e - fr_i
            if 0 <= g < 2:
                estrella(a, q[0], q[1], 11 if g < 1 else 7, pal)
                rnd = random.Random(fila + e)
                for _i in range(6):
                    k = rnd.uniform(6, 16) + g * 6
                    lado = rnd.uniform(-6, 6)
                    ep.punto(a, q[0] + dx * k - dy * lado, q[1] + dy * k + dx * lado, pal[2], 2)
            if g >= 0:
                ep.bolita(s, q[0] + dx * 2, q[1] + 2, 2.2 if g < 4 else 1.4, [OSCURO, OSCURO, (60, 12, 16), (90, 20, 24)])
                sangre(a, q[0], q[1] + 2, g, fila + 3, n=2)
            if viento and g >= 0:
                _vuela(a, q[0] + dx * 8, q[1] + dy * 8, dx, dy, g + 1, 10.0)
        m.append(escena([s], [(spr, pos[0], pos[1], 0)], [a]))
        t.append(1000 // 13)
    return m, t


# --- LA SIEGA: se yergue y barre de lado a lado con las dos juntas; pilla a todos los que tiene delante ---
def siega(fila, var=SIERRA):
    pal = _pal(var)
    A = (W * 0.45, H * 0.55)
    n = n_fotos(var, 'siega')
    # las victimas, por donde pasa la punta: al principio, en medio y al final del barrido
    camino = [c for c in (punta(var, 'siega', fila, k / 4.0, 1, A) for k in range(4, 17)) if c]
    vics = [camino[int(len(camino) * u)] for u in (0.15, 0.5, 0.85)]
    m, t = [], []
    carga = 5
    for f in range(carga + n + 4):
        s, a = nuevo(), nuevo()
        for v in vics:
            ep.victima(s, v[0], v[1] + 10)
        if f < carga:
            spr = marco(var, 'siega_carga', f, fila)
        else:
            e = f - carga
            fr = min(e, n - 1)
            spr = marco(var, 'siega', fr, fila)
            if e < n:
                for g in (-1, 1):
                    estela(a, var, 'siega', fila, g, A, fr, pal, 8.0, 2.0)
            for k, v in enumerate(vics):
                cuando = 1.0 + k * 1.0
                if 0 <= e - cuando < 1.5:
                    estrella(a, v[0], v[1], 10, pal)
                if e - cuando >= 0.5:
                    sangre(a, v[0], v[1] + 2, e - cuando, k + fila * 3, n=2)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 13)
    return m, t


# --- EL VENDAVAL DE CORTES: las deja caer y salen tres cortes de entre las dos puntas, en abanico ---
def vendaval(fila):
    dx, dy = _dir(fila)
    A = (W * 0.32 - dx * 30, H * 0.5 - dy * 30)
    ang = math.atan2(dy, dx)
    abre = math.radians(20)
    n = n_fotos(VENDAVAL, 'vendaval')
    sale_fr = 4.0
    p1, p2 = punta(VENDAVAL, 'vendaval', fila, sale_fr, -1, A), punta(VENDAVAL, 'vendaval', fila, sale_fr, 1, A)
    O = ((p1[0] + p2[0]) / 2, (p1[1] + p2[1]) / 2)
    largo = 140.0 / UNIDAD
    vics = [(O[0] + math.cos(ang + k * abre) * largo * 0.7, O[1] + math.sin(ang + k * abre) * largo * 0.7) for k in (-1, 0, 1)]
    m, t = [], []
    carga = 5
    for f in range(carga + n + 6):
        s, a = nuevo(), nuevo()
        for v in vics:
            ep.victima(s, v[0], v[1] + 10)
        if f < carga:
            spr = marco(VENDAVAL, 'vendaval_carga', f, fila)
            rnd = random.Random(f)
            for g in (-1, 1):
                q = punta(VENDAVAL, 'vendaval_carga', fila, f % 8, g, A)
                if q is None:
                    continue
                for _i in range(3):
                    aa = rnd.uniform(0, math.tau)
                    d = 14 - (f % 3) * 4
                    ep.punto(a, q[0] + math.cos(aa) * d, q[1] + math.sin(aa) * d * 0.7, VIENTO[2], 2)
        else:
            e = f - carga
            fr = min(e, n - 1)
            spr = marco(VENDAVAL, 'vendaval', fr, fila)
            if e < n:
                for g in (-1, 1):
                    estela(a, VENDAVAL, 'vendaval', fila, g, A, fr, METAL, 6.0, 1.25)
            g_ = e - sale_fr
            if g_ >= 0:
                d = 8 + g_ * 16
                for k in (-1, 0, 1):
                    aa = ang + k * abre
                    if d < largo + 6:
                        corte_viento(a, O[0] + math.cos(aa) * d, O[1] + math.sin(aa) * d, math.cos(aa), math.sin(aa), 11.0,
                                     g_ / 10.0)
                for v in vics:
                    dv = math.hypot(v[0] - O[0], v[1] - O[1])
                    if 0 <= d - dv < 16:
                        estrella(a, v[0], v[1], 10, VIENTO)
                    if d - dv >= 8:
                        sangre(a, v[0], v[1] + 2, (d - dv - 8) / 8, int(v[0]), n=2)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 13)
    return m, t


# --- VUELO CORTO: le pegan, salta atras de un aletazo y lanza un corte desde la garra al que le ha pegado ---
def vuelo_corto(fila=2):
    dx, dy = _dir(fila)
    A = (W * 0.42, H * 0.55)
    V = (A[0] + dx * 30, A[1] + dy * 30 + 3)
    n = n_fotos(VENDAVAL, 'salto_atras')
    sale = 3.0
    m, t = [], []
    for f in range(n + 6):
        s, a = nuevo(), nuevo()
        ep.victima(s, *V)
        atras = min(1.0, f / 3.0) * 20
        pos = (A[0] - dx * atras, A[1] - dy * atras)
        fr = min(f, n - 1)
        spr = marco(VENDAVAL, 'salto_atras', fr, fila)
        if f < n:
            estela(a, VENDAVAL, 'salto_atras', fila, 1, pos, fr, METAL, 5.0, 1.0)
        g = f - sale
        if g >= 0:
            q = punta(VENDAVAL, 'salto_atras', fila, sale, 1, (A[0] - dx * 20, A[1] - dy * 20))
            ox, oy = V[0] - q[0], V[1] - 10 - q[1]
            dd = math.hypot(ox, oy) or 1.0
            k = min(g * 12, dd)
            if k < dd:
                corte_viento(a, q[0] + ox / dd * k, q[1] + oy / dd * k, ox / dd, oy / dd, 9.0, g / 8.0)
            if dd - 12 <= g * 12 < dd + 12:
                estrella(a, V[0], V[1] - 10, 9, VIENTO)
        m.append(escena([s], [(spr, pos[0], pos[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    filas, gifs = [], []

    def fila(nombre, mt, idx):
        filas.append((nombre, elegir(mt[0], idx)))
        gifs.append(mt)

    for d in (1, 2, 4):
        fila('NORMAL tajo (izquierdo)\nhacia el ' + NOM_DIR[d], tajo(d), (1, 2, 3, 4, 5, 6, 8))
    fila('NORMAL tajo (derecho)\nhacia el ESTE', tajo(2, lado=1), (1, 2, 3, 4, 5, 6, 8))
    for d in (1, 4):
        fila('NORMAL Doble guadaña\nhacia el ' + NOM_DIR[d], guadana(d), (1, 2, 3, 4, 5, 6, 8))
    for d in (1, 2):
        fila('NORMAL Ensarte\nhacia el ' + NOM_DIR[d], ensarte(d), (1, 4, 7, 8, 9, 10, 12))
    fila('SIERRA tajo\nhacia el SURESTE', tajo(1, SIERRA), (1, 2, 3, 4, 5, 6, 8))
    fila('SIERRA Doble guadaña\nhacia el SURESTE', guadana(1, SIERRA), (1, 2, 3, 4, 5, 6, 8))
    for d in (1, 4):
        fila('SIERRA Siega\nhacia el ' + NOM_DIR[d], siega(d), (1, 4, 6, 7, 8, 9, 10, 12))
    fila('VENDAVAL tajo + corte\nhacia el SURESTE', tajo(1, VENDAVAL, viento=True), (2, 3, 4, 5, 6, 8, 9))
    fila('VENDAVAL Doble guadaña\n+ cortes', guadana(2, VENDAVAL, viento=True), (2, 3, 4, 5, 6, 8, 10))
    fila('VENDAVAL Ensarte\n+ corte', ensarte(2, VENDAVAL, viento=True), (4, 7, 8, 9, 10, 12, 14))
    for d in (1, 2):
        fila('VENDAVAL Vendaval de\ncortes hacia el ' + NOM_DIR[d], vendaval(d), (0, 3, 7, 9, 11, 13, 15))
    fila('VENDAVAL Vuelo corto', vuelo_corto(2), (0, 2, 3, 4, 6, 8, 10))
    ce.lamina(filas, os.path.join(SALIDA, 'segadora.png'))
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, 'segadora.gif'), 2)
    print('hecho en', SALIDA)


if __name__ == '__main__':
    principal()
