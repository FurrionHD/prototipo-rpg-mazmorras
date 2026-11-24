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
    # energia (amarillo) y piel
    'E': (255, 222, 80), 'F': (196, 150, 30), 'n': (232, 184, 142), 'N': (168, 118, 86),
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


# ------------------------------------------------------------------ piezas de los NODOS (24/11): un dibujo sencillo de lo
# que hace cada uno. Patrones en letras; 'rc' los cambia de color (la gota roja vale de verde para el veneno).
def rc(pat, m):
    return [''.join(m.get(ch, ch) for ch in f) for f in pat]


VERDE = {'r': 'g', 'p': 'q', 'R': 'G'}
GOTA = [".r.", "rpr", "rrR", ".R."]
GOTA_G = ["..r..", ".rpr.", "rprrr", "rrrrR", "rrrRR", ".RRR."]
CALAVERA = [".eeeee.", "eeeeeee", "eiieiie", "eiieiie", "eeeieee", ".eemee.", ".e.e.e."]
RELOJ = ["HHHHHH", ".vaav.", "..aa..", "..vv..", ".vaav.", ".aaaa.", "HHHHHH"]
PLUMA = ["......lw", ".....lwl", "....lwl.", "...lwl..", "..lml...", ".dm.....", "d......."]
FLECHA = ["....w..", "....ww.", "wwwwwww", "....ww.", "....w.."]
RAYO = ["..EE", ".EE.", "EEEE", ".EE.", "EE.."]
FRASCO = [".hh.", ".vv.", "vqgv", "vggv", "vgGv", ".vv."]
PUNO = [".nnnn.", "nnnnnn", "nNnNnN", "nnnnnn", ".nnnN.", "..nN.."]
ESTRELLA = ["...w...", "...w...", ".wwlww.", "wwlwlww", ".wwlww.", "...w...", "...w..."]
PIE = [".nn.", "nnnn", "nnnn", ".nnN", ".nN.", ".NN."]   # una huella: la suela
OJO = ["..kkkkk..", ".eeeeeee.", "eeeyiyeee", ".eeyyyee.", "..eeeee.."]
SILUETA = ["..kk..", ".kkkk.", ".kkkk.", "..kk..", "kkkkkk", "kkkkkk"]


def daga_v(L, x, y, largo=6, punta_abajo=True):
    """Una daga vertical de 2 de ancho: cruz, mango y hoja de 'largo'."""
    if punta_abajo:
        L.filas(x, y, [".aA.", ".hH.", "aaaA"])
        for k in range(largo):
            L.filas(x, y + 3 + k, [".wm." if k < largo - 1 else ".ld."])
    else:
        for k in range(largo):
            L.filas(x, y + k, [".ld." if k == 0 else ".wm."])
        L.filas(x, y + largo, ["aaaA", ".hH.", ".aA."])


def tajo(L, x0, y0, x1, y1):
    L.linea(x0, y0, x1, y1, ['d', 'm', 'l', 'w'])


def nube(L, cx, cy, s=1.0):
    L.disco(cx - 2.4 * s, cy + 0.6 * s, 2.2 * s, 's', luz='t', sombra='S')
    L.disco(cx + 0.4 * s, cy - 0.4 * s, 2.7 * s, 's', luz='t', sombra='S')
    L.disco(cx + 2.8 * s, cy + 0.9 * s, 2.0 * s, 's', luz='t', sombra='S')


def _n(fn):
    """Un dibujo de nodo a partir de una funcion que pinta en un Lienzo."""
    def f():
        L = Lienzo()
        fn(L)
        return L.hecho()
    return f


# --- RAFAGA
def _mas_tajos(L):
    for k in range(4):
        tajo(L, k * 3 - 1, 10, k * 3 + 2, 3)
def _hoja_fina(L):
    L.linea(1, 10, 10, 1, ['d', 'm', 'l', 'w'])
    L.linea(2, 10, 11, 1, ['d', 'm', 'l', 'l'])
def _remolino(L):
    L.arco(5.5, 5.5, 4.5, 0, 300, ['d', 'm', 'l', 'w'], paso=6)
    L.arco(5.5, 5.5, 2.5, 180, 420, ['d', 'm', 'l'], paso=10)
def _brazo_largo(L):
    tajo(L, 0, 11, 6, 5)
    L.filas(5, 1, ["..www", "...ww", "..w.w", ".w...", "w...."])
def _mil_cortes(L):
    for x, y in ((0, 0), (5, 1), (8, 4), (2, 5), (6, 7), (0, 8)):
        L.filas(x, y, GOTA)
