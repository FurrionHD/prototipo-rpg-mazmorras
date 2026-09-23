# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_encargos_excelia.tscn
#
# EL CAMINO ENTERO de la excelia de un encargo, no solo la base: mandar -> vencer -> RECOGER, y
# mirar si la ability_internal de cada uno ha subido de verdad. Nace del playtest del 23/09/2026:
# "recogi los encargos, fui al altar y ninguno tenia excelia pendiente; le subio 0 en todo".
#
# dev_encargos_rework.gd ya imprimia la excelia BASE y sale sana (47-60 por persona en 8 h), asi que
# el cero tiene que estar despues: o en el reto -- Game.ganar multiplica por el, y un reto 0 anula la
# ganancia entera -- o en el reparto, donde una entrada sin dueño se descarta en silencio.
#
# Imprime por personaje la subida real, y con desglose_excelia el reparto base x reto x dimin.
extends Node

# [etiqueta, stat de las cinco habilidades, piso]
const CASOS := [
	["flojo (100) en piso 1", 100.0, 1],
	["bueno (450) en piso 1", 450.0, 1],
	["flojo (100) en piso 6", 100.0, 6],
	["bueno (450) en piso 6", 450.0, 6],
	["tope (999) en piso 1", 999.0, 1],
]
const HORAS := 8
const ABILS := ["fuerza", "resistencia", "destreza", "agilidad", "magia"]

var _fallos := 0


func _ready() -> void:
	for caso in CASOS:
		_caso(String(caso[0]), float(caso[1]), int(caso[2]))
	_dueno()
	print("")
	if _fallos > 0:
		print("!! %d caso(s) no dieron NADA de excelia" % _fallos)
	else:
		print("OK: en todos los casos el encargo enseña algo")
	get_tree().quit(1 if _fallos > 0 else 0)


# EL FALLO DEL 23/09: las entradas salian SIN dueño. En solitario daba igual (el personaje esta en tu
# plantilla), pero en un mundo compartido lo resuelve la SALA, que no tiene a nadie en la suya: sin
# dueño no sabe a quien mandarsela y la excelia se perdia. partes_de si lo apuntaba; excelia_de no.
func _dueno() -> void:
	print("")
	print("=== CADA ENTRADA CON SU DUEÑO (el fallo del mundo compartido) ===")
	var pjs: Array = []
	var miembros: Array = []
	for i in 2:
		var pj := PersonajeData.new()
		pj.uid = "uid_%d" % i
		pj.nombre = "Sim%d" % i
		for s in ABILS:
			pj.ability_internal[s] = 100.0
			pj.ability_consolidado[s] = 100.0
		pjs.append(pj)
		miembros.append({"uid": pj.uid, "dueno": "jugador_%d" % i, "faenas": [], "clase": 0})
	var trabajo := {"uid_0": {Encargos.Grupo.MINERAL: 10}, "uid_1": {Encargos.Grupo.MINERAL: 10}}
	var entradas: Array = Encargos.excelia_de(pjs, 1, 5, trabajo, {}, {}, Encargos.EXITO, miembros)
	var sin_dueno: int = 0
	for g in entradas:
		if String((g as Dictionary).get("dueno", "")) != "jugador_" + String((g as Dictionary)["uid"]).substr(4):
			sin_dueno += 1
	print("  %d entradas, %d sin su dueño" % [entradas.size(), sin_dueno])
	if entradas.is_empty() or sin_dueno > 0:
		_fallos += 1


func _caso(etiqueta: String, stat: float, piso: int) -> void:
	# Partida limpia por caso: un solo personaje en la plantilla y FUERA del equipo (quien va en el
	# equipo no puede irse de encargo).
	Game.encargos.clear()
	Game.cofre_equipo.clear()
	Game.party.clear()
	Game.plantilla.clear()
	var pj := PersonajeData.new()
	pj.uid = "sim_%s_%d" % [str(int(stat)), piso]
	pj.nombre = "Sim"
	for s in ABILS:
		pj.ability_internal[s] = stat
		pj.ability_consolidado[s] = stat
		pj.ability_base_nivel[s] = stat
	Game.plantilla.append(pj)

	var antes: Dictionary = {}
	for s in ABILS:
		antes[s] = float(pj.ability_internal[s])

	var id: int = Game.enviar_encargo(piso, {Encargos.Grupo.MINERAL: 100}, HORAS * 3600, [pj.uid], [])
	if id == 0:
		print("  %-24s NO SALE: %s" % [etiqueta, Game.motivo_encargo])
		_fallos += 1
		return
	# Que venza ya: se le atrasa el arranque mas que su duracion.
	var e: Dictionary = Game.encargo_por_id(id)
	e["t_inicio"] = Encargos.ahora() - HORAS * 3600 - 60
	Game.repasar_encargos()
	Game.desglose_excelia = true
	var inf: Dictionary = Game.recoger_encargo(id)
	Game.desglose_excelia = false

	var total: float = 0.0
	var linea: String = ""
	for s in ABILS:
		var sube: float = float(pj.ability_internal[s]) - float(antes[s])
		total += sube
		if sube > 0.0:
			linea += "  %s +%.2f" % [s.substr(0, 3), sube]
	# 'materiales' y no 'trabajadas': el informe que devuelve recoger_encargo trae lo que ENTRA en el
	# almacen (ver Game, "var informe"), no las tiradas de trabajo, que se quedan en el encargo.
	print("  %-24s %s, %d materiales ->%s" % [etiqueta,
		Encargos.NOMBRE_DESENLACE[int(inf.get("desenlace", 0))], int(inf.get("materiales", 0)),
		linea if linea != "" else "  NADA (0 en todo)"])
	if total <= 0.0:
		_fallos += 1
