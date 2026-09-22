# ============================================================
#  tunel_steam.gd
#  EL TUNEL: lleva los datagramas de ENet por Steam, para jugar sin Hamachi ni IPs.
#
#  El juego y la sala siguen hablando ENet exactamente como hoy; ninguno sabe que hay Steam en medio:
#    - En el PC del AMIGO (modo "cliente"): su ENet conecta a 127.0.0.1:<puerto_local>. El tunel recoge
#      lo que manda y lo envia por Steam a la sala; lo que vuelve se lo devuelve a su ENet.
#    - En la SALA (modo "sala"): por cada amigo que llega por Steam abre un socket UDP PROPIO contra
#      127.0.0.1:<puerto de la sala>, asi la sala ve un cliente distinto por amigo (como si vinieran de
#      otra IP). Lo que la sala contesta por ese socket vuelve por Steam a ese amigo.
#
#  Por Steam va el canal NO fiable: la fiabilidad y el orden los sigue llevando ENet por dentro.
#  La contraseña la sigue comprobando el saludo de Net: el tunel acepta a cualquiera y deja que Net
#  eche a quien no toque.
#
#  El TRANSPORTE va aparte (enviar / recibir / bombear) para poder probar el tunel SIN Steam:
#    TransporteSteam  la cuenta de Steam (Steam) o la sala como servidor de juego anonimo (SteamServer)
#    TransporteFalso  UDP local, con perdida simulada (tools/prueba_tunel.tscn)
# ============================================================
extends Node

const CANAL := 0
const TOPE_POR_FOTOGRAMA := 256     # datagramas por sentido y fotograma: que un atasco no congele el juego
const MAX_REMOTOS := 32             # como Net.MAX_CONEXIONES: la sala no abre sockets sin fin
const SEG_INACTIVO := 45.0          # un amigo sin trafico este rato se olvida (ENet ya le habra echado)

var modo := ""                      # "" / "cliente" / "sala"
var transporte = null

# --- cliente ---
var _id_sala := 0
var _local := PacketPeerUDP.new()   # donde escucha el tunel: el ENet del juego conecta aqui
var _puerto_enet := 0               # desde donde habla ese ENet (lo sabemos con su primer datagrama)

# --- sala ---
var _puerto_sala := 0
var _remotos: Dictionary = {}       # id remoto -> {"udp": PacketPeerUDP, "t": ultimo trafico (s)}

# --- contadores (tecla P) ---
var _cuenta := {"sube_p": 0, "sube_b": 0, "baja_p": 0, "baja_b": 0, "fallos_envio": 0}
var _ritmo := {}                    # la cuenta del segundo pasado
var _t_ritmo := 0.0
var _reloj := 0.0


# Modo CLIENTE: devuelve el puerto local al que tiene que conectar el ENet del juego (0 = fallo).
func abrir_cliente(transporte_, id_sala: int) -> int:
	cerrar()
	if _local.bind(0, "127.0.0.1") != OK:
		push_warning("[tunel] no se pudo abrir el puerto local")
		return 0
	transporte = transporte_
	_id_sala = id_sala
	modo = "cliente"
	print("[tunel] cliente: ENet -> 127.0.0.1:%d -> %d" % [_local.get_local_port(), id_sala])
	return _local.get_local_port()


# Modo SALA: lo que llegue por el transporte se entrega a 127.0.0.1:<puerto_sala>.
func abrir_sala(transporte_, puerto_sala: int) -> void:
	cerrar()
	transporte = transporte_
	_puerto_sala = puerto_sala
	modo = "sala"
	print("[tunel] sala: %s -> 127.0.0.1:%d" % [str(transporte.mi_id()), puerto_sala])


func cerrar() -> void:
	_local.close()
	_puerto_enet = 0
	for id in _remotos:
		(_remotos[id]["udp"] as PacketPeerUDP).close()
	_remotos.clear()
	if transporte != null:
		transporte.cerrar()
	transporte = null
	modo = ""


func _exit_tree() -> void:
	cerrar()


func _process(delta: float) -> void:
	if modo == "":
		return
	_reloj += delta
	transporte.bombear()
	if modo == "cliente":
		_bombear_cliente()
	else:
		_bombear_sala()
	_t_ritmo += delta
	if _t_ritmo >= 1.0:
		_ritmo = _cuenta.duplicate()
		for k in _cuenta:
			_cuenta[k] = 0
		_t_ritmo = 0.0


func _bombear_cliente() -> void:
	# De mi ENet hacia la sala.
	var n := 0
	while _local.get_available_packet_count() > 0 and n < TOPE_POR_FOTOGRAMA:
		var p := _local.get_packet()
		_puerto_enet = _local.get_packet_port()
		_subir(_id_sala, p)
		n += 1
	# De la sala hacia mi ENet.
	for m in transporte.recibir(TOPE_POR_FOTOGRAMA):
		if int(m[0]) != _id_sala or _puerto_enet == 0:
			continue
		_local.set_dest_address("127.0.0.1", _puerto_enet)
		_local.put_packet(m[1])
		_contar_bajada(m[1])


