# ============================================================
#  net.gd  (autoload "Net")
#  Capa de RED del juego: el NUCLEO de la sesion. Aqui viven la conexion (host/cliente sobre ENet),
#  el saludo, quien es cada peer y donde esta (_peers, lugar, avatares), el cupo de personajes y el
#  estado de los dueños de piso, que leen casi todos los temas. Ver docs/MULTIJUGADOR.md.
#
#  CADA TEMA EN SU ARCHIVO, colgado de Net como hijo con NOMBRE FIJO (sus RPC viajan por la ruta del
#  nodo, que es la misma en todas las maquinas: /root/Net/<Nodo>). Se llaman como Net.<tema>.<funcion>:
#    jugadores   net_jugadores.gd    lo que los demas ven de ti (posicion, pose, aspecto, farolillo...)
#    pisos       net_pisos.gd        expedicion, muerte, escaleras, dueño de piso, relevos y fotos
#    enemigos    net_enemigos.gd     altas, bajas y posiciones de los bichos del dueño del piso
#    peleas      net_peleas.gd       pedir/unirse/traspasar peleas y el espejo del combate
#    extraccion  net_extraccion.gd   extraer cadaveres con candado del dueño
#    suelo       net_suelo.gd        soltar y recoger objetos
#    recoleccion net_recoleccion.gd  vetas, agotados, nonces y respawn
#    jefes       net_jefes.gd        jefe caido, sellos y su vuelta por reloj
#    pesca       net_pesca.gd        el charco compartido
#    hogar       net_hogar.gd        bote, cofres, baul, reservas, encargos y roster del hogar
#    mapa        net_mapa.gd         la libreta del mundo (mapa y niebla)
#    partida     net_partida.gd      personajes por red, guardado y entrar a un mundo compartido
#    _trab       trabajadores.gd     los Godot sin ventana que simulan los pisos
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
# CONEXIONES, que no es lo mismo que jugadores: los TRABAJADORES (uno por piso ocupado, mas los que
# esperan peleas) tambien son clientes ENet. Mientras create_server recibia MAX_JUGADORES, dos humanos
# con un piso y dos de pelea llenaban la sala y todo trabajador nuevo se quedaba en la puerta (playtest
# del 15/09: del 4 al 35 "no he podido conectar"). El tope de humanos lo pone ahora _saludar.
const MAX_CONEXIONES := 32

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
# 10: net.gd se parte en temas (Net.<tema>) y llegan los trabajadores de piso. Los RPC cambian de nodo
#     (/root/Net/<Tema>), asi que un build del 9 no entiende casi nada de lo que le llega.
# 11: las peleas las ejecutan los TRABAJADORES DE PELEA (RPC nuevos en Net.peleas y en los trabajadores, el
#     saludo del trabajador lleva su pid) y el lote de desgaste trae uid, durabilidad y pasivas. Un build
#     del 10 montaria la pelea en su PC mientras el otro la espera en un trabajador.
# 12: el corcho de pesca viaja como modo (int: nada / visible / pescando) en vez de bool; los aliados de la
#     instantanea del combate llevan los numeros de su ficha de detalle.
# 13: la FORMACION comun (Net.formacion: _set_formacion, peticiones de mover) y las filas del roster del
#     hogar llevan pos_equipo y el aspecto de los que van en equipo.
# 14: el encargo se pide con el OBJETIVO por grupos ({grupo: %}) en vez de la lista de tipos, y su
#     informe trae cristales, dinero y rotos. Un build del 13 mandaria tipos que el host leeria mal.
# 15: el daño del paquete de impactos va x100 (antes x10: un build del 14 veria diez veces el daño); el
#     tick de enemigos trae un sexto campo (contador de embestidas); la instantanea del combate lleva el
#     registro como Array de frases nuevas + "logn" (antes un String con la cola) y hay RPC nuevos para
#     pedir el registro entero.
# 16: sacar del cofre del hogar (equipo y consumibles) lleva "vender" en sus RPC, para vender desde la
#     tienda. Un build del 15 no casaria los argumentos y la peticion se perderia.
# 17: RPC nuevo _set_semilla_pueblo (las cañas del muelle salen igual para todos). Un build del 16 no
#     lo conoce y el pueblo se le colocaria con su propia semilla.
# 18: RPC nuevo _set_hora_pueblo (el dia y la noche del pueblo, con la hora del host). Un build del 17 no
#     lo conoce y veria su propio cielo.
# 19: las filas del roster llevan el aspecto de TODOS sin la foto (imagen_huella) y las fotos van por
#     _subir_fotos / _set_fotos_roster. Un build del 18 no las conoce y veria a todos sin foto.
const PROTOCOLO := 19

