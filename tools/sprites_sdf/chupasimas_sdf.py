# ============================================================
#  chupasimas_sdf.py -- el CHUPASIMAS en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (chupasimas_sprites.gd): UNA SANGUIJUELA -- un tubo blando y ANILLADO, sin una pata, gordo en el TERCIO TRASERO y
#  afilandose hacia una BOCA REDONDA (una ventosa con el anillo de dientes hacia dentro), y otra ventosa en la cola. Va
#  MOJADA (el brillo del motor). Lienzo y origen de su horneado (1,60 -> 104 x 104, el centro).
#  LA TRAZA es la del viejo: la COLA se queda clavada y la boca se adelanta; 'arco' hace el PUENTE de oruga (y acorta),
#  'alza' levanta la mitad delantera, 'serpea' la desmadeja de lado (encaje, muerte), 'aplasta' la hunde contra el
#  suelo como un trapo; 'boca' abre la ventosa y 'hincha' la llena (el drenaje).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/chupasimas_sdf.py [anim ...]  -> assets/sprites/enemigos/chupasimas_sdf/<anim>.png
#       python tools/sprites_sdf/chupasimas_sdf.py vistas     -> tools/salida/sdf/chupasimas_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/chupasimas_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Granate (804055), con su brillo de mojado; la ventosa por dentro, oscura; los dientes, claros.
MAT = {
    'piel':   [(0.32, 0.15, 0.20), (0.50, 0.25, 0.33), (0.64, 0.38, 0.45), (0.92, 0.78, 0.82)],
    'anillo': [(0.24, 0.11, 0.15), (0.38, 0.18, 0.24), (0.48, 0.26, 0.32)],
    'boca':   [(0.12, 0.04, 0.06)] * 3,
    'diente': [(0.86, 0.82, 0.70), (0.94, 0.92, 0.82), (0.99, 0.97, 0.90)],
}
# Algo mayor que su escala (1,6), como los demas de su piso: el viejo exageraba el tamaño.
MODELO = Modelo(2.0, (104, 104), (52, 52), MAT, (0.12, 0.05, 0.07), suaves=('cuerpo',), brillan=(), corta_suelo=True,
                especular=('piel',), umbral_especular=0.9)

LARGO = 26.0
N = 16
# Las medidas del viejo pasadas a este dibujo (mismo tamaño en pantalla, mas o menos).
K_VIEJO = 0.8
ARCO_ALTO = 6.2 * K_VIEJO
ARCO_ENCOGE = 0.30
ALZA_DESDE = 0.6            # la mitad delantera (los 5 anillos de delante de los 13 del viejo)
ALZA_ALTO = 6.0 * K_VIEJO
LAXO_SERPEA = 3.4 * K_VIEJO
HINCHA_MAX = 0.55
LUNGE_DIST = 7.0
ENCAJE_RETRO = 0.52


def POSE(**k):
    p = dict(arco=0.0, alza=0.0, avance=0.0, onda=0.0, serpea=0.0, aplasta=0.0, boca=0.0, hincha=0.0)
    p.update(k)
    return p


def huesos(p):
    return {'raiz': (np.eye(3), np.zeros(3))}


def _radio(u, p=None):
    """El grosor a lo largo (u = 0 la cola, 1 la boca): gordo en el tercio trasero, afilando hacia la boca. HINCHADA
    (el drenaje), lo gordo engorda mas."""
    panza = math.exp(-((u - 0.40) / 0.36) ** 2)
    h = p['hincha'] if p else 0.0
    return (1.1 + 1.7 * panza) * (1.0 + HINCHA_MAX * h * panza)


