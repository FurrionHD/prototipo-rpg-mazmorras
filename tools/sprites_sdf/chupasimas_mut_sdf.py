# ============================================================
#  chupasimas_mut_sdf.py -- LOS MUTANTES DE LA CHUPASIMAS, con sus animaciones (17/11/2026, chupasimas-mutante).
#  Los cuerpos son los elegidos en chupasimas_mutantes_versiones.py:
#    CHUPA_VAR=coagulo         COAGULO sin costra (A: casi la normal, algo mas llena y oscura, restos de postilla)
#    CHUPA_VAR=coagulo_costra  COAGULO con la costra puesta (B: postillas grandes agrietadas, la carne asoma)
#    CHUPA_VAR=vidriada        SANGUIJUELA VIDRIADA (A: cadena de prismas de cristal en rombo, mana dentro)
#    CHUPA_VAR=madre           MADRE DE LAS SIMAS sin costra (B: octogono granate de cristal, mana dentro)
#    CHUPA_VAR=madre_costra    MADRE con la costra puesta (postillas en la cara de arriba)
#  LAS ANIMACIONES son las de la normal (chupasimas_sdf: sus poses y sus tiempos, para que lo aprobado siga cayendo igual)
#  con el cuerpo nuevo, y dos de cero (su decision, 17/11):
#    sorbo   (vidriada) salta, muerde, bebe y vuelve a su sitio: no se queda pegada
#    rayo    (vidriada y madre) se alza, el mana de dentro engorda (carga) y lo suelta por la boca de golpe
#  La vidriada no se pega, asi que no lleva adherirse/adherido.
#  Uso: CHUPA_VAR=coagulo python tools/sprites_sdf/chupasimas_mut_sdf.py [anim ...] -> assets/sprites/enemigos/chupasimas_sdf_<var>/
#       python tools/sprites_sdf/chupasimas_mut_sdf.py hoja coagulo [anim ...] -> la hoja para mirarla, al escritorio
#       (la hoja no toca assets: se hornea tras su visto bueno. PROCESOS=n, 3 por defecto)
# ============================================================
import sys, os, math, random
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import chupasimas_sdf as base
import chupasimas_mutantes_versiones as vers

VAR = os.environ.get('CHUPA_VAR', 'coagulo')
VARS = ('coagulo', 'coagulo_costra', 'vidriada', 'madre', 'madre_costra')
assert VAR in VARS, 'CHUPA_VAR tiene que ser una de %s' % (VARS,)
SALIDA = 'assets/sprites/enemigos/chupasimas_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/'
V = np.array

# LA TRANSICION DE COLOR de la evolucion (memoria transiciones-de-color): sin saltos, con materiales intermedios. Cada
# pareja (de, a) lleva PASOS tonos de mezcla: 'mix_de_a_k'. Los de cristal son translucidos tambien a medias.
PASOS = 6
MEZCLAS = [('piel', 'piel_c'), ('piel', 'vidrio'), ('vidrio', 'vidrio_g'), ('piel_c', 'vidrio_g')]


def _mezcla_mat(a, b, f):
    ta, tb = vers.MAT[a], vers.MAT[b]
    n = min(len(ta), len(tb))
    return [tuple(ta[i][c] + (tb[i][c] - ta[i][c]) * f for c in range(3)) for i in range(n)]


for _a, _b in MEZCLAS:
    for _k in range(PASOS + 1):
        vers.MAT['mix_%s_%s_%d' % (_a, _b, _k)] = _mezcla_mat(_a, _b, _k / PASOS)
# Translucido si ES cristal: de cristal a cristal desde el primer paso (si no, el paso 0 salia opaco y en BLANCO), y de
# carne a cristal en cuanto empieza a serlo.
_VIDRIOS = ('vidrio', 'vidrio_g')
_TRANSLUCIDOS_MIX = tuple('mix_%s_%s_%d' % (a, b, k) for a, b in MEZCLAS for k in range(PASOS + 1)
                          if a in _VIDRIOS or (b in _VIDRIOS and k > 0))
