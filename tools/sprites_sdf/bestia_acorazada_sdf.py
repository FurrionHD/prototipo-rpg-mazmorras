# ============================================================
#  bestia_acorazada_sdf.py -- la BESTIA ACORAZADA en 3D (05/10/2026), con el motor de los enemigos (sdf_comun).
#  ES LA VERSION E de bestia_acorazada_versiones.py ("este esta buenardo"): una mole roja de PLACAS gordas erizadas de
#  puas, con el VIENTRE palido, COLLAR y BRAZALETES de hierro con tachuelas, cabeza de cocodrilo con la boca abierta,
#  casco de hierro y cuernos, y la cola segmentada con anillos de hierro y puas. (La 1a, la de bandas de armadillo,
#  queda en el historial de git.) Sus MUTANTES, en bestia_acorazada_mutantes.py: esos NO se animan aqui (tendran sus
#  propios ataques).
#  Lo del viejo (bestia_acorazada_sprites.gd) que se conserva: BAJA y ANCHA, patas COLUMNARES, encaja casi sin moverse
#  (resist_aturdir), la CARGA que avisa mucho y arranca tarde, se agazapa y escarba antes de cargar, y la pueden
#  VOLCAR panza arriba (volcar / volcada / enderezarse).
#  Lienzo 130 x 130 con los pies en el CENTRO (el juego coloca el lienzo por su centro; el viejo, 92, no le cabe).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/bestia_acorazada_sdf.py [anim ...] -> assets/sprites/enemigos/bestia_acorazada_sdf/
#       python tools/sprites_sdf/bestia_acorazada_sdf.py vistas    -> tools/salida/sdf/bestia_acorazada_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/bestia_acorazada_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

MAT = {
    'rojo':    [(0.36, 0.09, 0.10), (0.52, 0.15, 0.15), (0.66, 0.24, 0.22)],
    'hierro':  [(0.12, 0.10, 0.10), (0.20, 0.17, 0.17), (0.30, 0.26, 0.26)],
    'vientre': [(0.54, 0.48, 0.42), (0.70, 0.64, 0.57), (0.82, 0.77, 0.70)],
    'pua':     [(0.50, 0.47, 0.42), (0.68, 0.65, 0.59), (0.82, 0.80, 0.74)],
    'boca':    [(0.46, 0.10, 0.10), (0.66, 0.20, 0.18), (0.80, 0.32, 0.28)],
    'ojo':     [(1.00, 0.15, 0.10)] * 3,
}
BORDE = (0.08, 0.04, 0.04)
LADO = 130

LUNGE_DIST = 8.0
ENCAJE_RETRO = 0.13       # la mas baja del juego: a esto no lo mueves de un mandoble
PASO_LARGO = 1.5
AGAZAPA = 0.65
VOLCADA_ABRE = 0.7
PIVOTE_ALZA = V((0.0, -5.8, 0.0))     # se encabrita sobre las traseras
EJE_VUELCO = V((0.0, 0.0, 8.2))       # al volcarse, panza arriba con el lomo en el suelo
CUELLO = V((0.0, 9.0, 9.6))
H = V((0.0, 12.6, 9.0))               # la cabeza


