# PRUEBA (30/10, playtest del 29/10): LOS ICONOS DE ESTADO SALEN CUANDO EL GOLPE DA. "Los iconos de stun, por ejemplo,
# aparecen antes de que se de el golpe, cuando se empieza a ejecutar; el efecto le entra en el momento en el que golpea
# el arma." En una pelea tactica en la sala, uno de los tuyos golpea al enemigo y le aturde (como al resolver la accion:
# el golpe a la cola y el estado puesto ya):
#   - mientras el golpe no ha aterrizado, el enemigo NO lleva el icono;
#   - en cuanto aterriza, SI.
#   godot --headless --path . res://tools/prueba_iconos_al_golpe.tscn
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


# ¿Lleva el bloque el icono 'icono' entre sus chips?
func _lleva(b: Dictionary, icono: String) -> bool:
	var box: Container = b.get("chips")
	if box == null:
		return false
	for h in box.get_children():
		if not h.is_queued_for_deletion() and h is Button and String((h as Button).text).contains(icono):
			return true
	return false


# ¿Ha aterrizado ya el golpe a 'b'? (mirado en la propia cola, sin la ayuda del arreglo)
func _aterrizado(combat: Node, b: Dictionary) -> bool:
	for ev in combat._fx._cola:
		if is_same(ev["bv"], b) and not bool(ev["lanzado"]):
			return false
	return true


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_iconos_al_golpe", Game.PISO_ARENA):
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
	await _esperar(10)
	var e: Combatant = combat._enemies[0]
	var quien: Combatant = combat._aliados[0]
	e.max_hp = 99999.0
	e.current_hp = 99999.0
	e.status_resist = 0.0
	var b: Dictionary = combat._bloque_de(e)
	var icono: String = String(StatusEffects.def(StatusEffects.Id.ATURDIDO).get("icono", "💫"))
	_ver(not _lleva(b, icono), "antes del golpe no lleva %s" % icono)
	# Como al resolver: el golpe a la cola, el estado puesto y la pantalla refrescada; luego se anima.
	combat.efectos._fx_golpe(quien, e, 5.0, false, false, Elementos.Elemento.NINGUNO, CombatFX.Estilo.MELEE, 1.0)
	e.current_hp -= 5.0
	e.apply_status(StatusEffects.Id.ATURDIDO)
	combat._update_hp()
	combat._fx.arrancar_cola()
	await _esperar(1)
	var antes_de_dar: bool = _lleva(b, icono)
	var aterrizo := false
	var visto_al_aterrizar := false
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		if _aterrizado(combat, b):
			aterrizo = true
			await _esperar(2)
			visto_al_aterrizar = _lleva(b, icono)
			break
		if _lleva(b, icono):
			antes_de_dar = true
		await get_tree().process_frame
	_ver(e.has_status(StatusEffects.Id.ATURDIDO), "el estado esta puesto (lo aplica la resolucion)")
	_ver(not antes_de_dar, "mientras el golpe va de camino NO se ve %s" % icono)
	_ver(aterrizo and visto_al_aterrizar, "al aterrizar el golpe SI se ve %s (%d ms)" % [icono, Time.get_ticks_msec() - t0])
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
