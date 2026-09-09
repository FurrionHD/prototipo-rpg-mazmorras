# ============================================================
#  maestro_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  Menu del MAESTRO DE HABILIDADES: aqui se APRENDEN las tecnicas de cada arma. Solo eso.
#
#  Arriba, la fila de armas con su icono -- el mismo con el que se filtran en el inventario -- y
#  marcada la que el personaje lleva puesta. Debajo, la gente. Al centro, las tecnicas de esa arma
#  con lo que cuesta cada una, y a la derecha la ficha de la elegida con su boton.
#
#  APRENDER ES POR PERSONA (cada compañero paga las suyas), asi que lo primero de todo es a quien
#  estas mirando: los retratos mandan sobre el resto de la pantalla.
#
#  COLOCARLAS EN LOS CUATRO HUECOS NO SE HACE AQUI, se hace en la ficha del personaje, que es donde
#  se arrastran. Aqui hubo una pestaña "Equipar" que hacia lo mismo con botones, y tener el mismo
#  trabajo en dos sitios con dos gestos distintos solo servia para que uno de los dos se quedara
#  atras. Lo que si hace aprender es PONERLA SOLA si le cabe (ver Game.aprender_habilidad), para
#  que pagar por una tecnica se note en el sitio sin tener que ir a buscarla.
# ============================================================

extends CanvasLayer

const AMBAR := Color(0.95, 0.72, 0.36)
const VERDE := Color(0.55, 0.85, 0.55)
const GRIS := Color(0.6, 0.63, 0.7)

# Las mismas medidas que el inventario y la ficha de personaje: estan calibradas a las unidades
# logicas de 1280x720 (ver project.godot) y las tres pantallas tienen que verse hermanas.
const ANCHO_FICHA := 360.0
const ANCHO_LISTA_MIN := 420.0

var _root: Control = null
var _header: VBoxContainer = null
var _lista: VBoxContainer = null       # la columna del centro: las tecnicas del arma
var _content: VBoxContainer = null     # la ficha de la derecha
var _barra_armas: HBoxContainer = null # la fila de iconos de arma
var _fila_retratos: HBoxContainer = null
var _titulo_seccion: Label = null      # el nombre del arma que estas mirando
var _aviso_lbl: Label = null
var _dinero_lbl: Label = null
var _aviso: String = ""
var _aviso_ok: bool = true

# LAS TRES SECCIONES. Van en la barra de arriba con icono, como las del inventario.
#   TECNICAS    - lo de siempre: las habilidades del arma que elijas
#   MEDITACION  - el gacha: pagas y el azar decide (la magia se gana, no se compra)
#   BIBLIOTECA  - lo que has leido: grimorios, tomos de sabiduria y curiosidades
# El manifiesto de libros, por PRELOAD y no por su class_name: un class_name recien generado no
# esta en la cache de clases de Godot hasta que se abre el editor, y las herramientas se lanzan por
# linea de comandos. Es la misma razon por la que partida_de_prueba.gd se carga asi.
const Libros = preload("res://scripts/core/libros.gd")

const TABS := ["Técnicas", "Meditación", "Biblioteca"]
const TAB_ICONOS := ["habilidades", "vela", "libro"]
const TAB_TECNICAS := 0
const TAB_MEDITACION := 1
const TAB_BIBLIOTECA := 2

var _tab: int = TAB_TECNICAS
var _tab_buttons: Array = []

# LAS DOS COLUMNAS del esqueleto (lista + ficha). La Meditación NO las usa: es un CARTEL a pantalla
# completa, como cualquier banner de gacha, asi que ahi se esconden enteras y manda _capa_med.
var _split: BoxContainer = null
# La capa de la Meditación: el cartel, los retratos y los botones de tirar. Se monta una vez y se
# enseña o se esconde; volver a montarla en cada _rebuild se llevaria por delante la animacion del
# revelado a media reproduccion.
var _capa_med: Control = null
const GachaBanner = preload("res://scripts/ui/gacha_banner.gd")
var _banner: Control = null

var _pj_sel: int = 0     # a quien estamos mirando, dentro de _gente()
var _arma_idx: int = 0   # que arma del catalogo
var _sel: int = 0        # que tecnica de esa arma


func _ready() -> void:
	layer = 91
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("maestro_menu")

	# con_lateral = FALSE: las armas van en una FILA ARRIBA, no en una columna. Es la misma forma
	# que el inventario, y por el mismo motivo: con trece armas la columna seria una lista larga y
	# en fila son trece iconos que se abarcan de un vistazo.
	var m: Dictionary = MenuScaffold.construir(self, "MAESTRO", "", _cerrar, true, false)
	_root = m["root"]
	_header = m["header"]
	_lista = m["lista"]
	_content = m["content"]
	_aviso_lbl = m["aviso"]
	_dinero_lbl = m["dinero"]

	# EL REPARTO SE INVIERTE, igual que en el inventario: manda la lista del centro (es donde
	# eliges) y la ficha se queda con un ancho fijo, el justo para leerla sin barrer la vista.
	var scroll: ScrollContainer = m["lista_scroll"]
	scroll.custom_minimum_size = Vector2(ANCHO_LISTA_MIN, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_horizontal = Control.SIZE_FILL
	_content.custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	(_content.get_parent() as ScrollContainer).size_flags_horizontal = Control.SIZE_FILL
	(_content.get_parent() as ScrollContainer).custom_minimum_size = Vector2(ANCHO_FICHA, 0)
	# Las tecnicas van en dos columnas si hay ancho para ellas, asi que hay que repintarlas cuando la
	# ventana cambia de tamaño (ver _columnas).
	scroll.resized.connect(_on_lista_redimensionada)

	# LA FILA DE ARMAS, en la COLUMNA DEL CENTRO y encima de las tecnicas, que es lo que manda: es
	# el mismo sitio que las subpestañas de la ficha de personaje y del inventario. Estuvo arriba
	# del todo, por encima de la gente, y era justo al reves que los otros dos menus.
	#
	# Va FUERA del scroll (hermana suya, no hija) para que no se vaya con la lista al desplazarse:
	# la fila que elige el arma no puede desaparecer al bajar.
	var split: BoxContainer = scroll.get_parent()
	_split = split
	split.remove_child(scroll)
	var col_centro := VBoxContainer.new()
	col_centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_centro.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_centro.add_theme_constant_override("separation", 4)
	split.add_child(col_centro)
	split.move_child(col_centro, 0)

	# LA GENTE, ARRIBA DEL TODO PERO DENTRO DE LA COLUMNA, no en el header. El header del esqueleto
	# cruza la pantalla ENTERA, asi que con los retratos ahi la ficha de la derecha empezaba por
	# debajo de ellos y perdia 90 px de alto -- y esa ficha es larga (el resumen de una tecnica son
	# quince lineas), asi que lo que se perdia arriba se pagaba en scroll abajo.
	#
	# Metidos en la columna, la ficha sube hasta el borde y los retratos siguen donde tienen que
	# estar: lo primero de la pantalla, porque aprender es por persona.
	_fila_retratos = MenuScaffold.fila_retratos(col_centro)

	_barra_armas = HBoxContainer.new()
	_barra_armas.alignment = BoxContainer.ALIGNMENT_CENTER
	_barra_armas.add_theme_constant_override("separation", 10)
	col_centro.add_child(_barra_armas)
	col_centro.add_child(scroll)

	# LA FILA DE SECCIONES, con icono, igual que la del inventario (misma MenuScaffold.pestana_icono).
	# Estuvo escondida mientras este menu solo eran armas, y eso dejaba en la barra de arriba una
	# franja negra del ancho de la pantalla sin nada dentro. Ahora es donde viven las tres secciones.
	var barra_tabs: HBoxContainer = m["side"]
	barra_tabs.add_theme_constant_override("separation", 14)
	for i in TABS.size():
		var bt: Button = MenuScaffold.pestana_icono(TAB_ICONOS[i], TABS[i])
		bt.pressed.connect(_on_tab.bind(i))
		barra_tabs.add_child(bt)
		_tab_buttons.append(bt)
	var barra: BoxContainer = barra_tabs.get_parent()

	# PESTAÑAS CENTRADAS EN LA PANTALLA, igual que en el inventario y por el mismo motivo (ver el
	# comentario largo de inventory_menu): dentro de la barra "centrar" es centrar entre el titulo y
	# el dinero, que no miden lo mismo, asi que la fila queda corrida — y ademas baila cuando alguno
	# de los dos cambia de ancho. Se sacan de la barra y se cuelgan de la raiz en un CenterContainer
	# a todo lo ancho, que es el unico centro que no depende de los vecinos.
	barra.remove_child(barra_tabs)
	var centrador := CenterContainer.new()
	centrador.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	centrador.offset_top = 16.0
	centrador.offset_bottom = 16.0 + MenuScaffold.LADO_ICONO
	# Que no robe los clics de lo que hay debajo: los botones de dentro los siguen recibiendo,
	# porque un hijo con MOUSE_FILTER_STOP manda sobre el IGNORE del padre.
	centrador.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(centrador)
	centrador.add_child(barra_tabs)

	# EL TITULO EN DOS LINEAS: "Maestro" pequeño y gris encima del arma, en grande. La etiqueta que
	# trae el esqueleto se ESCONDE en vez de borrarse: un Control oculto no ocupa sitio.
	(barra.get_child(0) as Control).visible = false
	var titulo := VBoxContainer.new()
	titulo.add_theme_constant_override("separation", 0)
	var chico := Label.new()
	chico.text = "Maestro"
	chico.add_theme_font_size_override("font_size", 11)
	chico.add_theme_color_override("font_color", MenuScaffold.GRIS)
	titulo.add_child(chico)
	_titulo_seccion = Label.new()
	_titulo_seccion.add_theme_font_size_override("font_size", 20)
	_titulo_seccion.add_theme_color_override("font_color", AMBAR)
	titulo.add_child(_titulo_seccion)
	barra.add_child(titulo)
	barra.move_child(titulo, 1)

	# LAS MONEDAS, A LA BARRA. El esqueleto las cuelga ancladas bajo la esquina de la ✕, que es su
	# sitio cuando la ✕ flota; con barra superior la ✕ vive dentro de la barra y las monedas se
	# quedaban solas en mitad de la cabecera y en cuerpo 22.
	_dinero_lbl.get_parent().remove_child(_dinero_lbl)
	_dinero_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_dinero_lbl.custom_minimum_size = Vector2.ZERO
	_dinero_lbl.add_theme_font_size_override("font_size", 15)
	barra.add_child(_dinero_lbl)
	barra.move_child(_dinero_lbl, barra.get_child_count() - 2)


func abrir() -> void:
	if Game._active_layer != null or Game.debug_panel_open:
		return
	_aviso = ""
	_pj_sel = 0
	_sel = 0
	_abrir_por_su_arma()   # se abre por el arma que lleva en la mano, no por la primera del catalogo
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	_rebuild()


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)


