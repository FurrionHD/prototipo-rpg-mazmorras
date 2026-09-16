# ============================================================
#  craft_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu de RECETAS con los materiales del baul del Hogar. Sirve a DOS talleres, y el que sea lo
#  decide `modo` (ver MODOS abajo), que se le pone al instanciarlo desde player.gd:
#    POCIONES -> la BOTICARIA (boticaria.gd). Tiers Menores/Medianas x tipo Vida/Maná/Antídotos, con
#                mejoras que consumen la poción del escalon anterior. Oficio: MEZCLA.
#    COCINA   -> el COCINERO (cocinero.gd). Tiers T1/T2, sin sub-tipo y sin mejoras. Oficio: COCINA.
#  Van en el mismo archivo porque comparten TODO lo que cuesta: los contadores de calidad por
#  ingrediente, las reservas de multijugador y el calculo de cuantas piezas salen. Lo unico
#  distinto entre los dos son las pestañas, los textos y de donde salen las recetas.
#
#  Lo abre su NPC del pueblo (-> abrir()). No hay tecla propia: se entra por el NPC. Congela al
#  jugador via Game.inventory_open mientras esta abierto.
#
#  REHECHO el 16/09/2026 con la cara del inventario, igual que la peleteria (la plantilla): rejilla de
#  celdas a la izquierda (cada celda es LO QUE SALE: la poción o el plato), ficha ancha a la derecha y
#  los botones en un pie fijo debajo de ella. Arriba, las pestañas son los TIERS; encima de la rejilla,
#  en las pociones, el filtro Todo / Vida / Maná / Antídotos.
#
#  Este archivo es el ARMAZON: montaje, pestañas, rejilla, quien trabaja y piezas comunes de la ficha.
#  La pantalla de recetas vive en scripts/ui/taller/taller_recetas.gd. Toda la MATH sigue en Game.
#
#  ⚠️ El montaje es el MISMO que el de la peleteria y la tienda (ver tannery_menu._ready), copiado a
#  proposito: la regla del rework es un menu cada vez. Cuando le toque a forge_menu, ese montaje sube a
#  MenuScaffold y todas lo llaman.
# ============================================================

extends CanvasLayer

const TallerRecetas = preload("res://scripts/ui/taller/taller_recetas.gd")

# Que oficio es este menu. Se le pone ANTES de meterlo al arbol (player.gd), porque _ready() ya lo
# usa para elegir su grupo y su titulo.
enum Modo { POCIONES, COCINA }
var modo: int = Modo.POCIONES

func es_cocina() -> bool: return modo == Modo.COCINA

# El OFICIO de este taller: el id de su desarrollo, que es tambien la clave de su artesano.
func oficio() -> String: return "cocina" if es_cocina() else "mezcla"

# La PIEZA que sale de una receta, en singular y plural, para no escribir "poción" en un menu que
# esta haciendo un kebab.
func pieza_txt(n: int = 1) -> String:
	if es_cocina():
		return "plato" if n == 1 else "platos"
	return "poción" if n == 1 else "pociones"

# Las pestañas de arriba son los TIERS, con icono y sin texto (el nombre se lee arriba a la izquierda).
func tabs() -> Array:
	return ["De la cueva", "De lo hondo"] if es_cocina() else ["Menores", "Medianas"]
const TAB_ICONOS := ["tier_1", "tier_2"]

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const ROJO := Color(0.9, 0.5, 0.5)
const GRIS := Color(0.6, 0.63, 0.7)

# De mejor a peor (el enum de calidad NO esta ordenado: PURO se añadio al final).
const CALIDADES := [MaterialItem.Calidad.PURO, MaterialItem.Calidad.INTACTO,
	MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.DANADO]

const LADO_CELDA := 96.0
# EL REPARTO DEL ANCHO, que cambia con el taller. Una columna de ingrediente con sus contadores mide
# unos 280 px, y eso manda:
#   - POCIONES: la rejilla son diez recetas y con cuatro columnas cada fila es una cadena (base, +1,
#     +2, +3). La ficha lleva los ingredientes en DOS columnas (ver taller_recetas.COLUMNAS_ING): las
#     pociones llevan dos, y el antidoto que lleva tres pone el tercero debajo.
#   - COCINA: un plato lleva hasta SEIS ingredientes y van en TRES columnas. Con la rejilla a 420 la
#     tercera se salia por el canto de la pantalla, y con la rejilla a 300 el cuarto retrato de QUIEN
#     TRABAJA quedaba cortado (vistos los dos en captura): 330 es lo que piden cuatro retratos.
const ANCHO_FICHA := 780.0
const ANCHO_REJILLA_MIN := 420.0
const ANCHO_FICHA_COCINA := 875.0
const ANCHO_REJILLA_COCINA := 330.0

