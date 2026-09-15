# ============================================================
#  dev_hogar.gd  --  HERRAMIENTA, no parte del juego.
#
#  Abre el menu del HOGAR de verdad (scripts/ui/home_menu.gd) con la partida de prueba, un cofre con
#  piezas, consumibles y dinero en la hucha, y saca una captura de cada pestaña y apartado.
#
#  NO TOCA TU PARTIDA: sin ranura activa ni mundo abierto no se guarda nada (ver Perfil.guardar_actual).
#
#  Con ventana (headless no dibuja UI) y process_mode = ALWAYS (el menu pausa el arbol).
#    godot --path . res://tools/visores/dev_hogar.tscn -- capturas [prefijo]
# ============================================================
extends Node

const SALIDA := "res://tools/salida/"
const PartidaDePrueba = preload("res://tools/visores/partida_de_prueba.gd")

var _menu: CanvasLayer = null
var _prefijo := "hogar"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DisplayServer.window_set_size(Vector2i(1280, 720))
	Perfil.ranura_actual = 0
	Mundos.abierto = ""
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2:
		_prefijo = args[1]

	PartidaDePrueba.llenar()
	Game.asegurar_uids()
	_falso_jugador()
	_llenar_hogar()
	if args.has("multi"):
		_simular_multi()
	# El pueblo de mentira: hay cosas del hogar que solo se hacen en el pueblo.
	if get_tree().current_scene != null:
		get_tree().current_scene.scene_file_path = "res://scenes/town.tscn"

	_menu = preload("res://scripts/ui/home_menu.gd").new()
	add_child(_menu)
	add_child(preload("res://scripts/ui/peticion_formacion.gd").new())
	_menu.abrir()
	_barra()

	if args.has("capturas"):
		await _pasada()
		get_tree().quit()


# Dinero en la hucha, piezas del baul en el cofre, consumibles dentro y fuera.
func _llenar_hogar() -> void:
	Game.bote_dinero = 1250
	# MATERIALES en la bolsa y en casa, en cantidades muy distintas (las mismas que el visor del inventario).
	Game.materiales = []
	Game.almacen_materiales = []
	var i: int = 0
	for id in ["cobre", "cobre_veteado", "acero", "madera_comun", "cuero_simple", "baba_slime",
			"nucleo_slime", "ajo", "cebolla"]:
		var d: MaterialData = load("res://resources/materials/%s.tres" % id) as MaterialData
		if d == null:
			continue
		i += 1
		for _n in (i * 7) % 20 + 1:
			var it := MaterialItem.new()
			it.data = d
			it.calidad = MaterialItem.Calidad.NORMAL
			Game.materiales.append(it)
		for _n in (i * 23) % 120 + 5:
			var it2 := MaterialItem.new()
			it2.data = d
			it2.calidad = MaterialItem.Calidad.INTACTO
			Game.almacen_materiales.append(it2)
	# UTILES: mochilas y herramientas (con farolillos) en el baul, para meter parte en el cofre.
	var mo: BackpackData = load("res://resources/backpacks/mochila_basica.tres") as BackpackData
	if mo != null:
		for r in 3:
			Game.crear_item(mo, (r % 3) + 1, r * 2, {})
	for id in ["pico_basico", "hoz_basica", "farolillo_basico", "cuchillo_basico"]:
		var t: ToolData = load("res://resources/tools/%s.tres" % id) as ToolData
		if t != null:
			for k in 2:
				Game.crear_item(t, k + 1, k * 3, {})
	# EL COFRE: algunas piezas de cada clase que no lleve nadie.
	for lista in [Game.owned_weapons, Game.owned_armor, Game.owned_mochilas, Game.owned_tools]:
		var n: int = 0
		for it3 in lista.duplicate():
			if n >= 3:
				break
			if not Game.item_equipado(it3) and Net.hogar.meter_en_cofre(it3):
				n += 1
	# CONSUMIBLES dentro y fuera.
	for ruta in ["res://resources/consumables/pocion_menor.tres", "res://resources/consumables/piedra_retorno.tres",
			"res://resources/consumables/pocion_media.tres"]:
		if ResourceLoader.exists(ruta):
			var c: Resource = load(ruta)
			Game.consumables[c] = 3
			Game.cofre_consumibles[ruta] = 2


