# ============================================================
#  chillon_mut_sdf.py -- LOS MUTANTES DEL CHILLON, con sus animaciones (18/11/2026, memoria chillon-mutante). Los cuerpos
#  son los elegidos en chillon_mutantes_versiones.py:
#    CHILLON_VAR=apagaluces  APAGALUCES (A hollin: el mismo murcielago, negro mate, ojos ciegos lechosos). "10/10"
#    CHILLON_VAR=pina        PIÑA NEGRA (Piña 2, alas B: unos 25 apagaluces cabeza abajo en forma de piña y seis ENTEROS
#                            batiendo repartidos, que la llevan en el aire)
#    CHILLON_VAR=cria        LA CRIA de la Piña: el Apagaluces en pequeño (mismas animaciones)
#  LAS ANIMACIONES (aprobada la lista el 18/11):
#    APAGALUCES / CRIA  las del chillon (idle, walk, embestida = Picado, encaje, muerte) con su cuerpo, y nuevas:
#                       chillido_oscuro  quieto en el aire, se yergue y chilla en CIRCULO: las orejas se abren a los lados
#                       comer            (solo el Apagaluces) se alza y muerde tres veces
#                       evolucion        (solo el Apagaluces) desde el normal: se oscurece de las alas hacia dentro, crece
#                                        y le salen los ojos ciegos
#    PIÑA               idle / walk     el racimo flota con un balanceo pesado y los seis baten A DESTIEMPO
#                       chillido_oscuro el racimo se encoge y se abre de golpe (chillan todos)
#                       soltar          uno de los de abajo se suelta, cae y abre las alas (la cria)
#                       encaje          un tiron: el racimo se va atras y los que baten se descolocan
#                       muerte          los que baten se sueltan y el racimo cae y se deshace en el suelo
#                       evolucion       desde el Apagaluces: se le van pegando mas hasta formar la piña
#  Uso: CHILLON_VAR=apagaluces python tools/sprites_sdf/chillon_mut_sdf.py [anim ...] -> assets/sprites/enemigos/chillon_sdf_<var>/
#       CHILLON_VAR=pina python tools/sprites_sdf/chillon_mut_sdf.py hoja [anim ...] -> la hoja para mirarla, al escritorio
#       (la hoja no toca assets: se hornea tras su visto bueno. PROCESOS=n, 3 por defecto)
# ============================================================
import sys, os, math, random
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import chillon_sdf as base
import chillon_mutantes_versiones as vers

VAR = os.environ.get('CHILLON_VAR', 'apagaluces')
VARS = ('apagaluces', 'pina', 'cria')
assert VAR in VARS, 'CHILLON_VAR tiene que ser una de %s' % (VARS,)
SALIDA = 'assets/sprites/enemigos/chillon_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/'
V = np.array
Z = base.VUELO_Z

# LA TRANSICION DE COLOR de la evolucion (memoria transiciones-de-color): del gris del normal al hollin, sin saltos.
PASOS = 6
MEZCLAS = [(k, v) for k, v in vers.NEGRO.items()]
for _a, _b in MEZCLAS:
    for _k in range(PASOS + 1):
        ta, tb = vers.MAT[_a], vers.MAT[_b]
        vers.MAT['mix_%s_%s_%d' % (_a, _b, _k)] = [tuple(ta[i][c] + (tb[i][c] - ta[i][c]) * _k / PASOS for c in range(3))
                                                  for i in range(min(len(ta), len(tb)))]


def mix(a, b, f):
    return 'mix_%s_%s_%d' % (a, b, int(round(max(0.0, min(1.0, f)) * PASOS)))


# LOS LIENZOS: el normal es 1,5 en 80 x 80 (pies 40, 43). El Apagaluces es mas grande (tiene el triple de vida); la cria, un
# apagaluces en pequeño; la Piña, el doble de alta que un apagaluces.
ESCALA = {'apagaluces': 1.75, 'cria': 1.05, 'pina': 1.75}[VAR]
LIENZO = {'apagaluces': (100, 100, 50, 56), 'cria': (60, 60, 30, 34), 'pina': (136, 136, 68, 106)}[VAR]
MODELO = Modelo(ESCALA, LIENZO[:2], LIENZO[2:], vers.MAT, (0.02, 0.02, 0.03), suaves=('cuerpo', 'cabeza'),
                brillan=('ojo_ciego',), corta_suelo=True)
