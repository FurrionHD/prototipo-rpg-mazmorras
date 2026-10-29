# LA PELEA A MEDIAS EN EL GUARDADO DEL MUNDO (fase 2, etapa 3, paso 7). La pelea la ejecuta la sala; si se cierra con
# ella en marcha (el ultimo jugador se va a mitad), va al guardado del mundo, y al volver a abrirlo sigue donde estaba
# en cuanto vuelve uno de los suyos a su piso. Mira:
#   1) abro una pelea en el piso 1 y la juego hasta herir a un enemigo;
#   2) me voy a mitad: la sala se cierra sola y la guarda (su registro: "al guardado: 1 pelea(s) a medias");
#   3) vuelvo a abrir el mundo y la sala la trae ("pelea a medias en piso:1");
#   4) vuelvo al piso 1: la sala la rehace y se me abre el espejo solo, con mis personajes;
#   5) los enemigos siguen con la vida que les deje, y los mios no vuelven curados;
#   6) la juego hasta el final y la sala se queda sin peleas ni reservas.
# Un solo jugador, por la sala de una ranura de prueba (80).
#   <godot> --headless --path . res://tools/prueba_town_pelea_guardada.tscn -- nube_local
extends "res://tools/prueba_town_pelea_sala_guion.gd"


func _ready() -> void:
	slot = 80
	puerto = 24618
	if not preparar_mundo(TODO_EL_GRUPO, CASA_A, [], CASA_B) or not await abrir_sala_y_entrar():
		await _fin_solo()
		return

	# 1) Al piso 1 y a pelear, hasta que algun enemigo este herido.
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and _espejos_vivos() > 0, 40.0), "bajo al piso 1 (%d enemigos)" % _espejos_vivos())
	await _esperar(3.0)
	await _abrir_pelea_con_un_enemigo()
	var mia: Node = Net.peleas._pantalla_combate()
	if not _ok_y(Game.hay_pelea_en_pantalla() and is_instance_valid(mia) and Net.peleas.espejando(), "se abre la pelea en espejo"):
		await _fin_solo()
		return
	var t := 0.0
	while is_instance_valid(mia) and t < 90.0 and not mia.acabada() and not _algun_enemigo_herido(mia):
		await _un_turno(mia)
		t += 0.25
	if not _ok_y(is_instance_valid(mia) and not mia.acabada() and _algun_enemigo_herido(mia),
			"hiero a un enemigo sin acabar la pelea (%.1f s)" % t):
		await _fin_solo()
		return
	await _esperar(1.0)   # que lo ultimo que ha pasado en la sala me llegue al espejo
	var vida_e: Array = (mia._enemies as Array).map(func(e): return e.current_hp)
	var vida_a: Dictionary = {}
	for c in mia._aliados:
		vida_a[c.nombre] = c.current_hp
	print("[dev] corto la pelea con enemigos %s y aliados %s" % [str(vida_e), str(vida_a)])

	# 2) Me voy a mitad: la sala se queda sin nadie, se cierra y guarda la pelea.
	var registro_1 := registro_sala
	# Como cerrar el juego: en esta prueba el proceso sigue, asi que el espejo se cierra como cuando se cae la sala (si
	# no, al volver seguiria abierta la pantalla vieja y no podria retomar la pelea).
	Net.peleas._anfitrion_perdido()
	Net.desconectar()
	get_tree().change_scene_to_node(Node.new())
	_ok(await _hasta(func(): return not Game.hay_pelea_en_pantalla(), 5.0), "se cierra mi espejo")
	t = 0.0
	while OS.is_process_running(_pid_sala) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not OS.is_process_running(_pid_sala), "la sala se cierra sola al irme (%.1f s)" % t)
	_ok(_texto(registro_1).contains("[pelea] al guardado: 1 pelea(s) a medias"), "la sala guarda la pelea a medias")

	# 3) Vuelvo a abrir el mundo: la sala trae la pelea en el guardado.
	await _esperar(1.0)
	registro_sala = "user://logs/prueba_ranura_%d_sala_2.log" % slot
	if FileAccess.file_exists(registro_sala):
		DirAccess.remove_absolute(_ruta(registro_sala))
	if not _ok_y(await _volver_a_entrar(), "vuelvo a entrar en el mundo"):
		await _fin_solo()
		return
	_ok(await _hasta(func(): return _lineas_sala("[pelea] pelea a medias en piso:1") > 0, 5.0), "la sala trae la pelea del guardado")

	# 4) Al piso 1 otra vez, a mi sitio (como Mundos.entrar_al_mundo): la sala la rehace y se me abre sola.
	var donde: Dictionary = Net.partida.donde_volver
	Net.partida.donde_volver = {}
	_ok(String(donde.get("lugar", "")) == "piso:1" and donde.get("pos") is Vector2,
		"la sala me devuelve a donde estaba (%s)" % str(donde))
	Game.pos_cargada = donde.get("pos", Vector2.INF)
	Net.pisos.solicitar_volver(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1", 40.0), "vuelvo al piso 1")
	_ok(await _hasta(func(): return Game.hay_pelea_en_pantalla() and Net.peleas.espejando(), 20.0),
		"se me abre sola la pelea que deje a medias")
	_ok(_lineas_sala("[pelea] la sala rehace la pelea guardada en piso:1") > 0, "la rehace la sala")
	_ok(_lineas_sala("ha vuelto (peer") > 0, "y me devuelve a mis personajes")
	mia = Net.peleas._pantalla_combate()
	if not _ok_y(is_instance_valid(mia), "tengo la pantalla de la pelea"):
		await _fin_solo()
		return
	await _esperar(1.0)

	# 5) Como estaba: los enemigos con su vida (mis personajes defienden o esperan, no les pegan), los mios sin curarse.
	var ahora_e: Array = (mia._enemies as Array).map(func(e): return e.current_hp)
	var iguales := ahora_e.size() == vida_e.size()
	for i in mini(ahora_e.size(), vida_e.size()):
		iguales = iguales and absf(float(ahora_e[i]) - float(vida_e[i])) < 0.51
	_ok(iguales, "los enemigos siguen con la vida que les deje (%s / %s)" % [str(ahora_e), str(vida_e)])
	var curados: Array = []
	for c in mia._aliados:
		if vida_a.has(c.nombre) and c.current_hp > float(vida_a[c.nombre]) + 0.51:
			curados.append("%s %.1f > %.1f" % [c.nombre, c.current_hp, float(vida_a[c.nombre])])
	_ok(mia._aliados.size() == vida_a.size() and curados.is_empty(),
		"mis personajes estan todos y no vuelven curados (%d/%d) %s" % [mia._aliados.size(), vida_a.size(), "; ".join(curados)])
	# La frase la pone la sala al rehacerla y me llega con la SIGUIENTE instantanea (o al pedir el registro por el hueco):
	# con el PC cargado, un rato despues de abrirse la pantalla. Se le dan 5 s (29/10: fallo una vez en la bateria).
	var dice_que_sigue := func() -> bool:
		return is_instance_valid(mia) and (mia.get("_log_lines") as Array).any(func(l): return String(l).contains("dejasteis"))
	var t_log := 0.0
	while not dice_que_sigue.call() and t_log < 5.0:
		await _esperar(0.1)
		t_log += 0.1
	_ok(dice_que_sigue.call(), "el registro dice que la pelea sigue (%.1f s)" % t_log)

	# 6) La acabo y la sala se queda limpia.
	t = 0.0
	var plazo: float = 150.0 if bool(mia.get("tactico")) else 90.0
	while is_instance_valid(mia) and t < plazo and not mia.acabada():
		await _un_turno(mia)
		t += 0.25
	_ok(is_instance_valid(mia) and mia.acabada(), "la acabo desde el espejo (%.1f s)" % t)
	if is_instance_valid(mia):
		mia._on_continue_pressed()
	_ok(await hasta_sala("peleas", func(v): return v == "0", 15.0) and dato_sala("reservas") == "0",
		"la sala se queda sin peleas ni reservas (%s, %s)" % [dato_sala("peleas"), dato_sala("reservas")])
	await _fin_solo()


func _algun_enemigo_herido(p: Node) -> bool:
	for e in p._enemies:
		if e.is_alive() and e.current_hp < e.max_hp - 0.5:
			return true
	return false


# Un cuarto de segundo de pelea: si es mi turno, Atacar (o andar hacia el enemigo en tactico).
func _un_turno(p: Node) -> void:
	if int(p.get("_state")) == 1 and not _caja_abierta(p):
		var b: BaseButton = (p.get("_action_buttons") as Dictionary).get(0)
		if b != null and not b.disabled and b.is_visible_in_tree():
			b.pressed.emit()
		elif bool(p.get("tactico")):
			await _andar_hacia_objetivo(p)
	await _esperar(0.25)


# La sala otra vez y yo dentro, como abrir_sala_y_entrar (que ya dejo enganchado el paso al pueblo al entrar).
func _volver_a_entrar() -> bool:
	_entrado = false
	var clave: String = Mundos.clave_de_ranura(slot)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string(CODIGO)
	f.close()
	_pid_sala = _lanzar(["--", "sala", clave, str(puerto), Identidad.id, "nube_local", "sala_vacia=3",
		"sala_espera=30", "sonda"], registro_sala)
	var est: Dictionary = {}
	for i in 400:
		await _esperar(0.1)
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	if not _ok_y(String(est.get("estado", "")) == "lista", "la sala vuelve a estar lista (%s)" % str(est.get("mensaje", ""))):
		return false
	_ok(Net.unirse("127.0.0.1", CODIGO, puerto, true) == OK, "me vuelvo a conectar")
	var t := 0.0
	while not _entrado and t < 60.0:
		await _esperar(0.25)
		t += 0.25
	return _entrado
