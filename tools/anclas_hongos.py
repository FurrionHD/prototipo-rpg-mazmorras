# ============================================================
#  anclas_hongos.py -- DONDE BROTAN LAS SETAS DE LOS FLORECIDOS, FOTOGRAMA A FOTOGRAMA (10/11/2026, miconido-mutante).
#  El jefe (09/11, la lamina de florecidos): "las setas son una putisima basura": en el juego salian en una linea por
#  encima de la CAJA del bicho, flotando. En la lamina aprobada (tools/sprites_sdf/hongos_florecido_pixel.py) se median
#  sobre la SILUETA. Aqui se mide esa silueta en CADA fotograma de CADA hoja horneada (enemigos y el cuerpo del
#  personaje) y se guarda donde va cada seta, para que en el juego vayan pegadas al cuerpo en todas las poses.
#  10/11 tambien eligio "setas por mas sitios": ademas de las de ARRIBA, dos por los LADOS y dos por el FRENTE.
#
#  RANURAS por fotograma (en este orden; HongosPixel las usa por numero):
#  Todo se mide sobre EL BULTO DEL CUERPO (la silueta sin patas, pinchos ni antenas: ver 'cuerpo').
#    0-5  ARRIBA: 6 columnas repartidas por las columnas GRUESAS (las patas finas no cuentan), en el borde de arriba
#         del TROZO MAS LARGO de la columna (no una pata que pase por encima). Como la lamina.
#    6-7  LADOS: la fila gruesa a un tercio de la altura del cuerpo; su punta izquierda y derecha.
#    8-9  FRENTE: dos puntos del cuerpo (a 1/3 y 2/3 del ancho grueso, en la mitad de arriba) con cuerpo debajo.
#  Cada ranura es el PIXEL de la hoja donde se clava el pie de la seta, relativo a la esquina del RECORTE del fotograma
#  (el AtlasTexture: region). Sin sitio -> NADA.
#
#  SALIDA: assets/sprites/hongos/<forma>.tres (AnclasHongos: por recorte, sus 10 ranuras; cada punto en un entero
#  x*65536 + y) y assets/sprites/hongos/indice.tres (ruta de la hoja sin .png -> fichero). Las hojas con los mismos
#  recortes (los colores de un mismo bicho) comparten fichero.
#  CUANDO PASARLO: tras hornear o compactar hojas (cambian los recortes). tools/prueba_anclas_hongos lo vigila.
#    python tools/anclas_hongos.py
# ============================================================
import os, json, glob, hashlib
import numpy as np
from PIL import Image

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = os.path.join(RAIZ, 'assets', 'sprites', 'hongos')
NADA = -1
RANURAS = 10
UMBRAL = 40


def _gruesas(cols):
    if cols.max() == 0:
        return np.array([], dtype=int)
    return np.where(cols >= max(2, cols.max() * 0.45))[0]


def _trozo_largo(ys):
    trozos = np.split(ys, np.where(np.diff(ys) > 1)[0] + 1)
    return max(trozos, key=len)


