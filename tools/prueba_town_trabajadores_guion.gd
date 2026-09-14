extends Node

const PUERTO := 24599
var fallos: Array = []


func _ok(cond: bool, texto: String) -> void:
	print(("[PASA] " if cond else "[FALLA] ") + texto)
	if not cond:
		fallos.append(texto)


func _esperar(seg: float) -> void:
	await get_tree().create_timer(seg).timeout


func _espejos_vivos() -> int:
	var n := 0
	for id in Net.enemigos._enem_nodos:
		if is_instance_valid(Net.enemigos._enem_nodos[id]):
			n += 1
	return n


# Cuantas lineas con 'texto' hay en los registros de los trabajadores de esta pasada. Los registros se
# escriben con retraso (buffer), asi que se relee el fichero entero cada vez.
func _lineas_en_registros(texto: String) -> int:
	var dir := OS.get_user_data_dir().path_join("logs")
	var n := 0
	for f in DirAccess.get_files_at(dir):
		if not f.begins_with("trabajador_"):
			continue
		var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
		if fa == null:
			continue
		n += fa.get_as_text().count(texto)
	return n


func _trabajador_libre() -> int:
	for w in Net._trab._estado:
		if int(Net._trab._estado[w]) == 0:
			return w
	return 0


func _ready() -> void:
	print("[dev] datos de usuario: ", OS.get_user_data_dir())
	# El grupo de la partida de referencia de la huella: con uno recien creado la pelea del paso 5 se
	# perderia a la primera y morir cambia de escena (se lleva la prueba por delante).
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	await _esperar(0.5)
	var err := Net.hostear("abc", PUERTO)
	_ok(err == OK, "sala abierta")

	# 1) El de reserva arranca y se presenta.
	var t := 0.0
	while _trabajador_libre() == 0 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	var w := _trabajador_libre()
	_ok(w != 0, "un trabajador se presenta en %.1f s" % t)
	if w == 0:
		_fin()
		return
	_ok(not Net._avatares.has(w), "el trabajador no tiene avatar en el host")
	_ok(Net._num_humanos == 1, "el trabajador no cuenta como humano (humanos=%d)" % Net._num_humanos)

	# 2) Entro al piso 1: el dueño tiene que ser el trabajador y yo espejo.
	Net.pisos.solicitar_entrar(1)
	await _esperar(10.0)
	_ok(int(Net._dueno_piso.get(1, 0)) == w, "el piso 1 lo simula el trabajador (dueño=%s)" % str(Net._dueno_piso.get(1, 0)))
	_ok(not Net._soy_dueno, "el host entra de espejo")
	var espejos := _espejos_vivos()
	_ok(espejos > 0, "el host ve los enemigos del trabajador (%d espejos)" % espejos)
	print("[dev] nodos en grupo enemy: ", get_tree().get_nodes_in_group("enemy").size())

	# 3) Subo al pueblo: el piso se congela y el trabajador vuelve a la reserva.
	Net.pisos.viajar_al_pueblo()
	await _esperar(4.0)
	var foto: Dictionary = Net._fotos_piso.get(1, {})
	var n_foto := (foto.get("enemigos", []) as Array).size()
	_ok(Net._fotos_piso.has(1) and n_foto > 0, "piso 1 congelado con %d enemigos" % n_foto)
	# Habia otro esperando: este sobra y se cierra (si no, volveria a la reserva).
	_ok(int(Net._trab._estado.get(w, 0)) == 0, "el trabajador suelta el piso (reserva o cerrado)")
	_ok(Net._trab._libres() == Net._trab.RESERVA, "queda exactamente la reserva (%d)" % Net._trab._libres())
	_ok(not Net._dueno_piso.has(1), "el piso 1 ya no tiene dueño")

	# 4) Vuelvo a bajar: lo recoge un trabajador con la foto y veo los mismos enemigos.
	Net.pisos.solicitar_entrar(1)
	await _esperar(10.0)
	var dueno2: int = int(Net._dueno_piso.get(1, 0))
	_ok(Net.es_trabajador(dueno2), "al volver, el piso lo simula un trabajador otra vez")
	var espejos2 := _espejos_vivos()
	_ok(espejos2 == n_foto, "vuelven los mismos enemigos (%d de %d)" % [espejos2, n_foto])

	# 4b) EL ALBOROTO: yo soy espejo, asi que mi ruido tiene que llegarle al trabajador y reventar una
	# pared delante de MI (su cuerpo esta apagado en la entrada).
	var brotes_antes := _lineas_en_registros("[brote] revienta")
	Game.sumar_alboroto(Game.ALBOROTO_MAX + 10.0)
	t = 0.0
	while _lineas_en_registros("[brote] revienta") <= brotes_antes and t < 6.0:
		await _esperar(0.5)
		t += 0.5
	_ok(_lineas_en_registros("[brote] revienta") > brotes_antes,
		"mi ruido de espejo llega al trabajador y revienta una pared (%.1f s)" % t)
	_ok(Game.alboroto == 0.0, "el espejo no acumula alboroto propio (%.0f)" % Game.alboroto)

	# 5) LA PELEA LA EJECUTA UN TRABAJADOR DE PELEA (Parte 3): en el piso espera uno dentro, que no es el
	# dueño. Me planto al lado de un enemigo o le ataco; monta la pelea con mis fichas y yo la veo en ESPEJO.
	t = 0.0
	while Net._trab.pelea_libre_en(1) == 0 and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	var f1: int = Net._trab.pelea_libre_en(1)
	_ok(f1 != 0 and f1 != dueno2, "en el piso 1 espera un trabajador de pelea que no es el dueño (%.1f s)" % t)
	await _esperar(3.0)   # que cargue el piso y reciba los enemigos
	await _abrir_pelea_con_un_enemigo()
	_ok(Game.hay_pelea_en_pantalla(), "se abre la pelea contra un enemigo del trabajador")
	_ok(Net.peleas.espejando() and Net.peleas._pelea_anfitrion == f1,
		"la pelea la ejecuta el de pelea y yo la espejo (anfitrion=%d, de pelea=%d, dueño=%d)" % [
			Net.peleas._pelea_anfitrion, f1, dueno2])
	t = 0.0
	while (Net._trab.pelea_libre_en(1) == 0 or Net._trab.pelea_libre_en(1) == f1) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._trab.pelea_libre_en(1) not in [0, f1], "mientras peleo, entra otro a esperar la siguiente (%.1f s)" % t)
	_ok(not Game.combate_activo(), "en mi PC no se simula ningun enemigo de la pelea")

	# 5b) La juego desde el espejo (Atacar en cada turno mio) hasta que acabe y pulso Continuar: el
	# trabajador tiene que cerrarla SOLO (no tiene quien pulse) y devolverme lo mio.
	var excelia_antes: float = _excelia_grupo()
	t = 0.0
	var mia: Node = Net.peleas._pantalla_combate()
	while is_instance_valid(mia) and t < 90.0 and not (mia.acabada() if mia.has_method("acabada") else true):
		if int(mia.get("_state")) == 1 and not _caja_abierta(mia):
			var b: BaseButton = (mia.get("_action_buttons") as Dictionary).get(0)
			if b != null and not b.disabled and b.is_visible_in_tree():
				b.pressed.emit()
		await _esperar(0.25)
		t += 0.25
	_ok(is_instance_valid(mia) and mia.acabada(), "la pelea del trabajador termina jugandola desde el espejo (%.1f s)" % t)
	var cerradas_antes := _lineas_en_registros("[pelea] cierro la pelea acabada")
	if is_instance_valid(mia):
		mia._on_continue_pressed()
	t = 0.0
	while (_lineas_en_registros("[pelea] cierro la pelea acabada") <= cerradas_antes or Net.peleas._desgaste_pendiente) and t < 10.0:
		await _esperar(0.5)
		t += 0.5
	_ok(_lineas_en_registros("[pelea] cierro la pelea acabada") > cerradas_antes, "el trabajador cierra solo la pelea al salir yo (%.1f s)" % t)
	_ok(not Game.hay_pelea_en_pantalla() and not Net.peleas.espejando() and not Net.peleas._desgaste_pendiente,
		"vuelvo al mapa con lo mio de vuelta")
	_ok(_excelia_grupo() > excelia_antes, "la excelia de la pelea llega a mis personajes (%.2f -> %.2f)" % [excelia_antes, _excelia_grupo()])

	_ok(not Net._trab._de_pelea.has(f1) or Net._trab.pelea_libre_en(1) != 0,
		"al acabar, el que peleo deja sitio al que ya esperaba")

	# 5c) Otra pelea, para el paso 6: la lleva el que estaba esperando.
	await _esperar(3.0)
	await _abrir_pelea_con_un_enemigo()
	_ok(Net.peleas.espejando() and Net._trab._de_pelea.has(Net.peleas._pelea_anfitrion),
		"la segunda pelea la ejecuta otro trabajador de pelea")

	# 6) SE CAE EL TRABAJADOR (F4) MIENTRAS PELEO contra sus bichos: se matan sus procesos a lo bruto. El
	# piso lo hereda el humano de dentro con la foto de sus espejos, la pelea SE DESHACE (la llevaba el,
	# decidido asi) y la reserva vuelve a llenarse.
	var espejos_antes := _espejos_vivos()
	var muertos: Array = Net._trab._estado.keys()   # los que voy a matar: la reserva tiene que ser OTRO
	for pid in Net._trab._pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	t = 0.0
	while not Net._soy_dueno and t < 15.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._soy_dueno, "al caerse el trabajador, el piso lo hereda el humano de dentro (%.1f s)" % t)
	await _esperar(1.0)
	var reales := get_tree().get_nodes_in_group("enemy").filter(
		func(e): return is_instance_valid(e) and not e.has_meta("es_espejo")).size()
	_ok(reales > 0 and absi(reales - espejos_antes) <= 6,
		"hereda los enemigos que veia (%d reales, veia %d)" % [reales, espejos_antes])
	# Que se deshace = ya no espejo nada. Puede haber pantalla igual: al heredar el piso, el enemigo que tengo
	# al lado es MIO y me embiste, y esa pelea nueva ya va en mi PC (no hay trabajador). El de pelea es OTRO
	# proceso: su caida se detecta por su cuenta (hasta 5 s de ENet), no a la vez que la del dueño.
	t = 0.0
	while Net.peleas.espejando() and t < 8.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not Net.peleas.espejando(), "la pelea del trabajador caido se deshace (ahora %s)" % [
		"peleo en mi PC" if Game.combate_activo() else "sin pelea"])
	t = 0.0
	while (_trabajador_libre() == 0 or muertos.has(_trabajador_libre())) and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(_trabajador_libre() != 0 and not muertos.has(_trabajador_libre()),
		"la reserva se repone con un trabajador NUEVO tras la caida (%.1f s)" % t)

	_fin()


