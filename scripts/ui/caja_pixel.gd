# ============================================================
#  caja_pixel.gd  (06/11, rework del HUD: el estilo "pixel de mazmorra", ver hud_estilo.gd)
#  Un StyleBox que se DIBUJA a pixeles, sin imagen: marco de hierro con su brillo arriba y a la izquierda, su sombra
#  abajo y a la derecha, un contorno casi negro con las esquinas cortadas y, si se pide, un remache en cada esquina.
#  Al no ser una textura sirve a cualquier tamaño sin estirarse ni emborronarse: el "pixel" mide siempre P.
#
#  Dos formas:
#   - MARCO: paneles y botones.
#   - RELLENO: lo que se llena de una barra. Grises (de claro arriba a oscuro abajo) para que el color lo ponga el
#     self_modulate de la barra, como siempre. Se mete P hacia dentro para no pisar el contorno del fondo.
# ============================================================
extends StyleBox

enum Forma { MARCO, RELLENO }

const P := 2.0   # lo que mide un pixel del marco, en unidades de la UI

# @export: duplicate() solo copia lo que se guarda, y sin esto la copia (con) volvia a los colores de serie.
@export var forma: int = Forma.MARCO
@export var contorno := Color(0.04, 0.04, 0.05)
@export var hierro := Color(0.27, 0.28, 0.31)
@export var brillo := Color(0.42, 0.43, 0.47)
@export var sombra := Color(0.16, 0.16, 0.19)
@export var fondo := Color(0.09, 0.09, 0.11)
@export var remache := Color(0.62, 0.58, 0.50)
@export var con_remaches: bool = true
@export var grueso: int = 2   # pixeles de hierro (0 = solo contorno, para el fondo de las barras)


func _init() -> void:
	_margenes()


func _margenes() -> void:
	var m: float = P * float(2 + grueso)
	content_margin_left = m + 4.0
	content_margin_right = m + 4.0
	content_margin_top = m + 2.0
	content_margin_bottom = m + 2.0


func _rect(ci: RID, r: Rect2, c: Color) -> void:
	if r.size.x > 0.0 and r.size.y > 0.0:
		RenderingServer.canvas_item_add_rect(ci, r, c)


func _draw(ci: RID, rect: Rect2) -> void:
	rect = Rect2(rect.position.floor(), rect.size.floor())
	if forma == Forma.RELLENO:
		_relleno(ci, rect.grow(-P))
		return
	var x0: float = rect.position.x
	var y0: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	# El CONTORNO, con las cuatro esquinas cortadas (un pixel): de lejos se lee redondeado.
	_rect(ci, Rect2(x0 + P, y0, w - 2.0 * P, P), contorno)
	_rect(ci, Rect2(x0 + P, y0 + h - P, w - 2.0 * P, P), contorno)
	_rect(ci, Rect2(x0, y0 + P, P, h - 2.0 * P), contorno)
	_rect(ci, Rect2(x0 + w - P, y0 + P, P, h - 2.0 * P), contorno)
	var dentro: Rect2 = rect.grow(-P)
	if grueso > 0:
		var g: float = P * float(grueso)
		_rect(ci, dentro, hierro)
		# Brillo arriba e izquierda, sombra abajo y derecha: la luz viene de arriba, como en el mapa.
		_rect(ci, Rect2(dentro.position, Vector2(dentro.size.x, P)), brillo)
		_rect(ci, Rect2(dentro.position, Vector2(P, dentro.size.y)), brillo)
		_rect(ci, Rect2(dentro.position + Vector2(0, dentro.size.y - P), Vector2(dentro.size.x, P)), sombra)
		_rect(ci, Rect2(dentro.position + Vector2(dentro.size.x - P, 0), Vector2(P, dentro.size.y)), sombra)
		dentro = dentro.grow(-g)
		# El canto de dentro, oscuro: separa el hierro del fondo.
		_rect(ci, dentro, contorno)
		dentro = dentro.grow(-P)
	_rect(ci, dentro, fondo)
	if con_remaches and grueso >= 2 and w >= 8.0 * P and h >= 8.0 * P:
		var l: float = P * 2.0
		for esq in [Vector2(x0 + P, y0 + P), Vector2(x0 + w - P - l, y0 + P),
				Vector2(x0 + P, y0 + h - P - l), Vector2(x0 + w - P - l, y0 + h - P - l)]:
			_rect(ci, Rect2(esq, Vector2(l, l)), remache)
			_rect(ci, Rect2(esq + Vector2(P, P), Vector2(P, P)), remache.darkened(0.45))   # su sombra


# La barra que se llena: clara arriba, el tono en medio y oscura abajo (tres franjas de pixel).
func _relleno(ci: RID, r: Rect2) -> void:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	_rect(ci, r, Color(0.82, 0.82, 0.82))
	_rect(ci, Rect2(r.position, Vector2(r.size.x, minf(P, r.size.y))), Color(1, 1, 1))
	if r.size.y > 2.0 * P:
		_rect(ci, Rect2(r.position + Vector2(0, r.size.y - P), Vector2(r.size.x, P)), Color(0.58, 0.58, 0.58))


# Una copia con otros colores (los estados de un boton).
func con(cambios: Dictionary) -> StyleBox:
	var c = duplicate()
	for k in cambios:
		c.set(k, cambios[k])
	c._margenes()
	return c
