# ============================================================
#  arana_mutantes_sdf.py -- LOS MUTANTES DE LA ARAÑA animados (03/11/2026, arana-mutante). UNA LINEA:
#    ARANA_VAR=tejedora    la TEJEDORA DE BRASAS (1a, fuego): el abdomen es una jaula de carbon con el nucleo de ascuas
#    ARANA_VAR=tormentosa  la ARAÑA TORMENTOSA (2a, rayo): el abdomen es un globo de hilos de luz, patas de huesos
#  Sus cuerpos, los de la lamina (arana_mutantes_versiones.py: 'farol' y 'neon 3 vetas'); aqui cada pieza va a su HUESO.
#  Las animaciones de la araña (mismos tiempos, para que sus efectos caigan igual) que usan sus habilidades, mas las
#  suyas, comer y la EVOLUCION. Mayores que la araña (x1,15 y x1,3).
#  LOS HILOS DE LA TORMENTOSA (como los ojos del slime de mil ojos): el cuerpo va con todos los hilos apagados y cada uno
#  de los GRUPOS_PARPADO (3 hilos repartidos) sale en su hoja de capa; el juego las enciende cada una a su aire.
#  Uso: ARANA_VAR=tejedora python tools/sprites_sdf/arana_mutantes_sdf.py [anim ...]
#       -> tools/salida/sdf/arana_sdf_<var>/ (SIN hornear al juego hasta su visto bueno) y las vistas a su escritorio
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import arana_sdf as ars
import arana_mutantes_versiones as am

V = np.array
VAR = os.environ.get('ARANA_VAR', 'tejedora')
ESC = {'tejedora': 2.2 * 1.15, 'tormentosa': 2.2 * 1.3}[VAR]
ESC_ANTES = {'tejedora': 2.2, 'tormentosa': 2.2 * 1.15}[VAR]
LIENZO = {'tejedora': (160, 150), 'tormentosa': (180, 190)}[VAR]
PIES = {'tejedora': (80, 88), 'tormentosa': (90, 118)}[VAR]
SALIDA = 'tools/salida/sdf/arana_sdf_%s/' % VAR   # al juego (assets/sprites/enemigos/) cuando las apruebe
VISTAS = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                      'arana_%s_hojas' % VAR) + os.sep
PARPADOS = VAR == 'tormentosa'
GRUPOS_PARPADO = 4 if PARPADOS else 1
# LA EVOLUCION, POCO A POCO: tonos intermedios para que el material no cambie de golpe (la leccion del Espantajo).
TONOS = 5
TONOS_DE = {'cuerpo': 'carbon', 'pata': 'pata_carbon', 'brasa': 'noche', 'nucleo': 'noche', 'carbon': 'noche',
            'pata_carbon': 'pata_azul'}


def _mat():
    m = am._mat()
    for de, a in TONOS_DE.items():
        for k in range(1, TONOS):
            u = k / TONOS
            t0, t1 = m[de], m[a]
            n = min(len(t0), len(t1))
            m['%s_a_%s_%d' % (de, a, k)] = [tuple(t0[i][c] * (1 - u) + t1[i][c] * u for c in range(3)) for i in range(n)]
    return m


def _tono(de, a, u):
    k = int(round(u * TONOS))
    return de if k <= 0 else (a if k >= TONOS else '%s_a_%s_%d' % (de, a, k))


_brillan_tonos = tuple('%s_a_noche_%d' % (b, k) for b in ('brasa', 'nucleo') for k in range(1, 3))
MODELO = Modelo(ESC, LIENZO, PIES, _mat(), (0.07, 0.06, 0.09), suaves=('cuerpo',), brillan=am.BRILLAN + _brillan_tonos,
                corta_suelo=True)
MODELO.sin_borde = ('cian', 'turquesa', 'blanco_rayo', 'rojo_mota', 'hilo_azul', 'hilo_medio', 'hilo_claro', 'hilo_teal')


class _Esc:
    """La Escena del motor, con los ayudantes de la lamina: lo que se añade va al hueso que este puesto en 'hueso'."""
    def __init__(self, X):
        self.e = Escena(X)
        self.hueso = 'raiz'
        self.L = self.e.L

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso=None):
        self.e.add(fn, mat, k, grupo, hueso or self.hueso)


