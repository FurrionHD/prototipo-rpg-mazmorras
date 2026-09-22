# ============================================================
#  vendedor_mercadillo.gd  (class_name VendedorMercadillo)
#  EL VENDEDOR DE UN PUESTO DEL MERCADILLO (pedido del usuario el 22/09/2026). De pie DENTRO del puesto,
#  entre el mostrador y el estante, con el mismo muñeco que el jugador (MunecoJugador).
#
#  COMO SE METE DENTRO. El vendedor no cabe "entre" dos capas del puesto por z: sus capas van de -600 a
#  2560 sobre Game.Z_PERSONAJES, igual que las del jugador, y el puesto se ordena contra el jugador con
#  solo dos z (PiezaPueblo: -1 y 3700). Recortarlo tampoco basta: la mitad alta del puesto (la que tapa a
#  quien pasa por detras) lleva tambien el estante, y se le comia la cara (visto en las fotos del visor).
#
#  Asi que el vendedor se vuelve UNA PIEZA MAS DEL PUESTO: su muñeco se pinta en un SubViewport del
#  lienzo del puesto (algo mas ancho, ver MARGEN), y esa imagen se coloca como una PiezaPueblo entre el puesto entero y su
#  frente (PlazaSprites._puesto_frente). Tres piezas con el mismo lienzo y la misma huella: PiezaPueblo
#  las sube y las baja a la vez, y entre ellas manda el orden del arbol (puesto, vendedor, frente).
#
#  El aspecto sale de su numero, como el de los guardias: igual en todos los PC.
#
#  POR EL PUEBLO (de casa al puesto y vuelta, VendedoresPlan) va OTRO muñeco, uno normal colgado de un
#  nodo que se mueve ('_calle'). Cada fotograma se le pregunta al plan donde esta a esta hora y se
#  enseña uno u otro: el de la calle o el de la imagen del puesto.
# ============================================================
extends Node2D
class_name VendedorMercadillo

var indice: int = 0
var puesto: String = ""        # la clave de su puesto ("puesto_pan"...)
var huella: Rect2i = Rect2i()  # la huella de su puesto en casillas

var _vista: SubViewport = null
var _muneco: MunecoJugador = null      # el de dentro del puesto
var _pieza: PiezaPueblo = null
var _calle: Node2D = null              # el que anda por el pueblo
var _muneco_calle: MunecoJugador = null
var _pj: PersonajeData = null
var _anim: String = ""
var _anim_calle: String = ""


static func crear(i: int) -> VendedorMercadillo:
	var v := VendedorMercadillo.new()
	v.indice = i
	v.puesto = VendedoresPlan.VENDEDORES[i]["puesto"]
	v.huella = VendedoresPlan.huella(i)
	v.name = "Vendedor_%d" % i
	return v


func _ready() -> void:
	z_as_relative = false
	z_index = 0
	_pj = aspecto(indice)
	var tam_puesto: Vector2i = PlazaSprites.PIEZAS[puesto]["tam"]
	var tam: Vector2i = tam_puesto + Vector2i(MARGEN * 2, 0)
	_vista = SubViewport.new()
	_vista.name = "Vista"
	_vista.size = tam
	_vista.transparent_bg = true
	_vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vista)
	_muneco = MunecoJugador.new()
	_vista.add_child(_muneco)
	_muneco.montar(_pj)
	_muneco.tenir(_pj.color, 0.0)
	_pieza = PiezaPueblo.crear_textura("vendedor_%d" % indice, _vista.get_texture(), tam,
		int(PlazaSprites.PIEZAS[puesto]["pie"]), true)
	_pieza.ancho_delante = float(tam_puesto.x)
	add_child(_pieza)
	_pieza.global_position = _esquina_vista()
	_calle = Node2D.new()
	_calle.name = "Calle"
	add_child(_calle)
	_muneco_calle = MunecoJugador.new()
	_calle.add_child(_muneco_calle)
	_muneco_calle.z_index = Game.Z_PERSONAJES
	_muneco_calle.montar(_pj)
	_muneco_calle.tenir(_pj.color, 0.0)
	_actualizar()


func _process(_delta: float) -> void:
	_actualizar()


func _actualizar() -> void:
	var e: Dictionary = VendedoresPlan.estado(indice, CicloDia.segundo())
	var visible_: bool = bool(e["visible"])
	var dentro: bool = visible_ and bool(e["dentro"])
	var fuera: bool = visible_ and not dentro
	var anim: String = PoseJugador.animacion(e["mira"], 1, bool(e["moviendose"]), false, false)
	_muneco.visible = dentro
	_calle.visible = fuera
	# En el grupo de los NPC solo mientras anda por la calle: escondido en casa o metido en el puesto no
	# tiene que bajar el tejado de ninguna farola ni de ningun brasero (ver PiezaPueblo._personajes).
	if fuera != _calle.is_in_group(PiezaPueblo.GRUPO_NPC):
		if fuera:
			_calle.add_to_group(PiezaPueblo.GRUPO_NPC)
		else:
			_calle.remove_from_group(PiezaPueblo.GRUPO_NPC)
	if dentro:
		# En px de la imagen del puesto.
		_muneco.position = ((e["pos"] as Vector2) - _esquina_vista()).round()
		if anim != _anim:
			_anim = anim
			_muneco.animar(anim)
	elif fuera:
		_calle.global_position = e["pos"]
		if anim != _anim_calle:
			_anim_calle = anim
			_muneco_calle.animar(anim)


# LA IMAGEN DEL VENDEDOR ES MAS ANCHA QUE EL PUESTO, MARGEN px por cada lado: entra de lado desde la
# casilla del costado (VendedoresPlan.costado_de), y el cambio del muñeco de la calle al de la imagen se
# hace ahi, donde los dos se ven enteros e iguales. Lo que le va tapando al entrar es el poste y el
# mostrador del frente, no el borde de la imagen (con la imagen justa desaparecia de golpe al cambiar).
const MARGEN := 32

func _esquina_vista() -> Vector2:
	return esquina_puesto(huella) - Vector2(float(MARGEN), 0.0)


# ¿Se le puede comprar ahora?
func abierto() -> bool:
	return VendedoresPlan.abierto(indice, CicloDia.segundo())


# La esquina de arriba a la izquierda del lienzo del puesto (la misma cuenta que PiezaPueblo.crear).
static func esquina_puesto(r: Rect2i) -> Vector2:
	var celda: float = float(PuebloPlano.CELDA)
	var tam: Vector2i = PlazaSprites.PIEZAS["puesto_pan"]["tam"]
	return Vector2(float(r.position.x) * celda + (float(r.size.x) * celda - float(tam.x)) * 0.5,
		float(r.end.y) * celda - float(tam.y))


# El origen del vendedor de pie en su hueco (el de un personaje: sus pies PIES_BAJO_NODO por debajo).
static func origen_en_puesto(r: Rect2i) -> Vector2:
	var tam: Vector2i = PlazaSprites.PIEZAS["puesto_pan"]["tam"]
	return esquina_puesto(r) + Vector2(float(tam.x) * 0.5, PlazaSprites.pies_vendedor() - PoseJugador.PIES_BAJO_NODO)


# ============================================================
#  EL ASPECTO: ropa de calle con el mismo reparto que los guardias de paisano (GuardiaPueblo.paisano),
#  con otra semilla para que no salgan gemelos de ningun guardia.
# ============================================================
static func aspecto(i: int) -> PersonajeData:
	var pj: PersonajeData = GuardiaPueblo.paisano(100 + i)
	pj.nombre = "Vendedor"
	return pj
