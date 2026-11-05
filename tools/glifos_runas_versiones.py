# ============================================================
#  glifos_runas_versiones.py -- LOS GLIFOS DEL SELLO DE RUNAS de la rata y del Rey Rata, propuestas (31/10/2026). Cada set
#  lleva un simbolo de 7 x 7 en el sello de la celda (CeldaObjeto.GLIFO_SET), en claro sobre el disco del color de su
#  runa; a la rata (Alcantarilla) y al Rey Rata (Sangre real) les faltaba y salian con la gota del slime.
#  Pinta cada version en su sello a dos tamaños (el de la celda grande y el de la pequeña) junto a los que ya hay.
#  Uso: python tools/glifos_runas_versiones.py -> Desktop/taller_runas/glifos_versiones.png
# ============================================================
import os
from PIL import Image, ImageDraw

YA = {   # los de ahora, para comparar
    'slime (gota)': ("...#...", "..###..", ".#####.", ".#####.", "#######", ".#####.", "..###.."),
    'rey slime (corona)': ("#..#..#", "#.###.#", "#######", "#######", ".#####.", ".......", "......."),
}
RATA = {   # Alcantarilla: morado de la Runa de rata
    'A cabeza de rata': ("##...##", "##...##", ".#####.", "#.###.#", ".#####.", "..###..", "...#..."),
    'B rejilla de cloaca': (".#####.", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.#.#.#", ".#####."),
    'C rata de perfil': ("..##...", ".####..", "######.", "#######", ".######", "..#..##", "......#"),
}
REY = {   # Sangre real: rojo de la Runa de rey rata
    'A corona de colmillos': ("#.#.#.#", "#######", "#######", ".#.#.#.", ".#...#.", ".....#.", "......."),
    'B gota bajo corona': ("#.#.#..", "#####..", "...#...", "..###..", ".#####.", ".#####.", "..###.."),
    'C colmillo que gotea': ("#####..", ".####..", ".###...", "..##...", "..#..#.", "......#", ".....#."),
}
JABALI = {   # Musgo viejo (31/10): verde de la Runa de jabali
    'A seta': (".#####.", "#######", "#######", "...#...", "...#...", "..###..", "......."),
    'B helecho': ("...#...", ".#.#.#.", "..###..", "#.###.#", ".#####.", "...#...", "...#..."),
    'C colmillo': ("#......", "#......", "##.....", ".##....", "..###..", "...####", "....##."),
}
ARANA = {   # Hilo conductor (03/11): azul de la Runa de araña
    'A hilo con chispazo': ("...#...", "...#...", "..##...", "..###..", "...##..", "...#...", "...#..."),
    'B globo de hilos': ("..###..", ".#.#.#.", "#.#.#.#", "#.#.#.#", "#.#.#.#", ".#.#.#.", "..###.."),
    'C tela de araña': ("#..#..#", ".#.#.#.", "..###..", "###.###", "..###..", ".#.#.#.", "#..#..#"),
    'D rayo': ("....##.", "...##..", "..####.", "...#...", ".####..", "..##...", ".##...."),
}
CIEMPIES = {   # Dos mentes (05/11): naranja de la Runa de ciempies
    'A dos cabezas en U': ("#.#.#.#", ".#...#.", "##...##", "##...##", "##...##", ".##.##.", "..###.."),
    'B ciempies en S': ("##.....", "###....", ".##....", "..###..", "....##.", "....###", ".....##"),
    'C dos ojos': (".......", ".##.##.", "#.##.##", "#.##.##", ".##.##.", ".......", "......."),
    'D anillos enroscados': ("#######", "#.....#", "#.###.#", "#.#.#.#", "#.#...#", "#.#####", "#......"),
}
COL = {'ciempies': (0.86, 0.38, 0.1), 'arana': (0.2, 0.5, 0.62), 'ya': (0.36, 0.7, 0.42), 'rata': (0.55, 0.45, 0.6), 'rey': (0.62, 0.22, 0.2), 'jabali': (0.32, 0.5, 0.22)}


def sello(glifo, col, r):
    lado = int(r * 2 + 8)
    im = Image.new('RGB', (lado, lado), (13, 15, 20))
    d = ImageDraw.Draw(im)
    c = lado / 2
    osc = tuple(int(v * 255 * 0.65) for v in col)
    cla = tuple(int(min(1.0, v + (1 - v) * 0.45) * 255) for v in col)
    d.ellipse([c - r + 2, c - r + 2, c + r + 2, c + r + 2], fill=(0, 0, 0))
    d.ellipse([c - r, c - r, c + r, c + r], fill=osc, outline=cla, width=max(2, int(r * 0.17)))
    lg = r * 1.25
    px = lg / 7.0
    x0 = c - lg / 2
    y0 = c - lg / 2
    for j, f in enumerate(glifo):
        for i, ch in enumerate(f):
            if ch == '#':
                d.rectangle([x0 + i * px, y0 + j * px, x0 + (i + 1) * px - 1, y0 + (j + 1) * px - 1], fill=(244, 244, 244))
    return im


filas = [('ahora', YA, COL['ya']), ('RATA (Alcantarilla)', RATA, COL['rata']), ('REY RATA (Sangre real)', REY, COL['rey']),
         ('JABALI (Musgo viejo)', JABALI, COL['jabali']), ('ARAÑA (Hilo conductor)', ARANA, COL['arana']),
         ('CIEMPIES (Dos mentes)', CIEMPIES, COL['ciempies'])]
W, H = 1240, 120 * len(filas) + 20
lam = Image.new('RGB', (W, H), (40, 42, 50))
d = ImageDraw.Draw(lam)
for k, (titulo, tabla, col) in enumerate(filas):
    y = 10 + k * 120
    d.text((10, y + 50), titulo, fill=(220, 220, 220))
    for i, (nombre, g) in enumerate(tabla.items()):
        x = 180 + i * 260
        grande = sello(g, col, 40).resize((88 * 1, 88 * 1), Image.NEAREST)
        peque = sello(g, col, 14)
        lam.paste(grande, (x, y))
        lam.paste(peque.resize((peque.width * 2, peque.height * 2), Image.NEAREST), (x + 100, y + 20))
        d.text((x, y + 92), nombre, fill=(220, 220, 220))
salida = os.path.join(os.path.expanduser('~'), 'Desktop', 'taller_runas')
os.makedirs(salida, exist_ok=True)
ruta = os.path.join(salida, 'glifos_versiones.png')
lam.save(ruta)
print(ruta)
