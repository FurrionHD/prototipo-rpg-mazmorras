# ============================================================
#  net_enemigos.gd  (hijo de Net: /root/Net/Enemigos)
#  EL CANAL DE ENEMIGOS: el dueño del piso da de alta, mueve y da de baja a sus bichos y los demas
#  los ven en espejo (remote_enemy). Se llama como Net.enemigos.<funcion>. Las RESERVAS de pelea y
#  la extraccion viven con las peleas; lo comun de la sesion sigue en Net.
# ============================================================
extends Node

# En multi los enemigos los SIMULA el host (IA, spawns, aforo: su codigo de siempre); los
# clientes solo los VEN. El host es la fuente de verdad: _enemigos apunta cada bicho vivo por id,
# con su NODO real (para leer su posicion en el tick), su LUGAR y su aspecto. Los clientes montan
# un remote_enemy por id en _enem_nodos. Mismo patron que _suelo/_drops.
#
# LIMITE de 5.1 (a resolver en la siguiente sub-fase): el host solo simula el piso en el que ESTA
# (su current_scene). Un cliente en OTRO piso no ve bichos (nadie los simula alli todavia). El
# etiquetado por lugar ya deja el canal listo para autoridad por-piso cuando toque.
const _REMOTE_ENEMY := preload("res://scripts/actors/enemy/remote_enemy.gd")
var _enemigos: Dictionary = {}     # id -> {"nodo","lugar","color","lado"} (solo lo llena el host)
var _enem_nodos: Dictionary = {}   # id -> nodo remote_enemy (en los CLIENTES)
var _enem_next_id: int = 1         # contador de ids de enemigo del host
const _ENEM_TICK := 1.0 / 20.0     # ritmo de difusion de posiciones (~20 Hz, suave y barato)
var _enem_acum: float = 0.0


# --- ENEMIGOS replicados (hito 5.1, repartidos por dueño en 5.2) -----------------------------
#
# Lo llama el DUEÑO del piso al CREAR un bicho (dungeon_floor.crear_enemigo, ya con su posicion
# puesta): le asigna id, lo apunta y lo difunde a los que esten en ese piso. En solitario, o si
# solo espejo el piso, no hace NADA -> cero impacto en un jugador.
#
# RETRANSMISION: en la topologia estrella de Godot un cliente NO tiene socket con otro cliente, asi
# que si el dueño es un cliente sus bichos van cliente -> HOST -> los demas. Si el dueño es el
# host, difunde directo. (En LAN el salto extra son ~1-2 ms, nada al lado del tick de 20 Hz.)
func registrar_enemigo(nodo: Node2D, lugar: String) -> void:
	if not Net.activo or not Net._soy_dueno or nodo == null or multiplayer.multiplayer_peer == null:
		return
	# El id lleva DENTRO quien lo creo: con varios dueños simulando pisos a la vez, un contador
	# suelto en cada maquina chocaria. Asi son unicos sin preguntarle nada a nadie.
	var id := multiplayer.get_unique_id() * 1000000 + _enem_next_id
	_enem_next_id += 1
	nodo.set_meta("net_id", id)   # el id de red viaja como meta, sin tocar la clase enemy
	_enemigos[id] = {"nodo": nodo, "lugar": lugar}
	var d: Dictionary = _datos_enemigo(nodo)
	if Net.es_host:
		_spawn_enemigo.rpc(id, lugar, nodo.global_position, d)
	else:
		_rel_spawn.rpc_id(1, id, lugar, nodo.global_position, d)


