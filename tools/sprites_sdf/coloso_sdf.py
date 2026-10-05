# ============================================================
#  coloso_sdf.py -- el COLOSO en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Es la version A de
#  coloso_versiones.py (la ELEGIDA: "el A puede ser el principal"; la E, la de cristales, sera su MUTANTE): un gigante
#  de CANTOS FACETADOS grises con las juntas oscuras, antebrazos y puños enormes, cabeza pequeña hundida entre los
#  hombros con los ojos en una RANURA ambar y las espinillas mas oscuras. Las rocas se crean en el MISMO orden y con la
#  MISMA semilla que en la lamina, asi que son las mismas que eligio.
#
#  HUESOS: raiz (avanza, se agacha), torso (se inclina y gira sobre la pelvis), cabeza, brazo y antebrazo de cada lado.
#  Las PIERNAS por IK: de la cadera (con la raiz) al tobillo, con la rodilla hacia delante; el muslo y la espinilla son
#  rocas rigidas que se ALINEAN con su tramo. Al morir (lo del viejo): se le rompe una rodilla, luego la otra, se
#  vence hacia delante, se le apagan los ojos y SE DESMORONA: cada roca cae a su sitio de un monton (sitio sacado de un
#  hash de su posicion, que no baila entre fotogramas).
#  Los TIEMPOS de cada gesto, los del viejo (coloso_sprites.gd), para que sus efectos aprobados sigan cayendo igual.
#  Lienzo y origen de su horneado (4,00 -> 224 x 238; pies en 112, 161).
#  Uso: python tools/sprites_sdf/coloso_sdf.py [anim ...]  -> assets/sprites/enemigos/coloso_sdf/<anim>.png
#       python tools/sprites_sdf/coloso_sdf.py vistas     -> tools/salida/sdf/coloso_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
from coloso_versiones import sd_roca, _fibo, _giro_azar, MAT_A

SALIDA = 'assets/sprites/enemigos/coloso_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

MAT = dict(MAT_A)
# Los ojos APAGADOS del cadaver (una estatua que sigue mirando no esta muerta).
MAT['apagado'] = [(0.20, 0.19, 0.18)] * 3
BORDE = (0.07, 0.07, 0.08)
LADOS = ((-1, 'd'), (1, 'i'))    # 'd' = su derecha (a la izquierda de la pantalla mirando al sur)


# --- LAS ARTICULACIONES EN REPOSO ---
PELVIS = V((0.0, 0.0, 22.0))
NUCA = V((0.0, 0.4, 38.6))
def CADERA(s): return V((4.8 * s, 0.2, 21.0))
def RODILLA(s): return V((5.1 * s, 1.4, 12.2))
def TOBILLO(s): return V((4.8 * s, 0.6, 3.4))
def HOMBRO(s): return V((9.6 * s, 0.2, 35.6))
def CODO(s): return V((10.8 * s, 1.0, 26.2))
L1 = float(np.linalg.norm(CADERA(1) - RODILLA(1)))
L2 = float(np.linalg.norm(RODILLA(1) - TOBILLO(1)))


def POSE(**k):
    p = dict(agacha=0.0, avance=0.0, inclina=0.0, gira=0.0, balanceo=0.0, cabeza=0.0,
             alza_d=0.0, alza_i=0.0, codo_d=0.0, codo_i=0.0, abre_d=0.0, abre_i=0.0,
             pie_d=(0.0, 0.0), pie_i=(0.0, 0.0), rodilla_d=0.0, rodilla_i=0.0, apaga=0.0, desmorona=0.0)
    p.update(k)
    return p


def _giro_de_a(u, v):
    """La rotacion minima que lleva el vector unitario u al v (Rodrigues)."""
    c = float(u @ v)
    w = np.cross(u, v); s = float(np.linalg.norm(w))
    if s < 1e-8:
        return np.eye(3)
    k = w / s
    K = V([[0, -k[2], k[1]], [k[2], 0, -k[0]], [-k[1], k[0], 0]])
    return np.eye(3) + K * s + K @ K * (1 - c)


def alinea(a0, b0, a1, b1):
    """El hueso rigido que lleva el tramo de reposo a0->b0 al tramo a1->b1 (gira y pone a0 en a1)."""
    u = (b0 - a0) / np.linalg.norm(b0 - a0); v = (b1 - a1) / np.linalg.norm(b1 - a1)
    R = _giro_de_a(u, v)
    return (R, a1 - R @ a0)


