# ============================================================
#  cristal.gd
#  Un CRISTAL que se extrae del cuerpo de un enemigo (Fase 5).
#  Tiene:
#    - categoria: numero/tier (mayor = mas valioso). Lo fija el enemigo.
#    - calidad: resultado del minijuego de extraccion.
#  El valor en dinero (con su aleatoriedad) se calcula al venderlo en la
#  tienda (Fase 7), a partir de la categoria y la calidad.
# ============================================================

extends Resource
class_name Cristal

# Calidad resultante del minijuego: ROTO = se pierde (no obtienes cristal).
enum Calidad { INTACTO, NORMAL, DANADO, ROTO }

@export var categoria: int = 1
@export var calidad: Calidad = Calidad.NORMAL


# Multiplicador de valor segun la calidad.
func multiplicador_calidad() -> float:
	match calidad:
		Calidad.INTACTO: return 1.0
		Calidad.NORMAL: return 0.7
		Calidad.DANADO: return 0.4
		_: return 0.0  # ROTO


func se_pierde() -> bool:
	return calidad == Calidad.ROTO


func calidad_texto() -> String:
	match calidad:
		Calidad.INTACTO: return "Intacto"
		Calidad.NORMAL: return "Normal"
		Calidad.DANADO: return "Dañado"
		_: return "Roto"