def POSE(**k):
    # hincha  abulta el abdomen          vuela  el cuerpo en el aire      sacude  tiembla de lado
    # abre    los pies hacia fuera       teje   las patas de delante tejen
    # carga   el nucleo/los hilos crecen y se encienden (0..1)            evo     0 = lo que era, 1 = lo que es
    # cerrados el grupo de hilos encendido (ver PARPADOS), True = todos
    p = ars.POSE(hincha=1.0, vuela=0.0, sacude=0.0, abre=0.0, teje=0.0, carga=0.0, evo=1.0, cerrados=False)
    p.update(k)
    return p


def huesos(p):
    raiz = (np.eye(3), V((p['sacude'], p['avance'], -p['agacha'] * 2.0 + p['vuela'])))
    raiz = comp(raiz, sobre(ars.ALZA_PIVOTE, rx(-p['alza'] * ars.ALZA_MAX)))
    abd = comp(raiz, sobre(ars.PEDICULO, rx(p['abdomen'] * ars.ABDOMEN_MAX)))
    return {'raiz': raiz, 'abdomen': abd, 'mundo': IDENT}


def _pata(p, X, s, k, largo, alto):
    """La de la araña (arana_sdf._pata), con su largo y alto y los gestos nuevos."""
    y0, ang = ars.PATAS[k]
    base_l = V((2.4 * s, y0, 3.2))
    d = V((math.cos(ang) * s, math.sin(ang), 0.0))
    pie_l = base_l + d * (largo + p['abre'] * 3.0) + V((0, 0, -3.0))
    base = aplica(X['raiz'], base_l)
    pie = pie_l + V((p['sacude'], p['avance'], 0.0))
    grupo = (k + (1 if s > 0 else 0)) % 2
    fi = 2 * math.pi * (p['fase'] + 0.5 * grupo)
    pie = pie + V((0.0, ars.PASO_LARGO * math.sin(fi) * p['paso'], ars.PASO_ALTO * max(0.0, math.cos(fi)) * p['paso']))
    w = ars.ALZA_SIGUE[k] * min(1.0, p['alza'] * 1.5)
    if w > 0.0:
        pie = pie * (1 - w) + aplica(X['raiz'], pie_l + V((0.0, 1.5 * (1 - k), 2.0))) * w
    # EN EL AIRE: los pies suben con ella, recogidos a medias.
    if p['vuela'] > 0.0:
        r_ = min(1.0, p['vuela'] / 4.0) * 0.32
        pie = pie * (1 - r_) + base * r_ + V((0, 0, p['vuela'] * (1 - r_)))
        pie[2] = min(pie[2], base[2] - 1.0)
    # TEJER: las dos de delante se juntan y dan vueltas ante la boca.
    if p['teje'] > 0.0 and k == 0:
        a = 2 * math.pi * (p['fase'] + (0.25 if s > 0 else 0.0))
        q = aplica(X['raiz'], V((1.5 * s + 1.1 * math.cos(a), 9.6 + 0.8 * math.sin(a), 4.4 + 1.3 * math.sin(a))))
        pie = pie * (1 - p['teje']) + q * p['teje']
    h = pie - base
    rod = base + V((h[0], h[1], 0.0)) * 0.47 + V((0, 0, max(base[2], pie[2]) - base[2] + alto))
    tob = rod + (pie - rod) * 0.74
    tob[2] = pie[2] + 0.55 * (rod[2] - pie[2])
    e = p['encoge']
    if e > 0.0:
        rod_c = aplica(X['raiz'], base_l + d * 3.0 + V((0, 0, 4.6)))
        tob_c = aplica(X['raiz'], base_l + d * 4.4 + V((0, 0, 1.4)))
        pie_c = aplica(X['raiz'], base_l + d * 2.2 + V((0, 0, -1.6)))
        rod = rod * (1 - e) + rod_c * e
        tob = tob * (1 - e) + tob_c * e
        pie = pie * (1 - e) + pie_c * e
    return base, rod, tob, pie


def _muerde(e, y, z, p, mat='colmillo', palpo='pata', largo=1.0):
    m = p['muerde']
    for s in (-1, 1):
        punta = (0.55 * s + (1.3 if m > 0 else 0.5) * m * s, y + 1.1 * largo + 0.4 * max(m, 0.0), z - 1.5 * largo + 0.7 * max(m, 0.0))
        am._cono(e, (0.7 * s, y, z), punta, 0.7, 0.22, mat, 0, 'colmillo')
        am._cono(e, (1.6 * s, y - 0.5, z - 0.3), (2.6 * s + 0.6 * max(m, 0.0) * s, y + 1.5, z - 2.1 + 1.2 * max(m, 0.0)), 0.45, 0.28,
                 palpo, 0, 'palpo')


