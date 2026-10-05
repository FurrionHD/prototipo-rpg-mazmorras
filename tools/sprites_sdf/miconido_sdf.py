# ============================================================
#  miconido_sdf.py -- el MICONIDO en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (miconido_sprites.gd): UNA SETA CON CUERPO DE HOMBRE -- un torso gordo y PALIDO, un SOMBRERO oscuro y muy ancho cuya
#  ala cae por los lados, dos brazos finos y unas patas cortas. NO TIENE CARA: se sabe hacia donde va porque el SOMBRERO
#  VA LADEADO hacia donde mira y las LAMINAS (rayas oscuras bajo el ala) solo se ven por delante. Lienzo y origen de su
#  horneado (2,00 -> 90 x 106, el origen bajo).
#  Uso: python tools/sprites_sdf/miconido_sdf.py vistas
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/miconido_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# El sombrero, del color de su ficha (806e40, ocre); el cuerpo palido; las laminas oscuras.
MAT = {
    'sombrero': [(0.32, 0.27, 0.16), (0.50, 0.43, 0.25), (0.64, 0.57, 0.36)],
    'carne':    [(0.66, 0.64, 0.58), (0.82, 0.80, 0.74), (0.92, 0.90, 0.85)],
    'lamina':   [(0.24, 0.20, 0.14), (0.34, 0.29, 0.20), (0.42, 0.36, 0.26)],
    'mota':     [(0.70, 0.64, 0.46), (0.80, 0.74, 0.55), (0.88, 0.82, 0.64)],
}
LIENZO = (90, 106)
PIES = (45.0, 106 * 1.55 / 2.75)
MODELO = Modelo(2.0, LIENZO, PIES, MAT, (0.12, 0.10, 0.07), suaves=('cuerpo',), brillan=(), corta_suelo=True)

LADEO = 0.22     # cuanto cae el sombrero hacia delante (su "cara")


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, ladeo=0.0, brazos=0.0, paso=0.0)
    p.update(k)
    return p


def huesos(p):
    raiz = (np.eye(3), V((0.0, p['avance'], -p['agacha'])))
    X = {'raiz': raiz}
    X['sombrero'] = comp(raiz, sobre(V((0, 0, 16.5)), rx(LADEO + p['ladeo'])))
    for s, ld in ((-1, 'd'), (1, 'i')):
        X['brazo_' + ld] = comp(raiz, sobre(V((4.6 * s, 0.4, 12.5)), rx(-p['brazos'] * s * 0.4)))
        X['pierna_' + ld] = comp(raiz, sobre(V((2.2 * s, 0.0, 3.6)), rx(p['paso'] * s * 0.4)))
    return X


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena(pose):
    e = Escena(huesos(pose)); add = e.add
    # EL CUERPO: un tronco de seta gordo y palido, ancho abajo, casi tan ancho como alto.
    _elip(add, (0, 0, 9.5), (5.0, 4.6, 7.2), 'carne')
    _elip(add, (0, 0, 4.6), (4.6, 4.2, 3.0), 'carne', 2.0)
    # EL SOMBRERO: ancho y oscuro, con el ala que CAE por los lados; por debajo, plano, con las LAMINAS (rayas oscuras
    # en abanico) que solo asoman por delante porque el sombrero va ladeado hacia alli.
    def sombrero(P):
        cap = sd_elipsoide(P, V((0, 0, 18.0)), V((8.2, 8.2, 4.4)))
        return np.maximum(cap, -(P[:, 2] - 16.4 + 0.04 * ((P[:, 0] ** 2 + P[:, 1] ** 2))))   # la panza curvada del ala
    add(sombrero, 'sombrero', 0, 'sombrero', 'sombrero')
    # las motas claras de encima
    for (x, y, r) in ((-4.0, 2.0, 1.3), (3.0, -3.5, 1.1), (1.5, 4.5, 0.9), (-2.0, -5.0, 1.0), (5.5, 1.0, 0.8)):
        x, y = x * 0.72, y * 0.72
        z = 18.0 + 4.4 * math.sqrt(max(0.0, 1 - (x * x + y * y) / 67.0)) - 0.25
        _elip(add, (x, y, z), (r, r, 0.35), 'mota', 0, 'mota', 'sombrero')
    for k in range(20):
        a = k / 20 * 2 * math.pi
        r0, r1 = 3.0, 7.6
        # LAS LAMINAS, y por delante CUELGAN del ala hasta los hombros (la mancha que dice hacia donde va).
        caen = 2.4 if math.sin(a) > 0.2 else 0.0
        _cono(add, (math.cos(a) * r0, math.sin(a) * r0, 16.6), (math.cos(a) * r1, math.sin(a) * r1, 16.4 - 0.04 * 58 + 0.5),
              0.34, 0.3, 'lamina', 0, 'lamina', 'sombrero')
        if caen > 0:
            _cono(add, (math.cos(a) * 5.2, math.sin(a) * 5.4, 16.2), (math.cos(a) * 5.0, math.sin(a) * 5.4 + 0.4, 16.0 - caen - 2.6),
                  0.55, 0.38, 'lamina', 0, 'lamina', 'sombrero')
    # LOS BRAZOS: finos, colgando, con una mano de dedos-raicilla.
    for s, ld in ((-1, 'd'), (1, 'i')):
        h = 'brazo_' + ld
        _cono(add, (4.6 * s, 0.4, 12.5), (5.8 * s, 1.2, 7.2), 0.9, 0.7, 'carne', 0.6, 'brazo%d' % s, h)
        _cono(add, (5.8 * s, 1.2, 7.2), (6.0 * s, 1.8, 4.6), 0.7, 0.55, 'carne', 0.4, 'brazo%d' % s, h)
        for k in (-1, 0, 1):
            _cono(add, (6.0 * s, 1.8, 4.6), (6.0 * s + 0.4 * k, 2.3, 3.4), 0.35, 0.2, 'carne', 0, 'brazo%d' % s, h)
    # LAS PATAS: cortas y gruesas, de pie.
    for s, ld in ((-1, 'd'), (1, 'i')):
        h = 'pierna_' + ld
        _cono(add, (2.2 * s, 0.0, 3.6), (2.3 * s, 0.4, 0.8), 1.7, 1.9, 'carne', 0.6, 'pierna%d' % s, h)
    return e.L


if __name__ == '__main__':
    if sys.argv[1:] == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'miconido_806e40_2.00', VISTAS + 'miconido_vs_viejo.png', 4))
