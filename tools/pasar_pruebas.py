#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
pasar_pruebas.py -- pasa la bateria de pruebas sin ventana (tools/prueba_*.tscn) y dice cuales fallan.

REGLA (12/10/2026, la pidio el jefe): ANTES DE CADA COMMIT O SUBIDA se pasan las pruebas y tienen que
salir todas bien. Cada mecanica nueva entra con su prueba (y se apunta aqui si necesita algo especial).

  python tools/pasar_pruebas.py              # TODAS (las de red de una en una) -> al acabar una fase, antes de juntar a main / .exe
  python tools/pasar_pruebas.py --rapidas    # antes de cada commit (~1-2 min): unitarias + IMPRESCINDIBLES + las que
                                             # nombran los scripts que has tocado (ver tools/INDICE_PRUEBAS.md)
  python tools/pasar_pruebas.py --sin-red    # todas menos las de red (la --rapidas de antes del 15/10, ~7 min)
  python tools/pasar_pruebas.py arena magias # solo las que contengan esas palabras en el nombre
  python tools/pasar_pruebas.py --lista      # ensena que pasaria y con que tope, sin lanzar nada
  python tools/pasar_pruebas.py --unitarias  # solo las unitarias (tools/unitarias/test_*.gd): segundos

Cada prueba deja su salida en tools/resultados_pruebas/<nombre>.log (ignorada en git) y al final sale
un resumen: BIEN / MAL / COLGADA (paso su tope) / SIN MARCA (acabo sin decir ni bien ni mal).
Devuelve 0 solo si todas salen BIEN.

Como decide si una prueba ha ido bien (las hay de varias epocas y cada una lo dice a su manera):
  - MAL si: codigo de salida distinto de 0, o una linea de fallo (MAL / FALLA / FALLAN n / "n fallos" con
    n > 0), o un SCRIPT ERROR / Parse Error (el juego peto por dentro aunque la prueba no lo viera).
  - BIEN si no hay nada de eso y aparece su marca de exito (TODO BIEN, TODO PASA, OK:, "0 fallos"...).
  - SIN MARCA si acaba limpia pero sin marca: hay que mirarla y ponerle su "FIN: TODO BIEN".
