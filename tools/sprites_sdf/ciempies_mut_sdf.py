# ============================================================
#  ciempies_mut_sdf.py -- LOS MUTANTES DEL CIEMPIES CARMESI, con sus animaciones (05/11/2026, ciempies-mutante).
#  Los cuerpos son los elegidos en ciempies_mutantes_versiones.py, con la cabeza ESCUDO:
#    CIEM_VAR=bicefalo  CIEMPIES BICEFALO  herradura: una cabeza en cada punta (naranja A, turquesa B), las dos delante.
#    CIEM_VAR=nudo      NUDO CARMESI       monton: enorme y enrollado, una cabeza a ras de suelo (A) y otra en lo alto (B).
#  NO TIENE CUERPO, TIENE UNA CADENA (como el normal): cada pose calcula donde cae cada anillo y todo cuelga de ahi.
#  EL ENROSQUE son piezas sueltas que el combate pone a los pies de la presa:
#    enroscarse/enroscado/apreton/desenroscarse + _detras/_delante  la helice con la cabeza A
#    libre_idle, libre_muerde                                       lo que no enrosca, con la cabeza B: sigue atacando a otro
#    (nudo) las mismas con _b                                       la segunda helice, con la cabeza B, si atrapa a dos
#  Uso: CIEM_VAR=bicefalo python tools/sprites_sdf/ciempies_mut_sdf.py [anim ...] -> assets/sprites/enemigos/ciempies_sdf_<var>/
#       python tools/sprites_sdf/ciempies_mut_sdf.py hoja bicefalo|nudo [anim ...] -> la hoja para mirarla, al escritorio
#       (la hoja dibuja solo lo que enseña, sin tocar assets: PROCESOS=n, 3 por defecto)
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import ciempies_sdf as normal
import ciempies_mutantes_versiones as ver

V = np.array
VAR = os.environ.get('CIEM_VAR', 'bicefalo')
SALIDA = 'assets/sprites/enemigos/ciempies_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/'
_cono = normal._cono
_elip = normal._elip
_marco = normal._marco

# LA TRANSICION DE COLOR (memoria transiciones-de-color): en la evolucion el color se mezcla poco a poco, con materiales
# intermedios. 'de' es de donde sale cada material en la primera evolucion (el ciempies normal no tiene cabezas de color).
PASOS_TINTE = 8
_MAT = dict(ver.MAT)
_DE_NORMAL = {'cuerpo': normal.MAT['cuerpo'], 'placa': normal.MAT['placa'], 'pata': normal.MAT['pata'],
              'cabA': normal.MAT['cuerpo'], 'cabB': normal.MAT['cuerpo'], 'banda': normal.MAT['placa']}
_DE_BICEFALO = {'banda': ver.MAT['placa']}
for _o, _tabla in (('n', _DE_NORMAL), ('b', _DE_BICEFALO)):
    for _m, _desde in _tabla.items():
        for _k in range(0, PASOS_TINTE):
            _u = _k / PASOS_TINTE
            _MAT['%s>%s>%d' % (_o, _m, _k)] = [tuple(x + (y - x) * _u for x, y in zip(ca, cb)) for ca, cb in zip(_desde, ver.MAT[_m])]

