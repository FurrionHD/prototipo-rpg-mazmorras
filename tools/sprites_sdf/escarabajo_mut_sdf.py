# ============================================================
#  escarabajo_mut_sdf.py -- LOS MUTANTES DEL ESCARABAJO DE HIERRO, con sus animaciones (04/11/2026, escarabajo-mutante).
#  Los cuerpos son los elegidos en escarabajo_mutantes_versiones.py:
#    ESC_VAR=iman     ESCARABAJO IMAN   iman_a1: anda; el iman va en la cabeza, cabecea con ella.
#    ESC_VAR=saeta    ESCARABAJO SAETA  volador_c2: siempre en el aire, con sombra; aletea (huesos de ala y de elitro).
#    ESC_VAR=errante  IMAN ERRANTE      mezcla_a: la saeta de hierro con la herradura por mandibulas.
#  Solo las animaciones que usa cada uno:
#    iman     idle walk basico caparazon embestir_carga embestir pulso_carga pulso encaje muerte comer evolucion
#    saeta    idle walk basico pasada elitros subir aire picado caer volteado recolocarse encaje muerte comer evolucion
#    errante  idle walk basico pasada subir aire picado caer volteado recolocarse pulso_carga pulso encaje muerte comer evolucion evolucion_saeta
#  Uso: ESC_VAR=iman python tools/sprites_sdf/escarabajo_mut_sdf.py [anim ...] -> assets/sprites/enemigos/escarabajo_sdf_iman/
#       python tools/sprites_sdf/escarabajo_mut_sdf.py hoja iman|saeta|errante -> la hoja para mirarla, al escritorio
# ============================================================
import sys, os, math, json
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import escarabajo_versiones as base
import escarabajo_mutantes_versiones as ver
import escarabajo_sdf as normal

V = np.array
VAR = os.environ.get('ESC_VAR', 'iman')
SALIDA = 'assets/sprites/enemigos/escarabajo_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/'
Z = ver.Z_AIRE
ALTO_SUBIDA = 22.0      # lo que sube para el Picado
CUELLO = V((0.0, 4.0, 3.0))
PASO_LARGO = 1.5
PASO_ALTO = 1.1

# LA TRANSICION DE COLOR (04/11, el jefe: "no haces transiciones de color"): en la evolucion el color no salta, se mezcla
# poco a poco. El motor no mezcla materiales, asi que van en PASOS_TINTE materiales intermedios.
PASOS_TINTE = 8
PARES_TINTE = (('caparazon', 'hierro'), ('cuerno', 'hierro'), ('caparazon', 'ligero'), ('cuerno', 'ligero'), ('ligero', 'hierro'))
_MAT = dict(ver.MAT)
_ESPEC = ['caparazon', 'cuerno', 'hierro', 'rojo', 'polo', 'cobre', 'ligero', 'hoja', 'oscuro', 'cara']
for _a, _b in PARES_TINTE:
    for _k in range(1, PASOS_TINTE):
        _u = _k / PASOS_TINTE
        _n = '%s>%s>%d' % (_a, _b, _k)
        _MAT[_n] = [tuple(x + (y - x) * _u for x, y in zip(ca, cb)) for ca, cb in zip(ver.MAT[_a], ver.MAT[_b])]
        _ESPEC.append(_n)


# Con sitio arriba para la subida del Picado (y abajo para su sombra). Los pies, en el CENTRO del lienzo: es el origen del
# nodo en el juego (lo de abajo va vacio y las hojas se recortan al dibujo).
MODELO = Modelo(2.1, (136, 224), (68, 112), _MAT, (0.06, 0.09, 0.05), suaves=('cuerpo',), brillan=('ojo',), corta_suelo=True,
                especular=tuple(_ESPEC),
                umbral_especular=0.96, translucidos=('ala',), alfa=0.72)
GRUPOS_PARPADO = 1


def POSE(**k):
    p = dict(avance=0.0, agacha=0.0, estira=1.0, tumba=0.0, encoge=0.0, cielo=0.0, fase=0.0, paso=0.0, cabeza=0.0, vibra=0.0,
             alto=0.0, picar=0.0, ala=0.0, elitro=0.0, plegar=0.0, escala=1.0,
             # LA EVOLUCION: 'desde' = lo que era ('normal', 'iman', 'saeta') y mientras evo < 0,5 se pinta ESO; luego el
             # mutante, al que le crecen lo que no tenia: la herradura (crece_iman) o las alas (crece_ala), de 0 a 1.
             desde='', evo=1.0, crece_iman=1.0, crece_ala=1.0,
             # Lo que lleva de su color nuevo mientras aun es lo que era (0 a 1).
             tinte=0.0)
    p.update(k)
    return p


