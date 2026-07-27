# ============================================================
#  drop_pickup.gd
#  Un ITEM DE BOLSA tirado en el SUELO de la mazmorra: un MaterialItem (lo que suelta el
#  monstruo) o un Cristal que el jugador ha SOLTADO desde el inventario. Se ve como un
#  cuadradito de color segun su tipo/calidad. El jugador lo recoge acercandose y pulsando
#  F (ver player.gd). Se crea por codigo (sin .tscn).
# ============================================================

extends Node2D

# El item que hay en el suelo: Cristal | MaterialItem.
var item: Resource = null


func setup(i: Resource) -> void:
	item = i


const LADO := 16.0


func _ready() -> void:
	add_to_group("pickup")
	var rect := ColorRect.new()
	rect.size = Vector2(LADO, LADO)
	rect.position = Vector2(-LADO * 0.5, -LADO * 0.5)  # centrado en el nodo
	rect.color = _color_item()
	add_child(rect)
	_crear_destellos()


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
	var rango: int = data.rango_color()
	# El gris (rango 0) tambien destella, pero flojito: si el cobre corriente centellea como un
	# nucleo de boss, el lenguaje de color deja de decir nada.
	var intensidad: float = 0.3 + 0.7 * (float(rango) / float(MaterialData.Rango.AMARILLO))
	Particulas.destellos(self, data.color_rango(), Vector2(LADO, LADO), intensidad)


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
# en que parte de la bolsa lo mete (cristales / materiales).
func recoger() -> Resource:
	var i := item
	queue_free()
	return i
