# ============================================================
#  arana_mutantes_versiones.py -- LOS MUTANTES DE LA ARAÑA, propuestas en QUIETO (03/11/2026). Cada una con SU cuerpo
#  (silueta, proporciones y postura propias), no adornos sobre la de siempre. Nada en el suelo: los rastros y los rayos
#  que salen irian de efecto aparte.
#    TEJEDORA DE BRASAS (fuego)
#      A farol      el abdomen es una JAULA de costillas de carbon, alzada, con el nucleo de ascuas a la vista
#      B mortaja    patas larguisimas de zancuda, el cuerpo pequeño colgando y envuelto en capas de seda de ceniza
#      C horno      baja y maciza, patas gruesas con placas, abdomen de horno con chimeneas encendidas
#    ARAÑA TORMENTOSA (rayo), de SU referencia (03/11: la araña de neon, un globo de hilos de luz y patas de huesos con
#    las juntas encendidas). Las tres primeras que le saque (nube, pararrayos, bobina) no le gustaron.
#      A globo alzado  lo mas fiel: el globo hueco de hilos encima del cuerpo, con motas rojas y un nudo blanco dentro
#      B plasma        el globo detras, donde va el abdomen, con un nucleo blanco y arcos que saltan hasta los hilos
#      C neon entero   tambien el cuerpo es de hilos y las patas son de luz: casi no le queda nada solido
#      D globo macizo  el abdomen es una bola oscura con los hilos por fuera: se lee mejor en pequeño
#  Uso: python tools/sprites_sdf/arana_mutantes_versiones.py [filtro ...] -> tools/salida/sdf/arana_mutantes_versiones.png
#  (y al escritorio; con filtro solo esas filas, a arana_mutantes_prueba.png; RAPIDO=1: solo dos vistas)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import arana_sdf as ars

V = np.array
CARBON = [(0.07, 0.06, 0.07), (0.15, 0.13, 0.14), (0.27, 0.24, 0.24)]
PATA_CARBON = [(0.05, 0.04, 0.05), (0.11, 0.09, 0.10), (0.20, 0.17, 0.17)]
CENIZA = [(0.30, 0.29, 0.30), (0.47, 0.45, 0.45), (0.64, 0.62, 0.60)]
BRASA = [(1.0, 0.42, 0.08)] * 3
NUCLEO = [(1.0, 0.80, 0.32)] * 3
OJO_FUEGO = [(1.0, 0.62, 0.12)] * 3
NOCHE = [(0.02, 0.03, 0.08), (0.05, 0.07, 0.17), (0.10, 0.14, 0.30)]
PATA_AZUL = [(0.03, 0.06, 0.26), (0.07, 0.13, 0.46), (0.14, 0.24, 0.68)]
CIAN = [(0.28, 0.92, 1.0)] * 3
TURQUESA = [(0.35, 1.0, 0.86)] * 3
BLANCO_RAYO = [(0.92, 0.98, 1.0)] * 3
ROJO_MOTA = [(1.0, 0.16, 0.20)] * 3
OJO_RAYO = [(0.72, 0.94, 1.0)] * 3

BRILLAN = ('ojo', 'ojo_fuego', 'ojo_rayo', 'brasa', 'nucleo', 'cian', 'turquesa', 'blanco_rayo', 'rojo_mota')


def _mat():
    m = dict(ars.MAT)
    m.update(carbon=CARBON, pata_carbon=PATA_CARBON, ceniza=CENIZA, brasa=BRASA, nucleo=NUCLEO, ojo_fuego=OJO_FUEGO,
             noche=NOCHE, pata_azul=PATA_AZUL, cian=CIAN, turquesa=TURQUESA, blanco_rayo=BLANCO_RAYO, rojo_mota=ROJO_MOTA,
             ojo_rayo=OJO_RAYO)
    return m


class _Cuerpo:
    """Un cuerpo NUEVO, quieto (todo en el hueso 'raiz')."""
    def __init__(self):
        self.L = Piezas()
        self.L.sombras = []

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, IDENT, hueso))


def _cono(e, a, b, ra, rb, mat, k=0.0, grupo='adorno'):
    e.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo)


def _elip(e, c, r, mat, k=0.0, grupo='adorno'):
    e.add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo)


