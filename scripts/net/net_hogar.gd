# ============================================================
#  net_hogar.gd  (hijo de Net: /root/Net/Hogar)
#  EL HOGAR COMPARTIDO en multi: bote, cofres de equipo y consumibles, cupo del banner de novato,
#  biblioteca, recetas descubiertas, ENCARGOS y quien hay en casa (roster), el baul de materiales con
#  su candado de taller y las reservas en vivo. Manda el host; el cliente ve espejos (*_visible).
#  Se llama como Net.hogar.<funcion>. Las SEÑALES hogar_cambiado y reservas_cambiadas siguen en Net:
#  los menus preguntan por ellas con Net.has_signal.
# ============================================================
extends Node

# Lo que la UI del hogar debe MOSTRAR: en solitario/host, lo de Game; de cliente, el mirror del host.
func bote_visible() -> int:
	return _bote_mirror if Net._soy_cliente() else Game.bote_dinero
func cofre_visible() -> Array:
	return _cofre_mirror if Net._soy_cliente() else Game.cofre_equipo
func cofre_consumibles_visible() -> Dictionary:
	return _cofre_consum_mirror if Net._soy_cliente() else Game.cofre_consumibles
func encargos_visibles() -> Array:
	return _encargos_mirror if Net._soy_cliente() else Game.encargos
# Las tiradas ya gastadas del banner de novato. La pantalla del maestro lee SIEMPRE de aqui y nunca
# de Game.tiradas_novato: un cliente que mirase su propia copia creeria tener 30 cuando el host las
# tiene gastadas, y le dejaria darle al boton para nada.
func tiradas_novato_visibles() -> int:
	return _tiradas_novato_mirror if Net._soy_cliente() else Game.tiradas_novato

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
	if Net._soy_cliente():
		_pedir_depositar.rpc_id(1, n)
	else:
		Game.bote_dinero += n
		_difundir_bote()
	return true