_LIENZO = {'bicefalo': (136, 136), 'nudo': (184, 216)}[VAR]
MODELO = Modelo(2.3, _LIENZO, (_LIENZO[0] // 2, _LIENZO[1] // 2), _MAT, (0.07, 0.02, 0.06), suaves=('cuerpo',), brillan=('ojo',),
                corta_suelo=True)

Z_BIC = 1.5


def _ctrl_bicefalo():
    z = Z_BIC
    return [(-6.2, 7.0, z), (-6.2, 2.0, z), (-5.2, -3.0, z), (-2.4, -6.0, z), (2.4, -6.0, z), (5.2, -3.0, z), (6.2, 2.0, z), (6.2, 7.0, z)]


def _ctrl_nudo():
    ctrl = [(1.5, 15.0, 3.0), (5.5, 9.0, 3.0)]
    for k in range(10):
        a = math.radians(70) - k * math.radians(68)
        ctrl.append((8.0 * math.cos(a), 8.0 * math.sin(a), 3.0 + k * 0.62))
    ctrl += [(1.0, -5.0, 9.8), (-0.5, 0.5, 13.0), (0.0, 5.5, 15.5)]
    return ctrl


def _ctrl_normal():
    return [(0.0, 11.0, Z_BIC), (0.0, -11.0, Z_BIC)]


# N anillos; radio; radio en la punta; tamaño de cabeza; cada cuanto una banda; largo y grosor de pata; anillos que mueve cada cabeza
CONF = {
    'bicefalo': dict(N=16, r=2.15, fino=None, tam=1.15, bandas=0, lp=2.7, gp=1.0, cuello=5, amp=1.0),
    'nudo': dict(N=34, r=ver.R_GORDO, fino=2.6, tam=1.6, bandas=3, lp=3.0, gp=1.2, cuello=8, amp=0.5),
}
C = CONF[VAR]
N = C['N']


def POSE(**k):
    p = dict(fase=0.0, onda=0.4, paso=0.0, avance=0.0, vibra=0.0,
             # Cada cabeza por su cuenta: hacia delante, hacia arriba y hacia el centro.
             avA=0.0, altoA=0.0, ladoA=0.0, avB=0.0, altoB=0.0, ladoB=0.0,
             # MONTON: lo que sube (1 = como es) y lo que se aplasta y se abre al caer.
             sube=1.0, abre=1.0,
             # MUERTO: las dos puntas se enrollan cada una hacia dentro.
             enrosca=0.0,
             # LA EVOLUCION: forma de partida ('normal', 'bicefalo'), cuanto lleva de la nueva, y cuanto del color nuevo.
             desde='', evo=1.0, tinte=1.0,
             # LO SUELTO (el enrosque): 'pieza' = '', 'helice', 'libre'.
             pieza='', cab='A', sube_h=1.0, aprieta=1.0, gira=0.0, mitad=0)
    p.update(k)
    return p


def _muestras(ctrl, n):
    m = ver._catmull(ctrl) if len(ctrl) > 2 else [V(ctrl[0], dtype=float) + (V(ctrl[1], dtype=float) - V(ctrl[0], dtype=float)) * (i / 239.0) for i in range(240)]
    dist = [0.0]
    for i in range(1, len(m)):
        dist.append(dist[-1] + np.linalg.norm(m[i] - m[i - 1]))
    pts = []
    j = 0
    for i in range(n):
        obj = dist[-1] * i / (n - 1)
        while j < len(m) - 2 and dist[j + 1] < obj:
            j += 1
        pts.append(m[j])
    return np.array(pts)


def _forma(var):
    return _muestras({'bicefalo': _ctrl_bicefalo, 'nudo': _ctrl_nudo, 'normal': _ctrl_normal}[var](), N)


def _radios(p):
    """Radio de cada anillo; en la evolucion engorda poco a poco."""
    def de(var):
        c = CONF.get(var)
        if var == 'normal':
            return [2.15] * N
        out = []
        for i in range(N):
            punta = min(i, N - 1 - i)
            r = c['r']
            if c['fino'] is not None and punta < 4:
                r = c['fino'] + (c['r'] - c['fino']) * punta / 4.0
            out.append(r)
        return out
    r = np.array(de(VAR))
    if p['desde']:
        r = np.array(de(p['desde'])) * (1.0 - p['evo']) + r * p['evo']
    return r


def _traza(p):
    pts = _forma(VAR)
    if p['desde']:
        pts = _forma(p['desde']) * (1.0 - p['evo']) + pts * p['evo']
    z0 = C['r'] * 0.8 if VAR == 'nudo' else Z_BIC
    pts[:, 2] = z0 + (pts[:, 2] - z0) * p['sube']
    if p['abre'] != 1.0:
        pts[:, 0] *= p['abre']; pts[:, 1] *= p['abre']
    # LA ONDA: de lado respecto a por donde va la cadena, viaja de una punta a la otra.
    t = np.gradient(pts, axis=0)
    n = np.stack([-t[:, 1], t[:, 0]], axis=1)
    n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-4)
    for i in range(N):
        o = p['onda'] * 1.2 * C['amp'] * math.sin(2 * math.pi * (p['fase'] + i * 0.16 * 16 / N))
        pts[i, :2] += n[i] * o
    # CADA CABEZA arrastra su cuello, cada vez menos hacia el centro.
    L = C['cuello']
    for i in range(L):
        w = (1.0 - i / L) ** 1.5
        pts[i] += V((p['ladoA'], p['avA'], p['altoA'])) * w
        pts[N - 1 - i] += V((-p['ladoB'], p['avB'], p['altoB'])) * w
    # MUERTO: una espiral por cada punta, y el medio del cuerpo las une (una S cerrada).
    if p['enrosca'] > 0.0:
        ext = 7.5 if VAR == 'bicefalo' else 12.0
        for i in range(N):
            izq = i < N / 2
            f = (i if izq else N - 1 - i) / (N / 2.0)
            # Abierta: con mas vueltas los 16 anillos se pisan y sale un borron.
            # Cada cabeza arranca POR FUERA de su espiral: por dentro se juntan las dos en el centro y no se lee nada.
            a = (0.6 + math.pi if izq else 0.6) + f * 3.8
            rad = ext * 0.72 * (1.0 - f * 0.6)
            cx = -ext * 0.8 if izq else ext * 0.8
            obj = V((cx + rad * math.cos(a), rad * math.sin(a), z0))
            pts[i] = pts[i] * (1.0 - p['enrosca']) + obj * p['enrosca']
    pts[:, 1] += p['avance']
    pts[:, 0] += p['vibra']
    return pts


