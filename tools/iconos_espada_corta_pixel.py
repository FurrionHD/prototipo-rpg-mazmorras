# ============================================================
#  iconos_espada_corta_pixel.py -- LOS ICONOS DE LA ESPADA CORTA: sus 5 habilidades y los nodos de sus arboles (26/11,
#  memoria arboles-espada-corta). Mismo estilo y piezas que los de la daga y el estoque (tools/iconos_habilidades_pixel.py):
#  12 x 12, contorno oscuro que sale solo, sombra, medio, luz y brillo.
#
#  Uso: python tools/iconos_espada_corta_pixel.py [--abrir]           -> Desktop/iconos_habilidades/lamina_espada_corta.png
#       python tools/iconos_espada_corta_pixel.py --nodos [--abrir]   -> Desktop/iconos_habilidades/lamina_nodos_espada_corta.png
#       python tools/iconos_espada_corta_pixel.py --hornear           -> assets/ui/habilidades/ (SOLO tras su visto bueno)
# ============================================================
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iconos_habilidades_pixel as base  # noqa: E402
from iconos_habilidades_pixel import (Lienzo, _n, icono, rc, FLECHA, RELOJ, ESTRELLA, PIE, SILUETA, PUNO)  # noqa: E402
import iconos_estoque_pixel as est  # noqa: E402  (sus colores de mas y sus piezas: chispa, rayas, blanco)
from iconos_estoque_pixel import chispa, rayas, blanco  # noqa: E402


# ------------------------------------------------------------------ piezas
def espada(L, x0, y0, x1, y1, cruz=True):
    """Una espada corta de la empuñadura (x0,y0) a la punta (x1,y1): hoja ancha (dos tonos), cruz dorada y pomo."""
    L.linea(x0, y0, x1, y1, ['m', 'l', 'l', 'w'])
    dx, dy = (1 if x1 > x0 else -1 if x1 < x0 else 0), (1 if y1 > y0 else -1 if y1 < y0 else 0)
    # el canto de la hoja, un tono mas oscuro a un lado (la hace ancha)
    L.linea(x0 + dx + dy, y0 + dy - dx, x1 - dx + dy, y1 - dy - dx, ['d', 'm'])
    L.px(x0 - dx, y0 - dy, 'h')
    L.px(x0 - 2 * dx, y0 - 2 * dy, 'H')
    if cruz:
        L.px(x0 + dy, y0 - dx, 'a')
        L.px(x0 - dy, y0 + dx, 'A')
        L.px(x0 + 2 * dy, y0 - 2 * dx, 'a')
        L.px(x0 - 2 * dy, y0 + 2 * dx, 'A')


def tajo(L, cx, cy, r, a0, a1, c='w'):
    """La estela de un tajo (arco claro)."""
    L.arco(cx, cy, r, a0, a1, ['s', 'l', c], paso=6)


def grieta(L, x, y, c='r'):
    L.filas(x, y, [c + "..", "." + c + ".", c + "." + c.lower() if False else c + ".."])


def enemigo(L, x, y, c='r'):
    L.filas(x, y, rc(SILUETA[:4], {'k': c}))


# ------------------------------------------------------------------ las 5 habilidades
def tajo_quebrantador():
    """El tajo que parte un escudo: la espada en diagonal y la guardia rota (roja)."""
    L = Lienzo()
    L.filas(5, 3, ["rrrr.", "rRRrr", "rR.Rr", ".rRr.", "..r.."])
    espada(L, 1, 11, 10, 2)
    return L.hecho()


def doble_tajo():
    """Dos estelas que se cruzan."""
    L = Lienzo()
    tajo(L, 6.0, 6.0, 4.5, 200, 330)
    tajo(L, 6.0, 6.0, 4.5, 20, 150)
    espada(L, 2, 10, 9, 3, cruz=False)
    return L.hecho()


