#!/usr/bin/env python3
# ============================================================
#  aberracion_efectos_pixel.py -- LOS EFECTOS DE LA ABERRACION Y SUS MUTANTES EN PIXEL ART (13/11/2026, memorias
#  efectos-a-pixel-art y aberracion-mutante). La receta de la de la polilla: misma rejilla que los sprites, paletas de 4
#  tonos, transparencia de verdad (sin rejilla), sobre sus sprites horneados. Lo decidido con el jefe:
#  LA BASE (la MISMA idea que el dibujo a mano de FieraAire, pasada a pixel):
#    LATIGAZO    el tentaculo DEL SPRITE (su morado, borde, lomo claro, ventosas) brota, llega en curva, RESTALLA y se recoge;
#                verdugon rojo en quien lo recibe
#    ALARIDO     frentes de sonido ROTOS y deformes en circulo completo, violeta enfermizo; los que pilla tiemblan
#    MIRADA      el ojo se enciende y tres medias lunas NEGRAS recorren el cono; sobre quien pilla, un ojo negro y el Miedo
#    CARNE       la Carne que se cierra: bultos que se hinchan y se hunden al curarse
#    GRIETAS     la Luz le corta la cura: rajas doradas que chisporrotean
#  LA MASA GALVANICA (electricidad VIOLETA por fuera y CIAN por dentro: no el azul de la araña):
#    LATIGAZO    el de la base con una CHISPA en la punta al pegar
#    DESCARGA    un ANILLO DE CHISPAS que sale de ella por el suelo hasta el borde del circulo
#    MIRADA      un CONO DE CHISPAS en vez de las medias lunas
#    CONDUCTORA  pegarle de cerca: la descarga salta a quien le pega
#  EL OJO DE LA TORMENTA:
#    CHISPAZO    una chispa corta del ojo al objetivo
#    RAYO        un ZIGZAG GORDO, un relampago tumbado, del ojo hasta el final de su linea
#    EL OJO      la carga: en el suelo, una copia del ARO del ojo que se enciende punto a punto; al estallar, un anillo de rayos
#    TENTACULOS  chispas al pegar a los que tiene debajo
#  Solo la lamina y el gif: todavia no van al juego.
#    python tools/sprites_sdf/aberracion_efectos_pixel.py
# ============================================================
import math
import os
import random
import sys

import numpy as np

import ciempies_efectos_pixel as ce
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl
import rata_efectos_pixel as rt
import miconido_efectos_pixel as mi

