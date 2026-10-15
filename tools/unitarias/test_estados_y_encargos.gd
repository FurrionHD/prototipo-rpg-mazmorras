extends "res://tools/unitarias/caso.gd"
# StatusEffects (scripts/core/status_effects.gd): magnitudes y el viaje de un estado a diccionario y de vuelta.
# Encargos (scripts/core/encargos.gd): los repartos de porcentaje y la curva de desenlace (exito/parcial/fracaso).


# --- Estados -----------------------------------------------------------------------------------

func test_quemadura_es_un_porcentaje_del_golpe() -> void:
	var id: int = StatusEffects.Id.QUEMADURA
	cerca(StatusEffects.magnitud_por_golpe(id, 10.0, 100.0), 100.0 * StatusEffects.QUEMADURA_FRACCION, 0.0001,
		"con golpe manda el golpe")
	cerca(StatusEffects.magnitud_por_golpe(id, 40.0, -1.0), 40.0 * StatusEffects.QUEMADURA_FRACCION, 0.0001,
		"sin golpe, del ataque de quien la pone")
	cerca(StatusEffects.magnitud_por_golpe(id, 0.0, 0.0), 0.5, 0.0001, "nunca baja de 0.5")
	cerca(StatusEffects.magnitud_por_golpe(StatusEffects.Id.VENENO, 10.0, 100.0), -1.0, 0.0001,
		"un estado que no es de brasas devuelve -1 (el de su catalogo)")


func test_sangrado_baja_con_golpes_mas_pesados() -> void:
	var ligero := StatusEffects.sangrado_magnitude(50.0, 0.5)
	var pesado := StatusEffects.sangrado_magnitude(50.0, 2.0)
	cierto(ligero > pesado, "a mas motion value, menos sangrado por golpe (%s vs %s)" % [ligero, pesado])
	cierto(is_finite(StatusEffects.sangrado_magnitude(50.0, 0.0)), "motion value 0 no divide por cero")


func test_todos_los_estados_tienen_definicion() -> void:
	var ids := StatusEffects.all_ids()
	cierto(ids.size() > 10, "el catalogo tiene estados (%d)" % ids.size())
	for id in ids:
		cierto(not StatusEffects.def(id).is_empty(), "el estado %s tiene definicion" % id)
	cierto(StatusEffects.def(-12345).is_empty(), "un id que no existe no tiene definicion")


func test_estado_a_diccionario_y_de_vuelta() -> void:
	for id in StatusEffects.all_ids():
		var inst = StatusEffects.Instance.new(StatusEffects.def(id), 3, 2)
		inst.magnitude = 7.5
		inst.escala = 1.2
		var d := StatusEffects.dict_de_instancia(inst)
		var vuelta = StatusEffects.instancia_de_dict(d)
		if not cierto(vuelta != null, "el estado %s vuelve" % id):
			continue
		igual(vuelta.id(), id, "id")
		igual(vuelta.turns, 3, "turnos de %s" % id)
		cerca(vuelta.magnitude, 7.5, 0.0001, "magnitud de %s" % id)
		cerca(vuelta.escala, 1.2, 0.0001, "escala de %s" % id)


func test_estado_retirado_no_revienta() -> void:
	cierto(StatusEffects.instancia_de_dict({"id": -999, "turns": 2}) == null, "un id retirado se pierde sin petar")


func test_dict_viejo_sin_escala_vuelve_neutro() -> void:
	var id: int = StatusEffects.all_ids()[0]
	var vuelta = StatusEffects.instancia_de_dict({"id": id, "turns": 2, "stacks": 1, "magnitude": 1.0})
	cerca(vuelta.escala, 1.0, 0.0001, "sin 'escala' tiene que volver a 1.0, no a 0")


# --- Encargos ----------------------------------------------------------------------------------

func _suma(d: Dictionary) -> int:
	var s := 0
	for k in d:
		s += int(d[k])
	return s


func test_a_cien_siempre_suma_cien() -> void:
	for pesos in [{1: 1.0, 2: 1.0, 3: 1.0}, {1: 2.0, 2: 1.0}, {1: 0.0, 2: 0.0}, {5: 3.3, 6: 3.3, 7: 3.3},
			{1: 1.0}, {1: -4.0, 2: 1.0}]:
		igual(_suma(Encargos.a_cien(pesos)), 100, "a_cien(%s)" % str(pesos))
	igual(Encargos.a_cien({}).size(), 0, "sin pesos, sin reparto")


func test_desenlace_suma_uno_y_sube_con_el_poder() -> void:
	var antes := -1.0
	for d in [-5.0, -2.0, -1.5, -0.8, -0.3, 0.0, 0.5, 1.0, 3.0]:
		var p := Encargos.probs_por_pasos(d)
		cerca(float(p[0]) + float(p[1]) + float(p[2]), 1.0, 0.0001, "las tres suman 1 con %s pasos" % d)
		cierto(float(p[0]) >= antes, "el exito no puede bajar con mas poder (%s pasos)" % d)
		antes = float(p[0])


func test_desenlace_en_las_anclas() -> void:
	cerca(float(Encargos.probs_por_pasos(1.0)[0]), 1.0, 0.0001, "R + paso = exito seguro")
	cerca(float(Encargos.probs_por_pasos(-2.0)[2]), 1.0, 0.0001, "R - 2 pasos = fracaso seguro")
	cerca(float(Encargos.probs_por_pasos(0.0)[0]), 0.70, 0.0001, "en R, 70 % de exito")


func test_paso_crece_mas_despacio_que_el_requisito() -> void:
	var p1 := Encargos.paso(134.0) / 134.0
	var p2 := Encargos.paso(6000.0) / 6000.0
	cierto(p2 < p1, "el paso relativo baja con requisitos grandes (%s -> %s)" % [p1, p2])


func test_porcentajes_en_texto() -> void:
	igual(Encargos.pct(1.0), "100%", "uno")
	igual(Encargos.pct(0.5), "50%", "mitad")
	igual(Encargos.pct(0.9995), "99.95%", "casi cien no se redondea a 100")
	igual(Encargos.pct(0.0), "0%", "cero")
