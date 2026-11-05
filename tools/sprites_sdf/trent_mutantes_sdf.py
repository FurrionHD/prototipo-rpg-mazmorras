# ============================================================
#  trent_mutantes_sdf.py -- LOS MUTANTES DEL TRENT animados (02/11/2026, trent-mutante). UNA LINEA unida por la savia:
#    TRENT_VAR=ambarino   el TOCON AMBARINO (1a evolucion, savia dura): el tocon araña de corteza viva rebosando ambar
#    TRENT_VAR=espantajo  el ESPANTAJO (2a, savia negra): altisimo y flaco, encorvado, copa de ramas muertas y garras
#  Sus cuerpos, los de la lamina (trent_mutantes_versiones.py: 'ambar C tocon' y 'marchito A espantajo'); aqui cada pieza
#  va a su HUESO y cada uno tiene sus gestos. Las animaciones son las del trent (las que usan sus habilidades, con los
#  mismos tiempos para que sus efectos caigan igual), mas comer y la EVOLUCION (de lo que era a lo que es), y el
#  Espantajo el GEISER (cargando y soltando). Mayores que el trent (x1,15 y x1,3); el origen, el del trent.
#  Uso: TRENT_VAR=ambarino python tools/sprites_sdf/trent_mutantes_sdf.py [anim ...]
#       -> tools/salida/sdf/trent_sdf_<var>/ (SIN hornear al juego hasta su visto bueno) y las vistas a su escritorio
# ============================================================
import sys, os, math, random
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import trent_sdf as ts
import trent_mutantes_versiones as tv

V = np.array
VAR = os.environ.get('TRENT_VAR', 'ambarino')
ESC = {'ambarino': 2.5 * 1.15, 'espantajo': 2.5 * 1.3}[VAR]
ESC_ANTES = {'ambarino': 2.5, 'espantajo': 2.5 * 1.15}[VAR]
LIENZO = {'ambarino': (240, 216), 'espantajo': (340, 400)}[VAR]   # (330 de alto: la copa se salia al alzar los brazos)
PIES = (LIENZO[0] / 2.0, LIENZO[1] * 2.10 / 3.80)
# SIN COSTRA (02/11, la variante de la pelea del Tocon cuando se le rompe la costra de ambar: "se ve sin costra" hasta
# que le vuelve a brotar): sin el ambar, con el domo roto (un hueco arriba) y las cuencas vacias en las rodillas.
SIN_COSTRA = VAR == 'ambarino' and os.environ.get('TRENT_SIN_COSTRA', '') == '1'
_suf = VAR + ('_sin_costra' if SIN_COSTRA else '')
SALIDA = 'assets/sprites/enemigos/trent_sdf_%s/' % _suf   # (02/11, "estan guapardos": ya van al juego)
VISTAS = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                      'trent_%s_hojas' % _suf) + os.sep
# EL PUDRIRSE de la evolucion al Espantajo, POCO A POCO (02/11: cambiar el material de golpe "es muy de golpe"): tonos
# intermedios del ambar a la savia negra, de la corteza viva a la seca y de los ojos de ambar a los palidos.
PUDRE = 5
PUDRE_DE = {'ambar': 'savia_negra', 'corteza': 'seca', 'ojo_ambar': 'ojo_palido'}


def _mat_pudre():
    m = tv._mat()
    for de, a in PUDRE_DE.items():
        for k in range(1, PUDRE):
            u = k / PUDRE
            t0, t1 = m[de], m[a]
            n = min(len(t0), len(t1))
            m['%s_p%d' % (de, k)] = [tuple(t0[i][c] * (1 - u) + t1[i][c] * u for c in range(3)) for i in range(n)]
    return m


MODELO = Modelo(ESC, LIENZO, PIES, _mat_pudre(), (0.12, 0.06, 0.05), suaves=('cuerpo', 'musgo'),
                brillan=tv.BRILLAN + tuple('ojo_ambar_p%d' % k for k in range(1, PUDRE)),
                corta_suelo=True, especular=('ambar', 'savia_negra') + tuple('ambar_p%d' % k for k in range(1, PUDRE)),
                umbral_especular=0.9,
                translucidos=('ambar',) if VAR == 'ambarino' else (), alfa=0.72)


def _paso(x, a, b):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def rot_eje(eje, ang):
    # Giro de 'ang' alrededor de 'eje' (Rodrigues).
    k = V(eje, dtype=float); k = k / np.linalg.norm(k)
    K = V(((0, -k[2], k[1]), (k[2], 0, -k[0]), (-k[1], k[0], 0)))
    return np.eye(3) + math.sin(ang) * K + (1 - math.cos(ang)) * K @ K


# ============================================================
#  LOS BRAZOS (04/11, su queja tras jugarlo: "planos y guarros, no doblan nada, rectos tiesos"; el del Espantajo, "un palo
#  que mide el 100 % de su alto"). Como los del trent normal: rama gruesa con CODO NUDOSO que dobla (hueso 'antebrazo_*'),
#  vetas de corteza en relieve, un muñon de rama, un nudo hueco y manazas de dedos-rama con nudillo.
# ============================================================
def _flexion(p, s):
    # El codo: algo doblado siempre; al coger impulso (alza > 0) se dobla mucho, al descargar se estira, y se queda un pelin
    # atras en el columpio (el antebrazo va arrastrado, que es lo que lo hace leerse como rama y no como palo).
    a = p['alza']
    f = 0.35 + (0.55 * a if a > 0 else 0.5 * a) - 0.3 * p['clava'] + 0.22 * p['columpio'] * s
    return max(0.05, f)


