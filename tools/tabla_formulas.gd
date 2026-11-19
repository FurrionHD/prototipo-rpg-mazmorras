# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/tabla_formulas.tscn
#
# LA FORMULA DE STATS Y LA DE DEFENSA, ANTES Y DESPUES (19/11/2026, memoria stats-misma-formula-todos).
# Un PERSONAJE DE REFERENCIA por piso (la progresion que aprobo: nivel, habilidades del nivel, lo bakeado de los niveles
# anteriores y el equipo de placas + mandoble del tier del piso, con +7) contra CADA enemigo que sale en ese piso (las
# tablas de spawns) y los dos jefes. Por cada caso: cuantos golpes tuyos para tumbarlo, cuantos suyos para tumbarte (fisico
# y, si tiene Magia, magico) y cuantas veces actuas por cada una suya.
#   HOY        enemigos con la formula ADITIVA y la defensa daño = atk x 30 / (30 + def)
#   MULTI K30  enemigos con la MULTIPLICATIVA del jugador, la defensa de hoy
#   MULTI PROP enemigos multiplicativa, daño = atk x atk / (atk + c x def) (c calibrada: pisos 1-6 como hoy)
#   MULTI KPIS enemigos multiplicativa, daño = atk x K / (K + def) con K = 30 x 2,2^(tier del piso - 1)
#   NIV PROP / NIV KPIS  lo mismo, con los ENEMIGOS CON NIVEL (19/11, su eleccion "espejo del jugador"): pisos 1-12 nivel 1,
#              13-24 nivel 2, 25-36 nivel 3. Sus habilidades salen de la franja contando los pisos DESDE EL INICIO DE SU
#              NIVEL (el del 13 tiene las de un piso 1) y al subir de nivel BAKEAN sus bases como el jugador (con lo que
#              tendrian al final del nivel anterior, su piso 12) x1,1.
# Sin criticos, sin habilidades, sin estados: el golpe medio contra el golpe medio.
extends Node

const K_HOY := 30.0
const PISOS_NIVEL := 12   # cada nivel de enemigo ocupa 12 pisos
# piso: [nivel, habilidad del nivel, [bakeados], tier, mejoras, piezas de armadura]
const PROGRESION := {
	1: [1, 50, [], 1, 0, 2],
	2: [1, 100, [], 1, 1, 5],
	6: [1, 350, [], 1, 7, 5],
	7: [1, 400, [], 2, 0, 5],
	12: [1, 700, [], 2, 7, 5],
	13: [2, 100, [700.0], 3, 0, 5],
	18: [2, 500, [700.0], 3, 7, 5],
	25: [3, 100, [700.0, 800.0], 5, 0, 5],
	31: [3, 600, [700.0, 800.0], 6, 0, 5],
}
const JEFES := {6: "res://scenes/actors/enemy/rey_slime.tres", 12: "res://scenes/actors/enemy/guardian_rango.tres"}
const SLOTS := ["casco", "pecho", "manos", "pantalones", "botas"]

var _c_prop: float = 1.0


