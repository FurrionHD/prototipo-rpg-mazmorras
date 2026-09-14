# ============================================================
#  net_pisos.gd  (hijo de Net: /root/Net/Pisos)
#  LA MAZMORRA COMPARTIDA: entrar y salir (la expedicion), morir, las escaleras de cada uno, el DUEÑO
#  de cada piso (quien lo simula, relevos y fotos) y el aviso de pared de los brotes. El estado de los
#  dueños (_dueno_piso, _soy_dueno, _fotos_piso...) sigue en Net: lo leen casi todos los temas.
#  Se llama como Net.pisos.<funcion>.
# ============================================================
extends Node

# --- AVISO DE PARED replicado (los brotes) ----------------------------------------------------
#
# Los partos los simula UN dueño por piso, asi que el AVISO (la pared que late y tiembla) solo se
# montaba en su maquina: el compañero veia salir cuatro bichos de un muro liso, sin advertencia. El
# aviso ES la mecanica (decides si te quedas o te largas), asi que se replica a quien este en mi piso.
# Es puro FX: sin autoridad y sin estado. Va FIABLE: son pocos y sueltos, y perder uno era que al
# compañero le salieran los bichos de una pared lisa (lo vio en el playtest del 11/09/2026).
func anunciar_brote(paredes_px: Array, dur: float, amp: float, col: Color) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null or paredes_px.is_empty():
		return
	# Solo a los que estan EN MI PISO: el resto no tiene esa pared delante. El host hace de centralita
	# porque en ENet los clientes no se hablan entre ellos.
	if Net.es_host:
		for pid in Net._peers:
			if (Net._peers[pid] as Dictionary).get("lugar", "") == Net._mi_lugar:
				_pintar_brote.rpc_id(pid, paredes_px, dur, amp, col)
		return
	_rel_brote.rpc_id(1, paredes_px, dur, amp, col, Net._mi_lugar)


# Solo host: reparte el aviso de un cliente entre los demas de ESE lugar (el emisor ya lo ve).
@rpc("any_peer", "call_remote", "reliable")
func _rel_brote(paredes_px: Array, dur: float, amp: float, col: Color, lugar: String) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar:
		_pintar_brote(paredes_px, dur, amp, col)   # yo tambien estoy ahi
	for pid in Net._peers:
		if pid != de and (Net._peers[pid] as Dictionary).get("lugar", "") == lugar:
			_pintar_brote.rpc_id(pid, paredes_px, dur, amp, col)


@rpc("any_peer", "call_remote", "reliable")
func _pintar_brote(paredes_px: Array, dur: float, amp: float, col: Color) -> void:
	var piso: Node = Game.get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("pintar_aviso_pared"):
		piso.pintar_aviso_pared(paredes_px, dur, amp, col)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recibir_estado(emisor: int, pos: Vector2, _facing: Vector2, comps: Array = [],
		pose: int = 0) -> void:
	if Net._peers.has(emisor):
		Net._peers[emisor]["pos"] = pos   # se recuerda: al reconstruir su avatar aparece donde iba
	var a = Net._avatares.get(emisor)   # SIN tipar: puede ser una instancia ya liberada (ver nota abajo)
	if a != null and is_instance_valid(a):
		a.ir_a(pos)
		a.aplicar_pose(pose)   # su modo de andar, el arma fuera y el espadazo (ver empaquetar_pose)
	# Y sus acompañantes. Si aun no tengo tantos cuerpos como manda, se crean sobre la marcha (su
	# aspecto llega aparte, por _set_grupo).
	if not comps.is_empty():
		_mover_companeros(emisor, comps)


# Coloca (y crea si hacen falta) los cuerpos de los acompañantes de un peer.
func _mover_companeros(peer_id: int, posiciones: Array) -> void:
	if not Net._peers.has(peer_id) or Net._peers[peer_id].get("lugar", "") != Net._mi_lugar:
		return
	var lista: Array = Net._avatares_comp.get(peer_id, [])
	# NO crear un cuerpo de acompañante hasta tener su ASPECTO. Las posiciones llegan a 60 Hz y el
	# aspecto aparte (por _set_grupo, casi inmediato tras el handshake): crear el cuerpo antes lo
	# hacia nacer como un CUADRADO BLANCO que no se arreglaba hasta cambiar de escena. Con esto el
	# cuerpo aparece ya con su cara en cuanto llega el grupo (unos ms despues).
	var con_aspecto: int = int(Net._peers[peer_id].get("comps", []).size())
	var objetivo: int = mini(posiciones.size(), con_aspecto)
	while lista.size() < objetivo:
		var c = _crear_cuerpo_companero(peer_id, lista.size())
		if c == null:
			break
		lista.append(c)
		# El cuerpo nace AHORA (las posiciones llegan a 60 Hz, el farolillo solo cuando cambia), asi
		# que hay que darle el ultimo radio anunciado o alumbraria el suelo duro hasta que a su dueño
		# se le gastara el carbon. Mismo caso que la imbuicion en _montar_avatar.
		if c.has_method("aplicar_luz"):
			c.aplicar_luz(float(Net._peers[peer_id].get("luz", -1.0)))
	Net._avatares_comp[peer_id] = lista
	for i in mini(lista.size(), posiciones.size()):
		if is_instance_valid(lista[i]):
			lista[i].ir_a(posiciones[i])