func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_ESCAPE:
			# DE FUERA HACIA DENTRO. Esc cierra lo de encima, no la pantalla entera: abrir los
			# detalles del gacha y que Esc te echase del maestro es perder el sitio por consultar una
			# tabla. Los resultados van los primeros porque se dibujan por encima del modal.
			if _resultados != null and is_instance_valid(_resultados):
				_cerrar_resultados()
			elif _modal_abierto():
				_cerrar_detalles()
			else:
				_cerrar()
			get_viewport().set_input_as_handled()


# ============================================================
#  QUIEN, QUE ARMA Y QUE TECNICA
# ============================================================

# Todo el que puede aprender algo, en el MISMO orden que la ficha de personaje: primero los que
# bajan hoy y detras los del hogar. El orden importa porque la raya de la fila de retratos se pone
# en Game.party.size(): con otra lista, la raya cae en medio de quien no toca.
func _gente() -> Array:
	var out: Array = []
	for p in Game.party:
		out.append(p)
	for p in Game.en_el_banquillo():
		out.append(p)
	if out.is_empty():
		out.append(Game.lider())
	return out


func _pj() -> PersonajeData:
	var todos: Array = _gente()
	_pj_sel = clampi(_pj_sel, 0, todos.size() - 1)
	return todos[_pj_sel]


# Las plantillas base de todo lo que aporta habilidades: las armas y las secundarias (escudos y
# varita tambien traen las suyas, y compiten por los mismos cuatro huecos).
func _plantillas() -> Array:
	var out: Array = []
	for ruta in CatalogoEquipo.ARMAS + CatalogoEquipo.SECUNDARIAS:
		var it: Resource = load(ruta)
		if it != null and not it.habilidades.is_empty():
			out.append(it)
	return out


func _arma() -> Resource:
	var todas: Array = _plantillas()
	_arma_idx = clampi(_arma_idx, 0, todas.size() - 1)
	return todas[_arma_idx]


# Las tecnicas del arma abierta, sin los huecos vacios de su lista.
func _tecnicas() -> Array:
	var out: Array = []
	for ab in _arma().habilidades:
		if ab != null:
			out.append(ab)
	return out


func _pick_persona(i: int) -> void:
	if i == _pj_sel:
		return
	_pj_sel = i
	_sel = 0
	_aviso = ""
	# El historial es DEL PERSONAJE ELEGIDO, asi que al cambiar de cara hay que volver a la primera
	# pagina: con el otro en la 4, uno con tres tiradas se quedaba en blanco.
	_hist_pagina = 0
	_abrir_por_su_arma()
	_rebuild()


# ABRE POR EL ARMA QUE LLEVA EN LA MANO PRINCIPAL. Es lo que uno viene a mirar: las tecnicas que
# ese personaje puede usar HOY. Si va a puños (o su arma no da tecnicas) se queda donde estaba, que
# es mejor que saltar a una cualquiera.
func _abrir_por_su_arma() -> void:
	var pj: PersonajeData = _pj()
	var ruta: String = Game.ruta_base_de(pj.equipped_main) if pj.equipped_main != null else ""
	if ruta == "":
		return
	var todas: Array = _plantillas()
	for i in todas.size():
		if String(todas[i].resource_path) == ruta:
			_arma_idx = i
			return


func _pick_arma(i: int) -> void:
	if i == _arma_idx:
		return
	_arma_idx = i
	_sel = 0   # el indice viejo apunta a otra lista: sin esto la ficha enseñaba otra tecnica
	_aviso = ""
	_rebuild()


func _pick(i: int) -> void:
	_sel = i
	_rebuild()


# ============================================================
#  PINTAR
# ============================================================

# Guardia de REENTRADA. Un _rebuild puede entrar mientras otro esta a medias (las señales de red, un
# _on_* que espera en un await), y entonces el de dentro pinta su panel y el de fuera apila el suyo
# debajo: el menu salia DUPLICADO. Es el mismo guardia que lleva el herrero desde que se cazo alli.
var _reconstruyendo := false

func _rebuild() -> void:
	if _reconstruyendo:
		return
	_reconstruyendo = true
	_rebuild_real()
	_reconstruyendo = false


func _rebuild_real() -> void:
	# EL HEADER Y LA BARRA NO SE VACIAN: ahi viven la banda de retratos y la fila de armas, que son
	# de la PANTALLA y no de lo que estes mirando. Vaciarlos se llevaba por delante sus scrolls y
	# habia que remontarlos en cada pasada.
	MenuScaffold.vaciar(_lista)
	MenuScaffold.vaciar(_content)
	# EL MODAL DE DETALLES NO ES HIJO DE _lista (cuelga de _root, para flotar sobre todo), asi que
	# vaciar las columnas no se lo lleva: fuera de Meditacion hay que cerrarlo a mano. Sin esto se
	# quedaba abierto por encima de la Biblioteca, enseñando las probabilidades de otra pantalla.
	if _tab != TAB_MEDITACION:
		_cerrar_detalles()
		# Y LOS RESULTADOS DE LA TIRADA, que si no se quedaban flotando sobre la Biblioteca: tiras,
		# cambias de pestaña sin pulsar "Continuar" y las cartas seguian ahi encima.
		_tirar_resultados()
		# Y SE DESHACE EL CARTEL: la Meditación esconde las dos columnas del esqueleto para ocupar la
		# pantalla entera, asi que al salir hay que devolverlas. Sin esto, la Biblioteca aparecia en
		# blanco -- sus columnas seguian ocultas -- con el cartel del gacha por encima.
		if _capa_med != null and is_instance_valid(_capa_med):
			_capa_med.visible = false
		if _split != null:
			_split.visible = true
	MenuScaffold.decir(_aviso_lbl, _aviso, _aviso_ok)
	_dinero_lbl.text = "%d monedas" % Game.money

	var pj: PersonajeData = _pj()
	for i in _tab_buttons.size():
		(_tab_buttons[i] as Button).button_pressed = (i == _tab)
	# LOS RETRATOS, en TECNICAS y en MEDITACION pero NO en la biblioteca.
	#
	# En Meditación no son decoracion: el sesgo del gacha va POR PERSONAJE (ver Game.pesos_grimorio),
	# asi que quien este elegido cambia lo que te va a tocar, y mandarte a otra pantalla a elegirlo
	# seria esconder la mitad del mecanismo.
	#
	# En BIBLIOTECA sobran, y ademas MIENTEN: la biblioteca es de la PARTIDA y la comparte todo el
	# grupo (Game.biblioteca vive en SaveData, no en la ficha de nadie). Una fila de caras encima de
	# la coleccion da a entender que cada uno tiene la suya.
	# SE ESCONDE EL ENVOLTORIO, no la fila. MenuScaffold.fila_retratos monta
	# MarginContainer > ScrollContainer > HBox, y el scroll lleva una ALTURA MINIMA fija: ocultando
	# solo el HBox, el hueco de 90 px se queda ahi vacio — que es exactamente la franja negra que
	# habia que quitar de esta pantalla, movida de sitio.
	var caja_retratos: Control = _fila_retratos.get_parent().get_parent() as Control
	# SOLO EN TECNICAS. En la Biblioteca sobran y ademas MIENTEN (ver abajo), y en la Meditación hay
	# otra fila propia dentro del cartel: pintar tambien esta seria montar cuatro muñecos escondidos
	# detras del split en cada repintado.
	var con_retratos: bool = (_tab == TAB_TECNICAS)
	if caja_retratos != null:
		caja_retratos.visible = con_retratos
	if con_retratos:
		MenuScaffold.retratos(_fila_retratos, _gente(), _pj_sel, Game.party.size(), _pick_persona)

	# LA FILA DE ARMAS solo tiene sentido en Técnicas: en las otras dos no se elige arma. Se esconde
	# en vez de vaciarse porque un Control oculto no ocupa sitio y no hay que remontarla al volver.
	_barra_armas.visible = (_tab == TAB_TECNICAS)

	match _tab:
		TAB_TECNICAS:
			var arma: Resource = _arma()
			_titulo_seccion.text = String(arma.nombre).to_upper()
			_pintar_armas(pj)
			_pintar_tecnicas(pj, arma)
			_pintar_ficha(pj)
		TAB_MEDITACION:
			_titulo_seccion.text = "MEDITACIÓN"
			_pintar_meditacion(pj)
		TAB_BIBLIOTECA:
			_titulo_seccion.text = "BIBLIOTECA"
			_pintar_biblioteca(pj)


func _on_tab(i: int) -> void:
	_tab = i
	_sel = 0
	_aviso = ""
	_rebuild()


# LA FILA DE ARMAS. El icono de cada una es el mismo con el que se filtran en el inventario (ver
# MenuScaffold.icono_de_arma), y la que el personaje LLEVA PUESTA va marcada: es la que decide que
# tecnicas puede usar hoy, asi que tiene que verse sin leer nada.
func _pintar_armas(pj: PersonajeData) -> void:
	var todas: Array = _plantillas()
	var nombres: Array = []
	var iconos: Array = []
	var marcadas: Array = []
	# LO QUE LLEVA PUESTO se compara por la RUTA DE LA PLANTILLA y no con ==: la pieza equipada es
	# una copia (Game.crear_item la duplica) y una copia ha perdido su resource_path, asi que
	# comparar objetos no acierta nunca. ruta_base_de ademas repara las metas antiguas.
	var puestas: Array = []
	for it in [pj.equipped_main, pj.equipped_off]:
		var r: String = Game.ruta_base_de(it) if it != null else ""
		if r != "":
			puestas.append(r)
	for i in todas.size():
		var it2: Resource = todas[i]
		var lleva: bool = puestas.has(String(it2.resource_path))
		nombres.append("%s%s" % [it2.nombre, "  ·  la lleva puesta" if lleva else ""])
		iconos.append(MenuScaffold.icono_de_arma(it2))
		if lleva:
			marcadas.append(i)
	MenuScaffold.subpestanas(_barra_armas, nombres, iconos, _arma_idx, _pick_arma, marcadas)


