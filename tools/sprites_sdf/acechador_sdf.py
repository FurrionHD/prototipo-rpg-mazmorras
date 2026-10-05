# ============================================================
#  acechador_sdf.py -- el ACECHADOR en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (acechador_sprites.gd): LA LECTURA CONTRARIA DEL JABALI. Alto y estrecho, un galgo con dientes: patas LARGAS de
#  canido (la trasera con su corvejon en Z), la GRUPA ALTA y los hombros hundidos, la cabeza BAJA y adelantada por
#  debajo del lomo (la postura de acecho), morro largo con mandibula y colmillos hacia ABAJO, crin corta solo en la
#  nuca y una cola larga que CAE hacia el suelo. Casi negro: lo que se lee son los OJOS amarillos, los COLMILLOS de
#  hueso y el lomo iluminado.
#  Lienzo y origen de su horneado (1,80 -> 130 x 130, el centro).
#  Uso: python tools/sprites_sdf/acechador_sdf.py vistas  -> tools/salida/sdf/acechador_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/acechador_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Pardo casi negro (554e47); el lomo se aclara a pardo CENIZA, las patas casi negras (los calcetines del lobo).
MAT = {
    'piel':    [(0.22, 0.18, 0.15), (0.34, 0.29, 0.24), (0.50, 0.43, 0.35)],
    'pata':    [(0.12, 0.10, 0.09), (0.18, 0.15, 0.13), (0.27, 0.23, 0.20)],
    'crin':    [(0.10, 0.09, 0.08), (0.15, 0.13, 0.12), (0.22, 0.20, 0.18)],
    'morro':   [(0.15, 0.13, 0.12), (0.22, 0.19, 0.17), (0.30, 0.27, 0.24)],
    'hueso':   [(0.72, 0.68, 0.56), (0.88, 0.85, 0.72), (0.96, 0.94, 0.84)],
    'ojo':     [(0.98, 0.84, 0.30)] * 3,
    'pupila':  [(0.08, 0.05, 0.02)] * 3,
    'boca':    [(0.30, 0.08, 0.08), (0.40, 0.12, 0.11), (0.48, 0.16, 0.14)],
}
MODELO = Modelo(1.8, (130, 130), (65, 65), MAT, (0.06, 0.05, 0.04), suaves=('cuerpo', 'cabeza'),
                brillan=('ojo', 'pupila'), corta_suelo=True)

# LA LINEA DEL LOMO SUBE HACIA ATRAS (pecho 13, grupa 17): la del jabali, al reves.
PECHO = V((0.0, 5.4, 12.6))
GRUPA = V((0.0, -9.0, 16.6))
CABEZA = V((0.0, 15.6, 10.0))
NUCA = V((0.0, 9.0, 13.0))
COLA_NACE = V((0.0, -13.0, 16.0))


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, cabeza=0.0, boca=0.0, cola=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], -p['agacha'] * 2.0)))
    X['raiz'] = raiz
    # La cabeza va EXAGERADA (x1,35 desde la base del craneo), como en el viejo: a su tamaño real sale de 8 px y el
    # contorno se come los colmillos y la boca, que es justo lo que se tiene que leer.
    X['cabeza'] = comp(raiz, comp(sobre(NUCA, rx(-p['cabeza'] * 0.12)), sobre(CABEZA - V((0.0, 2.6, 0.6)), np.eye(3) * 1.35)))
    return X


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _unit(v):
    return v / np.linalg.norm(v)


