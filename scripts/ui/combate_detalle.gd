# ============================================================
#  combate_detalle.gd  (Control creado por codigo desde combat.gd)
#  FICHA DE DETALLE a pantalla completa de un combatiente, estilo Honkai Star Rail.
#
#  Por que existe: los chips de estado de la tarjeta van ICONO-ONLY en una fila con clip
#  (ver StatusChip). Cuando alguien lleva mas estados de los que caben, no hay forma de
#  leerlos. Ni de ver las stats reales de un aliado con el aporte del equipo desglosado, ni
#  las habilidades / la historia de un enemigo. Aqui se ve todo eso, con calma.
#
#  SOLO se abre en TU turno (combat._puedo_inspeccionar): no en mitad de una animacion, ni
#  en el turno de un enemigo, ni -en multi- en el de un aliado. Asi no hay un menu abierto
#  con el combate corriendo por detras.
#
#  Se abre de dos maneras (las dos las dispara combat.gd):
#    - boton "i" arriba a la derecha  -> abre en el primer personaje de tu formacion.
#    - mantener pulsado 1 s sobre una tarjeta/figura -> abre en ESE combatiente.
#
#  El jugador y sus compañeros ya se ven con el MunecoJugador de verdad (ver _pintar_figura),
#  mirando al SUR (de cara, como un retrato) -- lo contrario del escenario de combate, que
#  mira al norte. Se cae al cuadrado de color solo si no hay ficha detras (combate suelto de
#  pruebas, o un compañero espejado en red antes de que llegue su roster).
# ============================================================

extends Control
class_name CombateDetalle

const ANCHO_PANEL := 460.0
const AMBAR := Color(0.95, 0.72, 0.36)
const AZUL_EQUIPO := Color(0.55, 0.75, 1.0)   # el "+1446" de la captura
const GRIS := Color(0.62, 0.65, 0.72)

var _combat: Node = null                 # la escena de combate (combat.gd)

var _bando: int = 0                      # 0 = tus aliados, 1 = los de enfrente
var _idx: int = 0                        # indice dentro de la lista del bando
var _pestana: int = 0                    # 0 Detalles, 1 Habilidades, 2 Historia/Equipo
var _hab_sel: int = 0                    # habilidad elegida en la pestaña Habilidades
var _slot_sel: String = ""               # pieza desplegada en la pestaña Equipo ("" = ninguna)

var _tira: VBoxContainer = null          # los retratos, a la izquierda
var _switch_box: HBoxContainer = null    # conmutador de bando
var _figura_host: Control = null         # el combatiente en grande, en el centro
var _titulo_lbl: Label = null
var _tabs_box: HBoxContainer = null
var _panel: VBoxContainer = null         # cuerpo de la pestaña (derecha, con scroll)
var _modal: Control = null               # sub-overlay "Informacion de los atributos"

# LA FIGURA DEL CENTRO, guardada para poder RECOLOCARLA cuando el hueco cambie de tamaño (ver
# _recolocar_figura). Solo uno de los dos esta puesto a la vez: muñeco para los tuyos, sprite para
# los de enfrente.
var _fig_muneco: MunecoJugador = null
var _fig_sprite: AnimatedSprite2D = null
var _fig_rect: Rect2i = Rect2i()         # del sprite del enemigo: el pixel PINTADO de su fotograma
var _fig_marco: Vector2 = Vector2.ZERO   # del sprite del enemigo: el fotograma entero, con su aire

# Cuanto del hueco llena la figura. El aire que queda es para el pelo alto, el arma levantada y la
# sombra de contacto -- llenarlo al 100% le corta la coronilla en cuanto una animacion sube.
const OCUPA_FIG := 0.80
# Y UN TOPE EN PIXELES, porque el hueco crece con la pantalla y solo con la proporcion un Trent
# ocupaba media ventana en 1080p. Manda el mas pequeño de los dos: llena el hueco cuando es chico,
# y se planta cuando el hueco es enorme.
const ALTO_FIG_MAX := 320.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# POR ENCIMA DE TODO lo del escenario de combate: los marcadores de turno (turn_timeline.gd)
	# se pintan con z_index alto (hasta varios cientos) para ordenarse ENTRE ELLOS, y sin esto
	# se veian a traves de esta pantalla aunque estuviera encima en el arbol.
	z_index = 4096
	visible = false
	_construir()


func preparar(combat: Node) -> void:
	_combat = combat


# --- Construccion del armazon (una vez) ---------------------------------------

func _construir() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.06, 0.08, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	# Cabecera: titulo + X.
	_titulo_lbl = Label.new()
	_titulo_lbl.add_theme_color_override("font_color", AMBAR)
	_titulo_lbl.add_theme_font_size_override("font_size", 20)
	_titulo_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_titulo_lbl.position = Vector2(24 + Tactil.borde.x, 18 + Tactil.borde.y)
	add_child(_titulo_lbl)
	MenuScaffold.equis_cerrar(self, cerrar, "Cerrar  (C / Esc)")

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 20 + Tactil.borde.x
	hb.offset_top = 64 + Tactil.borde.y
	hb.offset_right = -(16 + Tactil.borde.x)
	hb.offset_bottom = -(16 + Tactil.borde.y)
	hb.add_theme_constant_override("separation", 16)
	add_child(hb)

	# --- Columna 1: tira de retratos + conmutador de bando ---
	var col_tira := VBoxContainer.new()
	col_tira.custom_minimum_size = Vector2(96, 0)
	col_tira.add_theme_constant_override("separation", 8)
	hb.add_child(col_tira)

	var tira_scroll := ScrollContainer.new()
	tira_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tira_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_tira.add_child(tira_scroll)
	_tira = VBoxContainer.new()
	_tira.add_theme_constant_override("separation", 8)
	tira_scroll.add_child(_tira)

	_switch_box = HBoxContainer.new()
	_switch_box.add_theme_constant_override("separation", 4)
	col_tira.add_child(_switch_box)
	for i in 2:
		var sb := Button.new()
		sb.text = "Tuyos" if i == 0 else "Ellos"
		sb.toggle_mode = true
		sb.focus_mode = Control.FOCUS_NONE
		sb.custom_minimum_size = Vector2(46, 34)
		sb.add_theme_font_size_override("font_size", 12)
		sb.pressed.connect(_cambiar_bando.bind(i))
		_switch_box.add_child(sb)

	# --- Columna 2: el combatiente en grande ---
	_figura_host = Control.new()
	_figura_host.custom_minimum_size = Vector2(300, 0)
	_figura_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_figura_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_figura_host.clip_contents = true
	# EL HUECO NO SABE SU TAMAÑO HASTA QUE EL CONTENEDOR REPARTE. Todo el colocado de la figura sale
	# de _figura_host.size, que al construir vale (0,0): sin esto la figura se pinta una vez contra un
	# hueco de cero y ya no se entera de nada.
	_figura_host.resized.connect(_recolocar_figura)
	hb.add_child(_figura_host)

	# --- Columna 3: pestañas + panel ---
	var col_der := VBoxContainer.new()
	col_der.custom_minimum_size = Vector2(ANCHO_PANEL, 0)
	col_der.add_theme_constant_override("separation", 8)
	hb.add_child(col_der)

	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 6)
	col_der.add_child(_tabs_box)
	col_der.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col_der.add_child(scroll)
	# MARGEN a la derecha: la barra de scroll se come el borde del panel y sin esto los valores
	# largos ("200 / 200") quedaban cortados justo por debajo de ella.
	var margen := MarginContainer.new()
	margen.add_theme_constant_override("margin_right", 14)
	margen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(margen)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 6)
	_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margen.add_child(_panel)


