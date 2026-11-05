# ============================================================
#  escarabajo_mutantes_versiones.py -- LOS MUTANTES DEL ESCARABAJO DE HIERRO, propuestas en QUIETO (04/11/2026). Cada una con
#  SU cuerpo (silueta, proporciones y postura propias), no adornos sobre el de siempre. Nada en el suelo.
#    IMAN (su Pulso arrastra hacia el a quien siga dentro de su circulo)
#      A herradura  las mandibulas son un iman de herradura enorme, cabeza gacha; el cuerpo, corto detras, de contrapeso
#      B bobina     bajo y muy ancho, con el abdomen alzado y envuelto en anillos de cobre; patas cortas de carga
#      C erizado    plano como una lapa, con el lomo lleno de limaduras de punta y dos polos en vez de cuerno
#    VOLADOR (agil y rapido: lo contrario del de siempre, "que destaque el cambio")
#      A ciervo     en el aire, elitros abiertos en V, alas largas, cuerpo fino y mandibulas de ciervo volante
#      B flecha     cuerpo larguisimo y estrecho, cuatro alas hacia atras: todo apunta hacia delante
#      C cuchillas  los elitros son dos hojas de metal abiertas en cruz, alas cortas y rapidas, patas recogidas
#  Uso: python tools/sprites_sdf/escarabajo_mutantes_versiones.py -> tools/salida/sdf/escarabajo_mutantes_versiones.png
#  (y al escritorio, en ataques_mapa/enemigos/prueba_3d/mutantes)
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import escarabajo_versiones as base

V = np.array
_cono = base._cono
_elip = base._elip
_curva = base._curva

MAT = dict(base.MAT)
MAT.update({
    # EL IMAN: hierro pavonado casi negro con rojo de iman y puntas de metal desnudo.
    'hierro':  [(0.10, 0.11, 0.14), (0.20, 0.22, 0.27), (0.34, 0.37, 0.43), (0.78, 0.82, 0.90)],
    'rojo':    [(0.34, 0.06, 0.06), (0.58, 0.11, 0.09), (0.80, 0.19, 0.13), (1.00, 0.72, 0.62)],
    'polo':    [(0.46, 0.50, 0.56), (0.68, 0.72, 0.78), (0.86, 0.89, 0.93), (1.00, 1.00, 1.00)],
    'cobre':   [(0.36, 0.17, 0.07), (0.62, 0.32, 0.13), (0.84, 0.50, 0.24), (1.00, 0.84, 0.62)],
    'limadura': [(0.16, 0.17, 0.20), (0.34, 0.36, 0.41), (0.58, 0.61, 0.67)],
    # EL VOLADOR: verde metalico ligero, mas claro que el de siempre, con alas de ambar palido.
    'ligero':  [(0.10, 0.28, 0.24), (0.18, 0.46, 0.38), (0.30, 0.66, 0.52), (0.84, 1.00, 0.92)],
    'ala':     [(0.52, 0.56, 0.42), (0.72, 0.76, 0.56), (0.90, 0.92, 0.70)],
    'vena':    [(0.20, 0.22, 0.14), (0.28, 0.30, 0.19), (0.36, 0.38, 0.24)],
    'hoja':    [(0.26, 0.34, 0.36), (0.48, 0.60, 0.60), (0.70, 0.84, 0.80), (1.00, 1.00, 1.00)],
})


def modelo(translucido=False):
    return Modelo(2.1, (112, 112), (56, 58), MAT, (0.06, 0.09, 0.05), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True,
                  especular=('caparazon', 'cuerno', 'hierro', 'rojo', 'polo', 'cobre', 'ligero', 'hoja', 'oscuro', 'cara'),
                  umbral_especular=0.96, translucidos=('ala',) if translucido else (), alfa=0.72)


def _patas(add, mat, lista, r=(0.7, 0.5, 0.25), z=0.0):
    """lista: (y de la base, angulo, largo). Los tres tramos de siempre, con la pierna que quiera cada cuerpo."""
    for s in (-1, 1):
        for k, (y0, ang, lar, ancho) in enumerate(lista):
            d = V((math.cos(ang) * s, math.sin(ang), 0.0))
            b = V((ancho * s, y0, 1.8 + z))
            rod = b + d * lar * 0.5 + V((0, 0, 1.6))
            tob = b + d * lar * 0.82 + V((0, 0, -0.6))
            pie = b + d * lar + V((0, 0, -1.7))
            g = 'pata%d%d' % (s, k)
            _cono(add, b, rod, r[0], r[1], mat, g)
            _cono(add, rod, tob, r[1], r[1] * 0.8, mat, g)
            _cono(add, tob, pie, r[1] * 0.6, r[2], mat, g)


