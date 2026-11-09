# ============================================================
#  miconido_mut_sdf.py -- LOS MUTANTES DEL MICONIDO, con sus animaciones (09/11/2026, miconido-mutante).
#  Los cuerpos son los elegidos en miconido_mutantes_versiones.py:
#    MIC_VAR=campana    CAMPANA PALIDA       1a A medusa: tallo flaco y alto, campana translucida con laminas y nucleo
#                                            encendidos, filamentos de luz colgando.
#    MIC_VAR=florecido  AVENTURERO FLORECIDO 2a C: el cadaver de un aventurero; en vez de cabeza, la campana de la 1a con
#                                            sus filamentos; tallos naranjas por los hombros, yelmo colgando del cinto,
#                                            espada oxidada.
#  Pegas de la lamina arregladas: los brazos de la medusa mas gruesos y claros; el muerto x1,1 (era mas pequeño que el normal).
#  TODO va colgado de la RAIZ (un solo hueso que inclina el cuerpo entero sobre los pies) y la pose mueve las piezas a mano:
#  son cuerpos nuevos, no el del micónido con adornos.
#  Uso: MIC_VAR=campana python tools/sprites_sdf/miconido_mut_sdf.py [anim ...] -> assets/sprites/enemigos/miconido_sdf_<var>/
#       MIC_VAR=campana python tools/sprites_sdf/miconido_mut_sdf.py hoja [anim ...] -> la hoja para mirarla, al escritorio
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import miconido_sdf as base
import miconido_mutantes_versiones as ver

V = np.array
VAR = os.environ.get('MIC_VAR', 'campana')
SALIDA = 'assets/sprites/enemigos/miconido_sdf_%s/' % VAR
VISTAS = 'tools/salida/sdf/'
_cono, _elip, _curva, _bez = ver._cono, ver._elip, ver._curva, ver._bez

# ------------------------------------------------------------
#  MATERIALES, con la TRANSICION DE COLOR de la evolucion (memoria transiciones-de-color) y el APAGARSE de la luz al morir
# ------------------------------------------------------------
PASOS = 10
_FINAL = dict(ver.MAT_LUZ) if VAR == 'campana' else dict(ver.MAT_CORD)
if VAR == 'florecido':
    _FINAL['carne'] = ver.MAT_LUZ['carne']
    _FINAL['luz2'] = ver.MAT_LUZ['luz2']
    _FINAL['mota'] = ver.MAT_LUZ['mota']
    _FINAL['raiz'] = ver.MAT_LUZ['raiz']   # las raices de la campana, al empezar la evolucion
# De donde sale cada material en la evolucion: del micónido normal (la campana) o de la campana (el florecido).
_DE_CAMPANA = {'carne': 'carne', 'sombrero': 'sombrero', 'campana': 'sombrero', 'luz': 'lamina', 'luz2': 'lamina',
               'mota': 'mota', 'raiz': 'carne'}
_APAGADA = [(0.20, 0.26, 0.28), (0.28, 0.36, 0.38), (0.36, 0.46, 0.48)]


def _origen(m):
    if VAR == 'campana':
        return base.MAT[_DE_CAMPANA.get(m, 'carne')]
    return ver.MAT_LUZ.get(m, _FINAL[m])


def _cuatro(tonos, n):
    return list(tonos) + [tonos[-1]] * (n - len(tonos))


_MAT = dict(_FINAL)
_ESPEC = ['campana', 'hierro']
for _m, _t in _FINAL.items():
    _o = _cuatro(_origen(_m), len(_t))
    for _k in range(PASOS):
        _u = _k / PASOS
        _MAT['%s>%d' % (_m, _k)] = [tuple(x + (y - x) * _u for x, y in zip(a, b)) for a, b in zip(_o, _t)]
    if _m in ('campana', 'hierro'):
        _ESPEC += ['%s>%d' % (_m, _k) for _k in range(PASOS)]
# Al morir la luz se apaga poco a poco: luz, luz2 y mota hacia un cian muerto.
for _m in ('luz', 'luz2', 'mota'):
    for _k in range(PASOS):
        _u = (_k + 1) / PASOS
        _MAT['%s@%d' % (_m, _k)] = [tuple(x + (y - x) * _u for x, y in zip(a, b)) for a, b in zip(_FINAL[_m], _APAGADA)]
_BRILLAN = [m for m in _MAT if m.split('>')[0].split('@')[0] in ('luz', 'luz2', 'mota')]

LIENZO = (280, 340)
PIES = (140, 236)
MODELO = Modelo(ver.ESC, LIENZO, PIES, _MAT, (0.04, 0.05, 0.06), suaves=('cuerpo',), brillan=tuple(_BRILLAN),
                corta_suelo=True, especular=tuple(_ESPEC), umbral_especular=0.80, translucidos=('campana',) + tuple(
                    'campana>%d' % k for k in range(PASOS)), alfa=0.72)


