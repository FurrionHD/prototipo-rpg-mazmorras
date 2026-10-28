#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
medir_red.py -- cuanto pesa cada mensaje de red (plan de optimizacion, fase 3: "medir primero").

Godot cuenta los bytes de cada RPC para su perfilador, pero solo con el editor conectado. Esto lo hace a mano:
envuelve TODOS los envios (`algo.rpc_id(...)` y `algo.rpc(...)`) para que pasen por Medidor.rpc_id_m / rpc_m, que
apunta el tamaño de los argumentos (var_to_bytes) por mensaje y lo vuelca al log cada 5 s como lineas [red].
Los .rpc() a todos cuentan una vez por cada peer que lo recibe. NO se sube instrumentado: poner, pasar, quitar.

  python tools/medir_red.py poner              # instrumenta scripts/ (y Medidor)
  python tools/pasar_pruebas.py town_dos_jugadores     # (o la que sea: sus logs llevan las lineas [red])
  python tools/medir_red.py leer <logs...>     # junta el ultimo volcado de cada log: mensajes por bytes
  python tools/medir_red.py quitar             # deja scripts/ como en git

El tamaño es el de var_to_bytes de los argumentos (+8 por envio): Godot codifica las RPC algo mas apretado, asi que
vale para ORDENAR, no para sumar al byte.
"""
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
MEDIDOR = RAIZ / "scripts" / "core" / "medidor.gd"
# Un envio: <expresion>.rpc_id( o <expresion>.rpc( al principio de la instruccion.
ENVIO = re.compile(r"^(\s*)([A-Za-z_][A-Za-z_0-9.]*)\.(rpc_id|rpc)\(", re.M)

ANADIDO = '''

# --- MEDIR_RED (tools/medir_red.py): NO SE SUBE ------------------------------------------------------------------
static var _red: Dictionary = {}   # mensaje -> [envios, bytes]
static var _red_volcado: float = 0.0

static func rpc_id_m(c: Callable, nombre: String, peer: int, ...args: Array) -> void:
	var a: Array = args
	_red_contar(nombre, a, 1 if peer != 0 else _red_peers())
	Callable.create(c, "rpc_id").callv([peer] + a)

static func rpc_m(c: Callable, nombre: String, ...args: Array) -> void:
	var a: Array = args
	_red_contar(nombre, a, _red_peers())
	Callable.create(c, "rpc").callv(a)

static func _red_peers() -> int:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null or arbol.get_multiplayer().multiplayer_peer == null:
		return 0
	return arbol.get_multiplayer().get_peers().size()

static func _red_contar(nombre: String, args: Array, veces: int) -> void:
	if veces <= 0:
		return
	var b: int = var_to_bytes(args).size() + 8
	var fila: Array = _red.get(nombre, [0, 0])
	fila[0] += veces
	fila[1] += b * veces
	_red[nombre] = fila
	var ahora: float = Time.get_ticks_msec() / 1000.0
	if ahora - _red_volcado >= 5.0:
		_red_volcado = ahora
		_red_volcar()

static func _red_volcar() -> void:
	var t: float = Time.get_ticks_msec() / 1000.0
	print("[red] volcado t=%.0f" % t)
	for k in _red:
		print("[red] %s %d %d" % [k, int(_red[k][0]), int(_red[k][1])])
'''


def _scripts_limpios() -> bool:
    r = subprocess.run(["git", "status", "--porcelain", "--", "scripts"], cwd=str(RAIZ), capture_output=True, text=True)
    return r.returncode == 0 and r.stdout.strip() == ""


def poner() -> int:
    # 'quitar' deja scripts/ como en git: con cambios sin commit se los llevaria por delante.
    if not _scripts_limpios():
        print("scripts/ tiene cambios sin commit: haz commit antes de medir (quitar los borraria)")
        return 1
    n = 0
    for p in sorted((RAIZ / "scripts").rglob("*.gd")):
        s = p.read_text(encoding="utf-8")
        def cambia(m):
            sangria, expr, tipo = m.group(1), m.group(2), m.group(3)
            nombre = expr.split(".")[-1]
            return '%sMedidor.%s_m(%s, "%s", ' % (sangria, tipo, expr, nombre)
        s2, k = ENVIO.subn(cambia, s)
        if k:
            # rpc() sin argumentos queda con una coma colgando: GDScript la admite.
            p.write_text(s2, encoding="utf-8", newline="")
            n += k
    MEDIDOR.write_text(MEDIDOR.read_text(encoding="utf-8") + ANADIDO, encoding="utf-8", newline="")
    print("envios instrumentados: %d" % n)
    return 0


def quitar() -> int:
    subprocess.run(["git", "checkout", "--", "scripts"], cwd=str(RAIZ), check=True)
    print("scripts/ como en git")
    return 0


def leer(rutas) -> int:
    total = defaultdict(lambda: [0, 0])
    for r in rutas:
        ultimo = {}
        for linea in Path(r).read_text(encoding="utf-8", errors="replace").splitlines():
            if "[red] volcado" in linea:
                ultimo = {}
                continue
            m = re.search(r"\[red\] (\S+) (\d+) (\d+)$", linea)
            if m:
                ultimo[m.group(1)] = (int(m.group(2)), int(m.group(3)))
        for k, (v, b) in ultimo.items():
            total[k][0] += v
            total[k][1] += b
    suma = sum(b for _, b in total.values()) or 1
    print("%-34s %8s %10s %6s %8s" % ("mensaje", "envios", "KB", "%", "B/envio"))
    for k, (v, b) in sorted(total.items(), key=lambda x: -x[1][1]):
        print("%-34s %8d %10.1f %5.1f%% %8d" % (k, v, b / 1024.0, 100.0 * b / suma, b // max(v, 1)))
    print("TOTAL %.1f KB en %d mensajes distintos" % (suma / 1024.0, len(total)))
    return 0


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] not in ("poner", "quitar", "leer"):
        print(__doc__)
        sys.exit(1)
    if sys.argv[1] == "poner":
        sys.exit(poner())
    if sys.argv[1] == "quitar":
        sys.exit(quitar())
    sys.exit(leer(sys.argv[2:]))
