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
#  TRAMPA DE GDSCRIPT (costo 471 errores en una prueba headless): los diccionarios de NODOS
#  (_avatares, _drops, _enem_nodos) guardan referencias que pueden quedar LIBERADAS al cambiar de
#  escena. Asignar una instancia ya liberada a una variable TIPADA (`var a: Node = _avatares[id]`)
#  LANZA error en Godot 4. Hay que leerlas SIN TIPAR (`var a = ...`) y filtrar con
#  is_instance_valid(). Todas las lecturas de esos tres diccionarios siguen esa regla.
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
const _REMOTE_ENEMY := preload("res://scripts/actors/enemy/remote_enemy.gd")
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
var _peers: Dictionary = {}        # peer_id -> {"color","metal","nombre","lugar","pos","comps"}
var _avatares: Dictionary = {}     # peer_id -> nodo RemotePlayer (solo peers de mi lugar)
# Sus ACOMPAÑANTES (hito 5.4): peer_id -> Array de cuerpos. Reusan remote_player.gd, que ya es un
# cuerpo del grupo "aliado": asi los bichos tambien pueden perseguirlos y saltarles encima, y la
# pelea se le empuja a su dueño por la meta peer_id, igual que con el cuerpo del jugador.
var _avatares_comp: Dictionary = {}
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

# --- PISOS INDEPENDIENTES y DUEÑO DE PISO (hito 5.2) -----------------------------------------
# Cada uno anda por el piso que quiera: el piso de cada cual vive en _peers[id]["lugar"]
# ("piso:N"), NO en un escalar de sesion. Las escaleras te mueven solo a TI.
#
# Como cada maquina solo puede simular UN piso (el suyo: Game.current_floor, el grupo
# "dungeon_floor" y los grupos enemy/corpse son globales del arbol), la simulacion se reparte:
# cada piso tiene UN DUEÑO, que es quien corre la IA/spawns alli y replica sus bichos. Estar solo
# en un piso = ser su dueño; si coincidis, manda uno y el otro espeja.
var _dueno_piso: Dictionary = {}   # piso:int -> peer_id que lo simula (SOLO host)
var _soy_dueno := false            # ¿simulo YO el piso en el que estoy? (cada maquina)
var _peleando := false             # ¿estoy en un combate ahora mismo? (se difunde: ver avisar_combate)

# --- PELEAS COMPARTIDAS (hito 5.4-C) ---------------------------------------------------------
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
# FOTO de los pisos sin nadie dentro: el piso se congela tal cual (bichos y cadaveres) y se
# restaura al volver, como en solitario. Vive en la SESION (host), no en el save de nadie: asi las
# dos maquinas no divergen y el save del cliente sigue sin tocarse.
var _fotos_piso: Dictionary = {}   # piso:int -> {"enemigos": [...]} (SOLO host)

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

# --- ENEMIGOS replicados (hito 5.1) ----------------------------------------------------------
# En multi los enemigos los SIMULA el host (IA, spawns, aforo: su codigo de siempre); los
# clientes solo los VEN. El host es la fuente de verdad: _enemigos apunta cada bicho vivo por id,
# con su NODO real (para leer su posicion en el tick), su LUGAR y su aspecto. Los clientes montan
# un remote_enemy por id en _enem_nodos. Mismo patron que _suelo/_drops.
#
# LIMITE de 5.1 (a resolver en la siguiente sub-fase): el host solo simula el piso en el que ESTA
# (su current_scene). Un cliente en OTRO piso no ve bichos (nadie los simula alli todavia). El
# etiquetado por lugar ya deja el canal listo para autoridad por-piso cuando toque.
# Bichos RESERVADOS: quien los esta peleando. Lo lleva el DUEÑO del piso, que es quien arbitra.
# Sin esto dos jugadores podrian coger el mismo bicho a la vez. Mismo espiritu que _vetas_ocupadas.
var _enem_ocupados: Dictionary = {}   # net_id -> peer_id que lo pelea (SOLO el dueño del piso)
var _enemigos: Dictionary = {}     # id -> {"nodo","lugar","color","lado"} (solo lo llena el host)
var _enem_nodos: Dictionary = {}   # id -> nodo remote_enemy (en los CLIENTES)
var _enem_next_id: int = 1         # contador de ids de enemigo del host
const _ENEM_TICK := 1.0 / 20.0     # ritmo de difusion de posiciones (~20 Hz, suave y barato)
var _enem_acum: float = 0.0

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


# El DUEÑO de un piso difunde las posiciones de SUS enemigos a ~20 Hz (hito 5.1/5.2). En
# solitario, o si solo espejo el piso, no hace nada. Va en _physics_process para leer las
# posiciones ya resueltas por la fisica del bicho ese frame.
func _physics_process(delta: float) -> void:
	if not activo or not _soy_dueno or _enemigos.is_empty() or multiplayer.multiplayer_peer == null:
		return
	_enem_acum += delta
	if _enem_acum < _ENEM_TICK:
		return
	_enem_acum = 0.0
	_difundir_posiciones_enemigos()


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
		var a = _avatares[id]
		if is_instance_valid(a):
			a.queue_free()
	_avatares.clear()
	for id in _avatares_comp.keys():
		_quitar_companeros(id)
	_avatares_comp.clear()
	# Los NODOS de los drops se quedan en el mundo como pickups locales normales (con
	# Net.activo=false el net_id deja de importar y F los coge por la rama de siempre). Solo se
	# vacian los registros. En el pueblo nada persiste, asi que el riesgo de duplicado tras una
	# desconexion es anecdotico y asumido (ver docs/MULTIJUGADOR.md).
	_suelo.clear()
	_drops.clear()
	# Enemigos: el host deja de simularlos por red; los cuerpos remotos del cliente se van (en el
	# pueblo no hay bichos, y al desconectar el cliente vuelve a su mundo sin sesion).
	for id in _enem_nodos.keys():
		var e = _enem_nodos[id]
		if is_instance_valid(e):
			e.retirar()
	_enem_nodos.clear()
	_enemigos.clear()
	_enem_ocupados.clear()
	_enem_next_id = 1
	_enem_acum = 0.0
	_peers.clear()
	_dentro.clear()
	_vetas_ocupadas.clear()
	_agotados_sesion.clear()
	expedicion_abierta = false
	_dueno_piso.clear()
	_fotos_piso.clear()
	_soy_dueno = false
	_peleando = false
	_pelea_id = 0
	_pelea_participantes.clear()
	_dobles.clear()
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()
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
func enviar_estado(pos: Vector2, facing: Vector2, comps: Array = []) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	_recibir_estado.rpc(pos, facing, comps)


# --- ¿QUIEN ESTA PELEANDO? (hito 5.3) --------------------------------------------------------
# Lo difunde Game al abrir/cerrar un combate. Sirve para que las paredes NO te paran bichos en las
# narices mientras estas en una pelea (no puedes ni verlo venir): ver spawn_zone._dist_min_de.
func avisar_combate(peleando: bool) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	_peleando = peleando
	_set_peleando.rpc(peleando)


@rpc("any_peer", "call_remote", "reliable")
func _set_peleando(peleando: bool) -> void:
	var emisor := multiplayer.get_remote_sender_id()
	if _peers.has(emisor):
		_peers[emisor]["peleando"] = peleando


# Donde esta cada OTRO jugador de mi mismo lugar y si esta peleando. Lo consultan las zonas de
# parto para no hacer nacer bichos encima de nadie (y menos aun encima de quien pelea).
func jugadores_remotos_aqui() -> Array:
	var out: Array = []
	if not activo:
		return out
	for id in _peers:
		var p: Dictionary = _peers[id]
		if p.get("lugar", "") == _mi_lugar and p.get("pos", Vector2.INF) != Vector2.INF:
			out.append({"pos": p["pos"], "peleando": bool(p.get("peleando", false))})
	return out


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recibir_estado(pos: Vector2, _facing: Vector2, comps: Array = []) -> void:
	var emisor := multiplayer.get_remote_sender_id()
	if _peers.has(emisor):
		_peers[emisor]["pos"] = pos   # se recuerda: al reconstruir su avatar aparece donde iba
	var a = _avatares.get(emisor)   # SIN tipar: puede ser una instancia ya liberada (ver nota abajo)
	if a != null and is_instance_valid(a):
		a.ir_a(pos)
	# Y sus acompañantes. Si aun no tengo tantos cuerpos como manda, se crean sobre la marcha (su
	# aspecto llega aparte, por _set_grupo).
	if not comps.is_empty():
		_mover_companeros(emisor, comps)