# LAS TECNICAS del arma abierta, una por linea: el nombre a la izquierda y a la derecha lo que hace
# falta para tenerla. El color dice el estado de un vistazo (verde = ya es suya, gris = no le llega
# el dinero) y el orden es el de la plantilla, que es el orden en que estan pensadas.
# ============================================================
#  MEDITACION (el gacha)
#
#  Pagas y el azar decide: la magia se GANA, no se compra. Por eso los grimorios salieron de la
#  tienda -- poder comprar justo el hechizo que te falta vaciaba de sentido toda esta pantalla.
#
#  EL REPARTO DE LA PANTALLA. Aqui NO valen las dos columnas del esqueleto: esto es un CARTEL a
#  pantalla completa, con el molde del banner de ARMAS y no el de personaje. La diferencia importa y
#  fue la primera correccion que hubo que hacer: en el de personaje manda la ilustracion del muñeco,
#  y en el de armas manda EL OBJETO, que es lo que se viene a buscar.
#    - El CARTEL (ver gacha_banner.gd): el grimorio mas raro en grande a la derecha con su nombre y
#      sus estrellas, y un abanico de los de la banda del garantizado abajo a la izquierda.
#    - Los RETRATOS arriba: el sesgo del gacha va por personaje, asi que quien medita se elige aqui.
#    - Los dos botones de tirar ABAJO A LA DERECHA y "Ver detalles" ABAJO A LA IZQUIERDA, que es
#      donde estan en todos.
#    - TODO LO DEMAS -- probabilidades, lista de lo que puede caer, historial -- detras del boton de
#      detalles, en un modal de dos pestañas.
#
#  Y LA TABLA NO LLEVA NI UN NUMERO ESCRITO A MANO: sale de Game.probs_grimorio con el pool y el
#  personaje de verdad. Una pantalla de porcentajes copiada a mano es la que miente en cuanto
#  alguien toca un peso, y encima nadie se entera hasta que se juega.
# ============================================================

func _pintar_meditacion(pj: PersonajeData) -> void:
	# LAS DOS COLUMNAS DEL ESQUELETO, FUERA. El cartel ocupa la pantalla entera; con el split debajo
	# se veian los separadores y el hueco de la ficha por detras.
	if _split != null:
		_split.visible = false
	_montar_capa_med()
	_capa_med.visible = true
	_banner.refrescar(pj, _pool_grimorios())
	_refrescar_botones_med()

	# Si los detalles estan abiertos, se vuelven a montar: sus probabilidades son LAS DEL PERSONAJE
	# ELEGIDO, asi que cambiar de retrato con el modal delante tiene que cambiar la tabla. Sin esto
	# seguia enseñando las del anterior, que es la clase de mentira que nadie comprueba.
	if _modal_abierto():
		_montar_modal()


# LA CAPA DE LA MEDITACION, montada UNA VEZ. Lo que cambia en cada repintado son los textos de los
# botones y el cartel, no el andamio: remontarlo entero cortaria el revelado por la mitad.
func _montar_capa_med() -> void:
	if _capa_med != null and is_instance_valid(_capa_med):
		return
	_capa_med = Control.new()
	_capa_med.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_capa_med.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_capa_med)

	_banner = GachaBanner.new()
	_banner.montar(_capa_med)

	# LOS RETRATOS, arriba: quien medita. Se monta una fila PROPIA en vez de reaprovechar la del
	# esqueleto porque aquella vive dentro del split, que aqui va escondido.
	_fila_retratos_med = MenuScaffold.fila_retratos(_caja_arriba_med())

	# LA BOTONERA DE ABAJO. Los de tirar a la derecha y los detalles a la izquierda, anclados al
	# fondo de la pantalla: es el sitio del molde y ademas es donde llega el pulgar en movil.
	var pie := HBoxContainer.new()
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_left = 24
	pie.offset_right = -24
	pie.offset_top = -66
	pie.offset_bottom = -18
	pie.add_theme_constant_override("separation", 10)
	# POR ENCIMA DE LOS MUÑECOS de los retratos, igual que el cartel (ver gacha_banner.montar).
	pie.z_index = 2600
	_capa_med.add_child(pie)

	_bt_detalles = MenuScaffold.boton(pie, "Ver detalles", _abrir_detalles)
	_bt_detalles.custom_minimum_size = Vector2(180, 46)
	var empuja := Control.new()
	empuja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pie.add_child(empuja)
	# LA CUENTA DEL GARANTIZADO, pegada a los botones y alineada con ellos en vertical.
	_lbl_pity = Label.new()
	_lbl_pity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_pity.add_theme_font_size_override("font_size", 12)
	_lbl_pity.add_theme_color_override("font_color", GRIS)
	pie.add_child(_lbl_pity)
	_bt_x1 = MenuScaffold.boton(pie, "", _meditar_x1)
	_bt_x1.custom_minimum_size = Vector2(250, 46)
	_bt_x10 = MenuScaffold.boton(pie, "", _meditar_x10)
	_bt_x10.custom_minimum_size = Vector2(290, 46)


var _fila_retratos_med: HBoxContainer = null
var _bt_detalles: Button = null
var _bt_x1: Button = null
var _bt_x10: Button = null
var _lbl_pity: Label = null


# La franja de arriba donde van los retratos, por debajo de la barra de pestañas del esqueleto.
func _caja_arriba_med() -> VBoxContainer:
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_TOP_WIDE)
	caja.offset_left = 24
	caja.offset_right = -24
	# 104 y no 84: ahi arriba esta la linea de aviso del esqueleto ("Sedaki medita"), y con los
	# retratos a 84 el texto salia cortado por las cabezas.
	caja.offset_top = 104
	caja.offset_bottom = 198
	_capa_med.add_child(caja)
	return caja


# Lo que cambia en cada repintado: el precio, si llega el dinero, y a quien se le pinta el retrato
# marcado. El andamio de _montar_capa_med se queda quieto.
func _refrescar_botones_med() -> void:
	MenuScaffold.retratos(_fila_retratos_med, _gente(), _pj_sel, Game.party.size(), _pick_persona)
	_lbl_pity.text = _texto_pity(_pj())
	_bt_x1.text = "Meditar ×1      %s" % _con_puntos(Game.GACHA_PRECIO)
	_bt_x1.disabled = not Game.puede_pagar(Game.GACHA_PRECIO)
	_bt_x10.text = "Meditar ×10     %s  (pagas 9)" % _con_puntos(Game.GACHA_PRECIO_X10)
	_bt_x10.disabled = not Game.puede_pagar(Game.GACHA_PRECIO_X10)


# CUANTO FALTA PARA CADA GARANTIZADO, en UNA linea encima de los botones de tirar. Es la unica
# informacion que cambia lo que haces ahora mismo ("me quedan tres, tiro"), asi que va pegada al
# boton y no en el cartel: en el cartel esta la REGLA, que se lee una vez, y aqui la CUENTA, que se
# mira en cada tirada.
#
# LOS NUMEROS SALEN DE Game.gacha_pity_restante, NO de restar aqui: si esta pantalla hiciera su
# propia cuenta, el dia que el pity cambie de escalones diria una cosa y el sorteo haria otra, y el
# jugador se fiaria de la pantalla.
func _texto_pity(pj: PersonajeData) -> String:
	var falta: Dictionary = Game.gacha_pity_restante(pj)
	return "Garantizado:  épico %s   ·   legendario %s" % [
		_cuantas(int(falta["epico"])), _cuantas(int(falta["legendario"]))]


# El singular, a mano: "en 1 tiradas" canta, y esta linea se lee una vez por tirada.
func _cuantas(n: int) -> String:
	if n <= 0:
		return "¡la siguiente!"
	if n == 1:
		return "en 1 tirada"
	return "en %d tiradas" % n


# ------------------------------------------------------------
#  TIRAR
# ------------------------------------------------------------

# Lo que ha salido en la ULTIMA tirada, para pintarlo a la derecha. Es de la pantalla y no de la
# partida: al cerrar el menu se olvida (lo que perdura es el historial, que si se guarda).
var _revelado: Array = []

func _meditar_x1() -> void:
	_meditar(1, Game.GACHA_PRECIO)


func _meditar_x10() -> void:
	_meditar(10, Game.GACHA_PRECIO_X10)


# UNA TANDA DE TIRADAS. Cobra UNA VEZ por la tanda (por eso la x10 puede tener descuento) y despues
# tira: Game.tirar_meditacion no cobra ni entrega nada a proposito, para que se pueda tirar diez mil
# veces en el visor sin tocar la partida.
func _meditar(cuantas: int, precio: int) -> void:
	if not Game.gastar(precio):
		_aviso = "No te llega."
		_aviso_ok = false
		_rebuild()
		return
	var pj: PersonajeData = _pj()
	var pool: Array = _pool_grimorios()
	var tochos: Array = _pool_tochos()
	# UN RNG NUEVO POR TANDA, sin semilla fija: aqui se quiere azar de verdad. El parametro existe
	# para que el visor pueda repetir una racha y, el dia que esto vaya por red, para que las tire
	# el host con su semilla (ver Game.sortear_grimorio).
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_revelado.clear()
	for i in cuantas:
		var t: Dictionary = Game.tirar_meditacion(pj, rng, pool, tochos)
		var c: ConsumableData = t.get("item")
		if c == null:
			continue
		Game.add_consumable(c, 1)
		Game.gacha_apuntar(pj, c, int(t.get("pity", 0)))
		_revelado.append(t)
	_aviso = "%s medita." % pj.nombre
	_aviso_ok = true

	# SE GUARDA AQUI MISMO, ANTES DE ENSEÑAR NADA. Es la excepcion a la regla de la casa (ninguna
	# pantalla guarda al comprar, tampoco la tienda) y tiene un motivo que solo se da en el gacha:
	# el resultado es AZAR, asi que sin guardar bastaba con ver una tirada mala y cerrar por la ✕ o
	# con alt+F4 para que no hubiera pasado nada -- y volver a tirar hasta que saliera el mitico. Un
	# gacha en el que la tirada se puede deshacer no es un gacha.
	#
	# Va DESPUES del bucle y no dentro: una sola escritura por tanda, no diez en una x10. Y por
	# guardar_mi_partida, que es el punto unico (en un mundo compartido o de invitado, escribir la
	# partida entera en la ranura seria justo lo que ese metodo existe para evitar).
	Game.guardar_mi_partida()

	_rebuild()
	_mostrar_resultados()


