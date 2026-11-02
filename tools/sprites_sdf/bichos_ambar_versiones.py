# ============================================================
#  bichos_ambar_versiones.py -- LOS BICHOS DEL AMBAR, en QUIETO (02/11/2026, trent-mutante): los que suelta la costra
#  del Tocon ambarino al romperse. Cada uno, basico + UNA habilidad. Lo que eligio el jefe:
#    garrapata    AMBAR OSCURO: lenteja marron-ambarina con brillo de resina, pinzas y 8 patitas; HINCHADA (1 a 3) se pone
#                 redonda, tirante y mas clara, con venas rojas (y si la matas asi, revienta)
#    mosquito     PREHISTORICO: grande, patas larguisimas colgando, alas transparentes con venas ambar, trompa larga y el
#                 cuerpo ambar oscuro rayado; vuela (sombra en el suelo)
#    pelotero     ESCARABAJO PELOTERO: redondito, negro-verdoso con brillo metalico, patas de atras largas empujando su
#                 BOLA de caca (marron con pajitas), mas grande que el
#  A la escala del jabali (1,7) para compararlos con lo que ya hay.
#  Uso: python tools/sprites_sdf/bichos_ambar_versiones.py -> tools/salida/sdf/bichos_ambar_versiones.png (y al escritorio)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

V = np.array
ESC = 1.7

MAT = {
    'garrapata': [(0.30, 0.15, 0.05), (0.50, 0.27, 0.09), (0.72, 0.45, 0.18), (1.0, 0.85, 0.55)],
    'escudo':    [(0.18, 0.09, 0.04), (0.30, 0.16, 0.07), (0.45, 0.26, 0.12), (0.85, 0.65, 0.40)],
    'hinchada':  [(0.50, 0.24, 0.12), (0.74, 0.42, 0.24), (0.90, 0.62, 0.40), (1.0, 0.90, 0.70)],   # (palida salia un huevo)
    'vena':      [(0.45, 0.06, 0.08), (0.62, 0.10, 0.12), (0.78, 0.20, 0.20)],
    'pata':      [(0.12, 0.07, 0.04), (0.22, 0.13, 0.07), (0.32, 0.20, 0.11)],
    'mosquito':  [(0.32, 0.17, 0.05), (0.52, 0.30, 0.10), (0.72, 0.48, 0.20)],
    'raya':      [(0.12, 0.07, 0.03), (0.20, 0.12, 0.05), (0.30, 0.19, 0.08)],
    'ala':       [(0.70, 0.62, 0.45), (0.85, 0.78, 0.60), (0.96, 0.92, 0.80)],
    'vena_ala':  [(0.55, 0.35, 0.10), (0.65, 0.42, 0.14), (0.75, 0.52, 0.20)],
    'ojo':       [(0.85, 0.20, 0.15)] * 3,
    'pelotero':  [(0.05, 0.08, 0.06), (0.10, 0.16, 0.12), (0.20, 0.32, 0.24), (0.55, 0.85, 0.65)],
    'caca':      [(0.24, 0.15, 0.08), (0.36, 0.23, 0.12), (0.48, 0.33, 0.18)],
    'paja':      [(0.62, 0.52, 0.22), (0.80, 0.70, 0.34), (0.92, 0.84, 0.50)],
}


class _E(Escena):
    def __init__(self):
        super().__init__({'raiz': IDENT})


def _cono(e, a, b, ra, rb, mat, k=0.0, grupo='adorno'):
    e.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo)


def _elip(e, c, r, mat, k=0.0, grupo='cuerpo'):
    e.add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo)


def _elip_girada(e, c, r, R, mat, k=0.0, grupo='adorno'):
    # Un elipsoide girado (las alas): R lleva los ejes del elipsoide al mundo.
    c = V(c, dtype=float); r = V(r, dtype=float); Rt = R.T
    e.add(lambda P: sd_elipsoide((P - c) @ R, V((0.0, 0.0, 0.0)), r), mat, k, grupo)


def _pata(e, base, codo, punta, r, mat='pata'):
    _cono(e, base, codo, r, r * 0.8, mat, 0, 'pata')
    _cono(e, codo, punta, r * 0.8, r * 0.3, mat, 0, 'pata')


