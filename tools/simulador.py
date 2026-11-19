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
  python tools/simulador.py --grupos duo,trio,cuatro --escenarios piso,jefe --veces 20   # grupos contra corros reales
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
    for k in ("pisos", "clases", "grupos", "escenarios", "solo", "arma", "pociones"):
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
    # juntar: R (una por pelea), P (una por personaje tuyo y pelea), E (una por enemigo y pelea)
    tablas = {"R": [None, []], "P": [None, []], "E": [None, []]}
    for _, _, crudo in procs:
        for l in crudo.read_text(encoding="utf-8", errors="replace").splitlines():
            if len(l) < 2 or l[1] != "|" or l[0] not in tablas:
                continue
            partes = l.split("|")[1:]
            if partes[0] == "tanda":
                tablas[l[0]][0] = partes
                continue
            tablas[l[0]][1].append(partes)
    destino = SALIDA / ("%s.csv" % a.tanda)
    for k, sufijo in (("R", ""), ("P", "_personajes"), ("E", "_enemigos")):
        with open(SALIDA / ("%s%s.csv" % (a.tanda, sufijo)), "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f, delimiter=";")
            if tablas[k][0]:
                w.writerow(tablas[k][0])
            w.writerows(tablas[k][1])
    filas = tablas["R"][1]
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


# EL RESUMEN. Por piso, grupo y escenario, y luego por enemigo: % de victorias, tus RONDAS para ganar (turnos de los tuyos
# / cuantos sois, en las que ganas), los turnos suyos para tumbaros (los que han tenido / la vida que os han quitado,
# extrapolado), la vida que perdeis, cuantos caen y las raras.
TAM_GRUPO = {"solo_guerrero": 1, "solo_mago": 1, "duo": 2, "trio": 3, "cuatro": 4}


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
        t_yo = sum(_f(r["turnos_yo"]) / TAM_GRUPO.get(r["grupo"], 1) for r in gana) / len(gana) if gana else float("nan")
        suyos = [(_f(r["turnos_el"]) / _f(r["vida_perdida"])) for r in rs if _f(r["vida_perdida"]) > 0.01]
        t_el = sorted(suyos)[len(suyos) // 2] if suyos else float("inf")
        vida = sum(_f(r["vida_perdida"]) for r in rs) / n
        caen = sum(_f(r.get("caidos", "0")) for r in rs) / n
        return "%4d  %5.0f%%  %6.1f  %7.1f  %6.0f%%  %5.2f  %s" % (n, 100.0 * len(gana) / n, t_yo, t_el, 100.0 * vida, caen,
            ("%d raras" % raras) if raras else "")
    cab = "%4s  %6s  %6s  %7s  %7s  %5s" % ("n", "gana", "rondas", "sus_t", "vida-", "caen")
    print()
    print("POR PISO, GRUPO Y ESCENARIO (en 'uno': normal / mutante / jefe)")
    print("%-36s %s" % ("", cab))
    def tipo(r):
        if r.get("escenario", "uno") != "uno":
            return r["escenario"]
        return "uno-jefe" if r["jefe"] == "1" else ("uno-mutante" if r["mutacion"] != "-" else "uno-normal")
    for (piso, grupo, t), rs in sorted(bloque(lambda r: (int(r["piso"]), r.get("grupo", r.get("clase", "")), tipo(r))).items()):
        print("%-36s %s" % ("piso %2d %-13s %-12s" % (piso, grupo, t), linea(rs)))
    if not detalle:
        return
    print()
    print("POR ENEMIGO (escenario 'uno')")
    print("%-60s %s" % ("", cab))
    for (piso, grupo, en, mut), rs in sorted(bloque(lambda r: (int(r["piso"]), r.get("grupo", ""), r["enemigo"], r["mutacion"])).items()):
        if rs[0].get("escenario", "uno") != "uno":
            continue
        print("%-60s %s" % ("piso %2d %-13s %-24s %s" % (piso, grupo, en[:24], "" if mut == "-" else mut[:12]), linea(rs)))
    print()
    print("rondas = turnos de los tuyos / cuantos sois, hasta ganar (media de las que ganais); sus_t = sus turnos para"
          " tumbaros (mediana, al ritmo al que os quitan vida); vida- = vida perdida media (cada uno, en %); caen = de los"
          " tuyos, cuantos caen de media; raras = atascadas/tablas/errores")


# LOS TUYOS, UNO A UNO (de <tanda>_personajes.csv): por piso, rol, arma y armadura; y cada accion, cuanto hace por uso.
def resumen_personajes(ruta: Path) -> None:
    if not ruta.exists():
        return
    with open(ruta, encoding="utf-8") as f:
        filas = list(csv.DictReader(f, delimiter=";"))
    if not filas:
        return
    def med(xs):
        xs = sorted(xs)
        return xs[len(xs) // 2] if xs else float("nan")
    g = defaultdict(list)
    for r in filas:
        g[(int(r["piso"]), r["rol"], r["arma"], r["armadura"])].append(r)
    print()
    print("LOS TUYOS, POR PISO / ROL / ARMA / ARMADURA (todas sus peleas)")
    print("%-44s %5s %7s %7s %6s %6s %7s %7s %6s %6s %6s %5s" % ("", "n", "daño/t", "recib/t", "mitF", "mitM", "vida", "ataque",
          "def", "%sinEN", "1ºsinEN", "cae"))
    for k, rs in sorted(g.items()):
        n = len(rs)
        turnos = sum(_f(r["turnos"]) for r in rs)
        sin_en = sum(_f(r["turnos_sin_energia"]) for r in rs)
        primeros = [_f(r["primer_turno_sin_energia"]) for r in rs if _f(r["primer_turno_sin_energia"]) > 0]
        print("%-44s %5d %7.1f %7.2f %5.0f%% %5.0f%% %7.0f %7.1f %6.1f %5.0f%% %6.0f %4.0f%%" % (
            "piso %2d %-8s %-12s %-14s" % k, n,
            sum(_f(r["dano_hecho"]) for r in rs) / max(turnos, 1),
            sum(_f(r["recibido_por_turno_enemigo"]) for r in rs) / n,
            100 * sum(_f(r["mitig_fisica"]) for r in rs) / n, 100 * sum(_f(r["mitig_magica"]) for r in rs) / n,
            sum(_f(r["vida_max"]) for r in rs) / n, sum(_f(r.get("ataque", "0")) for r in rs) / n,
            sum(_f(r["defensa"]) for r in rs) / n, 100 * sin_en / max(turnos, 1), med(primeros) if primeros else float("nan"),
            100 * sum(_f(r["cayo"]) for r in rs) / n))
    # cada accion: usos y daño medio por uso
    acc = defaultdict(lambda: [0, 0.0])
    for r in filas:
        for trozo in (r["acciones"] or "").split(","):
            partes = trozo.rsplit(":", 2)
            if len(partes) != 3:
                continue
            k = (int(r["piso"]), r["rol"], r["arma"], partes[0])
            acc[k][0] += int(_f(partes[1]))
            acc[k][1] += _f(partes[2])
    print()
    print("CADA ACCION: usos y daño medio por uso (lo que quita de vida, ya con defensa y resistencias)")
    for k, (u, d) in sorted(acc.items()):
        if u <= 0:
            continue
        print("  piso %2d %-8s %-12s %-26s %6d usos  %8.1f por uso" % (k[0], k[1], k[2], k[3][:26], u, d / u))
    print()
    print("daño/t = daño que hace por turno suyo; recib/t = lo que recibe por turno de los enemigos; mitF/mitM = lo que su"
          " defensa y armadura le quitan al golpe fisico/magico medio de esos enemigos; %sinEN = turnos que empieza sin"
          " energia para su habilidad de daño mas barata; 1ºsinEN = el primero (mediana); cae = % de peleas en que cae")


def resumen_enemigos(ruta: Path) -> None:
    if not ruta.exists():
        return
    with open(ruta, encoding="utf-8") as f:
        filas = list(csv.DictReader(f, delimiter=";"))
    if not filas:
        return
    g = defaultdict(list)
    for r in filas:
        g[(int(r["piso"]), r["enemigo"], r["mutacion"])].append(r)
    print()
    print("LOS ENEMIGOS (todas las peleas en que salen)")
    print("%-50s %5s %7s %7s %6s %6s %7s %7s %5s" % ("", "n", "vida", "ataque", "def", "vel", "daño/t", "recibe", "muere"))
    for k, rs in sorted(g.items()):
        n = len(rs)
        turnos = sum(_f(r["turnos"]) for r in rs)
        print("%-50s %5d %7.0f %7.1f %6.1f %6.1f %7.2f %7.0f %4.0f%%" % (
            "piso %2d %-26s %s" % (k[0], k[1][:26], "" if k[2] == "-" else k[2][:12]), n,
            sum(_f(r["vida_max"]) for r in rs) / n, sum(_f(r["ataque"]) for r in rs) / n, sum(_f(r["defensa"]) for r in rs) / n,
            sum(_f(r["velocidad"]) for r in rs) / n, sum(_f(r["dano_hecho"]) for r in rs) / max(turnos, 1),
            sum(_f(r["dano_recibido"]) for r in rs) / n, 100 * sum(_f(r["muere"]) for r in rs) / n))


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")   # la consola de Windows rompe los acentos si no
    except (AttributeError, ValueError):
        pass
    ap = argparse.ArgumentParser()
    ap.add_argument("--hilos", type=int, default=max(1, min(4, (os.cpu_count() or 4) // 2 - 1)))
    ap.add_argument("--veces", type=int, default=3)
    ap.add_argument("--pisos", default="")
    ap.add_argument("--clases", default="", help="guerrero,mago = grupos solo_guerrero,solo_mago (lo de antes)")
    ap.add_argument("--grupos", default="", help="solo_guerrero,solo_mago,duo,trio,cuatro")
    ap.add_argument("--escenarios", default="", help="uno,piso,manada,jefe")
    ap.add_argument("--pociones", default="", help="vida,mana por pelea (por defecto una de vida por cabeza y una de mana si va mago)")
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
    ruta = Path(a.resumen) if a.resumen else None
    if ruta is None:
        if not GODOT.exists():
            sys.exit("No encuentro Godot en %s" % GODOT)
        ruta = lanzar(a)
    resumen(ruta, not a.corto)
    base = str(ruta)[:-4] if str(ruta).endswith(".csv") else str(ruta)
    resumen_personajes(Path(base + "_personajes.csv"))
    if not a.corto:
        resumen_enemigos(Path(base + "_enemigos.csv"))


if __name__ == "__main__":
    main()
