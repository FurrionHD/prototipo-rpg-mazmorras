# ============================================================
#  coloso_sdf.py -- el COLOSO en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (coloso_sprites.gd): la MOLE LABRADA, el enemigo mas alto del juego. Granito gris azulado hecho de SILLARES con
#  aristas (lo que lo separa del golem, que es un pegote de barro): piernas que son PILARES con un pie-losa, cadera
#  ancha, torso estrecho para lo alto que es, dos HOMBRERAS cubicas que sobresalen, cabeza PEQUEÑA hundida entre ellas
#  con un VISOR donde brillan los ojos, brazos LARGOS de sillares rematados en un puño-mazo, y las RUNAS frias del pecho
#  (su "Muralla": lo unico encendido, y se apaga al morir).
#  CADA SILLAR EN SU GRUPO: entre grupos sale la linea de dentro, y eso son las JUNTAS (sin ellas es un bulto gris).
#  Lienzo y origen de su horneado (4,00 -> 224 x 238; pies en 112, 161).
#  Uso: python tools/sprites_sdf/coloso_sdf.py [anim ...]  -> assets/sprites/enemigos/coloso_sdf/<anim>.png
#       python tools/sprites_sdf/coloso_sdf.py vistas     -> tools/salida/sdf/coloso_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/coloso_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Granito gris azulado (el 6a6a80 del viejo). Las piernas y los brazos un punto mas oscuros (con el tono del torso
# se funden con el); la JUNTA y el visor casi negros; las RUNAS cian frias (el naranja es del golem, mismo piso).
MAT = {
    'piedra':  [(0.29, 0.29, 0.38), (0.42, 0.42, 0.53), (0.57, 0.58, 0.69)],
    'pierna':  [(0.25, 0.25, 0.33), (0.36, 0.36, 0.46), (0.50, 0.51, 0.62)],
    'brazo':   [(0.26, 0.26, 0.34), (0.38, 0.38, 0.49), (0.53, 0.54, 0.65)],
    'junta':   [(0.14, 0.14, 0.19), (0.19, 0.19, 0.25), (0.24, 0.24, 0.31)],
    'runa':    [(0.62, 0.90, 0.98), (0.62, 0.90, 0.98), (0.80, 0.97, 1.00)],
}
GRUPOS = []
def _g(nombre):
    if nombre not in GRUPOS: GRUPOS.append(nombre)
    return nombre

LADOS = ((-1, 'd'), (1, 'i'))
# Los grupos, fijos (el Modelo los necesita antes de montar la escena).
for _n in ('cadera', 'abdomen', 'pecho', 'cuello', 'cabeza'):
    _g(_n)
for _s, _nom in LADOS:
    for _n in ('pie', 'espinilla', 'espinilla2', 'rodilla', 'muslo', 'hombrera'):
        _g('%s_%s' % (_n, _nom))
    for _i in range(7):
        _g('brazo%d_%s' % (_i, _nom))
    _g('puno_' + _nom)

MODELO = Modelo(4.0, (224, 238), (112, 161), MAT, (0.08, 0.08, 0.11), suaves=tuple(GRUPOS),
                brillan=('runa',), salto_grupos=0.9, corta_suelo=True)

CHAFLAN = 0.55
EJES = np.eye(3)

def HOMBRO(s): return V((8.4 * s, 0.9, 36.4))


def POSE(**k):
    p = dict(agacha=0.0, avance=0.0, inclina=0.0, gira=0.0, cabeza=0.0, alza_d=0.10, alza_i=0.10, codo_d=0.25,
             codo_i=0.25, abre_d=0.06, abre_i=0.06, pie_d=(0.0, 0.0), pie_i=(0.0, 0.0), apaga=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], -p['agacha'])))
    X['raiz'] = raiz
    X['torso'] = comp(raiz, sobre(V((0.0, 0.0, 24.6)), rz(p['gira']) @ rx(p['inclina'])))
    X['cabeza'] = comp(X['torso'], sobre(V((0.0, 0.7, 39.0)), rx(p['cabeza'])))
    for s, nom in LADOS:
        X['brazo_' + nom] = comp(X['torso'], sobre(HOMBRO(s), ry(-p['abre_' + nom] * s) @ rx(-p['alza_' + nom])))
    for s, nom in LADOS:
        X['pierna_' + nom] = (np.eye(3), V((0.0, p['pie_' + nom][0], p['pie_' + nom][1])))
    return X


def _sillar(add, c, medio, mat, grupo, hueso, ejes=EJES, chaflan=CHAFLAN):
    add(lambda P, c=V(c, dtype=float), m=V(medio, dtype=float), ej=ejes: sd_caja(P, c, ej, m, chaflan), mat, 0,
        grupo, hueso)


