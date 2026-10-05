# ============================================================
#  slime_sdf.py -- los SLIMES en 3D (03/10/2026), con el motor de los enemigos (sdf_comun). Las medidas, las del viejo
#  (slime_sprites.gd: una bola apoyada de 34 de ancho, dos cuernos redondos de su gel, los ojos blancos altos y juntos)
#  y el lienzo y el origen de su horneado, uno por tamaño: el juego los coloca igual.
#  TRES FORMAS: el slime de siempre (normal, venenoso, profundo, abisal: cambian el color y el tamaño), el REY (el aro de
#  cinco puntas de su gel con una gema en cada una, en vez de cuernos) y el de LAVA (roca granate con las juntas
#  encendidas, del color del slime).
#  Uso: SLIME_VAR=<variante> python tools/sprites_sdf/slime_sdf.py [anim ...]
#       python tools/sprites_sdf/slime_sdf.py vistas    -> tools/salida/sdf/slime_*_vs_viejo.png
#  Variantes (tamaño = escala_visual de su ficha): s100 s115 s150 s170 (normal), lava160, rey280.
#  MUTANTES (05/10): mut120 = el BROTADO (lo eligio el jefe de slime_versiones.py, "la version mas god"): yemas de slime
#  con ojitos, un tercer cuerno torcido detras, dos ojos de mas, y dentro su nucleo y los CRISTALES que se ha comido
#  ("pero no tiene cristales dentro"). SOLO EL DEL SLIME NORMAL (slime.tres, s100), x1.2: los demas slimes tendran el
#  suyo. Y SOLO CON LAS ANIMACIONES QUE USA EL NORMAL (ANIMS_BROTADO): "no te inventes cosas".
#  NUCLEO (05/10, lo pidio: "de base en el slime normal se debe ver su nucleo y un cristal dentro"; SUTILES).
#  SLIME_SALIDA=<carpeta> manda las hojas a otro sitio (para enseñarlas sin pisar las del juego).
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

VISTAS = 'tools/salida/sdf/'

def hexc(h):
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

def osc(c, k):
    return tuple(x * (1.0 - k) for x in c)

def cla(c, k):
    return tuple(x + (1.0 - x) * k for x in c)

# LAS VARIANTES: tamaño, forma y el color con el que se pintan las hojas (el BASE del cargador, que tiñe al del piso).
VARIANTES = {
    's100': (1.00, 'normal', 'ff2b2b'),
    's115': (1.15, 'normal', '47d552'),
    's150': (1.50, 'normal', '556a80'),
    's170': (1.70, 'normal', '556faa'),
    'lava160': (1.60, 'lava', 'ff862b'),
    'rey280': (2.80, 'rey', '55b8ff'),
    'mut120': (1.20, 'brotado', 'ff2b2b'),
}
VAR = os.environ.get('SLIME_VAR', 's170')
ESCALA, FORMA, COLOR = VARIANTES[VAR]
SALIDA = os.environ.get('SLIME_SALIDA') or 'assets/sprites/enemigos/slime_sdf_%s/' % VAR
# El nucleo (y los cristales) dentro del gel: el normal y el brotado (el Rey y el de lava, no).
CON_NUCLEO = FORMA in ('normal', 'brotado')


def _lienzo(escala):
    u = 34.0 * escala / 1.15
    w = int(math.ceil(u * 1.66)); h = int(math.ceil(u * 1.52))
    w += w % 2; h += h % 2
    return (w, h), (w * 0.5, h * 1.12 / 1.52)


def _materiales(forma, color):
    c = hexc(color)
    # EL GEL: sombra, base, luz y el BRILLO especular (casi blanco), que pone el motor donde la cupula mira a la luz.
    gel = [osc(c, 0.30), c, cla(c, 0.28), cla(c, 0.62)]
    if forma == 'lava':
        return {
            'gel':    [(0.32, 0.06, 0.10), (0.44, 0.10, 0.12), (0.62, 0.20, 0.16), (0.80, 0.42, 0.30)],
            'lava':   [c, c, (1.0, 0.86, 0.34)],
            'ojo':    [(1.0, 0.99, 0.92)] * 3,
            'gema':   [(1.0, 0.95, 0.72)] * 3,
        }
    # La corona del Rey, de su gel mas claro.
    orn = [cla(c, 0.05), cla(c, 0.28), cla(c, 0.5), cla(c, 0.85)]
    return {'gel': gel, 'cuerno': orn, 'lava': gel, 'ojo': [(1.0, 0.97, 0.72)] * 3, 'gema': [(1.0, 0.95, 0.72)] * 3,
            # EL NUCLEO (oscuro y denso) y EL CRISTAL (el cian de los del juego), que se ven a traves del gel.
            # SUTILES (05/10: "se ven muy cargados, que sean mucho mas sutiles"): el nucleo, solo algo mas oscuro que el gel.
            'nucleo': [osc(c, 0.62), osc(c, 0.48), osc(c, 0.30)],
            'cristal': [(0.30, 0.72, 0.85), (0.55, 0.95, 1.0), (0.85, 1.0, 1.0), (1.0, 1.0, 1.0)]}


