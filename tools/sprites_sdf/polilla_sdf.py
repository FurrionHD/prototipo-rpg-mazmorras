# ============================================================
#  polilla_sdf.py -- la POLILLA DE ESPORAS en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (polilla_sprites.gd): NO SE POSA NUNCA y LA SILUETA SON LAS ALAS -- dos pares, ABIERTAS en aspa (volando, no el
#  tejadillo de reposo), anchas y REDONDAS, LISAS (sin huesos ni dedos: eso es de murcielago). Las delanteras algo hacia
#  delante, las traseras casi igual de grandes y hacia atras. EL OCELO en cada delantera (anillo claro, nucleo oscuro).
#  Cuerpo PELUDO y pardo (torax gordo con su gola de pelo, abdomen anillado), cabeza pequeña con OJOS GRANDES y oscuros
#  y ANTENAS PLUMOSAS en arco. Las alas son LAMINAS (sd_triangulo) y lo de encima (la base oscura, el ocelo) discos
#  pegados a su plano. LA SOMBRA en el suelo (Escena.sombra).
#  Lienzo y origen de su horneado (1,90 -> 90 x 90, el centro).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/polilla_sdf.py [anim ...]  -> assets/sprites/enemigos/polilla_sdf/<anim>.png
#       python tools/sprites_sdf/polilla_sdf.py vistas     -> tools/salida/sdf/polilla_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/polilla_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Lila ceniza (a48eaa) en las alas; el pelo, PARDO (tono fijo, como el viejo: escalar el lila lo mandaba a verde).
MAT = {
    'ala':      [(0.47, 0.40, 0.50), (0.64, 0.56, 0.67), (0.75, 0.69, 0.78)],
    'ala_tras': [(0.36, 0.29, 0.38), (0.49, 0.41, 0.51), (0.58, 0.50, 0.60)],
    'ocelo':    [(0.70, 0.64, 0.52), (0.86, 0.80, 0.64), (0.93, 0.88, 0.74)],
    'ocelo_n':  [(0.13, 0.10, 0.14), (0.18, 0.14, 0.20), (0.24, 0.20, 0.26)],
    'pelo':     [(0.30, 0.22, 0.16), (0.43, 0.32, 0.23), (0.56, 0.44, 0.33)],
    'anillo':   [(0.22, 0.16, 0.12), (0.31, 0.23, 0.17), (0.38, 0.29, 0.22)],
    'antena':   [(0.58, 0.50, 0.40), (0.74, 0.66, 0.54), (0.84, 0.77, 0.65)],
    'ojo':      [(0.06, 0.05, 0.07), (0.10, 0.09, 0.12), (0.20, 0.18, 0.24), (0.80, 0.78, 0.86)],
}
# Algo mayor que su escala (1,9), como los demas que se han pasado.
MODELO = Modelo(2.0, (90, 90), (45, 45), MAT, (0.08, 0.06, 0.09), suaves=('cuerpo', 'cabeza'), brillan=(),
                corta_suelo=True, especular=('ojo',), umbral_especular=0.8)

VUELO_Z = 10.5
CABECEO = 1.1
LUNGE_DIST = 9.0
ENCAJE_RETRO = 0.62
BATE_MAX = 0.95

# LAS ALAS en su plano: (raiz, centro del ovalo a lo largo/atras, radios, cuanto se adelanta la punta, grosor).
ALA1 = dict(raiz=V((1.35, 2.6, VUELO_Z + 0.35)), centro=(6.6, 2.6), radios=(6.4, 5.2), adelanta=0.26)
ALA2 = dict(raiz=V((1.20, -1.4, VUELO_Z - 0.35)), centro=(5.0, 3.8), radios=(5.0, 4.7), adelanta=-0.30)


def POSE(**k):
    p = dict(avance=0.0, bate=0.0, altura=1.0, cabeceo=0.0, ladea=0.0, polvo=0.0, cae=0.0, abre=0.0)
    p.update(k)
    return p


def _alto(p):
    return VUELO_Z * p['altura'] * (1.0 - p['cae']) + p['cabeceo'] * CABECEO - VUELO_Z