var _root: Control = null
var _header: VBoxContainer = null
var _lista: VBoxContainer = null      # la rejilla de celdas (columna izquierda)
var _content: VBoxContainer = null    # la ficha (columna derecha)
var _acciones: VBoxContainer = null   # bajo la ficha y FUERA de su scroll: siempre a la vista
var _contador_lbl: Label = null
var _aviso_lbl: Label = null
var _titulo_seccion: Label = null
var _tab_buttons: Array = []
# La fila de FILTROS de la columna izquierda (el tipo de poción). Vacia, desaparece.
var barra_sub: HBoxContainer = null
# La fila de retratos: quien esta trabajando en este taller (ver Game.artesano).
var _fila_artesano: HBoxContainer = null
var _fila_artesano_rotulo: Label = null

var recetas = null   # TallerRecetas

var tier: int = 1            # la pestaña: 1 menores / de la cueva, 2 medianas / de lo hondo
var sel: int = 0             # celda elegida en la rejilla
var stacks: Array = []       # lo pintado en la rejilla (las RecipeData), en el mismo orden
var _aviso: String = ""
var _aviso_ok: bool = true


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("cocina_menu" if es_cocina() else "craft_menu")
	recetas = TallerRecetas.new(self)

	# MULTI: refresco en vivo cuando el compañero toca el baul o su reserva (ver forge_menu).
	if Net.has_signal("hogar_cambiado"):
		Net.hogar_cambiado.connect(_on_cambio_externo)
	if Net.has_signal("reservas_cambiadas"):
		Net.reservas_cambiadas.connect(_on_cambio_externo)

	# El SITIO, no la persona (como la peleteria): lo haces tu con tus personajes.
	var m: Dictionary = MenuScaffold.construir(self, "COCINA" if es_cocina() else "BOTICARIA", "",
		_cerrar, false, false)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]
	# FUERA la cabecera entera (ver tannery_menu): vacia reservaba un palmo muerto.
	((m["aviso"] as Control).get_parent().get_parent() as Control).visible = false

	var ficha: float = ANCHO_FICHA_COCINA if es_cocina() else ANCHO_FICHA
	var scroll: ScrollContainer = m["lista_scroll"]
	scroll.custom_minimum_size = Vector2(_ancho_rejilla(), 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ficha, 0)
	var scroll_det: ScrollContainer = _content.get_parent() as ScrollContainer
	scroll_det.size_flags_horizontal = Control.SIZE_FILL
	scroll_det.custom_minimum_size = Vector2(ficha, 0)
	scroll.resized.connect(_on_lista_redimensionada)
	_lista.resized.connect(_on_lista_redimensionada)

	# LA COLUMNA DERECHA: la ficha con su scroll y, DEBAJO Y FUERA DEL SCROLL, las acciones.
	var split_der: BoxContainer = scroll_det.get_parent()
	split_der.remove_child(scroll_det)
	var col_der := VBoxContainer.new()
	col_der.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_der.custom_minimum_size = Vector2(ficha, 0)
	col_der.add_theme_constant_override("separation", 6)
	split_der.add_child(col_der)
	col_der.add_child(scroll_det)
	scroll_det.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_aviso_lbl = Label.new()
	_aviso_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso_lbl.add_theme_font_size_override("font_size", 13)
	col_der.add_child(_aviso_lbl)
	_acciones = VBoxContainer.new()
	_acciones.add_theme_constant_override("separation", 4)
	col_der.add_child(_acciones)

	# LA COLUMNA IZQUIERDA: quien trabaja, la fila de filtros y la rejilla.
	var split: BoxContainer = scroll.get_parent()
	split.remove_child(scroll)
	var col_izq := VBoxContainer.new()
	col_izq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_izq.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_izq.add_theme_constant_override("separation", 6)
	split.add_child(col_izq)
	split.move_child(col_izq, 0)
	var rotulo := Label.new()
	rotulo.text = "QUIÉN TRABAJA"
	rotulo.add_theme_font_size_override("font_size", 11)
	rotulo.add_theme_color_override("font_color", MenuScaffold.GRIS)
	_fila_artesano_rotulo = rotulo
	col_izq.add_child(rotulo)
	_fila_artesano = MenuScaffold.fila_retratos(col_izq)

	barra_sub = HBoxContainer.new()
	barra_sub.alignment = BoxContainer.ALIGNMENT_CENTER
	barra_sub.add_theme_constant_override("separation", 14)
	col_izq.add_child(barra_sub)
	col_izq.add_child(scroll)

	# LAS PESTAÑAS (los tiers), con icono y centradas en la pantalla.
	var barra_tabs: HBoxContainer = m["side"]
	barra_tabs.add_theme_constant_override("separation", 14)
	var nombres: Array = tabs()
	for i in nombres.size():
		var b: Button = MenuScaffold.pestana_icono(TAB_ICONOS[i], nombres[i])
		b.pressed.connect(_on_tab.bind(i + 1))
		barra_tabs.add_child(b)
		_tab_buttons.append(b)

	var barra: BoxContainer = barra_tabs.get_parent()
	(barra.get_child(0) as Control).visible = false
	# EL TITULO EN DOS LINEAS: el taller pequeño y gris encima del tier, grande.
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = "Cocina" if es_cocina() else "Boticaria"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", MenuScaffold.GRIS)
	titulo.add_child(chico)
	_titulo_seccion = Label.new()
	_titulo_seccion.add_theme_font_size_override("font_size", 20)
	_titulo_seccion.add_theme_color_override("font_color", AMBAR)
	titulo.add_child(_titulo_seccion)
	barra.add_child(titulo)
	barra.move_child(titulo, 1)

	barra.remove_child(barra_tabs)
	var centrador := CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centrador.offset_top = 16.0
	centrador.offset_bottom = 16.0 + MenuScaffold.LADO_ICONO
	centrador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centrador)
	centrador.add_child(barra_tabs)

	_contador_lbl = Label.new()
	_contador_lbl.add_theme_font_size_override("font_size", 15)
	_contador_lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.90))
	barra.add_child(_contador_lbl)
	barra.move_child(_contador_lbl, barra.get_child_count() - 2)