def _erosion(a, r):
    h, w = a.shape
    p = np.pad(a, r)
    out = np.ones_like(a)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out &= p[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def _dilatacion(a, r):
    h, w = a.shape
    p = np.pad(a, r)
    out = np.zeros_like(a)
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out |= p[r + dy:r + dy + h, r + dx:r + dx + w]
    return out


def cuerpo(a):
    """EL BULTO DEL CUERPO (10/11, el jefe: "cuidado con las cosas asi", setas colgando de patas y pinchos): la silueta
    sin lo FINO (patas, pinchos, antenas, colas): apertura (erosion + dilatacion) de radio 2 -> fuera lo de menos de
    5 pixeles de grueso. Si se come casi todo (un bicho flaco), radio 1; y si tampoco, la silueta tal cual."""
    total = a.sum()
    for r in (2, 1):
        c = _dilatacion(_erosion(a, r), r) & a
        if c.sum() >= total * 0.3:
            return c
    return a


def anclas(a):
    """a: mascara bool (alto, ancho) del recorte. Devuelve 10 (x, y) o None."""
    out = [None] * RANURAS
    if not a.any():
        return out
    a = cuerpo(a)
    grosor = a.sum(axis=0)
    gruesas = _gruesas(grosor)
    if len(gruesas) == 0:
        return out
    x0, x1 = gruesas[0], gruesas[-1]
    # ARRIBA
    for k in range(6):
        u = 0.1 + 0.8 * (k + 0.5) / 6
        x = int(round(x0 + (x1 - x0) * u))
        x = int(gruesas[np.argmin(np.abs(gruesas - x))])
        ys = np.where(a[:, x])[0]
        out[k] = (x, int(_trozo_largo(ys)[0]))
    # el cuerpo en alto: las filas gruesas
    filas = a.sum(axis=1)
    fg = _gruesas(filas)
    if len(fg):
        y0, y1 = fg[0], fg[-1]
        # LADOS: la fila gruesa a un tercio de la altura
        y = int(round(y0 + (y1 - y0) * 0.33))
        y = int(fg[np.argmin(np.abs(fg - y))])
        # (10/11, el jefe: "cuidado con las cosas asi") SOLO EL CUERPO GRUESO: la fila entera llega a la punta de una
        # pata o de un pincho y la seta quedaba colgando en el aire. Se cuentan solo las columnas gruesas (como las de
        # arriba) y el pie va un pixel hacia DENTRO, que salga del cuerpo.
        xs = np.where(a[y])[0]
        xs = xs[np.isin(xs, gruesas)]
        if len(xs):
            xs = _trozo_largo(xs)
            if len(xs) >= 4:
                out[6] = (int(xs[0]) + 1, y)
                out[7] = (int(xs[-1]) - 1, y)
        # FRENTE: con cuerpo debajo (3 pixeles), que la seta se apoye en el
        for j, (u, v) in enumerate(((0.33, 0.42), (0.67, 0.28))):
            x = int(round(x0 + (x1 - x0) * u))
            x = int(gruesas[np.argmin(np.abs(gruesas - x))])
            ys = np.where(a[:, x])[0]
            largo = _trozo_largo(ys)
            yy = int(largo[0] + (largo[-1] - largo[0]) * v)
            if yy + 3 <= largo[-1]:
                out[8 + j] = (x, yy)
    return out


def medir_hoja(js):
    d = json.load(open(js))
    png = js[:-5] + '.png'
    im = Image.open(png)
    alfa = np.asarray(im.convert('RGBA'))[:, :, 3] > UMBRAL
    vistos = {}
    for an in d['anims']:
        for f in an['f']:
            x, y, w, h = f[0], f[1], f[2], f[3]
            if w <= 0 or h <= 0 or (x, y) in vistos:
                continue
            vistos[(x, y)] = anclas(alfa[y:y + h, x:x + w])
    return vistos


def forma(js):
    d = json.load(open(js))
    f = [sorted({(m[0], m[1], m[2], m[3]) for a in d['anims'] for m in a['f']})]
    # los recortes Y el alfa: dos colores del mismo bicho comparten forma solo si su silueta es la misma
    alfa = np.asarray(Image.open(js[:-5] + '.png').convert('RGBA'))[:, :, 3] > UMBRAL
    h = hashlib.md5(json.dumps(f).encode())
    h.update(np.packbits(alfa).tobytes())
    return h.hexdigest()[:12]


def escribir_tres(ruta, vistos):
    regiones, puntos = [], []
    for (x, y), anc in sorted(vistos.items()):
        regiones.append(x * 65536 + y)
        for p in anc:
            puntos.append(NADA if p is None else p[0] * 65536 + p[1])
    with open(ruta, 'w', newline='\n') as f:
        f.write('[gd_resource type="Resource" script_class="AnclasHongos" load_steps=2 format=3]\n\n')
        f.write('[ext_resource type="Script" path="res://scripts/fx/anclas_hongos.gd" id="1"]\n\n')
        f.write('[resource]\nscript = ExtResource("1")\n')
        f.write('regiones = PackedInt32Array(%s)\n' % ', '.join(map(str, regiones)))
        f.write('puntos = PackedInt32Array(%s)\n' % ', '.join(map(str, puntos)))


def hojas():
    # los PARPADOS no: son la capa del ojo que va encima del bicho, no un cuerpo
    out = [j for j in glob.glob(os.path.join(RAIZ, 'assets', 'sprites', 'enemigos', '*.json')) if '_parpado' not in j]
    # tus personajes: el CUERPO (la piel va debajo de todo y da la silueta; la ropa se le pega)
    out.append(os.path.join(RAIZ, 'assets', 'sprites', 'player', 'cuerpo_1.00.json'))
    return [j for j in out if os.path.exists(j[:-5] + '.png') and '"anims"' in open(j).read()]


if __name__ == '__main__':
    os.makedirs(SALIDA, exist_ok=True)
    indice = {}
    hechas = {}
    for js in hojas():
        rel = 'res://' + os.path.relpath(js[:-5], RAIZ).replace('\\', '/')
        fm = forma(js)
        if fm not in hechas:
            vistos = medir_hoja(js)
            escribir_tres(os.path.join(SALIDA, fm + '.tres'), vistos)
            hechas[fm] = len(vistos)
        indice[rel] = 'res://assets/sprites/hongos/%s.tres' % fm
    # fuera los que ya no usa nadie
    for f in glob.glob(os.path.join(SALIDA, '*.tres')):
        n = os.path.basename(f)[:-5]
        if n != 'indice' and n not in hechas:
            os.remove(f)
    with open(os.path.join(SALIDA, 'indice.tres'), 'w', newline='\n') as f:
        f.write('[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/hojas = {\n')
        f.write(',\n'.join('"%s": "%s"' % (k, v) for k, v in sorted(indice.items())))
        f.write('\n}\n')
    print('hojas %d, formas %d, recortes %d' % (len(indice), len(hechas), sum(hechas.values())))
