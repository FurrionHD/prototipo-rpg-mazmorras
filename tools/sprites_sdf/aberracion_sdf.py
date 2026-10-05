# ============================================================
#  aberracion_sdf.py -- la ABERRACION en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (aberracion_sprites.gd): NO TIENE ESQUELETO. Una MASA derramada que se arrastra (bulbo ancho abajo, dos LOBULOS
#  descolocados y una JOROBA trasera: la simetria es de los animales, no de esto; y no puede parecer una bola, que
#  eso ya es el slime), UN OJO enorme alto y delante (globo, iris y pupila que sobresalen: sin eso no hay MIRADA),
#  las FAUCES en hendidura debajo, con dientes, y SEIS TENTACULOS gruesos que caen y se arrastran por el suelo.
#  Morada, con el brillo HUMEDO que tira a rosa lechoso (gris seria piedra).
#  Lienzo y origen de su horneado (1,80 -> 102 x 102, el centro).
#  SIN HUESOS: lo que se mueve es la MASA (se hincha, se aplasta, se desinfla) y eso se hace cambiando las formas en
#  escena() -- aplastar con la escala de un hueso agujerea el raymarch. LOS TIEMPOS, los del viejo.
#  Uso: python tools/sprites_sdf/aberracion_sdf.py [anim ...]  -> assets/sprites/enemigos/aberracion_sdf/<anim>.png
#       python tools/sprites_sdf/aberracion_sdf.py vistas     -> tools/salida/sdf/aberracion_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/aberracion_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Morado (754080). La carne con su brillo HUMEDO (cuarto tono, rosa lechoso); los tentaculos algo mas oscuros con las
# VENTOSAS palidas por debajo.
MAT = {
    'carne':   [(0.30, 0.15, 0.34), (0.46, 0.25, 0.51), (0.58, 0.35, 0.63), (0.86, 0.68, 0.86)],
    'tent':    [(0.24, 0.11, 0.27), (0.36, 0.18, 0.41), (0.48, 0.27, 0.53), (0.80, 0.62, 0.80)],
    'ventosa': [(0.62, 0.45, 0.60), (0.76, 0.58, 0.72), (0.86, 0.70, 0.82)],
    'vena':    [(0.36, 0.10, 0.28), (0.46, 0.14, 0.34), (0.54, 0.20, 0.40)],
    'globo':   [(0.86, 0.82, 0.68), (0.95, 0.92, 0.80), (1.00, 0.98, 0.90), (1.00, 1.00, 1.00)],
    'iris':    [(0.86, 0.52, 0.10), (0.95, 0.64, 0.16), (1.00, 0.78, 0.30)],
    'pupila':  [(0.06, 0.03, 0.05)] * 3,
    'fauces':  [(0.22, 0.04, 0.08), (0.34, 0.07, 0.11), (0.44, 0.10, 0.14)],
    'diente':  [(0.80, 0.76, 0.64), (0.92, 0.89, 0.78), (0.98, 0.96, 0.88)],
}
MODELO = Modelo(1.8, (102, 102), (51, 51), MAT, (0.12, 0.04, 0.12), suaves=('cuerpo',), brillan=('pupila',),
                corta_suelo=True, especular=('carne', 'tent', 'globo'), umbral_especular=0.90)

BULBO = V((0.0, 0.0, 5.6))
OJO = V((0.0, 5.0, 9.4))
BOCA = V((0.0, 6.0, 4.4))
TENTACULOS = 6
TENT_NACE_R = 4.6
TENT_NACE_Z = 4.2
TENT_PASO = 1.15
TENT_SEGMENTOS = 11
LUNGE_DIST = 5.0
ENCAJE_RETRO = 0.42


def POSE(**k):
    # Las claves del viejo: palpita (se hincha -/+), aplasta (0..0,7 baja), desinfla (0..1 al morir: se ENSANCHA
    # mientras baja), onda (fase del vaiven de los tentaculos), azota (los de DELANTE se levantan y azotan; negativo:
    # se recogen), boca (0..1), parpado (0..1).
    p = dict(avance=0.0, palpita=0.0, aplasta=0.0, desinfla=0.0, onda=0.0, azota=0.0, boca=0.15, parpado=0.0)
    p.update(k)
    return p


def huesos(p):
    return {'raiz': (np.eye(3), V((0.0, p['avance'], 0.0)))}


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _unit(v):
    return v / np.linalg.norm(v)


def _volumen(p):
    """(ancho, alto) de la masa, como en el viejo: late con 'palpita', baja con 'aplasta' y al desinflarse se ENSANCHA
    mientras baja (lo de dentro tiene que ir a alguna parte; si no, se lee como que encoge)."""
    h = 1.0 + 0.06 * p['palpita']
    return h * (1.0 + 0.34 * p['desinfla']), h * (1.0 - 0.36 * p['aplasta']) * (1.0 - 0.62 * p['desinfla'])


