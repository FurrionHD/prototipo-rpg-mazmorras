# ============================================================
#  bestia_acorazada_versiones.py -- CINCO PROPUESTAS de bestia acorazada en 3D (05/10/2026), una por cada referencia que
#  paso el jefe ("mira unos ejemplos de bestia acorazada mas god, haz todos los que te he pasado"). Solo QUIETAS: la(s)
#  elegida(s) pasan a bestia_acorazada_sdf.py para animarlas con las claves del viejo.
#    A behemot   hombros enormes y patas delanteras largas, fauces abiertas con corona de cuernos, PUAS de marfil
#                gigantes en el lomo, melena clara en el cuello y cola larga y fina enroscada en la punta
#    B blatogia  baja y larga, cabeza de CALAVERA de tiburon (hueso palido), filas de puas crema barridas hacia atras,
#                gris azulado con el VIENTRE NARANJA y la cola arqueada con su cresta
#    C isla      bestia de PIEDRA: patas delanteras como columnas, casco con cuerno, dos HOJAS DE ROCA enormes que salen
#                de la espalda en arco hacia delante y las fauces naranjas
#    D carnero   PLACAS DE ROCA angulosas por el lomo, vientre palido con pliegues, CUERNOS curvos hacia delante y la
#                cola de ESCORPION de rocas que sube y acaba en maza
#    E bowser    PLACAS ROJAS, collares de HIERRO con tachuelas, vientre palido, cabeza de cocodrilo con la boca abierta
#                y la cola segmentada con puas
#  Uso: python tools/sprites_sdf/bestia_acorazada_versiones.py  -> tools/salida/sdf/bestia_acorazada_versiones.png
# ============================================================
import sys, os, math, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

V = np.array
ESCALA = 1.95
LADO = 130


def _unit(v):
    v = V(v, dtype=float)
    return v / np.linalg.norm(v)


def marco(adelante, arriba=(0.0, 0.0, 1.0)):
    """Tres ejes (filas) para una caja: Y hacia 'adelante', Z lo mas cerca posible de 'arriba'."""
    y = _unit(adelante)
    x = _unit(np.cross(y, V(arriba, dtype=float)))
    z = np.cross(x, y)
    return [x, y, z]


class Kit:
    """Las piezas de siempre, ya con su lambda bien atada."""
    def __init__(self, e):
        self.add = e.add
        self.n = 0

    def elip(self, c, r, mat, k=0.0, g='cuerpo'):
        self.add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, g)

    def cono(self, a, b, ra, rb, mat, k=0.0, g='cuerpo'):
        self.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, g)

    def caja(self, c, ejes, medio, mat, red=0.3, k=0.0, g='cuerpo'):
        self.add(lambda P, c=V(c, dtype=float), m=V(medio, dtype=float): sd_caja(P, c, ejes, m, red), mat, k, g)

    def tri(self, a, b, c, grosor, mat, k=0.0, g='cuerpo'):
        self.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float), c=V(c, dtype=float): sd_triangulo(P, a, b, c, grosor),
                 mat, k, g)

    def pua(self, base, d, largo, r, mat, g='pua', curva=0.0):
        """Una pua conica; con 'curva' se dobla hacia atras (-Y) en dos tramos. La punta ROMA (0,35: afilada del todo
        se queda en contorno negro) y cada pua en su grupo alterno, para que entre dos que se tapan salga la raya."""
        base = V(base, dtype=float); d = _unit(d)
        self.n += 1; g = '%s%d' % (g, self.n % 2)
        punta = min(0.35, r * 0.4)
        if curva == 0.0:
            self.cono(base, base + d * largo, r, punta, mat, 0, g)
        else:
            m = base + d * largo * 0.55
            d2 = _unit(d + V((0.0, -curva, 0.0)))
            self.cono(base, m, r, r * 0.6, mat, 0, g)
            self.cono(m, m + d2 * largo * 0.5, r * 0.6, punta, mat, 0, g)

    def cadena(self, p0, d0, n, paso, r0, r1, giro, mat, k=0.4, g='cola'):
        """Por PASOS FIJOS (una cadena hecha con puntos de curva se abre): avanza 'paso' y gira con giro(i) (matriz).
        Devuelve [(punto, direccion, radio)] para colgarle cosas."""
        p = V(p0, dtype=float); d = _unit(d0); out = []
        for i in range(n):
            r = r0 + (r1 - r0) * i / max(n - 1, 1)
            rb = r0 + (r1 - r0) * (i + 1) / max(n - 1, 1)
            q = p + d * paso
            self.cono(p, q, r, rb, mat, k, g)
            out.append((q.copy(), d.copy(), rb))
            p = q; d = _unit(giro(i) @ d)
        return out

    def pata(self, puntos, radios, mat, garra_mat, garras=3, largo_garra=1.4, g='pata', k=0.8):
        """Una pata por sus articulaciones (de arriba al pie) y sus radios; el pie con sus GARRAS hacia delante."""
        for a, b, ra, rb in zip(puntos, puntos[1:], radios, radios[1:]):
            self.cono(a, b, ra, rb, mat, k, g)
        pie = V(puntos[-1], dtype=float)
        rp = radios[-1]
        self.elip(pie + V((0.0, 0.5, -pie[2] + rp * 0.55)), (rp * 1.15, rp * 1.35, rp * 0.6), mat, k, g)
        if garras:
            for j in range(garras):
                x = (j - (garras - 1) / 2.0) * rp * 0.75
                base = V((pie[0] + x, pie[1] + rp * 1.2, 0.7))
                self.cono(base, base + V((x * 0.15, largo_garra, -0.45)), 0.5, 0.1, garra_mat, 0, 'garra')

    def ojo(self, c, r, mat='ojo'):
        self.elip(c, (r, r, r * 0.85), mat, 0, 'ojo')