def _traza(u, p):
    # LA COLA SE QUEDA CLAVADA Y LA BOCA SE ADELANTA: se mide desde la cola, que es la ventosa que ancla.
    largo = LARGO * (1.0 - ARCO_ENCOGE * p['arco'])
    y = -0.5 * LARGO + u * largo
    # EL PUENTE: una campana algo picuda (una sanguijuela hace un pico, no un arcoiris).
    z = _radio(u, p) * (1.0 - 0.6 * p['aplasta']) + 0.15 + ARCO_ALTO * p['arco'] * math.sin(math.pi * u) ** 1.4
    # ALZARSE: solo la mitad delantera, con la cola en el suelo; lo que sube deja de avanzar.
    if p['alza'] > 0.0 and u > ALZA_DESDE:
        g = (u - ALZA_DESDE) / (1.0 - ALZA_DESDE)
        sube = p['alza'] * ALZA_ALTO * g * g
        z += sube
        y -= sube * 0.40
    # DESMADEJARSE de lado: crece hacia la cola, que es lo que mas latiguea.
    f = 1.0 - u
    x = math.sin(u * 4.0 + p['onda']) * 0.9 + p['serpea'] * LAXO_SERPEA * math.sin(math.pi * f * 1.6) * f
    return V((x, y + p['avance'], z))


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena(pose):
    e = Escena(huesos(pose)); add = e.add
    us = [i / (N - 1) for i in range(N)]
    pts = [_traza(u, pose) for u in us]
    for i in range(N - 1):
        _cono(add, pts[i], pts[i + 1], _radio(us[i], pose), _radio(us[i + 1], pose), 'piel', 0.8)
    # LA ANILLACION: aros finos y oscuros todo alrededor, muy juntos.
    for k in range(2, 17):
        u = k / 18
        c = _traza(u, pose)
        d = _traza(min(u + 0.01, 1.0), pose) - _traza(max(u - 0.01, 0.0), pose); d /= np.linalg.norm(d)
        r = _radio(u, pose) + 0.12
        def aro(P, c=c, d=d, r=r):
            q = P - c
            a = q @ d
            rad = np.linalg.norm(q - np.outer(a, d), axis=1)
            return np.sqrt((rad - r) ** 2 + a ** 2) - 0.32
        add(aro, 'anillo', 0, 'anillo')
    # LA VENTOSA DE DELANTE: un disco abierto con el anillo de DIENTES hacia dentro; 'boca' la ABRE.
    b = pose['boca']
    boca = pts[-1]; d = pts[-1] - pts[-2]; d /= np.linalg.norm(d)
    cen = boca + d * 0.6
    _elip(add, cen, (1.9 + 0.6 * b,) * 3, 'piel', 0.5)
    _elip(add, cen + d * (1.3 + 0.4 * b), (1.3 + 0.7 * b,) * 3, 'boca', 0, 'boca')
    a1 = np.cross(d, V((0.0, 0.0, 1.0))); a1 /= max(np.linalg.norm(a1), 1e-6); a2 = np.cross(d, a1)
    ab = 1.0 + 0.55 * b
    for k in range(8):
        ang = k / 8 * 2 * math.pi
        rr = a1 * math.cos(ang) + a2 * math.sin(ang)
        _cono(add, cen + d * (1.4 + 0.4 * b) + rr * 1.3 * ab, cen + d * (1.1 + 0.4 * b) + rr * 0.6 * ab, 0.3, 0.12, 'diente',
              0, 'diente')
    # LA VENTOSA DE LA COLA: mas pequeña, un disco que se agarra.
    cola = pts[0]; dc = pts[0] - pts[1]; dc /= np.linalg.norm(dc)
    _elip(add, cola + dc * 0.6 + V((0, 0, -0.6)), (2.2, 2.2, 0.8), 'piel', 0.6)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # Apenas respira: se encoge un pelin sin llegar al puente, y la boca se abre despacio.
    return POSE(arco=0.10 * (1 - math.cos(2 * math.pi * t)), boca=0.18 * (1 - math.cos(2 * math.pi * t + 1.2)))


def anim_walk(t):
    # EL BUCLE DE ORUGA: se arquea y se acorta (junta los extremos) y se estira hacia delante.
    return POSE(arco=0.5 - 0.5 * math.cos(2 * math.pi * t))


def anim_embestida(t):
    # Se alza buscando donde clavarse, ABRE LA BOCA (antes del avance: lo que llega es la ventosa) y se echa encima.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.32, -1.1), (0.50, 0.6), (0.72, 6.6), (0.86, 7.0), (1.0, 4.8)]) * K_VIEJO,
                alza=tramos(t, [(0.0, 0.0), (0.32, 1.0), (0.50, 0.92), (0.72, 0.16), (1.0, 0.0)]),
                arco=tramos(t, [(0.0, 0.0), (0.32, 0.55), (0.50, 0.40), (0.72, 0.0), (1.0, 0.10)]),
                boca=tramos(t, [(0.0, 0.0), (0.32, 0.85), (0.50, 1.0), (0.72, 0.45), (1.0, 0.10)]))