def huesos_codos(X, p, codos):
    for s, ld in ((-1, 'd'), (1, 'i')):
        X['antebrazo_' + ld] = comp(X['brazo_' + ld], sobre(codos[s], rx(_flexion(p, s)) @ ry(-s * 0.12)))


def _perp(d):
    a = np.cross(d, V((0.0, 0.0, 1.0)))
    if np.linalg.norm(a) < 1e-3:
        a = V((1.0, 0.0, 0.0))
    a = a / np.linalg.norm(a)
    return a, np.cross(d, a)


def _tramo_nudoso(e, a, b, r0, r1, mat, grupo, semilla):
    # De 'a' a 'b' en tres tramos que se tuercen un poco, con vetas de corteza en relieve alrededor.
    a, b = V(a, dtype=float), V(b, dtype=float)
    d = b - a; largo = np.linalg.norm(d); d = d / largo
    u1, u2 = _perp(d)
    rnd = random.Random(semilla)
    pts = [a]
    for k in (1, 2):
        t = k / 3.0
        pts.append(a + (b - a) * t + (u1 * rnd.uniform(-1, 1) + u2 * rnd.uniform(-1, 1)) * largo * 0.07)
    pts.append(b)
    rs = [r0, r0 + (r1 - r0) * 0.33 + 0.25, r0 + (r1 - r0) * 0.66, r1]
    for i in range(3):
        tv._cono(e, pts[i], pts[i + 1], rs[i], rs[i + 1], mat, 0.6, grupo)
    # LAS VETAS: cuatro costillas que van a lo largo, algo en espiral.
    for k in range(4):
        ang = k * math.pi / 2 + rnd.uniform(-0.3, 0.3)
        prev = None
        for j in range(4):
            t = j / 3.0
            c = pts[min(int(t * 3), 2)] * (1 - (t * 3 % 1)) + pts[min(int(t * 3) + 1, 3)] * (t * 3 % 1) if j < 3 else pts[3]
            r = r0 + (r1 - r0) * t
            q = ang + t * 0.6
            pt = c + (u1 * math.cos(q) + u2 * math.sin(q)) * r * 0.92
            if prev is not None:
                tv._cono(e, prev, pt, 0.42 * r0 / 2.0 + 0.2, 0.38 * r0 / 2.0 + 0.18, mat, 0.2, grupo)
            prev = pt
    return pts


# LAS VETAS DE UN TRONCO (04/11: "el tronco central sigue siendo completamente liso"): costillas de corteza en relieve que
# suben algo en espiral, como las del trent normal, menos donde diga 'evitar' (grados: la grieta, la cara).
def vetas_tronco(e, eje, rad, mat, n, semilla, evitar=(), t0=0.05, t1=0.95, grueso=0.8):
    rnd = random.Random(semilla)
    for k in range(n):
        a0 = k / n * 360.0 + rnd.uniform(-8, 8)
        if any(abs(((a0 - ev + 180) % 360) - 180) < 28 for ev in evitar):
            continue
        prev = None
        for j in range(6):
            t = t0 + (t1 - t0) * j / 5.0
            pt = tv._sobre(eje, rad, t, a0 + j * 7.0 + rnd.uniform(-3, 3), 0.05)
            if prev is not None:
                tv._cono(e, prev, pt, grueso, grueso * 0.85, mat, 0.3, 'veta')
            prev = pt


# Una pierna de rama: muslo y espinilla nudosos con la RODILLA abultada.
def pierna_rama(e, cadera, rodilla, pie, r, mat, grupo, semilla):
    _tramo_nudoso(e, cadera, rodilla, r[0], r[1], mat, grupo, semilla)
    tv._elip(e, rodilla, (r[1] * 1.35, r[1] * 1.35, r[1] * 1.25), mat, 0.5, grupo)
    _tramo_nudoso(e, rodilla, pie, r[1], r[2], mat, grupo, semilla + 5)