# ------------------------------------------------------------
#  A -- BEHEMOT
# ------------------------------------------------------------
MAT_A = {
    'piel':   [(0.20, 0.18, 0.16), (0.31, 0.28, 0.25), (0.42, 0.38, 0.33)],
    'escama': [(0.28, 0.25, 0.22), (0.40, 0.36, 0.31), (0.52, 0.48, 0.42)],
    'pelo':   [(0.42, 0.36, 0.30), (0.56, 0.49, 0.41), (0.68, 0.61, 0.52)],
    'marfil': [(0.66, 0.62, 0.52), (0.84, 0.80, 0.68), (0.95, 0.92, 0.82)],
    'boca':   [(0.30, 0.06, 0.06), (0.44, 0.10, 0.09), (0.56, 0.16, 0.13)],
    'ojo':    [(1.00, 0.70, 0.20)] * 3,
}


def escena_a():
    e = Escena({}); k = Kit(e)
    # El cuerpo: HOMBROS enormes y altos, la cintura se estrecha y la grupa baja (todo el peso delante).
    k.elip((0.0, 3.6, 12.4), (6.6, 6.4, 6.0), 'piel')
    k.elip((0.0, -3.4, 10.6), (4.8, 6.0, 4.2), 'piel', 3.0)
    k.elip((0.0, -9.2, 9.6), (4.6, 4.2, 4.0), 'piel', 3.0)
    # La placa escamosa de la cruz.
    k.elip((0.0, 3.0, 15.6), (5.0, 5.6, 3.6), 'escama', 1.0)
    # Cuello grueso hacia delante y ABAJO, y la cabeza baja.
    k.cono((0.0, 7.6, 11.6), (0.0, 12.6, 8.6), 4.6, 3.2, 'piel', 2.0)
    H = V((0.0, 14.2, 8.4))
    k.elip(H, (3.2, 3.2, 2.7), 'escama', 1.0, 'cabeza')
    # FAUCES ABIERTAS: el morro arriba y la mandibula abajo, con los dientes y lo rojo dentro.
    k.cono(H + V((0.0, 1.0, 0.6)), H + V((0.0, 6.2, 0.2)), 2.6, 1.5, 'escama', 1.0, 'cabeza')
    k.cono(H + V((0.0, 0.8, -1.8)), H + V((0.0, 5.6, -3.4)), 2.2, 1.2, 'piel', 1.0, 'mandibula')
    k.elip(H + V((0.0, 3.4, -1.2)), (1.9, 2.6, 1.1), 'boca', 0, 'boca')
    for s in (-1, 1):
        for i in range(4):
            y = 2.2 + 1.2 * i
            k.pua(H + V((1.3 * s, y, -0.2)), (0.1 * s, 0.1, -1.0), 1.1, 0.32, 'marfil', 'diente')
            k.pua(H + V((1.1 * s, y - 0.3, -2.4 - 0.25 * i)), (0.1 * s, 0.1, 1.0), 0.9, 0.3, 'marfil', 'diente')
        k.ojo(H + V((2.2 * s, 2.2, 1.6)), 0.55)
        # LA CORONA de cuernos: hacia atras desde la nuca.
        for j, (dy, dz, lg) in enumerate(((0.0, 2.2, 3.4), (-1.0, 1.0, 2.6), (0.8, 0.0, 2.0))):
            k.pua(H + V((2.0 * s, -0.8 + dy, 1.0 + dz)), (0.5 * s, -0.8, 0.5), lg * 1.6, 0.9, 'marfil', 'cuerno')
    # LA MELENA clara: mechones que cuelgan del cuello y el pecho.
    for i in range(9):
        a = -1.0 + 2.0 * i / 8.0
        base = V((3.4 * a, 9.6 - 0.6 * abs(a), 8.4 + 1.4 * (1 - abs(a))))
        k.cono(base, base + V((0.9 * a, 1.4, -4.6 - 0.8 * (i % 2))), 1.8, 0.35, 'pelo', 0.6, 'melena')
    # LAS PUAS DEL LOMO: enormes en la cruz, en abanico hacia atras, menguando hacia la grupa; y las de los lados.
    for i in range(6):
        u = i / 5.0
        y = 6.0 - u * 15.0
        z = 16.4 - 4.6 * u
        # GRANDES (a su tamaño 'real' median 13 px y medio quedaba dentro del lomo): en la referencia son casi tan
        # altas como el cuerpo.
        lg = 13.0 - 7.0 * u
        k.pua((0.0, y, z), (0.0, -0.55, 1.0), lg, 2.1 - 0.9 * u, 'marfil', 'pua', curva=0.35)
        for s in (-1, 1):
            if i < 5:
                k.pua((2.8 * s, y + 0.6, z - 1.6), (0.8 * s, -0.5, 0.8), lg * 0.6, 1.5 - 0.6 * u, 'marfil', 'pua2',
                      curva=0.25)
    # PATAS: delanteras LARGAS y gordas con puas en el codo; traseras mas cortas y dobladas.
    for s in (-1, 1):
        k.pata([(4.8 * s, 5.0, 12.0), (6.4 * s, 4.2, 6.2), (6.6 * s, 5.2, 1.4)], [3.4, 2.6, 2.3], 'piel', 'marfil',
               3, 1.6, 'pata_d')
        k.pua((6.6 * s, 3.0, 7.0), (0.3 * s, -1.0, 0.4), 5.0, 1.1, 'marfil', 'pua3')
        k.pata([(4.2 * s, -9.0, 10.0), (4.8 * s, -6.6, 5.6), (5.0 * s, -10.6, 3.0), (5.0 * s, -9.8, 1.2)],
               [3.0, 2.2, 1.6, 1.6], 'piel', 'marfil', 3, 1.3, 'pata_t')
        k.pua((5.4 * s, -10.6, 3.6), (0.2 * s, -1.0, 0.8), 2.0, 0.5, 'marfil', 'pua3')
    # LA COLA: larga y fina, baja y enrosca la punta hacia arriba.
    k.cadena((0.0, -12.4, 9.4), (0.0, -1.0, -0.35), 16, 1.25, 1.9, 0.45,
             lambda i: rx(0.04 if i < 9 else 0.38) @ rz(0.06), 'piel')
    return e.L