vers.TRANSLUCIDOS = vers.TRANSLUCIDOS + _TRANSLUCIDOS_MIX


def mix(a, b, f):
    """El material de la mezcla de 'a' a 'b' en 'f' (0..1)."""
    return 'mix_%s_%s_%d' % (a, b, int(round(max(0.0, min(1.0, f)) * PASOS)))


MODELO = vers.modelo()
MODELO.especular = tuple(MODELO.especular) + tuple(n for n in vers.MAT if n.startswith('mix_'))
# Lo que cambia de cada cuerpo: largo y grosor (los de la lamina elegida).
FORMA = {
    'normal': (1.0, 1.0),
    'coagulo': (1.0, 1.12), 'coagulo_costra': (1.0, 1.12),
    'vidriada': (1.0, 1.30),
    'madre': (1.05, 1.40), 'madre_costra': (1.05, 1.40),
}
KL, KR = FORMA[VAR]
CRISTAL = VAR in ('vidriada', 'madre', 'madre_costra')
SALTO_ALTO = 5.0     # lo que sube el sorbo en el aire
SORBO_DIST = 7.0     # lo que se lanza hacia delante


def POSE(**k):
    p = base.POSE()
    # kl/kr: el largo y el grosor de ESTE fotograma (la evolucion los lleva de un cuerpo al otro); None = los suyos.
    p.update(salto=0.0, carga=0.0, kl=None, kr=None, evo=-1.0, desde='normal', tiembla=0.0)
    p.update(k)
    return p


# ------------------------------------------------------------
#  EL CUERPO CON POSE (la traza de la normal, estirada y engordada como en la lamina)
# ------------------------------------------------------------
def _k(p):
    return (KL if p.get('kl') is None else p['kl']), (KR if p.get('kr') is None else p['kr'])


def _ra(u, p):
    return base._radio(u, p) * _k(p)[1]


def _tr(u, p):
    q = base._traza(u, p)
    kl, kr = _k(p)
    x = q[0] + p.get('tiembla', 0.0) * 0.5
    return V((x, q[1] * kl, q[2] + (kr - 1.0) * base._radio(u, p) + p['salto'] * SALTO_ALTO))


def _marco(u, p):
    a = _tr(min(u + 0.01, 1.0), p)
    b = _tr(max(u - 0.01, 0.0), p)
    d = a - b; d /= np.linalg.norm(d)
    lado = np.cross(d, V((0.0, 0.0, 1.0))); lado /= max(np.linalg.norm(lado), 1e-6)
    arriba = np.cross(lado, d)
    return d, lado, arriba


def _boca(add, p, mat, cen, d, k):
    """La ventosa con sus ocho dientes; 'boca' la abre (como la normal)."""
    b = p['boca']
    base._elip(add, cen + d * (1.3 + 0.4 * b) * k, ((1.3 + 0.7 * b) * k,) * 3, 'boca', 0, 'boca')
    a1 = np.cross(d, V((0.0, 0.0, 1.0))); a1 /= max(np.linalg.norm(a1), 1e-6); a2 = np.cross(d, a1)
    ab = 1.0 + 0.55 * b
    for i in range(8):
        ang = i / 8 * 2 * math.pi
        rr = a1 * math.cos(ang) + a2 * math.sin(ang)
        base._cono(add, cen + d * (1.4 + 0.4 * b) * k + rr * 1.3 * ab * k, cen + d * (1.1 + 0.4 * b) * k + rr * 0.6 * ab * k,
                   0.3, 0.12, 'diente', 0, 'diente')