def huesos(p):
    k = p['escala']
    S = np.diag([k * (1.0 + 0.06 * p['agacha']), k * p['estira'], k * (1.0 - 0.26 * p['agacha'])])
    X = (S, np.zeros(3))
    alt = Z if VAR != 'iman' else 2.8
    # El CABECEO y la TUMBA, alrededor del centro del cuerpo.
    X = comp(sobre(V((0.0, 0.0, alt)), rx(p['picar'])), X)
    X = comp(sobre(V((0.0, -1.0, alt)), ry(p['tumba'] * math.pi * 0.5)), X)
    X = comp((np.eye(3), V((p['vibra'], p['avance'], p['alto']))), X)
    h = {'raiz': X, 'cabeza': comp(X, sobre(CUELLO + V((0, 0, Z - 3.0 if VAR != 'iman' else 0.0)), rx(-p['cabeza'] * 0.45)))}
    for s in (-1, 1):
        # EL ALA: gira a lo largo del cuerpo (aletea arriba y abajo); plegarla la lleva hacia atras, sobre la espalda.
        r = V((1.4 * s, 0.8, Z + 0.8))
        giro = ry(-s * p['ala'] * 0.75)
        h['ala%d' % s] = comp(X, sobre(r, giro @ rz(-s * p['plegar'] * 0.75)))
        # EL ELITRO: abierto de serie; 'elitro' = 1 lo cierra sobre el lomo.
        e = V((1.8 * s, 2.0, Z + 1.6))
        h['eli%d' % s] = comp(X, sobre(e, rz(-s * p['elitro'] * 0.62) @ ry(s * p['elitro'] * 0.95)))
    return h


def _sobre_hueso(e, hueso):
    return lambda fn, mat, k=0.0, g='x': e.add(fn, mat, k, g, hueso)


def _patas_iman(e, p):
    # Las seis, a tripode alterno; se guardan (encoge) o se quedan tiesas (cielo). Como escarabajo_sdf.
    add = e.add
    centro = V((0.0, -1.0, 3.3))
    en = p['encoge']; ci = p['cielo']
    for s in (-1, 1):
        for k, (y0, ang, lar, ancho) in enumerate(((3.0, 0.6, 7.5, 3.0), (-1.2, -0.2, 8.5, 2.6), (-5.0, -0.8, 8.0, 2.4))):
            d = V((math.cos(ang) * s, math.sin(ang), 0.0))
            b = V((ancho * s, y0, 1.8))
            grupo = (k + (1 if s > 0 else 0)) % 2
            fi = 2 * math.pi * (p['fase'] + 0.5 * grupo)
            paso = V((0.0, PASO_LARGO * math.sin(fi), PASO_ALTO * max(0.0, math.cos(fi)))) * p['paso']
            rod = b + d * lar * 0.5 + V((0, 0, 1.6)) + paso * 0.4
            tob = b + d * lar * 0.82 + V((0, 0, -0.6)) + paso * 0.8
            pie = b + d * lar + V((0, 0, -1.7)) + paso
            if ci > 0.0:
                rod = rod * (1 - ci) + (b + d * 3.0 + V((0, 0, -2.0))) * ci
                tob = tob * (1 - ci) + (b + d * 3.4 + V((0, 0, -4.4))) * ci
                pie = pie * (1 - ci) + (b + d * 2.6 + V((0, 0, -5.6))) * ci
            if en > 0.0:
                rod = rod + (centro - rod) * 0.65 * en
                tob = tob + (centro - tob) * 0.72 * en
                pie = pie + (centro - pie) * 0.78 * en
                b = b + (centro - b) * 0.3 * en
            g = 'pata%d%d' % (s, k)
            ver._cono(add, b, rod, 0.7, 0.5, 'pata', g)
            ver._cono(add, rod, tob, 0.5, 0.4, 'pata', g)
            ver._cono(add, tob, pie, 0.3, 0.25, 'pata', g)


def _patas_colgando(e, z, p):
    for s in (-1, 1):
        for k, y0 in enumerate((3.0, 0.0, -3.0)):
            ci = p['cielo']
            a = V((1.8 * s, y0, z - 1.0))
            b = V((3.4 * s, y0 - 0.5, z - 3.6)) * (1 - ci) + V((2.6 * s, y0, z - 3.2)) * ci
            c = V((3.2 * s, y0 - 1.2, z - 6.0)) * (1 - ci) + V((2.0 * s, y0 + 0.4, z - 5.0)) * ci
            g = 'pata%d%d' % (s, k)
            ver._cono(e.add, a, b, 0.4, 0.28, 'pata', g)
            ver._cono(e.add, b, c, 0.28, 0.12, 'pata', g)