# ------------------------------------------------------------
#  B -- BLATOGIA
# ------------------------------------------------------------
MAT_B = {
    'piel':    [(0.20, 0.23, 0.29), (0.30, 0.34, 0.41), (0.42, 0.47, 0.54)],
    'naranja': [(0.58, 0.26, 0.10), (0.78, 0.40, 0.17), (0.90, 0.54, 0.26)],
    'hueso':   [(0.72, 0.66, 0.54), (0.88, 0.84, 0.72), (0.96, 0.94, 0.86)],
    'boca':    [(0.34, 0.06, 0.06), (0.48, 0.10, 0.09), (0.60, 0.16, 0.13)],
    'garra':   [(0.62, 0.56, 0.46), (0.80, 0.74, 0.62), (0.92, 0.88, 0.78)],
    'ojo':     [(0.55, 0.95, 0.35)] * 3,
}


def escena_b():
    e = Escena({}); k = Kit(e)
    # Cuerpo BAJO y largo, encorvado: el lomo sube hacia la grupa.
    k.elip((0.0, 4.0, 8.6), (5.0, 6.4, 4.4), 'piel')
    k.elip((0.0, -4.4, 10.4), (5.4, 6.4, 4.8), 'piel', 3.0)
    # El VIENTRE y los costados NARANJAS.
    k.elip((0.0, 2.0, 6.0), (4.4, 8.6, 2.8), 'naranja', 2.0)
    k.elip((0.0, -5.0, 7.8), (4.6, 4.8, 2.6), 'naranja', 2.0)
    # Cuello bajo y la CABEZA larga a ras de suelo: el craneo de hueso arriba, la mandibula naranja abajo.
    k.cono((0.0, 8.4, 8.4), (0.0, 12.0, 6.6), 3.6, 2.8, 'piel', 2.0)
    H = V((0.0, 13.6, 6.4))
    k.cono(H, H + V((0.0, 7.6, -0.8)), 2.8, 1.0, 'hueso', 0.8, 'cabeza')
    k.cono(H + V((0.0, 0.6, -1.6)), H + V((0.0, 6.4, -2.6)), 2.2, 0.9, 'naranja', 0.8, 'mandibula')
    k.elip(H + V((0.0, 3.4, -1.3)), (1.6, 3.0, 0.7), 'boca', 0, 'boca')
    for s in (-1, 1):
        for i in range(6):
            y = 1.6 + 1.0 * i
            k.pua(H + V((1.35 * s - 0.12 * s * i, y, -0.7)), (0.0, 0.0, -1.0), 0.95, 0.26, 'hueso', 'diente')
        k.ojo(H + V((1.9 * s, 2.2, 0.9)), 0.55)
        # Los cuernos de la calavera: hacia atras.
        k.pua(H + V((1.6 * s, -0.2, 1.6)), (0.3 * s, -1.0, 0.45), 3.6, 0.8, 'hueso', 'cuerno')
    # LAS PUAS: dos filas al tresbolillo, barridas hacia atras, mas grandes en el centro del lomo.
    for i in range(10):
        u = i / 9.0
        y = 9.0 - u * 18.0
        z = 10.6 + 4.4 * math.sin(math.pi * min(1.0, u * 1.3))
        lg = 6.5 + 6.0 * math.sin(math.pi * min(1.0, u * 1.2))
        s = 1 if i % 2 else -1
        k.pua((1.4 * s, y, z - 1.0), (0.45 * s, -0.9, 0.75), lg, 1.8, 'hueso', 'pua', curva=0.2)
    # PATAS: las delanteras dobladas y abiertas; las traseras grandes, con garras palidas largas.
    for s in (-1, 1):
        k.pata([(4.0 * s, 5.2, 8.0), (6.4 * s, 6.4, 4.2), (6.0 * s, 7.4, 1.2)], [2.4, 1.8, 1.5], 'piel', 'garra', 3,
               2.0, 'pata_d')
        k.elip((4.6 * s, -6.0, 9.0), (2.8, 4.0, 3.6), 'piel', 1.4, 'pata_t')
        k.pata([(4.8 * s, -6.0, 8.6), (5.6 * s, -3.6, 4.6), (5.6 * s, -7.4, 2.4), (5.6 * s, -6.6, 1.2)],
               [2.6, 1.8, 1.3, 1.4], 'piel', 'garra', 3, 2.2, 'pata_t')
        k.pua((5.9 * s, -7.8, 2.8), (0.2 * s, -1.0, 0.6), 1.6, 0.5, 'garra', 'garra2')
    # LA COLA: sale alta, se ARQUEA hacia arriba y atras, con su cresta de puas pequeñas.
    pts = k.cadena((0.0, -10.0, 11.4), (0.0, -0.8, 0.45), 19, 1.3, 2.4, 0.5,
                   lambda i: rx(0.13 if i < 12 else -0.12), 'piel')
    for j, (q, d, r) in enumerate(pts):
        if j % 2 == 0 and j < 17:
            k.pua(q + V((0.0, 0.0, r * 0.6)), (0.0, -0.8, 0.9), 3.2 - 0.12 * j, 0.9, 'hueso', 'pua_cola')
    return e.L


