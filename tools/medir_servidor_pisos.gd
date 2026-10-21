# MEDIR LA SALA CON VARIOS PISOS (fase 2, etapa 2, paso 4). Monta 1, 4 y 8 pisos como los monta la sala (servidor_pisos,
# sin dibujar, a 60 fotogramas) con un jugador de mentira en cada uno (para que sus enemigos tengan a quien mirar) y
# apunta lo que cuesta: memoria y tiempo por fotograma (proceso y fisica), media y peor.
#   godot --headless --path . res://tools/medir_servidor_pisos.tscn            (1, 4 y 8)
#   godot --headless --path . res://tools/medir_servidor_pisos.tscn -- 2 6     (los que se digan)
extends Node

const _SERVIDOR := preload("res://scripts/net/servidor_pisos.gd")
const SEG_MEDIR := 10.0
const SEG_ASENTAR := 4.0

var _srv: Node


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	Engine.max_fps = 60   # lo que llevara la sala
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	Game.current_floor = 1
	Net.soy_sala = true
	Net.es_host = true
	Net.activo = true
	Net._mi_lugar = "sala"
	_srv = _SERVIDOR.new()
	get_tree().root.add_child(_srv)
	var cuantos: Array = []
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			cuantos.append(int(a))
	if cuantos.is_empty():
		cuantos = [1, 4, 8]
	if OS.get_cmdline_user_args().has("perfil"):
		await _perfil(4)
		get_tree().quit(0)
		return
	var base := _memoria_mb()
	print("[medir] memoria sin pisos: %.1f MB" % base)
	var montados: Array = []
	var filas: Array = []
	for n in cuantos:
		while montados.size() < n:
			var piso: int = montados.size() + 1
			var pv: PisoVivo = _srv.montar(piso, piso)
			montados.append(piso)
			await _hasta_poblado(pv)
			# Un jugador de mentira en el piso, al lado de un enemigo (si no, la IA de casi todos esta dormida).
			_cuerpo_suelto(pv)
		await _esperar(SEG_ASENTAR)
		print("[medir] %d pisos: %d nodos, %d recursos, %d objetos" % [n,
			int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
			int(Performance.get_monitor(Performance.OBJECT_COUNT))])
		var m := await _medir()
		var enemigos := 0
		for p in montados:
			enemigos += _srv.piso(p).nodos(&"enemy").size()
		var fila := "%d pisos (%d enemigos): memoria %.1f MB (+%.1f), a 60: %.0f fps (peor fotograma %.1f ms); trabajo por fotograma: proceso %.2f ms + fisica %.2f ms (peor %.1f + %.1f)" % [
			n, enemigos, m["mem"], m["mem"] - base, m["fps"], m["peor_ms"], m["proc"], m["fis"], m["proc_max"], m["fis_max"]]
		print("[medir] ", fila)
		filas.append(fila)
	print("[medir] ===== RESUMEN =====")
	for f in filas:
		print("[medir] ", f)
	get_tree().quit(0)


# Un cuerpo de jugador en el piso, al lado de un enemigo, SIN apuntarlo en la red: un peer de mentira en Net._peers hace
# que la sala le mande paquetes a nadie, y cada uno escupe un error con su rastro (eso solo ya hundia la medida).
func _cuerpo_suelto(pv: PisoVivo) -> void:
	var av: Node2D = Net._REMOTE_PLAYER.new()
	pv.add_child(av)
	var enem: Array = pv.nodos(&"enemy")
	if not enem.is_empty():
		av.global_position = (enem[0] as Node2D).global_position + Vector2(60, 0)


func _memoria_mb() -> float:
	return float(OS.get_static_memory_usage()) / (1024.0 * 1024.0)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _hasta_poblado(pv: PisoVivo, tope: int = 900) -> void:
	var n: int = 0
	while n < tope:
		var suelo: Node = pv.primero(&"dungeon_floor")
		if suelo != null and suelo.get("gen") != null and not pv.nodos(&"enemy").is_empty():
			return
		await get_tree().physics_frame
		n += 1


# Tiempos por fotograma durante SEG_MEDIR (Performance da el del ultimo fotograma, en segundos).
func _medir() -> Dictionary:
	var proc := 0.0
	var proc_max := 0.0
	var fis := 0.0
	var fis_max := 0.0
	var n := 0
	var t0 := Time.get_ticks_msec()
	var peor_ms := 0.0
	var t_ant := Time.get_ticks_usec()
	while Time.get_ticks_msec() - t0 < int(SEG_MEDIR * 1000.0):
		await get_tree().process_frame
		var ahora := Time.get_ticks_usec()
		peor_ms = maxf(peor_ms, float(ahora - t_ant) / 1000.0)
		t_ant = ahora
		var p: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var f: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		proc += p
		fis += f
		proc_max = maxf(proc_max, p)
		fis_max = maxf(fis_max, f)
		n += 1
	var seg: float = float(Time.get_ticks_msec() - t0) / 1000.0
	return {"proc": proc / maxf(1, n), "proc_max": proc_max, "fis": fis / maxf(1, n), "fis_max": fis_max,
		"fps": float(n) / seg, "mem": _memoria_mb(), "peor_ms": peor_ms}


# PERFIL A MANO: con 'n' pisos montados, apaga el _process y el _physics_process de cada tipo de nodo (por su script)
# y mide cuantos fotogramas por segundo se recuperan. El que mas sube es el que se come el tiempo.
#   godot --headless --path . res://tools/medir_servidor_pisos.tscn -- perfil
func _perfil(n: int) -> void:
	for piso in range(1, n + 1):
		var pv: PisoVivo = _srv.montar(piso, piso)
		await _hasta_poblado(pv)
		_cuerpo_suelto(pv)
	await _esperar(SEG_ASENTAR)
	var por_script: Dictionary = {}
	for piso in range(1, n + 1):
		_recoger(_srv.piso(piso), por_script)
	var base: float = await _fps(3.0)
	print("[perfil] %d pisos: %.1f fps con todo encendido" % [n, base])
	var claves: Array = por_script.keys()
	claves.sort_custom(func(a, b): return (por_script[a] as Array).size() > (por_script[b] as Array).size())
	var filas: Array = []
	for k in claves:
		var lista: Array = por_script[k]
		for nd in lista:
			if is_instance_valid(nd):
				nd.set_process(false)
				nd.set_physics_process(false)
		var sin: float = await _fps(2.5)
		for nd in lista:
			if is_instance_valid(nd):
				nd.set_process(true)
				nd.set_physics_process(true)
		filas.append([sin - base, "%s (x%d): %.1f fps sin el (%+.1f)" % [k, lista.size(), sin, sin - base]])
		await _esperar(0.5)
	filas.sort_custom(func(a, b): return float(a[0]) > float(b[0]))
	print("[perfil] ===== LO QUE MAS RECUPERA =====")
	for f in filas.slice(0, 15):
		print("[perfil] ", f[1])


func _recoger(n: Node, por_script: Dictionary) -> void:
	for h in n.get_children():
		var sc = h.get_script()
		var k: String = (sc as Script).resource_path.get_file() if sc != null else h.get_class()
		if h.is_processing() or h.is_physics_processing():
			(por_script.get_or_add(k, []) as Array).append(h)
		_recoger(h, por_script)


func _fps(seg: float) -> float:
	var f0 := Engine.get_process_frames()
	var t0 := Time.get_ticks_msec()
	await _esperar(seg)
	return float(Engine.get_process_frames() - f0) / (float(Time.get_ticks_msec() - t0) / 1000.0)
