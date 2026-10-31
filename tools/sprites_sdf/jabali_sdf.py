# ============================================================
#  jabali_sdf.py -- el JABALI en 3D (02-03/10/2026; la prueba le gusto: "mucho mas wapos"). Con el motor del Minotauro
#  (sdf_comun). HUESOS: raiz (avanza, se agacha, se ladea, se empina sobre las traseras, cae de lado al morir), cabeza
#  (sube y baja sobre la nuca y se estira) y las cuatro patas (balanceo sobre el hombro/anca).
#  LOS TIEMPOS de cada gesto, los del viejo (jabali_sprites.gd), para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/jabali_sdf.py [anim ...]  -> assets/sprites/enemigos/jabali_sdf/<anim>.png
#       python tools/sprites_sdf/jabali_sdf.py vistas     -> tools/salida/sdf/jabali_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/jabali_sdf/'
VISTAS = 'tools/salida/sdf/'
ESTIRA = 1.08

def Z(x, y, z):
    return np.array([x, y, z * ESTIRA], dtype=float)

MAT = {
    'piel':   [(0.36, 0.24, 0.18), (0.50, 0.34, 0.24), (0.62, 0.44, 0.31)],
    'crin':   [(0.17, 0.11, 0.08), (0.25, 0.17, 0.12), (0.33, 0.23, 0.17)],
    'morro':  [(0.56, 0.38, 0.34), (0.72, 0.52, 0.46), (0.84, 0.64, 0.57)],
    'marfil': [(0.78, 0.74, 0.60), (0.93, 0.90, 0.78), (0.99, 0.97, 0.88)],
    'pezuna': [(0.10, 0.08, 0.08), (0.17, 0.14, 0.13), (0.25, 0.21, 0.19)],
    'ojo':    [(0.95, 0.92, 0.84), (0.95, 0.92, 0.84), (0.98, 0.96, 0.90)],
    'pupila': [(0.06, 0.03, 0.02), (0.06, 0.03, 0.02), (0.06, 0.03, 0.02)],
}
# El lienzo y los pies del generador viejo (88 x 88, pies a ~49): el juego lo coloca igual.
MODELO = Modelo(1.7, (88, 88), (44, 49), MAT, (0.11, 0.07, 0.05), suaves=('cuerpo',), brillan=('ojo', 'pupila'),
                estira=ESTIRA, corta_suelo=True)


NUCA = Z(0, 8.0, 9.0)
ANCA = Z(0, -8.0, 0.0)        # donde se apoya al empinarse (las traseras)

