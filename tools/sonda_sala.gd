# SONDA DE LA SALA, SOLO PARA PRUEBAS (fase 2, 20/10, todo por la sala, paso 6). Las pruebas town_* ya no son el
# anfitrion: entran como un cliente mas. Lo que antes miraban dentro del anfitrion (en que piso esta cada uno, quien
# lleva cada piso, las peleas, las fotos...) lo apunta la sala en su registro con lineas
#   [S] dato <clave>=<valor>
# cada vez que cambia, y la prueba las lee de alli. La pone sala.gd si se lanza con la palabra "sonda".
extends Node

const CADA := 0.25

var _visto: Dictionary = {}
# LA VUELTA DESDE LA FOTO (etapa 2): la ultima foto de cada piso (sus sitios) y los pisos montados que ya se han mirado.
var _ultima_foto: Dictionary = {}
var _montados_mirados: Dictionary = {}
var _t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[S] sonda puesta")


func _process(delta: float) -> void:
	if delta > 0.2:
		print("[S] tiron de %d ms (a los %d ms)" % [int(delta * 1000.0), Time.get_ticks_msec()])
	_mirar_vuelta_desde_foto()
	_leer_orden()
	_t += delta
	if _t < CADA:
		return
	_t = 0.0
	var d := _datos()
	for clave in d:
		var v: String = str(d[clave])
		if not _visto.has(clave) or String(_visto[clave]) != v:
			_visto[clave] = v
			print("[S] dato %s=%s" % [clave, v])


func _datos() -> Dictionary:
	var d := {}
	var humanos := 0
	for peer in Net._peers:
		humanos += 1
		var ident: String = Net._identidad_de_peer(peer)
		if ident != "":
			d["peer_" + ident] = peer
			d["piso_" + ident] = Net.pisos._piso_de(peer)
	d["humanos"] = humanos
	for piso in Net._dueno_piso:
		d["dueno_piso_%d" % int(piso)] = int(Net._dueno_piso[piso])
	# LOS PISOS DE LA SALA (etapa 2): cuales tiene montados, cuantos enemigos lleva cada uno y cuantos trae la foto de
	# los congelados.
	if Net.servidor != null:
		d["montados"] = _lista(Net.servidor.pisos())
		for piso in Net.servidor.pisos():
			var n := 0
			for id in Net.enemigos._enemigos:
				if String(Net.enemigos._enemigos[id]["lugar"]) == "piso:%d" % int(piso):
					n += 1
			d["enem_piso_%d" % int(piso)] = n
	for piso in Net._fotos_piso:
		var en_foto: Array = Net._fotos_piso[piso].get("enemigos", [])
		d["foto_piso_%d" % int(piso)] = en_foto.size()
		# Y donde esta cada uno en la foto ("x:y;x:y", redondeado): con esto se mira que vuelven a SU sitio.
		d["foto_pos_%d" % int(piso)] = ";".join(en_foto.map(func(e): return "%d:%d" % [
			int((e.get("pos", Vector2.ZERO) as Vector2).x), int((e.get("pos", Vector2.ZERO) as Vector2).y)]))
	# LAS FOTOS (Net.fotos): cuantos jugadores me han subido alguna, y las peticiones repetidas (tiene que ser 0: cada
	# maquina pide cada foto UNA vez).
	d["fotos_de"] = Net.fotos._subidas_de.size()
	d["fotos_repetidas"] = Net.fotos.repetidas
	# Y las que van a la partida: personajes de jugadores_mundo con su foto puesta (las fichas solo traen la huella).
	var con_foto := 0
	for ident in Game.jugadores_mundo:
		var jd = Game.jugadores_mundo[ident]
		if jd is JugadorData:
			for pj in (jd as JugadorData).personajes:
				if pj is PersonajeData and not (pj as PersonajeData).imagen.is_empty():
					con_foto += 1
	d["fotos_mundo"] = con_foto
	# A cuantos les manda la sala los cambios del baul (los que lo han pedido: Net.hogar._con_baul).
	d["con_baul"] = Net.hogar._con_baul.size()
	# LAS PELEAS DE LA SALA (etapa 3): cuantas lleva, en que pisos, y cuantos enemigos tiene reservados.
	d["peleas"] = Net.peleas._peleas.size()
	var lugares: Array = []
	for pe in Net.peleas._peleas.values():
		if is_instance_valid(pe):
			lugares.append(pe.piso.lugar if is_instance_valid(pe.piso) else "?")
	d["peleas_lugares"] = _lista(lugares)
	d["reservas"] = Net.peleas._enem_ocupados.size()
	return d


func _lista(a: Array) -> String:
	var s: Array = a.duplicate()
	s.sort()
	return ",".join(s.map(func(x): return str(x)))


