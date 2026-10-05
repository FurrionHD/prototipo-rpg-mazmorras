# ============================================================
#  escarabajo_sdf.py -- el ESCARABAJO DE HIERRO en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del
#  viejo (escarabajo_sprites.gd): LO CONTRARIO DE LA ARAÑA, un DOMO BAJO Y ANCHO (los elitros, con su raja) con la placa
#  del cuello (pronoto), la cabeza y la PALA plana delante -- empuja, no pincha --, y seis patas cortas que casi no se
#  ven. Lo de "hierro" es el BRILLO: un reflejo duro y claro sobre el lomo (el especular del motor). Lienzo y origen de
#  su horneado (1,50 -> 80 x 80, el centro).
#  Uso: python tools/sprites_sdf/escarabajo_sdf.py vistas
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/escarabajo_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Verde oliva (5c8055); el caparazon con su cuarto tono, el reflejo de metal.
MAT = {
    'caparazon': [(0.22, 0.31, 0.20), (0.36, 0.50, 0.33), (0.48, 0.63, 0.44), (0.86, 0.94, 0.82)],
    'oscuro':    [(0.12, 0.17, 0.11), (0.18, 0.25, 0.16), (0.26, 0.34, 0.22)],
    'pata':      [(0.14, 0.19, 0.12), (0.22, 0.29, 0.18), (0.30, 0.38, 0.25)],
    'ojo':       [(1.0, 0.80, 0.30)] * 3,
}
# Algo mayor que su escala (1,5): el viejo exageraba el tamaño, como el de la araña.
MODELO = Modelo(2.1, (80, 80), (40, 40), MAT, (0.06, 0.09, 0.05), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True,
                especular=('caparazon',), umbral_especular=0.975)


def POSE(**k):
    p = dict(agacha=0.0, avance=0.0, patas=0.0)
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
    # LOS ELITROS: el domo, ANCHO y BAJO, y la RAJA del medio (dos mitades que casi se tocan: la linea oscura).
    for s in (-1, 1):
        _elip(add, (2.75 * s, -1.4, 3.3), (3.3, 6.0, 3.3), 'caparazon', 0, 'elitro%d' % s)
    _elip(add, (0, -1.4, 2.2), (5.8, 5.8, 2.1), 'oscuro', 0, 'vientre')
    # EL PRONOTO: la placa del cuello, mas estrecha, y LA CABEZA.
    _elip(add, (0, 4.6, 3.0), (3.8, 2.6, 2.5), 'caparazon', 0, 'pronoto')
    _elip(add, (0, 7.0, 2.2), (2.3, 1.8, 1.6), 'oscuro', 0, 'cabeza')
    # LA PALA: plana y ancha, por delante de la cabeza, algo levantada.
    add(lambda P: sd_caja(P, V((0, 8.8, 1.8)), [V((1, 0, 0)), V((0, 0.94, 0.34)), V((0, -0.34, 0.94))], (3.2, 1.4, 0.35), 0.3),
        'caparazon', 0, 'pala')
    for s in (-1, 1):
        _elip(add, (1.5 * s, 7.9, 2.7), (0.45, 0.4, 0.4), 'ojo', 0, 'ojo')
        # las antenas, cortas y acodadas
        _cono(add, (1.6 * s, 7.6, 2.4), (3.0 * s, 8.6, 3.4), 0.3, 0.25, 'pata', 0, 'antena')
        _cono(add, (3.0 * s, 8.6, 3.4), (3.6 * s, 9.8, 3.6), 0.25, 0.4, 'pata', 0, 'antena')
    # LAS SEIS PATAS: cortas, en dos tramos, que asoman por debajo del borde del caparazon.
    for s in (-1, 1):
        for k, (y0, ang) in enumerate(((3.6, 0.6), (0.4, 0.0), (-3.2, -0.6))):
            base = V((4.6 * s, y0, 1.6))
            d = V((math.cos(ang) * s, math.sin(ang), 0.0))
            rod = base + d * 2.6 + V((0, 0, 0.9))
            pie = base + d * 4.6 + V((0, 0, -1.4))
            _cono(add, base, rod, 0.6, 0.5, 'pata', 0, 'pata%d%d' % (s, k))
            _cono(add, rod, pie, 0.5, 0.3, 'pata', 0, 'pata%d%d' % (s, k))
    return e.L


if __name__ == '__main__':
    if sys.argv[1:] == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'escarabajo_5c8055_1.50', VISTAS + 'escarabajo_vs_viejo.png', 4))
