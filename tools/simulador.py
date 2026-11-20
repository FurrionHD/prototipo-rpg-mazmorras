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

Cada Godot ocupa ~450-500 MB: por defecto se lanzan los que quepan en la RAM LIBRE (dejando 1,5 GB) sin pasar de los
nucleos menos dos; --hilos N lo fuerza.
Salida: tools/resultados_simulador/<tanda>.csv (+ <tanda>_<i>.txt, la salida cruda de cada Godot).
"""
import argparse
import re
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


# CUANTOS GODOT A LA VEZ (19/11, el jefe: "¿seguro que el PC solo puede con 4?"): lo que quepa en la RAM LIBRE dejando
# 1 GB de margen y uno menos (~600 MB por Godot con la arena montada) y sin pasar de los nucleos menos dos ([[cuidado-con-la-ram]],
# [[no-ocupar-todos-los-nucleos]]). En el portatil saldra otra cuenta: por eso se mira al arrancar.
MB_POR_GODOT = 900   # (19/11) medido: ~550 al arrancar y hasta ~1000 antes del tope de memoria (--tope-mb)
MARGEN_MB = 600   # (19/11 noche, el jefe: "usa mas ram y mas cpu, dejaste mucho margen"): con 6 Godot sobraban 3,6 GB y 73 % de CPU


def ram_libre_mb() -> int:
    try:
        import ctypes

        class MEM(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong), ("ullTotalPhys", ctypes.c_ulonglong),
                        ("ullAvailPhys", ctypes.c_ulonglong), ("ullTotalPageFile", ctypes.c_ulonglong),
                        ("ullAvailPageFile", ctypes.c_ulonglong), ("ullTotalVirtual", ctypes.c_ulonglong),
                        ("ullAvailVirtual", ctypes.c_ulonglong), ("sullAvailExtendedVirtual", ctypes.c_ulonglong)]
        m = MEM()
        m.dwLength = ctypes.sizeof(MEM)
        ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(m))
        return int(m.ullAvailPhys / (1024 * 1024))
    except Exception:
        return 4000


def hilos_auto() -> int:
    por_ram = (ram_libre_mb() - MARGEN_MB) // MB_POR_GODOT
    por_cpu = max(1, (os.cpu_count() or 4) - 2)
    # (19/11 noche) SIN el "uno menos" de la tarde: el jefe pidio apurar mas la RAM y la CPU (iba lento con margen de sobra)
    return int(max(1, min(por_ram, por_cpu)))


def _args_godot(a) -> list:
    if a.pisos_hasta > 0 and not a.pisos:
        a.pisos = ",".join(str(i) for i in range(1, a.pisos_hasta + 1))
    extra = ["veces=%d" % a.veces, "tanda=%s" % a.tanda, "reglas=%s" % a.reglas, "escala=%s" % a.escala]
    for k in ("pisos", "clases", "grupos", "escenarios", "solo", "arma", "armas", "armaduras", "sets", "magias", "pociones", "escala_des",
              "vel_enemigos", "iniciativa", "equipo"):
        v = getattr(a, k)
        if v:
            extra.append("%s=%s" % (k, v))
    if a.sin_mutantes:
        extra.append("sin_mutantes=1")
    if a.sin_jefes:
        extra.append("sin_jefes=1")
    if a.caer_en > 0:
        extra.append("caer_en=%d" % a.caer_en)
    return extra


# (19/11) Cuantas peleas saldrian con estos argumentos, sin jugar ninguna (un solo Godot, unos segundos): para saber si
# una tanda cabe en la tarde. Devuelve -1 si Godot no lo dice.
def contar(a) -> int:
    cmd = [str(GODOT), "--headless", "--path", str(RAIZ), "res://tools/simulador_peleas.tscn", "--", "trozo=0/1", "contar"] + _args_godot(a)
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", cwd=str(RAIZ))
    for l in r.stdout.splitlines():
        if l.startswith("[sim] CONTAR "):
            return int(l.split()[2])
    return -1


def lanzar(a) -> Path:
    if a.hilos <= 0:
        a.hilos = hilos_auto()
        print("[simulador] %d Godot a la vez (RAM libre %d MB, %d nucleos)" % (a.hilos, ram_libre_mb(), os.cpu_count() or 0))
    SALIDA.mkdir(parents=True, exist_ok=True)
    extra = _args_godot(a)
    t0 = time.time()
    trozos = [Trozo(i, a.hilos, a.tanda, extra + (["tope_mb=%d" % a.tope_mb] if a.tope_mb > 0 else [])) for i in range(a.hilos)]
    # REANUDAR una tanda cortada por el tope (20/11): --reanudar K0,K1,... = el caso por el que sigue cada trozo (el siguiente
    # a su ultimo CASO_HECHO); hace falta el MISMO numero de trozos (--hilos) que la tanda cortada y otro nombre de --tanda.
    if a.reanudar:
        desdes = [int(x) for x in a.reanudar.split(",")]
        if len(desdes) != a.hilos:
            raise SystemExit("[simulador] --reanudar trae %d trozos y hay %d hilos" % (len(desdes), a.hilos))
        for t, k in zip(trozos, desdes):
            t.desde = k
    for t in trozos:
        t.lanzar()
    print("[simulador] %d Godot en marcha (%s)" % (a.hilos, " ".join(extra)))
    hechas_antes = -1
    while any(t.vivo() for t in trozos):
        time.sleep(5)
        if time.time() - t0 > a.tope:
            print("[simulador] TOPE de %d s: los paro" % a.tope)
            for t in trozos:
                t.parar()
            break
        for t in trozos:
            t.revisar()   # el que acabo sin FIN (tope de memoria o caida) se relanza desde su caso siguiente
        hechas = sum(t.peleas() for t in trozos)
        if hechas != hechas_antes and int(time.time() - t0) % 30 < 5:
            print("[simulador] %4d peleas  (%.0f s)" % (hechas, time.time() - t0))
            hechas_antes = hechas
    for t in trozos:
        t.parar(esperar=True)
    relanzados = sum(len(t.partes) - 1 for t in trozos)
    saltados = [c for t in trozos for c in t.saltados]
    if relanzados:
        print("[simulador] %d relanzamientos (tope de memoria o caidas)%s" % (relanzados,
              "; casos SALTADOS por tumbar al Godot dos veces: " + ", ".join(saltados) if saltados else ""))
    # juntar: R (una por pelea), P (una por personaje tuyo y pelea), E (una por enemigo y pelea)
    tablas = {"R": [None, []], "P": [None, []], "E": [None, []], "S": [None, []]}
    for t in trozos:
        for l in t.lineas_validas():
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


# UN TROZO DE LA TANDA (19/11): su Godot y, si hace falta, los que le relevan. Cada Godot dice "[sim] CASO_HECHO j" al acabar
# cada caso; si se sale por el tope de memoria ("SALGO POR MEMORIA j") o se cae, se lanza otro con desde=j siguiente en otro
# fichero (<tanda>_<i>_p<n>.txt). De una caida solo vale lo escrito hasta su ultimo caso hecho (el caso a medias se repite
# entero); si el mismo caso tumba al Godot dos veces seguidas, se salta.
class Trozo:
    def __init__(self, i, n, tanda, extra):
        self.i, self.n, self.tanda, self.extra = i, n, tanda, extra
        self.partes = []   # [ruta, fichero, proceso]
        self.desde = 0
        self.caidas_aqui = 0
        self.saltados = []
        self.acabado = False

    def lanzar(self):
        k = len(self.partes)
        crudo = SALIDA / ("%s_%d.txt" % (self.tanda, self.i) if k == 0 else "%s_%d_p%d.txt" % (self.tanda, self.i, k))
        f = open(crudo, "w", encoding="utf-8")
        cmd = [str(GODOT), "--headless", "--fixed-fps", "60", "--path", str(RAIZ), "res://tools/simulador_peleas.tscn",
               "--", "trozo=%d/%d" % (self.i, self.n), "desde=%d" % self.desde] + self.extra
        self.partes.append([crudo, f, subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=str(RAIZ))])

    def vivo(self):
        return not self.acabado

    def revisar(self):
        if self.acabado or self.partes[-1][2].poll() is None:
            return
        crudo, f, _ = self.partes[-1]
        f.close()
        texto = crudo.read_text(encoding="utf-8", errors="replace")
        memoria = re.search(r"\[sim\] SALGO POR MEMORIA (\d+)", texto)
        hechos = [int(x) for x in re.findall(r"\[sim\] CASO_HECHO (\d+)", texto)]
        if memoria:
            self.desde, self.caidas_aqui = int(memoria.group(1)), 0
        elif "[sim] FIN" in texto:
            self.acabado = True
            return
        else:
            siguiente = (max(hechos) + 1) if hechos else self.desde
            self.caidas_aqui = self.caidas_aqui + 1 if siguiente == self.desde else 1
            self.desde = siguiente
            if self.caidas_aqui >= 2:
                self.saltados.append("trozo %d caso %d" % (self.i, self.desde))
                print("[simulador] el caso %d del trozo %d tumba al Godot dos veces: me lo salto" % (self.desde, self.i))
                self.desde += 1
                self.caidas_aqui = 0
            print("[simulador] el Godot del trozo %d se ha caido: sigo desde su caso %d" % (self.i, self.desde))
        self.lanzar()

    def parar(self, esperar=False):
        for _, f, pr in self.partes:
            if pr.poll() is None:
                if esperar:
                    pr.wait()
                else:
                    pr.kill()
            if not f.closed:
                f.close()
        self.acabado = True

    def peleas(self):
        return sum(_contar(c) for c, _, _ in self.partes)

    # Las lineas que valen: de cada parte que se cayo, solo hasta su ultimo CASO_HECHO (lo de despues se repitio).
    def lineas_validas(self):
        out = []
        for k, (crudo, _, _) in enumerate(self.partes):
            lineas = crudo.read_text(encoding="utf-8", errors="replace").splitlines()
            texto = "\n".join(lineas)
            if "[sim] FIN" not in texto and "SALGO POR MEMORIA" not in texto:
                ult = max((n for n, l in enumerate(lineas) if l.startswith("[sim] CASO_HECHO")), default=-1)
                cab = [l for l in lineas if l[:2] in ("R|", "P|", "E|", "S|") and l.split("|")[1] == "tanda"]
                lineas = cab + lineas[:ult + 1]
            out.extend(lineas)
        return out


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
        if t in ("muneco", "munecos", "munecos_juntos"):
            continue   # el muñeco no muere: va en el ranking de armas
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
    print("CICLO = 2 turnos con la velocidad de su NIVEL: 5 en los pisos 1-12, la del personaje medio del 13 (~15) en el 13-24, la del 25 (~41) en el 25-36 (solo corre cuando corre la barra)."
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
            v = [r for r in rs if r["escenario"] not in ("muneco", "munecos", "munecos_juntos")]
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
    peleas = [r for r in leer(".csv") if r.get("escenario") not in ("muneco", "munecos", "munecos_juntos")]
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


# LOS SETS DE HABILIDADES: por piso y equipo, los sets ordenados por daño por ciclo contra el muñeco (los 5 mejores y el peor).
def resumen_sets(base: str) -> None:
    ruta = Path(base + "_personajes.csv")
    if not ruta.exists():
        return
    with open(ruta, encoding="utf-8") as f:
        filas = [r for r in csv.DictReader(f, delimiter=";") if r.get("habilidades_puestas") and r["escenario"] == "muneco"
                 and r["rol"] in ("guerrero", "arquero")]
    g = defaultdict(lambda: defaultdict(list))
    for r in filas:
        g[(int(r["piso"]), r["arma"], r["armadura"])][r["habilidades_puestas"]].append(r)
    if not any(len(v) > 1 for v in g.values()):
        return
    print()
    print("SETS DE HABILIDADES (daño por ciclo contra el muñeco; los 5 mejores y el peor de cada equipo)")
    for k in sorted(g):
        sets = g[k]
        if len(sets) < 2:
            continue
        val = {st: sum(_f(r["dano_hecho"]) for r in rs) / max(sum(_f(r.get("ciclos", "0")) for r in rs), 0.01) for st, rs in sets.items()}
        orden = sorted(val, key=lambda st: -val[st])
        print("  piso %2d %s @%s" % k)
        for st in orden[:5]:
            print("      %7.1f  %s" % (val[st], st))
        if len(orden) > 5:
            print("      %7.1f  %s   (el peor)" % (val[orden[-1]], orden[-1]))


# LA REVISION DE VELOCIDAD (19/11, lo pidio antes del lanzamiento definitivo: "si algun enemigo actua demasiado o muy
# poco, o los aliados aun actuan demasiadas veces"): por piso, los turnos por ciclo de los tuyos (cada uno) y de cada
# enemigo, y el cociente. Marca: enemigo < 0,3 o > 3 veces lo de los tuyos; piso donde los tuyos actuan mas del doble
# (o menos de la mitad) que el enemigo medio. Y los errores del juego que hayan salido en la salida de los Godot.
def revision_velocidad(base: str) -> None:
    rp, re_ = Path(base + "_personajes.csv"), Path(base + "_enemigos.csv")
    if not rp.exists() or not re_.exists():
        return
    with open(rp, encoding="utf-8") as f:
        pers = [r for r in csv.DictReader(f, delimiter=";") if r.get("escenario") not in ("muneco", "munecos", "munecos_juntos")]
    with open(re_, encoding="utf-8") as f:
        enems = [r for r in csv.DictReader(f, delimiter=";") if r.get("escenario") not in ("muneco", "munecos", "munecos_juntos")]
    if not pers or "turnos_por_ciclo" not in pers[0]:
        return
    tuyo = defaultdict(list)
    for r in pers:
        tuyo[int(r["piso"])].append(_f(r["turnos_por_ciclo"]))
    suyo = defaultdict(lambda: defaultdict(list))
    for r in enems:
        suyo[int(r["piso"])][r["enemigo"]].append(_f(r["turnos_por_ciclo"]))
    avisos = []
    print()
    print("REVISION DE VELOCIDAD: turnos por ciclo (cada uno) de los tuyos y de los enemigos, y tuyos / suyos")
    print("  %5s %7s %7s %7s   %s" % ("piso", "tuyos", "suyos", "t/s", "los que se salen"))
    for piso in sorted(tuyo):
        t = sum(tuyo[piso]) / len(tuyo[piso])
        todos = [x for xs in suyo[piso].values() for x in xs]
        sm = sum(todos) / len(todos) if todos else 0.0
        fuera = []
        for en, xs in sorted(suyo[piso].items()):
            m = sum(xs) / len(xs)
            if t > 0 and (m < 0.3 * t or m > 3.0 * t):
                fuera.append("%s %.2f" % (en, m))
                avisos.append("piso %d: %s actua %.2f por ciclo frente a %.2f de los tuyos (x%.1f)" % (piso, en, m, t, m / t))
        ratio = t / sm if sm > 0 else float("inf")
        if ratio > 2.0 or ratio < 0.5:
            avisos.append("piso %d: los tuyos actuan %.1f veces lo que el enemigo medio" % (piso, ratio))
        print("  %5d %7.2f %7.2f %7.2f   %s" % (piso, t, sm, ratio, ", ".join(fuera)))
    # los errores del juego en la salida cruda de los Godot
    errores = defaultdict(int)
    for crudo in Path(base).parent.glob(Path(base).name + "_[0-9]*.txt"):
        texto = crudo.read_text(encoding="utf-8", errors="replace").splitlines()
        for i, l in enumerate(texto):
            if "SCRIPT ERROR" in l:
                donde = texto[i + 1].strip() if i + 1 < len(texto) else ""
                errores[(l.strip()[:110], donde[:90])] += 1
    print()
    print("ERRORES DEL JUEGO EN LA TANDA (%d distintos)" % len(errores))
    for (e, d), n in sorted(errores.items(), key=lambda x: -x[1]):
        print("  %4d x %s  %s" % (n, e, d))
    if avisos:
        print()
        print("VELOCIDADES QUE SE SALEN (%d)" % len(avisos))
        for a in avisos:
            print("  - " + a)


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
    reales = [r for r in peleas if r.get("escenario") not in ("muneco", "munecos", "munecos_juntos")]
    largas = [r for r in reales if _f(r.get("ciclos", "0")) > 30]
    if largas:
        avisos.append("%d peleas de mas de 30 ciclos (la mas larga: %.0f, piso %s %s contra %s)" % (len(largas),
                      max(_f(r.get("ciclos", "0")) for r in largas), largas[0]["piso"], largas[0]["grupo"], largas[0]["enemigo"]))
    # enemigos que casi nadie mata, o que no hacen nada
    g = defaultdict(list)
    for r in enems:
        if r.get("escenario") not in ("muneco", "munecos", "munecos_juntos"):
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
        if r.get("escenario") not in ("muneco", "munecos", "munecos_juntos"):
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
    ap.add_argument("--hilos", type=int, default=0, help="cuantos Godot a la vez (0 = los que quepan en la RAM libre)")
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
    ap.add_argument("--sets", default="", help="todos = cada combinacion de 4 habilidades que pueda llevar cada equipo (¡muchas!)")
    ap.add_argument("--magias", default="", help="todas = cada hechizo de daño solo, en el mago (grupos sin guerrero); o juegos a mano 'a;b,c'")
    ap.add_argument("--armaduras", default="", help="todas (tela, cuero, hierro, placas) o una lista: el hueco del guerrero la lleva en vez de la de su perfil")
    ap.add_argument("--tanda", default="hoy")
    ap.add_argument("--reglas", default="hoy", help="hoy | nuevas (formula multiplicativa, defensa K por piso con tope 75 %%, enemigos con nivel)")
    ap.add_argument("--vel-enemigos", dest="vel_enemigos", default="", help="relativa (de serie: la de su piso de origen frente a los personajes) | bakeada")
    ap.add_argument("--equipo", default="", help="suerte (de serie: cada pieza tira rareza y mejora por su piso) | fijo (la mas probable y la mejora del medio: para comparar armas o sets)")
    ap.add_argument("--iniciativa", default="", help="mixta (de serie: mitad tuya, mitad te emboscan) | tuya | suya")
    ap.add_argument("--pisos-hasta", dest="pisos_hasta", type=int, default=0, help="atajo: pisos=1..N (p. ej. 36)")
    # (19/11) x2 DE SERIE: comprobado que da lo mismo que x1 (el ritmo del juego) y x8 NO (los enemigos sacaban mas turnos
    # y las peleas duraban el doble de ciclos); x8 solo iba un 15 % mas rapido.
    ap.add_argument("--escala", default="2")
    ap.add_argument("--tope", type=int, default=8 * 3600, help="segundos que puede durar la tanda entera")
    ap.add_argument("--reanudar", default="", help="K0,K1,...: el caso por el que sigue cada trozo de una tanda cortada (mismo --hilos)")
    # (19/11) LA MEMORIA de cada Godot se va calentando (poses, hojas de cada color...) y en tandas de horas pasaba del GB:
    # pasado este tope (memoria estatica, MB) se sale al acabar su caso y se relanza desde ahi. 0 = sin tope.
    ap.add_argument("--tope-mb", dest="tope_mb", type=int, default=750)
    ap.add_argument("--sin-mutantes", action="store_true")
    ap.add_argument("--sin-jefes", action="store_true")
    ap.add_argument("--resumen", default="")
    ap.add_argument("--repetir", default="", help="la columna 'repetir' de una pelea: la vuelve a jugar igual, con ventana, y la graba en video")
    ap.add_argument("--corto", action="store_true", help="solo el resumen por piso y clase")
    ap.add_argument("--caer-en", dest="caer_en", type=int, default=0, help="PRUEBA: cada Godot se estrella tras N peleas (una vez) para probar el relevo")
    ap.add_argument("--contar", action="store_true", help="solo dice cuantas peleas saldrian (no juega ninguna)")
    a = ap.parse_args()
    if a.contar:
        print("[simulador] %s: %d peleas" % (a.tanda, contar(a)))
        return
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
    resumen_sets(base)
    revision_velocidad(base)
    rarezas(base)


if __name__ == "__main__":
    main()