# ------------------------------------------------------------
#  LO QUE HA SALIDO: la pantalla de resultados.
#
#  Va DELANTE de todo y a pantalla completa, como en cualquier gacha, y no en una columna al lado
#  del cartel: la tirada es el momento de la pantalla, y enseñarla en una lista lateral mientras el
#  cartel sigue mandando es justo lo que hacia que esto no pareciera un gacha.
#
#  Las diez cartas van en REJILLA de cinco por dos, con la misma carta que el cartel (el mismo
#  dibujo, en pequeño) para que se lean como el mismo objeto.
# ------------------------------------------------------------

var _resultados: Control = null

# Destruir y REPINTAR van separados a proposito: _rebuild tambien tiene que poder tirar los
# resultados (al cambiar de pestaña), y si tirarlos llamara a _rebuild seria una recursion. La
# guardia _reconstruyendo la cortaria, pero calladamente y dejando a medias el repintado de fuera.
func _tirar_resultados() -> void:
	# LOS TWEENS PRIMERO, siempre. Un tween sigue vivo aunque su nodo se libere, y al llegar a su
	# tween_property sobre un Control muerto revienta. Cerrar los resultados a media animacion (Esc,
	# o cambiar de pestaña) es justo el caso que lo provoca.
	for tw in _tweens_res:
		if tw != null and is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_tweens_res.clear()
	_carta_actual = null
	_zona_res = null
	_bt_continuar = null
	_res_idx = 0
	if _resultados == null:
		return
	# remove_child ADEMAS de queue_free: queue_free no saca del arbol hasta el final del frame, y
	# dos tandas seguidas se dibujaban superpuestas (la misma trampa que el modal de detalles).
	if _resultados.get_parent() != null:
		_resultados.get_parent().remove_child(_resultados)
	_resultados.queue_free()
	_resultados = null


func _cerrar_resultados() -> void:
	_tirar_resultados()
	_rebuild()


func _mostrar_resultados() -> void:
	# _tirar_resultados y NO _cerrar_resultados: cerrar repinta, y aqui venimos justo de un repintado.
	# Ademas hay que pasar por aqui SIEMPRE y no solo si quedaba una pantalla abierta, porque es lo
	# que vacia las cartas y los tweens de la tanda anterior.
	_tirar_resultados()
	if _revelado.is_empty():
		return
	_resultados = Control.new()
	_resultados.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Por encima de los muñecos de los retratos, igual que el cartel (ver gacha_banner.montar).
	_resultados.z_index = 3000
	_root.add_child(_resultados)

	# EL VELO se come los clics: sin el se podia pulsar "Meditar" a traves de los resultados, que es
	# gastarse otras 2.000 monedas sin haber visto lo que salio.
	var velo := ColorRect.new()
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# 0.94 y no 0.88: con 0.88 se colaba el naranja del cartel por detras de las cartas y competia
	# con ellas, que son lo unico que hay que mirar en este momento.
	velo.color = Color(0.02, 0.02, 0.04, 0.94)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_resultados.add_child(velo)

	# EL CLIC ES EL MANDO: cada toque pasa a la siguiente carta. En un gacha se le da a la pantalla,
	# no se busca un boton.
	velo.gui_input.connect(_velo_pulsado)

	# LA ZONA donde se pinta lo de cada momento (una carta, o el resumen del final). Se vacia y se
	# vuelve a llenar en cada paso; el velo y la capa se quedan.
	_zona_res = Control.new()
	_zona_res.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zona_res.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resultados.add_child(_zona_res)

	_res_idx = 0
	_pintar_paso_res()


# ------------------------------------------------------------
#  EL REVELADO, UNA CARTA POR CLIC
#
#  Asi lo pidio y asi es en el molde: NO una rejilla que se voltea sola. Sale una carta a pantalla
#  completa, con su nombre y sus estrellas AL LADO (la cinta del tipo encima, como en la referencia),
#  y cada toque pasa a la siguiente. Al acabar las diez se enseña el resumen de la tanda entera, que
#  es lo unico que se ve de un vistazo.
#
#  El VOLTEO de cada carta es un escalado en X: se cierra hasta quedar de canto, ahi se cambia el
#  dibujo, y se vuelve a abrir. Ni 3D ni shader, y se lee perfectamente como "se ha dado la vuelta".
# ------------------------------------------------------------

const CARTA_RES_ANCHO := 250.0
const CARTA_RES_ALTO := 340.0
const VOLTEO_MEDIO := 0.13       # lo que tarda en cerrarse (y otro tanto en abrirse)

var _zona_res: Control = null
var _res_idx: int = 0
var _carta_actual: Control = null      # el dibujo de la carta que se esta enseñando
var _caja_actual: Control = null       # su etiqueta (nombre y estrellas), oculta hasta el volteo
var _tweens_res: Array = []
var _bt_continuar: Button = null


# ¿La carta de ahora esta ya destapada? Es lo que decide si un clic la voltea o pasa a la siguiente.
func _carta_destapada() -> bool:
	return _carta_actual == null or not is_instance_valid(_carta_actual) \
		or bool(_carta_actual.get_meta("volteada", false))


func _velo_pulsado(e: InputEvent) -> void:
	# Solo el BOTON PULSADO, y no cualquier evento: un clic manda dos eventos (abajo y arriba) y sin
	# esto un solo toque se comeria DOS cartas.
	if not (e is InputEventMouseButton and (e as InputEventMouseButton).pressed):
		return
	get_viewport().set_input_as_handled()
	# Si la de ahora esta a medio voltear, el toque la termina en vez de saltarsela: si no, un
	# impaciente se salta justo la carta buena sin verla.
	if not _carta_destapada():
		_destapar_ya()
		return
	_res_idx += 1
	_pintar_paso_res()


func _pintar_paso_res() -> void:
	if _zona_res == null or not is_instance_valid(_zona_res):
		return
	_matar_tweens_res()
	for h in _zona_res.get_children():
		_zona_res.remove_child(h)
		h.queue_free()
	_carta_actual = null
	if _res_idx < _revelado.size():
		_pintar_carta_res(_revelado[_res_idx])
	else:
		_pintar_resumen_res()
# UNA CARTA, a pantalla completa. La carta al centro-derecha y su ETIQUETA a la izquierda: cinta con
# el tipo de libro, el nombre en grande y las estrellas debajo. Es el reparto de la referencia, y el
# motivo de que el nombre vaya al lado y no debajo es el mismo que en el cartel: debajo hay que
# estrechar la carta para que quepa, y la carta es lo que se ha venido a ver.
func _pintar_carta_res(t: Dictionary) -> void:
	var c: ConsumableData = t.get("item")
	if c == null:
		return
	var s: SpellData = t.get("spell")
	var r: int = int(s.rareza) if s != null else -1
	var seccion: String = c.seccion_biblioteca()
	var color: Color = _color_entrada(r, seccion)
	var familia: int = _familia_de(r, seccion)

	var dib := Control.new()
	dib.set_anchors_preset(Control.PRESET_CENTER)
	dib.custom_minimum_size = Vector2(CARTA_RES_ANCHO, CARTA_RES_ALTO)
	dib.size = Vector2(CARTA_RES_ANCHO, CARTA_RES_ALTO)
	dib.offset_left = -CARTA_RES_ANCHO * 0.5 + 150.0
	dib.offset_right = CARTA_RES_ANCHO * 0.5 + 150.0
	dib.offset_top = -CARTA_RES_ALTO * 0.5
	dib.offset_bottom = CARTA_RES_ALTO * 0.5
	dib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# EL PIVOTE EN EL CENTRO: el volteo encoge la carta en X hasta cero y la vuelve a abrir, y con el
	# pivote en la esquina (el de fabrica) la carta se iria hacia la izquierda en vez de girar sobre
	# si misma.
	dib.pivot_offset = Vector2(CARTA_RES_ANCHO, CARTA_RES_ALTO) * 0.5
	# EL ESTADO VIVE EN EL PROPIO NODO (set_meta) y no en una variable de fuera: el dibujo se dispara
	# cuando a Godot le apetece redibujar, y una variable de fuera es lo que se queda desfasado
	# cuando la carta se libera a media animacion.
	dib.set_meta("volteada", false)
	# La rareza y el color van tambien en el nodo: los necesita _destapar_ya, que entra por un clic y
	# no tiene de donde sacarlos.
	dib.set_meta("rareza", r)
	dib.set_meta("color", color)
	var gordo: bool = r >= Upgrades.Rareza.EPICO
	dib.draw.connect(_dibujar_carta_res.bind(dib, color, gordo, familia))
	_zona_res.add_child(dib)
	_carta_actual = dib

	# LA ETIQUETA, oculta hasta que la carta se da la vuelta: enseñar el nombre antes de voltear seria
	# contar el final.
	var caja := VBoxContainer.new()
	caja.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	caja.offset_left = 150.0
	caja.offset_right = 560.0
	caja.offset_top = -50.0
	caja.offset_bottom = 50.0
	caja.alignment = BoxContainer.ALIGNMENT_CENTER
	caja.add_theme_constant_override("separation", 4)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.visible = false
	_zona_res.add_child(caja)
	_caja_actual = caja

	var cinta := Label.new()
	cinta.text = "  %s  " % seccion
	cinta.add_theme_font_size_override("font_size", 11)
	cinta.add_theme_color_override("font_color", Color(0.06, 0.07, 0.10))
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(3)
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	cinta.add_theme_stylebox_override("normal", sb)
	cinta.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	caja.add_child(cinta)

	var nom := Label.new()
	nom.text = c.nombre
	nom.add_theme_font_size_override("font_size", 26)
	nom.add_theme_color_override("font_color", Color(0.95, 0.96, 0.99))
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caja.add_child(nom)

	var est := Label.new()
	est.text = _estrellas(r)
	est.add_theme_font_size_override("font_size", 15)
	est.add_theme_color_override("font_color", color)
	est.visible = est.text != ""
	caja.add_child(est)

	if int(t.get("pity", 0)) > 0:
		var g := Label.new()
		g.text = "★ garantizado"
		g.add_theme_font_size_override("font_size", 11)
		g.add_theme_color_override("font_color", AMBAR)
		caja.add_child(g)

	# EL CONTADOR y la pista del gesto, abajo del todo.
	var pie := Label.new()
	pie.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pie.offset_top = -70.0
	pie.offset_bottom = -40.0
	pie.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pie.text = "%d de %d      ·      toca para seguir" % [_res_idx + 1, _revelado.size()]
	pie.add_theme_font_size_override("font_size", 12)
	pie.add_theme_color_override("font_color", GRIS)
	_zona_res.add_child(pie)

	_voltear_carta(dib, caja, r, color)


