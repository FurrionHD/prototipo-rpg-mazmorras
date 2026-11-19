#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
simulador.py -- EL SIMULADOR DE PELEAS a lo grande (19/11/2026, memoria stats-misma-formula-todos).

Reparte los casos de tools/simulador_peleas.tscn entre VARIOS Godot a la vez (cada uno su trozo, su sala y su puerto),
junta lo que sale en un CSV y saca el resumen. Las peleas son DE VERDAD: la pantalla de combate en el mapa de la arena de
pruebas, con un piloto automatico que juega como un jugador (ver la cabecera de simulador_peleas.gd).

  python tools/simulador.py                          # todo: pisos de referencia, guerrero y mago, 3 veces cada caso
  python tools/simulador.py --veces 10 --hilos 4     # mas peleas por caso, 4 Godot a la vez
  python tools/simulador.py --pisos 1,6 --clases mago --solo jabali
  python tools/simulador.py --arma dagas --clases guerrero --tanda dagas   # comparar armas
  python tools/simulador.py --resumen tools/resultados_simulador/hoy.csv   # solo rehacer el resumen de un CSV

Cada Godot ocupa ~300-400 MB: con poca RAM libre, menos --hilos ([[cuidado-con-la-ram]]). Por defecto la mitad de los
nucleos menos uno, con tope 4.
Salida: tools/resultados_simulador/<tanda>.csv (+ <tanda>_<i>.txt, la salida cruda de cada Godot).
"""
import argparse
import csv
import os
import subprocess
import sys
import time
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
SALIDA = RAIZ / "tools" / "resultados_simulador"
GODOT = Path(os.environ.get("LOCALAPPDATA", "")) / ("Microsoft/WinGet/Packages/"
    "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe")


def lanzar(a) -> Path:
    SALIDA.mkdir(parents=True, exist_ok=True)
    extra = ["veces=%d" % a.veces, "tanda=%s" % a.tanda, "reglas=%s" % a.reglas, "escala=%s" % a.escala]
    for k in ("pisos", "clases", "solo", "arma"):
        v = getattr(a, k)
        if v:
            extra.append("%s=%s" % (k, v))
    if a.sin_mutantes:
        extra.append("sin_mutantes=1")
    if a.sin_jefes:
        extra.append("sin_jefes=1")
    procs = []
    t0 = time.time()
    for i in range(a.hilos):
        crudo = SALIDA / ("%s_%d.txt" % (a.tanda, i))
        f = open(crudo, "w", encoding="utf-8")
        cmd = [str(GODOT), "--headless", "--fixed-fps", "60", "--path", str(RAIZ), "res://tools/simulador_peleas.tscn",
               "--", "trozo=%d/%d" % (i, a.hilos)] + extra
        procs.append((subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=str(RAIZ)), f, crudo))
    print("[simulador] %d Godot en marcha (%s)" % (a.hilos, " ".join(extra)))
    hechas_antes = -1
    while any(p.poll() is None for p, _, _ in procs):
        time.sleep(5)
        if time.time() - t0 > a.tope:
            print("[simulador] TOPE de %d s: los paro" % a.tope)
            for p, _, _ in procs:
                p.kill()
            break
        hechas = sum(_contar(c) for _, _, c in procs)
        if hechas != hechas_antes and int(time.time() - t0) % 30 < 5:
            print("[simulador] %4d peleas  (%.0f s)" % (hechas, time.time() - t0))
            hechas_antes = hechas
    for p, f, _ in procs:
        p.wait()
        f.close()
    # juntar
    filas = []
    cab = None
    for _, _, crudo in procs:
        for l in crudo.read_text(encoding="utf-8", errors="replace").splitlines():
            if not l.startswith("R|"):
                continue
            partes = l.split("|")[1:]
            if partes[0] == "tanda":
                cab = partes
                continue
            filas.append(partes)
    destino = SALIDA / ("%s.csv" % a.tanda)
    with open(destino, "w", encoding="utf-8", newline="") as f:
        w = csv.writer(f, delimiter=";")
        if cab:
            w.writerow(cab)
        w.writerows(filas)
    dur = time.time() - t0
    print("[simulador] %d peleas en %.0f s (%.1f por minuto) -> %s" % (len(filas), dur, len(filas) * 60.0 / max(dur, 1), destino))
    return destino


def _contar(crudo: Path) -> int:
    try:
        return sum(1 for l in crudo.read_text(encoding="utf-8", errors="replace").splitlines() if l.startswith("R|") and "|tanda|" not in l)
    except OSError:
        return 0


def _f(x):
    try:
        return float(x)
    except ValueError:
        return 0.0


# EL RESUMEN. Por piso y clase, y luego por enemigo: % de victorias, tus turnos para tumbarle (en las que ganas), los
# suyos para tumbarte (los que ha tenido / la vida que te ha quitado, extrapolado), la vida que pierdes, y las raras.
def resumen(ruta: Path, detalle: bool = True) -> None:
    with open(ruta, encoding="utf-8") as f:
        filas = list(csv.DictReader(f, delimiter=";"))
    if not filas:
        print("(sin peleas)")
        return
    def bloque(clave):
        g = defaultdict(list)
        for r in filas:
            g[clave(r)].append(r)
        return g
    def linea(rs):
        n = len(rs)
        gana = [r for r in rs if r["gana"] == "GANA"]
        raras = sum(1 for r in rs if r["gana"] in ("ATASCADA", "TABLAS", "CERRADA") or r["gana"].startswith("ERROR"))
        t_yo = sum(_f(r["turnos_yo"]) for r in gana) / len(gana) if gana else float("nan")
        # sus turnos para tumbarte: lo que tardaria a ese ritmo (turnos suyos / fraccion de vida quitada)
        suyos = [(_f(r["turnos_el"]) / _f(r["vida_perdida"])) for r in rs if _f(r["vida_perdida"]) > 0.01]
        t_el = sorted(suyos)[len(suyos) // 2] if suyos else float("inf")
        vida = sum(_f(r["vida_perdida"]) for r in rs) / n
        return "%4d  %5.0f%%  %6.1f  %7.1f  %6.0f%%  %s" % (n, 100.0 * len(gana) / n, t_yo, t_el, 100.0 * vida,
            ("%d raras" % raras) if raras else "")
    print()
    print("POR PISO Y CLASE (normal / mutantes / jefe)")
    print("%-28s %4s  %6s  %6s  %7s  %7s" % ("", "n", "gana", "tus_t", "sus_t", "vida-"))
    for (piso, clase, tipo), rs in sorted(bloque(lambda r: (int(r["piso"]), r["clase"],
            "jefe" if r["jefe"] == "1" else ("mutante" if r["mutacion"] != "-" else "normal"))).items()):
        print("%-28s %s" % ("piso %2d %-8s %-8s" % (piso, clase, tipo), linea(rs)))
    if not detalle:
        return
    print()
    print("POR ENEMIGO")
    print("%-52s %4s  %6s  %6s  %7s  %7s" % ("", "n", "gana", "tus_t", "sus_t", "vida-"))
    for (piso, clase, en, mut), rs in sorted(bloque(lambda r: (int(r["piso"]), r["clase"], r["enemigo"], r["mutacion"])).items()):
        print("%-52s %s" % ("piso %2d %-8s %-24s %s" % (piso, clase, en[:24], "" if mut == "-" else mut[:12]), linea(rs)))
    print()
    print("tus_t = tus turnos para tumbarle (media de las que ganas); sus_t = sus turnos para tumbarte (mediana, al ritmo"
          " al que te quita vida); vida- = vida perdida media; raras = atascadas/tablas/errores")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--hilos", type=int, default=max(1, min(4, (os.cpu_count() or 4) // 2 - 1)))
    ap.add_argument("--veces", type=int, default=3)
    ap.add_argument("--pisos", default="")
    ap.add_argument("--clases", default="")
    ap.add_argument("--solo", default="")
    ap.add_argument("--arma", default="")
    ap.add_argument("--tanda", default="hoy")
    ap.add_argument("--reglas", default="hoy")
    ap.add_argument("--escala", default="8")
    ap.add_argument("--tope", type=int, default=3 * 3600)
    ap.add_argument("--sin-mutantes", action="store_true")
    ap.add_argument("--sin-jefes", action="store_true")
    ap.add_argument("--resumen", default="")
    ap.add_argument("--corto", action="store_true", help="solo el resumen por piso y clase")
    a = ap.parse_args()
    if a.resumen:
        resumen(Path(a.resumen), not a.corto)
        return
    if not GODOT.exists():
        sys.exit("No encuentro Godot en %s" % GODOT)
    resumen(lanzar(a), not a.corto)


if __name__ == "__main__":
    main()