def escena_iman(p):
    e = Escena(huesos(p))
    add = e.add
    ver._elip(add, (0, -5.5, 3.2), (4.2, 4.4, 3.0), 'hierro', 'elitros')
    ver._elip(add, (0, -5.5, 3.2), (0.26, 4.5, 3.1), 'costura', 'costura')
    ver._elip(add, (0, -1.0, 2.6), (2.6, 1.5, 1.8), 'oscuro', 'cintura')
    ver._elip(add, (0, 1.6, 3.2), (5.0, 2.8, 2.7), 'hierro', 'pronoto')
    cab = _sobre_hueso(e, 'cabeza')
    ver._elip(cab, (0, 4.6, 2.8), (2.6, 1.8, 1.7), 'cara', 'cabeza')
    ver._ojos(cab, 4.4, 2.7, 3.6)
    k = max(p['crece_iman'], 0.12)
    # El arco crece desde la boca: su base se queda donde esta la cabeza.
    ver._iman_u(cab, 3.4, R=5.6 * k, yc=5.4 + 5.6 * k, g=1.9 * k, largo=2.0 * k, polo=2.7 * k)
    _patas_iman(e, p)
    return e.L


def escena_saeta(p):
    e = Escena(huesos(p))
    add = e.add
    z = Z
    ver._elip(add, (0, -3.0, z), (2.5, 6.0, 2.0), 'oscuro', 'vientre')
    ver._elip(add, (0, 3.4, z + 0.4), (3.2, 2.2, 1.9), 'ligero', 'pronoto')
    cab = _sobre_hueso(e, 'cabeza')
    ver._elip(cab, (0, 6.2, z), (2.1, 1.7, 1.4), 'cara', 'cabeza')
    ver._ojos(cab, 6.8, 1.8, z + 0.5, 0.8)
    for s in (-1, 1):
        pts = [V((1.0 * s, 7.2, z)), V((2.6 * s, 8.4, z + 0.6)), V((3.5 * s, 10.6, z + 1.0)), V((2.0 * s, 12.6, z + 1.0))]
        ver._curva(cab, pts, 1.0, 0.25, 'cuerno', 'mand%d' % s)
        _ala_crece(e, s, (1.4 * s, 1.0, z + 0.8), (14.5 * s, -5.0, z + 2.4), p)
        ver._elitro_concha(_sobre_hueso(e, 'eli%d' % s), s, z, True)
    _patas_colgando(e, z, p)
    _sombra(e, p)
    return e.L


def escena_errante(p):
    e = Escena(huesos(p))
    add = e.add
    z = Z
    ver._elip(add, (0, -3.0, z), (2.5, 6.0, 2.0), 'oscuro', 'vientre')
    ver._elip(add, (0, 2.4, z + 0.4), (3.2, 2.2, 1.9), 'hierro', 'pronoto')
    cab = _sobre_hueso(e, 'cabeza')
    ver._elip(cab, (0, 4.8, z), (2.1, 1.7, 1.4), 'cara', 'cabeza')
    ver._ojos(cab, 4.8, 2.2, z + 0.6, 0.8)
    k = max(p['crece_iman'], 0.12)
    ver._iman_u(cab, z + 0.6, R=4.6 * k, yc=5.0 + 4.6 * k, g=1.5 * k, largo=1.6 * k, polo=2.2 * k)
    for s in (-1, 1):
        _ala_crece(e, s, (1.4 * s, 0.4, z + 0.8), (14.5 * s, -5.6, z + 2.4), p)
        ver._elitro_concha(_sobre_hueso(e, 'eli%d' % s), s, z, True, 'hierro')
    _patas_colgando(e, z, p)
    _sombra(e, p)
    return e.L


def _ala_crece(e, s, raiz, punta, p):
    k = max(p['crece_ala'], 0.08)
    r_ = V(raiz, dtype=float)
    ver._ala(_sobre_hueso(e, 'ala%d' % s), raiz, r_ + (V(punta, dtype=float) - r_) * k, 3.0 * k, 'ala%d' % s)


def _sombra(e, p):
    # La separacion con su sombra es lo que se lee como altura (como el chillon). Sube: la sombra encoge.
    k = max(0.45, 1.0 - 0.02 * max(p['alto'], 0.0))
    e.sombra(0.0, p['avance'], 6.0 * k, 4.2 * k)


