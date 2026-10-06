# ============================================================
#  slime_abisal_versiones.py -- el MUTANTE DEL SLIME ABISAL, propuestas (06/10/2026). Solo QUIETOS, al lado del abisal de
#  hoy (s170); el elegido pasa a slime_sdf.py como variante para animarlo.
#  Lo que pidio el jefe: ver dibujadas estas (el arbol y las pasivas, "tras verlo"), y luego sus REFERENCIAS (ojos en
#  almendra con el blanco encendido e iris neon; sombras negras con ojos blancos y sonrisa de dientes; una llama azul y
#  negra con estrellas y un corazon blanco):
#    - A CIELO DE NOCHE: azul noche translucido con las estrellas brillando dentro (alguna con su cruz de luz).
#    - B MUCHOS OJOS: ojos de verdad por todo el cuerpo (almendra, blanco, iris verde o magenta, pupila), alguno entornado.
#    - C FUEGO NEGRO: "un fuego negro que se vea literal fuego con animacion como las antorchas" (en el de fuego no, que es
#      lava; en este si). El cuerpo de noche con estrellas y un corazon blanco dentro; las LLAMAS se pintan encima, una
#      silueta que cambia poco de un fotograma a otro (ver LlamaAltar), no particulas. Lleva una TIRA aparte.
#    - D LA SOMBRA QUE SONRIE: cuerpo negro, ojos blancos que brillan y una sonrisa de dientes grandes y dentados.
#  Uso: python tools/sprites_sdf/slime_abisal_versiones.py [salida.png]
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
os.environ['SLIME_VAR'] = 's170'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import slime_sdf as S

V = np.array
COLOR = '556faa'
ESC_NORMAL = 1.70
ESC_MUTANTE = 1.70 * 1.2
LIENZO, PIES = S._lienzo(ESC_MUTANTE * 1.4)


def _mats(color=COLOR):
    m = S._materiales('normal', color)
    c = S.hexc(color)
    m['gel'] = [S.osc(c, 0.30), c, S.cla(c, 0.28), S.cla(c, 0.62)]
    m['cuerno'] = m['gel']
    # EL CIELO: el gel azul noche; LAS ESTRELLAS, blancas y azuladas (siempre en su luz).
    noche = (0.08, 0.09, 0.24)
    m['noche'] = [S.osc(noche, 0.4), noche, S.cla(noche, 0.18), S.cla(noche, 0.55)]
    m['estrella'] = [(0.80, 0.88, 1.0), (0.92, 0.96, 1.0), (1.0, 1.0, 1.0)]
    m['parpado'] = m['gel'][:3]
    # LOS OJOS de verdad: el blanco encendido, los iris neon (verde y magenta) y la pupila negra.
    m['blanco'] = [(1.0, 1.0, 0.97)] * 3
    m['iris_v'] = [(0.45, 1.0, 0.45)] * 3
    m['iris_m'] = [(1.0, 0.35, 0.95)] * 3
    m['iris_c'] = [(0.30, 0.95, 1.0)] * 3
    m['iris_a'] = [(1.0, 0.92, 0.25)] * 3
    m['iris_n'] = [(1.0, 0.55, 0.15)] * 3
    m['iris_r'] = [(1.0, 0.25, 0.30)] * 3
    m['iris_p'] = [(0.65, 0.45, 1.0)] * 3
    m['pupila'] = [(0.02, 0.02, 0.04)] * 3
    # EL CORAZON DE LUZ del fuego negro (blanco azulado, siempre en su luz).
    m['corazon_luz'] = [(0.85, 0.90, 1.0)] * 3
    # LA SOMBRA QUE SONRIE: el cuerpo negro, la boca y los dientes.
    m['sombra'] = [(0.02, 0.02, 0.03), (0.05, 0.05, 0.07), (0.12, 0.12, 0.16), (0.30, 0.30, 0.36)]
    m['boca'] = [(0.0, 0.0, 0.0)] * 3
    m['diente'] = [(0.86, 0.86, 0.84), (0.97, 0.97, 0.95), (1.0, 1.0, 1.0)]
    return m