# Los cuerpos de los apagaluces que van COPIADOS en la Piña (vers.instancia: grupo + sufijo) se funden igual que el suyo.
MODELO.suaves = ('cuerpo', 'cabeza') + tuple('%s%s' % (g, s) for s in ['_b%d' % i for i in range(6)] + ['_cria', '_evo']
                                             + ['_v%d' % i for i in range(40)]
                                             for g in ('cuerpo', 'cabeza'))


# ------------------------------------------------------------
#  EL APAGALUCES (y la cria)
# ------------------------------------------------------------
def _huesos(p):
    """Los del chillon y, en la evolucion, todo a escala (crece de lo que era al nuevo) desde el suelo."""
    X = base.huesos(p)
    sc = p.get('escala', 1.0)
    if sc != 1.0:
        S = (np.eye(3) * sc, np.zeros(3))
        X = {k: comp(S, v) for k, v in X.items()}
    return X


def escena_apagaluces(p):
    e = Escena(_huesos(p))
    if p.get('evo', -1.0) >= 0.0:
        # LA EVOLUCION: primero se le oscurecen las ALAS y luego el CUERPO (de fuera a dentro); los ojos salen al final.
        fa, fc = p['f_alas'], p['f_cuerpo']
        mats = {k: mix(k, v, fa if k in ('membrana', 'dedo') else fc) for k, v in vers.NEGRO.items()}
        vers.murcielago(e, p, mats, ojos=p['k_ojos'] if p['k_ojos'] > 0.05 else False, sombra=False)
    else:
        vers.murcielago(e, p, vers.NEGRO, ojos=True, sombra=False)
    return e.L


def _de_base(fn):
    return fn


def a_chillido_oscuro(t):
    # EL DE OSCURIDAD, EN CIRCULO: el del chillon (se para, se yergue, abre la boca) pero las orejas NO apuntan a nadie: se
    # abren a los lados, y las alas se extienden del todo (bate menos: quieto en el aire).
    p = base.anim_chillido(t)
    p['abre'] = tramos(t, [(0.0, 0.0), (0.143, 0.25), (0.286, 0.85), (0.429, 1.0), (0.714, 1.0), (0.857, 0.5), (1.0, 0.1)])
    p['orejas'] = 0.15 * p['abre']
    p['bate'] = 0.55 * p['bate'] - 0.2 * p['abre']
    return p


def _paso(x, a, b):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    u = (x - a) / (b - a)
    return u * u * (3 - 2 * u)


def a_comer(t):
    # COME CRISTALES: se para, se yergue y MUERDE tres veces hacia abajo.
    mordisco = 0.5 - 0.5 * math.cos(2 * math.pi * 3 * _paso(t, 0.15, 0.85))
    return base.POSE(bate=0.45 * math.sin(2 * math.pi * t * 2), encara=0.85 * (1.0 - _paso(t, 0.85, 1.0)) + 0.1,
                     vuela=-2.0 * _paso(t, 0.0, 0.15) * (1.0 - _paso(t, 0.85, 1.0)),
                     boca=0.1 + 0.9 * mordisco * (1.0 - _paso(t, 0.85, 1.0)), cabeza=0.5 * mordisco, patas=0.3)


def a_evolucion(t):
    # TIEMBLA SIENDO LO QUE ERA, se envuelve en las alas, crece y se oscurece (alas primero), y se abre ya negro.
    p = base.anim_idle(t * 4.0 % 1.0)
    rec = tramos(t, [(0.0, 0.0), (0.2, 0.8), (0.75, 0.8), (0.9, 0.0), (1.0, 0.0)])
    p.update(recoge=rec, bate=p['bate'] * (1.0 - rec) + 0.4 * rec,
             evo=_paso(t, 0.1, 0.9), f_alas=_paso(t, 0.15, 0.55), f_cuerpo=_paso(t, 0.35, 0.8),
             k_ojos=_paso(t, 0.7, 0.92), escala=1.5 / 1.75 + (1.0 - 1.5 / 1.75) * _paso(t, 0.2, 0.8),
             boca=tramos(t, [(0.0, 0.0), (0.88, 0.0), (0.94, 0.9), (1.0, 0.1)]),
             balanceo=0.25 * math.sin(t * 2 * math.pi * 7) * (1.0 - _paso(t, 0.6, 0.8)))
    return p