# ------------------------------------------------------------
#  C -- ISLA (piedra)
# ------------------------------------------------------------
MAT_C = {
    'roca':   [(0.34, 0.33, 0.30), (0.52, 0.50, 0.45), (0.68, 0.66, 0.60)],
    'oscura': [(0.17, 0.17, 0.18), (0.26, 0.26, 0.27), (0.36, 0.36, 0.36)],
    'boca':   [(0.66, 0.24, 0.06), (0.88, 0.40, 0.10), (0.98, 0.58, 0.22)],
    'diente': [(0.78, 0.76, 0.70), (0.92, 0.90, 0.84), (0.98, 0.97, 0.92)],
    'ojo':    [(1.00, 0.62, 0.16)] * 3,
}


def escena_c():
    e = Escena({}); k = Kit(e)
    # Corpachon de piedra: pecho enorme, panza oscura, grupa baja.
    k.elip((0.0, 3.4, 11.4), (7.0, 6.4, 6.0), 'roca')
    k.elip((0.0, -5.0, 9.6), (5.6, 6.6, 4.6), 'roca', 2.6)
    k.elip((0.0, -1.0, 6.8), (4.8, 6.4, 2.6), 'oscura', 2.0)
    # La CABEZA: baja y metida, con el CASCO de placas y un cuerno; las fauces naranjas.
    H = V((0.0, 11.4, 8.4))
    k.elip(H, (3.8, 3.6, 3.0), 'roca', 1.6, 'cabeza')
    k.cono(H + V((0.0, 1.0, -0.6)), H + V((0.0, 5.0, -1.2)), 2.8, 1.8, 'roca', 1.0, 'cabeza')
    k.cono(H + V((0.0, 0.8, -2.2)), H + V((0.0, 4.4, -3.4)), 2.4, 1.6, 'oscura', 1.0, 'mandibula')
    k.elip(H + V((0.0, 3.4, -1.9)), (2.0, 1.8, 0.8), 'boca', 0, 'boca')
    for s in (-1, 1):
        for i in range(3):
            k.pua(H + V((1.4 * s, 3.0 + 0.9 * i, -1.3)), (0.0, 0.2, -1.0), 1.0, 0.3, 'diente', 'diente')
        k.ojo(H + V((2.4 * s, 2.6, 0.4)), 0.5)
    k.caja(H + V((0.0, 0.4, 2.4)), marco((0.0, 1.0, 0.35)), (3.2, 3.6, 0.8), 'roca', 0.5, 0, 'casco')
    k.pua(H + V((0.0, 2.6, 2.6)), (0.0, 0.5, 1.0), 3.4, 1.2, 'roca', 'cuerno')
    # LAS HOJAS DE ROCA: dos laminas enormes desde los omoplatos, en arco hacia arriba y DELANTE.
    for s in (-1, 1):
        # Sube desde atras del omoplato, se arquea alto y cae hacia DELANTE en punta, por encima de la cabeza.
        a = V((3.0 * s, 0.0, 14.0)); b = V((5.0 * s, -6.0, 15.0))
        c1 = V((7.0 * s, -1.0, 27.0)); c2 = V((8.6 * s, -6.0, 26.0))
        c3 = V((9.6 * s, 6.0, 31.0)); c4 = V((10.0 * s, 13.0, 26.0)); c5 = V((9.6 * s, 17.0, 18.0))
        k.tri(a, b, c1, 1.0, 'roca', 0, 'hoja')
        k.tri(c1, b, c2, 1.0, 'roca', 0, 'hoja')
        k.tri(c1, c2, c3, 0.9, 'roca', 0, 'hoja')
        k.tri(c1, c3, c4, 0.8, 'roca', 0, 'hoja2')
        k.tri(c3, c4, c5, 0.7, 'oscura', 0, 'hoja3')
        # Hombreras de placa.
        k.caja(V((6.0 * s, 4.6, 13.0)), marco((0.0, 1.0, 0.0), (0.6 * s, 0.0, 1.0)), (2.0, 3.2, 1.0), 'roca', 0.4, 0, 'placa')
    # PATAS DE COLUMNA: las delanteras ENORMES, ensanchando al pie; las traseras cortas.
    for s in (-1, 1):
        k.pata([(5.2 * s, 4.6, 11.0), (6.8 * s, 6.0, 5.0), (7.2 * s, 6.6, 1.8)], [3.6, 3.2, 3.6], 'roca', 'oscura', 3,
               1.2, 'pata_d')
        k.elip((7.2 * s, 6.6, 1.2), (3.9, 3.9, 1.4), 'oscura', 0.8, 'pie')
        k.pata([(4.4 * s, -7.4, 9.0), (5.2 * s, -6.0, 4.6), (5.4 * s, -8.2, 1.4)], [3.0, 2.4, 2.4], 'roca', 'oscura', 3,
               1.0, 'pata_t')
    # COLA corta de piedra que acaba en punta hacia arriba.
    k.cadena((0.0, -10.8, 8.4), (0.0, -1.0, -0.3), 9, 1.3, 2.4, 0.4, lambda i: rx(0.1 if i > 4 else 0.0), 'roca')
    return e.L


