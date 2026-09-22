# ============================================================
#  dev_guardias.gd  --  HERRAMIENTA, no parte del juego.
#
#  Comprueba los GUARDIAS DEL PUEBLO y su cambio de turno (GuardiasPlan):
#    - todas las rutas existen y no pisan nada solido;
#    - los tramos de cada guardia van seguidos, sin saltos de hora ni de sitio;
#    - a mitad de turno hay exactamente cuatro de guardia (uno por puesto) y los otros cuatro en casa;
#    - nunca hay dos en el mismo puesto, y cada puesto se queda vacio solo un instante en el relevo;
#    - el relevo acaba mucho antes del siguiente cambio.
#
#  DOS MODOS: --headless solo comprueba; con ventana (herramientas/ver_guardias.bat) monta el pueblo de
#  verdad, clava la hora en momentos del relevo y saca capturas en tools/salida/guardias_*.png.
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
	_rutas()
	_tramos()
	_turnos()
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


func _rutas() -> void:
	print("=== LAS RUTAS ===")
	var cu: Vector2i = GuardiasPlan.puerta_cuartel()
	_ok("el cuartel tiene puerta (%s)" % cu, cu != Vector2i.ZERO and not PuebloPlano.solida(cu))
	for p in GuardiasPlan.PUESTOS:
		var c: Vector2i = p["casilla"]
		var frente: Vector2i = c + (p["mira"] as Vector2i)
		_ok("puesto %s, su frente y su aparte se pisan" % c,
			not PuebloPlano.solida(c) and not PuebloPlano.solida(frente) and not PuebloPlano.solida(p["aparte"]))
		_ok("  y esta en la calle mayor, pegado a la muralla",
			PuebloPlano.suelo(c) == PuebloPlano.Suelo.CALLE and PuebloPlano.suelo(c - (p["mira"] as Vector2i)) == PuebloPlano.Suelo.MURALLA)
	for g in GuardiasPlan.GUARDIAS.size():
		var casa: Vector2i = GuardiasPlan.puerta_casa(g)
		var hay_casa: bool = false
		for c in PuebloPlano.CASAS:
			if c["rect"] == GuardiasPlan.GUARDIAS[g]["casa"]:
				hay_casa = true
		_ok("guardia %d: su casa existe en el plano" % g, hay_casa)
		var p: Dictionary = GuardiasPlan.PUESTOS[int(GuardiasPlan.GUARDIAS[g]["puesto"])]
		var frente: Vector2i = (p["casilla"] as Vector2i) + (p["mira"] as Vector2i)
		for par in [[casa, cu], [cu, frente], [frente, cu], [cu, casa]]:
			var r: PackedVector2Array = GuardiasPlan.ruta(par[0], par[1])
			var bien: bool = r.size() >= 2 and r[0].is_equal_approx(GuardiasPlan.pos_de(par[0])) \
				and r[-1].is_equal_approx(GuardiasPlan.pos_de(par[1]))
			# Ningun punto del camino (muestreado cada 4 px) cae en una casilla solida.
			var pisa: int = 0
			for i in range(1, r.size()):
				var n: int = int(r[i - 1].distance_to(r[i]) / 4.0) + 1
				for k in n + 1:
					var pt: Vector2 = r[i - 1].lerp(r[i], float(k) / float(n)) + Vector2(0.0, PoseJugador.HUELLA_Y)
					if PuebloPlano.solida(Vector2i((pt / float(PuebloPlano.CELDA)).floor())):
						pisa += 1
			_ok("  ruta %s -> %s (%d puntos, %d px)" % [par[0], par[1], r.size(), int(GuardiasPlan._largo(r))], bien and pisa == 0)


func _tramos() -> void:
	print("\n=== LOS TRAMOS ===")
	for g in GuardiasPlan.GUARDIAS.size():
		for entra in [true, false]:
			var tr: Array = GuardiasPlan.linea(g, entra)
			var seguidos: bool = is_zero_approx(float(tr[0]["t0"]))
			var sin_saltos: bool = true
			var antes: Dictionary = {}
			for i in tr.size():
				if i > 0 and absf(float(tr[i]["t0"]) - float(tr[i - 1]["t1"])) > 0.001:
					seguidos = false
				var e0: Dictionary = GuardiasPlan._evaluar(tr[i], float(tr[i]["t0"]))
				if not antes.is_empty() and bool(antes["visible"]) and bool(e0["visible"]) \
						and (antes["pos"] as Vector2).distance_to(e0["pos"]) > 1.0:
					sin_saltos = false
				var t_fin: float = minf(float(tr[i]["t1"]), float(tr[i]["t0"]) + 1.0e6)
				antes = GuardiasPlan._evaluar(tr[i], t_fin)
			var fin: float = float(tr[-1]["t0"])
			_ok("guardia %d %s: %d tramos seguidos, sin saltos; acaba a los %d s" % [g, "entra" if entra else "sale", tr.size(), int(fin)],
				seguidos and sin_saltos and fin < GuardiasPlan.TURNO * 0.5)


