# ============================================================
#  arana_sdf.py -- la ARAÑA DE LAS SIMAS en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (arana_sprites.gd): la silueta son las OCHO PATAS, que salen a los lados y ARQUEAN POR ENCIMA DEL LOMO antes de bajar
#  al suelo; el cuerpo en dos piezas (el cefalotorax delante, bajo, y el abdomen detras, gordo y ALTO) con su cintura;
#  el racimo de ojos amarillos y los queliceros. Lienzo y origen de su horneado (1,50 -> 90 x 90, el centro).
#  HUESOS: raiz (el cuerpo: avanza, se agacha, SE ALZA sobre las traseras), abdomen (sube la punta para la telaraña) y
#  las patas, que se calculan EN EL MUNDO (los pies se quedan en el suelo mientras el cuerpo se mueve: andar a
#  tetrapodo, alzarse con las de delante en el aire, encogerse al morir).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/arana_sdf.py [anim ...]  -> assets/sprites/enemigos/arana_sdf/<anim>.png
#       python tools/sprites_sdf/arana_sdf.py vistas     -> tools/salida/sdf/arana_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/arana_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Morado ceniza (635580): el cuerpo en tres tonos, las patas mas oscuras, el dibujo del abdomen mas claro.
MAT = {
    'cuerpo':  [(0.25, 0.20, 0.34), (0.39, 0.33, 0.50), (0.52, 0.46, 0.64)],
    'pata':    [(0.16, 0.13, 0.23), (0.25, 0.21, 0.35), (0.34, 0.29, 0.46)],
    'dibujo':  [(0.52, 0.44, 0.68), (0.64, 0.56, 0.80), (0.76, 0.70, 0.90)],
    'ojo':     [(1.0, 0.85, 0.25)] * 3,
    'colmillo': [(0.80, 0.76, 0.62), (0.93, 0.90, 0.78), (0.99, 0.97, 0.88)],
}
# A 1,5 salia la mitad de grande que la vieja (aquella exageraba el tamaño): se pinta a 2,2 en el mismo lienzo.
MODELO = Modelo(2.2, (90, 90), (45, 45), MAT, (0.09, 0.07, 0.12), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True)

# Las distancias del viejo (avances) pasadas a este modelo: el cuerpo de aquel media 20,6 de largo, el de este 16,2.
K_VIEJO = 0.79
ALZA_MAX = 0.62                  # radianes a alza = 1 (el del viejo)
ALZA_PIVOTE = V((0.0, -6.0, 2.4))
ABDOMEN_MAX = 0.9                # radianes a abdomen = 1
PEDICULO = V((0.0, -0.4, 3.8))
PASO_LARGO = 3.6
PASO_ALTO = 2.4
# Las patas: (y de la coxa, angulo de abanico). Las de delante hacia delante, las de atras hacia atras.
PATAS = ((3.8, 0.55), (3.0, 0.15), (2.1, -0.25), (1.3, -0.65))
# Lo que sigue al cuerpo cada par cuando se ALZA: las de delante en el aire, las traseras clavadas.
ALZA_SIGUE = (1.0, 0.75, 0.2, 0.0)


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, alza=0.0, abdomen=0.0, estira=1.0, encoge=0.0, muerde=0.0, fase=0.0, paso=0.0)
    p.update(k)
    return p


def huesos(p):
    raiz = (np.eye(3), V((0.0, p['avance'], -p['agacha'] * 2.0)))
    raiz = comp(raiz, sobre(ALZA_PIVOTE, rx(-p['alza'] * ALZA_MAX)))
    abd = comp(raiz, sobre(PEDICULO, rx(p['abdomen'] * ABDOMEN_MAX)))
    return {'raiz': raiz, 'abdomen': abd, 'mundo': IDENT}


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _pata(p, X, s, k):
    """Coxa, rodilla, tobillo y pie de una pata, EN EL MUNDO."""
    y0, ang = PATAS[k]
    base_l = V((2.4 * s, y0, 3.2))
    d = V((math.cos(ang) * s, math.sin(ang), 0.0))
    pie_l = base_l + d * 11.6 + V((0, 0, -3.0))
    base = aplica(X['raiz'], base_l)
    # El pie en reposo: en el suelo, donde estaria con el cuerpo sin mover (salvo lo que avanza).
    pie = pie_l + V((0.0, p['avance'], 0.0))
    # ANDAR A TETRAPODO: L0 R1 L2 R3 a la vez y las otras cuatro en contrafase. Adelanta el pie en el aire.
    grupo = (k + (1 if s > 0 else 0)) % 2
    fi = 2 * math.pi * (p['fase'] + 0.5 * grupo)
    pie = pie + V((0.0, PASO_LARGO * math.sin(fi) * p['paso'], PASO_ALTO * max(0.0, math.cos(fi)) * p['paso']))
    # ALZARSE: las de delante se van con el cuerpo (al aire, amenazando).
    w = ALZA_SIGUE[k] * min(1.0, p['alza'] * 1.5)
    if w > 0.0:
        pie = pie * (1 - w) + aplica(X['raiz'], pie_l + V((0.0, 1.5 * (1 - k), 2.0))) * w
    h = pie - base
    rod = base + V((h[0], h[1], 0.0)) * 0.47 + V((0, 0, max(base[2], pie[2]) - base[2] + 5.4))
    tob = rod + (pie - rod) * 0.74
    tob[2] = pie[2] + 0.55 * (rod[2] - pie[2])
    # ENCOGERSE (morir): cada pata se ENROSCA hacia su lado -- la rodilla alta y cerca, y la punta recogida bajo el
    # vientre --, articulacion a articulacion. Juntando los pies en un punto salian las ocho en un bloque.
    e = p['encoge']
    if e > 0.0:
        rod_c = aplica(X['raiz'], base_l + d * 3.0 + V((0, 0, 4.6)))
        tob_c = aplica(X['raiz'], base_l + d * 4.4 + V((0, 0, 1.4)))
        pie_c = aplica(X['raiz'], base_l + d * 2.2 + V((0, 0, -1.6)))
        rod = rod * (1 - e) + rod_c * e
        tob = tob * (1 - e) + tob_c * e
        pie = pie * (1 - e) + pie_c * e
    return base, rod, tob, pie


