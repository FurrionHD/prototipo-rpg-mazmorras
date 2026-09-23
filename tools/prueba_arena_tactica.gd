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


func _afirmar(ok: bool, mensaje: String) -> void:
	if not ok:
		_fallo(mensaje)


func _fallo(mensaje: String) -> void:
	_fallos += 1
	if _fallos <= 20:   # con un fallo sistematico, 700 lineas iguales no ayudan
		print("[arena] FALLO  %s" % mensaje)
