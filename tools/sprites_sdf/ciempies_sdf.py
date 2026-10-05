# ============================================================
#  ciempies_sdf.py -- el CIEMPIES CARMESI en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (ciempies_sprites.gd): NO TIENE CUERPO, TIENE UNA CADENA -- una fila de anillos que SERPENTEA, y todo (las placas del
#  lomo, las patas, la cabeza) cuelga de donde caiga su anillo. Las patas AMARILLAS sobre el cuerpo rojo oscuro (lo que
#  tiene que leerse a la primera es que tiene muchas patas), antenas largas, las forcipulas delante y dos colas detras.
#  Lienzo y origen de su horneado (2,05 -> 104 x 104, el centro).
#  CADA ANILLO ES UN HUESO, orientado segun la cadena (su 'y' por donde va la cadena): asi la misma pieza vale para la
#  culebra, la ESPIRAL de la muerte y la HELICE con la que abraza a su presa en el mapa.
#  LA TRAZA (donde cae cada anillo) es la del viejo: recta con una onda que viaja de la cabeza a la cola, que 'enrosca'
#  lleva a la espiral y 'cinto' a la helice. El ENROSCADO va en DOS MITADES ('mitad' 1 = los anillos de detras de la
#  presa, 2 = los de delante): el combate las pone en dos sprites, uno por detras de ella y otro encima.
#  Uso: python tools/sprites_sdf/ciempies_sdf.py [anim ...]  -> assets/sprites/enemigos/ciempies_sdf/<anim>.png
#       python tools/sprites_sdf/ciempies_sdf.py vistas     -> tools/salida/sdf/ciempies_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/ciempies_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Carmesi (aa251c): el cuerpo y las placas; las patas y antenas amarillas.
MAT = {
    'cuerpo': [(0.40, 0.09, 0.07), (0.62, 0.15, 0.11), (0.80, 0.28, 0.20)],
    'placa':  [(0.30, 0.06, 0.05), (0.48, 0.10, 0.08), (0.66, 0.20, 0.15)],
    'pata':   [(0.78, 0.50, 0.10), (0.96, 0.70, 0.18), (1.0, 0.85, 0.40)],
    'garra':  [(0.12, 0.05, 0.04), (0.18, 0.08, 0.06), (0.26, 0.12, 0.09)],
    'ojo':    [(1.0, 0.90, 0.55)] * 3,
}
MODELO = Modelo(2.3, (104, 104), (52, 52), MAT, (0.12, 0.03, 0.02), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True)

N_ANILLOS = 13
PASO = 1.75
Z_CUERPO = 1.5
# Las medidas del viejo (en sus unidades, a su escala 2,05) pasadas a este dibujo (2,3): mismo tamaño EN PANTALLA.
K_VIEJO = 2.05 / 2.3
AMPLITUD = 1.6
DESFASE_ONDA = 0.16
ALZA_ANILLOS = 4
ALZA_ALTO = 5.5 * K_VIEJO
ESPIRAL_R = 9.5          # mas abierta que la del viejo (7,6): mas cerrada, los anillos se pisaban en un disco
ESPIRAL_PASO_ANG = 0.48 * 14 / (N_ANILLOS - 1)     # el viejo tenia 15 anillos: la misma vuelta con 13
ESPIRAL_ANG0 = 0.5
HELICE_R = 4.6 * K_VIEJO
HELICE_ALTO = 16.0 * K_VIEJO
HELICE_PASO = 0.5 * 14 / (N_ANILLOS - 1)
HELICE_A0 = math.pi * 0.2
LUNGE_DIST = 8.5
ENCAJE_RETRO = 0.50


def POSE(**k):
    # 'onda': cuanto serpentea; 'fase': por donde va la onda; 'paso': cuanto andan las patas; 'alza': levanta la mitad
    # delantera; 'enrosca': hacia la espiral (muerte); 'cinto' + 'sube'/'aprieta'/'gira': la helice del enroscado.
    p = dict(avance=0.0, fase=0.0, onda=0.42, paso=0.0, alza=0.0, enrosca=0.0, cinto=0.0, sube=1.0, aprieta=1.0,
             gira=0.0, mitad=0)
    p.update(k)
    return p


