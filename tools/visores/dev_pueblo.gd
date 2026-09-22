# ============================================================
#  dev_pueblo.gd  --  HERRAMIENTA, no parte del juego.
#
#  Monta el PUEBLO de verdad (scenes/levels/town.tscn, construido desde PuebloPlano) y comprueba lo que
#  la fase 1 del pueblo visual promete:
#    - ninguna casa pisa una calle, la muralla, el agua u otra casa (el pescador, la madera);
#    - cada oficio tiene UNA puerta interactuable, y su casilla se puede pisar;
#    - todas las puertas se alcanzan andando desde donde apareces;
#    - pulsar F en cada puerta abre un menu.
#
#  DOS MODOS: --headless solo comprueba; con ventana (herramientas/ver_pueblo.bat) saca ademas
#  capturas en tools/salida/pueblo_*.png: el pueblo entero y un primer plano de cada puerta.
#  Devuelve codigo != 0 si algo falla.
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PUEBLO := "res://scenes/levels/town.tscn"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

var _fallos: int = 0
var _hechas: int = 0
var _con_ventana: bool = DisplayServer.get_name() != "headless"
var _pueblo: Node2D = null
var _jugador: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if _con_ventana:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(SALIDA)
	PartidaDePrueba.llenar()
	# EL PUEBLO DE MENTIRA: Game.en_pueblo() y door.gd miran la ruta de la escena actual.
	get_tree().current_scene.scene_file_path = PUEBLO
	_pueblo = (load(PUEBLO) as PackedScene).instantiate() as Node2D
	add_child(_pueblo)
	_jugador = _pueblo.get_node("Player") as Node2D
	await get_tree().process_frame
	await get_tree().process_frame

	_hoja_de_piezas()
	_plano()
	await _choques()
	_puertas()
	await _menus()
	if _con_ventana:
		await _capturas()

	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _plano() -> void:
	print("=== EL PLANO ===")
	var ocupadas := {}
	for casa in PuebloPlano.CASAS:
		var r: Rect2i = casa["rect"]
		var clave: String = casa["clave"]
		var suelo_ok: int = PuebloPlano.Suelo.MADERA if clave == "pescador" else PuebloPlano.Suelo.HIERBA
		var mal: Array = []
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				if PuebloPlano.suelo(c) != suelo_ok or ocupadas.has(c) or PuebloPlano.es_verja(c):
					mal.append(c)
				ocupadas[c] = clave
		_ok("%s en %s no pisa nada" % [clave, r], mal.is_empty())
		var dib: String = "vacia_0" if clave == "vacia" else clave
		_ok("  su dibujo mide lo que su huella", CasaSprites.CASAS[dib]["huella"] == r.size)
		if not String(casa.get("script", "")).is_empty():
			var p: Vector2i = PuebloPlano.puerta_de(casa)
			_ok("  su puerta %s se puede pisar" % p, not PuebloPlano.solida(p))
		# Todas pegadas a su calle, con la casilla de la puerta enlosada (o la madera del pescador).
		var pu: Vector2i = PuebloPlano.puerta_de(casa)
		_ok("  la puerta %s es de piedra y da a una calle" % pu,
			PuebloPlano.suelo(pu) != PuebloPlano.Suelo.HIERBA
			and PuebloPlano.suelo(pu + Vector2i(0, 1)) != PuebloPlano.Suelo.HIERBA)
	for a in PuebloPlano.adornos():
		_ok("el adorno %s en %s va en hierba, fuera del camino" % [a[0], a[1]],
			PuebloPlano.suelo(a[1]) == PuebloPlano.Suelo.HIERBA)
	# Las CAÑAS: deterministas por semilla (asi salen iguales en multi) y distintas con otra semilla.
	var canas_a: Array = PuebloPlano.canas(12345)
	_ok("tres cañas, iguales con la misma semilla", canas_a.size() == 3 and canas_a == PuebloPlano.canas(12345))
	var cambian: bool = false
	for sem in range(1, 20):
		if PuebloPlano.canas(sem) != canas_a:
			cambian = true
	_ok("y en otro sitio con otra semilla", cambian)
	for sem in range(1, 40):
		for c in PuebloPlano.canas(sem):
			if PuebloPlano.suelo(c[0]) != PuebloPlano.Suelo.MADERA or PuebloPlano.solida(c[0]) 					or (c[0] as Vector2i).y == PuebloPlano.PLATAFORMA.position.y:
				_ok("caña fuera del borde de la plataforma: %s" % [c], false)
	# LAS LUCES: los postes en la hierba (en la calle quitarian paso), los braseros en hierba o en la
	# plaza; ninguna encima de una puerta, de un adorno, de una casa, de otra luz o de una verja.
	var puertas := {}
	for casa in PuebloPlano.CASAS:
		puertas[PuebloPlano.puerta_de(casa)] = true
	var vistas := {}
	for l in PuebloPlano.luces():
		var c: Vector2i = l[1]
		var s: int = PuebloPlano.suelo(c)
		var suelo_ok: bool = s == PuebloPlano.Suelo.HIERBA or (l[0] == "brasero" and PuebloPlano.PLAZA.has_point(c))
		var libre: bool = not puertas.has(c) and not vistas.has(c) and not PuebloPlano.solida_entera(c) \
			and not PuebloPlano.es_verja(c) and c != PuebloPlano.ALTAR
		for a in PuebloPlano.adornos():
			if a[1] == c:
				libre = false
		_ok("%s en %s: sitio libre y suelo bueno" % [l[0], c], suelo_ok and libre)
		vistas[c] = true
	# LOS CARTELES INDICADORES: en hierba, libres (nada de puertas, luces, adornos ni casas) y pegados a
	# una calle, que es donde se leen.
	for c in PuebloPlano.casillas_carteles():
		var libre: bool = not puertas.has(c) and not vistas.has(c) and not PuebloPlano.solida_entera(c) \
			and not PuebloPlano.es_verja(c)
		for a in PuebloPlano.adornos():
			if a[1] == c:
				libre = false
		var junto_calle: bool = false
		for dd in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if PuebloPlano.suelo(c + dd) == PuebloPlano.Suelo.CALLE:
				junto_calle = true
		_ok("cartel en %s: sitio libre, en hierba y junto a una calle" % c,
			libre and junto_calle and PuebloPlano.suelo(c) == PuebloPlano.Suelo.HIERBA)
		vistas[c] = true
	# LA PLAZA DE LA FUENTE Y EL MERCADILLO: cada mueble dentro de su plaza o en la hierba de al lado, sin
	# pisar puertas, luces, carteles ni a otro mueble; la fuente dentro de la plaza; y cada puesto con la
	# casilla de delante libre (ahi se compra).
	_ok("la fuente cae en la plaza", PuebloPlano.PARQUE.encloses(PuebloPlano.FUENTE))
	var de_muebles := {}
	for m in PuebloPlano.MUEBLES:
		var r: Rect2i = m[1]
		var bien: bool = true
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				var s: int = PuebloPlano.suelo(c)
				if (s != PuebloPlano.Suelo.CALLE and s != PuebloPlano.Suelo.HIERBA) or puertas.has(c) \
						or vistas.has(c) or de_muebles.has(c) or PuebloPlano.solida_entera(c) \
						or PuebloPlano.es_camino(c):
					bien = false
				de_muebles[c] = true
		_ok("%s en %s: sitio libre" % [m[0], r], bien)
		if String(m[0]).begins_with("puesto_"):
			var libre_delante: bool = true
			for x in range(r.position.x, r.end.x):
				if PuebloPlano.solida(Vector2i(x, r.end.y)):
					libre_delante = false
			_ok("  y se le puede comprar por delante", libre_delante)
	# EL JARDIN DEL HOGAR, CERRADO: verja por los cuatro lados, sin mas hueco que la entrada de abajo.
	var j: Rect2i = PuebloPlano.JARDIN
	var huecos: int = 0
	for x in range(j.position.x, j.end.x):
		for y in [j.position.y, j.end.y - 1]:
			if not PuebloPlano.es_verja(Vector2i(x, y)):
				huecos += 1
	for y in range(j.position.y, j.end.y):
		for x in [j.position.x, j.end.x - 1]:
			if not PuebloPlano.es_verja(Vector2i(x, y)):
				huecos += 1
	_ok("el jardin del hogar solo se abre por la entrada (%d huecos)" % huecos,
		huecos == PuebloPlano.JARDIN_HUECO.size.x)
	_ok("la escalera cae en la plaza", PuebloPlano.PLAZA.encloses(PuebloPlano.ESCALERA))
	_ok("apareces en un sitio libre", not PuebloPlano.solida(_celda(PuebloPlano.aparicion_px())))


