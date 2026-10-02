# ============================================================
#  golem_sdf.py -- el GOLEM DE ARCILLA en 3D (02-03/10/2026). Prueba aprobada ("el golem quedo peak"); ahora entero.
#  Con el motor del Minotauro (sdf_comun). Como el viejo: un bloque de barro encorvado con la cabeza hundida entre los
#  hombros, brazos de gorila hasta el suelo con puños enormes, piernas cortas y gordas, ojos que brillan y GRIETAS con
#  brasa en el pecho.
#
#  HUESOS: raiz (agacharse, balancearse, hundirse al morir), torso (se inclina y gira sobre la pelvis), cabeza, brazo y
#  antebrazo de cada lado. Las PIERNAS van por IK: de la cadera (que va con la raiz) al pie, que se queda en el suelo.
#
#  Uso:  python tools/sprites_sdf/golem_sdf.py [anim ...]   -> assets/sprites/enemigos/golem_sdf/<anim>.png
#        python tools/sprites_sdf/golem_sdf.py vistas       -> tools/salida/sdf/golem_vs_viejo.png (quieto, 5 vistas)
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/golem_sdf/'
VISTAS = 'tools/salida/sdf/'
ESTIRA = 1.15

def Z(x, y, z):
    return np.array([x, y, z * ESTIRA], dtype=float)

MAT = {
    'barro':  [(0.42, 0.28, 0.16), (0.56, 0.39, 0.23), (0.68, 0.50, 0.32)],
    'oscuro': [(0.31, 0.20, 0.12), (0.41, 0.28, 0.17), (0.51, 0.36, 0.23)],
    'ojo':    [(1.00, 0.95, 0.70), (1.00, 0.95, 0.70), (1.00, 0.97, 0.80)],
    'brasa':  [(0.95, 0.45, 0.12), (0.95, 0.45, 0.12), (1.00, 0.62, 0.22)],
}
# El lienzo y los pies del generador viejo (162 x 176, pies a ~128).
MODELO = Modelo(2.8, (162, 176), (81, 128), MAT, (0.16, 0.10, 0.06),
                suaves=('cuerpo', 'cabeza', 'brazo_d', 'brazo_i', 'pierna_d', 'pierna_i'),
                brillan=('ojo', 'brasa'), estira=ESTIRA, corta_suelo=True)

# --- LAS ARTICULACIONES EN REPOSO ---
PELVIS = Z(0, -0.2, 11.0)
CUELLO = Z(0, 2.6, 23.0)
def HOMBRO(s): return Z(8.6 * s, 0.4, 21.6)
def CODO(s): return Z(10.6 * s, 2.0, 11.6)
def MUNECA(s): return Z(10.4 * s, 3.4, 5.2)
def CADERA(s): return Z(3.8 * s, -0.4, 9.6)
def PIE(s): return Z(4.4 * s, 0.6, 1.3)
LADOS = ((-1, 'd'), (1, 'i'))    # 'd' = su derecha (a la izquierda de la pantalla mirando al sur)


