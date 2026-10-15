# ============================================================
#  pieza_pueblo.gd  (class_name PiezaPueblo)
#  Una pieza del pueblo con ALTURA (casa, columna, verja, farola, puesto) colocada sobre su huella, que se
#  ordena contra quien anda alrededor POR LA LINEA DE SU SUELO.
#
#  EL PROBLEMA. El proyecto no usa y_sort, y no puede usarlo sin mas: el muñeco del jugador ordena sus
#  capas con z (ver muneco_jugador.gd), asi que un y_sort solo ordenaria dentro del mismo z.
#
#  LA SALIDA (12/10, C2 del playtest 11/10). Game._ordenar_munecos ya reparte cada fotograma una BANDA de z
#  a cada muñeco y a cada enemigo por la altura de sus pies; las piezas entran en ese MISMO orden, enteras,
#  por su linea_suelo(): quien tiene los pies por encima (detras) queda tapado por la pieza entera, y quien
#  los tiene por debajo (delante) se pinta encima de ella entera. Cada uno en su sitio aunque haya uno
#  delante y otro detras a la vez.
#
#  Antes la pieza se partia en dos por la base de su huella: lo de abajo SIEMPRE por debajo de todos (z -1)
#  y lo de arriba SIEMPRE por encima (z 3700), y en las estrechas ('dinamicas') la parte alta bajaba si
#  habia alguien delante. Pero tenia UNA z para todos: con uno delante y otro detras (tu grupo, que va en
#  fila) el tejado de la farola le atravesaba la cabeza al de delante; y la tira de abajo era mas alta que
#  la caja de choque, asi que quien se arrimaba por detras metia los pies DENTRO de las cajas del mercado.
#
#  Lo que se pinta en la pieza (el fuego, el cartel de la fachada, el agua de la fuente, el vidrio de las
#  ventanas) cuelga de ella con z RELATIVA: sube y baja con ella.
# ============================================================
extends Node2D
class_name PiezaPueblo

# El humo de las chimeneas y el globo del cartel indicador van por encima de todo lo del mundo.
const Z_ENCIMA := 3700
# Hasta que Game la ordena (el primer fotograma), y siempre la que es todo suelo: con el suelo, pintada
# despues de el.
const Z_DEBAJO := -1
# Las z que gasta una pieza en el orden (Game._ordenar_munecos): la suya y una encima para lo que lleva
# pegado (fuego, cartel). Un muñeco gasta Game.BANDA_MUNECO; una pieza no tiene capas, y la verja del
# jardin son medio centenar de piezas a la vista a la vez.
const PASO_Z := 2
# Cuanto por encima de la base de su huella esta la linea del suelo. La caja de choque de lo pequeño (el
# zocalo del poste, la planta del barril) acaba unos px por encima de esa base, y quien se arrima por
# delante tiene los pies justo debajo de la caja: con la base pelada, el que esta pegado delante aun
# contaba como detras.
const MARGEN_SUELO := 8.0
const GRUPO := &"piezas_pueblo"

static var _creadas: int = 0

var clave: String = ""
# A la misma linea de suelo (el puesto, su vendedor y su frente comparten huella) manda el orden en que se
# crearon: lo que se monta despues va encima.
var orden: int = 0
var margen_suelo: float = MARGEN_SUELO

var _tam: Vector2i = Vector2i.ZERO
# Px desde abajo que son HUELLA (suelo). Si es el dibujo entero, la pieza no tiene altura.
var _pie: int = 0


# 'huella' en casillas: la pieza se centra en horizontal sobre ella y apoya su base en su borde sur.
static func crear(p_clave: String, huella: Rect2i) -> PiezaPueblo:
	var p := PiezaPueblo.new()
	p.clave = p_clave
	p.name = "Pieza_" + p_clave
	var celda: float = float(PuebloPlano.CELDA)
	p._montar(PuebloSprites.textura(p_clave), PuebloSprites.tam(p_clave), PuebloSprites.pie(p_clave))
	p.position = Vector2(float(huella.position.x) * celda + (float(huella.size.x) * celda - float(p._tam.x)) * 0.5,
		float(huella.end.y) * celda - float(p._tam.y))
	return p


# La misma pieza con una textura cualquiera y SIN colocar: la usan las escaleras de la mazmorra
# (EscaleraSprites), que no viven en la rejilla del pueblo, y el vendedor del mercadillo. Quien la crea pone
# 'position' (la esquina de arriba a la izquierda del dibujo). 'p_margen': cuanto por encima de la base
# cuenta aun como "delante" (la subida de la escalera: quien pisa los peldaños sigue delante del arco).
static func crear_textura(p_nombre: String, tex: Texture2D, p_tam: Vector2i, p_pie: int,
		p_margen: float = MARGEN_SUELO) -> PiezaPueblo:
	var p := PiezaPueblo.new()
	p.clave = p_nombre
	p.name = "Pieza_" + p_nombre
	p.margen_suelo = p_margen
	p._montar(tex, p_tam, p_pie)
	return p


func _init() -> void:
	_creadas += 1
	orden = _creadas
	z_as_relative = false
	z_index = Z_DEBAJO


func _montar(tex: Texture2D, p_tam: Vector2i, p_pie: int) -> void:
	_tam = p_tam
	_pie = mini(p_pie, _tam.y)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	# POR NODO, que el proyecto no lo pone globalmente (misma nota que en enemy.gd).
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(s)


# SOLO LAS QUE TIENEN ALTURA entran en el orden. La que es todo huella (la escalera que baja: un agujero en
# el suelo) se queda con el suelo, por debajo de quien la pisa.
func _ready() -> void:
	if _pie < _tam.y:
		add_to_group(GRUPO)


# Lo pone Game._ordenar_munecos cada fotograma. Lo pegado va relativo: sube y baja con ella.
func poner_z(z: int) -> void:
	if z_index != z:
		z_index = z


# La altura con la que entra en el orden de Game, como los pies de un muñeco.
func linea_suelo() -> float:
	return base_y() - margen_suelo


# El dibujo entero, en coordenadas globales (para saber si esta a la vista).
func rect_global() -> Rect2:
	return Rect2(global_position, Vector2(_tam))


# LO COLGADO DE LA FACHADA (el cartel del oficio, ver town._colgar_cartel): justo encima de la pared, y con
# ella por debajo de lo que queda delante (la farola de la calle, quien pasa). 'pos' en px del lienzo.
func colgar(nodo: Node2D, pos: Vector2) -> void:
	_pegar(nodo, pos)


# Lo que va pegado a la parte alta (la llama del altar, el fuego de la farola). 'pos' en px del lienzo.
func acompanar(nodo: CanvasItem, pos: Vector2) -> void:
	_pegar(nodo, pos)


# Lo que va pintado SOBRE la pieza a su misma altura (el agua de la fuente, el vidrio de las ventanas):
# despues de ella en el arbol, con su misma z.
func encima(nodo: CanvasItem) -> void:
	nodo.z_as_relative = true
	nodo.z_index = 0
	add_child(nodo)


func _pegar(nodo: CanvasItem, pos: Vector2) -> void:
	nodo.z_as_relative = true
	nodo.z_index = 1
	if nodo is Node2D:
		(nodo as Node2D).position = pos
	add_child(nodo)


# El borde sur de la huella, en coordenadas globales.
func base_y() -> float:
	return global_position.y + float(_tam.y)
