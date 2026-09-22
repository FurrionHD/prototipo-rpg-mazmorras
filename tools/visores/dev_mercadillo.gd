# ============================================================
#  dev_mercadillo.gd  --  HERRAMIENTA, no parte del juego.
#
#  Comprueba los VENDEDORES DEL MERCADILLO (VendedorMercadillo):
#    - cada puesto tiene su vendedor y esta de pie dentro de la huella del puesto;
#    - la franja que se ve de el (PlazaSprites.franja_vendedor) tiene sentido: cabeza y hombros.
#
#  DOS MODOS: --headless solo comprueba; con ventana (herramientas/ver_mercadillo.bat) monta el pueblo de
#  verdad a mediodia y saca capturas en tools/salida/mercadillo_*.png: el puesto con su vendedor y con el
#  jugador delante, detras y al lado. Devuelve codigo != 0 si algo falla.
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
	_hueco()
	_dia()
	if _con_ventana:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		DirAccess.make_dir_recursive_absolute(SALIDA)
		await _capturas()
	CicloDia.hora_forzada = -1.0
	if _fallos == 0:
		print("\nOK: las %d comprobaciones pasan." % _hechas)
	else:
		printerr("\nFALLAN %d de %d comprobaciones." % [_fallos, _hechas])
	get_tree().quit(1 if _fallos > 0 else 0)


func _puestos() -> Array:
	var out: Array = []
	for m in PuebloPlano.MUEBLES:
		if String(m[0]).begins_with("puesto_"):
			out.append(m)
	return out


func _hueco() -> void:
	print("=== EL HUECO DEL VENDEDOR ===")
	_ok("hay 4 puestos", _puestos().size() == 4)
	for m in _puestos():
		# El frente sale del puesto entero: cada pixel suyo es el mismo que el del entero, y tapa algo.
		var clave: String = m[0]
		var entero: Image = PuebloSprites.generar(clave)
		var frente: Image = PuebloSprites.generar(clave + PlazaSprites.SUFIJO_FRENTE)
		var distintos: int = 0
		var pintados: int = 0
		for y in frente.get_height():
			for x in frente.get_width():
				var c: Color = frente.get_pixel(x, y)
				if c.a > 0.0:
					pintados += 1
					if not c.is_equal_approx(entero.get_pixel(x, y)):
						distintos += 1
		_ok("%s: el frente son %d pixeles del entero (%d distintos)" % [clave, pintados, distintos],
			pintados > 2000 and distintos == 0)
		# Donde se pone el vendedor (la cintura), el frente no tapa: se le ve.
		var cintura := Vector2i(48, int(PlazaSprites.pies_vendedor() - 30.0))
		_ok("  a la altura de su pecho (%s) el frente esta hueco" % cintura, frente.get_pixelv(cintura).a == 0.0)
	for m in _puestos():
		var r: Rect2i = m[1]
		var o: Vector2 = VendedorMercadillo.origen_en_puesto(r)
		var pie := o + Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
		var c := Vector2i((pie / float(PuebloPlano.CELDA)).floor())
		_ok("%s: el vendedor pisa dentro de su huella (%s)" % [m[0], c], r.has_point(c))


func _dia() -> void:
	print("\n=== EL DIA DE LOS VENDEDORES ===")
	var n: int = VendedoresPlan.VENDEDORES.size()
	_ok("un vendedor por puesto", n == _puestos().size())
	for v in n:
		var hay_casa: bool = false
		for c in PuebloPlano.CASAS:
			if c["rect"] == VendedoresPlan.VENDEDORES[v]["casa"]:
				hay_casa = true
		for g in GuardiasPlan.GUARDIAS:
			if g["casa"] == VendedoresPlan.VENDEDORES[v]["casa"]:
				hay_casa = false
		_ok("vendedor %d: su casa existe y no es de un guardia" % v, hay_casa)
		var casa: Vector2i = VendedoresPlan.puerta_casa(v)
		var costado: Vector2i = VendedoresPlan.costado_de(v)
		_ok("  su costado %s se pisa y es calle" % costado,
			not PuebloPlano.solida(costado) and PuebloPlano.suelo(costado) == PuebloPlano.Suelo.CALLE)
		for par in [[casa, costado], [costado, casa]]:
			var r: PackedVector2Array = GuardiasPlan.ruta(par[0], par[1])
			var pisa: int = 0
			for i in range(1, r.size()):
				var k_n: int = int(r[i - 1].distance_to(r[i]) / 4.0) + 1
				for k in k_n + 1:
					var pt: Vector2 = r[i - 1].lerp(r[i], float(k) / float(k_n)) + Vector2(0.0, PoseJugador.HUELLA_Y)
					if PuebloPlano.solida(Vector2i((pt / float(PuebloPlano.CELDA)).floor())):
						pisa += 1
			_ok("  ruta %s -> %s (%d px)" % [par[0], par[1], int(GuardiasPlan._largo(r))],
				r.size() >= 2 and r[-1].is_equal_approx(GuardiasPlan.pos_de(par[1])) and pisa == 0)
		# Los tramos, seguidos y sin saltos de sitio.
		var tr: Array = VendedoresPlan.linea(v)
		var bien: bool = is_zero_approx(float(tr[0]["t0"]))
		var antes: Dictionary = {}
		for i in tr.size():
			if i > 0 and absf(float(tr[i]["t0"]) - float(tr[i - 1]["t1"])) > 0.001:
				bien = false
			var e0: Dictionary = VendedoresPlan._evaluar(tr[i], float(tr[i]["t0"]))
			if not antes.is_empty() and bool(antes["visible"]) and bool(e0["visible"]) \
					and (antes["pos"] as Vector2).distance_to(e0["pos"]) > 1.0:
				bien = false
			antes = VendedoresPlan._evaluar(tr[i], minf(float(tr[i]["t1"]), float(tr[i]["t0"]) + 1.0e6))
		_ok("  %d tramos seguidos y sin saltos" % tr.size(), bien)
		# Cuando abre: antes de que acabe el amanecer. Y a mediodia abierto; de noche en casa.
		var abre: float = -1.0
		var t: float = 0.0
		while t < CicloDia.CICLO and abre < 0.0:
			if VendedoresPlan.abierto(v, t):
				abre = t
			t += 0.5
		_ok("  abre a los %d s (antes de que acabe el amanecer, %d)" % [int(abre), int(CicloDia.T_DIA)],
			abre >= 0.0 and abre <= CicloDia.T_DIA)
		_ok("  a mediodia esta abierto", VendedoresPlan.abierto(v, CicloDia.T_DIA + CicloDia.DIA * 0.5))
		var noche: Dictionary = VendedoresPlan.estado(v, CicloDia.T_NOCHE + 300.0)
		_ok("  de noche esta en casa (escondido y cerrado)", not bool(noche["visible"]) and not bool(noche["abierto"]))