# TODO lo que el otro necesita para pintarlo Y para pelearlo/extraerlo: su aspecto (color y lado,
# ya con el tinte de su 't') y sus DATOS (ruta del .tres + 't' + si ya es cadaver). Se lee del nodo
# EN VIVO, asi que un cadaver sale gris y marcado sin tener que avisar aparte.
func _datos_enemigo(nodo: Node) -> Dictionary:
	var d := {"color": Color.WHITE, "lado": 32.0, "ruta": "", "t": 0.5, "muerto": false,
		"vis": 130.0, "ang": 50.0}
	if nodo == null or not is_instance_valid(nodo):
		return d
	# Alcance y apertura de su cono: van en el ALTA (una vez por bicho), no en el tick.
	d["vis"] = float(nodo.get("vision_range"))
	d["ang"] = float(nodo.get("vision_half_angle_deg"))
	if nodo.has_method("aspecto_red"):
		var a: Dictionary = nodo.aspecto_red()
		d["color"] = a.get("color", d["color"])
		d["lado"] = a.get("lado", d["lado"])
	var ed = nodo.get("data")
	if ed != null:
		d["ruta"] = String(ed.resource_path)
	d["t"] = float(nodo.get("current_t"))
	# MUTANTE (mini-jefe). Va en el ALTA como la 't' y por lo mismo: no se puede volver a tirar el
	# dado en la otra maquina o cada uno tendria sus propios mini-jefes -- el invitado veria una rata
	# normal donde el anfitrion pelea un mutante con el triple de vida.
	d["mut"] = bool(nodo.get("mutante"))
	# Y si es el JEFE del piso. Hace falta para el aspecto: un jefe mutante se agranda MENOS que un
	# bicho mutante corriente (ver EnemyData.mult_mutante), asi que sin esto el espejo lo pintaria
	# con la escala equivocada.
	d["boss"] = bool(nodo.get("es_boss"))
	if nodo.has_method("esta_muerto"):
		d["muerto"] = bool(nodo.esta_muerto())
	return d


# Lo llama el dueño cuando un bicho DESAPARECE del mundo (reciclado, piso desmontado): lo borra
# del registro y avisa para que quiten su cuerpo. Un cadaver NO llama a esto: la muerte replicada
# es de una sub-fase posterior (con el combate).
func baja_enemigo(nodo: Node) -> void:
	if not Net.activo or not Net._soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	if not _enemigos.has(id):
		return
	var lugar: String = _enemigos[id]["lugar"]
	_enemigos.erase(id)
	if Net.es_host:
		_despawn_enemigo.rpc(id)
	else:
		_rel_despawn.rpc_id(1, id, lugar)


# --- RETRANSMISION (solo host): lo que le manda un dueño CLIENTE se reparte a los de ese piso ---
# Al emisor no se le devuelve (ya tiene el bicho de verdad), y el propio host lo pinta si esta
# en ese piso sin ser su dueño.

@rpc("any_peer", "call_remote", "reliable")
func _rel_spawn(id: int, lugar: String, pos: Vector2, d: Dictionary) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar and not Net._soy_dueno:
		_spawn_enemigo(id, lugar, pos, d)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			_spawn_enemigo.rpc_id(pid, id, lugar, pos, d)


# Lo llama enemy.morir() en la maquina que SIMULA el piso: el bicho pasa a cadaver y hay que
# decirselo a los demas (el nodo NO se libera al morir, asi que _exit_tree/baja_enemigo no salta).
func enemigo_muerto(nodo: Node) -> void:
	if not Net.activo or not Net._soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	if not _enemigos.has(id):
		return
	_enemigos[id]["muerto"] = true
	var lugar: String = _enemigos[id]["lugar"]
	if Net.es_host:
		_marcar_cadaver.rpc(id, lugar)
	else:
		_rel_cadaver.rpc_id(1, id, lugar)


@rpc("authority", "call_remote", "reliable")
func _marcar_cadaver(id: int, lugar: String) -> void:
	if lugar != Net._mi_lugar:
		return
	var n = _enem_nodos.get(id)
	if n != null and is_instance_valid(n) and n.has_method("marcar_cadaver"):
		n.marcar_cadaver()


