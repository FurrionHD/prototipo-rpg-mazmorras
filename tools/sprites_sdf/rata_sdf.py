# ============================================================
#  rata_sdf.py -- la RATA y el REY RATA en 3D (03/10/2026), con el motor de los enemigos (sdf_comun), copiando la
#  receta del jabali. Las medidas, las del viejo (rata_sprites.gd: un bicho de ~24 de largo con la cola, el origen en
#  el centro del cuerpo a ras de suelo) y el lienzo y los pies de su horneado (rata 1,20 -> 48 x 48; rey 1,70 ->
#  66 x 66, los pies en el centro), para que el juego lo coloque igual.
#  EL REY: la misma rata, mas grande, con la CICATRIZ roja cruzandole el ojo, la OREJA RASGADA y la COLA ANUDADA.
#  Uso: python tools/sprites_sdf/rata_sdf.py vistas      -> tools/salida/sdf/rata_vs_viejo.png (y la del rey)
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/rata_sdf/'
SALIDA_REY = 'assets/sprites/enemigos/rata_rey_sdf/'
VISTAS = 'tools/salida/sdf/'
ESTIRA = 1.0

def Z(x, y, z):
    return np.array([x, y, z * ESTIRA], dtype=float)

# Los tonos de la rata vieja con su color de la prueba (806a55): pelo en tres tonos, rosa por dentro de las orejas,
# en el hocico, las manos y la cola pelada, y los ojos negros de roedor.
MAT = {
    'pelo':    [(0.34, 0.28, 0.21), (0.50, 0.42, 0.33), (0.63, 0.55, 0.45)],
    'vientre': [(0.44, 0.38, 0.31), (0.58, 0.51, 0.42), (0.68, 0.62, 0.53)],
    'rosa':    [(0.55, 0.36, 0.36), (0.72, 0.50, 0.50), (0.84, 0.64, 0.62)],
    'cola':    [(0.38, 0.28, 0.26), (0.52, 0.40, 0.37), (0.62, 0.50, 0.46)],
    'diente':  [(0.80, 0.76, 0.62), (0.93, 0.90, 0.78), (0.99, 0.97, 0.88)],
    'ojo':     [(0.06, 0.04, 0.04), (0.06, 0.04, 0.04), (0.06, 0.04, 0.04)],
    'brillo':  [(0.95, 0.93, 0.90), (0.95, 0.93, 0.90), (0.98, 0.97, 0.95)],
    'cicatriz': [(0.50, 0.09, 0.09), (0.66, 0.13, 0.12), (0.78, 0.22, 0.20)],
    'oro':     [(0.62, 0.42, 0.10), (0.86, 0.66, 0.20), (0.99, 0.88, 0.45)],
    'rubi':    [(0.70, 0.08, 0.10), (0.70, 0.08, 0.10), (0.92, 0.30, 0.30)],
}
MODELO = Modelo(1.2, (48, 48), (24, 24), MAT, (0.12, 0.09, 0.07), suaves=('cuerpo',), brillan=('ojo', 'brillo', 'cicatriz'),
                estira=ESTIRA, corta_suelo=True)
MODELO_REY = Modelo(1.7, (66, 66), (33, 33), MAT, (0.12, 0.09, 0.07), suaves=('cuerpo',),
                    brillan=('ojo', 'brillo', 'cicatriz', 'rubi'), estira=ESTIRA, corta_suelo=True)

NUCA = Z(0, 4.4, 3.0)