def _tubo(e, pts, rs, mat, grupo='cuerpo', k=0.0):
    pts = [V(p, dtype=float) for p in pts]
    for i in range(len(pts) - 1):
        _cono(e, pts[i], pts[i + 1], rs[i], rs[i + 1], mat, k, grupo)


def _ojos(e, y, z, mat, ancho=1.0):
    # Dos grandes delante y cuatro pequeños alrededor, como la de siempre.
    for s in (-1, 1):
        _elip(e, (0.9 * s * ancho, y, z), (0.62, 0.45, 0.58), mat, 0, 'ojo')
        _elip(e, (1.9 * s * ancho, y - 0.6, z + 0.3), (0.38, 0.3, 0.38), mat, 0, 'ojo')
        _elip(e, (0.5 * s * ancho, y - 0.6, z + 0.7), (0.32, 0.28, 0.32), mat, 0, 'ojo')


def _boca(e, y, z, mat='colmillo', largo=1.0, palpo='pata'):
    for s in (-1, 1):
        _cono(e, (0.7 * s, y, z), (0.55 * s, y + 1.1 * largo, z - 1.5 * largo), 0.7, 0.22, mat, 0, 'colmillo')
        _cono(e, (1.6 * s, y - 0.5, z - 0.3), (2.6 * s, y + 1.5, z - 2.1), 0.45, 0.28, palpo, 0, 'palpo')


def _gira_x(p, centro, ang):
    # Alza lo que esta detras de la cintura: 'ang' > 0 sube la punta del abdomen.
    d = V(p, dtype=float) - centro
    c, s_ = math.cos(ang), math.sin(ang)
    return centro + V((d[0], d[1] * c - d[2] * s_, d[1] * s_ + d[2] * c))


def _patas(e, mat, largo=11.6, alto=5.4, r=(1.0, 0.8, 0.6, 0.35), ancho=2.4, z_base=3.2, y_ini=None, abanico=None,
           punta=None, punta_r=0.0, placa=None, zigzag=0.0, sube=None, nudo=None, nudo_r=0.0):
    # Las ocho, con la forma de la de siempre (arquean por encima del lomo y bajan en tijera) y su largo y grosor propios.
    ys = y_ini if y_ini is not None else [p[0] for p in ars.PATAS]
    angs = abanico if abanico is not None else [p[1] for p in ars.PATAS]
    for s in (-1, 1):
        for k in range(4):
            base = V((ancho * s, ys[k], z_base))
            d = V((math.cos(angs[k]) * s, math.sin(angs[k]), 0.0))
            pie = base + d * largo
            pie[2] = 0.2
            h = pie - base
            rod = base + V((h[0], h[1], 0.0)) * 0.47
            rod[2] = base[2] + alto + (sube[k] if sube is not None else 0.0)
            tob = rod + (pie - rod) * 0.74
            tob[2] = pie[2] + 0.55 * (rod[2] - pie[2])
            g = 'pata%d%d' % (s, k)
            if zigzag > 0.0:
                # PATAS EN ZIGZAG: un quiebro de mas en cada tramo, para que la silueta se lea a chispazos.
                lado = d * zigzag
                m1 = (base + rod) * 0.5 + lado + V((0, 0, zigzag * 0.5))
                m2 = (rod + tob) * 0.5 - lado * 0.8 + V((0, 0, zigzag * 0.5))
                _tubo(e, [base, m1, rod, m2, tob, pie], [r[0], r[0] * 0.92, r[1], r[1] * 0.9, r[2], r[3]], mat, g)
            else:
                _tubo(e, [base, rod, tob, pie], list(r), mat, g)
            _elip(e, rod, (r[1] * 1.2,) * 3, mat, 0, g)
            if placa is not None:
                for t in (0.35, 0.72):
                    q = base + (rod - base) * t
                    _elip(e, q, (r[0] * 1.5, r[0] * 1.5, r[0] * 1.15), placa, 0, g + 'p')
            if nudo is not None:
                # LAS JUNTAS ENCENDIDAS: patas de huesos, cada articulacion con su punto de luz.
                for q in (base, rod, tob, tob + (pie - tob) * 0.55):
                    _elip(e, q, (nudo_r,) * 3, nudo, 0, 'nudo')
            if punta is not None:
                _elip(e, pie + V((0, 0, 0.5)), (punta_r, punta_r, punta_r * 1.3), punta, 0, 'punta')


