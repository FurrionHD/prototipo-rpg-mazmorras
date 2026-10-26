# LA PELEA DE OTRO JUGADOR, VISTA DESDE FUERA (11/10, lo pidio el usuario). Sin red: se llama a lo que llamaria la red
# (Game.impacto_ajeno, Game.zona_ajena, Game.zona_ajena_cerrada) en un piso de verdad y se mira que:
#   1) al IMPACTO de un compañero cercano y a la vista me quedo quieto; lejos o tras un muro, no;
#   2) si la zona me pilla dentro sigo quieto (me uno); si no, me suelto;
#   3) la zona se pinta (ajena) y la LINEA me frena; al tocarla sale la pregunta; con No sigo frenado y no se
#      repite mientras sigo pegado; al despegarme y volver a chocar, se repite;
#   4) cuando su pelea acaba, la zona desaparece.
# (Etapa 4, 26/10) COMO JUGADOR con su sala: lo que se mira es lo que hace la maquina del jugador.
#   godot --headless --path . res://tools/prueba_zona_ajena.tscn -- nube_local
extends Node

var j = null   # el jugador con su sala: tools/prueba_con_jugador.gd

var _mal: int = 0
const EMISOR := 7
const ANFITRION := 9


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


var _vigia_jug: Node2D = null
var _vigia_ult := Vector2.ZERO
var _vigia_log: Array = []
func _vigia() -> void:
	if _vigia_jug != null and is_instance_valid(_vigia_jug) and _vigia_jug.global_position != _vigia_ult:
		_vigia_log.append("f%d %s -> %s (fisica=%s)" % [Engine.get_process_frames(), _vigia_ult.round(), _vigia_jug.global_position.round(), Engine.is_in_physics_frame()])
		_vigia_ult = _vigia_jug.global_position


func _pregunta_abierta() -> bool:
	return Game._pregunta_pelea != null and is_instance_valid(Game._pregunta_pelea) \
		and not Game._pregunta_pelea.is_queued_for_deletion()


