# ============================================================
#  acechador_sdf.py -- el ACECHADOR en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (acechador_sprites.gd): LA LECTURA CONTRARIA DEL JABALI. Alto y estrecho, un galgo con dientes: patas LARGAS de
#  canido (la trasera con su corvejon en Z), la GRUPA ALTA y los hombros hundidos, la cabeza BAJA y adelantada por
#  debajo del lomo (la postura de acecho), morro largo con mandibula y colmillos hacia ABAJO, crin corta solo en la
#  nuca y una cola larga que CAE hacia el suelo. Casi negro: lo que se lee son los OJOS amarillos, los COLMILLOS de
#  hueso y el lomo iluminado.
#  Lienzo y origen de su horneado (1,80 -> 130 x 130, el centro).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/acechador_sdf.py [anim ...]  -> assets/sprites/enemigos/acechador_sdf/<anim>.png
#       python tools/sprites_sdf/acechador_sdf.py vistas     -> tools/salida/sdf/acechador_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/acechador_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Pardo casi negro (554e47); el lomo se aclara a pardo CENIZA, las patas casi negras (los calcetines del lobo).
MAT = {
    'piel':    [(0.22, 0.18, 0.15), (0.34, 0.29, 0.24), (0.50, 0.43, 0.35)],
    'pata':    [(0.12, 0.10, 0.09), (0.18, 0.15, 0.13), (0.27, 0.23, 0.20)],
    'crin':    [(0.10, 0.09, 0.08), (0.15, 0.13, 0.12), (0.22, 0.20, 0.18)],
    'morro':   [(0.15, 0.13, 0.12), (0.22, 0.19, 0.17), (0.30, 0.27, 0.24)],
    'hueso':   [(0.72, 0.68, 0.56), (0.88, 0.85, 0.72), (0.96, 0.94, 0.84)],
    'ojo':     [(0.98, 0.84, 0.30)] * 3,
    'pupila':  [(0.08, 0.05, 0.02)] * 3,
    'boca':    [(0.30, 0.08, 0.08), (0.40, 0.12, 0.11), (0.48, 0.16, 0.14)],
}
MODELO = Modelo(1.8, (130, 130), (65, 65), MAT, (0.06, 0.05, 0.04), suaves=('cuerpo', 'cabeza'),
                brillan=('ojo', 'pupila'), corta_suelo=True)

# LA LINEA DEL LOMO SUBE HACIA ATRAS (pecho 13, grupa 17): la del jabali, al reves.
PECHO = V((0.0, 5.4, 12.6))
GRUPA = V((0.0, -9.0, 16.6))
CABEZA = V((0.0, 15.6, 10.0))
NUCA = V((0.0, 9.0, 13.0))
COLA_NACE = V((0.0, -13.0, 16.0))

LUNGE_DIST = 13.0
SALTO_ALTO = 5.2
ENCAJE_RETRO = 0.34
PASO_LARGO = 2.4
PIVOTE_EMPINA = V((0.0, -9.6, 0.0))   # al EMPINARSE gira sobre las patas traseras
PIVOTE_CAIDA = V((-4.0, 0.0, 0.0))    # al MORIR cae de lado sobre su costado derecho


def POSE(**k):
    # Las claves del viejo (acechador_sprites.gd), en sus unidades: avance/alza/hocico/sacude/cabeza en unidades de
    # mundo; tumba 1 = de lado; patas -1..1 el trote (pasof, su coseno: que pata va en el aire); recoge 0..1 las patas
    # recogidas en el salto; empina sobre las traseras; zi/zd = el zarpazo de la mano izquierda/derecha.
    p = dict(avance=0.0, estira=1.0, patas=0.0, pasof=0.0, agacha=0.0, cabeza=0.0, alza=0.0, cola=0.0, recoge=0.0,
             hocico=0.0, boca=0.0, sacude=0.0, empina=0.0, zi_alza=0.0, zi_barre=0.0, zd_alza=0.0, zd_barre=0.0,
             tumba=0.0)
    p.update(k)
    return p


