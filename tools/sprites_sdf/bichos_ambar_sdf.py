# ============================================================
#  bichos_ambar_sdf.py -- LOS BICHOS DEL AMBAR animados (02/11/2026, trent-mutante): los que suelta la costra del Tocon
#  ambarino. Sus cuerpos, los de la lamina aprobada (bichos_ambar_versiones.py); aqui cada pieza a su hueso y SOLO las
#  animaciones que usa cada uno (basico + su UNA habilidad):
#    BICHO=garrapata [HINCHA=0..3]  idle walk embestida adherirse adherido drenaje encaje muerte (como el Chupasimas,
#                                   cuya mecanica de pegarse reutiliza); hinchada (1-3) en vez de 'muerte' REVIENTA
#    BICHO=mosquito                 idle walk embestida picadura encaje muerte (vuela: aletea siempre)
#    BICHO=pelotero                 idle walk embestida bola encaje muerte (la bola: la patea, se queda sin ella y se
#                                   hace otra que va creciendo)
#  Uso: BICHO=garrapata python tools/sprites_sdf/bichos_ambar_sdf.py [anim ...]
#       -> tools/salida/sdf/<bicho>_sdf[_h<n>]/ (SIN hornear al juego) y las vistas a su escritorio
# ============================================================
import sys, os, math, random
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import bichos_ambar_versiones as bv

V = np.array
BICHO = os.environ.get('BICHO', 'garrapata')
HINCHA = int(os.environ.get('HINCHA', '0')) if BICHO == 'garrapata' else 0
LADO = 96
MODELO = Modelo(bv.ESC, (LADO, LADO), (LADO // 2, int(LADO * 0.62)), bv.MAT, (0.08, 0.05, 0.03),
                suaves=('cuerpo', 'bola'), brillan=('ojo',), corta_suelo=True,
                especular=('garrapata', 'escudo', 'hinchada', 'pelotero'), umbral_especular=0.92, translucidos=('ala',),
                alfa=0.45)
_suf = BICHO + ('_h%d' % HINCHA if HINCHA else '')
SALIDA = 'assets/sprites/enemigos/%s_sdf/' % _suf   # (02/11, "estan guapardos": ya van al juego)
VISTAS = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                      'bicho_%s_hojas' % _suf) + os.sep


def POSE(**k):
    p = dict(avance=0.0, bota=0.0, mece=0.0, ladea=0.0, paso=0.0, fase=0.0, aplasta=0.0, hincha=0.0, boca=0.0,
             aleteo=0.0, alto=0.0, pica=0.0, patea=0.0, bola=1.0, bola_y=0.0, revienta=0.0, cae=0.0, tumba=0.0)
    p.update(k)
    return p


class _Esc(Escena):
    def __init__(self, X):
        super().__init__(X)
        self.h = 'cuerpo'

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso=None):
        h = hueso or self.h
        self.L.append((fn, mat, grupo, k, self.X.get(h, IDENT), h))


def _rot_eje(eje, ang):
    k = V(eje, dtype=float); k = k / np.linalg.norm(k)
    K = V(((0, -k[2], k[1]), (k[2], 0, -k[0]), (-k[1], k[0], 0)))
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * K @ K


def _cuerpo(p, pivote=V((0.0, 0.0, 3.0))):
    raiz = (np.eye(3), V((0.0, p['avance'], p['bota'] + p['alto'])))
    M = rx(p['mece'] * 0.12) @ ry(p['ladea'] * 0.15)
    # 'aplasta' (el golpe, la muerte): mas ancho y mas bajo; 'tumba' (el mosquito muerto): panza arriba
    if p['tumba'] > 0.0:
        M = ry(p['tumba'] * math.pi) @ M
    S = np.diag([1.0 + 0.3 * p['aplasta'], 1.0 + 0.15 * p['aplasta'], 1.0 - 0.45 * p['aplasta']])
    return comp(raiz, sobre(pivote, M @ S))


def _patas(X, raiz_cuerpo, p, bases, n_lados, sube=0.5, barre=0.3):
    # Cada pata gira en su base: tripode alterno al andar (la que avanza, levantada).
    for i, (s, j, base) in enumerate(bases):
        grupo = 1.0 if (j + (0 if s > 0 else 1)) % 2 == 0 else -1.0
        f = math.sin(2 * math.pi * p['fase']) * grupo
        lev = max(0.0, math.cos(2 * math.pi * p['fase']) * grupo)
        u = V((s, 0.0, 0.0))
        M = rz(p['paso'] * barre * f) @ _rot_eje(V((0, 1.0, 0)), -s * (p['paso'] * sube * lev + 0.8 * p['revienta']))
        X['pata%d' % i] = comp(raiz_cuerpo, sobre(V(base, dtype=float), M))


