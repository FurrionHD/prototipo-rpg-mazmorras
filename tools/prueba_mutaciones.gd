# EL ARBOL DE MUTACIONES DEL SLIME NORMAL (06/10): Slime -> brotado | punzante (50/50) -> brotado punzante; los nombres,
# la tabla de cada grado, las probabilidades de nacer (2 % y 0,5 %), los sprites de cada una y lo que pasa al comer.
#   godot --headless --path . res://tools/prueba_mutaciones.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/slime.tres")
	print("1) el arbol")
	_ver(ed.mutaciones.size() == 3, "tres mutaciones (%d)" % ed.mutaciones.size())
	_ver(ed.nombre_mostrado(true, &"brotado") == "Slime brotado", "nombre del brotado")
	_ver(ed.nombre_mostrado(true, &"punzante") == "Slime punzante", "nombre del punzante")
	_ver(ed.nombre_mostrado(true, &"brotado_punzante") == "Slime brotado punzante", "nombre del brotado punzante")
	_ver(ed.grado_de(true, &"brotado") == 1 and ed.grado_de(true, &"brotado_punzante") == 2 and ed.grado_de(false, &"") == 0,
		"grados 1, 2 y 0")
	var rata: EnemyData = load("res://scenes/actors/enemy/rata.tres") if ResourceLoader.exists("res://scenes/actors/enemy/rata.tres") else null
	if rata != null:
		_ver(rata.nombre_mostrado(true, &"") == "%s mutante" % rata.enemy_name, "sin arbol: el mutante de siempre")

	print("2) al mutar: 50/50 brotado o punzante, y de cada uno al brotado punzante")
	var cuenta := {}
	for i in 2000:
		var s: Dictionary = ed.siguiente_mutacion(false, &"")
		cuenta[s["id"]] = int(cuenta.get(s["id"], 0)) + 1
	_ver(cuenta.size() == 2 and absi(int(cuenta.get(&"brotado", 0)) - 1000) < 120, "reparto %s" % cuenta)
	_ver(ed.siguiente_mutacion(true, &"brotado")["id"] == &"brotado_punzante", "brotado -> brotado punzante")
	_ver(ed.siguiente_mutacion(true, &"punzante")["id"] == &"brotado_punzante", "punzante -> brotado punzante")
	_ver(not bool(ed.siguiente_mutacion(true, &"brotado_punzante")["mut"]), "el brotado punzante ya no evoluciona")

	print("3) al nacer: 2 % mutante y 0,5 % brotado punzante")
	var n1: int = 0
	var n2: int = 0
	var N: int = 40000
	for i in N:
		var r: Dictionary = ed.tirar_mutacion()
		if bool(r["mut"]):
			if ed.grado_de(true, r["id"]) == 2:
				n2 += 1
			else:
				n1 += 1
	_ver(absf(float(n1) / N - 0.02) < 0.004, "mutante %.2f %%" % (100.0 * n1 / N))
	_ver(absf(float(n2) / N - 0.005) < 0.002, "brotado punzante %.2f %%" % (100.0 * n2 / N))

	print("4) la tabla de cada grado")
	var c0: Combatant = ed.crear_combatant(0.5, false, false)
	var c1: Combatant = ed.crear_combatant(0.5, true, false, &"brotado")
	var c2: Combatant = ed.crear_combatant(0.5, true, false, &"brotado_punzante")
	# (La vida no es base x multiplicador a secas: se mira que cada grado tenga mas y en la PROPORCION de la tabla.)
	_ver(c1.max_hp > c0.max_hp * 1.8, "el brotado tiene mucha mas vida (x%.2f)" % (c1.max_hp / c0.max_hp))
	_ver(absf((c2.max_hp / c1.max_hp) - EnemyData.MUT2_HP / EnemyData.MUT_HP) < 0.06,
		"el brotado punzante, en la proporcion de la tabla (x%.2f sobre el brotado)" % (c2.max_hp / c1.max_hp))
	_ver(c2.base_attack > c1.base_attack and c2.base_defense > c1.base_defense, "y mas ataque y defensa")
	_ver(c2.nombre == "Slime brotado punzante" and c2.grado_mut == 2 and c2.mutacion == &"brotado_punzante",
		"el combatiente lleva nombre (%s), grado y mutacion" % c2.nombre)

	print("5) un sprite para cada una")
	for id in [&"brotado", &"punzante", &"brotado_punzante"]:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		_ver(sf != null and sf.has_animation(&"idle_0") and SpritesEnemigo.mutante_propio(ed, id), "sprite de %s" % id)
	var sp: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"punzante")
	_ver(sp != null and sp.has_animation(&"expandir_0") and sp.has_animation(&"erizar_3"), "el punzante lleva Expandir puas")
	var sb: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"brotado")
	_ver(sb != null and not sb.has_animation(&"expandir_0") and sb.has_animation(&"evolucion_0"), "el brotado no; lleva su transformacion")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
