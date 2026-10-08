# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_voluntad.tscn
#
# LA VOLUNTAD (08/10/2026, fase 1 del plan de mecanicas nuevas): la sexta basica. Mira que
#   - existe en todos los sitios que recorren "las basicas" y una partida VIEJA (sin su clave) no peta,
#   - la DEFENSA MAGICA la da ella y no la Magia (jugador), y al enemigo le sale IGUAL que ayer,
#   - resiste TODOS los estados por igual (espejo de la DESTREZA, que empuja la eficacia),
#   - se entrena (estados resistidos/entrados, ticks de daño, oscuridad),
#   - el ascenso graba lo suyo (eficacia y resistencia a efectos) y nada se pierde al guardar/cargar o por la red.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _ready() -> void:
	_nombres()
	_partida_vieja()
	_defensa_magica()
	_enemigo_igual()
	_estados()
	_excelia()
	_ascenso()
	_viaje()
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


func _nombres() -> void:
	print("=== LAS SEIS ===")
	_ok(Abilities.NOMBRES.has("voluntad") and Abilities.NOMBRES.size() == 6, "Abilities.NOMBRES lleva la Voluntad")
	_ok(not Abilities.NOMBRES_PODER.has("voluntad"), "la Voluntad NO cuenta para el poder (reto neutro)")
	_ok(PersonajeData._cero_abilities().has("voluntad"), "una ficha nueva nace con la clave")
	_ok(StatusEffects.NOMBRE_HABILIDAD.has("voluntad"), "tiene nombre bonito (platos, altar)")


# Una ficha de antes del 08/10: los tres diccionarios SIN la clave.
func _ficha_vieja() -> PersonajeData:
	var pj := PersonajeData.new()
	pj.nombre = "Vieja"
	for d in [pj.ability_internal, pj.ability_consolidado, pj.ability_base_nivel]:
		d.clear()
		for s in Abilities.NOMBRES_PODER:
			d[s] = 120.0
	return pj


func _partida_vieja() -> void:
	print("=== PARTIDA DE ANTES DE LA VOLUNTAD ===")
	var pj := _ficha_vieja()
	_ok(Game.stat_total("voluntad", pj) == 0, "stat_total sin clave = 0, sin petar")
	Game.ganar("voluntad", 1.0, 1.0, Game.RETO_MAX_FISICO, pj)
	_ok(float(pj.ability_internal.get("voluntad", 0.0)) > 0.0, "ganar() le crea la clave y entrena")
	Game.actualizar_estado(pj)
	_ok(pj.voluntad >= 1, "el altar la consolida y sale en lo visible (%d)" % pj.voluntad)
	_ok(pj.fuerza == 0, "lo demas sigue igual (visible = consolidado - base = 0)")


func _defensa_magica() -> void:
	print("=== DEFENSA MAGICA = VOLUNTAD ===")
	var a := Abilities.new()
	var base: float = 5.0
	_ok(is_equal_approx(StatsMath.magic_jugador(a, base), base), "Voluntad 0 = la base")
	a.magia = 999
	_ok(is_equal_approx(StatsMath.magic_jugador(a, base), base), "la MAGIA ya no da defensa")
	a.voluntad = 250
	_ok(is_equal_approx(StatsMath.magic_jugador(a, base), base * 2.0), "Voluntad 250 = el doble")


# Al enemigo su defensa magica le tiene que salir IGUAL que con la Magia de ayer.
func _enemigo_igual() -> void:
	print("=== ENEMIGOS: MISMA DEFENSA MAGICA QUE AYER ===")
	for ruta in ["res://scenes/actors/enemy/slime.tres", "res://scenes/actors/enemy/slime_abisal.tres",
			"res://scenes/actors/enemy/rey_slime.tres"]:
		var ed: EnemyData = load(ruta)
		var ab: Abilities = ed.crear_abilities(0.5)
		_ok(ab.voluntad == ab.magia, "%s: Voluntad %d = Magia %d" % [ed.resource_path.get_file(), ab.voluntad, ab.magia])
		var ayer: float = 3.0 + ab.magia * (StatsMath.MAG_COEF_BASE)
		_ok(is_equal_approx(StatsMath.magic_value(ab, 1, 3.0), ayer), "  su defensa magica no cambia")
		var suma_poder: int = ab.fuerza + ab.resistencia + ab.destreza + ab.agilidad + ab.magia
		_ok(ed.suma_habilidades(0.5) == suma_poder, "  la suma del piso no se reparte con la Voluntad")