func _bombear_sala() -> void:
	# De los amigos hacia la sala: cada uno por su socket.
	for m in transporte.recibir(TOPE_POR_FOTOGRAMA):
		var id: int = int(m[0])
		var r = _remotos.get(id)
		if r == null:
			if _remotos.size() >= MAX_REMOTOS:
				continue
			var udp := PacketPeerUDP.new()
			if udp.connect_to_host("127.0.0.1", _puerto_sala) != OK:
				continue
			r = {"udp": udp, "t": _reloj}
			_remotos[id] = r
			print("[tunel] llega %s (%d dentro)" % [str(id), _remotos.size()])
		r["t"] = _reloj
		(r["udp"] as PacketPeerUDP).put_packet(m[1])
		_contar_bajada(m[1])
	# De la sala hacia cada amigo.
	for id in _remotos.keys():
		var r: Dictionary = _remotos[id]
		var udp: PacketPeerUDP = r["udp"]
		var n := 0
		while udp.get_available_packet_count() > 0 and n < TOPE_POR_FOTOGRAMA:
			_subir(id, udp.get_packet())
			n += 1
		if n > 0:
			r["t"] = _reloj
		if _reloj - float(r["t"]) > SEG_INACTIVO:
			udp.close()
			_remotos.erase(id)
			transporte.olvidar(id)
			print("[tunel] %s sin trafico: fuera (%d dentro)" % [str(id), _remotos.size()])


func _subir(dest: int, p: PackedByteArray) -> void:
	if not transporte.enviar(dest, p):
		_cuenta["fallos_envio"] += 1
		return
	_cuenta["sube_p"] += 1
	_cuenta["sube_b"] += p.size()


func _contar_bajada(p: PackedByteArray) -> void:
	_cuenta["baja_p"] += 1
	_cuenta["baja_b"] += p.size()


# Una linea para la traza de la tecla P.
func resumen() -> String:
	if modo == "":
		return "tunel: apagado"
	var r: Dictionary = _ritmo if not _ritmo.is_empty() else _cuenta
	var quien := ("sala %s" % str(_id_sala)) if modo == "cliente" else ("%d amigos" % _remotos.size())
	return "tunel %s (%s): sube %d p/s %.1f KB/s, baja %d p/s %.1f KB/s, fallos %d%s" % [modo, quien,
		r["sube_p"], r["sube_b"] / 1024.0, r["baja_p"], r["baja_b"] / 1024.0, r["fallos_envio"],
		(", " + transporte.estado(_id_sala)) if modo == "cliente" else ""]


# ------------------------------------------------------------
#  TRANSPORTES
# ------------------------------------------------------------

## Steam de verdad. `api` es el singleton Steam (la cuenta del jugador) o SteamServer (la sala, como
## servidor de juego anonimo). Los dos tienen las mismas funciones de Networking Messages.
## Quien lo crea ya ha iniciado Steam; el transporte solo corre sus callbacks y mueve mensajes.
class TransporteSteam:
	var api: Object
	var acepta_de := 0          # 0 = acepta sesiones de cualquiera (sala); si no, solo de ese id
	# NETWORKING_SEND_UNRELIABLE (0) | NO_NAGLE (1) | AUTORESTART_BROKEN_SESSION (32). Van en numero porque
	# las constantes de la clase no se leen desde una variable Object.
	const _FLAGS := 0 | 1 | 32

	func _init(api_: Object, acepta_de_: int = 0) -> void:
		api = api_
		acepta_de = acepta_de_
		api.network_messages_session_request.connect(_al_pedir_sesion)
		api.network_messages_session_failed.connect(_al_fallar_sesion)
		api.initRelayNetworkAccess()

	func mi_id() -> int:
		return int(api.getSteamID())

	func _al_pedir_sesion(remoto: int) -> void:
		if acepta_de == 0 or remoto == acepta_de:
			api.acceptSessionWithUser(remoto)

	func _al_fallar_sesion(motivo, remoto, estado, texto) -> void:
		push_warning("[tunel] sesion Steam con %s cortada: %s %s" % [str(remoto), str(motivo), str(texto)])

	func bombear() -> void:
		api.run_callbacks()

	func enviar(dest: int, datos: PackedByteArray) -> bool:
		return int(api.sendMessageToUser(dest, datos, _FLAGS, CANAL)) == 1   # 1 = k_EResultOK

	func recibir(tope: int) -> Array:
		var out := []
		for m in api.receiveMessagesOnChannel(CANAL, tope):
			out.append([int(m["identity"]), m["payload"]])
		return out

	func olvidar(id: int) -> void:
		api.closeSessionWithUser(id)

	# Como va la conexion con ese id: directa (misma red o NAT abierto) o por los relays de Steam.
	func estado(id: int) -> String:
		var i: Dictionary = api.getSessionConnectionInfo(id, true, true)
		if i.is_empty():
			return "sin sesion"
		return "%s, ping %d ms" % ["relay" if int(i.get("pop_relay", 0)) != 0 else "directo",
			int(i.get("ping", -1))]

	func cerrar() -> void:
		if api.network_messages_session_request.is_connected(_al_pedir_sesion):
			api.network_messages_session_request.disconnect(_al_pedir_sesion)
			api.network_messages_session_failed.disconnect(_al_fallar_sesion)


## Para las pruebas: cada "id" es un puerto UDP de 127.0.0.1. `perdida` tira ese tanto por uno de lo
## que se envia, para ver que ENet lo aguanta como aguantaria el canal no fiable de Steam.
class TransporteFalso:
	var _udp := PacketPeerUDP.new()
	var perdida := 0.0

	func _init(perdida_: float = 0.0) -> void:
		perdida = perdida_
		_udp.bind(0, "127.0.0.1")

	func mi_id() -> int:
		return _udp.get_local_port()

	func bombear() -> void:
		pass

	func enviar(dest: int, datos: PackedByteArray) -> bool:
		if randf() < perdida:
			return true   # "enviado" y perdido por el camino
		_udp.set_dest_address("127.0.0.1", dest)
		return _udp.put_packet(datos) == OK

	func recibir(tope: int) -> Array:
		var out := []
		while _udp.get_available_packet_count() > 0 and out.size() < tope:
			var p := _udp.get_packet()
			out.append([_udp.get_packet_port(), p])
		return out

	func olvidar(_id: int) -> void:
		pass

	func estado(_id: int) -> String:
		return "falso"

	func cerrar() -> void:
		_udp.close()
