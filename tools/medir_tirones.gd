# ============================================================
#  MEDIR LOS TIRONES (plan de optimizacion, fase 1E): los fotogramas SUELTOS que se alargan, que son lo que se nota
#  aunque el fotograma normal vaya sobrado (ver medir_dibujo). Con ventana y sin vsync, con la partida de referencia:
#    1) cargar el pueblo;  2) bajar a un piso;  3) abrir una pelea con el enemigo mas cercano.
#  De cada cosa: lo que tarda la llamada, el fotograma mas largo de despues y los que pasan de 20 ms.
#    godot --path . res://tools/medir_tirones.tscn -- --piso 8 > salida.txt
# OJO: la salida a un FICHERO, nunca por una tuberia (ver medir_fotograma.gd).
# No es una prueba (no esta en la bateria): es una herramienta de medida.
# ============================================================
extends Node

const TIRON_MS := 20.0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _arg(nombre: String, defecto: int) -> int:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = a.find(nombre)
	return int(a[i + 1]) if i >= 0 and i + 1 < a.size() else defecto


func _correr() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469

	# 1) EL PUEBLO
	Game.current_floor = 0
	await _tramo("cargar el pueblo", func(): get_tree().change_scene_to_file("res://scenes/levels/town.tscn"), _hay_jugador)
	await _reposo(60)
	# 2) UN PISO (dos veces: la segunda ya tiene todo cargado en memoria)
	for vez in 2:
		Game.current_floor = _arg("--piso", 8)
		await _tramo("bajar al piso %d (%s)" % [Game.current_floor, "1a vez" if vez == 0 else "2a vez"],
			func(): get_tree().change_scene_to_file("res://scenes/levels/main.tscn"), _hay_jugador)
		await _reposo(60)
	# 3) UNA PELEA
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var presa: Node = null
	var mejor: float = INF
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.has_method("esta_muerto") and not e.esta_muerto():
			var d: float = (e as Node2D).global_position.distance_to(jugador.global_position)
			if d < mejor:
				mejor = d
				presa = e
	if presa == null:
		print("[TIRONES] no hay enemigo para pelear")
	else:
		await _tramo("abrir una pelea (%s)" % presa.name, func(): Game.start_combat([presa], false),
			func(): return Game.hay_pelea_en_pantalla())
	get_tree().quit(0)


func _hay_jugador() -> bool:
	return get_tree().get_first_node_in_group("player") != null and not get_tree().paused


# Llama a 'accion', espera a que 'listo' diga que si y 60 fotogramas mas, y cuenta.
func _tramo(que: String, accion: Callable, listo: Callable) -> void:
	await get_tree().process_frame
	var t0: int = Time.get_ticks_usec()
	accion.call()
	var t_llamada: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var fots: Array = []
	var t_ant: int = Time.get_ticks_usec()
	var hasta_listo: float = -1.0
	var despues: int = 0
	for i in 1200:
		await get_tree().process_frame
		var ahora: int = Time.get_ticks_usec()
		fots.append(float(ahora - t_ant) / 1000.0)
		t_ant = ahora
		if hasta_listo < 0.0 and listo.call():
			hasta_listo = float(ahora - t0) / 1000.0
		if hasta_listo >= 0.0:
			despues += 1
			if despues >= 60:
				break
	var largos: Array = []
	for i in fots.size():
		if fots[i] > TIRON_MS:
			largos.append("#%d %.0f" % [i, fots[i]])
	var peor: float = 0.0
	for f in fots:
		peor = maxf(peor, f)
	print("[TIRONES] %-28s llamada %6.1f ms | listo a los %6.1f ms | peor fotograma %6.1f ms | de mas de %.0f ms: %s" % [
		que, t_llamada, hasta_listo, peor, TIRON_MS, ", ".join(largos) if not largos.is_empty() else "ninguno"])


# Fotogramas normales: la mediana y el peor, para ver si queda algo coleando.
func _reposo(n: int) -> void:
	var fots: Array = []
	var t_ant: int = Time.get_ticks_usec()
	for i in n:
		await get_tree().process_frame
		var ahora: int = Time.get_ticks_usec()
		fots.append(float(ahora - t_ant) / 1000.0)
		t_ant = ahora
	fots.sort()
	print("[TIRONES]   y luego, quieto: mediana %.2f ms, peor %.1f ms" % [fots[n / 2], fots[n - 1]])