def cambio_de_ritmo():
    """La espada pasando de largo, con sus rayas y el reloj que adelanta."""
    L = Lienzo()
    rayas(L, 4, 7, 3, 'c')
    espada(L, 3, 9, 11, 9, cruz=True)
    L.filas(6, 0, ["HHHH", ".aa.", ".aa.", "HHHH"])
    return L.hecho()


def senalar_el_hueco():
    """La punta señalando una diana naranja (la Marca)."""
    L = Lienzo()
    L.disco(7.5, 4.5, 3.4, 'x', luz='E', sombra='X')
    L.disco(7.5, 4.5, 1.6, 'e')
    L.px(7.5, 4.5, 'x')
    espada(L, 1, 11, 5, 7, cruz=True)
    return L.hecho()


def corte_de_tendones():
    """Un tajo bajo a la pierna (la huella) con la sangre detras."""
    L = Lienzo()
    L.filas(6, 1, PIE)
    L.filas(5, 6, ["rr..", ".rR."])
    tajo(L, 6.0, 4.0, 6.0, 120, 200, 'w')
    espada(L, 0, 11, 6, 9, cruz=False)
    return L.hecho()


HABILIDADES = [
    ("tajo_quebrantador", "Tajo quebrantador", tajo_quebrantador),
    ("doble_tajo", "Doble tajo", doble_tajo),
    ("cambio_de_ritmo", "Cambio de ritmo", cambio_de_ritmo),
    ("senalar_el_hueco", "Señalar el hueco", senalar_el_hueco),
    ("corte_de_tendones", "Corte de tendones", corte_de_tendones),
]


def vulnerable(L, x, y):
    """El escudo roto (rojo) pequeño: el Vulnerable."""
    L.filas(x, y, ["rrr", "rRr", ".r."])


def marca(L, x, y, r=2.2):
    L.disco(x, y, r, 'x', luz='E', sombra='X')
    L.px(x, y, 'e')


# ------------------------------------------------------------------ TAJO QUEBRANTADOR
def _tajo_a_fondo(L):
    espada(L, 1, 6, 11, 6)
    L.filas(9, 2, ["w", "w"])
    L.filas(9, 9, ["w", "w"])
def _barrido_ancho(L):
    tajo(L, 6.0, 9.0, 5.5, 180, 360)
    espada(L, 6, 11, 6, 4, cruz=True)
def _romper_guardia(L):
    vulnerable(L, 7, 1)
    espada(L, 1, 11, 9, 3)
    chispa(L, 9, 8)
def _quebrar_armadura(L):
    L.filas(4, 2, ["dddddd", "dmmlmd", "dm.rmd", "dmrmmd", ".dmmd.", "..dd.."])
    espada(L, 0, 11, 6, 5, cruz=False)
def _hueco_abierto(L):
    vulnerable(L, 1, 1)
    L.filas(5, 4, ESTRELLA[0:7])
def _abrir_a_todos(L):
    vulnerable(L, 0, 2)
    vulnerable(L, 4, 0)
    vulnerable(L, 8, 2)
    tajo(L, 6.0, 11.0, 6.0, 200, 340)
def _exponer_mas(L):
    L.filas(2, 1, ["rrrrrrr", "rRRRRRr", "rR...Rr", "rR...Rr", ".rR.Rr.", "..rRr..", "...r..."])
def _desequilibrio_q(L):
    L.filas(1, 2, rc(SILUETA, {'k': 'r'}))
    L.filas(7, 3, rc(FLECHA, {'w': 'E'})[0:5])
def _aprovechar_hueco(L):
    vulnerable(L, 1, 1)
    L.filas(6, 4, rc(base.RAYO, {}))
def _mano_rapida_q(L):
    L.filas(3, 2, RELOJ)
    rayas(L, 3, 9, 1, 'c')
