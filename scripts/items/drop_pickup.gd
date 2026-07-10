# ============================================================
#  drop_pickup.gd
#  Un ITEM DE BOLSA tirado en el SUELO de la mazmorra: un MonsterDrop (drop del
#  monstruo) o un Cristal que el jugador ha SOLTADO desde el inventario. Se ve como
#  un cuadradito de color segun su tipo/calidad. El jugador lo recoge acercandose y
#  pulsando F (ver player.gd). Se crea por codigo (sin .tscn).
# ============================================================

extends Node2D

# El item que hay en el suelo: Cristal | MonsterDrop.
var item: Resource = null


func setup(i: Resource) -> void:
	item = i


func _ready() -> void:
	add_to_group("pickup")
	var rect := ColorRect.new()
	rect.size = Vector2(16, 16)
	rect.position = Vector2(-8, -8)  # centrado en el nodo
	rect.color = _color_item()
	add_child(rect)


# Color por tipo y calidad. Los cristales tiran a cian/violeta; los materiales, a la
# escala gris/azul/dorado de siempre.
func _color_item() -> Color:
	if item is MonsterDrop:
		match (item as MonsterDrop).calidad:
			MonsterDrop.Calidad.DEFECTUOSO: return Color(0.6, 0.6, 0.6)   # gris
			MonsterDrop.Calidad.NORMAL: return Color(0.4, 0.7, 1.0)        # azul
			_: return Color(1.0, 0.85, 0.2)                                # dorado (excelente)
	if item is Cristal:
		match (item as Cristal).calidad:
			Cristal.Calidad.INTACTO: return Color(0.4, 1.0, 0.9)   # cian brillante
			Cristal.Calidad.NORMAL: return Color(0.5, 0.8, 0.85)   # cian apagado
			_: return Color(0.45, 0.45, 0.55)                       # dañado: gris azulado
	return Color.WHITE


# El jugador lo recoge: devuelve el item y se elimina del suelo. Quien llama decide
# en que parte de la bolsa lo mete (cristales / drops).
func recoger() -> Resource:
	var i := item
	queue_free()
	return i