func retirar_bote(n: int) -> void:
	if n <= 0:
		return
	if Net._soy_cliente():
		_pedir_retirar.rpc_id(1, n)
	else:
		_resolver_retiro(n, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_depositar(n: int) -> void:
	if not Net.es_host or n <= 0:
		return
	Game.bote_dinero += n
	_difundir_bote()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_retirar(n: int) -> void:
	if not Net.es_host:
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
	Net.peleas._aviso_esquina(texto)


# Difunde el bote a los clientes (solo si hay sesion) y refresca la UI.
func _difundir_bote() -> void:
	if Net.activo:
		_set_bote.rpc(Game.bote_dinero)
	Net.hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_bote(v: int) -> void:
	_bote_mirror = v   # cliente: reflejo del bote del host
	Net.hogar_cambiado.emit()


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
	if Net._soy_cliente():
		_pedir_tiradas_novato.rpc_id(1, n)
	else:
		_resolver_tiradas_novato(n, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_tiradas_novato(n: int) -> void:
	if not Net.es_host:
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
	if Net.activo:
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
	if Net.es_host:
		_apuntar_tomo.rpc(id)


# Avisa a la sesion de que este tomo ya esta leido. Lo llama Game; aqui vive el reparto.
func apuntar_tomo_en_la_sesion(id: StringName) -> void:
	if not Net.activo or id == &"":
		return
	if Net.es_host:
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
	Net.hogar_cambiado.emit()   # los menus de crafteo abiertos se repintan con lo nuevo


@rpc("any_peer", "call_remote", "reliable")
func _apuntar_visto(id: String) -> void:
	if id == "" or Game.vistos_mundo.has(id):
		return
	Game.vistos_mundo[id] = true
	Net.hogar_cambiado.emit()
	if Net.es_host:
		_apuntar_visto.rpc(id)   # el host lo reparte a los demas (en estrella no se ven entre ellos)


# Lo llama Game.descubrir cuando alguien ve un material por primera vez.
func apuntar_visto_en_la_sesion(id: String) -> void:
	if not Net.activo or id == "":
		return
	if Net.es_host:
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
	if Net._soy_cliente():
		_pedir_meter_cofre.rpc_id(1, d)
	else:
		_apuntar_en_cofre(d)
	return true


@rpc("any_peer", "call_remote", "reliable")
func _pedir_meter_cofre(d: Dictionary) -> void:
	if not Net.es_host:
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
	if Net._soy_cliente():
		_pedir_sacar_cofre.rpc_id(1, id)
	else:
		_resolver_saca_cofre(id, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_sacar_cofre(id: int) -> void:
	if not Net.es_host:
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
			Net.peleas._aviso_esquina("Esa pieza está en un encargo")
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
	Net.hogar_cambiado.emit()


func _difundir_cofre() -> void:
	if Net.activo:
		_set_cofre.rpc(Game.cofre_equipo)
	Net.hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_cofre(lista: Array) -> void:
	_cofre_mirror = lista   # cliente: reflejo del cofre del host
	Net.hogar_cambiado.emit()


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
	if Net._soy_cliente():
		_pedir_encargo.rpc_id(1, piso, tipos, duracion, uids, cofre_ids, faenas, clases)
	else:
		# El host tambien pasa por la aduana: el que se le puede haber ido del selector es un
		# personaje DEL COMPAÑERO, y eso Game.enviar_encargo no lo sabe mirar (su party es la de aqui).
		if Net.activo:
			var motivo: String = _motivo_no_disponible(uids)
			if not motivo.is_empty():
				Net.peleas._toast(motivo)
				_difundir_hogar()
				return
		if Game.enviar_encargo(piso, tipos, duracion, uids, cofre_ids, faenas, clases) != 0:
			_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_encargo(piso: int, tipos: Array, duracion: int, uids: Array, cofre_ids: Array,
		faenas: Dictionary = {}, clases: Dictionary = {}) -> void:
	if not Net.es_host:
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
		e["quien_manda"] = Net._identidad_de_peer(quien)
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
	if Net._soy_cliente():
		_pedir_traer_encargo.rpc_id(1, id)
	else:
		if Game.traer_encargo(id):
			_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_traer_encargo(id: int) -> void:
	if Net.es_host and Game.traer_encargo(id):
		_difundir_hogar()


# DEV (temporal): terminar UNO al 100%, como si hubiera pasado su tiempo entero. Va por la red como
# los demas para que tambien sirva probando en multi.
func solicitar_dev_terminar_encargo(id: int) -> void:
	if Net._soy_cliente():
		_pedir_dev_terminar_encargo.rpc_id(1, id)
	elif Game.dev_terminar_encargo(id):
		_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_dev_terminar_encargo(id: int) -> void:
	if Net.es_host and Game.dev_terminar_encargo(id):
		_difundir_hogar()


func solicitar_recoger_encargo(id: int) -> void:
	if Net._soy_cliente():
		_pedir_recoger_encargo.rpc_id(1, id)
	else:
		var inf: Dictionary = Game.recoger_encargo(id)
		if not inf.is_empty():
			_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_recoger_encargo(id: int) -> void:
	if not Net.es_host:
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
	if Net._soy_cliente():
		_pedir_repaso_encargos.rpc_id(1)
	elif Game.repasar_encargos() > 0:
		_difundir_hogar()


@rpc("any_peer", "call_remote", "reliable")
func _pedir_repaso_encargos() -> void:
	if Net.es_host and Game.repasar_encargos() > 0:
		_difundir_hogar()


# UNA sola difusion para las tres cosas del hogar que van juntas (encargos, cofre y roster), en
# ORDEN FIJO. Publicar dos valores distintos del mismo estado en un mismo rebuild es lo que cuelga
# al invitado, asi que el roster se construye UNA vez y se manda esa copia.
func _difundir_hogar() -> void:
	if Net.activo and Net.es_host:
		var roster: Array = _construir_roster()
		_set_encargos.rpc(Game.encargos)
		_set_cofre.rpc(Game.cofre_equipo)
		_set_roster_hogar.rpc(roster)
		_roster_mirror = roster
	Net.hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_encargos(lista: Array) -> void:
	_encargos_mirror = lista
	# EL ENCARGO GANA, EL EQUIPO CEDE. Si uno de los MIOS acaba de salir de encargo, se va del
	# equipo aqui mismo. Es lo que hace _aplicar_cupo con el cupo de sesion: nada de handshakes,
	# gana el estado que difunde el host y cada maquina se ajusta sola.
	for pj in Game.plantilla.duplicate():
		if Game.party.has(pj) and Game.esta_de_encargo(pj):
			Game.sacar_del_equipo(pj)
	Net.hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_roster_hogar(lista: Array) -> void:
	_roster_mirror = lista
	Net.hogar_cambiado.emit()


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
	if Net.activo:
		_hogar_sucio = true


# Corre en EL HOST: un jugador me dice como esta su hogar AHORA.
@rpc("any_peer", "call_remote", "reliable")
func _mi_hogar(filas: Array) -> void:
	if not Net.es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	var identidad: String = Net._identidad_de_peer(quien)
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
	if Net._soy_cliente():
		return _roster_mirror
	return _construir_roster()


func _identidad_de_peer(peer: int) -> String:
	return String(Net._identidades.get(peer, ""))


# El peer de una identidad, o 0 si no esta conectada. Es lo que decide cual de las DOS VIAS de la
# excelia se toma (ver Game.recoger_encargo): mandarsela, o escribirla en su JugadorData.
func peer_de_identidad(identidad: String) -> int:
	if identidad.is_empty() or not Net.activo:
		return 0
	for peer in Net._identidades:
		if String(Net._identidades[peer]) == identidad:
			return int(peer)
	return 0


# El host le manda a un jugador la excelia que se han ganado SUS personajes en un encargo.
func mandar_excelia(identidad: String, entradas: Array) -> void:
	var peer: int = Net.peer_de_identidad(identidad)
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
		Net.peleas._aviso_esquina("Los tuyos han vuelto de un encargo")


# Y el PARTE DE TRABAJO: las pasivas RNG y los contadores ocultos de los desarrollos. Va por su
# propio RPC pero por la MISMA via y el mismo motivo que la excelia — solo esta maquina tiene sus
# PersonajeData. Si esto solo se enganchara en Game.recoger_encargo, el compañero conectado se
# quedaria sin pasivas y sin contadores y no habria ni un error que lo dijera.
func mandar_partes_encargo(identidad: String, partes: Array) -> void:
	var peer: int = Net.peer_de_identidad(identidad)
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
	if Net._soy_cliente():
		_pedir_meter_consumible.rpc_id(1, ruta, quita)
	else:
		_apuntar_consumible(ruta, quita)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_meter_consumible(ruta: String, n: int) -> void:
	if Net.es_host:
		_apuntar_consumible(ruta, n)


# Host o solitario: apunta en Game.cofre_consumibles (persiste).
func _apuntar_consumible(ruta: String, n: int) -> void:
	Game.cofre_consumibles[ruta] = int(Game.cofre_consumibles.get(ruta, 0)) + n
	_difundir_cofre_consumibles()


func sacar_consumible_cofre(ruta: String, n: int) -> void:
	if Net._soy_cliente():
		_pedir_sacar_consumible.rpc_id(1, ruta, n)
	else:
		_resolver_saca_consumible(ruta, n, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_sacar_consumible(ruta: String, n: int) -> void:
	if Net.es_host:
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
	Net.hogar_cambiado.emit()


func _difundir_cofre_consumibles() -> void:
	if Net.activo:
		_set_cofre_consumibles.rpc(Game.cofre_consumibles)
	Net.hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_cofre_consumibles(d: Dictionary) -> void:
	_cofre_consum_mirror = d   # cliente: reflejo del cofre del host
	Net.hogar_cambiado.emit()


# --- BAUL de materiales compartido + candado del taller (hito 4) ------------------------------

func _almacen_dicts() -> Array:
	var out: Array = []
	for m in Game.almacen_materiales:
		out.append(Net.suelo._item_a_dict(m))
	return out


func _cargar_almacen(arr: Array) -> void:
	var lista: Array[MaterialItem] = []
	for d in arr:
		var it := Net.suelo._item_de_dict(d)
		if it is MaterialItem:
			lista.append(it)
	Game.almacen_materiales = lista


# La llama un menu de taller (herrero/carpintero/boticaria/peletero) al abrir, o una accion
# suelta (depositar/vender del hogar) antes de tocar el baul. true = tienes el taller y tu
# Game.almacen_materiales YA es el baul autoritativo; false = esta ocupado por tu companero.
# ¿Lo tiene prestado OTRO? Solo el host puede preguntarlo con sentido (es quien arbitra el candado).
# Lo usa el cobro de un encargo para no pisar el almacen comun mientras alguien craftea.
func taller_ocupado() -> bool:
	return Net.activo and Net.es_host and _taller_dueno != 0 and _taller_dueno != 1


func abrir_taller() -> bool:
	if not Net.activo:
		return true   # solitario: el baul es tuyo y punto
	if Net.es_host:
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
	if not Net.es_host:
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
	if not Net.activo:
		return
	if Net.es_host:
		if _taller_dueno == 1:
			_taller_dueno = 0
			_difundir_almacen()   # mi baul (ya modificado) va a los mirrors
	else:
		_soltar_taller.rpc_id(1, _almacen_dicts())
		_taller_dueno = 0   # ya lo solte: dejo de "tenerlo" y el _set_almacen del host vuelve a valer


@rpc("any_peer", "call_remote", "reliable")
func _soltar_taller(bag: Array) -> void:
	if not Net.es_host:
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
	if not Net.activo:
		return true
	return _taller_dueno == multiplayer.get_unique_id()


func _difundir_almacen() -> void:
	_set_almacen.rpc(_almacen_dicts())
	Net.hogar_cambiado.emit()


@rpc("authority", "call_remote", "reliable")
func _set_almacen(bag: Array) -> void:
	# No piso mi baul si soy YO quien tiene el taller prestado (estoy crafteando con el).
	if _taller_dueno == multiplayer.get_unique_id():
		return
	_cargar_almacen(bag)
	Net.hogar_cambiado.emit()


# --- RESERVA de materiales EN VIVO (profesiones concurrentes) --------------------------------

# Cuantas unidades de (mat_id, calidad) tiene reservadas OTRA gente ahora mismo (no cuento las mias:
# las mias ya estan reflejadas en mi propia seleccion). Lo consulta la UI: disponible = baul - esto.
func reservado_por_otros(mat_id: String, calidad: int) -> int:
	if not Net.activo:
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
	if not Net.activo:
		return
	if _misma_reserva(claim, _mi_reserva_local):
		return
	_mi_reserva_local = claim.duplicate()
	if Net.es_host:
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
	if not Net.es_host:
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
	Net.reservas_cambiadas.emit()


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
	Net.reservas_cambiadas.emit()


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


# EL HOGAR, agrupado por frame (ver _hogar_sucio): publicar tu equipo no tiene nada que ver con estar en
# la mazmorra, asi que no mira ni si soy host ni si hay expedicion.
func _process(_delta: float) -> void:
	if not _hogar_sucio:
		return
	_hogar_sucio = false
	if Net._soy_cliente():
		_mi_hogar.rpc_id(1, _mis_filas_hogar())
	elif Net.es_host:
		_difundir_hogar()