def _off_cabeza(p):
    return V((p['sacude'], p['hocico'], p['cabeza']))


def huesos(p):
    X = {}
    # EL CUERPO se estira a lo largo y se AGACHA aplastandose en alto con las patas (como se agazapa en el viejo).
    raiz = (np.diag([1.0, p['estira'] * (1.0 + 0.07 * p['agacha']), 1.0 - 0.26 * p['agacha']]), np.zeros(3))
    if p['empina'] != 0.0:
        raiz = comp(sobre(PIVOTE_EMPINA, rx(-math.atan(0.32 * p['empina']))), raiz)
    if p['tumba'] != 0.0:
        raiz = comp(sobre(PIVOTE_CAIDA, ry(-p['tumba'] * math.pi * 0.5)), raiz)
    raiz = comp((np.eye(3), V((0.0, p['avance'], p['alza']))), raiz)
    X['raiz'] = raiz
    # La cabeza va EXAGERADA (x1,35 desde la base del craneo), como en el viejo: a su tamaño real sale de 8 px y el
    # contorno se come los colmillos y la boca, que es justo lo que se tiene que leer. Se DISPARA (hocico), sube y baja
    # (cabeza) y se sacude de lado (sacude) desplazandose, como en el viejo; el cuello se estira detras.
    X['cabeza'] = comp(raiz, comp((np.eye(3), _off_cabeza(p)), sobre(CABEZA - V((0.0, 2.6, 0.6)), np.eye(3) * 1.35)))
    # LA MANDIBULA baja sobre su bisagra al abrir la boca.
    X['mandibula'] = comp(X['cabeza'], sobre(CABEZA + V((0.0, 0.2, -1.4)), rx(p['boca'] * 0.5)))
    return X


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _unit(v):
    return v / np.linalg.norm(v)


def _pata_delantera(add, p, s):
    g = 'pata_d_%d' % s
    al = p['zi_alza'] if s < 0 else p['zd_alza']
    if al > 0.08:
        # EL ZARPAZO: la mano sube por delante y BARRE de lado (la del viejo: se adelanta 11 y sube).
        ba = p['zi_barre'] if s < 0 else p['zd_barre']
        hom = V((2.6 * s, 7.0, 12.8))
        # (Alta y adelantada de sobra: con lo justo del viejo, en 3D la mano no asomaba del perfil del pecho.)
        mano = V((s * (3.4 + al * 1.6) + ba * 3.5 * s, 6.6 + al * 10.5, 8.0 + al * 8.0))
        codo = (hom + mano) * 0.5 + V((0.6 * s, -0.6, -1.4))
        _cono(add, hom, codo, 2.4, 1.6, 'piel', 0.8, g)
        _cono(add, codo, mano, 1.5, 1.15, 'pata', 0.6, g)
        hacia = _unit(mano - codo)
        _elip(add, mano + hacia * 0.8, (1.6, 1.8, 1.15), 'pata', 0.6, g)
        lado = _unit(V((-hacia[1], hacia[0], 0.0)) + 1e-6)
        for u in (-1, 0, 1):
            b = mano + hacia * 1.8 + lado * u * 0.9
            _cono(add, b, b + hacia * 1.4 - V((0.0, 0.0, 0.6)), 0.42, 0.12, 'hueso', 0, 'una')
        return
    sw = p['patas'] * s
    lift = max(0.0, p['pasof'] * s) * 1.6
    enc = p['recoge'] * 1.8
    dy = sw * PASO_LARGO - p['recoge'] * 1.6
    hom = V((2.6 * s, 6.6, 12.6))
    codo = V((2.9 * s, 5.6 + dy * 0.55, 7.2 + enc * 0.8 + lift * 0.5))
    mun = V((3.1 * s, 6.4 + dy, 2.0 + enc * 1.5 + lift))
    _cono(add, hom, codo, 2.4, 1.5, 'piel', 0.8, g)
    _cono(add, codo, mun, 1.35, 0.95, 'pata', 0.6, g)
    _elip(add, mun + V((0.0, 0.9, -1.2)), (1.35, 1.8, 0.85), 'pata', 0.6, g)


