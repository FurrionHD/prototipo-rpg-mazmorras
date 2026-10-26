# AL HUIR, EL QUE HUYE PASA A IR EN CABEZA (12/10, lo pidio el jefe: "al huir que se convierta en lider
# automaticamente el que huye, para que se queden en la posicion desde la que sales"). Sin red, en la arena: se abre
# una pelea tactica, huye un COMPAÑERO (no el lider) y al cerrarse la pelea:
#   1) va en cabeza el que huyo;
#   2) el cuerpo que mueves esta donde estaba el (no donde estaba el lider de antes);
#   3) si huye el lider, sigue siendo el lider.
#   godot --headless --path . res://tools/prueba_huida_lider.tscn -- nube_local
extends Node

var j = null   # el jugador con su sala: tools/prueba_con_jugador.gd

var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _pantalla() -> Node:
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return h
	return null


# Abre una pelea contra un slime y hace huir a 'quien' (indice en Game.party). Devuelve donde estaba su cuerpo.
func _huir_con(quien: int) -> Vector2:
	# Como un jugador (etapa 4, 26/10): la pelea la lleva la sala y el dado lo tira ella. En el turno del que tiene que huir
	# se le pone en el borde y se pulsa Huir (el sexto boton, que lejos del borde es Pasar); en los de los demas, Defender.
	var nodo: Node2D = await j.poner("res://scenes/actors/enemy/slime.tres", Vector2(90, 0), {})
	var combat: Node = await j.pelear(nodo) if nodo != null else null
	if combat == null:
		print("MAL: no se abre la pelea")
		return Vector2.INF
	var pj: PersonajeData = Game.party[quien]
	var t = combat.turno_mapa
	var donde: Vector2 = Vector2.INF
	var t0: int = Time.get_ticks_msec()
	while Net.peleas.espejando() and Time.get_ticks_msec() - t0 < 60000:
		var p: Node = j.pantalla()
		if p != null and is_instance_valid(p) and int(p.get("_state")) == 1 and t._fase == t.Fase.MOVIENDO \
				and t._quien != null and is_instance_valid(t._cuerpo):
			if Game.pj_mio_de(t._quien) == pj:
				if j.huir():
					donde = t._cuerpo.global_position   # desde donde huye: el borde
					print("  [dev] turno de %s: pulso Huir desde %s" % [t._quien.nombre, str(donde.round())])
			elif j.pulsar(3) or j.pulsar(0):
				print("  [dev] turno de %s: defiende o ataca" % t._quien.nombre)
		elif p != null and is_instance_valid(p) and int(p.get("_state")) == 1:
			print("  [dev] me toca (estado 1) pero fase %s, quien %s" % [t._fase, t._quien.nombre if t._quien != null else "-"])
		await _esperar(5)
	await j._hasta(func(): return not Game.hay_pelea_en_pantalla() and not Net.peleas.espejando(), 10.0)
	await _esperar(10)
	return donde


func _correr() -> void:
	# EL JUGADOR CON SU SALA (etapa 4, 26/10): la huida la aplica el jugador al cerrar su espejo (tools/prueba_con_jugador.gd).
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_huida_lider", 73):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return
	if Game.party.size() < 2:
		print("MAL: hace falta un grupo de dos o mas")
		await j.cerrar()
		get_tree().quit(1)
		return
	Game.cambiar_lider(0)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	jug.refrescar_lider()
	await _esperar(3)

	print("1) huye un compañero")
	var donde: Vector2 = await _huir_con(1)
	_ver(Game.lider_idx == 1, "va en cabeza el que huyo (%s)" % Game.lider().nombre)
	print("2) desde su sitio")
	if donde != Vector2.INF:
		_ver(jug.global_position.distance_to(donde) < 24.0,
			"el cuerpo que mueves esta donde estaba el (%.0f px)" % jug.global_position.distance_to(donde))
	else:
		print("  (no encuentro su cuerpo en el mapa: me salto la posicion)")

	print("3) huye el lider")
	await _esperar(30)
	await _huir_con(1)
	_ver(Game.lider_idx == 1, "sigue en cabeza el mismo")

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	await j.cerrar()
	get_tree().quit(1 if _mal > 0 else 0)
