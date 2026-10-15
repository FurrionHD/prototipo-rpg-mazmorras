# EL GOLPE QUE NO ENTRA SE VE (15/10, lo pidio el usuario: "al esquivar solo se ve la animacion de apartarse"). Sale un
# «FALLO» como un numero mas -en BLANCO y del tamaño de un golpe normal- encima del que lo esquiva, sea de los tuyos o
# un enemigo. Pelea tactica en la arena, sin red:
#   1) el enemigo pega a uno de los tuyos y lo esquiva: «FALLO» sobre el tuyo;
#   2) uno de los tuyos pega al enemigo y lo esquiva: «FALLO» sobre el enemigo;
#   3) un golpe que entra sigue saliendo con su numero (no con «FALLO»).
#   godot --headless --path . res://tools/prueba_fallo_numero.tscn
extends Node

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


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _pelea() -> Array:
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", jug.global_position + Vector2(70, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	if not Game.start_combat([nodo], false):
		return []
	await _esperar(8)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					return [h, nodo]
	return []


# Lo que se ve de un numero que vuela: {texto, color, tam, centro (pantalla), visible}.
func _info(d: Dictionary) -> Dictionary:
	var lbl: Label = d["lbl"]
	return {"texto": lbl.text, "color": lbl.get_theme_color("font_color"),
		"tam": lbl.get_theme_font_size("font_size"), "visible": lbl.visible and lbl.modulate.a > 0.05,
		"centro": lbl.get_global_rect().get_center()}


# Pega un golpe de 'a' a 'v' (esquivado o no) y devuelve los numeros NUEVOS que salen. (Las etiquetas se reciclan de un
# monton comun: los nuevos se reconocen por su entrada en _numeros, no por la etiqueta.)
func _golpe(combat, a: Combatant, v: Combatant, evadido: bool) -> Array:
	var fx = combat._fx
	# Con la cola del golpe de antes YA ACABADA, como en la pelea: arrancarla con el anterior dentro lo volveria a soltar.
	for _k in 600:
		if fx._cola.is_empty():
			break
		await _esperar(1)
	var antes: Array = fx._numeros.duplicate()
	combat.efectos._fx_golpe(a, v, 0.0 if evadido else 3.5, false, evadido)
	fx.arrancar_cola()
	var nuevos: Array = []
	for _k in 120:
		await _esperar(1)
		nuevos = fx._numeros.filter(func(d): return not antes.any(func(x): return is_same(x, d)))
		if not nuevos.is_empty():
			break
	await _esperar(1)
	nuevos = fx._numeros.filter(func(d): return not antes.any(func(x): return is_same(x, d)))
	return nuevos.map(func(d): return _info(d))


func _encima_de(combat, c: Combatant, n: Dictionary) -> bool:
	var r: Rect2 = combat._fx._rect_mapa(combat._bloque_de(c))
	return r.has_area() and absf(float(n["centro"].x) - r.get_center().x) < 60.0 \
		and float(n["centro"].y) < r.end.y + 10.0 and float(n["centro"].y) > r.position.y - 90.0


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var r: Array = await _pelea()
	if r.is_empty():
		print("FIN: HAY FALLOS (no arranca la pelea)")
		get_tree().quit(1)
		return
	var combat: Node = r[0]
	var e: Combatant = combat._enemies[0]
	var al: Combatant = combat._aliados[0]
	combat.set_process(false)   # la barra quieta: los golpes los pone la prueba
	_ver(combat.tactico, "pelea en el mapa")

	print("1) el enemigo pega y uno de los tuyos lo esquiva")
	var n1: Array = await _golpe(combat, e, al, true)
	_ver(n1.size() == 1, "sale un numero (%d)" % n1.size())
	if n1.size() == 1:
		var n: Dictionary = n1[0]
		_ver(n["texto"] == "FALLO", "dice FALLO ('%s')" % n["texto"])
		_ver((n["color"] as Color).is_equal_approx(Color.WHITE), "en blanco (%s)" % n["color"])
		_ver(int(n["tam"]) == 19, "del tamaño de un golpe normal (%d)" % int(n["tam"]))
		_ver(n["visible"], "se ve")
		_ver(_encima_de(combat, al, n), "encima del que lo esquiva (%s)" % n["centro"])

	print("2) uno de los tuyos pega y el enemigo lo esquiva")
	var n2: Array = await _golpe(combat, al, e, true)
	_ver(n2.size() == 1 and n2[0]["texto"] == "FALLO", "sale FALLO (%s)" % str(n2.map(func(x): return x["texto"])))
	if n2.size() == 1:
		_ver(_encima_de(combat, e, n2[0]), "encima del enemigo (%s)" % n2[0]["centro"])

	print("3) un golpe que entra")
	var n3: Array = await _golpe(combat, e, al, false)
	_ver(n3.size() == 1 and n3[0]["texto"] != "FALLO" and String(n3[0]["texto"]).begins_with("3.50"),
		"sale su numero, no FALLO (%s)" % str(n3.map(func(x): return x["texto"])))

	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
