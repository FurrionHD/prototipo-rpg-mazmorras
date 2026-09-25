# PRUEBA (Steam F1): EL TUNEL. Una "sala" ENet y dos "amigos" ENet que solo se hablan a traves de
# tunel_steam.gd, con el transporte FALSO (UDP local) perdiendo el 10% de lo que pasa por el. Comprueba:
#   - la sala ve a cada amigo como un cliente distinto;
#   - 200 mensajes fiables de cada amigo llegan y vuelven enteros y EN ORDEN pese a la perdida;
#   - un paquete de 60 KB (troceado por ENet) llega intacto;
#   - al irse un amigo, la sala se entera y el otro sigue.
# Con `-- steam` hace lo mismo con STEAM DE VERDAD (un amigo, que es la cuenta abierta; la sala entra como
# servidor de juego anonimo). Necesita Steam abierto.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_tunel.tscn [-- steam]
extends Node

const Tunel = preload("res://scripts/net/tunel_steam.gd")
const PUERTO_SALA := 24597
const N := 200
const GRANDE := 60000
const BAUL := 2560 * 1024       # el baul de materiales real va en UN paquete de ~2,5 MB (prueba_paquete_grande)

var fallos := 0
var sala_enet := ENetConnection.new()
var sala_peers: Array = []        # peers que la sala ha visto conectarse
var sala_bajas := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


class Amigo:
	var nombre := ""
	var enet := ENetConnection.new()
	var peer: ENetPacketPeer
	var conectado := false
	var ecos: Array[int] = []
	var grande_ok := false
	var baul_ok := false

	func _init(nombre_: String, puerto_local: int) -> void:
		nombre = nombre_
		enet.create_host(1)
		peer = enet.connect_to_host("127.0.0.1", puerto_local, 1)

	func servir() -> void:
		while true:
			var ev: Array = enet.service(0)
			match int(ev[0]):
				ENetConnection.EVENT_CONNECT:
					conectado = true
				ENetConnection.EVENT_RECEIVE:
					var p: PackedByteArray = (ev[1] as ENetPacketPeer).get_packet()
					if p.size() == BAUL:
						baul_ok = true
					elif p.size() == GRANDE:
						grande_ok = _grande_bien(p)
					else:
						ecos.append(p.decode_u32(0))
				ENetConnection.EVENT_DISCONNECT:
					conectado = false
				_:
					return

	func mandar(i: int) -> void:
		var b := PackedByteArray()
		b.resize(4)
		b.encode_u32(0, i)
		peer.send(0, b, ENetPacketPeer.FLAG_RELIABLE)

	func mandar_grande() -> void:
		var b := PackedByteArray()
		b.resize(GRANDE)
		for i in GRANDE:
			b[i] = (i * 7 + 3) % 256
		peer.send(0, b, ENetPacketPeer.FLAG_RELIABLE)

	static func _grande_bien(b: PackedByteArray) -> bool:
		for i in GRANDE:
			if b[i] != (i * 7 + 3) % 256:
				return false
		return true


func _servir_sala() -> void:
	while true:
		var ev: Array = sala_enet.service(0)
		match int(ev[0]):
			ENetConnection.EVENT_CONNECT:
				sala_peers.append(ev[1])
			ENetConnection.EVENT_RECEIVE:
				var peer: ENetPacketPeer = ev[1]
				peer.send(0, peer.get_packet(), ENetPacketPeer.FLAG_RELIABLE)   # eco
			ENetConnection.EVENT_DISCONNECT:
				sala_bajas += 1
			_:
				return