def POSE(**k):
    # 'evo' (los mutantes): la TRANSFORMACION hasta su hoja: 0 = aun es lo que era, 1 = ya es el mutante.
    p = dict(avance=0.0, agacha=0.0, cabeza=0.0, estira=1.0, tumba=0.0, empina=0.0, escarba=0.0, patas=0.0,
             paso=0.0, muere=0.0, evo=1.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    # 'agacha' y 'cabeza' en las unidades del viejo: agacha 1 = el cuerpo baja ~2,4; cabeza +-1 = ~0,09 rad (+ arriba).
    raiz = (np.eye(3), np.array([0.0, p['avance'], -p['agacha'] * 2.4 * ESTIRA]))
    raiz = comp(raiz, sobre(Z(0, 0, 0), ry(p['tumba'] * math.pi * 0.5)))
    raiz = comp(raiz, sobre(ANCA, rx(-p['empina'])))
    # MORIR: cae de lado, girando sobre el canto de las patas de su derecha.
    if p['muere'] > 0.0:
        raiz = comp(sobre(np.array([-6.0, 0.0, 0.0]), ry(-p['muere'] * math.pi * 0.5)), raiz)
    X['raiz'] = raiz
    X['cabeza'] = comp(raiz, comp((np.eye(3), np.array([0.0, (p['estira'] - 1.0) * 10.0, 0.0])),
                                  sobre(NUCA, rx(-p['cabeza'] * 0.09))))
    for s, ld in ((-1, 'd'), (1, 'i')):
        for y0, dt in ((5.6, 'del'), (-7.6, 'tras')):
            # Andar (paso) por diagonales; galope (patas) los pares de delante y de atras a la vez.
            fase = p['paso'] * (1 if (s > 0) == (dt == 'del') else -1) + p['patas'] * (1 if dt == 'del' else -1)
            a = -0.6 * p['paso'] * (1 if (s > 0) == (dt == 'del') else -1) - 0.8 * p['patas'] * (1 if dt == 'del' else -1)
            if dt == 'del' and ld == 'd':
                e = p['escarba']
                a += 0.7 * e if e > 0 else 1.1 * e      # + raspa hacia atras; - se alza hacia delante
            if p['muere'] > 0.0:
                a = 0.25 * p['muere'] * (1 if dt == 'del' else -1)   # tiesas
            X['pata_%s_%s' % (dt, ld)] = comp(raiz, sobre(Z(3.8 * s, y0, 6.0), rx(a)))
    return X


def escena(pose):
    e = Escena(huesos(pose))
    add = e.add
    # EL CUERPO: barril, con la CRUZ alta y gorda (el jabali carga el peso delante) y el anca mas baja.
    # GORDO (la 1a vuelta salia flaco al lado del viejo): un barril ancho y bajo.
    add(lambda P: sd_elipsoide(P, Z(0, -1.0, 7.8), np.array([6.4, 9.6, 5.2 * ESTIRA])), 'piel', 0)
    add(lambda P: sd_elipsoide(P, Z(0, 4.4, 9.4), np.array([6.8, 5.8, 6.0 * ESTIRA])), 'piel', 2.5)
    add(lambda P: sd_elipsoide(P, Z(0, -7.6, 7.4), np.array([5.8, 4.8, 4.8 * ESTIRA])), 'piel', 2.5)
    # Papada/pecho que cae entre las patas de delante.
    add(lambda P: sd_elipsoide(P, Z(0, 7.0, 5.8), np.array([4.6, 3.6, 3.4 * ESTIRA])), 'piel', 2.0)
    # LA CABEZA: una cuña grande que baja hacia el morro, metida en los hombros (sin cuello).
    add(lambda P: sd_cono(P, Z(0, 8.8, 8.6), Z(0, 14.8, 5.0), 5.0, 2.6), 'piel', 2.0, hueso='cabeza')
    add(lambda P: sd_elipsoide(P, Z(0, 16.3, 4.7), np.array([2.7, 1.1, 2.1 * ESTIRA])), 'morro', 0, 'morro', 'cabeza')
    for s in (-1, 1):
        # Las orejas: puntiagudas, hacia arriba y atras.
        add(lambda P, s=s: sd_cono(P, Z(3.0 * s, 9.8, 11.2), Z(4.2 * s, 8.4, 14.2), 1.5, 0.3), 'piel', 0.4, hueso='cabeza')
        # LOS OJOS: blancos con la pupila negra, ASOMANDO de la cuña (a 2,9 quedaban dentro de la cabeza y no se veian).
        add(lambda P, s=s: sd_esfera(P, Z(3.35 * s, 11.8, 8.9), 0.85), 'ojo', 0, 'ojo', 'cabeza')
        add(lambda P, s=s: sd_esfera(P, Z(3.75 * s, 12.3, 9.0), 0.55), 'pupila', 0, 'ojo', 'cabeza')
        # LOS COLMILLOS: GORDOS, salen de los lados del morro y se curvan hacia arriba y atras.
        p = Z(2.4 * s, 15.0, 4.0); d = np.array([0.55 * s, 0.4, 0.75]); r = 1.25
        for k in range(5):
            dd = d / np.linalg.norm(d); q = p + dd * 1.35
            add(lambda P, a=p, b=q, ra=r, rb=max(0.2, r - 0.16): sd_cono(P, a, b, ra, rb), 'marfil', 0, 'colmillo', 'cabeza')
            p = q; r = max(0.22, r - 0.21); d = d + np.array([0.05 * s, -0.28, 0.0])
    # LA CRIN: mechones oscuros y tiesos por el espinazo, de la nuca a media espalda (los mas altos en la cruz).
    # Puntas finas que SOBRESALEN del perfil (la franja pegada al lomo se leia como una mancha), en dos filas al tresbolillo.
    for i in range(14):
        u = i / 13.0
        y = 10.0 - u * 17.0
        alto = 15.2 - 2.6 * abs(u - 0.3) * 2.0
        x = 0.7 if i % 2 else -0.7
        base = Z(x, y, alto - 0.8)
        punta = Z(x * 1.4, y - 2.6, alto + 3.6 - 0.9 * (i % 3))
        add(lambda P, a=base, b=punta: sd_cono(P, a, b, 1.1, 0.2), 'crin', 0, 'crin')
    # LAS PATAS: cortas y gordas, con su pezuña.
    for s, ld in ((-1, 'd'), (1, 'i')):
        for y0, gord, dt in ((5.6, 2.3, 'del'), (-7.6, 2.2, 'tras')):
            h = 'pata_%s_%s' % (dt, ld)
            add(lambda P, a=Z(3.8 * s, y0, 6.0), b=Z(3.8 * s, y0 + 0.3, 1.4), g=gord: sd_cono(P, a, b, g, g * 0.65), 'piel', 1.4,
                hueso=h)
            add(lambda P, c=Z(3.8 * s, y0 + 0.5, 0.7): sd_elipsoide(P, c, np.array([1.5, 1.7, 0.8 * ESTIRA])), 'pezuna', 0,
                'pezuna', h)
    # LA COLA: corta, con su borla oscura.
    add(lambda P: sd_cono(P, Z(0, -11.6, 8.4), Z(0, -12.8, 6.2), 0.5, 0.35), 'crin', 0, 'cola')
    add(lambda P: sd_elipsoide(P, Z(0, -13.0, 5.6), np.array([0.6, 0.6, 0.9 * ESTIRA])), 'crin', 0, 'cola')
    return e.L



# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # Resopla: respira hondo y mueve poco la cabeza.
    r = math.sin(2 * math.pi * t)
    return POSE(agacha=0.06 * (1 - r), cabeza=0.8 * r)


def anim_walk(t):
    # Trote corto y pesado por diagonales.
    f = math.sin(2 * math.pi * t)
    return POSE(paso=f, agacha=0.08 * abs(math.cos(2 * math.pi * t)), cabeza=0.6 * math.sin(4 * math.pi * t))


def anim_embestida(t):
    # ESCARBA -> se lanza -> impacto -> recupera (la de la pelea en fila).
    ag = tramos(t, [(0.0, 0.0), (0.30, 0.55), (0.62, 0.85), (0.80, 0.45), (1.0, 0.1)])
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.30, -1.6), (0.62, 6.5), (0.80, 7.4), (1.0, 5.2)]) * (9.0 / 7.4),
                estira=tramos(t, [(0.0, 1.0), (0.30, 0.94), (0.62, 1.14), (0.80, 0.92), (1.0, 1.0)]),
                agacha=ag, cabeza=-1.8 * ag * 5.0,
                escarba=tramos(t, [(0.0, 0.0), (0.16, 1.0), (0.30, 0.0), (1.0, 0.0)]))


