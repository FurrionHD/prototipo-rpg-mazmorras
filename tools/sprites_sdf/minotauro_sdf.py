# ============================================================
#  minotauro_sdf.py -- el MINOTAURO como FORMAS QUE SE FUNDEN (SDF), con HUESOS, pintado desde la camara del juego.
#
#  Por que asi (01/10): dibujado con bolas en 2D (minotauro_sprites.gd viejo) no habia forma de que pareciera un
#  cuerpo -- "tumores en los hombros, no agarra el hacha, la cara plana". Aqui cada parte es una forma 3D y las del
#  cuerpo se FUNDEN (smin): el hombro pasa al brazo como musculo. Se pinta con raymarching ortografico desde la camara
#  del juego (45 grados), a tres tonos planos por material y con el contorno del juego.
#
#  LOS HUESOS: cada pieza esta definida en la POSE DE REPOSO y cuelga de un hueso (torso, cabeza, brazo, antebrazo,
#  muslo, pierna, cola). La pose dice cuanto gira cada articulacion; la pieza se evalua llevando el punto al marco de
#  reposo de su hueso. El hacha cuelga del antebrazo derecho: va siempre en la mano.
#
#  Uso:  python tools/sprites_sdf/minotauro_sdf.py [anim ...]
#     -> assets/sprites/enemigos/minotauro_sdf/<anim>.png  (hoja: filas = direcciones, columnas = fotogramas)
#        assets/sprites/enemigos/minotauro_sdf/hojas.json   (lienzo y fps de cada animacion; lo lee MinotauroSprites)
#        tools/salida/sdf/<anim>_vista.png                   (vista ampliada para mirarla)
#  Sin argumentos: todas. 'vistas' saca solo la pose quieta en 5 direcciones (tools/salida/sdf/sdf_<dir>.png).
# ============================================================
import sys, math, json, os
from multiprocessing import Pool
import numpy as np
from PIL import Image

SALIDA = 'assets/sprites/enemigos/minotauro_sdf/'
VISTAS = 'tools/salida/sdf/'

# --- CAMARA (la del juego: pantalla_y = y*cos - z*sin) ---
CAM = math.radians(45.0)
C, S = math.cos(CAM), math.sin(CAM)
R_ = np.array([1.0, 0.0, 0.0])
U_ = np.array([0.0, -C, S])          # arriba en pantalla
F_ = np.array([0.0, -S, -C])         # hacia dentro de la pantalla
# EL TAMAÑO DEL PIXEL DEL JUEGO: 1 celda = 1,15 unidades (SpriteLienzo.UNIDADES_POR_CELDA) y el Minotauro va a escala
# 3,1 (guardian_rango.tres): 3,1 / 1,15 celdas por unidad del modelo. El lienzo y los pies, donde los ponia el generador
# viejo (ancho 1,46 / arriba 1,28 / abajo 0,34 de su altura de 40), para que el juego lo coloque igual.
PPU = 3.1 / 1.15
_ALTO_CELDAS = 40.0 * PPU
# EL ANCHO, MAS QUE EL VIEJO (1,46 -> 2,2): con el brazo estirado y el hacha (el barrido) llega a ~30 unidades del
# centro. Crece igual a los dos lados, asi que el centro y los pies siguen donde estaban.
W = int(math.ceil(_ALTO_CELDAS * 2.2)); W += W % 2
H = int(math.ceil(_ALTO_CELDAS * 1.62)); H += H % 2
OX, OY = W / 2, _ALTO_CELDAS * 1.28
# Y MAS ALTO, crecido IGUAL por arriba y por abajo (el hacha en alto se salia por arriba y al golpear hacia la camara,
# por abajo): el centro del lienzo -- donde el juego pone el nodo -- no se mueve respecto a los pies.
MARGEN_V = 58
H += 2 * MARGEN_V; OY += MARGEN_V
ESTIRA = 1.18                        # las alturas, estiradas (si no, a 45 grados un humanoide sale achaparrado)
PIERNA_EXTRA = 1.8                   # de la cadera para arriba sube esto: piernas mas largas

def Z(x, y, z):
    if z >= 18.0:
        z += PIERNA_EXTRA
    return np.array([x, y, z * ESTIRA], dtype=float)

# --- PRIMITIVAS (P: N x 3) ---
def sd_esfera(P, c, r):
    return np.linalg.norm(P - c, axis=1) - r

def sd_elipsoide(P, c, rad):
    q = (P - c) / rad
    k0 = np.linalg.norm(q, axis=1)
    k1 = np.linalg.norm(q / rad, axis=1)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-6)

def sd_cono(P, a, b, ra, rb):
    """Capsula con radio que va de ra (en a) a rb (en b)."""
    pa = P - a; ba = b - a
    h = np.clip((pa @ ba) / max(ba @ ba, 1e-6), 0.0, 1.0)
    return np.linalg.norm(pa - np.outer(h, ba), axis=1) - (ra + (rb - ra) * h)

def sd_caja(P, c, ejes, medio, redondeo=0.2):
    """Caja orientada: 'ejes' = 3 vectores unitarios (filas), 'medio' = semilados."""
    q = (P - c) @ np.array(ejes).T
    d = np.abs(q) - (np.array(medio) - redondeo)
    return np.linalg.norm(np.maximum(d, 0.0), axis=1) + np.minimum(d.max(axis=1), 0.0) - redondeo

def smin(a, b, k):
    if k <= 0: return np.minimum(a, b)
    h = np.clip(0.5 + 0.5 * (b - a) / k, 0.0, 1.0)
    return b + (a - b) * h - k * h * (1.0 - h)

# --- HUESOS: transformaciones rigidas (M, t): p_mundo = M p_reposo + t ---
IDENT = (np.eye(3), np.zeros(3))

def rx(a):
    """Gira en el plano Y-Z: con 'a' positivo, lo que esta ENCIMA del pivote se va hacia DELANTE (+Y)."""
    c, s = math.cos(a), math.sin(a)
    return np.array([[1, 0, 0], [0, c, s], [0, -s, c]], dtype=float)

def ry(a):
    """Gira en el plano X-Z (abrir el brazo hacia fuera: 'a' positivo lleva +Z hacia +X)."""
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]], dtype=float)

def rz(a):
    """Gira alrededor de la vertical."""
    c, s = math.cos(a), math.sin(a)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]], dtype=float)

def sobre(pivote, M):
    """Girar M alrededor de 'pivote'."""
    return (M, pivote - M @ pivote)

def mover(v):
    return (np.eye(3), np.array(v, dtype=float))

def comp(X2, X1):
    """Primero X1, luego X2."""
    return (X2[0] @ X1[0], X2[0] @ X1[1] + X2[1])

def aplica(X, p):
    return X[0] @ p + X[1]

