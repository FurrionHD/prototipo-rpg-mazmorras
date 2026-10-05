# ============================================================
#  aberracion_sdf.py -- la ABERRACION en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (aberracion_sprites.gd): NO TIENE ESQUELETO. Una MASA derramada que se arrastra (bulbo ancho abajo, dos LOBULOS
#  descolocados y una JOROBA trasera: la simetria es de los animales, no de esto; y no puede parecer una bola, que
#  eso ya es el slime), UN OJO enorme alto y delante (globo, iris y pupila que sobresalen: sin eso no hay MIRADA),
#  las FAUCES en hendidura debajo, con dientes, y SEIS TENTACULOS gruesos que caen y se arrastran por el suelo.
#  Morada, con el brillo HUMEDO que tira a rosa lechoso (gris seria piedra).
#  Lienzo y origen de su horneado (1,80 -> 102 x 102, el centro).
#  Uso: python tools/sprites_sdf/aberracion_sdf.py vistas  -> tools/salida/sdf/aberracion_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/aberracion_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Morado (754080). La carne con su brillo HUMEDO (cuarto tono, rosa lechoso); los tentaculos algo mas oscuros con las
# VENTOSAS palidas por debajo.
MAT = {
    'carne':   [(0.30, 0.15, 0.34), (0.46, 0.25, 0.51), (0.58, 0.35, 0.63), (0.86, 0.68, 0.86)],
    'tent':    [(0.24, 0.11, 0.27), (0.36, 0.18, 0.41), (0.48, 0.27, 0.53), (0.80, 0.62, 0.80)],
    'ventosa': [(0.62, 0.45, 0.60), (0.76, 0.58, 0.72), (0.86, 0.70, 0.82)],
    'vena':    [(0.36, 0.10, 0.28), (0.46, 0.14, 0.34), (0.54, 0.20, 0.40)],
    'globo':   [(0.86, 0.82, 0.68), (0.95, 0.92, 0.80), (1.00, 0.98, 0.90), (1.00, 1.00, 1.00)],
    'iris':    [(0.86, 0.52, 0.10), (0.95, 0.64, 0.16), (1.00, 0.78, 0.30)],
    'pupila':  [(0.06, 0.03, 0.05)] * 3,
    'fauces':  [(0.22, 0.04, 0.08), (0.34, 0.07, 0.11), (0.44, 0.10, 0.14)],
    'diente':  [(0.80, 0.76, 0.64), (0.92, 0.89, 0.78), (0.98, 0.96, 0.88)],
}
MODELO = Modelo(1.8, (102, 102), (51, 51), MAT, (0.12, 0.04, 0.12), suaves=('cuerpo',), brillan=('pupila',),
                corta_suelo=True, especular=('carne', 'tent', 'globo'), umbral_especular=0.90)

BULBO = V((0.0, 0.0, 5.6))
OJO = V((0.0, 5.0, 9.4))
BOCA = V((0.0, 6.0, 4.4))
TENTACULOS = 6
TENT_NACE_R = 4.6
TENT_NACE_Z = 4.2
TENT_PASO = 1.15
TENT_SEGMENTOS = 11


def POSE(**k):
    p = dict(avance=0.0, palpita=0.0, boca=0.15, parpado=0.0, onda=0.0, azota=0.0)
    p.update(k)
    return p


def huesos(p):
    X = {}
    X['raiz'] = (np.eye(3), V((0.0, p['avance'], 0.0)))
    return X


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _unit(v):
    return v / np.linalg.norm(v)


def _tentaculo(add, p, i):
    """Por PASOS FIJOS: se avanza TENT_PASO en la direccion actual y despues se gira (asi no se descose). Nace metido
    en el bulbo, cae fuerte y se va aplanando hasta tenderse en el suelo; la punta se enrosca un poco hacia arriba."""
    # Repartidos alrededor, ninguno justo delante (ahi estan el ojo y las fauces) y algo descolocados.
    ang = math.radians(30.0 + 60.0 * i + (7.0, -5.0, 9.0, -8.0, 4.0, -6.0)[i])
    fuera = V((math.sin(ang), math.cos(ang), 0.0))
    lado = V((fuera[1], -fuera[0], 0.0))
    pt = V((0.0, 0.0, TENT_NACE_Z)) + fuera * TENT_NACE_R
    caida = 0.95
    r0, r1 = 2.3, 1.0
    rr = r0
    for k in range(TENT_SEGMENTOS):
        u = k / (TENT_SEGMENTOS - 1)
        # Baja y se aplana hasta tenderse (nunca vuelve a subir: hacia atras, subir es un pincho en pantalla); solo la
        # punta se enrosca un pelo.
        caida = max(0.0, caida - 0.19) if k < TENT_SEGMENTOS - 2 else -0.22
        # Se CURVAN de lado (cada uno hacia un sitio) y ondulan: rectos parecian brazos de estrella de mar.
        enrosca = (0.9, -0.7, 0.8, -0.9, 0.7, -0.8)[i]
        onda = enrosca * u * u + 0.3 * math.sin(k * 0.7 + i * 1.9 + p['onda'] * 2 * math.pi) * u
        d = _unit(fuera * math.cos(caida) + V((0.0, 0.0, -math.sin(caida))) + lado * onda)
        q = pt + d * TENT_PASO
        q[2] = max(q[2], r1 * 0.9 + (rr - r1) * 0.55)
        rb = r0 + (r1 - r0) * min(1.0, (k + 1) / (TENT_SEGMENTOS - 1))
        _cono(add, pt, q, rr, rb, 'tent', 1.2 if k < 2 else 0.5)
        # Las VENTOSAS por la cara de abajo, a partir de medio tentaculo (solo asoman donde se levanta).
        if 3 <= k <= 9 and k % 2 == 1:
            _elip(add, q + lado * 0.0 - V((0.0, 0.0, rb * 0.62)) + fuera * 0.0, (rb * 0.55, rb * 0.55, rb * 0.42),
                  'ventosa', 0, 'ventosa')
        pt = q; rr = rb


