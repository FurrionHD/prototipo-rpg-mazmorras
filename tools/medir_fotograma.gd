# ============================================================
#  MEDIR EL FOTOGRAMA (plan de optimizacion, fase 1B): cuanto tiempo de script se va en un piso de verdad y QUIEN
#  se lo lleva. Carga la partida de referencia en un piso, anda en circulo y mide TIME_PROCESS / TIME_PHYSICS_PROCESS
#  de media; luego apaga por turnos cada pieza (HUD, jugador, enemigos, niebla, el resto del piso) y mira cuanto baja.
#  Sin ventana el dibujo no cuenta: esto mide SOLO el codigo.
#    godot --headless --path . res://tools/medir_fotograma.tscn -- --piso 5
# No es una prueba (no esta en la bateria): es una herramienta de medida.
# ============================================================
extends Node

const MUESTRAS := 240
const VECES := 30


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
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469
	Game.current_floor = _arg("--piso", 1)
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	var piso: Node = null
	var jugador: Node2D = null
	for i in 900:
		await get_tree().process_frame
		piso = get_tree().get_first_node_in_group("dungeon_floor")
		jugador = get_tree().get_first_node_in_group("player") as Node2D
		if piso != null and jugador != null and not get_tree().paused:
			break
	if piso == null or jugador == null:
		print("[FOTOGRAMA] no se monto el piso")
		get_tree().quit(1)
		return
	for i in 60:
		await get_tree().process_frame
	print("[FOTOGRAMA] piso %d  party=%d  enemigos=%d  pickups=%d  nodos=%d" % [Game.current_floor, Game.party.size(),
		get_tree().get_nodes_in_group("enemy").size(), get_tree().get_nodes_in_group("pickup").size(),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])

	# EL PERFIL POR SCRIPT: se llama a mano al _process / _physics_process de cada nodo (VECES veces) y se cronometra.
	# El tiempo del fotograma entero en este PC baila de 3 a 30 ms entre dos medidas iguales; esto no.
	Input.action_press("move_right")
	var por_script: Dictionary = {}   # ruta -> [us por fotograma (todas sus instancias), instancias]
	var todos: Array = []
	_juntar(get_tree().root, todos)
	for n in todos:
		if n == self or not is_instance_valid(n) or not n.is_inside_tree() or not n.can_process():
			continue
		var sc: Script = n.get_script()
		if sc == null:
			continue
		var ruta: String = sc.resource_path.get_file()
		var us: float = 0.0
		for metodo in ["_process", "_physics_process"]:
			if not n.has_method(metodo):
				continue
			if metodo == "_process" and not n.is_processing():
				continue
			if metodo == "_physics_process" and not n.is_physics_processing():
				continue
			var t0: int = Time.get_ticks_usec()
			for k in VECES:
				if not is_instance_valid(n):
					break
				n.call(metodo, 1.0 / 60.0)
			us += float(Time.get_ticks_usec() - t0) / VECES
		if us <= 0.0:
			continue
		var e: Array = por_script.get(ruta, [0.0, 0])
		e[0] += us
		e[1] += 1
		por_script[ruta] = e
	var rutas: Array = por_script.keys()
	rutas.sort_custom(func(a, b): return por_script[a][0] > por_script[b][0])
	var total: float = 0.0
	for r in rutas:
		total += por_script[r][0]
	print("[FOTOGRAMA] TOTAL de script por fotograma: %.2f ms" % (total / 1000.0))
	for r in rutas.slice(0, 25):
		print("[FOTOGRAMA]   %-34s %8.1f us   (%d nodos)" % [r, por_script[r][0], por_script[r][1]])
	_detalle_jugador(jugador)
	var hud2: Node = get_tree().get_first_node_in_group("hud")
	if hud2 != null:
		var t0: int = Time.get_ticks_usec()
		for k in VECES:
			hud2._process(1.0 / 60.0)
		print("[FOTOGRAMA] hud._process %.1f us" % (float(Time.get_ticks_usec() - t0) / VECES))
	_medir_guardado()
	Input.action_release("move_right")
	Input.action_release("move_down")
	get_tree().quit(0)


