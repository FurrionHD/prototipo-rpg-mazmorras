# ============================================================
#  net.gd  (autoload "Net")
#  Capa de RED del juego. HITO 1: esqueleto andante en LAN.
#
#  Dueño de la conexion (host/cliente sobre ENet) y de la replicacion MINIMA del hito 1:
#  la POSICION de cada jugador y su ASPECTO (color/brillo/nombre). Nada mas: ni inventario, ni
#  combate, ni estado de Game. Eso son hitos posteriores (ver docs/MULTIJUGADOR.md).
#
#  TODOS los RPC pasan por este singleton a proposito: como el autoload vive en la MISMA ruta
#  (/root/Net) en el host y en el cliente, no hay que casar rutas de nodos del mundo.
#
#  TRANSPORTE AISLADO: lo unico especifico de ENet vive en hostear()/unirse() (crear el
#  ENetMultiplayerPeer). Todo lo demas usa la API de alto nivel de Godot y es agnostico del
#  transporte: portarlo a Steam el dia de manana = cambiar esas dos funciones por crear/unir un
#  lobby con SteamMultiplayerPeer (misma ranura multiplayer.multiplayer_peer) y la UI de conexion.
# ============================================================

extends Node

const PUERTO := 24567
const MAX_JUGADORES := 4
const _REMOTE_PLAYER := preload("res://scripts/actors/player/remote_player.gd")
const _DROP_PICKUP := preload("res://scripts/items/drop_pickup.gd")

# ¿Hay una sesion de red en marcha? El resto del juego (player.gd) lo consulta para decidir si
# emite su posicion. En un jugador es false y NADA cambia.
var activo := false
var es_host := false

var _codigo := ""                  # codigo de sala que hay que casar para entrar
var _avatares: Dictionary = {}     # peer_id -> nodo RemotePlayer (el cuerpo del OTRO en mi mundo)

# --- OBJETOS DEL SUELO replicados (hito 2) ---
# El HOST es la fuente de verdad: _suelo apunta cada drop vivo por id. Todos los peers (host
# incluido) mantienen _drops con el NODO visual de cada id. Quien recoge se lo PIDE al host:
# el primero en llegar se lo lleva y el resto ni se entera (el drop simplemente desaparece).
var _suelo: Dictionary = {}        # id -> dict del item (solo lo llena el host)
var _drops: Dictionary = {}        # id -> nodo drop_pickup (en todos los peers)
var _next_id: int = 1              # contador de ids del host

# El panel de conexion se suscribe para pintar "Conectado / Rechazado / Host caido...".
signal estado_cambiado(texto: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la red sigue sondeando aunque un menu pause mi arbol
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- ARRANQUE (lo unico especifico de ENet) -------------------------------------------------

func hostear(codigo: String, puerto: int = PUERTO) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(puerto, MAX_JUGADORES)
	if err != OK:
		estado_cambiado.emit("No se pudo abrir el servidor (puerto %d ocupado?)" % puerto)
		return err
	multiplayer.multiplayer_peer = peer
	_codigo = codigo
	activo = true
	es_host = true
	estado_cambiado.emit("Servidor abierto. Esperando a que se unan...")
	return OK


func unirse(ip: String, codigo: String, puerto: int = PUERTO) -> int:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, puerto)
	if err != OK:
		estado_cambiado.emit("No se pudo conectar a %s" % ip)
		return err
	multiplayer.multiplayer_peer = peer
	_codigo = codigo
	activo = true
	es_host = false
	estado_cambiado.emit("Conectando a %s..." % ip)
	return OK


func desconectar() -> void:
	for id in _avatares.keys():
		var a: Node = _avatares[id]
		if is_instance_valid(a):
			a.queue_free()
	_avatares.clear()
	# Los NODOS de los drops se quedan en el mundo como pickups locales normales (con
	# Net.activo=false el net_id deja de importar y F los coge por la rama de siempre). Solo se
	# vacian los registros. En el pueblo nada persiste, asi que el riesgo de duplicado tras una
	# desconexion es anecdotico y asumido (ver docs/MULTIJUGADOR.md).
	_suelo.clear()
	_drops.clear()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	activo = false
	es_host = false


# --- POSICION (lo que hace que os veais moveros) --------------------------------------------

# La llama el Player LOCAL cada tick de fisica si Net.activo. Difunde su posicion a los demas.
func enviar_estado(pos: Vector2, facing: Vector2) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	_recibir_estado.rpc(pos, facing)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recibir_estado(pos: Vector2, _facing: Vector2) -> void:
	var emisor := multiplayer.get_remote_sender_id()
	var a: Node = _avatares.get(emisor)
	if a != null and is_instance_valid(a):
		a.ir_a(pos)


