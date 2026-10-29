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
# Lo de la pelea que EJECUTO vive en su PeleaViva (etapa 3, 22/10): estos nombres leen de la de la maquina.
var _pelea_id: int:                # la pelea que ejecuto YO (0 = ninguna)
	get: return Game.pelea.id
	set(v): Game.pelea.id = v
var _pelea_participantes: Array:   # peers que estan dentro de MI pelea (yo no me cuento)
	get: return Game.pelea.participantes
	set(v): Game.pelea.participantes = v
var _pelea_sigo: int = 0           # la pelea que estoy ESPEJANDO (0 = ninguna)
var _pelea_anfitrion: int = 0      # que peer ejecuta la pelea que espejo
var _pelea_next: int = 1           # contador de ids de pelea (por maquina; el id lleva el peer)
# Los DOBLES de los personajes de otros que pelean en MI pantalla: peer_id -> Array[PersonajeData],
# en el orden en que ese jugador me los mando (su formacion). Al cerrar, a cada uno se le devuelve
# lo que su doble vivio (vida, mana y excelia ganada).
var _dobles: Dictionary:
	get: return Game.pelea.dobles
	set(v): Game.pelea.dobles = v
# ESPEJO: los personajes MIOS que estan en la pelea que sigo.
var _mis_en_pelea: Array = []      # los que ofreci al unirme, en orden de formacion
# CUANDO TOCA MI ESPADAZO (etapa 3, paso 5): la pelea se pide al pulsar y la sala espera a este momento para montarla
# (ver golpe_hasta). msec del reloj del motor; en el pasado = no hay golpe en curso.
var _golpe_hasta_ms: int = 0
# Lo mas que la sala espera a un golpe (por si llega un numero raro).
const ESPERA_GOLPE_MAX := 1.0
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
# DE QUE PELEA espero todavia el cierre (_fin_espejo) y el lote de desgaste, cuando ya no la espejo.
# Sin esto, un cierre rezagado de una pelea VIEJA cerraba la pelea que tengo delante AHORA: _fin_espejo
# no miraba quien lo mandaba y apagaba el espejo que hubiera puesto. Ese era el bug del 19/09 ("me
# echaba de la pelea y mis personajes se quedaban dentro"): al rechazar una union tardia se le decia
# "sacame" al anfitrion viejo, su _fin_espejo llegaba mientras yo espejaba OTRA pelea y me la cerraba,
# dejando a mis personajes dentro de ella pidiendome turnos que ya no podia contestar.
var _cierre_esperado_de: int = 0
var _cierre_esperado_pelea: int = 0
# Bichos RESERVADOS: quien los esta peleando. Lo lleva el DUEÑO del piso, que es quien arbitra.
# Sin esto dos jugadores podrian coger el mismo bicho a la vez. Mismo espiritu que _vetas_ocupadas.
var _enem_ocupados: Dictionary = {}   # net_id -> peer_id que lo pelea (SOLO el dueño del piso)

# EN LA SALA (etapa 3, 22/10): las peleas que ejecuta, por id, cada una colgada del PisoVivo de su piso. Una pelea se
# nombra por su ID en toda la red (unirse, zonas, el pelea_de de cada enemigo, los mensajes al espejo): todas las de la
# sala llegan del mismo peer, asi que el peer ya no basta. Quien la ejecuta sale del propio id (ejecutor_de).
var _peleas: Dictionary = {}   # id -> PeleaViva
const ID_POR_PEER := 1000000
# Un enemigo reservado cuya pelea aun se esta montando (las fichas del que pega van de camino): quien viene a ayudar
# espera un poco en vez de rebotar.
const REINTENTOS_MONTANDO := 10
const ESPERA_MONTANDO := 0.15


@warning_ignore("integer_division")
static func ejecutor_de(pelea: int) -> int:
	return pelea / ID_POR_PEER if pelea > 0 else 0


# Al pulsar el ataque (remote_enemy.atacado_por_jugador): el golpe toca dentro de 'dur' segundos.
func golpe_hasta(dur: float) -> void:
	_golpe_hasta_ms = Time.get_ticks_msec() + int(maxf(dur, 0.0) * 1000.0)


# Lo que le queda a mi golpe, en segundos (0 = ya ha tocado, o no hay): viaja con las fichas.
func _espera_golpe() -> float:
	return clampf(float(_golpe_hasta_ms - Time.get_ticks_msec()) / 1000.0, 0.0, ESPERA_GOLPE_MAX)


# La pelea en la que estoy (la que ejecuto o la que espejo); 0 = ninguna.
func mi_pelea() -> int:
	return _pelea_id if _pelea_id != 0 else _pelea_sigo


# ¿Llevo yo los enemigos de verdad? Es la sala (la unica que hostea desde la etapa 2-bis). Antes se miraba si la
# maquina era dueña de su piso, que en la sala es siempre false: el enemigo que alcanzaba a un jugador rebotaba en
# vez de abrir la pelea, y las reservas no se soltaban al irse nadie.
func _soy_servidor() -> bool:
	return Net.es_host


# ¿La sala lleva alguna pelea en ese lugar? (un piso con pelea no se congela, ver Net.pisos.sala_reloj)
func hay_pelea_en(lugar: String) -> bool:
	for pe in _peleas.values():
		if is_instance_valid(pe) and is_instance_valid(pe.piso) and pe.piso.lugar == lugar:
			return true
	return false


# UNA PELEA DE LA SALA QUE SE VA SIN CERRARSE (su piso desmontado, o lo que sea): fuera de la lista y sus reservas
# sueltas. Sin esto quedaba apuntada para siempre con sus enemigos reservados. La llama PeleaViva al salir del arbol.
func olvidar_pelea(pe: PeleaViva) -> void:
	if pe.id == 0 or _peleas.get(pe.id) != pe:
		return
	push_warning("[pelea] la pelea %d se va sin cerrarse: la olvido y suelto sus reservas" % pe.id)
	_peleas.erase(pe.id)
	for n in pe.enemigos + pe.cola:
		if is_instance_valid(n) and n.has_meta("net_id"):
			_enem_ocupados.erase(int(n.get_meta("net_id")))
	pe.id = 0


# EL CADAVER QUE CEDE SU HUECO a un refuerzo o a una cria (Game.unir_enemigo_al_combate, dar_cuerpo_a_cria) sale de
# pe.enemigos, y cerrar_pelea solo suelta las reservas de los que siguen en la lista: la suya se quedaba para siempre
# (22/10, prueba_town_dos_peleas: "y no le quedan reservas (1)", solo cuando alguien entraba por la arena a mitad).
func soltar_reserva_del_cadaver(n) -> void:
	if Net.activo and _soy_servidor() and is_instance_valid(n) and n.has_meta("net_id"):
		_enem_ocupados.erase(int(n.get_meta("net_id")))


# La pelea de un humano EN LA SALA: la que le tiene dentro (participante, o con dobles suyos en cortesia). Fuera
# de la sala, la de la maquina.
func _pe_de_peer(peer: int) -> PeleaViva:
	if not Net.soy_sala:
		return Game.pelea
	for pe in _peleas.values():
		if is_instance_valid(pe) and ((pe as PeleaViva).participantes.has(peer) or (pe as PeleaViva).dobles.has(peer)):
			return pe
	return null