func abrir() -> void:
	# No abrir sobre un combate/extraccion ni con el panel DEBUG abierto.
	if Game._active_layer != null or Game.debug_panel_open:
		return
	# MULTI: no se coge el candado al abrir (los dos a la vez); se coge solo al fabricar, y lo
	# seleccionado se RESERVA para el otro. Ver forge_menu.
	tier = 1
	sel = 0
	_aviso = ""
	recetas.abrir()
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)
	if Net.activo:
		Net.hogar.liberar_mis_reservas()


func _on_cambio_externo() -> void:
	if _root != null and _root.visible:
		_rebuild()


func ocupado() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("Un momento: tu compañero está creando algo justo ahora.")


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			_cerrar()
			get_viewport().set_input_as_handled()


func _on_tab(t: int) -> void:
	if t == tier:
		return
	tier = t
	cambiar_pantalla()


# Lo que se enseña ha cambiado (tier, filtro, artesano): la celda elegida ya no vale.
func cambiar_pantalla() -> void:
	sel = 0
	_aviso = ""
	recetas.cambio_de_receta()
	_rebuild()


# ============================================================
#  RECONSTRUIR
# ============================================================

# Guardia de REENTRADA (ver tannery_menu): sin ella el menu salia DUPLICADO.
var _reconstruyendo := false
# Solo ha cambiado la celda elegida: la rejilla se marca en sitio y no se rehace (ver grid_detail).
var _solo_seleccion := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


# Para la pantalla de recetas (un nombre sin guion bajo que se pueda llamar desde fuera).
func rebuild() -> void:
	_rebuild()


func _rebuild_real() -> void:
	contador("")
	MenuScaffold.subpestanas(barra_sub, [], [], -1, Callable())
	for zona in ([_content, _acciones] if _solo_seleccion else [_header, _lista, _content, _acciones]):
		MenuScaffold.vaciar(zona)
	# Las MEDIANAS solo salen cuando has conseguido algun material para hacerlas; la cocina enseña sus
	# dos tiers desde el primer dia (verlo es la mitad de la gracia: te dice a que sabe seguir bajando).
	var hay_t2: bool = es_cocina() or Game.medianas_desbloqueadas()
	if tier >= 2 and not hay_t2:
		tier = 1
	for i in _tab_buttons.size():
		var b: Button = _tab_buttons[i]
		b.button_pressed = (i + 1 == tier)
		# Con UNA sola pestaña no hay nada que elegir: fuera la barra entera.
		b.visible = hay_t2
	_titulo_seccion.text = tabs()[tier - 1]

	_pintar_artesanos()
	recetas.build()
	_partir_lineas(_content)
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	_aviso_lbl.visible = _aviso != ""


# ============================================================
#  QUIEN TRABAJA
#  Toda tu plantilla: primero los que bajan hoy y detras los que se quedan en el Hogar. No se filtra
#  por "tiene el oficio": mandar a uno que no lo tiene es justo como lo aprende (ver Game.artesano).
# ============================================================