def _desarmar_guardia(L):
    L.filas(1, 1, ["dddd", "dmmd", "dmmd", ".dd."])
    L.linea(5, 5, 10, 10, ['S', 's'])
    espada(L, 11, 1, 5, 7, cruz=False)


# ------------------------------------------------------------------ DOBLE TAJO
def _tercer_tajo(L):
    tajo(L, 6.0, 6.0, 4.5, 200, 330)
    tajo(L, 6.0, 6.0, 4.5, 20, 150)
    L.linea(1, 6, 11, 6, ['s', 'l', 'w'])
def _mas_tajos(L):
    enemigo(L, 1, 6)
    enemigo(L, 6, 6)
    tajo(L, 6.0, 7.0, 5.5, 190, 350)
def _remate_combo(L):
    tajo(L, 6.0, 6.0, 4.5, 200, 330, 'l')
    espada(L, 1, 11, 10, 2)
    chispa(L, 9, 8)
def _filo_fino(L):
    espada(L, 1, 11, 10, 2, cruz=False)
    L.filas(6, 6, ESTRELLA[1:6])
def _abanico_d(L):
    tajo(L, 6.0, 10.0, 5.8, 180, 360)
    tajo(L, 6.0, 10.0, 3.6, 180, 360, 'l')
def _brazo_largo_d(L):
    espada(L, 0, 9, 11, 9)
    L.filas(4, 3, rc(FLECHA, {'w': 'c'}))
def _filo_sangra(L):
    espada(L, 1, 11, 10, 2, cruz=False)
    L.filas(7, 6, ["r.", "rr", "Rr", ".R"])
def _furia_filo(L):
    # (26/11) tres tajos en remolino: la furia que crece con cada enemigo
    tajo(L, 6.0, 6.0, 5.0, 150, 300)
    tajo(L, 6.0, 6.0, 3.2, 330, 480, 'l')
    L.filas(4, 4, rc(base.RAYO, {}))
def _respiracion_d(L):
    L.filas(4, 0, ESTRELLA[1:6])
    L.filas(4, 6, rc(base.RAYO, {}))


# ------------------------------------------------------------------ CAMBIO DE RITMO
def _acelerar(L):
    L.filas(3, 2, RELOJ)
    rayas(L, 3, 3, 3, 'c')
def _encadenar_r(L):
    L.disco(3.5, 6.0, 2.4, 'm', luz='l', sombra='d')
    L.disco(3.5, 6.0, 1.0, 'K')
    L.disco(8.5, 6.0, 2.4, 'm', luz='l', sombra='d')
    L.disco(8.5, 6.0, 1.0, 'K')
def _carrera_larga_r(L):
    rayas(L, 4, 3, 4, 'c')
    espada(L, 4, 6, 11, 6, cruz=False)
def _ancho_r(L):
    L.linea(1, 3, 11, 3, ['c'])
    L.linea(1, 9, 11, 9, ['c'])
    espada(L, 1, 6, 11, 6, cruz=False)
def _por_la_espalda_r(L):
    L.filas(5, 2, rc(SILUETA, {'k': 'r'}))
    espada(L, 0, 11, 6, 5, cruz=False)
def _esquivar_cruzar(L):
    L.arco(6.0, 7.0, 5.0, 200, 340, ['B', 'b', 'b', 'B'], paso=6)
    rayas(L, 5, 7, 2, 'c')
def _presteza_r(L):
    L.filas(4, 3, rc(PIE, {}))
    rayas(L, 4, 3, 3, 'c')
    L.filas(9, 0, ["c", "C"])


# ------------------------------------------------------------------ SEÑALAR EL HUECO
def _marca_honda(L):
    marca(L, 6.0, 6.0, 4.6)
    L.disco(6.0, 6.0, 2.2, 'R')
    L.px(6, 6, 'E')
def _marca_larga(L):
    marca(L, 4.0, 5.0, 3.0)
    L.filas(8, 4, ["HHH", ".a.", "HHH"])
