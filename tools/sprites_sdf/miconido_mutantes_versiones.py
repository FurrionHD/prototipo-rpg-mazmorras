# ============================================================
#  miconido_mutantes_versiones.py -- LOS MUTANTES DEL MICONIDO, propuestas en QUIETO (09/11/2026, miconido-mutante).
#  Arbol (el jefe): LINEA  Miconido -> 1a LUMINOSO -> 2a CORDYCEPS (conserva la luz).
#    LUMINOSO: alto y flaco, sombrero que brilla en la oscuridad (laminas encendidas), filamentos.
#    CORDYCEPS: el cadaver de un aventurero movido por el hongo; tallos por espalda, hombros y yelmo, con las puntas
#      ENCENDIDAS (la luz de la 1a); arma oxidada del muerto.
#  Cuerpos PROPIOS, no el miconido con adornos ([[mutante-cambia-el-cuerpo-entero]]).
#  Uso: python tools/sprites_sdf/miconido_mutantes_versiones.py [filtro]
#       -> tools/salida/sdf/miconido_mutantes_versiones.png (y al escritorio, ataques_mapa/enemigos/prueba_3d/mutantes)
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import sdf_comun
import miconido_sdf as base

V = np.array


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _curva(add, pts, r0, r1, mat, k=0.0, grupo='cuerpo'):
    """Un tallo curvo: tramos de cono por una lista de puntos, el radio de r0 a r1."""
    n = len(pts) - 1
    for i in range(n):
        _cono(add, pts[i], pts[i + 1], r0 + (r1 - r0) * i / n, r0 + (r1 - r0) * (i + 1) / n, mat, k, grupo)


def _bez(a, b, c, n=6):
    a, b, c = V(a, dtype=float), V(b, dtype=float), V(c, dtype=float)
    return [(1 - u) ** 2 * a + 2 * (1 - u) * u * b + u * u * c for u in np.linspace(0, 1, n + 1)]


# ------------------------------------------------------------
#  MATERIALES
# ------------------------------------------------------------
# LUMINOSO: carne palida azulada (de cueva, sin sol), sombrero oscuro de noche y lo que BRILLA en cian-verde.
MAT_LUZ = {
    'carne':   [(0.44, 0.50, 0.55), (0.62, 0.68, 0.72), (0.78, 0.84, 0.86)],
    'sombrero': [(0.10, 0.16, 0.22), (0.16, 0.26, 0.34), (0.24, 0.38, 0.46)],
    'campana': [(0.18, 0.46, 0.52), (0.30, 0.66, 0.70), (0.52, 0.86, 0.86), (0.85, 1.0, 0.98)],
    'luz':     [(0.30, 0.85, 0.72), (0.48, 1.0, 0.86), (0.80, 1.0, 0.95)],
    'luz2':    [(0.30, 0.70, 0.90), (0.50, 0.88, 1.0), (0.82, 0.97, 1.0)],
    'mota':    [(0.36, 0.80, 0.70), (0.55, 0.96, 0.84), (0.82, 1.0, 0.94)],
    'raiz':    [(0.30, 0.34, 0.38), (0.44, 0.48, 0.52), (0.58, 0.62, 0.66)],
}
# CORDYCEPS: el muerto (piel gris verdosa, tela parda, cuero, hierro oxidado), el hongo NARANJA del cordyceps de
# verdad, el fieltro blanco del micelio que lo cubre y las puntas que BRILLAN con la luz de la 1a.
MAT_CORD = {
    'piel':    [(0.30, 0.33, 0.28), (0.44, 0.47, 0.40), (0.56, 0.59, 0.50)],
    'tela':    [(0.20, 0.15, 0.12), (0.31, 0.24, 0.18), (0.42, 0.33, 0.25)],
    'cuero':   [(0.16, 0.11, 0.08), (0.26, 0.18, 0.12), (0.36, 0.26, 0.17)],
    'hierro':  [(0.22, 0.20, 0.19), (0.38, 0.35, 0.32), (0.55, 0.52, 0.48), (0.80, 0.78, 0.74)],
    'oxido':   [(0.30, 0.13, 0.06), (0.46, 0.22, 0.10), (0.60, 0.32, 0.15)],
    'hongo':   [(0.52, 0.22, 0.06), (0.76, 0.38, 0.10), (0.92, 0.56, 0.20)],
    'micelio': [(0.62, 0.62, 0.58), (0.80, 0.80, 0.76), (0.92, 0.92, 0.88)],
    'luz':     [(0.30, 0.85, 0.72), (0.48, 1.0, 0.86), (0.80, 1.0, 0.95)],
    'campana': [(0.18, 0.46, 0.52), (0.30, 0.66, 0.70), (0.52, 0.86, 0.86), (0.85, 1.0, 0.98)],
    'sombrero': [(0.10, 0.16, 0.22), (0.16, 0.26, 0.34), (0.24, 0.38, 0.46)],
}