# --- MATERIALES: tres tonos (sombra, base, luz) ---
MAT = {
    'piel':   [(0.56, 0.23, 0.13), (0.70, 0.30, 0.16), (0.82, 0.41, 0.21)],
    'pelo':   [(0.22, 0.12, 0.09), (0.32, 0.18, 0.13), (0.42, 0.25, 0.18)],
    'pezuna': [(0.15, 0.16, 0.23), (0.22, 0.24, 0.32), (0.32, 0.34, 0.43)],
    'cuero':  [(0.15, 0.10, 0.08), (0.23, 0.15, 0.12), (0.31, 0.21, 0.16)],
    'cuerno': [(0.70, 0.60, 0.46), (0.87, 0.78, 0.62), (0.96, 0.91, 0.79)],
    'morro':  [(0.66, 0.38, 0.34), (0.84, 0.54, 0.48), (0.93, 0.68, 0.62)],
    'ojo':    [(1.00, 0.78, 0.10), (1.00, 0.82, 0.15), (1.00, 0.90, 0.40)],
    'oro':    [(0.70, 0.50, 0.08), (0.94, 0.74, 0.16), (1.00, 0.90, 0.45)],
    'hierro': [(0.20, 0.21, 0.25), (0.31, 0.32, 0.37), (0.46, 0.47, 0.52)],
    'filo':   [(0.62, 0.62, 0.66), (0.80, 0.80, 0.83), (0.92, 0.92, 0.94)],
    'madera': [(0.30, 0.17, 0.10), (0.42, 0.25, 0.14), (0.52, 0.33, 0.19)],
    'cuerda': [(0.42, 0.31, 0.18), (0.58, 0.45, 0.27), (0.70, 0.57, 0.36)],
    'cuerda2': [(0.32, 0.23, 0.13), (0.46, 0.35, 0.20), (0.56, 0.44, 0.27)],
}
NOMBRES = list(MAT.keys())
BORDE = (0.13, 0.06, 0.05)

# --- LAS ARTICULACIONES EN REPOSO (para girar alrededor de ellas) ---
PELVIS_PIV = Z(0, -0.4, 21.0)
CUELLO_PIV = Z(0, 0.0, 33.0)
def HOMBRO(s): return Z(8.5 * s, 0.4, 31.4)
def CODO(s): return Z(10.0 * s, -1.0, 23.6)
def MUNECA(s): return Z(11.2 * s, 2.0, 16.8)
def CADERA(s): return Z(3.6 * s, 0.0, 20.0)
def RODILLA(s): return Z(4.3 * s, 1.4, 11.8)
def PIE(s): return Z(4.4 * s, 0.6, 1.3)
HACHA_LADO = -1          # la mano DERECHA del bicho (a la izquierda de la pantalla mirando al sur)


def POSE(**k):
    """La pose de reposo con todo a cero; cada animacion cambia lo suyo."""
    p = dict(avance=0.0, agacha=0.0, inclina=0.0, gira=0.0, ladea=0.0, cabeza=0.0, cabeza_gira=0.0,
             brazo_d=(0.0, 0.0, 0.0), brazo_i=(0.0, 0.0, 0.0),        # (adelante, abre, codo) en radianes
             pierna_d=(0.0, 0.0), pierna_i=(0.0, 0.0),                 # (adelante, rodilla)
             cola=0.0, hacha='mano', mango=None, pies=None, una_mano=False)
    p.update(k)
    return p


