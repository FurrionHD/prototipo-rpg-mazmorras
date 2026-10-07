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


# La ultima linea de los registros de los trabajadores que empieza por 'prefijo' ("" si no hay).
func _linea_de_registros(prefijo: String) -> String:
	var dir := OS.get_user_data_dir().path_join("logs")
	var ultima := ""
	for f in DirAccess.get_files_at(dir):
		if not f.begins_with("trabajador_"):
			continue
		var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
		if fa == null:
			continue
		for l in fa.get_as_text().split("\n"):
			if l.begins_with(prefijo):
				ultima = l.strip_edges()
	return ultima


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
	# Entre RESERVA y RESERVA_MAX: desde el 19/09 el que queda libre se CONSERVA hasta RESERVA_MAX para
	# reaprovecharlo en la pelea siguiente (ver trabajadores.gd). Antes esto pedia exactamente RESERVA.
	_ok(Net._trab._libres() >= Net._trab.RESERVA and Net._trab._libres() <= Net._trab.RESERVA_MAX,
		"quedan libres entre la reserva y su tope (%d)" % Net._trab._libres())
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
	# PRUEBA_CABOS=1 -> solo los dos cabos sueltos del 07/10 (ver _cabos_sueltos) y se acaba: sin esperar a que
	# termine ninguna pelea (en las pruebas el grupo solo sabe ir recto y se atasca en fila: no acaban).
	if OS.get_environment("PRUEBA_CABOS") != "":
		await _cabos_sueltos()
		_fin()
		return

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
	# EN LA MAZMORRA LA PELEA ES TACTICA (03/10): la arena la calcula el trabajador y me llega con su forma.
	var pt: Node = Net.peleas._pantalla_combate()
	_ok(pt != null and bool(pt.get("tactico")) and Game.pelea_tactica_en_curso(),
		"la pelea del trabajador en la mazmorra es TACTICA y veo su arena")
	var ar = Game.get("_arena_nodo")
	if is_instance_valid(ar):
		print("[dev] arena en mi mapa: %s, forma %s, %d tramos de borde" % [str(ar.rect_celdas),
			"relleno" if not (ar.mascara as PackedByteArray).is_empty() else "rectangulo", ar.tramos.size()])
	_ok(Net.peleas.espejando() and Net.peleas._pelea_anfitrion == f1,
		"la pelea la ejecuta el de pelea y yo la espejo (anfitrion=%d, de pelea=%d, dueño=%d)" % [
			Net.peleas._pelea_anfitrion, f1, dueno2])
	t = 0.0
	while (Net._trab.pelea_libre_en(1) == 0 or Net._trab.pelea_libre_en(1) == f1) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._trab.pelea_libre_en(1) not in [0, f1], "mientras peleo, entra otro a esperar la siguiente (%.1f s)" % t)
	_ok(not Game.combate_activo(), "en mi PC no se simula ningun enemigo de la pelea")
	# LOS DOBLES PELEAN CON MIS NUMEROS: el trabajador apunta los de cada doble al montar la pelea
	# (Game.abrir_pelea_de_fichas); aqui se comparan con los que tendria el personaje en solitario.
	await _esperar(1.5)   # los registros se escriben con retraso
	var comparados := 0
	var distintos: Array = []
	for pj in [Game.lider()] + Game.companeros():
		var linea := _linea_de_registros("[pelea] doble %s " % pj.uid)
		if linea == "":
			continue
		comparados += 1
		var c: Combatant = Game.crear_player_combatant(pj)
		var mio := "def=%.3f red=%.4f spd=%.3f cast=%.3f amp=%.3f hpmax=%.2f" % [
			c.def_value(), c.armor_reduction, c.spd(), c.cast_spd(), c.magic_amp, c.max_hp]
		if not linea.ends_with(mio):
			distintos.append("%s: trabajador '%s' / mi PC '%s'" % [pj.nombre, linea.get_slice(" ", 3), mio])
	_ok(comparados > 0 and distintos.is_empty(),
		"los dobles del trabajador pelean con mis mismos numeros (%d comparados) %s" % [comparados, "; ".join(distintos)])
	# Y LOS ENEMIGOS con los mismos que les saldrian en mi PC (misma tirada, mutacion, jefe y piso).
	var enem_comp := 0
	var enem_dist: Array = []
	for nid in Net.enemigos._enem_nodos:
		var ne = Net.enemigos._enem_nodos[nid]
		if not is_instance_valid(ne) or ne.data == null:
			continue
		var linea_e := _linea_de_registros("[pelea] enemigo %d " % int(nid))
		if linea_e == "":
			continue
		enem_comp += 1
		var ce: Combatant = ne.data.crear_combatant(ne.current_t, bool(ne.mutante), bool(ne.es_boss))
		var mio_e := "atk=%.3f def=%.3f spd=%.3f hpmax=%.2f piso=%d" % [ce.atk(), ce.def_value(), ce.spd(), ce.max_hp, Game.current_floor]
		if not linea_e.ends_with(mio_e):
			enem_dist.append("%d: trabajador '%s' / mi PC '%s'" % [int(nid), linea_e.substr(linea_e.find("atk=")), mio_e])
	_ok(enem_comp > 0 and enem_dist.is_empty(),
		"los enemigos del trabajador tienen los mismos numeros que en mi PC (%d comparados) %s" % [enem_comp, "; ".join(enem_dist)])

	# 5b) La juego desde el espejo (Atacar en cada turno mio) hasta que acabe y pulso Continuar: el
	# trabajador tiene que cerrarla SOLO (no tiene quien pulse) y devolverme lo mio.
	var excelia_antes: float = _excelia_grupo()
	var stats_antes: Dictionary = (Game.lider().ability_internal as Dictionary).duplicate()
	var dur_antes: float = Game.durabilidad_slot("main", Game.lider())
	t = 0.0
	var mia: Node = Net.peleas._pantalla_combate()
	# En tactico la pelea es mas larga (se anda, y la arena del pasillo mete a los de lejos): mas plazo.
	var plazo: float = 150.0 if is_instance_valid(mia) and bool(mia.get("tactico")) else 90.0
	while is_instance_valid(mia) and t < plazo and not (mia.acabada() if mia.has_method("acabada") else true):
		if int(mia.get("_state")) == 1 and not _caja_abierta(mia):
			var b: BaseButton = (mia.get("_action_buttons") as Dictionary).get(0)
			if b != null and not b.disabled and b.is_visible_in_tree():
				b.pressed.emit()
			elif bool(mia.get("tactico")):
				# EN TACTICO, fuera de alcance: ando hacia el enemigo un rato y vuelvo a mirar.
				await _andar_hacia_objetivo(mia)
		if fmod(t, 5.0) < 0.26:
			_traza_tactico(mia, t)
		await _esperar(0.25)
		t += 0.25
	_ok(is_instance_valid(mia) and mia.acabada(), "la pelea del trabajador termina jugandola desde el espejo (%.1f s)" % t)
	if is_instance_valid(mia) and not mia.acabada():
		var tz: Array = mia.get("_traza")
		for l in tz.slice(maxi(0, tz.size() - 80)):
			print("[traza-espejo] ", l)
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
	# Y STAT A STAT del lider: pegando sube la Fuerza (o la Destreza, si su arma escala con ella).
	var stats_despues: Dictionary = Game.lider().ability_internal
	var cambio: Array = []
	for k in stats_despues:
		cambio.append("%s %.3f->%.3f" % [k, float(stats_antes.get(k, 0.0)), float(stats_despues[k])])
	print("[dev] stats del lider tras la pelea tactica: ", ", ".join(cambio))
	_ok(float(stats_despues.get("fuerza", 0.0)) > float(stats_antes.get("fuerza", 0.0))
		or float(stats_despues.get("destreza", 0.0)) > float(stats_antes.get("destreza", 0.0)),
		"el lider gana Fuerza/Destreza pegando en la pelea tactica del trabajador")
	var dur_despues: float = Game.durabilidad_slot("main", Game.lider())
	_ok(Game.lider().equipped_main == null or dur_despues < dur_antes,
		"el arma del lider se gasta en la pelea del trabajador (%.4f -> %.4f)" % [dur_antes, dur_despues])

	_ok(not Net._trab._de_pelea.has(f1) or Net._trab.pelea_libre_en(1) != 0,
		"al acabar, el que peleo deja sitio al que ya esperaba")

	# 5c) Otra pelea, para el paso 6: la lleva el que estaba esperando.
	await _esperar(3.0)
	await _abrir_pelea_con_un_enemigo()
	_ok(Net.peleas.espejando() and Net._trab._de_pelea.has(Net.peleas._pelea_anfitrion),
		"la segunda pelea la ejecuta otro trabajador de pelea")

	# 6a) SE CAE SOLO EL DUEÑO DEL PISO mientras otro trabajador lleva mi pelea. El piso lo hereda el humano de
	# dentro con la foto de sus espejos, MENOS los enemigos que estan en esa pelea (si no, saldrian duplicados:
	# uno suelto y otro peleando). La pelea sigue en el de pelea y se termina.
	var f_pelea: int = Net.peleas._pelea_anfitrion
	var dueno_vivo: int = int(Net._dueno_piso.get(1, 0))
	var espejos_antes := _espejos_vivos()
	var en_pelea := 0
	for id in Net.enemigos._enem_nodos:
		var n = Net.enemigos._enem_nodos[id]
		if is_instance_valid(n) and int(n.get("pelea_de")) == f_pelea:
			en_pelea += 1
	var pid_dueno: int = int(Net._trab._pid_de.get(dueno_vivo, 0))
	_ok(pid_dueno > 0 and en_pelea > 0, "tengo el proceso del dueño (%d) y %d enemigo(s) en la pelea" % [pid_dueno, en_pelea])
	if pid_dueno > 0:
		OS.kill(pid_dueno)
	t = 0.0
	while not Net._soy_dueno and t < 15.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._soy_dueno, "al caerse el dueño, el piso lo hereda el humano de dentro (%.1f s)" % t)
	await _esperar(1.0)
	var reales := get_tree().get_nodes_in_group("enemy").filter(
		func(e): return is_instance_valid(e) and not e.has_meta("es_espejo")).size()
	_ok(reales > 0 and reales <= espejos_antes - en_pelea,
		"hereda los enemigos que veia SIN los de la pelea (%d reales, veia %d, %d en la pelea)" % [reales, espejos_antes, en_pelea])
	_ok(Net.peleas.espejando() and Net.peleas._pelea_anfitrion == f_pelea, "mi pelea SIGUE en el trabajador de pelea")
	var mia2: Node = Net.peleas._pantalla_combate()
	t = 0.0
	while is_instance_valid(mia2) and not mia2.acabada() and t < 60.0:
		if int(mia2.get("_state")) == 1 and not _caja_abierta(mia2):
			var b2: BaseButton = (mia2.get("_action_buttons") as Dictionary).get(0)
			if b2 != null and not b2.disabled and b2.is_visible_in_tree():
				b2.pressed.emit()
		await _esperar(0.25)
		t += 0.25
	_ok(is_instance_valid(mia2) and mia2.acabada(), "y se termina (%.1f s)" % t)
	if is_instance_valid(mia2):
		mia2._on_continue_pressed()
	t = 0.0
	while (Game.hay_pelea_en_pantalla() or Net.peleas._desgaste_pendiente) and t < 10.0:
		await _esperar(0.25)
		t += 0.25
	_ok(not Game.hay_pelea_en_pantalla(), "vuelvo al mapa del piso heredado")

	# 6b) SE CAE TODO (F4) EN PLENA PELEA: se matan todos los procesos a lo bruto. La pelea SE DESHACE (la
	# llevaba un trabajador, decidido asi) y la reserva vuelve a llenarse.
	t = 0.0
	while Net._trab.pelea_libre_en(1) == 0 and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	await _esperar(3.0)
	await _abrir_pelea_con_un_enemigo()
	_ok(Net.peleas.espejando(), "con el piso en mi PC, la pelea sigue yendo a un trabajador de pelea")
	var muertos: Array = Net._trab._estado.keys()   # los que voy a matar: la reserva tiene que ser OTRO
	for pid in Net._trab._pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	# Que se deshace = ya no espejo nada. Puede haber pantalla igual: el enemigo que tengo al lado es MIO y me
	# embiste, y esa pelea nueva ya va en mi PC (no hay trabajador).
	t = 0.0
	while Net.peleas.espejando() and t < 10.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not Net.peleas.espejando(), "la pelea del trabajador caido se deshace (ahora %s)" % [
		"peleo en mi PC" if Game.combate_activo() else "sin pelea"])
	t = 0.0
	while (_trabajador_libre() == 0 or muertos.has(_trabajador_libre())) and t < 45.0:
		await _esperar(0.5)
		t += 0.5
	_ok(_trabajador_libre() != 0 and not muertos.has(_trabajador_libre()),
		"la reserva se repone con un trabajador NUEVO tras la caida (%.1f s)" % t)

	_fin()


