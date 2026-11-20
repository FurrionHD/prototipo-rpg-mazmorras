#!/usr/bin/env python3
# ============================================================
#  acechador_efectos_pixel.py -- LOS EFECTOS DEL CAZADOR LUNAR EN PIXEL ART (20/11/2026, memoria acechador-mutante).
#  LA LUNA DEL CIELO: al empezar la pelea contra el Cazador sale una luna en el centro de la pelea, cambia de fase con
#  cada turno suyo (nueva, creciente, llena, menguante), apaga los farolillos y es la luz de la pelea (tenue y azul).
#  Lleva LOS PUNTOS DE LA PACIENCIA (como los circulos de las tejedoras: tools/sprites_sdf/arana_efectos_horno.py, cont_*)
#  para ver por cuanto va. Referencia del jefe (17/11): Desktop/ataques_mapa/enemigos/acechador/referencia/luna_1.png
#  (blanco azulado frio, borde que brilla, remolinos pastel por dentro, chispas): "no hace falta tan detallado".
#  TRES VERSIONES para que elija:
#    A  LUNA FRIA      blanco azulado con crateres y un halo tramado
#    B  ACUARELA       la de su foto: remolinos pastel (azul, lila, rosa, turquesa) por dentro, halo y chispas
#    C  GRABADO        disco claro con el borde grueso que brilla y un corro de estrellitas
#  Solo la lamina: todavia no va al juego.
#    python tools/sprites_sdf/acechador_efectos_pixel.py
# ============================================================
import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw

W, H = 96, 96
CX, CY, R = 48, 44, 18
YY, XX = np.mgrid[0:H, 0:W]
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
TRAMA = BAYER[YY % 4, XX % 4]
SALIDA = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'acechador')

FRIA = [(70, 84, 140), (132, 150, 204), (196, 210, 245), (238, 244, 255)]
HALO = (110, 130, 210)
NOCHE = (26, 30, 58)
PASTEL = [(150, 190, 255), (190, 160, 245), (250, 180, 220), (140, 230, 225)]
AMBAR = [(120, 62, 8), (214, 128, 20), (250, 184, 56), (255, 238, 170)]
CARBON = (40, 40, 52)
FASES = ('nueva', 'creciente', 'llena', 'menguante')


def nuevo():
    return np.zeros((H, W, 4), np.uint8)


def poner(a, m, col):
    a[m] = (*col, 255)


def disco_m(cx, cy, r):
    return (XX - cx) ** 2 + (YY - cy) ** 2 <= r * r


def oscuro_de(fase):
    """La parte en sombra del disco (la fase): nueva toda; creciente luz a la derecha; menguante a la izquierda."""
    d = disco_m(CX, CY, R)
    if fase == 'nueva':
        return d
    if fase == 'llena':
        return np.zeros_like(d)
    off = -R * 0.62 if fase == 'creciente' else R * 0.62
    return d & disco_m(CX + off, CY, R)


def halo(a, r0, r1, col, densidad):
    anillo = ((XX - CX) ** 2 + (YY - CY) ** 2 > r0 * r0) & ((XX - CX) ** 2 + (YY - CY) ** 2 <= r1 * r1)
    m = anillo & (TRAMA < densidad) & (a[..., 3] == 0)
    poner(a, m, col)


def luna_fria(a, fase):
    halo(a, R + 1, R + 4, HALO, 0.0 if fase == 'nueva' else 0.45)
    d = disco_m(CX, CY, R)
    # sombreado: la luz arriba a la izquierda
    dist = np.sqrt((XX - (CX - 6)) ** 2 + (YY - (CY - 6)) ** 2) / (R * 1.6)
    tono = np.clip((dist + TRAMA * 0.25) * 4, 0, 3).astype(int)
    for k in range(4):
        poner(a, d & (tono == k), FRIA[3 - k])
    for (x, y, r) in ((CX - 5, CY - 3, 4), (CX + 6, CY + 5, 3), (CX + 2, CY - 9, 2), (CX - 8, CY + 8, 2)):
        poner(a, d & disco_m(x, y, r), FRIA[1])
        poner(a, d & disco_m(x - 1, y - 1, max(1, r - 1)), FRIA[2])
    poner(a, oscuro_de(fase), NOCHE)
    # el borde de la parte oscura, apenas (la luna nueva se adivina)
    borde = d & ~disco_m(CX, CY, R - 1)
    poner(a, borde & oscuro_de(fase), (54, 62, 108))


