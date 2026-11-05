# ============================================================
#  iconos_estados_pixel.py -- LOS ICONOS DE LOS ESTADOS EN PIXEL ART (05/11/2026). El jefe: los emojis "estan graciosos
#  pero no es para un juego serio como el nuestro". Cada estado, un dibujo de 12 x 12 a varios tonos (contorno oscuro,
#  sombra, medio, luz y brillo), como el glifo de la guadaña. ESTILO APROBADO con la primera muestra ("han quedado god").
#
#  Las letras de cada dibujo:  o contorno, d sombra, m medio, l luz, w brillo  (salen del COLOR del estado en el
#  catalogo, asi el icono va a juego con su chip) y a/b/c acentos propios de ese dibujo.
#  Un dibujo de filas de 6 se ESPEJA: la mitad derecha es la izquierda al reves y en sombra (l->m, w->l).
#
#  Uso: python tools/iconos_estados_pixel.py [--abrir]    -> Desktop/iconos_estados/lamina.png
#       python tools/iconos_estados_pixel.py --hornear    -> assets/ui/estados/<clave>.png (12 x 12, lo que usa el juego)
# ============================================================
import os
import subprocess
import sys
from PIL import Image, ImageDraw, ImageFont

N = 12
RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def tonos(c):
    """Los cinco tonos de un color del catalogo (0..1)."""
    def mez(a, b, t):
        return tuple(int(round((a[i] * (1 - t) + b[i] * t) * 255)) for i in range(3))
    negro, blanco = (0.03, 0.03, 0.05), (1.0, 1.0, 1.0)
    return {'o': mez(c, negro, 0.72), 'd': mez(c, negro, 0.42), 'm': mez(c, negro, 0.12),
            'l': mez(c, blanco, 0.38), 'w': mez(c, blanco, 0.82)}


def espejo(mitad):
    cambia = {'l': 'm', 'w': 'l'}
    return tuple(f + ''.join(cambia.get(ch, ch) for ch in reversed(f)) for f in mitad)


def voltear(filas):
    return tuple(reversed(filas))


def plato(filas):
    """La marca de COMIDA: un cuenco en la esquina de abajo a la derecha (los buffs de plato llevan el mismo dibujo
    que su estado hermano, y el cuenco dice que viene de la cocina)."""
    f = [list(r) for r in filas]
    for j, fila in enumerate(("oooooo", "obbbbo", ".oooo.")):
        for i, ch in enumerate(fila):
            if ch != '.':
                f[9 + j][6 + i] = ch
    return tuple(''.join(r) for r in f)


# ------------------------------------------------------------------ dibujos que se reutilizan
GOTA = (".....o......", "....olo.....", "....omlo....", "...ommlo....", "..ommmllo...", ".ommmmmlwo..",
        ".ommmmmmlo..", ".odmmmmmmo..", ".oddmmmmmo..", "..oddddmo.o.", "...ooooo.olo", ".........odo")
FLECHA_ARRIBA = (".....oo.....", "....owlo....", "...owllmo...", "..owlllmmo..", ".ooollmmooo.", "...ollmmo...",
                 "...ollmmo...", "...ollmmo...", "...ollmmo...", "...ollmmo...", "...oooooo...", "............")
ESCUDO = espejo(("oooooo", "owllll", "olllla", "ollaaa", "olllla", "olllll", ".ollll", ".ollll", "..olll", "...oll",
                 "....ol", ".....o"))
CRUZ = ("....oooo....", "....olwo....", "....ollo....", "....ollo....", "ooooollooooo", "olwlllllllmo",
        "olllllllllmo", "ooooollmoooo", "....ollmo...", "....ollmo...", "....ommmo...", "....ooooo...")
DIAMANTE = espejo((".....o", "....ol", "...olw", "..olwl", ".ollll", "olllll", "odllll", ".oddll", "..oddl", "...odd",
                   "....od", ".....o"))
CHEVRONES = ("............", "oo....oo....", "olo...olo...", "ollo..ollo..", ".ollo..ollo.", "..ollo..ollo",
             "..ommo..ommo", ".ommo..ommo.", "ommo..ommo..", "omo...omo...", "oo....oo....", "............")
CORONA = espejo(("......", "......", ".o...o", ".oo.ol", ".olool", ".ollll", ".ollll", ".olala", ".ollll", ".ooooo",
                 "......", "......"))
BRASA = ("..o.....o...", ".obo...obo..", "..o..o..o...", ".....bo.....", "...oooooo...", "..oddaddoo..",
         ".oddabadddo.", "odaabbbadddo", "odddabaaddo.", ".oddddaddo..", "..oooooooo..", "............")
IMAN = espejo(("..oooo", ".ollll", "olwooo", "olo...", "olo...", "olo...", "olo...", "olo...", "oaao..", "oaao..",
               "oooo..", "......"))
DESTELLO = (".....o......", ".....o......", "....olo.....", "....olo.....", "..oolwloo...", "oollwwwlloo.",
            "..oolwloo...", "....olo.....", "....olo..o..", ".....o..olo.", ".....o...o..", "............")
ORBE = espejo(("...ooo", ".oolll", ".olwwl", "olwlll", "olllll", "olllll", "olllll", "odllll", "odllll", ".oddll",
               ".ooddd", "...ooo"))
RELOJ = espejo(("oooooo", "oaaaaa", ".ollll", ".olwll", "..olll", "...olw", "...olm", "..olbb", ".olbbb", ".obbbb",
                "oaaaaa", "oooooo"))


def daga(dx, dy):
    """Una daga de 4 de ancho y 10 de alto, colocada en (dx, dy) de un lienzo vacio."""
    d = ("..oo..", ".olwo.", ".olmo.", ".olmo.", ".olmo.", ".olmo.", "oaaaao", "..ob..", "..ob..", "..oo..")
    f = [['.'] * N for _ in range(N)]
    for j, fila in enumerate(d):
        for i, ch in enumerate(fila):
            x, y = dx + i, dy + j
            if ch != '.' and 0 <= x < N and 0 <= y < N:
                f[y][x] = ch
    return f


def junta(*capas):
    f = [['.'] * N for _ in range(N)]
    for c in capas:
        for j in range(N):
            for i in range(N):
                if c[j][i] != '.':
                    f[j][i] = c[j][i]
    return tuple(''.join(r) for r in f)


def pon(filas, extra):
    """Dibuja encima: extra = {(x, y): letra}."""
    f = [list(r) for r in filas]
    for (x, y), ch in extra.items():
        f[y][x] = ch
    return tuple(''.join(r) for r in f)


HUESO = {'o': (24, 40, 16), 'm': (150, 172, 128), 'l': (214, 228, 190), 'w': (250, 255, 240)}
FUEGO = {'o': (90, 22, 8), 'm': (236, 104, 28), 'a': (255, 204, 64), 'w': (255, 250, 220)}
ORO = {'a': (255, 214, 80)}
CUENCO = {'b': (196, 120, 60)}
PLATA = {'a': (230, 232, 240)}