ESC = 2.0 * base.GRANDE
LIENZO = (260, 330)
PIES = (130, 230)


def modelo(mat, transl=()):
    return Modelo(ESC, LIENZO, PIES, mat, (0.04, 0.05, 0.06), suaves=('cuerpo',), brillan=('luz', 'luz2', 'mota'),
                  corta_suelo=True, especular=('campana', 'hierro'), umbral_especular=0.80, translucidos=transl, alfa=0.72)


M_LUZ = modelo(MAT_LUZ, ('campana',))
M_CORD = modelo(MAT_CORD, ('campana',))


def _escena():
    return Escena({'raiz': IDENT})


# ------------------------------------------------------------
#  LUMINOSO
# ------------------------------------------------------------
def _brazos_finos(add, hombro_z, largo, abre=0.5, mat='carne'):
    """Brazos larguisimos y finos, colgando hasta casi el suelo, con dedos de raicilla."""
    for s in (-1, 1):
        h = V((1.6 * s, 0.2, hombro_z))
        codo = h + V((abre * 1.6 * s, 0.6, -largo * 0.5))
        mano = codo + V((abre * 0.6 * s, 1.0, -largo * 0.5))
        _cono(add, h, codo, 0.62, 0.48, mat, 0.5, 'brazo%d' % s)
        _cono(add, codo, mano, 0.48, 0.36, mat, 0.3, 'brazo%d' % s)
        for k in (-1, 0, 1):
            _cono(add, mano, mano + V((0.45 * k, 0.5, -1.4)), 0.24, 0.1, mat, 0, 'brazo%d' % s)


def _pies_raiz(add, r=1.7):
    """Una base de raices que se agarran al suelo (sin patas): cuerpo de seta clavado."""
    _elip(add, (0, 0, 1.6), (r * 1.4, r * 1.3, 1.8), 'carne', 1.2)
    for k in range(6):
        a = k / 6 * 2 * math.pi + 0.4
        _cono(add, (math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, 1.4), (math.cos(a) * r * 2.4, math.sin(a) * r * 2.4, 0.2),
              0.6, 0.22, 'raiz', 0, 'raices')