# Un cuerpo de acompañante de otro jugador. Reusa remote_player.gd (ya es un cuerpo del grupo
# "aliado" con su interpolacion), asi que los bichos pueden perseguirlo y saltarle encima; la meta
# peer_id dice a quien mandarle la pelea.
func _crear_cuerpo_companero(peer_id: int, idx: int):
	var mundo: Node = get_tree().current_scene
	if mundo == null:
		return null
	var c: Node2D = Net._REMOTE_PLAYER.new()
	mundo.add_child(c)
	c.set_meta("peer_id", peer_id)
	var comps: Array = Net._peers[peer_id].get("comps", [])
	if idx < comps.size():
		var d: Dictionary = comps[idx]
		c.aplicar_aspecto(d.get("color", Color.WHITE), float(d.get("metal", 0.0)),
			String(d.get("nombre", "")), d.get("imagen", PackedByteArray()),
			float(d.get("alpha", 1.0)), d.get("piezas", {}), d.get("equipo", {}))
	# Su imbuicion, de lo ultimo que anuncio. Sin esto un companero recreado (al viajar, o al
	# entrar tu a la partida) nace sin rastro aunque su dueño lleve el manto puesto.
	# +1 porque el hueco 0 del paquete es el LIDER (ver Net.anunciar_imbue).
	c.aplicar_imbue(Net._imbue_en(Net._peers[peer_id].get("imbue", PackedInt32Array()), idx + 1))
	return c


# Re-anuncia MI aspecto (el del LIDER) a todos. El del lider viaja en el handshake, pero si lo
# cambias en el hogar hay que re-difundirlo o el compañero no lo ve hasta que cambies de escena
# (que es cuando _reconstruir_vista recrea el avatar con los datos nuevos de _peers).
func anunciar_aspecto() -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not Net.activo or Net.soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var c := Game.player_color
	var m := Game.player_metalico
	var n := Game.player_nombre
	var img := Game.player_imagen_png
	var al := Game.player_color_alpha
	# Y sus PIEZAS: el pelo y la ropa. Van aparte del color porque cada una lleva el suyo (ver
	# PersonajeData.aspecto). Sin esto el compañero te ve calvo y desnudo, y no da ningun error.
	var pz: Dictionary = Game.lider().aspecto_completo()["piezas"]
	# Y LO QUE LLEVA PUESTO. Mismo motivo que las piezas, un escalon mas arriba: sin esto el otro
	# jugador te ve sin armadura, sin arma y sin escudo llevaras lo que llevaras, porque las capas de
	# equipo salen de los campos equipped_* de la ficha (ver JugadorSprites._capas_armadura). Viaja la
	# IDENTIDAD de cada pieza (ruta + tier/rareza/mejoras), no el objeto: ver Game.pj_a_dict.
	var eq: Dictionary = Game.pj_a_dict(Game.lider()).get("equipo", {})
	if Net.es_host:
		for pid in Net._peers:
			_set_aspecto.rpc_id(pid, Net._mi_id(), c, m, n, img, al, pz, eq)
	else:
		_rel_aspecto.rpc_id(1, c, m, n, img, al, pz, eq)


@rpc("any_peer", "call_remote", "reliable")
func _set_aspecto(emisor: int, color: Color, metal: float, nombre: String, imagen: PackedByteArray,
		alpha: float = 1.0, piezas: Dictionary = {}, equipo: Dictionary = {}) -> void:
	if not Net._peers.has(emisor):
		return
	Net._peers[emisor]["color"] = color
	Net._peers[emisor]["metal"] = metal
	Net._peers[emisor]["nombre"] = nombre
	Net._peers[emisor]["imagen"] = imagen
	Net._peers[emisor]["alpha"] = alpha
	Net._peers[emisor]["piezas"] = piezas
	Net._peers[emisor]["equipo"] = equipo
	# Repinta su avatar YA (si lo tengo delante): sin esto el cambio no se veria hasta reconstruir.
	var a = Net._avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a != null and is_instance_valid(a) and a.has_method("aplicar_aspecto"):
		a.aplicar_aspecto(color, metal, nombre, imagen, alpha, piezas, equipo)


@rpc("any_peer", "call_remote", "reliable")
func _rel_aspecto(color: Color, metal: float, nombre: String, imagen: PackedByteArray,
		alpha: float = 1.0, piezas: Dictionary = {}, equipo: Dictionary = {}) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_aspecto(de, color, metal, nombre, imagen, alpha, piezas, equipo)
	for pid in Net._peers:
		if pid != de:
			_set_aspecto.rpc_id(pid, de, color, metal, nombre, imagen, alpha, piezas, equipo)


# --- EXPEDICION compartida (hito 3b) ---------------------------------------------------------
#
# La puerta del pueblo, en multi, pasa por aqui. El PRIMERO que entra ABRE la expedicion (piso 1,
# flujo normal); el que llega despues SE UNE al piso activo TAL CUAL esta (ni repuebla ni resetea
# nada del que ya esta dentro: cada maquina tiene su copia del piso y lo compartido viaja por Net).
# El ULTIMO que sale la cierra y se olvida, como en solitario.

