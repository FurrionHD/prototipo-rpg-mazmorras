# ============================================================
#  prueba_companeros_pueblo.gd  --  HERRAMIENTA, no parte del juego.
#
#  "Los compañeros atraviesan casas y barriles al seguirme y se pintan raro un momento."
#  Monta el pueblo con el grupo de prueba (3 compañeros), pasea al jugador DE VERDAD (pulsando las
#  teclas, con su choque) alrededor de casas y adornos, andando y corriendo, y apunta en cada frame de
#  fisica:
#    - PISA: la huella de un compañero mete mas de 2 px dentro de algo solido;
#    - SALTO: un compañero se ha movido mas de lo que se puede en un frame (el RESCATE que lo planta).
#  Sin ventana: --headless --path . res://tools/prueba_companeros_pueblo.tscn
# ============================================================
extends Node

const PUEBLO := "res://scenes/levels/town.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

var _pueblo: Node2D = null
var _jugador: CharacterBody2D = null
var _pisa: int = 0
var _saltos: int = 0
var _frames: int = 0
var _antes: Dictionary = {}
var _ultimo_aviso: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PartidaDePrueba.llenar()
	get_tree().current_scene.scene_file_path = PUEBLO
	_pueblo = (load(PUEBLO) as PackedScene).instantiate() as Node2D
	add_child(_pueblo)
	_jugador = _pueblo.get_node("Player") as CharacterBody2D
	await get_tree().physics_frame
	await get_tree().physics_frame
	print("compañeros: %d" % _companeros().size())
	# EL DETECTOR DETECTA: un compañero plantado en mitad de la taberna tiene que dar PISA.
	var c0 := _companeros()[0] as CharacterBody2D
	var guarda: Vector2 = c0.global_position
	c0.global_position = PuebloPlano.centro_px(Vector2i(33, 30))
	_medir()
	print("detector (tiene que ser 1): %d" % _pisa)
	_pisa = 0
	_antes.clear()
	c0.global_position = guarda

	# RUTAS: casillas por las que pasar, en orden. Rodean casas y adornos pegandose a ellos.
	var rutas := {
		# Vuelta a la taberna cortando las cuatro esquinas en diagonal.
		"taberna (vuelta en diagonal)": [Vector2i(30, 33), Vector2i(37, 33), Vector2i(36, 27), Vector2i(30, 28), Vector2i(31, 33), Vector2i(37, 33)],
		# Rozando los barriles por delante, de un lado a otro, y de vuelta.
		"taberna (barriles)": [Vector2i(29, 33), Vector2i(37, 33), Vector2i(33, 32), Vector2i(29, 33)],
		"tienda (vuelta en diagonal)": [Vector2i(30, 24), Vector2i(37, 24), Vector2i(36, 18), Vector2i(30, 19), Vector2i(31, 24)],
		"cocina (barril, zigzag)": [Vector2i(10, 33), Vector2i(3, 33), Vector2i(4, 28), Vector2i(10, 29), Vector2i(9, 33)],
		"herreria (yunque, diagonal)": [Vector2i(38, 24), Vector2i(45, 24), Vector2i(44, 19), Vector2i(39, 20), Vector2i(40, 24)],
	}
	# Headless el reloj de fisica va a lo que puede: sin tope, cada frame es un frame.
	Engine.max_fps = 0
	for correr in [false, true]:
		for nombre in rutas:
			await _recorrer("%s %s" % [nombre, "CORRIENDO" if correr else "andando"], rutas[nombre], correr)
	print("\nframes: %d   PISA: %d   SALTOS: %d" % [_frames, _pisa, _saltos])
	get_tree().quit(0)


func _companeros() -> Array:
	return get_tree().get_nodes_in_group("aliado").filter(func(n): return n != _jugador)


