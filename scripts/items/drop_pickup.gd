# ============================================================
#  drop_pickup.gd
#  Un ITEM DE BOLSA tirado en el SUELO de la mazmorra: un MaterialItem (lo que suelta el
#  monstruo), un Cristal o una POCIÓN que el jugador ha SOLTADO desde el inventario. Se ve como un
#  cuadradito de color segun su tipo/calidad -- salvo los consumibles, que se ven como un FRASCO
#  (ver _dibujar_frasco). El jugador lo recoge acercandose y pulsando F (ver player.gd). Se crea
#  por codigo (sin .tscn).
# ============================================================

extends Node2D

# El item que hay en el suelo: Cristal | MaterialItem | ConsumableData.
#
# Ojo con el tercero: un consumible NO se instancia (la bolsa es un contador por .tres, ver
# Game.consumables), asi que lo que hay aqui es el PROPIO recurso compartido del proyecto. No se
# puede escribir nada en el ni guardar estado por unidad: para el suelo da igual, porque lo unico
# que se necesita es de que poción se trata.
var item: Resource = null


func setup(i: Resource) -> void:
	item = i


const LADO := 16.0


func _ready() -> void:
	add_to_group("pickup")
	if item is ConsumableData:
		queue_redraw()   # los consumibles se pintan a mano: frasco, no cuadrado
		return
	var rect := ColorRect.new()
	rect.size = Vector2(LADO, LADO)
	rect.position = Vector2(-LADO * 0.5, -LADO * 0.5)  # centrado en el nodo
	rect.color = _color_item()
	add_child(rect)
	_crear_destellos()


# EL FRASCO. PLACEHOLDER a proposito, como el resto de la UI: cuando llegue el rework del
# inventario, TODOS los objetos tendran su sprite (en la bolsa y en el suelo) y esto se cambia por
# uno. Hasta entonces la silueta dibujada ya hace su trabajo, que es que se distinga de un mineral.
#
# Un consumible en el suelo no puede ser el mismo cuadrado que un mineral: lo que se
# tira ahi es justo lo que un compañero necesita encontrar rapido en mitad de la pelea. La silueta
# (cuerpo ancho + cuello estrecho + tapon) se lee a este tamaño mucho antes que el color, asi que
# hace de "es un objeto" y el color hace de "es de vida / de maná / es un libro".
#
# Se dibuja en vez de instanciar un ColorRect por pieza porque son cuatro trazos: un nodo por trazo
# multiplicaria por cuatro lo que hay en el suelo de un piso (con el tope en 60 drops, ver
# Net.SUELO_TOPE_POR_LUGAR, eso son 240 nodos de mas para pintar lo mismo).
func _draw() -> void:
	if not (item is ConsumableData):
		return
	var cd := item as ConsumableData
	# Tres siluetas, no una: un grimorio no es un frasco y un guiso tampoco. La FORMA dice de que
	# clase de cosa se trata y el COLOR cual en concreto, que es lo que deja reconocer un drop sin
	# acercarse a leer el nombre.
	if cd.es_grimorio():
		_dibujar_libro(cd.color_suelo())
		return
	if cd.es_plato():
		_dibujar_plato(cd.color_suelo())
		return
	_dibujar_frasco(cd.color_suelo(), cd.tier)


# ============================================================
#  LOS FRASCOS, POR TIER
#  El TIER cambia la FORMA y el contenido cambia el COLOR: son dos ejes independientes, asi que una
#  poción de vida menor y una media se distinguen por el bulto aunque las dos sean rojas, y una de
#  vida y una de maná del mismo tier se distinguen por el color aunque tengan el mismo bulto. Con
#  todas del mismo tamaño, lo unico que quedaba era el tono, y "rojo oscuro" contra "rojo vivo" no
#  se lee en mitad de una pelea.
#
#  Cada perfil es el SEMIANCHO de cada fila de pixeles, de arriba abajo (16 filas de 1 px). Se
#  describe asi y no con rectangulos porque es lo unico que deja curvar los hombros y la panza: un
#  bulbo hecho con tres rectangulos se ve como una escalera.
# ============================================================

# tier 1: probeta estrecha y alta. tier 2: matraz con hombros. tier 3: bulbo panzudo.
const PERFILES := [
	[0.0, 2.0, 2.0, 1.5, 1.5, 2.0, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5, 2.0, 0.0],
	[0.0, 2.0, 2.0, 1.5, 1.5, 2.0, 3.0, 4.0, 4.5, 5.0, 5.0, 5.0, 5.0, 4.5, 3.5, 0.0],
	[2.0, 2.0, 1.5, 1.5, 2.5, 4.0, 5.0, 6.0, 6.5, 6.5, 6.5, 6.0, 5.5, 4.5, 3.0, 0.0],
]
# Filas de TAPON y de CUELLO en cada perfil (el resto es cuerpo). El bulbo del tier 3 empieza una
# fila mas arriba porque necesita el sitio para la panza.
const TAPON_FILAS := [[1, 2], [1, 2], [0, 1]]
const CUELLO_FILAS := [[3, 4], [3, 4], [2, 3]]
# Primera fila con LIQUIDO: por encima queda aire, que es lo que hace que se lea como un frasco
# medio lleno y no como un bloque de color.
const NIVEL_FILA := [6, 6, 5]

const CORCHO := Color(0.55, 0.40, 0.24)
const VIDRIO := Color(0.86, 0.90, 0.92, 0.55)