def _pata_trasera(add, p, s):
    g = 'pata_t_%d' % s
    sw = -p['patas'] * s
    lift = max(0.0, -p['pasof'] * s) * 1.6
    enc = p['recoge'] * 1.8
    dy = sw * PASO_LARGO + p['recoge'] * 1.6
    cad = V((2.8 * s, -9.0, 15.0))
    rod = V((3.2 * s, -6.6 + dy * 0.4 + enc * 0.6, 9.6 + enc * 0.6 + lift * 0.4))
    cor = V((3.3 * s, -10.6 + dy, 4.8 + enc * 1.2 + lift))
    pie = V((3.3 * s, -9.6 + dy, 1.0 + enc * 1.5 + lift))
    _elip(add, (3.0 * s, -8.2, 12.4), (2.4, 3.8, 4.0), 'piel', 1.2, g)
    _cono(add, cad, rod, 2.4, 1.6, 'piel', 0.8, g)
    _cono(add, rod, cor, 1.4, 1.0, 'pata', 0.6, g)
    _cono(add, cor, pie, 1.0, 0.95, 'pata', 0.5, g)
    _elip(add, pie + V((0.0, 0.9, -0.2)), (1.3, 1.7, 0.8), 'pata', 0.5, g)


def escena(pose):
    p = pose
    e = Escena(huesos(p)); add = e.add
    # --- EL TRONCO: pecho hondo y estrecho, cintura recogida (el galgo) y la grupa alta y musculada.
    _elip(add, PECHO, (4.4, 5.4, 4.4), 'piel', 0)
    _elip(add, (0.0, -1.6, 14.6), (3.8, 7.2, 3.2), 'piel', 3.0)
    _elip(add, GRUPA, (4.8, 5.0, 4.4), 'piel', 3.0)
    # El vientre recogido: sube del pecho a la ingle (lo que dice "corre").
    _elip(add, (0.0, 3.0, 10.2), (3.0, 3.6, 2.0), 'piel', 2.5)
    # ESCAPULAS: asoman por encima de la linea del lomo, en los hombros hundidos; al trotar suben por turnos.
    for s in (-1, 1):
        _elip(add, (2.6 * s, 6.0, 15.0 + max(0.0, p['patas'] * s) * 1.0), (1.5, 2.6, 2.2), 'piel', 1.6)
    # --- EL CUELLO: baja del pecho a la cabeza, FINO; se estira detras de la cabeza cuando esta se dispara.
    _cono(add, (0.0, 8.0, 13.4), V((0.0, 13.6, 10.8)) + _off_cabeza(p), 2.5, 1.8, 'piel', 1.6)
    # --- LA CABEZA, baja y adelantada: craneo, morro largo POR DEBAJO del eje y la mandibula.
    _elip(add, CABEZA, (2.6, 2.9, 2.4), 'piel', 0, 'cabeza', 'cabeza')
    _cono(add, CABEZA + V((0.0, 1.6, -0.3)), V((0.0, 20.6, 9.0)), 2.0, 1.15, 'piel', 1.2, 'cabeza', 'cabeza')
    _elip(add, (0.0, 21.0, 9.0), (1.05, 0.8, 0.9), 'morro', 0, 'nariz', 'cabeza')
    _cono(add, CABEZA + V((0.0, 1.0, -1.7)), V((0.0, 19.6, 7.5)), 1.5, 0.9, 'piel', 1.0, 'cabeza', 'mandibula')
    # La boca ABIERTA: lo rojo de dentro entre el morro y la mandibula.
    if p['boca'] > 0.05:
        _elip(add, (0.0, 18.0, 8.0 - 0.6 * p['boca']), (1.2, 2.4, 0.4 + 0.9 * p['boca']), 'boca', 0, 'boca_dentro',
              'cabeza')
    # La comisura: la raja roja a cada lado entre morro y mandibula (enseña los dientes).
    for s in (-1, 1):
        _cono(add, V((1.15 * s, 16.9, 8.2)), V((0.85 * s, 20.0, 8.1)), 0.5, 0.35, 'boca', 0, 'boca', 'cabeza')
    for s in (-1, 1):
        # OREJAS: puntiagudas y echadas hacia atras.
        _cono(add, CABEZA + V((1.5 * s, -0.6, 1.6)), CABEZA + V((2.3 * s, -2.6, 4.6)), 1.2, 0.25, 'piel', 0.5, 'cabeza',
              'cabeza')
        # OJOS: amarillos, grandes para la cabeza, que ASOMEN de la superficie, con la pupila rasgada.
        oj = CABEZA + V((1.75 * s, 2.1, 0.9))
        _elip(add, oj, (0.85, 0.8, 0.7), 'ojo', 0, 'ojo', 'cabeza')
        _elip(add, oj + V((0.45 * s, 0.35, 0.0)), (0.3, 0.3, 0.55), 'pupila', 0, 'ojo', 'cabeza')
        # COLMILLOS: cuatro, hacia ABAJO, por fuera de la boca (los de arriba largos).
        for y0, x0, largo in ((20.0, 1.0, 2.4), (17.8, 1.35, 1.7)):
            a = V((x0 * s, y0, 8.3))
            _cono(add, a, a + V((0.1 * s, 0.25, -largo)), 0.62, 0.16, 'hueso', 0, 'colmillo', 'cabeza')
    # --- LA CRIN: corta y erizada, SOLO en la nuca y la cruz; puntas que sobresalen del perfil.
    for i in range(7):
        u = i / 6.0
        y = 11.4 - u * 7.4
        z = 12.4 + u * 2.6
        x = 0.6 if i % 2 else -0.6
        _cono(add, (x, y, z), (x * 1.5, y - 2.0, z + 2.6 - 0.5 * (i % 2)), 0.95, 0.2, 'crin', 0, 'crin')
    # --- LAS PATAS: LARGAS, de canido. La delantera cae casi a plomo (hombro, codo, muñeca, mano); la trasera con su
    # muslo gordo, la rodilla delante y el CORVEJON atras (la Z que dice "salta").
    for s in (-1, 1):
        _pata_delantera(add, p, s)
        _pata_trasera(add, p, s)
    # --- LA COLA: larga y baja, por PASOS FIJOS (una cadena hecha con puntos de curva se abre). Cae, BARRE de lado
    # ('cola', como en el viejo: mas cuanto mas a la punta) y casi toca el suelo, con la punta algo levantada.
    pt = COLA_NACE.astype(float); d = _unit(V((0.0, -0.75, -0.25))); r = 1.25
    for i in range(12):
        q = pt + d * 1.3
        _cono(add, pt, q, r, max(0.45, r - 0.07), 'piel' if i < 9 else 'crin', 0.4, 'cola')
        pt = q; r = max(0.45, r - 0.07)
        giro = 0.2 if i < 6 else -0.12
        d = _unit(rx(-giro) @ d + V((0.035 * math.sin(i * 0.8) + 0.07 * p['cola'], 0.0, 0.0)))
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def _suave(a, b, x):
    u = min(max((x - a) / (b - a), 0.0), 1.0)
    return u * u * (3 - 2 * u)


