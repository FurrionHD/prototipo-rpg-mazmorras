# ============================================================
#  polilla_luz_versiones.py -- OPCIONES DE CUERPO PARA LOS MUTANTES DE LA POLILLA (12/11/2026). Los mutantes son MAGICOS
#  y de LUZ (memoria polilla-mutante): el jefe quiere ver "muchas opciones visuales, mas las que teniamos de reserva".
#  Las de reserva son las del 05/10 (polilla_versiones.py): B ojos y C boceto. Las nuevas usan la misma ala generica y
#  ademas partes que BRILLAN (el polvo de luz):
#    E luna      la polilla luna: alas verde palido casi blancas, borde lila, traseras en cola larga
#    F lumbre    alas casi negras con el borde y los ojos de ORO que brillan (la luz que lleva dentro)
#    G vidriera  alas oscuras con celdas de colores que brillan como una vidriera de capilla
#    H plata     alas blancas de plata, nervios y ojos dorados que brillan (la mas "sagrada")
#    I eclipse   negra del todo con un anillo de luz por dentro del borde y dianas de luz (el sol tapado)
#  Solo QUIETAS, las cinco direcciones. Uso: python tools/sprites_sdf/polilla_luz_versiones.py
#    -> tools/salida/sdf/polilla_luz_versiones.png
# ============================================================
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm
import polilla_versiones as pv

B, C = pv.VERSIONES['B ojos'], pv.VERSIONES['C boceto']
COLA = C['ala2']['borde']          # las traseras en cola del boceto
R1, R2 = pv.R1, pv.R2
DEL, TRA = pv.DEL_SATURNIA, pv.TRA_SATURNIA


def tonos(c, k=(0.62, 0.82, 1.0)):
    return [tuple(min(1.0, v * f) for v in c) for f in k]


ORO = tonos((1.0, 0.82, 0.38))
LUZ = tonos((1.0, 0.97, 0.80))

NUEVAS = {}

