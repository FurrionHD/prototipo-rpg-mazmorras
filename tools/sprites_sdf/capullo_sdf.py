# ============================================================
#  capullo_sdf.py -- EL CAPULLO DE CENIZA (03/11/2026, arana-mutante): lo teje la Tejedora de brasas alrededor de un
#  personaje. Es un enemigo de verdad, con su barra de vida: un huso de seda de ceniza con vetas de ascuas que laten. No
#  anda ni ataca: sus hojas son estar quieto, encajar y reventar a trozos.
#  Uso: python tools/sprites_sdf/capullo_sdf.py [anim ...] -> assets/sprites/enemigos/capullo_sdf/
# ============================================================
import sys, os, math, random
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/capullo_sdf/'
VISTAS = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes', 'capullo_hojas') + os.sep
V = np.array

MAT = {
    'cuerpo': [(0.26, 0.25, 0.26), (0.43, 0.41, 0.41), (0.60, 0.58, 0.56)],
    'hebra': [(0.17, 0.16, 0.17), (0.30, 0.28, 0.28), (0.48, 0.45, 0.44)],
    'brasa': [(1.0, 0.42, 0.08)] * 3,
    'nucleo': [(1.0, 0.80, 0.32)] * 3,
}
MODELO = Modelo(2.6, (110, 120), (55, 78), MAT, (0.07, 0.06, 0.09), suaves=('cuerpo',), brillan=('brasa', 'nucleo'), corta_suelo=True)


def POSE(**k):
    p = dict(late=0.0, sacude=0.0, ladea=0.0, rompe=0.0, avance=0.0)
    p.update(k)
    return p


def _elip(e, c, r, mat, k=0.0, grupo='adorno'):
    e.add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo)


def _cono(e, a, b, ra, rb, mat, k=0.0, grupo='adorno'):
    e.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo)


def _huso(z, alto, ancho):
    # El radio del capullo a la altura z: gordo en medio, cerrado por arriba y por abajo.
    u = max(0.0, min(1.0, z / alto))
    return ancho * math.sin(math.pi * (0.06 + 0.88 * u)) ** 0.8


def escena(p):
    X = {'raiz': (np.eye(3), V((p['sacude'], p['avance'], 0.0)))}
    X['raiz'] = comp(X['raiz'], sobre(V((0, 0, 0)), rx(p['ladea'])))
    e = Escena(X)
    ALTO = 21.0
    ANCHO = 7.2
    r0 = p['rompe']
    if r0 < 0.35:
        s = 1.0 - r0 * 0.6
        _elip(e, (0, 0, ALTO * 0.5 * s), (ANCHO * s, ANCHO * 0.92 * s, ALTO * 0.5 * s), 'cuerpo', 0.5, 'cuerpo')
        # LAS HEBRAS que lo envuelven, en espiral.
        for v in range(2):
            pts = []
            for i in range(28):
                u = i / 27.0
                z = ALTO * s * (0.05 + 0.9 * u)
                a = u * 3.2 * 2 * math.pi + v * math.pi
                rr = _huso(z, ALTO * s, ANCHO * s) + 0.15
                pts.append(V((rr * math.cos(a), rr * math.sin(a), z)))
            for a_, b_ in zip(pts, pts[1:]):
                _cono(e, a_, b_, 0.42, 0.42, 'hebra', 0, 'hebra')
        # LAS VETAS DE ASCUAS, que laten (mas gordas con 'late').
        gr = 0.42 + 0.26 * p['late']
        rnd = random.Random(5)
        for v in range(5):
            a0 = rnd.uniform(0, 2 * math.pi)
            z0 = rnd.uniform(5.0, 15.0) * s
            pts = []
            for i in range(5):
                z = z0 + i * 1.5
                a = a0 + rnd.uniform(-0.25, 0.25)
                rr = _huso(z, ALTO * s, ANCHO * s) + 0.25
                pts.append(V((rr * math.cos(a), rr * math.sin(a), z)))
            for a_, b_ in zip(pts, pts[1:]):
                _cono(e, a_, b_, gr, gr * 0.8, 'brasa', 0, 'veta')
    # REVENTAR: los trozos salen hacia fuera y caen, y se apagan.
    if r0 > 0.0:
        rnd = random.Random(9)
        for i in range(14):
            a = rnd.uniform(0, 2 * math.pi)
            z0 = rnd.uniform(3.0, 18.0)
            v_ = rnd.uniform(8.0, 15.0)
            x = math.cos(a) * (ANCHO * 0.7 + v_ * r0)
            y = math.sin(a) * (ANCHO * 0.7 + v_ * r0)
            z = z0 + 9.0 * r0 - 30.0 * r0 * r0
            tam = rnd.uniform(1.1, 2.2) * (1.0 - 0.45 * r0)
            if z > -tam:
                _elip(e, (x, y, max(z, 0.2)), (tam, tam * 0.75, tam * 0.55), 'cuerpo' if i % 3 else ('brasa' if r0 < 0.7 else 'hebra'), 0, 'trozo')
    return e.L


def anim_idle(t):
    return POSE(late=0.5 + 0.5 * math.sin(2 * math.pi * t))


def anim_encaje(t):
    return POSE(ladea=tramos(t, [(0.0, -0.18), (0.34, 0.08), (0.67, -0.03), (1.0, 0.0)]), late=1.0,
                sacude=tramos(t, [(0.0, 0.8), (0.34, -0.5), (0.67, 0.2), (1.0, 0.0)]))


def anim_muerte(t):
    return POSE(rompe=tramos(t, [(0.0, 0.0), (1.0, 1.0)]), late=1.0)


ANIMS = {
    'idle': (8, 5.0, True, 8, anim_idle),
    'walk': (8, 5.0, True, 8, anim_idle),
    'embestida': (8, 8.0, False, 8, anim_idle),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 12.0, False, 8, anim_muerte),
}

if __name__ == '__main__':
    hornear('capullo_sdf', sys.argv[1:] or list(ANIMS.keys()), SALIDA, VISTAS)
