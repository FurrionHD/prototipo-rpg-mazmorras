# ============================================================
#  coloso_versiones.py -- CINCO PROPUESTAS de coloso en 3D (05/10/2026), una por cada referencia que paso el jefe ("el
#  coloso parece unos cubos, asi que hay que hacerlo bien de verdad... haz los diferentes ejemplos"). Solo QUIETOS: el
#  elegido pasa a coloso_sdf.py para animarlo con las claves del viejo.
#    A rocas     el de rocas grises: cuerpo de CANTOS FACETADOS con juntas oscuras, antebrazos y puños enormes,
#                cabeza pequeña hundida con los ojos en una RANURA ambar, espinillas mas oscuras
#    B castillo  una FORTALEZA andante: cabeza-torreon almenado con visor, pecho con ventanas, hombreras de torre con
#                torrecillas de tejado, brazos y piernas de torre con anillos almenados, MUSGO y un banderin
#    C musgo     cantos REDONDOS color topo y lomo enorme cubierto de MUSGO, cabeza pequeña adelantada y baja con un
#                ojo, piernas cortas sobre losas
#    D placas    PLACAS ANGULOSAS marrones sobre un nucleo oscuro (se ve por las juntas), CORAZON de luz en el pecho,
#                yelmo en punta y un puño mucho mas grande que el otro
#    E cristal   piedra gris con MUSGO oliva arriba, CRISTALES azules que le brotan del lomo y de las juntas, nucleo
#                cian en el pecho, raices oscuras, hierba violeta y los antebrazos como MONOLITOS hasta el suelo
#  Uso: python tools/sprites_sdf/coloso_versiones.py [A B ...]  -> tools/salida/sdf/coloso_versiones.png
# ============================================================
import sys, os, math, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

V = np.array
ESCALA = 4.0
LIENZO = (224, 238)
PIES = (112, 161)


# ------------------------------------------------------------
#  PRIMITIVAS PROPIAS
# ------------------------------------------------------------
def _fibo(n):
    i = np.arange(n) + 0.5
    phi = np.arccos(1 - 2 * i / n); th = math.pi * (1 + 5 ** 0.5) * i
    return np.stack([np.cos(th) * np.sin(phi), np.sin(th) * np.sin(phi), np.cos(phi)], axis=1)


def _giro_azar(rng):
    q, _ = np.linalg.qr(rng.normal(size=(3, 3)))
    return q


def sd_roca(P, c, r, N, R, redondeo=1.16):
    """UNA ROCA FACETADA: el poliedro convexo de las normales N (en el espacio de la roca, girado con R y estirado a sus
    radios r), recortado por el elipsoide de radios r*redondeo para que no salgan picos. Las caras PLANAS son lo que
    la separa de un canto rodado (elipsoide) y de un sillar (caja): con tres tonos por material, cada cara sale de un
    tono y la piedra se lee tallada a golpes."""
    q = ((P - c) @ R) / r
    d = (q @ N.T).max(axis=1) - 1.0
    return np.maximum(d * r.min(), sd_elipsoide(P, c, r * redondeo))


def sd_cilindro(P, c, eje, radio, medio):
    """Cilindro de radio 'radio' y medio alto 'medio' a lo largo de 'eje' (unitario)."""
    q = P - c
    h = q @ eje
    rr = np.linalg.norm(q - np.outer(h, eje), axis=1)
    d = np.stack([rr - radio, np.abs(h) - medio], axis=1)
    return np.minimum(np.maximum(d[:, 0], d[:, 1]), 0.0) + np.linalg.norm(np.maximum(d, 0.0), axis=1)