def _ojos(add, y, x, z, r=0.9):
    for s in (-1, 1):
        _elip(add, (x * s, y, z), (r, r, r), 'ojo', 'ojo')


# ---------- IMAN ----------
def iman_a():
    # HERRADURA: lo primero que se ve es el iman. La cabeza gacha y enorme carga con el; el cuerpo es corto y va detras.
    e = Escena({}); add = e.add
    _elip(add, (0, -5.5, 3.2), (4.2, 4.4, 3.0), 'hierro', 'elitros')
    _elip(add, (0, -5.5, 3.2), (0.26, 4.5, 3.1), 'costura', 'costura')
    _elip(add, (0, -1.0, 2.6), (2.6, 1.5, 1.8), 'oscuro', 'cintura')
    _elip(add, (0, 1.6, 3.2), (5.0, 2.8, 2.7), 'hierro', 'pronoto')
    _elip(add, (0, 4.8, 2.6), (3.4, 2.2, 1.9), 'cara', 'cabeza')
    _ojos(add, 5.4, 2.9, 3.2)
    for s in (-1, 1):
        # La U de la herradura: arranca de la cabeza, se abre mucho y vuelve recta hacia delante. Roja; las puntas, desnudas.
        pts = [V((1.6 * s, 6.2, 2.8)), V((4.6 * s, 7.4, 3.4)), V((6.4 * s, 9.6, 3.8)), V((6.6 * s, 12.2, 3.9))]
        _curva(add, pts, 1.75, 1.45, 'rojo', 'iman%d' % s)
        _cono(add, (6.6 * s, 12.2, 3.9), (6.5 * s, 14.4, 3.9), 1.45, 1.3, 'polo', 'punta%d' % s)
    _patas(add, 'pata', ((3.0, 0.6, 7.5, 3.0), (-1.2, -0.2, 8.5, 2.6), (-5.0, -0.8, 8.0, 2.4)))
    return e.L


def iman_b():
    # BOBINA: bajo y muy ancho; el abdomen se alza detras envuelto en anillos de cobre, como un electroiman de carga.
    e = Escena({}); add = e.add
    _elip(add, (0, 1.6, 2.6), (7.2, 5.0, 2.5), 'hierro', 'pronoto')
    _elip(add, (0, 6.2, 2.2), (3.8, 2.0, 1.5), 'cara', 'cabeza')
    _ojos(add, 7.2, 2.8, 2.8)
    for s in (-1, 1):
        _cono(add, (1.8 * s, 7.6, 1.7), (2.6 * s, 10.0, 1.8), 1.0, 0.5, 'polo', 'pinza%d' % s)
    # El abdomen, un cilindro alzado hacia atras y arriba...
    a = V((0, -2.0, 3.6)); b = V((0, -8.0, 9.2))
    _cono(add, a, b, 3.8, 3.2, 'oscuro', 'abdomen')
    # ...y sus anillos de cobre (discos gruesos a lo largo).
    eje = (b - a) / np.linalg.norm(b - a)
    for i in range(5):
        c = a + (b - a) * (0.1 + 0.2 * i)
        add(lambda P, c=c, n=eje, ra=4.25 - 0.14 * i: sd_toro_plano(P, c, n, ra, 0.62), 'cobre', 0, 'bobina')
    # El polo de punta, arriba.
    _elip(add, b + eje * 0.6, (2.0, 2.0, 1.4), 'rojo', 'polo_alto')
    _patas(add, 'hierro', ((4.0, 0.45, 8.5, 5.5), (0.8, -0.05, 9.5, 5.8), (-2.6, -0.55, 8.5, 5.0)), r=(1.0, 0.75, 0.3))
    return e.L


