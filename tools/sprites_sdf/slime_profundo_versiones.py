# ============================================================
#  slime_profundo_versiones.py -- el MUTANTE DEL SLIME PROFUNDO, propuestas (07/10/2026). Solo QUIETOS, al lado del
#  profundo de hoy (s150); el elegido pasa a slime_sdf.py como variante para animarlo.
#  Lo que eligio el jefe: UNA LINEA con dos aspectos, FONDO MARINO (agua) y HIELO/ESCARCHA. De cada uno, dos maneras:
#    - A1 FONDO MARINO CON CEBO: casi negro azulado, puntitos de luz por el cuerpo y un CEBO luminoso colgando delante
#      de una antena (el pez linterna).
#    - A2 FONDO MARINO CON FRANJAS: el mismo azul de fondo, sin cebo; las luces van en HILERAS (como los peces del fondo)
#      y un filo de luz por abajo.
#    - B1 ESCARCHA: gel azul hielo claro con una costra de ESCARCHA blanca en la cupula y CARAMBANOS cortos colgando de
#      donde se acaba.
#    - B2 MEDIO CONGELADO: el gel de dentro azul profundo y por fuera una CASCARA de hielo clara (translucida) en la mitad
#      de arriba, con su escarcha en el filo.
#  Uso: python tools/sprites_sdf/slime_profundo_versiones.py [salida.png]
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
os.environ['SLIME_VAR'] = 's150'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import slime_sdf as S

V = np.array
COLOR = '556a80'
ESC_NORMAL = 1.50
ESC_MUTANTE = 1.50 * 1.2
LIENZO, PIES = S._lienzo(ESC_MUTANTE * 1.4)


def _mats(color=COLOR):
    m = S._materiales('normal', color)
    c = S.hexc(color)
    m['gel'] = [S.osc(c, 0.30), c, S.cla(c, 0.28), S.cla(c, 0.62)]
    m['cuerno'] = m['gel']
    # EL FONDO DEL MAR: azul casi negro; LAS LUCES (cian) y EL CEBO (blanco verdoso), siempre en su luz.
    fondo = (0.03, 0.08, 0.16)
    m['fondo'] = [S.osc(fondo, 0.4), fondo, S.cla(fondo, 0.16), S.cla(fondo, 0.50)]
    m['luz'] = [(0.45, 0.95, 1.0)] * 3
    m['cebo'] = [(0.85, 1.0, 0.80)] * 3
    m['antena'] = [S.osc(fondo, 0.3), fondo, S.cla(fondo, 0.2)]
    # EL HIELO: el gel azul hielo claro, la ESCARCHA casi blanca y la CASCARA (muy clara, translucida).
    hielo = (0.45, 0.68, 0.86)
    m['hielo'] = [S.osc(hielo, 0.35), hielo, S.cla(hielo, 0.35), (0.97, 1.0, 1.0)]
    m['escarcha'] = [(0.62, 0.76, 0.88), (0.80, 0.90, 0.98), (0.94, 0.98, 1.0)]
    m['carambano'] = [(0.55, 0.75, 0.90), (0.78, 0.90, 1.0), (0.95, 1.0, 1.0)]
    m['cascara'] = [(0.30, 0.50, 0.70), (0.45, 0.66, 0.84), (0.66, 0.82, 0.95), (0.95, 1.0, 1.0)]
    hondo = (0.10, 0.22, 0.42)
    m['hondo'] = [S.osc(hondo, 0.35), hondo, S.cla(hondo, 0.25), S.cla(hondo, 0.55)]
    # EL MAR (el gel de los de coral): azul verdoso translucido; Y LOS CORALES, cada uno de su color.
    mar = (0.12, 0.38, 0.55)
    m['mar'] = [S.osc(mar, 0.35), mar, S.cla(mar, 0.28), S.cla(mar, 0.60)]
    m['coral_r'] = [(0.62, 0.20, 0.24), (0.92, 0.42, 0.40), (1.0, 0.66, 0.58)]
    m['coral_n'] = [(0.66, 0.36, 0.12), (0.94, 0.62, 0.24), (1.0, 0.82, 0.48)]
    m['coral_m'] = [(0.40, 0.20, 0.52), (0.62, 0.38, 0.78), (0.82, 0.62, 0.95)]
    m['coral_a'] = [(0.60, 0.52, 0.20), (0.86, 0.78, 0.38), (0.98, 0.94, 0.62)]
    m['anemona'] = [(0.20, 0.55, 0.40), (0.38, 0.85, 0.58), (0.70, 1.0, 0.78)]
    m['punta_a'] = [(0.95, 0.55, 0.80)] * 3
    m['parpado'] = m['gel'][:3]
    return m