class Monta:
    """Junta las piezas: cada ROCA en su propio grupo (entre grupos sale la linea de dentro = la junta)."""
    def __init__(self, semilla=1):
        self.e = Escena({})
        self.n = 0
        self.rng = np.random.default_rng(semilla)

    def grupo(self, pref='p'):
        self.n += 1
        return '%s%d' % (pref, self.n)

    def roca(self, c, r, mat, caras=11, redondeo=1.32, grupo=None):
        N = _fibo(caras) + self.rng.normal(scale=0.12, size=(caras, 3))
        N /= np.linalg.norm(N, axis=1, keepdims=True)
        R = _giro_azar(self.rng)
        c = V(c, dtype=float); r = V(r, dtype=float)
        self.e.add(lambda P, c=c, r=r, N=N, R=R: sd_roca(P, c, r, N, R, redondeo), mat, 0, grupo or self.grupo())

    def elip(self, c, r, mat, k=0.0, grupo=None):
        self.e.add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k,
                   grupo or self.grupo())

    def cono(self, a, b, ra, rb, mat, k=0.0, grupo=None):
        self.e.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k,
                   grupo or self.grupo())

    def caja(self, c, medio, mat, red=0.2, ejes=None, grupo=None):
        ej = np.eye(3) if ejes is None else V(ejes, dtype=float)
        self.e.add(lambda P, c=V(c, dtype=float), m=V(medio, dtype=float): sd_caja(P, c, ej, m, red), mat, 0,
                   grupo or self.grupo())

    def cilindro(self, c, eje, radio, medio, mat, grupo=None):
        eje = V(eje, dtype=float); eje /= np.linalg.norm(eje)
        self.e.add(lambda P, c=V(c, dtype=float): sd_cilindro(P, c, eje, radio, medio), mat, 0, grupo or self.grupo())

    def musgo(self, c, r, n, mat='musgo', bola=1.0, aplasta=0.75):
        """Una MATA de musgo: bolitas que se funden entre si (en un solo grupo), repartidas por una mancha de radios r."""
        g = self.grupo('musgo')
        c = V(c, dtype=float); r = V(r, dtype=float)
        for _ in range(n):
            u = self.rng.normal(size=3); u /= np.linalg.norm(u)
            u *= self.rng.uniform(0.2, 1.0)
            b = bola * self.rng.uniform(0.75, 1.14)
            self.elip(c + u * r, (b, b, b * aplasta), mat, 0.6, g)

    def anillo_almenas(self, c, radio, n, alto, mat, eje_z=True):
        g = self.grupo('almena')
        for i in range(n):
            a = 2 * math.pi * i / n
            p = V(c, dtype=float) + V((math.cos(a) * radio, math.sin(a) * radio, alto * 0.5))
            self.caja(p, (0.62, 0.62, alto * 0.5), mat, 0.12, ejes=rz(a).T, grupo=g)


def modelo(mat, borde, L, brillan=('ojo',), especular=(), salto_grupos=0.5):
    grupos = tuple(dict.fromkeys(x[2] for x in L))
    return Modelo(ESCALA, LIENZO, PIES, mat, borde, suaves=grupos, brillan=brillan, especular=especular,
                  salto_grupos=salto_grupos, corta_suelo=True)


LADOS = (-1, 1)


# ------------------------------------------------------------
#  A -- ROCAS GRISES
# ------------------------------------------------------------
MAT_A = {
    'roca':  [(0.31, 0.32, 0.35), (0.46, 0.47, 0.50), (0.63, 0.64, 0.67)],
    'roca2': [(0.27, 0.28, 0.31), (0.40, 0.41, 0.44), (0.56, 0.57, 0.60)],
    'pie':   [(0.22, 0.24, 0.30), (0.32, 0.34, 0.41), (0.44, 0.46, 0.54)],
    'ojo':   [(1.00, 0.80, 0.30)] * 2 + [(1.00, 0.90, 0.55)],
    'hueco': [(0.08, 0.08, 0.09)] * 3,
}