def iman_c():
    # ERIZADO: plano como una lapa, y el lomo son limaduras de punta, peinadas en arcos de un polo al otro.
    e = Escena({}); add = e.add
    _elip(add, (0, -0.8, 1.9), (6.6, 8.0, 1.9), 'hierro', 'elitros')
    _elip(add, (0, 6.6, 1.8), (3.0, 1.7, 1.3), 'cara', 'cabeza')
    _ojos(add, 7.2, 2.4, 2.4, 0.8)
    # Los dos polos, en vez de cuerno.
    for s in (-1, 1):
        _cono(add, (2.0 * s, 7.4, 2.0), (2.6 * s, 10.4, 3.6), 1.05, 0.7, 'rojo', 'polo%d' % s)
        _elip(add, (2.6 * s, 10.6, 3.7), (0.95, 0.95, 0.95), 'polo', 'polo%d' % s)
    # Las limaduras: pinchos finos que nacen del lomo y se inclinan hacia el polo mas cercano.
    for i, y in enumerate(np.linspace(-7.0, 5.0, 8)):
        ancho = 5.6 * math.sqrt(max(0.05, 1.0 - ((y + 0.8) / 8.2) ** 2))
        for x in np.linspace(-ancho, ancho, 5 + (i % 2)):
            b = V((x, y, 1.9 + 1.5 * math.sqrt(max(0.0, 1.0 - (x / 6.8) ** 2 - ((y + 0.8) / 8.2) ** 2))))
            pu = b + V((0.12 * x, 0.42 + 0.06 * (5.0 - y), 2.3 + 0.6 * (i % 3)))
            _cono(add, b, pu, 0.5, 0.08, 'limadura', 'limaduras')
    _patas(add, 'pata', ((3.5, 0.5, 6.0, 5.2), (-0.6, -0.1, 6.5, 5.6), (-4.6, -0.6, 6.0, 4.6)), r=(0.55, 0.4, 0.2))
    return e.L


# ---------- VOLADOR ----------
def _ala(add, raiz, punta, ancho, g):
    """Un ala: un elipsoide muy fino entre raiz y punta, con su nervio."""
    r = V(raiz, dtype=float); p = V(punta, dtype=float)
    add(lambda P, a=r, b=p, w=ancho: sd_ala(P, a, b, w, 0.16), 'ala', 0, g)
    _cono(add, r, p, 0.26, 0.08, 'vena', g + 'n')


Z_AIRE = 9.0


def volador_a():
    # CIERVO: en el aire, cuerpo fino, elitros abiertos en V, las alas detras y las mandibulas de ciervo delante.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _elip(add, (0, -3.0, z), (2.5, 6.0, 2.0), 'oscuro', 'vientre')
    _elip(add, (0, 3.4, z + 0.4), (3.2, 2.2, 1.9), 'ligero', 'pronoto')
    _elip(add, (0, 6.2, z), (2.1, 1.7, 1.4), 'cara', 'cabeza')
    _ojos(add, 6.8, 1.8, z + 0.5, 0.8)
    for s in (-1, 1):
        pts = [V((1.0 * s, 7.2, z)), V((2.6 * s, 8.4, z + 0.6)), V((3.5 * s, 10.6, z + 1.0)), V((2.0 * s, 12.6, z + 1.0))]
        _curva(add, pts, 1.0, 0.25, 'cuerno', 'mand%d' % s)
        # El elitro, abierto en V hacia arriba y fuera.
        _ala_dura(add, (1.8 * s, 2.0, z + 1.6), (6.8 * s, -4.6, z + 5.0), 2.4, 'ligero', 'elitro%d' % s)
        # Las alas de verdad, largas, detras.
        _ala(add, (1.4 * s, 1.0, z + 0.8), (14.5 * s, -5.0, z + 2.4), 3.0, 'ala%d' % s)
        # Las patas, colgando.
        for k, y0 in enumerate((3.0, 0.0, -3.0)):
            _cono(add, (1.8 * s, y0, z - 1.0), (3.4 * s, y0 - 0.5, z - 3.6), 0.4, 0.28, 'pata', 'pata%d%d' % (s, k))
            _cono(add, (3.4 * s, y0 - 0.5, z - 3.6), (3.2 * s, y0 - 1.2, z - 6.0), 0.28, 0.12, 'pata', 'pata%d%d' % (s, k))
    return e.L