# --- Abrir / cerrar ----------------------------------------------------------

# 'c' == null -> abre en el primer personaje de tu formacion.
func abrir(c = null) -> void:
	if _combat == null:
		return
	_bando = 0
	_idx = 0
	_pestana = 0
	_hab_sel = 0
	_slot_sel = ""
	if c != null:
		var en_enemigos: int = _lista(1).find(c)
		if en_enemigos >= 0:
			_bando = 1
			_idx = en_enemigos
		else:
			_idx = maxi(0, _lista(0).find(c))
	visible = true
	_refrescar()


func cerrar() -> void:
	_cerrar_modal()
	visible = false


func abierta() -> bool:
	return visible


# ESC / C cierran (y consumen el evento antes de que el combate o la pausa lo vean).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_C or event.is_action_pressed(&"cancelar"):
		if _modal != null:
			_cerrar_modal()
		else:
			cerrar()
		get_viewport().set_input_as_handled()


# --- Datos ------------------------------------------------------------------

# Los combatientes VIVOS de un bando. 0 = tus aliados, 1 = los de enfrente.
func _lista(bando: int) -> Array:
	var fuente: Array = _combat._aliados if bando == 0 else _combat._enemies
	var out: Array = []
	for x in fuente:
		if x != null and x.is_alive():
			out.append(x)
	return out


func _actual() -> Combatant:
	var l: Array = _lista(_bando)
	if l.is_empty():
		return null
	_idx = clampi(_idx, 0, l.size() - 1)
	return l[_idx]


func _es_enemigo() -> bool:
	return _bando == 1


func _cambiar_bando(b: int) -> void:
	if b == _bando or _lista(b).is_empty():
		return
	_bando = b
	_idx = 0
	_pestana = 0
	_hab_sel = 0
	_slot_sel = ""
	_refrescar()


# --- Repintado -------------------------------------------------------------

func _refrescar() -> void:
	var c: Combatant = _actual()
	if c == null:
		# El bando se ha quedado vacio (todos muertos): salta al otro o cierra.
		if not _lista(1 - _bando).is_empty():
			_cambiar_bando(1 - _bando)
		else:
			cerrar()
		return

	_titulo_lbl.text = "Detalles de los aliados" if not _es_enemigo() else "Detalles del enemigo"
	for i in _switch_box.get_child_count():
		var sb: Button = _switch_box.get_child(i)
		sb.button_pressed = (i == _bando)
		sb.disabled = _lista(i).is_empty()

	_pintar_tira()
	_pintar_figura(c)
	_pintar_tabs()
	MenuScaffold.vaciar(_panel)
	match _pestana:
		0: _tab_detalles(c)
		1: _tab_habilidades(c)
		2:
			if _es_enemigo(): _tab_historia(c)
			else: _tab_equipo(c)


func _pintar_tira() -> void:
	MenuScaffold.vaciar(_tira)
	var l: Array = _lista(_bando)
	for i in l.size():
		var c: Combatant = l[i]
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(72, 72)
		b.toggle_mode = true
		b.button_pressed = (i == _idx)
		# EL ANILLO del que estas mirando. Va como stylebox propio y no fiandose del tema: el
		# retrato ocupa el boton entero y su borde por defecto se perderia debajo.
		var marco := StyleBoxFlat.new()
		marco.bg_color = Color(0.12, 0.13, 0.17, 1.0)
		marco.border_color = AMBAR if i == _idx else Color(1, 1, 1, 0.18)
		marco.set_border_width_all(3 if i == _idx else 1)
		marco.set_corner_radius_all(6)
		marco.set_content_margin_all(3)
		for estado in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(estado, marco)
		var pj: PersonajeData = Game.pj_de_combatant(c)
		var retrato: Texture2D = pj.textura() if pj != null else null
		if retrato == null and _es_enemigo():
			retrato = _miniatura_enemigo(c)   # su primer fotograma, para reconocerlo de un vistazo
		if retrato != null:
			var tr := TextureRect.new()
			tr.texture = retrato
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_encajar(tr)
			b.add_child(tr)
		elif not _es_enemigo() and pj != null and _muneco_retrato(b, pj):
			pass   # el muñeco entero, para los tuyos que no tienen foto puesta
		else:
			var cr := ColorRect.new()
			cr.color = c.color_visual if _es_enemigo() else _combat._color_de(c)
			cr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_encajar(cr)
			b.add_child(cr)
		b.tooltip_text = c.nombre
		var j: int = i
		b.pressed.connect(func() -> void:
			_idx = j
			_hab_sel = 0
			_slot_sel = ""
			_refrescar())
		_tira.add_child(b)


# DEVUELVE EL MUÑECO AL Z RELATIVO, que es lo unico que hace falta para que se VEA aqui dentro.
# MunecoJugador nace con z_as_relative = false a proposito (en el mapa sus capas se ordenan contra el
# mundo, no contra el cuerpo que las lleva), pero esta pantalla va a z_index 4096 para taparlo todo:
# con z absoluto el muñeco se dibuja en el z ~0 de sus capas, o sea DEBAJO del fondo de la ficha.
#
# Y HAY QUE ESPERAR A SU _ready SI TODAVIA NO HA CORRIDO: ahi es donde el muñeco pone el false. En la
# tira eso pasa siempre (el boton se cuelga de la tira despues de montarle dentro el muñeco), y
# ponerlo antes no vale de nada -- se veia el retrato vacio aunque el muñeco estuviera puesto.
func _z_relativo(m: MunecoJugador) -> void:
	m.z_as_relative = true
	m.z_index = 0
	if m.is_node_ready():
		return
	m.ready.connect(func() -> void:
		m.z_as_relative = true
		m.z_index = 0, CONNECT_ONE_SHOT)


