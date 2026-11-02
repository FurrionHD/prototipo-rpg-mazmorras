# ============================================================
#  trent_mutantes_versiones.py -- LOS MUTANTES DEL TRENT, propuestas en QUIETO (02/11/2026). El jefe eligio AMBAR,
#  MARCHITO y CARNIVORO y antes de decidir el arbol los quiere VER, y MUY distintos del normal. La 1a vuelta (adornos
#  sobre el trent de siempre) no valio: "le estas manteniendo la estructura del cuerpo y no te arriesgas a modificar el
#  enemigo entero". Esta es la 2a: CADA UNO CON SU CUERPO (silueta, proporciones y postura propias), con sus referencias
#  ('ember soul', la flor con boca, el arbol de las fauces). Nada en el suelo: los rastros irian de efecto aparte.
#    ambar A      COLOSO DE RESINA: bajo, ancho y encorvado como un gorila, nudillos al suelo con mazas de ambar y una
#                 JOROBA de ambar a la espalda con bichos dentro y tocones de rama asomando
#    ambar B      RELICARIO: el tronco es un NUCLEO de ambar con un escarabajo dentro, en una JAULA de tiras de corteza
#                 que arriba se cierra en una mascara y abajo se abre en raices-patas
#    marchito A   ESPANTAJO: altisimo y flaco, muy encorvado, la cabeza colgando delante, una COPA de ramas muertas y
#                 brazos larguisimos hasta el suelo con garras
#    marchito B   TOCON ARAÑA: un tocon PARTIDO y HUECO (luz violeta dentro) que anda sobre seis raices como una araña
#    ambar C      el TOCON ARAÑA de corteza viva rebosando ambar por arriba, chorreones, ojos y grumos de ambar (su peticion)
#    carnivoro A  FLOR: flaco, de piernas de ave, la cabeza una FLOR con boca de dientes, latigos con capullos y manos
#                 de petalos-garra
#    carnivoro B  FAUCES: sin piernas, sobre una masa de raices gordas; unas FAUCES enormes parten el tronco y las ramas
#                 son TENTACULOS que se enroscan
#    ascua        (idea nueva, de 'ember soul') una MOLE de brazos enormes, cabeza baja con cuernos encendidos, un
#                 CORAZON de ascuas en el pecho y placas de ceniza con anillos
#  Uso: python tools/sprites_sdf/trent_mutantes_versiones.py [filtro ...] -> tools/salida/sdf/trent_mutantes_versiones.png
#  (y al escritorio; con filtro solo esas filas, a trent_mutantes_prueba.png; RAPIDO=1: solo dos vistas)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import trent_sdf as ts

V = np.array
AMBAR = [(0.62, 0.30, 0.05), (0.90, 0.55, 0.12), (1.0, 0.78, 0.32), (1.0, 0.95, 0.70)]
OJO_AMBAR = [(1.0, 0.62, 0.15)] * 3
BICHO = [(0.10, 0.06, 0.04), (0.18, 0.11, 0.06), (0.26, 0.17, 0.09)]
SECA = [(0.22, 0.20, 0.21), (0.36, 0.33, 0.33), (0.50, 0.47, 0.46)]
GRIETA_LUZ = [(0.62, 0.50, 0.85)] * 3
SAVIA_NEGRA = [(0.04, 0.03, 0.06), (0.09, 0.06, 0.12), (0.30, 0.22, 0.42), (0.75, 0.70, 0.95)]
OJO_PALIDO = [(0.82, 0.74, 1.0)] * 3
PETALO = [(0.62, 0.20, 0.42), (0.86, 0.42, 0.62), (0.98, 0.72, 0.82)]
CAPULLO = [(0.50, 0.12, 0.32), (0.74, 0.28, 0.50), (0.92, 0.55, 0.70)]
TALLO = [(0.16, 0.24, 0.16), (0.26, 0.36, 0.24), (0.38, 0.48, 0.34)]
PLANTA = [(0.30, 0.18, 0.36), (0.46, 0.30, 0.52), (0.62, 0.46, 0.68)]
GARGANTA = [(0.22, 0.02, 0.06), (0.36, 0.05, 0.10), (0.50, 0.12, 0.16)]
DIENTE = [(0.70, 0.66, 0.56), (0.90, 0.87, 0.76), (1.0, 0.98, 0.90)]
CARBON = [(0.09, 0.08, 0.08), (0.17, 0.15, 0.15), (0.28, 0.25, 0.24)]
CENIZA = [(0.36, 0.36, 0.36), (0.52, 0.52, 0.50), (0.66, 0.66, 0.63)]
BRASA = [(1.0, 0.45, 0.10)] * 3
NUCLEO = [(1.0, 0.82, 0.35)] * 3


def _mat():
    m = dict(ts.MAT)
    m.update(ambar=AMBAR, ojo_ambar=OJO_AMBAR, bicho=BICHO, seca=SECA, savia_negra=SAVIA_NEGRA, ojo_palido=OJO_PALIDO,
             grieta_luz=GRIETA_LUZ, petalo=PETALO, capullo=CAPULLO, tallo=TALLO, planta=PLANTA, garganta=GARGANTA,
             diente=DIENTE, carbon=CARBON, ceniza=CENIZA, brasa=BRASA, nucleo=NUCLEO)
    return m


BRILLAN = ('ojo', 'ojo_palido', 'ojo_ambar', 'grieta_luz', 'brasa', 'nucleo')


class _Cuerpo:
    """Un cuerpo NUEVO, quieto (todo en el hueso 'raiz'). Con 'base' = True empieza por el trent de siempre."""
    def __init__(self, base=False):
        self.X = ts.huesos(ts.POSE())
        self.L = Piezas()
        self.L.sombras = []
        if base:
            self.L.extend(ts.escena(ts.POSE()))

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, self.X.get(hueso, IDENT), hueso))


def _cono(e, a, b, ra, rb, mat, k=0.0, grupo='adorno'):
    e.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo)


def _elip(e, c, r, mat, k=0.0, grupo='adorno'):
    e.add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo)