# --- OBJETOS DEL SUELO (hito 2): soltar y recoger con autoridad del host --------------------

# Item -> dict de red. Lo minimo para reconstruirlo en la otra maquina: el MaterialData es un
# .tres del proyecto (viaja por ruta, igual que los consumibles en el guardado) y el Cristal
# son dos enteros. Mismo criterio que save_data, pero desmontado.
func _item_a_dict(item: Resource) -> Dictionary:
	if item is MaterialItem:
		var m := item as MaterialItem
		return {"t": "mat", "ruta": m.data.resource_path, "calidad": int(m.calidad)}
	if item is Cristal:
		var c := item as Cristal
		return {"t": "cri", "categoria": c.categoria, "calidad": int(c.calidad)}
	return {}


func _item_de_dict(d: Dictionary) -> Resource:
	if d.get("t") == "mat":
		var data: MaterialData = load(str(d["ruta"]))   # load() cachea: misma instancia que la bolsa
		if data == null:
			return null
		return MaterialItem.crear(data, int(d["calidad"]))
	if d.get("t") == "cri":
		var c := Cristal.new()
		c.categoria = int(d["categoria"])
		c.calidad = int(d["calidad"])
		return c
	return null


# La llama Game.soltar_item cuando hay sesion: en vez de plantar el pickup en local, se pide
# al host (que asigna id y lo difunde a TODOS, tu incluido). El offset aleatorio ya viene
# calculado en pos por quien suelta: asi ambas maquinas ven el drop en el MISMO sitio.
func solicitar_soltar(item: Resource, pos: Vector2) -> void:
	var d := _item_a_dict(item)
	if d.is_empty():
		return
	if es_host:
		_registrar_y_difundir(d, pos)
	else:
		_pedir_soltar.rpc_id(1, d, pos)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_soltar(d: Dictionary, pos: Vector2) -> void:
	if not es_host:
		return
	_registrar_y_difundir(d, pos)


# Solo host: apunta el drop en el registro y lo difunde (a los peers por RPC, a si mismo directo).
# La pos se guarda tambien: un peer que entre DESPUES tiene que ver lo que ya habia en el suelo.
func _registrar_y_difundir(d: Dictionary, pos: Vector2) -> void:
	var id := _next_id
	_next_id += 1
	_suelo[id] = {"d": d, "pos": pos}
	_spawn_drop.rpc(id, d, pos)
	_spawn_drop(id, d, pos)


@rpc("any_peer", "call_remote", "reliable")
func _spawn_drop(id: int, d: Dictionary, pos: Vector2) -> void:
	var item := _item_de_dict(d)
	var mundo: Node = get_tree().current_scene
	if item == null or mundo == null:
		return
	var pickup: Node2D = _DROP_PICKUP.new()
	pickup.setup(item)
	pickup.set_meta("net_id", id)   # la clase no se toca: el id de red viaja como meta
	mundo.add_child(pickup)
	pickup.global_position = pos
	_drops[id] = pickup


# La llama player.gd al pulsar F sobre un drop CON net_id: se pide al host en vez de cogerlo.
func solicitar_recoger(id: int) -> void:
	if es_host:
		_resolver_recogida(id, 1)
	else:
		_pedir_recoger.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_recoger(id: int) -> void:
	if not es_host:
		return
	_resolver_recogida(id, multiplayer.get_remote_sender_id())


# Solo host: arbitra la carrera. El PRIMERO que llega se lo lleva; a los demas ni agua (regla
# del diseño: sin mensaje, el drop simplemente ya no esta — su nodo cae con _despawn_drop).
func _resolver_recogida(id: int, ganador: int) -> void:
	if not _suelo.has(id):
		return   # llego tarde: silencio
	var d: Dictionary = _suelo[id]["d"]
	_suelo.erase(id)
	_despawn_drop.rpc(id)
	_despawn_drop(id)
	if ganador == 1:
		_recoger_concedido(d)          # el host se lo queda: sin viaje de red
	else:
		_recoger_concedido.rpc_id(ganador, d)


@rpc("any_peer", "call_remote", "reliable")
func _despawn_drop(id: int) -> void:
	var n: Node = _drops.get(id)
	if n != null and is_instance_valid(n):
		n.queue_free()
	_drops.erase(id)


# SOLO le llega al ganador: reconstruye el item y lo embolsa. Como esto corre unicamente en su
# proceso, el aviso del HUD ("Recoges X") sale solo en SU pantalla.
@rpc("any_peer", "call_remote", "reliable")
func _recoger_concedido(d: Dictionary) -> void:
	var item := _item_de_dict(d)
	if item != null:
		Game.embolsar(item)