LIENZO, PIES = _lienzo(ESCALA)
BORDE = (0.16, 0.03, 0.05) if FORMA == 'lava' else osc(hexc(COLOR), 0.58)
MODELO = Modelo(ESCALA, LIENZO, PIES, _materiales(FORMA, COLOR), BORDE, suaves=('cuerpo',),
                brillan=('ojo', 'gema') + (('lava',) if FORMA == 'lava' else ()), corta_suelo=True,
                especular=('gel', 'cuerno', 'cristal'), umbral_especular=0.955,
                # EL GEL SE TRANSPARENTA (05/10): todo menos los ojos y las gemas, que son solidos. El de LAVA no: es roca.
                translucidos=() if FORMA == 'lava' else ('gel', 'cuerno'), alfa=0.72)
MODELO.alfa_dentro = 0.42
# Lo que brilla dentro (el cristal, el nucleo): el gel casi no lo tapa. Mezclados al 42 % salian GRISES (cian + rojo).
MODELO.claros_dentro = ('cristal', 'nucleo')
MODELO.alfa_claro = 0.45

# EL CUERPO (05/10, su referencia: una GOMINOLA de gel): una BOLA REDONDITA, solo un poco aplastada, posada. Ni disco (la primera vuelta, con los ojos en la coronilla) ni campana (la segunda llevaba
# una falda ancha fundida abajo: "porque es tan ancho abajo").
# Hundida: el suelo la corta a un tercio, asi apoya con una base ANCHA y blanda (al rozar el suelo con la panza
# redonda se leia como una bola sobre un plato).
CUERPO = np.array([0.0, 0.0, 9.0])
CUERPO_R = np.array([16.5, 16.5, 14.0])


def POSE(**k):
    # Los parametros del viejo (slime_sprites.gd), con sus mismas unidades:
    #   squash     alto del cuerpo (1 = reposo; < 1 aplastado y mas ancho, > 1 estirado y mas fino)
    #   derretido  0..1: se deshace en un charco (morir) o se rehace de el (nacer)
    #   bote       cuanto se despega del suelo (en BOTEs)      avance  hacia delante, en unidades
    #   encoge     tamaño entero (1 = el suyo): el brotado al morir se queda en menos (le salen las crias)
    #   yemas      0..1: cuanto asoman las yemas del brotado (al morir se le van)
    p = dict(squash=1.0, derretido=0.0, bote=0.0, avance=0.0, encoge=1.0, yemas=1.0)
    p.update(k)
    return p


BOTE = 3.1
LUNGE = 5.5          # (el viejo, 8: mi slime es algo mayor y al sur se salia del lienzo por abajo)
ENCAJE_RETRO = 3.4


def huesos(p):
    # Solo se MUEVE (bote y avance): la forma -- aplastarse, estirarse, derretirse -- se hace cambiando la bola en
    # escena(), no escalando el hueso: aplastada al 15 % con una escala, el trazado de rayos atravesaba la figura.
    return {'raiz': (np.eye(3), np.array([0.0, p['avance'], p['bote'] * BOTE]))}


def _forma(p):
    """El centro y los radios de la bola en esta pose (conservando mas o menos el volumen)."""
    sq = p['squash']; de = p['derretido']
    sz = sq * (1.0 - 0.82 * de)
    # Mas ancho al aplastarse, con tope: derretido del todo se quedaba un charco que llenaba el lienzo entero.
    # (el lienzo del viejo deja poco sitio bajo el suelo: mirando al sur, un charco mas ancho se salia por abajo)
    sxy = min(1.0 / math.sqrt(max(sq, 0.2)) * (1.0 + 0.1 * de), 1.1)
    en = p.get('encoge', 1.0)
    R = CUERPO_R * np.array([sxy, sxy, sz]) * en
    C = np.array([CUERPO[0], CUERPO[1], CUERPO[2] * sz * en])
    return C, R, sz