def _entrar_bailando(L):
    L.filas(1, 6, PIE)
    L.filas(7, 0, PIE)
    L.linea(0, 2, 4, 2, ['S', 's', 't'])
    L.linea(6, 8, 10, 8, ['S', 's', 't'])
def _persiguen(L):
    L.filas(0, 5, CALAVERA)
    L.arco(8.0, 6.0, 4.0, -170, -30, ['m', 'l', 'w'], paso=8)
    L.filas(9, 7, ["e.", "ee", ".e"])
def _remate(L):
    L.filas(1, 4, GOTA_G)
    tajo(L, 4, 11, 11, 0)
def _frenesi(L):
    L.filas(3, 2, RELOJ)
    tajo(L, 0, 11, 3, 8)
    tajo(L, 9, 11, 11, 9)
def _ligera(L):
    L.filas(2, 2, PLUMA)


# --- PUÑALADA
def _punto_debil(L):
    L.disco(6, 6, 5.5, 'e')
    L.disco(6, 6, 4.0, 'r')
    L.disco(6, 6, 2.5, 'e')
    L.disco(6, 6, 1.2, 'r')
def _herida_abierta(L):
    L.filas(3, 2, GOTA_G)
    L.filas(4, 4, ["..", ".R", "R."])
def _hasta_el_mango(L):
    L.filas(0, 7, ["dddddddddddd", "mmmmmmmmmmmm", "dddddddddddd"])
    daga_v(L, 4, 0, 4)
def _por_la_espalda(L):
    L.filas(0, 3, SILUETA + ["kkkkkk"])
    L.linea(6, 11, 11, 3, ['d', 'm', 'l', 'w'])
    L.filas(5, 10, ["a.", "ha"])
def _arteria(L):
    L.filas(1, 2, GOTA_G)
    L.filas(6, 5, GOTA_G)
def _mano_segura(L):
    # la mano cerrada AGARRANDO la daga (la hoja sale por abajo)
    L.filas(5, 0, ["aA"])
    L.filas(2, 1, ["nnnnnnn", "nNnNnNn", "nnnnnnN", ".aaaaA."])
    L.filas(5, 5, ["wm", "wm", "wm", "wm", "ld"])
def _asesinato(L):
    L.filas(2, 2, CALAVERA)
def _desangrar(L):
    L.filas(3, 3, GOTA_G)
    for x, y in ((1, 1), (10, 1), (0, 7), (11, 8), (5, 0)):
        L.px(x, y, 'r')
def _ejecucion(L):
    L.filas(3, 3, CALAVERA)
    L.arco(6.5, 6.5, 5.5, 200, 520, ['E', 'E', 'F'], paso=8)
    L.filas(0, 5, ["E", "EE"])
def _golpe_y_fuera(L):
    L.filas(4, 6, [f[::-1] for f in FLECHA])   # la flecha hacia atras (a la izquierda)
    daga_v(L, 7, 0, 4)


# --- FILO EMPONZOÑADO
def _agarra(L):
    L.linea(1, 10, 10, 1, ['d', 'm', 'l', 'w'])
    L.filas(5, 5, rc(GOTA, VERDE))
def _mas_usos(L):
    for k in range(3):
        L.filas(k * 4, 3 + (k % 2) * 3, rc(GOTA, VERDE))
def _dosis_cargadas(L):
    L.filas(1, 4, FRASCO)
    L.filas(7, 1, ["..q..", ".qqq.", "qqqqq", "..q..", "..q..", "..q.."])
def _veneno_fuerte(L):
    L.filas(2, 2, rc(GOTA_G, {'r': 'G', 'p': 'g', 'R': 'G'}))
    L.filas(3, 4, ["...", ".iq", "..."])
def _compartir(L):
    L.filas(0, 3, FRASCO)
    L.filas(6, 5, FRASCO)
def _mano_rapida(L):
    L.filas(3, 2, rc(RELOJ, {'a': 'g'}))
def _acido(L):
    L.filas(1, 1, ["dddddddd.", "dmmmmmmd.", "dm.m.mmd.", "dmmm.mmd.", ".dmm.md..", "..dm.d...", "...dd...."])
    L.filas(7, 6, rc(GOTA, VERDE))
def _ponzona_sangre(L):
    L.filas(0, 3, rc(GOTA_G, VERDE))
    L.filas(6, 5, GOTA_G)
def _toxina(L):
    L.filas(3, 3, rc(GOTA_G, VERDE))
    for x, y in ((1, 1), (10, 1), (0, 7), (11, 8), (5, 0)):
        L.px(x, y, 'g')
def _senal(L):
    L.filas(0, 4, rc(GOTA_G, VERDE))
    L.filas(7, 3, RAYO)


