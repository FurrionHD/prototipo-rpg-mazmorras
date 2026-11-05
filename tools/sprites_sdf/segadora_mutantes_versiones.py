# ============================================================
#  segadora_mutantes_versiones.py -- LOS MUTANTES DE LA SEGADORA, propuestas en QUIETO (05/11/2026, segadora-mutante).
#  SU MANTIS DE SIEMPRE (segadora_sdf: cuerpo, cabeza y alas), con lo que fue diciendo el jefe:
#    "que tenga las garras mas grandes no significa que sean el 1000 % del sprite y que tenga los brazos gordisimos"
#    "porque los tiene todo tiesos para adelante? con dientes como he dibujado y que se vea que puede doblar las garras"
#    1a: "garras 1.4 estan bien pero un poco curvas, metalicas, con dientes; añadele algo mas; mas oscuro tornandose hacia rojo"
#    2a: "garras en 1.6 y ya muy rojo, mas dentadas y mas anchas, algun detalle extra, saca varias versiones"
#  Uso: python tools/sprites_sdf/segadora_mutantes_versiones.py -> tools/salida/sdf/segadora_mutantes_versiones.png
#  (y al escritorio, en ataques_mapa/enemigos/prueba_3d/mutantes)
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import sdf_comun
import segadora_sdf as base

V = np.array
_cono = base._cono
_elip = base._elip
_unit = base._unit

# EL METAL de las hojas: el mismo acero en las dos; lo que cambia es el cuerpo.
METAL = {
    'hoja':  [(0.27, 0.29, 0.35), (0.48, 0.51, 0.58), (0.72, 0.75, 0.82), (1.0, 1.0, 1.0)],
    'diente': [(0.17, 0.18, 0.22), (0.30, 0.32, 0.38), (0.50, 0.53, 0.60)],
    'espina': [(0.10, 0.07, 0.07), (0.17, 0.11, 0.10), (0.26, 0.17, 0.15)],
}
# La 1a: oscura, tornandose hacia rojo.
MAT1 = dict(base.MAT)
MAT1.update(METAL)
MAT1.update({
    'cuerpo':  [(0.17, 0.09, 0.07), (0.28, 0.14, 0.10), (0.40, 0.21, 0.14)],
    'tegmina': [(0.24, 0.12, 0.08), (0.36, 0.18, 0.11), (0.48, 0.26, 0.16)],
    'mancha':  [(0.48, 0.14, 0.09), (0.62, 0.20, 0.12), (0.76, 0.30, 0.18)],
    'pata':    [(0.14, 0.08, 0.07), (0.23, 0.12, 0.09), (0.33, 0.18, 0.12)],
    'guadana': [(0.19, 0.10, 0.08), (0.31, 0.16, 0.11), (0.43, 0.23, 0.15)],
    'placa':   [(0.11, 0.07, 0.07), (0.20, 0.11, 0.10), (0.31, 0.17, 0.14)],
    'ojo':     [(0.62, 0.40, 0.18), (0.82, 0.58, 0.24), (0.94, 0.76, 0.38), (1.0, 0.95, 0.75)],
    'brillo':  [(0.70, 0.20, 0.08), (0.92, 0.36, 0.12), (1.0, 0.62, 0.26)],
})
# La 2a: ya muy roja.
MAT2 = dict(MAT1)
MAT2.update({
    'cuerpo':  [(0.30, 0.04, 0.04), (0.50, 0.07, 0.06), (0.70, 0.13, 0.09)],
    'tegmina': [(0.40, 0.05, 0.05), (0.62, 0.09, 0.07), (0.82, 0.17, 0.11)],
    'mancha':  [(0.12, 0.04, 0.05), (0.18, 0.06, 0.07), (0.26, 0.09, 0.10)],
    'pata':    [(0.22, 0.04, 0.05), (0.36, 0.06, 0.06), (0.52, 0.10, 0.08)],
    'guadana': [(0.27, 0.04, 0.05), (0.44, 0.07, 0.06), (0.62, 0.12, 0.09)],
    'placa':   [(0.10, 0.03, 0.05), (0.17, 0.05, 0.07), (0.27, 0.08, 0.10)],
    'ojo':     [(0.75, 0.55, 0.12), (0.95, 0.78, 0.22), (1.0, 0.92, 0.45), (1.0, 1.0, 0.85)],
    'brillo':  [(0.95, 0.42, 0.10), (1.0, 0.65, 0.18), (1.0, 0.86, 0.42)],
})


