# ============================================================
#  drop_pickup.gd
#  Un ITEM DE BOLSA tirado en el SUELO de la mazmorra: un MaterialItem (lo que suelta el
#  monstruo), un Cristal o una POCIÓN que el jugador ha SOLTADO desde el inventario. El dibujo lo
#  pone IconoItem, el mismo que usa la cuadricula del inventario: cubo para materiales y cristales,
#  frasco / libro / cuenco para los consumibles. El jugador lo recoge acercandose y pulsando F (ver
#  player.gd). Se crea por codigo (sin .tscn).
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
	queue_redraw()
	_crear_destellos()


# EL DIBUJO ENTERO LO PONE IconoItem, que es el MISMO que usa la cuadricula del inventario. Un item
# tiene que verse igual en el suelo y en la bolsa: es lo que deja reconocer de un vistazo lo que
# acabas de soltar. Mientras el dibujo vivio aqui dentro, la bolsa no tenia forma de pintarlo sin
# copiarlo, y una copia se despareja el dia que se retoque el color de una pocion.
#
# Se dibuja en vez de instanciar un nodo por trazo porque son cuatro trazos: un nodo por trazo
# multiplicaria por cuatro lo que hay en el suelo de un piso (con el tope en 60 drops, ver
# Net.SUELO_TOPE_POR_LUGAR, eso son 240 nodos de mas para pintar lo mismo).
func _draw() -> void:
	IconoItem.pintar(self, Vector2.ZERO, LADO, item)


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


# El jugador lo recoge: devuelve el item y se elimina del suelo. Quien llama decide
# en que parte de la bolsa lo mete (Game.embolsar: cristales / materiales / consumibles).
func recoger() -> Resource:
	var i := item
	queue_free()
	return i