# Las secciones viven en su archivo desde el troceo; antes, en el propio menu. Se mira donde esta el
# estado para que la misma pasada sirva para comparar las dos versiones.
func _seccion(nombre: String) -> Object:
	if nombre in _menu and _menu.get(nombre) != null:
		return _menu.get(nombre)
	return _menu


func _pasada() -> void:
	DirAccess.make_dir_recursive_absolute(SALIDA)
	var tabs: Array = _menu.TABS
	# EL EQUIPO Y SU EDITOR (en la pasada "multi" se ven las insignias P2 y el cupo de dos).
	var eq = _seccion("equipo")
	await _captura("equipo_vista")
	eq.abrir_editor()
	await _captura("equipo_editor")
	# EL BUG DEL CUPO: con el cupo lleno, enviar a casa a uno y añadir a otro de casa en el mismo
	# borrador. Al confirmar tiene que quedar ESE, no el original colado.
	var fuera: PersonajeData = Game.party[0]
	eq.editor._alternar(fuera)
	var entra: PersonajeData = null
	for pj in Game.plantilla:
		if not Game.party.has(pj) and Game.pj_por_uid(String(pj.uid)) != null:
			entra = pj
			break
	if entra != null:
		eq.editor._alternar(entra)
	await _captura("equipo_editor_cambio")
	eq.editor.soltar(0, 3)
	await _captura("equipo_editor_arrastrado")
	eq.editor.confirmar()
	print("[hogar] equipo tras confirmar: ", Game.party.map(func(x): return x.nombre), "  formacion: ", Net.formacion.formacion())
	await _captura("equipo_confirmado")
	Net.formacion.peticion_recibida.emit(99, "Hermano", "Hermano quiere cambiar el orden del equipo: Ilyan al puesto 2.")
	await _captura("equipo_peticion")
	for n in get_children():
		if n.has_method("_contestar"):
			n._contestar(false)   # que no tape el resto de capturas
	for i in tabs.size():
		_menu._on_tab(i)
		match str(tabs[i]):
			"Encargos":
				for s in 2:
					_seccion("encargos")._enc_sub = s
					_menu._rebuild()
					await _captura("%d_encargos_%d" % [i, s])
			"Cofre":
				var alm = _seccion("almacen")
				for c in alm.CATEGORIAS.size():
					alm._on_cat(c)
					await _captura("%d_almacen_%d" % [i, c])
				# Las subcategorias de equipo y un filtro de armas.
				alm._on_cat(alm.CAT_EQUIPO)
				for s in 3:
					alm._on_sub(s)
					await _captura("%d_almacen_equipo_sub%d" % [i, s])
				alm._on_cat(alm.CAT_ARMAS)
				alm._on_sub(3)
				await _captura("%d_almacen_armas_filtro" % i)
				alm._on_sub(0)
				# Elegir otra celda y mover una pieza.
				alm._pick(1, alm.LADO_CASA)
				await _captura("%d_almacen_armas_pick" % i)
				# ARRASTRAR: lo que haria soltar una celda del inventario en la columna de casa.
				alm._soltar({"cofre_lado": alm.LADO_ENCIMA, "cofre_idx": 2}, alm.LADO_CASA)
				await _captura("%d_almacen_armas_soltada" % i)
				# EL GESTO DE VERDAD: pulsar una celda del inventario, mover el raton a la columna de casa y
				# soltar, con eventos de raton. Es lo unico que prueba el arrastre y no solo la funcion.
				await _arrastre_real(alm)
				await _captura("%d_almacen_armas_arrastrada" % i)
				# El modal de materiales.
				alm._on_cat(alm.CAT_MATERIALES)
				alm._confirmar_bloque("recoger")
				await _captura("%d_almacen_modal" % i)
				alm.cerrar_modal()
			_:
				await _captura("%d_%s" % [i, str(tabs[i]).to_lower()])