def _tubo(e, pts, rs, mat, grupo='cuerpo', k=1.0):
    # Una cadena de conos por 'pts' con un radio por punto (troncos, brazos, piernas).
    pts = [V(p, dtype=float) for p in pts]
    for i in range(len(pts) - 1):
        _cono(e, pts[i], pts[i + 1], rs[i], rs[i + 1], mat, k, grupo)


def _sobre(pts, rs, t, ang, fuera=0.0):
    # Un punto de la SUPERFICIE de un tubo vertical-ish: 't' de 0 a 1 a lo largo, 'ang' grados (90 = de frente).
    pts = [V(p, dtype=float) for p in pts]
    n = len(pts) - 1
    x = min(max(t, 0.0), 1.0) * n
    i = min(int(x), n - 1); u = x - i
    c = pts[i] * (1 - u) + pts[i + 1] * u
    r = rs[i] * (1 - u) + rs[i + 1] * u
    a = math.radians(ang)
    return c + V((math.cos(a), math.sin(a), 0.0)) * (r + fuera)


def _grietas(e, pts, rs, angulos, mat, luz, semilla, t0=0.1, t1=0.85, fuera=0.6):
    # GRIETAS por un tubo: una raja oscura y, un poco MAS FUERA, el hilo de luz (dentro de la raja no se veia).
    rnd = random.Random(semilla)
    for ang in angulos:
        ts_ = np.linspace(t0 + rnd.uniform(0, 0.1), t1 - rnd.uniform(0, 0.1), 6)
        gs = [ang + rnd.uniform(-12, 12) for _ in ts_]
        a = [_sobre(pts, rs, t, g, fuera) for t, g in zip(ts_, gs)]
        b = [_sobre(pts, rs, t, g, fuera + 0.5) for t, g in zip(ts_, gs)]
        for p, q in zip(a, a[1:]):
            _cono(e, p, q, 0.75, 0.6, mat, 0, 'grieta')
        for p, q in zip(b, b[1:]):
            _cono(e, p, q, 0.38, 0.3, luz, 0, 'grieta_luz')


def _ojos(e, c, sep, mat, r=(1.3, 0.7, 0.7), ceja=None):
    for s in (-1, 1):
        _elip(e, c + V((sep * s, 0, 0)), r, mat, 0, 'ojo')
    if ceja:
        _cono(e, c + V((-sep * 1.8, -0.3, 1.4)), c + V((sep * 1.8, -0.3, 1.4)), 1.1, 1.1, ceja, 0.8, 'cuerpo')


def _dedos(e, mano, delante, mat, n=4, largo=3.5, r=0.9, abre=1.0, grupo='mano'):
    # Dedos-rama (o garras) que salen de la mano hacia 'delante' y abajo, abiertos en abanico.
    delante = V(delante, dtype=float); delante /= np.linalg.norm(delante)
    lado = np.cross(delante, V((0, 0, 1.0))); lado /= max(np.linalg.norm(lado), 1e-6)
    for i in range(n):
        f = (i - (n - 1) / 2) * abre
        a = mano + lado * f * 0.8
        b = a + delante * largo * 0.6 + lado * f * 0.4 + V((0, 0, -largo * 0.35))
        c = b + delante * largo * 0.45 + V((0, 0, -largo * 0.45))
        _cono(e, a, b, r, r * 0.7, mat, 0.2, grupo)
        _cono(e, b, c, r * 0.7, 0.08, mat, 0, grupo)


def _raices_pie(e, pie, mat, n=5, largo=4.5, r=1.4, grupo='pie'):
    for k in range(n):
        a = k / n * 2 * math.pi + 0.3
        largo_k = largo * (1.2 if math.sin(a) > 0.2 else 0.8)
        m = pie + V((math.cos(a) * largo_k * 0.55, math.sin(a) * largo_k * 0.55, -0.4))
        f = pie + V((math.cos(a) * largo_k, math.sin(a) * largo_k, -pie[2] + 0.3))
        _cono(e, pie, m, r, r * 0.75, mat, 0.4, grupo)
        _cono(e, m, f, r * 0.75, 0.25, mat, 0, grupo)


# ------------------------------------------------------------
#  PIEZAS SUELTAS (bichos, ramas, espirales, petalos)
# ------------------------------------------------------------
def _bicho(e, b, t=1.0):
    _elip(e, b, (0.55 * t, 0.35 * t, 0.3 * t), 'bicho', 0, 'bicho')
    for s in (-1, 1):
        _cono(e, b, b + V((0.6 * s, 0.2, -0.3)) * t, 0.12 * t, 0.08 * t, 'bicho', 0, 'bicho')


def _escarabajo(e, c, t=1.0):
    # UN ESCARABAJO GRANDE atrapado (de frente al que mira): caparazon, cabeza, cuernecillo y seis patas.
    _elip(e, c, (1.6 * t, 0.7 * t, 2.0 * t), 'bicho', 0, 'bicho')
    _elip(e, c + V((0, 0, 2.2 * t)), (0.9 * t, 0.5 * t, 0.7 * t), 'bicho', 0, 'bicho')
    _cono(e, c + V((0, 0.2, 2.6 * t)), c + V((0, 0.6, 4.0 * t)), 0.3 * t, 0.08 * t, 'bicho', 0, 'bicho')
    for s in (-1, 1):
        for z in (0.9, 0.0, -0.9):
            a = c + V((1.2 * s * t, 0, z * t))
            _cono(e, a, a + V((1.6 * s * t, 0.1, (z * 0.6 - 0.5) * t)), 0.18 * t, 0.1 * t, 'bicho', 0, 'bicho')


def _ambar_con_bichos(e, c, r, bichos, semilla, k=0.8):
    _elip(e, c, r, 'ambar', k, 'ambar')
    rnd = random.Random(semilla)
    for _ in range(bichos):
        d = V((rnd.uniform(-0.5, 0.5) * r[0], rnd.uniform(-0.5, 0.5) * r[1], rnd.uniform(-0.45, 0.45) * r[2]))
        _bicho(e, V(c, dtype=float) + d, rnd.uniform(1.0, 1.8))


