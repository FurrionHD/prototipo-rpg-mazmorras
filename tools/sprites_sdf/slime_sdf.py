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
    # LA 2a EVOLUCION (05/10, idea suya): el brotado con los cristales ya POR FUERA como puas. Un poco mas grande que el
    # brotado (x1.1, aprobado el 06/10: "quiero que sea un poco mas grande que el brotado").
    'evo2': (1.32, 'puas', 'ff2b2b'),
    # EL SLIME PUNZANTE (06/10, la version C de slime_versiones: "es justo lo que queria"): el OTRO mutante de 1a categoria
    # del slime normal. Puas de cristal por fuera con su costra, sin yemas; pasiva de espinas y su ataque, EXPANDIR PUAS.
    'pun120': (1.20, 'punzante', 'ff2b2b'),
    # LOS MUTANTES DEL SLIME VENENOSO (06/10, lo eligio el jefe de slime_veneno_versiones.py 'elegido'): UNA LINEA.
    # SLIME DE MIASMA (1a, x1,2 del venenoso): poros abiertos por donde le sale el humo A RATOS (el humo lo pone el juego,
    # en sitios al azar). SLIME PESTILENTE (2a, x1,1 del miasma): ademas, burbujitas por toda la piel (las que revientan
    # al azar las pone el juego). Solo con las anims del VENENOSO (+ comer, evolucion, aspirar/exhalar, soltar_burbujas).
    'mia138': (1.38, 'miasma', '47d552'),
    'pes152': (1.518, 'pestilente', '47d552'),
    # LOS MUTANTES DEL SLIME DE FUEGO (06/10, lo eligio el jefe de slime_fuego_versiones.py): UNA LINEA, el fuego se va
    # ENFRIANDO. CENIZA Y BRASA (1a, x1,2 del de fuego): costra de ceniza gris con las grietas en brasa y lascas a medio
    # caer. OBSIDIANA (2a, x1,1 de la ceniza): cristal volcanico negro y brillante, lava entre las placas y AGUJAS.
    'cen192': (1.92, 'ceniza', 'ff862b'),
    'obs211': (2.112, 'obsidiana', 'ff862b'),
}
VAR = os.environ.get('SLIME_VAR', 's170')
ESCALA, FORMA, COLOR = VARIANTES[VAR]
SALIDA = os.environ.get('SLIME_SALIDA') or 'assets/sprites/enemigos/slime_sdf_%s/' % VAR
# El nucleo (y los cristales) dentro del gel: el normal y el brotado (el Rey y el de lava, no).
# SOLO EL SLIME NORMAL (s100) y sus evoluciones: lo pidio para el normal ("no te inventes cosas"); los demas, cuando toque.
CON_NUCLEO = VAR in ('s100', 'mut120', 'evo2', 'pun120', 'mia138', 'pes152')
# Las dos evoluciones del slime normal comparten cuerpo (yemas, tercer cuerno, ojos de mas).
BROTADO = FORMA in ('brotado', 'puas')
# Las dos del venenoso comparten piel (poros; la 2a, burbujas).
TOXICO = FORMA in ('miasma', 'pestilente')
# Los de ROCA Y LAVA (el de fuego y sus mutantes): placas con las juntas encendidas, sin gel translucido.
ROCA = FORMA in ('lava', 'ceniza', 'obsidiana')


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
    if forma == 'ceniza':
        # LA CENIZA: costra gris; la BRASA de las grietas, mas roja y apagada que la lava.
        brasa = [(0.62, 0.12, 0.05), (0.86, 0.28, 0.08), (1.0, 0.52, 0.18)]
        return {
            'gel':    [(0.26, 0.24, 0.24), (0.40, 0.38, 0.37), (0.55, 0.53, 0.51), (0.62, 0.60, 0.58)],
            'lava':   brasa,
            'chispa': [brasa[1], brasa[2], brasa[2]],
            'ojo':    [(1.0, 0.99, 0.92)] * 3,
            'gema':   [(1.0, 0.95, 0.72)] * 3,
            'parpado': [(0.26, 0.24, 0.24), (0.40, 0.38, 0.37), (0.55, 0.53, 0.51)],
            'pestana': [(0.12, 0.10, 0.10)] * 3,
            # (transformandose: la roca ROJA del de fuego que se le cae a placas)
            'antes':  [(0.32, 0.06, 0.10), (0.44, 0.10, 0.12), (0.62, 0.20, 0.16), (0.80, 0.42, 0.30)],
        }
    if forma == 'obsidiana':
        # LA OBSIDIANA: negra con reflejo violaceo y su BRILLO especular; la lava entre las placas, la de siempre.
        # (su referencia, 06/10: cristal negro TALLADO, las caras que dan a la luz grises y el reflejo casi blanco)
        obs = [(0.03, 0.02, 0.04), (0.09, 0.08, 0.11), (0.30, 0.28, 0.34), (0.86, 0.84, 0.92)]
        return {
            'gel':    obs,
            'obsidiana': [(0.04, 0.03, 0.06), (0.10, 0.08, 0.13), (0.26, 0.22, 0.32), (0.75, 0.70, 0.85)],
            'lava':   [c, c, (1.0, 0.86, 0.34)],
            'chispa': [(1.0, 1.0, 1.0)] * 3,
            # LAS CARAS: cada una de un tono (negra, gris humo, violacea), y LA ARISTA clara entre ellas.
            # (el reflejo, gris claro y no blanco: una cara entera de blanco era demasiado)
            # (06/10, su diagnostico: en Expandir, mirando a una direccion, una cara salia GRIS y parpadeaba al estirarse el
            # cuerpo: la luz de las caras, solo un poco mas clara que su base, y SIN reflejo; el brillo, en aristas y chispas)
            'cara1':  [(0.02, 0.02, 0.03), (0.06, 0.05, 0.08), (0.11, 0.10, 0.14)],
            'cara2':  [(0.07, 0.06, 0.09), (0.14, 0.13, 0.17), (0.20, 0.19, 0.24)],
            'cara3':  [(0.05, 0.03, 0.08), (0.10, 0.08, 0.15), (0.16, 0.13, 0.22)],
            # (las aristas en sombra casi no se ven; solo brillan las que dan a la luz)
            'arista': [(0.10, 0.09, 0.13), (0.26, 0.25, 0.31), (0.88, 0.86, 0.96)],
            'ojo':    [(1.0, 0.99, 0.92)] * 3,
            'gema':   [(1.0, 0.95, 0.72)] * 3,
            'parpado': obs[:3],
            'pestana': [(0.02, 0.01, 0.03)] * 3,
            # (transformandose: la CENIZA gris que se le cae a placas)
            'antes':  [(0.26, 0.24, 0.24), (0.40, 0.38, 0.37), (0.55, 0.53, 0.51), (0.62, 0.60, 0.58)],
        }
    # La corona del Rey, de su gel mas claro.
    orn = [cla(c, 0.05), cla(c, 0.28), cla(c, 0.5), cla(c, 0.85)]
    return {'gel': gel, 'cuerno': orn, 'lava': gel, 'ojo': [(1.0, 0.97, 0.72)] * 3, 'gema': [(1.0, 0.95, 0.72)] * 3,
            # EL NUCLEO (oscuro y denso) y EL CRISTAL (el cian de los del juego), que se ven a traves del gel.
            # SUTILES (05/10: "se ven muy cargados, que sean mucho mas sutiles"): el nucleo, solo algo mas oscuro que el gel.
            'nucleo': [osc(c, 0.62), osc(c, 0.48), osc(c, 0.30)],
            'cristal': [(0.30, 0.72, 0.85), (0.55, 0.95, 1.0), (0.85, 1.0, 1.0), (1.0, 1.0, 1.0)],
            # EL PARPADO (el gel que tapa el ojo al parpadear, opaco) y LA RAYA del ojo cerrado.
            'parpado': [osc(c, 0.12), c, cla(c, 0.12)],
            'pestana': [osc(c, 0.62)] * 3,
            # LA COSTRA (2a evolucion): gel cuajado y opaco alrededor de donde le sale una pua.
            'costra': [osc(c, 0.55), osc(c, 0.38), osc(c, 0.18)],
            # LA AMPOLLA (mutantes del venenoso): el borde de los poros y las burbujas, verde amarillento claro y opaco.
            'ampolla': [osc((0.74, 0.95, 0.36), 0.22), (0.74, 0.95, 0.36), cla((0.74, 0.95, 0.36), 0.35),
                        cla((0.74, 0.95, 0.36), 0.75)]}


