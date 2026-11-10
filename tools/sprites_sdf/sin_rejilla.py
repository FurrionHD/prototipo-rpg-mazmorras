#!/usr/bin/env python3
# ============================================================
#  sin_rejilla.py -- REHORNEA LOS EFECTOS PIXEL DE LOS ENEMIGOS SIN REJILLA (10/11/2026, memoria transparencia-de-verdad).
#  "todos iban a ir con transparencias, no con rejillas". Sin tocar ningun horno: lanza cada uno 4 veces con la trama
#  CONSTANTE (TRAMA_FIJA = 0,125 / 0,375 / 0,625 / 0,875, ver escarabajo_efectos_pixel.BAYER) en modo volcado
#  (horno_efectos.VOLCAR: capas crudas a disco) y promedia: cada pixel con su color y el alfa en 4 escalones (25-100 %).
#  Luego guarda las hojas de verdad y las suma a efectos_pixel_datos.gd.
#    python tools/sprites_sdf/sin_rejilla.py [horno ...]      (sin nada: todos menos el miconido, que ya sale asi)
# ============================================================
import json
import os
import shutil
import subprocess
import sys
import tempfile

import numpy as np

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)
import horno_efectos as ho

UMBRALES = ('0.125', '0.375', '0.625', '0.875')
# (el del slime normal primero: los de su familia se suman a su linea)
HORNOS = ['slime', 'slime_veneno', 'slime_fuego', 'slime_profundo', 'slime_abisal', 'rey_slime', 'rata', 'rey_rata',
          'jabali', 'trent', 'arana', 'escarabajo_normal', 'ciempies', 'segadora']


def promedio(cargas, largos):
    filas = []
    for j, n in enumerate(largos):
        fila = []
        for i in range(n):
            capas = []
            for k in range(2):
                clave = '%d_%d_%d' % (j, i, k)
                col = None
                for c in cargas:
                    a = c[clave].astype(np.float32)
                    if col is None:
                        col = np.zeros(a.shape[:2] + (3,), np.float32)
                        cuenta = np.zeros(a.shape[:2], np.float32)
                    hay = a[:, :, 3] > 0
                    col[hay] += a[hay, :3]
                    cuenta[hay] += 1
                res = np.zeros(col.shape[:2] + (4,), np.uint8)
                hay = cuenta > 0
                res[hay, :3] = np.clip(col[hay] / cuenta[hay, None] + 0.5, 0, 255).astype(np.uint8)
                res[:, :, 3] = np.round(cuenta / len(cargas) * 255).astype(np.uint8)
                capas.append(res)
            fila.append(tuple(capas))
        filas.append(fila)
    return filas


def hornear(nombre):
    script = os.path.join(AQUI, nombre + '_efectos_horno.py')
    dirs = []
    try:
        for t in UMBRALES:
            d = tempfile.mkdtemp(prefix='sinrej_')
            dirs.append(d)
            env = dict(os.environ, TRAMA_FIJA=t, HORNO_VOLCAR=d, PYTHONIOENCODING='utf-8')
            r = subprocess.run([sys.executable, script], env=env, cwd=AQUI, capture_output=True, text=True, encoding='utf-8')
            if r.returncode != 0:
                print(r.stdout[-2000:], r.stderr[-4000:])
                raise SystemExit('%s fallo con trama %s' % (nombre, t))
        with open(os.path.join(dirs[0], 'orden.jsonl'), encoding='utf-8') as f:
            orden = [json.loads(l) for l in f if l.strip()]
        por_enemigo = {}
        for m in orden:
            cargas = [np.load(os.path.join(d, '%s__%s.npz' % (m['enemigo'], m['nombre']))) for d in dirs]
            filas = promedio(cargas, m['largos'])
            for c in cargas:
                c.close()
            por_enemigo.setdefault(m['enemigo'], {})[m['nombre']] = ho.guardar_efecto(
                m['enemigo'], m['nombre'], filas, [tuple(o) for o in m['origenes']], m['fps'], m['bucle'], m['corte'], m['fps2'])
        for enemigo, datos in por_enemigo.items():
            ho.sumar(enemigo, datos)
        print('== %s: %d efectos sin rejilla' % (nombre, len(orden)))
    finally:
        for d in dirs:
            shutil.rmtree(d, ignore_errors=True)


if __name__ == '__main__':
    for n in (sys.argv[1:] or HORNOS):
        hornear(n)