# EN LA SALA: ¿'peer' esta en una pelea, o tiene una montandose (bichos reservados a su nombre mientras termina el
# golpe)? Lo mira el viaje de piso (Net.pisos._conceder_piso). Un CADAVER reservado no cuenta: es una extraccion.
func peer_en_pelea(peer: int) -> bool:
	if _pe_de_peer(peer) != null:
		return true
	for id in _enem_ocupados:
		if int(_enem_ocupados[id]) != peer:
			continue
		var n = (Net.enemigos._enemigos.get(id, {}) as Dictionary).get("nodo")
		if n != null and is_instance_valid(n) and not n.esta_muerto():
			return true
	return false


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
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_encaminar_pelea(id, Net._mi_lugar, 1)
	else:
		_pedir_pelea.rpc_id(1, id, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_pelea(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	Medidor.marca("pelea", "sala_recibe")
	_encaminar_pelea(id, lugar, multiplayer.get_remote_sender_id())


# SOLO host: la resuelve la sala, que lleva todos los pisos (etapa 2).
func _encaminar_pelea(id: int, lugar: String, quien: int) -> void:
	if PisoVivo.dueno_de(lugar):
		_resolver_pelea(id, quien, lugar)
	else:
		_responder_pelea(quien, [], false)   # la sala no lleva ese piso: no hay pelea que dar


# SOLO el dueño: arbitra. Reserva el bicho y sus vecinos y responde con sus ids (vacio = ocupado).
# El grupo lo calcula vecinos(), el mismo que en solitario: es quien tiene los nodos reales y sabe
# quien esta al lado, con el tope MAX_COMBATIENTES.
func _resolver_pelea(id: int, quien: int, lugar: String, intento: int = 0) -> void:
	var e: Dictionary = Net.enemigos._enemigos.get(id, {})
	var nodo = e.get("nodo") if not e.is_empty() else null
	# ¿Ese bicho YA lo esta peleando alguien? Entonces la respuesta no es "ocupado", es una
	# INVITACION A UNIRSE a esa pelea (hito 5.4-C): es lo que espera el jugador cuando ve a su
	# compañero peleando y va a echar una mano.
	var pelea: int = _pelea_del_enemigo(id, nodo)
	if pelea > 0:
		var pe: PeleaViva = _peleas.get(pelea)
		# YA ES SUYA (12/10): el bicho le alcanzo mientras su espadazo terminaba y la pelea ya va de camino.
		if pe != null and pe.participantes.has(quien):
			return
		_responder_pelea(quien, [], false, pelea)
		return
	if pelea < 0:
		# RESERVADO Y MONTANDOSE (las fichas de quien le pego van de camino). Si es el mismo, ya es suya; si es otro,
		# se le contesta en cuanto exista la pelea, para que entre en ella.
		if -pelea == quien:
			return
		if intento < REINTENTOS_MONTANDO:
			get_tree().create_timer(ESPERA_MONTANDO, true).timeout.connect(
				_resolver_pelea.bind(id, quien, lugar, intento + 1))
			return
		_responder_pelea(quien, [], false)
		return
	_responder_pelea(quien, _reservar_grupo(nodo, id, quien), false)


# SOLO el dueño: ¿en QUE pelea esta metido este bicho? Su id (etapa 3); 0 = en ninguna; -peer = reservado para 'peer'
# y su pelea aun se esta montando.
#
# La reserva dice a nombre de quien se congelo. Sin reserva pero congelado es una pelea MIA (las
# propias no pasan por _enem_ocupados, las monta enemy._start_combat) -- salvo que ahora mismo yo solo
# este ESPEJANDO la de otro, y entonces la pelea es de ese otro. Antes se daba siempre por mia, y al que
# venia a ayudar se le mandaba a pedir sitio a alguien que no ejecutaba nada ("ya no esta disponible").
func _pelea_del_enemigo(id: int, nodo) -> int:
	if nodo != null and is_instance_valid(nodo):
		var pe: PeleaViva = PeleaViva.de_enemigo(nodo)
		if pe != null and pe.id != 0:
			return pe.id
		if nodo.has_method("esta_muerto") and nodo.esta_muerto():
			return 0
	var r: int = int(_enem_ocupados.get(id, 0))
	return -r if r != 0 else 0


# De quien es la pelea en la que esta este bicho, en CUALQUIER maquina: el dueño lo sabe por sus
# reservas y los demas por el tick (remote_enemy.pelea_de). 0 = suelto. Lo usan las lineas de vinculo y
# el unirse por contacto.
func pelea_de_enemigo(n) -> int:
	if not Net.activo or n == null or not is_instance_valid(n) or not n.has_meta("net_id"):
		return 0
	var id: int = int(n.get_meta("net_id"))
	if _soy_servidor() and Net.enemigos._enemigos.has(id):
		return _pelea_del_enemigo(id, n)
	return int(n.get("pelea_de")) if "pelea_de" in n else 0


# SOLO el dueño: reserva un bicho y a sus vecinos para la pelea de 'quien' y los congela. Devuelve
# los net_id reservados (vacio = no habia nada que dar). Extraido para que lo usen las DOS vias:
# la que pide el jugador al atacar, y la que EMPUJA el dueño cuando un bicho alcanza a alguien.
func _reservar_grupo(nodo, id: int, quien: int) -> Array:
	var ids: Array = []
	if nodo == null or not is_instance_valid(nodo) or _enem_ocupados.has(id):
		return ids
	# El que acaba de salir de una pelea y esta en sus 3 s quieto se puede volver a pelear (antes contestaba
	# "ese enemigo ya esta peleando con otro" a quien le pegaba, playtest 08/10).
	if nodo.has_method("soltar_congelado"):
		nodo.soltar_congelado()
	if nodo.esta_muerto() or nodo.get("_combat_triggered"):
		return ids
	for n in nodo.vecinos():
		if not is_instance_valid(n) or not n.has_meta("net_id"):
			continue
		var nid: int = n.get_meta("net_id")
		if _enem_ocupados.has(nid):
			continue
		if n.has_meta("id_pelea"):
			_olvidar_guardada_de(n)   # era de una pelea guardada cuyo dueño no ha vuelto: le han pegado, se olvida
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
func empujar_pelea(nodo: Node, peer: int, emboscada: bool = true) -> bool:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return false
	if nodo == null or not nodo.has_meta("net_id") or not (_soy_servidor() and PisoVivo.dueno_del_nodo(nodo)):
		return false
	# YA NO ESTA EN ESTE PISO (va de camino a otro, o se ha ido): su avatar puede seguir un momento aqui, pero
	# la pelea no es suya. Sin esto se le reservaba el grupo y la pelea acababa rebotando por ahi.
	var lugar_suyo: String = str(Net._peers.get(peer, {}).get("lugar", Net._mi_lugar))
	if not PisoVivo.lleva(lugar_suyo):
		return false
	var id: int = nodo.get_meta("net_id")
	var ids: Array = _reservar_grupo(nodo, id, peer)
	if ids.is_empty():
		return false
	# YA ESTA PELEANDO EN LA SALA: los bichos que le alcanzan entran en SU pelea, sin ida y vuelta.
	var ya: PeleaViva = _pe_de_peer(peer) if Net.soy_sala else null
	if ya != null and ya.id != 0:
		_meter_reservados(ids, ya)
		return true
	# EMBOSCADA SOLO SI LO ES (12/10): si el jugador ya le estaba soltando un espadazo (enemy._es_contra mira su
	# remote_player.quiere_atacarme), la pelea la ha empezado el. Antes iba siempre a true.
	_responder_pelea(peer, ids, emboscada)
	return true


# La respuesta vuelve al destinatario. El dueño es siempre la sala (etapa 2), que es tambien la que ejecuta
# la pelea (ver _entregar_pelea).
func _responder_pelea(quien: int, ids: Array, emboscada: bool, anfitrion: int = 0) -> void:
	if Net.es_host:
		_entregar_pelea(quien, ids, emboscada, anfitrion)


# SOLO host: la pelea ya reservada llega a su destinatario. La ejecuta la sala (etapa 3): se le dice al jugador que le
# mande sus fichas a ella.
func _entregar_pelea(para: int, ids: Array, emboscada: bool, anfitrion: int, _desde_ms: int = -1) -> void:
	# LA EJECUTA LA SALA (etapa 3, 22/10): el jugador le manda sus fichas a ella (_abre_mi_pelea) y la ve en espejo.
	if not ids.is_empty() and anfitrion == 0 and Net.soy_sala and para != 1:
		_pelea_en_ejecutor.rpc_id(para, ids, emboscada, 1)
		return
	if para == 1:
		_pelea_resuelta(ids, emboscada, anfitrion)
	else:
		_pelea_resuelta.rpc_id(para, ids, emboscada, anfitrion)


# Corre en EL QUE PELEA: monta el combate contra sus propios espejos, o los METE en la pelea que ya
# tenga abierta (hito 5.4). Se les puede pasar tal cual a Game._abrir_pelea porque exponen
# data/current_t/hp_restante y saben morir().
@rpc("any_peer", "call_remote", "reliable")
func _pelea_resuelta(ids: Array, emboscada: bool = false, anfitrion: int = 0) -> void:
	_llega_pelea(ids, emboscada, anfitrion, 0)


# --- LA PELEA LA EJECUTA LA SALA (etapa 3) ---------------------------------------------------
#
# El que ataca (o al que embisten) le manda sus fichas a la sala, que monta la pelea con los enemigos de verdad
# (_abre_en_la_sala) y se la abre en espejo. Hasta la etapa 3 lo hacia un TRABAJADOR DE PELEA (un Godot sin ventana
# por pelea, trabajadores.gd, ya borrado).

# EL HUMANO QUE ABRIO LA PELEA: el ruido de la pelea es suyo (el brote sale delante de el, no de cualquiera).
func causante_alboroto(pe: PeleaViva = null) -> int:
	if pe == null:
		pe = Game.pelea
	return pe.humano if Net.activo and Net.soy_sala else 0


# Corre en EL QUE ATACA (o al que embisten): el host le dice que su pelea la ejecuta 'ejecutor'.
@rpc("any_peer", "call_remote", "reliable")
func _pelea_en_ejecutor(ids: Array, emboscada: bool, ejecutor: int) -> void:
	Medidor.marca("pelea", "cliente_ejecutor")
	_llega_pelea(ids, emboscada, 0, ejecutor)


# Corre en LA SALA: llegan las fichas del que pelea (ver _abre_en_la_sala).
@rpc("any_peer", "call_remote", "reliable")
func _abre_mi_pelea(ids: Array, emboscada: bool, z: Array, vel: float = 1.0, espera: float = 0.0) -> void:
	var fichas: Array = Net.partida.fichas_de_red(Net.unzip_array(z))
	Medidor.marca("pelea", "sala_abre")
	var quien := multiplayer.get_remote_sender_id()
	if not Net.soy_sala:
		return   # solo la sala ejecuta peleas
	# AL TOCAR SU GOLPE (etapa 3, paso 5): la pidio al pulsar; se monta cuando su espadazo llega, ni antes (su
	# pantalla se abriria a mitad de la animacion) ni despues (es lo que se ahorra).
	if espera > 0.0:
		await get_tree().create_timer(minf(espera, ESPERA_GOLPE_MAX), true).timeout
	_abre_en_la_sala(quien, ids, emboscada, fichas, vel)


# EN LA SALA (etapa 3): llegan las fichas de quien pega (o de a quien embisten). Se monta una pelea NUEVA con los
# enemigos de verdad que sigan reservados a su nombre, colgada del piso de esos enemigos, y se le abre el espejo.
func _abre_en_la_sala(quien: int, ids: Array, emboscada: bool, fichas: Array, vel: float) -> void:
	var nodos: Array = []
	var mios: Array = []
	for i in ids:
		if int(_enem_ocupados.get(int(i), 0)) != quien:
			continue   # ya no es suyo (se solto, o lo cogio otra pelea)
		var n = _nodo_de_id(int(i))
		if n != null and is_instance_valid(n) and not n.esta_muerto():
			nodos.append(n)
			mios.append(int(i))
	var sobran: Array = []
	for i in ids:
		if not mios.has(int(i)):
			sobran.append(int(i))
	_soltar_reservados(sobran, quien)
	# YA ESTA EN UNA PELEA (le han metido por otro lado mientras llegaban sus fichas): los bichos entran en ella.
	var ya: PeleaViva = _pe_de_peer(quien)
	if ya != null and ya.id != 0:
		_meter_reservados(mios, ya)
		return
	var piso: PisoVivo = PisoVivo.de(nodos[0]) if not nodos.is_empty() else null
	if piso == null or fichas.is_empty():
		_soltar_reservados(mios, quien)
		_union_denegada.rpc_id(quien, "Ese enemigo ya no está.")
		return
	var pe := PeleaViva.new()
	pe.name = "Pelea"
	pe.humano = quien
	piso.add_child(pe, true)
	var huecos: Dictionary = Game.abrir_pelea_de_fichas(nodos, emboscada, [{"peer": quien, "fichas": fichas}], pe)
	var p: Node = _pantalla_combate(pe)
	if huecos.is_empty() or p == null or pe.id == 0:
		print("[pelea] la sala no ha podido montar la pelea de %d (%d bichos)" % [quien, nodos.size()])
		pe.queue_free()
		_soltar_reservados(mios, quien)
		_union_denegada.rpc_id(quien, "Esa pelea no se ha podido abrir.")
		return
	_peleas[pe.id] = pe
	print("[pelea] la sala abre la pelea %d de %d en %s: %d bichos, huecos %s (%d peleas)" % [
		pe.id, quien, piso.lugar, nodos.size(), str(huecos[quien]), _peleas.size()])
	p._aplicar_velocidad(vel)
	olvidar_filas(pe, quien)
	_union_ok.rpc_id(quien, pe.id, Net.zip(p.roster_para_espejo()), huecos[quien])


# Bichos ya reservados que entran en una pelea de la sala en marcha. El que no entre (se cierra) se suelta.
func _meter_reservados(ids: Array, pe: PeleaViva) -> void:
	for i in ids:
		var n = _nodo_de_id(int(i))
		if n == null or not is_instance_valid(n) or n.esta_muerto():
			_enem_ocupados.erase(int(i))
			continue
		if not Game.unir_enemigo_al_combate(n, -1, pe):
			_soltar_reservados([i], int(_enem_ocupados.get(int(i), 0)))


# Reservas que no llegan a ninguna pelea: fuera la reserva y el bicho vuelve a su vida (si no esta ya en una pelea).
func _soltar_reservados(ids: Array, quien: int) -> void:
	for i in ids:
		if int(_enem_ocupados.get(int(i), 0)) != quien:
			continue
		_enem_ocupados.erase(int(i))
		var n = _nodo_de_id(int(i))
		if n != null and is_instance_valid(n) and not n.esta_muerto() and PeleaViva.de_enemigo(n) == null:
			n.reanudar_tras_combate(-1.0)


# LA PELEA SIN NADIE DELANTE SE CIERRA SOLA. La sala no pulsa Continuar: la cierra cuando ya han salido todos los
# humanos de su espejo (cada uno se lleva lo suyo al salir, ver sacar_de_la_pelea), o pasado CIERRE_MAX por si alguno
# no pulsa nunca.
const CIERRE_MAX := 60.0

func _process(delta: float) -> void:
	_vencer_cortesia()
	if Net.soy_sala:
		for pe in _peleas.values().duplicate():
			if is_instance_valid(pe):
				_cierre_de(pe, delta)
		return


func _cierre_de(pe: PeleaViva, delta: float) -> void:
	var p: Node = _pantalla_combate(pe)
	if p == null or not p.has_method("acabada") or not p.acabada():
		pe.t_cierre = 0.0
		return
	pe.t_cierre += delta
	if pe.participantes.is_empty() or pe.t_cierre >= CIERRE_MAX:
		print("[pelea] cierro la pelea %d acabada (%d humanos dentro, %.0f s)" % [pe.id, pe.participantes.size(), pe.t_cierre])
		pe.t_cierre = 0.0
		p._on_continue_pressed()


# A quien le he mandado mis fichas (la sala) y todavia no me ha contestado (0 = a nadie).
var _fichas_mandadas_a: int = 0
var _fichas_emboscada: bool = false   # si la ultima pelea que pedi fue una emboscada (la miran las pruebas)

func _llega_pelea(ids: Array, emboscada: bool, anfitrion: int, ejecutor: int) -> void:
	if ids.is_empty():
		# Ese bicho ya lo pelea alguien: en vez de rebotar, ME UNO A SU PELEA. Es lo que espera el
		# jugador al ver a su compañero peleando e ir a ayudarle. ('anfitrion' es el id de esa pelea.)
		if anfitrion != 0:
			solicitar_unirse(anfitrion)
		else:
			# NO HAY PELEA QUE DAR (etapa 3, paso 5): el golpe se queda en golpe, SIN aviso. La peticion sale al
			# pulsar, asi que esto llega con el espadazo aun en el aire; antes salia "Ese enemigo ya esta peleando
			# con otro" despues de pegar, que es justo lo que no se quiere.
			print("[pelea] no hay pelea que dar con ese enemigo: el golpe se queda en golpe")
			Game.soltar_entrando_en_pelea()
		return
	# ESTOY ESPEJANDO una pelea: estos bichos me han alcanzado a MI, pero la pelea la ejecuta la sala y los
	# combatientes son suyos. Se los paso para que los meta en ella. Asi un enemigo puede entrar por CUALQUIERA de
	# los que estan dentro, no solo por quien la abrio.
	if espejando():
		if _pelea_anfitrion != 0:
			_refuerzos_para_mi_pelea.rpc_id(_pelea_anfitrion, ids)
		return
	# ME LA EJECUTA LA SALA: le mando mis fichas y espero su espejo. Si ahora no puedo pelear (un minijuego delante,
	# o esperando lo de la pelea anterior), los bichos vuelven a su dueño como siempre.
	if ejecutor != 0:
		# OTRA VEZ (la primera no pudo): el conjuro que viajaba con las fichas de antes vuelve a su nota para salir
		# otra vez con estas.
		if _fichas_mandadas_a != 0:
			Game.devolver_casteo_en_vuelo()
		if Game._active_layer != null or ocupado_en_pelea():
			_devolver_bichos(ids)
			return
		# QUIETO YA (playtest 08/10): hasta que la sala conteste pasan varios saltos de red, y te daba tiempo a
		# irte andando; luego la pelea te pillaba fuera de la zona. Se suelta solo al abrirse la pantalla.
		Game.marcar_entrando_en_pelea()
		_avisar_impacto_de(ids)   # y el compañero que este cerca, tambien (ver Game.impacto_ajeno)
		_fichas_mandadas_a = ejecutor
		_fichas_emboscada = emboscada
		_abre_mi_pelea.rpc_id(ejecutor, ids, emboscada, Net.zip(Net.partida.fichas_a_red(_fichas_de_mi_grupo())), Game.velocidad_combate, _espera_golpe())
		return
	# NINGUNA PELEA EN EL PC DE UN JUGADOR (etapa 3, paso 4): todas las ejecuta la sala, y aqui solo hay espejos.
	# Lo que llegue sin a quien mandarle las fichas vuelve al piso (y el conjuro que viajaba, a su nota).
	if _fichas_mandadas_a != 0:
		_fichas_mandadas_a = 0
		_mis_en_pelea.clear()
		Game.devolver_casteo_en_vuelo()
	Game.soltar_entrando_en_pelea()
	_devolver_bichos(ids)


# EL IMPACTO, a los de mi piso (11/10): donde esta el primer bicho de la pelea, o yo si no lo tengo aqui.
func _avisar_impacto_de(ids: Array) -> void:
	var pos := Vector2.INF
	for i in ids:
		var n = _nodo_de_id(int(i))
		if n == null or not is_instance_valid(n):
			n = Net.enemigos._enem_nodos.get(int(i))
		if n != null and is_instance_valid(n) and n is Node2D:
			pos = (n as Node2D).global_position
			break
	if pos == Vector2.INF:
		var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if yo == null:
			return
		pos = yo.global_position
	Game.avisar_impacto(pos)


# --- REFUERZOS QUE ALCANZAN A UN ESPEJO (hito 5.4-C) -----------------------------------------
#
# Corre en EL ANFITRION: unos bichos han alcanzado a alguien que esta en MI pelea, y me los pasa
# para que entren en ella (ver _pelea_resuelta). Los nodos que necesito son los MIOS: si simulo el
# piso son los de verdad, y si no, mis espejos.
@rpc("any_peer", "call_remote", "reliable")
func _refuerzos_para_mi_pelea(ids: Array) -> void:
	var pe: PeleaViva = _pe_de_peer(multiplayer.get_remote_sender_id())
	if pe == null or pe.id == 0 or not Game.combate_activo(pe):
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
		if Game.unir_enemigo_al_combate(n, -1, pe):
			entran.append(int(i))
		else:
			_devolver_bichos([i])      # no cabia: que el dueño lo suelte, o se queda estatua
	if not entran.is_empty():
		# La reserva estaba a nombre del que fue alcanzado, no a mi nombre. Si a EL se le corta la
		# conexion, _soltar_reservas_de descongelaria bichos que yo estoy peleando: se apunta a mi.
		reasignar_reservas(entran)


# El nodo que YO tengo para un net_id: el de verdad si simulo el piso, mi espejo si no.
func _nodo_de_id(id: int):
	if _soy_servidor():
		var e: Dictionary = Net.enemigos._enemigos.get(id, {})
		return e.get("nodo") if not e.is_empty() else null
	return Net.enemigos._enem_nodos.get(id)


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
	if _soy_servidor():
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
	if PisoVivo.dueno_de(lugar):
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
	if PisoVivo.dueno_de(lugar):
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
	elif not (nodo.has_method("esta_muerto") and nodo.esta_muerto()):
		nodo.reanudar_tras_combate(hp)   # (09/10) a un cadaver devuelto no se le reanuda


# Quien simula ese lugar (0 = nadie). Solo el host lo sabe.
# Alguien se fue (o se le corto). Si tenia bichos RESERVADOS para su pelea, hay que soltarlos o se
# quedan congelados para siempre: es el bug de las estatuas, pero por red. Lo difunde el host y lo
# aplica cada dueño sobre los suyos.
@rpc("any_peer", "call_remote", "reliable")
func _soltar_reservas_de(quien: int) -> void:
	if not _soy_servidor():
		return
	for id in _enem_ocupados.keys():
		if _enem_ocupados[id] != quien:
			continue
		# EN UNA PELEA DE LA SALA no se toca: la pelea sigue sin el (cortesia, o sus personajes salen).
		var en: Dictionary = Net.enemigos._enemigos.get(id, {})
		if not en.is_empty() and is_instance_valid(en.get("nodo")) and PeleaViva.de_enemigo(en.get("nodo")) != null:
			continue
		_enem_ocupados.erase(id)
		Net.extraccion._borrar_extrayendo(id)   # si era un cuerpo a medio extraer, vuelve a estar libre
		var e: Dictionary = Net.enemigos._enemigos.get(id, {})
		var nodo = e.get("nodo") if not e.is_empty() else null
		if nodo != null and is_instance_valid(nodo) and not nodo.esta_muerto():
			nodo.reanudar_tras_combate(-1.0)   # vuelve a la vida normal, sin heridas nuevas


# --- PELEAS COMPARTIDAS: unirse a la pelea de otro (hito 5.4-C) -------------------------------
#
# Quien abre una pelea la EJECUTA. Los demas se unen: reciben el roster, abren la pantalla en
# ESPEJO y a partir de ahi les llegan instantaneas. Cuando le toca el turno a un personaje SUYO,
# el anfitrion le pide la accion; el la elige en su pantalla y vuelve. Asi el ATB, los dados y la
# resolucion pasan en UN solo sitio y no hay dos verdades.

# La pantalla de combate que tengo delante (la mia o el espejo), o null.
func _pantalla_combate(pe: PeleaViva = null) -> Node:
	if pe == null:
		pe = Game.pelea
	if not is_instance_valid(pe.capa) or pe.capa.get_child_count() == 0:
		return null
	return pe.capa.get_child(0)


# Lo llama Game al abrir un combate en multi: esta pelea pasa a existir en la red.
func registrar_pelea(pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	pe.id = multiplayer.get_unique_id() * 1000000 + _pelea_next
	_pelea_next += 1
	pe.participantes.clear()


# --- QUIEN ESTA EN LA PELEA -------------------------------------------------------------------
# (El TRASPASO de la pelea a otro humano se fue en la etapa 3: la ejecuta la sala, que no se va a media pelea.)

# El nodo que YO tengo para un net_id (publico: lo usa Game al recoger una pelea).
func nodo_de_id(id: int):
	return _nodo_de_id(id)


# ¿Ese peer sigue dentro de la pelea que ejecuto yo? Si no, no tiene sentido pedirle su turno.
func esta_en_mi_pelea(peer: int, pe: PeleaViva = null) -> bool:
	if pe == null:
		pe = Game.pelea
	return pe.participantes.has(peer)


# SE ME HA CAIDO QUIEN LLEVA la pelea que espejo (la sala): no dejar la pantalla colgada esperando turnos que no
# van a llegar: se cierra y vuelves al mapa. Lo que vivieron tus personajes en esa pelea se pierde.
func _anfitrion_perdido() -> void:
	if _pelea_sigo == 0:
		return
	print("[espejo] se ha caido quien lleva mi pelea: cierro el espejo")
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()
	_desgaste_pendiente = false   # se fue con el: no hay lote que esperar
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("cerrar_espejo"):
		p.cerrar_espejo()
	Net._toast("Tu compañero se ha desconectado: la pelea se ha deshecho.")


# SE VA UNO SOLO (huida individual): la pelea SIGUE para los demas. Se le devuelve lo que vivieron
# sus dobles y se le cierra su espejo, y deja de recibir instantaneas. Es cerrar_pelea, pero para
# un participante en vez de para todos.
func sacar_de_la_pelea(peer: int, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
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
	if pe.id == 0:
		_fin_espejo.rpc_id(peer, 0)
		pe.participantes.erase(peer)
		return
	# SUS PERSONAJES SALEN DE MI PANTALLA. Es la otra mitad de sacarle, y faltaba: cerrandole solo el
	# espejo, sus combatientes se quedaban en la pelea con la barra corriendo y, al tocarles el turno,
	# se le pedia la accion a un peer que ya no tiene pantalla -> la pelea se quedaba pidiendosela cada
	# 4 s para siempre, y quien entrara despues se sentaba a esperar un turno que no iba a llegar.
	# Retirar no toca vida ni mana, asi que el lote de desgaste de aqui abajo sigue saliendo bien.
	_retirar_sus_combatientes(peer, pe)
	# SE VA DE UNA PELEA YA ACABADA CON TODO SU GRUPO CAIDO: eso es morir, no irse. Cerrando el espejo
	# antes que quien la ejecuta, se le devolvia el desgaste (a 0 de vida) y se libraba del castigo; y
	# en la pelea de la sala SIEMPRE se sale asi (la sala no pulsa Continuar).
	var p: Node = _pantalla_combate(pe)
	if pe.dobles.has(peer) and p != null and p.has_method("acabada") and p.acabada():
		var caidos := true
		for doble in pe.dobles[peer]:
			var c: Combatant = Game.combatant_de_pj(doble)
			if c != null and c.current_hp > 0.0:
				caidos = false
		if caidos:
			pe.dobles.erase(peer)
			_moriste.rpc_id(peer, pe.id)
			pe.participantes.erase(peer)
			return
	if pe.dobles.has(peer):
		var lote: Array = []
		for doble in pe.dobles[peer]:
			# A mitad de pelea la vida y el mana viven en el COMBATIENTE: hay que bajarlos a la
			# ficha antes de mandarlos, o se iria con los que entro.
			Game.volcar_desgaste_en_ficha(doble)
			lote.append(Net.partida.desgaste_a_dict(doble))
		_devolver_desgaste.rpc_id(peer, lote, pe.id)
		pe.dobles.erase(peer)
	_fin_espejo.rpc_id(peer, pe.id)
	pe.participantes.erase(peer)


# Sus combatientes fuera de MI pantalla (los de un peer al que estoy sacando de la pelea). Va por el
# mismo camino que usa la huida de un jugador, asi que la pelea se reordena igual: si el turno lo tenia
# uno de los suyos pasa a otro, y si no queda nadie de pie la pelea se cierra.
func _retirar_sus_combatientes(peer: int, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	var p: Node = _pantalla_combate(pe)
	if p == null or not p.has_method("sacar_a") or not p.has_method("tiene_en_pie_a"):
		return
	if not p.tiene_en_pie_a(peer):
		return   # ya estaban fuera (la huida individual los retira ella misma antes de llamar aqui)
	var quien: String = String((Net._peers.get(peer, {}) as Dictionary).get("nombre", "Tu compañero"))
	p.sacar_a(peer, "%s deja la pelea y sus personajes salen con él." % quien)


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
		_salgo_de_la_pelea.rpc_id(_pelea_anfitrion, _pelea_sigo)
		_desgaste_pendiente = true
		_desgaste_limite_ms = Time.get_ticks_msec() + DESGASTE_ESPERA_MAX_MS
		# De EL, y de nadie mas, espero el lote y el cierre: si para entonces ya estoy en otra pelea,
		# es lo unico que distingue su respuesta de la de la pelea nueva.
		_cierre_esperado_de = _pelea_anfitrion
		_cierre_esperado_pelea = _pelea_sigo   # y de ESA pelea: en la sala todas llegan del mismo peer
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_huecos.clear()
	# _mis_en_pelea NO se toca: es donde _devolver_desgaste busca por uid. Lo suelta _fin_espejo.


# Corre en EL ANFITRION: uno de los que estaban en mi pelea ha cerrado su pantalla por su cuenta.
# Es exactamente una huida individual, salvo que la pelea ya ha terminado: se le devuelve lo suyo
# y se le cierra el espejo.
@rpc("any_peer", "call_remote", "reliable")
func _salgo_de_la_pelea(pelea: int = 0) -> void:
	var quien := multiplayer.get_remote_sender_id()
	var pe: PeleaViva = _peleas.get(pelea) if Net.soy_sala and _peleas.has(pelea) else _pe_de_peer(quien)
	if pe == null:
		_fin_espejo.rpc_id(quien, pelea)   # en la sala y esa pelea ya no esta: que no se quede esperando
		return
	sacar_de_la_pelea(quien, pe)


# 'derrotados' = peers cuyo grupo ENTERO cayo: en vez de devolverles el desgaste y cerrarles el
# espejo, se les manda al pueblo con la penalizacion (_moriste corre morir_jugador en SU maquina).
func cerrar_pelea(derrotados: Array = [], pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if pe.id != 0:
		for caido in _caidos.keys():
			if _caidos[caido].get("pe", pe) != pe:
				continue   # de otra pelea de la sala
			_desgaste_a_la_sala(caido, String(_caidos[caido].get("ident", "")), pe)
			_caidos.erase(caido)
		for p in pe.participantes:
			if derrotados.has(p):
				# Su grupo murio: al pueblo. morir_jugador ya le reinicia las fichas, asi que NO se
				# le devuelve desgaste; _moriste tambien le cierra el espejo.
				_moriste.rpc_id(p, pe.id)
				continue
			# A cada uno lo SUYO: lo que sus dobles han vivido en mi pantalla (vida, mana y la
			# excelia ganada) vuelve a sus personajes de verdad. Va ANTES de cerrarle el espejo.
			if pe.dobles.has(p):
				var lote: Array = []
				for doble in pe.dobles[p]:
					lote.append(Net.partida.desgaste_a_dict(doble))
				_devolver_desgaste.rpc_id(p, lote, pe.id)
			_fin_espejo.rpc_id(p, pe.id)
		pe.participantes.clear()
		pe.dobles.clear()
		if Net.soy_sala:
			# LA SALA suelta sus reservas (sus bichos de verdad vuelven a su vida en el cierre de Game) y la olvida.
			for n in pe.enemigos + pe.cola:
				if is_instance_valid(n) and n.has_meta("net_id"):
					_enem_ocupados.erase(int(n.get_meta("net_id")))
			_peleas.erase(pe.id)
			pe.queue_free()
		pe.id = 0
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()


# Corre en EL QUE SE UNIO y cuyo grupo cayo entero: vuelve al pueblo con la penalizacion, igual que
# morir en solitario (decision del usuario: en multi los jugadores mueren de verdad, no se quedan a
# 1 de vida). Primero cierra su espejo (recoge la capa y despausa) y luego morir_jugador cambia de
# escena al pueblo. Sus personajes viven en SU maquina, asi que la muerte se resuelve aqui.
@rpc("any_peer", "call_remote", "reliable")
func _moriste(pelea: int = 0) -> void:
	# Y DE LA PELEA QUE ESPEJO, no de una vieja: mismo motivo que _fin_espejo, pero peor, porque esto
	# manda al jugador al pueblo con la penalizacion. Un "has muerto" rezagado de otra pelea te mataba
	# en la que estabas ganando.
	var quien := multiplayer.get_remote_sender_id()
	if _pelea_sigo != 0 and not _es_de_la_que_sigo(pelea, quien):
		print("[espejo] muerte rezagada (peer %d, pelea %d): sigo en la pelea %d, la ignoro" % [
			quien, pelea, _pelea_sigo])
		return
	_cierre_esperado_de = 0
	_cierre_esperado_pelea = 0
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
#   - el TRASPASO de pelea (el de antes de la sala) añadia los dobles con un `if` sin `break`, asi que
#     si uno no cabe la lista del anfitrion queda CORRIDA respecto a mi formacion;
#   - _mis_en_pelea puede haber cambiado de orden (cambiar de lider, recolocar el equipo) o ser de
#     una union anterior, y aqui no se validaba ninguna id de pelea.
# Como aplicar_desgaste ASIGNA, un desfase de un puesto copiaba al mago encima del tanque: su
# excelia, su nivel, sus cinco stats y sus contadores. El uid lo hace imposible.
@rpc("any_peer", "call_remote", "reliable")
func _devolver_desgaste(lote: Array, pelea: int = 0) -> void:
	# Y SOLO DE UNA PELEA MIA: la que espejo ahora, o la que acabo de dejar y cuyo lote espero. Un lote
	# de una pelea vieja (una union rechazada, un anfitrion que contesta tarde) trae la vida y el mana
	# de ENTONCES, y aplicar_desgaste ASIGNA: le borraria a la ficha lo que esta viviendo ahora mismo
	# en la pelea de verdad. El uid ya no basta para distinguirlos, porque son los mismos personajes.
	var quien := multiplayer.get_remote_sender_id()
	var de_la_mia: bool = _pelea_sigo != 0 and _es_de_la_que_sigo(pelea, quien)
	if not de_la_mia and not _es_del_cierre_esperado(pelea, quien):
		print("[espejo] desgaste rezagado (peer %d, pelea %d): no es de mi pelea, lo descarto" % [quien, pelea])
		return
	if not de_la_mia:
		_cierre_esperado_de = 0
		_cierre_esperado_pelea = 0
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
		Net._toast("Se perdio lo de tu ultima pelea, pero ya puedes volver a pelear.")
		return false
	return true


# Le he pegado a un bicho que YA esta en una pelea: quiero entrar a ayudar. Quien sabe de quien es
# esa pelea es el DUEÑO del piso (lleva las reservas), asi que si no lo soy, se lo pregunto por la
# via de siempre —solicitar_pelea ya devuelve el anfitrion al que unirse—.
func unirme_a_la_pelea_de(id: int) -> void:
	if not Net.activo:
		return
	Medidor.marca("pelea_compa", "pido_unirme")
	# Ya estoy en una pelea (la mia o espejando otra): una pantalla de combate por maquina.
	if Game.combate_activo() or ocupado_en_pelea():
		return
	if not _soy_servidor():
		# Si el tick ya me ha dicho en que pelea esta, voy directo; si no (o aun se esta montando: id negativo), se lo
		# pregunto a la sala, que lleva las reservas. Si el dato del tick se ha quedado viejo, _pedir_unirme lo rechaza
		# con su aviso, que es lo mismo que pasaria preguntando.
		var n = Net.enemigos._enem_nodos.get(id)
		var directo: int = int(n.pelea_de) if n != null and is_instance_valid(n) else 0
		if directo > 0 and directo != mi_pelea():
			solicitar_unirse(directo)
		else:
			solicitar_pelea(id)
		return
	var pelea: int = _pelea_del_enemigo(id, _nodo_de_id(id))
	if pelea > 0 and pelea != mi_pelea():
		solicitar_unirse(pelea)


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
const _LO_PUESTO := ["estados", "foco_cargas", "imbue", "municion_cargada"]
# Lo que se le devuelve al dueño cuando acaba la pelea: su desgaste y lo que ha aprendido.
const _VUELVE := ["current_hp", "current_mp", "stamina", "level",
	"ability_internal", "ability_consolidado", "ability_base_nivel",
	"fuerza", "resistencia", "destreza", "agilidad", "magia", "voluntad",
	"guardianes_vencidos", "esquivas_exp", "hechizos_exp", "recitado_exp",
	"dano_recibido_exp", "dano_infligido_exp", "dano_bloqueado_exp",
	"heal_left", "heal_rate", "heal_turnos",
	"mana_heal_left", "mana_heal_rate", "mana_heal_turnos",
	"estados", "foco_cargas", "imbue", "municion_cargada"]


# --- UNIRSE ---------------------------------------------------------------------------------

# La llama el jugador al querer meterse en la pelea de un compañero que tiene al lado.
func solicitar_unirse(pelea: int) -> void:
	if not Net.activo or pelea <= 0 or Game.combate_activo() or ocupado_en_pelea() or pelea == mi_pelea():
		return
	# A QUIEN se le pide: a quien la ejecuta, que sale del propio id (etapa 3: la sala).
	var a: int = ejecutor_de(pelea)
	if a == 0 or a == multiplayer.get_unique_id():
		return
	# Ya le he mandado mis fichas a ESE para MI pelea (me la abre ahora mismo): no hay nada a lo que unirse. Pasaba
	# cuando el bicho me embestia (la pelea me llegaba por el empuje) y detras llegaba la respuesta a mi golpe (12/10).
	if _fichas_mandadas_a != 0 and _fichas_mandadas_a == a:
		return
	Game.marcar_entrando_en_pelea()   # quieto mientras me contestan (ver _llega_pelea)
	_pedir_unirme.rpc_id(a, Net.zip(Net.partida.fichas_a_red(_fichas_de_mi_grupo())), pelea, _espera_golpe())


# LAS FICHAS DE MI GRUPO para una pelea que ejecuta la sala (la mia, o unirme a la de otro). Apunta a quien mando (_mis_en_pelea) y se lleva el conjuro que traiga cada uno.
func _fichas_de_mi_grupo() -> Array:
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
	return fichas


# Mi grupo en ORDEN DE FORMACION: el lider primero y detras los acompañantes. Es el orden en el que
# se ofrecen para la pelea compartida (formacion decidida: pos 1 seguro, pos 2 si queda hueco).
func _mi_formacion() -> Array:
	var out: Array = [Game.lider()]
	for comp in Game.companeros():
		out.append(comp)
	return out


# Corre en EL ANFITRION: alguien quiere entrar en mi pelea, con la ficha de su personaje. En la sala, en la pelea
# 'pelea' (su id: lleva varias).
@rpc("any_peer", "call_remote", "reliable")
func _pedir_unirme(z: Array, pelea: int = 0, espera: float = 0.0) -> void:
	var fichas: Array = Net.partida.fichas_de_red(Net.unzip_array(z))
	Medidor.marca("pelea_compa", "anfitrion_recibe_union")
	var quien := multiplayer.get_remote_sender_id()
	# Entra al tocar su golpe, como al abrir una (ver _abre_mi_pelea).
	if espera > 0.0 and Net.soy_sala:
		await get_tree().create_timer(minf(espera, ESPERA_GOLPE_MAX), true).timeout
	var pe: PeleaViva = _peleas.get(pelea) if Net.soy_sala else Game.pelea
	if pe == null:
		print("[Net.unirse] DENIEGO a ", quien, ": la pelea ", pelea, " ya no esta")
		_union_denegada.rpc_id(quien, "Esa pelea ya no está disponible.")
		return
	var p: Node = _pantalla_combate(pe)
	if pe.id == 0 or p == null or not p.has_method("roster_para_espejo") or fichas.is_empty():
		print("[Net.unirse] DENIEGO a ", quien, ": pelea_id=", pe.id, " pantalla=", p != null)
		_union_denegada.rpc_id(quien, "Esa pelea ya no está disponible.")
		return
	# YA ESTA DENTRO. Pasa cuando su espejo aun no le ha llegado desde la sala:
	# vuelve a atacar a un bicho de la misma pelea y eso se convierte en "unirse". Meterle otra vez
	# duplicaria sus personajes. Sin respuesta a proposito: un _union_denegada le vaciaria _mis_en_pelea,
	# que es con lo que su espejo, a punto de llegar, sabe cuales son los suyos.
	if pe.participantes.has(quien):
		print("[Net.unirse] ", quien, " ya esta en mi pelea: no se le mete dos veces")
		return
	print("[Net.unirse] ", quien, " entra en mi pelea con ", fichas.size(), " personaje(s)")
	# Aguanta la pelea hasta que entre de verdad: si caen todos en ese hueco, no se cierra
	# dejando al que venia de rescate con una pelea muerta.
	if p.has_method("esperar_refuerzo"):
		p.esperar_refuerzo(true)
	var r: Dictionary = meter_dobles(p, quien, fichas, pe)
	var dobles: Array = r["dobles"]
	var idxs: Array = r["idxs"]
	if p.has_method("esperar_refuerzo"):
		p.esperar_refuerzo(false)
	if dobles.is_empty():
		# La pelea existe: lo que pasa es que NO CABE nadie mas. Decirlo tal cual; el mensaje de
		# "ya no esta disponible" mandaba a buscar un problema que no era.
		_union_denegada.rpc_id(quien, "La pelea está llena: no cabe nadie más.")
		return
	pe.dobles[quien] = dobles       # de quien es cada doble, para devolverle lo suyo al acabar
	if not pe.participantes.has(quien):
		pe.participantes.append(quien)
	# Los INDICES le dicen cual de sus personajes es cada aliado de la pantalla: es lo unico que
	# significa lo mismo en las dos maquinas (y lo que necesita para saber a quien mover).
	olvidar_filas(pe, quien)
	_union_ok.rpc_id(quien, pe.id, Net.zip(p.roster_para_espejo()), idxs)


# Mete en la pelea de la pantalla 'p' un DOBLE por cada ficha de 'quien', marcados como suyos y con el
# conjuro que traigan sembrado. Devuelve {"dobles": [...], "idxs": [huecos en la fila de aliados]}.
# Lo usan las dos formas de meter a un humano: que se una a una pelea (_pedir_unirme) y que la pelea
# se monte entera con fichas en la sala (Game.abrir_pelea_de_fichas).
func meter_dobles(p: Node, quien: int, fichas: Array, pe: PeleaViva = null) -> Dictionary:
	if pe == null:
		pe = Game.pelea
	# Un DOBLE por personaje suyo: pelean aqui con sus stats y su equipo. Se meten POR ORDEN DE
	# FORMACION y entra lo que quepa (MAX_ALIADOS): su pos 1 seguro, la pos 2 si queda hueco.
	var dobles: Array = []
	var idxs: Array = []
	for f in fichas:
		var doble: PersonajeData = Net.partida.ficha_de_dict(f)
		if not Game.unir_aliado_al_combate(doble, float(f.get("overload", 1.0)), pe):
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
	return {"dobles": dobles, "idxs": idxs}


# La pelea que acabo de montar con fichas (Game.abrir_pelea_de_fichas) es de ESTOS humanos: sus dobles
# (para devolverles lo suyo al cerrar) y como participantes (reciben instantaneas y se les piden turnos).
func adoptar_pelea(dobles_por_peer: Dictionary, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	for peer in dobles_por_peer:
		pe.dobles[peer] = dobles_por_peer[peer]
		if not pe.participantes.has(peer):
			pe.participantes.append(peer)


@rpc("any_peer", "call_remote", "reliable")
func _union_denegada(motivo: String = "Esa pelea ya no está disponible.") -> void:
	_fichas_mandadas_a = 0   # (etapa 3) la sala me deniega la pelea que le pedi: ya no espero su respuesta
	Game.soltar_entrando_en_pelea()
	# El conjuro que mande con la ficha vuelve a su sitio. NO es opcional: para mandarlo ya le corte
	# el canto al jugador (ver solicitar_unirse), asi que sin esto el hechizo —y su maná— se pierden
	# en silencio. Con la nota de vuelta, el camino de siempre le devuelve el maná a los 5 s.
	Game.devolver_casteo_en_vuelo()
	# Y la lista de a quien mande, que si no se queda de una union que no llego a existir: un lote de
	# desgaste rezagado se buscaria el uid ahi dentro y podria colarse (ver _devolver_desgaste).
	_mis_en_pelea.clear()
	# El motivo lo manda el anfitrion: "no existe" y "esta llena" son cosas distintas y el jugador
	# necesita saber cual de las dos, o se pone a recolocarse pensando que apunta mal.
	Net._toast(motivo)


# Corre en EL QUE SE UNE: abre su pantalla en espejo.
# 'idxs' son los huecos de la fila de aliados que han tocado a MIS personajes, en el mismo orden en
# que mande las fichas. Con ellos se sabe a quien muevo yo cuando el anfitrion pide una accion.
@rpc("any_peer", "call_remote", "reliable")
func _union_ok(id: int, z: Array, idxs: Array) -> void:
	var roster: Dictionary = Net.unzip_dict(z)
	Medidor.marca("pelea", "union_ok")
	_fichas_mandadas_a = 0
	# NO PUEDO ABRIR EL ESPEJO (me ha caido otra pelea encima mientras llegaba este). Mis personajes YA
	# estan dentro de la suya: hay que decirle que me saque, o la pelea se quedaria esperando turnos mios
	# que nunca van a llegar. Lo que le devuelva no tiene dueño aqui (se descarta): no pelearon.
	if Game.combate_activo() or ocupado_en_pelea() or Game.abrir_combate_espejo(roster) == null:
		var otro := multiplayer.get_remote_sender_id()
		print("[Net.unirse] no puedo abrir el espejo de la pelea de ", otro, ": que me saque")
		# _mis_en_pelea SOLO SE VACIA SI NO TENGO OTRA PELEA. Si ya estoy espejando una, esa lista es
		# de ELLA (la formacion es la misma en las dos, asi que vaciarla aqui dejaba a la pelea buena
		# sin manera de devolverme nada: su lote llegaba sin dueño y se tiraba). Ver _devolver_desgaste.
		if _pelea_sigo == 0:
			_mis_en_pelea.clear()
		Game.devolver_casteo_en_vuelo()
		_salgo_de_la_pelea.rpc_id(otro, id)
		return
	# El conjuro que mande con la ficha ya esta sembrado en mi doble, alli: aqui no vuelve.
	Game.soltar_casteo_en_vuelo()
	_pelea_sigo = id
	_pelea_anfitrion = multiplayer.get_remote_sender_id()
	# Fin de la medida: la pantalla ya esta abierta (el que pego y el compañero que se une)
	Medidor.marca("pelea", "pantalla_abierta")   # siempre: tambien cuando la pelea la empezo el enemigo
	for tramo in ["pelea", "pelea_compa"]:
		if Medidor.abierto(tramo):
			Medidor.cerrar(tramo, "pantalla")
	Game.anunciar_mi_zona(_pelea_sigo)   # los de mi piso la ven desde fuera (y entra el que pille dentro)
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
func difundir_instantanea(snap: Dictionary, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if not Net.activo or pe.id == 0 or pe.participantes.is_empty():
		return
	for p in pe.participantes:
		_instantanea.rpc_id(p, solo_filas_nuevas(snap, pe.filas_enviadas, p), pe.id)


# LAS FILAS QUE NO HAN CAMBIADO NO VIAJAN (fase 3, 28/10): la instantanea era lo segundo que mas pesaba (~1,6 KB en cada
# cambio que se ve), y casi todo eran filas de combatientes iguales a las de la anterior (sus estados con su texto y
# su tooltip, los numeros de la ficha de cada aliado). Una fila igual a la ultima que le llego a ESE peer va como
# null, y el espejo se queda con la que tenia (la instantanea es fiable: la anterior le llego). Va entera si cambia
# la revision o el numero de filas, y para quien no tiene base: el que acaba de recibir el roster (al unirse o al
# pedirlo) la pierde, ver olvidar_filas. 'enviadas' = peer -> {"rev", "a", "e"}, y se actualiza aqui.
static func solo_filas_nuevas(snap: Dictionary, enviadas: Dictionary, peer: int) -> Dictionary:
	var antes: Dictionary = enviadas.get(peer, {})
	var a: Array = snap.get("a", [])
	var e: Array = snap.get("e", [])
	enviadas[peer] = {"rev": snap.get("rev", 0), "a": a, "e": e}
	var mismas_filas: bool = not antes.is_empty() and antes["rev"] == snap.get("rev", 0) \
		and (antes["a"] as Array).size() == a.size() and (antes["e"] as Array).size() == e.size()
	if not mismas_filas:
		return snap
	var out: Dictionary = snap.duplicate()
	out["a"] = _filas_cambiadas(antes["a"], a)
	out["e"] = _filas_cambiadas(antes["e"], e)
	return out


static func _filas_cambiadas(antes: Array, ahora: Array) -> Array:
	var out: Array = []
	for i in ahora.size():
		out.append(null if antes[i] == ahora[i] else ahora[i])
	return out


# Quien recibe el roster entero (al unirse, o porque lo pidio) monta su pantalla de cero: su siguiente instantanea, entera.
static func olvidar_filas(pe: PeleaViva, peer: int) -> void:
	if pe != null:
		pe.filas_enviadas.erase(peer)


# LA BARRA DE ACCION. Va aparte de la instantanea y a ~20 Hz porque es lo unico que se mueve de
# forma CONTINUA: metida en la instantanea (que solo sale cuando cambia algo) la barra del espejo
# iria a saltos, y mandada como fiable seria trafico tonto. Mismo trato que las posiciones de los
# enemigos: unreliable_ordered y a correr.
func difundir_atb(ratios: PackedFloat32Array, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if not Net.activo or pe.id == 0 or pe.participantes.is_empty():
		return
	for p in pe.participantes:
		_atb.rpc_id(p, ratios, pe.id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _atb(ratios: PackedFloat32Array, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _de_mi_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_atb"):
		p.aplicar_atb(ratios)


# LAS HUELLAS DEL MAPA (combate tactico): lo que alguien esta apuntando y lo que se esta cargando, para
# que todos lo vean en el suelo. Cosmetico y continuo como el ATB: unreliable_ordered. Lo reparte
# quien lleva la pelea, con TODAS las vivas en un paquete (ver turno_mapa.estado_huellas).
func difundir_huellas(datos: PackedFloat32Array, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if not Net.activo or pe.id == 0 or pe.participantes.is_empty():
		return
	for p in pe.participantes:
		_huellas.rpc_id(p, datos, pe.id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _huellas(datos: PackedFloat32Array, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _de_mi_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_huellas"):
		p.aplicar_huellas(datos)


# EL ESPEJO que esta apuntando le manda su huella a quien lleva la pelea, que la reparte a los demas.
func enviar_mi_huella(datos: PackedFloat32Array) -> void:
	if not Net.activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_mi_huella.rpc_id(_pelea_anfitrion, datos)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _mi_huella(datos: PackedFloat32Array) -> void:
	var pe: PeleaViva = _pe_de_peer(multiplayer.get_remote_sender_id())
	if pe == null or pe.id == 0:
		return
	var p: Node = _pantalla_combate(pe)
	if p != null and p.has_method("huella_de_espejo"):
		p.huella_de_espejo(datos, multiplayer.get_remote_sender_id())


# LOS GOLPES, para que el espejo pueda REPRODUCIRLOS (la embestida de la tarjeta y los numeros de
# daño). Sin esto el compañero veria las vidas bajar de golpe: los combatientes de su pantalla son
# maniquis y no resuelven nada. Sale UN paquete por accion, con 4 enteros por golpe.
#
# Va FIABLE desde el 09/10 (playtest 08/10: "un monton de animaciones no se hacen y no suenan"). Iba unreliable_ordered en
# el mismo canal que el ATB y las huellas, que salen 20 veces por segundo: con 'ordered', un paquete de golpes que
# llegaba detras de uno de ATB mas nuevo SE TIRABA entero, y se perdia el turno visto y oido. Es uno por accion y
# pequeño (5 enteros por golpe, tope 40): garantizarlo cuesta poco.
func difundir_impactos(datos: PackedInt32Array, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if not Net.activo or pe.id == 0 or pe.participantes.is_empty():
		return
	for p in pe.participantes:
		_impactos.rpc_id(p, datos, pe.id)


@rpc("any_peer", "call_remote", "reliable")
func _impactos(datos: PackedInt32Array, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _de_mi_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	# El has_method NO es paranoia: un compañero con una version anterior no tiene aplicar_impactos,
	# y asi el paquete se le cae en silencio en vez de reventarle la pelea.
	if p != null and p.has_method("aplicar_impactos"):
		p.aplicar_impactos(datos)


@rpc("any_peer", "call_remote", "reliable")
func _instantanea(snap: Dictionary, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _de_mi_anfitrion(pelea):
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

func difundir_roster(roster: Dictionary, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if not Net.activo or pe.id == 0 or pe.participantes.is_empty():
		return
	for p in pe.participantes:
		olvidar_filas(pe, p)
		_roster_pelea.rpc_id(p, Net.zip(roster), pe.id)


@rpc("any_peer", "call_remote", "reliable")
func _roster_pelea(z: Array, pelea: int = 0) -> void:
	var roster: Dictionary = Net.unzip_dict(z)
	if _pelea_sigo == 0 or not _de_mi_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_roster"):
		p.aplicar_roster(roster)


# ESPEJO: me falta un trozo del registro (me uni a mitad, o se escribio mucho de golpe). Lo pido
# entero UNA vez; va fiable, que ENet lo trocea aunque pase de la MTU.
func pedir_log_pelea() -> void:
	if not Net.activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_pedir_log_pelea.rpc_id(_pelea_anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_log_pelea() -> void:
	var pe: PeleaViva = _pe_de_peer(multiplayer.get_remote_sender_id())
	if pe == null or pe.id == 0:
		return
	var p: Node = _pantalla_combate(pe)
	if p != null and p.has_method("log_entero"):
		_log_pelea.rpc_id(multiplayer.get_remote_sender_id(), p.log_entero(), pe.id)


@rpc("any_peer", "call_remote", "reliable")
func _log_pelea(lineas: Array, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _de_mi_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_log_entero"):
		p.aplicar_log_entero(lineas)


# ESPEJO: la revision no me cuadra (me he perdido un alta). Que me manden el roster otra vez.
func pedir_roster_pelea() -> void:
	if not Net.activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_pedir_roster_pelea.rpc_id(_pelea_anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_roster_pelea() -> void:
	var quien := multiplayer.get_remote_sender_id()
	var pe: PeleaViva = _pe_de_peer(quien)
	if pe == null or pe.id == 0:
		return
	var p: Node = _pantalla_combate(pe)
	if p != null and p.has_method("roster_para_espejo"):
		olvidar_filas(pe, quien)
		_roster_pelea.rpc_id(quien, Net.zip(p.roster_para_espejo()), pe.id)


# --- VELOCIDAD x1 / x2 (espejo -> anfitrion) --------------------------------------------------

# ESPEJO: he pulsado el boton de velocidad. La pelea no corre aqui, asi que se le pide a quien la
# ejecuta, y la nueva velocidad vuelve a todos en la instantanea (ver combat_espejo.aplicar_instantanea).
# Antes el boton iba apagado en el espejo, y desde que TODAS las peleas las lleva la sala, eso era no poder cambiarla nunca (aunque jugaras solo en la partida).
func pedir_velocidad(v: float) -> void:
	if not Net.activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_pedir_velocidad.rpc_id(_pelea_anfitrion, v)


# Cualquiera que este DENTRO la cambia, y vale la ultima pulsacion.
@rpc("any_peer", "call_remote", "reliable")
func _pedir_velocidad(v: float) -> void:
	var pe: PeleaViva = _pe_de_peer(multiplayer.get_remote_sender_id())
	if pe == null or pe.id == 0 or not pe.participantes.has(multiplayer.get_remote_sender_id()):
		return
	var p: Node = _pantalla_combate(pe)
	if p == null or p._espejo:
		return
	p._aplicar_velocidad(v)
	p.espejo._difundir()


# --- TURNOS (anfitrion <-> dueño del personaje) ----------------------------------------------

# ============================================================
#  CAIDAS A MEDIA PELEA (fase 5 de la BD, 07/10/2026). Decision del jefe: al que se le corta la conexion,
#  sus personajes se quedan un rato (CORTESIA) y en su turno DEFIENDEN si tienen energia y si no PASAN
#  (combat.turno_automatico): nunca se queda la pelea parada. Si vuelve a tiempo, recupera el control; si
#  no, salen, y lo que vivieron (vida, mana, excelia) se apunta en su ficha del mundo en la sala.
# ------------------------------------------------------------
const CORTESIA := 60.0
# EN QUIEN LLEVA LA PELEA: peer que se cayo -> {"ident", "t" (msec), "nombre"}.
var _caidos: Dictionary = {}
# EN QUIEN LLEVA LA PELEA: quien era cada peer que se va (lo dice la sala, que es la que sabe identidades;
# puede llegar antes o despues de que yo note la caida).
var _ident_de_ido: Dictionary = {}
# EN LA SALA: identidad -> {"peer" (el viejo), "lugar", "t"}: los que se han caido hace poco, para
# devolverles la pelea cuando vuelvan a su piso.
var _caidos_sala: Dictionary = {}


func esta_caido(peer: int) -> bool:
	return _caidos.has(peer)


## Quien lleva la pelea: 'peer' se ha caido. true = se queda en cortesia; false = no tenia nada aqui.
func marcar_caido(peer: int, ident: String = "", motivo: String = "") -> bool:
	var pe: PeleaViva = _pe_de_peer(peer)
	if pe == null or pe.id == 0 or not pe.dobles.has(peer) or _caidos.has(peer):
		return false
	var p: Node = _pantalla_combate(pe)
	if p == null or not p.has_method("caido_de_la_red") or (p.has_method("acabada") and p.acabada()):
		return false
	pe.participantes.erase(peer)   # sin pantalla: ni instantaneas ni peticiones
	if ident == "":
		ident = String(_ident_de_ido.get(peer, ""))
	var nombre: String = "Tu compañero"
	for doble in pe.dobles[peer]:
		if doble != null:
			nombre = (doble as PersonajeData).nombre
			break
	_caidos[peer] = {"ident": ident, "t": Time.get_ticks_msec(), "nombre": nombre, "pe": pe}
	print("[pelea] %s (peer %d) se ha desconectado: sus personajes siguen %.0f s jugando solos" % [nombre, peer, CORTESIA])
	p._set_log(motivo % nombre if motivo != "" else "%s se ha desconectado: sus personajes defienden solos un rato." % nombre)
	p.caido_de_la_red(peer)
	return true


# Se acabo el rato de alguien que no ha vuelto: lo vivido a su ficha (en la sala) y sus personajes fuera.
func _vencer_cortesia() -> void:
	if _caidos.is_empty():
		return
	for peer in _caidos.keys():
		if Time.get_ticks_msec() - int(_caidos[peer]["t"]) < int(CORTESIA * 1000.0):
			continue
		var c: Dictionary = _caidos[peer]
		_caidos.erase(peer)
		var pe = c.get("pe", Game.pelea)   # sin tipar: la pelea puede haberse ido ya
		if not is_instance_valid(pe):
			continue
		_desgaste_a_la_sala(peer, String(c.get("ident", "")), pe)
		var p: Node = _pantalla_combate(pe)
		if p != null and p.has_method("sacar_a"):
			p.sacar_a(peer, "%s no ha vuelto: sus personajes dejan la pelea." % String(c.get("nombre", "Tu compañero")))


# Lo que vivieron los dobles de un jugador que ya no esta conectado, a la sala (que lo apunta en su ficha
# del mundo, o se lo manda si ya ha vuelto con otra conexion).
func _desgaste_a_la_sala(peer: int, ident: String, pe: PeleaViva = null) -> void:
	if pe == null:
		pe = Game.pelea
	if not pe.dobles.has(peer):
		return
	var lote: Array = []
	for doble in pe.dobles[peer]:
		Game.volcar_desgaste_en_ficha(doble)
		lote.append(Net.partida.desgaste_a_dict(doble))
	pe.dobles.erase(peer)
	if ident == "":
		push_warning("[pelea] lo vivido por los personajes del peer %d se pierde: no se sabe de quien era" % peer)
		return
	Net.partida.desgaste_de_ausente(ident, lote)


# LA SALA dice quien era el peer que se ha ido (a todos: quien lleve su pelea lo necesita).
@rpc("authority", "call_remote", "reliable")
func _ident_caido(peer: int, ident: String) -> void:
	_ident_de_ido[peer] = ident
	if _caidos.has(peer) and String(_caidos[peer].get("ident", "")) == "":
		_caidos[peer]["ident"] = ident


# EN LA SALA: se ha caido un humano. Se apunta y se reparte quien era.
func apuntar_caido(peer: int, ident: String, lugar: String) -> void:
	_caidos_sala[ident] = {"peer": peer, "lugar": lugar, "t": Time.get_ticks_msec()}
	_ident_de_ido[peer] = ident
	_ident_caido.rpc(peer, ident)


# EN LA SALA: 'peer' acaba de llegar a 'lugar'. Si es alguien que se cayo hace poco y vuelve a SU piso, se
# le avisa a la pelea (la llevo yo) para que le devuelva a sus personajes. Con un
# respiro: su piso se esta construyendo y el espejo de la pelea se monta encima.
func revisar_vuelta(peer: int, lugar: String) -> void:
	var ident: String = Net._identidad_de_peer(peer)
	if ident == "":
		return
	_rehacer_guardadas(peer, ident, lugar)   # una pelea guardada suya en ese piso: se rehace y queda en _caidos_sala
	if not _caidos_sala.has(ident):
		return
	var c: Dictionary = _caidos_sala[ident]
	if Time.get_ticks_msec() - int(c["t"]) > int((CORTESIA + 30.0) * 1000.0):
		_caidos_sala.erase(ident)
		return
	if String(c.get("lugar", "")) != lugar or not lugar.begins_with("piso:"):
		return
	_caidos_sala.erase(ident)
	await get_tree().create_timer(1.5).timeout
	var viejo: int = int(c["peer"])
	_vuelve.rpc(viejo, peer)
	_vuelve(viejo, peer)


# EN QUIEN LLEVA LA PELEA: 'viejo' ha vuelto como 'nuevo'. Si estaba en mi cortesia, sus personajes
# vuelven a ser suyos y se le abre el espejo.
@rpc("authority", "call_remote", "reliable")
func _vuelve(viejo: int, nuevo: int) -> void:
	if not _caidos.has(viejo):
		return
	var c: Dictionary = _caidos[viejo]
	_caidos.erase(viejo)
	var pe = c.get("pe", Game.pelea)   # sin tipar: la pelea puede haberse ido ya
	if not is_instance_valid(pe):
		return
	var p: Node = _pantalla_combate(pe)
	if p == null or not pe.dobles.has(viejo):
		return
	pe.dobles[nuevo] = pe.dobles[viejo]
	pe.dobles.erase(viejo)
	p.cambiar_dueno(viejo, nuevo)
	if not pe.participantes.has(nuevo):
		pe.participantes.append(nuevo)
	var pares: Array = []
	for doble in pe.dobles[nuevo]:
		pares.append([p.indice_de_aliado(Game.combatant_de_pj(doble)), String((doble as PersonajeData).uid)])
	print("[pelea] %s ha vuelto (peer %d -> %d): recupera a sus personajes" % [String(c.get("nombre", "")), viejo, nuevo])
	p._set_log("%s ha vuelto y recupera a sus personajes." % String(c.get("nombre", "Tu compañero")))
	_retoma_tu_pelea.rpc_id(nuevo, pe.id, IdsRed.a_red(p.roster_para_espejo()), pares)


# EN EL QUE VUELVE: se le abre el espejo de la pelea que dejo a medias, con sus personajes (por uid).
@rpc("any_peer", "call_remote", "reliable")
func _retoma_tu_pelea(id: int, roster: Dictionary, pares: Array) -> void:
	roster = IdsRed.de_red(roster)
	var otro := multiplayer.get_remote_sender_id()
	var mios: Array = []
	var huecos: Dictionary = {}
	for par in pares:
		var pj: PersonajeData = _mio_de_la_plantilla(String(par[1]))
		if pj != null:
			mios.append(pj)
			huecos[int(par[0])] = pj
	if mios.is_empty() or Game.combate_activo() or ocupado_en_pelea():
		print("[pelea] no puedo retomar la pelea de %d: que me saque" % otro)
		_salgo_de_la_pelea.rpc_id(otro, id)
		return
	_mis_en_pelea = mios
	if Game.abrir_combate_espejo(roster) == null:
		_mis_en_pelea.clear()
		_salgo_de_la_pelea.rpc_id(otro, id)
		return
	_pelea_sigo = id
	_pelea_anfitrion = otro
	_mis_huecos = huecos
	print("[pelea] retomo mi pelea en %d con %d personaje(s)" % [otro, mios.size()])


func _mio_de_la_plantilla(uid: String) -> PersonajeData:
	var pj: PersonajeData = Game.pj_por_uid(uid)
	if pj != null:
		return pj
	for x in Game.party:
		if x != null and String((x as PersonajeData).uid) == uid:
			return x
	return null


# ============================================================
#  LAS PELEAS A MEDIAS EN EL GUARDADO DEL MUNDO (fase 2, etapa 3, paso 7, 22/10). Si la sala guarda (o se cierra) con
#  peleas en marcha, van al guardado (SaveData.sesion_peleas) y vuelven al abrir el mundo. Se rehacen cuando vuelve a
#  su piso uno de los suyos: la sala la monta con TODOS sus personajes en cortesia, como si se acabaran de caer, y al
#  que vuelve le devuelve los suyos por el camino de las caidas (revisar_vuelta -> _vuelve -> _retoma_tu_pelea). El que
#  no vuelva en CORTESIA sale con lo vivido apuntado en su ficha. Decidido (usuario, 22/10): mientras no vuelve nadie,
#  sus enemigos andan libres, y si otro les pega la pelea guardada se olvida (sus dueños vuelven como si hubieran huido).
#  Prueba: tools/prueba_town_pelea_guardada.gd
# ------------------------------------------------------------
# EN LA SALA: las que esperan a que vuelva alguno de los suyos: [{lugar, base, estado}].
var _guardadas: Array = []
# La marca de los enemigos de cada pelea en la foto de su piso es base + hueco, y cada pelea tiene la suya, de 10 en 10.
# Arranca en la hora de abrir la sala por 100: asi no repite la de una pelea guardada en otra sesion. La 0 es la de solo.
var _base_next: int = 0
# Los PEERS DE MENTIRA de los personajes de una pelea rehecha mientras su dueño no ha vuelto (nunca son de nadie).
const PEER_GUARDADA := 1 << 30
var _peer_guardada_next: int = PEER_GUARDADA


## EN LA SALA: las peleas que hay que guardar (las vivas sin acabar y las que siguen esperando). Marca a sus enemigos:
## se llama ANTES de sacar las fotos de los pisos (Net.pisos.sesion_para_guardar).
func peleas_para_guardar() -> Array:
	var out: Array = []
	if not Net.soy_sala:
		return out
	for pe in _peleas.values():
		if not is_instance_valid(pe) or not is_instance_valid(pe.piso) or pe.piso.es_arena:
			continue
		var p: Node = _pantalla_combate(pe)
		if p == null or not p.has_method("estado_para_guardar") or (p.has_method("acabada") and p.acabada()):
			continue
		if pe.marca == 0:
			if _base_next == 0:
				_base_next = int(Time.get_unix_time_from_system()) * 100
			pe.marca = _base_next
			_base_next += 10
		var estado: Dictionary = p.estado_para_guardar(pe.marca)
		var aliados: Array = []
		for fila in estado.get("aliados", []):
			var peer: int = int(fila.get("dueno", 0))
			var ident: String = _ident_en_pelea(peer)
			var doble: PersonajeData = null
			for d in pe.dobles.get(peer, []):
				if d != null and String((d as PersonajeData).uid) == String(fila.get("uid", "")):
					doble = d
			if ident == "" or doble == null:
				continue   # de nadie que se sepa: no hay a quien devolverselo
			fila.erase("dueno")
			fila["ident"] = ident
			fila["ficha"] = Net.partida.ficha_a_dict(doble)
			# QUE CUERPO DE SU DUEÑO ES: ficha_a_dict lo mira en el grupo de esta maquina, y la sala no tiene grupo. Sin
			# esto, en tactico el doble rehecho no encontraba su cuerpo en el mapa y no podia andar.
			fila["ficha"]["cuerpo"] = int(doble.get_meta("cuerpo_red", -1))
			aliados.append(fila)
		if aliados.is_empty():
			continue
		estado["aliados"] = aliados
		out.append({"lugar": pe.piso.lugar, "base": pe.marca, "estado": estado})
	for g in _guardadas:
		out.append((g as Dictionary).duplicate(true))
	if not out.is_empty():
		print("[pelea] al guardado: %d pelea(s) a medias" % out.size())
	return out


# Quien es el dueño de un personaje de la pelea: el conectado, el que se ha caido (y sigue en cortesia) o el que aun no
# ha vuelto de una pelea rehecha.
func _ident_en_pelea(peer: int) -> String:
	var ident: String = Net._identidad_de_peer(peer)
	if ident == "":
		ident = String(_ident_de_ido.get(peer, ""))
	if ident == "" and _caidos.has(peer):
		ident = String(_caidos[peer].get("ident", ""))
	return ident


## EN LA SALA, al abrir el mundo (Net.pisos.sembrar_sesion): las peleas a medias que venian en el guardado.
func sembrar_guardadas(lista: Array) -> void:
	_guardadas = lista.duplicate(true)
	for g in _guardadas:
		_base_next = maxi(_base_next, int(g.get("base", 0)) + 10)
		print("[pelea] pelea a medias en %s (%d aliados): se sigue cuando vuelva uno de los suyos" % [
			String(g.get("lugar", "")), ((g.get("estado", {}) as Dictionary).get("aliados", []) as Array).size()])


## La pelea a medias de una partida de solo (SaveData.pelea_a_medias) en el formato de la sala, al pasar la ranura a
## formato de mundo (Perfil.convertir_a_mundo): sus enemigos ya van marcados con base 0. Vacio = no habia.
func guardada_de_solo(estado: Dictionary, ident: String) -> Dictionary:
	if estado.is_empty():
		return {}
	var e: Dictionary = estado.duplicate(true)
	var aliados: Array = []
	for fila in e.get("aliados", []):
		var pj: PersonajeData = _mio_de_la_plantilla(String(fila.get("uid", "")))
		if pj == null:
			continue
		fila["ident"] = ident
		fila["ficha"] = Net.partida.ficha_a_dict(pj)
		aliados.append(fila)
	if aliados.is_empty():
		return {}
	e["aliados"] = aliados
	return {"base": 0, "estado": e}


# EN LA SALA: 'peer' (identidad 'ident') llega a 'lugar'. Si alli hay una pelea guardada con personajes suyos, se rehace.
func _rehacer_guardadas(peer: int, ident: String, lugar: String) -> void:
	if not Net.soy_sala or _guardadas.is_empty() or not lugar.begins_with("piso:"):
		return
	for g in _guardadas.duplicate():
		if String(g.get("lugar", "")) != lugar:
			continue
		var suya := false
		for fila in (g["estado"] as Dictionary).get("aliados", []):
			suya = suya or String(fila.get("ident", "")) == ident
		if not suya:
			continue
		var piso: PisoVivo = PisoVivo.del_lugar(lugar)
		if piso == null:
			print("[pelea] la pelea guardada en %s espera: el piso aun no esta montado" % lugar)
			continue
		_guardadas.erase(g)
		_rehacer(g, piso, peer)


func _rehacer(g: Dictionary, piso: PisoVivo, peer: int) -> void:
	var estado: Dictionary = g["estado"]
	var base: int = int(g.get("base", 0))
	var por_marca: Dictionary = {}
	for n in piso.nodos(&"enemy"):
		if is_instance_valid(n) and n.has_meta("id_pelea"):
			por_marca[int(n.get_meta("id_pelea"))] = n
	_quitar_marcas(piso, base)
	var nodos: Array = []
	var filas_e: Array = []
	for e in estado.get("enemigos", []):
		var n = por_marca.get(base + int(e.get("id", -1)))
		if not bool(e.get("vivo", true)) or n == null or not is_instance_valid(n) or n.esta_muerto() \
				or not n.has_meta("net_id") or _enem_ocupados.has(int(n.get_meta("net_id"))) or PeleaViva.de_enemigo(n) != null:
			continue
		nodos.append(n)
		filas_e.append(e)
	if nodos.is_empty():
		print("[pelea] la pelea guardada en %s ya no tiene enemigos: se olvida" % piso.lugar)
		return
	# Un grupo por jugador, en el orden de la pelea (asi los huecos salen como estaban), cada uno con su peer de mentira.
	var grupos: Array = []
	var por_ident: Dictionary = {}
	for fila in estado.get("aliados", []):
		var ident: String = String(fila.get("ident", ""))
		if not por_ident.has(ident):
			por_ident[ident] = {"peer": _peer_guardada_next, "fichas": [], "ident": ident}
			_peer_guardada_next += 1
			grupos.append(por_ident[ident])
		(por_ident[ident]["fichas"] as Array).append(fila["ficha"])
	var quien: int = int(grupos[0]["peer"])
	var ids: Array = []
	for i in nodos.size():
		var n = nodos[i]
		var nid: int = int(n.get_meta("net_id"))
		_enem_ocupados[nid] = quien
		ids.append(nid)
		n.hp_restante = float((filas_e[i]["vol"] as Dictionary).get("hp", -1.0))
		n._combat_triggered = true
		n.velocity = Vector2.ZERO
		n._cancelar_aviso()
	var pe := PeleaViva.new()
	pe.name = "Pelea"
	pe.humano = peer
	pe.marca = base
	piso.add_child(pe, true)
	var huecos: Dictionary = Game.abrir_pelea_de_fichas(nodos, false, grupos, pe)
	var p: Node = _pantalla_combate(pe)
	if huecos.is_empty() or p == null or pe.id == 0:
		print("[pelea] la sala no ha podido rehacer la pelea guardada en %s" % piso.lugar)
		pe.queue_free()
		_soltar_reservados(ids, quien)
		return
	_peleas[pe.id] = pe
	pe.participantes.clear()   # los peers de mentira no tienen pantalla: nada de instantaneas (marcar_caido, abajo)
	# Lo vivido encima: cada personaje por su uid (las filas van en el orden de la pelea vieja).
	var cs: Array = []
	for fila in estado.get("aliados", []):
		var c: Combatant = null
		for i in pe.aliados_pjs.size():
			if pe.aliados_pjs[i] != null and String((pe.aliados_pjs[i] as PersonajeData).uid) == String(fila.get("uid", "")):
				c = pe.aliados_cs[i]
				break
		cs.append(c)
	p.retomar(estado, cs, filas_e, "La pelea sigue donde la dejasteis.")
	# TODOS EN CORTESIA: el que acaba de volver recupera a los suyos enseguida (revisar_vuelta, justo detras); los demas
	# tienen el rato de siempre para volver.
	var ahora: int = Time.get_ticks_msec()
	for gr in grupos:
		marcar_caido(int(gr["peer"]), String(gr["ident"]), "%s aún no ha vuelto: sus personajes defienden solos un rato.")
		_caidos_sala[String(gr["ident"])] = {"peer": int(gr["peer"]), "lugar": piso.lugar, "t": ahora}
	print("[pelea] la sala rehace la pelea guardada en %s (pelea %d): %d de %d enemigos, %d jugador(es)" % [
		piso.lugar, pe.id, nodos.size(), (estado.get("enemigos", []) as Array).size(), grupos.size()])


# A un enemigo de una pelea guardada le ha pegado otro (decidido, 22/10): la pelea se olvida.
func _olvidar_guardada_de(n: Node) -> void:
	var marca: int = int(n.get_meta("id_pelea"))
	n.remove_meta("id_pelea")
	var piso: PisoVivo = PisoVivo.de(n)
	if piso == null:
		return
	for g in _guardadas.duplicate():
		var base: int = int(g.get("base", 0))
		if String(g.get("lugar", "")) == piso.lugar and marca >= base and marca < base + 10:
			_guardadas.erase(g)
			_quitar_marcas(piso, base)
			print("[pelea] le pegan a un enemigo de la pelea guardada en %s: se olvida" % piso.lugar)


func _quitar_marcas(piso: PisoVivo, base: int) -> void:
	for n in piso.nodos(&"enemy"):
		if is_instance_valid(n) and n.has_meta("id_pelea") and int(n.get_meta("id_pelea")) >= base \
				and int(n.get_meta("id_pelea")) < base + 10:
			n.remove_meta("id_pelea")


# El anfitrion pide la accion al dueño de ese personaje. Mientras, su pantalla espera: el ATB no
# corre (State.WAITING_PLAYER), asi que nadie pierde turnos por pensar.
func pedir_accion(peer: int, idx: int, seq: int = 0, radio: float = 0.0, preps: Array = [],
		pe: PeleaViva = null) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_turno.rpc_id(peer, idx, seq, radio, preps, pe.id if pe != null else 0)


# 'seq' es el numero de peticion: viaja de ida y vuelta para que el anfitrion sepa distinguir la
# respuesta a ESTA peticion de una rezagada (ver combat.gd, _pet_seq).
# 'radio' es cuanto puede ANDAR en este turno, en la pelea en el mapa (0 = nada, o pelea de fila). Lo
# calcula el anfitrion: el maniqui del espejo no tiene la Agilidad con la que se saca.
@rpc("any_peer", "call_remote", "reliable")
# 'preps' = las preparaciones (Cargar, Untar) que ya ha hecho en ESTE turno: con alguna, es el mismo turno que sigue.
func _tu_turno(idx: int, seq: int = 0, radio: float = 0.0, preps: Array = [], pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("turno_mio"):
		p.turno_mio(idx, seq, radio, preps)


# --- EL COMBATE EN EL MAPA: los bichos se mueven -----------------------------------------------
# En la pelea en el mapa los bichos ANDAN en su turno, y lo decide quien lleva la pelea. Pero el
# bicho de verdad es de su DUEÑO (el del piso), que es quien difunde su posicion a todos a 20 Hz: si
# no se entera, sigue mandando la de antes y en las demas pantallas el bicho no se mueve (y en la
# mia volvia a su sitio). Asi que quien lleva la pelea le manda al dueño donde ha dejado cada bicho,
# por el mismo camino que el resultado de la pelea (yo -> host -> dueño), y el dueño lo pone en su
# sitio; de ahi lo reparte su tick de siempre.
#
# lote = [[id, pos, angulo_de_mirada, andando], ...]. FIABLE: son pocos paquetes (solo mientras un
# bicho anda, ~20 por segundo durante segundo y medio) y el ultimo, el de "se ha parado aqui", no
# se puede perder o el bicho se queda en el sitio equivocado para siempre.
func mover_bichos_en_pelea(lote: Array) -> void:
	# En la sala los bichos de la pelea SON los de verdad: ya estan donde los dejo la pelea (etapa 3).
	if not Net.activo or multiplayer.multiplayer_peer == null or lote.is_empty() or Net.soy_sala:
		return
	if Net.es_host:
		_encaminar_mover(lote, Net._mi_lugar, multiplayer.get_unique_id())
	else:
		_pedir_mover.rpc_id(1, lote, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_mover(lote: Array, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_mover(lote, lugar, multiplayer.get_remote_sender_id())


func _encaminar_mover(lote: Array, lugar: String, desde: int) -> void:
	if PisoVivo.dueno_de(lugar):
		_aplicar_mover(lote, desde)


# SOLO el dueño, y solo si se lo pide QUIEN LLEVA LA PELEA de ese bicho: nadie mas puede andar
# moviendole los bichos a otro.
func _aplicar_mover(lote: Array, desde: int) -> void:
	for par in lote:
		var id: int = int(par[0])
		var nodo = Net.enemigos._enemigos.get(id, {}).get("nodo")
		if nodo == null or not is_instance_valid(nodo):
			continue
		if ejecutor_de(_pelea_del_enemigo(id, nodo)) != desde:
			continue
		if nodo.has_method("mover_en_pelea"):
			nodo.mover_en_pelea(par[1], float(par[2]), bool(par[3]))


# LAS CRIAS DEL BROTE (28/09): quien lleva la pelea no simula el piso, asi que le pide al dueño que las haga
# nacer (Game.nacer_cria_aqui, reservadas a su nombre) y el dueño le contesta con el net_id de cada una para
# que enganche su espejo al hueco 'slot' (Game.cuerpo_de_cria_listo). Mismo camino que mover_bichos_en_pelea.
func pedir_cria(slot: int, ruta: String, pos: Vector2, t: float) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_encaminar_cria(slot, ruta, pos, t, Net._mi_lugar, multiplayer.get_unique_id())
	else:
		_pedir_cria.rpc_id(1, slot, IdsRed.de(ruta), pos, t, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_cria(slot: int, id: int, pos: Vector2, t: float, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_cria(slot, IdsRed.ruta(id), pos, t, lugar, multiplayer.get_remote_sender_id())   # su .tres, por id


func _encaminar_cria(slot: int, ruta: String, pos: Vector2, t: float, lugar: String, para: int) -> void:
	if PisoVivo.dueno_de(lugar):
		_nacer_cria_dueno(slot, ruta, pos, t, para, lugar)


func _nacer_cria_dueno(slot: int, ruta: String, pos: Vector2, t: float, para: int, lugar: String = "") -> void:
	var data: EnemyData = load(ruta) as EnemyData if ResourceLoader.exists(ruta) else null
	var n = Game.nacer_cria_aqui(data, pos, t, para, lugar) if data != null else null
	if n == null or not n.has_meta("net_id"):
		return
	var id: int = int(n.get_meta("net_id"))
	if para == multiplayer.get_unique_id():
		Game.cuerpo_de_cria_listo(slot, id)
	else:
		_cria_lista.rpc_id(para, slot, id)


@rpc("any_peer", "call_remote", "reliable")
func _cria_lista(slot: int, id: int) -> void:
	Game.cuerpo_de_cria_listo(slot, id)


# MAGIA (hito 5.4-C): recitar son varios turnos con su examen de frases, asi que no basta con
# mandar una accion suelta como en las habilidades — hay que enrutar CADA frase. El anfitrion
# sortea las opciones (lleva la pelea) y el dueño responde con la que eligio.
func pedir_frase(peer: int, idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0,
		pe: PeleaViva = null) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_frase.rpc_id(peer, idx, opciones, nombre, largo, seq, pe.id if pe != null else 0)


@rpc("any_peer", "call_remote", "reliable")
func _tu_frase(idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("recitar_frase"):
		p.recitar_frase(idx, opciones, nombre, largo, seq)


func pedir_disparo(peer: int, nombre: String, seq: int = 0, pe: PeleaViva = null) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_disparo.rpc_id(peer, nombre, seq, pe.id if pe != null else 0)


@rpc("any_peer", "call_remote", "reliable")
func _tu_disparo(nombre: String, seq: int = 0, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("lanzar_conjuro"):
		p.lanzar_conjuro(nombre, seq)


# ATAQUE DE CARGA listo: la orden de soltarlo (y el objetivo) es de SU dueño, no del anfitrion.
# Hermana de pedir_disparo, y por lo mismo: hay un turno cuya unica accion posible es esa.
func pedir_soltar(peer: int, nombre: String, seq: int = 0, pe: PeleaViva = null) -> void:
	if not Net.activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_carga.rpc_id(peer, nombre, seq, pe.id if pe != null else 0)


@rpc("any_peer", "call_remote", "reliable")
func _tu_carga(nombre: String, seq: int = 0, pelea: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion(pelea):
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("soltar_carga"):
		p.soltar_carga(nombre, seq)


# Lo mismo, EN SILENCIO, para lo que llega a chorro (barra de accion a 20 Hz, impactos, instantaneas): una
# pelea de la que ya sali (y en la que aun me tenian apuntado) no puede pintarse ni sonar dentro de la
# que espejo ahora.
func _de_mi_anfitrion(pelea: int = 0) -> bool:
	return _pelea_anfitrion == 0 or _es_de_la_que_sigo(pelea, multiplayer.get_remote_sender_id())


# ¿Este mensaje es de la pelea que espejo? Por su ID (etapa 3: las de la sala llegan todas del mismo peer); sin id
# (0), por quien lo manda, como antes.
func _es_de_la_que_sigo(pelea: int, quien: int) -> bool:
	return pelea == _pelea_sigo if pelea != 0 else quien == _pelea_anfitrion


# ¿Es de la pelea de la que me sali y cuyo cierre espero (ver salir_del_espejo)?
func _es_del_cierre_esperado(pelea: int, quien: int) -> bool:
	if pelea != 0 and _cierre_esperado_pelea != 0:
		return pelea == _cierre_esperado_pelea
	return quien == _cierre_esperado_de


# ¿Esto me lo manda de verdad quien lleva mi pelea? Las RPC de turno son "any_peer" (tienen que
# serlo: la pelea la ejecuta un jugador cualquiera, no el host de la red), asi que sin esta
# comprobacion cualquier peer podia ponerme los botones de un turno que no me toca.
func _lo_manda_el_anfitrion(pelea: int = 0) -> bool:
	var quien := multiplayer.get_remote_sender_id()
	if _pelea_anfitrion != 0 and not _es_de_la_que_sigo(pelea, quien):
		print("[multi] turno ignorado: lo manda el peer %d y mi pelea la lleva el %d" % [
			quien, _pelea_anfitrion])
		return false
	return true


# El dueño manda lo que ha elegido.
func enviar_accion(accion: Dictionary) -> void:
	if not Net.activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_accion_elegida.rpc_id(_pelea_anfitrion, accion_a_red(accion))


# LA ACCION VIAJA CON IDS (IdsRed): su "ruta" (la habilidad, el hechizo, el objeto, la municion) y su "hab" (la
# habilidad con la que se carga o se unta) van como numero.
static func accion_a_red(accion: Dictionary) -> Dictionary:
	var a: Dictionary = IdsRed.a_red(accion)
	if a.get("hab") is String and String(a["hab"]) != "":
		a["hab"] = IdsRed.de(a["hab"])
	return a


static func accion_de_red(accion: Dictionary) -> Dictionary:
	var a: Dictionary = IdsRed.de_red(accion)
	if a.get("hab") is int:
		a["hab"] = IdsRed.ruta(int(a["hab"]))
	return a


@rpc("any_peer", "call_remote", "reliable")
func _accion_elegida(accion: Dictionary) -> void:
	accion = accion_de_red(accion)
	var pe: PeleaViva = _pe_de_peer(multiplayer.get_remote_sender_id())
	if pe == null or pe.id == 0:
		return
	var p: Node = _pantalla_combate(pe)
	if p != null and p.has_method("aplicar_accion_remota"):
		# QUIEN la manda va SIEMPRE con ella. Sin esto, el combate no podia distinguir la respuesta
		# del jugador al que le toca de la de otro (o de un eco tardio), y una respuesta rezagada
		# consumia el turno de quien no habia elegido nada. Ver combat.aplicar_accion_remota.
		p.aplicar_accion_remota(accion, multiplayer.get_remote_sender_id())


# El anfitrion cierra: los espejos se cierran con el.
@rpc("any_peer", "call_remote", "reliable")
func _fin_espejo(pelea: int = 0) -> void:
	var quien := multiplayer.get_remote_sender_id()
	# ¿ES DE LA PELEA QUE ESTOY VIENDO? Un cierre de OTRA pelea (una union rechazada, un anfitrion
	# viejo que contesta tarde) no puede llevarse por delante la de ahora: cerraria mi pantalla y
	# dejaria a mis personajes dentro de la otra, pidiendo turnos que ya no puedo contestar. De la
	# vieja solo se suelta lo suyo: la espera del desgaste.
	if _pelea_sigo != 0 and not _es_de_la_que_sigo(pelea, quien):
		print("[espejo] cierre rezagado (peer %d, pelea %d): sigo en la pelea %d, no la cierro" % [
			quien, pelea, _pelea_sigo])
		if _es_del_cierre_esperado(pelea, quien):
			_cierre_esperado_de = 0
			_cierre_esperado_pelea = 0
			_desgaste_pendiente = false
		return
	_cierre_esperado_de = 0
	_cierre_esperado_pelea = 0
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
