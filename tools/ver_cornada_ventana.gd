# HERRAMIENTA (CON VENTANA). La Cornada del Minotauro en una pelea DE VERDAD (10/10, el playtest del 09/10: "no se
# desplaza con la embestida", "la hace instant", "primero se agacha... y luego embiste y cuando termina ya se levanta").
# El Minotauro muy rapido y solo con la Cornada; los tuyos casi quietos y duros. La 1a la suelta con los tuyos en la
# linea; para la 2a se apartan mientras carga (asi se ve que embiste igual sin nadie). Cada Cornada se guarda en una
# hoja (hoja_N.png, 5 por fila, de que empieza a cargar a que se levanta), y la ventana se queda abierta para mirarla.
#   VER_SALIDA=C:/Users/dasui/Desktop/ataques_mapa/enemigos/minotauro/cornada_recorre godot --path . res://tools/ver_cornada_ventana.tscn
extends Node

const CELDA := Vector2i(520, 400)
const MAX_CORNADAS := 2
const T_MAX_MS := 60000
const TRAS_LEVANTARSE_MS := 500

var _salida: String = ""
var _combat: Node = null
var _tm = null
var _mino: Combatant = null
var _cor: AbilityData = null
var _fotos: Array = []
var _grabando: bool = false
var _centro_fijo: Vector2 = Vector2.ZERO
var _fin_ms: int = -1
var _cornadas: int = 0
var _apartados: bool = false
var _t0: int = 0
var _par: int = 0


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
		_salida = "user://cornada_recorre"
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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/guardian_rango.tres", jug.global_position + Vector2(-220, 70), {})
	await _esperar(25)
	Game.start_combat(get_tree().get_nodes_in_group("enemy"), false)
	await _esperar(20)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					_combat = h
	_tm = _combat.turno_mapa
	_mino = _combat._enemies[0]
	_cor = load("res://resources/abilities/minotauro_cornada.tres")
	# SOLO LA CORNADA, siempre lista y siempre la elige. Rapido el, lentos y duros los tuyos.
	_mino.habilidades = [_cor]
	_mino.prob_habilidad = 1.0
	_mino.dummy_speed_override = 300.0
	_mino.max_hp = 999999.0
	_mino.current_hp = 999999.0
	for al in _combat._aliados:
		al.dummy_speed_override = 1.0
		al.max_hp = 999999.0
		al.current_hp = 999999.0
	_t0 = Time.get_ticks_msec()
	print("[ver] pelea abierta: el Minotauro solo hace la Cornada. Esperando %d..." % MAX_CORNADAS)
	while Time.get_ticks_msec() - _t0 < T_MAX_MS and _cornadas < MAX_CORNADAS:
		_mino.ability_cooldowns.clear()
		await RenderingServer.frame_post_draw
		_grabar()
		await get_tree().process_frame
	print("[ver] FIN: %d Cornadas -> %s (la ventana sigue abierta: cierrala cuando quieras)" % [_cornadas,
		ProjectSettings.globalize_path(_salida)])


func _grabar() -> void:
	# EMPIEZA A CARGAR: a grabar. La 2a vez los tuyos se apartan de su linea (que se vea embestir sin nadie).
	if not _grabando and _mino.charging == _cor:
		_grabando = true
		_fotos.clear()
		_fin_ms = -1
		_centro_fijo = _tm.pies_de(_mino) + Vector2(0, -30)
		var f = _tm._cargas.get(_mino, [null, null, null])[2] if _tm._cargas.has(_mino) else null
		if f != null:
			_centro_fijo = f.origen + f.dir * f.largo * 0.5 + Vector2(0, -30)
		if _cornadas == 1 and not _apartados:
			_apartados = true
			for al in _combat._aliados:
				var p: Vector2 = _tm.pos_de(al) + Vector2(0, 170 if _tm.pies_de(al).y > _tm.pies_de(_mino).y else -170)
				_tm._colocar(al, _tm.cuerpo_de(al), p)
			print("[ver] 2a Cornada: los tuyos se apartan de la linea")
		print("[ver] el Minotauro empieza a cargar la Cornada %d a los %d ms" % [_cornadas + 1, Time.get_ticks_msec() - _t0])
	if not _grabando:
		return
	# SE HA LEVANTADO: su gesto se acabo (o no lleva ninguno) y no le queda desliz.
	var cu: Node2D = _tm.cuerpo_de(_mino)
	var en_gesto: bool = cu != null and cu.has_meta("gesto_pelea") and _mino.charging == null
	if _fin_ms < 0 and _mino.charging == null and not en_gesto and _tm._embestida_en_curso(_mino).is_empty() \
			and _fotos.size() > 6:
		_fin_ms = Time.get_ticks_msec()
	_par += 1
	if _par % 2 == 0:
		var img: Image = get_tree().root.get_viewport().get_texture().get_image()
		var xf: Transform2D = get_tree().root.get_viewport().get_canvas_transform()
		var c: Vector2 = xf * _centro_fijo
		var rec := Rect2i(Vector2i(int(c.x) - CELDA.x / 2, int(c.y) - CELDA.y / 2), CELDA)
		rec = rec.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if rec.size.x > 0 and rec.size.y > 0 and _fotos.size() < 60:
			_fotos.append(img.get_region(rec))
	if _fin_ms >= 0 and Time.get_ticks_msec() - _fin_ms > TRAS_LEVANTARSE_MS:
		_cerrar_hoja()


func _cerrar_hoja() -> void:
	_grabando = false
	_cornadas += 1
	if _fotos.is_empty():
		return
	var w: int = CELDA.x
	var h: int = CELDA.y
	var filas: int = ceili(_fotos.size() / 5.0)
	var hoja := Image.create(w * 5, h * filas, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0.1, 0.1, 0.12))
	for k in _fotos.size():
		var f: Image = _fotos[k]
		f.convert(Image.FORMAT_RGBA8)
		hoja.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % 5) * w, (k / 5) * h))
	hoja.save_png("%s/hoja_%d.png" % [_salida, _cornadas])
	print("[foto] hoja_%d.png (%d fotos)" % [_cornadas, _fotos.size()])
	_fotos.clear()
