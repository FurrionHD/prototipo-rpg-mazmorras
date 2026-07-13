# ============================================================
#  spawn_table.gd
#  RECURSO: una TABLA de spawns. Lista de SpawnEntry; cada parto de una pared hace
#  una tirada PONDERADA entre las entradas disponibles en el piso actual.
#
#  Las tablas se ANIDAN, y ahi esta la gracia:
#    - tabla del PISO:    slimes 40 | goblins 30 | kobolds 30   (familias)
#    - tabla de SLIMES:   normal 88 | venenoso 10 | de fuego 2  (variantes)
#  Primero se sortea la familia, luego la variante dentro de ella. Cambiar el reparto
#  de un piso no toca las rarezas internas de cada familia, y al reves.
#
#  Ningun numero de estos vive en el codigo: todos son campos de los .tres.
# ============================================================

extends Resource
class_name SpawnTable

# Nombre de la familia ("Slimes"), solo para los logs y el resumen.
@export var nombre: String = ""
@export var entradas: Array[SpawnEntry] = []

# Tope de anidamiento: red de seguridad por si una tabla se referencia a si misma
# (se colgaria el juego). 4 niveles es mas de lo que ningun piso va a necesitar.
const MAX_PROFUNDIDAD := 4


func nombre_familia() -> String:
	return nombre if nombre != "" else "familia"


# Entradas que existen en este piso (respetan piso_min/piso_max y tienen algo que parir).
func disponibles(piso: int) -> Array:
	var out: Array = []
	for e in entradas:
		if e != null and e.disponible(piso):
			out.append(e)
	return out


# Tirada PONDERADA (ruleta): elige una entrada y, si es una familia, vuelve a tirar
# dentro de ella. Devuelve el EnemyData final, o null si no hay nada para este piso.
func elegir(piso: int, profundidad: int = 0) -> EnemyData:
	if profundidad >= MAX_PROFUNDIDAD:
		push_warning("[spawns] tablas anidadas demasiado hondo (¿una tabla se apunta a si misma?)")
		return null
	var e: SpawnEntry = _tirar(piso)
	if e == null:
		return null
	if e.es_familia():
		return e.tabla.elegir(piso, profundidad + 1)
	return e.enemy_data


func _tirar(piso: int) -> SpawnEntry:
	var pool: Array = disponibles(piso)
	if pool.is_empty():
		return null
	var total: float = 0.0
	for e in pool:
		total += e.peso
	var tirada: float = randf() * total
	for e in pool:
		tirada -= e.peso
		if tirada <= 0.0:
			return e
	return pool.back()


# Texto con los numeros DERIVADOS de los pesos (nunca escritos a mano): que probabilidad
# REAL tiene cada cosa en este piso. Una familia se abre entre parentesis con sus
# variantes ya multiplicadas por la parte que le toca a la familia, que es el numero que
# de verdad importa ("de cada 100 bichos del piso, cuantos son slimes de fuego").
func resumen(piso: int, cuota: float = 1.0, profundidad: int = 0) -> String:
	var pool: Array = disponibles(piso)
	if pool.is_empty():
		return "sin enemigos en este piso"
	var total: float = 0.0
	for e in pool:
		total += e.peso

	var partes: PackedStringArray = []
	for e in pool:
		var p: float = cuota * e.peso / total          # probabilidad ABSOLUTA en el piso
		var txt: String = "%s %s%%" % [e.etiqueta(), snappedf(p * 100.0, 0.1)]
		if p > 0.0:
			txt += " (1 de cada %d)" % roundi(1.0 / p)
		if e.es_familia() and profundidad + 1 < MAX_PROFUNDIDAD:
			txt += " [%s]" % e.tabla.resumen(piso, p, profundidad + 1)
		partes.append(txt)
	return ", ".join(partes)