# ------------------------------------------------------------
def garrapata(hinchazon=0):
    e = _E()
    h = hinchazon
    rx_, ry_, rz_ = 5.0 + 1.3 * h, 6.4 + 1.1 * h, 2.2 + 1.7 * h
    zc = 2.6 + 1.6 * h
    mat = 'garrapata' if h == 0 else 'hinchada'
    _elip(e, (0, -0.6, zc), (rx_, ry_, rz_), mat, 0.8)
    # el ESCUDO de delante: oscuro y duro (no crece al hincharse; en la hinchada queda pequeño encima)
    _elip(e, (0, 2.6 + 0.5 * h, zc + rz_ * 0.55), (3.2, 2.8, 0.9), 'escudo', 0.3)
    # la cabeza con sus pinzas
    _elip(e, (0, ry_ - 0.2, 2.4 + 0.4 * h), (1.5, 1.7, 1.0), 'escudo', 0.4)
    for s in (-1, 1):
        _cono(e, (0.6 * s, ry_ + 1.0, 2.3 + 0.4 * h), (0.9 * s, ry_ + 3.0, 1.6 + 0.3 * h), 0.45, 0.12, 'escudo', 0, 'pinza')
    # las venas de la hinchada: rojas, por encima
    if h > 0:
        rnd = random.Random(3)
        for k in range(5 + 2 * h):
            a0 = rnd.uniform(0, 2 * math.pi)
            pts = []
            for j in range(4):
                a = a0 + j * 0.25
                u = 0.3 + j * 0.18
                pts.append(V((math.cos(a) * rx_ * u, -0.6 + math.sin(a) * ry_ * u,
                              zc + rz_ * math.sqrt(max(0.0, 1 - u * u)) + 0.05)))
            for a, b in zip(pts, pts[1:]):
                _cono(e, a, b, 0.22, 0.15, 'vena', 0, 'vena')
    # 8 patitas, cuatro por lado, de delante a atras
    for s in (-1, 1):
        for j, y in enumerate((3.4, 1.4, -0.8, -3.0)):
            base = V((rx_ * 0.75 * s, y + 0.3 * h * (1 if y > 0 else -1), 2.0 + 0.5 * h))
            fuera = V((s * (3.5 + 0.4 * h), 1.2 if j < 2 else -1.2, 0.0))
            codo = base + fuera + V((0, 0, 1.6))
            punta = codo + V((s * 2.0, 1.6 if j < 2 else -1.6, -codo[2] + 0.2))
            _pata(e, base, codo, punta, 0.45)
    return e.L


def mosquito():
    e = _E()
    z = 15.0
    e.sombra(0.0, 0.0, 6.0, 4.0)
    # torax, cabeza y abdomen largo con rayas
    _elip(e, (0, 0.5, z), (2.2, 2.6, 2.2), 'mosquito', 0.6)
    _elip(e, (0, 3.6, z + 0.2), (1.4, 1.4, 1.4), 'mosquito', 0.4)
    for s in (-1, 1):
        _elip(e, (0.9 * s, 4.3, z + 0.6), (0.7, 0.7, 0.8), 'ojo', 0, 'ojo')
        _cono(e, (0.5 * s, 4.4, z + 1.2), (1.6 * s, 6.5, z + 3.6), 0.18, 0.05, 'raya', 0, 'antena')
    _cono(e, (0, 4.6, z - 0.4), (0, 10.5, z - 4.5), 0.32, 0.05, 'raya', 0, 'trompa')
    for j in range(6):
        u = j / 5
        c = V((0, -2.0 - 8.5 * u, z - 0.6 - 2.6 * u))
        r = 1.9 - 1.1 * u
        _elip(e, c, (r, r * 1.05, r), 'mosquito' if j % 2 == 0 else 'raya', 0.5)
    # las ALAS: dos hojas finas abiertas en V hacia atras y arriba, transparentes, con venas
    for s in (-1, 1):
        R = rz(s * 0.35) @ ry(-s * 0.35)
        c = V((3.8 * s, -2.8, z + 2.0))
        _elip_girada(e, c, (2.0, 6.5, 0.12), R, 'ala', 0, 'ala')
        for k in (-0.8, 0.0, 0.8):
            a = c + R @ V((k, 5.5, 0.15))
            b = c + R @ V((k * 0.5, -5.5, 0.15))
            _cono(e, a, b, 0.1, 0.1, 'vena_ala', 0, 'vena_ala')
    # seis patas larguisimas que cuelgan hasta casi el suelo
    for s in (-1, 1):
        for j, y in enumerate((1.6, 0.4, -0.8)):
            base = V((1.2 * s, y, z - 1.5))
            codo = base + V((s * 5.5, (1 - j) * 3.0, 2.5))
            punta = V((s * (8.0 + j), y + (1 - j) * 6.0, 1.5))
            _pata(e, base, codo, punta, 0.28, 'raya')
    return e.L