def POSE(**k):
    p = dict(avance=0.0, mece=0.0, balanceo=0.0, sacude=0.0, brazos=0.0, patas=0.0, hincha=0.0, hunde=0.0,
             derrumbe=0.0, puff=0.0, lanza=0.0, latigo=0.0, ola=0.0, alza=0.0, tajo=0.0, estoca=0.0, inclina=0.0,
             destella=0.0, agacha=0.0, apaga=0.0, evo=1.0, tinte=1.0, vibra=0.0)
    p.update(k)
    return p


def _mat(m, p):
    """El nombre del material en esta pose: a medio tenir en la evolucion, o apagandose al morir."""
    if p['apaga'] > 0.0 and m in ('luz', 'luz2', 'mota'):
        return '%s@%d' % (m, min(PASOS - 1, int(p['apaga'] * PASOS)))
    if p['tinte'] < 1.0 and m in _FINAL:
        return '%s>%d' % (m, min(PASOS - 1, int(p['tinte'] * PASOS)))
    return m


def _huesos(p):
    """La raiz: avanza, se mece hacia delante/atras y de lado sobre los pies y, al morir, se viene abajo hacia delante."""
    caer = p['derrumbe']
    R = rx(p['mece'] * 0.10 + caer * 1.25) @ ry(p['balanceo'] * 0.07)
    t = V((p['vibra'], p['avance'], -caer * 2.0))
    return {'raiz': (R, t)}


# ------------------------------------------------------------
#  LA CAMPANA (de la 1a; el florecido la lleva por cabeza)
# ------------------------------------------------------------
def _campana(add, p, c0, esc, mt):
    """La campana translucida con laminas y nucleo encendidos y los filamentos. 'esc' = su tamaño (la del florecido es
    mas pequeña); 'latigo' echa los filamentos de delante al frente (el basico), 'ola' los mece."""
    ladeo = 0.22 + p['sacude'] * 0.12 - p['destella'] * 0.55
    lad = rx(ladeo) @ ry(p['sacude'] * 0.18)
    infla = 1.0 + p['hincha'] + 0.10 * p['destella']
    hund = p['hunde']
    aplana = p.get('aplana', 1.0)          # < 1 = chata, como el sombrero del normal (en la evolucion)
    rr = V((6.8 * esc * infla, 6.8 * esc * infla, 5.6 * esc * infla * (1 - 0.25 * hund) * aplana))

    def campana(P, c0=c0, lad=lad, rr=rr):
        q = (P - c0) @ lad
        cap = sd_elipsoide(q, V((0, 0, 0.0)), rr)
        return np.maximum(cap, -(q[:, 2] + 1.2 * esc - 0.03 / esc * (q[:, 0] ** 2 + q[:, 1] ** 2)))
    add(campana, mt('campana'), 0, 'campana')
    for k in range(16):
        a = k / 16 * 2 * math.pi
        _cono(add, c0 + lad.T @ (V((math.cos(a) * 1.0, math.sin(a) * 1.0, 0.6)) * esc),
              c0 + lad.T @ (V((math.cos(a) * 5.6, math.sin(a) * 5.6, -0.4)) * esc), 0.3, 0.26, mt('luz'), 0, 'lamina')
    nuc = 2.0 * esc * (1.0 + 0.35 * p['destella'])
    _elip(add, c0 + V((0, 0, 1.4 * esc)), (nuc, nuc, nuc * 0.9), mt('luz2'), 0, 'nucleo')
    # los filamentos: caen ondulando; los de delante se lanzan al frente con el latigo
    n = 12 if esc > 0.8 else 8
    for k in range(n):
        a = k / n * 2 * math.pi + 0.13
        borde = c0 + lad.T @ (V((math.cos(a) * 6.2, math.sin(a) * 6.2, -1.0)) * esc * infla)
        largo = (7.0 + 2.0 * (1 - math.sin(a)) + 1.5 * math.sin(3 * a)) * esc * p['evo_fil']
        if largo < 0.3:
            continue
        delante = max(0.0, math.sin(a))
        lat = p['latigo'] * delante
        ola = p['ola'] * math.sin(k * 1.7)
        cae = V((math.cos(a) * 0.4 + 0.5 * math.sin(5 * a) + ola * 0.8, math.sin(a) * 0.4, -largo))
        frente = V((math.cos(a) * 1.5, largo * 1.1, -largo * 0.15))
        fin = borde + cae * (1 - lat) + frente * lat
        mid = borde + V((math.cos(a) * 0.9 + ola * 0.5, math.sin(a) * 0.9 + 0.6 * math.sin(2 * a), -largo * 0.5)) * (1 - lat) \
            + V((0, largo * 0.5, 0.3)) * lat
        _curva(add, _bez(borde, mid, fin, 4), 0.34, 0.14, mt('luz'), 0, 'fil%d' % k)
    if esc > 0.8:
        for (x, y, r) in ((-3.2, 1.0, 0.7), (2.4, -2.8, 0.6), (1.0, 3.4, 0.55), (-1.6, -3.6, 0.6), (3.6, 1.6, 0.5)):
            z = rr[2] * math.sqrt(max(0.0, 1 - (x * x + y * y) / (rr[0] ** 2))) - 0.15
            _elip(add, c0 + lad.T @ V((x, y, z)), (r, r, 0.28), mt('mota'), 0, 'mota')


