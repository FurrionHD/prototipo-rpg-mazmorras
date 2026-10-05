# ============================================================
#  slime_versiones.py -- el SLIME MUTANTE, propuestas (05/10/2026). Solo QUIETOS, al lado del normal; el elegido pasa a
#  slime_sdf.py como variante para animarlo.
#  Lo que pidio el jefe:
#    - La A (el TRAGON) le gusta, pero SIN calavera ni espada ("si siempre salen igual colocadas seria un poco mierda"):
#      dentro solo CRISTALES y NUCLEOS. Y el slime NORMAL tambien tiene que enseñar su nucleo y UN cristal dentro.
#    - Cuernos: uno grande y otro pequeño, o TRES sin simetria (dos a un lado, uno al otro).
#    - Queria ver igualmente las tres: B (el BROTADO: yemas de slime con ojitos) y C (el CRISTALIZADO: los cristales que
#      se ha comido le salen por fuera).
#  Filas: normal de hoy | normal con nucleo | A dos cuernos | A tres cuernos | B brotado | C cristalizado.
#  Uso: python tools/sprites_sdf/slime_versiones.py [salida.png]
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
os.environ['SLIME_VAR'] = 's100'
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import slime_sdf as S

V = np.array
COLOR = 'ff2b2b'          # el BASE de las hojas del slime normal (el piso lo tiñe)
ESC_NORMAL = 1.0
ESC_MUTANTE = 1.2         # el x1.2 de la tabla del mutante (EnemyData.mult_mutante)
# El lienzo, el del mutante y con holgura para los cuernos y las puas: los normales se pintan en el mismo, mas pequeños.
LIENZO, PIES = S._lienzo(ESC_MUTANTE * 1.25)


def _mats():
    m = S._materiales('normal', COLOR)
    c = S.hexc(COLOR)
    # EL NUCLEO: una bola mas oscura y densa del mismo color, que se ve a traves del gel.
    m['nucleo'] = [(0.22, 0.02, 0.06), (0.36, 0.04, 0.10), (0.62, 0.16, 0.22)]
    # EL CRISTAL: el cian de los cristales del juego (IconoItem), claro para que se lea a traves del gel.
    m['cristal'] = [(0.30, 0.72, 0.85), (0.55, 0.95, 1.0), (0.85, 1.0, 1.0), (1.0, 1.0, 1.0)]
    # LA COSTRA (C): gel cuajado y opaco alrededor de donde le sale un cristal.
    m['costra'] = [S.osc(c, 0.55), S.osc(c, 0.38), S.osc(c, 0.18)]
    return m


def modelo(escala):
    mo = Modelo(escala, LIENZO, PIES, _mats(), S.osc(S.hexc(COLOR), 0.58), suaves=('cuerpo',),
                brillan=('ojo', 'gema'), corta_suelo=True, especular=('gel', 'cuerno', 'cristal'), umbral_especular=0.955,
                translucidos=('gel', 'cuerno'), alfa=0.72)
    mo.alfa_dentro = 0.42
    mo.claros_dentro = ('cristal', 'nucleo')    # el gel casi no los tapa (si no, cian + rojo = gris)
    mo.alfa_claro = 0.2
    return mo


def _dir(x, y, z):
    d = V([x, y, z], dtype=float)
    return d / np.linalg.norm(d)


# UN CRISTAL: bipiramide alargada (dos conos punta con punta) centrada en 'c', a lo largo de 'eje'.
def _cristal(e, c, eje, largo, radio, mat='cristal'):
    eje = _dir(*eje)
    a = c - eje * largo * 0.5; b = c + eje * largo * 0.5
    e.add(lambda P, a=a, c=c, b=b: np.minimum(sd_cono(P, a, c, 0.25, radio), sd_cono(P, c, b, radio, 0.25)),
          mat, 0, 'cristal')


def _nucleo(e, c, r):
    e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'nucleo', 0, 'nucleo')


