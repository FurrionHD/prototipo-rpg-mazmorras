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
# 3: el paquete de impactos estrena los bits 20-30 con el sonido de la habilidad. Un build del 2
#    los lee como cero y oye el generico del estilo -- no revienta, pero se oye otra pelea.
# 4: el estilo pasa de 6 a 8 bits (cabian 64 y hacen falta 104: cada arma y cada habilidad del
#    jugador tienen dibujo propio). Peso, solo_dibujo y sonido se corren a la izquierda, asi que un
#    build del 3 lee MAL los cuatro campos: ve otro efecto, otro peso y otro sonido.
# 6: cada impacto pasa de CUATRO enteros a CINCO. El quinto es la semilla con la que se sortean la
#    version del fichero de sonido y su tono, para que el golpe suene identico en las dos pantallas
#    en vez de que cada maquina se saque la suya. Un build del 5 lee el paquete CORRIDO desde el
#    segundo impacto: victimas, daños y efectos inventados, y sin dar ni un error.
# 9: mensajes nuevos (lo descubierto del mundo, imbuir a otro jugador) y el tick de enemigos lleva de
#    quien es la pelea. Añadir @rpc corre los ids de los demas: un build del 8 se entenderia MAL.
const PROTOCOLO := 9

# Cuanto espera el cliente una respuesta al saludo antes de dar por hecho que no se entienden.
const _PLAZO_SALUDO := 5.0
const _REMOTE_PLAYER := preload("res://scripts/actors/player/remote_player.gd")
const _PROYECTIL_HECHIZO := preload("res://scripts/actors/player/proyectil_hechizo.gd")

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

# ÉPOCA de la mazmorra de ESTA sesion (ver Game.epoca_mazmorra): decide QUE material y QUE pez sale
# en cada sitio. La pone el host y la tienen TODOS igual, o el invitado veria otra especie en el
# mismo charco y otro sub-tier en la misma veta.
#
# Viaja en _entrar_ok, junto al resto del estado de expedicion (agotados, sellos de jefe), porque es
# exactamente eso: estado de la expedicion. NO cambia al subir al pueblo —la mazmorra persiste—,
# solo cuando caeis todos (_olvidar_expedicion), que es el equivalente en sesion de olvidar_mazmorra.
# Un 0 significa "aun no me la han dicho": Game.epoca_actual cae entonces a la local.
var epoca_sesion: int = 0

# NONCE VIVO de cada sitio de recoleccion de la sesion: sitio -> el numero con el que nacio lo que
# hay ahi ahora. Hermano de _agotados_sesion y con su misma clave (Vector3i(piso, x, y)).
#
# Es lo que hace que el sub-tier de una veta SOBREVIVA a reconstruir el piso: sin esto, al bajar y
# volver a subir la celda renacia con nonce 0 y volvia a ser lo de siempre. Lo estrena _revivir_celda
# (respawn) y lo reparte _entrar_ok al que baja.
var _nonces_sesion: Dictionary = {}

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
# peer_id -> piso al que se le CONCEDIO viajar y aun no ha anunciado su lugar (SOLO host). Construir
# un piso lleva segundos y el lugar solo llega al acabar: sin esto, si otro bajaba en esa ventana el
# host no veia al viajero en el piso y nombraba DOS dueños (cada uno con sus bichos, sin verse).
var _viajando: Dictionary = {}
# piso -> {heredero, foto}: la foto que le mande a quien hereda un piso, hasta que confirme (SOLO host).
# Ver _soltar_piso y _piso_asumido.
var _traspasos: Dictionary = {}
var _soy_dueno := false            # ¿simulo YO el piso en el que estoy? (cada maquina)
var _peleando := false             # ¿estoy en un combate ahora mismo? (se difunde: ver avisar_combate)

# --- PELEAS COMPARTIDAS (hito 5.4-C) ---------------------------------------------------------
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
# EL RELOJ ES EL DE PARED (Game.reloj_mundo, unix time), el mismo que en una partida de un jugador.
# Hubo dos antes que este y los dos se rompian por el mismo sitio: un `_reloj_expedicion` propio, que
# moria con la expedicion y al volver a bajar te encontrabas TODAS las vetas otra vez; y
# tiempo_mazmorra, que ademas de eso se CONGELA con cualquier menu abierto -- y como aqui barre el
# HOST, bastaba con que el anfitrion tuviera el hogar abierto para que las vetas no volvieran para
# nadie. Con el reloj de pared no hay nada que congelar ni que se muera al salir: cinco minutos son
# cinco minutos en las dos maquinas, aunque las dos esten en un menu.
var _agotados_sesion: Dictionary = {}
# JEFES caidos de la sesion: piso -> unix time (reloj de pared) en que cayo. Mismo mecanismo que
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
# Latido APARTE para los jefes. No comparte el de las vetas porque no comparte el guard: aquel solo
# corre con la expedicion abierta y este corre siempre (ver _process).
var _t_bosses := 0.0
const BARRIDO_RESPAWN_CADA := 2.0   # cada cuanto repasa el host la tabla (igual que en solitario)

# --- RESERVAS de enemigos y EXTRACCION (hito 5.3) ---

# El panel de conexion se suscribe para pintar "Conectado / Rechazado / Host caido...".
signal estado_cambiado(texto: String)
# El host ha contestado a un pedir_guardar_todos (corre en el invitado). Lo espera el "Guardar y salir"
# del invitado para no cortar antes de que su estado haya llegado y se haya escrito.
signal guardado_respondido(ok: bool)

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
func encargos_visibles() -> Array:
	return _encargos_mirror if _soy_cliente() else Game.encargos
# Las tiradas ya gastadas del banner de novato. La pantalla del maestro lee SIEMPRE de aqui y nunca
# de Game.tiradas_novato: un cliente que mirase su propia copia creeria tener 30 cuando el host las
# tiene gastadas, y le dejaria darle al boton para nada.
func tiradas_novato_visibles() -> int:
	return _tiradas_novato_mirror if _soy_cliente() else Game.tiradas_novato

# --- ALMACEN del hogar (bote/cofre): viven en Game (PERSISTEN en la partida, solo y multi). En
# solitario son tu almacen personal; en multi los del HOST son los compartidos. Aqui solo guardo
# el MIRROR de lo del host para cuando soy CLIENTE (asi no piso mis propios Game.* : no se pierde
# nada al entrar/salir de una sesion). Las lecturas de la UI pasan por *_visible().
var _bote_mirror: int = 0
var _cofre_mirror: Array = []
var _cofre_consum_mirror: Dictionary = {}
# ENCARGOS: la lista es del MUNDO y la lleva el host. El cliente solo tiene el reflejo.
# Y el ROSTER: quien hay en el hogar de TODOS (con su poder y si esta fuera), porque el invitado
# tiene Game.jugadores_mundo vacio a proposito -- los demas jugadores son cosa del host -- y sin
# esta lista no podria ni ver a los personajes de su compañero para mandarlos.
var _encargos_mirror: Array = []
var _roster_mirror: Array = []
# El CUPO del banner de novato del mundo del host. Mismo papel que _bote_mirror.
var _tiradas_novato_mirror: int = 0
# SOLO HOST: identidad -> las filas del hogar de ESE jugador, EN VIVO, calculadas por el.
#
# Antes las filas de los demas se sacaban de Game.jugadores_mundo, que es una FOTO que solo se
# refresca con el autoguardado (~60 s). Con eso, el invitado veia sus PROPIOS personajes a traves de
# una copia rancia del host: si acababa de meter a alguien en su equipo, al compañero le seguia
# apareciendo libre, y los suyos se le caian del selector por un 'en_equipo' desfasado. Ahora cada
# uno publica lo suyo, que ademas es lo correcto: Encargos.poder y las stats de efecto dependen del
# equipo PUESTO, y eso solo lo sabe su dueño.
var _roster_ajeno: Dictionary = {}
# Hay que republicar/redifundir el hogar en el proximo frame. Es un FLAG y no un envio directo a
# proposito: _difundir_hogar -> _set_encargos -> Game.sacar_del_equipo marcaria sucio DENTRO de la
# recepcion de una difusion, y con envio inmediato eso son dos clientes difundiendose en bucle.
# Agrupado por frame, meter y sacar a cuatro personas seguidas es UNA sola publicacion.
var _hogar_sucio: bool = false
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
	# Los TRABAJADORES DE PISO viven en un hijo con nombre fijo: sus RPC necesitan la misma ruta
	# (/root/Net/Trabajadores) en todas las maquinas.
	_trab = preload("res://scripts/net/trabajadores.gd").new()
	_trab.name = "Trabajadores"
	add_child(_trab)
	# LOS TEMAS DE LA RED, cada uno en su archivo (ver la cabecera de cada uno). Cuelgan con NOMBRE FIJO
	# por lo mismo que los trabajadores: sus RPC viajan por la ruta del nodo.
	pesca = NetPesca.new()
	pesca.name = "Pesca"
	add_child(pesca)
	peleas = NetPeleas.new()
	peleas.name = "Peleas"
	add_child(peleas)
	extraccion = NetExtraccion.new()
	extraccion.name = "Extraccion"
	add_child(extraccion)
	enemigos = NetEnemigos.new()
	enemigos.name = "Enemigos"
	add_child(enemigos)
	suelo = NetSuelo.new()
	suelo.name = "Suelo"
	add_child(suelo)
	var args: PackedStringArray = _trab.argumentos()
	if not args.is_empty():
		_trab.arrancar.call_deferred(args)


# --- LOS TEMAS, cada uno en su archivo ---
const NetPesca = preload("res://scripts/net/net_pesca.gd")
const NetPeleas = preload("res://scripts/net/net_peleas.gd")
const NetExtraccion = preload("res://scripts/net/net_extraccion.gd")
const NetEnemigos = preload("res://scripts/net/net_enemigos.gd")
const NetSuelo = preload("res://scripts/net/net_suelo.gd")
var pesca: NetPesca = null
var peleas: NetPeleas = null
var extraccion: NetExtraccion = null
var enemigos: NetEnemigos = null
var suelo: NetSuelo = null

# --- TRABAJADORES DE PISO (ver trabajadores.gd) ---
var _trab: Node = null
# ¿Soy YO un trabajador (un Godot sin ventana que simula un piso para la sala)? Lo miran el jugador
# (que se apaga), el guardado (que no escribe) y los anuncios de aspecto/grupo (que no salen).
var soy_trabajador := false


# ¿Ese peer es un trabajador y no un humano? Solo lo sabe el host.
func es_trabajador(peer_id: int) -> bool:
	return _trab != null and _trab.es_trabajador(peer_id)


# El HOST lleva el reloj de la expedicion y decide que vetas/plantas reviven. Ver _barrer_respawns.
func _process(delta: float) -> void:
	# EL HOGAR, agrupado por frame (ver _hogar_sucio). Va ARRIBA del todo, antes de los guardias de
	# host y de expedicion: publicar tu equipo no tiene nada que ver con estar en la mazmorra.
	if _hogar_sucio:
		_hogar_sucio = false
		if _soy_cliente():
			_mi_hogar.rpc_id(1, _mis_filas_hogar())
		elif es_host:
			_difundir_hogar()
	if not activo or not es_host:
		return
	# LOS JEFES VAN POR SU CUENTA, por encima del guard de expedicion_abierta que hay debajo. Su reloj
	# es de PARED (Encargos.ahora), asi que corre igual con la mazmorra vacia y con todo el mundo en el
	# pueblo: no tiene nada que ver con que haya alguien dentro. Colgado del guard, el sello se quedaba
	# congelado en cuanto el ultimo subia al pueblo y solo se soltaba en la puesta al dia de volver a
	# bajar (_conceder_entrada) -- por eso el Rey Slime "no volvia" hasta que te ibas y regresabas.
	#
	# Es la OTRA MITAD del bug que dejo el comentario de _barrer_bosses: entonces se arreglo el RELOJ
	# (de tiempo_mazmorra a reloj de pared) y se dejo la CADENCIA colgando de un guard que se apaga.
	_t_bosses -= delta
	if _t_bosses <= 0.0:
		_t_bosses = BARRIDO_RESPAWN_CADA
		_barrer_bosses()
	if not expedicion_abierta:
		return
	# El reloj del respawn ya lo mueve Game (tiempo_mazmorra): aqui solo se marca cada cuanto tocar
	# la tabla.
	_t_barrido -= delta
	if _t_barrido <= 0.0:
		_t_barrido = BARRIDO_RESPAWN_CADA
		_barrer_respawns()


# --- ARRANQUE (lo unico especifico de ENet) -------------------------------------------------

# ¿Estoy en el pueblo? Las sesiones SOLO se abren/unen desde alli: montar una sesion con la
# mitad de la gente ya metida en una mazmorra de otro mundo es un nido de estados imposibles.
func _en_el_pueblo() -> bool:
	var esc: Node = get_tree().current_scene
	return esc != null and esc.scene_file_path.contains("town")


# ¿Se puede abrir sala AQUI? En el pueblo, siempre. Y en la MAZMORRA tambien (playtest del
# 11/09/2026): si el host guardaba dentro y reabria el mundo, la sala no existia hasta que pisaba el
# pueblo y su compañero se comia un "no se encontro ninguna partida". Dentro hace falta el piso ya
# construido (sus enemigos se registran al abrir, ver _montar_sesion_desde_dentro) y nada delante: ni
# una pelea ni una faena, que se montaron en solitario y no sabrian pasar a sesion.
func puede_abrir_sala() -> bool:
	if _en_el_pueblo():
		return true
	return _piso_listo_para_sesion() != null


# El piso en el que estoy, si se puede convertir en el de una sesion; null si no.
func _piso_listo_para_sesion():
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	if piso == null or not piso.is_node_ready() or int(piso.get("_piso_construido")) <= 0:
		return null
	if Game.hay_pelea_en_pantalla() or Game.combate_activo():
		return null
	return piso


func hostear(codigo: String, puerto: int = PUERTO) -> int:
	if not puede_abrir_sala():
		estado_cambiado.emit("Ahora no se puede abrir la sala: sal de la pelea o de la faena.")
		return ERR_UNAVAILABLE
	var piso_dentro = null if _en_el_pueblo() else _piso_listo_para_sesion()
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
	if piso_dentro != null:
		_montar_sesion_desde_dentro(int(piso_dentro.get("_piso_construido")))
	_trab.al_abrir_sala(puerto)   # el primer trabajador de reserva, arrancando ya
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
	if es_host:
		_trab.al_cerrar_sala()
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
	suelo._suelo.clear()
	suelo._drops.clear()
	# Enemigos: el host deja de simularlos por red; los cuerpos remotos del cliente se van (en el
	# pueblo no hay bichos, y al desconectar el cliente vuelve a su mundo sin sesion).
	for id in enemigos._enem_nodos.keys():
		var e = enemigos._enem_nodos[id]
		if is_instance_valid(e):
			e.retirar()
	enemigos._enem_nodos.clear()
	enemigos._enemigos.clear()
	peleas._enem_ocupados.clear()
	extraccion._extrayendo.clear()
	extraccion._extraccion_pidiendo = false
	enemigos._enem_next_id = 1
	enemigos._enem_acum = 0.0
	_peers.clear()
	_dentro.clear()
	_muertos.clear()
	_vetas_ocupadas.clear()
	_agotados_sesion.clear()
	_nonces_sesion.clear()
	_roster_ajeno.clear()
	_hogar_sucio = false
	epoca_sesion = 0
	_bosses_sello.clear()
	expedicion_abierta = false
	_dueno_piso.clear()
	_viajando.clear()
	_fotos_piso.clear()
	_traspasos.clear()
	Game.vistos_mundo.clear()   # lo descubierto por los demas era de la sesion, no mio
	_soy_dueno = false
	_peleando = false
	peleas._pelea_id = 0
	peleas._pelea_participantes.clear()
	peleas._dobles.clear()
	peleas._pelea_sigo = 0
	peleas._pelea_anfitrion = 0
	peleas._mis_en_pelea.clear()
	peleas._mis_huecos.clear()
	peleas._desgaste_pendiente = false   # se cae la sesion: ese lote ya no va a llegar nunca
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
	_tiradas_novato_mirror = 0
	_cofre_mirror = []
	_encargos_mirror = []
	_roster_mirror = []
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

