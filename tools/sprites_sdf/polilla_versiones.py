# ============================================================
#  polilla_versiones.py -- CUATRO PROPUESTAS de polilla en 3D (05/10/2026), una por cada referencia que paso el jefe
#  ("parece una mariposa, no una polilla" + "hazme varias versiones de lo que te he pasado"). Solo QUIETAS: la elegida
#  pasa a polilla_sdf.py (que ya tiene las animaciones con las claves del viejo). Mismo cuerpo, lienzo y origen.
#    A pavon     el pavon nocturno de la lamina: gris pardo, banda clara en zigzag, borde palido, ocelos con media luna roja
#    B ojos      el grabado: alas NEGRAS con OJOS almendrados color crema (uno por ala) y un TERCER OJO en el torax
#    C boceto    su boceto: delanteras altas y PICUDAS, ocelos en DIANA blancos, bordes de humo deshilachados y las
#                traseras alargadas en COLA
#    D calavera  la esfinge de la calavera: delanteras largas y estrechas, moteadas; traseras AMARILLAS con bandas negras,
#                abdomen a rayas amarillas y la CALAVERA en el torax
#  Uso: python tools/sprites_sdf/polilla_versiones.py  -> tools/salida/sdf/polilla_versiones.png
# ============================================================
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm

V = np.array
Z = pm.VUELO_Z

COMUN = {
    'ojo':     [(0.06, 0.05, 0.07), (0.10, 0.09, 0.12), (0.20, 0.18, 0.24), (0.80, 0.78, 0.86)],
    'ocelo_n': [(0.05, 0.04, 0.05)] * 3,
    'brillo':  [(0.97, 0.96, 0.95)] * 3,
}