LIENZO, PIES = _lienzo(ESCALA)
BORDE = (0.16, 0.03, 0.05) if ROCA else osc(hexc(COLOR), 0.58)
MODELO = Modelo(ESCALA, LIENZO, PIES, _materiales(FORMA, COLOR), BORDE, suaves=('cuerpo',),
                brillan=('ojo', 'gema') + (('lava', 'chispa') if ROCA else ()), corta_suelo=True,
                especular=('gel', 'cuerno', 'cristal', 'ampolla'), umbral_especular=0.955,
                # EL GEL SE TRANSPARENTA (05/10): todo menos los ojos y las gemas, que son solidos. El de LAVA no: es roca.
                translucidos=() if ROCA else ('gel', 'cuerno'), alfa=0.72)
MODELO.alfa_dentro = 0.42
# Lo que brilla dentro (el cristal, el nucleo): el gel casi no lo tapa. Mezclados al 42 % salian GRISES (cian + rojo).
MODELO.claros_dentro = ('cristal', 'nucleo')
# PARPADEAN (05/10): el horno saca ademas <anim>_parpado.png, solo los ojos cerrados (el juego los pone a ratos).
# De momento el normal y sus evoluciones; "lo aplicaremos a los demas slimes tambien" (mas adelante).
PARPADOS = VAR in ('s100', 'mut120', 'evo2', 'pun120', 'mia138', 'pes152', 'cen192', 'obs211')
if FORMA == 'obsidiana':
    MODELO.especular = MODELO.especular + ('obsidiana',)
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
    #   evo        0..1: la TRANSFORMACION de normal a brotado (0 = aun es el normal, de su tamaño; 1 = brotado entero)
    #   cerrados   los ojos CERRADOS (solo para sacar la hoja de los parpados, ver PARPADOS)
    #   evo2       0..1: la TRANSFORMACION de brotado a 2a evolucion (0 = aun es el brotado; 1 = con todas las puas)
    #   puas       largo de las puas de la 2a (1 = las suyas; al LANZARLAS se le van y le vuelven a crecer)
    #   poros      tamaño de los poros del miasma/pestilente (aspirando se le cierran; exhalando se le abren de golpe)
    #   burb       tamaño de las burbujas del pestilente (al SOLTARLAS se le hinchan, se le van y le vuelven a salir)
    #   (en el MIASMA, 'evo' = le salen los poros viniendo del venenoso; en el PESTILENTE, las burbujas viniendo del miasma)
    #   (en el BROTADO PUNZANTE, 'evo' = le brotan las yemas viniendo del punzante; en el PUNZANTE, sus puas viniendo del normal)
    p = dict(squash=1.0, derretido=0.0, bote=0.0, avance=0.0, encoge=1.0, yemas=1.0, evo=1.0, cerrados=False, evo2=1.0,
             puas=1.0, poros=1.0, burb=1.0)
    p.update(k)
    return p


BOTE = 3.1
LUNGE = 5.5          # (el viejo, 8: mi slime es algo mayor y al sur se salia del lienzo por abajo)
ENCAJE_RETRO = 3.4


def _paso(x, a, b):
    """0 antes de 'a', 1 despues de 'b', suave entre medias."""
    u = min(1.0, max(0.0, (x - a) / max(b - a, 1e-6)))
    return u * u * (3 - 2 * u)