def modelo(escala, translucidos=('gel', 'cuerno'), noche=False):
    c = S.hexc(COLOR)
    mo = Modelo(escala, LIENZO, PIES, _mats(), (0.02, 0.02, 0.06) if noche else S.osc(c, 0.58), suaves=('cuerpo',),
                brillan=('ojo', 'gema', 'estrella', 'blanco', 'iris_v', 'iris_m', 'iris_c', 'iris_a', 'iris_n', 'iris_r',
                         'iris_p', 'corazon_luz'),
                corta_suelo=True, especular=('gel', 'cuerno', 'noche', 'sombra'), umbral_especular=0.955,
                translucidos=translucidos, alfa=0.72)
    mo.alfa_dentro = 0.42
    mo.claros_dentro = ('cristal', 'nucleo', 'estrella', 'corazon_luz')
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


def _ojo(e, C, R, x, y, z, k=1.0):
    base, n = S._superficie((x, y, z), C, R)
    c = base + n * 0.05
    rad = V([2.3, 3.0, 5.0]) * k
    e.add(lambda P, c=c, rad=rad: np.maximum(sd_elipsoide(P, c, rad), sd_elipsoide(P, C, R) - 0.3), 'ojo', 0, 'ojo')


# UN OJO DE VERDAD (sus referencias): una LENTE (dos esferas cruzadas, la almendra) aplanada contra la piel, con su iris
# y su pupila encima. 'abierto' 0..1 lo entorna (la almendra se estrecha de arriba abajo).
def _ojo_almendra(e, C, R, d, tam, iris='iris_v', abierto=1.0, giro=0.0):
    """'giro' (radianes) = lo TORCIDO que esta: la almendra gira sobre la piel (06/10: "ni rectos, puestos random")."""
    base, n = S._superficie(d, C, R)
    up = V([0.0, 0.0, 1.0]) - n * n[2]
    up = up / max(np.linalg.norm(up), 1e-6)
    up = up * math.cos(giro) + np.cross(n, up) * math.sin(giro)
    c = base + n * 0.25
    sep = tam * (0.55 + 0.4 * (1.0 - abierto))
    rr = tam * 1.05
    def lente(P, c=c, up=up, n=n, sep=sep, rr=rr):
        d1 = np.maximum(sd_esfera(P, c + up * sep, rr), sd_esfera(P, c - up * sep, rr))
        return np.maximum(d1, np.abs((P - c) @ n) - 0.55)
    e.add(lente, 'blanco', 0, 'ojo_blanco')
    if iris != 'blanco' and abierto > 0.2:
        ci = c + n * 0.5
        ri = min(tam * 0.48, (rr - sep) * 0.95)
        e.add(lambda P, ci=ci, n=n, r=ri: np.maximum(sd_esfera(P, ci, r), np.abs((P - ci) @ n) - 0.35), iris, 0, 'iris')
        cp = c + n * 0.85
        e.add(lambda P, cp=cp, n=n, r=ri * 0.45: np.maximum(sd_esfera(P, cp, r), np.abs((P - cp) @ n) - 0.3),
              'pupila', 0, 'pupila')


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def abisal_hoy():
    return S.escena(S.POSE())


def _estrellas(e, C, R, n, semilla, grandes=0):
    rng = np.random.default_rng(semilla)
    for i in range(n):
        d = rng.normal(size=3); d /= np.linalg.norm(d)
        p = C + d * R * rng.uniform(0.3, 0.85)
        grande = i >= n - grandes
        e.add(lambda P, p=p, r=1.1 if grande else 0.6: sd_esfera(P, p, r), 'estrella', 0, 'estrella')
        if grande:
            for ej in (V([1.0, 0.0, 0.0]), V([0.0, 0.0, 1.0])):
                e.add(lambda P, a=p - ej * 2.6, b=p + ej * 2.6: sd_cono(P, a, b, 0.35, 0.35), 'estrella', 0, 'estrella')


# A) CIELO DE NOCHE: un trozo de cielo: azul noche TRANSLUCIDO y dentro las ESTRELLAS (alguna con su cruz de luz).
def cielo():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'noche', 0)
    _estrellas(e, C, R, 30, 3, grandes=5)
    _cuernos(e, C, R, 'noche')
    for x in (-0.33, 0.33):
        _ojo(e, C, R, x, 0.88, 0.34)
    return e.L


