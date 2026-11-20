# HERRAMIENTA (CON VENTANA). EL CAZADOR LUNAR EN UNA PELEA DE VERDAD QUE SE JUEGA SOLA (20/11, el jefe: "me puedes mostrar
# los ataques sin que lo tenga que jugar yo?"). Arena de pruebas, tus cuatro quietos y duros, el Cazador rapido y con
# vida de sobra. Cada turno suyo hace el siguiente de la lista (Media luna, Marca, Caida, Salto, basico), con un cartel
# arriba que dice cual y en que fase esta la luna. Las fotos (VER_FOTOS=carpeta, 4 por segundo) son para revisarlo yo.
#   PRUEBA_MUTANTE=cazador godot --path . res://tools/ver_cazador.tscn       (VER_MUT=sombra para la Sombra sin rostro)
extends Node

var T_MAX_MS: int = int(OS.get_environment("VER_MS")) if OS.get_environment("VER_MS") != "" else 240000
const PASOS := [&"media_luna", &"marca_luna", &"caida_luna", &"salto", &""]
const NOMBRE := {&"media_luna": "Media luna", &"marca_luna": "Marca de la luna", &"caida_luna": "Caída de la luna",
	&"salto": "Salto", &"": "Ataque básico"}
const FASES := ["Luna nueva", "Luna creciente", "Luna llena", "Luna menguante"]

var _combat: Node = null
var _tm = null
var _caz: Combatant = null
var _cartel: Label = null
var _fotos: String = ""
var _n_foto: int = 0
var _t0: int = 0
var _habs: Dictionary = {}
var _vp: SubViewport = null
var _quien_antes: Combatant = null
var _recorte: String = ""   # VER_RECORTE=carpeta: fotos ampliadas del acechador NORMAL (los pixeles que se cuelan)
var _n_rec: int = 0


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