def escena(pose):
    X = huesos(pose)
    e = Escena(X); add = e.add
    es = pose['estira']
    # EL CUERPO EN DOS PIEZAS, con la cintura (el pediculo) entre medias.
    _elip(add, (0, 2.6, 3.4), (3.0, 3.2, 2.1), 'cuerpo')
    _cono(add, (0, 0.2, 3.6), (0, -1.0, 3.9), 0.9, 1.0, 'cuerpo', 0.6, hueso='abdomen')
    # El ABDOMEN: 'estira' lo alarga y adelgaza (el bombeo de la telaraña), sin despegarse de la cintura.
    ry_ = 5.4 * es; rxz = 1.0 / math.sqrt(es)
    cy = -0.4 - ry_ + 0.8
    _elip(add, (0, cy, 5.4), (4.4 * rxz, ry_, 4.0 * rxz), 'cuerpo', 0.8, hueso='abdomen')
    # EL DIBUJO del lomo del abdomen: unos galones claros, un pelo por fuera.
    for u, ancho in ((0.44, 2.2), (0.11, 2.8), (-0.26, 2.4), (-0.56, 1.5)):
        y = cy + u * ry_
        _elip(add, (0, y, 5.4 + math.sqrt(max(0.0, 1 - u * u)) * 4.0 * rxz - 0.15), (ancho * rxz, 0.55, 0.35), 'dibujo', 0,
              'dibujo', 'abdomen')
    # LOS OJOS: dos grandes delante y cuatro pequeños alrededor, amarillos, en la frente.
    for s in (-1, 1):
        _elip(add, (0.9 * s, 5.2, 4.6), (0.6, 0.45, 0.55), 'ojo', 0, 'ojo')
        _elip(add, (1.9 * s, 4.6, 4.9), (0.35, 0.3, 0.35), 'ojo', 0, 'ojo')
        _elip(add, (0.5 * s, 4.6, 5.3), (0.3, 0.28, 0.3), 'ojo', 0, 'ojo')
    # LOS QUELICEROS: dos colmillos cortos que bajan por delante; 'muerde' > 0 los ABRE, < 0 los cierra (pica).
    m = pose['muerde']
    for s in (-1, 1):
        punta = V((0.6 * s + (1.3 if m > 0 else 0.5) * m * s, 6.6 + 0.4 * max(m, 0.0), 1.6 + 0.7 * max(m, 0.0)))
        _cono(add, (0.7 * s, 5.5, 3.1), punta, 0.7, 0.25, 'colmillo', 0, 'colmillo')
        # los pedipalpos, cortos, a los lados de la boca
        _cono(add, (1.6 * s, 5.0, 2.8), (2.6 * s + 0.6 * max(m, 0.0) * s, 7.0, 1.0 + 1.2 * max(m, 0.0)), 0.45, 0.3, 'pata', 0,
              'palpo')
    # LAS OCHO PATAS: de la coxa suben a la RODILLA, por encima del lomo, y bajan en tijera al suelo.
    for s in (-1, 1):
        for k in range(4):
            base, rod, tob, pie = _pata(pose, X, s, k)
            g = 'pata%d%d' % (s, k)
            _cono(add, base, rod, 1.0, 0.8, 'pata', 0, g, 'mundo')
            _cono(add, rod, tob, 0.8, 0.6, 'pata', 0, g, 'mundo')
            _cono(add, tob, pie, 0.6, 0.35, 'pata', 0, g, 'mundo')
            _elip(add, rod, (0.95, 0.95, 0.95), 'pata', 0, g, 'mundo')
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # Acecha: casi CLAVADA; las patas tantean un poco y el abdomen sube y baja. Lenta (3 fps) a proposito.
    return POSE(fase=t, paso=0.16, agacha=0.04 * (1 - math.cos(2 * math.pi * t)))