def ik(cad, tob, polo=V((0.0, 1.0, 0.0))):
    d = tob - cad; dist = min(float(np.linalg.norm(d)), L1 + L2 - 1e-3); dn = d / max(np.linalg.norm(d), 1e-6)
    a = (L1 * L1 + dist * dist - L2 * L2) / (2 * dist)
    h = math.sqrt(max(L1 * L1 - a * a, 0.0))
    p = polo - dn * (polo @ dn); p /= max(np.linalg.norm(p), 1e-6)
    return cad + dn * a + p * h


def huesos(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], -p['agacha'])))
    raiz = comp(raiz, sobre(V((0.0, 0.0, 0.0)), ry(p['balanceo'] * 0.05)))
    X['raiz'] = raiz
    X['torso'] = comp(raiz, sobre(PELVIS, rz(p['gira']) @ rx(p['inclina'])))
    X['cabeza'] = comp(X['torso'], sobre(NUCA, rx(p['cabeza'])))
    for s, nom in LADOS:
        X['brazo_' + nom] = comp(X['torso'], sobre(HOMBRO(s), ry(-p['abre_' + nom] * s) @ rx(-p['alza_' + nom])))
        X['antebrazo_' + nom] = comp(X['brazo_' + nom], sobre(CODO(s), rx(-p['codo_' + nom])))
        # LAS PIERNAS: la cadera va con la raiz; el tobillo, donde diga la pose (en el suelo salvo al pisar).
        cad = aplica(raiz, CADERA(s))
        dy, dz = p['pie_' + nom]
        tob = TOBILLO(s) + V((0.0, dy, dz))
        rod = ik(cad, tob)
        # DE RODILLAS (al morir): la rodilla al suelo, delante, y la espinilla tumbada hacia atras.
        r = p['rodilla_' + nom]
        if r > 0.0:
            rod_k = V((5.0 * s, 3.6, 2.6))
            tob_k = rod_k + V((0.0, -L2 * 0.97, 0.4))
            rod = rod + (rod_k - rod) * r
            tob = tob + (tob_k - tob) * r
        X['muslo_' + nom] = alinea(CADERA(s), RODILLA(s), cad, rod)
        X['espinilla_' + nom] = alinea(RODILLA(s), TOBILLO(s), rod, tob)
        # El pie-losa: sigue al tobillo; al arrodillarse se queda de punta (gira con la espinilla, a medias).
        Mp, tp = sobre(TOBILLO(s), rx(-1.2 * r))
        X['pie_' + nom] = (Mp, tp + (tob - TOBILLO(s)))
    return X


class _Monta:
    """Como el Monta de las versiones, pero con HUESO por pieza y apuntando el centro de cada roca (para el desmorone)."""
    def __init__(self, X):
        self.e = Escena(X)
        self.rng = np.random.default_rng(11)
        self.n = 0
        self.centros = []

    def _g(self):
        self.n += 1
        return 'p%d' % self.n

    def roca(self, c, r, mat, caras=11, hueso='torso', redondeo=1.32):
        N = _fibo(caras) + self.rng.normal(scale=0.12, size=(caras, 3))
        N /= np.linalg.norm(N, axis=1, keepdims=True)
        R = _giro_azar(self.rng)
        c = V(c, dtype=float); r = V(r, dtype=float)
        self.e.add(lambda P, c=c, r=r, N=N, R=R: sd_roca(P, c, r, N, R, redondeo), mat, 0, self._g(), hueso)
        self.centros.append((c, float(r.mean())))

    def otra(self, fn, mat, grupo, hueso, c):
        self.e.add(fn, mat, 0, grupo, hueso)
        self.centros.append((V(c, dtype=float), 0.6))