# ---------------- LA TEJEDORA DE BRASAS (el farol) ----------------
FAROL_PE = V((0.0, 0.2, 3.6))
FAROL_C = V((0.0, -6.8, 5.0))
FAROL_R = V((5.6, 6.6, 5.6))


def _giro_farol(p):
    return am._gira_x(p, FAROL_PE, -0.58)


def piezas_tejedora(e, p, carbon='carbon', pata='pata_carbon', brasa='brasa', nucleo='nucleo', costillas=1.0, patas=True):
    X = e.e.X
    e.hueso = 'raiz'
    am._elip(e, (0, 3.0, 3.1), (3.0, 3.3, 1.9), carbon, 0.5, 'cuerpo')
    am._cono(e, (0, 1.0, 4.9), (0, 4.8, 4.5), 0.35, 0.25, brasa, 0, 'grieta')
    am._ojos(e, 5.5, 4.2, 'ojo_fuego')
    _muerde(e, 5.6, 2.8, p)
    e.hueso = 'abdomen'
    giro = _giro_farol
    h = p['hincha']
    r = FAROL_R * h
    am._cono(e, FAROL_PE, giro((0, -1.2, 4.2)), 1.3, 1.0, carbon, 0, 'cintura')
    # EL NUCLEO crece con la carga.
    n = 1.0 + 0.32 * p['carga']
    if brasa != 'noche':
        am._elip(e, giro(FAROL_C), V((3.3, 4.0, 3.3)) * n, brasa, 0, 'nucleo')
        am._elip(e, giro(FAROL_C + V((0, 0.6, 0.4))), V((2.1, 2.5, 2.1)) * n, nucleo, 0, 'nucleo2')
    # LAS COSTILLAS: 'costillas' < 1 las va sacando una a una (la evolucion).
    cuantas = int(round(9 * costillas))
    for i in range(cuantas):
        a = 2 * math.pi * i / 9 + 0.17
        am._tubo(e, am._costilla(FAROL_C, r, a, giro=giro), [0.62] * 13, carbon, 'costillas')
    if costillas >= 1.0:
        for t in (-0.45, 0.42):
            y = FAROL_C[1] + r[1] * t
            rad = math.sqrt(1 - t * t)
            pts = [giro((FAROL_C[0] + r[0] * rad * math.cos(2 * math.pi * j / 18), y,
                         FAROL_C[2] + r[2] * rad * math.sin(2 * math.pi * j / 18))) for j in range(19)]
            am._tubo(e, pts, [0.45] * 19, carbon, 'costillas')
    atras = -6.2 - r[1]
    am._cono(e, giro((0, atras, 5.0)), giro((0, atras - 2.0, 5.0)), 1.1, 0.5, carbon, 0, 'hilera')
    am._elip(e, giro((0, atras - 2.2, 5.0)), (0.5, 0.5, 0.5), brasa if brasa != 'noche' else carbon, 0, 'hilera')
    if patas:
        e.hueso = 'mundo'
        for s in (-1, 1):
            for k in range(4):
                base, rod, tob, pie = _pata(p, X, s, k, 13.0, 6.6)
                g = 'pata%d%d' % (s, k)
                am._tubo(e, [base, rod, tob, pie], [1.0, 0.75, 0.55, 0.28], pata, g)
                am._elip(e, rod, (0.9, 0.9, 0.9), pata, 0, g)
                if brasa != 'noche':
                    am._elip(e, pie + V((0, 0, 0.5)), (0.45, 0.45, 0.58), brasa, 0, 'punta')


# ---------------- LA ARAÑA TORMENTOSA (la neon) ----------------
GLOBO_C = V((0.0, -5.2, 9.4))
GLOBO_R = 6.8
N_HILOS = 12


def _encendido(p, i):
    c = p['cerrados']
    if c is True or p['carga'] >= 1.0:
        return True
    return c is not False and i % GRUPOS_PARPADO == c - 1