# Cuanto espera el cliente una respuesta al saludo antes de dar por hecho que no se entienden.
const _PLAZO_SALUDO := 5.0
const _REMOTE_PLAYER := preload("res://scripts/actors/player/remote_player.gd")

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

# LA SEMILLA DEL PUEBLO de la sesion (ver Game.semilla_pueblo). La tiene el HOST: la estrena con la suya
# al primer invitado, la renueva cada vez que alguien baja a la mazmorra (Net.pisos._conceder_entrada) y
# la manda a todos. 0 = aun no ha llegado (el pueblo usa la local mientras tanto).
var semilla_pueblo: int = 0


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

# El panel de conexion se suscribe para pintar "Conectado / Rechazado / Host caido...".
signal estado_cambiado(texto: String)
# La semilla del pueblo ha cambiado (ver Game.semilla_pueblo): el pueblo vuelve a colocar sus cañas.
signal semilla_pueblo_cambiada()
# El host ha contestado a un pedir_guardar_todos (corre en el invitado). Lo espera el "Guardar y salir"
# del invitado para no cortar antes de que su estado haya llegado y se haya escrito.
signal guardado_respondido(ok: bool)

# Se emite cuando cambia CUALQUIER estado compartido del hogar (bote, cofre, baul de materiales):
# los menus del pueblo abiertos se re-dibujan al oirlo (hoy la UI solo se refresca por accion
# propia; en multi el OTRO puede cambiar el estado y hay que enterarse).
signal hogar_cambiado()
# Una venta desde el cofre del hogar ya cobrada (en multi llega tarde: la concede el host). La escucha
# la tienda para decir lo que has cobrado.
signal venta_cofre(texto: String)

# ¿Soy un CLIENTE en sesion? (uso el almacen del host via mirror). El host y el modo un jugador
# usan Game.* directo.
func _soy_cliente() -> bool:
	return activo and not es_host