def anim_idle(t):
    # La cabeza BAJA y apenas se mueve; la cola barre de lado a lado.
    w = 2 * math.pi * t
    return POSE(estira=1.0 + 0.015 * math.sin(w), cabeza=-0.25 + 0.2 * math.sin(w), cola=math.sin(w))


def anim_walk(t):
    w = 2 * math.pi * t
    return POSE(estira=1.0 + 0.025 * math.sin(2 * w), patas=math.sin(w), pasof=math.cos(w),
                agacha=0.05 * (1 - math.cos(2 * w)), cabeza=-0.3 + 0.55 * math.sin(w), cola=math.sin(w * 0.5))


def anim_embestida(t):
    # AGAZAPARSE -> SALTO con las patas recogidas -> caer encima.
    alza = tramos(t, [(0.0, 0.0), (0.26, 0.0), (0.42, 0.75), (0.58, 1.0), (0.74, 0.35), (0.86, 0.0), (1.0, 0.0)])
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.26, -1.4), (0.50, 4.6), (0.70, 8.6), (0.86, 9.4), (1.0, 7.0)]) *
                (LUNGE_DIST / 9.4),
                alza=alza * SALTO_ALTO, recoge=alza,
                estira=tramos(t, [(0.0, 1.0), (0.26, 0.92), (0.50, 1.08), (0.70, 1.10), (0.86, 0.95), (1.0, 1.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.26, 0.80), (0.50, 0.20), (0.70, 0.0), (0.86, 0.55), (1.0, 0.1)]),
                cabeza=tramos(t, [(0.0, -0.3), (0.26, -1.5), (0.50, -0.2), (0.70, 0.4), (0.86, -1.2), (1.0, -0.3)]),
                cola=0.4)


