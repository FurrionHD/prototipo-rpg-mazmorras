# LA PANTALLA DE CARGA DEL PISO (08/10, playtest: "la primera vez que me metia en el piso 6 daba un lagazo; que haya una
# pantalla de carga que cargue primero el piso entero y luego ya me deje moverme"). Sin ventana Cargando no hace nada,
# asi que aqui se fuerza (forzar_sin_ventana). Entra al piso 6 por la puerta, y baja al 7 por la escalera: en los dos
# la capa tiene que estar puesta, y TU QUIETO (su modal), mientras se monta, y quitarse sola soltandote. Y las hojas de
# los enemigos del piso no se sueltan al acabar de montarlo.
# Desde la etapa 4 (26/10) es el JUGADOR con su sala (tools/prueba_con_jugador.gd), como se baja de verdad: la puerta y la
# escalera piden el piso a la sala. En multi la pantalla no pausa el arbol (el mundo es de todos): te para su modal.
# (Lo que era el 3, las listas que comparten los enemigos, es de la sala: tools/prueba_listas_enemigos.gd.)
#   godot --headless --path . res://tools/prueba_carga_piso.tscn -- nube_local
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


# Espera a que la capa se vaya, mirando que mientras esta sigas QUIETO (con su modal puesto). Devuelve los fotogramas.
func _mientras_tapa(tope: int) -> int:
	var n: int = 0
	var siempre_quieto: bool = true
	while Cargando.visible_ahora() and n < tope:
		if not Game.hay_modal():
			siempre_quieto = false
		await get_tree().process_frame
		n += 1
	_ver(siempre_quieto, "mientras se ve la pantalla, estas QUIETO (su modal)")
	return n


# Espera a que se ponga la pantalla (la pide la respuesta de la sala, que tarda un viaje).
func _hasta_que_tapa(tope: int) -> bool:
	var n: int = 0
	while not Cargando.visible_ahora() and n < tope:
		await get_tree().process_frame
		n += 1
	return Cargando.visible_ahora()


func _correr() -> void:
	Cargando.forzar_sin_ventana = true
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_carga_piso", 74, 0):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return

	print("1) entrar al piso 6 (la puerta)")
	Net.pisos.solicitar_entrar(6)
	_ver(await _hasta_que_tapa(600), "se pone la pantalla")
	_ver(Game.hay_modal(), "y te deja quieto")
	var n: int = await _mientras_tapa(2000)
	_ver(not Cargando.visible_ahora(), "se quita sola (%d fotogramas)" % n)
	_ver(not Game.hay_modal(), "y te suelta")
	_ver(get_tree().get_first_node_in_group("dungeon_floor") != null and Net._mi_lugar == "piso:6", "el piso 6 esta montado")

	print("2) bajar al piso 7 por la escalera")
	Net.pisos.solicitar_piso(7, false)   # lo que pide la escalera (stairs.gd)
	_ver(await _hasta_que_tapa(600), "al bajar se pone")
	n = await _mientras_tapa(2000)
	_ver(not Cargando.visible_ahora() and not Game.hay_modal(), "y se quita sola (%d fotogramas)" % n)
	_ver(Game.current_floor == 7 and Net._mi_lugar == "piso:7", "estamos en el piso 7")

	print("3) las hojas de los enemigos del piso no se sueltan al acabar de montarlo")
	# precalentar las cargaba y Game._soltar_hojas_sin_usar (que corre DESPUES de montarse el piso) las soltaba en el acto
	# porque aun no las llevaba ningun bicho: cada bajada las pagaba dos veces (19/10). SpritesEnemigo._del_piso las sujeta.
	Game._soltar_hojas_sin_usar()
	var sujetas: Array = SpritesEnemigo._del_piso
	var siguen: int = 0
	for sf in sujetas:
		if SpritesEnemigo._horneado.values().has(sf):
			siguen += 1
	_ver(sujetas.size() > 0 and siguen == sujetas.size(), "tras la limpieza siguen las %d hojas del piso (%d)" % [sujetas.size(), siguen])

	await j.cerrar()
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