def version_a():
    m = Monta(11)
    for s in LADOS:
        x = 4.8 * s
        # Piernas cortas y gruesas: losa, espinilla oscura (azulada abajo, como la referencia), rodilla, muslo.
        m.roca((x, 1.4, 1.8), (3.4, 4.0, 1.9), 'pie', 9)
        m.roca((x, 0.2, 6.6), (3.0, 2.8, 3.6), 'pie', 10)
        m.roca((x + 0.3 * s, 1.2, 12.0), (3.2, 3.0, 2.6), 'roca', 10)
        m.roca((x, 0.0, 17.4), (3.6, 3.4, 3.4), 'roca2', 11)
        m.roca((x + 1.6 * s, 0.8, 20.6), (2.2, 2.4, 1.8), 'roca', 9)
    # Cadera y vientre en FILAS de cantos pequeños (los "abdominales" de piedra).
    m.roca((0.0, -0.2, 22.6), (5.4, 3.8, 2.2), 'roca2', 12)
    for s in LADOS:
        m.roca((2.2 * s, 1.4, 25.8), (2.4, 2.6, 1.7), 'roca', 9)
        m.roca((2.5 * s, 1.6, 28.8), (2.6, 2.7, 1.7), 'roca', 9)
    m.roca((0.0, -1.0, 27.4), (4.6, 3.4, 3.6), 'roca2', 11)
    # El PECHO: dos pectorales enormes y el lomo; trapecios que suben hacia la cabeza.
    m.roca((0.0, -1.6, 34.0), (6.6, 3.8, 5.0), 'roca2', 12)
    for s in LADOS:
        m.roca((3.3 * s, 1.8, 33.6), (3.9, 3.0, 3.0), 'roca', 10)
        m.roca((4.6 * s, -0.6, 38.4), (2.8, 2.6, 1.9), 'roca', 9)
    # La CABEZA: pequeña, hundida entre los hombros, con la RANURA de los ojos.
    m.roca((0.0, 1.4, 41.4), (2.5, 2.4, 2.7), 'roca', 13)
    m.caja((0.0, 3.55, 41.6), (1.8, 0.25, 0.3), 'hueco', 0.1)
    for s in LADOS:
        m.elip((0.9 * s, 3.75, 41.6), (0.55, 0.3, 0.32), 'ojo', 0, 'ojo')
    # LOS BRAZOS: hombro de canto enorme, brazo, codo, ANTEBRAZO mas grande que el brazo y el puño-roca.
    for s in LADOS:
        m.roca((9.6 * s, 0.2, 37.0), (4.0, 3.8, 3.6), 'roca', 12)
        m.roca((10.4 * s, 0.4, 31.0), (2.9, 2.9, 3.2), 'roca2', 10)
        m.roca((10.8 * s, 1.0, 26.2), (2.7, 2.7, 2.2), 'roca', 9)
        m.roca((11.4 * s, 1.6, 20.0), (3.9, 3.8, 4.6), 'roca', 11)
        m.roca((13.6 * s, 1.2, 21.0), (1.8, 2.6, 3.4), 'roca2', 8)
        m.roca((11.4 * s, 2.0, 13.4), (3.6, 3.5, 2.6), 'roca2', 10)
        for k, dx in enumerate((-1.6, 0.0, 1.6)):
            m.roca((11.4 * s + dx, 4.6, 12.0), (1.3, 1.3, 1.6), 'roca', 8)
        m.roca((11.4 * s - 2.6 * s, 3.4, 13.8), (1.2, 1.4, 1.2), 'roca', 8)
    return m.e.L


# ------------------------------------------------------------
#  B -- CASTILLO
# ------------------------------------------------------------
MAT_B = {
    'piedra': [(0.40, 0.41, 0.43), (0.56, 0.57, 0.59), (0.72, 0.73, 0.74)],
    'piedra2': [(0.33, 0.34, 0.37), (0.46, 0.47, 0.50), (0.60, 0.61, 0.63)],
    'hueco':  [(0.07, 0.07, 0.08)] * 3,
    'musgo':  [(0.26, 0.42, 0.10), (0.40, 0.60, 0.16), (0.58, 0.78, 0.26)],
    'tejado': [(0.38, 0.20, 0.13), (0.54, 0.31, 0.19), (0.67, 0.42, 0.27)],
    'trapo':  [(0.55, 0.10, 0.10), (0.72, 0.16, 0.14), (0.85, 0.25, 0.20)],
    'ojo':    [(1.00, 0.82, 0.40)] * 2 + [(1.00, 0.92, 0.60)],
}

