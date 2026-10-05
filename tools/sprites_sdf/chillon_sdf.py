# ============================================================
#  chillon_sdf.py -- el CHILLON en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (chillon_sprites.gd): un MURCIELAGO CIEGO que NO SE POSA NUNCA. Sin ojos: la cara la cuentan las OREJAS ENORMES (piel
#  clara, casi verticales, separadas), la HOJA NASAL (lo mas claro del bicho) y los PALETOS. El cuerpo CUELGA por debajo
#  del plano de las alas; las patas van TENDIDAS hacia atras con la membrana de la cola entre ellas. EL ALA NO SE
#  PLIEGA, BATE (y solo se recoge al picar y al morir). Las alas son LAMINAS (sd_triangulo): huesos oscuros por encima
#  de una membrana clara, con el borde de salida en festones entre dedo y dedo.
#  LA SOMBRA va en el SUELO (Escena.sombra): en uno que vuela es lo unico que se lee como altura.
#  Lienzo y origen de su horneado (1,40 -> 80 x 80; el origen es el punto del SUELO, alto en el lienzo: 40, 43).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/chillon_sdf.py [anim ...]  -> assets/sprites/enemigos/chillon_sdf/<anim>.png
#       python tools/sprites_sdf/chillon_sdf.py vistas     -> tools/salida/sdf/chillon_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/chillon_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Gris azulado (6a7480): pelo oscuro; la piel desnuda (orejas, nariz, membrana) tira a rosa apagado, que es el unico
# sitio donde deja de ser gris y lo que hace que la cara se vea a la primera.
MAT = {
    'pelo':     [(0.17, 0.19, 0.22), (0.27, 0.29, 0.33), (0.38, 0.41, 0.46)],
    'membrana': [(0.35, 0.30, 0.33), (0.49, 0.43, 0.46), (0.60, 0.53, 0.56)],
    'dedo':     [(0.13, 0.14, 0.16), (0.20, 0.21, 0.24), (0.27, 0.29, 0.32)],
    'oreja':    [(0.47, 0.39, 0.42), (0.64, 0.55, 0.57), (0.76, 0.67, 0.69)],
    'oreja_in': [(0.40, 0.29, 0.32), (0.55, 0.41, 0.44), (0.64, 0.50, 0.52)],
    'nariz':    [(0.62, 0.48, 0.50), (0.79, 0.65, 0.65), (0.88, 0.76, 0.75)],
    'boca':     [(0.08, 0.05, 0.06)] * 3,
    'diente':   [(0.86, 0.85, 0.78), (0.94, 0.93, 0.88), (0.98, 0.97, 0.93)],
    'garra':    [(0.10, 0.10, 0.12), (0.15, 0.16, 0.18), (0.22, 0.23, 0.26)],
}
# Algo mayor que su escala (1,4), como los demas que se han pasado: el viejo exageraba el tamaño.
MODELO = Modelo(1.5, (80, 80), (40, 43), MAT, (0.07, 0.07, 0.09), suaves=('cuerpo', 'cabeza'), brillan=(),
                corta_suelo=True)

VUELO_Z = 12.0
LUNGE_DIST = 12.0
ENCAJE_RETRO = 0.55
# El hombro: la raiz del ala, en el COSTADO (no en el lomo: naciendo del lomo sale con las alas puestas como una
# mochila). Es tambien el eje sobre el que se YERGUE el cuerpo (las alas no se mueven: el bicho cuelga de ellas).
HOMBRO = V((2.0, 1.8, VUELO_Z + 0.2))
NUCA = V((0.0, 4.0, VUELO_Z - 1.4))

# EL ALA en su plano (a lo LARGO del ala, hacia ATRAS): abierta y recogida (al picar, al morir). 'tobillo' se
# sustituye por el de la pata: la membrana baja pegada al cuerpo hasta ahi.
ALA_ABIERTA = {'codo': (4.4, -1.1), 'muneca': (8.4, 0.1), 'pulgar': (9.3, -0.9),
               'd2': (14.2, 0.7), 'd3': (13.6, 4.6), 'd4': (10.8, 7.2), 'd5': (6.8, 7.6)}
ALA_RECOGIDA = {'codo': (3.2, -0.4), 'muneca': (4.0, 1.0), 'pulgar': (4.5, 0.2),
                'd2': (4.4, 6.2), 'd3': (3.9, 6.8), 'd4': (3.2, 7.0), 'd5': (2.4, 6.6)}