def _sobre_marcado(L):
    marca(L, 4.0, 4.0, 3.0)
    espada(L, 11, 11, 6, 6, cruz=False)
    chispa(L, 8, 2)
def _ojo_duelista(L):
    # (26/11) el ojo sobre la diana
    marca(L, 7.0, 7.0, 3.6)
    L.filas(0, 0, ["..kkkkk..", ".eeeeeee.", "eeeyiyeee", ".eeyyyee.", "..eeeee.."])
def _a_por_el(L):
    marca(L, 6.0, 3.0, 2.4)
    L.filas(0, 7, rc(FLECHA, {'w': 'E'})[1:4])
    L.filas(7, 7, rc(base.RAYO, {}))
def _orden_ataque(L):
    # (26/11) la silueta que sale de la sombra con la marca encima
    L.filas(2, 4, rc(SILUETA, {'k': 'S'}))
    L.filas(6, 4, rc(SILUETA, {'k': 'r'}))
    marca(L, 8.5, 2.0, 1.8)
def _sin_fallo(L):
    marca(L, 7.0, 5.0, 3.4)
    L.filas(0, 8, rc(FLECHA, {'w': 'w'}))
def _paso_al_hueco(L):
    L.filas(1, 5, PIE)
    marca(L, 8.5, 4.0, 2.6)
    rayas(L, 6, 8, 1, 'c')
def _caza(L):
    L.filas(1, 4, rc(SILUETA, {'k': 'S'}))
    marca(L, 4.0, 6.0, 1.6)
    L.filas(7, 3, ["..a.", ".aaa", "aaaa", ".aa."])
def _mano_rapida_s(L):
    marca(L, 3.5, 3.5, 2.4)
    L.filas(5, 5, RELOJ[:6])


# ------------------------------------------------------------------ CORTE DE TENDONES
def _barrido_bajo(L):
    tajo(L, 6.0, 6.0, 5.4, 0, 260)
    L.filas(4, 4, PIE)
def _brazo_largo_t(L):
    L.filas(1, 3, PIE)
    espada(L, 3, 10, 11, 10, cruz=False)
def _asegurar_corte(L):
    L.filas(3, 1, PIE)
    L.filas(2, 7, ["rrrrrr", ".rRRr."])
def _sin_curarse(L):
    # (26/11) la cruz de cura, rota y roja
    L.filas(3, 2, ["..gg..", "..gg..", "gggggg", "rrgggg", "..rr..", "..rr.."])
    L.linea(1, 10, 10, 1, ['R', 'r'])
def _al_que_cojea(L):
    L.filas(1, 4, rc(PIE, {'n': 'C', 'N': 'C'}))
    espada(L, 11, 11, 6, 6, cruz=False)
    chispa(L, 9, 2)
def _desangrar_t(L):
    L.filas(3, 1, PIE)
    L.filas(3, 7, ["r.r.", "rr.r", ".R.R"])
def _arrodillar(L):
    L.filas(2, 3, rc(SILUETA, {'k': 'r'}))
    L.linea(1, 11, 10, 11, ['H'])
    L.filas(8, 1, ["E", "E", ".", "E"])
def _presa_facil(L):
    # (26/11) la huella del cojo con la estrella del critico encima
    L.filas(1, 5, rc(PIE, {'n': 'C', 'N': 'C'}))
    L.filas(5, 0, ESTRELLA[0:7])
def _retroceso_t(L):
    L.filas(0, 4, rc(FLECHA[::-1], {'w': 'c'}) if False else ["..w....", ".ww....", "wwwwwww", ".ww....", "..w...."])
    L.filas(8, 4, PIE)
def _clavarlo(L):
    L.filas(4, 0, PIE)
    L.linea(0, 10, 11, 10, ['H'])
    L.filas(2, 6, ["g.....g.", ".g...g..", "..gGg...", ".gGgGg..", "GgGGgGG."])