# (clave, nombre, color del catalogo, filas, acentos). La clave es el nombre del Id en minusculas (lo que busca el juego);
# los chips sueltos (cargando, recitando...) llevan clave propia.
ICONOS = [
    # --- daño por turno
    ("veneno", "Veneno", (0.45, 0.85, 0.2), (
        "...oooooo...", "..olwllllo..", ".olwllllllo.", ".ollllllllo.", ".olaaollaao.", ".olaaollaao.",
        ".ollllollmo.", "..omllllmo..", "...olmlmo...", "...omomom...", "....ooooo...", "............"),
        dict(HUESO, a=(120, 255, 60))),
    ("sangrado", "Sangrado", (0.85, 0.15, 0.15), GOTA,
        {'o': (60, 6, 10), 'd': (130, 14, 22), 'm': (196, 30, 36), 'l': (240, 90, 90), 'w': (255, 210, 210)}),
    ("quemadura", "Quemadura", (1.0, 0.5, 0.1), (
        ".....o......", ".....oo.....", "....omo.....", "....ommo....", "...ommmo.o..", "...omamo.oo.",
        "..ommaamomo.", ".ommaawamo..", ".omaawwamo..", ".omaawwamo..", "..ommaamo...", "...ooooo...."), FUEGO),
    ("rescoldo", "Rescoldo", (0.85, 0.45, 0.25), voltear(voltear(BRASA[3:] + ("............",) * 3)),
        {'a': (255, 150, 60), 'b': (255, 220, 140)}),
    ("avivado", "Brasas avivadas", (1.0, 0.45, 0.2), BRASA, {'a': (255, 140, 40), 'b': (255, 236, 160)}),
    ("encendido", "Encendido", (1.0, 0.55, 0.15), espejo((".....o", "....oa", "...oab", "...oab", "..oawl", "..oawl",
        "...owl", "...owl", ".ooooo", "....oc", "....oc", ".....o")),
        {'a': (255, 140, 30), 'b': (255, 230, 120), 'c': (120, 80, 50), 'w': (240, 244, 250), 'l': (180, 190, 205)}),
    ("musgo_quemado", "Musgo quemado", (0.6, 0.35, 0.2), (
        ".......o....", "......oao...", "......oao...", "...o...o....", "..olo.o.o...", ".olmlolmlo..",
        "olmmmlmmmlo.", "ommdmmmdmmmo", "odddddddddmo", ".oooooooooo.", "............", "............"),
        {'a': (255, 150, 40)}),
    ("corrosion", "Corrosión", (0.55, 0.7, 0.35), (
        "....oooo....", "....owlo....", "....olmo....", "...oolmoo...", "..olllmmmo..", ".olaaaaaamo.",
        ".oawaaaaado.", "oaaaaabaaado", "oaabaaaaaddo", "oaaaaaaadddo", ".oaadddddo..", "..ooooooo..."),
        {'o': (26, 34, 20), 'l': (190, 205, 215), 'm': (120, 140, 150), 'w': (245, 250, 255), 'a': (170, 220, 60),
         'd': (100, 150, 30), 'b': (230, 255, 170)}),
    # --- control
    ("aturdido", "Aturdido", (1.0, 0.9, 0.3), (
        "....o.......", "...olo......", "..oolooo....", ".olllwllo...", "..ollllo....", "..olooloo.o.",
        "..oo..oooao.", "........oao.", "...o...oaaao", "..oao...oao.", "...o.....o..", "............"),
        {'o': (96, 70, 10), 'l': (255, 222, 80), 'w': (255, 255, 230), 'a': (255, 240, 170)}),
    ("una_cabeza", "Una cabeza aturdida", (1.0, 0.9, 0.3), (
        "....oooooooo", "....ollllllo", "....ooooollo", ".......ollo.", "......ollo..", ".....olloooo",
        "....ollllllo", "....oooooooo", "llll........", "..l.........", ".l..........", "llll........"), {}),
    ("rayo", "Electrizado", (0.6, 0.8, 1.0), (
        "......oooo..", ".....ollo...", "....ollo....", "...ollo.....", "..ollooooo..", ".olwwwwllo..",
        ".oooollo....", "....ollo....", "...olo......", "..olo.......", ".oo.........", "............"),
        {'o': (34, 46, 110), 'l': (140, 196, 255), 'w': (240, 250, 255)}),
    ("paralisis", "Parálisis", (0.36, 0.8, 0.92), espejo(("a....o", ".a..ol", "a...ol", ".a..oo", "...ool", "..olll",
        "..olll", "...oll", "...ol.", "...ol.", "...oo.", "......")), {'a': (200, 250, 255)}),
    ("congelacion", "Congelación", (0.6, 0.85, 1.0), (
        ".....o......", "..o.olo.o...", ".olooloolo..", "..ololwlo...", "...ollwo....", "oooolwlloooo",
        "ollllwwllllo", "oooollwoooo.", "...owllo....", "..olollolo..", ".oloolooolo.", "..o.olo.o..."),
        {'o': (40, 70, 110), 'l': (170, 220, 255), 'w': (250, 255, 255)}),
    ("miedo", "Miedo", (0.55, 0.35, 0.7), espejo(("...ooo", ".oolll", ".olwll", "olllll", "olaoll", "olaoll",
        "olllll", "olllll", "ollloo", "ollloo", ".ollll", "..oooo")), {'a': (250, 250, 255)}),
    ("silencio", "Silencio", (0.65, 0.5, 0.8), (
        "..oooooooo..", ".ollllllllmo", "ollallllalmo", "olllallalmmo", "ollllaalmmmo", "ollllaalmmmo",
        "olllallalmmo", "ollallllammo", ".ommmmmmmmo.", "..ooommooo..", "....omo.....", "....oo......"),
        {'a': (140, 20, 40)}),
    ("ceguera", "Ceguera", (0.72, 0.68, 0.5), (
        "............", "...oooooo...", "..owllllmo..", ".olloooolmo.", "ollobbbbolmo", "aaaaaaaaaaaa",
        "aaaaaaaaaaaa", "ollobbbbolmo", ".ollooooomo.", "..ommmmmmo..", "...oooooo...", "............"),
        {'a': (205, 205, 196), 'b': (40, 36, 30)}),
    ("enraizado", "Enraizado", (0.45, 0.62, 0.3), (
        "...oo..oo...", "..oaaooaao..", "...oaaaao...", ".....oo.....", "....omlo....", "..ooomloo...",
        ".omoommooo..", "omo.omlo.omo", "oo.omoomo.oo", "..omo..omo..", ".omo....omo.", ".oo......oo."),
        {'o': (36, 24, 12), 'm': (110, 76, 40), 'l': (160, 120, 70), 'a': (110, 190, 70)}),
    ("enroscado", "Enroscado", (0.62, 0.45, 0.3), (
        "..oooooooo..", ".ollllllllo.", "olloooooollo", "olo......olo", "olo.oooo.olo", "olo.olao.olo",
        "olo.olao.olo", "olo..olo.olo", "olloooloollo", ".olllllllmo.", "..oooooooo..", "............"),
        {'a': (255, 200, 80)}),
    ("encapullado", "Encapullado", (1.0, 0.42, 0.08), espejo(("....oo", "...oll", "..olaa", "..olll", ".oaaal",
        ".ollll", ".olaaa", ".ollll", "..oaaa", "..olll", "...oll", "....oo")), {'a': (240, 236, 220)}),
    ("imantado", "Imantado", (0.8, 0.19, 0.13), IMAN, PLATA),
    ("adherido", "Adherido", (0.6, 0.62, 0.68), pon(IMAN, {(5, 9): 'b', (6, 9): 'b', (5, 10): 'b', (6, 10): 'b'}),
        dict(PLATA, b=(200, 60, 50))),
    ("orbita", "Órbita", (0.8, 0.19, 0.13), (
        "............", "............", "...llllll...", ".ll......ll.", "l....oo....l", "l...oaao...l",
        "l...oaao...l", "l....oo....l", ".ll......ll.", "...llllll...", "............", "............"),
        {'a': (230, 232, 240)}),
    ("limaduras", "Limaduras", (0.58, 0.61, 0.67), (
        ".l.....m....", "..m...l...l.", "......m..m..", "l..l........", ".m.....l..m.", "....m.......",
        "..l....m..l.", "m......l....", "...m.l....m.", ".l.......l..", "....l.m.....", ".m........l."), {}),
    ("pegajoso", "Pegajoso", (0.4, 0.8, 0.4), (
        "oooooooooooo", "ollllwllllmo", "ommmmmmmmmmo", ".ommo.ommmo.", ".omo..ommo..", ".omo...omo..",
        "..o....omo..", "..o.....o...", ".olo....o...", ".omo...olo..", "..o....omo..", ".......oo..."), {}),
    ("resinado", "Resinado", (0.95, 0.6, 0.15), espejo(("...ooo", "..olww", ".olwll", ".ollll", "olllll", "ollllb",
        "ollllb", "olllll", ".ollll", ".odlll", "..oddl", "...ooo")), {'b': (70, 36, 10)}),
    ("pringado", "Pringado", (0.5, 0.36, 0.2), (
        "..oo....o...", ".olmo..olo..", ".ommo..omo..", "..oo....o...", "......oo....", ".....olmo...",
        "..ooooommooo", ".ommlllmmmmo", "ommllmmmmddo", "odmmmmmdddo.", ".oddddddoo..", "..oooooo...."),
        {'o': (40, 26, 12), 'd': (88, 60, 30), 'm': (128, 92, 50), 'l': (178, 140, 90)}),
    ("pegado", "Sanguijuela", (0.55, 0.2, 0.28), (
        "............", "............", "..oooo......", ".ollllo.....", "olwlllloo...", "ollmmmlllo..",
        ".oommmmmllo.", "...oommmmmlo", ".....oommmao", ".......oooo.", "............", "............"),
        {'a': (255, 120, 130)}),
    ("picor", "Picor", (0.85, 0.5, 0.35), (
        "............", ".oo....oo...", "oaao..oaao..", "oaaao.oaaao.", ".oaaoooaao..", "...oollo....",
        "..o.omlo.o..", ".o..omlo..o.", "...o.oo.o...", "..o..oo..o..", "......o.....", "......o....."),
        {'a': (210, 225, 235)}),
    ("savia_negra", "Savia negra", (0.55, 0.4, 0.8), GOTA,
        {'o': (8, 6, 12), 'd': (16, 12, 24), 'm': (34, 26, 48), 'l': (120, 90, 180), 'w': (210, 190, 255)}),
    ("lento", "Lento", (0.3, 0.6, 0.9), (
        "............", ".o.o..oooo..", ".olo.ommmmo.", "..ol.omllmmo", "..olomlmmlmo", "..olomlolmmo",
        "..olommllmmo", "..ollommmmo.", ".olllloooooo", "ollllllllllo", "oddddddddddo", ".oooooooooo."), {}),
    # --- debilidades y fortalezas
    ("debil", "Débil", (0.7, 0.4, 0.9), voltear(FLECHA_ARRIBA), {}),
    ("fortaleza", "Fortaleza", (0.95, 0.8, 0.2), FLECHA_ARRIBA,
        {'o': (90, 64, 6), 'm': (210, 160, 30), 'l': (255, 214, 80), 'w': (255, 248, 210)}),
    ("vulnerable", "Vulnerable", (0.9, 0.3, 0.5), (
        ".oooooooooo.", ".ollllolllo.", ".olwlloolmo.", ".ollllolmmo.", ".olllooommo.", ".ollloommmo.",
        "..ollolmmo..", "..olloommo..", "...oloomo...", "....oloo....", ".....oo.....", "............"),
        {'o': (70, 16, 34), 'm': (176, 60, 96), 'l': (236, 120, 156), 'w': (255, 220, 232)}),
    ("baluarte", "Baluarte", (0.6, 0.75, 0.95), ESCUDO, ORO),
    ("coraza_iman", "Coraza imantada", (0.34, 0.37, 0.43), pon(ESCUDO, {(4, 2): 'b', (7, 2): 'b', (4, 3): 'b',
        (7, 3): 'b', (4, 4): 'b', (5, 4): 'b', (6, 4): 'b', (7, 4): 'b', (5, 3): 'l', (6, 3): 'm', (5, 2): 'l',
        (6, 2): 'm'}), {'a': (160, 165, 175), 'b': (210, 60, 45)}),
    ("presteza", "Presteza", (0.5, 0.9, 0.95), CHEVRONES, {}),
    ("marca", "Marca", (0.95, 0.45, 0.3), espejo(("....ol", "..oool", ".olloo", ".olo..", "olo...", "oll..a",
        "oll..a", "olo...", ".olo..", ".olloo", "..oool", "....ol")), {'a': (255, 240, 200)}),
    ("herida_profunda", "Herida profunda", (0.8, 0.25, 0.35), (
        "........ooo.", ".......owllo", "......owlllo", ".....owllmo.", "....owlaao..", "...ollaao...",
        "..ollmao....", ".ollmmo.....", "ollmmo......", "olmmo.......", ".ooo........", "............"),
        {'o': (60, 40, 30), 'l': (236, 222, 196), 'w': (255, 250, 240), 'm': (190, 170, 140), 'a': (200, 30, 40)}),
    ("guardia_carne", "Guardia de carne", (0.85, 0.35, 0.4), espejo(("......", ".ooo..", "owllo.", "olllll",
        "ollall", "ollall", ".ollll", "..olll", "...oll", "....ol", ".....o", "......")), {'a': (120, 20, 40)}),
    ("sigilo", "Sigilo", (0.45, 0.5, 0.6), espejo(("....oo", "...oll", "..olll", "..olaa", ".olaaa", ".olaab",
        ".ollaa", "ollllo", "olllll", "olllll", "olllll", "oooooo")), {'a': (14, 14, 20), 'b': (200, 230, 255)}),
    ("en_sombras", "En las sombras", (0.3, 0.3, 0.42), (
        "....oooo....", "..oolllo....", ".olllo......", ".ollo.......", "ollo........", "ollo........",
        "ollo........", "olllo.......", ".ollloo....o", ".ommmlloooo.", "..oommmmoo..", "....oooo...."), {}),
    ("escolta", "Escolta", (0.9, 0.8, 0.55), junta(daga(1, 0), daga(6, 2)), {'a': (200, 160, 60), 'b': (110, 70, 40)}),
    ("oportunista", "Oportunista", (0.62, 0.55, 0.85), pon(junta(daga(2, 1)),
        {(9, 1): 'c', (8, 2): 'c', (9, 2): 'c', (10, 2): 'c', (9, 3): 'c'}),
        {'a': (150, 120, 200), 'b': (70, 50, 90), 'c': (255, 255, 230)}),
    ("afilado", "Afilado", (0.55, 0.5, 0.7), pon(junta(daga(4, 1)),
        {(1, 3): 'c', (0, 4): 'c', (1, 4): 'c', (2, 4): 'c', (1, 5): 'c', (9, 6): 'c', (10, 5): 'c', (10, 7): 'c',
         (11, 6): 'c'}), {'a': (150, 140, 180), 'b': (70, 50, 40), 'c': (255, 255, 255)}),
    ("decreto", "Decreto", (0.55, 0.9, 1.0), CORONA, {'a': (255, 255, 255)}),
    ("furia_rey", "Furia de rey", (0.9, 0.22, 0.15), ("..o.o..o.o..", "...o....o...", "..o.o..o.o..") + CORONA[2:11],
        {'a': (255, 220, 80)}),
    ("colmillos_rotos", "Colmillos rotos", (0.45, 0.88, 1.0), (
        "..ooo..ooo..", ".owlloolllo.", ".olllllllmo.", ".olllllllmo.", ".olllllllmo.", "..ollllllo..",
        "..olllllmo..", "...olllmo...", "...ollo.....", "....oo..o...", "........oo..", ".......omo.."), {}),
    ("en_vuelo", "En el aire", (0.3, 0.66, 0.52), (
        "..........oo", "........oolo", "......oollmo", "....oollllmo", "..oolllllmo.", ".olllllmmo..",
        "olllmmmoo...", "ollmoomo....", "omoolmo.....", "oolmoo......", "omo.........", "oo.........."), {}),
    ("elitros", "Élitros cerrados", (0.3, 0.66, 0.52), espejo(("....oo", "...oll", "..oooo", ".ollwo", "ollllo",
        "ollllo", "ollllo", "ollllo", "ollllo", ".olllo", "..ollo", "...ooo")), {}),
    # --- curas
    ("regeneracion", "Regeneración", (0.4, 0.9, 0.55), CRUZ,
        {'o': (16, 70, 34), 'm': (60, 170, 90), 'l': (120, 230, 150), 'w': (230, 255, 236)}),
    ("regen_mana", "Regen. maná", (0.4, 0.6, 1.0), DIAMANTE, {}),
    ("resguardo", "Resguardo", (0.55, 0.85, 0.45), espejo(("....oo", "...oaa", "....ow", "...oow", "..olll", ".ollgg",
        "olgggg", "oggggg", "oggggg", "odgggg", ".oddgg", "..oooo")),
        {'a': (150, 100, 60), 'g': (120, 210, 90), 'l': (210, 225, 235), 'w': (250, 255, 255)}),
    ("mojado", "Mojado", (0.4, 0.7, 1.0), (
        "...o........", "..olo.......", "..olo...o...", ".omllo.olo..", ".ommlo.olo..", ".ommmoomllo.",
        "..ooo.ommlo.", "......ommmo.", "..o....ooo..", ".olo........", ".omo........", "..o........."), {}),
    # --- platos de cocina (el dibujo de su estado hermano + el cuenco)
    ("plato_guardia", "Aguante (plato)", (0.55, 0.7, 0.95), plato(ESCUDO), dict(ORO, **CUENCO)),
    ("plato_brio", "Reflejos (plato)", (0.5, 0.9, 0.8), plato(CHEVRONES), CUENCO),
    ("plato_furia", "Fuerza (plato)", (0.95, 0.5, 0.3), plato(FLECHA_ARRIBA), CUENCO),
    ("plato_arcano", "Magia (plato)", (0.7, 0.55, 0.95), plato(DESTELLO), CUENCO),
    ("plato_nucleo", "Maná (plato)", (0.45, 0.6, 0.95), plato(DIAMANTE), CUENCO),
    ("plato_remedio", "Remedios (plato)", (0.5, 0.9, 0.5), plato(CRUZ), CUENCO),
    ("plato_estomago", "Estómago (plato)", (0.85, 0.8, 0.5), plato(espejo((".....o", ".....o", "....ol", "...oll",
        "..olll", ".ollal", "olllal", "olllal", "olllal", ".ollal", "..oooo", "..o.o."))),
        dict(CUENCO, a=(170, 150, 100))),
    ("plato_fortuna", "Fortuna (plato)", (0.45, 0.85, 0.5), plato(espejo(("..oo..", ".ollo.", "olwlo.", "olllo.", ".ollo.", "..oooo",
        ".ollo.", "olllo.", "olllo.", ".ollo.", "..oo.o", "....o."))), CUENCO),
    # --- los chips sueltos del combate (no son del catalogo)
    ("cargando", "Preparando", (0.95, 0.75, 0.35), RELOJ, {'a': (120, 80, 40), 'b': (255, 214, 120)}),
    ("carga_lista", "Lista para soltar", (1.0, 0.85, 0.3), pon(RELOJ, {(5, 6): 'w', (6, 6): 'w', (5, 7): 'w'}),
        {'a': (120, 80, 40), 'b': (255, 240, 160)}),
    ("recitando", "Recitando", (0.6, 0.55, 1.0), pon(ORBE, {(4, 4): 'b', (4, 5): 'b', (4, 6): 'b', (4, 7): 'b',
        (5, 5): 'b', (5, 6): 'b', (6, 5): 'b', (6, 6): 'b', (7, 6): 'b', (5, 4): 'b', (5, 7): 'b', (6, 4): 'b',
        (6, 7): 'b'}), {'b': (255, 255, 255)}),
    ("foco", "Foco arcano", (0.55, 0.7, 1.0), ORBE, {}),
    ("provocando", "Provocando", (0.95, 0.45, 0.3), espejo(("....oo", "...owl", "...oll", "...oll", "...oll",
        "...oll", "....ol", "....ol", "....oo", "....oo", "...oll", "....oo")), {}),
    ("provocado", "Provocado", (0.9, 0.3, 0.3), (
        "............", "..oo....oo..", ".olo....olo.", ".ollo..ollo.", "..ollooollo.", "....ollo....",
        "....ollo....", "..ollooollo.", ".ollo..ollo.", ".olo....olo.", "..oo....oo..", "............"), {}),
    ("cubriendo", "Cubriendo", (0.6, 0.75, 0.95), pon(ESCUDO, {(9, 3): 'a', (10, 4): 'a', (9, 5): 'a'}), ORO),
    ("cubierto", "Cubierto", (0.6, 0.75, 0.95), pon(ESCUDO, {(2, 3): 'a', (1, 4): 'a', (2, 5): 'a'}), ORO),
    ("en_guardia", "En guardia", (0.85, 0.8, 0.5), junta(daga(3, 1)), {'a': (200, 170, 80), 'b': (90, 60, 40)}),
    ("defendiendo", "Defendiendo", (0.6, 0.75, 0.95), ESCUDO, {'a': (255, 255, 255)}),
    ("sin_fuelle", "Sin fuelle", (0.8, 0.6, 0.45), (
        "............", "..ooo.......", ".olllo.ooo..", "olwlllolllo.", "ollllllllmo.", ".ommmmmmmo..",
        "..ooooooo...", "............", ".aa..aaa....", "...aa...aa..", "............", "............"),
        {'a': (230, 230, 240)}),
    ("pocion_vida", "Poción en el cuerpo", (0.9, 0.3, 0.35), espejo(("....oo", "...oaa", "....ow", "...oow", "..olll",
        ".ollgg", "olgggg", "oggggg", "oggggg", "odgggg", ".oddgg", "..oooo")),
        {'a': (150, 100, 60), 'g': (230, 60, 70), 'l': (210, 225, 235), 'w': (250, 255, 255)}),
    ("pocion_mana", "Poción de maná", (0.4, 0.7, 1.0), espejo(("....oo", "...oaa", "....ow", "...oow", "..olll",
        ".ollgg", "olgggg", "oggggg", "oggggg", "odgggg", ".oddgg", "..oooo")),
        {'a': (150, 100, 60), 'g': (70, 130, 240), 'l': (210, 225, 235), 'w': (250, 255, 255)}),
]