# UN CUERNO del slime: el del normal (dos conos fundidos con la cupula), con su tamaño y su sitio.
def _cuerno(e, C, R, x, y, z, tam=1.0, torcido=0.0):
    base, n = S._superficie((x, y, z), C, R)
    lado = 1.0 if x >= 0 else -1.0
    raiz = base - n * 2.0
    medio = base + n * 2.6 * tam + V([0.6 * lado * tam + torcido, 0.0, 3.0 * tam])
    punta = medio + V([-0.6 * lado * tam + torcido * 1.6, 0.0, 3.6 * tam])
    e.add(lambda P, a=raiz, b=medio, t=tam: sd_cono(P, a, b, 4.4 * min(t, 1.15), 2.4 * min(t, 1.15)), 'gel', 1.8)
    e.add(lambda P, a=medio, b=punta, t=tam: sd_cono(P, a, b, 2.4 * min(t, 1.15), 0.9), 'gel', 1.0)


def _ojos(e, C, R, extra=()):
    # Los dos de siempre, y los de mas (posicion en la cupula y tamaño).
    for x, y, z, k in [(-0.33, 0.88, 0.34, 1.0), (0.33, 0.88, 0.34, 1.0)] + list(extra):
        base, n = S._superficie((x, y, z), C, R)
        c = base + n * 0.05
        e.add(lambda P, c=c, k=k: np.maximum(sd_elipsoide(P, c, V([2.3, 3.0, 5.0]) * k), sd_elipsoide(P, C, R) - 0.3),
              'ojo', 0, 'ojo')


def _cuerpo(e, C, R, bultos=()):
    e.add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    # Los BULTOS del mutante: bolas de su gel fundidas con la cupula (la deforman sin taparle la cara).
    for (x, y, z, r) in bultos:
        base, n = S._superficie((x, y, z), C, R)
        c = base - n * r * 0.45
        e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'gel', 3.2)


def _base():
    C, R, _sz = S._forma(S.POSE())
    return Escena(S.huesos(S.POSE())), C, R


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def normal_hoy():
    return S.escena(S.POSE())


def normal_nucleo():
    e, C, R = _base()
    _cuerpo(e, C, R)
    for s in (-1, 1):
        _cuerno(e, C, R, 0.70 * s, 0.05, 0.72)
    _ojos(e, C, R)
    # Su NUCLEO, algo bajo y atras (que no tape los ojos de frente), y UN cristal pequeño flotando al lado.
    _nucleo(e, C + V([0.0, -2.5, -1.5]), 4.2)
    _cristal(e, C + V([5.0, -1.0, 2.5]), (0.5, 0.2, 1.0), 6.0, 1.7)
    return e.L


# Lo de DENTRO del tragon: dos nucleos y un puñado de cristales a distintas alturas y giros.
def _tripas_tragon(e, C):
    _nucleo(e, C + V([-2.5, -2.5, -2.0]), 4.4)
    _nucleo(e, C + V([4.0, -4.5, 1.5]), 3.2)
    for c, eje, largo, radio in [((5.5, 1.0, 3.5), (0.6, 0.1, 1.0), 7.0, 2.0),
                                 ((-6.0, 2.0, 0.5), (-0.4, 0.3, 1.0), 6.0, 1.7),
                                 ((0.5, -6.0, 5.5), (0.2, -0.6, 1.0), 7.5, 2.1),
                                 ((-3.0, 4.0, -4.0), (1.0, 0.2, 0.3), 5.0, 1.5),
                                 ((7.0, -5.5, -3.0), (0.3, 0.5, 1.0), 5.0, 1.5)]:
        _cristal(e, C + V(c), eje, largo, radio)


BULTOS_TRAGON = [(0.82, -0.35, 0.20, 7.5), (-0.70, -0.55, 0.45, 6.5), (-0.88, 0.20, -0.15, 5.5), (0.20, -0.95, -0.10, 6.0)]