# ============================================================
#  GARRAPATA
# ============================================================
def _g_dims(h):
    return 5.0 + 1.3 * h, 6.4 + 1.1 * h, 2.2 + 1.7 * h, 2.6 + 1.6 * h


def _g_bases(h):
    rx_, ry_, rz_, zc = _g_dims(h)
    out = []
    for s in (-1, 1):
        for j, y in enumerate((3.4, 1.4, -0.8, -3.0)):
            out.append((s, j, (rx_ * 0.75 * s, y + 0.3 * h * (1 if y > 0 else -1), 2.0 + 0.5 * h)))
    return out


def huesos_garrapata(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], p['bota'])))
    X['raiz'] = raiz
    X['cuerpo'] = _cuerpo(p)
    X['cabeza'] = comp(X['cuerpo'], sobre(V((0.0, 6.0, 2.4)), rx(-p['boca'] * 0.35)))
    _patas(X, raiz, p, _g_bases(HINCHA), 4)
    return X


def piezas_garrapata(e, p):
    h = HINCHA + p['hincha']        # (el drenaje la hincha un poco mas en la animacion, hasta la siguiente)
    rx_, ry_, rz_, zc = _g_dims(h)
    mat = 'garrapata' if HINCHA == 0 else 'hinchada'
    rev = p['revienta']
    e.h = 'cuerpo'
    if rev < 0.35:
        k = 1.0 + 0.25 * rev / 0.35        # se tensa antes de reventar
        e.add(lambda P, c=V((0, -0.6, zc)), r=V((rx_ * k, ry_ * k, rz_ * k)): sd_elipsoide(P, c, r), mat, 0.8, 'cuerpo')
        e.add(lambda P, c=V((0, 2.6 + 0.5 * h, zc + rz_ * 0.55 * k)): sd_elipsoide(P, c, V((3.2, 2.8, 0.9))), 'escudo',
              0.3, 'cuerpo')
        if HINCHA > 0:
            rnd = random.Random(3)
            for kk in range(5 + 2 * HINCHA):
                a0 = rnd.uniform(0, 2 * math.pi)
                pts = []
                for j in range(4):
                    a = a0 + j * 0.25
                    u = 0.3 + j * 0.18
                    pts.append(V((math.cos(a) * rx_ * u * k, -0.6 + math.sin(a) * ry_ * u * k,
                                  zc + rz_ * k * math.sqrt(max(0.0, 1 - u * u)) + 0.05)))
                for a, b in zip(pts, pts[1:]):
                    bv._cono(e, a, b, 0.22, 0.15, 'vena', 0, 'vena')
    else:
        # REVENTADA: el pellejo roto en jirones caidos alrededor del escudo, que queda en el suelo.
        q = min(1.0, (rev - 0.35) / 0.65)
        e.add(lambda P, c=V((0, 1.5, 1.0)): sd_elipsoide(P, c, V((3.2, 2.8, 0.9))), 'escudo', 0.3, 'cuerpo')
        for j in range(7):
            a = j / 7 * 2 * math.pi
            c = V((math.cos(a) * (3.0 + 2.5 * q) * (rx_ / 6.0), -0.6 + math.sin(a) * (3.0 + 2.5 * q) * (ry_ / 7.0),
                   0.6))
            e.add(lambda P, c=c: sd_elipsoide(P, c, V((1.8, 1.5, 0.5))), mat, 0.4, 'jiron')
    e.h = 'cabeza'
    e.add(lambda P, c=V((0, ry_ - 0.2, 2.4 + 0.4 * h if rev < 0.35 else 1.0)): sd_elipsoide(P, c, V((1.5, 1.7, 1.0))),
          'escudo', 0.4, 'cabeza')
    for s in (-1, 1):
        a = V((0.6 * s, ry_ + 1.0, 2.3 + 0.4 * h))
        bv._cono(e, a, a + V((0.3 * s + 0.6 * s * p['boca'], 2.0, -0.7)), 0.45, 0.12, 'escudo', 0, 'pinza')
    for i, (s, j, base) in enumerate(_g_bases(HINCHA)):
        e.h = 'pata%d' % i
        base = V(base)
        fuera = V((s * (3.5 + 0.4 * HINCHA), 1.2 if j < 2 else -1.2, 0.0))
        codo = base + fuera + V((0, 0, 1.6))
        punta = codo + V((s * 2.0, 1.6 if j < 2 else -1.6, -codo[2] + 0.2))
        bv._pata(e, base, codo, punta, 0.45)
    e.h = 'cuerpo'


