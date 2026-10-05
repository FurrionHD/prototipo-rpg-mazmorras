# ============================================================
#  escarabajo_cristal_sdf.py -- el ESCARABAJO DE CRISTAL, JEFE del PISO 18 (05/10/2026), con el motor de los enemigos
#  (sdf_comun). Sale de la version C de tools/sprites_sdf/escarabajo_versiones.py ("me gusta la de cristal, pero mas
#  cristalosa, de color diferente al bicho, y mucho mas grande, tamaño boss"). Su referencia: un cuerpo CARMESI con
#  manchas oscuras, patas GRISES como garras con el filo rojo, y el lomo hecho de CRISTALES de facetas, gris-blancos y
#  translucidos, con el rojo por dentro.
#    - LOS CRISTALES: translucidos (se ve el NUCLEO rojo de dentro y lo de detras), con su brillo especular; giradas
#      45 grados sobre su largo, para que enseñen ARISTA arriba y no una cara plana.
#    - LAS PATAS: seis, largas y acabadas en GARRA (punta afilada), grises con el filo rojo.
#    - LA CABEZA: carmesi, con ojos que brillan y dos ANTENAS-GARFIO rojas.
#  SOLO idle, walk y embestida: sus ataques seran UNICOS (por diseñar con el).
#  Uso: python tools/sprites_sdf/escarabajo_cristal_sdf.py [anim ...] -> assets/sprites/enemigos/escarabajo_cristal_sdf/
#       python tools/sprites_sdf/escarabajo_cristal_sdf.py vistas    -> tools/salida/sdf/escarabajo_cristal_vistas.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
from PIL import Image

SALIDA = 'assets/sprites/enemigos/escarabajo_cristal_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

MAT = {
    'carmesi': [(0.45, 0.06, 0.12), (0.72, 0.12, 0.20), (0.90, 0.26, 0.32), (1.0, 0.70, 0.74)],
    'mancha':  [(0.22, 0.04, 0.08), (0.32, 0.07, 0.12), (0.42, 0.10, 0.16)],
    'cristal': [(0.48, 0.44, 0.56), (0.70, 0.68, 0.78), (0.86, 0.85, 0.92), (1.0, 1.0, 1.0)],
    'nucleo':  [(0.70, 0.08, 0.16), (0.92, 0.16, 0.26), (1.0, 0.36, 0.42)],
    'garra':   [(0.24, 0.23, 0.28), (0.38, 0.37, 0.43), (0.52, 0.51, 0.58)],
    'filo':    [(0.70, 0.10, 0.16), (0.88, 0.18, 0.24), (1.0, 0.32, 0.36)],
    'ojo':     [(1.0, 0.86, 0.90)] * 3,
}
# TAMAÑO DE JEFE: casi tres veces el escarabajo del piso 7 (aquel, 2,1 en 80 x 80).
ESCALA = 5.6
LIENZO = (200, 200)
MODELO = Modelo(ESCALA, LIENZO, (100, 112), MAT, (0.10, 0.03, 0.05), suaves=('cuerpo',), brillan=('ojo', 'nucleo'),
                corta_suelo=True, especular=('cristal', 'carmesi'), umbral_especular=0.93, translucidos=('cristal',), alfa=0.72)

PASO_LARGO = 2.0
PASO_ALTO = 1.4
PATAS = ((4.2, 0.8), (0.8, -0.1), (-2.8, -0.8))
CUELLO = V((0.0, 6.6, 2.8))
LUNGE = 7.0


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, estira=1.0, fase=0.0, paso=0.0, antena=0.0, cabeza=0.0, brillo=0.0)
    p.update(k)
    return p


def huesos(p):
    S = np.diag([1.0 + 0.05 * p['agacha'], p['estira'], 1.0 - 0.2 * p['agacha']])
    X = comp((np.eye(3), V((0.0, p['avance'], 0.0))), (S, np.zeros(3)))
    return {'raiz': X, 'cabeza': comp(X, sobre(CUELLO, rx(-p['cabeza'] * 0.35))), 'mundo': IDENT}


