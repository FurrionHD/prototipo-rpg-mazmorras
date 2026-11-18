# ============================================================
#  iconos_chillon_versiones.py -- LOS ICONOS EN PIXEL DE LOS ESTADOS DEL CHILLON, propuestas (18/11/2026, memoria
#  chillon-mutante). Con el estilo de tools/iconos_estados_pixel.py (12 x 12; o contorno, d/m/l/w tonos del color del
#  estado, y acentos propios). Que elija el jefe; el elegido pasa a ICONOS de alli.
#    A OSCURAS    (el estado del Chillido de oscuridad: tu farolillo al minimo)
#    BEBE LA LUZ  (la pasiva del Apagaluces, sus crias y la Piña: mas rapido y mas daño por cada uno de los tuyos a oscuras)
#    RACIMO       (la pasiva de la Piña: menos daño mientras tiene crias)
#  Uso: python tools/iconos_chillon_versiones.py -> Desktop/iconos_estados/chillon_versiones.png
# ============================================================
import os
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import iconos_estados_pixel as ie

NEGRO = (16, 16, 26)
LUZ = (255, 220, 120)
LUZ_W = (255, 250, 220)

OSCURAS = (0.32, 0.34, 0.52)
VERSIONES = [
    ("osc_a", "A oscuras A\nfarol apagado", OSCURAS, (
        "....aa......", ".....a......", "....oooo....", "...o....o...", "..oooooooo..", "..obbbbbbo..",
        "..obbccbbo..", "..obbccbbo..", "..obbbbbbo..", "..oooooooo..", "...ommmmo...", "............"),
        {'a': (110, 110, 124), 'b': NEGRO, 'c': (96, 84, 70)}),
    ("osc_b", "A oscuras B\nel corro minimo", OSCURAS, (
        "...oooooo...", ".oobbbbbboo.", ".obbbbbbbbo.", "obbbbaabbbbo", "obbbaccabbbo", "obbaceecabbo",
        "obbaceecabbo", "obbbaccabbbo", "obbbbaabbbbo", ".obbbbbbbbo.", ".oobbbbbboo.", "...oooooo..."),
        {'a': (120, 100, 60), 'b': NEGRO, 'c': LUZ, 'e': LUZ_W}),
    ("osc_c", "A oscuras C\nun ala tapa el ojo", OSCURAS, (
        "............", "............", "..bbbbbbbb..", ".bbbbbbbbbb.", "obbbbbbbbbbo", "occbbbbbbcco",
        "occcaaaaccco", ".occcaaccco.", "..oocccoo...", "............", "............", "............"),
        {'a': (40, 40, 60), 'b': NEGRO, 'c': (230, 230, 236)}),
    ("beb_a", "Bebe la luz A\nse traga una gota", (0.85, 0.75, 0.35), (
        ".....cc.....", ".....ee.....", ".....cc.....", "....b..b....", "b...bbbb...b", "bb.bebbeb.bb",
        "bbbbbccbbbbb", "bbbbbbbbbbbb", ".bb.bbbb.bb.", "..b..bb..b..", "............", "............"),
        {'b': (30, 30, 40), 'c': LUZ, 'e': LUZ_W}),
    ("beb_b", "Bebe la luz B\nse come la luz", (0.85, 0.75, 0.35), (
        "....cccc....", "..cceebbbb..", ".ceeebbbbbb.", ".ceebbwbbwb.", "ceeebbbbbbb.", "ceeebbbbbbb.",
        "ceeebbbbbbb.", ".ceebbbbbbb.", ".ceeebbbbbb.", "..cceebbbb..", "....cccc....", "............"),
        {'b': (30, 30, 40), 'c': LUZ, 'e': LUZ_W, 'w': (220, 222, 228)}),
    ("rac_a", "Racimo A\nla piña de caras", (0.35, 0.33, 0.4), (
        "....o..o....", "...obbbbo...", "..obwbbwbo..", ".obbbbbbbbo.", "obwbwbbwbwbo", "obbbbbbbbbbo",
        ".obwbwbwbwo.", ".obbbbbbbbo.", "..obwbbwbo..", "...obbbbo...", "....obbo....", ".....oo....."),
        {'b': (30, 30, 40), 'w': (220, 222, 228)}),
    ("rac_b", "Racimo B\nescudo de murcielagos", (0.35, 0.33, 0.4), (
        ".oooooooooo.", "ommmmmmmmmmo", "ommmmmmmmmmo", "ombmmbbmmbmo", "ombbbbbbbbmo", "ommbwbbwbmmo",
        "ommmbbbbmmmo", ".ommmbbmmmo.", ".ommmmmmmmo.", "..ommmmmmo..", "...ommmmo...", ".....oo....."),
        {'b': (30, 30, 40), 'w': (220, 222, 228)}),
]


if __name__ == '__main__':
    lista = [(c, n, col, f, a) for c, n, col, f, a in VERSIONES]
    # (lamina() comprueba tambien los de ie; estos se dibujan por su cuenta)
    ie.comprobar = lambda: None
    ruta = ie.lamina(lista, 'chillon_versiones.png')
    print(ruta)
    if '--abrir' in sys.argv:
        subprocess.Popen(['cmd', '/c', 'start', '', 'mspaint', ruta])