def _brazo(add, hom, codo, mano, r, mt, g, dedos=True):
    _cono(add, hom, codo, r, r * 0.8, mt, 0.4, g)
    _cono(add, codo, mano, r * 0.8, r * 0.6, mt, 0.3, g)
    if dedos:
        for k in (-1, 0, 1):
            _cono(add, mano, mano + V((0.45 * k, 0.5, -1.4)), 0.3, 0.12, mt, 0, g)


def escena_campana(p):
    e = Escena(_huesos(p)); add = e.add
    mt = lambda m: _mat(m, p)
    ev = p['evo']
    # De micónido a campana: el cuerpo gordo se estira en tallo, el sombrero sube y se vuelve campana.
    alto = 16.0 + 9.0 * ev                  # donde acaba el tallo
    gordo = 1.0 - ev                        # lo que queda del cuerpo de seta
    ag = p['agacha']
    alto *= 1.0 - 0.25 * ag
    hun = p['hunde']
    alto -= hun * 1.8
    # las raices de la base
    # (crece con la evolucion: al principio no hay, si no tapa las patas del normal)
    _elip(add, (0, 0, 1.6), (2.1 * ev + 0.01, 2.0 * ev + 0.01, 1.8 * ev + 0.01), mt('carne'), 1.2)
    for k in range(6):
        a = k / 6 * 2 * math.pi + 0.4
        r = 1.5
        _cono(add, (math.cos(a) * r * 0.8, math.sin(a) * r * 0.8, 1.4),
              (math.cos(a) * r * 2.4 * (0.4 + 0.6 * ev), math.sin(a) * r * 2.4 * (0.4 + 0.6 * ev), 0.2),
              0.6 * ev + 0.01, 0.22, mt('raiz'), 0, 'raices')
    # el tallo, curvo hacia delante (se tuerce mas al agacharse y al lanzar)
    curva_y = (0.8 + 2.0 * ag + 1.2 * p['latigo'] + 1.5 * p['destella']) * (0.3 + 0.7 * ev)
    top = V((p['sacude'] * 0.6, curva_y, alto))
    _curva(add, _bez((0, 0, 1.5), (0, -0.6, alto * 0.55), top), 1.7, 1.05, mt('carne'), 0.8)
    pecho = V((0, 0.3 + 0.6 * ag, alto * 0.7))
    _elip(add, pecho, (2.0, 1.8, 3.6), mt('carne'), 1.5)
    # AL EMPEZAR LA EVOLUCION es el MICONIDO NORMAL (viene de comer): su tronco gordo y sus patas cortas, que se van
    # sorbiendo en el tallo (las medidas de miconido_sdf).
    if gordo > 0.02:
        g = gordo
        _elip(add, (0, 0, 9.5), (5.0 * g + 0.01, 4.6 * g + 0.01, 7.2 * g + 0.01), mt('carne'), 2.0)
        _elip(add, (0, 0, 4.6), (4.6 * g + 0.01, 4.2 * g + 0.01, 3.0 * g + 0.01), mt('carne'), 2.0)
        for s in (-1, 1):
            _cono(add, (2.2 * s, 0.0, 3.6), (2.3 * s, 0.4, 0.8), 1.7 * g + 0.01, 1.9 * g + 0.01, mt('carne'), 0.6, 'pierna%d' % s)
    # los brazos: mas gruesos y claros que en la lamina (casi no se veian); al lanzar el micelio, el de camara al frente
    for s in (-1, 1):
        hom = pecho + V(((1.9 + 2.7 * gordo) * s, 0.2, 2.0 + 0.8 * gordo))
        a = -p['brazos'] * s * 0.4
        largo = 12.0 * (0.7 + 0.3 * ev)
        if s == p['lado_lanza'] and p['lanza'] != 0.0:
            la = p['lanza']
            codo = hom + V((1.8 * s, 2.0 + 4.0 * max(la, 0), -largo * 0.35 + 3.0 * max(la, 0)))
            mano = codo + V((0.6 * s, 3.0 + 3.0 * max(la, 0), -largo * 0.3 + 2.0 * max(la, 0)))
        else:
            codo = hom + V((0.8 * s, 0.6 + a * 2, -largo * 0.5))
            mano = codo + V((0.3 * s, 1.0 + a * 3, -largo * 0.5))
        _brazo(add, hom, codo, mano, 0.85, mt('carne'), 'brazo%d' % s)
    # la campana sobre el tallo
    c0 = top + V((0, 0.1, 2.0))
    p2 = dict(p)
    p2['evo_fil'] = ev
    # el sombrero ancho y chato del normal (8,2 de radio, 4,4 de alto) que se va volviendo campana
    p2['aplana'] = 0.655 + 0.345 * ev
    _campana(add, p2, c0, 1.2 - 0.2 * ev, mt)
    # LA BOCANADA (esporas): el polvo sale de debajo de la campana, como en el normal, pero con luz
    pf = p['puff']
    if 0.0 < pf < 1.0:
        for k in range(10):
            a = k / 10 * 2 * math.pi + 0.3
            rr = 7.0 + 6.0 * pf
            r = 2.8 * (1.0 - 0.6 * pf)
            _elip(add, c0 + V((math.cos(a) * rr, math.sin(a) * rr * 0.9 + 1.0, -2.0 + 4.0 * pf + 1.2 * math.sin(3 * a))),
                  (r, r, r), mt('mota'), 0, 'espora')
    return e.L