# LOS DOS CABOS SUELTOS DE LOS TRABAJADORES DE PELEA (07/10; apuntados el 21/09):
#  1) el RUIDO de la pelea que ejecuta un trabajador va a nombre del humano que la abrio (el trabajador no tiene
#     cuerpo, y el brote salia delante de cualquiera). Abro una pelea, salgo de ella y el trabajador, sin nadie
#     dentro, la cierra: su registro tiene que decir que el ruido es mio (soy el 1).
#  2) el trabajador de pelea SE CAE CON MIS FICHAS EN LA MANO: lo mato y ataco enseguida. El host tarda ~5 s en
#     darlo por caido, asi que le manda mis fichas a un proceso muerto que nunca contesta. Antes los enemigos se
#     quedaban reservados a mi nombre y congelados; ahora la pelea me vuelve y va en mi PC.
func _cabos_sueltos() -> void:
	var t := 0.0
	while Net._trab.pelea_libre_en(1) == 0 and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	await _esperar(3.0)
	var f1: int = Net._trab.pelea_libre_en(1)
	await _abrir_pelea_con_un_enemigo()
	_ok(Net.peleas.espejando() and Net.peleas._pelea_anfitrion == f1, "cabo 1: la pelea la ejecuta el trabajador %d" % f1)
	await _esperar(2.0)
	var ruido_antes := _lineas_en_registros("[alboroto] la pelea que ejecuto es de 1:")
	Game._on_combate_espejo_cerrado()   # salgo de su pelea, como al cerrarla
	t = 0.0
	while _lineas_en_registros("[alboroto] la pelea que ejecuto es de 1:") <= ruido_antes and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(_lineas_en_registros("[alboroto] la pelea que ejecuto es de 1:") > ruido_antes,
		"cabo 1: al cerrarse, el ruido de la pelea del trabajador va a MI nombre (%.1f s)" % t)
	t = 0.0
	while Net.peleas.ocupado_en_pelea() and t < 15.0:
		await _esperar(0.5)
		t += 0.5

	t = 0.0
	while (Net._trab.pelea_libre_en(1) == 0 or Net._trab.pelea_libre_en(1) == f1) and t < 30.0:
		await _esperar(0.5)
		t += 0.5
	await _esperar(3.0)
	var f_cae: int = Net._trab.pelea_libre_en(1)
	var pid_cae: int = int(Net._trab._pid_de.get(f_cae, 0))
	_ok(f_cae != 0 and pid_cae > 0, "cabo 2: tengo el trabajador de pelea que voy a tirar (%d, pid %d)" % [f_cae, pid_cae])
	if pid_cae > 0:
		OS.kill(pid_cae)
	await _abrir_pelea_con_un_enemigo()
	t = 0.0
	while not Game.combate_activo() and t < 15.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Game.combate_activo() and not Net.peleas.espejando() and Net.peleas._fichas_mandadas_a == 0,
		"cabo 2: al caerse el trabajador con mis fichas, la pelea me vuelve y va en mi PC (%.1f s)" % t)


