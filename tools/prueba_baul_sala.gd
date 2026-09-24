# PRUEBA: el INVENTARIO (lo no equipado) sobrevive a volver a entrar en un mundo compartido con sala.
# Reproduce el viaje sin red: mi juego empaqueta lo mio (mi_jugador_data -> jd_a_dict), la sala lo apunta
# a mi nombre dos veces seguidas (_mi_estado: jd_de_dict sin registrar), y al volver a entrar la sala me lo
# devuelve (jd_a_dict) y lo adopto como en _tu_jugador (limpiar_mundo_heredado + jd_de_dict + aplicar).
#   godot --headless --path . res://tools/prueba_baul_sala.tscn
extends Node


func _ready() -> void:
	call_deferred("_correr")


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	var fallos: int = 0
	# Lo suelto: dos martillos, un mandoble, una pieza de armadura y una mochila de repuesto.
	var sueltas: Array = [
		Game.crear_item(load("res://resources/weapons/martillo_grande.tres"), 2, 1, {}),
		Game.crear_item(load("res://resources/weapons/martillo_grande.tres"), 1, 0, {}),
		Game.crear_item(load("res://resources/weapons/mandobles.tres"), 3, 2, {}),
		Game.crear_item(load("res://resources/armor/cuero_casco.tres"), 1, 0, {}),
		Game.crear_item(load("res://resources/backpacks/mochila_basica.tres"), 1, 0, {}),
	]
	sueltas = sueltas.filter(func(x): return x != null)
	var puesta: Resource = Game.lider().equipped_main
	var antes_armas: int = Game.owned_weapons.size()
	var antes_arm: int = Game.owned_armor.size()
	var antes_moch: int = Game.owned_mochilas.size()
	print("antes: %d armas, %d armaduras, %d mochilas; %d sueltas nuevas; arma puesta: %s" % [
		antes_armas, antes_arm, antes_moch, sueltas.size(), str(puesta)])

	# 1) Mi juego manda lo mio. 2) La SALA lo apunta dos veces (dos autoguardados), SIN registrar.
	var paquete: Dictionary = Net.partida.jd_a_dict(Game.mi_jugador_data())
	print("  el paquete lleva %d piezas en el baul" % (paquete.get("baul", []) as Array).size())
	var en_sala: JugadorData = Net.partida.jd_de_dict(paquete, false)
	en_sala = Net.partida.jd_de_dict(Net.partida.jd_a_dict(en_sala), false)
	# 3) Vuelvo a entrar: la sala me manda lo que tiene apuntado, y lo adopto.
	var vuelta: Dictionary = Net.partida.jd_a_dict(en_sala)
	Game.limpiar_mundo_heredado()
	var jd: JugadorData = Net.partida.jd_de_dict(vuelta, true)
	Game.aplicar_jugador_mundo(jd, Game.semilla_mundo)
	print("despues: %d armas, %d armaduras, %d mochilas" % [
		Game.owned_weapons.size(), Game.owned_armor.size(), Game.owned_mochilas.size()])
	if Game.owned_weapons.size() != antes_armas:
		print("MAL: las armas no cuadran (%d antes, %d despues)" % [antes_armas, Game.owned_weapons.size()])
		fallos += 1
	if Game.owned_armor.size() != antes_arm:
		print("MAL: las armaduras no cuadran (%d antes, %d despues)" % [antes_arm, Game.owned_armor.size()])
		fallos += 1
	if Game.owned_mochilas.size() != antes_moch:
		print("MAL: las mochilas no cuadran (%d antes, %d despues)" % [antes_moch, Game.owned_mochilas.size()])
		fallos += 1
	# El mandoble T3 raro tiene que volver con su tier y su rareza.
	var hay_mandoble: bool = false
	for w in Game.owned_weapons:
		var m: Dictionary = Game.meta_de(w)
		if String(w.get("nombre")) == "Mandobles" and int(m.get("tier", 0)) == 3 and int(m.get("rareza", 0)) == 2:
			hay_mandoble = true
	if not hay_mandoble:
		print("MAL: el mandoble T3 no vuelve con su identidad")
		fallos += 1
	# Lo equipado sigue puesto y no esta dos veces en el baul.
	var main_ahora: Resource = Game.lider().equipped_main
	if main_ahora != null:
		var veces: int = Game.owned_weapons.count(main_ahora)
		if veces != 1:
			print("MAL: el arma puesta esta %d veces en el baul" % veces)
			fallos += 1
	print("=== %s ===" % ("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos))
	get_tree().quit(1 if fallos > 0 else 0)
