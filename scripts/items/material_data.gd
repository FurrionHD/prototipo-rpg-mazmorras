# ============================================================
#  material_data.gd
#  PLANTILLA de un material (un .tres por material). Es la IDENTIDAD: que es, de que
#  familia, cuanto pesa y cuanto vale. Lo que llevas en la bolsa NO es esto, es un
#  MaterialItem (esta plantilla + la calidad con la que lo conseguiste).
#
#  Las dos FAMILIAS no se mezclan y es lo que la tienda y la forja van a mirar:
#    - CORRIENTE: babas, plantas, minerales, cuero. De aqui salen las POCIONES.
#    - NUCLEO:    el drop raro del monstruo. De aqui sale la MEJORA DE EQUIPO.
#
#  La 'descripcion' es SOLO SABOR: ni un numero escrito a mano. Los numeros los
#  deriva resumen() de los campos.
# ============================================================

extends Resource
class_name MaterialData

enum Familia { CORRIENTE, NUCLEO }
# LINGOTE va el ULTIMO a proposito: los .tres guardan el enum como numero, asi que meterlo
# en medio le cambiaria el tipo a todos los materiales que ya existen. No se recolecta: sale
# de FUNDIR mineral en el herrero, y es lo unico con lo que se forja.
enum Tipo { BABA, PLANTA, MINERAL, CUERO, NUCLEO, LINGOTE }
# A QUE se le puede meter este nucleo. Los del slime van al ARMA; el de la rata, a la
# ARMADURA. CUALQUIERA = comodin (no lo usa ningun nucleo hoy, pero el campo lo admite).
enum UsoMejora { CUALQUIERA, ARMA, ARMADURA }

@export var id: StringName = &"material"
@export var nombre: String = "Material"
@export var descripcion: String = ""

@export var familia: Familia = Familia.CORRIENTE
@export var tipo: Tipo = Tipo.MINERAL

# GRADO del material: sube el valor y el peso. Es el eje "de que profundidad viene esto".
@export var tier: int = 1

# Lo que CUESTA sacarlo del sitio: dureza de la veta (mineral) o fragilidad del tallo
# (planta). Es la entrada de la dificultad del minijuego, contra tu Fuerza o tu Destreza.
# Los materiales que NO se recolectan (baba, cuero, nucleo) no la usan.
@export var exigencia: float = 30.0

@export var peso_base: float = 1.5
@export var valor_base: int = 20

# --- SOLO para la familia NUCLEO: hasta donde deja subir el equipo ---
# El nucleo no es "un material mas caro": es el PERMISO para seguir mejorando. Un nucleo
# de slime te deja llegar a +3; uno de un bicho hondo, mucho mas lejos. El techo real del
# sistema es el de la rareza mas alta (Upgrades.RAREZA_SLOTS, obra maestra = 12): no se
# escribe aqui a mano, se lee de alli (ver mejora_tope).
# 0 = este material no mejora nada (todos los CORRIENTES).
@export var mejora_max: int = 0
@export var uso_mejora: UsoMejora = UsoMejora.CUALQUIERA

# Placeholder visual (el arte va al final): color del nodo en el mapa y del item del suelo.
@export var color: Color = Color(0.7, 0.7, 0.75)

# En que profundidad aparece. piso_max = 0 -> sin tope (mismo criterio que SpawnEntry).
@export var piso_min: int = 1
@export var piso_max: int = 0


func disponible(piso: int) -> bool:
	if piso < piso_min:
		return false
	return piso_max <= 0 or piso <= piso_max


func familia_texto() -> String:
	return "Corriente" if familia == Familia.CORRIENTE else "Núcleo"


func tipo_texto() -> String:
	match tipo:
		Tipo.BABA: return "Baba"
		Tipo.PLANTA: return "Planta"
		Tipo.MINERAL: return "Mineral"
		Tipo.CUERO: return "Cuero"
		_: return "Núcleo"


# ¿Se saca con el PICO? (mineral) ¿Con la HOZ? (planta) El resto cae de los monstruos.
func es_veta() -> bool:
	return tipo == Tipo.MINERAL

func es_planta() -> bool:
	return tipo == Tipo.PLANTA


# ¿Este material es un nucleo que sirve para MEJORAR el equipo?
func mejora_equipo() -> bool:
	return familia == Familia.NUCLEO and mejora_max > 0

# Tope de mejora EFECTIVO: el campo, pero nunca por encima del maximo real del sistema
# (la rareza mas alta de Upgrades). Asi un .tres no puede prometer un +20 que no existe.
func mejora_tope() -> int:
	return clampi(mejora_max, 0, Upgrades.RAREZA_SLOTS[Upgrades.RAREZA_SLOTS.size() - 1])

func uso_mejora_texto() -> String:
	match uso_mejora:
		UsoMejora.ARMA: return "armas"
		UsoMejora.ARMADURA: return "armaduras"
		_: return "equipo"


# Los NUMEROS visibles salen de aqui, no de la descripcion.
func resumen() -> String:
	var partes: PackedStringArray = [
		"%s · %s · grado %d" % [familia_texto(), tipo_texto(), tier],
		"valor base %d" % valor_base,
		"peso %.1f" % peso_base,
	]
	if es_veta() or es_planta():
		partes.append("exigencia %d" % roundi(exigencia))
	if mejora_equipo():
		partes.append("mejora hasta +%d · %s" % [mejora_tope(), uso_mejora_texto()])
	var pisos: String = "piso %d+" % piso_min if piso_max <= 0 else "pisos %d-%d" % [piso_min, piso_max]
	partes.append(pisos)
	return "  ·  ".join(partes)