def volador_b():
    # FLECHA: larguisimo y estrecho, con cuatro alas hacia atras; todo apunta adelante.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _elip(add, (0, -5.5, z), (1.7, 8.5, 1.5), 'ligero', 'elitros')
    _elip(add, (0, -5.5, z), (0.2, 8.6, 1.6), 'costura', 'costura')
    _elip(add, (0, 4.0, z + 0.2), (2.4, 2.6, 1.6), 'ligero', 'pronoto')
    _elip(add, (0, 7.2, z), (1.6, 1.5, 1.2), 'cara', 'cabeza')
    _ojos(add, 7.8, 1.4, z + 0.4, 0.75)
    _curva(add, [V((0, 8.0, z + 0.2)), V((0, 10.4, z + 0.5)), V((0, 13.2, z + 0.8))], 0.8, 0.14, 'cuerno', 'cuerno')
    for s in (-1, 1):
        _ala(add, (1.2 * s, 3.0, z + 0.6), (13.0 * s, -6.5, z + 1.6), 2.6, 'alad%d' % s)
        _ala(add, (1.2 * s, 0.0, z + 0.4), (10.0 * s, -11.5, z + 1.0), 2.3, 'alat%d' % s)
        for k, y0 in enumerate((3.6, 0.6, -2.4)):
            _cono(add, (1.2 * s, y0, z - 0.9), (2.0 * s, y0 - 2.2, z - 2.2), 0.3, 0.14, 'pata', 'pata%d%d' % (s, k))
    return e.L


def volador_c():
    # CUCHILLAS: los elitros son dos hojas de metal abiertas en cruz; alas cortas y patas recogidas.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _elip(add, (0, -1.8, z), (3.0, 4.6, 2.3), 'oscuro', 'vientre')
    _elip(add, (0, 3.2, z + 0.4), (3.0, 2.2, 1.9), 'ligero', 'pronoto')
    _elip(add, (0, 5.8, z), (1.9, 1.6, 1.4), 'cara', 'cabeza')
    _ojos(add, 6.4, 1.7, z + 0.5, 0.8)
    _cono(add, (0, 6.6, z + 0.5), (0, 9.6, z + 2.0), 0.9, 0.12, 'hoja', 'cuerno')
    for s in (-1, 1):
        # La hoja, larga y afilada, casi horizontal.
        _ala_dura(add, (1.8 * s, 2.0, z + 1.4), (14.0 * s, 3.4, z + 2.4), 2.2, 'hoja', 'hoja%d' % s)
        _ala(add, (1.4 * s, -1.0, z + 0.8), (8.5 * s, -7.0, z + 1.0), 2.4, 'ala%d' % s)
        for k, y0 in enumerate((2.6, 0.0, -2.6)):
            _cono(add, (2.0 * s, y0, z - 1.2), (2.6 * s, y0 - 1.0, z - 2.6), 0.42, 0.2, 'pata', 'pata%d%d' % (s, k))
    return e.L


def _ala_dura(add, raiz, punta, ancho, mat, g):
    r = V(raiz, dtype=float); p = V(punta, dtype=float)
    add(lambda P, a=r, b=p, w=ancho: sd_ala(P, a, b, w, 0.38), mat, 0, g)


# ---------- 04/11, ELIGIO IMAN A Y VOLADOR A ("se puede mejorar", "que parezca mas un iman god") ----------
def _cuerpo_iman(add):
    _elip(add, (0, -5.5, 3.2), (4.2, 4.4, 3.0), 'hierro', 'elitros')
    _elip(add, (0, -5.5, 3.2), (0.26, 4.5, 3.1), 'costura', 'costura')
    _elip(add, (0, -1.0, 2.6), (2.6, 1.5, 1.8), 'oscuro', 'cintura')
    _elip(add, (0, 1.6, 3.2), (5.0, 2.8, 2.7), 'hierro', 'pronoto')
    _elip(add, (0, 4.6, 2.8), (2.6, 1.8, 1.7), 'cara', 'cabeza')
    _ojos(add, 4.4, 2.7, 3.6)
    _patas(add, 'pata', ((3.0, 0.6, 7.5, 3.0), (-1.2, -0.2, 8.5, 2.6), (-5.0, -0.8, 8.0, 2.4)))