# EL CHOQUE ES LO QUE SE VE: en cada adorno, el pie del dibujo choca y la esquina de su casilla (hierba
# vacia alrededor del barril) no. Con la fisica de verdad, no con el plano.
func _choques() -> void:
	print("\n=== LOS CHOQUES ===")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var espacio: PhysicsDirectSpaceState2D = _pueblo.get_world_2d().direct_space_state
	var choca := func(p: Vector2) -> bool:
		var q := PhysicsPointQueryParameters2D.new()
		q.position = p
		return not espacio.intersect_point(q, 1).is_empty()
	var cel: float = float(PuebloPlano.CELDA)
	for a in PuebloPlano.adornos():
		var c: Vector2i = a[1]
		var esquina := Vector2(float(c.x) * cel + 2.0, float(c.y) * cel + cel - 2.0)
		var pie := Vector2(float(c.x) * cel + cel * 0.5, float(c.y) * cel + PuebloPlano.ADORNO_APOYO)
		_ok("%s: choca su pie y no la esquina de su casilla" % a[0], choca.call(pie) and not choca.call(esquina))
		var detras := Vector2(float(c.x) * cel + cel * 0.5, float(c.y) * cel + 2.0)
		_ok("  y no deja hueco por detras, contra la casa", choca.call(detras))
	var al: Vector2i = PuebloPlano.ALTAR
	_ok("la columna no choca por arriba de su casilla", not choca.call(Vector2(float(al.x) * cel + 3.0, float(al.y) * cel + 3.0)))


