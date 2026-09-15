# PRUEBA (headless, como escena porque necesita los autoloads):
#   godot --headless --path . res://tools/prueba_roster_duplicados.tscn
#
# El encargo que "no se mandaba": un personaje tuyo con una COPIA RANCIA en un JugadorData viejo de
# otra identidad tuya (ver identity.gd), y esa copia "en su equipo". Antes el roster lo repetia y la
# aduana del host se quedaba con la copia y rechazaba el envio en silencio.
# No toca ninguna partida: sin ranura ni mundo abierto no se guarda nada.
extends Node

const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")
var _fallos := 0


func _ok(cond: bool, que: String) -> void:
	print("  %s  %s" % ["ok " if cond else "MAL", que])
	if not cond:
		_fallos += 1


func _ready() -> void:
	Perfil.ranura_actual = 0
	Mundos.abierto = ""
	PartidaDePrueba.llenar()
	Game.asegurar_uids()
	# Uno a casa: es el que se va a mandar.
	var libre: PersonajeData = null
	for pj in Game.party.duplicate():
		if pj != Game.lider():
			libre = pj
			Game.sacar_del_equipo(pj)
			break
	_ok(libre != null, "hay alguien libre en casa")

	# LA COPIA RANCIA: la misma persona (mismo uid) en el JugadorData de una identidad vieja, en su equipo.
	var jd := JugadorData.new()
	jd.id = "cba95693eba7728cd210c82a"
	jd.nombre_visible = "dasui"
	var copia: PersonajeData = libre.duplicate(true) as PersonajeData
	copia.uid = libre.uid
	jd.personajes.append(copia)
	jd.equipo.append(copia)
	Game.jugadores_mundo[jd.id] = jd
	Net.activo = true
	Net.es_host = true

	var veces: int = 0
	for f in Net.hogar._construir_roster():
		if String(f.get("uid", "")) == String(libre.uid):
			veces += 1
			_ok(not bool(f.get("en_equipo", true)), "la fila que queda es la buena (en casa, no 'en su equipo')")
	_ok(veces == 1, "el personaje sale UNA vez en el roster (sale %d)" % veces)

	var motivo: String = Net.hogar.solicitar_encargo(1, {0: 100}, 3600, [String(libre.uid)], [])
	_ok(motivo.is_empty(), "el encargo sale (motivo: '%s')" % motivo)
	_ok(Game.uid_de_encargo(String(libre.uid)) != 0, "y queda apuntado como de encargo")

	# Y si NO puede salir, se sabe por que.
	var otra: String = Net.hogar.solicitar_encargo(1, {0: 100}, 3600, [String(libre.uid)], [])
	_ok(otra.contains("encargo"), "mandarlo otra vez dice por que no ('%s')" % otra)
	var lider_va: String = Net.hogar.solicitar_encargo(1, {0: 100}, 3600, [String(Game.lider().uid)], [])
	_ok(not lider_va.is_empty(), "mandar al que va en el equipo dice por que no ('%s')" % lider_va)

	Net.activo = false
	Net.es_host = false
	print("FIN, %d fallo(s)" % _fallos)
	get_tree().quit(1 if _fallos > 0 else 0)