# ------------------------------------------------------------------ LOS DEL RESTO DE LA INTERFAZ (05/11, el jefe: "todo
# tiene que ir con pixel art"): el registro, los avisos, los botones. Mismo estilo; se pintan en cualquier texto por la
# FUENTE DE ICONOS (scripts/ui/fuente_iconos.gd), que cambia cada emoji por su dibujo.
CALAVERA = ICONOS[0][3]
ICONOS_UI = [
    ("espadas", "Pelea", (0.78, 0.8, 0.86), (
        "oo........oo", "owo......olo", ".owo....olo.", "..owo..olo..", "...owoolo...", "....owlo....",
        "....olwo....", "...oloowo...", "..olo..owo..", ".aa......aa.", "bo........ob", "o..........o"),
        {'a': (200, 160, 60), 'b': (110, 70, 40)}),
    ("luz", "Luz", (1.0, 0.85, 0.35), espejo((".....a", ".a...a", "..a...", "....oo", "...olw", "aa.olw", "aa.oll",
        "...odl", "....oo", "..a...", ".a...a", ".....a")), {'a': (255, 240, 170)}),
    ("golpe", "Golpe", (1.0, 0.55, 0.15), (
        ".....o......", "..o..oo..o..", "...oollooo..", "oooolwwlo...", ".olwwwwwlooo", "..olwwwwwlo.",
        ".olwwwwwlo..", "oollwwwwloo.", "...olwwlooo.", "..oolloo.o..", ".o...oo.....", ".....o......"),
        {'w': (255, 240, 170)}),
    ("magia", "Magia", (0.75, 0.6, 1.0), DESTELLO, {}),
    ("viento", "Viento / esquiva", (0.6, 0.9, 0.95), (
        "............", ".......oo...", "........lo..", "ooooooooolo.", "lllllllllo..", "............",
        ".ooooooo....", "llllllllo...", "......olo...", ".....oo.....", "............", "............"), {}),
    ("corona", "Corona (jefe)", (0.95, 0.75, 0.2), CORONA, {'a': (220, 40, 50)}),
    ("arma", "Arma", (0.8, 0.82, 0.88), junta(daga(3, 1)), {'a': (200, 160, 60), 'b': (110, 70, 40)}),
    ("muerte", "Muerte", (0.7, 0.7, 0.72), CALAVERA,
        {'o': (20, 20, 24), 'm': (140, 140, 146), 'l': (210, 210, 214), 'w': (250, 250, 252), 'a': (20, 20, 24)}),
    ("victoria", "Victoria", (0.95, 0.75, 0.2), espejo((".ooooo", "oolwll", "o.olll", ".oolll", "..olll", "...oll",
        "....ol", "....ol", "...oll", "..olll", "..oooo", "......")), {}),
    ("huir", "Huir", (0.6, 0.42, 0.28), (
        "............", "............", ".....oooo...", ".....ollo...", ".....ollo...", "aaa..ollo...",
        ".....olloo..", ".aaa.ollllo.", ".....olllllo", "aaa..ooooooo", "............", "............"),
        {'a': (220, 225, 235)}),
    ("ok", "Hecho", (0.4, 0.85, 0.4), (
        "............", "............", "..........oo", ".........olo", "........ollo", ".oo....ollo.",
        "olo...ollo..", "ollo.ollo...", ".olloollo...", "..ollllo....", "...ollo.....", "....oo......"), {}),
    ("no", "No / cerrar", (0.9, 0.3, 0.3), (
        "............", ".oo......oo.", "ollo....ollo", ".ollo..ollo.", "..olloollo..", "...ollllo...",
        "...ollllo...", "..olloollo..", ".ollo..ollo.", "ollo....ollo", ".oo......oo.", "............"), {}),
    ("estrella", "Estrella", (1.0, 0.82, 0.25), espejo((".....o", "....ol", "....ow", "oooolw", "ollllw", ".ollll",
        "..olll", "..olll", ".ollll", ".olloo", "oloo..", "oo....")), {}),
    ("prohibido", "Prohibido", (0.85, 0.2, 0.2), espejo(("...ooo", ".oolll", ".ollll", "olllll", "olllll", "olaaaa",
        "olaaaa", "olllll", "olllll", ".ollll", ".oolll", "...ooo")), {'a': (255, 255, 255)}),
    ("vida", "Vida", (0.9, 0.25, 0.3), espejo(("......", ".ooo..", "owllo.", "olllll", "olllll", "olllll", ".ollll",
        "..olll", "...oll", "....ol", ".....o", "......")), {}),
    ("lupa", "Lupa", (0.6, 0.45, 0.3), (
        "..oooo......", ".oaaaao.....", "oaawaaao....", "oaaaaaao....", "oaaaaaao....", ".oaaaao.....",
        "..oooo.o....", "......olo...", ".......olo..", "........olo.", ".........olo", "..........oo"),
        {'a': (170, 210, 235), 'w': (250, 255, 255), 'o': (40, 34, 30)}),
    ("aviso", "Aviso", (1.0, 0.8, 0.2), espejo((".....o", "....ol", "....ol", "...olb", "...olb", "..ollb", "..ollb",
        ".olllb", ".ollll", "ollllb", "olllll", "oooooo")), {'b': (40, 30, 10)}),
    ("candado", "Candado", (0.95, 0.75, 0.25), espejo(("...ooo", "..oaaa", ".oao..", ".oao..", ".oao..", "oooooo",
        "olllll", "ollllb", "ollllb", "olllll", "odllll", "oooooo")), {'a': (190, 195, 205), 'b': (40, 30, 10)}),
    ("esporas", "Esporas", (0.85, 0.25, 0.25), espejo(("...ooo", ".oolll", ".ollal", "olaall", "olllll", "oooooo",
        "...obb", "...obb", "...obb", "..obbb", "..oooo", "......")), {'a': (255, 245, 235), 'b': (230, 215, 190)}),
    ("puas", "Púas", (0.55, 0.42, 0.3), espejo((".....o", "....ow", ".o..ol", "oo..ol", "ol.oll", "ololll", "olllll",
        "olllll", "oddddd", "oooooo", "......", "......")), {}),
    ("reflejo", "Reflejo", (0.85, 0.7, 0.3), espejo(("...ooo", ".ooaaa", ".oabbb", "oabwbb", "oabbwb", "oabbbb",
        "oabbbb", "oabbbb", ".oabbb", ".ooaaa", "...ooo", "......")),
        {'a': (220, 175, 70), 'b': (170, 215, 240), 'w': (250, 255, 255)}),
    ("burbujas", "Burbujas", (0.6, 0.85, 0.5), (
        "......llll..", ".....l.w..l.", ".....lw...l.", ".....l....l.", "......llll..", ".lll........",
        "lw..l..ll...", "l...l.l.wl..", "l...l.l..l..", ".lll...ll...", "............", "............"), {}),
    ("rata", "Rata", (0.6, 0.6, 0.64), (
        "............", "............", "...oo.......", "..olao......", ".ollloooooo.", "olbllllllllo",
        "pllllllllllo", ".ommmmmmmmo.", "..oo....oo.o", "..........o.", ".........o..", "............"),
        {'a': (230, 150, 160), 'b': (10, 10, 12), 'p': (230, 150, 160)}),
    ("escarabajo", "Escarabajo", (0.85, 0.55, 0.15), espejo(("....oo", "...oll", "..oooo", ".ollwo", "ollllo",
        "ollllo", "ollllo", "ollllo", "ollllo", ".olllo", "..ollo", "...ooo")), {}),
    ("slime", "Slime", (0.4, 0.85, 0.35), espejo(("......", "......", "....oo", "..ooll", ".olwll", ".ollll",
        "ollbll", "ollbll", "olllll", "odllll", ".ooooo", "......")), {'b': (16, 30, 14)}),
    ("arco", "Arco", (0.6, 0.42, 0.25), (
        "..oo........", "..a.oo......", "..a..olo....", "..a...olo...", "..a....olo..", "bbbbbbbbbbcc",
        "..a....olo..", "..a...olo...", "..a..olo....", "..a.oo......", "..oo........", "............"),
        {'a': (230, 230, 220), 'b': (190, 160, 110), 'c': (210, 215, 225)}),
    ("recitar", "Recitar", (0.65, 0.5, 0.95), (
        "............", ".oooooooooo.", "ollllllllllo", "ollllllllllo", "olaalaalaalo", "olaalaalaalo",
        "ollllllllllo", "ommmmmmmmmmo", "..ooommoooo.", "....omo.....", "....oo......", "............"),
        {'a': (255, 255, 255)}),
    ("prisma", "Prisma", (0.8, 0.85, 0.95), (
        ".....o......", "....olo.....", "....olo.....", "...ollwo....", "...ollwo....", "aa.olllwo...",
        "..ollllwlorr", "..olllllloyy", ".olllllllogg", ".ooooooooouu", "............", "............"),
        {'a': (255, 255, 255), 'r': (240, 70, 60), 'y': (250, 220, 70), 'g': (90, 210, 90), 'u': (80, 130, 240)}),
    ("gema", "Gema", (0.4, 0.85, 0.95), espejo(("......", "..oooo", ".olwwl", "olwlll", "oooooo", ".oldll", "..olll",
        "..odll", "...oll", "....ol", ".....o", "......")), {}),
    ("tormenta", "Tormenta", (0.62, 0.64, 0.72), (
        "....oooo....", "...ollllo...", ".ooollllooo.", "olllllllllmo", "ommmmmmmmmmo", ".ooooaaooo..",
        ".....aa.....", "....aa......", "...aaaa.....", ".....aa.....", "....aa......", "...a........"),
        {'a': (255, 225, 80)}),
    ("emboscada", "Emboscada", (0.95, 0.35, 0.3), DESTELLO, {}),
    ("cana", "Caña", (0.6, 0.42, 0.25), (
        "..........oo", ".........ol.", "........ol.a", ".......ol..a", "......ol...a", ".....ol....a",
        "....ol.....a", "...ol......a", "..ol.......b", ".oo.......bb", "oo........b.", "............"),
        {'a': (230, 230, 220), 'b': (190, 195, 205)}),
    ("subir", "Subir", (0.45, 0.85, 0.45), FLECHA_ARRIBA, {}),
    ("registro", "Registro", (0.9, 0.82, 0.62), (
        "............", ".oooooooooo.", "omllllllllmo", ".olbbbbbblo.", ".ollllllllo.", ".olbbbblllo.",
        ".ollllllllo.", ".olbbbbbblo.", ".ollllllllo.", "omllllllllmo", ".oooooooooo.", "............"),
        {'b': (120, 100, 70)}),
    ("ajustes", "Ajustes", (0.62, 0.64, 0.7), espejo(("....oo", ".oo.ol", ".olool", "..olll", "ooolll", "olllob",
        "olllob", "ooolll", "..olll", ".olool", ".oo.ol", "....oo")), {'b': (20, 20, 24)}),
    ("arriba", "Abrir", (0.85, 0.85, 0.9), (
        "............", "............", "............", "............", ".....oo.....", "....olwo....",
        "...ollwlo...", "..ollllllo..", ".oooooooooo.", "............", "............", "............"), {}),
    ("abajo", "Cerrar", (0.85, 0.85, 0.9), voltear((
        "............", "............", "............", "............", ".....oo.....", "....olwo....",
        "...ollwlo...", "..ollllllo..", ".oooooooooo.", "............", "............", "............")), {}),
    ("listo", "Listo", (0.85, 0.85, 0.9), (
        "............", "...oo.......", "...owo......", "...owlo.....", "...olllo....", "...ollllo...",
        "...olllmo...", "...ollmo....", "...olmo.....", "...omo......", "...oo.......", "............"), {}),
]