def POSE(**k):
    # Los parametros del viejo (rata_sprites.gd), con sus mismas unidades:
    #   agacha    + se aplasta contra el suelo, - se alza (sobre las traseras)   estira  largo del cuerpo (1 = reposo)
    #   cuello    + la cabeza se lanza adelante (morder)                       cabeza_lado  sacude la cabeza de lado
    #   rumbo     giro extra en planta (rad)        abre_patas  patas estiradas adelante y atras (el salto)
    #   tumba     se vuelca de lado (2 = panza arriba)   apoyo  sube del suelo     cola  el meneo de la cola
    p = dict(avance=0.0, agacha=0.0, estira=1.0, cuello=0.0, cabeza_lado=0.0, rumbo=0.0, abre_patas=0.0, tumba=0.0,
             apoyo=0.0, patas=0.0, cola=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    ag = p['agacha']
    # El cuerpo: se estira a lo largo, se aplasta (agacha +) o se empina sobre las traseras (agacha -).
    M = np.diag([1.0 + 0.08 * max(ag, 0.0), p['estira'], 1.0 - 0.28 * max(ag, 0.0)])
    raiz = (M, np.array([0.0, p['avance'], p['apoyo'] * 0.4]))
    raiz = comp(sobre(Z(0, -3.0, 0), rx(-max(-ag, 0.0) * 0.45)), raiz)
    # VOLCARSE: rueda sobre su eje largo (la tumba del viejo: 2 = panza arriba), a la altura del lomo.
    if p['tumba'] != 0.0:
        raiz = comp(sobre(Z(0, 0, 2.6), ry(p['tumba'] * math.pi * 0.5)), raiz)
    raiz = comp((rz(p['rumbo']), np.zeros(3)), raiz)
    X['raiz'] = raiz
    # LA CABEZA: 'cuello' la lanza adelante y un poco abajo (el mordisco); 'cabeza_lado' la sacude.
    cu = p['cuello']
    cab = comp((np.eye(3), np.array([0.0, cu * 1.3, -max(cu, 0.0) * 0.3])),
               comp(sobre(NUCA, rz(p['cabeza_lado'] * 0.35)), sobre(NUCA, rx(cu * 0.10))))
    X['cabeza'] = comp(raiz, cab)
    # La mandibula: se abre al lanzarse y se cierra al morder.
    X['boca'] = comp(X['cabeza'], sobre(Z(0, 7.4, 1.8), rx(max(cu, 0.0) * 0.35)))
    for s_, ld in ((-1, 'd'), (1, 'i')):
        for y0, dt in ((3.1, 'del'), (-2.8, 'tras')):
            a = -0.7 * p['patas'] * (1 if (s_ > 0) == (dt == 'del') else -1)
            # El salto: las de delante se estiran hacia delante y las de detras hacia atras.
            a += (-1.0 if dt == 'del' else 1.0) * p['abre_patas']
            X['pata_%s_%s' % (dt, ld)] = comp(raiz, sobre(Z(3.0 * s_, y0, 2.0), rx(a)))
    X['cola'] = raiz
    return X


def _cola_x(u, cola):
    # El meneo: una onda que la recorre (la del viejo, 'cola' es cuanto se sacude de lado).
    return (math.sin(u * 3.2) * 0.8 + cola * math.sin(u * 2.4)) * 1.4 * u


def _cola(add, p, rey):
    # LA COLA: cadena que nace de la grupa a la altura del cuerpo y cae hasta arrastrar, serpeando. La del rey, con un
    # NUDO (un lazo cerrado a media cola).
    n = 14
    prev = Z(0, -5.4, 2.3)
    for k in range(1, n + 1):
        u = k / n
        x = _cola_x(u, p['cola'])
        y = -5.4 - u * 10.5
        z = 2.3 + (0.55 - 2.3) * min(1.0, u * 1.6)
        pt = Z(x, y, z)
        r0 = 1.3 - 0.55 * (k - 1) / n
        r1 = 1.3 - 0.55 * u
        add(lambda P, a=prev, b=pt, ra=r0, rb=r1: sd_cono(P, a, b, ra, rb), 'cola', 0, 'cola', 'cola')
        prev = pt
    if rey:
        c = Z(_cola_x(0.5, p['cola']), -5.4 - 0.5 * 10.5, 0.6)
        for k in range(8):
            a0 = k / 8 * 2 * math.pi; a1 = (k + 1) / 8 * 2 * math.pi
            q0 = c + np.array([math.cos(a0) * 1.7, math.sin(a0) * 1.4, 0.4])
            q1 = c + np.array([math.cos(a1) * 1.7, math.sin(a1) * 1.4, 0.4])
            add(lambda P, a=q0, b=q1: sd_cono(P, a, b, 0.85, 0.85), 'cola', 0, 'cola', 'cola')


def escena(pose, rey=False):
    e = Escena(huesos(pose))
    add = e.add
    # EL CUERPO: una pera tumbada, ancha en las ancas y que se estrecha hacia los hombros; el lomo alto.
    add(lambda P: sd_elipsoide(P, Z(0, -1.2, 2.7), np.array([4.0, 5.0, 2.8])), 'pelo', 0)
    add(lambda P: sd_elipsoide(P, Z(0, 2.6, 2.6), np.array([3.0, 3.4, 2.4])), 'pelo', 1.6)
    # La tripa, mas clara, por debajo.
    add(lambda P: sd_elipsoide(P, Z(0, 0.2, 1.4), np.array([3.0, 4.6, 1.3])), 'vientre', 1.0)
    # LA CABEZA: una cuña que acaba en punta en el hocico, con la nariz rosa.
    add(lambda P: sd_elipsoide(P, Z(0, 5.6, 2.9), np.array([2.6, 2.6, 2.2])), 'pelo', 1.4, hueso='cabeza')
    add(lambda P: sd_cono(P, Z(0, 6.2, 2.7), Z(0, 8.9, 2.0), 2.0, 0.8), 'pelo', 1.0, hueso='cabeza')
    add(lambda P: sd_esfera(P, Z(0, 9.4, 2.1), 0.65), 'rosa', 0, 'nariz', 'cabeza')
    # Los incisivos: dos palas amarillentas que asoman bajo el hocico (su cosa es morder).
    for s in (-1, 1):
        add(lambda P, s=s: sd_cono(P, Z(0.28 * s, 8.4, 1.3), Z(0.3 * s, 8.6, 0.55), 0.32, 0.26), 'diente', 0, 'diente',
            'boca')
    for s in (-1, 1):
        # LAS OREJAS: redondas y grandes, de canto hacia delante, ROSA por dentro. La del rey (la izquierda) RASGADA:
        # le falta un bocado del borde.
        oc = Z(2.3 * s, 4.4, 5.6)
        rasgada = rey and s > 0
        def oreja(P, oc=oc, s=s, rasgada=rasgada):
            d = sd_elipsoide(P, oc, np.array([2.0, 1.0, 2.0]))
            if rasgada:
                d = np.maximum(d, -sd_esfera(P, oc + np.array([1.1 * s, 0.0, 1.2]), 0.95))
            return d
        add(oreja, 'pelo', 0, 'oreja', 'cabeza')
        def oreja_int(P, oc=oc, s=s, rasgada=rasgada):
            d = sd_elipsoide(P, oc + np.array([0.0, 0.6, 0.0]), np.array([1.4, 0.55, 1.4]))
            if rasgada:
                d = np.maximum(d, -sd_esfera(P, oc + np.array([1.1 * s, 0.0, 1.2]), 0.95))
            return d
        add(oreja_int, 'rosa', 0, 'oreja', 'cabeza')
        # LOS OJOS: negros y saltones, ASOMANDO de la cabeza, con un punto de brillo.
        add(lambda P, s=s: sd_esfera(P, Z(1.8 * s, 7.0, 3.5), 0.72), 'ojo', 0, 'ojo', 'cabeza')
        add(lambda P, s=s: sd_esfera(P, Z(2.05 * s, 7.3, 3.9), 0.25), 'brillo', 0, 'ojo', 'cabeza')
    if rey:
        # LA CICATRIZ: una raja roja que le cruza el ojo derecho, de la frente a la mejilla.
        add(lambda P: sd_cono(P, Z(-1.2, 6.0, 4.9), Z(-2.4, 7.9, 2.3), 0.38, 0.32), 'cicatriz', 0, 'cicatriz', 'cabeza')
        # LA CORONA DE ORO (05/10, la pidio el jefe): un aro entre las orejas, un poco ladeada, con cinco puntas y un
        # rubi delante (rojo, como la cicatriz y la sangre de lo suyo).
        cc = Z(0.3, 5.0, 5.9)
        aro = lambda P, c=cc: np.maximum(np.abs(sd_elipsoide(P, c, np.array([2.4, 2.4, 1.0]))) - 0.45, np.abs(P[:, 2] - c[2]) - 0.8)
        add(aro, 'oro', 0, 'corona', 'cabeza')
        for k in range(5):
            a = k / 5 * 2 * math.pi + math.pi / 2
            b = cc + np.array([math.cos(a) * 2.2, math.sin(a) * 2.2, 0.5])
            add(lambda P, a=b, b=b + np.array([math.cos(a) * 0.3, math.sin(a) * 0.3, 2.0]): sd_cono(P, a, b, 0.6, 0.22),
                'oro', 0, 'corona', 'cabeza')
            add(lambda P, c=b + np.array([0, 0, 2.2]): sd_esfera(P, c, 0.34), 'oro', 0, 'corona', 'cabeza')
        add(lambda P: sd_esfera(P, cc + np.array([0.0, 2.5, 0.0]), 0.55), 'rubi', 0, 'corona', 'cabeza')
    # LAS PATAS: cortas y metidas bajo el cuerpo; las MANOS rosas.
    for s, ld in ((-1, 'd'), (1, 'i')):
        for y0, dt in ((3.1, 'del'), (-2.8, 'tras')):
            h = 'pata_%s_%s' % (dt, ld)
            gord = 1.0 if dt == 'del' else 1.25
            add(lambda P, a=Z(3.0 * s, y0, 2.0), b=Z(3.2 * s, y0 + 0.3, 0.6), g=gord: sd_cono(P, a, b, g, g * 0.7), 'pelo',
                0.8, hueso=h)
            add(lambda P, c=Z(3.2 * s, y0 + 0.8, 0.35): sd_elipsoide(P, c, np.array([0.85, 1.15, 0.4])), 'rosa', 0,
                'mano', h)
    _cola(add, pose, rey)
    return e.L


def escena_rey(pose):
    return escena(pose, True)


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo; las mismas para la rata y el rey)
# ------------------------------------------------------------
TAU = 2 * math.pi


