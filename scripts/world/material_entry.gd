# ============================================================
#  material_entry.gd
#  UNA entrada de una MaterialTable: que material y con que peso sale en la tirada.
#  La PROFUNDIDAD a la que aparece no vive aqui: la lleva el propio MaterialData
#  (piso_min/piso_max), porque es una propiedad del material, no de la tabla.
#  Gemelo de spawn_entry.gd, pero para lo que se recolecta.
# ============================================================

extends Resource
class_name MaterialEntry

@export var material: MaterialData = null
@export var peso: float = 10.0

# --- RAMPA por profundidad (sub-tiers) ---
# Un material no tiene por que entrar de golpe con su peso definitivo. Con los sub-tiers
# (cobre / cobre veteado / cobre profundo) hace falta que el nuevo ASOME raro, CONVIVA con los
# otros y se vuelva DOMINANTE mas abajo. Si fuera un escalon, cada piso tendria un solo material
# y la mezcla no existiria.
#
# peso_pleno <= 0 -> SIN RAMPA: se usa `peso` tal cual en todos los pisos. Es el valor por
# defecto, o sea lo que hacen hoy todas las entradas.
# Con rampa, el peso interpola de `peso` (en piso_debut) a `peso_pleno` (en piso_pleno) y se
# queda ahi. Ojo: la rampa puede ir HACIA ABAJO (el cobre base se apaga segun bajas), y de hecho
# es lo que hace que las proporciones sumen bien.
@export var peso_pleno: float = 0.0
@export var piso_debut: int = 1
@export var piso_pleno: int = 1

# --- OCASO (opcional): el tercer tramo, para materiales que REINAN y luego ceden ---
# Con solo dos tramos (debut -> pleno -> constante) un material nunca deja de ser lo que es: una vez
# alcanza su peso pleno se queda ahi para siempre, y lo unico que puede quitarle protagonismo es que
# OTRO suba mas. Eso vale para los sub-tiers de una veta, pero no para una escalera de especies
# donde cada una tiene SU tramo de pisos: para que la lubina mande en el piso 4 y le deje el sitio al
# bagre en el 7, el gobio tendria que desplomarse de golpe — y eso es un escalon, no una curva.
#
# Con el ocaso, el peso baja de `peso_pleno` (en piso_pleno) a `peso_ocaso` (en piso_ocaso) y ahi se
# queda. Asi cada especie tiene su reinado y se apaga sin dar un salto.
#
# peso_ocaso < 0 -> SIN OCASO: es el valor por defecto y hace exactamente lo de antes (se queda en
# peso_pleno para siempre). Todas las entradas que ya existen siguen igual sin tocar un .tres.
# Ojo: 0.0 SI es un ocaso valido (el material desaparece del todo), por eso el corte es < 0 y no <= 0.
@export var peso_ocaso: float = -1.0
@export var piso_ocaso: int = 0


# El peso de esta entrada EN ESTE PISO, ya con la rampa aplicada.
# Mismo patron de interpolacion que EnemyData.drop_factor_piso: una sola manera de escalar con la
# profundidad en todo el proyecto.
func peso_en(piso: int) -> float:
	if peso_pleno <= 0.0 or piso_pleno <= piso_debut:
		return peso
	if piso <= piso_pleno:
		var t: float = float(piso - piso_debut) / float(piso_pleno - piso_debut)
		return lerpf(peso, peso_pleno, clampf(t, 0.0, 1.0))
	# Ya paso su mejor momento: o se queda en el pleno (lo de siempre) o entra en el ocaso.
	if peso_ocaso < 0.0 or piso_ocaso <= piso_pleno:
		return peso_pleno
	var to: float = float(piso - piso_pleno) / float(piso_ocaso - piso_pleno)
	return lerpf(peso_pleno, peso_ocaso, clampf(to, 0.0, 1.0))


func disponible(piso: int) -> bool:
	return material != null and peso_en(piso) > 0.0 and material.disponible(piso)


func etiqueta() -> String:
	return material.nombre if material != null else "(vacio)"
