# ============================================================
#  trent_versiones.py -- TRES PROPUESTAS de trent en 3D (05/10/2026), una por cada referencia que paso el jefe ("hay
#  muchos tipos, sacame varias versiones y nos quedamos con la que mas mole"). Solo QUIETAS: la elegida pasa a
#  trent_sdf.py con sus huesos y sus animaciones. Mismo lienzo y origen que el trent de siempre (2,50 -> 306 x 216).
#    guardian  el corpachon de tronco con la cara tallada, cuernos-rama con enredaderas y musgo en los hombros
#    tocones   a cuatro patas sobre tocones tallados, mascara de madera con runas que brillan y flores de luz
#    zarza     una bola de hojas maldita con muchos ojos, una boca dentada que brilla y patas de ramitas moradas
#  Uso: python tools/sprites_sdf/trent_versiones.py  -> tools/salida/sdf/trent_versiones.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import trent_sdf

V = np.array
LIENZO = trent_sdf.LIENZO
PIES = trent_sdf.PIES


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo)


# UNA RAMA RETORCIDA: tramo a tramo, la direccion se va girando (unas veces hacia fuera, otras hacia atras) con un
# meneo de seno y algo de azar; en los codos un NUDO, cada pocos tramos una RAMITA (la misma funcion, mas corta) y, en
# las gordas, la LIANA en espiral alrededor.
def _rama_retorcida(add, base, dir0, largo, r0, r1, s, semilla, nivel):
    rng = np.random.default_rng(semilla)
    n = 9 if nivel >= 2 else 5
    paso = largo / n
    d = dir0 / np.linalg.norm(dir0)
    p = base.copy()
    puntos = [p.copy()]
    for k in range(n):
        u = k / n
        # el giro: un vaiven a los lados, una caida hacia atras/delante y un poco de azar
        giro = V((0.34 * math.sin(k * 1.7 + semilla) * s, 0.30 * math.cos(k * 1.3 + semilla * 0.7), 0.0))
        giro += rng.normal(size=3) * (0.05 if nivel >= 2 else 0.12)
        d = d + giro
        d[2] = max(d[2], 0.45 if nivel >= 2 else 0.15)   # que no se tumbe: el cuerno siempre sube
        d /= np.linalg.norm(d)
        q = p + d * paso
        ra = r0 + (r1 - r0) * u
        rb = r0 + (r1 - r0) * (k + 1) / n
        _cono(add, p, q, ra, rb, 'corteza', 0.5, 'cuerno')
        if k in (2, 5) and nivel >= 1:
            _elip(add, p, (ra * 1.35, ra * 1.35, ra * 1.25), 'corteza', 0.4, 'cuerno')
        if nivel >= 1 and k in ((2, 4, 6) if nivel >= 2 else (2,)):
            lado = V((-d[1], d[0], 0.0)); lado = lado / max(np.linalg.norm(lado), 1e-6)
            sgn = 1 if k % 4 == 2 else -1
            dr = d * 0.5 + lado * sgn * 0.9 + V((0, 0, 0.35))
            _rama_retorcida(add, q, dr, largo * (0.32 if nivel >= 2 else 0.4), rb * 0.7, 0.3, s * sgn, semilla * 7 + k, nivel - 1)
        puntos.append(q.copy())
        p = q
    # LA LIANA: una espiral alrededor del primer tramo de la rama gorda, con una hoja de vez en cuando.
    if nivel >= 2:
        prev = None
        for k in range(0, 26):
            t = k / 25 * (len(puntos) - 1) * 0.65
            i0 = int(t); f = t - i0
            c = puntos[i0] * (1 - f) + puntos[min(i0 + 1, len(puntos) - 1)] * f
            dd = puntos[min(i0 + 1, len(puntos) - 1)] - puntos[i0]; dd /= max(np.linalg.norm(dd), 1e-6)
            a1 = np.cross(dd, V((0.0, 1.0, 0.0))); a1 /= max(np.linalg.norm(a1), 1e-6)
            a2 = np.cross(dd, a1)
            rr = r0 + (r1 - r0) * t / n + 0.35
            ang = k * 0.9
            pt = c + (a1 * math.cos(ang) + a2 * math.sin(ang)) * rr
            if prev is not None:
                _cono(add, prev, pt, 0.42, 0.42, 'liana', 0, 'liana')
            prev = pt
        # y un cabo de liana que cuelga
        mitad = puntos[len(puntos) // 2]
        _cono(add, mitad + V((0, 0.6, -0.5)), mitad + V((0.6 * s, 1.0, -7.5)), 0.4, 0.3, 'liana', 0, 'liana')


# ------------------------------------------------------------
#  A. EL GUARDIAN
# ------------------------------------------------------------
MAT_A = {
    'corteza': [(0.36, 0.19, 0.16), (0.52, 0.29, 0.23), (0.66, 0.40, 0.31)],
    'musgo':   [(0.20, 0.48, 0.40), (0.33, 0.68, 0.56), (0.55, 0.84, 0.72)],
    'liana':   [(0.10, 0.20, 0.14), (0.16, 0.30, 0.21), (0.22, 0.40, 0.28)],
    'ojo':     [(1.0, 0.93, 0.55)] * 3,
    'hueco':   [(0.14, 0.07, 0.06)] * 3,
}
MOD_A = Modelo(2.5, LIENZO, PIES, MAT_A, (0.12, 0.06, 0.05), suaves=('cuerpo', 'musgo'), brillan=('ojo',),
               corta_suelo=True)


def escena_guardian():
    e = Escena({'raiz': IDENT}); add = e.add
    # EL CUERPO: un tronco que se tuerce un poco a tramos (no un tubo: "muy rectos y rancios"), con la base abierta y
    # algo ancho de hombros; la cara va tallada en su parte alta (no tiene cuello).
    eje = [V((0.0, -0.4, 10.5)), V((0.9, 0.0, 16.5)), V((-0.7, 0.7, 22.5)), V((0.2, 1.0, 29.0)), V((0.0, 0.9, 32.0))]
    radios = [7.8, 6.8, 7.2, 8.0, 7.6]
    for k in range(len(eje) - 1):
        _cono(add, eje[k], eje[k + 1], radios[k], radios[k + 1], 'corteza', 2.0)
    _elip(add, (0, 0.5, 31), (8.5, 6.5, 5.0), 'corteza', 2.0)
    _elip(add, (0, -0.3, 11.5), (8.8, 7.8, 3.2), 'corteza', 2.0)
    # LAS VETAS: costillas de corteza en relieve, a lo largo y algo en espiral, y un par de NUDOS (agujero oscuro).
    for k in range(13):
        a0 = k / 13 * 2 * math.pi + 0.2
        if abs(math.sin(a0) - 1.0) < 0.35:
            continue                      # por delante no: ahi va la cara y la barba
        pts = []
        for j in range(5):
            z = 11.0 + j * 4.6
            r = 7.2 + 0.5 * math.sin(j * 1.3 + k)
            a = a0 + j * 0.12
            c = eje[min(j, len(eje) - 1)]
            pts.append(V((c[0] + math.cos(a) * r, c[1] + math.sin(a) * r, z)))
        for j in range(len(pts) - 1):
            _cono(add, pts[j], pts[j + 1], 0.95, 0.85, 'corteza', 0.5)
    for (a, z) in ((2.6, 18.0), (-0.5, 24.5), (4.0, 14.0)):
        _elip(add, (math.cos(a) * 7.4, math.sin(a) * 7.4, z), (1.3, 1.3, 1.8), 'hueco', 0, 'nudo')
    # LA CARA: la ceja de corteza sobre unos ojos amarillos que brillan, y la BARBA de astillas colgando.
    _cono(add, (-4.5, 8.0, 29.2), (4.5, 8.0, 29.2), 1.6, 1.6, 'corteza', 1.0)
    for s in (-1, 1):
        _elip(add, (2.6 * s, 8.7, 27.2), (1.7, 0.9, 0.9), 'ojo', 0, 'ojo')
    _elip(add, (0, 8.9, 24.0), (2.6, 0.8, 0.8), 'hueco', 0, 'boca')
    for k, x in enumerate((-4.0, -2.2, -0.4, 1.5, 3.4)):
        largo = (8.5, 11.0, 13.5, 10.5, 8.0)[k]
        _cono(add, (x, 8.6, 23.0), (x * 1.05, 9.6, 23.0 - largo), 1.5, 0.35, 'corteza', 0, 'barba')
    # LOS CUERNOS-RAMA, RETORCIDOS (05/10: "no tan rectas, mas retorcidas"): cada uno es una rama que se va torciendo
    # y doblando a tramos, con NUDOS en los codos, ramitas que salen a los lados y la LIANA enrollada en espiral.
    for s in (-1, 1):
        _rama_retorcida(add, V((3.5 * s, 0.0, 32.5)), V((0.55 * s, -0.05, 0.83)), 25.0, 2.8, 0.55, s, 5, 2)
    # EL MUSGO: matorrales en los dos hombros y un mechon en la coronilla.
    # MATORRAL, no hombreras: muchos bultos pequeños que se funden poco (la primera vuelta eran cuatro bolas lisas).
    rng = np.random.default_rng(11)
    for s in (-1, 1):
        for k in range(16):
            d = rng.normal(size=3); d[2] = abs(d[2]) * 0.8; d /= np.linalg.norm(d)
            c = V((9.5 * s, 0.0, 29.5)) + d * V((3.6, 3.6, 3.0))
            r = 1.6 + rng.random() * 1.3
            _elip(add, c, (r, r, r * 0.85), 'musgo', 0.5, 'musgo')
    for (dx, dz, r) in ((0, 35.5, 3.6), (-2.5, 34.5, 2.6), (2.6, 34.8, 2.8)):
        _elip(add, (dx, 0.5, dz), (r, r, r * 0.8), 'musgo', 1.2, 'musgo')
    # LOS BRAZOS: ramas GRUESAS que se tuercen (hombro, un codo nudoso, el antebrazo que se abre), con un muñon de rama
    # que les sale, la liana enrollada en la muñeca y unas MANAZAS de dedos-rama doblados.
    for s in (-1, 1):
        pts = [V((9.5 * s, 0.8, 28.0)), V((12.5 * s, 0.0, 23.5)), V((13.5 * s, 2.0, 18.5)), V((12.0 * s, 3.8, 15.0)),
               V((13.0 * s, 5.0, 12.0))]
        rs = [3.4, 3.0, 3.3, 2.8, 3.1]
        g = 'brazo%d' % s
        for k in range(len(pts) - 1):
            _cono(add, pts[k], pts[k + 1], rs[k], rs[k + 1], 'corteza', 1.2, g)
        _elip(add, pts[2], (3.9, 3.9, 3.4), 'corteza', 1.0, g)                      # el codo, nudoso
        _cono(add, pts[1], pts[1] + V((2.8 * s, -1.0, 3.2)), 1.2, 0.4, 'corteza', 0, g)   # un muñon de rama
        _elip(add, pts[2] + V((1.5 * s, 2.6, 0.0)), (1.0, 1.0, 1.4), 'hueco', 0, 'nudo')
        for u in (0.25, 0.6):
            c = pts[3] + (pts[4] - pts[3]) * u
            _elip(add, c, (3.4, 3.4, 0.65), 'liana', 0, 'liana')
        mano = pts[4]
        _elip(add, mano + V((0, 0.6, -0.8)), (3.2, 2.8, 2.4), 'corteza', 0.8, g)
        for k in (-1.5, -0.5, 0.5, 1.5):
            f1 = mano + V((1.0 * k + 0.3 * s, 2.0, -2.0))
            f2 = f1 + V((0.4 * k, 1.6, -2.2))
            _cono(add, mano + V((0.6 * k, 1.0, -1.0)), f1, 1.0, 0.75, 'corteza', 0.3, g)
            _cono(add, f1, f2, 0.75, 0.35, 'corteza', 0, g)
    # LAS PIERNAS: tocones cortos y gordos que se ABREN abajo en RAICES como dedos, clavadas en el suelo.
    for s in (-1, 1):
        g = 'pierna%d' % s
        cad = V((4.6 * s, 0.4, 12.5)); rod = V((5.4 * s, 1.4, 7.0)); pie = V((5.2 * s, 1.0, 2.0))
        _cono(add, cad, rod, 3.5, 3.1, 'corteza', 1.0, g)
        _cono(add, rod, pie, 3.1, 3.6, 'corteza', 1.0, g)
        for k in range(6):
            a = k / 6 * 2 * math.pi + (0.5 if s > 0 else 0.0)
            largo = 5.5 if math.sin(a) > 0.2 else 3.8          # las de delante, mas largas
            m = pie + V((math.cos(a) * largo * 0.55, math.sin(a) * largo * 0.55, -0.6))
            f = pie + V((math.cos(a) * largo, math.sin(a) * largo, -1.6))
            _cono(add, pie + V((0, 0, -0.5)), m, 1.7, 1.2, 'corteza', 0.6, g)
            _cono(add, m, f, 1.2, 0.45, 'corteza', 0, g)
    return e.L


# ------------------------------------------------------------
#  B. LOS TOCONES
# ------------------------------------------------------------
MAT_B = {
    'madera': [(0.42, 0.28, 0.14), (0.62, 0.44, 0.24), (0.78, 0.60, 0.36)],
    'oscura': [(0.24, 0.15, 0.08), (0.34, 0.22, 0.12), (0.44, 0.30, 0.17)],
    'hierba': [(0.16, 0.24, 0.12), (0.24, 0.36, 0.17), (0.34, 0.48, 0.24)],
    'runa':   [(0.62, 0.95, 1.0)] * 3,
    'flor':   [(0.70, 0.96, 1.0)] * 3,
    'tallo':  [(0.14, 0.26, 0.20), (0.20, 0.36, 0.28), (0.28, 0.46, 0.36)],
}
MOD_B = Modelo(2.5, LIENZO, PIES, MAT_B, (0.12, 0.07, 0.04), suaves=('cuerpo',), brillan=('runa', 'flor'),
               corta_suelo=True)


def escena_tocones():
    e = Escena({'raiz': IDENT}); add = e.add
    # EL CUERPO: un tronco tumbado y encorvado, alto entre las cuatro patas.
    _elip(add, (0, -1.0, 25.0), (7.0, 9.5, 6.0), 'oscura')
    _elip(add, (0, 4.5, 27.0), (6.0, 5.0, 5.5), 'oscura', 2.0)
    # LA MASCARA: una tabla de madera clara con el borde de astillas, colgando por delante, con las RUNAS que brillan
    # (un rombo en la frente y los dos ojos rasgados).
    add(lambda P: sd_caja(P, V((0, 10.5, 22.5)), [V((1, 0, 0)), V((0, 0.94, 0.34)), V((0, -0.34, 0.94))], (3.6, 1.0, 6.5), 1.2),
        'madera', 0, 'mascara')
    for k in (-1, 0, 1):
        _cono(add, (k * 1.8, 11.2, 28.0), (k * 2.2, 11.0, 31.5), 0.8, 0.3, 'madera', 0, 'mascara')
    add(lambda P: sd_caja(P, V((0, 11.6, 25.0)), [V((0.7, 0, 0.7)), V((0, 1, 0)), V((-0.7, 0, 0.7))], (0.9, 0.35, 0.9), 0.1),
        'runa', 0, 'runa')
    for s in (-1, 1):
        _cono(add, (0.8 * s, 11.6, 21.6), (2.4 * s, 11.4, 22.4), 0.4, 0.35, 'runa', 0, 'runa')
    # LAS CUATRO PATAS: tocones tallados, de pie, con raices abiertas y un manojo de hierba en el pie, unidos al cuerpo
    # por brazos-rama.
    for sx in (-1, 1):
        for sy in (-1, 1):
            base = V((11.0 * sx, 7.0 * sy, 0.0))
            _cono(add, base + V((0, 0, 1.5)), base + V((0.5 * sx, 0, 14.0)), 3.6, 2.6, 'madera', 0, 'pata%d%d' % (sx, sy))
            _cono(add, base + V((0.5 * sx, 0, 14.0)), base + V((0.2 * sx, 0.5, 17.0)), 2.6, 0.8, 'madera', 0,
                  'pata%d%d' % (sx, sy))
            # la runa de la pata (una raya que brilla)
            _cono(add, base + V((-1.2 * sx, 3.1 * sy * 0 + 3.0, 8.0)), base + V((-0.6 * sx, 3.2, 10.5)), 0.35, 0.35, 'runa',
                  0, 'runa')
            _cono(add, V((5.0 * sx, 3.5 * sy, 26.0)), base + V((0.3 * sx, 0, 12.5)), 2.4, 1.8, 'oscura', 1.0, 'cuerpo')
            for k in range(4):
                a = k / 4 * 2 * math.pi + 0.4
                _cono(add, base + V((0, 0, 1.2)), base + V((math.cos(a) * 4.5, math.sin(a) * 4.0, 0.3)), 1.4, 0.4,
                      'oscura', 0, 'pata%d%d' % (sx, sy))
            for k in range(5):
                a = k / 5 * 2 * math.pi
                _cono(add, base + V((math.cos(a) * 3.0, math.sin(a) * 2.6, 0.5)),
                      base + V((math.cos(a) * 4.2, math.sin(a) * 3.6, 3.2)), 0.7, 0.2, 'hierba', 0, 'hierba')
    # LAS RAMAS DE ARRIBA, retorcidas, con FLORES DE LUZ colgando y barbas de musgo.
    for s in (-1, 1):
        a = V((3.0 * s, -3.0, 30.0)); b = V((5.5 * s, -2.0, 38.0)); c = V((4.0 * s, -3.5, 46.0))
        _cono(add, a, b, 1.6, 1.1, 'oscura', 0, 'rama')
        _cono(add, b, c, 1.1, 0.5, 'oscura', 0, 'rama')
        _cono(add, b, b + V((3.5 * s, 0.5, 3.0)), 0.8, 0.35, 'oscura', 0, 'rama')
        _cono(add, b + V((0, 0, 1.0)), b + V((-1.5 * s, 2.5, 5.5)), 0.4, 0.3, 'tallo', 0, 'flor')
        _cono(add, b + V((-1.5 * s, 2.5, 5.5)), b + V((-2.5 * s, 3.5, 3.0)), 0.3, 0.3, 'tallo', 0, 'flor')
        _cono(add, b + V((-2.5 * s, 3.5, 3.0)), b + V((-2.7 * s, 3.7, 1.2)), 0.5, 1.3, 'flor', 0, 'flor')
        _cono(add, c, c + V((0.8 * s, 0, -4.0)), 0.35, 0.2, 'hierba', 0, 'musgo')
    return e.L


# ------------------------------------------------------------
#  C. LA ZARZA
# ------------------------------------------------------------
MAT_C = {
    'hoja':   [(0.20, 0.30, 0.12), (0.32, 0.45, 0.17), (0.48, 0.60, 0.26)],
    'hoja2':  [(0.30, 0.42, 0.16), (0.44, 0.58, 0.22), (0.60, 0.72, 0.32)],
    'rama':   [(0.16, 0.10, 0.20), (0.26, 0.16, 0.30), (0.36, 0.24, 0.42)],
    'ojo':    [(1.0, 0.80, 0.30)] * 3,
    'boca':   [(0.74, 1.0, 0.42)] * 3,
}
MOD_C = Modelo(2.5, LIENZO, PIES, MAT_C, (0.10, 0.07, 0.12), suaves=('cuerpo',), brillan=('ojo', 'boca'),
               corta_suelo=True)


def escena_zarza():
    e = Escena({'raiz': IDENT}); add = e.add
    C0 = V((0.0, 0.0, 25.0)); R0 = 12.5
    # LA BOLA DE HOJAS, con las hojas sueltas por encima (escamas mas claras) para que no sea una pelota lisa.
    _elip(add, C0, (R0, R0, R0 * 0.95), 'hoja')
    rng = np.random.default_rng(3)
    for k in range(34):
        d = rng.normal(size=3); d /= np.linalg.norm(d)
        if d[2] < -0.35 or (d[1] > 0.55 and d[2] < 0.35):
            continue
        p = C0 + d * R0 * 0.98
        _elip(add, p, (3.0, 3.0, 1.2), 'hoja2', 0, 'hojas')
    # LAS ESPINAS: ramitas moradas que salen de la bola.
    for k in range(9):
        a = k / 9 * 2 * math.pi + 0.3
        d = V((math.cos(a) * 0.8, math.sin(a) * 0.8 - 0.1, 0.55)); d /= np.linalg.norm(d)
        p = C0 + d * R0 * 0.9
        _cono(add, p, p + d * 9.0 + V((0, 0, 3.0)), 1.2, 0.25, 'rama', 0, 'espina')
    # LOS OJOS: varios, amarillos, de distinto tamaño, en la parte alta de la cara.
    for (x, z, r) in ((-4.6, 29.0, 2.6), (4.4, 29.6, 2.8), (-0.8, 32.6, 1.7), (1.6, 26.4, 1.4), (-7.0, 25.6, 1.4)):
        y = math.sqrt(max(R0 * R0 - x * x - (z - C0[2]) ** 2, 1.0)) - 0.4
        _elip(add, (x, y, z), (r, r * 0.6, r * 0.8), 'ojo', 0, 'ojo')
    # LA BOCA: una raja DENTADA que brilla en verde, abajo en la cara (zigzag de picos arriba y abajo).
    add(lambda P: np.maximum(sd_elipsoide(P, V((0, R0 - 1.2, 19.5)), V((6.5, 2.0, 3.0))), -sd_elipsoide(P, C0, V((R0 + 5, R0 - 1.6, R0 + 5)))),
        'boca', 0, 'boca')
    for k in range(5):
        x = -5.0 + k * 2.5
        _cono(add, (x, R0 - 0.8, 22.6), (x + 0.4, R0 - 0.3, 20.3), 0.9, 0.2, 'hoja', 0, 'diente')
        _cono(add, (x + 1.2, R0 - 0.8, 16.8), (x + 1.0, R0 - 0.3, 18.8), 0.8, 0.2, 'hoja', 0, 'diente')
    # LAS PATAS: dos ramitas moradas retorcidas, dobladas, con garras de espino.
    for s in (-1, 1):
        a = V((5.0 * s, 1.0, 14.0)); b = V((9.0 * s, 3.0, 8.0)); c = V((8.0 * s, 4.0, 0.8))
        _cono(add, a, b, 1.5, 1.2, 'rama', 0, 'pata%d' % s)
        _cono(add, b, c, 1.2, 0.9, 'rama', 0, 'pata%d' % s)
        for k in (-1, 0, 1):
            _cono(add, c, c + V((1.5 * k, 2.6, -0.3)), 0.6, 0.2, 'rama', 0, 'pata%d' % s)
        # LOS BRAZOS: largos y finos, cuelgan hasta casi el suelo y acaban en un manojo de hojas.
        h = V((11.0 * s, 0.5, 22.0)); m = V((15.5 * s, 2.0, 15.0)); f = V((15.0 * s, 5.0, 7.0))
        _cono(add, h, m, 1.2, 0.9, 'rama', 0, 'brazo%d' % s)
        _cono(add, m, f, 0.9, 0.8, 'rama', 0, 'brazo%d' % s)
        _elip(add, f, (2.6, 2.2, 2.4), 'hoja2', 0, 'mano%d' % s)
        for k in (-1, 1):
            _cono(add, f, f + V((1.6 * k, 2.4, -1.8)), 0.6, 0.2, 'rama', 0, 'mano%d' % s)
    return e.L


VERSIONES = (('actual', trent_sdf.MODELO, lambda: trent_sdf.escena(trent_sdf.POSE())),
             ('A guardian', MOD_A, escena_guardian), ('B tocones', MOD_B, escena_tocones), ('C zarza', MOD_C, escena_zarza))

if __name__ == '__main__':
    from PIL import Image, ImageDraw
    filas = []
    for nombre, mo, fn in VERSIONES:
        L = fn()
        fotos = [render(mo, L, d) for d in range(5)]
        W, H = fotos[0].size
        # recorte: el lienzo es muy ancho (los barridos); la figura va en el centro
        x0, x1 = W // 4, W * 3 // 4
        fila = Image.new('RGB', ((x1 - x0) * 5, H + 14), (40, 42, 50))
        for i, f in enumerate(fotos):
            fila.paste(f.crop((x0, 0, x1, H)), (i * (x1 - x0), 14), f.crop((x0, 0, x1, H)))
        ImageDraw.Draw(fila).text((4, 2), nombre, fill=(230, 230, 230))
        filas.append(fila)
        print(nombre, 'ok')
    out = Image.new('RGB', (filas[0].width, sum(f.height for f in filas)))
    y = 0
    for f in filas:
        out.paste(f, (0, y)); y += f.height
    out = out.resize((out.width * 2, out.height * 2), Image.NEAREST)
    os.makedirs('tools/salida/sdf', exist_ok=True)
    out.save('tools/salida/sdf/trent_versiones.png')
    print('tools/salida/sdf/trent_versiones.png')
