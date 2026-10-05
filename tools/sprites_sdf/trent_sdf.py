# ============================================================
#  trent_sdf.py -- el TRENT en 3D: el GUARDIAN (05/10/2026, elegido por el jefe entre tres propuestas de sus
#  referencias, ver trent_versiones.py). Un corpachon de tronco que se tuerce, con la cara tallada (ojos amarillos que
#  brillan, ceja de corteza y barba de astillas), dos cuernos-rama RETORCIDOS con liana, matorral de musgo en los
#  hombros, brazos de rama gruesa con codo nudoso y manazas, y piernas de tocon que se abren en raices.
#  HUESOS: raiz (avanza, cae de lado al morir), tronco (se mece adelante/atras sobre su base, se ladea, gira medio
#  cuerpo, se asienta), los dos brazos (alza/descarga, se abren, se columpian) y las dos piernas (el paso).
#  LOS TIEMPOS de cada gesto, los del viejo (trent_sprites.gd), para que sus efectos aprobados sigan cayendo igual.
#  El lienzo y el origen de su horneado (2,50 -> 306 x 216).
#  Uso: python tools/sprites_sdf/trent_sdf.py [anim ...]  -> assets/sprites/enemigos/trent_sdf/<anim>.png
#       python tools/sprites_sdf/trent_sdf.py vistas     -> tools/salida/sdf/trent_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/trent_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

MAT = {
    'corteza': [(0.36, 0.19, 0.16), (0.52, 0.29, 0.23), (0.66, 0.40, 0.31)],
    'musgo':   [(0.20, 0.48, 0.40), (0.33, 0.68, 0.56), (0.55, 0.84, 0.72)],
    'liana':   [(0.10, 0.20, 0.14), (0.16, 0.30, 0.21), (0.22, 0.40, 0.28)],
    'ojo':     [(1.0, 0.93, 0.55)] * 3,
    'hueco':   [(0.14, 0.07, 0.06)] * 3,
}
LIENZO = (306, 216)
PIES = (153.0, 216 * 2.10 / 3.80)
MODELO = Modelo(2.5, LIENZO, PIES, MAT, (0.12, 0.06, 0.05), suaves=('cuerpo', 'musgo'), brillan=('ojo',),
                corta_suelo=True)

BASE_TRONCO = V((0.0, 0.0, 10.0))
HOMBRO = {-1: V((-9.5, 0.8, 28.0)), 1: V((9.5, 0.8, 28.0))}
CADERA = {-1: V((-4.6, 0.4, 12.5)), 1: V((4.6, 0.4, 12.5))}


def POSE(**k):
    p = dict(avance=0.0, mece=0.0, balanceo=0.0, gira=0.0, alza=0.0, abre=0.0, columpio=0.0, patas=0.0,
             tumba=0.0, derrumbe=0.0, recoge=0.0, clava=0.0, hunde=0.0)
    p.update(k)
    return p


def _brazo_ang(alza):
    # 'alza' como en el viejo: + las ramas ARRIBA (hasta por encima de la cabeza), - DESCARGADAS hacia delante y abajo.
    return -2.3 * alza if alza > 0 else 0.6 * alza


def huesos(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], -p['hunde'])))
    if p['tumba'] > 0.0:
        # CAE COMO UN ARBOL: de lado (hacia su derecha), sobre el canto del pie.
        raiz = comp(sobre(V((-7.0, 0.0, 0.0)), ry(-p['tumba'] * math.pi * 0.5)), raiz)
    X['raiz'] = raiz
    # EL TRONCO, sobre su base: 'mece' + hacia delante, 'balanceo' de lado, 'gira' medio cuerpo, 'derrumbe' se asienta.
    M = rz(p['gira']) @ rx(p['mece'] * 0.09) @ ry(p['balanceo'] * 0.10) @ np.diag([1.0, 1.0, 1.0 - p['derrumbe']])
    X['tronco'] = comp(raiz, sobre(BASE_TRONCO, M))
    for s, ld in ((-1, 'd'), (1, 'i')):
        # 'clava' (las Raices): los brazos bajan por delante hasta meter las manos en la tierra.
        a = _brazo_ang(p['alza']) * (1.0 - p['clava']) - 0.30 * p['clava'] + p['columpio'] * 0.30 * s
        Mb = rx(a) @ ry(-s * p['abre'] * 0.5)
        X['brazo_' + ld] = comp(X['tronco'], sobre(HOMBRO[s], Mb))
        # El paso: pierna adelante y atras; al caer se recogen hacia el tronco.
        Mp = rx(p['patas'] * 0.32 * s) @ ry(s * p['recoge'] * 0.06)
        X['pierna_' + ld] = comp(raiz, sobre(CADERA[s], Mp))
    return X


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='tronco'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='tronco'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


