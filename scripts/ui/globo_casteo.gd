# ============================================================
#  globo_casteo.gd
#  El BOCADILLO que sale sobre la cabeza de quien esta cantando un hechizo en el mapa.
#
#  Enseña el ESTADO del canto (que hechizo y por que frase va), no las opciones: las cuatro frases
#  del examen son largas -"Que el cielo descargue su furia"- y cuatro de esas apiladas sobre un
#  cuerpo de 32 px taparian media pantalla y se saldrian por los bordes. Las opciones van en la
#  banda de abajo (ver casteo_mapa.gd), que ademas es donde cae el pulgar en el movil.
#
#  Se cuelga de CUALQUIER Node2D: tu personaje, o el avatar de otro humano cuando el que canta es
#  el (multijugador). Por eso no sabe nada de quien canta ni del hechizo: solo pinta lo que le den.
# ============================================================

extends Node2D
class_name GloboCasteo

# A que altura flota sobre el NODO del personaje, en unidades de mundo.
#
# Iba en 34 con el comentario "el cuerpo va de -16 a 16": era una sobra de cuando el personaje era
# un ColorRect de 32x32. Hoy el cuerpo dibujado sube hasta 46 px por encima del nodo (ver
# PoseJugador.ALTO_MUNDO y PIES_BAJO_NODO), asi que con 34 el bocadillo flotaba POR DENTRO del
# personaje y le cruzaba el pecho.
const ALTURA := 54.0

# Un aumento extra que se le aplica ENCIMA del latido. Existe porque el bocadillo del jugador local
# ya no vive en el mundo sino en un CanvasLayer (ver casteo_mapa.gd), donde la camara no lo amplia:
# quien lo pone ahi le pasa el zoom para que se vea del mismo tamaño que siempre.
#
# Va por aqui y no escribiendo 'scale' desde fuera porque este nodo YA escribe 'scale' cada frame
# para el latido -- desde fuera se pisarian el uno al otro y el globo daria tirones.
var escala_base := Vector2.ONE:
	set(v):
		escala_base = v
		_aplicar_escala()
# Latido: cuanto crece y cuantas veces por segundo. Suave a proposito — es un adorno que va a estar
# en pantalla varios segundos seguidos y un rebote fuerte marea.
const LATIDO_AMPLITUD := 0.05
const LATIDO_VEL := 2.6

var _fondo: Panel = null
var _texto: Label = null
var _t: float = 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = 6   # por encima de los cuerpos y del rastro elemental
	_fondo = Panel.new()
	_fondo.add_theme_stylebox_override("panel", _estilo(Color(0.8, 0.8, 1.0)))
	_fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fondo)

	_texto = Label.new()
	_texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_texto.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_texto.add_theme_font_size_override("font_size", 13)
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_texto)


# Que pone y de que color va (el del elemento del hechizo).
func mostrar(texto: String, color: Color) -> void:
	if _texto == null:
		return
	_texto.text = texto
	_texto.add_theme_color_override("font_color", Color(1, 1, 1))
	_fondo.add_theme_stylebox_override("panel", _estilo(color))
	_recolocar()
	visible = true


func ocultar() -> void:
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_aplicar_escala()


# El latido va en la ESCALA del nodo entero, no en el tamaño de la caja: cambiar el tamaño cada
# frame obligaria a recolocar el Label y el texto bailaria dentro del globo. Y va MULTIPLICADO por
# 'escala_base' en vez de sustituirla, que es lo que deja convivir el latido con el zoom de la
# camara cuando el globo vive en una capa.
func _aplicar_escala() -> void:
	var s: float = 1.0 + LATIDO_AMPLITUD * sin(_t * LATIDO_VEL)
	scale = escala_base * s


# La caja se ajusta al texto y se centra sobre la cabeza. El ancho tiene tope: con un nombre de
# hechizo largo, un globo de 400 px tapa a los bichos que vienen, que es justo lo que hay que ver.
const ANCHO_MAX := 210.0

func _recolocar() -> void:
	var fuente: Font = _texto.get_theme_font("font")
	var tam: int = _texto.get_theme_font_size("font_size")
	var ancho: float = minf(ANCHO_MAX, fuente.get_string_size(_texto.text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, tam).x + 16.0)
	var alto: float = float(tam) + 12.0
	_fondo.size = Vector2(ancho, alto)
	_fondo.position = Vector2(-ancho * 0.5, -ALTURA - alto)
	_texto.size = _fondo.size
	_texto.position = _fondo.position


func _estilo(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	# Fondo oscuro con el tinte del elemento: el color tiene que LEERSE de un vistazo (es la pista
	# de que te viene encima) sin que el texto blanco pierda contraste.
	sb.bg_color = Color(color.r * 0.30, color.g * 0.30, color.b * 0.30, 0.92)
	sb.border_color = color
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 8.0
	return sb