# Lo mismo, publico: lo pregunta el charco para no tratarse a si mismo como un pescador remoto.
func mi_peer() -> int:
	return _mi_id()


# El id de este peer, para meterlo como "emisor" cuando difundo yo directamente (host).
func _mi_id() -> int:
	return multiplayer.get_unique_id()


# --- POSICION (lo que hace que os veais moveros) --------------------------------------------
# ESTRANGULADA a ~20 Hz: el player la llama cada tick de fisica (60 Hz), pero mas no hace falta
# —remote_player interpola con SUAVIZADO entre paquetes, igual que los bichos—, y al pasar por el
# host se multiplicaria por el numero de destinos. Baja el trafico tambien con 2 jugadores.
const _POS_TICK_MS := 50   # ~20 Hz, hermano de _ENEM_TICK (que va en segundos)
var _pos_last_ms := 0

# --- LA POSE, DENTRO DEL PAQUETE DE POSICION -------------------------------------------------
# Lo que hace falta para dibujar a otro jugador HACIENDO cosas, y no solo andando: si va agachado o
# corriendo, si lleva el arma en la mano, y si esta soltando un espadazo. Antes no viajaba NADA de
# esto -- remote_player pintaba "modo andar" a pelo -- y por eso el compañero cruzaba la mazmorra sin
# sacar el arma y sin dar un solo golpe visible.
#
# VA EMPAQUETADO EN UN INT y pegado a la posicion, no en un RPC aparte. Motivo: un golpe dura ~0,67 s
# y el paquete sale a 20 Hz, asi que un espadazo cae dentro de ~13 paquetes seguidos. Aunque el canal
# sea unreliable y se pierdan varios, el golpe se ve igual -- mientras que un aviso suelto que se
# pierda no se ve NUNCA. El contador de golpes (que sube en cada espadazo) es lo que distingue "sigue
# el mismo golpe" de "ha empezado otro".
const POSE_MODO := 0b11          # bits 0-1: movement_mode (0 sigilo, 1 andar, 2 correr)
const POSE_DESENV := 1 << 2      # bit 2: lleva el arma fuera
const POSE_VARIANTE := 0b11 << 3 # bits 3-4: la mano del golpe (0 der, 1 izq, 2 dos manos)
const POSE_SEQ := 0xFF << 5      # bits 5-12: contador de espadazos, da la vuelta solo


static func empaquetar_pose(modo: int, desenvainado: bool, variante: int, seq: int,
		faena: int = 0, volteo: bool = false, tier: int = 1, golpe: int = 0) -> int:
	return (clampi(modo, 0, 3)) | (POSE_DESENV if desenvainado else 0) \
		| (clampi(variante, 0, 3) << 3) | ((seq & 0xFF) << 5) \
		| (clampi(faena, 0, 7) << POSE_FAENA_BIT) | ((1 << POSE_VOLTEO_BIT) if volteo else 0) \
		| (clampi(tier, 0, 7) << POSE_TIER_BIT) | (clampi(golpe, 0, 3) << POSE_GOLPE_BIT)


# LA FAENA (picar, talar...) viaja en la misma pose, en los bits de arriba: cual es (0 = ninguna,
# indice en PoseJugador.FAENAS + 1), si va volteada (a la izquierda del recurso) y el tier de la
# herramienta, para que el pico del otro salga de su metal. Cada golpe sube el mismo 'seq' que los
# espadazos, asi que no hace falta ningun mensaje nuevo.
const POSE_FAENA_BIT := 13
const POSE_VOLTEO_BIT := 16
const POSE_TIER_BIT := 17
# COMO HA SALIDO el ultimo golpe de la faena (el enum Golpe de su minijuego: flojo/limpio/bruto...).
# Con el, los demas oyen el golpe que toca y la maquina que mueve a los bichos sabe cuanto ruido ha
# hecho (ver RemotePlayer._faena_golpe_remoto).
const POSE_GOLPE_BIT := 20

static func golpe_de_pose(pose: int) -> int:
	return (pose >> POSE_GOLPE_BIT) & 0b11

static func faena_de_pose(pose: int) -> int:
	return (pose >> POSE_FAENA_BIT) & 0b111

static func volteo_de_pose(pose: int) -> bool:
	return ((pose >> POSE_VOLTEO_BIT) & 1) != 0

static func tier_de_pose(pose: int) -> int:
	return maxi(1, (pose >> POSE_TIER_BIT) & 0b111)


# La llama el Player LOCAL cada tick de fisica si Net.activo. Difunde su posicion a los de MI lugar.
func enviar_estado(pos: Vector2, facing: Vector2, comps: Array = [], pose: int = 0) -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not activo or soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var ahora := Time.get_ticks_msec()
	if ahora - _pos_last_ms < _POS_TICK_MS:
		return
	_pos_last_ms = ahora
	if es_host:
		for pid in _peers:
			if _peers[pid].get("lugar", "") == _mi_lugar:
				_recibir_estado.rpc_id(pid, _mi_id(), pos, facing, comps, pose)
	else:
		_rel_estado.rpc_id(1, pos, facing, comps, pose)


# Cliente -> host: reparte mi posicion a los de MI lugar (el host sabe donde esta cada cual).
@rpc("any_peer", "call_remote", "unreliable_ordered")
func _rel_estado(pos: Vector2, facing: Vector2, comps: Array = [], pose: int = 0) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	var lugar: String = _peers.get(de, {}).get("lugar", "")
	if _mi_lugar == lugar:
		_recibir_estado(de, pos, facing, comps, pose)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_recibir_estado.rpc_id(pid, de, pos, facing, comps, pose)


# --- ¿QUIEN ESTA PELEANDO? (hito 5.3) --------------------------------------------------------
# Lo difunde Game al abrir/cerrar un combate. Sirve para que las paredes NO te paran bichos en las
# narices mientras estas en una pelea (no puedes ni verlo venir): ver spawn_zone._dist_min_de.
func avisar_combate(peleando: bool) -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not activo or soy_trabajador or multiplayer.multiplayer_peer == null:
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
		if pid == de or es_trabajador(pid):
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
# Es puro FX: sin autoridad y sin estado. Va FIABLE: son pocos y sueltos, y perder uno era que al
# compañero le salieran los bichos de una pared lisa (lo vio en el playtest del 11/09/2026).
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
@rpc("any_peer", "call_remote", "reliable")
func _rel_brote(paredes_px: Array, dur: float, amp: float, col: Color, lugar: String) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar:
		_pintar_brote(paredes_px, dur, amp, col)   # yo tambien estoy ahi
	for pid in _peers:
		if pid != de and (_peers[pid] as Dictionary).get("lugar", "") == lugar:
			_pintar_brote.rpc_id(pid, paredes_px, dur, amp, col)


@rpc("any_peer", "call_remote", "reliable")
func _pintar_brote(paredes_px: Array, dur: float, amp: float, col: Color) -> void:
	var piso: Node = Game.get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("pintar_aviso_pared"):
		piso.pintar_aviso_pared(paredes_px, dur, amp, col)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recibir_estado(emisor: int, pos: Vector2, _facing: Vector2, comps: Array = [],
		pose: int = 0) -> void:
	if _peers.has(emisor):
		_peers[emisor]["pos"] = pos   # se recuerda: al reconstruir su avatar aparece donde iba
	var a = _avatares.get(emisor)   # SIN tipar: puede ser una instancia ya liberada (ver nota abajo)
	if a != null and is_instance_valid(a):
		a.ir_a(pos)
		a.aplicar_pose(pose)   # su modo de andar, el arma fuera y el espadazo (ver empaquetar_pose)
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
		# El cuerpo nace AHORA (las posiciones llegan a 60 Hz, el farolillo solo cuando cambia), asi
		# que hay que darle el ultimo radio anunciado o alumbraria el suelo duro hasta que a su dueño
		# se le gastara el carbon. Mismo caso que la imbuicion en _montar_avatar.
		if c.has_method("aplicar_luz"):
			c.aplicar_luz(float(_peers[peer_id].get("luz", -1.0)))
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
			float(d.get("alpha", 1.0)), d.get("piezas", {}), d.get("equipo", {}))
	# Su imbuicion, de lo ultimo que anuncio. Sin esto un companero recreado (al viajar, o al
	# entrar tu a la partida) nace sin rastro aunque su dueño lleve el manto puesto.
	# +1 porque el hueco 0 del paquete es el LIDER (ver Net.anunciar_imbue).
	c.aplicar_imbue(_imbue_en(_peers[peer_id].get("imbue", PackedInt32Array()), idx + 1))
	return c


# Re-anuncia MI aspecto (el del LIDER) a todos. El del lider viaja en el handshake, pero si lo
# cambias en el hogar hay que re-difundirlo o el compañero no lo ve hasta que cambies de escena
# (que es cuando _reconstruir_vista recrea el avatar con los datos nuevos de _peers).
func anunciar_aspecto() -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not activo or soy_trabajador or multiplayer.multiplayer_peer == null:
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
	if es_host:
		for pid in _peers:
			_set_aspecto.rpc_id(pid, _mi_id(), c, m, n, img, al, pz, eq)
	else:
		_rel_aspecto.rpc_id(1, c, m, n, img, al, pz, eq)


@rpc("any_peer", "call_remote", "reliable")
func _set_aspecto(emisor: int, color: Color, metal: float, nombre: String, imagen: PackedByteArray,
		alpha: float = 1.0, piezas: Dictionary = {}, equipo: Dictionary = {}) -> void:
	if not _peers.has(emisor):
		return
	_peers[emisor]["color"] = color
	_peers[emisor]["metal"] = metal
	_peers[emisor]["nombre"] = nombre
	_peers[emisor]["imagen"] = imagen
	_peers[emisor]["alpha"] = alpha
	_peers[emisor]["piezas"] = piezas
	_peers[emisor]["equipo"] = equipo
	# Repinta su avatar YA (si lo tengo delante): sin esto el cambio no se veria hasta reconstruir.
	var a = _avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a != null and is_instance_valid(a) and a.has_method("aplicar_aspecto"):
		a.aplicar_aspecto(color, metal, nombre, imagen, alpha, piezas, equipo)


@rpc("any_peer", "call_remote", "reliable")
func _rel_aspecto(color: Color, metal: float, nombre: String, imagen: PackedByteArray,
		alpha: float = 1.0, piezas: Dictionary = {}, equipo: Dictionary = {}) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_aspecto(de, color, metal, nombre, imagen, alpha, piezas, equipo)
	for pid in _peers:
		if pid != de:
			_set_aspecto.rpc_id(pid, de, color, metal, nombre, imagen, alpha, piezas, equipo)


# --- ASPECTO DE MI GRUPO (hito 5.4) ----------------------------------------------------------
# El color/brillo/nombre de MIS acompañantes. Va aparte de la posicion (que viaja 60 veces por
# segundo) porque solo cambia cuando cambia el equipo. Se difunde al conectar y al tocar el grupo.
func anunciar_grupo() -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not activo or soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var datos: Array = []
	for pj in Game.companeros():
		# "piezas" = su pelo y su ropa (ver PersonajeData.aspecto_completo). La clave que no metas
		# aqui es la que hace que el compañero se vea distinto en la pantalla del otro, y solo ahi.
		datos.append({"color": pj.color, "metal": pj.metalico, "nombre": pj.nombre,
			"imagen": pj.imagen, "alpha": pj.color_alpha,
			"piezas": pj.aspecto_completo()["piezas"],
			# Lo que lleva puesto, igual que el lider (ver anunciar_aspecto). Aqui sale gratis porque
			# esto ya viajaba como diccionario.
			"equipo": Game.pj_a_dict(pj).get("equipo", {})})
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
				float(d.get("alpha", 1.0)), d.get("piezas", {}), d.get("equipo", {}))
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
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not activo or soy_trabajador or multiplayer.multiplayer_peer == null:
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


# --- APOYO AL PERSONAJE DE OTRO JUGADOR (Mantos, curas y buffs desde el mapa) -----------------
# La ficha de ese personaje vive en la maquina de su dueño, asi que se aplica ALLI. Viaja la ruta del
# hechizo y a quien: 'idx' en el orden [lider] + companeros() (el de _mis_imbues) y el nombre como
# comprobacion, por si su grupo ha cambiado entre medias; 'grupo' = a todos los suyos. La cura que pone
# el que lanza ya va calculada (Game.cura_magica_de). El mana ya lo cobro quien lo recito.
func apoyo_a_otro(spell: SpellData, peer: int, idx: int, nombre: String, grupo: bool) -> void:
	if not activo or spell == null or peer == 0:
		return
	var lanzador: String = Game.lider().nombre
	var cura: float = Game.cura_magica_de(spell, Game.lider())
	if es_host:
		_apoyarte.rpc_id(peer, spell.resource_path, idx, nombre, lanzador, cura, grupo)
	else:
		_rel_apoyo.rpc_id(1, peer, spell.resource_path, idx, nombre, lanzador, cura, grupo)


@rpc("any_peer", "call_remote", "reliable")
func _rel_apoyo(peer: int, ruta: String, idx: int, nombre: String, lanzador: String, cura: float,
		grupo: bool) -> void:
	if not es_host:
		return
	if peer == _mi_id():
		_apoyarte(ruta, idx, nombre, lanzador, cura, grupo)
	elif _peers.has(peer):
		_apoyarte.rpc_id(peer, ruta, idx, nombre, lanzador, cura, grupo)


