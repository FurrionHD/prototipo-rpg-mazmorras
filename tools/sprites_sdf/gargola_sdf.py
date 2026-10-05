# ============================================================
#  gargola_sdf.py -- la GARGOLA DE BASALTO en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (gargola_sprites.gd): la unica de los constructos que NO es una mole. BIPEDA, AGAZAPADA (patas digitigradas de
#  rapaz, dobladas, el cuerpo echado hacia delante), brazos cortos de agarrarse, cabeza ALTA con ceja de piedra, hocico
#  chato, cuernos hacia atras, ojos VACIOS claros (la "Mirada petrea"), cola que baja al suelo con PALA, y ALAS DE
#  MURCIELAGO plegadas a la espalda (laminas: hueso oscuro y membrana mas oscura que el cuerpo, con sus DEDOS: sin ellos
#  el ala es una paleta lisa = una polilla).
#  Lienzo y origen de su horneado (2,40 -> 116 x 116; pies en 58, 66).
#  Uso: python tools/sprites_sdf/gargola_sdf.py [anim ...]  -> assets/sprites/enemigos/gargola_sdf/<anim>.png
#       python tools/sprites_sdf/gargola_sdf.py vistas     -> tools/salida/sdf/gargola_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/gargola_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Basalto gris azulado (el 6a7380 del viejo, con su _basalto). La membrana, MAS OSCURA que el cuerpo (asi se separa del
# lomo plegada encima); los huesos del ala y las garras, lo mas oscuro.
MAT = {
    'piedra':   [(0.25, 0.28, 0.34), (0.37, 0.41, 0.48), (0.52, 0.57, 0.65)],
    'pata':     [(0.21, 0.24, 0.29), (0.31, 0.34, 0.41), (0.44, 0.48, 0.56)],
    'membrana': [(0.18, 0.20, 0.25), (0.26, 0.29, 0.35), (0.35, 0.39, 0.46)],
    'hueso':    [(0.13, 0.14, 0.18), (0.19, 0.21, 0.26), (0.27, 0.30, 0.36)],
    'garra':    [(0.08, 0.09, 0.11), (0.12, 0.13, 0.16), (0.19, 0.21, 0.25)],
    'boca':     [(0.07, 0.07, 0.09)] * 3,
    'diente':   [(0.62, 0.65, 0.70), (0.74, 0.77, 0.82), (0.84, 0.87, 0.91)],
    'ojo':      [(0.86, 0.92, 0.96), (0.86, 0.92, 0.96), (0.93, 0.97, 1.00)],
}
MODELO = Modelo(2.4, (116, 116), (58, 66), MAT, (0.08, 0.09, 0.11),
                suaves=('cuerpo', 'cabeza', 'brazo_d', 'brazo_i', 'pierna_d', 'pierna_i', 'cola'),
                brillan=('ojo',), corta_suelo=True)

LADOS = ((-1, 'd'), (1, 'i'))    # 'd' = su derecha (a la izquierda de la pantalla mirando al sur)

# --- LAS ARTICULACIONES EN REPOSO ---
PELVIS = V((0.0, -1.0, 11.6))
CUELLO = V((0.0, 2.6, 21.4))
def HOMBRO(s): return V((4.4 * s, 2.0, 19.8))
def CODO(s): return V((5.4 * s, 1.0, 14.8))
def MANO(s): return V((3.9 * s, 5.6, 13.0))
def CADERA(s): return V((3.6 * s, -1.2, 11.2))
def RODILLA(s): return V((4.4 * s, 3.0, 7.2))
def CORVEJON(s): return V((4.2 * s, -2.4, 3.2))
def PIE(s): return V((3.9 * s, 1.2, 0.9))
def ALA_RAIZ(s): return V((3.0 * s, -2.0, 20.0))