func _puertas() -> void:
	print("\n=== LAS PUERTAS ===")
	var alcanzables: Dictionary = _alcanzables(_celda(PuebloPlano.aparicion_px()))
	# Sin los vendedores del mercadillo: se pueden usar o no segun la hora (VendedoresPlan.vende), y los
	# comprueba su propio visor (ver_mercadillo.bat).
	var nodos: Array = get_tree().get_nodes_in_group("interactable").filter(func(n): return not n is VendedorMercadillo)
	for casa in PuebloPlano.CASAS:
		if String(casa.get("script", "")).is_empty():
			continue
		var p: Vector2i = PuebloPlano.puerta_de(casa)
		var px: Vector2 = PuebloPlano.centro_px(p)
		var cerca: int = nodos.filter(func(n): return (n as Node2D).global_position.distance_to(px) < 24.0).size()
		_ok("%s: una puerta interactuable (%d)" % [casa["clave"], cerca], cerca == 1)
		_ok("  y se llega andando", alcanzables.has(p))
	_ok("la escalera es la salida a la mazmorra", get_tree().get_nodes_in_group("salida_pueblo").size() == 1)
	# La F de la escalera desde sus CUATRO lados, con el jugador de verdad pegado a cada uno.
	var esc: Rect2i = PuebloPlano.ESCALERA
	var cen: Vector2 = (Vector2(esc.position) + Vector2(esc.size) * 0.5) * float(PuebloPlano.CELDA)
	var medio: float = float(esc.size.x) * float(PuebloPlano.CELDA) * 0.5
	var lados := {"sur": Vector2(0, medio - 4.0), "norte": Vector2(0, -medio - 18.0),
		"este": Vector2(medio + 13.0, 0), "oeste": Vector2(-medio - 13.0, 0)}
	for lado in lados:
		_jugador.global_position = cen + lados[lado]
		var cual: Node = _jugador._mas_cercano_en_grupo("interactable", false)
		_ok("la escalera se usa desde el %s" % lado, cual != null and cual.is_in_group("salida_pueblo"))
	_jugador.global_position = PuebloPlano.aparicion_px()
	_ok("se llega al altar", alcanzables.has(PuebloPlano.ALTAR + Vector2i(0, 1)))
	# El barrio norte y los portones: se llega andando a la arena, al cuartel y delante de las dos
	# puertas de los guardias.
	_ok("se llega al porton de la arena", alcanzables.has(PuebloPlano.PORTON_ARENA))
	for casa in PuebloPlano.CASAS:
		if String(casa["clave"]) == "cuartel":
			_ok("se llega a la puerta del cuartel", alcanzables.has(PuebloPlano.puerta_de(casa)))
	for p in PuebloPlano.PORTONES:
		var r: Rect2i = p["rect"]
		if String(p["lado"]) == "oeste":
			_ok("se llega al porton oeste", alcanzables.has(Vector2i(r.end.x, r.position.y + 1)))
		elif String(p["lado"]) == "este":
			_ok("se llega al porton este", alcanzables.has(Vector2i(r.position.x - 1, r.position.y + 1)))
	# Y a TODAS las casas, tambien las vacias: ahi viviran los guardias y los aldeanos.
	var sin_salida: Array = []
	for casa in PuebloPlano.CASAS:
		if not alcanzables.has(PuebloPlano.puerta_de(casa)):
			sin_salida.append(casa["rect"])
	_ok("todas las casas tienen salida andando %s" % [sin_salida], sin_salida.is_empty())
	var n_carteles: int = PuebloPlano.CARTELES.size()
	_ok("hay %d interactuables (10 oficios + altar + escalera + porton + %d carteles)" % [nodos.size(), n_carteles],
		nodos.size() == 13 + n_carteles)


