# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_runas.tscn
#
# LAS RUNAS (08/10/2026, fase 5). Mira que
#   - cada pieza saca sub-stats de SU lista (la varita sin Ataque, con el critico magico; la armadura, las suyas),
#   - los valores salen sesgados hacia lo bajo, escalan con el tier y van x2 a dos manos; hasta 2 iguales,
#   - el Taller activa (gastando material y nucleo), sube hasta 4, cambia, re-tira y desencanta,
#   - las runas viajan por la red (serializar_equipo) y llegan al combatiente (sub-stats y sets),
#   - los mutantes sueltan la runa de su set.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _ready() -> void:
	_catalogo()
	_tiradas()
	_taller()
	_red()
	_combate()
	_drops()
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


func _w(ruta: String) -> Resource:
	return Game.crear_item(load(ruta), 1, 0, {}, false)


func _catalogo() -> void:
	print("=== CADA PIEZA, SU LISTA ===")
	_ok(Runas.sets().size() == 6, "los 6 sets cargan")
	var espada: Resource = _w("res://resources/weapons/espada_corta.tres")
	var varita: Resource = _w("res://resources/wands/varita.tres") if ResourceLoader.exists("res://resources/wands/varita.tres") else null
	var peto: Resource = _w("res://resources/armor/cuero_pecho.tres")
	_ok(Runas.lista_de(espada) == Runas.Lista.ARMA_FISICA, "la espada: lista de arma fisica")
	_ok(Runas.lista_de(peto) == Runas.Lista.ARMADURA, "el peto: lista de armadura")
	var mag: Array = Runas.subs()["ataque_pct"]["pesos"]
	_ok(int(mag[Runas.Lista.ARMA_MAGICA]) == 0, "las armas magicas no sacan Ataque %")
	_ok(int(Runas.subs()["crit_mag"]["pesos"][Runas.Lista.ARMA_MAGICA]) > 0
		and int(Runas.subs()["crit"]["pesos"][Runas.Lista.ARMA_MAGICA]) == 0, "...y su critico es el magico")
	if varita != null:
		_ok(Runas.lista_de(varita) == Runas.Lista.ARMA_MAGICA, "la varita: lista magica")
	_ok(Runas.tipo_set_de(peto) == RunaSetData.Tipo.ARMADURA and Runas.tipo_set_de(espada) == RunaSetData.Tipo.ARMA,
		"armadura con sets de armadura, arma con sets de arma")


func _tiradas() -> void:
	print("=== TIRADAS ===")
	var s: float = 0.0
	var n: int = 4000
	var minimo: float = 1.0
	var maximo: float = 0.0
	for i in n:
		var v: float = Runas.tirar_valor("crit", 1)
		s += v
		minimo = minf(minimo, v)
		maximo = maxf(maximo, v)
	var media: float = s / float(n)
	_ok(minimo >= 0.03 - 0.0001 and maximo <= 0.06 + 0.0001, "el critico dentro de 3-6 %% (%.3f-%.3f)" % [minimo, maximo])
	_ok(media < 0.045, "sesgado hacia lo bajo: media %.2f %% (el centro es 4,5 %%)" % (media * 100.0))
	_ok(is_equal_approx(Runas.tirar_valor("ataque_pct", 2, false, 1.0), 0.06 * 1.5), "Ataque escala con el tier (T2 x1,5)")
	_ok(is_equal_approx(Runas.tirar_valor("crit", 3, false, 1.0), 0.06), "el critico es FIJO aunque suba el tier")
	_ok(is_equal_approx(Runas.tirar_valor("crit", 1, true, 1.0), 0.12), "a DOS MANOS, x2")
	# Hasta 2 iguales: una pieza con dos criticos ya no puede sacar un tercero.
	var espada: Resource = _w("res://resources/weapons/espada_corta.tres")
	Game.meta_de(espada)["runas"] = {"set": "fuego", "subs": [{"s": "crit", "v": 0.03}, {"s": "crit", "v": 0.04}]}
	var tercero: bool = false
	for i in 500:
		if Runas.elegir_sub(espada) == "crit":
			tercero = true
	_ok(not tercero, "no sale una tercera igual")


func _dar(mat: MaterialData, n: int) -> void:
	for i in n:
		Game.almacen_materiales.append(MaterialItem.crear(mat, MaterialItem.Calidad.NORMAL))