def _superficie(d, C=CUERPO, R=CUERPO_R):
    """El punto del cuerpo en la direccion 'd' desde su centro."""
    d = np.array(d, dtype=float); d /= np.linalg.norm(d)
    k = 1.0 / math.sqrt(((d / R) ** 2).sum())
    return C + d * k, d


# LAS JUNTAS DE LAVA: un mosaico de placas sobre la bola (celdas de Voronoi en la esfera unidad); 'junta' es lo que
# falta para el borde entre dos placas.
_rng = np.random.default_rng(7)
_SEMILLAS = _rng.normal(size=(26, 3)); _SEMILLAS /= np.linalg.norm(_SEMILLAS, axis=1, keepdims=True)

def _junta(P, C, R):
    q = (P - C) / R
    q /= np.maximum(np.linalg.norm(q, axis=1, keepdims=True), 1e-6)
    d = np.linalg.norm(q[:, None, :] - _SEMILLAS[None, :, :], axis=2)
    d.sort(axis=1)
    return (d[:, 1] - d[:, 0]) * 0.5


def escena(pose):
    e = Escena(huesos(pose))
    add = e.add
    C, R, sz = _forma(pose)
    add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    # SIN CHARCO NI GOTAS (05/10, lo dijo el jefe): la baba del suelo la deja el juego por donde pasa
    # (Enemy._actualizar_rastro); pintada en el sprite iria pegada al slime. (Al MORIR si: el charco es el.)
    if FORMA == 'lava':
        # LA JUNTA: una capa un pelo por fuera del cuerpo, solo donde la placa se acaba: por ahi asoma la lava.
        def junta(P):
            cuerpo = sd_elipsoide(P, C, R + 0.18)
            return np.maximum(cuerpo, _junta(P, C, R) * 22.0 - 0.75)
        add(junta, 'lava', 0, 'junta')
    if FORMA == 'rey':
        # LA CORONA: un aro de cinco puntas de su gel, alrededor de la coronilla, con una GEMA en cada punta.
        for k in range(5):
            a = k / 5.0 * 2 * math.pi + math.pi * 0.5
            base, n = _superficie((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.83), C, R)
            base = base - n * 1.0
            punta = base + np.array([math.cos(a) * 0.8, math.sin(a) * 0.8, 7.5 * sz])
            add(lambda P, a=base, b=punta: sd_cono(P, a, b, 2.4, 1.3), 'cuerno', 0, 'corona')
            add(lambda P, c=punta + np.array([0, 0, 0.8]): sd_esfera(P, c, 1.35), 'gema', 0, 'gema')
    else:
        if FORMA == 'brotado':
            _brotes(e, C, R, sz, pose)
        # LOS CUERNOS: cortos y PUNTIAGUDOS, arriba a los lados, del MISMO gel y fundidos con la cupula (la referencia).
        for s in (-1, 1):
            base, n = _superficie((0.70 * s, 0.05, 0.72), C, R)
            raiz = base - n * 2.0
            en = pose['encoge']
            medio = base + n * 2.6 * en + np.array([0.6 * s * en, 0.0, 3.0 * sz * en])
            punta = medio + np.array([-0.6 * s * en, 0.0, 3.6 * sz * en])
            # (derritiendose, los cuernos se funden con el charco)
            fu = (1.0 - 0.85 * pose['derretido']) * en
            add(lambda P, a=raiz, b=medio, fu=fu: sd_cono(P, a, b, 4.4 * fu, 2.4 * fu), 'gel', 1.8)
            add(lambda P, a=medio, b=punta, fu=fu: sd_cono(P, a, b, 2.4 * fu, 0.9 * fu), 'gel', 1.0)
    # LOS OJOS: dos OVALOS VERTICALES amarillo palido EN EL FRENTE, a media altura, que asoman de la cara. El brotado
    # lleva dos mas, pequeños y descolocados.
    en = pose['encoge']
    ojos = [(-0.33, 0.88, 0.34, 1.0), (0.33, 0.88, 0.34, 1.0)]
    if FORMA == 'brotado':
        ojos += [(-0.55, 0.75, 0.55, 0.62), (0.08, 0.93, 0.62, 0.5)]
    for x, y, z, k in ojos:
        base, n = _superficie((x, y, z), C, R)
        c = base + n * 0.05
        # RECORTADO CONTRA LA BOLA: alto como es, su punta de arriba asomaba por la coronilla al mirar de espaldas. Y
        # aplastado con ella (derretido, se hunde en el charco).
        rad = np.array([2.3 * k * en, 3.0 * k * en, 5.0 * min(1.0, sz * 1.1) * k * en])
        add(lambda P, c=c, rad=rad: np.maximum(sd_elipsoide(P, c, rad), sd_elipsoide(P, C, R) - 0.3), 'ojo', 0, 'ojo')
    if CON_NUCLEO:
        # EL NUCLEO, algo bajo y atras (que no tape los ojos de frente).
        add(lambda P, c=C + np.array([0.0, -2.5, -1.5]) * en, r=3.4 * en: sd_esfera(P, c, r), 'nucleo', 0, 'nucleo')
        # Y LOS CRISTALES: uno en el normal; en el brotado, los que se ha comido.
        cris = _CRISTALES_BROTADO if FORMA == 'brotado' else [((5.0, -1.0, 2.5), (0.5, 0.2, 1.0), 6.0, 1.7)]
        for c, eje, largo, radio in cris:
            _cristal(e, C + np.array(c) * en, eje, largo * en * 0.75, radio * en * 0.65)
    return e.L


