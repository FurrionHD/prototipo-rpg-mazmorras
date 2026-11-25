extends "res://tools/unitarias/caso.gd"
# LAS CAPAS DE ESQUIVA (25/11, idea del jefe): si el golpe pasa tu esquiva normal, se vuelve a tirar con cada capa que
# lleves (la de la guardia, la del estado Esquivo...). Total = 1 - (1-normal)(1-capa1)(1-capa2).

const N := 20000


func _par() -> Array:
	var a := Combatant.new("a", 1, Abilities.new(), 1000.0, 10.0, 10.0, 10.0)
	var d := Combatant.new("d", 1, Abilities.new(), 1000.0, 10.0, 10.0, 10.0)
	return [a, d]


func _esquivadas(a: Combatant, d: Combatant) -> float:
	seed(12345)
	var n := 0
	for i in N:
		if bool(StatsMath.resolve_attack(a, d)["evaded"]):
			n += 1
	return float(n) / float(N)


func test_sin_capas_la_normal() -> void:
	var p: Array = _par()
	var normal: float = float(StatsMath.resolve_attack(p[0], p[1])["evade_p"])
	cerca(_esquivadas(p[0], p[1]), normal, 0.015, "sin capas, solo la esquiva normal (%.3f)" % normal)
	igual((p[1] as Combatant).capas_esquiva().size(), 0, "y no tiene capas")


func test_guardia_y_esquivo_tres_capas() -> void:
	var p: Array = _par()
	var a: Combatant = p[0]
	var d: Combatant = p[1]
	var normal: float = float(StatsMath.resolve_attack(a, d)["evade_p"])
	d.en_guardia = true
	d.guardia_capa = 0.2
	cierto(is_equal_approx(float(StatsMath.resolve_attack(a, d)["evade_p"]), normal),
		"la guardia ya NO se suma a la esquiva normal (ni sube su techo)")
	cerca(_esquivadas(a, d), 1.0 - (1.0 - normal) * 0.8, 0.015, "con la guardia: dos capas")
	d.apply_status(StatusEffects.Id.ESQUIVO, 2, -1.0, 1, false, -1, 0.0, 0.25)
	igual(d.capas_esquiva().size(), 2, "guardia y Esquivo: dos capas encima de la normal")
	cerca(_esquivadas(a, d), 1.0 - (1.0 - normal) * 0.8 * 0.75, 0.015, "con las dos: tres capas")
	d.salir_de_guardia()
	igual(d.capas_esquiva().size(), 1, "al salir de la guardia se va su capa (queda la del Esquivo)")
