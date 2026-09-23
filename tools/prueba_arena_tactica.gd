# ============================================================
#  PRUEBA: EL RECTANGULO DE LA ARENA
#  Genera pisos de verdad (el mismo DungeonGenerator del juego) y suelta arenas en MUCHOS puntos al
#  azar de cada uno, comprobando sin ventana que:
#    1) la arena cae dentro del mapa;
#    2) es casi toda suelo (se tolera la roca suelta de las estalagmitas);
#    3) la semilla queda DENTRO de su propia arena -- si no, peleas fuera del sitio donde peleas;
#    4) nunca se pasa de lo que se pidio;
#    5) `cabe()` y el tamaño real dicen lo mismo (el que dice que si, entrega ARENA_MIN o mas);
#    6) un jefe saca mas sitio que un bicho normal en la misma sala;
#    7) es DETERMINISTA: la misma semilla y el mismo punto dan el mismo rectangulo.
#
#    godot --headless --path . res://tools/prueba_arena_tactica.tscn
# ============================================================
extends Node

const PISOS := 12          # cuantos pisos distintos se prueban
const PUNTOS_POR_PISO := 60  # cuantas peleas se sueltan en cada uno

var _fallos: int = 0
var _casos: int = 0
# Cuantas arenas salieron demasiado pequeñas para el tactico. No es un fallo (un pasillo estrecho es
# un no legitimo), pero si fueran casi todas, el tactico no se jugaria nunca: por eso se cuenta.
var _pequenas: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260923

	for p in PISOS:
		var gen := DungeonGenerator.new()
		gen.generar(80, 60, 1000 + p * 7)
		_probar_piso(gen, rng, p)

	_probar_determinismo()
	_probar_borde()

	print("[arena] %d casos, %d pequeñas (sin tactico), %d fallos" % [_casos, _pequenas, _fallos])
	print("[arena] RESULTADO: %s" % ("TODO BIEN" if _fallos == 0 else "HAY FALLOS"))
	get_tree().quit(1 if _fallos > 0 else 0)


func _probar_piso(gen: DungeonGenerator, rng: RandomNumberGenerator, piso: int) -> void:
	# Los puntos se sortean entre las celdas de SUELO: soltar peleas dentro de la roca no prueba nada.
	var suelo: Array[Vector2i] = []
	for y in gen.alto:
		for x in gen.ancho:
			var c := Vector2i(x, y)
			if gen.es_suelo(c):
				suelo.append(c)
	if suelo.is_empty():
		_fallo("piso %d sin una sola celda de suelo" % piso)
		return

	for i in PUNTOS_POR_PISO:
		var celda: Vector2i = suelo[rng.randi_range(0, suelo.size() - 1)]
		var px: Vector2 = gen.centro_px(celda)
		var combatientes: int = rng.randi_range(2, 12)
		var hay_jefe: bool = rng.randf() < 0.2
		var deseado: Vector2i = ArenaCalculo.tam_deseado(combatientes, hay_jefe)
		var r: Rect2i = ArenaCalculo.rect_de_arena(gen, px, deseado)
		_casos += 1
		_comprobar(gen, r, celda, deseado, "piso %d punto %d" % [piso, i])

	# 6) EL JEFE SACA MAS SITIO. Se mide en la sala mas grande, que es donde hay margen de sobra para
	#    que la diferencia se note (en un pasillo los dos chocan con la misma pared y empatan).
	var mejor := Rect2i()
	for z in gen.zonas:
		if String(z["tipo"]) == "sala":
			var r2: Rect2i = z["rect"]
			if r2.size.x * r2.size.y > mejor.size.x * mejor.size.y:
				mejor = r2
	if mejor.size.x > 0:
		var centro: Vector2 = gen.centro_px(mejor.position + mejor.size / 2)
		var normal: Rect2i = ArenaCalculo.rect_de_arena(gen, centro,
			ArenaCalculo.tam_deseado(3, false))
		var jefe: Rect2i = ArenaCalculo.rect_de_arena(gen, centro,
			ArenaCalculo.tam_deseado(3, true))
		var area_n: int = normal.size.x * normal.size.y
		var area_j: int = jefe.size.x * jefe.size.y
		# >= y no >: en una sala justa los dos se comen la sala entera, y eso es correcto.
		_afirmar(area_j >= area_n,
			"piso %d: el jefe (%d celdas) no saca menos sitio que un normal (%d)"
			% [piso, area_j, area_n])


