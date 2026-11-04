# HERRAMIENTA (CON VENTANA). La lamina del ESCUDO DE AGUA del set Marea (09/10) para su visto bueno: el personaje en la
# pelea tactica con la burbuja llena, a la mitad, casi rota, al encajar un golpe, al parar un Lento y reventando.
#   ESCUDO_SALIDA=C:/Users/dasui/Desktop/ataques_mapa/escudo_agua godot --path . res://tools/lamina_escudo_agua.tscn
# Saca una foto por momento (01_lleno.png ...) y la hoja entera (hoja.png, 3 x 3, en ese orden), ampliadas x2.
extends Node



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


const CELDA := Vector2i(200, 240)
const AMPLIA := 2
var _salida: String = ""
var _fotos: Array = []


func _foto(nombre: String, centro_mundo: Vector2) -> void:
	# (por la sala la camara no sigue a la pelea: se le pone delante de la burbuja)
	var cam: Camera2D = get_tree().root.get_viewport().get_camera_2d()
	if cam == null:
		cam = Camera2D.new()
		cam.zoom = Vector2(3, 3)
		get_tree().root.add_child(cam)
		cam.make_current()
	cam.global_position = centro_mundo
	cam.reset_smoothing()
	print("[camara] ", cam.get_path(), " zoom ", cam.zoom, " en ", centro_mundo)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	var xf: Transform2D = get_tree().root.get_viewport().get_canvas_transform()
	var c: Vector2 = xf * centro_mundo
	var rec := Rect2i(Vector2i(int(c.x) - CELDA.x / 2, int(c.y) - CELDA.y / 2), CELDA)
	rec = rec.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var trozo: Image = img.get_region(rec)
	trozo.resize(trozo.get_width() * AMPLIA, trozo.get_height() * AMPLIA, Image.INTERPOLATE_NEAREST)
	trozo.save_png("%s/%s.png" % [_salida, nombre])
	_fotos.append(trozo)
	print("[foto] ", nombre)


func _correr() -> void:
	_salida = OS.get_environment("ESCUDO_SALIDA")
	if _salida == "":
		_salida = "user://escudo_agua"
	DirAccess.make_dir_recursive_absolute(_salida)
	# (04/11) Jugar solo va siempre por la SALA: la arena se abre como en las pruebas (prueba_sala_propia); el camino
	# viejo (entrar_arena_de_pruebas + pedir_spawn_arena) se pedia la arena a si mismo por red y se quedaba en el pueblo.
	var sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("lamina_escudo_agua", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(160, 0))
	await _esperar(25)
	var combat: Node = await sala.pelear()
	if combat == null:
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(40)
	combat.set_process(false)
	var tm = combat.turno_mapa
	var al: Combatant = combat._aliados[0]
	al.runa_escudo_max = 40.0
	al.runa_escudo_agua = 40.0
	al.invulnerable = true   # que el golpe de prueba no le baje la vida (el escudo se gasta igual: va antes)
	# EL DEL ESCUDO EN MEDIO (09/10, su peticion): uno de los suyos justo DETRAS (arriba en pantalla) y otro DELANTE
	# (abajo), pegados, para ver que la burbuja tapa al de detras y la tapa el de delante.
	var cu0: Node2D = tm.cuerpo_de(al)
	var otros: Array = []
	for k in range(1, combat._aliados.size()):
		var cuk: Node2D = tm.cuerpo_de(combat._aliados[k])
		if cuk != null:
			otros.append([combat._aliados[k], cuk])
	if otros.size() >= 2:
		for par in [[otros[0], Vector2(6, -26)], [otros[1], Vector2(-6, 26)]]:
			var cuo: Node2D = par[0][1]
			cuo.global_position = cu0.global_position + par[1]
			tm._pos[par[0][0]] = cuo.global_position
		await _esperar(5)
	tm.pintar_escudos_agua()
	var cu: Node2D = tm.cuerpo_de(al)
	var b: EscudoAgua = EscudoAgua.de(cu)
	var centro: Vector2 = cu.global_position + b._caja.get_center()   # el centro de la burbuja
	await _esperar(20)
	await _foto("01_lleno", centro)
	al.runa_escudo_agua = 20.0
	b._visto = 20.0
	await _esperar(10)
	await _foto("02_a_la_mitad", centro)
	al.runa_escudo_agua = 5.0
	b._visto = 5.0
	await _esperar(10)
	await _foto("03_casi_roto", centro)
	al.runa_escudo_agua = 30.0
	b._visto = 30.0
	await _esperar(10)
	al.runa_escudo_agua = 22.0
	await _esperar(5)
	await _foto("04_encaja_un_golpe", centro)
	await _esperar(30)
	al.apply_status(StatusEffects.Id.LENTO)
	await _esperar(4)
	await _foto("05_para_un_lento", centro)
	await _esperar(40)
	al.runa_escudo_agua = 0.0
	await _esperar(3)
	await _foto("06_revienta_1", centro)
	await _esperar(9)
	await _foto("07_revienta_2", centro)
	await _esperar(12)
	await _foto("08_revienta_3", centro)
	await _esperar(30)
	await _foto("09_sin_escudo", centro)
	var w: int = CELDA.x * AMPLIA
	var h: int = CELDA.y * AMPLIA
	var hoja := Image.create(w * 3, h * 3, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0.1, 0.1, 0.12))
	for k in _fotos.size():
		var f: Image = _fotos[k]
		f.convert(Image.FORMAT_RGBA8)
		hoja.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % 3) * w, (k / 3) * h))
	hoja.save_png("%s/hoja.png" % _salida)
	print("[foto] hoja.png -> ", _salida)
	get_tree().quit(0)
