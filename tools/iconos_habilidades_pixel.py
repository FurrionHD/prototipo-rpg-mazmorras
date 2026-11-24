# ============================================================
#  iconos_habilidades_pixel.py -- LOS ICONOS DE LAS HABILIDADES Y SUS NODOS EN PIXEL ART (24/11/2026, memoria
#  empezar-habilidades-24-11). Mismo estilo que los de los estados (tools/iconos_estados_pixel.py): 12 x 12, contorno
#  oscuro, sombra, medio, luz y brillo. Aqui se DIBUJAN con formas (lineas, circulos, rectangulos) en una rejilla de
#  letras y el CONTORNO sale solo alrededor de todo lo dibujado.
#
#  Uso: python tools/iconos_habilidades_pixel.py [--abrir]   -> Desktop/iconos_habilidades/lamina_daga.png
#       python tools/iconos_habilidades_pixel.py --hornear   -> assets/ui/habilidades/<clave>.png (SOLO tras su visto bueno)
# ============================================================
import math
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

N = 12
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Los colores de cada letra (RGB). 'o' = contorno (lo pone solo _contorno).
PAL = {
    'o': (16, 16, 24),
    # metal
    'w': (250, 252, 255), 'l': (206, 213, 228), 'm': (150, 158, 178), 'd': (92, 98, 116),
    # empuñadura y cruz
    'h': (132, 82, 46), 'H': (78, 46, 26), 'a': (232, 186, 74), 'A': (160, 116, 36),
    # sangre
    'p': (255, 120, 120), 'r': (206, 34, 44), 'R': (112, 14, 24),
    # veneno
    'q': (206, 255, 150), 'g': (112, 214, 60), 'G': (42, 112, 32),
    # vidrio del frasco
    'v': (170, 200, 214), 'V': (96, 126, 140),
    # humo
    't': (190, 194, 208), 's': (128, 132, 150), 'S': (82, 86, 102),
    # sombra (la silueta que se deshace)
    'k': (52, 44, 70), 'K': (34, 28, 48),
    # ojo
    'e': (238, 230, 206), 'y': (176, 132, 255), 'i': (30, 22, 50),
}


class Lienzo:
    def __init__(self):
        self.f = [['.'] * N for _ in range(N)]

    def px(self, x, y, c):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < N and 0 <= y < N:
            self.f[y][x] = c

    def linea(self, x0, y0, x1, y1, colores):
        """De (x0,y0) a (x1,y1); 'colores' se reparte a lo largo (el primero en la punta de salida)."""
        n = max(abs(x1 - x0), abs(y1 - y0))
        for k in range(int(n) + 1):
            t = k / max(n, 1)
            c = colores[min(int(t * len(colores)), len(colores) - 1)]
            self.px(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, c)

    def arco(self, cx, cy, r, a0, a1, colores, paso=2.0):
        """Un trozo de circulo de a0 a a1 (grados, 0 = derecha, sentido del reloj en pantalla)."""
        n = max(int(abs(a1 - a0) / paso), 1)
        for k in range(n + 1):
            t = k / n
            a = math.radians(a0 + (a1 - a0) * t)
            c = colores[min(int(t * len(colores)), len(colores) - 1)]
            self.px(cx + r * math.cos(a), cy + r * math.sin(a), c)

    def disco(self, cx, cy, r, c, luz=None, sombra=None):
        for y in range(N):
            for x in range(N):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                if dx * dx + dy * dy <= r * r:
                    col = c
                    if luz and dx + dy < -r * 0.6:
                        col = luz
                    elif sombra and dx + dy > r * 0.6:
                        col = sombra
                    self.f[y][x] = col

    def filas(self, x, y, filas):
        for j, fila in enumerate(filas):
            for i, ch in enumerate(fila):
                if ch != '.':
                    self.px(x + i, y + j, ch)

    def hecho(self):
        """El contorno: todo hueco que toca (en cruz) algo dibujado se vuelve 'o'."""
        g = [r[:] for r in self.f]
        for y in range(N):
            for x in range(N):
                if self.f[y][x] != '.':
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < N and 0 <= yy < N and self.f[yy][xx] not in ('.', 'o'):
                        g[y][x] = 'o'
                        break
        return tuple(''.join(r) for r in g)


# ------------------------------------------------------------------ las 5 habilidades de la daga
def rafaga():
    """Tres tajos curvos en abanico, del blanco (la punta) al gris (la estela)."""
    L = Lienzo()
    # tres tajos en diagonal (de arriba a la derecha hacia abajo a la izquierda), uno tras otro, gruesos en el medio
    for k, (x0, y0) in enumerate(((5, 0), (7, 2), (9, 4))):
        L.filas(x0 - 5, y0, [
            ".....w",
            "....wl",
            "...wl.",
            "..lm..",
            ".md...",
            "d.....",
        ][:6])
    return L.hecho()


def punalada():
    """Una daga clavada hacia abajo, con la punta en sangre."""
    L = Lienzo()
    L.filas(4, 0, [
        ".aA.",
        ".hH.",
        ".hH.",
    ])
    L.filas(1, 3, ["aaaaaaaaAA"])
    L.filas(4, 4, [
        ".wm.",
        ".wm.",
        ".wm.",
        ".ld.",
        ".pr.",
        ".rR.",
    ])
    L.px(5, 10, 'r')
    L.px(6, 10, 'R')
    return L.hecho()