# B) MUCHOS OJOS (su diagnostico, 06/10): repartidos AL AZAR por todo el slime (tambien a los lados y detras), de
# tamaños MEZCLADOS (no los grandes delante), TORCIDOS y con iris de MUCHOS colores; cada uno parpadea por su cuenta
# ('cerrados' = los que estan cerrados en este fotograma).
IRIS = ['iris_v', 'iris_m', 'iris_c', 'iris_a', 'iris_n', 'iris_r', 'iris_p']

def _ojos_al_azar(n=18, semilla=21):
    # (06/10, su diagnostico: "es calvo de ojos por detras": al azar sin mas dejaba huecos. Ahora un punto por zona,
    # REPARTIDOS PAREJO por toda la cupula (espiral de Fibonacci) y movido al azar, con tamaño, giro y color al azar.)
    rng = np.random.default_rng(semilla)
    ojos = []
    m = int(n / 0.78)
    for i in range(m):
        z = 1.0 - 2.0 * (i + 0.5) / m
        if z < -0.15:
            continue   # por debajo no se ve
        rr = math.sqrt(max(0.0, 1.0 - z * z))
        ang = 2.399963 * i
        d = V([rr * math.cos(ang), rr * math.sin(ang), z]) + rng.normal(0.0, 0.12, 3)
        d /= np.linalg.norm(d)
        tam = rng.uniform(1.8, 4.2)
        ojos.append((tuple(d), tam, IRIS[rng.integers(len(IRIS))], rng.uniform(-0.7, 0.7),
                     1.0 if rng.random() > 0.25 else rng.uniform(0.45, 0.7)))
    return ojos


OJOS = _ojos_al_azar()


def ojos(cerrados=()):
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    _cuernos(e, C, R)
    for i, (d, tam, iris, giro, ab) in enumerate(OJOS):
        _ojo_almendra(e, C, R, d, tam, iris, 0.08 if i in cerrados else ab, giro)
    return e.L


# C) FUEGO NEGRO: el cuerpo de noche con estrellas y un CORAZON blanco que brilla dentro; las LLAMAS se pintan encima
# (llamas_2d), fotograma a fotograma como las antorchas.
def fuego_negro():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'noche', 0)
    _estrellas(e, C, R, 14, 8)
    e.add(lambda P, c=C + V([1.5, 2.0, -0.5]): sd_esfera(P, c, 3.6), 'corazon_luz', 0, 'corazon')
    _cuernos(e, C, R, 'noche')
    for x in (-0.33, 0.33):
        _ojo(e, C, R, x, 0.88, 0.34)
    return e.L


