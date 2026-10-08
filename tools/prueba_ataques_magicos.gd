# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_ataques_magicos.tscn
#
# LOS ATAQUES MAGICOS DE LOS SLIMES (08/10/2026, fase 3 del plan de mecanicas nuevas). Mira que
#   - las 15 habilidades del reparto (16 fichas: el mil ojos tiene versiones propias) van marcadas es_magico,
#   - el ataque magico del enemigo sale de su MAGIA con la misma curva que la Fuerza,
#   - va contra la DEFENSA MAGICA y la reduccion MAGICA de la armadura, no contra las fisicas,
#   - ni la guardia ni el escudo lo paran.
extends Node

const MAGICAS := ["slime_llamarada", "slime_combustion", "slime_nube_ceniza", "slime_exhalar_miasma",
	"slime_exhalar_pestilente", "slime_burbujas_pestilentes", "slime_estallido_helado", "slime_aliento_gelido",
	"slime_tromba_abisal", "slime_lluvia_estrellas", "slime_lluvia_estrellas_mil", "slime_constelacion",
	"slime_agujero_negro", "slime_agujero_negro_mil", "slime_parpadeo_cegador", "slime_mirada_estelar"]

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _ready() -> void:
	_fichas()
	_ataque()
	_defensa()
	_sin_guardia()
	_pesos()
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


func _fichas() -> void:
	print("=== LAS FICHAS ===")
	for id in MAGICAS:
		var ab: AbilityData = load("res://resources/abilities/%s.tres" % id)
		_ok(ab != null and ab.es_magico, "%s es magica" % id)
	var fis: AbilityData = load("res://resources/abilities/slime_salpicadura_ardiente.tres")
	_ok(not fis.es_magico, "la Salpicadura ardiente sigue fisica")
	var llam: AbilityData = load("res://resources/abilities/slime_llamarada.tres")
	_ok(llam.resumen().contains("mágico"), "la ficha lo dice")


func _enemigo(fuerza: int, magia: int) -> Combatant:
	var a := Abilities.new()
	a.fuerza = fuerza
	a.magia = magia
	a.destreza = 30
	return Combatant.new("Slime", 1, a, 50.0, 6.0, 3.0, 4.0)


func _blanco(def: float, mdef: float) -> Combatant:
	var c := Combatant.new("Blanco", 1, Abilities.new(), 500.0, 5.0, def, 5.0)
	c.base_magic = mdef
	return c


# La media de 'n' tiradas con la misma semilla en los dos lados (la variacion y el critico salen iguales).
func _media(f: Callable, n: int = 300) -> float:
	var s: float = 0.0
	for i in n:
		seed(i)
		s += float(f.call()["damage"])
	return s / float(n)


func _ataque() -> void:
	print("=== EL ATAQUE SALE DE SU MAGIA ===")
	var igual := _enemigo(80, 80)
	_ok(is_equal_approx(igual.atk_magico(), igual.atk()), "Magia = Fuerza -> mismo ataque (%.2f)" % igual.atk())
	var mago := _enemigo(20, 160)
	_ok(mago.atk_magico() > mago.atk(), "mucha Magia y poca Fuerza: pega mas por magia (%.2f > %.2f)"
		% [mago.atk_magico(), mago.atk()])


