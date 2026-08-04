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

# VERSION DEL PROTOCOLO. Sube cuando cambia lo que viaja en el saludo (o lo que significa).
#
# Hace falta porque un desajuste de version entre dos builds NO da error: si el cliente llama a
# _saludar con menos parametros de los que el host declara, Godot DESCARTA el paquete en silencio y
# el que entra se queda para siempre en "Validando codigo...". Con esto, el host puede decirle lo que
# pasa; y si el que esta viejo es el host (y por tanto no conoce este campo), lo tapa el plazo del
# cliente (ver _PLAZO_SALUDO).
const PROTOCOLO := 2

# Cuanto espera el cliente una respuesta al saludo antes de dar por hecho que no se entienden.
const _PLAZO_SALUDO := 5.0
const _REMOTE_PLAYER := preload("res://scripts/actors/player/remote_player.gd")
const _REMOTE_ENEMY := preload("res://scripts/actors/enemy/remote_enemy.gd")
const _DROP_PICKUP := preload("res://scripts/items/drop_pickup.gd")

# ¿Hay una sesion de red en marcha? El resto del juego (player.gd) lo consulta para decidir si
# emite su posicion. En un jugador es false y NADA cambia.
var activo := false
var es_host := false

# ¿Esta sesion es de un MUNDO COMPARTIDO (un solo save que lleva dentro a todos, ver mundos.gd) o del
# LAN de siempre (cada uno trae su propia ranura)? Es el interruptor de todo lo nuevo, y va aparte de
# `activo` a proposito: el camino viejo tiene que seguir funcionando exactamente igual.
var mundo_compartido := false

# Solo HOST: quien es cada peer de verdad (peer_id -> Identidad.id). El peer_id se reasigna en cada
# conexion, asi que no sirve para reconocer a nadie entre sesiones; esto si.
var _identidades: Dictionary = {}
# Solo HOST: los que han saludado pero AUN NO ESTAN DENTRO, porque les falta tener personaje. Se
# guarda su lugar para admitirles cuando avisen. Ver _saludar / _listo.
var _en_la_puerta: Dictionary = {}

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

# ATAJOS por piso del MUNDO DEL HOST (los jefes que el ha matado). Misma regla que la tienda T2:
# estas en SU mundo, asi que sus accesos abiertos existen para todos. Llega en el handshake y se
# UNE con los tuyos en Game.pisos_desbloqueados() -- lo que abras en sesion (ver _boss_caido) se
# apunta ya en el Game de cada uno, asi que no hace falta re-difundir esta lista.
var pisos_host: Array = []

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
# peer_id -> true: quienes han CAIDO y todavia no han vuelto a bajar (host). Es la cuenta de "¿habeis
# muerto todos?", que es lo unico que olvida la mazmorra compartida (ver _registrar_muerte). Se le
# borra la marca al que vuelve a entrar: ha vuelto a la pelea.
var _muertos: Dictionary = {}
# CLAVE de un sitio de recoleccion: Vector3i(piso, celda.x, celda.y). Va el PISO dentro a
# proposito: los pisos se generan con el mismo molde y repiten coordenadas, asi que con la celda
# pelada picar una veta en el piso 3 borraba la del mismo hueco en el 4.
var _vetas_ocupadas: Dictionary = {}  # sitio -> peer_id que la trabaja (host)
# sitio -> momento en que se pico. El VALOR es lo que permite el respawn: el host barre la tabla y
# suelta lo que ya ha cumplido su tiempo (ver _barrer_respawns).
#
# EL RELOJ ES Game.tiempo_mazmorra DEL HOST, y tiene que ser ese y no otro. Antes habia un
# `_reloj_expedicion` propio que nacia a cero con cada expedicion y moria con ella; el problema no
# era el reloj en si, sino lo que arrastraba: como los sellos se apuntaban contra el, no podian
# sobrevivir a que saliera el ultimo jugador, y al volver a bajar estaban TODAS las vetas otra vez.
# tiempo_mazmorra ya va al save y sigue corriendo en el pueblo (que es lo que se quiere: si subes a
# forjar, has esperado de verdad), asi que es el mismo criterio que en una partida de un jugador.
var _agotados_sesion: Dictionary = {}
# JEFES caidos de la sesion: piso -> momento (del reloj del host) en que cayo. Mismo mecanismo que
# _agotados_sesion y por la misma razon: el jefe reaparece por RELOJ (Game.BOSS_RESPAWN) y su cuenta
# atras tiene que sobrevivir a que os subais todos al pueblo.
#
# ESTAR EN LA TABLA = ESTA MUERTO. La resta contra el reloj la hace SOLO el host (_barrer_bosses), y
# cuando cumple borra la entrada y lo difunde. En los clientes el valor no significa nada —su
# tiempo_mazmorra es el de su mundo, no el del host— y solo se mira si la clave esta o no: asi el
# dueño de un piso (que puede ser un cliente) planta el jefe cuando lo dice el host y no cuando se lo
# diga su propio reloj.
var _bosses_sello: Dictionary = {}
var _t_barrido := 0.0
const BARRIDO_RESPAWN_CADA := 2.0   # cada cuanto repasa el host la tabla (igual que en solitario)

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
# Cuerpos que alguien esta EXTRAYENDO ahora mismo (net_id -> peer). El candado DURO sigue siendo
# _enem_ocupados (compartido con las peleas); esto es SOLO el subconjunto de extracciones, y existe
# para poder DIFUNDIRLO: sin el, con los dos jugadores juntos y dos cuerpos al lado los dos apuntaban
# al MISMO (el mas cercano de cada uno) y el segundo se comia un "esta ocupado" creyendo que iba al
# otro cuerpo. Ahora la F esquiva los cuerpos que trabaja otro (ver cuerpo_ocupado_por_otro).
# En el DUEÑO del piso es autoritativo; en los demas es el reflejo que llega por _set_extrayendo.
var _extrayendo: Dictionary = {}
# ¿Tengo una peticion de extraccion EN VUELO? Sin esto, entre la F y la respuesta del dueño no habia
# nada que lo marcara: una segunda F mandaba otra peticion y dejaba candados huerfanos por el camino.
var _extraccion_pidiendo: bool = false
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

# --- RESERVA de materiales EN VIVO (profesiones concurrentes) --------------------------------
# Los dos entran a la vez en el herrero/peletero/boticaria. Mientras uno tiene material SELECCIONADO
# en un crafteo (la forja), esas unidades se APARTAN del pool del otro: cada peer publica su
# seleccion en curso y el host la difunde. Todos pintan "disponible = baul - reservado_por_otros" y
# capan sus selecciones a eso, asi el consumo (que solo gasta lo seleccionado, y va serializado por
# el candado por-accion) respeta lo reservado sin tocar el codigo de crafteo. Es coordinacion VISUAL;
# la garantia DURA contra doble-gasto es el candado (como el "ocupado" de las vetas). El host valida
# cada reserva contra baul - reservas_de_otros, asi que suma(reservas) <= baul siempre.
var _reservas: Dictionary = {}   # peer_id -> {"mat_id|calidad": count}
# Lo ULTIMO que publiqué yo. Sirve para NO reenviar la misma reserva (los menus la re-publican en
# cada rebuild, y el rebuild lo dispara reservas_cambiadas: sin esto seria un bucle).
var _mi_reserva_local: Dictionary = {}

# Se emite cuando cambia CUALQUIER reserva: los menus de profesion abiertos se redibujan para que el
# "disponible" del otro baje/suba en vivo.
signal reservas_cambiadas()


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
# El HOST lleva el reloj de la expedicion y decide que vetas/plantas reviven. Ver _barrer_respawns.
func _process(delta: float) -> void:
	if not activo or not es_host or not expedicion_abierta:
		return
	# El reloj del respawn ya lo mueve Game (tiempo_mazmorra): aqui solo se marca cada cuanto tocar
	# la tabla.
	_t_barrido -= delta
	if _t_barrido <= 0.0:
		_t_barrido = BARRIDO_RESPAWN_CADA
		_barrer_respawns()


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


# Lo mismo, pero para que lo pregunte quien esta FUERA. Lo usa Mundos: al abrir un mundo
# compartido hay que hostear en cuanto se pise el pueblo (desde el menu no se puede), y el mundo
# tiene que quedar abierto desde el minuto uno para que los demas entren cuando quieran.
func puede_abrir_sala() -> bool:
	return _en_el_pueblo()


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
	# Si lo que tengo abierto es un mundo compartido, esta sesion lo es (lo consulta medio net.gd).
	mundo_compartido = Mundos.abierto != ""
	_sembrar_mapa_sesion()    # el mapa de la sesion arranca siendo el MIO: se juega en mi mundo
	Game._refrescar_pausa()   # regimen multi: los menus dejan de pausar el arbol
	estado_cambiado.emit("Servidor abierto. Esperando a que se unan...")
	return OK


# compartido = me uno a un MUNDO COMPARTIDO: mi personaje vive alli y me lo dara el host, asi que
# entro DESDE EL MENU y no desde un pueblo mio (no tengo partida cargada, ni tiene que haberla).
func unirse(ip: String, codigo: String, puerto: int = PUERTO, compartido := false) -> int:
	if not compartido and not _en_el_pueblo():
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
	# Antes de que llegue la conexion: _on_connected_to_server lo consulta para no congelar un mundo
	# propio que no existe ni presentarse con un personaje que todavia no tengo.
	mundo_compartido = compartido
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
	_extrayendo.clear()
	_extraccion_pidiendo = false
	_enem_next_id = 1
	_enem_acum = 0.0
	_peers.clear()
	_dentro.clear()
	_muertos.clear()
	_vetas_ocupadas.clear()
	_agotados_sesion.clear()
	_bosses_sello.clear()
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
	pisos_host.clear()
	# La libreta de la sesion era del mundo del HOST: se va con la sesion. Al invitado le vuelve la
	# suya intacta (nunca se toco Game.mapa_snapshot ni su mazmorra_persistente).
	_mapa_sesion.clear()
	_vistas_sesion.clear()
	# Restaurar MI baul de materiales si lo habia guardado al entrar de cliente (no perder nada).
	# En un MUNDO COMPARTIDO no hay nada que restaurar: el invitado no aparto ningun baul al entrar
	# porque no trae mundo propio (ver _on_connected_to_server). Volcarle aqui un `_almacen_solo`
	# vacio le borraria el baul del mundo en el que acaba de jugar.
	if _almacen_guardado and not mundo_compartido:
		var lista: Array[MaterialItem] = []
		for m in _almacen_solo:
			lista.append(m)
		Game.almacen_materiales = lista
	if _almacen_guardado:
		_almacen_guardado = false
		_almacen_solo = []
	# La foto de MI mundo al entrar de invitado (ver _congelar_mi_mundo) no sobrevive a la sesion:
	# fuera de ella no hay nada que revertir, y dejarla puesta significaria que un guardado de
	# invitado hecho por error volcaria el baul y el mapa de una sesion ya cerrada.
	_mundo_propio = {}
	_bote_mirror = 0
	_cofre_mirror = []
	_cofre_consum_mirror = {}
	_taller_dueno = 0
	_taller_resp = 0
	_reservas.clear()
	_mi_reserva_local.clear()
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
	# En un mundo compartido NO: los apartados salieron de un grupo que vive en el mundo, y el
	# invitado se va del mundo entero (no vuelve a "su" partida donde recuperarlos). Devolverlos aqui
	# seria rearmar un grupo que ya no es de nadie en esta maquina.
	if not mundo_compartido:
		_aplicar_cupo()
	_apartados.clear()
	_identidades.clear()
	_en_la_puerta.clear()
	# El interruptor, al final: todo lo de arriba lo consulta.
	mundo_compartido = false


# --- RETRANSMISION de los mensajes de JUGADOR (topologia estrella) ---------------------------
# Mismo problema y misma cura que los ENEMIGOS (ver "El canal de enemigos" mas abajo): en estrella
# un cliente no tiene socket con otro cliente, asi que un mensaje cliente->cliente se pierde SIN
# error. La solucion: el cliente se lo manda al HOST y el host lo REPARTE. Y como el host reenvia
# con rpc_id, el EMISOR original no se puede leer con get_remote_sender_id() (seria el host): viaja
# DENTRO del mensaje. El host se lo aplica tambien a si mismo si le toca, y salta al emisor.
#
# Los mensajes "a todos" (aspecto, grupo, lugar, combate) son fiables, baratos y raros -> van a
# TODOS los peers a proposito: si se filtraran por lugar, quien no comparte piso no actualizaria su
# _peers y al reencontrarse pintaria datos rancios (el cuadrado blanco que se arreglo en 19f0aaa).
# Solo la POSICION (60 Hz -> estrangulada a 20) se filtra por lugar.

# El id de este peer, para meterlo como "emisor" cuando difundo yo directamente (host).
func _mi_id() -> int:
	return multiplayer.get_unique_id()


# --- POSICION (lo que hace que os veais moveros) --------------------------------------------
# ESTRANGULADA a ~20 Hz: el player la llama cada tick de fisica (60 Hz), pero mas no hace falta
# —remote_player interpola con SUAVIZADO entre paquetes, igual que los bichos—, y al pasar por el
# host se multiplicaria por el numero de destinos. Baja el trafico tambien con 2 jugadores.
const _POS_TICK_MS := 50   # ~20 Hz, hermano de _ENEM_TICK (que va en segundos)
var _pos_last_ms := 0

# La llama el Player LOCAL cada tick de fisica si Net.activo. Difunde su posicion a los de MI lugar.
func enviar_estado(pos: Vector2, facing: Vector2, comps: Array = []) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _pos_last_ms < _POS_TICK_MS:
		return
	_pos_last_ms = ahora
	if es_host:
		for pid in _peers:
			if _peers[pid].get("lugar", "") == _mi_lugar:
				_recibir_estado.rpc_id(pid, _mi_id(), pos, facing, comps)
	else:
		_rel_estado.rpc_id(1, pos, facing, comps)


# Cliente -> host: reparte mi posicion a los de MI lugar (el host sabe donde esta cada cual).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rel_estado(pos: Vector2, facing: Vector2, comps: Array = []) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	var lugar: String = _peers.get(de, {}).get("lugar", "")
	if _mi_lugar == lugar:
		_recibir_estado(de, pos, facing, comps)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_recibir_estado.rpc_id(pid, de, pos, facing, comps)


# --- ¿QUIEN ESTA PELEANDO? (hito 5.3) --------------------------------------------------------
# Lo difunde Game al abrir/cerrar un combate. Sirve para que las paredes NO te paran bichos en las
# narices mientras estas en una pelea (no puedes ni verlo venir): ver spawn_zone._dist_min_de.
func avisar_combate(peleando: bool) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	_peleando = peleando
	if es_host:
		for pid in _peers:
			_set_peleando.rpc_id(pid, _mi_id(), peleando)
	else:
		_rel_peleando.rpc_id(1, peleando)


@rpc("any_peer", "call_remote", "reliable")
func _set_peleando(emisor: int, peleando: bool) -> void:
	if _peers.has(emisor):
		_peers[emisor]["peleando"] = peleando


@rpc("any_peer", "call_remote", "reliable")
func _rel_peleando(peleando: bool) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_peleando(de, peleando)
	for pid in _peers:
		if pid != de:
			_set_peleando.rpc_id(pid, de, peleando)


# --- PIEDRA DE RETORNO: el viaje es COMPARTIDO ----------------------------------------------
# El que la gasta se va al instante (Game.volver_al_pueblo_con_objeto) y a los demas se les OFRECE
# subirse, gratis. Aqui solo se reparte el aviso; lo de enseñarlo y esperar a que el jugador este
# libre es cosa de la UI (retorno_menu.gd).
#
# El reparto va FILTRADO POR PISO, y ese filtro es lo que mantiene el sentido del tier de la piedra
# (T1 hasta el 6, T2 hasta el 12): al que esta en el pueblo no le llega nada, y al que esta mas
# hondo de lo que alcanza, tampoco. Regalarle el viaje seria convertir una piedra T1 en una T2 para
# todo el que no la paga.
#
# Molde: avisar_combate (arriba). El emisor puede ser cualquiera, asi que el cliente pasa por el
# host y el host reparte -- en estrella los clientes no se ven entre si.
func anunciar_retorno(piso_max: int, quien: String) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		_repartir_retorno(piso_max, quien, _mi_id())
	else:
		_rel_retorno.rpc_id(1, piso_max, quien)