# EL MUÑECO COMO RETRATO, para los tuyos que no tienen foto puesta: sin esto eran un cuadrado de
# color, que es lo mismo para los cuatro y no deja reconocer a nadie de un vistazo. Devuelve si ha
# podido montarlo (si no, quien llama se queda con el cuadrado de siempre).
#
# Va DENTRO de un hueco propio con recorte, y no colgando del boton: el muñeco se dibuja en unidades
# de mundo y se saldria del marco. Y se recoloca por 'resized' porque el boton no sabe lo que mide
# hasta que la tira reparte (la misma trampa que la figura grande).
func _muneco_retrato(b: Button, pj: PersonajeData) -> bool:
	var m := MunecoJugador.new()
	m.montar(pj)
	m.tenir(pj.color, 0.0)
	m.poner_cara(pj.textura())
	if not m.hay_dibujo():
		m.queue_free()
		return false
	m.animar("idle_0")
	var hueco := Control.new()
	hueco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hueco.clip_contents = true
	_encajar(hueco)
	b.add_child(hueco)
	hueco.add_child(m)
	_z_relativo(m)   # mismo motivo que en la figura grande: esta pantalla va a z 4096
	var colocar := func() -> void:
		var z: Vector2 = hueco.size
		if z.x <= 1.0 or z.y <= 1.0:
			return
		var esc: float = minf(z.y / PoseJugador.ALTO_MUNDO,
			z.x / (PoseJugador.ALTO_MUNDO * 0.55))
		m.scale = Vector2.ONE * esc
		var alto: float = PoseJugador.ALTO_MUNDO * esc
		m.position = Vector2(z.x * 0.5, (z.y - alto) * 0.5
			+ (PoseJugador.ALTO_MUNDO - PoseJugador.PIES_BAJO_NODO) * esc)
	hueco.resized.connect(colocar)
	colocar.call()
	return true


# Mete el retrato DENTRO del marco del boton, dejando ver su borde (el anillo del elegido).
func _encajar(n: Control) -> void:
	n.offset_left = 4
	n.offset_top = 4
	n.offset_right = -4
	n.offset_bottom = -4
	n.mouse_filter = Control.MOUSE_FILTER_IGNORE


# LA FIGURA CUELGA DIRECTAMENTE DEL HUECO, sin ningun Control intermedio, y ese es el arreglo: antes
# iba dentro de un 'host' de 260x260 que NUNCA recibia ese tamaño (un Control suelto no es hijo de un
# contenedor, asi que nadie le reparte y se queda en 0x0). Al muñeco ademas se le ponia clip_contents
# encima, y un recorte de tamaño cero no deja ver NADA: por eso el enemigo se veia (a el no se le
# recortaba) y tu personaje era un hueco negro.
#
# Aqui solo se MONTA. El tamaño y la posicion los pone _recolocar_figura, porque dependen de
# _figura_host.size y ese dato todavia no existe la primera vez (ver la conexion a 'resized').
func _pintar_figura(c: Combatant) -> void:
	for h in _figura_host.get_children():
		h.queue_free()
	_fig_muneco = null
	_fig_sprite = null

	var sp: AnimatedSprite2D = _sprite_enemigo(c) if _es_enemigo() else null
	if sp != null:
		_fig_sprite = sp
		_figura_host.add_child(sp)
		_recolocar_figura()
		return

	# EL MUÑECO DE VERDAD, para los tuyos con ficha detrás -- calco de VistaMuneco.mostrar(), que es
	# el mismo problema (encajar el muñeco en un Control). Mira al SUR (de cara, un retrato): lo
	# CONTRARIO del escenario de combate (combat.gd, que mira al norte porque ahí el jugador da la
	# espalda a la cámara para mirar a los enemigos) -- las dos direcciones van a propósito por
	# separado.
	if not _es_enemigo():
		var pj: PersonajeData = Game.pj_de_combatant(c)
		if pj != null:
			var m := MunecoJugador.new()
			m.montar(pj)
			m.tenir(pj.color, 0.0)
			m.poner_cara(pj.textura())
			if m.hay_dibujo():
				m.animar("idle_0")
				_fig_muneco = m
				_figura_host.add_child(m)
				# EL Z, VUELTO A RELATIVO, y sin esto no se ve NADA. MunecoJugador nace con
				# z_as_relative = false a propósito (en el mapa sus capas tienen que ordenarse contra
				# el mundo, no contra el cuerpo que las lleva), pero esta pantalla va a z_index 4096
				# para taparlo todo: con z absoluto el muñeco se dibujaba en el z ~0 de sus capas, o
				# sea DEBAJO del fondo de la propia ficha. El sprite del enemigo no sufría esto
				# porque un AnimatedSprite2D sí es relativo, y por eso el bicho se veía y tú no.
				_z_relativo(m)
				_recolocar_figura()
				return
			m.queue_free()   # sin capas de verdad (raro): se cae al cuadrado de siempre, como abajo

	# CUADRADO, como en el combate: color + shader de la cara para los tuyos, color plano
	# para un enemigo sin sprite. Cuadrado de verdad (no estirado al hueco): la cara va en un shader
	# pensado para un cuadrado, y deformarla la parte.
	var fig := ColorRect.new()
	fig.set_anchors_preset(Control.PRESET_CENTER)
	fig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _es_enemigo():
		fig.color = c.color_visual
	else:
		fig.color = _combat._color_de(c)
		fig.material = _combat._material_de(c)
	_figura_host.add_child(fig)
	_recolocar_figura()