def escena_normal(p):
    # EL ESCARABAJO DE SIEMPRE, el de verdad (escarabajo_sdf), en la misma pose.
    return normal.escena(normal.POSE(agacha=p['agacha'], cuerno=p['cabeza'], avance=p['avance'], estira=p['estira'],
                                     fase=p['fase'], paso=p['paso'], tumba=0.0))


# Que colores cambian segun de donde venga y a donde va.
def _hacia_color(desde):
    if desde == 'normal':
        c = 'hierro' if VAR == 'iman' else 'ligero'
        return {'caparazon': c, 'cuerno': c}
    if desde == 'saeta' and VAR == 'errante':
        return {'ligero': 'hierro'}
    return {}


def _tintar(L, p):
    k = int(round(p['tinte'] * PASOS_TINTE))
    cambia = _hacia_color(p['desde'])
    if k <= 0 or not cambia:
        return L
    for i, pieza in enumerate(L):
        hacia = cambia.get(pieza[1])
        if hacia is not None:
            nombre = hacia if k >= PASOS_TINTE else '%s>%s>%d' % (pieza[1], hacia, k)
            L[i] = (pieza[0], nombre) + tuple(pieza[2:])
    return L


def escena(p):
    if p['desde'] and p['evo'] < 0.5:
        return _tintar({'normal': escena_normal, 'iman': escena_iman, 'saeta': escena_saeta}[p['desde']](p), p)
    return {'iman': escena_iman, 'saeta': escena_saeta, 'errante': escena_errante}[VAR](p)


# ------------------------------------------------------------
#  ANIMACIONES
# ------------------------------------------------------------
def _paso(x, a, b):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def _aleteo(t, vueltas=2.0):
    return math.sin(2 * math.pi * t * vueltas)


# --- el iman ---
def i_idle(t):
    return POSE(estira=1.0 + 0.012 * math.sin(2 * math.pi * t), fase=t, paso=0.08, cabeza=0.08 * math.sin(2 * math.pi * t))


def i_walk(t):
    # Mas pesado aun que el de siempre: la herradura le tira de la cabeza hacia abajo a cada paso.
    return POSE(fase=t, paso=1.0, agacha=0.05 * (1 - math.cos(4 * math.pi * t)), cabeza=-0.1 + 0.1 * math.sin(4 * math.pi * t))


def i_basico(t):
    # Echa atras la cabeza y la deja caer: un cabezazo con el iman (toca en la mitad).
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.3, -1.2), (0.5, 3.4), (0.7, 2.6), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.4), (0.5, 0.7), (0.7, 0.4), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.3, 1.5), (0.5, -0.3), (0.7, -0.2), (1.0, 0.0)]))


def i_caparazon(t):
    # La Coraza imantada: se deja caer, mete las patas y clava la herradura al suelo.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.286, 0.55), (0.571, 1.0), (1.0, 0.96)]),
                encoge=tramos(t, [(0.0, 0.0), (0.286, 0.3), (0.571, 1.0), (1.0, 0.94)]),
                estira=tramos(t, [(0.0, 1.0), (0.571, 0.9), (1.0, 0.9)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.571, -0.25), (1.0, -0.22)]))


def i_embestir_carga(t):
    # Baja el iman y escarba: en bucle.
    return POSE(agacha=0.65 + 0.08 * math.sin(2 * math.pi * t), cabeza=-0.3, avance=-1.0 + 0.5 * math.sin(2 * math.pi * t),
                fase=t * 2.0, paso=0.5)


def i_embestir(t):
    # Empuja corriendo con la herradura por delante, patas a toda prisa (la pelea lo lleva por la linea).
    return POSE(agacha=0.45, cabeza=-0.3, fase=t * 2.0, paso=1.3, estira=1.05)


def i_pulso_carga(t):
    # ALZA LA HERRADURA y se pone a temblar, cada vez mas (en bucle): es el aviso de lo que viene.
    return POSE(cabeza=1.4 + 0.15 * math.sin(4 * math.pi * t), agacha=0.25, vibra=0.35 * (1 if int(t * 16) % 2 == 0 else -1))


def i_pulso(t):
    # La descarga: da un golpe seco hacia delante y abajo (toca a los 0,33) y se recupera.
    return POSE(cabeza=tramos(t, [(0.0, 1.5), (0.33, -0.3), (0.6, -0.15), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.25), (0.33, 0.9), (0.6, 0.4), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.33, 1.2), (1.0, 0.0)]))


