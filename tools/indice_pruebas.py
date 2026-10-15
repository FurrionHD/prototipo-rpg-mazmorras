#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
indice_pruebas.py -- escribe tools/INDICE_PRUEBAS.md: para cada script de scripts/, que pruebas lo NOMBRAN
(por su class_name, por su ruta o por su autoload) y cuales no tiene ninguna (los huecos).

  python tools/indice_pruebas.py          # rehace el indice
  python tools/indice_pruebas.py --huecos # solo dice cuantos scripts no tiene ninguna prueba, por carpeta

Ojo: "lo nombra" no es "lo cubre entero". Una prueba que llama a Game.peso_actual() nombra game.gd y no
prueba sus 16.000 lineas. Sirve para ver los HUECOS (lo que ninguna prueba toca ni de lejos) y para saber
que pruebas pasar despues de tocar un archivo. Parte del protocolo de docs/ORGANIZACION.md.
"""
import re
import sys
from pathlib import Path
from collections import defaultdict

RAIZ = Path(__file__).resolve().parent.parent
TOOLS = RAIZ / "tools"
SALIDA = TOOLS / "INDICE_PRUEBAS.md"


def autoloads() -> dict:
    """ruta res:// -> nombre del autoload."""
    out = {}
    t = (RAIZ / "project.godot").read_text(encoding="utf-8")
    m = re.search(r"\[autoload\]\n(.*?)\n\[", t, re.S)
    if m:
        for linea in m.group(1).splitlines():
            mm = re.match(r'(\w+)="\*?(res://[^"]+)"', linea.strip())
            if mm:
                out[mm.group(2)] = mm.group(1)
    return out


def main() -> int:
    al = autoloads()
    scripts = sorted(p for p in (RAIZ / "scripts").rglob("*.gd"))
    pruebas = sorted(TOOLS.glob("prueba_*.gd")) + sorted((TOOLS / "unitarias").glob("test_*.gd"))
    textos = {p: p.read_text(encoding="utf-8", errors="replace") for p in pruebas}

    nombra = defaultdict(list)   # script -> [prueba]
    for s in scripts:
        rel = s.relative_to(RAIZ).as_posix()
        res = "res://" + rel
        claves = [re.escape(res), re.escape(s.name)]
        cn = re.search(r"^class_name\s+(\w+)", s.read_text(encoding="utf-8", errors="replace"), re.M)
        if cn:
            claves.append(r"\b%s\b" % cn.group(1))
        if res in al:
            claves.append(r"\b%s\." % al[res])
        # Los temas de Net cuelgan del autoload con nombre fijo: net_peleas.gd = Net.peleas
        mt = re.match(r"scripts/net/net_(\w+)\.gd$", rel)
        if mt:
            claves.append(r"\bNet\.%s\b" % mt.group(1))
        r = re.compile("|".join(claves))
        for p, t in textos.items():
            if r.search(t):
                nombra[s].append(p.relative_to(TOOLS).as_posix())

    por_carpeta = defaultdict(lambda: [0, 0])
    for s in scripts:
        c = s.parent.relative_to(RAIZ).as_posix()
        por_carpeta[c][0] += 1
        if not nombra[s]:
            por_carpeta[c][1] += 1

    huecos = [s for s in scripts if not nombra[s]]
    if "--huecos" in sys.argv:
        for c, (n, h) in sorted(por_carpeta.items()):
            print("%-28s %3d scripts, %3d sin prueba" % (c, n, h))
        print("TOTAL: %d de %d scripts sin ninguna prueba" % (len(huecos), len(scripts)))
        return 0

    lineas = [
        "# Índice: qué prueba nombra cada script",
        "",
        "Generado por `python tools/indice_pruebas.py` (no editar a mano: se rehace). \"Lo nombra\" no es \"lo cubre",
        "entero\": sirve para ver los **huecos** y para saber qué pruebas pasar después de tocar un archivo.",
        "",
        "**%d de %d scripts no tienen ninguna prueba que los nombre.**" % (len(huecos), len(scripts)),
        "",
        "| Carpeta | Scripts | Sin prueba |",
        "|---|---|---|",
    ]
    for c, (n, h) in sorted(por_carpeta.items()):
        lineas.append("| `%s` | %d | %d |" % (c, n, h))
    lineas += ["", "## Huecos (ninguna prueba los nombra)", ""]
    for s in huecos:
        lineas.append("- `%s`" % s.relative_to(RAIZ).as_posix())
    lineas += ["", "## Con prueba", ""]
    for s in scripts:
        if nombra[s]:
            ps = nombra[s]
            muestra = ", ".join("`%s`" % p for p in ps[:6]) + (" y %d más" % (len(ps) - 6) if len(ps) > 6 else "")
            lineas.append("- `%s`: %s" % (s.relative_to(RAIZ).as_posix(), muestra))
    SALIDA.write_text("\n".join(lineas) + "\n", encoding="utf-8", newline="\n")   # LF como el resto del repo
    print("Escrito %s: %d scripts, %d sin prueba" % (SALIDA.relative_to(RAIZ), len(scripts), len(huecos)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