def cuerpo_blando(add, p, piel, anillos=True):
    N = base.N
    us = [i / (N - 1) for i in range(N)]
    pts = [_tr(u, p) for u in us]
    for i in range(N - 1):
        base._cono(add, pts[i], pts[i + 1], _ra(us[i], p), _ra(us[i + 1], p), piel, 0.8)
    if anillos:
        # LA ANILLACION, en la GRAFICA (memoria horno-sprites-a-gpu: una pieza que cae a 'raro' va a la CPU y frena el
        # horno; se le enseña a la grafica antes de hornear). Cada aro es el TORO de la grafica (sd_toro_y, en el plano
        # XZ alrededor de su Y) dentro de un HUESO propio girado para que su Y mire a lo largo del cuerpo ('d'): la misma
        # cuenta que el aro a mano de la normal (radio r, grosor 0,32).
        X = add.__self__.X
        for k in range(2, 17):
            u = k / 18
            c = _tr(u, p)
            d, lado, arriba = _marco(u, p)
            r = _ra(u, p) + 0.12
            nombre = 'aro%d' % k
            X[nombre] = (np.stack([lado, d, arriba], axis=1), c)
            add(lambda P, r=r: sd_toro_y(P, V((0.0, 0.0, 0.0)), r, 0.32), 'anillo', 0, 'anillo', nombre)
    kr = _k(p)[1]
    d = pts[-1] - pts[-2]; d /= np.linalg.norm(d)
    cen = pts[-1] + d * 0.6
    base._elip(add, cen, ((1.9 + 0.6 * p['boca']) * kr,) * 3, piel, 0.5)
    _boca(add, p, piel, cen, d, kr)
    dc = pts[0] - pts[1]; dc /= np.linalg.norm(dc)
    base._elip(add, pts[0] + dc * 0.6 + V((0, 0, -0.6)), (2.2 * kr, 2.2 * kr, 0.8), piel, 0.6)


def cuerpo_cristal(add, p, mat, talla, ancho=0.95, nucleo_mat=None, k_nuc=0.36, tramos=7, crece=1.0, octo=None):
    """La cadena de prismas de la lamina, con pose. 'carga' (el rayo) ENGORDA el nucleo: el mana se ve llenarse.
    LA EVOLUCION: 'crece' (0..1) hace salir el cristal desde nada; 'octo' (0..1) talla el rombo en octogono (la segunda
    caja, la recta, va saliendo). Sin 'octo', lo que diga la talla."""
    if crece < 0.04:
        return
    if octo is None:
        octo = 1.0 if talla == 'octo' else 0.0
    kr = _k(p)[1]
    k_nuc = k_nuc * (1.0 + 0.55 * p['carga'])
    lado_k = 0.82 + 0.04 * octo
    for i in range(tramos):
        u0 = 0.04 + 0.90 * i / tramos
        u1 = 0.04 + 0.90 * (i + 1) / tramos
        um = 0.5 * (u0 + u1)
        a = _tr(u0, p); b = _tr(u1, p)
        c = 0.5 * (a + b)
        d, lado, arriba = _marco(um, p)
        medio_l = (0.5 * np.linalg.norm(b - a) + 0.15) * (0.4 + 0.6 * crece)
        r = _ra(um, p) * ancho * crece
        vers._caja(add, c, vers._ejes(d, lado, arriba, math.pi / 4), (medio_l, r * lado_k, r * lado_k), mat, 'cristal')
        if octo > 0.04:
            vers._caja(add, c, vers._ejes(d, lado, arriba, 0.0), (medio_l, r * lado_k * octo, r * lado_k * octo), mat,
                       'cristal')
        if nucleo_mat and crece > 0.5:
            kn = k_nuc * (crece - 0.5) / 0.5
            vers._caja(add, c, vers._ejes(d, lado, arriba, math.pi / 4), (max(0.3, medio_l - 0.35), r * kn, r * kn),
                       nucleo_mat, 'nucleo', 0.1)
    ub = 0.97
    cb = _tr(ub, p)
    d, lado, arriba = _marco(ub, p)
    rb = 1.9 * kr * 0.85 * crece
    vers._caja(add, cb, vers._ejes(d, lado, arriba, math.pi / 8), (1.1 * crece, rb, rb), mat, 'cristal')
    if crece > 0.6:
        _boca(add, p, mat, cb - d * 0.1 * kr, d, kr * 0.9)
    cc = _tr(0.0, p)
    d, lado, arriba = _marco(0.02, p)
    vers._caja(add, cc - d * 0.8 + V((0, 0, -0.5)), vers._ejes(d, lado, V((0.0, 0.0, 1.0)), 0.0),
               (1.4 * crece, 2.0 * kr * 0.8 * crece, 0.7), mat, 'cristal')