def luminoso_medusa():
    """A MEDUSA: tallo flaco y alto, CAMPANA translucida que deja ver las laminas encendidas por dentro, y del borde
    cuelgan FILAMENTOS de luz como los de una medusa."""
    e = _escena(); add = e.add
    _pies_raiz(add, 1.5)
    # el tallo: flaco y alto, un poco curvo hacia delante (la "cara" la marca el ladeo, como el normal)
    _curva(add, _bez((0, 0, 1.5), (0, -0.6, 14), (0, 0.8, 25)), 1.7, 1.05, 'carne', 0.8)
    _elip(add, (0, 0.3, 17.5), (2.0, 1.8, 3.6), 'carne', 1.5)        # pecho: un engorde en el tallo
    _brazos_finos(add, 19.5, 13.0, 0.45)
    # la campana
    lad = rx(0.22)
    c0 = V((0, 0.9, 27.0))

    def campana(P):
        q = (P - c0) @ lad
        cap = sd_elipsoide(q, V((0, 0, 0.0)), V((6.8, 6.8, 5.6)))
        return np.maximum(cap, -(q[:, 2] + 1.2 - 0.03 * (q[:, 0] ** 2 + q[:, 1] ** 2)))
    add(campana, 'campana', 0, 'campana')
    # laminas encendidas por dentro de la campana
    for k in range(16):
        a = k / 16 * 2 * math.pi
        p0 = c0 + lad.T @ V((math.cos(a) * 1.0, math.sin(a) * 1.0, 0.6))
        p1 = c0 + lad.T @ V((math.cos(a) * 5.6, math.sin(a) * 5.6, -0.4))
        _cono(add, p0, p1, 0.3, 0.26, 'luz', 0, 'lamina')
    # nucleo: una bola de luz dentro (se ve por la campana)
    _elip(add, c0 + V((0, 0, 1.4)), (2.0, 2.0, 1.8), 'luz2', 0, 'nucleo')
    # filamentos del borde: caen ondulando, mas largos por detras
    for k in range(12):
        a = k / 12 * 2 * math.pi + 0.13
        borde = c0 + lad.T @ V((math.cos(a) * 6.2, math.sin(a) * 6.2, -1.0))
        largo = 7.0 + 4.0 * (1 - math.sin(a)) * 0.5 + 1.5 * math.sin(3 * a)
        mid = borde + V((math.cos(a) * 0.9, math.sin(a) * 0.9 + 0.6 * math.sin(2 * a), -largo * 0.5))
        fin = borde + V((math.cos(a) * 0.4 + 0.5 * math.sin(5 * a), math.sin(a) * 0.4, -largo))
        _curva(add, _bez(borde, mid, fin, 4), 0.34, 0.14, 'luz', 0, 'fil%d' % k)
    # motas de luz por encima de la campana
    for (x, y, r) in ((-3.2, 1.0, 0.7), (2.4, -2.8, 0.6), (1.0, 3.4, 0.55), (-1.6, -3.6, 0.6), (3.6, 1.6, 0.5)):
        z = 5.6 * math.sqrt(max(0.0, 1 - (x * x + y * y) / 46.0)) - 0.15
        _elip(add, c0 + lad.T @ V((x, y, z)), (r, r, 0.28), 'mota', 0, 'mota')
    return e.L


def luminoso_farol():
    """B FAROL: tallo LARGUISIMO y fino, encorvado como una farola, con un sombrero de CONO alto (la mycena de la
    cueva) que cuelga hacia delante; las laminas y el borde brillan, y del cuello cuelgan tres hilos de luz."""
    e = _escena(); add = e.add
    _pies_raiz(add, 1.7)
    pts = _bez((0, -0.5, 1.5), (0, -2.4, 26), (0, 3.2, 31))
    _curva(add, pts, 1.6, 0.85, 'carne', 0.8)
    _elip(add, (0, -0.9, 14.0), (1.9, 1.7, 3.4), 'carne', 1.6)
    _brazos_finos(add, 16.0, 11.5, 0.6)
    # el cono del sombrero, colgando hacia delante desde la punta del tallo
    top = pts[-1]
    eje = V((0, 0.55, -0.83)); eje = eje / np.linalg.norm(eje)       # hacia delante y abajo: la boca del farol
    base_c = top + eje * 2.2
    punta = top - eje * 6.0
    _cono(add, base_c, punta, 5.0, 0.6, 'sombrero', 0, 'farol')
    # la boca del farol: un disco de luz (las laminas) y un aro encendido en el borde
    def boca(P):
        q = P - base_c
        h = q @ eje
        rr = np.linalg.norm(q - np.outer(h, eje), axis=1)
        return np.maximum(np.abs(h) - 0.35, rr - 4.6)
    add(boca, 'luz', 0, 'boca')
    for k in range(14):
        a = k / 14 * 2 * math.pi
        u = np.cross(eje, V((1.0, 0, 0))); u /= np.linalg.norm(u); w = np.cross(eje, u)
        p = base_c + (u * math.cos(a) + w * math.sin(a)) * 5.0
        _elip(add, p, (0.55, 0.55, 0.55), 'luz2', 0, 'aro')
    # tres hilos de luz que cuelgan del sombrero
    for k, dx in enumerate((-2.6, 0.2, 2.8)):
        a0 = base_c + V((dx, 0.4, -0.5))
        _curva(add, _bez(a0, a0 + V((0.3, 0.6, -3.0)), a0 + V((-0.2, 0.3, -6.5 - k)), 4), 0.28, 0.14, 'luz', 0, 'hilo%d' % k)
    # vetas de luz que suben por el sombrero
    for k in range(5):
        a = (k - 2) * 0.55
        u = np.cross(eje, V((1.0, 0, 0))); u /= np.linalg.norm(u); w = np.cross(eje, u)
        d = (u * math.cos(a + 1.57) + w * math.sin(a + 1.57))
        _cono(add, base_c + d * 4.9 + eje * 0.1, punta + d * 0.5, 0.26, 0.12, 'luz2', 0, 'veta%d' % k)
    return e.L


