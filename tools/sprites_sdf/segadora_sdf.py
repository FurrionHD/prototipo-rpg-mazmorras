# ============================================================
#  segadora_sdf.py -- la SEGADORA en 3D (05/10/2026), con el motor de los enemigos (sdf_comun). Lo del viejo
#  (segadora_sprites.gd): UNA MANTIS. Cuerpo LARGO en tres tramos con personalidad: cabeza TRIANGULAR (ancha arriba,
#  con un OJO GORDO en cada punta y su pupila falsa que te sigue), PROTORAX largo y finisimo (sin el sale un
#  saltamontes) y ABDOMEN grande tapado por las TEGMINAS claras (las alas plegadas). CUATRO patas de marcha finas que
#  salen hacia fuera casi planas (nada de la jaula de la araña) y delante las dos GUADAÑAS PLEGADAS contra el pecho:
#  femur con su fila de ESPINAS y la tibia (la hoja) doblada sobre el. EL PLEGADO ES EL BICHO: su reposo es acecho.
#  Las guadañas interpolan DIRECCIONES (no puntas): el brazo mide lo mismo en toda la animacion.
#  Lienzo y origen de su horneado (2,20 -> 166 x 166, el centro).
#  LOS TIEMPOS de cada gesto, los del viejo, para que sus efectos aprobados sigan cayendo igual.
#  Uso: python tools/sprites_sdf/segadora_sdf.py [anim ...]  -> assets/sprites/enemigos/segadora_sdf/<anim>.png
#       python tools/sprites_sdf/segadora_sdf.py vistas     -> tools/salida/sdf/segadora_vs_viejo.png
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *

SALIDA = 'assets/sprites/enemigos/segadora_sdf/'
VISTAS = 'tools/salida/sdf/'
V = np.array

# Oliva pardo (806e40): las tegminas, lo mas CLARO del bicho; las patas, mas oscuras; la hoja de la guadaña, clara.
MAT = {
    'cuerpo':  [(0.26, 0.23, 0.13), (0.40, 0.36, 0.21), (0.52, 0.48, 0.29)],
    'tegmina': [(0.52, 0.53, 0.32), (0.66, 0.67, 0.43), (0.75, 0.74, 0.53)],
    'mancha':  [(0.52, 0.36, 0.33), (0.62, 0.44, 0.40), (0.70, 0.52, 0.48)],
    'pata':    [(0.29, 0.26, 0.15), (0.43, 0.39, 0.23), (0.55, 0.51, 0.32)],
    'guadana': [(0.40, 0.38, 0.22), (0.56, 0.54, 0.33), (0.67, 0.65, 0.42)],
    'hoja':    [(0.56, 0.52, 0.36), (0.72, 0.68, 0.50), (0.82, 0.79, 0.62)],
    'espina':  [(0.17, 0.13, 0.08), (0.24, 0.19, 0.11), (0.30, 0.25, 0.15)],
    'ojo':     [(0.66, 0.66, 0.40), (0.80, 0.80, 0.50), (0.88, 0.88, 0.62), (0.97, 0.97, 0.86)],
    'pupila':  [(0.10, 0.09, 0.06)] * 3,
}
MODELO = Modelo(2.5, (166, 166), (83, 83), MAT, (0.09, 0.07, 0.04), suaves=('cuerpo', 'cabeza'), brillan=('pupila',),
                corta_suelo=True, especular=('ojo',), umbral_especular=0.75)

CUERPO_Z = 6.4
LUNGE_DIST = 9.5
ENCAJE_RETRO = 0.44
# EL PROTORAX sube un poco hacia la cabeza (en 3D la pose de mantis se lee; el viejo la llevaba plana por la camara).
PROTO_A = V((0.0, 5.6, 0.6))
PROTO_B = V((0.0, 15.2, 2.8))
CABEZA = V((0.0, 17.0, 3.4))
# Las guadañas nacen al final del protorax, a los lados del cuello.
GUADANA_ANCLA = V((1.6, 13.4, 2.2))
FEMUR_LARGO = 7.6
TIBIA_LARGO = 8.4
FEMUR_PLEGADO = V((0.24, 0.78, 0.58))
TIBIA_PLEGADO = V((0.02, -0.40, -0.92))
FEMUR_ABIERTO = V((0.60, 0.76, 0.25))
TIBIA_ABIERTO = V((0.30, 0.92, -0.25))
# Las cuatro patas de marcha: (y del anclaje, cuanto abren hacia delante/atras, alcance).
PATAS = [(3.2, 2.6, 11.0), (0.8, -3.6, 12.0)]
PASO_LARGO = 3.4
PASO_ALTO = 2.4