# ------------------------------------------------------------
#  EL FLORECIDO: el cadaver con la campana por cabeza
# ------------------------------------------------------------
K = 1.1    # el muerto, un 10 % mas grande que en la lamina (era mas pequeño que el micónido normal)


def escena_florecido(p):
    e = Escena(_huesos(p)); add = e.add
    mt = lambda m: _mat(m, p)
    ev = p['evo']
    # En la evolucion el cuerpo SUBE DEL SUELO alrededor del tallo: todo lo del muerto va escalado en alto por 'sube'.
    sube = max(0.0, min(1.0, (ev - 0.1) / 0.75))
    W = lambda x, y, z: V((x * K, y * K, z * K * sube))
    inclina = 0.3 + p['inclina'] + 0.5 * p['agacha']
    paso = p['patas']
    # piernas
    for s in (-1, 1):
        cad = W(1.5 * s, 0.0, 11.0)
        rod = W(1.8 * s, 1.0 + 0.6 * inclina + 1.2 * paso * s, 6.0)
        tob = W(1.9 * s, 0.2 + 1.6 * paso * s, 1.4)
        if sube > 0.02:
            _cono(add, cad, rod, 1.25 * K * sube, 1.0 * K * sube, mt('tela'), 0, 'pierna%d' % s)
            _cono(add, rod, tob, 1.0 * K * sube, 0.85 * K * sube, mt('tela'), 0, 'pierna%d' % s)
            _elip(add, tob + V((0, 0.6, -0.6)) * K, (1.05 * K, 1.7 * K, 0.9 * K * sube + 0.05), mt('cuero'), 0, 'bota%d' % s)
            _cono(add, tob + V((0, 0, 0.2)), tob + W(0, 0, 2.6), 1.05 * K * sube, 1.02 * K * sube, mt('cuero'), 0, 'bota%d' % s)
    cadera = W(0, 0, 11.5)
    pecho = cadera + W(0, 2.0 + 4.0 * inclina, 6.0 - 2.4 * inclina)
    cuello = pecho + W(0, 0.6 + 1.8 * inclina, 2.6 - 1.0 * inclina)
    if sube > 0.02:
        ss = sube
        _cono(add, cadera, pecho, 2.6 * K * ss, 3.0 * K * ss, mt('tela'), 0, 'torso')
        _elip(add, pecho + W(0, -0.2, 0.3), (3.4 * K * ss, 2.2 * K * ss, 1.9 * K * ss), mt('tela'), 0, 'torso')
        _elip(add, cadera + W(0, 0.2, 0.9), (2.75 * K * ss, 1.95 * K * ss, 0.55 * K * ss), mt('cuero'), 0, 'cinto')
        _elip(add, cadera + W(0, 2.0, 0.9), (0.55 * K * ss, 0.3 * K * ss, 0.45 * K * ss), mt('oxido'), 0, 'hebilla')
        for s in (-1, 1):
            _elip(add, pecho + W(3.0 * s, -0.2, 0.9), (1.4 * K * ss, 1.5 * K * ss, 0.9 * K * ss), mt('cuero'), 0, 'hombrera%d' % s)
        # la capa rasgada, que ondea un poco al andar
        for k in range(5):
            x = -2.4 + k * 1.2
            arriba = pecho + W(x, -2.0, 0.6)
            largo = (9.0 + (1.6 if k % 2 else -0.4) + 1.2 * math.sin(k * 2.3)) * K * sube
            abajo = V((x * 1.2 * K, -2.6 * K - 1.0 * inclina - 0.8 * abs(paso), max(arriba[2] - largo, 2.6 * sube)))
            if np.linalg.norm(abajo - arriba) > 0.4:
                add(lambda P, a=arriba, b=abajo: sd_caja(P, (a + b) / 2, ver._ejes_tira(a, b), (0.62 * K, 0.18, np.linalg.norm(b - a) / 2), 0.1),
                    mt('tela'), 0, 'capa%d' % k)
        # el yelmo vacio colgando del cinto, que se balancea
        y0 = W(-2.9, 0.8 - 0.4 * paso, 10.4)
        _cono(add, W(-2.4, 0.6, 12.2), y0 + W(0, 0, 1.2), 0.16, 0.16, mt('cuero'), 0, 'correa')
        _elip(add, y0, (1.5 * K * ss, 1.6 * K * ss, 1.3 * K * ss), mt('hierro'), 0, 'yelmo_colgado')
        _elip(add, y0 + W(0.5, 0.9, 0.4), (0.6 * ss, 0.5 * ss, 0.4 * ss), mt('oxido'), 0, 'abollon')
        # los brazos: el izquierdo cuelga muerto; el derecho, la espada
        for s in (-1, 1):
            hom = pecho + W(3.1 * s, 0.0, 0.4)
            if s == 1:
                # ALZA: la espada sube por encima del hombro; TAJO: baja en diagonal por delante; ESTOCA: al frente, recta
                al, tj, es = p['alza'], p['tajo'], p['estoca']
                codo = hom + W(0.9 + 0.4 * tj, 1.6 + 1.2 * es - 1.0 * al, -3.6 + 6.0 * al - 1.5 * tj + 2.4 * es)
                mano = codo + W(0.2 - 1.2 * tj, 2.6 + 2.0 * es - 1.6 * al + 1.0 * tj, -1.6 + 3.0 * al - 1.0 * tj + 1.4 * es)
            else:
                sw = p['brazos'] * 0.6
                codo = hom + W(0.6 * s, 0.4 + sw, -4.2)
                mano = codo + W(0.2 * s, 0.6 + sw, -4.0)
            _cono(add, hom, codo, 0.95 * K * ss, 0.8 * K * ss, mt('piel' if s == -1 else 'tela'), 0, 'brazo%d' % s)
            _cono(add, codo, mano, 0.8 * K * ss, 0.65 * K * ss, mt('piel'), 0, 'brazo%d' % s)
            _elip(add, mano, (0.8 * K * ss, 0.8 * K * ss, 0.8 * K * ss), mt('piel'), 0, 'mano%d' % s)
            if s == 1:
                # la hoja: de la vertical (alzada) a apuntar al frente (estocada) o cruzada abajo (tajo)
                d = V((0.15 - 0.6 * p['tajo'], 0.55 + 0.45 * p['estoca'] - 0.2 * p['alza'], -0.82 + 1.5 * p['alza'] + 0.75 * p['estoca'] - 0.2 * p['tajo']))
                d = d / np.linalg.norm(d)
                lh = 9.0 * K * ss
                _cono(add, mano - d * 1.0, mano + d * 0.4, 0.38, 0.38, mt('cuero'), 0, 'puno')
                lado = np.cross(d, V((0, 0, 1.0)))
                lado = lado / max(np.linalg.norm(lado), 1e-6) if np.linalg.norm(lado) > 0.1 else V((1.0, 0, 0))
                _cono(add, mano + d * 0.5 - lado * 1.1, mano + d * 0.5 + lado * 1.1, 0.3, 0.3, mt('oxido'), 0, 'guarda')
                punta = mano + d * lh
                add(lambda P, a=mano + d * 0.7, b=punta, l=lado: sd_caja(P, (a + b) / 2, ver._ejes_tira(a, b, lado=l),
                                                                      (0.55, 0.14, np.linalg.norm(b - a) / 2), 0.08),
                    mt('hierro'), 0, 'hoja')
                for u in (0.3, 0.55, 0.8):
                    _elip(add, mano + d * (0.7 + 8.3 * K * ss * u), (0.45, 0.45, 0.45), mt('oxido'), 0, 'roña')
        # los tallos naranjas de los hombros, con las puntas encendidas (crecen al final de la evolucion)
        crece = max(0.0, min(1.0, (ev - 0.55) / 0.4))
        if crece > 0.02:
            for s in (-1, 1):
                for j, alto in enumerate((5.5, 3.8)):
                    pie = pecho + W(2.8 * s, -0.6 - 0.8 * j, 1.2)
                    h = alto * K * crece
                    fin = pie + V((2.2 * s * crece, (-1.6 - j) * crece, h))
                    _curva(add, _bez(pie, pie + V((1.2 * s * crece, -1.0 * crece, h * 0.5)), fin, 5), 0.42, 0.26, mt('hongo'), 0, 'hom%d%d' % (s, j))
                    dd = fin - pie; dd = dd / max(np.linalg.norm(dd), 1e-6)
                    _cono(add, fin - dd * 0.3, fin + dd * 1.6 * crece, 0.39, 0.29, mt('luz'), 0, 'hom%d%dp' % (s, j))
            for i, (c, r) in enumerate([(pecho + W(-1.6, 1.6, -1.6), 1.2), (pecho + W(1.5, 1.6, -3.0), 1.0),
                                        (W(1.5, 1.3, 7.2), 0.9), (cuello + W(0, -0.6, 0.0), 1.1)]):
                rc = r * K * crece
                _elip(add, c, (rc, rc * 0.8, rc * 0.6), mt('micelio'), 0, 'mic%d' % i)
    # EL CUELLO DE HONGO y la campana. En la evolucion: es el tallo de la campana, que baja de su altura al cuello.
    alto_campana = 25.0 + (cuello[2] + 1.8 * K - 25.0) * sube
    base_t = V((0, 0, 1.5)) * (1 - sube) + (cuello - V((0, 0, 0.6))) * sube
    top = V((0, cuello[1] * sube + 0.8 * (1 - sube), alto_campana))
    medio = V((0, -0.6, 25.0 * 0.55)) * (1 - sube) + ((base_t + top) / 2 + V((0, -0.4, 0))) * sube
    _curva(add, _bez(base_t, medio, top), 1.7 - 0.3 * sube, 1.05, mt('carne'), 0.8)
    # AL EMPEZAR LA EVOLUCION es la CAMPANA PALIDA entera (memoria: la evolucion arranca en lo que era): sus raices, el
    # engorde del pecho y sus brazos finos, que se van recogiendo en el muerto mientras sube.
    f = 1.0 - sube
    if f > 0.02:
        _elip(add, (0, 0, 1.6), (2.1 * f + 0.01, 2.0 * f + 0.01, 1.8 * f + 0.01), mt('carne'), 1.2)
        for k in range(6):
            a = k / 6 * 2 * math.pi + 0.4
            _cono(add, (math.cos(a) * 1.2, math.sin(a) * 1.2, 1.4), (math.cos(a) * 3.6 * f, math.sin(a) * 3.6 * f, 0.2),
                  0.6 * f + 0.01, 0.22 * f + 0.01, mt('raiz'), 0, 'raices')
        pecho_c = V((0, 0.3, 25.0 * 0.7))
        _elip(add, pecho_c, (2.0 * f + 0.01, 1.8 * f + 0.01, 3.6 * f + 0.01), mt('carne'), 1.5)
        for s in (-1, 1):
            hom = pecho_c + V((1.9 * s, 0.2, 2.0))
            a = -p['brazos'] * s * 0.4
            codo = hom + V((0.8 * s, 0.6 + a * 2, -6.0 * f))
            mano = codo + V((0.3 * s, 1.0 + a * 3, -6.0 * f))
            _brazo(add, hom, codo, mano, 0.85 * f + 0.01, mt('carne'), 'brazoc%d' % s, dedos=f > 0.4)
    c0 = top + V((0, 0.1 + 0.3 * sube, 2.0 + 0.2 * sube))
    p2 = dict(p)
    p2['evo_fil'] = 1.0
    _campana(add, p2, c0, 1.0 - 0.3 * sube, mt)
    pf = p['puff']
    if 0.0 < pf < 1.0:
        for k in range(10):
            a = k / 10 * 2 * math.pi + 0.3
            rr = 6.0 + 6.0 * pf
            r = 2.6 * (1.0 - 0.6 * pf)
            _elip(add, c0 + V((math.cos(a) * rr, math.sin(a) * rr * 0.9 + 1.0, -2.0 + 4.0 * pf + 1.2 * math.sin(3 * a))),
                  (r, r, r), mt('hongo') if k % 3 == 0 else mt('mota'), 0, 'espora')
    return e.L