# Coloca (y crea si hacen falta) los cuerpos de los acompañantes de un peer.
func _mover_companeros(peer_id: int, posiciones: Array) -> void:
	if not _peers.has(peer_id) or _peers[peer_id].get("lugar", "") != _mi_lugar:
		return
	var lista: Array = _avatares_comp.get(peer_id, [])
	while lista.size() < posiciones.size():
		var c = _crear_cuerpo_companero(peer_id, lista.size())
		if c == null:
			break
		lista.append(c)
	_avatares_comp[peer_id] = lista
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
	var c: Node2D = _REMOTE_PLAYER.new()
	mundo.add_child(c)
	c.set_meta("peer_id", peer_id)
	var comps: Array = _peers[peer_id].get("comps", [])
	if idx < comps.size():
		var d: Dictionary = comps[idx]
		c.aplicar_aspecto(d.get("color", Color.WHITE), float(d.get("metal", 0.0)),
			String(d.get("nombre", "")), d.get("imagen", PackedByteArray()))
	return c


# --- ASPECTO DE MI GRUPO (hito 5.4) ----------------------------------------------------------
# El color/brillo/nombre de MIS acompañantes. Va aparte de la posicion (que viaja 60 veces por
# segundo) porque solo cambia cuando cambia el equipo. Se difunde al conectar y al tocar el grupo.
func anunciar_grupo() -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	var datos: Array = []
	for pj in Game.companeros():
		datos.append({"color": pj.color, "metal": pj.metalico, "nombre": pj.nombre,
			"imagen": pj.imagen})
	_set_grupo.rpc(datos)


@rpc("any_peer", "call_remote", "reliable")
func _set_grupo(datos: Array) -> void:
	var emisor := multiplayer.get_remote_sender_id()
	if not _peers.has(emisor):
		return
	_peers[emisor]["comps"] = datos
	# Si tenia cuerpos de mas (se dejo gente en casa), fuera; y a los que quedan, su cara nueva.
	var lista: Array = _avatares_comp.get(emisor, [])
	while lista.size() > datos.size():
		var sobra = lista.pop_back()
		if is_instance_valid(sobra):
			sobra.queue_free()
	for i in mini(lista.size(), datos.size()):
		if is_instance_valid(lista[i]):
			var d: Dictionary = datos[i]
			lista[i].aplicar_aspecto(d.get("color", Color.WHITE), float(d.get("metal", 0.0)),
				String(d.get("nombre", "")), d.get("imagen", PackedByteArray()))
	_avatares_comp[emisor] = lista


# Tira los cuerpos de los acompañantes de un peer (cambio de lugar, se fue, fin de sesion).
func _quitar_companeros(peer_id: int) -> void:
	for c in _avatares_comp.get(peer_id, []):
		if is_instance_valid(c):
			c.queue_free()
	_avatares_comp.erase(peer_id)


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
	var a = _avatares.get(emisor)   # SIN tipar: puede ser una instancia ya liberada (ver nota abajo)
	if lugar == _mi_lugar:
		if a == null or not is_instance_valid(a):
			_crear_avatar_nodo(emisor)
	else:
		if a != null and is_instance_valid(a):
			a.queue_free()
		_avatares.erase(emisor)
		_quitar_companeros(emisor)   # su sequito se va con el


# Tras viajar YO: la escena vieja murio (y con ella mis avatares/drops). Se espera a que la
# nueva este montada y se reconstruye lo que toca ver aqui.
func _reconstruir_vista() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for id in _avatares.keys():
		var a = _avatares[id]
		if is_instance_valid(a):
			a.queue_free()
	_avatares.clear()
	for id in _avatares_comp.keys():
		_quitar_companeros(id)   # sus acompañantes murieron con la escena vieja tambien
	for id in _peers:
		if _peers[id]["lugar"] == _mi_lugar:
			_crear_avatar_nodo(id)
	for id in _drops.keys():
		var n = _drops[id]
		if is_instance_valid(n):
			n.queue_free()
	_drops.clear()
	if es_host:
		for id in _suelo:
			if _suelo[id]["lugar"] == _mi_lugar:
				_spawn_drop(id, _suelo[id]["d"], _suelo[id]["pos"], _mi_lugar)
	else:
		_pedir_suelo.rpc_id(1, _mi_lugar)
	# ENEMIGOS (hito 5.1/5.2): los cuerpos remotos murieron con la escena vieja. Si SIMULO este
	# piso no hay nada que pedir (los mios son reales y el piso ya los crea al poblarse/restaurar);
	# si solo lo espejo, pido la lista a quien lo simule. Al host no puede pedirsela a si mismo:
	# mira quien es el dueño y se la pide directamente.
	for id in _enem_nodos.keys():
		var en = _enem_nodos[id]   # sin tipar: puede ser una instancia ya liberada (ver purga del tick)
		if is_instance_valid(en):
			en.retirar()
	_enem_nodos.clear()
	if not _soy_dueno and _mi_lugar.begins_with("piso:"):
		if es_host:
			var dueno: int = _dueno_piso.get(mi_piso(), 0)
			if dueno != 0 and dueno != 1:
				_pedir_roster.rpc_id(dueno, _mi_lugar, 1)
		else:
			_pedir_enemigos.rpc_id(1, _mi_lugar)


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


# Solo host: apunta al peer como "dentro" y le concede la entrada. Por la puerta se entra SIEMPRE
# por el piso 1 (como en solitario): ya no existe "el piso activo de la sesion", cada uno anda por
# donde quiera. De paso se reparte quien simula el piso 1 y se le pasa su foto si estaba congelado.
func _conceder_entrada(quien: int) -> void:
	if not expedicion_abierta:
		expedicion_abierta = true
	_dentro[quien] = true
	var dueno: bool = _asignar_dueno(1, quien)
	var mem: Dictionary = {}
	if dueno:
		mem = _fotos_piso.get(1, {})
		_fotos_piso.erase(1)
	if quien == 1:
		_entrar_ok(1, _agotados_sesion.keys(), dueno, mem)
	else:
		_entrar_ok.rpc_id(quien, 1, _agotados_sesion.keys(), dueno, mem)


# Corre en QUIEN entra: hace el viaje completo. olvidar_mazmorra() limpia la memoria LOCAL de
# expediciones viejas (imprescindible tambien para el que se une: si no, restauraria SUS bichos
# rancios); los agotados de LA SESION llegan del host para que las vetas ya picadas no nazcan.
@rpc("any_peer", "call_remote", "reliable")
func _entrar_ok(piso: int, agotados: Array, dueno: bool, mem: Dictionary) -> void:
	_agotados_sesion.clear()
	for c in agotados:
		_agotados_sesion[c] = true
	Game.current_floor = piso
	Game.olvidar_mazmorra()
	_olvidar_mis_enemigos()
	# ¿Simulo yo este piso? Si si, y venia congelado, se siembra la memoria LOCAL con su foto para
	# que _restaurar_estado lo levante igual que en solitario (va DESPUES de olvidar_mazmorra,
	# que la vacia entera).
	_soy_dueno = dueno
	if dueno and not mem.is_empty():
		Game.memoria_pisos[piso] = _mem_de_red(mem)
	Game.iniciar_expedicion_mapa()
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	anunciar_lugar("piso:%d" % piso)


# La llama la puerta de vuelta / la salida del boss (rama multi), DESPUES de consolidar el mapa.
func viajar_al_pueblo() -> void:
	# Me llevo la foto del piso que dejo (si lo simulaba yo) para que no se pierdan sus bichos:
	# se la queda el host, o pasa al que siga dentro. Hay que sacarla ANTES de cambiar de escena.
	var foto: Dictionary = _foto_de_mi_piso()
	_soy_dueno = false
	_olvidar_mis_enemigos()
	if es_host:
		_registrar_salida(1, foto)
	else:
		_pedir_salir.rpc_id(1, foto)
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	anunciar_lugar("pueblo")


@rpc("any_peer", "call_remote", "reliable")
func _pedir_salir(foto: Dictionary) -> void:
	if not es_host:
		return
	_registrar_salida(multiplayer.get_remote_sender_id(), foto)