# EL GUARDADO CONTINUO (Profile._process, cada SEG_GUARDADO): exportar va en UN fotograma, pasar a filas va troceado
# y escribir otra vez en UN fotograma. Se escribe en una base de datos de usar y tirar (user://medir_fotograma.db).
func _medir_guardado() -> void:
	var ids := BDFilas.Ids.new()
	var bd := PartidaBD.new()
	var ruta: String = "user://medir_fotograma.db"
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	if not bd.abrir(ruta):
		print("[FOTOGRAMA] no se pudo abrir la BD de prueba")
		return
	for k in 4:
		var t0: int = Time.get_ticks_usec()
		var datos: SaveData = Game.exportar_partida()
		var t1: int = Time.get_ticks_usec()
		var filas: Dictionary = BDFilas.a_filas(datos, ids)
		var t2: int = Time.get_ticks_usec()
		var esc: int = bd.escribir(filas)
		var t3: int = Time.get_ticks_usec()
		print("[FOTOGRAMA] guardado %d: exportar %.1f ms | a filas %.1f ms (troceado) | escribir %.1f ms (%d)" % [
			k, (t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, esc])


# Media de TIME_PROCESS y TIME_PHYSICS_PROCESS (ms) en MUESTRAS fotogramas, andando en cuadrado.
func _medir(que: String) -> Array:
	var ps: Array = []
	var fs: Array = []
	var peor: float = 0.0
	for i in MUESTRAS:
		var fase: int = (i / 30) % 4
		Input.action_release("move_right"); Input.action_release("move_left")
		Input.action_release("move_down"); Input.action_release("move_up")
		Input.action_press(["move_right", "move_down", "move_left", "move_up"][fase])
		await get_tree().process_frame
		var p: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		var f: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		ps.append(p)
		fs.append(f)
		peor = maxf(peor, p + f)
	ps.sort()
	fs.sort()
	# MEDIANA y no media: un tiron suelto (el recolector, el disco) mueve la media y no dice nada del fotograma normal.
	var r: Array = [ps[MUESTRAS / 2], fs[MUESTRAS / 2]]
	print("[FOTOGRAMA] %-28s proceso %6.2f ms   fisica %6.2f ms   peor %6.2f ms" % [que, r[0], r[1], peor])
	return r


func _juntar(n: Node, out: Array) -> void:
	out.append(n)
	for h in n.get_children():
		_juntar(h, out)


# POR DENTRO DEL JUGADOR (el que mas gasta): cada pieza de su _physics_process, a mano.
func _detalle_jugador(j: Node) -> void:
	var d: float = 1.0 / 60.0
	var piezas: Array = [
		["_refrescar_barras", func(): j._refrescar_barras()],
		["_comprobar_grupo", func(): j._comprobar_grupo()],
		["_actualizar_max_aguante", func(): j._actualizar_max_aguante()],
		["_tick_aguante_companeros", func(): j._tick_aguante_companeros(d, false)],
		["_actualizar_animacion", func(): j._actualizar_animacion(true, d)],
		["_tick_oscuridad", func(): j._tick_oscuridad(d)],
		["_tick_huida", func(): j._tick_huida()],
		["_tick_ruido", func(): j._tick_ruido(d)],
		["_tick_ataque", func(): j._tick_ataque(d)],
		["_enemigo_mas_cercano", func(): j._enemigo_mas_cercano()],
		["_perseguidor", func(): j._perseguidor()],
		["_pj_agotado", func(): j._pj_agotado()],
		["objetivo_interaccion", func(): j.objetivo_interaccion()],
		["Game.tick_heal", func(): Game.tick_heal(d)],
		["Game.tick_mana_pocion", func(): Game.tick_mana_pocion(d)],
		["Game.tick_estados", func(): Game.tick_estados(d)],
		["Game.tick_hechizo_de_entrada", func(): Game.tick_hechizo_de_entrada(d)],
		["Game.estados_speed_mult_grupo", func(): Game.estados_speed_mult_grupo()],
		["Game.agilidad_speed_mult", func(): Game.agilidad_speed_mult()],
		["Game.armor_speed_mult", func(): Game.armor_speed_mult()],
		["Game.overload_speed_factor", func(): Game.overload_speed_factor()],
		["Game.entrando_en_pelea", func(): Game.entrando_en_pelea()],
	]
	# Y por dentro de las barras: lo que hace por cada miembro del grupo (sumado para todos).
	var grupo: Array = j._barras.map(func(f): return f["pj"])
	piezas.append_array([
		["  barras: max_hp x grupo", func(): for pj in grupo: Game.player_max_hp(pj)],
		["  barras: max_mp x grupo", func(): for pj in grupo: Game.player_max_mp(pj)],
		["  barras: hp+mp actual x grupo", func(): for pj in grupo: Game.player_hp(pj); Game.player_mp(pj)],
		["  barras: aguante x grupo", func(): for pj in grupo: j._calc_max_aguante(pj); j._aguante_de(pj)],
		["  vida: Runas.vida_mult x grupo", func(): for pj in grupo: Runas.vida_mult(pj)],
		["  vida: abilities_eff_de x grupo", func(): for pj in grupo: Game.abilities_eff_de(pj)],
		["  vida: StatsMath x grupo", func(): for pj in grupo: StatsMath.max_hp_jugador(Game.abilities_eff_de(pj), pj.base_hp)],
		["  hud: peso_actual", func(): Game.peso_actual()],
		["  hud: capacidad_carga", func(): Game.capacidad_carga()],
		["  hud: luz_total_restante", func(): Game.luz_total_restante()],
		["  hud: radio_lampara", func(): Game.radio_lampara()],
		["  hud: carbon_restante", func(): Game.carbon_restante()],
		["  hud: llama_fraccion", func(): Game.llama_fraccion()],
		["  barras: etiqueta_estados", func(): for pj in grupo: Game.etiqueta_estados(pj)],
		["  barras: cuadro equipo", func(): for f in j._barras: if f.get("equipo") != null: f["equipo"].refrescar_si_toca()],
		["  barras: mis_barras (red)", func(): Net.jugadores.mis_barras([])],
		["  barras: barras_otros", func(): if j._barras_otros != null: j._barras_otros.refrescar()],
	])
	var filas: Array = []
	for p in piezas:
		var t0: int = Time.get_ticks_usec()
		for k in VECES:
			p[1].call()
		filas.append([p[0], float(Time.get_ticks_usec() - t0) / VECES])
	filas.sort_custom(func(a, b): return a[1] > b[1])
	print("[FOTOGRAMA] dentro del jugador:")

	for f in filas:
		print("[FOTOGRAMA]   %-30s %8.1f us" % f)