func _dibujar_carta_res(c: Control, col: Color, gordo: bool, familia: int) -> void:
	if bool(c.get_meta("volteada", false)):
		_banner.dibujar_tomo(c, col, gordo, familia)
	else:
		_banner.dibujar_dorso(c)


# EL GIRO de la carta que acaba de salir. El tween lo crea ESTE nodo, que va con
# PROCESS_MODE_ALWAYS: el menu para el arbol entero al abrirse (Game.abrir_menu), y un tween de un
# nodo pausado no avanza -- la carta se quedaria boca abajo para siempre.
func _voltear_carta(dib: Control, caja: Control, r: int, color: Color) -> void:
	var tw: Tween = create_tween()
	_tweens_res.append(tw)
	tw.tween_property(dib, "scale:x", 0.0, VOLTEO_MEDIO)
	tw.tween_callback(_destapar.bind(dib, caja, r, color))
	tw.tween_property(dib, "scale:x", 1.0, VOLTEO_MEDIO)


# El momento del cambio, con la carta de canto: se cambia el dibujo y sale la etiqueta.
func _destapar(dib: Control, caja: Control, r: int, color: Color) -> void:
	if not is_instance_valid(dib):
		return
	dib.set_meta("volteada", true)
	dib.queue_redraw()
	if is_instance_valid(caja):
		caja.visible = true
	# EL DESTELLO, solo en las buenas. Si centellea todo no centellea nada: es la misma idea que el
	# brillo relativo del equipo.
	if r >= Upgrades.Rareza.EPICO:
		var p: CPUParticles2D = Particulas.destellos(dib, color,
			Vector2(CARTA_RES_ANCHO, CARTA_RES_ALTO), 1.0)
		# PROCESS_MODE_ALWAYS obligatorio, por lo mismo que el tween: con el arbol parado las
		# particulas no emiten ni una.
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		p.position = Vector2(CARTA_RES_ANCHO, CARTA_RES_ALTO) * 0.5


# Termina el giro de golpe (un toque impaciente a media vuelta). Mata el tween ANTES: si se deja
# correr, sigue escalando y deja la carta a media anchura para siempre.
func _destapar_ya() -> void:
	_matar_tweens_res()
	if _carta_actual == null or not is_instance_valid(_carta_actual):
		return
	_carta_actual.scale.x = 1.0
	_destapar(_carta_actual, _caja_actual,
		int(_carta_actual.get_meta("rareza", -1)),
		_carta_actual.get_meta("color", Color.WHITE))


# EL RESUMEN de la tanda, al final: las diez juntas, que es lo unico que se ve de un vistazo. Aqui ya
# no hay misterio, asi que van todas destapadas y pequeñas.
func _pintar_resumen_res() -> void:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 40
	col.offset_bottom = -24
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 14)
	_zona_res.add_child(col)

	var tit := Label.new()
	tit.text = "TE HA SALIDO"
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tit.add_theme_font_size_override("font_size", 20)
	tit.add_theme_color_override("font_color", AMBAR)
	col.add_child(tit)

	# CINCO POR FILA: con diez en una sola fila las cartas salen a 110 px y el nombre no cabe debajo.
	var centro := CenterContainer.new()
	col.add_child(centro)
	var rejilla := GridContainer.new()
	rejilla.columns = 5
	rejilla.add_theme_constant_override("h_separation", 14)
	rejilla.add_theme_constant_override("v_separation", 12)
	centro.add_child(rejilla)
	for t in _revelado:
		_mini_resumen(rejilla, t)

	var nota := Label.new()
	nota.text = "Los libros van a la bolsa: se leen desde el inventario."
	nota.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nota.add_theme_font_size_override("font_size", 11)
	nota.add_theme_color_override("font_color", GRIS)
	col.add_child(nota)

	var pie := CenterContainer.new()
	col.add_child(pie)
	_bt_continuar = MenuScaffold.boton(pie, "Continuar", _cerrar_resultados)
	_bt_continuar.custom_minimum_size = Vector2(240, 46)


const MINI_RES_ANCHO := 150.0
const MINI_RES_ALTO := 200.0

func _mini_resumen(rejilla: GridContainer, t: Dictionary) -> void:
	var c: ConsumableData = t.get("item")
	if c == null:
		return
	var s: SpellData = t.get("spell")
	var r: int = int(s.rareza) if s != null else -1
	var seccion: String = c.seccion_biblioteca()
	var color: Color = _color_entrada(r, seccion)
	var familia: int = _familia_de(r, seccion)

	var caja := VBoxContainer.new()
	caja.custom_minimum_size = Vector2(MINI_RES_ANCHO, 0)
	caja.add_theme_constant_override("separation", 2)
	rejilla.add_child(caja)

	var dib := Control.new()
	dib.custom_minimum_size = Vector2(MINI_RES_ANCHO, MINI_RES_ALTO)
	dib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caja.add_child(dib)
	var gordo: bool = r >= Upgrades.Rareza.EPICO
	dib.draw.connect(_banner.dibujar_tomo.bind(dib, color, gordo, familia))

	# LAS ESTRELLAS TAMBIEN AQUI. Sin ellas, un GRIMORIO comun se veia igual que una curiosidad
	# -- mismo dibujo, y el gris del comun y el de los menus son casi el mismo color -- asi que un
	# premio pasaba por un libro cualquiera. Las estrellas son lo que dice "esto va en la escala".
	var est := Label.new()
	est.text = _estrellas(r)
	est.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	est.add_theme_font_size_override("font_size", 12)
	est.add_theme_color_override("font_color", color)
	est.visible = est.text != ""
	caja.add_child(est)

	var nom := Label.new()
	nom.text = c.nombre
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom.add_theme_font_size_override("font_size", 12)
	nom.add_theme_color_override("font_color", color)
	caja.add_child(nom)

	if int(t.get("pity", 0)) > 0:
		var g := Label.new()
		g.text = "★ garantizado"
		g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		g.add_theme_font_size_override("font_size", 10)
		g.add_theme_color_override("font_color", AMBAR)
		caja.add_child(g)


func _matar_tweens_res() -> void:
	for tw in _tweens_res:
		if tw != null and is_instance_valid(tw) and tw.is_valid():
			tw.kill()
	_tweens_res.clear()


# Los tochos que pueden caer. Del manifiesto y no de escanear la carpeta, por lo mismo que los
# grimorios: en el .exe un escaneo de res:// no es de fiar (ver Libros).
func _pool_tochos() -> Array:
	var out: Array = []
	for ruta in Libros.TOCHOS:
		var c: ConsumableData = load(ruta) as ConsumableData
		if c != null:
			out.append(c)
	return out


# 20000 -> "20.000". El punto de los miles, que es como se escriben aqui los precios.
func _con_puntos(n: int) -> String:
	var s: String = str(n)
	var out: String = ""
	var c: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "." + out
	return out


# LA TABLA. No lleva ni un numero escrito a mano: sale de Game.probs_grimorio con el pool y el
# personaje de verdad. Una pantalla de porcentajes copiada a mano es la que miente en cuanto alguien
# toca un peso, y encima nadie se entera hasta que se juega.
#
# Recibe el VBox DONDE pintar en vez de escribir en _lista: la misma tabla se enseña ahora dentro
# del modal de detalles, y duplicarla para cambiarle el destino era garantizar que una de las dos
# se quedase atras.
func _tabla_probs(pj: PersonajeData, vb: VBoxContainer) -> void:
	var pool: Array = _pool_grimorios()
	if pool.is_empty():
		MenuScaffold.nota(vb, "(no hay ningún grimorio en el repertorio)")
		return
	var probs: Dictionary = Game.probs_grimorio(pool, pj)

	# POR BANDA, no hechizo a hechizo: dieciseis lineas de porcentaje no se leen. Lo que se viene a
	# saber aqui es "cuanto cuesta un legendario", y eso es una fila por rareza.
	var por_banda := {}
	for s in probs:
		var r: int = int(s.rareza)
		var d: Dictionary = por_banda.get(r, {"total": 0.0, "cuantos": 0, "sabidos": 0})
		d["total"] = float(d["total"]) + float(probs[s])
		d["cuantos"] = int(d["cuantos"]) + 1
		if Game.hechizos_sabidos(pj).has(s):
			d["sabidos"] = int(d["sabidos"]) + 1
		por_banda[r] = d

	var bandas: Array = por_banda.keys()
	bandas.sort()
	for r in bandas:
		var d2: Dictionary = por_banda[r]
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 10)
		vb.add_child(fila)
		var nom := Label.new()
		nom.text = _nombre_rareza(int(r))
		nom.add_theme_color_override("font_color", Upgrades.rareza_color(int(r)))
		nom.custom_minimum_size.x = 130
		fila.add_child(nom)
		var pct := Label.new()
		# El total de la BANDA y, entre parentesis, lo que sale CADA UNO: es la cuenta que hay que
		# ver junta, porque una banda gorda repartida entre muchos da hechizos individuales raros.
		pct.text = "%.1f%%   (cada uno %.2f%%)" % [
			float(d2["total"]) * 100.0, float(d2["total"]) / float(d2["cuantos"]) * 100.0]
		fila.add_child(pct)
		var cuantos := Label.new()
		var n: int = int(d2["cuantos"])
		cuantos.text = "  ·  %d %s" % [n, "hechizo" if n == 1 else "hechizos"] + (
			"  ·  %d ya sabidos" % int(d2["sabidos"]) if int(d2["sabidos"]) > 0 else "")
		cuantos.add_theme_color_override("font_color", MenuScaffold.GRIS)
		fila.add_child(cuantos)

	vb.add_child(HSeparator.new())
	MenuScaffold.nota(vb, "Estas cuentas salen del reparto de verdad, no están escritas aquí: "
		+ "si cambia el reparto, cambia esta tabla.")