func _correr() -> void:
	_fotos = OS.get_environment("VER_FOTOS")
	_recorte = OS.get_environment("VER_RECORTE")
	if _recorte != "":
		DirAccess.make_dir_recursive_absolute(_recorte)
	if _fotos != "":
		DirAccess.make_dir_recursive_absolute(_fotos)
	var mut: String = OS.get_environment("VER_MUT") if OS.get_environment("VER_MUT") != "" else "cazador"
	# como prueba_mut_acechador: su propia sala en la arena (sin red de por medio)
	var sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("ver_cazador", Game.PISO_ARENA):
		print("[ver] no arranca la sala")
		return
	# LA SALA PINTA EL PISO EN SU SubViewport (servidor_pisos: cada piso en su mundo) y no se ve: a la ventana
	var vp: SubViewport = sala.piso.get_parent() as SubViewport
	if vp != null:
		vp.size = get_tree().root.size
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var fondo := CanvasLayer.new()
		fondo.layer = 110
		get_tree().root.add_child(fondo)
		var tr := TextureRect.new()
		tr.texture = vp.get_texture()
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_SCALE
		fondo.add_child(tr)
		_vp = vp
	# VER_MUT=tres (20/11, el jefe: "sus 3 formas en un godot"): el normal, la Sombra sin rostro y el Cazador lunar juntos
	if mut == "tres":
		sala.poner("res://scenes/actors/enemy/acechador.tres", Vector2(150, -50), {})
		sala.poner("res://scenes/actors/enemy/acechador.tres", Vector2(190, 40), {"mutacion": "sombra"})
		sala.poner("res://scenes/actors/enemy/acechador.tres", Vector2(150, 130), {"mutacion": "cazador"})
	else:
		sala.poner("res://scenes/actors/enemy/acechador.tres", Vector2(170, 40), {"mutacion": mut})
	await _esperar(20)
	if (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)) == null:
		print("[ver] no se abrio la pelea")
		return
	await _esperar(5)
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					_combat = h
	if _combat == null:
		print("[ver] no encuentro la pelea")
		return
	_tm = _combat.turno_mapa
	_caz = _combat._enemies[0]
	for e in _combat._enemies:
		if e.mutacion == &"cazador" or e.mutacion == StringName(mut):
			_caz = e
	for e in _combat._enemies:
		e.prob_habilidad = 1.0
		e.max_hp = 999999.0
		e.current_hp = 999999.0
		if e != _caz:
			e.dummy_speed_override = 120.0
	Cargando.ocultar()
	print("[ver] contra %s (mutacion %s)" % [_caz.nombre, _caz.mutacion])
	for ab in _caz.habilidades:
		for k in PASOS:
			if k != &"" and String(ab.resource_path).ends_with("acechador_%s.tres" % k):
				_habs[k] = ab
	_caz.prob_habilidad = 1.0
	_caz.dummy_speed_override = 250.0
	_caz.max_hp = 999999.0
	_caz.current_hp = 999999.0
	for al in _combat._aliados:
		al.dummy_speed_override = 60.0
		al.max_hp = 999999.0
		al.current_hp = 999999.0
	var capa := CanvasLayer.new()
	capa.layer = 120
	get_tree().root.add_child(capa)
	_cartel = Label.new()
	_cartel.add_theme_font_size_override("font_size", 26)
	_cartel.add_theme_color_override("font_outline_color", Color.BLACK)
	_cartel.add_theme_constant_override("outline_size", 8)
	_cartel.position = Vector2(24, 16)
	capa.add_child(_cartel)
	_t0 = Time.get_ticks_msec()
	var todas: Array = _caz.habilidades.duplicate()
	while Time.get_ticks_msec() - _t0 < T_MAX_MS and is_instance_valid(_caz) and _caz.is_alive():
		# EL SIGUIENTE DE LA LISTA: el que toca en su proximo turno (mientras carga la Caida, esa)
		var paso: StringName = PASOS[maxi(_caz.turnos_luna, 0) % PASOS.size()]
		if _caz.charging == null:
			_caz.habilidades = [_habs[paso]] if _habs.has(paso) else []
			_caz.ability_cooldowns.clear()
		var hace: String = _caz.charging.nombre + " (cargando)" if _caz.charging != null else NOMBRE[paso]
		_cartel.text = "%s  ·  próximo: %s  ·  Paciencia %d/%d%s" % [FASES[clampi(_caz.fase_luna, 0, 3)] if _caz.fase_luna >= 0
			else "—", hace, _caz.paciencia_carga, _caz.paciencia_turnos, "  ·  escondido" if _caz.en_sombras() else ""]
		for e in _combat._enemies:
			e.current_hp = 999999.0
		for al in _combat._aliados:
			al.current_hp = al.max_hp
		# TUS TURNOS PASAN SOLOS
		if int(_combat._state) == 1 and _tm._fase == _tm.Fase.MOVIENDO and Engine.get_process_frames() % 20 == 0:
			_combat._accion_esperar()
		# QUIEN PEGA Y DESDE DONDE (20/11: "la sombra pega sin hueco"): al acabar de andar, su hueco a la presa mas cercana
		var q: Combatant = _tm._quien
		if _quien_antes != null and q != _quien_antes and _combat._enemies.has(_quien_antes) and _quien_antes.is_alive():
			var mejor: float = INF
			for al in _combat._aliados:
				mejor = minf(mejor, _tm.hueco_entre(_quien_antes, al))
			print("[ver] %s (%s) actua a %.1f px de hueco de su presa mas cercana; su alcance %.1f; escondido %s" % [
				_quien_antes.nombre, _quien_antes.mutacion, mejor, _tm.alcance_de(_quien_antes), _quien_antes.en_sombras()])
		_quien_antes = q
		await RenderingServer.frame_post_draw
		if _recorte != "" and _vp != null and Engine.get_frames_drawn() % 3 == 0:
			for e in _combat._enemies:
				if e.mutacion == &"" and _tm.cuerpo_de(e) != null:
					var cu: Node2D = _tm.cuerpo_de(e)
					var en: Vector2 = cu.get_global_transform_with_canvas().origin
					var img2: Image = _vp.get_texture().get_image()
					var r := Rect2i(Vector2i(en) - Vector2i(110, 150), Vector2i(220, 220)).intersection(
						Rect2i(Vector2i.ZERO, img2.get_size()))
					if r.size.x > 10 and r.size.y > 10:
						img2.get_region(r).save_png("%s/r_%04d_%s.png" % [_recorte, _n_rec, String(cu.get("_anim_actual"))])
						_n_rec += 1
		if _fotos != "" and Engine.get_frames_drawn() % 15 == 0:
			var img: Image = (_vp.get_texture() if _vp != null else get_tree().root.get_viewport().get_texture()).get_image()
			img.resize(img.get_width() / 2, img.get_height() / 2)
			img.save_png("%s/f_%04d.png" % [_fotos, _n_foto])
			print("[foto] f_%04d a los %d ms" % [_n_foto, Time.get_ticks_msec() - _t0])
			_n_foto += 1
		await get_tree().process_frame
	_caz.habilidades = todas
	print("[ver] FIN")
	if OS.get_environment("VER_SALIR") != "":
		get_tree().quit(0)