func _registrar_salida(quien: int, foto: Dictionary = {}) -> void:
	_liberar_vetas_de(quien)
	_soltar_piso(quien, foto)
	_dentro.erase(quien)
	if _dentro.is_empty() and expedicion_abierta:
		_cerrar_expedicion()


# Solo host: el ultimo salio. La expedicion se olvida: fuera drops de pisos y agotados de sesion.
func _cerrar_expedicion() -> void:
	expedicion_abierta = false
	# La mazmorra se olvida: ni dueños ni pisos congelados (la proxima expedicion nace limpia,
	# como en solitario).
	_dueno_piso.clear()
	_fotos_piso.clear()
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
	if not _mi_lugar.begins_with("piso:"):
		return -1
	return int(_mi_lugar.substr(5))


# ¿Simulo yo los bichos del piso donde estoy? En solitario SIEMPRE (no hay red que repartir).
# Lo consultan los gates de dungeon_floor (hay_sitio, boss, poblacion).
func simulo_mi_piso() -> bool:
	return (not activo) or _soy_dueno


# La llama stairs.gd (rama multi). 'bajando' es para aparecer en la boca del piso o junto a la
# escalera, igual que en solitario.
func solicitar_piso(nuevo: int, bajando: bool) -> void:
	if nuevo < 1:
		return
	var foto: Dictionary = _foto_de_mi_piso()   # lo que dejo atras, si yo lo simulaba
	if es_host:
		_conceder_piso(1, nuevo, bajando, foto)
	else:
		_pedir_viaje.rpc_id(1, nuevo, bajando, foto)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_viaje(nuevo: int, bajando: bool, foto: Dictionary) -> void:
	if not es_host:
		return
	_conceder_piso(multiplayer.get_remote_sender_id(), nuevo, bajando, foto)


# Solo host: arbitra el viaje de 'quien' al piso 'nuevo'. Suelta el piso viejo (con su foto) y
# reparte el nuevo. Responde SIEMPRE, porque el viajero espera para reconstruir su piso.
func _conceder_piso(quien: int, nuevo: int, bajando: bool, foto: Dictionary) -> void:
	if not expedicion_abierta:
		return
	_soltar_piso(quien, foto)
	var dueno_nuevo: bool = _asignar_dueno(nuevo, quien)
	# Si voy a simularlo, me llevo la foto congelada de ese piso (bichos y cadaveres tal cual).
	var mem: Dictionary = {}
	if dueno_nuevo:
		mem = _fotos_piso.get(nuevo, {})
		_fotos_piso.erase(nuevo)   # ya no esta congelado: pasa a estar vivo en su dueño
	if quien == 1:
		_viaje_ok(nuevo, bajando, dueno_nuevo, mem)
	else:
		_viaje_ok.rpc_id(quien, nuevo, bajando, dueno_nuevo, mem)


# Solo host: 'quien' deja de simular el piso que tuviera. Si queda gente alli, se le pasa el
# relevo con la foto (traspaso fiel: mismos bichos, mismas posiciones). Si no queda nadie, el piso
# se CONGELA en la foto de sesion hasta que alguien vuelva.
func _soltar_piso(quien: int, foto: Dictionary) -> void:
	var piso: int = -1
	for p in _dueno_piso:
		if _dueno_piso[p] == quien:
			piso = p
			break
	if piso < 0:
		return
	_dueno_piso.erase(piso)
	var heredero: int = _alguien_en(piso, quien)
	if heredero == 0:
		_fotos_piso[piso] = foto   # nadie mas: el piso queda congelado tal cual
		return
	_dueno_piso[piso] = heredero
	# Los OTROS que sigan en ese piso tiran sus espejos: el dueño nuevo va a recrear los bichos con
	# ids nuevos y, sin esto, los verian por duplicado (se nota con 3-4 jugadores).
	var lugar := "piso:%d" % piso
	for pid in _peers:
		if pid != heredero and _peers[pid].get("lugar", "") == lugar:
			_limpiar_espejo.rpc_id(pid)
	if heredero != 1 and _mi_lugar == lugar:
		_limpiar_espejo()
	if heredero == 1:
		_asumir_piso(piso, foto)
	else:
		_asumir_piso.rpc_id(heredero, piso, foto)


# Solo host: nombra dueño de 'piso' a 'quien' si esta libre. Devuelve si le toca simularlo.
func _asignar_dueno(piso: int, quien: int) -> bool:
	var actual: int = _dueno_piso.get(piso, 0)
	if actual == 0 or actual == quien or not _sigue_en(actual, piso):
		_dueno_piso[piso] = quien
		return true
	return false


# Solo host: un peer (distinto de 'salvo') que este en ese piso, o 0 si no hay nadie.
func _alguien_en(piso: int, salvo: int) -> int:
	var lugar := "piso:%d" % piso
	if salvo != 1 and _mi_lugar == lugar:
		return 1            # el host tambien cuenta como candidato
	for id in _peers:
		if id != salvo and _peers[id].get("lugar", "") == lugar:
			return id
	return 0


# Solo host: ¿ese peer sigue realmente en ese piso? (dueño fantasma si se fue sin avisar).
func _sigue_en(quien: int, piso: int) -> bool:
	var lugar := "piso:%d" % piso
	if quien == 1:
		return _mi_lugar == lugar
	return _peers.has(quien) and _peers[quien].get("lugar", "") == lugar


# Corre en EL VIAJERO: ya se sabe si simula el piso nuevo, asi que se puede reconstruir.
@rpc("any_peer", "call_remote", "reliable")
func _viaje_ok(nuevo: int, bajando: bool, dueno: bool, mem: Dictionary) -> void:
	_olvidar_mis_enemigos()   # los del piso que dejo mueren con su escena
	_soy_dueno = dueno
	# Sembrar la memoria LOCAL con la foto de sesion: asi _restaurar_estado (el mismo codigo que
	# en solitario) reconstruye el piso tal cual quedo. Si no lo simulo, se limpia para que no
	# resucite bichos mios rancios: los vere por red.
	if dueno and not mem.is_empty():
		Game.memoria_pisos[nuevo] = _mem_de_red(mem)
	else:
		Game.memoria_pisos.erase(nuevo)
	Game._cambiar_piso(nuevo, bajando)
	anunciar_lugar("piso:%d" % nuevo)


# Corre en QUIEN HEREDA un piso donde ya esta de pie: sus cuerpos espejados se van y en su lugar
# nacen los bichos de verdad, en las mismas posiciones y con las mismas stats.
@rpc("any_peer", "call_remote", "reliable")
func _asumir_piso(piso: int, mem: Dictionary) -> void:
	if mi_piso() != piso:
		return
	_soy_dueno = true
	_limpiar_espejo()   # respeta los que esté peleando (ver alli)
	var suelo: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if suelo != null and suelo.has_method("adoptar_foto"):
		suelo.adoptar_foto(_mem_de_red(mem))


# --- FOTO de un piso: el formato de Game.memoria_pisos, apto para la red -----------------------
# Se manda la RUTA del EnemyData (.tres de disco) en vez del recurso, como ya se hace con los
# materiales del suelo (ver _item_a_dict). load() cachea, asi que al rehidratar sale la MISMA
# instancia y la comparacion de identidad del boss (dungeon_floor._restaurar_estado) sigue valiendo.
# El "suelo" NO va: en sesion los drops los lleva Net (_suelo/_drops); meterlos aqui los duplicaria.
func _foto_de_mi_piso() -> Dictionary:
	if not activo or not _soy_dueno:
		return {}
	var piso := mi_piso()
	if piso < 0:
		return {}
	var f: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if f != null and f.has_method("volcar_a_memoria"):
		f.volcar_a_memoria()   # vuelca los bichos VIVOS de ahora mismo a Game.memoria_pisos
	return _mem_a_red(Game.memoria_pisos.get(piso, {}))


func _mem_a_red(mem: Dictionary) -> Dictionary:
	var out: Array = []
	for d in (mem.get("enemigos", []) as Array):
		var data = d.get("data")
		if data == null or String(data.resource_path).is_empty():
			continue   # un EnemyData creado en runtime no se puede mandar por ruta
		out.append({
			"ruta": data.resource_path,
			"pos": d["pos"], "t": d["t"], "zona": d["zona"], "muerto": d["muerto"],
		})
	return {"enemigos": out}


