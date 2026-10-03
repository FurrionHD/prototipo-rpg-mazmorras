# ============================================================
#  trent_sdf.py -- el TRENT en 3D (03/10/2026), con el motor de los enemigos (sdf_comun). Las medidas, las del viejo
#  (trent_sprites.gd): un arbol andante ENCORVADO -- el tronco inclinado hacia delante y la copa colgando por delante
#  como una cabeza demasiado grande, con flecos de hojas --, dos piernas de tocon con raices, los brazos-rama que
#  cuelgan, cuatro ramas como cuernos saliendo de la copa, los ojos claros en la sombra de la fronda y la GRIETA de la
#  corteza por donde escupe la savia. El lienzo y el origen de su horneado (2,50 -> 306 x 216).
#  Uso: python tools/sprites_sdf/trent_sdf.py vistas  -> tools/salida/sdf/trent_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/trent_sdf/'
VISTAS = 'tools/salida/sdf/'

# Los tonos del viejo con su color de la prueba (598040): la madera sale del color (oscura y parda), la fronda ES el
# color, la savia amarilla verdosa y los ojos claros.
MAT = {
    'corteza': [(0.20, 0.13, 0.08), (0.29, 0.19, 0.12), (0.38, 0.27, 0.17)],
    'pierna':  [(0.15, 0.10, 0.06), (0.22, 0.15, 0.09), (0.30, 0.21, 0.13)],
    'fronda':  [(0.23, 0.33, 0.16), (0.35, 0.50, 0.25), (0.52, 0.63, 0.45)],
    'grieta':  [(0.08, 0.05, 0.03), (0.10, 0.07, 0.04), (0.12, 0.08, 0.05)],
    'savia':   [(0.78, 0.86, 0.30), (0.78, 0.86, 0.30), (0.90, 0.95, 0.50)],
    'ojo':     [(0.95, 0.93, 0.62), (0.95, 0.93, 0.62), (0.98, 0.97, 0.80)],
}
LIENZO = (306, 216)
PIES = (153.0, 216 * 2.10 / 3.80)
MODELO = Modelo(2.5, LIENZO, PIES, MAT, (0.09, 0.06, 0.04), suaves=('cuerpo', 'copa'), brillan=('ojo', 'savia'),
                corta_suelo=True)


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, encorva=0.0, gira=0.0, paso=0.0, brazo_d=0.0, brazo_i=0.0, abre_d=0.0, abre_i=0.0,
             muere=0.0, copa=0.0)
    p.update(k)
    return p


CADERA = np.array([0.0, 0.0, 9.0])
HOMBRO = np.array([0.0, 2.6, 26.0])


def huesos(p):
    X = {}
    raiz = (np.eye(3), np.array([0.0, p['avance'], -p['agacha']]))
    if p['muere'] > 0.0:
        # CAE DE BRUCES, como un arbol talado: hacia delante, sobre los pies.
        raiz = comp(sobre(np.array([0.0, 2.0, 0.0]), rx(p['muere'] * math.pi * 0.47)), raiz)
    X['raiz'] = raiz
    # EL TRONCO se encorva sobre la cadera (+ hacia delante) y gira medio cuerpo (el ramazo).
    tronco = comp(raiz, comp(sobre(CADERA, rz(p['gira'])), sobre(CADERA, rx(0.12 + p['encorva']))))
    X['tronco'] = tronco
    # La copa algo SUBIDA sobre los hombros: mas baja tapaba el tronco entero y no se veia el arbol de debajo.
    X['copa'] = comp(tronco, comp(mover([0.0, 0.0, 3.0]), sobre(HOMBRO + np.array([0, 1.5, 6.0]), rx(p['copa']))))
    for s, ld, k in ((-1, 'd', 'brazo_d'), (1, 'i', 'brazo_i')):
        hombro = np.array([5.0 * s, 2.0, 25.0])
        # brazo_*: + lo levanta hacia delante; abre_*: + lo separa hacia fuera.
        M = ry(-s * p['abre_' + ld]) @ rx(p[k])
        X['brazo_' + ld] = comp(tronco, sobre(hombro, M))
    for s, ld in ((-1, 'd'), (1, 'i')):
        a = -0.35 * p['paso'] * s
        X['pierna_' + ld] = comp(raiz, sobre(np.array([4.6 * s, 0.0, 9.0]), rx(a)))
    return X