def escena(pose, lado_lanza=1):
    p = dict(pose)
    p['lado_lanza'] = lado_lanza
    return escena_campana(p) if VAR == 'campana' else escena_florecido(p)


def escena_dir(pose, d):
    return escena(pose, base._lado_del_latigo(d))


# ------------------------------------------------------------
#  ANIMACIONES. Las que comparte con el normal llevan SUS TIEMPOS (sus efectos siguen cayendo igual).
# ------------------------------------------------------------
def _de_normal(fn):
    return lambda t: POSE(**fn(t))


def a_idle(t):
    T = 2 * math.pi * t
    return POSE(mece=0.35 * math.sin(T), sacude=0.45 * math.sin(T + 1.9), brazos=0.22 * math.sin(T + 0.7),
                hincha=0.035 * (1 - math.cos(T)), ola=0.6 * math.sin(T + 0.5))


def a_walk(t):
    T = 2 * math.pi * t
    return POSE(mece=0.5 * math.sin(T * 2.0), balanceo=math.sin(T), sacude=1.0 * math.sin(T - 1.1),
                brazos=0.8 * math.sin(T - 0.5), patas=0.6 * math.sin(T), ola=0.9 * math.sin(T * 2 - 0.8))


def a_latigo(t):
    # EL BASICO DE LA CAMPANA: se echa atras y LANZA LOS FILAMENTOS al frente (toca en el mismo sitio que el del normal).
    return POSE(latigo=tramos(t, [(0.0, 0.0), (0.35, -0.3), (0.55, 1.0), (0.75, 0.8), (1.0, 0.0)]),
                mece=tramos(t, [(0.0, 0.0), (0.35, -1.4), (0.55, 1.6), (0.75, 1.0), (1.0, 0.2)]),
                avance=tramos(t, [(0.0, 0.0), (0.35, -0.8), (0.55, 1.8), (1.0, 0.6)]),
                sacude=tramos(t, [(0.0, 0.0), (0.35, -0.4), (0.55, 0.6), (1.0, 0.0)]))


