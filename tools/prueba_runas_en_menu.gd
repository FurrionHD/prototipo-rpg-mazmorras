# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_runas_en_menu.tscn
#
# ¿SE VEN LAS SUB-STATS DE LAS RUNAS EN EL MENU DE PERSONAJE? (09/10, su pregunta). Le pone al lider una runa con UNA
# sub-stat cada vez (en la espada o en el peto, segun su lista) y mide las filas de "Atributos" del menu con las mismas
# cuentas que character_menu.gd (todas salen de Game.crear_player_combatant). Dice cuales cambian y cuales no.
# (09/10, tras el arreglo) Las que no tienen fila propia salen como LINEAS DE MAS (MenuScaffold.filas_runas); la Vida %
# tambien fuera de la pelea (Game.player_max_hp: la barra del mapa). Al final, FIN: TODO BIEN si todas se ven.
extends Node


func _w(ruta: String) -> Resource:
	return Game.crear_item(load(ruta), 1, 0, {}, false)


func _filas(pj: PersonajeData) -> Dictionary:
	var c: Combatant = Game.crear_player_combatant(pj)
	var cap: float = StatsMath.EVADE_MAX_BUFF if c.evasion_bonus > 0.0 else StatsMath.EVADE_MAX
	return {
		"Vida máxima": c.max_hp,
		"Ataque": (c.base_ataque() + c.ataque_arma) * c.factor_ataque_crudo() * c.status_atk_mult(),
		"Ataque mágico": MenuScaffold.dano_magico(pj),
		"Defensa": c.def_value(),
		"Defensa mágica": c.mdef_value(),
		"Velocidad": c.spd(),
		"Prob. crítico": StatsMath.crit_chance(float(c.abilities.destreza), float(c.abilities.agilidad)) + c.crit_bonus_promedio() + c.crit_flat,
		"Daño crítico": c.crit_dmg,
		"Prob. crít. mágico": c.crit_magico,
		"Daño crít. mágico": c.crit_dmg_magico,
		"Prob. esquiva": clampf(StatsMath.evade_chance(float(c.abilities.agilidad), float(c.abilities.destreza)) - c.evasion_penal + c.evasion_bonus, 0.0, cap),
		"Reducción de daño": c.armor_reduction,
		"Resist. crítico": c.crit_resist,
		"Resist. estados": c.resist_estados(),
		"Eficacia": c.eficacia_estados(),
	}


func _ready() -> void:
	var pj: PersonajeData = Game.lider()
	var espada: Resource = _w("res://resources/weapons/espada_corta.tres")
	var peto: Resource = _w("res://resources/armor/cuero_pecho.tres")
	pj.equipped_main = espada
	pj.equipped_off = null
	pj.equipped_pecho = peto
	var base: Dictionary = _filas(pj)
	var no_salen: Array = []
	for k in Runas.subs():
		var pesos: Array = Runas.subs()[k]["pesos"]
		var en_arma: bool = int(pesos[Runas.Lista.ARMA_FISICA]) > 0 or int(pesos[Runas.Lista.ARMA_MAGICA]) > 0
		var pieza: Resource = espada if en_arma else peto
		Game.meta_de(espada)["runas"] = {}
		Game.meta_de(peto)["runas"] = {}
		Game.meta_de(pieza)["runas"] = {"set": "", "subs": [{"s": k, "v": 0.5}]}
		var f: Dictionary = _filas(pj)
		var cambian: Array = []
		for fila in f:
			if absf(float(f[fila]) - float(base[fila])) > 0.0001:
				cambian.append("%s %.2f -> %.2f" % [fila, float(base[fila]), float(f[fila])])
		var vb := VBoxContainer.new()
		var extra: int = MenuScaffold.filas_runas(vb, pj)
		var txt: String = ""
		for row in vb.get_children():
			for l in row.get_children():
				txt += (l as Label).text + " "
		vb.free()
		if extra > 0:
			cambian.append("linea de mas: " + txt.strip_edges())
		print("%-32s %s" % [Runas.nombre_sub(k), ("SALE: " + ", ".join(cambian)) if not cambian.is_empty() else "NO SALE en el menu"])
		if cambian.is_empty():
			no_salen.append(Runas.nombre_sub(k))
		if k == "vida_pct":
			var c: Combatant = Game.crear_player_combatant(pj)
			print("    vida fuera de la pelea %.1f, en la pelea %.1f" % [Game.player_max_hp(pj), c.max_hp])
			if absf(Game.player_max_hp(pj) - c.max_hp) > 0.01:
				no_salen.append("Vida (fuera de la pelea)")
	print("")
	print("NO SALEN (%d): %s" % [no_salen.size(), ", ".join(no_salen)])
	print("FIN: %s" % ("TODO BIEN" if no_salen.is_empty() else "HAY FALLOS"))
	get_tree().quit(0 if no_salen.is_empty() else 1)