# La llama door.gd (rama multi) al interactuar con la puerta del pueblo, y el menu de atajos con
# el piso elegido. Los ATAJOS si valen en multi: entrar por el piso 6 es lo mismo que entrar por el
# 1, solo cambia por donde apareces. Lo unico que sigue siendo del host es CONCEDERLO (es quien
# reparte los dueños de piso y guarda las fotos).
func solicitar_entrar(piso: int = 1) -> void:
	if Net.es_host:
		_conceder_entrada(1, piso)
	else:
		_pedir_entrar.rpc_id(1, piso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_entrar(piso: int = 1) -> void:
	if not Net.es_host:
		return
	_conceder_entrada(multiplayer.get_remote_sender_id(), piso)


# Solo host: apunta al peer como "dentro" y le concede la entrada por el piso que pide. No existe
# "el piso activo de la sesion": cada uno anda por donde quiera, asi que entrar por un atajo solo
# le mueve a EL. De paso se reparte quien simula ese piso y se le pasa su foto si estaba congelado.
#
# El piso pedido se CRIBA aqui: solo el 1 o un piso con jefe. Los atajos de cada cual son los suyos
# (los del host viajan en el handshake, los tuyos estan en tu save), y el host no puede comprobar
# los del invitado; lo que si puede es no dejar que un cliente pida el piso 500.
func _conceder_entrada(quien: int, piso: int = 1) -> void:
	if piso <= 1 or not Game.BOSSES.has(piso):
		piso = 1
	# La EPOCA de la sesion se fija UNA vez y no la mueve entrar ni salir: la mazmorra persiste, asi
	# que subir al pueblo y volver a bajar tiene que encontrar los mismos tiers. Solo la renueva
	# _olvidar_expedicion (habeis caido todos). Se coge del save del host, que es de quien es el mundo.
	if Net.epoca_sesion == 0:
		if Game.epoca_mazmorra == 0:
			Game.renovar_epoca()
		Net.epoca_sesion = Game.epoca_mazmorra
	if not Net.expedicion_abierta:
		Net.expedicion_abierta = true
		# Se abre la mazmorra: vuelven los sellos de lo que ya se pico en expediciones anteriores,
		# que estan en el save del host. Sin esto la tabla nacería vacia y todo estaria disponible.
		Net.recoleccion._sembrar_agotados_del_save()
		# Y se barren YA los que hayan cumplido su tiempo mientras no habia nadie. Va antes de
		# conceder la entrada a proposito: el que baja construye su piso con la lista de agotados que
		# le mandamos aqui abajo, asi que si esto se dejara al barrido periodico (cada 2 s) bajaria a
		# un piso sin la veta y se la veria brotar de la nada dos segundos despues.
		Net.recoleccion._barrer_respawns()
	Net._dentro[quien] = true
	Net._muertos.erase(quien)   # el que vuelve a bajar ya no cuenta como caido (ver _registrar_muerte)
	Net._trab.asegurar_dueno(piso)   # si hay un trabajador libre, el piso es suyo y yo entro de espejo
	var dueno: bool = _asignar_dueno(piso, quien)
	var mem: Dictionary = {}
	if dueno:
		mem = Net._fotos_piso.get(piso, {})
		Net._fotos_piso.erase(piso)
	# Va el diccionario ENTERO, no solo las claves: el valor es el momento en que se pico, y sin el
	# quien entra no sabria cuanto le queda a cada sitio para revivir.
	# Los jefes viajan como SEGUNDOS QUE FALTAN, no como el instante en que cayeron: el instante esta
	# en el reloj de PARED DEL HOST, y el del que recibe no tiene por que ir a la misma hora. Con
	# timestamps crudos el contador de la sala del jefe le saldria corrido por el desfase entre los dos
	# relojes (y con uno mal puesto, absurdo). Los segundos que faltan son los mismos en cualquier reloj.
	if quien == 1:
		_entrar_ok(piso, Net.recoleccion._agotados_sesion, dueno, mem, _restantes_boss(), Net.epoca_sesion, Net.recoleccion._nonces_sesion)
	else:
		_entrar_ok.rpc_id(quien, piso, Net.recoleccion._agotados_sesion, dueno, mem, _restantes_boss(),
			Net.epoca_sesion, Net.recoleccion._nonces_sesion)


# ABRIR LA SALA ESTANDO YA DENTRO DE UN PISO. Es _conceder_entrada + _entrar_ok sin viajar: el piso
# ya esta construido (en solitario) y hay que convertirlo en el de una sesion. Sin esto el host se
# quedaba con _mi_lugar "pueblo", la expedicion cerrada (las escaleras no contestaban), sin simular
# nada (los enemigos congelados) y con los enemigos fuera de _enemigos (al compañero le llegaba el
# piso vacio).
func _montar_sesion_desde_dentro(piso: int) -> void:
	if Net.epoca_sesion == 0:
		if Game.epoca_mazmorra == 0:
			Game.renovar_epoca()
		Net.epoca_sesion = Game.epoca_mazmorra
	Net.expedicion_abierta = true
	Net.recoleccion._sembrar_agotados_del_save()
	# Los NONCES tambien: las vetas de este piso nacieron con los de MI save (el piso se construyo en
	# solitario), y el que baje construira el suyo con los de la sesion. Sin sembrarlos veria otro
	# material en la misma veta.
	for p in Game.mazmorra_persistente:
		var nn = (Game.mazmorra_persistente[p] as Dictionary).get("nonces", {})
		if nn is Dictionary:
			for celda in nn:
				Net.recoleccion._nonces_sesion[Net.recoleccion._sitio(int(p), celda as Vector2i)] = int(nn[celda])
	Net.recoleccion._barrer_respawns()
	Net._dentro[1] = true
	Net._dueno_piso[piso] = 1
	Net._soy_dueno = true
	var lugar := "piso:%d" % piso
	Net.anunciar_lugar(lugar)
	# Lo que ya existe se da de alta en la red, igual que si hubiera nacido con la sesion abierta.
	var n_enem: int = 0
	for grupo in ["enemy", "corpse"]:
		for e in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(e) and not e.has_meta("net_id") and e is Node2D:
				Net.enemigos.registrar_enemigo(e, lugar)
				n_enem += 1
	# Y lo que hay por el suelo: los pickups locales pasan a ser drops de la sesion (_suelo), o el
	# compañero no los veria y yo los recogeria por la rama de solitario.
	var n_suelo: int = 0
	for pk in get_tree().get_nodes_in_group("pickup"):
		if not is_instance_valid(pk) or pk.has_meta("net_id") or pk.get("item") == null:
			continue
		var d: Dictionary = Net.suelo._item_a_dict(pk.item)
		if d.is_empty():
			continue
		var pos: Vector2 = (pk as Node2D).global_position
		pk.queue_free()
		Net.suelo._registrar_y_difundir(d, pos, lugar)
		n_suelo += 1
	print("[multi] sala abierta desde el piso %d: %d Net.enemigos y %d cosas del Net.suelo a la sesion" % [
		piso, n_enem, n_suelo])


# {piso: segundos que le faltan a ese jefe}. Solo tiene sentido en el host, que es quien lleva la
# cuenta. Ver _conceder_entrada y _marcar_boss: es la moneda con la que los jefes cruzan la red.
func _restantes_boss() -> Dictionary:
	var d: Dictionary = {}
	for piso in Net.jefes._bosses_sello:
		var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
		var pasado: float = float(Encargos.ahora()) - float(Net.jefes._bosses_sello[piso])
		d[piso] = maxf(0.0, espera - pasado)
	return d


# Corre en QUIEN entra: hace el viaje completo. olvidar_mazmorra() limpia la memoria LOCAL de
# expediciones viejas (imprescindible tambien para el que se une: si no, restauraria SUS bichos
# rancios); los agotados de LA SESION llegan del host para que las vetas ya picadas no nazcan.
#
# ESTE olvidar_mazmorra() SE QUEDA aunque en solitario se haya quitado del door.gd: en sesion la
# mazmorra persistente la lleva el HOST (_fotos_piso), y tu memoria local solo vale como cache de la
# foto que el te manda tres lineas mas abajo. Borrarla aqui es lo que impide que tu mundo propio se
# mezcle con el suyo.
@rpc("any_peer", "call_remote", "reliable")
func _entrar_ok(piso: int, agotados: Dictionary, dueno: bool, mem: Dictionary,
		sellos_boss: Dictionary = {}, epoca: int = 0, nonces: Dictionary = {}) -> void:
	Net.recoleccion._agotados_sesion = agotados.duplicate()
	# Que jefes de la sesion estan muertos ahora mismo. Sin esto, el que baja al piso 6 por el atajo
	# plantaria un rey slime que para los demas sigue muerto (y solo el lo veria).
	#
	# Llegan como SEGUNDOS QUE FALTAN (ver _conceder_entrada) y se pasan aqui a MI reloj de pared, para
	# que la resta de boss_restante valga igual en las dos maquinas. El HOST no se toca la suya: es la
	# tabla autoritativa, ya esta en su reloj, y re-hacerla desde su propio mensaje solo podria
	# estropearla con el redondeo del viaje de ida y vuelta.
	if not Net.es_host:
		Net.jefes._bosses_sello.clear()
		# 'p' y no 'piso': el parametro de esta funcion ya se llama asi (el piso al que entro).
		for p in sellos_boss:
			var espera: float = float(Game.BOSS_RESPAWN.get(p, 0.0))
			Net.jefes._bosses_sello[p] = float(Encargos.ahora()) - (espera - float(sellos_boss[p]))
	Game.current_floor = piso
	# La EPOCA y los NONCES del mundo del host: sin ellos el invitado tiraria por su cuenta que
	# material y que pez sale en cada sitio, y veria cosas distintas de las del host en la MISMA veta.
	# Se cogen ANTES de olvidar_mazmorra a proposito: esa renueva la epoca LOCAL (la de mi propio
	# mundo, que aqui no pinta nada) y lo que vale mientras dure la sesion es epoca_sesion.
	Net.recoleccion._nonces_sesion = nonces.duplicate()
	Game.olvidar_mazmorra()
	if epoca != 0:
		Net.epoca_sesion = epoca
	_olvidar_mis_enemigos()
	# ¿Simulo yo este piso? Si si, y venia congelado, se siembra la memoria LOCAL con su foto para
	# que _restaurar_estado lo levante igual que en solitario (va DESPUES de olvidar_mazmorra,
	# que la vacia entera).
	Net._soy_dueno = dueno
	if dueno and not mem.is_empty():
		Game.memoria_pisos[piso] = _mem_de_red(mem)
	# Por un ATAJO se aparece en la salida al pueblo de ESE piso (en el fondo), no en su boca:
	# mismo recado que pone floor_select_menu en solitario (lo consume DungeonFloor al construirse).
	Game.entrada_por_atajo = piso > 1
	Game.iniciar_expedicion_mapa()
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	Net.anunciar_lugar("piso:%d" % piso)


# La llama la puerta de vuelta / la salida del boss (rama multi), DESPUES de consolidar el mapa.
func viajar_al_pueblo() -> void:
	# Me llevo la foto del piso que dejo (si lo simulaba yo) para que no se pierdan sus bichos:
	# se la queda el host, o pasa al que siga dentro. Hay que sacarla ANTES de cambiar de escena.
	var foto: Dictionary = _foto_de_mi_piso()
	# El jaleo es de la bajada y se queda aqui (en sesion la foto del piso ya la lleva _foto_de_mi_piso,
	# asi que de cerrar_bajada solo hace falta esa mitad; ver Game).
	Game.cerrar_bajada()
	Net._soy_dueno = false
	_olvidar_mis_enemigos()
	if Net.es_host:
		_registrar_salida(1, foto)
	else:
		_pedir_salir.rpc_id(1, foto)
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	Net.anunciar_lugar("pueblo")


@rpc("any_peer", "call_remote", "reliable")
func _pedir_salir(foto: Dictionary) -> void:
	if not Net.es_host:
		return
	_registrar_salida(multiplayer.get_remote_sender_id(), foto)


func _registrar_salida(quien: int, foto: Dictionary = {}) -> void:
	var viejo: int = _piso_de(quien)
	Net._liberar_vetas_de(quien)
	Net.pesca._liberar_pesca_de(quien)   # sus corchos y el pez que tuviera enganchado
	_soltar_piso(quien, foto)
	Net._viajando.erase(quien)
	Net._trab.revisar_vacio(viejo, quien)
	Net._dentro.erase(quien)
	if Net._dentro.is_empty() and Net.expedicion_abierta:
		_cerrar_expedicion()


# --- MUERTE en la mazmorra (decision del usuario: que caiga UNO no cierra la mazmorra) -----------
#
# La llama Game.morir_jugador ANTES de desmontar el piso. Es la misma salida que viajar_al_pueblo
# —foto, suelto el piso, aviso al host— y por la misma razon de peso: si te vas siendo aun el dueño,
# cada bicho difunde su propia baja al morir con la escena (_exit_tree -> baja_enemigo) y al compañero
# que sigue dentro se le vacia el piso. Lo unico que cambia es lo que el host apunta: una MUERTE.
#
# Lo que NO se hace aqui es Game.cerrar_bajada(): morir_jugador ya se encarga de lo suyo (y el
# alboroto lo reinicia olvidar_mazmorra), y la foto se toma igual unas lineas mas abajo.
func morir_en_la_mazmorra() -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	var foto: Dictionary = _foto_de_mi_piso()
	Net._soy_dueno = false
	_olvidar_mis_enemigos()
	if Net.es_host:
		_registrar_muerte(1, foto)
	else:
		_pedir_muerte.rpc_id(1, foto)
	Net.anunciar_lugar("pueblo")


@rpc("any_peer", "call_remote", "reliable")
func _pedir_muerte(foto: Dictionary) -> void:
	if not Net.es_host:
		return
	_registrar_muerte(multiplayer.get_remote_sender_id(), foto)


# Solo host: 'quien' ha caido. Sale del piso igual que si volviera andando (el relevo de la
# simulacion pasa al que siga dentro, con la foto fiel), y se le apunta como MUERTO.
#
# La mazmorra compartida solo se OLVIDA cuando habeis caido todos: mientras quede un humano en pie,
# los pisos siguen como estaban. Que muera uno no puede castigar al otro —era justo el bug que se
# arreglaba aqui—, y tampoco puede borrarle la mazmorra al que esta arriba vendiendo.
func _registrar_muerte(quien: int, foto: Dictionary = {}) -> void:
	Net._muertos[quien] = true
	_registrar_salida(quien, foto)   # suelta vetas, piso y cargos (y cierra si era el ultimo dentro)
	if Net._dentro.is_empty() and Net._muertos.size() >= maxi(1, Net._num_humanos):
		_olvidar_expedicion()
	else:
		print("[multi] ha caido el peer %d (%d de %d): la mazmorra sigue en pie" % [
			quien, Net._muertos.size(), maxi(1, Net._num_humanos)])


# Solo host: habeis caido TODOS. ESTO es cerrar la mazmorra de verdad (lo otro, _cerrar_expedicion,
# solo suelta los cargos): se olvidan los pisos congelados, el botin que quedo tirado por ellos y los
# jefes se levantan. Es el equivalente en sesion de Game.olvidar_mazmorra.
#
# Lo picado (_agotados_sesion) NO entra: en solitario tampoco se pierde al morir, los sellos viven en
# mazmorra_persistente. Su CD es su CD.
func _olvidar_expedicion() -> void:
	Net._fotos_piso.clear()
	Net._traspasos.clear()
	Net._muertos.clear()
	# EPOCA NUEVA, como en solitario (Game.olvidar_mazmorra): la mazmorra vuelve a nacer, asi que se
	# rebaraja QUE hay en ella. Los nonces vivos se van con ella —ya no significan nada— y a los
	# demas les llega todo en el _entrar_ok de la proxima bajada.
	Game.renovar_epoca()
	Net.epoca_sesion = Game.epoca_mazmorra
	Net.recoleccion._nonces_sesion.clear()
	for id in Net.suelo._suelo.keys():
		if str(Net.suelo._suelo[id]["lugar"]).begins_with("piso:"):
			Net.suelo._suelo.erase(id)
			Net.suelo._despawn_drop.rpc(id)
			Net.suelo._despawn_drop(id)
	for piso in Net.jefes._bosses_sello.keys():
		Net.jefes._marcar_boss(piso, false)
		Net.jefes._marcar_boss.rpc(piso, false)
	print("[multi] habeis caido todos: la mazmorra se olvida")
	Net.estado_cambiado.emit("Habéis caído todos: la mazmorra se olvida.")


# Solo host: el ultimo salio. Se sueltan los CARGOS de la expedicion (quien simulaba cada piso, que
# vetas tenia cogidas cada cual), pero la MAZMORRA NO SE OLVIDA.
#
# Es el mismo cambio que en solitario (ver door.gd): salir todos al pueblo y volver a entrar te
# encuentra los pisos como los dejasteis, y lo que se os cayo al suelo en el piso 4 sigue ahi. Los
# dos diccionarios que lo sostienen son _fotos_piso (los pisos congelados) y _suelo (el botin
# tirado), y los dos viven en la RAM del host: cuando el host cierra el juego, la mazmorra se cierra
# para todos. Eso ES el limite acordado, no un descuido.
#
# Historia de lo que NO se limpia, para que no se "arregle" dos veces:
#   - _agotados_sesion: aqui se hacia clear() creyendo que "la proxima expedicion nace limpia, como
#     en solitario", y la premisa era falsa (en solitario los sellos viven en mazmorra_persistente).
#     Salir y volver a entrar regalaba la mazmorra entera sin CD.
#   - _fotos_piso y los drops de "piso:N": lo mismo con los bichos y el botin. Se borraban aqui.
#   - _bosses_sello: los jefes ya no vuelven porque la mazmorra se olvide, vuelven por RELOJ
#     (Game.BOSS_RESPAWN); limpiarlo aqui seria un jefe nuevo por cada viaje al pueblo.
func _cerrar_expedicion() -> void:
	Net.expedicion_abierta = false
	# Los pisos de los TRABAJADORES se quedan apuntados: su foto viene de camino (ver
	# Trabajadores.revisar_vacio) y hasta que llegue siguen siendo suyos. Borrarlos aqui perdia la foto y
	# dejaba al trabajador simulando un piso que ya nadie sabia que era suyo.
	for p in Net._dueno_piso.keys():
		if not Net.es_trabajador(int(Net._dueno_piso[p])):
			Net._dueno_piso.erase(p)
	Net._traspasos.clear()
	Net._viajando.clear()
	Net.recoleccion._vetas_ocupadas.clear()
	Net.recoleccion._t_barrido = 0.0
	Net.estado_cambiado.emit("Expedicion terminada: la mazmorra queda como la habeis dejado.")


# --- ESCALERAS: cada uno POR SU CUENTA (hito 5.2) ---------------------------------------------
#
# Bajar/subir te mueve solo a TI: el compañero se queda donde este. Antes (hito 3b) la escalera
# arrastraba a todos, lo que hacia imposible que dos estuvieran en pisos distintos.
#
# El viaje pasa por el host porque hay que repartir la SIMULACION: al irte de un piso sueltas su
# propiedad (y dejas la foto de como queda), y al llegar al nuevo el host te dice si lo simulas tu
# o solo lo espejas. Se resuelve ANTES de reconstruir el piso, que es lo que necesita saberlo.

# ¿En que piso estoy? -1 si estoy en el pueblo.
func mi_piso() -> int:
	if not Net._mi_lugar.begins_with("piso:"):
		return -1
	return int(Net._mi_lugar.substr(5))


# ¿Simulo yo los bichos del piso donde estoy? En solitario SIEMPRE (no hay red que repartir).
# Lo consultan los gates de dungeon_floor (hay_sitio, boss, poblacion).
func simulo_mi_piso() -> bool:
	# LA ARENA DE PRUEBAS ES SIEMPRE MIA. Es una sala local de dev: sus bichos los pone tu spawner,
	# no viajan por la red y nadie mas los ve. La propiedad solo se reclama en pisos de mazmorra
	# (ver _reclamar_piso), asi que en la arena _soy_dueno era false y con una sesion abierta
	# _start_combat se salia en seco SIN marcar nada ni reintentar: los bichos se te pegaban y te
	# atacaban y no se abria una sola pelea.
	if Net._mi_lugar == "sandbox":
		return true
	return (not Net.activo) or Net._soy_dueno


# CUANTOS personajes hay en MI piso, contando los grupos de los otros humanos que esten aqui.
# Lo usa el tamaño del brote: contar solo Game.party hacia que el brote saliera pequeño cuando
# estabais dos en el mismo piso, justo cuando la regla de diseño ("siempre te superan por uno")
# tenia que dar mas. En solitario devuelve tu grupo, igual que antes.
func personajes_en_mi_piso() -> int:
	# El trabajador no trae grupo: su Game.party es un personaje inventado que nadie ve.
	var n: int = 0 if Net.soy_trabajador else Game.party.size()
	if not Net.activo:
		return n
	for pid in Net._peers:
		var p: Dictionary = Net._peers[pid]
		if p.get("lugar", "") == Net._mi_lugar and not bool(p.get("trabajador", false)):
			# El humano + su sequito ("comps" son sus acompañantes, los que ves andando con el).
			n += 1 + (p.get("comps", []) as Array).size()
	return n


# La llama stairs.gd (rama multi). 'bajando' es para aparecer en la boca del piso o junto a la
# escalera, igual que en solitario.
func solicitar_piso(nuevo: int, bajando: bool) -> void:
	if nuevo < 1:
		return
	var foto: Dictionary = _foto_de_mi_piso()   # lo que dejo atras, si yo lo simulaba
	if Net.es_host:
		_conceder_piso(1, nuevo, bajando, foto)
	else:
		_pedir_viaje.rpc_id(1, nuevo, bajando, foto)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_viaje(nuevo: int, bajando: bool, foto: Dictionary) -> void:
	if not Net.es_host:
		return
	_conceder_piso(multiplayer.get_remote_sender_id(), nuevo, bajando, foto)


# Solo host: arbitra el viaje de 'quien' al piso 'nuevo'. Suelta el piso viejo (con su foto) y
# reparte el nuevo. Responde SIEMPRE, porque el viajero espera para reconstruir su piso.
func _conceder_piso(quien: int, nuevo: int, bajando: bool, foto: Dictionary) -> void:
	if not Net.expedicion_abierta:
		return
	var viejo: int = _piso_de(quien)
	_soltar_piso(quien, foto)
	Net._trab.asegurar_dueno(nuevo)
	var dueno_nuevo: bool = _asignar_dueno(nuevo, quien)
	if quien != 1:
		Net._viajando[quien] = nuevo   # hasta que llegue su _rel_lugar (ver _sigue_en)
	# El piso que deja puede quedarse sin humanos: si lo lleva un trabajador, se congela.
	if viejo != nuevo:
		Net._trab.revisar_vacio(viejo, quien)
	# Si voy a simularlo, me llevo la foto congelada de ese piso (bichos y cadaveres tal cual).
	var mem: Dictionary = {}
	if dueno_nuevo:
		mem = Net._fotos_piso.get(nuevo, {})
		Net._fotos_piso.erase(nuevo)   # ya no esta congelado: pasa a estar vivo en su dueño
	if quien == 1:
		_viaje_ok(nuevo, bajando, dueno_nuevo, mem)
	else:
		_viaje_ok.rpc_id(quien, nuevo, bajando, dueno_nuevo, mem)


# Solo host: 'quien' deja de simular el piso que tuviera. Si queda gente alli, se le pasa el
# relevo con la foto (traspaso fiel: mismos bichos, mismas posiciones). Si no queda nadie, el piso
# se CONGELA en la foto de sesion hasta que alguien vuelva.
func _soltar_piso(quien: int, foto: Dictionary) -> void:
	var piso: int = -1
	for p in Net._dueno_piso:
		if Net._dueno_piso[p] == quien:
			piso = p
			break
	if piso < 0:
		return
	Net._dueno_piso.erase(piso)
	# EL RELEVO A MEDIAS. Si 'quien' era el heredero de un traspaso que aun no ha confirmado, su foto
	# llega VACIA (no llego a simular el piso: _foto_de_mi_piso exige ser dueño), pero la de verdad la
	# tengo yo, la que le mande. Sin esto el piso se congelaba con {} y perdia todos sus enemigos.
	var pend: Dictionary = Net._traspasos.get(piso, {})
	Net._traspasos.erase(piso)
	if foto.is_empty() and int(pend.get("heredero", 0)) == quien:
		foto = pend.get("foto", {})
	var heredero: int = _alguien_en(piso, quien)
	if heredero == 0:
		# Nadie mas: el piso queda congelado tal cual. Una foto VACIA no significa "piso vacio" (esa
		# trae la clave "enemigos" aunque sea sin nadie), significa "no tengo foto": nunca pisa una buena.
		if not foto.is_empty() or not Net._fotos_piso.has(piso):
			Net._fotos_piso[piso] = foto
		return
	Net._dueno_piso[piso] = heredero
	# Los OTROS que sigan en ese piso tiran sus espejos: el dueño nuevo va a recrear los bichos con
	# ids nuevos y, sin esto, los verian por duplicado (se nota con 3-4 jugadores).
	var lugar := "piso:%d" % piso
	for pid in Net._peers:
		if pid != heredero and Net._peers[pid].get("lugar", "") == lugar:
			_limpiar_espejo.rpc_id(pid)
	if heredero != 1 and Net._mi_lugar == lugar:
		_limpiar_espejo()
	if heredero == 1:
		_asumir_piso(piso, foto)
	else:
		# Me QUEDO la foto hasta que confirme (_piso_asumido): si se va antes de procesarla, es la unica
		# copia que queda.
		Net._traspasos[piso] = {"heredero": heredero, "foto": foto}
		_asumir_piso.rpc_id(heredero, piso, foto)


# Solo host: nombra dueño de 'piso' a 'quien' si esta libre. Devuelve si le toca simularlo.
func _asignar_dueno(piso: int, quien: int) -> bool:
	var actual: int = Net._dueno_piso.get(piso, 0)
	if actual == 0 or actual == quien or not _sigue_en(actual, piso):
		Net._dueno_piso[piso] = quien
		return true
	return false


# Solo host: un peer (distinto de 'salvo') que este en ese piso, o 0 si no hay nadie.
func _alguien_en(piso: int, salvo: int) -> int:
	var lugar := "piso:%d" % piso
	if salvo != 1 and Net._mi_lugar == lugar:
		return 1            # el host tambien cuenta como candidato
	# Los TRABAJADORES no cuentan: esto pregunta por humanos (quien hereda un piso, si se ha quedado vacio).
	for id in Net._peers:
		if id != salvo and Net._peers[id].get("lugar", "") == lugar and not Net._viajando.has(id) \
				and not Net.es_trabajador(id):
			return id
	# Uno que viene de camino tambien cuenta: si el dueño se va mientras el otro aun construye, el
	# piso se le pasa a el en vez de congelarse con alguien dentro.
	for id in Net._viajando:
		if id != salvo and int(Net._viajando[id]) == piso and Net._peers.has(id) and not Net.es_trabajador(id):
			return id
	return 0


# Solo host: el piso en el que esta (o al que va) ese peer; -1 si no esta en ninguno.
func _piso_de(quien: int) -> int:
	if Net._viajando.has(quien):
		return int(Net._viajando[quien])
	var lugar: String = Net._mi_lugar if quien == 1 else str(Net._peers.get(quien, {}).get("lugar", ""))
	return int(lugar.substr(5)) if lugar.begins_with("piso:") else -1


# Solo host: ¿ese peer sigue realmente en ese piso? (dueño fantasma si se fue sin avisar).
func _sigue_en(quien: int, piso: int) -> bool:
	var lugar := "piso:%d" % piso
	if quien == 1:
		return Net._mi_lugar == lugar
	if not Net._peers.has(quien):
		return false
	if Net._viajando.has(quien):
		return int(Net._viajando[quien]) == piso   # va de camino: cuenta el piso AL QUE va, no el que deja
	return Net._peers[quien].get("lugar", "") == lugar


# Corre en EL VIAJERO: ya se sabe si simula el piso nuevo, asi que se puede reconstruir.
@rpc("any_peer", "call_remote", "reliable")
func _viaje_ok(nuevo: int, bajando: bool, dueno: bool, mem: Dictionary) -> void:
	_olvidar_mis_enemigos()   # los del piso que dejo mueren con su escena
	Net._soy_dueno = dueno
	# Sembrar la memoria LOCAL con la foto de sesion: asi _restaurar_estado (el mismo codigo que
	# en solitario) reconstruye el piso tal cual quedo. Si no lo simulo, se limpia para que no
	# resucite bichos mios rancios: los vere por red.
	if dueno and not mem.is_empty():
		Game.memoria_pisos[nuevo] = _mem_de_red(mem)
	else:
		Game.memoria_pisos.erase(nuevo)
	Game._cambiar_piso(nuevo, bajando)
	Net.anunciar_lugar("piso:%d" % nuevo)


# Corre en QUIEN HEREDA un piso donde ya esta de pie: sus cuerpos espejados se van y en su lugar
# nacen los bichos de verdad, en las mismas posiciones y con las mismas stats.
@rpc("any_peer", "call_remote", "reliable")
func _asumir_piso(piso: int, mem: Dictionary) -> void:
	if mi_piso() != piso:
		# Ya no estoy ahi (me fui entre medias): que el host se lo pase a otro con la foto que guarda.
		if not Net.es_host:
			_piso_asumido.rpc_id(1, piso, false)
		return
	Net._soy_dueno = true
	if not Net.es_host:
		_piso_asumido.rpc_id(1, piso, true)
	# CAIDA BRUSCA: al que se le corto la conexion no le dio tiempo a mandar la foto de su piso, y
	# antes se heredaba PELADO (las paredes lo repoblaban de cero, delante de tus narices). Pero yo
	# estaba alli VIENDO sus bichos: mis propios espejos son una foto casi fiel —tipo, posicion,
	# tirada y heridas—. Se toma ANTES de tirarlos, que es justo lo siguiente que pasa.
	if (mem.get("enemigos", []) as Array).is_empty():
		mem = _foto_de_mis_espejos()
	_limpiar_espejo()   # respeta los que esté peleando (ver alli)
	var piso_nodo: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso_nodo != null and piso_nodo.has_method("adoptar_foto"):
		piso_nodo.adoptar_foto(_mem_de_red(mem))


# Solo host: el heredero de un traspaso contesta. Bien -> la copia guardada ya sobra. Mal (ya no estaba
# en ese piso) -> si sigue apuntado como dueño, se suelta otra vez y la foto guardada va al siguiente.
@rpc("any_peer", "call_remote", "reliable")
func _piso_asumido(piso: int, ok: bool) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	var pend: Dictionary = Net._traspasos.get(piso, {})
	if ok:
		if int(pend.get("heredero", 0)) == de:
			Net._traspasos.erase(piso)
		return
	if int(Net._dueno_piso.get(piso, 0)) == de:
		_soltar_piso(de, {})


# --- FOTO de un piso: el formato de Game.memoria_pisos, apto para la red -----------------------
# Se manda la RUTA del EnemyData (.tres de disco) en vez del recurso, como ya se hace con los
# materiales del suelo (ver _item_a_dict). load() cachea, asi que al rehidratar sale la MISMA
# instancia y la comparacion de identidad del boss (dungeon_floor._restaurar_estado) sigue valiendo.
# El "suelo" NO va: en sesion los drops los lleva Net (_suelo/_drops); meterlos aqui los duplicaria.
func _foto_de_mi_piso() -> Dictionary:
	if not Net.activo or not Net._soy_dueno:
		return {}
	var piso := mi_piso()
	if piso < 0:
		return {}
	var f: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if f != null and f.has_method("volcar_a_memoria"):
		f.volcar_a_memoria()   # vuelca los bichos VIVOS de ahora mismo a Game.memoria_pisos
	return _mem_a_red(Game.memoria_pisos.get(piso, {}))


# La foto del piso reconstruida a partir de MIS ESPEJOS. Solo se usa al heredar un piso cuyo dueño
# se cayo de golpe (ver _asumir_piso). No sale la ZONA (un espejo no la sabe: la ocupacion de cada
# sala la llevaba el dueño), asi que se deja en -1 y la resuelve por posicion el que restaura.
func _foto_de_mis_espejos() -> Dictionary:
	var out: Array = []
	for id in Net.enemigos._enem_nodos.keys():
		var n = Net.enemigos._enem_nodos[id]   # SIN tipar: puede estar liberado (ver cabecera)
		if not is_instance_valid(n) or n.data == null:
			continue
		if String(n.data.resource_path).is_empty():
			continue
		out.append({"ruta": n.data.resource_path, "pos": n.global_position,
			"t": n.current_t, "zona": -1, "muerto": n.esta_muerto(),
			"hp": n.hp_restante})
	if not out.is_empty():
		print("[piso] heredo sin foto (se cayo el dueño): la rehago con %d espejos mios" % out.size())
	return {"enemigos": out}


func _mem_a_red(mem: Dictionary) -> Dictionary:
	var out: Array = []
	for d in (mem.get("enemigos", []) as Array):
		var data = d.get("data")
		if data == null or String(data.resource_path).is_empty():
			continue   # un EnemyData creado en runtime no se puede mandar por ruta
		out.append({
			"ruta": data.resource_path,
			"pos": d["pos"], "t": d["t"], "zona": d["zona"], "muerto": d["muerto"],
			"hp": d.get("hp", -1.0),   # las heridas viajan con el piso, como en solitario
		})
	return {"enemigos": out}


# Dejo de simular el piso donde estaba: sus bichos mueren con la escena, asi que su registro se va
# con ellos. Si no, las entradas rancias se quedan pegadas (y el dia que vuelva a ser dueño de algo
# las difundiria). Se llama SIEMPRE antes de reconstruir/abandonar un piso, y despues de sacar la
# foto: baja_enemigo no sirve aqui porque se cae por el guard de _soy_dueno.
func _olvidar_mis_enemigos() -> void:
	Net.enemigos._enemigos.clear()
	Net.peleas._enem_ocupados.clear()   # las reservas eran de esos bichos: se van con ellos
	if not Net.extraccion._extrayendo.is_empty():
		Net.extraccion._extrayendo.clear()
		Net.extraccion._difundir_extrayendo()   # y nadie debe seguir viendo esos cuerpos como ocupados


# El dueño de un piso ha cambiado: los que sigan ahi tiran sus cuerpos espejados, porque el dueño
# nuevo va a recrear los bichos con ids nuevos (si no, se verian por duplicado).
#
# MENOS los que estoy PELEANDO: el combate guarda esos nodos (Game._active_enemies) y borrarlos deja
# la pelea con referencias muertas -> la pantalla se queda colgada y el jugador NO PUEDE MOVERSE.
# Se quedan hasta que termine la pelea; al acabar, su resultado se resuelve en local (ver
# remote_enemy.morir), porque para entonces el dueño al que habria que avisar ya no esta.
@rpc("any_peer", "call_remote", "reliable")
func _limpiar_espejo() -> void:
	for id in Net.enemigos._enem_nodos.keys():
		var n = Net.enemigos._enem_nodos[id]
		if not is_instance_valid(n):
			Net.enemigos._enem_nodos.erase(id)
			continue
		if Game.combate_activo() and Game._active_enemies.has(n):
			continue   # esta en mi pelea: no se toca
		n.retirar()
		Net.enemigos._enem_nodos.erase(id)


func _mem_de_red(mem: Dictionary) -> Dictionary:
	var out: Array = []
	for d in (mem.get("enemigos", []) as Array):
		var data = load(str(d["ruta"]))
		if data == null:
			continue
		out.append({
			"data": data,
			"pos": d["pos"], "t": d["t"], "zona": d["zona"], "muerto": d["muerto"],
			"hp": d.get("hp", -1.0),
		})
	return {"enemigos": out, "suelo": []}
