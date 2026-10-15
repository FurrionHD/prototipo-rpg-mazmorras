# ============================================================
#  MEDIDOR: marcas de tiempo para saber DONDE se va el tiempo (plan de optimizacion, fase 0)
# ============================================================
# Una marca es una linea en el log:  [medir] <tramo> <paso> t=<ms del reloj del sistema> +<ms desde el inicio del tramo>
# Con el reloj del SISTEMA (no los ms desde que arranco el proceso) las marcas de la sala, los trabajadores y el
# cliente se pueden poner en una sola linea de tiempo cuando estan en el mismo PC. Entre dos PCs solo valen las
# restas DENTRO de un mismo proceso (la columna +ms), que es lo que mide lo que el jugador nota.
#
#   Medidor.empezar("pelea")              # abre el tramo (vuelve a cero si ya estaba abierto)
#   Medidor.marca("pelea", "pedida")      # una marca con lo que va desde empezar()
#   Medidor.cerrar("pelea", "pantalla")   # ultima marca; devuelve el total en ms
#
# Ademas guarda las ultimas marcas en memoria (ultimas()) para el informe de la tecla P, y medidas sueltas de
# cosas que no son tramos (medida("guardado", ms)): la media y el peor de cada una.
# Para juntar los logs de varios procesos: python tools/medir_logs.py <logs...>
# Prueba: tools/unitarias/test_medidor.gd
class_name Medidor
extends RefCounted

const MAX_MARCAS := 200

static var _inicio: Dictionary = {}     # tramo -> ms del sistema al empezar
static var _marcas: Array = []          # [{tramo, paso, t, desde}] las ultimas MAX_MARCAS
static var _medidas: Dictionary = {}    # nombre -> {n, suma, peor, ultima}
static var callado: bool = false        # las pruebas que miden mucho lo apagan para no llenar el log


static func ahora_ms() -> float:
	return Time.get_unix_time_from_system() * 1000.0


static func empezar(tramo: String, paso: String = "inicio") -> void:
	_inicio[tramo] = ahora_ms()
	_apuntar(tramo, paso, 0.0)


static func marca(tramo: String, paso: String) -> float:
	var desde: float = ahora_ms() - float(_inicio[tramo]) if _inicio.has(tramo) else -1.0
	_apuntar(tramo, paso, desde)
	return desde


static func cerrar(tramo: String, paso: String = "fin") -> float:
	var total: float = marca(tramo, paso)
	_inicio.erase(tramo)
	if total >= 0.0:
		medida(tramo, total)
	return total


static func abierto(tramo: String) -> bool:
	return _inicio.has(tramo)


# Una medida suelta (lo que tardo un guardado, una carga...). Se acumula para la media y el peor.
static func medida(nombre: String, ms: float) -> void:
	var m: Dictionary = _medidas.get(nombre, {"n": 0, "suma": 0.0, "peor": 0.0, "ultima": 0.0})
	m["n"] = int(m["n"]) + 1
	m["suma"] = float(m["suma"]) + ms
	m["peor"] = maxf(float(m["peor"]), ms)
	m["ultima"] = ms
	_medidas[nombre] = m


static func medidas() -> Dictionary:
	return _medidas


static func ultimas(n: int = 20) -> Array:
	return _marcas.slice(maxi(0, _marcas.size() - n))


# Texto para el informe de la tecla P: cada medida con su ultima, su media y su peor.
static func resumen() -> String:
	var lineas: PackedStringArray = []
	var nombres: Array = _medidas.keys()
	nombres.sort()
	for k in nombres:
		var m: Dictionary = _medidas[k]
		lineas.append("%s: ultima %.0f ms, media %.0f, peor %.0f (%d veces)" % [k, float(m["ultima"]),
			float(m["suma"]) / maxf(1.0, float(m["n"])), float(m["peor"]), int(m["n"])])
	return "\n".join(lineas)


static func olvidar() -> void:
	_inicio.clear()
	_marcas.clear()
	_medidas.clear()


static func _apuntar(tramo: String, paso: String, desde: float) -> void:
	var t: float = ahora_ms()
	_marcas.append({"tramo": tramo, "paso": paso, "t": t, "desde": desde})
	if _marcas.size() > MAX_MARCAS:
		_marcas.remove_at(0)
	if not callado:
		print("[medir] %s %s t=%.0f %s" % [tramo, paso, t, ("+%.0f" % desde) if desde >= 0.0 else "(sin empezar)"])