def girar(filas):
    """90 grados a la derecha."""
    return tuple(''.join(f[i] for f in reversed(filas)) for i in range(N))


def reflejar(filas):
    return tuple(f[::-1] for f in filas)


# Los SIGNOS sueltos que salen entre el texto (flechas, puntos): en gris claro, como la letra. Antes los ponia la fuente
# del sistema, que ya no se usa (ver scripts/ui/fuente_iconos.gd).
GRIS = (0.85, 0.86, 0.9)
FLECHA_DER = ("............", "............", "............", "......o.....", "......olo...", ".ooooooollo.",
              ".olllllllllo", ".ooooooollo.", "......olo...", "......o.....", "............", "............")
TRIANGULO_DER = ICONOS_UI[-1][3]
VUELTA = ("............", "...oooooo...", "..ollllllo..", ".olloooollo.", ".olo....olo.", ".olo....olo.",
          "ooloo...olo.", "olllo...olo.", ".olo....olo.", "..o.....oo..", "............", "............")
ICONOS_UI += [
    ("flecha_der", "Flecha →", GRIS, FLECHA_DER, {}),
    ("flecha_izq", "Flecha ←", GRIS, reflejar(FLECHA_DER), {}),
    ("flecha_abajo", "Flecha ↓", GRIS, girar(FLECHA_DER), {}),
    ("flecha_arriba", "Flecha ↑", GRIS, voltear(girar(FLECHA_DER)), {}),
    ("volver", "Volver ↩", GRIS, VUELTA, {}),
    ("seguir", "Seguir ↪", GRIS, reflejar(VUELTA), {}),
    ("rebote", "Rebote ↯", GRIS, next(i[3] for i in ICONOS if i[0] == "rayo"), {}),
    ("atras", "Atrás ◀", GRIS, reflejar(TRIANGULO_DER), {}),
    ("punto", "Punto ●", GRIS, ("............", "............", "....oooo....", "...ollllo...", "..olwllllo..",
        "..olllllmo..", "..ollllmmo..", "..olllmmmo..", "...ommmmo...", "....oooo....", "............",
        "............"), {}),
    ("hueco", "Hueco ○", GRIS, ("............", "............", "....oooo....", "...ollllo...", "..ol....lo..",
        "..ol....mo..", "..ol....mo..", "..ol....mo..", "...ommmmo...", "....oooo....", "............",
        "............"), {}),
    ("rombo", "Rombo ◆", GRIS, ("............", "............", ".....oo.....", "....olwo....", "...ollllo...",
        "..ollllllo..", "..ommmmmmo..", "...ommmmo...", "....ommo....", ".....oo.....", "............",
        "............"), {}),
    ("info", "Info ⓘ", (0.4, 0.65, 1.0), espejo(("...ooo", ".oolll", ".ollll", "olllaa", "olllll", "olllaa",
        "olllaa", "olllaa", "olllaa", ".ollll", ".oolll", "...ooo")), {'a': (255, 255, 255)}),
]