def POSE(**k):
    p = dict(agacha=0.0, avance=0.0, balanceo=0.0, inclina=0.0, gira=0.0, cabeza=0.0, hunde=0.0,
             alza_d=0.0, alza_i=0.0, codo_d=0.25, codo_i=0.25, abre_d=0.0, abre_i=0.0,
             pie_d=(0.0, 0.0), pie_i=(0.0, 0.0), hundir=0.0, vuelca=0.0, monton=0.0, tiembla=0.0,
             rodillas=0.0, apaga=0.0, rompe=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    # LA RAIZ: se agacha, se mece de lado (sobre los pies) y, al morir, se vence hacia delante y se hunde.
    raiz = (np.eye(3), np.array([p['tiembla'], p['avance'], -(p['agacha'] + p['hundir']) * ESTIRA]))
    raiz = comp(raiz, sobre(Z(0, 0, 0), ry(p['balanceo'])))
    raiz = comp(raiz, sobre(Z(0, 4.0, 0), rx(p['vuelca'])))
    X['raiz'] = raiz
    X['torso'] = comp(raiz, sobre(PELVIS, rz(p['gira']) @ rx(p['inclina'])))
    X['cabeza'] = comp(X['torso'], comp((np.eye(3), np.array([0, 0, -p['hunde'] * ESTIRA])), sobre(CUELLO, rx(p['cabeza']))))
    for s, nom in LADOS:
        X['brazo_' + nom] = comp(X['torso'], sobre(HOMBRO(s), ry(-p['abre_' + nom] * s) @ rx(-p['alza_' + nom])))
        X['antebrazo_' + nom] = comp(X['brazo_' + nom], sobre(CODO(s), rx(-p['codo_' + nom])))
    return X


def escena(p):
    if p['rompe'] > 0.0:
        return escena_trozos(p['rompe'])
    X = huesos(p)
    e = Escena(X)
    add = e.add
    # EL TRONCO: un bloque de barro, mas ancho arriba que abajo, y la CHEPA por encima de la cabeza.
    add(lambda P: sd_elipsoide(P, Z(0, 0.6, 19.0), np.array([8.4, 6.0, 6.8 * ESTIRA])), 'barro', 0, hueso='torso')
    add(lambda P: sd_elipsoide(P, Z(0, -0.2, 13.0), np.array([6.0, 4.8, 4.4 * ESTIRA])), 'barro', 2.0, hueso='torso')
    add(lambda P: sd_elipsoide(P, Z(0, -2.4, 23.4), np.array([6.6, 4.6, 3.6 * ESTIRA])), 'barro', 2.5, hueso='torso')
    # PEGOTES de barro por el cuerpo (modelado a mano, no liso).
    for c, r in ((Z(-4.2, 4.6, 14.4), 1.8), (Z(5.0, -3.4, 20.0), 2.0), (Z(-6.0, -2.0, 17.0), 1.6), (Z(0.0, 5.4, 12.0), 1.5)):
        add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'barro', 0.8, hueso='torso')
    # LAS GRIETAS CON BRASA en el pecho.
    for a, b in ((Z(2.2, 6.4, 21.0), Z(3.4, 6.2, 17.6)), (Z(3.4, 6.2, 17.6), Z(2.6, 6.0, 15.4)),
                 (Z(-3.0, 6.3, 19.4), Z(-2.0, 6.0, 16.2))):
        add(lambda P, a=a, b=b: sd_cono(P, a, b, 0.42, 0.32), 'brasa', 0, 'grieta', hueso='torso')
    # LA CABEZA: pequeña, hundida entre los hombros, en su grupo (la linea de dentro la separa del tronco).
    add(lambda P: sd_elipsoide(P, Z(0, 4.0, 25.4), np.array([3.4, 3.2, 3.0 * ESTIRA])), 'barro', 0, 'cabeza', 'cabeza')
    add(lambda P: sd_elipsoide(P, Z(0, 6.2, 24.4), np.array([2.4, 1.4, 1.6 * ESTIRA])), 'barro', 1.0, 'cabeza', 'cabeza')
    for s in (-1, 1):
        # (Al morir se le APAGAN: barro oscuro.)
        add(lambda P, s=s: sd_esfera(P, Z(1.4 * s, 6.6, 26.0), 0.95), 'oscuro' if p['apaga'] > 0.5 else 'ojo', 0, 'ojo',
            'cabeza')
    # LOS BRAZOS: el hombro va con el brazo (asi sale la linea entre los dos), codo oscuro y el puño enorme.
    for s, nom in LADOS:
        g = 'brazo_' + nom; hb = 'brazo_' + nom; ha = 'antebrazo_' + nom
        hom = HOMBRO(s); codo = CODO(s); mun = MUNECA(s)
        add(lambda P, c=hom: sd_elipsoide(P, c, np.array([4.0, 4.2, 3.8 * ESTIRA])), 'barro', 0, g, hb)
        add(lambda P, a=hom, b=codo: sd_cono(P, a, b, 3.2, 2.6), 'barro', 1.6, g, hb)
        add(lambda P, c=codo: sd_esfera(P, c, 2.6), 'oscuro', 0.8, g, ha)
        add(lambda P, a=codo, b=mun: sd_cono(P, a, b, 2.8, 2.4), 'barro', 1.0, g, ha)
        add(lambda P, c=Z(10.6 * s, 4.0, 3.0): sd_elipsoide(P, c, np.array([3.6, 3.8, 3.0 * ESTIRA])), 'barro', 1.2, g, ha)
        for k in (-1, 0, 1):
            add(lambda P, c=Z(10.6 * s + 1.3 * k, 6.8, 3.4): sd_esfera(P, c, 1.2), 'oscuro', 0.5, g, ha)
    # LAS PIERNAS por IK: de la cadera (con la raiz) al pie (en el suelo, o con la raiz al morir); la rodilla sale
    # hacia delante lo que haga falta para que la pierna no cambie de largo.
    for s, nom in LADOS:
        g = 'pierna_' + nom
        cad = aplica(X['raiz'], CADERA(s))
        dy, dz = p['pie_' + nom]
        pie_r = PIE(s) + np.array([0.0, dy, dz * ESTIRA])
        # Al hundirse (morir) los pies se hunden con el (el suelo los corta), sin girar: girados con la raiz quedaban
        # colgando en el aire.
        pie = pie_r - np.array([0.0, 0.0, p['hundir'] * ESTIRA])
        largo = np.linalg.norm(CADERA(s) - PIE(s))
        d = np.linalg.norm(cad - pie)
        dobla = math.sqrt(max(largo * largo - d * d, 0.0)) * 0.5
        rod = (cad + pie) * 0.5 + np.array([0.0, dobla, 0.0])
        # DE RODILLAS (al morir): la rodilla al suelo delante y la espinilla tumbada hacia atras.
        if p['rodillas'] > 0.0:
            r = p['rodillas']
            rod_k = np.array([4.0 * s, 3.4, 1.6])
            pie_k = rod_k + np.array([0.3 * s, -6.5, 0.0])
            rod = rod + (rod_k - rod) * r
            pie = pie + (pie_k - pie) * r
        add(lambda P, a=cad, b=rod: sd_cono(P, a, b, 3.2, 3.0), 'barro', 0, g, 'mundo')
        add(lambda P, a=rod, b=pie: sd_cono(P, a, b, 3.0, 2.8), 'barro', 1.4, g, 'mundo')
        add(lambda P, c=pie: sd_elipsoide(P, c, np.array([3.3, 3.9, 1.5 * ESTIRA])), 'oscuro', 0.8, g, 'mundo')
    # EL MONTON de barro donde se derrumba (al morir).
    # Bultos que se FUNDEN con su barro (en el grupo del cuerpo): uno plano y ancho se leia como un plato.
    if p['monton'] > 0.0:
        m = p['monton']
        for c, r in ((Z(0, 3.0, 0.0), (0.85, 0.9, 0.55)), (Z(-0.45, 1.0, 0.0), (0.6, 0.6, 0.45)),
                     (Z(0.5, 5.0, 0.0), (0.55, 0.55, 0.4))):
            add(lambda P, c=c, r=r: sd_elipsoide(P, c * np.array([m / 8.0, 1.0, 1.0]),
                np.array([m * r[0], m * r[1], m * r[2] * ESTIRA])), 'barro', 3.0, hueso='mundo')
    return e.L


