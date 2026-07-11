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

# OJO: el VENENO no es un elemento, es solo un ESTADO (DoT). Quien resista el veneno lo
# declara con el override 'inmune_estados', no con una afinidad.
enum Elemento { NINGUNO, FUEGO, AGUA, RAYO }

const NOMBRE := {
	Elemento.NINGUNO: "Físico",
	Elemento.FUEGO: "Fuego",
	Elemento.AGUA: "Agua",
	Elemento.RAYO: "Rayo",
}

# TABLA DE TIPOS por defecto: perfil de resistencia segun la AFINIDAD del defensor
# (multiplicador que RECIBE de cada elemento). Lo que no aparezca = 1.0 (neutro).
#   FUEGO: resiste Fuego (×0.5), débil a Agua (×1.5).
#   AGUA:  resiste Agua y Fuego (×0.5), débil a Rayo (×1.5).
#   RAYO:  resiste Rayo. SIN DEBILIDAD todavia (ya llegara su counter, p.ej. Tierra); mientras
#          tanto su imbuicion de cuerpo lo paga con mas maná y menos turnos.
const PERFIL_DEFECTO := {
	Elemento.FUEGO: { Elemento.FUEGO: 0.5, Elemento.AGUA: 1.5 },
	Elemento.AGUA: { Elemento.AGUA: 0.5, Elemento.FUEGO: 0.5, Elemento.RAYO: 1.5 },
	Elemento.RAYO: { Elemento.RAYO: 0.5 },
}


# Estados a los que te hace INMUNE tener esta afinidad. La inmunidad es CONSECUENCIA del
# elemento, no un dato suelto: un ser de fuego no se quema, y uno de agua tampoco (la apaga).
# Lo aprovechan los enemigos (slime de fuego) y el jugador al imbuirse el CUERPO.
const INMUNIDAD_POR_AFINIDAD := {
	Elemento.FUEGO: [StatusEffects.Id.QUEMADURA],    # eres fuego
	Elemento.AGUA: [StatusEffects.Id.QUEMADURA],     # el agua apaga el fuego
	Elemento.RAYO: [StatusEffects.Id.RAYO],
}

# Resistencia al ATURDIMIENTO por afinidad: multiplica la probabilidad de aturdir que RECIBES.
# El cuerpo imbuido de Rayo encaja mejor los golpes que atontan: RESISTENTE, no inmune.
const STUN_TAKEN_POR_AFINIDAD := {
	Elemento.RAYO: 0.6,
}

# Estados que AMPLIFICAN el daño elemental que RECIBE quien los sufre.
# Mojado -> el rayo te frie (+50%). Vive AQUI y no en status_effects.gd porque elements.gd ya
# depende de StatusEffects: al reves seria un CICLO de dependencias y no compilaria.
const AMPLIFICA_POR_ESTADO := {
	StatusEffects.Id.MOJADO: { Elemento.RAYO: 1.5 },
}


# Nombre legible de un elemento (para logs / UI).
static func nombre(elem: int) -> String:
	return String(NOMBRE.get(elem, "?"))


# Estados a los que es inmune quien tenga esta afinidad ([] si NINGUNO).
static func inmunidades_de(elem: int) -> Array:
	return INMUNIDAD_POR_AFINIDAD.get(elem, [])


# Multiplicador de la prob. de aturdir que recibe quien tenga esta afinidad (1.0 = neutro).
static func stun_taken_por_afinidad(elem: int) -> float:
	return float(STUN_TAKEN_POR_AFINIDAD.get(elem, 1.0))


# Amplificacion del daño de 'elem' por los ESTADOS del defensor (Mojado -> +50% Rayo).
static func mult_por_estados(elem: int, defender) -> float:
	var m := 1.0
	for e in defender.statuses:
		var tabla: Dictionary = AMPLIFICA_POR_ESTADO.get(e.id(), {})
		m *= float(tabla.get(elem, 1.0))
	return m


# Multiplicador de daño que RECIBE 'defender' de un ataque de elemento 'elem'.
# Prioridad: override propio del defensor > perfil por defecto de su afinidad > 1.0.
# Encima MULTIPLICA la amplificacion de sus ESTADOS (Mojado -> +50% de Rayo).
# 'defender' es un Combatant (tiene .elemento, .resist_elemental y .statuses).
static func mult_recibido(elem: int, defender) -> float:
	if elem == Elemento.NINGUNO or defender == null:
		return 1.0
	var base: float
	if defender.resist_elemental.has(elem):
		base = float(defender.resist_elemental[elem])
	else:
		var perfil: Dictionary = PERFIL_DEFECTO.get(defender.elemento, {})
		base = float(perfil.get(elem, 1.0))
	return base * mult_por_estados(elem, defender)
