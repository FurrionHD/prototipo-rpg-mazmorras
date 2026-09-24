# AUDITORIA: ¿se pierde algo de un jugador en un mundo compartido con sala?
# Hace el viaje entero SIN RED con la partida de referencia: mi juego empaqueta lo mio
# (mi_jugador_data -> jd_a_dict), la SALA lo apunta dos veces (_mi_estado: jd_de_dict sin registrar ->
# jd_a_dict), y al volver a entrar lo adopto como _tu_jugador (limpiar_mundo_heredado + jd_de_dict +
# aplicar_jugador_mundo). Luego compara CAMPO A CAMPO cada personaje y lo del jugador con lo de antes:
# cualquier campo de PersonajeData o de JugadorData que no viaje sale aqui, tambien los que se añadan.
#   godot --headless --path . res://tools/prueba_viaja_todo.tscn
extends Node

# Campos que NO tienen que viajar, a proposito (cada uno con su porque).
const NO_VIAJAN := {
	"script": "no es un dato",
	"resource_path": "no es un dato", "resource_name": "no es un dato",
	"resource_local_to_scene": "no es un dato", "resource_scene_unique_id": "no es un dato",
	"fecha_visto": "sello de cuando se guardo",
}


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	# Lo que en la partida de referencia esta a su valor por defecto, con algo de verdad: si no, que no
	# viaje no se notaria.
	Game.velocidad_combate = 2.0
	Game.gacha_historial = [{"quien": "Dasui", "nombre": "Prueba", "seccion": "x", "rareza": 2, "pity": 7,
		"cuando": 1790000000}]
	# Lo de antes, normalizado (sin objetos: rutas e identidades), por uid de personaje.
	var antes_pjs: Dictionary = {}
	for pj in Game.plantilla:
		antes_pjs[String(pj.uid)] = _campos(pj)
	var antes_jd: Dictionary = _campos(Game.mi_jugador_data())
	var antes_game: Dictionary = _game()

	# LOS QUE NO SALEN EN EL PAQUETE, valgan lo que valgan (la comparacion de abajo no ve los que en la
	# partida de referencia estan a cero).
	var claves_pj: Dictionary = Net.partida.pj_a_dict(Game.plantilla[0])
	var no_salen: Array = []
	for n in _campos(Game.plantilla[0]):
		if not claves_pj.has(n):
			no_salen.append(n)
	print("CAMPOS DEL PERSONAJE QUE NO VAN EN EL PAQUETE: %s" % ", ".join(no_salen))
	var claves_jd: Dictionary = Net.partida.jd_a_dict(Game.mi_jugador_data())
	var no_salen_jd: Array = []
	for n in _campos(Game.mi_jugador_data()):
		if not claves_jd.has(n):
			no_salen_jd.append(n)
	print("CAMPOS DEL JUGADOR QUE NO VAN EN EL PAQUETE (con su nombre): %s" % ", ".join(no_salen_jd))
	var paquete: Dictionary = Net.partida.jd_a_dict(Game.mi_jugador_data())
	var en_sala: JugadorData = Net.partida.jd_de_dict(paquete, false)
	en_sala = Net.partida.jd_de_dict(Net.partida.jd_a_dict(en_sala), false)
	var vuelta: Dictionary = Net.partida.jd_a_dict(en_sala)
	Game.limpiar_mundo_heredado()
	Game.aplicar_jugador_mundo(Net.partida.jd_de_dict(vuelta, true), Game.semilla_mundo)

	var fallos: int = 0
	print("--- PERSONAJES (%d) ---" % antes_pjs.size())
	var vistos: Dictionary = {}
	for pj in Game.plantilla:
		var uid: String = String(pj.uid)
		vistos[uid] = true
		if not antes_pjs.has(uid):
			print("MAL: aparece un personaje que no estaba: %s (%s)" % [pj.nombre, uid])
			fallos += 1
			continue
		fallos += _comparar("%s" % pj.nombre, antes_pjs[uid], _campos(pj))
	for uid in antes_pjs:
		if not vistos.has(uid):
			print("MAL: se ha perdido un personaje (uid %s)" % uid)
			fallos += 1
	print("--- JUGADOR ---")
	fallos += _comparar("JugadorData", antes_jd, _campos(Game.mi_jugador_data()))
	print("--- LO SUYO EN GAME ---")
	fallos += _comparar("Game", antes_game, _game())
	print("=== %s ===" % ("TODO VIAJA" if fallos == 0 else "%d CAMPOS SE PIERDEN O CAMBIAN" % fallos))
	get_tree().quit(1 if fallos > 0 else 0)