# Me planto al lado del primer enemigo vivo; si no me embiste solo, le ataco. Espera a tener pantalla.
func _abrir_pelea_con_un_enemigo() -> void:
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var presa = null
	for id in Net.enemigos._enem_nodos:
		var n = Net.enemigos._enem_nodos[id]
		if is_instance_valid(n) and not n.esta_muerto() and int(n.get("pelea_de")) == 0:
			presa = n
			break
	if jugador == null or presa == null:
		print("[dev] no hay jugador o enemigo libre para pelear")
		return
	jugador.recolocar((presa as Node2D).global_position + Vector2(40, 0))
	var t := 0.0
	while not Game.hay_pelea_en_pantalla() and t < 6.0:
		await _esperar(0.25)
		t += 0.25
	# Que me vea depende de su cono y de que yo haga ruido: esto se apunta, no se exige.
	print("[dev] ¿me ha visto y embestido solo?: ", Game.hay_pelea_en_pantalla(), " (%.1f s)" % t)
	if not Game.hay_pelea_en_pantalla() and is_instance_valid(presa):
		presa.atacado_por_jugador(0.3)
		t = 0.0
		while not Game.hay_pelea_en_pantalla() and t < 6.0:
			await _esperar(0.25)
			t += 0.25


func _caja_abierta(p: Node) -> bool:
	for caja in ["_cast_box", "_ability_box", "_objeto_box", "_spell_box"]:
		var c: Control = p.get(caja)
		if c != null and c.visible:
			return true
	return false


func _excelia_grupo() -> float:
	var s := 0.0
	for pj in [Game.lider()] + Game.companeros():
		for k in (pj.ability_internal as Dictionary):
			s += float(pj.ability_internal[k])
	return s


func _fin() -> void:
	var pids: Array = Net._trab._pids.duplicate()
	Net.desconectar()
	await _esperar(3.0)
	var vivos := pids.filter(func(p): return OS.is_process_running(p))
	_ok(vivos.is_empty(), "los trabajadores se cierran con la sala (%d vivos)" % vivos.size())
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit()