def _gota(e, p, largo, r):
    q = p + V((0.0, 0.2, -largo))
    _cono(e, p, q, r, r * 0.8, 'ambar', 0.3, 'ambar')
    _elip(e, q + V((0, 0, -0.3)), (r * 1.5, r * 1.5, r * 1.9), 'ambar', 0.3, 'ambar')


def _rama_seca(e, base, d, largo, r, semilla, nivel, mat='seca', grupo='rama', brasa=False):
    # UNA RAMA SECA Y PELADA: quebrada a tramos rectos, que se abre en horquillas finas. 'brasa': la punta encendida.
    rnd = random.Random(semilla)
    n = 4
    p = V(base, dtype=float)
    d = V(d, dtype=float); d = d / np.linalg.norm(d)
    for k in range(n):
        d = d + V((rnd.uniform(-0.35, 0.35), rnd.uniform(-0.35, 0.35), rnd.uniform(-0.05, 0.25)))
        d /= np.linalg.norm(d)
        q = p + d * largo / n
        r0 = max(r * (1.0 - k / (n + 0.6)), 0.15); r1 = max(r * (1.0 - (k + 1) / (n + 0.6)), 0.12)
        _cono(e, p, q, r0, r1, 'brasa' if (brasa and k == n - 1) else mat, 0.3, grupo)
        if nivel > 0 and k in (1, 3):
            lado = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), 0.6))
            _rama_seca(e, q, d * 0.4 + lado, largo * 0.45, max(r1 * 0.75, 0.2), semilla * 3 + k, nivel - 1, mat, grupo,
                       brasa)
        p = q


def _espiral(base, dir_h, alto, largo, vueltas, r_fin, n=26):
    # UN TALLO QUE SUBE Y SE ENROSCA AL FINAL: un tramo hacia fuera y arriba y luego una espiral que se cierra.
    pts = []
    base = V(base, dtype=float)
    dir_h = V(dir_h, dtype=float); dir_h = dir_h / np.linalg.norm(dir_h)
    arriba = V((0.0, 0.0, 1.0))
    for i in range(n + 1):
        t = i / n
        if t < 0.55:
            u = t / 0.55
            p = base + dir_h * largo * 0.6 * u + arriba * alto * math.sin(u * math.pi * 0.5)
        else:
            u = (t - 0.55) / 0.45
            ang = u * vueltas * 2 * math.pi
            rr = r_fin * (1.0 - 0.75 * u)
            centro = base + dir_h * largo * 0.6 + arriba * (alto - r_fin)
            p = centro + dir_h * math.sin(ang) * rr + arriba * math.cos(ang) * rr
        pts.append(p)
    return pts


def _plano(fn, eje, k):
    esc = np.ones(3); esc[eje] = 1.0 / k
    return lambda P, fn=fn, esc=esc: fn(P * esc) * k


def _petalo(e, a0, a1, ra, rb, aplasta=0.42, mat='petalo', grupo='flor', eje=1):
    # Un PETALO: un cono gordo aplastado en el eje 'eje'.
    k = aplasta
    esc = np.ones(3); esc[eje] = 1.0 / k
    e.add(_plano(lambda P, a=V(a0) * esc, b=V(a1) * esc: sd_cono(P, a, b, ra, rb), eje, k), mat, 0.5, grupo)


# ------------------------------------------------------------
#  AMBAR A -- COLOSO DE RESINA
# ------------------------------------------------------------
def coloso_resina():
    e = _Cuerpo()
    # Piernas cortas de tocon, separadas.
    for s in (-1, 1):
        pie = V((7.5 * s, 1.5, 1.6))
        _tubo(e, [(6.0 * s, -1.0, 10.0), (7.2 * s, 1.0, 5.0), pie], [4.2, 3.8, 4.2], 'corteza', 'pierna%d' % s)
        _raices_pie(e, pie, 'corteza', 5, 4.5, 1.6, 'pierna%d' % s)
    # El tronco, ancho y echado hacia delante (encorvado: los hombros por delante de la cadera).
    eje = [(0, -2.0, 9.0), (0, 0.0, 15.0), (0, 2.5, 21.0), (0, 5.0, 25.5), (0, 7.0, 28.0)]
    rad = [10.0, 11.0, 11.0, 9.5, 7.5]
    _tubo(e, eje, rad, 'corteza', 'cuerpo', 2.5)
    _elip(e, (0, 4.0, 25.0), (14.0, 8.0, 6.0), 'corteza', 2.5, 'cuerpo')          # los hombros, anchisimos
    # La cabeza HUNDIDA entre los hombros, por delante: un bulto con la ceja y los ojos de ambar.
    _elip(e, (0, 12.0, 26.5), (5.0, 4.5, 4.4), 'corteza', 1.2, 'cuerpo')
    _ojos(e, V((0, 16.2, 27.5)), 2.0, 'ojo_ambar', (1.2, 0.6, 0.7), 'corteza')
    _elip(e, (0, 16.3, 24.6), (2.4, 0.6, 0.6), 'hueco', 0, 'boca')
    # Brazos enormes que llegan al suelo: los NUDILLOS apoyados, con la mano metida en una MAZA de ambar.
    for s in (-1, 1):
        g = 'brazo%d' % s
        mano = V((16.0 * s, 11.0, 4.0))
        _tubo(e, [(12.0 * s, 4.0, 26.0), (16.5 * s, 6.0, 17.0), (15.5 * s, 9.5, 8.0), mano], [5.2, 4.6, 4.0, 3.8],
              'corteza', g)
        _ambar_con_bichos(e, mano + V((0, 0.5, -0.4)), (4.8, 4.8, 4.0), 2, 3 + s, 0.6)
    # LA JOROBA de ambar: tres bultos fundidos sobre la espalda, con bichos dentro y tocones de rama asomando.
    # (alta: que asome por ENCIMA de los hombros, que la camara mira desde arriba y delante)
    _ambar_con_bichos(e, (0, -3.0, 32.0), (9.0, 7.0, 8.5), 4, 11)
    _ambar_con_bichos(e, (-6.5, -1.0, 34.0), (4.8, 4.5, 5.0), 1, 12)
    _ambar_con_bichos(e, (6.5, -1.0, 34.0), (4.8, 4.5, 5.0), 1, 13)
    _ambar_con_bichos(e, (0, -7.0, 21.0), (7.5, 5.0, 7.0), 2, 14)
    for (x, y, z, dx, dz) in ((-3, -4, 39, -0.4, 1.0), (3.5, -5, 38.5, 0.5, 1.0), (0, -2, 40, 0.1, 1.0),
                              (-7, -1, 38, -0.7, 0.8), (7, -1, 38, 0.7, 0.8)):
        _cono(e, (x, y, z - 3.0), (x + dx * 4.5, y - 1.0, z + dz * 4.5), 1.4, 0.5, 'corteza', 0, 'rama')
    # Gotas que le cuelgan de la barbilla.
    for x in (-1.5, 1.2):
        _gota(e, V((x, 15.5, 23.5)), 2.5, 0.5)
    return e.L


