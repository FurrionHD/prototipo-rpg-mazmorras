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
#  tamaño del lienzo del puesto, y esa imagen se coloca como una PiezaPueblo entre el puesto entero y su
#  frente (PlazaSprites._puesto_frente). Tres piezas con el mismo lienzo y la misma huella: PiezaPueblo
#  las sube y las baja a la vez, y entre ellas manda el orden del arbol (puesto, vendedor, frente).
#
#  El aspecto sale de su numero, como el de los guardias: igual en todos los PC.
# ============================================================
extends Node2D
class_name VendedorMercadillo

var indice: int = 0
var puesto: String = ""        # la clave de su puesto ("puesto_pan"...)
var huella: Rect2i = Rect2i()  # la huella de su puesto en casillas

var _vista: SubViewport = null
var _muneco: MunecoJugador = null
var _pieza: PiezaPueblo = null
var _pj: PersonajeData = null


static func crear(i: int, p_puesto: String, p_huella: Rect2i) -> VendedorMercadillo:
	var v := VendedorMercadillo.new()
	v.indice = i
	v.puesto = p_puesto
	v.huella = p_huella
	v.name = "Vendedor_%d" % i
	return v


func _ready() -> void:
	# Para que las piezas estrechas del pueblo se ordenen tambien contra el (ver PiezaPueblo._personajes).
	add_to_group(PiezaPueblo.GRUPO_NPC)
	z_as_relative = false
	z_index = 0
	position = origen_en_puesto(huella)
	_pj = aspecto(indice)
	var tam: Vector2i = PlazaSprites.PIEZAS[puesto]["tam"]
	_vista = SubViewport.new()
	_vista.name = "Vista"
	_vista.size = tam
	_vista.transparent_bg = true
	_vista.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_vista.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vista)
	_muneco = MunecoJugador.new()
	_vista.add_child(_muneco)
	_muneco.position = Vector2(float(tam.x) * 0.5, PlazaSprites.pies_vendedor() - PoseJugador.PIES_BAJO_NODO)
	_muneco.montar(_pj)
	_muneco.tenir(_pj.color, 0.0)
	_muneco.animar(PoseJugador.animacion(Vector2.DOWN, 1, false, false, false))
	_pieza = PiezaPueblo.crear_textura("vendedor_%d" % indice, _vista.get_texture(), tam,
		int(PlazaSprites.PIEZAS[puesto]["pie"]), true)
	add_child(_pieza)
	_pieza.global_position = esquina_puesto(huella)


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
