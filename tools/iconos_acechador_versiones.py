# ============================================================
#  iconos_acechador_versiones.py -- EL ICONO EN PIXEL DE LA PASIVA DEL ACECHADOR MUTANTE, propuestas (20/11/2026, memoria
#  acechador-mutante). Con el estilo de tools/iconos_estados_pixel.py (12 x 12). Que elija el jefe; el elegido pasa a
#  ICONOS de alli.
#    PACIENCIA DEL CAZADOR  (la Sombra sin rostro y el Cazador lunar: se funde en las sombras y, tras 3 turnos escondido,
#                           su golpe pega +50 %)
#  Uso: python tools/iconos_acechador_versiones.py -> Desktop/iconos_estados/acechador_versiones.png
# ============================================================
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iconos_estados_pixel as ie

NEGRO = (16, 16, 26)
AMBAR = (240, 170, 40)
AMBAR_W = (255, 226, 140)
HUMO = (96, 88, 120)
COLOR = (0.85, 0.55, 0.2)

VERSIONES = [
    ("pac_a", "Paciencia A\nojos en la sombra", COLOR, (
        "............", "...bbbbbb...", "..bbbbbbbb..", ".bbbbbbbbbb.", ".baabbbbaab.", "bbbaebbeabbb",
        "bbbbbbbbbbbb", ".bbbbbbbbbb.", "..bbhbbhbb..", "...h.bb.h...", "....h..h....", "............"),
        {'a': AMBAR, 'e': AMBAR_W, 'b': NEGRO, 'h': HUMO}),
    ("pac_b", "Paciencia B\nlos ojos y sus 3 cargas", COLOR, (
        "............", "..bbbbbbbb..", ".bbbbbbbbbb.", "bbaabbbbaabb", "bbbaebbeabbb", ".bbbbbbbbbb.",
        "..bbbbbbbb..", "............", "..cc.cc.cc..", "..cc.cc.cc..", "............", "............"),
        {'a': AMBAR, 'e': AMBAR_W, 'b': NEGRO, 'c': AMBAR_W}),
    ("pac_c", "Paciencia C\nel lobo en la sombra", COLOR, (
        "............", "...b...b....", "...bb.bb....", "...bbbbbb...", "..bbbbbbbb..", "..bbbbabbbbb",
        ".bbbbbbbbbbb", ".bbbbbbbbbbw", "bbbbbbbbbbb.", "hbbbbbbbb...", ".hbbbbbb....", "..h.hh......"),
        {'a': AMBAR_W, 'b': NEGRO, 'h': HUMO, 'w': (70, 64, 80)}),
]

if __name__ == '__main__':
    # (la del juego aun no existe: para la comprobacion de ie.lamina, la A hace de 'paciencia' mientras elige)
    if not any(x[0] == 'paciencia' for x in ie.ICONOS):
        a = VERSIONES[0]
        ie.ICONOS.append(('paciencia', a[1], a[2], a[3], a[4]))
    ruta = ie.lamina(VERSIONES, 'acechador_versiones.png')
    print(ruta)
    if os.name == 'nt' and '--sin-abrir' not in sys.argv:
        os.startfile(ruta)
