# ============================================================
#  cuadro_farol.gd
#  EL FAROLILLO del HUD, al lado de la mochila: un farol con SU LLAMA dentro, que se apaga segun se
#  consume el carbon que esta ardiendo.
#
#  Hermano de cuadro_carga.gd (el deposito de peso) y por el mismo motivo: la luz que te queda era un
#  numero escondido en la pestaña "Farolillo" del inventario, o sea que para saber si te ibas a
#  quedar a oscuras habia que abrir un menu y leer. Un farol que se va apagando se lee de reojo
#  mientras andas, que es cuando importa.
#
#  LA LLAMA NO ES NUEVA: es exactamente la de la Quemadura (CapaEstado.pintar_fuego), metida dentro
#  del cristal. Ya son lenguas sueltas con su nucleo caliente y su bamboleo, y reusarla es ademas lo
#  que hace que el fuego del juego se vea IGUAL en todas partes.
# ============================================================

extends Control
class_name CuadroFarol

# El color del fuego segun lo que quede del carbon en curso: de dorado vivo a un rojo mortecino. No
# es adorno -- el COLOR es lo que se lee de lejos, antes que el tamaño de la llama.
const COLOR_VIVA := Color(1.0, 0.78, 0.30)
const COLOR_MURIENDO := Color(0.85, 0.30, 0.10)
# Por debajo de esto el farol PARPADEA: es el aviso de que se acaba, y llega antes que quedarse a
# oscuras de golpe.
const UMBRAL_AGONIA := 0.22
const PARPADEO_VEL := 9.0
# Lo que MIDE la llama, en fraccion del cuadro, de recien prendida a agonizando. El ancho encoge
# menos que el alto a proposito: una llama que mengua igual por los dos lados parece la misma llama
# vista de lejos, y lo que se quiere leer es "queda poca mecha".
const ALTO_MAX := 0.66
const ALTO_MIN := 0.16
const ANCHO_MAX := 0.46
const ANCHO_MIN := 0.22
const BASE_LLAMA := 0.79   # donde se apoya, justo encima de la tapa de abajo del farol

# Lo que se pinta, refrescado por el HUD cada frame (ver hud._process, que es quien sabe de Game).
#   llama  = fraccion del carbon EN CURSO que queda (1 recien prendido, 0 agotado)
#   hay_luz = tengo farolillo puesto y algo ardiendo. Sin esto el farol se apaga del todo.
var llama: float = 0.0
var hay_luz: bool = false

var _fuego: CapaEstado = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS   # es un indicador, pero con tooltip
	# La llama vive en su propio Control, mas estrecho que el farol y pegado al fondo del cristal:
	# CapaEstado dibuja el fuego naciendo de SU borde inferior y ocupando SU ancho, asi que el tamaño
	# de este hijo ES el tamaño de la hoguera. A lo ancho del farol entero saldria una fogata, no la
	# llama de una lampara.
	_fuego = CapaEstado.new()
	_fuego.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fuego)


func _process(_delta: float) -> void:
	_colocar_llama()
	queue_redraw()


# UNA SOLA LLAMA QUE ENCOGE. Lo que cuenta cuanto queda es el TAMAÑO, no la transparencia: una llama
# que se desvanece se lee como "esto se esta apagando en la pantalla" (un fallo de dibujo), y una que
# MENGUA se lee como "queda poca mecha". Por eso el nivel se aplica al tamaño del Control -- CapaEstado
# dibuja la llama a lo alto y ancho del suyo, asi que su tamaño ES el de la llama -- y la opacidad se
# queda casi fija.
#
# Se recoloca cada frame porque el HUD reescala el cuadro con la fila del grupo (ver hud.recolocar).
func _colocar_llama() -> void:
	if _fuego == null:
		return
	_fuego.fuego_unica = true   # un farol tiene UNA mecha, no una hoguera de trece lenguas
	if not hay_luz:
		_fuego.size = Vector2.ZERO
		_fuego.pintar_fuego(COLOR_MURIENDO, 0.0)
		return
	var q: float = clampf(llama, 0.0, 1.0)
	# De casi llenar el cristal (recien prendido) a un cabo de mecha. No baja de ALTO_MIN: una llama
	# de un pixel no se ve, y mientras quede carbon SIGUE dando luz -- de que se acaba avisa el
	# parpadeo, no la desaparicion.
	var alto: float = size.y * lerpf(ALTO_MIN, ALTO_MAX, q)
	var ancho: float = size.x * lerpf(ANCHO_MIN, ANCHO_MAX, q)
	_fuego.size = Vector2(ancho, alto)
	_fuego.position = Vector2((size.x - ancho) * 0.5, size.y * BASE_LLAMA - alto)
	var fuerza: float = 1.0
	if q < UMBRAL_AGONIA:
		var t: float = float(Time.get_ticks_msec()) / 1000.0
		fuerza = 0.55 + 0.45 * absf(sin(t * PARPADEO_VEL))
	_fuego.pintar_fuego(COLOR_MURIENDO.lerp(COLOR_VIVA, q), fuerza)


