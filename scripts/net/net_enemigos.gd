# ============================================================
#  net_enemigos.gd  (hijo de Net: /root/Net/Enemigos)
#  EL CANAL DE ENEMIGOS: el dueño del piso da de alta, mueve y da de baja a sus bichos y los demas
#  los ven en espejo (remote_enemy). Se llama como Net.enemigos.<funcion>. Las RESERVAS de pelea y
#  la extraccion viven con las peleas; lo comun de la sesion sigue en Net.
# ============================================================
extends Node

# El canal de cada mensaje (ver net_canales.gd: por que va cada uno en el suyo).
const Canal := preload("res://scripts/net/net_canales.gd")

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
# El dueño es siempre la sala (etapa 2), que difunde directo a los de ese piso.
func registrar_enemigo(nodo: Node2D, lugar: String) -> void:
	if not Net.activo or nodo == null or not PisoVivo.dueno_del_nodo(nodo) or multiplayer.multiplayer_peer == null:
		return
	# El id lleva DENTRO quien lo creo: con varios dueños simulando pisos a la vez, un contador
	# suelto en cada maquina chocaria. Asi son unicos sin preguntarle nada a nadie.
	var id := multiplayer.get_unique_id() * 1000000 + _enem_next_id
	_enem_next_id += 1
	nodo.set_meta("net_id", id)   # el id de red viaja como meta, sin tocar la clase enemy
	_enemigos[id] = {"nodo": nodo, "lugar": lugar}
	var d: Dictionary = _datos_enemigo(nodo)
	if Net.es_host:
		var red: Dictionary = IdsRed.a_red(d)
		for p in Net.peers_en(lugar):   # solo a los de ese piso; los que lleguen lo piden (_pedir_enemigos)
			_spawn_enemigo.rpc_id(p, id, lugar, nodo.global_position, red)


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
	d["mutid"] = String(nodo.get("mutacion")) if nodo.get("mutacion") != null else ""   # CUAL (06/10)
	# Los cristales que lleva comidos: el que entra tarde tambien tiene que verlo "cargado".
	var cm = nodo.get("comer")
	if cm != null:
		d["carga"] = float(cm.carga)
	# Y si es el JEFE del piso. Hace falta para el aspecto: un jefe mutante se agranda MENOS que un
	# bicho mutante corriente (ver EnemyData.mult_mutante), asi que sin esto el espejo lo pintaria
	# con la escala equivocada.
	d["boss"] = bool(nodo.get("es_boss"))
	# El MUÑECO de la arena: la pelea la ejecuta la sala, y quien la tenga en espejo solo tiene el ESPEJO de
	# este bicho, asi que el modo tiene que venir con el (ver Game.muneco_de).
	if nodo.has_meta("muneco"):
		d["muneco"] = nodo.get_meta("muneco")
	if nodo.has_method("esta_muerto"):
		d["muerto"] = bool(nodo.esta_muerto())
	# Lo que le queda para pudrirse (12/10): el que lo ve llegar ya cadaver lo pinta igual de rancio que el dueño.
	if d["muerto"] and nodo.has_method("pudre_quedan"):
		d["pudre_q"] = float(nodo.pudre_quedan())
	return d


# Lo llama el dueño cuando un bicho DESAPARECE del mundo (reciclado, piso desmontado): lo borra
# del registro y avisa para que quiten su cuerpo. Un cadaver NO llama a esto: la muerte replicada
# es de una sub-fase posterior (con el combate).
func baja_enemigo(nodo: Node) -> void:
	if not Net.activo or nodo == null or not PisoVivo.dueno_del_nodo(nodo) or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	if not _enemigos.has(id):
		return
	_enemigos.erase(id)
	_ultimo_tick.erase(id)
	if Net.es_host:
		_despawn_enemigo.rpc(id)