def iman_a1():
    # REDONDO: un solo arco en U, del mismo grueso de punta a punta, y los polos de metal mas gordos y con su corte.
    e = Escena({}); add = e.add
    _cuerpo_iman(add)
    R = 5.6; yc = 11.0; z = 3.4
    pts = [V((R * math.cos(t), yc - R * math.sin(t), z)) for t in np.linspace(0.0, math.pi, 13)]
    _curva(add, pts, 1.9, 1.9, 'rojo', 'iman')
    for s in (-1, 1):
        _cono(add, (R * s, yc, z), (R * s, yc + 2.0, z), 1.9, 1.9, 'rojo', 'iman')
        _cono(add, (R * s, yc + 2.0, z), (R * s, yc + 2.5, z), 2.05, 2.05, 'cara', 'corte%d' % s)
        _cono(add, (R * s, yc + 2.5, z), (R * s, yc + 5.2, z), 2.0, 2.0, 'polo', 'punta%d' % s)
    return e.L


def iman_a2():
    # DE DIBUJOS: el iman de los tebeos, de piezas rectas y canto cuadrado; se lee como iman a cualquier tamaño.
    e = Escena({}); add = e.add
    _cuerpo_iman(add)
    ej = [V((1.0, 0, 0)), V((0, 1.0, 0)), V((0, 0, 1.0))]
    z = 3.4
    add(lambda P, c=V((0, 7.6, z)), m=(7.4, 1.9, 1.9): sd_caja(P, c, ej, m, 0.5), 'rojo', 0, 'iman')
    for s in (-1, 1):
        add(lambda P, c=V((5.6 * s, 11.0, z)), m=(1.8, 3.2, 1.9): sd_caja(P, c, ej, m, 0.4), 'rojo', 0, 'iman')
        add(lambda P, c=V((5.6 * s, 14.2, z)), m=(1.95, 0.25, 2.05): sd_caja(P, c, ej, m, 0.05), 'oscuro', 0, 'corte%d' % s)
        add(lambda P, c=V((5.6 * s, 16.0, z)), m=(1.8, 1.6, 1.9): sd_caja(P, c, ej, m, 0.3), 'polo', 0, 'punta%d' % s)
    return e.L


def _ala_nervada(add, raiz, punta, ancho, g):
    _ala(add, raiz, punta, ancho, g)
    r = V(raiz, dtype=float); p = V(punta, dtype=float)
    d = p - r
    lado = np.cross(V((0, 0, 1.0)), d); lado = lado / np.linalg.norm(lado)
    for f, o in ((0.62, 0.62), (0.70, -0.62), (0.42, 0.72), (0.48, -0.72)):
        _cono(add, r + d * 0.12, r + d * f + lado * ancho * o, 0.2, 0.07, 'vena', g + 'n')


def _cuerpo_volador(add, z, s):
    pts = [V((1.0 * s, 7.2, z)), V((3.0 * s, 8.4, z + 0.7)), V((4.3 * s, 10.8, z + 1.2)), V((3.4 * s, 13.2, z + 1.5)), V((1.5 * s, 14.2, z + 1.4))]
    _curva(add, pts, 1.15, 0.22, 'cuerno', 'mand%d' % s)
    _cono(add, (4.0 * s, 10.0, z + 1.0), (2.4 * s, 10.9, z + 1.2), 0.5, 0.12, 'cuerno', 'mand%d' % s)
    for k, y0 in enumerate((3.0, 0.0, -3.0)):
        _cono(add, (1.8 * s, y0, z - 1.0), (3.8 * s, y0 - 0.5, z - 3.4), 0.42, 0.3, 'pata', 'pata%d%d' % (s, k))
        _cono(add, (3.8 * s, y0 - 0.5, z - 3.4), (3.4 * s, y0 - 1.5, z - 6.2), 0.3, 0.1, 'pata', 'pata%d%d' % (s, k))


def _abdomen_anillado(add, z):
    _elip(add, (0, -4.0, z), (2.6, 6.6, 2.0), 'oscuro', 'vientre')
    for y in (-1.4, -3.6, -5.8, -8.0):
        _elip(add, (0, y, z + 0.2), (2.75 - 0.2 * abs(y + 1.4), 0.6, 2.05 - 0.1 * abs(y + 1.4)), 'ligero', 'anillo')