def POSE(**k):
    p = dict(bate=0.0, vuela=0.0, avance=0.0, mece=0.0, balanceo=0.0, cabeza=0.0, boca=0.0, orejas=0.0, patas=0.0,
             encara=0.0, cae=0.0, tumba=0.0, apoyo=0.0, rumbo=0.0, recoge=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    # TODO EL BICHO: avanza, sube (vuela), cabecea (mece: morro abajo al picar), se ladea (balanceo) y, al morir, gira
    # en planta (rumbo) y vuelca de costado (tumba) sobre su eje morro-grupa YA EN EL SUELO.
    centro = V((0.0, 0.0, VUELO_Z - 1.2))
    raiz = (np.eye(3), V((0.0, p['avance'], p['vuela'] + p['apoyo'])))
    raiz = comp(raiz, sobre(centro, rz(p['rumbo'])))
    raiz = comp(raiz, sobre(centro, ry(p['tumba'] * math.pi * 0.5)))
    raiz = comp(raiz, sobre(centro, rx(p['mece'] * 0.16)))
    raiz = comp(raiz, sobre(centro, ry(p['balanceo'] * 0.14)))
    X['raiz'] = raiz
    # ERGUIRSE: el cuerpo gira alrededor del hombro (con 'encara' 1 cuelga casi vertical).
    X['cuerpo'] = comp(raiz, sobre(V((0.0, HOMBRO[1], HOMBRO[2])), rx(-p['encara'] * 0.55)))
    X['cabeza'] = comp(X['cuerpo'], sobre(NUCA, rx(p['cabeza'] * 0.45)))
    return X


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='cuerpo'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='cuerpo'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _lamina(add, a, b, c, mat='membrana', grosor=0.22, grupo='ala', hueso='mundo'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float), c=V(c, dtype=float): sd_triangulo(P, a, b, c, grosor),
        mat, 0, grupo, hueso)


def _elip_girado(add, c, ejes, r, mat, grupo, hueso):
    """Elipsoide con sus ejes (3 vectores unitarios, filas) y semiejes r: las orejas, que son palas inclinadas."""
    E = V(ejes, dtype=float); c = V(c, dtype=float); r = V(r, dtype=float)
    add(lambda P: sd_elipsoide((P - c) @ E.T, np.zeros(3), r), mat, 0, grupo, hueso)


def _pata(p, s):
    """Cadera -> tobillo, en el marco del CUERPO: tendidas hacia atras; 'patas' las sube y las baja."""
    cad = V((1.15 * s, -3.4, VUELO_Z - 2.1))
    a = p['patas'] * 0.35
    d = V((0.30 * s, -0.90 * math.cos(a) , -0.28 + 0.6 * math.sin(a)))
    d /= np.linalg.norm(d)
    return cad, cad + d * 4.4


def _punto_ala(p, s, span, atras):
    """Un punto del ala (a lo largo, hacia atras) en el marco de la RAIZ. El BATEO gira el ala sobre el hombro (la
    punta va algo RETRASADA: el ala se curva), y al CAER (muerte) se le apaga: cuelga."""
    th = p['bate'] * 0.95 - 0.55 * p['cae']
    lag = -0.22 * p['bate']            # la punta va por detras del hombro
    phi = th + lag * (span / 14.0)
    caida = 1.4 * p['cae'] * (atras / 7.6) * (span / 14.0)
    return HOMBRO * V((s, 1, 1)) + V((s * span * math.cos(phi), -atras, span * math.sin(phi) - caida))


