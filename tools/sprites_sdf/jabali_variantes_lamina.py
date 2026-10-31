# LAS VARIANTES DE LOS MUTANTES DEL JABALI, juntas (31/10): el Colmillo de cristal y el Jabali ancestral, enteros, con
# los colmillos ROTOS y (el ancestral) PELADO, en reposo mirando a las 5 direcciones (la primera columna de su hoja idle);
# y debajo sus dos EVOLUCIONES mirando al SE. Sale de las vistas de jabali_sdf.py (hay que hornearlas antes).
#   python tools/sprites_sdf/jabali_variantes_lamina.py -> Desktop/.../mutantes/jabali_variantes.png
import os
from PIL import Image, ImageDraw

BASE = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
VARS = [('colmillo', 'Colmillo de cristal'), ('colmillo_rotos', '... colmillos rotos'),
        ('ancestral', 'Jabali ancestral'), ('ancestral_rotos', '... colmillos rotos'),
        ('ancestral_pelado', '... pelado (fuego)'), ('ancestral_pelado_rotos', '... pelado y rotos')]


def vista(suf, anim):
    return Image.open(os.path.join(BASE, 'jabali_%s_hojas' % suf, 'jabali_sdf_%s.png' % anim))


filas = []
for suf, nombre in VARS:
    v = vista(suf, 'idle')
    n = 8
    w = v.width // n
    h = v.height // 5
    fotos = [v.crop((0, d * h, w, (d + 1) * h)) for d in range(5)]
    filas.append((nombre, fotos))
evos = []
for suf, nombre in (('colmillo', 'evolucion: jabali -> colmillo'), ('ancestral', 'evolucion: colmillo -> ancestral')):
    v = vista(suf, 'evolucion')
    w = v.width // 18
    h = v.height // 5
    evos.append((nombre, [v.crop((i * w, h, (i + 1) * w, 2 * h)) for i in range(0, 18, 2)]))
ETQ = 220
W = max(ETQ + sum(f.width for f in fotos) for _, fotos in filas + evos)
H = sum(f[1][0].height for f in filas + evos)
lam = Image.new('RGB', (W, H), (40, 42, 50))
d = ImageDraw.Draw(lam)
y = 0
for nombre, fotos in filas + evos:
    d.text((6, y + fotos[0].height // 2 - 6), nombre, fill=(225, 225, 225))
    x = ETQ
    for f in fotos:
        lam.paste(f, (x, y))
        x += f.width
    y += fotos[0].height
ruta = os.path.join(BASE, 'jabali_variantes.png')
lam.save(ruta)
print(ruta, lam.size)
