# ============================================================
#  net_recoleccion.gd  (hijo de Net: /root/Net/Recoleccion)
#  VETAS, PLANTAS Y RESPAWN en multi: una veta la trabaja uno a la vez ("esta ocupado"), lo agotado se
#  apunta en la sesion con su momento y su NONCE (que material nacio ahi), y el host barre y revive por
#  reloj de pared. Se llama como Net.recoleccion.<funcion>.
# ============================================================
extends Node

# NONCE VIVO de cada sitio de recoleccion de la sesion: sitio -> el numero con el que nacio lo que
# hay ahi ahora. Hermano de _agotados_sesion y con su misma clave (Vector3i(piso, x, y)).
#
# Es lo que hace que el sub-tier de una veta SOBREVIVA a reconstruir el piso: sin esto, al bajar y
# volver a subir la celda renacia con nonce 0 y volvia a ser lo de siempre. Lo estrena _revivir_celda
# (respawn) y lo reparte _entrar_ok al que baja.
var _nonces_sesion: Dictionary = {}
# CLAVE de un sitio de recoleccion: Vector3i(piso, celda.x, celda.y). Va el PISO dentro a
# proposito: los pisos se generan con el mismo molde y repiten coordenadas, asi que con la celda
# pelada picar una veta en el piso 3 borraba la del mismo hueco en el 4.
var _vetas_ocupadas: Dictionary = {}  # sitio -> peer_id que la trabaja (host)
# sitio -> momento en que se pico. El VALOR es lo que permite el respawn: el host barre la tabla y
# suelta lo que ya ha cumplido su tiempo (ver _barrer_respawns).
#
# EL RELOJ ES EL DE PARED (Game.reloj_mundo, unix time), el mismo que en una partida de un jugador.
# Hubo dos antes que este y los dos se rompian por el mismo sitio: un `_reloj_expedicion` propio, que
# moria con la expedicion y al volver a bajar te encontrabas TODAS las vetas otra vez; y
# tiempo_mazmorra, que ademas de eso se CONGELA con cualquier menu abierto -- y como aqui barre el
# HOST, bastaba con que el anfitrion tuviera el hogar abierto para que las vetas no volvieran para
# nadie. Con el reloj de pared no hay nada que congelar ni que se muera al salir: cinco minutos son
# cinco minutos en las dos maquinas, aunque las dos esten en un menu.
var _agotados_sesion: Dictionary = {}
var _t_barrido := 0.0
const BARRIDO_RESPAWN_CADA := 2.0   # cada cuanto repasa el host la tabla (igual que en solitario)


# --- VETAS: una a la vez, con "esta ocupado" --------------------------------------------------

# La clave de un sitio: el piso va DENTRO (ver _agotados_sesion).
func _sitio(piso: int, celda: Vector2i) -> Vector3i:
	return Vector3i(piso, celda.x, celda.y)