def anim_idle(t):
    return POSE(estira=1.0 + 0.025 * math.sin(TAU * t), cola=0.45 * math.sin(TAU * t))


def anim_walk(t):
    return POSE(estira=1.0 + 0.05 * math.sin(TAU * t * 2.0), cola=1.0 * math.sin(TAU * t), patas=math.sin(TAU * t))


def anim_embestida(t):
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.25, -1.2), (0.55, 5.0), (0.75, 5.8), (1.0, 4.0)]),
                estira=tramos(t, [(0.0, 1.0), (0.25, 0.82), (0.55, 1.2), (0.75, 0.9), (1.0, 1.0)]),
                cola=1.4 * math.sin(TAU * t * 1.5),
                agacha=tramos(t, [(0.0, 0.0), (0.25, 1.0), (0.55, 0.0), (0.75, 0.35), (1.0, 0.1)]))


def anim_chillido(t):
    # Se alza sobre las traseras y chilla con la cabeza arriba.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.143, 0.45), (0.286, -0.55), (0.429, -0.85), (0.571, -0.90),
                                  (0.714, -0.80), (0.857, -0.40), (1.0, 0.0)]),
                estira=tramos(t, [(0.0, 1.0), (0.143, 0.88), (0.286, 1.14), (0.429, 1.22), (0.571, 1.20), (0.714, 1.12),
                                  (0.857, 1.04), (1.0, 1.0)]),
                cuello=tramos(t, [(0.0, 0.0), (0.286, -0.6), (0.571, -0.8), (1.0, 0.0)]),
                cola=1.8 * math.sin(TAU * t * 2.0) * (1.0 - t * 0.5))