def _costilla(c, r, ang, n=12, giro=None):
    # Un meridiano del elipsoide (c, r) de delante a atras, por el angulo 'ang' alrededor del eje largo (y).
    pts = []
    for i in range(n + 1):
        t = -0.96 + 1.92 * i / n
        rad = math.sqrt(max(0.0, 1.0 - t * t))
        p = V((c[0] + r[0] * rad * math.cos(ang), c[1] + r[1] * t, c[2] + r[2] * rad * math.sin(ang)))
        pts.append(giro(p) if giro else p)
    return pts


# ---------------- TEJEDORA DE BRASAS ----------------
def tejedora_farol():
    e = _Cuerpo()
    # El cefalotorax bajo, de carbon, con una raja encendida en el lomo.
    _elip(e, (0, 3.0, 3.1), (3.0, 3.3, 1.9), 'carbon', 0.5, 'cuerpo')
    _cono(e, (0, 1.0, 4.9), (0, 4.8, 4.5), 0.35, 0.25, 'brasa', 0, 'grieta')
    _ojos(e, 5.5, 4.2, 'ojo_fuego')
    _boca(e, 5.6, 2.8)
    # LA JAULA: el abdomen alzado, costillas de carbon alrededor y el nucleo de ascuas dentro, a la vista.
    pe = V((0.0, 0.2, 3.6))
    giro = lambda p: _gira_x(p, pe, -0.58)
    c = V((0.0, -6.8, 5.0))
    r = V((5.6, 6.6, 5.6))
    _cono(e, pe, giro((0, -1.2, 4.2)), 1.3, 1.0, 'carbon', 0, 'cintura')
    _elip(e, giro(c), (3.3, 4.0, 3.3), 'brasa', 0, 'nucleo')
    _elip(e, giro(c + V((0, 0.6, 0.4))), (2.1, 2.5, 2.1), 'nucleo', 0, 'nucleo2')
    for i in range(9):
        a = 2 * math.pi * i / 9 + 0.17
        _tubo(e, _costilla(c, r, a, giro=giro), [0.62] * 13, 'carbon', 'costillas')
    # Los anillos que atan las costillas, y la hilera de atras, encendida: de ahi sale la seda de fuego.
    for t in (-0.45, 0.42):
        y = c[1] + r[1] * t
        rad = math.sqrt(1 - t * t)
        pts = [giro((c[0] + r[0] * rad * math.cos(2 * math.pi * j / 18), y,
                     c[2] + r[2] * rad * math.sin(2 * math.pi * j / 18))) for j in range(19)]
        _tubo(e, pts, [0.45] * 19, 'carbon', 'costillas')
    _cono(e, giro((0, -13.0, 5.0)), giro((0, -15.0, 5.0)), 1.1, 0.5, 'carbon', 0, 'hilera')
    _elip(e, giro((0, -15.2, 5.0)), (0.5, 0.5, 0.5), 'brasa', 0, 'hilera')
    _patas(e, 'pata_carbon', largo=13.0, alto=6.6, r=(1.0, 0.75, 0.55, 0.28), punta='brasa', punta_r=0.45)
    return e.L