def luminoso_racimo():
    """C RACIMO: un cuerpo encorvado, mas bajo y ancho, sin sombrero grande: de los hombros y la espalda le salen
    CINCO setas luminosas de tallo largo (un racimo de cueva), la mayor en lo alto como cabeza."""
    e = _escena(); add = e.add
    # piernas cortas como las del normal pero mas separadas
    for s in (-1, 1):
        _cono(add, (2.6 * s, 0.0, 4.4), (2.9 * s, 0.6, 0.9), 1.8, 2.0, 'carne', 0.7, 'pierna%d' % s)
    # cuerpo encorvado hacia delante
    _elip(add, (0, -0.4, 8.5), (4.8, 4.0, 5.0), 'carne', 2.0)
    _elip(add, (0, 1.2, 13.0), (4.2, 3.6, 3.8), 'carne', 2.0)
    _brazos_finos(add, 13.5, 11.0, 0.8)
    setas = [((0, 2.2, 15.0), (0, 3.6, 24.0), 4.4, 1.0),      # la cabeza
             ((-3.2, 0.0, 14.0), (-6.4, -1.2, 20.5), 2.8, 0.85),
             ((3.2, 0.2, 14.2), (6.8, -0.6, 19.0), 2.6, 0.8),
             ((-1.6, -2.6, 12.5), (-2.6, -5.8, 17.5), 2.2, 0.7),
             ((1.8, -2.8, 11.5), (3.4, -6.2, 15.0), 1.9, 0.6)]
    for i, (pie, top, r, rt) in enumerate(setas):
        mid = (V(pie) + V(top)) / 2 + V((0, 0.8, 0.6))
        _curva(add, _bez(pie, mid, top, 4), rt, rt * 0.7, 'carne', 0.6)
        t = V(top, dtype=float)

        def sombrero(P, t=t, r=r):
            cap = sd_elipsoide(P, t + V((0, 0, 0.4 * r / 4)), V((r, r, r * 0.55)))
            return np.maximum(cap, -(P[:, 2] - t[2] + 0.05 * ((P[:, 0] - t[0]) ** 2 + (P[:, 1] - t[1]) ** 2) / max(r / 4, 0.5)))
        add(sombrero, 'campana', 0, 'som%d' % i)
        _elip(add, t + V((0, 0, -0.1)), (r * 0.82, r * 0.82, 0.32), 'luz', 0, 'lam%d' % i)
        _elip(add, t + V((0, 0, r * 0.25)), (r * 0.42, r * 0.42, r * 0.3), 'luz2', 0, 'nuc%d' % i)
    # motas de luz por la espalda
    for (x, y, z) in ((-2.4, -3.2, 9.5), (2.0, -3.4, 8.0), (0.0, -3.8, 11.0), (-3.6, -1.4, 6.8), (3.4, -1.8, 10.6)):
        _elip(add, (x, y, z), (0.55, 0.4, 0.55), 'mota', 0, 'motas')
    return e.L