def brazo_rama(e, s, hombro, codo, mano, r, mat, semilla, n_dedos=3, largo_dedo=4.5, abre=1.0, ramitas=True):
    hb, ha = ('brazo_d', 'antebrazo_d') if s < 0 else ('brazo_i', 'antebrazo_i')
    g = 'brazo%d' % s
    hombro, codo, mano = V(hombro, dtype=float), V(codo, dtype=float), V(mano, dtype=float)
    # EL BRAZO: del hombro al codo, con un muñon de rama que sale hacia fuera y arriba.
    e.h = hb
    pts = _tramo_nudoso(e, hombro, codo, r[0], r[1], mat, g, semilla)
    tv._elip(e, codo, (r[1] * 1.3, r[1] * 1.3, r[1] * 1.2), mat, 0.6, g)
    if ramitas:
        if mat == 'seca':
            tv._rama_seca(e, pts[1], V((0.9 * s, -0.3, 0.6)), 6.0, r[1] * 0.45, semilla + 3, 1, mat, g)
        else:
            tv._cono(e, pts[1], pts[1] + V((2.4 * s, -0.6, 2.4)), r[1] * 0.42, 0.25, mat, 0, g)
    # EL ANTEBRAZO: arranca DENTRO del nudo del codo (varias celdas de solape: si no, al doblar se despega).
    e.h = ha
    tv._elip(e, codo, (r[1] * 1.35, r[1] * 1.35, r[1] * 1.25), mat, 0.6, g)
    pts2 = _tramo_nudoso(e, codo, mano, r[1], r[2], mat, g, semilla + 11)
    lado, _ = _perp((mano - codo) / max(np.linalg.norm(mano - codo), 1e-6))
    tv._elip(e, pts2[1] + lado * s * r[1] * 0.85, (r[1] * 0.35, r[1] * 0.35, r[1] * 0.5), 'hueco', 0, 'nudo')
    if ramitas:
        tv._cono(e, pts2[2], pts2[2] + V((1.6 * s, 0.4, 1.8)), r[2] * 0.4, 0.2, mat, 0, g)
    # LA MANAZA: un bulto de corteza y dedos-rama con NUDILLO (tres tramos que se doblan hacia abajo).
    delante = mano - codo; delante[2] = 0.0
    delante = delante / max(np.linalg.norm(delante), 1e-6) if np.linalg.norm(delante) > 0.1 else V((0.0, 1.0, 0.0))
    tv._elip(e, mano + V((0, 0.4, -0.4)), (r[2] * 1.45, r[2] * 1.3, r[2] * 1.2), mat, 0.8, g)
    lat = np.cross(delante, V((0, 0, 1.0))); lat /= max(np.linalg.norm(lat), 1e-6)
    for i in range(n_dedos):
        f = (i - (n_dedos - 1) / 2) * abre
        a = mano + lat * f * r[2] * 0.7 + V((0, 0, -r[2] * 0.4))
        b = a + delante * largo_dedo * 0.45 + lat * f * 0.5 + V((0, 0, -largo_dedo * 0.15))
        c = b + delante * largo_dedo * 0.3 + V((0, 0, -largo_dedo * 0.35))
        d = c + delante * largo_dedo * 0.1 + V((0, 0, -largo_dedo * 0.3))
        rd = r[2] * 0.42
        tv._cono(e, a, b, rd, rd * 0.85, mat, 0.2, g)
        tv._elip(e, b, (rd * 1.05, rd * 1.05, rd * 1.05), mat, 0.2, g)
        tv._cono(e, b, c, rd * 0.85, rd * 0.6, mat, 0.1, g)
        tv._cono(e, c, d, rd * 0.6, 0.08, mat, 0, g)
    e.h = 'tronco'


def POSE(**k):
    p = dict(avance=0.0, mece=0.0, balanceo=0.0, gira=0.0, bota=0.0, hunde=0.0, alza=0.0, abre=0.0, columpio=0.0,
             clava=0.0, patas=0.0, fase=0.0, recoge=0.0, abren=0.0, tumba=0.0, cabeza=0.0, evo=1.0, carga=0.0)
    p.update(k)
    return p


class _Esc(tv._Cuerpo):
    """Las piezas van al hueso que diga 'self.h' (lo cambia quien construye, tramo a tramo)."""
    def __init__(self, X):
        self.X = X
        self.L = Piezas()
        self.L.sombras = []
        self.h = 'tronco'

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso=None):
        h = hueso or self.h
        self.L.append((fn, mat, grupo, k, self.X.get(h, IDENT), h))


# ============================================================
#  EL TOCON AMBARINO
# ============================================================
T_BASE = V((0.0, 0.0, 8.0))
T_PATAS = [((i + 0.5) / 6 * 2 * math.pi) for i in range(6)]
T_HOMBRO = {s: V((5.0 * s, 6.0, 15.0)) for s in (-1, 1)}
T_CODO = {s: V((9.0 * s, 9.5, 11.0)) for s in (-1, 1)}
T_MANO = {s: V((8.0 * s, 17.0, 7.0)) for s in (-1, 1)}


def _cadera(i):
    a = T_PATAS[i]
    return V((0, 0, 9.0)) + V((math.cos(a), math.sin(a), 0.0)) * 7.0


def huesos_tocon(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], -p['hunde'])))
    X['raiz'] = raiz
    M = rz(p['gira']) @ rx(p['mece'] * 0.10) @ ry(p['balanceo'] * 0.10)
    tr = sobre(T_BASE, M)
    X['tronco'] = comp(raiz, (tr[0], tr[1] + V((0, 0, p['bota']))))
    for i, a in enumerate(T_PATAS):
        u = V((math.cos(a), math.sin(a), 0.0))
        t = V((-u[1], u[0], 0.0))
        # EL PASO: tripode alterno (0,2,4 contra 1,3,5): la que avanza va LEVANTADA.
        grupo = 1.0 if i % 2 == 0 else -1.0
        f = math.sin(2 * math.pi * p['fase']) * grupo
        sube = max(0.0, math.cos(2 * math.pi * p['fase']) * grupo)
        barre = p['patas'] * 0.28 * f
        alza = p['patas'] * 0.45 * sube + p['recoge'] * (0.9 + 0.15 * (i % 2)) - p['abren'] * 0.25
        # las de delante se levantan al encabritarse ('mece' negativo)
        alza += max(0.0, -p['mece']) * 0.22 * max(0.0, u[1])
        Mp = rz(barre) @ rot_eje(t, -alza)
        X['pata%d' % i] = comp(raiz, sobre(_cadera(i), Mp))
    for s, ld in ((-1, 'd'), (1, 'i')):
        a = ts._brazo_ang(p['alza']) * (1.0 - p['clava']) - 0.55 * p['clava'] + p['columpio'] * 0.30 * s
        Mb = rx(a) @ ry(-s * p['abre'] * 0.5)
        X['brazo_' + ld] = comp(X['tronco'], sobre(T_HOMBRO[s], Mb))
    huesos_codos(X, p, T_CODO)
    return X


