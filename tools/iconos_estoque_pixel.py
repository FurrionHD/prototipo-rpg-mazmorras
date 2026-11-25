# ============================================================
#  iconos_estoque_pixel.py -- LOS ICONOS DEL ESTOQUE: sus 6 habilidades y los nodos de sus arboles (25/11, memoria
#  arboles-estoque). Mismo estilo y piezas que los de la daga (tools/iconos_habilidades_pixel.py): 12 x 12, contorno
#  oscuro que sale solo, sombra, medio, luz y brillo.
#
#  Uso: python tools/iconos_estoque_pixel.py [--abrir]           -> Desktop/iconos_habilidades/lamina_estoque.png
#       python tools/iconos_estoque_pixel.py --nodos [--abrir]   -> Desktop/iconos_habilidades/lamina_nodos_estoque.png
#       python tools/iconos_estoque_pixel.py --hornear           -> assets/ui/habilidades/ (SOLO tras su visto bueno)
# ============================================================
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iconos_habilidades_pixel as base  # noqa: E402
from iconos_habilidades_pixel import (Lienzo, _n, icono, rc, nube, FLECHA, RAYO, OJO, RELOJ, ESTRELLA, PIE,  # noqa: E402
                                      SILUETA, GOTA, PUNO, CALAVERA)

# colores de mas (el PAL es comun: se añaden, no se pisan)
base.PAL.update({
    'c': (150, 236, 250), 'C': (46, 150, 190),     # Presteza (cian)
    'b': (130, 170, 255), 'B': (52, 76, 176),      # guardia / esquiva (azul)
    'u': (200, 150, 240), 'U': (110, 60, 160),     # nervios (Debil, morado)
    'x': (255, 150, 60), 'X': (170, 70, 20),       # Marca (naranja)
})

# ------------------------------------------------------------------ piezas
def estoque(L, x0, y0, x1, y1, cazoleta=True):
    """Un estoque de la empuñadura (x0,y0) a la punta (x1,y1): hoja FINA de un pixel y cazoleta dorada."""
    L.linea(x0, y0, x1, y1, ['m', 'l', 'l', 'w'])
    dx, dy = (1 if x1 > x0 else -1 if x1 < x0 else 0), (1 if y1 > y0 else -1 if y1 < y0 else 0)
    L.px(x0 - dx, y0 - dy, 'h')
    L.px(x0 - 2 * dx, y0 - 2 * dy, 'a')
    if cazoleta:
        # la cazoleta, de traves a la hoja
        L.px(x0 + dy, y0 - dx, 'a')
        L.px(x0 - dy, y0 + dx, 'A')
        L.px(x0, y0, 'a')


def punta(L, x, y, c='w'):
    L.px(x, y, c)


def chispa(L, x, y):
    L.filas(x - 1, y - 1, [".w.", "wEw", ".w."])


def rayas(L, x, y, n=3, c='s'):
    """Lineas de velocidad hacia la izquierda desde (x,y)."""
    for k in range(n):
        L.linea(x - 3, y + 2 * k, x - 1, y + 2 * k, [c])


def blanco(L, cx, cy, r=2.6):
    L.disco(cx, cy, r, 'r', luz='p', sombra='R')
    L.disco(cx, cy, r * 0.45, 'e')


# ------------------------------------------------------------------ las 6 habilidades
def estocada_penetrante():
    """El estoque en recto atravesando dos dianas."""
    L = Lienzo()
    blanco(L, 5.5, 6.0, 2.3)
    blanco(L, 9.5, 6.0, 2.0)
    estoque(L, 2, 6, 11, 6)
    return L.hecho()


def fintas():
    """Tres puntas en abanico: dos fintas (grises) y la de verdad (blanca)."""
    L = Lienzo()
    L.linea(2, 10, 8, 1, ['S', 's', 's'])
    L.linea(2, 10, 11, 9, ['S', 's', 's'])
    estoque(L, 2, 10, 10, 4)
    return L.hecho()


def danza_de_acero():
    """Un zigzag de pasos que acaba en la punta del estoque."""
    L = Lienzo()
    L.linea(0, 10, 3, 6, ['C', 'c'])
    L.linea(3, 6, 5, 9, ['C', 'c'])
    L.linea(5, 9, 7, 5, ['C', 'c'])
    estoque(L, 5, 7, 11, 1, cazoleta=False)
    chispa(L, 9, 9)
    return L.hecho()