def i_encaje(t):
    return POSE(avance=-tramos(t, [(0.0, 1.6), (0.34, 0.6), (0.67, 0.15), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.8), (0.34, 0.22), (0.67, 0.06), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.5), (1.0, 0.0)]))


def i_muerte(t):
    # El peso del iman lo vence hacia delante y se queda con la cabeza clavada y las patas guardandose.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.3, 0.5), (0.7, 1.0), (1.0, 1.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.3, 0.8), (0.55, -1.2), (0.7, -0.9), (1.0, -1.0)]),
                encoge=tramos(t, [(0.0, 0.0), (0.45, 0.2), (1.0, 0.7)]),
                tumba=tramos(t, [(0.0, 0.0), (0.55, 0.05), (1.0, 0.18)]))


def i_comer(t):
    masca = 0.35 * math.sin(2 * math.pi * t * 4.0) * (0.25 < t < 0.85)
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.15, 0.6), (0.85, 0.6), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.15, -0.3), (0.85, -0.25), (1.0, 0.0)]) + 0.4 * masca)


def i_evolucion(t):
    # Tiembla agazapado siendo el de siempre, se encoge y al alzarse ya es de hierro y la herradura le crece de la boca.
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.40, 0.50))
    return POSE(desde='normal', evo=_paso(t, 0.44, 0.46), tinte=_paso(t, 0.06, 0.44),
                agacha=tramos(t, [(0.0, 0.0), (0.12, 0.6), (0.45, 0.8), (0.55, -0.1), (0.70, 0.1), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.45, -0.25), (0.55, 1.2), (0.75, 0.3), (1.0, 0.0)]),
                vibra=0.3 * tiembla, crece_iman=_paso(t, 0.46, 0.82))


# --- los que vuelan ---
def v_idle(t):
    # Se queda en el aire, con un aleteo que no para y un cabeceo suave.
    return POSE(ala=_aleteo(t, 2.0), alto=0.7 * math.sin(2 * math.pi * t), picar=0.04 * math.sin(2 * math.pi * t))


def v_walk(t):
    # Volando: inclinado hacia delante, aleteo a toda prisa. Este es lo contrario del de siempre.
    return POSE(ala=_aleteo(t, 3.0), alto=0.4 * math.sin(4 * math.pi * t), picar=-0.28)


def v_basico(t):
    # Baja de un tiron, muerde con las mandibulas (toca en la mitad) y remonta.
    return POSE(ala=_aleteo(t, 2.0) * 0.6, avance=tramos(t, [(0.0, 0.0), (0.3, -1.4), (0.5, 4.2), (0.7, 3.0), (1.0, 0.0)]),
                alto=tramos(t, [(0.0, 0.0), (0.3, 1.2), (0.5, -3.6), (0.7, -2.4), (1.0, 0.0)]),
                picar=tramos(t, [(0.0, 0.0), (0.3, 0.2), (0.5, -0.5), (0.7, -0.3), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.3, 0.9), (0.5, -0.8), (1.0, 0.0)]))


def v_pasada(t):
    # La pasada: alas echadas atras, cuerpo estirado, flecha (la pelea lo lleva por la linea).
    return POSE(ala=0.25 * _aleteo(t, 4.0), plegar=0.65, picar=-0.42, estira=1.1, alto=-1.8, elitro=0.3)


def v_elitros(t):
    # Cierra las conchas y pliega las alas: un momento de bala (la esquiva).
    return POSE(elitro=tramos(t, [(0.0, 0.0), (0.4, 1.0), (0.8, 1.0), (1.0, 0.9)]),
                plegar=tramos(t, [(0.0, 0.0), (0.4, 1.0), (1.0, 1.0)]),
                ala=0.1 * _aleteo(t, 3.0), alto=tramos(t, [(0.0, 0.0), (0.4, 1.0), (1.0, 0.8)]))


def v_subir(t):
    return POSE(ala=_aleteo(t, 3.0), alto=tramos(t, [(0.0, 0.0), (0.2, -1.2), (1.0, ALTO_SUBIDA)]),
                picar=tramos(t, [(0.0, 0.0), (0.4, 0.4), (1.0, 0.1)]))


def v_aire(t):
    return POSE(ala=_aleteo(t, 2.0), alto=ALTO_SUBIDA + 0.8 * math.sin(2 * math.pi * t), picar=0.1)