# D) LA SOMBRA QUE SONRIE: cuerpo NEGRO, ojos blancos grandes que brillan y una SONRISA de lado a lado: la boca negra
# pintada en la piel y los DIENTES (conos blancos, desiguales) de arriba y de abajo.
def sonrisa():
    e, C, R = _base()
    R = R * V([1.05, 1.05, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'sombra', 0)
    _cuernos(e, C, R, 'sombra')
    for x in (-0.38, 0.38):
        _ojo_almendra(e, C, R, (x, 0.80, 0.58), 4.6, 'blanco', 0.75)
    zc = C[2] + 1.8
    def boca(P):
        mascara = (np.sqrt((P[:, 0] / 11.5) ** 2 + ((P[:, 2] - zc) / 4.2) ** 2) - 1.0) * 3.0
        frente = C[1] - P[:, 1]
        return np.maximum(np.maximum(sd_elipsoide(P, C, R + 0.2), mascara), frente)
    e.add(boca, 'boca', 0, 'boca')
    rng = np.random.default_rng(4)
    for i in range(7):
        x = -8.4 + i * 2.8
        for arriba in (True, False):
            z = zc + (3.6 if arriba else -3.4) * math.sqrt(max(0.0, 1.0 - (x / 11.5) ** 2))
            base, n = S._superficie((x, 40.0, z - C[2]), C, R)
            largo = rng.uniform(2.6, 3.8)
            punta = base + n * 0.5 + V([rng.uniform(-0.3, 0.3), 0.0, -largo if arriba else largo])
            e.add(lambda P, a=base + n * 0.35, b=punta, r=rng.uniform(1.15, 1.4): sd_cono(P, a, b, r, 0.12),
                  'diente', 0, 'diente')
    return e.L


# LAS LLAMAS NEGRAS (C), pintadas encima del sprite: lenguas a lo largo de la parte de arriba del cuerpo, cada una en tres
# capas (el borde azul marino casi negro, el indigo, y una raya azul clara en el lado de la luz) con alguna estrella. Una
# silueta que cambia poco: la base quieta en el cuerpo y la punta meciendose; el ultimo fotograma casa con el primero.
# LAS LLAMAS NEGRAS (C) con PARTICULAS (su diagnostico, 06/10: la silueta plana "parece un png guarro detras; hazlo con
# particulas"). Salen de TODO el borde de arriba y los lados del cuerpo (y unas pocas por delante de la cupula), suben
# meciendose, encogen y cambian de color con la edad: corazon azul claro -> indigo -> casi negro, y se apagan. Cada
# particula da 1 o 2 vueltas enteras por ciclo, asi que la tira de fotogramas casa al final.
# (mas NEGRO que azul: el azul claro solo en el corazon, recien nacida)
FUEGO_COL = [(0.0, (165, 185, 255)), (0.1, (95, 100, 220)), (0.3, (48, 38, 125)), (0.55, (20, 15, 52)),
             (1.0, (8, 6, 20))]

def _col_fuego(u):
    for (a, ca), (b, cb) in zip(FUEGO_COL, FUEGO_COL[1:]):
        if u <= b:
            k = (u - a) / (b - a)
            return tuple(round(ca[i] + (cb[i] - ca[i]) * k) for i in range(3))
    return FUEGO_COL[-1][1]


def _borde_arriba(a):
    """Puntos del borde del cuerpo (la mitad de arriba): por columnas, el primer pixel opaco; y los lados."""
    H, W = a.shape
    pts = []
    ys, xs = np.nonzero(a > 0)
    y0, y1 = ys.min(), ys.max()
    corte = y0 + (y1 - y0) * 0.62
    for x in range(xs.min(), xs.max() + 1):
        col = np.nonzero(a[:, x] > 0)[0]
        if len(col) and col[0] < corte:
            pts.append((x, col[0], 0.0))
    for y in range(int(y0), int(corte)):
        fila = np.nonzero(a[y] > 0)[0]
        if len(fila):
            pts.append((fila[0], y, -1.0)); pts.append((fila[-1], y, 1.0))
    return pts, (xs.min(), xs.max(), y0, y1)


def llamas_2d(img, t, n=190, semilla=5):
    return llamas_campo(img, t)


# EL FUEGO NEGRO COMO UNA SOLA LLAMA (06/10, su diagnostico de las particulas: "no parece fuego"; su referencia: una masa
# azul marino que FLUYE, con vetas curvas mas claras por dentro, puntas que se rizan y el corazon blanco). Un CAMPO de
# fuego sobre la cupula: alto donde nace (la mitad de arriba del cuerpo) y bajando hacia arriba y a los lados, retorcido
# por un ruido que SUBE con el tiempo (la fase da la vuelta entera: el ultimo fotograma casa con el primero). Se pinta
# POR BANDAS, como el pixel art: el borde casi negro, la masa azul marino, y las VETAS (indigo y azul claro) donde el
# campo cruza ciertos valores; mas arriba, jirones sueltos.
def llamas_campo(img, t, alto=0.85, ladeo=0.14):
    # (06/10, su diagnostico: "se ve poco natural": era una capucha pegada, con la base en raya recta, un solo bloque en
    # triangulo y las vetas en curvas de nivel. Ahora: la BASE ondula y vive, son VARIAS LENGUAS de alturas distintas que
    # suben a destiempo, las vetas son HEBRAS que suben y el canto que da a la luz se ilumina, como en su referencia.)
    a = np.asarray(img)[:, :, 3].astype(float) / 255.0
    H, W = a.shape
    ys, xs = np.nonzero(a > 0.5)
    if len(xs) == 0:
        return img
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    h = float(y1 - y0)
    cx = (x0 + x1) / 2.0
    rx = (x1 - x0) / 2.0
    techo = np.full(W, np.nan)
    for x in range(int(x0), int(x1) + 1):
        col = np.nonzero(a[:, x] > 0.5)[0]
        if len(col):
            techo[x] = col[0]
    idx = np.arange(W)
    ok = ~np.isnan(techo)
    techo = np.interp(idx, idx[ok], techo[ok])
    Y, X = np.mgrid[0:H, 0:W].astype(float)
    T = 2.0 * math.pi * t
    k = 1.0 / max(h, 1.0)
    # LA BASE, ondulada y viva (no una raya): cada columna nace a su altura, que sube y baja
    nace = techo[None, :] + h * (0.26 + 0.08 * np.sin(X * k * 15.0 - 2 * T) + 0.04 * np.sin(X * k * 31.0 + 3 * T))
    # LAS LENGUAS: el alto de la llama cambia por columnas (varias puntas) y esas puntas suben y bajan a destiempo
    lenguas = 0.45 + 0.55 * (0.5 + 0.5 * np.sin(X * k * 12.0 + T + 1.2 * np.sin(X * k * 5.0 - T)))
    Hf = h * alto * lenguas
    v = (nace - Y) / Hf
    u = (X - cx - ladeo * h * np.clip(v, 0, 1) ** 1.5) / (rx * (1.08 - 0.4 * np.clip(v, 0, 1)))
    ancho = np.clip(1.0 - u * u, 0.0, 1.0)
    Xw = X + h * 0.08 * np.sin(Y * k * 9.0 + T) + h * 0.04 * np.sin(Y * k * 17.0 - X * k * 5.0 + 2 * T)
    ruido = (0.55 * np.sin(Xw * k * 11.0 + Y * k * 7.0 + T) +
             0.35 * np.sin(Xw * k * 19.0 - Y * k * 4.0 + 2 * T + 1.3))
    envuelve = np.clip(ancho * 3.0, 0.0, 1.0) * np.clip((1.2 - v) * 3.0, 0.0, 1.0)
    F = ancho ** 0.5 * (1.0 - v) + 0.22 * ruido * np.clip(v + 0.3, 0.2, 1.0) * envuelve
    F = np.where(v < 0.0, F * np.clip(1.0 + v * 6.0, 0.0, 1.0), F)
    llama = F > 0.30
    # LAS HEBRAS que suben: bandas casi verticales (torcidas por el mismo ruido, que sube), solo por dentro de la llama
    hebra = np.sin(Xw * k * 17.0 + 0.6 * np.sin(Y * k * 6.0 + T) - Y * k * 2.0)
    # EL CANTO DE LA LUZ (la luz viene de arriba a la izquierda): los pixeles de llama con hueco a su izquierda
    izq = np.zeros_like(llama)
    izq[:, 2:] = llama[:, 2:] & ~(llama[:, :-2] & llama[:, 1:-1])
    out = np.asarray(img).astype(float).copy()
    # (06/10, su diagnostico: "el fuego no es solido, se ve un poco a traves de el": cada capa con su opacidad, y se
    # mezcla con lo que haya detras -el cuerpo o el suelo-; la masa deja ver, las hebras claras casi no)
    def pinta(mask, col, alfa):
        fa = out[:, :, 3] / 255.0
        na = alfa + fa * (1.0 - alfa)
        for c in range(3):
            mezcla = (col[c] * alfa + out[:, :, c] * fa * (1.0 - alfa)) / np.maximum(na, 1e-6)
            out[:, :, c] = np.where(mask, mezcla, out[:, :, c])
        out[:, :, 3] = np.where(mask, na * 255.0, out[:, :, 3])
    pinta(llama & ~(F > 0.35), (6, 5, 18), 0.7)                      # el borde, casi negro
    pinta(F > 0.35, (20, 18, 56), 0.62)                              # la masa azul marino, translucida
    pinta((F > 0.42) & (hebra > 0.72), (50, 48, 146), 0.75)         # las hebras indigo
    pinta((F > 0.55) & (hebra > 0.93), (112, 128, 236), 0.9)        # y su luz
    pinta(izq & (F > 0.35), (96, 112, 226), 0.85)                    # el canto que da a la luz
    pinta(F > 0.9, (62, 60, 168), 0.8)                               # donde arde mas, al pie
    pinta(F > 0.96, (175, 190, 255), 0.95)
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA')


# LO ELEGIDO (06/10, suyo): 1a = el CIELO DE NOCHE; 2a = los OJOS "pero con estrellitas tambien, y el color oscuro": el
# mismo cuerpo de noche con sus estrellas y los ojos al azar encima (x1,1 del cielo).
def ojos_cielo(cerrados=()):
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'noche', 0)
    _estrellas(e, C, R, 26, 3, grandes=4)
    _cuernos(e, C, R, 'noche')
    for i, (d, tam, iris, giro, ab) in enumerate(OJOS):
        _ojo_almendra(e, C, R, d, tam, iris, 0.08 if i in cerrados else ab, giro)
    return e.L