def anim_cornada(t):
    # Engancha DE ABAJO ARRIBA con UN colmillo: se agazapa, la cabeza baja y SUBE DE GOLPE (en el 5o), ladeandose.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.143, -1.2), (0.286, -1.6), (0.429, 1.4), (0.571, 3.2), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.143, 0.55), (0.286, 0.80), (0.429, 0.30), (0.571, -0.15), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.143, -2.6), (0.286, -4.0), (0.429, 1.4), (0.571, 7.6), (1.0, 0.0)]),
                tumba=tramos(t, [(0.0, 0.0), (0.143, 0.10), (0.286, 0.22), (0.429, 0.30), (0.571, 0.24), (1.0, 0.0)]),
                estira=tramos(t, [(0.0, 1.0), (0.143, 0.94), (0.286, 0.92), (0.429, 1.08), (0.571, 1.12), (1.0, 1.0)]),
                escarba=tramos(t, [(0.0, 0.0), (0.143, 0.9), (0.286, 0.2), (0.429, 0.0), (1.0, 0.0)]))


def anim_pisoton(t):
    # Se ALZA sobre las traseras y estampa las manos DE GOLPE en el 5o (el cuerpo de estirado a desplomado).
    e = tramos(t, [(0.0, 0.0), (0.143, -0.25), (0.286, -0.80), (0.429, -1.0), (0.571, 0.15), (1.0, 0.0)])
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.143, 0.22), (0.286, -0.18), (0.429, -0.30), (0.571, 0.95), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.143, 1.2), (0.286, 3.4), (0.429, 4.4), (0.571, -3.6), (1.0, 0.0)]),
                empina=max(0.0, -e) * 0.42, escarba=e)


def anim_basico(t):
    # El colmillazo corto: baja la cabeza y la sube de golpe (la cornada en pequeño, sin escarbar).
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.3, -0.6), (0.5, 1.6), (0.7, 1.4), (1.0, 0.0)]),
                estira=1.0 + 0.06 * math.sin(math.pi * t),
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.45), (0.5, -0.1), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.3, -2.4), (0.5, 5.0), (0.7, 3.2), (1.0, 0.0)]),
                tumba=tramos(t, [(0.0, 0.0), (0.3, 0.08), (0.5, 0.2), (0.7, 0.12), (1.0, 0.0)]))