def volador_a1():
    # ALAS A LO ANCHO: nervios en las alas y abdomen anillado; las mandibulas, mayores y con su diente.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _abdomen_anillado(add, z)
    _elip(add, (0, 3.4, z + 0.4), (3.3, 2.3, 2.0), 'ligero', 'pronoto')
    _elip(add, (0, 6.2, z), (2.2, 1.7, 1.4), 'cara', 'cabeza')
    _ojos(add, 6.8, 1.9, z + 0.5, 0.85)
    for s in (-1, 1):
        _cuerpo_volador(add, z, s)
        _ala_dura(add, (1.8 * s, 2.0, z + 1.6), (6.4 * s, -5.6, z + 5.4), 2.5, 'ligero', 'elitro%d' % s)
        _ala_nervada(add, (1.4 * s, 1.0, z + 0.8), (16.0 * s, -4.6, z + 2.6), 3.4, 'ala%d' % s)
    return e.L


def volador_a2():
    # ALAS ARRIBA: en pleno aleteo, las alas suben en V por encima del cuerpo y los elitros se abren mas: mas ganas de volar.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _abdomen_anillado(add, z)
    _elip(add, (0, 3.4, z + 0.4), (3.3, 2.3, 2.0), 'ligero', 'pronoto')
    _elip(add, (0, 6.2, z), (2.2, 1.7, 1.4), 'cara', 'cabeza')
    _ojos(add, 6.8, 1.9, z + 0.5, 0.85)
    for s in (-1, 1):
        _cuerpo_volador(add, z, s)
        _ala_dura(add, (1.8 * s, 2.0, z + 1.6), (9.0 * s, -2.6, z + 4.4), 2.4, 'ligero', 'elitro%d' % s)
        _ala_nervada(add, (1.4 * s, 0.4, z + 1.0), (11.5 * s, -8.0, z + 9.5), 3.3, 'ala%d' % s)
    return e.L


def _volador_base(add, z):
    _elip(add, (0, -3.0, z), (2.5, 6.0, 2.0), 'oscuro', 'vientre')
    _elip(add, (0, 3.4, z + 0.4), (3.2, 2.2, 1.9), 'ligero', 'pronoto')
    _elip(add, (0, 6.2, z), (2.1, 1.7, 1.4), 'cara', 'cabeza')
    _ojos(add, 6.8, 1.8, z + 0.5, 0.8)
    for s in (-1, 1):
        pts = [V((1.0 * s, 7.2, z)), V((2.6 * s, 8.4, z + 0.6)), V((3.5 * s, 10.6, z + 1.0)), V((2.0 * s, 12.6, z + 1.0))]
        _curva(add, pts, 1.0, 0.25, 'cuerno', 'mand%d' % s)
        _ala(add, (1.4 * s, 1.0, z + 0.8), (14.5 * s, -5.0, z + 2.4), 3.0, 'ala%d' % s)
        for k, y0 in enumerate((3.0, 0.0, -3.0)):
            _cono(add, (1.8 * s, y0, z - 1.0), (3.4 * s, y0 - 0.5, z - 3.6), 0.4, 0.28, 'pata', 'pata%d%d' % (s, k))
            _cono(add, (3.4 * s, y0 - 0.5, z - 3.6), (3.2 * s, y0 - 1.2, z - 6.0), 0.28, 0.12, 'pata', 'pata%d%d' % (s, k))


def _elitro_concha(add, s, z, nervio, mat='ligero'):
    # LA CONCHA ("no esta marcado que esta doblado para arriba"): no una lamina sino media cascara. Por debajo, la cara de
    # dentro, oscura y algo mayor, que asoma por el borde; encima, la cara de fuera, abombada, que coge luz y sombra.
    r = (1.8 * s, 2.0, z + 1.6)
    t = (6.8 * s, -4.6, z + 5.0)
    add(lambda P, a=V(r, dtype=float) + V((0, 0, -0.9)), b=V(t, dtype=float) + V((0.5 * s, -0.4, -1.1)), w=2.75: sd_ala(P, a, b, w, 0.42),
        'costura', 0, 'dentro%d' % s)
    add(lambda P, a=V(r, dtype=float), b=V(t, dtype=float), w=2.4: sd_ala(P, a, b, w, 1.05), mat, 0, 'elitro%d' % s)
    if nervio:
        # El nervio que recorre la concha por lo alto: la raya que dice por donde se dobla.
        ri = V(r, dtype=float); ti = V(t, dtype=float)
        pts = [ri + (ti - ri) * f + V((0.3 * s, 0.2, 1.05 * math.sin(math.pi * f) + 0.05)) for f in (0.08, 0.3, 0.55, 0.8, 0.96)]
        _curva(add, pts, 0.24, 0.12, 'costura', 'nervio%d' % s)


