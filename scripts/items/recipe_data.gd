# ============================================================
#  recipe_data.gd
#  RECURSO con una RECETA de la boticaria: que POCION sale y que cuesta. Se guarda como .tres.
#
#  Dos formas:
#   - RECETA BASE: pocion_base = null. Sale de puros materiales (baba comun + hierbas).
#   - MEJORA:      pocion_base != null. CONSUME una pocion de ese tipo y la sube un escalon
#                  (base -> +1 con baba de veneno; +1 -> +2 con baba de fuego). La cadena es
#                  SECUENCIAL: para tener una +2 tienes que haber hecho antes la +1.
#
#  Los COSTES se leen de aqui; el texto (resumen) los DERIVA, no se escriben a mano.
# ============================================================

extends Resource
class_name RecipeData

@export var resultado: ConsumableData = null
# null = receta desde cero; con valor = mejora que CONSUME una pocion de este tipo.
@export var pocion_base: ConsumableData = null
# Array (sin tipar) de RecipeIngrediente, como habilidades/efectos en el resto del proyecto:
# los Array tipados escritos a mano en .tres dan problemas al cargar.
@export var ingredientes: Array = []


func nombre() -> String:
	return resultado.nombre if resultado != null else "Receta"


func es_mejora() -> bool:
	return pocion_base != null


# Texto del coste DERIVADO de los campos (nunca a mano): pocion base (si mejora) + cada
# ingrediente con sus unidades. Lo usa el menu de la boticaria.
func resumen() -> String:
	var partes: PackedStringArray = []
	if es_mejora():
		partes.append("1 %s" % pocion_base.nombre)
	for ing in ingredientes:
		if ing != null and ing.material != null:
			partes.append("%d× %s" % [ing.unidades, ing.material.nombre])
	return "  +  ".join(partes)