def _en(p):
    """El tamaño entero de esta pose: el 'encoge' y, transformandose, el del normal (1/1,2) creciendo al del brotado."""
    en = p.get('encoge', 1.0)
    if FORMA in ('brotado', 'punzante'):
        en *= 1.0 / 1.2 + (1.0 - 1.0 / 1.2) * _paso(p.get('evo', 1.0), 0.2, 0.6)
    elif FORMA in ('miasma', 'ceniza'):
        en *= 1.0 / 1.2 + (1.0 - 1.0 / 1.2) * _paso(p.get('evo', 1.0), 0.2, 0.6)
    elif FORMA == 'obsidiana':
        en *= 1.0 / 1.1 + (1.0 - 1.0 / 1.1) * _paso(p.get('evo', 1.0), 0.15, 0.55)
    elif FORMA == 'pestilente':
        en *= 1.0 / 1.1 + (1.0 - 1.0 / 1.1) * _paso(p.get('evo', 1.0), 0.15, 0.55)
    elif FORMA == 'puas':
        # (transformandose desde el brotado o desde el punzante, empieza del tamaño de ellos: el brotado punzante es x1,1)
        g = min(p.get('evo', 1.0), p.get('evo2', 1.0))
        en *= 1.0 / 1.1 + (1.0 - 1.0 / 1.1) * _paso(g, 0.15, 0.55)
    return en


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
    en = _en(p)
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
    if FORMA == 'obsidiana':
        # TALLADA (su referencia, 06/10: "full de obsidiana", sin lava): un poliedro de caras planas recortado por un
        # elipsoide algo mayor (que no salgan picos). Cada cara sale de un tono.
        for k in range(3):
            add(lambda P, k=k: _sd_cara(P, C, R, k), 'cara%d' % (k + 1), 0)
        add(lambda P: _sd_arista(P, C, R), 'arista', 0, 'arista')
    else:
        add(lambda P: sd_elipsoide(P, C, R), 'gel', 0)
    # SIN CHARCO NI GOTAS (05/10, lo dijo el jefe): la baba del suelo la deja el juego por donde pasa
    # (Enemy._actualizar_rastro); pintada en el sprite iria pegada al slime. (Al MORIR si: el charco es el.)
    if ROCA and FORMA == 'obsidiana':
        if pose['evo'] < 0.99:
            _costra_de_antes(e, C, R, pose)
        _agujas(e, C, R, pose)
        _destellos(e, C, R, pose)
    elif ROCA:
        # LA JUNTA: una capa un pelo por fuera del cuerpo, solo donde la placa se acaba: por ahi asoma la lava. La ceniza,
        # con grietas mas anchas (la brasa asoma mas; transformandose, del fuego a la ceniza, se le van cerrando).
        ancho, sobra = (22.0, 0.75) if FORMA == 'lava' else ((20.0, 0.8) if FORMA == 'obsidiana' else (17.0, 0.75))
        if FORMA == 'ceniza':
            ancho = 13.0 + 4.0 * _paso(pose['evo'], 0.3, 0.8)
        def junta(P, ancho=ancho, sobra=sobra):
            cuerpo = sd_elipsoide(P, C, R + 0.18)
            return np.maximum(cuerpo, _junta(P, C, R) * ancho - sobra)
        add(junta, 'lava', 0, 'junta')
        if FORMA in ('ceniza', 'obsidiana') and pose['evo'] < 0.99:
            _costra_de_antes(e, C, R, pose)
        if FORMA == 'ceniza':
            _ceniza(e, C, R, pose)
        if FORMA == 'obsidiana':
            _agujas(e, C, R, pose)
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
        if BROTADO:
            _brotes(e, C, R, sz, pose)
        if FORMA in ('puas', 'punzante'):
            _puas(e, C, R, pose)
        if TOXICO:
            _piel_toxica(e, C, R, sz, pose)
        # LOS CUERNOS: cortos y PUNTIAGUDOS, arriba a los lados, del MISMO gel y fundidos con la cupula (la referencia).
        for s in (-1, 1):
            base, n = _superficie((0.70 * s, 0.05, 0.72), C, R)
            raiz = base - n * 2.0
            en = _en(pose)
            medio = base + n * 2.6 * en + np.array([0.6 * s * en, 0.0, 3.0 * sz * en])
            punta = medio + np.array([-0.6 * s * en, 0.0, 3.6 * sz * en])
            # (derritiendose, los cuernos se funden con el charco)
            fu = (1.0 - 0.85 * pose['derretido']) * en
            # (los de roca, transformandose: el cuerno es aun del aspecto de antes hasta media transformacion)
            mc = 'antes' if FORMA in ('ceniza', 'obsidiana') and pose['evo'] < 0.55 else 'gel'
            add(lambda P, a=raiz, b=medio, fu=fu: sd_cono(P, a, b, 4.4 * fu, 2.4 * fu), mc, 1.8)
            add(lambda P, a=medio, b=punta, fu=fu: sd_cono(P, a, b, 2.4 * fu, 0.9 * fu), mc, 1.0)
    # LOS OJOS: dos OVALOS VERTICALES amarillo palido EN EL FRENTE, a media altura, que asoman de la cara. El brotado
    # lleva dos mas, pequeños y descolocados.
    en = _en(pose)
    ojos = [(-0.33, 0.88, 0.34, 1.0), (0.33, 0.88, 0.34, 1.0)]
    if BROTADO:
        # (transformandose, se le abren al final)
        ab = _paso(pose['evo'], 0.70, 0.85)
        ojos += [(-0.55, 0.75, 0.55, 0.62 * ab), (0.08, 0.93, 0.62, 0.5 * ab)]
    for x, y, z, k in ojos:
        if k < 0.05:
            continue
        base, n = _superficie_tallada((x, y, z), C, R) if FORMA == 'obsidiana' else _superficie((x, y, z), C, R)
        c = base + n * 0.05
        # RECORTADO CONTRA LA BOLA: alto como es, su punta de arriba asomaba por la coronilla al mirar de espaldas. Y
        # aplastado con ella (derretido, se hunde en el charco).
        rad = np.array([2.3 * k * en, 3.0 * k * en, 5.0 * min(1.0, sz * 1.1) * k * en])
        if pose['cerrados']:
            # CERRADO: el gel tapa el ojo (el parpado) y queda una RAYA oscura de lado a lado, por encima.
            add(lambda P, c=c, rad=rad: np.maximum(sd_elipsoide(P, c, rad), sd_elipsoide(P, C, R) - 0.3), 'parpado', 0,
                'ojo')
            raya = np.array([rad[0] * 1.05, rad[1] * 1.05, max(0.45, rad[2] * 0.14)])
            add(lambda P, c=c, raya=raya: np.maximum(sd_elipsoide(P, c, raya), sd_elipsoide(P, C, R) - 0.42), 'pestana',
                0, 'pestana')
        else:
            # (la obsidiana tallada sobresale de la bola: sus ojos asoman un poco mas)
            if FORMA == 'obsidiana':
                add(lambda P, c=c, rad=rad: np.maximum(sd_elipsoide(P, c, rad), _sd_tallado(P, C, R) - 0.3), 'ojo', 0, 'ojo')
            else:
                add(lambda P, c=c, rad=rad: np.maximum(sd_elipsoide(P, c, rad), sd_elipsoide(P, C, R) - 0.3), 'ojo', 0,
                    'ojo')
    if CON_NUCLEO:
        # EL NUCLEO, algo bajo y atras (que no tape los ojos de frente).
        # (el venenoso no lleva nucleo: al miasma le aparece al transformarse)
        rn = 3.4 * en * (_paso(pose['evo'], 0.2, 0.55) if FORMA == 'miasma' else 1.0)
        if rn > 0.2:
            add(lambda P, c=C + np.array([0.0, -2.5, -1.5]) * en, r=rn: sd_esfera(P, c, r), 'nucleo', 0, 'nucleo')
        # Y LOS CRISTALES: uno en el normal; en el brotado, los que se ha comido (transformandose, el primero ya estaba y
        # los demas aparecen); en la 2a evolucion ninguno dentro: le han salido por fuera.
        if FORMA == 'brotado':
            cris = [(c, eje, l, r * (1.0 if i == 0 else _paso(pose['evo'], 0.25, 0.6)))
                    for i, (c, eje, l, r) in enumerate(_CRISTALES_BROTADO)]
        elif FORMA == 'puas':
            # Transformandose, los que llevaba DENTRO se le van (le salen por fuera como puas, ver _puas).
            se_van = 1.0 - _paso(pose['evo2'], 0.30, 0.75)
            cris = [(c, eje, l, r * se_van) for (c, eje, l, r) in _CRISTALES_BROTADO]
        elif FORMA == 'normal':
            cris = [((5.0, -1.0, 2.5), (0.5, 0.2, 1.0), 6.0, 1.7)]
        elif TOXICO:
            # Dos cristales comidos, pequeños (el venenoso no lleva: le aparecen al transformarse en el miasma).
            sale = _paso(pose['evo'], 0.25, 0.6) if FORMA == 'miasma' else 1.0
            cris = [((5.0, -1.0, 2.5), (0.5, 0.2, 1.0), 6.0, 2.0 * sale),
                    ((-5.0, -3.5, 0.5), (-0.4, 0.3, 1.0), 5.3, 1.7 * sale)]
        elif FORMA == 'punzante':
            # El cristal que llevaba el normal se le va al transformarse (le sale por fuera, como sus puas).
            cris = [((5.0, -1.0, 2.5), (0.5, 0.2, 1.0), 6.0, 1.7 * (1.0 - _paso(pose['evo'], 0.30, 0.60)))]
        else:
            cris = []
        for c, eje, largo, radio in cris:
            if radio > 0.05:
                _cristal(e, C + np.array(c) * en, eje, largo * en * 0.75, radio * en * 0.65)
    return e.L