func _dibujar_frasco(col: Color, tier: int) -> void:
	var i: int = clampi(tier - 1, 0, PERFILES.size() - 1)
	var perfil: Array = PERFILES[i]
	var tapon: Array = TAPON_FILAS[i]
	var cuello: Array = CUELLO_FILAS[i]
	var nivel: int = NIVEL_FILA[i]
	var y0 := -LADO * 0.5
	for fila in perfil.size():
		var w: float = float(perfil[fila])
		if w <= 0.0:
			continue
		var c: Color
		if fila >= int(tapon[0]) and fila <= int(tapon[1]):
			c = CORCHO
		elif fila >= int(cuello[0]) and fila <= int(cuello[1]):
			c = VIDRIO
		elif fila < nivel:
			c = VIDRIO                     # el aire de encima del liquido
		else:
			c = col
		draw_rect(Rect2(Vector2(-w, y0 + float(fila)), Vector2(w * 2.0, 1.0)), c)
	# Brillo: una columna de vidrio pegada al borde izquierdo del liquido. Es lo que hace que se
	# vea vidrio y no una mancha, sobre todo con las pociones oscuras.
	var alto: float = float(perfil.size() - 1 - nivel)
	draw_rect(Rect2(Vector2(-float(perfil[nivel + 1]) + 1.0, y0 + float(nivel)),
		Vector2(1.0, alto)), Color(1, 1, 1, 0.30))


# EL LIBRO (grimorios). Tapa de su color, lomo mas oscuro a la izquierda y el canto de las hojas
# en crema a la derecha: con esos tres bloques ya no se confunde con un frasco a 16 px.
func _dibujar_libro(col: Color) -> void:
	var h := LADO * 0.5
	draw_rect(Rect2(Vector2(-h * 0.8, -h * 0.85), Vector2(h * 1.6, h * 1.7)), col)
	draw_rect(Rect2(Vector2(-h * 0.8, -h * 0.85), Vector2(h * 0.35, h * 1.7)), col.darkened(0.45))
	draw_rect(Rect2(Vector2(h * 0.45, -h * 0.65), Vector2(h * 0.35, h * 1.3)),
		Color(0.92, 0.89, 0.78))
	# El cierre metalico, que es lo que lo hace "grimorio" y no "cuaderno".
	draw_rect(Rect2(Vector2(-h * 0.1, -h * 0.15), Vector2(h * 0.5, h * 0.3)),
		Color(0.85, 0.78, 0.45))


# EL PLATO (comida). Cuenco visto un poco desde arriba: el borde de barro por fuera, el contenido
# de su color HUNDIDO dentro. El contenido tiene que ser MAS ESTRECHO que el cuenco o deja de leerse
# como un cuenco lleno y parece un sombrero (primera version, vista al renderizarlo).
func _dibujar_plato(col: Color) -> void:
	var h := LADO * 0.5
	var barro := Color(0.62, 0.50, 0.41)
	# Borde del cuenco: la pieza mas ancha de todas, es la que da la silueta.
	draw_rect(Rect2(Vector2(-h * 0.95, -h * 0.55), Vector2(h * 1.9, h * 0.4)), barro)
	# El caldo, metido dentro del borde.
	draw_rect(Rect2(Vector2(-h * 0.7, -h * 0.5), Vector2(h * 1.4, h * 0.3)), col)
	# Panza y pie del cuenco, estrechandose hacia abajo.
	draw_rect(Rect2(Vector2(-h * 0.8, -h * 0.15), Vector2(h * 1.6, h * 0.55)), barro.darkened(0.15))
	draw_rect(Rect2(Vector2(-h * 0.45, h * 0.4), Vector2(h * 0.9, h * 0.35)), barro.darkened(0.4))
	# Un tropezon asomando por encima del borde: es lo que lo hace "comida" y no "vasija".
	draw_rect(Rect2(Vector2(-h * 0.2, -h * 0.85), Vector2(h * 0.45, h * 0.32)), col.lightened(0.3))


# DESTELLOS del color de su rango (ver MaterialData.rango_color): asi un nucleo de trent tirado en
# el suelo canta morado y no hay que acercarse a leer el nombre.
#
# MULTIJUGADOR: aqui no hay nada que sincronizar, y es a proposito. El drop viaja como
# {ruta del material, calidad} (ver Net._item_a_dict) y CADA peer llama a este _ready(), asi que
# los dos derivan el mismo color del mismo MaterialData. El color no va por el cable.
#
# Sirve igual para las DOS formas de acabar en el suelo: lo que suelta el bicho al morir y lo que
# tiras tu desde el inventario (los dos pasan por aqui, con y sin sesion).
func _crear_destellos() -> void:
	if not (item is MaterialItem):
		return   # los cristales tienen su propia escala (categoria/calidad), no la de rango
	var data: MaterialData = (item as MaterialItem).data
	if data == null:
		return
	# El gris (rango 0) tambien destella, pero flojito: si el cobre corriente centellea como un
	# nucleo de boss, el lenguaje de color deja de decir nada. Esa curva la lleva rango_intensidad.
	Particulas.destellos(self, data.color_rango(), Vector2(LADO, LADO), data.rango_intensidad())


# Color por tipo y calidad. Los cristales tiran a cian/violeta; los materiales llevan SU
# color (el del .tres), apagado o realzado segun la calidad (ver MaterialItem.color()).
func _color_item() -> Color:
	if item is MaterialItem:
		return (item as MaterialItem).color()
	if item is Cristal:
		match (item as Cristal).calidad:
			Cristal.Calidad.INTACTO: return Color(0.4, 1.0, 0.9)   # cian brillante
			Cristal.Calidad.NORMAL: return Color(0.5, 0.8, 0.85)   # cian apagado
			_: return Color(0.45, 0.45, 0.55)                       # dañado: gris azulado
	return Color.WHITE


# El jugador lo recoge: devuelve el item y se elimina del suelo. Quien llama decide
# en que parte de la bolsa lo mete (Game.embolsar: cristales / materiales / consumibles).
func recoger() -> Resource:
	var i := item
	queue_free()
	return i