def piezas_tocon(e, ambar=True):
    # El cuerpo de la lamina ('ambar C tocon'), con cada cosa en su hueso. SIN_COSTRA: sin el ambar (lo de abajo lo quita).
    mat = 'corteza' if ambar else 'seca'
    e.h = 'tronco'
    eje = [(0, 0, 8.0), (0, 0.3, 14.0), (0, 0.5, 21.0)]
    rad = [8.0, 8.6, 8.2]
    tv._tubo(e, eje, rad, mat, 'cuerpo', 1.5)
    if SIN_COSTRA:
        # el domo ROTO: la boca de arriba hueca, con restos de ambar pegados al borde, y las cuencas de las rodillas
        tv._elip(e, (0, 0.5, 28.6), (5.6, 5.6, 1.0), 'hueco', 0, 'hueco')
        for k, ang in enumerate((30, 150, 260)):
            a = math.radians(ang)
            tv._elip(e, (math.cos(a) * 5.2, 0.5 + math.sin(a) * 5.2, 28.0), (1.2, 1.0, 0.8), 'ambar', 0.3, 'resto')
    tv._ambar_con_bichos(e, (0, 0.5, 27.5), (5.8, 5.8, 3.8), 3, 61, 0.6)
    tv._escarabajo(e, V((0, 1.5, 29.0)), 1.3)
    for k, ang in enumerate((40, 110, 200, 290)):
        a = math.radians(ang)
        tv._ambar_con_bichos(e, (math.cos(a) * 6.0, 0.5 + math.sin(a) * 6.0, 24.0), (3.0, 3.0, 3.6), k % 2, 70 + k, 0.8)
    for k, ang in enumerate((20, 55, 125, 160, 215, 270, 325)):
        tv._gota(e, tv._sobre(eje, rad, 0.95, ang, -0.3), 5.0 + (k % 3) * 2.5, 0.8 + 0.15 * (k % 2))
    rnd = random.Random(5)
    for i in range(11):
        a = i / 11 * 2 * math.pi
        alto = (rnd.uniform(3.0, 9.0) if math.sin(a) < 0.5 else rnd.uniform(2.0, 4.0)) + 6.0
        b = V((math.cos(a) * 7.4, 0.5 + math.sin(a) * 7.4, 20.0))
        tv._cono(e, b, b + V((math.cos(a) * 0.8, math.sin(a) * 0.8, alto)), 1.6, 0.1, mat, 0.3, 'astilla')
    tv._ojos(e, V((0, 9.2, 16.5)), 2.4, 'ojo_ambar', (1.0, 0.5, 0.7))
    tv._elip(e, (0, 9.0, 12.5), (3.4, 0.7, 1.1), 'hueco', 0, 'boca')
    for x in (-2.4, -0.8, 0.8, 2.4):
        tv._cono(e, (x, 9.3, 13.4), (x, 9.6, 12.0), 0.45, 0.06, mat, 0, 'diente')
    for x in (-1.6, 1.4):
        tv._gota(e, V((x, 9.4, 11.8)), 2.2, 0.45)
    for i in range(6):
        e.h = 'pata%d' % i
        a = T_PATAS[i]
        u = V((math.cos(a), math.sin(a), 0.0))
        b = _cadera(i)
        rod = V((0, 0, 15.0)) + u * 14.0
        punta = V((0, 0, 0.3)) + u * 19.0
        # (04/11) con corteza: el muslo nudoso y la punta que se afila
        _tramo_nudoso(e, b, rod, 2.5, 1.9, mat, 'pata%d' % i, 30 + i)
        tv._cono(e, rod, punta, 1.8, 0.3, mat, 0.4, 'pata%d' % i)
        if SIN_COSTRA:
            tv._elip(e, rod + V((0, 0, 0.6)), (1.5, 1.5, 0.7), 'hueco', 0, 'cuenca')
        else:
            tv._ambar_con_bichos(e, rod, (2.4, 2.4, 2.2), 1 if i % 2 else 0, 80 + i, 0.4)
    for s in (-1, 1):
        brazo_rama(e, s, T_HOMBRO[s], T_CODO[s], T_MANO[s], (2.3, 2.0, 1.7), mat, 40 + s, 3, 4.5, 1.1)
        if not SIN_COSTRA:
            # una gota de ambar en el codo, que es suyo
            e.h = 'brazo_d' if s < 0 else 'brazo_i'
            tv._ambar_con_bichos(e, T_CODO[s] + V((0.8 * s, -0.6, 1.2)), (1.6, 1.6, 1.4), 0, 90 + s, 0.4)
    e.h = 'tronco'


# ============================================================
#  EL ESPANTAJO
# ============================================================
E_CADERA = {s: V((3.0 * s, -2.0, 21.0)) for s in (-1, 1)}
E_HOMBRO = {s: V((4.5 * s, 8.0, 40.0)) for s in (-1, 1)}
# (04/11) Mas cortos: el brazo entero bajaba de los hombros a los pies (32 de sus 41). Ahora el codo a media altura y la
# mano por la cadera; las garras, largas, son las que llegan abajo.
E_CODO = {s: V((9.5 * s, 9.0, 30.0)) for s in (-1, 1)}
E_MANO = {s: V((9.0 * s, 14.5, 20.0)) for s in (-1, 1)}
E_BASE = V((0.0, -2.0, 20.0))
E_CUELLO = V((0.0, 11.0, 41.0))