# LLENAR EL HUECO, sea lo que sea lo que haya dentro. Se llama al montar y cada vez que el hueco
# cambia de tamaño (otra resolucion, otra ventana), y es el unico sitio donde se decide cuanto mide
# la figura: el enemigo y el muñeco median antes por su cuenta con numeros fijos (210 px el bicho,
# 0.80 de 260 el muñeco) y salian los dos como una mota en el centro de una columna enorme.
func _recolocar_figura() -> void:
	var zona: Vector2 = _figura_host.size
	if zona.x <= 1.0 or zona.y <= 1.0:
		return   # todavia sin repartir: ya volvera por 'resized'

	if _fig_sprite != null:
		# SE MIDE EL PIXEL PINTADO, no el fotograma: los del horno traen mucho aire alrededor (el
		# sitio que necesitan las animaciones que se mueven), y escalando por el fotograma entero el
		# bicho se queda pequeño en medio de su propio margen. Es la misma cuenta que ya hacia la
		# miniatura de la tira (ver _miniatura_enemigo).
		var pint := Vector2(maxf(float(_fig_rect.size.x), 1.0), maxf(float(_fig_rect.size.y), 1.0))
		var esc: float = minf(zona.y * OCUPA_FIG / pint.y, zona.x * OCUPA_FIG / pint.x)
		esc = minf(esc, minf(ALTO_FIG_MAX / pint.y, ALTO_FIG_MAX / pint.x))
		_fig_sprite.scale = Vector2.ONE * esc
		# SE CENTRA EL FOTOGRAMA, no el pixel pintado dentro de el. Los del horno ya vienen colocados
		# en su cuadro (es lo mismo que hace el escenario de combate, que los planta sin compensar
		# nada): descontar ahi el aire los descolgaba hacia abajo, porque ese aire es justo el sitio
		# que el bicho necesita para las animaciones que se mueven.
		_fig_sprite.position = zona * 0.5
		return

	if _fig_muneco != null:
		# Mismo cálculo que VistaMuneco._recolocar (sin su hueco de barra de mandos: aquí no hay
		# ninguna), mas un tope por ANCHO: la columna puede ser mas estrecha que alta y escalando solo
		# por el alto el muñeco se sale por los lados. El 0.55 es el ancho del muñeco en proporción a
		# su alto, el mismo numero que usa combat.gd para repartir el zoom.
		var esc_m: float = minf(zona.y * OCUPA_FIG / PoseJugador.ALTO_MUNDO,
			zona.x * OCUPA_FIG / (PoseJugador.ALTO_MUNDO * 0.55))
		esc_m = minf(esc_m, ALTO_FIG_MAX / PoseJugador.ALTO_MUNDO)
		_fig_muneco.scale = Vector2.ONE * esc_m
		var alto: float = PoseJugador.ALTO_MUNDO * esc_m
		# EL DIBUJO SE CENTRA EN EL HUECO: el personaje va de -(ALTO_MUNDO - PIES_BAJO_NODO) a
		# +PIES_BAJO_NODO respecto a su nodo, o sea que su nodo NO es su centro.
		_fig_muneco.position = Vector2(zona.x * 0.5, (zona.y - alto) * 0.5
			+ (PoseJugador.ALTO_MUNDO - PoseJugador.PIES_BAJO_NODO) * esc_m)
		return

	# El cuadrado de respaldo: el mayor que quepa, centrado.
	for h in _figura_host.get_children():
		var cr := h as ColorRect
		if cr == null:
			continue
		var lado: float = minf(zona.x, zona.y) * OCUPA_FIG
		cr.size = Vector2(lado, lado)
		cr.position = (zona - cr.size) * 0.5


# El primer fotograma del enemigo, para la tira de retratos. Devuelve null si no tiene sprite
# (los ~15 bichos que siguen siendo un cuadrado de color), y entonces se pinta su color.
func _miniatura_enemigo(c: Combatant) -> Texture2D:
	if c.sprite_res == "" or not ResourceLoader.exists(c.sprite_res):
		return null
	var ed: EnemyData = load(c.sprite_res) as EnemyData
	if ed == null:
		return null
	var frames: SpriteFrames = SpritesEnemigo.frames_de(ed, c.sprite_t)
	if frames == null or not frames.has_animation(&"idle_0"):
		return null
	var tex: Texture2D = frames.get_frame_texture(&"idle_0", 0)
	# RECORTADO A LO QUE SE VE. Los fotogramas del horno traen mucho aire transparente (el sitio
	# que necesitan las animaciones que se mueven), asi que a 72 px el bicho salia como una mota:
	# el jabali y el trent eran ilegibles. Se busca la caja util de la imagen y se pinta solo esa.
	var at := tex as AtlasTexture
	if at == null or at.atlas == null:
		return tex
	var img: Image = tex.get_image()
	if img == null:
		return tex
	var usado: Rect2i = img.get_used_rect()
	if usado.size.x <= 0 or usado.size.y <= 0:
		return tex
	var recorte := AtlasTexture.new()
	recorte.atlas = at.atlas
	recorte.region = Rect2(at.region.position + Vector2(usado.position), Vector2(usado.size))
	return recorte


func _sprite_enemigo(c: Combatant) -> AnimatedSprite2D:
	if c.sprite_res == "" or not ResourceLoader.exists(c.sprite_res):
		return null
	var ed: EnemyData = load(c.sprite_res) as EnemyData
	if ed == null:
		return null
	var frames: SpriteFrames = SpritesEnemigo.frames_de(ed, c.sprite_t)
	if frames == null or not frames.has_animation(&"idle_0"):
		return null
	var sp := AnimatedSprite2D.new()
	sp.sprite_frames = frames
	sp.animation = &"idle_0"
	sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sp.centered = true
	# CUANTO MIDE DE VERDAD, para que _recolocar_figura lo llene al hueco: el fotograma entero (con su
	# aire) y, dentro, la caja del pixel pintado. La escala NO se decide aqui.
	_fig_rect = Rect2i()
	_fig_marco = Vector2.ZERO
	var tex: Texture2D = frames.get_frame_texture(&"idle_0", 0)
	if tex != null and tex.get_height() > 0:
		_fig_marco = tex.get_size()
		_fig_rect = Rect2i(Vector2i.ZERO, Vector2i(tex.get_size()))
		var img: Image = tex.get_image()
		if img != null and img.get_height() > 0:
			var usado: Rect2i = img.get_used_rect()
			if usado.size.x > 0 and usado.size.y > 0:
				_fig_rect = usado
	sp.play()
	return sp


func _pintar_tabs() -> void:
	for h in _tabs_box.get_children():
		h.queue_free()
	var nombres: Array = ["Detalles", "Habilidades", "Historia" if _es_enemigo() else "Equipo"]
	for i in nombres.size():
		var b := Button.new()
		b.text = nombres[i]
		b.toggle_mode = true
		b.button_pressed = (i == _pestana)
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 38)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var j: int = i
		b.pressed.connect(func() -> void:
			_pestana = j
			_refrescar())
		_tabs_box.add_child(b)


# --- Pestaña: Detalles ----------------------------------------------------