# ------------------------------------------------------------
#  CORDYCEPS: el cadaver
# ------------------------------------------------------------
def _cadaver(add, inclina=0.0, cabeza=True, arma=True, cuelga=0.35):
    """El aventurero muerto, de pie a tirones: piernas, torso con jubon y cinto, capa rasgada, yelmo abollado
    (cabeza colgando hacia un lado), un brazo colgando y el otro con la espada oxidada. 'inclina' = cuanto se dobla
    hacia delante (0 erguido, 1 muy encorvado)."""
    # piernas (un poco abiertas, rodillas flojas)
    for s in (-1, 1):
        cad = V((1.5 * s, 0.0, 11.0))
        rod = V((1.8 * s, 1.0 + 0.6 * inclina, 6.0))
        tob = V((1.9 * s, 0.2, 1.4))
        _cono(add, cad, rod, 1.25, 1.0, 'tela', 0, 'pierna%d' % s)
        _cono(add, rod, tob, 1.0, 0.85, 'tela', 0, 'pierna%d' % s)
        _elip(add, tob + V((0, 0.6, -0.6)), (1.05, 1.7, 0.9), 'cuero', 0, 'bota%d' % s)
        _cono(add, tob + V((0, 0, 0.2)), tob + V((0, 0, 2.6)), 1.05, 1.02, 'cuero', 0, 'bota%d' % s)
    # torso: de la cadera al pecho, doblandose
    cadera = V((0, 0, 11.5))
    pecho = cadera + V((0, 2.0 + 4.0 * inclina, 6.0 - 2.4 * inclina))
    cuello = pecho + V((0, 0.6 + 1.8 * inclina, 2.6 - 1.0 * inclina))
    _cono(add, cadera, pecho, 2.6, 3.0, 'tela', 0, 'torso')
    _elip(add, pecho + V((0, -0.2, 0.3)), (3.4, 2.2, 1.9), 'tela', 0, 'torso')
    # cinto con hebilla
    _elip(add, cadera + V((0, 0.2, 0.9)), (2.75, 1.95, 0.55), 'cuero', 0, 'cinto')
    _elip(add, cadera + V((0, 2.0, 0.9)), (0.55, 0.3, 0.45), 'oxido', 0, 'hebilla')
    # hombreras de cuero
    for s in (-1, 1):
        _elip(add, pecho + V((3.0 * s, -0.2, 0.9)), (1.4, 1.5, 0.9), 'cuero', 0, 'hombrera%d' % s)
    # capa rasgada por la espalda: tiras de tela que cuelgan
    for k in range(5):
        x = -2.4 + k * 1.2
        arriba = pecho + V((x, -2.0, 0.6))
        largo = 9.0 + (1.6 if k % 2 else -0.4) + 1.2 * math.sin(k * 2.3)
        abajo = V((x * 1.2, -2.6 - 1.0 * inclina, max(arriba[2] - largo, 2.6)))
        add(lambda P, a=arriba, b=abajo: sd_caja(P, (a + b) / 2, _ejes_tira(a, b), (0.62, 0.18, np.linalg.norm(b - a) / 2), 0.1),
            'tela', 0, 'capa%d' % k)
    # cabeza colgando de lado, con el yelmo abollado
    if cabeza:
        cab = cuello + V((cuelga * 2.2, 1.2 + 0.6 * inclina, 1.4 - cuelga * 0.8))
        _cono(add, cuello, cab, 1.0, 0.9, 'piel', 0, 'cuello')
        _elip(add, cab, (1.6, 1.8, 1.9), 'piel', 0, 'cabeza')
        _elip(add, cab + V((0, 0, 0.55)), (1.9, 2.05, 1.6), 'hierro', 0, 'yelmo')
        _elip(add, cab + V((0, 0, 0.1)), (2.2, 2.3, 0.3), 'oxido', 0, 'yelmo_ala')
        _elip(add, cab + V((-0.9, 0.8, 1.5)), (0.7, 0.7, 0.5), 'oxido', 0, 'abollon')
    else:
        cab = cuello
    # brazos: el izquierdo cuelga muerto; el derecho agarra la espada (o cuelga tambien)
    for s in (-1, 1):
        hom = pecho + V((3.1 * s, 0.0, 0.4))
        if s == 1 and arma:
            codo = hom + V((0.9, 1.6, -3.6))
            mano = codo + V((0.2, 2.6, -1.6))
        else:
            codo = hom + V((0.6 * s, 0.4, -4.2))
            mano = codo + V((0.2 * s, 0.6, -4.0))
        _cono(add, hom, codo, 0.95, 0.8, 'piel' if s == -1 else 'tela', 0, 'brazo%d' % s)
        _cono(add, codo, mano, 0.8, 0.65, 'piel', 0, 'brazo%d' % s)
        _elip(add, mano, (0.8, 0.8, 0.8), 'piel', 0, 'mano%d' % s)
        if s == 1 and arma:
            hoja_dir = V((0.15, 0.55, -0.82)); hoja_dir /= np.linalg.norm(hoja_dir)
            _cono(add, mano - hoja_dir * 1.0, mano + hoja_dir * 0.4, 0.38, 0.38, 'cuero', 0, 'puno')
            _cono(add, mano + hoja_dir * 0.5 + V((-1.1, 0, 0)), mano + hoja_dir * 0.5 + V((1.1, 0, 0)), 0.3, 0.3, 'oxido', 0, 'guarda')
            punta = mano + hoja_dir * 9.0
            add(lambda P, a=mano + hoja_dir * 0.7, b=punta: sd_caja(P, (a + b) / 2, _ejes_tira(a, b, lado=V((1.0, 0, 0))),
                                                                  (0.55, 0.14, np.linalg.norm(b - a) / 2), 0.08),
                'hierro', 0, 'hoja')
            for u in (0.3, 0.55, 0.8):
                _elip(add, mano + hoja_dir * (0.7 + 8.3 * u) + V((0.25 * (u - 0.5), 0, 0)), (0.45, 0.2, 0.5), 'oxido', 0, 'roña')
    return pecho, cuello, cab


