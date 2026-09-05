# ============================================================
#  map_menu.gd  (CanvasLayer creada por codigo desde el jugador)
#  MAPA (tecla M). Es una LIBRETA autonoma: dibuja el snapshot congelado
#  (Game.mapa_visible()[piso] -- tu libreta en solitario, la del mundo del HOST en sesion) que se
#  pone al dia al ABANDONAR cada piso. Nada de GPS en vivo
#  (no pinta TU posicion): es un plano de lo ya recorrido. Como la libreta hornea la geometria,
#  el mapa se puede abrir TAMBIEN en el pueblo y HOJEAR otros pisos ya explorados (◀ ▶).
#
#  Solo aparecen los pisos REALMENTE explorados (los que tienen snapshot). Al morir, lo
#  cartografiado esa expedicion se pierde (ver Game.revertir_mapa_expedicion).
# ============================================================

extends CanvasLayer

# Solo por el enum Tipo (VETA/PLANTA/MADERA/SAL/HUERTO) con el que se elige la forma de cada marca.
# resource_node.gd no tiene class_name, asi que hay que precargar el script para llegar a el.
const ResourceNode := preload("res://scripts/world/resource_node.gd")

const MARGEN := 60.0        # px de borde alrededor del mapa
const COLOR_FONDO := Color(0.04, 0.04, 0.06, 0.94)
const COLOR_SUELO := Color(0.24, 0.24, 0.30)      # zona explorada
# Los MISMOS colores que tienen dentro de la mazmorra las escaleras (stairs.gd) y las salidas al
# pueblo (dungeon_exit.gd): lo que ves en el plano y lo que ves en el suelo se reconocen a la primera.
const COLOR_SUBE := Color(0.55, 0.8, 0.35)
const COLOR_BAJA := Color(0.1, 0.7, 0.85)
const COLOR_PUEBLO := Color(0.9, 0.72, 0.3)
# El agua del charco. NO es el color que tiene en el suelo (0.11, 0.19, 0.30): sobre el fondo casi
# negro del plano ese azul no se ve. En un mapa manda que se distinga, no que empareje.
const COLOR_AGUA := Color(0.26, 0.55, 0.82)

# --- LA TIRA DE PISOS (columna de tarjetas a la izquierda) ---
# Ancho de la columna entera. El plano se dibuja a partir de aqui: ver _dibujar.
const ANCHO_TIRA := 132.0
const TARJETA_ALTO := 64.0
const TARJETA_SEP := 8.0
const Y_TIRA := 60.0        # debajo del titulo

var _root: Control = null
var _lienzo: Control = null
var _titulo: Label = null
var _tira: ScrollContainer = null
var _tira_col: VBoxContainer = null
var _tarjetas: Dictionary = {}   # piso (int) -> Control de su tarjeta
var _piso_viendo: int = 1   # piso cuyo mapa se esta MIRANDO (independiente de Game.current_floor)


func _ready() -> void:
	layer = 92   # como el menu de personaje: por encima del HUD
	process_mode = Node.PROCESS_MODE_ALWAYS   # el arbol se para: hay que seguir respondiendo
	add_to_group("menu_mapa")   # lo busca el boton del pergamino del HUD (ver hud.gd)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)

	var fondo := ColorRect.new()
	fondo.color = COLOR_FONDO
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(fondo)

	_lienzo = Control.new()
	_lienzo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lienzo.draw.connect(_dibujar)
	_root.add_child(_lienzo)

	_titulo = Label.new()
	_titulo.add_theme_font_size_override("font_size", 18)
	_titulo.position = Vector2(MARGEN, 20.0)
	_root.add_child(_titulo)

	# La TIRA DE PISOS: una tarjeta por piso, en una columna que se desliza. Sustituye al hojeo con
	# ◀ ▶, que en el movil no existia (no hay teclas) y que ademas no te decia en cual estabas.
	_tira = ScrollContainer.new()
	_tira.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tira.position = Vector2(12.0, Y_TIRA)
	_tira.size = Vector2(ANCHO_TIRA, 400.0)   # el alto se ajusta en _refrescar, ya con viewport
	_root.add_child(_tira)
	_tira_col = VBoxContainer.new()
	_tira_col.add_theme_constant_override("separation", int(TARJETA_SEP))
	_tira.add_child(_tira_col)
	ArrastreScroll.enganchar(_tira)

	# La ✕ de cerrar, arriba a la derecha. Hace falta de verdad: el mapa se cerraba solo con M o
	# ESC, asi que desde el movil se entraba y no se salia. Va tambien en escritorio.
	var cerrar: Control = BotonIcono.crear(Callable(Iconos, "equis"), _cerrar, 56.0)
	cerrar.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cerrar.offset_left = -12.0 - 56.0
	cerrar.offset_right = -12.0
	cerrar.offset_top = 12.0
	cerrar.offset_bottom = 12.0 + 56.0
	_root.add_child(cerrar)


