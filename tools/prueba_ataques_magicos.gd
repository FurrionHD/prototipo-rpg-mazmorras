# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_ataques_magicos.tscn
#
# LOS ATAQUES MAGICOS DE LOS SLIMES (08/10/2026, fase 3 del plan de mecanicas nuevas). Mira que
#   - las 15 habilidades del reparto (16 fichas: el mil ojos tiene versiones propias) van marcadas es_magico,
#   - el ataque magico del enemigo sale de su MAGIA con la misma curva que la Fuerza,
#   - va contra la DEFENSA MAGICA y la reduccion MAGICA de la armadura, no contra las fisicas,
#   - sin defender el escudo no cuenta; DEFENDIENDO (17/11) si: su Defensa magica (40/100/60 % de su Defensa segun el
#     tamaño), el bloqueo a medias y el critico a la mitad.
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
	_con_guardia()
	_escudos()
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
	print("=== SIN DEFENDER, EL ESCUDO NO CUENTA ===")
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
	_ok(is_equal_approx(mag, mag_libre), "al magico sin defender, nada (%.2f = %.2f)" % [mag, mag_libre])


# DEFENDIENDO CONTRA LA MAGIA (17/11): la Defensa magica del escudo, el bloqueo A MEDIAS y el critico a la mitad.
func _con_guardia() -> void:
	print("=== DEFENDIENDO CONTRA LA MAGIA ===")
	var e := _enemigo(80, 80)
	var t := _blanco(5.0, 5.0)
	var libre: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false, false))
	# Defendiendo SIN escudo ni bloqueo: la referencia (el critico ya va a la mitad, se compara con ella).
	t.defend_block = 0.0
	var libre_def: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false, true))
	# Solo la Defensa magica del escudo (sin bloqueo):
	t.defend_mdef = 30.0
	var solo_mdef: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false, true))
	var cuerpo := _blanco(5.0, 35.0)
	cuerpo.defend_block = 0.0
	var con_base: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, cuerpo, false, true))
	_ok(is_equal_approx(solo_mdef, con_base), "la Defensa magica del escudo suma a la del cuerpo (%.2f = %.2f)"
		% [solo_mdef, con_base])
	_ok(solo_mdef < libre, "y frena (%.2f -> %.2f)" % [libre, solo_mdef])
	# Solo el bloqueo: a medias.
	t.defend_mdef = 0.0
	t.defend_block = 0.6
	var bloq: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false, true))
	# (libre_def ya lleva el bloqueo minimo de defender, DEFEND_TAKEN_MAX = x0,9: se le quita para comparar)
	_ok(is_equal_approx(bloq, libre_def / StatsMath.DEFEND_TAKEN_MAX * (1.0 - 0.6 * t.defend_bloqueo_magia)),
		"sin escudo el bloqueo vale la mitad (60 %% -> quita el 30 %%: %.2f -> %.2f)" % [libre_def, bloq])
	t.defend_bloqueo_magia = 0.4
	var bloq_torre: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false, true))
	_ok(is_equal_approx(bloq_torre, libre_def / StatsMath.DEFEND_TAKEN_MAX * (1.0 - 0.6 * 0.4)),
		"y con la parte de su tamaño (40 %%: quita el 24 %%: %.2f)" % bloq_torre)
	t.defend_bloqueo_magia = 0.5
	# El defend_mdef no cuenta sin defender.
	t.defend_mdef = 30.0
	var sin: float = _media(func(): return StatsMath.resolve_magico_enemigo(e, t, false, false))
	_ok(is_equal_approx(sin, libre), "sin defender no cuenta nada (%.2f = %.2f)" % [sin, libre])
	# El critico a la mitad: la probabilidad que devuelve.
	var r_libre: Dictionary = StatsMath.resolve_magico_enemigo(e, t, false, false)
	var r_def: Dictionary = StatsMath.resolve_magico_enemigo(e, t, false, true)
	_ok(is_equal_approx(float(r_def["crit_p"]), float(r_libre["crit_p"]) * StatsMath.DEFEND_CRIT_MULT),
		"el critico magico a la mitad (%.3f -> %.3f)" % [float(r_libre["crit_p"]), float(r_def["crit_p"])])
	# Y el golpe fisico no se entera de la Defensa magica del escudo.
	t.defend_block = 0.0
	t.defend_defense = 0.0
	var f_sin: float = _media(func(): return StatsMath.resolve_attack(e, t, true, -1.0, 0.0, 0.0, false))
	t.defend_mdef = 0.0
	var f_con: float = _media(func(): return StatsMath.resolve_attack(e, t, true, -1.0, 0.0, 0.0, false))
	_ok(is_equal_approx(f_sin, f_con), "al fisico la Defensa magica del escudo no le cuenta")


# LA DEFENSA MAGICA DE CADA ESCUDO: la Defensa por la fraccion de su tamaño, y la Dureza sube las dos.
func _escudos() -> void:
	print("=== LOS TRES ESCUDOS ===")
	var fr := {ShieldData.Tamano.PEQUENO: 0.4, ShieldData.Tamano.NORMAL: 1.0, ShieldData.Tamano.GRANDE: 0.3}
	var bm := {}   # tamaño -> bloqueo contra magia (sin Refuerzo, con el 30 % de base de Defender)
	var vistos := 0
	var d := DirAccess.open("res://resources/shields")
	for f in d.get_files():
		if not f.ends_with(".tres"):
			continue
		var sh: ShieldData = load("res://resources/shields/" + f) as ShieldData
		if sh == null:
			continue
		vistos += 1
		var m: Dictionary = Upgrades.shield_mods(sh, 1.0, 0, {})
		_ok(is_equal_approx(float(m["mdef"]), float(m["def"]) * float(fr[sh.tamano])),
			"%s: Defensa magica %.2f = %.0f %% de %.2f" % [f, float(m["mdef"]), float(fr[sh.tamano]) * 100.0, float(m["def"])])
		bm[sh.tamano] = (0.3 + float(m["bloqueo"])) * float(m["bloqueo_magia_frac"])
	_ok(vistos > 0, "hay escudos que mirar (%d)" % vistos)
	# Su decision: contra la magia, el caballero el que mas bloquea y la torre la que menos.
	_ok(bm[ShieldData.Tamano.NORMAL] > bm[ShieldData.Tamano.PEQUENO] and bm[ShieldData.Tamano.PEQUENO] > bm[ShieldData.Tamano.GRANDE],
		"bloqueo contra magia: caballero %.1f %% > rodela %.1f %% > torre %.1f %%" % [bm[ShieldData.Tamano.NORMAL] * 100.0,
			bm[ShieldData.Tamano.PEQUENO] * 100.0, bm[ShieldData.Tamano.GRANDE] * 100.0])


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
