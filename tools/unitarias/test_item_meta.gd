extends "res://tools/unitarias/caso.gd"
# LAS PIEZAS AJENAS NO ENTRAN EN TU BAUL (auditoria 13/10). crear_item(registrar=false) es para lo que NO es tuyo:
# el doble de un compañero en una pelea, los muñecos del roster, las vitrinas, el escaparate del cofre. Antes metia
# su meta en Game.item_meta (el de TU baul), con el propio objeto de clave: no se liberaba nunca y acababa en tu
# guardado. Ahora la lleva pegada el objeto, y meta_de la encuentra igual.

const ESPADA := "res://resources/weapons/espada_corta.tres"


func test_pieza_ajena_no_toca_item_meta() -> void:
	var antes: int = Game.item_meta.size()
	var p: Resource = Game.crear_item(load(ESPADA), 3, 2, {"filo": 1}, false)
	igual(Game.item_meta.size(), antes, "crear una pieza ajena no añade nada a item_meta")
	igual(int(Game.meta_de(p)["tier"]), 3, "pero meta_de sigue sabiendo su tier")
	igual(int(Game.meta_de(p)["rareza"]), 2, "y su rareza")
	cierto(Game.tiene_meta(p), "tiene_meta la reconoce como pieza forjada")
	igual(Game.item_meta.size(), antes, "y preguntar tampoco la mete")


func test_meta_de_una_ajena_es_siempre_la_misma() -> void:
	var p: Resource = Game.crear_item(load(ESPADA), 2, 0, {}, false)
	Game.meta_de(p)["durabilidad"] = 0.4
	cerca(float(Game.meta_de(p)["durabilidad"]), 0.4, 0.0001, "lo que se escribe en su meta se queda")


func test_roster_repintado_no_crece() -> void:
	# pj_de_dict es lo que se ejecuta en cada repintado del roster y en cada saludo de red
	var pj := PersonajeData.new()
	pj.equipped_main = Game.crear_item(load(ESPADA), 2, 1, {}, false)
	var d: Dictionary = Game.pj_a_dict(pj)
	var antes: int = Game.item_meta.size()
	for i in 50:
		var copia: PersonajeData = Game.pj_de_dict(d)
		if i == 0:
			cierto(copia.equipped_main != null, "la copia lleva su arma")
	igual(Game.item_meta.size(), antes, "50 repintados del roster no dejan nada en item_meta")
	var una: PersonajeData = Game.pj_de_dict(d)
	igual(int(una.equip_meta.get("main", {}).get("tier", -1)), 2, "y la equip_meta del muñeco lleva el tier")


func test_pieza_propia_si_entra() -> void:
	var antes: int = Game.item_meta.size()
	var p: Resource = Game.crear_item(load(ESPADA), 1, 0, {}, false)   # ajena
	var q: Resource = load(ESPADA).duplicate()
	Game.item_meta[q] = {"tier": 4}   # lo que hace crear_item con registrar=true, sin tocar el baul de verdad
	igual(Game.item_meta.size(), antes + 1, "una pieza propia si tiene su entrada")
	cierto(Game.tiene_meta(q) and Game.tiene_meta(p), "las dos tienen meta")
	Game.item_meta.erase(q)


func test_meta_si_hay_lee_sin_crear() -> void:
	var antes: int = Game.item_meta.size()
	var ajena: Resource = Game.crear_item(load(ESPADA), 2, 0, {}, false)
	Game.meta_de(ajena)["runas"] = {"set": "slime"}
	igual(String(Game.meta_si_hay(ajena).get("runas", {}).get("set", "")), "slime", "las runas de una pieza ajena se leen")
	var suelta: Resource = load(ESPADA).duplicate()
	igual(Game.meta_si_hay(suelta).size(), 0, "una pieza sin meta da {}")
	igual(Game.item_meta.size(), antes, "y preguntar no crea nada")