def POSE(**k):
    # Las claves del viejo: patas (-1..1, el paso; pasof su coseno), hunde (se bambolea de lado), escarba (las
    # delanteras raspan hacia atras), alza (se encabrita sobre las traseras), vuelco (rad, sobre el eje largo: pi =
    # panza arriba), abre (patas abiertas: muerta o volcada), zi/zd = el zarpazo de cada mano.
    p = dict(avance=0.0, estira=1.0, patas=0.0, pasof=0.0, agacha=0.0, cabeza=0.0, hunde=0.0, escarba=0.0, alza=0.0,
             vuelco=0.0, abre=0.0, zi_alza=0.0, zi_barre=0.0, zd_alza=0.0, zd_barre=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    raiz = (np.diag([1.0, p['estira'] * (1.0 + 0.07 * p['agacha']), 1.0 - 0.24 * p['agacha']]), np.zeros(3))
    if p['hunde'] != 0.0:
        raiz = comp((ry(-math.atan(0.055 * p['hunde'])), np.zeros(3)), raiz)
    if p['alza'] != 0.0:
        raiz = comp(sobre(PIVOTE_ALZA, rx(-math.atan(0.42 * p['alza']))), raiz)
    if p['vuelco'] != 0.0:
        raiz = comp(sobre(EJE_VUELCO, ry(p['vuelco'])), raiz)
    # Muerta (patas abiertas sin volcar) se DESPLOMA sobre la panza.
    baja = 1.8 * p['abre'] if abs(p['vuelco']) < 0.5 else 0.0
    raiz = comp((np.eye(3), V((0.0, p['avance'], -baja))), raiz)
    X['raiz'] = raiz
    # La cabeza baja (cabeza < 0: la testuz por delante para cargar) y sube, cabeceando sobre el cuello.
    X['cabeza'] = comp(raiz, comp((np.eye(3), V((0.0, 0.0, p['cabeza'] * 0.9))), sobre(CUELLO, rx(-p['cabeza'] * 0.07))))
    return X


def _unit(v):
    v = V(v, dtype=float)
    return v / np.linalg.norm(v)


def marco(adelante, arriba=(0.0, 0.0, 1.0)):
    y = _unit(adelante)
    x = _unit(np.cross(y, V(arriba, dtype=float)))
    return [x, y, np.cross(x, y)]


class K:
    """Las piezas de siempre, con su lambda bien atada y su hueso."""
    def __init__(self, e):
        self.add = e.add
        self.n = 0

    def elip(self, c, r, mat, k=0.0, g='cuerpo', h='raiz'):
        self.add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, g, h)

    def cono(self, a, b, ra, rb, mat, k=0.0, g='cuerpo', h='raiz'):
        self.add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, g, h)

    def caja(self, c, ejes, medio, mat, red=0.3, k=0.0, g='cuerpo', h='raiz'):
        self.add(lambda P, c=V(c, dtype=float), m=V(medio, dtype=float): sd_caja(P, c, ejes, m, red), mat, k, g, h)

    def pua(self, base, d, largo, r, mat, g='pua', h='raiz'):
        """Punta ROMA (afilada se queda en contorno negro) y grupos alternos (entre dos que se tapan, la raya)."""
        base = V(base, dtype=float)
        self.n += 1
        self.cono(base, base + _unit(d) * largo, r, min(0.35, r * 0.4), mat, 0, '%s%d' % (g, self.n % 2), h)


def _pata(k, s, y0, p, delantera):
    lado = 0 if s < 0 else 1
    al = (p['zi_alza'], p['zd_alza'])[lado] if delantera else 0.0
    ba = (p['zi_barre'], p['zd_barre'])[lado] if delantera else 0.0
    sw = p['patas'] * s * (1.0 if delantera else -1.0)
    lift = max(0.0, p['pasof'] * s * (1.0 if delantera else -1.0)) * 1.4
    dy = sw * PASO_LARGO - (p['escarba'] * 2.2 if delantera else 0.0) + al * 4.6
    sube = al * 4.8 + lift + (p['escarba'] * 0.8 if delantera else 0.0)
    ab = p['abre']
    cad = V((5.4 * s + s * ab * 1.2, y0, 8.6 - ab * 1.6))
    pie = V((6.6 * s + s * (ab * 3.4 + al * 2.0 + ba * 3.2), y0 + 0.8 + dy, 1.6 + sube))
    rod = (cad + pie) * 0.5 + V((0.9 * s, 0.1, 0.4))
    g = 'pata'
    k.cono(cad, rod, 3.4, 2.8, 'rojo', 0.8, g)
    k.cono(rod, pie, 2.8, 2.6, 'rojo', 0.8, g)
    k.elip(pie + V((0.0, 0.5, -0.17)), (3.0, 3.5, 1.56), 'rojo', 0.8, g)
    # El BRAZALETE de hierro sobre el tobillo y las UÑAS palidas.
    d = _unit(pie - rod)
    k.cono(pie - d * 0.2 + V((0.0, 0.0, 1.4)), pie - d * 0.2 + V((0.0, 0.0, 0.3)), 3.0, 2.9, 'hierro', 0, 'brazal')
    for j in (-1, 0, 1):
        base = V((pie[0] + j * 1.95, pie[1] + 3.1, pie[2] - 0.9))
        k.cono(base, base + V((j * 0.2, 1.4, -0.45)), 0.5, 0.1, 'pua', 0, 'garra')
    k.pua((7.6 * s + s * ab * 1.2, y0 - 0.6, 8.4 - ab * 1.6), (1.0 * s, -0.3, 0.5), 3.2, 1.2, 'pua', 'pua_hombro')