"""
import argparse
import os
import re
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
TOOLS = RAIZ / "tools"
SALIDA = TOOLS / "resultados_pruebas"

GODOT_CANDIDATOS = [
    os.environ.get("GODOT", ""),
    str(Path.home() / "AppData/Local/Microsoft/WinGet/Packages/"
        "GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7-stable_win64_console.exe"),
]

# LAS IMPRESCINDIBLES (15/10/2026, decision del jefe: "las rapidas antes de cada commit y la grande al final o al
# juntar a main"). Cortas y repartidas por los sistemas: que todo compile, la huella del combate, guardar y cargar,
# lo que viaja por la red, el tactico, magias, mutantes, runas, el piso, la niebla y la interfaz. A esto --rapidas
# le suma las que NOMBRAN los scripts tocados (git), salvo los que nombran casi todas (game.gd): ahi no hay atajo.
IMPRESCINDIBLES = [
    "prueba_unitarias", "prueba_cargar_todo", "prueba_huella_combate",
    "prueba_bd_ida_vuelta", "prueba_bd_un_jugador", "prueba_viaja_todo", "prueba_ficha_fiel",
    "prueba_tactico_montaje", "prueba_arena_tactica", "prueba_formas_area", "prueba_retraso_barra",
    "prueba_magias_regla", "prueba_mutaciones", "prueba_runas", "prueba_encargos_excelia",
    "prueba_carga_piso", "prueba_niebla_quieto", "prueba_suelo_monton", "prueba_zona_ajena",
    "prueba_jugador_no_monta", "prueba_iniciativa_red", "prueba_scroll_rejilla",
]
# Un script que nombran mas de estas pruebas (game.gd, combat.gd...) no arrastra sus pruebas a --rapidas:
# serian casi todas. Para esos, la grande al acabar.
TOPE_TOCADOS = 25


def tocados_en_git() -> list:
    """Los .gd de scripts/ cambiados respecto al ultimo commit (incluidos los nuevos sin añadir)."""
    def git(*a):
        try:
            return subprocess.run(["git", *a], capture_output=True, text=True, cwd=str(RAIZ), timeout=30).stdout
        except Exception:
            return ""
    nombres = set(git("diff", "--name-only", "HEAD").split()) | set(git("ls-files", "--others", "--exclude-standard").split())
    return sorted(RAIZ / n for n in nombres if n.startswith("scripts/") and n.endswith(".gd") and (RAIZ / n).exists())


def pruebas_de_tocados(disponibles: list) -> list:
    sys.path.insert(0, str(TOOLS))
    from indice_pruebas import quien_nombra
    out = set()
    tocados = tocados_en_git()
    for s, ps in quien_nombra(tocados).items():
        nombres = {Path(p).stem for p in ps if p.startswith("prueba_")}
        rel = s.relative_to(RAIZ).as_posix()
        if len(nombres) > TOPE_TOCADOS:
            print("  (%s lo nombran %d pruebas: no se suman todas; pasa la grande al acabar)" % (rel, len(nombres)))
            continue
        nuevas = sorted(n for n in nombres if n in disponibles)
        if nuevas:
            print("  %s -> %s" % (rel, ", ".join(nuevas)))
        out |= set(nuevas)
    return sorted(out)


# Escenas que NO son una prueba por si solas: las lanza otra prueba como segundo proceso.
AYUDANTES = {
    "prueba_town_dos_cliente",
    "prueba_town_tactico_b",
    "prueba_town_zona_ajena_b",
    "prueba_town_baul_cliente",
    "prueba_sala_cliente",
    "prueba_solo_por_sala_cliente",
}

# Las de RED: lanzan procesos (sala, trabajadores, otro jugador) y usan puertos fijos -> de una en una.
def es_de_red(nombre: str) -> bool:
    return (nombre.startswith("prueba_town_") or nombre.startswith("prueba_sala")
            or nombre in {"prueba_tunel", "prueba_solo_por_sala", "prueba_menu_por_sala", "prueba_lan_por_sala", "prueba_baul_sala", "prueba_zona_otra_sala",
                          "prueba_vinculo_steam", "prueba_bd_nube"})

# Las que NO son una prueba sin ventana (necesitan pantalla de verdad): no se pasan.
NO_SIN_VENTANA = {"prueba_rueda_cristales"}

# COMO SE LANZA cada una que no va "a pelo" (lo dice la cabecera de cada prueba). Cada entrada es una lista de
# PASADAS en orden (las de dos fases son dos procesos): {"antes": args de godot, "despues": args tras "--",
# "env": variables}. Cuenta como BIEN solo si salen bien TODAS sus pasadas.
NUBE_LOCAL = [{"despues": ["nube_local"]}]
COMO_SE_LANZA = {
    "prueba_bd_nube": NUBE_LOCAL,
    "prueba_bd_un_jugador": NUBE_LOCAL,
    "prueba_nube_sin_red": NUBE_LOCAL,
    "prueba_sala": NUBE_LOCAL,
    "prueba_sala_dos_jugadores": NUBE_LOCAL,
    "prueba_sala_ranura": NUBE_LOCAL,
    "prueba_solo_por_sala": NUBE_LOCAL,
    "prueba_lan_por_sala": NUBE_LOCAL,
    "prueba_menu_por_sala": [{"despues": ["nube_local", "sala_vacia=6"]}],
    "prueba_sala_steam": NUBE_LOCAL,
    "prueba_vinculo_steam": NUBE_LOCAL,
    "prueba_sala_entrar": [{"despues": ["nube_local", "sala_vacia=4"]}],
    "prueba_huella_combate": [{"antes": ["--fixed-fps", "60"], "despues": ["comparar"]}],
    # "prepara": esa pasada solo deja las cosas listas para la siguiente (p. ej. se mata a si misma): no cuenta.
    "prueba_bd_altf4": [{"env": {"ALTF4_FASE": "1"}, "prepara": True}, {"env": {"ALTF4_FASE": "2"}}],
    "prueba_pelea_a_medias": [{"env": {"PELEA_FASE": "1"}, "prepara": True}, {"env": {"PELEA_FASE": "2"}}],
    # La larga y, aparte, los dos "cabos sueltos" (el trabajador de pelea se cae con tus fichas, etc.).
    "prueba_town_trabajadores": [{}, {"env": {"PRUEBA_CABOS": "1"}}],
}

# LAS QUE VAN DE UNA EN UNA aunque no sean de red: tocan las mismas ranuras de guardado (user://, la ranura 97...) y
# a la vez se pisan (12/10: con 6 a la vez fallaron bd_altf4 y bd_ranura, y solas pasan).
def va_sola(nombre: str) -> bool:
    return es_de_red(nombre) or nombre.startswith("prueba_bd_") or nombre in {
        "prueba_pelea_a_medias", "prueba_huella_save", "prueba_nube_sin_red", "prueba_ranura_a_mundo"}


TOPE_NORMAL = 120     # s. Regla del jefe: topes de 3-5 veces lo que tarda, nada de 500 s.
TOPE_RED = 240
TOPES = {             # las que tardan mas de lo normal cuando van bien
    "prueba_cargar_todo": 180,
    "prueba_huella_combate": 180,
    "prueba_companeros_pueblo": 300,
    "prueba_town_dos_jugadores": 360,   # ~3-4 min: dos jugadores, cuatro peleas y la arena   # ~105 s: recorre el pueblo andando y corriendo
}

R_FALLO = re.compile(
    r"(^\s*MAL\b|\b[1-9]\d* MAL\b|\bMAL:|\[FALLA\]|^FALLA\b|\bFALLAN \d+|\[FALLO\]|^FALLO\b|\b[1-9]\d* fallos?\b|\b[1-9]\d* fallo\(s\))",
    re.MULTILINE)
# Errores del MOTOR: el juego peto por dentro. Cuentan como MAL salvo que la prueba diga claramente que ha ido
# bien (hay pruebas que provocan un error a proposito, p. ej. prueba_bd_partida lee un .tres roto).
R_MOTOR = re.compile(r"(SCRIPT ERROR|Parse Error|Failed to load script)")
R_EXITO = re.compile(
    r"(TODO BIEN|TODO PASA|TODO CUADRA|TODO IGUAL|TODO VIAJA|^OK:|\b0 fallos?\b|\b0 fallo\(s\)|RESULTADO: OK|RESULTADO: 0 fallos)",
    re.MULTILINE)
# Lo que Godot escupe siempre al cerrar y no significa nada (ver LEEME_pruebas.md).
R_RUIDO = re.compile(r"(ObjectDB instances leaked|resources still in use|RID allocations? .*leaked)")


def buscar_godot() -> str:
    for c in GODOT_CANDIDATOS:
        if c and Path(c).exists():
            return c
    sys.exit("No encuentro Godot: pon la ruta en la variable GODOT.")


def todas_las_pruebas() -> list:
    return sorted(p.stem for p in TOOLS.glob("prueba_*.tscn")
                  if p.stem not in AYUDANTES and p.stem not in NO_SIN_VENTANA)


def matar_restos() -> None:
    """Las de red dejan Godots vivos si se cortan: los que sigan con el puerto 24599/24567 se cierran."""
    if os.name != "nt":
        return
    try:
        out = subprocess.run(["netstat", "-ano"], capture_output=True, text=True, timeout=20).stdout
    except Exception:
        return
    pids = set()
    for linea in out.splitlines():
        if ":24599" in linea or ":24567" in linea:
            partes = linea.split()
            if partes and partes[-1].isdigit() and partes[-1] != "0":
                pids.add(partes[-1])
    for pid in pids:
        subprocess.run(["taskkill", "/F", "/T", "/PID", pid], capture_output=True)


def _una_pasada(godot: str, nombre: str, pasada: dict, tope: float):
    cmd = [godot, "--headless"] + pasada.get("antes", []) + ["--path", str(RAIZ), "res://tools/%s.tscn" % nombre]
    if pasada.get("despues"):
        cmd += ["--"] + pasada["despues"]
    env = dict(os.environ)
    env.update(pasada.get("env", {}))
    try:
        p = subprocess.run(cmd, capture_output=True, timeout=tope, cwd=str(RAIZ), env=env)
        return (p.stdout + p.stderr).decode("utf-8", "replace"), p.returncode, False
    except subprocess.TimeoutExpired as e:
        return ((e.stdout or b"") + (e.stderr or b"")).decode("utf-8", "replace"), None, True


def _juzgar(texto: str, codigo, colgada: bool):
    lineas = [l for l in texto.splitlines() if not R_RUIDO.search(l)]
    fallos = [l.strip() for l in lineas if R_FALLO.search(l)]
    motor = [l.strip() for l in lineas if R_MOTOR.search(l)]
    exito = bool(R_EXITO.search(texto))
    if colgada:
        return "COLGADA", fallos + motor
    if codigo != 0 or fallos or (motor and not exito):
        return "MAL", fallos + motor
    if exito:
        return "BIEN", []
    return "SIN MARCA", []


ORDEN_MALO = {"BIEN": 0, "SIN MARCA": 1, "MAL": 2, "COLGADA": 3}


def pasar(godot: str, nombre: str) -> dict:
    tope = TOPES.get(nombre, TOPE_RED if es_de_red(nombre) else TOPE_NORMAL)
    pasadas = COMO_SE_LANZA.get(nombre, [{}])
    t0 = time.time()
    textos = []
    estado, fallos, codigo = "BIEN", [], 0
    for i, pasada in enumerate(pasadas):
        texto, cod, colgada = _una_pasada(godot, nombre, pasada, tope)
        textos.append("===== pasada %d %s =====\n%s" % (i + 1, pasada, texto))
        if colgada and es_de_red(nombre):
            matar_restos()
        if pasada.get("prepara") and not colgada:
            continue   # solo deja listo lo de la siguiente pasada
        e, f = _juzgar(texto, cod, colgada)
        if ORDEN_MALO[e] > ORDEN_MALO[estado]:
            estado, codigo = e, cod
        fallos += ["(pasada %d) %s" % (i + 1, x) for x in f] if len(pasadas) > 1 else f
        if colgada:
            break
    dur = time.time() - t0
    (SALIDA / (nombre + ".log")).write_text("\n".join(textos), encoding="utf-8")
    return {"nombre": nombre, "estado": estado, "dur": dur, "tope": tope, "codigo": codigo, "fallos": fallos[:6]}


def main() -> int:
    ap = argparse.ArgumentParser(description="Pasa las pruebas sin ventana de tools/.")
    ap.add_argument("filtros", nargs="*", help="solo las que contengan alguna de estas palabras")
    ap.add_argument("--rapidas", action="store_true",
                    help="antes de cada commit: unitarias + imprescindibles + las de los scripts tocados")
    ap.add_argument("--sin-red", action="store_true", help="todas menos las de red")
    ap.add_argument("--hilos", type=int, default=4, help="cuantas a la vez (por defecto 4; con 6 fallan las que miden tiempos)")
    ap.add_argument("--lista", action="store_true", help="ensena la lista y sale")
    ap.add_argument("--unitarias", action="store_true", help="solo las unitarias (tools/unitarias): segundos")
    a = ap.parse_args()

    nombres = todas_las_pruebas()
    if a.unitarias:
        nombres = ["prueba_unitarias"]
    if a.filtros:
        nombres = [n for n in nombres if any(f in n for f in a.filtros)]
    if a.rapidas:
        print("Rapidas: imprescindibles + las que nombran los scripts tocados:")
        nombres = sorted(set(n for n in IMPRESCINDIBLES if n in nombres) | set(pruebas_de_tocados(nombres)))
    if a.sin_red:
        nombres = [n for n in nombres if not es_de_red(n)]
    sin_red = [n for n in nombres if not va_sola(n)]
    con_red = [n for n in nombres if va_sola(n)]   # las de red y las que comparten ranura: de una en una
    if a.lista:
        for n in nombres:
            print("%-34s %s  tope %d s" % (n, "RED " if es_de_red(n) else "    ",
                                            TOPES.get(n, TOPE_RED if es_de_red(n) else TOPE_NORMAL)))
        print("%d pruebas (%d de red)" % (len(nombres), len(con_red)))
        return 0

    godot = buscar_godot()
    SALIDA.mkdir(exist_ok=True)
    print("Importando el proyecto (registra los class_name nuevos)...", flush=True)
    subprocess.run([godot, "--headless", "--path", str(RAIZ), "--import"], capture_output=True, timeout=600)

    res = []
    t0 = time.time()
    def apuntar(r):
        res.append(r)
        print("[%3d/%d] %-9s %-34s %5.1f s" % (len(res), len(nombres), r["estado"], r["nombre"], r["dur"]),
              flush=True)

    with ThreadPoolExecutor(max_workers=max(1, a.hilos)) as ex:
        for fut in as_completed([ex.submit(pasar, godot, n) for n in sin_red]):
            apuntar(fut.result())
    if any(es_de_red(n) for n in con_red):
        matar_restos()
    for n in con_red:
        apuntar(pasar(godot, n))

    malas = [r for r in res if r["estado"] != "BIEN"]
    print("\n================ RESUMEN (%.0f s) ================" % (time.time() - t0))
    for estado in ("BIEN", "MAL", "COLGADA", "SIN MARCA"):
        print("%-9s %d" % (estado, sum(1 for r in res if r["estado"] == estado)))
    for r in sorted(malas, key=lambda r: (r["estado"], r["nombre"])):
        print("\n-- %s  %s  (codigo %s, %.0f s de %d)" % (r["estado"], r["nombre"], r["codigo"], r["dur"], r["tope"]))
        for f in r["fallos"]:
            print("     " + f[:160])
    print("\nSalidas en %s" % SALIDA)
    print("TODO BIEN" if not malas else "HAY %d QUE NO SALEN BIEN" % len(malas))
    return 0 if not malas else 1


if __name__ == "__main__":
    sys.exit(main())
