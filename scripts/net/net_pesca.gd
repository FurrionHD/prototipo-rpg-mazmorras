# ============================================================
#  net_pesca.gd  (hijo de Net: /root/Net/Pesca)
#  LA PESCA COMPARTIDA, sacada de net.gd tal cual. Se llama como Net.pesca.<funcion>.
#  Lo comun de la sesion (activo, es_host, _peers, _mi_lugar, dueño del piso) sigue en Net.
# ============================================================
extends Node

# ==============================================================================================
#  PESCA COMPARTIDA
#
#  El charco funciona como los enemigos: lo SIMULA el dueño del piso y los demas lo ven en espejo.
#  Antes cada maquina corria su propio charco con su propio banco de 10, asi que dos personas en la
#  misma orilla sacaban veinte peces de un sitio que tiene diez, y ademas cada uno veia los suyos.
#
#  Tres cosas viajan, y ninguna es adorno:
#    1) EL BANCO (_peces_estado): que peces hay, donde nadan y cuantos quedan en el charco. Va a
#       ~10 Hz, sin fiabilidad (como el tick de los bichos): si se pierde un paquete, el siguiente
#       ya trae la verdad.
#    2) EL CORCHO de cada uno (_corcho_pesca): el dueño necesita saber donde ha caido el sedal del
#       otro para poder decidir QUE pez pica. La mordida es una colision, y las colisiones solo
#       existen en la maquina que simula.
#    3) EL CANDADO por pez: quien lo tiene enganchado. Es lo que hace que "ves como lo esta
#       pescando y no puedes interactuar con el" sea verdad y no una carrera entre dos maquinas.
#
#  Todo pasa por el host, como el resto: en estrella un cliente no habla con otro cliente.
# ==============================================================================================

# El charco vivo de MI piso (solo hay uno por piso). Lo registra fishing_spot._ready.
var _charco: Node = null


func registrar_charco(nodo: Node) -> void:
	_charco = nodo


func olvidar_charco(nodo: Node) -> void:
	if _charco == nodo:
		_charco = null


# --- 1) EL BANCO: del dueño a los demas ---
# Lo llama fishing_spot._process en el dueño, ya con su propio ritmo (no hace falta acumulador
# aqui: el charco sabe mejor que Net cada cuanto merece la pena mandar su foto).
func difundir_charco(snap: Dictionary) -> void:
	if not Net.activo or not Net._soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		for peer_id in Net._peers:
			if Net._peers[peer_id].get("lugar", "") == Net._mi_lugar:
				_tick_charco.rpc_id(peer_id, snap)
	else:
		_rel_charco.rpc_id(1, Net._mi_lugar, snap)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _tick_charco(snap: Dictionary) -> void:
	if _charco != null and is_instance_valid(_charco):
		_charco.aplicar_red(snap)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rel_charco(lugar: String, snap: Dictionary) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar and not Net._soy_dueno:
		_tick_charco(snap)
	for peer_id in Net._peers:
		if peer_id != de and Net._peers[peer_id].get("lugar", "") == lugar:
			_tick_charco.rpc_id(peer_id, snap)


# --- 2) EL CORCHO: de cada pescador al dueño ---
# 'activo' false = he recogido el sedal (o he salido de la pesca): el dueño se olvida de mi corcho.
#
# OJO con el HOST que NO es dueño del piso (lo simula un cliente): mismo caso REAL que en
# solicitar_pelea, y aqui se colaba. Un rpc_id(1, ...) a uno mismo revienta con "RPC on yourself is
# not allowed", asi que el corcho del host NUNCA llegaba al dueño: veia los peces nadar, echaba el
# sedal y no le picaba jamas. Si soy el host, el enrutado me lo hago en local pasandome como
# pescador (yo soy el peer 1).
#
# LO PUBLICA TAMBIEN EL DUEÑO. Antes salia de vacio si el piso era mio -- logico cuando esto solo
# servia para pedir mordidas, que el dueño se resuelve solo --, pero ahora tambien es lo que se PINTA:
# callandolo, el dueño del piso era el unico al que nadie veia pescar. Su propio charco se ignora a si
# mismo por peer id (ver fishing_spot.corcho_de).
func publicar_corcho(pos: Vector2, esta_activo: bool) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_encaminar_corcho(1, Net._mi_lugar, pos, esta_activo)
	else:
		_corcho_pesca.rpc_id(1, Net._mi_lugar, pos, esta_activo)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _corcho_pesca(lugar: String, pos: Vector2, esta_activo: bool) -> void:
	_encaminar_corcho(multiplayer.get_remote_sender_id(), lugar, pos, esta_activo)


