# ============================================================
#  escarabajo_sdf.py -- el ESCARABAJO DE HIERRO en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del
#  viejo (escarabajo_sprites.gd): LO CONTRARIO DE LA ARAÑA, un DOMO BAJO Y ANCHO (los elitros, con su raja) con la placa
#  del cuello (pronoto), la cabeza y la PALA plana delante -- empuja, no pincha --, y seis patas cortas que casi no se
#  ven. Lo de "hierro" es el BRILLO: un reflejo duro y claro sobre el lomo (el especular del motor). Lienzo y origen de
#  su horneado (1,50 -> 80 x 80, el centro).
#  HUESOS: solo la raiz, que lo lleva todo: se APLASTA (agacha: mas bajo y algo mas ancho), se acorta (estira), se pone
#  de COSTADO (rumbo) y RUEDA sobre su eje morro-grupa (tumba, en cuartos de vuelta), levantandose lo justo para rodar
#  SOBRE el suelo (el apoyo se saca de la geometria, no a ojo). Lo demas es forma: 'bola' redondea el domo y mete la
#  cabeza, 'encoge' guarda las patas, 'cielo' las pone tiesas (muerto, panza arriba).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/escarabajo_sdf.py [anim ...]  -> assets/sprites/enemigos/escarabajo_sdf/<anim>.png
#       python tools/sprites_sdf/escarabajo_sdf.py vistas     -> tools/salida/sdf/escarabajo_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/escarabajo_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Verde oliva (5c8055); el caparazon con su cuarto tono, el reflejo de metal.
MAT = {
    'caparazon': [(0.22, 0.31, 0.20), (0.36, 0.50, 0.33), (0.48, 0.63, 0.44), (0.86, 0.94, 0.82)],
    'oscuro':    [(0.12, 0.17, 0.11), (0.18, 0.25, 0.16), (0.26, 0.34, 0.22)],
    'pata':      [(0.14, 0.19, 0.12), (0.22, 0.29, 0.18), (0.30, 0.38, 0.25)],
    'ojo':       [(1.0, 0.80, 0.30)] * 3,
}
# Algo mayor que su escala (1,5): el viejo exageraba el tamaño, como el de la araña.
MODELO = Modelo(2.1, (80, 80), (40, 40), MAT, (0.06, 0.09, 0.05), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True,
                especular=('caparazon',), umbral_especular=0.975)

# Las distancias del viejo pasadas a este modelo (aquel media 23,5 de largo, este 17,6).
K_VIEJO = 0.75
LUNGE_DIST = 9.5
ENCAJE_RETRO = 0.22
PASO_LARGO = 1.8
PASO_ALTO = 1.1
PATAS = ((3.6, 0.6), (0.4, 0.0), (-3.2, -0.6))


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, estira=1.0, rumbo=0.0, tumba=0.0, bola=0.0, encoge=0.0, cielo=0.0, antena=0.0,
             fase=0.0, paso=0.0)
    p.update(k)
    return p


def _domo(b):
    """El elipsoide que envuelve el caparazon (centro, radios), con lo que lo redondea 'bola'."""
    return V((0.0, -1.4, 3.3 + 1.9 * b)), V((6.05 - 0.5 * b, 6.0 - 1.0 * b, 3.3 + 1.9 * b))