def POSE(**k):
    p = dict(avance=0.0, abre=0.0, abre_izq=-1.0, fase=0.0, paso=0.0, cabeza=0.0, agacha=0.0, alza=0.0, vuelca=0.0,
             encoge=0.0)
    p.update(k)
    return p


def _unit(v):
    return v / np.linalg.norm(v)


def huesos(p):
    X = {}
    # TODO EL BICHO: avanza, se agacha (baja el cuerpo) y, al morir, VUELCA de espaldas sobre su eje largo.
    raiz = (np.eye(3), V((0.0, p['avance'], CUERPO_Z * (1.0 - 0.35 * p['agacha']))))
    if p['vuelca'] > 0.0:
        raiz = comp(raiz, sobre(V((0.0, 0.0, 0.0)), ry(p['vuelca'] * 1.15 * 2.0 * 0.5 * math.pi / 1.15 * 0.5)))
    X['raiz'] = raiz
    # La CABEZA gira sola (lo unico que se le mueve en reposo).
    X['cabeza'] = comp(raiz, sobre(PROTO_B, rz(p['cabeza'] * 0.42)))
    return X


def _elip(add, c, r, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, c=V(c, dtype=float), r=V(r, dtype=float): sd_elipsoide(P, c, r), mat, k, grupo, hueso)