# ------------------------------------------------------------
#  D -- CARNERO (placas de roca, cuernos, cola de escorpion)
# ------------------------------------------------------------
MAT_D = {
    'roca':   [(0.20, 0.15, 0.12), (0.31, 0.24, 0.20), (0.42, 0.34, 0.28)],
    'piel':   [(0.25, 0.19, 0.15), (0.36, 0.28, 0.22), (0.46, 0.37, 0.30)],
    'vientre': [(0.54, 0.47, 0.36), (0.70, 0.62, 0.49), (0.80, 0.73, 0.60)],
    'cuerno': [(0.46, 0.30, 0.14), (0.62, 0.43, 0.22), (0.76, 0.56, 0.32)],
    'ojo':    [(1.00, 0.82, 0.20)] * 3,
}


def escena_d():
    e = Escena({}); k = Kit(e)
    k.elip((0.0, 2.6, 9.8), (6.0, 6.6, 5.4), 'piel')
    k.elip((0.0, -5.4, 8.4), (5.0, 5.6, 4.4), 'piel', 3.0)
    # El VIENTRE palido con sus pliegues (anillos que se funden poco: cada uno hace su raya).
    for i in range(5):
        k.elip((0.0, 6.0 - 2.6 * i, 5.4 + 0.15 * i), (4.2 - 0.2 * i, 1.6, 2.4), 'vientre', 0.5, 'vientre')
    # LAS PLACAS DE ROCA del lomo: losas angulosas inclinadas que montan unas sobre otras, mas grandes en la cruz.
    filas = [(-1, 2.6), (0, 0.0), (1, -2.6)]
    for i in range(6):
        y = 6.6 - 2.8 * i
        for j, (lado, x) in enumerate(filas):
            if i == 5 and lado != 0:
                continue
            tam = 1.0 - 0.06 * i + (0.15 if lado == 0 else 0.0)
            z = 14.6 - 0.5 * i - (1.3 if lado else 0.0)
            ejes = marco((0.0, 1.0, -0.35), (0.55 * lado, 0.25, 1.0))
            k.caja((x * 1.05, y + 0.4 * (j % 2), z), ejes, (2.3 * tam, 2.2 * tam, 1.2), 'roca', 0.25, 0,
                   'placa_%d' % ((i + j) % 3))
        # Puas color cuerno entre las placas (las de la cruz).
        if i < 3:
            k.pua((0.0, y - 1.2, z + 0.8), (0.0, -0.3, 1.0), 4.0, 1.0, 'cuerno', 'pua')
    # Cabeza con su placa frontal y los CUERNOS curvos que bajan y se van hacia delante.
    H = V((0.0, 11.6, 8.4))
    k.elip(H, (3.2, 3.2, 2.8), 'piel', 1.2, 'cabeza')
    k.cono(H + V((0.0, 1.0, -0.8)), H + V((0.0, 4.6, -1.8)), 2.4, 1.6, 'piel', 1.0, 'cabeza')
    k.caja(H + V((0.0, 0.8, 1.6)), marco((0.0, 1.0, 0.5)), (2.6, 2.4, 0.8), 'roca', 0.3, 0, 'casco')
    for s in (-1, 1):
        k.ojo(H + V((2.2 * s, 2.0, 0.6)), 0.55)
        k.pua(H + V((1.0 * s, 4.2, -2.6)), (0.2 * s, 0.4, -1.0), 1.2, 0.4, 'cuerno', 'colmillo')
        # El cuerno: por pasos, de la sien hacia fuera y atras, y se enrosca hacia delante.
        k.cadena(H + V((2.2 * s, -0.4, 1.8)), (0.8 * s, -0.5, 0.4), 10, 1.35, 2.0, 0.55,
                 lambda i, s=s: rz(-0.30 * s) @ rx(0.12), 'cuerno', 0.3, 'cuerno')
    # PATAS gruesas con placas en el hombro y garras color cuerno.
    for s in (-1, 1):
        k.pata([(4.6 * s, 4.4, 9.0), (5.8 * s, 5.4, 4.6), (6.0 * s, 6.0, 1.4)], [3.0, 2.4, 2.0], 'piel', 'cuerno', 3,
               1.6, 'pata_d')
        k.caja((5.8 * s, 4.4, 9.6), marco((0.0, 1.0, 0.0), (0.7 * s, 0.0, 1.0)), (1.6, 2.6, 0.9), 'roca', 0.3, 0, 'hombro')
        k.pata([(4.2 * s, -6.6, 8.0), (5.0 * s, -4.8, 4.4), (5.2 * s, -7.8, 2.2), (5.2 * s, -7.2, 1.2)],
               [2.8, 2.0, 1.5, 1.6], 'piel', 'cuerno', 3, 1.4, 'pata_t')
    # LA COLA DE ESCORPION: segmentos de roca que suben por detras y se curvan hacia delante, con la MAZA.
    pts = k.cadena((0.0, -9.8, 9.0), (0.0, -1.0, 0.3), 11, 1.7, 2.2, 1.5, lambda i: rx(0.24), 'piel', 0.6)
    for j, (q, d, r) in enumerate(pts):
        k.caja(q + V((0.0, 0.0, r * 0.35)), marco(d, (0.0, 0.0, 1.0) if abs(d[2]) < 0.9 else (0.0, 1.0, 0.0)),
               (r * 1.25, 0.8, r * 1.0), 'roca', 0.3, 0, 'seg_%d' % (j % 2))
    q, d, r = pts[-1]
    for dd in ((0.0, 0.0, 0.0), (1.0, 0.4, 0.6), (-1.0, 0.3, 0.8), (0.0, 1.0, 1.0), (0.4, -0.6, 1.2)):
        k.caja(q + d * 1.4 + V(dd) * 1.0, marco(_unit(d + V(dd) * 0.3)), (1.5, 1.5, 1.3), 'roca', 0.3, 0, 'maza')
    return e.L