def tejedora_mortaja():
    e = _Cuerpo()
    # Muy alta: el cuerpo pequeño cuelga entre unas patas larguisimas, envuelto en capas de seda de ceniza.
    z = 8.5
    _elip(e, (0, 2.2, z), (2.2, 2.4, 1.5), 'carbon', 0.5, 'cuerpo')
    _ojos(e, 4.1, z + 0.8, 'ojo_fuego', 0.75)
    _boca(e, 4.0, z - 0.4, largo=0.8)
    _elip(e, (0, -3.2, z + 0.2), (3.1, 4.4, 2.9), 'carbon', 0.8, 'cuerpo')
    # LA MORTAJA: tiras de seda que caen del lomo, cada una con el borde en ascuas.
    rnd = random.Random(5)
    for i in range(11):
        a = -math.pi * 0.05 + math.pi * 1.1 * i / 10
        y = -3.0 + rnd.uniform(-2.4, 2.4)
        x0, z0 = 2.9 * math.cos(a), z + 2.6 * math.sin(a)
        alto_cae = rnd.uniform(3.4, 5.6)
        lado = 1.0 if x0 >= 0 else -1.0
        x1, z1 = x0 + lado * rnd.uniform(0.7, 1.5), max(2.2, z0 - alto_cae - 1.6)
        pts = [(x0, y, z0), (x0 * 1.14, y + 0.4, (z0 + z1) * 0.5), (x1, y - 0.3, z1)]
        _tubo(e, pts, [1.25, 1.0, 0.6], 'ceniza', 'mortaja', k=0.0)
        _elip(e, (x1, y - 0.3, z1 - 0.45), (0.82, 0.82, 0.6), 'brasa', 0, 'ascua')
    for y, an in ((-5.8, 2.8), (-3.3, 3.5), (-0.9, 3.0)):
        _elip(e, (0, y, z + 1.9), (an, 1.55, 1.2), 'ceniza', 0.2, 'capa')
    _patas(e, 'pata_carbon', largo=18.0, alto=8.5, r=(0.72, 0.52, 0.38, 0.2), ancho=1.8, z_base=z,
           y_ini=(3.2, 2.5, 1.7, 1.0), abanico=(0.62, 0.2, -0.28, -0.74), sube=(1.0, 2.0, 2.0, 1.0),
           punta='brasa', punta_r=0.42)
    return e.L


def tejedora_horno():
    e = _Cuerpo()
    # Baja y ancha, de patas gruesas con placas: un horno que anda.
    _elip(e, (0, 4.4, 2.8), (4.4, 3.6, 1.9), 'carbon', 0.5, 'cuerpo')
    _cono(e, (-3.2, 6.0, 3.0), (3.2, 6.0, 3.0), 0.8, 0.8, 'ceniza', 0, 'ceja')
    _ojos(e, 7.1, 3.0, 'ojo_fuego', 1.2)
    _boca(e, 7.0, 2.1, largo=1.4)
    _elip(e, (0, -4.6, 4.9), (7.0, 7.4, 4.9), 'carbon', 0.9, 'cuerpo')
    # Las placas de ceniza del lomo, y entre ellas las rendijas encendidas, sobre la superficie del abdomen.
    lomo = lambda y: 4.9 + 4.9 * math.sqrt(max(0.0, 1.0 - ((y + 4.6) / 7.4) ** 2))
    for y, an in ((-9.2, 2.6), (-6.2, 3.9), (-3.2, 4.2), (-0.2, 3.1)):
        _elip(e, (0, y, lomo(y) + 0.1), (an, 1.05, 0.72), 'ceniza', 0.2, 'placa')
    for y, an in ((-7.7, 3.5), (-4.7, 4.0), (-1.7, 3.5)):
        _elip(e, (0, y, lomo(y) + 0.3), (an, 0.62, 0.5), 'brasa', 0, 'rendija')
    # LAS CHIMENEAS, encendidas por dentro y con un cerco de ascuas.
    for x, y, alto, r in ((-3.9, -7.0, 5.6, 1.35), (3.9, -7.0, 5.6, 1.35), (0.0, -10.0, 6.8, 1.65)):
        b = V((x, y, 6.6))
        t = b + V((x * 0.22, -0.8, alto))
        _cono(e, b, t, r * 1.25, r, 'carbon', 0, 'chimenea')
        _elip(e, b + (t - b) * 0.62, (r * 1.2, r * 1.2, 0.34), 'brasa', 0, 'cerco')
        _elip(e, t, (r * 1.08, r * 1.08, 0.42), 'carbon', 0, 'chimenea')
        _elip(e, t + V((0, 0, 0.42)), (r * 0.92, r * 0.92, 0.42), 'nucleo', 0, 'boca_chimenea')
    _patas(e, 'pata_carbon', largo=12.5, alto=4.8, r=(1.9, 1.5, 1.1, 0.65), ancho=4.4, z_base=2.6,
           y_ini=(5.2, 3.2, 0.8, -1.8), placa='ceniza')
    return e.L