def volador_c1():
    e = Escena({}); add = e.add
    _volador_base(add, Z_AIRE)
    for s in (-1, 1):
        _elitro_concha(add, s, Z_AIRE, False)
    return e.L


def volador_c2():
    e = Escena({}); add = e.add
    _volador_base(add, Z_AIRE)
    for s in (-1, 1):
        _elitro_concha(add, s, Z_AIRE, True)
    return e.L


# ---------- LA MEZCLA (04/11, eligio "ramas que se juntan"): el Volador y el Iman en un cuerpo ----------
def _iman_u(add, z, R=5.6, yc=11.0, g=1.9, largo=2.0, polo=2.7):
    pts = [V((R * math.cos(t), yc - R * math.sin(t), z)) for t in np.linspace(0.0, math.pi, 13)]
    _curva(add, pts, g, g, 'rojo', 'iman')
    for s in (-1, 1):
        _cono(add, (R * s, yc, z), (R * s, yc + largo, z), g, g, 'rojo', 'iman')
        _cono(add, (R * s, yc + largo, z), (R * s, yc + largo + 0.5, z), g + 0.15, g + 0.15, 'cara', 'corte%d' % s)
        _cono(add, (R * s, yc + largo + 0.5, z), (R * s, yc + largo + 0.5 + polo, z), g + 0.1, g + 0.1, 'polo', 'punta%d' % s)


def _patas_colgando(add, z):
    for s in (-1, 1):
        for k, y0 in enumerate((3.0, 0.0, -3.0)):
            _cono(add, (1.8 * s, y0, z - 1.0), (3.4 * s, y0 - 0.5, z - 3.6), 0.4, 0.28, 'pata', 'pata%d%d' % (s, k))
            _cono(add, (3.4 * s, y0 - 0.5, z - 3.6), (3.2 * s, y0 - 1.2, z - 6.0), 0.28, 0.12, 'pata', 'pata%d%d' % (s, k))


def mezcla_a():
    # EL VOLADOR QUE CARGA EL IMAN: el cuerpo fino del Volador, ya de hierro, con la herradura por mandibulas.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _elip(add, (0, -3.0, z), (2.5, 6.0, 2.0), 'oscuro', 'vientre')
    _elip(add, (0, 2.4, z + 0.4), (3.2, 2.2, 1.9), 'hierro', 'pronoto')
    _elip(add, (0, 4.8, z), (2.1, 1.7, 1.4), 'cara', 'cabeza')
    _ojos(add, 4.8, 2.2, z + 0.6, 0.8)
    _iman_u(add, z + 0.6, R=4.6, yc=9.6, g=1.5, largo=1.6, polo=2.2)
    _patas_colgando(add, z)
    for s in (-1, 1):
        _ala(add, (1.4 * s, 0.4, z + 0.8), (14.5 * s, -5.6, z + 2.4), 3.0, 'ala%d' % s)
        _elitro_concha(add, s, z, True, 'hierro')
    return e.L


def mezcla_b():
    # EL IMAN QUE HA ECHADO ALAS: macizo, el cuerpo del Iman en el aire, alas enormes para poder con el peso y la U grande.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _elip(add, (0, -5.0, z + 0.2), (4.0, 4.6, 3.0), 'hierro', 'elitros')
    _elip(add, (0, -1.0, z), (2.6, 1.5, 1.8), 'oscuro', 'cintura')
    _elip(add, (0, 1.6, z + 0.2), (5.0, 2.8, 2.7), 'hierro', 'pronoto')
    _elip(add, (0, 4.6, z - 0.2), (2.6, 1.8, 1.7), 'cara', 'cabeza')
    _ojos(add, 4.4, 2.7, z + 0.6)
    _iman_u(add, z + 0.4)
    _patas_colgando(add, z)
    for s in (-1, 1):
        _ala(add, (2.4 * s, 0.6, z + 1.8), (17.0 * s, -5.0, z + 4.4), 3.8, 'ala%d' % s)
        _ala(add, (2.0 * s, -2.0, z + 1.2), (12.5 * s, -10.0, z + 2.2), 2.8, 'alat%d' % s)
    return e.L