def modelo(escala, translucidos=('gel', 'cuerno'), borde=None):
    c = S.hexc(COLOR)
    mo = Modelo(escala, LIENZO, PIES, _mats(), borde or S.osc(c, 0.58), suaves=('cuerpo',),
                brillan=('ojo', 'gema', 'luz', 'cebo', 'punta_a'),
                corta_suelo=True, especular=('gel', 'cuerno', 'fondo', 'hielo', 'cascara', 'hondo', 'mar'),
                umbral_especular=0.955, translucidos=translucidos, alfa=0.72)
    mo.alfa_dentro = 0.42
    mo.claros_dentro = ('cristal', 'nucleo', 'luz', 'cebo')
    mo.alfa_claro = 0.25
    return mo


def _base():
    C, R, _sz = S._forma(S.POSE())
    return Escena(S.huesos(S.POSE())), C, R


def _cuernos(e, C, R, mat='gel'):
    for s in (-1, 1):
        base, n = S._superficie((0.70 * s, 0.05, 0.72), C, R)
        raiz = base - n * 2.0
        medio = base + n * 2.6 + V([0.6 * s, 0.0, 3.0])
        punta = medio + V([-0.6 * s, 0.0, 3.6])
        e.add(lambda P, a=raiz, b=medio: sd_cono(P, a, b, 4.4, 2.4), mat, 1.8)
        e.add(lambda P, a=medio, b=punta: sd_cono(P, a, b, 2.4, 0.9), mat, 1.0)


def _ojos(e, C, R):
    for x in (-0.33, 0.33):
        base, n = S._superficie((x, 0.88, 0.34), C, R)
        c = base + n * 0.05
        rad = V([2.3, 3.0, 5.0])
        e.add(lambda P, c=c, rad=rad: np.maximum(sd_elipsoide(P, c, rad), sd_elipsoide(P, C, R) - 0.3), 'ojo', 0, 'ojo')


def _luz(e, p, r):
    e.add(lambda P, p=p, r=r: sd_esfera(P, p, r), 'luz', 0, 'luz')


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def profundo_hoy():
    return S.escena(S.POSE())


# A1) FONDO MARINO CON CEBO: el azul casi negro, puntitos de luz sueltos (dentro y en la piel) y la ANTENA que sale de la
# coronilla, se curva hacia delante y cuelga el CEBO delante de la cara.
def marino_cebo():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'fondo', 0)
    rng = np.random.default_rng(11)
    for i in range(22):
        d = rng.normal(size=3); d[2] = abs(d[2]) * 0.8 - 0.1; d /= np.linalg.norm(d)
        _luz(e, C + d * R * rng.uniform(0.80, 0.97), rng.uniform(0.7, 1.1))
    _cuernos(e, C, R, 'fondo')
    _ojos(e, C, R)
    # LA ANTENA: tres tramos que salen de arriba y caen por delante
    raiz, n = S._superficie((0.0, 0.25, 0.97), C, R)
    p1 = raiz + V([0.0, 2.5, 7.0])
    p2 = p1 + V([0.0, 7.0, 2.0])
    p3 = p2 + V([0.0, 4.0, -4.5])
    for a, b, ra, rb in ((raiz - n * 1.0, p1, 1.6, 1.1), (p1, p2, 1.1, 0.85), (p2, p3, 0.85, 0.7)):
        e.add(lambda P, a=a, b=b, ra=ra, rb=rb: sd_cono(P, a, b, ra, rb), 'antena', 0.6)
    e.add(lambda P, c=p3 + V([0.0, 0.0, -1.2]): sd_esfera(P, c, 2.6), 'cebo', 0, 'cebo')
    return e.L


# A2) FONDO MARINO CON FRANJAS: sin cebo; las luces en HILERAS que bajan por los costados (los meridianos) y un FILO de
# luz en la base, como los peces del fondo.
def marino_franjas():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'fondo', 0)
    for k in range(7):
        a = k / 7.0 * 2 * math.pi + 0.35
        for j in range(5):
            z = 0.62 - j * 0.17
            rr = math.sqrt(max(0.0, 1.0 - z * z))
            d = V([math.cos(a) * rr, math.sin(a) * rr, z])
            p, n = S._superficie(tuple(d), C, R)
            _luz(e, p - n * 0.2, 0.75 - j * 0.06)
    for k in range(18):
        a = k / 18.0 * 2 * math.pi
        p, n = S._superficie((math.cos(a) * 0.98, math.sin(a) * 0.98, -0.12), C, R)
        _luz(e, p - n * 0.2, 0.55)
    _cuernos(e, C, R, 'fondo')
    _ojos(e, C, R)
    return e.L