def escena(p):
    X = huesos(p)
    m = _Monta(X)
    ojo = 'apagado' if p['apaga'] > 0.5 else 'ojo'
    # (El ORDEN de las rocas es el de version_a: asi salen las mismas.)
    for s, nom in LADOS:
        x = 4.8 * s
        m.roca((x, 1.4, 1.8), (3.4, 4.0, 1.9), 'pie', 9, 'pie_' + nom)
        m.roca((x, 0.2, 6.6), (3.0, 2.8, 3.6), 'pie', 10, 'espinilla_' + nom)
        m.roca((x + 0.3 * s, 1.2, 12.0), (3.2, 3.0, 2.6), 'roca', 10, 'espinilla_' + nom)
        m.roca((x, 0.0, 17.4), (3.6, 3.4, 3.4), 'roca2', 11, 'muslo_' + nom)
        m.roca((x + 1.6 * s, 0.8, 20.6), (2.2, 2.4, 1.8), 'roca', 9, 'muslo_' + nom)
    m.roca((0.0, -0.2, 22.6), (5.4, 3.8, 2.2), 'roca2', 12, 'raiz')
    for s in (-1, 1):
        m.roca((2.2 * s, 1.4, 25.8), (2.4, 2.6, 1.7), 'roca', 9)
        m.roca((2.5 * s, 1.6, 28.8), (2.6, 2.7, 1.7), 'roca', 9)
    m.roca((0.0, -1.0, 27.4), (4.6, 3.4, 3.6), 'roca2', 11)
    m.roca((0.0, -1.6, 34.0), (6.6, 3.8, 5.0), 'roca2', 12)
    for s in (-1, 1):
        m.roca((3.3 * s, 1.8, 33.6), (3.9, 3.0, 3.0), 'roca', 10)
        m.roca((4.6 * s, -0.6, 38.4), (2.8, 2.6, 1.9), 'roca', 9)
    m.roca((0.0, 1.4, 41.4), (2.5, 2.4, 2.7), 'roca', 13, 'cabeza')
    m.otra(lambda P: sd_caja(P, V((0.0, 3.55, 41.6)), np.eye(3), V((1.8, 0.25, 0.3)), 0.1), 'hueco', 'ranura',
           'cabeza', (0.0, 3.55, 41.6))
    for s in (-1, 1):
        m.otra(lambda P, s=s: sd_elipsoide(P, V((0.9 * s, 3.75, 41.6)), V((0.55, 0.3, 0.32))), ojo, 'ojo', 'cabeza',
               (0.9 * s, 3.75, 41.6))
    for s, nom in LADOS:
        hb = 'brazo_' + nom; ha = 'antebrazo_' + nom
        m.roca((9.6 * s, 0.2, 37.0), (4.0, 3.8, 3.6), 'roca', 12, hb)
        m.roca((10.4 * s, 0.4, 31.0), (2.9, 2.9, 3.2), 'roca2', 10, hb)
        m.roca((10.8 * s, 1.0, 26.2), (2.7, 2.7, 2.2), 'roca', 9, hb)
        m.roca((11.4 * s, 1.6, 20.0), (3.9, 3.8, 4.6), 'roca', 11, ha)
        m.roca((13.6 * s, 1.2, 21.0), (1.8, 2.6, 3.4), 'roca2', 8, ha)
        m.roca((11.4 * s, 2.0, 13.4), (3.6, 3.5, 2.6), 'roca2', 10, ha)
        for dx in (-1.6, 0.0, 1.6):
            m.roca((11.4 * s + dx, 4.6, 12.0), (1.3, 1.3, 1.6), 'roca', 8, ha)
        m.roca((11.4 * s - 2.6 * s, 3.4, 13.8), (1.2, 1.4, 1.2), 'roca', 8, ha)
    L = m.e.L
    if p['desmorona'] > 0.0:
        L = _desmorona(L, m.centros, p['desmorona'])
    return L


def _hash(c):
    h = math.sin(c[0] * 12.9898 + c[1] * 78.233 + c[2] * 37.719) * 43758.5453
    return h - math.floor(h)


def _desmorona(L, centros, k):
    """Cada pieza cae de donde esta (ya posada) a su sitio del MONTON; las de arriba, encima y las ultimas en caer.
    Tienen que quedar COMPACTAS (solapadas): repartidas por el suelo no se lee como un cadaver sino como un fallo."""
    zmax = 44.0
    out = Piezas()
    out.sombras = getattr(L, 'sombras', [])
    for (fn, mat, g, kk, Xh, nh), (c, r) in zip(L, centros):
        cw = aplica(Xh, c)
        alto = min(max(c[2] / zmax, 0.0), 1.0)
        a = _hash(c) * 2 * math.pi; rad = (0.35 + 0.65 * _hash(c + 1.7)) * 10.5 * (1.1 - 0.6 * alto)
        fin = V((math.cos(a) * rad, 3.0 + math.sin(a) * rad * 0.7, r * 0.95 + alto * 5.0))
        espera = 0.30 * (1.0 - alto) + 0.06 * _hash(c + 3.1)
        u = min(max((k - espera) / max(1.0 - espera, 1e-6), 0.0), 1.0)
        f = u * u
        giro = rz((_hash(c + 5.3) - 0.5) * 1.6 * u) @ rx((_hash(c + 7.9) - 0.5) * 1.2 * u)
        mover = V(fin) - cw
        extra = (giro, cw - giro @ cw + mover * f)
        # Cada pieza con SU nombre de hueso: evalua cachea la transformacion por nombre, y con el del hueso compartido
        # todas las rocas del torso caian con la transformacion de la primera (salia una columna, no un monton).
        out.append((fn, mat, g, kk, comp(extra, Xh), '%s#%d' % (nh, len(out))))
    return out