# El corcho va a TODOS los que esten en ese piso, no solo a quien lo simula.
#
# Antes iba unicamente al dueño, porque lo unico que se hacia con el era resolver mordidas. Pero eso
# dejaba la pesca en multi MUDA: no se veia a nadie pescar -- ni la caña, ni el hilo, ni el corcho en
# el agua --, cada uno miraba su propio sedal y el charco parecia vacio. El dueño sigue siendo el
# unico que DECIDE (ver fishing_spot.corcho_de); los demas solo lo PINTAN.
func _encaminar_corcho(de: int, lugar: String, pos: Vector2, esta_activo: bool) -> void:
	if Net._mi_lugar == lugar and _charco != null and is_instance_valid(_charco):
		_charco.corcho_de(de, pos, esta_activo)
	if not Net.es_host:
		return
	for peer_id in Net._peers:
		if peer_id != de and Net._peers[peer_id].get("lugar", "") == lugar:
			_corcho_pesca_a.rpc_id(peer_id, de, lugar, pos, esta_activo)


@rpc("authority", "call_remote", "unreliable_ordered")
func _corcho_pesca_a(de: int, lugar: String, pos: Vector2, esta_activo: bool) -> void:
	if Net._mi_lugar == lugar and _charco != null and is_instance_valid(_charco):
		_charco.corcho_de(de, pos, esta_activo)


# El CUERPO de otro jugador en mi mundo, o null. Lo pide el charco para colgarle el sedal del sitio
# correcto: un hilo que sale de la nada no dice quien esta pescando.
func cuerpo_de(peer: int):
	var a = Net._avatares.get(peer)
	return a if a != null and is_instance_valid(a) else null


# --- 3) LA MORDIDA: el dueño le dice a un pescador que ha picado, y cual ---
# Viaja el NONCE del pez, no su indice en el banco. El indice parecia valer (la lista va en el snap)
# pero NO es la misma en las dos maquinas: si una fila del snap no se pudo reconstruir, el array del
# espejo queda desplazado, y ademas el del dueño cambia entre foto y foto segun nacen y salen peces.
# El nonce es la identidad del animal y sale del mismo sorteo en los dos lados (ver _nacer_pez).
func avisar_mordida(a_quien: int, nonce: int) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_pez_pica.rpc_id(a_quien, nonce)
	else:
		_rel_mordida.rpc_id(1, a_quien, nonce)


@rpc("any_peer", "call_remote", "reliable")
func _rel_mordida(a_quien: int, nonce: int) -> void:
	if not Net.es_host:
		return
	if a_quien == 1:
		_pez_pica(nonce)
	else:
		_pez_pica.rpc_id(a_quien, nonce)


@rpc("any_peer", "call_remote", "reliable")
func _pez_pica(nonce: int) -> void:
	if _charco != null and is_instance_valid(_charco):
		_charco.me_ha_picado(nonce)


# --- 4) EL RESULTADO: el pescador le dice al dueño como acabo ---
# 'cobrado' true = me lo llevo (sale del banco y arranca su gate de 10 min); false = se escapo o
# recogi el sedal (el pez vuelve a nadar y el banco no se toca).
func resolver_pesca(nonce: int, cobrado: bool) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net._soy_dueno:
		return   # el dueño lo resuelve en local, no se manda una carta a si mismo
	# Mismo caso que en publicar_corcho: el host que solo espeja el piso no puede mandarse el
	# resultado a si mismo. Sin esto, el pez que pescaba el host no salia nunca del banco del dueño.
	if Net.es_host:
		_encaminar_fin_pesca(1, Net._mi_lugar, nonce, cobrado)
	else:
		_fin_pesca.rpc_id(1, Net._mi_lugar, nonce, cobrado)


@rpc("any_peer", "call_remote", "reliable")
func _fin_pesca(lugar: String, nonce: int, cobrado: bool) -> void:
	_encaminar_fin_pesca(multiplayer.get_remote_sender_id(), lugar, nonce, cobrado)


# SOLO host (o el propio host haciendose de pescador): el resultado va a quien simule ese piso.
func _encaminar_fin_pesca(de: int, lugar: String, nonce: int, cobrado: bool) -> void:
	if Net._mi_lugar == lugar and Net._soy_dueno and _charco != null and is_instance_valid(_charco):
		_charco.resolver_pez_remoto(de, nonce, cobrado)
		return
	if not Net.es_host:
		return
	var dueno: int = Net._dueno_de(lugar)
	if dueno != 0 and dueno != de:
		_fin_pesca_a.rpc_id(dueno, de, lugar, nonce, cobrado)


@rpc("authority", "call_remote", "reliable")
func _fin_pesca_a(de: int, lugar: String, nonce: int, cobrado: bool) -> void:
	if Net._mi_lugar == lugar and Net._soy_dueno and _charco != null and is_instance_valid(_charco):
		_charco.resolver_pez_remoto(de, nonce, cobrado)


# Al desconectarse alguien, sus corchos y sus peces enganchados se sueltan: un pez reservado por un
# fantasma se quedaria bloqueado para siempre (mismo motivo que _liberar_vetas_de).
func _liberar_pesca_de(quien: int) -> void:
	if _charco != null and is_instance_valid(_charco):
		_charco.soltar_todo_de(quien)