# UNA RAMA RETORCIDA: tramo a tramo, la direccion se va girando (unas veces hacia fuera, otras hacia atras) con un
# meneo de seno y algo de azar; en los codos un NUDO, cada pocos tramos una RAMITA (la misma funcion, mas corta) y, en
# las gordas, la LIANA en espiral alrededor.
def _rama_retorcida(add, base, dir0, largo, r0, r1, s, semilla, nivel, hueso='tronco'):
    rng = np.random.default_rng(semilla)
    n = 9 if nivel >= 2 else 5
    paso = largo / n
    d = dir0 / np.linalg.norm(dir0)
    p = base.copy()
    puntos = [p.copy()]
    for k in range(n):
        u = k / n
        giro = V((0.34 * math.sin(k * 1.7 + semilla) * s, 0.30 * math.cos(k * 1.3 + semilla * 0.7), 0.0))
        giro += rng.normal(size=3) * (0.05 if nivel >= 2 else 0.12)
        d = d + giro
        d[2] = max(d[2], 0.45 if nivel >= 2 else 0.15)   # que no se tumbe: el cuerno siempre sube
        d /= np.linalg.norm(d)
        q = p + d * paso
        ra = r0 + (r1 - r0) * u
        rb = r0 + (r1 - r0) * (k + 1) / n
        _cono(add, p, q, ra, rb, 'corteza', 0.5, 'cuerno', hueso)
        if k in (2, 5) and nivel >= 1:
            _elip(add, p, (ra * 1.35, ra * 1.35, ra * 1.25), 'corteza', 0.4, 'cuerno', hueso)
        if nivel >= 1 and k in ((2, 4, 6) if nivel >= 2 else (2,)):
            lado = V((-d[1], d[0], 0.0)); lado = lado / max(np.linalg.norm(lado), 1e-6)
            sgn = 1 if k % 4 == 2 else -1
            dr = d * 0.5 + lado * sgn * 0.9 + V((0, 0, 0.35))
            _rama_retorcida(add, q, dr, largo * (0.32 if nivel >= 2 else 0.4), rb * 0.7, 0.3, s * sgn, semilla * 7 + k,
                            nivel - 1, hueso)
        puntos.append(q.copy())
        p = q
    # LA LIANA: una espiral alrededor del primer tramo de la rama gorda.
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
                _cono(add, prev, pt, 0.42, 0.42, 'liana', 0, 'liana', hueso)
            prev = pt
        mitad = puntos[len(puntos) // 2]
        _cono(add, mitad + V((0, 0.6, -0.5)), mitad + V((0.6 * s, 1.0, -7.5)), 0.4, 0.3, 'liana', 0, 'liana', hueso)


def escena(pose):
    e = Escena(huesos(pose)); add = e.add
    # EL CUERPO: un tronco que se tuerce un poco a tramos (no un tubo: "muy rectos y rancios"), con la base abierta y
    # algo ancho de hombros; la cara va tallada en su parte alta (no tiene cuello).
    eje = [V((0.0, -0.4, 10.5)), V((0.9, 0.0, 16.5)), V((-0.7, 0.7, 22.5)), V((0.2, 1.0, 29.0)), V((0.0, 0.9, 32.0))]
    radios = [7.8, 6.8, 7.2, 8.0, 7.6]
    for k in range(len(eje) - 1):
        _cono(add, eje[k], eje[k + 1], radios[k], radios[k + 1], 'corteza', 2.0)
    _elip(add, (0, 0.5, 31), (8.5, 6.5, 5.0), 'corteza', 2.0)
    _elip(add, (0, -0.3, 11.5), (8.8, 7.8, 3.2), 'corteza', 2.0)
    # LAS VETAS: costillas de corteza en relieve, a lo largo y algo en espiral, y unos NUDOS (agujero oscuro).
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
    # LOS CUERNOS-RAMA, RETORCIDOS, en espejo.
    for s in (-1, 1):
        _rama_retorcida(add, V((3.5 * s, 0.0, 32.5)), V((0.55 * s, -0.05, 0.83)), 25.0, 2.8, 0.55, s, 5, 2)
    # EL MUSGO: matorral en los dos hombros (muchos bultos pequeños) y un mechon en la coronilla.
    rng = np.random.default_rng(11)
    for s in (-1, 1):
        for k in range(16):
            d = rng.normal(size=3); d[2] = abs(d[2]) * 0.8; d /= np.linalg.norm(d)
            c = V((9.5 * s, 0.0, 29.5)) + d * V((3.6, 3.6, 3.0))
            r = 1.6 + rng.random() * 1.3
            _elip(add, c, (r, r, r * 0.85), 'musgo', 0.5, 'musgo')
    for (dx, dz, r) in ((0, 35.5, 3.6), (-2.5, 34.5, 2.6), (2.6, 34.8, 2.8)):
        _elip(add, (dx, 0.5, dz), (r, r, r * 0.8), 'musgo', 1.2, 'musgo')
    # LOS BRAZOS: ramas GRUESAS que se tuercen (hombro, un codo nudoso, el antebrazo que se abre), con un muñon de rama,
    # la liana enrollada en la muñeca y unas MANAZAS de dedos-rama doblados.
    for s in (-1, 1):
        hb = 'brazo_d' if s < 0 else 'brazo_i'
        g = 'brazo%d' % s
        pts = [V((9.5 * s, 0.8, 28.0)), V((12.5 * s, 0.0, 23.5)), V((13.5 * s, 2.0, 18.5)), V((12.0 * s, 3.8, 15.0)),
               V((13.0 * s, 5.0, 12.0))]
        rs = [3.4, 3.0, 3.3, 2.8, 3.1]
        for k in range(len(pts) - 1):
            _cono(add, pts[k], pts[k + 1], rs[k], rs[k + 1], 'corteza', 1.2, g, hb)
        _elip(add, pts[2], (3.9, 3.9, 3.4), 'corteza', 1.0, g, hb)
        _cono(add, pts[1], pts[1] + V((2.8 * s, -1.0, 3.2)), 1.2, 0.4, 'corteza', 0, g, hb)
        _elip(add, pts[2] + V((1.5 * s, 2.6, 0.0)), (1.0, 1.0, 1.4), 'hueco', 0, 'nudo', hb)
        for u in (0.25, 0.6):
            c = pts[3] + (pts[4] - pts[3]) * u
            _elip(add, c, (3.4, 3.4, 0.65), 'liana', 0, 'liana', hb)
        mano = pts[4]
        _elip(add, mano + V((0, 0.6, -0.8)), (3.2, 2.8, 2.4), 'corteza', 0.8, g, hb)
        for k in (-1.5, -0.5, 0.5, 1.5):
            f1 = mano + V((1.0 * k + 0.3 * s, 2.0, -2.0))
            f2 = f1 + V((0.4 * k, 1.6, -2.2))
            _cono(add, mano + V((0.6 * k, 1.0, -1.0)), f1, 1.0, 0.75, 'corteza', 0.3, g, hb)
            _cono(add, f1, f2, 0.75, 0.35, 'corteza', 0, g, hb)
    # LAS PIERNAS: tocones cortos y gordos que se ABREN abajo en RAICES como dedos, clavadas en el suelo.
    for s in (-1, 1):
        hp = 'pierna_d' if s < 0 else 'pierna_i'
        g = 'pierna%d' % s
        cad = CADERA[s]; rod = V((5.4 * s, 1.4, 7.0)); pie = V((5.2 * s, 1.0, 2.0))
        _cono(add, cad, rod, 3.5, 3.1, 'corteza', 1.0, g, hp)
        _cono(add, rod, pie, 3.1, 3.6, 'corteza', 1.0, g, hp)
        for k in range(6):
            a = k / 6 * 2 * math.pi + (0.5 if s > 0 else 0.0)
            largo = 5.5 if math.sin(a) > 0.2 else 3.8          # las de delante, mas largas
            m = pie + V((math.cos(a) * largo * 0.55, math.sin(a) * largo * 0.55, -0.6))
            f = pie + V((math.cos(a) * largo, math.sin(a) * largo, -1.6))
            _cono(add, pie + V((0, 0, -0.5)), m, 1.7, 1.2, 'corteza', 0.6, g, hp)
            _cono(add, m, f, 1.2, 0.45, 'corteza', 0, g, hp)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # Quieto: se mece muy despacio y las ramas se columpian un poco (3 fps: tiene que LEERSE lento).
    return POSE(mece=0.5 * math.sin(2 * math.pi * t), columpio=0.25 * math.sin(2 * math.pi * t + 0.8))


def anim_walk(t):
    # NADA DE BOTE: se BALANCEA de un pie al otro y arrastra el peso.
    f = math.sin(2 * math.pi * t)
    return POSE(mece=0.9 * f, balanceo=f, columpio=0.8 * f, patas=f)


def anim_embestida(t):
    # EL RAMAZO: se echa atras, alza las ramas y las DESCARGA hacia delante (en 0,55), plantado.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 3.4), (0.75, 3.8), (1.0, 2.4)]) * (5.0 / 3.8),
                mece=tramos(t, [(0.0, 0.0), (0.35, -1.2), (0.55, 1.6), (0.75, 0.8), (1.0, 0.2)]),
                alza=tramos(t, [(0.0, 0.0), (0.35, 1.0), (0.55, -0.9), (0.75, -0.4), (1.0, 0.0)]))