def escena(pose):
    p = pose
    e = Escena(huesos(p)); add = e.add
    h = 1.0 + 0.05 * p['palpita']
    # --- LA MASA: bulbo derramado, ancho abajo; dos lobulos DESCOLOCADOS y la joroba alta y trasera.
    _elip(add, BULBO, (7.2 * h, 6.6 * h, 5.4 * h), 'carne', 0)
    _elip(add, (0.0, -0.4, 2.0), (8.0, 7.4, 2.4), 'carne', 2.5)
    _elip(add, (4.4, -3.0, 8.4), (3.8 * h, 4.0 * h, 3.6 * h), 'carne', 2.6)
    _elip(add, (-4.8, 1.6, 7.0), (3.4 * h, 3.6 * h, 3.2 * h), 'carne', 2.6)
    _elip(add, (-0.8, -2.8, 10.6), (4.2 * h, 3.8 * h, 3.2 * h), 'carne', 3.0)
    # Bultos pequeños y VENAS por encima: lo que la saca de ser una bola lisa de gel.
    _elip(add, (2.2, -5.4, 6.2), (1.8, 1.6, 1.6), 'carne', 1.2)
    _elip(add, (-3.6, -4.6, 9.4), (1.5, 1.5, 1.3), 'carne', 1.0)
    for a, b in (((-1.0, -1.0, 13.4), (3.6, -4.6, 11.4)), ((-1.5, -1.5, 13.3), (-5.4, 0.6, 9.8)),
                 ((0.5, -4.0, 12.6), (1.8, -7.6, 7.6))):
        _cono(add, a, b, 0.42, 0.3, 'vena', 0, 'vena')
    # --- EL OJO: enorme, alto y delante. Globo, iris y pupila (rasgada) que SOBRESALEN hacia delante: sin eso, de
    # perfil parece mirar siempre de frente.
    _elip(add, OJO, (3.3, 2.7, 3.2), 'globo', 0, 'ojo')
    _elip(add, OJO + V((0.0, 1.65, 0.05)), (1.9, 1.3, 1.85), 'iris', 0, 'ojo')
    _elip(add, OJO + V((0.0, 2.5, 0.05)), (0.55, 0.6, 1.35), 'pupila', 0, 'ojo')
    # El parpado/cuenca: un rodete de carne alrededor del ojo (lo engasta en la masa; suelto parecia una canica).
    _elip(add, OJO + V((0.0, -1.8, 1.2 + 2.4 * p['parpado'])), (3.7, 2.4, 2.3), 'carne', 1.2)
    # --- LAS FAUCES: hendidura vertical debajo del ojo, con dientes arriba y abajo.
    ab = 0.6 + 2.0 * p['boca']
    _elip(add, BOCA + V((0.0, 0.4, 0.0)), (2.5, 1.4, 0.7 + ab * 0.5), 'fauces', 0, 'boca')
    for j in range(5):
        x = -1.9 + 0.95 * j
        for sz in (1, -1):
            c = BOCA + V((x, 1.4 - 0.25 * abs(x), sz * (0.55 + ab * 0.45)))
            _cono(add, c, c - V((0.0, 0.0, sz * 0.95)), 0.42, 0.1, 'diente', 0, 'boca')
    # --- LOS SEIS TENTACULOS.
    for i in range(TENTACULOS):
        _tentaculo(add, p, i)
    return e.L


ANIMS = {}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'aberracion_754080_1.80', VISTAS + 'aberracion_vs_viejo.png', 3))
    else:
        hornear('aberracion_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