@rpc("any_peer", "call_remote", "reliable")
func _rel_retorno(piso_max: int, quien: String) -> void:
	if not es_host:
		return
	_repartir_retorno(piso_max, quien, multiplayer.get_remote_sender_id())


# Solo host: a cada peer que este DENTRO y a tiro de la piedra. El host se auto-sirve si le cuadra
# (no puede mandarse un rpc a si mismo), y al que la uso no se le ofrece: ya esta subiendo.
func _repartir_retorno(piso_max: int, quien: String, de: int) -> void:
	if not es_host:
		return
	if de != 1 and _alcanza_la_piedra(_mi_lugar, piso_max):
		Game.recibir_oferta_retorno(quien, piso_max)
	for pid in _peers:
		if pid == de:
			continue
		if _alcanza_la_piedra(str(_peers[pid].get("lugar", "")), piso_max):
			_ofrecer_retorno.rpc_id(pid, piso_max, quien)


# ¿A ese LUGAR llega una piedra de ese alcance? "pueblo" no (ya estas arriba) y un piso por debajo
# de su tope tampoco.
func _alcanza_la_piedra(lugar: String, piso_max: int) -> bool:
	if not lugar.begins_with("piso:"):
		return false
	return int(lugar.substr(5)) <= piso_max


@rpc("any_peer", "call_remote", "reliable")
func _ofrecer_retorno(piso_max: int, quien: String) -> void:
	Game.recibir_oferta_retorno(quien, piso_max)


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


# --- AVISO DE PARED replicado (los brotes) ----------------------------------------------------
#
# Los partos los simula UN dueño por piso, asi que el AVISO (la pared que late y tiembla) solo se
# montaba en su maquina: el compañero veia salir cuatro bichos de un muro liso, sin advertencia. El
# aviso ES la mecanica (decides si te quedas o te largas), asi que se replica a quien este en mi piso.
# Es puro FX: sin autoridad, sin estado y sin acuse. Si se pierde un paquete, se pierde un temblor.
func anunciar_brote(paredes_px: Array, dur: float, amp: float, col: Color) -> void:
	if not activo or multiplayer.multiplayer_peer == null or paredes_px.is_empty():
		return
	# Solo a los que estan EN MI PISO: el resto no tiene esa pared delante. El host hace de centralita
	# porque en ENet los clientes no se hablan entre ellos.
	if es_host:
		for pid in _peers:
			if (_peers[pid] as Dictionary).get("lugar", "") == _mi_lugar:
				_pintar_brote.rpc_id(pid, paredes_px, dur, amp, col)
		return
	_rel_brote.rpc_id(1, paredes_px, dur, amp, col, _mi_lugar)


# Solo host: reparte el aviso de un cliente entre los demas de ESE lugar (el emisor ya lo ve).
@rpc("any_peer", "call_remote", "unreliable")
func _rel_brote(paredes_px: Array, dur: float, amp: float, col: Color, lugar: String) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar:
		_pintar_brote(paredes_px, dur, amp, col)   # yo tambien estoy ahi
	for pid in _peers:
		if pid != de and (_peers[pid] as Dictionary).get("lugar", "") == lugar:
			_pintar_brote.rpc_id(pid, paredes_px, dur, amp, col)


@rpc("any_peer", "call_remote", "unreliable")
func _pintar_brote(paredes_px: Array, dur: float, amp: float, col: Color) -> void:
	var piso: Node = Game.get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("pintar_aviso_pared"):
		piso.pintar_aviso_pared(paredes_px, dur, amp, col)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recibir_estado(emisor: int, pos: Vector2, _facing: Vector2, comps: Array = []) -> void:
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
	# NO crear un cuerpo de acompañante hasta tener su ASPECTO. Las posiciones llegan a 60 Hz y el
	# aspecto aparte (por _set_grupo, casi inmediato tras el handshake): crear el cuerpo antes lo
	# hacia nacer como un CUADRADO BLANCO que no se arreglaba hasta cambiar de escena. Con esto el
	# cuerpo aparece ya con su cara en cuanto llega el grupo (unos ms despues).
	var con_aspecto: int = int(_peers[peer_id].get("comps", []).size())
	var objetivo: int = mini(posiciones.size(), con_aspecto)
	while lista.size() < objetivo:
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
			String(d.get("nombre", "")), d.get("imagen", PackedByteArray()),
			float(d.get("alpha", 1.0)))
	# Su imbuicion, de lo ultimo que anuncio. Sin esto un companero recreado (al viajar, o al
	# entrar tu a la partida) nace sin rastro aunque su dueño lleve el manto puesto.
	# +1 porque el hueco 0 del paquete es el LIDER (ver Net.anunciar_imbue).
	c.aplicar_imbue(_imbue_en(_peers[peer_id].get("imbue", PackedInt32Array()), idx + 1))
	return c


# Re-anuncia MI aspecto (el del LIDER) a todos. El del lider viaja en el handshake, pero si lo
# cambias en el hogar hay que re-difundirlo o el compañero no lo ve hasta que cambies de escena
# (que es cuando _reconstruir_vista recrea el avatar con los datos nuevos de _peers).
func anunciar_aspecto() -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	var c := Game.player_color
	var m := Game.player_metalico
	var n := Game.player_nombre
	var img := Game.player_imagen_png
	var al := Game.player_color_alpha
	if es_host:
		for pid in _peers:
			_set_aspecto.rpc_id(pid, _mi_id(), c, m, n, img, al)
	else:
		_rel_aspecto.rpc_id(1, c, m, n, img, al)


@rpc("any_peer", "call_remote", "reliable")
func _set_aspecto(emisor: int, color: Color, metal: float, nombre: String, imagen: PackedByteArray,
		alpha: float = 1.0) -> void:
	if not _peers.has(emisor):
		return
	_peers[emisor]["color"] = color
	_peers[emisor]["metal"] = metal
	_peers[emisor]["nombre"] = nombre
	_peers[emisor]["imagen"] = imagen
	_peers[emisor]["alpha"] = alpha
	# Repinta su avatar YA (si lo tengo delante): sin esto el cambio no se veria hasta reconstruir.
	var a = _avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a != null and is_instance_valid(a) and a.has_method("aplicar_aspecto"):
		a.aplicar_aspecto(color, metal, nombre, imagen, alpha)


@rpc("any_peer", "call_remote", "reliable")
func _rel_aspecto(color: Color, metal: float, nombre: String, imagen: PackedByteArray,
		alpha: float = 1.0) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_aspecto(de, color, metal, nombre, imagen, alpha)
	for pid in _peers:
		if pid != de:
			_set_aspecto.rpc_id(pid, de, color, metal, nombre, imagen, alpha)


# --- ASPECTO DE MI GRUPO (hito 5.4) ----------------------------------------------------------
# El color/brillo/nombre de MIS acompañantes. Va aparte de la posicion (que viaja 60 veces por
# segundo) porque solo cambia cuando cambia el equipo. Se difunde al conectar y al tocar el grupo.
func anunciar_grupo() -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	var datos: Array = []
	for pj in Game.companeros():
		datos.append({"color": pj.color, "metal": pj.metalico, "nombre": pj.nombre,
			"imagen": pj.imagen, "alpha": pj.color_alpha})
	if es_host:
		for pid in _peers:
			_set_grupo.rpc_id(pid, _mi_id(), datos)
	else:
		_rel_grupo.rpc_id(1, datos)


@rpc("any_peer", "call_remote", "reliable")
func _set_grupo(emisor: int, datos: Array) -> void:
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
				String(d.get("nombre", "")), d.get("imagen", PackedByteArray()),
				float(d.get("alpha", 1.0)))
	_avatares_comp[emisor] = lista


@rpc("any_peer", "call_remote", "reliable")
func _rel_grupo(datos: Array) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_grupo(de, datos)
	for pid in _peers:
		if pid != de:
			_set_grupo.rpc_id(pid, de, datos)


# --- IMBUICIONES DE MI GRUPO -----------------------------------------------------------------
# Canal PROPIO, y no un campo mas en anunciar_aspecto/anunciar_grupo, por una razon de peso: esos
# dos llevan el PNG del personaje (128x128) y solo cambian cuando te tocas la cara, mientras que la
# imbuicion se aplica y se gasta en CADA combate. Metida ahi, se habria reenviado la imagen entera
# de todo el grupo cada vez que a alguien se le acababan las cargas.
#
# El paquete es un int por persona, en el orden [lider] + companeros() -- el MISMO que usa
# anunciar_grupo, asi que el indice i+1 de aqui es el companero i de alli. Solo viaja el ID del
# elemento: el color lo saca cada maquina de Elementos.COLOR y no puede desincronizarse.
func anunciar_imbue() -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	var elems := _mis_imbues()
	if es_host:
		for pid in _peers:
			_set_imbue.rpc_id(pid, _mi_id(), elems)
	else:
		_rel_imbue.rpc_id(1, elems)


func _mis_imbues() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.append(Game.lider().imbue_elemento())
	for pj in Game.companeros():
		out.append(pj.imbue_elemento())
	return out


@rpc("any_peer", "call_remote", "reliable")
func _set_imbue(emisor: int, elems: PackedInt32Array) -> void:
	if not _peers.has(emisor):
		return
	# Se guarda en _peers ADEMAS de repintar: quien entre despues (o vuelva a montar la vista al
	# viajar) recrea los avatares desde aqui, y sin esto nacerian sin rastro.
	_peers[emisor]["imbue"] = elems
	_aplicar_imbue_a_avatares(emisor, elems)


# Reparte el paquete entre el avatar del lider y los de sus companeros. Lo llaman el RPC y las dos
# rutas de creacion de avatares (ver _crear_avatar_comp y _montar_avatar).
func _aplicar_imbue_a_avatares(emisor: int, elems: PackedInt32Array) -> void:
	var a = _avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a != null and is_instance_valid(a) and a.has_method("aplicar_imbue"):
		a.aplicar_imbue(_imbue_en(elems, 0))
	var lista: Array = _avatares_comp.get(emisor, [])
	for i in lista.size():
		if is_instance_valid(lista[i]) and lista[i].has_method("aplicar_imbue"):
			lista[i].aplicar_imbue(_imbue_en(elems, i + 1))


# Elemento en la posicion i, o NINGUNO si el paquete es mas corto (peer de una version anterior, o
# grupo que ha crecido entre dos anuncios).
func _imbue_en(elems: PackedInt32Array, i: int) -> int:
	return int(elems[i]) if i >= 0 and i < elems.size() else Elementos.Elemento.NINGUNO


@rpc("any_peer", "call_remote", "reliable")
func _rel_imbue(elems: PackedInt32Array) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_imbue(de, elems)
	for pid in _peers:
		if pid != de:
			_set_imbue.rpc_id(pid, de, elems)


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
		if es_host:
			for pid in _peers:
				_cambiar_lugar.rpc_id(pid, _mi_id(), lugar)
		else:
			_rel_lugar.rpc_id(1, lugar)
		_reconstruir_vista()


@rpc("any_peer", "call_remote", "reliable")
func _cambiar_lugar(emisor: int, lugar: String) -> void:
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


@rpc("any_peer", "call_remote", "reliable")
func _rel_lugar(lugar: String) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	# Aplicar en el host PRIMERO (actualiza _peers[de]["lugar"]) y luego repartir a los demas: asi
	# cualquier decision posterior por lugar ve ya el sitio nuevo.
	_cambiar_lugar(de, lugar)
	for pid in _peers:
		if pid != de:
			_cambiar_lugar.rpc_id(pid, de, lugar)


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

# La llama door.gd (rama multi) al interactuar con la puerta del pueblo, y el menu de atajos con
# el piso elegido. Los ATAJOS si valen en multi: entrar por el piso 6 es lo mismo que entrar por el
# 1, solo cambia por donde apareces. Lo unico que sigue siendo del host es CONCEDERLO (es quien
# reparte los dueños de piso y guarda las fotos).
func solicitar_entrar(piso: int = 1) -> void:
	if es_host:
		_conceder_entrada(1, piso)
	else:
		_pedir_entrar.rpc_id(1, piso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_entrar(piso: int = 1) -> void:
	if not es_host:
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
	if not expedicion_abierta:
		expedicion_abierta = true
		# Se abre la mazmorra: vuelven los sellos de lo que ya se pico en expediciones anteriores,
		# que estan en el save del host. Sin esto la tabla nacería vacia y todo estaria disponible.
		_sembrar_agotados_del_save()
		# Y se barren YA los que hayan cumplido su tiempo mientras no habia nadie. Va antes de
		# conceder la entrada a proposito: el que baja construye su piso con la lista de agotados que
		# le mandamos aqui abajo, asi que si esto se dejara al barrido periodico (cada 2 s) bajaria a
		# un piso sin la veta y se la veria brotar de la nada dos segundos despues.
		_barrer_respawns()
	_dentro[quien] = true
	_muertos.erase(quien)   # el que vuelve a bajar ya no cuenta como caido (ver _registrar_muerte)
	var dueno: bool = _asignar_dueno(piso, quien)
	var mem: Dictionary = {}
	if dueno:
		mem = _fotos_piso.get(piso, {})
		_fotos_piso.erase(piso)
	# Va el diccionario ENTERO, no solo las claves: el valor es el momento en que se pico, y sin el
	# quien entra no sabria cuanto le queda a cada sitio para revivir.
	if quien == 1:
		_entrar_ok(piso, _agotados_sesion, dueno, mem, _bosses_sello)
	else:
		_entrar_ok.rpc_id(quien, piso, _agotados_sesion, dueno, mem, _bosses_sello)


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
		sellos_boss: Dictionary = {}) -> void:
	_agotados_sesion = agotados.duplicate()
	# Que jefes de la sesion estan muertos ahora mismo. Sin esto, el que baja al piso 6 por el atajo
	# plantaria un rey slime que para los demas sigue muerto (y solo el lo veria).
	_bosses_sello = sellos_boss.duplicate()
	Game.current_floor = piso
	Game.olvidar_mazmorra()
	_olvidar_mis_enemigos()
	# ¿Simulo yo este piso? Si si, y venia congelado, se siembra la memoria LOCAL con su foto para
	# que _restaurar_estado lo levante igual que en solitario (va DESPUES de olvidar_mazmorra,
	# que la vacia entera).
	_soy_dueno = dueno
	if dueno and not mem.is_empty():
		Game.memoria_pisos[piso] = _mem_de_red(mem)
	# Por un ATAJO se aparece en la salida al pueblo de ESE piso (en el fondo), no en su boca:
	# mismo recado que pone floor_select_menu en solitario (lo consume DungeonFloor al construirse).
	Game.entrada_por_atajo = piso > 1
	Game.iniciar_expedicion_mapa()
	get_tree().change_scene_to_file("res://scenes/levels/main.tscn")
	anunciar_lugar("piso:%d" % piso)


# La llama la puerta de vuelta / la salida del boss (rama multi), DESPUES de consolidar el mapa.
func viajar_al_pueblo() -> void:
	# Me llevo la foto del piso que dejo (si lo simulaba yo) para que no se pierdan sus bichos:
	# se la queda el host, o pasa al que siga dentro. Hay que sacarla ANTES de cambiar de escena.
	var foto: Dictionary = _foto_de_mi_piso()
	# El jaleo es de la bajada y se queda aqui (en sesion la foto del piso ya la lleva _foto_de_mi_piso,
	# asi que de cerrar_bajada solo hace falta esa mitad; ver Game).
	Game.cerrar_bajada()
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
	_liberar_pesca_de(quien)   # sus corchos y el pez que tuviera enganchado
	_soltar_piso(quien, foto)
	_dentro.erase(quien)
	if _dentro.is_empty() and expedicion_abierta:
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
	if not activo or multiplayer.multiplayer_peer == null:
		return
	var foto: Dictionary = _foto_de_mi_piso()
	_soy_dueno = false
	_olvidar_mis_enemigos()
	if es_host:
		_registrar_muerte(1, foto)
	else:
		_pedir_muerte.rpc_id(1, foto)
	anunciar_lugar("pueblo")


@rpc("any_peer", "call_remote", "reliable")
func _pedir_muerte(foto: Dictionary) -> void:
	if not es_host:
		return
	_registrar_muerte(multiplayer.get_remote_sender_id(), foto)


