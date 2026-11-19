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
  python tools/simulador.py --armas todas --grupos solo_guerrero,trio --escenarios uno,piso,jefe --tanda armas   # TODAS las armas
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
    for k in ("pisos", "clases", "grupos", "escenarios", "solo", "arma", "armas", "armaduras", "pociones", "escala_des"):
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
    tablas = {"R": [None, []], "P": [None, []], "E": [None, []], "S": [None, []]}
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
    for k, sufijo in (("R", ""), ("P", "_personajes"), ("E", "_enemigos"), ("S", "_seguidas")):
        with open(SALIDA / ("%s%s.csv" % (a.tanda, sufijo)), "w", encoding="utf-8", newline="") as f:
            w = csv.writer(f, delimiter=";")
            if tablas[k][0]:
                w.writerow(tablas[k][0])
            w.writerows(tablas[k][1])
    filas = tablas["R"][1]
    # y a la base de datos local, para comparar tandas a lo grande (tools/simulador_bd.py)
    try:
        sys.path.insert(0, str(RAIZ / "tools"))
        import simulador_bd
        simulador_bd.meter(a.tanda, " ".join(extra))
    except Exception as ex:   # la BD no puede tumbar la tanda: los CSV ya estan
        print("[simulador] no se pudo meter en la BD: %s" % ex)
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
    print("%-44s %5s %7s %7s %6s %7s %7s %6s %6s %7s %7s %6s %6s %6s %5s" % ("", "n", "daño/c", "turn/c", "vel", "daño/t",
          "recib/c", "mitF", "mitM", "vida", "ataque", "def", "%sinEN", "1ºsinEN", "cae"))
    for k, rs in sorted(g.items()):
        n = len(rs)
        turnos = sum(_f(r["turnos"]) for r in rs)
        sin_en = sum(_f(r["turnos_sin_energia"]) for r in rs)
        primeros = [_f(r["primer_turno_sin_energia"]) for r in rs if _f(r["primer_turno_sin_energia"]) > 0]
        ciclos = sum(_f(r.get("ciclos", "0")) for r in rs)
        print("%-44s %5d %7.1f %7.2f %6.2f %7.1f %7.1f %5.0f%% %5.0f%% %7.0f %7.1f %6.1f %5.0f%% %6.0f %4.0f%%" % (
            "piso %2d %-8s %-12s %-14s" % k, n,
            sum(_f(r["dano_hecho"]) for r in rs) / max(ciclos, 0.01), turnos / max(ciclos, 0.01),
            sum(_f(r.get("velocidad", "0")) for r in rs) / n,
            sum(_f(r["dano_hecho"]) for r in rs) / max(turnos, 1),
            sum(_f(r["dano_recibido"]) for r in rs) / max(ciclos, 0.01),
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
    print("CICLO = lo que tarda alguien con velocidad 5 en actuar dos veces (solo corre cuando corre la barra)."
          " daño/c = daño que hace por ciclo; turn/c = cuantas veces actua por ciclo; vel = su velocidad; daño/t = por turno"
          " suyo; recib/c = lo que recibe por ciclo;")
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
    print("%-50s %5s %7s %7s %6s %6s %7s %7s %7s %5s" % ("", "n", "vida", "ataque", "def", "vel", "daño/t", "daño/c", "recibe",
          "muere"))
    for k, rs in sorted(g.items()):
        n = len(rs)
        turnos = sum(_f(r["turnos"]) for r in rs)
        ciclos = sum(_f(r.get("ciclos", "0")) for r in rs)
        print("%-50s %5d %7.0f %7.1f %6.1f %6.1f %7.2f %7.2f %7.0f %4.0f%%" % (
            "piso %2d %-26s %s" % (k[0], k[1][:26], "" if k[2] == "-" else k[2][:12]), n,
            sum(_f(r["vida_max"]) for r in rs) / n, sum(_f(r["ataque"]) for r in rs) / n, sum(_f(r["defensa"]) for r in rs) / n,
            sum(_f(r["velocidad"]) for r in rs) / n, sum(_f(r["dano_hecho"]) for r in rs) / max(turnos, 1),
            sum(_f(r["dano_hecho"]) for r in rs) / max(ciclos, 0.01),
            sum(_f(r["dano_recibido"]) for r in rs) / n, 100 * sum(_f(r["muere"]) for r in rs) / n))


# EL RANKING DE ARMAS (19/11): por piso, cada equipo del hueco del guerrero (o del arquero) ordenado por su daño por ciclo
# contra el MUÑECO (lo puro, sus rotaciones) y, al lado, como le va en las peleas de verdad (gana, cae, daño/ciclo). Marca
# las que se salen de la banda: mas de un 15 % por encima o por debajo de la mediana de su piso.
BANDA = 0.15


def ranking_armas(base: str) -> None:
    rp = Path(base + "_personajes.csv")
    if not rp.exists():
        return
    with open(rp, encoding="utf-8") as f:
        filas = [r for r in csv.DictReader(f, delimiter=";") if r["rol"] in ("guerrero", "arquero")]
    if len({(r["arma"], r["armadura"]) for r in filas}) < 2:
        return
    def med(xs):
        xs = sorted(xs)
        return xs[len(xs) // 2] if xs else 0.0
    por_piso = defaultdict(lambda: defaultdict(list))
    for r in filas:
        por_piso[int(r["piso"])]["%s @%s" % (r["arma"], r["armadura"])].append(r)
    print()
    print("RANKING DE ARMAS POR PISO (daño por ciclo contra el muñeco = lo puro; y en las peleas de verdad)")
    print("  %-44s %8s %7s %7s %8s | %6s %6s %8s %6s" % ("", "muñeco", "turn/c", "daño/t", "vs med", "gana", "cae",
          "daño/c", "%sinEN"))
    for piso in sorted(por_piso):
        armas = por_piso[piso]
        puro = {}
        for a, rs in armas.items():
            m = [r for r in rs if r["escenario"] == "muneco"]
            c = sum(_f(r.get("ciclos", "0")) for r in m)
            puro[a] = sum(_f(r["dano_hecho"]) for r in m) / c if c > 0 else None
        mediana = med([v for v in puro.values() if v is not None])
        print("  -- piso %d (mediana del muñeco: %.1f)" % (piso, mediana))
        orden = sorted(armas, key=lambda a: -(puro[a] or 0.0))
        for a in orden:
            rs = armas[a]
            m = [r for r in rs if r["escenario"] == "muneco"]
            v = [r for r in rs if r["escenario"] != "muneco"]
            tm = sum(_f(r["turnos"]) for r in m)
            cm = sum(_f(r.get("ciclos", "0")) for r in m)
            cv = sum(_f(r.get("ciclos", "0")) for r in v)
            tv = sum(_f(r["turnos"]) for r in rs)
            marca = ""
            if puro[a] is not None and mediana > 0:
                d = puro[a] / mediana - 1.0
                marca = "%+5.0f%%%s" % (100 * d, "  << FLOJA" if d < -BANDA else ("  >> FUERTE" if d > BANDA else ""))
            print("  %-44s %8s %7s %7s %8s | %5s %5s %8s %5.0f%%  %s" % (
                a, "%.1f" % puro[a] if puro[a] is not None else "-",
                "%.2f" % (tm / cm) if cm > 0 else "-",
                "%.1f" % (sum(_f(r["dano_hecho"]) for r in m) / tm) if tm > 0 else "-",
                marca.split("  ")[0] if marca else "-",
                "%.0f%%" % (100 * sum(1 for r in v if r["gana"] == "GANA") / len(v)) if v else "-",
                "%.0f%%" % (100 * sum(_f(r["cayo"]) for r in v) / len(v)) if v else "-",
                "%.1f" % (sum(_f(r["dano_hecho"]) for r in v) / cv) if cv > 0 else "-",
                100 * sum(_f(r["turnos_sin_energia"]) for r in rs) / max(tv, 1),
                marca[len(marca.split("  ")[0]):].strip() if marca else ""))


# ESTADOS Y ELEMENTOS (19/11): cuanto daño meten los estados (DoT) de cada bando, y de que elemento es el daño de los tuyos.
def estados_y_elementos(base: str) -> None:
    def leer(suf):
        ruta = Path(base + suf)
        if not ruta.exists():
            return []
        with open(ruta, encoding="utf-8") as f:
            return list(csv.DictReader(f, delimiter=";"))
    peleas = [r for r in leer(".csv") if r.get("escenario") != "muneco"]
    pers = leer("_personajes.csv")
    if not peleas or "estados_en_enemigos" not in peleas[0]:
        return
    def suma(filas, col, clave):
        g = defaultdict(lambda: defaultdict(float))
        for r in filas:
            for trozo in (r.get(col) or "").split(","):
                partes = trozo.rsplit(":", 1)
                if len(partes) == 2:
                    g[clave(r)][partes[0]] += _f(partes[1])
        return g
    print()
    print("ESTADOS: daño por pelea que meten los estados (DoT), por piso")
    tus = suma(peleas, "estados_en_enemigos", lambda r: int(r["piso"]))
    suyos = suma(peleas, "estados_en_los_tuyos", lambda r: int(r["piso"]))
    n_piso = defaultdict(int)
    for r in peleas:
        n_piso[int(r["piso"])] += 1
    for piso in sorted(set(tus) | set(suyos)):
        n = max(n_piso[piso], 1)
        a = ", ".join("%s %.1f" % (k, v / n) for k, v in sorted(tus[piso].items(), key=lambda x: -x[1]))
        b = ", ".join("%s %.1f" % (k, v / n) for k, v in sorted(suyos[piso].items(), key=lambda x: -x[1]))
        print("  piso %2d  los tuyos a ellos: %s" % (piso, a or "-"))
        print("           ellos a los tuyos:  %s" % (b or "-"))
    if pers and "dano_por_elemento" in pers[0]:
        print()
        print("ELEMENTOS: de que es el daño de cada uno (%% de su daño), por piso y rol")
        el = suma(pers, "dano_por_elemento", lambda r: (int(r["piso"]), r["rol"]))
        for k in sorted(el):
            tot = sum(el[k].values()) or 1.0
            print("  piso %2d %-8s %s" % (k[0], k[1], ", ".join("%s %.0f%%" % (e, 100 * v / tot)
                  for e, v in sorted(el[k].items(), key=lambda x: -x[1]))))


# LA MAZMORRA SEGUIDA: cuantas peleas del piso aguanta cada grupo sin volver al pueblo.
def resumen_seguidas(base: str) -> None:
    ruta = Path(base + "_seguidas.csv")
    if not ruta.exists():
        return
    with open(ruta, encoding="utf-8") as f:
        filas = list(csv.DictReader(f, delimiter=";"))
    if not filas:
        return
    g = defaultdict(list)
    for r in filas:
        g[(int(r["piso"]), r["grupo"], r["arma"])].append(r)
    print()
    print("MAZMORRA SEGUIDA: peleas del piso que aguantais sin volver al pueblo (tope %s)" % "12")
    for k, rs in sorted(g.items()):
        xs = sorted(int(_f(r["peleas_ganadas"])) for r in rs)
        print("  piso %2d %-13s %-14s media %4.1f  mediana %2d  (min %d, max %d, %d bajadas)  pociones que sobran %.1f" % (
            k[0], k[1], k[2], sum(xs) / len(xs), xs[len(xs) // 2], xs[0], xs[-1], len(xs),
            sum(_f(r["pociones_que_quedan"]) for r in rs) / len(rs)))


# EL DETECTOR DE RAREZAS (19/11): avisa solo de lo que se sale, para no tener que leerse las tablas enteras.
def rarezas(base: str) -> None:
    avisos = []
    def leer(suf):
        ruta = Path(base + suf)
        if not ruta.exists():
            return []
        with open(ruta, encoding="utf-8") as f:
            return list(csv.DictReader(f, delimiter=";"))
    peleas = leer(".csv")
    pers = leer("_personajes.csv")
    enems = leer("_enemigos.csv")
    # peleas raras o eternas
    raras = [r for r in peleas if r["gana"] in ("ATASCADA", "TABLAS", "CERRADA") or r["gana"].startswith("ERROR")]
    if raras:
        avisos.append("%d peleas raras (atascadas/tablas/errores), p. ej. piso %s %s contra %s%s" % (len(raras), raras[0]["piso"],
                      raras[0]["grupo"], raras[0]["enemigo"],
                      ("  -> repetirla: python tools/simulador.py --repetir %s" % raras[0]["repetir"]) if raras[0].get("repetir") else ""))
    reales = [r for r in peleas if r.get("escenario") != "muneco"]
    largas = [r for r in reales if _f(r.get("ciclos", "0")) > 30]
    if largas:
        avisos.append("%d peleas de mas de 30 ciclos (la mas larga: %.0f, piso %s %s contra %s)" % (len(largas),
                      max(_f(r.get("ciclos", "0")) for r in largas), largas[0]["piso"], largas[0]["grupo"], largas[0]["enemigo"]))
    # enemigos que casi nadie mata, o que no hacen nada
    g = defaultdict(list)
    for r in enems:
        if r.get("escenario") != "muneco":
            g[(r["piso"], r["enemigo"], r["mutacion"])].append(r)
    for (piso, en, mut), rs in sorted(g.items()):
        if len(rs) < 3:
            continue
        muere = sum(_f(r["muere"]) for r in rs) / len(rs)
        actua = sum(_f(r["turnos"]) for r in rs) / len(rs)
        hace = sum(_f(r["dano_hecho"]) for r in rs) / len(rs)
        nombre = "%s%s (piso %s)" % (en, "" if mut == "-" else " " + mut, piso)
        if muere < 0.2:
            avisos.append("%s: casi nadie lo tumba (muere en el %.0f %% de %d peleas)" % (nombre, 100 * muere, len(rs)))
        if actua > 0 and hace < 0.5:
            avisos.append("%s: actua pero casi no hace daño (%.1f de media en %d peleas)" % (nombre, hace, len(rs)))
        if actua < 0.5:
            avisos.append("%s: casi nunca llega a actuar (%.1f turnos de media)" % (nombre, actua))
    # los tuyos: siempre caen, nunca gastan energia, se quedan secos, acciones que no hacen nada
    g2 = defaultdict(list)
    for r in pers:
        if r.get("escenario") != "muneco":
            g2[(r["piso"], r["rol"], r["arma"])].append(r)
    for (piso, rol, arma), rs in sorted(g2.items()):
        if len(rs) < 3:
            continue
        turnos = sum(_f(r["turnos"]) for r in rs)
        cae = sum(_f(r["cayo"]) for r in rs) / len(rs)
        sin_en = sum(_f(r["turnos_sin_energia"]) for r in rs) / max(turnos, 1)
        sin_mp = sum(_f(r.get("turnos_sin_mana", "0")) for r in rs) / max(turnos, 1)
        nombre = "%s con %s (piso %s)" % (rol, arma, piso)
        if cae > 0.8:
            avisos.append("%s: cae en el %.0f %% de sus peleas" % (nombre, 100 * cae))
        if sin_en > 0.5:
            avisos.append("%s: empieza el %.0f %% de sus turnos sin energia para su habilidad mas barata" % (nombre, 100 * sin_en))
        if sin_mp > 0.4:
            avisos.append("%s: empieza el %.0f %% de sus turnos sin mana para su hechizo mas barato" % (nombre, 100 * sin_mp))
    acc = defaultdict(lambda: [0, 0.0])
    for r in pers:
        for trozo in (r["acciones"] or "").split(","):
            partes = trozo.rsplit(":", 2)
            if len(partes) == 3:
                acc[(r["rol"], r["arma"], partes[0])][0] += int(_f(partes[1]))
                acc[(r["rol"], r["arma"], partes[0])][1] += _f(partes[2])
    NO_DANO = ("defender", "pasar", "Poción", "Vendaje", "Filo", "Manto", "Fortaleza", "Provocación", "Muro", "Guardia", "Luz")
    for (rol, arma, ac), (u, d) in sorted(acc.items()):
        if u >= 10 and d <= 0.0 and not any(ac.startswith(x) for x in NO_DANO):
            avisos.append("%s con %s: '%s' se ha usado %d veces y no ha quitado nada" % (rol, arma, ac, u))
    print()
    print("RAREZAS (%d)" % len(avisos))
    for a in avisos:
        print("  - " + a)
    if not avisos:
        print("  (nada fuera de lo normal)")


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
    ap.add_argument("--escala-des", dest="escala_des", default="", help="daga:1,estoque:0.5 = esas armas escalan con la Destreza SOLO en la simulacion")
    ap.add_argument("--pociones", default="", help="vida,mana por pelea (por defecto una de vida por cabeza y una de mana si va mago)")
    ap.add_argument("--solo", default="")
    ap.add_argument("--arma", default="")
    ap.add_argument("--armas", default="", help="todas (todas las combinaciones de manos), basicas (las once solas), o una lista 'daga+escudo_pequeno,...'")
    ap.add_argument("--armaduras", default="", help="todas (tela, cuero, hierro, placas) o una lista: el hueco del guerrero la lleva en vez de la de su perfil")
    ap.add_argument("--tanda", default="hoy")
    ap.add_argument("--reglas", default="hoy")
    ap.add_argument("--escala", default="8")
    ap.add_argument("--tope", type=int, default=3 * 3600)
    ap.add_argument("--sin-mutantes", action="store_true")
    ap.add_argument("--sin-jefes", action="store_true")
    ap.add_argument("--resumen", default="")
    ap.add_argument("--repetir", default="", help="la columna 'repetir' de una pelea: la vuelve a jugar igual, con ventana, y la graba en video")
    ap.add_argument("--corto", action="store_true", help="solo el resumen por piso y clase")
    a = ap.parse_args()
    if a.repetir:
        SALIDA.mkdir(parents=True, exist_ok=True)
        video = SALIDA / ("repetida_%s.avi" % a.repetir.replace(",", "_"))
        print("[simulador] repitiendo la pelea con ventana; el video queda en %s" % video)
        subprocess.run([str(GODOT), "--fixed-fps", "60", "--path", str(RAIZ), "--write-movie", str(video),
                        "res://tools/simulador_peleas.tscn", "--", "repetir=" + a.repetir], cwd=str(RAIZ))
        return
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
    estados_y_elementos(base)
    resumen_seguidas(base)
    ranking_armas(base)
    rarezas(base)


if __name__ == "__main__":
    main()