func _taller() -> void:
	print("=== EL TALLER ===")
	var s: RunaSetData = Runas.set_por_id(&"slime")
	var peto: Resource = _w("res://resources/armor/cuero_pecho.tres")
	_ok(not Runas.puede_activar(peto, s) or Game.unidades_material_en_hogar(s.material) >= 6,
		"sin material no se activa")
	_dar(s.material, 3)   # 3 normales = 6 unidades
	_dar(s.nucleo, 3)
	_dar(s.runa, 7)
	var mat0: int = Game.unidades_material_en_hogar(s.material)
	var nuc0: int = Game.nucleos_en_hogar(s.nucleo)
	_ok(Runas.activar(peto, s) == "", "activa el set de slime en un peto")
	_ok(Game.unidades_material_en_hogar(s.material) == mat0 - 6 and Game.nucleos_en_hogar(s.nucleo) == nuc0 - 3,
		"gasta 6 unidades de baba y 3 nucleos")
	_ok(Runas.activar(peto, s) != "", "no se activa dos veces")
	_ok(Runas.activar(_w("res://resources/weapons/espada_corta.tres"), s) != "", "un set de armadura no va en un arma")
	var r0: int = Runas.runas_en_hogar(s)
	for i in 4:
		Runas.subir(peto)
	_ok(Runas.subs_de(peto).size() == 4 and Runas.runas_en_hogar(s) == r0 - 4, "sube a 4 sub-stats con 4 runas")
	_ok(Runas.subir(peto) != "", "y no pasa de 4")
	var antes: String = str(Runas.subs_de(peto)[0]["s"])
	Runas.cambiar(peto, 0)
	_ok(str(Runas.subs_de(peto)[0]["s"]) != antes, "cambiar pone OTRA sub-stat (%s -> %s)" % [antes, Runas.subs_de(peto)[0]["s"]])
	var clave: String = str(Runas.subs_de(peto)[1]["s"])
	Runas.retirar(peto, 1)
	_ok(str(Runas.subs_de(peto)[1]["s"]) == clave, "re-tirar deja la misma sub-stat")
	_ok(Runas.runas_en_hogar(s) == r0 - 6, "cada accion cuesta una runa")
	for sub in Runas.subs_de(peto):
		_ok(int(Runas.subs()[sub["s"]]["pesos"][Runas.Lista.ARMADURA]) > 0, "  %s es de armadura" % Runas.sub_txt(sub))
	_ok(Runas.filas(peto).size() == 5, "la ficha enseña el set y sus 4 sub-stats")
	_ok(Runas.desencantar(peto) == "" and Runas.runas_de(peto).is_empty(), "desencantar la deja limpia")


func _red() -> void:
	print("=== POR LA RED ===")
	var peto: Resource = _w("res://resources/armor/cuero_pecho.tres")
	Game.meta_de(peto)["runas"] = {"set": "slime", "subs": [{"s": "vida_pct", "v": 0.05}]}
	var d: Dictionary = Game.serializar_equipo(peto)
	var copia: Resource = Game.deserializar_equipo(d, false)
	_ok(Runas.set_de(copia) != null and Runas.set_de(copia).id == &"slime", "el set llega al otro lado")
	_ok(is_equal_approx(float(Runas.subs_de(copia)[0]["v"]), 0.05), "y sus sub-stats")
	Runas.subs_de(copia)[0]["v"] = 0.09
	_ok(is_equal_approx(float(Runas.subs_de(peto)[0]["v"]), 0.05), "es una COPIA (tocar una no toca la otra)")