def version_b():
    m = Monta(22)
    Zx = (0, 0, 1)
    for s in LADOS:
        x = 4.8 * s
        m.caja((x, 1.2, 1.4), (3.2, 3.8, 1.4), 'piedra2', 0.4)
        m.cilindro((x, 0.2, 8.0), Zx, 2.7, 5.4, 'piedra')
        m.cilindro((x, 0.2, 13.8), Zx, 3.3, 0.7, 'piedra2')
        m.anillo_almenas((x, 0.2, 14.4), 2.9, 7, 1.0, 'piedra2')
        m.cilindro((x, 0.0, 19.0), Zx, 3.0, 3.4, 'piedra')
        # Las saeteras de las torres-pierna.
        m.caja((x, 2.75, 9.0), (0.3, 0.2, 1.0), 'hueco', 0.05)
    m.caja((0.0, 0.0, 23.6), (6.0, 3.9, 2.0), 'piedra2', 0.4)
    m.cilindro((0.0, 0.0, 27.2), Zx, 4.4, 2.0, 'piedra')
    # El PECHO: un bloque de muralla con su cornisa y sus VENTANAS.
    m.caja((0.0, 0.4, 33.6), (6.6, 4.5, 4.4), 'piedra', 0.5)
    m.caja((0.0, 0.4, 29.6), (7.0, 4.9, 0.6), 'piedra2', 0.2)
    m.caja((0.0, 0.4, 37.9), (7.0, 4.9, 0.6), 'piedra2', 0.2)
    for x in (-3.8, -1.3, 1.3, 3.8):
        for z in (35.4, 32.4):
            m.caja((x, 4.95, z), (0.45, 0.12, 0.85), 'hueco', 0.05, grupo='ventanas')
    # La CABEZA: un TORREON almenado con el visor en T.
    m.cilindro((0.0, 0.8, 42.4), Zx, 3.0, 3.0, 'piedra')
    m.anillo_almenas((0.0, 0.8, 45.2), 2.6, 7, 1.4, 'piedra')
    m.cilindro((0.0, 0.8, 45.4), Zx, 2.0, 0.4, 'hueco')
    m.caja((0.0, 3.6, 43.0), (1.8, 0.3, 0.35), 'hueco', 0.05)
    m.caja((0.0, 3.6, 41.4), (0.4, 0.3, 1.4), 'hueco', 0.05)
    for s in LADOS:
        m.elip((0.95 * s, 3.85, 43.0), (0.4, 0.2, 0.25), 'ojo', 0, 'ojo')
    # El BANDERIN en lo alto.
    m.cono((1.4, 0.0, 45.0), (1.4, 0.0, 50.0), 0.18, 0.15, 'hueco')
    m.e.add(lambda P: sd_triangulo(P, V((1.4, 0.0, 50.0)), V((1.4, 0.0, 48.6)), V((4.0, -0.6, 49.6)), 0.15), 'trapo', 0,
            'trapo')
    # Las HOMBRERAS: torres TUMBADAS con torrecillas de tejado.
    for s in LADOS:
        m.cilindro((9.6 * s, 0.4, 37.6), (1, 0, 0), 3.4, 3.2, 'piedra')
        m.cilindro((12.9 * s, 0.4, 37.6), (1, 0, 0), 3.7, 0.45, 'piedra2')
        for dy in (-1.6, 1.6):
            m.cilindro((9.8 * s, 0.4 + dy, 41.4), Zx, 0.85, 1.0, 'piedra2')
            m.cono((9.8 * s, 0.4 + dy, 42.2), (9.8 * s, 0.4 + dy, 44.4), 1.1, 0.1, 'tejado')
        # Brazo: torre con anillo almenado abajo; antebrazo: torre gorda; puño de sillares.
        m.cilindro((10.4 * s, 0.6, 30.6), Zx, 2.5, 3.4, 'piedra2')
        m.cilindro((10.6 * s, 0.8, 26.6), Zx, 3.0, 0.6, 'piedra')
        m.anillo_almenas((10.6 * s, 0.8, 27.0), 2.6, 7, 0.9, 'piedra')
        m.cilindro((10.8 * s, 1.2, 20.0), Zx, 3.3, 4.6, 'piedra')
        m.caja((10.8 * s, 4.45, 21.0), (0.3, 0.2, 1.0), 'hueco', 0.05)
        m.cilindro((10.8 * s, 1.2, 15.2), Zx, 3.6, 0.5, 'piedra2')
        m.caja((10.8 * s, 1.8, 11.8), (3.1, 3.1, 2.8), 'piedra2', 0.9)
        for dx in (-1.4, 0.0, 1.4):
            m.caja((10.8 * s + dx, 4.6, 11.2), (0.6, 0.5, 1.6), 'piedra', 0.35, grupo='dedos%d' % s)
    # MUSGO que cuelga de cornisas y hombros.
    m.musgo((8.8, 0.8, 40.6), (2.4, 2.4, 0.4), 9)
    m.musgo((-3.0, 4.4, 37.6), (2.6, 0.8, 0.8), 7)
    m.musgo((4.0, 3.0, 29.4), (2.0, 1.0, 0.6), 6)
    m.musgo((-4.8, 2.6, 14.6), (2.0, 1.2, 0.5), 6)
    m.musgo((-10.8, 3.4, 15.4), (1.6, 0.8, 0.8), 5)
    m.musgo((0.6, 2.4, 45.6), (1.4, 1.0, 0.4), 5)
    return m.e.L


