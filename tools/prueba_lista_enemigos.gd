# LA LISTA DE ENEMIGOS DEL PANEL DERECHO (B6, playtest 11/10). Pelea en la arena contra el minotauro, una rata y un
# slime: debajo de la ficha del apuntado sale una fila por cada uno de los demas vivos, con su vida; pulsar una fila
# le apunta; y la lista no se mete debajo de la barra de acciones. Con ventana y LISTA_SALIDA=/ruta/base, captura.
#   godot --headless --path . res://tools/prueba_lista_enemigos.tscn -- nube_local
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


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	# EL JUGADOR CON SU SALA (etapa 4, 26/10): el panel lo pinta la maquina del jugador (tools/prueba_con_jugador.gd). Los
	# tres JUNTOS delante de el: como jugador entran en la pelea los que caen en su zona.
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_lista_enemigos", 72):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return
	var nodo: Node2D = await j.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(0, 130), {})
	await j.poner("res://scenes/actors/enemy/rata.tres", Vector2(70, 170), {})
	await j.poner("res://scenes/actors/enemy/slime.tres", Vector2(-70, 170), {})
	# LE PEGO YA, sin los 2 s que da j.pelear por si me embisten (28/10): el minotauro es un guardian A DISTANCIA y se
	# aparta cuando me pego a el, y en ese rato la rata llegaba y embestia; la pelea se abria con ella y el slime, y el
	# minotauro, ya a mas de RADIO_REFUERZO, se quedaba fuera (lo correcto en el juego; la prueba lo dejaba al azar).
	var combat: Node = null
	if nodo != null:
		var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		yo.recolocar(nodo.global_position + Vector2(40, 0))
		nodo.atacado_por_jugador(0.3)
		await j._hasta(func(): return j.pantalla() != null and Net.peleas.espejando(), 10.0)
		combat = j.pantalla()
	if combat == null or not combat.tactico:
		print("MAL: la pelea no se abre o no es tactica")
		await j.cerrar()
		get_tree().quit(1)
		return
	await _esperar_a(func() -> bool: return combat._enemies.size() >= 3, 10.0)
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		await j.cerrar()
		get_tree().quit(1)
		return
	await _esperar(3)
	var ficha = combat.ficha_objetivo
	var apuntado: Combatant = combat._objetivo()
	var otros: Array = combat._enemies.filter(func(e): return e.is_alive() and e != apuntado)
	print("     apuntado %s; en la lista: %s" % [apuntado.nombre, str(ficha._filas.map(func(f): return f["c"].nombre))])
	_ver(otros.size() >= 2, "hay al menos dos mas aparte del apuntado")
	_ver(ficha._filas.size() == otros.size() and ficha._lista_scroll.visible, "una fila por cada uno de los demas")
	var ok_hp: bool = true
	for f in ficha._filas:
		ok_hp = ok_hp and is_equal_approx((f["hp"] as ProgressBar).value, (f["c"] as Combatant).current_hp)
	_ver(ok_hp, "cada fila con su vida")
	var acciones: Control = combat._panel_acciones
	var fondo_lista: float = ficha._lista_scroll.global_position.y + ficha._lista_scroll.size.y
	print("     la lista acaba en %.0f; las acciones empiezan en %.0f" % [fondo_lista, acciones.global_position.y])
	_ver(not acciones.visible or fondo_lista <= acciones.global_position.y, "no se mete debajo de la barra de acciones")
	var salida: String = OS.get_environment("LISTA_SALIDA")
	if salida != "" and DisplayServer.get_name() != "headless":
		await _esperar(20)
		var img: Image = get_tree().root.get_viewport().get_texture().get_image()
		img.save_png(salida + ".png")
		print("     captura: %s.png" % salida)
	# Pulsar la primera fila = apuntarle.
	var otro: Combatant = ficha._filas[0]["c"] if not ficha._filas.is_empty() else null
	if otro != null:
		var clic := InputEventMouseButton.new()
		clic.button_index = MOUSE_BUTTON_LEFT
		clic.pressed = true
		(ficha._lista.get_child(0) as Control).gui_input.emit(clic)
		await _esperar(3)
		_ver(combat._objetivo() == otro, "pulsar su fila le apunta (%s)" % combat._objetivo().nombre)
		_ver(not ficha._filas.any(func(f): return f["c"] == otro) and ficha._filas.any(func(f): return f["c"] == apuntado),
			"y la lista pasa a tener al de antes en su lugar")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	await j.cerrar()
	get_tree().quit(0 if _mal == 0 else 1)
