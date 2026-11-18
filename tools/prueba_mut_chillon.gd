# PRUEBA (sin ventana): LOS MUTANTES DEL CHILLON (18/11, memoria chillon-mutante).
#
#   1. La ficha: la base con su Voluntad, el Apagaluces (1a) y la Piña negra (2a, desde el Apagaluces), sus stats y kits.
#   2. El Chillido de oscuridad: magico de Oscuridad, en circulo de 70 alrededor suyo, 0,36.
#   3. Los sprites: cada mutante el suyo (con sus animaciones), y la cria con el suyo.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	print(("  ok   " if cond else "  MAL: ") + que)
	if not cond:
		_mal += 1


func _ready() -> void:
	var ed: EnemyData = load("res://scenes/actors/enemy/chillon.tres")
	_ficha(ed)
	_chillido()
	_sprites(ed)
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


func _suma(m: Dictionary) -> int:
	var s := 0
	for k in m:
		s += int(m[k])
	return s


func _ficha(ed: EnemyData) -> void:
	print("=== LA FICHA ===")
	_ok([ed.resistencia, ed.fuerza, ed.destreza, ed.agilidad, ed.magia, ed.voluntad] == [20, 30, 38, 58, 14, 20],
		"la base: R20 F30 D38 A58 M14 V20 (suma 180)")
	var ap: MutacionData = ed.mutacion_de(&"apagaluces")
	var pi: MutacionData = ed.mutacion_de(&"pina")
	_ok(ap != null and pi != null, "el Apagaluces y la Piña negra")
	if ap == null or pi == null:
		return
	_ok(ap.grado == 1 and ap.nombre == "Apagaluces", "el Apagaluces, de 1a")
	_ok(pi.grado == 2 and pi.desde == [&"apagaluces"] and pi.nombre == "Piña negra", "la Piña negra, de 2a desde el Apagaluces")
	_ok(_suma(ap.pesos) == 180 and _suma(pi.pesos) == 180, "los dos suman 180 (%d, %d)" % [_suma(ap.pesos), _suma(pi.pesos)])
	_ok(int(ap.pesos["magia"]) == 32 and int(pi.pesos["resistencia"]) == 38 and int(pi.pesos["voluntad"]) == 32,
		"sus stats (Apagaluces M32, Piña R38 V32)")
	_ok(ed.siguiente_mutacion(false, &"")["id"] == &"apagaluces" and ed.siguiente_mutacion(true, &"apagaluces")["id"] == &"pina",
		"del normal al Apagaluces y del Apagaluces a la Piña")
	var noms_a: Array = ap.habilidades.map(func(a): return a.nombre)
	var noms_p: Array = pi.habilidades.map(func(a): return a.nombre)
	_ok(noms_a.has("Chillido de oscuridad") and noms_a.has("Picado"), "el Apagaluces: Chillido de oscuridad y Picado")
	_ok(noms_p == ["Chillido de oscuridad"], "la Piña: Chillido de oscuridad, sin Picado")
	var c: Combatant = ed.crear_combatant(0.5, true, false, &"apagaluces")
	_ok(c.nombre.contains("Apagaluces"), "en la pelea se llama Apagaluces (%s)" % c.nombre)


func _chillido() -> void:
	print("=== EL CHILLIDO DE OSCURIDAD ===")
	var ab: AbilityData = load("res://resources/abilities/chillon_chillido_oscuro.tres")
	_ok(ab.es_magico and ab.elemento_golpe == Elementos.Elemento.OSCURIDAD, "magico de Oscuridad")
	_ok(ab.forma == CombatFormas.Tipo.CIRCULO and ab.forma_apunte == CombatFormas.Apunte.ALREDEDOR
		and is_equal_approx(ab.forma_radio, 70.0), "en circulo de 70 alrededor suyo")
	_ok(is_equal_approx(ab.dano_mult, 0.36) and ab.fx_anim == &"chillido_oscuro", "0,36 y con su gesto")


func _sprites(ed: EnemyData) -> void:
	print("=== LOS SPRITES ===")
	for par in [[&"apagaluces", ["idle_0", "chillido_oscuro_0", "embestida_0", "comer_0", "evolucion_0"]],
			[&"pina", ["idle_0", "chillido_oscuro_0", "soltar_0", "evolucion_0", "muerte_0"]]]:
		_ok(Chillon3DSprites.tiene_mutante(ed, par[0]), "%s tiene su sprite" % par[0])
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, par[0])
		var faltan: Array = (par[1] as Array).filter(func(a): return sf == null or not sf.has_animation(StringName(a)))
		_ok(faltan.is_empty(), "%s: con sus animaciones (faltan %s)" % [par[0], str(faltan)])
	var sp: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5, true, &"pina")
	_ok(sp != null and not sp.has_animation(&"embestida_0"), "la Piña no pica")