# ------------------------------------------------------------
#  EL MODAL DE DETALLES: dos pestañas, "Probabilidades" e "Historial".
#
#  Va SUPERPUESTO sobre la pantalla del maestro (hijo de _root, que es el Control de pantalla
#  completa del scaffold) y no como una seccion mas de la columna: lo que se consulta de vez en
#  cuando no puede quedarse ocupando el sitio de lo que se usa siempre.
#
#  Se monta y se destruye entero en cada apertura. Es una pantalla de consultar, sin estado que
#  conservar, y un panel que se esconde en vez de morir es un panel que se queda con datos viejos
#  el dia que alguien cambie de personaje con el abierto.
# ------------------------------------------------------------

const MODAL_TABS := ["Probabilidades", "Historial"]

var _modal: Control = null
var _modal_tab: int = 0

func _abrir_detalles() -> void:
	_modal_tab = 0
	_hist_pagina = 0
	_montar_modal()


func _cerrar_detalles() -> void:
	if _modal != null:
		# SE SACA DEL ARBOL EN EL ACTO, y ademas se libera. queue_free() no borra hasta el final del
		# frame, asi que al cambiar de pestaña el modal viejo seguia dibujandose DEBAJO del nuevo: se
		# veian los dos superpuestos y medio pisados, con el titulo de uno asomando por detras del
		# otro. Con remove_child el sitio queda libre ya, y el queue_free solo se ocupa de la memoria.
		if _modal.get_parent() != null:
			_modal.get_parent().remove_child(_modal)
		_modal.queue_free()
		_modal = null


func _modal_abierto() -> bool:
	return _modal != null and is_instance_valid(_modal)


func _on_modal_tab(i: int) -> void:
	_modal_tab = i
	_montar_modal()


func _montar_modal() -> void:
	_cerrar_detalles()
	var pj: PersonajeData = _pj()

	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# EL Z A TOPE, y no basta con ser el ultimo hijo. Los RETRATOS llevan dentro un MunecoJugador,
	# que va con z_as_relative = false y se reparte z_index de hasta 2048 para ordenar sus propias
	# capas (ver muneco_jugador.gd): con z absoluto, esas caras se dibujan por encima de CUALQUIER
	# Control de z 0 aunque este detras en el arbol. Sin esto, las cuatro cabezas salian flotando
	# sobre el panel y tapaban el titulo del modal.
	# 4096 es el tope que acepta Godot; pasarse no lo recorta, lo rechaza y deja el valor anterior.
	_modal.z_index = 4096
	_root.add_child(_modal)

	# EL VELO. Ademas de oscurecer, COME LOS CLICS (MOUSE_FILTER_STOP): sin el se podia pulsar
	# "Meditar" a traves del modal, que es gastarse 2.000 monedas sin ver lo que sale.
	var velo := ColorRect.new()
	velo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	velo.color = Color(0, 0, 0, 0.6)
	velo.mouse_filter = Control.MOUSE_FILTER_STOP
	_modal.add_child(velo)

	var panel := PanelContainer.new()
	panel.theme = MenuScaffold.tema()
	# POR MARGENES Y NO POR TAMAÑO FIJO. Con PRESET_CENTER y un custom_minimum_size, el panel se
	# queda anclado a su centro pero el CONTENIDO lo estira: la primera version tenia la pestaña
	# "Probabilidades" saliendose por el borde izquierdo y cortada a la mitad. Atado a los cuatro
	# lados, el que se tiene que apañar con el hueco es el contenido, que para eso lleva scroll.
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = MODAL_MARGEN_X
	panel.offset_right = -MODAL_MARGEN_X
	panel.offset_top = MODAL_MARGEN_Y
	panel.offset_bottom = -MODAL_MARGEN_Y
	_modal.add_child(panel)

	var margen := MarginContainer.new()
	for lado in ["left", "right", "top", "bottom"]:
		margen.add_theme_constant_override("margin_" + lado, 16)
	panel.add_child(margen)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margen.add_child(col)

	var cabecera := HBoxContainer.new()
	cabecera.add_theme_constant_override("separation", 8)
	col.add_child(cabecera)
	MenuScaffold.pestanas(cabecera, MODAL_TABS, _modal_tab, _on_modal_tab, MODAL_TAB_ANCHO)
	var empuja := Control.new()
	empuja.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cabecera.add_child(empuja)
	MenuScaffold.boton(cabecera, "✕", _cerrar_detalles)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	scroll.add_child(vb)

	if _modal_tab == 0:
		_pintar_detalles_probs(pj, vb)
	else:
		_pintar_detalles_historial(vb)


# Lo que el modal deja ver de la pantalla de debajo, por lado. Sobre las unidades logicas de
# 1280x720 (ver project.godot) esto es un panel de 1040x580: casi toda la pantalla, como en el
# molde del que se copia. Deja el marco justo para que se siga entendiendo que hay algo detras.
const MODAL_MARGEN_X := 120.0
const MODAL_MARGEN_Y := 70.0
# Las pestañas del modal son mas anchas que las de 120 por defecto: "Probabilidades" no cabe.
const MODAL_TAB_ANCHO := 180


# PESTAÑA 1: que puede caer y con que probabilidad. Dos tablas, y en este orden a proposito:
# primero QUE CLASE de libro (que es el reparto que mas manda y el que nadie se espera: nueve de
# cada diez tiradas NO son un grimorio) y despues, dentro del grimorio, que rareza.
func _pintar_detalles_probs(pj: PersonajeData, vb: VBoxContainer) -> void:
	MenuScaffold.titulo(vb, "QUÉ PUEDE CAER", 14)
	MenuScaffold.nota(vb, "Cada tirada saca un libro. Primero se decide de qué clase es:")
	_fila_reparto(vb, "Grimorio", Game.GACHA_P_GRIMORIO, "enseña un hechizo", AMBAR)
	_fila_reparto(vb, "Tomo de sabiduría", Game.GACHA_P_TOMO_SABIO, "da excelia mágica al leerlo",
		VERDE)
	_fila_reparto(vb, "Curiosidad", 1.0 - Game.GACHA_P_GRIMORIO - Game.GACHA_P_TOMO_SABIO,
		"para la biblioteca", GRIS)
	MenuScaffold.nota(vb, "Las curiosidades que ya te has leído no vuelven a salir.")

	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "Y SI SALE GRIMORIO, DE QUÉ RAREZA", 14)
	MenuScaffold.nota(vb, "Para %s. A cada uno le sale menos lo que ya se sabe." % pj.nombre)
	_tabla_probs(pj, vb)

	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "GARANTIZADOS", 14)
	# El texto del pity, DERIVADO de las constantes: escribir "50" y "200" a mano aqui es la forma
	# clasica de que la pantalla siga prometiendo lo de antes cuando se muevan los escalones.
	MenuScaffold.nota(vb, "Cada %d tiradas, un grimorio épico o mejor."
		% Game.GACHA_PITY_EPICO)
	MenuScaffold.nota(vb, "Cada %d tiradas, un grimorio legendario o mejor."
		% Game.GACHA_PITY_LEGENDARIO)
	MenuScaffold.nota(vb, "Se cuentan TIRADAS, no la racha: que te salga uno bueno por suerte no "
		+ "retrasa el garantizado. Los dos van por personaje.")


func _fila_reparto(vb: VBoxContainer, que: String, p: float, para_que: String, color: Color) -> void:
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 10)
	vb.add_child(fila)
	var nom := Label.new()
	nom.text = que
	nom.add_theme_color_override("font_color", color)
	nom.custom_minimum_size.x = 180
	fila.add_child(nom)
	var pct := Label.new()
	pct.text = "%.0f%%" % (p * 100.0)
	pct.custom_minimum_size.x = 70
	fila.add_child(pct)
	var q := Label.new()
	q.text = "·  " + para_que
	q.add_theme_color_override("font_color", GRIS)
	fila.add_child(q)


# PESTAÑA 2: EL HISTORIAL. Una fila por tirada, lo mas nuevo arriba, con el nombre del color de su
# rareza -- que es lo que hace que se pueda barrer con la vista buscando los buenos.
# 16 y no 10: con diez filas el modal se quedaba medio vacio -- media pantalla de nada debajo de la
# tabla. El modal mide 580 de alto y una fila ronda los 24, asi que dieciseis lo llenan sin apretar.
const HIST_POR_PAGINA := 16

# La pagina que se esta mirando. Se pone a cero al abrir el modal y al cambiar de personaje: si no,
# abrir el historial de alguien con tres tiradas te dejaba en la pagina 4, o sea en blanco.
var _hist_pagina: int = 0

