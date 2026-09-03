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
	_dibujar_frasco(cd.color_suelo())


func _dibujar_frasco(col: Color) -> void:
	var cristal := Color(0.86, 0.90, 0.92, 0.55)   # el vidrio, siempre igual sea lo que sea
	var h := LADO * 0.5
	# Cuerpo: la panza del frasco, con el liquido de su color.
	draw_rect(Rect2(Vector2(-h * 0.75, -h * 0.15), Vector2(h * 1.5, h * 1.05)), col)
	# Hombros: un escalon mas estrecho, para que no parezca una caja.
	draw_rect(Rect2(Vector2(-h * 0.5, -h * 0.55), Vector2(h, h * 0.45)), col)
	# Cuello de vidrio y tapon de corcho.
	draw_rect(Rect2(Vector2(-h * 0.25, -h * 0.9), Vector2(h * 0.5, h * 0.4)), cristal)
	draw_rect(Rect2(Vector2(-h * 0.35, -h * 1.15), Vector2(h * 0.7, h * 0.3)), Color(0.55, 0.40, 0.24))
	# Brillo: una franja clara en el vidrio. Es lo que hace que se vea que es un frasco y no una
	# mancha de color, sobre todo con las pociones oscuras.
	draw_rect(Rect2(Vector2(-h * 0.6, -h * 0.05), Vector2(h * 0.22, h * 0.75)),
		Color(1, 1, 1, 0.35))


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
