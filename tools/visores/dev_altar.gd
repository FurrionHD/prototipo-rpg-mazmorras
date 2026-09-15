# ============================================================
#  dev_altar.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el menu del ALTAR de verdad (scripts/ui/altar_menu.gd) y el de SUBIR DE NIVEL
#  (scripts/ui/desarrollo_menu.gd) con un escenario donde sale TODO a la vez, para poder tocarlo:
#
#    - el LIDER (Ilyan) a nivel 1, con el guardian vencido y rango C: puede subir, y como no tiene
#      ningun desarrollo y todos los contadores estan llenos, al subir salen LAS ONCE.
#    - Sedaki tiene LAS ONCE aprendidas en rango I con los contadores de sobra: al actualizar le
#      suben todas a la vez.
#    - todos (menos Bram, el pelado) llevan LAS NUEVE PASIVAS pendientes y excelia sin consolidar:
#      punto ambar en el retrato y, al actualizar, el modal con todo.
#    - Oriol espera en el Hogar con excelia pendiente: el caso del banquillo.
#
#  NO SE CIERRA SOLO. Abajo a la izquierda hay una barrita para reabrir el altar si lo cierras con
#  Esc, rehacer el escenario (para volver a pulsar Actualizar) o ir directo a subir de nivel.
#
#  NO TOCA TU PARTIDA: sin ranura activa ni mundo abierto, Game.guardar_mi_partida() no escribe nada
#  (ver Perfil.guardar_actual), y subir de nivel guarda. Se fuerzan las dos cosas al arrancar.
#
#  Con el argumento "capturas" hace una pasada sola, guarda tools/salida/altar_*.png y se cierra:
#    godot --path . res://tools/visores/dev_altar.tscn -- capturas
#
#  Va CON VENTANA (un Control no se dibuja en headless) y con process_mode = ALWAYS (el menu pausa el
#  arbol al abrirse).
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

var _altar: CanvasLayer = null
var _subida: CanvasLayer = null
var _inicial: Dictionary = {}   # {PersonajeData: {level, fuerza...}} tal y como los deja la partida


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	# Que nada llegue al disco: ver la cabecera.
	Perfil.ranura_actual = 0
	Mundos.abierto = ""

	PartidaDePrueba.llenar()
	_falso_jugador()
	_banquillo()
	_escenario()

	_altar = preload("res://scripts/ui/altar_menu.gd").new()
	add_child(_altar)
	_subida = preload("res://scripts/ui/desarrollo_menu.gd").new()
	add_child(_subida)
	_barra()
	_altar.abrir()

	if OS.get_cmdline_user_args().has("capturas"):
		await _pasada()
		get_tree().quit()


# ============================================================
#  EL ESCENARIO
# ============================================================

# Un quinto que NO baja: se queda en la plantilla pero fuera del party.
func _banquillo() -> void:
	var pj: PersonajeData = Game.party[1].duplicate(true) as PersonajeData
	pj.nombre = "Oriol"
	pj.es_original = false
	pj.color = Color.from_hsv(0.62, 0.5, 0.85)
	Game.plantilla.append(pj)


func _escenario() -> void:
	var gente: Array = []
	for p in Game.party:
		gente.append(p)
	for p in Game.en_el_banquillo():
		gente.append(p)
	var lider: PersonajeData = Game.lider()
	var sedaki: PersonajeData = Game.party[1]
	var pelado: PersonajeData = Game.party[3]

	for pj in gente:
		# Lo de PARTIDA se apunta la primera vez y se repone en las siguientes: tras subir de nivel las
		# basicas quedan a 0 y "Rehacer escenario" tiene que dejarlo todo como al abrir.
		if not _inicial.has(pj):
			var foto: Dictionary = {"level": pj.level}
			for s in ["fuerza", "resistencia", "destreza", "agilidad", "magia"]:
				foto[s] = int(pj.get(s))
			_inicial[pj] = foto
		var ini: Dictionary = _inicial[pj]
		pj.level = int(ini["level"])
		for s in ["fuerza", "resistencia", "destreza", "agilidad", "magia"]:
			pj.set(s, int(ini[s]))
		pj.guardianes_vencidos.clear()
		pj.pasivas_rng.clear()
		pj.pasivas_pendientes.clear()
		pj.desarrollos_rango.clear()
		for d in Game.DESARROLLOS:
			pj.set(str(d["contador"]), 0.0)
		# Lo VISIBLE sale de consolidado - base_nivel: se parte de lo que ya enseña la ficha.
		for s in ["fuerza", "resistencia", "destreza", "agilidad", "magia"]:
			var v: float = float(pj.get(s))
			pj.ability_base_nivel[s] = 0.0
			pj.ability_consolidado[s] = v
			pj.ability_internal[s] = v
		if pj == pelado:
			continue   # el pelado: nada pendiente, para ver el caso vacio
		# EXCELIA PENDIENTE, distinta en cada basica para que las barras verdes no midan igual.
		var k: int = 0
		for s in ["fuerza", "resistencia", "destreza", "agilidad", "magia"]:
			pj.ability_internal[s] = float(pj.ability_consolidado[s]) + 15.0 + 22.0 * float(k)
			k += 1
		for p in Game.PASIVAS_RNG:
			pj.pasivas_pendientes[str(p["id"])] = true

	# EL LIDER: nivel 1, guardian del 2 vencido y rango C en Fuerza (por el total oculto).
	lider.level = 1
	lider.guardianes_vencidos[2] = true
	lider.ability_internal["fuerza"] = maxf(float(lider.ability_internal["fuerza"]),
		float(Game.RANGO_C_MIN) + 20.0)
	# Sin ningun desarrollo y con todos los contadores llenos: al subir se ofrecen los once.
	for d in Game.DESARROLLOS:
		lider.set(str(d["contador"]), float(d["umbral"]) * 1.05)

	# SEDAKI: los once en rango I, con contador para subir a rangos distintos (del II al VII), asi los
	# rombos del modal no salen todos iguales.
	var n: int = 0
	for d in Game.DESARROLLOS:
		var id: String = str(d["id"])
		sedaki.desarrollos_rango[id] = 1
		var objetivo: int = 2 + (n % 6)
		var req: float = Game.req_de_rango(float(d["umbral"]), objetivo,
			float(d.get("rango_mult", Game.RANGO_MULT)))
		sedaki.set(str(d["contador"]), req * 1.01)
		n += 1


