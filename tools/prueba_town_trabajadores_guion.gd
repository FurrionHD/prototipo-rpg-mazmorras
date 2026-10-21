# PRUEBA DE LOS TRABAJADORES DE PELEA, POR LA SALA (rehecha el 21/10, fase 2 etapa 2). Desde la etapa 2 los PISOS los
# lleva la sala (ver prueba_sala_pisos y prueba_town_dos_pisos); lo que queda de los trabajadores son los de PELEA: uno
# espera dentro de cada piso con gente y ejecuta la siguiente pelea, y el jugador la ve en espejo. Esto mira que la
# pelea vaya a un trabajador, que los dobles y los enemigos peleen con los mismos numeros que en mi PC, que la pelea
# acabe y me devuelva lo mio (excelia, stats, desgaste), que la siguiente la lleve otro, y las caidas (todos a la vez;
# y, con PRUEBA_CABOS=1, el ruido de su pelea a mi nombre y la caida del trabajador con mis fichas en la mano).
# El jugador entra como un cliente mas de la sala de una ranura de prueba (83); lo de dentro, de las lineas "[S] dato".
#   <godot> --headless --path . res://tools/prueba_town_trabajadores.tscn -- nube_local
extends "res://tools/prueba_town_sala_comun.gd"

const TODO_EL_GRUPO := ["Agirato ochinan", "Catalardio", "Dasui", "Daniel"]


func _espejos_vivos() -> int:
	var n := 0
	for id in Net.enemigos._enem_nodos:
		if is_instance_valid(Net.enemigos._enem_nodos[id]):
			n += 1
	return n


# Lo que dice la sala de sus trabajadores.
func _pelea_libre() -> int:
	return int(dato_sala("pelea_libre_1"))


func _de_pelea() -> Array:
	return Array(dato_sala("de_pelea").split(",", false)).map(func(x): return int(x))


func _trabajadores() -> Array:
	return Array(dato_sala("trabajadores").split(",", false)).map(func(x): return int(x))


func _pid_de(w: int) -> int:
	for par in dato_sala("pid_de").split(",", false):
		var kv: PackedStringArray = par.split(":")
		if kv.size() == 2 and int(kv[0]) == w:
			return int(kv[1])
	return 0


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


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


# DESDE UN PUNTO: lo que llevan escrito ahora los registros de los trabajadores (fichero -> largo). Con _linea_desde se
# busca solo en lo escrito despues: un trabajador lleva varias peleas en su registro (y los numeros de un personaje
# cambian de una a otra: la armadura se gasta), y comparar con la de otra pelea fallaba "a veces" (21/10).
func _marca_registros() -> Dictionary:
	var dir := OS.get_user_data_dir().path_join("logs")
	var m := {}
	for f in DirAccess.get_files_at(dir):
		if f.begins_with("trabajador_"):
			var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
			if fa != null:
				m[f] = fa.get_as_text().length()
	return m


func _linea_desde(prefijo: String, marca: Dictionary) -> String:
	var dir := OS.get_user_data_dir().path_join("logs")
	var ultima := ""
	for f in DirAccess.get_files_at(dir):
		if not f.begins_with("trabajador_"):
			continue
		var fa := FileAccess.open(dir.path_join(f), FileAccess.READ)
		if fa == null:
			continue
		var texto: String = fa.get_as_text()
		# Si el fichero es mas corto que la marca, es OTRO trabajador con el mismo numero (relanzado): entero.
		var desde: int = int(marca.get(f, 0))
		if desde > texto.length():
			desde = 0
		for l in texto.substr(desde).split("\n"):
			if l.begins_with(prefijo):
				ultima = l.strip_edges()
	return ultima