# Lo de la PERSONA que vive suelto en Game (no en los personajes) y que tiene que sobrevivir a entrar.
func _game() -> Dictionary:
	var d: Dictionary = {}
	for c in ["money", "crystals", "materiales", "carbon", "consumables", "cebo_activo", "lampara_llama",
			"lampara_llama_total", "owned_mochilas", "mochila_equipo", "owned_tools", "equipped_pico",
			"equipped_hoz", "equipped_hacha", "equipped_cana", "equipped_lampara", "equipped_cuchillo",
			"registro_pesca", "materiales_vistos", "pack_inicial_reclamado", "lider_idx", "party",
			"owned_weapons", "owned_armor", "velocidad_combate", "gacha_historial"]:
		d[c] = _norm(Game.get(c))
	return d


func _campos(o: Object) -> Dictionary:
	var d: Dictionary = {}
	for p in o.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		var n: String = String(p["name"])
		if NO_VIAJAN.has(n) or n.begins_with("_"):
			continue
		if n == "equip_meta" and o is PersonajeData:
			d[n] = _norm(_equip_meta_real(o as PersonajeData))
			continue
		d[n] = _norm(o.get(n))
	return d


# La meta del equipo SIN RUIDO: fuera las ranuras vacias (su meta no describe nada) y los valores por
# defecto que unas piezas apuntan y otras no (banda 0, durabilidad 1.0): no son datos que se pierdan.
func _equip_meta_real(pj: PersonajeData) -> Dictionary:
	var out: Dictionary = {}
	for slot in pj.equip_meta:
		if pj.get("equipped_" + String(slot)) == null:
			continue
		var m: Dictionary = (pj.equip_meta[slot] as Dictionary).duplicate(true)
		if int(m.get("banda", 0)) == 0:
			m.erase("banda")
		if is_equal_approx(float(m.get("durabilidad", 1.0)), 1.0):
			m.erase("durabilidad")
		out[slot] = m
	return out


func _comparar(quien: String, a: Dictionary, b: Dictionary) -> int:
	var f: int = 0
	for k in a:
		if not b.has(k):
			print("MAL %s.%s: no existe despues" % [quien, k])
			f += 1
		elif str(a[k]) != str(b[k]):
			var sa: String = str(a[k])
			var sb: String = str(b[k])
			# Desde donde empiezan a diferir, para que se vea QUE cambia y no los 300 primeros iguales.
			var i: int = 0
			while i < mini(sa.length(), sb.length()) and sa[i] == sb[i]:
				i += 1
			var desde: int = maxi(0, i - 60)
			print("MAL %s.%s (difiere en el caracter %d):\n     antes:   ...%s\n     despues: ...%s" % [
				quien, k, i, sa.substr(desde, 240), sb.substr(desde, 240)])
			f += 1
	return f


# Sin objetos: un Resource de equipo por su identidad, uno de fichero por su ruta, un personaje por su
# uid; arrays ordenados si son de identidades (el orden del baul no importa), floats redondeados.
func _norm(v, hondo: int = 0):
	if hondo > 6:
		return "..."
	if v is PersonajeData:
		return "pj:" + String((v as PersonajeData).uid)
	if v is Resource:
		var r: Resource = v
		if r.resource_path != "" and not r.resource_path.contains("::"):
			return r.resource_path
		var s: Dictionary = Game.serializar_equipo(r)
		if not s.is_empty():
			s.erase("desc")
			return JSON.stringify(s, "", true)
		return "<%s sin ruta>" % r.get_class()
	if v is float:
		return snappedf(v, 0.0001)
	if v is Array:
		var out: Array = []
		for x in v:
			out.append(str(_norm(x, hondo + 1)))
		if not out.is_empty() and (v as Array)[0] is Resource and not ((v as Array)[0] is PersonajeData):
			out.sort()
		return out
	if v is Dictionary:
		var claves: Array = []
		for k in v:
			claves.append([str(_norm(k, hondo + 1)), str(_norm(v[k], hondo + 1))])
		claves.sort()
		return claves
	return v