def anim_arrollar(t):
    # LA EMBESTIDA EN EL MAPA: la pelea lo lleva por la linea; aqui galopa con la testuz baja y da el testarazo al llegar.
    choque = min(max((t - 0.75) / 0.25, 0.0), 1.0)
    ag = tramos(t, [(0.0, 0.2), (0.7, 0.75), (0.82, 0.9), (1.0, 0.3)])
    return POSE(patas=math.sin(2 * math.pi * t * 2.0) * (1.0 - choque), agacha=ag,
                cabeza=-1.8 * ag * 3.0 + 9.0 * math.sin(math.pi * choque), estira=1.0 + 0.1 * choque)


def anim_encaje(t):
    # Empieza YA golpeado: se echa atras ladeado y vuelve.
    return POSE(avance=tramos(t, [(0, -1.6), (1, 0.0)]), tumba=tramos(t, [(0, 0.15), (0.5, -0.05), (1, 0.0)]),
                cabeza=tramos(t, [(0, 3.0), (0.4, -1.5), (1, 0.0)]), agacha=tramos(t, [(0, 0.3), (1, 0.0)]))


def anim_muerte(t):
    # Le fallan las patas, cae de lado y se queda con las patas tiesas.
    return POSE(agacha=tramos(t, [(0, 0.0), (0.3, 0.5), (1, 0.4)]),
                muere=tramos(t, [(0, 0.0), (0.2, 0.05), (0.75, 1.0), (1, 1.0)]),
                cabeza=tramos(t, [(0, 2.0), (0.4, -1.0), (1, -2.0)]))


# COMER CRISTALES (31/10, los mutantes): baja la testuz al cristal, lo hoza y lo masca a golpes de quijada, y resopla.
def anim_comer(t):
    masca = 1.4 * math.sin(2 * math.pi * t * 4.0) * (0.25 < t < 0.85)
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.15, 0.6), (0.85, 0.6), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.15, -4.5), (0.25, -3.5), (0.85, -3.5), (1.0, 0.0)]) + masca,
                escarba=tramos(t, [(0.0, 0.0), (0.1, 0.8), (0.2, 0.0), (1.0, 0.0)]))


# LA TRANSFORMACION hasta el mutante (31/10, 18 marcos a 10 como las demas): tiembla agazapado, se encoge y se ALZA
# de golpe (ahi cambian los colmillos y brota el musgo, ver la escena del mutante) y crece hasta su tamaño. 'evo' de
# 0 (lo que era) a 1 (el mutante).
def _paso(x, a, b):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def anim_evolucion(t):
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.30, 0.40))
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.12, 0.5), (0.45, 0.5), (0.55, -0.2), (0.70, 0.1), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.45, -2.0), (0.55, 4.0), (0.70, 0.0), (1.0, 0.0)]) + 0.8 * tiembla,
                tumba=0.04 * tiembla, evo=tramos(t, [(0.0, 0.0), (0.12, 0.0), (0.88, 1.0), (1.0, 1.0)]))


ANIMS = {
    'comer': (10, 10.0, False, 8, anim_comer),
    'idle': (8, 5.0, True, 8, anim_idle),
    'walk': (8, 8.0, True, 8, anim_walk),
    'embestida': (8, 11.0, False, 8, anim_embestida),
    'cornada': (8, 11.0, False, 8, anim_cornada),
    'pisoton': (8, 12.0, False, 8, anim_pisoton),
    'basico': (8, 14.0, False, 8, anim_basico),
    'arrollar': (8, 14.0, False, 8, anim_arrollar),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}


_escena_base = escena

