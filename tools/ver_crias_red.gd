# HERRAMIENTA (CON VENTANA). Las CRIAS EN MULTIJUGADOR (13/10, C3 del playtest 11/10: el slime brotado y el Rey
# Slime, sus crias en red salian mal "incluso siendo solo una persona"). Sala de verdad con trabajadores: la pelea
# la ejecuta un trabajador de pelea y esta ventana es el ESPEJO, lo que ve el jugador.
#   1) Un slime brotado: le pegas hasta que cae y se divide, y luego solo PASAS turnos para que les toque a las crias.
#   2) El Rey Slime: solo pasas turnos hasta que suelta su Brote y las crias juegan.
# De verdad, no muñecos: el muñeco de la arena no usa habilidades (ni el Brote del Rey ni las de las crias).
# Un solo personaje en el grupo (los compañeros mataban a las crias antes de que les tocara).
#   godot --path . res://tools/ver_crias_red.tscn
# EN VIDEO: VER_SALIR=1 godot --path . --write-movie X.avi --fixed-fps 30 res://tools/ver_crias_red.tscn
# Solo una: VER_SOLO=brotado o VER_SOLO=rey.
extends Node

const PUERTO := 24599
const TURNOS_CRIAS := 6       # turnos tuyos que pasas despues de que salgan las crias
const T_ESCENA_S := 120.0

var _salir: bool = OS.get_environment("VER_SALIR") != ""


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	var solo: Array[PersonajeData] = [Game.lider()]
	Game.party = solo
	Game.lider_idx = 0
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(1.5)
	var err := Net.hostear("abc", PUERTO)
	print("[ver] sala abierta: %s" % ("si" if err == OK else "NO (%d)" % err))
	var t := 0.0
	while _trabajador_libre() == 0 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	print("[ver] trabajador listo en %.1f s" % t)
	Game.entrar_arena_de_pruebas()
	t = 0.0
	while (get_tree().get_first_node_in_group("dungeon_floor") == null or not Game.es_arena()) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	await _esperar(3.0)
	Cargando.ocultar()
	print("[ver] en la arena (dueño del piso: %s)" % str(Net._dueno_piso.get(Game.PISO_ARENA, 0)))
	var que: String = OS.get_environment("VER_SOLO")
	if que in ["", "brotado"]:
		await _escena("SLIME BROTADO", "res://scenes/actors/enemy/slime.tres", {"mutacion": "brotado"}, true)
	if que in ["", "rey"]:
		await _escena("REY SLIME", "res://scenes/actors/enemy/rey_slime.tres", {}, false)
	print("[ver] FIN")
	if _salir:
		Net.desconectar()
		await _esperar(2.0)
		get_tree().quit(0)


func _trabajador_libre() -> int:
	for w in Net._trab._estado:
		if int(Net._trab._estado[w]) == 0:
			return w
	return 0


func _escena(titulo: String, ruta: String, muneco: Dictionary, pegarle: bool) -> void:
	print("[ver] ===== %s =====" % titulo)
	var tc := 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas._desgaste_pendiente) and tc < 10.0:
		await _esperar(0.25)
		tc += 0.25
	# Como en el juego: la pelea la monta el trabajador DE PELEA que espera en el piso (si no lo hay aun, iria en mi PC).
	var tw := 0.0
	while Net._trab.pelea_libre_en(Game.PISO_ARENA) == 0 and tw < 30.0:
		await _esperar(0.5)
		tw += 0.5
	print("[ver] trabajador de pelea esperando en la arena: %d (%.1f s)" % [Net._trab.pelea_libre_en(Game.PISO_ARENA), tw])
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var antes: Array = Net.enemigos._enem_nodos.keys()
	# Lejos de mi (que no me vea y me embista mientras el trabajador de pelea se entera de que existe).
	var sala_px: Vector2 = jug.global_position + Vector2(0, 160)
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null:
		var sala: Rect2i = piso.gen.salas[0]
		var c: float = float(DungeonGenerator.CELDA)
		sala_px = Vector2(sala.position.x + 6, sala.end.y - 4) * c
		jug.recolocar(Vector2(sala.end.x - 6, sala.position.y + 4) * c)
	Net.pisos.pedir_spawn_arena(ruta, sala_px, muneco)
	var presa: Node2D = null
	var t := 0.0
	while presa == null and t < 10.0:
		for nid in Net.enemigos._enem_nodos:
			var n = Net.enemigos._enem_nodos[nid]
			if nid not in antes and is_instance_valid(n) and not n.esta_muerto():
				presa = n
		await _esperar(0.25)
		t += 0.25
	if presa == null:
		print("[ver] MAL: no aparece el enemigo pedido")
		return
	print("[ver] aparece %s (mutacion '%s')" % [presa.name, str(presa.get("mutacion"))])
	# Que el trabajador de pelea ya lo tenga apuntado (recien nacido, con 1 s decia "0 de 1 bichos" y la montaba yo).
	await _esperar(4.0)
	# Le ataco YO nada mas llegar: si me embiste el primero, en esta rama la pelea se monta en mi PC (A1, arreglado en
	# fix/peleas-red) y no se veria el espejo, que es lo que falla.
	jug.recolocar(presa.global_position + Vector2(0, -110))
	presa.atacado_por_jugador(0.3)
	t = 0.0
	while not Game.hay_pelea_en_pantalla() and t < 10.0:
		await _esperar(0.25)
		t += 0.25
	var p: Node = Net.peleas._pantalla_combate()
	if p == null:
		print("[ver] MAL: no se abre la pelea")
		return
	print("[ver] pelea abierta (la ejecuta el trabajador %d; aqui, espejo: %s)" % [Net.peleas._pelea_anfitrion,
		str(Net.peleas.espejando())])
	await _esperar(1.0)
	Cargando.ocultar()
	# A JUGAR: le pego al brotado hasta que cae; despues (y con el Rey, desde el principio) solo paso turnos.
	var pasados: int = 0
	var vistas: int = 1
	t = 0.0
	while is_instance_valid(p) and not p.acabada() and t < T_ESCENA_S and pasados < TURNOS_CRIAS:
		p = _pantalla(p)
		var vivos: Array = p._enemies.filter(func(e): return e.is_alive())
		if vivos.size() != vistas:
			print("[ver] %.1f s: en la pelea %d enemigos vivos: %s" % [t, vivos.size(), ", ".join(vivos.map(func(e): return e.nombre))])
			vistas = vivos.size()
		var brotado_vivo: bool = vivos.any(func(e): return String(e.get("mutacion")) == "brotado")
		var crias: bool = vivos.size() > 1
		if int(p.get("_state")) == 1 and not _caja_abierta(p):
			if pegarle and brotado_vivo:
				if not _pulsar(p, 0):
					await _andar_hacia_objetivo(p)
			elif _pasar(p) and crias:
				pasados += 1
				print("[ver] %.1f s: paso mi turno (%d de %d)" % [t, pasados, TURNOS_CRIAS])
		await _esperar(0.25)
		t += 0.25
	# El brotado: remato a las crias (que se vea tambien como les pega uno) y la pelea acaba limpia.
	t = 0.0
	while pegarle and is_instance_valid(p) and not p.acabada() and t < 40.0:
		p = _pantalla(p)
		if int(p.get("_state")) == 1 and not _caja_abierta(p) and not _pulsar(p, 0):
			await _andar_hacia_objetivo(p)
		await _esperar(0.25)
		t += 0.25
	print("[ver] %s: la pelea %s" % [titulo, "acaba" if is_instance_valid(p) and p.acabada() else "sigue (huyo)"])
	await _esperar(2.0)
	# Fuera de la pelea: huyo (desde el borde) o, si acabo, Continuar. Y la arena limpia para la siguiente.
	if is_instance_valid(p) and p.acabada():
		p._on_continue_pressed()
	else:
		await _huir(p)
	t = 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas._desgaste_pendiente) and t < 10.0:
		await _esperar(0.25)
		t += 0.25
	Net.pisos.pedir_limpiar_arena()
	await _esperar(2.0)


