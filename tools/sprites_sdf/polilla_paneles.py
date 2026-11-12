# ============================================================
#  polilla_paneles.py -- LA MEZCLA DE LA POLILLA CON ALAS DE PANELES (12/11/2026). Del dibujo del jefe y su referencia
#  (alas negras picudas partidas en recuadros de ojos neon): "cada uno de los recuadros es un ojo y solo tiene un poco de
#  borde negro a los lados, y ya con las puntas bien marcadas igual que en la referencia, en pico".
#  CADA ALA = paneles (cuadrilateros en coordenadas del ala: [envergadura, hacia atras]). El ala entera va en negro (el
#  borde) y encima cada panel, un poco encogido, RELLENO DE ANILLOS con su misma forma (el panel encogido hacia su centro,
#  un color por anillo) y la pupila negra en medio. Delante: un cuadrilatero picudo partido en 2 x 2. Detras: una cometa
#  picuda partida en 2 x 2 y una cola con un panel.
#  Uso: python tools/sprites_sdf/polilla_paneles.py -> tools/salida/sdf/polilla_paneles.png
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm
import polilla_versiones as pv
import polilla_astral_versiones as ast

V = np.array
tonos = ast.tonos


def bilineal(q, u, v):
    """Punto (u, v) dentro del cuadrilatero q = [raiz-delante, punta-delante, punta-detras, raiz-detras]."""
    a = [q[0][i] + (q[1][i] - q[0][i]) * u for i in range(2)]
    b = [q[3][i] + (q[2][i] - q[3][i]) * u for i in range(2)]
    return (a[0] + (b[0] - a[0]) * v, a[1] + (b[1] - a[1]) * v)


def rejilla(q, nu, nv):
    """El cuadrilatero partido en nu x nv paneles."""
    out = []
    for i in range(nu):
        for j in range(nv):
            out.append([bilineal(q, i / nu, j / nv), bilineal(q, (i + 1) / nu, j / nv),
                        bilineal(q, (i + 1) / nu, (j + 1) / nv), bilineal(q, i / nu, (j + 1) / nv)])
    return out


def ala_paneles(add, p, s, A, nombre):
    th = p['bate'] * pm.BATE_MAX
    abre = 1.0 + 0.22 * p['abre']

    def punto(span, atras):
        span *= abre
        phi = th - 0.18 * p['bate'] * (span / 12.0)
        return A['raiz'] * V((s, 1, 1)) + V((s * span * math.cos(phi), -atras, span * math.sin(phi)))

    def poligono(pts2, grosor, mat):
        cx = sum(a for a, _b in pts2) / len(pts2); cy = sum(b for _a, b in pts2) / len(pts2)
        cen = punto(cx, cy)
        P3 = [punto(a, b) for a, b in pts2]
        for i in range(len(P3)):
            add(lambda P, a=cen, b=P3[i], c=P3[(i + 1) % len(P3)]: sd_triangulo(P, a, b, c, grosor), mat, 0, nombre,
                'raiz')

    def encoge(pts2, f):
        cx = sum(a for a, _b in pts2) / len(pts2); cy = sum(b for _a, b in pts2) / len(pts2)
        return [(cx + (a - cx) * f, cy + (b - cy) * f) for a, b in pts2]

    n = len(A['anillos'])
    for forma in A['silueta']:
        poligono(forma, 0.22, A['marco'])
    for k, panel in enumerate(A['paneles']):
        hueco = A.get('hueco', 0.84)
        # (12/11, la evolucion) 'abiertos': lo abierto de cada ojo (0..1); asi se abren uno a uno.
        if 'abiertos' in A:
            hueco *= A['abiertos'][k]
            if hueco < 0.06:
                continue
        for r in range(n):
            mat = A['anillos'][(r + k * A.get('gira', 2)) % n]
            poligono(encoge(panel, hueco * (1.0 - 0.78 * r / n)), 0.26 + 0.03 * r, mat)
        poligono(encoge(panel, hueco * 0.16), 0.26 + 0.03 * n, 'ocelo_n')


# LAS FORMAS (en el sentido de su dibujo): delante un cuadrilatero con la punta de fuera muy en pico hacia delante;
# detras una cometa con la punta hacia fuera y atras, y la cola colgando por dentro.
DEL = [(0.4, -0.6), (15.0, -5.2), (13.4, 2.4), (0.8, 5.0)]
TRA = [(0.6, 0.2), (9.6, 3.2), (9.0, 11.4), (1.4, 7.6)]
COLA = [(1.4, 7.8), (4.6, 9.4), (4.4, 17.8), (2.0, 13.6)]

ANILLOS_REF = ['n_magenta', 'n_amarillo', 'n_verde', 'n_cian', 'n_violeta']
NEON = {'n_magenta': tonos((1.0, 0.25, 0.85), (0.8, 0.95, 1.0)), 'n_amarillo': tonos((1.0, 0.95, 0.30), (0.8, 0.95, 1.0)),
        'n_verde': tonos((0.45, 1.0, 0.40), (0.8, 0.95, 1.0)), 'n_cian': tonos((0.30, 0.95, 1.0), (0.8, 0.95, 1.0)),
        'n_violeta': tonos((0.55, 0.35, 1.0), (0.8, 0.95, 1.0))}


def alas(marco, hueco=0.84, nu1=2, nv1=2):
    a1 = dict(raiz=pv.R1, marco=marco, anillos=ANILLOS_REF, hueco=hueco, silueta=[DEL], paneles=rejilla(DEL, nu1, nv1))
    a2 = dict(raiz=pv.R2, marco=marco, anillos=ANILLOS_REF, hueco=hueco, gira=3, silueta=[TRA, COLA],
              paneles=rejilla(TRA, 2, 2) + [COLA])
    return a1, a2


CUERPO = dict(ast.VARIANTES['E todo']['mat'])
VARIANTES = {}
a1, a2 = alas('marco')
VARIANTES['P1 paneles negros'] = dict(mat=dict(CUERPO, **NEON, marco=tonos((0.04, 0.03, 0.05))), escala=3.4,
                                      brillan=('brillo',) + tuple(NEON), ala1=a1, ala2=a2, extra='ojo_cielo')
a1, a2 = alas('marco', hueco=0.78)
VARIANTES['P2 marco violeta'] = dict(mat=dict(CUERPO, **NEON, marco=tonos((0.30, 0.10, 0.42))), escala=3.4,
                                     brillan=('brillo',) + tuple(NEON), ala1=a1, ala2=a2, extra='ojo_cielo')
a1, a2 = alas('marco', nu1=3, nv1=2)
VARIANTES['P3 seis paneles'] = dict(mat=dict(CUERPO, **NEON, marco=tonos((0.04, 0.03, 0.05))), escala=3.4,
                                    brillan=('brillo',) + tuple(NEON), ala1=a1, ala2=a2, extra='ojo_cielo')
a1, a2 = alas('marco', hueco=0.9)
VARIANTES['P4 borde finisimo'] = dict(mat=dict(CUERPO, **NEON, marco=tonos((0.04, 0.03, 0.05))), escala=3.4,
                                      brillan=('brillo',) + tuple(NEON), ala1=a1, ala2=a2, extra='ojo_cielo')


if __name__ == '__main__':
    pv.ala_generica = ala_paneles
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, vv in VARIANTES.items():
        mo = ast.mz.modelo(vv)
        L = ast.escena(vv, pm.POSE())
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 130, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (130 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/polilla_paneles.png')
    print('tools/salida/sdf/polilla_paneles.png')
