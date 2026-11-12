# ============================================================
#  polilla_mut_sdf.py -- LOS MUTANTES DE LA POLILLA (12/11/2026, memoria polilla-mutante), ANIMADOS.
#    vigilia  VIGILIA DORADA (rango 1, Luz): la B ojos de polilla_versiones.py
#    mortaja  MORTAJA ALADA (rango 1, Oscuridad): la C boceto
#    insomne  POLILLA INSOMNE (rango 2, la mezcla): la R1 algo abierta de polilla_paneles_final.py (alas en PANELES, un ojo
#             rojo por ala, cuerpo negro, tercer ojo astral)
#  El cuerpo y las animaciones son los de polilla_sdf.py (sus claves de tiempo); cambian las alas, los colores y el tamaño.
#  Anims (las aprobadas el 12/11): las de la base (idle walk embestida aletear nube encaje muerte); luego evolucion y,
#  la insomne, ojo_carga y ojo.
#  Uso: POLILLA_MUT=vigilia|mortaja|insomne python tools/sprites_sdf/polilla_mut_sdf.py hoja [anim ...]
#         -> Desktop/ataques_mapa/enemigos/prueba_3d/mutantes/polilla_<mut>_hojas/ (para mirarla; no toca assets)
#       ... polilla_mut_sdf.py [anim ...]   -> assets/sprites/enemigos/polilla_sdf_<mut>/ (EL HORNO, tras su visto bueno)
# ============================================================
import sys, os, math
import numpy as np
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sdf_comun import *
import sdf_comun as sc
import polilla_sdf as pm
import polilla_versiones as pv
import polilla_paneles as pp
import polilla_paneles_final as pf

ast = pp.ast
MUT = os.environ.get('POLILLA_MUT', 'vigilia').lower()

if MUT == 'vigilia':
    _VV = pv.VERSIONES['B ojos']
elif MUT == 'mortaja':
    _VV = pv.VERSIONES['C boceto']
else:
    _VV = pf.VARIANTES['R1 algo abierta']

# LA LUZ DE LOS OJOS DE LA INSOMNE (12/11): niveles 0 (apagados) .. 3 (normal) .. 5 (a tope). Cada material que brilla
# tiene una copia por nivel ('m_rojo@4'); la pose dice cual ('luz') y escena() cambia los nombres. De uno en uno, sin saltos
# (memoria transiciones-de-color): la carga sube 3->5, el estallido baja 5->3 y al morir se apagan 3->0.
LUZ_NORMAL = 3
_BRILLAN = ('m_rojo_osc', 'm_rojo', 'm_rojo_vivo', 'astral_3', 'astral_4', 'astral_5', 'ojo', 'm_blanco')
_APAGADO = (0.12, 0.08, 0.09)
_A_TOPE = (1.0, 0.42, 0.10)   # a tope, ROJO-NARANJA ENCENDIDO como una brasa (12/11: el blanco calido lo lavaba a rosa)


def _nivel(c, k):
    if k < LUZ_NORMAL:
        u = (LUZ_NORMAL - k) / LUZ_NORMAL
        return tuple(c[i] * (1 - u) + _APAGADO[i] * u for i in range(3))
    u = (k - LUZ_NORMAL) * 0.30
    return tuple(c[i] * (1 - u) + _A_TOPE[i] * u for i in range(3))


if MUT == 'insomne':
    _mat = dict(_VV['mat'])
    _luces = list(_VV.get('brillan', ('brillo',)))
    for m in _BRILLAN:
        if m not in _mat:
            continue
        for k in range(6):
            _mat['%s@%d' % (m, k)] = [_nivel(c, k) for c in _mat[m]]
            if k > 0 and m != 'm_blanco':
                _luces.append('%s@%d' % (m, k))
    _VV = dict(_VV, mat=_mat, brillan=tuple(_luces))