def escena(pose):
    p = pose
    X = huesos(p)
    e = Escena(X); add = e.add
    Z = VUELO_Z
    # --- EL CUERPO, colgado por debajo del plano de las alas: pecho gordo, panza, grupa.
    _elip(add, (0.0, 1.6, Z - 1.5), (3.0, 3.2, 2.8), 'pelo', 0.9)
    _elip(add, (0.0, -1.4, Z - 1.8), (2.2, 2.9, 2.1), 'pelo', 0.9)
    _elip(add, (0.0, -3.6, Z - 2.0), (1.3, 1.6, 1.2), 'pelo', 0.6)
    # --- LA CABEZA, adelantada y algo mas baja que el lomo, con el morro corto y romo.
    _elip(add, (0.0, 5.4, Z - 2.1), (2.4, 2.3, 2.2), 'pelo', 0.6, 'cabeza', 'cabeza')
    _elip(add, (0.0, 6.9, Z - 2.9), (1.25, 1.4, 1.1), 'pelo', 0.6, 'cabeza', 'cabeza')
    # LA HOJA NASAL: una lanza de piel vertical sobre el morro, lo mas claro del bicho.
    _elip(add, (0.0, 7.95, Z - 2.2), (0.95, 0.40, 1.45), 'nariz', 0, 'nariz', 'cabeza')
    # LA BOCA y LOS PALETOS (el mordisco): la boca crece hacia abajo al abrirse.
    b = p['boca']
    _elip(add, (0.0, 7.5, Z - 3.75 - 0.35 * b), (1.0, 0.85, 0.45 + 0.75 * b), 'boca', 0, 'boca', 'cabeza')
    for sx in (-1, 1):
        _cono(add, (0.42 * sx, 8.05, Z - 3.45), (0.42 * sx, 8.1, Z - 4.1 - 0.15 * b), 0.36, 0.30, 'diente', 0, 'diente',
              'cabeza')
    # --- LAS OREJAS: palas largas y estrechas, casi verticales y algo abiertas; por delante la piel de dentro, mas
    # oscura. 'orejas' las gira: + hacia delante (chilla), - hacia atras (pica).
    for s in (-1, 1):
        base = V((1.25 * s, 5.0, Z - 0.6))
        d = V((0.30 * s, -0.18, 0.94))
        a = p['orejas'] * 0.55
        d = V((d[0], d[1] * math.cos(a) + d[2] * math.sin(a), -d[1] * math.sin(a) + d[2] * math.cos(a)))
        d /= np.linalg.norm(d)
        frente = np.cross(d, V((1.0 * s, 0.0, 0.0))) * s
        frente /= np.linalg.norm(frente)
        if frente[1] < 0: frente = -frente
        ancho = np.cross(frente, d)
        c = base + d * 3.0
        _elip_girado(add, c, (ancho, frente, d), (1.55, 0.6, 3.4), 'oreja', 'oreja', 'cabeza')
        _elip_girado(add, c + frente * 0.38 + d * 0.2, (ancho, frente, d), (1.0, 0.32, 2.7), 'oreja_in', 'oreja',
                     'cabeza')
    # --- LAS PATAS, tendidas hacia atras, con el pie oscuro; y EL UROPATAGIO tensado entre los dos tobillos y la cola.
    tob = {}
    for s in (-1, 1):
        cad, t = _pata(p, s)
        _cono(add, cad, t, 0.62, 0.45, 'pelo', 0, 'pata', 'cuerpo')
        _elip(add, t + V((0.1 * s, -0.5, -0.2)), (0.55, 0.85, 0.45), 'garra', 0, 'pata', 'cuerpo')
        tob[s] = aplica(X['cuerpo'], t)
    cola = aplica(X['cuerpo'], V((0.0, -6.8, Z - 3.0)))
    grupa = aplica(X['cuerpo'], V((0.0, -3.2, Z - 2.1)))
    for s in (-1, 1):
        _lamina(add, tob[s], cola, grupa, grupo='cola')
    _cono(add, aplica(X['cuerpo'], V((0.0, -4.4, Z - 2.3))), cola, 0.35, 0.25, 'dedo', 0, 'cola', 'mundo')
    # --- LAS ALAS, en el marco de la RAIZ (no se yerguen con el cuerpo). Cada punto: abierta -> recogida.
    raiz = X['raiz']
    rec = min(1.0, p['recoge'] + 0.55 * p['cae'])
    for s in (-1, 1):
        q = {}
        for k in ALA_ABIERTA:
            (s0, a0), (s1, a1) = ALA_ABIERTA[k], ALA_RECOGIDA[k]
            q[k] = aplica(raiz, _punto_ala(p, s, s0 + (s1 - s0) * rec, a0 + (a1 - a0) * rec))
        hom = aplica(raiz, HOMBRO * V((s, 1, 1)))
        flanco = aplica(X['cuerpo'], V((1.6 * s, -2.4, Z - 1.4)))
        # El borde de salida en FESTONES: entre dedo y dedo la membrana se mete hacia la muñeca.
        def feston(a, b, k=0.20):
            m = 0.5 * (a + b)
            return m + (q['muneca'] - m) * k
        dedos = ['d2', 'd3', 'd4', 'd5']
        for i in range(3):
            a, bb = q[dedos[i]], q[dedos[i + 1]]
            m = feston(a, bb, 0.12 if i == 0 else 0.22)
            _lamina(add, q['muneca'], a, m)
            _lamina(add, q['muneca'], m, bb)
        m5 = feston(q['d5'], tob[s], 0.0)
        m5 = m5 + (q['codo'] - m5) * 0.18
        _lamina(add, q['codo'], q['muneca'], q['d5'])
        _lamina(add, q['codo'], q['d5'], m5)
        _lamina(add, q['codo'], m5, tob[s])
        _lamina(add, q['codo'], tob[s], flanco)
        _lamina(add, hom, q['codo'], flanco)
        # El borde de ataque, delante del brazo (hombro -> muñeca).
        _lamina(add, hom, q['codo'], q['muneca'], grosor=0.2)
        # LOS HUESOS por encima: brazo, antebrazo, dedos y el pulgar con su uña.
        _cono(add, hom, q['codo'], 0.75, 0.55, 'dedo', 0, 'ala', 'mundo')
        _cono(add, q['codo'], q['muneca'], 0.55, 0.42, 'dedo', 0, 'ala', 'mundo')
        for dd in dedos:
            _cono(add, q['muneca'], q[dd], 0.42, 0.26, 'dedo', 0, 'ala', 'mundo')
        _cono(add, q['muneca'], q['pulgar'], 0.42, 0.30, 'garra', 0, 'ala', 'mundo')
    # --- LA SOMBRA en el suelo, bajo el cuerpo (no sube con el: esa separacion es el vuelo). Algo menor cuanto mas alto.
    alto = max(0.0, VUELO_Z + p['vuela'] + p['apoyo'])
    k = 1.0 - 0.18 * min(alto / VUELO_Z, 1.5)
    e.sombra(0.0, p['avance'] + 0.5, 6.5 * k, 3.6 * k)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
