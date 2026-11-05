# LOS FALLOS DEL .EXE DEL 03/11 (playtest del 04/11), con el jugador y su sala de verdad: la pelea va en ESPEJO, que es donde
# salian los tres de pintar.
#   1) los puntos de las arañas solo en quien tiene cargas; el Tocon y el set Ambar llevan los suyos, en ambar
#   2) el estado viaja: la rata en las sombras no se ve en el espejo (ni cuerpo ni ficha) y vuelve al salir
#   3) la capa de ambar y el escudo de agua se rompen al tocar el golpe, no al resolverlo
#   4) la ficha va centrada en el dibujo, no en el origen de la lona
#   5) huir de un enemigo herido: Continuar sale en seguida (se quedaba 6 s esperando a una barra que nunca "llegaba")
#   godot --headless --path . res://tools/prueba_playtest_exe_04_11.tscn -- nube_local
extends Node

var j = null
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


func _ms(n: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < n:
		await get_tree().process_frame


# Espera a que me toque elegir en el mapa.
func _mi_turno(p: Node) -> bool:
	var t = p.turno_mapa
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		if int(p.get("_state")) == 1 and t._fase == t.Fase.MOVIENDO and t._quien != null and is_instance_valid(t._cuerpo):
			return true
		await get_tree().process_frame
	return false


func _puntos_unit() -> void:
	print("1) los puntos, solo en quien los usa")
	var jab: EnemyData = load("res://scenes/actors/enemy/jabali.tres")
	var rata: EnemyData = load("res://scenes/actors/enemy/rata.tres")
	var ara: EnemyData = load("res://scenes/actors/enemy/arana.tres")
	var c_jab: Combatant = jab.crear_combatant(0.5, true, false, &"colmillo", 5)
	var c_rat: Combatant = rata.crear_combatant(0.5, true, false, &"sombria", 5)
	var c_ara: Combatant = ara.crear_combatant(0.5, true, false, &"tejedora", 5)
	_ver(c_jab.carga_tope == 0, "el Colmillo de cristal no tiene contador (%d)" % c_jab.carga_tope)
	_ver(c_rat.carga_tope == 0, "la Rata sombria tampoco (%d)" % c_rat.carga_tope)
	_ver(c_ara.carga_tope == 4, "la Tejedora si (%d)" % c_ara.carga_tope)


func _centrado_unit(p: Node) -> void:
	print("4) la ficha, centrada en el dibujo")
	var jab: EnemyData = load("res://scenes/actors/enemy/jabali.tres")
	var sf: SpriteFrames = SpritesEnemigo.frames_de(jab, 0.5, true, &"colmillo")
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	add_child(spr)
	var movidos: int = 0
	for an in sf.get_animation_names():
		if String(an).begins_with("idle"):
			spr.animation = an
			var at := sf.get_frame_texture(an, 0) as AtlasTexture
			var esperado: Vector2 = at.margin.position + at.region.size * 0.5 - at.get_size() * 0.5
			var v: Vector2 = p.figuras_mapa._centro_pose(spr)
			if not v.is_equal_approx(esperado):
				_ver(false, "%s: %s en vez de %s" % [an, str(v), str(esperado)])
			if absf(v.x) >= 2.0:
				movidos += 1
	_ver(movidos >= 2, "las poses de lado llevan su correccion (%d con >= 2 unidades)" % movidos)
	spr.queue_free()


func _sombras(p: Node) -> void:
	print("2) los estados viajan: las sombras en el espejo")
	var e: Combatant = p._enemies[0]
	var fila: Array = p.espejo._valores(p._enemies)[0]
	_ver(fila.size() > 13, "la instantanea lleva los estados")
	var nueva: Array = fila.duplicate()
	nueva[13] = [[StatusEffects.Id.EN_SOMBRAS, 999, 1]]
	p.espejo._volcar(p._enemies, [nueva])
	_ver(e.en_sombras(), "el maniqui esta en las sombras")
	await _esperar(3)
	var cu: Node2D = p.turno_mapa.cuerpo_de(e)
	_ver(cu != null and not cu.visible, "su cuerpo no se ve en el espejo")
	var col: Control = p._bloques[0].get("columna")
	_ver(not col.visible, "ni su ficha")
	var sin: Array = fila.duplicate()
	sin[13] = []
	p.espejo._volcar(p._enemies, [sin])
	await _esperar(3)
	_ver(not e.en_sombras() and cu.visible and col.visible, "al salir vuelve todo")


func _capas(p: Node) -> void:
	print("3) las capas se rompen al tocar el golpe")
	var e: Combatant = p._enemies[0]
	var b: Dictionary = p._bloques[0]
	e.costra_max = 50.0
	e.costra = 50.0
	await _esperar(2)
	_ver(is_equal_approx(e.costra_vista(), 50.0), "se ve entera")
	# Llega la instantanea con la capa rota, ANTES que el paquete de los golpes.
	e.costra = 0.0
	await _esperar(5)
	_ver(is_equal_approx(e.costra_vista(), 50.0), "resuelto y sin golpe a la vista: sigue entera")
	# Llega el golpe.
	p._fx.encolar(b, b, 5.0, false, false, Color.WHITE)
	p._fx.arrancar_cola()
	await _esperar(1)
	_ver(p._fx.impacto_pendiente(b) and is_equal_approx(e.costra_vista(), 50.0), "el golpe va de camino: sigue entera")
	var t0: int = Time.get_ticks_msec()
	while p._fx.impacto_pendiente(b) and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
	await _esperar(2)
	_ver(e.costra_vista() <= 0.0, "ha tocado: rota")
	# Si el golpe no llegara nunca, no se queda colgada.
	e.costra = 50.0
	await _esperar(2)
	e.costra = 0.0
	await _ms(1700)
	_ver(e.costra_vista() <= 0.0, "sin golpe que llegue, se rompe pasado el margen")
	e.costra_max = 0.0

	print("   y el escudo de agua y la vida de los tuyos")
	var al: Combatant = p._aliados[0]
	var ba: Dictionary = p._bloques_aliados[0]
	al.runa_escudo_max = 40.0
	al.runa_escudo_agua = 40.0
	await _esperar(2)
	al.runa_escudo_agua = 0.0
	p._fx.encolar(b, ba, 5.0, false, false, Color.WHITE)
	p._fx.arrancar_cola()
	await _esperar(1)
	_ver(is_equal_approx(al.agua_vista(), 40.0), "el escudo sigue hasta que toca")
	t0 = Time.get_ticks_msec()
	while p._fx.impacto_pendiente(ba) and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().process_frame
	await _esperar(2)
	_ver(al.agua_vista() <= 0.0, "y revienta al tocar")
	al.runa_escudo_max = 0.0

	print("   los puntos del set Ambar")
	al.costra_max = 30.0
	al.costra = 30.0
	al.costra_turnos = 3
	await _esperar(3)
	var n = p.turno_mapa._trent._puntos.get(al)
	_ver(n != null and int(n._nivel) == 3 and int(n._tope) == 3, "con la capa, enteros (3 de 3)")   # (el contador en pixel: _nivel/_tope)
	al.costra = 0.0
	al.costra_espera = 2
	await _ms(1700)
	_ver(n != null and int(n._nivel) == 1, "rota y a 2 turnos de volver: 1 de 3 (%d)" % int(n._nivel if n != null else -1))
	al.costra_max = 0.0
	await _esperar(3)
	_ver(not p.turno_mapa._trent._puntos.has(al), "sin el set no hay puntos")


func _huir(p: Node) -> void:
	print("5) huir de un enemigo herido")
	var t = p.turno_mapa
	var fin_ms: int = -1
	var espera: int = -1
	var t0: int = Time.get_ticks_msec()
	while Net.peleas.espejando() and Time.get_ticks_msec() - t0 < 90000:
		var ahora: int = Time.get_ticks_msec()
		if int(p.get("_state")) == int(p.State.FINISHED):
			if fin_ms < 0:
				fin_ms = ahora
			if (p._continue_button as Button).visible:
				espera = ahora - fin_ms
				(p._continue_button as Button).pressed.emit()
				break
		elif int(p.get("_state")) == 1 and t._fase == t.Fase.MOVIENDO and t._quien != null and is_instance_valid(t._cuerpo):
			var herido := false
			for e in p._enemies:
				if e.current_hp < e.max_hp:
					herido = true
			if herido:
				j.huir()
			elif not (j.pulsar(0) or j.pulsar(3)):
				j.pulsar(5)
		await get_tree().process_frame
	# Queda animacion del ultimo golpe, pero no el tope de 6 s de la barra que no llega.
	# (05/11) < 5800 y no < 5000: lo que se mira es que NO agote el tope; con el banco cargado (3 a la vez) la animacion del
	# ultimo golpe llego a 5121 ms.
	_ver(espera >= 0 and espera < 5800, "Continuar sale sin agotar el tope (%d ms, tope 6000)" % espera)
	var q: bool = true
	for bl in p._bloques:
		var bar = bl.get("hp")
		if bar is ProgressBar and bl.has("hp_meta") and not p._fx._barra_llego(bar, float(bl["hp_meta"])):
			q = false
	_ver(q, "las barras han llegado aunque la vida lleve decimales")
	await j._hasta(func(): return not Game.hay_pelea_en_pantalla() and not Net.peleas.espejando(), 10.0)


func _correr() -> void:
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_playtest_exe_04_11", 74):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return
	_puntos_unit()
	var nodo: Node2D = await j.poner("res://scenes/actors/enemy/slime.tres", Vector2(90, 0), {})
	var combat: Node = await j.pelear(nodo) if nodo != null else null
	if combat == null:
		print("MAL: no se abre la pelea")
		await j.cerrar()
		get_tree().quit(1)
		return
	_ver(await _mi_turno(combat), "me toca")
	_centrado_unit(combat)
	await _sombras(combat)
	await _capas(combat)
	await _huir(combat)
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	await j.cerrar()
	get_tree().quit(1 if _mal > 0 else 0)