def anim_basico(t):
    # La DENTELLADA: abre, dispara el hocico y cierra de golpe.
    return POSE(hocico=tramos(t, [(0.0, 0.0), (0.2, -1.0), (0.36, 3.2), (0.55, 2.8), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.0), (0.2, 1.0), (0.3, 1.0), (0.38, 0.0), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.2, 0.3), (0.36, 0.1), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.2, -0.6), (0.36, 1.4), (0.6, 1.2), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, -0.3), (0.2, -0.8), (0.36, 0.2), (1.0, -0.3)]),
                cola=0.6 * math.sin(2 * math.pi * t))


_Z_ALZA = [(0.0, 0.0), (0.18, 1.0), (0.36, 0.55), (0.5, 0.0), (1.0, 0.0)]
_Z_BARRE = [(0.0, 0.0), (0.18, 1.0), (0.36, -1.0), (0.5, -0.3), (0.62, 0.0), (1.0, 0.0)]


def anim_zarpazo(t):
    # DOS zarpazos: la izquierda y, desfasada 4/11, la derecha; se empina un poco con cada uno.
    d = 4.0 / 11.0
    t2 = min(max(t - d, 0.0), 1.0)
    zi_a = tramos(t, _Z_ALZA); zi_b = tramos(t, _Z_BARRE)
    zd_a = tramos(t2, _Z_ALZA) if t >= d else 0.0
    zd_b = tramos(t2, _Z_BARRE) if t >= d else 0.0
    m = max(zi_a, zd_a)
    return POSE(zi_alza=zi_a, zi_barre=zi_b, zd_alza=zd_a, zd_barre=zd_b, empina=0.6 * m, boca=0.5 * m, cabeza=0.4,
                cola=0.5 * math.sin(2 * math.pi * t))


def anim_yugular(t):
    # A LA YUGULAR: se agazapa, salta un poco, muerde arriba y se empina con la presa.
    return POSE(agacha=tramos(t, [(0.0, 0.0), (0.1, 0.7), (0.24, 0.8), (0.34, 0.1), (0.62, 0.0), (0.74, 0.25),
                                  (0.85, 0.3), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, -0.3), (0.24, -1.8), (0.4, 0.4), (0.62, 1.2), (0.74, 2.4), (0.85, 2.0),
                                  (1.0, -0.3)]),
                hocico=tramos(t, [(0.0, 0.0), (0.24, -0.8), (0.45, 1.0), (0.7, 2.2), (0.78, 2.6), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.0), (0.5, 0.2), (0.66, 1.0), (0.75, 0.0), (1.0, 0.0)]),
                estira=tramos(t, [(0.0, 1.0), (0.24, 0.9), (0.4, 1.1), (0.62, 1.1), (0.74, 0.97), (1.0, 1.0)]),
                recoge=tramos(t, [(0.0, 0.0), (0.26, 0.0), (0.34, 0.8), (0.55, 1.0), (0.68, 0.3), (0.74, 0.0),
                                  (1.0, 0.0)]),
                empina=tramos(t, [(0.0, 0.0), (0.62, 0.1), (0.74, 0.7), (0.85, 0.6), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.24, -1.2), (0.34, 0.0), (1.0, 0.0)]),
                cola=tramos(t, [(0.0, 0.3), (0.24, -0.6), (0.5, 0.8), (1.0, 0.2)]),
                alza=tramos(t, [(0.0, 0.0), (0.3, 0.0), (0.4, 0.5), (0.6, 0.5), (0.72, 0.0), (1.0, 0.0)]) * SALTO_ALTO)


