# ============================================================
#  material_entry.gd
#  UNA entrada de una MaterialTable: que material y con que peso sale en la tirada.
#  La PROFUNDIDAD a la que aparece no vive aqui: la lleva el propio MaterialData
#  (piso_min/piso_max), porque es una propiedad del material, no de la tabla.
#  Gemelo de spawn_entry.gd, pero para lo que se recolecta.
# ============================================================

extends Resource
class_name MaterialEntry

@export var material: MaterialData = null
@export var peso: float = 10.0


func disponible(piso: int) -> bool:
	return material != null and peso > 0.0 and material.disponible(piso)


func etiqueta() -> String:
	return material.nombre if material != null else "(vacio)"