func _pj(piso: int) -> Combatant:
	var pr: Array = PROGRESION[piso]
	var p := PersonajeData.new()
	var hp: float = p.base_hp
	var at: float = p.base_attack
	var de: float = p.base_defense
	var sp: float = p.base_speed
	var mg: float = p.base_magic
	for s in pr[2]:
		var a := Abilities.new()
		a.fuerza = int(s); a.resistencia = int(s); a.agilidad = int(s); a.voluntad = int(s * 0.5)
		at = at * StatsMath.fuerza_factor(s) * 1.1
		hp = StatsMath.max_hp_jugador(a, hp) * 1.1
		de = StatsMath.defense_jugador(a, de) * 1.1
		sp = StatsMath.speed_jugador(a, sp) * 1.1
		mg = StatsMath.magic_jugador(a, mg) * 1.1
	p.base_attack = at; p.base_hp = hp; p.base_defense = de; p.base_speed = sp; p.base_magic = mg
	var h: int = int(pr[1])
	p.fuerza = h; p.resistencia = h; p.agilidad = h; p.destreza = h / 2; p.voluntad = h / 2
	p.equipped_main = load("res://resources/weapons/mandobles.tres")
	p.equip_meta["main"] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {Upgrades.AGUDEZA: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	for i in int(pr[5]):
		var s: String = SLOTS[(i + 1) % 5] if int(pr[5]) < 5 else SLOTS[i]
		p.set("equipped_" + s, load("res://resources/armor/placas_%s.tres" % s))
		p.equip_meta[s] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {Upgrades.DUREZA: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	return Game.crear_player_combatant(p)


# EL MAGO DE REFERENCIA (19/11): el mismo nivel y lo bakeado, pero la habilidad del nivel en la MAGIA (Resistencia y
# Agilidad a la mitad), baston y armadura de TELA del tier del piso con +7. Su golpe: TORMENTA (51,8 en 3 frases), lo que
# saca por turno de recitado ANTES de la defensa magica (StatsMath.resolve_spell sin el defensor).
func _mago(piso: int) -> Array:
	var pr: Array = PROGRESION[piso]
	var p := PersonajeData.new()
	var hp: float = p.base_hp
	var de: float = p.base_defense
	var mg: float = p.base_magic
	var mf: float = p.base_magia_factor
	for s in pr[2]:
		var a := Abilities.new()
		a.magia = int(s); a.resistencia = int(s * 0.5); a.agilidad = int(s * 0.5); a.voluntad = int(s * 0.5)
		hp = StatsMath.max_hp_jugador(a, hp) * 1.1
		de = StatsMath.defense_jugador(a, de) * 1.1
		mg = StatsMath.magic_jugador(a, mg) * 1.1
		mf = mf * StatsMath.magia_factor(float(s)) * 1.1
	p.base_hp = hp; p.base_defense = de; p.base_magic = mg; p.base_magia_factor = mf
	var h: int = int(pr[1])
	p.magia = h; p.resistencia = h / 2; p.agilidad = h / 2; p.voluntad = h / 2; p.fuerza = h / 4
	p.equipped_main = load("res://resources/weapons/baston.tres")
	p.equip_meta["main"] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {Upgrades.POTENCIA: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	for i in int(pr[5]):
		var s: String = SLOTS[(i + 1) % 5] if int(pr[5]) < 5 else SLOTS[i]
		p.set("equipped_" + s, load("res://resources/armor/tela_%s.tres" % s))
		p.equip_meta[s] = {"tier": int(pr[3]), "rareza": 0, "mejoras": {Upgrades.DUREZA: int(pr[4])}, "durabilidad": 1.0, "banda": 0}
	var c: Combatant = Game.crear_player_combatant(p)
	var sp: SpellData = load("res://resources/spells/tormenta.tres")
	var por_turno: float = sp.dano_base * StatsMath.magia_factor(c.hab("magia")) * c.magic_amp * c.magia_base_factor \
		* StatsMath.SPELL_DAMAGE_MULT / float(sp.frases.size())
	return [c, por_turno]


# Lo que hace un golpe de 'atk' contra 'def' con cada formula.
func _golpe(formula: String, atk: float, def: float, piso: int) -> float:
	match formula:
		"prop":
			return atk * atk / (atk + _c_prop * def)
		"kpis":
			var k: float = K_HOY * pow(2.2, float(int(ceil(float(piso) / 6.0)) - 1))
			return atk * k / (k + def)
	return atk * K_HOY / (K_HOY + def)


# Las stats del enemigo con la formula de hoy (aditiva) o la multiplicativa.
func _enemigo(ed: EnemyData, piso: int, jefe: bool, multi: bool) -> Dictionary:
	Game.current_floor = piso
	var c: Combatant = ed.crear_combatant(0.5, false, jefe, &"", piso)
	var a: Abilities = c.abilities_eff()
	if not multi:
		return {"hp": c.max_hp, "def": c.def_value(), "mdef": c.mdef_value(), "spd": c.spd(), "atk": c.atk(),
			"matk": c.atk_magico() if a.magia > 0 else 0.0}
	var spd: float = StatsMath.speed_jugador(a, c.base_speed) * c.velocidad_mult
	return {"hp": StatsMath.max_hp_jugador(a, c.base_hp), "def": StatsMath.defense_jugador(a, c.base_defense),
		"mdef": StatsMath.magic_jugador(a, c.base_magic), "spd": spd, "atk": c.atk(),
		"matk": c.atk_magico() if a.magia > 0 else 0.0}


# EL ENEMIGO CON NIVEL: habilidades de su piso dentro del nivel y las bases bakeadas en cada nivel anterior.
func _enemigo_nivel(ed: EnemyData, piso: int, jefe: bool) -> Dictionary:
	Game.current_floor = piso
	var c: Combatant = ed.crear_combatant(0.5, false, jefe, &"", piso)
	var nivel: int = 1 + (piso - 1) / PISOS_NIVEL
	var piso_local: int = piso - PISOS_NIVEL * (nivel - 1)
	var a: Abilities = ed.crear_abilities(0.5, &"", piso_local)
	var hp: float = c.base_hp
	var at: float = c.base_attack
	var de: float = c.base_defense
	var sp: float = c.base_speed
	var mg: float = c.base_magic
	for _n in nivel - 1:
		var ap: Abilities = ed.crear_abilities(0.5, &"", PISOS_NIVEL)
		hp = StatsMath.max_hp_jugador(ap, hp) * 1.1
		at = at * StatsMath.fuerza_factor(float(ap.fuerza)) * 1.1
		de = StatsMath.defense_jugador(ap, de) * 1.1
		sp = StatsMath.speed_jugador(ap, sp) * 1.1
		mg = StatsMath.magic_jugador(ap, mg) * 1.1
	return {"hp": StatsMath.max_hp_jugador(a, hp), "def": StatsMath.defense_jugador(a, de),
		"mdef": StatsMath.magic_jugador(a, mg), "spd": StatsMath.speed_jugador(a, sp) * c.velocidad_mult,
		"atk": at * StatsMath.fuerza_factor(float(a.fuerza)), "matk": at * StatsMath.fuerza_factor(float(a.magia)) if a.magia > 0 else 0.0,
		"nivel": nivel}


# Una pelea de un caso: [golpes tuyos, golpes suyos fisicos, golpes suyos magicos, tus turnos por cada suyo, reduccion
# de tu golpe, reduccion del suyo].
func _caso(yo: Combatant, e: Dictionary, formula: String, piso: int) -> Array:
	var mio: float = _golpe(formula, yo.atk(), e["def"], piso)
	var suyo: float = _golpe(formula, e["atk"], yo.def_value(), piso) * (1.0 - yo.armor_reduction)
	var suyo_m: float = _golpe(formula, e["matk"], yo.mdef_value(), piso) * (1.0 - yo.armor_reduction_magica) \
		if float(e["matk"]) > 0.0 else 0.0
	return [ceil(e["hp"] / maxf(mio, 0.01)), ceil(yo.max_hp / maxf(suyo, 0.01)),
		ceil(yo.max_hp / suyo_m) if suyo_m > 0.0 else 0.0, yo.spd() / maxf(e["spd"], 0.01),
		1.0 - mio / yo.atk(), 1.0 - suyo / maxf(e["atk"], 0.01)]


func _enemigos_de(piso: int) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://resources/spawns"):
		if not f.ends_with(".tres"):
			continue
		for en in load("res://resources/spawns/" + f).entradas:
			var p1: int = int(en.piso_max) if int(en.piso_max) > 0 else int(en.piso_min) + 3
			if int(en.piso_min) <= piso and piso <= p1 and en.enemy_data != null:
				if not out.any(func(x): return x[0] == en.enemy_data):
					out.append([en.enemy_data, false])
	if JEFES.has(piso):
		out.append([load(JEFES[piso]), true])
	return out


# LA c DE LA PROPORCION: la que deja la reduccion media de los pisos 1-6 (tu golpe y el suyo) igual que hoy.
func _calibrar() -> void:
	var mejor: float = 1.0
	var err_min: float = INF
	for i in range(1, 200):
		_c_prop = float(i) * 0.01
		var err: float = 0.0
		for piso in [1, 2, 6]:
			var yo: Combatant = _pj(piso)
			for par in _enemigos_de(piso):
				var hoy: Array = _caso(yo, _enemigo(par[0], piso, par[1], false), "hoy", piso)
				var pr: Array = _caso(yo, _enemigo(par[0], piso, par[1], false), "prop", piso)
				err += pow(float(hoy[4]) - float(pr[4]), 2) + pow(float(hoy[5]) - float(pr[5]), 2)
		if err < err_min:
			err_min = err
			mejor = _c_prop
	_c_prop = mejor
	print("c de la proporcion (pisos 1-6 como hoy): %.2f" % _c_prop)


# TABLA_EXPORT=1: los numeros crudos de cada caso (para calibrar fuera): el personaje y el enemigo con nivel SIN el
# crecimiento por piso de sus bases (vida, ataque y defensa divididos por Game.enemy_floor_stat_factor).
func _exportar() -> void:
	for piso in PROGRESION:
		var yo: Combatant = _pj(piso)
		var f: float = Game.enemy_floor_stat_factor(piso)
		var mago: Array = _mago(piso)
		var mc: Combatant = mago[0]
		print("M|%d|%.3f|%.3f|%.3f|%.4f|%.4f|%.4f" % [piso, mc.max_hp, mc.def_value(), mc.mdef_value(), mc.armor_reduction,
			mc.armor_reduction_magica, float(mago[1])])
		for par in _enemigos_de(piso):
			var e: Dictionary = _enemigo_nivel(par[0], piso, par[1])
			print("E|%d|%s|%d|%.3f|%.3f|%.3f|%.4f|%.4f|%.3f|%.5f|%.5f|%.5f|%.5f|%.5f|%.3f|%d|%.5f" % [piso, par[0].enemy_name,
				1 if par[1] else 0, yo.max_hp, yo.atk(), yo.def_value(), yo.armor_reduction, yo.spd(), yo.mdef_value(),
				float(e["hp"]) / f, float(e["atk"]) / f, float(e["def"]) / f, float(e["matk"]) / f, float(e["spd"]),
				yo.armor_reduction_magica, int(e["nivel"]), float(e["mdef"]) / sqrt(f)])
	get_tree().quit()


func _ready() -> void:
	if OS.get_environment("TABLA_EXPORT") != "":
		_exportar()
		return
	_calibrar()
	print("columnas: tus golpes para tumbarlo / sus golpes fisicos para tumbarte [magicos] | tus turnos por cada suyo")
	for piso in PROGRESION:
		var yo: Combatant = _pj(piso)
		print("")
		print("=== PISO %d: tu nv%d, habilidades %d, T%d +%d | vida %.0f atk %.0f def %.0f mdef %.0f vel %.1f ===" % [
			piso, PROGRESION[piso][0], PROGRESION[piso][1], PROGRESION[piso][3], PROGRESION[piso][4], yo.max_hp, yo.atk(),
			yo.def_value(), yo.mdef_value(), yo.spd()])
		for par in _enemigos_de(piso):
			var ed: EnemyData = par[0]
			var fila := "T|%d|%s%s" % [piso, ed.enemy_name, " (jefe)" if par[1] else ""]
			for caso in [["hoy", false], ["hoy", true], ["prop", true], ["kpis", true], ["prop", 2], ["kpis", 2]]:
				var e: Dictionary = _enemigo_nivel(ed, piso, par[1]) if typeof(caso[1]) == TYPE_INT \
					else _enemigo(ed, piso, par[1], caso[1])
				var r: Array = _caso(yo, e, caso[0], piso)
				fila += "|%d / %d%s x%.1f" % [int(r[0]), int(r[1]), (" [%d]" % int(r[2])) if float(r[2]) > 0.0 else "", float(r[3])]
			print(fila)
	get_tree().quit()
