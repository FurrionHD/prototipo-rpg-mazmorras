# TROZOS SUELTOS EN LOS MARCOS DE LAS HOJAS DE ENEMIGOS (20/11/2026, memoria pixeles-colados-piezas-sin-hueso). El jefe:
# "se le cuelan pixeles de la imagen de abajo". Casi siempre es una PIEZA DEL GENERADOR QUE NO SIGUE A SU HUESO (la punta de
# luz de la cola del Cazador lunar se quedaba quieta mientras la cola barria): en el marco sale un trocito separado del
# cuerpo, pegado al borde. Por hoja: cuantos hay y en que animaciones/marcos (marco, pixeles, borde). Los jirones de humo
# o los adornos sueltos a proposito tambien salen: hay que mirarlos (tools/sprites_sdf hoja ampliada).
#   python tools/trozos_sueltos.py acechador3d        (el principio del nombre de las hojas de assets/sprites/enemigos)
import json, glob, sys
import numpy as np
from PIL import Image
from collections import deque

def comps(f):
    h, w = f.shape
    lab = np.zeros((h, w), int)
    out = []
    n = 0
    for y in range(h):
        for x in range(w):
            if f[y, x] and not lab[y, x]:
                n += 1
                q = deque([(y, x)]); lab[y, x] = n; pts = []
                while q:
                    cy, cx = q.popleft(); pts.append((cy, cx))
                    for dy in (-1, 0, 1):
                        for dx in (-1, 0, 1):
                            yy, xx = cy + dy, cx + dx
                            if 0 <= yy < h and 0 <= xx < w and f[yy, xx] and not lab[yy, xx]:
                                lab[yy, xx] = n; q.append((yy, xx))
                out.append(pts)
    return out

patron = sys.argv[1]
for js in sorted(glob.glob('assets/sprites/enemigos/%s*.json' % patron)):
    d = json.load(open(js, encoding='utf-8'))
    a = np.asarray(Image.open(js[:-5] + '.png').convert('RGBA'))[..., 3]
    malos = {}
    vistos = set()
    for an in d['anims']:
        for i, m in enumerate(an['f']):
            x, y, w, h = map(int, m[:4])
            if w <= 0 or (x, y) in vistos:
                continue
            vistos.add((x, y))
            f = a[y:y + h, x:x + w] > 0
            cs = comps(f)
            if len(cs) < 2:
                continue
            grande = max(len(c) for c in cs)
            for c in cs:
                if len(c) < grande * 0.05:
                    ys = [p[0] for p in c]; xs = [p[1] for p in c]
                    if min(ys) == 0 or max(ys) == h - 1 or min(xs) == 0 or max(xs) == w - 1:
                        malos.setdefault(an['n'], []).append((i, len(c), 'arriba' if min(ys) == 0 else 'abajo' if max(ys) == h - 1 else 'lado'))
    print(js.replace('\\', '/').split('/')[-1], sum(len(v) for v in malos.values()))
    for k, v in malos.items():
        print('    ', k, v[:6])
