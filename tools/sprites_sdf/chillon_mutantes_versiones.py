# ============================================================
#  chillon_mutantes_versiones.py -- LOS MUTANTES DEL CHILLON, propuestas en QUIETO (18/11/2026, memoria chillon-mutante).
#  Una linea: Chillon -> APAGALUCES (se traga la luz; su chillido en circulo te deja A oscuras) -> PIÑA NEGRA (un racimo
#  de unos veinte que va soltando crias; lenta y tanque). El jefe: "muestramelas todas".
#    APAGALUCES  A hollin         el mismo murcielago, negro mate sin brillo; solo se le ven las orejas y unos ojos ciegos
#                B orejas radar   orejas ENORMES en embudo y alas con el borde deshilachado (tela quemada)
#                C boca embudo    la cabeza casi toda BOCA abierta en embudo (de ahi sale el chillido en circulo)
#    PIÑA NEGRA  A racimo         unos veinte pequeños apretados en forma de piña; los de arriba baten y sostienen el resto
#                B ovillo         una masa de alas plegadas como las escamas de una piña, con cabecitas asomando
#                C madre          un apagaluces GRANDE con crias colgando de la panza y el lomo
#  Los dos mutantes, algo mayores que el normal (tienen mucha mas vida). Nada en el suelo salvo su sombra.
#  Uso: python tools/sprites_sdf/chillon_mutantes_versiones.py
#    -> tools/salida/sdf/chillon_mutantes_versiones.png (y al escritorio, ataques_mapa/enemigos/prueba_3d/mutantes)
# ============================================================
import sys, os, math, random
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import sdf_comun
import chillon_sdf as base

V = np.array
Z = base.VUELO_Z

MAT = dict(base.MAT)
MAT.update({
    # HOLLIN: negro mate que se traga la luz (sin claros: el tono de luz casi igual al de sombra). La piel desnuda, un gris
    # ceniza apenas mas claro: es lo unico que dibuja la cara.
    'hollin':   [(0.09, 0.09, 0.12), (0.15, 0.15, 0.19), (0.21, 0.21, 0.26)],
    'memb_h':   [(0.15, 0.13, 0.17), (0.22, 0.20, 0.25), (0.29, 0.27, 0.32)],
    'dedo_h':   [(0.05, 0.05, 0.06), (0.08, 0.08, 0.10), (0.12, 0.12, 0.14)],
    'oreja_h':  [(0.36, 0.33, 0.37), (0.50, 0.46, 0.50), (0.60, 0.56, 0.60)],
    'oreja_hi': [(0.20, 0.18, 0.21), (0.28, 0.26, 0.29), (0.35, 0.33, 0.36)],
    'nariz_h':  [(0.44, 0.41, 0.45), (0.58, 0.55, 0.58), (0.68, 0.65, 0.68)],
    # los ojos CIEGOS: blanco lechoso (lo unico claro de verdad)
    'ojo_ciego': [(0.62, 0.64, 0.66), (0.80, 0.82, 0.84), (0.92, 0.93, 0.94)],
    # la boca del embudo por dentro: rojo muy oscuro, casi negro
    'garganta': [(0.10, 0.02, 0.03), (0.16, 0.04, 0.05), (0.22, 0.06, 0.07)],
    # el ala abierta de los que baten en el racimo: algo mas oscura (de plano a la luz salia casi blanca)
    'memb_o':   [(0.10, 0.09, 0.12), (0.15, 0.14, 0.18), (0.21, 0.19, 0.24)],
    'labio':    [(0.40, 0.32, 0.35), (0.54, 0.44, 0.47), (0.64, 0.54, 0.56)],
})
NEGRO = {'pelo': 'hollin', 'membrana': 'memb_h', 'dedo': 'dedo_h', 'oreja': 'oreja_h', 'oreja_in': 'oreja_hi',
         'nariz': 'nariz_h'}


