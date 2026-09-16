# ============================================================
#  pieza_pueblo.gd  (class_name PiezaPueblo)
#  Una pieza del pueblo con ALTURA (casa, columna, verja) colocada sobre su huella y PARTIDA EN DOS
#  para que se ordene bien contra quien anda alrededor.
#
#  EL PROBLEMA. El proyecto no usa y_sort, y no puede usarlo sin mas: el muñeco del jugador ordena sus
#  capas con z ABSOLUTOS de 1 a ~2050 (ver muneco_jugador.gd), asi que un y_sort solo ordenaria
#  dentro del mismo z y no serviria de nada.
#
#  LA SALIDA. El dibujo se corta por la linea de fondo de su HUELLA:
#    - lo que cae DENTRO de la huella (la fachada, el pie de la columna) va por DEBAJO de los
#      personajes: como nadie puede meterse en la huella, quien este cerca esta DELANTE y se le ve
#      encima de la fachada;
#    - lo que SOBRESALE por encima (tejado, chimenea, la parte alta de la columna) va por ENCIMA:
#      quien pasa por detras queda tapado.
#
#  Eso es exacto cuando la huella es mas honda que alto es un personaje (~60 px): las casas. En una
#  pieza ESTRECHA (una columna de una casilla, una verja) no lo es: alguien pegado por delante mete
#  la cabeza en la parte que sobresale y el tejado de la columna le taparia la cara. Para esas va
#  'dinamica': si hay alguien delante y cerca, la parte de arriba baja tambien por debajo.
# ============================================================
extends Node2D
class_name PiezaPueblo

# Por encima de TODAS las capas del muñeco. No basta con pasar el 2051 de la cara: el arma se empuja
# a prof 40 cuando va delante (muneco_jugador.gd), o sea z ~2560, y con 2100 asomaba por encima del
# tejado. Por debajo del 4000 de los numeros de combate y del tope de Godot (4096).
const Z_ENCIMA := 3700   # y por encima de la base de los personajes: 1024 + 2560 (Game.Z_PERSONAJES)
const Z_DEBAJO := -1        # con el suelo, pero pintada despues de el

var clave: String = ""
var dinamica: bool = false

var _arriba: Sprite2D = null
# Lo que va pegado a la parte ALTA y tiene que ordenarse igual que ella (la llama del altar): si la parte
# alta baja por debajo de quien esta delante, esto baja con ella.
var acompanantes: Array[CanvasItem] = []
var _abajo: Sprite2D = null
var _tam: Vector2i = Vector2i.ZERO
var _pie: int = 0


# 'huella' en casillas: la pieza se centra en horizontal sobre ella y apoya su base en su borde sur.
static func crear(p_clave: String, huella: Rect2i, p_dinamica: bool = false) -> PiezaPueblo:
	var p := PiezaPueblo.new()
	p.clave = p_clave
	p.dinamica = p_dinamica
	p.name = "Pieza_" + p_clave
	var celda: float = float(PuebloPlano.CELDA)
	p._montar(PuebloSprites.textura(p_clave), PuebloSprites.tam(p_clave), PuebloSprites.pie(p_clave))
	p.position = Vector2(float(huella.position.x) * celda + (float(huella.size.x) * celda - float(p._tam.x)) * 0.5,
		float(huella.end.y) * celda - float(p._tam.y))
	return p


# La misma pieza partida, con una textura cualquiera y SIN colocar: la usan las escaleras de la
# mazmorra (EscaleraSprites), que no viven en la rejilla del pueblo. Quien la crea pone 'position'
# (la esquina de arriba a la izquierda del dibujo). 'margen_delante': cuanto por encima de la base
# cuenta aun como "delante" en una pieza dinamica (ver _process).
static func crear_textura(p_nombre: String, tex: Texture2D, p_tam: Vector2i, p_pie: int,
		p_dinamica: bool = false, margen_delante: float = 20.0) -> PiezaPueblo:
	var p := PiezaPueblo.new()
	p.clave = p_nombre
	p.dinamica = p_dinamica
	p.name = "Pieza_" + p_nombre
	p._margen_delante = margen_delante
	p._montar(tex, p_tam, p_pie)
	return p


var _margen_delante: float = 20.0

func _montar(tex: Texture2D, p_tam: Vector2i, p_pie: int) -> void:
	_tam = p_tam
	_pie = mini(p_pie, _tam.y)
	var corte: int = _tam.y - _pie
	_abajo = _trozo(tex, Rect2(0, corte, _tam.x, _pie), Z_DEBAJO)
	if corte > 0:
		_arriba = _trozo(tex, Rect2(0, 0, _tam.x, corte), Z_ENCIMA)


# Aqui y no en crear(): Godot ENCIENDE el _process al entrar en el arbol si el script lo define, asi
# que apagarlo antes de add_child no sirve de nada (y las piezas sin parte alta petaban cada frame).
func _ready() -> void:
	set_process(dinamica and _arriba != null)


# Pega algo a la parte alta (ver acompanantes). 'pos' en px del lienzo de la pieza.
func acompanar(nodo: CanvasItem, pos: Vector2) -> void:
	nodo.z_as_relative = false
	nodo.z_index = Z_ENCIMA + 1
	if nodo is Node2D:
		(nodo as Node2D).position = pos
	add_child(nodo)
	acompanantes.append(nodo)


func _trozo(tex: Texture2D, region: Rect2, z: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.region_enabled = true
	s.region_rect = region
	s.position = region.position
	# POR NODO, que el proyecto no lo pone globalmente (misma nota que en enemy.gd).
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.z_as_relative = false
	s.z_index = z
	add_child(s)
	return s


# El borde sur de la huella, en coordenadas globales.
func base_y() -> float:
	return global_position.y + float(_tam.y)


func _process(_delta: float) -> void:
	var fondo: float = base_y()
	var cx: float = global_position.x + float(_tam.x) * 0.5
	var delante: bool = false
	for n in get_tree().get_nodes_in_group("aliado"):
		var nd := n as Node2D
		if nd == null:
			continue
		var p: Vector2 = nd.global_position
		# Delante = su origen por debajo de la base (menos lo que su caja de pies sube) y lo bastante
		# cerca para que su cabeza llegue a la parte que sobresale.
		if absf(p.x - cx) < float(_tam.x) * 0.5 + 16.0 and p.y > fondo - _margen_delante and p.y < fondo + 80.0:
			delante = true
			break
	_arriba.z_index = Z_DEBAJO if delante else Z_ENCIMA
	for a in acompanantes:
		if is_instance_valid(a):
			a.z_index = _arriba.z_index + 1
