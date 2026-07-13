# ============================================================
#  recipe_ingrediente.gd
#  UN ingrediente de una receta: QUE material y CUANTAS UNIDADES pide. Las unidades NO
#  son "items": un item aporta 1/2/3 unidades segun su calidad (MaterialItem.unidades_crafteo).
#  Asi un intacto cuenta por tres y hacen falta menos items para cubrir el coste.
#  Recurso pequeño, mismo patron que StatusApplication.
# ============================================================

extends Resource
class_name RecipeIngrediente

@export var material: MaterialData = null
@export var unidades: int = 1