# ------------------------------------------------------------
#  LA PIÑA NEGRA
# ------------------------------------------------------------
S_PINA = 3.4                 # los de colgar (la Piña 2)
ANILLOS = vers.PINA_2
ALTO = 30.0                  # a que altura va la corona
K_BATE = 0.85                # los que baten, a esta escala del apagaluces
# Los seis que baten (alas B, repartidos): anillo, angulo, desfase del aleteo (a destiempo).
BATEN = [(1, 20, 0.0), (1, 200, 0.5), (2, 100, 0.25), (2, 290, 0.7), (3, 40, 0.4), (3, 220, 0.9)]
K_CRIA = 1.05 / 1.75         # la cria que suelta, a la escala de su propio dibujo
VUELO_EVO = 0.16             # (evolucion) lo que tarda cada uno en llegar volando, en tramo de la animacion
K_LLEGA = 0.7                # y a que escala viene (se encoge al colgarse: se pliega)


_PIEZAS_BATE = {}


def _apagaluces_bate(pose_fn, t_a):
    """Las piezas de un apagaluces batiendo en el momento t_a (cacheadas por momento: son muchas)."""
    clave = (pose_fn.__name__, round(t_a % 1.0, 3))
    if clave not in _PIEZAS_BATE:
        pose = pose_fn(t_a % 1.0)
        e = Escena(base.huesos(pose))
        vers.murcielago(e, pose, vers.NEGRO, ojos=True, sombra=False)
        _PIEZAS_BATE[clave] = list(e.L)
    return _PIEZAS_BATE[clave]


def POSE_PINA(**k):
    p = dict(t_ala=0.0, batir='idle', bal=0.0, sube=0.0, avance=0.0, contrae=0.0, abre_r=0.0, suelta=-1.0, cae=0.0,
             desh=0.0, sueltan=0.0, evo=-1.0, tiron=0.0)
    p.update(k)
    return p