def _traza(i, p):
    """Donde cae el anillo i (0 = la cabeza), y si queda DELANTE de la presa (en el enroscado)."""
    f = i / (N_ANILLOS - 1)
    x = p['onda'] * AMPLITUD * math.sin(2 * math.pi * (p['fase'] + i * DESFASE_ONDA)) * min(1.0, 0.4 + i * 0.12)
    y = (N_ANILLOS - 1) * PASO * 0.5 - i * PASO
    z = Z_CUERPO
    # ALZARSE: solo los primeros anillos, cada vez menos hacia atras; lo que sube deja de avanzar.
    if p['alza'] > 0.0 and i < ALZA_ANILLOS:
        g = 1.0 - i / ALZA_ANILLOS
        sube = p['alza'] * ALZA_ALTO * g * g
        y -= sube * 0.42
        z += sube
    pt = V((x, y, z))
    # MUERTO: la espiral que se cierra hacia dentro (recentrada: la cabeza arranca en el borde de fuera).
    if p['enrosca'] > 0.0:
        a = ESPIRAL_ANG0 + i * ESPIRAL_PASO_ANG
        r = ESPIRAL_R * (1.0 - f * 0.72)
        esp = V((r * math.sin(a), r * math.cos(a) - ESPIRAL_R * 0.35, Z_CUERPO))
        pt = pt * (1 - p['enrosca']) + esp * p['enrosca']
    delante = True
    # ENROSCADO: el anillo va a su sitio de la helice, que sube del suelo al pecho con la cabeza arriba y delante.
    if p['cinto'] > 0.0:
        a = HELICE_A0 - i * HELICE_PASO + p['gira'] * 2 * math.pi
        h = V((math.cos(a) * HELICE_R * p['aprieta'], math.sin(a) * HELICE_R * p['aprieta'],
               Z_CUERPO + HELICE_ALTO * p['sube'] * (1.0 - f)))
        pt = pt * (1 - p['cinto']) + h * p['cinto']
        delante = math.sin(a) > 0.0
    return pt + V((0.0, p['avance'], 0.0)), delante


def _marco(d):
    """Giro que lleva la 'y' local por la cadena ('d'), con la 'x' en horizontal."""
    d = d / np.linalg.norm(d)
    lado = np.cross(d, V((0.0, 0.0, 1.0)))
    if np.linalg.norm(lado) < 1e-4:
        lado = V((1.0, 0.0, 0.0))
    lado = lado / np.linalg.norm(lado)
    arriba = np.cross(lado, d)
    return np.column_stack((lado, d, arriba))