S2 = lambda t, f=0.0: math.sin(2 * math.pi * t + f)
CABECEO = 0.95


def anim_idle(t):
    # REVOLOTEA en el sitio: bateo corto y nervioso, el cuerpo medio ERGUIDO (es lo que lo separa del walk).
    return POSE(bate=0.62 * S2(t), vuela=CABECEO * 0.75 * S2(t, -1.9), encara=0.55, cabeza=0.14 * math.sin(math.pi * t),
                orejas=0.10 * math.sin(math.pi * t + 1.0), patas=0.15 * S2(t))


def anim_walk(t):
    # EN MARCHA: el mismo bateo pero AMPLIO y el cuerpo tendido; las orejas atras (va lanzado).
    return POSE(bate=S2(t), vuela=CABECEO * S2(t, -1.9), mece=0.5 * S2(t, -1.9), balanceo=0.35 * math.sin(math.pi * t),
                cabeza=0.10 * math.sin(math.pi * t), orejas=-0.25, patas=0.30 * S2(t))


def anim_embestida(t):
    # EL PICADO: sube, se deja caer con la boca abierta (alas RECOGIDAS: al picar no bate) y vuelve a subir.
    boca = tramos(t, [(0.0, 0.0), (0.30, 0.15), (0.44, 0.70), (0.62, 1.0), (0.78, 0.35), (1.0, 0.0)])
    return POSE(vuela=tramos(t, [(0.0, 0.0), (0.16, 4.2), (0.30, 6.4), (0.44, 1.0), (0.62, -3.4), (0.78, 1.6), (1.0, 4.6)]),
                avance=tramos(t, [(0.0, 0.0), (0.16, -1.8), (0.30, -2.4), (0.44, 4.0), (0.62, 11.0), (0.78, 8.0),
                                  (1.0, 5.4)]) * (LUNGE_DIST / 11.0),
                bate=tramos(t, [(0.0, 0.0), (0.16, -0.9), (0.30, 0.95), (0.44, 0.80), (0.62, 0.55), (0.78, -0.85),
                                (1.0, 0.30)]),
                recoge=tramos(t, [(0.0, 0.0), (0.30, 0.1), (0.44, 0.65), (0.62, 0.55), (0.78, 0.0)]),
                boca=boca,
                mece=tramos(t, [(0.0, 0.0), (0.30, -0.8), (0.44, 0.9), (0.62, 1.7), (0.78, 0.2), (1.0, -0.4)]),
                encara=0.70 * min(max(1.0 - t * 3.2, 0.0), 1.0),
                orejas=-0.55 * min(max(t * 2.5, 0.0), 1.0),
                patas=0.55 * boca)