def postillas(add, p, desde, hasta, n_largo, n_vuelta, tam, abre, semilla, levanta=0.0, prob=1.0, vuelta=1.6, k_sup=1.0):
    """Las de la lamina, con pose: la MISMA semilla en cada fotograma, asi que no bailan de sitio."""
    rnd = random.Random(semilla)
    for i in range(n_largo):
        u = desde + (hasta - desde) * (i + 0.5) / n_largo
        d, lado, arriba = _marco(u, p)
        r = _ra(u, p) * k_sup
        c0 = _tr(u, p)
        for j in range(n_vuelta):
            sale = rnd.random()
            ang = (j + 0.5) / n_vuelta * vuelta - vuelta / 2 + rnd.uniform(-0.12, 0.12)
            lev = rnd.uniform(0.0, 0.5); dd = rnd.uniform(-0.3, 0.3)
            f_l = rnd.uniform(0.8, 1.15); f_a = rnd.uniform(0.8, 1.1)
            if sale > prob:
                continue
            nrm = arriba * math.cos(ang) + lado * math.sin(ang)
            tang = np.cross(nrm, d); tang /= max(np.linalg.norm(tang), 1e-6)
            c = c0 + nrm * (r + 0.05 + levanta * lev) + d * dd
            M = np.stack([d, tang, nrm], axis=1)
            add(lambda P, c=c, M=M, rad=V((tam * f_l * (1 - abre), tam * 0.85 * f_a * (1 - abre), 0.42)):
                sd_elipsoide_girado(P, c, M, rad), 'costra', 0, 'costra')
            add(lambda P, c=c - nrm * 0.25, M=M, rad=V((tam * 0.95, tam * 0.8, 0.22)): sd_elipsoide_girado(P, c, M, rad),
                'carne', 0, 'carne')


def _mezcla(a, b, f):
    return a + (b - a) * max(0.0, min(1.0, f))


def _escena_evolucion(p):
    """LA EVOLUCION, sin cortes: la forma, el grosor y el color van a la vez y poco a poco. 'evo' 0..1 = cuanto le falta
    para ser lo nuevo; 'desde' = de donde viene."""
    e = Escena(base.huesos(p)); add = e.add
    ev = p['evo']
    kl0, kr0 = FORMA[p['desde']]
    pf = dict(p)
    pf['kl'] = _mezcla(kl0, KL, ev)
    if VAR == 'coagulo':
        # ENGORDA Y SE OSCURECE, y le salen los restos de postilla.
        pf['kr'] = _mezcla(kr0, KR, ev)
        cuerpo_blando(add, pf, mix('piel', 'piel_c', p['tinte']))
        if ev > 0.5:
            postillas(add, pf, 0.25, 0.75, 4, 3, 0.9 * (ev - 0.5) / 0.5, 0.0, 7, prob=0.35)
    elif VAR == 'vidriada' or (VAR == 'madre' and p['desde'] == 'coagulo'):
        # EL CRISTAL LE CRECE POR FUERA: el cuerpo blando se va tiñendo del color del vidrio y encoge dentro, y el
        # cristal sale de el hasta su tamaño. Al final solo queda el cristal (con el mana).
        piel0 = 'piel' if VAR == 'vidriada' else 'piel_c'
        vidrio = 'vidrio' if VAR == 'vidriada' else 'vidrio_g'
        crece = max(0.0, (ev - 0.15) / 0.85)
        pb = dict(pf); pb['kr'] = kr0 * (1.0 - 0.45 * ev)
        if ev < 0.92:
            cuerpo_blando(add, pb, mix(piel0, vidrio, p['tinte'] * 0.7), anillos=ev < 0.5)
        pc = dict(pf); pc['kr'] = KR
        cuerpo_cristal(add, pc, vidrio, 'diamante' if VAR == 'vidriada' else 'octo', nucleo_mat='mana',
                       k_nuc=0.36 if VAR == 'vidriada' else 0.34, crece=crece)
    else:
        # MADRE DESDE LA VIDRIADA: el rombo se talla en octogono y el cristal pasa a granate.
        pf['kr'] = _mezcla(kr0, KR, ev)
        cuerpo_cristal(add, pf, mix('vidrio', 'vidrio_g', p['tinte']), 'octo', nucleo_mat='mana', k_nuc=0.34, octo=ev)
    return e.L