func _pintar_detalles_historial(vb: VBoxContainer) -> void:
	var pj: PersonajeData = _pj()
	# SOLO LAS DE QUIEN ESTA ELEGIDO ARRIBA. El pity ya va por personaje, asi que el historial de
	# todos mezclado no respondia a la pregunta que se viene a hacer aqui ("¿cómo le está yendo a
	# ESTE?"). Y filtrando sobra la columna "Quién", que era la misma palabra repetida diez veces.
	#
	# Se compara por NOMBRE porque es lo que guarda gacha_apuntar. Dos compañeros con el mismo nombre
	# compartirian historial; es un mal menor frente a guardar una referencia al Resource, que no
	# sobrevive a guardar y cargar.
	var mias: Array = []
	for e in Game.gacha_historial:
		if String(e.get("quien", "")) == pj.nombre:
			mias.append(e)

	MenuScaffold.titulo(vb, "LO QUE LE HA IDO SALIENDO A %s" % pj.nombre.to_upper(), 14)
	if mias.is_empty():
		MenuScaffold.nota(vb, "%s todavía no ha meditado." % pj.nombre)
		return

	var paginas: int = int(ceil(float(mias.size()) / float(HIST_POR_PAGINA)))
	_hist_pagina = clampi(_hist_pagina, 0, paginas - 1)
	MenuScaffold.nota(vb, "%d tiradas, la más reciente arriba." % mias.size())
	vb.add_child(HSeparator.new())

	# EN REJILLA Y NO EN FILAS DE HBox. Con HBox las columnas se corrian: un ancho minimo solo es un
	# MINIMO, asi que un nombre largo ("Reconocimiento de la piedra por el tacto") empujaba su fila y
	# la de al lado quedaba desalineada. Un GridContainer reparte por COLUMNA, que es lo que hace que
	# una tabla se pueda barrer con la vista.
	var tabla := GridContainer.new()
	tabla.columns = 4
	tabla.add_theme_constant_override("h_separation", 18)
	tabla.add_theme_constant_override("v_separation", 4)
	tabla.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(tabla)

	for cab in ["Qué", "", "De qué", "Cuándo"]:
		var h := Label.new()
		h.text = cab
		h.add_theme_color_override("font_color", AMBAR)
		tabla.add_child(h)

	var desde: int = _hist_pagina * HIST_POR_PAGINA
	var hasta: int = mini(desde + HIST_POR_PAGINA, mias.size())
	for i in range(desde, hasta):
		var e: Dictionary = mias[i]
		var nom := Label.new()
		var r: int = int(e.get("rareza", -1))
		# El "★" delante marca el garantizado. Va PEGADO al nombre y no en una columna aparte porque
		# lo que se busca al abrir esto es "¿qué me salió?", y una columna casi siempre vacia solo
		# roba ancho a la que se lee.
		var seccion: String = String(e.get("seccion", ""))
		nom.text = ("★ " if int(e.get("pity", 0)) > 0 else "") + String(e.get("nombre", ""))
		# El color ES la informacion de esta tabla: es lo que deja encontrar los buenos sin leer.
		nom.add_theme_color_override("font_color", _color_entrada(r, seccion))
		# ANCHO MINIMO, NO EXPAND_FILL: expandiendo, la columna del nombre se comia todo el ancho del
		# modal y las otras tres se iban al borde derecho, con medio palmo de vacio en medio. Con un
		# minimo, la tabla queda junta y las columnas siguen alineadas.
		nom.custom_minimum_size.x = 330
		tabla.add_child(nom)

		# LAS ESTRELLAS, en columna propia: es lo que distingue un GRIMORIO (aunque sea comun) de un
		# tocho de un vistazo, sin tener que leer la seccion.
		var est := Label.new()
		est.text = _estrellas(r)
		est.add_theme_color_override("font_color", _color_entrada(r, seccion))
		tabla.add_child(est)

		var sec := Label.new()
		sec.text = seccion
		sec.add_theme_color_override("font_color", GRIS)
		tabla.add_child(sec)

		var cuando := Label.new()
		cuando.text = _fecha_corta(int(e.get("cuando", 0)))
		cuando.add_theme_color_override("font_color", GRIS)
		tabla.add_child(cuando)

	if paginas > 1:
		_pintar_paginador(vb, paginas)


# LAS FLECHAS DE PAGINA, centradas debajo de la tabla. Se apagan solas en los extremos en vez de dar
# la vuelta: en una lista ordenada por fecha, saltar de la primera pagina a la ultima desorienta.
func _pintar_paginador(vb: VBoxContainer, paginas: int) -> void:
	var centro := CenterContainer.new()
	vb.add_child(centro)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 14)
	centro.add_child(fila)

	var izq: Button = MenuScaffold.boton(fila, "◀", _hist_anterior, _hist_pagina > 0)
	izq.custom_minimum_size = Vector2(52, 34)
	var n := Label.new()
	n.text = "%d / %d" % [_hist_pagina + 1, paginas]
	n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(70, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila.add_child(n)
	var der: Button = MenuScaffold.boton(fila, "▶", _hist_siguiente, _hist_pagina < paginas - 1)
	der.custom_minimum_size = Vector2(52, 34)


func _hist_anterior() -> void:
	_hist_pagina -= 1
	_montar_modal()


func _hist_siguiente() -> void:
	_hist_pagina += 1
	_montar_modal()


# EL GRIS DE LOS TOCHOS, y por que no vale el GRIS de la casa: el comun de la escala de rareza es
# Color(0.70,0.72,0.76) y el GRIS de los menus es (0.6,0.63,0.7) -- practicamente el mismo color. Con
# eso, un GRIMORIO COMUN (que es un premio, aunque flojo) se veia exactamente igual que una
# curiosidad de relleno, y encima sin estrellas: parecia un libro normal. Este gris esta bastante mas
# apagado para que la diferencia se vea de un vistazo.
const TOCHO_GRIS := Color(0.44, 0.46, 0.53)

# Y EL DE LOS TOMOS DE SABIDURIA, que tampoco pueden ir del mismo gris que las curiosidades: los dos
# son tochos y se veian identicos, pero uno te sube la magia al leerlo y el otro solo tiene texto.
#
# TEAL y no un dorado: el dorado se confunde con el amarillo del legendario y el verde con el del
# poco comun. Este frio no lo usa ninguna banda de rareza, asi que no puede leerse como "una rareza
# mas" -- que es justo lo que no es.
#
# Y VA APAGADO A PROPOSITO. La primera version era (0.35, 0.72, 0.74), un teal vivo, y el resultado
# fue que un tomo de sabiduria LLAMABA MAS que un grimorio comun (que va en el gris palido de su
# banda) -- o sea, el premio peor parecia el mejor. Cualquier grimorio vale mas que un tocho, asi
# que ningun tocho puede brillar por encima del comun.
const SABIO_TEAL := Color(0.30, 0.50, 0.53)

# La seccion que devuelve ConsumableData.seccion_biblioteca para los tomos de sabiduria. Se compara
# por ese texto porque es lo unico que guarda el historial de cada tirada.
const SEC_SABIDURIA := "Sabiduría"


# El color de una entrada del gacha. Las TRES familias tienen que distinguirse de un vistazo:
#   grimorio   -> el color de su rareza (y lleva estrellas)
#   sabiduria  -> teal (sin estrellas: no esta en la escala)
#   curiosidad -> gris apagado
func _color_entrada(r: int, seccion: String = "") -> Color:
	if r >= 0:
		return Upgrades.rareza_color(r)
	return SABIO_TEAL if seccion == SEC_SABIDURIA else TOCHO_GRIS


# La familia para el dibujo (ver GachaBanner.FAM_*). Sale de la rareza y la seccion, que es lo unico
# que guarda el historial: un grimorio siempre tiene rareza, y los dos tochos se separan por seccion.
func _familia_de(r: int, seccion: String) -> int:
	if r >= 0:
		return GachaBanner.FAM_GRIMORIO
	return GachaBanner.FAM_SABIDURIA if seccion == SEC_SABIDURIA else GachaBanner.FAM_CURIOSIDAD


# Las estrellas de una rareza: cuentan desde 1, asi que el comun saca UNA y el mitico seis. Un tocho
# (r < 0) se queda sin ninguna, que es la verdad: no esta en la escala.
func _estrellas(r: int) -> String:
	return "★".repeat(r + 1) if r >= 0 else ""


# El sello de una tirada, en corto: "07-09 09:45". Sin año ni segundos -- esto se mira para situar
# una tirada dentro de la sesion ("esto fue antes o despues de comer"), no para fecharla.
func _fecha_corta(unix: int) -> String:
	if unix <= 0:
		return ""
	# EN HORA LOCAL. get_datetime_dict_from_unix_time devuelve UTC, asi que hay que sumarle el huso
	# a mano: sin esto, en España las tiradas salian fechadas una o dos horas antes de haberlas
	# hecho, que es de las cosas que se miran una vez y se dan por buenas.
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var t: Dictionary = Time.get_datetime_dict_from_unix_time(unix + bias * 60)
	return "%02d-%02d %02d:%02d" % [int(t["day"]), int(t["month"]), int(t["hour"]), int(t["minute"])]


# Los hechizos que pueden salir: los que tienen grimorio. Sale del manifiesto y no de escanear la
# carpeta porque en el .exe un escaneo de res:// no es de fiar (ver Libros).
func _pool_grimorios() -> Array:
	var out: Array = []
	for ruta in Libros.GRIMORIOS:
		var c: ConsumableData = load(ruta) as ConsumableData
		if c != null and c.spell != null:
			out.append(c.spell)
	return out


func _nombre_rareza(r: int) -> String:
	var n := ["Común", "Poco común", "Raro", "Épico", "Legendario", "Mítico", "Obra maestra",
		"Prístino"]
	return n[r] if r >= 0 and r < n.size() else "?"


# ============================================================
#  BIBLIOTECA
#
#  Molde del libro del Pescador: una entrada por libro, y lo que aun no has leido en gris y sin
#  texto. El libro es tambien la lista de lo que te falta.
# ============================================================

func _pintar_biblioteca(_pj: PersonajeData) -> void:
	var todos: Array = Libros.todos()
	var leidos: int = 0
	# Por SECCION, que es como se pidio: Grimorios / Sabiduria / Curiosidades. La seccion la DERIVA
	# el propio libro (ConsumableData.seccion_biblioteca), no una lista de aqui.
	var secciones := {}
	for ruta in todos:
		var c: ConsumableData = load(ruta) as ConsumableData
		if c == null or not c.en_biblioteca():
			continue
		var s: String = c.seccion_biblioteca()
		if not secciones.has(s):
			secciones[s] = []
		(secciones[s] as Array).append(c)
		if Game.tomo_leido(c.tomo_id):
			leidos += 1

	MenuScaffold.titulo(_lista, "BIBLIOTECA", 14)
	MenuScaffold.nota(_lista, "Llevas %d de %d. Lo que leas se queda aquí aunque gastes el libro."
		% [leidos, todos.size()])

	# Orden fijo y no el del diccionario: un menu que reordena sus secciones entre pasadas marea.
	for nombre in ["Grimorios", "Sabiduría", "Curiosidades"]:
		if not secciones.has(nombre):
			continue
		var libros: Array = secciones[nombre]
		var n_leidos: int = 0
		for c in libros:
			if Game.tomo_leido(c.tomo_id):
				n_leidos += 1
		_lista.add_child(HSeparator.new())
		MenuScaffold.titulo(_lista, "%s   %d / %d" % [nombre.to_upper(), n_leidos, libros.size()], 13)
		var grid := GridContainer.new()
		grid.columns = _columnas()
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 4)
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_lista.add_child(grid)
		for c in libros:
			_celda_libro(grid, c)

	# LA FICHA DE LA DERECHA: el texto del libro que hayas abierto. Es el sitio donde se LEE, que es
	# para lo que existe la biblioteca — el libro se gasta, el texto no.
	if _libro_abierto == null or not Game.tomo_leido(_libro_abierto.tomo_id):
		MenuScaffold.nota(_content, "Elige un libro de la lista para releerlo.")
		return
	var c2: ConsumableData = _libro_abierto
	MenuScaffold.titulo_item(_content, c2.nombre,
		Upgrades.rareza_color(int(c2.spell.rareza)) if c2.es_grimorio() else MenuScaffold.AMBAR,
		Upgrades.rareza_intensidad(int(c2.spell.rareza)) if c2.es_grimorio() else 0.0)
	var sub := Label.new()
	sub.text = c2.seccion_biblioteca()
	sub.add_theme_color_override("font_color", MenuScaffold.GRIS)
	sub.add_theme_font_size_override("font_size", 11)
	_content.add_child(sub)
	_content.add_child(HSeparator.new())
	var txt := Label.new()
	txt.text = c2.descripcion
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(txt)


