# ============================================================
#  probar_vision.gd  --  HERRAMIENTA, no parte del juego.
#
#  Comprueba LA REGLA de la visibilidad contra el caso que la definio (el dibujo del usuario):
#  dos aliados con farolillo, uno al otro lado de un muro y otro con linea recta despejada.
#      - al de detras del muro NO se le ve, aunque tenga su propia luz;
#      - al de la linea despejada SI, aunque tu luz no le llegue.
#  Y de paso que el radio minimo se respeta y que la roca corta la luz.
#
#  Escupe el mapa en texto para poder MIRARLO, no solo para que diga OK.
#  Se lanza con:  godot --headless --path . --script res://tools/probar_vision.gd
# ============================================================
extends SceneTree

const W := 41
const H := 17


func _initialize() -> void:
	var fallos: int = 0
	fallos += _caso_muro()
	fallos += _caso_radio_minimo()
	medir()
	print("")
	if fallos == 0:
		print("=== TODO BIEN ===")
	else:
		print("=== %d FALLOS ===" % fallos)
	quit(fallos)


# Un piso de juguete: sala abierta con un tabique vertical en la columna 20, con un hueco abajo.
func _mapa() -> DungeonGenerator:
	var gen := DungeonGenerator.new()
	gen.ancho = W
	gen.alto = H
	gen.solido = PackedByteArray()
	gen.solido.resize(W * H)
	gen.zona_de = PackedInt32Array()
	gen.zona_de.resize(W * H)
	for y in H:
		for x in W:
			var roca: bool = x == 0 or y == 0 or x == W - 1 or y == H - 1
			# tabique: columna 20, de arriba hasta la fila 11 (por debajo hay paso)
			if x == 20 and y <= 11:
				roca = true
			gen.solido[y * W + x] = 1 if roca else 0
			gen.zona_de[y * W + x] = -1 if roca else 0
	return gen


func _px(celda: Vector2i) -> Vector2:
	var c: float = float(DungeonGenerator.CELDA)
	return Vector2((float(celda.x) + 0.5) * c, (float(celda.y) + 0.5) * c)


func _caso_muro() -> int:
	print("=== CASO DEL DIBUJO: dos aliados, uno tras el muro ===")
	var gen: DungeonGenerator = _mapa()
	var v := Vision.new()
	v.preparar(gen)

	# OJO al colocarlos: el tabique llega hasta la fila 11, asi que hay que ponerse por DEBAJO de
	# el para tener linea limpia. La primera version puso al aliado "despejado" en diagonal y la
	# linea rozaba justo la punta del tabique -- el test fallaba y el codigo tenia razon.
	var yo := Vector2i(10, 13)         # tu, a la izquierda y por debajo del tabique
	var tapado := Vector2i(30, 4)      # al otro lado del muro: NO se debe ver
	var visible := Vector2i(30, 13)    # misma fila, por debajo del tabique: SI se debe ver

	var r: float = 5.0
	v.calcular([
		{"pos": _px(yo), "radio": r},
		{"pos": _px(tapado), "radio": r},
		{"pos": _px(visible), "radio": r},
	], _px(yo))

	_pintar(gen, v, {yo: "T", tapado: "1", visible: "2"})

	var fallos: int = 0
	fallos += _esperar("me veo a mi mismo", v.luz_en(_px(yo)) > 0.5, true)
	fallos += _esperar("el aliado TAPADO por el muro no se ve",
		v.luz_en(_px(tapado)) > 0.05, false)
	fallos += _esperar("el aliado con LINEA DESPEJADA si se ve (aunque mi luz no llegue)",
		v.luz_en(_px(visible)) > 0.5, true)
	# Y su corro tambien: "por supuesto ves iluminado su entorno"
	fallos += _esperar("veo el ENTORNO iluminado del aliado lejano",
		v.luz_en(_px(visible + Vector2i(2, 0))) > 0.3, true)
	# La roca corta: la celda del propio tabique se ve (es la cara del muro) pero lo de detras no
	fallos += _esperar("no se ve a traves del tabique",
		v.luz_en(_px(Vector2i(25, 4))) > 0.05, false)
	return fallos


func _caso_radio_minimo() -> int:
	print("")
	print("=== SUELO DURO: sin farolillo sigues viendo tu corro ===")
	var gen: DungeonGenerator = _mapa()
	var v := Vision.new()
	v.preparar(gen)
	var yo := Vector2i(10, 13)
	# radio 0: aunque el requisito del piso sea absurdo, RADIO_MINIMO manda
	v.calcular([{"pos": _px(yo), "radio": 0.0}], _px(yo))
	var fallos: int = 0
	fallos += _esperar("con radio 0 sigo viendo a 3 celdas",
		v.luz_en(_px(yo + Vector2i(3, 0))) > 0.1, true)
	fallos += _esperar("pero no a 12 celdas",
		v.luz_en(_px(yo + Vector2i(12, 0))) > 0.1, false)
	return fallos


func _esperar(que: String, real: bool, esperado: bool) -> int:
	if real == esperado:
		print("  OK    %s" % que)
		return 0
	print("  FALLO %s  (esperaba %s y es %s)" % [que, esperado, real])
	return 1


# El mapa en texto. '#' roca, '.' oscuro, ':' penumbra, '@' bien iluminado, y las marcas encima.
func _pintar(gen: DungeonGenerator, v: Vision, marcas: Dictionary) -> void:
	for y in gen.alto:
		var linea: String = ""
		for x in gen.ancho:
			var c := Vector2i(x, y)
			if marcas.has(c):
				linea += String(marcas[c])
				continue
			if gen.es_solido(c):
				linea += "#"
				continue
			var l: float = v.luz_en(_px(c))
			if l > 0.55:
				linea += "@"
			elif l > 0.05:
				linea += ":"
			else:
				linea += "."
		print("  " + linea)


# ------------------------------------------------------------
#  COSTE: esto corre 15 veces por segundo, asi que mas vale medirlo.
#  Se prueba en un piso GENERADO DE VERDAD y con el peor caso: un farolillo pegado a ti (barato,
#  el rayo del ojo es corto) y otro al otro extremo del mapa (caro, cada subcelda suya tira un
#  rayo largo hasta tu ojo).
# ------------------------------------------------------------
func medir() -> void:
	print("")
	print("=== COSTE ===")
	for piso in [1, 8, 16]:
		var gen := DungeonGenerator.new()
		gen.generar(roundi(100.0 * (1.0 + 0.05 * float(piso))),
			roundi(60.0 * (1.0 + 0.05 * float(piso))), 12345 + piso * 7919)
		var v := Vision.new()
		v.preparar(gen)
		var a: Vector2i = gen.salas[0].get_center()
		var b: Vector2i = gen.salas[gen.salas.size() - 1].get_center()
		var focos: Array = [
			{"pos": _px(a), "radio": 7.2},
			{"pos": _px(a + Vector2i(1, 0)), "radio": 7.2},
			{"pos": _px(b), "radio": 7.2},          # el lejano: el caro
		]
		# El recorte a lo que se ve: 1280x720 a zoom 1.8, mas el margen de la niebla.
		var tam := Vector2(1280.0, 720.0) / 1.8
		var vista := Rect2(_px(a) - tam * 0.5, tam).grow(8.0 * float(DungeonGenerator.CELDA))
		var t0: int = Time.get_ticks_usec()
		var vueltas: int = 20
		for i in vueltas:
			v.calcular(focos, _px(a), vista)
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(vueltas)
		print("  piso %2d  %3dx%-3d celdas  ->  %.2f ms por pasada" % [piso, gen.ancho, gen.alto, ms])
