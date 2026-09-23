# ============================================================
#  combat_ficha_objetivo.gd  (tema de la pantalla de combate: combat.ficha_objetivo)
#  LA PESTAÑA DEL ENEMIGO APUNTADO, cuando se pelea en el mapa. Nombre, numero, vida con cifras y
#  sus estados, en SITIO FIJO: el hueco de la columna derecha que queda entre el registro y la barra
#  de acciones.
#
#  POR QUE EN SITIO FIJO Y NO SOBRE EL BICHO. Se probo flotando encima del apuntado y el problema es
#  que la ficha entera mide mas que el bicho: se plantaba justo en el trozo de tablero por el que
#  vienen los demas, que es lo que de verdad estas mirando cuando eliges a quien pegar. En la
#  columna derecha no tapa nada, porque ahi no se pelea.
#
#  Y SOBRE EL BICHO SE QUEDA SU BARRITA, tambien el apuntado. Asi la fila de barras del tablero no
#  cambia de forma segun a quien mires: siempre son barras a la medida de cada cuerpo, y el detalle
#  esta siempre en el mismo sitio.
#
#  NO REUSA EL BLOQUE del apuntado, y es el unico sitio de la pantalla que pinta un combatiente sin
#  reusarlo: no se puede: el bloque solo hay uno y tiene que seguir siendo la barrita de encima del
#  bicho. Lo que si se reusa es todo lo que hay debajo -- _chips_de para saber que estados lleva
#  (que es lo que ademas hace que en el espejo salga lo mismo) y StatusChip para dibujarlos.
# ============================================================
extends RefCounted

const Pantalla = preload("res://scripts/ui/combat.gd")
const Montaje = preload("res://scripts/ui/combat_montaje.gd")

var _pantalla: Pantalla = null

# El aire entre el registro y esta pestaña.
const SEP_REGISTRO := 8.0
const ALTO_BARRA := 17.0
const ALTO_CHIPS := 26.0

var _caja: PanelContainer = null
var _nombre: Label = null
var _hp: ProgressBar = null
var _hp_lbl: Label = null
var _chips: HFlowContainer = null

# Lo ultimo que se pinto, para no rehacer los chips (que se borran y se recrean) en cada fotograma.
var _ultimo_c: Combatant = null
var _ultimos_pares: Array = []


func _init(pantalla: Pantalla) -> void:
	_pantalla = pantalla


func montar() -> void:
	_caja = PanelContainer.new()
	_caja.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# La MISMA columna que el registro y los botones: los tres anclados igual, para que el dia que
	# la columna cambie de ancho no se quede uno de los tres descolgado.
	_caja.offset_left = -Montaje.ANCHO_COL_DER - _pantalla.MARGEN_UI - Tactil.borde.x
	_caja.offset_right = -_pantalla.MARGEN_UI - Tactil.borde.x
	_caja.mouse_filter = Control.MOUSE_FILTER_PASS
	_caja.visible = false   # sin nadie apuntado no hay pestaña
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.08, 0.11, 0.92)   # el mismo fondo que el registro
	sb.set_corner_radius_all(4)
	for lado in ["left", "right", "top", "bottom"]:
		sb.set("content_margin_" + lado, 8.0)
	_caja.add_theme_stylebox_override("panel", sb)
	_pantalla.add_child(_caja)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	_caja.add_child(vb)

	_nombre = Label.new()
	_nombre.clip_text = true
	_nombre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_nombre)

	_hp = ProgressBar.new()
	_hp.show_percentage = false
	_hp.custom_minimum_size = Vector2(0, ALTO_BARRA)
	_hp.self_modulate = Color(1.0, 0.4, 0.4)
	_hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(_hp)
	_hp_lbl = _pantalla.efectos._crear_label_barra(_hp, 13)

	# Mismo envoltorio de alto fijo que en la tarjeta: entrar o salir un estado no mueve nada.
	var chips_wrap := Control.new()
	chips_wrap.custom_minimum_size = Vector2(0, ALTO_CHIPS)
	chips_wrap.clip_contents = true
	chips_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.add_child(chips_wrap)

	_chips = HFlowContainer.new()
	_chips.add_theme_constant_override("h_separation", 4)
	_chips.add_theme_constant_override("v_separation", 4)
	_chips.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_chips.mouse_filter = Control.MOUSE_FILTER_PASS
	chips_wrap.add_child(_chips)


# Cada fotograma, desde la pantalla. Barato: lo unico que se rehace son los chips, y solo cuando de
# verdad cambian.
func refrescar() -> void:
	if not is_instance_valid(_caja):
		return
	var c: Combatant = _apuntado()
	_caja.visible = c != null
	if c == null:
		_ultimo_c = null
		return

	# DEBAJO DEL REGISTRO, midiendolo: el registro se estira y se encoge al desplegarlo (ver
	# combat._alternar_log), asi que su alto no se puede suponer.
	var y: float = _pantalla.MARGEN_UI + Tactil.borde.y
	var log_caja: Control = _pantalla.montaje._log_caja
	if is_instance_valid(log_caja):
		y = log_caja.position.y + log_caja.size.y + SEP_REGISTRO
	_caja.offset_top = y

	var idx: int = _pantalla._enemies.find(c)
	_nombre.text = "%d. %s" % [idx + 1, c.nombre] if idx >= 0 else c.nombre
	# Mismo formato que la barra de la tarjeta (ver combat._update_hp), que es donde se decidio.
	_hp.max_value = c.max_hp
	_hp.value = c.current_hp
	_hp_lbl.text = "%.2f / %.2f" % [c.current_hp, c.max_hp]

	# LOS CHIPS se borran y se recrean enteros, asi que solo cuando cambian de verdad: si no, esto
	# estaria creando y tirando botones sesenta veces por segundo.
	var pares: Array = _pantalla.efectos._chips_de(c)
	if c != _ultimo_c or pares != _ultimos_pares:
		_ultimo_c = c
		_ultimos_pares = pares.duplicate(true)
		for hijo in _chips.get_children():
			hijo.queue_free()
		for par in pares:
			var col: Color = (par[3] as Color) if par.size() > 3 else _pantalla.efectos.CHIP_NEUTRO
			var txt: String = String(par[2]) if par.size() > 2 and String(par[2]) != "" \
				else String(par[0])
			_chips.add_child(StatusChip.crear(txt, col, String(par[1])))


# El enemigo apuntado, o null. VIVO: mismo criterio que el recuadro de seleccion; a un cadaver no se
# le apunta, asi que tampoco tiene pestaña.
func _apuntado() -> Combatant:
	var i: int = _pantalla._target_idx
	if i < 0 or i >= _pantalla._enemies.size():
		return null
	var c: Combatant = _pantalla._enemies[i]
	return c if c.is_alive() else null