W, H = 330, 280
YY, XX = np.mgrid[0:H, 0:W]
TRAMA = ep.BAYER[(YY // 2) % 4, (XX // 2) % 4]
for _m in (ce, ep, sl, rt, mi):
    _m.W, _m.H, _m.YY, _m.XX, _m.TRAMA = W, H, YY, XX, TRAMA

from slime_efectos_pixel import UNIDAD, SALIDA, nuevo, estrella, elegir, DIRS, NOM_DIR  # noqa: E402
from rata_efectos_pixel import marco, escena  # noqa: E402
import sdf_comun as sc  # noqa: E402
import aberracion_sdf as ab  # noqa: E402
import aberracion_mut_sdf as amut  # noqa: E402  (ABERRACION_MUT por defecto: galvanica, su modelo x1,2)

poner, punto, bolita, disco = ep.poner, ep.punto, ep.bolita, ep.disco
velo, cabeza, caja_dibujo, cuentas, _curva = mi.velo, mi.cabeza, mi.caja_dibujo, mi.cuentas, mi._curva

BASE, GALVANICA, TORMENTA = 'aberracion_sdf', 'aberracion_sdf_galvanica', 'aberracion_sdf_tormenta'

# El tentaculo: SU morado (aberracion_sdf.MAT 'tent'), su borde y las ventosas palidas.
TENT = [(61, 28, 69), (92, 46, 105), (122, 69, 135), (204, 158, 204)]
TENT_B = (31, 10, 31)
VENTOSA = (196, 148, 184)
# El de la MASA GALVANICA: su lila translucido (aberracion_medusa_versiones 'tent_t') con anillos cian.
TENT_GALV = [(105, 75, 130), (142, 100, 175), (173, 122, 214), (217, 170, 255)]
VERDUGON = [(110, 20, 30), (170, 40, 46), (220, 90, 90), (250, 190, 180)]
ALARIDO = [(70, 40, 100), (120, 74, 170), (168, 107, 230), (237, 214, 255)]
NEGRO = [(6, 4, 8), (22, 14, 26), (52, 34, 64), (236, 226, 246)]
MIEDO = [(30, 12, 44), (70, 34, 96), (130, 80, 170), (210, 180, 240)]
PUSTULA = [(120, 70, 128), (176, 120, 180), (222, 178, 222), (250, 232, 250)]
ORO = [(96, 66, 20), (176, 128, 48), (232, 190, 96), (255, 240, 190)]
# LA ELECTRICIDAD DE LA ABERRACION: violeta por fuera, cian por dentro (13/11, el jefe).
RAYO = [(70, 26, 130), (150, 72, 228), (110, 235, 255), (236, 255, 255)]
RAYO_B = (34, 8, 66)


def centro(spr, pos):
    x0, y0, x1, y1 = caja_dibujo(spr, pos)
    return (x0 + x1) / 2, (y0 + y1) / 2


def frente(spr, pos, dx, dy, k=0.45, alto=0.0):
    """El borde de su dibujo hacia donde mira; 'alto' sube el punto (0 = el centro, 0,5 = el borde de arriba)."""
    x0, y0, x1, y1 = caja_dibujo(spr, pos)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2 - alto * (y1 - y0)
    return cx + dx * (x1 - x0) * k, cy + dy * (y1 - y0) * k * 0.6


def ojo_de(spr, pos, dx, dy):
    """Donde tiene el ojo: arriba y delante de su masa."""
    return frente(spr, pos, dx, dy, 0.32, 0.18)


def _dir(fila):
    dx, dy = DIRS[fila]
    return dx, dy * 0.9


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
def arco(a, x0, y0, x1, y1, sem, g=2.0, pal=RAYO, borde=RAYO_B, u=1.0, amp=5.5, paso=8):
    """Un rayo es una CINTA rellena en zigzag (la de la araña, con nuestra paleta): gorda en medio y afilada en las puntas.
    'amp' = lo que se sale de la recta en cada quiebro y 'paso' = cada cuanto quiebra (el Rayo del ojo: gordo y quebrado)."""
    rnd = random.Random(sem)
    L = math.hypot(x1 - x0, y1 - y0) or 1
    px, py = -(y1 - y0) / L, (x1 - x0) / L
    n = max(3, int(L / paso))
    nodos = []
    for i in range(n + 1):
        c = i / n
        m_ = 0 if i in (0, n) else rnd.uniform(-amp, amp)
        nodos.append((x0 + (x1 - x0) * c + px * m_, y0 + (y1 - y0) * c + py * m_))
    puntos = []
    for i in range(n):
        tramo = max(int(L / n), 1)
        for q in range(tramo + 1):
            c = q / tramo
            k = (i + c) / n
            if k > u:
                break
            puntos.append((nodos[i][0] + (nodos[i + 1][0] - nodos[i][0]) * c,
                           nodos[i][1] + (nodos[i + 1][1] - nodos[i][1]) * c,
                           g * math.sin(math.pi * min(max(k, 0.05), 0.95)) ** 0.6))
    for x, y, r in puntos:
        disco(a, x, y, r + 0.8, borde)
    for x, y, r in puntos:
        disco(a, x, y, r, pal[1])
    for x, y, r in puntos:
        disco(a, x, y, r * 0.55, pal[2] if r > 1.2 else pal[3])
    for x, y, r in puntos:
        if r > 2.2:
            disco(a, x, y, r * 0.25, pal[3])


def chispas_en(a, x, y, e, sem, n=3, r=11.0, g=1.3):
    """Unos chispazos cortos alrededor de un punto (el Electrizado que entra), saltando de sitio cada 2 marcos."""
    if e < 0 or e >= 6:
        return
    for k in range(n):
        ang = k * (math.tau / n) + (e // 2) * 1.3 + sem
        arco(a, x, y, x + math.cos(ang) * r, y + math.sin(ang) * r * 0.75, sem * 31 + e // 2 * 7 + k, g)
    if e < 2:
        estrella(a, x, y, (10, 6)[e], RAYO)


def tentaculo(a, o, h, u, panza, grueso=4.2, pal=TENT, anillos=False):
    """EL TENTACULO DEL SPRITE: de 'o' hacia 'h', salido una fraccion 'u' (0..1), con la panza de la curva a un lado (+/-)."""
    if u <= 0.02:
        return []
    fin = (o[0] + (h[0] - o[0]) * u, o[1] + (h[1] - o[1]) * u)
    L = math.hypot(fin[0] - o[0], fin[1] - o[1])
    pts = _curva(o, fin, panza * max(4.0, L * 0.28), n=max(6, int(L / 2.2)))
    cuentas(a, pts, grueso, pal, TENT_B)
    # el lomo claro y las ventosas palidas, una cuenta si y otra no, por debajo
    for i, (x, y) in enumerate(pts):
        uu = i / max(1, len(pts) - 1)
        r = grueso * (1.0 - 0.55 * uu)
        if i % 2 == 1 and 0.2 < uu < 0.9:
            punto(a, x, y + r * 0.55, VENTOSA)
        if i % 3 == 0:
            punto(a, x - r * 0.3, y - r * 0.5, pal[3])
        if anillos and i % 4 == 2 and uu < 0.85:
            disco(a, x, y, r * 0.75, RAYO[2])
            disco(a, x, y, r * 0.35, pal[1])
    return pts


def verdugon(a, x, y, dx, dy, e):
    """La marca del azote: una franja roja de lado a lado del cuerpo, que se va."""
    if e < 0 or e > 5:
        return
    px, py = -dy, dx
    f = 1.0 - e / 6.0
    for k in range(-5, 6):
        if ep.TRAMA[int(y) % H, int(x + k) % W] > f:
            continue
        disco(a, x + px * k, y - 10 + py * k * 0.6 + k * 0.3, 1.4, VERDUGON[1] if abs(k) < 4 else VERDUGON[0])
    if e < 2:
        disco(a, x, y - 10, 1.6, VERDUGON[3])


def media_luna_negra(a, cx, cy, r, ang, ancho, f):
    """Una media luna NEGRA de lado a lado del cono, con el filo claro roto por delante (la Voragine, no un rayo)."""
    for k in range(-10, 11):
        t = k / 10.0
        aa = ang + t * ancho
        x, y = cx + math.cos(aa) * r, cy + math.sin(aa) * r * 0.72
        g = 2.8 * (1 - abs(t) ** 2) * f + 0.6
        # (13/11, "a la mirada le pasa lo mismo") a medias, como una sombra que pasa, no un tajo.
        disco(a, x, y, g, NEGRO[1], 0.5 * f)
        disco(a, x - math.cos(ang) * 0.6, y - math.sin(ang) * 0.4, g * 0.6, NEGRO[0], 0.6 * f)
        if k % 3 == 0 and f > 0.4:
            disco(a, x + math.cos(ang) * g, y + math.sin(ang) * g * 0.7, 0.6, NEGRO[3], 0.7 * f)


def ojo_negro(a, x, y, e):
    """Sobre quien pilla la Mirada: se le abre un OJO negro con la pupila del eclipse encima de la cabeza."""
    if e < 0 or e > 9:
        return
    abre = min(1.0, (e + 1) / 3.0) * (1.0 if e < 7 else (9 - e) / 3.0)
    ry = 3.2 * abre
    m = ((XX - x) / 6.0) ** 2 + ((YY - y) / max(ry, 0.6)) ** 2 <= 1
    poner(a, m & (TRAMA < 0.62), NEGRO[1])
    if abre > 0.4:
        disco(a, x, y, 1.6, NEGRO[0], 0.8)
        disco(a, x - 1, y - 1, 0.6, NEGRO[3], 0.8)


def tiembla(a, v, e, pal=MIEDO):
    """El temblor del miedo / del grito: dos medias rayitas a cada lado de la cabeza, alternando."""
    if e < 0 or e > 7:
        return
    hx, hy = cabeza(v)
    lado = 1 if e % 2 == 0 else -1
    for s in (-1, 1):
        x = hx + s * (7 + lado)
        for j in range(3):
            disco(a, x + s * j * 0.4, hy - 1 + j * 2, 0.9, pal[2] if j != 1 else pal[3])


def frente_roto(a, cx, cy, r, sem, fuerza, pal=ALARIDO):
    """Un frente del Alarido: un ANILLO que ondula fuerte, con huecos, del filo claro a nada hacia dentro."""
    rnd = random.Random(sem)
    fases = [rnd.uniform(0, math.tau) for _ in range(3)]
    huecos = [(rnd.uniform(0, math.tau), rnd.uniform(0.25, 0.5)) for _ in range(3)]
    n = int(max(24, r * 1.6))
    for i in range(n):
        ang = i / n * math.tau
        if any(abs((ang - h0 + math.pi) % math.tau - math.pi) < w for h0, w in huecos):
            continue
        rr = r * (1 + 0.09 * math.sin(3 * ang + fases[0]) + 0.06 * math.sin(5 * ang + fases[1]))
        x, y = cx + math.cos(ang) * rr, cy + math.sin(ang) * rr * 0.6
        # (13/11, el jefe: "no puede no tener nada de transparencia, parece un ataque en vez de un grito") A MEDIAS: el
        # cuerpo del frente a la mitad, el filo claro algo mas y lo de dentro casi nada (4 escalones de alfa, sin rejilla).
        disco(a, x, y, 1.8 * fuerza + 0.4, pal[2], 0.45 * fuerza)
        disco(a, x, y, 0.7, pal[3], 0.7 * fuerza)
        xi, yi = cx + math.cos(ang) * (rr - 3), cy + math.sin(ang) * (rr - 3) * 0.6
        disco(a, xi, yi, 1.2, pal[1], 0.22 * fuerza)


def anillo_chispas(a, s, cx, cy, R, e, sem):
    """EL ANILLO DE CHISPAS (la Descarga): sale de ella por el suelo hasta el borde: tramos de rayo cortos y TANGENTES al
    anillo, que saltan de sitio, y unas quemaduras en el suelo por donde pasa."""
    if e < 0 or e > 10:
        return
    k = min(1.0, (e + 1) / 5.0)
    r = R * k
    fuerza = 1.0 if e < 6 else max(0.0, 1.0 - (e - 6) / 5.0)
    rnd = random.Random(sem + e // 2)
    n = 10
    for j in range(n):
        ang = j / n * math.tau + rnd.uniform(-0.15, 0.15)
        ang2 = ang + rnd.uniform(0.25, 0.45)
        x0, y0 = cx + math.cos(ang) * r, cy + math.sin(ang) * r * 0.6
        x1, y1 = cx + math.cos(ang2) * r, cy + math.sin(ang2) * r * 0.6
        if fuerza > 0.15 and (j + e) % 4 != 3:
            arco(a, x0, y0, x1, y1, sem * 17 + j + e // 2 * 5, 1.6 * fuerza + 0.4, amp=3.0, paso=5)
        if fuerza > 0.5 and (j + e) % 3 == 0:
            estrella(a, x0, y0, 4, RAYO)
    # las quemaduras del suelo: un anillo tenue violeta por donde ha pasado
    d = np.hypot(XX - cx, (YY - cy) / 0.6)
    poner(s, (np.abs(d - r) < 2.0) & (TRAMA < 0.35 * fuerza), RAYO[0])


def aro_suelo(s, a, cx, cy, R, encendidos, luz, n=16):
    """LA COPIA DEL ARO DEL OJO EN EL SUELO (la carga de El ojo se abre): n cuentas en el circulo, las 'encendidos' primeras
    (en sentido horario desde arriba) brillando; las demas, apagadas."""
    for j in range(n):
        ang = -math.pi * 0.5 + j / n * math.tau
        x, y = cx + math.cos(ang) * R, cy + math.sin(ang) * R * 0.6
        if j < encendidos:
            disco(s, x, y, 3.2, RAYO_B)
            bolita(a, x, y, 2.6, [RAYO[1], RAYO[2], RAYO[3], RAYO[3]])
            if luz and (j == encendidos - 1):
                estrella(a, x, y - 1, 5, RAYO)
        else:
            disco(s, x, y, 2.4, RAYO_B)
            disco(s, x, y, 1.6, RAYO[0])


# ------------------------------------------------------------
#  MEDIDO EN EL MODELO (13/11, el jefe: "los latigazos tienen que salir de los tentaculos, del que usa para atacar"): como
#  la punta del brazo del miconido, lo que sale del cuerpo sale de DONDE esta en el sprite de ese fotograma.
# ------------------------------------------------------------
SONIDO = [(70, 44, 96), (132, 92, 180), (196, 160, 236), (246, 236, 255)]   # el violeta enfermizo del Alarido
OSCURO = [(14, 8, 22), (34, 20, 52), (66, 40, 98), (204, 184, 240)]          # la Mirada: negro con el filo del eclipse


def _modelo_de(var):
    return amut.MODELO if var == GALVANICA else ab.MODELO


def _a_lamina(var, q, pos):
    mo = _modelo_de(var)
    return (int(round(pos[0])) - mo.W // 2 + q[0], int(round(pos[1])) - mo.H // 2 + q[1])


def punta_tentaculo(var, anim, fila, fr, pos, hacia, k=6):
    """Donde va, en la lamina, el tramo 'k' del tentaculo de DELANTE que azota en el fotograma 'fr' de 'anim' (de los dos
    de delante, el que queda mas cerca de 'hacia'). Desde ahi se estira el latigazo."""
    n, _fps, loop, _d, fn = ab.ANIMS[anim]
    p = fn(fr / n if loop else fr / max(1, n - 1))
    an, al = ab._volumen(p)
    mejor = None
    for i in (0, 5):
        q, _r = amut._punto_tent(p, i, an, al, k)
        q = q + np.array((0.0, p['avance'], 0.0))
        xy = _a_lamina(var, sc.a_pantalla(_modelo_de(var), q, fila), pos)
        dd = math.hypot(xy[0] - hacia[0], xy[1] - hacia[1])
        if mejor is None or dd < mejor[0]:
            mejor = (dd, xy)
    return mejor[1]


def boca_de(var, anim, fila, fr, pos):
    """Donde tiene las FAUCES en ese fotograma (de ahi sale el Alarido)."""
    n, _fps, loop, _d, fn = ab.ANIMS[anim]
    p = fn(fr / n if loop else fr / max(1, n - 1))
    an, al = ab._volumen(p)
    q = np.array((ab.BOCA[0], ab.BOCA[1] * an + 1.2, max(1.4, ab.BOCA[2] * al)))
    q = q + np.array((0.0, p['avance'], 0.0))
    return _a_lamina(var, sc.a_pantalla(_modelo_de(var), q, fila), pos)


def miedo(a, v, e):
    """El Miedo (el de la polilla): jirones morados que suben de la cabeza y tiemblan."""
    if e < 0 or e > 8:
        return
    hx, hy = cabeza(v)
    for j in range(3):
        k = e - j * 0.6
        if k < 0:
            continue
        x = hx + (j - 1) * 5 + math.sin(k * 2 + j) * 1.5
        bolita(a, x, hy - 6 - k * 1.6, 1.4, MIEDO)


def frentes_grito(a, b, R, f, pal=SONIDO, n_frentes=4, sem=0):
    """EL GRITO (como el Chillido del Rey Rata: bandas finas con su filo que SALEN DE LA BOCA una tras otra y se apagan con
    la distancia), pero en CIRCULO COMPLETO, deformes y con huecos: lo que no deberias estar oyendo."""
    dd = np.hypot(XX - b[0], (YY - b[1]) / 0.62)
    ang = np.arctan2((YY - b[1]) / 0.62, XX - b[0])
    for k in range(n_frentes):
        e = f - 1 - k * 2.5
        if e < 0:
            continue
        r = 6 + e * 6.5
        if r > R:
            continue
        fuerza = 1.0 - r / R
        rnd = random.Random(sem * 31 + k)
        ph1, ph2 = rnd.uniform(0, math.tau), rnd.uniform(0, math.tau)
        dw = dd + np.sin(ang * 3 + ph1 + e * 0.4) * r * 0.07 + np.sin(ang * 5 + ph2) * r * 0.04
        hueco = np.zeros_like(dd, dtype=bool)
        for _h in range(3):
            c0, w0 = rnd.uniform(-math.pi, math.pi), rnd.uniform(0.2, 0.42)
            hueco |= np.abs((ang - c0 + np.pi) % (2 * np.pi) - np.pi) < w0
        borde = np.abs(dw - r)
        en = (borde < 2.2) & ~hueco
        poner(a, en & (TRAMA < fuerza * 0.9), pal[1])
        poner(a, en & (borde < 1.0) & (TRAMA < fuerza * 1.2), pal[2])
        poner(a, en & (borde < 0.6) & (fuerza > 0.55) & (TRAMA < 0.8), pal[3])


def vibra(a, v, llega, pal=SONIDO):
    """A quien le llega el grito, el sonido le vibra alrededor (el del Chillido)."""
    if not 0 <= llega < 7:
        return
    tiembla_ = (llega % 2) * 2 - 1
    for lado in (-1, 1):
        for j in range(-3, 4):
            punto(a, v[0] + lado * (8 + abs(j) * 0.3) + tiembla_, v[1] - 10 + j * 1.3, pal[2 if abs(j) < 2 else 1],
                  2 if abs(j) < 2 else 1)


# ------------------------------------------------------------
#  LA BASE
# ------------------------------------------------------------
def latigazo(fila, var=BASE, chispa=False, dist=None):
    # (13/11, el jefe: hacia el N salia del centro y POR ENCIMA de la masa, gordo y pegado: "no tiene sentido") A la
    # distancia de verdad (su alcance, 90), mas fino, desde el BORDE de la masa que mira al objetivo y, si el objetivo
    # esta detras (dy < 0), en una capa POR DETRAS del cuerpo: la masa le tapa la raiz.
    dist = 90.0 / UNIDAD * 0.75 if dist is None else dist
    dx, dy = _dir(fila)
    A = (W * 0.5 - dx * dist * 0.5, H * 0.52 - dy * dist * 0.36)
    V = (A[0] + dx * dist, A[1] + dy * dist * 0.72 + 6)
    lado = 1 if fila % 2 == 0 else -1
    m, t = [], []
    for f in range(13):
        s, a, tb = nuevo(), nuevo(), nuevo()
        ep.victima(s, *V)
        spr = marco(var, 'basico', min(f, 7), fila)
        o = punta_tentaculo(var, 'basico', fila, min(f, 7), A, V)
        detras = dy < -0.2
        h = (V[0], V[1] - 9)
        if f < 4:
            u, panza = 1 - (1 - (f + 1) / 4.0) ** 2, lado
        elif f < 7:
            u, panza = 1.0, -0.7 * lado
        else:
            u, panza = max(0.0, 1.0 - (f - 6) / 5.0), -0.4 * lado
        e = f - 4
        verdugon(a, V[0], V[1], dx, dy, e)
        tentaculo(tb if detras else a, o, h, u, panza, 3.0, TENT_GALV if var == GALVANICA else TENT, var == GALVANICA)
        if e == 0 or e == 1:
            estrella(a, h[0], h[1], (10, 6)[e], ALARIDO if not chispa else RAYO)
        if chispa:
            chispas_en(a, h[0], h[1], e, fila, 3, 10)
        m.append(escena([s, tb], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def alarido():
    """EL ALARIDO DEMENTE: sale de sus FAUCES, en circulo completo (frentes_grito), y a quien le llega le vibra el sonido."""
    R = 70.0 / UNIDAD
    A = (W * 0.5, H * 0.5)
    vict = [(A[0] + R * 0.8, A[1] + 8), (A[0] - R * 0.75, A[1] - 6), (A[0] + 6, A[1] + R * 0.5)]
    b = boca_de(BASE, 'alarido', 1, 3, A)
    m, t = [], []
    for f in range(18):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        spr = marco(BASE, 'alarido', min(f, 7), 1)
        frentes_grito(a, b, R, f - 2, sem=1)
        for v in vict:
            vibra(a, v, f - 3 - int(math.hypot(v[0] - b[0], (v[1] - b[1]) / 0.62) / 6.5))
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def mirada(fila, var=BASE, chispas=False):
    dx, dy = _dir(fila)
    R = 120.0 / UNIDAD
    A = (W * 0.5 - dx * R * 0.55, H * 0.52 - dy * R * 0.4)
    eje = math.atan2(dy * 0.72, dx)
    ancho = math.radians(15)
    vict = [(A[0] + dx * R * 0.55, A[1] + dy * R * 0.4 + 4), (A[0] + dx * R * 0.9, A[1] + dy * R * 0.65 + 2)]
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        spr = marco(var, 'mirada', min(f, 7), fila)
        oj = ojo_de(spr, A, dx, dy)
        e = f - 2
        if 0 <= e < 3:
            estrella(a, oj[0], oj[1], (6, 9, 6)[e], NEGRO if not chispas else RAYO)
        if e >= 0:
            if not chispas:
                # (13/11) el cono del Parpado negro de la Polilla insomne (mi.abanico), negro con el filo del eclipse, y
                # motas violetas que brillan (negro sobre el suelo oscuro no se leia); sale de su ojo.
                o = (oj[0], oj[1] + 6)
                mi.abanico(a, o[0], o[1], eje, R, 30.0, e, OSCURO)
                mi.motas(a, o[0] + dx * R * 0.5, o[1] + dy * R * 0.4, e, fila + 9, SONIDO, 7, 0.5, R * 0.3, True)
            else:
                # EL CONO DE CHISPAS: arcos cortos que saltan por todo el cono, mas hacia el fondo a cada paso
                rnd = random.Random(fila * 13 + e // 2)
                for k in range(9):
                    if e > 9:
                        break
                    r0 = rnd.uniform(8, R * min(1.0, 0.35 + e / 7.0))
                    aa = eje + rnd.uniform(-ancho, ancho)
                    x, y = A[0] + math.cos(aa) * r0, A[1] + math.sin(aa) * r0 * 0.72 - 4
                    bb = aa + rnd.uniform(-1.4, 1.4)
                    arco(a, x, y, x + math.cos(bb) * 9, y + math.sin(bb) * 7, k * 7 + e // 2, 1.2, amp=2.5, paso=4)
                    if k % 3 == 0:
                        estrella(a, x, y, 4, RAYO)
        for j, v in enumerate(vict):
            llega = 4 + j * 2
            if not chispas:
                hx, hy = cabeza(v)
                ojo_negro(a, hx, hy - 9, f - llega)
                miedo(a, v, f - llega - 1)
            else:
                chispas_en(a, v[0], v[1] - 10, f - llega, j + 5, 3, 9)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def carne():
    """LA CARNE QUE SE CIERRA: bultos que se hinchan y se hunden por su masa al curarse."""
    A = (W * 0.5, H * 0.52)
    rnd = random.Random(3)
    bultos = [(rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.2), rnd.uniform(0, 4)) for _ in range(6)]
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        spr = marco(BASE, 'idle', f, 1)
        x0, y0, x1, y1 = caja_dibujo(spr, A)
        cx, cy, w, h = (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0
        for bx, by, fase in bultos:
            u = (f - fase) / 8.0
            if not 0 <= u <= 1:
                continue
            r = 3.2 * math.sin(math.pi * u)
            if r > 0.6:
                bolita(a, cx + bx * w, cy + by * h, r, PUSTULA)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


def grietas():
    """LA LUZ LE CORTA LA CURA: rajas DORADAS por su masa que chisporrotean (se quedan mientras dura el corte)."""
    A = (W * 0.5, H * 0.52)
    rnd = random.Random(9)
    rajas = []
    for _ in range(4):
        x, y = rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.15)
        ang = rnd.uniform(0, math.tau)
        rajas.append((x, y, ang))
    m, t = [], []
    for f in range(14):
        s, a = nuevo(), nuevo()
        spr = marco(BASE, 'idle', f, 1)
        x0, y0, x1, y1 = caja_dibujo(spr, A)
        cx, cy, w, h = (x0 + x1) / 2, (y0 + y1) / 2, x1 - x0, y1 - y0
        for j, (x, y, ang) in enumerate(rajas):
            px, py = cx + x * w, cy + y * h
            arco(a, px, py, px + math.cos(ang) * 8, py + math.sin(ang) * 5, j * 3 + 1, 1.0 + 0.3 * ((f + j) % 2),
                 pal=ORO, borde=(60, 40, 10), amp=2.0, paso=3)
            if (f + j * 2) % 5 == 0:
                estrella(a, px, py, 4, ORO)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 10)
    return m, t


# ------------------------------------------------------------
#  LA MASA GALVANICA
# ------------------------------------------------------------
def descarga():
    R = 70.0 / UNIDAD
    A = (W * 0.5, H * 0.52)
    vict = [(A[0] + R * 0.8, A[1] + 8), (A[0] - R * 0.75, A[1] - 6), (A[0] + 6, A[1] + R * 0.5)]
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        spr = marco(GALVANICA, 'alarido', min(f, 7), 1)
        c = centro(spr, A)
        e = f - 3
        if 0 <= e < 2:
            estrella(a, c[0], c[1], (16, 22)[e], RAYO)
        anillo_chispas(a, s, A[0], A[1], R, e, 7)
        for j, v in enumerate(vict):
            llega = 3 + int(5 * math.hypot(v[0] - A[0], (v[1] - A[1]) / 0.6) / R)
            chispas_en(a, v[0], v[1] - 10, f - llega, j + 2, 3, 9)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def conductora():
    """Le pegan de cerca: la descarga le salta a quien le pega."""
    A = (W * 0.56, H * 0.5)
    V = (A[0] - 26, A[1] + 8)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        ep.victima(s, *V)
        spr = marco(GALVANICA, 'encaje' if f < 4 else 'idle', min(f, 3) if f < 4 else f, 1)
        c = centro(spr, A)
        hv = cabeza(V)
        e = f - 1
        if 0 <= e < 5:
            arco(a, c[0] - 4, c[1], hv[0], hv[1], 40 + e // 2 * 3, 2.0 * (1 - e / 7.0) + 0.6)
        if 0 <= e < 2:
            estrella(a, c[0] - 4, c[1], (12, 8)[e], RAYO)
        chispas_en(a, hv[0], hv[1] + 4, e - 1, 9, 3, 8)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


# ------------------------------------------------------------
#  EL OJO DE LA TORMENTA (vuela: sus pies son el origen de su sprite, en el suelo)
# ------------------------------------------------------------
def chispazo(fila):
    dx, dy = _dir(fila)
    A = (W * 0.5 - dx * 34, H * 0.6 - dy * 24)
    V = (A[0] + dx * 46, A[1] + dy * 33 + 4)
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        ep.victima(s, *V)
        spr = marco(TORMENTA, 'basico', min(f, 7), fila)
        oj = ojo_de(spr, A, dx, dy)
        hv = cabeza(V)
        e = f - 3
        if 0 <= e < 3:
            arco(a, oj[0], oj[1], hv[0], hv[1], 60 + e, 2.2 * (1 - e / 4.0) + 0.6, u=min(1.0, (e + 1) / 1.5))
        if 0 <= e < 2:
            estrella(a, oj[0], oj[1], (9, 6)[e], RAYO)
        chispas_en(a, hv[0], hv[1] + 3, e - 1, 4, 3, 8)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def rayo(fila):
    """EL RAYO DEL OJO: un zigzag GORDO (un relampago tumbado) del ojo hasta el final de su linea a ras de suelo."""
    dx, dy = _dir(fila)
    L = 130.0 / UNIDAD
    A = (W * 0.5 - dx * L * 0.45, H * 0.5 - dy * L * 0.36)
    fin = (A[0] + dx * L, A[1] + dy * L * 0.72)
    vict = [(A[0] + dx * L * 0.45, A[1] + dy * L * 0.33 + 3), (A[0] + dx * L * 0.85, A[1] + dy * L * 0.62 + 2)]
    m, t = [], []
    for f in range(16):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        spr = marco(TORMENTA, 'rayo', min(f, 9), fila)
        oj = ojo_de(spr, A, dx, dy)
        e = f - 5
        if 0 <= f < 5:
            estrella(a, oj[0], oj[1], 3 + f * 1.6, RAYO)
        if 0 <= e < 7:
            g = 5.0 * (1.0 - max(0, e - 2) / 6.0) + 0.8
            arco(a, oj[0], oj[1], fin[0], fin[1], 90 + e // 2 * 11, g, u=min(1.0, (e + 1) / 1.4), amp=11.0, paso=12)
            if e < 2:
                estrella(a, oj[0], oj[1], (14, 10)[e], RAYO)
                estrella(a, fin[0], fin[1], (10, 14)[e], RAYO)
            d = np.hypot(XX - fin[0], (YY - fin[1]) / 0.6)
            poner(s, (d < 6) & (TRAMA < 0.4 * (1 - e / 7.0)), RAYO[0])
        for j, v in enumerate(vict):
            chispas_en(a, v[0], v[1] - 10, e - j, 20 + j, 3, 9)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def ojo_se_abre():
    R = 70.0 / UNIDAD
    A = (W * 0.5, H * 0.56)
    vict = [(A[0] + R * 0.6, A[1] + 6), (A[0] - R * 0.65, A[1] - 4), (A[0] + 4, A[1] + R * 0.5)]
    carga = 10
    m, t = [], []
    for f in range(carga + 12):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        if f < carga:
            spr = marco(TORMENTA, 'ojo_carga', f, 1)
            aro_suelo(s, a, A[0], A[1], R, int(round(16 * (f + 1) / carga)), True)
        else:
            e = f - carga
            spr = marco(TORMENTA, 'ojo', min(e, 7), 1)
            c = centro(spr, A)
            if e < 2:
                estrella(a, c[0], c[1], (18, 24)[e], RAYO)
            if e < 3:
                aro_suelo(s, a, A[0], A[1], R, 16, False)
            # EL ANILLO DE RAYOS: del aro encendido salen rayos que lo recorren y bajan del ojo a cada cuenta
            if e < 8:
                rnd = random.Random(e // 2 * 13)
                for j in range(0, 16, 2):
                    ang = -math.pi * 0.5 + j / 16 * math.tau
                    x, y = A[0] + math.cos(ang) * R, A[1] + math.sin(ang) * R * 0.6
                    ang2 = ang + math.tau / 16 * 2
                    x2, y2 = A[0] + math.cos(ang2) * R, A[1] + math.sin(ang2) * R * 0.6
                    g = 2.4 * (1 - e / 9.0) + 0.5
                    arco(a, x, y, x2, y2, j + e // 2 * 5, g, amp=4.0, paso=6)
                    if e < 3 and j % 4 == 0:
                        arco(a, c[0], c[1], x, y, 70 + j + e, 1.6, amp=6.0, paso=9)
                    if rnd.random() < 0.4:
                        estrella(a, x, y, 5, RAYO)
            anillo_chispas(a, s, A[0], A[1], R, e - 1, 3)
            for j, v in enumerate(vict):
                chispas_en(a, v[0], v[1] - 10, e - 1, 30 + j, 3, 9)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 12)
    return m, t


def tentaculos_cuelgan():
    """TENTACULOS QUE CUELGAN: restallan contra los que tiene debajo y salta la chispa en cada uno."""
    A = (W * 0.5, H * 0.58)
    vict = [(A[0] - 10, A[1] + 6), (A[0] + 14, A[1] + 2)]
    m, t = [], []
    for f in range(12):
        s, a = nuevo(), nuevo()
        for v in vict:
            ep.victima(s, *v)
        spr = marco(TORMENTA, 'tentaculos', min(f, 7), 1)
        x0, y0, x1, y1 = caja_dibujo(spr, A)
        e = f - 3
        for j, v in enumerate(vict):
            hv = cabeza(v)
            if 0 <= e < 3:
                arco(a, hv[0] + (j * 2 - 1) * 2, y1 - 2, hv[0], hv[1], 50 + j * 3 + e, 1.8 * (1 - e / 4.0) + 0.5, amp=3.0,
                     paso=5)
            chispas_en(a, hv[0], hv[1] + 2, e, 40 + j, 3, 8)
        m.append(escena([s], [(spr, A[0], A[1], 0)], [a]))
        t.append(1000 // 14)
    return m, t


def _sin_rejilla(fn):
    import transparencia as tr

    def envuelto(*a, **k):
        return tr.con_alfa(fn, [ce, ep, sl, rt, mi, sys.modules[__name__]], *a, **k)
    return envuelto


def principal():
    global latigazo, alarido, mirada, carne, grietas, descarga, conductora, chispazo, rayo, ojo_se_abre, tentaculos_cuelgan
    if os.environ.get('CON_REJILLA') != '1':
        latigazo, alarido, mirada, carne, grietas = map(_sin_rejilla, (latigazo, alarido, mirada, carne, grietas))
        descarga, conductora, chispazo, rayo = map(_sin_rejilla, (descarga, conductora, chispazo, rayo))
        ojo_se_abre, tentaculos_cuelgan = map(_sin_rejilla, (ojo_se_abre, tentaculos_cuelgan))
    os.makedirs(SALIDA, exist_ok=True)
    filas, gifs = [], []

    def fila(nombre, mt, idx):
        filas.append((nombre, elegir(mt[0], idx)))
        gifs.append(mt)

    for d in (1, 4):
        fila('BASE Latigazo de\ntentaculo hacia el ' + NOM_DIR[d], latigazo(d), (1, 2, 3, 4, 5, 7, 10))
    fila('BASE Alarido demente', alarido(), (2, 3, 5, 7, 9, 11, 14))
    for d in (1, 2):
        fila('BASE Mirada del vacio\nhacia el ' + NOM_DIR[d], mirada(d), (2, 3, 5, 7, 9, 11, 14))
    fila('BASE Carne que\nse cierra', carne(), (0, 2, 4, 6, 8, 10, 12))
    fila('BASE la Luz le\ncorta la cura', grietas(), (0, 2, 4, 6, 8, 10, 12))
    fila('MASA Latigazo\ngalvanico', latigazo(1, GALVANICA, True), (2, 3, 4, 5, 6, 8, 11))
    fila('MASA Descarga', descarga(), (2, 3, 4, 6, 8, 10, 13))
    for d in (1, 2):
        fila('MASA Mirada chispeante\nhacia el ' + NOM_DIR[d], mirada(d, GALVANICA, True), (2, 3, 5, 7, 9, 11, 14))
    fila('MASA pegarle de cerca\n(conductora)', conductora(), (0, 1, 2, 3, 4, 6, 9))
    for d in (1, 2):
        fila('OJO Chispazo\nhacia el ' + NOM_DIR[d], chispazo(d), (2, 3, 4, 5, 6, 8, 10))
    for d in (1, 2):
        fila('OJO Rayo del ojo\nhacia el ' + NOM_DIR[d], rayo(d), (1, 3, 5, 6, 7, 9, 12))
    fila('OJO El ojo se abre\n(carga y estallido)', ojo_se_abre(), (2, 5, 9, 10, 11, 13, 17))
    fila('OJO Tentaculos\nque cuelgan', tentaculos_cuelgan(), (2, 3, 4, 5, 6, 8, 10))
    nombre = 'aberracion'
    ce.lamina(filas, os.path.join(SALIDA, nombre + '.png'), 3)
    todos, tiempos = [], []
    for marcos, ts in gifs:
        todos += list(marcos) + [marcos[-1]]
        tiempos += list(ts) + [450]
    ep.gif(todos, tiempos, os.path.join(SALIDA, nombre + '.gif'), 2)
    print('hecho en', SALIDA, nombre)


if __name__ == '__main__':
    principal()