func _comprobar(gen: DungeonGenerator, r: Rect2i, semilla: Vector2i,
		deseado: Vector2i, donde: String) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		_fallo("%s: arena vacia sobre una celda de suelo" % donde)
		return

	# 1) DENTRO DEL MAPA.
	_afirmar(r.position.x >= 0 and r.position.y >= 0
		and r.position.x + r.size.x <= gen.ancho and r.position.y + r.size.y <= gen.alto,
		"%s: la arena %s se sale del mapa (%dx%d)" % [donde, r, gen.ancho, gen.alto])

	# 2) CASI TODO SUELO. El tope es generoso a proposito: la via de la SALA admite las estalagmitas
	#    que haya dentro, y una sala decorada puede tener unas cuantas. Lo que no puede pasar es que
	#    la arena se coma media pared.
	var roca: int = 0
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if gen.es_solido(Vector2i(x, y)):
				roca += 1
	var celdas: int = r.size.x * r.size.y
	_afirmar(float(roca) / float(celdas) <= 0.25,
		"%s: la arena %s es roca en un %d%% (%d de %d)"
		% [donde, r, roundi(100.0 * float(roca) / float(celdas)), roca, celdas])

	# 3) LA SEMILLA, DENTRO.
	_afirmar(r.has_point(semilla),
		"%s: la semilla %s se queda fuera de su arena %s" % [donde, semilla, r])

	# 4) NUNCA MAS DE LO PEDIDO.
	_afirmar(r.size.x <= deseado.x and r.size.y <= deseado.y,
		"%s: la arena %s se pasa de lo pedido %s" % [donde, r, deseado])

	# 5) COHERENCIA CON cabe().
	var cabe: bool = ArenaCalculo.cabe(gen, gen.centro_px(semilla), deseado)
	var grande: bool = r.size.x >= ArenaCalculo.ARENA_MIN.x and r.size.y >= ArenaCalculo.ARENA_MIN.y
	_afirmar(cabe == grande,
		"%s: cabe() dice %s pero la arena mide %s" % [donde, cabe, r.size])
	if not grande:
		_pequenas += 1


# 7) DETERMINISTA. Dos peleas iguales en el mismo sitio tienen que dar la MISMA arena: en multi la
#    calcula el anfitrion y viaja al espejo, pero si un dia se recalculara, tiene que dar lo mismo.
func _probar_determinismo() -> void:
	var a := DungeonGenerator.new()
	a.generar(80, 60, 4242)
	var b := DungeonGenerator.new()
	b.generar(80, 60, 4242)
	var iguales: bool = true
	var vistos: int = 0
	for y in range(0, a.alto, 3):
		for x in range(0, a.ancho, 3):
			var c := Vector2i(x, y)
			if not a.es_suelo(c):
				continue
			vistos += 1
			var d: Vector2i = ArenaCalculo.tam_deseado(5, false)
			if ArenaCalculo.rect_de_arena(a, a.centro_px(c), d) \
					!= ArenaCalculo.rect_de_arena(b, b.centro_px(c), d):
				iguales = false
	_afirmar(vistos > 0, "determinismo: no se probo ni un punto")
	_afirmar(iguales, "determinismo: la misma semilla da arenas distintas")