# QUE EMOJI PINTA CADA DIBUJO (la fuente de iconos). Los de los estados, por su emoji del catalogo; si dos estados
# comparten emoji, aqui gana el que va primero (en el registro un 🔥 es fuego, sin mas).
EMOJI = {
    "⚔": "espadas", "☀": "luz", "💥": "golpe", "✨": "magia", "💨": "viento", "👑": "corona", "🗡": "arma",
    "💀": "muerte", "🎉": "victoria", "🏃": "huir", "✓": "ok", "✗": "no", "✕": "no", "★": "estrella",
    "⛔": "prohibido", "♥": "vida", "⌕": "lupa", "⚠": "aviso", "🔒": "candado", "🍄": "esporas", "🦔": "puas",
    "🪞": "reflejo", "🫧": "burbujas", "🐀": "rata", "🪲": "escarabajo", "🟢": "slime", "🏹": "arco",
    "🗣": "recitar", "🌈": "prisma", "💎": "gema", "🌩": "tormenta", "✱": "emboscada", "🎣": "cana", "⬆": "subir",
    "📜": "registro", "🔧": "ajustes", "▲": "arriba", "▼": "abajo", "▶": "listo", "♻": "regeneracion",
    "→": "flecha_der", "←": "flecha_izq", "↓": "flecha_abajo", "↑": "flecha_arriba", "↩": "volver", "↪": "seguir",
    "↯": "rebote", "◀": "atras", "◄": "atras", "●": "punto", "○": "hueco", "◆": "rombo", "ⓘ": "info",
    "☠": "veneno", "🩸": "sangrado", "🔥": "quemadura", "🐌": "lento", "🕸": "pegajoso", "💢": "provocado",
    "🔻": "vulnerable", "💪": "fortaleza", "💫": "aturdido", "⚡": "rayo", "✚": "regeneracion", "🔷": "regen_mana",
    "💧": "mojado", "🌀": "presteza", "🛡": "defendiendo", "🎯": "marca", "🩹": "herida_profunda", "⚗": "corrosion",
    "🤐": "silencio", "🌱": "enraizado", "🧪": "resguardo", "🌫": "ceguera", "😱": "miedo", "👤": "sigilo",
    "🫀": "guardia_carne", "🐛": "enroscado", "🍯": "resinado", "♨": "avivado", "😤": "furia_rey",
    "🖤": "savia_negra", "🦟": "picor", "💩": "pringado", "🫨": "paralisis", "🧲": "imantado", "⚙": "limaduras",
    "🪽": "en_vuelo", "💤": "una_cabeza", "❄": "congelacion", "🌑": "en_sombras", "🦷": "colmillos_rotos",
    "🔮": "foco", "⏳": "cargando", "🤺": "en_guardia", "😮": "sin_fuelle", "💚": "plato_remedio",
    "🧄": "plato_estomago", "🍀": "plato_fortuna",
}