# ---------------- ARAÑA TORMENTOSA ----------------
def _globo(e, c, r, n, mat, hilo, grupo='hilos', paralelos=()):
    # Una bola de hilos que se juntan arriba y abajo (el eje es la vertical, como en la referencia).
    c = V(c, dtype=float)
    for i in range(n):
        a = 2 * math.pi * i / n + 0.2
        pts = []
        for j in range(15):
            th = math.pi * j / 14
            pts.append(c + V((r * math.sin(th) * math.cos(a), r * math.sin(th) * math.sin(a), r * math.cos(th))))
        _tubo(e, pts, [hilo] * 15, mat, grupo)
    for z in paralelos:
        rad = r * math.sqrt(max(0.0, 1.0 - z * z))
        pts = [c + V((rad * math.cos(2 * math.pi * j / 20), rad * math.sin(2 * math.pi * j / 20), r * z)) for j in range(21)]
        _tubo(e, pts, [hilo * 0.85] * 21, mat, grupo)


def _cuerpo_noche(e, z=3.2):
    _elip(e, (0, 3.0, z), (2.5, 2.9, 1.6), 'noche', 0.5, 'cuerpo')
    _cono(e, (0, 0.9, z + 1.5), (0, 4.6, z + 1.2), 0.28, 0.22, 'cian', 0, 'veta')
    _ojos(e, 5.3, z + 0.9, 'ojo_rayo', 0.85)
    _boca(e, 5.3, z - 0.4, palpo='pata_azul')


def tormentosa_globo():
    e = _Cuerpo()
    _cuerpo_noche(e)
    c = V((0.0, -2.6, 12.0))
    r = 6.8
    _tubo(e, [(0, 1.0, 3.6), (0, -1.0, 4.4), c + V((0, 0, -r))], [0.8, 0.65, 0.5], 'pata_azul', 'tallo')
    _globo(e, c, r, 12, 'cian', 0.34)
    # Dentro: las motas rojas y el nudo blanco de abajo.
    for q in ((-3.0, -3.4, 12.8), (2.0, -1.4, 9.8), (-1.2, -3.6, 8.9), (2.6, -4.2, 13.6)):
        _elip(e, q, (0.62, 0.62, 0.62), 'rojo_mota', 0, 'mota')
    _tubo(e, [(-2.6, -2.2, 7.4), (0.2, -3.6, 8.2), (2.5, -2.0, 7.4), (0.0, -1.2, 8.4), (-2.6, -2.2, 7.4)], [0.3] * 5,
          'blanco_rayo', 'nudo_blanco')
    _patas(e, 'pata_azul', largo=14.5, alto=5.6, r=(0.62, 0.48, 0.34, 0.16), nudo='turquesa', nudo_r=0.62)
    return e.L


def tormentosa_plasma():
    e = _Cuerpo()
    _cuerpo_noche(e)
    c = V((0.0, -6.8, 7.2))
    r = 6.6
    _tubo(e, [(0, 1.0, 3.6), (0, -0.9, 4.5)], [0.9, 0.8], 'pata_azul', 'tallo')
    _globo(e, c, r, 9, 'cian', 0.3)
    _elip(e, c, (1.7, 1.7, 1.7), 'blanco_rayo', 0, 'nucleo_rayo')
    # LOS ARCOS: saltan del nucleo a los hilos en zigzag.
    rnd = random.Random(4)
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.5
        b = rnd.uniform(-0.65, 0.65)
        d = V((math.cos(a) * math.sqrt(1 - b * b), math.sin(a) * math.sqrt(1 - b * b), b))
        lado = V((-d[1], d[0], 0.2))
        _tubo(e, [c + d * 1.4, c + d * 3.0 + lado * 0.9, c + d * 4.4 - lado * 0.8, c + d * (r - 0.1)], [0.3, 0.26, 0.24, 0.2],
              'blanco_rayo', 'arco')
    _patas(e, 'pata_azul', largo=13.5, alto=6.2, r=(0.68, 0.52, 0.36, 0.17), nudo='turquesa', nudo_r=0.6)
    return e.L