def _m(nombre, p):
    """El material con el tinte de la evolucion a medias."""
    if p['desde'] and p['tinte'] < 1.0:
        tabla = 'n' if p['desde'] == 'normal' else 'b'
        if nombre in (_DE_NORMAL if tabla == 'n' else _DE_BICEFALO):
            return '%s>%s>%d' % (tabla, nombre, min(PASOS_TINTE - 1, int(p['tinte'] * PASOS_TINTE)))
    return nombre


def _cabeza(add, h, mat, t, p, cuerpo_normal=False):
    """La ESCUDO elegida, menos cuadrada: redondeada, la placa mas pequeña, ojos que se vean y las hoces de hueso."""
    _elip(add, (0, 1.4 * t, 0.0), (2.35 * t, 2.7 * t, 1.25 * t), mat, 0, 'cabeza', h)
    _elip(add, (0, 0.7 * t, 0.85 * t), (1.1 * t, 1.3 * t, 0.55 * t), _m('placa', p), 0, 'cabplaca', h)
    for s in (-1, 1):
        _elip(add, (1.15 * s * t, 2.9 * t, 0.8 * t), (0.62 * t, 0.55 * t, 0.5 * t), 'ojo', 0, 'ojo', h)
        _cono(add, (0.8 * s * t, 3.4 * t, 0.8 * t), (2.6 * s * t, 5.8 * t, 2.0 * t), 0.5, 0.36, _m('pata', p), 0, 'antena', h)
        _cono(add, (2.6 * s * t, 5.8 * t, 2.0 * t), (3.8 * s * t, 7.8 * t, 1.4 * t), 0.36, 0.26, _m('pata', p), 0, 'antena', h)
        ver._hoz(add, h, s, (1.6 * t, 3.4 * t, -0.2), (2.6 * t, 5.0 * t, -0.2), (0.7 * t, 6.2 * t, -0.2), 0.8 * t)


