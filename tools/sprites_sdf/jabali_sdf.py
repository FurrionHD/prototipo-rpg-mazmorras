# ============================================================
#  jabali_sdf.py -- el JABALI en 3D (02/10/2026, PRUEBA: ponerlo al lado del viejo y ver cuanto gana; ver la memoria
#  enemigos-a-3d-prueba). Con el motor del Minotauro (sdf_comun). De momento solo el cuerpo QUIETO.
#  Uso: python tools/sprites_sdf/jabali_sdf.py vistas  -> tools/salida/sdf/jabali_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from sdf_comun import *

VISTAS = 'tools/salida/sdf/'
ESTIRA = 1.08

def Z(x, y, z):
    return np.array([x, y, z * ESTIRA], dtype=float)

MAT = {
    'piel':   [(0.36, 0.24, 0.18), (0.50, 0.34, 0.24), (0.62, 0.44, 0.31)],
    'crin':   [(0.17, 0.11, 0.08), (0.25, 0.17, 0.12), (0.33, 0.23, 0.17)],
    'morro':  [(0.56, 0.38, 0.34), (0.72, 0.52, 0.46), (0.84, 0.64, 0.57)],
    'marfil': [(0.78, 0.74, 0.60), (0.93, 0.90, 0.78), (0.99, 0.97, 0.88)],
    'pezuna': [(0.10, 0.08, 0.08), (0.17, 0.14, 0.13), (0.25, 0.21, 0.19)],
    'ojo':    [(0.95, 0.92, 0.84), (0.95, 0.92, 0.84), (0.98, 0.96, 0.90)],
    'pupila': [(0.06, 0.03, 0.02), (0.06, 0.03, 0.02), (0.06, 0.03, 0.02)],
}
# El lienzo y los pies del generador viejo (88 x 88, pies a ~49): el juego lo coloca igual.
MODELO = Modelo(1.7, (88, 88), (44, 49), MAT, (0.11, 0.07, 0.05), suaves=('cuerpo',), brillan=('ojo', 'pupila'),
                estira=ESTIRA)


def huesos(pose):
    return {'raiz': IDENT}


def escena(pose):
    e = Escena(huesos(pose))
    add = e.add
    # EL CUERPO: barril, con la CRUZ alta y gorda (el jabali carga el peso delante) y el anca mas baja.
    # GORDO (la 1a vuelta salia flaco al lado del viejo): un barril ancho y bajo.
    add(lambda P: sd_elipsoide(P, Z(0, -1.0, 7.8), np.array([6.4, 9.6, 5.2 * ESTIRA])), 'piel', 0)
    add(lambda P: sd_elipsoide(P, Z(0, 4.4, 9.4), np.array([6.8, 5.8, 6.0 * ESTIRA])), 'piel', 2.5)
    add(lambda P: sd_elipsoide(P, Z(0, -7.6, 7.4), np.array([5.8, 4.8, 4.8 * ESTIRA])), 'piel', 2.5)
    # Papada/pecho que cae entre las patas de delante.
    add(lambda P: sd_elipsoide(P, Z(0, 7.0, 5.8), np.array([4.6, 3.6, 3.4 * ESTIRA])), 'piel', 2.0)
    # LA CABEZA: una cuña grande que baja hacia el morro, metida en los hombros (sin cuello).
    add(lambda P: sd_cono(P, Z(0, 8.8, 8.6), Z(0, 14.8, 5.0), 5.0, 2.6), 'piel', 2.0)
    add(lambda P: sd_elipsoide(P, Z(0, 16.3, 4.7), np.array([2.7, 1.1, 2.1 * ESTIRA])), 'morro', 0, 'morro')
    for s in (-1, 1):
        # Las orejas: puntiagudas, hacia arriba y atras.
        add(lambda P, s=s: sd_cono(P, Z(3.0 * s, 9.8, 11.2), Z(4.2 * s, 8.4, 14.2), 1.5, 0.3), 'piel', 0.4)
        # LOS OJOS: blancos con la pupila negra, ASOMANDO de la cuña (a 2,9 quedaban dentro de la cabeza y no se veian).
        add(lambda P, s=s: sd_esfera(P, Z(3.35 * s, 11.8, 8.9), 0.85), 'ojo', 0, 'ojo')
        add(lambda P, s=s: sd_esfera(P, Z(3.75 * s, 12.3, 9.0), 0.55), 'pupila', 0, 'ojo')
        # LOS COLMILLOS: GORDOS, salen de los lados del morro y se curvan hacia arriba y atras.
        p = Z(2.4 * s, 15.0, 4.0); d = np.array([0.55 * s, 0.4, 0.75]); r = 1.25
        for k in range(5):
            dd = d / np.linalg.norm(d); q = p + dd * 1.35
            add(lambda P, a=p, b=q, ra=r, rb=max(0.2, r - 0.16): sd_cono(P, a, b, ra, rb), 'marfil', 0, 'colmillo')
            p = q; r = max(0.22, r - 0.21); d = d + np.array([0.05 * s, -0.28, 0.0])
    # LA CRIN: mechones oscuros y tiesos por el espinazo, de la nuca a media espalda (los mas altos en la cruz).
    # Puntas finas que SOBRESALEN del perfil (la franja pegada al lomo se leia como una mancha), en dos filas al tresbolillo.
    for i in range(14):
        u = i / 13.0
        y = 10.0 - u * 17.0
        alto = 15.2 - 2.6 * abs(u - 0.3) * 2.0
        x = 0.7 if i % 2 else -0.7
        base = Z(x, y, alto - 0.8)
        punta = Z(x * 1.4, y - 2.6, alto + 3.6 - 0.9 * (i % 3))
        add(lambda P, a=base, b=punta: sd_cono(P, a, b, 1.1, 0.2), 'crin', 0, 'crin')
    # LAS PATAS: cortas y gordas, con su pezuña.
    for s in (-1, 1):
        for y0, gord in ((5.6, 2.3), (-7.6, 2.2)):
            add(lambda P, a=Z(3.8 * s, y0, 6.0), b=Z(3.8 * s, y0 + 0.3, 1.4), g=gord: sd_cono(P, a, b, g, g * 0.65), 'piel', 1.4)
            add(lambda P, c=Z(3.8 * s, y0 + 0.5, 0.7): sd_elipsoide(P, c, np.array([1.5, 1.7, 0.8 * ESTIRA])), 'pezuna', 0, 'pezuna')
    # LA COLA: corta, con su borla oscura.
    add(lambda P: sd_cono(P, Z(0, -11.6, 8.4), Z(0, -12.8, 6.2), 0.5, 0.35), 'crin', 0, 'cola')
    add(lambda P: sd_elipsoide(P, Z(0, -13.0, 5.6), np.array([0.6, 0.6, 0.9 * ESTIRA])), 'crin', 0, 'cola')
    return e.L


if __name__ == '__main__':
    if sys.argv[1:] == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        L = escena({})
        fotos = [render(MODELO, L, d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'jabali_806255_1.70', VISTAS + 'jabali_vs_viejo.png', 5))
