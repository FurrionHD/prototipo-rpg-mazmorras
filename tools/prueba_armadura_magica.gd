# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_armadura_magica.tscn
#
# FASE 2 del plan de mecanicas (08/10/2026): la armadura da DEFENSA MAGICA, al reves que la fisica
# (la suma fisica + magica es 3,2 en todas las categorias), y una REDUCCION contra la magia tambien al
# reves. Mira la tabla, que llega al combatiente, que la multiplica la Voluntad y que frena hechizos.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _ready() -> void:
	_tabla()
	_al_combatiente()
	_hechizo()
	_tela()
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)


const PECHOS := {
	"cuero": "res://resources/armor/cuero_pecho.tres",
	"hierro": "res://resources/armor/hierro_pecho.tres",
	"hierro_completo": "res://resources/armor/hierro_completo_pecho.tres",
	"placas": "res://resources/armor/placas_pecho.tres",
}


func _tabla() -> void:
	print("=== LA TABLA: FISICA + MAGICA = 3,2 ===")
	for k in PECHOS:
		var a: ArmorData = load(PECHOS[k])
		_ok(is_equal_approx(a.motion_def + a.mdef_motion(), 3.2),
			"%s: fisica %.1f + magica %.1f" % [k, a.motion_def, a.mdef_motion()])
	# La reduccion va AL REVES POR POSICION: la magica de una es la fisica de su espejo en la escalera
	# tela-cuero-hierro-completo-placas (cuero <-> hierro completo, placas <-> tela).
	var placas: ArmorData = load(PECHOS["placas"])
	var cuero: ArmorData = load(PECHOS["cuero"])
	var hcomp: ArmorData = load(PECHOS["hierro_completo"])
	var hierro: ArmorData = load(PECHOS["hierro"])
	_ok(is_equal_approx(cuero.reduccion_magia(), hcomp.reduccion)
		and is_equal_approx(hcomp.reduccion_magia(), cuero.reduccion), "reduccion: cuero <-> hierro completo")
	_ok(is_equal_approx(hierro.reduccion_magia(), hierro.reduccion), "reduccion: el hierro, en medio, igual")
	_ok(is_equal_approx(placas.reduccion_magia(), 0.04) and is_equal_approx(
		ArmorData.REDUCCION_MAGICA_TIPO[ArmorData.Tipo.TELA], placas.reduccion), "reduccion: placas <-> tela")
	var mp := Upgrades.armor_piece_mods(placas, 1.0, 0, {}, 1)
	var mc := Upgrades.armor_piece_mods(cuero, 1.0, 0, {}, 1)
	_ok(float(mp["def"]) > float(mc["def"]) and float(mp["mdef"]) < float(mc["mdef"]),
		"placas: mas fisica y menos magica que el cuero")
	var mejoras := {Upgrades.DUREZA: 3}
	var m3 := Upgrades.armor_piece_mods(cuero, 1.0, 0, mejoras, 1)
	_ok(is_equal_approx(float(m3["mdef"]) / float(mc["mdef"]), float(m3["def"]) / float(mc["def"])),
		"la Dureza sube la magica en la misma proporcion que la fisica")
	_ok(ArmorData.es_ligera(ArmorData.Tipo.TELA) and not ArmorData.es_ligera(ArmorData.Tipo.PLACAS),
		"la TELA es ligera (Evasion), las placas no")


func _al_combatiente() -> void:
	print("=== LLEGA AL COMBATIENTE ===")
	var pj: PersonajeData = Game.lider()
	var guardado: Array = [pj.equipped_pecho, pj.voluntad]
	pj.equipped_pecho = null
	var c0: Combatant = Game.crear_player_combatant(pj)
	pj.equipped_pecho = load(PECHOS["cuero"])
	var c1: Combatant = Game.crear_player_combatant(pj)
	_ok(c1.extra_magic_def > 0.0 and c1.mdef_value() > c0.mdef_value(),
		"con peto de cuero sube la DEF magica (%.2f -> %.2f)" % [c0.mdef_value(), c1.mdef_value()])
	_ok(c1.armor_reduction_magica > 0.0, "y la reduccion magica (%.3f)" % c1.armor_reduction_magica)
	pj.voluntad = 250
	var c2: Combatant = Game.crear_player_combatant(pj)
	_ok(is_equal_approx(c2.mdef_value(), c1.mdef_value() * 2.0),
		"Voluntad 250 dobla TODA la DEF magica, la de la armadura incluida")
	pj.equipped_pecho = guardado[0]
	pj.voluntad = guardado[1]