func _tab_detalles(c: Combatant) -> void:
	var elem: String = ""
	if c.elemento != Elementos.Elemento.NINGUNO:
		elem = "  %s %s" % [Elementos.icono(c.elemento), Elementos.nombre(c.elemento)]
	MenuScaffold.titulo(_panel, "%s   ·   Niv. %d%s" % [c.nombre, c.level, elem], 18)

	# Vida, energia y maná: las tres arriba y grandes, que es donde se miran.
	_barras(c)

	# Debilidades / resistencias elementales (derivadas, nunca escritas a mano).
	if _es_enemigo():
		var deb: PackedStringArray = []
		var res: PackedStringArray = []
		for e in [Elementos.Elemento.FUEGO, Elementos.Elemento.AGUA, Elementos.Elemento.RAYO]:
			var m: float = Elementos.mult_recibido(e, c)
			if m > 1.01:
				deb.append("%s %s ×%.2f" % [Elementos.icono(e), Elementos.nombre(e), m])
			elif m < 0.99:
				res.append("%s %s ×%.2f" % [Elementos.icono(e), Elementos.nombre(e), m])
		if not deb.is_empty():
			MenuScaffold.fila(_panel, "Debilidades", ", ".join(deb))
		if not res.is_empty():
			MenuScaffold.fila(_panel, "Resistencias", ", ".join(res))

	# Rejilla de stats: para un ALIADO, con el aporte del equipo desglosado en azul.
	if not _es_enemigo():
		_panel.add_child(HSeparator.new())
		_rejilla_stats(c)

	# TODOS los estados, con el texto entero. Reutiliza el derivador del combate (cubre los
	# chips sinteticos -guardia, defender, foco, casteo...- y los estados del catalogo, y
	# funciona igual en el espejo con los pares pre-resueltos).
	_panel.add_child(HSeparator.new())
	var chips: Array = _combat._chips_de(c)
	# EN EL ESPEJO no hay motor detras (los combatientes son maniquies y los chips llegan ya
	# resueltos por red), asi que no se puede saber el signo de cada uno: se enseña el total pelado
	# en vez de un "positivos 0 · negativos 0" que seria mentira.
	if _combat._espejo:
		MenuScaffold.titulo(_panel, "Estados   ·   %d" % chips.size(), 15)
	else:
		var cuenta: Vector3i = _contar_efectos(c)
		var cab: String = "Estados   ·   positivos %d   ·   negativos %d" % [cuenta.x, cuenta.y]
		if cuenta.z > 0:
			cab += "   ·   en curso %d" % cuenta.z
		MenuScaffold.titulo(_panel, cab, 15)
	if chips.is_empty():
		MenuScaffold.nota(_panel, "Sin estado.")
	else:
		for entrada in chips:
			# El cuerpo (el tooltip del chip) YA trae su propia cabecera con icono, nombre y lo que
			# le queda: la etiqueta corta del chip repetiria lo mismo dos lineas mas arriba.
			var cuerpo: String = str(entrada[1]) if entrada.size() > 1 else ""
			if cuerpo.strip_edges() == "":
				cuerpo = str(entrada[0]) if entrada.size() > 0 else ""
			var caja := PanelContainer.new()
			var l := Label.new()
			l.text = cuerpo
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			caja.add_child(l)
			# Teñido con el color del estado, como el chip de la tarjeta: asi se reconoce cual es
			# cual sin leer (los que no salen del catalogo no traen color y se quedan neutros).
			if entrada.size() > 3 and entrada[3] is Color:
				var col: Color = entrada[3]
				var sb := StyleBoxFlat.new()
				sb.bg_color = Color(col.r, col.g, col.b, 0.13)
				sb.border_color = Color(col.r, col.g, col.b, 0.55)
				sb.set_border_width_all(1)
				sb.set_corner_radius_all(4)
				sb.set_content_margin_all(8)
				caja.add_theme_stylebox_override("panel", sb)
			_panel.add_child(caja)


# LAS TRES BARRAS: vida, energia y mana, con los MISMOS colores que la tarjeta del combate (salen
# de MenuScaffold, que es donde viven ahora). Una barra tiene que significar lo mismo en las dos
# pantallas, y ademas asi la vida, el mana y la energia ya no hacen falta como filas en la lista.
#
# Energia y mana solo si las tiene, igual que combat._crear_barras_aliado: un enemigo va a cero en
# las dos y pintarselas seria enseñar dos barras vacias que no significan nada.
func _barras(c: Combatant) -> void:
	MenuScaffold.barra(_panel, MenuScaffold.COLOR_VIDA, c.current_hp, c.max_hp, "%.0f / %.0f", 22, 14)
	if c.max_energy > 0.0:
		MenuScaffold.barra(_panel, MenuScaffold.COLOR_ENERGIA, c.current_energy, c.max_energy,
			"EN  %.0f / %.0f", 15, 11)
	if c.max_mp > 0.0:
		MenuScaffold.barra(_panel, MenuScaffold.COLOR_MANA, c.current_mp, c.max_mp,
			"MP  %.0f / %.0f", 15, 11)


# Ataque total (raw, sin motion value: ese se aplica por golpe) igual que la ficha del menu C.
func _atk_total(c: Combatant) -> float:
	return (c.base_attack + c.ataque_arma) \
		* StatsMath.fuerza_factor(float(c.abilities.fuerza)) * c.status_atk_mult()

func _atk_arma(c: Combatant) -> float:
	return c.ataque_arma * StatsMath.fuerza_factor(float(c.abilities.fuerza)) * c.status_atk_mult()


# LO QUE APORTA EL EQUIPO A LA DEFENSA, medido POR DIFERENCIA y no leyendo `extra_defense`.
#
# No es lo mismo ni de lejos: def_value() mete la defensa de la armadura DENTRO de la base que
# multiplica tu Resistencia, asi que 98 puntos de coraza se convierten en ~504 de defensa real
# cuando tu Resistencia va alta. Enseñar el 98 (que es lo que hacia esta ficha) era mentir por
# un factor de cinco. La diferencia sale siempre bien sea cual sea la formula, que es el mismo
# motivo por el que character_menu mide los aportes de habilidad con _sin_habilidad().
func _def_del_equipo(c: Combatant) -> float:
	var con: float = c.def_value()
	var antes: float = c.extra_defense
	c.extra_defense = 0.0
	var sin_ella: float = c.def_value()
	c.extra_defense = antes
	return con - sin_ella


# El multiplicador que tu Resistencia aplica a TODA la defensa. La formula no se reescribe:
# defense_jugador con base 1.0 devuelve exactamente ese factor.
func _factor_resistencia(c: Combatant) -> float:
	if not c.stats_multiplicativas:
		return 0.0   # los enemigos van por la formula aditiva: aqui ese factor no significa nada
	var ab := Abilities.new()
	ab.resistencia = c.abilities_eff().resistencia
	return StatsMath.defense_jugador(ab, 1.0)