MODELO = None
def _modelo():
    L = escena(POSE())
    grupos = tuple(dict.fromkeys(x[2] for x in L))
    return Modelo(4.0, (224, 238), (112, 161), MAT, BORDE, suaves=grupos, brillan=('ojo',), salto_grupos=0.5,
                  corta_suelo=True)
MODELO = _modelo()


# ------------------------------------------------------------
#  ANIMACIONES: nombre -> (fotogramas, fps, loop, direcciones, t -> pose). Las claves de tiempo, las del viejo.
# ------------------------------------------------------------
def anim_idle(t):
    # Agilidad 8, la mas baja del juego: apenas se mece, y los brazos van un pelin a destiempo.
    r = math.sin(2 * math.pi * t)
    return POSE(inclina=0.025 * r, agacha=0.25 * (1 - math.cos(2 * math.pi * t)),
                alza_d=0.05 * math.sin(2 * math.pi * t + 0.6), alza_i=0.05 * math.sin(2 * math.pi * t + 0.6),
                cabeza=0.03 * r)


def anim_walk(t):
    # Pasos CORTOS y lentisimos: bascula el peso de un pilar al otro; los brazos en contrafase.
    f = 2 * math.pi * t
    return POSE(pie_d=(2.8 * math.sin(f), 1.6 * max(0.0, math.cos(f))),
                pie_i=(-2.8 * math.sin(f), 1.6 * max(0.0, -math.cos(f))),
                balanceo=math.sin(f), gira=0.05 * math.sin(f), agacha=0.4 * (1 - math.cos(2 * f)) * 0.5 + 0.2,
                inclina=0.04, alza_d=-0.30 * math.sin(f), alza_i=0.30 * math.sin(f), codo_d=0.15, codo_i=0.15)


# EL PISOTON (embestida y sismico): levanta un pie del tamaño de una lapida, lo AGUANTA arriba (es una mole, no puede
# ser rapida) y lo estampa en 0,66; los brazos se abren para equilibrarse.
PISA = [(0.0, 0.0), (0.26, 1.0), (0.54, 1.0), (0.66, 0.0), (1.0, 0.0)]
PISA_AGACHA = [(0.0, 0.0), (0.26, 0.25), (0.54, 0.30), (0.66, 1.0), (0.80, 0.55), (1.0, 0.15)]
PISA_MECE = [(0.0, 0.0), (0.26, -0.8), (0.54, -0.9), (0.66, 1.2), (0.80, 0.7), (1.0, 0.2)]

def _pisoton(t, avance=0.0):
    k = tramos(t, PISA)
    return POSE(pie_d=(3.4 * k, 8.0 * k), agacha=1.6 * tramos(t, PISA_AGACHA), inclina=0.09 * tramos(t, PISA_MECE),
                balanceo=1.6 * k, abre_d=0.35 * k, abre_i=0.35 * k, alza_d=0.25 * k, alza_i=0.25 * k,
                codo_d=0.3 * k, codo_i=0.3 * k, avance=avance, cabeza=0.05 * tramos(t, PISA_MECE))


def anim_embestida(t):
    return _pisoton(t, tramos(t, [(0.0, 0.0), (0.26, -0.5), (0.54, -0.6), (0.66, 5.4), (0.80, 6.0), (1.0, 4.6)]))


def anim_sismico(t):
    return _pisoton(t)


def anim_basico(t):
    # EL MAZAZO: sube el puño derecho por encima de la cabeza, lo aguanta y lo deja caer delante en 0,714.
    # (Con el codo muy doblado arriba el puño acaba DETRAS de la cabeza: arriba casi recto.)
    mazo = tramos(t, [(0.0, 0.0), (0.286, 2.2), (0.43, 2.55), (0.571, 2.45), (0.714, 1.05), (0.857, 0.95),
                      (1.0, 0.40)])
    codo = tramos(t, [(0.0, 0.5), (0.286, 0.35), (0.571, 0.3), (0.714, 0.0), (0.857, 0.1), (1.0, 0.35)])
    mece = tramos(t, [(0.0, 0.0), (0.43, -0.9), (0.571, -0.8), (0.714, 2.0), (0.857, 1.5), (1.0, 0.4)])
    return POSE(alza_d=mazo, codo_d=codo, inclina=0.08 * mece, gira=0.05 * mece,
                agacha=2.0 * tramos(t, [(0.0, 0.0), (0.43, 0.05), (0.714, 0.85), (0.857, 0.60), (1.0, 0.15)]),
                avance=tramos(t, [(0.0, 0.0), (0.43, -0.4), (0.714, 2.2), (0.857, 2.4), (1.0, 1.0)]),
                cabeza=0.06 * mece, alza_i=0.1)


