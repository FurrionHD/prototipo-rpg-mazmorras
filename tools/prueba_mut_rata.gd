# LOS MUTANTES DE LA RATA (30/10): Rata -> RATA SOMBRIA / RATA DRUSA -> RATA DE CUARZO AHUMADO. El arbol, sus stats
# (tablas de los slimes con su reparto de las seis), sus ataques (los de siempre MEJORADOS y los nuevos), sus pasivas
# (resiste magia y fragil a contundentes; sigilo y salto al esquivar) y sus sprites (con la evolucion de dos padres).
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_rata.tscn
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
	var ed: EnemyData = load("res://scenes/actors/enemy/rata.tres")

	print("1) EL ARBOL")
	var c0: Combatant = ed.crear_combatant(0.5, false)
	var cs: Combatant = ed.crear_combatant(0.5, true, false, &"sombria")
	var cd: Combatant = ed.crear_combatant(0.5, true, false, &"drusa")
	var cq: Combatant = ed.crear_combatant(0.5, true, false, &"cuarzo")
	print("    %s / %s / %s" % [cs.nombre, cd.nombre, cq.nombre])
	_ver(cs.nombre == "Rata sombría" and cd.nombre == "Rata drusa" and cq.nombre == "Rata de cuarzo ahumado", "nombres")
	var primeras: Array = []
	for _i in 60:
		primeras.append(ed.siguiente_mutacion(false, &"")["id"])
	_ver(primeras.has(&"sombria") and primeras.has(&"drusa"), "de la rata sale sombria o drusa")
	_ver(ed.siguiente_mutacion(true, &"sombria")["id"] == &"cuarzo" and ed.siguiente_mutacion(true, &"drusa")["id"] == &"cuarzo",
		"de las dos se llega a la de cuarzo")
	# (la vida tambien sale de su reparto, asi que no da el x2,6 / x3,6 justo: cada una en su banda)
	var v1: float = cs.max_hp / c0.max_hp
	var v1d: float = cd.max_hp / c0.max_hp
	var v2: float = cq.max_hp / c0.max_hp
	_ver(v1 > 2.2 and v1 < 3.0 and v1d > 2.2 and v1d < 3.0 and v2 > 3.0 and v2 < 4.0,
		"vida: tabla de los slimes con su reparto (sombria x%.2f, drusa x%.2f, cuarzo x%.2f)" % [v1, v1d, v2])

	print("2) LAS STATS (las seis, suma 150)")
	_ver(ed.voluntad == 18 and ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad == 150,
		"la rata: 26/18/36/40/12/18 (estrena Voluntad)")
	for id in [&"sombria", &"drusa", &"cuarzo"]:
		var p: Dictionary = ed.mutacion_de(id).pesos
		var suma: int = 0
		for k in p:
			suma += int(p[k])
		_ver(suma == 150 and p.size() == 6, "%s: reparto de las seis, suma %d" % [id, suma])
	_ver(cd.hab("voluntad") > cs.hab("voluntad") * 2.0, "la drusa con mucha mas Voluntad que la sombria")
	_ver(cs.hab("agilidad") > cd.hab("agilidad"), "la sombria mas agil")

	print("3) LOS ATAQUES")
	print("    sombria %s" % [_nombres(cs)])
	print("    drusa   %s" % [_nombres(cd)])
	print("    cuarzo  %s" % [_nombres(cq)])
	_ver(_nombres(cs) == ["Mordisco sombrío", "Frenesí en la sombra", "Mordisco a traición"], "la sombria: sus mejorados + Traicion")
	_ver(_nombres(cd) == ["Mordisco de cristal", "Frenesí de esquirlas", "Embestida de cristal"], "la drusa: sus mejorados + Embestida")
	_ver(_nombres(cq).size() == 5 and _nombres(cq).has("Destello") and _nombres(cq).has("Mordisco sombrío")
		and _nombres(cq).has("Frenesí de esquirlas"), "la de cuarzo: lo mejor de las dos + Destello")
	for c in [cs, cd, cq]:
		for a in c.habilidades:
			_ver(a.es_magico == (a.nombre == "Destello"), "%s: magico solo el Destello" % a.nombre)

	print("4) LAS PASIVAS")
	_ver(is_equal_approx(cd.resiste_magia, 0.6) and is_equal_approx(cd.fragil_contundente, 1.3), "drusa: magia x0,6, contundente x1,3")
	_ver(is_equal_approx(cs.sigilo_prob, 0.5) and is_equal_approx(cs.salto_esquiva, 40.0), "sombria: sigilo 50 %, salto 40 px")
	_ver(is_equal_approx(cq.resiste_magia, 0.6) and is_equal_approx(cq.sigilo_prob, 0.5), "cuarzo: las dos")
	_ver(is_equal_approx(c0.resiste_magia, 1.0) and c0.sigilo_prob == 0.0, "la rata normal, ninguna")
	# El daño magico que le entra a la drusa: x0,6 (misma semilla).
	var mago := Combatant.new("Mago", 1, Abilities.new(), 100.0, 3.0, 3.0, 10.0)
	var sp: SpellData = load("res://resources/spells/descarga.tres") if ResourceLoader.exists("res://resources/spells/descarga.tres") else null
	if sp != null:
		cd.resiste_magia = 1.0
		seed(3)
		var d1: float = float(StatsMath.resolve_spell(mago, cd, sp)["damage"])
		cd.resiste_magia = 0.6
		seed(3)
		var d2: float = float(StatsMath.resolve_spell(mago, cd, sp)["damage"])
		_ver(absf(d2 / d1 - 0.6) < 0.01, "un hechizo a la drusa: %.1f -> %.1f (x0,6)" % [d1, d2])
	else:
		_ver(false, "no encuentro el hechizo de prueba")

	print("5) LOS SPRITES")
	var sf0: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, false, &"")
	_ver(sf0 != null and sf0.has_animation(&"comer_0"), "la rata normal ya come")
	var anims := {&"sombria": ["evolucion_0", "comer_3", "salto_rata_2"], &"drusa": ["evolucion_0", "embestida_1"],
		&"cuarzo": ["evolucion_0", "evolucion_drusa_0", "destello_4", "embestida_1"]}
	for id in anims:
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, id)
		var ok: bool = sf != null and SpritesEnemigo.mutante_propio(ed, id)
		for a in anims[id]:
			ok = ok and sf.has_animation(StringName(a))
		_ver(ok, "%s: su hoja propia %s" % [id, anims[id]])
	var sfs: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"sombria")
	var sfs2: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.9, true, &"sombria")
	_ver(sfs == sfs2, "sin tinte de piso (la misma hoja en cualquier piso)")

	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