# ------------------------------------------------------------
#  C -- MUSGO
# ------------------------------------------------------------
MAT_C = {
    'roca':  [(0.45, 0.42, 0.41), (0.61, 0.58, 0.56), (0.75, 0.72, 0.70)],
    'roca2': [(0.30, 0.28, 0.33), (0.41, 0.39, 0.45), (0.52, 0.50, 0.56)],
    'musgo': [(0.26, 0.36, 0.20), (0.37, 0.49, 0.28), (0.49, 0.61, 0.36)],
    'ojo':   [(0.95, 0.95, 0.90)] * 3,
    'hueco': [(0.10, 0.09, 0.11)] * 3,
}

def version_c():
    m = Monta(33)
    for s in LADOS:
        x = 5.2 * s
        m.roca((x + 0.4 * s, 1.6, 1.8), (4.2, 4.6, 1.9), 'roca', 12, 1.14)
        m.roca((x, 0.4, 6.8), (3.3, 3.0, 3.0), 'roca2', 12, 1.14)
        m.roca((x + 0.3 * s, 1.6, 12.2), (3.8, 3.5, 3.0), 'roca', 12, 1.14)
        m.roca((x, 0.0, 17.4), (3.0, 3.0, 3.0), 'roca2', 12, 1.14)
    # Cinturon de piedra con musgo, pecho-escudo delante y el LOMO enorme detras (lo que lo hace una montaña).
    m.roca((0.0, 0.2, 23.4), (6.6, 4.6, 2.8), 'roca', 13, 1.14)
    m.roca((0.0, -1.2, 28.2), (5.4, 4.0, 3.2), 'roca2', 12, 1.14)
    m.roca((0.0, -1.8, 35.2), (8.2, 5.6, 6.4), 'roca', 14, 1.14)
    m.roca((0.0, 3.4, 31.6), (4.8, 2.4, 3.8), 'roca', 10, 1.2)
    # La cabeza: pequeña, ADELANTADA Y BAJA, metida bajo el lomo, con un solo ojo.
    m.roca((0.0, 5.6, 37.2), (2.4, 2.3, 2.6), 'roca', 12, 1.14)
    m.caja((0.0, 7.4, 37.4), (1.4, 0.3, 0.35), 'hueco', 0.1)
    m.elip((0.7, 7.55, 37.4), (0.45, 0.25, 0.32), 'ojo', 0, 'ojo')
    for s in LADOS:
        m.roca((10.2 * s, 0.0, 34.4), (4.6, 4.4, 4.2), 'roca', 13, 1.14)
        m.roca((10.4 * s, 0.6, 28.0), (2.4, 2.4, 2.8), 'roca2', 10, 1.14)
        m.roca((11.2 * s, 1.4, 21.0), (4.3, 4.2, 4.0), 'roca', 13, 1.14)
        m.roca((11.0 * s, 2.6, 13.6), (3.4, 3.4, 2.8), 'roca2', 12, 1.14)
        m.roca((11.0 * s - 1.8 * s, 4.6, 13.0), (1.5, 1.5, 1.6), 'roca2', 9, 1.2)
    # EL MUSGO: lomo, hombros, cinturon, rodillas y pies.
    m.musgo((0.0, -2.0, 41.4), (6.6, 4.4, 1.4), 30, bola=2.0)
    for s in LADOS:
        m.musgo((10.2 * s, -0.2, 38.6), (3.4, 3.4, 0.6), 14, bola=1.7)
        m.musgo((11.2 * s, 1.6, 25.0), (3.6, 3.4, 0.6), 12, bola=1.5)
        m.musgo((5.6 * s, 3.0, 15.0), (2.8, 2.2, 0.6), 8, bola=1.4)
        m.musgo((6.0 * s, 3.0, 3.2), (2.2, 1.6, 0.4), 5, bola=1.0)
    m.musgo((0.0, 3.4, 25.6), (6.0, 2.4, 0.8), 18, bola=1.6)
    return m.e.L


# ------------------------------------------------------------
#  D -- PLACAS
# ------------------------------------------------------------
MAT_D = {
    'placa':  [(0.48, 0.37, 0.28), (0.64, 0.51, 0.40), (0.79, 0.66, 0.53)],
    'placa2': [(0.40, 0.30, 0.23), (0.54, 0.42, 0.33), (0.68, 0.55, 0.44)],
    'nucleo': [(0.14, 0.10, 0.08), (0.21, 0.15, 0.12), (0.27, 0.20, 0.16)],
    'ojo':    [(1.00, 0.96, 0.86)] * 2 + [(1.00, 1.00, 0.95)],
}