# Dejo de simular el piso donde estaba: sus bichos mueren con la escena, asi que su registro se va
# con ellos. Si no, las entradas rancias se quedan pegadas (y el dia que vuelva a ser dueño de algo
# las difundiria). Se llama SIEMPRE antes de reconstruir/abandonar un piso, y despues de sacar la
# foto: baja_enemigo no sirve aqui porque se cae por el guard de _soy_dueno.
func _olvidar_mis_enemigos() -> void:
	_enemigos.clear()
	_enem_ocupados.clear()   # las reservas eran de esos bichos: se van con ellos


# El dueño de un piso ha cambiado: los que sigan ahi tiran sus cuerpos espejados, porque el dueño
# nuevo va a recrear los bichos con ids nuevos (si no, se verian por duplicado).
#
# MENOS los que estoy PELEANDO: el combate guarda esos nodos (Game._active_enemies) y borrarlos deja
# la pelea con referencias muertas -> la pantalla se queda colgada y el jugador NO PUEDE MOVERSE.
# Se quedan hasta que termine la pelea; al acabar, su resultado se resuelve en local (ver
# remote_enemy.morir), porque para entonces el dueño al que habria que avisar ya no esta.
@rpc("any_peer", "call_remote", "reliable")
func _limpiar_espejo() -> void:
	for id in _enem_nodos.keys():
		var n = _enem_nodos[id]
		if not is_instance_valid(n):
			_enem_nodos.erase(id)
			continue
		if Game.combate_activo() and Game._active_enemies.has(n):
			continue   # esta en mi pelea: no se toca
		n.retirar()
		_enem_nodos.erase(id)


func _mem_de_red(mem: Dictionary) -> Dictionary:
	var out: Array = []
	for d in (mem.get("enemigos", []) as Array):
		var data = load(str(d["ruta"]))
		if data == null:
			continue
		out.append({
			"data": data,
			"pos": d["pos"], "t": d["t"], "zona": d["zona"], "muerto": d["muerto"],
		})
	return {"enemigos": out, "suelo": []}


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


# --- BOSS CAIDO (hito 5.3) --------------------------------------------------------------------
#
# Lo llama enemy.morir() del jefe, en la maquina que simula ese piso. Decision del usuario: el
# ATAJO y la TIENDA se abren para TODOS los de la sesion (lo habeis hecho juntos), pero el CREDITO
# DE NIVEL es POR PERSONAJE y no se toca aqui: guardianes_vencidos solo lo apuntan los personajes
# que estuvieron en ESA pelea (ver Game._on_combat_finished). Si no participaste, se te abre el
# atajo pero no cuentas con haberlo matado.
func avisar_boss_caido(piso: int) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	_boss_caido.rpc(piso)


# Corre en TODOS: apunta el hito de mundo y, si estoy en ESE piso, abre sus salidas (la escalera
# de bajada y la puerta al pueblo). Sin esto, el compañero que estaba en la sala del jefe nunca
# veria aparecer la bajada.
@rpc("any_peer", "call_remote", "reliable")
func _boss_caido(piso: int) -> void:
	Game.marcar_boss_derrotado(piso)
	if mi_piso() != piso:
		return
	var f: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if f != null and f.has_method("abrir_salidas"):
		f.abrir_salidas()


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
	var n = _drops.get(id)
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
	if not activo or not _soy_dueno or nodo == null or multiplayer.multiplayer_peer == null:
		return
	# El id lleva DENTRO quien lo creo: con varios dueños simulando pisos a la vez, un contador
	# suelto en cada maquina chocaria. Asi son unicos sin preguntarle nada a nadie.
	var id := multiplayer.get_unique_id() * 1000000 + _enem_next_id
	_enem_next_id += 1
	nodo.set_meta("net_id", id)   # el id de red viaja como meta, sin tocar la clase enemy
	_enemigos[id] = {"nodo": nodo, "lugar": lugar}
	var d: Dictionary = _datos_enemigo(nodo)
	if es_host:
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
	if nodo.has_method("esta_muerto"):
		d["muerto"] = bool(nodo.esta_muerto())
	return d


# Lo llama el dueño cuando un bicho DESAPARECE del mundo (reciclado, piso desmontado): lo borra
# del registro y avisa para que quiten su cuerpo. Un cadaver NO llama a esto: la muerte replicada
# es de una sub-fase posterior (con el combate).
func baja_enemigo(nodo: Node) -> void:
	if not activo or not _soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	if not _enemigos.has(id):
		return
	var lugar: String = _enemigos[id]["lugar"]
	_enemigos.erase(id)
	if es_host:
		_despawn_enemigo.rpc(id)
	else:
		_rel_despawn.rpc_id(1, id, lugar)


# --- RETRANSMISION (solo host): lo que le manda un dueño CLIENTE se reparte a los de ese piso ---
# Al emisor no se le devuelve (ya tiene el bicho de verdad), y el propio host lo pinta si esta
# en ese piso sin ser su dueño.

@rpc("any_peer", "call_remote", "reliable")
func _rel_spawn(id: int, lugar: String, pos: Vector2, d: Dictionary) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar and not _soy_dueno:
		_spawn_enemigo(id, lugar, pos, d)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_spawn_enemigo.rpc_id(pid, id, lugar, pos, d)


# Lo llama enemy.morir() en la maquina que SIMULA el piso: el bicho pasa a cadaver y hay que
# decirselo a los demas (el nodo NO se libera al morir, asi que _exit_tree/baja_enemigo no salta).
func enemigo_muerto(nodo: Node) -> void:
	if not activo or not _soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	if not _enemigos.has(id):
		return
	_enemigos[id]["muerto"] = true
	var lugar: String = _enemigos[id]["lugar"]
	if es_host:
		_marcar_cadaver.rpc(id, lugar)
	else:
		_rel_cadaver.rpc_id(1, id, lugar)


@rpc("authority", "call_remote", "reliable")
func _marcar_cadaver(id: int, lugar: String) -> void:
	if lugar != _mi_lugar:
		return
	var n = _enem_nodos.get(id)
	if n != null and is_instance_valid(n) and n.has_method("marcar_cadaver"):
		n.marcar_cadaver()


