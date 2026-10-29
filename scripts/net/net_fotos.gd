# ============================================================
#  net_fotos.gd  (hijo de Net: Net.fotos)
#  LAS FOTOS DE CARA DE LOS PERSONAJES (el PNG de PersonajeData.imagen, hasta ~64 KB). Cada una viaja UNA vez por
#  maquina: por la red solo va su HUELLA (PersonajeData.huella_de), y quien no tiene esa foto la pide.
#
#  COMO VA:
#    publicar(png) -> huella   la apunta en esta maquina. En un CLIENTE, ademas, la sube a la sala la primera vez en la
#                              sesion. La SALA publica las de su partida y jugadores_mundo al construir lo que manda.
#    pedir(huella) -> png      la foto si esta maquina la tiene; si no, vacio, y en un cliente la pide a la sala
#                              (agrupadas por fotograma, una vez por huella). Cuando llega salta `llegada` y quien la
#                              pinta se repinta.
#  El cliente no sube ni pide nada hasta que la sala le ha ADMITIDO (al_entrar): antes, la sala no sabe quien es y lo
#  tira, y el lo daria por hecho. Lo de antes se guarda y sale al entrar.
#  LOS PERSONAJES que llegan por red con la huella de su foto (las fichas de net_partida): poner_en(pj, huella) se la
#  pone ya o, si aun no esta, la apunta como PENDIENTE y se la pone sola al llegar. huella_de_pj es la que viaja.
#  La sala contesta con lo que tenga, y si aun no la tiene (su dueño no la ha subido) apunta quien espera y se la manda
#  en cuanto llega. Asi da igual el orden en que lleguen la subida, el roster y la peticion.
#
#  LAS FOTOS SE QUEDAN entre sesiones (_png): una foto es la misma siempre que tenga la misma huella. Lo que se olvida al
#  cerrar la sesion es lo que la sala sabe de mi (lo subido, lo pedido) y lo que yo se de los demas (quien espera).
#  No crece sin fin: solo entran las de los personajes que hay en los mundos en que se juega.
#
#  NADA SE CREE A CIEGAS: lo que llega tiene que ser un PNG de tamaño razonable y su huella se calcula aqui (la que
#  diga el otro no vale). Al cliente solo le entra lo que pidio; a la sala, un tope de subidas por jugador.
# ============================================================
extends Node

# Ha llegado (o la sala ha recibido) la foto con esa huella: quien la pinte, que se repinte.
signal llegada(huella: int)

# El PNG mas grande posible de una foto de IMAGEN_CUERPO_MAX px por lado sin comprimir, con margen para las cabeceras.
const TOPE_PNG := Game.IMAGEN_CUERPO_MAX * Game.IMAGEN_CUERPO_MAX * 4 + 4096
# Cuantas fotos puede subir un jugador en una sesion: las de sus personajes (y alguna vez que cambie una cara). Es el
# freno a que un cliente roto llene de basura la memoria de la sala.
const SUBIDAS_POR_PEER := 64
# Cuantas huellas caben en una peticion.
const PEDIDAS_POR_MENSAJE := 256
const _FIRMA_PNG := [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]

var _png: Dictionary = {}           # TODAS LAS MAQUINAS: huella -> png (se queda entre sesiones)
var _pjs_esperan: Dictionary = {}   # huella -> [WeakRef de PersonajeData que la esperan] (poner_en)

# --- CLIENTE ---
var _subidas: Dictionary = {}       # huella -> true: ya se la he subido a la sala en esta sesion
var _pedidas: Dictionary = {}       # huella -> true: pedida y aun sin llegar (o ya en _por_pedir)
var _por_pedir: PackedInt64Array = PackedInt64Array()   # lo que sale en la proxima peticion
var _por_subir: Dictionary = {}     # huella -> png: publicadas antes de que la sala me admitiera
var _dentro := false                # ¿me ha admitido ya la sala? (al_entrar)
var recibidas := 0                  # fotos que me han llegado en esta sesion (lo miran las pruebas)

# --- SALA ---
var _esperan: Dictionary = {}       # huella -> [peers que la han pedido y aun no la tengo]
var _subidas_de: Dictionary = {}    # peer -> cuantas me ha subido en esta sesion
var _mandadas: Dictionary = {}      # peer -> {huella: true}: lo que ya le he mandado (no se manda dos veces)
var repetidas := 0                  # peticiones de algo que ya se le habia mandado: un cliente que pide de mas