# DONDE ESTA ahora el cuerpo de ese peer en MI escena, o Vector2.INF si no lo tengo. Con 0 ("yo")
# devuelve INF y quien pregunte usa mi jugador; salvo en un TRABAJADOR, que no tiene jugador: ahi vale
# el primer humano que tenga a la vista. Lo usa el brote del alboroto para reventar la pared delante de
# quien ha hecho el ruido.
func posicion_de_peer(peer: int) -> Vector2:
	var a = _avatares.get(peer) if peer != 0 else null   # sin tipar: puede estar liberado
	if a != null and is_instance_valid(a):
		return (a as Node2D).global_position
	if soy_trabajador:
		for id in _avatares:
			var b = _avatares[id]
			if is_instance_valid(b):
				return (b as Node2D).global_position
	return Vector2.INF


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
	jugadores = NetJugadores.new()
	jugadores.name = "Jugadores"
	add_child(jugadores)
	pisos = NetPisos.new()
	pisos.name = "Pisos"
	add_child(pisos)
	partida = NetPartida.new()
	partida.name = "Partida"
	add_child(partida)
	mapa = NetMapa.new()
	mapa.name = "Mapa"
	add_child(mapa)
	jefes = NetJefes.new()
	jefes.name = "Jefes"
	add_child(jefes)
	recoleccion = NetRecoleccion.new()
	recoleccion.name = "Recoleccion"
	add_child(recoleccion)
	hogar = NetHogar.new()
	hogar.name = "Hogar"
	add_child(hogar)
	formacion = NetFormacion.new()
	formacion.name = "Formacion"
	add_child(formacion)
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
const NetJugadores = preload("res://scripts/net/net_jugadores.gd")
const NetPisos = preload("res://scripts/net/net_pisos.gd")
const NetPartida = preload("res://scripts/net/net_partida.gd")
const NetMapa = preload("res://scripts/net/net_mapa.gd")
const NetJefes = preload("res://scripts/net/net_jefes.gd")
const NetRecoleccion = preload("res://scripts/net/net_recoleccion.gd")
const NetHogar = preload("res://scripts/net/net_hogar.gd")
const NetFormacion = preload("res://scripts/net/net_formacion.gd")
const NetPeleas = preload("res://scripts/net/net_peleas.gd")
const NetExtraccion = preload("res://scripts/net/net_extraccion.gd")
const NetEnemigos = preload("res://scripts/net/net_enemigos.gd")
const NetSuelo = preload("res://scripts/net/net_suelo.gd")
var pesca: NetPesca = null
var jugadores: NetJugadores = null
var pisos: NetPisos = null
var partida: NetPartida = null
var mapa: NetMapa = null
var jefes: NetJefes = null
var recoleccion: NetRecoleccion = null
var hogar: NetHogar = null
var formacion: NetFormacion = null
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
	var err := peer.create_server(puerto, MAX_CONEXIONES)
	if err != OK:
		estado_cambiado.emit("No se pudo abrir el servidor (puerto %d ocupado?)" % puerto)
		return err
	multiplayer.multiplayer_peer = peer
	_codigo = codigo
	activo = true
	es_host = true
	# Si lo que tengo abierto es un mundo compartido, esta sesion lo es (lo consulta medio net.gd).
	mundo_compartido = Mundos.abierto != ""
	mapa._sembrar_mapa_sesion()    # el mapa de la sesion arranca siendo el MIO: se juega en mi mundo
	Game._refrescar_pausa()   # regimen multi: los menus dejan de pausar el arbol
	if piso_dentro != null:
		pisos._montar_sesion_desde_dentro(int(piso_dentro.get("_piso_construido")))
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
		jugadores._quitar_companeros(id)
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
	recoleccion._vetas_ocupadas.clear()
	recoleccion._agotados_sesion.clear()
	recoleccion._nonces_sesion.clear()
	hogar._roster_ajeno.clear()
	hogar._hogar_sucio = false
	hogar._olvidar_fotos()
	epoca_sesion = 0
	semilla_pueblo = 0
	CicloDia.desfase = 0.0      # sin sesion, la hora vuelve a ser la de este PC
	jefes._bosses_sello.clear()
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
	mapa._mapa_sesion.clear()
	mapa._vistas_sesion.clear()
	# Restaurar MI baul de materiales si lo habia guardado al entrar de cliente (no perder nada).
	# En un MUNDO COMPARTIDO no hay nada que restaurar: el invitado no aparto ningun baul al entrar
	# porque no trae mundo propio (ver _on_connected_to_server). Volcarle aqui un `_almacen_solo`
	# vacio le borraria el baul del mundo en el que acaba de jugar.
	if hogar._almacen_guardado and not mundo_compartido:
		var lista: Array[MaterialItem] = []
		for m in hogar._almacen_solo:
			lista.append(m)
		Game.almacen_materiales = lista
	if hogar._almacen_guardado:
		hogar._almacen_guardado = false
		hogar._almacen_solo = []
	# La foto de MI mundo al entrar de invitado (ver _congelar_mi_mundo) no sobrevive a la sesion:
	# fuera de ella no hay nada que revertir, y dejarla puesta significaria que un guardado de
	# invitado hecho por error volcaria el baul y el mapa de una sesion ya cerrada.
	partida._mundo_propio = {}
	hogar._bote_mirror = 0
	hogar._tiradas_novato_mirror = 0
	hogar._cofre_mirror = []
	hogar._encargos_mirror = []
	hogar._roster_mirror = []
	hogar._cofre_consum_mirror = {}
	hogar._taller_dueno = 0
	hogar._taller_resp = 0
	hogar._reservas.clear()
	hogar._mi_reserva_local.clear()
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
		jugadores._quitar_companeros(emisor)   # su sequito se va con el


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
		jugadores._quitar_companeros(id)   # sus acompañantes murieron con la escena vieja tambien
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
			var dueno: int = _dueno_piso.get(pisos.mi_piso(), 0)
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
	hogar._difundir_hogar()   # alguien entra o se va: la formacion se reconcilia y viaja ya


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
	for c in recoleccion._vetas_ocupadas.keys():
		if recoleccion._vetas_ocupadas[c] == quien:
			recoleccion._vetas_ocupadas.erase(c)


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
		hogar._almacen_solo = Game.almacen_materiales.duplicate()
		hogar._almacen_guardado = true
		partida._congelar_mi_mundo()   # para poder GUARDAR sin volcar en mi save nada del mundo del host

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
	# EL TOPE DE HUMANOS. Antes lo ponia ENet de rebote (create_server con MAX_JUGADORES); ahora ENet
	# deja sitio a los trabajadores y la cuenta se hace aqui: yo, los que ya estan y los que estan en
	# la puerta creando personaje.
	var humanos := 1 + _en_la_puerta.size()
	for pid in _peers:
		if not es_trabajador(pid) and not _en_la_puerta.has(pid):
			humanos += 1
	if humanos >= MAX_JUGADORES:
		estado_cambiado.emit("Rechazado: la sala ya tiene %d jugadores." % MAX_JUGADORES)
		await _echar(quien, "La sala está llena.")
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
			partida._tu_jugador.rpc_id(quien, partida.jd_a_dict(jd as JugadorData), Game.semilla_mundo)
		else:
			estado_cambiado.emit("%s entra por primera vez: está creando su personaje." % nombre_visible)
			partida._crea_tu_personaje.rpc_id(quien, Game.player_nombre)
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
	hogar._set_almacen.rpc_id(quien, hogar._almacen_dicts())
	hogar._set_bote.rpc_id(quien, Game.bote_dinero)
	hogar._set_cofre.rpc_id(quien, Game.cofre_equipo)
	hogar._set_cofre_consumibles.rpc_id(quien, Game.cofre_consumibles)
	# Los encargos en marcha y quien hay en el hogar de todos: sin esto entraria viendo el hogar
	# vacio y solo se le poblaria al primer cambio.
	hogar._set_encargos.rpc_id(quien, Game.encargos)
	var roster_ya: Array = hogar._construir_roster()
	hogar._repartir_fotos(quien, roster_ya)
	hogar._set_roster_hogar.rpc_id(quien, roster_ya)
	# Y la LIBRETA del mundo (mapa + niebla): al entrar en mi mundo recoge lo que yo tenga descubierto.
	mapa._set_mapa_sesion.rpc_id(quien, mapa._mapa_sesion, mapa._vistas_sesion)
	# LA BIBLIOTECA DEL MUNDO. Mientras jugais juntos es COMUN: lo que lea uno cuenta para todos, que
	# es lo que se espera de una estanteria compartida -- si tu hermano ya se ha leido el del kebab,
	# el texto esta desbloqueado y no tiene sentido que a ti te lo vuelva a dar el gacha.
	# Al desconectar, cada uno recupera la suya (ver Game.exportar_partida_invitado).
	hogar._set_biblioteca.rpc_id(quien, Game.biblioteca)
	# Y LO DESCUBIERTO: las recetas que ya se enseñan en este mundo (ver _set_vistos_mundo).
	hogar._set_vistos_mundo.rpc_id(quien, hogar._vistos_de_todos())
	hogar._set_tiradas_novato.rpc_id(quien, Game.tiradas_novato)
	# Y la SEMILLA DEL PUEBLO, para que sus cañas caigan donde las mias.
	if semilla_pueblo == 0:
		semilla_pueblo = Game.semilla_pueblo
	_set_semilla_pueblo.rpc_id(quien, semilla_pueblo)
	# Y SU HORA, para que el dia y la noche del pueblo (CicloDia) vayan a la par aunque el reloj de algun
	# PC vaya adelantado o atrasado. Lo que tarde en llegar (milisegundos) no se ve en un ciclo de 40 min.
	_set_hora_pueblo.rpc_id(quien, Time.get_unix_time_from_system() + float(Encargos.desfase_prueba))


