# ============================================================
#  material_item.gd
#  UNA UNIDAD de material en la bolsa: la plantilla (MaterialData) + la CALIDAD con la
#  que la conseguiste. La calidad sale del minijuego (mineria/herboristeria) o del drop.
#
#  Misma escala de calidad que el Cristal a proposito (INTACTO/NORMAL/DAÑADO/ROTO, y
#  ROTO = se pierde): el jugador solo tiene que aprender UNA escala para todo el botin.
# ============================================================

extends Resource
class_name MaterialItem

enum Calidad { INTACTO, NORMAL, DANADO, ROTO }

@export var data: MaterialData = null
@export var calidad: Calidad = Calidad.NORMAL


static func crear(d: MaterialData, c: Calidad = Calidad.NORMAL) -> MaterialItem:
	var m := MaterialItem.new()
	m.data = d
	m.calidad = c
	return m


func se_pierde() -> bool:
	return calidad == Calidad.ROTO or data == null


func nombre() -> String:
	return data.nombre if data != null else "Material"


func calidad_texto() -> String:
	match calidad:
		Calidad.INTACTO: return "Intacto"
		Calidad.NORMAL: return "Normal"
		Calidad.DANADO: return "Dañado"
		_: return "Roto"


# Mismos multiplicadores que el Cristal: la calidad vale lo mismo saques lo que saques.
func multiplicador_calidad() -> float:
	match calidad:
		Calidad.INTACTO: return 2.5
		Calidad.NORMAL: return 1.0
		Calidad.DANADO: return 0.45
		_: return 0.0  # ROTO

func peso_mult_calidad() -> float:
	match calidad:
		Calidad.INTACTO: return 1.0
		Calidad.NORMAL: return 0.9
		Calidad.DANADO: return 0.7
		_: return 0.0


# UNIDADES que aporta este item a una RECETA de crafteo (KAN, boticaria). La calidad no
# cambia la receta: cambia CUANTOS items necesitas. Un intacto rinde por tres, un dañado
# por uno; asi el que se esfuerza en el minijuego (o tiene suerte) gasta menos botin.
# ROTO no llega nunca a la bolsa (se pierde), pero por si acaso aporta 0.
func unidades_crafteo() -> int:
	match calidad:
		Calidad.INTACTO: return 3
		Calidad.NORMAL: return 2
		Calidad.DANADO: return 1
		_: return 0


# El valor sube en CURVA con el grado (como el cristal con la categoria): los materiales
# de arriba valen mucho mas, y no un poco mas.
const VALOR_TIER_FACTOR := 0.35

func valor_estimado() -> int:
	if data == null:
		return 0
	var tier_mult: float = 1.0 + VALOR_TIER_FACTOR * float(maxi(1, data.tier) - 1) * float(data.tier)
	return int(round(float(data.valor_base) * tier_mult * multiplicador_calidad()))


func peso() -> float:
	if data == null:
		return 0.0
	return maxf(0.1, data.peso_base * peso_mult_calidad())


# Color del item (para el pickup del suelo y la UI): el del material, apagado si esta dañado.
func color() -> Color:
	var c: Color = data.color if data != null else Color.WHITE
	match calidad:
		Calidad.INTACTO: return c.lightened(0.25)
		Calidad.NORMAL: return c
		_: return c.darkened(0.35)
