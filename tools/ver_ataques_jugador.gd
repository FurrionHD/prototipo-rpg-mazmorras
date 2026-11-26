# VER EN DIRECTO TODOS LOS ATAQUES DEL JUGADOR, a su velocidad normal (26/11, el jefe: "muestrame todos los ataques del
# jugador sin excepcion a su velocidad normal para que te diga si alguna es demasiado rapida"). CON VENTANA.
# Una pelea de verdad en la sala de pruebas, todos los tuyos con el mismo equipo y los enemigos quietos; en cada turno, un
# ataque (el basico y luego cada habilidad que da ese equipo), con su nombre en grande arriba. Se cierra sola al acabar.
#   VER_MAIN=estoque VER_OFF=escudo_pequeno godot --path . res://tools/ver_ataques_jugador.tscn
#   VER_OFF: un escudo (escudo_pequeno/normal/grande), varita, o un arma (la misma: dos dagas, dos mazas). Vacio = nada.
#   VER_SOLO=avance_cubierto,embestida  solo esas (y sin el basico)
extends Node

var sala
var combat: Node = null
var t = null
var es: Array = []
var lado := Vector2.LEFT
var centro := Vector2.ZERO
var _rotulo: Label = null
var _cam: Camera2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


var _mira_antes := Vector2.ZERO
var _t_mira: int = 0

func _process(_d: float) -> void:
	if OS.get_environment("VER_MIRA") != "" and combat != null and t != null and combat._player != null:
		var cu = t.cuerpo_de(combat._player)
		if cu != null:
			var f: Vector2 = cu.get("_facing")
			if f.distance_to(_mira_antes) > 0.01:
				print("    [mira] %s a %.2f s (gesto: %s)" % [str(f.snapped(Vector2(0.01, 0.01))),
					(Time.get_ticks_msec() - _t_mira) / 1000.0, str(t._gestos_mapa.has(cu))])
				_mira_antes = f
	if _cam != null and is_instance_valid(_cam):
		_cam.global_position = centro + lado * 30.0 + Vector2(0.0, -14.0)
		_cam.zoom = Vector2(2.0, 2.0)


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _turno() -> Combatant:
	await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 15.0)
	await _esperar_a(func() -> bool: return t._deslices.is_empty(), 8.0)
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 40.0):
		return null
	var yo: Combatant = combat._player
	yo.max_energy = 1000.0
	yo.current_energy = 1000.0
	yo.max_mp = maxf(yo.max_mp, 500.0)
	yo.current_mp = yo.max_mp
	yo.salir_de_guardia()
	yo.statuses.clear()
	yo.ability_cooldowns.clear()
	return yo