def version_d():
    m = Monta(44)
    # EL NUCLEO oscuro: un cuerpo de carne de roca negra que se ve por las juntas de las placas.
    m.elip((0.0, -0.2, 31.0), (5.4, 3.6, 8.0), 'nucleo', 0, 'nucleo')
    for s in LADOS:
        m.cono((4.6 * s, 0.0, 22.0), (4.8 * s, 0.4, 2.0), 2.4, 2.2, 'nucleo', 0, 'nucleo_p%d' % s)
    m.cono((-9.6, 0.0, 37.0), (-10.4, 1.4, 14.0), 2.2, 2.0, 'nucleo', 0, 'nucleo_b1')
    m.cono((10.0, 0.0, 37.0), (11.6, 1.4, 16.0), 2.4, 2.6, 'nucleo', 0, 'nucleo_b2')
    m.elip((0.0, -0.4, 40.0), (2.0, 2.0, 2.0), 'nucleo', 0, 'nucleo_c')
    for s in LADOS:
        x = 4.8 * s
        m.roca((x, 1.6, 1.4), (3.4, 4.0, 1.5), 'placa2', 7)
        m.roca((x + 1.0 * s, 1.8, 3.2), (1.4, 1.6, 1.2), 'placa', 7)
        m.roca((x, 0.6, 7.0), (2.9, 2.7, 3.2), 'placa', 7)
        m.roca((x - 0.4 * s, 1.4, 12.2), (2.6, 2.5, 2.2), 'placa2', 7)
        m.roca((x, 0.6, 16.8), (3.2, 3.0, 2.8), 'placa', 7)
        m.roca((x + 0.4 * s, 1.2, 21.0), (2.6, 2.6, 2.0), 'placa2', 7)
    # Pelvis en V y el pecho en CHEURON, con el CORAZON de luz en medio.
    m.roca((0.0, 1.8, 23.0), (3.4, 2.6, 2.6), 'placa', 7)
    for s in LADOS:
        m.roca((3.4 * s, 1.6, 27.2), (2.6, 2.6, 2.0), 'placa2', 7)
        m.roca((3.2 * s, 2.2, 33.4), (3.6, 2.4, 3.2), 'placa', 7)
        m.roca((5.0 * s, -0.4, 38.2), (2.6, 2.6, 1.8), 'placa2', 7)
    m.roca((0.0, 2.4, 29.0), (2.4, 2.2, 1.8), 'placa', 7)
    m.roca((0.0, -2.4, 33.4), (6.0, 3.0, 5.0), 'placa2', 8)
    m.roca((0.0, 4.9, 32.6), (1.7, 1.1, 2.3), 'ojo', 6, 1.1, grupo='corazon')
    # El YELMO en punta, con un ojo bajo el filo.
    m.roca((0.0, 1.0, 42.4), (2.4, 2.6, 3.0), 'placa', 7)
    m.roca((0.0, 2.6, 44.6), (1.2, 1.6, 1.4), 'placa2', 6)
    m.elip((0.7, 3.5, 41.6), (0.4, 0.22, 0.25), 'ojo', 0, 'ojo')
    # Brazos: el derecho (pantalla izq.) normal; el IZQUIERDO con el puño enorme.
    m.roca((-9.4, 0.0, 37.6), (3.4, 3.2, 3.0), 'placa', 7)
    m.roca((-10.0, 0.4, 31.0), (2.4, 2.4, 2.8), 'placa2', 7)
    m.roca((-10.4, 1.0, 24.6), (2.7, 2.6, 3.0), 'placa', 7)
    m.roca((-10.6, 1.6, 18.4), (2.4, 2.4, 2.4), 'placa2', 7)
    m.roca((-10.6, 2.0, 14.0), (2.6, 2.6, 2.2), 'placa', 7)
    m.roca((10.4, 0.0, 38.0), (4.4, 4.0, 3.6), 'placa', 7)
    m.roca((10.8, 0.4, 31.4), (2.6, 2.6, 2.6), 'placa2', 7)
    m.roca((11.4, 0.8, 26.4), (1.8, 1.8, 1.8), 'placa', 7)
    m.roca((12.0, 1.4, 21.6), (4.8, 4.6, 4.2), 'placa', 7)
    m.roca((12.0, 2.4, 14.6), (4.0, 4.0, 3.0), 'placa2', 7)
    for dx in (-1.8, 0.0, 1.8):
        m.roca((12.0 + dx, 5.4, 13.6), (1.4, 1.4, 1.9), 'placa', 7)
    return m.e.L