def piezas_tormentosa(e, p, hilos=N_HILOS, patas=True):
    X = e.e.X
    e.hueso = 'raiz'
    am._elip(e, (0, 3.0, 3.2), (1.4, 1.7, 1.0), 'noche', 0.3, 'cuerpo')
    for i in range(6):
        a = 2 * math.pi * i / 6
        pts = []
        for j in range(11):
            t = -0.96 + 1.92 * j / 10
            rad = math.sqrt(1 - t * t)
            pts.append((2.5 * rad * math.cos(a), 3.0 + 3.0 * t, 3.2 + 1.7 * rad * math.sin(a)))
        am._tubo(e, pts, [0.26] * 11, 'hilo_azul', 'hilos_cuerpo')
    am._ojos(e, 5.6, 4.1, 'hilo_claro', 0.85)
    _muerde(e, 5.4, 2.9, p, mat='hilo_teal', palpo='pata_azul')
    e.hueso = 'abdomen'
    am._tubo(e, [(0, 1.0, 3.7), (0, -1.0, 4.8), (0, -3.0, 5.1)], [0.42, 0.36, 0.32], 'hilo_azul', 'tallo')
    r = GLOBO_R * p['hincha']
    for i in range(hilos):
        a = 2 * math.pi * i / N_HILOS + 0.2
        pts = []
        for j in range(15):
            th = math.pi * j / 14
            pts.append(GLOBO_C + V((r * math.sin(th) * math.cos(a), r * math.sin(th) * math.sin(a), r * math.cos(th))))
        am._tubo(e, pts, [0.34] * 15, 'hilo_claro' if _encendido(p, i) else 'hilo_azul', 'hilos')
    for q in ((-2.8, -5.8, 10.0), (2.2, -4.2, 8.0), (0.6, -7.0, 11.3)):
        am._elip(e, q, (0.62, 0.62, 0.62), 'rojo_mota', 0, 'mota')
    if patas:
        e.hueso = 'mundo'
        for s in (-1, 1):
            for k in range(4):
                base, rod, tob, pie = _pata(p, X, s, k, 14.0, 6.0)
                g = 'pata%d%d' % (s, k)
                am._cono(e, base, rod, 0.38, 0.32, 'hilo_azul', 0, g)
                am._cono(e, rod, tob, 0.32, 0.26, 'pata_azul', 0, g)
                am._cono(e, tob, pie, 0.26, 0.16, 'pata_azul', 0, g)
                for q in (base, rod, tob, tob + (pie - tob) * 0.55):
                    am._elip(e, q, (0.62, 0.62, 0.62), 'hilo_teal', 0, 'nudo')


# ============================================================
#  LAS ANIMACIONES: las de la araña, con sus tiempos
# ============================================================
def _de_arana(fn):
    def anim(t):
        return POSE(**{k: v for k, v in fn(t).items()})
    return anim


def anim_hilo(t):
    # HILO AL ROJO: baja la cabeza, apunta con el abdomen, dispara en el 0,4 y da el TIRON hacia atras en el 0,6.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.25, 0.4), (0.6, 0.2), (1.0, 0.0)]),
                abdomen=tramos(t, [(0.0, 0.0), (0.3, 0.75), (0.4, 0.95), (0.6, 0.65), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.4, 0.5), (0.62, -3.2), (1.0, 0.0)]),
                carga=tramos(t, [(0.0, 0.0), (0.38, 0.8), (0.5, 0.2), (1.0, 0.0)]))


def anim_capullo_carga(t):
    # CAPULLO DE CENIZA, cargando (en bucle): alzada, las patas de delante tejen sin parar y el nucleo late.
    return POSE(alza=0.42 + 0.05 * math.sin(2 * math.pi * t), teje=1.0, fase=t,
                carga=0.35 + 0.25 * math.sin(2 * math.pi * t))


def anim_capullo(t):
    # CAPULLO DE CENIZA, soltando: se estira y lanza la seda en el 0,35.
    return POSE(alza=tramos(t, [(0.0, 0.42), (0.25, 0.7), (0.38, 0.2), (1.0, 0.0)]),
                teje=tramos(t, [(0.0, 1.0), (0.3, 1.0), (0.42, 0.0), (1.0, 0.0)]),
                fase=t * 2.0, avance=tramos(t, [(0.0, 0.0), (0.25, -0.8), (0.38, 2.0), (1.0, 0.0)]),
                carga=tramos(t, [(0.0, 0.5), (0.3, 1.0), (0.42, 0.1), (1.0, 0.0)]))


