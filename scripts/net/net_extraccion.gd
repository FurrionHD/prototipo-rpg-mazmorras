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
# Lo arbitra el dueño del piso, que es quien tiene el cuerpo de verdad. Devuelve true si puedo
# empezar YA (soy el dueño y esta libre); si no, la respuesta llega por _extraccion_concedida.
func solicitar_extraccion(id: int) -> bool:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return true
	var yo: int = multiplayer.get_unique_id()
	if Net._soy_dueno:
		# Idempotente: si el candado ya es MIO, se me vuelve a conceder. Antes cualquier re-peticion
		# propia (una segunda F antes de que abriera la pantalla) se contestaba "lo trabaja tu
		# compañero" siendo yo mismo.
		if Net.peleas._enem_ocupados.has(id) and int(Net.peleas._enem_ocupados[id]) != yo:
			Net._toast("Ese cuerpo lo está trabajando tu compañero.")
			return false
		Net.peleas._enem_ocupados[id] = yo
		_apuntar_extrayendo(id, yo)
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
	if Net._mi_lugar == lugar and Net._soy_dueno:
		_resolver_extraccion(id, quien)
		return
	var dueno: int = Net._dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_pedir_extraccion_dueno.rpc_id(dueno, id, lugar, quien)
	else:
		_responder_extraccion(quien, id, false)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_extraccion_dueno(id: int, lugar: String, para: int) -> void:
	if Net._mi_lugar != lugar or not Net._soy_dueno:
		return
	_resolver_extraccion(id, para)


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
	elif Net.es_host:
		_extraccion_concedida.rpc_id(quien, id, ok)
	else:
		_rel_resp_extraccion.rpc_id(1, quien, id, ok)


@rpc("any_peer", "call_remote", "reliable")
func _rel_resp_extraccion(para: int, id: int, ok: bool) -> void:
	if not Net.es_host:
		return
	if para == 1:
		_extraccion_concedida(id, ok)
	else:
		_extraccion_concedida.rpc_id(para, id, ok)


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
	if Net._soy_dueno:
		_consumir_cadaver(id)
	elif Net.es_host:
		_encaminar_consumir(id, Net._mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_consumir.rpc_id(1, id, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_consumir(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_consumir(id, lugar)


func _encaminar_consumir(id: int, lugar: String) -> void:
	if Net._mi_lugar == lugar and Net._soy_dueno:
		_consumir_cadaver(id)
		return
	var dueno: int = Net._dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_consumir.rpc_id(dueno, id, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_consumir(id: int, lugar: String) -> void:
	if Net._mi_lugar != lugar or not Net._soy_dueno:
		return
	_consumir_cadaver(id)


# Suelto el cuerpo SIN haberlo extraido (me han quitado la pantalla, el cuerpo se fue con el piso
# viejo, o el minijuego se auto-cancelo). Gemela de notificar_extraido pero sin desvanecer nada: solo
# devuelve el candado, que si no se queda puesto para siempre.
func soltar_extraccion(id: int) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net._soy_dueno:
		_liberar_cadaver(id)
	elif Net.es_host:
		_encaminar_soltar_cuerpo(id, Net._mi_lugar)   # host no-dueño: sin RPC a mi mismo
	else:
		_pedir_soltar_cuerpo.rpc_id(1, id, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_soltar_cuerpo(id: int, lugar: String) -> void:
	if not Net.es_host:
		return
	_encaminar_soltar_cuerpo(id, lugar)


func _encaminar_soltar_cuerpo(id: int, lugar: String) -> void:
	if Net._mi_lugar == lugar and Net._soy_dueno:
		_liberar_cadaver(id)
		return
	var dueno: int = Net._dueno_de(lugar)
	if dueno != 0 and dueno != 1:
		_rel_soltar_cuerpo.rpc_id(dueno, id, lugar)


@rpc("any_peer", "call_remote", "reliable")
func _rel_soltar_cuerpo(id: int, lugar: String) -> void:
	if Net._mi_lugar != lugar or not Net._soy_dueno:
		return
	_liberar_cadaver(id)


# SOLO el dueño: devuelve el candado de un cuerpo que sigue ahi, intacto y extraible.
func _liberar_cadaver(id: int) -> void:
	Net.peleas._enem_ocupados.erase(id)
	_borrar_extrayendo(id)


# --- Difusion de los cuerpos que se estan extrayendo -------------------------------------------
#
# La lleva el DUEÑO del piso y viaja por el HOST, porque en ENet los clientes no se hablan entre
# ellos (mismo relevo que _rel_resp_extraccion).

func _apuntar_extrayendo(id: int, quien: int) -> void:
	if int(_extrayendo.get(id, 0)) == quien:
		return
	_extrayendo[id] = quien
	_difundir_extrayendo()


func _borrar_extrayendo(id: int) -> void:
	if not _extrayendo.has(id):
		return
	_extrayendo.erase(id)
	_difundir_extrayendo()


func _difundir_extrayendo() -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_set_extrayendo.rpc(_extrayendo)
	else:
		_rel_extrayendo.rpc_id(1, _extrayendo)


@rpc("any_peer", "call_remote", "reliable")
func _rel_extrayendo(d: Dictionary) -> void:
	if not Net.es_host:
		return
	_extrayendo = d.duplicate()   # el host tambien lo necesita para su propia F
	_set_extrayendo.rpc(d)


@rpc("any_peer", "call_remote", "reliable")
func _set_extrayendo(d: Dictionary) -> void:
	if Net._soy_dueno:
		return   # el mio es el autoritativo: no me lo pisa el eco del host
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
