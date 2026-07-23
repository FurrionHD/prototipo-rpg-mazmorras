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

# --- QUIEN es cada peer y DONDE esta (hito 3b) ---
# _peers guarda los DATOS de cada peer (aspecto, lugar, ultima pos): sobrevive a cambios de
# escena. _avatares guarda el NODO visual, que solo existe si el peer esta en MI MISMO LUGAR
# ("pueblo" o "piso:N") y muere con la escena; se reconstruye desde _peers al viajar.
var _peers: Dictionary = {}        # peer_id -> {"color","metal","nombre","lugar","pos"}
var _avatares: Dictionary = {}     # peer_id -> nodo RemotePlayer (solo peers de mi lugar)
var _mi_lugar := "pueblo"          # donde estoy YO: "pueblo" o "piso:N"

# Semilla del mundo del HOST (solo la usa el cliente; en el host vale 0 = usa la suya).
# NUNCA se escribe en Game.semilla_mundo del cliente: esa es de SU save.
var semilla_host: int = 0

# El surtido de la tienda manda el MUNDO DEL HOST: si el tiene la T2 abierta (Rey Slime muerto),
# ambos la ven. Llega en el handshake; no cambia en sesion (los enemigos estan apagados en multi,
# asi que el host no mata bosses mientras jugais).
var tienda_t2_host: bool = false

# --- EXPEDICION compartida (hito 3b; el host es la autoridad) ---
# El PRIMERO que entra la abre; el ULTIMO que sale la cierra (y se olvida, como en solitario).
# Mientras quede alguien dentro, la mazmorra vive: puedes salir a vender y volver.
var expedicion_abierta := false    # solo fiable en el host
var piso_actual := 1               # piso activo de la sesion (solo fiable en el host)

# --- CUPO de personajes en sesion: maximo 4 EN TOTAL entre todos los humanos ---
# 2 humanos -> principal + 1 acompanante cada uno; 3 -> host con 1 acompanante, invitados solos;
# 4 -> todos solos. Los que sobran se van SOLOS al hogar y VUELVEN solos al irse gente o cerrar.
var _apartados: Array = []         # PersonajeData que el cupo mando al hogar, en su orden
# Cuantos HUMANOS hay en la sesion. Lo cuenta el HOST (es el unico que ve a todos: en la
# topologia estrella de Godot los clientes no se ven entre si, solo al host) y lo DIFUNDE. Un
# cliente jamas puede deducirlo de su _peers (que solo tiene al host).
var _num_humanos := 1
var _dentro: Dictionary = {}       # peer_id -> true: quienes estan en la mazmorra (host)
var _vetas_ocupadas: Dictionary = {}  # celda -> peer_id que la trabaja (host)
var _agotados_sesion: Dictionary = {} # celda -> true: vetas agotadas ESTA expedicion (todos)

# --- OBJETOS DEL SUELO replicados (hito 2) ---
# El HOST es la fuente de verdad: _suelo apunta cada drop vivo por id. Todos los peers (host
# incluido) mantienen _drops con el NODO visual de cada id. Quien recoge se lo PIDE al host:
# el primero en llegar se lo lleva y el resto ni se entera (el drop simplemente desaparece).
var _suelo: Dictionary = {}        # id -> dict del item (solo lo llena el host)
var _drops: Dictionary = {}        # id -> nodo drop_pickup (en todos los peers)
var _next_id: int = 1              # contador de ids del host

# El panel de conexion se suscribe para pintar "Conectado / Rechazado / Host caido...".
signal estado_cambiado(texto: String)

# Se emite cuando cambia CUALQUIER estado compartido del hogar (bote, cofre, baul de materiales):
# los menus del pueblo abiertos se re-dibujan al oirlo (hoy la UI solo se refresca por accion
# propia; en multi el OTRO puede cambiar el estado y hay que enterarse).
signal hogar_cambiado()

# ¿Soy un CLIENTE en sesion? (uso el almacen del host via mirror). El host y el modo un jugador
# usan Game.* directo.
func _soy_cliente() -> bool:
	return activo and not es_host

# Lo que la UI del hogar debe MOSTRAR: en solitario/host, lo de Game; de cliente, el mirror del host.
func bote_visible() -> int:
	return _bote_mirror if _soy_cliente() else Game.bote_dinero
func cofre_visible() -> Array:
	return _cofre_mirror if _soy_cliente() else Game.cofre_equipo
func cofre_consumibles_visible() -> Dictionary:
	return _cofre_consum_mirror if _soy_cliente() else Game.cofre_consumibles

# --- ALMACEN del hogar (bote/cofre): viven en Game (PERSISTEN en la partida, solo y multi). En
# solitario son tu almacen personal; en multi los del HOST son los compartidos. Aqui solo guardo
# el MIRROR de lo del host para cuando soy CLIENTE (asi no piso mis propios Game.* : no se pierde
# nada al entrar/salir de una sesion). Las lecturas de la UI pasan por *_visible().
var _bote_mirror: int = 0
var _cofre_mirror: Array = []
var _cofre_consum_mirror: Dictionary = {}
# Baul de MATERIALES: como el crafteo trabaja sobre Game.almacen_materiales, al ser cliente se
# guarda aparte el mio y se restaura al desconectar (durante la sesion veo/uso el del host).
var _almacen_solo: Array = []
var _almacen_guardado := false

