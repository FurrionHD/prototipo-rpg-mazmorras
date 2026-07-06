# ============================================================
#  spell_data.gd
#  RECURSO (Resource) con los DATOS de un HECHIZO. Se guarda como .tres.
#
#  Los hechizos se lanzan RECITANDO un encantamiento: una o varias FRASES en
#  orden. En combate, cada turno el juego muestra un test tipo examen (a/b/c/d)
#  con la frase correcta mezclada con distractores del repositorio (SpellBook).
#  Aciertas -> avanzas a la siguiente frase; fallas -> backfire (te daña).
#
#  La LONGITUD del hechizo = numero de frases:
#    1 frase  = CORTO   (T1 recitas, T2 dispara)
#    2 frases = MEDIO   (T1, T2 recitas, T3 dispara)
#    3 frases = LARGO   (T1, T2, T3 recitas, T4 dispara)
#
#  De momento solo se implementa el tipo ATAQUE (daño). BUFF/DEBUFF quedan
#  definidos en el modelo pero se implementan en una tarea futura (con KAN-58).
# ============================================================

extends Resource
class_name SpellData

enum TipoEfecto { ATAQUE, BUFF, DEBUFF }

@export var nombre: String = "Hechizo"
@export var tipo: TipoEfecto = TipoEfecto.ATAQUE

# Frases del encantamiento EN ORDEN. Se recitan una por turno. El tamaño define
# corto/medio/largo. Deberian salir del repositorio de SpellBook.REPOSITORIO.
@export var frases: Array[String] = []

# Coste de maná (se descuenta AL EMPEZAR el casteo; si fallas, se pierde).
@export var coste_mana: int = 5

# RAW del hechizo: se escala con la Magia del lanzador (magia_factor) y con el
# magic_amp del arma (bastones/varitas, futuro KAN-95). PROVISIONAL -> Excel.
@export var dano_base: float = 10.0

@export_multiline var descripcion: String = ""


# Numero de frases (= turnos de recitado). 1=corto, 2=medio, 3=largo.
func longitud() -> int:
	return frases.size()
