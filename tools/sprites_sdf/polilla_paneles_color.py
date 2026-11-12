# ============================================================
#  polilla_paneles_color.py -- COLORES PARA LA MEZCLA DE PANELES (12/11/2026). El jefe: "el formato lo tenemos, pero hay
#  que ver que hacer con el cuerpo y los colores... ¿mas asi o asi? con estos colores y el cuerpo negro completamente".
#  Sus dos referencias: (1) ojos almendrados NEGROS con el iris en aro BLANCO y la pupila negra rasgada, perfilados en
#  blanco; (2) negro con medias lunas blancas y un iris ROJO que brilla. El CUERPO, NEGRO del todo en todas.
#    Q1 blanco y negro    paneles negros, iris en aro blanco, pupila negra en rombo (rasgada)
#    Q2 perfil blanco     Q1 con el filo entre paneles en blanco (el perfil de su referencia)
#    Q3 ojo rojo          paneles negros, un aro blanco y el iris en anillos ROJOS que brillan
#    Q4 blanco y rojo     alas de Q2 y los ojos del cuerpo y el tercer ojo en rojo que brilla
#    Q5 neon cuerpo negro la P1 de antes (anillos neon) con el cuerpo negro, para comparar
#  Uso: python tools/sprites_sdf/polilla_paneles_color.py -> tools/salida/sdf/polilla_paneles_color.png
# ============================================================
import sys, os
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm
import polilla_versiones as pv
import polilla_paneles as pp

ast = pp.ast
tonos = pp.tonos


def t(c, brilla=False):
    return tonos(c, (0.8, 0.95, 1.0) if brilla else (0.62, 0.82, 1.0))


NEGRO = t((0.07, 0.06, 0.08))
COLORES = {
    'm_negro': NEGRO, 'm_negro2': t((0.12, 0.11, 0.13)), 'm_blanco': t((0.93, 0.92, 0.95)),
    'm_rojo_osc': t((0.55, 0.04, 0.06), True), 'm_rojo': t((0.92, 0.10, 0.10), True),
    'm_rojo_vivo': t((1.0, 0.40, 0.30), True),
}
# El CUERPO negro del todo (los tonos un pelin distintos para que se lea la forma).
CUERPO_NEGRO = {'pelo': t((0.09, 0.08, 0.10)), 'gola': t((0.13, 0.12, 0.14)), 'anillo': t((0.05, 0.05, 0.06)),
                'antena': t((0.16, 0.15, 0.17)), 'ojo': [(0.04, 0.04, 0.05)] * 3 + [(0.6, 0.6, 0.65)]}
OJOS_ROJOS = {'ojo': [(0.35, 0.02, 0.03), (0.70, 0.06, 0.06), (0.95, 0.20, 0.15), (1.0, 0.6, 0.5)]}

TERCER_BN = {'astral_%d' % k: c for k, c in enumerate(
    [NEGRO, t((0.93, 0.92, 0.95)), t((0.93, 0.92, 0.95)), NEGRO, t((0.93, 0.92, 0.95)), NEGRO])}
TERCER_ROJO = {'astral_%d' % k: c for k, c in enumerate(
    [NEGRO, t((0.93, 0.92, 0.95)), NEGRO, COLORES['m_rojo_osc'], COLORES['m_rojo'], COLORES['m_rojo_vivo']])}

BN = ['m_negro', 'm_negro2', 'm_blanco', 'm_blanco', 'm_blanco']
ROJO = ['m_negro', 'm_negro', 'm_blanco', 'm_negro', 'm_rojo_osc', 'm_rojo', 'm_rojo_vivo']


def alas(anillos, hueco=0.84):
    a1, a2 = pp.alas('marco', hueco=hueco)
    for a in (a1, a2):
        a['anillos'] = anillos
        a['gira'] = 0
    return a1, a2


BASE = dict(pp.CUERPO, **pp.NEON, **COLORES, **CUERPO_NEGRO)
VARIANTES = {}
a1, a2 = alas(BN)
VARIANTES['Q1 blanco y negro'] = dict(mat=dict(BASE, **TERCER_BN, marco=NEGRO), escala=3.4, brillan=('brillo',),
                                      ala1=a1, ala2=a2, extra='ojo_cielo')
a1, a2 = alas(BN, hueco=0.80)
VARIANTES['Q2 perfil blanco'] = dict(mat=dict(BASE, **TERCER_BN, marco=t((0.85, 0.85, 0.88))), escala=3.4,
                                     brillan=('brillo',), ala1=a1, ala2=a2, extra='ojo_cielo')
a1, a2 = alas(ROJO)
VARIANTES['Q3 ojo rojo'] = dict(mat=dict(BASE, **TERCER_ROJO, **OJOS_ROJOS, marco=NEGRO), escala=3.4,
                                brillan=('brillo', 'm_rojo_osc', 'm_rojo', 'm_rojo_vivo', 'astral_3', 'astral_4',
                                         'astral_5', 'ojo'), ala1=a1, ala2=a2, extra='ojo_cielo')
a1, a2 = alas(BN, hueco=0.80)
VARIANTES['Q4 blanco y rojo'] = dict(mat=dict(BASE, **TERCER_ROJO, **OJOS_ROJOS, marco=t((0.85, 0.85, 0.88))),
                                     escala=3.4, brillan=('brillo', 'astral_3', 'astral_4', 'astral_5', 'ojo'),
                                     ala1=a1, ala2=a2, extra='ojo_cielo')
VARIANTES['Q5 neon cuerpo negro'] = dict(pp.VARIANTES['P1 paneles negros'],
                                         mat=dict(pp.VARIANTES['P1 paneles negros']['mat'], **CUERPO_NEGRO))


if __name__ == '__main__':
    pv.ala_generica = pp.ala_paneles
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, vv in VARIANTES.items():
        mo = ast.mz.modelo(vv)
        L = ast.escena(vv, pm.POSE())
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 140, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (140 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/polilla_paneles_color.png')
    print('tools/salida/sdf/polilla_paneles_color.png')