@rpc("any_peer", "call_remote", "reliable")
func _rel_cadaver(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar and not Net._soy_dueno:
		_marcar_cadaver(id, lugar)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			_marcar_cadaver.rpc_id(pid, id, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_despawn(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar and not Net._soy_dueno:
		_despawn_enemigo(id)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			_despawn_enemigo.rpc_id(pid, id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rel_tick(lugar: String, lote: Array) -> void:
	if not Net.es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar and not Net._soy_dueno:
		_tick_enemigos(lote)
	for pid in Net._peers:
		if pid != de and Net._peers[pid].get("lugar", "") == lugar:
			_tick_enemigos.rpc_id(pid, lote)


# Le llega al dueño CLIENTE de un piso: alguien acaba de entrar ahi y necesita su lista de bichos.
# La respuesta vuelve a pasar por el host, que la reenvia solo a ese peer.
@rpc("any_peer", "call_remote", "reliable")
func _pedir_roster(lugar: String, para: int) -> void:
	if Net._mi_lugar != lugar or not Net._soy_dueno:
		return
	for id in _enemigos:
		var e: Dictionary = _enemigos[id]
		if is_instance_valid(e["nodo"]):
			_rel_spawn_a.rpc_id(1, para, id, lugar, (e["nodo"] as Node2D).global_position,
				_datos_enemigo(e["nodo"]))


@rpc("any_peer", "call_remote", "reliable")
func _rel_spawn_a(para: int, id: int, lugar: String, pos: Vector2, d: Dictionary) -> void:
	if not Net.es_host:
		return
	if para == 1:
		_spawn_enemigo(id, lugar, pos, d)
	else:
		_spawn_enemigo.rpc_id(para, id, lugar, pos, d)


@rpc("authority", "call_remote", "reliable")
func _spawn_enemigo(id: int, lugar: String, pos: Vector2, d: Dictionary) -> void:
	if lugar != Net._mi_lugar:
		return   # eso esta en OTRO piso: aqui no se pinta
	if _enem_nodos.has(id) and is_instance_valid(_enem_nodos[id]):
		return   # ya lo tengo (llego dos veces: difusion + peticion de late-join)
	var mundo: Node = get_tree().current_scene
	if mundo == null:
		return
	var cuerpo: Node2D = _REMOTE_ENEMY.new()
	mundo.add_child(cuerpo)
	cuerpo.global_position = pos
	cuerpo.set_meta("net_id", id)   # para pedir pelea/extraccion por el
	cuerpo.configurar(d.get("color", Color.WHITE), float(d.get("lado", 32.0)),
		int(d.get("elem", Elementos.Elemento.NINGUNO)), float(d.get("einten", 1.0)))
	cuerpo.es_boss = bool(d.get("boss", false))   # antes de aplicar_datos: decide su escala si muto
	cuerpo.aplicar_datos(String(d.get("ruta", "")), float(d.get("t", 0.5)),
		bool(d.get("muerto", false)), float(d.get("vis", 130.0)), float(d.get("ang", 50.0)),
		bool(d.get("mut", false)))
	_enem_nodos[id] = cuerpo


@rpc("authority", "call_remote", "reliable")
func _despawn_enemigo(id: int) -> void:
	var n = _enem_nodos.get(id)
	if n != null and is_instance_valid(n):
		n.retirar()
	_enem_nodos.erase(id)


# Difusion de POSICIONES: la hace el DUEÑO del piso, a ~20 Hz desde _physics_process. Un lote
# [[id, pos], ...] no fiable y ordenado, como la posicion del jugador (perder un paquete no
# importa, el siguiente corrige). Todos mis bichos son de MI piso, asi que el lote es uno solo.
func _difundir_posiciones_enemigos() -> void:
	# Purga de nodos muertos (reciclados sin pasar por baja, por si acaso). SIN tipar la variable:
	# asignar una instancia YA LIBERADA a un `var: Node` lanza error en Godot 4; hay que leerla
	# cruda y dejar que is_instance_valid la descarte.
	for id in _enemigos.keys():
		var nodo = _enemigos[id]["nodo"]
		if not is_instance_valid(nodo):
			var lug: String = _enemigos[id]["lugar"]
			_enemigos.erase(id)
			if Net.es_host:
				_despawn_enemigo.rpc(id)
			else:
				_rel_despawn.rpc_id(1, id, lug)
	if _enemigos.is_empty():
		return
	# Cada bicho manda [id, pos, angulo_de_mirada, avisando_el_golpe]. Los dos ultimos NO son
	# adorno: con ellos el que solo lo ve espejado pinta su CONO DE VISION y su linea de direccion,
	# que es lo unico que permite jugar al sigilo.
	var lote: Array = []
	for id in _enemigos:
		var nd = _enemigos[id]["nodo"]
		var est: Array = nd.estado_visual_red() if nd.has_method("estado_visual_red") else [0.0, false, 0]
		# El QUINTO, de quien es la pelea en la que esta metido (0 = suelto). Va en el tick y no en un
		# aviso suelto a proposito: una pelea se abre y se cierra por media docena de caminos (reservar,
		# empujar, devolver, morir, traspasar...), y un estado que se repite 20 veces por segundo no se
		# desincroniza aunque alguno de esos caminos se olvide de avisar.
		# El SEXTO, el contador de embestidas: con el suena la embestida en los PCs que solo la espejan.
		# El SEPTIMO, si esta EMBISTIENDO ahora mismo: es lo que hace que el espejo enseñe el gesto de
		# ataque ENTERO y no solo el parpadeo del aviso (ver enemy.estado_visual_red).
		lote.append([id, (nd as Node2D).global_position, est[0], est[1], Net.peleas._anfitrion_de_enemigo(id, nd),
			est[2] if est.size() >= 3 else 0, est[3] if est.size() >= 4 else false])
	if Net.es_host:
		for peer_id in Net._peers:
			if Net._peers[peer_id].get("lugar", "") == Net._mi_lugar:
				_tick_enemigos.rpc_id(peer_id, lote)
	else:
		_rel_tick.rpc_id(1, Net._mi_lugar, lote)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _tick_enemigos(lote: Array) -> void:
	for par in lote:
		var n = _enem_nodos.get(par[0])
		if n == null or not is_instance_valid(n):
			continue
		n.ir_a(par[1])
		if par.size() >= 4:
			# El septimo (embistiendo) va JUNTO con el aviso y no en una llamada aparte: los dos deciden
			# la misma animacion, y aplicarlos por separado dejaria un fotograma con uno viejo y otro nuevo.
			n.aplicar_estado_visual(float(par[2]), bool(par[3]), bool(par[6]) if par.size() >= 7 else false)
		if par.size() >= 5:
			n.pelea_de = int(par[4])
		if par.size() >= 6:
			n.aplicar_embestida(int(par[5]))


# Alguien que acaba de llegar a un piso pide sus enemigos (late-join / cambio de piso). Siempre se
# le pregunta al HOST, que es quien sabe QUIEN simula ese piso: si es el, responde; si es un
# cliente, le reenvia la peticion para que conteste el (via _pedir_roster).
@rpc("any_peer", "call_remote", "reliable")
func _pedir_enemigos(lugar: String) -> void:
	if not Net.es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if Net._mi_lugar == lugar and Net._soy_dueno:
		for id in _enemigos:
			var e: Dictionary = _enemigos[id]
			if is_instance_valid(e["nodo"]):
				_spawn_enemigo.rpc_id(quien, id, lugar, (e["nodo"] as Node2D).global_position,
					_datos_enemigo(e["nodo"]))
		return
	var piso: int = int(lugar.substr(5)) if lugar.begins_with("piso:") else -1
	var dueno: int = Net._dueno_piso.get(piso, 0)
	if dueno != 0 and dueno != quien:
		_pedir_roster.rpc_id(dueno, lugar, quien)


# El DUEÑO del piso difunde las posiciones de SUS enemigos a ~20 Hz. En solitario, o si solo espejo el
# piso, no hace nada. Va en _physics_process para leer las posiciones ya resueltas por la fisica del bicho.
func _physics_process(delta: float) -> void:
	if not Net.activo or not Net._soy_dueno or _enemigos.is_empty() or multiplayer.multiplayer_peer == null:
		return
	_enem_acum += delta
	if _enem_acum < _ENEM_TICK:
		return
	_enem_acum = 0.0
	_difundir_posiciones_enemigos()