# ------------------------------------------------------------
#  E -- BOWSER (placas rojas y hierro)
# ------------------------------------------------------------
MAT_E = {
    'rojo':    [(0.36, 0.09, 0.10), (0.52, 0.15, 0.15), (0.66, 0.24, 0.22)],
    'hierro':  [(0.12, 0.10, 0.10), (0.20, 0.17, 0.17), (0.30, 0.26, 0.26)],
    'vientre': [(0.54, 0.48, 0.42), (0.70, 0.64, 0.57), (0.82, 0.77, 0.70)],
    'pua':     [(0.50, 0.47, 0.42), (0.68, 0.65, 0.59), (0.82, 0.80, 0.74)],
    'boca':    [(0.46, 0.10, 0.10), (0.66, 0.20, 0.18), (0.80, 0.32, 0.28)],
    'ojo':     [(1.00, 0.15, 0.10)] * 3,
}


def escena_e():
    e = Escena({}); k = Kit(e)
    # El cuerpo: una mole redonda, con el VIENTRE palido debajo.
    k.elip((0.0, 0.0, 9.4), (7.4, 9.0, 6.0), 'rojo')
    k.elip((0.0, 2.0, 6.2), (5.6, 7.6, 3.6), 'vientre', 1.6)
    # PLACAS ROJAS gordas sobre el lomo (cada una su grupo: entre ellas, la raya).
    for i, (x, y, z, r) in enumerate(((0.0, 4.2, 14.6, 3.8), (-3.6, -1.0, 14.0, 3.4), (3.6, -1.0, 14.0, 3.4),
                                      (0.0, -5.6, 13.4, 3.4), (-4.8, 4.0, 12.0, 2.8), (4.8, 4.0, 12.0, 2.8))):
        k.elip((x, y, z), (r, r * 1.05, r * 0.6), 'rojo', 0, 'placa_%d' % i)
        k.pua((x * 1.05, y - 0.4, z + r * 0.5), (x * 0.1, -0.35, 1.0), 5.2 if i < 4 else 3.6, 1.5, 'pua', 'pua')
    # COLLAR DE HIERRO en el cuello con tachuelas, y la cabeza de cocodrilo con la boca abierta.
    k.cono((0.0, 7.6, 10.6), (0.0, 11.0, 9.0), 4.6, 3.8, 'rojo', 2.0)
    k.cono((0.0, 9.0, 10.2), (0.0, 10.4, 9.6), 4.7, 4.3, 'hierro', 0, 'collar')
    for a in range(7):
        t = math.pi * (0.1 + 0.8 * a / 6.0)
        k.pua((4.5 * math.cos(t), 9.7, 9.9 + 4.3 * math.sin(t) * 0.9), (math.cos(t), 0.0, math.sin(t)), 1.8, 0.8,
              'pua', 'tachuela')
    H = V((0.0, 12.6, 9.0))
    k.elip(H, (3.4, 3.2, 2.8), 'rojo', 1.0, 'cabeza')
    k.cono(H + V((0.0, 1.0, 0.6)), H + V((0.0, 6.6, 0.0)), 2.8, 1.8, 'rojo', 1.0, 'cabeza')
    k.caja(H + V((0.0, 2.2, 2.0)), marco((0.0, 1.0, -0.1)), (2.2, 3.8, 0.7), 'hierro', 0.4, 0, 'casco')
    k.pua(H + V((0.0, 6.0, 1.0)), (0.0, 0.6, 1.0), 1.8, 0.7, 'pua', 'cuerno')
    k.cono(H + V((0.0, 0.8, -1.6)), H + V((0.0, 5.8, -3.2)), 2.4, 1.6, 'vientre', 1.0, 'mandibula')
    k.elip(H + V((0.0, 3.6, -1.3)), (2.0, 2.8, 1.0), 'boca', 0, 'boca')
    for s in (-1, 1):
        for i in range(4):
            k.pua(H + V((1.7 * s, 2.6 + 1.1 * i, -0.4)), (0.0, 0.1, -1.0), 1.0, 0.36, 'pua', 'diente')
        k.ojo(H + V((2.4 * s, 2.0, 1.4)), 0.6)
        k.pua(H + V((2.0 * s, -0.8, 1.8)), (0.6 * s, -0.8, 0.5), 2.6, 0.8, 'pua', 'cuerno')
    # PATAS rojas con BRAZALETES de hierro y uñas palidas.
    for s in (-1, 1):
        for y0, d in ((5.4, 1), (-5.8, -1)):
            k.pata([(5.4 * s, y0, 8.6), (6.4 * s, y0 + 0.6, 4.4), (6.6 * s, y0 + 0.8, 1.6)], [3.4, 2.8, 2.6], 'rojo',
                   'pua', 3, 1.4, 'pata')
            k.cono((6.5 * s, y0 + 0.7, 3.2), (6.55 * s, y0 + 0.75, 2.0), 3.0, 2.9, 'hierro', 0, 'brazal')
            k.pua((7.6 * s, y0 - 0.6, 8.4), (1.0 * s, -0.3, 0.5), 3.2, 1.2, 'pua', 'pua_hombro')
    # LA COLA: segmentada (anillos de hierro) y con puas, baja y se levanta en la punta.
    pts = k.cadena((0.0, -8.6, 9.0), (0.0, -1.0, -0.2), 10, 1.5, 2.8, 0.9, lambda i: rx(0.08 if i > 4 else -0.02),
                   'rojo', 0.5)
    for j, (q, d, r) in enumerate(pts):
        if j % 2 == 1:
            k.cono(q - d * 0.35, q + d * 0.35, r * 1.12, r * 1.08, 'hierro', 0, 'anillo')
        if j % 2 == 0 and j < 9:
            k.pua(q + V((0.0, 0.0, r * 0.8)), (0.0, -0.5, 1.0), 2.8, 0.95, 'pua', 'pua_cola')
    return e.L