def huesos_espantajo(p):
    X = {}
    raiz = (np.eye(3), V((0.0, p['avance'], -p['hunde'])))
    if p['tumba'] > 0.0:
        # SE DESPLOMA HACIA DELANTE, de bruces, girando sobre los pies.
        raiz = comp(sobre(V((0.0, 3.0, 0.0)), rx(p['tumba'] * math.pi * 0.47)), raiz)
    X['raiz'] = raiz
    M = rz(p['gira']) @ rx(p['mece'] * 0.08) @ ry(p['balanceo'] * 0.09)
    tr = sobre(E_BASE, M)
    X['tronco'] = comp(raiz, (tr[0], tr[1] + V((0, 0, p['bota']))))
    X['cabeza'] = comp(X['tronco'], sobre(E_CUELLO, rx(p['cabeza'] * 0.12)))
    for s, ld in ((-1, 'd'), (1, 'i')):
        a = ts._brazo_ang(p['alza']) * (1.0 - p['clava']) - 0.25 * p['clava'] + p['columpio'] * 0.30 * s
        Mb = rx(a * 0.8) @ ry(-s * p['abre'] * 0.5)
        X['brazo_' + ld] = comp(X['tronco'], sobre(E_HOMBRO[s], Mb))
        Mp = rx(p['patas'] * 0.30 * s * math.sin(2 * math.pi * p['fase'])) @ ry(s * p['recoge'] * 0.08)
        X['pierna_' + ld] = comp(raiz, sobre(E_CADERA[s], Mp))
    huesos_codos(X, p, E_CODO)
    return X


def piezas_espantajo(e, carga=0.0):
    # El cuerpo de la lamina ('marchito A espantajo'), con cada cosa en su hueso. 'carga' (el Geiser): la GRIETA de la
    # espalda se abre y brilla mas.
    for s in (-1, 1):
        e.h = 'pierna_d' if s < 0 else 'pierna_i'
        g = 'pierna%d' % s
        pie = V((5.5 * s, 0.0, 1.5))
        pierna_rama(e, E_CADERA[s], V((5.5 * s, 3.5, 12.0)), pie, (2.5, 2.0, 1.6), 'seca', g, 20 + s)
        tv._raices_pie(e, pie, 'seca', 4, 4.0, 0.9, g)
    e.h = 'tronco'
    eje = [(0, -2.0, 20.0), (0, -1.0, 28.0), (0, 2.0, 35.0), (0, 7.0, 40.0), (0, 11.0, 41.0)]
    rad = [4.4, 4.0, 4.0, 3.8, 3.0]
    tv._tubo(e, eje, rad, 'seca', 'cuerpo', 1.0)
    # la corteza: vetas en espiral (no por la grieta de la espalda) y unos nudos huecos
    vetas_tronco(e, eje, rad, 'seca', 12, 33, evitar=(270,), grueso=0.75)
    for (t, ang) in ((0.3, 30), (0.55, 150), (0.75, 60)):
        tv._elip(e, tv._sobre(eje, rad, t, ang, -0.2), (0.9, 0.9, 1.3), 'hueco', 0, 'nudo')
    tv._grietas(e, eje, rad, (40, 140, 220, 320), 'savia_negra', 'grieta_luz', 31, 0.05, 0.75, 0.2)
    # LA GRIETA DE LA ESPALDA (por donde sale el Geiser): una raja larga por el espinazo, con la luz dentro.
    ancho = 0.9 + 0.9 * carga
    pts = [tv._sobre(eje, rad, t, 270, 0.25) for t in np.linspace(0.15, 0.7, 6)]
    luz = [tv._sobre(eje, rad, t, 270, 0.75 + 0.5 * carga) for t in np.linspace(0.15, 0.7, 6)]
    for a, b in zip(pts, pts[1:]):
        tv._cono(e, a, b, ancho, ancho * 0.8, 'savia_negra', 0, 'grieta')
    for a, b in zip(luz, luz[1:]):
        tv._cono(e, a, b, ancho * 0.45, ancho * 0.4, 'grieta_luz', 0, 'grieta_luz')
    for i, (b, d, lg, r) in enumerate((((-3.0, 3.0, 40.0), (-0.8, -0.3, 1.0), 20.0, 1.8),
                                       ((3.0, 3.0, 40.0), (0.8, -0.3, 1.0), 20.0, 1.8),
                                       ((0.0, 0.5, 39.0), (0.0, -0.8, 1.0), 22.0, 2.0),
                                       ((-2.0, -1.0, 34.0), (-0.9, -0.9, 0.6), 15.0, 1.5),
                                       ((2.0, -1.0, 34.0), (0.9, -0.9, 0.6), 15.0, 1.5),
                                       ((0.0, 6.0, 41.5), (0.1, 0.3, 1.0), 13.0, 1.3))):
        tv._rama_seca(e, b, d, lg, r, 70 + i * 7, 2)
    e.h = 'cabeza'
    tv._elip(e, (0, 15.0, 37.5), (3.2, 3.2, 4.6), 'seca', 1.2, 'cuerpo')
    tv._ojos(e, V((0, 17.8, 38.5)), 1.4, 'ojo_palido', (0.8, 0.5, 0.6))
    tv._cono(e, (-1.2, 18.0, 35.0), (1.2, 18.0, 35.0), 0.6, 0.6, 'hueco', 0, 'boca')
    for x in (-1.0, 0.0, 1.0):
        tv._cono(e, (x, 17.5, 34.5), (x * 1.2, 17.6, 31.0 - abs(x)), 0.5, 0.1, 'seca', 0, 'barba')
    for s in (-1, 1):
        brazo_rama(e, s, E_HOMBRO[s], E_CODO[s], E_MANO[s], (2.3, 1.9, 1.6), 'seca', 60 + s, 4, 7.0, 1.0)
    e.h = 'tronco'