def en_guardia():
    """El estoque en alto y, delante, el arco azul de la esquiva."""
    L = Lienzo()
    L.arco(6.0, 7.0, 5.0, 200, 340, ['B', 'b', 'b', 'B'], paso=6)
    estoque(L, 5, 10, 5, 1)
    return L.hecho()


def paso_ligero():
    """Una huella con su estela y la punta delante."""
    L = Lienzo()
    L.filas(4, 5, PIE)
    rayas(L, 3, 6, 3, 'c')
    estoque(L, 7, 4, 11, 0, cazoleta=False)
    return L.hecho()


def punzada_al_nervio():
    """La punta sobre un nervio que salta (rayo morado)."""
    L = Lienzo()
    L.filas(6, 5, rc(RAYO, {'E': 'u'}))
    L.filas(8, 1, rc(RAYO, {'E': 'u'})[:3])
    estoque(L, 1, 10, 6, 5)
    return L.hecho()


HABILIDADES = [
    ("estocada_penetrante", "Estocada penetrante", estocada_penetrante),
    ("fintas", "Fintas", fintas),
    ("danza_de_acero", "Danza de acero", danza_de_acero),
    ("en_guardia", "En guardia", en_guardia),
    ("paso_ligero", "Paso ligero", paso_ligero),
    ("punzada_al_nervio", "Punzada al nervio", punzada_al_nervio),
]

# ------------------------------------------------------------------ ESTOCADA PENETRANTE
ESCUDO = ["dddddd", "dmmmmd", "dmllmd", "dmmmmd", ".dmmd.", "..dd.."]


def _sin_armadura(L):
    L.filas(4, 3, rc(ESCUDO, {}))
    L.px(6, 5, '.'); L.px(7, 6, '.'); L.px(6, 7, '.')
    estoque(L, 1, 6, 10, 6)
def _atravesar(L):
    L.filas(2, 2, ["s", "s", "s", "s", "s", "s", "s", "s"])
    L.filas(9, 2, ["s", "s", "s", "s", "s", "s", "s", "s"])
    estoque(L, 1, 5, 11, 5)
    estoque(L, 1, 7, 11, 7, cazoleta=False)
def _corazon(L):
    L.filas(4, 1, [".rr.rr.", "rpprrrr", "rprrrrR", "rrrrrRR", ".rrrRR.", "..rRR..", "...R..."])
    estoque(L, 0, 11, 5, 6, cazoleta=False)
def _empunadura(L):
    blanco(L, 7.5, 5.5, 3.2)
    estoque(L, 1, 10, 7, 5)
def _lanza_larga(L):
    estoque(L, 1, 6, 11, 6)
    L.filas(4, 2, rc(FLECHA, {'w': 'c'})[:2])
    L.filas(4, 9, rc(FLECHA, {'w': 'c'})[3:])
def _ensartar(L):
    for x in (3, 6, 9):
        L.disco(x + 0.5, 6.5, 1.4, 'r', sombra='R')
    estoque(L, 0, 6, 11, 6, cazoleta=False)
def _herida_se_abre(L):
    L.filas(3, 1, rc(RELOJ, {}))
    L.filas(8, 7, GOTA)
def _desequilibrio(L):
    L.filas(2, 2, SILUETA)
    L.filas(8, 1, ["..w", ".w.", "w..", ".w.", "..w"])
    chispa(L, 9, 9)
def _grieta(L):
    L.filas(2, 2, ESCUDO)
    L.linea(4, 3, 6, 6, ['g']); L.linea(6, 6, 5, 8, ['g'])
    L.filas(8, 6, rc(GOTA, {'r': 'g', 'p': 'q', 'R': 'G'}))
def _estocada_doble(L):
    estoque(L, 1, 4, 10, 4)
    estoque(L, 1, 8, 10, 8)
def _a_fondo(L):
    L.filas(1, 4, rc(FLECHA, {'w': 'c'}))
    estoque(L, 4, 9, 11, 9, cazoleta=False)
