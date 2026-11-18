# PRUEBA (sin ventana): LOS MUTANTES DE LA CHUPASIMAS (18/11, memoria chupasimas-mutante).
#
#   1. La ficha: la base con su Voluntad, las tres mutaciones (la Madre desde las dos) y sus kits.
#   2. La COSTRA DE SANGRE: nace sin costra, con el tope en su vida maxima; con ella puesta el fisico entra a medias, el agua
#      x1,3 y el rayo normal; sin ella, lo de siempre; rota no rebrota sola.
#   3. BEBER MANA y el RAYO: lo bebido sale del mana de quien muerde y carga el rayo (con tope); el rayo pega segun la carga.
#   4. La SED DE MANA: va a por el mago (tres de 20 y uno de 52: x1,86 y x0,71).
#   5. Los SPRITES: cada mutante el suyo, y la variante con costra en el Coagulo y la Madre.
extends Node

const CE := preload("res://scripts/ui/combat_enemigos.gd")
const CO := preload("res://scripts/ui/combat_objetivos.gd")

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	print(("  ok   " if cond else "  MAL: ") + que)
	if not cond:
		_mal += 1


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/chupasimas.tres")
	_ficha(ed)
	_costra(ed)
	_mana_y_rayo(ed)
	_sed()
	_sprites(ed)
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


func _ficha(ed: EnemyData) -> void:
	print("=== LA FICHA ===")
	_ok([ed.resistencia, ed.fuerza, ed.destreza, ed.agilidad, ed.magia, ed.voluntad] == [32, 34, 28, 23, 12, 26],
		"la base: R32 F34 D28 A23 M12 V26 (suma 155)")
	var co: MutacionData = ed.mutacion_de(&"coagulo")
	var vi: MutacionData = ed.mutacion_de(&"vidriada")
	var ma: MutacionData = ed.mutacion_de(&"madre")
	_ok(co != null and vi != null and ma != null, "las tres mutaciones")
	if ma != null:
		_ok(ma.grado == 2 and ma.desde.has(&"coagulo") and ma.desde.has(&"vidriada"), "la Madre sale de las dos")
	if vi != null:
		_ok(vi.habilidades.all(func(a): return a.es_magico) and vi.basico_propio != null and vi.basico_propio.es_magico,
			"la Vidriada: todo su kit magico (tambien el basico)")
		_ok(vi.habilidades.any(func(a): return a.rayo_mana) and vi.habilidades.any(func(a): return a.se_aparta > 0.0),
			"la Vidriada lleva el Rayo y el Sorbo (que se aparta)")
		_ok(not vi.habilidades.any(func(a): return a.pega), "la Vidriada no se pega")
	if co != null:
		_ok(not co.habilidades.any(func(a): return a.es_magico), "el Coagulo, todo fisico")
	if ma != null:
		var adh: Array = ma.habilidades.filter(func(a): return a.pega)
		_ok(adh.size() == 1 and not adh[0].es_magico, "la Madre se pega con el Adherirse FISICO")
		_ok(ma.habilidades.any(func(a): return a.robo_vida > 0.0 and a.roba_mana > 0.0 and a.es_magico),
			"su Drenaje: magico, hace costra y bebe mana")
		_ok(ma.suelta_con_rayo and ma.sed_de_mana and ma.costra_sangre > 0.0, "la Madre junta las dos pasivas")


func _costra(ed: EnemyData) -> void:
	print("=== LA COSTRA DE SANGRE ===")
	var c: Combatant = ed.crear_combatant(0.5, true, false, &"coagulo")
	_ok(is_zero_approx(c.costra) and is_equal_approx(c.costra_max, c.max_hp), "nace sin costra; tope = su vida maxima (%.1f)" % c.max_hp)
	_ok(not c.con_costra_sangre(), "sin costra no cuenta")
	# Las resistencias, con y sin costra.
	var agua_sin: float = Elementos.mult_recibido(2, c)
	var rayo_sin: float = Elementos.mult_recibido(3, c)
	c.costra = 20.0
	var agua_con: float = Elementos.mult_recibido(2, c)
	var rayo_con: float = Elementos.mult_recibido(3, c)
	_ok(is_equal_approx(agua_sin, 0.7) and is_equal_approx(rayo_sin, 1.5), "sin costra: agua x0,7, rayo x1,5 (%.2f, %.2f)" % [agua_sin, rayo_sin])
	_ok(is_equal_approx(agua_con, 1.3) and is_equal_approx(rayo_con, 1.0), "con costra: agua x1,3, rayo x1,0 (%.2f, %.2f)" % [agua_con, rayo_con])
	# El fisico, a medias con costra (misma semilla, sin esquiva).
	var yo := Combatant.new("Yo", 1, Abilities.new(), 500.0, 20.0, 5.0, 5.0)
	c.costra = 0.0
	seed(3)
	var d_sin: float = float(StatsMath.resolve_attack(yo, c, false, -1.0, 0.0, 0.0, false)["damage"])
	c.costra = 20.0
	seed(3)
	var d_con: float = float(StatsMath.resolve_attack(yo, c, false, -1.0, 0.0, 0.0, false)["damage"])
	_ok(is_equal_approx(d_con, d_sin * 0.5), "el fisico entra a medias con costra (%.2f -> %.2f)" % [d_sin, d_con])
	# Rota no rebrota sola.
	c.take_damage(999.0)
	_ok(c.costra <= 0.0 and c.costra_espera == 0, "rota, no se pone a contar para rebrotar")
	# Una mutacion SIN costra no la tiene.
	var v: Combatant = ed.crear_combatant(0.5, true, false, &"vidriada")
	_ok(v.costra_max <= 0.0 and not v.con_costra_sangre(), "la Vidriada no tiene costra")


