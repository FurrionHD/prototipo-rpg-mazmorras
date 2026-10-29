# ============================================================
#  net_extraccion.gd  (hijo de Net: /root/Net/Extraccion)
#  EXTRAER UN CADAVER en multi: se le pide el cuerpo al dueño del piso (candado compartido con las
#  peleas en Net.peleas._enem_ocupados), se consume o se suelta, y se difunde quien esta extrayendo que para
#  que la F de los demas lo esquive. Se llama como Net.extraccion.<funcion>.
# ============================================================
extends Node

# Cuerpos que alguien esta EXTRAYENDO ahora mismo (net_id -> peer). El candado DURO sigue siendo
# _enem_ocupados (compartido con las peleas); esto es SOLO el subconjunto de extracciones, y existe
# para poder DIFUNDIRLO: sin el, con los dos jugadores juntos y dos cuerpos al lado los dos apuntaban
# al MISMO (el mas cercano de cada uno) y el segundo se comia un "esta ocupado" creyendo que iba al
# otro cuerpo. Ahora la F esquiva los cuerpos que trabaja otro (ver cuerpo_ocupado_por_otro).
# En el DUEÑO del piso es autoritativo; en los demas es el reflejo que llega por _set_extrayendo.
var _extrayendo: Dictionary = {}
# ¿Tengo una peticion de extraccion EN VUELO? Sin esto, entre la F y la respuesta del dueño no habia
# nada que lo marcara: una segunda F mandaba otra peticion y dejaba candados huerfanos por el camino.
var _extraccion_pidiendo: bool = false


# --- EXTRAER UN CADAVER (hito 5.3) ------------------------------------------------------------
#
# Mismo candado que las vetas, pero por CUERPO: dos no pueden sacarle el cristal al mismo cadaver.
# Lo arbitra el dueño del piso (la sala), que es quien tiene el cuerpo de verdad. Devuelve true si puedo
# empezar YA (sin red); si no, la respuesta llega por _extraccion_concedida.
func solicitar_extraccion(id: int) -> bool:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return true
	# Una peticion a la vez: la respuesta tarda un viaje de ida y vuelta y en ese hueco una segunda F
	# (o un paso que cambia cual es el cuerpo mas cercano) mandaba otra peticion y dejaba el candado
	# del primer cuerpo puesto para siempre.
	if _extraccion_pidiendo:
		return false
	_extraccion_pidiendo = true
	if Net.es_host:
		_encaminar_extraccion(id, Net._mi_lugar, 1)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_extraccion.rpc_id(1, id, Net._mi_lugar)
	return false   # hay que esperar respuesta: la pantalla la abre _extraccion_concedida


