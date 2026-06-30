# ============================================================
#  drop_pickup.gd
#  El DROP del monstruo tirado en el SUELO de la mazmorra. Se ve como un
#  cuadradito de color segun su calidad. El jugador lo recoge acercandose y
#  pulsando F (ver player.gd). Se crea por codigo (sin .tscn).
# ============================================================

extends Node2D

var drop: MonsterDrop = null


func setup(d: MonsterDrop) -> void:
	drop = d


func _ready() -> void:
	add_to_group("pickup")
	var rect := ColorRect.new()
	rect.size = Vector2(16, 16)
	rect.position = Vector2(-8, -8)  # centrado en el nodo
	rect.color = _color_por_calidad()
	add_child(rect)


func _color_por_calidad() -> Color:
	if drop == null:
		return Color.WHITE
	match drop.calidad:
		MonsterDrop.Calidad.DEFECTUOSO: return Color(0.6, 0.6, 0.6)   # gris
		MonsterDrop.Calidad.NORMAL: return Color(0.4, 0.7, 1.0)        # azul
		_: return Color(1.0, 0.85, 0.2)                                # dorado (excelente)


# El jugador lo recoge: devuelve el drop y se elimina del suelo.
func recoger() -> MonsterDrop:
	var d := drop
	queue_free()
	return d
