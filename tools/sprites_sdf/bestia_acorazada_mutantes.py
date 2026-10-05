# ============================================================
#  bestia_acorazada_mutantes.py -- la familia de la BESTIA ACORAZADA (05/10/2026), tras elegir entre las cinco versiones
#  (bestia_acorazada_versiones.py):
#    E bowser    "este esta buenardo" -> la NORMAL (a la escala del viejo, 1,95)
#    B blatogia  MUTANTE: "mas grande y mas epico" (2,7)
#    A behemot   MUTANTE JEFE: "uno hazlo como si fuera un jefe" (3,6), el mayor
#  Los mutantes son su version de la lamina + lo EPICO encima: mas puas (segunda fila por los flancos, en la cola, en
#  los codos), mas cuernos, garras mas largas y ojos que brillan; el jefe ademas con escamas en las patas.
#  Solo QUIETOS, en una lamina al MISMO zoom (para que se vea la diferencia de tamaño).
#  Uso: python tools/sprites_sdf/bestia_acorazada_mutantes.py  -> tools/salida/sdf/bestia_acorazada_mutantes.png
# ============================================================
import sys, os, math, json
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import bestia_acorazada_versiones as bv

V = np.array
_unit = bv._unit


class _Añade:
    """Para colgar piezas a una escena ya hecha (sin huesos: todo en la raiz)."""
    def __init__(self, L):
        self.L = L

    def add(self, fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        self.L.append((fn, mat, grupo, k, IDENT, hueso))


def _puntos_cadena(p0, d0, n, paso, r0, r1, giro):
    """Los mismos puntos que Kit.cadena, sin pintar nada (para colgarle puas a una cola ya hecha)."""
    p = V(p0, dtype=float); d = _unit(d0); out = []
    for i in range(n):
        rb = r0 + (r1 - r0) * (i + 1) / max(n - 1, 1)
        q = p + d * paso
        out.append((q.copy(), d.copy(), rb))
        p = q; d = _unit(giro(i) @ d)
    return out


# ------------------------------------------------------------
#  B MUTANTE -- blatogia, mas epica
# ------------------------------------------------------------
# 05/10: "el mutante que no tenga el color tan diferente del normal, es decir ROJO" y luego "que cambien UN POCO de
# color pero que mantengan la paleta mas o menos": la familia de la E, cada mutante con su matiz. Este, ROJO OXIDO
# (tira a naranja), con el vientre palido algo mas calido.
MAT_B = dict(bv.MAT_B)
MAT_B['piel'] = [(0.40, 0.11, 0.08), (0.58, 0.19, 0.13), (0.72, 0.29, 0.20)]
MAT_B['naranja'] = [(0.58, 0.46, 0.36), (0.74, 0.62, 0.50), (0.85, 0.75, 0.63)]
MAT_B['hueso'] = bv.MAT_E['pua']
MAT_B['garra'] = bv.MAT_E['pua']
MAT_B['ojo'] = [(1.00, 0.20, 0.12)] * 3


def escena_b_mutante():
    L = bv.escena_b()
    k = bv.Kit(_Añade(L))
    H = V((0.0, 13.6, 6.4))
    # LAS RAYAS NARANJAS de los costados (las de la referencia): laminas finas que asoman de la piel, en diagonal.
    for s in (-1, 1):
        for i, y in enumerate((5.0, 1.0, -3.0, -7.0)):
            c = V((4.5 * s if i < 2 else 5.0 * s, y, 9.6 + (0.6 if i > 1 else 0.0)))
            k.caja(c, bv.marco((0.0, 0.5, -1.0), (s, 0.0, 0.0)), (0.35, 0.6, 2.6), 'naranja', 0.25, 0, 'raya')
    # SEGUNDA FILA de puas por los flancos, mas bajas y abiertas.
    for i in range(6):
        u = i / 5.0
        y = 6.0 - u * 14.0
        for s in (-1, 1):
            k.pua((4.0 * s, y, 10.8 + 1.6 * math.sin(math.pi * u)), (0.9 * s, -0.7, 0.55), 4.6 - 1.2 * abs(u - 0.4),
                  1.2, 'hueso', 'pua_f', curva=0.15)
    # PUAS en los codos y en el muslo, hacia atras.
    for s in (-1, 1):
        k.pua((6.2 * s, 5.4, 4.6), (0.3 * s, -1.0, 0.5), 3.6, 0.9, 'hueso', 'pua_codo')
        k.pua((6.6 * s, -6.6, 9.6), (0.6 * s, -1.0, 0.6), 4.2, 1.0, 'hueso', 'pua_codo')
        # Un segundo par de cuernos, mas largos, en la calavera.
        k.pua(H + V((1.0 * s, -0.8, 2.2)), (0.2 * s, -1.0, 0.7), 5.4, 0.9, 'hueso', 'cuerno', curva=0.25)
    return L


# ------------------------------------------------------------
#  A JEFE -- behemot
# ------------------------------------------------------------
# El jefe, en VINO OSCURO: de la familia de la normal pero mas hondo y algo morado (el granate de antes salia casi del
# mismo rojo que la B); la melena, del hierro de la E.
MAT_A = dict(bv.MAT_A)
MAT_A['piel'] = [(0.17, 0.04, 0.08), (0.27, 0.07, 0.13), (0.38, 0.12, 0.19)]
MAT_A['escama'] = [(0.25, 0.06, 0.11), (0.37, 0.10, 0.17), (0.50, 0.17, 0.25)]
MAT_A['pelo'] = bv.MAT_E['hierro']
MAT_A['marfil'] = bv.MAT_E['pua']
MAT_A['ojo'] = [(1.00, 0.25, 0.10)] * 3


def escena_a_jefe():
    L = bv.escena_a()
    k = bv.Kit(_Añade(L))
    H = V((0.0, 14.2, 8.4))
    # SEGUNDA FILA de puas por los flancos (debajo de las del lomo).
    for i in range(6):
        u = i / 5.0
        y = 6.6 - u * 14.0
        z = 12.0 - 2.6 * u
        for s in (-1, 1):
            k.pua((4.6 * s - 0.6 * s * u, y, z), (1.0 * s, -0.5, 0.45), 6.0 - 3.0 * u, 1.4 - 0.4 * u, 'marfil', 'pua_f',
                  curva=0.2)
    # PUAS EN LA COLA: por encima, menguando hacia la punta.
    pts = _puntos_cadena((0.0, -12.4, 9.4), (0.0, -1.0, -0.35), 16, 1.25, 1.9, 0.45,
                         lambda i: rx(0.04 if i < 9 else 0.38) @ rz(0.06))
    for j, (q, d, r) in enumerate(pts[:11]):
        if j % 2 == 0:
            k.pua(q + V((0.0, 0.0, r * 0.5)), (0.0, -0.6, 1.0), 3.6 - 0.25 * j, 0.95 - 0.05 * j, 'marfil', 'pua_cola')
    for s in (-1, 1):
        # Mas cuernos: el par de las mejillas, hacia delante y abajo (los de la referencia, a los lados de las fauces).
        k.pua(H + V((2.4 * s, 2.0, -1.0)), (0.7 * s, 0.4, -0.3), 3.0, 0.75, 'marfil', 'cuerno')
        k.pua(H + V((2.0 * s, 4.0, -2.2)), (0.7 * s, 0.6, -0.4), 2.2, 0.6, 'marfil', 'cuerno')
        # El gran cuerno de la frente, por encima de la corona.
        k.pua(H + V((1.0 * s, 0.4, 2.4)), (0.25 * s, -0.6, 1.0), 6.4, 1.1, 'marfil', 'cuerno', curva=0.3)
        # Ojos mayores, encendidos.
        k.ojo(H + V((2.3 * s, 2.4, 1.6)), 0.62)
        # ESCAMAS en las patas delanteras: placas que sobresalen por la cara de fuera.
        for j in range(4):
            c = V((6.4 * s + 1.4 * s, 4.6 - 0.2 * j, 10.6 - 2.2 * j))
            k.elip(c, (0.7, 1.6, 1.2), 'escama', 0, 'escama%d' % (j % 2))
        # GARRAS mas largas por delante.
        for j in (-1, 0, 1):
            base = V((6.6 * s + 1.7 * j, 7.6, 0.8))
            k.cono(base, base + V((0.3 * j, 2.4, -0.6)), 0.7, 0.15, 'marfil', 0, 'garra_g')
    return L


FAMILIA = [
    ('E normal 1,95', bv.MAT_E, bv.escena_e, (0.08, 0.04, 0.04), 1.95),
    ('B mutante 2,7', MAT_B, escena_b_mutante, (0.08, 0.04, 0.04), 2.7),
    ('A jefe 3,6', MAT_A, escena_a_jefe, (0.07, 0.03, 0.03), 3.6),
]


def modelo(mat, borde, L, escala):
    grupos = tuple(dict.fromkeys(x[2] for x in L))
    lado = int(round(bv.LADO * escala / bv.ESCALA / 2)) * 2
    return Modelo(escala, (lado, lado), (lado // 2, int(lado // 2 + 14 * escala / bv.ESCALA)), mat, borde,
                  suaves=grupos, brillan=('ojo',), corta_suelo=True)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, mat, fn, borde, esc in FAMILIA:
        L = fn()
        mo = modelo(mat, borde, L, esc)
        fotos = [render(mo, L, dd) for dd in range(5)]
        # Recortar a lo ocupado (el lienzo del jefe es casi todo aire).
        caja = None
        for f in fotos:
            b = f.getbbox()
            caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
        filas.append((nombre, [f.crop((0, caja[1] - 3, f.size[0], caja[3] + 3)) for f in fotos]))
        print(nombre, 'ok')
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 80, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (80 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/bestia_acorazada_mutantes.png')
    print('tools/salida/sdf/bestia_acorazada_mutantes.png')
