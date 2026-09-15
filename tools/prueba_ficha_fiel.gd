# PRUEBA: el DOBLE que monta un trabajador de pelea tiene que pelear IGUAL que el personaje en su PC.
# Para cada personaje de la partida de referencia se crea su combatiente como en solitario y otro a partir de
# la ficha que viaja por la red (Net.partida.ficha_a_dict -> ficha_de_dict), y se comparan los numeros que
# usa la pelea. Sin red ni procesos: tarda segundos.
#   godot --headless --path . res://tools/prueba_ficha_fiel.tscn
extends Node

const MUNDO_REF := "res://tools/huellas/mundo_ref.tres"


func _ready() -> void:
	await get_tree().process_frame
	var ref = ResourceLoader.load(MUNDO_REF, "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (ref is SaveData):
		print("[ficha] SIN PARTIDA DE REFERENCIA")
		get_tree().quit(1)
		return
	Game.importar_partida(ref)
	var fallos := 0
	for pj in Game.plantilla:
		var local: Combatant = Game.crear_player_combatant(pj)
		var doble: PersonajeData = Net.partida.ficha_de_dict(Net.partida.ficha_a_dict(pj))
		var remoto: Combatant = Game.crear_player_combatant(doble)
		var a := _numeros(local)
		var b := _numeros(remoto)
		var distintos: Array = []
		for k in a:
			if absf(float(a[k]) - float(b[k])) > 0.001:
				distintos.append("%s %.3f -> %.3f" % [k, a[k], b[k]])
		if distintos.is_empty():
			print("[ficha] %s igual (def %.2f, red. %.3f)" % [pj.nombre, a["defensa"], a["reduccion_armadura"]])
		else:
			fallos += 1
			print("[ficha] %s CAMBIA: %s" % [pj.nombre, "; ".join(distintos)])
			for slot in ["main", "off", "casco", "pecho", "manos", "pantalones", "botas"]:
				print("[ficha]    %s: suyo %s | doble %s" % [slot, str(pj.equip_meta.get(slot, {})), str(doble.equip_meta.get(slot, {}))])
	print("[ficha] RESULTADO: ", "TODO IGUAL" if fallos == 0 else "CAMBIAN %d" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


func _numeros(c: Combatant) -> Dictionary:
	return {
		"vida_max": c.max_hp,
		"defensa": c.def_value(),
		"defensa_extra": c.extra_defense,
		"reduccion_armadura": c.armor_reduction,
		"velocidad": c.spd(),
		"vel_recitado": c.cast_spd(),
		"ataque_arma": c.ataque_arma,
		"magic_amp": c.magic_amp,
		"mana_max": c.max_mp,
	}