def anim_walk(t):
    # A TIRONES, el mas rapido del juego: el cuerpo apenas sube y baja, lo que se mueve son las patas.
    return POSE(fase=t, paso=1.0, agacha=0.05 * (1 - math.cos(2 * math.pi * t * 2.0)))


def anim_embestida(t):
    # SE ALZA enseñando los queliceros y se DEJA CAER encima: el avance llega tarde y de golpe.
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.34, 1.0), (0.52, 0.95), (0.72, 0.10), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.34, -1.2), (0.52, 0.4), (0.72, 7.6), (0.86, 8.0), (1.0, 5.4)]) * K_VIEJO,
                agacha=tramos(t, [(0.0, 0.0), (0.34, 0.0), (0.72, 0.30), (1.0, 0.10)]),
                muerde=tramos(t, [(0.0, 0.0), (0.34, 1.0), (0.62, 1.0), (0.74, -0.4), (1.0, 0.0)]))


def anim_telarana(t):
    # BAJA LA CABEZA Y LEVANTA EL ABDOMEN hacia el objetivo, lo bombea y dispara (el salto del 0,45 es el disparo).
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.2, 0.35), (0.45, 0.45), (0.7, 0.3), (1.0, 0.0)]),
                abdomen=tramos(t, [(0.0, 0.0), (0.25, 0.9), (0.4, 1.0), (0.5, 0.82), (0.7, 0.85), (1.0, 0.0)]),
                estira=tramos(t, [(0.0, 1.0), (0.3, 0.9), (0.4, 0.86), (0.45, 1.1), (0.6, 1.02), (1.0, 1.0)]))


def anim_basico(t):
    # Se alza un poco con los queliceros abiertos, un pasito adelante y PICA (cierra) en el 0,45.
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.3, 0.5), (0.45, 0.12), (0.65, 0.08), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.3, -0.6), (0.45, 2.6), (0.65, 2.3), (1.0, 0.0)]) * K_VIEJO,
                muerde=tramos(t, [(0.0, 0.0), (0.3, 1.0), (0.42, 0.9), (0.47, -0.4), (0.7, -0.3), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.0), (0.45, 0.25), (1.0, 0.0)]))


def anim_mordisco(t):
    # EL PONZOÑOSO: el mismo, mas alta y mas adelante, y al clavar se queda apretando (el veneno entra).
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.28, 0.75), (0.42, 0.15), (0.75, 0.1), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.28, -0.9), (0.42, 3.6), (0.75, 3.3), (1.0, 0.4)]) * K_VIEJO,
                muerde=tramos(t, [(0.0, 0.0), (0.28, 1.2), (0.38, 1.1), (0.44, -0.5), (0.75, -0.45), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.28, 0.0), (0.42, 0.35), (0.75, 0.3), (1.0, 0.0)]))


def anim_encaje(t):
    # Empieza YA golpeada: sale despedida (pesa poco) con las patas recogidas a medias.
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.42), (0.67, 0.10), (1.0, 0.0)]) * 8.0 * 0.55 * K_VIEJO,
                agacha=tramos(t, [(0.0, 0.70), (0.34, 0.10), (0.67, 0.02), (1.0, 0.0)]),
                encoge=tramos(t, [(0.0, 0.26), (0.34, 0.12), (0.67, 0.03), (1.0, 0.0)]))


def anim_muerte(t):
    # SE ENCOGE: las ocho patas se cierran sobre el vientre, con un ULTIMO ESPASMO (el 0,72) antes de cerrarse.
    return POSE(encoge=tramos(t, [(0.0, 0.0), (0.16, 0.28), (0.38, 0.66), (0.56, 0.88), (0.72, 0.74), (0.86, 1.0),
                                  (1.0, 1.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.16, 0.45), (0.38, 0.85), (0.56, 1.0), (1.0, 1.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.16, 0.34), (0.38, 0.06), (1.0, 0.0)]))


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo.
ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 11.0, True, 8, anim_walk),
    'embestida': (8, 11.0, False, 8, anim_embestida),
    'telarana': (10, 12.0, False, 8, anim_telarana),
    'basico': (8, 16.0, False, 8, anim_basico),
    'mordisco': (10, 14.0, False, 8, anim_mordisco),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'arana_635580_1.50', VISTAS + 'arana_vs_viejo.png', 4))
    else:
        hornear('arana_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