def huesos(p):
    tr = [_traza(i, p) for i in range(N_ANILLOS)]
    pts = [t[0] for t in tr]
    X = {}
    largos = []
    for i in range(N_ANILLOS):
        # La cadena va de la cola a la cabeza: 'y' local hacia delante (hacia el anillo anterior).
        d = pts[max(i - 1, 0)] - pts[min(i + 1, N_ANILLOS - 1)]
        X['a%d' % i] = (_marco(d), pts[i])
        # Lo que hay hasta el vecino: en la helice los anillos se separan, y con el largo fijo quedaban trozos sueltos.
        largos.append(np.linalg.norm(d) * 0.5)
    return X, [t[1] for t in tr], largos


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena(pose):
    X, delante, largos = huesos(pose)
    e = Escena(X); add = e.add
    mitad = pose['mitad']
    # ENROLLADO (espiral o helice): las patas se recogen bajo el cuerpo y el anillo se estrecha. Con las 24 patas
    # abiertas, en curva salian en radial como los rayos de un sol, y no se leia el tubo que se enrolla.
    rizo = max(pose['enrosca'], pose['cinto'])
    rp = 1.0 - 0.7 * rizo
    for i in range(N_ANILLOS):
        # EN DOS MITADES: solo los anillos de este lado de la presa.
        if mitad and (delante[i] != (mitad == 2)):
            continue
        h = 'a%d' % i
        r = 1.9 if i == 0 else (2.15 - 0.6 * max(0, i - 8) / 4.0)
        # EL ANILLO y su PLACA del lomo (mas oscura y un pelo mas ancha): lo que lo hace segmentado.
        ly = max(PASO, largos[i]) / PASO
        ra = r * (1.0 - 0.25 * rizo)
        _elip(add, (0, 0, 0), (ra * 1.15, PASO * 0.62 * ly, r * 0.85), 'cuerpo', 0.6 + 0.6 * rizo, hueso=h)
        _elip(add, (0, 0, r * 0.45), (ra * 1.2, PASO * 0.48 * ly, r * 0.45), 'placa', 0, 'placa%d' % (i % 2), h)
        # UN PAR CADA DOS ANILLOS (05/10, "menos pies, que se entiende mal"): uno por anillo se pegaban en una FALDA
        # AMARILLA que se comia el cuerpo; con hueco entre pata y pata se cuentan una a una (lo mismo que acabo haciendo
        # el viejo).
        if 0 < i < N_ANILLOS - 1 and i % 2 == 1:
            # LAS PATAS: una a cada lado por anillo, amarillas, de lado y abajo hasta el suelo; andan en ola.
            for s in (-1, 1):
                g = 2 * math.pi * (pose['fase'] * 2.0 + i * 0.30) + (0.0 if s > 0 else math.pi)
                fase = math.sin(g) * 1.3 * pose['paso']
                alto = max(0.0, math.cos(g)) * 1.0 * pose['paso']
                rod = V((s * (ra + 1.3 * rp), fase * 0.5, 0.6 * rp + alto * 0.5))
                pie = V((s * (ra + 2.7 * rp), fase, -1.5 + alto))
                _cono(add, V((s * r * 0.8, 0, 0)), rod, 0.78, 0.66, 'pata', 0, 'pata', h)
                _cono(add, rod, pie, 0.66, 0.35, 'pata', 0, 'pata', h)
    # LA CABEZA: las antenas largas hacia delante y afuera, las forcipulas (garras) cerradas delante, y dos ojillos.
    if not mitad or delante[0] == (mitad == 2):
        for s in (-1, 1):
            _cono(add, (0.6 * s, 1.0, 0.6), (2.6 * s, 4.0, 1.8), 0.55, 0.42, 'pata', 0, 'antena', 'a0')
            _cono(add, (2.6 * s, 4.0, 1.8), (4.0 * s, 6.2, 1.2), 0.42, 0.3, 'pata', 0, 'antena', 'a0')
            _cono(add, (0.9 * s, 1.1, -0.3), (1.3 * s, 2.4, -0.3), 0.5, 0.35, 'garra', 0, 'garra', 'a0')
            _cono(add, (1.3 * s, 2.4, -0.3), (0.3 * s, 3.0, -0.3), 0.35, 0.15, 'garra', 0, 'garra', 'a0')
            _elip(add, (0.85 * s, 1.0, 0.75), (0.35, 0.3, 0.3), 'ojo', 0, 'ojo', 'a0')
    # LAS COLAS: dos patas largas detras, como las de verdad.
    n = N_ANILLOS - 1
    if not mitad or delante[n] == (mitad == 2):
        for s in (-1, 1):
            _cono(add, (0, 0, 0), (1.6 * s, -3.6, 0.4), 0.7, 0.35, 'pata', 0, 'cola', 'a%d' % n)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # Nunca deja de ondular del todo: la onda floja y las patas tanteando.
    return POSE(fase=t, onda=0.42, paso=0.20)


def anim_walk(t):
    # A 12 fps, EL MAS RAPIDO DEL JUEGO, con la onda a tope.
    return POSE(fase=t, onda=1.0, paso=1.0)


def anim_embestida(t):
    # LEVANTA LA MITAD DELANTERA, se queda en alto y se deja caer con las forcipulas por delante.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.30, -1.0), (0.50, 0.6), (0.70, 7.4), (0.86, 8.5), (1.0, 6.0)]) * K_VIEJO,
                onda=0.55, alza=tramos(t, [(0.0, 0.0), (0.30, 1.0), (0.50, 0.94), (0.70, 0.12), (1.0, 0.0)]))


def anim_enrosque(t):
    # (Combate, de frente) Se lanza y SE ENROLLA a media espiral (no a 1, que es su muerte); la onda se apaga al apretar.
    onda = tramos(t, [(0.0, 0.55), (0.143, 0.85), (0.286, 0.70), (0.429, 0.40), (0.571, 0.18), (0.714, 0.10),
                      (0.857, 0.16), (1.0, 0.40)])
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.143, -1.4), (0.286, 1.0), (0.429, 5.4), (0.571, 7.6), (0.714, 7.6),
                                  (0.857, 6.8), (1.0, 5.4)]) * K_VIEJO,
                fase=t * 1.3, onda=onda, paso=onda * 0.5,
                alza=tramos(t, [(0.0, 0.0), (0.143, 0.70), (0.286, 0.85), (0.429, 0.40), (0.571, 0.10), (0.714, 0.0),
                                (1.0, 0.0)]),
                enrosca=tramos(t, [(0.0, 0.0), (0.143, 0.0), (0.286, 0.10), (0.429, 0.34), (0.571, 0.56), (0.714, 0.62),
                                   (0.857, 0.60), (1.0, 0.44)]))