def anim_adherirse(t):
    # UN AGARRE: se alza, planta la ventosa y SE QUEDA, encogida y tirando.
    return POSE(boca=tramos(t, [(0.0, 0.0), (0.143, 0.75), (0.286, 1.0), (0.429, 0.55), (0.571, 0.30), (0.714, 0.22),
                                (1.0, 0.20)]),
                alza=tramos(t, [(0.0, 0.0), (0.143, 0.85), (0.286, 1.0), (0.429, 0.62), (0.571, 0.45), (1.0, 0.40)]),
                arco=tramos(t, [(0.0, 0.0), (0.143, 0.30), (0.286, 0.15), (0.429, 0.62), (0.571, 0.78), (0.714, 0.70),
                                (1.0, 0.74)]))


def anim_adherido(t):
    # PEGADA encima de su presa (en bucle): la pose del final del agarre con un bombeo lento.
    return POSE(boca=0.2, alza=0.4, arco=0.74 + 0.06 * math.sin(2 * math.pi * t),
                hincha=0.12 + 0.1 * (0.5 - 0.5 * math.cos(2 * math.pi * t)))


def anim_drenaje(t):
    # BOMBEA: se llena A TIRONES, en escalones, y cada tiron aprieta el arco.
    return POSE(hincha=tramos(t, [(0.0, 0.0), (0.143, 0.28), (0.286, 0.22), (0.429, 0.52), (0.571, 0.46), (0.714, 0.78),
                                  (0.857, 0.72), (1.0, 1.0)]),
                arco=tramos(t, [(0.0, 0.55), (0.143, 0.72), (0.286, 0.58), (0.429, 0.76), (0.571, 0.60), (0.714, 0.80),
                                (0.857, 0.62), (1.0, 0.82)]),
                alza=0.40, boca=0.20)


def anim_encaje(t):
    # Empieza YA golpeada: SE SACUDE COMO UN TRAPO, se desmadeja de lado y vuelve.
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.40), (0.67, 0.10), (1.0, 0.0)]) * LUNGE_DIST * ENCAJE_RETRO * K_VIEJO,
                serpea=tramos(t, [(0.0, 1.0), (0.34, -0.55), (0.67, 0.20), (1.0, 0.0)]),
                arco=tramos(t, [(0.0, 0.42), (0.34, 0.14), (0.67, 0.04), (1.0, 0.0)]))


def anim_muerte(t):
    # SE QUEDA LAXA: un ultimo espasmo (se arquea de golpe) y se aplasta y desmadeja, con la boca floja abierta.
    return POSE(arco=tramos(t, [(0.0, 0.0), (0.16, 0.85), (0.34, 0.45), (0.56, 0.12), (1.0, 0.0)]),
                serpea=tramos(t, [(0.0, 0.0), (0.16, -0.35), (0.34, 0.55), (0.56, 0.85), (0.78, 1.0), (1.0, 1.0)]),
                aplasta=tramos(t, [(0.0, 0.0), (0.16, 0.0), (0.34, 0.35), (0.56, 0.72), (0.78, 0.94), (1.0, 1.0)]),
                boca=tramos(t, [(0.0, 0.20), (0.16, 0.90), (0.34, 0.70), (1.0, 0.55)]))


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo.
ANIMS = {
    'idle': (8, 4.0, True, 8, anim_idle),
    'walk': (8, 7.0, True, 8, anim_walk),
    'embestida': (8, 10.0, False, 8, anim_embestida),
    'adherirse': (8, 11.0, False, 8, anim_adherirse),
    'adherido': (6, 5.0, True, 8, anim_adherido),
    'drenaje': (8, 11.0, False, 8, anim_drenaje),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'chupasimas_804055_1.60', VISTAS + 'chupasimas_vs_viejo.png', 4))
    else:
        hornear('chupasimas_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