def anim_chillido(t):
    # SE PARA EN EL AIRE, se yergue del todo, apunta las orejas hacia ti y grita. La QUIETUD es el gesto.
    boca = tramos(t, [(0.0, 0.0), (0.143, 0.20), (0.286, 0.85), (0.429, 1.0), (0.571, 1.0), (0.714, 1.0), (0.857, 0.55),
                      (1.0, 0.10)])
    enc = tramos(t, [(0.0, 0.35), (0.143, 0.20), (0.286, 0.80), (0.429, 0.95), (0.571, 0.95), (0.714, 0.95),
                     (0.857, 0.70), (1.0, 0.45)])
    return POSE(boca=boca,
                orejas=tramos(t, [(0.0, 0.0), (0.143, 0.35), (0.286, 0.85), (0.429, 1.0), (0.571, 1.0), (0.714, 1.0),
                                  (0.857, 0.60), (1.0, 0.15)]),
                encara=enc,
                bate=tramos(t, [(0.0, -0.70), (0.143, 0.60), (0.286, 0.30), (0.429, 0.18), (0.571, 0.18), (0.714, 0.18),
                                (0.857, 0.40), (1.0, -0.30)]),
                vuela=0.8 * enc, cabeza=-0.20 * boca, patas=0.45 * enc)


def anim_encaje(t):
    # Empieza YA golpeado: sale despedido como un trapo, las alas a destiempo, pierde altura de golpe.
    r = tramos(t, [(0.0, 1.0), (0.34, 0.45), (0.67, 0.14), (1.0, 0.0)])
    m = tramos(t, [(0.0, -2.1), (0.34, 1.1), (0.67, -0.40), (1.0, 0.0)])
    return POSE(avance=-r * LUNGE_DIST * ENCAJE_RETRO, mece=m, balanceo=m * 0.5, bate=0.95 - 1.7 * r, vuela=-2.6 * r,
                cabeza=m * 0.35, boca=0.55 * r, orejas=-0.8 * r, encara=0.30)


def anim_muerte(t):
    # EL UNICO QUE MUERE CAYENDO: las alas se apagan lo primero, la caida ACELERA y se estampa de costado.
    cae = tramos(t, [(0.0, 0.15), (0.14, 0.55), (0.30, 0.80), (1.0, 1.0)])
    return POSE(vuela=tramos(t, [(0.0, 0.0), (0.14, -0.6), (0.30, -1.8), (0.48, -4.2), (0.66, -7.6), (0.82, -11.2),
                                 (1.0, -VUELO_Z)]),
                cae=cae,
                tumba=tramos(t, [(0.0, 0.0), (0.30, 0.06), (0.48, 0.20), (0.66, 0.52), (0.82, 0.88), (1.0, 1.0)]),
                rumbo=tramos(t, [(0.0, 0.0), (0.14, 0.10), (0.48, 0.50), (0.82, 0.78), (1.0, 0.80)]) * math.pi * 0.5,
                apoyo=tramos(t, [(0.0, 0.0), (0.48, 0.6), (0.66, 1.6), (0.82, 2.6), (1.0, 2.8)]),
                bate=tramos(t, [(0.0, 0.55), (0.14, 0.20), (0.30, -0.35), (0.48, -0.70), (1.0, -0.85)]),
                boca=0.45 * (1.0 - cae), orejas=-0.9 * cae, cabeza=-0.35 * cae, patas=-0.5 * cae)


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo.
ANIMS = {
    'idle': (8, 9.0, True, 8, anim_idle),
    'walk': (8, 14.0, True, 8, anim_walk),
    'embestida': (8, 12.0, False, 8, anim_embestida),
    'chillido': (8, 8.0, False, 8, anim_chillido),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 11.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(anim_idle(0.0)), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'chillon_6a7480_1.40', VISTAS + 'chillon_vs_viejo.png', 4))
    else:
        hornear('chillon_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
