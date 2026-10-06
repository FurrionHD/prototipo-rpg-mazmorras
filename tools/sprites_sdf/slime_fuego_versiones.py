# ============================================================
#  slime_fuego_versiones.py -- el MUTANTE DEL SLIME DE FUEGO, propuestas (06/10/2026). Solo QUIETOS, al lado del de fuego
#  de hoy (lava160: roca granate con las juntas de lava); el elegido pasa a slime_sdf.py como variante para animarlo.
#  Lo que pidio el jefe: ver dibujadas estas tres para decidir (el arbol y las pasivas, "tras verlo"):
#    - VOLCAN: un crater en la coronilla con su lava dentro, que humea y suelta chispas; placas de roca mas gruesas.
#    - OBSIDIANA: placas negras brillantes como cristal volcanico, la lava entre ellas y agujas de obsidiana saliendole.
#    - CENIZA Y BRASA: costra de ceniza gris agrietada que se le cae a trozos, con brasas que asoman.
#  Uso: python tools/sprites_sdf/slime_fuego_versiones.py [salida.png]
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
os.environ['SLIME_VAR'] = 'lava160'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import slime_sdf as S

V = np.array
COLOR = 'ff862b'          # el BASE de las hojas del slime de fuego (la lava)
ESC_NORMAL = 1.60
ESC_MUTANTE = 1.60 * 1.2
# El lienzo, el del mutante y con holgura para el humo del volcan y las agujas.
LIENZO, PIES = S._lienzo(ESC_MUTANTE * 1.3)


def _mats(roca=None):
    m = S._materiales('lava', COLOR)
    if roca is not None:
        m['gel'] = roca
    m['cuerno'] = m['gel']
    # EL HUMO del volcan: gris, algo calido.
    m['humo'] = [(0.30, 0.27, 0.27), (0.45, 0.41, 0.40), (0.62, 0.58, 0.55)]
    # LA CHISPA y la BRASA: lo mas encendido (siempre en su luz).
    m['chispa'] = [(1.0, 0.78, 0.30), (1.0, 0.86, 0.42), (1.0, 0.95, 0.70)]
    # LA OBSIDIANA de las agujas: negra con reflejo violaceo y su brillo.
    m['obsidiana'] = [(0.04, 0.03, 0.06), (0.10, 0.08, 0.13), (0.26, 0.22, 0.32), (0.75, 0.70, 0.85)]
    return m


ROCA_OBSIDIANA = [(0.04, 0.03, 0.06), (0.10, 0.08, 0.13), (0.24, 0.20, 0.30), (0.72, 0.66, 0.82)]
ROCA_CENIZA = [(0.26, 0.24, 0.24), (0.40, 0.38, 0.37), (0.55, 0.53, 0.51)]
# La BRASA de la ceniza: mas roja y apagada que la lava (lo que queda encendido bajo la ceniza).
BRASA = [(0.62, 0.12, 0.05), (0.86, 0.28, 0.08), (1.0, 0.52, 0.18)]


def modelo(escala, roca=None, especular=(), lava=None):
    m = _mats(roca)
    if lava is not None:
        m['lava'] = lava
        m['chispa'] = [lava[1], lava[2], lava[2]]
    mo = Modelo(escala, LIENZO, PIES, m, (0.16, 0.03, 0.05), suaves=('cuerpo',),
                brillan=('ojo', 'gema', 'lava', 'chispa'), corta_suelo=True,
                especular=('cristal',) + tuple(especular), umbral_especular=0.93)
    return mo


def _dir(x, y, z):
    d = V([x, y, z], dtype=float)
    return d / np.linalg.norm(d)


def _base():
    C, R, _sz = S._forma(S.POSE())
    return Escena(S.huesos(S.POSE())), C, R


# El cuerpo de roca con sus JUNTAS de lava (como el de hoy), con el ancho de junta que se pida (mas = mas lava).
def _cuerpo_lava(e, C, R, junta=22.0, sobra=0.75):
    e.add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    def j(P, C=C, R=R):
        return np.maximum(sd_elipsoide(P, C, R + 0.18), S._junta(P, C, R) * junta - sobra)
    e.add(j, 'lava', 0, 'junta')


