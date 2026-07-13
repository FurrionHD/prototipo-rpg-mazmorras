# ============================================================
#  material_table.gd
#  TABLA de lo que se recolecta: una para las VETAS y otra para las PLANTAS. Cada nodo
#  recolectable del piso hace una tirada ponderada aqui para saber QUE material lleva.
#
#  Mismo patron que spawn_table.gd (las paredes paren por tirada ponderada), pero sin
#  anidar: un mineral no tiene "variantes" como una familia de bichos.
#
#  Ningun numero vive en el codigo: los pesos y los pisos son campos de los .tres.
# ============================================================

extends Resource
class_name MaterialTable

@export var nombre: String = ""
@export var entradas: Array[MaterialEntry] = []


func disponibles(piso: int) -> Array:
	var out: Array = []
	for e in entradas:
		if e != null and e.disponible(piso):
			out.append(e)
	return out


# Tirada ponderada. 'rng' entra por parametro para que la COLOCACION del piso sea
# DETERMINISTA (el mismo piso pone siempre las mismas vetas del mismo material). Sin
# rng, tira al azar (util para el resumen de dev).
func elegir(piso: int, rng: RandomNumberGenerator = null) -> MaterialData:
	var pool: Array = disponibles(piso)
	if pool.is_empty():
		return null
	var total: float = 0.0
	for e in pool:
		total += e.peso
	var tirada: float = (rng.randf() if rng != null else randf()) * total
	for e in pool:
		tirada -= e.peso
		if tirada <= 0.0:
			return e.material
	return (pool.back() as MaterialEntry).material


# Probabilidades REALES en este piso, derivadas de los pesos (nunca escritas a mano).
func resumen(piso: int) -> String:
	var pool: Array = disponibles(piso)
	if pool.is_empty():
		return "nada que recolectar en este piso"
	var total: float = 0.0
	for e in pool:
		total += e.peso
	var partes: PackedStringArray = []
	for e in pool:
		partes.append("%s %s%%" % [e.etiqueta(), snappedf(100.0 * e.peso / total, 0.1)])
	return ", ".join(partes)
