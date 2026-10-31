# LOS MUTANTES DEL JABALI (31/10): Jabali -> COLMILLO DE CRISTAL -> JABALI ANCESTRAL. El arbol, sus stats (las seis, suma
# 136, el jabali estrena Voluntad), sus ataques (la Cornada de cristal en vez de la de siempre) y sus sprites (con sus
# variantes de la pelea: los colmillos rotos y el ancestral pelado).
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_jabali.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _nombres(c: Combatant) -> Array:
	return c.habilidades.map(func(a): return a.nombre)


func _correr() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/jabali.tres")

	print("1) EL ARBOL")
	var c0: Combatant = ed.crear_combatant(0.5, false)
	var c1: Combatant = ed.crear_combatant(0.5, true, false, &"colmillo")
	var c2: Combatant = ed.crear_combatant(0.5, true, false, &"ancestral")
	_ver(c1.nombre == "Colmillo de cristal" and c2.nombre == "Jabalí ancestral", "nombres (%s / %s)" % [c1.nombre, c2.nombre])
	_ver(ed.siguiente_mutacion(false, &"")["id"] == &"colmillo", "del jabali sale el Colmillo de cristal")
	_ver(ed.siguiente_mutacion(true, &"colmillo")["id"] == &"ancestral", "y de el, el Jabali ancestral")

	print("2) LAS STATS (las seis, suma 136)")
	_ver(ed.voluntad == 14 and ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad == 136,
		"el jabali: 40/36/14/24/8/14 (estrena Voluntad)")
	for id in [&"colmillo", &"ancestral"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 136 and p.size() == 6, "%s: reparto de las seis, suma %d" % [id, suma])
	_ver(c2.hab("resistencia") > c1.hab("resistencia") and c2.hab("agilidad") < c1.hab("agilidad"),
		"el ancestral, mas duro y mas lento")

	print("3) LOS ATAQUES")
	print("    colmillo  %s" % [_nombres(c1)])
	print("    ancestral %s" % [_nombres(c2)])
	_ver(_nombres(c1) == ["Embestida", "Pisotón", "Cornada de cristal"], "el Colmillo: la Cornada de cristal")
	_ver(_nombres(c2) == ["Embestida", "Pisotón", "Cornada de cristal"], "el ancestral, tambien (la suya)")
	var cc: AbilityData = c1.habilidades[2]
	var ca: AbilityData = c2.habilidades[2]
	_ver(is_equal_approx(cc.dano_mult, 1.6) and int(cc.forma) == 3 and is_equal_approx(cc.forma_radio, 50.0),
		"Cornada de cristal: x1,6, linea de 50")
	_ver(is_equal_approx(ca.dano_mult, 1.9) and is_equal_approx(ca.forma_radio, 60.0), "la del ancestral: x1,9, linea de 60")
	var sang: bool = false
	for a in ca.efectos:
		if a.estado == StatusEffects.Id.SANGRADO and a.stacks == 2:
			sang = true
	_ver(sang, "la del ancestral abre 2 cargas de Sangrado")

	print("4) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "el jabali normal ya come")
	for id in [&"colmillo", &"ancestral"]:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		_ver(sf != null and SpritesEnemigo.mutante_propio(ed, id) and sf.has_animation(&"evolucion_1")
			and sf.has_animation(&"cornada_2") and sf.has_animation(&"comer_3"), "%s: su hoja propia (evolucion, cornada, comer)" % id)
		_ver(sf == SpritesEnemigo.frames_de(ed, 0.9, true, id), "%s: sin tinte de piso" % id)
	var variantes := {&"colmillo": [&"rotos"], &"ancestral": [&"rotos", &"pelado", &"pelado_rotos"]}
	for id in variantes:
		for vr in variantes[id]:
			var sv: SpriteFrames = SpritesEnemigo.frames_variante(ed, id, vr)
			_ver(sv != null and sv.has_animation(&"idle_0") and sv.has_animation(&"cornada_4")
				and sv != SpritesEnemigo.frames_de(ed, 0.5, true, id), "%s %s: su variante" % [id, vr])
	_ver(SpritesEnemigo.frames_variante(ed, &"colmillo", &"pelado") == null, "(el Colmillo no tiene variante pelada)")

	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