def POSE(**k):
    p = dict(agacha=0.0, avance=0.0, vuela=0.0, mece=0.0, balanceo=0.0, inclina=0.0, cabeza=0.0, cola=0.0,
             alza_d=0.0, alza_i=0.0, abre=0.0, patas=0.0, recoge=0.0, tumba=0.0, apoyo=0.0, apaga=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    # AL MORIR se va de lado DE UNA PIEZA, como una estatua: todo el bicho (patas incluidas) gira sobre un eje que va
    # del morro a la grupa, un poco a su izquierda; 'apoyo' lo levanta lo justo para que ruede SOBRE el suelo.
    muere = comp((np.eye(3), V((-6.5 * p['tumba'], 0.0, p['apoyo']))), sobre(V((1.5, 0.0, 0.0)), ry(p['tumba'] * math.pi * 0.5)))
    base = comp(muere, (np.eye(3), V((0.0, p['avance'], p['vuela']))))
    raiz = comp(base, (np.eye(3), V((0.0, 0.0, -p['agacha']))))
    raiz = comp(raiz, sobre(V((0.0, 0.0, 0.0)), ry(p['balanceo'] * 0.12)))
    raiz = comp(raiz, sobre(V((0.0, 0.0, 10.0)), rx(p['mece'] * 0.16)))
    X['raiz'] = raiz
    X['torso'] = comp(raiz, sobre(PELVIS, rx(p['inclina'])))
    X['cabeza'] = comp(X['torso'], sobre(CUELLO, rx(p['cabeza'])))
    for s, nom in LADOS:
        X['brazo_' + nom] = comp(X['torso'], sobre(HOMBRO(s), rx(-p['alza_' + nom])))
        X['ala_' + nom] = X['torso']
        # LAS PATAS: los pies se quedan en el suelo; al agacharse la pata se ENCOGE en altura (la cadera baja con el
        # cuerpo), al andar oscilan sobre la cadera y en el aire se RECOGEN hacia atras.
        enc = (CADERA(s)[2] - p['agacha']) / CADERA(s)[2]
        aplasta = (np.diag([1.0, 1.0, enc]), np.zeros(3))
        oscila = sobre(CADERA(s), rx(p['patas'] * 0.38 * (1 if nom == 'd' else -1) + p['recoge'] * 0.7))
        X['pierna_' + nom] = comp(base, comp(aplasta, oscila))
    X['cola'] = comp(raiz, sobre(V((0.0, -4.4, 12.0)), rz(p['cola'] * 0.35) @ rx(-p['recoge'] * 0.3)))
    return X


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='torso'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='torso'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _lamina(add, a, b, c, mat='membrana', grosor=0.30, grupo='ala', hueso='torso'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float), c=V(c, dtype=float): sd_triangulo(P, a, b, c, grosor),
        mat, 0, grupo, hueso)


def _garras(add, base, adelante, n, largo, r, grupo, hueso, abre=0.55):
    """'n' garras desde 'base' hacia 'adelante' (un vector), abiertas en abanico y curvadas hacia abajo."""
    a = V(adelante, dtype=float); a /= np.linalg.norm(a)
    lado = np.cross(a, V((0.0, 0.0, 1.0)))
    if np.linalg.norm(lado) < 1e-3: lado = V((1.0, 0.0, 0.0))
    lado /= np.linalg.norm(lado)
    for i in range(n):
        f = (i - (n - 1) / 2.0) * abre
        d = a * math.cos(f) + lado * math.sin(f)
        b0 = base + lado * (i - (n - 1) / 2.0) * r * 1.3
        punta = b0 + d * largo + V((0.0, 0.0, -largo * 0.45))
        _cono(add, b0, punta, r, r * 0.35, 'garra', 0, grupo, hueso)