# LA REJILLA de un aliado. Cada stat fisica con su gemela magica JUSTO DEBAJO (ataque/ataque
# magico, defensa/defensa magica, velocidad/vel. recitado) en vez de un bloque "Magia" aparte al
# final: asi se comparan de un vistazo y el mago no tiene que bajar a buscar sus numeros.
#
# El desglose "del equipo" ya no sale aqui -- se mira el total y punto; el reparto sigue estando en
# la lupa. Y la vida tampoco: la enseña la barra de arriba.
#
# NADA puede quedar por debajo del boton de la lupa: es el final de la lista.
func _rejilla_stats(c: Combatant) -> void:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	MenuScaffold.fila(_panel, "Ataque", "%.0f" % _atk_total(c))
	if pj != null:
		MenuScaffold.fila(_panel, "Ataque mágico", "%.0f" % MenuScaffold.dano_magico(pj))
	MenuScaffold.fila(_panel, "Defensa", "%.0f" % c.def_value())
	MenuScaffold.fila(_panel, "Defensa mágica", "%.0f" % StatsMath.magic_jugador(
		c.abilities_eff(), c.base_magic))
	MenuScaffold.fila(_panel, "Velocidad", "%.0f" % c.spd())
	MenuScaffold.fila(_panel, "Vel. recitado", "%.1f" % c.cast_spd())
	# CRITICO FISICO Y MAGICO POR SEPARADO: son cuatro campos distintos en Combatant y el arma
	# magica solo toca los suyos. Con uno solo, un mago no tenia forma de ver su critico de verdad.
	MenuScaffold.fila(_panel, "Prob. crítico", _pct(_crit_fisico(c)))
	MenuScaffold.fila(_panel, "Daño crítico", _crit_dmg_txt(c.crit_dmg))
	MenuScaffold.fila(_panel, "Prob. crít. mágico", _pct(_crit_magico(c)))
	MenuScaffold.fila(_panel, "Daño crít. mágico", _crit_dmg_txt(c.crit_dmg_magico))
	if c.mp_regen_turno > 0.0:
		MenuScaffold.fila(_panel, "Regen maná", "%.2f/turno" % c.mp_regen_turno)
	var lupa := Button.new()
	lupa.text = "⌕  Información de los atributos"
	lupa.focus_mode = Control.FOCUS_NONE
	lupa.custom_minimum_size = Vector2(0, 36)
	lupa.pressed.connect(_abrir_modal_atributos.bind(c))
	_panel.add_child(lupa)


# El critico es un CONTEST (tu Destreza contra la Agilidad de quien recibe el golpe); aqui no hay
# rival delante, asi que se mide contra un maniqui con TUS mismas stats, igual que el menu C.
func _crit_fisico(c: Combatant) -> float:
	return clampf(StatsMath.crit_chance(float(c.abilities.destreza),
		float(c.abilities.agilidad)) + c.crit_bonus_promedio() + c.crit_flat, 0.0, 1.0)


# El magico NO se promedia por manos: loadout_mods ya suma lo del baston y lo de la varita.
func _crit_magico(c: Combatant) -> float:
	return clampf(StatsMath.crit_chance(float(c.abilities.destreza),
		float(c.abilities.agilidad)) + c.crit_magico, 0.0, 1.0)


# UN SOLO formato para el daño critico en toda la pantalla (el de character_menu). Antes la
# rejilla ponia "×1.69" y la lupa "68.8%": el mismo numero dicho de dos maneras.
func _crit_dmg_txt(extra: float) -> String:
	var m: float = StatsMath.CRIT_MULT + extra
	return "×%.2f (+%d%%)" % [m, roundi((m - 1.0) * 100.0)]


func _pct(x: float) -> String:
	return "%.1f%%" % (x * 100.0)


# CUENTA DE EFECTOS. Tiene que cuadrar con las tarjetas que se pintan justo debajo: si sale
# "positivos 0" con una Imbuicion en pantalla, el contador esta mintiendo.
#
# Y ese fue el fallo: contaba SOLO c.statuses (los del catalogo) mas tres sinteticos elegidos a
# mano, mientras que _chips_de pinta ademas la imbuicion, el agotamiento, la provocacion, la carga
# y el casteo. Dos listas paralelas que se separan en cuanto se añade un chip a una sola.
#
# Ahora se enumeran TODOS los que pinta _chips_de, y el total tiene que dar su mismo tamaño (la
# tercera cuenta, 'neutro', es la que lo cuadra: cargar y recitar no son ni bueno ni malo, son
# cosas que estas haciendo). Devuelve (positivos, negativos, neutros).
func _contar_efectos(c: Combatant) -> Vector3i:
	var pos: int = 0
	var neg: int = 0
	var neu: int = 0
	# Los del CATALOGO: el propio estado dice si es un debuff, y el que hace daño por turno lo es
	# aunque no lo diga. Se agrupan por id, igual que los chips (un Sangrado x3 es UN chip).
	var vistos: Dictionary = {}
	for e in c.statuses:
		if vistos.has(e.id()):
			continue
		vistos[e.id()] = true
		if bool(e.d.get("debuff", false)) or e.dot_damage() > 0.0:
			neg += 1
		else:
			pos += 1
	# Los SINTETICOS, en el mismo orden que _chips_de para poder cotejarlos de un vistazo.
	if c.charging != null: neu += 1              # te esta preparando algo: ni bueno ni malo
	if _combat._casteos.has(c): neu += 1         # recitando
	if c.provocar_turnos > 0: pos += 1
	if c.imbue_etiqueta() != "": pos += 1        # imbuicion (la que faltaba)
	if c.en_guardia: pos += 1
	if bool(_combat._defendiendo.get(c, false)) or (c == _combat._player and _combat._player_defending):
		pos += 1
	if int(_combat._lentas.get(c, 0)) > 0: neg += 1   # sin fuelle
	if c.foco_cargas > 0: pos += 1
	return Vector3i(pos, neg, neu)


# --- Pestaña: Habilidades -----------------------------------------------