def _cono(add, a, b, ra, rb, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
    add(lambda P, a=V(a, dtype=float), b=V(b, dtype=float): sd_cono(P, a, b, ra, rb), mat, k, grupo, hueso)


def _guadana(add, p, s):
    """Femur + tibia, interpolando DIRECCIONES entre plegada y abierta. 'alza' las sube (la doble guadaña)."""
    a = p['abre'] if (s > 0 or p['abre_izq'] < 0) else p['abre_izq']
    a = max(0.0, min(1.0, a))
    def mezcla(d0, d1):
        d = _unit(d0 + (d1 - d0) * a)
        return V((d[0] * s, d[1], d[2]))
    df = mezcla(FEMUR_PLEGADO, FEMUR_ABIERTO)
    dt = mezcla(TIBIA_PLEGADO, TIBIA_ABIERTO)
    # ALZAR: las dos se levantan por encima de la cabeza (giro sobre el hombro, hacia arriba y atras).
    al = p['alza'] * 0.9
    R = rx(-al)
    df = R @ df; dt = R @ dt
    hom = GUADANA_ANCLA * V((s, 1, 1))
    codo = hom + df * FEMUR_LARGO
    punta = codo + dt * TIBIA_LARGO
    g = 'guadana_%d' % s
    # La coxa: el tramo corto que la une al protorax.
    _cono(add, hom - V((0.6 * s, 0.6, 0.6)), hom, 0.95, 0.95, 'guadana', 0, g)
    # EL FEMUR: grueso, con la fila de ESPINAS por la cara de dentro.
    _cono(add, hom, codo, 1.55, 1.20, 'guadana', 0, g)
    dentro = _unit(dt - df * float(dt @ df))
    for i in range(4):
        u = 0.30 + 0.17 * i
        b = hom + df * FEMUR_LARGO * u
        _cono(add, b, b + dentro * 1.55 + df * 0.35, 0.42, 0.10, 'espina', 0, g)
    # LA TIBIA: la HOJA, fina y curva, con el garfio en la punta.
    medio = codo + dt * TIBIA_LARGO * 0.55 + dentro * 0.35
    _cono(add, codo, medio, 1.05, 0.85, 'hoja', 0, g)
    _cono(add, medio, punta, 0.85, 0.50, 'hoja', 0, g)
    _cono(add, punta, punta + dentro * 1.2 - dt * 0.5, 0.42, 0.12, 'hoja', 0, g)


def _pata(add, p, i, s):
    """Una pata de marcha: cadera en el torax, rodilla baja y algo afuera, pie en el suelo. Al andar, por pares
    cruzados (lo de la araña y el ciempies)."""
    y0, abre, alcance = PATAS[i]
    cad = V((2.0 * s, y0, 0.0))
    fase = p['fase'] + (0.5 if (i == 0) == (s > 0) else 0.0)
    paso = p['paso'] * math.sin(2 * math.pi * fase)
    sube = p['paso'] * max(0.0, math.cos(2 * math.pi * fase)) * PASO_ALTO
    pie = V((alcance * s * 0.95, y0 + abre + paso * PASO_LARGO, -CUERPO_Z * (1.0 - 0.35 * p['agacha']) + sube))
    # Al morir (de espaldas) las patas se ENCOGEN hacia el cuerpo.
    pie = pie + (V((3.2 * s, y0, 2.2)) - pie) * p['encoge']
    rod = cad + (pie - cad) * 0.45 + V((0.0, 0.0, 3.4 - 1.2 * p['encoge']))
    g = 'pata_%d_%d' % (i, s)
    _cono(add, cad, rod, 0.80, 0.68, 'pata', 0, g)
    _cono(add, rod, pie, 0.68, 0.48, 'pata', 0, g)


def escena(pose):
    p = pose
    e = Escena(huesos(p)); add = e.add
    # --- EL ABDOMEN: un oval largo y lleno que se ensancha y se afila, algo caido hacia atras; anillado por debajo.
    for i in range(7):
        u = i / 6
        y = 2.4 - 2.75 * i
        w = 2.6 + 1.2 * math.sin(math.pi * min(u * 1.25, 1.0)) - (1.4 * max(0.0, u - 0.8) / 0.2)
        h = 1.9 + 0.4 * math.sin(math.pi * min(u * 1.25, 1.0)) - (0.9 * max(0.0, u - 0.8) / 0.2)
        _elip(add, (0.0, y, -0.2 - 0.16 * i * 1.6), (max(w, 1.4), 1.9, max(h, 1.15)), 'cuerpo', 1.2)
    # LAS TEGMINAS: las alas plegadas sobre el abdomen, GRANDES y CLARAS, con la costura en medio.
    for s in (-1, 1):
        _elip(add, (0.95 * s, -5.0, 1.55), (2.05, 8.6, 0.75), 'tegmina', 0, 'tegmina')
    # La MANCHA del abdomen: atras y discreta (delante se leia como una cara en el culo).
    for s in (-1, 1):
        _elip(add, (1.4 * s, -8.2, 1.95), (0.85, 1.1, 0.45), 'mancha', 0, 'tegmina')
    # --- EL TORAX, donde se clavan las patas.
    _elip(add, (0.0, 3.8, 0.2), (2.4, 2.2, 1.9), 'cuerpo', 1.0)
    # --- EL PROTORAX: un palo largo y fino, ensanchandose un poco donde nacen las guadañas.
    _cono(add, PROTO_A, PROTO_B, 1.55, 1.05, 'cuerpo', 0.8)
    _elip(add, (0.0, 13.4, 2.9), (1.75, 1.6, 1.25), 'cuerpo', 0.8)
    # --- LA CABEZA TRIANGULAR: una barra ancha (los ojos en las puntas) y el morro estrecho delante y abajo.
    _elip(add, CABEZA, (2.8, 1.35, 1.55), 'cuerpo', 0.6, 'cabeza', 'cabeza')
    _elip(add, CABEZA + V((0.0, 1.5, -0.9)), (1.25, 1.2, 1.25), 'cuerpo', 0.6, 'cabeza', 'cabeza')
    for s in (-1, 1):
        c = CABEZA + V((2.55 * s, 0.35, 0.55))
        _elip(add, c, (1.35, 1.25, 1.45), 'ojo', 0, 'ojo', 'cabeza')
        _elip(add, c + _unit(V((0.55 * s, 0.75, 0.35))) * 1.05, (0.55, 0.55, 0.6), 'pupila', 0, 'ojo', 'cabeza')
        # LAS ANTENAS: dos hilos finos hacia delante y arriba (sin barbas: las plumosas son de polilla).
        a0 = CABEZA + V((0.65 * s, 0.9, 1.2))
        a1 = a0 + _unit(V((0.30 * s, 0.75, 0.55))) * 5.6
        _cono(add, a0, a1, 0.40, 0.28, 'pata', 0, 'antena', 'cabeza')
    # --- LAS PATAS DE MARCHA y LAS GUADAÑAS.
    for i in range(2):
        for s in (-1, 1):
            _pata(add, p, i, s)
    for s in (-1, 1):
        _guadana(add, p, s)
    return e.L


# ------------------------------------------------------------
#  ANIMACIONES (las claves de tiempo, las del viejo)
# ------------------------------------------------------------
def anim_idle(t):
    # CLAVADA: lo unico que se mueve es la cabeza, que gira.
    return POSE(cabeza=math.sin(2 * math.pi * t), agacha=0.03 * (1 - math.cos(2 * math.pi * t)))


ANIMS = {
    'idle': (8, 3.0, True, 8, anim_idle),
}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['vistas']:
        os.makedirs(VISTAS, exist_ok=True)
        fotos = [render(MODELO, escena(POSE()), d) for d in range(5)]
        print(vistas_lado_a_lado(fotos, 'segadora_806e40_2.20', VISTAS + 'segadora_vs_viejo.png', 3))
    else:
        hornear('segadora_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
