# ============================================================
#  net_formacion.gd  (hijo de Net: Net.formacion)
#  LA FORMACION: una sola lista ORDENADA con los personajes que van en equipo de TODOS los jugadores
#  del mundo. De izquierda a derecha es como se colocan en la fila del combate, entre los que esten
#  dentro: si entras solo con tu segundo personaje, se pone en SU sitio y no se corre a la izquierda;
#  y si tu compañero y tu estais intercalados, en la pelea tambien.
#
#  QUIEN MANDA: el HOST. Reconcilia la lista cada vez que alguien cambia su equipo (quita a los que
#  ya no van, añade a los nuevos al final sin mover a nadie) y la difunde junto con el roster del hogar.
#  En solitario no hay nada que sincronizar: la formacion es el orden de Game.party.
#
#  MOVER A LOS DE OTRO: cualquiera puede pedir un orden nuevo, pero si desplaza a personajes de otro
#  jugador, el host se lo PREGUNTA a su dueño. Si rechaza (o no contesta en PLAZO_PETICION segundos),
#  se le avisa al que lo pidio de que no quiere el cambio y no se toca nada.
#
#  PUESTOS FIJOS CON HUECOS (16/09, lo pidio el usuario): la formacion son Game.PARTY_MAX puestos y un
#  puesto puede estar VACIO (""). Antes era una lista compacta: quitar a uno corria a los de detras y
#  no se podia dejar a nadie en el puesto 2 con el 1 libre, asi que en compañia, quitar a tu personaje y
#  volver a ponerlo obligaba a mover otra vez al de tu amigo. Ver encajar().
#
#  EL NUMERO DE JUGADOR (P1, P2...): el host es el P1 y el resto va por ORDEN DE LLEGADA. Lo asigna y
#  difunde el host, igual que el recuento de humanos: en estrella un cliente no ve a los otros clientes.
# ============================================================
extends Node

const PLAZO_PETICION := 30.0

# Llega una peticion para mover a personajes MIOS. La UI (peticion_formacion.gd) la enseña y contesta
# con responder(id, ok).
signal peticion_recibida(id: int, de_nombre: String, texto: String)

# --- HOST ---
var _formacion: Array = []     # uids, de izquierda a derecha
var _llegada: Array = []       # identidades, por orden de llegada (la del host la primera)
var _peticiones: Dictionary = {}   # id -> {nueva, pide, pide_peer, faltan, t}
var _siguiente_id: int = 1

# --- SOLITARIO: los puestos (con huecos) de tu equipo ---
var _formacion_solo: Array = []

# --- CLIENTE: lo que difundio el host ---
var _formacion_mirror: Array = []
var _llegada_mirror: Array = []


# ============================================================
#  LEER
# ============================================================

# La formacion vigente (uids).
# PUESTOS: un uid por puesto, "" = vacio.
func formacion() -> Array:
	if not Net.activo:
		var van: Array = []
		for pj in Game.party:
			van.append(String(pj.uid))
		_formacion_solo = encajar(_formacion_solo, van)
		return _formacion_solo
	return _formacion_mirror if Net._soy_cliente() else _formacion


# ENCAJAR a quienes van en unos puestos: el que ya tenia puesto se queda EN EL SUYO, el que ya no va deja
# su puesto VACIO (sin correr a nadie) y el nuevo ocupa el primer hueco libre.
static func encajar(puestos: Array, van: Array) -> Array:
	var out: Array = puestos.duplicate()
	while out.size() < Game.PARTY_MAX:
		out.append("")
	for i in out.size():
		if not String(out[i]).is_empty() and not van.has(String(out[i])):
			out[i] = ""
	for u in van:
		if String(u).is_empty() or out.has(u):
			continue
		var libre: int = out.find("")
		if libre >= 0:
			out[libre] = u
		else:
			out.append(u)
	while out.size() > Game.PARTY_MAX and String(out[-1]).is_empty():
		out.pop_back()
	return out


# SOLITARIO: los puestos que se confirmaron en el editor del hogar.
func fijar_solo(puestos: Array) -> void:
	_formacion_solo = puestos.duplicate()


func pos_de(uid: String) -> int:
	if uid.is_empty():
		return -1
	return formacion().find(uid)


# El numero de jugador de una identidad (1 = el host), o 0 si no esta en la sesion.
func num_jugador(identidad: String) -> int:
	if not Net.activo:
		return 1
	var lista: Array = _llegada_mirror if Net._soy_cliente() else _llegada
	return lista.find(identidad) + 1


