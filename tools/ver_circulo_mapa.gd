# EL CIRCULO MAGICO FUERA DE COMBATE (26/09): en el pueblo, recita un hechizo frase a frase por casteo_mapa (el
# camino de verdad), lo suelta y despues falla otro. Fotos de cada momento. CON VENTANA.
#   CIRCULO_HECHIZO=tormenta CIRCULO_SALIDA=/ruta/pref godot --path . res://tools/ver_circulo_mapa.tscn
extends Node

const CASTEO_MAPA = preload("res://scripts/ui/casteo_mapa.gd")
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("CIRCULO_SALIDA")
	if _salida == "":
		_salida = "user://circulo_mapa"
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


func _pausa(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	var ruta: String = "%s_%s.png" % [_salida, nombre]
	img.save_png(ruta)
	print("[foto] ", ruta)


func _correr() -> void:
	var nom: String = OS.get_environment("CIRCULO_HECHIZO")
	if nom == "":
		nom = "tormenta"
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(20)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jug == null:
		print("MAL: no hay jugador")
		get_tree().quit(1)
		return
	var sp: SpellData = load("res://resources/spells/%s.tres" % nom)
	# 1) Recitado entero y soltado.
	var c: Node = CASTEO_MAPA.new()
	c.setup(Game.lider(), jug, null)
	jug.add_child(c)
	await _esperar(3)
	c._elegir(sp)
	for k in sp.longitud():
		c._responder(sp.frases[k], sp.frases[k])
		await _pausa(0.2)
		await _foto("%s_frase%d_sale" % [nom, k + 1])
		await _pausa(0.7)
		await _foto("%s_frase%d" % [nom, k + 1])
	await _pausa(0.25)
	await _foto("%s_disparo" % nom)
	await _pausa(1.0)
	# 2) Otro que se falla en la segunda frase.
	var c2: Node = CASTEO_MAPA.new()
	c2.setup(Game.lider(), jug, null)
	jug.add_child(c2)
	await _esperar(3)
	c2._elegir(sp)
	c2._responder(sp.frases[0], sp.frases[0])
	await _pausa(0.9)
	c2._responder("mal", sp.frases[1])
	await _pausa(0.2)
	await _foto("%s_fallo" % nom)
	await _pausa(1.2)
	var quedan: int = 0
	for h in jug.get_children():
		if h is CirculoMagico:
			quedan += 1
	print("  circulos que quedan: ", quedan)
	print("=== FIN ===")
	get_tree().quit(0)
