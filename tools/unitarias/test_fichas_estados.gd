extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/status_effects.gd (Instance.resumen, la ficha de cada estado)
# NINGUN ESTADO MUDO (05/11, el jefe: el Congelado "no tiene descripcion", en la ficha de inspeccion solo salia su nombre
# y sus turnos). Cada estado del catalogo tiene que decir, debajo de la cabecera, que te hace.


func test_cada_estado_dice_que_hace() -> void:
	var mudos: Array = []
	for id in StatusEffects.all_ids():
		var c := Combatant.new("Prueba", 1, Abilities.new(), 100.0, 1.0, 1.0, 1.0)
		c.apply_status(int(id), 3, 5.0)
		if c.statuses.is_empty():
			continue   # los que no se ponen asi (inmunes, de otra via): no hay ficha que pintar
		var lineas: PackedStringArray = String(c.statuses[0].resumen()).split("\n")
		var utiles: int = 0
		for l in lineas.slice(1):
			if not l.begins_with("Acumulaciones"):
				utiles += 1
		if utiles == 0:
			mudos.append(String(StatusEffects.def(int(id)).get("nombre", str(id))))
	igual(mudos, [], "estados cuya ficha no dice que hacen")


func test_el_congelado_dice_que_andas_la_mitad() -> void:
	var c := Combatant.new("Prueba", 1, Abilities.new(), 100.0, 1.0, 1.0, 1.0)
	c.apply_status(StatusEffects.Id.CONGELACION, 1)
	var r: String = c.statuses[0].resumen()
	cierto(r.contains("recorre un %d %%" % roundi(StatusEffects.CONGELACION_MOV * 100.0)), "la ficha dice cuanto anda: " + r)