# Una entrada de la biblioteca. Sin leer sale en gris y SIN TITULO: enseñar el titulo de lo que no
# has leido es medio spoiler del chiste, y ademas quita las ganas de buscarlo.
func _celda_libro(grid: GridContainer, c: ConsumableData) -> void:
	var leido: bool = Game.tomo_leido(c.tomo_id)
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 34)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.text = "  " + (c.nombre if leido else "— — —")
	b.disabled = not leido
	if leido:
		b.add_theme_color_override("font_color", MenuScaffold.AMBAR
			if c.es_grimorio() else Color(0.86, 0.89, 0.94))
		b.pressed.connect(_ver_libro.bind(c))
	grid.add_child(b)


func _ver_libro(c: ConsumableData) -> void:
	_libro_abierto = c
	_rebuild()


var _libro_abierto: ConsumableData = null


func _pintar_tecnicas(pj: PersonajeData, arma: Resource) -> void:
	var lleva: bool = _la_lleva(pj, arma)
	# Solo "TÉCNICAS": el nombre del arma ya esta arriba, en grande, y repetirlo en la misma pantalla
	# gasta una linea para no decir nada nuevo.
	MenuScaffold.titulo(_lista, "TÉCNICAS", 14)
	MenuScaffold.nota(_lista, ("%s lleva esta arma: lo que aprenda aquí lo usa ya." % pj.nombre)
		if lleva else ("No hace falta llevar el arma puesta para aprender sus técnicas, "
		+ "pero sí para usarlas."))
	var tecnicas: Array = _tecnicas()
	if tecnicas.is_empty():
		MenuScaffold.nota(_lista, "Esta arma no tiene técnicas propias.")
		return
	_sel = clampi(_sel, 0, tecnicas.size() - 1)
	# EN DOS COLUMNAS. Cada arma trae hoy cinco o seis tecnicas y en una sola columna ya llegaban
	# abajo del todo; segun se vayan añadiendo, la lista empezaria con scroll -- y una lista de la
	# que solo se ve media no deja comparar, que es justo lo que uno viene a hacer aqui.
	#
	# Una sola columna cuando no hay ancho (movil en vertical): a menos de ANCHO_DOS px, dos celdas
	# dejan el nombre y el estado pisandose.
	var grid := GridContainer.new()
	grid.columns = _columnas()
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 4)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lista.add_child(grid)
	_cols_pintadas = grid.columns
	for i in tecnicas.size():
		_fila_tecnica(grid, pj, tecnicas[i], i)


# Cuantas columnas caben AHORA. Se mide en vez de fijarlo porque el ancho depende de la ventana (y
# en movil, de la orientacion), igual que en la rejilla del inventario.
const ANCHO_DOS := 520.0

func _columnas() -> int:
	var ancho: float = _lista.size.x
	if ancho <= 1.0:
		ancho = ANCHO_LISTA_MIN   # primera pasada: aun no esta colocado
	return 2 if ancho >= ANCHO_DOS else 1


# Repintar SOLO si cambia el numero de columnas. Sin el guardia, cada pixel de resize dispara un
# rebuild entero y arrastrar el borde de la ventana se vuelve un tiron.
var _cols_pintadas: int = 0

func _on_lista_redimensionada() -> void:
	if not _root.visible or _columnas() == _cols_pintadas:
		return
	_rebuild()


func _fila_tecnica(grid: GridContainer, pj: PersonajeData, ab: AbilityData, i: int) -> void:
	var b := TooltipButton.new()   # tooltip multilinea: el de Godot no parte lineas
	b.custom_minimum_size = Vector2(0, MenuScaffold.ALTO_BOTON)
	# Que las dos columnas midan lo mismo: sin esto cada boton pide el ancho de SU texto y la rejilla
	# sale con una columna gorda y otra flaca segun lo largo que sea el nombre de la primera tecnica.
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.toggle_mode = true
	b.button_pressed = (i == _sel)
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("h_separation", 0)
	b.text = "  " + ab.nombre
	b.tooltip_text = ab.resumen(Game.manos_de(ab, pj))
	if ab.descripcion != "":
		b.tooltip_text += "\n\n" + ab.descripcion
	b.pressed.connect(_pick.bind(i))
	grid.add_child(b)

	# EL ESTADO, pegado al borde derecho del mismo boton. Va dibujado y no en otra etiqueta porque
	# un Label encima de un Button se come el clic y la fila dejaria de poder elegirse.
	var estado: String = _estado_de(pj, ab)
	var col: Color = _color_estado(pj, ab)
	b.draw.connect(func() -> void:
		var f: Font = b.get_theme_font(&"font")
		var an: float = f.get_string_size(estado, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		b.draw_string(f, Vector2(b.size.x - an - 12.0, b.size.y * 0.5 + 5.0), estado,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col))


func _estado_de(pj: PersonajeData, ab: AbilityData) -> String:
	if ab.inicial:
		return "viene con el arma"
	if Game.habilidad_desbloqueada(ab, pj):
		return "ya la sabe"
	if not Game.puede_pagar(ab.precio):
		return "te faltan %d" % (ab.precio - Game.money)
	return "%d monedas" % ab.precio


func _color_estado(pj: PersonajeData, ab: AbilityData) -> Color:
	if ab.inicial or Game.habilidad_desbloqueada(ab, pj):
		return VERDE
	return GRIS if not Game.puede_pagar(ab.precio) else AMBAR


# LA FICHA de la tecnica elegida, con su boton. Todo sale de resumen(), asi que tocar un numero en
# el .tres se ve aqui sin escribir nada (ver AbilityData.resumen).
func _pintar_ficha(pj: PersonajeData) -> void:
	var tecnicas: Array = _tecnicas()
	if tecnicas.is_empty() or _sel < 0 or _sel >= tecnicas.size():
		return
	var ab: AbilityData = tecnicas[_sel]
	MenuScaffold.titulo(_content, String(ab.nombre), 17)
	if ab.has_method("es_area"):
		MenuScaffold.fila(_content, "Alcance", "Área" if ab.es_area() else "Individual")
	var l := Label.new()
	l.text = ab.resumen(Game.manos_de(ab, pj))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(l)
	if ab.descripcion != "":
		MenuScaffold.nota(_content, ab.descripcion)
	_content.add_child(HSeparator.new())

	var sabida: bool = ab.inicial or Game.habilidad_desbloqueada(ab, pj)
	if sabida:
		MenuScaffold.nota(_content, ("%s ya se la sabe. Los cuatro huecos se ordenan en su ficha "
			+ "[C], arrastrando.") % pj.nombre)
	elif not Game.puede_pagar(ab.precio):
		MenuScaffold.nota(_content, "Te faltan %d monedas." % (ab.precio - Game.money))
	var fila := HBoxContainer.new()
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	_content.add_child(fila)
	var texto: String = "Ya la sabe" if sabida else "Aprender por %d" % ab.precio
	var b: Button = MenuScaffold.pastilla(fila, texto, _aprender.bind(ab), true,
		not sabida and Game.puede_pagar(ab.precio))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Con los dedos no hay "pasar el raton por encima", asi que la ficha completa necesita su boton.
	MenuScaffold.info(fila, b, String(ab.nombre))


func _aprender(ab: AbilityData) -> void:
	var pj: PersonajeData = _pj()
	if not Game.aprender_habilidad(ab, pj):
		_aviso = "No te llega el dinero."
		_aviso_ok = false
		_rebuild()
		return
	# APRENDER LA PONE SOLA si le cabe (lo hace Game.aprender_habilidad, igual que un grimorio con
	# las magias). El aviso dice cual de las dos cosas ha pasado: pagar por una tecnica y que no
	# aparezca en ningun sitio es lo que hace pensar que se ha perdido.
	if Game.habilidades_con_huecos(pj).has(ab):
		_aviso = "%s aprende %s y se la prepara." % [pj.nombre, ab.nombre]
	else:
		_aviso = "%s aprende %s, pero tendrá que colocarla en su ficha [C]." % [pj.nombre, ab.nombre]
	_aviso_ok = true
	_rebuild()


# ¿Lleva puesta ESTA arma (la plantilla, no la copia)? Ver _pintar_armas.
func _la_lleva(pj: PersonajeData, arma: Resource) -> bool:
	var ruta: String = String(arma.resource_path)
	for it in [pj.equipped_main, pj.equipped_off]:
		if it != null and Game.ruta_base_de(it) == ruta:
			return true
	return false