def anim_basico(t):
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.25, -0.3), (0.45, 1.0), (0.62, 0.9), (1.0, 0.0)]),
                estira=tramos(t, [(0.0, 1.0), (0.25, 0.92), (0.45, 1.08), (1.0, 1.0)]),
                cola=0.8 * math.sin(TAU * t),
                agacha=tramos(t, [(0.0, 0.0), (0.25, 0.35), (0.45, 0.05), (1.0, 0.0)]),
                cuello=tramos(t, [(0.0, 0.0), (0.25, -0.6), (0.45, 1.5), (0.62, 1.3), (1.0, 0.0)]))


def anim_desgarro(t):
    lado = tramos(t, [(0.0, 0.0), (0.4, 0.0), (0.5, 1.1), (0.6, -1.1), (0.7, 1.0), (0.8, -0.8), (0.9, 0.0), (1.0, 0.0)])
    p = anim_basico(min(t * 1.2, 0.5) if t < 0.42 else 0.5)
    p.update(cuello=tramos(t, [(0.0, 0.0), (0.22, -0.6), (0.4, 1.4), (0.85, 1.2), (1.0, 0.0)]), cabeza_lado=lado,
             avance=tramos(t, [(0.0, 0.0), (0.4, 0.9), (0.85, 0.7), (1.0, 0.0)]), rumbo=lado * 0.12,
             cola=1.4 * math.sin(TAU * t * 2.0))
    return p