# ------------------------------------------------------------
#  E -- CRISTAL
# ------------------------------------------------------------
MAT_E = {
    'roca':    [(0.38, 0.40, 0.41), (0.53, 0.55, 0.56), (0.67, 0.69, 0.70)],
    'roca2':   [(0.30, 0.32, 0.34), (0.42, 0.44, 0.46), (0.55, 0.57, 0.59)],
    'musgo':   [(0.42, 0.47, 0.16), (0.56, 0.62, 0.23), (0.70, 0.76, 0.33)],
    'cristal': [(0.18, 0.42, 0.82), (0.32, 0.62, 0.96), (0.60, 0.86, 1.00), (0.92, 0.98, 1.00)],
    'ojo':     [(0.60, 0.97, 1.00)] * 2 + [(0.85, 1.00, 1.00)],
    'raiz':    [(0.10, 0.08, 0.08), (0.15, 0.12, 0.11), (0.20, 0.16, 0.15)],
    'hierba':  [(0.38, 0.24, 0.62), (0.54, 0.38, 0.84), (0.70, 0.56, 0.96)],
}

def _prisma(m, base, dirc, largo, radio, mat='cristal'):
    """Un CRISTAL: prisma de seis caras con punta (cono al final)."""
    d = V(dirc, dtype=float); d /= np.linalg.norm(d)
    b = V(base, dtype=float)
    g = m.grupo('cristal')
    m.cilindro(b + d * largo * 0.4, d, radio, largo * 0.4, mat, grupo=g)
    m.cono(b + d * largo * 0.8, b + d * (largo + radio * 0.6), radio * 0.95, 0.1, mat, 0, g)

def version_e():
    m = Monta(55)
    for s in LADOS:
        x = 4.6 * s
        m.roca((x, 1.0, 2.0), (3.2, 3.6, 2.2), 'roca2', 9)
        m.roca((x, 0.2, 7.6), (3.0, 2.8, 3.6), 'roca', 10)
        m.elip((x, 0.6, 12.4), (1.6, 1.6, 1.0), 'ojo', 0, 'ojo')
        m.roca((x, 0.0, 16.6), (3.2, 3.0, 3.2), 'roca2', 10)
    m.roca((0.0, 0.0, 21.8), (5.2, 3.6, 2.4), 'roca2', 11)
    m.roca((0.0, 0.4, 30.0), (6.2, 4.6, 6.4), 'roca', 12)
    m.roca((0.0, -2.0, 36.0), (6.0, 4.2, 3.2), 'musgo', 10)
    # El NUCLEO cian en el pecho, con sus grietas (raices oscuras) alrededor.
    m.roca((0.0, 6.0, 30.6), (2.0, 1.3, 2.0), 'ojo', 7, 1.1, grupo='nucleo')
    for a, b in (((0.8, 5.8, 31.6), (3.6, 5.0, 35.0)), ((-0.8, 5.8, 29.4), (-4.0, 4.8, 25.6)),
                 ((-0.6, 5.8, 31.8), (-3.0, 4.8, 36.4)), ((0.8, 5.8, 29.2), (2.6, 5.0, 24.2))):
        m.cono(a, b, 0.4, 0.2, 'raiz', 0, 'raices')
    # La cabeza, pequeña y adelantada, con los ojos cian.
    m.roca((0.0, 3.0, 38.4), (2.0, 2.2, 2.6), 'roca', 11)
    m.roca((0.0, 2.6, 40.6), (1.6, 1.8, 1.0), 'musgo', 8)
    for s in LADOS:
        m.elip((0.85 * s, 5.1, 38.2), (0.45, 0.22, 0.28), 'ojo', 0, 'ojo')
    # LOS CRISTALES que le brotan del lomo (hacia arriba y algo atras: atras SUBE en pantalla, que aqui es lo que se
    # quiere: la corona de cristal que asoma por encima de la cabeza).
    for base, dirc, largo, r in (((-1.6, -3.0, 37.0), (-0.25, -0.35, 1.0), 10.0, 1.1),
                                 ((1.2, -3.4, 36.4), (0.15, -0.45, 1.0), 8.0, 0.95),
                                 ((-3.8, -2.6, 35.6), (-0.6, -0.3, 1.0), 6.5, 0.85),
                                 ((3.6, -2.8, 35.4), (0.55, -0.4, 1.0), 6.0, 0.8),
                                 ((0.0, -3.8, 34.0), (0.0, -0.7, 0.8), 5.0, 0.8)):
        _prisma(m, base, dirc, largo, r)
    # BRAZOS: hombros con musgo encima, brazo corto, CRISTALES en el codo y el antebrazo-MONOLITO hasta el suelo.
    for s in LADOS:
        m.roca((9.2 * s, 0.0, 35.2), (3.4, 3.2, 3.0), 'roca', 10)
        m.roca((9.2 * s, -0.2, 37.8), (2.8, 2.6, 1.2), 'musgo', 8)
        m.roca((9.8 * s, 0.4, 29.6), (2.2, 2.2, 2.6), 'roca2', 9)
        for dirc, largo in (((0.6 * s, 0.2, 0.9), 4.0), ((0.9 * s, 0.4, 0.3), 3.2), ((0.4 * s, -0.6, 0.6), 3.0)):
            _prisma(m, (10.2 * s, 0.4, 26.4), dirc, largo, 0.65)
        m.roca((11.6 * s, 1.2, 15.2), (4.2, 4.0, 8.4), 'roca', 10)
        m.roca((11.6 * s, 1.0, 23.2), (3.8, 3.6, 1.2), 'musgo', 9)
        m.roca((11.6 * s, 3.6, 5.0), (3.6, 2.6, 2.6), 'roca2', 8)
        for k in range(6):
            a = k * 1.05
            m.cono((11.6 * s + math.cos(a) * 2.0, 1.0 + math.sin(a) * 1.8, 23.8),
                   (11.6 * s + math.cos(a) * 2.6, 1.0 + math.sin(a) * 2.2, 27.0 + 0.6 * (k % 2)), 0.3, 0.06,
                   'hierba', 0, 'hierba%d' % s)
    return m.e.L