# ------------------------------------------------------------
#  EL DESMORONE (al morir, despues de caer de rodillas): el cuerpo se parte en TROZOS de arcilla que caen y se amontonan.
#  Cada trozo sale de un sitio de su cuerpo arrodillado (POSE_RODILLAS) y acaba en el monton; los de arriba, encima.
# ------------------------------------------------------------
_TROZOS = None

def _anclas():
    # (punto en reposo, hueso, tamaño)
    A = [(Z(0, 0.6, 19.0), 'torso', 3.8), (Z(-4.2, 1.2, 19.4), 'torso', 3.0), (Z(4.2, 1.2, 19.4), 'torso', 3.0),
         (Z(0, -0.2, 13.6), 'torso', 3.4), (Z(-3.4, 0.4, 14.0), 'torso', 2.4), (Z(3.4, 0.4, 14.0), 'torso', 2.4),
         (Z(0, -2.4, 23.6), 'torso', 3.2), (Z(-3.6, -2.0, 22.8), 'torso', 2.4), (Z(3.6, -2.0, 22.8), 'torso', 2.4),
         (Z(0, 4.2, 18.0), 'torso', 2.6), (Z(0, 4.0, 25.4), 'cabeza', 2.8)]
    for s, nom in LADOS:
        A += [(HOMBRO(s), 'brazo_' + nom, 3.2), ((HOMBRO(s) + CODO(s)) * 0.5, 'brazo_' + nom, 2.6),
              (CODO(s), 'antebrazo_' + nom, 2.4), ((CODO(s) + MUNECA(s)) * 0.5, 'antebrazo_' + nom, 2.3),
              (Z(10.6 * s, 4.0, 3.0), 'antebrazo_' + nom, 3.0)]
    return A