def escena(pose):
    p = pose
    e = Escena(huesos(p)); k = K(e)
    # El cuerpo: una mole redonda, con el VIENTRE palido debajo.
    k.elip((0.0, 0.0, 9.4), (7.4, 9.0, 6.0), 'rojo')
    k.elip((0.0, 2.0, 6.2), (5.6, 7.6, 3.6), 'vientre', 1.6)
    # PLACAS ROJAS gordas sobre el lomo (cada una su grupo: entre ellas, la raya), cada una con su pua.
    for i, (x, y, z, r) in enumerate(((0.0, 4.2, 14.6, 3.8), (-3.6, -1.0, 14.0, 3.4), (3.6, -1.0, 14.0, 3.4),
                                      (0.0, -5.6, 13.4, 3.4), (-4.8, 4.0, 12.0, 2.8), (4.8, 4.0, 12.0, 2.8))):
        k.elip((x, y, z), (r, r * 1.05, r * 0.6), 'rojo', 0, 'placa_%d' % i)
        k.pua((x * 1.05, y - 0.4, z + r * 0.5), (x * 0.1, -0.35, 1.0), 5.2 if i < 4 else 3.6, 1.5, 'pua', 'pua')
    # COLLAR DE HIERRO en el cuello con tachuelas.
    k.cono((0.0, 7.6, 10.6), (0.0, 11.0, 9.0), 4.6, 3.8, 'rojo', 2.0)
    k.cono((0.0, 9.0, 10.2), (0.0, 10.4, 9.6), 4.7, 4.3, 'hierro', 0, 'collar')
    for a in range(7):
        t = math.pi * (0.1 + 0.8 * a / 6.0)
        k.pua((4.5 * math.cos(t), 9.7, 9.9 + 4.3 * math.sin(t) * 0.9), (math.cos(t), 0.0, math.sin(t)), 1.8, 0.8,
              'pua', 'tachuela')
    # La CABEZA de cocodrilo con la boca abierta, el casco de hierro y los cuernos.
    hc = 'cabeza'
    k.elip(H, (3.4, 3.2, 2.8), 'rojo', 1.0, 'cabeza', hc)
    k.cono(H + V((0.0, 1.0, 0.6)), H + V((0.0, 6.6, 0.0)), 2.8, 1.8, 'rojo', 1.0, 'cabeza', hc)
    k.caja(H + V((0.0, 2.2, 2.0)), marco((0.0, 1.0, -0.1)), (2.2, 3.8, 0.7), 'hierro', 0.4, 0, 'casco', hc)
    k.pua(H + V((0.0, 6.0, 1.0)), (0.0, 0.6, 1.0), 1.8, 0.7, 'pua', 'cuerno', hc)
    k.cono(H + V((0.0, 0.8, -1.6)), H + V((0.0, 5.8, -3.2)), 2.4, 1.6, 'vientre', 1.0, 'mandibula', hc)
    k.elip(H + V((0.0, 3.6, -1.3)), (2.0, 2.8, 1.0), 'boca', 0, 'boca', hc)
    for s in (-1, 1):
        for i in range(4):
            k.pua(H + V((1.7 * s, 2.6 + 1.1 * i, -0.4)), (0.0, 0.1, -1.0), 1.0, 0.36, 'pua', 'diente', hc)
        k.elip(H + V((2.4 * s, 2.0, 1.4)), (0.6, 0.6, 0.51), 'ojo', 0, 'ojo', hc)
        k.pua(H + V((2.0 * s, -0.8, 1.8)), (0.6 * s, -0.8, 0.5), 2.6, 0.8, 'pua', 'cuerno', hc)
    # LAS PATAS: columnares, con brazaletes y uñas; se mueven con el paso, escarban, abren y dan zarpazos.
    for s in (-1, 1):
        _pata(k, s, 5.4, p, True)
        _pata(k, s, -5.8, p, False)
    # LA COLA: segmentada (anillos de hierro) y con puas, baja y se levanta en la punta. Por PASOS FIJOS.
    pt = V((0.0, -8.6, 9.0)); d = _unit((0.0, -1.0, -0.2)); n = 10
    for j in range(n):
        r = 2.8 + (0.9 - 2.8) * j / (n - 1)
        rb = 2.8 + (0.9 - 2.8) * (j + 1) / (n - 1)
        q = pt + d * 1.5
        k.cono(pt, q, r, rb, 'rojo', 0.5, 'cola')
        if j % 2 == 1:
            k.cono(q - d * 0.35, q + d * 0.35, rb * 1.12, rb * 1.08, 'hierro', 0, 'anillo')
        if j % 2 == 0 and j < 9:
            k.pua(q + V((0.0, 0.0, rb * 0.8)), (0.0, -0.5, 1.0), 2.8, 0.95, 'pua', 'pua_cola')
        pt = q; d = _unit(rx(0.08 if j > 4 else -0.02) @ d)
    return e.L


