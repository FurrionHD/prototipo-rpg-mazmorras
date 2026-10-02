# ============================================================
#  golem_sdf.py -- el GOLEM DE ARCILLA en 3D (02/10/2026, PRUEBA al lado del viejo; ver la memoria enemigos-a-3d-prueba).
#  Con el motor del Minotauro (sdf_comun). De momento solo el cuerpo QUIETO.
#  Como el viejo: un bloque de barro con la cabeza hundida entre los hombros, brazos larguisimos hasta el suelo con
#  puños enormes (se apoya en ellos como un gorila), piernas cortas y gordas, ojos que brillan y GRIETAS con brasa.
#  Uso: python tools/sprites_sdf/golem_sdf.py vistas  -> tools/salida/sdf/golem_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sdf_comun import *

VISTAS = 'tools/salida/sdf/'
ESTIRA = 1.15

def Z(x, y, z):
    return np.array([x, y, z * ESTIRA], dtype=float)

MAT = {
    'barro':  [(0.42, 0.28, 0.16), (0.56, 0.39, 0.23), (0.68, 0.50, 0.32)],
    'oscuro': [(0.31, 0.20, 0.12), (0.41, 0.28, 0.17), (0.51, 0.36, 0.23)],
    'ojo':    [(1.00, 0.95, 0.70), (1.00, 0.95, 0.70), (1.00, 0.97, 0.80)],
    'brasa':  [(0.95, 0.45, 0.12), (0.95, 0.45, 0.12), (1.00, 0.62, 0.22)],
}
# El lienzo y los pies del generador viejo (162 x 176, pies a ~128).
MODELO = Modelo(2.8, (162, 176), (81, 128), MAT, (0.16, 0.10, 0.06), suaves=('cuerpo', 'cabeza', 'brazo_d', 'brazo_i', 'pierna_d', 'pierna_i'),
                brillan=('ojo', 'brasa'), estira=ESTIRA)


def huesos(pose):
    return {'raiz': IDENT}


def escena(pose):
    e = Escena(huesos(pose))
    add = e.add
    # EL TRONCO: un bloque de barro, mas ancho arriba (los hombros) que abajo, un poco echado hacia delante.
    add(lambda P: sd_elipsoide(P, Z(0, 0.6, 19.0), np.array([8.4, 6.0, 6.8 * ESTIRA])), 'barro', 0)
    add(lambda P: sd_elipsoide(P, Z(0, -0.2, 13.0), np.array([6.0, 4.8, 4.4 * ESTIRA])), 'barro', 2.0)
    # La CHEPA: el lomo sube por encima de la cabeza (va encorvado).
    add(lambda P: sd_elipsoide(P, Z(0, -2.4, 23.4), np.array([6.6, 4.6, 3.6 * ESTIRA])), 'barro', 2.5)
    # LA CABEZA: pequeña, hundida entre los hombros y adelantada.
    # Su propio grupo: la linea de dentro la separa del tronco (fundida, era todo un bulto).
    add(lambda P: sd_elipsoide(P, Z(0, 4.0, 25.4), np.array([3.4, 3.2, 3.0 * ESTIRA])), 'barro', 0, 'cabeza')
    add(lambda P: sd_elipsoide(P, Z(0, 6.2, 24.4), np.array([2.4, 1.4, 1.6 * ESTIRA])), 'barro', 1.0, 'cabeza')
    for s in (-1, 1):
        # El ojo que brilla, grande.
        add(lambda P, s=s: sd_esfera(P, Z(1.4 * s, 6.6, 26.0), 0.95), 'ojo', 0, 'ojo')
    # LAS GRIETAS CON BRASA en el pecho: tajos finos y quebrados (rellenos, sin raya), por fuera de la piel.
    for a, b in ((Z(2.2, 6.4, 21.0), Z(3.4, 6.2, 17.6)), (Z(3.4, 6.2, 17.6), Z(2.6, 6.0, 15.4)),
                 (Z(-3.0, 6.3, 19.4), Z(-2.0, 6.0, 16.2))):
        add(lambda P, a=a, b=b: sd_cono(P, a, b, 0.42, 0.32), 'brasa', 0, 'grieta')
    # LOS BRAZOS: larguisimos, hasta el suelo, con el puño enorme apoyado (como un gorila).
    for s, nom in ((-1, 'd'), (1, 'i')):
        g = 'brazo_' + nom
        hom = Z(9.0 * s, 0.6, 20.8); codo = Z(10.6 * s, 2.0, 11.6); mun = Z(10.4 * s, 3.4, 5.2)
        # El HOMBRO va con el brazo (no con el tronco): asi sale la linea entre los dos.
        add(lambda P, c=Z(8.6 * s, 0.4, 21.6): sd_elipsoide(P, c, np.array([4.0, 4.2, 3.8 * ESTIRA])), 'barro', 0, g)
        add(lambda P, a=hom, b=codo: sd_cono(P, a, b, 3.2, 2.6), 'barro', 1.6, g)
        add(lambda P, a=codo, b=mun: sd_cono(P, a, b, 2.8, 2.4), 'barro', 1.0, g)
        # El codo, un bulto de barro mas oscuro.
        add(lambda P, c=codo: sd_esfera(P, c, 2.6), 'oscuro', 0.8, g)
        # EL PUÑO: un pegote enorme apoyado en el suelo, con sus nudillos.
        add(lambda P, c=Z(10.6 * s, 4.0, 3.0): sd_elipsoide(P, c, np.array([3.6, 3.8, 3.0 * ESTIRA])), 'barro', 1.2, g)
        for k in (-1, 0, 1):
            add(lambda P, c=Z(10.6 * s + 1.3 * k, 6.8, 3.4): sd_esfera(P, c, 1.2), 'oscuro', 0.5, g)
    # LAS PIERNAS: cortas y gordas, separadas, y los pies como peanas.
    for s, nom in ((-1, 'd'), (1, 'i')):
        g = 'pierna_' + nom
        add(lambda P, a=Z(3.8 * s, -0.4, 9.6), b=Z(4.3 * s, -0.2, 2.4): sd_cono(P, a, b, 3.1, 2.8), 'barro', 0, g)
        add(lambda P, c=Z(4.4 * s, 0.6, 1.3): sd_elipsoide(P, c, np.array([3.3, 3.9, 1.5 * ESTIRA])), 'oscuro', 0.8, g)
    # PEGOTES de barro sueltos por el cuerpo (que se vea modelado a mano, no liso).
    for c, r in ((Z(-4.2, 4.6, 14.4), 1.8), (Z(5.0, -3.4, 20.0), 2.0), (Z(-6.0, -2.0, 17.0), 1.6), (Z(0.0, 5.4, 12.0), 1.5)):
        add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'barro', 0.8)
    return e.L


if __name__ == '__main__':
    if sys.argv[1:] == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        L = escena({})
        fotos = [render(MODELO, L, d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'golem_aa8055_2.80', VISTAS + 'golem_vs_viejo.png', 3))
