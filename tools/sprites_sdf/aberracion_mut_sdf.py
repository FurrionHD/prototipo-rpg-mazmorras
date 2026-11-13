# ============================================================
#  aberracion_mut_sdf.py -- LOS MUTANTES DE LA ABERRACION (13/11/2026, memoria aberracion-mutante), ANIMADOS.
#    galvanica  MASA GALVANICA (rango 1): la R1 c de aberracion_medusa_versiones.py -- la forma de la base, translucida
#               (carne lechosa), con los NERVIOS cian a la vista (con nudos de luz) y anillos cian donde nacen los tentaculos.
#    tormenta   OJO DE LA TORMENTA (rango 2): la E a. VUELA de verdad: sus animaciones son todas nuevas (otro archivo de
#               claves, mas abajo, cuando toque).
#  La Masa usa el cuerpo y las CLAVES DE TIEMPO de aberracion_sdf.py (las del viejo) y las mismas anims que la base (el
#  jefe, 13/11): idle walk embestida basico encaje muerte + alarido (= su DESCARGA) + mirada (= su MIRADA CHISPEANTE).
#  Los nervios van pegados al cuerpo (escalan con el latido y el aplastarse, avanzan con el) y BRILLAN POR ESCALONES
#  ('luz' 0..5, uno por fotograma como mucho: memoria transiciones-de-color): laten en reposo, se encienden del todo en
#  la Descarga y se apagan al morir. La sombra NO va en el sprite (memoria sombras-fuera-del-sprite).
#  Uso: ABERRACION_MUT=galvanica python tools/sprites_sdf/aberracion_mut_sdf.py hoja [anim ...]
#         -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/aberracion_<mut>_hojas/ (para mirarla; no toca assets)
#       ... aberracion_mut_sdf.py [anim ...]   -> assets/sprites/enemigos/aberracion_sdf_<mut>/ (EL HORNO, tras su visto bueno)
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import aberracion_sdf as ab
import aberracion_medusa_versiones as amv

V = np.array
MUT = os.environ.get('ABERRACION_MUT', 'galvanica').lower()
_elip, _cono, _unit = ab._elip, ab._cono, ab._unit

# LA LUZ DE LOS NERVIOS: 0 (apagados, del color de la carne) .. 3 (normal, el cian de la lamina) .. 5 (a tope, casi
# blanco). Cada material que brilla tiene una copia por nivel ('nervio@4').
LUZ_NORMAL = 3
_APAGADO = (0.34, 0.22, 0.44)
_CIAN = (0.45, 0.95, 1.0)
_A_TOPE = (0.88, 1.0, 1.0)


def _nivel(c, k):
    """El tono del nivel k: de apagado a cian (0..3) y de cian a casi blanco (3..5)."""
    if k <= LUZ_NORMAL:
        u = k / LUZ_NORMAL
        return tuple(a + (b - a) * u for a, b in zip(_APAGADO, c))
    u = (k - LUZ_NORMAL) / (5 - LUZ_NORMAL)
    return tuple(a + (b - a) * u for a, b in zip(c, _A_TOPE))


MAT = dict(amv.MAT)
for _k in range(6):
    MAT['nervio@%d' % _k] = amv.tonos(_nivel(_CIAN, _k))[:3]
    MAT['nudo@%d' % _k] = amv.tonos(_nivel((0.80, 1.0, 1.0), _k))[:3]
    MAT['iris@%d' % _k] = amv.tonos(_nivel(_CIAN, _k))[:3]
_BRILLAN = tuple(m for m in MAT if m.startswith(('nervio@', 'nudo@', 'iris@'))) + ('pupila',)