# --- BAUL de materiales COMPARTIDO (hito 4): con CANDADO de taller (uno craftea a la vez) ---
# El baul "de verdad" es el del host (Game.almacen_materiales). Los clientes tienen un MIRROR
# (solo para mostrar/validar). Para craftear/depositar hay que COGER el candado: mientras lo
# tienes, el host te PRESTA el baul autoritativo en tu Game.almacen_materiales local y crafteas
# con el codigo de siempre; al soltarlo, tu baul vuelve al host y se difunde a los mirrors. Solo
# uno a la vez -> cero doble-gasto, cero refactor del crafteo. Igual que el "esta ocupado" de las vetas.
var _taller_dueno: int = 0     # peer que tiene el candado (host lo arbitra); 0 = libre
var _taller_resp: int = 0      # cliente: respuesta pendiente (0 esperando, 1 concedido, -1 ocupado)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # la red sigue sondeando aunque un menu pause mi arbol
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


# --- ARRANQUE (lo unico especifico de ENet) -------------------------------------------------

# ¿Estoy en el pueblo? Las sesiones SOLO se abren/unen desde alli: montar una sesion con la
# mitad de la gente ya metida en una mazmorra de otro mundo es un nido de estados imposibles.
func _en_el_pueblo() -> bool:
	var esc: Node = get_tree().current_scene
	return esc != null and esc.scene_file_path.contains("town")


func hostear(codigo: String, puerto: int = PUERTO) -> int:
	if not _en_el_pueblo():
		estado_cambiado.emit("Solo se puede abrir una sala desde el pueblo.")
		return ERR_UNAVAILABLE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(puerto, MAX_JUGADORES)
	if err != OK:
		estado_cambiado.emit("No se pudo abrir el servidor (puerto %d ocupado?)" % puerto)
		return err
	multiplayer.multiplayer_peer = peer
	_codigo = codigo
	activo = true
	es_host = true
	Game._refrescar_pausa()   # regimen multi: los menus dejan de pausar el arbol
	estado_cambiado.emit("Servidor abierto. Esperando a que se unan...")
	return OK


func unirse(ip: String, codigo: String, puerto: int = PUERTO) -> int:
	if not _en_el_pueblo():
		estado_cambiado.emit("Solo puedes unirte a una sala desde el pueblo.")
		return ERR_UNAVAILABLE
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, puerto)
	if err != OK:
		estado_cambiado.emit("No se pudo conectar a %s" % ip)
		return err
	multiplayer.multiplayer_peer = peer
	_codigo = codigo
	activo = true
	es_host = false
	Game._refrescar_pausa()   # regimen multi: los menus dejan de pausar el arbol
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
	_peers.clear()
	_dentro.clear()
	_vetas_ocupadas.clear()
	_agotados_sesion.clear()
	expedicion_abierta = false
	piso_actual = 1
	semilla_host = 0
	tienda_t2_host = false
	# Restaurar MI baul de materiales si lo habia guardado al entrar de cliente (no perder nada).
	if _almacen_guardado:
		var lista: Array[MaterialItem] = []
		for m in _almacen_solo:
			lista.append(m)
		Game.almacen_materiales = lista
		_almacen_guardado = false
		_almacen_solo = []
	_bote_mirror = 0
	_cofre_mirror = []
	_cofre_consum_mirror = {}
	_taller_dueno = 0
	_taller_resp = 0
	_mi_lugar = "pueblo"
	_num_humanos = 1
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	activo = false
	es_host = false
	# De vuelta al regimen de un jugador: si hay un menu abierto, el arbol vuelve a pausarse.
	Game._refrescar_pausa()
	# Fin de sesion: cupo = PARTY_MAX otra vez, asi que los apartados por el cupo vuelven todos.
	_aplicar_cupo()
	_apartados.clear()


# --- POSICION (lo que hace que os veais moveros) --------------------------------------------

# La llama el Player LOCAL cada tick de fisica si Net.activo. Difunde su posicion a los demas.
func enviar_estado(pos: Vector2, facing: Vector2) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	_recibir_estado.rpc(pos, facing)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recibir_estado(pos: Vector2, _facing: Vector2) -> void:
	var emisor := multiplayer.get_remote_sender_id()
	if _peers.has(emisor):
		_peers[emisor]["pos"] = pos   # se recuerda: al reconstruir su avatar aparece donde iba
	var a: Node = _avatares.get(emisor)
	if a != null and is_instance_valid(a):
		a.ir_a(pos)


# --- LUGAR (hito 3b): "pueblo" o "piso:N" -----------------------------------------------------

# Lo llamo YO al viajar (puerta, escaleras). Difunde mi lugar nuevo y reconstruye mi vista
# (avatares y drops del lugar nuevo) cuando la escena nueva ya esta montada.
func anunciar_lugar(lugar: String) -> void:
	_mi_lugar = lugar
	if activo:
		_cambiar_lugar.rpc(lugar)
		_reconstruir_vista()


