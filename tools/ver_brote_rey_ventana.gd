# HERRAMIENTA (CON VENTANA). El Brote del Rey Slime en una pelea DE VERDAD (09/10, idea suya para ver la 16): el Rey muy
# rapido y tu personaje casi quieto, la pelea corriendo sola. Va grabando; cuando el Rey escupe crias guarda los
# fotogramas de un poco antes a un poco despues (hoja_N.png, 4 x 3) y el rastro de cada cria en la consola.
#   VER_SALIDA=C:/Users/dasui/Desktop/ataques_mapa/brote_rey_pelea godot --path . res://tools/ver_brote_rey_ventana.tscn
extends Node

const CELDA := Vector2i(600, 420)
const ANTES := 4        # fotogramas guardados de antes del escupitajo (cada 3)
const DESPUES := 26     # y de despues (~1,6 s: vuelo, caida y crecer)
const MAX_BROTES := 2
const T_MAX_MS := 40000

var _salida: String = ""
var _combat: Node = null
var _tm = null
var _rey: Combatant = null
var _anillo: Array = []          # [img, ms, centro]
var _grabando: int = -1          # fotogramas que faltan por guardar tras un escupitajo (-1 = nada)
var _fotos: Array = []
var _brotes: int = 0
var _t0: int = 0
var _crias_rastro: Dictionary = {}


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
	_salida = OS.get_environment("VER_SALIDA")
	if _salida == "":
		_salida = "user://brote_rey_pelea"
	DirAccess.make_dir_recursive_absolute(_salida)
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/rey_slime.tres", jug.global_position + Vector2(150, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	Game.start_combat([nodo], false)
	await _esperar(20)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					_combat = h
	_tm = _combat.turno_mapa
	_rey = _combat._enemies[0]
	# El Rey MUY rapido y los tuyos casi quietos (y duros, que aguanten): el Rey hace muchos turnos seguidos.
	_rey.dummy_speed_override = 400.0
	for al in _combat._aliados:
		al.dummy_speed_override = 1.0
		al.max_hp = 999999.0
		al.current_hp = 999999.0
	_combat._fx.dibujo_en_mapa.connect(_on_dibujo)
	_t0 = Time.get_ticks_msec()
	print("[ver] pelea abierta: Rey rapido, tu lento. Esperando Brotes...")
	while Time.get_ticks_msec() - _t0 < T_MAX_MS and _brotes < MAX_BROTES:
		await RenderingServer.frame_post_draw
		_grabar()
		await get_tree().process_frame
	while _grabando > 0:
		await RenderingServer.frame_post_draw
		_grabar()
		await get_tree().process_frame
	_cerrar_hoja()
	for c in _crias_rastro.keys():
		print("[cria] %s: %s" % [(c as Combatant).nombre, " | ".join(_crias_rastro[c])])
	print("[ver] FIN: %d brotes vistos -> %s" % [_brotes, ProjectSettings.globalize_path(_salida)])
	get_tree().quit(0)


var _centro_fijo = null   # al escupir: entre el Rey y donde caen sus crias

func _centro() -> Vector2:
	if _combat == null or _combat._aliados.is_empty():
		return Vector2.ZERO
	if _centro_fijo != null:
		return _centro_fijo
	return (_tm.pies_de(_rey) + _tm.pies_de(_combat._aliados[0])) * 0.5 + Vector2(0, -20)


var _par: int = 0

func _grabar() -> void:
	_par += 1
	# El rastro de las crias, cada fotograma: pies, cuanto sube el dibujo, si se ve.
	for c in _combat._enemies:
		if c == _rey or not (c as Combatant).is_alive():
			continue
		var cu: Node2D = _tm.cuerpo_de(c)
		if cu == null:
			continue
		if not _crias_rastro.has(c):
			_crias_rastro[c] = []
		var sp = cu.get("_sprite")
		var l: Array = _crias_rastro[c]
		if l.size() < 60 and _par % 3 == 0:
			l.append("%dms %s h%.0f %s" % [Time.get_ticks_msec() - _t0, str(cu.global_position.round()),
				-(sp as Node2D).position.y if sp is Node2D else 0.0, "V" if cu.is_visible_in_tree() else "oculta"])
	if _par % 3 != 0:
		return
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	var xf: Transform2D = get_tree().root.get_viewport().get_canvas_transform()
	var c: Vector2 = xf * _centro()
	var rec := Rect2i(Vector2i(int(c.x) - CELDA.x / 2, int(c.y) - CELDA.y / 2), CELDA)
	rec = rec.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	if rec.size.x <= 0 or rec.size.y <= 0:
		return
	var trozo: Image = img.get_region(rec)
	if _grabando > 0:
		_fotos.append(trozo)
		_grabando -= 1
		if _grabando == 0:
			_cerrar_hoja()
	else:
		_anillo.append(trozo)
		if _anillo.size() > ANTES:
			_anillo.pop_front()


func _on_dibujo(ev: Dictionary, vuelo: float) -> void:
	if int(ev.get("estilo", 0)) != CombatFX.Estilo.CRIA_LANZADA or _grabando > 0:
		return
	print("[ver] el Rey escupe a los %d ms (vuelo %.2f)" % [Time.get_ticks_msec() - _t0, vuelo])
	var suma: Vector2 = _tm.pies_de(_rey)
	var n: int = 1
	for d in _tm._deslices:
		if bool(d.get("cria", false)):
			suma += Vector2(d["hasta"])
			n += 1
	_centro_fijo = suma / float(n) + Vector2(0, -20)
	_fotos = _anillo.duplicate()
	_anillo.clear()
	_grabando = DESPUES


func _cerrar_hoja() -> void:
	if _fotos.is_empty():
		return
	_brotes += 1
	var w: int = CELDA.x
	var h: int = CELDA.y
	var hoja := Image.create(w * 5, h * 6, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0.1, 0.1, 0.12))
	for k in mini(_fotos.size(), 30):
		var f: Image = _fotos[k]
		f.convert(Image.FORMAT_RGBA8)
		hoja.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % 5) * w, (k / 5) * h))
	hoja.save_png("%s/hoja_%d.png" % [_salida, _brotes])
	print("[foto] hoja_%d.png (%d fotos, la %d es el escupitajo)" % [_brotes, _fotos.size(), ANTES + 1])
	_fotos.clear()
	_centro_fijo = null