func _tab_habilidades(c: Combatant) -> void:
	if _es_enemigo():
		if c.habilidades.is_empty():
			MenuScaffold.nota(_panel, "Solo ataque básico.")
			return
		for hab in c.habilidades:
			if hab == null:
				continue
			var tag: String = "Área" if hab.has_method("es_area") and hab.es_area() else "Individual"
			MenuScaffold.titulo(_panel, "%s   [%s]" % [str(hab.nombre), tag], 15)
			var l := Label.new()
			l.text = hab.resumen() if hab.has_method("resumen") else str(hab.get("descripcion"))
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_panel.add_child(l)
			_panel.add_child(HSeparator.new())
		return

	# ALIADO: basico + habilidades de arma + hechizos, con la elegida en detalle.
	var kit: Array = []
	kit.append({"nombre": "Ataque básico", "txt":
		"Golpe con lo que lleves en las manos. No cuesta energía: la recupera."})
	for hab in c.abilities_combate:
		if hab != null:
			kit.append({"nombre": str(hab.nombre),
				"txt": hab.resumen() if hab.has_method("resumen") else ""})
	for sp in c.spells:
		if sp != null:
			kit.append({"nombre": "🔮 " + str(sp.nombre),
				"txt": sp.resumen() if sp.has_method("resumen") else ""})

	var iconos := HFlowContainer.new()
	iconos.add_theme_constant_override("h_separation", 6)
	iconos.add_theme_constant_override("v_separation", 6)
	_panel.add_child(iconos)
	for i in kit.size():
		var b := Button.new()
		b.text = str(kit[i]["nombre"])
		b.toggle_mode = true
		b.button_pressed = (i == _hab_sel)
		b.focus_mode = Control.FOCUS_NONE
		var j: int = i
		b.pressed.connect(func() -> void:
			_hab_sel = j
			_refrescar())
		iconos.add_child(b)
	_panel.add_child(HSeparator.new())

	_hab_sel = clampi(_hab_sel, 0, kit.size() - 1)
	MenuScaffold.titulo(_panel, str(kit[_hab_sel]["nombre"]), 16)
	var det := Label.new()
	det.text = str(kit[_hab_sel]["txt"])
	det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	det.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel.add_child(det)


# --- Pestaña: Historia (enemigo) --------------------------------------

func _tab_historia(c: Combatant) -> void:
	var texto: String = ""
	if c.sprite_res != "" and ResourceLoader.exists(c.sprite_res):
		var ed: EnemyData = load(c.sprite_res) as EnemyData
		if ed != null and "historia" in ed:
			texto = str(ed.historia).strip_edges()
	var l := Label.new()
	l.text = texto if texto != "" else "Sin historia todavía."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if texto == "":
		l.add_theme_color_override("font_color", GRIS)
	_panel.add_child(l)


# --- Pestaña: Equipo (aliado) ---------------------------------------

const SLOTS_EQUIPO := [
	["equipped_main", "Principal"], ["equipped_off", "Secundaria"],
	["equipped_casco", "Casco"], ["equipped_pecho", "Pecho"],
	["equipped_manos", "Manos"], ["equipped_pantalones", "Pantalones"],
	["equipped_botas", "Botas"]]


# Las 7 piezas en lista compacta; al pulsar una se despliegan SUS stats debajo. Antes salia solo el
# nombre pelado ("Yelmo de placas") y no habia forma de saber ni su tier, ni su rareza, ni cuantas
# mejoras llevaba, que es justo lo que decide si una pieza es buena.
func _tab_equipo(c: Combatant) -> void:
	var pj: PersonajeData = Game.pj_de_combatant(c)
	if pj == null:
		MenuScaffold.nota(_panel, "No hay ficha de este personaje.")
		return
	var algo := false
	for par in SLOTS_EQUIPO:
		var slot: String = str(par[0])
		var res: Resource = pj.get(slot)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 34)
		b.toggle_mode = true
		b.button_pressed = (_slot_sel == slot)
		if res == null:
			b.text = "%s:  —" % str(par[1])
			b.disabled = true
			_panel.add_child(b)
			continue
		algo = true
		# item_display_name es el MISMO texto que en el inventario y el menu C: "Yelmo de placas
		# +15  ·  T3 Pristino". Y el color de su rareza, para reconocerla sin leer.
		b.text = "%s:  %s" % [str(par[1]), Game.item_display_name(res)]
		b.add_theme_color_override("font_color", Game.color_rareza_de(res))
		b.add_theme_color_override("font_hover_color", Game.color_rareza_de(res))
		b.pressed.connect(func() -> void:
			_slot_sel = "" if _slot_sel == slot else slot
			_refrescar())
		_panel.add_child(b)
		if _slot_sel == slot:
			_ficha_pieza(res, pj)
	if not algo:
		MenuScaffold.nota(_panel, "Sin equipo: va a puños y sin armadura.")


# Las stats de UNA pieza, por la misma via que el menu de personaje (MenuScaffold.filas_*): asi las
# dos pantallas no pueden decir numeros distintos del mismo objeto.
func _ficha_pieza(res: Resource, pj: PersonajeData) -> void:
	var m: Dictionary = Game.meta_de(res)
	var tier: int = int(m["tier"])
	var rareza: int = int(m["rareza"])
	var mejoras: Dictionary = m["mejoras"]
	var filas: Array = []
	if res is ArmorData:
		filas = MenuScaffold.filas_armadura(res as ArmorData, tier, rareza, mejoras,
			Game.durabilidad_item(res), MenuScaffold.factor_resistencia(pj))
	elif res is WeaponData:
		filas = MenuScaffold.filas_arma(res as WeaponData, tier, rareza, mejoras, pj,
			Game.durabilidad_item(res))
	elif res is ShieldData:
		filas = MenuScaffold.filas_escudo(res as ShieldData, tier, rareza, mejoras, pj)
	elif res is WandData:
		var wd := res as WandData
		var mg: Dictionary = Upgrades.magic_mods(wd.magic_amp, Game.tier_mult(tier), rareza, mejoras)
		filas = [["Tipo", "Varita  ·  mano secundaria"],
			["Ataque mágico", "%.1f" % MenuScaffold.dano_magico(pj, float(mg["magic_amp"]))]]
		filas += MenuScaffold.filas_critico_magico(mg, wd.crit_bonus)
	var caja := PanelContainer.new()
	var vb := VBoxContainer.new()
	caja.add_child(vb)
	for f in filas:
		MenuScaffold.fila(vb, "   " + str(f[0]), str(f[1]), 200)
	MenuScaffold.fila(vb, "   Durabilidad", Game.durabilidad_txt_item(res), 200,
		Game.durabilidad_color(res))
	_panel.add_child(caja)


# --- Modal: Información de los atributos --------------------------------