def luna_acuarela(a, fase, f=0):
    halo(a, R + 1, R + 3, (200, 210, 255), 0.0 if fase == 'nueva' else 0.6)
    halo(a, R + 3, R + 6, HALO, 0.0 if fase == 'nueva' else 0.22)
    d = disco_m(CX, CY, R)
    # remolinos pastel: bandas que se curvan (como marmol), cuantizadas a 4 colores y aclaradas hacia el borde de luz
    u = (XX - CX) / R
    v = (YY - CY) / R
    onda = np.sin(u * 3.2 + np.sin(v * 4.0 + f * 0.6) * 1.6) + np.cos(v * 2.6 - u * 1.4)
    idx = np.clip(((onda + 2.0) / 4.0 * 4 + TRAMA * 0.6).astype(int), 0, 3)
    for k in range(4):
        poner(a, d & (idx == k), PASTEL[k])
    # el centro mas blanco (la luna brilla por dentro)
    poner(a, d & disco_m(CX - 3, CY - 3, R * 0.45) & (TRAMA < 0.55), (240, 244, 255))
    borde = d & ~disco_m(CX, CY, R - 1.2)
    poner(a, borde, (246, 250, 255))
    poner(a, oscuro_de(fase), NOCHE)
    poner(a, borde & oscuro_de(fase), (60, 68, 118))
    if fase != 'nueva':
        rnd = random.Random(7 + f)
        for _ in range(7):
            ang = rnd.uniform(0, math.tau)
            rr = rnd.uniform(R + 5, R + 11)
            x, y = int(CX + math.cos(ang) * rr), int(CY + math.sin(ang) * rr * 0.85)
            if 0 <= x < W and 0 <= y < H:
                a[y, x] = (*((255, 255, 255) if rnd.random() < 0.5 else PASTEL[rnd.randrange(4)]), 255)


def luna_grabado(a, fase):
    d = disco_m(CX, CY, R)
    poner(a, d, FRIA[2])
    poner(a, d & disco_m(CX - 2, CY - 2, R - 3), FRIA[3])
    for (x, y, r) in ((CX - 5, CY - 2, 3), (CX + 6, CY + 6, 2), (CX + 3, CY - 8, 2)):
        poner(a, d & disco_m(x, y, r), FRIA[1])
    borde = d & ~disco_m(CX, CY, R - 2)
    poner(a, borde, (255, 255, 255))
    poner(a, oscuro_de(fase), NOCHE)
    poner(a, borde & oscuro_de(fase), (64, 74, 128))
    if fase != 'nueva':
        for k in range(12):
            ang = k / 12 * math.tau
            x, y = int(round(CX + math.cos(ang) * (R + 6))), int(round(CY + math.sin(ang) * (R + 6)))
            a[y, x] = (*(255, 255, 255), 255)
            if k % 3 == 0:
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    a[y + dy, x + dx] = (*HALO, 255)


# ------------------------------------------------------------
#  LA ELEGIDA (20/11, la A "me mola") MEJORADA, su encargo: "que brille mas, los puntos ARRIBA como en los enemigos, y los
#  tipicos HACES DE LUZ aleatorios, transparentes, que no salgan siempre del mismo lado; un poco de brillo, que se note
#  que esta FLOTANDO, un poco aspecto 3D". Animada (f = fotograma de N_ANIM): haces que nacen y se apagan por turnos en
#  angulos al azar, el resplandor que respira y un vaiven de 1-2 px. Transparencia de verdad (alfa por niveles), sin trama.
# ------------------------------------------------------------
N_ANIM = 16
FRIA2 = [(92, 108, 170), (150, 168, 222), (210, 222, 252), (246, 250, 255)]
RAYO = (200, 216, 255)


def mezcla(a, m, col, alfa):
    """Pinta 'col' con 'alfa' (0..1) ENCIMA de lo que haya (alfa de verdad, por niveles de 1/8 para que siga siendo pixel)."""
    al = np.round(np.clip(alfa, 0, 1) * 8) / 8
    if np.isscalar(al):
        al = np.full((H, W), al)
    m = m & (al > 0)
    base = a[..., :3].astype(float)
    ab = a[..., 3].astype(float) / 255.0
    nuevo_al = al + ab * (1 - al)
    rgb = (np.array(col, float) * al[..., None] + base * (ab * (1 - al))[..., None]) / np.maximum(nuevo_al, 1e-6)[..., None]
    a[m, :3] = rgb[m].astype(np.uint8)
    a[m, 3] = (nuevo_al[m] * 255).astype(np.uint8)