@rpc("any_peer", "call_remote", "reliable")
func _rel_cadaver(id: int, lugar: String) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar and not _soy_dueno:
		_marcar_cadaver(id, lugar)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_marcar_cadaver.rpc_id(pid, id, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_despawn(id: int, lugar: String) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar and not _soy_dueno:
		_despawn_enemigo(id)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_despawn_enemigo.rpc_id(pid, id)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rel_tick(lugar: String, lote: Array) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar and not _soy_dueno:
		_tick_enemigos(lote)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_tick_enemigos.rpc_id(pid, lote)


# Le llega al dueño CLIENTE de un piso: alguien acaba de entrar ahi y necesita su lista de bichos.
# La respuesta vuelve a pasar por el host, que la reenvia solo a ese peer.
@rpc("any_peer", "call_remote", "reliable")
func _pedir_roster(lugar: String, para: int) -> void:
	if _mi_lugar != lugar or not _soy_dueno:
		return
	for id in _enemigos:
		var e: Dictionary = _enemigos[id]
		if is_instance_valid(e["nodo"]):
			_rel_spawn_a.rpc_id(1, para, id, lugar, (e["nodo"] as Node2D).global_position,
				_datos_enemigo(e["nodo"]))


@rpc("any_peer", "call_remote", "reliable")
func _rel_spawn_a(para: int, id: int, lugar: String, pos: Vector2, d: Dictionary) -> void:
	if not es_host:
		return
	if para == 1:
		_spawn_enemigo(id, lugar, pos, d)
	else:
		_spawn_enemigo.rpc_id(para, id, lugar, pos, d)


@rpc("authority", "call_remote", "reliable")
func _spawn_enemigo(id: int, lugar: String, pos: Vector2, d: Dictionary) -> void:
	if lugar != _mi_lugar:
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
	cuerpo.configurar(d.get("color", Color.WHITE), float(d.get("lado", 32.0)))
	cuerpo.aplicar_datos(String(d.get("ruta", "")), float(d.get("t", 0.5)),
		bool(d.get("muerto", false)), float(d.get("vis", 130.0)), float(d.get("ang", 50.0)))
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
			if es_host:
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
		var est: Array = nd.estado_visual_red() if nd.has_method("estado_visual_red") else [0.0, false]
		lote.append([id, (nd as Node2D).global_position, est[0], est[1]])
	if es_host:
		for peer_id in _peers:
			if _peers[peer_id].get("lugar", "") == _mi_lugar:
				_tick_enemigos.rpc_id(peer_id, lote)
	else:
		_rel_tick.rpc_id(1, _mi_lugar, lote)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _tick_enemigos(lote: Array) -> void:
	for par in lote:
		var n = _enem_nodos.get(par[0])
		if n == null or not is_instance_valid(n):
			continue
		n.ir_a(par[1])
		if par.size() >= 4:
			n.aplicar_estado_visual(float(par[2]), bool(par[3]))


# Alguien que acaba de llegar a un piso pide sus enemigos (late-join / cambio de piso). Siempre se
# le pregunta al HOST, que es quien sabe QUIEN simula ese piso: si es el, responde; si es un
# cliente, le reenvia la peticion para que conteste el (via _pedir_roster).
@rpc("any_peer", "call_remote", "reliable")
func _pedir_enemigos(lugar: String) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar and _soy_dueno:
		for id in _enemigos:
			var e: Dictionary = _enemigos[id]
			if is_instance_valid(e["nodo"]):
				_spawn_enemigo.rpc_id(quien, id, lugar, (e["nodo"] as Node2D).global_position,
					_datos_enemigo(e["nodo"]))
		return
	var piso: int = int(lugar.substr(5)) if lugar.begins_with("piso:") else -1
	var dueno: int = _dueno_piso.get(piso, 0)
	if dueno != 0 and dueno != quien:
		_pedir_roster.rpc_id(dueno, lugar, quien)


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
	if not activo or _soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		_encaminar_pelea(id, _mi_lugar, 1)
	else:
		_pedir_pelea.rpc_id(1, id, _mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_pelea(id: int, lugar: String) -> void:
	if not es_host:
		return
	_encaminar_pelea(id, lugar, multiplayer.get_remote_sender_id())


# SOLO host: le pasa la peticion a quien simule ese piso (o la resuelve el mismo si es suyo).
func _encaminar_pelea(id: int, lugar: String, quien: int) -> void:
	if _mi_lugar == lugar and _soy_dueno:
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
	if _mi_lugar != lugar or not _soy_dueno:
		return
	_resolver_pelea(id, para, lugar)


# SOLO el dueño: arbitra. Reserva el bicho y sus vecinos y responde con sus ids (vacio = ocupado).
# El grupo lo calcula vecinos(), el mismo que en solitario: es quien tiene los nodos reales y sabe
# quien esta al lado, con el tope MAX_COMBATIENTES.
func _resolver_pelea(id: int, quien: int, _lugar: String) -> void:
	var e: Dictionary = _enemigos.get(id, {})
	var nodo = e.get("nodo") if not e.is_empty() else null
	# ¿Ese bicho YA lo esta peleando alguien? Entonces la respuesta no es "ocupado", es una
	# INVITACION A UNIRSE a esa pelea (hito 5.4-C): es lo que espera el jugador cuando ve a su
	# compañero peleando y va a echar una mano.
	var anfitrion: int = int(_enem_ocupados.get(id, 0))
	if anfitrion == 0 and nodo != null and is_instance_valid(nodo) and nodo.get("_combat_triggered"):
		# Nadie lo tiene reservado pero esta congelado: lo estoy peleando YO (mis propias peleas no
		# pasan por _enem_ocupados, las monta enemy._start_combat directamente).
		anfitrion = multiplayer.get_unique_id()
	if anfitrion != 0 and anfitrion != quien:
		_responder_pelea(quien, [], false, anfitrion)
		return
	_responder_pelea(quien, _reservar_grupo(nodo, id, quien), false)


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
func empujar_pelea(nodo: Node, peer: int) -> void:
	if not activo or not _soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if nodo == null or not nodo.has_meta("net_id"):
		return
	var id: int = nodo.get_meta("net_id")
	var ids: Array = _reservar_grupo(nodo, id, peer)
	if ids.is_empty():
		return
	_responder_pelea(peer, ids, true)


# La respuesta vuelve al destinatario; si yo soy un dueño CLIENTE, pasa por el host.
#
# OJO: hay que comparar con MI id, no con 1. "quien == 1" significa "el peticionario es el host",
# que solo soy YO si yo soy el host; en un dueño CLIENTE, tratarlo como propio se comia la
# respuesta y el que ataco se quedaba sin pelea (sin error ninguno, que es lo traicionero).
func _responder_pelea(quien: int, ids: Array, emboscada: bool, anfitrion: int = 0) -> void:
	if quien == multiplayer.get_unique_id():
		_pelea_resuelta(ids, emboscada, anfitrion)
	elif es_host:
		_pelea_resuelta.rpc_id(quien, ids, emboscada, anfitrion)
	else:
		_rel_respuesta_pelea.rpc_id(1, quien, ids, emboscada, anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _rel_respuesta_pelea(para: int, ids: Array, emboscada: bool, anfitrion: int = 0) -> void:
	if not es_host:
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
		var n = _enem_nodos.get(i)
		if n != null and is_instance_valid(n):
			n.entrar_en_pelea()
			nodos.append(n)
	if nodos.is_empty():
		return
	# Ya estoy peleando: estos se UNEN a mi pelea en vez de abrir otra (una por maquina). El que no
	# quepa se DEVUELVE al dueño: si no, se quedaria reservado y congelado para siempre.
	if Game.combate_activo():
		for n in nodos:
			if not Game.unir_enemigo_al_combate(n):
				n.salir_de_pelea()
		return
	# Emboscada solo si me han saltado encima; si ataque yo, la iniciativa es mia.
	Game.start_combat(nodos, emboscada)


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
	if _soy_dueno:
		var e: Dictionary = _enemigos.get(id, {})
		return e.get("nodo") if not e.is_empty() else null
	return _enem_nodos.get(id)


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
	if not activo or ids.is_empty() or multiplayer.multiplayer_peer == null:
		return
	var yo: int = multiplayer.get_unique_id()
	if _soy_dueno:
		_aplicar_reasignacion(ids, yo)
	elif es_host:
		_encaminar_reasignacion(ids, _mi_lugar, yo)
	else:
		_pedir_reasignacion.rpc_id(1, ids, _mi_lugar, yo)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_reasignacion(ids: Array, lugar: String, para: int) -> void:
	if not es_host:
		return
	_encaminar_reasignacion(ids, lugar, para)


func _encaminar_reasignacion(ids: Array, lugar: String, para: int) -> void:
	if _mi_lugar == lugar and _soy_dueno:
		_aplicar_reasignacion(ids, para)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_reasignacion.rpc_id(dueno, ids, lugar, para)


@rpc("any_peer", "call_remote", "reliable")
func _rel_reasignacion(ids: Array, lugar: String, para: int) -> void:
	if _mi_lugar != lugar or not _soy_dueno:
		return
	_aplicar_reasignacion(ids, para)


func _aplicar_reasignacion(ids: Array, para: int) -> void:
	for i in ids:
		if _enem_ocupados.has(int(i)):
			_enem_ocupados[int(i)] = para


# --- RESULTADO de una pelea jugada contra espejos ---------------------------------------------

# La llaman remote_enemy.morir() / .reanudar_tras_combate() al cerrarse el combate.
func resultado_bicho(id: int, ha_muerto: bool, hp: float) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		_encaminar_resultado(id, ha_muerto, hp, _mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_resultado.rpc_id(1, id, ha_muerto, hp, _mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_resultado(id: int, ha_muerto: bool, hp: float, lugar: String) -> void:
	if not es_host:
		return
	_encaminar_resultado(id, ha_muerto, hp, lugar)


func _encaminar_resultado(id: int, ha_muerto: bool, hp: float, lugar: String) -> void:
	if _mi_lugar == lugar and _soy_dueno:
		_aplicar_resultado(id, ha_muerto, hp)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_resultado.rpc_id(dueno, id, ha_muerto, hp, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_resultado(id: int, ha_muerto: bool, hp: float, lugar: String) -> void:
	if _mi_lugar != lugar or not _soy_dueno:
		return
	_aplicar_resultado(id, ha_muerto, hp)


# SOLO el dueño: lo que paso en la pelea de otro se aplica sobre el bicho DE VERDAD. morir() ya se
# encarga de difundir el cadaver a todos (y de abrir las salidas si era el jefe).
func _aplicar_resultado(id: int, ha_muerto: bool, hp: float) -> void:
	_enem_ocupados.erase(id)
	var e: Dictionary = _enemigos.get(id, {})
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
	if not _soy_dueno:
		return
	for id in _enem_ocupados.keys():
		if _enem_ocupados[id] != quien:
			continue
		_enem_ocupados.erase(id)
		var e: Dictionary = _enemigos.get(id, {})
		var nodo = e.get("nodo") if not e.is_empty() else null
		if nodo != null and is_instance_valid(nodo) and not nodo.esta_muerto():
			nodo.reanudar_tras_combate(-1.0)   # vuelve a la vida normal, sin heridas nuevas


# --- EXTRAER UN CADAVER (hito 5.3) ------------------------------------------------------------
#
# Mismo candado que las vetas, pero por CUERPO: dos no pueden sacarle el cristal al mismo cadaver.
# Lo arbitra el dueño del piso, que es quien tiene el cuerpo de verdad. Devuelve true si puedo
# empezar YA (soy el dueño y esta libre); si no, la respuesta llega por _extraccion_concedida.
func solicitar_extraccion(id: int) -> bool:
	if not activo or multiplayer.multiplayer_peer == null:
		return true
	if _soy_dueno:
		if _enem_ocupados.has(id):
			_toast("Ese cuerpo lo está trabajando tu compañero.")
			return false
		_enem_ocupados[id] = multiplayer.get_unique_id()
		return true
	if es_host:
		_encaminar_extraccion(id, _mi_lugar, 1)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_extraccion.rpc_id(1, id, _mi_lugar)
	return false   # hay que esperar respuesta: la pantalla la abre _extraccion_concedida


@rpc("any_peer", "call_remote", "reliable")
func _pedir_extraccion(id: int, lugar: String) -> void:
	if not es_host:
		return
	_encaminar_extraccion(id, lugar, multiplayer.get_remote_sender_id())


func _encaminar_extraccion(id: int, lugar: String, quien: int) -> void:
	if _mi_lugar == lugar and _soy_dueno:
		_resolver_extraccion(id, quien)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_pedir_extraccion_dueno.rpc_id(dueno, id, lugar, quien)
	else:
		_responder_extraccion(quien, id, false)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_extraccion_dueno(id: int, lugar: String, para: int) -> void:
	if _mi_lugar != lugar or not _soy_dueno:
		return
	_resolver_extraccion(id, para)


# SOLO el dueño: concede el cuerpo al primero que lo pida.
func _resolver_extraccion(id: int, quien: int) -> void:
	var libre: bool = not _enem_ocupados.has(id) and _enemigos.has(id)
	if libre:
		_enem_ocupados[id] = quien
	_responder_extraccion(quien, id, libre)


# Misma regla que _responder_pelea: comparar con MI id, no con 1.
func _responder_extraccion(quien: int, id: int, ok: bool) -> void:
	if quien == multiplayer.get_unique_id():
		_extraccion_concedida(id, ok)
	elif es_host:
		_extraccion_concedida.rpc_id(quien, id, ok)
	else:
		_rel_resp_extraccion.rpc_id(1, quien, id, ok)


@rpc("any_peer", "call_remote", "reliable")
func _rel_resp_extraccion(para: int, id: int, ok: bool) -> void:
	if not es_host:
		return
	if para == 1:
		_extraccion_concedida(id, ok)
	else:
		_extraccion_concedida.rpc_id(para, id, ok)


# Corre en QUIEN PIDIO extraer: si se la han dado, se abre el minijuego sobre SU cuerpo espejado.
@rpc("any_peer", "call_remote", "reliable")
func _extraccion_concedida(id: int, ok: bool) -> void:
	if not ok:
		_toast("Ese cuerpo lo está trabajando tu compañero.")
		return
	var n = _enem_nodos.get(id)
	if n != null and is_instance_valid(n):
		# La marca ANTES de reentrar, o start_extraction volveria a pedir permiso en bucle.
		n.set_meta("permiso_extraccion", true)
		Game.start_extraction(n)


# La llama Game al TERMINAR de extraer: el cuerpo de verdad se desvanece en la maquina del dueño
# (y su _exit_tree despawnea los espejos de todos). Suelta tambien el candado.
func notificar_extraido(id: int) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if _soy_dueno:
		_consumir_cadaver(id)
	elif es_host:
		_encaminar_consumir(id, _mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_consumir.rpc_id(1, id, _mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_consumir(id: int, lugar: String) -> void:
	if not es_host:
		return
	_encaminar_consumir(id, lugar)


func _encaminar_consumir(id: int, lugar: String) -> void:
	if _mi_lugar == lugar and _soy_dueno:
		_consumir_cadaver(id)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_consumir.rpc_id(dueno, id, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_consumir(id: int, lugar: String) -> void:
	if _mi_lugar != lugar or not _soy_dueno:
		return
	_consumir_cadaver(id)


func _consumir_cadaver(id: int) -> void:
	_enem_ocupados.erase(id)
	var e: Dictionary = _enemigos.get(id, {})
	var nodo = e.get("nodo") if not e.is_empty() else null
	if nodo != null and is_instance_valid(nodo):
		nodo.extracted = true
		if nodo.has_method("desvanecer"):
			nodo.desvanecer()   # al liberarse, _exit_tree -> baja_enemigo quita los espejos


# Quien simula ese lugar (0 = nadie). Solo el host lo sabe.
func _dueno_de(lugar: String) -> int:
	if not lugar.begins_with("piso:"):
		return 0
	return _dueno_piso.get(int(lugar.substr(5)), 0)


# Aviso corto en MI pantalla (el HUD es local: los avisos no se replican).
func _toast(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast(texto)
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
	if not activo or multiplayer.multiplayer_peer == null:
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
	if not activo or not espejando() or _pelea_anfitrion == 0:
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
	if not activo or _pelea_id == 0 or nuevo == 0 or multiplayer.multiplayer_peer == null:
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
	print("[traspaso] me llega la pelea: %d aliados, %d enemigos (sigo=%d)" % [
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
	if not activo or multiplayer.multiplayer_peer == null:
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
	for id in _enem_nodos.keys():
		ids.append(id)
	if _soy_dueno:
		for id in _enemigos.keys():
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
	if not activo or _pelea_id == 0 or peer == 0:
		return
	if _dobles.has(peer):
		var lote: Array = []
		for doble in _dobles[peer]:
			# A mitad de pelea la vida y el mana viven en el COMBATIENTE: hay que bajarlos a la
			# ficha antes de mandarlos, o se iria con los que entro.
			Game.volcar_desgaste_en_ficha(doble)
			lote.append(desgaste_a_dict(doble))
		_devolver_desgaste.rpc_id(peer, lote)
		_dobles.erase(peer)
	_fin_espejo.rpc_id(peer)
	_pelea_participantes.erase(peer)


func cerrar_pelea() -> void:
	if _pelea_id != 0:
		for p in _pelea_participantes:
			# A cada uno lo SUYO: lo que sus dobles han vivido en mi pantalla (vida, mana y la
			# excelia ganada) vuelve a sus personajes de verdad. Va ANTES de cerrarle el espejo.
			if _dobles.has(p):
				var lote: Array = []
				for doble in _dobles[p]:
					lote.append(desgaste_a_dict(doble))
				_devolver_desgaste.rpc_id(p, lote)
			_fin_espejo.rpc_id(p)
		_pelea_participantes.clear()
		_dobles.clear()
		_pelea_id = 0
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()


# Corre en EL DUEÑO de los personajes: lo que vivio cada doble se aplica a su ficha de verdad. El
# lote viene en el MISMO orden en que mande las fichas al unirme (mi formacion), asi que se cruza
# por indice con _mis_en_pelea: si no, el acompañante se quedaria con la vida del lider.
@rpc("any_peer", "call_remote", "reliable")
func _devolver_desgaste(lote: Array) -> void:
	for i in mini(lote.size(), _mis_en_pelea.size()):
		var pj: PersonajeData = _mis_en_pelea[i]
		if pj != null:
			aplicar_desgaste(pj, lote[i])


# ¿Estoy espejando una pelea? (lo consulta el jugador para no dejarme accionar por mi cuenta)
func espejando() -> bool:
	return _pelea_sigo != 0


# Le he pegado a un bicho que YA esta en una pelea: quiero entrar a ayudar. Quien sabe de quien es
# esa pelea es el DUEÑO del piso (lleva las reservas), asi que si no lo soy, se lo pregunto por la
# via de siempre —solicitar_pelea ya devuelve el anfitrion al que unirse—.
func unirme_a_la_pelea_de(id: int) -> void:
	if not activo:
		return
	# Ya estoy en una pelea (la mia o espejando otra): una pantalla de combate por maquina.
	if Game.combate_activo() or espejando():
		return
	if not _soy_dueno:
		solicitar_pelea(id)   # el dueño del piso sabe de quien es esa pelea y me lo dira
		return
	var peer: int = int(_enem_ocupados.get(id, 0))
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
# Lo que se le devuelve al dueño cuando acaba la pelea: su desgaste y lo que ha aprendido.
const _VUELVE := ["current_hp", "current_mp", "stamina", "level",
	"ability_internal", "ability_consolidado", "ability_base_nivel",
	"fuerza", "resistencia", "destreza", "agilidad", "magia",
	"guardianes_vencidos", "esquivas_exp", "hechizos_exp", "recitado_exp",
	"dano_recibido_exp", "dano_infligido_exp"]


func ficha_a_dict(pj: PersonajeData) -> Dictionary:
	var d := {}
	for campo in ["nombre", "color", "metalico", "imagen", "color_alpha", "level",
			"ability_internal", "ability_consolidado", "ability_base_nivel",
			"fuerza", "resistencia", "destreza", "agilidad", "magia",
			"base_hp", "base_attack", "base_defense", "base_magic", "base_speed",
			"base_mp", "base_magia_factor", "base_crit",
			"current_hp", "current_mp", "stamina",
			"desarrollos_rango", "pasivas_rng", "guardianes_vencidos",
			"esquivas_exp", "hechizos_exp", "recitado_exp",
			"dano_recibido_exp", "dano_infligido_exp"]:
		d[campo] = pj.get(campo)
	var sin_viajar: Array = []
	for r in _RANURAS:
		var pieza: Resource = pj.get(r)
		d[r] = Game.serializar_equipo(pieza)
		# No basta con que el diccionario no este vacio: tiene que llevar una ruta USABLE. Una
		# version anterior mandaba la ruta del propio guardado ("user://saves/...::Resource_x"), que
		# al otro lado no carga — y como el dict no venia vacio, este aviso no saltaba.
		if pieza != null and not Game._ruta_plantilla_valida(str((d[r] as Dictionary).get("ruta", ""))):
			sin_viajar.append(str(pieza.get("nombre")))
	# Una pieza que no viaja NO es un detalle: el doble entra sin ella y pelea con los puños, que es
	# un bug de balance silencioso. Se dice UNA vez por ficha, con nombres, en vez de callarlo.
	if not sin_viajar.is_empty():
		push_warning("[multi] %s viaja SIN: %s (no se pudo identificar su plantilla)" % [
			pj.nombre, ", ".join(sin_viajar)])
	var hechizos: Array = []
	for s in pj.equipped_spells:
		if s != null and not String(s.resource_path).is_empty():
			hechizos.append(s.resource_path)
	d["spells"] = hechizos
	return d


func ficha_de_dict(d: Dictionary) -> PersonajeData:
	var pj := PersonajeData.new()
	for campo in d:
		if campo == "spells" or _RANURAS.has(campo):
			continue
		pj.set(campo, d[campo])
	for r in _RANURAS:
		var item: Resource = Game.deserializar_equipo(d.get(r, {}))
		if item != null:
			pj.set(r, item)
			# Y su meta EQUIPADA apuntando al MISMO dict que la del objeto. Sin esto el doble
			# llevaba el arma pero con tier 1 y rareza comun: la identidad la lee equip_meta[slot]
			# (ver Game._meta), no el objeto. Es la misma invariante que restaura
			# _realinear_equip_meta al cargar una partida.
			pj.equip_meta[r.replace("equipped_", "")] = Game.meta_de(item)
	var hechizos: Array = []
	for ruta in d.get("spells", []):
		var s = load(String(ruta))
		if s != null:
			hechizos.append(s)
	pj.equipped_spells = hechizos
	return pj


# Lo que el doble ha vivido en la pelea, para devolverselo a su dueño.
func desgaste_a_dict(pj: PersonajeData) -> Dictionary:
	var d := {}
	for campo in _VUELVE:
		d[campo] = pj.get(campo)
	return d


func aplicar_desgaste(pj: PersonajeData, d: Dictionary) -> void:
	for campo in _VUELVE:
		if d.has(campo):
			pj.set(campo, d[campo])


# --- UNIRSE ---------------------------------------------------------------------------------

# La llama el jugador al querer meterse en la pelea de un compañero que tiene al lado.
func solicitar_unirse(anfitrion: int) -> void:
	if not activo or anfitrion == 0 or Game.combate_activo() or espejando():
		return
	if anfitrion == multiplayer.get_unique_id():
		return
	# Va MI GRUPO ENTERO, en orden de formacion: sin sus fichas el anfitrion no puede tirar los
	# dados por ellos. Entra lo que quepa (el decide, ver _pedir_unirme); mi pos 1 siempre.
	_mis_en_pelea = _mi_formacion()
	var fichas: Array = []
	for pj in _mis_en_pelea:
		fichas.append(ficha_a_dict(pj))
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
		print("[unirse] DENIEGO a ", quien, ": pelea_id=", _pelea_id, " pantalla=", p != null)
		_union_denegada.rpc_id(quien)
		return
	print("[unirse] ", quien, " entra en mi pelea con ", fichas.size(), " personaje(s)")
	# Aguanta la pelea hasta que entre de verdad: si caen todos en ese hueco, no se cierra
	# dejando al que venia de rescate con una pelea muerta.
	if p.has_method("esperar_refuerzo"):
		p.esperar_refuerzo(true)
	# Un DOBLE por personaje suyo: pelean aqui con sus stats y su equipo. Se meten POR ORDEN DE
	# FORMACION y entra lo que quepa (MAX_ALIADOS): su pos 1 seguro, la pos 2 si queda hueco.
	var dobles: Array = []
	var idxs: Array = []
	for f in fichas:
		var doble: PersonajeData = ficha_de_dict(f)
		if not Game.unir_aliado_al_combate(doble):
			break   # la pelea esta llena: los que falten se quedan fuera
		dobles.append(doble)
		# Y que la pelea sepa que ese personaje lo mueve EL, no yo: cuando le toque el turno se le
		# pediran a el los botones (ver combat._begin_player_turn).
		var suyo: Combatant = Game.combatant_de_pj(doble)
		if suyo != null and p.has_method("marcar_dueno"):
			p.marcar_dueno(suyo, quien)
		idxs.append(p.indice_de_aliado(suyo))
	if p.has_method("esperar_refuerzo"):
		p.esperar_refuerzo(false)
	if dobles.is_empty():
		_union_denegada.rpc_id(quien)
		return
	_dobles[quien] = dobles       # de quien es cada doble, para devolverle lo suyo al acabar
	if not _pelea_participantes.has(quien):
		_pelea_participantes.append(quien)
	# Los INDICES le dicen cual de sus personajes es cada aliado de la pantalla: es lo unico que
	# significa lo mismo en las dos maquinas (y lo que necesita para saber a quien mover).
	_union_ok.rpc_id(quien, _pelea_id, p.roster_para_espejo(), idxs)


@rpc("any_peer", "call_remote", "reliable")
func _union_denegada() -> void:
	_toast("Esa pelea ya no está disponible.")


# Corre en EL QUE SE UNE: abre su pantalla en espejo.
# 'idxs' son los huecos de la fila de aliados que han tocado a MIS personajes, en el mismo orden en
# que mande las fichas. Con ellos se sabe a quien muevo yo cuando el anfitrion pide una accion.
@rpc("any_peer", "call_remote", "reliable")
func _union_ok(id: int, roster: Dictionary, idxs: Array) -> void:
	if Game.combate_activo() or espejando():
		return
	if Game.abrir_combate_espejo(roster) == null:
		return
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

# La llama el combate cada vez que cambia algo que se ve. Barata: solo numeros.
func difundir_instantanea(snap: Dictionary) -> void:
	if not activo or _pelea_id == 0 or _pelea_participantes.is_empty():
		return
	for p in _pelea_participantes:
		_instantanea.rpc_id(p, snap)


# LA BARRA DE ACCION. Va aparte de la instantanea y a ~20 Hz porque es lo unico que se mueve de
# forma CONTINUA: metida en la instantanea (que solo sale cuando cambia algo) la barra del espejo
# iria a saltos, y mandada como fiable seria trafico tonto. Mismo trato que las posiciones de los
# enemigos: unreliable_ordered y a correr.
func difundir_atb(ratios: PackedFloat32Array) -> void:
	if not activo or _pelea_id == 0 or _pelea_participantes.is_empty():
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


@rpc("any_peer", "call_remote", "unreliable_ordered")
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
	if not activo or _pelea_id == 0 or _pelea_participantes.is_empty():
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
	if not activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
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
func pedir_accion(peer: int, idx: int) -> void:
	if not activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_turno.rpc_id(peer, idx)


@rpc("any_peer", "call_remote", "reliable")
func _tu_turno(idx: int) -> void:
	if _pelea_sigo == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("turno_mio"):
		p.turno_mio(idx)


# MAGIA (hito 5.4-C): recitar son varios turnos con su examen de frases, asi que no basta con
# mandar una accion suelta como en las habilidades — hay que enrutar CADA frase. El anfitrion
# sortea las opciones (lleva la pelea) y el dueño responde con la que eligio.
func pedir_frase(peer: int, idx: int, opciones: Array, nombre: String, largo: int) -> void:
	if not activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_frase.rpc_id(peer, idx, opciones, nombre, largo)


@rpc("any_peer", "call_remote", "reliable")
func _tu_frase(idx: int, opciones: Array, nombre: String, largo: int) -> void:
	if _pelea_sigo == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("recitar_frase"):
		p.recitar_frase(idx, opciones, nombre, largo)


func pedir_disparo(peer: int, nombre: String) -> void:
	if not activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_disparo.rpc_id(peer, nombre)


@rpc("any_peer", "call_remote", "reliable")
func _tu_disparo(nombre: String) -> void:
	if _pelea_sigo == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("lanzar_conjuro"):
		p.lanzar_conjuro(nombre)


# El dueño manda lo que ha elegido.
func enviar_accion(accion: Dictionary) -> void:
	if not activo or _pelea_anfitrion == 0 or multiplayer.multiplayer_peer == null:
		return
	_accion_elegida.rpc_id(_pelea_anfitrion, accion)


@rpc("any_peer", "call_remote", "reliable")
func _accion_elegida(accion: Dictionary) -> void:
	if _pelea_id == 0:
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("aplicar_accion_remota"):
		p.aplicar_accion_remota(accion)


# El anfitrion cierra: los espejos se cierran con el.
@rpc("any_peer", "call_remote", "reliable")
func _fin_espejo() -> void:
	if _pelea_sigo == 0:
		return
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("cerrar_espejo"):
		p.cerrar_espejo()


# --- HANDSHAKE + CONTRASEÑA ------------------------------------------------------------------

# Cliente: nada mas conectar, se presenta al host (id 1) con el codigo, su aspecto y su lugar.
func _on_connected_to_server() -> void:
	estado_cambiado.emit("Conectado. Validando codigo...")
	# Guardo MI baul de materiales antes de que el host me mande el suyo (lo recupero al salir).
	_almacen_solo = Game.almacen_materiales.duplicate()
	_almacen_guardado = true
	_saludar.rpc_id(1, _codigo, Game.player_color, Game.player_metalico, Game.player_nombre,
		_mi_lugar, Game.player_imagen_png)


# Corre EN EL HOST, llamado por el cliente. Valida el codigo y, si vale, se registran
# mutuamente; si no, se echa al que intenta colarse.
@rpc("any_peer", "call_remote", "reliable")
func _saludar(codigo: String, color: Color, metal: float, nombre: String, lugar: String,
		imagen: PackedByteArray = PackedByteArray()) -> void:
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
	_registrar_peer(quien, color, metal, nombre, lugar, imagen)
	estado_cambiado.emit("%s se ha unido." % nombre)
	_presentarse.rpc_id(quien, Game.player_color, Game.player_metalico, Game.player_nombre,
		_mi_lugar, Game.semilla_mundo, Game.tienda_t2_abierta(), Game.player_imagen_png)
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
		t2: bool, imagen: PackedByteArray = PackedByteArray()) -> void:
	var quien := multiplayer.get_remote_sender_id()
	semilla_host = semilla
	tienda_t2_host = t2
	_registrar_peer(quien, color, metal, nombre, lugar, imagen)
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
func _registrar_peer(peer_id: int, color: Color, metal: float, nombre: String, lugar: String,
		imagen: PackedByteArray = PackedByteArray()) -> void:
	# La IMAGEN del cuerpo viaja UNA VEZ, en el handshake: es un PNG ya recortado a 128x128
	# (Game.IMAGEN_CUERPO_MAX), no la foto original. Se guarda por peer para poder repintar su
	# cuerpo cada vez que se recrea (al cambiar de piso, por ejemplo) sin volver a pedirla.
	_peers[peer_id] = {"color": color, "metal": metal, "nombre": nombre,
		"lugar": lugar, "pos": Vector2.INF, "peleando": false, "comps": [],
		"imagen": imagen}
	if lugar == _mi_lugar:
		_crear_avatar_nodo(peer_id)
	# Acabamos de conocernos: le digo como es MI sequito (el suyo me llegara igual). Sin esto, los
	# acompañantes del que ya estaba saldrian sin cara hasta que tocara su equipo.
	anunciar_grupo()
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
	# De quien es este cuerpo: al alcanzarlo un bicho hay que mandarle la pelea a SU dueño. Va como
	# meta, mismo patron que el net_id de bichos y drops.
	av.set_meta("peer_id", peer_id)
	av.aplicar_aspecto(p["color"], p["metal"], p["nombre"], p.get("imagen", PackedByteArray()))
	if p["pos"] != Vector2.INF:
		av.ir_a(p["pos"])   # aparece donde iba, no en el origen
	_avatares[peer_id] = av


func _on_peer_disconnected(id: int) -> void:
	var conocido := _peers.has(id)
	var a = _avatares.get(id)
	if a != null and is_instance_valid(a):
		a.queue_free()
	_avatares.erase(id)
	_quitar_companeros(id)
	_peers.erase(id)
	# Su marcha cuenta como salir de la mazmorra: libera sus vetas y, si era el ultimo
	# dentro, la expedicion se cierra (solo decide el host).
	if es_host:
		_liberar_vetas_de(id)
		if _taller_dueno == id:   # se fue con el taller cogido: se libera (su crafteo a medias se pierde)
			_taller_dueno = 0
		# Si simulaba un piso, lo suelta SIN foto (se fue de golpe, no dio tiempo a sacarla): quien
		# se quede lo hereda vacio y las paredes lo van repoblando. Es el precio de un corte brusco.
		_soltar_piso(id, {})
		# Y si se fue A MEDIA PELEA, los bichos que tenia reservados quedarian congelados para
		# siempre. Que cada dueño suelte los suyos.
		_soltar_reservas_de.rpc(id)
		_soltar_reservas_de(id)
		if _dentro.has(id):
			_dentro.erase(id)
			if _dentro.is_empty():
				_cerrar_expedicion()
	# ¿Se ha ido el que llevaba la pelea que yo estoy espejando? Mi pantalla se queda huerfana:
	# sin el no llegan ni instantaneas ni turnos, y se quedaria colgada para siempre.
	if id == _pelea_anfitrion:
		_anfitrion_perdido()
	# Si se ha ido alguien que estaba en MI pelea, sus personajes salen de ella (y sus reservas ya
	# las suelta el host mas arriba). Si no, la pelea esperaria un turno que no va a llegar nunca.
	if _pelea_id != 0 and _pelea_participantes.has(id):
		_pelea_participantes.erase(id)
		_dobles.erase(id)
		var mia: Node = _pantalla_combate()
		if mia != null and mia.has_method("sacar_a"):
			mia.sacar_a(id)
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
