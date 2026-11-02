# ============================================================
#  PRUEBA: LOS BICHOS DEL AMBAR (02/11/2026, trent-mutante, paso 2): los que suelta la costra del Tocon ambarino.
#  1) Las tres fichas (resources/enemigos_invocados/bicho_*.tres): sus stats del jefe, UNA habilidad cada uno con sus
#     numeros, y que no suelten nada.
#  2) Sus sprites, horneados: las animaciones que usan, y las tres hinchazones de la garrapata (variantes de la pelea).
#  3) Los estados nuevos: el PICOR quita el 10 % de la energia que queda al empezar el turno, y el PRINGADO corta los
#     objetos (tambien por la puerta del espejo).
#    godot --headless --path . res://tools/prueba_bichos_ambar.tscn
# ============================================================
extends Node

const CARPETA := "res://resources/enemigos_invocados/"

var _mal: int = 0


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _tiene(ab: AbilityData, estado: int, prob: float) -> bool:
	for sa in ab.efectos:
		if sa.estado == estado and is_equal_approx(sa.prob, prob):
			return true
	return false


func _ready() -> void:
	print("1) LAS FICHAS")
	var stats := {"garrapata": [20, 36, 30, 32, 12, 20], "mosquito": [16, 16, 34, 50, 14, 20],
		"pelotero": [24, 40, 26, 26, 12, 22]}
	var eds := {}
	for k in stats:
		var ed: EnemyData = load(CARPETA + "bicho_%s.tres" % k) as EnemyData
		eds[k] = ed
		_ver(ed != null, "%s: la ficha carga" % k)
		if ed == null:
			continue
		var s: Array = [ed.fuerza, ed.resistencia, ed.destreza, ed.agilidad, ed.magia, ed.voluntad]
		_ver(s == stats[k], "%s: stats %s" % [k, str(s)])
		_ver(ed.habilidades.size() == 1, "%s: una sola habilidad (%d)" % [k, ed.habilidades.size()])
		_ver(ed.drop_material == null and ed.nucleo == null, "%s: no suelta nada" % k)
	var eng: AbilityData = eds["garrapata"].habilidades[0]
	_ver(eng.pega and eng.salta and is_equal_approx(eng.forma_rango, 60.0) and is_equal_approx(eng.dano_mult, 0.6)
		and is_equal_approx(eng.robo_vida, 0.5), "Enganche: salta 60, se pega y chupa x0,6 (la mitad para ella)")
	var pic: AbilityData = eds["mosquito"].habilidades[0]
	_ver(is_equal_approx(pic.dano_mult, 0.7) and is_equal_approx(pic.robo_vida, 0.5) and pic.cooldown == 2
		and _tiene(pic, StatusEffects.Id.PICOR, 0.7), "Picadura: x0,7, mitad para el, Picor 70 %, cd 2")
	var bol: AbilityData = eds["pelotero"].habilidades[0]
	_ver(bol.forma == 3 and is_equal_approx(bol.forma_radio, 100.0) and is_equal_approx(bol.dano_mult, 0.8)
		and bol.cooldown == 3 and _tiene(bol, StatusEffects.Id.PRINGADO, 0.7), "Bola de caca: linea 100, x0,8, Pringado 70 %, cd 3")

	print("2) LOS SPRITES")
	var anims := {"garrapata": ["idle_0", "walk_0", "embestida_0", "adherirse_0", "adherido_0", "drenaje_0", "muerte_0",
		"cadaver_0"], "mosquito": ["idle_0", "walk_0", "embestida_0", "picadura_0", "muerte_0", "cadaver_0"],
		"pelotero": ["idle_0", "walk_0", "embestida_0", "bola_0", "muerte_0", "cadaver_0"]}
	for k in anims:
		var ed: EnemyData = eds[k]
		_ver(SpriteLienzo.descripcion(SpritesEnemigo.clave_de(ed, 0.5)) != null, "%s: horneado (%s)" % [k,
			SpritesEnemigo.clave_de(ed, 0.5)])
		var sf: SpriteFrames = SpritesEnemigo.frames_de(ed, 0.5)
		var faltan: Array = []
		for a in anims[k]:
			if sf == null or not SpriteLienzo.asegurar_anim(sf, StringName(a)):
				faltan.append(a)
		_ver(faltan.is_empty(), "%s: con sus animaciones (faltan %s)" % [k, str(faltan)])
		_ver(SpritesEnemigo.tam_cuerpo(ed).x > 5.0, "%s: con cuerpo para chocar %s" % [k, str(SpritesEnemigo.tam_cuerpo(ed))])
	for h in [&"h1", &"h2", &"h3"]:
		var sv: SpriteFrames = SpritesEnemigo.frames_variante(eds["garrapata"], &"", h)
		_ver(sv != null and SpriteLienzo.asegurar_anim(sv, &"adherido_0")
			and SpriteLienzo.descripcion("garrapata3d_%s" % h) != null, "la garrapata hinchada %s, horneada" % h)

	print("3) LOS ESTADOS")
	var c := Combatant.new("Picado", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
	c.max_energy = 50.0
	c.current_energy = 30.0
	c.apply_status(StatusEffects.Id.PICOR)
	var ev: Dictionary = c.tick_statuses()
	_ver(is_equal_approx(c.current_energy, 27.0) and is_equal_approx(float(ev.get("energia", 0.0)), 3.0),
		"Picor: al empezar su turno pierde el 10 %% de la que le queda (30 -> %.1f)" % c.current_energy)
	c.current_energy = 2.0
	c.tick_statuses()
	_ver(is_equal_approx(c.current_energy, 1.8), "con poca, pierde poco (2 -> %.2f)" % c.current_energy)
	_ver(not c.pringado(), "sin Pringado puede usar objetos")
	c.apply_status(StatusEffects.Id.PRINGADO)
	_ver(c.pringado(), "con Pringado no")
	var maniqui := Combatant.new("Maniqui", 1, Abilities.new(), 100.0, 5.0, 5.0, 5.0)
	maniqui.puertas_remotas = c.puertas()
	_ver(maniqui.pringado(), "y el maniqui del espejo lo sabe (puerta)")
	_ver(StatusEffects.def(StatusEffects.Id.PRINGADO)["turns"] == 2 and StatusEffects.def(StatusEffects.Id.PICOR)["turns"] == 3,
		"duran 2 (Pringado) y 3 (Picor) turnos")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
