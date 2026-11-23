extends "res://tools/unitarias/caso.gd"
# Cubre: res://scripts/core/personaje_data.gd
# Cubre: res://scripts/core/game.gd
# Cubre: res://tools/simulador_peleas.gd
# LA SUBIDA DE NIVEL, UNA SOLA COPIA (23/11). El simulador de peleas tenia la subida de nivel copiada a mano y se dejo el
# mana maximo, el ataque por Destreza, el critico, la eficacia y la resistencia por Voluntad; y sin el total oculto la
# energia maxima de sus personajes salia siempre 100. Ahora juego y simulador usan PersonajeData.bakear_subida,
# inflar_total_al_subir y Game.max_aguante_de. Aqui: que la subida toca TODAS las bases, que la energia sale del
# consolidado, y que el simulador no vuelve a llevar su propia copia de las formulas.


func _stats(v: int) -> Abilities:
	var a := Abilities.new()
	for s in Abilities.NOMBRES:
		a.set(s, v)
	return a


func test_la_subida_toca_todas_las_bases() -> void:
	var p := PersonajeData.new()
	var antes: Dictionary = {}
	var campos := ["base_hp", "base_attack", "base_defense", "base_speed", "base_magic", "base_magia_factor", "base_mp",
		"base_crit", "base_eficacia", "base_resist_voluntad"]
	for c in campos:
		antes[c] = float(p.get(c))
	var des0: float = p.base_ataque_destreza()
	p.bakear_subida(_stats(750), 1.1)
	for c in campos:
		cierto(float(p.get(c)) > float(antes[c]), "%s sube al subir de nivel (%.3f -> %.3f)" % [c, antes[c], p.get(c)])
	cierto(p.base_attack_des > des0, "el ataque por Destreza sube (%.2f -> %.2f)" % [des0, p.base_attack_des])
	cerca(p.base_mp, StatsMath.max_mp_jugador(_stats(750), 20.0) * 1.1, 0.001, "mana base = el maximo que tenias x1,1")


func test_el_total_oculto_se_infla() -> void:
	var p := PersonajeData.new()
	p.asegurar_stats()
	p.ability_internal["resistencia"] = 750.0
	p.inflar_total_al_subir(1.1)
	cerca(float(p.ability_consolidado["resistencia"]), 825.0, 0.001, "consolidado = total x1,1")
	cerca(float(p.ability_base_nivel["resistencia"]), 825.0, 0.001, "la marca del nivel sube al total")


func test_energia_maxima_sale_del_consolidado() -> void:
	var p := PersonajeData.new()
	p.asegurar_stats()
	cerca(Game.max_aguante_de(p), 100.0, 0.001, "sin nada consolidado, 100")
	p.ability_consolidado["resistencia"] = 1000.0
	p.ability_consolidado["agilidad"] = 1000.0
	cerca(Game.max_aguante_de(p), 100.0 + 75.0 + 25.0, 0.001, "100 + 0,075 Res + 0,025 Agi")


# EL GUARDIA: si alguien vuelve a copiar las formulas de la subida en el simulador, esto salta.
func test_el_simulador_no_copia_la_subida() -> void:
	var src: String = FileAccess.get_file_as_string("res://tools/simulador_peleas.gd")
	cierto(src.contains("bakear_subida("), "el simulador sube de nivel con PersonajeData.bakear_subida")
	cierto(not src.contains("max_hp_jugador("), "el simulador no lleva su propia copia de max_hp_jugador")
	cierto(not src.contains("* 0.075"), "ni de las constantes del aguante")
