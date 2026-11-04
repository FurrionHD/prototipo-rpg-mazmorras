#!/usr/bin/env python3
# ============================================================
#  horno_efectos.py -- LO COMUN DEL HORNO DE LOS EFECTOS EN PIXEL ART (04/11/2026, memoria efectos-a-pixel-art).
#  Guarda cada efecto (solo el efecto: el horno de cada enemigo cambia escena() y victima() de su lamina por unas que no pintan
#  cuerpos ni objetivos) como hoja recortada en assets/sprites/efectos/<enemigo>/ y apunta sus medidas en
#  scripts/fx/efectos_pixel_datos.gd SIN pisar a los demas enemigos.
# ============================================================
import json
import os
import re

from PIL import Image

RAIZ = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
DATOS = os.path.join(RAIZ, 'scripts', 'fx', 'efectos_pixel_datos.gd')
CABECERA = ('# GENERADO por tools/sprites_sdf/horno_efectos.py: no tocar a mano. Las hojas de assets/sprites/efectos/:\n'
            '# n marcos x filas (1 o las 5 direcciones S, SE, E, NE, N); s = capa del suelo, a = capa de encima; [ancho, alto, origen x, origen y].\n'
            '# corte + fps2: desde ese marco va a otro ritmo (lo rapido ha de cuadrar con el golpe; lo que se seca, sin prisa).\n'
            'extends RefCounted\n\nconst HOJAS := {\n')


def guardar_capa(carpeta, nombre, sufijo, filas, indice, origenes):
    caja = None
    for j, fila in enumerate(filas):
        ox, oy = origenes[j]
        for marcos in fila:
            b = Image.fromarray(marcos[indice], 'RGBA').getbbox()
            if b:
                # relativo a SU origen: cada fila tiene el suyo
                b = (b[0] - ox, b[1] - oy, b[2] - ox, b[3] - oy)
                caja = b if caja is None else (min(caja[0], b[0]), min(caja[1], b[1]), max(caja[2], b[2]), max(caja[3], b[3]))
    if caja is None:
        return None
    x0, y0, x1, y1 = caja
    w, h = x1 - x0, y1 - y0
    hoja = Image.new('RGBA', (w * len(filas[0]), h * len(filas)), (0, 0, 0, 0))
    for j, fila in enumerate(filas):
        ox, oy = origenes[j]
        for i, marcos in enumerate(fila):
            hoja.paste(Image.fromarray(marcos[indice], 'RGBA').crop((x0 + ox, y0 + oy, x1 + ox, y1 + oy)), (i * w, j * h))
    hoja.save(os.path.join(carpeta, '%s_%s.png' % (nombre, sufijo)), optimize=True)
    return [w, h, -x0, -y0]


def guardar_efecto(enemigo, nombre, filas, origenes, fps, bucle=False, corte=0, fps2=0.0):
    """filas: lista (1 o 5) de listas de marcos (s, a); origenes: (x, y) de cada fila en el lienzo."""
    carpeta = os.path.join(RAIZ, 'assets', 'sprites', 'efectos', enemigo)
    os.makedirs(carpeta, exist_ok=True)
    origenes = [(int(round(x)), int(round(y))) for x, y in origenes]
    d = {'n': len(filas[0]), 'filas': len(filas), 'fps': fps, 'bucle': bucle,
         's': guardar_capa(carpeta, nombre, 's', filas, 0, origenes), 'a': guardar_capa(carpeta, nombre, 'a', filas, 1, origenes)}
    if corte:
        d['corte'], d['fps2'] = corte, fps2
    print(enemigo, nombre, d)
    return d


# Pone o cambia la linea de 'enemigo' en el .gd; las de los demas se quedan como estan.
def apuntar(enemigo, datos):
    lineas = {}
    if os.path.exists(DATOS):
        with open(DATOS, encoding='utf-8') as f:
            for m in re.finditer(r'^\t"(\w+)": (\{.*\}),$', f.read(), re.M):
                lineas[m.group(1)] = m.group(2)
    lineas[enemigo] = json.dumps(datos)
    texto = CABECERA + ''.join('\t"%s": %s,\n' % (k, lineas[k]) for k in sorted(lineas)) + '}\n'
    with open(DATOS, 'w', encoding='utf-8', newline='\n') as f:
        f.write(texto)