def _cuernos(e, C, R, tam=1.0):
    for s in (-1, 1):
        base, n = S._superficie((0.70 * s, 0.05, 0.72), C, R)
        raiz = base - n * 2.0
        medio = base + n * 2.6 * tam + V([0.6 * s * tam, 0.0, 3.0 * tam])
        punta = medio + V([-0.6 * s * tam, 0.0, 3.6 * tam])
        e.add(lambda P, a=raiz, b=medio: sd_cono(P, a, b, 4.4 * min(tam, 1.15), 2.4 * min(tam, 1.15)), 'gel', 1.8)
        e.add(lambda P, a=medio, b=punta: sd_cono(P, a, b, 2.4 * min(tam, 1.15), 0.9), 'gel', 1.0)


def _ojos(e, C, R):
    for x, y, z in [(-0.33, 0.88, 0.34), (0.33, 0.88, 0.34)]:
        base, n = S._superficie((x, y, z), C, R)
        c = base + n * 0.05
        e.add(lambda P, c=c: np.maximum(sd_elipsoide(P, c, V([2.3, 3.0, 5.0])), sd_elipsoide(P, C, R) - 0.3),
              'ojo', 0, 'ojo')


def _aguja(e, c, eje, largo, radio, mat='obsidiana'):
    eje = _dir(*eje)
    a = c - eje * largo * 0.25; b = c + eje * largo * 0.75
    m = c + eje * largo * 0.1
    e.add(lambda P, a=a, m=m, b=b: np.minimum(sd_cono(P, a, m, 0.3, radio), sd_cono(P, m, b, radio, 0.2)), mat, 0, 'aguja')


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def fuego_hoy():
    return S.escena(S.POSE())


# A) VOLCAN: placas mas gruesas (juntas mas estrechas pero mas hondas), un CRATER de roca en la coronilla con su lava
# dentro, una columna de humo que sube y chispas saltando.
def volcan():
    e, C, R = _base()
    R = R * V([1.05, 1.05, 1.0])
    _cuerpo_lava(e, C, R, junta=26.0, sobra=0.6)
    # EL CRATER: un cono truncado de roca fundido con la cupula, un poco atras (no tapa la cara), hueco por arriba.
    base, n = S._superficie((0.0, -0.35, 1.0), C, R)
    boca = base + V([0.0, -0.6, 3.6])
    # (ancho y bajo, con la boca abierta hacia arriba: a 45 grados se le ve la lava dentro)
    def crater(P, a=base - V([0, 0, 2.0]), b=boca):
        cono = sd_cono(P, a, b, 10.5, 7.6)
        hueco = sd_esfera(P, b + V([0, 0, 3.2]), 6.4)
        return np.maximum(cono, -hueco)
    e.add(crater, 'gel', 2.4)
    # Su lava dentro, llenando la boca.
    e.add(lambda P, c=boca - V([0, 0, 2.2]): sd_esfera(P, c, 5.6), 'lava', 0, 'magma')
    # EL HUMO: bocanadas grises que suben de la boca y se tuercen.
    for (dx, dy, dz), k in [((0.0, -1.0, 4.5), 1.35), ((2.2, -1.6, 10.0), 1.15), ((-0.6, -2.4, 15.0), 0.95)]:
        nube = boca + V([dx, dy, dz])
        for (ox, oy, oz), rr in [((0.0, 0.0, 0.0), 2.6), ((2.0, 0.4, -0.4), 2.0), ((-2.0, -0.3, -0.5), 1.9),
                                 ((0.5, 0.3, 1.6), 1.8)]:
            e.add(lambda P, c=nube + V([ox, oy, oz]) * k, r=rr * k: sd_esfera(P, c, r), 'humo', 1.0, 'humo')
    # LAS CHISPAS: motas encendidas saltando de la boca.
    for c, r in [((3.5, 1.0, 5.0), 0.8), ((-3.0, -1.0, 7.5), 0.7), ((4.5, -2.0, 10.0), 0.6), ((-1.5, 2.0, 3.0), 0.7)]:
        e.add(lambda P, c=boca + V(c), r=r: sd_esfera(P, c, r), 'chispa', 0, 'chispa')
    _cuernos(e, C, R, 1.1)
    _ojos(e, C, R)
    return e.L


