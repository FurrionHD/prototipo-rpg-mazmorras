# ============================================================
#  aberracion_medusa_versiones.py -- LOS DOS RANGOS DE LA ABERRACION MUTANTE (13/11/2026), elegidos por el jefe en texto
#  antes de dibujar (memoria aberracion-mutante): van hacia una MEDUSA ELECTRICA, MORADO + CIAN.
#    RANGO 1 = CARNE QUE SE ACLARA: la forma de la base, pero translucida y con los NERVIOS electricos a la vista.
#      R1 a  entera translucida, nervios ramificados por dentro hasta los tentaculos
#      R1 b  se aclara solo por ARRIBA (lobulos y joroba); abajo sigue la carne de siempre
#      R1 c  entera translucida, nervios con NUDOS de luz y los tentaculos con anillos cian
#    RANGO 2 = CAMPANA TRANSLUCIDA: flota, se ve dentro el ojo y los nervios encendidos.
#      R2 a  campana ALTA (casi un gorro), seis tentaculos gruesos colgando
#      R2 b  campana ANCHA y baja, mas tentaculos y mas finos
#      R2 c  campana alta con el BORDE encendido y tentaculos con anillos cian
#  Solo QUIETAS, las cinco direcciones. Uso: python tools/sprites_sdf/aberracion_medusa_versiones.py
#    -> tools/salida/sdf/aberracion_medusa_versiones.png
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import aberracion_sdf as ab
import aberracion_mutantes_versiones as mv

V = np.array
_elip, _cono, _unit = ab._elip, ab._cono, ab._unit
tonos = mv.tonos

CIAN = tonos((0.45, 0.95, 1.0))[:3]
MAT = dict(ab.MAT)
MAT.update({
    'carne_t': tonos((0.80, 0.62, 0.94)),     # la carne que se aclara (translucida)
    'tent_t': tonos((0.68, 0.48, 0.84)),
    'campana': tonos((0.84, 0.68, 0.96)),
    'nervio': CIAN, 'nudo': tonos((0.80, 1.0, 1.0))[:3],
    'iris': tonos((0.45, 0.95, 1.0))[:3],
    'iris_luz': tonos((0.70, 1.0, 1.0))[:3],
})


def modelo(trans=('carne_t', 'tent_t', 'campana'), lado=240, pies=(120, 170), esc=1.8):
    return Modelo(esc, (lado, lado), pies, MAT, (0.12, 0.04, 0.12), suaves=('cuerpo',),
                  brillan=('pupila', 'nervio', 'nudo', 'iris_luz'), corta_suelo=True,
                  especular=('carne', 'tent', 'globo', 'carne_t', 'tent_t', 'campana'), umbral_especular=0.90,
                  translucidos=trans, alfa=0.45)


def recolorea(L, cambio):
    """Las piezas de la base con otros materiales (la carne que se aclara), sin tocar la forma."""
    out = Piezas([(fn, cambio.get(mat, mat), g, k, X, h) for (fn, mat, g, k, X, h) in L])
    out.sombras = list(L.sombras)
    return out


def nervios(add, centro, puntas, r=0.34, nudos=False, ramas=2):
    """Cordones que salen de un CENTRO hacia cada punta con un quiebro a medio camino (el rayo no va recto), y alguna
    rama corta. Con 'nudos', una bola de luz en cada quiebro."""
    c = V(centro, dtype=float)
    for j, p in enumerate(puntas):
        p = V(p, dtype=float)
        m = (c + p) / 2 + V((math.sin(j * 2.3) * 1.2, math.cos(j * 1.7) * 1.2, math.sin(j * 3.1) * 0.8))
        _cono(add, c, m, r, r * 0.9, 'nervio', 0, 'nervio')
        _cono(add, m, p, r * 0.9, r * 0.7, 'nervio', 0, 'nervio')
        if nudos:
            _elip(add, m, (r * 2.2,) * 3, 'nudo', 0, 'nervio')
        for b in range(ramas if j % 2 == 0 else 0):
            q = m + _unit(V((math.cos(j + b * 2.0), math.sin(j + b * 2.0), 0.5))) * 1.8
            _cono(add, m, q, r * 0.7, r * 0.5, 'nervio', 0, 'nervio')
    if nudos:
        _elip(add, c, (r * 3.0,) * 3, 'nudo', 0, 'nervio')