func _mana_y_rayo(ed: EnemyData) -> void:
	print("=== BEBER MANA Y EL RAYO ===")
	var v: Combatant = ed.crear_combatant(0.5, true, false, &"vidriada")
	var mago := Combatant.new("Mago", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
	mago.max_mp = 52.0
	mago.current_mp = 52.0
	var b: float = v.beber_mana(mago, 0.1)
	_ok(is_equal_approx(b, 5.2) and is_equal_approx(mago.current_mp, 46.8) and is_equal_approx(v.mana_bebido, 5.2),
		"bebe el 10 %% del mana MAXIMO (5,2 de 52) y le carga el rayo")
	mago.current_mp = 1.0
	_ok(is_equal_approx(v.beber_mana(mago, 0.1), 1.0), "no bebe mas de lo que le queda")
	v.mana_bebido = 0.0
	for i in 20:
		mago.current_mp = 52.0
		v.beber_mana(mago, 0.1)
	_ok(is_equal_approx(v.mana_bebido, v.rayo_tope), "la carga tiene tope (%.1f)" % v.rayo_tope)
	var rayo: AbilityData = load("res://resources/abilities/chupasimas_rayo_mana.tres")
	v.mana_bebido = 0.0
	_ok(is_equal_approx(CE._rayo_mult(v, rayo), 0.5), "rayo vacio: x0,5")
	v.mana_bebido = 6.0
	_ok(is_equal_approx(CE._rayo_mult(v, rayo), 1.22), "con 6 bebidos: x1,22")
	v.mana_bebido = v.rayo_tope
	_ok(is_equal_approx(CE._rayo_mult(v, rayo), 2.0), "lleno: x2 (tope)")
	_ok(CE.rayo_listo(v), "lleno, lo suelta seguro")
	v.mana_bebido = 2.0
	var alguna: bool = false
	for i in 200:
		alguna = alguna or CE.rayo_listo(v)
	_ok(not alguna, "con menos de 4, nunca")
	v.mana_bebido = 6.0
	var veces: int = 0
	for i in 2000:
		veces += 1 if CE.rayo_listo(v) else 0
	_ok(veces > 350 and veces < 650, "con 6, alrededor del 25 %% (%d de 2000)" % veces)
	var otra: AbilityData = load("res://resources/abilities/chupasimas_sorbo.tres")
	_ok(is_equal_approx(CE._rayo_mult(v, otra), 1.0), "lo demas no se toca")


func _sed() -> void:
	print("=== SED DE MANA ===")
	var g: Array = []
	for mp in [20.0, 20.0, 20.0, 52.0]:
		var c := Combatant.new("X", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
		c.max_mp = mp
		g.append(c)
	_ok(is_equal_approx(CO.sed_de_mana_de(g[3], g), 52.0 / 28.0), "el mago (52 de media 28): x%.2f" % CO.sed_de_mana_de(g[3], g))
	_ok(is_equal_approx(CO.sed_de_mana_de(g[0], g), 20.0 / 28.0), "los de 20: x%.2f" % CO.sed_de_mana_de(g[0], g))
	(g[3] as Combatant).max_mp = 400.0
	_ok(is_equal_approx(CO.sed_de_mana_de(g[3], g), 2.0), "con tope en x2")


func _sprites(ed: EnemyData) -> void:
	print("=== LOS SPRITES ===")
	for m in [&"coagulo", &"vidriada", &"madre"]:
		_ok(Chupasimas3DSprites.tiene_mutante(ed, m), "%s tiene su sprite" % m)
		_ok(SpritesEnemigo.frames_de(ed, 0.5, true, m) != null, "%s carga" % m)
	_ok(SpritesEnemigo.frames_variante(ed, &"coagulo", &"costra") != null, "el Coagulo tiene la variante con costra")
	_ok(SpritesEnemigo.frames_variante(ed, &"madre", &"costra") != null, "la Madre tambien")
	_ok(SpritesEnemigo.frames_variante(ed, &"vidriada", &"costra") == null, "la Vidriada no")
	var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"madre")
	_ok(sf != null and sf.has_animation(&"evolucion_coagulo_0") and sf.has_animation(&"rayo_0"),
		"la Madre: las dos evoluciones y el rayo")
	var sv: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"vidriada")
	_ok(sv != null and sv.has_animation(&"sorbo_0") and not sv.has_animation(&"adherido_0"),
		"la Vidriada: sorbo, y sin adherido")