# ============================================================
#  ANIMACIONES (los tiempos de los gestos, los del trent)
# ============================================================
def anim_idle(t):
    if VAR == 'ambarino':
        return POSE(bota=0.35 * math.sin(2 * math.pi * t), mece=0.4 * math.sin(2 * math.pi * t + 0.5),
                    columpio=0.3 * math.sin(2 * math.pi * t + 0.8), abren=0.15 * math.sin(2 * math.pi * t))
    return POSE(mece=0.5 * math.sin(2 * math.pi * t), cabeza=0.8 * math.sin(2 * math.pi * t + 1.0),
                columpio=0.35 * math.sin(2 * math.pi * t + 0.8), bota=0.3 * math.sin(4 * math.pi * t))


def anim_walk(t):
    if VAR == 'ambarino':
        # CORRETEA a lo araña: tripode alterno y el cuerpo apenas se mueve.
        return POSE(patas=1.0, fase=t, bota=0.4 * abs(math.sin(2 * math.pi * t)), columpio=0.4 * math.sin(2 * math.pi * t))
    # A ZANCADAS largas, encorvado, la cabeza colgando que se balancea.
    f = math.sin(2 * math.pi * t)
    return POSE(patas=1.0, fase=t, balanceo=0.8 * f, mece=0.6 + 0.3 * abs(f), columpio=0.9 * f,
                cabeza=1.2 * math.sin(2 * math.pi * t + 0.6), bota=0.6 * abs(f))


def anim_embestida(t):
    # EL GOLPE: se echa atras alzando los brazos y los DESCARGA hacia delante en el 0,55.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 4.0), (0.75, 4.4), (1.0, 2.8)]),
                mece=tramos(t, [(0.0, 0.0), (0.35, -1.6), (0.55, 1.8), (0.75, 1.0), (1.0, 0.2)]),
                alza=tramos(t, [(0.0, 0.0), (0.35, 1.0), (0.55, -0.9), (0.75, -0.4), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.35, -1.5), (0.55, 2.0), (1.0, 0.0)]))


def anim_escupir(t):
    # LA RESINA / LA SAVIA NEGRA: se echa atras cogiendo aire y se VUELCA al soltar (en el 3o-4o).
    return POSE(mece=tramos(t, [(0.0, 0.0), (0.143, -1.4), (0.286, -2.2), (0.429, 2.0), (0.571, 2.6), (0.714, 1.4),
                                (0.857, 0.5), (1.0, 0.0)]),
                bota=tramos(t, [(0.0, 0.0), (0.286, 1.2), (0.429, -0.6), (0.714, 0.0), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.143, 0.6), (0.286, 1.1), (0.429, 0.7), (0.571, 0.3), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.143, 0.5), (0.286, 0.8), (0.429, 0.0), (0.571, -0.3), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.286, -2.5), (0.429, 2.5), (0.714, 1.0), (1.0, 0.0)]))


def anim_basico(t):
    # EL BASICO: baja los brazos al suelo y TIRA hacia arriba de golpe (en 0,55).
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 1.0), (0.75, 0.7), (1.0, 0.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.35, 1.0), (0.55, -0.9), (0.75, -0.5), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.35, 0.5), (0.55, 0.2), (1.0, 0.0)]),
                bota=tramos(t, [(0.0, 0.0), (0.35, -0.8), (0.55, 0.8), (1.0, 0.0)]))


def _barrido(t, signo):
    bal = tramos(t, [(0.0, -1.1 * signo), (0.5, 1.2 * signo), (1.0, 1.0 * signo)])
    return POSE(mece=0.9 * math.sin(math.pi * t), balanceo=bal * 0.5, gira=bal * 0.45, abre=0.8, alza=-0.6,
                abren=0.3)


def anim_barrido_raiz(t):
    return _barrido(t, 1.0)


def anim_barrido_vuelta(t):
    return _barrido(t, -1.0)


def anim_raices(t):
    # CLAVA LAS MANOS EN EL SUELO (en 0,52) y ahi se queda: el tocon se agacha abriendo las patas.
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.28, 0.95), (0.52, 0.0), (1.0, 0.0)]),
                clava=tramos(t, [(0.0, 0.0), (0.28, 0.0), (0.52, 1.0), (1.0, 1.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.28, -0.9), (0.52, 2.6), (0.74, 2.2), (1.0, 2.0)]),
                hunde=tramos(t, [(0.0, 0.0), (0.28, 0.0), (0.52, 2.0 if VAR == 'ambarino' else 3.0), (1.0, 1.8)]),
                abren=tramos(t, [(0.0, 0.0), (0.28, 0.0), (0.52, 1.0), (1.0, 0.9)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.52, 2.0), (1.0, 1.5)]))