func _esperar(cond: Callable, seg: float, amigos: Array) -> bool:
	var t := 0.0
	while t < seg:
		_servir_sala()
		for a in amigos:
			a.servir()
		if cond.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var con_steam := OS.get_cmdline_user_args().has("steam")
	print("== prueba del tunel (%s)" % ("STEAM de verdad" if con_steam else "transporte falso, 10% de perdida"))
	ok(sala_enet.create_host_bound("127.0.0.1", PUERTO_SALA, 32) == OK, "la sala escucha en %d" % PUERTO_SALA)

	var t_sala := Tunel.new()
	add_child(t_sala)
	var tr_sala
	var trs_amigos: Array = []
	if con_steam:
		# En el MISMO proceso Steam exige la cuenta ANTES que el servidor ("No SteamUser023" si no). En el
		# juego de verdad son procesos distintos (el juego y la sala) y el orden da igual.
		var cli: Object = Engine.get_singleton("Steam")
		var r: Dictionary = cli.steamInitEx(480, false)
		ok(int(r.get("status", -1)) == 0, "Steam con la cuenta abierta: %s" % str(r))
		var srv = await _iniciar_steam_servidor()
		if srv == null:
			get_tree().quit(1)
			return
		tr_sala = Tunel.TransporteSteam.new(srv)
		trs_amigos = [Tunel.TransporteSteam.new(cli, tr_sala.mi_id())]
	else:
		tr_sala = Tunel.TransporteFalso.new(0.1)
		trs_amigos = [Tunel.TransporteFalso.new(0.1), Tunel.TransporteFalso.new(0.1)]
	t_sala.abrir_sala(tr_sala, PUERTO_SALA)

	var amigos: Array = []
	var tuneles: Array = []
	for i in trs_amigos.size():
		var t := Tunel.new()
		add_child(t)
		var puerto: int = t.abrir_cliente(trs_amigos[i], tr_sala.mi_id())
		ok(puerto > 0, "tunel del amigo %d abierto en 127.0.0.1:%d" % [i + 1, puerto])
		tuneles.append(t)
		amigos.append(Amigo.new("amigo %d" % (i + 1), puerto))

	# La sala se entera de cada uno un poco DESPUES que el propio amigo (el acuse del saludo de ENet):
	# se esperan las dos cosas.
	var conectados := func(): return amigos.all(func(a): return a.conectado) and sala_peers.size() >= amigos.size()
	ok(await _esperar(conectados, 20.0, amigos), "los amigos conectan con la sala a traves del tunel")
	ok(sala_peers.size() == amigos.size(), "la sala ve %d clientes distintos (ve %d)" % [amigos.size(), sala_peers.size()])

	for a in amigos:
		for i in N:
			a.mandar(i)
		a.mandar_grande()
	var todos_llegan := func():
		return amigos.all(func(a): return a.ecos.size() >= N and a.grande_ok)
	ok(await _esperar(todos_llegan, 30.0, amigos), "vuelven los %d ecos y el paquete grande a cada amigo" % N)
	for a in amigos:
		var en_orden: bool = a.ecos.size() == N
		for i in mini(N, a.ecos.size()):
			en_orden = en_orden and a.ecos[i] == i
		ok(en_orden, "%s: los %d en orden, sin repetidos (%d recibidos)" % [a.nombre, N, a.ecos.size()])
		ok(a.grande_ok, "%s: el paquete de %d bytes llega intacto" % [a.nombre, GRANDE])
	for t in tuneles:
		print("    " + t.resumen())
	print("    " + t_sala.resumen())

	# El BAUL: 2,5 MB de ida y 2,5 de vuelta, cronometrado. Es lo mas gordo que manda el juego.
	var b := PackedByteArray()
	b.resize(BAUL)
	var t0 := Time.get_ticks_msec()
	amigos[0].peer.send(0, b, ENetPacketPeer.FLAG_RELIABLE)
	var llego: bool = await _esperar(func(): return amigos[0].baul_ok, 40.0, amigos)
	ok(llego, "el baul de 2,5 MB va y vuelve en %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))

	# El primero se va; la sala se entera y el otro (si lo hay) sigue.
	amigos[0].peer.peer_disconnect()
	ok(await _esperar(func(): return sala_bajas >= 1, 10.0, amigos), "la sala se entera de que el amigo 1 se va")
	if amigos.size() > 1:
		amigos[1].ecos.clear()
		amigos[1].mandar(0)
		ok(await _esperar(func(): return amigos[1].ecos.size() == 1, 10.0, amigos), "el amigo 2 sigue jugando")

	for t in tuneles:
		t.cerrar()
	t_sala.cerrar()
	sala_enet.destroy()
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)


# La sala como servidor de juego anonimo de Steam (lo que hara la sala de verdad en la F2).
func _iniciar_steam_servidor():
	if not Engine.has_singleton("SteamServer"):
		ok(false, "no hay GodotSteam Server")
		return null
	var srv: Object = Engine.get_singleton("SteamServer")
	var r: Dictionary = srv.serverInitEx("0.0.0.0", 27115, 27116, 2, "0.1")   # 2 = SERVER_MODE_AUTHENTICATION
	ok(int(r.get("status", -1)) == 0, "servidor de juego iniciado: %s" % str(r))
	srv.setProduct("dungeon_oratoria")
	srv.setModDir("dungeon_oratoria")
	srv.setDedicatedServer(true)
	srv.logOnAnonymous()
	var t := 0.0
	while not srv.loggedOn() and t < 20.0:
		srv.run_callbacks()
		await get_tree().process_frame
		t += get_process_delta_time()
	ok(srv.loggedOn(), "la sala entra en Steam como servidor anonimo (%s)" % str(srv.getSteamID()))
	return srv if srv.loggedOn() else null
