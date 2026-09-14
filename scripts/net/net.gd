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
const NetPartida = preload("res://scripts/net/net_partida.gd")
const NetMapa = preload("res://scripts/net/net_mapa.gd")
const NetJefes = preload("res://scripts/net/net_jefes.gd")
const NetRecoleccion = preload("res://scripts/net/net_recoleccion.gd")
const NetHogar = preload("res://scripts/net/net_hogar.gd")
const NetPeleas = preload("res://scripts/net/net_peleas.gd")
const NetExtraccion = preload("res://scripts/net/net_extraccion.gd")
const NetEnemigos = preload("res://scripts/net/net_enemigos.gd")
const NetSuelo = preload("res://scripts/net/net_suelo.gd")
var pesca: NetPesca = null
var partida: NetPartida = null
var mapa: NetMapa = null
var jefes: NetJefes = null
var recoleccion: NetRecoleccion = null
var hogar: NetHogar = null
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
	mapa._sembrar_mapa_sesion()    # el mapa de la sesion arranca siendo el MIO: se juega en mi mundo
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
	recoleccion._vetas_ocupadas.clear()
	recoleccion._agotados_sesion.clear()
	recoleccion._nonces_sesion.clear()
	hogar._roster_ajeno.clear()
	hogar._hogar_sucio = false
	epoca_sesion = 0
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
		recoleccion._sembrar_agotados_del_save()
		# Y se barren YA los que hayan cumplido su tiempo mientras no habia nadie. Va antes de
		# conceder la entrada a proposito: el que baja construye su piso con la lista de agotados que
		# le mandamos aqui abajo, asi que si esto se dejara al barrido periodico (cada 2 s) bajaria a
		# un piso sin la veta y se la veria brotar de la nada dos segundos despues.
		recoleccion._barrer_respawns()
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
		_entrar_ok(piso, recoleccion._agotados_sesion, dueno, mem, _restantes_boss(), epoca_sesion, recoleccion._nonces_sesion)
	else:
		_entrar_ok.rpc_id(quien, piso, recoleccion._agotados_sesion, dueno, mem, _restantes_boss(),
			epoca_sesion, recoleccion._nonces_sesion)


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
	recoleccion._sembrar_agotados_del_save()
	# Los NONCES tambien: las vetas de este piso nacieron con los de MI save (el piso se construyo en
	# solitario), y el que baje construira el suyo con los de la sesion. Sin sembrarlos veria otro
	# material en la misma veta.
	for p in Game.mazmorra_persistente:
		var nn = (Game.mazmorra_persistente[p] as Dictionary).get("nonces", {})
		if nn is Dictionary:
			for celda in nn:
				recoleccion._nonces_sesion[recoleccion._sitio(int(p), celda as Vector2i)] = int(nn[celda])
	recoleccion._barrer_respawns()
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
	for piso in jefes._bosses_sello:
		var espera: float = float(Game.BOSS_RESPAWN.get(piso, 0.0))
		var pasado: float = float(Encargos.ahora()) - float(jefes._bosses_sello[piso])
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
	recoleccion._agotados_sesion = agotados.duplicate()
	# Que jefes de la sesion estan muertos ahora mismo. Sin esto, el que baja al piso 6 por el atajo
	# plantaria un rey slime que para los demas sigue muerto (y solo el lo veria).
	#
	# Llegan como SEGUNDOS QUE FALTAN (ver _conceder_entrada) y se pasan aqui a MI reloj de pared, para
	# que la resta de boss_restante valga igual en las dos maquinas. El HOST no se toca la suya: es la
	# tabla autoritativa, ya esta en su reloj, y re-hacerla desde su propio mensaje solo podria
	# estropearla con el redondeo del viaje de ida y vuelta.
	if not es_host:
		jefes._bosses_sello.clear()
		# 'p' y no 'piso': el parametro de esta funcion ya se llama asi (el piso al que entro).
		for p in sellos_boss:
			var espera: float = float(Game.BOSS_RESPAWN.get(p, 0.0))
			jefes._bosses_sello[p] = float(Encargos.ahora()) - (espera - float(sellos_boss[p]))
	Game.current_floor = piso
	# La EPOCA y los NONCES del mundo del host: sin ellos el invitado tiraria por su cuenta que
	# material y que pez sale en cada sitio, y veria cosas distintas de las del host en la MISMA veta.
	# Se cogen ANTES de olvidar_mazmorra a proposito: esa renueva la epoca LOCAL (la de mi propio
	# mundo, que aqui no pinta nada) y lo que vale mientras dure la sesion es epoca_sesion.
	recoleccion._nonces_sesion = nonces.duplicate()
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
	recoleccion._nonces_sesion.clear()
	for id in suelo._suelo.keys():
		if str(suelo._suelo[id]["lugar"]).begins_with("piso:"):
			suelo._suelo.erase(id)
			suelo._despawn_drop.rpc(id)
			suelo._despawn_drop(id)
	for piso in jefes._bosses_sello.keys():
		jefes._marcar_boss(piso, false)
		jefes._marcar_boss.rpc(piso, false)
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
	recoleccion._vetas_ocupadas.clear()
	recoleccion._t_barrido = 0.0
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
	hogar._set_roster_hogar.rpc_id(quien, hogar._construir_roster())
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