def anim_agazapado(t):
    return POSE(avance=0.25 * math.sin(TAU * t * 2.0), estira=0.86 + 0.02 * math.sin(TAU * t * 4.0),
                cola=1.6 * math.sin(TAU * t * 2.0), agacha=0.82, cuello=-0.4, cabeza_lado=0.3 * math.sin(TAU * t * 3.0))


def anim_salto_rata(t):
    return POSE(estira=tramos(t, [(0.0, 0.86), (0.3, 1.3), (1.0, 1.25)]), cola=0.6 * math.sin(TAU * t),
                agacha=tramos(t, [(0.0, 0.82), (0.3, -0.15), (1.0, -0.1)]),
                abre_patas=tramos(t, [(0.0, 0.0), (0.3, 1.0), (1.0, 1.0)]),
                cuello=tramos(t, [(0.0, -0.4), (0.3, 0.9), (1.0, 1.0)]))


def anim_frenesi(t):
    lado = tramos(t, [(0.0, 0.0), (0.2, -1.0), (0.4, 1.0), (0.6, -0.6), (1.0, 0.0)])
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.4, 0.7), (1.0, 0.0)]), cola=1.8 * math.sin(TAU * t * 2.0),
                patas=0.6 * math.sin(TAU * t * 2.0), agacha=0.3,
                cuello=tramos(t, [(0.0, 0.2), (0.4, 1.4), (1.0, 0.2)]), cabeza_lado=lado, rumbo=lado * 0.3)


def anim_dentellada(t):
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.3, -0.5), (0.5, 2.0), (0.7, 1.9), (1.0, 0.6)]),
                estira=tramos(t, [(0.0, 1.0), (0.3, 0.9), (0.5, 1.15), (0.7, 1.1), (1.0, 1.0)]),
                cola=1.2 * math.sin(TAU * t),
                patas=0.7 * math.sin(math.pi * min(max((t - 0.3) / 0.4, 0.0), 1.0)),
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.45), (0.5, 0.0), (1.0, 0.0)]),
                cuello=tramos(t, [(0.0, 0.0), (0.3, -0.8), (0.5, 1.7), (0.7, 1.5), (1.0, 0.0)]))


# El REY, estirandose como la rata (1,35), se salia del lienzo de 66 mirando al E y al O: el estiron, mas corto en el.
ESTIRON_YUGULAR = 0.22 if os.environ.get('RATA_VAR') == 'rey' else 0.35


def anim_yugular(t):
    k = ESTIRON_YUGULAR / 0.35
    return POSE(estira=tramos(t, [(0.0, 1.0), (0.3, 0.84), (0.45, 1.0 + 0.35 * k), (1.0, 1.0 + 0.3 * k)]),
                cola=0.9 * math.sin(TAU * t),
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.9), (0.45, -0.1), (1.0, -0.05)]),
                abre_patas=tramos(t, [(0.0, 0.0), (0.3, 0.0), (0.45, 1.0), (1.0, 1.0)]),
                cuello=tramos(t, [(0.0, 0.0), (0.3, -0.5), (0.45, 1.3), (1.0, 1.4)]))