def escena(pose):
    e = Escena(huesos(pose))
    add = e.add
    # EL TRONCO: grueso, de la cadera a los hombros, inclinado hacia delante (el hueso ya lo encorva).
    add(lambda P: sd_cono(P, np.array([0, 0.0, 9.0]), np.array([0, 1.2, 27.0]), 6.2, 5.2), 'corteza', 0, 'cuerpo', 'tronco')
    # Vetas de la corteza: costillas verticales un pelo por fuera, para que no sea un tubo liso.
    for k in range(7):
        a = k / 7 * 2 * math.pi + 0.3
        dx, dy = math.cos(a), math.sin(a)
        add(lambda P, dx=dx, dy=dy: sd_cono(P, np.array([dx * 5.7, dy * 5.7, 11.0]), np.array([dx * 5.0, 1.2 + dy * 5.0, 25.0]),
                                            0.9, 0.7), 'corteza', 0.8, 'cuerpo', 'tronco')
    # LA GRIETA, en el frente del tronco, y la SAVIA asomando por dentro.
    add(lambda P: sd_elipsoide(P, np.array([0, 6.0, 16.0]), np.array([1.5, 1.4, 4.6])), 'grieta', 0, 'grieta', 'tronco')
    add(lambda P: sd_elipsoide(P, np.array([0, 6.9, 14.0]), np.array([1.0, 0.9, 2.2])), 'savia', 0, 'grieta', 'tronco')
    # LA COPA: la masa de hojas ARRIBA y ADELANTADA, en varios bultos que se funden (una bola sola era una seta).
    # ANCHA (la primera vuelta salia una cabeza redonda; el viejo es una fronda que cuelga por los lados).
    for c, r in (((0, 3.5, 33.0), (12.5, 10.5, 8.0)), ((-8.0, 2.5, 33.5), (6.5, 6.5, 6.0)), ((8.0, 2.5, 33.5), (6.5, 6.5, 6.0)),
                 ((0, -3.0, 36.0), (8.0, 6.5, 6.0)), ((0, 7.5, 31.0), (9.0, 5.5, 5.5))):
        add(lambda P, c=np.array(c, dtype=float), r=np.array(r): sd_elipsoide(P, c, r), 'fronda', 2.2, 'copa', 'copa')
    # LOS FLECOS: mechones de hojas que cuelgan por el borde de la copa, sobre todo por delante.
    for k in range(11):
        a = k / 11 * 2 * math.pi + 0.2
        dx, dy = math.cos(a) * 11.0, math.sin(a) * 9.5 + 3.0
        alto = 22.5 if dy > 3.0 else 25.5
        add(lambda P, a=np.array([dx, dy, 29.0]), b=np.array([dx * 1.04, dy + 0.5, alto]):
            sd_cono(P, a, b, 2.3, 1.2), 'fronda', 1.4, 'copa', 'copa')
    # LAS RAMAS-CUERNO: cuatro, saliendo de la fronda hacia arriba y afuera.
    for k in range(4):
        a = k / 4 * 2 * math.pi + math.pi / 4
        base = np.array([math.cos(a) * 6.0, 2.0 + math.sin(a) * 4.5, 37.0])
        punta = base + np.array([math.cos(a) * 3.5, math.sin(a) * 2.5, 9.5])
        add(lambda P, a=base, b=punta: sd_cono(P, a, b, 2.1, 0.8), 'corteza', 0, 'rama', 'copa')
        add(lambda P, a=punta, b=punta + np.array([math.cos(a + 1.2) * 1.8, math.sin(a + 1.2) * 1.8, 1.8]):
            sd_cono(P, a, b, 0.5, 0.3), 'corteza', 0, 'rama', 'copa')
    # LOS OJOS: dos puntos claros en la sombra, bajo el borde de la copa, por delante.
    for s in (-1, 1):
        add(lambda P, s=s: sd_esfera(P, np.array([2.8 * s, 13.6, 28.4]), 1.35), 'ojo', 0, 'ojo', 'copa')
    # LOS BRAZOS-RAMA: cuelgan de los hombros, se abren un poco y acaban en dedos-ramita.
    for s, ld in ((-1, 'd'), (1, 'i')):
        h = 'brazo_' + ld
        p0 = np.array([5.0 * s, 2.0, 25.0]); p1 = np.array([8.5 * s, 3.0, 17.0]); p2 = np.array([9.5 * s, 4.5, 10.0])
        add(lambda P, a=p0, b=p1: sd_cono(P, a, b, 2.2, 1.7), 'corteza', 1.0, 'brazo' + ld, h)
        add(lambda P, a=p1, b=p2: sd_cono(P, a, b, 1.7, 1.2), 'corteza', 1.0, 'brazo' + ld, h)
        for k in (-1, 0, 1):
            add(lambda P, a=p2, b=p2 + np.array([0.9 * k + 0.6 * s, 1.0, -2.6]): sd_cono(P, a, b, 0.7, 0.35), 'corteza', 0,
                'brazo' + ld, h)
    # LAS PIERNAS: dos tocones cortos y gordos, con RAICES que se abren por el suelo.
    for s, ld in ((-1, 'd'), (1, 'i')):
        h = 'pierna_' + ld
        add(lambda P, s=s: sd_cono(P, np.array([4.6 * s, 0.0, 11.0]), np.array([4.8 * s, 0.4, 1.5]), 3.0, 3.3), 'pierna', 0,
            'pierna' + ld, h)
        for k in range(5):
            a = k / 5 * 2 * math.pi + (0.3 if s > 0 else 0.9)
            add(lambda P, s=s, a=a: sd_cono(P, np.array([4.8 * s, 0.4, 1.4]),
                                            np.array([4.8 * s + math.cos(a) * 5.0, 0.4 + math.sin(a) * 4.5, 0.4]), 1.5, 0.5),
                'pierna', 0, 'pierna' + ld, h)
    return e.L


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'trent_598040_2.50', VISTAS + 'trent_vs_viejo.png', 2))
