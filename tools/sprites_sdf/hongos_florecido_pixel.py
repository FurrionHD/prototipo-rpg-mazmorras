# ============================================================
#  hongos_florecido_pixel.py -- LOS HONGOS DE LOS FLORECIDOS (09/11/2026, miconido-mutante, parte C de la infeccion).
#  Un enemigo que cae INFECTADO se levanta con hongos: el MISMO sprite, mas apagado (gris de muerto), y le brotan setas
#  y tallos con la punta encendida por ARRIBA de su silueta (como el Aventurero florecido: naranja con luz cian).
#  Las setas son pixel art de la rejilla de los sprites (1 celda = 1 px de su hoja), paleta cerrada.
#  La lamina mide la silueta de verdad de cada enemigo de los pisos 7-10 (su idle) y planta las setas por arriba.
#  Uso: python tools/sprites_sdf/hongos_florecido_pixel.py -> Desktop/ataques_mapa/efectos_pixel/florecidos.png
# ============================================================
import os, json, random
import numpy as np
from PIL import Image, ImageDraw

RAIZ = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
HOJAS = os.path.join(RAIZ, 'assets', 'sprites', 'enemigos')

# Paleta: o contorno, d/m/l el sombrero naranja, s el pie palido, a/w la luz cian de la punta.
PAL = {
    'o': (46, 22, 10), 'd': (140, 60, 16), 'm': (196, 98, 26), 'l': (236, 150, 60), 'b': (255, 226, 180),
    's': (214, 200, 176), 'p': (150, 136, 116), 'a': (90, 220, 190), 'w': (210, 255, 240),
}
# Cada seta con su PIE abajo en el centro (la ultima fila es donde se clava).
SETAS = {
    'pequena': ("..ooo..", ".olmlo.", "oolbmoo", "..oso..", "..oso.."),
    'mediana': ("...ooooo...", "..olllmmo..", ".olblllmmo.", "ooooooooooo", "....oso....", "....oso....", "....ops...."),
    'doble': ("..ooo......", ".olmlo.ooo.", "oolbmoolmlo", "..osooolbmo", "..oso..oso.", "..oso..oso."),
    'tallo': ("aw.", "ow.", "od.", "om.", "om.", "od."),
    'tallo_largo': (".aw", ".ow", ".om", "om.", "od.", "om.", "od."),
}


def seta_img(nombre):
    filas = SETAS[nombre]
    h, w = len(filas), max(len(f) for f in filas)
    im = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    px = im.load()
    for y, f in enumerate(filas):
        for x, ch in enumerate(f):
            if ch in PAL:
                px[x, y] = PAL[ch] + (255,)
    return im


def apagar(im):
    """Gris de muerto: menos color y mas oscuro, sin tocar el contorno ni el alfa."""
    a = np.asarray(im).astype(float)
    rgb = a[:, :, :3]
    gris = rgb.mean(axis=2, keepdims=True)
    rgb = (rgb * 0.45 + gris * 0.55) * 0.72 + np.array([6, 10, 4])
    a[:, :, :3] = np.clip(rgb, 0, 255)
    return Image.fromarray(a.astype(np.uint8), 'RGBA')


def anclas(im, n, semilla):
    """Donde brotan: n columnas repartidas por el CUERPO (las columnas gruesas: las patas finas no cuentan, si no la seta
    queda colgando de una pata), en su borde de ARRIBA, un poco hundidas para que salgan DEL cuerpo."""
    a = np.asarray(im)[:, :, 3] > 40
    grosor = a.sum(axis=0)
    if grosor.max() == 0:
        return []
    gruesas = np.where(grosor >= max(4, grosor.max() * 0.45))[0]
    x0, x1 = gruesas[0], gruesas[-1]
    rng = random.Random(semilla)
    out = []
    for k in range(n):
        u = 0.1 + 0.8 * (k + 0.5) / n + rng.uniform(-0.04, 0.04)
        x = int(round(x0 + (x1 - x0) * u))
        # la columna gruesa mas cercana (entre x0 y x1 puede haber huecos)
        x = int(gruesas[np.argmin(np.abs(gruesas - x))])
        ys = np.where(a[:, x])[0]
        # el borde de arriba del TROZO MAS LARGO de la columna (no una pata que pase por encima)
        trozos = np.split(ys, np.where(np.diff(ys) > 1)[0] + 1)
        largo = max(trozos, key=len)
        out.append((x, int(largo[0]) + 2))
    return out


def florecer(im, semilla=7):
    base = apagar(im)
    a = np.asarray(im)[:, :, 3] > 40
    ancho = int(a.any(axis=0).sum())
    n = 4 if ancho < 40 else (5 if ancho < 70 else 6)
    rng = random.Random(semilla)
    tipos = ['tallo', 'pequena', 'mediana', 'tallo_largo', 'doble', 'pequena'] if ancho >= 40 else \
        ['tallo', 'pequena', 'tallo_largo', 'pequena']
    rng.shuffle(tipos)
    out = base.copy()
    for (x, y), t in zip(anclas(im, n, semilla), tipos):
        s = seta_img(t)
        out.alpha_composite(s, (x - s.width // 2, y - s.height + 1))
    return out


def frame(nombre, fila=1):
    carpeta = os.path.join(HOJAS, nombre)
    meta = json.load(open(os.path.join(carpeta, 'hojas.json')))
    W, H = meta['lienzo']
    hoja = Image.open(os.path.join(carpeta, 'idle.png')).convert('RGBA')
    return hoja.crop((0, fila * H, W, (fila + 1) * H))


ENEMIGOS = ['rata_sdf', 'rata_rey_sdf', 'arana_sdf', 'escarabajo_sdf', 'ciempies_sdf', 'segadora_sdf',
            'chupasimas_sdf', 'chillon_sdf', 'aberracion_sdf', 'acechador_sdf']

if __name__ == '__main__':
    ESC = 4
    tiras = []
    for nom in ENEMIGOS:
        try:
            fr = frame(nom)
        except OSError:
            print('sin hoja:', nom)
            continue
        caja = fr.getbbox()
        fl = florecer(fr, hash(nom) & 0xffff)
        cb = fl.getbbox()
        c = (min(caja[0], cb[0]) - 2, min(caja[1], cb[1]) - 2, max(caja[2], cb[2]) + 2, max(caja[3], cb[3]) + 2)
        tiras.append((nom.replace('_sdf', ''), fr.crop(c), fl.crop(c)))
    filas = [tiras[:5], tiras[5:]]
    ancho = 20 + max(sum((t[1].width * 2 + 10) * ESC for t in f) for f in filas)
    alto_f = [max(t[1].height for t in f) * ESC + 30 for f in filas if f]
    lam = Image.new('RGB', (ancho, sum(alto_f) + 10), (40, 42, 50))
    d = ImageDraw.Draw(lam)
    y = 10
    for f, af in zip(filas, alto_f):
        x = 10
        for nom, a, b in f:
            for k, im in enumerate((a, b)):
                g = im.resize((im.width * ESC, im.height * ESC), Image.NEAREST)
                lam.paste(g, (x + k * (im.width + 4) * ESC, y), g)
            d.text((x, y + af - 22), nom + '  (normal | florecido)', fill=(230, 230, 230))
            x += (a.width * 2 + 10) * ESC
        y += af
    ruta = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'efectos_pixel', 'florecidos.png')
    os.makedirs(os.path.dirname(ruta), exist_ok=True)
    lam.save(ruta)
    print(ruta, lam.size)