# ------------------------------------------------------------
#  AMBAR B -- RELICARIO
# ------------------------------------------------------------
def relicario():
    e = _Cuerpo()
    # EL NUCLEO de ambar (el tronco entero), con un escarabajo grande y bichos dentro.
    _ambar_con_bichos(e, (0, 0.5, 22.0), (6.2, 5.6, 12.5), 6, 21, 0)
    _escarabajo(e, V((0, 2.5, 22.0)), 1.6)
    # LA JAULA: tiras de corteza que se retuercen alrededor del nucleo; arriba se cierran en la cabeza y abajo se abren
    # en RAICES-PATAS.
    n = 7
    for i in range(n):
        a0 = i / n * 2 * math.pi + 0.25
        pts = []
        for j in range(9):
            t = j / 8
            z = 7.5 + t * 29.0
            ang = a0 + t * 0.9
            rr = 6.6 * math.sin(math.pi * (0.12 + t * 0.8)) + 1.2
            pts.append((math.cos(ang) * rr, math.sin(ang) * rr + 0.5, z))
        _tubo(e, pts, [1.5] * len(pts), 'corteza', 'cuerpo', 0.6)
        # la pata: de abajo de la tira hacia fuera y al suelo
        b = V(pts[0], dtype=float)
        dirh = V((math.cos(a0), math.sin(a0), 0.0))
        rod = b + dirh * 5.5 + V((0, 0, 1.5))
        punta = b + dirh * 10.5 + V((0, 0, -b[2] + 0.3))
        _tubo(e, [b, rod, punta], [1.8, 1.4, 0.35], 'corteza', 'pata', 0.4)
    # La cabeza: una MASCARA de corteza encima de la jaula, con los ojos de ambar y ramitas de corona.
    _elip(e, (0, 1.5, 38.5), (5.0, 4.5, 4.8), 'corteza', 1.2, 'cuerpo')
    _ojos(e, V((0, 5.8, 39.0)), 1.9, 'ojo_ambar', (1.2, 0.6, 0.8), 'corteza')
    _elip(e, (0, 6.0, 36.2), (1.8, 0.5, 0.5), 'hueco', 0, 'boca')
    for i, (dx, dy) in enumerate(((-2.5, -1.0), (0.0, -2.0), (2.5, -1.0))):
        _rama_seca(e, (dx, dy, 42.0), (dx * 0.25, -0.2, 1.0), 7.0, 0.9, 50 + i, 1, 'corteza', 'rama')
    # Brazos de rama, largos y finos, colgando, con gotas de ambar en la punta de los dedos.
    for s in (-1, 1):
        g = 'brazo%d' % s
        mano = V((10.5 * s, 4.5, 14.0))
        _tubo(e, [(5.5 * s, 0.5, 33.5), (10.0 * s, 0.5, 27.0), (11.5 * s, 2.5, 20.0), mano], [1.8, 1.6, 1.4, 1.3],
              'corteza', g, 0.4)
        _dedos(e, mano, (0.1 * s, 1.0, -0.4), 'corteza', 3, 4.0, 0.6, 1.2, g)
        _gota(e, mano + V((0, 2.5, -4.0)), 2.0, 0.5)
    return e.L