def anim_desgarrar(t):
    # MUERDE y SACUDE la cabeza de lado a lado tirando hacia atras.
    return POSE(hocico=tramos(t, [(0.0, 0.0), (0.2, -0.6), (0.36, 3.0), (0.5, 2.6), (0.7, 1.4), (1.0, 0.0)]),
                boca=tramos(t, [(0.0, 0.0), (0.2, 1.0), (0.3, 1.0), (0.37, 0.0), (1.0, 0.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.2, -0.4), (0.36, 1.4), (0.5, 0.4), (0.7, -2.4), (0.85, -2.0),
                                  (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.0), (0.36, 0.15), (0.55, 0.5), (0.75, 0.55), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, -0.3), (0.36, -0.2), (0.55, -1.0), (0.75, -0.8), (1.0, -0.3)]),
                sacude=1.3 * math.sin(2 * math.pi * (t - 0.4) * 3.0) * (_suave(0.38, 0.45, t) - _suave(0.75, 0.85, t)),
                cola=-0.5)


def anim_encaje(t):
    # Empieza YA golpeado: retrocede encogido con la cabeza alzada y vuelve.
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.48), (0.67, 0.14), (1.0, 0.0)]) * LUNGE_DIST * ENCAJE_RETRO,
                estira=tramos(t, [(0.0, 0.84), (0.34, 1.10), (0.67, 0.96), (1.0, 1.0)]),
                agacha=tramos(t, [(0.0, 0.80), (0.34, 0.30), (0.67, 0.08), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 2.2), (0.34, -0.9), (0.67, 0.2), (1.0, -0.3)]), cola=-0.8)


def anim_muerte(t):
    # Se le doblan las patas y CAE DE LADO; la cabeza se va al suelo.
    return POSE(tumba=tramos(t, [(0.0, 0.0), (0.14, 0.12), (0.28, 0.34), (0.45, 0.62), (0.62, 0.88), (0.78, 1.0),
                                 (1.0, 1.0)]),
                agacha=tramos(t, [(0.0, 0.15), (0.14, 0.62), (0.28, 0.88), (0.45, 0.80), (1.0, 0.62)]),
                cabeza=tramos(t, [(0.0, -0.3), (0.14, -1.1), (0.45, -2.2), (1.0, -2.6)]),
                cola=tramos(t, [(0.0, 0.6), (0.28, 0.3), (1.0, 0.0)]))


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo. El cadaver sale del ultimo de 'muerte'.
ANIMS = {
    'idle': (8, 6.0, True, 8, anim_idle),
    'walk': (8, 10.0, True, 8, anim_walk),
    'embestida': (8, 12.0, False, 8, anim_embestida),
    'basico': (8, 16.0, False, 8, anim_basico),
    'zarpazo': (12, 20.0, False, 8, anim_zarpazo),
    'yugular': (14, 16.0, False, 8, anim_yugular),
    'desgarrar': (12, 18.0, False, 8, anim_desgarrar),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'acechador_554e47_1.80', VISTAS + 'acechador_vs_viejo.png', 3))
    else:
        hornear('acechador_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