# Corre en el DUEÑO del personaje.
@rpc("authority", "call_remote", "reliable")
func _apoyarte(ruta: String, idx: int, nombre: String, lanzador: String, cura: float, grupo: bool) -> void:
	var spell = load(ruta) if ruta.begins_with("res://") else null
	if not (spell is SpellData) or not (spell as SpellData).es_apoyo():
		return
	var sp: SpellData = spell
	# Metido en una pelea, la ficha la lleva el combate y la pisaria al cerrarse. No deberia llegar aqui
	# (quien lanza te ve peleando y entra en tu pelea en vez de mandar esto), pero la carrera existe.
	if Game.hay_pelea_en_pantalla():
		peleas._toast("✨ %s intentó echarte %s, pero estabas peleando." % [lanzador, sp.nombre])
		return
	var mios: Array = [Game.lider()]
	mios.append_array(Game.companeros())
	var destinos: Array = []
	if grupo:
		destinos = mios
	elif idx >= 0 and idx < mios.size() and (mios[idx] as PersonajeData).nombre == nombre:
		destinos = [mios[idx]]
	else:
		for g in mios:
			if (g as PersonajeData).nombre == nombre:
				destinos = [g]
				break
	var partes: PackedStringArray = []
	for pj in destinos:
		var hecho: String = Game.apoyo_desde_mapa(sp, pj, lanzador, cura)
		if hecho != "":
			partes.append("%s: %s" % ["tú" if pj == Game.lider() else (pj as PersonajeData).nombre, hecho])
	if not partes.is_empty():
		peleas._toast("✨ %s te echa %s.  %s" % [lanzador, sp.nombre, "  ·  ".join(partes)])


# --- ENTRAR EN LA PELEA DE UN JUGADOR (el que la ejecuta puede no ser el) ---------------------
# Para echarle una magia de apoyo a alguien que esta peleando hay que entrar en SU pelea, pero esa
# pelea la puede estar ejecutando otro (el esta espejando). Asi que se le pregunta a EL quien la lleva,
# que es el unico que lo sabe seguro, y con la respuesta se pide sitio por la via de siempre.
func unirme_a_la_pelea_del_jugador(peer: int) -> void:
	if not activo or peer == 0 or peer == _mi_id():
		return
	_dime_tu_pelea.rpc_id(peer)