# UN CRISTAL: bipiramide alargada (dos conos punta con punta) centrada en 'c', a lo largo de 'eje'.
def _cristal(e, c, eje, largo, radio):
    eje = np.array(eje, dtype=float); eje /= np.linalg.norm(eje)
    a = c - eje * largo * 0.5; b = c + eje * largo * 0.5
    e.add(lambda P, a=a, c=c, b=b: np.minimum(sd_cono(P, a, c, 0.25, radio), sd_cono(P, c, b, radio, 0.25)),
          'cristal', 0, 'cristal')


# Los cristales que lleva dentro el brotado (centro respecto al de la bola, eje, largo, grosor): repartidos a distintas
# alturas y giros, sin tapar los ojos de frente.
_CRISTALES_BROTADO = [((5.5, 1.0, 3.5), (0.6, 0.1, 1.0), 7.0, 2.0),
                      ((-6.0, 2.0, 0.5), (-0.4, 0.3, 1.0), 6.0, 1.7),
                      ((0.5, -6.0, 5.5), (0.2, -0.6, 1.0), 7.5, 2.1),
                      ((6.5, -5.0, -3.0), (0.3, 0.5, 1.0), 5.0, 1.5)]


# EL BROTADO: las YEMAS (bolitas de slime a medio salir, unas con su ojito) y el TERCER CUERNO, torcido, detras. Todo
# sale de la bola de esta pose, asi que se aplasta, bota y se encoge con ella.
_YEMAS = [(0.85, -0.30, 0.30, 5.6, True), (-0.80, -0.45, 0.10, 4.8, True), (0.30, -0.85, 0.55, 4.2, False),
          (-0.45, 0.10, 0.85, 3.8, True), (0.70, 0.45, -0.20, 3.6, False)]


def _brotes(e, C, R, sz, pose):
    en = pose['encoge']; ye = pose['yemas']; fu = 1.0 - 0.85 * pose['derretido']
    if ye > 0.05:
        for x, y, z, r, ojo in _YEMAS:
            r = r * en * ye
            base, n = _superficie((x, y, z), C, R)
            c = base + n * r * 0.35
            e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'gel', 1.6)
            if ojo:
                m = n + np.array([0.0, 0.6, 0.0]); m /= np.linalg.norm(m)
                o = c + m * (r * 0.92)
                e.add(lambda P, o=o, r=r: sd_elipsoide(P, o, np.array([1.1, 1.1, 1.5]) * (r / 4.5)), 'ojo', 0, 'ojo')
    base, n = _superficie((0.10, -0.45, 0.88), C, R)
    tam = 0.85 * en
    raiz = base - n * 2.0
    medio = base + n * 2.6 * tam + np.array([0.6 * tam + 1.0 * en, 0.0, 3.0 * tam * sz])
    punta = medio + np.array([-0.6 * tam + 1.6 * en, 0.0, 3.6 * tam * sz])
    e.add(lambda P, a=raiz, b=medio: sd_cono(P, a, b, 4.4 * tam * fu, 2.4 * tam * fu), 'gel', 1.8)
    e.add(lambda P, a=medio, b=punta: sd_cono(P, a, b, 2.4 * tam * fu, 0.9 * fu), 'gel', 1.0)


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
TAU = 2 * math.pi
T = tramos