# --- DESAPARECER
def _nube_grande(L):
    nube(L, 6.0, 6.5, 1.25)
def _a_fondo(L):
    nube(L, 6.0, 9.0, 0.8)
    daga_v(L, 4, 0, 5)
def _humo_espeso(L):
    nube(L, 6.0, 7.0, 1.2)
    L.filas(3, 5, ["iiiiii"])
def _humo_todos(L):
    nube(L, 6.0, 9.0, 1.0)
    L.filas(0, 1, SILUETA)
    L.filas(6, 1, SILUETA)
def _salir_sombras(L):
    L.disco(6, 8.5, 3.5, 'k', sombra='K')
    L.linea(6, 0, 6, 6, ['w', 'l', 'm'])
    L.filas(5, 6, ["aaa"])
def _escabullirse(L):
    L.filas(0, 3, SILUETA)
    L.filas(5, 5, FLECHA)
def _desvio(L):
    # el ojo que ya no te ve: tachado
    L.filas(1, 3, OJO)
    L.linea(1, 10, 10, 1, ['r', 'r', 'p'])
def _pies_niebla(L):
    nube(L, 6.0, 8.5, 1.0)
    L.filas(1, 0, PIE)
    L.filas(7, 1, PIE)
def _sombra_larga(L):
    L.filas(0, 1, SILUETA)
    L.filas(0, 8, ["KKKKKKKKKKKK", ".kkkkkkkkkk."])
    L.filas(7, 1, ["HHHH", ".aa.", ".vv.", "HHHH"])
def _recarga(L):
    nube(L, 5.0, 8.0, 1.0)
    L.filas(7, 0, RAYO)


# --- OPORTUNISTA
def _mas_huecos(L):
    L.filas(0, 0, [".kkk.", "eyie.", ".eee."])
    L.filas(6, 3, [".kkk.", "eyie.", ".eee."])
    L.filas(2, 7, [".kkk.", "eyie.", ".eee."])
def _entrar_fondo(L):
    daga_v(L, 4, 0, 7)
    L.filas(0, 9, ["kkkkkkkkkkkk", "KKKKKKKKKKKK"])
def _ojo_halcon(L):
    L.filas(0, 2, OJO)
    L.filas(5, 7, FLECHA)
def _critico_cadena(L):
    L.filas(0, 0, ESTRELLA)
    L.filas(5, 7, ["mm.mm", "m.m.m", "mm.mm"])
def _llegar_matando(L):
    L.arco(6.0, 9.0, 6.0, 200, 300, ['t', 't', 's'], paso=10)
    daga_v(L, 7, 2, 6)
def _desequilibrar(L):
    L.filas(1, 3, SILUETA)
    L.filas(7, 2, ["..w", ".w.", "w..", ".w.", "..w"])
def _sin_rastro(L):
    # las huellas que se van borrando
    L.filas(0, 6, PIE)
    L.filas(4, 3, rc(PIE, {'n': 's', 'N': 'S'}))
    L.filas(8, 0, rc(PIE, {'n': 'S', 'N': 'S'}))
def _aprovechado(L):
    L.linea(1, 10, 7, 4, ['d', 'm', 'l', 'w'])
    L.filas(7, 2, RAYO)
def _salto_largo(L):
    L.arco(6.0, 11.0, 5.5, 190, 350, ['l', 'l', 'w'], paso=6)
    L.filas(9, 8, ["w.", "ww"])
    L.filas(0, 8, ["kk", "kk"])
def _entrar_dos(L):
    L.linea(1, 10, 9, 2, ['d', 'm', 'l', 'w'])
    L.linea(10, 10, 2, 2, ['d', 'm', 'l', 'w'])


