# ============================================================
#  miconido_sdf.py -- el MICONIDO en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (miconido_sprites.gd): UNA SETA CON CUERPO DE HOMBRE -- un torso gordo y PALIDO, un SOMBRERO oscuro y muy ancho cuya
#  ala cae por los lados, dos brazos finos y unas patas cortas. NO TIENE CARA: se sabe hacia donde va porque el SOMBRERO
#  VA LADEADO hacia donde mira y las LAMINAS (rayas oscuras bajo el ala) solo se ven por delante. Lienzo y origen de su
#  horneado (2,00 -> 90 x 106, el origen bajo).
#  HUESOS: raiz (se mece adelante/atras y de lado sobre los pies), sombrero (va con RETRASO de lado, se HINCHA para la
#  bocanada y se HUNDE sobre el cuerpo), los brazos y las patas. Morir (DESHINCHARSE) cambia la forma: el cuerpo se
#  chafa y se desparrama y el sombrero cae encima (aplastar con el hueso agujerea el raymarch).
#  EL LATIGO DE MICELIO lo lanza el brazo que da a camara (escena_dir): el mismo que elige MiconidoSprites.mano_del_latigo,
#  de donde SimaAire saca el cordon.
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/miconido_sdf.py [anim ...]  -> assets/sprites/enemigos/miconido_sdf/<anim>.png
#       python tools/sprites_sdf/miconido_sdf.py vistas     -> tools/salida/sdf/miconido_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/miconido_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# El sombrero, del color de su ficha (806e40, ocre); el cuerpo palido; las laminas oscuras; las esporas, polvo claro.
MAT = {
    'sombrero': [(0.32, 0.27, 0.16), (0.50, 0.43, 0.25), (0.64, 0.57, 0.36)],
    'carne':    [(0.66, 0.64, 0.58), (0.82, 0.80, 0.74), (0.92, 0.90, 0.85)],
    'lamina':   [(0.24, 0.20, 0.14), (0.34, 0.29, 0.20), (0.42, 0.36, 0.26)],
    'mota':     [(0.70, 0.64, 0.46), (0.80, 0.74, 0.55), (0.88, 0.82, 0.64)],
    'espora':   [(0.80, 0.82, 0.56), (0.90, 0.92, 0.66), (0.97, 0.98, 0.78)],
}
LIENZO = (90, 106)
PIES = (45.0, 106 * 1.55 / 2.75)
MODELO = Modelo(2.0, LIENZO, PIES, MAT, (0.12, 0.10, 0.07), suaves=('cuerpo',), brillan=(), corta_suelo=True)

LADEO = 0.22     # cuanto cae el sombrero hacia delante (su "cara")
# Las medidas del viejo pasadas a este dibujo: aquel media 23 hasta lo alto del cuerpo, este 16,7.
K_VIEJO = 0.73
LUNGE_DIST = 4.0
BASE_SOMBRERO = V((0.0, 0.0, 16.5))


def POSE(**k):
    p = dict(avance=0.0, mece=0.0, balanceo=0.0, sacude=0.0, brazos=0.0, patas=0.0, hincha=0.0, hunde=0.0,
             derrumbe=0.0, puff=0.0, lanza=0.0)
    p.update(k)
    return p


def _lado_del_latigo(d):
    """El brazo que da a camara mirando hacia 'd' (+1 = su x local), con la cuenta de MiconidoSprites._lado_del_latigo."""
    v = DIR_VECS[d]
    ang = math.atan2(v[1], v[0]) - math.atan2(1, 0)
    return -1 if math.sin(ang) < -0.1 else 1