def _ejes_tira(a, b, lado=None):
    """Ejes de una caja que va de 'a' a 'b' (el tercero a lo largo), ancha de lado."""
    l = (b - a) / max(np.linalg.norm(b - a), 1e-6)
    x = lado if lado is not None else V((1.0, 0.0, 0.0))
    x = x - l * float(x @ l); x /= max(np.linalg.norm(x), 1e-6)
    y = np.cross(l, x)
    return [x, y, l]


def _tallo(add, pie, mid, fin, r0, r1, nombre, punta=1.0):
    """Un tallo del hongo naranja que sale del cuerpo, con la cabezuela ENCENDIDA en la punta."""
    _curva(add, _bez(pie, mid, fin, 5), r0, r1, 'hongo', 0, nombre)
    f = V(fin, dtype=float)
    d = f - V(mid, dtype=float); d /= np.linalg.norm(d)
    _cono(add, f - d * 0.3, f + d * 1.6 * punta, r1 * 1.5, r1 * 1.1, 'luz', 0, nombre + 'p')


def _micelio(add, puntos):
    """Fieltro blanco del micelio que cubre el cuerpo a parches."""
    for i, (c, r) in enumerate(puntos):
        _elip(add, c, (r, r * 0.8, r * 0.6), 'micelio', 0, 'mic%d' % i)


def cordyceps_en_pie():
    """A EN PIE: el muerto casi erguido, la cabeza colgando de lado; tallos que salen de la espalda y los hombros como
    una corona de cuernos, y tres por el yelmo. Espada oxidada en la mano."""
    e = _escena(); add = e.add
    pecho, cuello, cab = _cadaver(add, 0.15, True, True, 0.45)
    for i, (dx, dz, sx, alto) in enumerate(((-2.0, 0.4, -1, 8.5), (-0.6, 0.9, -0.3, 10.5), (0.9, 0.8, 0.4, 9.5),
                                           (2.2, 0.3, 1, 7.5))):
        pie = pecho + V((dx, -1.8, dz))
        fin = pie + V((sx * 3.0, -2.6, alto))
        _tallo(add, pie, pie + V((sx * 0.6, -2.4, alto * 0.45)), fin, 0.55, 0.32, 'esp%d' % i)
    for i, (dx, dy, alto) in enumerate(((-0.8, 0.2, 4.5), (0.6, -0.4, 5.5), (1.4, 0.6, 3.6))):
        pie = cab + V((dx, dy, 1.5))
        _tallo(add, pie, pie + V((dx * 0.6, 0.2, alto * 0.5)), pie + V((dx * 1.4, 0.6, alto)), 0.38, 0.24, 'yel%d' % i)
    for s in (-1, 1):
        pie = pecho + V((3.1 * s, -0.4, 1.6))
        _tallo(add, pie, pie + V((1.4 * s, -0.6, 2.4)), pie + V((2.6 * s, -1.0, 5.0)), 0.42, 0.26, 'hom%d' % s)
    _micelio(add, [(pecho + V((-1.8, 1.6, -1.4)), 1.3), (pecho + V((1.4, 1.8, -3.4)), 1.0), (V((1.6, 1.3, 7.0)), 0.9),
                   (V((-1.7, 1.2, 4.2)), 0.8), (pecho + V((-3.2, 0.2, -2.6)), 0.8)])
    return e.L


