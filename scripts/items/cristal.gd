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


# Multiplicador de VALOR segun la calidad (precios bien marcados).
func multiplicador_calidad() -> float:
	match calidad:
		Calidad.INTACTO: return 2.5
		Calidad.NORMAL: return 1.0
		Calidad.DANADO: return 0.45
		_: return 0.0  # ROTO

# Multiplicador de PESO segun la calidad (dañado pesa menos).
func peso_mult_calidad() -> float:
	match calidad:
		Calidad.INTACTO: return 1.0
		Calidad.NORMAL: return 0.9
		Calidad.DANADO: return 0.7
		_: return 0.0


func se_pierde() -> bool:
	return calidad == Calidad.ROTO


func calidad_texto() -> String:
	match calidad:
		Calidad.INTACTO: return "Intacto"
		Calidad.NORMAL: return "Normal"
		Calidad.DANADO: return "Dañado"
		_: return "Roto"


# Valor base por CATEGORIA en CURVA (no lineal): las categorias bajas valen
# poco y las altas suben fuerte. valor_base = categoria^2 * factor.
const VALOR_CAT_FACTOR := 4.0
func valor_base_categoria() -> int:
	return int(round(categoria * categoria * VALOR_CAT_FACTOR))

# Valor ESTIMADO (para el HUD). El precio real con azar se calcula en la tienda.
func valor_estimado() -> int:
	return int(round(valor_base_categoria() * multiplicador_calidad()))


# Peso del cristal: mayor categoria = mas pesado, y la calidad lo ajusta
# (dañado pesa menos). PESO_FACTOR global por si quieres aligerar todo.
const PESO_FACTOR := 1.0
func peso() -> float:
	return maxf(0.4, categoria * PESO_FACTOR * peso_mult_calidad())