# ESC va en _input y CONSUME el evento: _input corre SIEMPRE antes que _unhandled_input, asi que el
# menu de PAUSA (que escucha ahi) no llega a ver la tecla y no se abre por detras al cerrar el mapa.
func _input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if not event.is_action_pressed(&"cancelar"):
		return
	_cerrar()
	get_viewport().set_input_as_handled()


# Las teclas de LETRA van en _unhandled_key_input y NO en _input, por lo mismo que las teclas de dev
# (ver la cabecera de Game._unhandled_key_input): _input corre ANTES que la GUI y se comia lo que
# escribias, mientras que un LineEdit con el foco CONSUME la tecla y aqui no llega. Asi escribir en un
# campo de texto (el nombre al reclutar, la cantidad del bote) ya no abre el mapa por encima.
# Game.escribiendo() es el cinturon explicito encima de eso. No lo devuelvas a _input.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if Game.escribiendo():
		return   # con el foco en un campo de texto, una tecla es una LETRA y no un atajo
	if event.is_action_pressed(&"mapa"):
		_toggle()
	elif not _root.visible:
		return
	elif event.is_action_pressed(&"move_left"):
		_cambiar_viendo(-1)
	elif event.is_action_pressed(&"move_right"):
		_cambiar_viendo(1)


func _toggle() -> void:
	if _root.visible:
		_cerrar()
		return
	# No sobre un combate/extraccion, ni con el DEBUG abierto, ni encima de OTRO MENU. Lo ultimo era
	# hay que decirlo: en solitario lo tapaba la pausa del arbol, pero en MULTI nada pausa y el mapa se
	# abria encima de la tienda o de la taberna. hay_modal() cubre la pila entera de menus.
	# Ya NO exige piso vivo: se abre tambien en el pueblo (la libreta es autonoma).
	if Game._active_layer != null or Game.debug_panel_open or Game.hay_modal():
		return
	# Empieza SIEMPRE por el piso en el que estas, lo tengas cartografiado o no. Antes, si el piso
	# era nuevo, saltaba al mas profundo que hubieras traido a salvo: justo lo contrario de lo que
	# hace falta, porque el numero del piso ya no se enseña en el HUD y esta libreta es ahora la
	# forma de saber DONDE estas. Sin mapa se abre en blanco, que ya lo cuenta _dibujar().
	_piso_viendo = Game.current_floor
	_root.visible = true
	Game.abrir_menu(self)   # para el mundo entero mientras el menu esta abierto
	# La tira se rehace CADA VEZ: la lista de pisos crece segun juegas, y el que se rehiciera solo al
	# nacer el menu la dejaba congelada con los pisos de la primera vez que lo abriste.
	_rehacer_tira()
	_ver_piso(_piso_viendo)   # pinta y deja la tira ya puesta en tu piso


func _cerrar() -> void:
	_root.visible = false
	Game.cerrar_menu(self)


# Pisos con mapa (SOLO los comprometidos: lo que has traido vivo al pueblo), ordenados. Es la
# lista por la que se hojea. La cartografia de la bajada en curso (mapa_trabajo) NO se pinta hasta
# que se comete al volver al pueblo con vida: el mapa refleja lo que has puesto a salvo, no lo que
# estas viendo ahora mismo.
func _pisos_disponibles() -> Array:
	var out: Array = Game.mapa_visible().keys()
	# Y SIEMPRE el piso en el que estas, lo tengas cartografiado o no: si no, el piso al que acabas
	# de bajar no tendria tarjeta y esta libreta —que es como sabes donde estas desde que el numero
	# se fue del HUD— se quedaria justo sin el dato que importa.
	if not out.has(Game.current_floor):
		out.append(Game.current_floor)
	out.sort()
	return out