# Me planto al lado del primer enemigo vivo; si no me embiste solo, le ataco. Espera a tener pantalla.
func _abrir_pelea_con_un_enemigo() -> void:
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var presa = null
	# Espejos si el piso lo simula otro; los de VERDAD si lo he heredado yo (paso 6).
	var ids: Array = Net.enemigos._enemigos.keys() if Net._soy_dueno else Net.enemigos._enem_nodos.keys()
	# Mejor uno que este en una SALA: en un pasillo de 3 celdas con el grupo en fila solo pelea el de delante y
	# la pelea tactica se alarga mucho (eso se juega, pero aqui solo se quiere que acabe y devuelva lo mio).
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	var gen: DungeonGenerator = piso.get("gen") if piso != null else null
	for id in ids:
		var n = Net.peleas.nodo_de_id(int(id))
		if is_instance_valid(n) and not n.esta_muerto() and Net.peleas.pelea_de_enemigo(n) == 0:
			if presa == null:
				presa = n
			if gen != null:
				var z: int = gen.zona_en(ArenaCalculo.celda_de_px((n as Node2D).global_position))
				if z >= 0 and String(gen.zonas[z]["tipo"]) == "sala":
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


# EN TACTICO, mi turno con el enemigo fuera de alcance: ando hacia el con las teclas, como un jugador.
func _andar_hacia_objetivo(p: Node) -> void:
	var tm = p.get("turno_mapa")
	if tm == null or tm._fase != tm.Fase.MOVIENDO or not is_instance_valid(tm._cuerpo):
		return
	var antes: Vector2 = tm._cuerpo.global_position
	# Hacia el enemigo vivo mas cercano (el objetivo marcado puede ser uno que ya murio).
	var mejor: Node2D = null
	for e in p._enemies:
		var ce: Node2D = tm.cuerpo_de(e) if e.is_alive() else null
		if ce != null and (mejor == null or ce.global_position.distance_to(antes) < mejor.global_position.distance_to(antes)):
			mejor = ce
	# Como haria un jugador que rodea a los suyos: un hueco libre JUNTO al enemigo, dentro de mi circulo.
	if mejor != null:
		for r in [22.0, 30.0, 40.0]:
			var hecho: bool = false
			for k in 12:
				var q: Vector2 = mejor.global_position + Vector2.RIGHT.rotated(TAU * float(k) / 12.0) * r
				if q.distance_to(tm._inicio) <= tm._radio and tm._puede_estar(q, tm._cuerpo) and tm._en_arena(q):
					tm._colocar(tm._quien, tm._cuerpo, q)
					hecho = true
					break
			if hecho:
				break
		await _esperar(0.2)
		var at: BaseButton = (p.get("_action_buttons") as Dictionary).get(0)
		if at != null and not at.disabled:
			return
	if mejor != null:
		var d: Vector2 = mejor.global_position - antes
		var teclas: Array = []
		if absf(d.x) > 6.0:
			teclas.append("move_right" if d.x > 0.0 else "move_left")
		if absf(d.y) > 6.0:
			teclas.append("move_down" if d.y > 0.0 else "move_up")
		for k in teclas:
			Input.action_press(k)
		await _esperar(0.35)
		for k in teclas:
			Input.action_release(k)
	if tm._fase != tm.Fase.MOVIENDO or not is_instance_valid(tm._cuerpo):
		return
	# Si ya no avanzo (el circulo, la pared o un compañero delante) y sigo sin llegar: Defender, para que
	# el turno pase. Un jugador rodearia; esto solo va en linea recta.
	var b: BaseButton = (p.get("_action_buttons") as Dictionary).get(0)
	var acerca: float = 0.0 if mejor == null else 		antes.distance_to(mejor.global_position) - tm._cuerpo.global_position.distance_to(mejor.global_position)
	if b != null and b.disabled and acerca < 2.0:
		var defender: BaseButton = (p.get("_action_buttons") as Dictionary).get(3)
		var pasar: BaseButton = (p.get("_action_buttons") as Dictionary).get(5)
		if defender != null and not defender.disabled:
			defender.pressed.emit()
		elif pasar != null and not pasar.disabled and pasar.text == "Pasar":
			pasar.pressed.emit()   # sin energia para Defender: Pasar (en el mapa siempre esta, salvo en el borde)
		else:
			print("[dev] no puedo ni Defender ni Pasar")