def escena(p):
    if p.get('evo', -1.0) >= 0.0:
        return _escena_evolucion(p)
    e = Escena(base.huesos(p)); add = e.add
    if CRISTAL:
        # EL CRISTAL NO SE HINCHA (la carcasa es dura): lo que se llena al beber es el MANA de dentro. El 'hincha' de las
        # poses de la normal (drenaje, adherido, sorbo) pasa a 'carga', que engorda el nucleo.
        p = dict(p)
        p['carga'] = max(p['carga'], p['hincha'])
        p['hincha'] = 0.0
    if VAR == 'coagulo':
        cuerpo_blando(add, p, 'piel_c')
        postillas(add, p, 0.25, 0.75, 4, 3, 0.9, 0.0, 7, prob=0.35)
    elif VAR == 'coagulo_costra':
        cuerpo_blando(add, p, 'piel_c', anillos=False)
        postillas(add, p, 0.10, 0.86, 7, 5, 1.55, 0.14, 11, levanta=0.25, vuelta=2.4)
    elif VAR == 'vidriada':
        cuerpo_cristal(add, p, 'vidrio', 'diamante', nucleo_mat='mana', k_nuc=0.36)
    else:
        cuerpo_cristal(add, p, 'vidrio_g', 'octo', nucleo_mat='mana', k_nuc=0.34)
        if VAR == 'madre_costra':
            postillas(add, p, 0.14, 0.62, 5, 3, 1.3, 0.14, 41, levanta=0.2, vuelta=1.2, k_sup=0.80)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES: las de la normal con este cuerpo, y las dos nuevas
# ------------------------------------------------------------
def _de_base(fn):
    return lambda t: POSE(**fn(t))


def a_sorbo(t):
    # SALTA, MUERDE, BEBE Y VUELVE: se encoge, sale en arco con la boca abriendose, clava (se hincha bebiendo) y
    # vuelve de un bote hacia atras a su sitio. No se queda pegada (eso es del Coagulo).
    return POSE(arco=tramos(t, [(0.0, 0.0), (0.15, 0.7), (0.30, 0.1), (0.55, 0.2), (0.75, 0.5), (1.0, 0.0)]),
                salto=tramos(t, [(0.0, 0.0), (0.15, 0.0), (0.28, 1.0), (0.40, 0.15), (0.62, 0.15), (0.78, 0.6), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.15, -0.6), (0.40, SORBO_DIST), (0.62, SORBO_DIST), (0.85, 1.0), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.0), (0.22, 0.6), (0.38, 1.0), (0.45, 0.3), (0.62, 0.3), (0.75, 0.0), (1.0, 0.0)]),
                hincha=tramos(t, [(0.0, 0.0), (0.42, 0.0), (0.60, 0.7), (0.80, 0.5), (1.0, 0.3)]),
                alza=tramos(t, [(0.0, 0.0), (0.15, 0.5), (0.30, 0.3), (0.40, 0.0), (1.0, 0.0)]))


def a_rayo(t):
    # CARGA Y SUELTA: se alza, el mana de dentro engorda (carga), abre la boca de golpe y el retroceso la echa atras.
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.35, 1.0), (0.62, 1.0), (0.75, 0.6), (1.0, 0.0)]),
                carga=tramos(t, [(0.0, 0.0), (0.55, 1.0), (0.64, 1.0), (0.72, 0.0), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.0), (0.55, 0.2), (0.64, 1.0), (0.80, 0.8), (1.0, 0.1)]),
                avance=tramos(t, [(0.0, 0.0), (0.62, 0.0), (0.72, -2.2), (1.0, 0.0)]),
                arco=tramos(t, [(0.0, 0.0), (0.35, 0.35), (0.62, 0.45), (0.72, 0.1), (1.0, 0.0)]))


