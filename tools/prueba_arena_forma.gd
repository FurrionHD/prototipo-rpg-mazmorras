# ============================================================
#  PRUEBA: LA ARENA CON LA FORMA DEL SITIO (03/10/2026, combate tactico en la mazmorra)
#  Pisos de verdad, peleas soltadas al azar por el suelo, y comprueba sin ventana que:
#    1) en el suelo SIEMPRE sale arena (el 19% de pasillos que antes no daba, ya da);
#    2) la superficie es la pedida: el rectangulo si cabe en la sala, y si no las mismas celdas;
#    3) el relleno es todo suelo, de una pieza, y la semilla esta dentro;
#    4) el borde solo va por donde se puede salir (nunca contra la roca);
#    5) recortar_dentro deja cualquier punto dentro, y el centro de una celda de arena esta dentro;
#    6) es DETERMINISTA.
#
#    godot --headless --path . res://tools/prueba_arena_forma.tscn
# ============================================================
extends Node

const PISOS := 12
const PUNTOS_POR_PISO := 60

var _fallos: int = 0
var _casos: int = 0
var _rellenos: int = 0
var _largo_max: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261003
	for p in PISOS:
		var gen := DungeonGenerator.new()
		gen.generar(80, 60, 1000 + p * 7)
		_probar_piso(gen, rng, p)
	_probar_determinismo()
	print("[forma] %d casos, %d con relleno (no cabian en su sala), lado mas largo %d celdas, %d fallos"
		% [_casos, _rellenos, _largo_max, _fallos])
	print("[forma] RESULTADO: %s" % ("TODO BIEN" if _fallos == 0 else "HAY FALLOS"))
	get_tree().quit(1 if _fallos > 0 else 0)


func _probar_piso(gen: DungeonGenerator, rng: RandomNumberGenerator, piso: int) -> void:
	var suelo: Array[Vector2i] = []
	for y in gen.alto:
		for x in gen.ancho:
			if gen.es_suelo(Vector2i(x, y)):
				suelo.append(Vector2i(x, y))
	for i in PUNTOS_POR_PISO:
		var celda: Vector2i = suelo[rng.randi_range(0, suelo.size() - 1)]
		var deseado: Vector2i = ArenaCalculo.tam_deseado(rng.randi_range(2, 12), rng.randf() < 0.2)
		var f: Dictionary = ArenaCalculo.forma_de_arena(gen, gen.centro_px(celda), deseado)
		_casos += 1
		_comprobar(gen, f, celda, deseado, "piso %d punto %d" % [piso, i])


func _comprobar(gen: DungeonGenerator, f: Dictionary, semilla: Vector2i, deseado: Vector2i,
		donde: String) -> void:
	var r: Rect2i = f["rect"]
	var m: PackedByteArray = f["mascara"]
	# 1) SIEMPRE HAY ARENA.
	if not r.has_area():
		_fallo("%s: sin arena sobre una celda de suelo" % donde)
		return
	_largo_max = maxi(_largo_max, maxi(r.size.x, r.size.y))
	var celdas: Array[Vector2i] = []
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if ArenaCalculo.en_forma(r, m, Vector2i(x, y)):
				celdas.append(Vector2i(x, y))
	# 3) La semilla, dentro.
	_afirmar(ArenaCalculo.en_forma(r, m, semilla), "%s: la semilla %s fuera de su arena" % [donde, semilla])
	if m.is_empty():
		# 2a) EL RECTANGULO: lo pedido, y dentro de una sala.
		_afirmar(r.size == deseado, "%s: rectangulo %s y se pidio %s" % [donde, r.size, deseado])
		var z: int = gen.zona_en(semilla)
		_afirmar(z >= 0 and String(gen.zonas[z]["tipo"]) == "sala"
			and (gen.zonas[z]["rect"] as Rect2i).encloses(r), "%s: rectangulo %s fuera de su sala" % [donde, r])
	else:
		_rellenos += 1
		# 2b) LA MISMA SUPERFICIE.
		_afirmar(celdas.size() == deseado.x * deseado.y,
			"%s: relleno de %d celdas y se pedian %d" % [donde, celdas.size(), deseado.x * deseado.y])
		# 3) Todo suelo y de una pieza.
		for c in celdas:
			if not gen.es_suelo(c):
				_fallo("%s: el relleno se mete en la roca en %s" % [donde, c])
				break
		var vistas: Dictionary = {celdas[0]: true}
		var cola: Array[Vector2i] = [celdas[0]]
		while not cola.is_empty():
			var c: Vector2i = cola.pop_back()
			for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var v: Vector2i = c + d
				if not vistas.has(v) and ArenaCalculo.en_forma(r, m, v):
					vistas[v] = true
					cola.append(v)
		_afirmar(vistas.size() == celdas.size(), "%s: el relleno esta partido en trozos" % donde)

	# 4) y 5) LA ARENA MONTADA con el trazado: el borde nunca contra la roca, y nada se sale.
	var arena: ArenaCombate = ArenaCombate.montar(self, r, m)
	arena.poner_forma(r, m, gen)
	var cel: float = float(DungeonGenerator.CELDA)
	for tr in arena.tramos:
		var medio: Vector2 = ((tr["a"] as Vector2) + (tr["b"] as Vector2)) * 0.5
		var fuera: Vector2i = ArenaCalculo.celda_de_px(medio - (tr["n"] as Vector2) * cel * 0.5)
		_afirmar(gen.es_suelo(fuera), "%s: hay borde contra la roca en %s" % [donde, fuera])
	for c in celdas:
		var centro: Vector2 = (Vector2(c) + Vector2(0.5, 0.5)) * cel
		if not arena.contiene(centro):
			_fallo("%s: el centro de la celda %s no cuenta como dentro" % [donde, c])
			break
	for p in [Vector2(-500, -500), Vector2(9999, 9999), arena.rect.get_center(),
			arena.rect.position - Vector2(20, 20), arena.rect.end + Vector2(20, 0)]:
		var q: Vector2 = arena.recortar_dentro(p)
		_afirmar(arena.contiene(q), "%s: recortar_dentro(%s) = %s, fuera" % [donde, p, q])
	arena.free()


func _probar_determinismo() -> void:
	var a := DungeonGenerator.new()
	a.generar(80, 60, 4242)
	var b := DungeonGenerator.new()
	b.generar(80, 60, 4242)
	var d: Vector2i = ArenaCalculo.tam_deseado(8, false)
	for y in range(0, a.alto, 3):
		for x in range(0, a.ancho, 3):
			var c := Vector2i(x, y)
			if not a.es_suelo(c):
				continue
			var fa: Dictionary = ArenaCalculo.forma_de_arena(a, a.centro_px(c), d)
			var fb: Dictionary = ArenaCalculo.forma_de_arena(b, b.centro_px(c), d)
			if fa["rect"] != fb["rect"] or fa["mascara"] != fb["mascara"]:
				_fallo("determinismo: %s da arenas distintas" % c)
				return


func _afirmar(ok: bool, mensaje: String) -> void:
	if not ok:
		_fallo(mensaje)


func _fallo(mensaje: String) -> void:
	_fallos += 1
	if _fallos <= 20:
		print("[forma] FALLO  %s" % mensaje)