NODOS = [
    ("rafaga", [("mas_tajos", "Más tajos", _mas_tajos), ("hoja_fina", "Hoja fina", _hoja_fina),
                ("remolino", "Remolino", _remolino), ("brazo_largo", "Brazo largo", _brazo_largo),
                ("mil_cortes", "Mil cortes", _mil_cortes), ("entrar_bailando", "Entrar bailando", _entrar_bailando),
                ("persiguen", "Persiguen", _persiguen), ("remate", "Remate", _remate),
                ("frenesi", "Frenesí", _frenesi), ("ligera", "Ráfaga ligera", _ligera)]),
    ("punalada", [("punto_debil", "Punto débil", _punto_debil), ("herida_abierta", "Herida abierta", _herida_abierta),
                  ("hasta_el_mango", "Hasta el mango", _hasta_el_mango), ("por_la_espalda", "Por la espalda", _por_la_espalda),
                  ("arteria", "Arteria", _arteria), ("mano_segura", "Mano segura", _mano_segura),
                  ("asesinato", "Asesinato", _asesinato), ("desangrar", "Desangrar", _desangrar),
                  ("ejecucion", "Ejecución", _ejecucion), ("golpe_y_fuera", "Golpe y fuera", _golpe_y_fuera)]),
    ("filo_emponzonado", [("agarra_mejor", "Agarra mejor", _agarra), ("mas_usos", "Más usos", _mas_usos),
                          ("dosis_cargadas", "Dosis cargadas", _dosis_cargadas), ("veneno_fuerte", "Veneno fuerte", _veneno_fuerte),
                          ("compartir", "Compartir", _compartir), ("mano_rapida", "Mano rápida", _mano_rapida),
                          ("acido", "Ácido", _acido), ("ponzona_sangre", "Ponzoña y sangre", _ponzona_sangre),
                          ("toxina", "Toxina", _toxina), ("senal", "Señal", _senal)]),
    ("desaparecer", [("nube_grande", "Nube grande", _nube_grande), ("a_fondo", "A fondo", _a_fondo),
                     ("humo_espeso", "Humo espeso", _humo_espeso), ("humo_todos", "Humo para todos", _humo_todos),
                     ("salir_sombras", "Salir de sombras", _salir_sombras), ("escabullirse", "Escabullirse", _escabullirse),
                     ("desvio", "Desvío", _desvio), ("pies_niebla", "Pies en niebla", _pies_niebla),
                     ("sombra_larga", "Sombra larga", _sombra_larga), ("recarga", "Recarga", _recarga)]),
    ("oportunista", [("mas_huecos", "Más huecos", _mas_huecos), ("entrar_fondo", "Entrar a fondo", _entrar_fondo),
                     ("ojo_halcon", "Ojo de halcón", _ojo_halcon), ("critico_cadena", "Crítico cadena", _critico_cadena),
                     ("llegar_matando", "Llegar matando", _llegar_matando), ("desequilibrar", "Desequilibrar", _desequilibrar),
                     ("sin_rastro", "Sin rastro", _sin_rastro), ("aprovechado", "Aprovechado", _aprovechado),
                     ("salto_largo", "Salto largo", _salto_largo), ("entrar_dos", "Entrar los dos", _entrar_dos)]),
]


def lamina_nodos(archivo):
    col, alto = 124, 150
    lam = Image.new('RGB', (20 + col * 10, 30 + alto * len(NODOS)), (13, 14, 19))
    d = ImageDraw.Draw(lam)
    try:
        fuente = ImageFont.truetype("arial.ttf", 11)
        fuente_t = ImageFont.truetype("arial.ttf", 14)
    except OSError:
        fuente = fuente_t = None
    for j, (hab, nodos) in enumerate(NODOS):
        y = 10 + j * alto
        d.text((20, y), dict((c, n) for c, n, _ in HABILIDADES)[hab], fill=(240, 200, 110), font=fuente_t)
        for k, (clave, nombre, fn) in enumerate(nodos):
            x = 20 + k * col
            ic = icono(_n(fn)())
            g = ic.resize((N * 6, N * 6), Image.NEAREST)
            lam.paste(g, (x, y + 22), g)
            nodo = en_nodo(ic, 3, 'cuadro', (150, 156, 170))
            lam.paste(nodo, (x + 74, y + 46), nodo)
            d.text((x, y + 100), nombre, fill=(225, 225, 225), font=fuente)
    carpeta = os.path.join(os.path.expanduser('~'), 'Desktop', 'iconos_habilidades')
    os.makedirs(carpeta, exist_ok=True)
    ruta = os.path.join(carpeta, archivo)
    lam.save(ruta)
    return ruta


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
    for clave, _nombre, fn in HABILIDADES:
        icono(fn()).save(os.path.join(carpeta, clave + '.png'))
    # los de los nodos: <habilidad>__<nodo>.png (lo que busca arbol_mejoras_ui)
    for hab, nodos in NODOS:
        for clave, _nombre, fn in nodos:
            icono(_n(fn)()).save(os.path.join(carpeta, '%s__%s.png' % (hab, clave)))
    return carpeta


if __name__ == '__main__':
    if '--hornear' in sys.argv:
        print(hornear())
    elif '--nodos' in sys.argv:
        r = lamina_nodos('lamina_nodos_daga.png')
        print(r)
        if '--abrir' in sys.argv:
            subprocess.Popen(['mspaint', r])
    else:
        r = lamina(HABILIDADES, 'lamina_daga.png')
        print(r)
        if '--abrir' in sys.argv:
            subprocess.Popen(['mspaint', r])