def _tentaculo(add, p, i, an, al):
    """Por PASOS FIJOS: se avanza TENT_PASO en la direccion actual y despues se gira (asi no se descose). Nace metido
    en el bulbo, cae fuerte y se va aplanando hasta tenderse en el suelo; la punta se enrosca un poco hacia arriba.
    EL AZOTE VA EN EL ANGULO (como en el viejo): los de delante levantan el arranque; el paso no cambia."""
    # Repartidos alrededor, ninguno justo delante (ahi estan el ojo y las fauces) y algo descolocados.
    ang = math.radians(30.0 + 60.0 * i + (7.0, -5.0, 9.0, -8.0, 4.0, -6.0)[i])
    fuera = V((math.sin(ang), math.cos(ang), 0.0))
    lado = V((fuera[1], -fuera[0], 0.0))
    frontal = max(0.0, fuera[1])
    az = p['azota'] * frontal
    pt = V((0.0, 0.0, TENT_NACE_Z * al)) + fuera * TENT_NACE_R * an
    caida = min(1.45, 0.95 - az * 1.55)
    suelo = 0.0 if az <= 0.0 else -0.5 * az
    r0, r1 = 2.3, 1.0
    rr = r0
    enrosca = (0.9, -0.7, 0.8, -0.9, 0.7, -0.8)[i]
    for k in range(TENT_SEGMENTOS):
        u = k / (TENT_SEGMENTOS - 1)
        # Baja y se aplana hasta tenderse (nunca vuelve a subir si no azota: hacia atras, subir es un pincho en
        # pantalla); solo la punta se enrosca un pelo.
        caida = max(suelo, caida - 0.19) if k < TENT_SEGMENTOS - 2 else min(caida, -0.22)
        # Se CURVAN de lado (cada uno hacia un sitio) y ondulan, cada uno en su fase (si no, un ventilador).
        onda = enrosca * u * u + 0.45 * math.sin(math.pi * p['onda'] + i * 1.9 + k * 0.7) * u
        d = _unit(fuera * math.cos(caida) + V((0.0, 0.0, -math.sin(caida))) + lado * onda)
        q = pt + d * TENT_PASO
        q[2] = max(q[2], r1 * 0.9 + (rr - r1) * 0.55)
        rb = r0 + (r1 - r0) * min(1.0, (k + 1) / (TENT_SEGMENTOS - 1))
        _cono(add, pt, q, rr, rb, 'tent', 1.2 if k < 2 else 0.5)
        # Las VENTOSAS por la cara de abajo, a partir de medio tentaculo (solo asoman donde se levanta).
        if 3 <= k <= 9 and k % 2 == 1:
            _elip(add, q - V((0.0, 0.0, rb * 0.62)), (rb * 0.55, rb * 0.55, rb * 0.42), 'ventosa', 0, 'ventosa')
        pt = q; rr = rb