def anim_escupir(t):
    # LA SAVIA: se echa atras cogiendo aire (ramas arriba y abiertas) y se vuelca al soltar (en el 3o-4o), ladeandose.
    return POSE(mece=tramos(t, [(0.0, 0.0), (0.143, -1.4), (0.286, -2.2), (0.429, 2.0), (0.571, 2.6), (0.714, 1.4),
                                (0.857, 0.5), (1.0, 0.0)]),
                balanceo=tramos(t, [(0.0, 0.0), (0.143, -0.9), (0.286, -1.5), (0.429, 0.8), (0.571, 1.2), (0.714, 0.6),
                                    (0.857, 0.2), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.143, 0.6), (0.286, 1.1), (0.429, 0.7), (0.571, 0.3), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.143, 0.65), (0.286, 1.05), (0.429, 0.10), (0.571, -0.45), (0.714, -0.30),
                                (0.857, -0.12), (1.0, 0.0)]))


def anim_basico(t):
    # EL BASICO: baja las ramas al suelo y TIRA hacia arriba de golpe (en 0,55): arranca la raiz que cae encima.
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 1.0), (0.75, 0.7), (1.0, 0.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.35, 1.0), (0.55, -0.9), (0.75, -0.5), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.35, 0.5), (0.55, 0.2), (1.0, 0.0)]))