MODELO = ast.mz.modelo(_VV)
# MAS LIENZO para las de alas picudas (12/11: la Mortaja se cortaba por arriba de frente; el lienzo sale del tamaño, y las
# puntas de la C suben mas que las alas redondas de la B).
_HOLGURA = {'vigilia': 1.0, 'mortaja': 1.3, 'insomne': 1.25}[MUT]
if _HOLGURA != 1.0:
    _lado = int(round(MODELO.W * _HOLGURA / 2)) * 2
    MODELO = Modelo(MODELO.ppu * 1.15, (_lado, _lado), (_lado // 2, _lado // 2), MODELO.mat, MODELO.borde,
                    suaves=('cuerpo', 'cabeza'), brillan=_VV.get('brillan', ('brillo',)), corta_suelo=True,
                    especular=('ojo',), umbral_especular=0.8)
LIENZO = (MODELO.W, MODELO.H)
ANIMS = dict(pm.ANIMS)
SALIDA = 'assets/sprites/enemigos/polilla_sdf_%s/' % MUT
VISTAS = 'tools/salida/sdf/polilla_%s/' % MUT


def escena(pose):
    # El ala de cada una: la generica (vigilia, mortaja) o la de paneles (insomne). polilla_mezcla_versiones envuelve la
    # generica para que acepte un ala por lado; con un ala normal hace lo mismo que la original.
    pv.ala_generica = pp.ala_paneles if MUT == 'insomne' else ast.mz._ala_por_lado
    if pose.get('_evo') is not None and MUT in ORIGEN:
        return _escena_evo(pose)
    if pose.get('_evo') is not None and MUT == 'insomne':
        return _escena_evo_insomne(pose)
    L = ast.escena(_VV, pose)
    luz = int(round(pose.get('luz', LUZ_NORMAL)))
    if MUT == 'insomne' and luz != LUZ_NORMAL:
        L = [(x[0], '%s@%d' % (x[1], luz) if x[1] in _BRILLAN else x[1]) + tuple(x[2:]) for x in L]
    return L


# ------------------------------------------------------------
#  LAS ANIMS NUEVAS DE LA INSOMNE (aprobadas el 12/11)
# ------------------------------------------------------------
def anim_ojo_carga(t):
    # EL AVISO del Ojo que se abre (bucle): alas abiertas y quietas ARRIBA, flotando, y los ojos LATIENDO (3-4-5-4).
    s = math.sin(2 * math.pi * t)
    return pm.POSE(bate=0.82 + 0.06 * s, abre=1.0, altura=1.0 + 0.05 * s, cabeceo=-0.5,
                   luz=LUZ_NORMAL + 1 + s)


def anim_ojo(t):
    # EL ESTALLIDO: los ojos a tope, un batido de golpe abriendose del todo, y la luz vuelve a su sitio.
    return pm.POSE(bate=tramos(t, [(0.0, 0.85), (0.2, 1.0), (0.4, -1.0), (0.6, -0.7), (0.8, -0.2), (1.0, 0.0)]),
                   abre=tramos(t, [(0.0, 1.0), (0.4, 1.0), (0.7, 0.6), (1.0, 0.3)]),
                   polvo=tramos(t, [(0.0, 0.0), (0.4, 0.7), (1.0, 1.0)]),
                   cabeceo=tramos(t, [(0.0, -0.5), (0.4, 1.3), (0.7, 0.5), (1.0, 0.0)]),
                   luz=tramos(t, [(0.0, 5.0), (0.45, 5.0), (0.7, 4.0), (1.0, 3.0)]))


def anim_muerte_insomne(t):
    # LA DE SIEMPRE, y los ojos SE APAGAN al caer (como la luz del miconido al morir).
    p = pm.anim_muerte(t)
    p['luz'] = tramos(t, [(0.0, 3.0), (0.3, 3.0), (0.6, 2.0), (0.8, 1.0), (1.0, 0.0)])
    return p


if MUT == 'insomne':
    ANIMS['ojo_carga'] = (8, 8.0, True, 8, anim_ojo_carga)
    ANIMS['ojo'] = (8, 12.0, False, 8, anim_ojo)
    ANIMS['muerte'] = (8, 11.0, False, 8, anim_muerte_insomne)


# ------------------------------------------------------------
#  LA EVOLUCION (12/11; "arranca en lo que era y se transforma, colores en transicion, no a saltos")
#  De la de ORIGEN (vigilia <- pavon A; mortaja <- calavera D) a la mutante, fotograma a fotograma: el TAMAÑO (la escala del
#  modelo), los COLORES (cada material, mezclado), el CONTORNO del ala (los dos remuestreados al mismo numero de puntos y
#  mezclados), los OJOS (los de antes se cierran y se abren los nuevos), la banda, los jirones que salen... Cada pose trae
#  su modelo (modelo_de): el horno lo sabe usar desde el 12/11 (sdf_comun.modelo_de).
# ------------------------------------------------------------
V = np.array
ORIGEN = {'vigilia': 'A pavon', 'mortaja': 'D calavera'}


def _lerp(a, b, u):
    return a + (b - a) * u


def _remuestrea(bd, n=28):
    """El contorno cerrado [(a, b, f)] en n puntos a la misma distancia; cada uno con el 'f' del vertice mas cercano."""
    pts = [(a, b) for a, b, _f in bd] + [(bd[0][0], bd[0][1])]
    largos = [0.0]
    for (a0, b0), (a1, b1) in zip(pts, pts[1:]):
        largos.append(largos[-1] + math.hypot(a1 - a0, b1 - b0))
    total = largos[-1]
    out = []
    for k in range(n):
        d = total * k / n
        j = max(0, min(len(largos) - 2, next(i for i in range(len(largos) - 1) if largos[i + 1] >= d)))
        w = (d - largos[j]) / max(1e-6, largos[j + 1] - largos[j])
        a = _lerp(pts[j][0], pts[j + 1][0], w); b = _lerp(pts[j][1], pts[j + 1][1], w)
        cerca = min(bd, key=lambda v: (v[0] - a) ** 2 + (v[1] - b) ** 2)
        out.append((a, b, cerca[2]))
    return out


def _centro(A):
    if 'centro' in A:
        return A['centro']
    bd = A['borde']
    return (sum(x[0] for x in bd) / len(bd), sum(x[1] for x in bd) / len(bd))


def _ala_evo(A0, A1, u):
    b0, b1 = _remuestrea(A0['borde']), _remuestrea(A1['borde'])
    c0, c1 = _centro(A0), _centro(A1)
    out = dict(raiz=A0['raiz'] * (1 - u) + A1['raiz'] * u, mat=A1['mat'] if u >= 0.5 else A0['mat'],
               borde=[(_lerp(p[0], q[0], u), _lerp(p[1], q[1], u), q[2] if u >= 0.5 else p[2]) for p, q in zip(b0, b1)],
               centro=(_lerp(c0[0], c1[0], u), _lerp(c0[1], c1[1], u)))
    w0 = A0['banda'][1] if A0.get('banda') else 0.0
    w1 = A1['banda'][1] if A1.get('banda') else 0.0
    w = _lerp(w0, w1, u)
    if w > 0.05:
        out['banda'] = ((A1 if A1.get('banda') else A0)['banda'][0], w)
    out['festones'] = A1.get('festones') if u >= 0.5 else A0.get('festones')
    if A1.get('jirones') and u > 0.25:   # el humo de la C le va saliendo
        k = (u - 0.25) / 0.75
        out.update(jirones=A1['jirones'], semilla=A1.get('semilla', 3),
                   jiron_r=tuple(x * k for x in A1.get('jiron_r', (0.55, 1.25))),
                   jiron_sale=tuple(x * k for x in A1.get('jiron_sale', (0.2, 1.0))))
    if u >= 0.6:
        for clave in ('contorno', 'rayos'):
            if A1.get(clave):
                out[clave] = A1[clave]
    out['lineas'] = A0.get('lineas', []) if u < 0.5 else A1.get('lineas', [])
    out['manchas'] = [(a, b, r1 * (1 - u), r2 * (1 - u), ang, m) for a, b, r1, r2, ang, m in A0.get('manchas', [])
                      if (1 - u) > 0.1] + [(a, b, r1 * u, r2 * u, ang, m) for a, b, r1, r2, ang, m in A1.get('manchas', [])
                                           if u > 0.1]
    out['ocelos'] = [(c, r * (1 - u), e) for c, r, e in A0.get('ocelos', []) if r * (1 - u) > 0.15] + \
                    [(c, r * u, e) for c, r, e in A1.get('ocelos', []) if r * u > 0.15]
    return out


def _mats_evo(m0, m1, u):
    out = dict(pv.COMUN)
    for k in set(m0) | set(m1):
        if k in m0 and k in m1 and len(m0[k]) == len(m1[k]):
            out[k] = [tuple(_lerp(a[i], b[i], u) for i in range(3)) for a, b in zip(m0[k], m1[k])]
        else:
            out[k] = (m1 if k in m1 else m0)[k]
    return out


def _vv_evo(u):
    v0, v1 = pv.VERSIONES[ORIGEN[MUT]], _VV
    return dict(mat=_mats_evo(v0['mat'], v1['mat'], u), escala=_lerp(v0.get('escala', 2.0), v1.get('escala', 2.0), u),
                ala1=_ala_evo(v0['ala1'], v1['ala1'], u), ala2=_ala_evo(v0['ala2'], v1['ala2'], u),
                extras=((v0.get('extra'), 1 - u), (v1.get('extra'), u)))


_MODELOS_EVO = {}


def modelo_de(pose):
    u = pose.get('_evo')
    if u is None:
        return MODELO
    k = (pose.get('_evo_de'), round(float(u), 4))
    if k not in _MODELOS_EVO:
        vv = _vv_evo_insomne(k[0], k[1]) if k[0] else _vv_evo(k[1])
        _MODELOS_EVO[k] = Modelo(vv['escala'] / 1.0, (MODELO.W, MODELO.H), (MODELO.OX, MODELO.OY), vv['mat'],
                                 MODELO.borde, suaves=('cuerpo', 'cabeza'),
                                 brillan=_VV.get('brillan', ('brillo',)) if k[0] else ('brillo',), corta_suelo=True,
                                 especular=('ojo',), umbral_especular=0.8)
    return _MODELOS_EVO[k]


def _extra(L, cual, k, pose):
    """El tercer ojo (la B) o la calavera (la D), a tamaño k (0..1): asi aparecen y se van creciendo y menguando."""
    if cual is None or k < 0.08:
        return
    X = pm.huesos(pose)
    Z = pm.VUELO_Z
    def add(fn, mat):
        L.append((fn, mat, 'marca', 0, X['raiz'], 'raiz'))
    if cual == 'tercer_ojo':
        c = V((0.0, 2.6, Z + 2.45))
        add(lambda P: sd_elipsoide(P, c, V((1.7 * k, 1.0 * k, 0.34))), 'ocelo')
        add(lambda P: sd_elipsoide(P, c + V((0, 0, 0.08)), V((0.75 * k, 0.75 * k, 0.36))), 'iris')
        add(lambda P: sd_elipsoide(P, c + V((0, 0, 0.14)), V((0.40 * k, 0.40 * k, 0.36))), 'ocelo_n')
    elif cual == 'calavera':
        c = V((0.0, 2.2, Z + 2.35))
        add(lambda P: sd_elipsoide(P, c, V((1.45 * k, 1.35 * k, 0.40))), 'craneo')
        add(lambda P: sd_elipsoide(P, c + V((0.0, 1.0 * k, -0.1)), V((0.85 * k, 0.6 * k, 0.35))), 'craneo')
        for sx in (-1, 1):
            add(lambda P, sx=sx: sd_elipsoide(P, c + V((0.55 * sx * k, 0.35 * k, 0.12)), V((0.42 * k, 0.42 * k, 0.35))),
                'ocelo_n')


def _escena_evo(pose):
    vv = _vv_evo(round(float(pose['_evo']), 4))
    pv.ala_generica = ast.mz._ala_por_lado
    L = pv.escena_version(dict(vv, extra=None), pose)
    for cual, k in vv['extras']:
        _extra(L, cual, k, pose)
    return L


def anim_evolucion(t):
    # Flota, las alas tiemblan cada vez mas y se abren del todo en medio (cuando mas cambia), y se asienta ya transformada.
    u = min(1.0, max(0.0, (t - 0.12) / 0.76))
    u = u * u * (3 - 2 * u)
    ola = math.sin(math.pi * t)
    return pm.POSE(bate=0.55 * math.sin(2 * math.pi * 3.0 * t) * (0.4 + 0.6 * ola), abre=0.9 * ola,
                   altura=1.0 + 0.18 * ola, cabeceo=-0.4 * ola, _evo=u)


if MUT in ORIGEN:
    ANIMS['evolucion'] = (20, 10.0, False, 8, anim_evolucion)


# ------------------------------------------------------------
#  LAS DOS EVOLUCIONES A LA INSOMNE (12/11): desde la Vigilia (evolucion_luz) y desde la Mortaja (evolucion_sombra).
#  1) El ala de antes se ESTIRA hacia la forma de paneles (picuda) y se ENNEGRECE; sus ojos y dibujos se cierran.
#  2) Los ojos rojos se ABREN DE DELANTE A ATRAS: el de la delantera, el de la trasera y, con la cola que le sale, el suyo.
#  3) El cuerpo a negro, los ojos del bicho a rojo y el tercer ojo astral le crece en el lomo.
# ------------------------------------------------------------
ORIGEN_INSOMNE = {'evolucion_luz': 'B ojos', 'evolucion_sombra': 'C boceto'}
_CUERPO = ('pelo', 'gola', 'anillo', 'antena', 'ojo')


def _paso(u, a, b):
    x = min(1.0, max(0.0, (u - a) / (b - a)))
    return x * x * (3 - 2 * x)


def _como_borde(quad):
    """Un cuadrilatero de paneles [raiz-delante, punta-delante, punta-detras, raiz-detras] como contorno del ala generica."""
    return [(quad[0][0], quad[0][1], 0), (quad[1][0], quad[1][1], 1), (quad[2][0], quad[2][1], 1),
            (quad[3][0], quad[3][1], 0)]


def _encoge(pts, f):
    cx = sum(a for a, _b in pts) / len(pts); cy = sum(b for _a, b in pts) / len(pts)
    return [(cx + (a - cx) * f, cy + (b - cy) * f) for a, b in pts]


def _gen_hacia(A0, quad, u):
    """El ala generica de antes, estirandose hacia 'quad' y quedandose sin dibujos."""
    forma = _paso(u, 0.0, 0.5)
    fuera = 1.0 - _paso(u, 0.0, 0.6)       # lo que le queda de sus dibujos
    b0, b1 = _remuestrea(A0['borde']), _remuestrea(_como_borde(quad))
    c0 = _centro(A0)
    c1 = (sum(a for a, _b in quad) / 4.0, sum(b for _a, b in quad) / 4.0)
    out = dict(raiz=A0['raiz'], mat=A0['mat'],
               borde=[(_lerp(p[0], q[0], forma), _lerp(p[1], q[1], forma), p[2]) for p, q in zip(b0, b1)],
               centro=(_lerp(c0[0], c1[0], forma), _lerp(c0[1], c1[1], forma)))
    if A0.get('banda') and A0['banda'][1] * fuera > 0.05:
        out['banda'] = (A0['banda'][0], A0['banda'][1] * fuera)
    if u < 0.35:
        for clave in ('festones', 'contorno', 'rayos', 'lineas'):
            if A0.get(clave):
                out[clave] = A0[clave]
    if A0.get('jirones') and fuera > 0.1:
        out.update(jirones=A0['jirones'], semilla=A0.get('semilla', 3),
                   jiron_r=tuple(x * fuera for x in A0.get('jiron_r', (0.55, 1.25))),
                   jiron_sale=tuple(x * fuera for x in A0.get('jiron_sale', (0.2, 1.0))))
    out['ocelos'] = [(c, r * fuera, e) for c, r, e in A0.get('ocelos', []) if r * fuera > 0.15]
    return out


def _ala_doble(add, p, s, A, nombre):
    if A.get('gen'):
        ast.mz._ala_por_lado(add, p, s, A['gen'], nombre)
    if A.get('pan'):
        pp.ala_paneles(add, p, s, A['pan'], nombre)


def _vv_evo_insomne(anim, u):
    v0 = pv.VERSIONES[ORIGEN_INSOMNE[anim]]
    fin1, fin2 = _VV['ala1'], _VV['ala2']
    tra, cola = fin2['silueta']
    color = _paso(u, 0.1, 0.8)
    mats = dict(pv.COMUN)
    mats.update(_VV['mat'])
    for k, c in v0['mat'].items():
        if k in ('ala', 'ala_tras'):
            dst = _VV['mat']['marco']
            mats[k] = [tuple(_lerp(a[i], b[i], color) for i in range(3)) for a, b in zip(c, dst)]
        elif k in _CUERPO and k in _VV['mat'] and len(c) == len(_VV['mat'][k]):
            mats[k] = [tuple(_lerp(a[i], b[i], color) for i in range(3)) for a, b in zip(c, _VV['mat'][k])]
        elif k not in ('ocelo_n', 'brillo'):
            mats[k] = c
    k1, k2, k3 = _paso(u, 0.45, 0.7), _paso(u, 0.58, 0.83), _paso(u, 0.7, 0.95)
    sale_cola = _paso(u, 0.45, 0.8)
    pan1 = dict(fin1, silueta=[], abiertos=[k1])
    pan2 = dict(fin2, silueta=[_encoge(cola, sale_cola)] if sale_cola > 0.05 else [], abiertos=[k2, k3])
    return dict(mat=mats, escala=_lerp(v0.get('escala', 2.0), _VV.get('escala', 2.0), _paso(u, 0.0, 0.9)),
                ala1=dict(raiz=fin1['raiz'], gen=_gen_hacia(v0['ala1'], fin1['silueta'][0], u), pan=pan1),
                ala2=dict(raiz=fin2['raiz'], gen=_gen_hacia(v0['ala2'], tra, u), pan=pan2),
                extras=((v0.get('extra'), 1 - _paso(u, 0.2, 0.6)), ('ojo_cielo', _paso(u, 0.6, 1.0))))


def _extra_cielo(L, k, pose):
    if k < 0.08:
        return
    X = pm.huesos(pose)
    c = V((0.0, 1.6, pm.VUELO_Z + 2.4))
    n = len(ast.ANILLOS)
    for j in range(n):
        f = (1.0 - 0.62 * j / n) * k
        L.append((lambda P, f=f, j=j: sd_elipsoide(P, c + V((0, 0, 0.06 * j)), V((2.6 * f, 1.7 * f, 0.34))),
                  'astral_%d' % j, 'marca', 0, X['raiz'], 'raiz'))
    L.append((lambda P: sd_elipsoide(P, c + V((0, 0, 0.06 * n)), V((0.62 * k, 0.62 * k, 0.34))), 'ocelo_n', 'marca', 0,
              X['raiz'], 'raiz'))


def _escena_evo_insomne(pose):
    vv = _vv_evo_insomne(pose['_evo_de'], round(float(pose['_evo']), 4))
    pv.ala_generica = _ala_doble
    L = pv.escena_version(dict(vv, extra=None), pose)
    for cual, k in vv['extras']:
        if cual == 'ojo_cielo':
            _extra_cielo(L, k, pose)
        else:
            _extra(L, cual, k, pose)
    return L


def _anim_evo_insomne(de):
    def fn(t):
        p = anim_evolucion(t)
        p['_evo_de'] = de
        return p
    return fn


if MUT == 'insomne':
    ANIMS['evolucion_luz'] = (20, 10.0, False, 8, _anim_evo_insomne('evolucion_luz'))
    ANIMS['evolucion_sombra'] = (20, 10.0, False, 8, _anim_evo_insomne('evolucion_sombra'))


def _hoja_ver(nombres):
    from PIL import Image, ImageDraw
    import sdf_gpu
    DIRS = (1, 4)     # SE de frente y N de espaldas
    pedidas = nombres or list(ANIMS.keys())
    # DE ANIMACION EN ANIMACION (12/11): las alas de paneles de la insomne tienen muchas piezas (cada anillo de cada ojo es
    # un poligono) y todas las anims de golpe no cabian en la memoria de la grafica.
    fotos = {}
    for nm in pedidas:
        trabajos = []; quien = []
        n, _fps, loop, _d, fn = ANIMS[nm]
        for d in DIRS:
            for i in range(n):
                t = i / n if loop else i / max(1, n - 1)
                pose = fn(t)
                trabajos.append((modelo_de(pose), escena(pose), d)); quien.append((nm, d, i))
        fotos.update(zip(quien, sdf_gpu.render_lote(trabajos)))
        print(nm, 'ok', flush=True)
    ESC = 3
    recortes = []
    for nm in pedidas:
        for d in DIRS:
            tira = [fotos[(nm, d, i)] for i in range(ANIMS[nm][0])]
            cajas = [f.getbbox() for f in tira if f.getbbox()]
            c = (min(x[0] for x in cajas) - 2, min(x[1] for x in cajas) - 2, max(x[2] for x in cajas) + 2,
                 max(x[3] for x in cajas) + 2)
            if c[0] <= 0 or c[1] <= 0 or c[2] >= LIENZO[0] or c[3] >= LIENZO[1]:
                print('OJO: %s d%d toca el borde del lienzo %s' % (nm, d, c))
            recortes.append(('%s d%d' % (nm, d), tira, c))
    ancho = 150 + max((c[2] - c[0]) * ESC * len(tira) for _, tira, c in recortes)
    alto = sum((c[3] - c[1]) * ESC + 6 for _, _, c in recortes)
    hoja = Image.new('RGB', (ancho, alto), (24, 26, 32))
    dib = ImageDraw.Draw(hoja)
    y = 0
    for nombre, tira, c in recortes:
        cw, ch = c[2] - c[0], c[3] - c[1]
        dib.text((6, y + ch * ESC // 2), nombre, fill=(235, 235, 235))
        for i, f in enumerate(tira):
            r = f.crop(c).resize((cw * ESC, ch * ESC), Image.NEAREST)
            hoja.paste(r, (150 + i * cw * ESC, y), r)
        y += ch * ESC + 6
    esc = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes',
                       'polilla_%s_hojas' % MUT)
    os.makedirs(esc, exist_ok=True)
    os.makedirs(VISTAS, exist_ok=True)
    nombre = 'polilla_%s_%s.png' % (MUT, '_'.join(nombres) if nombres and len(nombres) <= 3 else 'todas')
    hoja.save(os.path.join(esc, nombre))
    hoja.save(VISTAS + nombre)
    print(os.path.join(esc, nombre), hoja.size)


if __name__ == '__main__':
    args = sys.argv[1:]
    if args[:1] == ['hoja']:
        _hoja_ver(args[1:])
    else:
        hornear('polilla_mut_sdf', args or list(ANIMS.keys()), SALIDA, VISTAS)