def modelo(mat):
    return Modelo(2.5, (190, 190), (95, 108), mat, (0.05, 0.02, 0.03), suaves=('cuerpo', 'cabeza'), brillan=('pupila', 'brillo'),
                  corta_suelo=True, especular=('ojo', 'hoja'), umbral_especular=0.78)


M1, M2 = modelo(MAT1), modelo(MAT2)
CFG = {'tibia': 1.4, 'ancho': 1.0, 'dientes': 6, 'tam_diente': 1.0}


def _panza(dt):
    """Hacia donde se comba la hoja: hacia delante y abajo, perpendicular a ella."""
    d = V((0.0, 1.0, -0.35))
    return _unit(d - dt * float(d @ dt))


def _hoja(add, g, codo, dt, dentro, largo):
    """La hoja de metal, UN POCO curva (la panza hacia fuera y la punta hacia dentro), con sus dientes por el filo de dentro."""
    an = CFG['ancho']
    n = 8
    pts = []
    for i in range(n + 1):
        u = i / n
        pts.append(codo + dt * largo * u + _panza(dt) * math.sin(math.pi * u) * largo * 0.2)
    prev = None
    for i, q in enumerate(pts):
        u = i / n
        w = (1.15 - 0.72 * u ** 1.6) * an
        if prev is not None:
            _cono(add, prev[0], q, prev[1], w, 'hoja', 0, g)
        prev = (q, w)
    nd = CFG['dientes']
    for k in range(nd):
        u = 0.14 + 0.72 * k / max(nd - 1, 1)
        q = pts[int(u * n)] * (1.0 - (u * n % 1)) + pts[min(int(u * n) + 1, n)] * (u * n % 1)
        tam = CFG['tam_diente'] * (1.0 - 0.35 * u)
        w = (1.15 - 0.72 * u ** 1.6) * an
        fuera = _panza(dt)
        pie = q + fuera * w * 0.5
        _cono(add, pie, pie + fuera * 2.2 * tam + dt * 0.7 * tam, 0.62 * tam, 0.14, 'diente', 0, g + 'd')


def _guadana(add, p, s):
    a = max(0.0, min(1.0, p['abre']))

    def mezcla(d0, d1):
        d = _unit(d0 + (d1 - d0) * a)
        return V((d[0] * s, d[1], d[2]))
    df = mezcla(base.FEMUR_PLEGADO, base.FEMUR_ABIERTO)
    dt = mezcla(base.TIBIA_PLEGADO, base.TIBIA_ABIERTO)
    hom = base.GUADANA_ANCLA * V((s, 1, 1))
    codo = hom + df * base.FEMUR_LARGO
    # Plegada HACIA ATRAS y abajo, contra el pecho: a pico hacia el suelo, desde esta camara se quedaba en un muñon. Asi se lee
    # el doblez entero: el femur sube y la hoja vuelve.
    dt = _unit(V((0.26 * s, -0.58, -0.77)))
    g = 'guadana_%d' % s
    _cono(add, hom - V((0.6 * s, 0.6, 0.6)), hom, 0.95, 0.95, 'guadana', 0, g)
    _cono(add, hom, codo, 1.55, 1.20, 'guadana', 0, g)
    dentro = _unit(dt - df * float(dt @ df))
    for i in range(4):
        b = hom + df * base.FEMUR_LARGO * (0.30 + 0.17 * i)
        _cono(add, b, b + dentro * 1.55 + df * 0.35, 0.42, 0.10, 'espina', 0, g)
    _hoja(add, g, codo, dt, dentro, base.TIBIA_LARGO * CFG['tibia'])


