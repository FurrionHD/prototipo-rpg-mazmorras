# PRUEBA (24/11, el jefe): LOS DOS MOVIMIENTOS DEL ARBOL DE LA DAGA, en una pelea tactica de verdad en su sala.
#   - ENTRAR BAILANDO (Rafaga, AbilityData.acercarse): con el enemigo FUERA del cono de siempre, apuntando a el, la
#     huella sale de donde acabas tras acercarte y le pilla; al lanzarla te acercas (sin pasarte de lo que da) y le pegas.
#   - ESCABULLIRSE (Desaparecer, AbilityData.se_mueve): DOS CLICS al lanzarla, primero el golpe y luego el sitio. El
#     primero no la lanza; el clic derecho vuelve al primero; el segundo la lanza y, acabados los golpes, te vas hacia el
#     sitio elegido sin pasar de lo que da. El sitio viaja con el apunte (apunte_para_red: cuatro numeros).
#   godot --headless --path . res://tools/prueba_moverse_daga.tscn
extends Node

const PASO := 60.0
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
	if not await sala.arrancar("prueba_moverse_daga", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(-220, 70), {})
	await _esperar(25)
	if not (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var yo: Combatant = combat._player
	var e: Combatant = combat._enemies[0]
	for c in combat._aliados + [e]:
		c.max_hp = 999999.0
		c.current_hp = 999999.0
		c.current_energy = 99999.0
		c.max_energy = 99999.0
	# Los demas de los tuyos, lejos: que no tapen el sitio.
	var ar = t._arena()
	var centro: Vector2 = ar.rect.get_center()
	var lado := Vector2.LEFT if t._en_arena(centro + Vector2(-200, 0)) else Vector2.RIGHT
	for i in combat._aliados.size():
		var o: Combatant = combat._aliados[i]
		if o != yo:
			t._colocar(o, t.cuerpo_de(o), centro - lado * 150.0 + Vector2(0, -60 + 50 * i) - Vector2(0, PoseJugador.PIES_BAJO_NODO))

	# --- 1) ENTRAR BAILANDO
	print("--- Entrar bailando (Rafaga)")
	var raf: AbilityData = (load("res://resources/abilities/rafaga.tres") as AbilityData).duplicate()
	raf.acercarse = 0.0
	t._colocar(yo, t.cuerpo_de(yo), centro - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	# el enemigo a ~90 px de hueco: fuera del cono de siempre (59 px), dentro con el paso de 60
	var pe: Vector2 = centro + lado * (90.0 + t.radio_pisa(yo) + t.radio_pisa(e))
	t._colocar(e, t.cuerpo_de(e), pe - (t.pies_de(e) - t.pos_de(e)))
	await _esperar(3)
	t.anotar_apunte([t.pies_de(e).x, t.pies_de(e).y])
	_ver(t.reparto_habilidad(raf, yo).is_empty(), "sin Entrar bailando no le llega")
	raf.acercarse = PASO
	var pilla: Array = t.reparto_habilidad(raf, yo)
	_ver(pilla.size() == 1 and pilla[0]["c"] == e, "con Entrar bailando la huella le pilla (sale de donde acabas)")
	var desde: Vector2 = t.pies_de(yo)
	var vida0: float = e.current_hp
	combat._state = combat.State.WAITING_PLAYER
	t._terminar()
	t.anotar_apunte([t.pies_de(e).x, t.pies_de(e).y])
	combat.habilidades._usar_habilidad(raf, true)
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 6.0)
	await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 6.0)
	var anda: float = t.pies_de(yo).distance_to(desde)
	print("    se ha acercado %.1f px (tope %.0f); vida del enemigo %.0f -> %.0f" % [anda, PASO, vida0, e.current_hp])
	_ver(anda > 20.0 and anda <= PASO + 1.0, "se acerca, sin pasar de lo que da")
	_ver((t.pies_de(yo) - desde).dot(lado) > 0.0, "se acerca HACIA el objetivo")
	_ver(e.current_hp < vida0, "y le pega")

	# --- 2) ESCABULLIRSE
	print("--- Escabullirse (Desaparecer)")
	await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0)
	yo = combat._player
	yo.current_energy = 99999.0
	var des: AbilityData = (load("res://resources/abilities/desaparecer.tres") as AbilityData).duplicate()
	des.se_mueve = PASO
	des.cooldown = 0
	t._colocar(yo, t.cuerpo_de(yo), centro - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	t._colocar(e, t.cuerpo_de(e), centro + lado * (t.radio_pisa(yo) + t.radio_pisa(e) + 10.0) - (t.pies_de(e) - t.pos_de(e)))
	await _esperar(3)
	desde = t.pies_de(yo)
	vida0 = e.current_hp
	var g0: int = combat._fx._cola.size() if combat._fx != null else 0
	t.apuntar(des)
	t.raton_simulado = t.pies_de(e)
	t._confirmar_apunte()
	_ver(t.esta_apuntando() and t._eligiendo_retirada, "el primer clic NO la lanza: pide el sitio")
	_ver(t._arena().huellas.has(t.CLAVE_RETIRADA), "se ve hasta donde puedes retirarte")
	# clic derecho: vuelve al primero
	t._cancelar_apunte()
	_ver(t.esta_apuntando() and not t._eligiendo_retirada and not t._arena().huellas.has(t.CLAVE_RETIRADA),
		"el clic derecho vuelve al primer clic")
	t._confirmar_apunte()
	# el sitio: 150 px hacia el otro lado (lejos: se queda en 60)
	var sitio: Vector2 = desde - lado * 150.0
	t.raton_simulado = sitio
	t._refrescar_apunte(sitio)
	_ver(t._arena().huellas.has(t.CLAVE_RETIRADA_SITIO), "se ve donde acabarias")
	t._confirmar_apunte()
	t.raton_simulado = null
	_ver(not t.esta_apuntando(), "el segundo clic la lanza")
	var red: Array = t.apunte_para_red()
	_ver(red.size() == 4 and is_equal_approx(float(red[2]), sitio.x), "el sitio viaja con el apunte (%s)" % str(red))
	# DESAPARECER SE PREPARA (sale al volver a llegar a la barra): la pelea sigue de verdad; los demas de los tuyos se
	# defienden en su turno, y el sitio tiene que seguir ahi cuando salga (guardar_carga / recuperar_carga).
	var t0: int = Time.get_ticks_msec()
	while yo.charging != null and Time.get_ticks_msec() - t0 < 40000:
		if t._fase == t.Fase.MOVIENDO and combat._player != yo and combat._state == combat.State.WAITING_PLAYER:
			combat._accion_defender()
		await get_tree().process_frame
	_ver(yo.charging == null, "sale al volver a la barra")
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 6.0)
	await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 6.0)
	anda = t.pies_de(yo).distance_to(desde)
	print("    se ha ido %.1f px (tope %.0f); vida del enemigo %.0f -> %.0f" % [anda, PASO, vida0, e.current_hp])
	_ver(e.current_hp < vida0, "la puñalada entra")
	_ver(anda > 20.0 and anda <= PASO + 1.0, "se escabulle, sin pasar de lo que da")
	_ver((t.pies_de(yo) - desde).dot(-lado) > 0.0, "hacia el sitio elegido")

	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