@rpc("any_peer", "call_remote", "reliable")
func _dime_tu_pelea() -> void:
	var anfitrion: int = _mi_id() if peleas._pelea_id != 0 else peleas._pelea_anfitrion
	_esta_es_mi_pelea.rpc_id(multiplayer.get_remote_sender_id(), anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _esta_es_mi_pelea(anfitrion: int) -> void:
	if anfitrion == 0:
		peleas._toast("Esa pelea ya ha terminado.")
		return   # la nota del conjuro caduca sola y devuelve el mana (Game.tick_hechizo_de_entrada)
	peleas.solicitar_unirse(anfitrion)


@rpc("any_peer", "call_remote", "reliable")
func _rel_imbue(elems: PackedInt32Array) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_imbue(de, elems)
	for pid in _peers:
		if pid != de:
			_set_imbue.rpc_id(pid, de, elems)


# --- EL FAROLILLO DE CADA UNO ------------------------------------------------------------------
# Cuanto alumbra su lampara, en celdas. Canal propio y calcado del de las imbuiciones, por lo mismo:
# es un numero minusculo que cambia a su ritmo (enciendes, se gasta el carbon, cambias de farolillo)
# y no puede ir colgado de anunciar_aspecto, que arrastra el PNG del personaje.
#
# Antes NO viajaba nada de esto, y niebla._focos() le ponia a todos los aliados MI radio: en la
# pantalla de cada uno, el compañero alumbraba exactamente lo que alumbrabas tu. Se veia raro
# justamente cuando importa -- yo sin carbon y el otro con el farolillo bueno, y aun asi veia igual.
#
# Es SOLO del lider: los acompañantes van pegados a el y su luz es la misma (en local pasa igual,
# ver _focos). Un solo float, y el que no lo anuncie se queda con el suelo duro de vision.
#
# SE LLAMA CADA FRAME (desde niebla._focos) y manda solo cuando el numero CAMBIA de verdad. Es a
# proposito: el radio se mueve por media docena de motivos -enciendes, se acaba el trozo de carbon,
# prende el siguiente, te cambias el farolillo, bajas un piso- y engancharse a los seis call sites
# es la clase de lista a la que siempre se le olvida uno. Comparar un float por frame no cuesta nada
# y no se puede olvidar ninguno.
var _luz_anunciada: float = -1.0

func anunciar_luz() -> void:
	# Un trabajador de piso no es nadie: ni se mueve, ni pelea, ni tiene cara que anunciar.
	if not activo or soy_trabajador or multiplayer.multiplayer_peer == null:
		return
	var r: float = Game.radio_lampara()
	if is_equal_approx(r, _luz_anunciada):
		return
	_luz_anunciada = r
	if es_host:
		for pid in _peers:
			_set_luz.rpc_id(pid, _mi_id(), r)
	else:
		_rel_luz.rpc_id(1, r)


@rpc("any_peer", "call_remote", "reliable")
func _set_luz(emisor: int, radio: float) -> void:
	if not _peers.has(emisor):
		return
	# En _peers ADEMAS de en el avatar: quien entre despues -o vuelva a montar la vista al viajar-
	# recrea los cuerpos desde aqui, y sin esto nacerian con el radio por defecto.
	_peers[emisor]["luz"] = radio
	_aplicar_luz_a_avatares(emisor, radio)


func _aplicar_luz_a_avatares(emisor: int, radio: float) -> void:
	var a = _avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a != null and is_instance_valid(a) and a.has_method("aplicar_luz"):
		a.aplicar_luz(radio)
	for c in _avatares_comp.get(emisor, []):
		if is_instance_valid(c) and c.has_method("aplicar_luz"):
			c.aplicar_luz(radio)


@rpc("any_peer", "call_remote", "reliable")
func _rel_luz(radio: float) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	_set_luz(de, radio)
	for pid in _peers:
		if pid != de:
			_set_luz.rpc_id(pid, de, radio)


# --- CANTAR HECHIZOS EN EL MAPA: lo que ven los demas ------------------------------------------
# Puro ADORNO, y por eso va por su propio canal y no con la pelea: el bocadillo sobre la cabeza del
# que esta recitando y el conjuro que sale disparado. Nada de esto decide nada — quien resuelve el
# hechizo es la maquina que acaba montando el combate (ver Game._soltar_hechizo_de_entrada).
#
# 'texto' vacio = ha dejado de cantar (lo ha soltado, ha fallado o lo ha cancelado).
func anunciar_canto(texto: String, color: Color) -> void:
	if not activo or multiplayer.multiplayer_peer == null:
		return
	if es_host:
		for pid in _peers:
			if _peers[pid].get("lugar", "") == _mi_lugar:
				_set_canto.rpc_id(pid, _mi_id(), texto, color)
	else:
		_rel_canto.rpc_id(1, texto, color, _mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _set_canto(emisor: int, texto: String, color: Color) -> void:
	var a = _avatares.get(emisor)   # SIN tipar: puede estar liberado
	if a == null or not is_instance_valid(a) or not a.has_method("cantar"):
		return
	a.cantar(texto, color)


@rpc("any_peer", "call_remote", "reliable")
func _rel_canto(texto: String, color: Color, lugar: String) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar:
		_set_canto(de, texto, color)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_set_canto.rpc_id(pid, de, texto, color)


# El conjuro que sale volando hacia un bicho. Viaja el net_id del objetivo (que es lo unico que
# significa lo mismo en las dos maquinas), el color y la RUTA del hechizo: de ella salen la forma y
# el tamaño del proyectil (ver proyectil_hechizo), asi que sin ella el compañero veria un conjuro
# generico donde tu ves una Tormenta.
func anunciar_conjuro(objetivo: Node, color: Color, spell: SpellData = null) -> void:
	if not activo or multiplayer.multiplayer_peer == null or objetivo == null:
		return
	var id: int = int(objetivo.get_meta("net_id", 0)) if objetivo.has_meta("net_id") else 0
	if id == 0:
		return
	var ruta: String = String(spell.resource_path) if spell != null else ""
	if es_host:
		for pid in _peers:
			if _peers[pid].get("lugar", "") == _mi_lugar:
				_set_conjuro.rpc_id(pid, _mi_id(), id, color, ruta)
	else:
		_rel_conjuro.rpc_id(1, id, color, ruta, _mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _set_conjuro(emisor: int, id: int, color: Color, ruta: String = "") -> void:
	var a = _avatares.get(emisor)
	var obj = enemigos._enem_nodos.get(id)
	if a == null or not is_instance_valid(a) or obj == null or not is_instance_valid(obj):
		return
	var p: Node2D = _PROYECTIL_HECHIZO.new()
	p.setup(obj, color, load(ruta) as SpellData if ruta != "" else null)
	p.global_position = (a as Node2D).global_position
	var mundo: Node = get_tree().current_scene
	if mundo != null:
		mundo.add_child(p)


@rpc("any_peer", "call_remote", "reliable")
func _rel_conjuro(id: int, color: Color, ruta: String, lugar: String) -> void:
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	if _mi_lugar == lugar:
		_set_conjuro(de, id, color, ruta)
	for pid in _peers:
		if pid != de and _peers[pid].get("lugar", "") == lugar:
			_set_conjuro.rpc_id(pid, de, id, color, ruta)


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
	_viajando.erase(de)   # ya ha llegado: a partir de aqui manda su lugar de verdad
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
	for id in suelo._drops.keys():
		var n = suelo._drops[id]
		if is_instance_valid(n):
			n.queue_free()
	suelo._drops.clear()
	if es_host:
		for id in suelo._suelo:
			if suelo._suelo[id]["lugar"] == _mi_lugar:
				suelo._spawn_drop(id, suelo._suelo[id]["d"], suelo._suelo[id]["pos"], _mi_lugar)
	else:
		_pedir_suelo.rpc_id(1, _mi_lugar)
	# ENEMIGOS (hito 5.1/5.2): los cuerpos remotos murieron con la escena vieja. Si SIMULO este
	# piso no hay nada que pedir (los mios son reales y el piso ya los crea al poblarse/restaurar);
	# si solo lo espejo, pido la lista a quien lo simule. Al host no puede pedirsela a si mismo:
	# mira quien es el dueño y se la pide directamente.
	for id in enemigos._enem_nodos.keys():
		var en = enemigos._enem_nodos[id]   # sin tipar: puede ser una instancia ya liberada (ver purga del tick)
		if is_instance_valid(en):
			en.retirar()
	enemigos._enem_nodos.clear()
	if not _soy_dueno and _mi_lugar.begins_with("piso:"):
		if es_host:
			var dueno: int = _dueno_piso.get(mi_piso(), 0)
			if dueno != 0 and dueno != 1:
				enemigos._pedir_roster.rpc_id(dueno, _mi_lugar, 1)
		else:
			enemigos._pedir_enemigos.rpc_id(1, _mi_lugar)


# Un cliente que acaba de viajar pide el suelo de su lugar nuevo.
@rpc("any_peer", "call_remote", "reliable")
func _pedir_suelo(lugar: String) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	for id in suelo._suelo:
		if suelo._suelo[id]["lugar"] == lugar:
			suelo._spawn_drop.rpc_id(quien, id, suelo._suelo[id]["d"], suelo._suelo[id]["pos"], lugar)


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
	# La EPOCA de la sesion se fija UNA vez y no la mueve entrar ni salir: la mazmorra persiste, asi
	# que subir al pueblo y volver a bajar tiene que encontrar los mismos tiers. Solo la renueva
	# _olvidar_expedicion (habeis caido todos). Se coge del save del host, que es de quien es el mundo.
	if epoca_sesion == 0:
		if Game.epoca_mazmorra == 0:
			Game.renovar_epoca()
		epoca_sesion = Game.epoca_mazmorra
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
	_trab.asegurar_dueno(piso)   # si hay un trabajador libre, el piso es suyo y yo entro de espejo
	var dueno: bool = _asignar_dueno(piso, quien)
	var mem: Dictionary = {}
	if dueno:
		mem = _fotos_piso.get(piso, {})
		_fotos_piso.erase(piso)
	# Va el diccionario ENTERO, no solo las claves: el valor es el momento en que se pico, y sin el
	# quien entra no sabria cuanto le queda a cada sitio para revivir.
	# Los jefes viajan como SEGUNDOS QUE FALTAN, no como el instante en que cayeron: el instante esta
	# en el reloj de PARED DEL HOST, y el del que recibe no tiene por que ir a la misma hora. Con
	# timestamps crudos el contador de la sala del jefe le saldria corrido por el desfase entre los dos
	# relojes (y con uno mal puesto, absurdo). Los segundos que faltan son los mismos en cualquier reloj.
	if quien == 1:
		_entrar_ok(piso, _agotados_sesion, dueno, mem, _restantes_boss(), epoca_sesion, _nonces_sesion)
	else:
		_entrar_ok.rpc_id(quien, piso, _agotados_sesion, dueno, mem, _restantes_boss(),
			epoca_sesion, _nonces_sesion)


# ABRIR LA SALA ESTANDO YA DENTRO DE UN PISO. Es _conceder_entrada + _entrar_ok sin viajar: el piso
# ya esta construido (en solitario) y hay que convertirlo en el de una sesion. Sin esto el host se
# quedaba con _mi_lugar "pueblo", la expedicion cerrada (las escaleras no contestaban), sin simular
# nada (los enemigos congelados) y con los enemigos fuera de _enemigos (al compañero le llegaba el
# piso vacio).
func _montar_sesion_desde_dentro(piso: int) -> void:
	if epoca_sesion == 0:
		if Game.epoca_mazmorra == 0:
			Game.renovar_epoca()
		epoca_sesion = Game.epoca_mazmorra
	expedicion_abierta = true
	_sembrar_agotados_del_save()
	# Los NONCES tambien: las vetas de este piso nacieron con los de MI save (el piso se construyo en
	# solitario), y el que baje construira el suyo con los de la sesion. Sin sembrarlos veria otro
	# material en la misma veta.
	for p in Game.mazmorra_persistente:
		var nn = (Game.mazmorra_persistente[p] as Dictionary).get("nonces", {})
		if nn is Dictionary:
			for celda in nn:
				_nonces_sesion[_sitio(int(p), celda as Vector2i)] = int(nn[celda])
	_barrer_respawns()
	_dentro[1] = true
	_dueno_piso[piso] = 1
	_soy_dueno = true
	var lugar := "piso:%d" % piso
	anunciar_lugar(lugar)
	# Lo que ya existe se da de alta en la red, igual que si hubiera nacido con la sesion abierta.
	var n_enem: int = 0
	for grupo in ["enemy", "corpse"]:
		for e in get_tree().get_nodes_in_group(grupo):
			if is_instance_valid(e) and not e.has_meta("net_id") and e is Node2D:
				enemigos.registrar_enemigo(e, lugar)
				n_enem += 1
	# Y lo que hay por el suelo: los pickups locales pasan a ser drops de la sesion (_suelo), o el
	# compañero no los veria y yo los recogeria por la rama de solitario.
	var n_suelo: int = 0
	for pk in get_tree().get_nodes_in_group("pickup"):
		if not is_instance_valid(pk) or pk.has_meta("net_id") or pk.get("item") == null:
			continue
		var d: Dictionary = suelo._item_a_dict(pk.item)
		if d.is_empty():
			continue
		var pos: Vector2 = (pk as Node2D).global_position
		pk.queue_free()
		suelo._registrar_y_difundir(d, pos, lugar)
		n_suelo += 1
	print("[multi] sala abierta desde el piso %d: %d enemigos y %d cosas del suelo a la sesion" % [
		piso, n_enem, n_suelo])


# {piso: segundos que le faltan a ese jefe}. Solo tiene sentido en el host, que es quien lleva la
# cuenta. Ver _conceder_entrada y _marcar_boss: es la moneda con la que los jefes cruzan la red.
func _restantes_boss() -> Dictionary:
	var d: Dictionary = {}
	for piso in _bosses_sello:
		var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
		var pasado: float = float(Encargos.ahora()) - float(_bosses_sello[piso])
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
	_agotados_sesion = agotados.duplicate()
	# Que jefes de la sesion estan muertos ahora mismo. Sin esto, el que baja al piso 6 por el atajo
	# plantaria un rey slime que para los demas sigue muerto (y solo el lo veria).
	#
	# Llegan como SEGUNDOS QUE FALTAN (ver _conceder_entrada) y se pasan aqui a MI reloj de pared, para
	# que la resta de boss_restante valga igual en las dos maquinas. El HOST no se toca la suya: es la
	# tabla autoritativa, ya esta en su reloj, y re-hacerla desde su propio mensaje solo podria
	# estropearla con el redondeo del viaje de ida y vuelta.
	if not es_host:
		_bosses_sello.clear()
		# 'p' y no 'piso': el parametro de esta funcion ya se llama asi (el piso al que entro).
		for p in sellos_boss:
			var espera: float = float(Game.BOSS_RESPAWN.get(p, 0.0))
			_bosses_sello[p] = float(Encargos.ahora()) - (espera - float(sellos_boss[p]))
	Game.current_floor = piso
	# La EPOCA y los NONCES del mundo del host: sin ellos el invitado tiraria por su cuenta que
	# material y que pez sale en cada sitio, y veria cosas distintas de las del host en la MISMA veta.
	# Se cogen ANTES de olvidar_mazmorra a proposito: esa renueva la epoca LOCAL (la de mi propio
	# mundo, que aqui no pinta nada) y lo que vale mientras dure la sesion es epoca_sesion.
	_nonces_sesion = nonces.duplicate()
	Game.olvidar_mazmorra()
	if epoca != 0:
		epoca_sesion = epoca
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
	var viejo: int = _piso_de(quien)
	_liberar_vetas_de(quien)
	pesca._liberar_pesca_de(quien)   # sus corchos y el pez que tuviera enganchado
	_soltar_piso(quien, foto)
	_viajando.erase(quien)
	_trab.revisar_vacio(viejo, quien)
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
	_traspasos.clear()
	_muertos.clear()
	# EPOCA NUEVA, como en solitario (Game.olvidar_mazmorra): la mazmorra vuelve a nacer, asi que se
	# rebaraja QUE hay en ella. Los nonces vivos se van con ella —ya no significan nada— y a los
	# demas les llega todo en el _entrar_ok de la proxima bajada.
	Game.renovar_epoca()
	epoca_sesion = Game.epoca_mazmorra
	_nonces_sesion.clear()
	for id in suelo._suelo.keys():
		if str(suelo._suelo[id]["lugar"]).begins_with("piso:"):
			suelo._suelo.erase(id)
			suelo._despawn_drop.rpc(id)
			suelo._despawn_drop(id)
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
	# Los pisos de los TRABAJADORES se quedan apuntados: su foto viene de camino (ver
	# Trabajadores.revisar_vacio) y hasta que llegue siguen siendo suyos. Borrarlos aqui perdia la foto y
	# dejaba al trabajador simulando un piso que ya nadie sabia que era suyo.
	for p in _dueno_piso.keys():
		if not es_trabajador(int(_dueno_piso[p])):
			_dueno_piso.erase(p)
	_traspasos.clear()
	_viajando.clear()
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
	# LA ARENA DE PRUEBAS ES SIEMPRE MIA. Es una sala local de dev: sus bichos los pone tu spawner,
	# no viajan por la red y nadie mas los ve. La propiedad solo se reclama en pisos de mazmorra
	# (ver _reclamar_piso), asi que en la arena _soy_dueno era false y con una sesion abierta
	# _start_combat se salia en seco SIN marcar nada ni reintentar: los bichos se te pegaban y te
	# atacaban y no se abria una sola pelea.
	if _mi_lugar == "sandbox":
		return true
	return (not activo) or _soy_dueno


# CUANTOS personajes hay en MI piso, contando los grupos de los otros humanos que esten aqui.
# Lo usa el tamaño del brote: contar solo Game.party hacia que el brote saliera pequeño cuando
# estabais dos en el mismo piso, justo cuando la regla de diseño ("siempre te superan por uno")
# tenia que dar mas. En solitario devuelve tu grupo, igual que antes.
func personajes_en_mi_piso() -> int:
	# El trabajador no trae grupo: su Game.party es un personaje inventado que nadie ve.
	var n: int = 0 if soy_trabajador else Game.party.size()
	if not activo:
		return n
	for pid in _peers:
		var p: Dictionary = _peers[pid]
		if p.get("lugar", "") == _mi_lugar and not bool(p.get("trabajador", false)):
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
	var viejo: int = _piso_de(quien)
	_soltar_piso(quien, foto)
	_trab.asegurar_dueno(nuevo)
	var dueno_nuevo: bool = _asignar_dueno(nuevo, quien)
	if quien != 1:
		_viajando[quien] = nuevo   # hasta que llegue su _rel_lugar (ver _sigue_en)
	# El piso que deja puede quedarse sin humanos: si lo lleva un trabajador, se congela.
	if viejo != nuevo:
		_trab.revisar_vacio(viejo, quien)
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
	# EL RELEVO A MEDIAS. Si 'quien' era el heredero de un traspaso que aun no ha confirmado, su foto
	# llega VACIA (no llego a simular el piso: _foto_de_mi_piso exige ser dueño), pero la de verdad la
	# tengo yo, la que le mande. Sin esto el piso se congelaba con {} y perdia todos sus enemigos.
	var pend: Dictionary = _traspasos.get(piso, {})
	_traspasos.erase(piso)
	if foto.is_empty() and int(pend.get("heredero", 0)) == quien:
		foto = pend.get("foto", {})
	var heredero: int = _alguien_en(piso, quien)
	if heredero == 0:
		# Nadie mas: el piso queda congelado tal cual. Una foto VACIA no significa "piso vacio" (esa
		# trae la clave "enemigos" aunque sea sin nadie), significa "no tengo foto": nunca pisa una buena.
		if not foto.is_empty() or not _fotos_piso.has(piso):
			_fotos_piso[piso] = foto
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
		# Me QUEDO la foto hasta que confirme (_piso_asumido): si se va antes de procesarla, es la unica
		# copia que queda.
		_traspasos[piso] = {"heredero": heredero, "foto": foto}
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
	# Los TRABAJADORES no cuentan: esto pregunta por humanos (quien hereda un piso, si se ha quedado vacio).
	for id in _peers:
		if id != salvo and _peers[id].get("lugar", "") == lugar and not _viajando.has(id) \
				and not es_trabajador(id):
			return id
	# Uno que viene de camino tambien cuenta: si el dueño se va mientras el otro aun construye, el
	# piso se le pasa a el en vez de congelarse con alguien dentro.
	for id in _viajando:
		if id != salvo and int(_viajando[id]) == piso and _peers.has(id) and not es_trabajador(id):
			return id
	return 0


# Solo host: el piso en el que esta (o al que va) ese peer; -1 si no esta en ninguno.
func _piso_de(quien: int) -> int:
	if _viajando.has(quien):
		return int(_viajando[quien])
	var lugar: String = _mi_lugar if quien == 1 else str(_peers.get(quien, {}).get("lugar", ""))
	return int(lugar.substr(5)) if lugar.begins_with("piso:") else -1


# Solo host: ¿ese peer sigue realmente en ese piso? (dueño fantasma si se fue sin avisar).
func _sigue_en(quien: int, piso: int) -> bool:
	var lugar := "piso:%d" % piso
	if quien == 1:
		return _mi_lugar == lugar
	if not _peers.has(quien):
		return false
	if _viajando.has(quien):
		return int(_viajando[quien]) == piso   # va de camino: cuenta el piso AL QUE va, no el que deja
	return _peers[quien].get("lugar", "") == lugar


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
		# Ya no estoy ahi (me fui entre medias): que el host se lo pase a otro con la foto que guarda.
		if not es_host:
			_piso_asumido.rpc_id(1, piso, false)
		return
	_soy_dueno = true
	if not es_host:
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
	if not es_host:
		return
	var de := multiplayer.get_remote_sender_id()
	var pend: Dictionary = _traspasos.get(piso, {})
	if ok:
		if int(pend.get("heredero", 0)) == de:
			_traspasos.erase(piso)
		return
	if int(_dueno_piso.get(piso, 0)) == de:
		_soltar_piso(de, {})


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
	for id in enemigos._enem_nodos.keys():
		var n = enemigos._enem_nodos[id]   # SIN tipar: puede estar liberado (ver cabecera)
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
	enemigos._enemigos.clear()
	peleas._enem_ocupados.clear()   # las reservas eran de esos bichos: se van con ellos
	if not extraccion._extrayendo.is_empty():
		extraccion._extrayendo.clear()
		extraccion._difundir_extrayendo()   # y nadie debe seguir viendo esos cuerpos como ocupados


# El dueño de un piso ha cambiado: los que sigan ahi tiran sus cuerpos espejados, porque el dueño
# nuevo va a recrear los bichos con ids nuevos (si no, se verian por duplicado).
#
# MENOS los que estoy PELEANDO: el combate guarda esos nodos (Game._active_enemies) y borrarlos deja
# la pelea con referencias muertas -> la pantalla se queda colgada y el jugador NO PUEDE MOVERSE.
# Se quedan hasta que termine la pelea; al acabar, su resultado se resuelve en local (ver
# remote_enemy.morir), porque para entonces el dueño al que habria que avisar ya no esta.
@rpc("any_peer", "call_remote", "reliable")
func _limpiar_espejo() -> void:
	for id in enemigos._enem_nodos.keys():
		var n = enemigos._enem_nodos[id]
		if not is_instance_valid(n):
			enemigos._enem_nodos.erase(id)
			continue
		if Game.combate_activo() and Game._active_enemies.has(n):
			continue   # esta en mi pelea: no se toca
		n.retirar()
		enemigos._enem_nodos.erase(id)


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
	if not _mi_lugar.begins_with("piso:") or Game.current_floor != piso:
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
	_barrer_bosses()
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
	# El nonce se APUNTA, no solo se usa: es lo que hace que el sub-tier con el que acaba de brotar
	# siga siendo el mismo cuando alguien reconstruya el piso (bajar y volver a subir). Sin esto, la
	# veta que revivio de estaño profundo volvia a ser la de siempre en cuanto se rehacia la escena.
	_nonces_sesion[_sitio(piso, celda)] = nonce
	# Y FUERA DEL SAVE DEL HOST, o el sello volveria a sembrarse en la proxima expedicion y la veta
	# que acaba de revivir nacería agotada otra vez. Es lo mismo que hace _olvidar_agotado en
	# solitario. Solo el host: en el invitado ese diccionario es de SU mundo, no de este.
	if es_host:
		(Game.persistente_piso(piso)["agotados"] as Dictionary).erase(celda)
	if not _mi_lugar.begins_with("piso:") or Game.current_floor != piso:
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
	_bosses_sello[piso] = float(Encargos.ahora())
	# Acaba de caer: le queda la espera entera, y eso es lo que se manda (no el instante, ver
	# _conceder_entrada). El _marcar_boss local no toca nada, que la clave ya esta puesta arriba.
	var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
	_marcar_boss(piso, true, espera)
	_marcar_boss.rpc(piso, true, espera)
	print("[multi] jefe del piso %d abatido: vuelve en %d s" % [
		piso, roundi(float(Game.BOSS_RESPAWN.get(piso, 0.0)))])


@rpc("any_peer", "call_remote", "reliable")
func _marcar_boss(piso: int, muerto: bool, restan: float = -1.0) -> void:
	if muerto:
		# Quien MANDA la decision sigue siendo el host (esta clave puesta = el jefe esta muerto). Lo
		# que se guarda aqui es el instante EN MI RELOJ en que le tocara volver, para que el contador
		# de su sala pueda restar en local sin preguntar nada. 'restan' viene del host en segundos por
		# lo mismo que en _conceder_entrada: los relojes de pared de dos maquinas no van a la par.
		# Sin 'restan' (el jefe acaba de caer aqui mismo) la cuenta arranca entera.
		if not _bosses_sello.has(piso):
			var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
			var falta: float = espera if restan < 0.0 else restan
			_bosses_sello[piso] = float(Encargos.ahora()) - (espera - falta)
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
		# RELOJ DE PARED, el mismo que en solitario (ver Game.bosses_sello). Con tiempo_mazmorra el
		# barrido iba al ritmo de los MENUS DEL HOST: si el anfitrion tenia el hogar abierto, el jefe
		# no se rehacia para nadie. Era la mitad del "el Rey Slime tardo media hora".
		var pasado: float = float(Encargos.ahora()) - float(_bosses_sello[piso])
		if pasado < 0.0:
			_bosses_sello[piso] = float(Encargos.ahora())   # el reloj se fue atras: se reinicia
			continue
		if pasado < espera:
			continue
		_bosses_sello.erase(piso)
		_marcar_boss(piso, false)
		_marcar_boss.rpc(piso, false)
		# El TIEMPO REAL que ha pasado va en el print a proposito: si vuelve a haber una queja de "el
		# jefe no reaparece", este numero dice de un vistazo si el reloj corrio (pasado ~ espera) o si
		# el barrido estuvo parado y se puso al dia de golpe (pasado >> espera).
		print("[multi] el jefe del piso %d vuelve a estar de pie (esperaba %d s, han pasado %d)" % [
			piso, roundi(espera), roundi(pasado)])


# ¿Toca que el jefe de ese piso este de pie? Lo pregunta Game.boss_disponible cuando hay sesion.
# Es una consulta de TABLA, sin relojes: la resta la hace el host en _barrer_bosses.
func boss_disponible(piso: int) -> bool:
	return not _bosses_sello.has(piso)


# SEGUNDOS que le faltan a ese jefe, para el contador de su sala. Aqui SI se resta, tambien en el
# cliente: su entrada de _bosses_sello ya viene re-basada a su reloj (ver _marcar_boss y _entrar_ok).
# Que el numero baje solo es cosmetico; quien decide que se plante sigue siendo boss_disponible, y esa
# sigue siendo consulta de tabla contra el host.
func boss_restante(piso: int) -> float:
	if not _bosses_sello.has(piso):
		return 0.0
	var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
	return maxf(0.0, espera - (float(Encargos.ahora()) - float(_bosses_sello[piso])))


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
	_num_humanos = 1
	for pid in _peers:
		if not es_trabajador(pid):
			_num_humanos += 1
	_set_num_humanos.rpc(_num_humanos)
	_aplicar_cupo()


# Corre en los CLIENTES: el host dice cuantos humanos hay. Reajustan su equipo al cupo nuevo.
@rpc("authority", "call_remote", "reliable")
func _set_num_humanos(n: int) -> void:
	_num_humanos = n
	_aplicar_cupo()


# Ajusta MI equipo al cupo. Cada maquina se ajusta sola (todas conocen n y su rol).
#  - RECORTE: se quedan las primeras posiciones de la formacion, con la garantia del que va EN
#    CABEZA: si el cupo lo dejaria fuera, SE DESLIZA al ultimo hueco permitido desplazando al que
#    iba ahi. Los apartados van al hogar (banquillo) EN ORDEN.
#  - RESTAURACION: al bajar la gente (o cerrar sesion), los apartados vuelven en su orden.
# Se recompone el array party entero (sacar_del_equipo no desliza posiciones), reapuntando
# lider_idx a la misma persona.
#
# LA GARANTIA ES DEL LIDER, NO DEL ORIGINAL. Antes se protegia al personaje con el que empezaste la
# partida, pero eso es justo lo que el jugador pidio quitar: si en una sesion de cuatro humanos solo
# le cabe uno, ESE UNO LO ELIGE EL. Y el que ha elegido es a quien lleva en cabeza.
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
		var mantener: Array = []
		for pj in Game.party:
			if mantener.size() < cupo:
				mantener.append(pj)
		if Game.party.has(lider_pj) and not mantener.has(lider_pj):
			mantener[cupo - 1] = lider_pj   # el que llevas en cabeza se desliza al ultimo hueco
		for pj in Game.party:
			if not mantener.has(pj):
				_apartados.append(pj)
		Game.party.assign(mantener)
		# El lider siempre esta en `mantener` por la garantia de arriba, asi que el find no falla; el
		# maxi es la red por si el equipo llegara vacio a esta rama.
		Game.lider_idx = maxi(0, Game.party.find(lider_pj))

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


# El host le dice a UN cliente por que no ha podido hacer algo. Generico a proposito: el motivo lo
# escribe quien lo rechaza, que es el unico que lo sabe.
@rpc("any_peer", "call_remote", "reliable")
func _aviso_remoto(texto: String) -> void:
	peleas._aviso_esquina(texto)


# Difunde el bote a los clientes (solo si hay sesion) y refresca la UI.
func _difundir_bote() -> void:
	if activo:
		_set_bote.rpc(Game.bote_dinero)
	hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_bote(v: int) -> void:
	_bote_mirror = v   # cliente: reflejo del bote del host
	hogar_cambiado.emit()


# --- EL CUPO DEL BANNER DE NOVATO ------------------------------------------------------------
#
# 30 tiradas para TODO EL MUNDO, no por persona ni por personaje. Es el bote del hogar del reves: en
# vez de "¿hay bastante para retirar?", "¿queda cupo para gastar?". Y como todo lo que es del mundo,
# lo lleva el HOST: si cada cliente contara las suyas, dos jugadores tirando a la vez se gastarian 60.
#
# SE CONCEDE LO QUE HAYA, NO TODO O NADA. Pides x10 y quedan 3 -> te da 3, y la pantalla cobra 3. La
# otra opcion era apagar el boton del x10 al bajar de 10, y eso deja el final del cupo inalcanzable
# salvo de una en una. El que llama TIENE QUE MIRAR lo que se le concede y cobrar por eso, nunca por
# lo que pidio.
signal tiradas_novato_concedidas(n: int)


# La pantalla llama aqui y espera la señal. En solitario y de host llega en el mismo frame; de
# cliente, cuando conteste el host. Por eso se pide ANTES de cobrar: al reves, un cliente podria
# pagar 4500 y que el host le dijera que no quedan.
func pedir_tiradas_novato(n: int) -> void:
	if _soy_cliente():
		_pedir_tiradas_novato.rpc_id(1, n)
	else:
		_resolver_tiradas_novato(n, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_tiradas_novato(n: int) -> void:
	if not es_host:
		return
	_resolver_tiradas_novato(n, multiplayer.get_remote_sender_id())


# Host o solitario: cuantas de las que pide caben en lo que queda. quien=1 = yo mismo.
func _resolver_tiradas_novato(n: int, quien: int) -> void:
	var cupo: int = int(Game.banner(Game.BANNER_NOVATO).get("cupo", 0))
	var quedan: int = maxi(0, cupo - Game.tiradas_novato)
	var k: int = mini(maxi(0, n), quedan)
	if k > 0:
		# SE APUNTAN AL CONCEDER, no al tirar. El que las tiene concedidas ya las ha gastado aunque
		# tarde un segundo en darle al boton: si se apuntaran despues, dos clientes pidiendo a la vez
		# se llevarian los dos las mismas ultimas tiradas.
		Game.tiradas_novato += k
		_difundir_tiradas_novato()
	if quien == 1:
		tiradas_novato_concedidas.emit(k)
	else:
		_tiradas_novato_ok.rpc_id(quien, k)


@rpc("any_peer", "call_remote", "reliable")
func _tiradas_novato_ok(k: int) -> void:
	tiradas_novato_concedidas.emit(k)


func _difundir_tiradas_novato() -> void:
	if activo:
		_set_tiradas_novato.rpc(Game.tiradas_novato)


@rpc("authority", "call_remote", "reliable")
func _set_tiradas_novato(v: int) -> void:
	_tiradas_novato_mirror = v


# --- LA BIBLIOTECA DEL MUNDO -----------------------------------------------------------------
#
# COMUN MIENTRAS JUGAIS JUNTOS, y de cada uno al volver a su partida. Lo que lea cualquiera queda
# leido para todos: es una estanteria compartida, y si tu hermano ya se ha leido el del kebab el
# texto esta desbloqueado -- no tiene sentido que a ti te lo siga dando el gacha.
#
# NO SE PISA, SE SUMA. Es lo que hace que valga para las dos direcciones: el invitado entra con lo
# que el host tenga leido, y lo que el invitado traiga de su casa tambien queda disponible en la
# sesion. Sustituir en vez de sumar le borraria al invitado su coleccion en cuanto entrara.
#
# Lo que NO hace es quedarse: al desconectar, exportar_partida_invitado devuelve la biblioteca a como
# estaba al entrar (ver Net._congelar_mi_mundo). Una tarde con tu hermano no te completa la coleccion.
@rpc("authority", "call_remote", "reliable")
func _set_biblioteca(v: Dictionary) -> void:
	for k in v:
		Game.biblioteca[k] = true


# Alguien ha leido un tomo: se apunta en todas las estanterias de la sesion. Lo llama Game al leer
# (leer_tocho y aprender_de_grimorio), y va por el host para que el reparto sea el mismo que el del
# resto del estado del hogar.
@rpc("any_peer", "call_remote", "reliable")
func _apuntar_tomo(id: String) -> void:
	if id == "":
		return
	Game.biblioteca[StringName(id)] = true
	# El host lo reparte a los demas; un cliente solo se lo apunta. Sin esto, lo que leyera un
	# invitado solo lo sabria el host y el otro invitado seguiria recibiendolo del gacha.
	if es_host:
		_apuntar_tomo.rpc(id)


# Avisa a la sesion de que este tomo ya esta leido. Lo llama Game; aqui vive el reparto.
func apuntar_tomo_en_la_sesion(id: StringName) -> void:
	if not activo or id == &"":
		return
	if es_host:
		_apuntar_tomo.rpc(String(id))
	else:
		_apuntar_tomo.rpc_id(1, String(id))


# --- LO DESCUBIERTO EN EL MUNDO (recetas del crafteo) -----------------------------------------
#
# El herrero, el carpintero, el peletero y la boticaria enseñan lo que has VISTO (Game.material_visto).
# Eso es por persona, y en el playtest del 11/09/2026 el invitado solo veia T1 aunque el host ya forjaba
# T2. Decision del usuario: lo que descubra CUALQUIERA se desbloquea para TODOS. Mismo patron que la
# biblioteca: se SUMA, nunca se pisa, y va por el host.
#
# Lo propio de cada uno sigue en su materiales_vistos (y en su JugadorData); lo de los demas vive en
# Game.vistos_mundo, que es de la sesion. Asi nadie se lleva a su partida lo que descubrio otro.
@rpc("authority", "call_remote", "reliable")
func _set_vistos_mundo(v: Dictionary) -> void:
	for k in v:
		Game.vistos_mundo[String(k)] = true
	hogar_cambiado.emit()   # los menus de crafteo abiertos se repintan con lo nuevo


@rpc("any_peer", "call_remote", "reliable")
func _apuntar_visto(id: String) -> void:
	if id == "" or Game.vistos_mundo.has(id):
		return
	Game.vistos_mundo[id] = true
	hogar_cambiado.emit()
	if es_host:
		_apuntar_visto.rpc(id)   # el host lo reparte a los demas (en estrella no se ven entre ellos)


# Lo llama Game.descubrir cuando alguien ve un material por primera vez.
func apuntar_visto_en_la_sesion(id: String) -> void:
	if not activo or id == "":
		return
	if es_host:
		_apuntar_visto.rpc(id)
	else:
		_apuntar_visto.rpc_id(1, id)


# Todo lo que sabe el mundo, para ponerle al dia al que entra: lo mio, lo que me han contado en esta
# sesion y lo que tenga guardado cada jugador del mundo (aunque hoy no este).
func _vistos_de_todos() -> Dictionary:
	var out: Dictionary = Game.materiales_vistos.duplicate()
	for k in Game.vistos_mundo:
		out[k] = true
	for ident in Game.jugadores_mundo:
		var jd = Game.jugadores_mundo[ident]
		if jd is JugadorData:
			for k in (jd as JugadorData).materiales_vistos:
				out[k] = true
	return out


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
	# "encargo": id del encargo que la esta usando ahi abajo, o 0 si esta libre. Vive DENTRO de la
	# entrada y no en un diccionario aparte porque asi persiste y viaja gratis: cofre_equipo ya es
	# @export en SaveData y ya se difunde entero con _set_cofre.
	Game.cofre_equipo.append({"id": Game._cofre_next_id, "dict": d,
		"clase": str(d.get("clase", "arma")), "desc": str(d.get("desc", "?")), "encargo": 0})
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
	# EN USO en un encargo: no se la lleva nadie, ni el que la metio. La UI ya deshabilita el boton,
	# pero el que manda es el host: un cliente con la lista desfasada podria pedirla igual.
	if int(Game.cofre_equipo[idx].get("encargo", 0)) != 0:
		if quien == 1:
			peleas._aviso_esquina("Esa pieza está en un encargo")
		else:
			_aviso_remoto.rpc_id(quien, "Esa pieza está en un encargo")
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


# ============================================================
#  ENCARGOS (mandar gente del hogar a recolectar por reloj real)
#
#  EL HOST ES LA AUTORIDAD, y aqui no es una manía: resolver un encargo TIRA DADOS. Si lo resolviera
#  cada maquina, cada uno veria un botin distinto del mismo encargo. El host resuelve una vez y
#  difunde el resultado YA COCIDO.
#
#  Patron de siempre: la UI llama a solicitar_*(), el cliente lo manda por RPC, el host resuelve y
#  difunde la lista entera. Calcado del cofre y del bote.
# ============================================================

func solicitar_encargo(piso: int, tipos: Array, duracion: int, uids: Array, cofre_ids: Array,
		faenas: Dictionary = {}, clases: Dictionary = {}) -> void:
	if _soy_cliente():
		_pedir_encargo.rpc_id(1, piso, tipos, duracion, uids, cofre_ids, faenas, clases)
	else:
		# El host tambien pasa por la aduana: el que se le puede haber ido del selector es un
		# personaje DEL COMPAÑERO, y eso Game.enviar_encargo no lo sabe mirar (su party es la de aqui).
		if activo:
			var motivo: String = _motivo_no_disponible(uids)
			if not motivo.is_empty():
				peleas._toast(motivo)
				_difundir_hogar()
				return
		if Game.enviar_encargo(piso, tipos, duracion, uids, cofre_ids, faenas, clases) != 0:
			_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_encargo(piso: int, tipos: Array, duracion: int, uids: Array, cofre_ids: Array,
		faenas: Dictionary = {}, clases: Dictionary = {}) -> void:
	if not es_host:
		return
	var quien: int = multiplayer.get_remote_sender_id()
	# ¿SIGUEN LIBRES? El cliente pinta con el roster que le llego, y entre su clic y este RPC su
	# compañero ha podido meter a ese personaje en su equipo. Se comprueba contra el roster EN VIVO,
	# que es la unica verdad, y se le redifunde el hogar para que su selector se repinte con ella.
	var motivo: String = _motivo_no_disponible(uids)
	if not motivo.is_empty():
		_aviso_remoto.rpc_id(quien, motivo)
		_difundir_hogar()
		return
	# enviar_encargo revalida la clase contra el equipo real: lo que mande el cliente es una peticion.
	var id: int = Game.enviar_encargo(piso, tipos, duracion, uids, cofre_ids, faenas, clases)
	if id == 0:
		_aviso_remoto.rpc_id(quien, "No se pudo mandar ese encargo.")
		return
	# Quien lo manda es el que lo pidio, no el host: es quien puede traerlos de vuelta.
	var e: Dictionary = Game.encargo_por_id(id)
	if not e.is_empty():
		e["quien_manda"] = _identidad_de_peer(quien)
	_difundir_hogar()


# SOLO HOST: ¿se puede mandar a toda esa gente AHORA? Devuelve "" si si, y si no, el motivo con el
# nombre del que falla (que es lo que el jugador necesita para entenderlo).
#
# Se construye el roster UNA vez y se indexa: es la misma foto para los N uids, asi que no puede
# contestar que si a uno y que no a otro por haberse movido algo entre medias.
func _motivo_no_disponible(uids: Array) -> String:
	var por_uid: Dictionary = {}
	for f in _construir_roster():
		por_uid[String((f as Dictionary).get("uid", ""))] = f
	for u in uids:
		var fila = por_uid.get(String(u))
		if fila == null:
			return "Uno de los elegidos ya no está en el hogar."
		var d := fila as Dictionary
		if bool(d.get("en_equipo", false)):
			return "%s ya no está disponible: lo han metido en su equipo." % String(d.get("nombre", "?"))
		if bool(d.get("de_encargo", false)):
			return "%s ya no está disponible: se ha ido de encargo." % String(d.get("nombre", "?"))
	return ""


func solicitar_traer_encargo(id: int) -> void:
	if _soy_cliente():
		_pedir_traer_encargo.rpc_id(1, id)
	else:
		if Game.traer_encargo(id):
			_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_traer_encargo(id: int) -> void:
	if es_host and Game.traer_encargo(id):
		_difundir_hogar()


# DEV (temporal): terminar UNO al 100%, como si hubiera pasado su tiempo entero. Va por la red como
# los demas para que tambien sirva probando en multi.
func solicitar_dev_terminar_encargo(id: int) -> void:
	if _soy_cliente():
		_pedir_dev_terminar_encargo.rpc_id(1, id)
	elif Game.dev_terminar_encargo(id):
		_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_dev_terminar_encargo(id: int) -> void:
	if es_host and Game.dev_terminar_encargo(id):
		_difundir_hogar()


func solicitar_recoger_encargo(id: int) -> void:
	if _soy_cliente():
		_pedir_recoger_encargo.rpc_id(1, id)
	else:
		var inf: Dictionary = Game.recoger_encargo(id)
		if not inf.is_empty():
			_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_recoger_encargo(id: int) -> void:
	if not es_host:
		return
	var inf: Dictionary = Game.recoger_encargo(id)
	var quien: int = multiplayer.get_remote_sender_id()
	if inf.is_empty():
		return
	if bool(inf.get("ocupado", false)):
		_aviso_remoto.rpc_id(quien, "El taller está ocupado: inténtalo en un momento.")
		return
	_aviso_remoto.rpc_id(quien, "Han vuelto: %d material(es) al almacén." % int(inf.get("materiales", 0)))
	_difundir_hogar()


# Repasar (¿ha vencido alguno?). Lo pide la UI al abrir el Hogar; en cliente se lo pide al host,
# que es el unico que puede resolver.
func pedir_repasar_encargos() -> void:
	if _soy_cliente():
		_pedir_repaso_encargos.rpc_id(1)
	elif Game.repasar_encargos() > 0:
		_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_repaso_encargos() -> void:
	if es_host and Game.repasar_encargos() > 0:
		_difundir_hogar()


# UNA sola difusion para las tres cosas del hogar que van juntas (encargos, cofre y roster), en
# ORDEN FIJO. Publicar dos valores distintos del mismo estado en un mismo rebuild es lo que cuelga
# al invitado, asi que el roster se construye UNA vez y se manda esa copia.
func _difundir_hogar() -> void:
	if activo and es_host:
		var roster: Array = _construir_roster()
		_set_encargos.rpc(Game.encargos)
		_set_cofre.rpc(Game.cofre_equipo)
		_set_roster_hogar.rpc(roster)
		_roster_mirror = roster
	hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_encargos(lista: Array) -> void:
	_encargos_mirror = lista
	# EL ENCARGO GANA, EL EQUIPO CEDE. Si uno de los MIOS acaba de salir de encargo, se va del
	# equipo aqui mismo. Es lo que hace _aplicar_cupo con el cupo de sesion: nada de handshakes,
	# gana el estado que difunde el host y cada maquina se ajusta sola.
	for pj in Game.plantilla.duplicate():
		if Game.party.has(pj) and Game.esta_de_encargo(pj):
			Game.sacar_del_equipo(pj)
	hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_roster_hogar(lista: Array) -> void:
	_roster_mirror = lista
	hogar_cambiado.emit()


# QUIEN HAY EN EL HOGAR, de todos los jugadores. Solo lectura: lo justo para pintar la fila y decidir
# si se le puede mandar. El invitado no tiene los PersonajeData de su compañero (Game.jugadores_mundo
# esta vacio en su maquina a proposito), asi que sin esto no podria mandar a nadie que no sea suyo.
func _construir_roster() -> Array:
	var out: Array = []
	# Los mios, calculados aqui: mi party es la de verdad.
	for pj in Game.plantilla:
		if String(pj.uid).is_empty():
			push_warning("[hogar] %s no tiene uid: fuera del selector de encargos" % pj.nombre)
			continue   # sin uid no se le puede mandar ni cobrar: es el personaje fantasma
		out.append(_fila_roster(pj, Identidad.id, Identidad.nombre))
	# Y los de los demas. Si su dueño esta conectado, sus filas llegan EN VIVO (_roster_ajeno); si no
	# —desconectado—, se sacan de la foto de jugadores_mundo, que para alguien que no esta jugando es
	# perfectamente buena.
	for id in Game.jugadores_mundo:
		var jd: JugadorData = Game.jugadores_mundo[id]
		if jd == null:
			continue
		if _roster_ajeno.has(id):
			for f in (_roster_ajeno[id] as Array):
				var fila: Dictionary = (f as Dictionary).duplicate()
				# 'de_encargo' lo sella el HOST y solo el: Game.encargos vive aqui, y el dueño no puede
				# saber si a uno suyo lo ha mandado ya el compañero.
				fila["de_encargo"] = Game.uid_de_encargo(String(fila.get("uid", ""))) != 0
				if String(fila.get("dueno_nombre", "")).is_empty():
					fila["dueno_nombre"] = jd.nombre_visible
				out.append(fila)
			continue
		for pj in jd.personajes:
			if pj is PersonajeData and not String((pj as PersonajeData).uid).is_empty():
				out.append(_fila_roster(pj as PersonajeData, String(jd.id), jd.nombre_visible))
	return out


# MIS filas del hogar, para mandarselas al host. Las calculo YO porque soy el unico que tiene mi
# party y mi equipo puesto (de ahi salen Encargos.poder, las stats de efecto y las clases).
# 'de_encargo' va como venga: lo pisa el host al construir el roster, que es quien tiene Game.encargos.
func _mis_filas_hogar() -> Array:
	var out: Array = []
	for pj in Game.plantilla:
		if String(pj.uid).is_empty():
			continue
		out.append(_fila_roster(pj, Identidad.id, Identidad.nombre))
	return out


# Mi hogar ha cambiado (he metido o sacado a alguien del equipo, o he fichado). No manda nada aqui:
# lo agrupa _process. Lo llaman Game.meter_en_equipo / sacar_del_equipo / fichar, que son el embudo
# por el que pasan las teclas, la taberna, el Hogar y el cupo de sesion.
func marcar_hogar_sucio() -> void:
	if activo:
		_hogar_sucio = true


# Corre en EL HOST: un jugador me dice como esta su hogar AHORA.
@rpc("any_peer", "call_remote", "reliable")
func _mi_hogar(filas: Array) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	var identidad: String = _identidad_de_peer(quien)
	if identidad.is_empty():
		return
	var limpias: Array = []
	for f in filas:
		var fila := (f as Dictionary).duplicate()
		if String(fila.get("uid", "")).is_empty():
			continue
		# El dueño NO se cree lo que venga en el paquete: se pone el de quien lo manda. Mismo criterio
		# que en el resto de altas — si no, cualquiera podria colar filas a nombre de otro.
		fila["dueno"] = identidad
		limpias.append(fila)
	# Si no ha cambiado nada, NO se redifunde. Es la otra mitad del cerrojo del bucle: sin esto, dos
	# clientes en la misma sala se turnarian difundiendose para siempre.
	if _roster_ajeno.get(identidad) == limpias:
		return
	_roster_ajeno[identidad] = limpias
	_difundir_hogar()


func _fila_roster(pj: PersonajeData, dueno: String, dueno_nombre: String) -> Dictionary:
	# En_equipo se mira contra el equipo de SU dueño. Para los mios es Game.party; para los demas,
	# el `equipo` de su JugadorData, que puede ir hasta 60 s desfasado -- por eso la regla es que el
	# encargo gana y el equipo cede (ver _set_encargos) en vez de fiarse de este dato.
	var en_equipo: bool = Game.party.has(pj)
	if dueno != Identidad.id:
		var jd: JugadorData = Game.jugadores_mundo.get(dueno)
		en_equipo = jd != null and jd.equipo.has(pj)
	return {
		"uid": String(pj.uid), "nombre": pj.nombre, "level": pj.level,
		"dueno": dueno, "dueno_nombre": dueno_nombre,
		"en_equipo": en_equipo, "de_encargo": Game.esta_de_encargo(pj),
		# El poder viaja YA CALCULADO (el invitado no tiene el equipo del compañero para sacarlo) y
		# las STATS DE EFECTO van sueltas, porque el pronostico de recoleccion necesita la stat del
		# oficio persona a persona. Son cinco numeros: sale mas barato que pedirselas al host cada
		# vez que marcas una casilla.
		# TIENEN que ser las MISMAS que usa Encargos.poder_recolector al resolver (consolidado + su
		# plato): si aqui viajara otra cosa, el invitado veria una calidad prevista y le llegaria otra.
		"poder": int(round(Encargos.poder(pj))),
		"stats": {
			"fuerza": Game.stat_consolidado_eff("fuerza", pj),
			"resistencia": Game.stat_consolidado_eff("resistencia", pj),
			"destreza": Game.stat_consolidado_eff("destreza", pj),
			"agilidad": Game.stat_consolidado_eff("agilidad", pj),
			"magia": Game.stat_consolidado_eff("magia", pj),
		},
		# Las CLASES de combate que puede elegir hoy, tambien ya calculadas. Salen de lo que lleve
		# puesto (escudo, dagas, magias...) y el invitado no tiene su equipo, asi que si no viajan aqui
		# el desplegable de clase le sale vacio o mentiroso para los personajes del compañero.
		"clases": Encargos.clases_de(pj),
		"color": pj.color,
	}


# Lo que la UI del hogar tiene que listar como "gente disponible". En solitario se construye al
# vuelo; de cliente, el reflejo de lo que mando el host.
func roster_hogar() -> Array:
	if _soy_cliente():
		return _roster_mirror
	return _construir_roster()


func _identidad_de_peer(peer: int) -> String:
	return String(_identidades.get(peer, ""))


# El peer de una identidad, o 0 si no esta conectada. Es lo que decide cual de las DOS VIAS de la
# excelia se toma (ver Game.recoger_encargo): mandarsela, o escribirla en su JugadorData.
func peer_de_identidad(identidad: String) -> int:
	if identidad.is_empty() or not activo:
		return 0
	for peer in _identidades:
		if String(_identidades[peer]) == identidad:
			return int(peer)
	return 0


# El host le manda a un jugador la excelia que se han ganado SUS personajes en un encargo.
func mandar_excelia(identidad: String, entradas: Array) -> void:
	var peer: int = peer_de_identidad(identidad)
	if peer != 0:
		_set_excelia_encargo.rpc_id(peer, entradas)


# Corre en el DUEÑO. Aplica lo suyo a sus propios PersonajeData: son los unicos autoritativos.
@rpc("authority", "call_remote", "reliable")
func _set_excelia_encargo(entradas: Array) -> void:
	var tocados: int = 0
	for g in entradas:
		var d := g as Dictionary
		var pj: PersonajeData = Game.pj_por_uid(String(d.get("uid", "")))
		if pj == null:
			# Puede pasar si el save de este jugador es anterior al uid y el backfill le puso otro.
			# Se avisa en vez de callarlo: perder excelia en silencio es de lo peor que puede hacer
			# un sistema que tarda ocho horas en dar su premio.
			push_warning("[encargos] llega excelia para un uid que no tengo: %s" % String(d.get("uid", "")))
			continue
		Game.ganar(String(d["abil"]), float(d["reto"]), float(d["base"]), float(d["max_reto"]), pj)
		tocados += 1
	if tocados > 0:
		peleas._aviso_esquina("Los tuyos han vuelto de un encargo")


# Y el PARTE DE TRABAJO: las pasivas RNG y los contadores ocultos de los desarrollos. Va por su
# propio RPC pero por la MISMA via y el mismo motivo que la excelia — solo esta maquina tiene sus
# PersonajeData. Si esto solo se enganchara en Game.recoger_encargo, el compañero conectado se
# quedaria sin pasivas y sin contadores y no habria ni un error que lo dijera.
func mandar_partes_encargo(identidad: String, partes: Array) -> void:
	var peer: int = peer_de_identidad(identidad)
	if peer != 0:
		_set_partes_encargo.rpc_id(peer, partes)


@rpc("authority", "call_remote", "reliable")
func _set_partes_encargo(partes: Array) -> void:
	for p in partes:
		var parte := p as Dictionary
		var pj: PersonajeData = Game.pj_por_uid(String(parte.get("uid", "")))
		if pj == null:
			push_warning("[encargos] llega un parte de trabajo para un uid que no tengo: %s"
				% String(parte.get("uid", "")))
			continue
		Game.aplicar_parte_encargo(parte, int(parte.get("piso", 1)), pj)


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
		out.append(suelo._item_a_dict(m))
	return out


func _cargar_almacen(arr: Array) -> void:
	var lista: Array[MaterialItem] = []
	for d in arr:
		var it := suelo._item_de_dict(d)
		if it is MaterialItem:
			lista.append(it)
	Game.almacen_materiales = lista


# La llama un menu de taller (herrero/carpintero/boticaria/peletero) al abrir, o una accion
# suelta (depositar/vender del hogar) antes de tocar el baul. true = tienes el taller y tu
# Game.almacen_materiales YA es el baul autoritativo; false = esta ocupado por tu companero.
# ¿Lo tiene prestado OTRO? Solo el host puede preguntarlo con sentido (es quien arbitra el candado).
# Lo usa el cobro de un encargo para no pisar el almacen comun mientras alguien craftea.
func taller_ocupado() -> bool:
	return activo and es_host and _taller_dueno != 0 and _taller_dueno != 1


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


# ============================================================
#  UN PERSONAJE DE VERDAD (no el doble de combate) Y SU JUGADOR
#  ficha_a_dict/ficha_de_dict son el DOBLE: mandan lo justo para pelear, viajan en CADA union a una
#  pelea y traen el equipo SIN registrar a proposito (el bug de las 6 hachas). No se tocan.
#
#  Esto es lo otro: mandar a una PERSONA para que VIVA en un mundo que no esta en su disco. Va una
#  vez al entrar y otra al guardar, asi que puede permitirse ser fiel. Lo que el doble no lleva y
#  aqui es imprescindible:
#    es_original          el personaje de referencia DE ESA PERSONA (a quien se recurre si no queda nadie)
#    dueno                de quien es (ver personaje_data.gd)
#    rol                  su kit y su ficha
#    pasivas_pendientes   una tirada de 1 entre 500.000 sin leer; perderla seria una crueldad
#  Y su equipo se deserializa REGISTRANDO: en un mundo compartido el baul del mundo es la casa de
#  esos objetos, no un prestamo para una pelea.
# ------------------------------------------------------------
# OJO: esta lista es FIJA. Un campo permanente de PersonajeData que no este aqui funciona perfecto en
# solitario y desaparece SOLO en multi, que es de las averias mas caras de encontrar. `uid` esta aqui
# porque los ENCARGOS apuntan a la gente por uid y se cobran horas despues, quiza en otra maquina.
const _PERMANENTES := ["es_original", "rol", "dueno", "pasivas_pendientes", "uid"]


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
		var m: Dictionary = suelo._item_a_dict(it)
		if not m.is_empty():
			bolsa.append(m)
	var cris: Array = []
	for it in jd.crystals:
		var c: Dictionary = suelo._item_a_dict(it)
		if not c.is_empty():
			cris.append(c)
	var carbonera: Array = []
	for it in jd.carbon:
		var cb: Dictionary = suelo._item_a_dict(it)
		if not cb.is_empty():
			carbonera.append(cb)
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
		"cuchillo": Game.serializar_equipo(jd.equipped_cuchillo),
		# EL FAROLILLO Y SU CARBON. No viajaban: cada autoguardado del mundo escribia al invitado sin
		# lampara, sin carbonera y sin la llama que llevaba encendida, y al volver a entrar se lo
		# encontraba a oscuras (playtest del 11/09/2026). El cebo tampoco venia.
		"lampara": Game.serializar_equipo(jd.equipped_lampara),
		"carbon": carbonera,
		"lampara_llama": jd.lampara_llama, "lampara_llama_total": jd.lampara_llama_total,
		"cebo": jd.cebo,
		"registro_pesca": jd.registro_pesca.duplicate(true),
		"mezcla": jd.mezcla_exp, "metalurgia": jd.metalurgia_exp,
		"peleteria": jd.peleteria_exp, "herreria": jd.herreria_exp,
		"carpinteria": jd.carpinteria_exp, "cocina": jd.cocina_exp,
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
		var it: Resource = suelo._item_de_dict(m as Dictionary)
		if it != null:
			jd.materiales.append(it)
	jd.crystals = []
	for c in d.get("crystals", []):
		var it2: Resource = suelo._item_de_dict(c as Dictionary)
		if it2 != null:
			jd.crystals.append(it2)
	jd.carbon = []
	for cb in d.get("carbon", []):
		var it3: Resource = suelo._item_de_dict(cb as Dictionary)
		if it3 != null:
			jd.carbon.append(it3)
	jd.lampara_llama = float(d.get("lampara_llama", 0.0))
	jd.lampara_llama_total = float(d.get("lampara_llama_total", 0.0))
	jd.cebo = String(d.get("cebo", ""))
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
			["cana", "equipped_cana"], ["cuchillo", "equipped_cuchillo"], ["lampara", "equipped_lampara"]]:
		var t: Resource = Game.deserializar_equipo(d.get(String(par[0]), {}), registrar)
		if t is ToolData:
			jd.set(String(par[1]), t)
			jd.owned_tools.append(t)
	jd.registro_pesca = (d.get("registro_pesca", {}) as Dictionary).duplicate(true)
	jd.mezcla_exp = float(d.get("mezcla", 0.0))
	jd.metalurgia_exp = float(d.get("metalurgia", 0.0))
	jd.peleteria_exp = float(d.get("peleteria", 0.0))
	jd.herreria_exp = float(d.get("herreria", 0.0))
	jd.carpinteria_exp = float(d.get("carpinteria", 0.0))
	jd.cocina_exp = float(d.get("cocina", 0.0))
	jd.materiales_vistos = (d.get("materiales_vistos", {}) as Dictionary).duplicate()
	jd.pack_inicial = bool(d.get("pack_inicial", false))
	jd.en_mazmorra = bool(d.get("en_mazmorra", false))
	jd.current_floor = maxi(1, int(d.get("current_floor", 1)))
	jd.pos = d.get("pos", Vector2.ZERO)
	jd.fecha_visto = Time.get_datetime_string_from_system(false, true)
	return jd


func ficha_a_dict(pj: PersonajeData) -> Dictionary:
	var d := {}
	for campo in ["nombre", "color", "metalico", "imagen", "color_alpha", "aspecto", "level",
			"ability_internal", "ability_consolidado", "ability_base_nivel",
			"fuerza", "resistencia", "destreza", "agilidad", "magia",
			"base_hp", "base_attack", "base_defense", "base_magic", "base_speed",
			"base_mp", "base_magia_factor", "base_crit",
			"current_hp", "current_mp", "stamina",
			"desarrollos_rango", "pasivas_rng", "guardianes_vencidos",
			"esquivas_exp", "hechizos_exp", "recitado_exp",
			"dano_recibido_exp", "dano_infligido_exp", "dano_bloqueado_exp"]:
		d[campo] = pj.get(campo)
	# Y su pocion a medias, para que el anfitrion pueda meterla en la pelea (ver _COLAS_POCION), y lo
	# que lleve puesto: estados, cargas de Foco e imbuicion (ver _LO_PUESTO).
	for campo in peleas._COLAS_POCION + peleas._LO_PUESTO:
		d[campo] = pj.get(campo)
	var sin_viajar: Array = []
	for r in peleas._RANURAS:
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
	# CON LOS HUECOS, y el hueco viaja como "". El set de magias guarda la RANURA de cada una (ver
	# Game._set_hechizos), asi que saltarse los null aqui corria las magias del doble una posicion:
	# el clasico campo que se pierde solo en multi y no da ningun error.
	var hechizos: Array = []
	for s in Game.hechizos_con_huecos(pj):
		if s != null and not String(s.resource_path).is_empty():
			hechizos.append(s.resource_path)
		else:
			hechizos.append("")
	d["spells"] = hechizos
	# Y los que SABE, que no son los mismos desde que aprender dejo de tener tope: sin mandarlos, al
	# otro lado el doble llega sin lista de sabidos y su pantalla de magias sale vacia -- no podria
	# volver a ponerse uno que se acaba de quitar. Es justo el fallo que solo se ve en multi.
	var sabidos: Array = []
	for s in Game.hechizos_sabidos(pj):
		if s != null and not String(s.resource_path).is_empty():
			sabidos.append(s.resource_path)
	d["spells_sabidos"] = sabidos
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
	# AGOTAMIENTO (correr sin fuelle) y COOLDOWNS pendientes de sus habilidades. Los dos duran ENTRE
	# combates y los dos se perdian al unirse a la pelea de otro: el doble entraba descansado y con
	# los CD a cero. Van aqui, no en _LO_PUESTO, porque no son campos de la ficha (uno es una meta y
	# el otro vive en Game.ability_cooldowns_persist). Los CD viajan por RUTA, ver Game.cds_a_rutas.
	d["sin_fuelle"] = bool(pj.get_meta("sin_fuelle", false))
	d["cds"] = Game.cds_a_rutas(Game.ability_cooldowns_persist.get(pj, {}))
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
		if campo == "spells" or campo == "habs_sabidas" or campo == "habs_sets" or peleas._RANURAS.has(campo):
			continue
		pj.set(campo, d[campo])
	for r in peleas._RANURAS:
		var item: Resource = Game.deserializar_equipo(d.get(r, {}), registrar)
		if item != null:
			pj.set(r, item)
			# Y su meta EQUIPADA apuntando al MISMO dict que la del objeto. Sin esto el doble
			# llevaba el arma pero con tier 1 y rareza comun: la identidad la lee equip_meta[slot]
			# (ver Game._meta), no el objeto. Es la misma invariante que restaura
			# _realinear_equip_meta al cargar una partida.
			pj.equip_meta[r.replace("equipped_", "")] = Game.meta_de(item)
	# El "" es un hueco VACIO y se restaura como tal: las ranuras del doble son las del original.
	# Una ficha vieja llega compacta y sin "": entra tal cual y Game._set_hechizos la rellena de
	# huecos por detras, que es exactamente lo que era.
	var hechizos: Array = []
	for ruta in d.get("spells", []):
		var s = load(String(ruta)) if not String(ruta).is_empty() else null
		hechizos.append(s)
	pj.equipped_spells = hechizos
	# Los SABIDOS. Una ficha de una version anterior no trae la clave: se queda vacia y
	# Game.hechizos_sabidos la reconstruye desde los equipados, que es lo que habia antes.
	var sabidos: Array = []
	for ruta in d.get("spells_sabidos", []):
		var s2 = load(String(ruta))
		if s2 != null:
			sabidos.append(s2)
	pj.hechizos_aprendidos = sabidos
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
	# Lo que no es campo de la ficha, en metas (ver ficha_a_dict): las lee Game al meterlo en la
	# pelea. Los cooldowns siguen aqui en RUTAS; se traducen al aplicarlos.
	pj.set_meta("sin_fuelle", bool(d.get("sin_fuelle", false)))
	pj.set_meta("cds", d.get("cds", {}))
	return pj


# Lo que el doble ha vivido en la pelea, para devolverselo a su dueño.
func desgaste_a_dict(pj: PersonajeData) -> Dictionary:
	var d := {}
	for campo in peleas._VUELVE:
		var v = pj.get(campo)
		# COPIA, no referencia. Los tres dicts de habilidad y los estados son objetos: metidos a pelo,
		# el lote apunta al MISMO dict de la ficha, asi que cualquier cambio posterior lo reescribe por
		# detras. Por red no se nota (el RPC serializa), pero en local el lote mentia.
		d[campo] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	# DE QUIEN ES ESTE LOTE. Va aparte de _VUELVE a proposito: el uid identifica, no se aplica (si
	# entrara en el bucle de arriba, aplicar_desgaste se lo escribiria encima al de casa).
	#
	# Antes el lote no llevaba identidad ninguna y el dueño lo cruzaba POR POSICION con su formacion
	# (ver _devolver_desgaste). Un solo puesto de desfase no "suma mal": COPIA un personaje entero
	# encima de otro -- excelia, nivel, las cinco stats, vida y contadores.
	d["uid"] = String(pj.uid)
	# Los COOLDOWNS que le queden al doble: van APARTE de _VUELVE porque no son un campo de la ficha
	# (viven en Game.ability_cooldowns_persist, ver Game.cds_a_rutas). Si no vuelven, el que se une a
	# la pelea de otro sale de ella con todas sus habilidades listas. Mientras se pelea los buenos
	# son los del COMBATIENTE (el dict de Game solo tiene los de la entrada): asi tambien salen bien
	# si se marcha a mitad, que es el otro camino que pasa por aqui.
	var vivo: Combatant = Game.combatant_de_pj(pj)
	d["cds"] = Game.cds_a_rutas(vivo.ability_cooldowns if vivo != null \
		else Game.ability_cooldowns_persist.get(pj, {}))
	return d


# LO QUE SOLO SUBE se funde por MAXIMO; lo demas se asigna.
#
# La excelia y los contadores ocultos nunca bajan, asi que si lo que llega es MENOR que lo que ya
# tengo, lo que llega esta rancio y hay que ignorarlo. Asignar a pelo tenia dos formas de perder
# progreso de verdad:
#   - la excelia de un ENCARGO que aterriza mientras espejo una pelea (Net._set_excelia_encargo
#     escribe en el PersonajeData real) se borraba al cerrarse la pelea;
#   - cualquier lote rezagado o repetido revertia lo ganado desde que se mando la ficha.
# Con el maximo, el peor caso de un paquete raro es que no aporte nada, nunca que reste.
const _SOLO_SUBEN := ["esquivas_exp", "hechizos_exp", "recitado_exp",
	"dano_recibido_exp", "dano_infligido_exp", "dano_bloqueado_exp"]
const _DICTS_HABILIDAD := ["ability_internal", "ability_consolidado", "ability_base_nivel"]

func aplicar_desgaste(pj: PersonajeData, d: Dictionary) -> void:
	for campo in peleas._VUELVE:
		if not d.has(campo):
			continue
		if campo in _DICTS_HABILIDAD:
			pj.set(campo, _fundir_maximo(pj.get(campo), d[campo]))
		elif campo in _SOLO_SUBEN:
			pj.set(campo, maxf(float(pj.get(campo)), float(d[campo])))
		else:
			pj.set(campo, d[campo])
	if d.has("cds"):
		Game.ability_cooldowns_persist[pj] = Game.cds_de_rutas(d["cds"] as Dictionary)
	# Los estados vuelven como datos, pero lo que el mapa lee de ellos (cuanto te frenan, sus chips)
	# esta CACHEADO en la ficha: sin recalcularlo, el que se une a una pelea salia con el Pegajoso
	# puesto y andando a velocidad normal, y sin chips que lo dijeran.
	Game.refrescar_cache_estados(pj)


# Dos dicts de habilidad, quedandose con el mayor de cada stat. Las claves que solo esten en uno de
# los dos entran tal cual: un peer de otra version puede no traerlas todas.
func _fundir_maximo(mio_, suyo_) -> Dictionary:
	var mio := (mio_ if mio_ is Dictionary else {}) as Dictionary
	var suyo := (suyo_ if suyo_ is Dictionary else {}) as Dictionary
	var out: Dictionary = mio.duplicate()
	for k in suyo:
		out[k] = maxf(float(mio.get(k, 0.0)), float(suyo[k]))
	return out


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
		# Los ENCARGOS son del mundo, igual que el cofre: los del host apuntan a gente y herramientas
		# que en mi partida no existen, asi que los mios se apartan y vuelven al desconectar.
		"encargos": Game.encargos.duplicate(true),
		"encargo_next_id": Game._encargo_next_id,
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
		# LA BIBLIOTECA con la que entre. Mientras dure la sesion es COMUN (lo que lea uno vale para
		# todos, ver _set_biblioteca), pero al salir cada uno recupera la suya: una tarde jugando con
		# tu hermano no te puede completar media coleccion. Es lo mismo que se hace con los bosses y
		# con los materiales conocidos.
		"biblioteca": Game.biblioteca.duplicate(),
		# El cupo del novato de MI mundo. Mientras juegue de invitado gasto el del host, y este vuelve
		# intacto al salir (Game.exportar_partida_invitado).
		"tiradas_novato": Game.tiradas_novato,
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
	_estados_pedidos = _peers.keys().filter(func(pid): return not es_trabajador(pid))
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
	if es_host or soy_trabajador:
		return
	_mi_estado.rpc_id(1, jd_a_dict(Game.mi_jugador_data()))
	if not cerrando:
		peleas._aviso_esquina("Partida guardada")
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
			for r in peleas._RANURAS:
				_olvidar_meta_item((pj as PersonajeData).get(r))
	_olvidar_meta_item((jd as JugadorData).equipped_mochila)
	for t in [(jd as JugadorData).equipped_pico, (jd as JugadorData).equipped_hoz,
			(jd as JugadorData).equipped_hacha, (jd as JugadorData).equipped_cana,
			(jd as JugadorData).equipped_cuchillo, (jd as JugadorData).equipped_lampara]:
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
	guardado_respondido.emit(ok)
	if not ok:
		peleas._toast("El anfitrión no ha podido guardar: tu partida tampoco se ha guardado.")


# Corre en el INVITADO: guarda en SU ranura, en el pueblo de SU mundo.
@rpc("authority", "call_remote", "reliable")
func _guardar_ahora(cerrando: bool = false) -> void:
	# El guardado en si lo hace Game (es quien habla con Perfil): si net.gd llamara a Perfil se cerraria
	# un ciclo net -> Perfil -> Game -> net y GDScript deja de inferir los tipos de Game.* aqui dentro.
	var ok: bool = Game.guardar_partida_invitado()
	if not cerrando:
		# El exito es rutina (va a la esquina); el FALLO si es una noticia y sale en grande.
		if ok:
			peleas._aviso_esquina("Partida guardada")
		else:
			peleas._toast("El anfitrión ha guardado, pero tu partida NO se pudo guardar.")
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
	if soy_trabajador:
		_trab.saludar()   # sin partida, sin aspecto y sin codigo: con el token de su host
		return
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

	# Sus PIEZAS (pelo y ropa) van con el resto del aspecto. En un mundo compartido todavia no hay
	# personaje, asi que ahi salen vacias y las buenas llegan luego con _listo.
	var pzs: Dictionary = {} if mundo_compartido else Game.lider().aspecto_completo()["piezas"]
	_esperar_respuesta()
	_saludar.rpc_id(1, _codigo, PROTOCOLO, Identidad.id, Identidad.nombre,
		col, met, nom, _mi_lugar, png, alp, pzs)


# EL PLAZO. Si el host es de otro build, su _saludar tiene otra firma y Godot tira el paquete SIN
# error: sin esto, el jugador se queda mirando "Validando codigo..." para siempre.
var _respondio := false
# Cada intento de entrar lleva su numero. El plazo de un intento VIEJO (salir y volver a entrar en
# menos de _PLAZO_SALUDO) veia el _respondio del nuevo a false y cortaba la conexion buena.
var _intento_saludo: int = 0

func _esperar_respuesta() -> void:
	_respondio = false
	_intento_saludo += 1
	var intento: int = _intento_saludo
	await get_tree().create_timer(_PLAZO_SALUDO).timeout
	if intento != _intento_saludo or _respondio or not activo or es_host:
		return
	estado_cambiado.emit("El anfitrión no contesta. Lo más probable es que no coincida la versión "
		+ "del juego: tenéis que ser el mismo build.")
	desconectar()


# Corre EN EL HOST, llamado por el cliente. Valida el codigo y, si vale, se registran
# mutuamente; si no, se echa al que intenta colarse.
@rpc("any_peer", "call_remote", "reliable")
func _saludar(codigo: String, protocolo: int, identidad: String, nombre_visible: String,
		color: Color, metal: float, nombre: String, lugar: String,
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0,
		piezas: Dictionary = {}) -> void:
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
	_admitir(quien, color, metal, nombre, lugar, imagen, alpha, piezas)


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
		imagen: PackedByteArray, alpha: float, piezas: Dictionary = {}) -> void:
	_en_la_puerta.erase(quien)
	# Presentaciones cruzadas con los que YA estaban (roster): antes de registrar al
	# nuevo, para no presentarselo a si mismo. Cada cliente que ya estaba se entera del nuevo, y al
	# nuevo se le pasa la lista entera. Sin esto, dos clientes serian invisibles entre si.
	for otro in _peers:
		var p: Dictionary = _peers[otro]
		# Al que ya estaba: aqui viene uno nuevo. Tambien a los TRABAJADORES: sus bichos tienen que verle.
		_presentar_ajeno.rpc_id(otro, quien, color, metal, nombre, lugar, imagen, alpha, [], piezas)
		# Al nuevo NO se le presenta un trabajador: no es nadie a quien ver.
		if es_trabajador(otro):
			continue
		# Al nuevo: este otro ya estaba (con SUS datos, sequito incluido).
		_presentar_ajeno.rpc_id(quien, otro, p["color"], p["metal"], p["nombre"], p["lugar"],
			p.get("imagen", PackedByteArray()), float(p.get("alpha", 1.0)), p.get("comps", []),
			p.get("piezas", {}))
	# Presentarme al nuevo (registra al HOST en su _peers) ANTES de registrarle yo: _registrar_peer
	# dispara mi anunciar_grupo(), y si su _set_grupo llegara antes que este _presentarse, el cliente
	# aun no me tendria en _peers y lo tiraria en la puerta (mi sequito no le apareceria). Viaja la
	# SEMILLA del mundo del host (para generar la MISMA mazmorra sin replicar geometria) y mi lugar.
	_presentarse.rpc_id(quien, Game.player_color, Game.player_metalico, Game.player_nombre,
		_mi_lugar, Game.semilla_mundo, Game.tienda_t2_abierta(), Game.player_imagen_png,
		Game.player_color_alpha, PackedInt32Array(Game.pisos_desbloqueados()),
		Game.lider().aspecto_completo()["piezas"])
	# Registro mutuo (en el host): apunta al nuevo y me re-anuncia el grupo a todos, el ya incluido.
	_registrar_peer(quien, color, metal, nombre, lugar, imagen, alpha, true, piezas)
	estado_cambiado.emit("%s se ha unido." % nombre)
	# Y ponerle al dia el SUELO de su lugar: lo que ya estaba soltado antes de que entrara.
	for id in suelo._suelo:
		if suelo._suelo[id]["lugar"] == lugar:
			suelo._spawn_drop.rpc_id(quien, id, suelo._suelo[id]["d"], suelo._suelo[id]["pos"], lugar)
	# Estado compartido del hogar (el del HOST): baul de materiales, bote y cofre.
	_set_almacen.rpc_id(quien, _almacen_dicts())
	_set_bote.rpc_id(quien, Game.bote_dinero)
	_set_cofre.rpc_id(quien, Game.cofre_equipo)
	_set_cofre_consumibles.rpc_id(quien, Game.cofre_consumibles)
	# Los encargos en marcha y quien hay en el hogar de todos: sin esto entraria viendo el hogar
	# vacio y solo se le poblaria al primer cambio.
	_set_encargos.rpc_id(quien, Game.encargos)
	_set_roster_hogar.rpc_id(quien, _construir_roster())
	# Y la LIBRETA del mundo (mapa + niebla): al entrar en mi mundo recoge lo que yo tenga descubierto.
	_set_mapa_sesion.rpc_id(quien, _mapa_sesion, _vistas_sesion)
	# LA BIBLIOTECA DEL MUNDO. Mientras jugais juntos es COMUN: lo que lea uno cuenta para todos, que
	# es lo que se espera de una estanteria compartida -- si tu hermano ya se ha leido el del kebab,
	# el texto esta desbloqueado y no tiene sentido que a ti te lo vuelva a dar el gacha.
	# Al desconectar, cada uno recupera la suya (ver Game.exportar_partida_invitado).
	_set_biblioteca.rpc_id(quien, Game.biblioteca)
	# Y LO DESCUBIERTO: las recetas que ya se enseñan en este mundo (ver _set_vistos_mundo).
	_set_vistos_mundo.rpc_id(quien, _vistos_de_todos())
	_set_tiradas_novato.rpc_id(quien, Game.tiradas_novato)


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
	pj.es_original = true       # EL personaje de esa persona en este mundo (su referencia)
	pj.dueno = identidad
	# Red de seguridad para clientes de versiones anteriores, que mandaban el uid vacio (no pasaban
	# por Game.fichar). Un personaje sin uid no se puede mandar de encargo ni cobrar su excelia. Se le
	# pone AQUI, antes de guardarlo, para que el uid que salga viaje de vuelta en jd_a_dict y las dos
	# maquinas partan del mismo.
	Game.asegurar_uid(pj)
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
	# Entro SIEMPRE por el pueblo: la posicion de la mazmorra que traiga mi JugadorData es de una
	# expedicion que no es esta, y sin esto mi primera bajada me dejaba en ese sitio viejo.
	Game.pos_cargada = Vector2.INF
	mundo_compartido = true
	var l: PersonajeData = Game.lider()
	# Y ahora si tengo cara: se manda con el "estoy listo" para que el host me registre con ella.
	_listo.rpc_id(1, Game.player_color, Game.player_metalico, Game.player_nombre,
		Game.player_imagen_png, Game.player_color_alpha,
		Game.lider().aspecto_completo()["piezas"])
	estado_cambiado.emit("Entrando con %s." % (l.nombre if l != null else "tu personaje"))
	entrada_lista.emit()


# El invitado ya tiene ficha: ahora si se le mete dentro. Corre EN EL HOST.
@rpc("any_peer", "call_remote", "reliable")
func _listo(color: Color, metal: float, nombre: String, imagen: PackedByteArray, alpha: float,
		piezas: Dictionary = {}) -> void:
	if not es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if not _en_la_puerta.has(quien):
		return
	var lugar := String(_en_la_puerta[quien].get("lugar", "pueblo"))
	_admitir(quien, color, metal, nombre, lugar, imagen, alpha, piezas)


# Corre en el CLIENTE, llamado por el host tras aceptarlo: registra al host y guarda su semilla.
@rpc("any_peer", "call_remote", "reliable")
func _presentarse(color: Color, metal: float, nombre: String, lugar: String, semilla: int,
		t2: bool, imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0,
		atajos: PackedInt32Array = PackedInt32Array(), piezas: Dictionary = {}) -> void:
	var quien := multiplayer.get_remote_sender_id()
	_respondio = true
	semilla_host = semilla
	# UN TRABAJADOR no trae partida, y sin semilla Game.hay_partida() es falso: la mazmorra le echaria
	# al menu principal. Su mundo ES el del host, asi que la suya es la del host.
	if soy_trabajador:
		Game.semilla_mundo = semilla
	tienda_t2_host = t2
	pisos_host = Array(atajos)
	_registrar_peer(quien, color, metal, nombre, lugar, imagen, alpha, true, piezas)
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
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0, avisar: bool = true,
		piezas: Dictionary = {}) -> void:
	# La IMAGEN del cuerpo viaja UNA VEZ, en el handshake: es un PNG ya recortado a 128x128
	# (Game.IMAGEN_CUERPO_MAX), no la foto original. Se guarda por peer para poder repintar su
	# cuerpo cada vez que se recrea (al cambiar de piso, por ejemplo) sin volver a pedirla.
	# El ALPHA es la opacidad del color SOBRE la imagen (color_alpha del shader): sin el, el color
	# tapaba del todo la cara del compañero (se fijaba a 1.0).
	_peers[peer_id] = {"color": color, "metal": metal, "nombre": nombre,
		"lugar": lugar, "pos": Vector2.INF, "peleando": false, "comps": [],
		"imagen": imagen, "alpha": alpha, "piezas": piezas}
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
		imagen: PackedByteArray = PackedByteArray(), alpha: float = 1.0, comps: Array = [],
		piezas: Dictionary = {}) -> void:
	if peer_id == multiplayer.get_unique_id() or _peers.has(peer_id):
		return   # yo mismo, o ya lo conozco (llego dos veces): idempotente
	_registrar_peer(peer_id, color, metal, nombre, lugar, imagen, alpha, false, piezas)
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
	_viajando.erase(peer_id)


