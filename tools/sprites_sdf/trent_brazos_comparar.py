#!/usr/bin/env python3
# LOS BRAZOS NUEVOS DE LOS TRENT MUTANTES (04/11), ANTES Y DESPUES: por cada pose, arriba la hoja que hay en el juego y abajo
# el dibujo nuevo, en dos direcciones. Para que el jefe los vea antes de hornear las hojas enteras.
#   TRENT_VAR=ambarino|espantajo python tools/sprites_sdf/trent_brazos_comparar.py
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
import trent_mutantes_sdf as tm
from sdf_comun import render

POSES = [('quieto', 'idle', 0.0), ('golpe: coge impulso', 'embestida', 0.35), ('golpe: descarga', 'embestida', 0.55),
         ('basico: abajo', 'basico', 0.35), ('basico: tira arriba', 'basico', 0.55), ('raices', 'raices', 1.0),
         ('andando', 'walk', 0.25), ('andando (otro paso)', 'walk', 0.75)]
DIRS = (1, 2)


def viejo(anim, t, d):
    ruta = os.path.join(tm.SALIDA, anim + '.png')
    hoja = Image.open(ruta).convert('RGBA')
    W, H = tm.LIENZO
    n = hoja.size[0] // W
    f = min(n - 1, int(round(t * n)))
    return hoja.crop((f * W, d * H, f * W + W, d * H + H))


def main():
    W, H = tm.LIENZO
    z = 2
    filas = len(DIRS) * 2
    img = Image.new('RGB', (len(POSES) * W * z, filas * H * z + 30), (40, 37, 42))
    pinta = ImageDraw.Draw(img)
    for i, (nombre, anim, t) in enumerate(POSES):
        pose = tm.ANIMS[anim][4](t)
        pinta.text((i * W * z + 6, 8), nombre, fill=(230, 226, 214))
        for j, d in enumerate(DIRS):
            for k, foto in enumerate((viejo(anim, t, d), render(tm.MODELO, tm.escena(pose), d))):
                fondo = Image.new('RGBA', (W, H), (52, 48, 56, 255) if k == 0 else (44, 54, 50, 255))
                fondo.alpha_composite(foto.convert('RGBA'))
                img.paste(fondo.resize((W * z, H * z), Image.NEAREST), (i * W * z, 30 + (j * 2 + k) * H * z))
    for j in range(len(DIRS)):
        pinta.text((4, 34 + j * 2 * H * z), 'ANTES', fill=(240, 180, 160))
        pinta.text((4, 34 + (j * 2 + 1) * H * z), 'AHORA', fill=(170, 240, 190))
    sal = os.path.join(os.path.expanduser('~'), 'Desktop', 'ataques_mapa', 'enemigos', 'prueba_3d', 'mutantes')
    os.makedirs(sal, exist_ok=True)
    ruta = os.path.join(sal, 'trent_brazos_%s.png' % tm.VAR)
    img.save(ruta)
    print(ruta)


if __name__ == '__main__':
    main()