def _raices_tent(r=4.0, z=4.0, n=6, des=30.0):
    out = []
    for i in range(n):
        a = math.radians(des + 360.0 / n * i + (7.0, -5.0, 9.0, -8.0, 4.0, -6.0, 5.0, -7.0)[i % 8])
        out.append((math.sin(a) * r, math.cos(a) * r, z))
    return out


# ------------------------------------------------------------
#  RANGO 1: la base que se aclara
# ------------------------------------------------------------
def _nervios_base(nudos):
    e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))})
    puntas = [(4.4, -3.0, 8.4), (-4.8, 1.6, 7.0), (-0.8, -2.8, 10.6), (0.0, 3.6, 8.6)] + _raices_tent(4.2, 3.6)
    nervios(e.add, (0.0, -0.4, 5.6), puntas, nudos=nudos)
    return e.L


def r1(variante, anillos=True):
    L = ab.escena(ab.POSE())
    if variante == 'b':
        # Solo arriba: la carne de los lobulos y la joroba (z alto) se aclara; el bulbo de abajo y los tentaculos no.
        out = Piezas()
        for i, (fn, mat, g, k, X, h) in enumerate(L):
            out.append((fn, 'carne_t' if (mat == 'carne' and 2 <= i <= 6) else mat, g, k, X, h))
        out.sombras = list(L.sombras)
        L = out
    else:
        L = recolorea(L, {'carne': 'carne_t', 'tent': 'tent_t'})
    N = _nervios_base(nudos=(variante == 'c'))
    L.extend(N)
    if variante == 'c' and anillos:
        e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))})
        for (x, y, z) in _raices_tent(7.4, 1.6):
            _elip(e.add, (x, y, z), (1.5, 1.5, 0.9), 'nervio', 0, 'nervio')
        L.extend(e.L)
    return L


# ------------------------------------------------------------
#  RANGO 2: la campana translucida
# ------------------------------------------------------------
def r2(variante):
    e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))}); add = e.add
    alta = variante in ('a', 'c')
    z = 11.0 if alta else 13.0
    rad = V((8.4, 8.2, 9.6)) if alta else V((10.6, 10.2, 6.0))
    e.sombra(0.0, 0.0, rad[0] * 0.95, rad[1] * 0.85, 0.30)
    add(lambda P: sd_casquete(P, V((0.0, 0.0, z)), np.eye(3), V((0.0, 0.0, 0.0)), rad, -0.8, 0.02),
        'campana', 0, 'campana')
    # Dentro: el OJO (grande, mirando al frente) y los nervios que salen de detras del ojo a todo el borde.
    oz = z + (3.6 if alta else 2.2)
    mv.ojo(add, (0.0, 4.0 if alta else 5.0, oz), 1.15, cuenca=False)
    borde = [(rad[0] * 0.85 * math.sin(math.radians(a)), rad[1] * 0.85 * math.cos(math.radians(a)), z + 0.4)
             for a in range(0, 360, 45)]
    arriba = [(0.0, -1.0, z + rad[2] * 0.8), (3.0, -2.0, z + rad[2] * 0.6), (-3.0, -2.0, z + rad[2] * 0.6)]
    nervios(add, (0.0, -0.6, oz), borde + arriba, r=0.3, nudos=(variante == 'c'), ramas=1)
    if variante == 'c':
        # El BORDE encendido: un cordon de cuentas alrededor del filo de la campana.
        for a in range(0, 360, 12):
            ar = math.radians(a)
            _elip(add, (rad[0] * 0.98 * math.sin(ar), rad[1] * 0.98 * math.cos(ar), z - 0.5), (0.9, 0.9, 0.6),
                  'nervio', 0, 'nervio')
    # Los TENTACULOS que cuelgan (translucidos), del borde de la campana.
    n, r0, r1_ = (6, 1.8, 0.8) if variante != 'b' else (10, 1.2, 0.5)
    mv.corro(add, n, rad[0] * 0.7, z - 0.6, 'cuelga', n=12, paso=1.2, r0=r0, r1=r1_, desfase=30.0, salta_frente=False,
             mat='tent_t')
    if variante == 'c':
        for i, (x, y, _) in enumerate(_raices_tent(rad[0] * 0.7, 0, 6)):
            for zz in (z - 4.0, z - 7.5):
                _elip(add, (x * 1.05, y * 1.05, zz), (1.3, 1.3, 0.5), 'nervio', 0, 'nervio')
    return e.L


