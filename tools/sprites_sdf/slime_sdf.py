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
}
VAR = os.environ.get('SLIME_VAR', 's170')
ESCALA, FORMA, COLOR = VARIANTES[VAR]
SALIDA = 'assets/sprites/enemigos/slime_sdf_%s/' % VAR


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
    return {'gel': gel, 'cuerno': orn, 'lava': gel, 'ojo': [(1.0, 0.97, 0.72)] * 3, 'gema': [(1.0, 0.95, 0.72)] * 3}


LIENZO, PIES = _lienzo(ESCALA)
BORDE = (0.16, 0.03, 0.05) if FORMA == 'lava' else osc(hexc(COLOR), 0.58)
MODELO = Modelo(ESCALA, LIENZO, PIES, _materiales(FORMA, COLOR), BORDE, suaves=('cuerpo',),
                brillan=('ojo', 'gema') + (('lava',) if FORMA == 'lava' else ()), corta_suelo=True,
                especular=('gel', 'cuerno'), umbral_especular=0.955,
                # EL GEL SE TRANSPARENTA (05/10): todo menos los ojos y las gemas, que son solidos. El de LAVA no: es roca.
                translucidos=() if FORMA == 'lava' else ('gel', 'cuerno'), alfa=0.72)
MODELO.alfa_dentro = 0.42

# EL CUERPO (05/10, su referencia: una GOMINOLA de gel): una BOLA REDONDITA, solo un poco aplastada, posada. Ni disco (la primera vuelta, con los ojos en la coronilla) ni campana (la segunda llevaba
# una falda ancha fundida abajo: "porque es tan ancho abajo").
# Hundida: el suelo la corta a un tercio, asi apoya con una base ANCHA y blanda (al rozar el suelo con la panza
# redonda se leia como una bola sobre un plato).
CUERPO = np.array([0.0, 0.0, 9.0])
CUERPO_R = np.array([16.5, 16.5, 14.0])


def POSE(**k):
    p = dict(aplasta=0.0, bote=0.0, avance=0.0, ladea=0.0, inclina=0.0, hincha=0.0, hunde=0.0, mira=0.0)
    p.update(k)
    return p


def huesos(p):
    # El cuerpo se APLASTA (+) o se ESTIRA (-) sobre el suelo: escala z y engorda en x/y. Los adornos van con el.
    a = p['aplasta']
    sz = 1.0 - a; sxy = 1.0 + a * 0.5
    M = np.diag([sxy, sxy, sz])
    M = rx(p['inclina']) @ ry(p['ladea']) @ M
    t = np.array([0.0, p['avance'], p['bote'] - p['hunde']])
    return {'raiz': (M, t)}


def _superficie(d):
    """El punto del cuerpo (en reposo) en la direccion 'd' desde su centro."""
    d = np.array(d, dtype=float); d /= np.linalg.norm(d)
    k = 1.0 / math.sqrt(((d / CUERPO_R) ** 2).sum())
    return CUERPO + d * k, d


# LAS JUNTAS DE LAVA: un mosaico de placas sobre la bola (celdas de Voronoi en la esfera unidad); 'junta' es lo que
# falta para el borde entre dos placas.
_rng = np.random.default_rng(7)
_SEMILLAS = _rng.normal(size=(26, 3)); _SEMILLAS /= np.linalg.norm(_SEMILLAS, axis=1, keepdims=True)

def _junta(P):
    q = (P - CUERPO) / CUERPO_R
    q /= np.maximum(np.linalg.norm(q, axis=1, keepdims=True), 1e-6)
    d = np.linalg.norm(q[:, None, :] - _SEMILLAS[None, :, :], axis=2)
    d.sort(axis=1)
    return (d[:, 1] - d[:, 0]) * 0.5


def escena(pose):
    e = Escena(huesos(pose))
    add = e.add
    hin = 1.0 + pose['hincha']
    R = CUERPO_R * np.array([hin, hin, hin])
    add(lambda P: sd_elipsoide(P, CUERPO, R), 'gel', 0)
    # SIN CHARCO NI GOTAS (05/10, lo dijo el jefe): la baba del suelo la deja el juego por donde pasa
    # (Enemy._actualizar_rastro); pintada en el sprite iria pegada al slime.
    if FORMA == 'lava':
        # LA JUNTA: una capa un pelo por fuera del cuerpo, solo donde la placa se acaba: por ahi asoma la lava.
        def junta(P):
            cuerpo = sd_elipsoide(P, CUERPO, R + 0.18)
            return np.maximum(cuerpo, _junta(P) * 22.0 - 0.75)
        add(junta, 'lava', 0, 'junta')
    if FORMA == 'rey':
        # LA CORONA: un aro de cinco puntas de su gel, alrededor de la coronilla, con una GEMA en cada punta.
        for k in range(5):
            a = k / 5.0 * 2 * math.pi + math.pi * 0.5
            base, n = _superficie((math.cos(a) * 0.55, math.sin(a) * 0.55, 0.83))
            base = base - n * 1.0
            punta = base + np.array([math.cos(a) * 0.8, math.sin(a) * 0.8, 7.5])
            add(lambda P, a=base, b=punta: sd_cono(P, a, b, 2.4, 1.3), 'cuerno', 0, 'corona')
            add(lambda P, c=punta + np.array([0, 0, 0.8]): sd_esfera(P, c, 1.35), 'gema', 0, 'gema')
    else:
        # LOS CUERNOS: cortos y PUNTIAGUDOS, arriba a los lados, del MISMO gel y fundidos con la cupula (la referencia).
        for s in (-1, 1):
            base, n = _superficie((0.70 * s, 0.05, 0.72))
            raiz = base - n * 2.0
            medio = base + n * 2.6 + np.array([0.6 * s, 0.0, 3.0])
            punta = medio + np.array([-0.6 * s, 0.0, 3.6])
            add(lambda P, a=raiz, b=medio: sd_cono(P, a, b, 4.4, 2.4), 'gel', 1.8)
            add(lambda P, a=medio, b=punta: sd_cono(P, a, b, 2.4, 0.9), 'gel', 1.0)
    # LOS OJOS: dos OVALOS VERTICALES amarillo palido EN EL FRENTE, a media altura, que asoman de la cara.
    for s in (-1, 1):
        base, n = _superficie((0.33 * s, 0.88, 0.34))
        c = base + n * 0.05
        # RECORTADO CONTRA LA BOLA: alto como es, su punta de arriba asomaba por la coronilla al mirar de espaldas.
        add(lambda P, c=c: np.maximum(sd_elipsoide(P, c, np.array([2.3, 3.0, 5.0])), sd_elipsoide(P, CUERPO, R) - 0.3),
            'ojo', 0, 'ojo')
    return e.L


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