def tragon_dos():
    e, C, R = _base()
    R = R * V([1.06, 1.04, 1.04])
    _cuerpo(e, C, R, BULTOS_TRAGON)
    _cuerno(e, C, R, -0.66, 0.05, 0.74, tam=1.75)     # el GRANDE
    _cuerno(e, C, R, 0.68, 0.12, 0.70, tam=0.55)      # el pequeño
    _ojos(e, C, R)
    _tripas_tragon(e, C)
    return e.L


def tragon_tres():
    e, C, R = _base()
    R = R * V([1.06, 1.04, 1.04])
    _cuerpo(e, C, R, BULTOS_TRAGON)
    # Dos a la izquierda (uno delante grande y otro detras mas corto) y uno a la derecha, mediano.
    _cuerno(e, C, R, -0.66, 0.30, 0.70, tam=1.45)
    _cuerno(e, C, R, -0.50, -0.50, 0.72, tam=0.90, torcido=-0.8)
    _cuerno(e, C, R, 0.72, 0.0, 0.70, tam=1.05)
    _ojos(e, C, R)
    _tripas_tragon(e, C)
    return e.L


def brotado():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.04])
    _cuerpo(e, C, R)
    # LAS YEMAS: bolitas de slime a medio salir, cada una con su ojito (algunas).
    yemas = [(0.85, -0.30, 0.30, 5.6, True), (-0.80, -0.45, 0.10, 4.8, True), (0.30, -0.85, 0.55, 4.2, False),
             (-0.45, 0.10, 0.85, 3.8, True), (0.70, 0.45, -0.20, 3.6, False)]
    for x, y, z, r, ojo in yemas:
        base, n = S._superficie((x, y, z), C, R)
        c = base + n * r * 0.35
        e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'gel', 1.6)
        if ojo:
            # El ojito mira hacia fuera de la yema, un poco hacia la camara.
            o = c + _dir(n[0], n[1] + 0.6, n[2]) * (r * 0.92)
            e.add(lambda P, o=o, r=r: sd_elipsoide(P, o, V([1.1, 1.1, 1.5]) * (r / 4.5)), 'ojo', 0, 'ojo')
    for s in (-1, 1):
        _cuerno(e, C, R, 0.70 * s, 0.05, 0.72)
    _cuerno(e, C, R, 0.10, -0.45, 0.88, tam=0.85, torcido=1.0)   # el TERCERO, torcido, detras
    # Cuatro ojos: los dos de siempre y dos mas pequeños, descolocados.
    _ojos(e, C, R, extra=[(-0.55, 0.75, 0.55, 0.62), (0.08, 0.93, 0.62, 0.5)])
    _nucleo(e, C + V([0.0, -2.5, -1.5]), 4.2)
    return e.L


def cristalizado():
    e, C, R = _base()
    R = R * V([1.05, 1.05, 1.03])
    _cuerpo(e, C, R)
    for s in (-1, 1):
        _cuerno(e, C, R, 0.70 * s, 0.05, 0.72, tam=1.1)
    _ojos(e, C, R)
    _nucleo(e, C + V([0.0, -2.5, -1.5]), 4.4)
    # LAS PUAS: cristales que nacen dentro y le atraviesan la piel por el lomo y entre los cuernos. Donde salen, una
    # COSTRA de gel cuajado (opaca).
    puas = [((0.0, -0.20, 0.98), 11.0, 2.6), ((0.45, -0.60, 0.65), 9.0, 2.2), ((-0.50, -0.55, 0.65), 9.5, 2.3),
            ((0.80, -0.35, 0.25), 7.0, 1.9), ((-0.85, -0.10, 0.30), 6.5, 1.8), ((0.15, -0.90, 0.25), 7.5, 2.0)]
    for d, largo, radio in puas:
        base, n = S._superficie(d, C, R)
        c = base + n * (largo * 0.32)
        _cristal(e, c, tuple(n), largo * 1.25, radio)
        e.add(lambda P, b=base, r=radio: sd_esfera(P, b, r * 1.25), 'costra', 0, 'costra')
    _cristal(e, C + V([-4.5, 2.0, 1.0]), (0.4, 0.2, 1.0), 5.5, 1.6)   # y uno dentro que aun no ha salido
    return e.L


