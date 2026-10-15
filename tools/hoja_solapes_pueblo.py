#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
hoja_solapes_pueblo.py -- junta los recortes de tools/ver_solapes_pueblo.tscn en hojas con rotulos:
una fila por adorno y una columna por caso (por detras, por delante, de lado, uno detras y otro delante).
Saca tools/salida/solapes_pueblo_N.png (varias hojas para que se lean sin hacer zoom).

  python tools/hoja_solapes_pueblo.py
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

RAIZ = Path(__file__).resolve().parent.parent
DIR = RAIZ / "tools" / "salida" / "solapes"
CELDA = (340, 300)
ROTULO_IZQ = 170
CABECERA = 34
FILAS_POR_HOJA = 6


def fuente(t):
    for f in ("C:/Windows/Fonts/arialbd.ttf", "C:/Windows/Fonts/arial.ttf"):
        try:
            return ImageFont.truetype(f, t)
        except OSError:
            pass
    return ImageFont.load_default()


def main():
    filas = {}
    casos = []
    for linea in (DIR / "indice.txt").read_text(encoding="utf-8").splitlines():
        rotulo, caso, archivo = linea.split("\t")
        filas.setdefault(rotulo, {})[caso] = archivo
        if caso not in casos:
            casos.append(caso)
    nombres = list(filas)
    f_cab, f_fila, f_nada = fuente(17), fuente(16), fuente(14)
    for h in range(0, len(nombres), FILAS_POR_HOJA):
        trozo = nombres[h:h + FILAS_POR_HOJA]
        ancho = ROTULO_IZQ + CELDA[0] * len(casos)
        alto = CABECERA + CELDA[1] * len(trozo)
        hoja = Image.new("RGB", (ancho, alto), (28, 28, 34))
        d = ImageDraw.Draw(hoja)
        for k, caso in enumerate(casos):
            d.text((ROTULO_IZQ + k * CELDA[0] + 8, 8), caso, fill=(240, 220, 150), font=f_cab)
        for i, nombre in enumerate(trozo):
            y0 = CABECERA + i * CELDA[1]
            d.line([(0, y0), (ancho, y0)], fill=(70, 70, 80))
            d.text((8, y0 + 8), nombre, fill=(230, 230, 230), font=f_fila)
            for k, caso in enumerate(casos):
                x0 = ROTULO_IZQ + k * CELDA[0]
                archivo = filas[nombre].get(caso, "-")
                if archivo == "-":
                    d.text((x0 + 12, y0 + CELDA[1] // 2 - 8), "no se puede llegar", fill=(140, 140, 140), font=f_nada)
                    continue
                im = Image.open(DIR / archivo).convert("RGB")
                esc = min((CELDA[0] - 8) / im.width, (CELDA[1] - 8) / im.height)
                im = im.resize((max(1, int(im.width * esc)), max(1, int(im.height * esc))), Image.NEAREST)
                hoja.paste(im, (x0 + (CELDA[0] - im.width) // 2, y0 + (CELDA[1] - im.height) // 2))
        salida = RAIZ / "tools" / "salida" / ("solapes_pueblo_%d.png" % (h // FILAS_POR_HOJA + 1))
        hoja.save(salida)
        print(salida)


if __name__ == "__main__":
    main()