def _remate(L):
    L.filas(5, 0, CALAVERA)
    estoque(L, 0, 11, 5, 6)
def _acoso(L):
    L.filas(7, 3, SILUETA)
    for y in (2, 5, 8):
        L.linea(0, y + 1, 5, y, ['m', 'l', 'w'])
def _abanico(L):
    for x1, y1 in ((11, 1), (11, 5), (11, 9)):
        L.linea(1, 10, x1, y1, ['m', 'l', 'w'])
def _buscar_hueco(L):
    for k, y in enumerate((9, 6, 3)):
        L.linea(1, y + 1, 4 + 3 * k, y, ['m', 'l', 'w'])
def _ultima_estocada(L):
    L.linea(1, 3, 5, 3, ['S', 's'])
    L.linea(1, 5, 5, 5, ['S', 's'])
    estoque(L, 1, 8, 11, 8)
def _mas_fintas(L):
    for y in (1, 3, 5, 7, 9):
        L.linea(1, 10, 10, y, ['S', 's', 'l'])
def _brazo_largo_f(L):
    estoque(L, 1, 6, 11, 6)
    L.filas(8, 8, ["w.", "ww", "w."])
    L.filas(1, 2, ["nn", "nN"])
def _ninguno_se_libra(L):
    # tres dianas pequeñas y una punta clavada en cada una
    for cx, cy in ((3.0, 3.0), (9.0, 3.0), (6.0, 9.0)):
        L.disco(cx, cy, 2.0, 'r', luz='p', sombra='R')
        L.px(int(cx) - 1, int(cy) - 1, 'w')
def _finta_enganosa(L):
    L.filas(1, 3, OJO)
    L.linea(2, 10, 8, 8, ['S', 's'])
    estoque(L, 2, 11, 11, 7, cazoleta=False)
def _leer_guardia(L):
    L.filas(3, 2, ESCUDO)
    L.filas(1, 7, rc(OJO, {'y': 'b'}))
def _ritmo_f(L):
    L.filas(3, 1, RELOJ)
    rayas(L, 3, 3, 3, 'c')
def _respiracion(L):
    L.filas(4, 3, rc(RAYO, {}))
    chispa(L, 2, 2)
    chispa(L, 9, 9)

# ------------------------------------------------------------------ DANZA DE ACERO
def _cuarto_tiempo(L):
    for k, (x, y) in enumerate(((1, 9), (4, 6), (7, 9), (10, 6))):
        L.filas(x, y - 4, ["w", "l", "m"] if k == 3 else ["l", "m", "d"])
    L.linea(1, 10, 10, 7, ['C', 'c'])
def _danza_ancha(L):
    L.linea(0, 3, 11, 3, ['C', 'c'])
    L.linea(0, 8, 11, 8, ['C', 'c'])
    L.filas(3, 4, ["w..w..w", ".w..w.."])
def _compas(L):
    for k in range(4):
        L.linea(1 + 3 * k, 10, 1 + 3 * k, 9 - 2 * k, ['l', 'w'])
def _remate_baile(L):
    L.linea(0, 10, 3, 6, ['C', 'c']); L.linea(3, 6, 5, 9, ['C', 'c'])
    blanco(L, 8.5, 4.5, 2.6)
    chispa(L, 8, 4)
def _danza_larga(L):
    L.linea(0, 8, 2, 5, ['C', 'c']); L.linea(2, 5, 4, 8, ['C', 'c']); L.linea(4, 8, 6, 5, ['C', 'c'])
    L.linea(6, 5, 8, 8, ['C', 'c']); L.linea(8, 8, 11, 4, ['C', 'c'])
def _baile_alimenta(L):
    L.linea(0, 10, 3, 6, ['C', 'c']); L.linea(3, 6, 5, 9, ['C', 'c'])
    L.filas(7, 2, RAYO)
def _herida_cruz(L):
    L.linea(2, 2, 9, 9, ['m', 'l', 'w'])
    L.linea(9, 2, 2, 9, ['m', 'l', 'w'])
    L.filas(8, 7, GOTA)
def _sin_guardia(L):
    L.filas(1, 2, ESCUDO)
    L.linea(1, 9, 9, 1, ['r', 'p'])
    L.linea(2, 9, 10, 1, ['R', 'r'])
