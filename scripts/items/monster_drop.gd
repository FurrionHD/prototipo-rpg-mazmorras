# ============================================================
#  monster_drop.gd
#  DROP raro de un monstruo (material), aparte del cristal. Tiene una
#  probabilidad baja de salir al extraer (ajustable por enemigo) y se recoge
#  automaticamente. Su calidad (Defectuoso/Normal/Excelente) sale de una
#  tirada en una franja que se desplaza segun la categoria del cristal.
# ============================================================

extends Resource
class_name MonsterDrop

enum Calidad { DEFECTUOSO, NORMAL, EXCELENTE }

@export var nombre: String = "Material"
@export var calidad: Calidad = Calidad.NORMAL


func calidad_texto() -> String:
	match calidad:
		Calidad.DEFECTUOSO: return "Defectuoso"
		Calidad.NORMAL: return "Normal"
		_: return "Excelente"


# Valor ESTIMADO (para el HUD). El precio real con azar se calcula en la tienda.
func valor_estimado() -> int:
	match calidad:
		Calidad.DEFECTUOSO: return 20
		Calidad.NORMAL: return 50
		_: return 120


# Peso del material (fijo, ligero).
func peso() -> float:
	return 2.0


# Convierte un valor numerico (de la franja) en calidad. Umbrales ajustables.
# (Permisivo a proposito: el drop ya es raro, asi que su calidad no es dura.)
static func calidad_desde_valor(valor: int) -> Calidad:
	if valor <= 2:
		return Calidad.DEFECTUOSO
	elif valor <= 3:
		return Calidad.NORMAL
	else:
		return Calidad.EXCELENTE