# ------------------------------------------------------------
#  CAPTURAS: el pueblo de verdad a mediodia.
# ------------------------------------------------------------
func _capturas() -> void:
	PartidaDePrueba.llenar()
	get_tree().current_scene.scene_file_path = PUEBLO
	_pueblo = (load(PUEBLO) as PackedScene).instantiate() as Node2D
	add_child(_pueblo)
	_jugador = _pueblo.get_node("Player") as Node2D
	await get_tree().process_frame
	var cam: Camera2D = _jugador.get_node("Camera2D") as Camera2D
	cam.position_smoothing_enabled = false
	var mediodia: float = CicloDia.T_DIA + CicloDia.DIA * 0.5
	var pan: Rect2i = _puestos()[0][1]
	var celda: float = float(PuebloPlano.CELDA)
	var centro := Vector2(pan.get_center()) * celda
	var fuera := Vector2(-5000, -5000)
	# El mercadillo entero, de lejos.
	cam.zoom = Vector2(2.0, 2.0)
	var mercado: Rect2i = PuebloPlano.MERCADO
	await _foto("entero", mediodia, fuera, Vector2(mercado.get_center()) * celda)
	# El puesto del pan de cerca, sin nadie.
	cam.zoom = Vector2(4.0, 4.0)
	await _foto("pan_solo", mediodia, fuera, centro)
	# Con el jugador DELANTE (en el pasillo, pegado), DETRAS y AL LADO.
	var delante: Vector2 = GuardiasPlan.pos_de(Vector2i(pan.get_center().x, pan.end.y))
	var detras: Vector2 = GuardiasPlan.pos_de(Vector2i(pan.get_center().x, pan.position.y - 1))
	var lado: Vector2 = GuardiasPlan.pos_de(Vector2i(pan.end.x, pan.end.y - 1))
	await _foto("pan_delante", mediodia, delante, centro)
	await _foto("pan_detras", mediodia, detras, centro)
	await _foto("pan_lado", mediodia, lado, centro)
	# Los otros tres, sin nadie.
	for m in _puestos().slice(1):
		await _foto(String(m[0]).trim_prefix("puesto_"), mediodia, fuera, Vector2((m[1] as Rect2i).get_center()) * celda)
	# EL VENDEDOR DEL PAN ENTRANDO: andando hacia el costado, en el borde (el cambio de muñeco) y dentro.
	var tr: Array = VendedoresPlan.linea(0)
	var t_dentro: float = -1.0
	for x in tr:
		if bool(x.get("dentro", false)):
			t_dentro = float(x["t0"])
			break
	await _foto("entra_1_calle", t_dentro - 0.05, fuera, centro)
	await _foto("entra_2_costado", t_dentro + 0.05, fuera, centro)
	await _foto("entra_3_poste", t_dentro + 0.3, fuera, centro)
	await _foto("entra_4_dentro", t_dentro + 0.7, fuera, centro)
	# Por la calle, a medio camino de casa al puesto.
	var a_medio: float = VendedoresPlan.SALIDA + (t_dentro - VendedoresPlan.SALIDA) * 0.5
	cam.zoom = Vector2(3.0, 3.0)
	await _foto("por_la_calle", a_medio, fuera, VendedoresPlan.estado(0, a_medio)["pos"])
	# De noche, el mercadillo vacio.
	cam.zoom = Vector2(2.0, 2.0)
	await _foto("de_noche", CicloDia.T_NOCHE + 300.0, fuera, Vector2(mercado.get_center()) * celda)


func _foto(nombre: String, t: float, jugador: Vector2, donde: Vector2) -> void:
	CicloDia.hora_forzada = t
	await get_tree().process_frame
	# Los compañeros, fuera de la foto: se los trae el sequito si solo se les mueve.
	for nd in get_tree().get_nodes_in_group("aliado"):
		if nd is CanvasItem and nd != _jugador:
			(nd as CanvasItem).visible = false
	_jugador.global_position = jugador
	await get_tree().process_frame
	# Y FUERA del grupo: escondidos o lejos siguen contando para PiezaPueblo como "alguien delante" (el
	# sequito los vuelve a traer detras del jugador) y bajan el toldo en la foto.
	for nd in get_tree().get_nodes_in_group("aliado"):
		if nd is Node2D and nd != _jugador:
			nd.remove_from_group("aliado")
	var cam: Camera2D = _jugador.get_node("Camera2D") as Camera2D
	cam.global_position = donde
	cam.reset_smoothing()
	await get_tree().process_frame
	# La camara va pegada al jugador: se vuelve a clavar despues de moverle.
	cam.global_position = donde
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%smercadillo_%s.png" % [SALIDA, nombre])


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
