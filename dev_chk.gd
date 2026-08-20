extends Node
func _ready() -> void:
	var fallos := 0
	var d := DirAccess.open("res://resources/abilities")
	print("--- habilidades SIN DAÑO que piden estilo (tienen que ir por _fx_adorno) ---")
	for f in d.get_files():
		if not f.ends_with(".tres"): continue
		var ab: AbilityData = load("res://resources/abilities/%s" % f)
		if ab == null or ab.fx_estilo < 0: continue
		if float(CombatFX.T_VUELO.get(ab.fx_estilo, 0.0)) <= 0.0:
			print("  MUDO (sin vuelo): %s estilo %d" % [ab.nombre, ab.fx_estilo]); fallos += 1
		if ab.dano_mult <= 0.0:
			var donde: String = "sobre si mismo" if CombatFX.SOBRE_SI_MISMO.has(ab.fx_estilo) else "sobre los objetivos"
			print("  %-24s estilo %2d -> %s" % [ab.nombre, ab.fx_estilo, donde])
	print("--- enemigos sin basico ---")
	var sinb := []
	var de := DirAccess.open("res://scenes/actors/enemy")
	for f in de.get_files():
		if not f.ends_with(".tres"): continue
		var en: EnemyData = load("res://scenes/actors/enemy/%s" % f)
		if en != null and en.fx_basico < 0: sinb.append(en.enemy_name)
	print("  %s" % ("ninguno" if sinb.is_empty() else ", ".join(sinb)))
	print("--- habilidades de enemigo que AUN no tienen estilo ---")
	var pend := []
	for f in de.get_files():
		if not f.ends_with(".tres"): continue
		var en: EnemyData = load("res://scenes/actors/enemy/%s" % f)
		if en == null: continue
		for ab in en.habilidades:
			if ab != null and ab.fx_estilo < 0 and not pend.has(ab.nombre): pend.append(ab.nombre)
	pend.sort()
	print("  (%d) %s" % [pend.size(), ", ".join(pend)])
	print("=== %s ===" % ("OK" if fallos == 0 else "%d FALLOS" % fallos))
	get_tree().quit()