def _cono(add, a, b, ra, rb, mat, g, h='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, 0, g, h)


def _elip(add, c, r, mat, g, h='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, 0, g, h)


def _cristal(add, c, ang, inc, med, g, nucleo=True):
    """Un cristal de facetas: su largo apunta hacia atras y arriba ('inc') y se abre de lado ('ang'); girado 45 grados
    sobre su largo para enseñar ARISTA. Con su NUCLEO rojo dentro, que se ve a traves."""
    lar = V((math.sin(ang), -math.cos(inc), math.sin(inc))); lar /= np.linalg.norm(lar)
    anc = np.cross(lar, V((0, 0, 1.0))); anc /= np.linalg.norm(anc)
    alt = np.cross(anc, lar)
    a1 = (anc + alt) / math.sqrt(2); a2 = (alt - anc) / math.sqrt(2)
    c = V(c, dtype=float)
    E = np.array([a1, lar, a2])
    # EL CRISTAL: un PRISMA cortado por un OCTAEDRO estirado (la interseccion de los dos): las caras largas del prisma
    # y las PUNTAS en facetas. Con dos cajas apiladas salia un escalon, cajas y no cristal.
    def cr(P, c=c, E=E, m=med):
        q = (P - c) @ E.T
        caja = np.linalg.norm(np.maximum(np.abs(q) - V(m), 0.0), axis=1) + np.minimum((np.abs(q) - V(m)).max(axis=1), 0.0)
        o = V((m[0] * 2.4, m[1] * 1.3, m[2] * 2.4))
        octa = (np.abs(q) / o).sum(axis=1) - 1.0
        octa = octa / math.sqrt(((1.0 / o) ** 2).sum())
        return np.maximum(caja, octa)
    add(cr, 'cristal', 0, g)
    if nucleo:
        def nu(P, c=c - lar * med[1] * 0.15, E=E, m=(med[0] * 0.4, med[1] * 0.65, med[2] * 0.4)):
            q = (P - c) @ E.T
            o = V(m)
            return ((np.abs(q) / o).sum(axis=1) - 1.0) / math.sqrt(((1.0 / o) ** 2).sum())
        add(nu, 'nucleo', 0, g + 'n')


def escena(pose):
    X = huesos(pose)
    e = Escena(X); add = e.add
    # EL CUERPO: el lomo carmesi bajo los cristales, con sus MANCHAS oscuras, el vientre y el escudo.
    _elip(add, (0, -2.4, 3.0), (4.8, 6.2, 2.6), 'carmesi', 'lomo')
    for (x, y, r) in ((-2.6, -1.0, 0.9), (2.4, -3.6, 1.0), (-1.4, -6.2, 0.8), (3.0, 0.2, 0.7), (0.4, -4.4, 0.6)):
        z = 3.0 + 2.6 * math.sqrt(max(0.0, 1 - (x / 4.8) ** 2 - ((y + 2.4) / 6.2) ** 2))
        _elip(add, (x, y, z - 0.2), (r, r * 1.2, 0.35), 'mancha', 'mancha')
    _elip(add, (0, -1.0, 1.8), (4.2, 6.2, 1.6), 'mancha', 'vientre')
    _elip(add, (0, 2.6, 2.8), (2.6, 1.4, 1.8), 'mancha', 'cintura')
    _elip(add, (0, 4.6, 3.1), (4.2, 2.4, 2.3), 'carmesi', 'pronoto')
    for (x, y, r) in ((-1.8, 4.4, 0.7), (1.6, 5.0, 0.6), (0.0, 3.6, 0.5)):
        _elip(add, (x, y, 5.2), (r, r, 0.3), 'mancha', 'mancha_p')
    # LOS CRISTALES: el grande en el centro, dos a los lados abiertos, y dos pequeños detras.
    _cristal(add, (0.0, -2.6, 9.0), 0.0, 1.05, (3.0, 7.2, 2.6), 'cr0')
    _cristal(add, (-3.6, -1.4, 6.6), -0.55, 0.8, (2.3, 5.4, 2.0), 'cr1')
    _cristal(add, (3.6, -1.6, 6.6), 0.55, 0.8, (2.3, 5.4, 2.0), 'cr2')
    _cristal(add, (-2.2, -6.0, 5.4), -0.35, 1.2, (1.6, 3.8, 1.4), 'cr3', False)
    _cristal(add, (2.4, -6.2, 5.2), 0.4, 1.25, (1.5, 3.5, 1.3), 'cr4', False)
    # LA CABEZA, carmesi, con ojos que brillan y las ANTENAS-GARFIO.
    _elip(add, (0, 7.6, 2.6), (2.4, 1.9, 1.7), 'carmesi', 'cabeza', 'cabeza')
    a = pose['antena']
    for s in (-1, 1):
        _elip(add, (1.9 * s, 8.3, 3.1), (0.8, 0.75, 0.75), 'ojo', 'ojo', 'cabeza')
        pts = [V((0.8 * s, 8.4, 3.4)), V((2.0 * s, 9.8, 5.4 + 0.4 * a)), V((3.2 * s, 10.8, 7.8 + 0.6 * a)),
               V((2.8 * s, 11.8, 8.8 + 0.6 * a))]
        for i in range(3):
            _cono(add, pts[i], pts[i + 1], 0.55 - 0.1 * i, 0.45 - 0.1 * i, 'filo', 'antena%d' % s, 'cabeza')
        _cono(add, pts[2], pts[2] + V((1.1 * s, -0.2, -0.7)), 0.32, 0.08, 'filo', 'antena%d' % s, 'cabeza')
        # mandibulas cortas
        _cono(add, (1.0 * s, 9.2, 2.0), (1.3 * s, 10.3, 1.9), 0.5, 0.3, 'garra', 'boca%d' % s, 'cabeza')
        _cono(add, (1.3 * s, 10.3, 1.9), (0.3 * s, 10.9, 1.9), 0.3, 0.1, 'filo', 'boca%d' % s, 'cabeza')
    # LAS PATAS: seis, largas, grises, acabadas en GARRA con el filo rojo; andan a tripode alterno. Los pies se calculan
    # EN EL MUNDO (con el avance), asi se quedan clavados mientras el cuerpo se agacha.
    for s in (-1, 1):
        for k, (y0, ang) in enumerate(PATAS):
            d = V((math.cos(ang) * s, math.sin(ang), 0.0))
            base = aplica(X['raiz'], V((2.6 * s, y0, 1.8)))
            grupo = (k + (1 if s > 0 else 0)) % 2
            fi = 2 * math.pi * (pose['fase'] + 0.5 * grupo)
            paso = V((0.0, PASO_LARGO * math.sin(fi), PASO_ALTO * max(0.0, math.cos(fi)))) * pose['paso']
            pie = V((2.6 * s, y0 + pose['avance'], 0.0)) + d * 9.6 + paso
            rod = base + (pie - base) * 0.45 + V((0, 0, 3.6))
            tob = base + (pie - base) * 0.8 + V((0, 0, 1.4))
            g = 'pata%d%d' % (s, k)
            _cono(add, base, rod, 0.8, 0.6, 'garra', g, 'mundo')
            _cono(add, rod, tob, 0.6, 0.45, 'garra', g, 'mundo')
            _cono(add, tob, pie + V((0, 0, 0.3)), 0.45, 0.06, 'garra', g, 'mundo')
            # el FILO rojo por fuera de la garra
            _cono(add, tob + d * 0.25 + V((0, 0, 0.15)), pie + d * 0.15 + V((0, 0, 0.35)), 0.25, 0.04, 'filo', g + 'f', 'mundo')
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES: SOLO idle, walk y embestida (sus ataques seran unicos)
# ------------------------------------------------------------
def anim_idle(t):
    # Pesado y quieto: respira despacio y tantea con las antenas-garfio.
    return POSE(estira=1.0 + 0.012 * math.sin(2 * math.pi * t), fase=t, paso=0.08,
                agacha=0.05 * (1 - math.cos(2 * math.pi * t)), antena=math.sin(2 * math.pi * t))


def anim_walk(t):
    # TRIPODE ALTERNO, lento y PESADO: el cuerpo baja en cada apoyo.
    return POSE(fase=t, paso=1.0, agacha=0.10 * (1 - math.cos(2 * math.pi * t * 2.0)), antena=0.4 * math.sin(2 * math.pi * t),
                cabeza=0.15 * math.sin(4 * math.pi * t))


def anim_embestida(t):
    # Se AGAZAPA con la cabeza baja, carga el peso y se LANZA con los cristales por delante; al llegar, cabecea arriba.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.26, 1.0), (0.46, 0.85), (0.74, 0.30), (1.0, 0.1)]),
                avance=tramos(t, [(0.0, 0.0), (0.26, -1.2), (0.46, 1.2), (0.74, LUNGE), (0.88, LUNGE * 1.1), (1.0, LUNGE * 0.8)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.26, -0.8), (0.74, -0.4), (0.88, 1.0), (1.0, 0.2)]),
                antena=tramos(t, [(0.0, 0.0), (0.26, -0.8), (0.88, 0.8), (1.0, 0.0)]))


ANIMS = {
    'idle': (8, 4.0, True, 8, anim_idle),
    'walk': (8, 6.0, True, 8, anim_walk),
    'embestida': (8, 10.0, False, 8, anim_embestida),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        W, H = LIENZO
        hoja = Image.new('RGB', (W * 5, H), (40, 42, 50))
        for d in range(5):
            im = render(MODELO, escena(POSE()), d)
            hoja.paste(im, (d * W, 0), im)
        hoja = hoja.resize((hoja.width * 2, hoja.height * 2), Image.NEAREST)
        hoja.save(VISTAS + 'escarabajo_cristal_vistas.png')
        print('ok')
    else:
        hornear('escarabajo_cristal_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