# EL FAROL: la caja de cristal con su asa arriba y su base. Se dibuja a mano, como el deposito de la
# mochila, para que los dos cuadros del HUD se lean como pareja.
func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# El cristal: mas oscuro apagado que encendido, para que el farol muerto no parezca lleno de luz.
	var q: float = clampf(llama, 0.0, 1.0) if hay_luz else 0.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.10, 0.11, 0.14, 0.85), true)
	# El RESPLANDOR dentro del cristal, detras de la llama: es lo que hace que el farol ILUMINE en vez
	# de tener un fuego pegado.
	#
	# NO es un draw_circle: un circulo tiene BORDE, y un borde duro no es un resplandor -- se lee como
	# un disco de pintura marron detras del fuego (probado, y cantaba muchisimo). El degradado se hace
	# a mano, con anillos concentricos que van sumando alfa hacia el centro. Es la unica forma de tener
	# caida suave sin meter una textura ni un shader por un adorno de 64 px.
	if hay_luz and q > 0.0:
		var centro := Vector2(w * 0.5, h * 0.60)
		var r: float = minf(w, h) * (0.30 + 0.16 * q)
		var col: Color = COLOR_MURIENDO.lerp(COLOR_VIVA, q)
		var capas := 7
		for i in capas:
			# De fuera adentro. El alfa por anillo es bajo a proposito: se ACUMULAN, y la suma de los
			# de dentro es lo que da el nucleo brillante.
			var u: float = 1.0 - float(i) / float(capas)
			draw_circle(centro, r * u, Color(col.r, col.g, col.b, 0.045 + 0.030 * q))

	# EL ASA, arriba: un arco de dos trazos. Sin ella el cuadro es una caja con fuego, no un farol.
	# Las piezas de metal van FINAS: con tapas gordas el farol se leia como una estanteria.
	var metal := Color(0.72, 0.74, 0.80, 0.9)
	var asa_y: float = h * 0.12
	var grosor: float = maxf(1.0, h * 0.022)
	draw_line(Vector2(w * 0.36, asa_y), Vector2(w * 0.5, h * 0.04), metal, grosor, true)
	draw_line(Vector2(w * 0.5, h * 0.04), Vector2(w * 0.64, asa_y), metal, grosor, true)
	# El SOMBRERO y la BASE: las dos tapas metalicas entre las que va el cristal.
	draw_rect(Rect2(Vector2(w * 0.20, asa_y), Vector2(w * 0.60, h * 0.05)), metal, true)
	draw_rect(Rect2(Vector2(w * 0.16, h * 0.80), Vector2(w * 0.68, h * 0.06)), metal, true)
	# Los dos MONTANTES del cristal, de tapa a tapa.
	var barra := Color(0.55, 0.57, 0.63, 0.8)
	draw_line(Vector2(w * 0.24, h * 0.17), Vector2(w * 0.24, h * 0.80), barra, 1.0, true)
	draw_line(Vector2(w * 0.76, h * 0.17), Vector2(w * 0.76, h * 0.80), barra, 1.0, true)
	# Y el marco del cuadro al final, encima de todo, igual que en el deposito de la mochila.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.78, 0.85, 0.9), false, 1.0)
