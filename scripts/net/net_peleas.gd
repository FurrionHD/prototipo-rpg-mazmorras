# ============================================================
#  net_peleas.gd  (hijo de Net: /root/Net/Peleas)
#  LAS PELEAS EN MULTI: pedirle la pelea al dueño del piso (reservas), refuerzos que alcanzan a un
#  espejo, devolver el resultado, unirse a la pelea de otro, el TRASPASO cuando se va el anfitrion,
#  la ficha de combate por red y el espejo (instantaneas, roster y turnos). Net.peleas.<funcion>.
# ============================================================
extends Node

# Una pelea EXISTE en la red: tiene id y una maquina que la EJECUTA (la de quien la abrio, porque
# es la que tiene la pantalla delante; el dueño del piso puede estar en su propia pelea o en
# ninguna). Los demas participantes la ven en ESPEJO y le mandan sus acciones.
var _pelea_id: int = 0             # la pelea que ejecuto YO (0 = ninguna)
var _pelea_participantes: Array = []  # peers que estan dentro de MI pelea (yo no me cuento)
var _pelea_sigo: int = 0           # la pelea que estoy ESPEJANDO (0 = ninguna)
var _pelea_anfitrion: int = 0      # que peer ejecuta la pelea que espejo
var _pelea_next: int = 1           # contador de ids de pelea (por maquina; el id lleva el peer)
# Los DOBLES de los personajes de otros que pelean en MI pantalla: peer_id -> Array[PersonajeData],
# en el orden en que ese jugador me los mando (su formacion). Al cerrar, a cada uno se le devuelve
# lo que su doble vivio (vida, mana y excelia ganada).
var _dobles: Dictionary = {}
# ESPEJO: los personajes MIOS que estan en la pelea que sigo.
var _mis_en_pelea: Array = []      # los que ofreci al unirme, en orden de formacion
var _mis_huecos: Dictionary = {}   # hueco en la fila de aliados -> mi PersonajeData
# ME HE SALIDO del espejo por mi cuenta y el anfitrion todavia no me ha devuelto lo que vivieron
# mis personajes (ver salir_del_espejo). Mientras esto este en pie NO puedo meterme en otra pelea:
# _devolver_desgaste ASIGNA sobre la ficha, asi que el lote que viene de camino le pisaria a la
# ficha lo que hubiera hecho en la pelea nueva.
var _desgaste_pendiente: bool = false
# CUANDO CADUCA esa espera (ms de reloj del motor). Es la red de seguridad del bug de "no me entra
# en combate": mientras _desgaste_pendiente este en pie no se puede pelear, y si el lote NO llega
# nunca (un anfitrion que se cae justo despues, un RPC que se pierde en un corte, un camino nuevo que
# se olvide de contestar) el jugador se queda sin poder entrar en combate el resto de la sesion sin
# ningun aviso. El lote llega en un viaje de ida y vuelta -milisegundos en LAN-, asi que cinco
# segundos son de sobra para lo legitimo y cortos para lo roto: pasados, se da por perdido y se
# sigue jugando. Perder un desgaste es un mal rato; no volver a pelear es la partida.
const DESGASTE_ESPERA_MAX_MS := 5000
var _desgaste_limite_ms: int = 0
# Bichos RESERVADOS: quien los esta peleando. Lo lleva el DUEÑO del piso, que es quien arbitra.
# Sin esto dos jugadores podrian coger el mismo bicho a la vez. Mismo espiritu que _vetas_ocupadas.
var _enem_ocupados: Dictionary = {}   # net_id -> peer_id que lo pelea (SOLO el dueño del piso)


# --- PELEAR CONTRA UN PISO QUE SIMULA OTRO (hito 5.3) -----------------------------------------
#
# El que NO simula el piso ve espejos. Al atacar uno, le PIDE la pelea a su dueño: el dueño reserva
# el bicho y a sus vecinos (nadie mas puede cogerlos), los congela, y le devuelve la lista de ids.
# El peticionario juega la pelea contra SUS espejos y al acabar devuelve el resultado, que el dueño
# aplica sobre los bichos de verdad. Todo pasa por el host porque en estrella un cliente no habla
# con otro cliente.