def _barrido(t, signo):
    # EL RAMAZO BAJO: GIRA medio cuerpo con las ramas bajas y abiertas, de un lado al otro (la vuelta, al reves).
    bal = tramos(t, [(0.0, -1.1 * signo), (0.5, 1.2 * signo), (1.0, 1.0 * signo)])
    return POSE(mece=0.9 * math.sin(math.pi * t), balanceo=bal * 0.5, gira=bal * 0.45, abre=0.8, alza=-0.6)


def anim_barrido_raiz(t):
    return _barrido(t, 1.0)


def anim_barrido_vuelta(t):
    return _barrido(t, -1.0)


def anim_raices(t):
    # CLAVA LAS MANOS EN EL SUELO (en 0,52) y AHI SE QUEDA, agarrado, mientras las raices salen por debajo: alza las
    # ramas, se dobla hacia delante agachandose y las hunde en la tierra.
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.28, 0.95), (0.52, 0.0), (1.0, 0.0)]),
                clava=tramos(t, [(0.0, 0.0), (0.28, 0.0), (0.52, 1.0), (1.0, 1.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.28, -0.9), (0.52, 3.2), (0.74, 2.8), (1.0, 2.6)]),
                hunde=tramos(t, [(0.0, 0.0), (0.28, 0.0), (0.52, 3.0), (0.74, 2.6), (1.0, 2.5)]))


def anim_encaje(t):
    # PLANTADO, no retrocede: la sacudida es del tronco, que se pasa de largo y rebota.
    return POSE(mece=tramos(t, [(0.0, -1.9), (0.34, 1.0), (0.67, -0.4), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.30), (0.34, -0.35), (0.67, 0.12), (1.0, 0.0)]))


def anim_muerte(t):
    # SE CAE COMO UN ARBOL: cruje hacia el otro lado, se inclina y a partir de cierto punto se desploma ACELERANDO; las
    # ramas se descuelgan, los pies se recogen y al tocar el suelo se asienta un poco.
    return POSE(tumba=tramos(t, [(0.0, 0.0), (0.14, 0.06), (0.28, 0.20), (0.45, 0.52), (0.62, 0.84), (0.78, 1.02),
                                 (0.90, 0.97), (1.0, 1.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.14, -0.8), (0.28, -0.4), (0.45, 0.0), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.14, 0.3), (0.28, -0.3), (0.62, -0.45), (1.0, -0.5)]),
                recoge=tramos(t, [(0.0, 0.0), (0.28, 1.2), (0.62, 5.0), (0.78, 7.0), (1.0, 7.2)]),
                derrumbe=tramos(t, [(0.0, 0.0), (0.62, 0.0), (0.78, 0.06), (1.0, 0.08)]))


ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 5.0, True, 8, anim_walk),
    'embestida': (8, 8.0, False, 8, anim_embestida),
    'escupir': (8, 10.0, False, 8, anim_escupir),
    'basico': (8, 9.0, False, 8, anim_basico),
    'barrido_raiz': (6, 10.0, False, 8, anim_barrido_raiz),
    'barrido_vuelta': (6, 10.0, False, 8, anim_barrido_vuelta),
    'raices': (8, 7.0, False, 8, anim_raices),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'trent_598040_2.50', VISTAS + 'trent_vs_viejo.png', 2))
    else:
        hornear('trent_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