# EL TAMAÑO: x1,2 de la base (1,80 -> 2,16; lienzo 102 -> 122, origen en el centro). Un mutante con sprite propio NO se
# estira el x1,2 de los mutantes (SpritesEnemigo.mutante_propio): tiene que venir ya grande.
MUT_GRANDE = 1.2
_LADO = int(round(102 * MUT_GRANDE / 2)) * 2
MODELO = Modelo(1.8 * MUT_GRANDE, (_LADO, _LADO), (_LADO // 2, _LADO // 2), MAT, (0.12, 0.04, 0.12), suaves=('cuerpo',), brillan=_BRILLAN,
                corta_suelo=True, especular=('carne', 'tent', 'globo', 'carne_t', 'tent_t'), umbral_especular=0.90,
                translucidos=('carne_t', 'tent_t'), alfa=0.45)
LIENZO = (MODELO.W, MODELO.H)
SALIDA = 'assets/sprites/enemigos/aberracion_sdf_%s/' % MUT
VISTAS = 'tools/salida/sdf/aberracion_%s/' % MUT


def POSE(**k):
    p = ab.POSE()
    p.update(luz=LUZ_NORMAL, chispas=0.0, t=0.0)
    p.update(k)
    return p


# ------------------------------------------------------------
#  LA MASA GALVANICA
# ------------------------------------------------------------
# Donde van los nervios, en las coordenadas de la base SIN deformar (las mismas que la R1 c de la lamina).
_CENTRO = (0.0, -0.4, 5.6)
_PUNTAS = [(4.4, -3.0, 8.4), (-4.8, 1.6, 7.0), (-0.8, -2.8, 10.6), (0.0, 3.6, 8.6)]


def _punto_tent(p, i, an, al, k_obj=3):
    """Donde pasa el tentaculo i en su tramo k_obj (la misma cuenta que aberracion_sdf._tentaculo, sin pintar): asi el
    anillo cian de su raiz va pegado al tentaculo aunque se levante para azotar."""
    ang = math.radians(30.0 + 60.0 * i + (7.0, -5.0, 9.0, -8.0, 4.0, -6.0)[i])
    fuera = V((math.sin(ang), math.cos(ang), 0.0))
    lado = V((fuera[1], -fuera[0], 0.0))
    az = p['azota'] * max(0.0, fuera[1])
    pt = V((0.0, 0.0, ab.TENT_NACE_Z * al)) + fuera * ab.TENT_NACE_R * an
    caida = min(1.45, 0.95 - az * 1.55)
    suelo = 0.0 if az <= 0.0 else -0.5 * az
    r0, r1 = 2.3, 1.0
    rr = r0
    enrosca = (0.9, -0.7, 0.8, -0.9, 0.7, -0.8)[i]
    n = ab.TENT_SEGMENTOS
    for k in range(k_obj + 1):
        u = k / (n - 1)
        caida = max(suelo, caida - 0.19) if k < n - 2 else min(caida, -0.22)
        onda = enrosca * u * u + 0.45 * math.sin(math.pi * p['onda'] + i * 1.9 + k * 0.7) * u
        d = _unit(fuera * math.cos(caida) + V((0.0, 0.0, -math.sin(caida))) + lado * onda)
        q = pt + d * ab.TENT_PASO
        q[2] = max(q[2], r1 * 0.9 + (rr - r1) * 0.55)
        rr = r0 + (r1 - r0) * min(1.0, (k + 1) / (n - 1))
        pt = q
    return pt, rr


def _escena_galvanica(pose):
    p = pose
    L = amv.recolorea(ab.escena(p), {'carne': 'carne_t', 'tent': 'tent_t', 'iris': 'iris@%d' % _luz_iris(p)})
    e = Escena(ab.huesos(p)); add = e.add
    an, al = ab._volumen(p)
    T = lambda c: V((c[0] * an, c[1] * an, c[2] * al))
    k = int(p['luz'])
    nerv, nudo = 'nervio@%d' % k, 'nudo@%d' % k
    # LOS NERVIOS: del centro a los lobulos, la joroba, detras del ojo y a la raiz de cada tentaculo, con un quiebro a
    # medio camino (el rayo no va recto) y un nudo de luz en cada quiebro (amv.nervios, con el material del nivel).
    raices = []
    for i in range(ab.TENTACULOS):
        q, _rr = _punto_tent(p, i, an, al, 1)
        raices.append(tuple(q))
    puntas = [tuple(T(c)) for c in _PUNTAS] + raices
    sub = Escena(ab.huesos(p))
    amv.nervios(sub.add, T(_CENTRO), puntas, nudos=True)
    for (fn, mat, g, kk, X, h) in sub.L:
        e.L.append((fn, {'nervio': nerv, 'nudo': nudo}.get(mat, mat), g, kk, X, h))
    # LOS ANILLOS cian donde el tentaculo toca el suelo (pegados a el).
    for i in range(ab.TENTACULOS):
        q, rr = _punto_tent(p, i, an, al, 3)
        _elip(add, q, (rr * 0.78, rr * 0.78, rr * 0.55), nerv, 0, 'nervio')
    # LAS CHISPAS DEL OJO (la Mirada chispeante): puntitos de luz delante del iris que saltan de sitio cada fotograma.
    if p['chispas'] > 0.01:
        oj = V((ab.OJO[0], ab.OJO[1] * an + 2.4, ab.OJO[2] * al))
        rng = np.random.default_rng(int(p['t'] * 997) + 7)
        for _j in range(int(3 + 6 * p['chispas'])):
            off = V((rng.uniform(-2.6, 2.6), rng.uniform(0.0, 1.2), rng.uniform(-2.4, 2.4))) * (0.6 + 0.6 * p['chispas'])
            _elip(add, oj + off, (0.32, 0.32, 0.32), 'nudo@5', 0, 'nervio')
    L.extend(e.L)
    return L


def _luz_iris(p):
    return int(min(5, max(0, round(p['luz'] + 1.5 * p['chispas']))))


def _con_luz(fn, claves=None, chispas=None, idle=False):
    """La anim de la base con la luz de los nervios encima: 'claves' = [(t, nivel)] (por tramos), 'idle' = late 2..4."""
    def g(t):
        p = POSE(**fn(t))
        p['t'] = t
        if idle:
            p['luz'] = LUZ_NORMAL + round(math.sin(2 * math.pi * t))
        elif claves:
            p['luz'] = int(round(tramos(t, claves)))
        if chispas:
            p['chispas'] = tramos(t, chispas)
        return p
    return g


if MUT == 'galvanica':
    escena = _escena_galvanica
    ANIMS = {}
    for nm, (n, fps, loop, d, fn) in ab.ANIMS.items():
        if nm == 'idle':
            g = _con_luz(fn, idle=True)
        elif nm == 'alarido':
            # LA DESCARGA: el gesto del Alarido (se encoge, se hincha, vibra) y los nervios suben de uno en uno hasta
            # encenderse TODOS en el golpe, y vuelven.
            g = _con_luz(fn, [(0.0, 3), (0.143, 3), (0.286, 4), (0.429, 5), (0.571, 5), (0.714, 4), (0.857, 3), (1.0, 3)])
        elif nm == 'mirada':
            # LA MIRADA CHISPEANTE: la de la base con el ojo lleno de chispas cuando se queda tiesa mirando.
            g = _con_luz(fn, [(0.0, 3), (0.286, 3), (0.429, 4), (0.857, 4), (1.0, 3)],
                         chispas=[(0.0, 0.0), (0.143, 0.0), (0.286, 0.6), (0.429, 1.0), (0.714, 1.0), (0.857, 0.4), (1.0, 0.0)])
        elif nm in ('embestida', 'basico'):
            # el golpe del tentaculo: un escalon mas al azotar
            g = _con_luz(fn, [(0.0, 3), (0.3, 3), (0.45, 4), (0.7, 4), (1.0, 3)])
        elif nm == 'encaje':
            g = _con_luz(fn, [(0.0, 4), (0.5, 3), (1.0, 3)])
        elif nm == 'muerte':
            # se apagan de uno en uno
            g = _con_luz(fn, [(0.0, 3), (0.3, 3), (0.5, 2), (0.7, 1), (0.9, 0), (1.0, 0)])
        else:
            g = _con_luz(fn)
        ANIMS[nm] = (n, fps, loop, d, g)
elif MUT != 'tormenta':
    raise SystemExit('ABERRACION_MUT=%s: galvanica o tormenta' % MUT)


# ------------------------------------------------------------
#  EL OJO DE LA TORMENTA (13/11): la E a de aberracion_medusa_versiones.py, ANIMADA DE CERO ("la forma se parece pero no
#  es igual: literal VUELA"). Anims marcadas por el jefe (memoria aberracion-mutante):
#    idle       late como medusa: se contrae y se expande, sube con cada latido y baja despacio; tentaculos con retraso
#    walk       avanza a latidos: inclinado hacia donde va, empujon al contraerse, planea; tentaculos de estela
#    basico     el Chispazo: el aro parpadea y salta la chispa, con un tiron de retroceso
#    rayo       Rayo del ojo: sube, el aro se cierra sobre la pupila y el disparo la empuja atras
#    ojo_carga  El ojo se abre, la carga (bucle): sube mas, tentaculos en abanico, el aro se enciende punto a punto
#    ojo        el estallido: baja de golpe con todo encendido
#    tentaculos Tentaculos que cuelgan: se tensan y restallan hacia abajo
#    encaje     sale despedida atras y arriba, se tambalea y se recoloca
#    muerte     los nervios se apagan uno a uno, cae girando, choca y se desinfla, el aro apagado
#    evolucion  desde la Masa galvanica: se hincha, se despega del suelo, los tentaculos pasan a colgar y se enciende el aro
#  EL CUERPO (la masa, el ojo, el aro, los nervios, la boca) va ENTERO en un hueso que sube, se inclina, retrocede y gira;
#  los TENTACULOS cuelgan de donde nacen con su propio movimiento (ondean, abanico, estela, tension) y, si el cuerpo
#  baja, se apoyan en el suelo. Sin sombra en el sprite (la pondra el juego).
# ------------------------------------------------------------
ALTURA = 20.0          # a la que flota (la F c3 aprobada)
AURO_N = 16            # puntos del aro del ojo
_ESC_TOR = 2.6         # la E a (x1,44 de la base)


def POSE_T(**k):
    p = dict(sube=0.0, latido=0.0, inclina=0.0, avance=0.0, gira=0.0, boca=0.6, desinfla=0.0, parpado=0.0,
             luz=LUZ_NORMAL, iris=4, aro=AURO_N, aro_luz=LUZ_NORMAL, aro_cierra=0.0, onda=0.0, abanico=0.0, estela=0.0,
             tension=0.0, escala=1.0, finos=1.0, alto=ALTURA, t=0.0)
    p.update(k)
    return p


def _rot(p):
    """El giro del cuerpo: guiñada (gira, al caer) y cabeceo (inclina: + = la cara hacia abajo, hacia donde va)."""
    a, g = p['inclina'], p['gira']
    cx, sx = math.cos(a), math.sin(a)
    rx_ = np.array([[1, 0, 0], [0, cx, sx], [0, -sx, cx]])
    cz, sz = math.cos(g), math.sin(g)
    rz_ = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]])
    return rz_ @ rx_