def anim_basico(t):
    # Se alza un momento y deja caer la cabeza PICANDO (en la mitad).
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.3, -1.0), (0.5, 3.4), (0.7, 2.8), (1.0, 0.0)]) * K_VIEJO,
                fase=t * 0.3, onda=0.5, paso=0.2,
                alza=tramos(t, [(0.0, 0.0), (0.3, 1.0), (0.5, 0.15), (0.7, 0.1), (1.0, 0.0)]))


def anim_oleada(t):
    # Ya encima, una SACUDIDA por picotazo: la onda se dispara, las patas baten y la mitad delantera empuja.
    return POSE(avance=tramos(t, [(0.0, 1.5), (0.5, 4.2), (1.0, 1.5)]) * K_VIEJO, fase=t * 0.5,
                onda=tramos(t, [(0.0, 0.6), (0.5, 1.7), (1.0, 0.6)]), paso=1.0,
                alza=tramos(t, [(0.0, 0.35), (0.5, 0.0), (1.0, 0.35)]))


def _helice(sube, aprieta, gira, fase, paso, mitad):
    return POSE(onda=0.0, fase=fase, paso=paso, cinto=1.0, sube=sube, aprieta=aprieta, gira=gira, mitad=mitad)


def _enroscado(mitad):
    # Trepa por la presa (la helice crece desde el suelo y se cierra segun sube), la tiene apretando en bucle, aprieta
    # de golpe cada turno, y la suelta.
    return {
        'enroscarse': lambda t: _helice(t, 1.6 + (1.0 - 1.6) * t * t, 0.35 * (1.0 - t), t, 1.0 - t, mitad),
        'enroscado': lambda t: _helice(1.0, 1.0 + 0.05 * math.sin(2 * math.pi * t), 0.02 * math.sin(2 * math.pi * t), t,
                                       0.6, mitad),
        'apreton': lambda t: _helice(1.0, tramos(t, [(0.0, 1.0), (0.3, 0.74), (0.5, 0.7), (0.75, 0.86), (1.0, 1.0)]),
                                     0.0, t * 0.5, 0.3, mitad),
        'desenroscarse': lambda t: _helice(1.0 - t, 1.0 + 0.6 * t * t, -0.35 * t, t, t, mitad),
    }


def anim_muerte(t):
    # SE ENROSCA EN ESPIRAL, con un ULTIMO LATIGAZO (0,66) y un tiron de la cabeza al principio.
    onda = tramos(t, [(0.0, 1.0), (0.18, 0.85), (0.40, 0.45), (0.66, 0.62), (0.84, 0.12), (1.0, 0.0)])
    return POSE(fase=t * 1.6, onda=onda, paso=onda * 0.5,
                alza=tramos(t, [(0.0, 0.0), (0.18, 0.45), (0.40, 0.10), (1.0, 0.0)]),
                enrosca=tramos(t, [(0.0, 0.0), (0.18, 0.16), (0.40, 0.55), (0.66, 0.74), (0.84, 0.96), (1.0, 1.0)]))


def anim_encaje(t):
    # Empieza YA golpeado: sale despedido y SE RETUERCE (la onda se dispara).
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.44), (0.67, 0.12), (1.0, 0.0)]) * LUNGE_DIST * ENCAJE_RETRO * K_VIEJO,
                fase=0.35 * t, onda=tramos(t, [(0.0, 2.1), (0.34, 1.5), (0.67, 1.1), (1.0, 1.0)]), paso=0.3)


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo.
ANIMS = {
    'idle': (8, 4.0, True, 8, anim_idle),
    'walk': (8, 12.0, True, 8, anim_walk),
    'embestida': (8, 12.0, False, 8, anim_embestida),
    'enrosque': (8, 11.0, False, 1, anim_enrosque),
    'basico': (6, 16.0, False, 8, anim_basico),
    'oleada': (6, 18.0, False, 8, anim_oleada),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}
for _m, _suf in ((1, '_detras'), (2, '_delante')):
    _e = _enroscado(_m)
    ANIMS['enroscarse' + _suf] = (6, 12.0, False, 1, _e['enroscarse'])
    ANIMS['enroscado' + _suf] = (8, 8.0, True, 1, _e['enroscado'])
    ANIMS['apreton' + _suf] = (5, 14.0, False, 1, _e['apreton'])
    ANIMS['desenroscarse' + _suf] = (6, 12.0, False, 1, _e['desenroscarse'])


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'ciempies_aa251c_2.05', VISTAS + 'ciempies_vs_viejo.png', 4))
    else:
        hornear('ciempies_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