def cordyceps_encorvado():
    """B ENCORVADO: doblado hacia delante como si lo arrastraran por la nuca; de la ESPALDA le sale UN TALLO ENORME
    (el estroma del cordyceps de verdad), mas alto que el, que se curva por encima y acaba en una maza ENCENDIDA. Otros
    tallos pequeños por la columna."""
    e = _escena(); add = e.add
    pecho, cuello, cab = _cadaver(add, 0.85, True, True, 0.2)
    pie = pecho + V((0.0, -2.2, 0.4))
    top = pie + V((0.6, 3.5, 15.0))
    _curva(add, _bez(pie, pie + V((0.4, -4.5, 10.0)), top, 8), 1.4, 0.7, 'hongo', 0, 'estroma')
    d = V((0.1, 0.6, 0.1)); d /= np.linalg.norm(d)
    _cono(add, top - d * 0.5, top + d * 4.0, 1.25, 1.0, 'luz', 0, 'maza')
    for k in range(6):
        a = k / 6 * 2 * math.pi
        _elip(add, top + d * 1.8 + V((math.cos(a) * 1.1, 0, math.sin(a) * 1.1)), (0.45, 0.45, 0.45), 'luz2' if 'luz2' in MAT_CORD else 'luz', 0, 'bulto%d' % k)
    for i in range(4):
        p = pecho + V((0.0, -2.0, 0.0)) + (V((0, 0, 11.5)) - pecho) * (0.25 + 0.2 * i) + V((0, -0.4, 0))
        s = -1 if i % 2 else 1
        _tallo(add, p, p + V((s * 1.0, -1.4, 1.8)), p + V((s * 2.0, -2.2, 3.8 - 0.4 * i)), 0.38, 0.22, 'col%d' % i)
    _tallo(add, cab + V((0.4, 0, 1.4)), cab + V((0.8, 0.8, 3.0)), cab + V((1.0, 1.8, 4.6)), 0.34, 0.2, 'yel')
    _micelio(add, [(pecho + V((-1.2, 1.4, -1.0)), 1.2), (V((1.7, 1.6, 6.5)), 0.9), (pecho + V((2.6, -0.8, 0.2)), 1.0),
                   (pecho + V((-2.0, -1.6, -2.0)), 1.1)])
    return e.L


def cordyceps_sin_cabeza():
    """C SIN CABEZA: el hongo le ha REVENTADO la cabeza y en su lugar crece un sombrero de LUMINOSO (la campana de la
    1a, que se ve que viene de alli) con filamentos; el yelmo vacio le cuelga del cinto. Tallos por los hombros."""
    e = _escena(); add = e.add
    pecho, cuello, cab = _cadaver(add, 0.3, False, True)
    _cono(add, cuello - V((0, 0, 0.6)), cuello + V((0, 0.4, 1.8)), 1.3, 1.0, 'hongo', 0, 'cuello')
    c0 = cuello + V((0, 0.6, 4.2))
    lad = rx(0.25)

    def campana(P):
        q = (P - c0) @ lad
        cap = sd_elipsoide(q, V((0, 0, 0.0)), V((4.8, 4.8, 3.8)))
        return np.maximum(cap, -(q[:, 2] + 0.9 - 0.04 * (q[:, 0] ** 2 + q[:, 1] ** 2)))
    add(campana, 'campana', 0, 'campana')
    for k in range(12):
        a = k / 12 * 2 * math.pi
        _cono(add, c0 + lad.T @ V((math.cos(a) * 0.8, math.sin(a) * 0.8, 0.3)),
              c0 + lad.T @ V((math.cos(a) * 3.9, math.sin(a) * 3.9, -0.4)), 0.24, 0.2, 'luz', 0, 'lam')
    _elip(add, c0 + V((0, 0, 1.0)), (1.5, 1.5, 1.3), 'luz', 0, 'nucleo')
    for k in range(8):
        a = k / 8 * 2 * math.pi + 0.2
        borde = c0 + lad.T @ V((math.cos(a) * 4.4, math.sin(a) * 4.4, -0.8))
        largo = 4.5 + 1.5 * math.sin(3 * a)
        _curva(add, _bez(borde, borde + V((math.cos(a) * 0.6, math.sin(a) * 0.6, -largo * 0.5)),
                         borde + V((0.3 * math.sin(4 * a), 0, -largo)), 3), 0.26, 0.12, 'luz', 0, 'fil%d' % k)
    for s in (-1, 1):
        for j, alto in enumerate((5.5, 3.8)):
            pie = pecho + V((2.8 * s, -0.6 - 0.8 * j, 1.2))
            _tallo(add, pie, pie + V((1.2 * s, -1.0, alto * 0.5)), pie + V((2.2 * s, -1.6 - j, alto)), 0.42, 0.26, 'hom%d%d' % (s, j))
    # el yelmo vacio colgando del cinto, a un lado
    y0 = V((-2.9, 0.8, 10.4))
    _cono(add, V((-2.4, 0.6, 12.2)), y0 + V((0, 0, 1.2)), 0.16, 0.16, 'cuero', 0, 'correa')
    _elip(add, y0, (1.5, 1.6, 1.3), 'hierro', 0, 'yelmo_colgado')
    _elip(add, y0 + V((0.5, 0.9, 0.4)), (0.6, 0.5, 0.4), 'oxido', 0, 'abollon')
    _micelio(add, [(pecho + V((-1.6, 1.6, -1.6)), 1.2), (pecho + V((1.5, 1.6, -3.0)), 1.0), (V((1.5, 1.3, 7.2)), 0.9),
                   (cuello + V((0, -0.6, 0.0)), 1.1)])
    return e.L