def _trozos():
    global _TROZOS
    if _TROZOS is not None:
        return _TROZOS
    rng = np.random.default_rng(7)
    X = huesos(POSE_RODILLAS)
    T = []
    for ancla, hueso, tam in _anclas():
        # GRANDES: a su tamaño de antes el cuerpo se quedaba en un esqueleto de grava con huecos.
        T.append({'ini': aplica(X[hueso], ancla), 'tam': tam * 1.55})
    # Las piernas (arrodilladas) tambien se parten.
    for s in (-1, 1):
        T.append({'ini': np.array([4.0 * s, 2.4, 3.6]), 'tam': 3.8})
        T.append({'ini': np.array([4.0 * s, -1.8, 1.6]), 'tam': 3.2})
    zmax = max(t['ini'][2] for t in T)
    for i, t in enumerate(T):
        alto = t['ini'][2] / zmax
        a = rng.uniform(0, 2 * math.pi); r = rng.uniform(1.0, 8.5) * (1.15 - 0.6 * alto)
        # Al monton: los de abajo, repartidos por el suelo; los de arriba, encima.
        t['fin'] = np.array([math.cos(a) * r, 3.0 + math.sin(a) * r * 0.9, t['tam'] * 0.45 + alto * 6.0])
        t['espera'] = 0.25 * (1.0 - alto) + rng.uniform(0.0, 0.08)
        q, _ = np.linalg.qr(rng.normal(size=(3, 3)))
        t['ejes'] = q
        t['gira'] = rng.uniform(-1.2, 1.2)
        t['medio'] = np.array([1.0, rng.uniform(0.7, 0.95), rng.uniform(0.55, 0.8)]) * t['tam']
        t['mat'] = 'oscuro' if rng.uniform() < 0.3 else 'barro'
    _TROZOS = T
    return T


def escena_trozos(rompe):
    e = Escena({})
    for i, t in enumerate(_trozos()):
        u = min(max((rompe - t['espera']) / (1.0 - t['espera']), 0.0), 1.0)
        f = u * u                                        # caen con peso
        c = t['ini'] + (t['fin'] - t['ini']) * f
        # Al empezar se SEPARAN un pelin hacia fuera (se le abre el cuerpo en pedazos).
        fuera = t['ini'] - np.array([0.0, 1.0, 10.0])
        fuera[2] = 0.0
        n = np.linalg.norm(fuera)
        if n > 0.01:
            c = c + fuera / n * 0.9 * min(rompe * 6.0, 1.0) * (1.0 - f)
        ejes = rz(t['gira'] * u) @ t['ejes']
        e.add(lambda P, c=c, ej=ejes, m=t['medio']: sd_caja(P, c, ej, m, m.min() * 0.45), t['mat'], 0, 'trozo%d' % i,
              'mundo')
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES: nombre -> (fotogramas, fps, loop, direcciones, t -> pose)
#  Los golpes TOCAN en el 6o de 8 (indice 5): CombatFX.IMPACTO_ANIM_MAPA 'golem_golpe' 0,5 a 10 fps.
# ------------------------------------------------------------
TOCA = 5.0 / 7.0