def anim_muralla(t):
    # LA MURALLA: se planta, flexiona, cruza los antebrazos DELANTE del pecho y agacha la cabeza: un muro.
    ag = tramos(t, [(0.0, 0.0), (0.143, 0.10), (0.286, 0.30), (0.429, 0.42), (0.571, 0.48), (0.714, 0.50),
                    (0.857, 0.48), (1.0, 0.45)])
    br = tramos(t, [(0.0, 0.0), (0.143, 0.10), (0.286, 0.28), (0.429, 0.38), (0.571, 0.42), (0.714, 0.42),
                    (0.857, 0.40), (1.0, 0.38)]) / 0.42
    cab = tramos(t, [(0.0, 0.0), (0.143, 0.06), (0.286, 0.18), (0.429, 0.26), (0.571, 0.30), (0.714, 0.30),
                     (0.857, 0.28), (1.0, 0.26)])
    return POSE(agacha=4.0 * ag, alza_d=0.55 * br, alza_i=0.55 * br, codo_d=2.3 * br, codo_i=2.3 * br,
                abre_d=-0.22 * br, abre_i=-0.22 * br, cabeza=0.9 * cab, inclina=0.08 * br)


def anim_encaje(t):
    # Encaja MENOS que nadie: se hunde sobre las piernas, cabecea y ya.
    retro = tramos(t, [(0.0, 1.0), (0.34, 0.38), (0.67, 0.10), (1.0, 0.0)])
    return POSE(avance=-1.0 * retro, agacha=1.4 * tramos(t, [(0.0, 0.80), (0.34, 0.24), (0.67, 0.06), (1.0, 0.0)]),
                inclina=-0.08 * retro, cabeza=-0.15 * retro, alza_d=-0.15 * retro, alza_i=-0.15 * retro)


def anim_muerte(t):
    # Le revienta una rodilla, luego la otra, se vence hacia delante con la cabeza gacha, se le apagan los ojos y SE
    # DESHACE EN ESCOMBROS (desde 0,62). El cadaver es el monton.
    r1 = tramos(t, [(0.0, 0.0), (0.08, 0.10), (0.20, 0.60), (0.34, 1.0), (1.0, 1.0)])
    r2 = tramos(t, [(0.0, 0.0), (0.34, 0.05), (0.48, 0.45), (0.64, 1.0), (1.0, 1.0)])
    cab = tramos(t, [(0.0, 0.0), (0.20, 0.15), (0.34, 0.4), (0.64, 0.9), (1.0, 1.0)])
    br = tramos(t, [(0.0, 0.0), (0.20, 0.3), (0.64, 0.8), (1.0, 0.9)])
    return POSE(rodilla_d=r1, rodilla_i=r2, agacha=4.8 * r1 + 4.8 * r2,
                inclina=tramos(t, [(0.0, -0.05), (0.08, -0.08), (0.20, 0.08), (0.34, 0.14), (0.64, 0.3), (1.0, 0.3)]),
                balanceo=2.0 * (r1 - r2), cabeza=0.5 * cab, alza_d=0.35 * br, alza_i=0.35 * br,
                codo_d=0.2 * br, codo_i=0.2 * br, apaga=1.0 if t >= 0.5 else 0.0,
                desmorona=tramos(t, [(0.0, 0.0), (0.62, 0.0), (0.74, 0.22), (0.86, 0.68), (0.94, 0.94), (1.0, 1.0)]))


ANIMS = {
    'idle': (8, 2.0, True, 8, anim_idle),
    'walk': (8, 4.0, True, 8, anim_walk),
    'embestida': (8, 9.0, False, 8, anim_embestida),
    'basico': (8, 9.0, False, 8, anim_basico),
    'sismico': (8, 9.0, False, 8, anim_sismico),
    'muralla': (8, 8.0, False, 8, anim_muralla),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 9.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'coloso_6a6a80_4.00', VISTAS + 'coloso_vs_viejo.png', 2))
    else:
        hornear('coloso_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