# ------------------------------------------------------------
#  LAMINA
# ------------------------------------------------------------
def _normal():
    """El micónido de hoy, pegado en el mismo lienzo con los pies en el mismo sitio."""
    out = []
    for d in range(5):
        im0 = render(base.MODELO, base.escena(base.POSE()), d)
        im = Image.new('RGBA', LIENZO, (0, 0, 0, 0))
        im.paste(im0, (int(PIES[0] - base.MODELO.OX), int(PIES[1] - base.MODELO.OY)), im0)
        out.append(im)
    return out


if __name__ == '__main__':
    getattr(sdf_comun, '_prioridad_baja', lambda: None)()
    filtro = sys.argv[1].lower() if len(sys.argv) > 1 else ''
    filas = [
        ('NORMAL (hoy)', None, None),
        ('1a LUMINOSO A\nmedusa', luminoso_medusa, M_LUZ),
        ('1a LUMINOSO B\nfarol', luminoso_farol, M_LUZ),
        ('1a LUMINOSO C\nracimo', luminoso_racimo, M_LUZ),
        ('2a CORDYCEPS A\nen pie', cordyceps_en_pie, M_CORD),
        ('2a CORDYCEPS B\nencorvado (estroma)', cordyceps_encorvado, M_CORD),
        ('2a CORDYCEPS C\nsin cabeza (campana)', cordyceps_sin_cabeza, M_CORD),
    ]
    if filtro:
        filas = [f for f in filas if filtro in f[0].lower() or f[1] is None]
    ESCALA = 3
    MARGEN = 200
    tiras = []
    for nombre, fn, mo in filas:
        if fn is None:
            fotos = _normal()
        else:
            L = fn()
            fotos = [render(mo, L, d) for d in range(5)]
        cajas = [f.getbbox() for f in fotos if f.getbbox()]
        tiras.append((nombre, fotos, max(0, min(c[1] for c in cajas) - 3), min(LIENZO[1], max(c[3] for c in cajas) + 3)))
        print(nombre.replace('\n', ' '), [c for c in cajas][0], flush=True)
    x0 = max(0, min(f.getbbox()[0] for t in tiras for f in t[1] if f.getbbox()) - 3)
    x1 = min(LIENZO[0], max(f.getbbox()[2] for t in tiras for f in t[1] if f.getbbox()) + 3)
    ancho = x1 - x0
    hoja = Image.new('RGB', (MARGEN + ancho * 5 * ESCALA, sum((t[3] - t[2]) * ESCALA for t in tiras)), (18, 20, 26))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, fotos, y0, y1 in tiras:
        dib.text((10, y + (y1 - y0) * ESCALA // 2), nombre, fill=(235, 235, 235))
        for d, im in enumerate(fotos):
            c = im.crop((x0, y0, x1, y1)).resize((ancho * ESCALA, (y1 - y0) * ESCALA), Image.NEAREST)
            hoja.paste(c, (MARGEN + d * ancho * ESCALA, y), c)
        y += (y1 - y0) * ESCALA
    os.makedirs('tools/salida/sdf', exist_ok=True)
    hoja.save('tools/salida/sdf/miconido_mutantes_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    hoja.save(os.path.join(esc, 'miconido_mutantes_versiones.png'))
    print('ok', hoja.size)