def v_picado(t):
    # Pliega y cae como una flecha: toca a los 0,6; rebota y vuelve a su altura.
    return POSE(alto=tramos(t, [(0.0, ALTO_SUBIDA), (0.6, -4.0), (0.75, -2.6), (1.0, 0.0)]),
                picar=tramos(t, [(0.0, -0.2), (0.3, -1.1), (0.6, -1.15), (0.75, -0.2), (1.0, 0.0)]),
                plegar=tramos(t, [(0.0, 0.2), (0.3, 1.0), (0.6, 1.0), (0.8, 0.2), (1.0, 0.0)]),
                elitro=tramos(t, [(0.0, 0.0), (0.3, 0.8), (0.6, 0.8), (0.8, 0.1), (1.0, 0.0)]),
                ala=_aleteo(t, 2.0) * tramos(t, [(0.0, 0.2), (0.6, 0.1), (1.0, 0.9)]))


def v_pulso_carga(t):
    # En el aire, alza la herradura y tiembla.
    return POSE(ala=_aleteo(t, 3.0), cabeza=1.3, vibra=0.3 * (1 if int(t * 16) % 2 == 0 else -1), picar=0.25)


def v_pulso(t):
    return POSE(ala=_aleteo(t, 2.0), cabeza=tramos(t, [(0.0, 1.4), (0.33, -0.9), (0.6, -0.4), (1.0, 0.0)]),
                picar=tramos(t, [(0.0, 0.25), (0.33, -0.4), (1.0, 0.0)]), alto=tramos(t, [(0.0, 0.0), (0.33, -1.6), (1.0, 0.0)]))


def v_encaje(t):
    return POSE(ala=_aleteo(t, 1.0) * 0.5, avance=-tramos(t, [(0.0, 3.2), (0.34, 1.4), (0.67, 0.4), (1.0, 0.0)]),
                picar=tramos(t, [(0.0, 0.4), (0.67, 0.08), (1.0, 0.0)]), alto=tramos(t, [(0.0, 1.5), (1.0, 0.0)]))


def v_muerte(t):
    # Deja de aletear y se viene abajo dando la vuelta; acaba panza arriba en el suelo.
    return POSE(ala=_aleteo(t, 1.5) * (1 - _paso(t, 0.1, 0.5)), plegar=_paso(t, 0.1, 0.6), elitro=_paso(t, 0.1, 0.6),
                alto=tramos(t, [(0.0, 0.0), (0.2, 1.2), (0.62, ALTO_VOLTEADO - 0.4), (0.76, ALTO_VOLTEADO + 0.8), (0.88, ALTO_VOLTEADO - 0.2), (1.0, ALTO_VOLTEADO)]),
                tumba=tramos(t, [(0.0, 0.0), (0.2, 0.1), (0.62, 1.9), (0.76, 2.04), (1.0, 2.0)]),
                cielo=_paso(t, 0.4, 0.9))


# DERRIBADO (04/11, lo pidio el jefe: un bicho que vuela, aturdido o bajado del aire, CAE): cae dando la vuelta, se queda
# panza arriba pataleando lo que dure y se recoloca volviendo a levantar el vuelo.
ALTO_VOLTEADO = -4.6   # (panza arriba, con alas y conchas plegadas: asi no se hunden en el suelo y no se cortan)


def v_caer(t):
    return POSE(ala=_aleteo(t, 1.5) * (1 - _paso(t, 0.0, 0.5)), plegar=_paso(t, 0.05, 0.55), elitro=_paso(t, 0.05, 0.55),
                alto=tramos(t, [(0.0, 0.0), (0.7, ALTO_VOLTEADO - 0.4), (0.85, ALTO_VOLTEADO + 0.9), (1.0, ALTO_VOLTEADO)]),
                tumba=tramos(t, [(0.0, 0.0), (0.7, 1.9), (0.85, 2.05), (1.0, 2.0)]), cielo=_paso(t, 0.2, 0.8))


def v_volteado(t):
    # Panza arriba: patalea (el cuerpo se mece) y las alas dan algun tiron en el suelo.
    s_ = math.sin(2 * math.pi * t)
    return POSE(alto=ALTO_VOLTEADO, tumba=2.0 + 0.05 * s_, cielo=0.85 + 0.15 * s_, plegar=1.0, elitro=1.0, ala=0.06 * _aleteo(t, 2.0),
                vibra=0.2 * math.sin(4 * math.pi * t))