# ------------------------------------------------------------------ LOS ICONOS DE LOS MENUS (05/11, "todo pixel"): los 76
# de scripts/ui/iconos.gd, que iban a trazos de un color. La clave es el NOMBRE DE SU FUNCION alli (Iconos.persona...):
# cada funcion pinta su dibujo si existe (assets/ui/iconos/<clave>.png) y la pantalla lo tiñe con el color que ya le
# pasaba (blanco = tal cual; gris = apagado). Por eso van en color y con contorno: el tinte solo los oscurece.
def de(clave):
    for i in ICONOS + ICONOS_UI:
        if i[0] == clave:
            return i
    raise KeyError(clave)


def como(clave_nueva, nombre, clave_vieja):
    _c, _n, color, filas, acentos = de(clave_vieja)
    return (clave_nueva, nombre, color, filas, acentos)


DIGITOS = {"1": (".x.", "xx.", ".x.", ".x.", "xxx"), "2": ("xx.", "..x", ".x.", "x..", "xxx"),
           "3": ("xx.", "..x", ".x.", "..x", "xx."), "4": ("x.x", "x.x", "xxx", "..x", "..x"),
           "5": ("xxx", "x..", "xx.", "..x", "xx.")}
ROMBO = (".....oo.....", "....ollo....", "...ollllo...", "..ollllllo..", ".ollllllllo.", "ollllllllllo",
         "ollllllllllo", ".ollllllllo.", "..ollllllo..", "...ollllo...", "....ollo....", ".....oo.....")


def tier(n):
    extra = {}
    for j, f in enumerate(DIGITOS[n]):
        for i, ch in enumerate(f):
            if ch == 'x':
                extra[(5 + i - 1, 4 + j)] = 'b'
    return pon(ROMBO, extra)


CORAZA = espejo((".oo...", "ollooo", "olllll", "olllll", ".ollll", ".ollll", ".ollll", ".ollll", ".ollll", ".ollll",
                 "..olll", "..oooo"))


def lamas(n):
    extra = {}
    for k in range(n):
        for x in range(2, 10):
            extra[(x, 4 + 2 * k)] = 'a'
    return pon(CORAZA, extra)


PIEDRA = ("............", "....oooo....", "..oollllooo.", ".olllllllllo", "ollllllllllo", "ollllllllllo",
          "ollllllllllo", "ollllllllllo", ".ommmmmmmmo.", "..oooooooo..", "............", "............")


def vetas(n):
    extra = {}
    for k in range(n):
        y = 4 + 2 * k
        for x in range(3, 9):
            extra[(x + (1 if (x + k) % 3 == 0 else 0), y)] = 'a'
    return pon(PIEDRA, extra)


ESPADA = espejo((".....o", "....ow", "....ol", "....ol", "....ol", "....ol", "....ol", "..oooo", "..oaaa", "....ob",
                 "....ob", ".....o"))
ACERO = (0.8, 0.82, 0.88)
MADERA = (0.62, 0.44, 0.28)
EMPUÑADURA = {'a': (210, 170, 70), 'b': (110, 70, 40)}
FLECHA_TIRO = (".........aaa", "..........aa", ".........b.a", "........b...", ".......b....", "......b.....",
               ".....b......", "....b.......", "...b........", "ccb.........", "c.c.........", ".cc.........")

