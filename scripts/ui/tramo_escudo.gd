# ============================================================
#  tramo_escudo.gd  (class_name TramoEscudo)
#  EL ESCUDO DE AGUA EN LA BARRA DE VIDA (09/10/2026, set Marea; eligio "burbuja + barra"): un tramo azul encima de la
#  vida, justo detras de lo que tienes. Si vida + escudo pasa del maximo, el tramo se mete hacia dentro desde el final
#  (para que se vea entero). Sin escudo no pinta nada. Es un hijo de la ProgressBar de la vida, del tamaño de ella.
#  Y LA COSTRA DE AMBAR (02/11, el Tocon ambarino): lo mismo en ambar (poner_costra), en un tramo aparte.
# ============================================================
extends Control
class_name TramoEscudo

const AGUA := Color(0.35, 0.75, 1.0, 0.85)
const ESPUMA := Color(0.85, 0.96, 1.0, 0.9)
const AMBAR := Color(0.95, 0.62, 0.15, 0.9)
const AMBAR_BRILLO := Color(1.0, 0.86, 0.5, 0.9)

var _vida: float = 0.0
var _max: float = 1.0
var _escudo: float = 0.0
var _color: Color = AGUA
var _brillo: Color = ESPUMA


# Pone (o actualiza) el tramo en 'barra'. Devuelve el texto que va detras del numero de vida ("" sin escudo).
static func poner(barra: ProgressBar, vida: float, maximo: float, escudo: float) -> String:
	_poner(barra, "TramoEscudo", vida, maximo, escudo, AGUA, ESPUMA)
	return "  +%.0f 💧" % escudo if escudo > 0.0 else ""


static func poner_costra(barra: ProgressBar, vida: float, maximo: float, costra: float) -> String:
	_poner(barra, "TramoCostra", vida, maximo, costra, AMBAR, AMBAR_BRILLO)
	return "  +%.0f 🍯" % costra if costra > 0.0 else ""


static func _poner(barra: ProgressBar, nombre: String, vida: float, maximo: float, escudo: float, color: Color,
		brillo: Color) -> void:
	var t: TramoEscudo = barra.get_node_or_null(nombre) as TramoEscudo
	if t == null:
		if escudo <= 0.0:
			return
		t = TramoEscudo.new()
		t.name = nombre
		t._color = color
		t._brillo = brillo
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		barra.add_child(t)
		barra.move_child(t, 0)   # debajo del numero
	if not is_equal_approx(t._vida, vida) or not is_equal_approx(t._max, maximo) or not is_equal_approx(t._escudo, escudo):
		t._vida = vida
		t._max = maxf(maximo, 1.0)
		t._escudo = maxf(escudo, 0.0)
		t.queue_redraw()


func _draw() -> void:
	if _escudo <= 0.0:
		return
	var w: float = size.x
	var h: float = size.y
	var desde: float = clampf(_vida / _max, 0.0, 1.0)
	var hasta: float = clampf((_vida + _escudo) / _max, 0.0, 1.0)
	if (_vida + _escudo) > _max:
		# No cabe detras: se mete desde el final hacia dentro, del ancho del escudo.
		hasta = 1.0
		desde = clampf(1.0 - _escudo / _max, 0.0, 1.0)
	var r := Rect2(w * desde, 0.0, maxf(w * (hasta - desde), 1.0), h)
	draw_rect(r, _color)
	draw_rect(Rect2(r.position, Vector2(r.size.x, maxf(h * 0.3, 1.0))), _brillo)