def _ala(add, s, p):
    """El ala PLEGADA (y lo que se abra con 'abre', para el vuelo): el brazo del ala sube desde la espalda a la MUÑECA
    (por encima de los hombros: la silueta clasica de gargola), y desde ahi los dedos BAJAN por detras hasta la cadera
    sosteniendo la membrana entre ellos."""
    a = p['abre']
    raiz = ALA_RAIZ(s)
    # Plegada: muñeca alta y algo atras; abierta: muñeca al costado, en alto.
    mun = V((s * (7.4 + 6.0 * a), -2.6 + 0.6 * a, 28.6 - 2.6 * a))
    codo = (raiz + mun) * 0.5 + V((s * (1.8 + 1.0 * a), -1.6, 0.0))
    # Las puntas de los dedos, de la de fuera a la de dentro (plegadas cuelgan por detras hacia la grupa).
    puntas_pleg = [V((s * 9.6, -4.2, 18.0)), V((s * 8.4, -5.0, 13.0)), V((s * 6.0, -4.8, 10.0))]
    puntas_ab = [V((s * 22.0, -4.0, 22.0)), V((s * 19.0, -7.0, 14.0)), V((s * 12.0, -7.0, 10.0))]
    puntas = [pp + (pa - pp) * a for pp, pa in zip(puntas_pleg, puntas_ab)]
    g = 'ala_' + ('d' if s < 0 else 'i'); h = g
    # La membrana: entre dedo y dedo, y del ultimo dedo a la espalda.
    cadena = [mun] + puntas
    for i in range(1, len(cadena) - 1):
        _lamina(add, mun, cadena[i], cadena[i + 1], 'membrana', 0.30, g, h)
    _lamina(add, mun, puntas[-1], raiz + V((0.0, -0.6, -4.0)), 'membrana', 0.30, g, h)
    _lamina(add, mun, raiz + V((0.0, -0.6, -4.0)), codo, 'membrana', 0.30, g, h)
    # Los HUESOS por encima: brazo del ala (gordo) y los dedos (finos) hasta cada punta.
    _cono(add, raiz, codo, 1.15, 1.0, 'hueso', 0, g + '_h', h)
    _cono(add, codo, mun, 1.0, 0.85, 'hueso', 0, g + '_h', h)
    for pt in puntas:
        _cono(add, mun, pt, 0.55, 0.35, 'hueso', 0, g + '_h', h)
    # El GARFIO de la muñeca: la seña del ala de murcielago (y en la gargola, el pincho que remata la silueta).
    _cono(add, mun, mun + V((s * 0.6, 0.6, 2.2)), 0.7, 0.2, 'garra', 0, g + '_h', h)