func _ready() -> void:
	slot = 83
	puerto = 24615
	# Con el grupo entero de la partida de referencia (4): con dos la pelea tactica se alarga y el guion no sabe andar.
	if not preparar_mundo(TODO_EL_GRUPO, CASA_A, [], CASA_B) or not await abrir_sala_y_entrar():
		await _fin_solo()
		return

	# 1) Los de reserva arrancan y se presentan (no son humanos ni tienen cuerpo).
	_ok(await hasta_sala("trabajadores", func(v): return v != "", 40.0), "los trabajadores de la sala se presentan (%s)" % dato_sala("trabajadores"))
	_ok(Net._num_humanos == 1, "los trabajadores no cuentan como humanos (humanos=%d)" % Net._num_humanos)
	for w in _trabajadores():
		_ok(not Net._avatares.has(w), "el trabajador %d no tiene cuerpo" % w)

	# 2) Entro al piso 1: lo lleva la sala y yo soy espejo.
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and _espejos_vivos() > 0, 40.0), "bajo al piso 1 y veo sus enemigos (%d)" % _espejos_vivos())
	_ok(dato_sala("dueno_piso_1") == "1", "el piso 1 lo lleva la sala")
	_ok(not Net._soy_dueno, "entro de espejo")

	# 3) EL ALBOROTO: soy espejo, asi que mi ruido le llega a la sala y revienta una pared delante de mi.
	var brotes_antes := _texto(registro_sala).count("en piso:1! Brote disparado")
	var t := 0.0
	while _texto(registro_sala).count("en piso:1! Brote disparado") <= brotes_antes and t < 20.0:
		Game.sumar_alboroto(40.0)
		await _esperar(0.5)
		t += 0.5
	_ok(_texto(registro_sala).count("en piso:1! Brote disparado") > brotes_antes,
		"mi ruido de espejo llega a la sala y revienta una pared (%.1f s)" % t)
	_ok(Game.alboroto == 0.0, "el espejo no acumula alboroto propio (%.0f)" % Game.alboroto)
	# PRUEBA_CABOS=1 -> solo los dos cabos sueltos del 07/10 (ver _cabos_sueltos) y se acaba: sin esperar a que
	# termine ninguna pelea (en las pruebas el grupo solo sabe ir recto y se atasca en fila: no acaban).
	if OS.get_environment("PRUEBA_CABOS") != "":
		await _cabos_sueltos()
		await _fin_solo()
		return

	# 5) LA PELEA LA EJECUTA UN TRABAJADOR DE PELEA (Parte 3): en el piso espera uno dentro, que no es el
	# dueño. Me planto al lado de un enemigo o le ataco; monta la pelea con mis fichas y yo la veo en ESPEJO.
	_ok(await _hasta(func(): return _pelea_libre() != 0, 30.0), "en el piso 1 espera un trabajador de pelea")
	var f1: int = _pelea_libre()
	await _esperar(3.0)   # que cargue el piso y reciba los enemigos
	var marca_pelea := _marca_registros()   # los numeros de ESTA pelea: lo que se escriba a partir de aqui
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
		"la pelea la ejecuta el de pelea y yo la espejo (anfitrion=%d, de pelea=%d)" % [Net.peleas._pelea_anfitrion, f1])
	_ok(await _hasta(func(): return _pelea_libre() not in [0, f1], 30.0), "mientras peleo, entra otro a esperar la siguiente")
	_ok(not Game.combate_activo(), "en mi PC no se simula ningun enemigo de la pelea")
	# LOS DOBLES PELEAN CON MIS NUMEROS: el trabajador apunta los de cada doble al montar la pelea
	# (Game.abrir_pelea_de_fichas); aqui se comparan con los que tendria el personaje en solitario.
	await _esperar(1.5)   # los registros se escriben con retraso
	var comparados := 0
	var distintos: Array = []
	for pj in [Game.lider()] + Game.companeros():
		var linea := _linea_desde("[pelea] doble %s " % pj.uid, marca_pelea)
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
		var linea_e := _linea_desde("[pelea] enemigo %d " % int(nid), marca_pelea)
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

	_ok(not _de_pelea().has(f1) or _pelea_libre() != 0, "al acabar, el que peleo deja sitio al que ya esperaba")

	# 5c) Otra pelea, para el paso 6: la lleva el que estaba esperando.
	await _esperar(3.0)
	await _abrir_pelea_con_un_enemigo()
	_ok(Net.peleas.espejando() and _de_pelea().has(Net.peleas._pelea_anfitrion),
		"la segunda pelea la ejecuta otro trabajador de pelea")

	# (El 6a viejo, "se cae el dueño del piso y lo hereda el humano de dentro", ya no existe: el piso lo lleva la sala.)
	# La segunda pelea no hace falta acabarla: la dejo (como al cerrarla) y espero a que el trabajador la suelte.
	if Net.peleas.espejando():
		Game._on_combate_espejo_cerrado()
	await _hasta(func(): return not Net.peleas.ocupado_en_pelea(), 15.0)

	# 6b) SE CAE TODO (F4) EN PLENA PELEA: se matan todos los procesos a lo bruto. La pelea SE DESHACE (la
	# llevaba un trabajador, decidido asi) y la reserva vuelve a llenarse.
	await _hasta(func(): return _pelea_libre() != 0, 30.0)
	await _esperar(3.0)
	await _abrir_pelea_con_un_enemigo()
	_ok(Net.peleas.espejando(), "la pelea va a un trabajador de pelea")
	var muertos: Array = _trabajadores()   # los que voy a matar: la reserva tiene que ser OTRO
	for pid in Array(dato_sala("pids_trab").split(",", false)).map(func(x): return int(x)):
		if proceso_vivo(pid):
			OS.kill(pid)
	# Que se deshace = ya no espejo nada. Puede haber pantalla igual: el enemigo que tengo al lado es MIO y me
	# embiste, y esa pelea nueva ya va en mi PC (no hay trabajador).
	t = 0.0
	while Net.peleas.espejando() and t < 10.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not Net.peleas.espejando(), "la pelea del trabajador caido se deshace (ahora %s)" % [
		"peleo en mi PC" if Game.combate_activo() else "sin pelea"])
	_ok(await _hasta(func(): return _trabajadores().any(func(w): return not muertos.has(w)), 45.0),
		"la reserva se repone con un trabajador NUEVO tras la caida (%s)" % dato_sala("trabajadores"))

	await _fin_solo()


