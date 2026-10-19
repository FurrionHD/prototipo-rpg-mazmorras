# ============================================================
#  MEDIR EL DIBUJO (plan de optimizacion, fase 1E): lo que medir_fotograma no ve porque va sin ventana. Carga la
#  partida de referencia en un piso (-1 = el pueblo, town.tscn), quita el vsync y mide con ventana: el fotograma entero, el
#  tiempo de dibujo en CPU y en GPU y las llamadas de dibujo. Luego ESCONDE por turnos todo lo de cada script (los
#  munecos, las piezas del pueblo, las luces...) y mira cuanto baja cada cosa.
#    godot --path . res://tools/medir_dibujo.tscn -- --piso -1 > salida.txt
# OJO: la salida a un FICHERO, nunca por una tuberia (ver medir_fotograma.gd).
# No es una prueba (no esta en la bateria): es una herramienta de medida.
# ============================================================
extends Node

const MUESTRAS := 120
const TOP_SCRIPTS := 22


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
	var piso: int = _arg("--piso", -1)
	Game.current_floor = maxi(0, piso)
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn" if piso < 0 else "res://scenes/levels/main.tscn")
	var jugador: Node2D = null
	for i in 900:
		await get_tree().process_frame
		jugador = get_tree().get_first_node_in_group("player") as Node2D
		if jugador != null and not get_tree().paused:
			break
	if jugador == null:
		print("[DIBUJO] no se monto el piso")
		get_tree().quit(1)
		return
	for i in 120:
		await get_tree().process_frame
	var vp: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	print("[DIBUJO] piso %d  nodos=%d  enemigos=%d" % [Game.current_floor,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), get_tree().get_nodes_in_group("enemy").size()])
	var base: Dictionary = await _medir("TODO A LA VISTA", vp)

	# POR SCRIPT: los CanvasItem visibles agrupados por el script que llevan (o el de su primer padre con script).
	var por_script: Dictionary = {}
	var todos: Array = []
	_juntar(get_tree().root, todos)
	for n in todos:
		if not (n is CanvasItem) or not (n as CanvasItem).is_visible_in_tree() or n == self:
			continue
		var sc: Script = n.get_script()
		if sc == null or sc.resource_path == "":
			continue
		var r: String = sc.resource_path.get_file()
		if not por_script.has(r):
			por_script[r] = []
		por_script[r].append(n)
	var rutas: Array = por_script.keys()
	rutas.sort_custom(func(a, b): return por_script[a].size() > por_script[b].size())
	var filas: Array = []
	for r in rutas.slice(0, TOP_SCRIPTS):
		var nodos: Array = por_script[r]
		for n in nodos:
			if is_instance_valid(n):
				(n as CanvasItem).visible = false
		var m: Dictionary = await _medir("", vp)
		for n in nodos:
			if is_instance_valid(n):
				(n as CanvasItem).visible = true
		filas.append([r, nodos.size(), base["fotograma"] - m["fotograma"], base["cpu"] - m["cpu"],
			base["gpu"] - m["gpu"], base["llamadas"] - m["llamadas"]])
	filas.sort_custom(func(a, b): return a[2] > b[2])
	print("[DIBUJO] ESCONDIENDO CADA SCRIPT (lo que se AHORRA; negativo = ruido):")
	print("[DIBUJO]   %-30s %5s  %9s  %9s  %9s  %8s" % ["script", "nodos", "fotograma", "cpu dib.", "gpu", "llamadas"])
	for f in filas:
		print("[DIBUJO]   %-30s %5d  %7.2f ms %7.2f ms %7.2f ms  %8d" % f)
	get_tree().quit(0)


# MEDIANAS de MUESTRAS fotogramas, quieto (el jugador no anda: asi esconder algo no cambia lo que se ve de lo demas).
func _medir(que: String, vp: RID) -> Dictionary:
	for i in 10:
		await get_tree().process_frame
	var fot: Array = []
	var cpu: Array = []
	var gpu: Array = []
	var llam: Array = []
	var t_ant: int = Time.get_ticks_usec()
	for i in MUESTRAS:
		await get_tree().process_frame
		var ahora: int = Time.get_ticks_usec()
		fot.append(float(ahora - t_ant) / 1000.0)
		t_ant = ahora
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu())
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
		llam.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var r: Dictionary = {"fotograma": _mediana(fot), "cpu": _mediana(cpu), "gpu": _mediana(gpu), "llamadas": int(_mediana(llam))}
	if que != "":
		print("[DIBUJO] %-18s fotograma %6.2f ms (%d fps) | dibujo cpu %5.2f ms gpu %5.2f ms | %d llamadas | proceso %5.2f fisica %5.2f" % [
			que, r["fotograma"], int(1000.0 / maxf(0.001, r["fotograma"])), r["cpu"], r["gpu"], r["llamadas"],
			Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0])
	return r


func _mediana(a: Array) -> float:
	var b: Array = a.duplicate()
	b.sort()
	return float(b[b.size() / 2])


func _juntar(n: Node, out: Array) -> void:
	out.append(n)
	for h in n.get_children():
		_juntar(h, out)