# ---------- LOS DETALLES (cada uno pegado a su cuerpo, sin cambiarle la silueta) ----------
def hombreras(add, cab):
    for s in (-1, 1):
        _elip(add, (2.1 * s, 13.0, 3.6), (1.7, 2.1, 1.0), 'placa', 0, 'hombrera')
        _cono(add, (2.6 * s, 13.2, 4.1), (4.1 * s, 12.2, 6.0), 0.65, 0.14, 'espina', 0, 'hombrera')


def cuernos(add, cab, largo=1.0):
    for s in (-1, 1):
        c = base.CABEZA + V((1.3 * s, -0.2, 1.3))
        _cono(cab, c, c + V((1.0 * s, -2.4 * largo, 2.6 * largo)), 0.62, 0.14, 'espina', 0, 'cuerno')


def cresta(add, cab):
    for i in range(4):
        y, z = 12.0 - i * 2.6, 3.4 - i * 0.55
        _cono(add, (0.0, y, z), (0.0, y - 1.1, z + 2.1 - i * 0.15), 0.62, 0.12, 'espina', 0, 'cresta')
    for i in range(5):
        y, z = 0.5 - i * 2.9, 2.05 - i * 0.14
        _cono(add, (0.0, y, z), (0.0, y - 1.0, z + 1.7 - i * 0.22), 0.55, 0.12, 'espina', 0, 'cresta')


def anillos(add, cab):
    # Bandas oscuras a traves de las alas, como una avispa: se ven desde lejos.
    for i in range(4):
        _elip(add, (0.0, 0.2 - i * 3.0, 2.05 - i * 0.16), (2.05 - i * 0.22, 0.55, 0.38), 'placa', 0, 'banda')


def alas(add, cab):
    # Las alas entreabiertas: dos hojas rojas asomando por los lados, con su nervio.
    for s in (-1, 1):
        a, b = V((1.2 * s, 2.0, 2.2)), V((6.6 * s, -9.5, 2.8))
        _cono(add, a, b, 1.1, 0.5, 'tegmina', 0, 'ala%d' % s)
        _cono(add, a + V((1.0 * s, -2.0, 0.6)), V((7.4 * s, -6.0, 3.2)), 0.8, 0.3, 'tegmina', 0, 'ala%d' % s)
        _cono(add, a, b, 0.32, 0.14, 'placa', 0, 'nervio%d' % s)


def venas(add, cab):
    # Grietas encendidas por el lomo y en el pecho: lo mas llamativo.
    for s in (-1, 1):
        _cono(add, (0.8 * s, 0.5, 2.25), (1.3 * s, -5.0, 2.15), 0.28, 0.22, 'brillo', 0, 'vena')
        _cono(add, (1.3 * s, -5.0, 2.15), (0.7 * s, -9.5, 1.5), 0.22, 0.14, 'brillo', 0, 'vena')
    _cono(add, (0.0, 6.5, 2.0), (0.0, 12.0, 3.7), 0.28, 0.2, 'brillo', 0, 'vena')


def pinchos_patas(add, cab):
    for k, (y0, abre, alc) in enumerate(base.PATAS):
        for s in (-1, 1):
            r = V((alc * 0.42 * s, y0 + abre * 0.45, 3.0))
            _cono(add, r, r + V((1.2 * s, 0.2, 2.0)), 0.5, 0.12, 'espina', 0, 'pp')