VERSIONES = {
    'A rocas': (MAT_A, version_a, (0.07, 0.07, 0.08), ('ojo',), ()),
    'B castillo': (MAT_B, version_b, (0.07, 0.07, 0.08), ('ojo',), ()),
    'C musgo': (MAT_C, version_c, (0.12, 0.10, 0.12), ('ojo',), ()),
    'D placas': (MAT_D, version_d, (0.09, 0.06, 0.05), ('ojo',), ()),
    'E cristal': (MAT_E, version_e, (0.07, 0.08, 0.10), ('ojo',), ('cristal',)),
}


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    solo = sys.argv[1:]
    filas = []
    if not solo:
        d = json.load(open('assets/sprites/enemigos/coloso_6a6a80_4.00.json'))
        im = Image.open('assets/sprites/enemigos/coloso_6a6a80_4.00.png').convert('RGBA')
        viejas = []
        for kk in range(5):
            a = [x for x in d['anims'] if x['n'] == 'idle_%d' % kk][0]
            x, y, w, h, ox, oy = a['f'][0]
            c = Image.new('RGBA', (d['w'], d['h'])); c.paste(im.crop((x, y, x + w, y + h)), (ox, oy)); viejas.append(c)
        filas.append(('viejo', viejas))
    for nombre, (mat, fn, borde, brillan, especular) in VERSIONES.items():
        if solo and nombre[0] not in solo:
            continue
        L = fn()
        mo = modelo(mat, borde, L, brillan, especular)
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok')
    # Recorte vertical comun (el lienzo es muy alto y casi todo es aire).
    W = max(f[1][0].size[0] for f in filas)
    H = max(f[1][0].size[1] for f in filas)
    y_ini, y_fin = H, 0
    for _, fotos in filas:
        for f in fotos:
            bb = f.getbbox()
            if bb:
                y_ini = min(y_ini, bb[1]); y_fin = max(y_fin, bb[3])
    y_ini = max(0, y_ini - 4); y_fin = min(H, y_fin + 4); h = y_fin - y_ini
    lam = Image.new('RGB', (W * 5 + 70, h * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * h + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            fc = f.crop((0, y_ini, f.size[0], y_fin))
            lam.paste(fc, (70 + i * W + (W - f.size[0]) // 2, j * h), fc)
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    sal = 'tools/salida/sdf/coloso_versiones%s.png' % ('_' + ''.join(solo) if solo else '')
    lam.save(sal)
    print(sal)