# ------------------------------------------------------------
#  MARCHITO A -- ESPANTAJO
# ------------------------------------------------------------
def espantajo():
    e = _Cuerpo()
    # Piernas largas y flacas, dobladas, con pies de raiz.
    for s in (-1, 1):
        g = 'pierna%d' % s
        pie = V((5.5 * s, 0.0, 1.5))
        _tubo(e, [(3.0 * s, -2.0, 21.0), (5.5 * s, 3.5, 12.0), pie], [2.2, 1.7, 1.5], 'seca', g, 0.5)
        _raices_pie(e, pie, 'seca', 4, 4.0, 0.9, g)
    # El tronco FLACO y muy encorvado: sube y se dobla hacia delante como un viejo.
    eje = [(0, -2.0, 20.0), (0, -1.0, 28.0), (0, 2.0, 35.0), (0, 7.0, 40.0), (0, 11.0, 41.0)]
    rad = [4.4, 4.0, 4.0, 3.8, 3.0]
    _tubo(e, eje, rad, 'seca', 'cuerpo', 1.0)
    _grietas(e, eje, rad, (40, 140, 220, 320, 270), 'savia_negra', 'grieta_luz', 31, 0.05, 0.75, 0.2)
    # La cabeza COLGANDO por delante, alargada hacia abajo como una calavera de madera.
    _elip(e, (0, 15.0, 37.5), (3.2, 3.2, 4.6), 'seca', 1.2, 'cuerpo')
    _ojos(e, V((0, 17.8, 38.5)), 1.4, 'ojo_palido', (0.8, 0.5, 0.6))
    _cono(e, (-1.2, 18.0, 35.0), (1.2, 18.0, 35.0), 0.6, 0.6, 'hueco', 0, 'boca')
    for x in (-1.0, 0.0, 1.0):
        _cono(e, (x, 17.5, 34.5), (x * 1.2, 17.6, 31.0 - abs(x)), 0.5, 0.1, 'seca', 0, 'barba')
    # LA COPA de ramas muertas, de los hombros y la espalda, quebradas y abiertas.
    for i, (b, d, lg, r) in enumerate(((( -3.0, 3.0, 40.0), (-0.8, -0.3, 1.0), 20.0, 1.8),
                                       ((3.0, 3.0, 40.0), (0.8, -0.3, 1.0), 20.0, 1.8),
                                       ((0.0, 0.5, 39.0), (0.0, -0.8, 1.0), 22.0, 2.0),
                                       ((-2.0, -1.0, 34.0), (-0.9, -0.9, 0.6), 15.0, 1.5),
                                       ((2.0, -1.0, 34.0), (0.9, -0.9, 0.6), 15.0, 1.5),
                                       ((0.0, 6.0, 41.5), (0.1, 0.3, 1.0), 13.0, 1.3))):
        _rama_seca(e, b, d, lg, r, 70 + i * 7, 2)
    # Brazos LARGUISIMOS que cuelgan hasta el suelo, con dedos de garra.
    for s in (-1, 1):
        g = 'brazo%d' % s
        mano = V((9.0 * s, 15.0, 8.0))
        _tubo(e, [(4.5 * s, 8.0, 40.0), (9.5 * s, 9.5, 29.0), (9.5 * s, 13.0, 17.0), mano], [2.0, 1.6, 1.4, 1.3],
              'seca', g, 0.5)
        _dedos(e, mano, (0.0, 1.0, -0.5), 'seca', 4, 6.0, 0.55, 1.0, g)
    return e.L


# ------------------------------------------------------------
#  MARCHITO B -- TOCON ARAÑA
# ------------------------------------------------------------
def tocon_arana(ambar=False):
    # 'ambar' (02/11, "haz el de ambar como el B de este"): el mismo tocon araña pero de corteza VIVA, rebosando ambar
    # por la boca de arriba (un domo con bichos), con chorreones por los costados, ojos de ambar y grumos en las rodillas.
    e = _Cuerpo()
    mat = 'corteza' if ambar else 'seca'
    # EL TOCON: ancho y bajo, en alto sobre las patas; la boca de arriba PARTIDA en astillas y HUECO por dentro.
    eje = [(0, 0, 8.0), (0, 0.3, 14.0), (0, 0.5, 21.0)]
    rad = [8.0, 8.6, 8.2]
    _tubo(e, eje, rad, mat, 'cuerpo', 1.5)
    if ambar:
        # (la tapa del tronco es redonda y sube hasta z 29: el domo va ENCIMA, o la tapa se lo come)
        _ambar_con_bichos(e, (0, 0.5, 27.5), (5.8, 5.8, 3.8), 3, 61, 0.6)
        _escarabajo(e, V((0, 1.5, 29.0)), 1.3)
        # y se DESBORDA: grumos que caen por el borde, entre las astillas
        for k, ang in enumerate((40, 110, 200, 290)):
            a = math.radians(ang)
            _ambar_con_bichos(e, (math.cos(a) * 6.0, 0.5 + math.sin(a) * 6.0, 24.0), (3.0, 3.0, 3.6), k % 2, 70 + k, 0.8)
        for k, ang in enumerate((20, 55, 125, 160, 215, 270, 325)):
            p = _sobre(eje, rad, 0.95, ang, -0.3)
            _gota(e, p, 5.0 + (k % 3) * 2.5, 0.8 + 0.15 * (k % 2))
    else:
        _elip(e, (0, 0.5, 21.2), (6.4, 6.4, 1.2), 'hueco', 0, 'hueco')
        _elip(e, (0, 0.5, 21.0), (2.6, 2.6, 1.3), 'grieta_luz', 0, 'hueco')
    rnd = random.Random(5)
    for i in range(11):
        a = i / 11 * 2 * math.pi
        alto = rnd.uniform(3.0, 9.0) if math.sin(a) < 0.5 else rnd.uniform(2.0, 4.0)
        b = V((math.cos(a) * 7.4, 0.5 + math.sin(a) * 7.4, 20.0))
        if ambar:
            alto += 6.0          # que asomen por encima del ambar
        _cono(e, b, b + V((math.cos(a) * 0.8, math.sin(a) * 0.8, alto)), 1.6, 0.1, mat, 0.3, 'astilla')
    if not ambar:
        _grietas(e, eje, rad, (30, 150, 210, 330), 'savia_negra', 'grieta_luz', 41, 0.0, 0.9, 0.2)
    # La cara, en el frente del tocon: ojos (violeta o de ambar) y una raja dentada.
    _ojos(e, V((0, 9.2, 16.5)), 2.4, 'ojo_ambar' if ambar else 'ojo_palido', (1.0, 0.5, 0.7))
    _elip(e, (0, 9.0, 12.5), (3.4, 0.7, 1.1), 'hueco', 0, 'boca')
    for x in (-2.4, -0.8, 0.8, 2.4):
        _cono(e, (x, 9.3, 13.4), (x, 9.6, 12.0), 0.45, 0.06, mat, 0, 'diente')
    if ambar:
        for x in (-1.6, 1.4):
            _gota(e, V((x, 9.4, 11.8)), 2.2, 0.45)
    # SEIS RAICES como patas de araña: salen del tocon, suben a la rodilla y bajan clavadas al suelo.
    for i in range(6):
        a = (i + 0.5) / 6 * 2 * math.pi + (0.0 if i < 3 else 0.0)
        u = V((math.cos(a), math.sin(a), 0.0))
        b = V((0, 0, 9.0)) + u * 7.0
        rod = V((0, 0, 15.0)) + u * 14.0
        punta = V((0, 0, 0.3)) + u * 19.0
        _tubo(e, [b, rod, punta], [2.4, 1.7, 0.3], mat, 'pata%d' % i, 0.4)
        if ambar:
            _ambar_con_bichos(e, rod, (2.4, 2.4, 2.2), 1 if i % 2 else 0, 80 + i, 0.4)
    # Dos brazos flacos por delante, que agarran.
    for s in (-1, 1):
        g = 'brazo%d' % s
        mano = V((6.5 * s, 16.0, 6.0))
        _tubo(e, [(5.0 * s, 6.0, 15.0), (8.5 * s, 11.0, 13.0), mano], [1.6, 1.3, 1.1], mat, g, 0.4)
        _dedos(e, mano, (0.0, 1.0, -0.6), mat, 3, 4.5, 0.5, 1.1, g)
    return e.L