# LAS PUAS de la 2a evolucion: los cristales que llevaba dentro le atraviesan la piel por donde no hay yemas (lomo,
# entre los cuernos, costados de atras), cada una con una COSTRA de gel cuajado donde sale.
_PUAS = [((0.0, -0.20, 0.98), 11.0, 2.6), ((0.45, -0.62, 0.62), 9.0, 2.2), ((-0.20, -0.75, 0.60), 9.0, 2.2),
         ((-0.88, 0.05, 0.40), 6.5, 1.8), ((0.55, 0.20, 0.80), 7.0, 1.9), ((-0.30, -0.95, 0.05), 7.0, 1.9)]

def _puas(e, C, R, pose):
    en = _en(pose)
    for i, (d, largo, radio) in enumerate(_PUAS):
        # Transformandose, le salen UNA A UNA (el punzante viniendo del normal, el brotado punzante viniendo del brotado);
        # lanzandolas, se le van (y le vuelven a crecer); EXPANDIENDOLAS, se le alargan.
        g = pose['evo'] if FORMA == 'punzante' else pose['evo2']
        sale = _paso(g, 0.35 + i * 0.07, 0.50 + i * 0.07) * pose['puas']
        if sale < 0.05:
            continue
        base, n = _superficie(d, C, R)
        l = largo * 1.25 * en * sale
        c = base + n * (l * 0.26)
        _cristal(e, c, tuple(n), l, radio * en * min(1.0, 0.4 + sale) * (1.0 if sale <= 1.0 else 1.0 / sale ** 0.3))
        # La costra sale con su pua (y se queda aunque la lance: es por donde le sale).
        cs = _paso(g, 0.35 + i * 0.07, 0.45 + i * 0.07)
        if cs > 0.05:
            e.add(lambda P, b=base, r=radio * 1.25 * en * cs: sd_esfera(P, b, r), 'costra', 0, 'costra')


# LA PIEL DE LOS MUTANTES DEL VENENOSO: POROS abiertos (un borde claro con su agujero) por donde le sale el gas, y en
# el pestilente ademas BURBUJITAS a medio salir. Todo sale de la bola de esta pose (se aplasta y bota con ella).
_POROS = [((0.80, -0.30, 0.35), 2.1), ((-0.75, -0.40, 0.30), 1.9), ((0.40, -0.75, 0.45), 1.8), ((-0.30, -0.85, 0.15), 2.0)]
_BURBUJAS = [((0.88, 0.25, -0.05), 2.4), ((-0.55, -0.15, 0.80), 2.0), ((0.15, -0.95, 0.30), 2.6),
             ((-0.90, 0.20, 0.05), 1.8), ((0.55, -0.40, 0.72), 1.7)]


def _piel_toxica(e, C, R, sz, pose):
    en = _en(pose)
    fu = (1.0 - pose['derretido']) * (0.55 + 0.45 * min(1.0, sz)) * en
    for i, (d, r) in enumerate(_POROS):
        # (transformandose en miasma, se le abren uno a uno)
        sale = _paso(pose['evo'], 0.30 + i * 0.08, 0.45 + i * 0.08) if FORMA == 'miasma' else 1.0
        r = r * fu * sale * pose['poros']
        if r < 0.25:
            continue
        base, n = _superficie(d, C, R)
        c = base + n * r * 0.2
        e.add(lambda P, c=c, r=r, n=n: np.maximum(sd_esfera(P, c, r), -sd_esfera(P, c + n * r * 0.95, r * 0.55)),
              'ampolla', 0.5)
    if FORMA != 'pestilente':
        return
    for i, (d, r) in enumerate(_BURBUJAS):
        # (transformandose en pestilente, le brotan una a una, con un pelin de rebote)
        sale = _paso(pose['evo'], 0.30 + i * 0.08, 0.42 + i * 0.08)
        r = r * fu * sale * (1.0 + 0.25 * math.sin(math.pi * sale)) * pose['burb']
        if r < 0.25:
            continue
        base, n = _superficie(d, C, R)
        e.add(lambda P, c=base + n * r * 0.35, r=r: sd_esfera(P, c, r), 'ampolla', 0.5)


# EL CUERPO TALLADO DE LA OBSIDIANA: las normales de sus caras (fijas, repartidas por la esfera) y la distancia.
_CARAS = (lambda n: np.array([[math.cos(2.399963 * i) * math.sqrt(1 - (1 - 2 * (i + 0.5) / n) ** 2),
                               math.sin(2.399963 * i) * math.sqrt(1 - (1 - 2 * (i + 0.5) / n) ** 2),
                               1 - 2 * (i + 0.5) / n] for i in range(n)]))(13)
_CARAS = _CARAS + np.random.default_rng(5).normal(0.0, 0.10, _CARAS.shape)
_CARAS /= np.linalg.norm(_CARAS, axis=1, keepdims=True)
_TONO_CARA = np.random.default_rng(9).permutation(np.arange(len(_CARAS)) % 3)
_REDONDEO = 1.22     # (con poco, el elipsoide se comia las esquinas y salia redondo)

def _tallado(P, C, R):
    q = (P - C) / R
    pr = q @ _CARAS.T
    d = np.maximum((pr.max(axis=1) - 1.0) * R.min(), sd_elipsoide(P, C, R * _REDONDEO))
    return d, pr

def _sd_tallado(P, C, R):
    return _tallado(P, C, R)[0]