def _modelo(L):
    # TODOS los grupos 'suaves' (con k 0 se unen duro igual): entre dos piezas que se tapan, la raya de dentro.
    grupos = tuple(dict.fromkeys(x[2] for x in L))
    return Modelo(1.95, (LADO, LADO), (LADO // 2, LADO // 2), MAT, BORDE, suaves=grupos, brillan=('ojo',),
                  corta_suelo=True)


# Los grupos son los mismos en todas las poses (ninguna pieza aparece ni desaparece al animar).
MODELO = _modelo(escena(POSE()))


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def _suave(a, b, x):
    u = min(max((x - a) / (b - a), 0.0), 1.0)
    return u * u * (3 - 2 * u)


def anim_idle(t):
    # Resuella, muy lento: el fuelle del costado y la cabeza, un poco.
    w = 2 * math.pi * t
    return POSE(estira=1.0 + 0.018 * math.sin(w), cabeza=0.30 * math.sin(w))


def anim_walk(t):
    # Paso corto y pesado: se BAMBOLEA (un costado y luego el otro).
    w = 2 * math.pi * t
    return POSE(patas=math.sin(w), pasof=math.cos(w), hunde=math.sin(w), agacha=0.05 * (1 - math.cos(2 * w)),
                cabeza=0.5 * math.sin(w))


def anim_embestida(t):
    # PLANTARSE (escarba) -> arrancar -> impacto -> frenar: avisa mucho y arranca tarde.
    ag = tramos(t, [(0.0, 0.0), (0.38, 0.62), (0.66, 0.88), (0.82, 0.50), (1.0, 0.08)])
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.38, -1.2), (0.66, 4.8), (0.82, 8.0), (1.0, 6.0)]) * (LUNGE_DIST / 8.0),
                estira=tramos(t, [(0.0, 1.0), (0.38, 0.94), (0.66, 1.06), (0.82, 0.96), (1.0, 1.0)]),
                agacha=ag, cabeza=-1.9 * ag,
                escarba=tramos(t, [(0.0, 0.0), (0.20, 1.0), (0.38, 0.25), (1.0, 0.0)]))


def anim_encaje(t):
    # Casi no se mueve: lo que se sacude es la CABEZA.
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.40), (0.67, 0.10), (1.0, 0.0)]) * LUNGE_DIST * ENCAJE_RETRO,
                estira=tramos(t, [(0.0, 0.92), (0.34, 1.05), (0.67, 0.98), (1.0, 1.0)]),
                agacha=tramos(t, [(0.0, 0.55), (0.34, 0.14), (0.67, 0.04), (1.0, 0.0)]),
                cabeza=tramos(t, [(0.0, 2.6), (0.34, -0.8), (0.67, 0.3), (1.0, 0.0)]))


def anim_muerte(t):
    # NO vuelca: se le abren las patas y se DESPLOMA sobre la panza, con la cabeza al suelo.
    return POSE(agacha=tramos(t, [(0.0, 0.10), (0.16, 0.45), (0.34, 0.72), (0.55, 0.88), (0.78, 0.95), (1.0, 0.95)]),
                cabeza=tramos(t, [(0.0, 0.0), (0.16, -0.8), (0.34, -1.8), (0.55, -2.6), (1.0, -3.0)]),
                avance=tramos(t, [(0.0, 0.0), (0.16, 0.8), (0.34, 1.2), (0.55, 1.0), (1.0, 0.9)]),
                abre=tramos(t, [(0.0, 0.0), (0.16, 0.3), (0.34, 0.7), (0.55, 1.0), (1.0, 1.0)]))


def anim_agazapar(t):
    # Baja la testuz y se planta (el aviso de la carga).
    kk = 1.0 - (1.0 - t) * (1.0 - t)
    return POSE(agacha=AGAZAPA * kk, cabeza=-1.9 * AGAZAPA * kk, estira=1.0 - 0.05 * kk)


def anim_escarbar(t):
    # Agazapada, raspa el suelo con las delanteras (en bucle mientras carga).
    w = 2 * math.pi * t
    return POSE(agacha=AGAZAPA, cabeza=-1.9 * AGAZAPA + 0.2 * math.sin(w), escarba=0.5 + 0.5 * math.sin(w),
                estira=0.95 + 0.012 * math.sin(2 * w), hunde=0.25 * math.sin(w))