# ------------------------------------------------------------
#  CARNIVORO A -- FLOR
# ------------------------------------------------------------
def flor_cabeza(e, c, escala=1.0):
    # LA CABEZA ES UNA FLOR: dos coronas de petalos abiertas hacia delante alrededor de una BOCA llena de dientes.
    c = V(c, dtype=float)
    _elip(e, c, V((5.0, 3.6, 5.0)) * escala, 'garganta', 1.0, 'flor')
    _elip(e, c + V((0, 2.6, 0)) * escala, V((3.0, 1.0, 3.4)) * escala, 'hueco', 0, 'boca_flor')
    for anillo, (n, rd, lg, ra, fy) in enumerate(((9, 3.6, 10.5, 2.6, 0.4), (9, 2.6, 8.0, 2.0, 2.2))):
        for i in range(n):
            a = i / n * 2 * math.pi + anillo * 0.35
            u = V((math.cos(a), 0.0, math.sin(a)))
            a0 = c + (u * rd + V((0, fy, 0))) * escala
            a1 = c + (u * (rd + lg) + V((0, fy - 3.0 + anillo * 1.5, 1.2))) * escala
            _petalo(e, a0, a1, ra * escala, 0.6 * escala, mat='petalo' if anillo else 'capullo')
    for i in range(16):
        a = i / 16 * 2 * math.pi
        u = V((math.cos(a) * 3.1, 0.0, math.sin(a) * 3.5)) * escala
        b = c + u + V((0, 3.2, 0)) * escala
        _cono(e, b, b - u * 0.45 + V((0, 0.7, 0)), 0.45 * escala, 0.05, 'diente', 0, 'diente')


def latigo(e, base, dir_h, alto, largo, vueltas, r_fin):
    pts = _espiral(base, dir_h, alto, largo, vueltas, r_fin)
    _tubo(e, pts, list(np.linspace(1.3, 0.7, len(pts))), 'tallo', 'latigo', 0.3)
    for i in range(2, len(pts) - 2, 3):
        d = pts[i + 1] - pts[i]; d /= np.linalg.norm(d)
        fuera = np.cross(d, V((0, 1.0, 0))); fuera /= max(np.linalg.norm(fuera), 1e-6)
        fuera *= (1 if i % 2 else -1)
        _cono(e, pts[i], pts[i] + fuera * 1.4, 0.35, 0.05, 'tallo', 0, 'espina')
    punta = pts[-1]
    _elip(e, punta + V((0, 0, 2.0)), (2.6, 2.6, 3.4), 'capullo', 0.6, 'capullo')
    for k in range(4):
        a = k * math.pi / 2 + 0.4
        _cono(e, punta, punta + V((math.cos(a) * 1.9, math.sin(a) * 1.9, 2.4)), 0.7, 0.1, 'tallo', 0, 'capullo')


def flor():
    e = _Cuerpo()
    # Piernas de AVE: muslo hacia delante, tobillo hacia atras y pie de garras-petalo.
    for s in (-1, 1):
        g = 'pierna%d' % s
        pie = V((4.5 * s, 1.0, 1.2))
        _tubo(e, [(3.2 * s, -0.5, 20.0), (4.8 * s, 4.5, 13.0), (4.6 * s, -2.0, 6.0), pie], [2.6, 2.0, 1.5, 1.4],
              'planta', g, 0.5)
        for k in (-1, 0, 1):
            _petalo(e, pie, pie + V((k * 1.4, 3.6, -0.8)), 1.0, 0.1, 0.55, 'petalo', g, 2)
        _petalo(e, (4.8 * s, 4.8, 13.5), (5.4 * s, 6.5, 17.5), 1.6, 0.2, 0.5, 'petalo', g)     # en la rodilla
    # Un torso FLACO de tallos: cadera, cintura de avispa y pecho.
    eje = [(0, -0.5, 19.5), (0, 0.5, 25.0), (0, 1.5, 30.5), (0, 2.0, 33.5)]
    rad = [3.8, 2.8, 4.6, 4.8]
    _tubo(e, eje, rad, 'planta', 'cuerpo', 1.0)
    for (ang, t) in ((60, 0.75), (120, 0.75), (90, 0.4), (0, 0.85), (180, 0.85)):
        a0 = _sobre(eje, rad, t + 0.12, ang, -0.3); a1 = _sobre(eje, rad, t - 0.15, ang, 1.0)
        _petalo(e, a0, a1, 1.5, 0.3, 0.5, 'petalo', 'escama', 0 if ang in (0, 180) else 1)
    # Cuello largo y la FLOR de cabeza.
    _tubo(e, [(0, 2.0, 34.0), (0, 4.0, 38.0), (0, 5.5, 40.5)], [2.2, 1.8, 1.8], 'planta', 'cuerpo', 0.6)
    flor_cabeza(e, (0, 6.5, 42.0), 0.9)
    # Brazos flacos con manos de PETALOS-GARRA.
    for s in (-1, 1):
        g = 'brazo%d' % s
        mano = V((10.5 * s, 7.0, 20.0))
        _tubo(e, [(5.2 * s, 2.0, 33.0), (9.0 * s, 2.5, 26.5), mano], [2.0, 1.6, 1.6], 'planta', g, 0.5)
        _petalo(e, (5.6 * s, 1.5, 34.0), (8.0 * s, 0.0, 37.0), 2.0, 0.4, 0.5, 'petalo', g, 1)   # hombrera
        for k in (-1.2, 0.0, 1.2):
            _petalo(e, mano, mano + V((k * 1.2 + 0.6 * s, 3.8, -2.2)), 1.2, 0.08, 0.5, 'petalo', g, 0)
    # LATIGOS de espinas desde la espalda, con su capullo.
    for s in (-1, 1):
        latigo(e, V((2.5 * s, -2.5, 32.0)), V((0.9 * s, -0.5, 0.0)), 20.0, 13.0, 0.6, 4.5)
    return e.L