# Monta el nodo visual de un peer YA registrado (solo si compartimos lugar).
func _crear_avatar_nodo(peer_id: int) -> void:
	if not _peers.has(peer_id):
		return
	if bool(_peers[peer_id].get("trabajador", false)):
		return   # un trabajador de piso no tiene cuerpo
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
		float(p.get("alpha", 1.0)), p.get("piezas", {}), p.get("equipo", {}))
	if p["pos"] != Vector2.INF:
		av.ir_a(p["pos"])   # aparece donde iba, no en el origen
	_avatares[peer_id] = av
	# Su imbuicion, de lo ultimo que anuncio. Va DESPUES de guardar el avatar en _avatares porque
	# _aplicar_imbue_a_avatares lo busca ahi. Sin esto, entrar a una partida en marcha te mostraba
	# sin rastro a alguien que ya iba imbuido: el reparto en vivo (_set_imbue) solo alcanza a quien
	# ya estaba escuchando.
	_aplicar_imbue_a_avatares(peer_id, p.get("imbue", PackedInt32Array()))
	# Y su FAROLILLO, por el mismo motivo y con la misma trampa: sin esto, quien entra a mitad de
	# partida (o vuelve a montar la vista al viajar) pinta al compañero con el radio por defecto, que
	# es el suelo duro -- se veria a alguien con un farol bueno alumbrando un palmo hasta que se le
	# gastara el carbon y volviera a anunciar.
	_aplicar_luz_a_avatares(peer_id, float(p.get("luz", -1.0)))