def huesos(p):
    # TODO EL BICHO: avanza, sube y baja (altura, cabeceo; 'cae' lo lleva al suelo) y se LADEA (vuela a tirones). Al
    # caer muerta vuelca de lado y cabecea morro abajo.
    centro = V((0.0, 0.0, VUELO_Z))
    raiz = (np.eye(3), V((0.0, p['avance'], _alto(p))))
    raiz = comp(raiz, sobre(centro, ry(p['ladea'] * 0.30)))
    raiz = comp(raiz, sobre(centro, rx(p['cae'] * 0.35)))
    return {'raiz': raiz}


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _disco(add, c, e1, e2, r1, r2, grosor, mat, grupo):
    """Un disco pegado al plano del ala (e1, e2): la base oscura, el ocelo."""
    n = np.cross(e1, e2); n /= np.linalg.norm(n)
    E = V((e1, e2, n)); c = V(c, dtype=float); r = V((r1, r2, grosor))
    add(lambda P: sd_elipsoide((P - c) @ E.T, np.zeros(3), r), mat, 0, grupo, 'raiz')


def _ala(add, p, s, A, ocelo, nombre, mat='ala'):
    """Un ala: un ovalo en su plano, girado sobre la raiz por el BATEO (la punta va algo retrasada: se curva).
    'abre' la estira a lo ancho (la nube). Todo en el marco de la raiz."""
    abre = 1.0 + 0.22 * p['abre']
    th = p['bate'] * BATE_MAX
    def punto(span, atras):
        span *= abre
        atras = atras - span * A['adelanta']
        phi = th - 0.18 * p['bate'] * (span / 12.0)
        return A['raiz'] * V((s, 1, 1)) + V((s * span * math.cos(phi), -atras, span * math.sin(phi)))
    cx, cy = A['centro']; rx_, ry_ = A['radios']
    N = 16
    borde = []
    for i in range(N):
        a = 2 * math.pi * i / N
        # Un ovalo algo PICUDO en la punta de fuera (las delanteras de una polilla tienen apice).
        r = 1.0 + (0.10 if math.cos(a) > 0.6 else 0.0) * (math.cos(a) - 0.6) / 0.4
        borde.append(punto(cx + rx_ * r * math.cos(a), cy + ry_ * math.sin(a)))
    cen = punto(cx, cy)
    for i in range(N):
        add(lambda P, a=cen, b=borde[i], c=borde[(i + 1) % N]: sd_triangulo(P, a, b, c, 0.22), mat, 0, nombre, 'raiz')
    # La raiz pegada al cuerpo.
    r0 = punto(0.0, 0.0); r1 = punto(0.0, cy * 1.6)
    add(lambda P, a=r0, b=r1, c=cen: sd_triangulo(P, a, b, c, 0.22), mat, 0, nombre, 'raiz')
    # El plano del ala (para lo que va pegado encima).
    e1 = punto(1.0, cy) - punto(0.0, cy); e1 /= np.linalg.norm(e1)
    e2 = punto(cx, cy + 1.0) - punto(cx, cy); e2 /= np.linalg.norm(e2)
    # EL OCELO: grande en las delanteras, pequeño en las traseras.
    k = 1.0 if ocelo else 0.62
    c = punto(cx + rx_ * 0.30, cy - ry_ * 0.05)
    _disco(add, c, e1, e2, 1.85 * k, 1.65 * k, 0.34, 'ocelo', nombre)
    _disco(add, c, e1, e2, 0.85 * k, 0.80 * k, 0.42, 'ocelo_n', nombre)