# F sobre cada puerta de oficio: tiene que aparecer algo que antes no se veia.
func _menus() -> void:
	print("\n=== F EN CADA PUERTA ===")
	for casa in PuebloPlano.CASAS:
		if String(casa.get("script", "")).is_empty():
			continue
		var puerta: Node = _pueblo.get_node("Casa_%s/Puerta" % casa["clave"])
		# Todo menu de oficio se apunta en Game.abrir_menu al abrirse (es lo que pausa el mundo).
		Game.inventory_open = false
		puerta.interact_with_player()
		await get_tree().process_frame
		await get_tree().process_frame
		_ok("%s abre su menú" % casa["clave"], Game.inventory_open)
		Game.cerrar_menus_abiertos()
		get_tree().paused = false
		await get_tree().process_frame


func _capturas() -> void:
	var cam: Camera2D = _jugador.get_node("Camera2D") as Camera2D
	var tam: Vector2 = PuebloPlano.tam_px()
	# El pueblo ENTERO: sin limites y con el zoom que hace falta para que quepa.
	cam.position_smoothing_enabled = false
	var limites := [cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom]
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	var z: float = minf(1280.0 / tam.x, 720.0 / tam.y)
	cam.zoom = Vector2(z, z)
	_jugador.global_position = tam * 0.5
	await _captura("entero")
	cam.limit_left = limites[0]
	cam.limit_top = limites[1]
	cam.limit_right = limites[2]
	cam.limit_bottom = limites[3]
	cam.zoom = Vector2(1.8, 1.8)
	for casa in PuebloPlano.CASAS:
		if String(casa.get("script", "")).is_empty():
			continue
		_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.puerta_de(casa)) + Vector2(0, 6)
		await _captura(String(casa["clave"]))
	_jugador.global_position = PuebloPlano.aparicion_px()
	await _captura("plaza")
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.ALTAR + Vector2i(0, 2))
	await _captura("altar")
	# El TAPADO: detras de la columna, la parte alta tiene que taparle; delante, no.
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.ALTAR) + Vector2(0, -34)
	await _captura("altar_detras")
	# Pegado por detras a la columna y a la verja de abajo del jardin: las piernas NO se pintan encima.
	var al: Vector2i = PuebloPlano.ALTAR
	_jugador.global_position = Vector2(float(al.x) * 32.0 + 16.0, float(al.y + 1) * 32.0 - 34.0)
	await _captura("altar_pegado_detras")
	var vj := Vector2i(PuebloPlano.JARDIN.position.x + 2, PuebloPlano.JARDIN.end.y - 1)
	_jugador.global_position = Vector2(float(vj.x) * 32.0 + 16.0, float(vj.y) * 32.0 + 16.0 - 24.0)
	await _captura("verja_pegado_detras")
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.ALTAR) + Vector2(0, 20)
	await _captura("altar_delante")
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.ESCALERA.position + Vector2i(1, -1))
	await _captura("escalera_norte")
	# La verja de arriba del jardin, que lo cierra desde que el pueblo crecio.
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.JARDIN.position + Vector2i(3, -1))
	await _captura("verja_arriba")
	# Los portones: el del norte de frente y los de los lados de canto.
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.PORTON_ARENA + Vector2i(0, 1))
	await _captura("porton_norte")
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(4, 38))
	await _captura("porton_oeste")
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(PuebloPlano.ANCHO - 5, 38))
	await _captura("porton_este")
	# Lo nuevo del barrio norte: el cuartel y un cartel.
	for casa in PuebloPlano.CASAS:
		if String(casa["clave"]) == "cuartel":
			_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.puerta_de(casa) + Vector2i(0, 1))
			await _captura("cuartel")
	_jugador.global_position = PuebloPlano.centro_px(PuebloPlano.CARTELES[0]["casilla"] + Vector2i(0, 1))
	await _captura("cartel")
	# La plaza de la fuente y el mercadillo, desde el sur de cada uno.
	var pq: Rect2i = PuebloPlano.PARQUE
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(pq.get_center().x, pq.end.y - 1))
	await _captura("plaza_fuente")
	var mc: Rect2i = PuebloPlano.MERCADO
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(mc.get_center().x, mc.end.y - 1))
	await _captura("mercadillo")
	_jugador.global_position = PuebloPlano.centro_px(Vector2i(PuebloPlano.MUELLE.position.x + 1, PuebloPlano.MUELLE.position.y + 1))
	await _captura("muelle")