def _ritmo_d(L):
    L.filas(3, 1, RELOJ)
    L.linea(0, 10, 3, 8, ['C', 'c']); L.linea(3, 8, 5, 10, ['C', 'c'])
def _bailar_esquivando(L):
    L.filas(3, 3, SILUETA)
    L.arco(6.0, 6.5, 5.2, 160, 380, ['B', 'b', 'b', 'B'], paso=6)

# ------------------------------------------------------------------ EN GUARDIA
def _guardia_alta(L):
    L.arco(6.0, 7.0, 5.0, 200, 340, ['B', 'b', 'b', 'B'], paso=6)
    L.arco(6.0, 7.0, 3.5, 210, 330, ['B', 'b'], paso=6)
    estoque(L, 5, 11, 5, 2)
def _guardia_paciente(L):
    L.filas(3, 2, RELOJ)
    L.arco(6.0, 7.0, 5.5, 140, 400, ['B', 'b'], paso=6)
def _ojos_espalda(L):
    L.filas(2, 0, rc(OJO, {'y': 'b'}))
    L.filas(3, 6, SILUETA)
def _reto(L):
    L.filas(1, 4, rc(FLECHA, {'w': 'x'}))
    L.filas(7, 3, SILUETA[:4])
    estoque(L, 8, 11, 11, 8, cazoleta=False)
def _riposte_perfecto(L):
    L.arco(5.0, 6.0, 4.0, 200, 340, ['B', 'b'], paso=6)
    estoque(L, 1, 10, 10, 1)
    L.filas(7, 5, ESTRELLA[1:6])
def _salir_al_paso(L):
    L.filas(1, 5, PIE)
    L.filas(6, 3, rc(FLECHA, {'w': 'b'}))
def _respiro(L):
    L.arco(6.0, 7.0, 5.0, 200, 340, ['B', 'b'], paso=6)
    L.filas(4, 4, RAYO)
def _paciencia_g(L):
    L.filas(1, 2, rc(OJO, {'y': 'x'}))
    L.filas(4, 7, rc(FLECHA, {'w': 'x'}))
def _guardia_no_cae(L):
    L.arco(6.0, 6.0, 5.0, 180, 360, ['B', 'b', 'b', 'B'], paso=6)
    L.arco(6.0, 6.0, 5.0, 0, 180, ['S', 's'], paso=20)
    estoque(L, 5, 11, 5, 3)

# ------------------------------------------------------------------ PASO LIGERO
def _paso_largo(L):
    L.filas(0, 6, PIE)
    L.filas(7, 1, PIE)
    L.linea(3, 5, 7, 7, ['c'])
def _al_costado(L):
    L.filas(4, 1, SILUETA)
    estoque(L, 0, 10, 4, 7, cazoleta=False)
    L.filas(9, 7, rc(FLECHA, {'w': 'c'})[1:4])
def _ida_vuelta(L):
    L.filas(1, 1, rc(FLECHA, {'w': 'c'}))
    L.filas(4, 6, rc([f[::-1] for f in FLECHA], {'w': 'c'}))
def _esquiva_paso(L):
    L.filas(4, 5, PIE)
    L.arco(6.0, 6.0, 5.2, 180, 360, ['B', 'b', 'b', 'B'], paso=6)
def _pasar_cortando(L):
    L.filas(4, 0, SILUETA)
    L.linea(0, 9, 11, 9, ['c', 'c', 'w'])
    L.linea(3, 7, 8, 4, ['m', 'l', 'w'])
def _encadenar(L):
    for x, y in ((1, 6), (5, 3), (8, 7)):
        L.disco(x + 1.5, y + 1.5, 1.8, 'E', sombra='F')
        L.disco(x + 1.5, y + 1.5, 0.7, '.')
def _presteza_mayor(L):
    L.filas(4, 5, PIE)
    rayas(L, 3, 2, 5, 'c')
    L.filas(8, 0, ["c.", "cc", "c."])
def _paso_despista(L):
    L.filas(5, 3, rc(SILUETA, {'k': 's'}))
    L.filas(0, 0, ["S...", ".S..", "..S."])
    L.filas(1, 6, rc(PIE, {'n': 'c', 'N': 'C'}))