def escena(pose):
    p = pose
    e = Escena(huesos(p)); add = e.add
    Z = VUELO_Z
    # --- EL CUERPO: torax gordo y peludo con su GOLA (el cuello de pelo), abdomen anillado que se afila atras.
    _elip(add, (0.0, 2.4, Z), (2.8, 2.6, 2.5), 'pelo', 0.8)
    for k in range(7):
        a = 2 * math.pi * k / 7
        _elip(add, (1.9 * math.cos(a), 4.1, Z + 1.8 * math.sin(a)), (1.1, 0.9, 1.1), 'pelo', 0.5)
    for i in range(4):
        y = 0.4 - 2.0 * i
        r = 1.85 - 0.30 * i
        _elip(add, (0.0, y, Z - 0.2 - 0.15 * i), (r, 1.4, r * 0.92), 'pelo', 0.7)
    for i in range(3):
        y = -0.6 - 2.0 * i
        r = 1.75 - 0.30 * i
        add(lambda P, c=V((0.0, y, Z - 0.3 - 0.15 * i)), r=r: np.sqrt(
            (np.sqrt((P[:, 0] - c[0]) ** 2 + ((P[:, 2] - c[2]) / 0.92) ** 2) - r) ** 2 + (P[:, 1] - c[1]) ** 2) - 0.28,
            'anillo', 0, 'anillo')
    # --- LA CABEZA: pequeña, con OJOS GRANDES y oscuros (una polilla es casi todo ojo).
    _elip(add, (0.0, 6.0, Z - 0.1), (1.8, 1.6, 1.7), 'pelo', 0.5, 'cabeza')
    for s in (-1, 1):
        d = V((0.62 * s, 0.66, 0.22)); d /= np.linalg.norm(d)
        _elip(add, V((0.0, 6.0, Z - 0.1)) + d * 1.2, (1.1, 1.1, 1.1), 'ojo', 0, 'ojo')
    # --- LAS ANTENAS PLUMOSAS: un eje en ARCO hacia delante, arriba y afuera, con barbas a los lados.
    for s in (-1, 1):
        pts = []
        for i in range(7):
            u = i / 6
            ang = 0.45 + 0.30 * u * u
            pts.append(V((s * (0.5 + 6.6 * u * math.sin(ang)), 6.9 + 6.6 * u * math.cos(ang) * 0.75,
                          Z + 0.9 + 6.6 * u * 0.62 - 1.6 * u * u)))
        for i in range(6):
            _cono(add, pts[i], pts[i + 1], 0.42 - 0.04 * i, 0.38 - 0.04 * i, 'antena', 0, 'antena')
            if i >= 1:
                d = pts[i + 1] - pts[i]; d /= np.linalg.norm(d)
                lat = np.cross(d, V((0, 0, 1.0))); lat /= np.linalg.norm(lat)
                largo = 1.8 * math.sin(math.pi * (i + 0.5) / 6.5)
                for sg in (-1, 1):
                    _cono(add, pts[i], pts[i] + lat * sg * largo - d * 0.5, 0.34, 0.26, 'antena', 0, 'antena')
    # --- LAS ALAS: traseras primero (debajo), delanteras encima; el ocelo en las delanteras.
    for s in (-1, 1):
        _ala(add, p, s, ALA2, False, 'ala2', 'ala_tras')
        _ala(add, p, s, ALA1, True, 'ala1')
    # --- LA SOMBRA en el suelo, menor cuanto mas alto vuela.
    alto = max(0.0, VUELO_Z + _alto(p))
    k = 1.0 - 0.22 * min(alto / VUELO_Z, 1.5)
    e.sombra(0.0, p['avance'] + 1.0, 7.5 * k, 4.2 * k)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def _bateo(t, fuerza):
    # El cuerpo cabecea AL REVES que las alas (cuando bajan, sube): se lee como que se sostiene.
    b = math.sin(2 * math.pi * t)
    return dict(bate=b * fuerza, cabeceo=-b * 0.85)


def anim_idle(t):
    return POSE(**_bateo(t, 0.55))


def anim_walk(t):
    return POSE(ladea=0.55 * math.sin(math.pi * t), altura=1.0 + 0.10 * math.sin(2 * math.pi * t), **_bateo(t, 1.0))


