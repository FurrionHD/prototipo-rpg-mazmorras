# ============================================================
#  net_suelo.gd  (hijo de Net: /root/Net/Suelo)
#  LOS OBJETOS DEL SUELO en multi: soltar y recoger con autoridad del host. Se llama como
#  Net.suelo.<funcion>. Lo comun de la sesion (activo, es_host, _peers, _mi_lugar) sigue en Net.
# ============================================================
extends Node

const _DROP_PICKUP := preload("res://scripts/items/drop_pickup.gd")
# El HOST es la fuente de verdad: _suelo apunta cada drop vivo por id. Todos los peers (host
# incluido) mantienen _drops con el NODO visual de cada id. Quien recoge se lo PIDE al host:
# el primero en llegar se lo lleva y el resto ni se entera (el drop simplemente desaparece).
var _suelo: Dictionary = {}        # id -> dict del item (solo lo llena el host)
var _drops: Dictionary = {}        # id -> nodo drop_pickup (en todos los peers)
var _next_id: int = 1              # contador de ids del host


# --- OBJETOS DEL SUELO (hito 2): soltar y recoger con autoridad del host --------------------

# Item -> dict de red. Lo minimo para reconstruirlo en la otra maquina: el MaterialData es un
# .tres del proyecto (viaja por ruta, igual que los consumibles en el guardado) y el Cristal
# son dos enteros. Mismo criterio que save_data, pero desmontado.
func _item_a_dict(item: Resource) -> Dictionary:
	if item is MaterialItem:
		var m := item as MaterialItem
		# La TALLA va con el: en un pez es media identidad del ejemplar (su corona sale de ella, ver
		# MaterialItem.corona). Sin esto, todo pescado que cruzaba el cable volvia a 0 cm -- y por ahi
		# pasa la bolsa entera de quien no es el host cada vez que se sincroniza, asi que un pez trofeo
		# se convertia en un pez del monton sin que nadie tocara nada.
		return {"t": "mat", "ruta": m.data.resource_path, "calidad": int(m.calidad), "cm": m.cm}
	if item is Cristal:
		var c := item as Cristal
		return {"t": "cri", "categoria": c.categoria, "calidad": int(c.calidad)}
	if item is ConsumableData:
		# Solo la RUTA: un consumible no tiene estado por unidad (la bolsa es un contador por .tres),
		# asi que el .tres del proyecto ES el objeto. load() cachea, o sea que al rehidratarlo sale
		# la MISMA instancia que usa Game.consumables como clave -- y por eso recogerlo suma en la
		# pila que ya tenias en vez de abrir una segunda entrada con el mismo nombre.
		return {"t": "con", "ruta": (item as ConsumableData).resource_path}
	return {}


func _item_de_dict(d: Dictionary) -> Resource:
	if d.get("t") == "mat":
		var data: MaterialData = load(str(d["ruta"]))   # load() cachea: misma instancia que la bolsa
		if data == null:
			return null
		var m := MaterialItem.crear(data, int(d["calidad"]))
		m.cm = float(d.get("cm", 0.0))   # 0 si viene de una version que aun no la mandaba
		return m
	if d.get("t") == "cri":
		var c := Cristal.new()
		c.categoria = int(d["categoria"])
		c.calidad = int(d["calidad"])
		return c
	if d.get("t") == "con":
		return load(str(d["ruta"])) as ConsumableData
	return null


# La llama Game.soltar_item cuando hay sesion: en vez de plantar el pickup en local, se pide
# al host (que asigna id y lo difunde a TODOS, tu incluido). El offset aleatorio ya viene
# calculado en pos por quien suelta: asi ambas maquinas ven el drop en el MISMO sitio.
func solicitar_soltar(item: Resource, pos: Vector2) -> void:
	var d := _item_a_dict(item)
	if d.is_empty():
		return
	if Net.es_host:
		_registrar_y_difundir(d, pos, Net._mi_lugar)
	else:
		_pedir_soltar.rpc_id(1, d, pos, Net._mi_lugar)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_soltar(d: Dictionary, pos: Vector2, lugar: String) -> void:
	if not Net.es_host:
		return
	_registrar_y_difundir(d, pos, lugar)