# LOS MUTANTES DEL JABALI (31/10, jabali-mutante): JABALI_VAR=colmillo (el Colmillo de cristal: los colmillos curvos de
# cristal, la crin de musgo y una chepa leve) | ancestral (el Jabali ancestral: los colmillos enormes, drusas en el morro,
# el manto de musgo con helechos y setas y la chepa enorme). Y lo que les pasa en la pelea, cada uno su carpeta:
# JABALI_ROTOS=1 (los colmillos partidos tras la Cornada de cristal: los muñones) y, el ancestral, JABALI_PELADO=1 (le
# han quemado el musgo). Sus piezas, las de jabali_versiones.py; sus animaciones, las del jabali + comer y su evolucion
# (solo la entera). Las vistas, a su escritorio.
VAR = os.environ.get('JABALI_VAR', '')
ROTOS = os.environ.get('JABALI_ROTOS', '') == '1'
PELADO = os.environ.get('JABALI_PELADO', '') == '1'
if VAR in ('colmillo', 'ancestral'):
    sys.modules.setdefault('jabali_sdf', sys.modules[__name__])
    import jabali_versiones as _jv
    _ESC_M = {'colmillo': (1.7 * 1.2, 1.7), 'ancestral': (1.7 * 1.32, 1.7 * 1.2)}   # [la suya, la de lo que era]
    _esc_m, _esc_antes = _ESC_M[VAR]
    _lado = int(round(88 * _esc_m / 1.7 / 2)) * 2 + 16
    MODELO = Modelo(_esc_m, (_lado, _lado), (_lado // 2, int(_lado * 0.56)), _jv._mat(), (0.11, 0.07, 0.05),
                    suaves=('cuerpo',), brillan=('ojo', 'pupila'), estira=ESTIRA, corta_suelo=True, especular=('cristal',),
                    umbral_especular=0.955)
    _suf = VAR + ('_pelado' if PELADO and VAR == 'ancestral' else '') + ('_rotos' if ROTOS else '')
    SALIDA = 'tools/salida/sdf/jabali_sdf_%s/' % _suf   # (hasta su visto bueno: luego a assets/sprites/enemigos/)
    VISTAS = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                          'jabali_%s_hojas' % _suf) + os.sep
    _SUYAS = ['idle', 'walk', 'embestida', 'cornada', 'pisoton', 'basico', 'arrollar', 'encaje', 'muerte']
    if not ROTOS and not PELADO:
        _SUYAS += ['comer', 'evolucion']
    ANIMS['evolucion'] = (18, 10.0, False, 8, anim_evolucion)
    ANIMS = {k: ANIMS[k] for k in _SUYAS}

    def escena(pose):
        jv = _jv
        evo = pose.get('evo', 1.0)
        if VAR == 'colmillo':
            # Del jabali al Colmillo de cristal: le crece la chepa, los colmillos se le hacen CRISTAL en la sacudida
            # (y se alargan) y la crin se le vuelve musgo de la nuca hacia atras.
            ch = jv.CH1 * _paso(evo, 0.2, 0.7)
            pz = jv._Piezas(pose, ('colmillo', 'crin') if evo >= 0.5 else ('colmillo',))
            jv.r_chepa(pz, ch)
            jv.r_curvos(pz, 1.0, ROTOS, 'cristal' if evo >= 0.5 else 'marfil')
            if evo >= 0.5:
                jv.r_musgo_crin(pz, ch, _paso(evo, 0.5, 0.9))
        else:
            # Del Colmillo de cristal al Ancestral: la chepa se hincha, el musgo se extiende del espinazo a los flancos,
            # los colmillos se alargan, le brotan las drusas del morro y luego los helechos y las setas.
            ch = jv.CH1 + (jv.CH2 - jv.CH1) * _paso(evo, 0.2, 0.7)
            pz = jv._Piezas(pose, ('colmillo', 'crin'))
            jv.r_chepa(pz, ch)
            jv.r_curvos(pz, 1.0 + 0.6 * _paso(evo, 0.35, 0.8), ROTOS)
            jv.r_drusas_morro(pz, _paso(evo, 0.45, 0.75))
            if PELADO:
                jv.r_quemado(pz, ch)
            else:
                if evo < 0.3:
                    jv.r_musgo_crin(pz, ch)
                jv.r_manto_musgo(pz, ch, 80, max(_paso(evo, 0.3, 0.8), 0.05))
                jv.r_helechos(pz, ch, _paso(evo, 0.7, 0.9))
                jv.r_setas(pz, ch, 3, _paso(evo, 0.75, 0.95))
        L = pz.L
        # El TAMAÑO: de lo que era al suyo (todo el modelo, desde los pies).
        s = (_esc_antes + (_esc_m - _esc_antes) * _paso(evo, 0.2, 0.85)) / _esc_m
        if s != 1.0:
            for i, (fn, m, g, k, Xh, nh) in enumerate(L):
                L[i] = (fn, m, g, k, (Xh[0] * s, Xh[1] * s), nh)
        return L


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'jabali_806255_1.70', VISTAS + 'jabali_vs_viejo.png', 5))
    else:
        hornear('jabali_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
