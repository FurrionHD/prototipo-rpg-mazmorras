# ============================================================
#  spawn_entry.gd
#  RECURSO: una ENTRADA de una tabla de spawns = "esto, con este peso, entre estos
#  pisos". "Esto" puede ser:
#    - un ENEMIGO concreto (enemy_data), o
#    - otra TABLA (tabla) -> una FAMILIA, que reparte por dentro con sus propios pesos.
#  Asi el piso dice "40% slimes / 30% goblins / 30% kobolds" y, dentro del 40% de
#  slimes, se sigue tirando 88 / 10 / 2 (normal / venenoso / de fuego).
#
#  La rareza vive AQUI y no en EnemyData a proposito: el mismo bicho puede ser raro
#  arriba y comun abajo sin tocar su .tres.
# ============================================================

extends Resource
class_name SpawnEntry

# Rellena UNO de los dos. Si hay tabla, gana la tabla (enemy_data se ignora).
@export var enemy_data: EnemyData
# Es un SpawnTable, pero va tipado como Resource A PROPOSITO: si esto dijera "SpawnTable"
# los dos scripts se referenciarian por class_name el uno al otro y Godot se atraganta con
# la referencia circular. Aqui basta con preguntarle si sabe hacer de tabla.
@export var tabla: Resource

# PESO de la tirada ponderada. No es un porcentaje: se normaliza contra la suma de los
# pesos de las entradas DISPONIBLES en el piso (dentro de SU tabla). Aun asi conviene
# escribirlos como si lo fueran (40/30/30, 88/10/2) porque asi se leen de un vistazo.
@export var peso: float = 1.0

# Franja de PROFUNDIDAD en la que esto existe. piso_max = 0 -> sin techo. Puesto en una
# familia entera, hace que los goblins no aparezcan hasta cierto piso.
@export var piso_min: int = 1
@export var piso_max: int = 0


# ¿Existe esto en el piso dado? Una familia VACIA en este piso (p.ej. todos sus bichos
# tienen piso_min mas alto) no esta disponible: si no, se comeria su parte de la tirada
# y no pariria nada.
func disponible(piso: int) -> bool:
	if peso <= 0.0:
		return false
	if piso < piso_min:
		return false
	if piso_max > 0 and piso > piso_max:
		return false
	if es_familia():
		return not tabla.disponibles(piso).is_empty()
	return enemy_data != null


# ¿Esta entrada es una FAMILIA (una tabla anidada) en vez de un bicho suelto?
func es_familia() -> bool:
	return tabla != null and tabla.has_method("disponibles")


# Nombre para los logs / resumen: el del bicho o el de la familia.
func etiqueta() -> String:
	if es_familia():
		return tabla.nombre_familia()
	return enemy_data.enemy_name if enemy_data != null else "?"