# ============================================================
#  HOST: RECONCILIAR
#  La llama Net.hogar._difundir_hogar antes de mandar el roster, asi la formacion viaja siempre con
#  el roster del que sale y no pueden llegar desfasados.
# ============================================================

func reconciliar() -> void:
	if not (Net.activo and Net.es_host):
		return
	# Quienes estan conectados, el host el primero.
	var conectados: Array = [Identidad.id]
	for peer in Net._identidades:
		var ident: String = String(Net._identidades[peer])
		if not ident.is_empty() and not conectados.has(ident):
			conectados.append(ident)
	for ident in _llegada.duplicate():
		if not conectados.has(ident):
			_llegada.erase(ident)
	for ident in conectados:
		if not _llegada.has(ident):
			_llegada.append(ident)

	# Quien va en equipo AHORA, por jugador y en el orden de SU equipo.
	var van: Array = []
	for pj in Game.party:
		if not String(pj.uid).is_empty():
			van.append(String(pj.uid))
	for ident in _llegada:
		if ident == Identidad.id:
			continue
		var filas: Array = (Net.hogar._roster_ajeno.get(ident, []) as Array).duplicate()
		filas.sort_custom(func(a, b): return int(a.get("pos_equipo", 99)) < int(b.get("pos_equipo", 99)))
		for f in filas:
			if bool(f.get("en_equipo", false)):
				van.append(String(f.get("uid", "")))
	# Los que ya no van dejan su puesto VACIO; los nuevos, al primer hueco (sin mover a nadie de su sitio).
	_formacion = encajar(_formacion, van)


# El host manda la formacion a todos. Va DESPUES de _set_roster_hogar (ver Net.hogar._difundir_hogar).
func difundir() -> void:
	if Net.activo and Net.es_host:
		_set_formacion.rpc(_formacion, _llegada)


@rpc("authority", "call_remote", "reliable")
func _set_formacion(lista: Array, llegada: Array) -> void:
	_formacion_mirror = lista
	_llegada_mirror = llegada
	Net.hogar_cambiado.emit()


# ============================================================
#  PEDIR UN ORDEN NUEVO
# ============================================================

# 'nueva' = los MISMOS uids que la formacion actual, en otro orden. En solitario se aplica al momento.
func pedir_orden(nueva: Array) -> void:
	if not Net.activo:
		fijar_solo(nueva)
		return
	if Net._soy_cliente():
		_pedir_orden.rpc_id(1, nueva)
	else:
		_resolver_orden(nueva, Identidad.id, Identidad.nombre, 1)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_orden(nueva: Array) -> void:
	if not Net.es_host:
		return
	var peer: int = multiplayer.get_remote_sender_id()
	var ident: String = Net.hogar._identidad_de_peer(peer)
	if ident.is_empty():
		return
	_resolver_orden(nueva, ident, _nombre_de(ident), peer)


# HOST: ¿el orden nuevo desplaza a personajes de OTROS? Si no, se aplica; si si, se pregunta.
func _resolver_orden(nueva: Array, pide: String, pide_nombre: String, pide_peer: int) -> void:
	if not _mismo_conjunto(nueva, _formacion):
		_avisar(pide_peer, "El equipo ha cambiado mientras tanto: vuelve a intentarlo.")
		difundir()
		return
	var duenos: Dictionary = _duenos()
	var faltan: Array = []
	for i in nueva.size():
		var u: String = String(nueva[i])
		if u.is_empty():
			continue
		var dueno: String = String(duenos.get(u, ""))
		if dueno != pide and _formacion.find(u) != i and not faltan.has(dueno) and not dueno.is_empty():
			faltan.append(dueno)
	if faltan.is_empty():
		_aplicar(nueva)
		return
	var id: int = _siguiente_id
	_siguiente_id += 1
	_peticiones[id] = {"nueva": nueva, "pide": pide, "pide_nombre": pide_nombre,
		"pide_peer": pide_peer, "faltan": faltan, "t": 0.0}
	var texto: String = _texto_peticion(nueva, duenos, pide_nombre)
	for dueno in faltan:
		var peer: int = 1 if dueno == Identidad.id else Net.hogar.peer_de_identidad(dueno)
		if peer == 1:
			peticion_recibida.emit(id, pide_nombre, texto)
		elif peer != 0:
			_peticion.rpc_id(peer, id, pide_nombre, texto)
	_avisar(pide_peer, "Se lo has pedido a %s." % _nombres(faltan))