def mezcla_c():
    # LOS ELITROS SON EL IMAN: las dos conchas abiertas, rojas y con las puntas de metal, forman la herradura por detras.
    e = Escena({}); add = e.add
    z = Z_AIRE
    _elip(add, (0, -3.0, z), (2.5, 6.0, 2.0), 'hierro', 'vientre')
    _elip(add, (0, 3.4, z + 0.4), (3.2, 2.2, 1.9), 'hierro', 'pronoto')
    _elip(add, (0, 6.2, z), (2.1, 1.7, 1.4), 'cara', 'cabeza')
    _ojos(add, 6.8, 1.8, z + 0.5, 0.8)
    _patas_colgando(add, z)
    for s in (-1, 1):
        pts = [V((1.0 * s, 7.2, z)), V((2.6 * s, 8.4, z + 0.6)), V((3.5 * s, 10.6, z + 1.0)), V((2.0 * s, 12.6, z + 1.0))]
        _curva(add, pts, 1.0, 0.25, 'polo', 'mand%d' % s)
        _ala(add, (1.4 * s, 1.0, z + 0.8), (14.5 * s, -2.0, z + 2.0), 3.0, 'ala%d' % s)
        pts2 = [V((1.8 * s, 2.0, z + 1.8)), V((5.0 * s, 0.6, z + 3.6)), V((6.8 * s, -2.8, z + 4.8)), V((6.8 * s, -6.8, z + 5.2))]
        _curva(add, pts2, 1.7, 1.6, 'rojo', 'elitro%d' % s)
        _cono(add, (6.8 * s, -6.8, z + 5.2), (6.8 * s, -7.3, z + 5.2), 1.75, 1.75, 'cara', 'corte%d' % s)
        _cono(add, (6.8 * s, -7.3, z + 5.2), (6.8 * s, -9.6, z + 5.2), 1.65, 1.65, 'polo', 'punta%d' % s)
    return e.L


# ---------- PIEZAS QUE NO TRAE sdf_comun ----------
def sd_ala(P, a, b, ancho, grueso):
    """Elipsoide plano entre a y b: largo a-b, 'ancho' en horizontal, 'grueso' en vertical."""
    c = (a + b) * 0.5
    e1 = (b - a); lar = np.linalg.norm(e1) * 0.5; e1 = e1 / np.linalg.norm(e1)
    e2 = np.cross(V((0, 0, 1.0)), e1); e2 = e2 / np.linalg.norm(e2)
    e3 = np.cross(e1, e2)
    d = P - c
    x = np.dot(d, e1) / lar; y = np.dot(d, e2) / ancho; z = np.dot(d, e3) / grueso
    k0 = np.sqrt(x * x + y * y + z * z)
    return (k0 - 1.0) * min(lar, ancho, grueso)


def sd_toro_plano(P, c, n, radio, grueso):
    """Anillo de eje 'n'."""
    d = P - c
    h = np.dot(d, n)
    pl = d - h[..., None] * n
    q = np.sqrt(np.sum(pl * pl, axis=-1))
    return np.sqrt((q - radio) ** 2 + h * h) - grueso


if __name__ == '__main__':
    filas = [
        ('IMAN (elegido)', iman_a1(), modelo()),
        ('VOLADOR (elegido)', volador_c2(), modelo(True)),
        ('MEZCLA A volador con iman', mezcla_a(), modelo(True)),
        ('MEZCLA B iman con alas', mezcla_b(), modelo(True)),
        ('MEZCLA C elitros de iman', mezcla_c(), modelo(True)),
    ]
    W = H = 112
    ESC = 3
    MARGEN = 170
    hoja = Image.new('RGB', (MARGEN + W * 5 * ESC, H * ESC * len(filas)), (40, 42, 50))
    dib = ImageDraw.Draw(hoja)
    for f, (nombre, L, mo) in enumerate(filas):
        dib.text((10, f * H * ESC + H * ESC // 2), nombre, fill=(235, 235, 235))
        for d in range(5):
            im = render(mo, L, d).resize((W * ESC, H * ESC), Image.NEAREST)
            hoja.paste(im, (MARGEN + d * W * ESC, f * H * ESC), im)
    os.makedirs('tools/salida/sdf', exist_ok=True)
    hoja.save('tools/salida/sdf/escarabajo_mutantes_versiones.png')
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    hoja.save(os.path.join(esc, 'escarabajo_mutantes_versiones.png'))
    print('ok', hoja.size)