@rpc("any_peer", "call_remote", "reliable")
func _cambiar_lugar(lugar: String) -> void:
	var emisor := multiplayer.get_remote_sender_id()
	if not _peers.has(emisor):
		return
	_peers[emisor]["lugar"] = lugar
	# ¿Ahora compartimos lugar? Su avatar aparece. ¿Ya no? Desaparece.
	var a: Node = _avatares.get(emisor)
	if lugar == _mi_lugar:
		if a == null or not is_instance_valid(a):
			_crear_avatar_nodo(emisor)
	else:
		if a != null and is_instance_valid(a):
			a.queue_free()
		_avatares.erase(emisor)


# Tras viajar YO: la escena vieja murio (y con ella mis avatares/drops). Se espera a que la
# nueva este montada y se reconstruye lo que toca ver aqui.
func _reconstruir_vista() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for id in _avatares.keys():
		var a: Node = _avatares[id]
		if is_instance_valid(a):
			a.queue_free()
	_avatares.clear()
	for id in _peers:
		if _peers[id]["lugar"] == _mi_lugar:
			_crear_avatar_nodo(id)
	for id in _drops.keys():
		var n: Node = _drops[id]
		if is_instance_valid(n):
			n.queue_free()
	_drops.clear()
	if es_host:
		for id in _suelo:
			if _suelo[id]["lugar"] == _mi_lugar:
				_spawn_drop(id, _suelo[id]["d"], _suelo[id]["pos"], _mi_lugar)
	else:
		_pedir_suelo.rpc_id(1, _mi_lugar)


# Un cliente que acaba de viajar pide el suelo de su lugar nuevo.
@rpc("any_peer", "call_remote", "reliable")
func _pedir_suelo(lugar: String) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	for id in _suelo:
		if _suelo[id]["lugar"] == lugar:
			_spawn_drop.rpc_id(quien, id, _suelo[id]["d"], _suelo[id]["pos"], lugar)


# --- EXPEDICION compartida (hito 3b) ---------------------------------------------------------
#
# La puerta del pueblo, en multi, pasa por aqui. El PRIMERO que entra ABRE la expedicion (piso 1,
# flujo normal); el que llega despues SE UNE al piso activo TAL CUAL esta (ni repuebla ni resetea
# nada del que ya esta dentro: cada maquina tiene su copia del piso y lo compartido viaja por Net).
# El ULTIMO que sale la cierra y se olvida, como en solitario.

# La llama door.gd (rama multi) al interactuar con la puerta del pueblo.
func solicitar_entrar() -> void:
	if es_host:
		_conceder_entrada(1)
	else:
		_pedir_entrar.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_entrar() -> void:
	if not es_host:
		return
	_conceder_entrada(multiplayer.get_remote_sender_id())


# Solo host: apunta al peer como "dentro" y le concede la entrada con el piso que toque.
func _conceder_entrada(quien: int) -> void:
	if not expedicion_abierta:
		expedicion_abierta = true
		piso_actual = 1
	_dentro[quien] = true
	if quien == 1:
		_entrar_ok(piso_actual, _agotados_sesion.keys())
	else:
		_entrar_ok.rpc_id(quien, piso_actual, _agotados_sesion.keys())


# Corre en QUIEN entra: hace el viaje completo. olvidar_mazmorra() limpia la memoria LOCAL de
# expediciones viejas (imprescindible tambien para el que se une: si no, restauraria SUS bichos
# rancios); los agotados de LA SESION llegan del host para que las vetas ya picadas no nazcan.
@rpc("any_peer", "call_remote", "reliable")
func _entrar_ok(piso: int, agotados: Array) -> void:
	_agotados_sesion.clear()
	for c in agotados:
		_agotados_sesion[c] = true
	Game.current_floor = piso
	Game.olvidar_mazmorra()
	Game.iniciar_expedicion_mapa()
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	anunciar_lugar("piso:%d" % piso)


# La llama la puerta de vuelta / la salida del boss (rama multi), DESPUES de consolidar el mapa.
func viajar_al_pueblo() -> void:
	if es_host:
		_registrar_salida(1)
	else:
		_pedir_salir.rpc_id(1)
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	anunciar_lugar("pueblo")


@rpc("any_peer", "call_remote", "reliable")
func _pedir_salir() -> void:
	if not es_host:
		return
	_registrar_salida(multiplayer.get_remote_sender_id())


func _registrar_salida(quien: int) -> void:
	_liberar_vetas_de(quien)
	_dentro.erase(quien)
	if _dentro.is_empty() and expedicion_abierta:
		_cerrar_expedicion()


# Solo host: el ultimo salio. La expedicion se olvida: fuera drops de pisos y agotados de sesion.
func _cerrar_expedicion() -> void:
	expedicion_abierta = false
	piso_actual = 1
	_vetas_ocupadas.clear()
	_agotados_sesion.clear()
	_limpiar_agotados_sesion.rpc()
	for id in _suelo.keys():
		if str(_suelo[id]["lugar"]).begins_with("piso:"):
			_suelo.erase(id)
			_despawn_drop.rpc(id)
			_despawn_drop(id)
	estado_cambiado.emit("Expedicion terminada: la mazmorra se olvida.")