func _defensa() -> void:
	print("=== CONTRA LA DEFENSA MAGICA ===")
	var e := _enemigo(80, 80)
	var base := _blanco(5.0, 5.0)
	var mucha_def := _blanco(40.0, 5.0)
	var mucha_mdef := _blanco(5.0, 40.0)
	var d0: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, base, false))
	var d_def: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, mucha_def, false))
	var d_mdef: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, mucha_mdef, false))
	_ok(is_equal_approx(d0, d_def), "la defensa FISICA no la frena (%.2f = %.2f)" % [d0, d_def])
	_ok(d_mdef < d0 * 0.6, "la defensa MAGICA si (%.2f -> %.2f)" % [d0, d_mdef])
	var red_fis := _blanco(5.0, 5.0)
	red_fis.armor_reduction = 0.15
	var red_mag := _blanco(5.0, 5.0)
	red_mag.armor_reduction_magica = 0.10
	var d_rf: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, red_fis, false))
	var d_rm: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, red_mag, false))
	_ok(is_equal_approx(d_rf, d0), "la reduccion FISICA de la armadura no cuenta")
	_ok(is_equal_approx(d_rm, d0 * 0.9), "la reduccion MAGICA si (%.2f -> %.2f)" % [d0, d_rm])
	# Y al reves: el golpe fisico de siempre no se entera de la defensa magica.
	var f0: float = _media(func(): return StatsMath.resolve_attack(e, base, false, -1.0, 0.0, 0.0, false))
	var f_mdef: float = _media(func(): return StatsMath.resolve_attack(e, mucha_mdef, false, -1.0, 0.0, 0.0, false))
	_ok(is_equal_approx(f0, f_mdef), "el golpe fisico no mira la defensa magica")


func _sin_guardia() -> void:
	print("=== NI GUARDIA NI ESCUDO ===")
	var e := _enemigo(80, 80)
	var t := _blanco(5.0, 5.0)
	var fis_libre: float = _media(func(): return StatsMath.resolve_attack(e, t, false, -1.0, 0.0, 0.0, false))
	t.defend_defense = 30.0
	t.defend_block = 0.6
	var fis_guardia: float = _media(func(): return StatsMath.resolve_attack(e, t, true, -1.0, 0.0, 0.0, false))
	_ok(fis_guardia < fis_libre * 0.5, "al fisico la guardia con escudo le quita (%.2f -> %.2f)" % [fis_libre, fis_guardia])
	var mag: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false))
	t.defend_defense = 0.0
	t.defend_block = 0.0
	var mag_libre: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false))
	_ok(is_equal_approx(mag, mag_libre), "al magico, nada (%.2f = %.2f)" % [mag, mag_libre])


# LOS PESOS POR MUTACION (MutacionData.pesos): la obsidiana pega fisico y la escarcha magico aunque vengan del mismo slime.
func _pesos() -> void:
	print("=== PESOS POR MUTACION ===")
	var fuego: EnemyData = load("res://scenes/actors/enemy/slime_fuego.tres")
	var p0: Dictionary = fuego.pesos_de()
	var po: Dictionary = fuego.pesos_de(&"obsidiana")
	_ok(int(p0["magia"]) > int(p0["fuerza"]), "el de fuego es de magia (F%d M%d)" % [p0["fuerza"], p0["magia"]])
	_ok(int(po["fuerza"]) > int(po["magia"]) and int(po["resistencia"]) == int(p0["resistencia"]),
		"la obsidiana es de fuerza y hereda lo que no cambia (F%d M%d R%d)" % [po["fuerza"], po["magia"], po["resistencia"]])
	var suma := func(p: Dictionary) -> int: return int(p["fuerza"] + p["resistencia"] + p["destreza"] + p["agilidad"] + p["magia"])
	for ficha in ["slime_fuego", "slime_veneno", "slime_profundo", "slime_abisal"]:
		var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % ficha)
		for m in ed.mutaciones:
			if not m.pesos.is_empty():
				_ok(suma.call(ed.pesos_de(m.id)) == suma.call(ed.pesos_de()),
					"%s: la Magia sale de la Fuerza, el total igual" % m.nombre)
	Game.current_floor = 6
	var c_base: Combatant = fuego.crear_combatant(0.5)
	var c_obs: Combatant = fuego.crear_combatant(0.5, true, false, &"obsidiana")
	_ok(c_obs.abilities.fuerza > c_base.abilities.fuerza and c_obs.abilities.magia < c_base.abilities.magia,
		"y llegan al combatiente (base F%d M%d, obsidiana F%d M%d)" % [c_base.abilities.fuerza,
			c_base.abilities.magia, c_obs.abilities.fuerza, c_obs.abilities.magia])
	var normal: EnemyData = load("res://scenes/actors/enemy/slime.tres")
	_ok(normal.pesos_de()["voluntad"] == normal.magia, "sin Voluntad puesta sigue siendo la de su Magia")
	Game.current_floor = 1