def a_tajo(t):
    # EL BASICO DEL FLORECIDO: alza la espada a tirones (como un titere) y la deja CAER en diagonal (toca en ~0,55).
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.2, 0.6), (0.35, 1.0), (0.55, 0.0), (1.0, 0.0)]),
                tajo=tramos(t, [(0.0, 0.0), (0.35, 0.0), (0.55, 1.0), (0.75, 1.0), (1.0, 0.2)]),
                mece=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 1.6), (0.75, 1.2), (1.0, 0.2)]),
                avance=tramos(t, [(0.0, 0.0), (0.35, -0.6), (0.55, 2.4), (1.0, 0.8)]),
                sacude=tramos(t, [(0.0, 0.0), (0.2, 0.8), (0.35, -0.5), (0.55, 0.9), (1.0, 0.0)]))


def a_estocada(t):
    # ESTOCADA DEL MUERTO: se encoge con la espada atras y SE LANZA recto al frente (toca en 0,5).
    return POSE(estoca=tramos(t, [(0.0, 0.0), (0.3, -0.4), (0.5, 1.0), (0.8, 1.0), (1.0, 0.1)]),
                inclina=tramos(t, [(0.0, 0.0), (0.3, -0.15), (0.5, 0.45), (0.8, 0.4), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.3, -1.2), (0.5, 4.5), (0.8, 4.0), (1.0, 1.0)]),
                patas=tramos(t, [(0.0, 0.0), (0.3, -0.4), (0.5, 0.7), (1.0, 0.0)]),
                sacude=tramos(t, [(0.0, 0.0), (0.5, 1.0), (1.0, 0.0)]))