func _turnos() -> void:
	print("\n=== LOS TURNOS ===")
	var n: int = GuardiasPlan.GUARDIAS.size()
	for mitad in [600.0, 1800.0]:
		var de_guardia: int = 0
		var ocultos: int = 0
		for g in n:
			var e: Dictionary = GuardiasPlan.estado(g, mitad)
			if bool(e["solido"]):
				de_guardia += 1
			if not bool(e["visible"]):
				ocultos += 1
		_ok("a los %d s: 4 de guardia y 4 en casa (%d, %d)" % [int(mitad), de_guardia, ocultos], de_guardia == 4 and ocultos == 4)
	# Todo el ciclo cada medio segundo: nunca dos en un puesto, y los huecos, cortos.
	var dobles: int = 0
	var vacio_max: Array = [0.0, 0.0, 0.0, 0.0]
	var vacio: Array = [0.0, 0.0, 0.0, 0.0]
	var t: float = 0.0
	while t < CicloDia.CICLO:
		var cuenta: Array = [0, 0, 0, 0]
		for g in n:
			if GuardiasPlan.en_puesto(g, t):
				cuenta[int(GuardiasPlan.GUARDIAS[g]["puesto"])] += 1
		for k in 4:
			if int(cuenta[k]) > 1:
				dobles += 1
			vacio[k] = float(vacio[k]) + 0.5 if int(cuenta[k]) == 0 else 0.0
			vacio_max[k] = maxf(float(vacio_max[k]), float(vacio[k]))
		t += 0.5
	_ok("nunca hay dos en el mismo puesto (%d)" % dobles, dobles == 0)
	for k in 4:
		_ok("el puesto %d se queda vacio como mucho %.1f s seguidos" % [k, vacio_max[k]], float(vacio_max[k]) <= 3.0)
	for g in n:
		var llega: float = float(GuardiasPlan._relevo(g)["llega"])
		print("  guardia %d llega a su puesto a los %d s del cambio" % [g, int(llega)])


# ------------------------------------------------------------
#  CAPTURAS: el pueblo de verdad con la hora clavada.
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
	cam.zoom = Vector2(2.0, 2.0)
	var oeste: Vector2 = GuardiasPlan.pos_de(Vector2i(5, 38))
	var este: Vector2 = GuardiasPlan.pos_de(Vector2i(68, 38))
	# De guardia a mitad de turno, en los dos portones.
	await _foto("puesto_oeste", 600.0, oeste)
	await _foto("puesto_este", 600.0, este)
	# El relevo del puesto 0 (guardia 0 entra, el 4 sale), paso a paso.
	var ev: Dictionary = GuardiasPlan._relevo(0)
	await _foto("relevo_1_llega", float(ev["llega"]) + 0.3, oeste)
	await _foto("relevo_2_aparta", float(ev["entra_ocupa"]) - 0.05, oeste)
	await _foto("relevo_3_ocupa", float(ev["entra_listo"]) + 0.1, oeste)
	await _foto("relevo_4_saluda", float(ev["sale_delante"]) + 0.8, oeste)
	# Por el camino: el que entra saliendo de casa, y los de paisano entrando en el cuartel.
	await _foto("sale_de_casa", 2.0, GuardiasPlan.pos_de(GuardiasPlan.puerta_casa(0)))
	var al_cuartel: float = GuardiasPlan._largo(GuardiasPlan.ruta(GuardiasPlan.puerta_casa(0), GuardiasPlan.puerta_cuartel())) / GuardiasPlan.VELOCIDAD
	await _foto("llega_al_cuartel", al_cuartel - 1.5, GuardiasPlan.pos_de(GuardiasPlan.puerta_cuartel()))
	await _foto("sale_armado", al_cuartel + GuardiasPlan.EN_CUARTEL + 2.0, GuardiasPlan.pos_de(GuardiasPlan.puerta_cuartel()))
	# JUNTO A LA VERJA DEL HOGAR: el primer momento en que cada guardia pasa pegado a ella (a una casilla
	# o menos de una casilla de verja), de paisano o armado. Ahi las verjas se les pintaban encima.
	cam.zoom = Vector2(3.0, 3.0)
	var vistos := {}
	for g in GuardiasPlan.GUARDIAS.size():
		var t := 0.0
		while t < 400.0:
			var e: Dictionary = GuardiasPlan.estado(g, t)
			if bool(e["visible"]):
				var pie: Vector2 = (e["pos"] as Vector2) + Vector2(0.0, PoseJugador.HUELLA_Y)
				var c := Vector2i((pie / float(PuebloPlano.CELDA)).floor())
				var cerca: bool = false
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if PuebloPlano.es_verja(c + Vector2i(dx, dy)):
							cerca = true
				var lado: String = "oeste" if c.x < PuebloPlano.ALTAR.x else "este"
				var clave: String = "%s_%s" % [lado, "armado" if bool(e["armado"]) else "paisano"]
				if cerca and not vistos.has(clave):
					vistos[clave] = true
					await _foto("verja_" + clave, t, e["pos"])
			t += 0.25
	# PRIMEROS PLANOS, para ver la armadura, la espada y el escudo (y la ropa de paisano).
	cam.zoom = Vector2(5.0, 5.0)
	await _foto("cerca_de_guardia", 600.0, GuardiasPlan.pos_de(Vector2i(2, 38)))
	await _foto("cerca_andando", 20.0, GuardiasPlan.estado(0, 20.0)["pos"])
	await _foto("cerca_armado_andando", al_cuartel + GuardiasPlan.EN_CUARTEL + 3.0,
		GuardiasPlan.estado(0, al_cuartel + GuardiasPlan.EN_CUARTEL + 3.0)["pos"])


func _foto(nombre: String, t: float, donde: Vector2) -> void:
	CicloDia.hora_forzada = t
	_jugador.global_position = donde + Vector2(0, 40)
	await get_tree().process_frame
	for nd in get_tree().get_nodes_in_group("aliado"):
		if nd is Node2D:
			(nd as Node2D).global_position = Vector2(-5000, -5000)
	(_jugador.get_node("Camera2D") as Camera2D).global_position = donde
	(_jugador.get_node("Camera2D") as Camera2D).reset_smoothing()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%sguardias_%s.png" % [SALIDA, nombre])


func _ok(que: String, cond: bool) -> void:
	_hechas += 1
	if cond:
		print("  ok   %s" % que)
	else:
		_fallos += 1
		printerr("  FALLA %s" % que)
