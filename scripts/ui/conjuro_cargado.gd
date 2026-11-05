# ============================================================
#  conjuro_cargado.gd
#  EL CONJURO RECITADO EN EL MAPA Y AUN SIN SOLTAR (04/11, el jefe: "poder castear la frase entera pero que no se tire
#  directo, si no que luego puedas moverte con el hechizo ya cargado y seleccionar donde tirarlo clicando, aparecera el
#  area del hechizo. Se tirara instant al llegar tu turno, lo de siempre").
#
#  1er clic: sale su area y sigue al raton, y se puede seguir andando.
#  2o clic:  con algun enemigo dentro, se abre la pelea con ese sitio sellado y el conjuro sale solo en tu turno
#            (combat_magia._mostrar_disparo). Sin nadie dentro no pasa nada: no hay pelea que abrir y sigue cargado.
#  Clic derecho o Esc: se guarda el area.
#
#  La nota de verdad vive en Game (viaja con la ficha a cualquier pelea, y vuelve si no te dejan entrar); esto solo la
#  pinta y la apunta, y se quita sola cuando la nota se va o entras en una pelea.
# ============================================================
extends Node2D

const CombatTactico = preload("res://scripts/ui/combat_tactico.gd")

# Sin respuesta a la pelea pedida en este rato (ya la tiene otro...), el sitio se olvida y vuelves a elegir.
const ESPERA_PELEA := 5.0
const COLOR_AREA := Color(0.45, 0.85, 1.0)
const ALTO_LETRERO := 112.0

var _jugador: Node2D = null
var _spell: SpellData = null
var _ab: AbilityData = null
var _apuntando: bool = false
var _forma: RefCounted = null
var _pillado: Node2D = null
var _esperando_t: float = 0.0
var _letrero: Label = null
var _letrero_visto: String = ""


func setup(jugador: Node2D) -> void:
	_jugador = jugador
	_spell = Game.conjuro_cargado()
	if _spell != null:
		_ab = CombatTactico.crear_huella_apunte(_spell)


func _ready() -> void:
	top_level = true
	z_as_relative = false
	z_index = ArenaCombate.Z_SUELO
	global_position = Vector2.ZERO
	var capa := CanvasLayer.new()
	capa.layer = 5
	add_child(capa)
	_letrero = Label.new()
	_letrero.add_theme_font_size_override("font_size", 18)
	_letrero.add_theme_color_override("font_outline_color", Color.BLACK)
	_letrero.add_theme_constant_override("outline_size", 6)
	_letrero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_letrero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_letrero.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_letrero.offset_top = -ALTO_LETRERO
	_letrero.offset_bottom = -ALTO_LETRERO + 28.0
	capa.add_child(_letrero)
	_actualizar_letrero()
	# Su circulo sigue a tus pies (si la nota vuelve de una pelea que no ha sido, se levanta otra vez).
	CirculoMagico.en_cuerpo(_jugador, _spell, _spell.longitud(), CirculoMagico.Fin.SIGUE)
	Net.jugadores.anunciar_circulo(_spell.resource_path, _spell.longitud(), CirculoMagico.Fin.SIGUE)


func _process(delta: float) -> void:
	if Game.conjuro_cargado() == null or Game.conjuro_cargado() != _spell or Game.combate_activo():
		_cerrar()
		return
	if _esperando_t > 0.0:
		_esperando_t -= delta
		if _esperando_t <= 0.0:
			Game.sitio_de_conjuro(null)
	if _apuntando:
		mover_area(get_global_mouse_position())
	_actualizar_letrero()


func _unhandled_input(event: InputEvent) -> void:
	if _esperando_t > 0.0:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		match (event as InputEventMouseButton).button_index:
			MOUSE_BUTTON_LEFT:
				if _apuntando:
					elegir_sitio(get_global_mouse_position())
				else:
					sacar_area(get_global_mouse_position())
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_RIGHT:
				if _apuntando:
					guardar_area()
					get_viewport().set_input_as_handled()
	elif _apuntando and event.is_action_pressed(&"cancelar"):
		guardar_area()
		get_viewport().set_input_as_handled()


func esta_apuntando() -> bool:
	return _apuntando


func sacar_area(punto: Vector2) -> void:
	_apuntando = true
	mover_area(punto)