def _paso(x, a, b):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    u = (x - a) / (b - a)
    return u * u * (3 - 2 * u)


def a_comer(t):
    # COME CRISTALES: se alza, MUERDE tres veces (la boca se abre y se cierra) y se va llenando.
    mordisco = 0.5 - 0.5 * math.cos(2 * math.pi * 3 * _paso(t, 0.15, 0.85))
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.15, 0.7), (0.85, 0.7), (1.0, 0.0)]),
                boca=0.1 + 0.9 * mordisco * (1.0 - _paso(t, 0.85, 1.0)),
                arco=0.15 + 0.15 * mordisco,
                hincha=tramos(t, [(0.0, 0.0), (0.3, 0.2), (0.6, 0.45), (0.85, 0.6), (1.0, 0.25)]))


def _evolucion(desde):
    def fn(t):
        # TIEMBLA siendo lo que era, se encoge y se arquea; la forma y el color cambian a la vez, poco a poco.
        tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.6, 0.78))
        return POSE(desde=desde, evo=_paso(t, 0.14, 0.82), tinte=_paso(t, 0.06, 0.78), tiembla=tiembla,
                    arco=tramos(t, [(0.0, 0.0), (0.3, 0.6), (0.7, 0.4), (1.0, 0.0)]),
                    alza=tramos(t, [(0.0, 0.0), (0.75, 0.0), (0.88, 0.8), (1.0, 0.0)]),
                    boca=tramos(t, [(0.0, 0.0), (0.82, 0.0), (0.9, 1.0), (1.0, 0.1)]))
    return fn


ANIMS = {}
for _nm, (_n, _fps, _loop, _dirs, _fn) in base.ANIMS.items():
    if VAR == 'vidriada' and _nm in ('adherirse', 'adherido'):
        continue
    ANIMS[_nm] = (_n, _fps, _loop, _dirs, _de_base(_fn))
if VAR == 'vidriada':
    ANIMS['sorbo'] = (10, 12.0, False, 8, a_sorbo)
if CRISTAL:
    ANIMS['rayo'] = (10, 11.0, False, 8, a_rayo)
# COMER Y EVOLUCION, solo en los cuerpos de verdad (las costras son un estado de la pelea, no se come ni se evoluciona
# con ellas puestas). La Madre lleva DOS: desde la Vidriada ('evolucion') y desde el Coagulo ('evolucion_coagulo').
if VAR in ('coagulo', 'vidriada', 'madre'):
    ANIMS['comer'] = (10, 10.0, False, 8, a_comer)
    ANIMS['evolucion'] = (18, 10.0, False, 8, _evolucion('vidriada' if VAR == 'madre' else 'normal'))
if VAR == 'madre':
    ANIMS['evolucion_coagulo'] = (18, 10.0, False, 8, _evolucion('coagulo'))


# ------------------------------------------------------------
#  LA HOJA PARA MIRARLA (sin tocar assets)
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
        for d in DIRS:
            trabajos += [(nm, d, i) for i in range(ANIMS[nm][0])]
    with Pool(int(os.environ.get('PROCESOS', 0)) or 3) as pool:
        hechos = pool.map(_dibuja, trabajos, chunksize=4)
    fotos = {(a, b, c): im for a, b, c, im in hechos}
    ESC = 3
    filas = []
    for nm in pedidas:
        for d in DIRS:
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
    ruta = os.path.join(esc, 'chupasimas_%s_hoja.png' % var)
    hoja.save(ruta)
    hoja.save(VISTAS + 'chupasimas_%s_hoja.png' % var)
    print(ruta, hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        assert args[1] == VAR, 'pon CHUPA_VAR=%s' % args[1]
        _hoja(args[1], args[2:])
    else:
        hornear('chupasimas_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