# Solo host: 'quien' ha caido. Sale del piso igual que si volviera andando (el relevo de la
# simulacion pasa al que siga dentro, con la foto fiel), y se le apunta como MUERTO.
#
# La mazmorra compartida solo se OLVIDA cuando habeis caido todos: mientras quede un humano en pie,
# los pisos siguen como estaban. Que muera uno no puede castigar al otro —era justo el bug que se
# arreglaba aqui—, y tampoco puede borrarle la mazmorra al que esta arriba vendiendo.
func _registrar_muerte(quien: int, foto: Dictionary = {}) -> void:
	_muertos[quien] = true
	_registrar_salida(quien, foto)   # suelta vetas, piso y cargos (y cierra si era el ultimo dentro)
	if _dentro.is_empty() and _muertos.size() >= maxi(1, _num_humanos):
		_olvidar_expedicion()
	else:
		print("[multi] ha caido el peer %d (%d de %d): la mazmorra sigue en pie" % [
			quien, _muertos.size(), maxi(1, _num_humanos)])


# Solo host: habeis caido TODOS. ESTO es cerrar la mazmorra de verdad (lo otro, _cerrar_expedicion,
# solo suelta los cargos): se olvidan los pisos congelados, el botin que quedo tirado por ellos y los
# jefes se levantan. Es el equivalente en sesion de Game.olvidar_mazmorra.
#
# Lo picado (_agotados_sesion) NO entra: en solitario tampoco se pierde al morir, los sellos viven en
# mazmorra_persistente. Su CD es su CD.
func _olvidar_expedicion() -> void:
	_fotos_piso.clear()
	_muertos.clear()
	for id in _suelo.keys():
		if str(_suelo[id]["lugar"]).begins_with("piso:"):
			_suelo.erase(id)
			_despawn_drop.rpc(id)
			_despawn_drop(id)
	for piso in _bosses_sello.keys():
		_marcar_boss(piso, false)
		_marcar_boss.rpc(piso, false)
	print("[multi] habeis caido todos: la mazmorra se olvida")
	estado_cambiado.emit("Habéis caído todos: la mazmorra se olvida.")


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
	expedicion_abierta = false
	_dueno_piso.clear()
	_vetas_ocupadas.clear()
	_t_barrido = 0.0
	estado_cambiado.emit("Expedicion terminada: la mazmorra queda como la habeis dejado.")


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


# CUANTOS personajes hay en MI piso, contando los grupos de los otros humanos que esten aqui.
# Lo usa el tamaño del brote: contar solo Game.party hacia que el brote saliera pequeño cuando
# estabais dos en el mismo piso, justo cuando la regla de diseño ("siempre te superan por uno")
# tenia que dar mas. En solitario devuelve tu grupo, igual que antes.
func personajes_en_mi_piso() -> int:
	var n: int = Game.party.size()
	if not activo:
		return n
	for pid in _peers:
		var p: Dictionary = _peers[pid]
		if p.get("lugar", "") == _mi_lugar:
			# El humano + su sequito ("comps" son sus acompañantes, los que ves andando con el).
			n += 1 + (p.get("comps", []) as Array).size()
	return n


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
	# CAIDA BRUSCA: al que se le corto la conexion no le dio tiempo a mandar la foto de su piso, y
	# antes se heredaba PELADO (las paredes lo repoblaban de cero, delante de tus narices). Pero yo
	# estaba alli VIENDO sus bichos: mis propios espejos son una foto casi fiel —tipo, posicion,
	# tirada y heridas—. Se toma ANTES de tirarlos, que es justo lo siguiente que pasa.
	if (mem.get("enemigos", []) as Array).is_empty():
		mem = _foto_de_mis_espejos()
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


# La foto del piso reconstruida a partir de MIS ESPEJOS. Solo se usa al heredar un piso cuyo dueño
# se cayo de golpe (ver _asumir_piso). No sale la ZONA (un espejo no la sabe: la ocupacion de cada
# sala la llevaba el dueño), asi que se deja en -1 y la resuelve por posicion el que restaura.
func _foto_de_mis_espejos() -> Dictionary:
	var out: Array = []
	for id in _enem_nodos.keys():
		var n = _enem_nodos[id]   # SIN tipar: puede estar liberado (ver cabecera)
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
	_enemigos.clear()
	_enem_ocupados.clear()   # las reservas eran de esos bichos: se van con ellos
	if not _extrayendo.is_empty():
		_extrayendo.clear()
		_difundir_extrayendo()   # y nadie debe seguir viendo esos cuerpos como ocupados


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
			"hp": d.get("hp", -1.0),
		})
	return {"enemigos": out, "suelo": []}


# --- VETAS: una a la vez, con "esta ocupado" --------------------------------------------------

# La clave de un sitio: el piso va DENTRO (ver _agotados_sesion).
func _sitio(piso: int, celda: Vector2i) -> Vector3i:
	return Vector3i(piso, celda.x, celda.y)


