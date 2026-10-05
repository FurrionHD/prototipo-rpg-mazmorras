# ============================================================
#  bestia_acorazada_sdf.py -- la BESTIA ACORAZADA en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del
#  viejo (bestia_acorazada_sprites.gd): UN ANIMAL, NO UN CONSTRUCTO (suelta cuero, carne y nucleo de bestia). La
#  contraria del acechador: BAJA y ANCHISIMA, casi tan ancha como larga, un ariete con patas COLUMNARES y cortas; lomo
#  casi horizontal; la cabeza ANCHA y CHATA a ras de suelo con el TESTUZ (la placa con la que embiste) y dos puas
#  romas por fuera; ojos pequeños y hundidos. Encima, la CORAZA en BANDAS transversales de la nuca a la grupa, OSCURA
#  y mate (cuerno curtido, no metal), y debajo la CARNE calida a la vista: se lee primero la silueta blindada y
#  despues el bicho de dentro. Cola: un muñon acorazado.
#  Lienzo y origen de su horneado (1,95 -> 92 x 92, el centro).
#  Uso: python tools/sprites_sdf/bestia_acorazada_sdf.py vistas  -> tools/salida/sdf/bestia_acorazada_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/bestia_acorazada_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Pardo rojizo (804d40) la carne; la coraza pardo OSCURO con un punto de frio (gris del todo seria piedra).
MAT = {
    'carne':  [(0.40, 0.18, 0.12), (0.55, 0.27, 0.18), (0.68, 0.37, 0.26)],
    'coraza': [(0.17, 0.12, 0.11), (0.27, 0.20, 0.18), (0.38, 0.29, 0.26)],
    'junta':  [(0.09, 0.06, 0.05)] * 3,
    'una':    [(0.14, 0.11, 0.10), (0.22, 0.18, 0.16), (0.30, 0.25, 0.22)],
    'ojo':    [(0.98, 0.80, 0.22)] * 3,
}
MODELO = Modelo(1.95, (92, 92), (46, 46), MAT, (0.08, 0.05, 0.04), suaves=('cuerpo', 'cabeza'), brillan=('ojo',),
                corta_suelo=True)

CABEZA = V((0.0, 12.8, 5.6))
# EL CAPARAZON: una cupula algo mayor que el tronco, cortada por abajo en un faldon que vuela sobre los costados.
CAPA_C = V((0.0, -0.6, 7.4))
CAPA_R = V((9.0, 10.8, 6.0))
CAPA_FALDON = 5.8        # z del borde de abajo
BANDAS = 7
BANDA_Y0, BANDA_Y1 = 9.2, -11.0
BANDA_HUECO = 0.55


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, cabeza=0.0, fuelle=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], -p['agacha'] * 1.6)))
    X['raiz'] = raiz
    X['cabeza'] = comp(raiz, sobre(V((0.0, 9.0, 6.4)), rx(-p['cabeza'] * 0.1)))
    return X


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _banda(P, y0, y1, crece):
    """Una banda de la coraza: la cupula (algo mas gorda por detras, que monta sobre la siguiente) cortada entre y0 e
    y1 y por debajo del faldon."""
    d = sd_elipsoide(P, CAPA_C, CAPA_R + crece)
    corte = np.maximum(P[:, 1] - y0, y1 - P[:, 1])
    return np.maximum(np.maximum(d, corte), CAPA_FALDON - P[:, 2])


