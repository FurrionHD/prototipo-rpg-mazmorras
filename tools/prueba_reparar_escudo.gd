# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_reparar_escudo.tscn
#
# EL ESCUDO SE REPARA (playtest 08/10: "la reparacion no detecta los escudos"). Mira que un escudo gastado sale en la
# lista del herrero, tiene precio, entra en "Reparar todo" y queda al 100 %. Y peleando (09/10): el escudo se gasta
# al PARAR un golpe y la varita al LANZAR un conjuro, y la varita tambien se repara.
extends Node

var _mal := 0


func _ok(cond: bool, que: String) -> void:
	if cond:
		print("  ok   ", que)
	else:
		_mal += 1
		print("  MAL: ", que)


func _ready() -> void:
	var pj: PersonajeData = Game.lider()
	var escudo: Resource = Game.crear_item(load("res://resources/shields/escudo_normal.tres"), 1, 0, {}, false)
	Game.equipar_secundaria(escudo, pj)
	Game.meta_de(escudo)["durabilidad"] = 0.4
	_ok(is_equal_approx(Game.durabilidad_slot("off", pj), 0.4), "el escudo equipado esta al 40 %%: %.2f" % Game.durabilidad_slot("off", pj))
	var precio: int = Game.precio_reparar("off", pj)
	_ok(precio > 0, "tiene precio de reparar: %d" % precio)
	_ok(Game._slots_reparables(pj).has("off"), "entra en 'Reparar todo'")
	var rep = load("res://scripts/ui/herreria/herreria_reparar.gd").new(null)
	var lista: Array = rep._reparables(pj)
	_ok(lista.any(func(p): return p["slot"] == "off" and p["item"] == escudo), "sale en la lista del herrero")
	Game.money = 1000000
	Game.reparar_todo(pj)
	_ok(is_equal_approx(Game.durabilidad_item(escudo), 1.0), "reparado al 100 %%: %.2f" % Game.durabilidad_item(escudo))
	var varita: Resource = Game.crear_item(load("res://resources/wands/" + DirAccess.get_files_at("res://resources/wands")[0].trim_suffix(".remap")), 1, 0, {}, false)
	Game.equipar_secundaria(varita, pj)
	# PELEANDO: el escudo se gasta al parar, la varita al lanzar; y la varita tambien se repara.
	Game.desgastar_por_magia(pj)
	_ok(Game.durabilidad_item(varita) < 1.0, "lanzar un conjuro gasta la varita: %.3f" % Game.durabilidad_item(varita))
	_ok(Game._slots_reparables(pj).has("off") and rep._reparables(pj).any(func(p): return p["slot"] == "off"),
		"y la varita se repara en el herrero")
	Game.equipar_secundaria(escudo, pj)
	Game.desgastar_escudo(pj)
	_ok(Game.durabilidad_item(escudo) < 1.0, "parar un golpe gasta el escudo: %.3f" % Game.durabilidad_item(escudo))
	print("")
	print("FIN: TODO BIEN" if _mal == 0 else "FIN: %d MAL" % _mal)
	get_tree().quit(1 if _mal > 0 else 0)