def anim_embestida(t):
    return POSE(avance=tramos(t, [(0.0, 0.0), (0.30, -1.6), (0.48, 3.2), (0.68, 8.4), (0.84, 9.0), (1.0, 6.0)]),
                bate=tramos(t, [(0.0, 0.0), (0.30, 1.0), (0.48, -1.0), (0.68, -0.55), (0.84, 0.2), (1.0, 0.0)]),
                cabeceo=tramos(t, [(0.0, 0.0), (0.30, -0.9), (0.48, 1.1), (0.68, 0.6), (1.0, 0.0)]))


def anim_aletear(t):
    # TRES BATIDOS rapidos sin moverse del sitio, echandose un pelin hacia delante ("se te viene a la cara").
    u = min(max(t / 0.5, 0.0), 1.0)
    return POSE(polvo=min(t * 2.4, 1.0), avance=2.2 * u * u * (3 - 2 * u), **_bateo(t * 3.0, 1.0))


def anim_nube(t):
    # UN SOLO batido enorme y lento: sube, AGUANTA arriba y baja de golpe abriendose del todo.
    return POSE(bate=tramos(t, [(0.0, 0.0), (0.143, 0.75), (0.286, 1.0), (0.429, 1.0), (0.571, -1.0), (0.714, -0.7),
                                (0.857, -0.2), (1.0, 0.0)]),
                abre=tramos(t, [(0.0, 0.0), (0.286, 0.35), (0.429, 0.45), (0.571, 1.0), (0.714, 0.8), (1.0, 0.3)]),
                polvo=tramos(t, [(0.0, 0.0), (0.429, 0.0), (0.571, 0.55), (0.714, 0.85), (1.0, 1.0)]),
                cabeceo=tramos(t, [(0.0, 0.0), (0.286, -1.1), (0.429, -1.2), (0.571, 1.3), (0.714, 0.6), (1.0, 0.0)]))


def anim_encaje(t):
    # Empieza YA golpeada: sale despedida de lado como un papel y pierde altura.
    return POSE(avance=-tramos(t, [(0.0, 1.0), (0.34, 0.45), (0.67, 0.12), (1.0, 0.0)]) * LUNGE_DIST * ENCAJE_RETRO,
                ladea=tramos(t, [(0.0, 1.6), (0.34, -0.9), (0.67, 0.35), (1.0, 0.0)]),
                altura=tramos(t, [(0.0, 0.55), (0.34, 0.80), (0.67, 0.95), (1.0, 1.0)]),
                bate=tramos(t, [(0.0, -0.9), (0.34, 0.9), (0.67, -0.3), (1.0, 0.0)]))


def anim_muerte(t):
    # SE CAE DEL AIRE: dos aletazos desesperados, pierde altura a tirones y se estrella de lado.
    return POSE(cae=tramos(t, [(0.0, 0.0), (0.14, 0.10), (0.28, 0.06), (0.45, 0.34), (0.62, 0.28), (0.78, 0.72),
                               (0.90, 0.95), (1.0, 1.0)]),
                bate=tramos(t, [(0.0, 0.9), (0.14, -0.8), (0.28, 0.55), (0.45, -0.6), (0.62, 0.25), (0.78, -0.9),
                                (1.0, -1.0)]),
                ladea=tramos(t, [(0.0, 0.0), (0.28, 0.6), (0.62, 1.2), (0.90, 1.7), (1.0, 1.8)]),
                cabeceo=tramos(t, [(0.0, 0.0), (0.28, 0.8), (0.62, 1.4), (1.0, 1.8)]))


# nombre: (fotogramas, fps, loop, direcciones, funcion) -- los del viejo.
ANIMS = {
    'idle': (8, 6.0, True, 8, anim_idle),
    'walk': (8, 12.0, True, 8, anim_walk),
    'embestida': (8, 12.0, False, 8, anim_embestida),
    'aletear': (8, 14.0, False, 8, anim_aletear),
    'nube': (8, 10.0, False, 8, anim_nube),
    'encaje': (4, 18.0, False, 8, anim_encaje),
    'muerte': (8, 11.0, False, 8, anim_muerte),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(anim_idle(0.0)), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'polilla_a48eaa_1.90', VISTAS + 'polilla_vs_viejo.png', 4))
    else:
        hornear('polilla_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