# Lo llama enemy.morir() en la maquina que SIMULA el piso: el bicho pasa a cadaver y hay que
# decirselo a los demas (el nodo NO se libera al morir, asi que _exit_tree/baja_enemigo no salta).
func enemigo_muerto(nodo: Node) -> void:
	if not Net.activo or nodo == null or not PisoVivo.dueno_del_nodo(nodo) or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	if not _enemigos.has(id):
		return
	_enemigos[id]["muerto"] = true
	var lugar: String = _enemigos[id]["lugar"]
	if Net.es_host:
		for p in Net.peers_en(lugar):
			_marcar_cadaver.rpc_id(p, id, lugar)


# COMER CRISTALES (05/10): lo que hace el bicho al comer, para que los espejos lo vean igual. 'tipo' es
# "come" (empieza a comer: el picoteo), "carga" (se lo trago: su carga nueva) o "muta" (muta en vivo; valor =
# lo que dura la transformacion). Mismo camino que la muerte: el dueño (la sala) difunde. Sin esto el invitado
# veria a un bicho normal donde el anfitrion ya pelea un mutante.
func aviso_comer(nodo: Node, tipo: String, valor: float, extra: String = "") -> void:
	if not Net.activo or nodo == null or not PisoVivo.dueno_del_nodo(nodo) or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	if not _enemigos.has(id):
		return
	var lugar: String = _enemigos[id]["lugar"]
	if Net.es_host:
		for p in Net.peers_en(lugar):
			_aviso_comer.rpc_id(p, id, lugar, tipo, valor, extra)


@rpc("authority", "call_remote", "reliable", Canal.MUNDO)
func _aviso_comer(id: int, lugar: String, tipo: String, valor: float, extra: String = "") -> void:
	if not PisoVivo.lleva(lugar):
		Net.contar_de_otro_sitio()
		return
	var n = _enem_nodos.get(id)
	if n != null and is_instance_valid(n) and n.has_method("aviso_comer"):
		n.aviso_comer(tipo, valor, extra)


@rpc("authority", "call_remote", "reliable", Canal.MUNDO)
func _marcar_cadaver(id: int, lugar: String) -> void:
	if not PisoVivo.lleva(lugar):
		Net.contar_de_otro_sitio()
		return
	var n = _enem_nodos.get(id)
	if n != null and is_instance_valid(n) and n.has_method("marcar_cadaver"):
		n.marcar_cadaver()


@rpc("authority", "call_remote", "reliable", Canal.MUNDO)
func _spawn_enemigo(id: int, lugar: String, pos: Vector2, d: Dictionary) -> void:
	if not PisoVivo.lleva(lugar):
		Net.contar_de_otro_sitio()
		return   # eso esta en OTRO piso: aqui no se pinta
	if _enem_nodos.has(id) and is_instance_valid(_enem_nodos[id]):
		return   # ya lo tengo (llego dos veces: difusion + peticion de late-join)
	d = IdsRed.de_red(d)   # su .tres viaja como numero (IdsRed)
	var mundo: Node = PisoVivo.raiz_del_lugar(lugar, get_tree())
	if mundo == null:
		return
	var cuerpo: Node2D = _REMOTE_ENEMY.new()
	mundo.add_child(cuerpo)
	cuerpo.global_position = pos
	cuerpo.set_meta("net_id", id)   # para pedir pelea/extraccion por el
	if d.has("muneco"):
		cuerpo.set_meta("muneco", d["muneco"])
	cuerpo.configurar(d.get("color", Color.WHITE), float(d.get("lado", 32.0)),
		int(d.get("elem", Elementos.Elemento.NINGUNO)), float(d.get("einten", 1.0)))
	cuerpo.es_boss = bool(d.get("boss", false))   # antes de aplicar_datos: decide su escala si muto
	cuerpo.aplicar_datos(String(d.get("ruta", "")), float(d.get("t", 0.5)),
		bool(d.get("muerto", false)), float(d.get("vis", 130.0)), float(d.get("ang", 50.0)),
		bool(d.get("mut", false)), String(d.get("mutid", "")))
	cuerpo.carga = float(d.get("carga", 0.0))
	if d.has("pudre_q"):
		cuerpo.fijar_pudre_quedan(float(d["pudre_q"]))
	_enem_nodos[id] = cuerpo