def v_recolocarse(t):
    return POSE(alto=tramos(t, [(0.0, ALTO_VOLTEADO), (0.45, ALTO_VOLTEADO + 0.6), (0.8, 1.2), (1.0, 0.0)]),
                tumba=tramos(t, [(0.0, 2.0), (0.45, 0.2), (0.6, 0.0), (1.0, 0.0)]), cielo=1.0 - _paso(t, 0.1, 0.55),
                plegar=1.0 - _paso(t, 0.45, 0.8), elitro=1.0 - _paso(t, 0.45, 0.75), ala=_aleteo(t, 3.0) * _paso(t, 0.5, 0.8))


def v_comer(t):
    # Baja al suelo a comer: las patas tocan y agacha las mandibulas.
    masca = 0.3 * math.sin(2 * math.pi * t * 4.0) * (0.25 < t < 0.85)
    return POSE(alto=tramos(t, [(0.0, 0.0), (0.15, -2.8), (0.85, -2.8), (1.0, 0.0)]),
                plegar=tramos(t, [(0.0, 0.0), (0.2, 0.8), (0.8, 0.8), (1.0, 0.0)]),
                ala=_aleteo(t, 1.0) * 0.15, cabeza=tramos(t, [(0.0, 0.0), (0.15, -0.9), (0.85, -0.8), (1.0, 0.0)]) + masca,
                picar=tramos(t, [(0.0, 0.0), (0.15, -0.3), (0.85, -0.3), (1.0, 0.0)]))


def v_evolucion(t):
    # El SAETA: el de siempre, en el suelo, tiembla y se encoge; le saltan las conchas, le crecen las alas y despega.
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.40, 0.50))
    return POSE(desde='normal', evo=_paso(t, 0.44, 0.46), tinte=_paso(t, 0.06, 0.44),
                agacha=tramos(t, [(0.0, 0.0), (0.12, 0.6), (0.45, 0.8), (0.46, 0.0), (1.0, 0.0)]),
                alto=tramos(t, [(0.0, -2.8), (0.5, -2.8), (0.72, 2.2), (1.0, 0.0)]),
                elitro=tramos(t, [(0.0, 1.0), (0.46, 1.0), (0.62, 0.0), (1.0, 0.0)]),
                plegar=tramos(t, [(0.0, 1.0), (0.46, 1.0), (0.66, 0.0), (1.0, 0.0)]),
                ala=_aleteo(t, 4.0) * _paso(t, 0.55, 0.72), crece_ala=_paso(t, 0.46, 0.76), vibra=0.3 * tiembla)


def v_evolucion_iman(t):
    # El ERRANTE viniendo del Iman: el Iman en el suelo; le salen las alas y levanta el vuelo con la herradura a cuestas.
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.40, 0.50))
    return POSE(desde='iman', evo=_paso(t, 0.44, 0.46),
                agacha=tramos(t, [(0.0, 0.0), (0.12, 0.6), (0.45, 0.8), (0.46, 0.0), (1.0, 0.0)]),
                alto=tramos(t, [(0.0, -2.8), (0.5, -2.8), (0.74, 2.2), (1.0, 0.0)]),
                elitro=tramos(t, [(0.0, 1.0), (0.46, 1.0), (0.62, 0.0), (1.0, 0.0)]),
                plegar=tramos(t, [(0.0, 1.0), (0.46, 1.0), (0.66, 0.0), (1.0, 0.0)]),
                ala=_aleteo(t, 4.0) * _paso(t, 0.55, 0.72), crece_ala=_paso(t, 0.46, 0.76), vibra=0.3 * tiembla)


def v_evolucion_saeta(t):
    # El ERRANTE viniendo del Saeta: en el aire tiembla; se oscurece a hierro y le crece la herradura de la boca.
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.40, 0.50))
    return POSE(desde='saeta', evo=_paso(t, 0.44, 0.46), tinte=_paso(t, 0.06, 0.44), ala=_aleteo(t, 4.0) * (0.35 + 0.65 * _paso(t, 0.46, 0.7)),
                plegar=tramos(t, [(0.0, 0.0), (0.2, 0.7), (0.44, 0.7), (0.56, 0.0), (1.0, 0.0)]),
                elitro=tramos(t, [(0.0, 0.0), (0.2, 0.7), (0.44, 0.7), (0.56, 0.0), (1.0, 0.0)]),
                alto=tramos(t, [(0.0, 0.0), (0.44, -1.8), (0.62, 2.0), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.46, -0.2), (0.62, 1.1), (1.0, 0.0)]),
                crece_iman=_paso(t, 0.46, 0.82), vibra=0.3 * tiembla)