# La llama resource_node.interactuar() (rama multi): pedir la veta antes de abrir el minijuego.
func solicitar_veta(celda: Vector2i, piso: int) -> void:
	if Net.es_host:
		_resolver_veta(celda, piso, 1)
	else:
		_pedir_veta.rpc_id(1, celda, piso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_veta(celda: Vector2i, piso: int) -> void:
	if not Net.es_host:
		return
	_resolver_veta(celda, piso, multiplayer.get_remote_sender_id())


# Solo host: arbitra. Libre -> lock y concedida; ocupada -> "esta ocupado" (AQUI si hay mensaje,
# regla del usuario; en los drops del suelo, silencio).
func _resolver_veta(celda: Vector2i, piso: int, quien: int) -> void:
	var s: Vector3i = _sitio(piso, celda)
	if _agotados_sesion.has(s):
		return   # ya no existe: su nodo esta cayendo, no hay nada que decir
	if _vetas_ocupadas.has(s) and _vetas_ocupadas[s] != quien:
		if quien == 1:
			_veta_ocupada()
		else:
			_veta_ocupada.rpc_id(quien)
		return
	_vetas_ocupadas[s] = quien
	if quien == 1:
		_veta_concedida(celda)
	else:
		_veta_concedida.rpc_id(quien, celda)


@rpc("any_peer", "call_remote", "reliable")
func _veta_concedida(celda: Vector2i) -> void:
	for n in get_tree().get_nodes_in_group("recolectable"):
		if is_instance_valid(n) and n.celda == celda:
			n.abrir_minijuego()
			return


@rpc("any_peer", "call_remote", "reliable")
func _veta_ocupada() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("Esta ocupado: tu companero ya lo esta trabajando.")


# La llama Game._cerrar_recoleccion (rama multi) al terminar el minijuego de una celda.
#
# 'retraso' = lo que ESTE sitio tarda de mas en volver (la despensa, el doble; ver
# Game.RESPAWN_RETRASO_DESPENSA). Viaja con el mensaje porque el host no puede deducirlo: solo
# recibe la celda, y puede no estar ni en ese piso para mirar que hay plantado en ella.
func notificar_agotado(celda: Vector2i, piso: int, retraso: float = 0.0) -> void:
	if Net.es_host:
		_registrar_agotado(celda, piso, retraso)
	else:
		_pedir_agotar.rpc_id(1, celda, piso, retraso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_agotar(celda: Vector2i, piso: int, retraso: float = 0.0) -> void:
	if not Net.es_host:
		return
	_registrar_agotado(celda, piso, retraso)


# Solo host: suelta el lock, sella el sitio con la hora (es lo que hara que reviva), lo APUNTA EN SU
# SAVE y difunde el agotado a todos.
#
# Lo del save es lo que hace que el CD sobreviva a que salgais todos: la mazmorra es la del mundo del
# host, asi que sus sellos van a mazmorra_persistente igual que en una partida de un jugador, y de
# ahi se vuelven a sembrar en la siguiente expedicion (ver _sembrar_agotados_del_save).
func _registrar_agotado(celda: Vector2i, piso: int, retraso: float = 0.0) -> void:
	var s: Vector3i = _sitio(piso, celda)
	var sello: float = Game.reloj_mundo() + retraso
	_vetas_ocupadas.erase(s)
	_agotados_sesion[s] = sello
	(Game.persistente_piso(piso)["agotados"] as Dictionary)[celda] = sello
	_agotar_celda.rpc(celda, piso, retraso)
	_agotar_celda(celda, piso, retraso)


# Corre en TODOS los que esten en la mazmorra: la veta de ese sitio desaparece tambien aqui.
# A los clientes el VALOR del sello no les sirve de nada, solo la presencia ("esto no esta"): quien
# decide el respawn es el host, en _barrer_respawns.
#
# En el host esto corre justo despues de _registrar_agotado (que lo llama directo), asi que tiene que
# sellar con el MISMO reloj o le pisaria el valor bueno al que se acaba de guardar en el save.
@rpc("any_peer", "call_remote", "reliable")
func _agotar_celda(celda: Vector2i, piso: int, retraso: float = 0.0) -> void:
	_agotados_sesion[_sitio(piso, celda)] = Game.reloj_mundo() + retraso
	if not Net._mi_lugar.begins_with("piso:") or Game.current_floor != piso:
		return
	var piso_nodo: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso_nodo != null and piso_nodo.has_method("marcar_agotado"):
		piso_nodo.marcar_agotado(celda, retraso)
	for n in get_tree().get_nodes_in_group("recolectable"):
		if is_instance_valid(n) and n.celda == celda:
			n.agotar()
			return


# SOLO HOST: repasa los sitios picados y suelta los que ya han cumplido su tiempo. Es el equivalente
# por red de dungeon_floor._repoblar_agotados, con la diferencia que importa: aqui manda UN reloj (el
# tiempo_mazmorra DEL HOST) en vez del de cada maquina, que es local y diverge, asi que la veta
# revive en todas a la vez. Antes esto no existia y lo picado en sesion no volvia NUNCA.
func _barrer_respawns() -> void:
	# Los JEFES ya NO cuelgan de aqui: tienen su propio latido en _process, por encima del guard de
	# expedicion_abierta (su reloj es de pared y corre con la mazmorra vacia). Se sigue llamando desde
	# _conceder_entrada, y esa llamada tambien tiene que ponerlos al dia: es la que planta al jefe ya
	# de pie ANTES de conceder la entrada, para que el que baja no lo vea aparecer de la nada.
	Net.jefes._barrer_bosses()
	if _agotados_sesion.is_empty():
		return
	for s in _agotados_sesion.keys():
		if Game.reloj_mundo() - float(_agotados_sesion[s]) < Game.RESPAWN_SEGUNDOS:
			continue
		_agotados_sesion.erase(s)
		var celda := Vector2i(s.y, s.z)
		# El NONCE lo pone el host y viaja con el mensaje: es lo que hace que la tirada del material
		# salga IGUAL en todas las maquinas (ver dungeon_floor._material_del_sitio). Antes cada una
		# tiraba por su cuenta y la misma veta salia de cobre normal en una y veteado en la otra.
		var nonce: int = randi()
		_revivir_celda.rpc(celda, s.x, nonce)
		_revivir_celda(celda, s.x, nonce)


# SOLO HOST: rellena la tabla de la sesion con los sellos que quedaron guardados en el save. Se llama
# al abrir la expedicion, y es la otra mitad de que el CD sobreviva: _registrar_agotado los escribe
# en mazmorra_persistente, y esto los vuelve a traer cuando alguien baja de nuevo. Sin esto, la
# tabla nacia vacia en cada sesion (se limpia al montarla) y daba igual lo que hubiera en el save.
func _sembrar_agotados_del_save() -> void:
	if not Net.es_host:
		return
	for piso in Game.mazmorra_persistente:
		var ag = (Game.mazmorra_persistente[piso] as Dictionary).get("agotados", {})
		if not (ag is Dictionary):
			continue
		for celda in ag:
			_agotados_sesion[_sitio(int(piso), celda as Vector2i)] = float(ag[celda])
	if not _agotados_sesion.is_empty():
		print("[multi] sembrados %d sitios ya picados de expediciones anteriores" % _agotados_sesion.size())


# Corre en TODOS: se levanta el sello y, si estoy en ese piso, brota el nodo otra vez (con el
# material RE-TIRADO, igual que en solitario). Si no estoy alli basta con soltar el sello: cuando
# baje, el piso se construye y la celda vuelve a nacer sola.
@rpc("any_peer", "call_remote", "reliable")
func _revivir_celda(celda: Vector2i, piso: int, nonce: int = 0) -> void:
	_agotados_sesion.erase(_sitio(piso, celda))
	# El nonce se APUNTA, no solo se usa: es lo que hace que el sub-tier con el que acaba de brotar
	# siga siendo el mismo cuando alguien reconstruya el piso (bajar y volver a subir). Sin esto, la
	# veta que revivio de estaño profundo volvia a ser la de siempre en cuanto se rehacia la escena.
	_nonces_sesion[_sitio(piso, celda)] = nonce
	# Y FUERA DEL SAVE DEL HOST, o el sello volveria a sembrarse en la proxima expedicion y la veta
	# que acaba de revivir nacería agotada otra vez. Es lo mismo que hace _olvidar_agotado en
	# solitario. Solo el host: en el invitado ese diccionario es de SU mundo, no de este.
	if Net.es_host:
		(Game.persistente_piso(piso)["agotados"] as Dictionary).erase(celda)
	if not Net._mi_lugar.begins_with("piso:") or Game.current_floor != piso:
		return
	var piso_nodo: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso_nodo != null and piso_nodo.has_method("revivir_celda"):
		piso_nodo.revivir_celda(celda, nonce)


# ¿Este sitio ya se agoto en ESTA expedicion? Lo consulta dungeon_floor al construir el piso.
func celda_agotada_sesion(celda: Vector2i, piso: int) -> bool:
	return _agotados_sesion.has(_sitio(piso, celda))


# Con que nonce nacio lo que hay AHORA en ese sitio (0 = lo original de esta epoca, nunca ha
# rebrotado). Lo consulta dungeon_floor al construir el piso, igual que celda_agotada_sesion.
func nonce_celda_sesion(celda: Vector2i, piso: int) -> int:
	return int(_nonces_sesion.get(_sitio(piso, celda), 0))


# El HOST decide que vetas y plantas reviven. El reloj del respawn es de pared (ver _barrer_respawns):
# aqui solo se marca cada cuanto tocar la tabla, y solo con la expedicion abierta.
func _process(delta: float) -> void:
	if not Net.activo or not Net.es_host or not Net.expedicion_abierta:
		return
	_t_barrido -= delta
	if _t_barrido <= 0.0:
		_t_barrido = BARRIDO_RESPAWN_CADA
		_barrer_respawns()