# ------------------------------------------------------------
#  EL ALA GENERICA: contorno en abanico; encima (lo mas gordo gana) la banda del borde, el centro, los festones o los
#  jirones de humo, las lineas, las bandas, las manchas y los ojos.
# ------------------------------------------------------------
def ala_generica(add, p, s, A, nombre):
    th = p['bate'] * pm.BATE_MAX
    abre = 1.0 + 0.22 * p['abre']
    def punto(span, atras):
        span *= abre
        phi = th - 0.18 * p['bate'] * (span / 12.0)
        return A['raiz'] * V((s, 1, 1)) + V((s * span * math.cos(phi), -atras, span * math.sin(phi)))
    def lam(pts2, grosor, mat, cen2):
        cen = punto(*cen2)
        P3 = [punto(a, b) for a, b in pts2]
        for i in range(len(P3)):
            add(lambda P, a=cen, b=P3[i], c=P3[(i + 1) % len(P3)]: sd_triangulo(P, a, b, c, grosor), mat, 0, nombre,
                'raiz')
    bd = A['borde']
    cx = sum(b[0] for b in bd) / len(bd); cy = sum(b[1] for b in bd) / len(bd)
    cen2 = A.get('centro', (cx, cy))
    banda = A.get('banda')            # (material, ancho) o None
    if banda:
        lam([(a, b) for a, b, _f in bd], 0.20, banda[0], cen2)
        dentro = []
        for a, b, f in bd:
            if f:
                d = math.hypot(a - cen2[0], b - cen2[1])
                k = max(0.0, (d - banda[1]) / d)
                a, b = cen2[0] + (a - cen2[0]) * k, cen2[1] + (b - cen2[1]) * k
            dentro.append((a, b))
        lam(dentro, 0.27, A['mat'], cen2)
    else:
        lam([(a, b) for a, b, _f in bd], 0.24, A['mat'], cen2)
    e1 = punto(1.0, cy) - punto(0.0, cy); e1 /= np.linalg.norm(e1)
    e2 = punto(cx, cy + 1.0) - punto(cx, cy); e2 /= np.linalg.norm(e2)
    def disco(a, b, r1, r2, grosor, mat, ang=0.0):
        u1 = e1 * math.cos(ang) + e2 * math.sin(ang); u2 = -e1 * math.sin(ang) + e2 * math.cos(ang)
        pm._disco(add, punto(a, b), u1, u2, r1, r2, grosor, mat, nombre)
    fuera = [(a, b) for a, b, f in bd if f]
    # FESTONES (el borde ondulado) o JIRONES (el humo del boceto: bultos de tamaños distintos hacia fuera).
    if A.get('festones') or A.get('jirones'):
        rng = np.random.default_rng(A.get('semilla', 3))
        for (a0, b0), (a1, b1) in zip(fuera, fuera[1:]):
            n = max(1, int(math.hypot(a1 - a0, b1 - b0) / 1.25))
            for j in range(n):
                u = (j + 0.5) / n
                a, b = a0 + (a1 - a0) * u, b0 + (b1 - b0) * u
                d = math.hypot(a - cen2[0], b - cen2[1])
                if A.get('jirones'):
                    r = rng.uniform(0.55, 1.25)
                    sale = rng.uniform(0.2, 1.0)
                    a += (a - cen2[0]) / d * sale; b += (b - cen2[1]) / d * sale
                    disco(a, b, r, r * rng.uniform(0.7, 1.0), 0.22, A['jirones'])
                else:
                    a += (a - cen2[0]) / d * 0.25; b += (b - cen2[1]) / d * 0.25
                    disco(a, b, 0.70, 0.70, 0.20, A['festones'])
    # LINEAS en zigzag: [(desde, hasta, material, picos, amplitud)]
    for (a0, b0), (a1, b1), mat, n, amp in A.get('lineas', []):
        pts = []
        for j in range(n + 1):
            u = j / n
            off = amp * (1 if j % 2 else -1)
            pts.append(punto(a0 + (a1 - a0) * u + off, b0 + (b1 - b0) * u))
        for q0, q1 in zip(pts, pts[1:]):
            pm._cono(add, q0, q1, 0.32, 0.32, mat, 0, nombre)
    # MANCHAS y BANDAS: discos alargados [(a, b, r1, r2, ang, material)]
    for a, b, r1, r2, ang, mat in A.get('manchas', []):
        disco(a, b, r1, r2, 0.31, mat, ang)
    # LOS OJOS
    for (oa, ob), r, estilo in A.get('ocelos', []):
        if estilo == 'saturnia':
            disco(oa, ob, r, r * 0.95, 0.36, 'ocelo')
            disco(oa, ob, r * 0.74, r * 0.70, 0.40, 'iris')
            disco(oa - r * 0.10, ob - r * 0.14, r * 0.52, r * 0.50, 0.44, 'rojo')
            disco(oa + r * 0.05, ob + r * 0.05, r * 0.46, r * 0.44, 0.48, 'ocelo_n')
            disco(oa - r * 0.15, ob - r * 0.18, r * 0.14, r * 0.14, 0.54, 'brillo')
        elif estilo == 'ojo':
            # ALMENDRADO, como un ojo de persona: el blanco crema estirado a lo largo del ala, el iris y la pupila.
            disco(oa, ob, r * 1.55, r * 0.78, 0.36, 'ocelo')
            disco(oa, ob, r * 0.62, r * 0.62, 0.42, 'iris')
            disco(oa, ob, r * 0.34, r * 0.34, 0.48, 'ocelo_n')
            disco(oa - r * 0.15, ob - r * 0.15, r * 0.12, r * 0.12, 0.54, 'brillo')
        elif estilo == 'diana':
            # EN DIANA, la del boceto: blanco, oscuro, blanco, nucleo.
            disco(oa, ob, r, r, 0.36, 'ocelo')
            disco(oa, ob, r * 0.72, r * 0.72, 0.40, 'ocelo_n')
            disco(oa, ob, r * 0.50, r * 0.50, 0.44, 'ocelo')
            disco(oa, ob, r * 0.24, r * 0.24, 0.50, 'ocelo_n')


# ------------------------------------------------------------
#  LAS CUATRO
# ------------------------------------------------------------
R1 = V((1.35, 2.6, Z + 0.35))
R2 = V((1.20, -1.2, Z - 0.35))
DEL_SATURNIA = [(0.0, -0.4, 0), (3.5, -1.3, 0), (7.5, -2.1, 0), (11.0, -2.8, 0), (13.4, -3.0, 1), (14.3, -1.9, 1),
                (13.9, 0.4, 1), (12.7, 2.8, 1), (10.9, 4.8, 1), (8.6, 6.1, 1), (6.0, 6.5, 1), (3.2, 6.1, 0),
                (1.0, 4.9, 0)]
TRA_SATURNIA = [(0.0, 0.0, 0), (3.0, 0.4, 0), (6.5, 1.4, 0), (9.0, 3.3, 1), (10.0, 5.8, 1), (9.4, 8.2, 1),
                (7.6, 10.0, 1), (5.0, 10.8, 1), (2.6, 10.2, 1), (0.9, 8.4, 0), (0.0, 5.0, 0)]