# B2: LA SEGUNDA EVOLUCION (05/10, idea suya al ver la C: "que aun tenga los bultos tal como tenemos hecho el otro pero
# con lo nuevo"): el brotado de siempre, pero los cristales que llevaba dentro ya le han salido por FUERA como puas.
def brotado_puas():
    e, C, R = _base()
    R = R * V([1.04, 1.04, 1.04])
    _cuerpo(e, C, R)
    yemas = [(0.85, -0.30, 0.30, 5.6, True), (-0.80, -0.45, 0.10, 4.8, True), (0.30, -0.85, 0.55, 4.2, False),
             (-0.45, 0.10, 0.85, 3.8, True), (0.70, 0.45, -0.20, 3.6, False)]
    for x, y, z, r, ojo in yemas:
        base, n = S._superficie((x, y, z), C, R)
        c = base + n * r * 0.35
        e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'gel', 1.6)
        if ojo:
            o = c + _dir(n[0], n[1] + 0.6, n[2]) * (r * 0.92)
            e.add(lambda P, o=o, r=r: sd_elipsoide(P, o, V([1.1, 1.1, 1.5]) * (r / 4.5)), 'ojo', 0, 'ojo')
    for s_ in (-1, 1):
        _cuerno(e, C, R, 0.70 * s_, 0.05, 0.72)
    _cuerno(e, C, R, 0.10, -0.45, 0.88, tam=0.85, torcido=1.0)
    _ojos(e, C, R, extra=[(-0.55, 0.75, 0.55, 0.62), (0.08, 0.93, 0.62, 0.5)])
    _nucleo(e, C + V([0.0, -2.5, -1.5]), 3.4)
    # Las PUAS por donde no hay yemas: lomo, entre los cuernos y los costados de atras, con su costra.
    puas = [((0.0, -0.20, 0.98), 11.0, 2.6), ((0.45, -0.62, 0.62), 9.0, 2.2), ((-0.20, -0.75, 0.60), 9.0, 2.2),
            ((-0.88, 0.05, 0.40), 6.5, 1.8), ((0.55, 0.20, 0.80), 7.0, 1.9), ((-0.30, -0.95, 0.05), 7.0, 1.9)]
    for d, largo, radio in puas:
        base, n = S._superficie(d, C, R)
        c = base + n * (largo * 0.32)
        _cristal(e, c, tuple(n), largo * 1.25, radio)
        e.add(lambda P, b=base, r=radio: sd_esfera(P, b, r * 1.25), 'costra', 0, 'costra')
    return e.L


FILAS = [
    ('normal hoy', ESC_NORMAL, normal_hoy),
    ('normal +nucleo', ESC_NORMAL, normal_nucleo),
    ('A 2 cuernos', ESC_MUTANTE, tragon_dos),
    ('A 3 cuernos', ESC_MUTANTE, tragon_tres),
    ('B brotado', ESC_MUTANTE, brotado),
    ('C cristal', ESC_MUTANTE, cristalizado),
    ('B2 evolucion', ESC_MUTANTE * 1.1, brotado_puas),
]


if __name__ == '__main__':
    sal = sys.argv[1] if len(sys.argv) > 1 else 'tools/salida/sdf/slime_versiones.png'
    os.makedirs(os.path.dirname(sal), exist_ok=True)
    filas = []
    for nombre, esc, fn in FILAS:
        L = fn()
        mo = modelo(esc)
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
    IZQ = 92
    lam = Image.new('RGB', (W * 5 + IZQ, h * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * h + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            fc = f.crop((0, y_ini, f.size[0], y_fin))
            lam.paste(fc, (IZQ + i * W, j * h), fc)
    lam = lam.resize((lam.width * 4, lam.height * 4), Image.NEAREST)
    lam.save(sal)
    print(sal)