# ¿VUELVEN A SU SITIO? En cuanto un piso que estaba congelado se monta y salen sus enemigos (el mismo fotograma, antes de
# que anden), se cuenta cuantos estan donde decia su foto: "[S] dato vuelta_piso_N=en_su_sitio/total". Lo mira la sala
# porque al jugador le llegan despues de cargar su piso, y para entonces ya han andado.
func _mirar_vuelta_desde_foto() -> void:
	for piso in Net._fotos_piso:
		_ultima_foto[int(piso)] = (Net._fotos_piso[piso].get("enemigos", []) as Array).map(
			func(e): return e.get("pos", Vector2.INF))
	if Net.servidor == null:
		return
	for piso in _montados_mirados.keys():
		if not Net.servidor.pisos().has(piso):
			_montados_mirados.erase(piso)
	for piso in Net.servidor.pisos():
		if _montados_mirados.has(piso) or not _ultima_foto.has(int(piso)):
			continue
		var pos: Array = []
		for id in Net.enemigos._enemigos:
			var e: Dictionary = Net.enemigos._enemigos[id]
			if String(e["lugar"]) == "piso:%d" % int(piso) and is_instance_valid(e["nodo"]):
				pos.append((e["nodo"] as Node2D).global_position)
		if pos.is_empty():
			continue   # aun no han salido
		_montados_mirados[piso] = true
		var sitios: Array = _ultima_foto[int(piso)]
		var en_su_sitio := 0
		for p in pos:
			for s in sitios:
				if (p as Vector2).distance_to(s) < 4.0:
					en_su_sitio += 1
					break
		print("[S] dato vuelta_piso_%d=%d/%d" % [int(piso), en_su_sitio, pos.size()])


# ============================================================
#  LAS ORDENES (09/11, prueba_mut_miconido_espejo): lo que en el juego pasa a media pelea por suerte (que caiga uno
#  infectado), la prueba se lo PIDE a la sala, que es quien lleva la pelea, y luego mira en SU espejo lo que ve el jugador.
#  La prueba escribe "<n> <orden> [nombre]" en ORDEN; la sonda la hace una vez y contesta "[S] dato orden_<n>=<resultado>".
# ============================================================
const ORDEN := "user://sonda_orden.txt"
var _orden_hecha := -1


func _leer_orden() -> void:
	if not FileAccess.file_exists(ORDEN):
		return
	var f := FileAccess.open(ORDEN, FileAccess.READ)
	if f == null:
		return
	var partes: PackedStringArray = f.get_as_text().strip_edges().split(" ", false, 2)
	f.close()
	if partes.size() < 2 or int(partes[0]) == _orden_hecha:
		return
	_orden_hecha = int(partes[0])
	var res: String = _hacer_orden(partes[1], partes[2] if partes.size() > 2 else "")
	print("[S] dato orden_%d=%s" % [_orden_hecha, res])


# La pantalla de la (unica) pelea que lleva la sala.
func _pelea() -> Node:
	for pe in Net.peleas._peleas.values():
		if is_instance_valid(pe):
			var p: Node = Net.peleas._pantalla_combate(pe)
			if p != null:
				return p
	return null


func _hacer_orden(orden: String, nombre: String) -> String:
	var p: Node = _pelea()
	if p == null:
		return "sin_pelea"
	match orden:
		"preparar":
			# Que no se acabe sola: todos con muchisima vida.
			for c in p._aliados + p._enemies:
				var cb: Combatant = c
				cb.max_hp = 100000.0
				cb.current_hp = 100000.0
			return "ok"
		"florecer_bicho":
			# Un bicho que no es micónido cae infectado: tiene que levantarse con setas.
			for c in p._enemies:
				var e: Combatant = c
				if e.is_alive() and e.mutacion == &"" and not e.nombre.to_lower().contains("mic"):
					e.apply_status(StatusEffects.Id.INFECTADO)
					e.take_damage(e.current_hp + 10.0)
					p._morir_enemigo(e)
					return "ok:" + e.nombre
			return "sin_bicho"
		"florecer_aliado":
			for c in p._aliados:
				var al: Combatant = c
				if al.nombre == nombre and al.is_alive():
					al.apply_status(StatusEffects.Id.INFECTADO)
					al.take_damage(al.current_hp + 10.0)
					p.altas._caer_aliado(al)
					return "ok"
			return "sin_aliado"
		"tumbar":
			# El personaje florecido (el que usa el muñeco de un caido) cae otra vez.
			for c in p._enemies:
				var e: Combatant = c
				if e.is_alive() and e.nombre == nombre and e.has_status(StatusEffects.Id.FLORECIDO):
					e.take_damage(e.current_hp + 10.0)
					p._morir_enemigo(e)
					return "ok"
			return "sin_florecido"
	return "orden_desconocida"