# LAS TRES REGLAS DEL BORDE. Se montan cuerpos de mentira (Node2D pelados) y se les mueve a mano:
# la arena no sabe nada de jugadores ni de bichos, solo mira posiciones y grupos.
func _probar_borde() -> void:
	var arena: ArenaCombate = ArenaCombate.montar(self, Rect2i(10, 10, 12, 10))
	var r: Rect2 = arena.rect

	var dentros: Array = []
	var entradas: Array = []
	var preguntas: Array = []
	arena.borde_desde_dentro.connect(func(c): dentros.append(c))
	arena.enemigo_entra.connect(func(c, p): entradas.append({"c": c, "p": p}))
	arena.jugador_pregunta.connect(func(c): preguntas.append(c))

	# --- 1) DE DENTRO: acercarse al borde propone huir, UNA vez.
	var yo := Node2D.new()
	add_child(yo)
	arena.en_pelea.append(yo)
	yo.global_position = r.get_center()
	arena.vigilar([])
	_afirmar(dentros.is_empty(), "borde: en el centro no deberia proponer huir")

	yo.global_position = Vector2(r.position.x + 4.0, r.get_center().y)
	arena.vigilar([])
	arena.vigilar([])   # otra vuelta: NO puede repetir la propuesta
	_afirmar(dentros.size() == 1,
		"borde: la propuesta de huir salio %d veces, tenia que salir 1" % dentros.size())

	# Se despega y vuelve: se le propone otra vez.
	yo.global_position = r.get_center()
	arena.vigilar([])
	yo.global_position = Vector2(r.position.x + 4.0, r.get_center().y)
	arena.vigilar([])
	_afirmar(dentros.size() == 2, "borde: al volver al muro no se le vuelve a proponer huir")

	# --- 2) DE FUERA, ENEMIGO: entra, y entra DENTRO.
	var bicho := Node2D.new()
	add_child(bicho)
	bicho.global_position = Vector2(r.position.x + r.size.x + 4.0, r.get_center().y)
	arena.vigilar([bicho])
	_afirmar(entradas.size() == 1, "borde: el enemigo de fuera no entro")
	if not entradas.is_empty():
		var p: Vector2 = entradas[0]["p"]
		_afirmar(arena.contiene(p), "borde: el enemigo entro en %s, que esta FUERA de %s" % [p, r])

	# Dos por el mismo sitio quedan escalonados, no encima.
	var bicho2 := Node2D.new()
	add_child(bicho2)
	bicho2.global_position = bicho.global_position
	arena.vigilar([bicho, bicho2])
	_afirmar(entradas.size() == 2, "borde: el segundo enemigo no entro")
	if entradas.size() == 2:
		var d: float = (entradas[0]["p"] as Vector2).distance_to(entradas[1]["p"])
		_afirmar(d >= ArenaCombate.SEPARACION_ENTRADA - 0.01,
			"borde: dos enemigos entraron encima (a %.1f px, minimo %.1f)"
			% [d, ArenaCombate.SEPARACION_ENTRADA])

	# --- 3) DE FUERA, JUGADOR: se le pregunta; si dice que NO, atraviesa sin mas preguntas.
	var otro := Node2D.new()
	otro.add_to_group("aliado")
	add_child(otro)
	otro.global_position = Vector2(r.get_center().x, r.position.y - 4.0)
	arena.vigilar([otro])
	_afirmar(preguntas.size() == 1, "borde: al jugador de fuera no se le pregunto")
	_afirmar(entradas.size() == 2, "borde: el jugador entro como si fuera un bicho")

	arena.dijo_que_no(otro)
	var antes: int = preguntas.size()
	# Lo cruza de lado a lado: ni una pregunta mas. El recorrido acaba DENTRO a proposito -- pasarse
	# de largo le soltaria el pestillo, que es justo lo que se comprueba despues.
	for k in 9:
		otro.global_position = Vector2(r.get_center().x,
			r.position.y - 4.0 + r.size.y * (float(k) / 9.0))
		arena.vigilar([otro])
	_afirmar(preguntas.size() == antes,
		"borde: al que dijo que no se le volvio a preguntar mientras cruzaba")
	_afirmar(arena.esta_de_paso(otro),
		"borde: el que dijo que no tendria que contar como 'de paso' (no se le pinta)")

	# Se va lejos y vuelve: ahora SI se le pregunta otra vez (lo pidio el usuario).
	otro.global_position = r.get_center() + Vector2(0.0, -r.size.y * 3.0)
	arena.vigilar([otro])
	_afirmar(not arena.esta_de_paso(otro),
		"borde: al alejarse tendria que soltarse el pestillo del 'no'")
	otro.global_position = Vector2(r.get_center().x, r.position.y - 4.0)
	arena.vigilar([otro])
	_afirmar(preguntas.size() == antes + 1,
		"borde: al volver a chocar no se le volvio a preguntar")

	# --- recortar_dentro: cualquier punto acaba dentro.
	for p2 in [Vector2(-500, -500), Vector2(9999, 9999), r.get_center()]:
		_afirmar(arena.contiene(arena.recortar_dentro(p2)),
			"borde: recortar_dentro(%s) dejo el punto fuera" % p2)

	arena.queue_free()


func _afirmar(ok: bool, mensaje: String) -> void:
	if not ok:
		_fallo(mensaje)


func _fallo(mensaje: String) -> void:
	_fallos += 1
	if _fallos <= 20:   # con un fallo sistematico, 700 lineas iguales no ayudan
		print("[arena] FALLO  %s" % mensaje)