func _combate() -> void:
	print("=== EN EL COMBATE ===")
	var pj: PersonajeData = Game.lider()
	var guardado: Array = [pj.equipped_main, pj.equipped_off, pj.equipped_pecho, pj.equipped_casco]
	var espada: Resource = _w("res://resources/weapons/espada_corta.tres")
	pj.equipped_main = espada
	pj.equipped_off = null
	pj.equipped_pecho = null
	pj.equipped_casco = null
	var c0: Combatant = Game.crear_player_combatant(pj)
	Game.meta_de(espada)["runas"] = {"set": "fuego", "subs": [{"s": "ataque_pct", "v": 0.10}, {"s": "crit", "v": 0.05}]}
	var c1: Combatant = Game.crear_player_combatant(pj)
	_ok(is_equal_approx(c1.ataque_arma, c0.ataque_arma * 1.10), "Ataque +10 %% en el arma (%.2f -> %.2f)" % [c0.ataque_arma, c1.ataque_arma])
	_ok(is_equal_approx(c1.crit_bonus, c0.crit_bonus + 0.05), "critico +5 %")
	_ok(c1.runa_ignicion_prob == 0.0, "una pieza de Ignicion sola no activa el set (pide 2)")
	# Dos piezas de armadura de slime: el bonus de 2 (Vida +12 %).
	var peto: Resource = _w("res://resources/armor/cuero_pecho.tres")
	var casco: Resource = _w("res://resources/armor/cuero_casco.tres")
	pj.equipped_pecho = peto
	pj.equipped_casco = casco
	var c2: Combatant = Game.crear_player_combatant(pj)
	Game.meta_de(peto)["runas"] = {"set": "slime", "subs": [{"s": "defensa_pct", "v": 0.10}]}
	Game.meta_de(casco)["runas"] = {"set": "slime", "subs": []}
	var c3: Combatant = Game.crear_player_combatant(pj)
	_ok(is_equal_approx(float(c3.max_hp), float(c2.max_hp) * 1.12), "2 piezas de slime: Vida +12 %% (%.1f -> %.1f)" % [c2.max_hp, c3.max_hp])
	_ok(is_equal_approx(c3.def_value(), c2.def_value() * 1.10), "Defensa +10 %")
	Game._aplicar_loadout(c3, pj)
	_ok(is_equal_approx(c3.def_value(), c2.def_value() * 1.10), "reaplicar el equipo en la pelea NO lo acumula")
	_ok(c3.runa_gordo_reduce == 0.0, "el efecto de 5 piezas no salta con 2")
	# El daño final: un % encima del golpe.
	var e := Combatant.new("Blanco", 1, Abilities.new(), 500.0, 3.0, 3.0, 3.0)
	c1.runa_final_fis = 0.0
	seed(7)
	var g0: float = float(StatsMath.resolve_attack(c1, e, false, -1.0, 0.0, 0.0, false)["damage"])
	c1.runa_final_fis = 0.04
	seed(7)
	var g1: float = float(StatsMath.resolve_attack(c1, e, false, -1.0, 0.0, 0.0, false)["damage"])
	_ok(is_equal_approx(g1, g0 * 1.04), "Daño final +4 %% (%.2f -> %.2f)" % [g0, g1])
	# Masa gelatinosa: el primer golpe gordo entra menos, una vez.
	var t := Combatant.new("Tanque", 1, Abilities.new(), 100.0, 3.0, 3.0, 3.0)
	t.runa_gordo_umbral = 0.2
	t.runa_gordo_reduce = 0.4
	t.take_damage(30.0)
	_ok(is_equal_approx(t.current_hp, 100.0 - 18.0), "golpe gordo: 30 -> 18")
	t.take_damage(30.0)
	_ok(is_equal_approx(t.current_hp, 82.0 - 30.0), "el segundo entra entero")
	# Marea: el escudo se come el daño y para el Lento.
	var m := Combatant.new("Marea", 1, Abilities.new(), 100.0, 3.0, 3.0, 3.0)
	m.runa_escudo_agua = 15.0
	m.apply_status(StatusEffects.Id.LENTO)
	_ok(not m.has_status(StatusEffects.Id.LENTO), "con escudo de agua no te dejan Lento")
	m.take_damage(20.0)
	_ok(is_equal_approx(m.current_hp, 95.0) and m.runa_agua_rota, "el escudo se come 15 de 20 y se rompe")
	pj.equipped_main = guardado[0]
	pj.equipped_off = guardado[1]
	pj.equipped_pecho = guardado[2]
	pj.equipped_casco = guardado[3]


func _drops() -> void:
	print("=== DROPS ===")
	for f in ["slime", "slime_veneno", "slime_fuego", "slime_abisal", "slime_profundo", "rey_slime"]:
		var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % f)
		var s_ok: bool = false
		for s in Runas.sets():
			if (s as RunaSetData).runa == ed.drop_runa:
				s_ok = true
		_ok(ed.drop_runa != null and s_ok, "%s suelta la runa de su set (%s)" % [f, ed.drop_runa.nombre if ed.drop_runa else "-"])
	_ok(Runas.DROP_RUNA[0] < 0.01 and Runas.DROP_RUNA[2] > Runas.DROP_RUNA[1], "0,5 % normal / 30 % mut1 / 70 % mut2")