VERSIONES = {
    'A behemot': (MAT_A, escena_a, (0.06, 0.05, 0.04)),
    'B blatogia': (MAT_B, escena_b, (0.06, 0.06, 0.08)),
    'C isla': (MAT_C, escena_c, (0.10, 0.10, 0.10)),
    'D carnero': (MAT_D, escena_d, (0.07, 0.05, 0.04)),
    'E bowser': (MAT_E, escena_e, (0.08, 0.04, 0.04)),
}


def modelo(mat, borde, L):
    # TODOS los grupos 'suaves' (con k 0 se unen duro igual): asi entre dos piezas que se tapan sale la raya de dentro
    # con el salto pequeño (salto_grupos), y no solo con el grande.
    grupos = tuple(dict.fromkeys(x[2] for x in L))
    return Modelo(ESCALA, (LADO, LADO), (LADO // 2, LADO // 2 + 14), mat, borde, suaves=grupos, brillan=('ojo',),
                  corta_suelo=True)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    solo = sys.argv[1:]
    filas = []
    d = json.load(open('assets/sprites/enemigos/bestia_acorazada_804d40_1.95.json'))
    im = Image.open('assets/sprites/enemigos/bestia_acorazada_804d40_1.95.png').convert('RGBA')
    viejas = []
    for kk in range(5):
        a = [x for x in d['anims'] if x['n'] == 'idle_%d' % kk][0]
        x, y, w, h, ox, oy = a['f'][0]
        c = Image.new('RGBA', (d['w'], d['h'])); c.paste(im.crop((x, y, x + w, y + h)), (ox, oy)); viejas.append(c)
    filas.append(('viejo', viejas))
    for nombre, (mat, fn, borde) in VERSIONES.items():
        if solo and nombre[0] not in solo:
            continue
        L = fn()
        mo = modelo(mat, borde, L)
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok')
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 70, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (70 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 3, lam.height * 3), Image.NEAREST)
    sal = 'tools/salida/sdf/bestia_acorazada_versiones%s.png' % ('_' + ''.join(solo) if solo else '')
    lam.save(sal)
    print(sal)