# (13/11, el jefe: "los tentaculos de la que vuela son lamentables, parecen planos y se fusionan entre si; mejor 6 como el
# original") SEIS, cada uno en SU GRUPO (contorno propio: no se funden entre si; los dos primeros tramos, en el del cuerpo,
# para que nazcan de la masa sin costura), mas abiertos hacia fuera (TENT_ABRE) y de un material que se elige para
# compararlo: TENT_MAT = tent (opacos, el de la base) o tent_t (translucidos).
TENT_MAT = os.environ.get('TENT_MAT', 'tent_ojo')
# (13/11, el jefe: "los translucidos, pero menos translucidos y mas marcado que es otra parte del cuerpo, parece plano") SU
# MATERIAL: morado mas intenso que la carne y con MAS CONTRASTE de sombra a luz (el volumen), y su propia opacidad
# (Modelo.alfa_mat), TENT_ALFA.
TENT_ALFA = float(os.environ.get('TENT_ALFA', '0.70'))   # (13/11, eligio la C: 0,70)
MAT['tent_ojo'] = [(0.22, 0.09, 0.32), (0.46, 0.24, 0.62), (0.66, 0.44, 0.82), (0.88, 0.74, 0.96)]
TENT_ABRE = 0.3
TENT_RAIZ = 5.4