# ------------------------------------------------------------
#  LA TIRA DE PISOS
#  Dos marcas DISTINTAS, porque son dos cosas distintas y de un vistazo se confunden:
#    - donde ESTAS (Game.current_floor): borde vivo y la etiqueta "AQUI".
#    - lo que MIRAS (_piso_viendo): la tarjeta rellena.
#  Casi siempre coinciden (el mapa abre por tu piso), pero al hojear se separan.
# ------------------------------------------------------------
func _rehacer_tira() -> void:
	for t in _tira_col.get_children():
		t.queue_free()
	_tarjetas.clear()
	for piso in _pisos_disponibles():
		var tarjeta: Control = _crear_tarjeta(int(piso))
		_tira_col.add_child(tarjeta)
		_tarjetas[int(piso)] = tarjeta
	# El alto se fija aqui y no en _ready porque depende del viewport, que al construirse el menu
	# todavia no es el definitivo.
	var alto_util: float = get_viewport().get_visible_rect().size.y - Y_TIRA - 16.0
	_tira.size = Vector2(ANCHO_TIRA, maxf(120.0, alto_util))


func _crear_tarjeta(piso: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(ANCHO_TIRA - 16.0, TARJETA_ALTO)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	var font: Font = ThemeDB.fallback_font
	c.draw.connect(func() -> void:
		var aqui: bool = piso == Game.current_floor
		var mirando: bool = piso == _piso_viendo
		var con_mapa: bool = Game.mapa_visible().has(piso)

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.20, 0.24, 0.34, 0.95) if mirando else Color(0.09, 0.10, 0.13, 0.85)
		sb.border_color = COLOR_SUBE if aqui else Color(1, 1, 1, 0.18)
		sb.set_border_width_all(3 if aqui else 1)
		sb.set_corner_radius_all(10)
		c.draw_style_box(sb, Rect2(Vector2.ZERO, c.size))

		# Un piso sin cartografiar se pinta apagado: se puede mirar igual, pero sale en blanco.
		var tinta: Color = Color(0.95, 0.95, 1.0) if con_mapa else Color(0.55, 0.55, 0.62)
		c.draw_string(font, Vector2(14.0, 34.0), "P %d" % piso,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 22, tinta)
		if aqui:
			c.draw_string(font, Vector2(14.0, 54.0), "AQUÍ",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_SUBE)
		elif not con_mapa:
			c.draw_string(font, Vector2(14.0, 54.0), "sin mapa",
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.5, 0.5, 0.57))
	)
	c.gui_input.connect(func(event: InputEvent) -> void:
		# Solo al SOLTAR, y solo si el gesto no se ha convertido en un arrastre de la tira: si no,
		# deslizar la columna cambiaria de piso a cada dedazo (ver arrastre_scroll.gd).
		var suelta: bool = (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed) \
			or (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed \
				and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT)
		if suelta and not ArrastreScroll.hubo_arrastre(_tira):
			_ver_piso(piso)
	)
	return c


# Cambia el plano que se mira. UNICA puerta: por aqui pasan el toque en la tarjeta y las teclas
# ◀ ▶, para que la marca y el desplazamiento de la tira no dependan de por donde hayas entrado.
func _ver_piso(piso: int) -> void:
	_piso_viendo = piso
	_refrescar()
	if _tarjetas.has(piso):
		_tira.ensure_control_visible(_tarjetas[piso])


# Salta al piso cartografiado anterior/siguiente (dir = -1/+1). Solo entre los explorados.
func _cambiar_viendo(dir: int) -> void:
	var pisos: Array = _pisos_disponibles()
	var idx: int = pisos.find(_piso_viendo)
	if idx == -1:
		if pisos.is_empty():
			return
		_ver_piso(int(pisos[0]))
	else:
		_ver_piso(int(pisos[clampi(idx + dir, 0, pisos.size() - 1)]))


func _refrescar() -> void:
	# Ni "◀ ▶ pisos" ni "[M] cerrar": la tira de la izquierda ya enseña los pisos y la ✕ ya enseña
	# por donde se sale, asi que nombrar las teclas encima era ruido.
	_titulo.text = "MAPA · Piso %d" % _piso_viendo
	for t in _tira_col.get_children():
		(t as Control).queue_redraw()   # la marca de "lo que miras" se ha movido
	_lienzo.queue_redraw()


# Donde empieza el plano por la izquierda: justo despues de la tira de pisos. En un solo sitio
# porque lo miran el dibujo del plano Y el aviso de "sin cartografiar".
func _x_plano() -> float:
	return 12.0 + ANCHO_TIRA + MARGEN * 0.5