def escena(pose):
    p = pose
    e = Escena(huesos(p)); add = e.add
    an, al = _volumen(p)
    T = lambda c: V((c[0] * an, c[1] * an, c[2] * al))
    R = lambda r: V((r[0] * an, r[1] * an, r[2] * al))
    # --- LA MASA: bulbo derramado, ancho abajo; dos lobulos DESCOLOCADOS y la joroba alta y trasera.
    _elip(add, T(BULBO), R((7.2, 6.6, 5.4)), 'carne', 0)
    _elip(add, T((0.0, -0.4, 2.0)), R((8.0, 7.4, 2.4)), 'carne', 2.5)
    _elip(add, T((4.4, -3.0, 8.4)), R((3.8, 4.0, 3.6)), 'carne', 2.6)
    _elip(add, T((-4.8, 1.6, 7.0)), R((3.4, 3.6, 3.2)), 'carne', 2.6)
    _elip(add, T((-0.8, -2.8, 10.6)), R((4.2, 3.8, 3.2)), 'carne', 3.0)
    # Bultos pequeños y VENAS por encima: lo que la saca de ser una bola lisa de gel.
    _elip(add, T((2.2, -5.4, 6.2)), R((1.8, 1.6, 1.6)), 'carne', 1.2)
    _elip(add, T((-3.6, -4.6, 9.4)), R((1.5, 1.5, 1.3)), 'carne', 1.0)
    for a, b in (((-1.0, -1.0, 13.4), (3.6, -4.6, 11.4)), ((-1.5, -1.5, 13.3), (-5.4, 0.6, 9.8)),
                 ((0.5, -4.0, 12.6), (1.8, -7.6, 7.6))):
        _cono(add, T(a), T(b), 0.42, 0.3, 'vena', 0, 'vena')
    # --- EL OJO: enorme, alto y delante. Globo, iris y pupila (rasgada) que SOBRESALEN hacia delante: sin eso, de
    # perfil parece mirar siempre de frente. No se aplasta con la masa (un ojo aplastado deja de ser un ojo): baja con
    # ella y, al desinflarse, se queda asomando. Al morir la pupila se DILATA hasta comerse el iris.
    oj = V((OJO[0], OJO[1] * an, OJO[2] * al + 1.6 * p['desinfla']))
    dil = 1.0 + 0.3 * p['desinfla']
    _elip(add, oj, (3.3, 2.7, 3.2), 'globo', 0, 'ojo')
    _elip(add, oj + V((0.0, 1.65, 0.05)), (1.9, 1.3, 1.85), 'iris', 0, 'ojo')
    _elip(add, oj + V((0.0, 2.5, 0.05)), (0.55 + 1.0 * p['desinfla'], 0.6, min(1.75, 1.35 * dil)), 'pupila', 0, 'ojo')
    # La cuenca: un rodete de carne alrededor del ojo (lo engasta en la masa; suelto parecia una canica).
    _elip(add, oj + V((0.0, -1.8, 1.2)), (3.7, 2.4, 2.3), 'carne', 1.2)
    # EL PARPADO: baja de la cuenca y tapa el ojo (cerrado del todo con 1).
    if p['parpado'] > 0.02:
        _elip(add, oj + V((0.0, 0.7, 3.8 - 3.6 * p['parpado'])), (3.55, 2.55, 2.5), 'carne', 0, 'parpado')
    # --- LAS FAUCES: hendidura vertical debajo del ojo, con dientes arriba y abajo; el alarido las abre del todo.
    # (Con MUCHO recorrido: en el alarido "la boca es todo el gesto", y abriendo lo justo no se notaba.)
    ab = 0.6 + 2.0 * p['boca']
    bo = V((BOCA[0], BOCA[1] * an, max(1.4, BOCA[2] * al)))
    ancho = 2.5 + 0.7 * p['boca']
    _elip(add, bo + V((0.0, 0.4 + 0.3 * p['boca'], 0.0)), (ancho, 1.4, 0.7 + ab * 0.8), 'fauces', 0, 'boca')
    for j in range(5):
        x = (-1.9 + 0.95 * j) * ancho / 2.5
        for sz in (1, -1):
            c = bo + V((x, 1.5 + 0.3 * p['boca'] - 0.25 * abs(x), sz * (0.55 + ab * 0.75)))
            _cono(add, c, c - V((0.0, 0.0, sz * (0.95 + 0.3 * p['boca']))), 0.45, 0.1, 'diente', 0, 'boca')
    # --- LOS SEIS TENTACULOS.
    for i in range(TENTACULOS):
        _tentaculo(add, p, i, an, al)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # PALPITA y parpadea una vez; los tentaculos ondulan a la mitad (los dos ritmos no se sincronizan).
    w = 2 * math.pi * t
    return POSE(palpita=math.sin(w), onda=math.sin(w * 0.5),
                parpado=tramos(t, [(0.0, 0.0), (0.60, 0.0), (0.70, 1.0), (0.80, 0.0), (1.0, 0.0)]),
                boca=0.12 + 0.10 * math.sin(w))


def anim_walk(t):
    # SE ARRASTRA a tirones: se aplasta y tira; los tentaculos ondulan al doble.
    w = 2 * math.pi * t
    return POSE(aplasta=0.22 * (1 - math.cos(w)), palpita=0.7 * math.sin(w + math.pi * 0.5), onda=math.sin(w),
                boca=0.15)


def anim_embestida(t):
    # ENCOGERSE -> AZOTAR con los de delante -> recoger; las fauces se abren del todo en el golpe.
    az = tramos(t, [(0.0, 0.0), (0.30, -0.55), (0.55, 1.0), (0.78, 0.75), (1.0, 0.0)])
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.30, -1.8), (0.55, 3.6), (0.75, 5.0), (1.0, 2.4)]) * (LUNGE_DIST / 5.0),
                palpita=tramos(t, [(0.0, 0.0), (0.30, -1.4), (0.55, 1.6), (0.75, 0.8), (1.0, 0.0)]),
                azota=az, boca=tramos(t, [(0.0, 0.15), (0.30, 0.45), (0.55, 1.0), (0.78, 0.85), (1.0, 0.2)]),
                aplasta=0.20 * max(0.0, -az))


