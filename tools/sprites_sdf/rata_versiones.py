# ============================================================
#  rata_versiones.py -- LOS MUTANTES DE LA RATA, propuestas en QUIETO (30/10/2026). El jefe eligio tres ideas (rata
#  escurridiza, rata de la plaga, rata de cristal) y "la forma del arbol se decidira al ver las opciones": dos versiones
#  de cada una, sobre la rata de siempre (rata_sdf.py) y a su tamaño de mutante (x1,2), al MISMO zoom que la normal.
#    ESCURRIDIZA A  sombra   casi negra, flaca y pegada al suelo, ojos amarillos que brillan
#    ESCURRIDIZA B  erizada  gris pizarra con una CRESTA de pelo negro erizado por el lomo, ojos rojos, cola larga y oscura
#    PLAGA A        sarnosa  pelo pardo verdoso con CALVAS de piel rosa y PUSTULAS amarillentas, ojos lechosos
#    PLAGA B        bubonica mas oscura, BUBAS gordas negruzcas en el cuello y la ijada, LLAGAS en la cola, ojos rojos
#    CRISTAL A      cresta   una FILA de cristales (los que se ha comido, los mismos cian de los slimes) por el lomo
#    CRISTAL B      drusas   RACIMOS de cristales gordos en los hombros y las ancas, y uno en la frente
#  Y las SEGUNDAS EVOLUCIONES (lo pidio: "hazlas todas y las elijo"): una por pareja y una con las tres, mezclando lo
#  mas suyo de cada una; se rehacen con las versiones que elija.
#  Solo QUIETAS: la(s) elegida(s) pasan a rata_sdf.py para animarlas con las claves de la rata.
#  Uso: python tools/sprites_sdf/rata_versiones.py  -> tools/salida/sdf/rata_versiones.png
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import rata_sdf as rs

Z = rs.Z
ESC_NORMAL = 1.2
ESC_MUTANTE = 1.2 * 1.2   # la tabla de los mutantes: tamaño x1,2

CRISTAL = [(0.30, 0.72, 0.85), (0.55, 0.95, 1.0), (0.85, 1.0, 1.0), (1.0, 1.0, 1.0)]   # el 4o, el destello (especular)


def _mat(**cambios):
    m = dict(rs.MAT)
    m['cristal'] = CRISTAL
    m.update(cambios)
    return m


def _lomo(y):
    """La altura del lomo a lo largo del cuerpo (lo mas alto de las dos elipses del cuerpo de rata_sdf)."""
    z = 0.0
    for (cy, cz, ry, rz) in ((-1.2, 2.7, 5.0, 2.8), (2.6, 2.6, 3.4, 2.4)):
        u = (y - cy) / ry
        if abs(u) < 1.0:
            z = max(z, cz + rz * math.sqrt(1.0 - u * u))
    return z


def _sobre_cuerpo(y, ang):
    """Un punto de la piel del cuerpo trasero: 'ang' 0 = arriba, +-90 = los flancos (grados)."""
    a = math.radians(ang)
    u = max(-0.95, min(0.95, (y + 1.2) / 5.0))
    k = math.sqrt(1.0 - u * u)
    return Z(4.0 * k * math.sin(a), y, 2.7 + 2.8 * k * math.cos(a))


class _Piezas:
    def __init__(self, pose):
        self.X = rs.huesos(pose)
        self.L = rs.escena(pose)

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, self.X.get(hueso, IDENT), hueso))


def _cristal(add, base, d, largo, r, grupo='cristal', hueso='raiz'):
    d = np.array(d, dtype=float)
    d = d / np.linalg.norm(d)
    add(lambda P, a=base - d * 0.4, b=base + d * largo, ra=r: sd_cono(P, a, b, ra, ra * 0.12), 'cristal', 0, grupo, hueso)


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def normal():
    return rs.escena(rs.POSE())


# ------------------------------------------------------------
#  LOS RASGOS (piezas que se ponen sobre una rata; las segundas evoluciones los juntan)
# ------------------------------------------------------------
def r_cresta_pelo(e):
    # LA CRESTA: mechones de pelo negro erizados a lo largo del lomo, de la nuca a la grupa, mas altos en medio.
    for i in range(9):
        y = 3.6 - i * 0.95
        z = _lomo(y)
        alto = 1.8 + 1.6 * math.sin(math.pi * (i + 0.5) / 9)
        e.add(lambda P, a=Z(0, y, z - 0.5), b=Z(0, y - 1.0, z + alto), r=0.85: sd_cono(P, a, b, r, 0.12), 'pelo_osc', 0,
              'cresta', 'cabeza' if y > 4.0 else 'raiz')


def r_calvas(e):
    # LAS CALVAS: parches de piel rosada sin pelo por el lomo y los flancos.
    for (y, ang, r) in ((0.5, 25, 1.9), (-2.4, -40, 1.7), (-0.8, 75, 1.5), (2.2, -20, 1.4)):
        e.add(lambda P, c=_sobre_cuerpo(y, ang), r=r: sd_esfera(P, c, r), 'calva', 0.4, 'cuerpo')


