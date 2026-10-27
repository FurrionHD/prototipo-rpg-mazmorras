# UNA PELEA EN LA SALA, DE PRINCIPIO A FIN (fase 2, etapa 3, paso 6; antes prueba_town_trabajadores, cuando las peleas
# las ejecutaba un trabajador de pelea). La sala lleva el piso y la pelea; el jugador la ve en espejo. Mira:
#   1) que la sala ya no lanza trabajadores: el unico otro de la red es ella;
#   2) el piso 1 lo lleva la sala y yo soy espejo;
#   3) mi ruido de espejo le llega a la sala y revienta una pared;
#   4) la pelea la ejecuta la sala, es TACTICA y veo su arena; los DOBLES y los ENEMIGOS pelean con los mismos numeros que
#      en mi PC (lo apunta la sala en su registro al montarla);
#   5) la juego hasta el final: la sala la cierra sola al salir yo y me vuelve lo mio (excelia, stats, desgaste del arma);
#   6) el ruido de una pelea de la sala va a MI nombre (el brote sale delante de mi, no de cualquiera).
# El jugador entra como un cliente mas de la sala de una ranura de prueba (83); lo de dentro, de las lineas "[S] dato" y
# del registro de la sala.
#   <godot> --headless --path . res://tools/prueba_town_pelea_sala.tscn -- nube_local
extends "res://tools/prueba_town_sala_comun.gd"

const TODO_EL_GRUPO := ["Agirato ochinan", "Catalardio", "Dasui", "Daniel"]


func _espejos_vivos() -> int:
	var n := 0
	for id in Net.enemigos._enem_nodos:
		if is_instance_valid(Net.enemigos._enem_nodos[id]):
			n += 1
	return n


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


# Cuantas lineas con 'texto' tiene el registro de la sala (se escribe con retraso: se relee entero cada vez).
func _lineas_sala(texto: String) -> int:
	return _texto(registro_sala).count(texto)