func _colocar(yo: Combatant, seps: Array, fuera: Array) -> void:
	t._colocar(yo, t.cuerpo_de(yo), centro - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	var arriba := lado.orthogonal()
	for i in es.size():
		var e: Combatant = es[i]
		var pe: Vector2 = centro + lado * (t.radio_pisa(yo) + t.radio_pisa(e) + float(seps[i])) + arriba * float(fuera[i])
		t._colocar(e, t.cuerpo_de(e), pe - (t.pies_de(e) - t.pos_de(e)))
		e.statuses.clear()
		e.current_hp = e.max_hp
		e.en_guardia = false
	# mirando al primero, como si hubiera llegado andando hacia el (el visor le coloca de golpe)
	if not es.is_empty():
		t.encarar_hacia(yo, t.pies_de(es[0]) - t.pies_de(yo))
	await _esperar(3)


func _pj_items(pj: PersonajeData) -> void:
	var main: String = OS.get_environment("VER_MAIN")
	var off: String = OS.get_environment("VER_OFF")
	pj.equipped_main = load("res://resources/weapons/%s.tres" % main)
	pj.equipped_off = null
	if off == "":
		return
	if off.begins_with("escudo"):
		pj.equipped_off = load("res://resources/shields/%s.tres" % off)
	elif off == "varita":
		pj.equipped_off = load("res://resources/wands/varita.tres")
	else:
		pj.equipped_off = (load("res://resources/weapons/%s.tres" % off) as Resource).duplicate()


func _correr() -> void:
	var main: String = OS.get_environment("VER_MAIN")
	if main == "":
		main = "estoque"
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar(OS.get_environment("VER_SALA") if OS.get_environment("VER_SALA") != "" else "ver_ataques_jugador",
			Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	# (26/11, el jefe) UN SOLO PERSONAJE contra UN SLIME con mucha vida: el grupo se queda en el lider.
	var lider: PersonajeData = Game.lider()
	var solo_uno: Array[PersonajeData] = [lider]
	Game.party = solo_uno
	Game.lider_idx = 0
	_pj_items(lider)
	var sequito = sala.jugador.get("_sequito")
	if sequito != null and is_instance_valid(sequito) and sequito is CanvasItem:
		(sequito as CanvasItem).visible = false
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(-220, 70), {})
	await _esperar(25)
	if not (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(5)
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico or combat._enemies.is_empty():
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	t = combat.turno_mapa
	es = combat._enemies.slice(0, 1)
	for c in combat._aliados + es:
		c.max_hp = 9999999.0
		c.current_hp = 9999999.0
	for e in es:
		e.dummy_speed_override = 0.001   # quietos: que no se metan por medio
	centro = t._arena().rect.get_center()
	lado = Vector2.LEFT if t._en_arena(centro + Vector2(-200, 0)) else Vector2.RIGHT
	for i in combat._aliados.size():
		var o: Combatant = combat._aliados[i]
		t._colocar(o, t.cuerpo_de(o), centro - lado * 160.0 + Vector2(0, -60 + 50 * i) - Vector2(0, PoseJugador.PIES_BAJO_NODO))
	# EL PISO SE PINTA (la sala lo tiene en una SubViewport SIN dibujar, ver servidor_pisos): se enciende y se pone a
	# pantalla completa, o la ventana se queda gris.
	var vp: SubViewport = sala.piso.get_parent() as SubViewport
	if vp != null:
		vp.size = get_viewport().get_visible_rect().size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var fondo := CanvasLayer.new()
		fondo.layer = -10
		add_child(fondo)
		var tr := TextureRect.new()
		tr.texture = vp.get_texture()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		fondo.add_child(tr)
	# LA CAMARA, sobre la pelea (la de la sala se queda en la puerta de la arena) y sin los paneles de pruebas (dev)
	if vp != null:
		var cams: Array = vp.find_children("*", "Camera2D", true, false)
		var cam: Camera2D = null
		for c in cams:
			if (c as Camera2D).is_current():
				cam = c
		if cam == null and not cams.is_empty():
			cam = cams[0]
		if cam != null:
			cam.set_process(false)
			cam.set_physics_process(false)
			cam.position_smoothing_enabled = false
			cam.drag_horizontal_enabled = false
			cam.drag_vertical_enabled = false
			cam.limit_left = -10000000
			cam.limit_top = -10000000
			cam.limit_right = 10000000
			cam.limit_bottom = 10000000
			cam.offset = Vector2.ZERO
			cam.global_position = centro + Vector2(lado.x * 40.0, -10.0)
			cam.make_current()
			_cam = cam
		for n in vp.find_children("*", "", true, false):
			var sc = n.get_script()
			if sc != null and String(sc.resource_path).get_file() in ["spawner.gd", "material_spawner.gd"]:
				if n is CanvasItem:
					(n as CanvasItem).visible = false
				elif n is CanvasLayer:
					(n as CanvasLayer).visible = false
				var padre = n.get_parent()
				if padre is CanvasLayer and padre.get_child_count() == 1:
					(padre as CanvasLayer).visible = false
	# el rotulo
	var capa := CanvasLayer.new()
	capa.layer = 120
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 34)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 8)
	_rotulo.position = Vector2(24, 18)
	capa.add_child(_rotulo)
	# la lista: el basico y lo que da el equipo
	var pool: Array = Game.pool_habilidades(Game.lider())
	var solo: String = OS.get_environment("VER_SOLO")
	var lista: Array = [] if solo != "" else [null]
	for ab in pool:
		var a: AbilityData = ab
		if a.cargar_municion > 0 or a.untar:
			continue   # preparaciones (abren la bolsa): no son ataques
		if solo != "" and not solo.split(",").has(String(a.resource_path).get_file().get_basename()):
			continue
		lista.append(a)
	var arma_txt: String = main + ("" if OS.get_environment("VER_OFF") == "" else " + " + OS.get_environment("VER_OFF"))
	print("== %s: %s" % [arma_txt, ", ".join(lista.map(func(a): return "basico" if a == null else a.nombre))])
	var reloj: Array = [0]
	combat._fx.gesto_iniciado.connect(func(_b, _d, dur, anim, m) -> void:
		print("    gesto %s mano %d a %.2f s (dura %.2f)" % [anim, m, (Time.get_ticks_msec() - int(reloj[0])) / 1000.0, dur]))
	for k in lista.size():
		var ab: AbilityData = lista[k]
		var yo: Combatant = await _turno()
		if yo == null:
			print("MAL: no llego el turno")
			break
		var a_distancia: bool = yo.a_distancia
		await _colocar(yo, [70.0] if a_distancia or (ab != null and ab.carga) else [14.0], [0.0])
		_rotulo.text = "%s   ·   %s   (%d/%d)" % [arma_txt, "Ataque básico" if ab == null else ab.nombre, k + 1, lista.size()]
		await _segundos(0.9)
		combat._state = combat.State.WAITING_PLAYER
		combat._target_idx = combat._enemies.find(es[0])
		var t0: int = Time.get_ticks_msec()
		reloj[0] = t0
		_t_mira = t0
		if ab == null:
			combat._accion_atacar()
		else:
			var punto: Vector2 = t.pies_de(es[0])
			if ab.forma_a_aliados:
				var al: Combatant = combat._aliados[(combat._aliados.find(yo) + 1) % combat._aliados.size()]
				punto = t.pies_de(al)
			t.anotar_apunte([punto.x, punto.y])
			combat.habilidades._usar_habilidad(ab, true)
		if OS.get_environment("VER_FOTO") != "" and k == 0:
			# VER_FOTO=/ruta/pref: fotos a 0,3 / 0,6 / 1,0 / 1,6 / 2,4 s (pref_1.png ...)
			var antes: float = 0.0
			for n_f in [0.3, 0.6, 1.0, 1.6, 2.4].size():
				var cuando: float = [0.3, 0.6, 1.0, 1.6, 2.4][n_f]
				await _segundos(cuando - antes)
				antes = cuando
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("%s_%d.png" % [OS.get_environment("VER_FOTO"), n_f + 1])
		await _esperar(2)
		await _esperar_a(func() -> bool: return combat._fx == null or not combat._fx.ocupado(), 15.0)
		await _esperar_a(func() -> bool: return t._deslices.is_empty(), 8.0)
		print("  %s: %.2f s" % ["basico" if ab == null else ab.nombre, (Time.get_ticks_msec() - t0) / 1000.0])

		await _segundos(1.2)
	print("=== FIN ===")
	get_tree().quit(0)