def anim_explosion(t):
    # LA EXPLOSION (no gasta turno y no se avisa: rapida): la jaula se hincha de golpe, revienta en el 0,3 y la deja
    # pegada al suelo, con las patas abiertas.
    return POSE(hincha=tramos(t, [(0.0, 1.0), (0.26, 1.22), (0.36, 0.92), (0.6, 1.02), (1.0, 1.0)]),
                carga=tramos(t, [(0.0, 0.3), (0.26, 1.0), (0.42, 0.0), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.26, 0.15), (0.38, 0.9), (0.7, 0.5), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.3, 0.0), (0.42, 0.8), (1.0, 0.0)]),
                sacude=0.45 * math.sin(2 * math.pi * t * 5.0) * (t < 0.3))


def anim_pisoton(t):
    # PISOTON DE TRUENO: se alza con las de delante en el aire y lo descarga todo en el 0,5.
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.38, 1.25), (0.46, 1.2), (0.54, 0.0), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.38, 0.0), (0.54, 1.0), (0.75, 0.6), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.48, 0.0), (0.56, 0.9), (0.8, 0.5), (1.0, 0.0)]),
                muerde=tramos(t, [(0.0, 0.0), (0.38, 1.0), (0.54, 1.0), (0.7, 0.0)]))


def anim_salto(t):
    # SALTO DE ARCO: se agacha, salta en el 0,25, va por el aire y cae en el 0,72 (el juego mueve el cuerpo).
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.2, 0.9), (0.28, 0.0), (0.72, 0.0), (0.8, 1.0), (1.0, 0.0)]),
                vuela=tramos(t, [(0.0, 0.0), (0.24, 0.0), (0.48, 11.0), (0.72, 0.0), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.7, 0.0), (0.78, 0.8), (1.0, 0.0)]))


def anim_descarga(t):
    # LA DESCARGA (no gasta turno y no se avisa: rapida): patas rigidas, todos los hilos encendidos y suelta en el 0,3.
    return POSE(hincha=tramos(t, [(0.0, 1.0), (0.24, 1.12), (0.34, 0.94), (0.6, 1.0), (1.0, 1.0)]),
                carga=tramos(t, [(0.0, 0.0), (0.05, 1.0), (0.5, 1.0), (0.55, 0.0), (1.0, 0.0)]),
                alza=tramos(t, [(0.0, 0.0), (0.28, 0.32), (0.45, 0.05), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.28, 1.0), (0.55, 0.6), (1.0, 0.0)]),
                sacude=0.4 * math.sin(2 * math.pi * t * 6.0) * (t < 0.55))


def anim_comer(t):
    # COME: baja la cabeza, sujeta el cristal con las de delante y masca.
    masca = math.sin(2 * math.pi * t * 4.0) * (0.25 < t < 0.85)
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.15, 0.55), (0.85, 0.55), (1.0, 0.0)]),
                abdomen=tramos(t, [(0.0, 0.0), (0.15, 0.3), (0.85, 0.3), (1.0, 0.0)]),
                teje=tramos(t, [(0.0, 0.0), (0.18, 0.75), (0.82, 0.75), (1.0, 0.0)]), fase=t * 2.0,
                muerde=0.7 * masca)


def anim_evolucion(t):
    return POSE(evo=t, sacude=0.35 * math.sin(2 * math.pi * t * 8.0) * (0.25 < t < 0.75))


# nombre: (fotogramas, fps, loop, direcciones, funcion)
ANIMS = {
    'idle': (8, 3.0, True, 8, _de_arana(ars.anim_idle)),
    'walk': (8, 11.0, True, 8, _de_arana(ars.anim_walk)),
    'embestida': (8, 11.0, False, 8, _de_arana(ars.anim_embestida)),
    'telarana': (10, 12.0, False, 8, _de_arana(ars.anim_telarana)),
    'basico': (8, 16.0, False, 8, _de_arana(ars.anim_basico)),
    'encaje': (4, 18.0, False, 8, _de_arana(ars.anim_encaje)),
    'muerte': (8, 10.0, False, 8, _de_arana(ars.anim_muerte)),
    'comer': (10, 10.0, False, 8, anim_comer),
    'evolucion': (18, 10.0, False, 8, anim_evolucion),
}
if VAR == 'tejedora':
    ANIMS.update({'hilo': (10, 12.0, False, 8, anim_hilo), 'capullo_carga': (8, 8.0, True, 8, anim_capullo_carga),
                  'capullo': (8, 10.0, False, 8, anim_capullo), 'explosion': (8, 14.0, False, 8, anim_explosion)})