# LA ESCARCHA: una costra un pelo por fuera del cuerpo, solo por encima de 'z0' (con el filo ondulado), y carambanos
# cortos colgando del filo.
def _escarcha(e, C, R, z0=0.45, carambanos=9, semilla=5, costra=True):
    zc = C[2] + R[2] * z0
    def costra_fn(P):
        ang = np.arctan2(P[:, 1] - C[1], P[:, 0] - C[0])
        filo = zc + R[2] * 0.08 * np.sin(ang * 7.0) + R[2] * 0.05 * np.sin(ang * 13.0 + 1.0)
        D = (P - C) / R
        # A PARCHES (no una capucha entera): un ruido sobre la direccion; y la CARA libre (los ojos se tienen que ver)
        ruido = (np.sin(D[:, 0] * 7.0 + D[:, 2] * 3.0) + np.sin(D[:, 1] * 6.0 - D[:, 0] * 4.0 + 1.3) +
                 np.sin(D[:, 2] * 9.0 + D[:, 1] * 2.0 + 0.7))
        parche = (0.2 - ruido) * 3.0
        cara = (0.40 - np.sqrt((D[:, 0] / 1.0) ** 2 + ((D[:, 2] - 0.32) / 0.6) ** 2)) * 8.0
        cara = np.where(D[:, 1] > 0.3, cara, -9.0)
        return np.maximum(np.maximum(np.maximum(sd_elipsoide(P, C, R + 0.45), (filo - P[:, 2]) * 0.8), parche), cara)
    if costra:
        e.add(costra_fn, 'escarcha', 0, 'escarcha')
    rng = np.random.default_rng(semilla)
    for k in range(carambanos):
        a = k / carambanos * 2 * math.pi + rng.uniform(-0.2, 0.2)
        if math.sin(a) > 0.75:
            continue   # (delante de los ojos no)
        zz = z0 + 0.08 * math.sin(a * 7.0) + 0.05 * math.sin(a * 13.0 + 1.0) - 0.02
        rr = math.sqrt(max(0.0, 1.0 - zz * zz))
        base, n = S._superficie((math.cos(a) * rr, math.sin(a) * rr, zz), C, R)
        largo = rng.uniform(2.2, 3.8)
        punta = base + n * 0.6 + V([0.0, 0.0, -largo])
        e.add(lambda P, a=base + n * 0.3, b=punta, r=rng.uniform(0.8, 1.1): sd_cono(P, a, b, r, 0.1),
              'carambano', 0, 'carambano')


# B1) ESCARCHA: gel azul hielo claro, costra blanca en la cupula y carambanos.
def escarcha():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'hielo', 0)
    _cuernos(e, C, R, 'hielo')
    _escarcha(e, C, R)
    _ojos(e, C, R)
    return e.L


# B2) MEDIO CONGELADO: dentro el gel azul hondo; por fuera, en la mitad de arriba, una CASCARA de hielo gruesa y clara
# (se ve el gel a traves) con escarcha en el filo de abajo.
def congelado():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'hondo', 0)
    zc = C[2] + R[2] * 0.15
    def cascara(P):
        ang = np.arctan2(P[:, 1] - C[1], P[:, 0] - C[0])
        filo = zc + R[2] * 0.10 * np.sin(ang * 5.0 + 0.5)
        fuera = sd_elipsoide(P, C, R + 1.1)
        return np.maximum(np.maximum(fuera, -(sd_elipsoide(P, C, R) - 0.1)), (filo - P[:, 2]) * 0.8)
    e.add(cascara, 'cascara', 0, 'cascara')
    _cuernos(e, C, R, 'cascara')
    _escarcha(e, C, R + 1.1, z0=0.15, carambanos=8, semilla=8, costra=False)
    _ojos(e, C, R + 1.4)
    return e.L


