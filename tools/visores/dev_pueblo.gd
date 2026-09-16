# ============================================================
#  dev_pueblo.gd  --  HERRAMIENTA, no parte del juego.
#
#  Monta el PUEBLO de verdad (scenes/levels/town.tscn, construido desde PuebloPlano) y comprueba lo que
#  la fase 1 del pueblo visual promete:
#    - ninguna casa pisa una calle, la muralla, el agua u otra casa (el pescador, la madera);
#    - cada oficio tiene UNA puerta interactuable, y su casilla se puede pisar;
#    - todas las puertas se alcanzan andando desde donde apareces;
#    - pulsar F en cada puerta abre un menu.
#
#  DOS MODOS: --headless solo comprueba; con ventana (herramientas/ver_pueblo.bat) saca ademas
#  capturas en tools/salida/pueblo_*.png: el pueblo entero y un primer plano de cada puerta.
#  Devuelve codigo != 0 si algo falla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PUEBLO := "res://scenes/levels/town.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

var _fallos: int = 0
var _hechas: int = 0
var _con_ventana: bool = DisplayServer.get_name() != "headless"
var _pueblo: Node2D = null
var _jugador: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _con_ventana:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	# EL PUEBLO DE MENTIRA: Game.en_pueblo() y door.gd miran la ruta de la escena actual.
	get_tree().current_scene.scene_file_path = PUEBLO
	_pueblo = (load(PUEBLO) as PackedScene).instantiate() as Node2D
	add_child(_pueblo)
	_jugador = _pueblo.get_node("Player") as Node2D
	await get_tree().process_frame
	await get_tree().process_frame

	_plano()
	_puertas()
	await _menus()
	if _con_ventana:
		await _capturas()

	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _plano() -> void:
	print("=== EL PLANO ===")
	var ocupadas := {}
	for casa in PuebloPlano.CASAS:
		var r: Rect2i = casa["rect"]
		var clave: String = casa["clave"]
		var suelo_ok: int = PuebloPlano.Suelo.MADERA if clave == "pescador" else PuebloPlano.Suelo.HIERBA
		var mal: Array = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if PuebloPlano.suelo(c) != suelo_ok or ocupadas.has(c) or PuebloPlano.es_verja(c):
					mal.append(c)
				ocupadas[c] = clave
		_ok("%s en %s no pisa nada" % [clave, r], mal.is_empty())
		if not String(casa.get("script", "")).is_empty():
			var p: Vector2i = PuebloPlano.puerta_de(casa)
			_ok("  su puerta %s se puede pisar" % p, not PuebloPlano.solida(p))
	_ok("la escalera cae en la plaza", PuebloPlano.PLAZA.encloses(PuebloPlano.ESCALERA))
	_ok("apareces en un sitio libre", not PuebloPlano.solida(_celda(PuebloPlano.aparicion_px())))


func _puertas() -> void:
	print("\n=== LAS PUERTAS ===")
	var alcanzables: Dictionary = _alcanzables(_celda(PuebloPlano.aparicion_px()))
	var nodos: Array = get_tree().get_nodes_in_group("interactable")
	for casa in PuebloPlano.CASAS:
		if String(casa.get("script", "")).is_empty():
			continue
		var p: Vector2i = PuebloPlano.puerta_de(casa)
		var px: Vector2 = PuebloPlano.centro_px(p)
		var cerca: int = nodos.filter(func(n): return (n as Node2D).global_position.distance_to(px) < 24.0).size()
		_ok("%s: una puerta interactuable (%d)" % [casa["clave"], cerca], cerca == 1)
		_ok("  y se llega andando", alcanzables.has(p))
	_ok("la escalera es la salida a la mazmorra", get_tree().get_nodes_in_group("salida_pueblo").size() == 1)
	_ok("se llega al altar", alcanzables.has(PuebloPlano.ALTAR + Vector2i(0, 1)))
	_ok("hay 12 interactuables (10 oficios + altar + escalera)", nodos.size() == 12)


# F sobre cada puerta de oficio: tiene que aparecer algo que antes no se veia.
func _menus() -> void:
	print("\n=== F EN CADA PUERTA ===")
	for casa in PuebloPlano.CASAS:
		if String(casa.get("script", "")).is_empty():
			continue
		var puerta: Node = _pueblo.get_node("Casa_%s/Puerta" % casa["clave"])
		# Todo menu de oficio se apunta en Game.abrir_menu al abrirse (es lo que pausa el mundo).
		Game.inventory_open = false
		puerta.interact_with_player()
		await get_tree().process_frame
		await get_tree().process_frame
		_ok("%s abre su menú" % casa["clave"], Game.inventory_open)
		Game.cerrar_menus_abiertos()
		get_tree().paused = false
		await get_tree().process_frame


func _capturas() -> void:
	var cam: Camera2D = _jugador.get_node("Camera2D") as Camera2D
	var tam: Vector2 = PuebloPlano.tam_px()
	# El pueblo ENTERO: sin limites y con el zoom que hace falta para que quepa.
	cam.position_smoothing_enabled = false
	var limites := [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	var z: float = minf(1280.0 / tam.x, 720.0 / tam.y)
	cam.zoom = Vector2(z, z)
	_jugador.global_position = tam * 0.5
	await _captura("entero")
	cam.limit_left = limites[0]
	cam.limit_top = limites[1]
	cam.limit_right = limites[2]
	cam.limit_bottom = limites[3]
	cam.zoom = Vector2(1.8, 1.8)
	for casa in PuebloPlano.CASAS:
		if String(casa.get("script", "")).is_empty():
			continue
		_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.puerta_de(casa)) + Vector2(0, 6)
		await _captura(String(casa["clave"]))
	_jugador.global_position = PuebloPlano.aparicion_px()
	await _captura("plaza")
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.ALTAR + Vector2i(0, 2))
	await _captura("altar")
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(PuebloPlano.MUELLE.position.x + 1, PuebloPlano.MUELLE.position.y + 1))
	await _captura("muelle")


func _captura(nombre: String) -> void:
	await get_tree().process_frame
	(_jugador.get_node("Camera2D") as Camera2D).reset_smoothing()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%spueblo_%s.png" % [SALIDA, nombre])


func _celda(px: Vector2) -> Vector2i:
	return Vector2i((px / float(PuebloPlano.CELDA)).floor())


func _alcanzables(desde: Vector2i) -> Dictionary:
	var vistas := {desde: true}
	var cola: Array[Vector2i] = [desde]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if PuebloPlano.dentro(n) and not vistas.has(n) and not PuebloPlano.solida(n):
				vistas[n] = true
				cola.append(n)
	return vistas


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