func _dibujar() -> void:
	var snap: Dictionary = Game.mapa_visible().get(_piso_viendo, {})
	# Sin snapshot, o uno viejo sin la geometria horneada (saves anteriores): nada que dibujar.
	if snap.is_empty() or not snap.has("suelo"):
		var f0: Font = ThemeDB.fallback_font
		_lienzo.draw_string(f0, Vector2(_x_plano(), 90.0),
			"Aún no has cartografiado este piso. Explóralo y sal con vida.",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.7, 0.75))
		return

	var ancho: int = int(snap["ancho"])
	var alto: int = int(snap["alto"])
	var agotados: Dictionary = snap["agotados"]

	# Escala: que el mapa entero quepa en la pantalla con margen, manteniendo proporcion. El ancho
	# util arranca DESPUES de la tira de pisos (_x_plano), o el plano se dibujaria por debajo de las
	# tarjetas y no habria forma de leerlo.
	var x0: float = _x_plano()
	var area := get_viewport().get_visible_rect().size \
		- Vector2(x0 + MARGEN, MARGEN * 2.0)
	var celda_px: float = minf(area.x / float(ancho), area.y / float(alto))
	var offset := Vector2(x0, MARGEN) \
		+ (area - Vector2(ancho, alto) * celda_px) * 0.5

	# 1) SUELO de las zonas cartografiadas (horneado en la libreta; la niebla es no dibujar el resto).
	for c in (snap["suelo"] as Array):
		var p: Vector2 = offset + Vector2(c) * celda_px
		_lienzo.draw_rect(Rect2(p, Vector2(celda_px, celda_px)), COLOR_SUELO)

	# 2) NODOS que estaban VIVOS al cartografiar: color del material (congelado en la libreta).
	for n in (snap["vivos"] as Array):
		_marca(offset, celda_px, n["cell"], n["color"], int(n.get("tipo", -1)), 0.42)

	# 3) NODOS AGOTADOS al cartografiar: apagados + cuenta atras hasta el respawn. Y cuando la
	# cuenta atras VENCE se pintan como VIVOS: el respawn corre en tiempo real, asi que a esa hora
	# el nodo ya ha brotado de verdad aunque la libreta se congelara con el agotado. Antes aqui
	# habia un 'continue' y la celda desaparecia del plano: material listo que no salia marcado.
	var font: Font = ThemeDB.fallback_font
	for celda in agotados:
		var e = agotados[celda]
		# Saves viejos guardaban solo el sello (float); los nuevos, un dict con color y tipo.
		var sello: float = float(e["t"]) if e is Dictionary else float(e)
		var falta: float = Game.RESPAWN_SEGUNDOS - (Game.reloj_mundo() - sello)
		if falta <= 0.0:
			if e is Dictionary and e.has("color"):
				_marca(offset, celda_px, celda, e["color"], int(e.get("tipo", -1)), 0.42)
			continue
		var p: Vector2 = offset + (Vector2(celda) + Vector2(0.5, 0.5)) * celda_px
		_lienzo.draw_circle(p, celda_px * 0.30, Color(0.4, 0.4, 0.42, 0.7))
		_lienzo.draw_string(font, p + Vector2(celda_px * 0.4, -celda_px * 0.4),
			"%dm" % int(ceil(falta / 60.0)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(0.7, 0.7, 0.75))

	# 4) EL ESTANQUE: la balsa entera, con su tamaño real. Va antes que las escaleras (que son las que
	# mandan al orientarse) pero despues de los nodos, para que ninguna marca de veta se le pierda
	# encima del azul. Con .get(): los mapas cartografiados antes de esto no traen la clave.
	for est in (snap.get("estanques", []) as Array):
		_estanque(offset, celda_px, font, est["cell"], est["tam"], est.get("celdas", []))

	# 5) ESCALERAS y SALIDAS: los puntos por los que de verdad te orientas. Van los ULTIMOS para que
	# no los tape ningun nodo ni su cuenta atras. Con .get(): los mapas de saves viejos no tienen
	# estas claves (se rellenan solas la proxima vez que cartografies el piso).
	for esc in (snap.get("escaleras", []) as Array):
		var sube: bool = bool(esc["sube"])
		_hito(offset, celda_px, font, esc["cell"],
			COLOR_SUBE if sube else COLOR_BAJA, "SUBIR" if sube else "BAJAR")
	for celda_salida in (snap.get("salidas", []) as Array):
		_hito(offset, celda_px, font, celda_salida, COLOR_PUEBLO, "PUEBLO")


# EL CHARCO. A diferencia de un hito de una celda, este se pinta CON SU FORMA: en el plano hay que
# reconocer la balsa por su mancha, igual que en el suelo. La celda que se guarda es su CENTRO (ver
# FishingSpot.celda), asi que hay que restarle la mitad para dar con la esquina.
#
# Los mapas cartografiados ANTES de que el charco tuviera forma no traen `celdas`: esos se siguen
# pintando como el rectangulo de entonces, y se arreglan solos la proxima vez que se cartografie.
func _estanque(offset: Vector2, celda_px: float, font: Font, centro: Vector2i, tam: Vector2i,
		celdas: Variant) -> void:
	var esquina: Vector2i = centro - Vector2i(tam.x / 2, tam.y / 2)
	var p: Vector2 = offset + Vector2(esquina) * celda_px
	var lista := celdas as PackedVector2Array if celdas is PackedVector2Array else PackedVector2Array()
	if lista.is_empty():
		_lienzo.draw_rect(Rect2(p, Vector2(tam) * celda_px), COLOR_AGUA)
	else:
		# El rotulo se ancla a la esquina de lo que OCUPA el agua, no a la primera celda de la lista:
		# el diccionario no viene ordenado y "PESCA" saldria en un sitio distinto cada vez.
		var arriba: Vector2 = lista[0]
		for c in lista:
			_lienzo.draw_rect(Rect2(offset + c * celda_px, Vector2(celda_px, celda_px)), COLOR_AGUA)
			arriba = arriba.min(c)
		p = offset + arriba * celda_px
	_lienzo.draw_string(font, p + Vector2(0.0, -celda_px * 0.3), "PESCA",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COLOR_AGUA)


# Un HITO del plano (escalera o salida): su celda pintada del color que tiene en el suelo, con el
# rotulo al lado. Una sola funcion para los tres: si cambia el aspecto, cambia para todos.
func _hito(offset: Vector2, celda_px: float, font: Font, celda: Vector2i, color: Color, txt: String) -> void:
	var q: Vector2 = offset + Vector2(celda) * celda_px
	_lienzo.draw_rect(Rect2(q, Vector2(celda_px, celda_px)), color)
	_lienzo.draw_string(font, q + Vector2(celda_px * 1.2, celda_px * 0.9), txt,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)


# La marca de un nodo de recoleccion. El COLOR sigue siendo el del material (como antes), pero
# ahora la FORMA dice de que tipo es, que es lo que no se podia leer de un vistazo: tres circulos
# de colores parecidos no te dicen cual era la veta. Formas con primitivas y no glifos de fuente
# a proposito: ThemeDB.fallback_font no garantiza ningun simbolo bonito.
#   VETA = rombo (un bulto en la roca) · PLANTA = circulo (el manojo) · MADERA = cuadrado (tocon)
#   SAL = triangulo (el terron que asoma) · HUERTO = barra ancha y baja (la mata a ras de suelo)
#
# La sal y el huerto SI se cartografiaban —tienen material_data y estan en "recolectable"—, pero
# caian las dos en el circulo del `_:` y en el plano eran indistinguibles de una planta. Con cinco
# tipos de nodo, "el que no es veta ni madera" ya no es una categoria: cada uno su forma.
#
# Las formas siguen la silueta que tiene el nodo EN EL SUELO (ver ResourceNode._crear_aspecto): el
# huerto es ancho y bajo alli y aqui, la sal es compacta en los dos sitios. Lo que reconoces en el
# pasillo es lo que reconoces en la libreta.
#
# tipo -1 = snapshot viejo sin el dato: circulo, como se dibujaba antes.
func _marca(offset: Vector2, celda_px: float, celda: Vector2i, color: Color, tipo: int,
		radio_frac: float) -> void:
	var p: Vector2 = offset + (Vector2(celda) + Vector2(0.5, 0.5)) * celda_px
	var r: float = celda_px * radio_frac
	match tipo:
		ResourceNode.Tipo.VETA:
			_lienzo.draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -r), p + Vector2(r, 0), p + Vector2(0, r), p + Vector2(-r, 0),
			]), color)
		ResourceNode.Tipo.MADERA:
			_lienzo.draw_rect(Rect2(p - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), color)
		ResourceNode.Tipo.SAL:
			_lienzo.draw_colored_polygon(PackedVector2Array([
				p + Vector2(0, -r), p + Vector2(r, r * 0.8), p + Vector2(-r, r * 0.8),
			]), color)
		ResourceNode.Tipo.HUERTO:
			_lienzo.draw_rect(Rect2(p - Vector2(r, r * 0.45), Vector2(r * 2.0, r * 0.9)), color)
		_:
			_lienzo.draw_circle(p, r, color)