func _on_peer_disconnected(id: int) -> void:
	var conocido := _peers.has(id)
	var trabajador := es_trabajador(id)
	var piso_viejo: int = _piso_de(id) if es_host else -1   # antes de olvidarle: lo lee de _peers
	_olvidar_peer(id)   # avatar, sequito y registro (la parte visual, comun con _quitar_ajeno)
	# Su marcha cuenta como salir de la mazmorra: libera sus vetas y, si era el ultimo
	# dentro, la expedicion se cierra (solo decide el host).
	if es_host:
		# Roster: avisar a los DEMAS clientes de que este se ha ido, para que borren su avatar (en
		# estrella no se enteran por su cuenta). A quien se cayo no hay a quien mandarselo.
		for otro in _peers:
			_quitar_ajeno.rpc_id(otro, id)
		_liberar_vetas_de(id)
		pesca._liberar_pesca_de(id)
		if _taller_dueno == id:   # se fue con el taller cogido: se libera (su crafteo a medias se pierde)
			_taller_dueno = 0
		if _reservas.has(id):   # se fue con material reservado: lo suelta para que el otro lo vea libre
			_reservas.erase(id)
			_set_reservas.rpc(_reservas)
			reservas_cambiadas.emit()
		# Sus filas EN VIVO del hogar se van con el: a partir de ahora manda la foto de
		# jugadores_mundo, que para quien no esta jugando es la buena. Sin esto se quedarian filas de
		# alguien que ya no esta, y vuelve el personaje fantasma por otra puerta.
		var ident_ida: String = _identidad_de_peer(id)
		if not ident_ida.is_empty() and _roster_ajeno.erase(ident_ida):
			marcar_hogar_sucio()
		# Si simulaba un piso, lo suelta SIN foto (se fue de golpe, no dio tiempo a sacarla): quien
		# se quede lo hereda vacio y las paredes lo van repoblando. Es el precio de un corte brusco.
		_soltar_piso(id, {})
		# TRABAJADORES: si el que se va es uno, su piso ya lo ha heredado un humano justo arriba (con la
		# foto de sus espejos) y solo queda reponer la reserva. Si es un humano, el piso en el que estaba
		# puede haberse quedado vacio.
		_viajando.erase(id)
		if trabajador:
			_trab.al_irse(id)
		else:
			_trab.revisar_vacio(piso_viejo, id)
		# Y si se fue A MEDIA PELEA, los bichos que tenia reservados quedarian congelados para
		# siempre. Que cada dueño suelte los suyos.
		peleas._soltar_reservas_de.rpc(id)
		peleas._soltar_reservas_de(id)
		# Irse NO es morir: se le quita la marca de caido para que no cuente en el "¿habeis muerto
		# todos?" de _registrar_muerte (el que se va tambien deja de contar en _num_humanos).
		_muertos.erase(id)
		if _dentro.has(id):
			_dentro.erase(id)
			if _dentro.is_empty():
				_cerrar_expedicion()
	# ¿Se ha ido el que llevaba la pelea que yo estoy espejando? Mi pantalla se queda huerfana:
	# sin el no llegan ni instantaneas ni turnos, y se quedaria colgada para siempre.
	if id == peleas._pelea_anfitrion:
		peleas._anfitrion_perdido()
	# Si se ha ido alguien que estaba en MI pelea, sus personajes salen de ella (y sus reservas ya
	# las suelta el host mas arriba). Si no, la pelea esperaria un turno que no va a llegar nunca.
	if peleas._pelea_id != 0 and peleas._pelea_participantes.has(id):
		peleas._pelea_participantes.erase(id)
		peleas._dobles.erase(id)
		var mia: Node = peleas._pantalla_combate()
		if mia != null and mia.has_method("sacar_a"):
			mia.sacar_a(id)
	# Solo avisar de gente que llego a ENTRAR (registrada): un intento rechazado por codigo
	# tambien dispara esta señal y no es "un jugador que se va".
	if conocido and not trabajador:
		estado_cambiado.emit("Un jugador se ha ido.")
		# Somos uno menos: el host recuenta y difunde; los apartados por cupo van volviendo.
		if es_host:
			_sync_humanos()
	# SU IDENTIDAD SE VA CON EL, y va AL FINAL porque lo de arriba todavia la lee. _saludar rechaza a
	# quien traiga una identidad que ya esta dentro, y esto no se borraba nunca: el que salia al menu
	# no podia volver a entrar hasta que el host cerrase la sesion (playtest del 11/09/2026).
	_identidades.erase(id)
	_en_la_puerta.erase(id)


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
	if soy_trabajador:
		_trab.me_han_soltado("no he podido conectar con la sala")
		return
	# IP mal escrita, host sin abrir, o no hay red: para el jugador es lo mismo.
	estado_cambiado.emit("No se encontro ninguna partida en esa IP.")
	desconectar()


func _on_server_disconnected() -> void:
	if soy_trabajador:
		_trab.me_han_soltado("la sala se ha cerrado")
		return
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