def escena(pose):
    p = pose
    e = Escena(huesos(p)); add = e.add
    f = 1.0 + 0.04 * p['fuelle']
    # --- EL CUERPO: bajo y anchisimo, poco hueco debajo (lo que dice "pesa").
    _elip(add, (0.0, 0.0, 6.6), (7.8 * f, 9.6, 4.8 * f), 'carne', 0)
    _elip(add, (0.0, 6.4, 6.4), (7.0, 5.0, 4.4), 'carne', 2.5)
    _elip(add, (0.0, -7.4, 6.2), (6.8, 4.8, 4.2), 'carne', 2.5)
    # --- LA CORAZA en BANDAS: debajo, la cupula oscura de las JUNTAS; encima, cada banda, y cada una un pelin mas
    # gorda que la de delante (montan como las de un armadillo: el canto de cada una hace su raya).
    add(lambda P: np.maximum(sd_elipsoide(P, CAPA_C, CAPA_R - 0.5), CAPA_FALDON + 0.4 - P[:, 2]), 'junta', 0, 'coraza')
    paso = (BANDA_Y0 - BANDA_Y1) / BANDAS
    for i in range(BANDAS):
        y0 = BANDA_Y0 - paso * i
        y1 = y0 - paso + BANDA_HUECO
        crece = 0.18 * (i % 2)
        add(lambda P, y0=y0, y1=y1, c=crece: _banda(P, y0, y1, c), 'coraza', 0, 'coraza')
    # El ESCUDO DE LA NUCA: una placa propia sobre el cuello, delante de la primera banda.
    _elip(add, (0.0, 10.4, 8.6), (5.0, 2.4, 2.0), 'coraza', 0, 'nuca')
    # --- LA CABEZA: ancha, chata y a RAS DE SUELO, metida en los hombros.
    _elip(add, CABEZA, (4.6, 4.0, 3.2), 'carne', 0, 'cabeza', 'cabeza')
    _elip(add, CABEZA + V((0.0, 2.6, -1.6)), (3.6, 2.6, 2.0), 'carne', 1.2, 'cabeza', 'cabeza')
    # EL TESTUZ: la placa frontal, inclinada hacia atras, por delante y por encima del morro.
    add(lambda P: sd_caja(P, CABEZA + V((0.0, 3.4, 0.8)), [V((1.0, 0.0, 0.0)), V((0.0, 0.94, -0.34)),
                                                          V((0.0, 0.34, 0.94))], V((4.0, 1.0, 2.8)), 0.6),
        'coraza', 0, 'testuz', 'cabeza')
    for s in (-1, 1):
        # PUAS romas por FUERA del testuz: rompen la silueta.
        _cono(add, CABEZA + V((3.4 * s, 3.2, 1.6)), CABEZA + V((5.6 * s, 4.6, 2.6)), 1.15, 0.45, 'coraza', 0, 'testuz',
              'cabeza')
        # OJOS: pequeños, hundidos bajo el borde del testuz, en la CARA (no sobre la placa).
        _elip(add, CABEZA + V((3.5 * s, 2.0, 1.3)), (0.75, 0.75, 0.6), 'ojo', 0, 'ojo', 'cabeza')
        # Narinas: dos puntos oscuros en el morro, bajo la placa.
        _elip(add, CABEZA + V((1.1 * s, 5.0, -1.6)), (0.5, 0.4, 0.4), 'junta', 0, 'nariz', 'cabeza')
    # --- LAS PATAS: COLUMNARES y cortas (muslo y pie, sin caña), por fuera de la panza, con tres uñas romas.
    for s in (-1, 1):
        for y0 in (5.6, -6.6):
            g = 'pata_%d_%d' % (s, int(y0))
            _cono(add, (5.0 * s, y0, 6.0), (5.8 * s, y0 + 0.2, 1.4), 2.6, 2.3, 'carne', 1.0, g)
            _elip(add, (5.9 * s, y0 + 0.3, 0.9), (2.5, 2.6, 1.0), 'carne', 0.8, g)
            for j in (-1, 0, 1):
                c = V((5.9 * s + 1.0 * j, y0 + 2.2 - 0.3 * abs(j), 0.55))
                _elip(add, c, (0.55, 0.8, 0.55), 'una', 0, 'una')
    # --- LA COLA: un muñon acorazado con dos anillos.
    _cono(add, (0.0, -10.8, 6.6), (0.0, -13.4, 4.6), 1.9, 1.2, 'carne', 1.0)
    for i, (y, z, r) in enumerate(((-11.4, 6.3, 1.9), (-12.8, 5.2, 1.5))):
        _elip(add, (0.0, y, z + 0.3), (r * 1.05, 0.65, r * 1.0), 'coraza', 0, 'cola_%d' % i)
    return e.L


ANIMS = {}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'bestia_acorazada_804d40_1.95', VISTAS + 'bestia_acorazada_vs_viejo.png', 3))
    else:
        hornear('bestia_acorazada_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