def escena_pina(p):
    # EL RACIMO ENTERO en un hueso 'mundo': sube y baja, se balancea (gira sobre el eje Y en su copa) y avanza.
    copa = V((0.0, 0.0, ALTO))
    T = (np.eye(3), V((0.0, p['avance'], p['sube'] - p['cae'] * (ALTO - 12.0))))
    T = comp(T, sobre(copa, ry(p['bal'] * 0.18)))
    T = comp(T, sobre(copa, rx(p['tiron'] * -0.3)))
    X = base.huesos(base.POSE())
    X['mundo'] = T
    e = Escena(X)
    add = e.add
    rnd = random.Random(3)
    evo = p['evo']
    # cuantos de colgar hay (la evolucion los va pegando de arriba abajo)
    total = sum(n for _dz, _r, n in ANILLOS)
    # EL ENCOGERSE del chillido (contrae) y el DESHACERSE de la muerte (desh): el racimo se aplasta y se abre.
    k_r = (1.0 - 0.12 * p['contrae'] + 0.10 * p['abre_r']) * (1.0 + 0.9 * p['desh'])
    k_z = (1.0 - 0.08 * p['contrae']) * (1.0 - 0.75 * p['desh'])
    fondo = ANILLOS[-1][0]
    r_max = max(r for _dz, r, _n in ANILLOS)
    k_nuc = 1.0 if evo < 0 else _paso(evo, 0.25, 0.85)
    if k_nuc > 0.05:
        base._elip(add, (0.0, 0.0, ALTO + fondo * 0.45 * k_z),
                   (r_max * 0.85 * k_r * k_nuc, r_max * 0.85 * k_r * k_nuc, (-fondo * 0.55 + 1.5) * k_z * k_nuc),
                   'hollin', 0.5, 'nucleo', 'mundo')
    ultimo = None
    i_g = 0
    for j, (dz, r, n) in enumerate(ANILLOS):
        for i in range(n):
            a = (i + 0.5 * (j % 2)) / n * 2 * math.pi + rnd.uniform(-0.12, 0.12)
            jit = rnd.uniform(-0.6, 0.6)
            sz = rnd.uniform(0.9, 1.08)
            i_g += 1
            c = V((r * k_r * math.cos(a), r * k_r * math.sin(a), ALTO + (dz + jit) * k_z))
            fuera = V((math.cos(a), math.sin(a), 0.0)) if r > 0 else V((0.0, 1.0, 0.0))
            if evo >= 0.0:
                # (18/11, el jefe: "que vengan de fuera murcielagos a juntarse con el") cada uno LLEGA VOLANDO desde fuera
                # (de su lado, alto) hasta su sitio, batiendo, y al llegar se cuelga cabeza abajo. Por orden, de arriba abajo.
                llega = 0.12 + 0.62 * (i_g - 1) / max(1, total - 1)
                u = (evo - (llega - VUELO_EVO)) / VUELO_EVO
                if u < 0.0:
                    continue
                if u < 1.0:
                    ang_v = a + 0.6 * (1 if i_g % 2 else -1)
                    lejos = c + V((math.cos(ang_v), math.sin(ang_v), 0.0)) * 46.0 + V((0.0, 0.0, 14.0))
                    k_e = u * u * (3 - 2 * u)
                    donde = lejos + (c - lejos) * k_e
                    giro = math.atan2(c[1] - lejos[1], c[0] - lejos[0]) - math.pi / 2
                    pecho = V((0.0, 0.0, Z - 1.5)) * K_LLEGA
                    vers.instancia(e, _apagaluces_bate(base.anim_walk, p['t_ala'] * 1.5 + i_g * 0.37), K_LLEGA, giro,
                                   donde - rz(giro) @ pecho, '_v%d' % (i_g % 40), T=T)
                    continue
            if j == len(ANILLOS) - 1:
                ultimo = (c, sz)
                if p['suelta'] >= 0.0:
                    continue      # el de abajo, el que se suelta: va aparte
            vers.pequeno(add, c, S_PINA * sz, V((0.0, 0.0, -1.0)) + fuera * 0.45, fuera, grupo='r%d_%d' % (j, i))
    # LOS QUE BATEN, a destiempo (cada uno con su desfase); al morir se sueltan y se apartan hacia arriba y fuera.
    pose_fn = base.anim_walk if p['batir'] == 'walk' else base.anim_idle
    n_bate = len(BATEN) if evo < 0 else int(round(len(BATEN) * _paso(evo, 0.55, 0.95)))
    for jb, (anillo, ang, des) in enumerate(BATEN[:n_bate]):
        dz, r, _n = ANILLOS[anillo]
        a = math.radians(ang)
        fuera = V((math.cos(a), math.sin(a), 0.0))
        donde = V((r * k_r * math.cos(a), r * k_r * math.sin(a), ALTO + dz * k_z)) + fuera * 4.5 + V((0.0, 0.0, 1.5))
        donde = donde + (fuera * 7.0 + V((0.0, 0.0, 6.0))) * p['sueltan']
        giro = a - math.pi / 2
        t_a = p['t_ala'] + des
        # descolocados (el tiron del encaje): el aleteo da un salto
        t_a += 0.35 * p['tiron'] * (1 if jb % 2 else -1)
        pecho = V((0.0, 0.0, Z - 1.5)) * K_BATE
        vers.instancia(e, _apagaluces_bate(pose_fn, t_a), K_BATE, giro, donde - rz(giro) @ pecho, '_b%d' % jb, T=T)
    # EL QUE SE SUELTA: cae desde abajo y, a media caida, ya es la cria batiendo (el apagaluces en pequeño).
    if p['suelta'] >= 0.0 and ultimo is not None:
        c, sz = ultimo
        u = p['suelta']
        bajo = c + V((0.0, 2.0 * u, -9.0 * _paso(u, 0.0, 0.6) + 3.0 * _paso(u, 0.6, 1.0)))
        if u < 0.45:
            vers.pequeno(add, bajo, S_PINA * sz, V((0.0, 0.0, -1.0)), V((0.0, 1.0, 0.0)), grupo='suelta')
        else:
            k = K_CRIA * (0.8 + 0.2 * _paso(u, 0.45, 0.8))
            pecho = V((0.0, 0.0, Z - 1.5)) * k
            vers.instancia(e, _apagaluces_bate(base.anim_walk, u * 2.0), k, 0.0, bajo - pecho, '_cria', T=T)
    # EL APAGALUCES QUE SE CONVIERTE (la evolucion): el del centro, que se queda de los que baten.
    if 0.0 <= evo < 0.6:
        k = 1.0 - 0.15 * _paso(evo, 0.3, 0.6)
        pecho = V((0.0, 0.0, Z - 1.5)) * k
        vers.instancia(e, _apagaluces_bate(base.anim_idle, p['t_ala']), k, 0.0, V((0.0, 0.0, ALTO + 1.0)) - pecho, '_evo',
                       T=T)
    return e.L


def p_idle(t):
    return POSE_PINA(t_ala=t * 2.0, bal=math.sin(2 * math.pi * t), sube=0.9 * math.sin(2 * math.pi * t + 1.2))


def p_walk(t):
    return POSE_PINA(t_ala=t * 2.0, batir='walk', bal=1.4 * math.sin(2 * math.pi * t), sube=1.2 * math.sin(4 * math.pi * t),
                     tiron=0.25 * math.sin(2 * math.pi * t))


