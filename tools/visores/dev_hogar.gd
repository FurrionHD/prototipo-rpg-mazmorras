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
	_falso_jugador()
	_llenar_hogar()
	# El pueblo de mentira: hay cosas del hogar que solo se hacen en el pueblo.
	if get_tree().current_scene != null:
		get_tree().current_scene.scene_file_path = "res://scenes/town.tscn"

	_menu = preload("res://scripts/ui/home_menu.gd").new()
	add_child(_menu)
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
					await _captura("%d_almacen_%d_casa" % [i, c])
					if c == alm.CAT_HUCHA:
						continue
					alm._on_lado(alm.LADO_ENCIMA)
					await _captura("%d_almacen_%d_encima" % [i, c])
					alm._on_lado(alm.LADO_CASA)
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
				alm._pick(1)
				await _captura("%d_almacen_armas_pick" % i)
				alm._mover(alm._stacks[alm._sel], 1)
				await _captura("%d_almacen_armas_sacada" % i)
				# El modal de materiales.
				alm._on_cat(alm.CAT_MATERIALES)
				alm._confirmar_bloque("recoger")
				await _captura("%d_almacen_modal" % i)
				alm.cerrar_modal()
			_:
				await _captura("%d_%s" % [i, str(tabs[i]).to_lower()])


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
