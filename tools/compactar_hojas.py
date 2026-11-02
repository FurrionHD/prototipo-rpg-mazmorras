# COMPACTAR LAS HOJAS HORNEADAS (09/10, "~730 MB de texturas, que locura"). Se pasa DESPUES del horno, sobre lo ya
# horneado (PNG + JSON de SpriteLienzo.hornear), y deja el dibujo IDENTICO (son los mismos pixeles):
#   1. LOS FOTOGRAMAS REPETIDOS se guardan una sola vez (en la hoja del cuerpo eran el 29 % del area: poses que se
#      mantienen varios fotogramas, direcciones iguales...). Varios fotogramas del JSON apuntan al mismo recorte.
#   2. LAS HOJAS GRISES (casi todas las del jugador: se hornean en gris y se tiñen en el juego) se escriben en PNG de
#      GRIS + ALFA, y el juego las sube a la grafica como LA8: 2 bytes por pixel en vez de 4. Su .import pasa a "keep"
#      (Godot las exporta tal cual: con "Lossless" las guardaria en WebP y volverian a ser de 4 bytes). El JSON lo
#      dice con "gris": true (ver SpriteLienzo.cargar_horneado).
#   3. LOS ENEMIGOS VAN EN BC7 (02/11, el Espantajo eran 65 MB de grafica): las hojas de color de assets/sprites/enemigos
#      se importan comprimidas en la grafica (compress/mode=2 + high_quality = BPTC/BC7 en PC, ASTC en movil): 1 byte
#      por pixel en vez de 4, a ojo igual (error medio 1-4 de 255, el alfa no cambia en ningun pixel; ver la hoja
#      Desktop/.../mutantes/comparacion_bc7.png). Esto lo escribe AQUI en su .import, tambien en las ya compactadas, asi
#      que un enemigo nuevo sale comprimido solo con pasar el compactador. SIN_PERDIDA: las que un shader reconoce por
#      su COLOR EXACTO (ojos de la camada, ojos de la rabia del minotauro), que con BC7 se mueve unos puntos.
#      El juego no lee pixeles de estas hojas: la caja pintada sale de SpriteLienzo.caja_pintada.
# Reempaqueta en estantes por altura. Si una hoja ya esta compactada ("compacta": true en su JSON) no la toca.
#   python tools/compactar_hojas.py assets/sprites/player/pelo_bob_1.00.png [mas.png ...]
#   python tools/compactar_hojas.py --todas assets/sprites/player
#   python tools/compactar_hojas.py --sin-gris --todas assets/sprites/enemigos   (solo repetidos: los enemigos son de
#       color y alguna herramienta los carga con load(), que no puede con una hoja "keep")
import sys, os, json, glob, hashlib, math
from PIL import Image
import numpy as np

IMPORT_KEEP = '[remap]\n\nimporter="keep"\n'
SIN_PERDIDA = ('minotauro3d', 'rata3d')
# Lo minimo para una hoja nueva sin .import: Godot completa el resto (uid, rutas, los demas parametros) al importar.
IMPORT_BC7 = ('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[params]\n\ncompress/mode=2\n'
              'compress/high_quality=true\nmipmaps/generate=false\nprocess/fix_alpha_border=true\n'
              'detect_3d/compress_to=1\n')


def va_en_bc7(png):
    ruta = png.replace('\\', '/')
    return '/sprites/enemigos/' in ruta and not os.path.basename(png).startswith(SIN_PERDIDA)


def poner_bc7(png):
    # Toca solo los dos parametros (el uid y lo demas se quedan como estan). True si ha cambiado algo.
    imp = png + '.import'
    if not os.path.exists(imp):
        with open(imp, 'w', encoding='utf-8', newline='\n') as f:
            f.write(IMPORT_BC7)
        return True
    texto = open(imp, encoding='utf-8').read()
    if 'importer="keep"' in texto:
        return False
    nuevo = texto.replace('compress/mode=0', 'compress/mode=2').replace('compress/mode=1', 'compress/mode=2')
    nuevo = nuevo.replace('compress/high_quality=false', 'compress/high_quality=true')
    if nuevo != texto:
        with open(imp, 'w', encoding='utf-8', newline='\n') as f:
            f.write(nuevo)
    return nuevo != texto


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
    mb_despues = ancho * alto * (2 if gris else (1 if va_en_bc7(png) else 4)) / 1048576
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
    bc7 = 0
    for p in args:
        r = compactar(p, gris_vale)
        if r:
            tot_a += r[0]
            tot_d += r[1]
        if va_en_bc7(p) and not json.load(open(p[:-4] + '.json', encoding='utf-8')).get('gris') and poner_bc7(p):
            bc7 += 1
    if bc7:
        print('%d hojas pasadas a BC7 (falta el --import de Godot)' % bc7)
    print('TOTAL grafica %.1f -> %.1f MB' % (tot_a, tot_d))
