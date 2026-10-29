# ============================================================
#  net_canales.gd  (hijo de Net: Net.canales)
#  LOS CANALES DE LA RED (29/10) y la BARRERA para lo que depende de varios.
#
#  POR QUE: ENet entrega lo fiable EN ORDEN dentro de cada canal. Con todo en el 0, un paquete perdido del hogar dejaba
#  esperando a los golpes de la pelea hasta que se reenviaba (Steam por el tunel, wifi). Cada canal espera solo a lo
#  suyo. OJO, MEDIDO: no quita el atasco de un mensaje GORDO (la cola de envio y la ventana de ENet son por conexion,
#  no por canal: 1 MB frena 133 ms al de detras, vaya por el canal que vaya); eso lo quitan el zip y no mandar gordos.
#
#  EL PRECIO: entre canales distintos YA NO HAY ORDEN. Lo que dependa de un mensaje de otro canal tiene que ir en el
#  mismo canal que el, o esperar con la barrera (abajo). Por eso el reparto es por lo que depende de que, no por
#  archivo. Auditados los @rpc (29/10: 197; luego 194, fuera los de mover bichos y pedir crias); los cruces y como se resuelven:
#
#  CONTROL (0)  net.gd y net_jugadores: saludo, permisos, pausa, PRESENCIA (registro, aspecto, grupo, imbuir, apoyo) y
#               el LUGAR de cada jugador. Los manejadores de un jugador tiran lo suyo si aun no esta en _peers, y el
#               registro va aqui: por eso _set_aspecto/_rel_aspecto (net_pisos) van aqui tambien.
#               Y las peticiones de "dame lo que hay aqui" al llegar (_pedir_suelo, _pedir_enemigos): van DETRAS del
#               cambio de lugar, asi la sala ya sabe donde estas cuando contesta. Por otro canal podia contestar antes
#               de saberlo, y lo que se soltara en ese hueco no te llegaba nunca. Las respuestas van por MUNDO.
#  COMBATE (1)  net_peleas (lo fiable). La pelea la ejecuta la sala con sus enemigos de verdad (y alli nacen las crias):
#               el cliente solo le reenvia ids, asi que no depende del orden de MUNDO.
#  MUNDO (2)    lo que hay en los sitios y los VIAJES: net_pisos (salvo el aspecto), enemigos, suelo, recoleccion,
#               jefes, extraccion, pesca y mapa. Los viajes (_viaje_ok, _entrar_ok) llevan la foto de las vetas del
#               piso: tienen que ir en orden con _agotar_celda/_revivir_celda o una foto vieja pisaria una veta ya
#               revivida. Lo de otro sitio se tira por su lugar (PisoVivo.lleva) y al llegar se pide la foto entera.
#  HOGAR (3)    net_hogar y net_formacion.
#  PARTIDA (4)  net_partida: la puerta (_tu_jugador, alta, _listo: cada paso espera la respuesta del anterior) y el
#               GUARDADO, que necesita la barrera: casi todo toca el estado guardado del jugador (desgaste de una pelea,
#               retirar del hogar, recoger del suelo, un pez...), y el estado no puede salir antes de que llegue eso.
#  FOTOS (5)    net_fotos: ya aguanta cualquier orden (la huella espera a su foto, y la sala apunta quien espera).
#
#  LO NO FIABLE (posiciones, ATB, huellas, el charco...) se queda en el 0 a proposito: alli ENet lo lleva por un carril
#  suyo. En un canal propio iria junto a lo fiable de ese canal y esperaria a sus reenvios.
#
#  LA BARRERA: barrera(peer) manda una marca numerada por cada canal; el mensaje que depende lleva ese numero, y el que
#  lo recibe espera (await pasada(...)) a tener la marca en todos. Como cada canal va en orden, tener la marca de un
#  canal es tener todo lo que se mando antes por el.
# ============================================================
extends Node