else:
    ANIMS.update({'mordisco': (10, 14.0, False, 8, _de_arana(ars.anim_mordisco)), 'pisoton': (10, 12.0, False, 8, anim_pisoton),
                  'salto': (10, 12.0, False, 8, anim_salto), 'descarga': (8, 14.0, False, 8, anim_descarga)})


# ============================================================
#  LA ESCENA (y la EVOLUCION, de lo que era a lo que es)
# ============================================================
def _paso(x, a, b):
    u = max(0.0, min(1.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def _escala(L, s, dz=0.0):
    # Todo el modelo a escala 's' desde los pies.
    for i, (fn, m, g, k, Xh, nh) in enumerate(L):
        L[i] = (fn, m, g, k, (Xh[0] * s, Xh[1] * s + V((0, 0, dz))), nh)
    return L


def _cambia_mat(L, cambios):
    return [(fn, cambios.get(m, m), g, k, Xh, nh) for (fn, m, g, k, Xh, nh) in L]


def _evo_tejedora(pose):
    # DE ARAÑA A FAROL: se le chamusca la piel; el abdomen macizo encoge hasta quedar en el nucleo mientras las costillas
    # le van saliendo una a una alrededor.
    evo = pose['evo']
    L = Piezas()
    L.sombras = []
    u_mat = _paso(evo, 0.04, 0.48)
    if evo < 0.62:
        Lb = list(ars.escena(ars.POSE(agacha=0.15 * _paso(evo, 0.1, 0.4))))
        Lb = _cambia_mat(Lb, {'cuerpo': _tono('cuerpo', 'carbon', u_mat), 'pata': _tono('pata', 'pata_carbon', u_mat),
                              'dibujo': 'brasa' if evo > 0.3 else 'dibujo', 'ojo': 'ojo_fuego' if evo > 0.3 else 'ojo'})
        L.extend(_escala(Lb, (ESC_ANTES / ESC) * (1.0 + 0.1 * _paso(evo, 0.1, 0.5))))
    if evo >= 0.5:
        e = _Esc(huesos(pose))
        piezas_tejedora(e, dict(pose, carga=1.0 - _paso(evo, 0.8, 1.0)), costillas=_paso(evo, 0.5, 0.95))
        L.extend(e.L)
    return L


def _evo_tormentosa(pose):
    # DEL FAROL A LA NEON: se le apagan las ascuas y el carbon se oscurece; despues le nacen los hilos de luz, uno a uno,
    # y al final se enciende el globo entero un momento antes de quedarse en su azul.
    evo = pose['evo']
    L = Piezas()
    L.sombras = []
    apaga = _paso(evo, 0.04, 0.42)
    if evo < 0.68:
        e = _Esc(huesos(POSE(agacha=0.15 * apaga)))
        piezas_tejedora(e, POSE(), carbon=_tono('carbon', 'noche', apaga), pata=_tono('pata_carbon', 'pata_azul', apaga),
                        brasa=_tono('brasa', 'noche', apaga), nucleo=_tono('nucleo', 'noche', apaga))
        L.extend(_escala(list(e.L), (ESC_ANTES / ESC) * (1.0 - 0.1 * _paso(evo, 0.45, 0.68))))
    if evo >= 0.42:
        e = _Esc(huesos(pose))
        fin = _paso(evo, 0.82, 0.88) * (1 - _paso(evo, 0.95, 1.0))
        piezas_tormentosa(e, dict(pose, carga=1.0 if fin > 0.5 else 0.0), hilos=int(round(N_HILOS * _paso(evo, 0.42, 0.82))),
                          patas=evo >= 0.66)
        L.extend(e.L)
    return L


def escena(pose):
    if pose.get('evo', 1.0) < 1.0:
        return _evo_tejedora(pose) if VAR == 'tejedora' else _evo_tormentosa(pose)
    e = _Esc(huesos(pose))
    if VAR == 'tejedora':
        piezas_tejedora(e, pose)
    else:
        piezas_tormentosa(e, pose)
    return e.L


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        for d, f in enumerate(fotos):
            print(d, f.getbbox())
    else:
        hornear('arana_mutantes_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