NODOS = [
    ("tajo_quebrantador", [("tajo_a_fondo", "Tajo a fondo", _tajo_a_fondo), ("barrido_ancho", "Barrido ancho", _barrido_ancho),
                           ("romper_guardia", "Romper la guardia", _romper_guardia),
                           ("quebrar_armadura", "Quebrar armadura", _quebrar_armadura),
                           ("hueco_abierto", "Hueco abierto", _hueco_abierto), ("abrir_a_todos", "Abrir a todos", _abrir_a_todos),
                           ("exponer_mas", "Exponer más", _exponer_mas), ("desequilibrio_q", "Desequilibrio", _desequilibrio_q),
                           ("aprovechar_hueco", "Aprovechar el hueco", _aprovechar_hueco),
                           ("mano_rapida_q", "Mano rápida", _mano_rapida_q),
                           ("desarmar_guardia", "Desarmar la guardia", _desarmar_guardia)]),
    ("doble_tajo", [("tercer_tajo", "Tercer tajo", _tercer_tajo), ("mas_tajos", "Más tajos", _mas_tajos),
                    ("remate_combo", "Remate del combo", _remate_combo), ("filo_fino", "Filo fino", _filo_fino),
                    ("abanico_d", "Abanico", _abanico_d), ("brazo_largo_d", "Brazo largo", _brazo_largo_d),
                    ("filo_sangra", "Filo que sangra", _filo_sangra), ("furia_filo", "Furia de filo", _furia_filo),
                    ("respiracion_d", "Respiración", _respiracion_d)]),
    ("cambio_de_ritmo", [("acelerar", "Acelerar", _acelerar), ("encadenar_r", "Encadenar", _encadenar_r),
                         ("carrera_larga_r", "Carrera larga", _carrera_larga_r), ("ancho_r", "Ancho", _ancho_r),
                         ("por_la_espalda_r", "Por la espalda", _por_la_espalda_r),
                         ("esquivar_cruzar", "Esquivar al cruzar", _esquivar_cruzar), ("presteza_r", "Presteza", _presteza_r)]),
    ("senalar_el_hueco", [("marca_honda", "Marca honda", _marca_honda), ("marca_larga", "Marca larga", _marca_larga),
                          ("sobre_marcado", "Sobre lo marcado", _sobre_marcado), ("ojo_duelista", "Ojo de duelista", _ojo_duelista),
                          ("a_por_el", "A por él", _a_por_el), ("orden_ataque", "Orden de ataque", _orden_ataque),
                          ("sin_fallo", "Sin fallo", _sin_fallo), ("paso_al_hueco", "Paso al hueco", _paso_al_hueco),
                          ("caza", "Caza", _caza), ("mano_rapida_s", "Mano rápida", _mano_rapida_s)]),
    ("corte_de_tendones", [("barrido_bajo", "Barrido bajo", _barrido_bajo), ("brazo_largo_t", "Brazo largo", _brazo_largo_t),
                           ("asegurar_corte", "Asegurar el corte", _asegurar_corte), ("sin_curarse", "Sin poder curarse", _sin_curarse),
                           ("al_que_cojea", "Al que cojea", _al_que_cojea), ("desangrar_t", "Desangrar", _desangrar_t),
                           ("arrodillar", "Arrodillar", _arrodillar), ("presa_facil", "Presa fácil", _presa_facil),
                           ("retroceso_t", "Retroceso", _retroceso_t), ("clavarlo", "Clavarlo", _clavarlo)]),
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
    base.HABILIDADES = HABILIDADES
    base.NODOS = NODOS
    if '--hornear' in sys.argv:
        print(hornear())
    else:
        r = base.lamina_nodos('lamina_nodos_espada_corta.png') if '--nodos' in sys.argv \
            else base.lamina(HABILIDADES, 'lamina_espada_corta.png')
        print(r)
        if '--abrir' in sys.argv:
            subprocess.Popen(['mspaint', r])