# ============================================================
#  MOSQUITO
# ============================================================
M_Z = 15.0


def huesos_mosquito(p):
    X = {}
    alto = p['alto'] - p['cae']
    raiz = (np.eye(3), V((0.0, p['avance'], p['bota'] + alto)))
    X['raiz'] = raiz
    M = rx(p['mece'] * 0.15 + p['pica'] * 0.6) @ ry(p['ladea'] * 0.2)   # (+: el morro ABAJO; con - lo alzaba y se le veia la tripa)
    if p['tumba'] > 0.0:
        M = ry(p['tumba'] * math.pi * 0.9) @ M
    X['cuerpo'] = comp(raiz, sobre(V((0.0, 0.5, M_Z)), M))
    for s in (-1, 1):
        # LAS ALAS: aletean arriba y abajo alrededor de su raiz (rapido: un aleteo por fotograma, con desfase)
        a = 0.55 * math.sin(p['aleteo']) * (1.0 - p['tumba'])
        X['ala%d' % s] = comp(X['cuerpo'], sobre(V((1.4 * s, -0.6, M_Z + 1.4)), _rot_eje(V((0, 1.0, 0)), -s * a)))
    # las patas cuelgan del cuerpo y se mecen con retraso
    for i in range(6):
        s = -1 if i < 3 else 1
        X['pata%d' % i] = comp(X['cuerpo'], sobre(V((1.2 * s, 1.6 - 1.2 * (i % 3), M_Z - 1.5)),
                                                  rx(0.25 * math.sin(2 * math.pi * p['fase'] + i) * p['paso']
                                                     - 0.3 * p['pica'])))
    return X


def piezas_mosquito(e, p):
    z = M_Z
    e.h = 'raiz'
    e.sombra(0.0, p['avance'], 6.0, 4.0, 0.26 * max(0.2, 1.0 - (p['alto'] - p['cae'] + 15.0) / 40.0))
    e.h = 'cuerpo'
    bv._elip(e, (0, 0.5, z), (2.2, 2.6, 2.2), 'mosquito', 0.6)
    bv._elip(e, (0, 3.6, z + 0.2), (1.4, 1.4, 1.4), 'mosquito', 0.4)
    for s in (-1, 1):
        bv._elip(e, (0.9 * s, 4.3, z + 0.6), (0.7, 0.7, 0.8), 'ojo', 0, 'ojo')
        bv._cono(e, (0.5 * s, 4.4, z + 1.2), (1.6 * s, 6.5, z + 3.6), 0.18, 0.05, 'raya', 0, 'antena')
    bv._cono(e, (0, 4.6, z - 0.4), (0, 10.5, z - 4.5), 0.32, 0.05, 'raya', 0, 'trompa')
    for j in range(6):
        u = j / 5
        c = V((0, -2.0 - 8.5 * u, z - 0.6 - 2.6 * u))
        r = 1.9 - 1.1 * u
        bv._elip(e, c, (r, r * 1.05, r), 'mosquito' if j % 2 == 0 else 'raya', 0.5)
    for s in (-1, 1):
        e.h = 'ala%d' % s
        R = rz(s * 0.35) @ ry(-s * 0.35)
        c = V((3.8 * s, -2.8, z + 2.0))
        bv._elip_girada(e, c, (2.0, 6.5, 0.12), R, 'ala', 0, 'ala')
        for k in (-0.8, 0.0, 0.8):
            a = c + R @ V((k, 5.5, 0.15))
            b = c + R @ V((k * 0.5, -5.5, 0.15))
            bv._cono(e, a, b, 0.1, 0.1, 'vena_ala', 0, 'vena_ala')
    for i in range(6):
        e.h = 'pata%d' % i
        s = -1 if i < 3 else 1
        j = i % 3
        y = (1.6, 0.4, -0.8)[j]
        base = V((1.2 * s, y, z - 1.5))
        codo = base + V((s * 5.5, (1 - j) * 3.0, 2.5))
        punta = V((s * (8.0 + j), y + (1 - j) * 6.0, 1.5))
        bv._pata(e, base, codo, punta, 0.28, 'raya')
    e.h = 'cuerpo'