# La ultima linea que empieza por 'prefijo' escrita en el registro de la sala DESPUES de 'desde' (su largo de entonces):
# la sala lleva varias peleas en su registro y los numeros de un personaje cambian de una a otra (la armadura se gasta).
func _linea_sala_desde(prefijo: String, desde: int) -> String:
	var texto: String = _texto(registro_sala)
	var ultima := ""
	for l in texto.substr(mini(desde, texto.length())).split("\n"):
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

	# 1) Sin trabajadores: en la red solo estamos la sala y yo.
	await _esperar(3.0)
	_ok(Net._num_humanos == 1, "soy el unico humano (humanos=%d)" % Net._num_humanos)
	_ok(Net._peers.keys() == [1], "en la red solo esta la sala, ningun trabajador (%s)" % str(Net._peers.keys()))

	# 2) Entro al piso 1: lo lleva la sala y yo soy espejo.
	Net.pisos.solicitar_entrar(1)
	_ok(await _hasta(func(): return Net._mi_lugar == "piso:1" and _espejos_vivos() > 0, 40.0), "bajo al piso 1 y veo sus enemigos (%d)" % _espejos_vivos())
	_ok(dato_sala("dueno_piso_1") == "1", "el piso 1 lo lleva la sala")
	_ok(not PisoVivo.dueno_de(Net._mi_lugar), "entro de espejo")

	# 3) EL ALBOROTO: soy espejo, asi que mi ruido le llega a la sala y revienta una pared delante de mi.
	var brotes_antes := _lineas_sala("en piso:1! Brote disparado")
	var t := 0.0
	while _lineas_sala("en piso:1! Brote disparado") <= brotes_antes and t < 20.0:
		Game.sumar_alboroto(40.0)
		await _esperar(0.5)
		t += 0.5
	_ok(_lineas_sala("en piso:1! Brote disparado") > brotes_antes, "mi ruido de espejo llega a la sala y revienta una pared (%.1f s)" % t)

	# 4) LA PELEA LA EJECUTA LA SALA y yo la veo en ESPEJO.
	await _esperar(3.0)
	var marca: int = _texto(registro_sala).length()   # los numeros de ESTA pelea: lo que se escriba a partir de aqui
	await _abrir_pelea_con_un_enemigo()
	_ok(Game.hay_pelea_en_pantalla(), "se abre la pelea")
	var pt: Node = Net.peleas._pantalla_combate()
	_ok(pt != null and bool(pt.get("tactico")) and Game.pelea_tactica_en_curso(), "en la mazmorra es TACTICA y veo su arena")
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la ejecuta la sala y yo la espejo (pelea %d)" % Net.peleas._pelea_sigo)
	_ok(not Game.combate_activo(), "en mi PC no se simula ningun enemigo de la pelea")
	# LOS DOBLES PELEAN CON MIS NUMEROS: la sala apunta los de cada doble al montar la pelea (Game.abrir_pelea_de_fichas);
	# aqui se comparan con los que tendria el personaje en solitario.
	await _esperar(1.5)   # el registro se escribe con retraso
	var comparados := 0
	var distintos: Array = []
	for pj in [Game.lider()] + Game.companeros():
		var linea := _linea_sala_desde("[pelea] doble %s " % pj.uid, marca)
		if linea == "":
			continue
		comparados += 1
		var c: Combatant = Game.crear_player_combatant(pj)
		var mio := "def=%.3f red=%.4f spd=%.3f cast=%.3f amp=%.3f hpmax=%.2f" % [
			c.def_value(), c.armor_reduction, c.spd(), c.cast_spd(), c.magic_amp, c.max_hp]
		if not linea.ends_with(mio):
			distintos.append("%s: sala '%s' / mi PC '%s'" % [pj.nombre, linea.get_slice(" ", 3), mio])
	_ok(comparados > 0 and distintos.is_empty(),
		"los dobles de la sala pelean con mis mismos numeros (%d comparados) %s" % [comparados, "; ".join(distintos)])
	# Y LOS ENEMIGOS con los mismos que les saldrian en mi PC (misma tirada, mutacion, jefe y piso).
	var enem_comp := 0
	var enem_dist: Array = []
	for nid in Net.enemigos._enem_nodos:
		var ne = Net.enemigos._enem_nodos[nid]
		if not is_instance_valid(ne) or ne.data == null:
			continue
		var linea_e := _linea_sala_desde("[pelea] enemigo %d " % int(nid), marca)
		if linea_e == "":
			continue
		enem_comp += 1
		var ce: Combatant = ne.data.crear_combatant(ne.current_t, bool(ne.mutante), bool(ne.es_boss))
		var mio_e := "atk=%.3f def=%.3f spd=%.3f hpmax=%.2f piso=%d" % [ce.atk(), ce.def_value(), ce.spd(), ce.max_hp, Game.current_floor]
		if not linea_e.ends_with(mio_e):
			enem_dist.append("%d: sala '%s' / mi PC '%s'" % [int(nid), linea_e.substr(linea_e.find("atk=")), mio_e])
	_ok(enem_comp > 0 and enem_dist.is_empty(),
		"los enemigos de la sala tienen los mismos numeros que en mi PC (%d comparados) %s" % [enem_comp, "; ".join(enem_dist)])

	# 5) La juego desde el espejo (Atacar en cada turno mio) hasta que acabe y pulso Continuar: la sala tiene que
	# cerrarla SOLA (nadie pulsa alli) y devolverme lo mio. Y el ruido de la pelea, a MI nombre (6).
	var excelia_antes: float = _excelia_grupo()
	var stats_antes: Dictionary = (Game.lider().ability_internal as Dictionary).duplicate()
	var dur_antes: float = Game.durabilidad_slot("main", Game.lider())
	t = 0.0
	var mia: Node = Net.peleas._pantalla_combate()
	var plazo: float = 150.0 if is_instance_valid(mia) and bool(mia.get("tactico")) else 90.0
	while is_instance_valid(mia) and t < plazo and not (mia.acabada() if mia.has_method("acabada") else true):
		if int(mia.get("_state")) == 1 and not _caja_abierta(mia):
			var b: BaseButton = (mia.get("_action_buttons") as Dictionary).get(0)
			if b != null and not b.disabled and b.is_visible_in_tree():
				b.pressed.emit()
			elif bool(mia.get("tactico")):
				await _andar_hacia_objetivo(mia)
		if fmod(t, 5.0) < 0.26:
			_traza_tactico(mia, t)
		await _esperar(0.25)
		t += 0.25
	_ok(is_instance_valid(mia) and mia.acabada(), "la pelea de la sala termina jugandola desde el espejo (%.1f s)" % t)
	if is_instance_valid(mia) and not mia.acabada():
		var tz: Array = mia.get("_traza")
		for l in tz.slice(maxi(0, tz.size() - 80)):
			print("[traza-espejo] ", l)
	var cerradas_antes := _lineas_sala("[pelea] cierro la pelea ")
	var mi_ruido := "[alboroto] la pelea que ejecuto es de %d:" % multiplayer.get_unique_id()
	var ruido_antes := _lineas_sala(mi_ruido)
	if is_instance_valid(mia):
		mia._on_continue_pressed()
	t = 0.0
	while (_lineas_sala("[pelea] cierro la pelea ") <= cerradas_antes or Net.peleas._desgaste_pendiente) and t < 10.0:
		await _esperar(0.5)
		t += 0.5
	_ok(_lineas_sala("[pelea] cierro la pelea ") > cerradas_antes, "la sala cierra sola la pelea al salir yo (%.1f s)" % t)
	_ok(not Game.hay_pelea_en_pantalla() and not Net.peleas.espejando() and not Net.peleas._desgaste_pendiente,
		"vuelvo al mapa con lo mio de vuelta")
	_ok(_excelia_grupo() > excelia_antes, "la excelia de la pelea llega a mis personajes (%.2f -> %.2f)" % [excelia_antes, _excelia_grupo()])
	var stats_despues: Dictionary = Game.lider().ability_internal
	_ok(float(stats_despues.get("fuerza", 0.0)) > float(stats_antes.get("fuerza", 0.0))
		or float(stats_despues.get("destreza", 0.0)) > float(stats_antes.get("destreza", 0.0)),
		"el lider gana Fuerza/Destreza pegando en la pelea de la sala")
	var dur_despues: float = Game.durabilidad_slot("main", Game.lider())
	_ok(Game.lider().equipped_main == null or dur_despues < dur_antes,
		"el arma del lider se gasta en la pelea de la sala (%.4f -> %.4f)" % [dur_antes, dur_despues])
	_ok(await _hasta(func(): return _lineas_sala(mi_ruido) > ruido_antes, 10.0),
		"el ruido de la pelea va a MI nombre (el brote sale delante de mi)")
	_ok(await hasta_sala("peleas", func(v): return v == "0", 10.0) and dato_sala("reservas") == "0",
		"la sala se queda sin peleas ni reservas (%s, %s)" % [dato_sala("peleas"), dato_sala("reservas")])

	await _fin_solo()


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
	var acerca: float = 0.0 if mejor == null else antes.distance_to(mejor.global_position) - tm._cuerpo.global_position.distance_to(mejor.global_position)
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


# El final, sin jugador B: me voy y la sala se cierra sola.
func _fin_solo() -> void:
	for linea in _texto(registro_sala).split("\n"):
		if linea.contains("SCRIPT ERROR"):
			print("[sala] ", linea)
	Net.desconectar()
	var t := 0.0
	while OS.is_process_running(_pid_sala) and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not OS.is_process_running(_pid_sala), "la sala se cierra sola al irme (%.1f s)" % t)
	if proceso_vivo(_pid_sala):
		OS.kill(_pid_sala)
	if _nube_id != "":
		await Nube.partida_borrar(_nube_id)
	_borrar_ranura()
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit()
