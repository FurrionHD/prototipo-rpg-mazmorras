extends "res://tools/unitarias/caso.gd"
# PeleaViva (scripts/net/pelea_viva.gd, etapa 3): los nombres de siempre de Game y Net.peleas leen y escriben en la
# pelea de la maquina (Game.pelea). Con una pelea todo es lo de antes: lo que se pone por un lado se ve por el otro.


func _guardar() -> Dictionary:
	var p: PeleaViva = Game.pelea
	return {"enemigos": p.enemigos, "capa": p.capa, "montaje": p.montaje_ms, "cs": p.aliados_cs,
		"pjs": p.aliados_pjs, "tras": p.traspasados, "cola": p.cola, "arena": p.arena_nodo,
		"puntos": p.puntos_arena_fichas, "zona": p.zona, "id": p.id, "part": p.participantes,
		"dobles": p.dobles, "humano": p.humano, "t": p.t_cierre}


func _devolver(d: Dictionary) -> void:
	var p: PeleaViva = Game.pelea
	p.enemigos = d["enemigos"]
	p.capa = d["capa"]
	p.montaje_ms = d["montaje"]
	p.aliados_cs = d["cs"]
	p.aliados_pjs = d["pjs"]
	p.traspasados = d["tras"]
	p.cola = d["cola"]
	p.arena_nodo = d["arena"]
	p.puntos_arena_fichas = d["puntos"]
	p.zona = d["zona"]
	p.id = d["id"]
	p.participantes = d["part"]
	p.dobles = d["dobles"]
	p.humano = d["humano"]
	p.t_cierre = d["t"]


func test_game_lee_de_su_pelea() -> void:
	var antes := _guardar()
	var p: PeleaViva = Game.pelea
	cierto(p != null and p.is_inside_tree(), "Game lleva su pelea colgada")
	var n := Node.new()
	var cuantos: int = p.enemigos.size()
	Game._active_enemies.append(n)
	igual(p.enemigos.size(), cuantos + 1, "append por el nombre viejo llega a la caja")
	cierto(p.en_marcha(), "con un enemigo, la pelea esta en marcha")
	Game._active_player_pjs = [1, 2]
	igual(p.aliados_pjs, [1, 2], "asignar por el nombre viejo escribe en la caja")
	p.cola = [3]
	igual(Game._cola_combate, [3], "lo que se pone en la caja se ve por el nombre viejo")
	Game._montaje_ms = 77
	igual(p.montaje_ms, 77, "_montaje_ms")
	Game.enemigos_traspasados = [0]
	igual(p.traspasados, [0], "enemigos_traspasados")
	Game._mi_zona = {"anfitrion": 5}
	igual(p.zona, {"anfitrion": 5}, "_mi_zona")
	Game._active_enemies.erase(n)
	n.free()
	_devolver(antes)


func test_net_peleas_lee_de_la_misma() -> void:
	var antes := _guardar()
	var p: PeleaViva = Game.pelea
	Net.peleas._pelea_id = 42
	igual(p.id, 42, "_pelea_id")
	Net.peleas._pelea_participantes.append(7)
	cierto(p.participantes.has(7), "_pelea_participantes")
	Net.peleas._dobles[7] = []
	cierto(p.dobles.has(7), "_dobles")
	p.humano = 9
	igual(Net.peleas._pelea_humano, 9, "_pelea_humano")
	Net.peleas._t_cierre = 1.5
	igual(p.t_cierre, 1.5, "_t_cierre")
	Net.peleas._pelea_participantes.erase(7)
	Net.peleas._dobles.erase(7)
	_devolver(antes)


func test_dos_peleas_cada_cosa_en_la_suya() -> void:
	var a := PeleaViva.new()
	var b := PeleaViva.new()
	arbol.add_child(a)
	arbol.add_child(b)
	var ca := Combatant.new("x", 1, Abilities.new(), 10.0, 1.0, 1.0, 1.0)
	var cb := Combatant.new("x", 1, Abilities.new(), 10.0, 1.0, 1.0, 1.0)
	var pja := PersonajeData.new()
	var pjb := PersonajeData.new()
	var ea := Node.new()
	var eb := Node.new()
	a.aliados_cs = [ca]
	a.aliados_pjs = [pja]
	a.enemigos.append(ea)
	b.aliados_cs = [cb]
	b.aliados_pjs = [pjb]
	b.enemigos.append(eb)
	igual(PeleaViva.de_combatiente(ca), a, "el combatiente de A es de A")
	igual(PeleaViva.de_combatiente(cb), b, "el de B es de B")
	igual(PeleaViva.de_ficha(pjb), b, "la ficha de B es de B")
	igual(PeleaViva.de_enemigo(ea), a, "el enemigo de A es de A")
	igual(Game.pj_de_combatant(cb), pjb, "Game.pj_de_combatant encuentra la ficha en SU pelea")
	igual(Game.combatant_de_pj(pja), ca, "Game.combatant_de_pj tambien")
	cierto(Game.esta_en_combate(eb), "el enemigo de B esta en combate")
	cierto(PeleaViva.de_combatiente(Combatant.new("x", 1, Abilities.new(), 10.0, 1.0, 1.0, 1.0)) == null, "uno suelto no es de ninguna")
	arbol.remove_child(b)
	cierto(PeleaViva.de_enemigo(eb) == null, "fuera del arbol, la pelea ya no cuenta")
	b.free()
	arbol.remove_child(a)
	a.free()
	ea.free()
	eb.free()
