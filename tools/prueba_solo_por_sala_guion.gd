# Guion del jugador de prueba_solo_por_sala (fase 2, 20/10, todo por la sala, paso 3): UNO SOLO, por la sala de su
# ranura, juega como el solo de siempre. Apunta lo que ve con "[P] ..." y la prueba lo lee de su registro.
#   1) En la arena, con dos slimes lejos: andan; abro un menu y se paran (y mi juego se pausa); lo cierro y siguen.
#   2) Peleo con uno: el mapa se para (el otro slime no se mueve); la pelea sigue.
#   3) En la pelea abro un menu: la pelea espera (las barras no se mueven); lo cierro y sigue. Y va a x2.
#   4) Acabo la pelea: todo en marcha otra vez.
# Lo que se mueve en el mapa se mira por lo que MANDA el trabajador (_objetivo del enemigo remoto), no por donde lo
# pinto: con mi juego en pausa mis dibujos no se mueven aunque el trabajador si.
extends "res://tools/prueba_town_dos_comun.gd"

const TOKEN_MENU := "prueba_menu"
const SLIME := "res://scenes/actors/enemy/slime.tres"

var _entrado := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # el guion sigue con mi juego en pausa (el menu abierto)
	prefijo = "[P] "
	var args := OS.get_cmdline_user_args()
	var i := args.find("cliente_solo")
	var puerto := int(args[i + 1])
	var codigo: String = args[i + 2]
	Identidad.id = args[i + 3]
	Net.partida.entrada_lista.connect(func():
		var arbol := get_tree()
		arbol.change_scene_to_file("res://scenes/levels/town.tscn")
		await arbol.process_frame
		Net.anunciar_lugar("pueblo")
		_entrado = true)
	await _esperar(0.5)
	_ok(Net.unirse("127.0.0.1", codigo, puerto, true) == OK, "me conecto a la sala de mi ranura")
	_ok(await _hasta(func(): return _entrado, 60.0), "entro con lo de mi ranura")
	_ok(Net._num_humanos == 1, "estoy solo: somos %d" % Net._num_humanos)
	await _esperar(1.0)
	await _guion()
	print("[P] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	Net.desconectar()
	await _esperar(1.0)
	get_tree().quit(0 if fallos.is_empty() else 1)


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


func _abrir_menu() -> void:
	Game.entrar_modal(Game.Modal.MENU, TOKEN_MENU)


func _cerrar_menu() -> void:
	Game.salir_modal(TOKEN_MENU)


# Donde dice el trabajador que esta cada enemigo vivo (id -> Vector2).
func _objetivos() -> Dictionary:
	var out := {}
	for nid in Net.enemigos._enem_nodos:
		var n = Net.enemigos._enem_nodos[nid]
		if is_instance_valid(n) and not n.esta_muerto() and n._objetivo != Vector2.INF:
			out[nid] = n._objetivo
	return out


# Cuanto se ha movido, como mucho, cada enemigo de 'antes' durante 'seg' segundos (solo los de 'ids', si se dan).
func _cuanto_se_mueven(seg: float, ids: Array = []) -> float:
	var antes := _objetivos()
	var maximo := 0.0
	var t := 0.0
	while t < seg:
		await _esperar(0.25)
		t += 0.25
		var ahora := _objetivos()
		for nid in antes:
			if (ids.is_empty() or ids.has(nid)) and ahora.has(nid):
				maximo = maxf(maximo, (ahora[nid] as Vector2).distance_to(antes[nid]))
	return maximo


func _suma_barras(p: Node) -> float:
	var s := 0.0
	for c in p._gauge:
		s += float(p._gauge[c])
	return s


func _guion() -> void:
	# --- 1) La arena, con dos slimes lejos ---
	Game.entrar_arena_de_pruebas()
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, 40.0), "entro en la arena")
	await _esperar(3.0)
	Net.pisos.pedir_piso_arena(15)   # que la pelea dure: con los del piso 1 mi grupo acaba en dos golpes
	await _esperar(1.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena(SLIME, yo.global_position + Vector2(520, 0), {})   # lejos: que no me vea y se me eche encima antes de tiempo
	Net.pisos.pedir_spawn_arena(SLIME, yo.global_position + Vector2(-520, 0), {})
	_ok(await _hasta(func(): return _objetivos().size() >= 2, 15.0), "salen los dos slimes (%d)" % _objetivos().size())
	var libre := await _cuanto_se_mueven(5.0)
	print("[P] dato mapa_libre=%d" % int(libre))
	_ok(libre > 4.0, "sin menu los enemigos andan (%.1f px)" % libre)

	_abrir_menu()
	_ok(await _hasta(func(): return Net.pausa_solo == Net.PAUSA_SOLO_TODO, 5.0), "con el menu, la sala para TODO (%d)" % Net.pausa_solo)
	_ok(get_tree().paused, "y mi juego se pausa, como en solitario")
	await _esperar(0.5)
	var con_menu := await _cuanto_se_mueven(4.0)
	print("[P] dato mapa_con_menu=%d" % int(con_menu))
	_ok(con_menu < 1.0, "con el menu abierto los enemigos NO se mueven (%.1f px)" % con_menu)
	_cerrar_menu()
	_ok(await _hasta(func(): return Net.pausa_solo == 0, 5.0), "al cerrarlo, todo en marcha (%d)" % Net.pausa_solo)
	_ok(not get_tree().paused, "y mi juego tambien")
	var despues := await _cuanto_se_mueven(5.0)
	_ok(despues > 4.0, "y los enemigos vuelven a andar (%.1f px)" % despues)

	# --- 2) La pelea: el mapa se para ---
	yo = get_tree().get_first_node_in_group("player") as Node2D
	var ids: Array = _objetivos().keys()
	ids.sort_custom(func(a, b): return (_objetivos()[a] as Vector2).distance_to(yo.global_position) \
		< (_objetivos()[b] as Vector2).distance_to(yo.global_position))
	var cerca: Node2D = Net.enemigos._enem_nodos[ids[0]]
	var lejos_id: int = int(ids[-1]) if ids.size() > 1 else -1
	await pelear_con(cerca)
	var p: Node = pantalla()
	_ok(await _hasta(func(): p = pantalla(); return p != null and is_instance_valid(p), 10.0), "empieza la pelea")
	if p == null:
		return
	_ok(await _hasta(func(): return Net.pausa_solo == Net.PAUSA_SOLO_MAPA, 5.0), "peleando, la sala para el MAPA (%d)" % Net.pausa_solo)
	var en_pelea: bool = p._enemies.any(func(e): return lejos_id >= 0 and p.turno_mapa != null \
		and p.turno_mapa.cuerpo_de(e) == Net.enemigos._enem_nodos.get(lejos_id))
	print("[P] [dev] el slime lejano (%d) %s en la pelea" % [lejos_id, "ESTA" if en_pelea else "no esta"])
	if not en_pelea and lejos_id >= 0:
		await _esperar(0.5)   # el ultimo paquete de posicion que ya venia de camino
		var lejano := await _cuanto_se_mueven(4.0, [lejos_id])
		print("[P] dato mapa_en_pelea=%d" % int(lejano))
		_ok(lejano < 1.0, "mientras peleo, el slime de fuera NO se mueve (%.1f px)" % lejano)

	# --- 3) Un menu en mitad de la pelea: la pelea espera ---
	# Primero mi turno (si me toca, Defiendo): con mi turno delante las barras no se mueven de todas formas.
	_ok(await _hasta(func(): return int(p._state) == 1 or _suma_barras(p) > 0.0, 20.0), "la pelea avanza")
	await _hasta(func(): pulsar(3); return int(p._state) != 1, 10.0)
	_abrir_menu()
	_ok(await _hasta(func(): return Net.pausa_solo == Net.PAUSA_SOLO_TODO, 5.0), "con un menu en la pelea, la sala para TODO (%d)" % Net.pausa_solo)
	await _esperar(1.5)   # lo que estaba en el aire (una embestida) acaba
	var b0 := _suma_barras(p)
	var turno0 := int(p._state)
	await _esperar(3.0)
	var b1 := _suma_barras(p)
	print("[P] dato barras_con_menu=%.3f->%.3f" % [b0, b1])
	_ok(absf(b1 - b0) < 0.01 and int(p._state) == turno0, "con el menu abierto la pelea espera (barras %.3f -> %.3f)" % [b0, b1])
	_cerrar_menu()
	_ok(await _hasta(func(): return Net.pausa_solo == Net.PAUSA_SOLO_MAPA, 5.0), "al cerrarlo, vuelve a parar solo el mapa (%d)" % Net.pausa_solo)
	# Sigue = se mueven las barras, cambia el estado o me llega el turno (y lo juego).
	_ok(await _hasta(func(): return absf(_suma_barras(p) - b1) > 0.01 or int(p._state) != turno0 or pulsar(3), 10.0),
		"y la pelea sigue")

	# x2: lo pide el espejo, lo aplica el trabajador y vuelve en la instantanea.
	Net.peleas.pedir_velocidad(2.0)
	_ok(await _hasta(func(): return is_instance_valid(p) and float(p._vel_pelea) >= 1.5, 10.0), "la pelea va a x2")

	# --- 4) Se acaba: todo en marcha ---
	var t := 0.0
	while is_instance_valid(p) and not p.acabada() and t < 120.0:
		if not huir():
			pulsar(0)
		await _esperar(0.25)
		t += 0.25
	_ok(is_instance_valid(p) and p.acabada(), "la pelea acaba (%.1f s)" % t)
	if is_instance_valid(p) and p.acabada():
		p._on_continue_pressed()
	_ok(await _hasta(func(): return not Game.hay_pelea_en_pantalla(), 10.0), "salgo de la pelea")
	_ok(await _hasta(func(): return Net.pausa_solo == 0, 10.0), "y el mapa vuelve a ir (%d)" % Net.pausa_solo)