def escena(pose):
    p = pose
    X = huesos(p)
    e = Escena(X); add = e.add
    # --- EL CUERPO: pecho alto y echado hacia delante, cintura estrecha, grupa sobre las patas.
    _elip(add, (0.0, 1.6, 17.6), (5.0, 4.4, 4.6), 'piedra', 0)
    _elip(add, (0.0, -0.4, 13.4), (3.8, 3.6, 3.4), 'piedra', 2.0)
    _elip(add, (0.0, -2.6, 11.4), (3.6, 3.0, 2.8), 'piedra', 1.6)
    # Los PECTORALES y la quilla: dos placas de piedra que dan el relieve al pecho de frente.
    for s in (-1, 1):
        _elip(add, (1.9 * s, 4.6, 18.4), (2.3, 1.3, 2.0), 'piedra', 0.8)
    # El ESPINAZO: una cresta de bultos por el lomo, entre las alas.
    for i, (y, z) in enumerate(((-2.0, 21.0), (-3.0, 18.4), (-3.6, 15.6), (-3.8, 12.8))):
        _elip(add, (0.0, y, z), (1.0, 1.1, 1.0), 'piedra', 0.6)
    # --- LA CABEZA: alta (lo que la separa del pecho es (y - z), no adelantarla), con hocico chato, CEJA de piedra
    # (sin ella los ojos flotan y no hay mirada), mandibula con colmillos y orejas puntiagudas hacia atras.
    hc = 'cabeza'
    _cono(add, (0.0, 1.8, 19.6), (0.0, 3.6, 24.0), 2.4, 2.0, 'piedra', 0, hc, hc)
    _elip(add, (0.0, 4.4, 26.0), (2.8, 2.8, 2.6), 'piedra', 0, hc, hc)
    _elip(add, (0.0, 6.9, 25.0), (2.0, 2.0, 1.5), 'piedra', 1.0, hc, hc)
    _elip(add, (0.0, 6.2, 27.3), (3.0, 1.4, 0.95), 'piedra', 0.6, hc, hc)
    _elip(add, (0.0, 7.4, 23.6), (1.8, 1.4, 0.7), 'boca', 0, 'boca', hc)
    for s in (-1, 1):
        _cono(add, (0.9 * s, 8.0, 24.2), (0.9 * s, 8.3, 22.9), 0.38, 0.12, 'diente', 0, 'diente', hc)
        # Los OJOS, vacios y claros, bajo la ceja y bien separados (pegados se leen como una mancha).
        add(lambda P, s=s: sd_elipsoide(P, V((1.35 * s, 6.9, 26.4)), V((0.75, 0.55, 0.6))),
            'hueso' if p['apaga'] > 0.5 else 'ojo', 0, 'ojo', hc)
        # Las OREJAS, en punta hacia atras y fuera.
        _cono(add, (2.4 * s, 3.6, 27.0), (4.2 * s, 1.6, 28.4), 0.9, 0.2, 'piedra', 0.5, hc, hc)
        # Los CUERNOS: hacia ATRAS y ARRIBA, curvados, que rompen la silueta redonda.
        c0 = V((1.5 * s, 4.4, 28.2)); c1 = V((2.2 * s, 2.6, 31.0)); c2 = V((2.6 * s, -0.2, 32.4))
        _cono(add, c0, c1, 0.95, 0.7, 'piedra', 0.4, hc, hc)
        _cono(add, c1, c2, 0.7, 0.25, 'piedra', 0.2, hc, hc)
    # --- LOS BRAZOS: cortos, doblados, de rapaz; las zarpas por delante del pecho, apoyadas en las rodillas.
    for s, nom in LADOS:
        g = 'brazo_' + nom
        _elip(add, HOMBRO(s), (2.2, 2.3, 2.1), 'piedra', 0, g, g)
        _cono(add, HOMBRO(s), CODO(s), 1.8, 1.4, 'piedra', 1.0, g, g)
        _cono(add, CODO(s), MANO(s), 1.4, 1.15, 'piedra', 0.8, g, g)
        _elip(add, MANO(s), (1.4, 1.5, 1.2), 'piedra', 0.6, g, g)
        _garras(add, MANO(s) + V((0.0, 0.9, -0.4)), (0.0, 1.0, -0.6), 3, 1.6, 0.45, g + '_g', g, abre=0.5)
    # --- LAS PATAS: digitigradas, dobladas (muslo hacia delante, caña hacia atras al CORVEJON, empeine a los dedos).
    for s, nom in LADOS:
        g = 'pierna_' + nom; h = g
        _cono(add, CADERA(s), RODILLA(s), 2.6, 1.9, 'pata', 0, g, h)
        _elip(add, (CADERA(s) + RODILLA(s)) * 0.5 + V((0.4 * s, 0.0, 0.6)), (2.3, 2.8, 2.6), 'pata', 1.2, g, h)
        _cono(add, RODILLA(s), CORVEJON(s), 1.7, 1.2, 'pata', 0.8, g, h)
        _cono(add, CORVEJON(s), PIE(s), 1.1, 1.0, 'pata', 0.6, g, h)
        _garras(add, PIE(s) + V((0.0, 0.6, 0.0)), (0.0, 1.0, -0.15), 3, 2.0, 0.55, g + '_g', h, abre=0.45)
        _cono(add, CORVEJON(s), CORVEJON(s) + V((0.0, -1.4, -1.0)), 0.6, 0.2, 'garra', 0, g + '_g', h)
    # --- LA COLA: atras Y abajo (atras sube en pantalla: bajandola se cancela), hasta el suelo y remata en PALA.
    pts = [V((0.0, -4.0, 11.4)), V((0.0, -6.0, 7.6)), V((0.0, -7.4, 4.0)), V((0.0, -8.4, 1.6)), V((1.4, -9.8, 1.1))]
    rads = [1.7, 1.4, 1.1, 0.85, 0.7]
    for i in range(len(pts) - 1):
        _cono(add, pts[i], pts[i + 1], rads[i], rads[i + 1], 'piedra', 0.4, 'cola', 'cola')
    _elip(add, (2.4, -10.6, 1.1), (1.5, 1.9, 0.55), 'piedra', 0.3, 'cola', 'cola')
    # --- LAS ALAS, plegadas a la espalda.
    for s, nom in LADOS:
        _ala(add, s, p)
    # LA SOMBRA en el suelo cuando se despega: es lo que se lee como estar EN EL AIRE (y encoge con la altura).
    if p['vuela'] > 0.6:
        k = 1.0 / (1.0 + p['vuela'] / 14.0)
        e.sombra(0.0, p['avance'] + 0.5, 6.0 * k, 5.0 * k, 0.26 * min(1.0, p['vuela'] / 2.0))
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES: nombre -> (fotogramas, fps, loop, direcciones, t -> pose). Las claves de tiempo, las del viejo.
# ------------------------------------------------------------
VUELO_ALTO = 9.0
LUNGE_DIST = 11.0
ENCAJE_RETRO = 0.42


def anim_idle(t):
    # Posada: respira, la cola se mueve despacio y las alas plegadas se ajustan un pelin (parada del todo seria una
    # estatua, que es lo que quiere hacerte creer).
    r = math.sin(2 * math.pi * t)
    return POSE(agacha=0.35 * (1 - math.cos(2 * math.pi * t)), cola=0.45 * r,
                abre=0.05 + 0.05 * math.sin(2 * math.pi * t + 1.1), cabeza=0.05 * r)