def r_pustulas(e, n=14):
    # LAS PUSTULAS: granos amarillentos, sueltos.
    rnd = random.Random(7)
    for i in range(n):
        c = _sobre_cuerpo(rnd.uniform(-4.5, 2.8), rnd.uniform(-95, 95))
        e.add(lambda P, c=c, r=rnd.uniform(0.55, 0.85): sd_esfera(P, c, r), 'pustula', 0, 'pustula')


def r_bubas(e):
    # LAS BUBAS: bultos gordos y negruzcos en el cuello y en la ijada.
    for (y, ang, r) in ((3.0, 55, 1.6), (3.2, -60, 1.4), (-2.0, 80, 1.8), (-0.6, -85, 1.5), (-3.6, 20, 1.3)):
        e.add(lambda P, c=_sobre_cuerpo(y, ang), r=r: sd_esfera(P, c, r), 'buba', 0.2, 'buba')


def r_llagas(e):
    # LAS LLAGAS de la cola: anillos rojizos a lo largo.
    for k in (4, 7, 10):
        u = k / 14
        c = Z(rs._cola_x(u, 0.0), -5.4 - u * 10.5, 2.3 + (0.55 - 2.3) * min(1.0, u * 1.6))
        e.add(lambda P, c=c, r=1.6 - 0.55 * u: sd_esfera(P, c, r), 'llaga', 0, 'llaga', 'cola')


def r_cresta_cristal(e, escala=1.0):
    # LA FILA DE CRISTALES por el lomo, echados hacia atras, mas grandes en medio.
    for i in range(7):
        y = 2.8 - i * 1.15
        z = _lomo(y)
        t = math.sin(math.pi * (i + 0.5) / 7)
        _cristal(e.add, Z(0.25 * (-1) ** i, y, z - 0.2), (0.25 * (-1) ** i, -0.45, 1.0), (2.4 + 2.6 * t) * escala,
                 0.7 + 0.35 * t)


def r_drusas(e, frente=True):
    # LOS RACIMOS (drusas) en los hombros y en las ancas: tres o cuatro cristales gordos que salen abanicados.
    for (y, ang, n, largo) in ((2.4, 40, 3, 3.6), (2.4, -40, 3, 3.6), (-2.6, 30, 4, 4.4), (-2.6, -30, 4, 4.4)):
        c = _sobre_cuerpo(y, ang)
        s = 1 if ang > 0 else -1
        for k in range(n):
            gi = (k - (n - 1) / 2) * 0.55
            d = (s * (0.55 + 0.25 * k / n), -0.3 + gi * 0.6, 1.0)
            _cristal(e.add, c, d, largo * (0.75 + 0.25 * ((k + 1) % 2)), 0.85)
    if frente:
        # Y UNO EN LA FRENTE, entre las orejas.
        _cristal(e.add, Z(0, 5.6, 4.7), (0, 0.35, 1.0), 2.8, 0.7, hueso='cabeza')


def _con(pose, *rasgos):
    e = _Piezas(pose)
    for r in rasgos:
        r(e)
    return e.L


# ------------------------------------------------------------
#  LAS VERSIONES (primera evolucion) y las SEGUNDAS (juntan dos, o las tres)
# ------------------------------------------------------------
def escurridiza_a():
    # Flaca y pegada al suelo: el cuerpo mas largo y aplastado.
    return _con(rs.POSE(estira=1.12, agacha=0.22))


def escurridiza_b():
    return _con(rs.POSE(estira=1.06, agacha=0.1), r_cresta_pelo)


def plaga_a():
    return _con(rs.POSE(), r_calvas, r_pustulas)


def plaga_b():
    return _con(rs.POSE(agacha=0.08), r_bubas, r_llagas)


def cristal_a():
    return _con(rs.POSE(), r_cresta_cristal)


def cristal_b():
    return _con(rs.POSE(), r_drusas)


def evo_escurridiza_plaga():
    # La sombra que apesta: flaca y negra (la A), la cresta erizada (la B), las bubas y las llagas de la plaga.
    return _con(rs.POSE(estira=1.1, agacha=0.18), r_cresta_pelo, r_bubas, r_llagas)


def evo_escurridiza_cristal():
    # Negra y pegada al suelo, con la fila de cristales por el lomo (oscuros, como cristal ahumado).
    return _con(rs.POSE(estira=1.1, agacha=0.18), r_cresta_cristal)


def evo_plaga_cristal():
    # Sarnosa, con pustulas, y los cristales le revientan la piel en racimos.
    return _con(rs.POSE(), r_calvas, lambda e: r_pustulas(e, 9), lambda e: r_drusas(e, False))


def evo_las_tres():
    # Todo: negra y flaca, cresta de cristal, bubas y llagas.
    return _con(rs.POSE(estira=1.1, agacha=0.18), lambda e: r_cresta_cristal(e, 1.15), r_bubas, r_llagas)


