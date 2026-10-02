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


# Cuantas unidades iguales hay en este monton (las flechas que se recuperan caen juntas). 1 = una.
var cantidad: int = 1

func setup(i: Resource, n: int = 1) -> void:
	item = i
	cantidad = maxi(1, n)


const LADO := 16.0


func _ready() -> void:
	add_to_group("pickup")
	queue_redraw()
	_crear_destellos()
	_mirar_arquero()


# LA MUNICION SOLO LA VE QUIEN LA USA (02/10, lo pidio el jefe): con arco o ballesta se ve y se recoge; sin, ni
# se ve ni esta en el grupo de recogibles, para que un compañero que no la usa no se la lleve sin querer. Se mira
# a ratos porque puedes cambiar de arma con ella en el suelo.
var _t_arquero: float = 0.0

func _es_municion() -> bool:
	return item is MaterialItem and (item as MaterialItem).data is MunicionData

func _process(delta: float) -> void:
	if not _es_municion():
		set_process(false)
		return
	_t_arquero -= delta
	if _t_arquero <= 0.0:
		_t_arquero = 0.5
		_mirar_arquero()

func _mirar_arquero() -> void:
	if not _es_municion():
		return
	var ve: bool = Game.lleva_arma_distancia(Game.lider())
	visible = ve
	if ve and not is_in_group("pickup"):
		add_to_group("pickup")
	elif not ve and is_in_group("pickup"):
		remove_from_group("pickup")


# EL DIBUJO ENTERO LO PONE IconoItem, que es el MISMO que usa la cuadricula del inventario. Un item
# tiene que verse igual en el suelo y en la bolsa: es lo que deja reconocer de un vistazo lo que
# acabas de soltar. Mientras el dibujo vivio aqui dentro, la bolsa no tenia forma de pintarlo sin
# copiarlo, y una copia se despareja el dia que se retoque el color de una pocion.
#
# Se dibuja en vez de instanciar un nodo por trazo porque son cuatro trazos: un nodo por trazo
# multiplicaria por cuatro lo que hay en el suelo de un piso (con el tope en 60 drops, ver
# Net.suelo.SUELO_TOPE_POR_LUGAR, eso son 240 nodos de mas para pintar lo mismo).
func _draw() -> void:
	IconoItem.pintar(self, Vector2.ZERO, LADO, item)
	if cantidad > 1:
		var f: Font = ThemeDB.fallback_font
		draw_string_outline(f, Vector2(LADO * 0.1, LADO * 0.62), "x%d" % cantidad, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 9, 3, Color(0, 0, 0, 0.8))
		draw_string(f, Vector2(LADO * 0.1, LADO * 0.62), "x%d" % cantidad, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


# DESTELLOS del color de su rango (ver MaterialData.rango_color): asi un nucleo de trent tirado en
# el suelo canta morado y no hay que acercarse a leer el nombre.
#
# MULTIJUGADOR: aqui no hay nada que sincronizar, y es a proposito. El drop viaja como
# {ruta del material, calidad} (ver Net.suelo._item_a_dict) y CADA peer llama a este _ready(), asi que
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

# Todo el monton, una unidad por elemento (para embolsarlas de una en una). La primera es el propio item.
func recoger_todos() -> Array:
	var out: Array = [item]
	for _k in range(cantidad - 1):
		if item is MaterialItem:
			out.append(MaterialItem.crear((item as MaterialItem).data, int((item as MaterialItem).calidad)))
		else:
			out.append(item)
	queue_free()
	return out
