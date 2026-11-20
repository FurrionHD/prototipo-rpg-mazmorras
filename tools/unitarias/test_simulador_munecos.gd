extends "res://tools/unitarias/caso.gd"
# Cubre: res://tools/simulador_peleas.gd
# EL SIMULADOR, MUÑECOS Y MAGOS (20/11): el corro de 10 muñecos de su dibujo, los muñecos juntos para las areas pequeñas,
# los 14 hechizos de daño (antes el mago llevaba siempre los mismos 5) y el mago con los hechizos que se le fuerzan.

const SIM := "res://tools/simulador_peleas.gd"


func _sim():
	return load(SIM)


# Cuantos muñecos caen dentro de un circulo de 'radio' centrado en 'centro'.
func _dentro(sitios: Array, centro: Vector2, radio: float) -> int:
	var n: int = 0
	for s in sitios:
		if (s as Vector2).distance_to(centro) <= radio:
			n += 1
	return n


func test_el_corro_es_el_del_dibujo() -> void:
	var c: Array = _sim().CORRO_MUNECOS
	igual(c.size(), 10, "10 muñecos en el corro")
	var detras: int = 0
	var delante: int = 0
	var lejos: int = 0
	for s in c:
		var v: Vector2 = s
		if v.x < -60.0:
			detras += 1
		elif v.x > 200.0:
			lejos += 1
		elif v.x > 60.0:
			delante += 1
	igual(detras, 1, "uno detras")
	igual(delante, 3, "tres delante (conos y barridos)")
	igual(lejos, 3, "tres lejos (conos largos, magias de area)")
	cierto((c[0] as Vector2).length() < 60.0, "uno pegado a ti")
	var vistos: Dictionary = {}
	for s in c:
		vistos[s] = true
	igual(vistos.size(), 10, "ninguno encima de otro")


func test_los_muneco_juntos_separan_areas_pequenas_y_grandes() -> void:
	var j: Array = _sim().MUNECOS_JUNTOS
	igual(j.size(), 10, "10 muñecos juntos")
	var centro: Vector2 = j[0]
	var radio_bola: float = (load("res://resources/spells/bola_fuego.tres") as SpellData).forma_radio
	var radio_tormenta: float = (load("res://resources/spells/tormenta.tres") as SpellData).forma_radio
	igual(_dentro(j, centro, radio_bola), 7, "la bola de fuego (radio %.0f) pilla el nucleo de 7" % radio_bola)
	igual(_dentro(j, centro, radio_tormenta), 10, "la tormenta (radio %.0f) a los 10" % radio_tormenta)
	cierto(_dentro(_sim().CORRO_MUNECOS, (_sim().CORRO_MUNECOS[5] as Vector2), radio_tormenta) <= 3,
		"en el corro abierto la tormenta pilla 3 o menos: por eso hacian falta los juntos")
	cierto(_sim().ESC_MUNECO.has("munecos") and _sim().ESC_MUNECO.has("munecos_juntos") and _sim().ESC_MUNECO.has("muneco"),
		"los tres escenarios de muñecos se tratan como muñeco (no pegan, nivel 1, 12 ciclos, maná de sobra)")


func test_los_14_hechizos_de_dano_existen_y_pegan() -> void:
	var lista: Array = _sim().MAGIAS_DANO
	igual(lista.size(), 14, "14 hechizos de daño")
	for m in lista:
		var s: SpellData = load("res://resources/spells/%s.tres" % m)
		cierto(s != null, "%s existe" % m)
		if s != null:
			cierto(s.tipo == SpellData.TipoEfecto.ATAQUE and s.dano_base > 0.0, "%s es de daño" % m)


func test_el_mago_lleva_los_hechizos_que_se_le_fuerzan() -> void:
	var sim = _sim().new()
	var p: PersonajeData = sim._personaje(6, "mago", false, "~rayo;eclipse")
	var nombres: Array = p.equipped_spells.map(func(s): return s.resource_path.get_file().get_basename())
	igual(nombres, ["rayo", "eclipse"], "solo los forzados, en su orden")
	var normal: PersonajeData = sim._personaje(6, "mago", false, "")
	igual(normal.equipped_spells.size(), _sim().MAGIAS_MAGO.size(), "sin forzar, los de siempre")
	sim.free()


# EL ALCANCE DE CADA HECHIZO para el piloto del mago (20/11): las lineas y los conos salen de el y llegan lo que mide su
# largo; antes se leia solo forma_rango (que no tienen) y lanzaba el Torrente desde 220 con un largo de 200.
func test_el_mago_sabe_hasta_donde_llega_cada_hechizo() -> void:
	var sim = _sim()
	for par in [["chorro_agua", "forma_radio"], ["pulso_menor", "forma_radio"], ["brasa", "forma_radio"], ["tormenta", "forma_rango"],
			["rayo", "forma_rango"]]:
		var s: SpellData = load("res://resources/spells/%s.tres" % par[0])
		cerca(sim._alcance_hechizo(s), float(s.get(par[1])), 0.001, "%s llega lo que dice su %s" % [par[0], par[1]])
		cierto(sim._alcance_hechizo(s) > 0.0, "%s tiene alcance" % par[0])


# EL ELEMENTO DE CADA GOLPE Y LOS DISPERSOS (20/11, el jefe: "que diga el elemento de cada golpe: la tormenta, rayo en area y
# agua no"; "la tormenta no tiene objetivo principal"): las dos columnas nuevas, el gancho del golpe vacio fuera del golpe, y
# que hechizos van sin principal (los dispersos: sus golpes caen al azar entre los del area).
func test_elemento_por_golpe_y_dispersos_sin_principal() -> void:
	var cab: String = _sim().CABECERA_P
	cierto(cab.ends_with("|elemento_por_accion|medio_por_pillado|mejor_golpe_por_accion|enemigo_por_accion"),
		"las columnas nuevas, al final (la BD las añade sola)")
	igual(Combatant.elem_golpe, -1, "fuera de un golpe de hechizo el gancho no dice elemento")
	var tormenta: SpellData = load("res://resources/spells/tormenta.tres")
	cierto(tormenta.dispersa and tormenta.elemento_mix.size() == 2, "la Tormenta es dispersa y de dos elementos")
	cierto((load("res://resources/spells/bola_fuego.tres") as SpellData).dispersa, "la Andanada ignea tambien va sin principal")
	cierto(not (load("res://resources/spells/rayo.tres") as SpellData).dispersa, "el Rayo si tiene principal (y rebotes)")