def anim_zarandeo(t):
    lado = tramos(t, [(0.0, 0.0), (0.15, 1.2), (0.3, -1.2), (0.45, 1.1), (0.6, -1.0), (0.8, 0.4), (1.0, 0.0)])
    suelta = min(max((t - 0.75) / 0.25, 0.0), 1.0)
    return POSE(avance=0.6 * (1.0 - suelta), estira=1.12 + (1.0 - 1.12) * suelta, cola=1.5 * math.sin(TAU * t * 2.0),
                agacha=0.15 * (1.0 - suelta), cuello=1.4 * (1.0 - suelta), cabeza_lado=lado, rumbo=lado * 0.2)


def anim_muerte(t):
    # Le fallan las patas, se vuelca PANZA ARRIBA (la tumba del viejo, hasta 2) girando un cuarto en planta.
    return POSE(estira=tramos(t, [(0.0, 1.0), (0.14, 0.86), (0.28, 1.05), (1.0, 1.0)]),
                cola=0.9 * (1.0 - min(t * 2.2, 1.0)),
                agacha=tramos(t, [(0.0, 0.15), (0.14, 0.62), (0.28, 0.30), (0.45, 0.0), (1.0, 0.0)]),
                tumba=tramos(t, [(0.0, 0.0), (0.14, 0.0), (0.28, 0.45), (0.45, 1.25), (0.62, 1.85), (0.78, 2.12),
                                 (0.90, 1.94), (1.0, 2.0)]),
                rumbo=tramos(t, [(0.0, 0.0), (0.14, 0.10), (0.28, 0.45), (0.45, 0.80), (0.62, 0.95), (1.0, 1.0)]) * math.pi * 0.5,
                apoyo=tramos(t, [(0.0, 0.0), (0.14, 0.0), (0.28, 1.4), (0.45, 3.4), (0.62, 4.7), (0.78, 5.3), (0.90, 5.1),
                                 (1.0, 5.2)]))


def anim_encaje(t):
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.52), (0.67, 0.16), (1.0, 0.0)]) * 1.9,
                estira=tramos(t, [(0.0, 0.80), (0.34, 1.10), (0.67, 0.96), (1.0, 1.0)]),
                cola=tramos(t, [(0.0, 1.6), (0.34, -0.9), (0.67, 0.4), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.85), (0.34, 0.20), (0.67, 0.06), (1.0, 0.0)]))


ANIMS = {
    'idle': (8, 5.0, True, 8, anim_idle),
    'walk': (8, 10.0, True, 8, anim_walk),
    'embestida': (8, 11.0, False, 8, anim_embestida),
    'chillido': (8, 10.0, False, 8, anim_chillido),
    'basico': (8, 16.0, False, 8, anim_basico),
    'desgarro': (11, 16.0, False, 8, anim_desgarro),
    'agazapado': (8, 12.0, True, 8, anim_agazapado),
    'salto_rata': (8, 12.0, False, 8, anim_salto_rata),
    'frenesi': (6, 20.0, False, 8, anim_frenesi),
    'dentellada': (8, 13.0, False, 8, anim_dentellada),
    'yugular': (8, 12.0, False, 8, anim_yugular),
    'zarandeo': (12, 16.0, False, 8, anim_zarandeo),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}

# RATA_VAR=rey: el mismo script hornea al REY (su modelo, su lienzo y su carpeta); hornear() lee MODELO y escena.
_escena_base = escena
if os.environ.get('RATA_VAR') == 'rey':
    MODELO = MODELO_REY
    SALIDA = SALIDA_REY

    def escena(pose):
        return _escena_base(pose, True)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'rata_806a55_1.20', VISTAS + 'rata_vs_viejo.png', 5))
        fotos = [render(MODELO_REY, escena_rey(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'rata_aa8a55_1.70_rey', VISTAS + 'rata_rey_vs_viejo.png', 5))
    else:
        hornear('rata_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