@rpc("any_peer", "call_remote", "reliable")
func _limpiar_agotados_sesion() -> void:
	_agotados_sesion.clear()


# --- ESCALERAS: bajar/subir JUNTOS ------------------------------------------------------------

# La llama stairs.gd (rama multi). El host valida y TODOS los que esten en la mazmorra cambian.
func solicitar_cambio_piso(nuevo: int) -> void:
	if es_host:
		_aplicar_cambio_piso(nuevo)
	else:
		_pedir_piso.rpc_id(1, nuevo)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_piso(nuevo: int) -> void:
	if not es_host:
		return
	_aplicar_cambio_piso(nuevo)


# Solo host: fija el piso de la sesion y lo difunde (a si mismo directo).
func _aplicar_cambio_piso(nuevo: int) -> void:
	if nuevo < 1 or not expedicion_abierta:
		return
	piso_actual = nuevo
	_vetas_ocupadas.clear()   # los minijuegos abiertos se cierran con el piso; locks fuera
	_cambiar_piso_todos.rpc(nuevo)
	_cambiar_piso_todos(nuevo)


# Corre en TODOS: solo reacciona quien este en la mazmorra. regenerar() reconstruye el piso en
# esta maquina; la geometria sale igual en todas (misma semilla del host).
@rpc("any_peer", "call_remote", "reliable")
func _cambiar_piso_todos(nuevo: int) -> void:
	if not _mi_lugar.begins_with("piso:"):
		return
	var bajando: bool = nuevo > Game.current_floor
	Game._cambiar_piso(nuevo, bajando)
	anunciar_lugar("piso:%d" % nuevo)


# --- VETAS: una a la vez, con "esta ocupado" --------------------------------------------------

# La llama resource_node.interactuar() (rama multi): pedir la veta antes de abrir el minijuego.
func solicitar_veta(celda: Vector2i) -> void:
	if es_host:
		_resolver_veta(celda, 1)
	else:
		_pedir_veta.rpc_id(1, celda)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_veta(celda: Vector2i) -> void:
	if not es_host:
		return
	_resolver_veta(celda, multiplayer.get_remote_sender_id())


# Solo host: arbitra. Libre -> lock y concedida; ocupada -> "esta ocupado" (AQUI si hay mensaje,
# regla del usuario; en los drops del suelo, silencio).
func _resolver_veta(celda: Vector2i, quien: int) -> void:
	if _agotados_sesion.has(celda):
		return   # ya no existe: su nodo esta cayendo, no hay nada que decir
	if _vetas_ocupadas.has(celda) and _vetas_ocupadas[celda] != quien:
		if quien == 1:
			_veta_ocupada()
		else:
			_veta_ocupada.rpc_id(quien)
		return
	_vetas_ocupadas[celda] = quien
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
func notificar_agotado(celda: Vector2i) -> void:
	if es_host:
		_registrar_agotado(celda)
	else:
		_pedir_agotar.rpc_id(1, celda)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_agotar(celda: Vector2i) -> void:
	if not es_host:
		return
	_registrar_agotado(celda)


# Solo host: suelta el lock, sella la celda para la sesion y difunde el agotado a todos.
func _registrar_agotado(celda: Vector2i) -> void:
	_vetas_ocupadas.erase(celda)
	_agotados_sesion[celda] = true
	_agotar_celda.rpc(celda)
	_agotar_celda(celda)


# Corre en TODOS los que esten en la mazmorra: la veta de esa celda desaparece tambien aqui.
@rpc("any_peer", "call_remote", "reliable")
func _agotar_celda(celda: Vector2i) -> void:
	_agotados_sesion[celda] = true
	if not _mi_lugar.begins_with("piso:"):
		return
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("marcar_agotado"):
		piso.marcar_agotado(celda)
	for n in get_tree().get_nodes_in_group("recolectable"):
		if is_instance_valid(n) and n.celda == celda:
			n.agotar()
			return


# ¿Esta celda ya se agoto en ESTA expedicion? Lo consulta dungeon_floor al construir el piso.
func celda_agotada_sesion(celda: Vector2i) -> bool:
	return _agotados_sesion.has(celda)


# --- CUPO de personajes (max 4 en total en la sesion) ----------------------------------------

# Cuantos personajes puede llevar MI equipo ahora mismo. Sin sesion: el tope normal. La regla
# del reparto (decidida por el usuario): con 3 humanos el acompanante extra es del HOST.
func cupo_party() -> int:
	if not activo:
		return Game.PARTY_MAX
	var n: int = _num_humanos   # lo mantiene y difunde el host (ver _sync_humanos)
	if n <= 1:
		return Game.PARTY_MAX
	if n == 2:
		return 2
	if n == 3:
		return 2 if es_host else 1
	return 1


# Solo HOST: recuenta los humanos, lo difunde a los clientes y reajusta su propio equipo.
func _sync_humanos() -> void:
	_num_humanos = _peers.size() + 1
	_set_num_humanos.rpc(_num_humanos)
	_aplicar_cupo()