def fauces(add, cab):
    # Mandibulas de metal que asoman del morro.
    for s in (-1, 1):
        c = base.CABEZA + V((0.65 * s, 2.0, -1.2))
        _cono(cab, c, c + V((0.7 * s, 2.0, -0.2)), 0.5, 0.26, 'diente', 0, 'fauz')
        _cono(cab, c + V((0.7 * s, 2.0, -0.2)), c + V((-0.25 * s, 2.9, -0.2)), 0.26, 0.1, 'diente', 0, 'fauz')


def escena(tibia, ancho, dientes, tam_diente, detalles):
    CFG.update(tibia=tibia, ancho=ancho, dientes=dientes, tam_diente=tam_diente)
    original = base._guadana
    base._guadana = _guadana
    p = base.POSE(abre=0.0)
    L = base.escena(p)
    base._guadana = original
    e = Escena(base.huesos(p))
    cab = lambda fn, mat, k=0.0, grupo='cuerpo', hueso='raiz': e.add(fn, mat, k, grupo, 'cabeza')
    for d in detalles:
        d(e.add, cab)
    L.extend(e.L)
    return L


def _cuernos_largos(add, cab):
    cuernos(add, cab, 1.5)


if __name__ == '__main__':
    getattr(sdf_comun, '_prioridad_baja', lambda: None)()
    A1 = (1.4, 1.0, 4, 1.0)
    A2 = (1.6, 1.3, 5, 1.25)
    filas = [
        ('NORMAL (hoy)', None, None),
        ('1a evolucion A\nhombreras y cuernos', escena(*A1, [hombreras, cuernos]), M1),
        ('1a evolucion B\ny bandas en las alas', escena(*A1, [hombreras, cuernos, anillos]), M1),
        ('1a evolucion C\ny cresta', escena(*A1, [hombreras, cuernos, cresta]), M1),
        ('2a evolucion A\ncresta y cuernos largos', escena(*A2, [hombreras, _cuernos_largos, cresta]), M2),
        ('2a evolucion B\nalas entreabiertas', escena(*A2, [hombreras, cuernos, alas]), M2),
        ('2a evolucion C\nvetas encendidas', escena(*A2, [hombreras, cuernos, venas]), M2),
        ('2a evolucion D\nfauces y patas con pinchos', escena(*A2, [hombreras, cuernos, fauces, pinchos_patas]), M2),
    ]
    W, H = 190, 190
    ESC = 3
    MARGEN = 190
    tiras = []
    for nombre, L, mo in filas:
        fotos = []
        for d in range(5):
            if L is None:
                im0 = render(base.MODELO, base.escena(base.POSE()), d)
                im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                im.paste(im0, (95 - base.MODELO.OX, 108 - base.MODELO.OY), im0)
            else:
                im = render(mo, L, d)
            fotos.append(im)
        cajas = [f.getbbox() for f in fotos]
        tiras.append((nombre, fotos, max(0, min(c[1] for c in cajas) - 3), min(H, max(c[3] for c in cajas) + 3)))
        print(nombre.replace('\n', ' '), flush=True)
    x0 = min(f.getbbox()[0] for t in tiras for f in t[1]) - 3
    x1 = max(f.getbbox()[2] for t in tiras for f in t[1]) + 3
    ancho = x1 - x0
    hoja = Image.new('RGB', (MARGEN + ancho * 5 * ESC, sum((t[3] - t[2]) * ESC for t in tiras)), (40, 42, 50))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, fotos, y0, y1 in tiras:
        dib.text((10, y + (y1 - y0) * ESC // 2), nombre, fill=(235, 235, 235))
        for d, im in enumerate(fotos):
            c = im.crop((x0, y0, x1, y1)).resize((ancho * ESC, (y1 - y0) * ESC), Image.NEAREST)
            hoja.paste(c, (MARGEN + d * ancho * ESC, y), c)
        y += (y1 - y0) * ESC
    os.makedirs('tools/salida/sdf', exist_ok=True)
    hoja.save('tools/salida/sdf/segadora_mutantes_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    hoja.save(os.path.join(esc, 'segadora_mutantes_versiones.png'))
    print('ok', hoja.size)