@rpc("authority", "call_remote", "reliable", Canal.MUNDO)
func _despawn_enemigo(id: int) -> void:
	var n = _enem_nodos.get(id)
	if n != null and is_instance_valid(n):
		n.retirar()
	_enem_nodos.erase(id)


# Difusion de POSICIONES: la hace el DUEÑO del piso, a ~20 Hz desde _physics_process. Un lote empaquetado
# (empaquetar_tick) no fiable y ordenado, como la posicion del jugador (perder un paquete no importa: el siguiente
# corrige, y cada bicho sale entero al menos una vez por segundo). Uno por lugar.
func _difundir_posiciones_enemigos() -> void:
	# Purga de nodos muertos (reciclados sin pasar por baja, por si acaso). SIN tipar la variable:
	# asignar una instancia YA LIBERADA a un `var: Node` lanza error en Godot 4; hay que leerla
	# cruda y dejar que is_instance_valid la descarte.
	for id in _enemigos.keys():
		var nodo = _enemigos[id]["nodo"]
		if not is_instance_valid(nodo):
			_enemigos.erase(id)
			_ultimo_tick.erase(id)
			if Net.es_host:
				_despawn_enemigo.rpc(id)
	if _enemigos.is_empty():
		return
	# Cada bicho manda [id, pos, angulo_de_mirada, avisando_el_golpe]. Los dos ultimos NO son
	# adorno: con ellos el que solo lo ve espejado pinta su CONO DE VISION y su linea de direccion,
	# que es lo unico que permite jugar al sigilo.
	# UN LOTE POR LUGAR (fase 2, 19/10): en un cliente todos son de su piso (un lote, lo de siempre); en el servidor
	# cada piso manda los suyos a los que estan en el.
	var lotes: Dictionary = {}
	var ahora: int = Time.get_ticks_msec()
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
		var fila: Array = [id, (nd as Node2D).global_position, float(est[0]), bool(est[1]),
			Net.peleas._pelea_del_enemigo(id, nd), int(est[2]) if est.size() >= 3 else 0,
			bool(est[3]) if est.size() >= 4 else false]
		# SOLO LO QUE CAMBIA (fase 3, 28/10): el tick era lo que mas pesaba de toda la red (~30 %), y la mayoria de
		# filas eran bichos quietos y cadaveres repetidos 20 veces por segundo. Va el que se ha movido o ha cambiado
		# algo; y cada bicho, como poco, una vez cada TICK_ENTERO_MS aunque no cambie: el canal no es fiable, y si
		# se pierde su ultimo paso, eso lo corrige (el estado que se repite sigue sin poder desincronizarse, ahora
		# con un segundo de plazo en vez de una vigesima).
		var antes: Array = _ultimo_tick.get(id, [])
		if not antes.is_empty() and ahora - int(antes[0]) < TICK_ENTERO_MS and fila_igual(antes[1], fila):
			continue
		_ultimo_tick[id] = [ahora, fila]
		(lotes.get_or_add(String(_enemigos[id]["lugar"]), []) as Array).append(fila)
	if not Net.es_host:
		return
	for lug in lotes:
		var paquete: Array = empaquetar_tick(lotes[lug])
		for peer_id in Net._peers:
			if Net._peers[peer_id].get("lugar", "") == lug:
				_tick_enemigos.rpc_id(peer_id, paquete)


# Lo ultimo que se mando de cada bicho: id -> [msec, fila]. Solo en quien difunde.
var _ultimo_tick: Dictionary = {}
const TICK_ENTERO_MS := 1000
const TICK_MOVIDO_PX := 0.5     # menos que esto no se ve: medio pixel
const TICK_GIRO := 0.02         # radianes (~1 grado)


static func fila_igual(a: Array, b: Array) -> bool:
	if (a[1] as Vector2).distance_to(b[1]) >= TICK_MOVIDO_PX:
		return false
	if absf(angle_difference(float(a[2]), float(b[2]))) >= TICK_GIRO:
		return false
	return a[3] == b[3] and a[4] == b[4] and a[5] == b[5] and a[6] == b[6]