# ------------------------------------------------------------
#  RANGO 2 (13/11, segunda vuelta): las campanas no le convencieron ("ha perdido la aberracion"). Ahora es LA R1 c TAL
#  CUAL, fiel a la aberracion, pero FLOTANDO DE VERDAD en el aire. Lo que cambia entre versiones: la altura, el tamaño
#  y como le cuelgan los tentaculos.
#    F a  a media altura, los tentaculos CUELGAN y las puntas se arrastran por el suelo
#    F b  mas alta, los tentaculos ABIERTOS como los de la base (la base entera levantada)
#    F c  la mas alta, los tentaculos cuelgan ondulando SIN tocar el suelo
# ------------------------------------------------------------
def _levanta(L, h):
    out = Piezas([(fn, m, g, k, (X[0], X[1] + V((0.0, 0.0, h))), 'flota_' + str(nh)) for (fn, m, g, k, X, nh) in L])
    out.sombras = list(L.sombras)
    return out


def flota(variante):
    """13/11, tercera vuelta: la F c "no esta realmente flotando" (las puntas casi tocaban el suelo y tapaban la sombra).
    Ahora: MAS ALTA y tentaculos MAS CORTOS, para que haya AIRE entre las puntas y su sombra. (altura, tramos)."""
    h, n = {'a': (6.0, 14), 'b': (8.0, 0), 'c': (11.0, 13),
            'c1': (14.0, 9), 'c2': (17.0, 10), 'c3': (20.0, 10)}[variante]
    guardo = ab.TENTACULOS
    if variante != 'b':
        ab.TENTACULOS = 0
    try:
        L = r1('c', anillos=(variante == 'b'))
    finally:
        ab.TENTACULOS = guardo
    L = _levanta(L, h)
    e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))})
    e.sombra(0.0, 0.0, 8.0, 7.0, 0.36)
    if variante != 'b':
        mv.corro(e.add, 6, 4.6, h + 3.6, 'cuelga', n=n, paso=1.2, r0=2.2, r1=0.9, salta_frente=True, mat='tent_t')
        # Los anillos cian, donde nace cada tentaculo (debajo de la masa).
        for (x, y, _) in _raices_tent(4.6, 0, 6):
            if y / 4.6 > 0.93: continue
            _elip(e.add, (x, y, h + 1.6), (1.4, 1.4, 0.7), 'nervio', 0, 'nervio')
    L.extend(e.L)
    L.sombras = list(L.sombras) + list(e.L.sombras)
    return L


