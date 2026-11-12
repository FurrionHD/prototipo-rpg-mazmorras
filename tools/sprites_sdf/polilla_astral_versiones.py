# ============================================================
#  polilla_astral_versiones.py -- LA MEZCLA "4 LUZ Y SOMBRA" EN ASTRAL (12/11/2026). El jefe eligio la 4 de
#  polilla_mezcla_versiones.py (delanteras de la B, traseras en cola de la C) y pidio que se vea "astral, magica", con su
#  referencia: silueta negra, un OJO enorme en el cielo con el iris en ANILLOS NEON (magenta, naranja, amarillo, verde,
#  cian, azul) y el color que se escapa alrededor del negro.
#    4  tal cual       la elegida, para comparar
#    A  ojo astral     alas negras; los ojos de delante pasan a ojos astrales de anillos neon que brillan
#    B  aura           A + el borde de las alas en neon (cian y magenta) y las colas deshilachadas en violeta que brilla
#    C  ojo del cielo  A + el TERCER OJO del lomo enorme y astral
#    D  cielo dentro   alas azul noche con pinceladas neon de colores y los ojos astrales
#    E  todo           B + C + D: aura, ojo del cielo y pinceladas
#  Uso: python tools/sprites_sdf/polilla_astral_versiones.py -> tools/salida/sdf/polilla_astral_versiones.png
# ============================================================
import sys, os
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import polilla_sdf as pm
import polilla_versiones as pv
import polilla_mezcla_versiones as mz

V = np.array
B, C = pv.VERSIONES['B ojos'], pv.VERSIONES['C boceto']
CUATRO = mz.MEZCLAS['4 luz y sombra']
tonos = mz.tonos

# Los anillos del ojo, de fuera a dentro (los de su referencia).
ANILLOS = [(1.0, 0.25, 0.75), (1.0, 0.50, 0.15), (1.0, 0.92, 0.30), (0.35, 1.0, 0.45), (0.25, 0.90, 1.0),
           (0.40, 0.38, 1.0)]
ASTRAL = {'astral_%d' % k: tonos(c, (0.75, 0.92, 1.0)) for k, c in enumerate(ANILLOS)}
NOMBRES_ASTRAL = tuple(ASTRAL.keys())
NEGRO = {'ala': tonos((0.06, 0.05, 0.08)), 'ala_tras_c': tonos((0.06, 0.05, 0.08)), 'pelo': tonos((0.08, 0.07, 0.10)),
         'ala_c': tonos((0.06, 0.05, 0.08))}


def astral(ala, **cambios):
    """El ala con sus ojos pasados a ASTRALES (mismo sitio, un poco mas grandes)."""
    a = dict(ala)
    a['ocelos'] = [((oa, ob), r * 1.1, 'astral') for (oa, ob), r, _e in a.get('ocelos', [])]
    a['_mats'] = NOMBRES_ASTRAL
    a.update(cambios)
    return a


PINCELADAS = [((2.6, -1.4), (6.4, 0.6), 'astral_0', 4, 0.5), ((6.0, 4.4), (11.0, 1.6), 'astral_4', 4, 0.5),
              ((9.4, -2.2), (12.8, -0.6), 'astral_2', 3, 0.4), ((3.0, 4.6), (5.6, 5.8), 'astral_3', 3, 0.3)]

VARIANTES = {}
VARIANTES['4 tal cual'] = CUATRO

VARIANTES['A ojo astral'] = dict(
    CUATRO, mat=dict(CUATRO['mat'], **ASTRAL, **NEGRO), brillan=('brillo',) + NOMBRES_ASTRAL,
    ala1=astral(B['ala1']),
    ala2=dict(CUATRO['ala2'], _mats=NOMBRES_ASTRAL),
)

VARIANTES['B aura'] = dict(
    VARIANTES['A ojo astral'],
    mat=dict(VARIANTES['A ojo astral']['mat'], borde=tonos((0.30, 0.90, 1.0)), linea=tonos((1.0, 0.30, 0.80)),
             humo=tonos((0.55, 0.30, 1.0))),
    brillan=('brillo', 'borde', 'linea', 'humo') + NOMBRES_ASTRAL,
)

VARIANTES['C ojo del cielo'] = dict(VARIANTES['A ojo astral'], extra='ojo_cielo')

VARIANTES['D cielo dentro'] = dict(
    VARIANTES['A ojo astral'],
    mat=dict(VARIANTES['A ojo astral']['mat'], ala=tonos((0.08, 0.08, 0.26)), ala_c=tonos((0.07, 0.07, 0.22)),
             ala_tras_c=tonos((0.07, 0.07, 0.22)), humo=tonos((0.25, 0.85, 1.0))),
    brillan=('brillo', 'humo') + NOMBRES_ASTRAL,
    ala1=astral(B['ala1'], lineas=PINCELADAS),
)

VARIANTES['E todo'] = dict(
    VARIANTES['B aura'], extra='ojo_cielo',
    mat=dict(VARIANTES['B aura']['mat'], ala=tonos((0.08, 0.08, 0.26)), ala_c=tonos((0.07, 0.07, 0.22)),
             ala_tras_c=tonos((0.07, 0.07, 0.22))),
    ala1=astral(B['ala1'], lineas=PINCELADAS),
)