def _tentaculo_ojo(add, nace, fuera, p, i, n, paso, r0, r1, punta=None):
    """Un tentaculo que CUELGA: cae casi recto y se curva al final. 'abanico' lo abre hacia fuera, 'estela' lo deja atras
    (contra donde va), 'onda' lo mece (cada uno en su fase, con retraso hacia la punta), 'tension' > 0 lo tensa recto hacia
    abajo (el azote) y < 0 lo recoge hacia arriba. Si llega al suelo, se tiende."""
    fuera = _unit(V((fuera[0], fuera[1], 0.0)))
    lado = V((fuera[1], -fuera[0], 0.0))
    atras = V((0.0, -1.0, 0.0))
    pt = V(nace, dtype=float); rr = r0
    enr = (0.9, -0.7, 0.8, -0.9, 0.7, -0.8, 0.6, -0.6)[i % 8]
    ten = p['tension']
    en_suelo = False      # una vez toca el suelo, se tiende (el grosor que lo apoya va menguando: no vale comparar alturas)
    for k in range(n):
        u = k / (n - 1)
        caida = 1.45 - (p['abanico'] + TENT_ABRE) * 0.75 * (1.0 - 0.5 * u)
        if ten > 0.0:
            caida = caida + (1.55 - caida) * ten
        elif ten < 0.0:
            caida = caida + ten * 1.6 * u          # recogido: la punta sube
        sway = (1.0 - max(ten, 0.0)) * (0.35 * math.sin(2 * math.pi * p['onda'] - u * 2.2 + i * 1.9) * u + enr * 0.25 * u * u)
        d = fuera * math.cos(caida) + V((0.0, 0.0, -math.sin(caida))) + lado * sway + atras * p['estela'] * 0.9 * u
        if en_suelo:
            d = fuera + lado * sway * 0.5     # en el suelo: se tiende
        d = _unit(d)
        q = pt + d * paso
        apoyo = r1 * 0.9 + (rr - r1) * 0.55
        if q[2] <= apoyo:
            q[2] = apoyo
            en_suelo = True
        rb = r0 + (r1 - r0) * min(1.0, (k + 1) / (n - 1))
        _cono(add, pt, q, rr, rb, TENT_MAT, 1.2 if k < 2 else 0.0, 'cuerpo' if k < 2 else 'tent%d' % i)
        pt = q; rr = rb
    if punta:
        _elip(add, pt, (r1 * 1.3,) * 3, punta, 0, 'nervio')