func _traza_tactico(p: Node, t: float) -> void:
	var tm = p.get("turno_mapa")
	var b: BaseButton = (p.get("_action_buttons") as Dictionary).get(0)
	var linea := "[dev] t=%.0f state=%d" % [t, int(p.get("_state"))]
	if tm != null:
		linea += " fase=%d quien=%s" % [int(tm._fase), tm._quien.nombre if tm._quien != null else "-"]
		if is_instance_valid(tm._cuerpo):
			linea += " cuerpo=%s inicio=%s radio=%.0f" % [str(tm._cuerpo.global_position.round()), str(tm._inicio.round()), tm._radio]
	if tm != null and is_instance_valid(tm._cuerpo):
		var c0: Vector2 = tm._cuerpo.global_position
		var obj = p._objetivo()
		linea += " obj=%s" % (obj.nombre if obj != null else "-")
		for dd in [Vector2(0, -8), Vector2(-8, 0), Vector2(8, 0), Vector2(0, 8)]:
			var q: Vector2 = c0 + dd
			linea += " [%s suelo=%s arena=%s puede=%s]" % [str(dd), tm._sobre_suelo(q, tm._cuerpo), tm._en_arena(q), tm._puede_estar(q, tm._cuerpo)]
		linea += " arena_aqui=%s" % tm._en_arena(c0)
	linea += " atacar=%s" % ("-" if b == null else ("apagado" if b.disabled else "ok") + ("" if b.is_visible_in_tree() else " oculto"))
	for al in p._aliados:
		var ca: Node2D = tm.cuerpo_de(al) if tm != null else null
		linea += " | %s en %s" % [al.nombre.left(4), str(ca.global_position.round()) if ca != null else "?"]
	for e in p._enemies:
		var ce: Node2D = tm.cuerpo_de(e) if tm != null else null
		linea += " | %s hp=%.0f en %s" % [e.nombre, e.current_hp, str(ce.global_position.round()) if ce != null else "?"]
	print(linea)


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