# Cada cara de su tono: la pieza 'k' es el cuerpo donde manda una cara de ese tono (donde no, un poco mas lejos: gana
# la de su tono y el trazado no se salta nada).
def _sd_cara(P, C, R, k):
    d, pr = _tallado(P, C, R)
    mia = _TONO_CARA[np.argmax(pr, axis=1)] == k
    return np.where(mia, d, d + 0.4)

# LA ARISTA: donde dos caras casi empatan (el canto entre ellas), una raya clara un pelo por fuera.
def _sd_arista(P, C, R):
    d, pr = _tallado(P, C, R)
    o = np.sort(pr, axis=1)
    hueco = (o[:, -1] - o[:, -2]) * R.min()
    return np.maximum(d - 0.06, hueco - 0.32)


# Donde la superficie TALLADA corta la direccion 'd' desde el centro (los ojos van ahi, no en la bola de dentro).
def _superficie_tallada(d, C, R):
    d = np.array(d, dtype=float); d /= np.linalg.norm(d)
    a, b = 0.0, float(R.max()) * 1.5
    for _ in range(30):
        m = (a + b) * 0.5
        if _sd_tallado((C + d * m)[None, :], C, R)[0] < 0.0:
            a = m
        else:
            b = m
    return C + d * a, d


# LOS DESTELLOS de la obsidiana (su referencia: chispas de estrella sobre las caras): motas blancas en unas pocas caras.
_DESTELLOS = [((-0.55, 0.45, 0.60), 0.55), ((0.30, 0.20, 0.85), 0.45), ((0.70, 0.55, 0.15), 0.5), ((-0.20, -0.40, 0.80), 0.4)]

def _destellos(e, C, R, pose):
    fu = (1.0 - pose['derretido']) * _en(pose) * _paso(pose['evo'], 0.6, 0.9)
    for d, r in _DESTELLOS:
        if r * fu < 0.2:
            continue
        base, n = _superficie(d, C, R * 1.04)
        e.add(lambda P, c=base, r=r * fu: sd_esfera(P, c, r), 'chispa', 0, 'destello')


# LA TRANSFORMACION DE LOS DE ROCA: el material no puede cambiar a mitad de animacion, asi que el aspecto de ANTES (la
# roca roja del de fuego sobre la ceniza; la ceniza gris sobre la obsidiana) va como una COSTRA un pelo por fuera, PLACA A
# PLACA (las celdas de las juntas), y cada placa se le cae en su momento entre evo 0,25 y 0,85. Por las juntas asoma lo
# de dentro. (Donde la placa ya se cayo, la costra devuelve su distancia +0,5: gana el cuerpo de dentro y el trazado no
# se salta nada.)
_ORDEN_PLACAS = np.random.default_rng(31).permutation(len(_SEMILLAS)) / float(len(_SEMILLAS))

def _costra_de_antes(e, C, R, pose):
    g = pose['evo']
    # (con un hueco en cada ojo: la costra los tapaba)
    # (un TUNEL desde el centro hacia cada ojo: la costra de la obsidiana va bastante por fuera de la bola)
    ejes = [_superficie((x, 0.88, 0.34), C, R)[1] for x in (-0.33, 0.33)]
    r_ojo = 3.4 * _en(pose)
    def costra(P, C=C, R=R, g=g):
        d = sd_elipsoide(P, C, R * (_REDONDEO + 0.02 if FORMA == 'obsidiana' else 1.0) + 0.32)
        d = np.maximum(d, 0.75 - _junta(P, C, R) * 22.0)
        for ej in ejes:
            v = P - C
            lado = np.linalg.norm(v - np.outer(v @ ej, ej), axis=1)
            d = np.maximum(d, np.where(v @ ej > 0.0, r_ojo - lado, -1e3))
        q = (P - C) / R
        q /= np.maximum(np.linalg.norm(q, axis=1, keepdims=True), 1e-6)
        celda = np.argmin(np.linalg.norm(q[:, None, :] - _SEMILLAS[None, :, :], axis=2), axis=1)
        sigue = (0.25 + 0.6 * _ORDEN_PLACAS[celda]) > g
        return np.where(sigue, d, d + 0.5)
    e.add(costra, 'antes', 0, 'costra_antes')


# LA CENIZA Y BRASA: LASCAS de costra despegadas y ladeadas (a medio caerse) y BRASAS sueltas que asoman. Transformandose
# (del fuego a la ceniza), le salen una a una.
_LASCAS = [((0.75, -0.40, 0.50), 5.5), ((-0.70, -0.30, 0.60), 5.0), ((0.10, -0.85, 0.50), 4.8), ((0.88, 0.20, 0.05), 4.2)]
_BRASAS = [((0.45, -0.55, 0.70), 1.3), ((-0.55, -0.20, 0.80), 1.1), ((0.80, 0.10, 0.45), 1.0), ((-0.20, -0.85, 0.40), 1.2),
           ((-0.80, 0.30, 0.20), 0.9)]

def _ceniza(e, C, R, pose):
    en = _en(pose)
    fu = (1.0 - pose['derretido']) * en
    for i, (d, tam) in enumerate(_LASCAS):
        sale = _paso(pose['evo'], 0.40 + i * 0.08, 0.55 + i * 0.08)
        t = tam * fu * sale
        if t < 0.4:
            continue
        base, n = _superficie(d, C, R)
        n = n + np.array([0.35, 0.0, 0.3]); n /= np.linalg.norm(n)
        c = base + n * 2.2 * sale + np.array([0, 0, -0.6])
        e.add(lambda P, c=c, t=t, n=n: np.maximum(sd_esfera(P, c, t), np.abs((P - c) @ n) - 0.7 * en), 'gel', 0, 'lasca')
    for i, (d, r) in enumerate(_BRASAS):
        r = r * fu * _paso(pose['evo'], 0.30 + i * 0.06, 0.45 + i * 0.06)
        if r < 0.25:
            continue
        base, n = _superficie(d, C, R)
        e.add(lambda P, c=base + n * 0.2, r=r: sd_esfera(P, c, r), 'chispa', 0, 'brasa')


# LA OBSIDIANA: AGUJAS de cristal volcanico que le salen del lomo y los costados (sin tapar la cara). Transformandose
# (de la ceniza a la obsidiana), le salen una a una; 'puas' las alarga (erizar/expandir: el Estallido de agujas; afilar).
_AGUJAS = [((0.0, -0.30, 0.95), 13.0, 2.6), ((0.55, -0.55, 0.62), 10.0, 2.2), ((-0.50, -0.60, 0.62), 11.0, 2.3),
           ((0.85, -0.10, 0.35), 8.0, 1.8), ((-0.88, -0.05, 0.30), 7.5, 1.8), ((0.20, -0.90, 0.30), 8.5, 2.0),
           ((-0.30, -0.80, 0.45), 6.5, 1.6)]