# LA HOJA DE PIEZAS: cada dibujo suelto, ampliado x4 sobre un fondo de hierba y con una raya roja
# en su linea de corte (lo de encima tapa a quien pasa por detras). No necesita ventana: es imagen pura.
const ZOOM := 4

func _hoja_de_piezas() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var claves: PackedStringArray = PuebloSprites.claves()
	# Las murallas van en su propia hoja: miden lo que el pueblo y no caben en una celda.
	for m in MurallaSprites.claves():
		var im: Image = MurallaSprites.generar(m)
		if im.get_width() > im.get_height():
			im = im.get_region(Rect2i(0, 0, 1000, im.get_height()))
		else:
			im = im.get_region(Rect2i(0, 600, im.get_width(), 400))
		im.resize(im.get_width() * 2, im.get_height() * 2, Image.INTERPOLATE_NEAREST)
		im.save_png("%spueblo_%s.png" % [SALIDA, m])
	var ancho: int = 6
	var mayor := Vector2i.ZERO
	for c in claves:
		mayor = mayor.max(PuebloSprites.tam(c))
	var celda := (mayor + Vector2i(8, 8)) * ZOOM
	var filas: int = int(ceil(float(claves.size()) / float(ancho)))
	var hoja := Image.create(celda.x * ancho, celda.y * filas, false, Image.FORMAT_RGBA8)
	hoja.fill(Color(0.31, 0.47, 0.21))
	for i in claves.size():
		var img: Image = PuebloSprites.generar(claves[i])
		img.resize(img.get_width() * ZOOM, img.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
		var o := Vector2i((i % ancho) * celda.x + 8, (i / ancho) * celda.y + 8)
		hoja.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), o)
		var corte: int = (PuebloSprites.tam(claves[i]).y - PuebloSprites.pie(claves[i])) * ZOOM
		if corte > 0:
			for x in img.get_width():
				hoja.set_pixel(o.x + x, o.y + corte, Color.RED)
	hoja.save_png("%spueblo_piezas.png" % SALIDA)
	# La LLAMA del altar: sus fotogramas seguidos, ampliados x6, sobre la piedra del claro.
	var z: int = 6
	var tira := Image.create(LlamaAltar.ANCHO * z * LlamaAltar.FOTOGRAMAS, LlamaAltar.ALTO * z, false, Image.FORMAT_RGBA8)
	tira.fill(Color(0.45, 0.43, 0.41))
	for k in LlamaAltar.FOTOGRAMAS:
		var f: Image = LlamaAltar._fotograma(k)
		f.resize(f.get_width() * z, f.get_height() * z, Image.INTERPOLATE_NEAREST)
		tira.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i(k * LlamaAltar.ANCHO * z, 0))
	tira.save_png("%spueblo_llama.png" % SALIDA)


func _captura(nombre: String) -> void:
	await get_tree().process_frame
	# Los compañeros siguen al jugador y se plantan delante de lo que se quiere mirar: fuera de camara.
	for n in get_tree().get_nodes_in_group("aliado"):
		if n != _jugador and n is Node2D:
			(n as Node2D).global_position = Vector2(-5000, -5000)
	(_jugador.get_node("Camera2D") as Camera2D).reset_smoothing()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%spueblo_%s.png" % [SALIDA, nombre])


func _celda(px: Vector2) -> Vector2i:
	return Vector2i((px / float(PuebloPlano.CELDA)).floor())


func _alcanzables(desde: Vector2i) -> Dictionary:
	var vistas := {desde: true}
	var cola: Array[Vector2i] = [desde]
	while not cola.is_empty():
		var c: Vector2i = cola.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if PuebloPlano.dentro(n) and not vistas.has(n) and not PuebloPlano.solida(n):
				vistas[n] = true
				cola.append(n)
	return vistas


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