SOMBRA = dict(pelo=[(0.07, 0.07, 0.10), (0.14, 0.14, 0.19), (0.24, 0.24, 0.31)],
              vientre=[(0.12, 0.12, 0.16), (0.20, 0.20, 0.26), (0.30, 0.30, 0.37)],
              cola=[(0.10, 0.09, 0.12), (0.18, 0.16, 0.20), (0.27, 0.25, 0.30)])
PELO_OSC = [(0.05, 0.05, 0.07), (0.11, 0.11, 0.14), (0.20, 0.20, 0.24)]
SARNA = dict(pelo=[(0.27, 0.27, 0.17), (0.40, 0.40, 0.26), (0.52, 0.52, 0.36)],
             calva=[(0.52, 0.38, 0.38), (0.68, 0.52, 0.50), (0.80, 0.66, 0.62)],
             pustula=[(0.62, 0.60, 0.20), (0.85, 0.82, 0.35), (0.97, 0.95, 0.60)])
BUBAS = dict(buba=[(0.14, 0.16, 0.08), (0.26, 0.30, 0.14), (0.40, 0.45, 0.24)],
             llaga=[(0.45, 0.10, 0.08), (0.62, 0.18, 0.14), (0.75, 0.30, 0.24)])
CRISTAL_OSC = [(0.16, 0.30, 0.42), (0.30, 0.55, 0.72), (0.55, 0.80, 0.95), (0.95, 1.0, 1.0)]
OJO_AMARILLO = [(0.95, 0.80, 0.20)] * 3
OJO_ROJO = [(0.90, 0.15, 0.12)] * 3
ESC_EVO2 = 1.2 * 1.35   # la segunda evolucion, algo mayor que la primera

# [nombre, materiales, escena, escala]
VERSIONES = [
    ('rata hoy', rs.MAT, normal, ESC_NORMAL),
    ('escurridiza A sombra', _mat(ojo=OJO_AMARILLO, **SOMBRA), escurridiza_a, ESC_MUTANTE),
    ('escurridiza B erizada', _mat(
        pelo=[(0.20, 0.22, 0.26), (0.33, 0.35, 0.40), (0.46, 0.48, 0.53)], pelo_osc=PELO_OSC,
        cola=[(0.10, 0.10, 0.12), (0.18, 0.18, 0.21), (0.27, 0.27, 0.30)], ojo=OJO_ROJO), escurridiza_b, ESC_MUTANTE),
    ('plaga A sarnosa', _mat(ojo=[(0.80, 0.82, 0.78)] * 3, **SARNA), plaga_a, ESC_MUTANTE),
    ('plaga B bubonica', _mat(pelo=[(0.19, 0.17, 0.12), (0.30, 0.27, 0.19), (0.41, 0.37, 0.27)], ojo=OJO_ROJO, **BUBAS),
     plaga_b, ESC_MUTANTE),
    ('cristal A cresta', _mat(), cristal_a, ESC_MUTANTE),
    ('cristal B drusas', _mat(), cristal_b, ESC_MUTANTE),
    ('2a: escurr.+plaga', _mat(ojo=OJO_AMARILLO, pelo_osc=PELO_OSC, **SOMBRA, **BUBAS), evo_escurridiza_plaga, ESC_EVO2),
    ('2a: escurr.+cristal', _mat(ojo=OJO_AMARILLO, cristal=CRISTAL_OSC, **SOMBRA), evo_escurridiza_cristal, ESC_EVO2),
    ('2a: plaga+cristal', _mat(ojo=[(0.80, 0.82, 0.78)] * 3, **SARNA), evo_plaga_cristal, ESC_EVO2),
    ('2a: las tres', _mat(ojo=OJO_AMARILLO, cristal=CRISTAL_OSC, **SOMBRA, **BUBAS), evo_las_tres, ESC_EVO2),
]


def modelo(mat, L, escala):
    lado = int(round(48 * escala / ESC_NORMAL / 2)) * 2 + 8
    return Modelo(escala, (lado, lado), (lado // 2, lado // 2), mat, (0.12, 0.09, 0.07), suaves=('cuerpo',),
                  brillan=('ojo', 'brillo', 'cicatriz'), corta_suelo=True, especular=('cristal',), umbral_especular=0.955)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, mat, fn, esc in VERSIONES:
        L = fn()
        mo = modelo(mat, L, esc)
        fotos = [render(mo, L, dd) for dd in range(5)]
        caja = None
        for f in fotos:
            b = f.getbbox()
            caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
        filas.append((nombre, [f.crop((0, caja[1] - 3, f.size[0], caja[3] + 3)) for f in fotos]))
        print(nombre, 'ok')
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
    lam = lam.resize((lam.width * 5, lam.height * 5), Image.NEAREST)
    lam.save('tools/salida/sdf/rata_versiones.png')
    print('tools/salida/sdf/rata_versiones.png')
