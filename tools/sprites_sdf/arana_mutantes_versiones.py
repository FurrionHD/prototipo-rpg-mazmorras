# ============================================================
#  arana_mutantes_versiones.py -- LOS MUTANTES DE LA ARAÑA, propuestas en QUIETO (03/11/2026). Cada una con SU cuerpo
#  (silueta, proporciones y postura propias), no adornos sobre la de siempre. Nada en el suelo: los rastros y los rayos
#  que salen irian de efecto aparte.
#    TEJEDORA DE BRASAS (fuego)
#      A farol      el abdomen es una JAULA de costillas de carbon, alzada, con el nucleo de ascuas a la vista
#      B mortaja    patas larguisimas de zancuda, el cuerpo pequeño colgando y envuelto en capas de seda de ceniza
#      C horno      baja y maciza, patas gruesas con placas, abdomen de horno con chimeneas encendidas
#    ARAÑA TORMENTOSA (rayo)
#      A nube       el abdomen es una NUBE de tormenta, a bultos, con grietas de luz; patas finas y claras
#      B pararrayos larga y plana, una doble fila de pinchos con la punta encendida y patas en zigzag
#      C bobina     el abdomen alzado son anillos apilados que acaban en una bola de luz
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
TORMENTA = [(0.14, 0.17, 0.27), (0.25, 0.30, 0.43), (0.40, 0.46, 0.60)]
NUBE = [(0.22, 0.25, 0.35), (0.40, 0.44, 0.54), (0.62, 0.66, 0.74)]
PATA_CLARA = [(0.26, 0.31, 0.44), (0.42, 0.49, 0.64), (0.62, 0.69, 0.82)]
AISLANTE = [(0.10, 0.13, 0.22), (0.19, 0.24, 0.36), (0.31, 0.37, 0.52)]
LUZ_RAYO = [(0.62, 0.86, 1.0)] * 3
BLANCO_RAYO = [(0.92, 0.98, 1.0)] * 3
OJO_RAYO = [(0.72, 0.94, 1.0)] * 3

BRILLAN = ('ojo', 'ojo_fuego', 'ojo_rayo', 'brasa', 'nucleo', 'luz_rayo', 'blanco_rayo')


def _mat():
    m = dict(ars.MAT)
    m.update(carbon=CARBON, pata_carbon=PATA_CARBON, ceniza=CENIZA, brasa=BRASA, nucleo=NUCLEO, ojo_fuego=OJO_FUEGO,
             tormenta=TORMENTA, nube=NUBE, pata_clara=PATA_CLARA, aislante=AISLANTE, luz_rayo=LUZ_RAYO,
             blanco_rayo=BLANCO_RAYO, ojo_rayo=OJO_RAYO)
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
           punta=None, punta_r=0.0, placa=None, zigzag=0.0, sube=None):
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
def tormentosa_nube():
    e = _Cuerpo()
    _elip(e, (0, 3.2, 3.8), (2.7, 3.1, 1.8), 'tormenta', 0.5, 'cuerpo')
    _ojos(e, 5.6, 4.8, 'ojo_rayo')
    _boca(e, 5.6, 3.3, palpo='pata_clara')
    # LA NUBE: muchos bultos que no acaban de formar una bola, a lo ancho y a lo alto.
    rnd = random.Random(8)
    c = V((0.0, -6.5, 8.5))
    _cono(e, (0, 0.8, 4.0), (0, -3.4, 7.0), 1.1, 1.3, 'tormenta', 0, 'cintura')
    for i in range(18):
        a = rnd.uniform(0, 2 * math.pi)
        b = rnd.uniform(-0.9, 1.0)
        rr = rnd.uniform(2.5, 3.9)
        p = c + V((7.0 * math.cos(a) * math.sqrt(1 - b * b * 0.8), 6.2 * math.sin(a) * math.sqrt(1 - b * b * 0.8), 3.9 * b))
        _elip(e, p, (rr, rr, rr * 0.85), 'nube', 0.0, 'nube')
    _elip(e, c, (6.8, 6.2, 4.1), 'nube', 0.0, 'nube')
    # Las panzas oscuras por debajo, como una nube de agua.
    for x, y in ((-3.8, -5.2), (3.8, -5.0), (0.0, -8.9), (0.2, -2.7)):
        _elip(e, (x, y, 5.3), (3.6, 3.4, 1.9), 'tormenta', 0.0, 'panza')
    # EL RAYO DENTRO: una grieta de luz en zigzag que se asoma por la nube.
    for pts, r in (([(-5.6, -3.2, 9.8), (-3.1, -4.6, 12.6), (-0.8, -3.2, 12.2), (1.7, -5.2, 13.3)], 0.55),
                   ([(3.8, -8.6, 12.5), (5.9, -7.0, 10.6), (7.4, -8.2, 8.7)], 0.5),
                   ([(-3.4, -10.5, 10.2), (-1.2, -11.2, 12.1), (0.8, -10.2, 11.6)], 0.48)):
        _tubo(e, pts, [r] * len(pts), 'blanco_rayo', 'rayo')
    _patas(e, 'pata_clara', largo=13.0, alto=7.0, r=(0.82, 0.62, 0.44, 0.2), punta='luz_rayo', punta_r=0.34)
    return e.L


