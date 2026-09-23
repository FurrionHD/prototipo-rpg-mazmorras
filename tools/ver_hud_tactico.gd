# MIRAR EL HUD DEL COMBATE TACTICO. Entra en la arena, planta bichos de tamaños MUY distintos, abre
# la pelea, saca capturas y mide donde cae la barra de cada uno respecto a su cuerpo.
#
# CON VENTANA, a proposito: lo que viene a comprobar -- que la barra este ENCIMA del bicho y a SU
# ancho -- no lo dice ningun assert, hay que verlo. Se escribio despues de arreglar eso tres veces
# a ciegas, cada una con una teoria distinta sobre el tamaño de los sprites y las tres mal. La
# cuarta se resolvio pintando la caja calculada encima del bicho y mirando si encajaba.
#
# Se lanza asi (la ruta de salida de los PNG es opcional):
#   HUD_SALIDA=/ruta/hud godot --path . res://tools/ver_hud_tactico.tscn
#
# Lo que hay que mirar en lo que imprime: 'barra N ancho (1.00x el bicho)' y que el GROSOR salga
# IGUAL en todos -- el ancho cambia con el bicho, el grosor nunca.
extends Node

# Bichos a la vez, elegidos por ser los que mas se diferencian en tamaño y forma.
# TRES y no cuatro: la pelea tiene cupo de enemigos y el cuarto se quedaba fuera sin barra (por eso
# en la primera vuelta el Rey Slime salia sin nada encima). Estos tres son los extremos: el mas
# grande, el mas pequeño y el alargado.
const BICHOS := [
	["trent", Vector2(-160, -30)],
	["rata", Vector2(0, 40)],
	["rey_slime", Vector2(160, -20)],
]
var _salida: String = ""


func _ready() -> void:
	_salida = OS.get_environment("HUD_SALIDA")
	if _salida == "":
		_salida = "user://hud_tactico"
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _nombre_de(cuerpo: Node) -> String:
	var d = cuerpo.get("data")
	return String(d.enemy_name) if d != null else String(cuerpo.name)


func _foto(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	var ruta: String = "%s_%s.png" % [_salida, nombre]
	img.save_png(ruta)
	print("[foto] ", ruta, "  ", img.get_width(), "x", img.get_height())


func _correr() -> void:
	print("=== HUD TACTICO: A OJO ===")
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242

	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)

	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if jug == null:
		print("MAL: no hay jugador")
		get_tree().quit(1)
		return

	for b in BICHOS:
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % b[0],
			jug.global_position + (b[1] as Vector2), {})
		await _esperar(3)
	await _esperar(20)   # que generen su sprite (se dibujan por codigo)

	var enemigos: Array = get_tree().get_nodes_in_group("enemy")
	print("bichos plantados: ", enemigos.size())
	for e in enemigos:
		print("   ", e.name, "  data=", _nombre_de(e))

	if not Game.start_combat(enemigos, false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(40)
	await _foto("pelea")

	# Y con uno apuntado, para ver la pestaña de la derecha y el recuadro de seleccion.
	var combat: Node = null
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat != null:
		print("pantalla de combate: tactico=", combat.tactico)
		combat.figuras._seleccionar(0)
		await _esperar(20)
		await _foto("apuntado")
		# Y lo que de verdad importa: donde cae cada barra respecto a su bicho.
		_medir(combat)
	get_tree().quit(0)


# Escribe, bicho a bicho, si su barra esta ENCIMA y a SU ancho. Es el numero que llevo fallando.
func _medir(combat: Node) -> void:
	print("--- barra contra bicho (todo en px de pantalla) ---")
	var fm = combat.figuras_mapa
	for f in fm._fichas:
		var col: Control = f["bloque"].get("columna")
		var cuerpo: Node2D = f["cuerpo"]
		if not is_instance_valid(col) or not is_instance_valid(cuerpo):
			continue
		var cuerpo_px: Rect2 = fm._rect_cuerpo_px(cuerpo)
		var nombre: String = _nombre_de(cuerpo)
		var ratio: float = col.size.x / maxf(cuerpo_px.size.x, 1.0)
		var hueco: float = cuerpo_px.position.y - (col.position.y + col.size.y)
		# EL GROSOR tiene que salir IGUAL en todos: solo el ancho cambia con el bicho.
		var barra: Control = f["bloque"].get("hp")
		var grosor: float = barra.size.y if is_instance_valid(barra) else -1.0
		print("%-22s cuerpo %5.0fx%-5.0f  barra %5.0f ancho (%.2fx el bicho) x %.1f de GROSOR  hueco sobre la cabeza %5.1f px" % [
			nombre, cuerpo_px.size.x, cuerpo_px.size.y, col.size.x, ratio, grosor, hueco])
		# EL DESGLOSE, que es lo que hace falta para ver donde se rompe.
		var spr: AnimatedSprite2D = null
		for h in cuerpo.get_children():
			if h is AnimatedSprite2D and (h as CanvasItem).visible:
				spr = h
		print("      cuerpo en pantalla (origen) %s | rect calculado %s | barra puesta en %s" % [
			str(cuerpo.get_global_transform_with_canvas().origin.round()),
			str(cuerpo_px.position.round()) + "+" + str(cuerpo_px.size.round()),
			str(col.position.round())])
		if spr != null and spr.sprite_frames != null:
			var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, spr.get_frame())
			if tex != null:
				print("      sprite: anim=%s lona=%s pintado=%s escala_total=%s centered=%s offset=%s" % [
					spr.animation, str(tex.get_size()), str(fm._pintado_de(tex)),
					str(spr.get_global_transform_with_canvas().get_scale()),
					spr.centered, str(spr.offset)])