# ============================================================
#  PELOTERO
# ============================================================
P_BASES = []
for _s in (-1, 1):
    P_BASES += [(_s, 0, (2.2 * _s, 6.6, 2.2)), (_s, 1, (2.8 * _s, 3.0, 2.4)), (_s, 2, (2.4 * _s, -0.8, 2.8))]
P_BOLA = V((0.0, -9.0, 6.4))


def huesos_pelotero(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], p['bota'])))
    X['raiz'] = raiz
    X['cuerpo'] = _cuerpo(p, V((0.0, 2.0, 2.0)))
    _patas(X, raiz, p, P_BASES, 3, 0.4, 0.25)
    # las de atras empujan la bola / la patean ('patea': se estiran de golpe hacia atras)
    for i, (s, j, base) in enumerate(P_BASES):
        if j == 2:
            X['pata%d' % i] = comp(X['pata%d' % i], sobre(V(base, dtype=float), rx(0.7 * p['patea'])))
    # LA BOLA: rueda con el paso (gira en x) y sale despedida al patearla ('bola_y' la aleja)
    gira = -p['fase'] * 2 * math.pi * 0.5 * p['paso']
    X['bola'] = comp(raiz, sobre(P_BOLA, rx(gira)))
    X['bola'] = (X['bola'][0], X['bola'][1] + V((0.0, -p['bola_y'], 0.0)))
    return X


def piezas_pelotero(e, p):
    e.h = 'cuerpo'
    bv._elip(e, (0, 2.0, 3.6), (3.4, 4.0, 2.7), 'pelotero', 0.6)
    bv._cono(e, (0, -1.8, 4.5), (0, 5.8, 4.5), 0.12, 0.12, 'raya', 0, 'sutura')
    bv._elip(e, (0, 6.4, 3.0), (3.0, 2.0, 2.0), 'pelotero', 0.6)
    bv._elip(e, (0, 8.6, 1.9), (2.6, 1.4, 0.8), 'pelotero', 0.3)
    for x in (-1.6, -0.5, 0.5, 1.6):
        bv._cono(e, (x, 9.6, 1.9), (x * 1.1, 10.4, 1.6), 0.35, 0.08, 'pelotero', 0, 'diente')
    piezas = {0: ((4.2, 8.0, 1.8), (4.6, 9.6, 0.2), 0.55), 1: ((5.0, 3.4, 2.6), (5.6, 4.6, 0.2), 0.5),
              2: ((4.6, -3.8, 5.8), (2.4, -6.2, 7.8), 0.5)}
    for i, (s, j, base) in enumerate(P_BASES):
        e.h = 'pata%d' % i
        codo, punta, r = piezas[j]
        bv._pata(e, V(base), V((codo[0] * s, codo[1], codo[2])), V((punta[0] * s, punta[1], punta[2])), r, 'pelotero')
    # LA BOLA (con 'bola' de 0 a 1: su tamaño mientras se hace otra)
    t = p['bola']
    if t > 0.02:
        e.h = 'bola'
        c = P_BOLA + V((0.0, 0.0, -6.3 * (1.0 - t)))
        bv._elip(e, c, (6.2 * t, 6.0 * t, 6.3 * t), 'caca', 1.0, 'bola')
        rnd = random.Random(8)
        for _ in range(7):
            d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.3, 1)))
            d /= np.linalg.norm(d)
            bv._elip(e, c + d * 5.4 * t, (1.6 * t, 1.6 * t, 1.4 * t), 'caca', 1.0, 'bola')
        for _ in range(9):
            d = V((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.2, 1)))
            d /= np.linalg.norm(d)
            q0 = c + d * 5.8 * t
            q1 = q0 + (d + V((rnd.uniform(-0.6, 0.6), rnd.uniform(-0.6, 0.6), 0.2))) * rnd.uniform(1.6, 2.8) * t
            if t > 0.4:
                bv._cono(e, q0, q1, 0.2, 0.12, 'paja', 0, 'paja')
    e.h = 'cuerpo'