func guardar_area() -> void:
	_apuntando = false
	_forma = null
	_pillado = null
	queue_redraw()


func mover_area(punto: Vector2) -> void:
	_forma = forma_en(_spell, _ab, _jugador, punto)
	_pillado = enemigo_en(_forma, _jugador)
	queue_redraw()


# El clic que elige: con alguien dentro, a la pelea con el sitio sellado. Devuelve si se abre.
func elegir_sitio(punto: Vector2) -> bool:
	mover_area(punto)
	if _pillado == null or not _pillado.has_method("atacado_por_jugador"):
		_toast("No hay nadie ahí: %s sigue cargado." % _spell.nombre)
		return false
	Game.sitio_de_conjuro(punto)
	if not bool(_pillado.atacado_por_jugador(0.0)):
		Game.sitio_de_conjuro(null)
		_toast("No puedes entrar en esa pelea ahora mismo.")
		return false
	if _jugador.has_method("_arrancar_golpe"):
		_jugador._arrancar_golpe()   # el gesto de lanzarlo
	guardar_area()
	_esperando_t = ESPERA_PELEA
	return true


# La huella desde mis pies hacia 'punto'. Los mismos numeros que en la pelea (CombatTactico.forma_de).
static func forma_en(spell: SpellData, ab: AbilityData, jugador: Node2D, punto: Vector2) -> RefCounted:
	var pies: Vector2 = jugador.global_position + Vector2(0.0, PoseJugador.PIES_BAJO_NODO)
	var pisa: float = Cuerpos.caja_de(jugador).size.x * CombatTactico.PISA
	var w: WeaponData = Game.lider().equipped_main as WeaponData
	var alcance: float = maxf(w.alcance_real() if w != null else 0.0, CombatTactico.ALCANCE_MINIMO)
	var f = CombatFormas.de_habilidad_mapa(ab, pies, pisa, alcance, punto)
	f.cunas = spell.forma_cunas
	return f


# El enemigo del piso que pilla esa huella: el mas cercano a su centro, a la vista (null si nadie).
static func enemigo_en(f: RefCounted, jugador: Node2D) -> Node2D:
	var mejor: Node2D = null
	var mejor_d: float = INF
	for e in PisoVivo.nodos_de(jugador, &"enemy"):
		if not is_instance_valid(e) or not (e is Node2D) or not (e as Node2D).is_visible_in_tree():
			continue
		var r: Rect2 = Cuerpos.caja_de(e)
		if not f.toca(r):
			continue
		if jugador.has_method("_vision_libre") and not jugador._vision_libre((e as Node2D).global_position):
			continue
		var d: float = r.get_center().distance_squared_to(f.centro)
		if d < mejor_d:
			mejor_d = d
			mejor = e
	return mejor


func _draw() -> void:
	if _forma != null:
		CombatFormas.dibujar(_forma, self, Color(COLOR_AREA, 0.85))


func _actualizar_letrero() -> void:
	var txt: String = "🔮 %s cargado · Clic: elegir dónde cae · Mantener atacar: deshacerlo" % _spell.nombre
	if _apuntando:
		var pilla: String = "no pilla a nadie" if _pillado == null else "pilla enemigos"
		txt = "🔮 %s: %s · Clic: lanzarlo · Clic derecho: guardar el área" % [_spell.nombre, pilla]
	if txt == _letrero_visto:
		return
	_letrero_visto = txt
	_letrero.text = txt
	Net.jugadores.anunciar_canto("🔮 %s" % _spell.nombre, _color())


func _color() -> Color:
	return Elementos.color(_spell.elemento) if Elementos.tiene_color(_spell.elemento) else Color(0.75, 0.75, 0.9)


func _toast(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast(texto)


# Se va la nota (lanzado, deshecho o a la pelea): su circulo se apaga aqui y en las otras pantallas. Dentro de la pelea
# ya lo pinta CombatTactico.
func _cerrar() -> void:
	if is_instance_valid(_jugador):
		CirculoMagico.en_cuerpo(_jugador, _spell, 0, CirculoMagico.Fin.APAGA)
	if _spell != null:
		Net.jugadores.anunciar_circulo(_spell.resource_path, 0, CirculoMagico.Fin.APAGA)
	Net.jugadores.anunciar_canto("", Color.WHITE)
	queue_free()