def anim_encaje(t):
    return POSE(mece=tramos(t, [(0.0, -1.9), (0.34, 1.0), (0.67, -0.4), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.30), (0.34, -0.35), (0.67, 0.12), (1.0, 0.0)]),
                abren=tramos(t, [(0.0, 0.5), (0.34, -0.2), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, -2.5), (0.34, 1.5), (1.0, 0.0)]))


def anim_muerte(t):
    if VAR == 'ambarino':
        # SE MUERE COMO UNA ARAÑA: las patas se encogen hacia arriba y el tocon se desploma y se ladea.
        return POSE(recoge=tramos(t, [(0.0, 0.0), (0.2, 0.2), (0.6, 0.9), (1.0, 1.1)]),
                    hunde=tramos(t, [(0.0, 0.0), (0.3, 1.0), (0.6, 6.0), (0.8, 8.0), (1.0, 7.6)]),
                    balanceo=tramos(t, [(0.0, 0.0), (0.3, -0.8), (0.8, 1.6), (1.0, 1.5)]),
                    alza=tramos(t, [(0.0, 0.0), (0.3, 0.6), (1.0, -0.5)]))
    # SE DERRUMBA DE RODILLAS como un arbol seco que se quiebra: se tambalea, le fallan las piernas, se hinca y se dobla
    # hacia delante (no cae cuan largo es: no cabia en el lienzo y en la pelea tapaba media pantalla).
    return POSE(tumba=tramos(t, [(0.0, 0.0), (0.14, -0.04), (0.28, 0.05), (0.45, 0.20), (0.62, 0.38), (0.78, 0.50),
                                 (0.90, 0.47), (1.0, 0.48)]),
                hunde=tramos(t, [(0.0, 0.0), (0.28, 1.0), (0.45, 5.0), (0.62, 9.0), (0.78, 10.0), (1.0, 10.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.14, -1.0), (0.45, 1.5), (1.0, 2.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.28, 0.6), (0.62, 1.0), (1.0, 1.1)]),
                recoge=tramos(t, [(0.0, 0.0), (0.45, 1.0), (1.0, 2.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.45, 2.0), (1.0, 3.0)]))


def anim_comer(t):
    # COME: se inclina, se lleva las manos a la boca y masca.
    masca = math.sin(2 * math.pi * t * 4.0) * (0.25 < t < 0.85)
    return POSE(mece=tramos(t, [(0.0, 0.0), (0.15, 1.6), (0.85, 1.6), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.15, 0.55), (0.85, 0.55), (1.0, 0.0)]) + 0.12 * masca,
                bota=0.5 * masca, cabeza=tramos(t, [(0.0, 0.0), (0.15, 2.5), (0.85, 2.5), (1.0, 0.0)]) + 1.2 * masca)


def anim_geiser_carga(t):
    # EL GEISER, CARGANDO (en bucle): encorvado del todo, tiembla y la grieta de la espalda se abre y brilla.
    tiembla = math.sin(2 * math.pi * t * 4.0)
    return POSE(mece=2.4 + 0.3 * tiembla, cabeza=2.5, alza=-0.3, abre=0.4, balanceo=0.15 * tiembla,
                carga=0.6 + 0.4 * abs(math.sin(math.pi * t * 2.0)), bota=-0.6)


def anim_geiser(t):
    # EL GEISER, SOLTANDO: se ARQUEA hacia atras de golpe (en el 0,35 sale el chorro por la grieta) y se recoge.
    return POSE(mece=tramos(t, [(0.0, 2.4), (0.25, 2.8), (0.35, -2.2), (0.6, -1.6), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.4), (0.35, 1.3), (0.6, 1.0), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, -0.3), (0.35, 0.9), (0.6, 0.6), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 2.5), (0.35, -3.0), (1.0, 0.0)]),
                carga=tramos(t, [(0.0, 1.0), (0.35, 1.0), (0.6, 0.3), (1.0, 0.0)]),
                bota=tramos(t, [(0.0, -0.6), (0.35, 1.2), (1.0, 0.0)]))


def anim_evolucion(t):
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.40, 0.50))
    return POSE(evo=tramos(t, [(0.0, 0.0), (0.10, 0.0), (0.90, 1.0), (1.0, 1.0)]), balanceo=0.4 * tiembla)


ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 5.0 if VAR == 'ambarino' else 4.0, True, 8, anim_walk),
    'embestida': (8, 8.0, False, 8, anim_embestida),
    'escupir': (8, 10.0, False, 8, anim_escupir),
    'basico': (8, 9.0, False, 8, anim_basico),
    'barrido_raiz': (6, 10.0, False, 8, anim_barrido_raiz),
    'barrido_vuelta': (6, 10.0, False, 8, anim_barrido_vuelta),
    'raices': (8, 7.0, False, 8, anim_raices),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
    'comer': (10, 10.0, False, 8, anim_comer),
    'evolucion': (18 if VAR == 'ambarino' else 24, 10.0, False, 8, anim_evolucion),   # (el pudrirse, despacio)
}
if SIN_COSTRA:
    del ANIMS['comer'], ANIMS['evolucion']
if VAR == 'espantajo':
    ANIMS['geiser_carga'] = (8, 8.0, True, 8, anim_geiser_carga)
    ANIMS['geiser'] = (8, 10.0, False, 8, anim_geiser)