func _hechizo() -> void:
	print("=== FRENA LOS HECHIZOS ===")
	var sp: SpellData = load("res://resources/spells/pulso_menor.tres")
	var at_ab := Abilities.new()
	at_ab.magia = 300
	var at := Combatant.new("Mago", 1, at_ab, 50.0, 5.0, 5.0, 5.0)
	var def_ab := Abilities.new()
	var d0 := Combatant.new("Blanco", 1, def_ab, 500.0, 5.0, 5.0, 5.0)
	d0.stats_multiplicativas = true
	d0.base_magic = 5.0
	var d1 := Combatant.new("Blanco", 1, def_ab, 500.0, 5.0, 5.0, 5.0)
	d1.stats_multiplicativas = true
	d1.base_magic = 5.0
	d1.extra_magic_def = 10.0
	d1.armor_reduction_magica = 0.10
	var s0: float = 0.0
	var s1: float = 0.0
	for i in 200:
		seed(i)
		s0 += float(StatsMath.resolve_spell(at, d0, sp)["damage"])
		seed(i)
		s1 += float(StatsMath.resolve_spell(at, d1, sp)["damage"])
	print("    sin armadura %.2f · con armadura %.2f (media de 200)" % [s0 / 200.0, s1 / 200.0])
	_ok(s1 < s0 * 0.9, "la armadura frena el hechizo")


func _mat(id: String) -> MaterialData:
	return load("res://resources/materials/%s.tres" % id) as MaterialData


func _tela() -> void:
	print("=== LA TELA: HILAR Y COSER ===")
	_ok(Game.tela_de(_mat("hierba_palida")) == _mat("tela_hierba"), "hierba palida -> tela de hierba")
	_ok(Game.tela_de(_mat("sanguinaria")) == _mat("tela_sanguina"), "sanguinaria -> tela sanguina (T1 +2)")
	_ok(Game.tela_de(_mat("esporas_densas")) == _mat("tela_moho"), "esporas densas -> tela de moho (equivalente)")
	_ok(Game.tela_de(_mat("polvo_de_alas")) == _mat("tela_umbria"), "polvo de alas -> tela umbria (equivalente)")
	var tunica: ArmorData = load("res://resources/armor/tela_pecho.tres")
	var peto: ArmorData = load("res://resources/armor/cuero_pecho.tres")
	_ok(Game.es_armadura_cosida(tunica) and Game.es_armadura_tela(tunica), "la tunica se cose en la peleteria")
	_ok(String(Forge.coste(tunica)["forma"]) == "hebillas", "y lleva hebillas, como el cuero")
	var heb: MaterialData = _mat("hebillas_cobre")
	var ings: Array = Game.ingredientes_forja(tunica, heb)
	_ok(ings.size() == 2 and ings[1]["material"] == _mat("tela_hierba"), "coserla pide tela de hierba (T1)")
	_ok(Game.ingredientes_forja(peto, heb)[1]["material"] == Game.cuero_de_tier(1), "el peto sigue pidiendo cuero")
	_ok(Game.fibra_de_forja(tunica, heb, 4) == _mat("tela_raiz"), "mejorarla del +4 pide tela de raiz (su banda)")
	var mt := Upgrades.armor_piece_mods(tunica, 1.0, 0, {}, 1)
	var mc := Upgrades.armor_piece_mods(peto, 1.0, 0, {}, 1)
	_ok(float(mt["mdef"]) > float(mc["mdef"]) and float(mt["def"]) < float(mc["def"]),
		"la tunica: mas DEF magica y menos fisica que el peto de cuero")
	_ok(ArmaduraSprites.nombre_tipo(ArmorData.Tipo.TELA) == "cuero", "se pinta como el cuero (provisional), no como placas")
	# HILAR de verdad: 9 hierbas normales dan 2 telas (4 por tela) y sobra 1.
	var hierba: MaterialData = _mat("hierba_palida")
	var cal: int = MaterialItem.Calidad.NORMAL
	var antes_h: int = Game.items_calidad_en_hogar(hierba, cal)
	var antes_t: int = 0
	for c in [MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.INTACTO]:
		antes_t += Game.items_calidad_en_hogar(_mat("tela_hierba"), c)
	for i in 9:
		Game.almacen_materiales.append(MaterialItem.crear(hierba, cal))
	var n: int = Game.hilar(cal, 5, hierba)
	var despues_t: int = 0
	for c in [MaterialItem.Calidad.NORMAL, MaterialItem.Calidad.INTACTO]:
		despues_t += Game.items_calidad_en_hogar(_mat("tela_hierba"), c)
	_ok(n == 2 and despues_t - antes_t >= 2, "hilar 9 hierbas da 2 telas (%d)" % n)
	_ok(Game.items_calidad_en_hogar(hierba, cal) - antes_h <= 1, "y gasta 4 por tela")