def anim_walk(t):
    # A SALTITOS: se impulsa y bota dos veces por ciclo (una por pata), y abre las alas a medias en cada bote.
    f = 2 * math.pi * t
    bote = max(0.0, math.sin(2 * f))
    return POSE(patas=math.sin(f), alza_d=0.25 * math.sin(f), alza_i=-0.25 * math.sin(f), balanceo=0.6 * math.sin(f),
                vuela=1.6 * bote, agacha=0.9 * max(0.0, -math.sin(2 * f)), abre=0.10 + 0.22 * bote,
                cola=0.7 * math.sin(f), mece=0.4 * bote)


def anim_embestida(t):
    # EL PICADO: abre las alas del todo, se ELEVA (la ventana del jugador: arriba de 0,30 a 0,52) y se deja caer encima.
    ab = tramos(t, [(0.0, 0.10), (0.18, 0.80), (0.30, 1.0), (0.52, 1.0), (0.68, 0.55), (0.84, 0.30), (1.0, 0.12)])
    vu = tramos(t, [(0.0, 0.0), (0.18, 1.5), (0.30, 2.4), (0.52, 2.6), (0.68, 0.2), (0.84, 0.0), (1.0, 0.0)])
    return POSE(abre=ab, vuela=vu * 2.6,
                avance=tramos(t, [(0.0, 0.0), (0.18, -1.2), (0.30, -1.6), (0.52, 0.4), (0.68, 9.6), (0.84, 11.0),
                                  (1.0, 9.4)]) * (LUNGE_DIST / 11.0),
                agacha=1.6 * tramos(t, [(0.0, 0.0), (0.18, -0.30), (0.52, -0.35), (0.68, 1.0), (0.84, 0.55),
                                        (1.0, 0.15)]),
                mece=tramos(t, [(0.0, 0.0), (0.30, -0.9), (0.52, -0.7), (0.68, 1.6), (0.84, 1.0), (1.0, 0.3)]),
                alza_d=0.8 * ab, alza_i=0.8 * ab, recoge=0.55 * ab, cola=-0.8 * vu / 2.6)


def anim_despegar(t):
    # Se agacha para impulsarse, abre las alas y sube: es la carga del picado en el mapa (despegar > vuelo > picar).
    return POSE(abre=tramos(t, [(0.0, 0.10), (0.4, 0.85), (0.7, 1.0), (1.0, 0.92)]),
                vuela=tramos(t, [(0.0, 0.0), (0.2, 0.0), (0.6, VUELO_ALTO * 0.8), (1.0, VUELO_ALTO)]),
                agacha=1.6 * tramos(t, [(0.0, 0.0), (0.2, 0.45), (0.5, -0.30), (1.0, -0.30)]),
                recoge=0.4 * min(t * 2.0, 1.0), alza_d=0.6 * min(t * 2.0, 1.0), alza_i=0.6 * min(t * 2.0, 1.0),
                cola=-0.6 * t)


def anim_vuelo(t):
    # Suspendida: las alas baten despacio y el cuerpo sube cuando bajan.
    bate = 0.5 + 0.5 * math.cos(2 * math.pi * t)
    return POSE(abre=0.72 + 0.28 * bate, vuela=VUELO_ALTO + 1.0 * (1.0 - bate), agacha=-0.5, recoge=0.4,
                alza_d=0.6, alza_i=0.6, cola=-0.6 + 0.25 * math.sin(2 * math.pi * t),
                cabeza=0.06 * math.sin(2 * math.pi * t))


def anim_picar(t):
    # Arriba, se recoge un instante y cae a plomo: las garras TOCAN en el marco 6 de 8 (0,714).
    vu = tramos(t, [(0.0, VUELO_ALTO), (0.286, VUELO_ALTO + 1.0), (0.43, VUELO_ALTO * 0.75), (0.57, VUELO_ALTO * 0.3),
                    (0.714, 0.0), (1.0, 0.0)])
    arriba = min(vu / VUELO_ALTO * 3, 1.0)
    return POSE(vuela=vu,
                abre=tramos(t, [(0.0, 1.0), (0.286, 0.75), (0.57, 0.45), (0.714, 0.60), (0.857, 0.35), (1.0, 0.12)]),
                agacha=1.6 * tramos(t, [(0.0, -0.30), (0.286, -0.35), (0.57, -0.20), (0.714, 1.0), (0.857, 0.55),
                                        (1.0, 0.15)]),
                mece=tramos(t, [(0.0, 0.0), (0.286, -0.9), (0.57, 0.4), (0.714, 1.6), (0.857, 1.0), (1.0, 0.3)]),
                recoge=0.55 * arriba, alza_d=0.6 * arriba, alza_i=0.6 * arriba,
                cola=-0.8 * min(max(vu / VUELO_ALTO, 0.0), 1.0))