def _recobrar_aliento(L):
    L.filas(1, 5, PIE)
    L.filas(6, 2, RAYO)
def _paso_guardia(L):
    L.filas(0, 5, PIE)
    L.arco(7.0, 7.0, 4.5, 200, 340, ['B', 'b'], paso=6)
    estoque(L, 7, 11, 7, 3)

# ------------------------------------------------------------------ PUNZADA AL NERVIO
NERVIO = rc(RAYO, {'E': 'u'})


def _nervio_brazo(L):
    L.filas(1, 3, PUNO)
    L.filas(7, 4, NERVIO)
def _nervio_pierna(L):
    L.filas(1, 5, PIE)
    L.filas(6, 3, NERVIO)
def _temblor(L):
    L.filas(3, 3, PUNO)
    L.filas(0, 2, ["u.", ".u", "u."])
    L.filas(10, 6, ["u.", ".u", "u."])
def _pulso_firme(L):
    blanco(L, 6.0, 6.0, 4.0)
    L.filas(4, 4, NERVIO)
def _clavado(L):
    # el pie, y las raices que lo agarran desde el suelo
    L.filas(4, 0, PIE)
    L.linea(0, 10, 11, 10, ['H'])
    L.filas(2, 5, ["g.....g.", ".g...g..", "..gGg...", ".gGgGg..", "GgGGgGG."])
def _cadena_nerviosa(L):
    L.disco(2.5, 3.5, 2.0, 'k')
    L.disco(9.5, 8.5, 2.0, 'k')
    L.linea(3, 5, 6, 5, ['u']); L.linea(6, 5, 5, 8, ['u']); L.linea(5, 8, 8, 8, ['u'])
def _atravesar_p(L):
    # dos cuerpos en fila y la punta que los cruza a los dos, con el calambre encima
    L.filas(2, 3, ["kk.", "kkk", "kkk", "kk."])
    L.filas(7, 3, ["kk.", "kkk", "kkk", "kk."])
    estoque(L, 0, 5, 11, 5, cazoleta=False)
    L.filas(2, 0, ["u.u", ".u."])
    L.filas(7, 0, ["u.u", ".u."])
def _linea_larga_p(L):
    estoque(L, 1, 6, 11, 6)
    L.filas(5, 8, rc(FLECHA, {'w': 'u'})[1:4])
def _sobre_lo_tocado(L):
    L.filas(2, 3, rc(SILUETA, {'k': 'U'}))
    estoque(L, 11, 11, 7, 7, cazoleta=False)
    L.filas(8, 1, ["u.", ".u", "u."])
def _mano_segura_p(L):
    L.filas(1, 5, PUNO)
    estoque(L, 6, 7, 11, 2, cazoleta=False)
    L.filas(0, 0, ESTRELLA[2:5])
def _lena_al_caido(L):
    L.disco(6.0, 6.0, 4.6, 'x', luz='E', sombra='X')
    L.disco(6.0, 6.0, 2.6, 'e')
    L.disco(6.0, 6.0, 1.2, 'x')