def _brazo(add, p, s, nom):
    """Cadena de sillares por PASOS fijos desde el hombro (el paso SOBRA contra el grosor: tangentes se descosen), con
    TODO el pliegue en el codo (el 4o)."""
    hb = 'brazo_' + nom
    pos = HOMBRO(s) + V((0.6 * s, 0.0, -2.4))
    d = V((0.08 * s, 0.05, -1.0)); d /= np.linalg.norm(d)
    paso = 2.9
    for i in range(7):
        if i == 4:
            # El codo dobla el antebrazo hacia DELANTE (rx negativo lleva lo de abajo a +Y).
            d = rx(-p['codo_' + nom]) @ d
        r = 2.5 - 0.06 * i
        # Cada sillar orientado con el brazo: su eje largo a lo largo de 'd'.
        z = d; x = np.cross(V((0.0, 1.0, 0.0)), z); x /= np.linalg.norm(x); y = np.cross(z, x)
        _sillar(add, pos, (r, r * 0.92, 1.75), 'brazo', _g('brazo%d_%s' % (i, nom)), hb, ejes=V((x, y, z)))
        pos = pos + d * paso
    # EL PUÑO-MAZO: un bloque grande al final de la cadena, con los nudillos marcados.
    z = d; x = np.cross(V((0.0, 1.0, 0.0)), z); x /= np.linalg.norm(x); y = np.cross(z, x)
    c = pos + d * 0.6
    _sillar(add, c, (3.0, 3.0, 2.9), 'brazo', _g('puno_' + nom), hb, ejes=V((x, y, z)), chaflan=0.9)
    # Una runa en el dorso del puño.
    add(lambda P, c=c + y * 2.95, ej=V((x, y, z)): sd_caja(P, c, ej, V((0.45, 0.3, 1.6)), 0.15), 'runa', 0,
        'runa_puno_' + nom, hb)


def escena(pose):
    p = pose
    X = huesos(p)
    e = Escena(X); add = e.add
    runa = 'junta' if p['apaga'] > 0.5 else 'runa'
    # --- LAS PIERNAS: pilares de sillares sobre un PIE-LOSA ("un pie del tamaño de una lapida").
    for s, nom in LADOS:
        h = 'pierna_' + nom; x = 3.8 * s
        _sillar(add, (x, 0.9, 1.6), (3.1, 3.9, 1.6), 'pierna', 'pie_' + nom, h)
        _sillar(add, (x, 0.0, 5.4), (2.4, 2.4, 2.4), 'pierna', 'espinilla_' + nom, h)
        _sillar(add, (x, 0.0, 10.2), (2.5, 2.5, 2.5), 'pierna', 'espinilla2_' + nom, h)
        _sillar(add, (x, 0.5, 14.4), (2.8, 2.8, 1.9), 'pierna', 'rodilla_' + nom, h, chaflan=0.8)
        _sillar(add, (x, 0.0, 19.2), (3.0, 2.9, 3.4), 'pierna', 'muslo_' + nom, h)
    # --- LA CADERA y el TORSO: abdomen estrecho y el PECHO ancho encima (la proporcion de torre).
    _sillar(add, (0.0, 0.0, 24.4), (6.2, 4.2, 2.6), 'piedra', 'cadera', 'torso')
    _sillar(add, (0.0, 0.3, 28.6), (4.8, 3.8, 2.2), 'piedra', 'abdomen', 'torso')
    _sillar(add, (0.0, 0.5, 34.2), (6.8, 4.6, 4.0), 'piedra', 'pecho', 'torso')
    # LAS RUNAS del pecho: tres trazos frios, grabados en la cara de delante.
    for i, (z, ancho) in enumerate(((36.0, 3.0), (34.2, 2.4), (32.4, 1.8))):
        add(lambda P, z=z, a=ancho: sd_caja(P, V((0.0, 5.05, z)), EJES, V((a, 0.3, 0.38)), 0.12), runa, 0,
            'runa_pecho', 'torso')
    # --- LAS HOMBRERAS: dos sillares cubicos encima de los hombros, que sobresalen por los lados y por arriba.
    for s, nom in LADOS:
        _sillar(add, (8.4 * s, 0.9, 38.4), (3.4, 3.3, 2.8), 'piedra', 'hombrera_' + nom, 'torso', chaflan=0.8)
    # --- LA CABEZA: PEQUEÑA y hundida entre las hombreras, con cuello y un VISOR hundido donde brillan los ojos.
    _sillar(add, (0.0, 0.7, 39.4), (2.0, 2.0, 2.2), 'piedra', 'cuello', 'cabeza')
    _sillar(add, (0.0, 1.0, 43.2), (2.8, 2.6, 2.8), 'piedra', 'cabeza', 'cabeza', chaflan=0.7)
    _sillar(add, (0.0, 3.3, 43.5), (2.3, 0.5, 0.8), 'junta', 'visor', 'cabeza', chaflan=0.15)
    for s in (-1, 1):
        add(lambda P, s=s: sd_caja(P, V((1.1 * s, 3.5, 43.5)), EJES, V((0.65, 0.4, 0.42)), 0.12), runa, 0, 'ojo',
            'cabeza')
    # --- LOS BRAZOS.
    for s, nom in LADOS:
        _brazo(add, p, s, nom)
    return e.L


def anim_idle(t):
    r = math.sin(2 * math.pi * t)
    return POSE(agacha=0.2 * (1 - math.cos(2 * math.pi * t)), alza_d=0.10 + 0.03 * r, alza_i=0.10 + 0.03 * r)


ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'coloso_6a6a80_4.00', VISTAS + 'coloso_vs_viejo.png', 2))
    else:
        hornear('coloso_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