def escena(pose):
    p = pose
    e = Escena(huesos(p)); add = e.add
    # --- EL TRONCO: pecho hondo y estrecho, cintura recogida (el galgo) y la grupa alta y musculada.
    _elip(add, PECHO, (4.4, 5.4, 4.4), 'piel', 0)
    _elip(add, (0.0, -1.6, 14.6), (3.8, 7.2, 3.2), 'piel', 3.0)
    _elip(add, GRUPA, (4.8, 5.0, 4.4), 'piel', 3.0)
    # El vientre recogido: sube del pecho a la ingle (lo que dice "corre").
    _elip(add, (0.0, 3.0, 10.2), (3.0, 3.6, 2.0), 'piel', 2.5)
    # ESCAPULAS: asoman por encima de la linea del lomo, en los hombros hundidos.
    for s in (-1, 1):
        _elip(add, (2.6 * s, 6.0, 15.0), (1.5, 2.6, 2.2), 'piel', 1.6)
    # --- EL CUELLO: baja del pecho a la cabeza, FINO (si no, sale un tubo del morro a la cola).
    _cono(add, (0.0, 8.0, 13.4), (0.0, 13.6, 10.8), 2.5, 1.8, 'piel', 1.6)
    # --- LA CABEZA, baja y adelantada: craneo, morro largo POR DEBAJO del eje y la mandibula.
    _elip(add, CABEZA, (2.6, 2.9, 2.4), 'piel', 0, 'cabeza', 'cabeza')
    _cono(add, CABEZA + V((0.0, 1.6, -0.3)), V((0.0, 20.6, 9.0)), 2.0, 1.15, 'piel', 1.2, 'cabeza', 'cabeza')
    _elip(add, (0.0, 21.0, 9.0), (1.05, 0.8, 0.9), 'morro', 0, 'nariz', 'cabeza')
    _cono(add, CABEZA + V((0.0, 1.0, -1.7)), V((0.0, 19.6, 7.5)), 1.5, 0.9, 'piel', 1.0, 'cabeza', 'cabeza')
    # La comisura: la raja roja a cada lado entre morro y mandibula (enseña los dientes).
    for s in (-1, 1):
        _cono(add, V((1.15 * s, 16.9, 8.2)), V((0.85 * s, 20.0, 8.1)), 0.5, 0.35, 'boca', 0, 'boca', 'cabeza')
    for s in (-1, 1):
        # OREJAS: puntiagudas y echadas hacia atras.
        _cono(add, CABEZA + V((1.5 * s, -0.6, 1.6)), CABEZA + V((2.3 * s, -2.6, 4.6)), 1.2, 0.25, 'piel', 0.5, 'cabeza',
              'cabeza')
        # OJOS: amarillos, grandes para la cabeza, que ASOMEN de la superficie, con la pupila rasgada.
        oj = CABEZA + V((1.75 * s, 2.1, 0.9))
        _elip(add, oj, (0.85, 0.8, 0.7), 'ojo', 0, 'ojo', 'cabeza')
        _elip(add, oj + V((0.45 * s, 0.35, 0.0)), (0.3, 0.3, 0.55), 'pupila', 0, 'ojo', 'cabeza')
        # COLMILLOS: cuatro, hacia ABAJO, por fuera de la boca (los de arriba largos).
        for y0, x0, largo in ((20.0, 1.0, 2.4), (17.8, 1.35, 1.7)):
            a = V((x0 * s, y0, 8.3))
            _cono(add, a, a + V((0.1 * s, 0.25, -largo)), 0.62, 0.16, 'hueso', 0, 'colmillo', 'cabeza')
    # --- LA CRIN: corta y erizada, SOLO en la nuca y la cruz; puntas que sobresalen del perfil.
    for i in range(7):
        u = i / 6.0
        y = 11.4 - u * 7.4
        z = 12.4 + u * 2.6
        x = 0.6 if i % 2 else -0.6
        _cono(add, (x, y, z), (x * 1.5, y - 2.0, z + 2.6 - 0.5 * (i % 2)), 0.95, 0.2, 'crin', 0, 'crin')
    # --- LAS PATAS: LARGAS, de canido. La delantera cae casi a plomo (hombro, codo, muñeca, mano); la trasera con su
    # muslo gordo, la rodilla delante y el CORVEJON atras (la Z que dice "salta").
    for s in (-1, 1):
        g = 'pata_d_%d' % s
        hom = V((2.6 * s, 6.6, 12.6)); codo = V((2.9 * s, 5.6, 7.2)); mun = V((3.1 * s, 6.4, 2.0))
        _cono(add, hom, codo, 2.4, 1.5, 'piel', 0.8, g)
        _cono(add, codo, mun, 1.35, 0.95, 'pata', 0.6, g)
        _elip(add, mun + V((0.0, 0.9, -1.2)), (1.35, 1.8, 0.85), 'pata', 0.6, g)
        g = 'pata_t_%d' % s
        cad = V((2.8 * s, -9.0, 15.0)); rod = V((3.2 * s, -6.6, 9.6))
        cor = V((3.3 * s, -10.6, 4.8)); pie = V((3.3 * s, -9.6, 1.0))
        _elip(add, (3.0 * s, -8.2, 12.4), (2.4, 3.8, 4.0), 'piel', 1.2, g)
        _cono(add, cad, rod, 2.4, 1.6, 'piel', 0.8, g)
        _cono(add, rod, cor, 1.4, 1.0, 'pata', 0.6, g)
        _cono(add, cor, pie, 1.0, 0.95, 'pata', 0.5, g)
        _elip(add, pie + V((0.0, 0.9, -0.2)), (1.3, 1.7, 0.8), 'pata', 0.5, g)
    # --- LA COLA: larga y baja, por PASOS FIJOS (una cadena hecha con puntos de curva se abre). Cae, barre y casi toca
    # el suelo, con la punta algo levantada.
    pt = COLA_NACE.astype(float); d = _unit(V((0.0, -0.75, -0.25))); r = 1.25
    for i in range(12):
        q = pt + d * 1.3
        _cono(add, pt, q, r, max(0.45, r - 0.07), 'piel' if i < 9 else 'crin', 0.4, 'cola')
        pt = q; r = max(0.45, r - 0.07)
        giro = 0.2 if i < 6 else -0.12
        d = _unit(rx(-giro) @ d + V((0.035 * math.sin(i * 0.8 + p['cola']), 0.0, 0.0)))
    return e.L


ANIMS = {}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'acechador_554e47_1.80', VISTAS + 'acechador_vs_viejo.png', 3))
    else:
        hornear('acechador_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