def huesos(p):
    # Aplastarse y acortarse (escala suave: aplastar mucho con el hueso agujerea el raymarch).
    S = np.diag([1.0 + 0.06 * p['agacha'], p['estira'], 1.0 - 0.26 * p['agacha']])
    X = (S, np.zeros(3))
    c, r = _domo(p['bola'])
    c = S @ c
    # RUEDA sobre su eje morro-grupa (alrededor del centro del domo) y se pone de COSTADO (gira sobre la vertical).
    X = comp(sobre(c, ry(p['tumba'] * math.pi * 0.5)), X)
    X = comp(sobre(V((0.0, -1.4, 0.0)), rz(p['rumbo'])), X)
    # EL APOYO: lo que hay que subirlo para que lo mas bajo del domo quede a ras de suelo, y no dentro.
    M = X[0]
    cz = (M @ _domo(p['bola'])[0] + X[1])[2]
    medio = math.sqrt(sum((M[2, j] * r[j]) ** 2 for j in range(3)))
    apoyo = max(0.0, medio - cz)
    X = comp((np.eye(3), V((0.0, p['avance'], apoyo))), X)
    return {'raiz': X}


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena(pose):
    e = Escena(huesos(pose)); add = e.add
    b = pose['bola']
    sube = 1.9 * b
    # LOS ELITROS: el domo, ANCHO y BAJO, y la RAJA del medio (dos mitades que casi se tocan: la linea oscura).
    # Hecho bola: mas alto y mas corto, casi redondo.
    for s in (-1, 1):
        _elip(add, (2.75 * s - 1.5 * b * s, -1.4, 3.3 + sube), (3.3 + 1.0 * b, 6.0 - 1.0 * b, 3.3 + sube), 'caparazon', 0,
              'elitro%d' % s)
    _elip(add, (0, -1.4, 2.2 + 1.2 * b), (5.8 - 0.6 * b, 5.8 - 1.0 * b, 2.1 + 2.0 * b), 'oscuro', 0, 'vientre')
    # EL PRONOTO: la placa del cuello, mas estrecha, y LA CABEZA. Hecho bola, la cabeza se mete dentro.
    mete = V((0.0, -3.4 * b, 1.6 * b))
    _elip(add, V((0, 4.6, 3.0)) + mete, (3.8, 2.6, 2.5 + 0.8 * b), 'caparazon', 0, 'pronoto')
    _elip(add, V((0, 7.0, 2.2)) + mete * 1.1, (2.3, 1.8, 1.6), 'oscuro', 0, 'cabeza')
    # LA PALA: plana y ancha, por delante de la cabeza, algo levantada.
    cpala = V((0, 8.8, 1.8)) + mete * 1.2
    add(lambda P, c=cpala: sd_caja(P, c, [V((1, 0, 0)), V((0, 0.94, 0.34)), V((0, -0.34, 0.94))], (3.2, 1.4, 0.35), 0.3),
        'caparazon', 0, 'pala')
    # Los ojos y las antenas se guardan los primeros al cerrarse.
    if b < 0.6:
        a = pose['antena']
        for s in (-1, 1):
            _elip(add, V((1.5 * s, 7.9, 2.7)) + mete, (0.45, 0.4, 0.4), 'ojo', 0, 'ojo')
            # las antenas, cortas y acodadas; 'antena' las mueve tanteando
            codo = V((3.0 * s, 8.6, 3.4 + 0.5 * a)) + mete
            punta = codo + V((0.6 * s + 0.4 * a * s, 1.2 - 0.3 * abs(a), 0.2 + 0.6 * a))
            _cono(add, V((1.6 * s, 7.6, 2.4)) + mete, codo, 0.3, 0.25, 'pata', 0, 'antena')
            _cono(add, codo, punta, 0.25, 0.4, 'pata', 0, 'antena')
    # LAS SEIS PATAS: cortas, en dos tramos, que asoman por debajo del borde del caparazon.
    # Andan a TRIPODE ALTERNO (L0 R1 L2 a la vez, las otras tres en contrafase).
    centro = V((0.0, -1.4, 3.3 + sube))
    en = pose['encoge']; ci = pose['cielo']
    for s in (-1, 1):
        for k, (y0, ang) in enumerate(PATAS):
            base = V((4.6 * s, y0, 1.6 + 0.6 * b))
            d = V((math.cos(ang) * s, math.sin(ang), 0.0))
            grupo = (k + (1 if s > 0 else 0)) % 2
            fi = 2 * math.pi * (pose['fase'] + 0.5 * grupo)
            paso = V((0.0, PASO_LARGO * math.sin(fi), PASO_ALTO * max(0.0, math.cos(fi)))) * pose['paso']
            rod = base + d * 2.6 + V((0, 0, 0.9)) + paso * 0.5
            pie = base + d * 4.6 + V((0, 0, -1.4)) + paso
            # PATAS AL CIELO (muerto panza arriba): tiesas y dobladas hacia lo que ahora es arriba.
            if ci > 0.0:
                rod = rod * (1 - ci) + (base + d * 1.8 + V((0, 0, -1.6))) * ci
                pie = pie * (1 - ci) + (base + d * 1.2 + V((0, 0, -4.2))) * ci
            # GUARDADAS (caparazon, bola): se recogen hacia dentro del domo.
            if en > 0.0:
                rod = rod + (centro - rod) * 0.6 * en
                pie = pie + (centro - pie) * 0.7 * en
                base = base + (centro - base) * 0.3 * en
            _cono(add, base, rod, 0.6, 0.5, 'pata', 0, 'pata%d%d' % (s, k))
            _cono(add, rod, pie, 0.5, 0.3, 'pata', 0, 'pata%d%d' % (s, k))
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # Respira y tantea con las antenas: es una placa de metal, lo unico vivo son las antenas.
    return POSE(estira=1.0 + 0.015 * math.sin(2 * math.pi * t), fase=t, paso=0.10, antena=math.sin(2 * math.pi * t))


def anim_walk(t):
    # TRIPODE ALTERNO, lento y pesado; el caparazon apenas cabecea.
    return POSE(fase=t, paso=1.0, agacha=0.04 * (1 - math.cos(2 * math.pi * t * 2.0)), antena=0.4 * math.sin(2 * math.pi * t))


def anim_embestida(t):
    # SE APLASTA y sale ARRASTRANDO su peso con la pala: el avance arranca tarde pero no se para.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.26, 1.0), (0.46, 0.85), (0.74, 0.30), (1.0, 0.12)]),
                avance=tramos(t, [(0.0, 0.0), (0.26, -1.4), (0.46, 1.6), (0.74, 8.4), (0.88, 9.5), (1.0, 6.8)])
                * (LUNGE_DIST / 9.5) * K_VIEJO)


