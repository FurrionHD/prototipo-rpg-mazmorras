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
                brillan=('ojo', 'gema', 'estrella', 'blanco', 'iris_v', 'iris_m', 'corazon_luz'),
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
def _ojo_almendra(e, C, R, d, tam, iris='iris_v', abierto=1.0):
    base, n = S._superficie(d, C, R)
    up = V([0.0, 0.0, 1.0]) - n * n[2]
    up = up / max(np.linalg.norm(up), 1e-6)
    c = base + n * 0.25
    sep = tam * (0.55 + 0.35 * (1.0 - abierto))
    rr = tam * 1.05
    def lente(P, c=c, up=up, n=n, sep=sep, rr=rr):
        d1 = np.maximum(sd_esfera(P, c + up * sep, rr), sd_esfera(P, c - up * sep, rr))
        return np.maximum(d1, np.abs((P - c) @ n) - 0.55)
    e.add(lente, 'blanco', 0, 'ojo_blanco')
    if iris != 'blanco':
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


# B) MUCHOS OJOS: ojos de verdad por todo el cuerpo, de tamaños distintos, con iris verde o magenta; alguno entornado.
def ojos():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.03])
    e.add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    _cuernos(e, C, R)
    for d, tam, iris, ab in [((-0.36, 0.85, 0.40), 5.6, 'iris_v', 1.0), ((0.36, 0.85, 0.40), 5.6, 'iris_m', 1.0),
                             ((0.80, 0.40, 0.45), 4.0, 'iris_m', 0.5), ((-0.78, 0.35, 0.50), 3.8, 'iris_v', 1.0),
                             ((0.02, 0.45, 0.88), 3.4, 'iris_v', 1.0), ((-0.70, -0.40, 0.58), 4.0, 'iris_m', 0.45),
                             ((0.55, -0.55, 0.62), 3.6, 'iris_v', 1.0)]:
        _ojo_almendra(e, C, R, d, tam, iris, ab)
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
def _lengua(dr, bx, by, ancho, alto, mece, curva, col):
    """Una lengua de llama: su linea central sube curvandose (y se mece arriba), el ancho afila hasta la punta."""
    izq, der = [], []
    n = 10
    for i in range(n + 1):
        v = i / n
        cxv = bx + mece * v ** 1.5 + curva * math.sin(v * math.pi) * ancho * 0.4
        cyv = by - alto * v
        w = ancho * (1.0 - v) ** 0.75 * (1.0 + 0.18 * math.sin(v * 7.0 + curva))
        izq.append((cxv - w, cyv)); der.append((cxv + w, cyv))
    dr.polygon([(round(x), round(y)) for x, y in izq + der[::-1]], fill=col)


def llamas_2d(img, t):
    a = np.asarray(img)[:, :, 3]
    ys, xs = np.nonzero(a > 0)
    if len(xs) == 0:
        return img
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    cx = (x0 + x1) / 2.0
    cy = y0 + (y1 - y0) * 0.5
    rx = (x1 - x0) / 2.0 * 0.95
    ry = (y1 - y0) / 2.0 * 0.9
    detras = Image.new('RGBA', img.size, (0, 0, 0, 0))
    delante = Image.new('RGBA', img.size, (0, 0, 0, 0))
    # tres capas: el borde casi negro, el indigo, y la luz azul clara (corrida hacia la luz, a la izquierda)
    capas = [((12, 10, 36, 255), 1.0, 0.0), ((40, 34, 108, 255), 0.70, -0.08), ((110, 125, 232, 255), 0.36, -0.22)]
    lenguas = [(-0.92, 0.55, 0.3, 1.0), (-0.62, 0.85, 1.6, -1.0), (-0.25, 1.0, 2.9, 1.0), (0.18, 1.0, 4.1, -1.0),
               (0.58, 0.85, 5.2, 1.0), (0.92, 0.55, 0.9, -1.0)]
    for col, f, corre in capas:
        dr = ImageDraw.Draw(detras)
        # LA CORONA: la banda de fuego sobre la cupula de la que nacen las lenguas (las une).
        bw = rx * (0.98 if f == 1.0 else 0.9 * f + 0.1)
        dr.ellipse([round(cx - bw + rx * corre), round(cy - ry * 0.98 - ry * 0.18 * f),
                    round(cx + bw + rx * corre), round(cy - ry * 0.98 + ry * 0.55 * f)], fill=col)
        for u, k, fase, curva in lenguas:
            ang = math.pi * 0.5 * (1.0 - u)
            bx = cx + math.cos(ang) * rx * 0.9 + rx * corre * 0.5
            by = cy - math.sin(ang) * ry * 0.85
            th = 2 * math.pi * t + fase
            ancho = rx * 0.26 * k * (0.35 + 0.65 * f)
            alto = (ry * 1.05 + ry * 0.14 * math.sin(th * 2.0)) * k * (0.45 + 0.55 * f)
            mece = math.sin(th) * ancho * 0.9
            _lengua(dr, bx, by, ancho, alto, mece, curva * math.cos(th), col)
    # el CORAZON del fuego, palido, abajo en la corona, y unas estrellas en las llamas
    dr = ImageDraw.Draw(detras)
    for u in (-0.3, 0.25):
        hx, hy = cx + u * rx, cy - ry * 0.9
        dr.ellipse([round(hx - 2), round(hy - 2), round(hx + 2), round(hy + 1)], fill=(190, 205, 255, 255))
    rng = np.random.default_rng(int(t * 8) + 11)
    for _ in range(5):
        sx = cx + rng.uniform(-0.8, 0.8) * rx
        sy = cy - ry * rng.uniform(1.1, 1.8)
        if a.shape[0] > sy > 0:
            dr.point([(round(sx), round(sy))], fill=(230, 235, 255, 255))
    out = Image.alpha_composite(detras, img)
    return Image.alpha_composite(out, delante)


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
    _lamina([('C llamas', [llamas_2d(cuerpo, i / 8.0) for i in range(8)])], sal.replace('.png', '_tira.png'))