func _ready() -> void:
	set_process(false)   # solo despierta cuando hay algo que pedir


# Apunta la foto en esta maquina y devuelve su huella (0 si no hay foto). En un cliente la sube a la sala la primera
# vez. 'huella' se puede pasar ya calculada (PersonajeData.huella_imagen la recuerda) para no hacer la SHA otra vez.
func publicar(png: PackedByteArray, huella: int = 0) -> int:
	if png.is_empty():
		return 0
	if huella == 0:
		huella = PersonajeData.huella_de(png)
	if not _png.has(huella):
		_guardar(huella, png)
	if Net._soy_cliente() and not _subidas.has(huella):
		_subidas[huella] = true
		if _dentro:
			_subir.rpc_id(1, png)
		else:
			_por_subir[huella] = png
	return huella


# La de un personaje, con su huella recordada.
func publicar_pj(pj: PersonajeData) -> int:
	return 0 if pj == null else publicar(pj.imagen, pj.huella_imagen())


# La huella que VIAJA como foto de 'pj': la de su foto, o la que espera si aun no le ha llegado.
func huella_de_pj(pj: PersonajeData) -> int:
	if pj == null:
		return 0
	if not pj.imagen.is_empty():
		return publicar_pj(pj)
	return int(pj.get_meta(PersonajeData.META_FOTO_PENDIENTE, 0))


# Le pone a 'pj' la foto de esa huella: ya, si esta maquina la tiene; si no, la pide y se la pone al llegar.
func poner_en(pj: PersonajeData, huella: int) -> void:
	if pj == null or huella == 0:
		return
	var png: PackedByteArray = pedir(huella)
	if not png.is_empty():
		pj.set_imagen(png)
		return
	pj.set_meta(PersonajeData.META_FOTO_PENDIENTE, huella)
	(_pjs_esperan.get_or_add(huella, []) as Array).append(weakref(pj))


# Una foto nueva en esta maquina: se guarda, y les llega a quien la esperaba (la sala a los peers, y los personajes).
func _guardar(h: int, png: PackedByteArray) -> void:
	_png[h] = png
	_atender_esperas(h)
	for w in _pjs_esperan.get(h, []):
		var pj = (w as WeakRef).get_ref()
		if pj != null and int(pj.get_meta(PersonajeData.META_FOTO_PENDIENTE, 0)) == h:
			pj.set_imagen(png)
	_pjs_esperan.erase(h)


# La foto de esa huella, o vacio si esta maquina aun no la tiene (un cliente la pide y avisara con `llegada`).
func pedir(huella: int) -> PackedByteArray:
	if huella == 0:
		return PackedByteArray()
	if _png.has(huella):
		return _png[huella]
	if Net._soy_cliente() and not _pedidas.has(huella):
		_pedidas[huella] = true
		_por_pedir.append(huella)
		set_process(true)
	return PackedByteArray()


func tiene(huella: int) -> bool:
	return _png.has(huella)


# CLIENTE: la sala me acaba de admitir. Sale lo que se publico o pidio antes.
func al_entrar() -> void:
	_dentro = true
	for h in _por_subir:
		_subir.rpc_id(1, _por_subir[h])
	_por_subir.clear()
	set_process(not _por_pedir.is_empty())


# Lo pedido en este fotograma sale en UN mensaje: la UI repinta muchas filas de golpe.
func _process(_delta: float) -> void:
	set_process(false)
	if _por_pedir.is_empty() or not _dentro:
		return   # sin admitir aun: espera a al_entrar
	if Net._soy_cliente():
		for i in range(0, _por_pedir.size(), PEDIDAS_POR_MENSAJE):
			_pedir.rpc_id(1, _por_pedir.slice(i, i + PEDIDAS_POR_MENSAJE))
	_por_pedir = PackedInt64Array()


# ¿Es una foto que se puede guardar? PNG por la firma y de un tamaño que quepa en una foto de cara.
static func valida(png) -> bool:
	if not (png is PackedByteArray):
		return false
	var b: PackedByteArray = png
	if b.size() < _FIRMA_PNG.size() or b.size() > TOPE_PNG:
		return false
	for i in _FIRMA_PNG.size():
		if b[i] != _FIRMA_PNG[i]:
			return false
	return true