# --- HANDSHAKE + CONTRASEÑA ------------------------------------------------------------------

# Cliente: nada mas conectar, se presenta al host (id 1) con el codigo y su aspecto.
func _on_connected_to_server() -> void:
	estado_cambiado.emit("Conectado. Validando codigo...")
	_saludar.rpc_id(1, _codigo, Game.player_color, Game.player_metalico, Game.player_nombre)


# Corre EN EL HOST, llamado por el cliente. Valida el codigo y, si vale, se crean los avatares
# mutuos; si no, se echa al que intenta colarse.
@rpc("any_peer", "call_remote", "reliable")
func _saludar(codigo: String, color: Color, metal: float, nombre: String) -> void:
	var quien := multiplayer.get_remote_sender_id()
	if codigo != _codigo:
		estado_cambiado.emit("Rechazado un intento con codigo incorrecto.")
		_rechazado.rpc_id(quien)
		# Un respiro antes de cortar: los RPC salen en el siguiente poll, y desconectar en el
		# mismo frame tira el paquete de _rechazado sin enviarlo (el cliente se quedaria sin
		# saber POR QUE se le echo).
		await get_tree().create_timer(0.3).timeout
		if multiplayer.multiplayer_peer != null:
			multiplayer.disconnect_peer(quien)
		return
	# Codigo OK: el host crea el avatar del cliente y se presenta de vuelta para que el cliente
	# cree el del host.
	_crear_avatar(quien, color, metal, nombre)
	estado_cambiado.emit("%s se ha unido." % nombre)
	_presentarse.rpc_id(quien, Game.player_color, Game.player_metalico, Game.player_nombre)
	# Y ponerle al dia el SUELO: lo que ya estaba soltado antes de que entrara.
	for id in _suelo:
		_spawn_drop.rpc_id(quien, id, _suelo[id]["d"], _suelo[id]["pos"])


# Corre en el CLIENTE, llamado por el host tras aceptarlo: crea el avatar del host (id 1).
@rpc("any_peer", "call_remote", "reliable")
func _presentarse(color: Color, metal: float, nombre: String) -> void:
	var quien := multiplayer.get_remote_sender_id()
	_crear_avatar(quien, color, metal, nombre)
	estado_cambiado.emit("Conectado con %s." % nombre)


# Corre en el CLIENTE si el host lo rechaza por codigo. El flag evita que la desconexion
# posterior pise el aviso con un "el host ha cerrado" que no cuenta la verdad.
var _fui_rechazado := false

@rpc("any_peer", "call_remote", "reliable")
func _rechazado() -> void:
	_fui_rechazado = true
	# En el idioma del jugador: no se distingue "la sala existe pero el codigo esta mal" de
	# "no hay sala". Suena natural y de paso no confirma a un curioso que ahi hay una partida.
	estado_cambiado.emit("No hay ninguna sala con ese codigo en esa IP.")


# --- AVATARES -------------------------------------------------------------------------------

func _crear_avatar(peer_id: int, color: Color, metal: float, nombre: String) -> void:
	if _avatares.has(peer_id) and is_instance_valid(_avatares[peer_id]):
		_avatares[peer_id].aplicar_aspecto(color, metal, nombre)
		return
	var mundo: Node = get_tree().current_scene
	if mundo == null:
		return
	var av: Node2D = _REMOTE_PLAYER.new()
	mundo.add_child(av)
	av.aplicar_aspecto(color, metal, nombre)
	_avatares[peer_id] = av


func _on_peer_disconnected(id: int) -> void:
	var conocido := _avatares.has(id)
	var a: Node = _avatares.get(id)
	if a != null and is_instance_valid(a):
		a.queue_free()
	_avatares.erase(id)
	# Solo avisar de gente que llego a ENTRAR (con avatar): un intento rechazado por codigo
	# tambien dispara esta señal y no es "un jugador que se va".
	if conocido:
		estado_cambiado.emit("Un jugador se ha ido.")


# El resto de señales de multiplayer.
func _on_peer_connected(_id: int) -> void:
	# El intercambio de aspecto lo dispara el handshake (_saludar/_presentarse), no esta señal:
	# aqui aun no sabemos el codigo ni el aspecto del que entra.
	pass


func _on_connection_failed() -> void:
	# IP mal escrita, host sin abrir, o no hay red: para el jugador es lo mismo.
	estado_cambiado.emit("No se encontro ninguna partida en esa IP.")
	desconectar()


func _on_server_disconnected() -> void:
	if _fui_rechazado:
		_fui_rechazado = false
		estado_cambiado.emit("No hay ninguna sala con ese codigo en esa IP.")
	else:
		estado_cambiado.emit("El host ha cerrado la partida.")
	desconectar()