# EL PAQUETE (fase 3): una fila por bicho era un Array de siete con sus cabeceras de tipo (~100 B por bicho). Ahora:
#   [ids (PackedInt32), x/y/mirada seguidos (PackedFloat32), avisos (PackedByte: bit 0 avisando el golpe, bit 1
#    embistiendo), pelea de cada uno (PackedInt32: las ejecuta todas la sala, peer 1, asi que su id es
#    ID_POR_PEER + n y cabe de sobra), contador de embestidas (PackedInt32)]
# 'filas' = [[id, pos, mirada, avisando, pelea, embestidas, embistiendo], ...]; filas_de_tick lo deshace igual.
static func empaquetar_tick(filas: Array) -> Array:
	var ids := PackedInt32Array()
	var xya := PackedFloat32Array()
	var marcas := PackedByteArray()
	var peleas := PackedInt32Array()
	var embs := PackedInt32Array()
	for f in filas:
		ids.append(int(f[0]))
		xya.append((f[1] as Vector2).x)
		xya.append((f[1] as Vector2).y)
		xya.append(float(f[2]))
		marcas.append((1 if bool(f[3]) else 0) | (2 if bool(f[6]) else 0))
		peleas.append(int(f[4]))
		embs.append(int(f[5]))
	return [ids, xya, marcas, peleas, embs]


static func filas_de_tick(lote: Array) -> Array:
	if lote.size() < 5:
		return []
	var ids: PackedInt32Array = lote[0]
	var xya: PackedFloat32Array = lote[1]
	var marcas: PackedByteArray = lote[2]
	var peleas: PackedInt32Array = lote[3]
	var embs: PackedInt32Array = lote[4]
	var n: int = mini(mini(ids.size(), xya.size() / 3), mini(marcas.size(), mini(peleas.size(), embs.size())))
	var filas: Array = []
	for i in n:
		filas.append([ids[i], Vector2(xya[i * 3], xya[i * 3 + 1]), xya[i * 3 + 2], (marcas[i] & 1) != 0,
			peleas[i], embs[i], (marcas[i] & 2) != 0])
	return filas


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _tick_enemigos(lote: Array) -> void:
	# Todo lo que llega se aplica: las peleas las lleva la sala, que es tambien la que tiene los bichos de verdad, asi
	# que lo que dice el tick es donde estan, tambien a media pelea (29/10: fuera la excepcion de cuando la pelea la
	# llevaba un jugador y el sitio lo mandaba el).
	for par in filas_de_tick(lote):
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


# Alguien que acaba de llegar a un piso pide sus enemigos (late-join / cambio de piso). Se le pregunta
# a la sala, que lleva todos los pisos (etapa 2).
@rpc("any_peer", "call_remote", "reliable", Canal.CONTROL)
func _pedir_enemigos(lugar: String) -> void:
	if not Net.es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if PisoVivo.dueno_de(lugar):
		# Solo los de ESE piso: en la sala (etapa 2) llevo varios, y sin filtrar le llegaban los de todos con su lugar.
		for id in _enemigos:
			var e: Dictionary = _enemigos[id]
			if is_instance_valid(e["nodo"]) and String(e["lugar"]) == lugar:
				_spawn_enemigo.rpc_id(quien, id, lugar, (e["nodo"] as Node2D).global_position,
					IdsRed.a_red(_datos_enemigo(e["nodo"])))
		# Y los cuerpos que se estan extrayendo en ese piso: tambien solo le llegaban a los que estaban.
		Net.extraccion._set_extrayendo.rpc_id(quien, Net.extraccion.del_lugar(lugar))


# El DUEÑO del piso difunde las posiciones de SUS enemigos a ~20 Hz. En solitario, o si solo espejo el
# piso, no hace nada. Va en _physics_process para leer las posiciones ya resueltas por la fisica del bicho.
func _physics_process(delta: float) -> void:
	if not Net.activo or _enemigos.is_empty() or not PisoVivo.dueno_de_alguno() or multiplayer.multiplayer_peer == null:
		return
	_enem_acum += delta
	if _enem_acum < _ENEM_TICK:
		return
	_enem_acum = 0.0
	_difundir_posiciones_enemigos()