# ------------------------------------------------------------
#  LOS DE CORAL (07/10, su diagnostico: "de el marino no me convence ninguno; ¿podemos hacer que sea mas coraloso?")
# ------------------------------------------------------------
def _rama(e, a, d, largo, r, mat, nivel, rng):
    """Un coral RAMIFICADO: un tramo y de su punta dos (o tres) mas finos que se abren hacia arriba."""
    d = d / np.linalg.norm(d)
    b = a + d * largo
    e.add(lambda P, a=a, b=b, ra=r, rb=r * 0.8: sd_cono(P, a, b, ra, rb), mat, 0.5, 'coral')
    if nivel == 0:
        e.add(lambda P, c=b, rr=r * 0.95: sd_esfera(P, c, rr), mat, 0, 'coral')
        return
    for k in range(2 if rng.random() < 0.6 else 3):
        lado = rng.normal(size=3); lado[2] = 0.0
        nd = d + lado * 0.7 + V([0.0, 0.0, 0.35])
        _rama(e, b, nd, largo * rng.uniform(0.65, 0.8), r * 0.75, mat, nivel - 1, rng)


def _cerebro(e, C, R, d, rad, mat):
    """Un coral CEREBRO: una media bola sobre la piel con surcos serpenteantes."""
    base, n = S._superficie(d, C, R)
    c = base - n * rad * 0.35
    def f(P, c=c, rad=rad):
        q = (P - c) / rad
        surco = np.sin(q[:, 0] * 9.0 + np.sin(q[:, 1] * 7.0) * 1.6) * np.sin(q[:, 1] * 8.0 + q[:, 2] * 3.0)
        return sd_esfera(P, c, rad) + 0.35 * np.clip(surco, 0.0, 1.0)
    e.add(f, mat, 0, 'coral')


def _tubos(e, C, R, d, n_tubos, mat, rng):
    """Un racimo de corales de TUBO: cilindros cortos, huecos por arriba."""
    base, n = S._superficie(d, C, R)
    for i in range(n_tubos):
        off = rng.normal(size=3) * 2.2; off -= n * (off @ n)
        a = base + off - n * 0.8
        b = a + (n + rng.normal(size=3) * 0.2) * rng.uniform(4.0, 6.5)
        r = rng.uniform(1.2, 1.6)
        def f(P, a=a, b=b, r=r):
            tubo = sd_cono(P, a, b, r, r)
            hueco = sd_cono(P, a + (b - a) * 0.5, b + (b - a) * 0.3, r * 0.55, r * 0.55)
            return np.maximum(tubo, -hueco)
        e.add(f, mat, 0, 'coral')


def _anemona(e, C, R, d, mat, rng, n_brazos=11):
    """Una ANEMONA: un pie corto y una corona de tentaculos finos con la punta rosa."""
    base, n = S._superficie(d, C, R)
    pie = base + n * 2.4
    e.add(lambda P, a=base - n * 0.5, b=pie: sd_cono(P, a, b, 2.4, 2.0), mat, 0.4, 'coral')
    for k in range(n_brazos):
        lado = rng.normal(size=3); lado -= n * (lado @ n); lado /= np.linalg.norm(lado)
        dd = n * 0.9 + lado * 0.6 + V([0.0, 0.0, 0.3])
        dd /= np.linalg.norm(dd)
        punta = pie + dd * rng.uniform(3.6, 5.2)
        e.add(lambda P, a=pie, b=punta: sd_cono(P, a, b, 0.75, 0.5), mat, 0, 'coral')
        e.add(lambda P, c=punta: sd_esfera(P, c, 0.75), 'punta_a', 0, 'coral')


# C1) CUERNOS DE CORAL: el gel del mar, y en vez de cuernos dos CORALES RAMIFICADOS (rojo coral) que le salen de la
# cabeza; algun brote pequeño mas por la cupula.
def coral_cuernos():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'mar', 0)
    rng = np.random.default_rng(4)
    for s_ in (-1, 1):
        base, n = S._superficie((0.62 * s_, 0.0, 0.78), C, R)
        _rama(e, base - n * 1.2, n + V([0.3 * s_, 0.0, 0.9]), 6.0, 2.3, 'coral_r', 2, rng)
    for d in ((-0.2, -0.6, 0.78), (0.75, -0.45, 0.45)):
        base, n = S._superficie(d, C, R)
        _rama(e, base - n * 0.8, n + V([0.0, 0.0, 0.6]), 3.6, 1.5, 'coral_r', 1, rng)
    _ojos(e, C, R)
    return e.L


