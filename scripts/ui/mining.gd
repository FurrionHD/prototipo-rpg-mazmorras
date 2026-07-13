# ============================================================
#  mining.gd
#  Minijuego de MINERIA (veta -> pico -> FUERZA). Nada que ver con el del cristal:
#  aqui no hay marcador que rebota, hay una CARGA que tu decides cuando soltar.
#
#  MANTIENES ESPACIO: la barra de carga sube. SUELTAS: golpeas.
#    - Sueltas dentro de la franja optima -> GOLPE BUENO: la veta cede (+1 de progreso).
#    - Te quedas corto             -> GOLPE FLOJO: el pico rebota. NO avanza nada.
#    - Te pasas (o la carga llena)  -> GOLPE BRUTO: la veta cede igual, pero AGRIETAS el
#      mineral (+1 grieta). Eso es lo que te destroza el botin.
#  Y la veta NO aguanta golpes infinitos: tienes un MARGEN de golpes por encima de los que
#  hacen falta, y al pasarte la roca se viene abajo entera (pieza rota). Sin ese margen, el
#  golpe flojo seria gratis y bastaba con dar toquecitos hasta sacar la pieza intacta.
#  La franja se re-sortea tras cada golpe: la veta no cede dos veces por el mismo sitio.
#
#  La FUERZA no golpea por ti: hace la franja mas ANCHA y mas BAJA (un brazo fuerte no
#  necesita cargar tanto) y baja los golpes necesarios. Sigues teniendo que soltar tu.
#  Se crea por codigo (sin .tscn), como extraction.gd.
# ============================================================

extends Control

signal mineria_finished(item: MaterialItem)

enum { RUNNING, FINISHED }

var _material: MaterialData = null
var _golpes_necesarios: int = 3
var _opt_ini: float = 0.5      # inicio de la franja optima EN ESTE GOLPE (0..1)
var _opt_base: float = 0.5     # donde la pone la dificultad; el sorteo se mueve ALREDEDOR
var _opt_ancho: float = 0.22
var _carga_vel: float = 1.0    # de 0 a 1 en 1/_carga_vel segundos

var _carga: float = 0.0
var _cargando: bool = false
var _progreso: float = 0.0
var _grietas: int = 0
var _golpes: int = 0
var _ultimo: String = ""       # texto del ultimo golpe (para el HUD)
var _state: int = RUNNING
var _result: MaterialItem = null
var _press_was: bool = false

# Golpes de MARGEN por encima de los necesarios: lo que la veta aguanta antes de venirse
# abajo. Es lo que le pone precio a fallar (y lo que impide sacar la pieza a toquecitos).
const GOLPES_MARGEN := 4
# Grietas a las que la pieza se parte del todo.
const GRIETAS_ROTO := 3


func setup(material: MaterialData, golpes: int, opt_ini: float, opt_ancho: float,
		carga_vel: float) -> void:
	_material = material
	_golpes_necesarios = maxi(1, golpes)
	_opt_ini = opt_ini
	_opt_base = opt_ini
	_opt_ancho = opt_ancho
	_carga_vel = carga_vel


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sortear_franja()


func _process(delta: float) -> void:
	var pressed: bool = Input.is_key_pressed(KEY_SPACE)

	if _state == FINISHED:
		# Se sale con una pulsacion NUEVA (no con la que acabo de romper la veta).
		if pressed and not _press_was:
			mineria_finished.emit(_result)
			queue_free()
		_press_was = pressed
		return

	if pressed:
		_cargando = true
		_carga += _carga_vel * delta
		if _carga >= 1.0:
			# Cargar hasta reventar es una decision, y se paga: golpe bruto forzado.
			_carga = 1.0
			_golpear()
	elif _cargando:
		_golpear()   # has soltado: ahi va el golpe

	_press_was = pressed
	queue_redraw()


func _golpear() -> void:
	_cargando = false
	_golpes += 1
	if _carga < _opt_ini:
		_ultimo = "Golpe flojo: el pico rebota"   # no avanza: has gastado un golpe y ya
	elif _carga <= _opt_ini + _opt_ancho:
		_progreso += 1.0
		_ultimo = "¡Golpe limpio!"
	else:
		_progreso += 1.0
		_grietas += 1
		_ultimo = "Golpe bruto: agrietas el mineral"

	_carga = 0.0
	_sortear_franja()

	# ¿Ya la tienes? (esto va PRIMERO: el golpe que la abre cuenta aunque sea el ultimo)
	if _progreso >= float(_golpes_necesarios):
		_terminar()
		return
	# Ya esta agrietada del todo, o la has machacado tanto que se viene abajo: escombro.
	if _grietas >= GRIETAS_ROTO or _golpes >= _golpes_max():
		_grietas = GRIETAS_ROTO   # se derrumba: no hay pieza que sacar
		_terminar()