# ============================================================
#  ANIMACIONES
# ============================================================
def _vuela(t, k=1.0):
    # el mosquito: aleteo rapido (varios por vuelta) y un flote suave
    return dict(aleteo=2 * math.pi * t * 4.0, bota=0.8 * k * math.sin(2 * math.pi * t))


def anim_idle(t):
    if BICHO == 'mosquito':
        return POSE(**_vuela(t), paso=0.4, fase=t)
    if BICHO == 'pelotero':
        return POSE(mece=0.25 * math.sin(2 * math.pi * t), paso=0.2, fase=t * 0.5)
    return POSE(bota=0.15 * math.sin(2 * math.pi * t), boca=0.2 + 0.2 * math.sin(2 * math.pi * t * 2))


def anim_walk(t):
    if BICHO == 'mosquito':
        return POSE(**_vuela(t), mece=0.8, paso=1.0, fase=t)
    if BICHO == 'pelotero':
        # ANDA CON SU BOLA: la lleva detras, sujeta con las patas de atras, y rueda con el paso.
        return POSE(paso=1.0, fase=t, bota=0.2 * abs(math.sin(2 * math.pi * t)), mece=0.3)
    return POSE(paso=1.0, fase=t, bota=0.2 * abs(math.sin(4 * math.pi * t)))


def anim_embestida(t):
    if BICHO == 'mosquito':
        # el BASICO: se echa atras y da un picotazo corto con la trompa
        return POSE(**_vuela(t), avance=tramos(t, [(0.0, 0.0), (0.35, -1.5), (0.55, 3.0), (1.0, 0.0)]),
                    pica=tramos(t, [(0.0, 0.0), (0.35, -0.2), (0.55, 0.6), (1.0, 0.0)]))
    if BICHO == 'pelotero':
        # CABEZAZO con la pala
        return POSE(avance=tramos(t, [(0.0, 0.0), (0.35, -1.2), (0.55, 3.0), (0.75, 2.6), (1.0, 0.0)]),
                    mece=tramos(t, [(0.0, 0.0), (0.35, -1.5), (0.55, 2.0), (1.0, 0.0)]))
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 3.0), (0.75, 2.6), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.0), (0.35, 1.0), (0.55, 0.2), (1.0, 0.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 1.0), (1.0, 0.0)]))


def anim_adherirse(t):
    # EL SALTO: se encoge y SALTA (sube y avanza), abre las pinzas y cae encima pegandose.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.25, -0.5), (0.6, 6.0), (1.0, 7.0)]),
                bota=tramos(t, [(0.0, 0.0), (0.25, -0.6), (0.45, 6.0), (0.7, 3.0), (0.85, 0.0), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.0), (0.4, 1.0), (0.85, 1.0), (1.0, 0.3)]),
                aplasta=tramos(t, [(0.0, 0.0), (0.25, 0.3), (0.4, -0.2), (0.85, 0.2), (1.0, 0.0)]))


def anim_adherido(t):
    return POSE(boca=0.3, aplasta=0.08 + 0.06 * math.sin(2 * math.pi * t), bota=0.1 * math.sin(2 * math.pi * t))


def anim_drenaje(t):
    # BOMBEA A TIRONES: se va hinchando hacia la siguiente hinchazon (la hoja de la de al lado la remata).
    return POSE(hincha=tramos(t, [(0.0, 0.0), (0.143, 0.15), (0.286, 0.10), (0.429, 0.30), (0.571, 0.25), (0.714, 0.45),
                                  (0.857, 0.40), (1.0, 0.5)]) if HINCHA < 3 else 0.1 * math.sin(2 * math.pi * t * 3),
                boca=0.4, aplasta=tramos(t, [(0.0, 0.0), (0.143, 0.15), (0.286, 0.0), (0.429, 0.15), (0.571, 0.0),
                                             (0.714, 0.15), (1.0, 0.0)]))


def anim_picadura(t):
    # LA PICADURA: sube un poco, se lanza en picado con la trompa por delante y se queda clavado chupando, y se suelta.
    return POSE(**_vuela(t), alto=tramos(t, [(0.0, 0.0), (0.25, 3.0), (0.45, -6.0), (0.8, -6.0), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.25, -1.0), (0.45, 5.0), (0.8, 5.0), (1.0, 1.0)]),
                pica=tramos(t, [(0.0, 0.0), (0.25, -0.3), (0.45, 1.0), (0.8, 0.9), (1.0, 0.0)]),
                mece=0.5 * math.sin(2 * math.pi * t * 3) * (0.45 < t < 0.8))