# C2) ARRECIFE: el gel del mar con un trozo de arrecife encima: un CORAL CEREBRO (amarillo), un racimo de TUBOS
# (morado), una ANEMONA (verde con las puntas rosas) y una ramita roja. Conserva sus cuernos.
def coral_arrecife():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'mar', 0)
    _cuernos(e, C, R, 'mar')
    rng = np.random.default_rng(9)
    _cerebro(e, C, R, (-0.30, -0.20, 0.92), 5.8, 'coral_a')
    _tubos(e, C, R, (0.55, -0.35, 0.70), 5, 'coral_m', rng)
    _anemona(e, C, R, (0.20, 0.25, 0.94), 'anemona', rng)
    base, n = S._superficie((-0.80, 0.10, 0.45), C, R)
    _rama(e, base - n * 0.8, n + V([0.0, 0.0, 0.7]), 4.4, 1.7, 'coral_r', 1, rng)
    _ojos(e, C, R)
    return e.L


# C3) COSTRA DE ARRECIFE: la mitad de arriba cubierta de coral a PARCHES (naranja, con bultos) por donde asoma el gel;
# de la costra le salen ramas, tubos y una anemona. El que mas "roca de mar" parece.
def coral_costra():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'mar', 0)
    def costra(P):
        D = (P - C) / R
        ruido = (np.sin(D[:, 0] * 6.0 + D[:, 2] * 4.0) + np.sin(D[:, 1] * 5.0 - D[:, 0] * 3.0 + 2.1) +
                 np.sin(D[:, 2] * 8.0 + D[:, 1] * 3.0 + 0.4))
        bultos = 0.35 * np.sin(D[:, 0] * 14.0) * np.sin(D[:, 1] * 14.0) * np.sin(D[:, 2] * 14.0)
        cara = (0.40 - np.sqrt((D[:, 0] / 1.0) ** 2 + ((D[:, 2] - 0.32) / 0.6) ** 2)) * 8.0
        cara = np.where(D[:, 1] > 0.3, cara, -9.0)
        return np.maximum(np.maximum(np.maximum(sd_elipsoide(P, C, R + 0.6) + bultos, (0.1 - D[:, 2]) * 8.0),
                                     (0.5 - ruido) * 3.0), cara)
    e.add(costra, 'coral_n', 0, 'coral')
    _cuernos(e, C, R, 'coral_n')
    rng = np.random.default_rng(6)
    _tubos(e, C, R, (-0.55, -0.40, 0.70), 4, 'coral_m', rng)
    base, n = S._superficie((0.45, -0.30, 0.82), C, R)
    _rama(e, base - n * 0.8, n + V([0.2, 0.0, 0.8]), 4.6, 1.8, 'coral_r', 2, rng)
    _anemona(e, C, R, (0.85, 0.20, 0.25), 'anemona', rng, 9)
    _ojos(e, C, R)
    return e.L


_MAR = {'translucidos': ('mar',), 'borde': (0.03, 0.10, 0.16)}

FILAS = [
    ('profundo hoy', ESC_NORMAL, profundo_hoy, {}),
    ('C1 coral cuernos', ESC_MUTANTE, coral_cuernos, _MAR),
    ('C2 arrecife', ESC_MUTANTE, coral_arrecife, _MAR),
    ('C3 costra coral', ESC_MUTANTE, coral_costra, _MAR),
    ('B1 escarcha', ESC_MUTANTE * 1.1, escarcha, {'translucidos': ('hielo',), 'borde': (0.16, 0.26, 0.38)}),
]


def _lamina(filas, sal, esc=3):
    W, H = filas[0][1][0].size
    y_ini, y_fin = H, 0
    for _, fotos in filas:
        for f in fotos:
            bb = f.getbbox()
            if bb:
                y_ini = min(y_ini, bb[1]); y_fin = max(y_fin, bb[3])
    y_ini = max(0, y_ini - 3); y_fin = min(H, y_fin + 3); h = y_fin - y_ini
    IZQ = 110
    n = max(len(f) for _, f in filas)
    lam = Image.new('RGB', (W * n + IZQ, h * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * h + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            fc = f.crop((0, y_ini, f.size[0], y_fin))
            lam.paste(fc, (IZQ + i * W, j * h), fc)
    lam.resize((lam.width * esc, lam.height * esc), Image.NEAREST).save(sal)
    print(sal)


if __name__ == '__main__':
    sal = sys.argv[1] if len(sys.argv) > 1 else 'tools/salida/sdf/slime_profundo_versiones.png'
    os.makedirs(os.path.dirname(sal), exist_ok=True)
    filas = []
    for nombre, esc, fn, extra in FILAS:
        mo = modelo(esc, **extra)
        filas.append((nombre, [render(mo, fn(), d) for d in range(5)]))
        print(nombre, 'ok')
    _lamina(filas, sal)
