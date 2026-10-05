# ============================================================
#  ciempies_sdf.py -- el CIEMPIES CARMESI en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (ciempies_sprites.gd): NO TIENE CUERPO, TIENE UNA CADENA -- una fila de anillos que SERPENTEA, y todo (las placas del
#  lomo, las patas, la cabeza) cuelga de donde caiga su anillo. Las patas AMARILLAS sobre el cuerpo rojo oscuro (lo que
#  tiene que leerse a la primera es que tiene muchas patas), antenas largas, las forcipulas delante y dos colas detras.
#  Lienzo y origen de su horneado (2,05 -> 104 x 104, el centro).
#  Uso: python tools/sprites_sdf/ciempies_sdf.py vistas
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/ciempies_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Carmesi (aa251c): el cuerpo y las placas; las patas y antenas amarillas.
MAT = {
    'cuerpo': [(0.40, 0.09, 0.07), (0.62, 0.15, 0.11), (0.80, 0.28, 0.20)],
    'placa':  [(0.30, 0.06, 0.05), (0.48, 0.10, 0.08), (0.66, 0.20, 0.15)],
    'pata':   [(0.78, 0.50, 0.10), (0.96, 0.70, 0.18), (1.0, 0.85, 0.40)],
    'garra':  [(0.12, 0.05, 0.04), (0.18, 0.08, 0.06), (0.26, 0.12, 0.09)],
    'ojo':    [(1.0, 0.90, 0.55)] * 3,
}
MODELO = Modelo(2.3, (104, 104), (52, 52), MAT, (0.12, 0.03, 0.02), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True)

N_ANILLOS = 13
PASO = 1.75


def POSE(**k):
    # 'onda': la fase del serpenteo; 'amplitud': cuanto se tuerce; 'alza': cuanto levanta la cabeza.
    p = dict(onda=0.0, amplitud=1.0, alza=0.0, avance=0.0)
    p.update(k)
    return p


def huesos(p):
    return {'raiz': (np.eye(3), V((0.0, p['avance'], 0.0)))}


def _traza(i, p):
    """Donde cae el anillo i (0 = la cabeza): una onda lateral que recorre la cadena."""
    y = (N_ANILLOS - 1) * PASO * 0.5 - i * PASO
    x = math.sin(i * 0.55 + p['onda']) * 1.6 * p['amplitud'] * min(1.0, 0.4 + i * 0.12)
    z = 1.5 + p['alza'] * max(0.0, 2.5 - i) * 1.2
    return V((x, y, z))


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena(pose):
    e = Escena(huesos(pose)); add = e.add
    pts = [_traza(i, pose) for i in range(N_ANILLOS)]
    for i in range(N_ANILLOS):
        c = pts[i]
        r = 1.9 if i == 0 else (2.15 - 0.6 * max(0, i - 8) / 4.0)
        # EL ANILLO y su PLACA del lomo (mas oscura y un pelo mas ancha): lo que lo hace segmentado.
        _elip(add, c, (r * 1.15, PASO * 0.62, r * 0.85), 'cuerpo', 0.6)
        _elip(add, c + V((0, 0, r * 0.45)), (r * 1.2, PASO * 0.48, r * 0.45), 'placa', 0, 'placa%d' % (i % 2))
        if i == 0:
            continue
        # LAS PATAS: una a cada lado por anillo, amarillas, de lado y abajo hasta el suelo.
        if i < N_ANILLOS - 1:
            nxt = pts[min(i + 1, N_ANILLOS - 1)] - pts[i - 1]
            d = nxt / np.linalg.norm(nxt)
            lado = V((-d[1], d[0], 0.0)); lado /= np.linalg.norm(lado)
            for s in (-1, 1):
                fase = math.sin(i * 1.3 + pose['onda'] * 2.0 + (0 if s > 0 else math.pi)) * 0.5
                rod = c + lado * s * (r + 1.3) + V((0, 0, 0.6)) + d * fase * 0.6
                pie = c + lado * s * (r + 2.7) + V((0, 0, -1.5)) + d * fase
                _cono(add, c + lado * s * r * 0.8, rod, 0.78, 0.66, 'pata', 0, 'pata')
                _cono(add, rod, pie, 0.66, 0.35, 'pata', 0, 'pata')
    # LA CABEZA: las antenas largas hacia delante y afuera, las forcipulas (garras) cerradas delante, y dos ojillos.
    cab = pts[0]
    for s in (-1, 1):
        _cono(add, cab + V((0.6 * s, 1.0, 0.6)), cab + V((2.6 * s, 4.0, 1.8)), 0.55, 0.42, 'pata', 0, 'antena')
        _cono(add, cab + V((2.6 * s, 4.0, 1.8)), cab + V((4.0 * s, 6.2, 1.2)), 0.42, 0.3, 'pata', 0, 'antena')
        _cono(add, cab + V((0.9 * s, 1.1, -0.3)), cab + V((1.3 * s, 2.4, -0.3)), 0.5, 0.35, 'garra', 0, 'garra')
        _cono(add, cab + V((1.3 * s, 2.4, -0.3)), cab + V((0.3 * s, 3.0, -0.3)), 0.35, 0.15, 'garra', 0, 'garra')
        _elip(add, cab + V((0.85 * s, 1.0, 0.75)), (0.35, 0.3, 0.3), 'ojo', 0, 'ojo')
    # LAS COLAS: dos patas largas detras, como las de verdad.
    col = pts[-1]
    for s in (-1, 1):
        _cono(add, col, col + V((1.6 * s, -3.6, 0.4)), 0.7, 0.35, 'pata', 0, 'cola')
    return e.L


if __name__ == '__main__':
    if sys.argv[1:] == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'ciempies_aa251c_2.05', VISTAS + 'ciempies_vs_viejo.png', 4))