func _arrastre_real(alm) -> void:
	var antes_inv: int = (alm._stacks[alm.LADO_ENCIMA] as Array).size()
	var antes_casa: int = (alm._stacks[alm.LADO_CASA] as Array).size()
	var celda: Control = null
	for h in alm._columna[alm.LADO_ENCIMA].get_children():
		if h is GridContainer and h.get_child_count() > 4:
			celda = h.get_child(4)
	if celda == null:
		print("[hogar] ARRASTRE: no hay celda que arrastrar")
		return
	var desde: Vector2 = celda.get_global_rect().get_center()
	var hasta: Vector2 = (alm._columna[alm.LADO_CASA].get_parent() as Control).get_global_rect().get_center()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = desde
	ev.global_position = desde
	Input.parse_input_event(ev)
	await get_tree().process_frame
	for k in 12:
		var mv := InputEventMouseMotion.new()
		var pos: Vector2 = desde.lerp(hasta, float(k + 1) / 12.0)
		mv.position = pos
		mv.global_position = pos
		mv.button_mask = MOUSE_BUTTON_MASK_LEFT
		mv.relative = (hasta - desde) / 12.0
		Input.parse_input_event(mv)
		await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = hasta
	up.global_position = hasta
	Input.parse_input_event(up)
	for k in 3:
		await get_tree().process_frame
	var despues_inv: int = (alm._stacks[alm.LADO_ENCIMA] as Array).size()
	var despues_casa: int = (alm._stacks[alm.LADO_CASA] as Array).size()
	print("[hogar] ARRASTRE REAL: inventario %d -> %d, casa %d -> %d  %s" % [antes_inv, despues_inv,
		antes_casa, despues_casa, "OK" if despues_inv == antes_inv - 1 and despues_casa == antes_casa + 1 else "FALLA"])


# ============================================================
#  MULTI DE MENTIRA ("multi" en los argumentos)
#  Sin red de verdad: el peer por defecto de Godot es OfflineMultiplayerPeer, asi que los .rpc() no
#  salen a ningun sitio. Se hace de host con un jugador 2 ("Hermano") de dos personajes, cupo 2 y la
#  formacion INTERCALADA [tuyo, suyo, tuyo, suyo], que es lo que hay que ver.
# ============================================================
func _simular_multi() -> void:
	Net.activo = true
	Net.es_host = true
	Net._num_humanos = 2
	Net._identidades[2] = "hermano"
	# Tu equipo, al cupo de dos.
	var mios: Array[PersonajeData] = [Game.party[0], Game.party[1]]
	Game.party.assign(mios)
	Game.lider_idx = 0
	# El hermano: dos personajes suyos que van en su equipo.
	var jd := JugadorData.new()
	jd.id = "hermano"
	jd.nombre_visible = "Hermano"
	for k in 2:
		var pj: PersonajeData = Game.plantilla[2 + k].duplicate(true) as PersonajeData
		pj.nombre = ["Kael", "Mira"][k]
		pj.uid = "hermano_%d" % k
		pj.color = Color.from_hsv(0.55 + 0.2 * float(k), 0.6, 0.9)
		jd.personajes.append(pj)
		jd.equipo.append(pj)
	Game.jugadores_mundo["hermano"] = jd
	var filas: Array = []
	for pj in jd.personajes:
		filas.append(Net.hogar._fila_roster(pj, "hermano", "Hermano"))
	Net.hogar._roster_ajeno["hermano"] = filas
	Net.formacion.reconciliar()
	var f: Array = Net.formacion._formacion
	if f.size() == 4:
		Net.formacion._formacion = [f[0], f[2], f[1], f[3]]


# La barrita de pruebas, abajo a la izquierda: reabrir el hogar si se cierra con Esc.
func _barra() -> void:
	var capa := CanvasLayer.new()
	capa.layer = 120
	add_child(capa)
	var b := Button.new()
	b.text = "Reabrir hogar"
	b.focus_mode = Control.FOCUS_NONE
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 12
	b.offset_top = -44
	b.offset_bottom = -12
	b.pressed.connect(func():
		if not _menu._root.visible:
			_menu.abrir())
	capa.add_child(b)


func _falso_jugador() -> void:
	var sc := GDScript.new()
	sc.source_code = """
extends Node
func aguante_de_grupo(pj) -> Vector2:
	var tope := 60.0 + float(pj.resistencia) * 0.12
	return Vector2(tope, tope)
func refrescar_grupo() -> void:
	pass
func refrescar_lider() -> void:
	pass
"""
	sc.reload()
	var n := Node.new()
	n.name = "JugadorDePrueba"
	n.set_script(sc)
	n.add_to_group("player")
	add_child(n)


func _captura(nombre: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var ruta: String = "%s%s_%s.png" % [SALIDA, _prefijo, nombre]
	get_viewport().get_texture().get_image().save_png(ruta)
	print("[hogar] ", ProjectSettings.globalize_path(ruta))