def _construir(pts, radios, p, cab_a=1.0, cab_b=1.0, delante=None):
    """La cadena dibujada. 'cab_a', 'cab_b': tamaño de cada cabeza (0 = no tiene); 'delante': en la helice, que anillos van
    delante de la presa (con 'mitad' solo se dibujan los de ese lado)."""
    n = len(pts)
    X = {}
    for i in range(n):
        d = pts[max(i - 1, 0)] - pts[min(i + 1, n - 1)]
        X['a%d' % i] = (_marco(d), pts[i])
    X['cabA'] = (_marco(pts[0] - pts[1]), pts[0])
    X['cabB'] = (_marco(pts[-1] - pts[-2]), pts[-1])
    e = Escena(X)
    add = e.add
    mitad = p['mitad']
    enrollado = p['pieza'] == 'helice'
    lp, gp = C['lp'], C['gp']
    # Lo mismo que el largo de cada anillo: lo que haya hasta el vecino (en la helice se separan).
    for i in range(n):
        if mitad and delante is not None and delante[i] != (mitad == 2):
            continue
        h = 'a%d' % i
        # (05/11, el jefe: "al enroscarse se encojen, no mantienen su tamaño": medido, -25 % y -40 % de grosor.) El mismo
        # grosor enroscado que suelto; lo que cambia es la helice, mas ancha.
        r = radios[i] * (1.0 - 0.18 * p['enrosca'])
        ly = max(1.75, np.linalg.norm(pts[max(i - 1, 0)] - pts[min(i + 1, n - 1)]) * 0.5)
        _elip(add, (0, 0, 0), (r * 1.15, ly * 0.66, r * 0.85), _m('cuerpo', p), 0.6, hueso=h)
        mat = 'banda' if C['bandas'] and i % C['bandas'] == 0 and p['desde'] != 'normal' else 'placa'
        # El color de la cabeza se queda en el anillo pegado a ella.
        if i == 0 and cab_a > 0:
            mat = 'cabA'
        elif i == n - 1 and cab_b > 0:
            mat = 'cabB'
        ancho = 0.3 if mat == 'banda' else 0.5
        _elip(add, (0, 0, r * 0.45), (r * 1.2, ly * ancho, r * 0.45), _m(mat, p), 0, 'placa%d' % (i % 2), h)
        if 1 < i < n - 2 and i % 2 == 1:
            en_suelo = pts[i][2] < radios[i] + 1.5 and not enrollado
            l = (lp if en_suelo else lp * 0.45) * (1.0 - 0.6 * p['enrosca'])
            for s in (-1, 1):
                g = 2 * math.pi * (p['fase'] * 2.0 + i * 0.30) + (0.0 if s > 0 else math.pi)
                fase = math.sin(g) * 1.3 * p['paso']
                alto = max(0.0, math.cos(g)) * p['paso']
                rod = V((s * (r + l * 0.48), fase * 0.5, 0.6 + alto * 0.5))
                pie = V((s * (r + l), fase, (-1.5 if en_suelo else -0.5) + alto))
                _cono(add, V((s * r * 0.8, 0, 0)), rod, 0.78 * gp, 0.66 * gp, _m('pata', p), 0, 'pata', h)
                _cono(add, rod, pie, 0.66 * gp, 0.35, _m('pata', p), 0, 'pata', h)
    if cab_a > 0 and (not mitad or delante is None or delante[0] == (mitad == 2)):
        _cabeza(add, 'cabA', _m('cabA', p), C['tam'] * cab_a, p)
    if cab_b > 0 and (not mitad or delante is None or delante[n - 1] == (mitad == 2)):
        _cabeza(add, 'cabB', _m('cabB', p), C['tam'] * cab_b, p)
    return e.L


# LO QUE ENROSCA: la mitad del cuerpo en helice, con UNA cabeza arriba y delante.
# Helice + lo libre = el cuerpo entero. En el Nudo, justo la mitad: al atrapar a dos, las dos helices son TODO su cuerpo.
N_HELICE = 11 if VAR == 'bicefalo' else N // 2
HELICE_R = 5.0 if VAR == 'bicefalo' else 7.0
HELICE_ALTO = 14.3 if VAR == 'bicefalo' else 20.0
# Mas de UNA vuelta entera: con menos, casi todo el cuerpo se queda por detras de la presa y no se ve que la abraza.
HELICE_PASO = 0.82 if VAR == 'bicefalo' else 0.42


def _pieza_helice(p):
    pts = []
    del_ = []
    for i in range(N_HELICE):
        f = i / (N_HELICE - 1)
        a = math.pi * 0.2 - i * HELICE_PASO + p['gira'] * 2 * math.pi
        pts.append(V((math.cos(a) * HELICE_R * p['aprieta'], math.sin(a) * HELICE_R * p['aprieta'],
                      1.5 + HELICE_ALTO * p['sube_h'] * (1.0 - f))))
        del_.append(math.sin(a) > 0.0)
    pts = np.array(pts)
    r = np.full(N_HELICE, C['r'])
    # La helice de la cabeza B es la segunda presa: la misma pieza con la otra cabeza.
    if p['cab'] == 'A':
        return _construir(pts, r, p, 1.0, 0.0, del_)
    return _construir(pts[::-1], r, p, 0.0, 1.0, del_[::-1])


# LO QUE NO ENROSCA: sale de la base de la helice y sigue atacando a otro con la cabeza B.
N_LIBRE = N - N_HELICE


def _pieza_libre(p):
    # Lo que mide esa parte del cuerpo: en el Nudo son la mitad de sus anillos, y en poco sitio salian apelotonados.
    k = 1.0 if VAR == 'bicefalo' else 2.1
    z = 1.5 if VAR == 'bicefalo' else C['r'] * 0.8
    ctrl = [(0.0, 1.5, z), (-1.6 * k, 5.0 * k, z), (0.8 * k, 9.0 * k, z), (0.0, 13.0 * k, z)]
    pts = _muestras(ctrl, N_LIBRE)
    r = np.full(N_LIBRE, C['r'])
    t = np.gradient(pts, axis=0)
    n = np.stack([-t[:, 1], t[:, 0]], axis=1)
    n = n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-4)
    for i in range(N_LIBRE):
        f = i / (N_LIBRE - 1)
        pts[i, :2] += n[i] * p['onda'] * 1.0 * f * math.sin(2 * math.pi * (p['fase'] + i * 0.16))
        pts[i] += V((0.0, p['avB'], p['altoB'])) * f * f
    return _construir(pts, r, p, 0.0, 1.0)


