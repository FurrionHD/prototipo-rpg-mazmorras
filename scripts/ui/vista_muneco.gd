# ============================================================
#  vista_muneco.gd  (class_name VistaMuneco)
#  EL PERSONAJE, VIVO, DENTRO DE UN RECUADRO DE INTERFAZ.
#
#  Existe porque elegir el pelo y la ropa mirando un cuadrado de color es elegir a ciegas: lo que se
#  esta decidiendo es una SILUETA, y una silueta no se juzga quieta ni de frente. Por eso esto no es
#  una miniatura -- gira por las ocho direcciones y anda.
#
#  Lo que enseña es el MunecoJugador de verdad, con las mismas capas horneadas y el mismo shader que
#  el del mapa. No es una aproximacion del personaje: es el personaje.
#
#  TRES COSAS QUE NO SON OBVIAS:
#
#  1. UN Node2D DENTRO DE UN Control NO SE RECORTA SOLO. El muñeco se dibuja a tamaño de mundo (60
#     unidades de alto) y hay que AMPLIARLO para llenar el recuadro; sin 'clip_contents' se sale por
#     encima y se cuela por debajo del resto de la pantalla.
#
#  2. LOS MENUS PAUSAN EL ARBOL. El muñeco lleva su propio reloj en _process, asi que sin
#     PROCESS_MODE_ALWAYS la vista previa saldria CONGELADA en el primer fotograma -- y parecerian
#     rotas las animaciones, no la pausa.
#
#  3. REMONTAR SOLO CUANDO CAMBIA LA LISTA DE CAPAS. De eso ya se encarga MunecoJugador.montar (mira
#     la firma de claves), y por eso aqui se le puede llamar en cada toque del ColorPicker sin
#     reconstruir nada: arrastrar el color repinta, cambiar de peinado remonta.
# ============================================================

extends Control
class_name VistaMuneco

const FONDO := Color(0.10, 0.11, 0.14)
const BORDE := Color(0.30, 0.33, 0.40)
# Cuanto del alto del recuadro ocupa el personaje. Deja aire arriba (el pelo alto y el arma que
# algun dia se levante) y abajo (la sombra de contacto).
const OCUPA := 0.80

var _muneco: MunecoJugador = null
var _dir: int = 0                 # 0 = S, en el orden de SpriteLienzo.dir8
var _andando: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(240, 300)
	clip_contents = true
	# Los menus pausan el arbol: sin esto la vista previa sale congelada (ver la cabecera).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = FONDO
	fondo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fondo)

	_muneco = MunecoJugador.new()
	add_child(_muneco)

	# Los mandos, abajo: girar a los dos lados y andar. Van DENTRO de la vista y no en la pantalla
	# que la usa para que quien la ponga no tenga que montarlos (y para que sean iguales en las dos
	# pantallas que la van a usar: la creacion y el aspecto del hogar).
	var barra := HBoxContainer.new()
	barra.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	barra.offset_top = -34
	barra.alignment = BoxContainer.ALIGNMENT_CENTER
	barra.add_theme_constant_override("separation", 6)
	add_child(barra)

	var izq := Button.new()
	izq.text = "◀"
	izq.tooltip_text = "Girarlo a la izquierda"
	izq.pressed.connect(func(): girar(-1))
	barra.add_child(izq)

	var andar := CheckButton.new()
	andar.text = "Andar"
	andar.toggled.connect(func(v: bool):
		_andando = v
		_refrescar_anim())
	barra.add_child(andar)

	var der := Button.new()
	der.text = "▶"
	der.tooltip_text = "Girarlo a la derecha"
	der.pressed.connect(func(): girar(1))
	barra.add_child(der)

	resized.connect(_recolocar)
	_recolocar()
	_refrescar_anim()


# Enseña a ESTE personaje. Se puede llamar en cada toque: si solo ha cambiado un color, no
# reconstruye nada (ver MunecoJugador.montar).
func mostrar(pj: PersonajeData) -> void:
	if _muneco == null or pj == null:
		return
	_muneco.montar(pj)
	# El color de respaldo para las capas que no traigan el suyo, y el acabado de la FOTO: los dos
	# mandos viejos son de la cara (ver PersonajeData.metalico).
	_muneco.tenir(pj.color, 0.0)
	_muneco.poner_cara(pj.textura())
	_refrescar_anim()


func girar(paso: int) -> void:
	_dir = posmod(_dir + paso, 8)
	_refrescar_anim()


func _refrescar_anim() -> void:
	if _muneco == null or not _muneco.hay_dibujo():
		return
	# 'modo' 1 = andar de pie, que es el del mapa. La pose de sigilo aqui no dice nada.
	_muneco.animar(PoseJugador.animacion(PoseJugador.DIR_VECS[_dir], 1, _andando))


# El muñeco se dibuja en unidades de mundo con los pies en su nodo, asi que se le pone la escala que
# llene el recuadro y se le planta el nodo donde tienen que caer los pies.
#
# LOS PIES SE COLOCAN A MANO, y no centrando el cuerpo: el personaje esta casi entero POR ENCIMA de
# su nodo (la coronilla a -46 y los pies a +14, ver PoseJugador.CAJA_CUERPO), asi que centrarlo lo
# hunde -- se salia por debajo del recuadro y la barra de mandos le cruzaba las piernas.
#
# El hueco de abajo es de la BARRA (34 px) mas un respiro para la sombra de contacto.
const HUECO_BARRA := 44.0

func _recolocar() -> void:
	if _muneco == null:
		return
	var util: float = maxf(40.0, size.y - HUECO_BARRA)
	var esc: float = maxf(1.0, util * OCUPA / PoseJugador.ALTO_MUNDO)
	_muneco.scale = Vector2.ONE * esc
	# EL DIBUJO SE CENTRA EN EL HUECO, y hay que hacer la cuenta entera: el personaje va de
	# -(ALTO_MUNDO - PIES_BAJO_NODO) a +PIES_BAJO_NODO respecto a su nodo, o sea que su nodo NO es su
	# centro. Aqui habia media PIES_BAJO_NODO en vez del alto entero y a esta escala eso son 40 px de
	# mas hacia abajo: los pies se metian detras de la barra de mandos.
	var alto: float = PoseJugador.ALTO_MUNDO * esc
	_muneco.position = Vector2(size.x * 0.5,
		(util - alto) * 0.5 + (PoseJugador.ALTO_MUNDO - PoseJugador.PIES_BAJO_NODO) * esc)