def _raices(r, z, nn, des, an, al):
    out = []
    for i in range(nn):
        a = math.radians(des + 360.0 / nn * i + (7.0, -5.0, 9.0, -8.0, 4.0, -6.0, 5.0, -7.0)[i % 8])
        f = (math.sin(a), math.cos(a))
        if f[1] > 0.93:
            continue      # ninguno justo delante (el ojo y las fauces)
        out.append((i, f, V((f[0] * r * an, f[1] * r * an, z * al))))
    return out


def _escena_tormenta(pose):
    p = pose
    # EL CUERPO, en sus coordenadas (la masa de la base sin tentaculos, la boca abierta), translucida.
    pal = (p['escala'] - 1.0) / 0.06 + 1.6 * p['latido']
    pb = ab.POSE(palpita=pal, boca=p['boca'], desinfla=p['desinfla'], parpado=p['parpado'],
                 aplasta=max(0.0, -0.35 * p['latido']))
    guardo = ab.TENTACULOS
    ab.TENTACULOS = 0
    try:
        Lc = ab.escena(pb)
    finally:
        ab.TENTACULOS = guardo
    Lc = amv.recolorea(Lc, {'carne': 'carne_t', 'tent': 'tent_t', 'iris': 'iris@%d' % int(p['iris'])})
    an, al = ab._volumen(pb)
    T = lambda c: V((c[0] * an, c[1] * an, c[2] * al))
    e = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))}); add = e.add
    k = int(p['luz'])
    oj = V((ab.OJO[0], ab.OJO[1] * an, ab.OJO[2] * al))
    # LOS NERVIOS, que nacen DEL OJO (el corazon de la tormenta), con nudos.
    puntas = [tuple(T(c)) for c in [(4.4, -3.0, 8.4), (-4.8, 1.6, 7.0), (-0.8, -2.8, 10.6), (2.6, -5.0, 6.0),
                                    (-3.6, -4.4, 9.0)]]
    puntas += [tuple(q) for (_i, _f, q) in _raices(4.2, 3.6, 8, 22.5, an, al)]
    sub = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))})
    amv.nervios(sub.add, oj - V((0.0, 2.6, 0.0)), puntas, nudos=True)
    for (fn, mat, g, kk, X, h) in sub.L:
        e.L.append((fn, {'nervio': 'nervio@%d' % k, 'nudo': 'nudo@%d' % k}.get(mat, mat), g, kk, X, h))
    # LA LUZ DE LA BOCA.
    bo = V((0.0, ab.BOCA[1] * an + 1.9, max(1.4, ab.BOCA[2] * al)))
    _elip(add, bo, (2.1, 0.7, 1.2 + 0.6 * p['boca']), 'nudo@%d' % min(5, k + 1), 0, 'nervio')
    # EL ARO: AURO_N cuentas en el plano de la cara, delante del globo; 'aro' = cuantas encendidas (de una en una, en
    # sentido horario desde arriba), 'aro_cierra' las junta sobre la pupila (el Rayo).
    rad = 3.9 * (1.0 - 0.62 * p['aro_cierra'])
    for j in range(AURO_N):
        a = math.pi * 0.5 - 2 * math.pi * j / AURO_N
        lit = j < int(round(p['aro']))
        mat = 'nervio@%d' % (int(p['aro_luz']) if lit else 0)
        _elip(add, oj + V((rad * math.cos(a), 2.6 + 0.4 * p['aro_cierra'], rad * 0.97 * math.sin(a))), (0.55, 0.5, 0.55),
              mat, 0, 'nervio')
    # TODO EL CUERPO al hueso del vuelo: sube (altura + sube), avanza, se inclina y gira.
    M = _rot(p)
    tr = V((0.0, p['avance'], p['alto'] + p['sube']))
    L = Piezas([(fn, m, g, kk, (M, tr), 'vuelo') for (fn, m, g, kk, _X, _h) in list(Lc) + list(e.L)])
    L.sombras = []
    # LOS SEIS TENTACULOS, colgando de donde nacen (en el mundo), cada uno con su contorno.
    et = Escena({'raiz': (np.eye(3), V((0.0, 0.0, 0.0)))})
    for (i, f, q) in _raices(TENT_RAIZ, 3.4, 6, 30.0, an, al):
        _tentaculo_ojo(et.add, M @ q + tr, M @ V((f[0], f[1], 0.0)), p, i, 11, 1.2, 2.2, 0.8)
    # Los anillos cian donde nacen.
    for (i, f, q) in _raices(TENT_RAIZ, 1.6 / max(al, 0.2), 6, 30.0, an, al):
        _elip(et.add, M @ V((q[0], q[1], 1.6)) + tr, (1.4, 1.4, 0.7), 'nervio@%d' % k, 0, 'nervio')
    L.extend(et.L)
    return L