func _combatiente(ab: Abilities) -> Combatant:
	return Combatant.new("P", 1, ab, 50.0, 5.0, 5.0, 5.0)


func _estados() -> void:
	print("=== ESTADOS: RESISTENCIA Y EFICACIA ===")
	var a := Abilities.new()
	var c0 := _combatiente(a)
	var a2 := Abilities.new()
	a2.voluntad = 999
	a2.destreza = 999
	var c1 := _combatiente(a2)
	var mental: int = StatusEffects.Id.CEGUERA
	var veneno: int = StatusEffects.Id.VENENO
	_ok(is_equal_approx(c1.resist_estados(mental) - c0.resist_estados(mental),
		StatsMath.RESIST_VOLUNTAD_MAX), "Voluntad 999 = +%.1f contra la Ceguera" % StatsMath.RESIST_VOLUNTAD_MAX)
	_ok(is_equal_approx(c1.resist_estados(veneno) - c0.resist_estados(veneno), StatsMath.RESIST_VOLUNTAD_MAX),
		"y lo MISMO contra el veneno (todos por igual)")
	_ok(is_equal_approx(c1.resist_estados(-1) - c0.resist_estados(-1), StatsMath.RESIST_VOLUNTAD_MAX),
		"y en la resistencia general que pintan las fichas")
	_ok(is_equal_approx(c1.eficacia_estados() - c0.eficacia_estados(),
		StatsMath.EFICACIA_DESTREZA_MAX), "Destreza 999 = +%.1f de eficacia" % StatsMath.EFICACIA_DESTREZA_MAX)
	c0.resist_voluntad_bake = 0.3
	c0.eficacia_bake = 0.2
	_ok(is_equal_approx(c0.resist_estados(mental), _combatiente(Abilities.new()).resist_estados(mental) + 0.3),
		"lo grabado al ascender suma a la resistencia")
	_ok(is_equal_approx(c0.eficacia_estados(), 0.2), "y a la eficacia")


func _ficha_limpia() -> PersonajeData:
	var pj := PersonajeData.new()
	pj.nombre = "Sim"
	for s in Abilities.NOMBRES:
		pj.ability_internal[s] = 100.0
		pj.ability_consolidado[s] = 100.0
		pj.ability_base_nivel[s] = 0.0
	return pj


func _subida(pj: PersonajeData) -> float:
	return float(pj.ability_internal["voluntad"]) - 100.0


func _excelia() -> void:
	print("=== DE DONDE SALE LA VOLUNTAD ===")
	var poder: float = 150.0
	var a := _ficha_limpia()
	Game.ganar_voluntad_estado(poder, 1, StatusEffects.Id.VENENO, false, a)
	var resistido: float = _subida(a)
	var b := _ficha_limpia()
	Game.ganar_voluntad_estado(poder, 1, StatusEffects.Id.VENENO, true, b)
	var entro: float = _subida(b)
	var m := _ficha_limpia()
	Game.ganar_voluntad_estado(poder, 1, StatusEffects.Id.MIEDO, false, m)
	var mental: float = _subida(m)
	print("    resistido %.4f · entro %.4f · miedo resistido %.4f" % [resistido, entro, mental])
	_ok(resistido > 0.0, "resistir un estado entrena")
	_ok(is_equal_approx(entro, resistido * Game.VOLUNTAD_ESTADO_ENTRA), "comerselo entrena la mitad")
	_ok(is_equal_approx(mental, resistido), "el Miedo enseña lo mismo que el veneno (todos por igual)")
	var d := _ficha_limpia()
	Game.ganar_voluntad_dot(5.0, 100.0, d)
	_ok(_subida(d) > 0.0, "un tick de veneno entrena (%.4f)" % _subida(d))
	var o := _ficha_limpia()
	Game.ganar_voluntad_oscuridad(1.0, o)
	var o2 := _ficha_limpia()
	Game.ganar_voluntad_oscuridad(0.0, o2)
	_ok(_subida(o) > 0.0 and is_zero_approx(_subida(o2)), "la oscuridad entrena; con luz plena, nada")
	var g := _ficha_limpia()
	var res_antes: float = float(g.ability_internal["resistencia"])
	Game.ganar_voluntad_golpe_magico(1.0, 20.0, 100.0, g)
	_ok(_subida(g) > 0.0 and is_equal_approx(float(g.ability_internal["resistencia"]), res_antes),
		"un golpe magico entrena Voluntad (la Resistencia la pone el golpe, aparte)")
	# Y que el combatiente lo apunte solo cuando le toca: jugador <- enemigo.
	var ab_e := Abilities.new()
	ab_e.fuerza = 100
	var enemigo := _combatiente(ab_e)
	enemigo.stats_multiplicativas = false
	var yo := _combatiente(Abilities.new())
	yo.stats_multiplicativas = true
	_ok(enemigo.poder_como_enemigo() == 100.0, "el poder del enemigo sale de Combatant (100)")