def anim_idle(t):
    # Respira muy despacio (tiene Agilidad 10: se lee lento) y los brazos se mecen un pelin.
    r = math.sin(2 * math.pi * t)
    return POSE(agacha=0.25 * (1 - r), cabeza=0.03 * r, alza_d=0.05 * r, alza_i=0.05 * r, inclina=0.02 * r)


def anim_walk(t):
    # NADA DE BOTE: bascula de un pilon al otro y arrastra el peso; los brazos en contrafase con las piernas.
    f = 2 * math.pi * t
    return POSE(pie_d=(2.6 * math.sin(f), 1.2 * max(0.0, math.cos(f))),
                pie_i=(-2.6 * math.sin(f), 1.2 * max(0.0, -math.cos(f))),
                balanceo=0.07 * math.sin(f), gira=0.06 * math.sin(f), agacha=0.5 * abs(math.sin(f)),
                alza_d=-0.35 * math.sin(f), alza_i=0.35 * math.sin(f), inclina=0.06)


def anim_basico(t):
    # EL PUÑETAZO: alza el puño derecho por encima de la cabeza, aguanta y lo deja caer delante como un mazo.
    # (Con el codo muy doblado arriba, de lado el puño acababa DETRAS de la cabeza.)
    return POSE(alza_d=tramos(t, [(0, 0.1), (0.29, 2.45), (0.57, 2.6), (TOCA, 0.35), (1, 0.2)]),
                codo_d=tramos(t, [(0, 0.3), (0.29, 0.55), (0.57, 0.45), (TOCA, 0.2), (1, 0.3)]),
                inclina=tramos(t, [(0, 0.0), (0.43, -0.15), (TOCA, 0.28), (1, 0.06)]),
                gira=tramos(t, [(0, 0.0), (0.43, 0.15), (TOCA, -0.1), (1, 0.0)]),
                agacha=tramos(t, [(0.57, 0.0), (TOCA, 1.2), (1, 0.3)]),
                alza_i=0.08, cabeza=tramos(t, [(0.43, -0.1), (TOCA, 0.2), (1, 0.0)]))


def anim_machaca(t):
    # LA MACHACA: los DOS puños arriba (se ve venir: suben pronto y aguantan) y los deja caer como un yunque.
    al = tramos(t, [(0, 0.1), (0.29, 2.55), (0.57, 2.7), (TOCA, 0.5), (1, 0.3)])
    co = tramos(t, [(0, 0.3), (0.29, 0.6), (0.57, 0.5), (TOCA, 0.2), (1, 0.3)])
    return POSE(alza_d=al, alza_i=al, codo_d=co, codo_i=co, abre_d=0.15, abre_i=0.15,
                inclina=tramos(t, [(0, 0.0), (0.43, -0.2), (TOCA, 0.35), (1, 0.08)]),
                agacha=tramos(t, [(0, 0.0), (0.43, -0.3), (0.57, 0.0), (TOCA, 1.8), (1, 0.5)]),
                cabeza=tramos(t, [(0.43, -0.15), (TOCA, 0.25), (1, 0.05)]))