def rot_entre(u, v):
    """La rotacion minima que lleva la direccion u a la v (Rodrigues)."""
    u = u / np.linalg.norm(u); v = v / np.linalg.norm(v)
    eje = np.cross(u, v); s_ = np.linalg.norm(eje); c_ = float(u @ v)
    if s_ < 1e-6:
        return np.eye(3)
    k = eje / s_
    K = np.array([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + K * s_ + K @ K * (1 - c_)


def puno_reposo(s):
    return MUNECA(s) + Z(0.2 * s, 0.4, -2.2)


def agarre_hacha(pose):
    """Donde va el hacha en el marco de reposo del antebrazo derecho, para 'alto' y 'lado': (puño, eje del mango hacia
    la cabeza, largo). En el hachazo se coge por el extremo (palanca larga), tambien en el barrido: asi el hacha sale LEJOS del cuerpo."""
    puno = MUNECA(HACHA_LADO) + Z(-0.2, 0.4, -2.2)
    abajo = np.array([0.0, 0.15, -1.0]); abajo /= np.linalg.norm(abajo)
    largo = 11.5
    return puno, abajo, largo


def ik(S, T, L1, L2, polo):
    """Dos huesos: el codo y la mano para que la mano llegue a T desde el hombro S (si no llega, se queda estirada
    hacia T). 'polo' es hacia donde sale el codo."""
    d = T - S; n = np.linalg.norm(d); dn = d / n
    dist = float(np.clip(n, abs(L1 - L2) + 0.01, L1 + L2 - 0.01))
    a = (L1 * L1 - L2 * L2 + dist * dist) / (2 * dist)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    p = polo - dn * (polo @ dn); p /= np.linalg.norm(p)
    return S + dn * a + p * h, S + dn * dist


def huesos(pose):
    """Las transformaciones de cada hueso para esta pose."""
    raiz = mover((0.0, pose['avance'], -pose['agacha'] * ESTIRA))
    # EL TORSO gira sobre la pelvis: se inclina hacia delante, se ladea y se tuerce.
    torso = comp(raiz, sobre(PELVIS_PIV, rz(pose['gira']) @ ry(pose['ladea']) @ rx(pose['inclina'])))
    X = {'raiz': raiz, 'torso': torso}
    X['cabeza'] = comp(torso, sobre(CUELLO_PIV, rz(pose['cabeza_gira']) @ rx(-pose['cabeza'])))
    X['cola'] = comp(torso, sobre(Z(0, -4.6, 21.4), rz(pose['cola'])))
    # EL FALDON SIGUE A LOS MUSLOS (01/10: al subir la rodilla en el pisoton, el muslo lo atravesaba): el de delante se
    # levanta con la pierna que se adelanta, el de atras con la que se va hacia atras. Gira desde el cinturon.
    adel = [pose['pierna_d'][0], pose['pierna_i'][0]]
    X['faldon_del'] = comp(raiz, sobre(Z(0, 4.5, 20.6), rx(0.8 * max(max(adel), 0.0))))
    X['faldon_tras'] = comp(raiz, sobre(Z(0, -4.5, 20.6), rx(0.8 * min(min(adel), 0.0))))
    for s, nom in ((HACHA_LADO, 'd'), (-HACHA_LADO, 'i')):
        a, abre, codo, *resto = pose['brazo_' + nom]
        # 'barre' (opcional, 4o valor): el brazo gira alrededor de la VERTICAL en el hombro (+ hacia la derecha del bicho,
        # - hacia su izquierda). Hace falta para un barrido: con el brazo estirado al frente, 'abre' casi no lo mueve.
        barre = resto[0] if resto else 0.0
        # Los signos: rx(+) lleva hacia DELANTE lo que esta ENCIMA del pivote, y hacia atras lo que cuelga DEBAJO. El
        # brazo y la pierna cuelgan, asi que "adelante" es rx(-); el codo dobla hacia delante (rx(-)) y la rodilla
        # hacia atras (rx(+)).
        # 'abre' + = hacia FUERA (con ry, el brazo colgando se va a -X con angulo +: por eso -abre*s).
        brazo = comp(torso, sobre(HOMBRO(s), rz(barre) @ ry(-abre * s) @ rx(-a)))
        X['brazo_' + nom] = brazo
        X['antebrazo_' + nom] = comp(brazo, sobre(CODO(s), rx(-codo)))
        adel, rod = pose['pierna_' + nom]
        muslo = comp(raiz, sobre(CADERA(s), rx(-adel)))
        X['muslo_' + nom] = muslo
        X['pierna_' + nom] = comp(muslo, sobre(RODILLA(s), rx(rod)))
    # LAS PEZUÑAS EN EL SUELO (01/10, la cornada a cuatro patas): con 'pies' (desplazamiento de cada pezuña respecto a su
    # sitio de reposo, en el mundo) las piernas se doblan para que la pezuña quede ahi aunque la cadera baje ('agacha').
    # Sin esto, agacharse hundia las pezuñas en el suelo, porque la raiz baja con todo.
    if pose.get('pies') is not None:
        for s, nom in ((HACHA_LADO, 'd'), (-HACHA_LADO, 'i')):
            if pose['pies'].get(nom) is None:
                continue          # esta pierna va por sus angulos (la que sube en el pisoton)
            off = np.array(pose['pies'][nom], dtype=float)
            S0 = CADERA(s); E0 = RODILLA(s); F0 = PIE(s)
            S = aplica(X['raiz'], S0)
            T = F0 + np.array([0.0, pose['avance'], 0.0]) + np.array([off[0], off[1], off[2] * ESTIRA])
            E, F = ik(S, T, np.linalg.norm(E0 - S0), np.linalg.norm(F0 - E0), np.array([0.0, 1.0, 0.15]))
            R1 = rot_entre(E0 - S0, E - S)
            X['muslo_' + nom] = (R1, S - R1 @ S0)
            R2 = rot_entre(R1 @ (F0 - E0), F - E) @ R1
            X['pierna_' + nom] = (R2, E - R2 @ E0)
    # A DOS MANOS (01/10): la animacion dice por donde va el MANGO ('mango' = (punto de agarre, hacia donde apunta la
    # cabeza del hacha), en el marco del torso en reposo) y LOS DOS BRAZOS se doblan para llegar: la derecha en el
    # agarre y la izquierda un poco mas arriba del mango (IK de dos huesos, codos hacia fuera y abajo). Antes se movia el
    # brazo derecho por angulos y la izquierda intentaba alcanzarlo: con el brazo estirado, el mango quedaba mas lejos
    # de lo que mide el otro brazo y la mano se quedaba a medio camino ("no agarra con las dos manos").
    if pose.get('mango') is not None:
        G, D = pose['mango']
        Mt = X['torso'][0]
        Gw = aplica(X['torso'], np.array(G, dtype=float))
        Dw = Mt @ (np.array(D, dtype=float) / np.linalg.norm(D))
        manos = ((HACHA_LADO, 'd', Gw), (-HACHA_LADO, 'i', Gw + Dw * 2.6))
        if pose.get('una_mano'):
            manos = manos[:1]
        for s, nom, T in manos:
            S0 = HOMBRO(s); E0 = CODO(s); F0 = puno_reposo(s)
            S = aplica(X['torso'], S0)
            E, F = ik(S, T, np.linalg.norm(E0 - S0), np.linalg.norm(F0 - E0), Mt @ np.array([s * 1.0, -0.3, -0.6]))
            R1 = rot_entre(Mt @ (E0 - S0), E - S) @ Mt
            X['brazo_' + nom] = (R1, S - R1 @ S0)
            R2 = rot_entre(R1 @ (F0 - E0), F - E) @ R1
            X['antebrazo_' + nom] = (R2, E - R2 @ E0)
        # EL HACHA cuelga del agarre: su puño de reposo va a Gw y su mango apunta a Dw.
        puno, abajo, largo = agarre_hacha(pose)
        Rh = rot_entre(abajo, Dw)
        X['hacha'] = (Rh, Gw - Rh @ puno)
    return X


def escena(pose):
    """Lista de (sdf_fn, material, grupo, k, hueso). Las del grupo 'cuerpo' se FUNDEN entre si con su k; el resto se
    une duro. Cada pieza esta en la pose de REPOSO y cuelga de su hueso."""
    X = huesos(pose)
    L = []
    def add(fn, mat, k=0.0, grupo='cuerpo', hueso='torso'):
        L.append((fn, mat, grupo, k, X[hueso], hueso))

    # TORSO EN V
    add(lambda P: sd_elipsoide(P, Z(0, -0.4, 21.4), np.array([4.1, 3.9, 3.2 * ESTIRA])), 'piel', 0, hueso='raiz')
    add(lambda P: sd_elipsoide(P, Z(0, 0.8, 24.8), np.array([4.8, 4.2, 3.8 * ESTIRA])), 'piel', 2.0)
    add(lambda P: sd_elipsoide(P, Z(0, 1.0, 29.4), np.array([8.0, 5.6, 5.4 * ESTIRA])), 'piel', 2.0)
    for s in (-1, 1):
        add(lambda P, s=s: sd_elipsoide(P, Z(3.9 * s, 3.8, 29.0), np.array([3.8, 2.8, 3.2 * ESTIRA])), 'piel', 1.2)
    add(lambda P: sd_elipsoide(P, Z(0, -1.2, 32.6), np.array([4.6, 3.4, 2.4 * ESTIRA])), 'piel', 1.6)   # trapecio
    add(lambda P: sd_cono(P, Z(0, 0.0, 32.0), Z(0, 1.0, 36.4), 3.3, 3.0), 'piel', 1.2, hueso='cabeza')  # cuello

    # BRAZOS: deltoide (torso), brazo con biceps y triceps (brazo), antebrazo, brazalete y puño (antebrazo)
    for s, nom in ((HACHA_LADO, 'd'), (-HACHA_LADO, 'i')):
        hom = HOMBRO(s); codo = CODO(s); mun = MUNECA(s)
        add(lambda P, c=hom: sd_elipsoide(P, c - Z(0, 0, 0.6), np.array([2.9, 3.0, 3.2 * ESTIRA])), 'piel', 2.2)
        hb = 'brazo_' + nom; ha = 'antebrazo_' + nom
        gb = 'brazo_' + nom      # el brazo se funde CONSIGO MISMO, no con el pecho (si no, al cruzar por delante se mezclaba)
        add(lambda P, a=hom, b=codo: sd_cono(P, a, b, 2.6, 2.0), 'piel', 0, gb, hueso=hb)
        bi = hom + (codo - hom) * 0.5
        add(lambda P, c=bi + np.array([0.3 * s, 1.3, 0.0]): sd_elipsoide(P, c, np.array([2.9, 2.1, 3.0 * ESTIRA])), 'piel', 0.7, gb, hueso=hb)
        add(lambda P, c=bi + np.array([0.9 * s, -1.1, 0.4]): sd_elipsoide(P, c, np.array([2.7, 2.0, 3.2 * ESTIRA])), 'piel', 0.7, gb, hueso=hb)
        add(lambda P, a=codo, b=mun: sd_cono(P, a, b, 2.1, 1.9), 'piel', 0.8, gb, hueso=ha)
        ab = codo + (mun - codo) * 0.3
        add(lambda P, c=ab + np.array([0.7 * s, 0.5, 0.0]): sd_elipsoide(P, c, np.array([3.1, 2.4, 3.4 * ESTIRA])), 'piel', 0.8, gb, hueso=ha)
        add(lambda P, a=codo, b=mun: sd_cono(P, a + (b - a) * 0.45, a + (b - a) * 0.95, 2.95, 2.7), 'cuero', 0, 'brazalete', hueso=ha)
        puno = mun + Z(0.2 * s, 0.4, -2.2)
        add(lambda P, c=puno: sd_elipsoide(P, c, np.array([2.6, 2.6, 2.6 * ESTIRA])), 'piel', 0.8, gb, hueso=ha)

    # PIERNAS digitigradas: muslo (muslo), rodilla adelante, corvejon atras y pezuña (pierna)
    for s, nom in ((HACHA_LADO, 'd'), (-HACHA_LADO, 'i')):
        cad = CADERA(s); rod = RODILLA(s); cor = Z(4.3 * s, -1.2, 5.6); pie = Z(4.4 * s, 0.6, 1.3)
        add(lambda P, a=cad, b=rod: sd_cono(P, a, b, 3.2, 2.7), 'piel', 1.5, hueso='muslo_' + nom)
        add(lambda P, a=rod, b=cor: sd_cono(P, a, b, 2.6, 1.9), 'pelo', 1.0, hueso='pierna_' + nom)
        add(lambda P, a=cor, b=pie: sd_cono(P, a, b, 1.9, 1.7), 'pelo', 0.8, hueso='pierna_' + nom)
        add(lambda P, c=Z(4.4 * s, 1.0, 1.0): sd_elipsoide(P, c, np.array([2.1, 2.6, 1.2 * ESTIRA])), 'pezuna', 0.4, hueso='pierna_' + nom)

    # CABEZA: craneo, cara larga hacia abajo, morro claro, cejas, orejas, ojos, anilla
    hc = 'cabeza'
    add(lambda P: sd_elipsoide(P, Z(0, 0.8, 39.0), np.array([3.8, 3.8, 3.4 * ESTIRA])), 'piel', 1.5, hueso=hc)
    add(lambda P: sd_cono(P, Z(0, 2.0, 38.6), Z(0, 6.4, 36.2), 3.3, 2.8), 'piel', 1.2, hueso=hc)
    add(lambda P: sd_elipsoide(P, Z(0, 7.3, 35.6), np.array([2.9, 2.1, 1.9 * ESTIRA])), 'morro', 0, 'morro', hueso=hc)
    for s in (-1, 1):
        add(lambda P, s=s: sd_elipsoide(P, Z(2.1 * s, 3.8, 40.0), np.array([1.5, 1.2, 0.7 * ESTIRA])), 'piel', 0.6, hueso=hc)
        add(lambda P, s=s: sd_elipsoide(P, Z(4.3 * s, 0.2, 39.4), np.array([2.0, 0.9, 0.9 * ESTIRA])), 'piel', 0.5, hueso=hc)
        add(lambda P, s=s: sd_esfera(P, Z(2.3 * s, 5.0, 38.9), 0.85), 'ojo', 0, 'ojo', hueso=hc)
        add(lambda P, s=s: sd_esfera(P, Z(1.1 * s, 9.2, 35.9), 0.5), 'pelo', 0, 'narina', hueso=hc)
    def anilla(P):
        q = P - Z(0, 8.8, 34.3)
        d2 = np.sqrt(q[:, 0] ** 2 + (q[:, 2] / ESTIRA) ** 2) - 1.2
        return np.sqrt(d2 ** 2 + q[:, 1] ** 2) - 0.38
    add(anilla, 'oro', 0, 'anilla', hueso=hc)
    # CUERNOS EN U (y el izquierdo partido en la variante 'roto', la rabia)
    for s in (-1, 1):
        p = Z(3.2 * s, 0.6, 41.2); th = 0.30; r = 1.8
        n_seg = 3 if (pose.get('roto') and s == 1) else 7
        for k in range(n_seg):
            d = np.array([math.cos(th) * s, 0.12 + 0.06 * k, math.sin(th) * ESTIRA]); d /= np.linalg.norm(d)
            q = p + d * 1.7; r2 = max(0.5, r - 0.2)
            add(lambda P, a=p, b=q, ra=r, rb=r2: sd_cono(P, a, b, ra, rb), 'cuerno', 0, 'cuerno', hueso=hc)
            p = q; r = r2; th += 0.26

    # TAPARRABOS: cinturon pegado a la piel (busca la superficie del cuerpo en cada direccion), nudo y tiras.
    def cuerpo_reposo(P):
        d = None
        for fn, m, g, k, Xh, nh in L:
            if g == 'cuerpo' and not nh.startswith('brazo') and not nh.startswith('antebrazo'):
                v = fn(P)
                d = v if d is None else smin(d, v, k)
        return d
    def superficie(ang, z):
        dv = np.array([math.sin(ang), math.cos(ang), 0.0])
        c = Z(0, -0.3, z)
        rr = np.arange(0.0, 14.0, 0.1)
        dist = cuerpo_reposo(c + np.outer(rr, dv))
        fuera = np.where(dist > 0)[0]
        return c + dv * rr[fuera[0] if len(fuera) else -1], dv
    for k in range(36):
        ang = 2 * math.pi * k / 36
        p0, dv = superficie(ang, 20.9)
        add(lambda P, c=p0 + dv * 0.2: sd_elipsoide(P, c, np.array([1.0, 1.0, 1.0 * ESTIRA])), 'cuero', 0, 'ropa', hueso='raiz')
    p_n, d_n = superficie(0.25, 20.9)
    nudo = p_n + d_n * 0.8
    add(lambda P: sd_elipsoide(P, nudo, np.array([1.0, 0.8, 0.9 * ESTIRA])), 'cuerda', 0, 'cuerda', hueso='raiz')
    for off, largo in ((0.0, 3.6), (0.9, 2.8)):
        a = nudo + np.array([0.4 + off, 0.3, 0.0]); b = a + np.array([0.6, 0.4, -largo * ESTIRA])
        add(lambda P, a=a, b=b: sd_cono(P, a, b, 0.5, 0.4), 'cuerda2', 0, 'cuerda', hueso='raiz')
        add(lambda P, c=b: sd_esfera(P, c, 0.6), 'cuerda', 0, 'cuerda', hueso='raiz')
    E = ESTIRA
    for s in (1, -1):
        pts = [np.array([0, 4.5 * s, (20.4 + PIERNA_EXTRA) * E]), np.array([0, 5.4 * s, (17.4 + 1.2) * E]),
               np.array([0, 5.1 * s, (14.4 + 0.5) * E]), np.array([0, 4.5 * s, 11.8 * E])]
        anchos = [2.3, 2.1, 1.9]
        for k in range(3):
            a, b = pts[k], pts[k + 1]
            eje = (b - a) / np.linalg.norm(b - a)
            ex = np.array([1.0, 0, 0]); ey = np.cross(eje, ex)
            add(lambda P, a=a, b=b, ex=ex, ey=ey, eje=eje, w=anchos[k]: sd_caja(P, (a + b) / 2, [ex, ey, eje],
                [w, 0.35, np.linalg.norm(b - a) / 2 + 0.35], 0.3), 'cuero', 0, 'ropa',
                hueso='faldon_del' if s > 0 else 'faldon_tras')

    # COLA con borla
    p = Z(0, -4.6, 21.4)
    for k in range(8):
        f = k / 7.0
        q = p + Z(0.5 * f, -0.7 + 0.4 * f, -1.05)
        add(lambda P, a=p, b=q: sd_cono(P, a, b, 0.7, 0.65), 'piel', 0.3, 'cola', hueso='cola')
        p = q
    add(lambda P, c=p: sd_elipsoide(P, c, np.array([1.3, 1.3, 2.0 * ESTIRA])), 'pelo', 0.5, 'cola', hueso='cola')

    # EL HACHA. En la mano: cuelga del antebrazo derecho (la cabeza bajo el puño, el mango subiendo por detras del
    # antebrazo). A la espalda: en diagonal, de la cadera derecha al hombro izquierdo, colgada del torso.
    if pose['hacha'] == 'mano':
        puno = MUNECA(HACHA_LADO) + Z(-0.2, 0.4, -2.2)
        abajo = np.array([-0.18, 0.1, -1.0]); abajo /= np.linalg.norm(abajo)
        afuera = np.array([-0.35, 1.0, 0.0]); afuera /= np.linalg.norm(afuera)
        mango_a, mango_b = puno - abajo * 6.0, puno + abajo * 5.5
        cab = puno + abajo * 5.6
        h_hacha = 'antebrazo_d'
    elif pose['hacha'] in ('alto', 'lado'):
        puno, abajo, largo = agarre_hacha(pose)
        h_hacha = 'hacha' if pose.get('mango') is not None else 'antebrazo_d'
        # EL FILO POR DELANTE (01/10, "si no le esta golpeando con la parte roma"): las hojas van en el plano que forman
        # el mango y HACIA DONDE SE MUEVE la cabeza del hacha en este fotograma ('filo', que pone _trabajo mirando el
        # instante de antes y el de despues). Sin movimiento (o sin dato), en el plano de delante.
        afuera = np.array([0.0, 1.0, 0.0])
        if pose.get('filo') is not None:
            v = X[h_hacha][0].T @ np.array(pose['filo'])
            v = v - abajo * (v @ abajo)
            if np.linalg.norm(v) > 1e-3:
                afuera = v / np.linalg.norm(v)
        mango_a, mango_b = puno - abajo * 1.6, puno + abajo * largo
        cab = puno + abajo * (largo - 1.0)
    else:
        base = Z(4.0, -5.4, 18.5); tope = Z(-5.0, -5.4, 33.5)
        abajo = (base - tope) / np.linalg.norm(base - tope)
        afuera = np.array([0.0, 0.0, 1.0]); afuera = afuera - abajo * (afuera @ abajo); afuera /= np.linalg.norm(afuera)
        afuera = np.cross(abajo, np.array([0.0, 1.0, 0.0])); afuera /= np.linalg.norm(afuera)
        mango_a, mango_b = tope, base
        cab = tope + abajo * 1.2
        h_hacha = 'torso'
    normal = np.cross(afuera, abajo); normal /= np.linalg.norm(normal)
    add(lambda P: sd_cono(P, mango_a, mango_b, 0.55, 0.55), 'madera', 0, 'hacha', hueso=h_hacha)
    for sg in (1, -1):
        def hoja(P, sg=sg):
            q = P - cab
            t = q @ abajo; dd = q @ afuera * sg; n = q @ normal
            e = np.sqrt(((dd - 3.4) / 3.6) ** 2 + (t / (1.4 + 0.75 * np.clip(dd, 0, 6))) ** 2) - 1.0
            d2 = np.maximum(e * 2.0, 0.6 - dd)
            return np.maximum(d2, np.abs(n) - 0.35)
        add(hoja, 'hierro', 0, 'hacha', hueso=h_hacha)
        def filo(P, sg=sg):
            q = P - cab
            t = q @ abajo; dd = q @ afuera * sg; n = q @ normal
            e = np.sqrt(((dd - 3.4) / 3.6) ** 2 + (t / (1.4 + 0.75 * np.clip(dd, 0, 6))) ** 2) - 1.0
            d2 = np.maximum(np.abs(e * 2.0 + 0.5) - 0.5, 4.2 - dd)
            return np.maximum(d2, np.abs(n) - 0.4)
        add(filo, 'filo', 0, 'hacha', hueso=h_hacha)
    add(lambda P: sd_cono(P, cab - abajo * 1.2, cab + abajo * 1.2, 0.95, 0.95), 'hierro', 0, 'hacha', hueso=h_hacha)
    return L


SALTO_ENTRE_GRUPOS = 1.6     # linea entre brazo y cuerpo solo si el brazo va CLARAMENTE por delante (no en el hombro)
SUAVES = ('cuerpo', 'brazo_d', 'brazo_i')     # los grupos que se FUNDEN por dentro; entre ellos, union dura

def evalua(P, L, con_grupo=False):
    """Distancia y material (y el grupo, si se pide): cada grupo de SUAVES se funde por dentro (smin) y lo demas se une
    duro. Cada pieza se evalua llevando el punto al marco de reposo de su hueso: p_reposo = M^T (p - t)."""
    acc = {}; mat = {}; mat_d = {}
    dur = np.full(len(P), 1e9); dur_mat = np.zeros(len(P), dtype=int); dur_g = np.zeros(len(P), dtype=int)
    gid = {g: i for i, g in enumerate(SUAVES)}
    cache = {}
    otros = {}
    for fn, m, g, k, Xh, nh in L:
        if nh not in cache:
            cache[nh] = (P - Xh[1]) @ Xh[0]
        d = fn(cache[nh])
        mi = NOMBRES.index(m)
        if g in gid:
            if g not in acc:
                acc[g] = d; mat[g] = np.full(len(P), mi); mat_d[g] = d
            else:
                acc[g] = smin(acc[g], d, k)
                mejor = d < mat_d[g]
                mat[g] = np.where(mejor, mi, mat[g]); mat_d[g] = np.where(mejor, d, mat_d[g])
        else:
            if g not in otros: otros[g] = len(SUAVES) + len(otros)
            mejor = d < dur
            dur_mat = np.where(mejor, mi, dur_mat); dur_g = np.where(mejor, otros[g], dur_g); dur = np.minimum(dur, d)
    dist = dur; mats = dur_mat; grp = dur_g
    for g, dg in acc.items():
        mejor = dg < dist
        dist = np.where(mejor, dg, dist); mats = np.where(mejor, mat[g], mats); grp = np.where(mejor, gid[g], grp)
    if con_grupo:
        return dist, mats, grp
    return dist, mats


DIR_VECS = [(0, 1), (0.7, 0.7), (1, 0), (0.7, -0.7), (0, -1), (-0.7, -0.7), (-1, 0), (-0.7, 0.7)]

def render(dir_i, pose):
    L = escena(pose)
    v = DIR_VECS[dir_i]
    ang = math.atan2(v[1], v[0]) - math.atan2(1, 0)
    ca, sa = math.cos(-ang), math.sin(-ang)
    jj, ii = np.mgrid[0:H, 0:W]
    u = (ii.ravel() + 0.5 - OX) / PPU
    vv = (OY - (jj.ravel() + 0.5)) / PPU
    O = np.outer(u, R_) + np.outer(vv, U_) - F_ * 90.0
    def a_local(P):
        x = P[:, 0] * ca - P[:, 1] * sa; y = P[:, 0] * sa + P[:, 1] * ca
        return np.stack([x, y, P[:, 2]], axis=1)
    t = np.zeros(len(O)); vivo = np.ones(len(O), dtype=bool); toca = np.zeros(len(O), dtype=bool)
    for _ in range(160):
        idx = np.where(vivo)[0]
        if len(idx) == 0: break
        P = a_local(O[idx] + np.outer(t[idx], F_))
        d, _m = evalua(P, L)
        hit = d < 0.02
        toca[idx[hit]] = True; vivo[idx[hit]] = False
        t[idx[~hit]] += np.maximum(d[~hit] * 0.8, 0.02)
        vivo &= ~(t > 190)
    hi = np.where(toca)[0]
    img = np.zeros((H * W, 4))
    if len(hi) == 0:
        return Image.fromarray((img.reshape(H, W, 4) * 255).astype(np.uint8), 'RGBA')
    P = a_local(O[hi] + np.outer(t[hi], F_))
    _d, mats, grupos = evalua(P, L, True)
    e = 0.05
    n = np.zeros_like(P)
    for a in range(3):
        dv = np.zeros(3); dv[a] = e
        n[:, a] = evalua(P + dv, L)[0] - evalua(P - dv, L)[0]
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-6)
    # La luz, FIJA EN PANTALLA (arriba a la izquierda y algo de delante): se gira con el bicho al reves.
    luz_mundo = np.array([-0.75, 0.35, 0.6]); luz_mundo /= np.linalg.norm(luz_mundo)
    lx = luz_mundo[0] * ca - luz_mundo[1] * sa; ly = luz_mundo[0] * sa + luz_mundo[1] * ca
    ndl = n @ np.array([lx, ly, luz_mundo[2]])
    ao = np.clip(evalua(P + n * 1.2, L)[0] / 1.2, 0, 1)
    # PLANO, como los demas enemigos (01/10: "se nota demasiado que es 3D por los brillos"): casi todo en el tono BASE;
    # la LUZ solo en lo que mira hacia arriba (hombros, lomo, craneo) y la SOMBRA solo en lo que da la espalda a la luz
    # de verdad y en los huecos hondos. Con tres bandas por la luz de lado salian manchas siguiendo cada curva.
    arriba = n[:, 2]
    banda = np.where(arriba > 0.72, 2, np.where(ndl < -0.12, 0, 1))
    banda = np.where(ao < 0.3, 0, banda)
    for i, nom in enumerate(NOMBRES):
        sel = mats == i
        bb = np.full(sel.sum(), 2) if nom == 'ojo' else banda[sel]
        img[hi[sel], :3] = np.array(MAT[nom])[bb]
    img[hi, 3] = 1.0
    prof = np.full(H * W, np.inf); prof[hi] = t[hi]
    matmap = np.full(H * W, -1); matmap[hi] = mats
    grpmap = np.full(H * W, -1); grpmap[hi] = grupos; grpmap = grpmap.reshape(H, W)
    img = img.reshape(H, W, 4); prof = prof.reshape(H, W); matmap = matmap.reshape(H, W)
    OJO_I = NOMBRES.index('ojo')
    # CONTORNO de fuera y LINEAS DE DENTRO donde hay salto de profundidad (lo de delante va suelto).
    sal = img.copy()
    opaco = img[:, :, 3] > 0
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        vec_op = np.zeros_like(opaco); vec_pr = np.full_like(prof, np.inf)
        ys = slice(max(0, dy), H + min(0, dy)); yd = slice(max(0, -dy), H + min(0, -dy))
        xs = slice(max(0, dx), W + min(0, dx)); xd = slice(max(0, -dx), W + min(0, -dx))
        vec_op[yd, xd] = opaco[ys, xs]; vec_pr[yd, xd] = prof[ys, xs]
        vec_g = np.full_like(grpmap, -1); vec_g[yd, xd] = grpmap[ys, xs]
        # Y ENTRE GRUPOS DE LOS QUE SE FUNDEN (el brazo por delante del pecho), con poco salto basta.
        cruza = (vec_g != grpmap) & (grpmap < len(SUAVES)) & (vec_g >= 0) & (vec_g < len(SUAVES)) & (vec_pr - prof > SALTO_ENTRE_GRUPOS)
        borde = opaco & (~vec_op | ((matmap != OJO_I) & (vec_pr - prof > 2.6)) | cruza)
        sal[borde, :3] = BORDE
    return Image.fromarray((np.clip(sal, 0, 1) * 255).astype(np.uint8), 'RGBA')


# ------------------------------------------------------------
#  ANIMACIONES: nombre -> (fotogramas, fps, loop, direcciones, funcion t -> pose)
# ------------------------------------------------------------
def anim_idle(t):
    # QUIETO: respira hondo (sube y baja el pecho), la cabeza se mece y los brazos acompañan un pelin.
    r = math.sin(2 * math.pi * t)
    return POSE(agacha=0.25 * (1 - r) * 0.5, inclina=0.02 * r, cabeza=0.04 * r,
                brazo_d=(0.03 * r, 0.02, 0.05 * r), brazo_i=(0.03 * r, 0.02, 0.05 * r), cola=0.15 * r)

def anim_walk(t):
    # ANDAR: zancada pesada; brazos en contrafase con las piernas; la rodilla de la pierna que avanza se dobla; el
    # cuerpo sube y baja dos veces por ciclo y el torso se tuerce con el paso.
    f = 2 * math.pi * t
    sw = 0.40 * math.sin(f)
    rod_d = 0.55 * max(0.0, math.cos(f)) + 0.1
    rod_i = 0.55 * max(0.0, -math.cos(f)) + 0.1
    return POSE(pierna_d=(sw, rod_d), pierna_i=(-sw, rod_i),
                brazo_d=(-0.28 * math.sin(f), 0.03, 0.15), brazo_i=(0.28 * math.sin(f), 0.03, 0.25),
                agacha=0.35 * (0.5 - 0.5 * math.cos(2 * f)), gira=0.07 * math.sin(f), cabeza=0.05 * math.sin(2 * f),
                cola=0.3 * math.sin(f))

def tramos(t, claves):
    """Interpola por tramos (como SpriteLienzo.tramos): claves = [(t, valor), ...]."""
    if t <= claves[0][0]: return claves[0][1]
    for (t0, v0), (t1, v1) in zip(claves, claves[1:]):
        if t <= t1:
            f = (t - t0) / max(t1 - t0, 1e-6)
            f = f * f * (3 - 2 * f)
            return v0 + (v1 - v0) * f
    return claves[-1][1]

# LOS 8 INSTANTES QUE SE DIBUJAN de una animacion que no repite: 0, 1/7 ... 1. Los momentos clave van EN ellos.
M = [i / 7.0 for i in range(8)]

def _mango(t, claves):
    """Interpola el agarre (punto, direccion) por tramos: claves = [(t, (x, y, z), (dx, dy, dz)), ...] en coordenadas
    de reposo del torso (el punto pasa por Z: estirado como todo lo demas)."""
    P = np.array([tramos(t, [(k[0], Z(*k[1])[i]) for k in claves]) for i in range(3)])
    D = np.array([tramos(t, [(k[0], k[2][i]) for k in claves]) for i in range(3)])
    return (P, D / np.linalg.norm(D))


def anim_basico(t):
    # EL HACHAZO, A UNA MANO (01/10: a dos manos el hacha pasaba por encima y detras de la cabeza y se le metia dentro;
    # "el basico, que es un golpe simple, que lo haga con una mano"). La derecha la sube POR ENCIMA DE SU HOMBRO DERECHO
    # -- por fuera de la cabeza --, la aguanta atras y la deja caer delante hasta clavarla en el suelo en el 6o de 8
    # (M[5]; "mino_hachazo"). La izquierda, libre, se abre para equilibrar. Se anima el MANGO y el brazo lo sigue.
    mango = _mango(t, [
        (M[0], (-10.0, 4.0, 17.0), (-0.15, 0.3, -0.95)),
        (M[1], (-11.5, 9.0, 33.0), (-0.2, 0.3, 0.95)),
        (M[2], (-11.0, -2.0, 43.0), (-0.25, -0.6, 0.75)),
        (M[3], (-11.0, -4.0, 43.5), (-0.25, -0.85, 0.45)),
        (M[4], (-10.0, 6.0, 41.0), (-0.1, 0.55, 0.8)),
        (M[5], (-7.0, 12.0, 21.0), (0.0, 0.6, -0.8)),
        (M[6], (-7.0, 11.5, 20.0), (0.0, 0.55, -0.83)),
        (M[7], (-9.0, 7.0, 19.0), (-0.1, 0.4, -0.9))])
    inclina = tramos(t, [(M[0], 0.0), (M[2], -0.1), (M[3], -0.15), (M[4], 0.1), (M[5], 0.35), (M[6], 0.32), (M[7], 0.12)])
    agacha = tramos(t, [(M[0], 0.0), (M[3], -0.3), (M[5], 1.3), (M[6], 1.1), (M[7], 0.4)])
    avance = tramos(t, [(M[0], 0.0), (M[3], -0.8), (M[5], 2.4), (M[6], 2.4), (M[7], 1.4)])
    gira = tramos(t, [(M[0], 0.0), (M[2], 0.2), (M[3], 0.25), (M[5], -0.15), (M[7], -0.05)])
    cabeza = tramos(t, [(M[0], 0.0), (M[3], 0.1), (M[5], -0.2), (M[7], -0.05)])
    otro = tramos(t, [(M[0], 0.05), (M[3], 0.35), (M[5], -0.3), (M[7], -0.05)])
    paso = tramos(t, [(M[0], 0.0), (M[3], -0.1), (M[5], 0.35), (M[7], 0.2)])
    return POSE(hacha='alto', mango=mango, una_mano=True, brazo_i=(otro, 0.45, 0.35), inclina=inclina, agacha=agacha,
                avance=avance, gira=gira, cabeza=cabeza, pierna_i=(paso, 0.25 * max(0.0, paso)),
                pierna_d=(-0.6 * paso, 0.1), cola=0.3 * gira)


def anim_barrido(t):
    # EL BARRIDO (el cono), A DOS MANOS de lado a lado, como lo dibujo el usuario (01/10): los dos brazos CASI RECTOS y el
    # hacha LEJOS Y BAJA -- a un lado, delante de los pies a mitad (5o de 8, M[4]: "mino_barrido") y al otro lado en
    # espejo --, y recupera. Lo que lleva el hacha de lado a lado es sobre todo el TRONCO (gira): asi los dos hombros
    # quedan de cara al hacha y los dos brazos llegan rectos tambien en los lados. (Con el hacha pegada al cuerpo y a
    # media altura, los codos se doblaban raro.)
    ang = tramos(t, [(M[0], 1.0), (M[1], 1.25), (M[2], 1.4), (M[3], 0.8), (M[4], 0.0), (M[5], -0.8), (M[6], -1.3), (M[7], 0.45)])
    gira = 0.6 * ang
    fi = ang - gira
    z = tramos(t, [(M[0], 21.0), (M[2], 22.0), (M[4], 20.0), (M[6], 21.5), (M[7], 21.0)])
    r = R_BARRIDO
    d = np.array([-math.sin(fi), math.cos(fi), -0.3])
    mango = (Z(-r * math.sin(fi), 1.0 + r * math.cos(fi), z), d / np.linalg.norm(d))
    agacha = tramos(t, [(M[0], 0.6), (M[1], 0.8), (M[2], 0.9), (M[3], 1.0), (M[4], 1.1), (M[5], 1.0), (M[6], 0.9), (M[7], 0.6)])
    inclina = tramos(t, [(M[0], 0.15), (M[2], 0.18), (M[4], 0.28), (M[6], 0.2), (M[7], 0.15)])
    avance = tramos(t, [(M[0], 0.0), (M[2], -0.6), (M[3], 0.3), (M[4], 1.0), (M[5], 1.2), (M[6], 1.0), (M[7], 0.6)])
    return POSE(hacha='lado', mango=mango, gira=gira, agacha=agacha, inclina=inclina, avance=avance,
                cabeza=-0.1 * agacha, cabeza_gira=-0.3 * gira, pierna_i=(0.2 * agacha, 0.15),
                pierna_d=(-0.15 * agacha, 0.1), cola=0.4 * gira)

R_BARRIDO = 10.0

def _cuatro_patas(f):
    """La pose a cuatro patas, mezclada 'f' (0 de pie .. 1 del todo): el torso casi horizontal, la cadera baja, los
    brazos a plomo con los nudillos al suelo, la cabeza baja con los cuernos al frente y la cola arriba (sube sola al
    inclinarse el torso). Es la de la referencia (referencia/embestida.png)."""
    inc = 1.2 * f
    return dict(inclina=inc, agacha=4.6 * f, brazo_d=(inc * 0.95, 0.15 * f, 0.15), brazo_i=(inc * 0.95, 0.15 * f, 0.15),
                cabeza=0.2 * f, pies={'d': (0.0, -2.2 * f, 0.0), 'i': (0.0, 1.6 * f, 0.0)})


def anim_agacharse(t):
    # PONERSE A CUATRO PATAS (mientras avisa la Cornada, fx_anim_carga): se echa el hacha a la espalda (en el 2o
    # fotograma la mano derecha esta por encima del hombro, dejandola) y baja hasta apoyar los nudillos.
    f = tramos(t, [(0.0, 0.0), (0.2, 0.08), (0.4, 0.35), (0.6, 0.7), (0.8, 0.92), (1.0, 1.0)])
    p = _cuatro_patas(f)
    if t < 0.1:
        return POSE(**p)
    # DEJAR EL HACHA (01/10, "no hay animacion de pillar el arma de la espalda"): en el 2o la sube por detras del hombro
    # todavia en la mano (el hacha cuelga a su espalda), en el 3o ya esta en su sitio y la mano la suelta alli.
    if t < 0.3:
        p['brazo_d'] = (2.45, 0.25, 1.75)
        return POSE(hacha='mano', **p)
    if t < 0.5:
        p['brazo_d'] = (2.2, 0.3, 1.45)
    return POSE(hacha='espalda', **p)


def anim_agazapado(t):
    # AGAZAPADO, en bucle hasta que suelta: resopla (el lomo sube y baja) y ESCARBA con la pezuña de atras.
    r = math.sin(2 * math.pi * t)
    p = _cuatro_patas(1.0)
    p['agacha'] += 0.25 * r
    p['pies'] = {'d': (0.0, -2.2 - 1.6 * max(0.0, r), 0.8 * max(0.0, r)), 'i': (0.0, 1.6, 0.0)}
    p['cabeza'] = 0.2 + 0.08 * r
    return POSE(hacha='espalda', cola=0.3 * r, **p)


def anim_cornada(t):
    # LA CORNADA: suelta y embiste a cuatro patas (el juego le desliza por la linea en 0,2 s), al llegar ENGANCHA hacia
    # arriba con los cuernos (3o de 8 a 12 fps: "mino_cornada" 0,17) y se reincorpora; en el ultimo fotograma recupera
    # el hacha a la mano.
    f = tramos(t, [(M[0], 1.0), (M[1], 1.0), (M[2], 0.75), (M[3], 0.6), (M[4], 0.4), (M[5], 0.22), (M[6], 0.08), (M[7], 0.0)])
    p = _cuatro_patas(f)
    gal = math.sin(2 * math.pi * t * 2.0) * (1.0 if t < M[2] else 0.0)
    p['brazo_d'] = (p['brazo_d'][0] + 0.35 * gal, p['brazo_d'][1], 0.15)
    p['brazo_i'] = (p['brazo_i'][0] - 0.35 * gal, p['brazo_i'][1], 0.15)
    # EL ENGANCHE: la cabeza sube de golpe en el 3o y vuelve.
    p['cabeza'] = tramos(t, [(M[0], 0.15), (M[1], 0.0), (M[2], 1.0), (M[3], 0.7), (M[5], 0.2), (M[7], 0.0)])
    p['inclina'] = p['inclina'] - tramos(t, [(M[0], 0.0), (M[2], 0.25), (M[4], 0.1), (M[7], 0.0)])
    # COGER EL HACHA DE LA ESPALDA (01/10): en el 5o la mano sube por encima del hombro hasta el mango; en el 6o ya la
    # tiene (en la mano, colgando por detras); en el 7o la trae por delante y en el 8o la baja a su sitio.
    hacha = 'espalda'
    if t >= M[4] - 1e-6:
        p['brazo_d'] = (2.2, 0.3, 1.45)
    if t >= M[5] - 1e-6:
        p['brazo_d'] = (2.45, 0.25, 1.75); hacha = 'mano'
    if t >= M[6] - 1e-6:
        p['brazo_d'] = (1.1, 0.15, 0.9)
    if t >= M[7] - 1e-6:
        p['brazo_d'] = (0.1, 0.02, 0.15)
    return POSE(hacha=hacha, cola=0.3 * gal, **p)


def anim_pisoton(t):
    # EL PISOTON: carga el peso en la izquierda y LEVANTA LA DERECHA con la rodilla alta, estirandose con los brazos
    # abiertos para equilibrarse (el hacha en la mano); y la DEJA CAER con todo el peso en el 5o de 8 (M[4]; a 12 fps,
    # "mino_pisoton" 0,33): el cuerpo se hunde, la cabeza baja y los brazos caen. Luego se recupera. La pierna de apoyo
    # va siempre al suelo (IK); la que pisa va por angulos mientras sube y al suelo desde que pisa.
    sube = tramos(t, [(M[0], 0.0), (M[1], 0.45), (M[2], 0.9), (M[3], 1.0), (M[4], 0.0), (M[7], 0.0)])
    agacha = tramos(t, [(M[0], 0.0), (M[1], -0.1), (M[2], -0.4), (M[3], -0.5), (M[4], 1.7), (M[5], 1.5), (M[6], 0.7), (M[7], 0.15)])
    inclina = tramos(t, [(M[0], 0.0), (M[2], -0.08), (M[3], -0.1), (M[4], 0.28), (M[5], 0.25), (M[6], 0.12), (M[7], 0.0)])
    brazos = tramos(t, [(M[0], 0.0), (M[2], 0.8), (M[3], 1.0), (M[4], -0.2), (M[5], -0.1), (M[7], 0.0)])
    cabeza = tramos(t, [(M[0], 0.0), (M[3], 0.15), (M[4], -0.35), (M[5], -0.3), (M[7], 0.0)])
    pies = {'i': (0.0, -0.6, 0.0), 'd': (0.0, 2.4, 0.0) if t >= M[4] - 1e-6 else None}
    return POSE(pierna_d=(1.1 * sube, 1.5 * sube), pies=pies, agacha=agacha, inclina=inclina, cabeza=cabeza,
                # Los brazos se ABREN hacia los lados (no al frente) para equilibrarse, y al pisar caen.
                brazo_d=(0.15 * min(brazos, 0.0), 0.65 * max(brazos, 0.0) + 0.05, 0.25),
                brazo_i=(0.15 * min(brazos, 0.0), 0.65 * max(brazos, 0.0) + 0.05, 0.25),
                ladea=-0.06 * sube, cola=0.25 * sube)


def anim_bramido(t):
    # EL BRAMIDO: coge aire (se encoge, la cabeza baja) y BRAMA en el 4o de 8 (M[3]; a 8 fps, "mino_bramido" 0,375): se
    # yergue sacando pecho, echa la CABEZA ATRAS hasta que el morro apunta al cielo, abre el brazo libre y alza el hacha
    # con la derecha. Aguanta temblando y se recupera.
    agacha = tramos(t, [(M[0], 0.0), (M[1], 0.7), (M[2], -0.2), (M[3], -0.4), (M[4], -0.35), (M[5], -0.4), (M[6], 0.0), (M[7], 0.0)])
    inclina = tramos(t, [(M[0], 0.0), (M[1], 0.18), (M[2], -0.08), (M[3], -0.22), (M[4], -0.2), (M[5], -0.22), (M[6], -0.05), (M[7], 0.0)])
    cabeza = tramos(t, [(M[0], 0.0), (M[1], -0.3), (M[2], 0.45), (M[3], 0.85), (M[4], 0.8), (M[5], 0.85), (M[6], 0.3), (M[7], 0.0)])
    abre = tramos(t, [(M[0], 0.0), (M[1], 0.1), (M[2], 0.5), (M[3], 0.85), (M[5], 0.85), (M[6], 0.35), (M[7], 0.05)])
    alza = tramos(t, [(M[0], 0.0), (M[1], 0.1), (M[2], 1.5), (M[3], 2.6), (M[5], 2.6), (M[6], 1.0), (M[7], 0.1)])
    tiembla = 0.04 * math.sin(2 * math.pi * t * 6.0) * (1.0 if M[3] - 1e-6 <= t <= M[5] + 1e-6 else 0.0)
    return POSE(agacha=agacha, inclina=inclina + tiembla, cabeza=cabeza + tiembla,
                brazo_d=(alza, 0.35 * abre, 0.2), brazo_i=(0.35 * abre, abre, 0.7 * abre),
                cola=0.4 * tiembla / 0.04 if tiembla else 0.0)


ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 6.0, True, 8, anim_walk),
    'basico': (8, 10.0, False, 8, anim_basico),
    'barrido': (8, 10.0, False, 8, anim_barrido),
    'mino_agacharse': (6, 10.0, False, 8, anim_agacharse),
    'mino_agazapado': (4, 6.0, True, 8, anim_agazapado),
    'mino_cornada': (8, 12.0, False, 8, anim_cornada),
    'mino_pisoton': (8, 12.0, False, 8, anim_pisoton),
    'mino_bramido': (8, 8.0, False, 8, anim_bramido),
}