ICONOS_MENU = [
    ("persona", "Personaje", (0.45, 0.6, 0.9), espejo(("......", "....oo", "...oaa", "..oaaa", "..oaaa", "...oaa",
        "....oo", "..oooo", ".ollll", "olllll", "olllll", "oooooo")), {'a': (240, 200, 160)}),
    ("mochila", "Mochila", (0.65, 0.45, 0.28), espejo(("......", "...ooo", "..o...", ".ooooo", "olllll", "oooooo",
        "ollllb", "olllll", "olllll", "olllll", "oddddd", "oooooo")), {'b': (230, 190, 80)}),
    como("pergamino", "Pergamino (misiones)", "registro"),
    ("libro", "Libro", (0.55, 0.35, 0.7), (
        "............", ".oooooooooo.", ".oalllllllo.", ".oallwllllo.", ".oalllllllo.", ".oallbbbllo.",
        ".oalllllllo.", ".oalllllllo.", ".oalllllllo.", ".oaccccccco.", ".oooooooooo.", "............"),
        {'a': (100, 60, 130), 'b': (230, 190, 80), 'c': (235, 225, 200)}),
    ("vela", "Vela", (0.95, 0.9, 0.75), espejo(("......", ".....a", "....ab", "....ab", ".....c", "...ooo", "...olw",
        "...oll", "...oll", "...oll", ".odddd", "..oooo")),
        {'a': (255, 150, 40), 'b': (255, 230, 120), 'c': (40, 30, 20), 'd': (180, 140, 60)}),
    como("engranaje", "Engranaje (ajustes)", "ajustes"),
    ("mano", "Mano (actuar)", (0.95, 0.78, 0.62), espejo(("...o.o", "..olol", "..olol", "..olol", ".oolll", "ololll",
        ".ollll", ".ollll", "..olll", "...oll", "...oll", "...ooo")), {}),
    ("espada", "Espada (atacar)", ACERO, ESPADA, EMPUÑADURA),
    como("pocion", "Poción (curar)", "pocion_vida"),
    ("cofre", "Cofre", MADERA, (
        "............", "............", ".oooooooooo.", "olllllllllmo", "omlllllllmmo", "oaaaabbaaaao",
        "ollllbbllllo", "olllllllllmo", "olllllllllmo", "oaaaaaaaaaao", "oooooooooooo", "............"),
        {'a': (120, 120, 130), 'b': (230, 190, 80)}),
    ("flecha_abajo", "Bajar", GRIS, girar(FLECHA_DER), {}),
    ("flecha_arriba", "Subir", GRIS, voltear(girar(FLECHA_DER)), {}),
    ("flecha_doble_arriba", "Subir del todo", GRIS, voltear(girar(CHEVRONES)), {}),
    ("moneda", "Moneda", (0.95, 0.78, 0.25), espejo(("...ooo", ".oolll", ".olwll", "olwlaa", "ollall", "ollall",
        "ollall", "ollall", "ollaaa", ".ollll", ".oolll", "...ooo")), {'a': (190, 140, 40)}),
    ("bolsa", "Bolsa", (0.62, 0.46, 0.3), espejo(("....oo", "...oaa", "....oo", "...oll", "..olll", ".ollll",
        "olllll", "ollllb", "ollllb", "olllll", ".ollll", "..oooo")), {'a': (200, 60, 50), 'b': (230, 190, 80)}),
    ("mineral", "Mineral", (0.55, 0.7, 0.85), DIAMANTE, {}),
    ("coraza", "Coraza", ACERO, CORAZA, {}),
    ("pico", "Pico", ACERO, (
        "...oooooo...", ".ooaaaaaaoo.", "oaaooooooaao", "oo..obbo..oo", "....obbo....", "....obbo....",
        "....obbo....", "....obbo....", "....obbo....", "....obbo....", "....obbo....", "....oooo...."),
        {'a': (200, 205, 215), 'b': (150, 105, 65)}),
    ("hoz", "Hoz", ACERO, (
        "....oooo....", "..ooaaaao...", ".oaaoooaao..", ".oao....oo..", "oao.........", "oao.........",
        "oaao........", ".oaaooo.....", "..ooobbo....", ".....obbo...", "......obbo..", ".......ooo.."),
        {'a': (200, 205, 215), 'b': (150, 105, 65)}),
    como("cana", "Caña", "cana"),
    ("cuchillo", "Cuchillo", ACERO, (
        "..........oo", ".........olo", "........ollo", ".......olwo.", "......olwo..", ".....olwo...",
        "....olmo....", "...oooo.....", "..obbo......", ".obbo.......", "obbo........", "oo.........."),
        {'b': (150, 105, 65)}),
    ("farol", "Farol", (0.35, 0.33, 0.3), espejo(("....oo", "...o..", "..oooo", ".oaaaa", ".oabbb", ".oabcb",
        ".oabcc", ".oabbb", ".oaaaa", "..oooo", "......", "......")),
        {'a': (90, 86, 80), 'b': (255, 220, 120), 'c': (255, 150, 40)}),
    ("correr", "Correr", (0.6, 0.9, 0.95), CHEVRONES, {}),
    ("sigilo", "Sigilo (pisada)", (0.6, 0.62, 0.7), (
        "............", "...o.o.o.o..", "..olololol..", "...o.o.o.o..", "...oooooo...", "..ollllllo..",
        "..ollllllo..", "..olllllo...", "...ollllo...", "...ollllo...", "....oooo....", "............"), {}),
    como("info", "Información", "info"),
    ("consola", "Consola", (0.62, 0.64, 0.7), (
        "............", "oooooooooooo", "oaaaaaaaaaao", "oooooooooooo", "obbbbbbbbbbo", "obgbbbbbbbbo",
        "obbgbbbbbbbo", "obgbbbbbbbbo", "obbbbbggbbbo", "obbbbbbbbbbo", "oooooooooooo", "............"),
        {'a': (150, 155, 165), 'b': (20, 24, 28), 'g': (110, 230, 110)}),
    como("equis", "Cerrar", "no"),
    ("tier_1", "Tier 1", (0.85, 0.75, 0.45), tier("1"), {'b': (40, 30, 10)}),
    ("tier_2", "Tier 2", (0.85, 0.75, 0.45), tier("2"), {'b': (40, 30, 10)}),
    ("tier_3", "Tier 3", (0.85, 0.75, 0.45), tier("3"), {'b': (40, 30, 10)}),
    ("tier_4", "Tier 4", (0.85, 0.75, 0.45), tier("4"), {'b': (40, 30, 10)}),
    ("tier_5", "Tier 5", (0.85, 0.75, 0.45), tier("5"), {'b': (40, 30, 10)}),
    ("todo", "Todo", (0.82, 0.84, 0.9), (
        "............", ".oooo..oooo.", ".ollo..ollo.", ".ollo..ollo.", ".oooo..oooo.", "............",
        "............", ".oooo..oooo.", ".ollo..ollo.", ".ollo..ollo.", ".oooo..oooo.", "............"), {}),
    ("casco", "Casco", ACERO, espejo(("......", "...ooo", ".oolll", ".olwll", "olllll", "olllll", "olbbbb", "olllll",
        "olllo.", "ollo..", "ooo...", "......")), {'b': (20, 20, 24)}),
    ("pantalon", "Pantalón", (0.45, 0.5, 0.65), espejo(("......", "oooooo", "olllll", "oaaaaa", "olllll", "olllll",
        "ollllo", "ollllo", "olllo.", "olllo.", "olllo.", "ooooo.")), {'a': (110, 80, 50)}),
    ("botas", "Botas", (0.55, 0.38, 0.24), (
        "............", "...oooo.....", "...ollo.....", "...ollo.....", "...ollo.....", "...ollo.....",
        "...olloo....", "...ollllo...", "...olllllo..", "...oooooooo.", "............", "............"), {}),
    ("daga", "Daga", ACERO, junta(daga(3, 1)), EMPUÑADURA),
    ("espada_corta", "Espada corta", ACERO, ("......", ) * 0 + espejo(("......", "......", "......", ".....o",
        "....ow", "....ol", "....ol", "..oooo", "..oaaa", "....ob", "....ob", ".....o")), EMPUÑADURA),
    ("espada_larga", "Espada larga", ACERO, ESPADA, EMPUÑADURA),
    ("mandoble", "Mandoble", ACERO, espejo(("....oo", "...owl", "...owl", "...owl", "...owl", "...owl", "...owl",
        "oooooo", "oaaaaa", "....ob", "....ob", ".....o")), EMPUÑADURA),
    ("estoque", "Estoque", ACERO, (
        "......o.....", "......l.....", "......l.....", "......l.....", "......l.....", "......l.....",
        "......l.....", "....ooloo...", "...oaaaaao..", "....oobo....", "......b.....", "......o....."), EMPUÑADURA),
    ("hacha", "Hacha", ACERO, (
        ".......oo...", "..ooo.obbo..", ".oaaaoobbo..", "oaaaaaobbo..", "oaaaaaobbo..", ".oaaaoobbo..",
        "..ooo.obbo..", "......obbo..", "......obbo..", "......obbo..", "......obbo..", "......oooo.."),
        {'a': (200, 205, 215), 'b': (150, 105, 65)}),
    ("maza", "Maza", ACERO, espejo((".....o", "..o.oo", "...ooo", "..oaaa", "ooaaaa", "..oaaa", "...ooo", "....ob",
        "....ob", "....ob", "....ob", ".....o")), {'a': (170, 175, 185), 'b': (150, 105, 65)}),
    ("martillo", "Martillo", ACERO, (
        "............", ".oooooooooo.", ".oaaaaaaaao.", ".oaaaaaaaao.", ".oooooooooo.", "....obbo....",
        "....obbo....", "....obbo....", "....obbo....", "....obbo....", "....obbo....", "....oooo...."),
        {'a': (170, 175, 185), 'b': (150, 105, 65)}),
    ("baston", "Bastón", MADERA, (
        "....ooo.....", "...occco....", "...occco....", "....ooo.....", "....obo.....", "....obo.....",
        "....obo.....", "....obo.....", "....obo.....", "....obo.....", "....obo.....", "....ooo....."),
        {'b': (150, 105, 65), 'c': (120, 220, 255)}),
    ("escudo_peq", "Escudo pequeño", (0.6, 0.75, 0.95), espejo(("......", "......", "...ooo", ".oolll", ".olwll",
        "olllla", "olllla", ".ollll", ".oolll", "...ooo", "......", "......")), ORO),
    como("escudo_med", "Escudo mediano", "baluarte"),
    ("escudo_gra", "Escudo grande", (0.6, 0.75, 0.95), espejo(("oooooo", "owllll", "olllll", "olllll", "olllll",
        "olllla", "olllla", "olllll", "olllll", "olllll", "olllll", "oooooo")), ORO),
    ("varita", "Varita", MADERA, (
        "........o...", ".......oao..", "......oaaao.", ".......oao..", "......obo...", ".....obo....",
        "....obo.....", "...obo......", "..obo.......", ".obo........", "obo.........", "oo.........."),
        {'a': (255, 240, 150), 'b': (150, 105, 65)}),
    ("habilidades", "Habilidades", (0.75, 0.6, 1.0), (
        "....llll....", "....l..l....", "....llll....", "......l.....", "....llll....", "...laaaal...",
        "...laaaal...", "....llll....", "...l....l...", ".llll..llll.", ".l..l..l..l.", ".llll..llll."),
        {'a': (255, 230, 120)}),
    ("flor", "Flor (desarrollos)", (0.95, 0.55, 0.7), espejo(("....oo", "...olw", "...oll", ".ooooo", "ollloa",
        "olllaa", "olllaa", "ollloa", ".ooooo", "...oll", "...oll", "....oo")), {'a': (255, 220, 80)}),
    ("cuero", "Cuero", (0.68, 0.48, 0.3), espejo((".oo...", "ollooo", ".ollll", "..olll", "..olll", ".ollll",
        "olllll", "olllll", ".ollll", "..olll", ".ollll", ".oo.oo")), {}),
    ("huso", "Huso", MADERA, (
        ".....oo.....", ".....ob.....", "..aaaob.....", ".a...ob.....", ".a...ob.....", "..aaaob.....",
        ".....ob.....", "..oooooooo..", ".obbbbbbbbo.", "..oooooooo..", ".....ob.....", ".....oo....."),
        {'a': (240, 236, 220), 'b': (150, 105, 65)}),
    ("rollo", "Rollo de tela", (0.75, 0.7, 0.9), (
        "............", "............", ".oooooooooo.", "oaollllllllo", "oaollllllllo", "oaollllllllo",
        "oaollllllllo", ".oooooooooo.", ".......olo..", "......ollo..", "......oo....", "............"),
        {'a': (150, 140, 180)}),
    ("correa", "Correa", MADERA, (
        "............", "............", "............", "aaaa........", "a..aoooooooo", "a.aallllllll",
        "a..aoooooooo", "aaaa........", "............", "............", "............", "............"),
        {'a': (230, 190, 80)}),
    ("hebilla", "Hebilla", (0.9, 0.75, 0.3), (
        "............", "............", "..aaaaaaaa..", "..a......a..", "..a......a..", "..aaaaaa.a..",
        "..a......a..", "..a......a..", "..aaaaaaaa..", "............", "............", "............"),
        {'a': (230, 190, 80)}),
    ("flecha_tiro", "Flecha", MADERA, FLECHA_TIRO,
        {'a': (200, 205, 215), 'b': (190, 150, 100), 'c': (220, 70, 60)}),
    ("virote", "Virote", MADERA, (
        "............", "........aaaa", ".........aaa", "........bbaa", ".......bbb.a", "......bbb...",
        ".....bbb....", "....bbb.....", "..ccbb......", "..cccb......", "...cc.......", "............"),
        {'a': (200, 205, 215), 'b': (170, 125, 80), 'c': (220, 70, 60)}),
    ("cuerda", "Cuerda", (0.8, 0.68, 0.45), (
        "............", "...llllll...", "..lmmmmmml..", ".lml....lml.", ".lm..ll..ml.", ".lm.lmml.ml.",
        ".lm.lm...ml.", ".lm..llllml.", "..lmmmmmml..", "...llllll...", ".........ll.", "..........l."), {}),
    como("vida", "Poción de vida", "pocion_vida"),
    como("mana", "Poción de maná", "pocion_mana"),
    como("antidoto", "Antídoto", "resguardo"),
    ("untura", "Untura", MADERA, pon(FLECHA_TIRO, {(11, 3): 'g', (10, 4): 'g', (11, 4): 'g', (11, 5): 'g'}),
        {'a': (200, 205, 215), 'b': (190, 150, 100), 'c': (220, 70, 60), 'g': (120, 220, 80)}),
    ("cuenco", "Cuenco", MADERA, (
        "............", "....w..w....", "...w..w.....", "............", "oooooooooooo", "oaaaaaaaaaao",
        "ollllllllllo", ".ollllllllo.", "..ollllllo..", "...oooooo...", "............", "............"),
        {'a': (230, 150, 70), 'w': (220, 225, 235)}),
    ("chapa", "Chapa", ACERO, (
        "............", "............", "............", ".....ooooooo", "....owllllmo", "...olllllmo.",
        "..olllllmo..", ".olllllmo...", "ooooooooo...", "oddddddo....", "oooooooo....", "............"), {}),
    como("deshacer", "Deshacer", "volver"),
    ("tablon", "Tablón", MADERA, (
        "............", "............", "............", "oooooooooooo", "ollllllllllo", "olaaallllllo",
        "olllllaaaalo", "olaallllllmo", "oooooooooooo", "............", "............", "............"),
        {'a': (120, 80, 45)}),
    ("carbon", "Carbón", (0.3, 0.3, 0.33), (
        ".....a......", "....aba.....", "....aba.....", ".....a......", "...oooooo...", "..oddmddoo..",
        ".odmdddmddo.", "oddddmddddo.", "odmdddddmdo.", ".oddddddoo..", "..oooooo....", "............"),
        {'a': (255, 140, 40), 'b': (255, 230, 120)}),
    ("coraza_1", "Coraza ligera", ACERO, lamas(1), {'a': (120, 125, 135)}),
    ("coraza_2", "Coraza pesada", ACERO, lamas(2), {'a': (120, 125, 135)}),
    ("coraza_3", "Placas", ACERO, lamas(3), {'a': (120, 125, 135)}),
    ("veta_1", "Veta (en bruto)", (0.55, 0.55, 0.58), vetas(1), {'a': (230, 160, 80)}),
    ("veta_2", "Veta (veteado)", (0.55, 0.55, 0.58), vetas(2), {'a': (230, 160, 80)}),
    ("veta_3", "Veta (profundo)", (0.55, 0.55, 0.58), vetas(3), {'a': (230, 160, 80)}),
    ("pelo", "Pelo", (0.95, 0.78, 0.62), espejo(("...ooo", ".ooaaa", ".oaaaa", "oaaaaa", "oaolll", "oaolll",
        "oaolll", "oaolll", "oaaoll", ".oa.ol", ".oo..o", "......")), {'a': (120, 80, 45)}),
    ("ropa", "Ropa", (0.45, 0.6, 0.85), espejo(("......", "..oo..", ".olloo", "olllll", "olllll", "ooolll",
        "..olll", "..olll", "..olll", "..olll", "..olll", "..oooo")), {}),
]