def haces(a, cx, cy, f, fase, sem=3):
    """Los haces de luz: cuñas finas desde la luna hacia fuera, cada una con su angulo al azar; nacen y se apagan por
    turnos (cada una en su tramo del ciclo) y al renacer cambian de angulo: nunca salen siempre del mismo lado."""
    if fase == 'nueva':
        return
    rnd = random.Random(sem)
    fuerza = {'creciente': 0.55, 'llena': 1.0, 'menguante': 0.55}[fase]
    ang = np.arctan2(YY - cy, XX - cx)
    dist = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2)
    for k in range(5):
        a0 = rnd.uniform(0, math.tau)
        ancho = rnd.uniform(0.13, 0.22)          # CONOS que se abren hacia fuera (finos se leian como palitos)
        largo = rnd.uniform(R * 2.0, R * 2.6)
        t = f / N_ANIM + k / 5.0
        vida = math.sin((t % 1.0) * math.pi) ** 2          # nace, brilla y se apaga
        if vida < 0.08:
            continue
        a_k = a0 + int(t) * 2.3                            # cada vez que renace, por otro lado
        dif = np.abs((ang - a_k + math.pi) % math.tau - math.pi)
        cuna = dif < ancho
        tramo = (dist > R * 0.8) & (dist < largo)
        # mas fuerte en el eje del haz y hacia la luna; se deshace hacia fuera y por los lados
        alfa = vida * fuerza * 0.38 * np.clip(1.0 - (dist - R) / (largo - R), 0, 1) * np.clip(1.0 - dif / ancho, 0, 1) ** 0.6
        mezcla(a, cuna & tramo, RAYO, alfa)


def resplandor(a, cx, cy, f, fase):
    """El brillo que la rodea, suave, que respira."""
    if fase == 'nueva':
        return
    fuerza = {'creciente': 0.6, 'llena': 1.0, 'menguante': 0.6}[fase]
    resp = 0.85 + 0.15 * math.sin(f / N_ANIM * math.tau)
    dist = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2)
    alfa = np.clip(1.0 - (dist - R) / 10.0, 0, 1) ** 1.6 * 0.6 * fuerza * resp
    mezcla(a, dist > R - 0.5, (170, 190, 255), alfa)


def oscuro_de_en(fase, cx, cy):
    d = disco_m(cx, cy, R)
    if fase == 'nueva':
        return d
    if fase == 'llena':
        return np.zeros_like(d)
    off = -R * 0.62 if fase == 'creciente' else R * 0.62
    return d & disco_m(cx + off, cy, R)


def luna_viva(a, fase, f=0):
    """La A mejorada: esfera con la luz fuerte arriba a la izquierda, mas clara, brillo (especular) y borde de luz por
    detras (se lee como bola que flota); resplandor, haces y el vaiven de flotar."""
    dy = round(1.5 * math.sin(f / N_ANIM * math.tau))
    cx, cy = CX, CY + dy
    resplandor(a, cx, cy, f, fase)
    haces(a, cx, cy, f, fase)
    d = disco_m(cx, cy, R)
    nx = (XX - cx) / R
    ny = (YY - cy) / R
    nz = np.sqrt(np.clip(1 - nx * nx - ny * ny, 0, 1))
    luz = np.clip(-0.45 * nx - 0.55 * ny + 0.7 * nz, 0, 1)
    tono = np.clip((luz * 3.6 + TRAMA * 0.35).astype(int), 0, 3)
    for k in range(4):
        poner(a, d & (tono == k), FRIA2[k])
    for (x, y, r) in ((cx - 5, cy - 3, 4), (cx + 6, cy + 5, 3), (cx + 2, cy - 9, 2), (cx - 8, cy + 8, 2)):
        poner(a, d & disco_m(x, y, r), FRIA2[1])
        poner(a, d & disco_m(x - 1, y - 1, max(1, r - 1)), FRIA2[2])
    poner(a, d & disco_m(cx - 7, cy - 8, 2.2), (255, 255, 255))
    rim = d & ~disco_m(cx - 1, cy - 1, R - 1)
    poner(a, rim & (XX > cx + 3) & (YY > cy + 2), FRIA2[2])   # el borde de luz de detras, suave (blanco era una raya)
    osc = oscuro_de_en(fase, cx, cy)
    poner(a, osc, NOCHE)
    poner(a, d & ~disco_m(cx, cy, R - 1) & osc, (60, 70, 120))