def anim_idle(t):
    return POSE(squash=1.0 + 0.03 * math.sin(TAU * t))


def anim_walk(t):
    return POSE(squash=1.0 - 0.17 * math.cos(TAU * t), bote=math.sin(math.pi * t))


def anim_embestida(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.25, 0.60), (0.55, 1.25), (0.75, 0.70), (1.0, 0.95)]),
                avance=T(t, [(0.0, 0.0), (0.25, 0.0), (0.55, 0.90), (0.75, 0.95), (1.0, 0.70)]) * LUNGE,
                bote=T(t, [(0.0, 0.0), (0.25, 0.0), (0.55, 1.0), (0.75, 0.15), (1.0, 0.0)]) * 1.4)


def anim_inflar(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.30, 0.68), (0.62, 1.32), (0.82, 1.16), (1.0, 1.24)]),
                bote=T(t, [(0.0, 0.0), (0.30, -0.25), (0.62, 0.35), (0.82, 0.20), (1.0, 0.55)]))


def anim_hinchado(t):
    l = math.sin(TAU * t)
    return POSE(squash=1.24 + 0.06 * l, bote=0.55 + 0.10 * l)


def anim_deshincharse(t):
    return POSE(squash=T(t, [(0.0, 1.24), (0.143, 1.02), (0.286, 0.74), (0.429, 0.90), (0.571, 0.80), (0.714, 0.94),
                             (0.857, 0.96), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.55), (0.143, 0.20), (0.286, -0.20), (0.429, 0.06), (0.571, -0.08), (0.714, 0.02),
                           (0.857, 0.0), (1.0, 0.0)]))


def anim_encogido(t):
    tiembla = 1.0 if int(round(t * 8)) % 2 == 0 else -1.0
    return POSE(squash=0.68 + 0.05 * tiembla, avance=-1.2 + 0.7 * tiembla)


def anim_aplaston(t):
    return POSE(squash=T(t, [(0.0, 0.58), (0.143, 0.66), (0.286, 1.14), (0.429, 1.10), (0.571, 0.86), (0.714, 1.06),
                             (0.857, 0.98), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.143, 0.0), (0.286, 0.30), (0.429, 0.20), (0.571, 0.0), (0.714, 0.06),
                           (0.857, 0.0), (1.0, 0.0)]))


def anim_ignicion(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.143, 0.90), (0.286, 1.14), (0.429, 0.88), (0.571, 1.20), (0.714, 0.90),
                             (0.857, 1.16), (1.0, 1.06)]),
                bote=T(t, [(0.0, 0.0), (0.143, -0.10), (0.286, 0.16), (0.429, -0.08), (0.571, 0.22), (0.714, 0.0),
                           (0.857, 0.18), (1.0, 0.08)]))


def anim_brote(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.143, 0.90), (0.286, 1.22), (0.429, 1.32), (0.571, 0.74), (0.714, 0.90),
                             (0.857, 1.08), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.143, -0.20), (0.286, 0.24), (0.429, 0.35), (0.571, -0.15), (0.714, 0.05),
                           (0.857, 0.12), (1.0, 0.0)]))


def anim_escupir(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.143, 0.88), (0.286, 0.76), (0.429, 1.30), (0.571, 1.16), (0.714, 0.94),
                             (0.857, 1.04), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.143, -0.14), (0.286, -0.22), (0.429, 0.26), (0.571, 0.12), (0.714, -0.06),
                           (0.857, 0.04), (1.0, 0.0)]))


def anim_muerte(t):
    if FORMA == 'brotado':
        return _muerte_brotado(t)
    # Se DERRITE donde esta: un ultimo respingo y se deshace en un charco.
    return POSE(squash=T(t, [(0.0, 1.0), (0.14, 1.16), (0.28, 0.92), (0.45, 0.72), (0.62, 0.58), (0.78, 0.48),
                             (0.90, 0.43), (1.0, 0.42)]),
                derretido=T(t, [(0.0, 0.0), (0.14, 0.0), (0.28, 0.12), (0.45, 0.38), (0.62, 0.64), (0.78, 0.86),
                                (0.90, 0.97), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.14, 0.45), (0.28, 0.0), (1.0, 0.0)]))