def _trabajo(args):
    nombre, d, i = args
    n, fps, loop, dirs, fn = ANIMS[nombre]
    t = i / n if loop else (i / (n - 1) if n > 1 else 0.0)
    pose = fn(t)
    if pose['hacha'] in ('alto', 'lado'):
        # Hacia donde se mueve la cabeza del hacha: el instante de antes y el de despues (ver 'filo' en escena).
        def cabeza(tt):
            pp = fn(min(max(tt, 0.0), 1.0))
            puno, abajo, largo = agarre_hacha(pp)
            Xp = huesos(pp)
            hueso = Xp['hacha'] if pp.get('mango') is not None else Xp['antebrazo_d']
            return aplica(hueso, puno + abajo * (largo - 1.0))
        v = cabeza(t + 0.04) - cabeza(t - 0.04)
        if np.linalg.norm(v) > 0.05:
            pose['filo'] = v
    return (nombre, d, i, render(d, pose))


def hornear(nombres):
    os.makedirs(SALIDA, exist_ok=True); os.makedirs(VISTAS, exist_ok=True)
    trabajos = [(nm, d, i) for nm in nombres for d in range(ANIMS[nm][3]) for i in range(ANIMS[nm][0])]
    with Pool() as pool:
        hechos = pool.map(_trabajo, trabajos)
    meta_path = SALIDA + 'hojas.json'
    meta = json.load(open(meta_path)) if os.path.exists(meta_path) else {}
    meta['lienzo'] = [W, H]
    meta.setdefault('anims', {})
    for nm in nombres:
        n, fps, loop, dirs, fn = ANIMS[nm]
        hoja = Image.new('RGBA', (W * n, H * dirs), (0, 0, 0, 0))
        for (a, d, i, im) in hechos:
            if a == nm:
                hoja.paste(im, (i * W, d * H))
        hoja.save(SALIDA + nm + '.png')
        meta['anims'][nm] = {'fotogramas': n, 'fps': fps, 'loop': loop, 'dirs': dirs}
        # Vista para mirarla: las direcciones 0-4 en filas, ampliada.
        filas = min(dirs, 5)
        vista = Image.new('RGB', (W * n, H * filas), (28, 30, 38))
        recorte = hoja.crop((0, 0, W * n, H * filas))
        vista.paste(recorte, (0, 0), recorte)
        vista = vista.resize((vista.width * 2, vista.height * 2), Image.NEAREST)
        vista.save(VISTAS + nm + '_vista.png')
        print(nm, 'ok')
    json.dump(meta, open(meta_path, 'w'), indent=1)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        for d in range(5):
            render(d, anim_idle(0.0)).save(VISTAS + 'sdf_%d.png' % d)
    else:
        hornear(args or list(ANIMS.keys()))
