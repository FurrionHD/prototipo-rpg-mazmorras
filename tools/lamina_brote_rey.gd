# HERRAMIENTA (CON VENTANA). La lamina del BROTE DEL REY SLIME (09/10, el 16 del playtest 08/10): las crias salen
# volando en arco del Rey y caen DETRAS de los tuyos. Fotos antes, durante el vuelo y al caer (hoja.png, 3 x 2).
#   BROTE_SALIDA=C:/Users/dasui/Desktop/ataques_mapa/brote_rey godot --path . res://tools/lamina_brote_rey.tscn
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


const CELDA := Vector2i(480, 320)
const AMPLIA := 1
var _salida: String = ""
var _fotos: Array = []


func _foto(nombre: String, centro_mundo: Vector2) -> void:
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
	_salida = OS.get_environment("BROTE_SALIDA")
	if _salida == "":
		_salida = "user://brote_rey"
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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/rey_slime.tres", jug.global_position + Vector2(130, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	Game.start_combat([nodo], false)
	await _esperar(40)
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)
	var tm = combat.turno_mapa
	var e: Combatant = combat._enemies[0]
	var centro: Vector2 = tm.pies_de(combat._aliados[0]) + Vector2(10, -20)
	e.charging = null
	tm.olvidar_carga(e)
	await _esperar(10)
	await _foto("01_antes", centro)
	var inv: AbilityData = load("res://resources/abilities/rey_slime_invocacion.tres")
	combat.enemigos._enemy_use_ability(e, inv)
	combat._fx.arrancar_cola()
	for c in combat._enemies:
		if c != e:
			print("[cria] %s hacia %s" % [c.nombre, str(tm.pos_de(c).round())])
	print("[cria] rey en %s, jugador en %s" % [str(tm.pos_de(e).round()), str(tm.pos_de(combat._aliados[0]).round())])
	for k in 5:
		await _esperar(5 if k < 4 else 40)
		await _foto("%02d_%s" % [k + 2, "vuela" if k < 4 else "cae"], centro)
	var w: int = CELDA.x * AMPLIA
	var h: int = CELDA.y * AMPLIA
	var hoja := Image.create(w * 3, h * 2, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0.1, 0.1, 0.12))
	for k in _fotos.size():
		var f: Image = _fotos[k]
		f.convert(Image.FORMAT_RGBA8)
		hoja.blit_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i((k % 3) * w, (k / 3) * h))
	hoja.save_png("%s/hoja.png" % _salida)
	print("[foto] hoja.png -> ", _salida)
	get_tree().quit(0)