def huesos(p, lado_lanza=1):
    de = p['derrumbe']
    baja = 1.0 - 0.5 * de          # lo que se queda de alto el cuerpo al deshincharse
    raiz = (np.eye(3), V((0.0, p['avance'], 0.0)))
    # SE MECE sobre los pies: adelante (+) y atras, y de lado al andar; lo alto se mueve mas que los pies.
    raiz = comp(raiz, (rx(p['mece'] * 0.11), np.zeros(3)))
    raiz = comp(raiz, (ry(p['balanceo'] * 0.07), np.zeros(3)))
    X = {'raiz': raiz}
    # EL SOMBRERO: ladeado hacia delante (su cara), con retraso de lado (sacude), hinchado o hundido sobre el cuerpo.
    infla = 1.0 + p['hincha']
    h = p['hunde']
    chafa = 1.0 + 0.12 * h
    S = np.diag([infla * chafa * (1 + 0.12 * de), infla * chafa * (1 + 0.12 * de), infla * (1 - 0.26 * h) * (1 - 0.3 * de)])
    som = sobre(BASE_SOMBRERO, S)
    som = comp(sobre(BASE_SOMBRERO, rx(LADEO) @ ry(p['sacude'] * 0.14)), som)
    som = comp((np.eye(3), V((0.0, 0.0, -h * 2.6 * K_VIEJO - BASE_SOMBRERO[2] * (1 - baja)))), som)
    X['sombrero'] = comp(raiz, som)
    for s, ld in ((-1, 'd'), (1, 'i')):
        hombro = V((4.6 * s, 0.4, 12.5))
        a = -p['brazos'] * s * 0.4
        # EL LATIGO: el brazo de camara se echa atras y se LANZA al frente y arriba.
        giro = rx(a)
        if s == lado_lanza and p['lanza'] != 0.0:
            # Al frente Y HACIA FUERA: recto al frente, la mano quedaba escondida bajo el ala del sombrero.
            la = p['lanza']
            giro = rz(-s * 0.8 * max(la, 0.0)) @ rx(-la * 1.5 + p['brazos'] * 0.15)
        Xb = sobre(hombro, giro)
        Xb = comp((np.eye(3), V((0.0, 0.0, -hombro[2] * (1 - baja)))), Xb)
        X['brazo_' + ld] = comp(raiz, Xb)
        X['pierna_' + ld] = comp(raiz, sobre(V((2.2 * s, 0.0, 3.6)), rx(p['patas'] * s * 0.4)))
    return X


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def escena_dir(pose, d):
    return escena(pose, _lado_del_latigo(d))