# Corre en los CLIENTES: el host dice cuantos humanos hay. Reajustan su equipo al cupo nuevo.
@rpc("authority", "call_remote", "reliable")
func _set_num_humanos(n: int) -> void:
	_num_humanos = n
	_aplicar_cupo()


# Ajusta MI equipo al cupo. Cada maquina se ajusta sola (todas conocen n y su rol).
#  - RECORTE: se quedan las primeras posiciones de la formacion, con la garantia del ORIGINAL
#    (el personaje que creaste): si el cupo lo dejaria fuera, SE DESLIZA al ultimo hueco
#    permitido desplazando al que iba ahi. Los apartados van al hogar (banquillo) EN ORDEN.
#  - RESTAURACION: al bajar la gente (o cerrar sesion), los apartados vuelven en su orden.
# Se recompone el array party entero (sacar_del_equipo no vale: rechaza al original y no
# desliza posiciones), reapuntando lider_idx a la misma persona si sigue, o al original.
func _aplicar_cupo() -> void:
	var cupo := cupo_party()
	var antes: int = Game.party.size()

	# Restaurar primero (si hay hueco y gente esperando).
	while Game.party.size() < cupo and not _apartados.is_empty():
		var pj: PersonajeData = _apartados.pop_front()
		if not Game.meter_en_equipo(pj):
			break   # seguridad (no deberia pasar: estan en plantilla y hay hueco)

	# Recortar si sobra gente.
	if Game.party.size() > cupo:
		var lider_pj: PersonajeData = Game.lider()
		var orig: PersonajeData = Game.original()
		var mantener: Array = []
		for pj in Game.party:
			if mantener.size() < cupo:
				mantener.append(pj)
		if Game.party.has(orig) and not mantener.has(orig):
			mantener[cupo - 1] = orig   # el original se desliza al ultimo hueco permitido
		for pj in Game.party:
			if not mantener.has(pj):
				_apartados.append(pj)
		Game.party.assign(mantener)
		var idx: int = Game.party.find(lider_pj)
		Game.lider_idx = idx if idx >= 0 else maxi(0, Game.party.find(orig))

	if Game.party.size() == antes:
		return   # nada cambio: ni refresco ni toast

	# El sequito/barras se refrescan solos (player._comprobar_grupo), pero el TRASPASO DE
	# AGUANTE del cambio de lider no: hay que llamarlo, como hace el menu del Hogar.
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("refrescar_lider"):
		p.refrescar_lider()
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		if Game.party.size() < antes:
			hud.mostrar_toast("Cupo de sesion: tus acompanantes esperan en el hogar.")
		else:
			hud.mostrar_toast("Tus acompanantes han vuelto al equipo.")


# Solo host: suelta todos los locks de un peer que se va (salida o desconexion a mitad de
# minijuego).
func _liberar_vetas_de(quien: int) -> void:
	for c in _vetas_ocupadas.keys():
		if _vetas_ocupadas[c] == quien:
			_vetas_ocupadas.erase(c)


# --- BOTE de dinero del hogar (hito 4) -------------------------------------------------------
#
# El dinero de bolsillo es de cada uno; el BOTE es un fondo comun. Depositar: el que deposita
# YA descuenta su money (local) y avisa al host de que sume al bote. Retirar: el host valida que
# hay tanto en el bote, lo resta, y le dice al que pide que ingrese esa cantidad. Host-autoritativo.

# La UI llama a estas dos. El dinero de bolsillo (Game.money) sale/entra en LOCAL siempre; el
# bote vive en Game (persiste) y en multi es el del host. Devuelve false si no tienes tanto.
func depositar_bote(n: int) -> bool:
	if n <= 0:
		return false
	if not Game.gastar(n):   # el dinero sale de MI bolsillo ya (personal, local)
		return false
	if _soy_cliente():
		_pedir_depositar.rpc_id(1, n)
	else:
		Game.bote_dinero += n
		_difundir_bote()
	return true