def escena(p):
    if p['pieza'] == 'helice':
        return _pieza_helice(p)
    if p['pieza'] == 'libre':
        return _pieza_libre(p)
    cab_b = 1.0
    if p['desde'] == 'normal':
        # La segunda cabeza NACE en la cola.
        cab_b = max(0.0, (p['evo'] - 0.15) / 0.85)
    return _construir(_traza(p), _radios(p), p, 1.0, cab_b)


# ------------------------------------------------------------
#  ANIMACIONES
# ------------------------------------------------------------
def _paso(x, a, b):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


K = 1.0 if VAR == 'bicefalo' else 1.5     # lo gordo que es cada gesto


def a_idle(t):
    # Las dos cabezas tantean por turnos: nunca estan quietas a la vez.
    s = math.sin(2 * math.pi * t)
    return POSE(fase=t, onda=0.3, paso=0.15, altoA=max(0.0, s) * 1.6 * K, altoB=max(0.0, -s) * 1.6 * K,
                ladoA=0.6 * s, ladoB=-0.6 * s)


def a_walk(t):
    return POSE(fase=t, onda=0.9, paso=1.0, avA=0.8 * math.sin(2 * math.pi * t) * K, avB=-0.8 * math.sin(2 * math.pi * t) * K)


def a_basico(t):
    # EL BASICO EN U (su peticion): muerde la cabeza A y el cuerpo se gira para que la B muerda AL MISMO. Las dos van al
    # centro, que es donde esta el objetivo: la A toca en 0,31 y la B en 0,69.
    lado = 5.2 if VAR == 'bicefalo' else 2.0
    return POSE(fase=t * 0.3, onda=0.25, paso=0.2,
                avA=tramos(t, [(0.0, 0.0), (0.15, -1.6), (0.31, 6.5), (0.5, 2.0), (1.0, 0.0)]) * K,
                altoA=tramos(t, [(0.0, 0.0), (0.15, 3.0), (0.31, 0.0), (1.0, 0.0)]),
                ladoA=tramos(t, [(0.0, 0.0), (0.15, 1.0), (0.31, lado), (0.5, 2.0), (1.0, 0.0)]),
                avB=tramos(t, [(0.0, 0.0), (0.45, -1.2), (0.69, 6.5), (0.85, 2.0), (1.0, 0.0)]) * K,
                altoB=tramos(t, [(0.0, 0.0), (0.45, 3.0), (0.69, 0.0), (1.0, 0.0)]),
                ladoB=tramos(t, [(0.0, 0.0), (0.45, 1.0), (0.69, lado), (0.85, 2.0), (1.0, 0.0)]))


def a_pinza(t):
    # LA PINZA: abre las dos cabezas hacia fuera y las cierra de golpe a la vez, cada una barriendo su mitad (toca en 0,5).
    lado = tramos(t, [(0.0, 0.0), (0.33, -3.6), (0.5, 5.6), (0.7, 4.2), (1.0, 0.0)])
    av = tramos(t, [(0.0, 0.0), (0.33, -1.0), (0.5, 7.0), (0.7, 5.0), (1.0, 0.0)]) * K
    return POSE(fase=t * 0.2, onda=0.2, paso=0.3, ladoA=lado, ladoB=lado, avA=av, avB=av,
                altoA=tramos(t, [(0.0, 0.0), (0.33, 2.2), (0.5, 0.0), (1.0, 0.0)]),
                altoB=tramos(t, [(0.0, 0.0), (0.33, 2.2), (0.5, 0.0), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.33, -1.0), (0.5, 2.5), (1.0, 0.0)]) * K)


def a_oleada(t):
    return POSE(fase=t * 0.5, onda=tramos(t, [(0.0, 0.6), (0.5, 1.5), (1.0, 0.6)]), paso=1.0,
                avance=tramos(t, [(0.0, 1.5), (0.5, 4.0), (1.0, 1.5)]) * K,
                avA=tramos(t, [(0.0, 0.0), (0.5, 2.0), (1.0, 0.0)]), avB=tramos(t, [(0.0, 0.0), (0.5, 2.0), (1.0, 0.0)]))