# Golpes que aguanta la veta antes de derrumbarse.
func _golpes_max() -> int:
	return _golpes_necesarios + GOLPES_MARGEN


func _terminar() -> void:
	_state = FINISHED
	var item := MaterialItem.new()
	item.data = _material
	if _grietas >= GRIETAS_ROTO:
		item.calidad = MaterialItem.Calidad.ROTO
	elif _grietas == 0:
		item.calidad = MaterialItem.Calidad.INTACTO
	elif _grietas == 1:
		item.calidad = MaterialItem.Calidad.NORMAL
	else:
		item.calidad = MaterialItem.Calidad.DANADO
	_result = item
	queue_redraw()


func _sortear_franja() -> void:
	# El ancho y la altura MEDIA los fija la dificultad (Game); aqui la franja solo se mueve
	# un poco arriba y abajo de esa media. Se sortea alrededor de _opt_base y NO de la franja
	# anterior: si no, cada golpe la empujaria un poco mas y acabaria pegada a un extremo.
	var margen: float = 0.12
	var ini: float = _opt_base + randf_range(-margen, margen)
	_opt_ini = clampf(ini, 0.05, 1.0 - _opt_ancho - 0.02)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.1, 0.08, 0.07, 1.0))

	var font: Font = ThemeDB.fallback_font
	var nombre: String = _material.nombre if _material != null else "Veta"

	# --- BARRA DE CARGA: VERTICAL, y a proposito (que no se confunda con la del cristal) ---
	var bar_w: float = 64.0
	var bar_h: float = h * 0.5
	var bar_x: float = w * 0.5 - bar_w * 0.5
	var bar_y: float = h * 0.5 - bar_h * 0.35

	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.22, 0.2, 0.19))
	# La franja optima (se dibuja de abajo a arriba: carga 0 = abajo).
	var zy: float = bar_y + bar_h * (1.0 - _opt_ini - _opt_ancho)
	draw_rect(Rect2(bar_x, zy, bar_w, bar_h * _opt_ancho), Color(0.95, 0.7, 0.2))
	# Por encima de la franja: zona de PASARSE (rojiza: es la que te agrieta la pieza).
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h * (1.0 - _opt_ini - _opt_ancho)),
		Color(0.7, 0.2, 0.15, 0.28))
	# Carga actual.
	var cy: float = bar_y + bar_h * (1.0 - _carga)
	draw_rect(Rect2(bar_x - 6.0, cy - 2.0, bar_w + 12.0, 4.0), Color.WHITE)

	# --- INTEGRIDAD de la veta (cuanto le queda) ---
	var pw: float = 260.0
	var px: float = w * 0.5 - pw * 0.5
	var py: float = bar_y + bar_h + 34.0
	draw_rect(Rect2(px, py, pw, 14.0), Color(0.25, 0.25, 0.28))
	var frac: float = clampf(_progreso / float(_golpes_necesarios), 0.0, 1.0)
	draw_rect(Rect2(px, py, pw * frac, 14.0), Color(0.4, 0.75, 0.95))

	draw_string(font, Vector2(px - 60.0, bar_y - 70.0), "Picando: %s" % nombre,
		HORIZONTAL_ALIGNMENT_CENTER, pw + 120.0, 22)
	if _state == RUNNING:
		draw_string(font, Vector2(px - 60.0, bar_y - 44.0),
			"MANTÉN ESPACIO para cargar y SUÉLTALO en la franja",
			HORIZONTAL_ALIGNMENT_CENTER, pw + 120.0, 16)
		draw_string(font, Vector2(px - 60.0, py + 36.0),
			"Golpes: %d/%d   ·   Grietas: %d/%d   ·   %s" % [
				_golpes, _golpes_max(), _grietas, GRIETAS_ROTO, _ultimo],
			HORIZONTAL_ALIGNMENT_CENTER, pw + 120.0, 16)
	else:
		var txt: String = "El mineral se deshace en escombro: lo has perdido" if _result.se_pierde() \
			else "Sacas %s (%s)" % [nombre, _result.calidad_texto()]
		draw_string(font, Vector2(px - 60.0, py + 36.0), txt + "   ·   ESPACIO para continuar",
			HORIZONTAL_ALIGNMENT_CENTER, pw + 120.0, 16)
