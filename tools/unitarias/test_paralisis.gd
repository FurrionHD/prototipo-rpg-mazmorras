extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/status_effects.gd, res://scripts/core/combatant.gd (la PARALISIS)
# 03/11, el Mordisco de la Araña tormentosa: 3 turnos fijos, en cada uno un 40 % de perderlo.

const ID := StatusEffects.Id.PARALISIS


func _uno() -> Combatant:
	return Combatant.new("x", 1, Abilities.new(), 1000.0, 1.0, 1.0, 1.0)


func test_dura_tres_turnos_fijos() -> void:
	var c := _uno()
	c.apply_status(ID)
	for i in 3:
		cierto(c.has_status(ID), "le queda el turno %d" % (i + 1))
		c.tick_statuses()
	cierto(not c.has_status(ID), "tras tres turnos se ha ido")


func test_pierde_el_turno_el_cuarenta_por_ciento() -> void:
	seed(7)
	var perdidos: int = 0
	var n: int = 400
	for i in n:
		var c := _uno()
		c.apply_status(ID)
		var ev: Dictionary = c.tick_statuses()
		cierto(bool(ev.stunned) == bool(ev.paralizado), "si pierde el turno, es por la Paralisis")
		if bool(ev.stunned):
			perdidos += 1
	entre(float(perdidos) / n, 0.33, 0.47, "cerca del 40 %% (%d de %d)" % [perdidos, n])


func test_no_es_un_aturdido() -> void:
	# Lo que corta las cargas al instante mira esto: la Paralisis solo las corta el turno que falla la tirada.
	var c := _uno()
	c.apply_status(ID)
	cierto(not c.aturdido(), "paralizado no cuenta como aturdido")


func test_volver_a_morder_renueva_sin_acumular() -> void:
	var c := _uno()
	c.apply_status(ID)
	c.tick_statuses()
	c.apply_status(ID)
	igual(c.stacks_de(ID), 1, "sigue siendo una")
	for i in 3:
		cierto(c.has_status(ID), "renovada: le queda el turno %d" % (i + 1))
		c.tick_statuses()
	cierto(not c.has_status(ID), "y a los tres se va")


func test_es_un_control() -> void:
	cierto(StatusEffects.es_control(ID), "esta en la familia del control")
	var c := _uno()
	var limpio: float = StatusEffects.prob_final(0.6, null, c, ID)
	c.apply_status(StatusEffects.Id.RAYO)
	cierto(StatusEffects.prob_final(0.6, null, c, ID) > limpio, "el Electrizado la hace mas facil")
	var d := _uno()
	d.apply_status(ID)
	cerca(d.decaimiento_control(ID), 0.5, 0.001, "gasta su escalon: el siguiente control entra a la mitad")