# ------------------------------------------------------------
#  RANGO 2 EPICO (13/11): la F c3 "mas epica, que se note que es la ultima evolucion". Marcado por el jefe:
#  OJO QUE IRRADIA (iris encendido + halo, los nervios NACEN del ojo), MAS TENTACULOS, FAUCES MAS GRANDES (abiertas y
#  con luz cian dentro). Lo que cambia entre versiones es el HALO del ojo:
#    E a  aro de cuentas de luz alrededor del ojo
#    E b  rayos cortos que salen del ojo hacia fuera (un sol)
#    E c  aro + rayos
# ------------------------------------------------------------
def epica(variante, h=20.0):
    guardo = ab.TENTACULOS
    ab.TENTACULOS = 0
    try:
        L = ab.escena(ab.POSE(boca=0.6))
    finally:
        ab.TENTACULOS = guardo
    L = recolorea(L, {'carne': 'carne_t', 'tent': 'tent_t', 'iris': 'iris_luz'})
    e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))}); add = e.add
    oj = V((0.0, 5.0, 9.4))
    # Los NERVIOS nacen detras del OJO (es el corazon de la tormenta) y van a lobulos, joroba y raices de tentaculos.
    puntas = [(4.4, -3.0, 8.4), (-4.8, 1.6, 7.0), (-0.8, -2.8, 10.6), (2.6, -5.0, 6.0), (-3.6, -4.4, 9.0)] +              _raices_tent(4.2, 3.6, 8, 22.5)
    nervios(add, oj - V((0.0, 2.6, 0.0)), puntas, nudos=True)
    # LUZ en la boca abierta.
    _elip(add, (0.0, 7.9, 4.4), (2.1, 0.7, 1.7), 'nudo', 0, 'nervio')
    # EL HALO del ojo, en el plano de la cara (XZ), un poco por delante del globo.
    if variante in ('a', 'c'):
        for k in range(16):
            a = 2 * math.pi * k / 16
            _elip(add, oj + V((3.9 * math.cos(a), 2.6, 3.8 * math.sin(a))), (0.55, 0.5, 0.55), 'nervio', 0, 'nervio')
    if variante in ('b', 'c'):
        for k in range(10):
            a = 2 * math.pi * (k + 0.5) / 10
            u = V((math.cos(a), 0.0, math.sin(a)))
            r0 = 4.7 if variante == 'c' else 3.9
            _cono(add, oj + u * r0 + V((0.0, 2.6, 0.0)), oj + u * (r0 + 2.2) + V((0.0, 2.6, 0.0)), 0.5, 0.15,
                  'nervio', 0, 'nervio')
    L.extend(e.L)
    L = _levanta(L, h)
    # MAS TENTACULOS: 6 gordos y 5 finos entre medias (melena), colgando cortos como la F c3; anillos cian en la raiz.
    e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))})
    e.sombra(0.0, 0.0, 8.0, 7.0, 0.36)
    mv.corro(e.add, 6, 4.6, h + 3.6, 'cuelga', n=10, paso=1.2, r0=2.2, r1=0.9, salta_frente=True, mat='tent_t')
    mv.corro(e.add, 6, 5.4, h + 3.0, 'cuelga', n=12, paso=1.2, r0=1.1, r1=0.45, desfase=0.0, salta_frente=True,
             mat='tent_t', punta='nervio')
    for (x, y, _) in _raices_tent(4.6, 0, 6):
        if y / 4.6 > 0.93: continue
        _elip(e.add, (x, y, h + 1.6), (1.4, 1.4, 0.7), 'nervio', 0, 'nervio')
    L.extend(e.L)
    L.sombras = list(L.sombras) + list(e.L.sombras)
    return L


VERSIONES = [
    ('R1 c', lambda: r1('c'), None),
    ('F c3', lambda: flota('c3'), None),
    ('E a', lambda: epica('a'), None), ('E b', lambda: epica('b'), None), ('E c', lambda: epica('c'), None),
]


if __name__ == '__main__':
    solo = sys.argv[1:]
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, fn, trans in VERSIONES:
        if solo and nombre.replace(' ', '') not in solo:
            continue
        mo = modelo(esc=2.6) if nombre.startswith('E') else modelo(esc=2.1) if nombre.startswith(('R2', 'F')) else (modelo() if trans is None else modelo(trans))
        filas.append((nombre, [render(mo, fn(), dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    caja = None
    for _, fotos in filas:
        for f in fotos:
            b = f.getbbox()
            if b: caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
    caja = (caja[0] - 4, caja[1] - 4, caja[2] + 4, caja[3] + 4)
    filas = [(n, [f.crop(caja) for f in fotos]) for n, fotos in filas]
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 40, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (40 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 3, lam.height * 3), Image.NEAREST)
    lam.save('tools/salida/sdf/aberracion_epica_versiones.png')
    print('tools/salida/sdf/aberracion_epica_versiones.png')