# LOS DOS CABOS SUELTOS DE LOS TRABAJADORES DE PELEA (07/10; apuntados el 21/09):
#  1) el RUIDO de la pelea que ejecuta un trabajador va a nombre del humano que la abrio (el trabajador no tiene
#     cuerpo, y el brote salia delante de cualquiera). Abro una pelea, salgo de ella y el trabajador, sin nadie
#     dentro, la cierra: su registro tiene que decir que el ruido es mio (soy el 1).
#  2) el trabajador de pelea SE CAE CON MIS FICHAS EN LA MANO: lo mato y ataco enseguida. El host tarda ~5 s en
#     darlo por caido, asi que le manda mis fichas a un proceso muerto que nunca contesta. Antes los enemigos se
#     quedaban reservados a mi nombre y congelados; ahora la pelea me vuelve y va en mi PC.
func _cabos_sueltos() -> void:
	await _hasta(func(): return _pelea_libre() != 0, 30.0)
	await _esperar(3.0)
	var f1: int = _pelea_libre()
	await _abrir_pelea_con_un_enemigo()
	_ok(Net.peleas.espejando() and Net.peleas._pelea_anfitrion == f1, "cabo 1: la pelea la ejecuta el trabajador %d" % f1)
	await _esperar(2.0)
	var mio := "[alboroto] la pelea que ejecuto es de %d:" % multiplayer.get_unique_id()
	var ruido_antes := _lineas_en_registros(mio)
	Game._on_combate_espejo_cerrado()   # salgo de su pelea, como al cerrarla
	var t := 0.0
	while _lineas_en_registros(mio) <= ruido_antes and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(_lineas_en_registros(mio) > ruido_antes,
		"cabo 1: al cerrarse, el ruido de la pelea del trabajador va a MI nombre (%.1f s)" % t)
	t = 0.0
	while Net.peleas.ocupado_en_pelea() and t < 15.0:
		await _esperar(0.5)
		t += 0.5

	await _hasta(func(): return _pelea_libre() not in [0, f1], 30.0)
	await _esperar(3.0)
	var f_cae: int = _pelea_libre()
	var pid_cae: int = _pid_de(f_cae)
	_ok(f_cae != 0 and pid_cae > 0, "cabo 2: tengo el trabajador de pelea que voy a tirar (%d, pid %d)" % [f_cae, pid_cae])
	if pid_cae > 0:
		OS.kill(pid_cae)
	await _abrir_pelea_con_un_enemigo()
	t = 0.0
	# (12/10) Se espera a la PANTALLA de pelea, no a combate_activo(): ese solo es cierto con la pelea en mi PC.
	while not Game.combate_activo() and (Net.peleas._pelea_anfitrion == 0 or Net.peleas._pelea_anfitrion == f_cae) and t < 15.0:
		await _esperar(0.5)
		t += 0.5
	# (12/10) Antes la pelea volvia y se jugaba en MI PC; ahora la lleva OTRO trabajador ("que mi PC no lleve nada").
	_ok(Net.peleas.espejando() and Net.peleas._pelea_anfitrion != f_cae,
		"cabo 2: al caerse el trabajador con mis fichas, la pelea la lleva OTRO trabajador (%d, %.1f s)"
		% [Net.peleas._pelea_anfitrion, t])


# Me planto al lado del primer enemigo vivo; si no me embiste solo, le ataco. Espera a tener pantalla.
func _abrir_pelea_con_un_enemigo() -> void:
	var jugador: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var presa = null
	var ids: Array = Net.enemigos._enem_nodos.keys()   # espejos: el piso lo lleva la sala
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


# El final, sin jugador B: me voy, la sala se cierra sola y se lleva a sus trabajadores.
func _fin_solo() -> void:
	var pids: Array = Array(dato_sala("pids_trab").split(",", false)).map(func(x): return int(x))
	for linea in _texto(registro_sala).split("\n"):
		if linea.contains("SCRIPT ERROR"):
			print("[sala] ", linea)
	Net.desconectar()
	var t := 0.0
	while OS.is_process_running(_pid_sala) and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not OS.is_process_running(_pid_sala), "la sala se cierra sola al irme (%.1f s)" % t)
	await _esperar(2.0)
	var vivos := pids.filter(func(x): return proceso_vivo(x))
	_ok(not pids.is_empty() and vivos.is_empty(), "los trabajadores (%d) se cierran con la sala (%d vivos)" % [pids.size(), vivos.size()])
	for p in [_pid_sala] + pids:
		if proceso_vivo(p):
			OS.kill(p)
	if _nube_id != "":
		await Nube.partida_borrar(_nube_id)
	_borrar_ranura()
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit()