@rpc("authority", "call_remote", "reliable")
func _peticion(id: int, de_nombre: String, texto: String) -> void:
	peticion_recibida.emit(id, de_nombre, texto)


# La contestacion de la UI (en la maquina del dueño).
func responder(id: int, ok: bool) -> void:
	if Net._soy_cliente():
		_respuesta.rpc_id(1, id, ok)
	else:
		_resolver_respuesta(id, ok, Identidad.id)


@rpc("any_peer", "call_remote", "reliable")
func _respuesta(id: int, ok: bool) -> void:
	if Net.es_host:
		_resolver_respuesta(id, ok, Net.hogar._identidad_de_peer(multiplayer.get_remote_sender_id()))


func _resolver_respuesta(id: int, ok: bool, quien: String) -> void:
	if not _peticiones.has(id):
		return
	var p: Dictionary = _peticiones[id]
	if not (p["faltan"] as Array).has(quien):
		return
	if not ok:
		_peticiones.erase(id)
		_avisar(int(p["pide_peer"]), "%s no quiere hacer el cambio." % _nombre_de(quien))
		return
	(p["faltan"] as Array).erase(quien)
	if not (p["faltan"] as Array).is_empty():
		return
	_peticiones.erase(id)
	if not _mismo_conjunto(p["nueva"], _formacion):
		_avisar(int(p["pide_peer"]), "El equipo ha cambiado mientras tanto: vuelve a intentarlo.")
		return
	_aplicar(p["nueva"])
	_avisar(int(p["pide_peer"]), "%s acepta el cambio." % _nombre_de(quien))


func _process(delta: float) -> void:
	if _peticiones.is_empty() or not (Net.activo and Net.es_host):
		return
	for id in _peticiones.keys():
		var p: Dictionary = _peticiones[id]
		p["t"] = float(p["t"]) + delta
		if float(p["t"]) >= PLAZO_PETICION:
			_peticiones.erase(id)
			_avisar(int(p["pide_peer"]), "%s no ha contestado: no se hace el cambio." % _nombres(p["faltan"]))


func _aplicar(nueva: Array) -> void:
	_formacion = nueva.duplicate()
	difundir()
	Net.hogar_cambiado.emit()


# ============================================================
#  AYUDAS
# ============================================================

# ¿Los mismos personajes, esten en el puesto que esten? Los huecos no cuentan.
func _mismo_conjunto(a: Array, b: Array) -> bool:
	var sa: Array = a.filter(func(u): return not String(u).is_empty())
	var sb: Array = b.filter(func(u): return not String(u).is_empty())
	if sa.size() != sb.size():
		return false
	for u in sa:
		if not sb.has(u):
			return false
	return true


# uid -> identidad del dueño, sacado del roster del hogar.
func _duenos() -> Dictionary:
	var out: Dictionary = {}
	for f in Net.hogar.roster_hogar():
		out[String(f.get("uid", ""))] = String(f.get("dueno", ""))
	return out


func _nombre_de(identidad: String) -> String:
	if identidad == Identidad.id:
		return Identidad.nombre
	var jd: JugadorData = Game.jugadores_mundo.get(identidad)
	if jd != null and not jd.nombre_visible.is_empty():
		return jd.nombre_visible
	for f in Net.hogar.roster_hogar():
		if String(f.get("dueno", "")) == identidad and not String(f.get("dueno_nombre", "")).is_empty():
			return String(f["dueno_nombre"])
	return "Tu compañero"


func _nombres(identidades: Array) -> String:
	var n: Array = []
	for i in identidades:
		n.append(_nombre_de(String(i)))
	return ", ".join(n)


# "Fulano quiere poner a Tu Personaje en el puesto 2."
func _texto_peticion(nueva: Array, duenos: Dictionary, pide_nombre: String) -> String:
	var nombres: Dictionary = {}
	for f in Net.hogar.roster_hogar():
		nombres[String(f.get("uid", ""))] = String(f.get("nombre", "?"))
	var cambios: Array = []
	for i in nueva.size():
		var u: String = String(nueva[i])
		if u.is_empty():
			continue
		if _formacion.find(u) != i:
			cambios.append("%s al puesto %d" % [nombres.get(u, "?"), i + 1])
	return "%s quiere cambiar el orden del equipo: %s." % [pide_nombre, ", ".join(cambios)]


# Un aviso al que pidio: toast local si es el host, remoto si es un cliente.
func _avisar(peer: int, texto: String) -> void:
	if peer == 1 or peer == 0:
		Net._toast(texto)
	else:
		Net.hogar._aviso_remoto.rpc_id(peer, texto)