# B) OBSIDIANA: la roca es cristal volcanico NEGRO y brillante (con su reflejo), la lava entre las placas, y AGUJAS de
# obsidiana que le salen del lomo y los costados (sin tapar la cara).
def obsidiana():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.02])
    _cuerpo_lava(e, C, R, junta=20.0, sobra=0.8)
    for d, largo, radio in [((0.0, -0.30, 0.95), 13.0, 2.6), ((0.55, -0.55, 0.62), 10.0, 2.2),
                            ((-0.50, -0.60, 0.62), 11.0, 2.3), ((0.85, -0.10, 0.35), 8.0, 1.8),
                            ((-0.88, -0.05, 0.30), 7.5, 1.8), ((0.20, -0.90, 0.30), 8.5, 2.0),
                            ((-0.30, -0.80, 0.45), 6.5, 1.6)]:
        base, n = S._superficie(d, C, R)
        _aguja(e, base, tuple(n + V([0, 0, 0.25])), largo, radio)
    _cuernos(e, C, R, 1.1)
    _ojos(e, C, R)
    return e.L


# C) CENIZA Y BRASA: costra de ceniza GRIS con grietas anchas por donde asoma la brasa; trozos de costra levantados a
# medio caerse y alguna brasa suelta encendida.
def ceniza():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.02])
    _cuerpo_lava(e, C, R, junta=17.0, sobra=0.75)
    # LOS TROZOS que se le caen: lascas planas de costra despegadas de la piel, ladeadas.
    for d, tam in [((0.75, -0.40, 0.50), 5.5), ((-0.70, -0.30, 0.60), 5.0), ((0.10, -0.85, 0.50), 4.8),
                   ((0.88, 0.20, 0.05), 4.2)]:
        base, n = S._superficie(d, C, R)
        # (despegada de la piel y ladeada: se ve el canto y la brasa debajo)
        n = _dir(*(n + V([0.35, 0.0, 0.3])))
        c = base + n * 2.2 + V([0, 0, -0.6])
        e.add(lambda P, c=c, t=tam, n=n: np.maximum(sd_esfera(P, c, t), np.abs((P - c) @ n) - 0.7), 'gel', 0, 'lasca')
    # LAS BRASAS: puntos encendidos que asoman entre la ceniza.
    for d, r in [((0.45, -0.55, 0.70), 1.3), ((-0.55, -0.20, 0.80), 1.1), ((0.80, 0.10, 0.45), 1.0),
                 ((-0.20, -0.85, 0.40), 1.2), ((-0.80, 0.30, 0.20), 0.9)]:
        base, n = S._superficie(d, C, R)
        e.add(lambda P, c=base + n * 0.2, r=r: sd_esfera(P, c, r), 'chispa', 0, 'brasa')
    _cuernos(e, C, R, 1.0)
    _ojos(e, C, R)
    return e.L


FILAS = [
    ('fuego hoy', ESC_NORMAL, fuego_hoy, {}),
    ('A volcan', ESC_MUTANTE, volcan, {}),
    ('B obsidiana', ESC_MUTANTE, obsidiana, {'roca': ROCA_OBSIDIANA, 'especular': ('gel', 'cuerno', 'obsidiana')}),
    ('C ceniza y brasa', ESC_MUTANTE, ceniza, {'roca': ROCA_CENIZA, 'lava': BRASA}),
]


if __name__ == '__main__':
    sal = sys.argv[1] if len(sys.argv) > 1 else 'tools/salida/sdf/slime_fuego_versiones.png'
    os.makedirs(os.path.dirname(sal), exist_ok=True)
    filas = []
    for nombre, esc, fn, extra in FILAS:
        L = fn()
        mo = modelo(esc, **extra)
        filas.append((nombre, [render(mo, L, d) for d in range(5)]))
        print(nombre, 'ok')
    W, H = filas[0][1][0].size
    y_ini, y_fin = H, 0
    for _, fotos in filas:
        for f in fotos:
            bb = f.getbbox()
            if bb:
                y_ini = min(y_ini, bb[1]); y_fin = max(y_fin, bb[3])
    y_ini = max(0, y_ini - 3); y_fin = min(H, y_fin + 3); h = y_fin - y_ini
    IZQ = 110
    lam = Image.new('RGB', (W * 5 + IZQ, h * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * h + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            fc = f.crop((0, y_ini, f.size[0], y_fin))
            lam.paste(fc, (IZQ + i * W, j * h), fc)
    lam = lam.resize((lam.width * 3, lam.height * 3), Image.NEAREST)
    lam.save(sal)
    print(sal)
