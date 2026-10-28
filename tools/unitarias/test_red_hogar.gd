extends "res://tools/unitarias/caso.gd"
# El hogar por la red (scripts/net/net_hogar.gd, fase 3): lo que ya se difundio sin cambios no se repite.

const NH := preload("res://scripts/net/net_hogar.gd")


func test_solo_se_difunde_lo_que_cambia() -> void:
	var h: Node = NH.new()
	var cofre: Array = [{"id": 1, "desc": "Espada"}, {"id": 2, "desc": "Escudo"}]
	cierto(h._cambio("cofre", cofre), "la primera vez, si")
	cierto(not h._cambio("cofre", cofre.duplicate(true)), "lo mismo otra vez (otra copia), no")
	cofre.append({"id": 3, "desc": "Casco"})
	cierto(h._cambio("cofre", cofre), "con una pieza mas, si")
	(cofre[0] as Dictionary)["desc"] = "Espada +1"
	cierto(h._cambio("cofre", cofre), "con una pieza cambiada por dentro, si")
	cierto(h._cambio("roster", cofre), "cada cosa lleva su cuenta: el roster va aparte")
	h._hash_difundido.clear()
	cierto(h._cambio("cofre", cofre), "al cerrar la sesion se olvida: se vuelve a mandar")
	h.free()
