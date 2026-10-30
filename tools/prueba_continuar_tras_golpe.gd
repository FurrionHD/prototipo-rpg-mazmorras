# PRUEBA (30/10, playtest del 29/10): EL "CONTINUAR" SALE CUANDO SE HA VISTO EL ULTIMO GOLPE. "El juego ya sabe cuando has
# matado al enemigo y finaliza el combate: te sale el continuar antes de que siquiera veas la animacion del golpe ni le
# baje la barra de vida." En una pelea tactica en la sala, uno de los tuyos remata al enemigo con un golpe de verdad
# (con su animacion en la cola de efectos) y se acaba la pelea:
#   - el boton NO esta mientras la cola anima el golpe ni mientras la barra de vida baja;
#   - y SI sale despues (sin quedarse colgado).
#   godot --headless --path . res://tools/prueba_continuar_tras_golpe.tscn
extends Node

var sala
var _mal := 0


func _ready() -> void:
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
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_continuar_tras_golpe", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(70, 0), {})
	await _esperar(25)
	var combat: Node = await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)
	if combat == null:
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var e: Combatant = combat._enemies[0]
	var quien: Combatant = combat._aliados[0]
	# El golpe mortal, como lo resuelve la pelea: a la cola de efectos (con su animacion) y a la vida; y se acaba.
	await _esperar(10)
	var vida0: float = e.current_hp
	e.current_hp = 0.0
	combat.efectos._fx_golpe(quien, e, vida0, false, false, Elementos.Elemento.NINGUNO, CombatFX.Estilo.MELEE, 1.0)
	combat._update_hp()
	combat._end(true)
	await get_tree().process_frame
	var hubo_cola: bool = combat._fx != null and (combat._fx.ocupado() or not combat._fx.barras_quietas())
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 8000 and not combat._continue_button.visible:
		await get_tree().process_frame
	var tardo: int = Time.get_ticks_msec() - t0
	# En el fotograma en que sale el boton, ¿seguia animandose el golpe o bajando la barra?
	var visto_mientras: bool = combat._fx != null and (combat._fx.ocupado() or not combat._fx.barras_quietas())
	_ver(hubo_cola, "el golpe mortal se anima (cola ocupada o barra bajando tras acabar la pelea)")
	_ver(not visto_mientras, "el Continuar no sale mientras se anima el golpe ni mientras baja la barra")
	_ver(combat._continue_button.visible and not combat._continue_button.disabled,
		"y sale despues, pulsable (a los %d ms)" % tardo)
	combat._on_continue_pressed()
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