# ============================================================
#  LA SALA
# ============================================================
@rpc("any_peer", "call_remote", "reliable")
func _subir(png) -> void:
	if Net.es_host and Net._peers.has(multiplayer.get_remote_sender_id()):   # solo de quien esta dentro
		recibir_subida(multiplayer.get_remote_sender_id(), png)


# Un jugador me sube una foto. Devuelve su huella (0 si no se acepta). La huella la calculo yo: la foto es lo que es.
func recibir_subida(peer: int, png) -> int:
	if int(_subidas_de.get(peer, 0)) >= SUBIDAS_POR_PEER:
		push_warning("[fotos] el peer %d ya ha subido %d fotos en esta sesion: no se aceptan mas" % [peer, SUBIDAS_POR_PEER])
		return 0
	if not valida(png):
		push_warning("[fotos] el peer %d ha subido algo que no es una foto valida" % peer)
		return 0
	_subidas_de[peer] = int(_subidas_de.get(peer, 0)) + 1
	var h: int = PersonajeData.huella_de(png)
	if not _png.has(h):
		_guardar(h, png)
		llegada.emit(h)
	return h


@rpc("any_peer", "call_remote", "reliable")
func _pedir(huellas) -> void:
	if Net.es_host and huellas is PackedInt64Array and Net._peers.has(multiplayer.get_remote_sender_id()):
		atender_peticion(multiplayer.get_remote_sender_id(), huellas)


# Un jugador me pide fotos: las que tengo se las mando ya; las demas, en cuanto lleguen.
func atender_peticion(peer: int, huellas: PackedInt64Array) -> void:
	for h in huellas.slice(0, PEDIDAS_POR_MENSAJE):
		if h == 0:
			continue
		if (_mandadas.get(peer, {}) as Dictionary).has(h):
			repetidas += 1
			continue
		if _png.has(h):
			_mandar(peer, h)
			continue
		var quien: Array = _esperan.get_or_add(h, [])
		if not quien.has(peer):
			quien.append(peer)


func _atender_esperas(h: int) -> void:
	var quien: Array = _esperan.get(h, [])
	_esperan.erase(h)
	for peer in quien:
		if Net._peers.has(peer):
			_mandar(peer, h)


func _mandar(peer: int, h: int) -> void:
	(_mandadas.get_or_add(peer, {}) as Dictionary)[h] = true
	_foto.rpc_id(peer, h, _png[h])


# ============================================================
#  EL CLIENTE
# ============================================================
@rpc("authority", "call_remote", "reliable")
func _foto(huella: int, png) -> void:
	recibir_foto(huella, png)


# Me llega una foto. Solo entra si la pedi, es una foto valida y su huella es la que pedi.
func recibir_foto(huella: int, png) -> bool:
	if not _pedidas.has(huella):
		return false
	_pedidas.erase(huella)
	if not valida(png) or PersonajeData.huella_de(png) != huella:
		push_warning("[fotos] la foto %d ha llegado mal: no se guarda" % huella)
		return false
	_guardar(huella, png)
	recibidas += 1
	llegada.emit(huella)
	return true


# ============================================================
#  OLVIDAR
# ============================================================
# Se va un jugador (SALA): ni sus subidas cuentan ya ni espera nada.
func olvidar_peer(peer: int) -> void:
	_subidas_de.erase(peer)
	_mandadas.erase(peer)
	for h in _esperan.keys():
		(_esperan[h] as Array).erase(peer)
		if (_esperan[h] as Array).is_empty():
			_esperan.erase(h)


# Se acaba la sesion. Las fotos se quedan; lo que la otra punta sabia de mi (y yo de ella), no.
func olvidar_sesion() -> void:
	_subidas.clear()
	_pedidas.clear()
	_por_pedir = PackedInt64Array()
	_por_subir.clear()
	_dentro = false
	set_process(false)
	recibidas = 0
	_esperan.clear()
	_subidas_de.clear()
	_mandadas.clear()
	_pjs_esperan.clear()   # sus peticiones se han perdido con la sesion (los personajes conservan su huella pendiente)
	repetidas = 0