# ============================================================
#  LA BARRITA DE PRUEBAS
# ============================================================

func _barra() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 120
	add_child(capa)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	panel.offset_left = 12
	panel.offset_bottom = -12
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.25, 0.05, 0.25, 0.92)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)
	capa.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	panel.add_child(hb)
	var t := Label.new()
	t.text = "PRUEBAS:"
	t.add_theme_font_size_override("font_size", 12)
	hb.add_child(t)
	_boton(hb, "Reabrir altar", _reabrir)
	_boton(hb, "Rehacer escenario", _rehacer)
	_boton(hb, "Subir de nivel", _subir_directo)


func _boton(hb: HBoxContainer, txt: String, al_pulsar: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 12)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(al_pulsar)
	hb.add_child(b)


func _cerrar_todo() -> void:
	if _subida._root.visible:
		_subida._cerrar()
	if _altar._root.visible:
		_altar._cerrar()


func _reabrir() -> void:
	_cerrar_todo()
	_altar.abrir()


func _rehacer() -> void:
	_cerrar_todo()
	_escenario()
	_altar.abrir()


# Por el ALTAR, como en el juego: asi al elegir o al aplazar se vuelve a el y no a la nada.
func _subir_directo() -> void:
	_cerrar_todo()
	_altar.abrir()
	_altar._subir()


# ============================================================
#  LA PASADA DE CAPTURAS
# ============================================================

func _pasada() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	await _captura("0_lider_pendiente")
	_altar._actualizar(Game.lider())
	await _captura("1_lider_modal")
	await _bajar_scroll(_altar._modal)
	await _captura("1_lider_modal_abajo")
	_altar._cerrar_modal()
	await _captura("2_lider_actualizado")

	_altar._pick_persona(1)
	await _captura("3_sedaki_pendiente")
	_altar._actualizar(Game.party[1])
	await _captura("4_sedaki_modal")
	await _bajar_scroll(_altar._modal)
	await _captura("4_sedaki_modal_abajo")
	_altar._cerrar_modal()

	_altar._pick_persona(3)
	_altar._actualizar(Game.party[3])
	await _captura("5_pelado_sin_cambios")
	_altar._pick_persona(4)
	await _captura("6_banquillo")

	# SUBIR DE NIVEL: primero se rehace el escenario (el lider ya ha consolidado arriba, pero sus
	# contadores siguen llenos, asi que da igual) y se abre directo.
	_rehacer()
	_altar._subir()
	await _captura("7_subir")
	await _bajar_scroll(_subida._root)
	await _captura("7_subir_abajo")
	_subida._pick(7)
	await _captura("8_subir_elegida")
	# APLAZAR: tiene que volver al altar, no dejar la pantalla vacia. Y luego se vuelve a entrar.
	_subida._cerrar()
	await _captura("8b_aplazar_vuelve_al_altar")
	_altar._subir()
	_subida._pick(7)
	# Al elegir, el selector vuelve SOLO al altar (abierto desde el): la captura tiene que salir con
	# el altar delante y el "reinicio" en las cinco basicas.
	_subida._elegir(str(Game.desarrollos_disponibles()[_subida._sel]["id"]))
	await _captura("9_tras_subir")
	# Y el pelado, con el punto: tras rehacer, todos menos el tienen algo pendiente.
	_rehacer()
	_altar._pick_persona(3)
	await _captura("9b_marcas_retratos")

	# VENTANA ESTRECHA: que no se corte ningun nombre ni se monte nada.
	DisplayServer.window_set_size(Vector2i(960, 600))
	await get_tree().process_frame
	await get_tree().process_frame
	_rehacer()
	await _captura("10_estrecha_altar")
	_subir_directo()
	await _captura("10_estrecha_subir")


func _bajar_scroll(raiz: Node) -> void:
	await RenderingServer.frame_post_draw
	if raiz == null:
		return
	for s in raiz.find_children("*", "ScrollContainer", true, false):
		(s as ScrollContainer).scroll_vertical = 100000


# Copia de la de dev_personaje: el jugador de mentira que responde a aguante_de_grupo.
func _falso_jugador() -> void:
	var sc := GDScript.new()
	sc.source_code = """
extends Node
func aguante_de_grupo(pj) -> Vector2:
	var tope := 60.0 + float(pj.resistencia) * 0.12
	return Vector2(tope, tope)
func refrescar_grupo() -> void:
	pass
"""
	sc.reload()
	var n := Node.new()
	n.name = "JugadorDePrueba"
	n.set_script(sc)
	n.add_to_group("player")
	add_child(n)


func _captura(nombre: String) -> void:
	# DOS frames: el primero coloca los contenedores y el segundo ya dibuja lo colocado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%saltar_%s.png" % [SALIDA, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[altar] ", ProjectSettings.globalize_path(ruta))
