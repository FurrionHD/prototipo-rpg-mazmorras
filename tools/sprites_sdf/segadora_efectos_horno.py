#!/usr/bin/env python3
# ============================================================
#  segadora_efectos_horno.py -- HORNEA LOS EFECTOS DE LA SEGADORA Y SUS MUTANTES, los de su lamina aprobada (05/11).
#  LA ESTELA DE LAS GARRAS sale de quien corta, (CX, CY) = sus pies (el origen del modelo), una fila por direccion (las otras
#  tres las espeja EfectoPixel) y un marco por fotograma de su animacion, al mismo ritmo: se lanza al empezar el gesto
#  siguiendo al cuerpo y va pegada a la hoja (las puntas, de tools/salida/sdf/puntas_<var>.json; ver segadora_efectos_pixel).
#  EL IMPACTO (destello y sangre) va sobre el cuerpo que recibe, (CX, CY) = sus pies.
#    python tools/sprites_sdf/segadora_efectos_horno.py
# ============================================================
import segadora_efectos_pixel as se       # (trae su lienzo: va antes que los demas)
import escarabajo_efectos_pixel as ep
import slime_efectos_pixel as sl

import horno_efectos as ho
from slime_efectos_pixel import nuevo, estrella

LA = 'segadora'
W, H = se.W, se.H
CX, CY = W // 2, H // 2
ALTO = 10     # el pecho de quien recibe, sobre sus pies

# Donde caen los pies (el origen del modelo) en el lienzo de cada sprite: Modelo(..., pies) de su generador.
PIES = {se.NORMAL: (83, 83), se.SIERRA: (110, 122), se.VENDAVAL: (110, 122)}
# Que hojas tiene cada uno, y con que garras corta en cada una.
ANIMS = {
    se.NORMAL: {'basico': (-1,), 'basico_der': (1,), 'guadanas': (-1, 1), 'ensarte': (1,)},
    se.SIERRA: {'basico': (-1,), 'basico_der': (1,), 'guadanas': (-1, 1), 'ensarte': (1,), 'siega': (-1, 1)},
    se.VENDAVAL: {'basico': (-1,), 'basico_der': (1,), 'guadanas': (-1, 1), 'ensarte': (1,), 'siega': (-1, 1),
                  'vendaval': (-1, 1), 'salto_atras': (1,)},
}
GRUESO = {'guadanas': 7.0, 'siega': 8.0, 'ensarte': 5.0}
LARGO = {'siega': 2.0, 'ensarte': 1.0, 'vendaval': 1.25, 'salto_atras': 1.0}
PREFIJO = {se.NORMAL: 'normal', se.SIERRA: 'sierra', se.VENDAVAL: 'vendaval'}

d = {}
for var, anims in ANIMS.items():
    se._carga(var)
    lw, lh = se._LIENZO[var]
    ox, oy = PIES[var]
    # el sprite puesto de forma que sus pies caigan en (CX, CY): punta() lo coloca por su centro
    pos = (CX - ox + lw // 2, CY - oy + lh // 2)
    pal = se._pal(var)
    for anim, garras in anims.items():
        n = se.n_fotos(var, anim)
        filas = []
        for fila in range(5):
            marcos = []
            for f in range(n):
                s, a = nuevo(), nuevo()
                for g in garras:
                    se.estela(a, var, anim, fila, g, pos, f, pal, GRUESO.get(anim, 6.0), LARGO.get(anim, 1.5))
                marcos.append((s, a))
            filas.append(marcos)
        fps = {'basico': 16.0, 'basico_der': 16.0, 'guadanas': 13.0, 'ensarte': 13.0, 'siega': 13.0, 'vendaval': 13.0,
               'salto_atras': 14.0}[anim]
        nombre = '%s_%s' % (PREFIJO[var], anim)
        d[nombre] = ho.guardar_efecto(LA, nombre, filas, [(CX, CY)] * 5, fps)


# --- EL IMPACTO sobre quien recibe: destello del color de la hoja y sangre (el destello en el marco 0) ---
def impacto(pal):
    out = []
    for e in range(6):
        s, a = nuevo(), nuevo()
        if e < 2:
            estrella(a, CX, CY - ALTO, 11 if e == 0 else 7, pal)
        se.sangre(a, CX, CY - ALTO + 2, e, 3, n=2)
        out.append((s, a))
    return [out]


for nombre, pal in (('impacto_hueso', se.HUESO), ('impacto_metal', se.METAL), ('impacto_viento', se.VIENTO)):
    d[nombre] = ho.guardar_efecto(LA, nombre, impacto(pal), [(CX, CY)], 14.0)

# --- EL ENSARTE sobre quien recibe: destello, esquirlas que salen POR DETRAS (una fila por direccion) y el agujero ---
def estocada(pal):
    import random
    filas = []
    for fila in range(5):
        dx, dy = se._dir(fila)
        out = []
        for e in range(8):
            s, a = nuevo(), nuevo()
            if e < 2:
                estrella(a, CX, CY - ALTO, 11 if e == 0 else 7, pal)
                rnd = random.Random(fila + e)
                for _i in range(6):
                    k = rnd.uniform(6, 16) + e * 6
                    lado = rnd.uniform(-6, 6)
                    ep.punto(a, CX + dx * k - dy * lado, CY - ALTO + dy * k + dx * lado, pal[2], 2)
            ep.bolita(s, CX + dx * 2, CY - ALTO + 2, 2.2 if e < 4 else 1.4, [se.OSCURO, se.OSCURO, (60, 12, 16), (90, 20, 24)])
            se.sangre(a, CX, CY - ALTO + 2, e, fila + 3, n=2)
            out.append((s, a))
        filas.append(out)
    return filas


for nombre, pal in (('estocada_hueso', se.HUESO), ('estocada_metal', se.METAL)):
    d[nombre] = ho.guardar_efecto(LA, nombre, estocada(pal), [(CX, CY)] * 5, 14.0)

ho.sumar(LA, d)
