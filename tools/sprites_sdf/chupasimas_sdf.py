# ============================================================
#  chupasimas_sdf.py -- el CHUPASIMAS en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (chupasimas_sprites.gd): UNA SANGUIJUELA -- un tubo blando y ANILLADO, sin una pata, gordo en el TERCIO TRASERO y
#  afilandose hacia una BOCA REDONDA (una ventosa con el anillo de dientes hacia dentro), y otra ventosa en la cola. Va
#  MOJADA (el brillo del motor). Lienzo y origen de su horneado (1,60 -> 104 x 104, el centro).
#  Uso: python tools/sprites_sdf/chupasimas_sdf.py vistas
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/chupasimas_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Granate (804055), con su brillo de mojado; la ventosa por dentro, oscura; los dientes, claros.
MAT = {
    'piel':   [(0.32, 0.15, 0.20), (0.50, 0.25, 0.33), (0.64, 0.38, 0.45), (0.92, 0.78, 0.82)],
    'anillo': [(0.24, 0.11, 0.15), (0.38, 0.18, 0.24), (0.48, 0.26, 0.32)],
    'boca':   [(0.12, 0.04, 0.06)] * 3,
    'diente': [(0.86, 0.82, 0.70), (0.94, 0.92, 0.82), (0.99, 0.97, 0.90)],
}
# Algo mayor que su escala (1,6), como los demas de su piso: el viejo exageraba el tamaño.
MODELO = Modelo(2.0, (104, 104), (52, 52), MAT, (0.12, 0.05, 0.07), suaves=('cuerpo',), brillan=(), corta_suelo=True,
                especular=('piel',), umbral_especular=0.9)

LARGO = 26.0
N = 16


def POSE(**k):
    # 'arco': la joroba de oruga (se arquea y se encoge); 'encoge': cuanto se acorta; 'alza': cuanto levanta la boca.
    p = dict(arco=0.0, encoge=0.0, alza=0.0, avance=0.0, onda=0.0)
    p.update(k)
    return p


def huesos(p):
    return {'raiz': (np.eye(3), V((0.0, p['avance'], 0.0)))}


def _radio(u):
    """El grosor a lo largo (u = 0 la cola, 1 la boca): gordo en el tercio trasero, afilando hacia la boca."""
    return 1.1 + 1.7 * math.exp(-((u - 0.40) / 0.36) ** 2)


def _traza(u, p):
    largo = LARGO * (1.0 - 0.35 * p['encoge'])
    y = (u - 0.5) * largo
    z = _radio(u) + 0.15 + p['arco'] * 5.0 * math.sin(math.pi * u) + p['alza'] * 4.0 * max(0.0, u - 0.7) / 0.3
    x = math.sin(u * 4.0 + p['onda']) * 0.9
    return V((x, y, z))


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena(pose):
    e = Escena(huesos(pose)); add = e.add
    us = [i / (N - 1) for i in range(N)]
    pts = [_traza(u, pose) for u in us]
    for i in range(N - 1):
        _cono(add, pts[i], pts[i + 1], _radio(us[i]), _radio(us[i + 1]), 'piel', 0.8)
    # LA ANILLACION: aros finos y oscuros todo alrededor, muy juntos.
    for k in range(2, 17):
        u = k / 18
        c = _traza(u, pose)
        d = _traza(min(u + 0.01, 1.0), pose) - _traza(max(u - 0.01, 0.0), pose); d /= np.linalg.norm(d)
        r = _radio(u) + 0.12
        def aro(P, c=c, d=d, r=r):
            q = P - c
            a = q @ d
            rad = np.linalg.norm(q - np.outer(a, d), axis=1)
            return np.sqrt((rad - r) ** 2 + a ** 2) - 0.32
        add(aro, 'anillo', 0, 'anillo')
    # LA VENTOSA DE DELANTE: un disco abierto con el anillo de DIENTES hacia dentro.
    boca = pts[-1]; d = pts[-1] - pts[-2]; d /= np.linalg.norm(d)
    cen = boca + d * 0.6
    _elip(add, cen, (1.9, 1.9, 1.9), 'piel', 0.5)
    _elip(add, cen + d * 1.3, (1.3, 1.3, 1.3), 'boca', 0, 'boca')
    a1 = np.cross(d, V((0.0, 0.0, 1.0))); a1 /= max(np.linalg.norm(a1), 1e-6); a2 = np.cross(d, a1)
    for k in range(8):
        ang = k / 8 * 2 * math.pi
        rr = a1 * math.cos(ang) + a2 * math.sin(ang)
        _cono(add, cen + d * 1.4 + rr * 1.3, cen + d * 1.1 + rr * 0.6, 0.3, 0.12, 'diente', 0, 'diente')
    # LA VENTOSA DE LA COLA: mas pequeña, un disco que se agarra.
    cola = pts[0]; dc = pts[0] - pts[1]; dc /= np.linalg.norm(dc)
    _elip(add, cola + dc * 0.6 + V((0, 0, -0.6)), (2.2, 2.2, 0.8), 'piel', 0.6)
    return e.L


if __name__ == '__main__':
    if sys.argv[1:] == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'chupasimas_804055_1.60', VISTAS + 'chupasimas_vs_viejo.png', 4))