def pelotero():
    e = _E()
    # EL ESCARABAJO, cabeza abajo empujando hacia atras: el caparazon redondo, el pronoto y la cabeza-pala.
    _elip(e, (0, 2.0, 3.6), (3.4, 4.0, 2.7), 'pelotero', 0.6)
    _cono(e, (0, -1.8, 4.5), (0, 5.8, 4.5), 0.12, 0.12, 'raya', 0, 'sutura')
    _elip(e, (0, 6.4, 3.0), (3.0, 2.0, 2.0), 'pelotero', 0.6)
    _elip(e, (0, 8.6, 1.9), (2.6, 1.4, 0.8), 'pelotero', 0.3)
    for x in (-1.6, -0.5, 0.5, 1.6):
        _cono(e, (x, 9.6, 1.9), (x * 1.1, 10.4, 1.6), 0.35, 0.08, 'pelotero', 0, 'diente')
    for s in (-1, 1):
        # las de delante, cortas y dentadas, apoyadas
        _pata(e, (2.2 * s, 6.6, 2.2), (4.2 * s, 8.0, 1.8), (4.6 * s, 9.6, 0.2), 0.55, 'pelotero')
        _pata(e, (2.8 * s, 3.0, 2.4), (5.0 * s, 3.4, 2.6), (5.6 * s, 4.6, 0.2), 0.5, 'pelotero')
        # las de atras, LARGAS, hacia arriba y atras contra la bola
        _pata(e, (2.4 * s, -0.8, 2.8), (4.6 * s, -3.8, 5.8), (2.4 * s, -6.2, 7.8), 0.5, 'pelotero')
    # LA BOLA: mas grande que el, irregular, con pajitas asomando
    c = V((0, -9.0, 6.4))
    _elip(e, c, (6.2, 6.0, 6.3), 'caca', 1.0, 'bola')
    rnd = random.Random(8)
    for _ in range(7):
        d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1)))
        d /= np.linalg.norm(d)
        _elip(e, c + d * 5.4, (1.6, 1.6, 1.4), 'caca', 1.0, 'bola')
    for _ in range(9):
        d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 1)))
        d /= np.linalg.norm(d)
        p = c + d * 5.8
        q = p + (d + V((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0.2))) * rnd.uniform(1.6, 2.8)
        _cono(e, p, q, 0.2, 0.12, 'paja', 0, 'paja')
    return e.L


VERSIONES = [
    ('garrapata', lambda: garrapata(0)),
    ('garrapata hinchada 1', lambda: garrapata(1)),
    ('garrapata hinchada 2', lambda: garrapata(2)),
    ('garrapata hinchada 3', lambda: garrapata(3)),
    ('mosquito', mosquito),
    ('pelotero', pelotero),
]


def modelo():
    lado = 96
    return Modelo(ESC, (lado, lado), (lado // 2, int(lado * 0.62)), MAT, (0.08, 0.05, 0.03), suaves=('cuerpo', 'bola'),
                  brillan=('ojo',), corta_suelo=True, especular=('garrapata', 'escudo', 'hinchada', 'pelotero'),
                  umbral_especular=0.92, translucidos=('ala',), alfa=0.45)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    mo = modelo()
    filas = []
    for nombre, fn in VERSIONES:
        L = fn()
        fotos = [render(mo, L, d) for d in range(5)]
        caja = None
        for f in fotos:
            b = f.getbbox()
            caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
        filas.append((nombre, [f.crop((0, caja[1] - 3, f.size[0], caja[3] + 3)) for f in fotos]))
        print(nombre, 'ok', caja, flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    ETQ = 130
    lam = Image.new('RGB', (W * 5 + ETQ, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2 - 5), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (ETQ + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 3, lam.height * 3), Image.NEAREST)
    lam.save('tools/salida/sdf/bichos_ambar_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    lam.save(os.path.join(esc, 'bichos_ambar_versiones.png'))
    print(os.path.join(esc, 'bichos_ambar_versiones.png'))