def _agujas(e, C, R, pose):
    en = _en(pose)
    fu = (1.0 - pose['derretido']) * en
    for i, (d, largo, radio) in enumerate(_AGUJAS):
        sale = _paso(pose['evo'], 0.35 + i * 0.07, 0.50 + i * 0.07) * pose['puas']
        if sale < 0.05:
            continue
        base, n = _superficie(d, C, R)
        eje = n + np.array([0.0, 0.0, 0.25]); eje /= np.linalg.norm(eje)
        l = largo * fu * sale
        rr = radio * fu * min(1.0, 0.4 + sale) * (1.0 if sale <= 1.0 else 1.0 / sale ** 0.3)
        a = base - eje * l * 0.25; b = base + eje * l * 0.75; m = base + eje * l * 0.1
        e.add(lambda P, a=a, m=m, b=b, rr=rr: np.minimum(sd_cono(P, a, m, 0.3, rr), sd_cono(P, m, b, rr, 0.2)),
              'obsidiana', 0, 'aguja')


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
          (-0.45, 0.10, 0.85, 3.8, True), (0.70, 0.40, 0.05, 3.6, False)]


def _brotes(e, C, R, sz, pose):
    en = _en(pose); ye = pose['yemas']; fu = 1.0 - 0.85 * pose['derretido']
    if ye > 0.05:
        for i, (x, y, z, r, ojo) in enumerate(_YEMAS):
            # Transformandose, las yemas le brotan UNA A UNA (con un pelin de rebote al salir).
            sale = _paso(pose['evo'], 0.30 + i * 0.07, 0.42 + i * 0.07)
            # (y se aplastan con el cuerpo: aplastado a lo ancho, sin esto las yemas se salian del lienzo)
            r = r * en * ye * sale * (1.0 + 0.25 * math.sin(math.pi * sale)) * (0.55 + 0.45 * min(1.0, sz))
            if r < 0.3:
                continue
            base, n = _superficie((x, y, z), C, R)
            c = base + n * r * 0.35
            e.add(lambda P, c=c, r=r: sd_esfera(P, c, r), 'gel', 1.6)
            if ojo:
                m = n + np.array([0.0, 0.6, 0.0]); m /= np.linalg.norm(m)
                o = c + m * (r * 0.92)
                ro = np.array([1.1, 1.1, 1.5]) * (r / 4.5)
                if pose['cerrados']:
                    e.add(lambda P, o=o, ro=ro: sd_elipsoide(P, o, ro), 'parpado', 0, 'ojo')
                    e.add(lambda P, o=o, ro=ro: sd_elipsoide(P, o + m * 0.15, np.array([ro[0] * 1.08, ro[1] * 1.08,
                                                                                       max(0.4, ro[2] * 0.2)])),
                          'pestana', 0, 'pestana')
                else:
                    e.add(lambda P, o=o, ro=ro: sd_elipsoide(P, o, ro), 'ojo', 0, 'ojo')
    base, n = _superficie((0.10, -0.45, 0.88), C, R)
    tam = 0.85 * en * _paso(pose['evo'], 0.62, 0.80)   # el tercer cuerno, al final de la transformacion
    if tam < 0.08:
        return
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
    if BROTADO:
        return _muerte_brotado(t)
    if TOXICO:
        return _muerte_revienta(t)
    if FORMA == 'obsidiana':
        return _muerte_obsidiana(t)   # la 2a tambien: mantiene la pasiva (se encoge y salen las crias)
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


# COMER UN CRISTAL (05/10): se estira hacia delante y bajo, el gel se le echa encima, lo engulle de un trago y se
# asienta. 12 marcos a 10 = 1,2 s (ComerCristales.COMER_DUR). AQUI NO SE DIBUJA NINGUN CRISTAL: el que se come es el DEL
# SUELO, el de verdad ("se tiene que comer literalmente el sprite del cristal que haya en el suelo"), y lo mueve el juego
# (ComerCristales.tragar_visual) al ritmo de estas claves: lo engulle entre 0,25 y 0,55 y se le deshace hasta 0,9.
def anim_comer(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.18, 0.84), (0.32, 0.70), (0.46, 1.16), (0.60, 0.90), (0.76, 1.05),
                             (1.0, 1.0)]),
                avance=T(t, [(0.0, 0.0), (0.18, 1.6), (0.32, 2.6), (0.46, 0.8), (0.60, 0.2), (1.0, 0.0)]),
                bote=T(t, [(0.0, 0.0), (0.40, 0.0), (0.46, 0.20), (0.60, 0.0), (1.0, 0.0)]))


# LA TRANSFORMACION de normal a brotado (05/10): tiembla, se hincha, le brotan las yemas una a una, le sale el tercer
# cuerno, se le abren los ojos de mas y se asienta. 18 marcos a 10 = 1,8 s (ComerCristales.TRANSFORMACION_DUR).
def anim_evolucion(t):
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.25, 0.32))
    return POSE(squash=T(t, [(0.0, 1.0), (0.30, 1.0), (0.40, 1.24), (0.55, 1.08), (0.70, 1.18), (0.82, 0.84),
                             (0.92, 1.04), (1.0, 1.0)]) + 0.06 * tiembla * (t < 0.32),
                bote=T(t, [(0.0, 0.0), (0.38, 0.0), (0.45, 0.35), (0.55, 0.0), (0.70, 0.25), (0.82, 0.0), (1.0, 0.0)]),
                evo=T(t, [(0.0, 0.0), (0.12, 0.0), (0.88, 1.0), (1.0, 1.0)]))


# LA TRANSFORMACION de brotado a 2a evolucion (06/10): se APRIETA temblando, los cristales de dentro se le van y le
# salen por fuera como PUAS una a una (cada una con su costra), crece un poco y se sacude. 18 marcos a 10 = 1,8 s.
def anim_evolucion2(t):
    tiembla = (1.0 if int(t * 16) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.30, 0.36))
    return POSE(squash=T(t, [(0.0, 1.0), (0.12, 0.86), (0.34, 0.80), (0.45, 1.18), (0.60, 0.95), (0.74, 1.12),
                             (0.86, 0.90), (1.0, 1.0)]) + 0.05 * tiembla * (t < 0.36),
                bote=T(t, [(0.0, 0.0), (0.40, 0.0), (0.47, 0.30), (0.58, 0.0), (0.74, 0.20), (0.86, 0.0), (1.0, 0.0)]),
                evo2=T(t, [(0.0, 0.0), (0.10, 0.0), (0.90, 1.0), (1.0, 1.0)]))


# LANZAR PUAS (06/10, su pasiva: "con una probabilidad, al golpearlo lanza puas a los que tiene cerca"): se contrae, las
# puas se le alargan un instante y SALEN (las que vuelan las pone el juego como efecto) y le vuelven a crecer.
# 8 marcos a 12.
def anim_lanzar_puas(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.18, 0.80), (0.32, 1.20), (0.50, 0.94), (0.72, 1.04), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.28, 0.0), (0.34, 0.25), (0.50, 0.0), (1.0, 0.0)]),
                puas=T(t, [(0.0, 1.0), (0.18, 1.15), (0.30, 1.25), (0.34, 0.0), (0.55, 0.15), (0.85, 0.85), (1.0, 1.0)]))


