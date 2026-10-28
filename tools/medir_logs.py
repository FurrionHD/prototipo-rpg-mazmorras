#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
medir_logs.py -- junta las marcas [medir] de varios logs (sala, jugadores) en UNA linea de tiempo.

  python tools/medir_logs.py                       # los logs de %APPDATA%/DungeonOratoria/logs
  python tools/medir_logs.py a.log b.log           # esos logs
  python tools/medir_logs.py --tramo pelea         # solo un tramo
  python tools/medir_logs.py --resumen             # por tramo: cuantas veces, media, peor (de su columna +ms)

Las marcas las escribe scripts/core/medidor.gd:  [medir] <tramo> <paso> t=<ms del sistema> +<ms desde empezar>
En el MISMO PC el reloj es el mismo para todos los procesos, asi que la columna t se puede ordenar entre logs
y sale cuanto tarda cada salto (sala -> cliente). Entre dos PCs, solo valen las restas +ms.
"""
import argparse
import os
import re
import statistics
import sys
from collections import defaultdict
from pathlib import Path

R = re.compile(r"\[medir\] (\S+) (\S+) t=(\d+) (?:\+(\d+)|\(sin empezar\))")


def logs_por_defecto():
    d = Path(os.environ.get("APPDATA", "")) / "DungeonOratoria" / "logs"
    return sorted(d.glob("*.log")) if d.exists() else []


def leer(rutas):
    marcas = []
    for r in rutas:
        p = Path(r)
        for linea in p.read_text(encoding="utf-8", errors="replace").splitlines():
            m = R.search(linea)
            if m:
                marcas.append({"log": p.name, "tramo": m.group(1), "paso": m.group(2), "t": int(m.group(3)),
                               "desde": int(m.group(4)) if m.group(4) else None})
    marcas.sort(key=lambda x: x["t"])
    return marcas


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("logs", nargs="*")
    ap.add_argument("--tramo")
    ap.add_argument("--resumen", action="store_true")
    a = ap.parse_args()
    marcas = leer(a.logs or logs_por_defecto())
    if a.tramo:
        marcas = [m for m in marcas if m["tramo"] == a.tramo]
    if not marcas:
        print("No hay marcas [medir] en esos logs.")
        return 1
    if a.resumen:
        totales = defaultdict(list)
        for m in marcas:
            if m["paso"] in ("fin", "pantalla") and m["desde"] is not None:
                totales[m["tramo"]].append(m["desde"])
        for tramo, xs in sorted(totales.items()):
            print("%-20s %3d veces  media %6.0f ms  peor %6.0f ms" % (tramo, len(xs), statistics.mean(xs), max(xs)))
        return 0
    t0 = marcas[0]["t"]
    previo = t0
    for m in marcas:
        print("%8d ms  (+%5d)  %-22s %-16s %-24s %s" % (m["t"] - t0, m["t"] - previo, m["log"][:22], m["tramo"],
                                                    m["paso"], "" if m["desde"] is None else "+%d" % m["desde"]))
        previo = m["t"]
    return 0


if __name__ == "__main__":
    sys.exit(main())