def a_enrosque(t):
    # Se lanza con la cabeza A y arrastra el cuerpo (al acabar, el combate pone las piezas de la helice).
    return POSE(fase=t * 1.3, onda=tramos(t, [(0.0, 0.5), (0.3, 0.9), (1.0, 0.3)]), paso=0.5,
                avA=tramos(t, [(0.0, 0.0), (0.2, -1.5), (0.5, 7.0), (1.0, 5.0)]) * K,
                altoA=tramos(t, [(0.0, 0.0), (0.2, 3.5), (0.5, 0.5), (1.0, 0.0)]),
                ladoA=tramos(t, [(0.0, 0.0), (0.5, 5.0), (1.0, 5.0)]) if VAR == 'bicefalo' else 0.0,
                avance=tramos(t, [(0.0, 0.0), (0.2, -1.0), (0.6, 4.0), (1.0, 4.5)]))


def a_encaje(t):
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.44), (0.67, 0.12), (1.0, 0.0)]) * 3.8, fase=0.35 * t,
                onda=tramos(t, [(0.0, 1.8), (0.34, 1.3), (0.67, 0.9), (1.0, 0.4)]), paso=0.3,
                altoA=tramos(t, [(0.0, 2.0), (1.0, 0.0)]), altoB=tramos(t, [(0.0, 2.0), (1.0, 0.0)]))


def a_muerte(t):
    # Las dos cabezas se yerguen una ultima vez, por turnos, y cada punta se enrolla hacia dentro.
    o = tramos(t, [(0.0, 1.0), (0.18, 0.85), (0.40, 0.45), (0.66, 0.6), (0.84, 0.12), (1.0, 0.0)])
    return POSE(fase=t * 1.6, onda=o, paso=o * 0.5,
                altoA=tramos(t, [(0.0, 0.0), (0.18, 3.0), (0.40, 0.5), (1.0, 0.0)]),
                altoB=tramos(t, [(0.0, 0.0), (0.30, 3.0), (0.55, 0.5), (1.0, 0.0)]),
                sube=tramos(t, [(0.0, 1.0), (0.5, 0.6), (1.0, 0.0)]) if VAR == 'nudo' else 1.0,
                enrosca=tramos(t, [(0.0, 0.0), (0.18, 0.1), (0.40, 0.5), (0.66, 0.72), (0.84, 0.96), (1.0, 1.0)]))


def a_comer(t):
    # Primero una cabeza y luego la otra: las dos quieren.
    baja = tramos(t, [(0.0, 0.0), (0.12, 1.0), (0.88, 1.0), (1.0, 0.0)])
    m = math.sin(2 * math.pi * t * 4.0)
    return POSE(fase=t * 0.3, onda=0.2, paso=0.1, avA=baja * (2.5 + max(0.0, m) * 2.0) * K, avB=baja * (2.5 + max(0.0, -m) * 2.0) * K,
                ladoA=baja * (3.0 if VAR == 'bicefalo' else 0.0), ladoB=baja * (3.0 if VAR == 'bicefalo' else 0.0))


def a_derrumbe_carga(t):
    # EL MONTON SE ALZA, cada vez mas alto y temblando, y las cabezas se echan atras (bucle mientras carga).
    s = math.sin(2 * math.pi * t)
    return POSE(fase=t, onda=0.25, paso=0.2, sube=1.55 + 0.06 * s, abre=0.92, avA=-3.0, altoA=2.5, avB=-3.0, altoB=2.0,
                vibra=0.25 * (1.0 if int(t * 8) % 2 == 0 else -1.0))


def a_derrumbe(t):
    # CAE ENTERO: se aplasta contra el suelo abriendose (toca en 0,29) y vuelve a recogerse.
    return POSE(fase=t * 0.3, onda=tramos(t, [(0.0, 0.25), (0.29, 0.9), (1.0, 0.3)]), paso=0.3,
                sube=tramos(t, [(0.0, 1.55), (0.14, 1.7), (0.29, 0.25), (0.5, 0.45), (1.0, 1.0)]),
                abre=tramos(t, [(0.0, 0.92), (0.14, 0.9), (0.29, 1.32), (0.5, 1.22), (1.0, 1.0)]),
                avA=tramos(t, [(0.0, -3.0), (0.29, 4.0), (1.0, 0.0)]), altoA=tramos(t, [(0.0, 2.5), (0.29, 0.0), (1.0, 0.0)]),
                avB=tramos(t, [(0.0, -3.0), (0.29, 4.0), (1.0, 0.0)]), altoB=tramos(t, [(0.0, 2.0), (0.29, -2.0), (1.0, 0.0)]))