def anim_mirada(t):
    # LA MIRADA PETREA: lo contrario del picado -- NO se despega del suelo. Tantea con la cabeza, se agazapa, se YERGUE
    # abriendo las alas a medias (0,70: del todo es el picado) y se QUEDA CLAVADA (0,571 a 0,714 iguales).
    return POSE(cabeza=0.5 * tramos(t, [(0.0, 0.10), (0.143, 0.38), (0.286, 0.16), (0.429, 0.0), (0.571, 0.0),
                                       (0.714, 0.0), (0.857, 0.05), (1.0, 0.10)]),
                agacha=2.0 * tramos(t, [(0.0, 0.0), (0.143, 0.16), (0.286, -0.10), (0.429, -0.20), (0.571, -0.24),
                                        (0.714, -0.22), (0.857, -0.10), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.10), (0.143, 0.06), (0.286, 0.40), (0.429, 0.62), (0.571, 0.70), (0.714, 0.70),
                                (0.857, 0.42), (1.0, 0.14)]),
                inclina=-0.25 * tramos(t, [(0.0, 0.0), (0.286, 0.5), (0.429, 1.0), (0.714, 1.0), (1.0, 0.0)]),
                cola=tramos(t, [(0.0, 0.30), (0.143, 0.10), (0.286, -0.45), (0.429, -0.70), (0.571, -0.75),
                                (0.714, -0.75), (0.857, -0.40), (1.0, 0.0)]))


def anim_encaje(t):
    # ESTA SI SALE DESPEDIDA (es ligera) y las alas se le abren de golpe. Empieza ya golpeada.
    retro = tramos(t, [(0.0, 1.0), (0.34, 0.45), (0.67, 0.14), (1.0, 0.0)])
    mece = tramos(t, [(0.0, -1.7), (0.34, 0.9), (0.67, -0.35), (1.0, 0.0)])
    return POSE(avance=-retro * LUNGE_DIST * ENCAJE_RETRO,
                abre=tramos(t, [(0.0, 0.62), (0.34, 0.40), (0.67, 0.18), (1.0, 0.08)]),
                mece=mece, cabeza=0.3 * mece, agacha=0.9 * retro, cola=0.5 * mece)


def anim_muerte(t):
    # CAE COMO UNA ESTATUA: las alas se cierran de golpe lo primero, se queda tiesa, y se va de lado DE UNA PIEZA,
    # acelerando, sin rebotar ni asentarse. Los ojos se apagan.
    return POSE(tumba=tramos(t, [(0.0, 0.0), (0.14, 0.05), (0.30, 0.18), (0.48, 0.48), (0.66, 0.80), (0.82, 0.97),
                                 (1.0, 1.0)]),
                apoyo=tramos(t, [(0.0, 0.0), (0.30, 0.3), (0.48, 1.0), (0.66, 1.8), (0.82, 2.3), (1.0, 2.4)]),
                abre=tramos(t, [(0.0, 0.35), (0.14, 0.06), (1.0, 0.0)]),
                agacha=1.6 * tramos(t, [(0.0, 0.0), (0.14, 0.45), (0.30, 0.62), (1.0, 0.62)]),
                cabeza=0.5 * tramos(t, [(0.0, 0.0), (0.14, -0.5), (0.30, -0.2), (1.0, 0.0)]),
                apaga=1.0 if t > 0.2 else 0.0)


ANIMS = {
    'idle': (8, 4.0, True, 8, anim_idle),
    'walk': (8, 8.0, True, 8, anim_walk),
    'embestida': (8, 12.0, False, 8, anim_embestida),
    'despegar': (6, 10.0, False, 8, anim_despegar),
    'vuelo': (6, 7.0, True, 8, anim_vuelo),
    'picar': (8, 12.0, False, 8, anim_picar),
    'mirada': (8, 8.0, False, 8, anim_mirada),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 11.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'gargola_6a7380_2.40', VISTAS + 'gargola_vs_viejo.png', 3))
    else:
        hornear('gargola_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