def modelo(escala=1.5, lado=110, k_pies=0.56):
    return Modelo(escala, (lado, lado), (lado // 2, int(lado * k_pies)), MAT, (0.02, 0.02, 0.03),
                  suaves=('cuerpo', 'cabeza'), brillan=('ojo_ciego',), corta_suelo=True)


# ------------------------------------------------------------
#  EL MURCIELAGO (el de chillon_sdf.escena, con perillas)
# ------------------------------------------------------------
def _elip_girado(add, c, ejes, r, mat, grupo, hueso):
    """Las orejas (base._elip_girado) con sd_elipsoide_girado: la misma cuenta, pero la grafica la lee."""
    E = V(ejes, dtype=float); c = V(c, dtype=float); r = V(r, dtype=float)
    add(lambda P: sd_elipsoide_girado(P, c, E.T, r), mat, 0, grupo, hueso)


def murcielago(e, p, mats=None, k_oreja=1.0, embudo=0.0, desfleco=0.0, ojos=False, boca_embudo=False, sombra=True):
    """El cuerpo del chillon con lo que cambia en cada version. 'mats' cambia los materiales (el negro); 'k_oreja' agranda
    las orejas y 'embudo' las abre hacia delante como una bocina; 'desfleco' rompe el borde del ala en jirones; 'ojos' le
    pone los ojos ciegos; 'boca_embudo' cambia la boca por un embudo enorme."""
    m = lambda k: (mats or {}).get(k, k)
    X = e.X
    add = e.add
    _elip, _cono, _lamina = base._elip, base._cono, base._lamina
    _elip(add, (0.0, 1.6, Z - 1.5), (3.0, 3.2, 2.8), m('pelo'), 0.9)
    _elip(add, (0.0, -1.4, Z - 1.8), (2.2, 2.9, 2.1), m('pelo'), 0.9)
    _elip(add, (0.0, -3.6, Z - 2.0), (1.3, 1.6, 1.2), m('pelo'), 0.6)
    _elip(add, (0.0, 5.4, Z - 2.1), (2.4, 2.3, 2.2), m('pelo'), 0.6, 'cabeza', 'cabeza')
    if boca_embudo:
        # LA BOCA EN EMBUDO: la cabeza se abre por delante en una bocina; labio claro por fuera, garganta casi negra.
        c0 = V((0.0, 6.2, Z - 2.4))
        c1 = V((0.0, 9.2, Z - 2.6))
        _cono(add, c0, c1, 1.6, 3.0, m('pelo'), 0.4, 'cabeza', 'cabeza')
        _cono(add, c0 + V((0, 1.2, 0)), c1 + V((0, 0.35, 0)), 1.0, 2.45, 'garganta', 0, 'boca', 'cabeza')
        for k in range(10):
            a = k / 10 * 2 * math.pi
            _elip(add, c1 + V((2.75 * math.cos(a), 0.05, 2.75 * math.sin(a))), (0.55, 0.45, 0.55), 'labio', 0, 'labio',
                  'cabeza')
        for k in range(8):   # dientecillos por dentro del labio
            a = (k + 0.5) / 8 * 2 * math.pi
            _cono(add, c1 + V((2.3 * math.cos(a), -0.1, 2.3 * math.sin(a))),
                  c1 + V((1.5 * math.cos(a), -0.5, 1.5 * math.sin(a))), 0.28, 0.06, 'diente', 0, 'diente', 'cabeza')
    else:
        _elip(add, (0.0, 6.9, Z - 2.9), (1.25, 1.4, 1.1), m('pelo'), 0.6, 'cabeza', 'cabeza')
        _elip(add, (0.0, 7.95, Z - 2.2), (0.95, 0.40, 1.45), m('nariz'), 0, 'nariz', 'cabeza')
        b = p['boca']
        _elip(add, (0.0, 7.5, Z - 3.75 - 0.35 * b), (1.0, 0.85, 0.45 + 0.75 * b), 'boca', 0, 'boca', 'cabeza')
        for sx in (-1, 1):
            _cono(add, (0.42 * sx, 8.05, Z - 3.45), (0.42 * sx, 8.1, Z - 4.1 - 0.15 * b), 0.36, 0.30, 'diente', 0,
                  'diente', 'cabeza')
    if ojos:
        ko = 1.0 if ojos is True else float(ojos)   # (la evolucion: le van saliendo)
        for sx in (-1, 1):
            _elip(add, (1.05 * sx, 7.2, Z - 1.7), (0.62 * ko, 0.42 * ko, 0.52 * ko), 'ojo_ciego', 0, 'ojo', 'cabeza')
    # LAS OREJAS
    for s in (-1, 1):
        bse = V((1.25 * s, 5.0, Z - 0.6))
        # 'abre' (el Chillido de oscuridad, en circulo): las orejas se abren a los LADOS en vez de apuntar delante
        ab = p.get('abre', 0.0)
        d = V((0.30 * s + 0.35 * embudo * s + 1.1 * ab * s, -0.18 + 0.30 * embudo, 0.94 - 0.35 * ab))
        a = p['orejas'] * 0.55
        d = V((d[0], d[1] * math.cos(a) + d[2] * math.sin(a), -d[1] * math.sin(a) + d[2] * math.cos(a)))
        d /= np.linalg.norm(d)
        frente = np.cross(d, V((1.0 * s, 0.0, 0.0))) * s
        frente /= np.linalg.norm(frente)
        if frente[1] < 0: frente = -frente
        ancho = np.cross(frente, d)
        c = bse + d * 3.0 * k_oreja
        # el EMBUDO: la oreja mas ancha y ahuecada (la de dentro se mete mas)
        ka = 1.0 + 0.45 * embudo
        _elip_girado(add, c, (ancho, frente, d), (1.55 * k_oreja * ka, 0.6, 3.4 * k_oreja), m('oreja'), 'oreja', 'cabeza')
        _elip_girado(add, c + frente * (0.38 + 0.25 * embudo) + d * 0.2, (ancho, frente, d),
                     (1.0 * k_oreja * ka, 0.32, 2.7 * k_oreja), m('oreja_in'), 'oreja', 'cabeza')
    # LAS PATAS Y LA COLA
    tob = {}
    for s in (-1, 1):
        cad, t = base._pata(p, s)
        _cono(add, cad, t, 0.62, 0.45, m('pelo'), 0, 'pata', 'cuerpo')
        _elip(add, t + V((0.1 * s, -0.5, -0.2)), (0.55, 0.85, 0.45), 'garra', 0, 'pata', 'cuerpo')
        tob[s] = aplica(X['cuerpo'], t)
    cola = aplica(X['cuerpo'], V((0.0, -6.8, Z - 3.0)))
    grupa = aplica(X['cuerpo'], V((0.0, -3.2, Z - 2.1)))
    for s in (-1, 1):
        _lamina(add, tob[s], cola, grupa, mat=m('membrana'), grupo='cola')
    _cono(add, aplica(X['cuerpo'], V((0.0, -4.4, Z - 2.3))), cola, 0.35, 0.25, m('dedo'), 0, 'cola', 'mundo')
    # LAS ALAS
    raiz = X['raiz']
    rec = min(1.0, p['recoge'] + 0.55 * p['cae'])
    for s in (-1, 1):
        q = {}
        for k in base.ALA_ABIERTA:
            (s0, a0), (s1, a1) = base.ALA_ABIERTA[k], base.ALA_RECOGIDA[k]
            q[k] = aplica(raiz, base._punto_ala(p, s, s0 + (s1 - s0) * rec, a0 + (a1 - a0) * rec))
        hom = aplica(raiz, base.HOMBRO * V((s, 1, 1)))
        flanco = aplica(X['cuerpo'], V((1.6 * s, -2.4, Z - 1.4)))

        def feston(a, b, k=0.20):
            mm = 0.5 * (a + b)
            return mm + (q['muneca'] - mm) * k
        dedos = ['d2', 'd3', 'd4', 'd5']
        for i in range(3):
            a, bb = q[dedos[i]], q[dedos[i + 1]]
            if desfleco > 0.0:
                # EL BORDE EN JIRONES: tres picos por tramo, unos mas metidos que otros (tela quemada)
                pts = [a]
                for j, kk in enumerate((0.42, 0.18, 0.50)):
                    u = (j + 1) / 4.0
                    mm = a + (bb - a) * u
                    pts.append(mm + (q['muneca'] - mm) * kk * desfleco)
                pts.append(bb)
                for j in range(len(pts) - 1):
                    _lamina(add, q['muneca'], pts[j], pts[j + 1], mat=m('membrana'))
            else:
                mm = feston(a, bb, 0.12 if i == 0 else 0.22)
                _lamina(add, q['muneca'], a, mm, mat=m('membrana'))
                _lamina(add, q['muneca'], mm, bb, mat=m('membrana'))
        m5 = feston(q['d5'], tob[s], 0.0)
        m5 = m5 + (q['codo'] - m5) * (0.18 + 0.25 * desfleco)
        _lamina(add, q['codo'], q['muneca'], q['d5'], mat=m('membrana'))
        _lamina(add, q['codo'], q['d5'], m5, mat=m('membrana'))
        _lamina(add, q['codo'], m5, tob[s], mat=m('membrana'))
        _lamina(add, q['codo'], tob[s], flanco, mat=m('membrana'))
        _lamina(add, hom, q['codo'], flanco, mat=m('membrana'))
        _lamina(add, hom, q['codo'], q['muneca'], mat=m('membrana'), grosor=0.2)
        _cono(add, hom, q['codo'], 0.75, 0.55, m('dedo'), 0, 'ala', 'mundo')
        _cono(add, q['codo'], q['muneca'], 0.55, 0.42, m('dedo'), 0, 'ala', 'mundo')
        for dd in dedos:
            _cono(add, q['muneca'], q[dd], 0.42, 0.26, m('dedo'), 0, 'ala', 'mundo')
        _cono(add, q['muneca'], q['pulgar'], 0.42, 0.30, 'garra', 0, 'ala', 'mundo')
    if sombra:
        e.sombra(0.0, 0.5, 5.4, 3.0)


# ------------------------------------------------------------
#  LOS PEQUEÑOS (las crias de la Piña): una bolita de pelo con sus orejas, las alas plegadas encima o abiertas batiendo
# ------------------------------------------------------------
def pequeno(add, c, s, mira, arriba, abierto=False, grupo='cria', mats=NEGRO):
    """Un apagaluces pequeño en 'c' (mundo), de escala 's', con la cabeza hacia 'mira' y el lomo hacia 'arriba'."""
    m = lambda k: mats.get(k, k)
    c = V(c, dtype=float)
    f = V(mira, dtype=float); f /= np.linalg.norm(f)
    u = V(arriba, dtype=float); u = u - f * np.dot(u, f); u /= np.linalg.norm(u)
    l = np.cross(f, u)
    P = lambda x, y, z: c + l * x * s + f * y * s + u * z * s
    base._elip(add, P(0, 0, 0), (1.2 * s, 1.3 * s, 1.2 * s), m('pelo'), 0.4, grupo, 'mundo')
    base._elip(add, P(0, 1.3, 0.1), (0.85 * s, 0.8 * s, 0.8 * s), m('pelo'), 0.3, grupo, 'mundo')
    base._elip(add, P(0, 2.0, 0.15), (0.32 * s, 0.18 * s, 0.45 * s), m('nariz'), 0, grupo, 'mundo')
    for sx in (-1, 1):   # los ojos ciegos: cada cria, una cara
        base._elip(add, P(0.42 * sx, 1.85, 0.45), (0.30 * s, 0.22 * s, 0.26 * s), 'ojo_ciego', 0, grupo, 'mundo')
    for sx in (-1, 1):
        base._cono(add, P(0.45 * sx, 1.3, 0.6), P(0.75 * sx, 1.1, 2.0), 0.42 * s, 0.12 * s, m('oreja'), 0, grupo, 'mundo')
        if abierto:
            # el ala abierta, batiendo: la del apagaluces en pequeño (brazo, tres dedos y la membrana en festones)
            k = float(abierto) if not isinstance(abierto, bool) else 1.0
            h = P(0.9 * sx, 0.3, 0.4)
            mu = P(3.0 * sx * k, 0.6, 1.4)
            dd = [P(5.6 * sx * k, 0.2, 1.8), P(5.0 * sx * k, -1.8, 1.0), P(3.4 * sx * k, -2.8, 0.4)]
            cad = P(0.8 * sx, -1.2, 0.1)
            base._lamina(add, h, mu, cad, mat=m('membrana'), grosor=0.18 * s, grupo=grupo)
            ant = cad
            for q in reversed(dd):
                base._lamina(add, mu, q, ant, mat=m('membrana'), grosor=0.18 * s, grupo=grupo)
                ant = q
            base._cono(add, h, mu, 0.26 * s, 0.18 * s, m('dedo'), 0, grupo, 'mundo')
            for q in dd:
                base._cono(add, mu, q, 0.16 * s, 0.08 * s, m('dedo'), 0, grupo, 'mundo')
        else:
            # plegada sobre el costado, como un capote
            base._elip(add, P(0.95 * sx, -0.2, 0.2), (0.45 * s, 1.35 * s, 1.0 * s), m('membrana'), 0, grupo, 'mundo')


# ------------------------------------------------------------
#  LAS VERSIONES
# ------------------------------------------------------------
def _escena():
    return Escena(base.huesos(base.anim_idle(0.0)))


def apagaluces_a():
    e = _escena()
    murcielago(e, base.anim_idle(0.0), NEGRO, ojos=True)
    return e.L


def apagaluces_b():
    e = _escena()
    murcielago(e, base.anim_idle(0.0), NEGRO, k_oreja=1.45, embudo=1.0, desfleco=1.0)
    return e.L


def apagaluces_c():
    e = _escena()
    murcielago(e, base.anim_idle(0.0), NEGRO, k_oreja=0.85, boca_embudo=True)
    return e.L


def pina_a():
    """EL RACIMO: unos veinte pequeños apretados en forma de piña (ancha arriba, en punta abajo), cabeza abajo como cuelgan
    los murcielagos; los cinco de la corona baten y sostienen el resto."""
    e = _escena()
    add = e.add
    rnd = random.Random(3)
    cz = Z + 1.0
    anillos = [(0.0, 4.6, 6), (-2.4, 4.0, 6), (-4.6, 2.9, 5), (-6.4, 1.5, 3), (-7.6, 0.0, 1)]
    for j, (dz, r, n) in enumerate(anillos):
        for i in range(n):
            a = (i + 0.5 * (j % 2)) / n * 2 * math.pi + rnd.uniform(-0.15, 0.15)
            c = V((r * math.cos(a), r * math.sin(a), cz + dz))
            fuera = V((math.cos(a), math.sin(a), 0.0)) if r > 0 else V((0.0, 1.0, 0.0))
            pequeno(add, c, 1.15, V((0.0, 0.0, -1.0)) + fuera * 0.35, fuera, grupo='r%d_%d' % (j, i))
    for i in range(5):
        a = i / 5 * 2 * math.pi + 0.3
        c = V((3.0 * math.cos(a), 3.0 * math.sin(a), cz + 2.6))
        pequeno(add, c, 1.1, V((math.cos(a), math.sin(a), 0.4)), V((0.0, 0.0, 1.0)), abierto=True, grupo='corona%d' % i)
    e.sombra(0.0, 0.0, 6.5, 3.6)
    return e.L


SUAVES_EXTRA = set()


def escalar(fn, s):
    """La misma pieza 's' veces mas grande, con sus NUMEROS escalados (centros, radios, grosores): asi la distancia sale
    exacta (con un hueso que escala, el rayo daba pasos de mas y se saltaba las alas) y la grafica la sigue leyendo. None si
    la pieza no se deja leer."""
    r = fn(sdf_comun.SONDA)
    if not isinstance(r, tuple):
        return None
    tipo, a = r[0], r[1:]
    if tipo == 'esfera':
        c, rr = V(a[0], dtype=float) * s, a[1] * s
        return lambda P: sd_esfera(P, c, rr)
    if tipo == 'elipsoide':
        c, rad = V(a[0], dtype=float) * s, V(a[1], dtype=float) * s
        return lambda P: sd_elipsoide(P, c, rad)
    if tipo == 'cono':
        pa, pb, ra, rb = V(a[0], dtype=float) * s, V(a[1], dtype=float) * s, a[2] * s, a[3] * s
        return lambda P: sd_cono(P, pa, pb, ra, rb)
    if tipo == 'caja':
        c, ejes, medio, red = V(a[0], dtype=float) * s, a[1], V(a[2], dtype=float) * s, a[3] * s
        return lambda P: sd_caja(P, c, ejes, medio, red)
    if tipo == 'triangulo':
        pa, pb, pc, g = V(a[0], dtype=float) * s, V(a[1], dtype=float) * s, V(a[2], dtype=float) * s, a[3] * s
        return lambda P: sd_triangulo(P, pa, pb, pc, g)
    if tipo == 'casquete' and a[4] <= -1e5:   # el elipsoide girado (las orejas)
        c, M, rad = V(a[0], dtype=float) * s, a[1], V(a[3], dtype=float) * s
        return lambda P: sd_elipsoide_girado(P, c, M, rad)
    return None


SUAVES_EXTRA = set()


def instancia(e, L_src, s, giro, t, suf, T=None):
    """Copia un bicho ENTERO (sus piezas con sus huesos) a escala 's', girado 'giro' sobre Z y puesto en 't': los apagaluces
    que baten en el racimo llevan asi las alas de verdad (las hechas a mano salian como petalos). La escala va en los numeros
    de cada pieza (escalar) y el hueso solo gira y mueve: p_mundo = R (M p + tx) s + t = (R M)(s p) + (s R tx + t)."""
    R = rz(giro)
    for fn, m, g, k, Xh, nh in L_src:
        f2 = escalar(fn, s)
        if f2 is None:
            raise ValueError('instancia: una pieza que no se deja escalar (%s, %s)' % (g, m))
        gn = g + suf
        if g in ('cuerpo', 'cabeza'):
            SUAVES_EXTRA.add(gn)
        Xn = (R @ Xh[0], s * (R @ Xh[1]) + V(t, dtype=float))
        e.L.append((f2, m, gn, k * s, comp(T, Xn) if T is not None else Xn, nh + suf))


def _apagaluces_piezas(t_anim=0.0):
    pose = base.anim_idle(t_anim)
    e = Escena(base.huesos(pose))
    murcielago(e, pose, NEGRO, ojos=True, sombra=False)
    return e.L


def pina_alas(s, anillos, alto, baten, k_bate=0.85, sem=3):
    """(18/11, 3a vuelta) "necesito tambien alas fuera, si no no pueden volar": el racimo de la Piña 2 y, pegados por fuera,
    apagaluces ENTEROS batiendo (cabeza hacia fuera, alas abiertas), los que lo llevan en el aire. 'baten' = [(anillo,
    angulo en grados, momento del aleteo)]."""
    e = pina_grande(s, anillos, alto, corona=0, sem=sem, devolver_escena=True)
    for j, (anillo, ang, t_a) in enumerate(baten):
        dz, r, _n = anillos[anillo]
        a = math.radians(ang)
        donde = V((r * math.cos(a), r * math.sin(a), alto + dz)) + V((math.cos(a), math.sin(a), 0.0)) * 4.5 + V((0.0, 0.0, 1.5))
        # su cuerpo (local: el centro del pecho, a VUELO_Z) va a 'donde'; mira hacia fuera (+Y local -> fuera)
        giro = a - math.pi / 2
        pecho = V((0.0, 0.0, Z - 1.5)) * k_bate
        t = donde - rz(giro) @ pecho
        instancia(e, _apagaluces_piezas(t_a), k_bate, giro, t, '_b%d' % j)
    return e.L


def pina_grande(s, anillos, alto, corona=8, sem=3, abren=(), abren_anillos=(), devolver_escena=False):
    """(18/11, 2a vuelta) EL RACIMO GRANDE: "piensa que son muchos murcielagos de estos juntos". Apagaluces como el elegido
    (el hollin, con sus ojos ciegos), cabeza abajo como cuelgan los murcielagos, apretados en forma de piña: ancha arriba,
    en punta abajo. La corona, con las alas abiertas, sostiene el resto. 'alto' = a que altura va la corona."""
    e = _escena()
    add = e.add
    rnd = random.Random(sem)
    # EL NUCLEO: los de dentro del racimo, que no se ven sueltos; tapa los huecos (sin el, se veia un barril hueco)
    fondo = anillos[-1][0]
    r_max = max(r for _dz, r, _n in anillos)
    base._elip(add, (0.0, 0.0, alto + fondo * 0.45), (r_max * 0.85, r_max * 0.85, -fondo * 0.55 + 1.5), 'hollin', 0.5,
               'nucleo', 'mundo')
    for j, (dz, r, n) in enumerate(anillos):
        for i in range(n):
            a = (i + 0.5 * (j % 2)) / n * 2 * math.pi + rnd.uniform(-0.12, 0.12)
            c = V((r * math.cos(a), r * math.sin(a), alto + dz + rnd.uniform(-0.6, 0.6)))
            fuera = V((math.cos(a), math.sin(a), 0.0)) if r > 0 else V((0.0, 1.0, 0.0))
            if (j, i) in abren or (j in abren_anillos):
                # ESTE BATE: la cabeza hacia fuera y las alas abiertas por fuera del racimo (los que lo llevan volando)
                # DE LADO (mira a lo largo del anillo): asi un ala sale hacia FUERA del racimo y la otra queda dentro
                tang = V((-math.sin(a), math.cos(a), 0.0))
                pequeno(add, c + fuera * 0.5 * s, s, tang + V((0.0, 0.0, 0.25)), V((0.0, 0.0, 1.0)), abierto=1.0,
                        grupo='r%d_%d' % (j, i), mats=dict(NEGRO, membrana='memb_o'))
            else:
                pequeno(add, c, s * rnd.uniform(0.9, 1.08), V((0.0, 0.0, -1.0)) + fuera * 0.45, fuera,
                        grupo='r%d_%d' % (j, i))
    for i in range(corona):
        a = i / corona * 2 * math.pi + 0.3
        c = V((anillos[1][1] * 0.75 * math.cos(a), anillos[1][1] * 0.75 * math.sin(a), alto + 1.0))
        pequeno(add, c, s * 1.1, V((math.cos(a), math.sin(a), 0.3)), V((0.0, 0.0, 1.0)), abierto=True, grupo='corona%d' % i)
    e.sombra(0.0, 0.0, anillos[0][1] * 1.1, anillos[0][1] * 0.6)
    return e if devolver_escena else e.L


def pina_b():
    """EL OVILLO: un cuerpo como una piña cubierto de alas plegadas a modo de escamas (laminas solapadas, en espiral) y,
    entre ellas, cabecitas asomando con sus orejas."""
    e = _escena()
    add = e.add
    cz = Z
    base._elip(add, (0.0, 0.0, cz), (4.4, 4.4, 6.2), 'hollin', 0.5, 'nucleo', 'mundo')
    n_f, n_v = 6, 5
    for j in range(n_v):
        t = (j + 0.5) / n_v
        zz = cz + 5.2 - 10.4 * t
        r = 4.4 * math.sqrt(max(0.05, 1.0 - ((zz - cz) / 6.2) ** 2)) + 0.4
        for i in range(n_f):
            a = (i + 0.5 * (j % 2)) / n_f * 2 * math.pi
            fuera = V((math.cos(a), math.sin(a), 0.0))
            tang = V((-math.sin(a), math.cos(a), 0.0))
            p0 = V((0.0, 0.0, zz + 1.6)) + fuera * (r - 0.6)
            pa = p0 + fuera * 1.0 + tang * 1.6 + V((0, 0, -2.6))
            pb = p0 + fuera * 1.0 - tang * 1.6 + V((0, 0, -2.6))
            base._lamina(add, p0, pa, pb, mat='memb_h', grosor=0.25, grupo='escama%d_%d' % (j, i))
            base._cono(add, p0, p0 + fuera * 1.0 + V((0, 0, -2.8)), 0.25, 0.12, 'dedo_h', 0, 'escama%d_%d' % (j, i),
                       'mundo')
    rnd = random.Random(7)
    for k in range(9):
        a = rnd.uniform(0, 2 * math.pi)
        zz = cz + rnd.uniform(-3.5, 3.8)
        r = 4.4 * math.sqrt(max(0.05, 1.0 - ((zz - cz) / 6.2) ** 2)) + 1.0
        fuera = V((math.cos(a), math.sin(a), 0.0))
        c = V((0.0, 0.0, zz)) + fuera * r
        # solo la cabecita: el cuerpo queda dentro del ovillo
        P = lambda x, y, zq: c + fuera * y + V((-math.sin(a), math.cos(a), 0.0)) * x + V((0, 0, zq))
        base._elip(add, P(0, 0, 0), (0.8, 0.8, 0.8), 'hollin', 0.3, 'cab%d' % k, 'mundo')
        base._elip(add, P(0, 0.75, 0.1), (0.3, 0.18, 0.42), 'nariz_h', 0, 'cab%d' % k, 'mundo')
        for sx in (-1, 1):
            base._cono(add, P(0.4 * sx, 0.1, 0.5), P(0.7 * sx, -0.1, 1.8), 0.38, 0.1, 'oreja_h', 0, 'cab%d' % k, 'mundo')
    # dos alas grandes abiertas arriba, que lo mantienen en el aire
    for s in (-1, 1):
        h = V((2.6 * s, 0.0, cz + 4.4))
        pnt = V((11.0 * s, -1.0, cz + 6.4))
        atr = V((7.0 * s, -4.5, cz + 2.4))
        base._lamina(add, h, pnt, atr, mat='memb_h', grosor=0.22, grupo='ala')
        base._lamina(add, h, atr, V((2.6 * s, -3.0, cz + 2.2)), mat='memb_h', grosor=0.22, grupo='ala')
        base._cono(add, h, pnt, 0.6, 0.3, 'dedo_h', 0, 'ala', 'mundo')
        base._cono(add, h + (pnt - h) * 0.55, atr, 0.4, 0.22, 'dedo_h', 0, 'ala', 'mundo')
    e.sombra(0.0, 0.0, 6.5, 3.6)
    return e.L


def pina_c():
    """LA MADRE: un apagaluces grande (el hollin, con ojos ciegos) con las crias colgando de la panza y agarradas al lomo."""
    e = _escena()
    murcielago(e, base.anim_idle(0.0), NEGRO, ojos=True, sombra=False)
    add = e.add
    X = e.X
    for k, (x, y) in enumerate([(-1.6, 2.2), (1.5, 1.0), (-0.6, -0.6), (1.2, -2.2), (-1.4, -2.6)]):
        c = aplica(X['cuerpo'], V((x * 1.2, y, Z - 5.0)))
        pequeno(add, c, 0.95, V((0.0, 0.0, -1.0)), V((x, 0.3, 0.0)) if x else V((1, 0, 0)), grupo='panza%d' % k)
    for k, (x, y) in enumerate([(-1.0, 1.0), (1.1, -1.4), (0.0, -3.4)]):
        c = aplica(X['cuerpo'], V((x * 1.4, y, Z + 1.6)))
        pequeno(add, c, 0.9, V((0.0, 1.0, 0.2)), V((0.0, 0.0, 1.0)), grupo='lomo%d' % k)
    e.sombra(0.0, 0.5, 6.5, 3.6)
    return e.L


PINA_1 = [(2.0, 2.4, 3), (-2.6, 6.6, 6), (-7.6, 7.6, 7), (-12.6, 6.6, 6), (-17.2, 4.4, 4), (-20.8, 1.8, 2),
          (-23.6, 0.0, 1)]
PINA_2 = [(2.4, 2.8, 3), (-3.2, 7.6, 6), (-9.2, 8.2, 6), (-15.0, 6.4, 5), (-20.2, 3.2, 3), (-24.4, 0.0, 1)]

if __name__ == '__main__':
    getattr(sdf_comun, '_prioridad_baja', lambda: None)()
    os.environ['SDF_SOMBRA'] = '1'   # en las laminas, la sombra para leer la altura
    W = H = 110
    if sys.argv[1:] == ['pina']:
        # 2a vuelta de la Piña: junto al Apagaluces elegido y al normal, a la MISMA escala, para ver lo grande que es
        W = H = 190
        filas = [
            ('NORMAL (hoy)', None, None),
            ('APAGALUCES (elegido)', apagaluces_a(), modelo(1.75, 190, 0.78)),
            ('PINA 2 alas A: seis arriba', pina_alas(3.4, PINA_2, 30.0,
                [(1, 0, 0.0), (1, 60, 0.3), (1, 120, 0.6), (1, 180, 0.15), (1, 240, 0.45), (1, 300, 0.75)]), None),
            ('PINA 2 alas B: repartidos', pina_alas(3.4, PINA_2, 30.0,
                [(1, 20, 0.0), (1, 200, 0.5), (2, 100, 0.25), (2, 290, 0.7), (3, 40, 0.4), (3, 220, 0.9)]), None),
        ]
    else:
      filas = [
        ('NORMAL (hoy)', None, None),
        ('APAGALUCES A hollin', apagaluces_a(), modelo(1.75)),
        ('APAGALUCES B orejas radar', apagaluces_b(), modelo(1.75)),
        ('APAGALUCES C boca embudo', apagaluces_c(), modelo(1.75)),
        ('PIÑA NEGRA A racimo', pina_a(), modelo(1.9)),
        ('PIÑA NEGRA B ovillo', pina_b(), modelo(1.9)),
        ('PIÑA NEGRA C madre', pina_c(), modelo(2.1)),
      ]
    ESC = 3 if W > 110 else 4
    MARGEN = 230
    tiras = []
    for nombre, L, mo in filas:
        fotos = []
        for d in range(5):
            if L is None:
                im = render(base.MODELO, base.escena(base.anim_idle(0.0)), d)
                lien = Image.new('RGBA', (W, H), (0, 0, 0, 0))
                lien.paste(im, ((W - im.size[0]) // 2, int(H * (0.78 if W > 110 else 0.56)) - base.MODELO.OY), im)
                im = lien
            else:
                if mo is None:
                    mo = modelo(1.75, 190, 0.78)
                    mo.suaves = tuple(mo.suaves) + tuple(sorted(SUAVES_EXTRA))
                im = render(mo, L, d)
            fotos.append(im)
        cajas = [f.getbbox() for f in fotos]
        y0 = max(0, min(c[1] for c in cajas) - 3)
        y1 = min(H, max(c[3] for c in cajas) + 3)
        tiras.append((nombre, fotos, y0, y1))
        print(nombre, flush=True)
    x0 = max(0, min(f.getbbox()[0] for t in tiras for f in t[1]) - 3)
    x1 = min(W, max(f.getbbox()[2] for t in tiras for f in t[1]) + 3)
    ancho = x1 - x0
    alto_total = sum((t[3] - t[2]) * ESC for t in tiras)
    # FONDO: el suelo de la mazmorra (gris azulado), que es donde tiene que leerse algo tan negro
    hoja = Image.new('RGB', (MARGEN + ancho * 5 * ESC, alto_total), (52, 58, 70))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, fotos, y0, y1 in tiras:
        dib.text((10, y + (y1 - y0) * ESC // 2), nombre, fill=(235, 235, 235))
        for d, im in enumerate(fotos):
            c = im.crop((x0, y0, x1, y1)).resize((ancho * ESC, (y1 - y0) * ESC), Image.NEAREST)
            hoja.paste(c, (MARGEN + d * ancho * ESC, y), c)
        y += (y1 - y0) * ESC
        dib.line((0, y - 1, hoja.size[0], y - 1), fill=(70, 74, 86))
    os.makedirs('tools/salida/sdf', exist_ok=True)
    nom = 'chillon_pina_versiones.png' if W > 110 else 'chillon_mutantes_versiones.png'
    hoja.save('tools/salida/sdf/' + nom)
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(esc, exist_ok=True)
    hoja.save(os.path.join(esc, nom))
    print('ok', hoja.size)