def puntos_arriba(a, nivel, f=0, tope=3):
    """LOS PUNTOS DE LA PACIENCIA ENCIMA de la luna, como los contadores de los enemigos (tejedoras)."""
    dy = round(1.5 * math.sin(f / N_ANIM * math.tau))
    for k in range(tope):
        x = CX + (k - (tope - 1) / 2) * 9
        y = CY + dy - R - 12
        poner(a, disco_m(x, y, 3.4), (14, 12, 16))
        poner(a, disco_m(x, y, 2.4), AMBAR[2] if k < nivel else CARBON)
        if k < nivel:
            a[int(y - 1), int(x - 1)] = (*AMBAR[3], 255)


def principal_v2():
    os.makedirs(SALIDA, exist_ok=True)
    zoom = 4
    rot = 230
    filas = [('LA A MEJORADA\nlas cuatro fases\n(Paciencia 0..3 arriba)', [(fase, i, 3) for i, fase in enumerate(FASES)]),
             ('LUNA LLENA ANIMADA\nlos haces nacen y se apagan\npor turnos; flota y respira',
              [('llena', 2, f) for f in range(0, N_ANIM, 2)]),
             ('CRECIENTE ANIMADA\n(haces mas flojos)', [('creciente', 1, f) for f in range(0, N_ANIM, 2)])]
    cols = max(len(c) for _, c in filas)
    img = Image.new('RGB', (rot + cols * (W * zoom + 6), len(filas) * (H * zoom + 30) + 10), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, celdas) in enumerate(filas):
        y = 10 + j * (H * zoom + 30)
        pinta.text((10, y + 10), nombre, fill=(230, 226, 214))
        for i, (fase, niv, f) in enumerate(celdas):
            a = nuevo()
            luna_viva(a, fase, f)
            puntos_arriba(a, niv, f)
            img.paste(componer(a).resize((W * zoom, H * zoom), Image.NEAREST), (rot + i * (W * zoom + 6), y))
            pinta.text((rot + i * (W * zoom + 6) + 4, y + H * zoom + 4), '%s  f%d' % (fase, f), fill=(200, 200, 210))
    ruta = os.path.join(SALIDA, 'luna_elegida_v2.png')
    img.save(ruta)
    # y el GIF de la llena, para verla moverse
    gif = []
    for f in range(N_ANIM):
        a = nuevo()
        luna_viva(a, 'llena', f)
        puntos_arriba(a, 2, f)
        gif.append(componer(a).resize((W * 4, H * 4), Image.NEAREST))
    gif[0].save(os.path.join(SALIDA, 'luna_llena.gif'), save_all=True, append_images=gif[1:], duration=110, loop=0)
    print(ruta)
    return ruta


def puntos(a, nivel, tope=3):
    """LOS PUNTOS DE LA PACIENCIA, como el contador de las tejedoras: un circulo por carga, encendidos los que lleva."""
    for k in range(tope):
        x = CX + (k - (tope - 1) / 2) * 9
        y = CY + R + 9
        poner(a, disco_m(x, y, 3.4), (14, 12, 16))
        poner(a, disco_m(x, y, 2.4), AMBAR[2] if k < nivel else CARBON)
        if k < nivel:
            a[int(y - 1), int(x - 1)] = (*AMBAR[3], 255)


def fondo_noche():
    """El suelo de la pelea a la luz de la luna: oscuro y azul (los farolillos apagados)."""
    f = np.zeros((H, W, 3), np.uint8)
    f[:] = (30, 32, 46)
    m = TRAMA < 0.18
    f[m] = (38, 42, 62)
    return f


def componer(a):
    f = fondo_noche()
    al = a[..., 3:4] / 255.0
    out = (f * (1 - al) + a[..., :3] * al).astype(np.uint8)
    return Image.fromarray(out, 'RGB')


def principal():
    os.makedirs(SALIDA, exist_ok=True)
    estilos = [('A  LUNA FRIA\ncrateres y halo tramado', luna_fria),
               ('B  ACUARELA\nremolinos pastel, halo y chispas\n(la de su foto)', luna_acuarela),
               ('C  GRABADO\nborde que brilla y estrellitas', luna_grabado)]
    zoom = 4
    rot = 230
    img = Image.new('RGB', (rot + 4 * (W * zoom + 6), len(estilos) * (H * zoom + 30) + 10), (24, 22, 26))
    pinta = ImageDraw.Draw(img)
    for j, (nombre, fn) in enumerate(estilos):
        y = 10 + j * (H * zoom + 30)
        pinta.text((10, y + 10), nombre, fill=(230, 226, 214))
        for i, fase in enumerate(FASES):
            a = nuevo()
            fn(a, fase)
            puntos(a, i)
            im = componer(a).resize((W * zoom, H * zoom), Image.NEAREST)
            x = rot + i * (W * zoom + 6)
            img.paste(im, (x, y))
            pinta.text((x + 4, y + H * zoom + 4), 'luna %s  -  Paciencia %d/3' % (fase, i), fill=(200, 200, 210))
    ruta = os.path.join(SALIDA, 'luna_versiones.png')
    img.save(ruta)
    print(ruta)
    return ruta