def p_chillido(t):
    return POSE_PINA(t_ala=t * 2.0, contrae=tramos(t, [(0.0, 0.0), (0.3, 1.0), (0.42, 0.0), (1.0, 0.0)]),
                     abre_r=tramos(t, [(0.0, 0.0), (0.3, 0.0), (0.42, 1.0), (0.75, 1.0), (1.0, 0.0)]),
                     sube=tramos(t, [(0.0, 0.0), (0.3, -0.8), (0.42, 1.2), (1.0, 0.0)]))


def p_soltar(t):
    return POSE_PINA(t_ala=t * 2.0, suelta=t, sube=0.5 * math.sin(2 * math.pi * t), bal=0.4 * math.sin(2 * math.pi * t))


def p_encaje(t):
    r = tramos(t, [(0.0, 1.0), (0.34, 0.45), (0.67, 0.14), (1.0, 0.0)])
    return POSE_PINA(t_ala=t, tiron=r, avance=-3.0 * r, bal=-1.2 * r, sube=-1.0 * r)


def p_muerte(t):
    cae = tramos(t, [(0.0, 0.0), (0.15, 0.05), (0.35, 0.25), (0.6, 0.7), (0.78, 1.0), (1.0, 1.0)])
    return POSE_PINA(t_ala=t * 2.0, sueltan=_paso(t, 0.0, 0.45), cae=cae, desh=_paso(t, 0.65, 1.0),
                     bal=0.8 * math.sin(t * 9.0) * (1.0 - cae))


def p_evolucion(t):
    # LLAMA A LOS SUYOS: el apagaluces se queda batiendo en el sitio y le van llegando de fuera, uno tras otro (ver arriba)
    return POSE_PINA(t_ala=t * 4.0, evo=t, sube=0.6 * math.sin(2 * math.pi * t * 2))


# ------------------------------------------------------------
#  LAS ANIMACIONES DE CADA UNO
# ------------------------------------------------------------
ANIMS = {}
if VAR in ('apagaluces', 'cria'):
    for _nm in ('idle', 'walk', 'embestida', 'encaje', 'muerte'):
        ANIMS[_nm] = base.ANIMS[_nm]
    ANIMS['chillido_oscuro'] = (8, 8.0, False, 8, a_chillido_oscuro)
if VAR == 'apagaluces':
    ANIMS['comer'] = (10, 10.0, False, 8, a_comer)
    ANIMS['evolucion'] = (18, 10.0, False, 8, a_evolucion)
if VAR == 'pina':
    ANIMS['idle'] = (8, 8.0, True, 8, p_idle)
    ANIMS['walk'] = (8, 10.0, True, 8, p_walk)
    ANIMS['chillido_oscuro'] = (8, 8.0, False, 8, p_chillido)
    ANIMS['soltar'] = (10, 10.0, False, 8, p_soltar)
    ANIMS['encaje'] = (4, 14.0, False, 8, p_encaje)
    ANIMS['muerte'] = (10, 10.0, False, 8, p_muerte)
    ANIMS['evolucion'] = (24, 10.0, False, 8, p_evolucion)


def escena(p):
    return escena_pina(p) if VAR == 'pina' else escena_apagaluces(p)


# ------------------------------------------------------------
#  LA HOJA PARA MIRARLA (sin tocar assets)
# ------------------------------------------------------------
def _dibuja(tr):
    getattr(__import__('sdf_comun'), '_prioridad_baja', lambda: None)()
    nombre, d, i = tr
    n, _fps, loop, _dirs, fn = ANIMS[nombre]
    t = i / n if loop else i / max(1, n - 1)
    return (nombre, d, i, render(MODELO, escena(fn(t)), d))


def _hoja(nombres):
    from multiprocessing import Pool
    from PIL import Image, ImageDraw
    DIRS = (1, 4)     # SE de frente y N de espaldas
    pedidas = nombres or list(ANIMS.keys())
    trabajos = []
    for nm in pedidas:
        for d in DIRS:
            trabajos += [(nm, d, i) for i in range(ANIMS[nm][0])]
    with Pool(int(os.environ.get('PROCESOS', 0)) or 3) as pool:
        hechos = pool.map(_dibuja, trabajos, chunksize=2)
    fotos = {(a, b, c): im for a, b, c, im in hechos}
    ESC = 3 if VAR != 'pina' else 2
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
    hoja = Image.new('RGB', (ancho, alto), (52, 58, 70))
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
    ruta = os.path.join(esc, 'chillon_%s_hoja.png' % VAR)
    hoja.save(ruta)
    hoja.save(VISTAS + 'chillon_%s_hoja.png' % VAR)
    print(ruta, hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja(args[1:])
    else:
        hornear('chillon_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
