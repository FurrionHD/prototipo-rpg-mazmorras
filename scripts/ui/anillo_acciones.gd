# ============================================================
#  anillo_acciones.gd  (06/11, rework del HUD, estilo MODERNO: ver hud_estilo.gd)
#  Las seis acciones EN ANILLO, como en Honkai: Star Rail: la PRIMERA (Atacar) grande en la esquina de abajo a la
#  derecha, que es donde descansa el pulgar, y las otras cinco en un cuarto de circulo alrededor, de la izquierda a
#  arriba. Es un Container: los botones son los mismos de siempre, solo cambia donde caen.
# ============================================================
extends Container

const LADO_GRANDE := 130.0
const LADO := 76.0
const RADIO := 176.0     # del centro del grande al de cada pequeño (con 5 en 105 grados no se tocan)
const ARCO := 105.0      # de la izquierda (180) a un poco pasado arriba (285)
const CORRE := 16.0      # el grande, algo a la izquierda de la esquina: si no, el de arriba se sale por la derecha
const MARGEN := 4.0
const ALTO := 284.0      # algo mas que la rejilla de 2x3 (248): el panel crece hacia arriba (combat_montaje)


func _init() -> void:
	custom_minimum_size = Vector2(0, ALTO)


func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN:
		return
	var hijos: Array = []
	for c in get_children():
		if c is Control and (c as Control).visible:
			hijos.append(c)
	if hijos.is_empty():
		return
	var centro := Vector2(size.x - MARGEN - LADO_GRANDE * 0.5 - CORRE, size.y - MARGEN - LADO_GRANDE * 0.5)
	fit_child_in_rect(hijos[0], Rect2(centro - Vector2(LADO_GRANDE, LADO_GRANDE) * 0.5, Vector2(LADO_GRANDE, LADO_GRANDE)))
	var resto: int = hijos.size() - 1
	for i in resto:
		# De 180 grados (a la izquierda) a 180 + ARCO (arriba y un poco a la derecha), repartidos.
		var a: float = deg_to_rad(180.0 + (ARCO * float(i) / float(maxi(resto - 1, 1))))
		var p: Vector2 = centro + Vector2(cos(a), sin(a)) * RADIO
		fit_child_in_rect(hijos[i + 1], Rect2(p - Vector2(LADO, LADO) * 0.5, Vector2(LADO, LADO)))


func _get_minimum_size() -> Vector2:
	return Vector2(0, ALTO)