# ============================================================
#  LA ESCENA (y la EVOLUCION, de lo que era a lo que es)
# ============================================================
def _escala(L, s, dz=0.0):
    # Todo el modelo a escala 's' desde los pies (y subido/bajado 'dz').
    for i, (fn, m, g, k, Xh, nh) in enumerate(L):
        L[i] = (fn, m, g, k, (Xh[0] * s, Xh[1] * s + V((0, 0, dz))), nh)
    return L


def _cambia_mat(L, cambios):
    return [(fn, cambios.get(m, m), g, k, Xh, nh) for (fn, m, g, k, Xh, nh) in L]


def escena_mutante(pose):
    if VAR == 'ambarino':
        e = _Esc(huesos_tocon(pose))
        piezas_tocon(e)
        if SIN_COSTRA:
            # fuera el ambar del tronco (el domo, los grumos, las gotas, sus bichos y el escarabajo); quedan los restos
            fuera = {'ambar', 'bicho'}
            e.L[:] = [x for x in e.L if not (x[1] in fuera and x[2] != 'resto')]
    else:
        e = _Esc(huesos_espantajo(pose))
        piezas_espantajo(e, pose['carga'])
    return e.L


def escena(pose):
    evo = pose['evo']
    if evo >= 1.0:
        return escena_mutante(pose)
    L = Piezas(); L.sombras = []
    if VAR == 'ambarino':
        # DEL TRENT AL TOCON: el trent tiembla y el AMBAR le brota de los pies y lo envuelve en un capullo; el capullo
        # tiembla y REVIENTA en trozos que salen despedidos y caen, y de dentro sale el tocon, que despliega las patas.
        s_t = ESC_ANTES / ESC
        capullo = _paso(evo, 0.05, 0.45)
        REVIENTA = 0.6
        e = _Esc({'raiz': IDENT})
        e.h = 'raiz'
        if evo < REVIENTA:
            L.extend(_escala(list(ts.escena(ts.POSE(mece=pose['balanceo'], balanceo=pose['balanceo']))), s_t))
            alto = 6.0 + 34.0 * capullo
            ancho = 6.0 + 9.0 * capullo
            hincha = 1.0 + 0.06 * _paso(evo, 0.48, REVIENTA)
            tv._ambar_con_bichos(e, (0, 0, alto * 0.48), (ancho * hincha, ancho * hincha, alto * 0.55), 4, 91, 0.8)
        else:
            q = _paso(evo, REVIENTA, 0.92)
            Lm = escena_mutante(POSE(recoge=0.9 * (1 - q), hunde=2.5 * (1 - q), bota=0.8 * math.sin(math.pi * q)))
            L.extend(_escala(list(Lm), 0.85 + 0.15 * q))
            # Los TROZOS del capullo: salen hacia fuera y arriba, caen (parabola) y se hunden al tocar el suelo.
            u = min(1.0, (evo - REVIENTA) / 0.3)
            rnd = random.Random(17)
            for i in range(12):
                a = i / 12 * 2 * math.pi + rnd.uniform(-0.2, 0.2)
                z0 = rnd.uniform(8.0, 34.0)
                v = rnd.uniform(9.0, 16.0)
                r0 = (math.cos(a) * 9.0, math.sin(a) * 9.0)
                x = r0[0] + math.cos(a) * v * u
                y = r0[1] + math.sin(a) * v * u
                z = z0 + 10.0 * u - 52.0 * u * u
                tam = rnd.uniform(1.6, 3.0) * (1.0 - 0.6 * _paso(u, 0.7, 1.0))
                if z > -tam:
                    tv._elip(e, (x, y, max(z, 0.0)), (tam, tam * 0.8, tam * 0.6), 'ambar', 0, 'trozo')
        L.extend(e.L)
        return L
    # DEL TOCON AL ESPANTAJO: el ambar se PUDRE (ennegrece) y el tocon se hunde en la tierra encogiendo las patas;
    # de ese sitio el Espantajo SALE CRECIENDO del suelo como un arbol, desplegando la copa.
    s_t = ESC_ANTES / ESC
    if evo < 0.66:
        sink = _paso(evo, 0.42, 0.66)
        pt = POSE(recoge=0.7 * sink, hunde=14.0 * sink, balanceo=pose['balanceo'])
        e = _Esc(huesos_tocon(pt))
        piezas_tocon(e)
        Lt = list(e.L)
        # primero se pudre el ambar y los ojos; la corteza se seca un poco despues
        cambios = {}
        for de, a_, u in (('ambar', 'savia_negra', _paso(evo, 0.04, 0.36)), ('ojo_ambar', 'ojo_palido', _paso(evo, 0.04, 0.36)),
                          ('corteza', 'seca', _paso(evo, 0.14, 0.44))):
            k = int(round(u * PUDRE))
            if k >= PUDRE:
                cambios[de] = a_
            elif k > 0:
                cambios[de] = '%s_p%d' % (de, k)
        Lt = _cambia_mat(Lt, cambios)
        L.extend(_escala(Lt, s_t))
    if evo > 0.52:
        sube = _paso(evo, 0.52, 0.96)
        Lm = list(escena_mutante(POSE(mece=1.2 * (1 - sube), alza=0.8 * (1 - sube), cabeza=2.0 * (1 - sube))))
        L.extend(_escala(Lm, 0.55 + 0.45 * sube, -38.0 * (1 - sube)))
    return L


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        for d, f in enumerate(fotos):
            print(d, f.getbbox())
    else:
        hornear('trent_mutantes_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