@rpc("any_peer", "call_remote", "reliable")
func _set_hora_pueblo(t_host: float) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	# La hora llega TARDE: va al final del alta, detras del baul y el cofre, y medido tarda ~5 s. Aplicarla
	# siempre le meteria ese retraso a un reloj que ya iba bien. Solo se corrige un reloj MAL PUESTO de verdad.
	var d: float = t_host - (Time.get_unix_time_from_system() + float(Encargos.desfase_prueba))
	CicloDia.desfase = d if absf(d) > 30.0 else 0.0


# HOST: estrena semilla del pueblo y se la manda a todos (ver Game.semilla_pueblo).
func renovar_semilla_pueblo() -> void:
	if not activo or not es_host:
		return
	semilla_pueblo = randi() | 1
	_set_semilla_pueblo.rpc(semilla_pueblo)
	semilla_pueblo_cambiada.emit()


@rpc("any_peer", "call_remote", "reliable")
func _set_semilla_pueblo(v: int) -> void:
	if multiplayer.get_remote_sender_id() != 1:
		return
	semilla_pueblo = v
	semilla_pueblo_cambiada.emit()


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
		jugadores.anunciar_grupo()
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
	jugadores._quitar_companeros(peer_id)
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
	jugadores._aplicar_imbue_a_avatares(peer_id, p.get("imbue", PackedInt32Array()))
	# Y su FAROLILLO, por el mismo motivo y con la misma trampa: sin esto, quien entra a mitad de
	# partida (o vuelve a montar la vista al viajar) pinta al compañero con el radio por defecto, que
	# es el suelo duro -- se veria a alguien con un farol bueno alumbrando un palmo hasta que se le
	# gastara el carbon y volviera a anunciar.
	jugadores._aplicar_luz_a_avatares(peer_id, float(p.get("luz", -1.0)))


