# ============================================================
#  arana_sdf.py -- la ARAÑA DE LAS SIMAS en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (arana_sprites.gd): la silueta son las OCHO PATAS, que salen a los lados y ARQUEAN POR ENCIMA DEL LOMO antes de bajar
#  al suelo; el cuerpo en dos piezas (el cefalotorax delante, bajo, y el abdomen detras, gordo y ALTO) con su cintura;
#  el racimo de ojos amarillos y los queliceros. Lienzo y origen de su horneado (1,50 -> 90 x 90, el centro).
#  Uso: python tools/sprites_sdf/arana_sdf.py vistas
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/arana_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Morado ceniza (635580): el cuerpo en tres tonos, las patas mas oscuras, el dibujo del abdomen mas claro.
MAT = {
    'cuerpo':  [(0.25, 0.20, 0.34), (0.39, 0.33, 0.50), (0.52, 0.46, 0.64)],
    'pata':    [(0.16, 0.13, 0.23), (0.25, 0.21, 0.35), (0.34, 0.29, 0.46)],
    'dibujo':  [(0.52, 0.44, 0.68), (0.64, 0.56, 0.80), (0.76, 0.70, 0.90)],
    'ojo':     [(1.0, 0.85, 0.25)] * 3,
    'colmillo': [(0.80, 0.76, 0.62), (0.93, 0.90, 0.78), (0.99, 0.97, 0.88)],
}
# A 1,5 salia la mitad de grande que la vieja (aquella exageraba el tamaño): se pinta a 2,2 en el mismo lienzo.
MODELO = Modelo(2.2, (90, 90), (45, 45), MAT, (0.09, 0.07, 0.12), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True)


def POSE(**k):
    p = dict(agacha=0.0, avance=0.0, patas=0.0, encoge=0.0)
    p.update(k)
    return p


def huesos(p):
    return {'raiz': (np.eye(3), V((0.0, p['avance'], -p['agacha'])))}


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena(pose):
    e = Escena(huesos(pose)); add = e.add
    # EL CUERPO EN DOS PIEZAS, con la cintura (el pediculo) entre medias.
    _elip(add, (0, 2.6, 3.4), (3.0, 3.2, 2.1), 'cuerpo')
    _cono(add, (0, 0.2, 3.6), (0, -1.0, 3.9), 0.9, 1.0, 'cuerpo', 0.6)
    _elip(add, (0, -5.0, 5.4), (4.4, 5.4, 4.0), 'cuerpo', 0.8)
    # EL DIBUJO del lomo del abdomen: unos galones claros, un pelo por fuera.
    for k, (y, ancho) in enumerate(((-2.6, 2.2), (-4.4, 2.8), (-6.4, 2.4), (-8.0, 1.5))):
        _elip(add, (0, y, 5.4 + math.sqrt(max(0.0, 1 - ((y + 5.0) / 5.4) ** 2)) * 4.0 - 0.15), (ancho, 0.55, 0.35), 'dibujo', 0,
              'dibujo')
    # LOS OJOS: dos grandes delante y cuatro pequeños alrededor, amarillos, en la frente.
    for s in (-1, 1):
        _elip(add, (0.9 * s, 5.2, 4.6), (0.6, 0.45, 0.55), 'ojo', 0, 'ojo')
        _elip(add, (1.9 * s, 4.6, 4.9), (0.35, 0.3, 0.35), 'ojo', 0, 'ojo')
        _elip(add, (0.5 * s, 4.6, 5.3), (0.3, 0.28, 0.3), 'ojo', 0, 'ojo')
    # LOS QUELICEROS: dos colmillos cortos que bajan por delante.
    for s in (-1, 1):
        _cono(add, (0.7 * s, 5.5, 3.1), (0.6 * s, 6.6, 1.6), 0.7, 0.25, 'colmillo', 0, 'colmillo')
        # los pedipalpos, cortos, a los lados de la boca
        _cono(add, (1.6 * s, 5.0, 2.8), (2.6 * s, 7.0, 1.0), 0.45, 0.3, 'pata', 0, 'palpo')
    # LAS OCHO PATAS: de la coxa suben a la RODILLA, por encima del lomo, y bajan en tijera al suelo. Abiertas en
    # abanico: las de delante hacia delante, las de atras hacia atras.
    for s in (-1, 1):
        for k, (y0, ang) in enumerate(((3.8, 0.55), (3.0, 0.15), (2.1, -0.25), (1.3, -0.65))):
            base = V((2.4 * s, y0, 3.2))
            d = V((math.cos(ang) * s, math.sin(ang), 0.0))
            rodilla = base + d * 5.5 + V((0, 0, 5.4))
            tobillo = base + d * 10.0 + V((0, 0, 1.6))
            pie = base + d * 11.6 + V((0, 0, -3.0))
            _cono(add, base, rodilla, 1.0, 0.8, 'pata', 0, 'pata%d%d' % (s, k))
            _cono(add, rodilla, tobillo, 0.8, 0.6, 'pata', 0, 'pata%d%d' % (s, k))
            _cono(add, tobillo, pie, 0.6, 0.35, 'pata', 0, 'pata%d%d' % (s, k))
            _elip(add, rodilla, (0.95, 0.95, 0.95), 'pata', 0, 'pata%d%d' % (s, k))
    return e.L


if __name__ == '__main__':
    if sys.argv[1:] == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'arana_635580_1.50', VISTAS + 'arana_vs_viejo.png', 4))