# Solo host: apunta el drop en el registro y lo difunde (a los peers por RPC, a si mismo directo).
# Guarda pos y LUGAR: un peer que entre despues (o que viaje a ese lugar) tiene que verlo.
func _registrar_y_difundir(d: Dictionary, pos: Vector2, lugar: String) -> void:
	_hacer_hueco_en(lugar)
	var id := _next_id
	_next_id += 1
	_suelo[id] = {"d": d, "pos": pos, "lugar": lugar}
	_spawn_drop.rpc(id, d, pos, lugar)
	_spawn_drop(id, d, pos, lugar)


# TOPE de cosas tiradas por LUGAR. Desde que la mazmorra no se cierra al volver al pueblo (ver
# _cerrar_expedicion), el suelo de un piso no lo vacia nadie: en una sesion larga se acumulan cientos
# de pickups que el host difunde a todo el que entra. El tope es generoso a proposito —cabe de sobra
# lo que se te caiga por sobrepeso en una bajada— y al llegar tira el MAS VIEJO, que es el que menos
# posibilidades tiene de que alguien vuelva a por el (los ids son crecientes, asi que la clave mas
# baja de ese lugar es la mas antigua).
const SUELO_TOPE_POR_LUGAR := 60

func _hacer_hueco_en(lugar: String) -> void:
	var ids: Array = []
	for id in _suelo:
		if _suelo[id]["lugar"] == lugar:
			ids.append(id)
	if ids.size() < SUELO_TOPE_POR_LUGAR:
		return
	ids.sort()
	var sobran: int = ids.size() - SUELO_TOPE_POR_LUGAR + 1
	for i in range(sobran):
		var viejo: int = ids[i]
		_suelo.erase(viejo)
		_despawn_drop.rpc(viejo)
		_despawn_drop(viejo)
	print("[suelo] %s estaba lleno (%d): se van los %d mas viejos" % [lugar, ids.size(), sobran])


@rpc("any_peer", "call_remote", "reliable")
func _spawn_drop(id: int, d: Dictionary, pos: Vector2, lugar: String) -> void:
	if lugar != Net._mi_lugar:
		return   # eso esta en OTRO sitio (otro piso, o el pueblo): aqui no se pinta
	var item := _item_de_dict(d)
	var mundo: Node = get_tree().current_scene
	if item == null or mundo == null:
		return
	var pickup: Node2D = _DROP_PICKUP.new()
	pickup.setup(item)
	pickup.set_meta("net_id", id)   # la clase no se toca: el id de red viaja como meta
	mundo.add_child(pickup)
	pickup.global_position = pos
	_drops[id] = pickup


# La llama player.gd al pulsar F sobre un drop CON net_id: se pide al host en vez de cogerlo.
func solicitar_recoger(id: int) -> void:
	if Net.es_host:
		_resolver_recogida(id, 1)
	else:
		_pedir_recoger.rpc_id(1, id)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_recoger(id: int) -> void:
	if not Net.es_host:
		return
	_resolver_recogida(id, multiplayer.get_remote_sender_id())


# Solo host: arbitra la carrera. El PRIMERO que llega se lo lleva; a los demas ni agua (regla
# del diseño: sin mensaje, el drop simplemente ya no esta — su nodo cae con _despawn_drop).
func _resolver_recogida(id: int, ganador: int) -> void:
	if not _suelo.has(id):
		return   # llego tarde: silencio
	var d: Dictionary = _suelo[id]["d"]
	_suelo.erase(id)
	_despawn_drop.rpc(id)
	_despawn_drop(id)
	if ganador == 1:
		_recoger_concedido(d)          # el host se lo queda: sin viaje de red
	else:
		_recoger_concedido.rpc_id(ganador, d)


@rpc("any_peer", "call_remote", "reliable")
func _despawn_drop(id: int) -> void:
	var n = _drops.get(id)
	if n != null and is_instance_valid(n):
		n.queue_free()
	_drops.erase(id)


# SOLO le llega al ganador: reconstruye el item y lo embolsa. Como esto corre unicamente en su
# proceso, el aviso del HUD ("Recoges X") sale solo en SU pantalla.
@rpc("any_peer", "call_remote", "reliable")
func _recoger_concedido(d: Dictionary) -> void:
	var item := _item_de_dict(d)
	if item != null:
		Game.embolsar(item)