def escena(pose, lado_lanza=1):
    e = Escena(huesos(pose, lado_lanza)); add = e.add
    de = pose['derrumbe']
    # El monton de carne asoma por debajo del ala (si no, muerto solo quedaba un disco de sombrero en el suelo).
    baja = 1.0 - 0.5 * de; derrama = 1.0 + 0.75 * de
    # EL CUERPO: un tronco de seta gordo y palido, ancho abajo, casi tan ancho como alto. Al morir se chafa y se
    # desparrama (mas bajo Y mas ancho: bajando sin ensanchar seria la misma seta mas pequeña, como si se alejara).
    _elip(add, (0, 0, 9.5 * baja), (5.0 * derrama, 4.6 * derrama, 7.2 * baja), 'carne')
    _elip(add, (0, 0, 4.6 * baja), (4.6 * derrama, 4.2 * derrama, 3.0 * max(baja, 0.55)), 'carne', 2.0)
    # EL SOMBRERO: ancho y oscuro, con el ala que CAE por los lados; por debajo, plano, con las LAMINAS (rayas oscuras
    # en abanico) que solo asoman por delante porque el sombrero va ladeado hacia alli.
    def sombrero(P):
        cap = sd_elipsoide(P, V((0, 0, 18.0)), V((8.2, 8.2, 4.4)))
        return np.maximum(cap, -(P[:, 2] - 16.4 + 0.04 * ((P[:, 0] ** 2 + P[:, 1] ** 2))))   # la panza curvada del ala
    add(sombrero, 'sombrero', 0, 'sombrero', 'sombrero')
    # las motas claras de encima
    for (x, y, r) in ((-4.0, 2.0, 1.3), (3.0, -3.5, 1.1), (1.5, 4.5, 0.9), (-2.0, -5.0, 1.0), (5.5, 1.0, 0.8)):
        x, y = x * 0.72, y * 0.72
        z = 18.0 + 4.4 * math.sqrt(max(0.0, 1 - (x * x + y * y) / 67.0)) - 0.25
        _elip(add, (x, y, z), (r, r, 0.35), 'mota', 0, 'mota', 'sombrero')
    for k in range(20):
        a = k / 20 * 2 * math.pi
        r0, r1 = 3.0, 7.6
        # LAS LAMINAS, y por delante CUELGAN del ala hasta los hombros (la mancha que dice hacia donde va).
        caen = 2.4 if math.sin(a) > 0.2 else 0.0
        _cono(add, (math.cos(a) * r0, math.sin(a) * r0, 16.6), (math.cos(a) * r1, math.sin(a) * r1, 16.4 - 0.04 * 58 + 0.5),
              0.34, 0.3, 'lamina', 0, 'lamina', 'sombrero')
        if caen > 0:
            _cono(add, (math.cos(a) * 5.2, math.sin(a) * 5.4, 16.2), (math.cos(a) * 5.0, math.sin(a) * 5.4 + 0.4, 16.0 - caen - 2.6),
                  0.55, 0.38, 'lamina', 0, 'lamina', 'sombrero')
    # LA BOCANADA: el polvo de esporas sale de debajo del ala en el reventon y se abre hacia fuera y arriba.
    pf = pose['puff']
    if 0.0 < pf < 1.0:
        for k in range(10):
            a = k / 10 * 2 * math.pi + 0.3
            rr = 7.0 + 6.0 * pf
            r = 2.8 * (1.0 - 0.6 * pf)
            _elip(add, (math.cos(a) * rr, math.sin(a) * rr * 0.9 + 1.0, 15.0 + 4.0 * pf + 1.2 * math.sin(3 * a)),
                  (r, r, r), 'espora', 0, 'espora', 'sombrero')
    # LOS BRAZOS: finos, colgando, con una mano de dedos-raicilla.
    for s, ld in ((-1, 'd'), (1, 'i')):
        h = 'brazo_' + ld
        _cono(add, (4.6 * s, 0.4, 12.5), (5.8 * s, 1.2, 7.2), 0.9, 0.7, 'carne', 0.6, 'brazo%d' % s, h)
        _cono(add, (5.8 * s, 1.2, 7.2), (6.0 * s, 1.8, 4.6), 0.7, 0.55, 'carne', 0.4, 'brazo%d' % s, h)
        for k in (-1, 0, 1):
            _cono(add, (6.0 * s, 1.8, 4.6), (6.0 * s + 0.4 * k, 2.3, 3.4), 0.35, 0.2, 'carne', 0, 'brazo%d' % s, h)
    # LAS PATAS: cortas y gruesas, de pie (al deshincharse se las traga el monton).
    for s, ld in ((-1, 'd'), (1, 'i')):
        h = 'pierna_' + ld
        _cono(add, (2.2 * s, 0.0, 3.6), (2.3 * s, 0.4, 0.8), 1.7, 1.9, 'carne', 0.6, 'pierna%d' % s, h)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # RESPIRA, y el sombrero TANTEA EL AIRE desacompasado del cuerpo. Lento (3 fps): se tiene que leer lento.
    return POSE(mece=0.35 * math.sin(2 * math.pi * t), sacude=0.45 * math.sin(2 * math.pi * t + 1.9),
                brazos=0.22 * math.sin(2 * math.pi * t + 0.7), hincha=0.035 * (1 - math.cos(2 * math.pi * t)))


def anim_walk(t):
    # ARRASTRA, sin bote: el sombrero va CON RETRASO respecto del cuerpo (el -1,1), los brazos a su aire.
    T = 2 * math.pi * t
    return POSE(mece=0.55 * math.sin(T * 2.0), balanceo=math.sin(T), sacude=1.0 * math.sin(T - 1.1),
                brazos=0.8 * math.sin(T - 0.5), patas=math.sin(T))


def anim_embestida(t):
    # Se echa atras y DEJA CAER EL SOMBRERO ENCIMA, como quien vuelca. Viaja poquisimo: a este se le ve venir.
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.35, -1.0), (0.55, 3.2), (0.75, 3.8), (1.0, 2.6)]) * (LUNGE_DIST / 3.8) * K_VIEJO,
                mece=tramos(t, [(0.0, 0.0), (0.35, -1.5), (0.55, 2.2), (0.75, 1.5), (1.0, 0.4)]),
                brazos=tramos(t, [(0.0, 0.0), (0.35, -0.9), (0.55, 1.2), (0.75, 0.6), (1.0, 0.1)]),
                hunde=tramos(t, [(0.0, 0.0), (0.35, -0.35), (0.55, 0.75), (0.75, 0.45), (1.0, 0.1)]))