func _correr() -> void:
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_zona_ajena", 77, 1):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return
	await _esperar(30)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.gen
	var sala := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala" and (z["rect"] as Rect2i).get_area() > sala.get_area():
			sala = z["rect"]
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	# Los enemigos fuera de la sala, que no se metan en medio.
	j.apartar_enemigos()
	var centro: Vector2 = gen.centro_px(sala.position + sala.size / 2)
	jug.global_position = centro
	_vigia_jug = jug
	_vigia_ult = centro
	get_tree().physics_frame.connect(_vigia)
	get_tree().process_frame.connect(_vigia)
	await _esperar(3)

	print("1) el impacto de un compañero")
	Game.impacto_ajeno(EMISOR, centro + Vector2(60, 0))
	_ver(Game.entrando_en_pelea(), "a 60 px y a la vista: me quedo quieto")
	if not Game.entrando_en_pelea():
		print("    por que no: capa=%s combate=%s ocupado=%s jugador=%s (centro %s) linea=%s enemigos=%s" % [
			Game._active_layer, Game.combate_activo(), Net.peleas.ocupado_en_pelea(), jug.global_position.round(),
			centro.round(), ArenaCalculo.linea_por_suelo(gen, jug.global_position, centro + Vector2(60, 0)),
			Game._active_enemies])
	Game.soltar_entrando_en_pelea()
	Game._impacto_de = 0
	Game.impacto_ajeno(EMISOR, centro + Vector2(Game.ALIADOS_EN_ZONA + 40.0, 0))
	_ver(not Game.entrando_en_pelea(), "a %d px: no" % int(Game.ALIADOS_EN_ZONA + 40.0))
	# Tras un muro: una celda de suelo a menos de 320 px sin linea recta por el suelo.
	var tras_muro := Vector2.INF
	var c0: Vector2i = ArenaCalculo.celda_de_px(centro)
	for dy in range(-9, 10):
		for dx in range(-9, 10):
			var c := c0 + Vector2i(dx, dy)
			var q: Vector2 = gen.centro_px(c)
			if gen.es_suelo(c) and q.distance_to(centro) <= Game.ALIADOS_EN_ZONA \
					and not ArenaCalculo.linea_por_suelo(gen, centro, q):
				tras_muro = q
				break
		if tras_muro != Vector2.INF:
			break
	if tras_muro != Vector2.INF:
		Game.impacto_ajeno(EMISOR, tras_muro)
		_ver(not Game.entrando_en_pelea(), "tras un muro (%s): no" % tras_muro.round())
	else:
		print("  (no hay suelo tras un muro a menos de 320 px de esta sala: me salto ese caso)")

	print("2) llega su zona")
	var dentro_rect := Rect2i(c0 - Vector2i(2, 2), Vector2i(5, 5))
	Game.impacto_ajeno(EMISOR, centro + Vector2(60, 0))
	var quieto_antes: bool = Game.entrando_en_pelea()
	Game.zona_ajena(EMISOR, ANFITRION, dentro_rect, PackedByteArray())
	_ver(Game.entrando_en_pelea(), "me pilla dentro: sigo quieto (me uno)")
	if not Game.entrando_en_pelea():
		print("    por que no: quieto antes=%s jugador=%s celda %s, zona %s, enemigos=%s capa=%s" % [quieto_antes,
			jug.global_position.round(), ArenaCalculo.celda_de_px(jug.global_position), dentro_rect,
			Game._active_enemies, Game._active_layer])
	_ver(Game._impacto_de == 0, "el impacto ya esta atendido")
	Game.zona_ajena_cerrada(EMISOR)
	Game.soltar_entrando_en_pelea()
	_ver(not Game.hay_zona_ajena(ANFITRION), "su pelea acaba: la zona se va")
	# Ahora una zona que NO me pilla: a la derecha, dentro de la sala, con dos celdas de hueco.
	var fuera_rect := Rect2i(c0 + Vector2i(2, -2), Vector2i(4, 5))
	Game.impacto_ajeno(EMISOR, centro + Vector2(60, 0))
	Game.zona_ajena(EMISOR, ANFITRION, fuera_rect, PackedByteArray())
	_ver(not Game.entrando_en_pelea(), "no me pilla: me suelto")
	await _esperar(2)
	var nodo = Game._zonas_ajenas.get(ANFITRION, {}).get("nodo")
	_ver(nodo != null and is_instance_valid(nodo) and (nodo as ArenaCombate).ajena, "su zona esta pintada en mi suelo (ajena)")

	print("3) la linea me frena y me pregunta")
	var arena: ArenaCombate = nodo
	var borde_x: float = arena.rect.position.x
	jug.global_position = Vector2(borde_x - 20.0, centro.y)
	await _esperar(2)
	for _k in 8:
		var antes: Vector2 = jug.global_position
		jug.global_position = antes + Vector2(4.0, 0.0)
		Game.frenar_en_zonas_ajenas(jug, antes)
	_ver(not arena.contiene(jug.global_position), "empujando contra la linea no entro (x=%.0f, borde %.0f)" % [jug.global_position.x, borde_x])
	_ver(_pregunta_abierta(), "al tocarla sale la pregunta")
	if _pregunta_abierta():
		Game._pregunta_pelea._no()
	await _esperar(2)
	for _k in 4:
		var antes2: Vector2 = jug.global_position
		jug.global_position = antes2 + Vector2(4.0, 0.0)
		Game.frenar_en_zonas_ajenas(jug, antes2)
	_ver(not arena.contiene(jug.global_position), "con el No sigo frenado")
	_ver(not _pregunta_abierta(), "pegado a la linea no se me vuelve a preguntar")
	var lejos_x: Vector2 = Vector2(borde_x - ArenaCombate.SOLTAR - 12.0, centro.y)
	Game.frenar_en_zonas_ajenas(jug, jug.global_position)
	jug.global_position = lejos_x
	Game.frenar_en_zonas_ajenas(jug, lejos_x)
	for _k in 12:
		var antes3: Vector2 = jug.global_position
		jug.global_position = antes3 + Vector2(4.0, 0.0)
		Game.frenar_en_zonas_ajenas(jug, antes3)
	_ver(_pregunta_abierta(), "me despego y vuelvo a chocar: se me pregunta otra vez")
	if _pregunta_abierta():
		Game._pregunta_pelea._no()
	await _esperar(2)

	print("4) su pelea acaba")
	Game.zona_ajena_cerrada(EMISOR)
	await _esperar(2)
	_ver(not Game.hay_zona_ajena(ANFITRION) and not is_instance_valid(nodo), "la zona desaparece de mi suelo")
	var antes4: Vector2 = jug.global_position
	jug.global_position = antes4 + Vector2(40.0, 0.0)
	Game.frenar_en_zonas_ajenas(jug, antes4)
	_ver(jug.global_position.is_equal_approx(antes4 + Vector2(40.0, 0.0)), "y ya no me frena")
	_ver(not Game.hay_modal(), "no se queda ningun menu abierto")

	print("5) (12/10) una zona NUEVA que me pilla dentro, sin que me llegara su impacto: entro solo")
	Game._entrada_por_zona = 0
	jug.global_position = centro
	await _esperar(2)
	Game.zona_ajena(EMISOR, ANFITRION + 1, dentro_rect, PackedByteArray())
	_ver(Game._entrada_por_zona == ANFITRION + 1, "me pilla dentro: entro con mi grupo sin preguntar")
	Game.zona_ajena_cerrada(EMISOR)
	Game._entrada_por_zona = 0
	Game.zona_ajena(EMISOR, ANFITRION + 2, fuera_rect, PackedByteArray())
	_ver(Game._entrada_por_zona == 0, "una que no me pilla: no entro")
	Game.zona_ajena_cerrada(EMISOR)

	print("6) (12/10) MI pelea acaba y mi compañero aun la anuncia: ni zona ni pregunta")
	var mia := ANFITRION + 3
	Game.zona_ajena(EMISOR, mia, dentro_rect, PackedByteArray())   # la anunciaba mientras peleabamos juntos
	Game._mi_zona = {"anfitrion": mia, "rect": dentro_rect, "mascara": PackedByteArray()}
	Game._olvidar_zona_de_mi_pelea(true)
	Game._mi_zona = {}
	_ver(not Game.hay_zona_ajena(mia), "al acabar mi pelea su zona deja de ser ajena")
	Game._entrada_por_zona = 0
	Game.zona_ajena(EMISOR, mia, dentro_rect, PackedByteArray())   # su anuncio rezagado
	_ver(not Game.hay_zona_ajena(mia) and Game._entrada_por_zona == 0, "su anuncio rezagado no la vuelve a poner")
	Game.zona_ajena(EMISOR, mia, Rect2i(dentro_rect.position + Vector2i(40, 40), dentro_rect.size), PackedByteArray())
	_ver(Game.hay_zona_ajena(mia), "una pelea NUEVA de ese mismo (en otro sitio) si se ve")
	Game.zona_ajena_cerrada(EMISOR)
	var huyo := ANFITRION + 4
	Game.zona_ajena(EMISOR, huyo, dentro_rect, PackedByteArray())
	Game._mi_zona = {"anfitrion": huyo, "rect": dentro_rect, "mascara": PackedByteArray()}
	Game._olvidar_zona_de_mi_pelea(false)   # me voy huyendo y la pelea sigue
	Game._mi_zona = {}
	_ver(Game.hay_zona_ajena(huyo), "si me voy huyendo de una que sigue, la veo desde fuera")
	Game.zona_ajena_cerrada(EMISOR)

	if _mal > 0:
		print("    vigia: ", _vigia_log.slice(0, 20))
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	await j.cerrar()
	get_tree().quit(1 if _mal > 0 else 0)