def anim_basico(t):
    # EL LATIGAZO CORTO: se encoge y SUELTA sin avanzar (el tentaculo que pega es el efecto).
    az = tramos(t, [(0.0, 0.0), (0.2, -0.3), (0.37, 0.35), (0.6, 0.15), (1.0, 0.0)])
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.2, -1.2), (0.37, 1.2), (0.6, 0.6), (1.0, 0.0)]),
                palpita=tramos(t, [(0.0, 0.0), (0.2, -1.0), (0.37, 1.1), (0.6, 0.4), (1.0, 0.0)]),
                azota=az, boca=tramos(t, [(0.0, 0.15), (0.2, 0.25), (0.37, 0.38), (1.0, 0.15)]),
                aplasta=0.2 * max(0.0, -az))


def anim_alarido(t):
    # EL ALARIDO: abre las fauces DEL TODO, se HINCHA y la masa vibra; no va a ningun sitio.
    return POSE(palpita=tramos(t, [(0.0, 0.0), (0.143, -0.9), (0.286, 1.4), (0.429, 1.8), (0.571, 1.7), (0.714, 1.5),
                                   (0.857, 0.7), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.15), (0.143, 0.05), (0.286, 0.90), (0.429, 1.0), (0.571, 1.0), (0.714, 1.0),
                                (0.857, 0.55), (1.0, 0.2)]),
                onda=tramos(t, [(0.0, 0.0), (0.143, 0.3), (0.286, -0.9), (0.429, 0.9), (0.571, -0.8), (0.714, 0.7),
                                (0.857, -0.3), (1.0, 0.0)]),
                parpado=0.0)


def anim_mirada(t):
    # LA MIRADA: parpadea una vez y se queda TIESA, con el ojo abierto de par en par.
    return POSE(palpita=tramos(t, [(0.0, 0.0), (0.143, -0.7), (0.286, 0.8), (0.429, 1.1), (0.571, 1.0), (0.714, 0.9),
                                   (0.857, 0.4), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.15), (0.143, 0.08), (0.286, 0.10), (0.571, 0.10), (1.0, 0.15)]),
                parpado=tramos(t, [(0.0, 0.0), (0.143, 1.0), (0.286, 0.0), (1.0, 0.0)]),
                onda=tramos(t, [(0.0, 0.0), (0.143, 0.6), (0.286, 0.3), (0.429, 0.10), (0.571, 0.0), (0.714, 0.0),
                                (0.857, 0.1), (1.0, 0.0)]))


def anim_encaje(t):
    # BLANDA: empieza ya golpeada, aplastada y echada atras, y rebota.
    retro = tramos(t, [(0.0, 1.0), (0.34, 0.45), (0.67, 0.12), (1.0, 0.0)])
    return POSE(avance=-retro * LUNGE_DIST * ENCAJE_RETRO,
                aplasta=tramos(t, [(0.0, 0.70), (0.34, 0.10), (0.67, 0.22), (1.0, 0.0)]),
                palpita=tramos(t, [(0.0, -1.6), (0.34, 1.1), (0.67, -0.4), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.9), (0.34, 0.6), (0.67, 0.3), (1.0, 0.15)]), azota=-0.35 * retro)


def anim_muerte(t):
    # Un ultimo espasmo y SE DESINFLA: se ensancha mientras baja, la boca abierta y el parpado a medias.
    des = tramos(t, [(0.0, 0.0), (0.18, 0.15), (0.38, 0.5), (0.60, 0.82), (0.82, 0.96), (1.0, 1.0)])
    return POSE(desinfla=des,
                palpita=tramos(t, [(0.0, 0.0), (0.14, 1.3), (0.30, -0.6), (0.55, -1.4), (1.0, -1.8)]),
                aplasta=tramos(t, [(0.0, 0.0), (0.18, 0.12), (0.38, 0.42), (0.60, 0.68), (1.0, 0.80)]),
                boca=tramos(t, [(0.0, 0.2), (0.14, 1.0), (0.38, 0.85), (1.0, 0.7)]),
                parpado=tramos(t, [(0.0, 0.0), (0.38, 0.1), (0.60, 0.35), (1.0, 0.55)]), azota=-0.20 * des)


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo. El cadaver sale del ultimo de 'muerte'.
ANIMS = {
    'idle': (8, 4.0, True, 8, anim_idle),
    'walk': (8, 6.0, True, 8, anim_walk),
    'embestida': (8, 12.0, False, 8, anim_embestida),
    'basico': (8, 16.0, False, 8, anim_basico),
    'alarido': (8, 9.0, False, 8, anim_alarido),
    'mirada': (8, 9.0, False, 8, anim_mirada),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 9.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'aberracion_754080_1.80', VISTAS + 'aberracion_vs_viejo.png', 3))
    else:
        hornear('aberracion_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