def anim_esporas(t):
    # EL SOMBRERO SE HINCHA, aguanta y SUELTA DE GOLPE (el salto de tamaño entre dos marcos es el disparo).
    return POSE(hincha=tramos(t, [(0.0, 0.0), (0.143, 0.12), (0.286, 0.22), (0.429, 0.26), (0.571, -0.12), (0.714, -0.04),
                                  (0.857, 0.0), (1.0, 0.0)]),
                hunde=tramos(t, [(0.0, 0.0), (0.286, -0.20), (0.429, -0.25), (0.571, 0.55), (0.714, 0.30), (1.0, 0.05)]),
                puff=tramos(t, [(0.0, 0.0), (0.429, 0.0), (0.571, 0.35), (0.714, 0.68), (0.857, 0.88), (1.0, 1.0)]))


def anim_micelio(t):
    # Echa el brazo atras y lo LANZA al frente en el 0,286 (de su mano sale el latigo); se hunde y tira hacia atras.
    return POSE(lanza=tramos(t, [(0.0, 0.0), (0.143, -0.5), (0.286, 1.0), (0.571, 1.0), (0.857, 0.9), (1.0, 0.6)]),
                hunde=tramos(t, [(0.0, 0.0), (0.143, 0.30), (0.286, 0.62), (0.429, 0.55), (1.0, 0.48)]),
                brazos=tramos(t, [(0.0, 0.0), (0.143, 0.5), (0.286, 1.1), (0.571, 0.9), (1.0, 0.8)]),
                mece=tramos(t, [(0.0, 0.0), (0.143, 0.6), (0.286, -1.3), (0.429, -1.6), (0.714, -1.2), (1.0, -1.0)]))


def anim_encaje(t):
    # NO RETROCEDE (Resistencia 55): se COMPRIME, el sombrero se hunde y rebota, y acusa el golpe de lado.
    return POSE(hunde=tramos(t, [(0.0, 1.0), (0.34, 0.15), (0.67, -0.30), (1.0, 0.0)]),
                brazos=tramos(t, [(0.0, -1.1), (0.34, 0.7), (0.67, -0.2), (1.0, 0.0)]),
                sacude=tramos(t, [(0.0, 1.4), (0.34, -0.9), (0.67, 0.35), (1.0, 0.0)]))


def anim_muerte(t):
    # SE DESHINCHA: cruje y aguanta, y luego se viene abajo de golpe hasta un monton desparramado; ladeado al final.
    return POSE(derrumbe=tramos(t, [(0.0, 0.0), (0.14, 0.08), (0.28, 0.24), (0.45, 0.58), (0.62, 0.86), (0.78, 1.02),
                                    (0.90, 0.96), (1.0, 1.0)]),
                hunde=tramos(t, [(0.0, 0.0), (0.14, 0.20), (0.45, 0.70), (0.78, 1.0), (1.0, 1.0)]),
                hincha=tramos(t, [(0.0, 0.0), (0.14, 0.16), (0.28, 0.06), (0.62, -0.10), (1.0, -0.14)]),
                brazos=tramos(t, [(0.0, 0.0), (0.14, 0.4), (0.28, -0.2), (0.62, -0.45), (1.0, -0.5)]),
                mece=tramos(t, [(0.0, 0.0), (0.14, -0.6), (0.45, 0.4), (1.0, 0.7)]))


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo.
ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
    'walk': (8, 5.0, True, 8, anim_walk),
    'embestida': (8, 8.0, False, 8, anim_embestida),
    'esporas': (8, 12.0, False, 8, anim_esporas),
    'micelio': (8, 12.0, False, 8, anim_micelio),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 10.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'miconido_806e40_2.00', VISTAS + 'miconido_vs_viejo.png', 4))
    else:
        hornear('miconido_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