def a_esporas(t):
    # Las del normal (mismos tiempos): la campana se hincha, aguanta y suelta.
    return POSE(**dict(base.anim_esporas(t), ola=0.8 * math.sin(2 * math.pi * t)))


def a_micelio(t):
    q = base.anim_micelio(t)
    if VAR == 'florecido':
        q['lanza'] = 0.0
        q['estoca'] = q['brazos'] * 0.3
    return POSE(**q)


def a_destello_carga(t):
    # SE ENCIENDE: la campana se alza hacia delante y el nucleo crece, latiendo (lo que avisa).
    lat = 0.5 + 0.5 * math.sin(2 * math.pi * t)
    return POSE(destella=0.55 + 0.25 * lat, hincha=0.06 * lat, mece=-0.6, ola=1.2 * math.sin(4 * math.pi * t),
                vibra=0.15 * math.sin(6 * math.pi * t))


def a_destello(t):
    # EL DESTELLO: la campana se abre de golpe hacia el frente y vuelve (toca en 0,4).
    return POSE(destella=tramos(t, [(0.0, 0.8), (0.25, 1.0), (0.4, 1.3), (0.6, 0.6), (1.0, 0.0)]),
                hincha=tramos(t, [(0.0, 0.06), (0.25, 0.14), (0.4, -0.08), (0.6, 0.0), (1.0, 0.0)]),
                mece=tramos(t, [(0.0, -0.6), (0.4, 1.2), (0.6, 0.6), (1.0, 0.0)]),
                latigo=tramos(t, [(0.0, 0.0), (0.4, 0.5), (0.7, 0.0), (1.0, 0.0)]))


def a_encaje(t):
    return POSE(**dict(base.anim_encaje(t), ola=tramos(t, [(0.0, 1.5), (0.34, -1.0), (0.67, 0.4), (1.0, 0.0)])))


def a_muerte(t):
    # SE DESPLOMA hacia delante y la LUZ SE APAGA poco a poco (sin saltos de color).
    return POSE(derrumbe=tramos(t, [(0.0, 0.0), (0.14, 0.04), (0.3, 0.12), (0.5, 0.45), (0.7, 0.85), (0.85, 1.02), (1.0, 1.0)]),
                hunde=tramos(t, [(0.0, 0.0), (0.14, 0.3), (0.5, 0.5), (1.0, 0.6)]),
                hincha=tramos(t, [(0.0, 0.0), (0.14, 0.1), (0.5, -0.06), (1.0, -0.12)]),
                agacha=tramos(t, [(0.0, 0.0), (0.3, 0.7), (1.0, 0.9)]),
                brazos=tramos(t, [(0.0, 0.0), (0.14, 0.5), (0.5, -0.4), (1.0, -0.5)]),
                ola=tramos(t, [(0.0, 0.0), (0.3, 1.2), (0.7, -0.6), (1.0, 0.0)]),
                apaga=tramos(t, [(0.0, 0.0), (0.2, 0.0), (0.9, 0.95), (1.0, 0.95)]))