def anim_basico(t):
    # EL PALAZO: se agacha echandose atras y empuja de golpe con la pala (en la mitad), corto y seco.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.3, -1.6), (0.5, 4.6), (0.7, 3.6), (1.0, 0.0)]) * K_VIEJO,
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.7), (0.5, 0.15), (0.7, 0.25), (1.0, 0.0)]),
                estira=tramos(t, [(0.0, 1.0), (0.3, 0.96), (0.5, 1.08), (0.7, 1.04), (1.0, 1.0)]))


def anim_caparazon(t):
    # Un respingo, se deja caer, y DESPUES mete las patas y la cabeza: una PIEDRA LISA.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.143, -0.12), (0.286, 0.55), (0.429, 0.88), (0.571, 1.0), (0.857, 1.0),
                                  (1.0, 0.96)]),
                encoge=tramos(t, [(0.0, 0.0), (0.143, 0.0), (0.286, 0.30), (0.429, 0.75), (0.571, 1.0), (0.857, 1.0),
                                  (1.0, 0.94)]),
                estira=tramos(t, [(0.0, 1.0), (0.143, 1.02), (0.286, 0.95), (0.429, 0.90), (0.571, 0.88), (0.857, 0.88),
                                  (1.0, 0.89)]),
                antena=tramos(t, [(0.0, 0.6), (0.143, 0.2), (0.286, 0.0), (1.0, 0.0)]))


# LA BOLA: patas dentro, de costado para rodar como una rueda, un poco agachado.
def _pose_bola(cierra, tumba=0.0, avance=0.0, agacha=0.3):
    return POSE(encoge=cierra, bola=cierra, rumbo=math.pi * 0.5 * cierra, tumba=tumba, avance=avance,
                agacha=agacha, antena=0.6 * (1 - cierra), estira=1.0 - 0.2 * cierra)


def anim_hacerse_bola(t):
    return _pose_bola(tramos(t, [(0.0, 0.0), (0.4, 0.55), (0.8, 1.0), (1.0, 1.0)]), 0.0, 0.0,
                      tramos(t, [(0.0, 0.0), (0.4, 0.75), (1.0, 0.3)]))


def anim_bola(t):
    # Se mece adelante y atras cogiendo carrerilla (en bucle).
    s = math.sin(2 * math.pi * t)
    return _pose_bola(1.0, -0.35 * s, -1.2 * (0.5 + 0.5 * s) * K_VIEJO, 0.3 + 0.1 * (0.5 + 0.5 * s))


RODAR_MARCOS = 8
RODAR_PLANTARSE = 4


def anim_rodar(t):
    # DOS VUELTAS a 90 grados por marco (la pelea lo lleva por la linea) y luego se desenrosca y se planta.
    total = RODAR_MARCOS + RODAR_PLANTARSE
    i = t * (total - 1)
    if i <= RODAR_MARCOS:
        return _pose_bola(1.0, 8.0 * i / RODAR_MARCOS)
    k = (i - RODAR_MARCOS) / (RODAR_PLANTARSE - 1)
    return _pose_bola(1.0 - k, 0.0, 0.0, 0.3 * (1 - k) + 0.25 * math.sin(math.pi * k))


def anim_desenroscarse(t):
    return _pose_bola(1.0 - t, 0.0, 0.0, 0.3 * (1 - t))


def anim_muerte(t):
    # PATAS ARRIBA: da la vuelta entera (con un BOTE al llegar) y las patas se quedan tiesas al cielo.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.16, 0.6), (0.34, 0.9), (0.62, 0.5), (1.0, 0.35)]),
                tumba=tramos(t, [(0.0, 0.0), (0.16, 0.14), (0.34, 0.62), (0.50, 1.30), (0.62, 2.14), (0.76, 1.92),
                                 (0.88, 2.04), (1.0, 2.0)]),
                rumbo=tramos(t, [(0.0, 0.0), (0.16, 0.10), (0.34, 0.40), (0.50, 0.68), (0.70, 0.82), (1.0, 0.85)])
                * math.pi * 0.5,
                cielo=tramos(t, [(0.0, 0.0), (0.34, 0.35), (0.62, 0.85), (1.0, 1.0)]))


def anim_encaje(t):
    # Empieza YA golpeado: APENAS se mueve, se hunde sobre las patas y vuelve (es una mole).
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.40), (0.67, 0.10), (1.0, 0.0)]) * LUNGE_DIST * ENCAJE_RETRO * K_VIEJO,
                agacha=tramos(t, [(0.0, 0.85), (0.34, 0.22), (0.67, 0.06), (1.0, 0.0)]))


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo.
ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 7.0, True, 8, anim_walk),
    'embestida': (8, 10.0, False, 8, anim_embestida),
    'basico': (6, 16.0, False, 8, anim_basico),
    'caparazon': (8, 9.0, False, 8, anim_caparazon),
    'hacerse_bola': (6, 12.0, False, 8, anim_hacerse_bola),
    'bola': (8, 8.0, True, 8, anim_bola),
    'rodar': (RODAR_MARCOS + RODAR_PLANTARSE, 18.0, False, 8, anim_rodar),
    'desenroscarse': (5, 12.0, False, 8, anim_desenroscarse),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'escarabajo_5c8055_1.50', VISTAS + 'escarabajo_vs_viejo.png', 4))
    else:
        hornear('escarabajo_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