def anim_bola(t):
    # LA BOLA DE CACA: se planta, PATEA la bola hacia atras con las de atras (sale rodando: el efecto la sigue) y se
    # queda sin ella; escarba y se hace otra que va creciendo.
    return POSE(patea=tramos(t, [(0.0, 0.0), (0.25, -0.5), (0.35, 1.0), (0.5, 0.3), (1.0, 0.0)]),
                bola_y=tramos(t, [(0.0, 0.0), (0.3, 0.0), (0.45, 25.0), (0.59, 25.0), (0.6, 0.0), (1.0, 0.0)]),   # la nueva, a su lado
                bola=tramos(t, [(0.0, 1.0), (0.44, 1.0), (0.45, 0.0), (0.6, 0.0), (1.0, 0.8)]),
                mece=tramos(t, [(0.0, 0.0), (0.25, 1.0), (0.35, 1.6), (0.6, 0.8), (1.0, 0.0)]),
                paso=tramos(t, [(0.0, 0.0), (0.55, 0.0), (0.6, 1.0), (1.0, 1.0)]), fase=t * 3.0)


def anim_encaje(t):
    if BICHO == 'mosquito':
        return POSE(**_vuela(t), avance=tramos(t, [(0.0, -2.0), (0.4, -0.6), (1.0, 0.0)]),
                    ladea=tramos(t, [(0.0, 1.5), (0.34, -0.8), (0.67, 0.3), (1.0, 0.0)]))
    return POSE(aplasta=tramos(t, [(0.0, 0.6), (0.34, -0.2), (0.67, 0.1), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, -1.5), (0.5, -0.4), (1.0, 0.0)]))


def anim_muerte(t):
    if BICHO == 'mosquito':
        # deja de aletear y CAE en espiral, panza arriba al llegar
        return POSE(aleteo=2 * math.pi * t * 4.0 * (1.0 - t), cae=15.0 * min(1.0, t * 1.4) ** 2,
                    tumba=tramos(t, [(0.0, 0.0), (0.5, 0.3), (0.75, 1.0), (1.0, 1.0)]),
                    ladea=tramos(t, [(0.0, 0.0), (0.4, 2.0), (1.0, 0.0)]))
    if BICHO == 'garrapata' and HINCHA > 0:
        # HINCHADA: se tensa y REVIENTA (el efecto, la salpicadura); queda el pellejo
        return POSE(revienta=tramos(t, [(0.0, 0.0), (0.3, 0.3), (0.38, 0.4), (1.0, 1.0)]),
                    bota=tramos(t, [(0.0, 0.0), (0.3, 1.0), (0.38, 0.0), (1.0, 0.0)]))
    # patas arriba encogidas y aplastado
    return POSE(aplasta=tramos(t, [(0.0, 0.0), (0.3, 0.5), (1.0, 0.8)]), revienta=tramos(t, [(0.0, 0.0), (1.0, 0.3)]),
                ladea=tramos(t, [(0.0, 0.0), (0.3, -0.6), (1.0, 0.4)]))


ANIMS = {
    'idle': (8, 4.0 if BICHO != 'mosquito' else 12.0, True, 8, anim_idle),
    'walk': (8, 8.0 if BICHO != 'mosquito' else 12.0, True, 8, anim_walk),
    'embestida': (8, 10.0, False, 8, anim_embestida),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}
if BICHO == 'garrapata':
    ANIMS.update({'adherirse': (8, 11.0, False, 8, anim_adherirse), 'adherido': (6, 5.0, True, 8, anim_adherido),
                  'drenaje': (8, 11.0, False, 8, anim_drenaje)})
elif BICHO == 'mosquito':
    ANIMS['picadura'] = (10, 12.0, False, 8, anim_picadura)
else:
    ANIMS['bola'] = (12, 10.0, False, 8, anim_bola)


def escena(pose):
    if BICHO == 'garrapata':
        e = _Esc(huesos_garrapata(pose)); piezas_garrapata(e, pose)
    elif BICHO == 'mosquito':
        e = _Esc(huesos_mosquito(pose)); piezas_mosquito(e, pose)
    else:
        e = _Esc(huesos_pelotero(pose)); piezas_pelotero(e, pose)
    return e.L


if __name__ == '__main__':
    hornear('bichos_ambar_sdf', sys.argv[1:] or list(ANIMS.keys()), SALIDA, VISTAS)