VERSIONES = {}

VERSIONES['A pavon'] = dict(
    mat={'ala': [(0.27, 0.23, 0.21), (0.38, 0.33, 0.30), (0.47, 0.42, 0.38)],
         'ala_tras': [(0.24, 0.20, 0.18), (0.34, 0.29, 0.26), (0.43, 0.37, 0.33)],
         'borde': [(0.60, 0.55, 0.47), (0.75, 0.70, 0.60), (0.83, 0.79, 0.70)],
         'linea': [(0.70, 0.64, 0.54), (0.82, 0.76, 0.65), (0.88, 0.83, 0.73)],
         'rosa': [(0.58, 0.38, 0.40), (0.70, 0.48, 0.50), (0.78, 0.57, 0.58)],
         'ocelo': [(0.74, 0.68, 0.56), (0.86, 0.80, 0.66), (0.92, 0.87, 0.75)],
         'iris': [(0.44, 0.33, 0.20), (0.56, 0.42, 0.26), (0.64, 0.50, 0.32)],
         'rojo': [(0.62, 0.16, 0.20), (0.76, 0.22, 0.26), (0.84, 0.32, 0.35)],
         'pelo': [(0.25, 0.18, 0.15), (0.36, 0.26, 0.22), (0.46, 0.35, 0.30)],
         'gola': [(0.58, 0.52, 0.44), (0.72, 0.66, 0.56), (0.80, 0.75, 0.66)],
         'anillo': [(0.20, 0.14, 0.11), (0.28, 0.20, 0.16), (0.35, 0.26, 0.21)],
         'antena': [(0.56, 0.48, 0.34), (0.70, 0.61, 0.44), (0.80, 0.72, 0.54)]},
    ala1=dict(raiz=R1, mat='ala', borde=DEL_SATURNIA, banda=('borde', 1.4), festones='borde',
              lineas=[((10.4, -2.6), (8.0, 5.8), 'linea', 8, 0.6), ((3.8, -1.2), (3.0, 6.0), 'rosa', 6, 0.45)],
              ocelos=[((8.0, 1.6), 2.6, 'saturnia')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA_SATURNIA, banda=('borde', 1.4), festones='borde',
              lineas=[((6.4, 1.6), (2.2, 9.6), 'linea', 7, 0.5)],
              ocelos=[((5.4, 5.6), 2.5, 'saturnia')]),
)

VERSIONES['B ojos'] = dict(
    mat={'ala': [(0.07, 0.06, 0.06), (0.11, 0.10, 0.10), (0.16, 0.14, 0.14)],
         'ala_tras': [(0.06, 0.05, 0.05), (0.10, 0.09, 0.09), (0.14, 0.12, 0.12)],
         'borde': [(0.58, 0.46, 0.33), (0.70, 0.57, 0.42), (0.78, 0.66, 0.50)],
         'linea': [(0.58, 0.46, 0.33), (0.70, 0.57, 0.42), (0.78, 0.66, 0.50)],
         'ocelo': [(0.74, 0.60, 0.45), (0.86, 0.72, 0.56), (0.92, 0.80, 0.65)],
         'iris': [(0.30, 0.24, 0.18), (0.40, 0.32, 0.24), (0.48, 0.39, 0.30)],
         'pelo': [(0.08, 0.07, 0.07), (0.13, 0.11, 0.11), (0.20, 0.17, 0.16)],
         'gola': [(0.50, 0.40, 0.30), (0.62, 0.50, 0.38), (0.72, 0.59, 0.46)],
         'anillo': [(0.42, 0.33, 0.24), (0.54, 0.43, 0.32), (0.62, 0.50, 0.38)],
         'antena': [(0.56, 0.48, 0.40), (0.70, 0.62, 0.52), (0.80, 0.72, 0.62)]},
    ala1=dict(raiz=R1, mat='ala', borde=DEL_SATURNIA, banda=('borde', 0.75), festones='ala',
              lineas=[((12.0, -2.4), (9.6, 5.6), 'linea', 1, 0.0)],
              ocelos=[((8.0, 1.6), 2.4, 'ojo')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA_SATURNIA, banda=('borde', 0.75), festones='ala_tras',
              ocelos=[((5.2, 5.8), 2.2, 'ojo')]),
    extra='tercer_ojo',
)

VERSIONES['C boceto'] = dict(
    mat={'ala': [(0.16, 0.16, 0.18), (0.23, 0.23, 0.25), (0.30, 0.30, 0.32)],
         'ala_tras': [(0.13, 0.13, 0.15), (0.19, 0.19, 0.21), (0.25, 0.25, 0.27)],
         'humo': [(0.26, 0.26, 0.28), (0.34, 0.34, 0.36), (0.40, 0.40, 0.42)],
         'linea': [(0.70, 0.70, 0.72), (0.84, 0.84, 0.86), (0.90, 0.90, 0.92)],
         'ocelo': [(0.86, 0.86, 0.86), (0.93, 0.93, 0.93), (0.97, 0.97, 0.97)],
         'pelo': [(0.10, 0.10, 0.11), (0.16, 0.16, 0.17), (0.23, 0.23, 0.24)],
         'gola': [(0.17, 0.17, 0.18), (0.24, 0.24, 0.25), (0.31, 0.31, 0.32)],
         'anillo': [(0.30, 0.30, 0.32), (0.40, 0.40, 0.42), (0.48, 0.48, 0.50)],
         'antena': [(0.16, 0.16, 0.17), (0.24, 0.24, 0.25), (0.32, 0.32, 0.33)],
         'iris': [(0.5, 0.5, 0.5)] * 3},
    ala1=dict(raiz=R1, mat='ala', jirones='humo', semilla=7, centro=(8.0, 1.0),
              borde=[(0.0, -0.4, 0), (4.0, -2.6, 0), (9.0, -5.2, 0), (13.6, -7.8, 0), (14.4, -6.4, 1),
                     (13.6, -2.6, 1), (12.4, 1.2, 1), (10.4, 4.4, 1), (7.6, 6.2, 1), (4.6, 6.6, 1), (2.2, 6.0, 0),
                     (0.8, 4.6, 0)],
              lineas=[((5.0, -2.0), (3.6, 5.2), 'linea', 6, 0.55)],
              ocelos=[((9.0, -1.0), 3.3, 'diana')]),
    ala2=dict(raiz=R2, mat='ala_tras', jirones='humo', semilla=11, centro=(4.6, 6.0),
              borde=[(0.0, 0.0, 0), (3.4, 0.6, 0), (7.0, 2.0, 0), (9.0, 4.4, 1), (8.4, 7.4, 1), (6.4, 10.0, 1),
                     (4.8, 13.2, 1), (4.4, 16.4, 1), (3.4, 16.8, 1), (2.6, 13.6, 1), (1.4, 10.4, 0), (0.0, 6.0, 0)],
              ocelos=[((5.0, 5.8), 2.5, 'diana')]),
)

VERSIONES['D calavera'] = dict(
    mat={'ala': [(0.18, 0.14, 0.11), (0.27, 0.21, 0.16), (0.35, 0.28, 0.22)],
         'mota': [(0.40, 0.33, 0.25), (0.52, 0.44, 0.34), (0.60, 0.52, 0.41)],
         'ala_tras': [(0.70, 0.54, 0.12), (0.86, 0.68, 0.18), (0.93, 0.78, 0.30)],
         'banda': [(0.08, 0.06, 0.05), (0.13, 0.10, 0.08), (0.18, 0.14, 0.11)],
         'pelo': [(0.14, 0.11, 0.09), (0.21, 0.17, 0.13), (0.29, 0.23, 0.18)],
         'gola': [(0.20, 0.16, 0.12), (0.28, 0.22, 0.17), (0.36, 0.29, 0.22)],
         'anillo': [(0.72, 0.56, 0.12), (0.86, 0.68, 0.18), (0.92, 0.77, 0.28)],
         'antena': [(0.30, 0.25, 0.20), (0.42, 0.35, 0.28), (0.52, 0.44, 0.36)],
         'craneo': [(0.70, 0.62, 0.46), (0.84, 0.76, 0.58), (0.91, 0.85, 0.68)],
         'ocelo': [(0.8, 0.8, 0.8)] * 3, 'iris': [(0.5, 0.5, 0.5)] * 3},
    ala1=dict(raiz=R1, mat='ala',
              borde=[(0.0, -0.6, 0), (5.0, -1.5, 0), (10.0, -1.8, 0), (14.6, -1.4, 0), (15.4, 0.1, 1), (13.4, 1.9, 1),
                     (9.4, 3.5, 1), (5.2, 4.5, 1), (2.0, 4.7, 0), (0.6, 3.6, 0)],
              manchas=[(6.0, 1.0, 1.8, 0.8, 0.3, 'mota'), (10.4, 0.4, 1.4, 0.7, -0.2, 'mota'),
                       (13.2, 0.2, 0.9, 0.6, 0.0, 'mota'), (3.0, 2.6, 1.0, 0.7, 0.0, 'mota')]),
    ala2=dict(raiz=V((1.2, -0.6, Z - 0.35)), mat='ala_tras',
              borde=[(0.0, 0.0, 0), (4.0, 0.4, 0), (7.4, 1.6, 1), (8.2, 3.8, 1), (7.2, 6.0, 1), (4.6, 7.0, 1),
                     (2.0, 6.6, 0), (0.5, 4.6, 0)],
              manchas=[(4.8, 2.6, 3.4, 0.45, 0.35, 'banda'), (4.2, 5.4, 3.6, 0.45, 0.25, 'banda'),
                       (6.8, 4.0, 1.4, 2.9, 0.1, 'banda')]),
    extra='calavera',
)


def escena_version(vv, pose):
    pm._ala = ala_generica
    pm.ALA1 = vv['ala1']; pm.ALA2 = vv['ala2']
    L = pm.escena(pose)
    X = pm.huesos(pose)
    def add(fn, mat, k=0.0, grupo='cuerpo', hueso='raiz'):
        L.append((fn, mat, grupo, k, X['raiz'], hueso))
    if vv.get('extra') == 'tercer_ojo':
        # EL TERCER OJO, en el lomo del torax, mirando arriba.
        c = V((0.0, 2.6, Z + 2.45))
        add(lambda P: sd_elipsoide(P, c, V((1.25, 0.75, 0.30))), 'ocelo', 0, 'marca')
        add(lambda P: sd_elipsoide(P, c + V((0, 0, 0.08)), V((0.55, 0.55, 0.32))), 'iris', 0, 'marca')
        add(lambda P: sd_elipsoide(P, c + V((0, 0, 0.14)), V((0.30, 0.30, 0.32))), 'ocelo_n', 0, 'marca')
    if vv.get('extra') == 'calavera':
        # LA CALAVERA en el lomo del torax: el craneo palido con dos cuencas oscuras.
        c = V((0.0, 2.2, Z + 2.35))
        add(lambda P: sd_elipsoide(P, c, V((1.45, 1.35, 0.40))), 'craneo', 0, 'marca')
        add(lambda P: sd_elipsoide(P, c + V((0.0, 1.0, -0.1)), V((0.85, 0.6, 0.35))), 'craneo', 0, 'marca')
        for sx in (-1, 1):
            add(lambda P, sx=sx: sd_elipsoide(P, c + V((0.55 * sx, 0.35, 0.12)), V((0.42, 0.42, 0.35))), 'ocelo_n', 0,
                'marca')
    return L


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    # Arriba, el VIEJO.
    import json
    d = json.load(open('assets/sprites/enemigos/polilla_a48eaa_1.90.json'))
    im = Image.open('assets/sprites/enemigos/polilla_a48eaa_1.90.png').convert('RGBA')
    viejas = []
    for k in range(5):
        a = [x for x in d['anims'] if x['n'] == 'idle_%d' % k][0]
        x, y, w, h, ox, oy = a['f'][0]
        c = Image.new('RGBA', (d['w'], d['h'])); c.paste(im.crop((x, y, x + w, y + h)), (ox, oy)); viejas.append(c)
    filas.append(('viejo', viejas))
    for nombre, vv in VERSIONES.items():
        mat = dict(COMUN); mat.update(vv['mat'])
        mo = Modelo(2.0, (90, 90), (45, 45), mat, (0.05, 0.04, 0.05), suaves=('cuerpo', 'cabeza'), brillan=('brillo',),
                    corta_suelo=True, especular=('ojo',), umbral_especular=0.8)
        L = escena_version(vv, pm.POSE())
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok')
    W, H = 90, 90
    lam = Image.new('RGB', (W * 5 + 70, H * len(filas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    for j, (nombre, fotos) in enumerate(filas):
        dr.text((4, j * H + 40), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (70 + i * W, j * H), f)
    lam = lam.resize((lam.width * 3, lam.height * 3), Image.NEAREST)
    lam.save('tools/salida/sdf/polilla_versiones.png')
    print('tools/salida/sdf/polilla_versiones.png')