def anim_arremeter(t):
    # LA CARGA EN EL MAPA: corre agachada y, al llegar, se ENCABRITA y estampa la testuz.
    corre = 1.0 - _suave(0.26, 0.36, t)
    return POSE(alza=tramos(t, [(0.0, 0.0), (0.3, 0.0), (0.44, 1.4), (0.56, -0.15), (0.72, 0.05), (1.0, 0.0)]),
                agacha=tramos(t, [(0.0, 0.75), (0.3, 0.75), (0.44, 0.1), (0.56, 0.8), (0.72, 0.3), (1.0, 0.05)]),
                cabeza=tramos(t, [(0.0, -1.5), (0.3, -1.5), (0.44, 1.6), (0.56, -1.4), (0.72, -0.3), (1.0, 0.0)]) +
                0.5 * math.sin(2 * math.pi * t * 6.4) * corre,
                estira=tramos(t, [(0.0, 1.04), (0.3, 1.04), (0.44, 0.96), (0.56, 1.12), (0.72, 0.99), (1.0, 1.0)]),
                patas=1.6 * math.sin(2 * math.pi * t * 3.2) * corre,
                pasof=math.cos(2 * math.pi * t * 3.2) * corre,
                hunde=0.9 * math.sin(2 * math.pi * t * 3.2) * corre)


_Z_ALZA = [(0.0, 0.0), (0.18, 1.0), (0.36, 0.55), (0.5, 0.0), (1.0, 0.0)]
_Z_BARRE = [(0.0, 0.0), (0.18, 1.0), (0.36, -1.0), (0.5, -0.3), (0.62, 0.0), (1.0, 0.0)]


def anim_zarpazo(t):
    # DOS zarpazos (izquierda y, desfasada 4/11, la derecha), bamboleandose hacia la mano que pega.
    d = 4.0 / 11.0
    t2 = min(max(t - d, 0.0), 1.0)
    zi_a = tramos(t, _Z_ALZA); zd_a = tramos(t2, _Z_ALZA) if t >= d else 0.0
    return POSE(zi_alza=zi_a, zi_barre=tramos(t, _Z_BARRE), zd_alza=zd_a,
                zd_barre=tramos(t2, _Z_BARRE) if t >= d else 0.0, hunde=0.9 * (zd_a - zi_a), agacha=0.18, cabeza=-0.5)


def anim_volcar(t):
    # LA VUELCAN: rueda sobre el costado hasta quedar PANZA ARRIBA, pataleando.
    return POSE(vuelco=tramos(t, [(0.0, 0.0), (0.35, 0.9), (0.7, 2.5), (1.0, math.pi)]),
                patas=0.8 * math.sin(2 * math.pi * t * 1.5), abre=VOLCADA_ABRE * _suave(0.3, 1.0, t))


def anim_volcada(t):
    # Panza arriba, meciendose y pataleando al aire (en bucle).
    w = 2 * math.pi * t
    return POSE(vuelco=math.pi + 0.14 * math.sin(w), patas=1.5 * math.sin(2 * w),
                abre=VOLCADA_ABRE + 0.12 * math.sin(2 * w), cabeza=0.6 * math.sin(w))


def anim_enderezarse(t):
    # Se da la vuelta de un golpe y vuelve a quedar de pie.
    return POSE(vuelco=tramos(t, [(0.0, math.pi), (0.35, 2.3), (0.7, 0.6), (0.85, -0.1), (1.0, 0.0)]),
                patas=0.8 * math.sin(2 * math.pi * t * 1.5) * (1.0 - t), abre=VOLCADA_ABRE * (1.0 - _suave(0.0, 0.7, t)))


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo. El cadaver sale del ultimo de 'muerte'.
ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 5.0, True, 8, anim_walk),
    'embestida': (8, 9.0, False, 8, anim_embestida),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 9.0, False, 8, anim_muerte),
    'agazapar': (5, 10.0, False, 8, anim_agazapar),
    'escarbar': (8, 8.0, True, 8, anim_escarbar),
    'arremeter': (10, 12.0, False, 8, anim_arremeter),
    'zarpazo': (12, 20.0, False, 8, anim_zarpazo),
    'volcar': (6, 12.0, False, 8, anim_volcar),
    'volcada': (8, 8.0, True, 8, anim_volcada),
    'enderezarse': (6, 12.0, False, 8, anim_enderezarse),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'bestia_acorazada_804d40_1.95', VISTAS + 'bestia_acorazada_vs_viejo.png', 3))
    else:
        hornear('bestia_acorazada_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