# La llama remote_enemy.atacado_por_jugador().
#
# OJO con el HOST que NO es dueño del piso (lo simula un cliente): es un caso REAL y se colaba.
# Mandarse a si mismo un rpc_id(1, ...) revienta con "RPC on yourself is not allowed". Si soy el
# host, el enrutado me lo hago en local pasandome como peticionario (yo soy el peer 1).
func solicitar_pelea(id: int) -> void:
	if not Net.activo or Net._soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_encaminar_pelea(id, Net._mi_lugar, 1)
	else:
		_pedir_pelea.rpc_id(1, id, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_pelea(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_pelea(id, lugar, multiplayer.get_remote_sender_id())


# SOLO host: le pasa la peticion a quien simule ese piso (o la resuelve el mismo si es suyo).
func _encaminar_pelea(id: int, lugar: String, quien: int) -> void:
	if Net._mi_lugar == lugar and Net._soy_dueno:
		_resolver_pelea(id, quien, lugar)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_pedir_pelea_dueno.rpc_id(dueno, id, lugar, quien)
	else:
		_responder_pelea(quien, [], false)   # nadie simula ese piso: no hay pelea que dar


# Le llega al dueño CLIENTE del piso (reenviada por el host).
@rpc("any_peer", "call_remote", "reliable")
func _pedir_pelea_dueno(id: int, lugar: String, para: int) -> void:
	if Net._mi_lugar != lugar or not Net._soy_dueno:
		return
	_resolver_pelea(id, para, lugar)


# SOLO el dueño: arbitra. Reserva el bicho y sus vecinos y responde con sus ids (vacio = ocupado).
# El grupo lo calcula vecinos(), el mismo que en solitario: es quien tiene los nodos reales y sabe
# quien esta al lado, con el tope MAX_COMBATIENTES.
func _resolver_pelea(id: int, quien: int, _lugar: String) -> void:
	var e: Dictionary = Net.enemigos._enemigos.get(id, {})
	var nodo = e.get("nodo") if not e.is_empty() else null
	# ¿Ese bicho YA lo esta peleando alguien? Entonces la respuesta no es "ocupado", es una
	# INVITACION A UNIRSE a esa pelea (hito 5.4-C): es lo que espera el jugador cuando ve a su
	# compañero peleando y va a echar una mano.
	var anfitrion: int = _anfitrion_de_enemigo(id, nodo)
	if anfitrion != 0 and anfitrion != quien:
		_responder_pelea(quien, [], false, anfitrion)
		return
	_responder_pelea(quien, _reservar_grupo(nodo, id, quien), false)


# SOLO el dueño: ¿en la pelea de QUIEN esta metido este bicho? 0 = en ninguna.
#
# La reserva dice a nombre de quien se congelo. Sin reserva pero congelado es una pelea MIA (las
# propias no pasan por _enem_ocupados, las monta enemy._start_combat) -- salvo que ahora mismo yo solo
# este ESPEJANDO la de otro, y entonces la pelea es de ese otro. Antes se daba siempre por mia, y al que
# venia a ayudar se le mandaba a pedir sitio a alguien que no ejecutaba nada ("ya no esta disponible").
func _anfitrion_de_enemigo(id: int, nodo) -> int:
	var a: int = int(_enem_ocupados.get(id, 0))
	if a != 0:
		return a
	if nodo == null or not is_instance_valid(nodo) or not nodo.get("_combat_triggered"):
		return 0
	if nodo.has_method("esta_muerto") and nodo.esta_muerto():
		return 0
	if espejando() and _pelea_anfitrion != 0:
		return _pelea_anfitrion
	return multiplayer.get_unique_id()


# De quien es la pelea en la que esta este bicho, en CUALQUIER maquina: el dueño lo sabe por sus
# reservas y los demas por el tick (remote_enemy.pelea_de). 0 = suelto. Lo usan las lineas de vinculo y
# el unirse por contacto.
func pelea_de_enemigo(n) -> int:
	if not Net.activo or n == null or not is_instance_valid(n) or not n.has_meta("net_id"):
		return 0
	var id: int = int(n.get_meta("net_id"))
	if Net._soy_dueno and Net.enemigos._enemigos.has(id):
		return _anfitrion_de_enemigo(id, n)
	return int(n.get("pelea_de")) if "pelea_de" in n else 0


# SOLO el dueño: reserva un bicho y a sus vecinos para la pelea de 'quien' y los congela. Devuelve
# los net_id reservados (vacio = no habia nada que dar). Extraido para que lo usen las DOS vias:
# la que pide el jugador al atacar, y la que EMPUJA el dueño cuando un bicho alcanza a alguien.
func _reservar_grupo(nodo, id: int, quien: int) -> Array:
	var ids: Array = []
	if nodo == null or not is_instance_valid(nodo) or _enem_ocupados.has(id):
		return ids
	if nodo.esta_muerto() or nodo.get("_combat_triggered"):
		return ids
	for n in nodo.vecinos():
		if not is_instance_valid(n) or not n.has_meta("net_id"):
			continue
		var nid: int = n.get_meta("net_id")
		if _enem_ocupados.has(nid):
			continue
		_enem_ocupados[nid] = quien
		n._combat_triggered = true      # congelado: ya esta en una pelea (la de otro)
		n.velocity = Vector2.ZERO
		n._cancelar_aviso()
		ids.append(nid)
	return ids


# EMPUJE (hito 5.4): un bicho ha alcanzado el cuerpo de OTRO jugador. La pelea es SUYA, no mia
# (yo solo simulo el piso). Se reserva el grupo y se le manda, CON emboscada: le han saltado
# encima, no ha atacado el.
#
# Devuelve si el empuje ha COLADO. Antes se iba en silencio cuando la reserva fallaba, y quien lo
# llama (enemy._start_combat) se quedaba sin saberlo: el bicho seguia suelto, retrocedia, volvia a
# embestir y volvia a sonar su golpe... indefinidamente, y encima con el dueño mirando su propia
# pantalla de combate. Ese era el "los enemigos en cola se escuchan golpeando sin parar".
func empujar_pelea(nodo: Node, peer: int) -> bool:
	if not Net.activo or not Net._soy_dueno or multiplayer.multiplayer_peer == null:
		return false
	if nodo == null or not nodo.has_meta("net_id"):
		return false
	var id: int = nodo.get_meta("net_id")
	var ids: Array = _reservar_grupo(nodo, id, peer)
	if ids.is_empty():
		return false
	_responder_pelea(peer, ids, true)
	return true


# La respuesta vuelve al destinatario; si yo soy un dueño CLIENTE, pasa por el host.
#
# OJO: hay que comparar con MI id, no con 1. "quien == 1" significa "el peticionario es el host",
# que solo soy YO si yo soy el host; en un dueño CLIENTE, tratarlo como propio se comia la
# respuesta y el que ataco se quedaba sin pelea (sin error ninguno, que es lo traicionero).
func _responder_pelea(quien: int, ids: Array, emboscada: bool, anfitrion: int = 0) -> void:
	if quien == multiplayer.get_unique_id():
		_pelea_resuelta(ids, emboscada, anfitrion)
	elif Net.es_host:
		_pelea_resuelta.rpc_id(quien, ids, emboscada, anfitrion)
	else:
		_rel_respuesta_pelea.rpc_id(1, quien, ids, emboscada, anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _rel_respuesta_pelea(para: int, ids: Array, emboscada: bool, anfitrion: int = 0) -> void:
	if not Net.es_host:
		return
	if para == 1:
		_pelea_resuelta(ids, emboscada, anfitrion)
	else:
		_pelea_resuelta.rpc_id(para, ids, emboscada, anfitrion)


# Corre en EL QUE PELEA: monta el combate contra sus propios espejos, o los METE en la pelea que ya
# tenga abierta (hito 5.4). Se les puede pasar tal cual a Game.start_combat porque exponen
# data/current_t/hp_restante y saben morir().
@rpc("any_peer", "call_remote", "reliable")
func _pelea_resuelta(ids: Array, emboscada: bool = false, anfitrion: int = 0) -> void:
	if ids.is_empty():
		# Ese bicho ya lo pelea alguien: en vez de rebotar, ME UNO A SU PELEA. Es lo que espera el
		# jugador al ver a su compañero peleando e ir a ayudarle.
		if anfitrion != 0:
			solicitar_unirse(anfitrion)
		else:
			_toast("Ese enemigo ya está peleando con otro.")
		return
	# ESTOY ESPEJANDO la pelea de otro: estos bichos me han alcanzado a MI, pero la pelea la ejecuta
	# el anfitrion y los combatientes son suyos. Se los paso para que los meta en ella. Asi un
	# enemigo puede entrar por CUALQUIERA de los que estan dentro, no solo por quien la abrio.
	if espejando():
		if _pelea_anfitrion != 0:
			_refuerzos_para_mi_pelea.rpc_id(_pelea_anfitrion, ids)
		return
	var nodos: Array = []
	for i in ids:
		var n = Net.enemigos._enem_nodos.get(i)
		if n != null and is_instance_valid(n):
			n.entrar_en_pelea()
			nodos.append(n)
	if nodos.is_empty():
		# Ya no tengo espejos de esos ids (culling, cambio de piso...), pero SIGUEN reservados y
		# congelados en casa del dueño. Hay que soltarlos o se quedan de estatua.
		_devolver_bichos(ids)
		return
	# Ya estoy peleando: estos se UNEN a mi pelea en vez de abrir otra (una por maquina). El que no
	# quepa se DEVUELVE al dueño: si no, se quedaria reservado y congelado para siempre.
	if Game.combate_activo():
		for n in nodos:
			if not Game.unir_enemigo_al_combate(n):
				n.salir_de_pelea()
		return
	# Emboscada solo si me han saltado encima; si ataque yo, la iniciativa es mia.
	# HAY QUE MIRAR EL RESULTADO: si estoy TRABAJANDO (mineria/tala/herboristeria/extraccion) hay un
	# _active_layer delante y start_combat rechaza la pelea. En multi el mundo no se pausa, asi que
	# esto pasa a menudo. Antes se ignoraba el rechazo y los bichos se quedaban reservados y
	# congelados para siempre, "peleando" con nadie: el bug de las estatuas del playtest.
	if not Game.start_combat(nodos, emboscada):
		_devolver_bichos(ids)


# --- REFUERZOS QUE ALCANZAN A UN ESPEJO (hito 5.4-C) -----------------------------------------
#
# Corre en EL ANFITRION: unos bichos han alcanzado a alguien que esta en MI pelea, y me los pasa
# para que entren en ella (ver _pelea_resuelta). Los nodos que necesito son los MIOS: si simulo el
# piso son los de verdad, y si no, mis espejos.
@rpc("any_peer", "call_remote", "reliable")
func _refuerzos_para_mi_pelea(ids: Array) -> void:
	if _pelea_id == 0 or not Game.combate_activo():
		_devolver_bichos(ids)
		return
	var entran: Array = []
	for i in ids:
		var n = _nodo_de_id(int(i))
		if n == null or not is_instance_valid(n):
			continue
		if n.has_method("entrar_en_pelea"):
			n.entrar_en_pelea()        # espejo: a partir de aqui es un combatiente mio
		else:
			n._combat_triggered = true # nodo real: ya lo congelo _reservar_grupo, por si acaso
		if Game.unir_enemigo_al_combate(n):
			entran.append(int(i))
		else:
			_devolver_bichos([i])      # no cabia: que el dueño lo suelte, o se queda estatua
	if not entran.is_empty():
		# La reserva estaba a nombre del que fue alcanzado, no a mi nombre. Si a EL se le corta la
		# conexion, _soltar_reservas_de descongelaria bichos que yo estoy peleando: se apunta a mi.
		reasignar_reservas(entran)


# El nodo que YO tengo para un net_id: el de verdad si simulo el piso, mi espejo si no.
func _nodo_de_id(id: int):
	if Net._soy_dueno:
		var e: Dictionary = Net.enemigos._enemigos.get(id, {})
		return e.get("nodo") if not e.is_empty() else null
	return Net.enemigos._enem_nodos.get(id)


# Puerta publica: la usa Game.retomar_combate, que tambien puede quedarse con bichos congelados si
# el traspaso no cuaja. Aguanta que no haya sesion (en solitario no hay nada que devolver).
func devolver_bichos(ids: Array) -> void:
	if not Net.activo or ids.is_empty():
		return
	_devolver_bichos(ids)


# Devolver bichos reservados que al final no entran en ninguna pelea (si no, se quedan congelados
# para siempre: el bug de las estatuas por red).
func _devolver_bichos(ids: Array) -> void:
	for i in ids:
		var n = _nodo_de_id(int(i))
		if n == null or not is_instance_valid(n):
			continue
		if n.has_method("salir_de_pelea"):
			n.salir_de_pelea()   # el espejo ya avisa al dueño por resultado_bicho
		else:
			_enem_ocupados.erase(int(i))
			if not n.esta_muerto():
				n.reanudar_tras_combate(-1.0)


# Estos bichos los peleo YO ahora: que el dueño del piso apunte la reserva a mi nombre.
func reasignar_reservas(ids: Array) -> void:
	if not Net.activo or ids.is_empty() or multiplayer.multiplayer_peer == null:
		return
	var yo: int = multiplayer.get_unique_id()
	if Net._soy_dueno:
		_aplicar_reasignacion(ids, yo)
	elif Net.es_host:
		_encaminar_reasignacion(ids, Net._mi_lugar, yo)
	else:
		_pedir_reasignacion.rpc_id(1, ids, Net._mi_lugar, yo)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_reasignacion(ids: Array, lugar: String, para: int) -> void:
	if not Net.es_host:
		return
	_encaminar_reasignacion(ids, lugar, para)


func _encaminar_reasignacion(ids: Array, lugar: String, para: int) -> void:
	if Net._mi_lugar == lugar and Net._soy_dueno:
		_aplicar_reasignacion(ids, para)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_reasignacion.rpc_id(dueno, ids, lugar, para)


@rpc("any_peer", "call_remote", "reliable")
func _rel_reasignacion(ids: Array, lugar: String, para: int) -> void:
	if Net._mi_lugar != lugar or not Net._soy_dueno:
		return
	_aplicar_reasignacion(ids, para)


func _aplicar_reasignacion(ids: Array, para: int) -> void:
	for i in ids:
		if _enem_ocupados.has(int(i)):
			_enem_ocupados[int(i)] = para


# --- RESULTADO de una pelea jugada contra espejos ---------------------------------------------

# La llaman remote_enemy.morir() / .reanudar_tras_combate() al cerrarse el combate.
func resultado_bicho(id: int, ha_muerto: bool, hp: float) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_encaminar_resultado(id, ha_muerto, hp, Net._mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_resultado.rpc_id(1, id, ha_muerto, hp, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_resultado(id: int, ha_muerto: bool, hp: float, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_resultado(id, ha_muerto, hp, lugar)


func _encaminar_resultado(id: int, ha_muerto: bool, hp: float, lugar: String) -> void:
	if Net._mi_lugar == lugar and Net._soy_dueno:
		_aplicar_resultado(id, ha_muerto, hp)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_resultado.rpc_id(dueno, id, ha_muerto, hp, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_resultado(id: int, ha_muerto: bool, hp: float, lugar: String) -> void:
	if Net._mi_lugar != lugar or not Net._soy_dueno:
		return
	_aplicar_resultado(id, ha_muerto, hp)


# SOLO el dueño: lo que paso en la pelea de otro se aplica sobre el bicho DE VERDAD. morir() ya se
# encarga de difundir el cadaver a todos (y de abrir las salidas si era el jefe).
func _aplicar_resultado(id: int, ha_muerto: bool, hp: float) -> void:
	_enem_ocupados.erase(id)
	var e: Dictionary = Net.enemigos._enemigos.get(id, {})
	var nodo = e.get("nodo") if not e.is_empty() else null
	if nodo == null or not is_instance_valid(nodo):
		return
	if ha_muerto:
		nodo.morir()
	else:
		nodo.reanudar_tras_combate(hp)


# Quien simula ese lugar (0 = nadie). Solo el host lo sabe.
# Alguien se fue (o se le corto). Si tenia bichos RESERVADOS para su pelea, hay que soltarlos o se
# quedan congelados para siempre: es el bug de las estatuas, pero por red. Lo difunde el host y lo
# aplica cada dueño sobre los suyos.
@rpc("any_peer", "call_remote", "reliable")
func _soltar_reservas_de(quien: int) -> void:
	if not Net._soy_dueno:
		return
	for id in _enem_ocupados.keys():
		if _enem_ocupados[id] != quien:
			continue
		_enem_ocupados.erase(id)
		Net.extraccion._borrar_extrayendo(id)   # si era un cuerpo a medio extraer, vuelve a estar libre
		var e: Dictionary = Net.enemigos._enemigos.get(id, {})
		var nodo = e.get("nodo") if not e.is_empty() else null
		if nodo != null and is_instance_valid(nodo) and not nodo.esta_muerto():
			nodo.reanudar_tras_combate(-1.0)   # vuelve a la vida normal, sin heridas nuevas


# Quien simula ese lugar (0 = nadie). Solo el host lo sabe.
func _dueno_de(lugar: String) -> int:
	if not lugar.begins_with("piso:"):
		return 0
	return Net._dueno_piso.get(int(lugar.substr(5)), 0)


# Aviso corto en MI pantalla (el HUD es local: los avisos no se replican).
func _toast(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast(texto)
	else:
		print("[net] ", texto)


# Acuse de recibo DISCRETO, en la esquina de abajo. Para lo rutinario (el autoguardado salta cada
# minuto): un cartelon en mitad de la pantalla cada 60 segundos era insufrible.
func _aviso_esquina(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso_esquina"):
		hud.mostrar_aviso_esquina(texto)
	else:
		print("[net] ", texto)


# --- PELEAS COMPARTIDAS: unirse a la pelea de otro (hito 5.4-C) -------------------------------
#
# Quien abre una pelea la EJECUTA. Los demas se unen: reciben el roster, abren la pantalla en
# ESPEJO y a partir de ahi les llegan instantaneas. Cuando le toca el turno a un personaje SUYO,
# el anfitrion le pide la accion; el la elige en su pantalla y vuelve. Asi el ATB, los dados y la
# resolucion pasan en UN solo sitio y no hay dos verdades.

# La pantalla de combate que tengo delante (la mia o el espejo), o null.
func _pantalla_combate() -> Node:
	if not is_instance_valid(Game._active_layer) or Game._active_layer.get_child_count() == 0:
		return null
	return Game._active_layer.get_child(0)


# Lo llama Game al abrir un combate en multi: esta pelea pasa a existir en la red.
func registrar_pelea() -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	_pelea_id = multiplayer.get_unique_id() * 1000000 + _pelea_next
	_pelea_next += 1
	_pelea_participantes.clear()


# --- TRASPASO DE LA PELEA ---------------------------------------------------------------------
#
# La pelea la ejecuta UNA maquina. Si esa se va (su jugador huye, o se le corta), la pelea no se
# cierra: se le pasa a otro de los que estan dentro y sigue donde estaba. Es la misma pieza para
# los dos casos, por eso se construye una vez.

# UN BICHO MIO me alcanza mientras estoy ESPEJANDO la pelea de otro. No se me abre una pelea nueva
# (me robaria la pantalla y dejaria al anfitrion esperando mi turno): se mete en la que estoy
# peleando. Solo pasa cuando YO simulo el piso; si no, el bicho es un espejo y su camino ya pasa por
# el dueño (empujar_pelea -> _pelea_resuelta, que tambien reenvia).
# Devuelve false si no hay a quien mandarselo (entonces el que llama lo deja esperando pegado).
func refuerzo_a_mi_pelea(nodo: Node) -> bool:
	if not Net.activo or not espejando() or _pelea_anfitrion == 0:
		return false
	if nodo == null or not nodo.has_meta("net_id"):
		return false
	var ids: Array = _reservar_grupo(nodo, int(nodo.get_meta("net_id")), _pelea_anfitrion)
	if ids.is_empty():
		return false
	_refuerzos_para_mi_pelea.rpc_id(_pelea_anfitrion, ids)
	return true


# El nodo que YO tengo para un net_id (publico: lo usa Game al recoger una pelea).
func nodo_de_id(id: int):
	return _nodo_de_id(id)


# ¿A quien le puedo pasar la pelea? Al primero que este dentro (0 = a nadie).
# ¿Ese peer sigue dentro de la pelea que ejecuto yo? Si no, no tiene sentido pedirle su turno.
func esta_en_mi_pelea(peer: int) -> bool:
	return _pelea_participantes.has(peer)


func heredero_de_pelea() -> int:
	return int(_pelea_participantes[0]) if not _pelea_participantes.is_empty() else 0


# La llama el combate cuando el que la ejecuta se va. Devuelve true si alguien la recoge.
func traspasar_pelea(estado: Dictionary) -> bool:
	var nuevo: int = heredero_de_pelea()
	if not Net.activo or _pelea_id == 0 or nuevo == 0 or multiplayer.multiplayer_peer == null:
		return false
	# Los DEMAS participantes (si los hay) pasan a espejar al nuevo: se los paso para que el los
	# recoja el mismo, que es quien va a tener la pantalla.
	var otros: Array = []
	for p in _pelea_participantes:
		if p != nuevo:
			otros.append(p)
	print("[traspaso] le paso la pelea a ", nuevo, " (y ", otros.size(), " espejo(s) mas)")
	_recoge_la_pelea.rpc_id(nuevo, estado, otros)
	# Yo ya no la llevo: ni participantes ni dobles (sus fichas viajan DENTRO del estado, asi que
	# no hay que devolverles nada: siguen peleando alli).
	_pelea_participantes.clear()
	_dobles.clear()
	_pelea_id = 0
	return true


@rpc("any_peer", "call_remote", "reliable")
func _recoge_la_pelea(estado: Dictionary, otros: Array) -> void:
	print("[traspaso] me llega la pelea: %d aliados, %d Net.enemigos (sigo=%d)" % [
		estado.get("aliados", []).size(), estado.get("enemigos", []).size(), _pelea_sigo])
	if _pelea_sigo == 0:
		return
	# Fuera mi espejo ANTES de montar la pelea de verdad: solo cabe una pantalla por maquina.
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("cerrar_espejo"):
		p.cerrar_espejo()
	await get_tree().process_frame   # que se recoja la capa vieja antes de montar la nueva
	_herederos_espejo = otros
	if not Game.retomar_combate(estado):
		print("[traspaso] no he podido recoger la pelea")
		_herederos_espejo.clear()


# Lo rellena _recoge_la_pelea y lo consume asumir_pelea: los que tienen que pasar a espejarme A MI.
var _herederos_espejo: Array = []


# La llama Game cuando ya tiene la pantalla montada: a partir de aqui la pelea es MIA.
func asumir_pelea(dobles_por_peer: Dictionary, pantalla: Node) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	registrar_pelea()
	for peer in dobles_por_peer:
		_dobles[peer] = dobles_por_peer[peer]
	# Los que ya estaban espejando siguen espejando, pero A MI.
	for peer in _herederos_espejo:
		if not _pelea_participantes.has(peer):
			_pelea_participantes.append(peer)
	_herederos_espejo.clear()
	if pantalla != null and pantalla.has_method("roster_para_espejo"):
		for peer in _pelea_participantes:
			_cambio_de_anfitrion.rpc_id(peer, _pelea_id, pantalla.roster_para_espejo())
	# Los bichos los peleo YO ahora: que el dueño del piso apunte las reservas a mi nombre, o al
	# desconectarse el que se fue se los encontraria "libres" y los descongelaria en plena pelea.
	var ids: Array = []
	for id in Net.enemigos._enem_nodos.keys():
		ids.append(id)
	if Net._soy_dueno:
		for id in Net.enemigos._enemigos.keys():
			ids.append(id)
	reasignar_reservas(ids)


# SE ME HA CAIDO EL ANFITRION de la pelea que espejo. Aqui NO se puede traspasar: el traspaso lo
# manda el que se va, y a este le han cortado sin darle tiempo. Lo que si se puede es no dejar la
# pantalla colgada esperando turnos que no van a llegar: se cierra y vuelves al mapa. Lo que
# vivieron tus personajes en esa pelea se pierde (sus dobles se fueron con el).
func _anfitrion_perdido() -> void:
	if _pelea_sigo == 0:
		return
	print("[traspaso] se ha caido el anfitrion de mi pelea: cierro el espejo")
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()
	_desgaste_pendiente = false   # se fue con el: no hay lote que esperar
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("cerrar_espejo"):
		p.cerrar_espejo()
	_toast("Tu compañero se ha desconectado: la pelea se ha deshecho.")


# Corre en un ESPEJO de tercero: la pelea que sigo ha cambiado de manos.
@rpc("any_peer", "call_remote", "reliable")
func _cambio_de_anfitrion(id: int, roster: Dictionary) -> void:
	_pelea_sigo = id
	_pelea_anfitrion = multiplayer.get_remote_sender_id()
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_roster"):
		p.aplicar_roster(roster)


# SE VA UNO SOLO (huida individual): la pelea SIGUE para los demas. Se le devuelve lo que vivieron
# sus dobles y se le cierra su espejo, y deja de recibir instantaneas. Es cerrar_pelea, pero para
# un participante en vez de para todos.
func sacar_de_la_pelea(peer: int) -> void:
	if not Net.activo or peer == 0:
		return
	# LA PELEA YA NO ESTA, pero hay que CONTESTAR IGUAL. Este era el bug de "no me entra en combate":
	# el que se sale del espejo por su cuenta se pone _desgaste_pendiente y espera respuesta
	# (ver salir_del_espejo), y si pulsaba Continuar en el mismo suspiro en que el anfitrion cerraba
	# la pelea, aqui se salia de vacio por _pelea_id == 0 y no le llegaba NADA. Ese flag solo lo
	# apagan _devolver_desgaste, _fin_espejo y _moriste, asi que se quedaba encendido PARA SIEMPRE:
	# ocupado_en_pelea() daba true el resto de la sesion y enemy._start_combat se salia por su return
	# seco en todos los contactos. Un _fin_espejo suelto (sin desgaste, que ya no hay dobles de donde
	# sacarlo) es exactamente el "ya no viene nada mas" que estaba esperando.
	if _pelea_id == 0:
		_fin_espejo.rpc_id(peer)
		_pelea_participantes.erase(peer)
		return
	if _dobles.has(peer):
		var lote: Array = []
		for doble in _dobles[peer]:
			# A mitad de pelea la vida y el mana viven en el COMBATIENTE: hay que bajarlos a la
			# ficha antes de mandarlos, o se iria con los que entro.
			Game.volcar_desgaste_en_ficha(doble)
			lote.append(Net.partida.desgaste_a_dict(doble))
		_devolver_desgaste.rpc_id(peer, lote)
		_dobles.erase(peer)
	_fin_espejo.rpc_id(peer)
	_pelea_participantes.erase(peer)


# ME SALGO YO del espejo, por mi cuenta: he pulsado "Continuar" con la pelea ya terminada y no
# quiero quedarme mirando hasta que el anfitrion pulse el suyo.
#
# La pantalla se recoge AQUI MISMO, pero la red no se cierra del todo, y ese es el detalle que
# importa: lo que vivieron mis personajes (vida, mana y LA EXCELIA GANADA) lo tiene el anfitrion y
# vuelve en un lote aparte, _devolver_desgaste, que cruza por uid contra _mis_en_pelea. Si aqui se
# hiciera cerrar_pelea() -que lo vacia- ese lote llegaria sin dueño, se descartaria entero y me
# saldria de la pelea con lo que entre: sin la excelia y curado gratis.
#
# Asi que se apaga lo que tiene que apagarse ya (dejo de espejar: no quiero que los bichos que me
# alcancen se cuelen en una pelea que ya no veo) y se CONSERVA _mis_en_pelea hasta que llegue el
# desgaste. Para que no se haga esperar, se le avisa al anfitrion de que me saque: reutiliza
# sacar_de_la_pelea, el mismo camino que la huida individual, asi el lote sale ya y no cuando el
# otro decida cerrar.
func salir_del_espejo() -> void:
	if _pelea_sigo == 0:
		return   # el cierre no es mio: ya lo han apagado _fin_espejo, _moriste o el anfitrion caido
	if _pelea_anfitrion != 0:
		_salgo_de_la_pelea.rpc_id(_pelea_anfitrion)
		_desgaste_pendiente = true
		_desgaste_limite_ms = Time.get_ticks_msec() + DESGASTE_ESPERA_MAX_MS
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_huecos.clear()
	# _mis_en_pelea NO se toca: es donde _devolver_desgaste busca por uid. Lo suelta _fin_espejo.


# Corre en EL ANFITRION: uno de los que estaban en mi pelea ha cerrado su pantalla por su cuenta.
# Es exactamente una huida individual, salvo que la pelea ya ha terminado: se le devuelve lo suyo
# y se le cierra el espejo.
@rpc("any_peer", "call_remote", "reliable")
func _salgo_de_la_pelea() -> void:
	sacar_de_la_pelea(multiplayer.get_remote_sender_id())


# 'derrotados' = peers cuyo grupo ENTERO cayo: en vez de devolverles el desgaste y cerrarles el
# espejo, se les manda al pueblo con la penalizacion (_moriste corre morir_jugador en SU maquina).
func cerrar_pelea(derrotados: Array = []) -> void:
	if _pelea_id != 0:
		for p in _pelea_participantes:
			if derrotados.has(p):
				# Su grupo murio: al pueblo. morir_jugador ya le reinicia las fichas, asi que NO se
				# le devuelve desgaste; _moriste tambien le cierra el espejo.
				_moriste.rpc_id(p)
				continue
			# A cada uno lo SUYO: lo que sus dobles han vivido en mi pantalla (vida, mana y la
			# excelia ganada) vuelve a sus personajes de verdad. Va ANTES de cerrarle el espejo.
			if _dobles.has(p):
				var lote: Array = []
				for doble in _dobles[p]:
					lote.append(Net.partida.desgaste_a_dict(doble))
				_devolver_desgaste.rpc_id(p, lote)
			_fin_espejo.rpc_id(p)
		_pelea_participantes.clear()
		_dobles.clear()
		_pelea_id = 0
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()


# Corre en EL QUE SE UNIO y cuyo grupo cayo entero: vuelve al pueblo con la penalizacion, igual que
# morir en solitario (decision del usuario: en multi los jugadores mueren de verdad, no se quedan a
# 1 de vida). Primero cierra su espejo (recoge la capa y despausa) y luego morir_jugador cambia de
# escena al pueblo. Sus personajes viven en SU maquina, asi que la muerte se resuelve aqui.
@rpc("any_peer", "call_remote", "reliable")
func _moriste() -> void:
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()
	# Morir NO devuelve desgaste (morir_jugador reinicia las fichas): no hay lote que esperar.
	_desgaste_pendiente = false
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("cerrar_espejo"):
		p.cerrar_espejo()   # -> Game._on_combate_espejo_cerrado: recoge la capa y el modal
	Game.morir_jugador()


# Corre en EL DUEÑO de los personajes: lo que vivio cada doble se aplica a su ficha de verdad.
#
# SE CRUZA POR UID, NO POR POSICION. Antes iba por indice contra _mis_en_pelea dando por hecho que
# el lote volvia en el mismo orden en que mande las fichas, y esa premisa se rompe por dos sitios:
#   - el TRASPASO de pelea (Game.retomar_combate) añade los dobles con un `if` sin `break`, asi que
#     si uno no cabe la lista del anfitrion queda CORRIDA respecto a mi formacion;
#   - _mis_en_pelea puede haber cambiado de orden (cambiar de lider, recolocar el equipo) o ser de
#     una union anterior, y aqui no se validaba ninguna id de pelea.
# Como aplicar_desgaste ASIGNA, un desfase de un puesto copiaba al mago encima del tanque: su
# excelia, su nivel, sus cinco stats y sus contadores. El uid lo hace imposible.
@rpc("any_peer", "call_remote", "reliable")
func _devolver_desgaste(lote: Array) -> void:
	for d_ in lote:
		var d := d_ as Dictionary
		var pj: PersonajeData = _mio_por_uid(String(d.get("uid", "")))
		if pj == null:
			push_warning("[multi] desgaste sin dueño (uid '%s'): se descarta" % String(d.get("uid", "")))
			continue
		Net.partida.aplicar_desgaste(pj, d)
	# Ya tengo lo mio: si me habia salido del espejo por mi cuenta, se acabo la espera y puedo
	# volver a meterme en peleas (ver salir_del_espejo).
	_desgaste_pendiente = false


# El personaje MIO con ese uid, entre los que mande a la pelea. Se busca en _mis_en_pelea y no en la
# plantilla entera a proposito: solo puede volver desgaste de quien mande.
func _mio_por_uid(uid: String) -> PersonajeData:
	if uid.is_empty():
		return null
	for pj in _mis_en_pelea:
		if pj != null and String((pj as PersonajeData).uid) == uid:
			return pj
	return null


# ¿Estoy espejando una pelea? (lo consulta el jugador para no dejarme accionar por mi cuenta)
func espejando() -> bool:
	return _pelea_sigo != 0


# ¿Me tiene pillado una pelea? Es espejando() MAS el rato en el que ya me he salido pero todavia
# me debe el desgaste (ver salir_del_espejo). Lo consultan los caminos que ABREN pelea, que son los
# que no pueden correr en ese hueco; espejando() a secas sigue valiendo para lo demas (redirigir un
# refuerzo, por ejemplo, que ahi si quiero haber dejado de espejar).
func ocupado_en_pelea() -> bool:
	if _pelea_sigo != 0:
		return true
	if not _desgaste_pendiente:
		return false
	# Ha caducado: el lote no viene. Se suelta AQUI (y no en un _process) porque este es el unico
	# sitio que pregunta, asi que no hace falta un reloj propio para algo que casi nunca pasa.
	if Time.get_ticks_msec() >= _desgaste_limite_ms:
		push_warning("[multi] el desgaste de mi ultima pelea no ha llegado en %d ms: se da por perdido"
			% DESGASTE_ESPERA_MAX_MS)
		_desgaste_pendiente = false
		_mis_en_pelea.clear()
		_mis_huecos.clear()
		# Y SE DICE. El sintoma de este atasco es "no me entra en combate", que desde el mando no se
		# distingue de un juego roto: sin una linea que lo explique se pierde la tarde buscando el bug
		# en el sitio equivocado (que es justo lo que paso).
		_toast("Se perdio lo de tu ultima pelea, pero ya puedes volver a pelear.")
		return false
	return true


# Le he pegado a un bicho que YA esta en una pelea: quiero entrar a ayudar. Quien sabe de quien es
# esa pelea es el DUEÑO del piso (lleva las reservas), asi que si no lo soy, se lo pregunto por la
# via de siempre —solicitar_pelea ya devuelve el anfitrion al que unirse—.
func unirme_a_la_pelea_de(id: int) -> void:
	if not Net.activo:
		return
	# Ya estoy en una pelea (la mia o espejando otra): una pantalla de combate por maquina.
	if Game.combate_activo() or ocupado_en_pelea():
		return
	if not Net._soy_dueno:
		# Si el tick ya me ha dicho de quien es la pelea, voy directo; si no, se lo pregunto al dueño
		# del piso, que lleva las reservas. Si el dato del tick se ha quedado viejo, _pedir_unirme lo
		# rechaza con su aviso, que es lo mismo que pasaria preguntando.
		var n = Net.enemigos._enem_nodos.get(id)
		var directo: int = int(n.pelea_de) if n != null and is_instance_valid(n) else 0
		if directo != 0 and directo != multiplayer.get_unique_id():
			solicitar_unirse(directo)
		else:
			solicitar_pelea(id)
		return
	var peer: int = _anfitrion_de_enemigo(id, _nodo_de_id(id))
	if peer != 0 and peer != multiplayer.get_unique_id():
		solicitar_unirse(peer)


# --- LA FICHA DE UN PERSONAJE POR RED --------------------------------------------------------
#
# Para que el que se une PELEE de verdad, sus stats tienen que estar en la maquina que ejecuta la
# pelea: alli es donde se tiran los dados. Se manda una copia de su ficha y el anfitrion monta con
# ella un DOBLE (un PersonajeData igual pero suyo), sobre el que corre el combate de siempre. Al
# acabar, del doble vuelven la vida, el mana y la excelia ganada, y se aplican al personaje REAL.
#
# El equipo se serializa con serializar_equipo, el mismo que ya usa el cofre del hogar: lleva la
# ruta base y la meta por instancia (tier, rareza, mejoras, durabilidad).
const _RANURAS := ["equipped_main", "equipped_off", "equipped_casco", "equipped_pecho",
	"equipped_manos", "equipped_pantalones", "equipped_botas"]
# Las COLAS de pocion a medias (cura y maná). Viajan en los dos sentidos: si te unes a la pelea de
# otro con una pocion a medio gotear, el anfitrion tiene que convertirla en Regeneracion dentro de
# la pelea, y lo que sobre tiene que volverte. Sin esto la pocion se perdia entera: entrabas sin
# ella, tu cola seguia goteando al vacio fuera del combate y al salir te machacaban el HP con el
# del doble, que nunca la vio.
const _COLAS_POCION := ["heal_left", "heal_rate", "heal_turnos",
	"mana_heal_left", "mana_heal_rate", "mana_heal_turnos"]
# LO QUE LLEVA PUESTO AHORA MISMO y dura ENTRE combates: los estados alterados, las cargas de Foco
# arcano y la imbuicion. Viaja en los dos sentidos por lo mismo que las colas de pocion: si te unes a
# la pelea de otro envenenado, el doble tiene que entrar envenenado, y los buffs que se eche dentro
# tienen que volverte al salir. La imbuicion llevaba aqui un agujero desde el principio -- solo
# viajaba su COLOR (ver anunciar_imbue), asi que el doble peleaba sin el manto puesto.
const _LO_PUESTO := ["estados", "foco_cargas", "imbue"]
# Lo que se le devuelve al dueño cuando acaba la pelea: su desgaste y lo que ha aprendido.
const _VUELVE := ["current_hp", "current_mp", "stamina", "level",
	"ability_internal", "ability_consolidado", "ability_base_nivel",
	"fuerza", "resistencia", "destreza", "agilidad", "magia",
	"guardianes_vencidos", "esquivas_exp", "hechizos_exp", "recitado_exp",
	"dano_recibido_exp", "dano_infligido_exp", "dano_bloqueado_exp",
	"heal_left", "heal_rate", "heal_turnos",
	"mana_heal_left", "mana_heal_rate", "mana_heal_turnos",
	"estados", "foco_cargas", "imbue"]


# --- UNIRSE ---------------------------------------------------------------------------------

# La llama el jugador al querer meterse en la pelea de un compañero que tiene al lado.
func solicitar_unirse(anfitrion: int) -> void:
	if not Net.activo or anfitrion == 0 or Game.combate_activo() or ocupado_en_pelea():
		return
	if anfitrion == multiplayer.get_unique_id():
		return
	# EL CANTO SE CORTA AQUI, y no en Game._montar_pantalla_combate como en las demas peleas: alli
	# seria tarde, la ficha ya habria salido. Interrumpirlo ahora deja player._casteo en null, asi que
	# el interrumpir_casteo de _montar_pantalla_combate se queda en nada y no lo apunta dos veces.
	var pnode: Node = get_tree().get_first_node_in_group("player")
	if pnode != null and pnode.has_method("interrumpir_casteo"):
		pnode.interrumpir_casteo()
	Game.soltar_casteo_en_vuelo()   # lo de una union anterior ya no vuelve
	# Va MI GRUPO ENTERO, en orden de formacion: sin sus fichas el anfitrion no puede tirar los
	# dados por ellos. Entra lo que quepa (el decide, ver _pedir_unirme); mi pos 1 siempre.
	_mis_en_pelea = _mi_formacion()
	var fichas: Array = []
	for pj in _mis_en_pelea:
		var f: Dictionary = Net.partida.ficha_a_dict(pj)
		# Y con el CONJURO que traiga puesto (recitado entero en el mapa, o a medias). Va como una
		# clave mas DENTRO de la ficha y no como un parametro nuevo del rpc: cambiar la aridad de un
		# @rpc rompe a cualquier peer con la version anterior, una clave de mas se ignora sola.
		var cast: Dictionary = Game.casteo_para_viajar(pj)
		if not cast.is_empty():
			f["casteo"] = cast
		fichas.append(f)
	_pedir_unirme.rpc_id(anfitrion, fichas)


# Mi grupo en ORDEN DE FORMACION: el lider primero y detras los acompañantes. Es el orden en el que
# se ofrecen para la pelea compartida (formacion decidida: pos 1 seguro, pos 2 si queda hueco).
func _mi_formacion() -> Array:
	var out: Array = [Game.lider()]
	for comp in Game.companeros():
		out.append(comp)
	return out


# Corre en EL ANFITRION: alguien quiere entrar en mi pelea, con la ficha de su personaje.
@rpc("any_peer", "call_remote", "reliable")
func _pedir_unirme(fichas: Array) -> void:
	var quien := multiplayer.get_remote_sender_id()
	var p: Node = _pantalla_combate()
	if _pelea_id == 0 or p == null or not p.has_method("roster_para_espejo") or fichas.is_empty():
		print("[Net.unirse] DENIEGO a ", quien, ": pelea_id=", _pelea_id, " pantalla=", p != null)
		_union_denegada.rpc_id(quien, "Esa pelea ya no está disponible.")
		return
	print("[Net.unirse] ", quien, " entra en mi pelea con ", fichas.size(), " personaje(s)")
	# Aguanta la pelea hasta que entre de verdad: si caen todos en ese hueco, no se cierra
	# dejando al que venia de rescate con una pelea muerta.
	if p.has_method("esperar_refuerzo"):
		p.esperar_refuerzo(true)
	# Un DOBLE por personaje suyo: pelean aqui con sus stats y su equipo. Se meten POR ORDEN DE
	# FORMACION y entra lo que quepa (MAX_ALIADOS): su pos 1 seguro, la pos 2 si queda hueco.
	var dobles: Array = []
	var idxs: Array = []
	for f in fichas:
		var doble: PersonajeData = Net.partida.ficha_de_dict(f)
		if not Game.unir_aliado_al_combate(doble, float(f.get("overload", 1.0))):
			break   # la pelea esta llena: los que falten se quedan fuera
		dobles.append(doble)
		# Y que la pelea sepa que ese personaje lo mueve EL, no yo: cuando le toque el turno se le
		# pediran a el los botones (ver combat._begin_player_turn).
		var suyo: Combatant = Game.combatant_de_pj(doble)
		if suyo != null and p.has_method("marcar_dueno"):
			p.marcar_dueno(suyo, quien)
		var idx_al: int = p.indice_de_aliado(suyo)
		idxs.append(idx_al)
		# El conjuro que traia se siembra sobre SU doble. A partir de ahi lo lleva el flujo de turnos
		# de siempre: al llegarle el turno se le pedira a EL el disparo (o la frase por la que iba).
		var cast := (f as Dictionary).get("casteo", {}) as Dictionary
		if not cast.is_empty() and p.has_method("aplicar_casteo_entrante"):
			p.aplicar_casteo_entrante(idx_al, cast)
	if p.has_method("esperar_refuerzo"):
		p.esperar_refuerzo(false)
	if dobles.is_empty():
		# La pelea existe: lo que pasa es que NO CABE nadie mas. Decirlo tal cual; el mensaje de
		# "ya no esta disponible" mandaba a buscar un problema que no era.
		_union_denegada.rpc_id(quien, "La pelea está llena: no cabe nadie más.")
		return
	_dobles[quien] = dobles       # de quien es cada doble, para devolverle lo suyo al acabar
	if not _pelea_participantes.has(quien):
		_pelea_participantes.append(quien)
	# Los INDICES le dicen cual de sus personajes es cada aliado de la pantalla: es lo unico que
	# significa lo mismo en las dos maquinas (y lo que necesita para saber a quien mover).
	_union_ok.rpc_id(quien, _pelea_id, p.roster_para_espejo(), idxs)


@rpc("any_peer", "call_remote", "reliable")
func _union_denegada(motivo: String = "Esa pelea ya no está disponible.") -> void:
	# El conjuro que mande con la ficha vuelve a su sitio. NO es opcional: para mandarlo ya le corte
	# el canto al jugador (ver solicitar_unirse), asi que sin esto el hechizo —y su maná— se pierden
	# en silencio. Con la nota de vuelta, el camino de siempre le devuelve el maná a los 5 s.
	Game.devolver_casteo_en_vuelo()
	# Y la lista de a quien mande, que si no se queda de una union que no llego a existir: un lote de
	# desgaste rezagado se buscaria el uid ahi dentro y podria colarse (ver _devolver_desgaste).
	_mis_en_pelea.clear()
	# El motivo lo manda el anfitrion: "no existe" y "esta llena" son cosas distintas y el jugador
	# necesita saber cual de las dos, o se pone a recolocarse pensando que apunta mal.
	_toast(motivo)


# Corre en EL QUE SE UNE: abre su pantalla en espejo.
# 'idxs' son los huecos de la fila de aliados que han tocado a MIS personajes, en el mismo orden en
# que mande las fichas. Con ellos se sabe a quien muevo yo cuando el anfitrion pide una accion.
@rpc("any_peer", "call_remote", "reliable")
func _union_ok(id: int, roster: Dictionary, idxs: Array) -> void:
	if Game.combate_activo() or ocupado_en_pelea():
		return
	if Game.abrir_combate_espejo(roster) == null:
		return
	# El conjuro que mande con la ficha ya esta sembrado en mi doble, alli: aqui no vuelve.
	Game.soltar_casteo_en_vuelo()
	_pelea_sigo = id
	_pelea_anfitrion = multiplayer.get_remote_sender_id()
	_mis_huecos.clear()
	for i in mini(idxs.size(), _mis_en_pelea.size()):
		_mis_huecos[int(idxs[i])] = _mis_en_pelea[i]


# ESPEJO: de quien es el hueco 'idx' de la fila de aliados, si es MIO (null si es de otro). Lo usa
# la pantalla para rellenar el maniqui con las habilidades y hechizos de ESE personaje.
func mi_pj_en_pelea(idx: int) -> PersonajeData:
	return _mis_huecos.get(idx)


# --- INSTANTANEAS (anfitrion -> espejos) -----------------------------------------------------

# La llama el combate cada vez que cambia algo que se ve. Va FIABLE: sale solo cuando cambia algo
# (no por frame), asi que garantizar la entrega es barato y evita que se pierda un avance o el "fin".
# Antes iba unreliable y una pelea larga la hacia pasar de la MTU -> se descartaba y el espejo se
# congelaba (el log ya va recortado a la cola, ver combat.instantanea). La barra de ATB sigue aparte.
func difundir_instantanea(snap: Dictionary) -> void:
	if not Net.activo or _pelea_id == 0 or _pelea_participantes.is_empty():
		return
	for p in _pelea_participantes:
		_instantanea.rpc_id(p, snap)


# LA BARRA DE ACCION. Va aparte de la instantanea y a ~20 Hz porque es lo unico que se mueve de
# forma CONTINUA: metida en la instantanea (que solo sale cuando cambia algo) la barra del espejo
# iria a saltos, y mandada como fiable seria trafico tonto. Mismo trato que las posiciones de los
# enemigos: unreliable_ordered y a correr.
func difundir_atb(ratios: PackedFloat32Array) -> void:
	if not Net.activo or _pelea_id == 0 or _pelea_participantes.is_empty():
		return
	for p in _pelea_participantes:
		_atb.rpc_id(p, ratios)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _atb(ratios: PackedFloat32Array) -> void:
	if _pelea_sigo == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_atb"):
		p.aplicar_atb(ratios)


# LOS GOLPES, para que el espejo pueda REPRODUCIRLOS (la embestida de la tarjeta y los numeros de
# daño). Sin esto el compañero veria las vidas bajar de golpe: los combatientes de su pantalla son
# maniquis y no resuelven nada. Sale UN paquete por accion, con 4 enteros por golpe.
#
# Va unreliable_ordered como el ATB, y a proposito: es puramente cosmetico. Perder uno significa
# ver un turno sin animacion, mientras que mandarlo fiable lo pondria a competir con la instantanea
# -que es la que lleva los numeros de verdad- por el mismo ancho de banda.
func difundir_impactos(datos: PackedInt32Array) -> void:
	if not Net.activo or _pelea_id == 0 or _pelea_participantes.is_empty():
		return
	for p in _pelea_participantes:
		_impactos.rpc_id(p, datos)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _impactos(datos: PackedInt32Array) -> void:
	if _pelea_sigo == 0:
		return
	var p: Node = _pantalla_combate()
	# El has_method NO es paranoia: un compañero con una version anterior no tiene aplicar_impactos,
	# y asi el paquete se le cae en silencio en vez de reventarle la pelea.
	if p != null and p.has_method("aplicar_impactos"):
		p.aplicar_impactos(datos)


@rpc("any_peer", "call_remote", "reliable")
func _instantanea(snap: Dictionary) -> void:
	if _pelea_sigo == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_instantanea"):
		p.aplicar_instantanea(snap)


# --- ROSTER (altas de combatiente) -----------------------------------------------------------
#
# La instantanea solo lleva NUMEROS y va sin garantia de entrega, asi que un combatiente NUEVO no
# puede viajar en ella: se manda el roster entero por canal FIABLE cada vez que entra alguien. Son
# eventos raros (un refuerzo, una invocacion, un compañero que se une), asi que pagar el roster
# completo -caras incluidas- sale mas barato que inventarse un formato de evento aparte.

func difundir_roster(roster: Dictionary) -> void:
	if not Net.activo or _pelea_id == 0 or _pelea_participantes.is_empty():
		return
	for p in _pelea_participantes:
		_roster_pelea.rpc_id(p, roster)


@rpc("any_peer", "call_remote", "reliable")
func _roster_pelea(roster: Dictionary) -> void:
	if _pelea_sigo == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_roster"):
		p.aplicar_roster(roster)


# ESPEJO: la revision no me cuadra (me he perdido un alta). Que me manden el roster otra vez.
func pedir_roster_pelea() -> void:
	if not Net.activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_pedir_roster_pelea.rpc_id(_pelea_anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_roster_pelea() -> void:
	if _pelea_id == 0:
		return
	var quien := multiplayer.get_remote_sender_id()
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("roster_para_espejo"):
		_roster_pelea.rpc_id(quien, p.roster_para_espejo())


# --- TURNOS (anfitrion <-> dueño del personaje) ----------------------------------------------

# El anfitrion pide la accion al dueño de ese personaje. Mientras, su pantalla espera: el ATB no
# corre (State.WAITING_PLAYER), asi que nadie pierde turnos por pensar.
func pedir_accion(peer: int, idx: int, seq: int = 0) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_turno.rpc_id(peer, idx, seq)


# 'seq' es el numero de peticion: viaja de ida y vuelta para que el anfitrion sepa distinguir la
# respuesta a ESTA peticion de una rezagada (ver combat.gd, _pet_seq).
@rpc("any_peer", "call_remote", "reliable")
func _tu_turno(idx: int, seq: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion():
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("turno_mio"):
		p.turno_mio(idx, seq)


# MAGIA (hito 5.4-C): recitar son varios turnos con su examen de frases, asi que no basta con
# mandar una accion suelta como en las habilidades — hay que enrutar CADA frase. El anfitrion
# sortea las opciones (lleva la pelea) y el dueño responde con la que eligio.
func pedir_frase(peer: int, idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_frase.rpc_id(peer, idx, opciones, nombre, largo, seq)


@rpc("any_peer", "call_remote", "reliable")
func _tu_frase(idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion():
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("recitar_frase"):
		p.recitar_frase(idx, opciones, nombre, largo, seq)


func pedir_disparo(peer: int, nombre: String, seq: int = 0) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_disparo.rpc_id(peer, nombre, seq)


@rpc("any_peer", "call_remote", "reliable")
func _tu_disparo(nombre: String, seq: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion():
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("lanzar_conjuro"):
		p.lanzar_conjuro(nombre, seq)


# ATAQUE DE CARGA listo: la orden de soltarlo (y el objetivo) es de SU dueño, no del anfitrion.
# Hermana de pedir_disparo, y por lo mismo: hay un turno cuya unica accion posible es esa.
func pedir_soltar(peer: int, nombre: String, seq: int = 0) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_carga.rpc_id(peer, nombre, seq)


@rpc("any_peer", "call_remote", "reliable")
func _tu_carga(nombre: String, seq: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion():
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("soltar_carga"):
		p.soltar_carga(nombre, seq)


# ¿Esto me lo manda de verdad quien lleva mi pelea? Las RPC de turno son "any_peer" (tienen que
# serlo: la pelea la ejecuta un jugador cualquiera, no el host de la red), asi que sin esta
# comprobacion cualquier peer podia ponerme los botones de un turno que no me toca.
func _lo_manda_el_anfitrion() -> bool:
	var quien := multiplayer.get_remote_sender_id()
	if _pelea_anfitrion != 0 and quien != _pelea_anfitrion:
		print("[multi] turno ignorado: lo manda el peer %d y mi pelea la lleva el %d" % [
			quien, _pelea_anfitrion])
		return false
	return true


# El dueño manda lo que ha elegido.
func enviar_accion(accion: Dictionary) -> void:
	if not Net.activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_accion_elegida.rpc_id(_pelea_anfitrion, accion)


@rpc("any_peer", "call_remote", "reliable")
func _accion_elegida(accion: Dictionary) -> void:
	if _pelea_id == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_accion_remota"):
		# QUIEN la manda va SIEMPRE con ella. Sin esto, el combate no podia distinguir la respuesta
		# del jugador al que le toca de la de otro (o de un eco tardio), y una respuesta rezagada
		# consumia el turno de quien no habia elegido nada. Ver combat.aplicar_accion_remota.
		p.aplicar_accion_remota(accion, multiplayer.get_remote_sender_id())


# El anfitrion cierra: los espejos se cierran con el.
@rpc("any_peer", "call_remote", "reliable")
func _fin_espejo() -> void:
	# LA LIMPIEZA VA SIEMPRE, aunque ya no espeje. Antes esto lo remataba cerrar_pelea() al recoger
	# la pantalla, pero desde salir_del_espejo hay un caso en el que la pantalla ya no esta y
	# _mis_en_pelea sigue en pie a proposito, esperando el desgaste: este aviso es justo el "ya no
	# viene nada mas". Sin esto _mis_en_pelea se quedaria lleno para siempre.
	#
	# El orden con _devolver_desgaste esta garantizado: los dos van por rpc_id fiable y por el mismo
	# canal, y el anfitrion manda SIEMPRE el lote antes que esto (ver sacar_de_la_pelea).
	_mis_en_pelea.clear()
	_mis_huecos.clear()
	_desgaste_pendiente = false
	if _pelea_sigo == 0:
		return
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("cerrar_espejo"):
		p.cerrar_espejo()