NODOS = [
    ("estocada_penetrante", [("sin_armadura", "Sin armadura", _sin_armadura), ("atravesar", "Atravesar", _atravesar),
                             ("corazon", "Corazón", _corazon), ("empunadura", "Hasta la empuñadura", _empunadura),
                             ("lanza_larga", "Lanza larga", _lanza_larga), ("ensartar", "Ensartar", _ensartar),
                             ("herida_se_abre", "Herida que se abre", _herida_se_abre),
                             ("desequilibrio", "Desequilibrio", _desequilibrio), ("grieta", "Grieta", _grieta),
                             ("estocada_doble", "Estocada doble", _estocada_doble), ("a_fondo", "A fondo", _a_fondo),
                             ("remate", "Remate", _remate)]),
    ("fintas", [("acoso", "Acoso", _acoso), ("abanico", "Abanico", _abanico), ("buscar_hueco", "Buscar el hueco", _buscar_hueco),
                ("ultima_estocada", "Última estocada", _ultima_estocada), ("mas_fintas", "Más fintas", _mas_fintas),
                ("brazo_largo_f", "Brazo largo", _brazo_largo_f), ("ninguno_se_libra", "Ninguno se libra", _ninguno_se_libra),
                ("finta_enganosa", "Finta engañosa", _finta_enganosa), ("leer_guardia", "Leer la guardia", _leer_guardia),
                ("ritmo_f", "Ritmo", _ritmo_f), ("respiracion", "Respiración", _respiracion)]),
    ("danza_de_acero", [("cuarto_tiempo", "Cuarto tiempo", _cuarto_tiempo), ("danza_ancha", "Danza ancha", _danza_ancha),
                        ("compas", "Compás", _compas), ("remate_baile", "Remate del baile", _remate_baile),
                        ("danza_larga", "Danza larga", _danza_larga), ("baile_alimenta", "Baile que alimenta", _baile_alimenta),
                        ("herida_cruz", "Herida en cruz", _herida_cruz), ("sin_guardia", "Sin guardia", _sin_guardia),
                        ("ritmo_d", "Ritmo", _ritmo_d), ("bailar_esquivando", "Bailar esquivando", _bailar_esquivando)]),
    ("en_guardia", [("guardia_alta", "Guardia alta", _guardia_alta), ("guardia_paciente", "Guardia paciente", _guardia_paciente),
                    ("ojos_espalda", "Ojos en la espalda", _ojos_espalda), ("reto", "Reto", _reto),
                    ("riposte_perfecto", "Riposte perfecto", _riposte_perfecto), ("salir_al_paso", "Salir al paso", _salir_al_paso),
                    ("respiro", "Respiro", _respiro), ("paciencia_g", "Paciencia", _paciencia_g),
                    ("guardia_no_cae", "Guardia que no cae", _guardia_no_cae)]),
    ("paso_ligero", [("paso_largo", "Paso largo", _paso_largo), ("al_costado", "Al costado", _al_costado),
                     ("ida_vuelta", "Ida y vuelta", _ida_vuelta), ("esquiva_paso", "Esquiva en el paso", _esquiva_paso),
                     ("pasar_cortando", "Pasar cortando", _pasar_cortando), ("encadenar", "Encadenar", _encadenar),
                     ("presteza_mayor", "Presteza mayor", _presteza_mayor), ("paso_despista", "Paso que despista", _paso_despista),
                     ("recobrar_aliento", "Recobrar aliento", _recobrar_aliento), ("paso_guardia", "Paso de guardia", _paso_guardia)]),
    ("punzada_al_nervio", [("nervio_brazo", "Nervio del brazo", _nervio_brazo), ("nervio_pierna", "Nervio de la pierna", _nervio_pierna),
                           ("temblor", "Temblor", _temblor), ("pulso_firme", "Pulso firme", _pulso_firme),
                           ("clavado", "Clavado", _clavado), ("cadena_nerviosa", "Cadena nerviosa", _cadena_nerviosa),
                           ("atravesar_p", "Atravesar", _atravesar_p), ("larga_p", "Línea larga", _linea_larga_p),
                           ("sobre_lo_tocado", "Sobre lo tocado", _sobre_lo_tocado), ("mano_segura", "Mano segura", _mano_segura_p),
                           ("lena_al_caido", "Leña al caído", _lena_al_caido)]),
]


def hornear():
    carpeta = os.path.join(base.RAIZ, 'assets', 'ui', 'habilidades')
    os.makedirs(carpeta, exist_ok=True)
    for clave, _nombre, fn in HABILIDADES:
        icono(fn()).save(os.path.join(carpeta, clave + '.png'))
    for hab, nodos in NODOS:
        for clave, _nombre, fn in nodos:
            icono(_n(fn)()).save(os.path.join(carpeta, '%s__%s.png' % (hab, clave)))
    return carpeta


if __name__ == '__main__':
    # las laminas de la daga leen sus listas del modulo: se le prestan las del estoque
    base.HABILIDADES = HABILIDADES
    base.NODOS = NODOS
    if '--hornear' in sys.argv:
        print(hornear())
    else:
        r = base.lamina_nodos('lamina_nodos_estoque.png') if '--nodos' in sys.argv \
            else base.lamina(HABILIDADES, 'lamina_estoque.png')
        print(r)
        if '--abrir' in sys.argv:
            subprocess.Popen(['mspaint', r])