const CONTROL := 0
const COMBATE := 1
const MUNDO := 2
const HOGAR := 3
const PARTIDA := 4
const FOTOS := 5
const TODOS := [CONTROL, COMBATE, MUNDO, HOGAR, PARTIDA, FOTOS]

# Lo que se espera a una barrera antes de seguir sin ella (y avisar). Las marcas llegan con lo que tuvieran delante:
# esto solo salta si la otra punta se ha ido o el canal esta atascado de verdad.
const PLAZO_BARRERA := 10.0

var _numero := 0                   # la ultima barrera que he mandado (una cuenta para todos los peers)
var _vistas: Dictionary = {}       # peer -> {canal: la ultima marca que me ha llegado de el por ese canal}
var plazos_vencidos := 0           # barreras que no se completaron a tiempo (lo miran las pruebas)


# Manda una marca por cada canal a 'peer' y devuelve su numero, que viaja en el mensaje que depende de lo de antes.
func barrera(peer: int) -> int:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return 0
	_numero += 1
	_marca_control.rpc_id(peer, _numero)
	_marca_combate.rpc_id(peer, _numero)
	_marca_mundo.rpc_id(peer, _numero)
	_marca_hogar.rpc_id(peer, _numero)
	_marca_partida.rpc_id(peer, _numero)
	_marca_fotos.rpc_id(peer, _numero)
	return _numero


# Espera a que me hayan llegado de 'de' las marcas 'n' de todos los canales. true si llegaron; false si vencio el
# plazo (se sigue igual: mejor tarde y avisado que nunca). n = 0 es "sin barrera" (un build de antes): no espera.
func pasada(de: int, n: int) -> bool:
	var hasta: int = Time.get_ticks_msec() + int(PLAZO_BARRERA * 1000.0)
	while not completa(de, n):
		if Time.get_ticks_msec() >= hasta or not Net.activo:
			plazos_vencidos += 1
			push_warning("[canales] la barrera %d de %d no se completo en %.0f s: sigo sin ella" % [n, de, PLAZO_BARRERA])
			return false
		await get_tree().process_frame
	return true


func completa(de: int, n: int) -> bool:
	if n <= 0:
		return true
	var v: Dictionary = _vistas.get(de, {})
	for c in TODOS:
		if int(v.get(c, 0)) < n:
			return false
	return true


func apuntar_marca(de: int, canal: int, n: int) -> void:
	var v: Dictionary = _vistas.get_or_add(de, {})
	v[canal] = maxi(int(v.get(canal, 0)), n)


# Se va un peer: sus marcas no valen para la conexion que traiga si vuelve.
func olvidar_peer(peer: int) -> void:
	_vistas.erase(peer)


func olvidar_sesion() -> void:
	_vistas.clear()
	_numero = 0
	plazos_vencidos = 0


@rpc("any_peer", "call_remote", "reliable", CONTROL)
func _marca_control(n: int) -> void:
	apuntar_marca(multiplayer.get_remote_sender_id(), CONTROL, n)


@rpc("any_peer", "call_remote", "reliable", COMBATE)
func _marca_combate(n: int) -> void:
	apuntar_marca(multiplayer.get_remote_sender_id(), COMBATE, n)


@rpc("any_peer", "call_remote", "reliable", MUNDO)
func _marca_mundo(n: int) -> void:
	apuntar_marca(multiplayer.get_remote_sender_id(), MUNDO, n)


@rpc("any_peer", "call_remote", "reliable", HOGAR)
func _marca_hogar(n: int) -> void:
	apuntar_marca(multiplayer.get_remote_sender_id(), HOGAR, n)


@rpc("any_peer", "call_remote", "reliable", PARTIDA)
func _marca_partida(n: int) -> void:
	apuntar_marca(multiplayer.get_remote_sender_id(), PARTIDA, n)


@rpc("any_peer", "call_remote", "reliable", FOTOS)
func _marca_fotos(n: int) -> void:
	apuntar_marca(multiplayer.get_remote_sender_id(), FOTOS, n)
