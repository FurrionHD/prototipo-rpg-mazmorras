# COMPACTAR LAS HOJAS HORNEADAS (09/10, "~730 MB de texturas, que locura"). Se pasa DESPUES del horno, sobre lo ya
# horneado (PNG + JSON de SpriteLienzo.hornear), y deja el dibujo IDENTICO (son los mismos pixeles):
#   1. LOS FOTOGRAMAS REPETIDOS se guardan una sola vez (en la hoja del cuerpo eran el 29 % del area: poses que se
#      mantienen varios fotogramas, direcciones iguales...). Varios fotogramas del JSON apuntan al mismo recorte.
#   2. LAS HOJAS GRISES (casi todas las del jugador: se hornean en gris y se tiñen en el juego) se escriben en PNG de
#      GRIS + ALFA, y el juego las sube a la grafica como LA8: 2 bytes por pixel en vez de 4. Su .import pasa a "keep"
#      (Godot las exporta tal cual: con "Lossless" las guardaria en WebP y volverian a ser de 4 bytes). El JSON lo
#      dice con "gris": true (ver SpriteLienzo.cargar_horneado).
# Reempaqueta en estantes por altura. Si una hoja ya esta compactada ("compacta": true en su JSON) no la toca.
#   python tools/compactar_hojas.py assets/sprites/player/pelo_bob_1.00.png [mas.png ...]
#   python tools/compactar_hojas.py --todas assets/sprites/player
#   python tools/compactar_hojas.py --sin-gris --todas assets/sprites/enemigos   (solo repetidos: los enemigos son de
#       color y alguna herramienta los carga con load(), que no puede con una hoja "keep")
import sys, os, json, glob, hashlib, math
from PIL import Image
import numpy as np

IMPORT_KEEP = '[remap]\n\nimporter="keep"\n'


def es_gris(arr):
    a = arr[..., 3] > 0
    rgb = arr[..., :3][a]
    return rgb.size == 0 or (bool((rgb[:, 0] == rgb[:, 1]).all()) and bool((rgb[:, 1] == rgb[:, 2]).all()))


def empaquetar(tams, ancho):
    # Estantes: de mas alto a mas bajo, llenando filas de 'ancho'. Devuelve las posiciones y el alto total.
    orden = sorted(range(len(tams)), key=lambda i: (-tams[i][1], -tams[i][0]))
    pos = [None] * len(tams)
    x = y = alto_fila = 0
    for i in orden:
        w, h = tams[i]
        if x + w > ancho:
            y += alto_fila
            x = alto_fila = 0
        pos[i] = (x, y)
        x += w + 1          # 1 px de aire: el filtro NEAREST no lo necesita, pero el borde del atlas no muerde
        alto_fila = max(alto_fila, h + 1)
    return pos, y + alto_fila


def compactar(png, gris_vale=True):
    js = png[:-4] + '.json'
    d = json.load(open(js, encoding='utf-8'))
    if d.get('compacta'):
        return None
    im = Image.open(png).convert('RGBA')
    arr = np.asarray(im)
    unicos = {}       # hash -> indice en 'recortes'
    recortes = []     # (x, y, w, h) en la hoja vieja
    for a in d['anims']:
        for m in a['f']:
            w, h = int(m[2]), int(m[3])
            if w <= 0 or h <= 0:
                continue
            x, y = int(m[0]), int(m[1])
            k = hashlib.md5(arr[y:y + h, x:x + w].tobytes() + bytes([w & 255, w >> 8, h & 255, h >> 8])).hexdigest()
            if k not in unicos:
                unicos[k] = len(recortes)
                recortes.append((x, y, w, h))
            m.append(unicos[k])   # (temporal) a que recorte apunta
    area = sum(w * h for _, _, w, h in recortes)
    ancho = max(max((w for _, _, w, _ in recortes), default=1) + 1, int(math.sqrt(area) * 1.08))
    pos, alto = empaquetar([(w, h) for _, _, w, h in recortes], ancho)
    nueva = Image.new('RGBA', (ancho, max(alto, 1)), (0, 0, 0, 0))
    for i, (x, y, w, h) in enumerate(recortes):
        nueva.paste(im.crop((x, y, x + w, y + h)), pos[i])
    for a in d['anims']:
        for m in a['f']:
            if int(m[2]) <= 0 or int(m[3]) <= 0:
                continue
            i = m.pop()
            m[0], m[1] = pos[i]
    gris = gris_vale and es_gris(arr)
    d['compacta'] = True
    d['gris'] = gris
    antes = os.path.getsize(png)
    if gris:
        nueva.convert('LA').save(png, optimize=True)
        with open(png + '.import', 'w', encoding='utf-8', newline='\n') as f:
            f.write(IMPORT_KEEP)
    else:
        nueva.save(png, optimize=True)
    with open(js, 'w', encoding='utf-8', newline='\n') as f:
        f.write(json.dumps(d, separators=(',', ':')))
    mb_antes = im.width * im.height * 4 / 1048576
    mb_despues = ancho * alto * (2 if gris else 4) / 1048576
    print('%-48s %5dx%-5d -> %5dx%-5d %s  grafica %6.1f -> %5.1f MB  disco %5.0f -> %5.0f KB' % (
        os.path.basename(png), im.width, im.height, ancho, alto, 'GRIS ' if gris else 'color', mb_antes, mb_despues,
        antes / 1024, os.path.getsize(png) / 1024))
    return mb_antes, mb_despues


if __name__ == '__main__':
    args = sys.argv[1:]
    gris_vale = True
    if args and args[0] == '--sin-gris':
        gris_vale = False
        args = args[1:]
    if args and args[0] == '--todas':
        args = sorted(glob.glob(os.path.join(args[1], '*.png')))
        args = [p for p in args if os.path.exists(p[:-4] + '.json')]
    tot_a = tot_d = 0.0
    for p in args:
        r = compactar(p, gris_vale)
        if r:
            tot_a += r[0]
            tot_d += r[1]
    print('TOTAL grafica %.1f -> %.1f MB' % (tot_a, tot_d))
