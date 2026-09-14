"""Imprime la MARCA (primera linea del bloque de comentario pegado encima, o la propia 'func') de cada
funcion pedida. Sirve para dar marcas exactas a trocear_pantalla.py / trocear_net.py.
uso: python tools/marca_de.py scripts/ui/combat.gd func1 func2 ..."""
import os, re, sys

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L = open(os.path.join(RAIZ, sys.argv[1]), encoding="utf-8").read().split("\n")
for nombre in sys.argv[2:]:
    i = next((k for k, l in enumerate(L) if re.match(r"^(?:static\s+)?func\s+" + re.escape(nombre) + r"\(", l)), None)
    if i is None:
        print("%s: NO ESTA" % nombre)
        continue
    a = i
    while a - 1 >= 0 and (L[a - 1].startswith("#") or L[a - 1].startswith("@")) and not L[a - 1].startswith("# ==="):
        a -= 1
    print("%s: %s" % (nombre, L[a][:70]))