# ------------------------------------------------------------
#  CARNIVORO B -- FAUCES
# ------------------------------------------------------------
def fauces():
    e = _Cuerpo()
    # SIN PIERNAS: el tronco nace de una masa de RAICES gordas que se arquean y se clavan (con eso se arrastra).
    for i in range(9):
        a = i / 9 * 2 * math.pi + 0.2
        u = V((math.cos(a), math.sin(a), 0.0))
        b = V((0, 0, 6.0)) + u * 8.5
        arco = V((0, 0, 7.0)) + u * 13.5
        punta = V((0, 0, 0.3)) + u * (17.5 if math.sin(a) > -0.3 else 15.0)
        _tubo(e, [b, arco, punta], [3.4, 2.4, 0.6], 'corteza', 'raiz%d' % i, 0.6)
    eje = [(0, 0, 3.0), (0, 0.5, 13.0), (0, 1.0, 25.0), (0, 1.0, 35.0), (0, 0.5, 42.0)]
    rad = [11.0, 10.0, 9.4, 8.2, 6.4]
    _tubo(e, eje, rad, 'corteza', 'cuerpo', 2.0)
    for (a, t) in ((200, 0.4), (330, 0.6), (250, 0.75), (20, 0.3)):
        _elip(e, _sobre(eje, rad, t, a, -0.4), (1.5, 1.5, 2.0), 'hueco', 0, 'nudo')
    # LAS FAUCES: de arriba abajo por el frente, con colmillos largos arriba y abajo y la lengua-raiz colgando.
    c = _sobre(eje, rad, 0.5, 90, -1.8)
    _elip(e, c, (6.4, 2.8, 9.0), 'garganta', 0.6, 'fauces')
    _elip(e, c + V((0, 1.8, 0)), (4.8, 1.6, 7.4), 'hueco', 0, 'fauces')
    for i in range(8):
        x = -4.6 + i * 1.32
        lg = 4.4 if i in (1, 6) else 2.6 + 0.6 * (i % 2)
        top = c + V((x, 2.4, 7.0 - abs(x) * 0.6))
        _cono(e, top, top + V((x * 0.05, 0.6, -lg)), 0.75, 0.06, 'diente', 0, 'diente')
        bot = c + V((x, 2.4, -7.0 + abs(x) * 0.6))
        _cono(e, bot, bot + V((x * 0.05, 0.6, lg * 0.9)), 0.7, 0.06, 'diente', 0, 'diente')
    _tubo(e, [c + V((0, 1.8, -4.5)), c + V((0.8, 4.0, -6.5)), c + V((1.3, 5.2, -10.5)), c + V((0.9, 5.6, -13.0))],
          [1.3, 1.1, 0.8, 0.4], 'garganta', 'lengua', 0.3)
    # Los ojos, pequeños y altos, encima de la boca.
    _ojos(e, _sobre(eje, rad, 0.85, 90, -0.2), 2.0, 'ojo', (1.0, 0.5, 0.6), 'corteza')
    # LAS RAMAS COMO TENTACULOS: cuatro arriba que se enroscan y dos a los lados, a media altura, que agarran.
    for i, (b, h, alto, lg, vu, r, r0) in enumerate((((-3.5, 0, 41), (-1.0, 0.1, 0), 16.0, 16.0, 0.9, 5.0, 2.8),
                                                    ((3.5, 0, 41), (1.0, 0.1, 0), 18.0, 15.0, 1.0, 4.5, 2.8),
                                                    ((-1.5, -2.5, 43), (-0.4, -1.0, 0), 21.0, 10.0, 0.8, 4.0, 2.4),
                                                    ((2.0, -2.0, 43), (0.5, -1.0, 0), 13.0, 13.0, 1.1, 3.5, 2.2),
                                                    ((-8.0, 2.0, 28), (-1.0, 0.6, 0), 3.0, 18.0, 0.8, 4.0, 2.6),
                                                    ((8.0, 2.0, 28), (1.0, 0.6, 0), 3.0, 18.0, 0.8, 4.0, 2.6))):
        pts = _espiral(b, h, alto, lg, vu, r, 30)
        _tubo(e, pts, list(np.linspace(r0, 0.4, len(pts))), 'corteza', 'tentaculo%d' % i, 0.6)
    return e.L


# ------------------------------------------------------------
#  ASCUA (idea nueva, de 'ember soul')
# ------------------------------------------------------------
def _anillos(e, c, r, alto):
    # Una PLACA DE CENIZA con anillos de crecimiento marcados (el corte de un tronco).
    c = V(c, dtype=float)
    _elip(e, c, (r, r * 0.9, alto), 'ceniza', 0.6, 'ceniza')
    for rr in (r * 0.3, r * 0.58, r * 0.82):
        zz = alto * math.sqrt(max(0.0, 1 - (rr / r) ** 2))
        for k in range(12):
            a0 = k / 12 * 2 * math.pi; a1 = (k + 1) / 12 * 2 * math.pi
            p0 = c + V((math.cos(a0) * rr, math.sin(a0) * rr * 0.9, zz))
            p1 = c + V((math.cos(a1) * rr, math.sin(a1) * rr * 0.9, zz))
            _cono(e, p0, p1, 0.24, 0.24, 'carbon', 0, 'anillo')