def tormentosa_neon():
    e = _Cuerpo()
    # Hasta el cuerpo es de hilos: dentro solo queda un poco de noche para que no se vea el suelo a traves.
    _elip(e, (0, 3.0, 3.2), (1.4, 1.7, 1.0), 'noche', 0.3, 'cuerpo')
    for i in range(6):
        a = 2 * math.pi * i / 6
        pts = []
        for j in range(11):
            t = -0.96 + 1.92 * j / 10
            rad = math.sqrt(1 - t * t)
            pts.append((2.5 * rad * math.cos(a), 3.0 + 3.0 * t, 3.2 + 1.7 * rad * math.sin(a)))
        _tubo(e, pts, [0.26] * 11, 'cian', 'hilos_cuerpo')
    _ojos(e, 5.6, 4.1, 'blanco_rayo', 0.85)
    _boca(e, 5.4, 2.9, mat='turquesa', palpo='cian')
    c = V((0.0, -5.2, 9.4))
    _tubo(e, [(0, 1.0, 3.7), (0, -1.0, 4.8), (0, -3.0, 5.1)], [0.42, 0.36, 0.32], 'turquesa', 'tallo')
    _globo(e, c, 6.8, 12, 'cian', 0.34, paralelos=(0.0,))
    for q in ((-2.8, -5.8, 10.0), (2.2, -4.2, 8.0), (0.6, -7.0, 11.3)):
        _elip(e, q, (0.62, 0.62, 0.62), 'rojo_mota', 0, 'mota')
    _patas(e, 'cian', largo=14.0, alto=6.0, r=(0.38, 0.32, 0.26, 0.16), nudo='blanco_rayo', nudo_r=0.62)
    return e.L


def tormentosa_maciza():
    e = _Cuerpo()
    _cuerpo_noche(e)
    c = V((0.0, -6.4, 7.0))
    r = 6.5
    _tubo(e, [(0, 1.0, 3.6), (0, -0.8, 4.4)], [0.95, 0.85], 'noche', 'tallo')
    _elip(e, c, (r - 0.15, r - 0.15, r - 0.15), 'noche', 0, 'bola')
    _globo(e, c, r, 10, 'cian', 0.34, paralelos=(0.42,))
    for q in (V((-3.4, -4.6, 11.2)), V((3.8, -5.4, 9.9)), V((0.4, -2.2, 10.5))):
        _elip(e, q, (0.6, 0.6, 0.6), 'rojo_mota', 0, 'mota')
    _patas(e, 'pata_azul', largo=13.0, alto=6.4, r=(0.82, 0.62, 0.44, 0.2), nudo='turquesa', nudo_r=0.68)
    return e.L


VERSIONES = [
    ('la de siempre', lambda: ars.escena(ars.POSE())),
    ('brasas A farol', tejedora_farol),
    ('tormenta A globo alzado', tormentosa_globo),
    ('tormenta B plasma', tormentosa_plasma),
    ('tormenta C neon entero', tormentosa_neon),
    ('tormenta D globo macizo', tormentosa_maciza),
]


def modelo():
    mo = Modelo(2.2, (300, 300), (150, 190), _mat(), (0.07, 0.06, 0.09), suaves=('cuerpo',), brillan=BRILLAN,
                corta_suelo=True)
    mo.sin_borde = ('cian', 'turquesa', 'blanco_rayo', 'rojo_mota')
    return mo


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    solo = sys.argv[1:]
    filas = []
    for nombre, fn in VERSIONES:
        if solo and not any(s in nombre for s in solo):
            continue
        L = fn()
        mo = modelo()
        fotos = [render(mo, L, dd) for dd in ((0, 2) if os.environ.get('RAPIDO') else range(5))]
        caja = None
        for f in fotos:
            b = f.getbbox()
            caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
        filas.append((nombre, [f.crop((caja[0] - 3, caja[1] - 3, caja[2] + 3, caja[3] + 3)) for f in fotos]))
        print(nombre, 'ok', caja, flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    ETQ = 130
    lam = Image.new('RGB', (W * len(filas[0][1]) + ETQ, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (ETQ + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    nombre_png = 'arana_mutantes_versiones.png' if not solo else 'arana_mutantes_prueba.png'
    lam.save('tools/salida/sdf/' + nombre_png)
    if not solo:
        esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
        os.makedirs(esc, exist_ok=True)
        lam.save(os.path.join(esc, nombre_png))
        print(os.path.join(esc, nombre_png))