# nombre: (fotogramas, fps, loop, direcciones, funcion)
_IMAN = {
    'idle': (8, 3.0, True, 8, i_idle), 'walk': (8, 6.0, True, 8, i_walk), 'basico': (6, 16.0, False, 8, i_basico),
    'caparazon': (8, 9.0, False, 8, i_caparazon), 'embestir_carga': (8, 8.0, True, 8, i_embestir_carga),
    'embestir': (8, 18.0, True, 8, i_embestir), 'pulso_carga': (8, 12.0, True, 8, i_pulso_carga),
    'pulso': (6, 14.0, False, 8, i_pulso), 'encaje': (4, 18.0, False, 8, i_encaje), 'muerte': (8, 10.0, False, 8, i_muerte),
    'comer': (10, 10.0, False, 8, i_comer), 'evolucion': (18, 10.0, False, 8, i_evolucion),
}
_SAETA = {
    'idle': (8, 12.0, True, 8, v_idle), 'walk': (6, 18.0, True, 8, v_walk), 'basico': (6, 16.0, False, 8, v_basico),
    'pasada': (6, 18.0, True, 8, v_pasada), 'elitros': (8, 12.0, False, 8, v_elitros), 'subir': (8, 12.0, False, 8, v_subir),
    'aire': (6, 14.0, True, 8, v_aire), 'picado': (8, 14.0, False, 8, v_picado), 'encaje': (4, 18.0, False, 8, v_encaje),
    'muerte': (8, 10.0, False, 8, v_muerte), 'comer': (10, 10.0, False, 8, v_comer), 'evolucion': (18, 10.0, False, 8, v_evolucion),
    'caer': (8, 14.0, False, 8, v_caer), 'volteado': (6, 10.0, True, 8, v_volteado), 'recolocarse': (8, 12.0, False, 8, v_recolocarse),
}
_ERRANTE = dict(_SAETA)
del _ERRANTE['elitros']
_ERRANTE.update({'pulso_carga': (8, 12.0, True, 8, v_pulso_carga), 'pulso': (6, 14.0, False, 8, v_pulso),
                 # Dos: viene de dos sitios (enemy.gd busca 'evolucion_<de donde viene>'; sin ella, 'evolucion').
                 'evolucion': (18, 10.0, False, 8, v_evolucion_iman),
                 'evolucion_saeta': (18, 10.0, False, 8, v_evolucion_saeta)})
_TABLA = {'iman': _IMAN, 'saeta': _SAETA, 'errante': _ERRANTE}[VAR]


ANIMS = _TABLA


def _hoja(var):
    # Recortada al dibujo (sin el lienzo con sitio para la subida), en dos vistas; cada animacion, su altura.
    from PIL import Image, ImageDraw
    carp = 'assets/sprites/enemigos/escarabajo_sdf_%s/' % var
    meta = json.load(open(carp + 'hojas.json'))
    W, H = meta['lienzo']
    ESC = 3
    DIRS = (1, 2)
    filas = []
    for n in meta['anims']:
        im = Image.open(carp + n + '.png').convert('RGBA')
        k = int(meta['anims'][n]['fotogramas'])
        for d in DIRS:
            cajas = [im.crop((i * W, d * H, (i + 1) * W, (d + 1) * H)).getbbox() for i in range(k)]
            cajas = [c for c in cajas if c]
            x0 = min(c[0] for c in cajas) - 2; y0 = min(c[1] for c in cajas) - 2
            x1 = max(c[2] for c in cajas) + 2; y1 = max(c[3] for c in cajas) + 2
            filas.append((n, im, k, d, (x0, y0, x1, y1)))
    ancho = 150 + max((f[4][2] - f[4][0]) * ESC * f[2] for f in filas)
    alto = sum((f[4][3] - f[4][1]) * ESC + 6 for f in filas)
    hoja = Image.new('RGB', (ancho, alto), (40, 42, 50))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for n, im, k, d, (x0, y0, x1, y1) in filas:
        cw, ch = x1 - x0, y1 - y0
        dib.text((6, y + ch * ESC // 2), n, fill=(235, 235, 235))
        for i in range(k):
            c = im.crop((i * W + x0, d * H + y0, i * W + x1, d * H + y1)).resize((cw * ESC, ch * ESC), Image.NEAREST)
            hoja.paste(c, (150 + i * cw * ESC, y), c)
        y += ch * ESC + 6
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    ruta = os.path.join(esc, 'escarabajo_%s_hoja.png' % var)
    hoja.save(ruta)
    hoja.save('tools/salida/sdf/escarabajo_%s_hoja.png' % var)
    print(ruta, hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja(args[1])
    else:
        hornear('escarabajo_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
