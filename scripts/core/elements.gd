# ============================================================
#  elements.gd  (class_name Elementos)
#  Sistema ELEMENTAL: afinidades con resistencias/debilidades.
#  El daño elemental (hechizos ahora; arma imbuida en el futuro) se multiplica
#  segun el DEFENSOR: su override propio manda, si no la TABLA DE TIPOS por
#  defecto de su afinidad, si no neutro (×1.0).
#  Extensible: para meter Hielo u otros, se añaden al enum y a la tabla.
# ============================================================

extends RefCounted
class_name Elementos

enum Elemento { NINGUNO, FUEGO, AGUA, RAYO, VENENO }

const NOMBRE := {
	Elemento.NINGUNO: "Físico",
	Elemento.FUEGO: "Fuego",
	Elemento.AGUA: "Agua",
	Elemento.RAYO: "Rayo",
	Elemento.VENENO: "Veneno",
}

# TABLA DE TIPOS por defecto: perfil de resistencia segun la AFINIDAD del defensor
# (multiplicador que RECIBE de cada elemento). Lo que no aparezca = 1.0 (neutro).
#   FUEGO: resiste Fuego (×0.5), débil a Agua (×1.5).
#   AGUA:  resiste Agua y Fuego (×0.5), débil a Rayo (×1.5).
#   RAYO:  resiste Rayo.
#   VENENO: resiste Veneno.
const PERFIL_DEFECTO := {
	Elemento.FUEGO: { Elemento.FUEGO: 0.5, Elemento.AGUA: 1.5 },
	Elemento.AGUA: { Elemento.AGUA: 0.5, Elemento.FUEGO: 0.5, Elemento.RAYO: 1.5 },
	Elemento.RAYO: { Elemento.RAYO: 0.5 },
	Elemento.VENENO: { Elemento.VENENO: 0.5 },
}


# Nombre legible de un elemento (para logs / UI).
static func nombre(elem: int) -> String:
	return String(NOMBRE.get(elem, "?"))


# Multiplicador de daño que RECIBE 'defender' de un ataque de elemento 'elem'.
# Prioridad: override propio del defensor > perfil por defecto de su afinidad > 1.0.
# 'defender' es un Combatant (tiene .elemento y .resist_elemental).
static func mult_recibido(elem: int, defender) -> float:
	if elem == Elemento.NINGUNO or defender == null:
		return 1.0
	if defender.resist_elemental.has(elem):
		return float(defender.resist_elemental[elem])
	var perfil: Dictionary = PERFIL_DEFECTO.get(defender.elemento, {})
	return float(perfil.get(elem, 1.0))