# LA TRANSFORMACION de normal a PUNZANTE (06/10): tiembla, se hincha, el cristal de dentro se le va y le salen las puas
# una a una con su costra. 18 marcos a 10 = 1,8 s, como la del brotado.
def anim_evolucion_punzante(t):
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.25, 0.32))
    return POSE(squash=T(t, [(0.0, 1.0), (0.30, 1.0), (0.40, 0.82), (0.52, 1.20), (0.66, 0.92), (0.80, 1.10),
                             (0.90, 0.95), (1.0, 1.0)]) + 0.06 * tiembla * (t < 0.32),
                bote=T(t, [(0.0, 0.0), (0.46, 0.0), (0.52, 0.35), (0.64, 0.0), (0.80, 0.2), (0.90, 0.0), (1.0, 0.0)]),
                evo=T(t, [(0.0, 0.0), (0.12, 0.0), (0.88, 1.0), (1.0, 1.0)]))


# LA TRANSFORMACION de punzante a BROTADO PUNZANTE (06/10): ya tiene las puas; se hincha, le brotan las yemas una a una,
# el tercer cuerno y los ojos de mas, y crece un poco. Va en la hoja del brotado punzante, como la que viene del brotado.
def anim_evolucion_desde_punzante(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.25, 0.90), (0.40, 1.24), (0.55, 1.08), (0.70, 1.18), (0.82, 0.84),
                             (0.92, 1.04), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.38, 0.0), (0.45, 0.35), (0.55, 0.0), (0.70, 0.25), (0.82, 0.0), (1.0, 0.0)]),
                evo=T(t, [(0.0, 0.0), (0.12, 0.0), (0.88, 1.0), (1.0, 1.0)]))


# EXPANDIR PUAS (06/10, el ataque propio del punzante y del brotado punzante): carga de un turno y golpe en circulo
# alrededor suyo. ERIZAR = la carga, en bucle: se encoge apretado y tiembla con las puas recogidas. EXPANDIR = el golpe:
# se hincha de golpe y las puas le salen LARGAS hacia fuera, y se le vuelven a recoger.
def anim_erizar(t):
    tiembla = 1.0 if int(round(t * 8)) % 2 == 0 else -1.0
    return POSE(squash=0.84 + 0.04 * tiembla, puas=0.75 + 0.06 * tiembla)


def anim_expandir(t):
    return POSE(squash=T(t, [(0.0, 0.84), (0.20, 0.78), (0.32, 1.22), (0.50, 1.10), (0.72, 0.94), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.28, 0.0), (0.34, 0.30), (0.50, 0.10), (0.65, 0.0), (1.0, 0.0)]),
                # (hasta x1,5: mas largas se salian del lienzo de su hoja)
                puas=T(t, [(0.0, 0.75), (0.20, 0.70), (0.32, 1.50), (0.55, 1.42), (0.80, 1.05), (1.0, 1.0)]))


# ---- LOS MUTANTES DEL VENENOSO (06/10) ----
# REVIENTA AL MORIR (su pasiva: deja una nube de veneno, la pone el juego): se hincha temblando y REVIENTA de golpe en
# un charco (su cadaver, como el del venenoso).
def _muerte_revienta(t):
    tiembla = (1.0 if int(t * 20) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.40, 0.46))
    return POSE(squash=T(t, [(0.0, 1.0), (0.14, 1.12), (0.30, 1.26), (0.44, 1.34), (0.52, 0.62), (0.68, 0.50),
                             (0.84, 0.44), (1.0, 0.42)]) + 0.04 * tiembla * (t < 0.46),
                derretido=T(t, [(0.0, 0.0), (0.44, 0.0), (0.52, 0.55), (0.68, 0.85), (0.84, 0.97), (1.0, 1.0)]),
                poros=T(t, [(0.0, 1.0), (0.30, 1.35), (0.44, 1.5), (0.50, 0.0), (1.0, 0.0)]),
                burb=T(t, [(0.0, 1.0), (0.30, 1.3), (0.44, 1.45), (0.50, 0.0), (1.0, 0.0)]),
                bote=T(t, [(0.0, 0.0), (0.30, 0.2), (0.44, 0.35), (0.52, 0.0), (1.0, 0.0)]))


# LA TRANSFORMACION de venenoso a MIASMA (y de miasma a PESTILENTE): tiembla, se hincha, le salen los poros (o las
# burbujas) uno a uno y crece. 18 marcos a 10 = 1,8 s, como las del slime normal.
def anim_evolucion_toxica(t):
    tiembla = (1.0 if int(t * 14) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.25, 0.32))
    return POSE(squash=T(t, [(0.0, 1.0), (0.30, 1.0), (0.40, 1.22), (0.55, 1.06), (0.70, 1.16), (0.82, 0.86),
                             (0.92, 1.04), (1.0, 1.0)]) + 0.06 * tiembla * (t < 0.32),
                bote=T(t, [(0.0, 0.0), (0.38, 0.0), (0.45, 0.30), (0.55, 0.0), (0.70, 0.22), (0.82, 0.0), (1.0, 0.0)]),
                evo=T(t, [(0.0, 0.0), (0.12, 0.0), (0.88, 1.0), (1.0, 1.0)]))


# EXHALAR MIASMA (su ataque nuevo): ASPIRAR = la carga, en bucle: se llena de gas, hinchado y temblando, con los poros
# apretados. EXHALAR = el golpe: se vacia de golpe por los poros (que se le abren de par en par) y se asienta.
def anim_aspirar(t):
    tiembla = 1.0 if int(round(t * 8)) % 2 == 0 else -1.0
    return POSE(squash=1.18 + 0.04 * tiembla, bote=0.30 + 0.05 * tiembla, poros=0.45)


def anim_exhalar(t):
    return POSE(squash=T(t, [(0.0, 1.18), (0.15, 1.24), (0.30, 0.76), (0.50, 0.86), (0.70, 1.04), (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.30), (0.15, 0.40), (0.30, -0.15), (0.50, 0.0), (1.0, 0.0)]),
                poros=T(t, [(0.0, 0.45), (0.15, 0.40), (0.28, 1.70), (0.55, 1.45), (0.80, 1.05), (1.0, 1.0)]))