def a_evolucion(t):
    # Tiembla siendo lo que era; y SIN CORTES: la forma, el grosor y el color cambian a la vez, poco a poco.
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.55, 0.72))
    return POSE(desde='normal' if VAR == 'bicefalo' else 'bicefalo', evo=_paso(t, 0.14, 0.82), tinte=_paso(t, 0.06, 0.78),
                fase=t * 1.2, onda=tramos(t, [(0.0, 0.5), (0.4, 1.1), (1.0, 0.4)]), paso=0.4, vibra=0.3 * tiembla,
                altoA=tramos(t, [(0.0, 0.0), (0.75, 0.0), (0.88, 3.5), (1.0, 0.0)]),
                altoB=tramos(t, [(0.0, 0.0), (0.82, 0.0), (0.92, 3.5), (1.0, 0.0)]))


def _h(sube, aprieta, gira, fase, paso, mitad, cab):
    return POSE(pieza='helice', cab=cab, onda=0.0, fase=fase, paso=paso, sube_h=sube, aprieta=aprieta, gira=gira, mitad=mitad)


def _piezas(m, cab):
    return {
        'enroscarse': lambda t: _h(t, 1.6 + (1.0 - 1.6) * t * t, 0.35 * (1.0 - t), t, 1.0 - t, m, cab),
        'enroscado': lambda t: _h(1.0, 1.0 + 0.05 * math.sin(2 * math.pi * t), 0.02 * math.sin(2 * math.pi * t), t, 0.6, m, cab),
        'apreton': lambda t: _h(1.0, tramos(t, [(0.0, 1.0), (0.3, 0.74), (0.5, 0.7), (0.75, 0.86), (1.0, 1.0)]), 0.0, t * 0.5, 0.3, m, cab),
        'desenroscarse': lambda t: _h(1.0 - t, 1.0 + 0.6 * t * t, -0.35 * t, t, t, m, cab),
    }


def a_libre_idle(t):
    return POSE(pieza='libre', fase=t, onda=0.5, paso=0.3, altoB=max(0.0, math.sin(2 * math.pi * t)) * 2.0 * K)


def a_libre_muerde(t):
    # La cabeza que queda libre sigue a lo suyo: se echa atras y muerde (toca en 0,4).
    return POSE(pieza='libre', fase=t * 0.3, onda=0.3, paso=0.3,
                # (el Nudo es largo: con su K se salia del lienzo, y ya llega de sobra)
                avB=tramos(t, [(0.0, 0.0), (0.2, -2.0), (0.4, 6.0), (0.7, 2.0), (1.0, 0.0)]) * (1.0 if VAR == 'bicefalo' else 0.6),
                altoB=tramos(t, [(0.0, 0.0), (0.2, 3.0), (0.4, 0.0), (1.0, 0.0)]))


# nombre: (fotogramas, fps, loop, direcciones, funcion)
ANIMS = {
    'idle': (8, 4.0, True, 8, a_idle),
    'walk': (8, 10.0 if VAR == 'bicefalo' else 7.0, True, 8, a_walk),
    'basico': (8, 14.0, False, 8, a_basico),
    'pinza': (7, 14.0, False, 8, a_pinza),
    'oleada': (6, 18.0, False, 8, a_oleada),
    'enrosque': (8, 11.0, False, 8, a_enrosque),
    'libre_idle': (6, 8.0, True, 8, a_libre_idle),
    'libre_muerde': (6, 14.0, False, 8, a_libre_muerde),
    'encaje': (4, 18.0, False, 8, a_encaje),
    'muerte': (8, 10.0, False, 8, a_muerte),
    'comer': (10, 10.0, False, 8, a_comer),
    'evolucion': (18, 10.0, False, 8, a_evolucion),
}
if VAR == 'nudo':
    ANIMS['derrumbe_carga'] = (8, 10.0, True, 8, a_derrumbe_carga)
    ANIMS['derrumbe'] = (7, 12.0, False, 8, a_derrumbe)
for _cab, _suf0 in (('A', ''),) + ((('B', '_b'),) if VAR == 'nudo' else ()):
    for _mit, _suf in ((1, '_detras'), (2, '_delante')):
        _e = _piezas(_mit, _cab)
        ANIMS['enroscarse' + _suf0 + _suf] = (6, 12.0, False, 1, _e['enroscarse'])
        ANIMS['enroscado' + _suf0 + _suf] = (8, 8.0, True, 1, _e['enroscado'])
        ANIMS['apreton' + _suf0 + _suf] = (5, 14.0, False, 1, _e['apreton'])
        ANIMS['desenroscarse' + _suf0 + _suf] = (6, 12.0, False, 1, _e['desenroscarse'])