func _on_peer_disconnected(id: int) -> void:
	var conocido := _peers.has(id)
	var trabajador := es_trabajador(id)
	var piso_viejo: int = pisos._piso_de(id) if es_host else -1   # antes de olvidarle: lo lee de _peers
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
		if hogar._taller_dueno == id:   # se fue con el taller cogido: se libera (su crafteo a medias se pierde)
			hogar._taller_dueno = 0
		if hogar._reservas.has(id):   # se fue con material reservado: lo suelta para que el otro lo vea libre
			hogar._reservas.erase(id)
			hogar._set_reservas.rpc(hogar._reservas)
			reservas_cambiadas.emit()
		# Sus filas EN VIVO del hogar se van con el: a partir de ahora manda la foto de
		# jugadores_mundo, que para quien no esta jugando es la buena. Sin esto se quedarian filas de
		# alguien que ya no esta, y vuelve el personaje fantasma por otra puerta.
		var ident_ida: String = _identidad_de_peer(id)
		if not ident_ida.is_empty() and hogar._roster_ajeno.erase(ident_ida):
			hogar.marcar_hogar_sucio()
		hogar._fotos_mandadas.erase(id)   # si vuelve es otra conexion, sin fotos: se le mandan de nuevo
		# Si simulaba un piso, lo suelta SIN foto (se fue de golpe, no dio tiempo a sacarla): quien
		# se quede lo hereda vacio y las paredes lo van repoblando. Es el precio de un corte brusco.
		pisos._soltar_piso(id, {})
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
				pisos._cerrar_expedicion()
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