def paleta(color, acentos):
    p = tonos(color)
    p.update(acentos)
    return p


def comprobar():
    vistas = set()
    for clave, nombre, color, filas, acentos in ICONOS + ICONOS_UI:
        assert clave not in vistas, "clave repetida: " + clave
        vistas.add(clave)
    menu = set()
    for clave, nombre, color, filas, acentos in ICONOS_MENU:
        assert clave not in menu, "clave de menu repetida: " + clave
        menu.add(clave)
    for clave, nombre, color, filas, acentos in ICONOS + ICONOS_UI + ICONOS_MENU:
        pal = paleta(color, acentos)
        assert len(filas) == N, "%s: %d filas" % (nombre, len(filas))
        for j, f in enumerate(filas):
            assert len(f) == N, "%s fila %d mide %d: '%s'" % (nombre, j, len(f), f)
            for ch in f:
                assert ch == '.' or ch in pal, "%s fila %d: '%s' sin color" % (nombre, j, ch)
    for e, clave in EMOJI.items():
        assert clave in vistas, "el emoji %s apunta a '%s', que no esta dibujado" % (e, clave)


def icono(filas, pal):
    im = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    for j, f in enumerate(filas):
        for i, ch in enumerate(f):
            if ch != '.':
                im.putpixel((i, j), tuple(pal[ch]) + (255,))
    return im


def chip(ic, color, escala):
    # El chip de verdad (StatusChip): fondo del color al 30 % y borde, con el icono dentro.
    w, h = (N + 10) * escala, (N + 4) * escala
    im = Image.new('RGBA', (w, h), (22, 24, 30, 255))
    d = ImageDraw.Draw(im)
    c = tuple(int(v * 255) for v in color)
    fondo = tuple(int(v * 0.55 * 0.30 + 22 * 0.70) for v in c)
    d.rounded_rectangle([0, 0, w - 1, h - 1], radius=3 * escala, fill=fondo,
                        outline=tuple(int(v * 0.55 + 22 * 0.45) for v in c), width=escala)
    im.alpha_composite(ic.resize((N * escala, N * escala), Image.NEAREST), (5 * escala, 2 * escala))
    return im


def lamina(lista, archivo):
    comprobar()
    por_fila, col, alto = 11, 128, 196
    filas_lam = (len(lista) + por_fila - 1) // por_fila
    lam = Image.new('RGB', (20 + col * por_fila, 20 + alto * filas_lam), (40, 42, 50))
    d = ImageDraw.Draw(lam)
    try:
        fuente = ImageFont.truetype("arial.ttf", 12)
    except OSError:
        fuente = None
    for k, (clave, nombre, color, filas, acentos) in enumerate(lista):
        x = 20 + (k % por_fila) * col
        y = 14 + (k // por_fila) * alto
        ic = icono(filas, paleta(color, acentos))
        g = ic.resize((N * 8, N * 8), Image.NEAREST)
        lam.paste(g, (x, y), g)
        lam.paste(chip(ic, color, 1), (x, y + 108))
        lam.paste(chip(ic, color, 2), (x + 30, y + 104))
        d.text((x, y + 146), nombre, fill=(225, 225, 225), font=fuente)
    carpeta = os.path.join(os.path.expanduser('~'), 'Desktop', 'iconos_estados')
    os.makedirs(carpeta, exist_ok=True)
    ruta = os.path.join(carpeta, archivo)
    lam.save(ruta)
    return ruta


def hornear():
    comprobar()
    carpeta = os.path.join(RAIZ, 'assets', 'ui', 'estados')
    os.makedirs(carpeta, exist_ok=True)
    for clave, _n, color, filas, acentos in ICONOS + ICONOS_UI:
        icono(filas, paleta(color, acentos)).save(os.path.join(carpeta, clave + '.png'))
    menus = os.path.join(RAIZ, 'assets', 'ui', 'iconos')
    os.makedirs(menus, exist_ok=True)
    for clave, _n, color, filas, acentos in ICONOS_MENU:
        icono(filas, paleta(color, acentos)).save(os.path.join(menus, clave + '.png'))
    # La tabla para el juego: que dibujo pinta cada emoji (scripts/ui/fuente_iconos.gd la lee).
    lineas = ["# GENERADO por tools/iconos_estados_pixel.py --hornear: no tocar a mano.",
              "# Que dibujo de assets/ui/estados pinta cada emoji en la FUENTE DE ICONOS.",
              "const TABLA := {"]
    for e, clave in EMOJI.items():
        lineas.append('\t"%s": "%s",' % (e, clave))
    lineas.append("}")
    with open(os.path.join(RAIZ, 'scripts', 'ui', 'fuente_iconos_tabla.gd'), 'w', encoding='utf-8', newline='\n') as f:
        f.write("\n".join(lineas) + "\n")
    return carpeta


if __name__ == '__main__':
    if '--hornear' in sys.argv:
        print(hornear())
    else:
        if '--menus' in sys.argv:
            r = lamina(ICONOS_MENU, 'lamina_menus.png')
        else:
            r = lamina(ICONOS_UI, 'lamina_interfaz.png') if '--ui' in sys.argv else lamina(ICONOS, 'lamina.png')
        print(r)
        if '--abrir' in sys.argv:
            subprocess.Popen(['mspaint', r])