# ------------------------------------------------------------
#  LA SEGUNDA REFERENCIA (12/11, "algo mas asi que es god"; y su duda: "no se si se ven bien las alas, como tiene mas
#  cosas"). A este tamaño los ojitos pequeños se pierden: lo que se lee son AREAS GRANDES. Asi que el color RELLENA el
#  ala en paneles de anillos neon, con un MARCO NEGRO gordo y formas picudas, como la suya.
#    F ojos gigantes   cada ala, UN ojo astral enorme que la llena casi entera; marco negro
#    G paneles         alas picudas (las de la C delante tambien), marco negro gordo, nervios negros que las parten en
#                      paneles y un ojo grande en cada uno
#    H violeta         G con el fondo del ala violeta que brilla (el morado de su referencia) en vez de negro
# ------------------------------------------------------------
MARCO = tonos((0.03, 0.02, 0.04))
CAMBIO_NEGRO = dict(VARIANTES['A ojo astral']['mat'], borde=MARCO, linea=MARCO, humo=MARCO)

VARIANTES['F ojos gigantes'] = dict(
    VARIANTES['A ojo astral'], mat=CAMBIO_NEGRO, brillan=('brillo',) + NOMBRES_ASTRAL, extra='ojo_cielo',
    ala1=dict(B['ala1'], banda=('borde', 1.0), festones=None, contorno=None, lineas=[], _mats=NOMBRES_ASTRAL,
              ocelos=[((7.8, 1.8), 4.6, 'astral')]),
    ala2=dict(CUATRO['ala2'], jirones=None, lineas=[], _mats=NOMBRES_ASTRAL, banda=('humo', 0.8),
              ocelos=[((5.0, 5.0), 3.6, 'astral'), ((4.3, 11.4), 2.4, 'astral')]),
)

PICUDA1 = dict(mz.de_c(C['ala1']), mat='ala', jirones=None, lineas=[], banda=('borde', 1.0), _mats=NOMBRES_ASTRAL,
               rayos=((1.0, 1.0), 1.0, 1.3, 'linea', 4),
               ocelos=[((9.8, -2.4), 3.0, 'astral'), ((10.6, 2.6), 2.6, 'astral'), ((5.2, 2.8), 2.4, 'astral')])
PICUDA2 = dict(CUATRO['ala2'], mat='ala_tras_c', jirones=None, lineas=[], banda=('humo', 0.8), _mats=NOMBRES_ASTRAL,
               ocelos=[((5.0, 4.6), 3.0, 'astral'), ((4.4, 10.6), 2.2, 'astral'), ((5.8, 16.4), 1.6, 'astral')])

VARIANTES['G paneles'] = dict(
    VARIANTES['A ojo astral'], mat=CAMBIO_NEGRO, brillan=('brillo',) + NOMBRES_ASTRAL, extra='ojo_cielo',
    ala1=PICUDA1, ala2=PICUDA2,
)

VIOLETA = tonos((0.45, 0.16, 0.62))
VARIANTES['H violeta'] = dict(
    VARIANTES['G paneles'], brillan=('brillo', 'ala', 'ala_tras_c') + NOMBRES_ASTRAL,
    mat=dict(CAMBIO_NEGRO, ala=VIOLETA, ala_tras_c=VIOLETA),
)

for _k in ['A ojo astral', 'B aura', 'C ojo del cielo', 'D cielo dentro']:
    del VARIANTES[_k]


def escena(vv, pose):
    extra = vv.get('extra')
    L = pv.escena_version(dict(vv, extra=None if extra == 'ojo_cielo' else extra), pose)
    if extra == 'ojo_cielo':
        # EL OJO DEL CIELO: el tercer ojo del lomo, grande y en anillos, mirando arriba.
        X = pm.huesos(pose)
        c = V((0.0, 1.6, pm.VUELO_Z + 2.4))
        n = len(ANILLOS)
        for k in range(n):
            f = 1.0 - 0.62 * k / n
            L.append((lambda P, f=f, k=k: sd_elipsoide(P, c + V((0, 0, 0.06 * k)), V((2.6 * f, 1.7 * f, 0.34))),
                      'astral_%d' % k, 'marca', 0, X['raiz'], 'raiz'))
        L.append((lambda P: sd_elipsoide(P, c + V((0, 0, 0.06 * n)), V((0.62, 0.62, 0.34))), 'ocelo_n', 'marca', 0,
                  X['raiz'], 'raiz'))
        L.append((lambda P: sd_elipsoide(P, c + V((-0.25, 0.25, 0.06 * n + 0.08)), V((0.22, 0.22, 0.3))), 'brillo',
                  'marca', 0, X['raiz'], 'raiz'))
    return L


if __name__ == '__main__':
    os.makedirs('tools/salida/sdf', exist_ok=True)
    filas = []
    for nombre, vv in VARIANTES.items():
        mo = mz.modelo(vv)
        L = escena(vv, pm.POSE())
        filas.append((nombre, [render(mo, L, dd) for dd in range(5)]))
        print(nombre, 'ok', flush=True)
    W = max(f[1][0].size[0] for f in filas)
    alturas = [f[1][0].size[1] for f in filas]
    lam = Image.new('RGB', (W * 5 + 120, sum(alturas)), (40, 42, 50))
    dr = ImageDraw.Draw(lam)
    y0 = 0
    for j, (nombre, fotos) in enumerate(filas):
        h = alturas[j]
        dr.text((4, y0 + h // 2), nombre, fill=(220, 220, 220))
        for i, f in enumerate(fotos):
            lam.paste(f, (120 + i * W + (W - f.size[0]) // 2, y0), f)
        y0 += h
    lam = lam.resize((lam.width * 2, lam.height * 2), Image.NEAREST)
    lam.save('tools/salida/sdf/polilla_astral_versiones.png')
    print('tools/salida/sdf/polilla_astral_versiones.png')