# SOLTAR BURBUJAS (el pestilente, sin carga): se sacude, las burbujas de la piel se le hinchan y SE LE VAN (las que
# flotan las pone el juego) y le vuelven a salir.
def anim_soltar_burbujas(t):
    return POSE(squash=T(t, [(0.0, 1.0), (0.15, 0.86), (0.30, 1.16), (0.45, 0.92), (0.60, 1.08), (0.80, 0.97),
                             (1.0, 1.0)]),
                bote=T(t, [(0.0, 0.0), (0.25, 0.0), (0.32, 0.30), (0.45, 0.0), (0.60, 0.12), (0.75, 0.0), (1.0, 0.0)]),
                burb=T(t, [(0.0, 1.0), (0.18, 1.35), (0.30, 1.60), (0.36, 0.0), (0.60, 0.15), (0.90, 0.85), (1.0, 1.0)]))


# ---- LOS MUTANTES DEL SLIME DE FUEGO (06/10) ----
# LA MUERTE DE LA OBSIDIANA: no se derrite (es cristal: derretida salia un charco blanco). Un respingo, tiembla, se le
# PARTEN las agujas y se HUNDE, mas pequeña y algo chafada: ese es su cadaver.
def _muerte_obsidiana(t):
    tiembla = (1.0 if int(t * 22) % 2 == 0 else -1.0) * (1.0 - _paso(t, 0.40, 0.50))
    return POSE(squash=T(t, [(0.0, 1.0), (0.14, 1.10), (0.30, 0.92), (0.50, 0.86), (0.70, 0.80), (1.0, 0.78)])
                + 0.03 * tiembla * (t < 0.5),
                encoge=T(t, [(0.0, 1.0), (0.30, 1.0), (0.60, 0.88), (1.0, 0.84)]),
                puas=T(t, [(0.0, 1.0), (0.30, 1.1), (0.42, 0.35), (0.60, 0.20), (1.0, 0.18)]),
                bote=T(t, [(0.0, 0.0), (0.14, 0.40), (0.30, 0.0), (1.0, 0.0)]))

# LA TRANSFORMACION del fuego a la CENIZA (las grietas se le cierran bajo la ceniza, le salen las lascas y las brasas,
# crece) y de la ceniza a la OBSIDIANA (le salen las agujas una a una, crece): como las del slime normal.
anim_evolucion_roca = anim_evolucion_toxica


# AFILARSE (la obsidiana, sin carga): se frota las placas temblando, las agujas le entran y salen rascandose, y se
# asienta con ellas un poco mas largas.
def anim_afilar(t):
    roce = math.sin(t * math.pi * 6.0)
    return POSE(squash=T(t, [(0.0, 1.0), (0.15, 0.90), (0.75, 0.92), (0.88, 1.08), (1.0, 1.0)]) + 0.02 * roce,
                avance=0.6 * roce * (1.0 - _paso(t, 0.75, 0.85)),
                puas=T(t, [(0.0, 1.0), (0.15, 0.85), (0.75, 0.85), (0.88, 1.18), (1.0, 1.05)]) + 0.06 * roce * (t < 0.75))


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
if BROTADO or FORMA == 'punzante':
    ANIMS = {k: v for k, v in ANIMS.items() if k in ANIMS_BROTADO}
# COMER: todos los enemigos comen cristales, pero de momento solo el slime NORMAL y su brotado la llevan (uno a uno).
# EVOLUCION: la transformacion de normal a brotado vive en la hoja del BROTADO (empieza del tamaño del normal).
# Las del VENENOSO y nada mas (06/10): quieto, andar, embestida (el basico y el Placaje), escupir (Rociada y
# Escupitajo), encajar y morir.
ANIMS_TOXICO = ('idle', 'walk', 'embestida', 'escupir', 'encaje', 'muerte')
if TOXICO:
    ANIMS = {k: v for k, v in ANIMS.items() if k in ANIMS_TOXICO}
    ANIMS['evolucion'] = (18, 10.0, False, 8, anim_evolucion_toxica)
    ANIMS['aspirar'] = (8, 12.0, True, 8, anim_aspirar)
    ANIMS['exhalar'] = (10, 12.0, False, 8, anim_exhalar)
if FORMA == 'pestilente':
    ANIMS['soltar_burbujas'] = (10, 12.0, False, 8, anim_soltar_burbujas)
# LOS DEL DE FUEGO (06/10): la CENIZA, con las del de fuego (Escupitajo de brasas y Sacudida = escupir; Nube de ceniza =
# ignicion de carga y aplaston; Avivar brasas = ignicion); la OBSIDIANA, sin fuego: embestida (Embestida cortante),
# escupir (Esquirlas), erizar/expandir (Estallido de agujas) y afilar (Afilarse). Las dos, comer y su evolucion.
ANIMS_CENIZA = ('idle', 'walk', 'embestida', 'escupir', 'ignicion', 'aplaston', 'encaje', 'muerte')
ANIMS_OBSIDIANA = ('idle', 'walk', 'embestida', 'escupir', 'encaje', 'muerte')
if FORMA == 'ceniza':
    ANIMS = {k: v for k, v in ANIMS.items() if k in ANIMS_CENIZA}
    ANIMS['evolucion'] = (18, 10.0, False, 8, anim_evolucion_roca)
if FORMA == 'obsidiana':
    ANIMS = {k: v for k, v in ANIMS.items() if k in ANIMS_OBSIDIANA}
    ANIMS['evolucion'] = (18, 10.0, False, 8, anim_evolucion_roca)
    ANIMS['erizar'] = (8, 12.0, True, 8, anim_erizar)
    ANIMS['expandir'] = (10, 12.0, False, 8, anim_expandir)
    ANIMS['afilar'] = (12, 12.0, False, 8, anim_afilar)
# (el venenoso tambien come cristales: 06/10, al hacer su arbol)
if VAR in ('s100', 'mut120', 'evo2', 'pun120', 's115', 'mia138', 'pes152', 'lava160', 'cen192', 'obs211'):
    ANIMS['comer'] = (12, 10.0, False, 8, anim_comer)
if VAR == 'pun120':
    ANIMS['evolucion'] = (18, 10.0, False, 8, anim_evolucion_punzante)
    ANIMS['lanzar_puas'] = (8, 12.0, False, 8, anim_lanzar_puas)
if VAR in ('pun120', 'evo2'):
    ANIMS['erizar'] = (8, 12.0, True, 8, anim_erizar)
    ANIMS['expandir'] = (10, 12.0, False, 8, anim_expandir)
if VAR == 'mut120':
    ANIMS['evolucion'] = (18, 10.0, False, 8, anim_evolucion)
if VAR == 'evo2':
    # (se llama 'evolucion' igual que la del brotado: cada hoja lleva la transformacion que lleva HASTA ella)
    ANIMS['evolucion'] = (18, 10.0, False, 8, anim_evolucion2)
    ANIMS['lanzar_puas'] = (8, 12.0, False, 8, anim_lanzar_puas)
    # (y la que viene del PUNZANTE: el brotado punzante se alcanza por los dos lados)
    ANIMS['evolucion_punzante'] = (18, 10.0, False, 8, anim_evolucion_desde_punzante)


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