# ------------------------------------------------------------------ AL JUEGO (20/11): LA LUNA DEL CIELO HORNEADA
#   luna_nueva / luna_creciente / luna_llena / luna_menguante   (bucle de N_ANIM) la luna aprobada, con su vaiven, haces y
#                                                               resplandor. Origen = su centro (sin el vaiven)
#   puntos_0 .. puntos_3   (bucle de N_ANIM, al mismo vaiven) los puntos de la Paciencia encima
#   luna_estela            la estela de luz de la CAIDA, hacia arriba (el codigo la gira hacia de donde viene)
#   luna_golpe             (suelo + aire) el GOLPE al caer: destello, el anillo que se abre y esquirlas de luna
def _creciente_m(cx, cy, r, abre, giro):
    ox, oy = math.cos(giro) * r * abre, math.sin(giro) * r * abre
    return disco_m(cx, cy, r) & ~disco_m(cx - ox, cy - oy, r)


def hornear_luna():
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import horno_efectos as ho
    d = {}
    for fase in FASES:
        out = []
        for f in range(N_ANIM):
            s, a = nuevo(), nuevo()
            luna_viva(a, fase, f)
            out.append((s, a))
        d['luna_' + fase] = ho.guardar_efecto('acechador', 'luna_' + fase, [out], [(CX, CY)], 10.0, True)
    for nivel in range(4):
        out = []
        for f in range(N_ANIM):
            s, a = nuevo(), nuevo()
            puntos_arriba(a, nivel, f)
            out.append((s, a))
        d['puntos_%d' % nivel] = ho.guardar_efecto('acechador', 'puntos_%d' % nivel, [out], [(CX, CY)], 10.0, True)
    # la estela: hacia ARRIBA desde el centro, ancha y transparente, que se afila
    s, a = nuevo(), nuevo()
    proy = CY - YY
    lado = np.abs(XX - CX)
    m = (proy > 0) & (proy < 44) & (lado < 13 * (1 - proy / 52))
    mezcla(a, m, (190, 206, 255), np.clip(1 - proy / 44, 0, 1) * 0.45)
    d['luna_estela'] = ho.guardar_efecto('acechador', 'luna_estela', [[(s, a)]], [(CX, CY)], 10.0, True)
    # el golpe
    out = []
    Rg = 42.0
    dist = np.sqrt((XX - CX) ** 2 + ((YY - CY) / 0.8) ** 2)
    for e in range(8):
        s, a = nuevo(), nuevo()
        vida = 1 - e / 8.0
        if e <= 1:
            mezcla(a, dist < Rg * 0.9, (235, 242, 255), (0.7 if e == 0 else 0.4) * np.clip(1 - dist / (Rg * 0.9), 0, 1))
        rr = Rg * 0.6 * (0.5 + 0.8 * (1 - (1 - min(1, e / 4)) ** 3))
        mezcla(s, (dist <= rr) & (dist > rr - 3), (230, 238, 255), 0.9 * vida)
        mezcla(s, dist < Rg * 0.6, (90, 110, 190), 0.25 * vida)
        rnd = random.Random(2)
        for i in range(8):
            an = rnd.uniform(0, math.tau)
            dd = 6 + e * rnd.uniform(3, 5)
            x, y = CX + math.cos(an) * dd, CY + math.sin(an) * dd * 0.8 - 8 + e * e * 0.5
            mezcla(a, _creciente_m(x, y, 2.6, 0.55, an), FRIA2[3], vida)
        out.append((s, a))
    d['luna_golpe'] = ho.guardar_efecto('acechador', 'luna_golpe', [out], [(CX, CY)], 14.0)
    ho.sumar('acechador', d)


if __name__ == '__main__':
    import sys
    if '--hornear' in sys.argv:
        hornear_luna()
    else:
        r = principal() if '--v1' in sys.argv else principal_v2()
        if os.name == 'nt' and '--abrir' in sys.argv:
            import subprocess
            subprocess.Popen(['mspaint', r])   # (con Paint: memoria abrir-con-paint)