def filo_emponzonado():
    """Una hoja en diagonal con una gota verde que resbala, y un frasquito detras."""
    L = Lienzo()
    # el frasco (detras, abajo a la derecha)
    L.filas(7, 5, [
        ".VV.",
        "vqgV",
        "vggG",
        "vgGG",
        ".GG.",
    ])
    L.px(8, 4, 'h')
    # la hoja, de abajo a la izquierda hacia arriba a la derecha
    L.linea(2, 8, 8, 2, ['d', 'm', 'l', 'w'])
    L.linea(3, 8, 9, 2, ['d', 'd', 'm', 'l'])
    L.filas(0, 8, ["aa", "hA"])
    L.px(1, 7, 'a')
    L.px(2, 9, 'a')
    L.px(0, 10, 'H')
    # la gota que resbala por el filo
    L.px(5, 6, 'g')
    L.px(5, 7, 'q')
    L.px(5, 8, 'g')
    return L.hecho()


def desaparecer():
    """Una nube de humo y, encima, una silueta que se deshace."""
    L = Lienzo()
    # la silueta (cabeza y hombros), deshaciendose en motas hacia arriba a la derecha
    L.filas(2, 0, [
        "..kk....",
        ".kkkk...",
        ".kkkk.k.",
        "..kk...k",
        "kkkkkk..",
        "kkkkkkk.",
    ])
    L.px(10, 0, 'k')
    # el humo: tres bolas esponjosas con su brillo
    L.disco(3.2, 8.6, 2.4, 's', luz='t', sombra='S')
    L.disco(6.6, 7.6, 2.8, 's', luz='t', sombra='S')
    L.disco(9.6, 9.0, 2.2, 's', luz='t', sombra='S')
    L.filas(1, 10, ["SSSSSSSSSS"])
    L.px(5, 6, 'w')
    L.px(2, 7, 'w')
    return L.hecho()


def oportunista():
    """Un ojo entrecerrado, con una daga detras en diagonal."""
    L = Lienzo()
    # la daga, detras
    L.linea(1, 10, 9, 2, ['d', 'm', 'l', 'w'])
    L.px(10, 1, 'w')
    L.filas(0, 9, ["a.", "ha"])
    # el ojo, delante y entrecerrado (el parpado de arriba cae hasta la mitad)
    L.filas(2, 4, [
        ".kkkkkkk.",
        "kkkkkkkkk",
        "eeeyyieee",
        ".eeyiyee.",
        "..eeeee..",
    ])
    return L.hecho()


HABILIDADES = [
    ("rafaga", "Ráfaga", rafaga),
    ("punalada", "Puñalada certera", punalada),
    ("filo_emponzonado", "Filo emponzoñado", filo_emponzonado),
    ("desaparecer", "Desaparecer", desaparecer),
    ("oportunista", "Oportunista", oportunista),
]


# ------------------------------------------------------------------ salida
def icono(filas):
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    for j, f in enumerate(filas):
        assert len(f) == N, "fila %d mide %d" % (j, len(f))
        for i, ch in enumerate(f):
            if ch != '.':
                im.putpixel((i, j), PAL[ch] + (255,))
    return im


def en_nodo(ic, P=3, forma='cuadro', aro=(232, 186, 74)):
    """Como sale en el arbol: el nodo (16 x 16 a P) con el icono de 12 dentro (ver NodoUI en arbol_mejoras_ui.gd)."""
    n = 16
    im = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    c = n / 2.0
    for y in range(n):
        for x in range(n):
            dx, dy = x + 0.5 - c, y + 0.5 - c
            d = max(abs(dx), abs(dy)) if forma == 'cuadro' else math.hypot(dx, dy)
            r = n / 2.0
            if d <= r:
                if d > r - 1:
                    col = (10, 10, 15)
                elif d > r - 2:
                    col = aro
                elif d > r - 3:
                    col = tuple(int(v * 0.45) for v in aro)
                else:
                    col = (23, 23, 31)
                im.putpixel((x, y), col + (255,))
    im.alpha_composite(ic, (2, 2))
    return im.resize((n * P, n * P), Image.NEAREST)


def lamina(lista, archivo):
    col, alto = 150, 190
    lam = Image.new('RGB', (20 + col * len(lista), alto), (13, 14, 19))
    d = ImageDraw.Draw(lam)
    try:
        fuente = ImageFont.truetype("arial.ttf", 13)
    except OSError:
        fuente = None
    for k, (clave, nombre, fn) in enumerate(lista):
        x = 20 + k * col
        ic = icono(fn())
        g = ic.resize((N * 9, N * 9), Image.NEAREST)
        lam.paste(g, (x, 10), g)
        lam.paste(en_nodo(ic, 3, 'cuadro'), (x, 124), en_nodo(ic, 3, 'cuadro'))
        lam.paste(en_nodo(ic, 3, 'circulo', (150, 156, 170)), (x + 56, 124), en_nodo(ic, 3, 'circulo', (150, 156, 170)))
        d.text((x, 175), nombre, fill=(225, 225, 225), font=fuente)
    carpeta = os.path.join(os.path.expanduser('~'), 'Desktop', 'iconos_habilidades')
    os.makedirs(carpeta, exist_ok=True)
    ruta = os.path.join(carpeta, archivo)
    lam.save(ruta)
    return ruta


def hornear():
    carpeta = os.path.join(RAIZ, 'assets', 'ui', 'habilidades')
    os.makedirs(carpeta, exist_ok=True)
    for clave, _n, fn in HABILIDADES:
        icono(fn()).save(os.path.join(carpeta, clave + '.png'))
    return carpeta


if __name__ == '__main__':
    if '--hornear' in sys.argv:
        print(hornear())
    else:
        r = lamina(HABILIDADES, 'lamina_daga.png')
        print(r)
        if '--abrir' in sys.argv:
            subprocess.Popen(['mspaint', r])