# La llama resource_node.interactuar() (rama multi): pedir la veta antes de abrir el minijuego.
func solicitar_veta(celda: Vector2i, piso: int) -> void:
	if es_host:
		_resolver_veta(celda, piso, 1)
	else:
		_pedir_veta.rpc_id(1, celda, piso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_veta(celda: Vector2i, piso: int) -> void:
	if not es_host:
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
	if es_host:
		_registrar_agotado(celda, piso, retraso)
	else:
		_pedir_agotar.rpc_id(1, celda, piso, retraso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_agotar(celda: Vector2i, piso: int, retraso: float = 0.0) -> void:
	if not es_host:
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
	var sello: float = Game.tiempo_mazmorra + retraso
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
	_agotados_sesion[_sitio(piso, celda)] = Game.tiempo_mazmorra + retraso
	if not _mi_lugar.begins_with("piso:") or Game.current_floor != piso:
		return
	var suelo: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if suelo != null and suelo.has_method("marcar_agotado"):
		suelo.marcar_agotado(celda, retraso)
	for n in get_tree().get_nodes_in_group("recolectable"):
		if is_instance_valid(n) and n.celda == celda:
			n.agotar()
			return


# SOLO HOST: repasa los sitios picados y suelta los que ya han cumplido su tiempo. Es el equivalente
# por red de dungeon_floor._repoblar_agotados, con la diferencia que importa: aqui manda UN reloj (el
# tiempo_mazmorra DEL HOST) en vez del de cada maquina, que es local y diverge, asi que la veta
# revive en todas a la vez. Antes esto no existia y lo picado en sesion no volvia NUNCA.
func _barrer_respawns() -> void:
	# Los JEFES van en el mismo barrido (mismo reloj, misma cadencia, y misma puesta al dia cuando
	# alguien vuelve a bajar). Va ANTES del early-return de abajo: un piso sin vetas picadas puede
	# perfectamente tener un jefe esperando su hora.
	_barrer_bosses()
	if _agotados_sesion.is_empty():
		return
	for s in _agotados_sesion.keys():
		if Game.tiempo_mazmorra - float(_agotados_sesion[s]) < Game.RESPAWN_SEGUNDOS:
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
	if not es_host:
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
	# Y FUERA DEL SAVE DEL HOST, o el sello volveria a sembrarse en la proxima expedicion y la veta
	# que acaba de revivir nacería agotada otra vez. Es lo mismo que hace _olvidar_agotado en
	# solitario. Solo el host: en el invitado ese diccionario es de SU mundo, no de este.
	if es_host:
		(Game.persistente_piso(piso)["agotados"] as Dictionary).erase(celda)
	if not _mi_lugar.begins_with("piso:") or Game.current_floor != piso:
		return
	var suelo: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if suelo != null and suelo.has_method("revivir_celda"):
		suelo.revivir_celda(celda, nonce)


# ¿Este sitio ya se agoto en ESTA expedicion? Lo consulta dungeon_floor al construir el piso.
func celda_agotada_sesion(celda: Vector2i, piso: int) -> bool:
	return _agotados_sesion.has(_sitio(piso, celda))


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
	# Y que el HOST arranque su cuenta atras, que es el unico que la lleva. Va aparte de _boss_caido
	# porque ese es "call_remote" (quien mata ya hizo su parte en local) y porque el sello no es un
	# hito de mundo: es un cronometro.
	if es_host:
		_sellar_boss_host(piso)
	else:
		_pedir_sellar_boss.rpc_id(1, piso)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_sellar_boss(piso: int) -> void:
	if es_host:
		_sellar_boss_host(piso)


# Solo host: el jefe de ese piso queda MUERTO en la tabla de sesion, y se difunde para que todos
# sepan que no toca plantarlo (el dueño del piso puede ser cualquiera).
func _sellar_boss_host(piso: int) -> void:
	if not Game.BOSSES.has(piso):
		return
	_bosses_sello[piso] = Game.tiempo_mazmorra
	_marcar_boss(piso, true)
	_marcar_boss.rpc(piso, true)
	print("[multi] jefe del piso %d abatido: vuelve en %d s" % [
		piso, roundi(float(Game.BOSS_RESPAWN.get(piso, 0.0)))])


@rpc("any_peer", "call_remote", "reliable")
func _marcar_boss(piso: int, muerto: bool) -> void:
	if muerto:
		# En el cliente el valor da igual (no compara relojes, ver _bosses_sello): lo que cuenta es
		# que la clave este.
		if not _bosses_sello.has(piso):
			_bosses_sello[piso] = Game.tiempo_mazmorra
	else:
		_bosses_sello.erase(piso)


# SOLO HOST: repasa los jefes muertos y levanta a los que han cumplido su tiempo. Va colgado del
# mismo barrido que las vetas (_barrer_respawns), asi que hereda sus dos propiedades: corre cada
# BARRIDO_RESPAWN_CADA con la expedicion abierta, y se pone al dia de golpe cuando alguien vuelve a
# entrar despues de un rato en el pueblo.
#
# Aqui NO se planta el bicho: solo se suelta el sello. Plantarlo es cosa del dueño del piso, que es
# quien simula alli (dungeon_floor._repoblar_boss), o del propio piso al construirse.
func _barrer_bosses() -> void:
	if not es_host:
		return
	for piso in _bosses_sello.keys():
		var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
		if Game.tiempo_mazmorra - float(_bosses_sello[piso]) < espera:
			continue
		_bosses_sello.erase(piso)
		_marcar_boss(piso, false)
		_marcar_boss.rpc(piso, false)
		print("[multi] el jefe del piso %d vuelve a estar de pie" % piso)


# ¿Toca que el jefe de ese piso este de pie? Lo pregunta Game.boss_disponible cuando hay sesion.
# Es una consulta de TABLA, sin relojes: la resta la hace el host en _barrer_bosses.
func boss_disponible(piso: int) -> bool:
	return not _bosses_sello.has(piso)


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
	# Marco que el candado es MIO: _taller_dueno hace de "¿lo tengo yo?" local (lo lee tengo_taller,
	# que gatea depositar/vender/craftear del baul compartido) Y de escudo contra que un _set_almacen
	# me pise el baul a media edicion. Sin esto, en el cliente se quedaba en 0 y tengo_taller devolvia
	# false aunque tuviera el baul prestado: guardar materiales decia "0" y no depositaba nada.
	_taller_dueno = multiplayer.get_unique_id()
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
		_taller_dueno = 0   # ya lo solte: dejo de "tenerlo" y el _set_almacen del host vuelve a valer


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


# --- RESERVA de materiales EN VIVO (profesiones concurrentes) --------------------------------

# Cuantas unidades de (mat_id, calidad) tiene reservadas OTRA gente ahora mismo (no cuento las mias:
# las mias ya estan reflejadas en mi propia seleccion). Lo consulta la UI: disponible = baul - esto.
func reservado_por_otros(mat_id: String, calidad: int) -> int:
	if not activo:
		return 0
	var yo := multiplayer.get_unique_id()
	var clave := "%s|%d" % [mat_id, calidad]
	var total := 0
	for peer in _reservas:
		if peer != yo:
			total += int((_reservas[peer] as Dictionary).get(clave, 0))
	return total


# Publica MI seleccion en curso como reserva. 'claim' = {"mat_id|calidad": count}. En el host se
# aplica en local; en el cliente se le pide al host. En solitario no hace nada. Si no ha CAMBIADO
# respecto a lo ultimo que publiqué, no reenvia nada (los menus llaman esto en cada rebuild, y el
# rebuild lo dispara reservas_cambiadas: sin la deduplicacion seria un bucle).
func reservar(claim: Dictionary) -> void:
	if not activo:
		return
	if _misma_reserva(claim, _mi_reserva_local):
		return
	_mi_reserva_local = claim.duplicate()
	if es_host:
		_aplicar_reserva(multiplayer.get_unique_id(), claim)
	else:
		pedir_reserva.rpc_id(1, claim)


func _misma_reserva(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for k in a:
		if int(b.get(k, -1)) != int(a[k]):
			return false
	return true


# Suelto todo lo que tenia reservado (al cerrar el menu o tras craftear).
func liberar_mis_reservas() -> void:
	reservar({})


@rpc("any_peer", "call_remote", "reliable")
func pedir_reserva(claim: Dictionary) -> void:
	if not es_host:
		return
	_aplicar_reserva(multiplayer.get_remote_sender_id(), claim)


# Solo host: guarda la reserva de 'quien' CAPADA a lo que de verdad queda libre (baul menos lo que
# reservan los demas), y difunde el mapa entero. El capado mantiene la invariante suma(reservas)<=baul.
func _aplicar_reserva(quien: int, claim: Dictionary) -> void:
	var limpio: Dictionary = {}
	for clave in claim:
		var pide := int(claim[clave])
		if pide <= 0:
			continue
		var libre := _en_baul(String(clave)) - _reservado_por_otros_host(quien, String(clave))
		var dado := clampi(pide, 0, maxi(0, libre))
		if dado > 0:
			limpio[clave] = dado
	if limpio.is_empty():
		_reservas.erase(quien)
	else:
		_reservas[quien] = limpio
	_set_reservas.rpc(_reservas)
	reservas_cambiadas.emit()


# Solo host: cuantas de 'clave' hay en el baul autoritativo (Game.almacen_materiales).
func _en_baul(clave: String) -> int:
	var partes := clave.split("|")
	if partes.size() != 2:
		return 0
	var mat_id := partes[0]
	var cal := int(partes[1])
	var n := 0
	for m in Game.almacen_materiales:
		if m != null and m.data != null and String(m.data.id) == mat_id and int(m.calidad) == cal:
			n += 1
	return n


# Solo host: lo reservado por todos MENOS 'salvo', para 'clave' (usado al capar).
func _reservado_por_otros_host(salvo: int, clave: String) -> int:
	var total := 0
	for peer in _reservas:
		if peer != salvo:
			total += int((_reservas[peer] as Dictionary).get(clave, 0))
	return total


@rpc("authority", "call_remote", "reliable")
func _set_reservas(todas: Dictionary) -> void:
	# El ECO de mi propia reserva vuelve por aqui: yo la pido, el host la aplica y me difunde el mapa
	# entero, que ya incluye lo que acabo de mandar. Si NADA ha cambiado respecto a lo que ya tenia,
	# emitir despertaria un rebuild en cada menu abierto por nada — y ese rebuild puede volver a
	# publicar. Es un cortafuegos: el bucle de verdad se corta en quien publica (ver forge_menu
	# _claim_reserva), pero esto lo hace imposible desde el otro lado.
	if _mismas_reservas(todas, _reservas):
		return
	_reservas = todas.duplicate(true)
	reservas_cambiadas.emit()


# ¿Los dos mapas de reservas dicen lo MISMO? peer a peer, reusando la comparacion de una sola
# reserva. Las claves son ids de peer, asi que basta con que coincidan los peers y sus dicts.
func _mismas_reservas(a: Dictionary, b: Dictionary) -> bool:
	if a.size() != b.size():
		return false
	for peer in a:
		if not b.has(peer):
			return false
		if not _misma_reserva(a[peer] as Dictionary, b[peer] as Dictionary):
			return false
	return true


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
	_hacer_hueco_en(lugar)
	var id := _next_id
	_next_id += 1
	_suelo[id] = {"d": d, "pos": pos, "lugar": lugar}
	_spawn_drop.rpc(id, d, pos, lugar)
	_spawn_drop(id, d, pos, lugar)


# TOPE de cosas tiradas por LUGAR. Desde que la mazmorra no se cierra al volver al pueblo (ver
# _cerrar_expedicion), el suelo de un piso no lo vacia nadie: en una sesion larga se acumulan cientos
# de pickups que el host difunde a todo el que entra. El tope es generoso a proposito —cabe de sobra
# lo que se te caiga por sobrepeso en una bajada— y al llegar tira el MAS VIEJO, que es el que menos
# posibilidades tiene de que alguien vuelva a por el (los ids son crecientes, asi que la clave mas
# baja de ese lugar es la mas antigua).
const SUELO_TOPE_POR_LUGAR := 60

func _hacer_hueco_en(lugar: String) -> void:
	var ids: Array = []
	for id in _suelo:
		if _suelo[id]["lugar"] == lugar:
			ids.append(id)
	if ids.size() < SUELO_TOPE_POR_LUGAR:
		return
	ids.sort()
	var sobran: int = ids.size() - SUELO_TOPE_POR_LUGAR + 1
	for i in range(sobran):
		var viejo: int = ids[i]
		_suelo.erase(viejo)
		_despawn_drop.rpc(viejo)
		_despawn_drop(viejo)
	print("[suelo] %s estaba lleno (%d): se van los %d mas viejos" % [lugar, ids.size(), sobran])


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
	cuerpo.configurar(d.get("color", Color.WHITE), float(d.get("lado", 32.0)),
		int(d.get("elem", Elementos.Elemento.NINGUNO)), float(d.get("einten", 1.0)))
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
	if not activo or not _soy_dueno or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		for peer_id in _peers:
			if _peers[peer_id].get("lugar", "") == _mi_lugar:
				_tick_charco.rpc_id(peer_id, snap)
	else:
		_rel_charco.rpc_id(1, _mi_lugar, snap)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _tick_charco(snap: Dictionary) -> void:
	if _charco != null and is_instance_valid(_charco):
		_charco.aplicar_red(snap)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rel_charco(lugar: String, snap: Dictionary) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar and not _soy_dueno:
		_tick_charco(snap)
	for peer_id in _peers:
		if peer_id != de and _peers[peer_id].get("lugar", "") == lugar:
			_tick_charco.rpc_id(peer_id, snap)


# --- 2) EL CORCHO: de cada pescador al dueño ---
# 'activo' false = he recogido el sedal (o he salido de la pesca): el dueño se olvida de mi corcho.
func publicar_corcho(pos: Vector2, esta_activo: bool) -> void:
	if not activo or _soy_dueno or multiplayer.multiplayer_peer == null:
		return
	_corcho_pesca.rpc_id(1, _mi_lugar, pos, esta_activo)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _corcho_pesca(lugar: String, pos: Vector2, esta_activo: bool) -> void:
	var de := multiplayer.get_remote_sender_id()
	# Yo soy el dueño de ese piso: el corcho es para mi charco.
	if _mi_lugar == lugar and _soy_dueno and _charco != null and is_instance_valid(_charco):
		_charco.corcho_remoto(de, pos, esta_activo)
		return
	# No lo soy: si soy el host, se lo encamino a quien si.
	if not es_host:
		return
	var piso: int = int(lugar.substr(5)) if lugar.begins_with("piso:") else -1
	var dueno: int = _dueno_piso.get(piso, 0)
	if dueno != 0 and dueno != de:
		_corcho_pesca_a.rpc_id(dueno, de, lugar, pos, esta_activo)


@rpc("authority", "call_remote", "unreliable_ordered")
func _corcho_pesca_a(de: int, lugar: String, pos: Vector2, esta_activo: bool) -> void:
	if _mi_lugar == lugar and _soy_dueno and _charco != null and is_instance_valid(_charco):
		_charco.corcho_remoto(de, pos, esta_activo)


# --- 3) LA MORDIDA: el dueño le dice a un pescador que ha picado, y cual ---
# 'idx' es el indice del pez en el banco, que es la misma lista en las dos maquinas (va en el snap).
func avisar_mordida(a_quien: int, idx: int) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		_pez_pica.rpc_id(a_quien, idx)
	else:
		_rel_mordida.rpc_id(1, a_quien, idx)


@rpc("any_peer", "call_remote", "reliable")
func _rel_mordida(a_quien: int, idx: int) -> void:
	if not es_host:
		return
	if a_quien == 1:
		_pez_pica(idx)
	else:
		_pez_pica.rpc_id(a_quien, idx)


@rpc("any_peer", "call_remote", "reliable")
func _pez_pica(idx: int) -> void:
	if _charco != null and is_instance_valid(_charco):
		_charco.me_ha_picado(idx)


# --- 4) EL RESULTADO: el pescador le dice al dueño como acabo ---
# 'cobrado' true = me lo llevo (sale del banco y arranca su gate de 10 min); false = se escapo o
# recogi el sedal (el pez vuelve a nadar y el banco no se toca).
func resolver_pesca(idx: int, cobrado: bool) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if _soy_dueno:
		return   # el dueño lo resuelve en local, no se manda una carta a si mismo
	_fin_pesca.rpc_id(1, _mi_lugar, idx, cobrado)


@rpc("any_peer", "call_remote", "reliable")
func _fin_pesca(lugar: String, idx: int, cobrado: bool) -> void:
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar and _soy_dueno and _charco != null and is_instance_valid(_charco):
		_charco.resolver_pez_remoto(de, idx, cobrado)
		return
	if not es_host:
		return
	var piso: int = int(lugar.substr(5)) if lugar.begins_with("piso:") else -1
	var dueno: int = _dueno_piso.get(piso, 0)
	if dueno != 0 and dueno != de:
		_fin_pesca_a.rpc_id(dueno, de, lugar, idx, cobrado)


@rpc("authority", "call_remote", "reliable")
func _fin_pesca_a(de: int, lugar: String, idx: int, cobrado: bool) -> void:
	if _mi_lugar == lugar and _soy_dueno and _charco != null and is_instance_valid(_charco):
		_charco.resolver_pez_remoto(de, idx, cobrado)


# Al desconectarse alguien, sus corchos y sus peces enganchados se sueltan: un pez reservado por un
# fantasma se quedaria bloqueado para siempre (mismo motivo que _liberar_vetas_de).
func _liberar_pesca_de(quien: int) -> void:
	if _charco != null and is_instance_valid(_charco):
		_charco.soltar_todo_de(quien)


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
		# Ya no tengo espejos de esos ids (culling, cambio de piso...), pero SIGUEN reservados y
		# congelados en casa del dueño. Hay que soltarlos o se quedan de estatua.
		_devolver_bichos(ids)
		return
	# Ya estoy peleando: estos se UNEN a mi pelea en vez de abrir otra (una por maquina). El que no
	# quepa se DEVUELVE al dueño: si no, se quedaria reservado y congelado para siempre.
	if Game.combate_activo():
		for n in nodos:
			if not Game.unir_enemigo_al_combate(n):
				n.salir_de_pelea()
		return
	# Emboscada solo si me han saltado encima; si ataque yo, la iniciativa es mia.
	# HAY QUE MIRAR EL RESULTADO: si estoy TRABAJANDO (mineria/tala/herboristeria/extraccion) hay un
	# _active_layer delante y start_combat rechaza la pelea. En multi el mundo no se pausa, asi que
	# esto pasa a menudo. Antes se ignoraba el rechazo y los bichos se quedaban reservados y
	# congelados para siempre, "peleando" con nadie: el bug de las estatuas del playtest.
	if not Game.start_combat(nodos, emboscada):
		_devolver_bichos(ids)


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


# Puerta publica: la usa Game.retomar_combate, que tambien puede quedarse con bichos congelados si
# el traspaso no cuaja. Aguanta que no haya sesion (en solitario no hay nada que devolver).
func devolver_bichos(ids: Array) -> void:
	if not activo or ids.is_empty():
		return
	_devolver_bichos(ids)


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
		_borrar_extrayendo(id)   # si era un cuerpo a medio extraer, vuelve a estar libre
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
	var yo: int = multiplayer.get_unique_id()
	if _soy_dueno:
		# Idempotente: si el candado ya es MIO, se me vuelve a conceder. Antes cualquier re-peticion
		# propia (una segunda F antes de que abriera la pantalla) se contestaba "lo trabaja tu
		# compañero" siendo yo mismo.
		if _enem_ocupados.has(id) and int(_enem_ocupados[id]) != yo:
			_toast("Ese cuerpo lo está trabajando tu compañero.")
			return false
		_enem_ocupados[id] = yo
		_apuntar_extrayendo(id, yo)
		return true
	# Una peticion a la vez: la respuesta tarda un viaje de ida y vuelta y en ese hueco una segunda F
	# (o un paso que cambia cual es el cuerpo mas cercano) mandaba otra peticion y dejaba el candado
	# del primer cuerpo puesto para siempre.
	if _extraccion_pidiendo:
		return false
	_extraccion_pidiendo = true
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


# SOLO el dueño: concede el cuerpo al primero que lo pida. Idempotente: si el candado YA es de quien
# pregunta, se le vuelve a conceder (una re-peticion suya no es una colision).
func _resolver_extraccion(id: int, quien: int) -> void:
	var mio_ya: bool = _enem_ocupados.has(id) and int(_enem_ocupados[id]) == quien
	var libre: bool = _enemigos.has(id) and (mio_ya or not _enem_ocupados.has(id))
	if libre:
		_enem_ocupados[id] = quien
		_apuntar_extrayendo(id, quien)
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
	_extraccion_pidiendo = false   # la peticion ya no esta en vuelo, salga bien o mal
	if not ok:
		_toast("Ese cuerpo lo está trabajando tu compañero.")
		return
	var n = _enem_nodos.get(id)
	# Si el cuerpo ya no esta, o si mientras viajaba la respuesta se me ha puesto una pantalla delante
	# (una pelea, otro minijuego), Game.start_extraction se iria de vacio y el candado se quedaria
	# puesto PARA SIEMPRE: ese cuerpo diria "ocupado" el resto de la sesion aunque nadie lo trabajara.
	# Era la razon de que el bug se "pegara" y reapareciera luego sin motivo. Se devuelve el candado.
	if n == null or not is_instance_valid(n) or Game.hay_pelea_en_pantalla():
		soltar_extraccion(id)
		return
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


# Suelto el cuerpo SIN haberlo extraido (me han quitado la pantalla, el cuerpo se fue con el piso
# viejo, o el minijuego se auto-cancelo). Gemela de notificar_extraido pero sin desvanecer nada: solo
# devuelve el candado, que si no se queda puesto para siempre.
func soltar_extraccion(id: int) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if _soy_dueno:
		_liberar_cadaver(id)
	elif es_host:
		_encaminar_soltar_cuerpo(id, _mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_soltar_cuerpo.rpc_id(1, id, _mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_soltar_cuerpo(id: int, lugar: String) -> void:
	if not es_host:
		return
	_encaminar_soltar_cuerpo(id, lugar)


func _encaminar_soltar_cuerpo(id: int, lugar: String) -> void:
	if _mi_lugar == lugar and _soy_dueno:
		_liberar_cadaver(id)
		return
	var dueno: int = _dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_soltar_cuerpo.rpc_id(dueno, id, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_soltar_cuerpo(id: int, lugar: String) -> void:
	if _mi_lugar != lugar or not _soy_dueno:
		return
	_liberar_cadaver(id)


# SOLO el dueño: devuelve el candado de un cuerpo que sigue ahi, intacto y extraible.
func _liberar_cadaver(id: int) -> void:
	_enem_ocupados.erase(id)
	_borrar_extrayendo(id)


# --- Difusion de los cuerpos que se estan extrayendo -------------------------------------------
#
# La lleva el DUEÑO del piso y viaja por el HOST, porque en ENet los clientes no se hablan entre
# ellos (mismo relevo que _rel_resp_extraccion).

func _apuntar_extrayendo(id: int, quien: int) -> void:
	if int(_extrayendo.get(id, 0)) == quien:
		return
	_extrayendo[id] = quien
	_difundir_extrayendo()


func _borrar_extrayendo(id: int) -> void:
	if not _extrayendo.has(id):
		return
	_extrayendo.erase(id)
	_difundir_extrayendo()


func _difundir_extrayendo() -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		_set_extrayendo.rpc(_extrayendo)
	else:
		_rel_extrayendo.rpc_id(1, _extrayendo)


@rpc("any_peer", "call_remote", "reliable")
func _rel_extrayendo(d: Dictionary) -> void:
	if not es_host:
		return
	_extrayendo = d.duplicate()   # el host tambien lo necesita para su propia F
	_set_extrayendo.rpc(d)


@rpc("any_peer", "call_remote", "reliable")
func _set_extrayendo(d: Dictionary) -> void:
	if _soy_dueno:
		return   # el mio es el autoritativo: no me lo pisa el eco del host
	_extrayendo = d.duplicate()


# ¿Ese cuerpo lo esta trabajando OTRO? Lo consulta player._mas_cercano_en_grupo para no apuntar a un
# cuerpo que ya tiene dueño: asi dos jugadores juntos apuntan a cuerpos DISTINTOS en vez de pelearse
# por el mas cercano y que uno se coma un aviso de "ocupado".
func cuerpo_ocupado_por_otro(net_id: int) -> bool:
	if not activo or multiplayer.multiplayer_peer == null:
		return false
	var peer: int = int(_extrayendo.get(net_id, 0))
	return peer != 0 and peer != multiplayer.get_unique_id()


func _consumir_cadaver(id: int) -> void:
	_enem_ocupados.erase(id)
	_borrar_extrayendo(id)
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


# Acuse de recibo DISCRETO, en la esquina de abajo. Para lo rutinario (el autoguardado salta cada
# minuto): un cartelon en mitad de la pantalla cada 60 segundos era insufrible.
func _aviso_esquina(texto: String) -> void:
	var hud: Node = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_aviso_esquina"):
		hud.mostrar_aviso_esquina(texto)
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


# 'derrotados' = peers cuyo grupo ENTERO cayo: en vez de devolverles el desgaste y cerrarles el
# espejo, se les manda al pueblo con la penalizacion (_moriste corre morir_jugador en SU maquina).
func cerrar_pelea(derrotados: Array = []) -> void:
	if _pelea_id != 0:
		for p in _pelea_participantes:
			if derrotados.has(p):
				# Su grupo murio: al pueblo. morir_jugador ya le reinicia las fichas, asi que NO se
				# le devuelve desgaste; _moriste tambien le cierra el espejo.
				_moriste.rpc_id(p)
				continue
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


# Corre en EL QUE SE UNIO y cuyo grupo cayo entero: vuelve al pueblo con la penalizacion, igual que
# morir en solitario (decision del usuario: en multi los jugadores mueren de verdad, no se quedan a
# 1 de vida). Primero cierra su espejo (recoge la capa y despausa) y luego morir_jugador cambia de
# escena al pueblo. Sus personajes viven en SU maquina, asi que la muerte se resuelve aqui.
@rpc("any_peer", "call_remote", "reliable")
func _moriste() -> void:
	_pelea_sigo = 0
	_pelea_anfitrion = 0
	_mis_en_pelea.clear()
	_mis_huecos.clear()
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("cerrar_espejo"):
		p.cerrar_espejo()   # -> Game._on_combate_espejo_cerrado: recoge la capa y el modal
	Game.morir_jugador()


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
const _LO_PUESTO := ["estados", "foco_cargas", "imbue"]
# Lo que se le devuelve al dueño cuando acaba la pelea: su desgaste y lo que ha aprendido.
const _VUELVE := ["current_hp", "current_mp", "stamina", "level",
	"ability_internal", "ability_consolidado", "ability_base_nivel",
	"fuerza", "resistencia", "destreza", "agilidad", "magia",
	"guardianes_vencidos", "esquivas_exp", "hechizos_exp", "recitado_exp",
	"dano_recibido_exp", "dano_infligido_exp",
	"heal_left", "heal_rate", "heal_turnos",
	"mana_heal_left", "mana_heal_rate", "mana_heal_turnos",
	"estados", "foco_cargas", "imbue"]


# ============================================================
#  UN PERSONAJE DE VERDAD (no el doble de combate) Y SU JUGADOR
#  ficha_a_dict/ficha_de_dict son el DOBLE: mandan lo justo para pelear, viajan en CADA union a una
#  pelea y traen el equipo SIN registrar a proposito (el bug de las 6 hachas). No se tocan.
#
#  Esto es lo otro: mandar a una PERSONA para que VIVA en un mundo que no esta en su disco. Va una
#  vez al entrar y otra al guardar, asi que puede permitirse ser fiel. Lo que el doble no lleva y
#  aqui es imprescindible:
#    es_original          el personaje intocable DE ESA PERSONA (sin esto se le podria echar del equipo)
#    dueno                de quien es (ver personaje_data.gd)
#    rol                  su kit y su ficha
#    pasivas_pendientes   una tirada de 1 entre 500.000 sin leer; perderla seria una crueldad
#  Y su equipo se deserializa REGISTRANDO: en un mundo compartido el baul del mundo es la casa de
#  esos objetos, no un prestamo para una pelea.
# ------------------------------------------------------------
const _PERMANENTES := ["es_original", "rol", "dueno", "pasivas_pendientes"]


func pj_a_dict(pj: PersonajeData) -> Dictionary:
	var d := ficha_a_dict(pj)
	for campo in _PERMANENTES:
		d[campo] = pj.get(campo)
	return d


# 'registrar' por defecto true porque el caso normal de esta funcion es el ALTA (un personaje que
# pasa a vivir en este mundo). Ver la nota de ficha_de_dict, y sobre todo _mi_estado, que es
# periodico y tiene que pasar false.
func pj_de_dict(d: Dictionary, registrar := true) -> PersonajeData:
	return ficha_de_dict(d, registrar)


# TODO lo de una persona en un mundo: sus personajes y lo que es suyo y de nadie mas (dinero, bolsa,
# oficios, donde se quedo). Es el JugadorData de jugador_data.gd, pero por cable.
func jd_a_dict(jd: JugadorData) -> Dictionary:
	var fichas: Array = []
	for pj in jd.personajes:
		if pj is PersonajeData:
			fichas.append(pj_a_dict(pj as PersonajeData))
	# El equipo va por INDICE dentro de `personajes`, NUNCA como copias: si el mismo personaje viajara
	# dos veces, al otro lado serian DOS objetos distintos y estaria a la vez en el equipo y en la
	# plantilla como dos personas (dos vidas, dos inventarios, y el desgaste de la pelea perdido).
	var huecos: Array = []
	for pj in jd.equipo:
		var i: int = jd.personajes.find(pj)
		if i >= 0:
			huecos.append(i)
	var bolsa: Array = []
	for it in jd.materiales:
		var m: Dictionary = _item_a_dict(it)
		if not m.is_empty():
			bolsa.append(m)
	var cris: Array = []
	for it in jd.crystals:
		var c: Dictionary = _item_a_dict(it)
		if not c.is_empty():
			cris.append(c)
	return {
		"id": jd.id, "nombre_visible": jd.nombre_visible,
		"personajes": fichas, "equipo": huecos, "lider_pos": jd.lider_pos,
		"dinero": jd.dinero, "materiales": bolsa, "crystals": cris,
		"consumibles": jd.consumibles.duplicate(),
		"mochila": Game.serializar_equipo(jd.equipped_mochila),
		# Las HERRAMIENTAS equipadas. Solo viajan las puestas, como la mochila: el baul de
		# herramientas de cada uno se queda en su save y no tiene por que existir en este mundo.
		"pico": Game.serializar_equipo(jd.equipped_pico),
		"hoz": Game.serializar_equipo(jd.equipped_hoz),
		"hacha": Game.serializar_equipo(jd.equipped_hacha),
		"cana": Game.serializar_equipo(jd.equipped_cana),
		"registro_pesca": jd.registro_pesca.duplicate(true),
		"mezcla": jd.mezcla_exp, "metalurgia": jd.metalurgia_exp,
		"peleteria": jd.peleteria_exp, "herreria": jd.herreria_exp,
		"materiales_vistos": jd.materiales_vistos.duplicate(),
		"pack_inicial": jd.pack_inicial,
		"en_mazmorra": jd.en_mazmorra, "current_floor": jd.current_floor, "pos": jd.pos,
	}


# 'registrar': ¿el equipo que trae este jugador pasa a vivir en MI baul? true en un ALTA (entra al
# mundo por primera vez, o vuelve: sus cosas tienen que existir aqui). FALSE en las
# SINCRONIZACIONES periodicas (_mi_estado), donde ya estan registradas de antes y volver a hacerlo
# mete una COPIA NUEVA cada vez -- ver la nota larga de _mi_estado.
func jd_de_dict(d: Dictionary, registrar := true) -> JugadorData:
	var jd := JugadorData.new()
	jd.id = String(d.get("id", ""))
	jd.nombre_visible = String(d.get("nombre_visible", ""))
	jd.personajes = []
	for f in d.get("personajes", []):
		jd.personajes.append(pj_de_dict(f as Dictionary, registrar))
	jd.equipo = []
	for i in d.get("equipo", []):
		var idx: int = int(i)
		if idx >= 0 and idx < jd.personajes.size() and not jd.equipo.has(jd.personajes[idx]):
			jd.equipo.append(jd.personajes[idx])   # la MISMA instancia, no una copia
	if jd.equipo.is_empty() and not jd.personajes.is_empty():
		jd.equipo.append(jd.personajes[0])   # sin equipo no hay con quien jugar
	jd.lider_pos = clampi(int(d.get("lider_pos", 0)), 0, maxi(0, jd.equipo.size() - 1))
	jd.dinero = int(d.get("dinero", 0))
	jd.materiales = []
	for m in d.get("materiales", []):
		var it: Resource = _item_de_dict(m as Dictionary)
		if it != null:
			jd.materiales.append(it)
	jd.crystals = []
	for c in d.get("crystals", []):
		var it2: Resource = _item_de_dict(c as Dictionary)
		if it2 != null:
			jd.crystals.append(it2)
	jd.consumibles = (d.get("consumibles", {}) as Dictionary).duplicate()
	# La mochila va por el MISMO criterio que el resto del equipo (antes llevaba un `true` a pelo, y
	# por ahi se colaba una mochila nueva en el baul en cada sincronizacion). Es suya y vive en este
	# mundo, pero eso se decide al darla de alta, no cada minuto. Ver Game.serializar_equipo, que le
	# guarda la capacidad porque es el unico campo de instancia que no esta en la meta.
	var mo: Resource = Game.deserializar_equipo(d.get("mochila", {}), registrar)
	if mo is BackpackData:
		jd.equipped_mochila = mo
		jd.owned_mochilas = [mo]
	# HERRAMIENTAS, por el MISMO criterio 'registrar' que la mochila y por la misma razon: con un
	# `true` a pelo cada sincronizacion periodica metería TRES herramientas nuevas en el baul. Es el
	# bug de las 6 hachas multiplicado por tres.
	jd.owned_tools = []
	for par in [["pico", "equipped_pico"], ["hoz", "equipped_hoz"], ["hacha", "equipped_hacha"],
			["cana", "equipped_cana"]]:
		var t: Resource = Game.deserializar_equipo(d.get(String(par[0]), {}), registrar)
		if t is ToolData:
			jd.set(String(par[1]), t)
			jd.owned_tools.append(t)
	jd.registro_pesca = (d.get("registro_pesca", {}) as Dictionary).duplicate(true)
	jd.mezcla_exp = float(d.get("mezcla", 0.0))
	jd.metalurgia_exp = float(d.get("metalurgia", 0.0))
	jd.peleteria_exp = float(d.get("peleteria", 0.0))
	jd.herreria_exp = float(d.get("herreria", 0.0))
	jd.materiales_vistos = (d.get("materiales_vistos", {}) as Dictionary).duplicate()
	jd.pack_inicial = bool(d.get("pack_inicial", false))
	jd.en_mazmorra = bool(d.get("en_mazmorra", false))
	jd.current_floor = maxi(1, int(d.get("current_floor", 1)))
	jd.pos = d.get("pos", Vector2.ZERO)
	jd.fecha_visto = Time.get_datetime_string_from_system(false, true)
	return jd


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
	# Y su pocion a medias, para que el anfitrion pueda meterla en la pelea (ver _COLAS_POCION), y lo
	# que lleve puesto: estados, cargas de Foco e imbuicion (ver _LO_PUESTO).
	for campo in _COLAS_POCION + _LO_PUESTO:
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
	# HABILIDADES de arma: lo que SABE y el set que lleva puesto POR TIPO DE ARMA. Sin esto el
	# doble entraba a la pelea con el set por DEFECTO de su arma en vez de con el suyo, que es un
	# bug de balance callado (el jugador ve otras cuatro habilidades y nadie avisa).
	# Viajan como rutas .tres, igual que los hechizos; el dict va con la clave en texto porque el
	# JSON no tiene claves enteras (al otro lado se vuelve a int, ver ficha_de_dict).
	var sabidas: Array = []
	for ab in pj.habilidades_aprendidas:
		if ab != null and not String(ab.resource_path).is_empty():
			sabidas.append(ab.resource_path)
	d["habs_sabidas"] = sabidas
	var sets: Dictionary = {}
	for clave in pj.loadout_habilidades:
		var rutas: Array = []
		for ab in pj.loadout_habilidades[clave]:
			# Los HUECOS viajan como "" y NO se saltan. Saltarlos acorta el array, y un set corto
			# es justo lo que Game._set_guardado interpreta como "posiciones que nunca han
			# existido" -> se las autorrellena. Resultado: el doble entraba con cuatro habilidades
			# donde su dueño llevaba una a proposito.
			rutas.append(ab.resource_path if ab != null and not String(ab.resource_path).is_empty() else "")
		sets[str(clave)] = rutas
	d["habs_sets"] = sets
	# SOBREPESO del que se une: viaja para que su doble vaya lento EL solo, no todo el grupo del
	# anfitrion. Es del loadout del HUMANO (su mochila), asi que va una vez por ficha con el mismo valor.
	d["overload"] = Game.overload_speed_factor()
	return d


# registrar: ¿el equipo que llega pasa a vivir en MI baul?
#   false (por defecto) = es el DOBLE de otro humano en una pelea: su arma NO es mia. Sin esto se
#     colaba en mi baul una copia por cada vez que se unia a mi pelea (el bug de las 6 hachas).
#   true = el personaje es PERMANENTE y este mundo es su casa (un invitado que se crea o que vuelve
#     en un mundo compartido): entonces su equipo TIENE que registrarse, porque el baul del mundo es
#     el sitio donde viven esos objetos.
func ficha_de_dict(d: Dictionary, registrar := false) -> PersonajeData:
	var pj := PersonajeData.new()
	for campo in d:
		if campo == "spells" or campo == "habs_sabidas" or campo == "habs_sets" or _RANURAS.has(campo):
			continue
		pj.set(campo, d[campo])
	for r in _RANURAS:
		var item: Resource = Game.deserializar_equipo(d.get(r, {}), registrar)
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
	# Habilidades de arma (ver ficha_a_dict). La clave del set vuelve a int: es el
	# WeaponData.Tipo con el que la guardo Game.clave_loadout.
	var sabidas: Array = []
	for ruta in d.get("habs_sabidas", []):
		var ab = load(String(ruta))
		if ab != null:
			sabidas.append(ab)
	pj.habilidades_aprendidas = sabidas
	var sets: Dictionary = {}
	var sets_in: Dictionary = d.get("habs_sets", {})
	for clave in sets_in:
		var lista: Array = []
		for ruta in sets_in[clave]:
			# "" = hueco que su dueño dejo vacio; entra como null y se respeta tal cual.
			lista.append(load(String(ruta)) if String(ruta) != "" else null)
		sets[int(str(clave))] = lista
	pj.loadout_habilidades = sets
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
	# Los estados vuelven como datos, pero lo que el mapa lee de ellos (cuanto te frenan, sus chips)
	# esta CACHEADO en la ficha: sin recalcularlo, el que se une a una pelea salia con el Pegajoso
	# puesto y andando a velocidad normal, y sin chips que lo dijeran.
	Game.refrescar_cache_estados(pj)


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
		_union_denegada.rpc_id(quien, "Esa pelea ya no está disponible.")
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
		if not Game.unir_aliado_al_combate(doble, float(f.get("overload", 1.0))):
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
		# La pelea existe: lo que pasa es que NO CABE nadie mas. Decirlo tal cual; el mensaje de
		# "ya no esta disponible" mandaba a buscar un problema que no era.
		_union_denegada.rpc_id(quien, "La pelea está llena: no cabe nadie más.")
		return
	_dobles[quien] = dobles       # de quien es cada doble, para devolverle lo suyo al acabar
	if not _pelea_participantes.has(quien):
		_pelea_participantes.append(quien)
	# Los INDICES le dicen cual de sus personajes es cada aliado de la pantalla: es lo unico que
	# significa lo mismo en las dos maquinas (y lo que necesita para saber a quien mover).
	_union_ok.rpc_id(quien, _pelea_id, p.roster_para_espejo(), idxs)


@rpc("any_peer", "call_remote", "reliable")
func _union_denegada(motivo: String = "Esa pelea ya no está disponible.") -> void:
	# El motivo lo manda el anfitrion: "no existe" y "esta llena" son cosas distintas y el jugador
	# necesita saber cual de las dos, o se pone a recolocarse pensando que apunta mal.
	_toast(motivo)


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

# La llama el combate cada vez que cambia algo que se ve. Va FIABLE: sale solo cuando cambia algo
# (no por frame), asi que garantizar la entrega es barato y evita que se pierda un avance o el "fin".
# Antes iba unreliable y una pelea larga la hacia pasar de la MTU -> se descartaba y el espejo se
# congelaba (el log ya va recortado a la cola, ver combat.instantanea). La barra de ATB sigue aparte.
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


@rpc("any_peer", "call_remote", "reliable")
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
func pedir_accion(peer: int, idx: int, seq: int = 0) -> void:
	if not activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_turno.rpc_id(peer, idx, seq)


# 'seq' es el numero de peticion: viaja de ida y vuelta para que el anfitrion sepa distinguir la
# respuesta a ESTA peticion de una rezagada (ver combat.gd, _pet_seq).
@rpc("any_peer", "call_remote", "reliable")
func _tu_turno(idx: int, seq: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion():
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("turno_mio"):
		p.turno_mio(idx, seq)


# MAGIA (hito 5.4-C): recitar son varios turnos con su examen de frases, asi que no basta con
# mandar una accion suelta como en las habilidades — hay que enrutar CADA frase. El anfitrion
# sortea las opciones (lleva la pelea) y el dueño responde con la que eligio.
func pedir_frase(peer: int, idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	if not activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_frase.rpc_id(peer, idx, opciones, nombre, largo, seq)


@rpc("any_peer", "call_remote", "reliable")
func _tu_frase(idx: int, opciones: Array, nombre: String, largo: int, seq: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion():
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("recitar_frase"):
		p.recitar_frase(idx, opciones, nombre, largo, seq)


func pedir_disparo(peer: int, nombre: String, seq: int = 0) -> void:
	if not activo or peer == 0 or multiplayer.multiplayer_peer == null:
		return
	_tu_disparo.rpc_id(peer, nombre, seq)


@rpc("any_peer", "call_remote", "reliable")
func _tu_disparo(nombre: String, seq: int = 0) -> void:
	if _pelea_sigo == 0 or not _lo_manda_el_anfitrion():
		return
	var p: Node = _pantalla_combate()
	if p != null and p.has_method("lanzar_conjuro"):
		p.lanzar_conjuro(nombre, seq)


# ¿Esto me lo manda de verdad quien lleva mi pelea? Las tres RPC de turno son "any_peer" (tienen que
# serlo: la pelea la ejecuta un jugador cualquiera, no el host de la red), asi que sin esta
# comprobacion cualquier peer podia ponerme los botones de un turno que no me toca.
func _lo_manda_el_anfitrion() -> bool:
	var quien := multiplayer.get_remote_sender_id()
	if _pelea_anfitrion != 0 and quien != _pelea_anfitrion:
		print("[multi] turno ignorado: lo manda el peer %d y mi pelea la lleva el %d" % [
			quien, _pelea_anfitrion])
		return false
	return true


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
		# QUIEN la manda va SIEMPRE con ella. Sin esto, el combate no podia distinguir la respuesta
		# del jugador al que le toca de la de otro (o de un eco tardio), y una respuesta rezagada
		# consumia el turno de quien no habia elegido nada. Ver combat.aplicar_accion_remota.
		p.aplicar_accion_remota(accion, multiplayer.get_remote_sender_id())


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


# --- MAPA DE LA SESION (la libreta del mundo del HOST) ----------------------------------------
#
# Se juega en el mundo del HOST, asi que la libreta que hay que mirar es la de SU mundo. Antes el
# mapa (tecla M) dibujaba Game.mapa_snapshot a pelo, que en el invitado es el de SU mundo (otra
# semilla): abrias el mapa y veias una mazmorra que no era la que estabas pisando. Y la NIEBLA se
# escribia en Game.mazmorra_persistente incluso en sesion, o sea que el save del invitado se iba
# llenando de niebla de un mundo ajeno.
#
# Ahora hay UNA libreta de sesion, autoritativa en el host, y NADA de esto toca el save del invitado.
#
# REGLA DE REFRESCO (decision del usuario): la exploracion se comparte, pero cada uno actualiza su
# copia SOLO CUANDO SUBE EL al pueblo. Si yo subo con una zona nueva, mi compañero no la ve hasta que
# suba el. Por eso el host, al fusionar lo que le trae alguien, le devuelve la libreta entera SOLO A
# EL: los demas se quedan con su copia vieja hasta que les toque. Al entrar en la sesion, el invitado
# recoge de golpe lo que el host tenga descubierto.
var _mapa_sesion: Dictionary = {}    # piso -> snapshot (mismo formato que Game.mapa_snapshot)
var _vistas_sesion: Dictionary = {}  # piso -> {zona_idx: true}  (la niebla)


# Solo host, al abrir sala: la libreta de la sesion empieza siendo la del mundo del host.
func _sembrar_mapa_sesion() -> void:
	_mapa_sesion = Game.mapa_snapshot.duplicate(true)
	_vistas_sesion = {}
	for p in Game.mazmorra_persistente:
		var vistas: Dictionary = (Game.mazmorra_persistente[p] as Dictionary).get("zonas_vistas", {})
		if not vistas.is_empty():
			_vistas_sesion[p] = vistas.duplicate()


# Lo que DIBUJA el mapa (lo lee Game.mapa_visible).
func mapa_sesion() -> Dictionary:
	return _mapa_sesion


# La niebla de un piso, creandola vacia si no existe. Es la que se escribe EN VIVO al andar
# (DungeonFloor) y la que lee la captura de la libreta (Game.capturar_mapa).
func vistas_sesion(piso: int) -> Dictionary:
	if not _vistas_sesion.has(piso):
		_vistas_sesion[piso] = {}
	return _vistas_sesion[piso]


# Los pisos que tienen niebla en MI copia (para el baseline de la expedicion).
func vistas_sesion_todas() -> Array:
	return _vistas_sesion.keys()


# Al MORIR: mi copia de la niebla vuelve a como estaba al bajar. Lo que ya estaba COMPROMETIDO en el
# host no se pierde -- alli sigue, y me llega entero la proxima vez que suba al pueblo con vida.
func revertir_vistas_sesion(baseline: Dictionary) -> void:
	for p in _vistas_sesion.keys():
		var vb: Dictionary = baseline.get(p, {})
		_vistas_sesion[p] = vb.duplicate()


# Lo llama Game.comprometer_mapa al SUBIR AL PUEBLO con vida: mando lo que he cartografiado esta
# bajada y, de vuelta, recibo la libreta fusionada. El host fusiona y me la devuelve solo a mi.
func comprometer_mapa_sesion(trabajo: Dictionary) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		_fusionar_mapa(trabajo, _vistas_sesion)
		return
	_pedir_fusion_mapa.rpc_id(1, trabajo, _vistas_sesion)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_fusion_mapa(trabajo: Dictionary, vistas: Dictionary) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	_fusionar_mapa(trabajo, vistas)
	# Solo A EL: los demas siguen con su copia vieja hasta que suban ellos.
	_set_mapa_sesion.rpc_id(quien, _mapa_sesion, _vistas_sesion)


# Solo host: mete en la libreta de la sesion lo que trae uno que acaba de subir al pueblo.
func _fusionar_mapa(trabajo: Dictionary, vistas: Dictionary) -> void:
	for p in vistas:
		var mia: Dictionary = vistas_sesion(int(p))
		for z in (vistas[p] as Dictionary):
			mia[z] = true
	for p in trabajo:
		var piso: int = int(p)
		if not _mapa_sesion.has(piso):
			_mapa_sesion[piso] = (trabajo[p] as Dictionary).duplicate(true)
			continue
		_fundir_snap(_mapa_sesion[piso], trabajo[p] as Dictionary)


# Fusiona DOS snapshots del mismo piso. Se puede porque los dos salen de la MISMA geometria (misma
# semilla): lo que cambia es cuanto ha visto cada uno, asi que la union es exacta. Se hace campo a
# campo y no reemplazando el snapshot entero, porque el que sube solo ha horneado SU niebla y
# reemplazar borraria del plano las zonas que descubrio el otro.
#
# ¡OJO! CAMPO A CAMPO SIGNIFICA QUE ESTA LISTA HAY QUE MANTENERLA. Lo que Game.capturar_mapa meta en
# el snapshot y no se copie AQUI se pierde en cada fusion, y solo en MULTIJUGADOR: en solitario
# comprometer_mapa reemplaza el diccionario entero y el campo nuevo llega igual. Asi se perdio
# "estanques" -- el plano pintaba los charcos en el editor y no en la partida con un compañero, que
# es el sitio donde nadie lo mira dos veces. Si añades una clave al snapshot, añadela abajo.
func _fundir_snap(base: Dictionary, nuevo: Dictionary) -> void:
	base["ancho"] = nuevo.get("ancho", base.get("ancho", 0))
	base["alto"] = nuevo.get("alto", base.get("alto", 0))
	_unir_celdas(base, nuevo, "suelo")
	_unir_por_celda(base, nuevo, "vivos")
	_unir_por_celda(base, nuevo, "escaleras")
	_unir_celdas(base, nuevo, "salidas")
	# El charco lleva su celda en "cell" como las escaleras (mas un "tam"), asi que una por celda.
	_unir_por_celda(base, nuevo, "estanques")
	# AGOTADOS: gana el sello mas NUEVO (es una cuenta atras de respawn; el ultimo picado es la verdad).
	var ag: Dictionary = base.get("agotados", {})
	for celda in (nuevo.get("agotados", {}) as Dictionary):
		var e = (nuevo["agotados"] as Dictionary)[celda]
		if not ag.has(celda) or _sello_de(e) >= _sello_de(ag[celda]):
			ag[celda] = e
	base["agotados"] = ag


# Union de una lista de CELDAS sueltas (suelo, salidas), sin repetir.
func _unir_celdas(base: Dictionary, nuevo: Dictionary, clave: String) -> void:
	var vistas: Dictionary = {}
	var out: Array = []
	for lista in [base.get(clave, []), nuevo.get(clave, [])]:
		for c in (lista as Array):
			if not vistas.has(c):
				vistas[c] = true
				out.append(c)
	base[clave] = out


# Union de una lista de DICTS que llevan su celda en "cell" (vivos, escaleras): una entrada por celda.
func _unir_por_celda(base: Dictionary, nuevo: Dictionary, clave: String) -> void:
	var por_celda: Dictionary = {}
	var out: Array = []
	for lista in [base.get(clave, []), nuevo.get(clave, [])]:
		for d in (lista as Array):
			var c = (d as Dictionary).get("cell")
			if not por_celda.has(c):
				por_celda[c] = true
				out.append(d)
	base[clave] = out


# El sello de tiempo de un 'agotado'. Los snapshots viejos guardaban solo el float; los nuevos, un
# dict con color y tipo (misma tolerancia que map_menu._dibujar).
func _sello_de(e) -> float:
	return float((e as Dictionary)["t"]) if e is Dictionary else float(e)


@rpc("authority", "call_remote", "reliable")
func _set_mapa_sesion(mapa: Dictionary, vistas: Dictionary) -> void:
	_mapa_sesion = mapa.duplicate(true)
	_vistas_sesion = vistas.duplicate(true)


# --- GUARDADO PREVENTIVO: el host guarda por los dos -------------------------------------------
#
# El guardado sincronizado de verdad (hito 6: un save autoritativo, la expedicion congelada y la
# posicion de cada invitado por identidad) es mucho mas grande y sigue pendiente. Esto es el
# PREVENTIVO acordado con el usuario: cuando el host da a Guardar, el invitado tambien guarda -- en SU
# ranura, en el PUEBLO de SU mundo, con el personaje tal y como esta en ese momento.
#
# Lo que se le guarda: objetos, nivel, excelia, oficios, pasivas... todo lo del PERSONAJE.
# Lo que NO: el progreso del MUNDO (bosses, tienda T2, mapa, vetas agotadas, baul y cofres comunes),
# porque eso es del mundo del HOST y en el suyo no lo ha hecho. De ahi el congelado de abajo.
#
# CONTRAPARTIDA (avisada): el invitado pierde el SITIO. Si estaba en el piso 8, al cargar sale en su
# pueblo. Su personaje y su bolsa, intactos.

# Lo que era MIO al entrar en la sesion, para devolverlo al save y no volcar el mundo del host.
# Vacio = no estoy de invitado (o ya me fui).
var _mundo_propio: Dictionary = {}


# Solo cliente, al conectar: aparta los campos del mundo PROPIO antes de que el host mande el suyo.
#
# No es cosmetico: mientras tengo el candado del taller, Game.almacen_materiales ES EL BAUL DEL HOST
# (ver _taller_ok). Guardar a pelo me metia en mi save los materiales de mi compañero.
func _congelar_mi_mundo() -> void:
	_mundo_propio = {
		"almacen_materiales": Game.almacen_materiales.duplicate(),
		"bote_dinero": Game.bote_dinero,
		"cofre_equipo": Game.cofre_equipo.duplicate(true),
		"cofre_consumibles": Game.cofre_consumibles.duplicate(true),
		"mazmorra_persistente": Game.mazmorra_persistente.duplicate(true),
		"mapa_snapshot": Game.mapa_snapshot.duplicate(true),
		"mapa_trabajo": Game.mapa_trabajo.duplicate(true),
		"bosses_derrotados": Game.bosses_derrotados.duplicate(),
		# Que METALES/MADERAS conoce mi oficio. Es progreso del MUNDO tanto como los bosses: lo que
		# se descubre picando aqui sale de las vetas del host, y si se queda pegado, al volver a mi
		# partida el herrero me ofrece sub-tiers que en mi mundo no he sacado nunca. Es la mitad
		# "LAN de siempre" del bug de los sub-tiers regalados; la otra mitad (mundo compartido) la
		# tapa Game.limpiar_mundo_heredado.
		"materiales_vistos": Game.materiales_vistos.duplicate(),
	}


# ¿Estoy jugando de invitado en el mundo de otro? Lo consulta Game.exportar_partida_invitado.
func mundo_propio_congelado() -> Dictionary:
	return _mundo_propio


# ============================================================
#  GUARDAR EN UN MUNDO COMPARTIDO: al reves que en el LAN de siempre
#  LAN de siempre: "guardaos todos" = cada uno escribe SU ranura. Aqui no: hay UN save y lo escribe
#  el HOST, asi que lo que se pide no es "guardate" sino "MANDAME LO TUYO".
#
#  Se espera a que contesten, pero con plazo: si alguien no responde (se le fue la red justo ahora),
#  se escribe su ultimo JugadorData conocido. Nunca se pierde su personaje; como mucho, sus ultimos
#  minutos. Bloquear el guardado del mundo por un peer mudo seria peor.
# ------------------------------------------------------------
const _PLAZO_ESTADOS := 1.5

var _estados_pedidos: Array = []   # peers a los que se les ha pedido y aun no han contestado


func recoger_estados(cerrando: bool = false) -> void:
	if not activo or not es_host or not mundo_compartido:
		return
	_estados_pedidos = _peers.keys()
	if _estados_pedidos.is_empty():
		return
	_dame_tu_estado.rpc(cerrando)
	var esperado := 0.0
	while not _estados_pedidos.is_empty() and esperado < _PLAZO_ESTADOS:
		await get_tree().create_timer(0.1).timeout
		esperado += 0.1
	if not _estados_pedidos.is_empty():
		push_warning("[multi] %d jugador(es) no mandaron su estado: se guarda el ultimo que tengo" % \
			_estados_pedidos.size())
	_estados_pedidos.clear()


# El host pide lo mio. Corre en el INVITADO.
@rpc("any_peer", "call_remote", "reliable")
func _dame_tu_estado(cerrando: bool) -> void:
	if es_host:
		return
	_mi_estado.rpc_id(1, jd_a_dict(Game.mi_jugador_data()))
	if not cerrando:
		_aviso_esquina("Partida guardada")
		return
	# El mundo se cierra: aqui no me queda nada (mi personaje se queda dentro de el). Un respiro para
	# que el paquete de arriba salga antes de cortar, o se guardaria sin mi ultimo rato.
	await get_tree().create_timer(0.4).timeout
	desconectar()
	estado_cambiado.emit("Se cerró el mundo. Tu personaje queda guardado dentro.")
	_sacar_a_escena("res://scenes/ui/multi_menu.tscn")


# Lo que manda el invitado. Corre EN EL HOST: lo mete en el mundo, tal cual, a nombre de su identidad.
#
# SIN REGISTRAR EL EQUIPO, y esto es lo importante. Esto corre en CADA guardado (el autoguardado del
# mundo es cada 60 s), y reconstruir una ficha con registrar=true mete su equipo en MI baul. Como
# crear_item hace base.duplicate(), cada vuelta son objetos NUEVOS y el guardia `not
# owned_weapons.has(item)` -- que compara por REFERENCIA -- no los reconoce: cada guardado añadia
# arma + escudo + 5 piezas + mochila al baul del host, y en media hora lo dejaba inservible.
# Su equipo ya se registro cuando entro al mundo (_alta_jugador / _alta_personaje); esto es una
# ACTUALIZACION, no un alta. Es el mismo fallo que el "bug de las 6 hachas" de ficha_de_dict, que se
# arreglo para el camino del combate y quedo vivo en este.
@rpc("any_peer", "call_remote", "reliable")
func _mi_estado(d: Dictionary) -> void:
	if not es_host or not mundo_compartido:
		return
	var quien := multiplayer.get_remote_sender_id()
	var identidad := String(_identidades.get(quien, ""))
	if identidad == "":
		return
	var jd: JugadorData = jd_de_dict(d, false)
	jd.id = identidad          # manda MI registro de quien es, no lo que diga el paquete
	# El estado ANTERIOR se tira: que se lleve consigo la meta de su equipo. Sin esto la fuga seguia
	# por debajo: crear_item apunta en item_meta ANTES de mirar 'registrar', asi que cada
	# sincronizacion dejaba ~8 entradas huerfanas que no purga nadie y que se vuelcan enteras al
	# save (y cada clave es un Resource, o sea un [sub_resource] entero en el .tres).
	_olvidar_meta_de(Game.jugadores_mundo.get(identidad))
	Game.jugadores_mundo[identidad] = jd
	_estados_pedidos.erase(quien)
	print("[multi] estado recibido de ", jd.nombre_visible, ": ", jd.resumen())


# La meta del equipo de un JugadorData que se va a TIRAR. Esas piezas las fabrico la sincronizacion
# anterior y no las referencia ya nadie, pero item_meta las tiene de CLAVE y eso las mantiene vivas
# (y las escribe en el save) para siempre.
func _olvidar_meta_de(jd) -> void:
	if not (jd is JugadorData):
		return
	for pj in (jd as JugadorData).personajes:
		if pj is PersonajeData:
			for r in _RANURAS:
				_olvidar_meta_item((pj as PersonajeData).get(r))
	_olvidar_meta_item((jd as JugadorData).equipped_mochila)
	for t in [(jd as JugadorData).equipped_pico, (jd as JugadorData).equipped_hoz,
			(jd as JugadorData).equipped_hacha, (jd as JugadorData).equipped_cana]:
		_olvidar_meta_item(t)


func _olvidar_meta_item(item) -> void:
	if not (item is Resource):
		return
	# SALVAGUARDA: si la pieza SI vive en mi baul (viene de un alta con registro, o de lo que dejo
	# acumulado este bug), su meta es la buena y borrarla la degradaria a T1/Comun -- meta_de fabrica
	# un por-defecto cuando no encuentra la entrada. Solo se olvida lo que no es de nadie.
	# Se pregunta por TIPO antes del has(): los arrays estan tipados y preguntarle a owned_armor por
	# un arma revienta (ver la nota de Game.sacar_de_baul).
	if item is ArmorData:
		if Game.owned_armor.has(item):
			return
	elif item is BackpackData:
		if Game.owned_mochilas.has(item):
			return
	elif item is ToolData:
		if Game.owned_tools.has(item):
			return
	elif Game.owned_weapons.has(item):
		return
	Game.item_meta.erase(item)


# Solo host: guardar por los dos. Mi partida la guarda quien me llama (el menu de pausa); aqui se le
# pide a cada invitado que guarde la suya. 'cerrando' = el host ha dado a "Guardar y SALIR": el
# invitado, ademas de guardar, se vuelve A SU MUNDO con la partida ya guardada, en vez de comerse un
# "el host ha cerrado la partida" a secas.
#
# ⚠️ ESTO ES EL CAMINO LEGADO (cada uno con su ranura). En un MUNDO COMPARTIDO no se usa: alli se
# llama a recoger_estados() y el host escribe UN save (ver arriba).
func guardar_todos(cerrando: bool = false) -> void:
	if not activo or not es_host or multiplayer.multiplayer_peer == null:
		return
	# .rpc() sin rpc_id = a TODOS los peers. Con dos o tres invitados guardan todos, cada uno en su
	# ranura: aqui no hay nada que asuma un solo invitado.
	_guardar_ahora.rpc(cerrando)
	if not cerrando:
		return
	# Un respiro antes de que el host corte: los RPC salen en el siguiente poll, y desconectar en el
	# mismo frame tiraria el paquete sin enviarlo (misma trampa que _rechazado). Sin esto el invitado
	# se quedaria sin guardar.
	await get_tree().create_timer(0.3).timeout


# Lo llama el INVITADO desde el menu de pausa: guardar no es privilegio del host. El invitado no
# puede guardar por su cuenta y ya (el host tiene que volcar SU mundo, que es donde estais jugando),
# asi que se lo PIDE y el host hace exactamente lo mismo que si hubiera pulsado el boton el.
func pedir_guardar_todos(cerrando: bool = false) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		return   # el host no se pide nada a si mismo: pause_menu ya llama a guardar_todos
	_pedir_guardar.rpc_id(1, cerrando)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_guardar(cerrando: bool = false) -> void:
	if not es_host:
		return
	var quien: int = multiplayer.get_remote_sender_id()
	# MUNDO COMPARTIDO: no hay "guardar por los dos", hay UN save. Se recogen los estados de todos
	# (incluido el del que lo pide) y se escribe; Mundos.autoguardar ya hace las dos cosas en orden.
	if mundo_compartido:
		var bien: bool = await Mundos.autoguardar()
		_aviso_guardado.rpc_id(quien, bien)
		return
	# El guardado del host lo hace Game (es quien habla con Perfil: ver la nota de _guardar_ahora).
	var ok: bool = Game.guardar_mi_partida()
	_aviso_guardado.rpc_id(quien, ok)
	if ok:
		# Y de aqui salen los guardados de TODOS los invitados, el que lo pidio incluido.
		guardar_todos(cerrando)


# Corre en el INVITADO que pidio guardar: si el host no pudo, que no se quede pensando que si.
@rpc("authority", "call_remote", "reliable")
func _aviso_guardado(ok: bool) -> void:
	if not ok:
		_toast("El anfitrión no ha podido guardar: tu partida tampoco se ha guardado.")


# Corre en el INVITADO: guarda en SU ranura, en el pueblo de SU mundo.
@rpc("authority", "call_remote", "reliable")
func _guardar_ahora(cerrando: bool = false) -> void:
	# El guardado en si lo hace Game (es quien habla con Perfil): si net.gd llamara a Perfil se cerraria
	# un ciclo net -> Perfil -> Game -> net y GDScript deja de inferir los tipos de Game.* aqui dentro.
	var ok: bool = Game.guardar_partida_invitado()
	if not cerrando:
		# El exito es rutina (va a la esquina); el FALLO si es una noticia y sale en grande.
		if ok:
			_aviso_esquina("Partida guardada")
		else:
			_toast("El anfitrión ha guardado, pero tu partida NO se pudo guardar.")
		return
	# El host cierra la sesion. Me vuelvo A MI MUNDO con lo que se acaba de guardar: se RECARGA de la
	# ranura, que es la unica forma de garantizar que no me llevo nada del mundo del host (baul, mapa,
	# bosses, el piso en el que estaba). Salgo de la sesion PRIMERO, o desconectar pisaria lo cargado
	# restaurando el baul de antes.
	desconectar()
	if ok and Game.recargar_mi_partida():
		estado_cambiado.emit("El anfitrión ha guardado y cerrado. Vuelves a tu mundo.")
	else:
		# No se pudo guardar/recargar: al menos no dejarle dentro de un piso del mundo del host.
		Game.current_floor = 1
		Game.olvidar_mazmorra()
		estado_cambiado.emit("El anfitrión ha cerrado la partida.")
	_sacar_a_escena("res://scenes/levels/town.tscn")


# --- HANDSHAKE + CONTRASEÑA ------------------------------------------------------------------

# Cliente: nada mas conectar, se presenta al host (id 1) con el codigo, su aspecto y su lugar.
func _on_connected_to_server() -> void:
	estado_cambiado.emit("Conectado. Validando codigo...")
	if not mundo_compartido:
		# LAN de siempre: tengo mi propia partida cargada y hay que protegerla del mundo del host.
		# Guardo MI baul de materiales antes de que el host me mande el suyo (lo recupero al salir).
		_almacen_solo = Game.almacen_materiales.duplicate()
		_almacen_guardado = true
		_congelar_mi_mundo()   # para poder GUARDAR sin volcar en mi save nada del mundo del host

	# EL ASPECTO SOLO SI TENGO PERSONAJE. En un mundo compartido todavia no lo tengo (me lo va a dar
	# el host), y `Game.player_*` delega en Game.lider(), que con el grupo vacio NO devuelve null: se
	# INVENTA un PersonajeData en blanco y lo mete en la plantilla. Ese fantasma se quedaria ahi al
	# llegar el personaje de verdad. Asi que en compartido se saluda con un aspecto neutro y el bueno
	# se difunde solo (player.refrescar_grupo -> anunciar_aspecto) al pisar el pueblo.
	var col := Color(1, 1, 1)
	var met := 0.0
	var nom := Identidad.nombre
	var png := PackedByteArray()
	var alp := 1.0
	if not mundo_compartido:
		col = Game.player_color
		met = Game.player_metalico
		nom = Game.player_nombre
		png = Game.player_imagen_png
		alp = Game.player_color_alpha

	_esperar_respuesta()
	_saludar.rpc_id(1, _codigo, PROTOCOLO, Identidad.id, Identidad.nombre,
		col, met, nom, _mi_lugar, png, alp)


# EL PLAZO. Si el host es de otro build, su _saludar tiene otra firma y Godot tira el paquete SIN
# error: sin esto, el jugador se queda mirando "Validando codigo..." para siempre.
var _respondio := false

func _esperar_respuesta() -> void:
	_respondio = false
	await get_tree().create_timer(_PLAZO_SALUDO).timeout
	if _respondio or not activo or es_host:
		return
	estado_cambiado.emit("El anfitrión no contesta. Lo más probable es que no coincida la versión "
		+ "del juego: tenéis que ser el mismo build.")
	desconectar()


# Corre EN EL HOST, llamado por el cliente. Valida el codigo y, si vale, se registran
# mutuamente; si no, se echa al que intenta colarse.
@rpc("any_peer", "call_remote", "reliable")
func _saludar(codigo: String, protocolo: int, identidad: String, nombre_visible: String,
		color: Color, metal: float, nombre: String, lugar: String,
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0) -> void:
	var quien := multiplayer.get_remote_sender_id()
	if codigo != _codigo:
		estado_cambiado.emit("Rechazado un intento con codigo incorrecto.")
		await _echar(quien, "No hay ninguna sala con ese codigo en esa IP.")
		return
	if protocolo != PROTOCOLO:
		estado_cambiado.emit("Rechazado: version de juego distinta (la suya %d, la mia %d)." % [
			protocolo, PROTOCOLO])
		await _echar(quien, "No coincide la versión del juego: tenéis que tener el mismo build.")
		return

	if mundo_compartido:
		# En un mundo compartido la identidad no es un adorno: es la llave de SU personaje.
		if identidad.strip_edges() == "":
			await _echar(quien, "Tu juego no dice quién eres: actualízalo.")
			return
		# La MISMA identidad dos veces a la vez no puede ser (un identidad.cfg copiado en dos
		# maquinas). Se permite usarla por turnos —eso es tu personaje en otro PC— pero no a la vez:
		# los dos reclamarian el mismo personaje del mundo y el ultimo en guardar pisaria al otro.
		for id in _identidades:
			if String(_identidades[id]) == identidad:
				await _echar(quien, "Ya hay alguien dentro con tu misma identidad de jugador.")
				return

	_identidades[quien] = identidad

	if mundo_compartido:
		# NO se le admite todavia: primero tiene que tener personaje. Se guarda en la puerta y se
		# entra por _listo(). Aqui NO se puede esperar (`await`) a que rellene el creador: esto es un
		# RPC, y mientras el elige nombre no puede andar por el mundo sin ficha.
		_en_la_puerta[quien] = {"identidad": identidad, "lugar": lugar, "nombre": nombre_visible}
		var jd = Game.jugadores_mundo.get(identidad)
		if jd is JugadorData:
			estado_cambiado.emit("%s vuelve al mundo." % nombre_visible)
			_tu_jugador.rpc_id(quien, jd_a_dict(jd as JugadorData), Game.semilla_mundo)
		else:
			estado_cambiado.emit("%s entra por primera vez: está creando su personaje." % nombre_visible)
			_crea_tu_personaje.rpc_id(quien, Game.player_nombre)
		return

	# LAN de siempre (cada uno con su ranura): dentro directo, como ha sido siempre.
	_admitir(quien, color, metal, nombre, lugar, imagen, alpha)


# Echar a alguien DICIENDO por que. El respiro es obligatorio: los RPC salen en el siguiente poll, y
# desconectar en el mismo frame tira el paquete sin enviarlo (el cliente se quedaria sin saber por que
# se le echo, que es como estaba antes de que el motivo viajara).
func _echar(quien: int, motivo: String) -> void:
	_rechazado.rpc_id(quien, motivo)
	await get_tree().create_timer(0.3).timeout
	_en_la_puerta.erase(quien)
	_identidades.erase(quien)
	if multiplayer.multiplayer_peer != null:
		multiplayer.disconnect_peer(quien)


# METERLE DENTRO de verdad. Es el cuerpo que antes era la segunda mitad de _saludar; se extrajo
# porque en un mundo compartido hay un paso intermedio (darle su personaje) y hasta que lo tenga no
# puede entrar.
func _admitir(quien: int, color: Color, metal: float, nombre: String, lugar: String,
		imagen: PackedByteArray, alpha: float) -> void:
	_en_la_puerta.erase(quien)
	# Presentaciones cruzadas con los que YA estaban (roster): antes de registrar al
	# nuevo, para no presentarselo a si mismo. Cada cliente que ya estaba se entera del nuevo, y al
	# nuevo se le pasa la lista entera. Sin esto, dos clientes serian invisibles entre si.
	for otro in _peers:
		var p: Dictionary = _peers[otro]
		# Al que ya estaba: aqui viene uno nuevo.
		_presentar_ajeno.rpc_id(otro, quien, color, metal, nombre, lugar, imagen, alpha)
		# Al nuevo: este otro ya estaba (con SUS datos, sequito incluido).
		_presentar_ajeno.rpc_id(quien, otro, p["color"], p["metal"], p["nombre"], p["lugar"],
			p.get("imagen", PackedByteArray()), float(p.get("alpha", 1.0)), p.get("comps", []))
	# Presentarme al nuevo (registra al HOST en su _peers) ANTES de registrarle yo: _registrar_peer
	# dispara mi anunciar_grupo(), y si su _set_grupo llegara antes que este _presentarse, el cliente
	# aun no me tendria en _peers y lo tiraria en la puerta (mi sequito no le apareceria). Viaja la
	# SEMILLA del mundo del host (para generar la MISMA mazmorra sin replicar geometria) y mi lugar.
	_presentarse.rpc_id(quien, Game.player_color, Game.player_metalico, Game.player_nombre,
		_mi_lugar, Game.semilla_mundo, Game.tienda_t2_abierta(), Game.player_imagen_png,
		Game.player_color_alpha, PackedInt32Array(Game.pisos_desbloqueados()))
	# Registro mutuo (en el host): apunta al nuevo y me re-anuncia el grupo a todos, el ya incluido.
	_registrar_peer(quien, color, metal, nombre, lugar, imagen, alpha)
	estado_cambiado.emit("%s se ha unido." % nombre)
	# Y ponerle al dia el SUELO de su lugar: lo que ya estaba soltado antes de que entrara.
	for id in _suelo:
		if _suelo[id]["lugar"] == lugar:
			_spawn_drop.rpc_id(quien, id, _suelo[id]["d"], _suelo[id]["pos"], lugar)
	# Estado compartido del hogar (el del HOST): baul de materiales, bote y cofre.
	_set_almacen.rpc_id(quien, _almacen_dicts())
	_set_bote.rpc_id(quien, Game.bote_dinero)
	_set_cofre.rpc_id(quien, Game.cofre_equipo)
	_set_cofre_consumibles.rpc_id(quien, Game.cofre_consumibles)
	# Y la LIBRETA del mundo (mapa + niebla): al entrar en mi mundo recoge lo que yo tenga descubierto.
	_set_mapa_sesion.rpc_id(quien, _mapa_sesion, _vistas_sesion)


# ============================================================
#  EL PERSONAJE DEL QUE SE UNE (mundo compartido)
#  Tres mensajes y una regla: el invitado NO entra hasta que tiene ficha.
#    host -> _tu_jugador        "este eres tu en este mundo" (vuelve alguien conocido)
#    host -> _crea_tu_personaje "no te conozco: hazte uno" (primera vez)
#    cliente -> _alta_personaje  el que acaba de crear; el host lo guarda EN EL MUNDO
#    cliente -> _listo           ya lo he aplicado, y este es mi aspecto de verdad
#  El aspecto viaja en _listo y no en el saludo porque al saludar el invitado todavia no tiene cara.
# ------------------------------------------------------------

# El mundo pide un personaje nuevo. Lo recoge la UI (el menu de multijugador), porque abrir una
# pantalla no es cosa de la capa de red.
signal pedir_personaje(nombre_mundo: String)
# Ya tengo mi personaje del mundo y estoy dentro: quien escuche esto lleva al jugador al pueblo.
signal entrada_lista


# Lo llama la UI cuando el jugador ha terminado de crear su personaje para este mundo.
func mandar_alta_personaje(pj: PersonajeData) -> void:
	if not activo or es_host:
		return
	_alta_personaje.rpc_id(1, pj_a_dict(pj))


# MUDANZA: en vez de un personaje recien creado, se manda uno TRAIDO de una partida de un jugador,
# con sus acompañantes, su equipo puesto y su bolsa (ver Game.jugador_data_desde_ranura).
func mandar_alta_jugador(jd: JugadorData) -> void:
	if not activo or es_host or jd == null:
		return
	_alta_jugador.rpc_id(1, jd_a_dict(jd))


@rpc("any_peer", "call_remote", "reliable")
func _crea_tu_personaje(nombre_mundo: String) -> void:
	_respondio = true
	estado_cambiado.emit("Es tu primera vez en este mundo: crea tu personaje.")
	pedir_personaje.emit(nombre_mundo)


# El invitado manda el personaje recien creado. Corre EN EL HOST: es el que lo guarda en el mundo,
# porque el mundo es suyo mientras tenga el cerrojo.
@rpc("any_peer", "call_remote", "reliable")
func _alta_personaje(d: Dictionary) -> void:
	if not es_host or not mundo_compartido:
		return
	var quien := multiplayer.get_remote_sender_id()
	if not _en_la_puerta.has(quien):
		return
	var identidad := String(_identidades.get(quien, ""))
	if identidad == "":
		return
	var pj: PersonajeData = pj_de_dict(d)
	pj.es_original = true       # EL personaje de esa persona en este mundo: intocable
	pj.dueno = identidad
	var jd := JugadorData.new()
	jd.id = identidad
	jd.nombre_visible = String(_en_la_puerta[quien].get("nombre", ""))
	jd.personajes = [pj]
	jd.equipo = [pj]
	jd.lider_pos = 0
	Game.jugadores_mundo[identidad] = jd
	print("[multi] alta de ", pj.nombre, " (", jd.nombre_visible, ") en el mundo")
	# Se le devuelve YA empaquetado: asi los dos lados parten de lo mismo y no hay dos verdades.
	_tu_jugador.rpc_id(quien, jd_a_dict(jd), Game.semilla_mundo)


# MUDANZA: el invitado trae un jugador ENTERO de una de sus partidas (personajes + bolsa + oficios).
# Corre EN EL HOST, que es quien manda mientras tenga el cerrojo del mundo, asi que aqui se valida
# todo lo que llega: no se admite un paquete que diga ser de otra persona, ni un equipo mas grande
# del que cabe. El equipo que traen los personajes se registra en el baul de este mundo (lo hace
# jd_de_dict via ficha_de_dict con registrar=true), que es donde tienen que vivir a partir de ahora.
@rpc("any_peer", "call_remote", "reliable")
func _alta_jugador(d: Dictionary) -> void:
	if not es_host or not mundo_compartido:
		return
	var quien := multiplayer.get_remote_sender_id()
	if not _en_la_puerta.has(quien):
		return
	var identidad := String(_identidades.get(quien, ""))
	if identidad == "":
		return
	# Ya tiene personaje aqui: no se le deja traer otro encima (seria machacar al que vive en el
	# mundo, y con el todo lo que hubiera hecho dentro).
	if Game.jugadores_mundo.get(identidad) is JugadorData:
		print("[multi] %s ya tiene personaje en este mundo: no se importa nada" % identidad)
		_tu_jugador.rpc_id(quien, jd_a_dict(Game.jugadores_mundo[identidad]), Game.semilla_mundo)
		return

	var jd: JugadorData = jd_de_dict(d)
	if jd.equipo.is_empty():
		print("[multi] el paquete de %s no trae equipo: no se da de alta" % identidad)
		return
	# La IDENTIDAD la pone el host con la del que lo manda, pase lo que pase en el diccionario.
	jd.id = identidad
	jd.nombre_visible = String(_en_la_puerta[quien].get("nombre", ""))
	# El grupo que baja no puede pasar del tope, y cada personaje queda a nombre de su dueño. Solo el
	# LIDER es "el original" de esa persona en este mundo; los acompañantes son contratados suyos.
	while jd.equipo.size() > Game.PARTY_MAX:
		jd.equipo.pop_back()
	jd.lider_pos = clampi(jd.lider_pos, 0, maxi(0, jd.equipo.size() - 1))
	for pj2 in jd.personajes:
		if pj2 is PersonajeData:
			(pj2 as PersonajeData).dueno = identidad
			(pj2 as PersonajeData).es_original = false
	var lider = jd.equipo[jd.lider_pos]
	if lider is PersonajeData:
		(lider as PersonajeData).es_original = true

	Game.jugadores_mundo[identidad] = jd
	print("[multi] MUDANZA: entra %s con %d personajes y %d materiales" % [
		jd.resumen(), jd.personajes.size(), jd.materiales.size()])
	_tu_jugador.rpc_id(quien, jd_a_dict(jd), Game.semilla_mundo)


# El host le da al invitado SU jugador de este mundo. Corre en el CLIENTE.
@rpc("any_peer", "call_remote", "reliable")
func _tu_jugador(d: Dictionary, semilla: int) -> void:
	_respondio = true
	# LO PRIMERO, antes de reconstruir nada: fuera lo que quede de mi partida anterior. Game es un
	# autoload y si venia de "Continuar" en una de mis ranuras, mi baul/almacen/mapa siguen puestos y
	# me los llevaba dentro del mundo de otro (ver Game.limpiar_mundo_heredado). Y va ANTES de
	# jd_de_dict porque ese registra en owned_*/item_meta el equipo que trae puesto mi personaje:
	# limpiar despues seria borrarselo.
	Game.limpiar_mundo_heredado()
	var jd: JugadorData = jd_de_dict(d)
	Game.aplicar_jugador_mundo(jd, semilla)
	mundo_compartido = true
	var l: PersonajeData = Game.lider()
	# Y ahora si tengo cara: se manda con el "estoy listo" para que el host me registre con ella.
	_listo.rpc_id(1, Game.player_color, Game.player_metalico, Game.player_nombre,
		Game.player_imagen_png, Game.player_color_alpha)
	estado_cambiado.emit("Entrando con %s." % (l.nombre if l != null else "tu personaje"))
	entrada_lista.emit()


# El invitado ya tiene ficha: ahora si se le mete dentro. Corre EN EL HOST.
@rpc("any_peer", "call_remote", "reliable")
func _listo(color: Color, metal: float, nombre: String, imagen: PackedByteArray, alpha: float) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if not _en_la_puerta.has(quien):
		return
	var lugar := String(_en_la_puerta[quien].get("lugar", "pueblo"))
	_admitir(quien, color, metal, nombre, lugar, imagen, alpha)


# Corre en el CLIENTE, llamado por el host tras aceptarlo: registra al host y guarda su semilla.
@rpc("any_peer", "call_remote", "reliable")
func _presentarse(color: Color, metal: float, nombre: String, lugar: String, semilla: int,
		t2: bool, imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0,
		atajos: PackedInt32Array = PackedInt32Array()) -> void:
	var quien := multiplayer.get_remote_sender_id()
	_respondio = true
	semilla_host = semilla
	tienda_t2_host = t2
	pisos_host = Array(atajos)
	_registrar_peer(quien, color, metal, nombre, lugar, imagen, alpha)
	estado_cambiado.emit("Conectado con %s." % nombre)


# Corre en el CLIENTE si el host lo rechaza por codigo. El flag evita que la desconexion
# posterior pise el aviso con un "el host ha cerrado" que no cuenta la verdad.
var _fui_rechazado := false

@rpc("any_peer", "call_remote", "reliable")
func _rechazado(motivo: String = "No hay ninguna sala con ese codigo en esa IP.") -> void:
	_fui_rechazado = true
	_respondio = true
	_motivo_rechazo = motivo
	# El motivo lo redacta el host. Para el codigo malo sigue siendo ambiguo a proposito ("no hay
	# ninguna sala con ese codigo en esa IP"): no se distingue "la sala existe pero el codigo esta
	# mal" de "no hay sala", asi que a un curioso no se le confirma que ahi hay una partida. Los
	# demas motivos (version distinta, identidad repetida) SI son claros: ahi ya sabes que existe.
	estado_cambiado.emit(motivo)


# Se guarda para que la desconexion posterior repita el MISMO motivo en vez de pisarlo con un
# "el host ha cerrado" que no cuenta la verdad.
var _motivo_rechazo := "No hay ninguna sala con ese codigo en esa IP."


# --- AVATARES -------------------------------------------------------------------------------

# Registra los DATOS de un peer y, si comparte mi lugar, le monta el nodo visual.
#
# 'avisar' (por defecto true) dispara los efectos de "acabamos de conocernos": re-anunciar MI
# sequito y, en el host, recontar humanos. Se pone a FALSE cuando el host me PRESENTA a varios peers
# ajenos de golpe (_presentar_ajeno): alli no quiero N difusiones de grupo en cascada ni tocar el
# recuento (los ajenos no cambian cuantos humanos hay: eso lo lleva el host aparte).
func _registrar_peer(peer_id: int, color: Color, metal: float, nombre: String, lugar: String,
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0, avisar: bool = true) -> void:
	# La IMAGEN del cuerpo viaja UNA VEZ, en el handshake: es un PNG ya recortado a 128x128
	# (Game.IMAGEN_CUERPO_MAX), no la foto original. Se guarda por peer para poder repintar su
	# cuerpo cada vez que se recrea (al cambiar de piso, por ejemplo) sin volver a pedirla.
	# El ALPHA es la opacidad del color SOBRE la imagen (color_alpha del shader): sin el, el color
	# tapaba del todo la cara del compañero (se fijaba a 1.0).
	_peers[peer_id] = {"color": color, "metal": metal, "nombre": nombre,
		"lugar": lugar, "pos": Vector2.INF, "peleando": false, "comps": [],
		"imagen": imagen, "alpha": alpha}
	if lugar == _mi_lugar:
		_crear_avatar_nodo(peer_id)
	if avisar:
		# Acabamos de conocernos: le digo como es MI sequito (el suyo me llegara igual). Sin esto, los
		# acompañantes del que ya estaba saldrian sin cara hasta que tocara su equipo.
		anunciar_grupo()
		# El HOST recuenta y difunde el numero de humanos (los clientes reajustan al recibirlo).
		if es_host:
			_sync_humanos()


# --- ROSTER: que los CLIENTES se conozcan entre si (topologia estrella) ----------------------
# En estrella un cliente solo tiene socket con el host: por su cuenta NUNCA sabe que existe otro
# cliente, asi que su _peers solo tendria al host y todos los manejadores de jugador (_set_aspecto,
# _set_grupo, _cambiar_lugar, _recibir_estado) tirarian los mensajes del otro en la puerta con
# `if not _peers.has(emisor)`. El HOST, que si los ve a todos, hace de presentador: cuando entra
# alguien, le pasa la lista de los que ya estaban y avisa a esos del nuevo. El peer va DENTRO del
# mensaje porque get_remote_sender_id() aqui seria siempre el host.
@rpc("authority", "call_remote", "reliable")
func _presentar_ajeno(peer_id: int, color: Color, metal: float, nombre: String, lugar: String,
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0, comps: Array = []) -> void:
	if peer_id == multiplayer.get_unique_id() or _peers.has(peer_id):
		return   # yo mismo, o ya lo conozco (llego dos veces): idempotente
	_registrar_peer(peer_id, color, metal, nombre, lugar, imagen, alpha, false)
	# Su SEQUITO viaja en la misma presentacion (no solo el lider): si no, veria al lider del otro
	# cliente pero sus acompañantes no naceran hasta que ese cliente vuelva a tocar su grupo. Basta
	# con guardarlo: _mover_companeros crea los cuerpos con esta cara en cuanto lleguen sus posiciones.
	if not comps.is_empty():
		_peers[peer_id]["comps"] = comps


# El host me dice que un peer ajeno se ha ido. Idempotente: con server_relay podria llegarme
# ademas mi propia señal peer_disconnected, y no pasa nada por limpiar dos veces.
@rpc("authority", "call_remote", "reliable")
func _quitar_ajeno(peer_id: int) -> void:
	_olvidar_peer(peer_id)


# Limpia la parte VISUAL y el registro de un peer: su avatar, su sequito y su entrada en _peers.
# El arbitraje del host (vetas, pisos, peleas) NO va aqui: eso se queda en _on_peer_disconnected,
# que es lo unico que corre cuando de verdad se cae un socket. Esto lo llaman los dos caminos.
func _olvidar_peer(peer_id: int) -> void:
	var a = _avatares.get(peer_id)
	if a != null and is_instance_valid(a):
		a.queue_free()
	_avatares.erase(peer_id)
	_quitar_companeros(peer_id)
	_peers.erase(peer_id)


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
	av.aplicar_aspecto(p["color"], p["metal"], p["nombre"], p.get("imagen", PackedByteArray()),
		float(p.get("alpha", 1.0)))
	if p["pos"] != Vector2.INF:
		av.ir_a(p["pos"])   # aparece donde iba, no en el origen
	_avatares[peer_id] = av
	# Su imbuicion, de lo ultimo que anuncio. Va DESPUES de guardar el avatar en _avatares porque
	# _aplicar_imbue_a_avatares lo busca ahi. Sin esto, entrar a una partida en marcha te mostraba
	# sin rastro a alguien que ya iba imbuido: el reparto en vivo (_set_imbue) solo alcanza a quien
	# ya estaba escuchando.
	_aplicar_imbue_a_avatares(peer_id, p.get("imbue", PackedInt32Array()))


func _on_peer_disconnected(id: int) -> void:
	var conocido := _peers.has(id)
	_olvidar_peer(id)   # avatar, sequito y registro (la parte visual, comun con _quitar_ajeno)
	# Su marcha cuenta como salir de la mazmorra: libera sus vetas y, si era el ultimo
	# dentro, la expedicion se cierra (solo decide el host).
	if es_host:
		# Roster: avisar a los DEMAS clientes de que este se ha ido, para que borren su avatar (en
		# estrella no se enteran por su cuenta). A quien se cayo no hay a quien mandarselo.
		for otro in _peers:
			_quitar_ajeno.rpc_id(otro, id)
		_liberar_vetas_de(id)
		_liberar_pesca_de(id)
		if _taller_dueno == id:   # se fue con el taller cogido: se libera (su crafteo a medias se pierde)
			_taller_dueno = 0
		if _reservas.has(id):   # se fue con material reservado: lo suelta para que el otro lo vea libre
			_reservas.erase(id)
			_set_reservas.rpc(_reservas)
			reservas_cambiadas.emit()
		# Si simulaba un piso, lo suelta SIN foto (se fue de golpe, no dio tiempo a sacarla): quien
		# se quede lo hereda vacio y las paredes lo van repoblando. Es el precio de un corte brusco.
		_soltar_piso(id, {})
		# Y si se fue A MEDIA PELEA, los bichos que tenia reservados quedarian congelados para
		# siempre. Que cada dueño suelte los suyos.
		_soltar_reservas_de.rpc(id)
		_soltar_reservas_de(id)
		# Irse NO es morir: se le quita la marca de caido para que no cuente en el "¿habeis muerto
		# todos?" de _registrar_muerte (el que se va tambien deja de contar en _num_humanos).
		_muertos.erase(id)
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


# Sacar al jugador de la escena en la que esta por orden del host o por un corte de red. TODAS las
# salidas de este tipo tienen que pasar por aqui, y no es cosmetico: la pila de modales vive en Game,
# que es un autoload y PERSISTE entre escenas. Si al jugador se le saca con un menu abierto (el de
# ESC es el caso tipico: el host guarda y cierra mientras el otro lo tiene delante), la pila se queda
# con su pausa puesta y la escena nueva NACE CONGELADA: no responde a nada y la unica salida es
# cerrar el juego a lo bruto. Es el mismo motivo por el que pause_menu._salir limpia antes de
# cambiar de escena.
func _sacar_a_escena(ruta: String) -> void:
	Game.limpiar_modales()
	get_tree().change_scene_to_file(ruta)


func _on_connection_failed() -> void:
	# IP mal escrita, host sin abrir, o no hay red: para el jugador es lo mismo.
	estado_cambiado.emit("No se encontro ninguna partida en esa IP.")
	desconectar()


func _on_server_disconnected() -> void:
	# Se guarda ANTES de limpiar el flag: mas abajo hay que volver a saber si esto fue un rechazo, y
	# si se lee `_fui_rechazado` despues de ponerlo a false siempre parece que no lo fue -- y se le
	# pisaba al jugador el motivo de verdad ("tu identidad ya esta dentro") con un "se cerro el mundo".
	var rechazado := _fui_rechazado
	if rechazado:
		_fui_rechazado = false
		estado_cambiado.emit(_motivo_rechazo)
	else:
		estado_cambiado.emit("El host ha cerrado la partida.")
	# MUNDO COMPARTIDO: mi personaje vive en el mundo del host, asi que aqui no me queda nada que
	# jugar -- ni pueblo propio al que volver. Al menu de multijugador, y lo que hubiera sin guardar
	# se queda en el ultimo guardado del host (el suyo autoguarda cada minuto).
	if mundo_compartido:
		desconectar()
		if not rechazado:
			estado_cambiado.emit("Se cerró el mundo. Tu personaje queda guardado dentro de él.")
		_sacar_a_escena("res://scenes/ui/multi_menu.tscn")
		return
	# Si me pilla DENTRO de la mazmorra, de vuelta al pueblo: ese piso era del MUNDO DEL HOST
	# (su semilla); sin sesion no tiene sentido seguir alli.
	var en_mazmorra := _mi_lugar.begins_with("piso:")
	desconectar()
	if en_mazmorra:
		Game.current_floor = 1
		Game.olvidar_mazmorra()
		_sacar_a_escena("res://scenes/levels/town.tscn")