def tormentosa_pararrayos():
    e = _Cuerpo()
    # Larga, baja y afilada: de delante a atras una sola linea, con la doble fila de pararrayos.
    _elip(e, (0, 5.8, 2.9), (2.6, 4.2, 1.5), 'tormenta', 0.4, 'cuerpo')
    _ojos(e, 9.5, 3.5, 'ojo_rayo', 0.8)
    _boca(e, 9.5, 2.4, largo=1.1, palpo='pata_clara')
    _elip(e, (0, -5.6, 3.8), (3.7, 9.2, 2.4), 'tormenta', 0.6, 'cuerpo')
    _elip(e, (0, 1.1, 3.2), (1.9, 2.4, 1.3), 'aislante', 0.4, 'cuerpo')
    # Los segmentos del lomo y LOS PARARRAYOS, mas altos en el centro.
    for i, y in enumerate((-12.0, -9.2, -6.3, -3.3, -0.4)):
        alto = (5.0, 7.0, 9.4, 8.0, 5.5)[i]
        an = (1.5, 2.2, 2.6, 2.4, 1.6)[i]
        _elip(e, (0, y, 5.2 + (0.1 if i else -0.7)), (an + 0.6, 0.72, 0.75), 'aislante', 0, 'segmento')
        for s in (-1, 1):
            b = V((an * 0.72 * s, y, 5.3))
            t = b + V((an * 0.4 * s, -0.5, alto))
            _cono(e, b, t, 0.56, 0.17, 'aislante', 0, 'pincho')
            _elip(e, b + (t - b) * 0.55, (0.5, 0.5, 0.2), 'pata_clara', 0, 'anillo')
            _elip(e, t, (0.72, 0.72, 0.72), 'blanco_rayo', 0, 'punta_pincho')
    _patas(e, 'pata_clara', largo=12.0, alto=6.0, r=(0.82, 0.62, 0.48, 0.2), ancho=2.0, z_base=2.8,
           y_ini=(8.0, 5.6, 3.2, 0.8), abanico=(0.7, 0.22, -0.28, -0.72), zigzag=1.5, punta='luz_rayo', punta_r=0.34)
    return e.L


def tormentosa_bobina():
    e = _Cuerpo()
    _elip(e, (0, 3.2, 3.4), (3.0, 3.1, 1.9), 'tormenta', 0.5, 'cuerpo')
    _ojos(e, 5.7, 4.3, 'ojo_rayo')
    _boca(e, 5.7, 2.9, palpo='pata_clara')
    # LA BOBINA: el abdomen se alza casi en vertical, anillos cada vez mas pequeños y una bola de luz arriba.
    base = V((0.0, -0.6, 4.0))
    eje = V((0.0, -0.45, 0.89))
    _cono(e, (0, 1.2, 3.8), base + eje * 2.0, 1.4, 1.4, 'aislante', 0, 'cintura')
    d = 3.0
    radios = (5.4, 6.2, 5.8, 5.1, 4.3, 3.5, 2.6)
    for i, r in enumerate(radios):
        p = base + eje * d
        _elip(e, p, (r, r, 1.32), 'tormenta' if i % 2 == 0 else 'aislante', 0, 'anillo%d' % i)
        _elip(e, p + eje * 0.75, (r * 0.62, r * 0.62, 0.82), 'luz_rayo', 0, 'junta%d' % i)
        d += 2.3
    tope = base + eje * d
    _cono(e, tope - eje * 0.7, tope + eje * 1.5, 0.8, 0.5, 'aislante', 0, 'mastil')
    _elip(e, tope + eje * 2.3, (1.65, 1.65, 1.65), 'luz_rayo', 0, 'bola')
    _elip(e, tope + eje * 2.3, (0.98, 0.98, 0.98), 'blanco_rayo', 0, 'bola2')
    _patas(e, 'pata_clara', largo=12.5, alto=5.2, r=(1.05, 0.8, 0.58, 0.28), punta='luz_rayo', punta_r=0.38)
    return e.L


VERSIONES = [
    ('la de siempre', lambda: ars.escena(ars.POSE())),
    ('brasas A farol', tejedora_farol),
    ('brasas B mortaja', tejedora_mortaja),
    ('brasas C horno', tejedora_horno),
    ('tormenta A nube', tormentosa_nube),
    ('tormenta B pararrayos', tormentosa_pararrayos),
    ('tormenta C bobina', tormentosa_bobina),
]


def modelo():
    return Modelo(2.2, (300, 300), (150, 190), _mat(), (0.07, 0.06, 0.09), suaves=('cuerpo',), brillan=BRILLAN,
                  corta_suelo=True)


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
