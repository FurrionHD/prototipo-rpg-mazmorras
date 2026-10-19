# ============================================================
#  PRUEBA: LAS ANTORCHAS DEL PUEBLO SOLO SUENAN ENCENDIDAS Y A TU ALCANCE (optimizacion 1E, 19/10/2026)
#  Antes sonaban todas siempre (~48 OGG a la vez, de dia a -60 dB). Ahora (Antorcha._vigilar_sonido):
#   1) de noche, junto a una antorcha: la suya suena, y ninguna de las que suenan esta lejos de la camara;
#   2) alejandose, la que sonaba se calla;
#   3) de dia: no suena ninguna.
#    godot --headless --path . res://tools/prueba_antorchas_sonido.tscn
# ============================================================
extends Node

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.current_floor = 0
	CicloDia.hora_forzada = _hora_de_noche()
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	var jugador: Node2D = null
	for k in 300:
		await get_tree().process_frame
		jugador = get_tree().get_first_node_in_group("player") as Node2D
		if jugador != null:
			break
	var antorchas: Array = _antorchas(get_tree().current_scene)
	_ver(antorchas.size() > 20, "hay antorchas en el pueblo (%d)" % antorchas.size())
	# 1) DE NOCHE, junto a la primera.
	var junto: Antorcha = antorchas[0]
	jugador.global_position = junto.global_position + Vector2(0, 40)
	await _segundos(1.5)
	var cam: Camera2D = get_viewport().get_camera_2d()
	var suenan: int = 0
	var lejos: int = 0
	for a in antorchas:
		if a._sonido != null and a._sonido.playing:
			suenan += 1
			if a.global_position.distance_to(cam.get_screen_center_position()) > a._alcance + Antorcha.MARGEN_SONIDO + 32.0:
				lejos += 1
	_ver(junto._sonido != null and junto._sonido.playing, "de noche, la antorcha de al lado suena")
	_ver(suenan < antorchas.size() and lejos == 0, "solo suenan las cercanas (%d de %d; lejos: %d)" % [suenan, antorchas.size(), lejos])
	# 2) ALEJARSE.
	jugador.global_position = junto.global_position + Vector2(0, 2000)
	await _segundos(0.5)
	_ver(not junto._sonido.playing, "al alejarse, se calla")
	# 3) DE DIA.
	jugador.global_position = junto.global_position + Vector2(0, 40)
	CicloDia.hora_forzada = _hora_de_dia()
	await _segundos(1.5)
	var de_dia: int = 0
	for a in antorchas:
		if a._sonido != null and a._sonido.playing:
			de_dia += 1
	_ver(de_dia == 0, "de dia no suena ninguna (%d)" % de_dia)
	CicloDia.hora_forzada = -1.0
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)


# El primer momento del ciclo con las luces del todo encendidas / del todo apagadas.
func _hora_de_noche() -> float:
	for i in 200:
		var s: float = CicloDia.CICLO * float(i) / 200.0
		if CicloDia.luces(1.0, s) >= 1.0 and CicloDia.luces(0.0, s) >= 1.0:
			return s
	return CicloDia.CICLO * 0.9


func _hora_de_dia() -> float:
	for i in 200:
		var s: float = CicloDia.CICLO * float(i) / 200.0
		if CicloDia.luces(1.0, s) <= 0.0 and CicloDia.luces(0.0, s) <= 0.0:
			return s
	return CicloDia.CICLO * 0.4


func _segundos(t: float) -> void:
	var fin: int = Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < fin:
		await get_tree().process_frame


func _antorchas(n: Node) -> Array:
	var out: Array = []
	if n is Antorcha:
		out.append(n)
	for h in n.get_children():
		out.append_array(_antorchas(h))
	return out
