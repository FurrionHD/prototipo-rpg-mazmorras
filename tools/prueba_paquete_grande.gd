# PRUEBA (sin ventana): ¿aguanta la red un paquete del tamaño del baúl de materiales?
#
# Al abrir el baúl del hogar en multi, el anfitrión manda el almacén ENTERO en UN SOLO RPC fiable
# (net_hogar._taller_ok con _almacen_dicts). Con un baúl de verdad son megas. Esto monta un ENet de
# ida y vuelta en localhost y prueba varios tamaños para ver dónde deja de pasar.
extends SceneTree

const PUERTO := 47913
# Los tamaños que interesan: lo que cabe holgado, el baúl real medido (2,47 MB) y el doble.
const TAMANOS := [64 * 1024, 256 * 1024, 1024 * 1024, 2560 * 1024, 5120 * 1024]

var _malos: int = 0


func _initialize() -> void:
	print("=== UN PAQUETE DEL TAMAÑO DEL BAÚL ===")
	var servidor := ENetConnection.new()
	var err: int = servidor.create_host_bound("127.0.0.1", PUERTO, 4, 4)
	if err != OK:
		print("  MAL  no se pudo abrir el puerto (error %d)" % err)
		quit(1)
		return
	var cliente := ENetConnection.new()
	cliente.create_host(1, 4)
	var peer := cliente.connect_to_host("127.0.0.1", PUERTO, 4)

	var del_servidor: ENetPacketPeer = null
	for i in 200:
		var ev: Array = servidor.service(10)
		if int(ev[0]) == ENetConnection.EVENT_CONNECT:
			del_servidor = ev[1]
		cliente.service(10)
		if del_servidor != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
			break
	if del_servidor == null:
		print("  MAL  el cliente no llegó a conectarse")
		quit(1)
		return
	print("  ok   ENet de ida y vuelta montado en localhost")

	for n in TAMANOS:
		var datos := PackedByteArray()
		datos.resize(n)
		var e: int = del_servidor.send(0, datos, ENetPacketPeer.FLAG_RELIABLE)
		var recibidos: int = 0
		if e == OK:
			for i in 400:
				servidor.service(5)
				var ev: Array = cliente.service(5)
				if int(ev[0]) == ENetConnection.EVENT_RECEIVE:
					recibidos = (ev[1] as ENetPacketPeer).get_packet().size()
					break
		var bien: bool = e == OK and recibidos == n
		print("  %s  %7.2f MB -> send=%d recibidos=%d" % [
			"ok  " if bien else "MAL ", n / 1048576.0, e, recibidos])
		if not bien:
			_malos += 1

	del_servidor.peer_disconnect_now(0)
	cliente.destroy()
	servidor.destroy()
	print("FIN, %d tamaños que NO pasan" % _malos)
	quit(0)