NUEVAS['E luna'] = dict(
    mat={'ala': tonos((0.80, 0.92, 0.80)), 'ala_tras': tonos((0.74, 0.88, 0.76)),
         'borde': tonos((0.66, 0.48, 0.74)), 'linea': tonos((0.62, 0.46, 0.70)),
         'ocelo': tonos((0.95, 0.92, 0.80)), 'ocelo_n': tonos((0.45, 0.30, 0.50)),
         'iris': tonos((0.72, 0.58, 0.40)), 'rojo': tonos((0.66, 0.40, 0.66)),
         'pelo': tonos((0.92, 0.92, 0.88)), 'gola': tonos((0.62, 0.42, 0.66)),
         'anillo': tonos((0.86, 0.86, 0.82)), 'antena': tonos((0.80, 0.72, 0.50))},
    escala=2.35,
    ala1=dict(raiz=R1, mat='ala', borde=DEL, banda=('borde', 0.9), festones=None,
              lineas=[((3.6, -1.2), (3.0, 5.6), 'linea', 6, 0.35)],
              ocelos=[((8.0, 1.6), 1.7, 'saturnia')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=COLA, banda=('borde', 0.8), centro=(4.6, 6.0),
              ocelos=[((5.4, 5.2), 1.5, 'saturnia')]),
)

NUEVAS['F lumbre'] = dict(
    mat={'ala': tonos((0.12, 0.09, 0.08)), 'ala_tras': tonos((0.10, 0.08, 0.07)),
         'borde': ORO, 'linea': ORO, 'ocelo': LUZ, 'iris': ORO, 'ocelo_n': tonos((0.35, 0.20, 0.05)),
         'pelo': tonos((0.16, 0.12, 0.10)), 'gola': ORO, 'anillo': ORO, 'antena': ORO},
    escala=3.0, brillan=('brillo', 'borde', 'ocelo', 'iris'),
    ala1=dict(B['ala1'], banda=('borde', 0.6)),
    ala2=dict(B['ala2'], banda=('borde', 0.6)),
    extra='tercer_ojo',
)

NUEVAS['G vidriera'] = dict(
    mat={'ala': tonos((0.08, 0.08, 0.10)), 'ala_tras': tonos((0.07, 0.07, 0.09)),
         'borde': tonos((0.30, 0.28, 0.34)), 'linea': tonos((0.30, 0.28, 0.34)),
         'v_rojo': tonos((0.95, 0.30, 0.30)), 'v_ambar': tonos((1.0, 0.72, 0.25)),
         'v_azul': tonos((0.35, 0.55, 1.0)), 'v_verde': tonos((0.40, 0.85, 0.50)),
         'ocelo': LUZ, 'iris': tonos((0.6, 0.4, 0.9)),
         'pelo': tonos((0.12, 0.12, 0.14)), 'gola': tonos((0.35, 0.55, 1.0)), 'anillo': tonos((0.30, 0.28, 0.34)),
         'antena': tonos((0.40, 0.38, 0.44))},
    escala=2.6, brillan=('brillo', 'v_rojo', 'v_ambar', 'v_azul', 'v_verde', 'ocelo'),
    ala1=dict(raiz=R1, mat='ala', borde=DEL, banda=('borde', 0.6), contorno=(1.5, 'linea'),
              manchas=[(4.6, 0.8, 2.2, 1.7, 0.3, 'v_azul'), (8.6, -0.4, 2.1, 1.6, 0.0, 'v_ambar'),
                       (11.8, -0.4, 1.5, 1.3, -0.2, 'v_rojo'), (7.6, 3.8, 2.0, 1.5, 0.4, 'v_verde'),
                       (10.8, 2.8, 1.5, 1.3, 0.2, 'v_azul'), (3.2, 4.0, 1.4, 1.2, 0.0, 'v_rojo')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA, banda=('borde', 0.6), contorno=(1.4, 'linea'),
              manchas=[(3.4, 2.6, 1.9, 1.5, 0.2, 'v_ambar'), (6.6, 4.4, 1.9, 1.5, 0.5, 'v_rojo'),
                       (4.8, 7.8, 2.0, 1.6, 0.3, 'v_azul'), (2.0, 6.4, 1.4, 1.2, 0.0, 'v_verde')],
              ocelos=[((5.0, 5.6), 0.9, 'diana')]),
)

NUEVAS['H plata'] = dict(
    mat={'ala': tonos((0.86, 0.86, 0.90)), 'ala_tras': tonos((0.80, 0.80, 0.86)),
         'borde': ORO, 'linea': ORO, 'ocelo': LUZ, 'iris': ORO, 'rojo': tonos((0.95, 0.75, 0.35)),
         'ocelo_n': tonos((0.55, 0.40, 0.15)),
         'pelo': tonos((0.95, 0.94, 0.90)), 'gola': ORO, 'anillo': tonos((0.90, 0.88, 0.82)), 'antena': ORO},
    escala=2.6, brillan=('brillo', 'linea', 'borde', 'ocelo'),
    ala1=dict(raiz=R1, mat='ala', borde=DEL, banda=('borde', 0.7), festones='ala',
              rayos=((1.0, 1.6), 1.2, 1.4, 'linea', 7),
              ocelos=[((8.4, 1.4), 2.2, 'saturnia')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA, banda=('borde', 0.7), festones='ala_tras',
              rayos=((1.0, 1.2), 1.2, 1.4, 'linea', 6),
              ocelos=[((5.4, 5.6), 2.0, 'saturnia')]),
)

NUEVAS['I eclipse'] = dict(
    mat={'ala': tonos((0.04, 0.04, 0.05)), 'ala_tras': tonos((0.04, 0.04, 0.05)),
         'linea': LUZ, 'ocelo': LUZ, 'ocelo_n': tonos((0.04, 0.04, 0.05)),
         'humo': tonos((0.08, 0.08, 0.10)), 'iris': LUZ,
         'pelo': tonos((0.06, 0.06, 0.07)), 'gola': LUZ, 'anillo': tonos((0.10, 0.10, 0.12)), 'antena': LUZ},
    escala=3.0, brillan=('brillo', 'linea', 'ocelo'),
    ala1=dict(C['ala1'], contorno=(1.6, 'linea'), lineas=[]),
    ala2=dict(C['ala2'], contorno=(1.4, 'linea'), lineas=[]),
)

# ------------------------------------------------------------
#  Y OTRAS QUE NO SON DE LUZ (12/11, el jefe: "no tiene por que ser de luz, inventa cosas extra")
#    J escarcha    alas de hielo azul con jirones de escarcha y nervios blancos que brillan (el elemento nuevo)
#    K arcana      morado profundo con runas de magia pura que brillan y tercer ojo (sin elemento)
#    L brasas      alas de carbon con el borde al rojo y vetas de fuego que brillan
#    M abisal      azul noche con un cielo de estrellas dentro
#    N espora      su origen llevado lejos: bioluminiscente, borde de setitas y esporas verdes que brillan
# ------------------------------------------------------------
NUEVAS['J escarcha'] = dict(
    mat={'ala': tonos((0.55, 0.78, 0.95)), 'ala_tras': tonos((0.50, 0.72, 0.92)),
         'borde': tonos((0.92, 0.97, 1.0)), 'linea': tonos((0.92, 0.97, 1.0)), 'ocelo': tonos((0.92, 0.97, 1.0)),
         'ocelo_n': tonos((0.25, 0.45, 0.70)), 'humo': tonos((0.75, 0.90, 1.0)),
         'pelo': tonos((0.90, 0.95, 1.0)), 'gola': tonos((0.60, 0.80, 1.0)), 'anillo': tonos((0.45, 0.65, 0.85)),
         'antena': tonos((0.85, 0.93, 1.0)), 'iris': tonos((0.6, 0.8, 1.0))},
    escala=2.6, brillan=('brillo', 'linea', 'borde'),
    ala1=dict(C['ala1'], jirones='humo', rayos=((1.0, 1.0), 1.2, 1.6, 'linea', 7), lineas=[]),
    ala2=dict(C['ala2'], jirones='humo', lineas=[]),
)

NUEVAS['K arcana'] = dict(
    mat={'ala': tonos((0.22, 0.10, 0.34)), 'ala_tras': tonos((0.18, 0.08, 0.30)),
         'borde': tonos((0.55, 0.30, 0.85)), 'linea': tonos((0.85, 0.60, 1.0)), 'ocelo': tonos((0.90, 0.70, 1.0)),
         'ocelo_n': tonos((0.22, 0.10, 0.34)), 'iris': tonos((0.95, 0.85, 1.0)),
         'pelo': tonos((0.20, 0.10, 0.30)), 'gola': tonos((0.85, 0.60, 1.0)), 'anillo': tonos((0.40, 0.22, 0.60)),
         'antena': tonos((0.85, 0.60, 1.0))},
    escala=2.6, brillan=('brillo', 'linea', 'ocelo'),
    ala1=dict(raiz=R1, mat='ala', borde=DEL, banda=('borde', 0.6), contorno=(1.3, 'linea'),
              lineas=[((4.0, -1.0), (4.0, 5.0), 'linea', 4, 0.9), ((11.0, -1.6), (9.0, 4.0), 'linea', 4, 0.8)],
              ocelos=[((7.6, 1.4), 1.8, 'diana')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA, banda=('borde', 0.6), contorno=(1.2, 'linea'),
              lineas=[((2.6, 2.0), (6.6, 8.0), 'linea', 5, 0.7)],
              ocelos=[((5.6, 5.2), 1.6, 'diana')]),
    extra='tercer_ojo',
)

NUEVAS['L brasas'] = dict(
    mat={'ala': tonos((0.13, 0.11, 0.10)), 'ala_tras': tonos((0.11, 0.09, 0.08)),
         'borde': tonos((1.0, 0.42, 0.10)), 'linea': tonos((1.0, 0.62, 0.20)), 'ocelo': tonos((1.0, 0.80, 0.35)),
         'ocelo_n': tonos((0.45, 0.10, 0.04)), 'iris': tonos((1.0, 0.45, 0.10)), 'humo': tonos((0.22, 0.20, 0.20)),
         'rojo': tonos((1.0, 0.30, 0.08)),
         'pelo': tonos((0.18, 0.14, 0.12)), 'gola': tonos((1.0, 0.42, 0.10)), 'anillo': tonos((0.55, 0.18, 0.06)),
         'antena': tonos((0.60, 0.30, 0.15))},
    escala=2.6, brillan=('brillo', 'borde', 'linea', 'ocelo'),
    ala1=dict(raiz=R1, mat='ala', borde=DEL, banda=('borde', 0.7), festones='humo',
              lineas=[((3.6, -1.2), (3.0, 5.6), 'linea', 6, 0.6), ((10.4, -2.6), (8.0, 5.8), 'linea', 7, 0.6)],
              ocelos=[((8.0, 1.6), 1.6, 'saturnia')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA, banda=('borde', 0.7), festones='humo',
              lineas=[((6.4, 1.6), (2.2, 9.6), 'linea', 7, 0.6)]),
)

NUEVAS['M abisal'] = dict(
    mat={'ala': tonos((0.06, 0.08, 0.20)), 'ala_tras': tonos((0.05, 0.06, 0.16)),
         'borde': tonos((0.30, 0.20, 0.55)), 'linea': tonos((0.50, 0.40, 0.85)),
         'estrella': tonos((1.0, 0.98, 0.85)), 'estrella_c': tonos((0.65, 0.85, 1.0)),
         'ocelo': tonos((0.85, 0.90, 1.0)), 'ocelo_n': tonos((0.06, 0.08, 0.20)), 'iris': tonos((0.6, 0.5, 1.0)),
         'pelo': tonos((0.08, 0.08, 0.18)), 'gola': tonos((0.50, 0.40, 0.85)), 'anillo': tonos((0.20, 0.18, 0.40)),
         'antena': tonos((0.55, 0.50, 0.85))},
    escala=3.0, brillan=('brillo', 'estrella', 'estrella_c', 'ocelo'),
    ala1=dict(raiz=R1, mat='ala', borde=DEL, banda=('borde', 0.8), festones='ala',
              manchas=[(3.0, 0.4, 0.35, 0.35, 0, 'estrella'), (5.6, -0.8, 0.45, 0.45, 0, 'estrella_c'),
                       (8.0, 3.6, 0.35, 0.35, 0, 'estrella'), (10.8, -1.2, 0.5, 0.5, 0, 'estrella'),
                       (12.2, 1.4, 0.35, 0.35, 0, 'estrella_c'), (6.6, 4.8, 0.4, 0.4, 0, 'estrella'),
                       (4.0, 3.2, 0.3, 0.3, 0, 'estrella_c'), (9.6, 1.6, 0.3, 0.3, 0, 'estrella')],
              ocelos=[((7.6, 1.2), 1.4, 'diana')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA, banda=('borde', 0.8), festones='ala_tras',
              manchas=[(2.4, 2.0, 0.4, 0.4, 0, 'estrella'), (5.4, 3.2, 0.3, 0.3, 0, 'estrella_c'),
                       (7.6, 5.6, 0.45, 0.45, 0, 'estrella'), (4.0, 8.4, 0.35, 0.35, 0, 'estrella'),
                       (2.0, 6.2, 0.3, 0.3, 0, 'estrella_c'), (6.0, 9.2, 0.3, 0.3, 0, 'estrella_c')]),
)

NUEVAS['N espora'] = dict(
    mat={'ala': tonos((0.20, 0.17, 0.14)), 'ala_tras': tonos((0.17, 0.15, 0.12)),
         'borde': tonos((0.40, 0.33, 0.24)), 'seta': tonos((0.78, 0.62, 0.42)),
         'espora': tonos((0.55, 1.0, 0.55)), 'linea': tonos((0.45, 0.95, 0.55)),
         'ocelo': tonos((0.55, 1.0, 0.55)), 'ocelo_n': tonos((0.10, 0.25, 0.12)), 'iris': tonos((0.8, 1.0, 0.7)),
         'pelo': tonos((0.30, 0.25, 0.18)), 'gola': tonos((0.55, 1.0, 0.55)), 'anillo': tonos((0.32, 0.27, 0.20)),
         'antena': tonos((0.55, 1.0, 0.55))},
    escala=2.6, brillan=('brillo', 'espora', 'linea', 'ocelo'),
    ala1=dict(raiz=R1, mat='ala', borde=DEL, banda=('borde', 0.8), festones='seta',
              lineas=[((3.6, -1.2), (3.0, 5.6), 'linea', 5, 0.4)],
              manchas=[(6.0, 0.2, 0.5, 0.5, 0, 'espora'), (9.4, 3.4, 0.45, 0.45, 0, 'espora'),
                       (11.6, -0.6, 0.4, 0.4, 0, 'espora'), (5.0, 4.0, 0.35, 0.35, 0, 'espora')],
              ocelos=[((8.4, 1.0), 1.5, 'diana')]),
    ala2=dict(raiz=R2, mat='ala_tras', borde=TRA, banda=('borde', 0.8), festones='seta',
              manchas=[(3.0, 3.0, 0.45, 0.45, 0, 'espora'), (6.6, 6.0, 0.5, 0.5, 0, 'espora'),
                       (4.0, 8.8, 0.4, 0.4, 0, 'espora')]),
)


def modelo(vv):
    mat = dict(pv.COMUN); mat.update(vv['mat'])
    esc = vv.get('escala', 2.0)
    lado = int(round(90 * esc / 2.0 / 2)) * 2
    return Modelo(esc, (lado, lado), (lado // 2, lado // 2), mat, (0.05, 0.04, 0.05), suaves=('cuerpo', 'cabeza'),
                  brillan=vv.get('brillan', ('brillo',)), corta_suelo=True, especular=('ojo',), umbral_especular=0.8)


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    lista = [('B ojos (reserva)', B), ('C boceto (reserva)', C)] + list(NUEVAS.items())
    filas = []
    for nombre, vv in lista:
        mo = modelo(vv)
        L = pv.escena_version(vv, pm.POSE())
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 110, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (110 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/polilla_luz_versiones.png')
    print('tools/salida/sdf/polilla_luz_versiones.png')