func _abrir_modal_atributos(c: Combatant) -> void:
	_cerrar_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_modal)

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed:
			_cerrar_modal())
	_modal.add_child(scrim)

	var caja := PanelContainer.new()
	caja.anchor_left = 0.5
	caja.anchor_top = 0.5
	caja.anchor_right = 0.5
	caja.anchor_bottom = 0.5
	caja.offset_left = -320
	caja.offset_right = 320
	caja.offset_top = -260
	caja.offset_bottom = 260
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.10, 0.13, 1.0)
	sb.border_color = Color(1, 1, 1, 0.25)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(16)
	caja.add_theme_stylebox_override("panel", sb)
	_modal.add_child(caja)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 5)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var cab := HBoxContainer.new()
	var cab_lbl := Label.new()
	cab_lbl.text = "Información de los atributos"
	cab_lbl.add_theme_color_override("font_color", AMBAR)
	cab_lbl.add_theme_font_size_override("font_size", 18)
	cab.add_child(cab_lbl)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(hueco)
	var x := Button.new()
	x.text = "✕"
	x.focus_mode = Control.FOCUS_NONE
	x.pressed.connect(_cerrar_modal)
	cab.add_child(x)
	vb.add_child(cab)
	vb.add_child(HSeparator.new())

	# LA LUPA SI mantiene el desglose "lo que pone el equipo", que es justo para lo que existe: la
	# rejilla de fuera se quedo con el total pelado.
	var pj_l: PersonajeData = Game.pj_de_combatant(c)
	MenuScaffold.titulo(vb, "Básicos", 14, GRIS)
	_fila_modal(vb, "PV", "%d" % roundi(c.max_hp), 0.0)
	_fila_modal(vb, "ATQ", "%d" % roundi(_atk_total(c)), _atk_arma(c),
		"El raw antes del motion value: cada golpe le aplica su %. Tu Fuerza lo multiplica, "
		+ "así que el arma pone más de lo que dice su ficha.")
	if pj_l != null:
		_fila_modal(vb, "ATQ mágico", "%d" % roundi(MenuScaffold.dano_magico(pj_l)), 0.0,
			"Medido con el hechizo más básico, para que se pueda comparar con el ataque físico. "
			+ "Un hechizo mejor pega más, en la misma proporción.")
	# El bonus va medido POR DIFERENCIA (lo que de verdad aporta el equipo), no leyendo el campo
	# crudo: la Resistencia multiplica tambien la defensa de la armadura. Ver _def_del_equipo.
	_fila_modal(vb, "DEF", "%d" % roundi(c.def_value()), _def_del_equipo(c),
		"Tu Resistencia multiplica TODA la defensa, la de la armadura incluida.")
	_fila_modal(vb, "DEF mágica", "%d" % roundi(StatsMath.magic_jugador(
		c.abilities_eff(), c.base_magic)), 0.0,
		"Lo que te protege cuando el que lanza el hechizo es el otro.")
	_fila_modal(vb, "VEL", "%d" % roundi(c.spd()), 0.0)
	_fila_modal(vb, "VEL recitado", "%.1f" % c.cast_spd(), 0.0,
		"Lo rápido que recitas, que no es lo rápido que blandes.")
	vb.add_child(HSeparator.new())
	MenuScaffold.titulo(vb, "Atributos avanzados", 14, GRIS)
	# FISICO Y MAGICO POR SEPARADO, y con el MISMO formato que la rejilla de fuera: antes esta
	# lupa decia "68.8%" y la rejilla "×1.69" del mismo numero.
	_fila_modal(vb, "Prob. CRIT", _pct(_crit_fisico(c)), 0.0,
		"Tu Destreza contra la Agilidad de quien recibe el golpe.")
	_fila_modal(vb, "Daño CRIT", _crit_dmg_txt(c.crit_dmg), 0.0)
	_fila_modal(vb, "Prob. CRIT mágico", _pct(_crit_magico(c)), 0.0,
		"El mismo duelo, pero con el crítico que pone tu arma mágica (bastón o varita).")
	_fila_modal(vb, "Daño CRIT mágico", _crit_dmg_txt(c.crit_dmg_magico), 0.0)
	_fila_modal(vb, "Reducción de daño", _pct(c.armor_reduction), 0.0,
		"Se resta SIEMPRE, aparte de la Defensa. Se promedia por la cobertura de cada pieza, "
		+ "así que un set incompleto reduce mucho menos, y el desgaste la baja.")
	if c.crit_resist > 0.001:
		_fila_modal(vb, "Resist. crítico", _pct(c.crit_resist), 0.0)
	_fila_modal(vb, "Resist. estados", _pct(c.resist_estados()), 0.0)
	# El multiplicador crudo se queda SOLO aqui: fuera se enseña ya convertido a daño (ATQ mágico).
	if pj_l != null:
		_fila_modal(vb, "Poder mágico", "×%.2f" % Game.poder_magico(pj_l), 0.0,
			"El multiplicador en crudo. Es lo que convierte el daño de la ficha de un hechizo "
			+ "en el que haces tú.")
	if c.max_mp > 0.0:
		_fila_modal(vb, "Maná máximo", "%.0f" % c.max_mp, 0.0)
	_fila_modal(vb, "Regen. maná", "%.2f/turno" % c.mp_regen_turno, 0.0,
		"Solo con arma mágica o pociones: el maná no se regenera solo.")
	_fila_modal(vb, "Energía máxima", "%d" % roundi(c.max_energy), 0.0,
		"Las habilidades y Defender la gastan; el ataque básico la recupera.")


func _fila_modal(vb: VBoxContainer, etiqueta: String, valor: String, bonus: float,
		ayuda: String = "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var k := Label.new()
	k.text = etiqueta
	k.custom_minimum_size = Vector2(220, 0)
	k.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	row.add_child(k)
	var v := Label.new()
	v.text = valor
	row.add_child(v)
	if absf(bonus) >= 0.5:
		var bl := Label.new()
		bl.text = "  +%d" % roundi(bonus)
		bl.add_theme_color_override("font_color", AZUL_EQUIPO)
		row.add_child(bl)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(hueco)
	if ayuda != "":
		var q := Button.new()
		q.text = "?"
		q.focus_mode = Control.FOCUS_NONE
		q.custom_minimum_size = Vector2(28, 28)
		q.pressed.connect(func() -> void:
			var f: Node = get_tree().get_first_node_in_group("ficha_tactil")
			if f != null and f.has_method("abrir"):
				f.abrir(ayuda, etiqueta))
		row.add_child(q)
	vb.add_child(row)


func _cerrar_modal() -> void:
	if _modal != null and is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null