@rpc("any_peer", "call_remote", "reliable")
func _pedir_extraccion(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_extraccion(id, lugar, multiplayer.get_remote_sender_id())


func _encaminar_extraccion(id: int, lugar: String, quien: int) -> void:
	if PisoVivo.dueno_de(lugar):
		_resolver_extraccion(id, quien)
		return
	_responder_extraccion(quien, id, false)   # ese piso no lo lleva la sala: no hay cuerpo que dar


# SOLO el dueño: concede el cuerpo al primero que lo pida. Idempotente: si el candado YA es de quien
# pregunta, se le vuelve a conceder (una re-peticion suya no es una colision).
func _resolver_extraccion(id: int, quien: int) -> void:
	var mio_ya: bool = Net.peleas._enem_ocupados.has(id) and int(Net.peleas._enem_ocupados[id]) == quien
	var libre: bool = Net.enemigos._enemigos.has(id) and (mio_ya or not Net.peleas._enem_ocupados.has(id))
	if libre:
		Net.peleas._enem_ocupados[id] = quien
		_apuntar_extrayendo(id, quien)
	_responder_extraccion(quien, id, libre)


# Misma regla que _responder_pelea: comparar con MI id, no con 1.
func _responder_extraccion(quien: int, id: int, ok: bool) -> void:
	if quien == multiplayer.get_unique_id():
		_extraccion_concedida(id, ok)
	else:
		_extraccion_concedida.rpc_id(quien, id, ok)


# Corre en QUIEN PIDIO extraer: si se la han dado, se abre el minijuego sobre SU cuerpo espejado.
@rpc("any_peer", "call_remote", "reliable")
func _extraccion_concedida(id: int, ok: bool) -> void:
	_extraccion_pidiendo = false   # la peticion ya no esta en vuelo, salga bien o mal
	if not ok:
		Net._toast("Ese cuerpo lo está trabajando tu compañero.")
		return
	var n = Net.enemigos._enem_nodos.get(id)
	# Si el cuerpo ya no esta, o si mientras viajaba la respuesta se me ha puesto una pantalla delante
	# (una pelea, otro minijuego), Game.start_extraction se iria de vacio y el candado se quedaria
	# puesto PARA SIEMPRE: ese cuerpo diria "ocupado" el resto de la sesion aunque nadie lo trabajara.
	# Era la razon de que el bug se "pegara" y reapareciera luego sin motivo. Se devuelve el candado.
	if n == null or not is_instance_valid(n) or Game.hay_pelea_en_pantalla():
		soltar_extraccion(id)
		return
	# La marca ANTES de reentrar, o start_extraction volveria a pedir permiso en bucle.
	n.set_meta("permiso_extraccion", true)
	Game.start_extraction(n)


# La llama Game al TERMINAR de extraer: el cuerpo de verdad se desvanece en la maquina del dueño
# (y su _exit_tree despawnea los espejos de todos). Suelta tambien el candado.
func notificar_extraido(id: int) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_encaminar_consumir(id, Net._mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_consumir.rpc_id(1, id, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_consumir(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_consumir(id, lugar)


func _encaminar_consumir(id: int, lugar: String) -> void:
	if PisoVivo.dueno_de(lugar):
		_consumir_cadaver(id)


# Suelto el cuerpo SIN haberlo extraido (me han quitado la pantalla, el cuerpo se fue con el piso
# viejo, o el minijuego se auto-cancelo). Gemela de notificar_extraido pero sin desvanecer nada: solo
# devuelve el candado, que si no se queda puesto para siempre.
func soltar_extraccion(id: int) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_encaminar_soltar_cuerpo(id, Net._mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_soltar_cuerpo.rpc_id(1, id, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_soltar_cuerpo(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_soltar_cuerpo(id, lugar)


func _encaminar_soltar_cuerpo(id: int, lugar: String) -> void:
	if PisoVivo.dueno_de(lugar):
		_liberar_cadaver(id)


# SOLO el dueño: devuelve el candado de un cuerpo que sigue ahi, intacto y extraible.
func _liberar_cadaver(id: int) -> void:
	Net.peleas._enem_ocupados.erase(id)
	_borrar_extrayendo(id)


# --- Difusion de los cuerpos que se estan extrayendo -------------------------------------------
#
# La lleva el DUEÑO del piso, que con red es siempre la sala (etapa 2): la reparte a todos.

func _apuntar_extrayendo(id: int, quien: int) -> void:
	if int(_extrayendo.get(id, 0)) == quien:
		return
	_extrayendo[id] = quien
	_difundir_extrayendo(_lugar_de(id))


func _borrar_extrayendo(id: int) -> void:
	if not _extrayendo.has(id):
		return
	var lugar: String = _lugar_de(id)
	_extrayendo.erase(id)
	_difundir_extrayendo(lugar)


# A CADA UNO, LO DE SU PISO: los cuerpos de otro piso no los tiene. 'lugar' = solo a los de ese sitio (lo que ha
# cambiado); vacio = a todos, cada uno lo suyo. Quien llega a un piso lo recibe con sus enemigos (_pedir_enemigos).
func _difundir_extrayendo(lugar: String = "") -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		for p in Net._peers:
			var suyo: String = String(Net._peers[p].get("lugar", ""))
			if suyo.begins_with("piso:") and (lugar.is_empty() or suyo == lugar):
				_set_extrayendo.rpc_id(p, del_lugar(suyo))


# Los cuerpos que se estan extrayendo en ese sitio.
func del_lugar(lugar: String) -> Dictionary:
	var out: Dictionary = {}
	for id in _extrayendo:
		if _lugar_de(id) == lugar:
			out[id] = _extrayendo[id]
	return out


func _lugar_de(id: int) -> String:
	return String((Net.enemigos._enemigos.get(id, {}) as Dictionary).get("lugar", ""))


@rpc("any_peer", "call_remote", "reliable")
func _set_extrayendo(d: Dictionary) -> void:
	_extrayendo = d.duplicate()


# ¿Ese cuerpo lo esta trabajando OTRO? Lo consulta player._mas_cercano_en_grupo para no apuntar a un
# cuerpo que ya tiene dueño: asi dos jugadores juntos apuntan a cuerpos DISTINTOS en vez de pelearse
# por el mas cercano y que uno se coma un aviso de "ocupado".
func cuerpo_ocupado_por_otro(net_id: int) -> bool:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return false
	var peer: int = int(_extrayendo.get(net_id, 0))
	return peer != 0 and peer != multiplayer.get_unique_id()


func _consumir_cadaver(id: int) -> void:
	Net.peleas._enem_ocupados.erase(id)
	_borrar_extrayendo(id)
	var e: Dictionary = Net.enemigos._enemigos.get(id, {})
	var nodo = e.get("nodo") if not e.is_empty() else null
	if nodo != null and is_instance_valid(nodo):
		nodo.extracted = true
		if nodo.has_method("desvanecer"):
			nodo.desvanecer()   # al liberarse, _exit_tree -> baja_enemigo quita los espejos