# La pantalla de la pelea de AHORA (la del espejo se rehace al llegar la pelea del trabajador).
func _pantalla(p: Node) -> Node:
	var q: Node = Net.peleas._pantalla_combate()
	return q if q != null else p


func _caja_abierta(p: Node) -> bool:
	for caja in ["_cast_box", "_ability_box", "_objeto_box", "_spell_box"]:
		var c: Control = p.get(caja)
		if c != null and c.visible:
			return true
	return false


func _pulsar(p: Node, id: int) -> bool:
	var b: BaseButton = (p.get("_action_buttons") as Dictionary).get(id)
	if b == null or b.disabled or not b.is_visible_in_tree():
		return false
	b.pressed.emit()
	return true


# PASAR: en mitad de la zona, Huir es Pasar; si estoy en el borde, Defender.
func _pasar(p: Node) -> bool:
	if p._huir_es_pasar():
		return _pulsar(p, 5)
	return _pulsar(p, 3)


func _huir(p: Node) -> void:
	var t := 0.0
	while is_instance_valid(p) and not p.acabada() and Game.hay_pelea_en_pantalla() and t < 20.0:
		if int(p.get("_state")) == 1 and not _caja_abierta(p):
			var tm = p.turno_mapa
			if tm._fase == tm.Fase.MOVIENDO and is_instance_valid(tm._cuerpo) and not tm.en_el_borde():
				for k in 24:
					var q: Vector2 = tm._inicio + Vector2.RIGHT.rotated(TAU * k / 24.0) * (tm._radio - 4.0)
					if tm._puede_estar(q, tm._cuerpo) and tm._en_arena(q):
						tm._colocar(tm._quien, tm._cuerpo, q)
						break
			_pulsar(p, 5)
		await _esperar(0.25)
		t += 0.25


func _andar_hacia_objetivo(p: Node) -> void:
	var tm = p.get("turno_mapa")
	if tm == null or tm._fase != tm.Fase.MOVIENDO or not is_instance_valid(tm._cuerpo):
		return
	var antes: Vector2 = tm._cuerpo.global_position
	var mejor: Node2D = null
	for e in p._enemies:
		var ce: Node2D = tm.cuerpo_de(e) if e.is_alive() else null
		if ce != null and (mejor == null or ce.global_position.distance_to(antes) < mejor.global_position.distance_to(antes)):
			mejor = ce
	if mejor == null:
		return
	for r in [22.0, 30.0, 40.0, 60.0]:
		for k in 12:
			var q: Vector2 = mejor.global_position + Vector2.RIGHT.rotated(TAU * float(k) / 12.0) * r
			if q.distance_to(tm._inicio) <= tm._radio and tm._puede_estar(q, tm._cuerpo) and tm._en_arena(q):
				tm._colocar(tm._quien, tm._cuerpo, q)
				return
	# Ni a tiro de un paso: hasta el borde de mi circulo, hacia el.
	var q2: Vector2 = tm._inicio + (mejor.global_position - tm._inicio).normalized() * (tm._radio - 4.0)
	if tm._puede_estar(q2, tm._cuerpo):
		tm._colocar(tm._quien, tm._cuerpo, q2)