def ascua():
    e = _Cuerpo()
    # Piernas cortas y GORDAS, abiertas, con garras.
    for s in (-1, 1):
        g = 'pierna%d' % s
        pie = V((9.0 * s, 1.0, 2.0))
        _tubo(e, [(5.5 * s, -2.0, 15.0), (9.5 * s, 2.5, 9.0), pie], [4.6, 4.0, 4.4], 'carbon', g, 1.0)
        _dedos(e, pie + V((0, 2.5, 0.5)), (0.0, 1.0, -0.2), 'ceniza', 3, 4.0, 0.9, 1.4, g)
    # El torso: cadera estrecha y un pecho ENORME echado hacia delante.
    eje = [(0, -2.0, 15.0), (0, 0.0, 20.5), (0, 3.0, 26.5), (0, 4.0, 31.0)]
    rad = [6.0, 7.0, 9.5, 9.0]
    _tubo(e, eje, rad, 'carbon', 'cuerpo', 2.0)
    _elip(e, (0, 3.0, 30.0), (15.0, 8.5, 6.5), 'carbon', 2.0, 'cuerpo')
    _grietas(e, eje, rad, (30, 150, 220, 320, 270), 'carbon', 'brasa', 61, 0.0, 0.9, 0.3)
    # EL CORAZON DE ASCUAS en el pecho.
    c = _sobre(eje, rad, 0.62, 90, -0.8)
    _elip(e, c, (5.0, 2.4, 5.0), 'brasa', 0, 'corazon')
    _elip(e, c + V((0, 1.2, 0.3)), (3.2, 1.8, 3.2), 'nucleo', 0, 'corazon')
    for j in range(8):
        a = j / 8 * 2 * math.pi
        _elip(e, c + V((math.cos(a) * 5.0, 1.0, math.sin(a) * 5.0)), (1.6, 1.2, 1.6), 'carbon', 0.5, 'borde')
    # La cabeza PEQUEÑA y baja entre los hombros, con la boca encendida y dos CUERNOS curvos negros con la punta al rojo.
    h = V((0, 10.5, 31.0))
    _elip(e, h, (3.6, 3.4, 3.4), 'carbon', 1.0, 'cuerpo')
    _ojos(e, h + V((0, 3.0, 0.8)), 1.4, 'brasa', (0.9, 0.5, 0.5))
    _elip(e, h + V((0, 3.2, -1.4)), (1.6, 0.5, 0.5), 'brasa', 0, 'boca')
    for s in (-1, 1):
        pts = [h + V((2.5 * s, 0, 2.0)), h + V((7.0 * s, -1.0, 5.0)), h + V((10.0 * s, -1.0, 9.5)),
               h + V((9.5 * s, 0.5, 14.0)), h + V((7.0 * s, 1.5, 16.0))]
        _tubo(e, pts, [1.8, 1.6, 1.3, 0.9, 0.3], 'carbon', 'cuerno%d' % s, 0.3)
        _cono(e, pts[3], pts[4], 0.95, 0.3, 'brasa', 0, 'cuerno%d' % s)
    # De la espalda, RAMAS NEGRAS que se retuercen como llamas, con la punta encendida.
    for i, (b, d) in enumerate((((-6, -4, 33), (-0.6, -0.6, 1.0)), ((6, -4, 33), (0.6, -0.6, 1.0)),
                                ((-2, -6, 31), (-0.2, -1.0, 0.8)), ((3, -6, 32), (0.3, -1.0, 0.9)))):
        _rama_seca(e, b, d, 13.0, 1.8, 90 + i * 3, 1, 'carbon', 'rama', True)
    # Brazos ENORMES hasta el suelo, con placas de ceniza en hombros y antebrazos y garras grandes.
    for s in (-1, 1):
        g = 'brazo%d' % s
        mano = V((16.0 * s, 12.0, 4.5))
        pts = [(13.0 * s, 3.5, 31.0), (18.0 * s, 5.0, 21.0), (17.0 * s, 9.0, 11.0), mano]
        rs = [5.6, 5.0, 4.6, 4.4]
        _tubo(e, pts, rs, 'carbon', g, 1.2)
        _grietas(e, pts, rs, (90, 0 if s > 0 else 180), 'carbon', 'brasa', 70 + s, 0.1, 0.9, 0.2)
        _anillos(e, (13.5 * s, 3.0, 34.5), 5.0, 2.6)
        _dedos(e, mano + V((0, 2.5, 0)), (0.1 * s, 1.0, -0.2), 'ceniza', 4, 5.0, 1.0, 1.3, g)
    return e.L


# ------------------------------------------------------------
VERSIONES = [
    ('trent hoy', lambda: _Cuerpo(True).L, ()),
    ('ambar A coloso', coloso_resina, ('ambar',)),
    ('ambar B relicario', relicario, ('ambar',)),
    ('marchito A espantajo', espantajo, ()),
    ('marchito B tocon', tocon_arana, ()),
    ('ambar C tocon', lambda: tocon_arana(True), ('ambar',)),
    ('carnivoro A flor', flor, ()),
    ('carnivoro B fauces', fauces, ()),
    ('ascua (nueva)', ascua, ()),
]


def modelo(translucidos):
    return Modelo(2.5, (420, 300), (210, 205), _mat(), (0.12, 0.06, 0.05), suaves=('cuerpo', 'musgo'),
                  brillan=BRILLAN, corta_suelo=True, especular=('ambar', 'savia_negra'), umbral_especular=0.9,
                  translucidos=translucidos, alfa=0.72)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    solo = sys.argv[1:]
    filas = []
    for nombre, fn, trans in VERSIONES:
        if solo and not any(s in nombre for s in solo):
            continue
        L = fn()
        mo = modelo(trans)
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
    nombre_png = 'trent_mutantes_versiones.png' if not solo else 'trent_mutantes_prueba.png'
    lam.save('tools/salida/sdf/' + nombre_png)
    if not solo:
        esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
        os.makedirs(esc, exist_ok=True)
        lam.save(os.path.join(esc, nombre_png))
        print(os.path.join(esc, nombre_png))