def anim_endurecerse(t):
    # SE APELMAZA: coge aire, se desploma sobre si mismo, recoge los puños contra el pecho y hunde la cabeza; tiembla al
    # cuajar y se queda QUIETO (eso es lo que dice que se ha vuelto un pedrusco).
    tiembla = 0.35 * math.sin(t * 40.0) * max(0.0, 1.0 - abs(t - 0.45) / 0.15)
    return POSE(agacha=tramos(t, [(0, 0.0), (0.14, -0.4), (0.43, 2.6), (1, 2.6)]),
                alza_d=tramos(t, [(0, 0.1), (0.43, 0.45), (1, 0.45)]), alza_i=tramos(t, [(0, 0.1), (0.43, 0.45), (1, 0.45)]),
                codo_d=tramos(t, [(0, 0.3), (0.43, 1.9), (1, 1.9)]), codo_i=tramos(t, [(0, 0.3), (0.43, 1.9), (1, 1.9)]),
                abre_d=tramos(t, [(0, 0.0), (0.43, -0.3), (1, -0.3)]), abre_i=tramos(t, [(0, 0.0), (0.43, -0.3), (1, -0.3)]),
                hunde=tramos(t, [(0, 0.0), (0.43, 2.0), (1, 2.0)]), tiembla=tiembla)


def anim_encaje(t):
    # ENCAJAR: empieza YA golpeado (el 0 es el impacto): se echa atras, la cabeza se le va y vuelve.
    return POSE(inclina=tramos(t, [(0, -0.28), (0.33, -0.18), (0.67, -0.05), (1, 0.0)]),
                cabeza=tramos(t, [(0, -0.35), (0.33, 0.12), (0.67, -0.04), (1, 0.0)]),
                agacha=tramos(t, [(0, 0.8), (1, 0.0)]),
                alza_d=tramos(t, [(0, -0.25), (1, 0.0)]), alza_i=tramos(t, [(0, -0.25), (1, 0.0)]))


# MORIR (03/10, lo pidio el: "primero caiga de rodillas y luego se desmorone" en un monton de trozos de arcilla):
# marcos 1-4 se le doblan las piernas y CAE DE RODILLAS, apoya los puños, cuelga la cabeza y se le apagan los ojos;
# marcos 5-8 se PARTE en trozos que caen y se amontonan. El cadaver es el monton.
POSE_RODILLAS = POSE(rodillas=1.0, agacha=6.6, inclina=0.32, alza_d=0.35, alza_i=0.35, codo_d=0.2, codo_i=0.2,
                     abre_d=0.1, abre_i=0.1, cabeza=0.55, apaga=1.0)

def anim_muerte(t):
    if t > 0.5:
        return POSE(rompe=tramos(t, [(4 / 7.0, 0.12), (5 / 7.0, 0.45), (6 / 7.0, 0.8), (1, 1.0)]))
    k = tramos(t, [(0, 0.0), (1 / 7.0, 0.45), (2 / 7.0, 1.0), (1, 1.0)])
    p = POSE(rodillas=k, agacha=6.6 * k, inclina=tramos(t, [(0, -0.15), (1 / 7.0, 0.1), (2 / 7.0, 0.25), (3 / 7.0, 0.32)]),
             alza_d=0.35 * k, alza_i=0.35 * k, codo_d=0.25 - 0.05 * k, codo_i=0.25 - 0.05 * k, abre_d=0.1 * k,
             abre_i=0.1 * k, cabeza=tramos(t, [(0, -0.3), (1 / 7.0, 0.15), (2 / 7.0, 0.35), (3 / 7.0, 0.55)]),
             apaga=1.0 if t >= 3 / 7.0 - 1e-6 else 0.0)
    return p


ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 5.0, True, 8, anim_walk),
    'basico': (8, 10.0, False, 8, anim_basico),
    'golem_machaca': (8, 10.0, False, 8, anim_machaca),
    'endurecerse': (8, 9.0, False, 8, anim_endurecerse),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 9.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'golem_aa8055_2.80', VISTAS + 'golem_vs_viejo.png', 3))
    else:
        hornear('golem_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
