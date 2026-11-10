#!/usr/bin/env python3
# ============================================================
#  miconido_puntas.py -- DE DONDE SALEN LOS EFECTOS DEL MICONIDO Y SUS MUTANTES (10/11/2026, efectos en pixel).
#  La regla (05/11, la segadora): el corte es la estela de la PUNTA del arma y lo que sale del cuerpo sale de SU sitio,
#  medido en el modelo 3D fotograma a fotograma (cada cuarto), no inventado:
#    normal   'micelio'    la MANO del brazo que lanza el latigo (el de camara: escena_dir)       -> 'mano'
#    campana  'embestida'  la punta de los TRES FILAMENTOS de delante que se lanzan al frente     -> 'fil2' 'fil3' 'fil4'
#    florecido 'embestida' y 'estocada'  la PUNTA DE LA ESPADA                                     -> 'espada'
#  Uso: python tools/sprites_sdf/miconido_puntas.py  -> tools/salida/sdf/puntas_miconido_<var>.json
#  {'anim|dir|fotograma|nombre': [x, y]} en pixeles del lienzo de su hoja.
# ============================================================
import importlib
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import sdf_comun as sc  # noqa: E402

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SUB = 4


def _extremos(L, grupo, mat):
    """Los puntos (mundo) de las piezas de 'grupo' (y material 'mat', o cualquiera): extremos de conos, centros de
    esferas/elipsoides y los dos cabos del eje largo de una caja."""
    pts = []
    for fn, m, g, k, X, nh in L:
        if g != grupo or (mat and m.split('>')[0] != mat):
            continue
        r = fn(sc.SONDA)
        if not isinstance(r, tuple):
            continue
        qs = []
        if r[0] == 'cono':
            qs = [r[1], r[2]]
        elif r[0] in ('esfera', 'elipsoide'):
            qs = [r[1]]
        elif r[0] == 'caja':
            c, ejes, medio = np.asarray(r[1], float), np.asarray(r[2], float), np.asarray(r[3], float)
            i = int(np.argmax(medio))
            qs = [c + ejes[i] * medio[i], c - ejes[i] * medio[i]]
        for q in qs:
            pts.append(X[0] @ np.asarray(q, dtype=float) + X[1])
    return pts


def _mas_lejos(pts, desde):
    return max(pts, key=lambda q: float(np.linalg.norm(q - desde))) if pts else None


def medir(mod, anims, que, escena_fn):
    sal = {}
    for nm in anims:
        n, _fps, loop, dirs, fn = mod.ANIMS[nm]
        for d in range(min(dirs, 5)):
            for k in range((n - 1) * SUB + 1 if not loop else n * SUB):
                fr = k / SUB
                t = fr / n if loop else (fr / (n - 1) if n > 1 else 0.0)
                L = escena_fn(fn(t), d)
                for nombre, (grupos, mat, base) in que(d).items():
                    pts = []
                    for g in grupos:
                        pts += _extremos(L, g, mat)
                    bpts = []
                    for g in base:
                        bpts += _extremos(L, g, None)
                    if not pts:
                        continue
                    ref = bpts[0] if bpts else pts[0]
                    q = _mas_lejos(pts, ref)
                    x, y = sc.a_pantalla(mod.MODELO, q, d)
                    sal['%s|%d|%.2f|%s' % (nm, d, fr, nombre)] = [float(x), float(y)]
    return sal


def principal():
    os.makedirs(os.path.join(RAIZ, 'tools/salida/sdf'), exist_ok=True)
    # EL NORMAL: la mano del brazo del latigo
    import miconido_sdf as mn
    lado = mn._lado_del_latigo
    que_n = lambda d: {'mano': (['brazo%d' % lado(d)], None, ['brazo%d' % lado(d)])}
    esc_n = (lambda p, d: mn.escena_dir(p, d)) if hasattr(mn, 'escena_dir') else (lambda p, d: mn.escena(p))
    out = medir(mn, ['micelio'], que_n, esc_n)
    json.dump(out, open(os.path.join(RAIZ, 'tools/salida/sdf/puntas_miconido_normal.json'), 'w'))
    print('normal', len(out))
    for var in ('campana', 'florecido'):
        os.environ['MIC_VAR'] = var
        if 'miconido_mut_sdf' in sys.modules:
            mm = importlib.reload(sys.modules['miconido_mut_sdf'])
        else:
            mm = importlib.import_module('miconido_mut_sdf')
        if var == 'campana':
            que = lambda d: {'fil%d' % k: (['fil%d' % k], None, ['campana']) for k in (2, 3, 4)}
            anims = ['embestida']
        else:
            que = lambda d: {'espada': (['hoja'], None, ['puno'])}
            anims = ['embestida', 'estocada']
        out = medir(mm, anims, que, lambda p, d: mm.escena_dir(p, d))
        json.dump(out, open(os.path.join(RAIZ, 'tools/salida/sdf/puntas_miconido_%s.json' % var), 'w'))
        print(var, len(out))


if __name__ == '__main__':
    principal()