def _anim_t(claves):
    """Una anim del Ojo a partir de sus claves: {param: [(t, valor)]}. Los niveles de luz se redondean (escalones)."""
    def g(t):
        p = POSE_T(t=t)
        for k_, cl in claves.items():
            if callable(cl):
                p[k_] = cl(t)
            else:
                p[k_] = tramos(t, cl)
        for k_ in ('luz', 'iris', 'aro_luz'):
            p[k_] = int(round(p[k_]))
        return p
    return g


if MUT == 'tormenta':
    MODELO = Modelo(_ESC_TOR, (190, 190), (95, 95), MAT, (0.12, 0.04, 0.12), suaves=('cuerpo',), brillan=_BRILLAN,
                    corta_suelo=True, especular=('carne', 'tent', 'globo', 'carne_t', 'tent_t'), umbral_especular=0.90,
                    translucidos=('carne_t', 'tent_t', 'tent_ojo'), alfa=0.45)
    MODELO.alfa_mat = {'tent_ojo': TENT_ALFA}
    MODELO.especular = MODELO.especular + ('tent_ojo',)
    LIENZO = (MODELO.W, MODELO.H)
    escena = _escena_tormenta
    W = lambda f=1.0, ph=0.0: (lambda t: math.sin(2 * math.pi * (f * t + ph)))
    ANIMS = {
        # LATE COMO MEDUSA: contraer (latido -) = mas estrecha y alta; con cada latido sube un poco y baja despacio. Los
        # tentaculos ondean a la mitad y con retraso. Los nervios laten 2..4.
        'idle': (8, 6.0, True, 8, _anim_t({
            'latido': W(1.0), 'sube': lambda t: 1.2 * math.sin(2 * math.pi * t - 0.9), 'onda': lambda t: t,
            'luz': lambda t: 3 + math.sin(2 * math.pi * t), 'abanico': lambda t: 0.12 + 0.12 * math.sin(2 * math.pi * t - 1.4)})),
        # AVANZA A LATIDOS: inclinada, empujon al contraerse (avance +) y planea; tentaculos de estela.
        'walk': (8, 8.0, True, 8, _anim_t({
            'inclina': lambda t: 0.22, 'latido': W(1.0), 'avance': lambda t: 1.4 * math.sin(2 * math.pi * t + 0.6),
            'sube': lambda t: 0.8 * math.sin(2 * math.pi * t - 0.5), 'estela': lambda t: 0.55 + 0.25 * math.sin(2 * math.pi * t - 1.5),
            'onda': lambda t: 2 * t})),
        # EL CHISPAZO: el aro parpadea (3 -> 5 -> 3) y un tiron atras.
        'basico': (8, 14.0, False, 8, _anim_t({
            'aro_luz': [(0.0, 3), (0.2, 4), (0.35, 5), (0.5, 5), (0.7, 4), (1.0, 3)],
            'iris': [(0.0, 4), (0.35, 5), (0.6, 5), (1.0, 4)],
            'avance': [(0.0, 0.0), (0.2, 0.6), (0.4, -1.6), (0.7, -0.6), (1.0, 0.0)],
            'latido': [(0.0, 0.0), (0.3, -0.6), (0.45, 0.6), (1.0, 0.0)],
            'onda': lambda t: 0.3 * t})),
        # RAYO DEL OJO: sube, el aro se cierra sobre la pupila y se enciende; el disparo la empuja atras.
        'rayo': (10, 12.0, False, 8, _anim_t({
            'sube': [(0.0, 0.0), (0.35, 2.0), (0.55, 2.2), (0.8, 1.0), (1.0, 0.0)],
            'aro_cierra': [(0.0, 0.0), (0.4, 1.0), (0.6, 1.0), (0.8, 0.3), (1.0, 0.0)],
            'aro_luz': [(0.0, 3), (0.2, 4), (0.4, 5), (0.65, 5), (0.85, 4), (1.0, 3)],
            'iris': [(0.0, 4), (0.4, 5), (0.7, 5), (1.0, 4)],
            'avance': [(0.0, 0.0), (0.5, 0.4), (0.6, -3.0), (0.8, -1.4), (1.0, 0.0)],
            'inclina': [(0.0, 0.0), (0.5, 0.08), (0.6, -0.12), (1.0, 0.0)],
            'tension': [(0.0, 0.0), (0.55, 0.0), (0.62, -0.3), (1.0, 0.0)],
            'onda': lambda t: 0.4 * t})),
        # EL OJO SE ABRE, LA CARGA (bucle): arriba, tentaculos en abanico y el aro encendiendose punto a punto.
        'ojo_carga': (8, 8.0, True, 8, _anim_t({
            'sube': lambda t: 4.0 + 0.4 * math.sin(2 * math.pi * t), 'abanico': lambda t: 0.9 + 0.08 * math.sin(2 * math.pi * t),
            'aro': lambda t: AURO_N * (t + 1.0 / 8.0), 'aro_luz': lambda t: 4, 'iris': lambda t: 5, 'luz': lambda t: 4,
            'latido': lambda t: -0.3 + 0.2 * math.sin(4 * math.pi * t), 'onda': lambda t: t})),
        # EL ESTALLIDO: baja de golpe con todo a tope, los tentaculos restallan abajo, y vuelve.
        'ojo': (8, 12.0, False, 8, _anim_t({
            'sube': [(0.0, 4.0), (0.25, -2.0), (0.45, -1.0), (1.0, 0.0)],
            'abanico': [(0.0, 0.9), (0.25, 0.0), (1.0, 0.1)],
            'tension': [(0.0, 0.0), (0.2, 0.9), (0.45, 0.6), (1.0, 0.0)],
            'latido': [(0.0, -0.3), (0.25, 1.0), (0.5, 0.3), (1.0, 0.0)],
            'luz': [(0.0, 4), (0.2, 5), (0.5, 5), (0.75, 4), (1.0, 3)],
            'aro_luz': [(0.0, 4), (0.2, 5), (0.6, 5), (1.0, 3)],
            'iris': [(0.0, 5), (0.6, 5), (1.0, 4)]})),
        # TENTACULOS QUE AZOTAN: se recogen y restallan hacia abajo; el cuerpo da un respingo.
        'tentaculos': (8, 14.0, False, 8, _anim_t({
            'tension': [(0.0, 0.0), (0.25, -0.8), (0.45, 1.0), (0.65, 0.6), (1.0, 0.0)],
            'sube': [(0.0, 0.0), (0.25, 1.2), (0.45, -0.8), (1.0, 0.0)],
            'luz': [(0.0, 3), (0.4, 4), (0.65, 4), (1.0, 3)]})),
        # ENCAJE EN EL AIRE: despedida atras y arriba, tambaleo, se recoloca.
        'encaje': (4, 18.0, False, 8, _anim_t({
            'avance': [(0.0, -3.0), (0.34, -1.6), (0.67, -0.5), (1.0, 0.0)],
            'sube': [(0.0, 2.2), (0.34, 1.2), (0.67, 0.3), (1.0, 0.0)],
            'inclina': [(0.0, -0.35), (0.34, 0.18), (0.67, -0.08), (1.0, 0.0)],
            'latido': [(0.0, 1.0), (0.5, -0.3), (1.0, 0.0)],
            'luz': [(0.0, 4), (0.5, 3), (1.0, 3)], 'estela': [(0.0, -0.6), (1.0, 0.0)]})),
        # MUERTE QUE CAE: se apagan los nervios uno a uno y el aro; cae dando vueltas, choca y se desinfla.
        'muerte': (12, 9.0, False, 8, _anim_t({
            'luz': [(0.0, 3), (0.15, 2), (0.3, 1), (0.45, 0), (1.0, 0)],
            'aro': [(0.0, AURO_N), (0.4, 0), (1.0, 0)], 'iris': [(0.0, 4), (0.3, 2), (0.5, 0), (1.0, 0)],
            'sube': [(0.0, 0.0), (0.15, 1.0), (0.62, -ALTURA), (1.0, -ALTURA)],
            'gira': [(0.0, 0.0), (0.62, 2.4), (1.0, 2.6)],
            'inclina': [(0.0, 0.0), (0.4, 0.3), (0.62, 0.1), (1.0, 0.0)],
            'desinfla': [(0.0, 0.0), (0.62, 0.0), (0.75, 0.55), (0.9, 0.9), (1.0, 1.0)],
            'latido': [(0.0, 0.0), (0.62, 0.0), (0.66, -0.8), (1.0, 0.0)],
            'boca': [(0.0, 0.6), (0.3, 1.0), (1.0, 0.7)], 'parpado': [(0.0, 0.0), (0.62, 0.3), (1.0, 0.55)],
            'abanico': [(0.0, 0.0), (0.5, 0.5), (1.0, 0.8)], 'onda': lambda t: 1.5 * t})),
        # LA EVOLUCION desde la Masa galvanica: en el suelo y del tamaño de la Masa; se hincha, se despega, los finos
        # le brotan, y el aro se enciende punto a punto.
        'evolucion': (20, 10.0, False, 8, _anim_t({
            'escala': [(0.0, 2.16 / _ESC_TOR), (0.35, 2.16 / _ESC_TOR * 1.06), (0.7, 1.0), (1.0, 1.0)],
            'sube': [(0.0, -ALTURA), (0.3, -ALTURA), (0.75, 0.6), (0.85, -0.3), (1.0, 0.0)],
            'latido': [(0.0, 0.0), (0.15, 0.8), (0.3, -0.6), (0.45, 1.0), (0.6, 0.0), (1.0, 0.0)],
            'finos': [(0.0, 0.0), (0.5, 0.0), (0.85, 1.0), (1.0, 1.0)],
            'boca': [(0.0, 0.15), (0.6, 0.15), (0.9, 0.6), (1.0, 0.6)],
            'aro': [(0.0, 0), (0.7, 0), (1.0, AURO_N)], 'aro_luz': [(0.0, 3), (1.0, 3)],
            'iris': [(0.0, 3), (0.7, 3), (0.85, 4), (1.0, 4)],
            'luz': [(0.0, 3), (0.4, 4), (0.6, 5), (0.8, 4), (1.0, 3)], 'onda': lambda t: t})),
    }