# LA MUERTE DEL BROTADO (05/10, lo pidio el jefe): no se derrite, SE ENCOGE. Un respingo, dos convulsiones en las
# que las yemas se le recogen (son las dos crias que el juego saca a su lado) y se queda tirado, mas pequeño y algo
# aplastado: ese es su CADAVER, que se queda en el suelo con su cristal dentro.
def _muerte_brotado(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.12, 1.18), (0.26, 0.82), (0.40, 1.06), (0.54, 0.80), (0.70, 0.90),
                             (0.85, 0.74), (1.0, 0.72)]),
                encoge=T(t, [(0.0, 1.0), (0.12, 1.02), (0.40, 0.90), (0.70, 0.72), (1.0, 0.66)]),
                yemas=T(t, [(0.0, 1.0), (0.26, 1.0), (0.54, 0.35), (0.70, 0.0), (1.0, 0.0)]),
                derretido=T(t, [(0.0, 0.0), (0.70, 0.05), (1.0, 0.18)]),
                bote=T(t, [(0.0, 0.0), (0.12, 0.45), (0.26, 0.0), (0.40, 0.18), (0.54, 0.0), (1.0, 0.0)]))


def anim_nacer(t):
    # Al reves: del charco se levanta y se rehace (las crias del Rey).
    return POSE(squash=T(t, [(0.0, 0.42), (0.20, 0.48), (0.40, 0.66), (0.60, 0.92), (0.76, 1.16), (0.88, 0.94), (1.0, 1.0)]),
                derretido=T(t, [(0.0, 1.0), (0.20, 0.90), (0.40, 0.62), (0.60, 0.28), (0.76, 0.0), (1.0, 0.0)]),
                bote=T(t, [(0.0, 0.0), (0.60, 0.0), (0.76, 0.40), (0.88, 0.0), (1.0, 0.0)]))


def anim_encaje(t):
    return POSE(squash=T(t, [(0.0, 0.64), (0.34, 1.18), (0.67, 0.93), (1.0, 1.0)]),
                avance=-T(t, [(0.0, 1.0), (0.34, 0.55), (0.67, 0.18), (1.0, 0.0)]) * ENCAJE_RETRO,
                bote=T(t, [(0.0, 0.0), (0.34, 0.45), (0.67, 0.0), (1.0, 0.0)]))


ANIMS = {
    'idle': (8, 4.0, True, 8, anim_idle),
    'walk': (8, 8.0, True, 8, anim_walk),
    'embestida': (8, 10.0, False, 8, anim_embestida),
    'inflar': (8, 9.0, False, 8, anim_inflar),
    'hinchado': (8, 8.0, True, 8, anim_hinchado),
    'deshincharse': (8, 10.0, False, 8, anim_deshincharse),
    'encogido': (8, 12.0, True, 8, anim_encogido),
    'aplaston': (8, 14.0, False, 8, anim_aplaston),
    'ignicion': (8, 12.0, False, 8, anim_ignicion),
    'brote': (8, 10.0, False, 8, anim_brote),
    'escupir': (8, 12.0, False, 8, anim_escupir),
    'nacer': (8, 10.0, False, 8, anim_nacer),
    'muerte': (8, 10.0, False, 8, anim_muerte),
    'encaje': (4, 18.0, False, 8, anim_encaje),
}


# Las del slime NORMAL y nada mas: quieto, andar, embestida (su basico, el Placaje y el Doble embate), inflar, hinchado,
# aplaston y deshincharse (el Reventon), encajar y morir (el cadaver es su ultimo fotograma).
ANIMS_BROTADO = ('idle', 'walk', 'embestida', 'inflar', 'hinchado', 'aplaston', 'deshincharse', 'encaje', 'muerte')
if FORMA == 'brotado':
    ANIMS = {k: v for k, v in ANIMS.items() if k in ANIMS_BROTADO}


VIEJOS = {'s170': 'slime_556faa_1.70', 's115': 'slime_47d552_1.15', 's150': 'slime_556a80_1.50', 's100': 'slime_ff2b2b_1.00',
          'rey280': 'slime_55b8ff_2.80_corona', 'lava160': 'slime_ff862b_1.60_lava'}

if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, VIEJOS[VAR], VISTAS + 'slime_%s_vs_viejo.png' % VAR, 4))
    else:
        hornear('slime_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
