# Guion del jugador de prueba_solo_por_sala (fase 2, 20/10, todo por la sala, paso 3): UNO SOLO, por la sala de su
# ranura, juega como el solo de siempre. Apunta lo que ve con "[P] ..." y la prueba lo lee de su registro.
#   1) En la arena, con dos slimes lejos: andan; abro un menu y se paran (y mi juego se pausa); lo cierro y siguen.
#   2) Peleo con uno: el mapa se para (el otro slime no se mueve); la pelea sigue.
#   3) En la pelea abro un menu: la pelea espera (las barras no se mueven); lo cierro y sigue. Y va a x2.
#   4) Acabo la pelea: todo en marcha otra vez.
#   5) (etapa 4) Al pueblo y al piso 1 DE VERDAD (lo de la arena no se guarda): gano una pelea, que la monta la sala, y
#      apunto lo ganado (la excelia de mi lider) para que la prueba lo busque en la ranura cuando la sala se cierre.
# Con "vuelta <uid> <excelia>" detras de los argumentos es la SEGUNDA entrada: por el camino del menu
# (Mundos.entrar_al_mundo) la sala me devuelve al piso 1, con mi lider como lo deje.
# Lo que se mueve en el mapa se mira por lo que MANDA la sala (_objetivo del enemigo remoto), no por donde lo
# pinto: con mi juego en pausa mis dibujos no se mueven aunque la sala si.
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
	var v := args.find("vuelta")
	Net.partida.entrada_lista.connect(func():
		if v >= 0:
			await Mundos.entrar_al_mundo()   # el del menu: al pueblo, y si estaba abajo, de vuelta a mi piso
			_entrado = true
			return
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
	if v >= 0:
		await _vuelta(args[v + 1], float(args[v + 2]))
	else:
		await _guion()
	# SALGO COMO EL JUEGO (menu de pausa o la X de la ventana): le pido a la sala que guarde lo mio y espero a que lo diga.
	# Con un desconectar() a pelo la sala solo tenia lo de su ultimo autoguardado (cada 60 s).
	_ok(await Ventana.pedir_guardado_al_anfitrion(), "al salir, la sala guarda lo mio")
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


# Donde dice la sala que esta cada enemigo vivo (id -> Vector2).
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


func _excelia(pj) -> float:
	var s := 0.0
	for k in (pj.ability_internal as Dictionary):
		s += float(pj.ability_internal[k])
	return s


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

	# x2: lo pide el espejo, lo aplica la sala y vuelve en la instantanea.
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

	# --- 5) En la mazmorra de verdad: lo que gano peleando se queda en mi ranura ---
	Net.pisos.viajar_al_pueblo()
	_ok(await _hasta(func(): return Net._mi_lugar == "pueblo", 30.0), "salgo de la arena al pueblo")
	await _esperar(2.0)
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1", 40.0), "bajo al piso 1")
	_ok(await _hasta(func(): return enemigo_libre() != null, 20.0), "hay enemigos en el piso")
	# La excelia la gana QUIEN ACTUA (26/10: a veces los golpes los da un compañero y el lider no gana nada): se mira el
	# grupo entero, y para la ranura se apunta al que mas ha ganado.
	var grupo: Array = [Game.lider()] + Game.companeros()
	var antes: Dictionary = {}
	for pj in grupo:
		antes[pj.uid] = _excelia(pj)
	var antes_grupo := excelia_grupo()
	await pelear_con(enemigo_libre())
	_ok(Game.hay_pelea_en_pantalla(), "peleo en el piso 1 (la pelea la monta la sala)")
	_ok(await pelear_hasta_el_final(90.0), "y la gano")
	_ok(excelia_grupo() > antes_grupo, "peleando gana excelia el grupo (%.4f -> %.4f)" % [antes_grupo, excelia_grupo()])
	_ok(Net._mi_lugar == "piso:1", "y sigo en el piso 1 (%s)" % Net._mi_lugar)
	var mejor = grupo[0]
	for pj in grupo:
		if _excelia(pj) - float(antes[pj.uid]) > _excelia(mejor) - float(antes[mejor.uid]):
			mejor = pj
	print("[P] dato lider=%s excelia=%.4f" % [mejor.uid, _excelia(mejor)])


# LA VUELTA: entro otra vez (sala nueva, la de antes se cerro) y estoy donde lo deje, con lo ganado.
func _vuelta(uid: String, excelia: float) -> void:
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1", 60.0), "la sala me devuelve al piso 1 (%s)" % Net._mi_lugar)
	var suyo = null   # el del grupo que mas gano en la pelea (ver el final de _guion)
	for pj in [Game.lider()] + Game.companeros():
		if pj != null and pj.uid == uid:
			suyo = pj
	_ok(suyo != null, "con el mismo grupo (esta %s)" % uid)
	if suyo != null:
		_ok(absf(_excelia(suyo) - excelia) < 0.01, "y con la excelia que gane (%.4f, esperaba %.4f)" % [
			_excelia(suyo), excelia])
