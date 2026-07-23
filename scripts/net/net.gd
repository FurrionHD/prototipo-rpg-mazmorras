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

# ¿Hay una sesion de red en marcha? El resto del juego (player.gd) lo consulta para decidir si
# emite su posicion. En un jugador es false y NADA cambia.
var activo := false
var es_host := false

var _codigo := ""                  # codigo de sala que hay que casar para entrar
var _avatares: Dictionary = {}     # peer_id -> nodo RemotePlayer (el cuerpo del OTRO en mi mundo)

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
	estado_cambiado.emit("Codigo incorrecto: el host te ha rechazado.")


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
	estado_cambiado.emit("No se pudo conectar al host.")
	desconectar()


func _on_server_disconnected() -> void:
	if _fui_rechazado:
		_fui_rechazado = false
		estado_cambiado.emit("Expulsado: el codigo de sala no era correcto.")
	else:
		estado_cambiado.emit("El host ha cerrado la partida.")
	desconectar()