ELEGIDO = [
    ('abisal hoy', ESC_NORMAL, abisal_hoy, {}),
    ('1a cielo', ESC_MUTANTE, cielo, {'translucidos': ('noche', 'cuerno'), 'noche': True}),
    ('2a ojos', ESC_MUTANTE * 1.1, ojos_cielo, {'translucidos': ('noche', 'cuerno'), 'noche': True}),
]


FILAS = [
    ('abisal hoy', ESC_NORMAL, abisal_hoy, {}),
    ('A cielo de noche', ESC_MUTANTE, cielo, {'translucidos': ('noche', 'cuerno'), 'noche': True}),
    ('B muchos ojos', ESC_MUTANTE, ojos, {}),
    ('C fuego negro', ESC_MUTANTE, fuego_negro, {'translucidos': ('noche', 'cuerno'), 'noche': True}),
    ('D sonrisa', ESC_MUTANTE, sonrisa, {'translucidos': (), 'noche': True}),
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


if __name__ == '__main__' and len(sys.argv) > 1 and sys.argv[1] == 'elegido':
    sal = 'tools/salida/sdf/slime_abisal_elegido.png'
    filas = []
    for nombre, esc, fn, extra in ELEGIDO:
        filas.append((nombre, [render(modelo(esc, **extra), fn(), d) for d in range(5)]))
        print(nombre, 'ok')
    _lamina(filas, sal)
    mo = modelo(ESC_MUTANTE * 1.1, translucidos=('noche', 'cuerno'), noche=True)
    rng = np.random.default_rng(2)
    _lamina([('2a parpadeo', [render(mo, ojos_cielo(tuple(rng.choice(len(OJOS), 3, replace=False))), 0)
                              for _ in range(8)])], sal.replace('.png', '_tira.png'))
    sys.exit(0)

if __name__ == '__main__':
    sal = sys.argv[1] if len(sys.argv) > 1 else 'tools/salida/sdf/slime_abisal_versiones.png'
    os.makedirs(os.path.dirname(sal), exist_ok=True)
    filas = []
    for nombre, esc, fn, extra in FILAS:
        mo = modelo(esc, **extra)
        fotos = [render(mo, fn(), d) for d in range(5)]
        if fn is fuego_negro:
            fotos = [llamas_2d(f, 0.0) for f in fotos]
        filas.append((nombre, fotos))
        print(nombre, 'ok')
    _lamina(filas, sal)
    # LA TIRA del fuego negro mirando al sur: 8 fotogramas del vaiven.
    mo = modelo(ESC_MUTANTE, translucidos=('noche', 'cuerno'), noche=True)
    cuerpo = render(mo, fuego_negro(), 0)
    tira_c = [llamas_2d(cuerpo, i / 8.0) for i in range(8)]
    # Y EL PARPADEO de B: cada fotograma, unos cuantos cerrados al azar (cada ojo a su aire).
    mo_b = modelo(ESC_MUTANTE)
    rng = np.random.default_rng(2)
    tira_b = [render(mo_b, ojos(tuple(rng.choice(len(OJOS), 3, replace=False))), 0) for _ in range(8)]
    _lamina([('C llamas', tira_c), ('B parpadeo', tira_b)], sal.replace('.png', '_tira.png'))