# ------------------------------------------------------------
#  LA HOJA PARA MIRARLA (sin tocar assets: se hornea tras su visto bueno)
# ------------------------------------------------------------
def _dibuja(tr):
    getattr(__import__('sdf_comun'), '_prioridad_baja', lambda: None)()
    nombre, d, i = tr
    n, _fps, loop, _dirs, fn = ANIMS[nombre]
    t = i / n if loop else i / max(1, n - 1)
    return (nombre, d, i, render(MODELO, escena(fn(t)), d))


def _hoja(var, nombres):
    from multiprocessing import Pool
    from PIL import Image, ImageDraw
    DIRS = (1, 4)     # SE de frente y N de espaldas
    pedidas = nombres or list(ANIMS.keys())
    trabajos = []
    for nm in pedidas:
        for d in (DIRS if ANIMS[nm][3] > 1 else (0,)):
            trabajos += [(nm, d, i) for i in range(ANIMS[nm][0])]
    with Pool(int(os.environ.get('PROCESOS', 0)) or 3) as pool:
        hechos = pool.map(_dibuja, trabajos, chunksize=4)
    fotos = {(a, b, c): im for a, b, c, im in hechos}
    W, H = MODELO.W, MODELO.H
    ESC = 3
    filas = []
    # Las piezas del enrosque, montadas como en la pelea: lo de detras, la presa (azul) y lo de delante.
    hechas = set()
    for nm in pedidas:
        if nm in hechas:
            continue
        if nm.endswith('_detras') and nm.replace('_detras', '_delante') in pedidas:
            otro = nm.replace('_detras', '_delante')
            hechas.update((nm, otro))
            k = ANIMS[nm][0]
            tira = []
            for i in range(k):
                im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                a = fotos[(nm, 0, i)]
                im.paste(a, (0, 0), a)
                dib = ImageDraw.Draw(im)
                cx, cy = MODELO.OX, MODELO.OY
                dib.rounded_rectangle((cx - 11, cy - 38, cx + 11, cy + 2), 9, fill=(90, 140, 230, 255), outline=(20, 30, 70, 255))
                b = fotos[(otro, 0, i)]
                im.paste(b, (0, 0), b)
                # Lo que no enrosca tambien esta ahi: si no, en la hoja parece que el bicho ha encogido.
                if nm.startswith('enroscado') and '_b' not in nm and ('libre_idle', 1, 0) in fotos:
                    li = fotos[('libre_idle', 1, i % ANIMS['libre_idle'][0])]
                    im.paste(li, (0, 0), li)
                tira.append(im)
            filas.append((nm.replace('_detras', ''), tira))
        else:
            hechas.add(nm)
            for d in (DIRS if ANIMS[nm][3] > 1 else (0,)):
                filas.append(('%s d%d' % (nm, d), [fotos[(nm, d, i)] for i in range(ANIMS[nm][0])]))
    recortes = []
    for nombre, tira in filas:
        cajas = [f.getbbox() for f in tira if f.getbbox()]
        c = (min(x[0] for x in cajas) - 2, min(x[1] for x in cajas) - 2, max(x[2] for x in cajas) + 2, max(x[3] for x in cajas) + 2)
        recortes.append((nombre, tira, c))
    ancho = 150 + max((c[2] - c[0]) * ESC * len(tira) for _, tira, c in recortes)
    alto = sum((c[3] - c[1]) * ESC + 6 for _, _, c in recortes)
    hoja = Image.new('RGB', (ancho, alto), (40, 42, 50))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, tira, c in recortes:
        cw, ch = c[2] - c[0], c[3] - c[1]
        dib.text((6, y + ch * ESC // 2), nombre, fill=(235, 235, 235))
        for i, f in enumerate(tira):
            r = f.crop(c).resize((cw * ESC, ch * ESC), Image.NEAREST)
            hoja.paste(r, (150 + i * cw * ESC, y), r)
        y += ch * ESC + 6
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    os.makedirs(VISTAS, exist_ok=True)
    ruta = os.path.join(esc, 'ciempies_%s_hoja.png' % var)
    hoja.save(ruta)
    hoja.save(VISTAS + 'ciempies_%s_hoja.png' % var)
    print(ruta, hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        assert args[1] == VAR, 'pon CIEM_VAR=%s' % args[1]
        _hoja(args[1], args[2:])
    else:
        hornear('ciempies_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