def modelo_de(pose):
    return MODELO


def _hoja_ver(nombres):
    """Como polilla_mut_sdf._hoja_ver: cada anim en SE (de frente) y N (de espaldas), fotograma a fotograma, x3."""
    from PIL import Image, ImageDraw
    import sdf_gpu
    DIRS = (1, 4)
    pedidas = nombres or list(ANIMS.keys())
    fotos = {}
    for nm in pedidas:
        trabajos = []; quien = []
        n, _fps, loop, _d, fn = ANIMS[nm]
        for d in DIRS:
            for i in range(n):
                t = i / n if loop else i / max(1, n - 1)
                pose = fn(t)
                trabajos.append((modelo_de(pose), escena(pose), d)); quien.append((nm, d, i))
        fotos.update(zip(quien, sdf_gpu.render_lote(trabajos)))
        print(nm, 'ok', flush=True)
    ESC = 3
    recortes = []
    for nm in pedidas:
        for d in DIRS:
            tira = [fotos[(nm, d, i)] for i in range(ANIMS[nm][0])]
            cajas = [f.getbbox() for f in tira if f.getbbox()]
            c = (min(x[0] for x in cajas) - 2, min(x[1] for x in cajas) - 2, max(x[2] for x in cajas) + 2,
                 max(x[3] for x in cajas) + 2)
            if c[0] <= 0 or c[1] <= 0 or c[2] >= LIENZO[0] or c[3] >= LIENZO[1]:
                print('OJO: %s d%d toca el borde del lienzo %s' % (nm, d, c))
            recortes.append(('%s d%d' % (nm, d), tira, c))
    ancho = 150 + max((c[2] - c[0]) * ESC * len(tira) for _, tira, c in recortes)
    alto = sum((c[3] - c[1]) * ESC + 6 for _, _, c in recortes)
    hoja = Image.new('RGB', (ancho, alto), (24, 26, 32))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, tira, c in recortes:
        cw, ch = c[2] - c[0], c[3] - c[1]
        dib.text((6, y + ch * ESC // 2), nombre, fill=(235, 235, 235))
        for i, f in enumerate(tira):
            r = f.crop(c).resize((cw * ESC, ch * ESC), Image.NEAREST)
            hoja.paste(r, (150 + i * cw * ESC, y), r)
        y += ch * ESC + 6
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                       'aberracion_%s_hojas' % MUT)
    os.makedirs(esc, exist_ok=True)
    os.makedirs(VISTAS, exist_ok=True)
    nombre = 'aberracion_%s_%s.png' % (MUT, '_'.join(nombres) if nombres and len(nombres) <= 3 else 'todas')
    hoja.save(os.path.join(esc, nombre))
    hoja.save(VISTAS + nombre)
    print(os.path.join(esc, nombre), hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja_ver(args[1:])
    else:
        hornear('aberracion_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