func retirar_bote(n: int) -> void:
	if n <= 0:
		return
	if _soy_cliente():
		_pedir_retirar.rpc_id(1, n)
	else:
		_resolver_retiro(n, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_depositar(n: int) -> void:
	if not es_host or n <= 0:
		return
	Game.bote_dinero += n
	_difundir_bote()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_retirar(n: int) -> void:
	if not es_host:
		return
	_resolver_retiro(n, multiplayer.get_remote_sender_id())


# Host o solitario: hay tanto en el bote? -> se lo lleva quien lo pide; si no, aviso. quien=1 =
# yo mismo (host o solitario); otro id = un cliente.
func _resolver_retiro(n: int, quien: int) -> void:
	if n <= 0 or Game.bote_dinero < n:
		if quien == 1:
			_retiro_fallido()
		else:
			_retiro_fallido.rpc_id(quien)
		return
	Game.bote_dinero -= n
	_difundir_bote()
	if quien == 1:
		Game.ingresar(n)
	else:
		_retiro_ok.rpc_id(quien, n)


@rpc("any_peer", "call_remote", "reliable")
func _retiro_ok(n: int) -> void:
	Game.ingresar(n)   # el dinero entra en MI bolsillo


@rpc("any_peer", "call_remote", "reliable")
func _retiro_fallido() -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast("No hay tanto en el bote del hogar.")


# Difunde el bote a los clientes (solo si hay sesion) y refresca la UI.
func _difundir_bote() -> void:
	if activo:
		_set_bote.rpc(Game.bote_dinero)
	hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_bote(v: int) -> void:
	_bote_mirror = v   # cliente: reflejo del bote del host
	hogar_cambiado.emit()


# --- COFRE de armas/armaduras (hito 4) -------------------------------------------------------
#
# Meter: el que deposita saca la pieza de SU baul (local) y manda su serializacion; el host la
# apunta en el cofre. Sacar: el host la quita del cofre y se la manda al que la pide, que la
# reconstruye en su baul. Host-autoritativo: el cofre "de verdad" es el del host, los demas lo
# reflejan.

# La UI llama a esta con una pieza de owned_* NO equipada. false si no se puede serializar/sacar.
func meter_en_cofre(item: Resource) -> bool:
	var d: Dictionary = Game.serializar_equipo(item)
	if d.is_empty():
		return false
	if not Game.sacar_de_baul(item):   # se va de MI baul ya
		return false
	if _soy_cliente():
		_pedir_meter_cofre.rpc_id(1, d)
	else:
		_apuntar_en_cofre(d)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _pedir_meter_cofre(d: Dictionary) -> void:
	if not es_host:
		return
	_apuntar_en_cofre(d)


# Host o solitario: apunta la pieza en el cofre (Game.cofre_equipo, que persiste).
func _apuntar_en_cofre(d: Dictionary) -> void:
	Game.cofre_equipo.append({"id": Game._cofre_next_id, "dict": d,
		"clase": str(d.get("clase", "arma")), "desc": str(d.get("desc", "?"))})
	Game._cofre_next_id += 1
	_difundir_cofre()


# La UI llama a esta con el id de una entrada del cofre. El host la concede al que la pide.
func sacar_de_cofre(id: int) -> void:
	if _soy_cliente():
		_pedir_sacar_cofre.rpc_id(1, id)
	else:
		_resolver_saca_cofre(id, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_sacar_cofre(id: int) -> void:
	if not es_host:
		return
	_resolver_saca_cofre(id, multiplayer.get_remote_sender_id())


# Host o solitario: el primero que la pide se la lleva; el resto, silencio (ya no esta). quien=1 =
# yo mismo (host/solitario); otro id = un cliente al que hay que enviarsela.
func _resolver_saca_cofre(id: int, quien: int) -> void:
	var idx := -1
	for i in Game.cofre_equipo.size():
		if int(Game.cofre_equipo[i]["id"]) == id:
			idx = i
			break
	if idx < 0:
		return
	var d: Dictionary = Game.cofre_equipo[idx]["dict"]
	Game.cofre_equipo.remove_at(idx)
	_difundir_cofre()
	if quien == 1:
		Game.deserializar_equipo(d)
	else:
		_cofre_concedido.rpc_id(quien, d)


@rpc("any_peer", "call_remote", "reliable")
func _cofre_concedido(d: Dictionary) -> void:
	Game.deserializar_equipo(d)   # se reconstruye en MI baul
	hogar_cambiado.emit()


func _difundir_cofre() -> void:
	if activo:
		_set_cofre.rpc(Game.cofre_equipo)
	hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_cofre(lista: Array) -> void:
	_cofre_mirror = lista   # cliente: reflejo del cofre del host
	hogar_cambiado.emit()


# --- COFRE de CONSUMIBLES (pociones/grimorios): stackeable, ruta -> cantidad -----------------

func meter_consumible_cofre(ruta: String, n: int) -> void:
	var quita: int = Game.quitar_consumible(load(ruta), n)   # sale de MI inventario
	if quita <= 0:
		return
	if _soy_cliente():
		_pedir_meter_consumible.rpc_id(1, ruta, quita)
	else:
		_apuntar_consumible(ruta, quita)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_meter_consumible(ruta: String, n: int) -> void:
	if es_host:
		_apuntar_consumible(ruta, n)


# Host o solitario: apunta en Game.cofre_consumibles (persiste).
func _apuntar_consumible(ruta: String, n: int) -> void:
	Game.cofre_consumibles[ruta] = int(Game.cofre_consumibles.get(ruta, 0)) + n
	_difundir_cofre_consumibles()


func sacar_consumible_cofre(ruta: String, n: int) -> void:
	if _soy_cliente():
		_pedir_sacar_consumible.rpc_id(1, ruta, n)
	else:
		_resolver_saca_consumible(ruta, n, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_sacar_consumible(ruta: String, n: int) -> void:
	if es_host:
		_resolver_saca_consumible(ruta, n, multiplayer.get_remote_sender_id())


func _resolver_saca_consumible(ruta: String, n: int, quien: int) -> void:
	var hay: int = int(Game.cofre_consumibles.get(ruta, 0))
	var da: int = mini(hay, maxi(0, n))
	if da <= 0:
		return
	if hay - da <= 0:
		Game.cofre_consumibles.erase(ruta)
	else:
		Game.cofre_consumibles[ruta] = hay - da
	_difundir_cofre_consumibles()
	if quien == 1:
		Game.add_consumable(load(ruta), da)
	else:
		_consumible_concedido.rpc_id(quien, ruta, da)


@rpc("any_peer", "call_remote", "reliable")
func _consumible_concedido(ruta: String, n: int) -> void:
	Game.add_consumable(load(ruta), n)
	hogar_cambiado.emit()


func _difundir_cofre_consumibles() -> void:
	if activo:
		_set_cofre_consumibles.rpc(Game.cofre_consumibles)
	hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_cofre_consumibles(d: Dictionary) -> void:
	_cofre_consum_mirror = d   # cliente: reflejo del cofre del host
	hogar_cambiado.emit()


# --- BAUL de materiales compartido + candado del taller (hito 4) ------------------------------

func _almacen_dicts() -> Array:
	var out: Array = []
	for m in Game.almacen_materiales:
		out.append(_item_a_dict(m))
	return out


func _cargar_almacen(arr: Array) -> void:
	var lista: Array[MaterialItem] = []
	for d in arr:
		var it := _item_de_dict(d)
		if it is MaterialItem:
			lista.append(it)
	Game.almacen_materiales = lista


# La llama un menu de taller (herrero/carpintero/boticaria/peletero) al abrir, o una accion
# suelta (depositar/vender del hogar) antes de tocar el baul. true = tienes el taller y tu
# Game.almacen_materiales YA es el baul autoritativo; false = esta ocupado por tu companero.
func abrir_taller() -> bool:
	if not activo:
		return true   # solitario: el baul es tuyo y punto
	if es_host:
		if _taller_dueno != 0 and _taller_dueno != 1:
			return false
		_taller_dueno = 1
		return true
	# Cliente: pedir al host y esperar respuesta.
	_taller_resp = 0
	_pedir_taller.rpc_id(1)
	var t := 0.0
	while _taller_resp == 0 and t < 5.0:
		await get_tree().process_frame
		t += get_process_delta_time()
	return _taller_resp == 1


@rpc("any_peer", "call_remote", "reliable")
func _pedir_taller() -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if _taller_dueno != 0 and _taller_dueno != quien:
		_taller_no.rpc_id(quien)
		return
	_taller_dueno = quien
	_taller_ok.rpc_id(quien, _almacen_dicts())   # le PRESTO el baul autoritativo


@rpc("authority", "call_remote", "reliable")
func _taller_ok(bag: Array) -> void:
	_cargar_almacen(bag)   # mi Game.almacen_materiales pasa a ser el baul de verdad
	_taller_resp = 1


@rpc("authority", "call_remote", "reliable")
func _taller_no() -> void:
	_taller_resp = -1


# La llama el menu al cerrar (o la accion suelta al terminar): devuelve el baul y suelta el candado.
func cerrar_taller() -> void:
	if not activo:
		return
	if es_host:
		if _taller_dueno == 1:
			_taller_dueno = 0
			_difundir_almacen()   # mi baul (ya modificado) va a los mirrors
	else:
		_soltar_taller.rpc_id(1, _almacen_dicts())


@rpc("any_peer", "call_remote", "reliable")
func _soltar_taller(bag: Array) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if _taller_dueno != quien:
		return
	_cargar_almacen(bag)   # el host adopta el baul que devuelve el cliente
	_taller_dueno = 0
	_difundir_almacen()


# ¿Tengo YO el candado del taller ahora mismo? (o estoy en solitario). Lo consulta Game antes de
# tocar el baul compartido, como red de seguridad contra desincronizar desde una UI despistada.
func tengo_taller() -> bool:
	if not activo:
		return true
	return _taller_dueno == multiplayer.get_unique_id()


func _difundir_almacen() -> void:
	_set_almacen.rpc(_almacen_dicts())
	hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_almacen(bag: Array) -> void:
	# No piso mi baul si soy YO quien tiene el taller prestado (estoy crafteando con el).
	if _taller_dueno == multiplayer.get_unique_id():
		return
	_cargar_almacen(bag)
	hogar_cambiado.emit()


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
		_registrar_y_difundir(d, pos, _mi_lugar)
	else:
		_pedir_soltar.rpc_id(1, d, pos, _mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_soltar(d: Dictionary, pos: Vector2, lugar: String) -> void:
	if not es_host:
		return
	_registrar_y_difundir(d, pos, lugar)


# Solo host: apunta el drop en el registro y lo difunde (a los peers por RPC, a si mismo directo).
# Guarda pos y LUGAR: un peer que entre despues (o que viaje a ese lugar) tiene que verlo.
func _registrar_y_difundir(d: Dictionary, pos: Vector2, lugar: String) -> void:
	var id := _next_id
	_next_id += 1
	_suelo[id] = {"d": d, "pos": pos, "lugar": lugar}
	_spawn_drop.rpc(id, d, pos, lugar)
	_spawn_drop(id, d, pos, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _spawn_drop(id: int, d: Dictionary, pos: Vector2, lugar: String) -> void:
	if lugar != _mi_lugar:
		return   # eso esta en OTRO sitio (otro piso, o el pueblo): aqui no se pinta
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

# Cliente: nada mas conectar, se presenta al host (id 1) con el codigo, su aspecto y su lugar.
func _on_connected_to_server() -> void:
	estado_cambiado.emit("Conectado. Validando codigo...")
	# Guardo MI baul de materiales antes de que el host me mande el suyo (lo recupero al salir).
	_almacen_solo = Game.almacen_materiales.duplicate()
	_almacen_guardado = true
	_saludar.rpc_id(1, _codigo, Game.player_color, Game.player_metalico, Game.player_nombre,
		_mi_lugar)


# Corre EN EL HOST, llamado por el cliente. Valida el codigo y, si vale, se registran
# mutuamente; si no, se echa al que intenta colarse.
@rpc("any_peer", "call_remote", "reliable")
func _saludar(codigo: String, color: Color, metal: float, nombre: String, lugar: String) -> void:
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
	# Codigo OK: registro mutuo. Viaja tambien la SEMILLA del mundo del host (para que el
	# cliente genere la MISMA mazmorra sin replicar geometria) y el lugar de cada uno.
	_registrar_peer(quien, color, metal, nombre, lugar)
	estado_cambiado.emit("%s se ha unido." % nombre)
	_presentarse.rpc_id(quien, Game.player_color, Game.player_metalico, Game.player_nombre,
		_mi_lugar, Game.semilla_mundo, Game.tienda_t2_abierta())
	# Y ponerle al dia el SUELO de su lugar: lo que ya estaba soltado antes de que entrara.
	for id in _suelo:
		if _suelo[id]["lugar"] == lugar:
			_spawn_drop.rpc_id(quien, id, _suelo[id]["d"], _suelo[id]["pos"], lugar)
	# Estado compartido del hogar (el del HOST): baul de materiales, bote y cofre.
	_set_almacen.rpc_id(quien, _almacen_dicts())
	_set_bote.rpc_id(quien, Game.bote_dinero)
	_set_cofre.rpc_id(quien, Game.cofre_equipo)
	_set_cofre_consumibles.rpc_id(quien, Game.cofre_consumibles)


# Corre en el CLIENTE, llamado por el host tras aceptarlo: registra al host y guarda su semilla.
@rpc("any_peer", "call_remote", "reliable")
func _presentarse(color: Color, metal: float, nombre: String, lugar: String, semilla: int,
		t2: bool) -> void:
	var quien := multiplayer.get_remote_sender_id()
	semilla_host = semilla
	tienda_t2_host = t2
	_registrar_peer(quien, color, metal, nombre, lugar)
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

# Registra los DATOS de un peer y, si comparte mi lugar, le monta el nodo visual.
func _registrar_peer(peer_id: int, color: Color, metal: float, nombre: String, lugar: String) -> void:
	_peers[peer_id] = {"color": color, "metal": metal, "nombre": nombre,
		"lugar": lugar, "pos": Vector2.INF}
	if lugar == _mi_lugar:
		_crear_avatar_nodo(peer_id)
	# El HOST recuenta y difunde el numero de humanos (los clientes reajustan al recibirlo).
	if es_host:
		_sync_humanos()


# Monta el nodo visual de un peer YA registrado (solo si compartimos lugar).
func _crear_avatar_nodo(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	if _avatares.has(peer_id) and is_instance_valid(_avatares[peer_id]):
		return
	var mundo: Node = get_tree().current_scene
	if mundo == null:
		return
	var p: Dictionary = _peers[peer_id]
	var av: Node2D = _REMOTE_PLAYER.new()
	mundo.add_child(av)
	av.aplicar_aspecto(p["color"], p["metal"], p["nombre"])
	if p["pos"] != Vector2.INF:
		av.ir_a(p["pos"])   # aparece donde iba, no en el origen
	_avatares[peer_id] = av


func _on_peer_disconnected(id: int) -> void:
	var conocido := _peers.has(id)
	var a: Node = _avatares.get(id)
	if a != null and is_instance_valid(a):
		a.queue_free()
	_avatares.erase(id)
	_peers.erase(id)
	# Su marcha cuenta como salir de la mazmorra: libera sus vetas y, si era el ultimo
	# dentro, la expedicion se cierra (solo decide el host).
	if es_host:
		_liberar_vetas_de(id)
		if _taller_dueno == id:   # se fue con el taller cogido: se libera (su crafteo a medias se pierde)
			_taller_dueno = 0
		if _dentro.has(id):
			_dentro.erase(id)
			if _dentro.is_empty():
				_cerrar_expedicion()
	# Solo avisar de gente que llego a ENTRAR (registrada): un intento rechazado por codigo
	# tambien dispara esta señal y no es "un jugador que se va".
	if conocido:
		estado_cambiado.emit("Un jugador se ha ido.")
		# Somos uno menos: el host recuenta y difunde; los apartados por cupo van volviendo.
		if es_host:
			_sync_humanos()


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
	# Si me pilla DENTRO de la mazmorra, de vuelta al pueblo: ese piso era del MUNDO DEL HOST
	# (su semilla); sin sesion no tiene sentido seguir alli.
	var en_mazmorra := _mi_lugar.begins_with("piso:")
	desconectar()
	if en_mazmorra:
		Game.current_floor = 1
		Game.olvidar_mazmorra()
		get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
