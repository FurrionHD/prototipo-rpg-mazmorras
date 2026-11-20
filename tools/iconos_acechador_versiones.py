# ============================================================
#  iconos_acechador_versiones.py -- EL ICONO EN PIXEL DE LA PASIVA DEL ACECHADOR MUTANTE, propuestas (20/11/2026, memoria
#  acechador-mutante). Con el estilo de tools/iconos_estados_pixel.py (12 x 12). Que elija el jefe; el elegido pasa a
#  ICONOS de alli.
#    PACIENCIA DEL CAZADOR  (la Sombra sin rostro y el Cazador lunar: se funde en las sombras y, tras 3 turnos escondido,
#                           su golpe pega +50 %)
#    MARCA DE LA LUNA       (el estado que pone el Cazador lunar a su presa)
#    FASES DE LA LUNA y LUZ DE LUNA  (las otras dos pasivas del Cazador lunar)
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
LUNA_W = (226, 236, 255)
LUNA_L = (170, 182, 222)
HALO = (120, 140, 210)
NOCHE = (40, 46, 86)
ESTRELLA = (190, 170, 240)

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
    # (20/11, el CAZADOR LUNAR) su estado y sus dos pasivas
    ("mar_a", "Marca de la luna A\nla creciente", (0.75, 0.8, 1.0), (
        "............", "....wwww....", "...wwll.....", "..wwl.......", "..wl........", ".wwl........",
        ".wwl........", "..wl........", "..wwl.......", "...wwll.....", "....wwww....", "............"),
        {'w': LUNA_W, 'l': LUNA_L}),
    ("mar_b", "Marca de la luna B\ncreciente y estrella", (0.75, 0.8, 1.0), (
        "............", "....wwww....", "...wwll.....", "..wwl.......", "..wl...s....", ".wwl..sss...",
        ".wwl...s....", "..wl........", "..wwl.......", "...wwll.....", "....wwww....", "............"),
        {'w': LUNA_W, 'l': LUNA_L, 's': ESTRELLA}),
    ("fas_a", "Fases de la luna A\nlas cuatro", (0.6, 0.65, 0.9), (
        ".bbb...bww..", "bbbbb.bbbww.", "bbbbb.bbbww.", "bbbbb.bbbww.", ".bbb...bww..", "............",
        ".www...wwb..", "wwwww.wwbbb.", "wwwww.wwbbb.", "wwwww.wwbbb.", ".www...wwb..", "............"),
        {'b': NOCHE, 'w': LUNA_W}),
    ("fas_b", "Fases de la luna B\nla luna y sus puntos", (0.6, 0.65, 0.9), (
        ".....p......", "............", "....bbww....", "...bbbwww...", "...bbbwww...", ".p.bbbwww.p.",
        "...bbbwww...", "...bbbwww...", "....bbww....", "............", ".....p......", "............"),
        {'b': NOCHE, 'w': LUNA_W, 'p': AMBAR}),
    ("luz_a", "Luz de luna A\nla luna llena", (0.85, 0.9, 1.0), (
        "............", "....hhhh....", "...hwwwwh...", "..hwwlwwwh..", "..hwwwwwwh..", "..hwwwwlwh..",
        "..hwlwwwwh..", "..hwwwwwwh..", "...hwwwwh...", "....hhhh....", "............", "............"),
        {'h': HALO, 'w': LUNA_W, 'l': LUNA_L}),
    ("luz_b", "Luz de luna B\nla llena que cura", (0.85, 0.9, 1.0), (
        "....hhhh....", "...hwwwwh...", "..hwwlwwwh..", "..hwwwwwwh..", "..hwwwwlwh..", "..hwlwwwwh..",
        "..hwwwwwwh..", "...hwwwwh...", "....hhhh....", ".........g..", "........ggg.", ".........g.."),
        {'h': HALO, 'w': LUNA_W, 'l': LUNA_L, 'g': (110, 220, 120)}),
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