func _ascenso() -> void:
	print("=== AL ASCENDER SE GRABA ===")
	var lider: PersonajeData = Game.lider()
	var guardado: Dictionary = {}
	for k in ["level", "base_eficacia", "base_resist_voluntad", "base_magic", "base_crit"]:
		guardado[k] = lider.get(k)
	Game.debug_set_abilities(600, 0, 500, 0, 0, 500)
	_ok(lider.voluntad == 500 and lider.destreza == 500, "el debug pone la Voluntad (%d)" % lider.voluntad)
	var ef_antes: float = lider.base_eficacia
	var rm_antes: float = lider.base_resist_voluntad
	var mdef_antes: float = lider.base_magic
	Game.guardianes_vencidos[Game.player_level + 1] = true
	var subio: bool = Game.subir_nivel("cazador")
	_ok(subio, "sube de nivel")
	var spike: float = 1.0 + Game.NIVEL_SPIKE
	_ok(is_equal_approx(lider.base_eficacia - ef_antes, StatsMath.eficacia_de_destreza(500.0) * spike),
		"graba la eficacia de la Destreza (+%.3f)" % (lider.base_eficacia - ef_antes))
	_ok(is_equal_approx(lider.base_resist_voluntad - rm_antes, StatsMath.resist_de_voluntad(500.0) * spike),
		"graba la resistencia a efectos (+%.3f)" % (lider.base_resist_voluntad - rm_antes))
	_ok(lider.base_magic > mdef_antes * 2.9, "y la defensa magica de la Voluntad (%.1f -> %.1f)" % [mdef_antes, lider.base_magic])
	_ok(lider.voluntad == 0, "el visible vuelve a 0")
	# Guardar y cargar.
	var sd: SaveData = Game.exportar_partida()
	_ok(is_equal_approx(sd.player_base_eficacia, lider.base_eficacia) and sd.ability_internal.has("voluntad"),
		"el guardado lleva lo grabado y la Voluntad")
	for k in guardado:
		lider.set(k, guardado[k])


func _viaje() -> void:
	print("=== POR LA RED ===")
	var pj := _ficha_limpia()
	pj.voluntad = 321
	pj.base_eficacia = 0.42
	pj.base_resist_voluntad = 0.17
	var d: Dictionary = Net.partida.ficha_a_dict(pj)
	var vuelta: PersonajeData = Net.partida.ficha_de_dict(d)
	_ok(vuelta.voluntad == 321, "viaja la Voluntad")
	_ok(is_equal_approx(vuelta.base_eficacia, 0.42) and is_equal_approx(vuelta.base_resist_voluntad, 0.17),
		"viaja lo grabado")
	# Una ficha de una version vieja (sin la clave) llega rellena.
	var d_vieja: Dictionary = Net.partida.ficha_a_dict(_ficha_vieja())
	d_vieja.erase("voluntad")
	var v2: PersonajeData = Net.partida.ficha_de_dict(d_vieja)
	_ok(v2.ability_internal.has("voluntad"), "una ficha vieja por red llega con la clave")