func _gente() -> Array:
	var out: Array = []
	out.append_array(Game.party)
	out.append_array(Game.en_el_banquillo())
	return out


func _pintar_artesanos() -> void:
	var gente: Array = _gente()
	_fila_artesano_rotulo.visible = gente.size() > 1
	var actual: PersonajeData = Game.artesano(oficio())
	# QUIEN TIENE EL OFICIO se marca EN SU RETRATO, con el icono en la esquina (como la peleteria):
	# escrito en la ficha habia que leerlo, y encima solo hablaba del que estuviera elegido.
	var con_oficio: Array = []
	for i in gente.size():
		if Game.desarrollo_rango(oficio(), gente[i] as PersonajeData) > 0:
			con_oficio.append(i)
	MenuScaffold.retratos(_fila_artesano, gente, gente.find(actual), Game.party.size(),
		_on_artesano, con_oficio, "cuenco" if es_cocina() else "pocion",
		"Tiene Cocina" if es_cocina() else "Tiene Mezcla")


func _on_artesano(i: int) -> void:
	var gente: Array = _gente()
	if i < 0 or i >= gente.size():
		return
	Game.poner_artesano(oficio(), gente[i] as PersonajeData)
	# Repintar entero: con el artesano cambia el bonus del oficio, y con el la racion doble. La
	# receta elegida se queda (no ha cambiado lo que quieres hacer, solo quien lo hace).
	_aviso = ""
	_rebuild()


# La ficha va en un scroll SIN barra horizontal, y ahi una etiqueta que no parte linea impone su
# ancho a la columna entera (ver tannery_menu).
func _partir_lineas(nodo: Node) -> void:
	for h in nodo.get_children():
		if h is Label and (h as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
			(h as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_partir_lineas(h)


# ============================================================
#  LA REJILLA
# ============================================================

func _ancho_rejilla() -> float:
	return ANCHO_REJILLA_COCINA if es_cocina() else ANCHO_REJILLA_MIN


func _columnas() -> int:
	var ancho: float = _lista.size.x
	if ancho <= 1.0:
		ancho = _ancho_rejilla()
	return maxi(2, int(floorf((ancho + 6.0) / (LADO_CELDA + 6.0))))


var _cols_pintadas: int = 0

func _on_lista_redimensionada() -> void:
	if _root.visible and _columnas() != _cols_pintadas:
		_rebuild.call_deferred()


# Pinta la rejilla y la ficha de lo elegido. 'vacio' = lo que se dice cuando no hay nada.
func grid_detail(piezas: Array, ficha: Callable, vacio: String = "(nada por aquí)") -> void:
	if piezas.is_empty():
		# Apuntar las columnas TAMBIEN sin rejilla, o el resized pide rebuilds sin parar y el juego se
		# cuelga (ver tannery_menu.grid_detail).
		_cols_pintadas = _columnas()
		MenuScaffold.nota(_lista, vacio)
		return
	sel = clampi(sel, 0, piezas.size() - 1)
	if not (_solo_seleccion and MenuScaffold.marcar_en_rejilla(_lista, sel)):
		MenuScaffold.vaciar(_lista)
		_cols_pintadas = _columnas()
		MenuScaffold.rejilla_objetos(_lista, piezas, sel, _pick, _cols_pintadas, LADO_CELDA)
	ficha.call(_content)


func _pick(i: int) -> void:
	if i != sel:
		_aviso = ""   # cambiar de receta borra el aviso de la anterior
		recetas.cambio_de_receta()
	sel = i
	_solo_seleccion = true
	_rebuild()
	_solo_seleccion = false


# ============================================================
#  PIEZAS DE LA FICHA
# ============================================================

func contador(txt: String, alerta: bool = false) -> void:
	_contador_lbl.text = txt
	_contador_lbl.visible = txt != ""
	_contador_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.52, 0.52) if alerta else Color(0.78, 0.82, 0.90))


func titulo_seccion(txt: String) -> void:
	_titulo_seccion.text = txt


func decir(txt: String, ok: bool = true) -> void:
	_aviso = txt
	_aviso_ok = ok


func note(vb: VBoxContainer, txt: String) -> void:
	MenuScaffold.nota(vb, txt)


# El pie fijo de la ficha, donde van los botones.
func acciones() -> VBoxContainer:
	return _acciones


# El nombre de una calidad, como se lee en el baul.
static func cal_txt(cal: int) -> String:
	match cal:
		MaterialItem.Calidad.PURO: return "Puro"
		MaterialItem.Calidad.INTACTO: return "Intacto"
		MaterialItem.Calidad.NORMAL: return "Normal"
		MaterialItem.Calidad.DANADO: return "Dañado"
		_: return "Roto"