def a_comer(t):
    # Se agacha sobre lo que come y la campana lo envuelve, latiendo.
    sobre = tramos(t, [(0.0, 0.0), (0.2, 1.0), (0.85, 1.0), (1.0, 0.0)])
    return POSE(agacha=sobre, mece=0.9 * sobre, hincha=0.05 * math.sin(6 * math.pi * t) * sobre,
                ola=1.0 * math.sin(4 * math.pi * t) * sobre, latigo=0.25 * sobre, alza=0.0)


def _paso(t, a, b):
    u = max(0.0, min(1.0, (t - a) / (b - a)))
    return u * u * (3 - 2 * u)


def a_evolucion(t):
    # Tiembla siendo lo que era y cambia SIN CORTES: forma y color a la vez, poco a poco (memoria transiciones-de-color).
    # La CAMPANA: el cuerpo gordo se estira en tallo y el sombrero se vuelve campana. El FLORECIDO: del suelo sube el muerto
    # alrededor del tallo, la campana baja hasta su cuello, y al final le brotan los tallos de los hombros.
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.6, 0.78))
    return POSE(evo=_paso(t, 0.12, 0.85), tinte=_paso(t, 0.06, 0.8), vibra=0.3 * tiembla,
                hincha=tramos(t, [(0.0, 0.0), (0.4, 0.1), (0.8, 0.0), (0.9, 0.12), (1.0, 0.0)]),
                ola=1.4 * math.sin(4 * math.pi * t), destella=tramos(t, [(0.0, 0.0), (0.82, 0.0), (0.9, 0.9), (1.0, 0.0)]))


ANIMS = {
    'idle': (8, 3.0, True, 8, a_idle),
    'walk': (8, 5.0, True, 8, a_walk),
    'embestida': (8, 8.0, False, 8, a_latigo if VAR == 'campana' else a_tajo),
    'esporas': (8, 12.0, False, 8, a_esporas),
    'micelio': (8, 12.0, False, 8, a_micelio),
    'destello_carga': (8, 8.0, True, 8, a_destello_carga),
    'destello': (8, 12.0, False, 8, a_destello),
    'encaje': (4, 18.0, False, 8, a_encaje),
    'muerte': (10, 10.0, False, 8, a_muerte),
    'comer': (10, 10.0, False, 8, a_comer),
    'evolucion': (20, 10.0, False, 8, a_evolucion),
}
if VAR == 'florecido':
    ANIMS['estocada'] = (8, 13.0, False, 8, a_estocada)


# ------------------------------------------------------------
#  LA HOJA PARA MIRARLA (sin tocar assets: se hornea tras su visto bueno)
# ------------------------------------------------------------
def _hoja_ver(nombres):
    from PIL import Image, ImageDraw
    import sdf_gpu
    DIRS = (1, 4)     # SE de frente y N de espaldas
    pedidas = nombres or list(ANIMS.keys())
    trabajos = []; quien = []
    for nm in pedidas:
        n, _fps, loop, _d, fn = ANIMS[nm]
        for d in DIRS:
            for i in range(n):
                t = i / n if loop else i / max(1, n - 1)
                trabajos.append((MODELO, escena_dir(fn(t), d), d)); quien.append((nm, d, i))
    fotos = dict(zip(quien, sdf_gpu.render_lote(trabajos)))
    ESC = 3
    recortes = []
    for nm in pedidas:
        for d in DIRS:
            tira = [fotos[(nm, d, i)] for i in range(ANIMS[nm][0])]
            cajas = [f.getbbox() for f in tira if f.getbbox()]
            c = (min(x[0] for x in cajas) - 2, min(x[1] for x in cajas) - 2, max(x[2] for x in cajas) + 2, max(x[3] for x in cajas) + 2)
            # tocar el borde del lienzo = se sale
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
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes', 'miconido_%s_hojas' % VAR)
    os.makedirs(esc, exist_ok=True)
    os.makedirs(VISTAS, exist_ok=True)
    nombre = 'miconido_%s_%s.png' % (VAR, '_'.join(nombres) if nombres and len(nombres) <= 3 else 'todas')
    hoja.save(os.path.join(esc, nombre))
    hoja.save(VISTAS + nombre)
    print(os.path.join(esc, nombre), hoja.size)
    if 'evolucion' in pedidas:
        for d in DIRS:
            medias = []
            for i in range(ANIMS['evolucion'][0]):
                a = np.asarray(fotos[('evolucion', d, i)]).astype(float)
                dentro = a[:, :, 3] > 0
                medias.append(a[dentro][:, :3].mean(axis=0))
            print('evolucion d%d: mayor salto de color %.1f' % (d, max(np.abs(x - y).sum() for x, y in zip(medias, medias[1:]))))


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja_ver(args[1:])
    else:
        hornear('miconido_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