func _recorrer(nombre: String, casillas: Array, correr: bool) -> void:
	print("\n=== %s ===" % nombre)
	# Se planta al jugador en la primera y se resiembra la fila, como al llegar.
	var destino: Vector2i = casillas[0]
	_jugador.global_position = PuebloPlano.centro_px(destino)
	var seq: Node = _jugador.get("_sequito")
	if seq != null and seq.has_method("teletransportar"):
		seq.teletransportar()
	# La fila se tiende un paso de fisica despues (ver party_trail.teletransportar).
	await get_tree().physics_frame
	await get_tree().physics_frame
	_antes.clear()
	for i in range(1, casillas.size()):
		# DIRECTO: sin rodeo por casillas, tecla hacia el siguiente punto y a resbalar por las paredes,
		# que es como anda alguien de verdad (cortando esquinas).
		var camino: Array = [casillas[i]]
		for c in camino:
			var meta: Vector2 = PuebloPlano.centro_px(c) - Vector2(0.0, PoseJugador.HUELLA_Y)
			var t: int = 0
			while _jugador.global_position.distance_to(meta) > 5.0 and t < 240:
				_pulsar(meta - _jugador.global_position, correr)
				await get_tree().physics_frame
				_medir()
				t += 1
			if t >= 240:
				print("  (atascado yendo a %s, jugador en %s)" % [c, _jugador.global_position.round()])
		print("  tramo hasta %s: jugador en %s  [%d ms]" % [casillas[i], _jugador.global_position.round(), Time.get_ticks_msec()])
	_soltar()
	# Que la fila llegue y se pare.
	for k in 40:
		await get_tree().physics_frame
		_medir()


func _pulsar(d: Vector2, correr: bool) -> void:
	_soltar()
	if d.x > 2.0:
		Input.action_press(&"move_right")
	elif d.x < -2.0:
		Input.action_press(&"move_left")
	if d.y > 2.0:
		Input.action_press(&"move_down")
	elif d.y < -2.0:
		Input.action_press(&"move_up")
	if correr:
		Input.action_press(&"correr")


func _soltar() -> void:
	for a in [&"move_right", &"move_left", &"move_up", &"move_down", &"correr"]:
		Input.action_release(a)


func _medir() -> void:
	_frames += 1
	var espacio: PhysicsDirectSpaceState2D = _pueblo.get_world_2d().direct_space_state
	for c in _companeros():
		var cb := c as CharacterBody2D
		var p: Vector2 = cb.global_position
		if _antes.has(cb) and (_antes[cb] as Vector2).distance_to(p) > 12.0:
			_saltos += 1
			print("  SALTO %s: %s -> %s (%.0f px)  jugador en %s" % [cb.name, _antes[cb], p,
				(_antes[cb] as Vector2).distance_to(p), _jugador.global_position.round()])
		_antes[cb] = p
		# La huella encogida 2 px por lado: tocar la pared es legal, meterse dentro no.
		var forma := RectangleShape2D.new()
		forma.size = PoseJugador.HUELLA - Vector2(4, 4)
		var q := PhysicsShapeQueryParameters2D.new()
		q.shape = forma
		q.transform = Transform2D(0.0, p + Vector2(0.0, PoseJugador.HUELLA_Y))
		q.collision_mask = 1
		q.exclude = [_jugador.get_rid()]
		if not espacio.intersect_shape(q, 1).is_empty():
			_pisa += 1
			if _frames - int(_ultimo_aviso.get(cb, -100)) > 30:
				print("  PISA %s en %s (casilla %s)  jugador en %s" % [cb.name, p.round(),
					Vector2i((p / 32.0).floor()), _jugador.global_position.round()])
			_ultimo_aviso[cb] = _frames


# BFS por casillas no solidas.
func _camino(a: Vector2i, b: Vector2i) -> Array:
	var prev := {a: a}
	var cola: Array[Vector2i] = [a]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		if c == b:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if PuebloPlano.dentro(n) and not prev.has(n) and not PuebloPlano.solida(n):
				prev[n] = c
				cola.append(n)
	if not prev.has(b):
		print("  (sin camino %s -> %s)" % [a, b])
		return []
	var out: Array = []
	var k: Vector2i = b
	while k != a:
		out.push_front(k)
		k = prev[k]
	return out
