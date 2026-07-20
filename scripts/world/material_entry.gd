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

# --- RAMPA por profundidad (sub-tiers) ---
# Un material no tiene por que entrar de golpe con su peso definitivo. Con los sub-tiers
# (cobre / cobre veteado / cobre profundo) hace falta que el nuevo ASOME raro, CONVIVA con los
# otros y se vuelva DOMINANTE mas abajo. Si fuera un escalon, cada piso tendria un solo material
# y la mezcla no existiria.
#
# peso_pleno <= 0 -> SIN RAMPA: se usa `peso` tal cual en todos los pisos. Es el valor por
# defecto, o sea lo que hacen hoy todas las entradas.
# Con rampa, el peso interpola de `peso` (en piso_debut) a `peso_pleno` (en piso_pleno) y se
# queda ahi. Ojo: la rampa puede ir HACIA ABAJO (el cobre base se apaga segun bajas), y de hecho
# es lo que hace que las proporciones sumen bien.
@export var peso_pleno: float = 0.0
@export var piso_debut: int = 1
@export var piso_pleno: int = 1


# El peso de esta entrada EN ESTE PISO, ya con la rampa aplicada.
# Mismo patron de interpolacion que EnemyData.drop_factor_piso: una sola manera de escalar con la
# profundidad en todo el proyecto.
func peso_en(piso: int) -> float:
	if peso_pleno <= 0.0 or piso_pleno <= piso_debut:
		return peso
	var t: float = float(piso - piso_debut) / float(piso_pleno - piso_debut)
	return lerpf(peso, peso_pleno, clampf(t, 0.0, 1.0))


func disponible(piso: int) -> bool:
	return material != null and peso_en(piso) > 0.0 and material.disponible(piso)


func etiqueta() -> String:
	return material.nombre if material != null else "(vacio)"
