# ============================================================
#  net_mapa.gd  (hijo de Net: /root/Net/Mapa)
#  LA LIBRETA DEL MUNDO en sesion: el mapa y la niebla que se van descubriendo se apuntan en el mundo
#  del HOST y no en el save del invitado. Se llama como Net.mapa.<funcion>.
# ============================================================
extends Node

# --- MAPA DE LA SESION (la libreta del mundo del HOST) ----------------------------------------
#
# Se juega en el mundo del HOST, asi que la libreta que hay que mirar es la de SU mundo. Antes el
# mapa (tecla M) dibujaba Game.mapa_snapshot a pelo, que en el invitado es el de SU mundo (otra
# semilla): abrias el mapa y veias una mazmorra que no era la que estabas pisando. Y la NIEBLA se
# escribia en Game.mazmorra_persistente incluso en sesion, o sea que el save del invitado se iba
# llenando de niebla de un mundo ajeno.
#
# Ahora hay UNA libreta de sesion, autoritativa en el host, y NADA de esto toca el save del invitado.
#
# REGLA DE REFRESCO (decision del usuario): la exploracion se comparte, pero cada uno actualiza su
# copia SOLO CUANDO SUBE EL al pueblo. Si yo subo con una zona nueva, mi compañero no la ve hasta que
# suba el. Por eso el host, al fusionar lo que le trae alguien, le devuelve la libreta entera SOLO A
# EL: los demas se quedan con su copia vieja hasta que les toque. Al entrar en la sesion, el invitado
# recoge de golpe lo que el host tenga descubierto.
var _mapa_sesion: Dictionary = {}    # piso -> snapshot (mismo formato que Game.mapa_snapshot)
var _vistas_sesion: Dictionary = {}  # piso -> {zona_idx: true}  (la niebla)


# Solo host, al abrir sala: la libreta de la sesion empieza siendo la del mundo del host.
func _sembrar_mapa_sesion() -> void:
	_mapa_sesion = Game.mapa_snapshot.duplicate(true)
	_vistas_sesion = {}
	for p in Game.mazmorra_persistente:
		var vistas: Dictionary = (Game.mazmorra_persistente[p] as Dictionary).get("zonas_vistas", {})
		if not vistas.is_empty():
			_vistas_sesion[p] = vistas.duplicate()


# Lo que DIBUJA el mapa (lo lee Game.mapa_visible).
func mapa_sesion() -> Dictionary:
	return _mapa_sesion


# La niebla de un piso, creandola vacia si no existe. Es la que se escribe EN VIVO al andar
# (DungeonFloor) y la que lee la captura de la libreta (Game.capturar_mapa).
func vistas_sesion(piso: int) -> Dictionary:
	if not _vistas_sesion.has(piso):
		_vistas_sesion[piso] = {}
	return _vistas_sesion[piso]


# Los pisos que tienen niebla en MI copia (para el baseline de la expedicion).
func vistas_sesion_todas() -> Array:
	return _vistas_sesion.keys()


# Al MORIR: mi copia de la niebla vuelve a como estaba al bajar. Lo que ya estaba COMPROMETIDO en el
# host no se pierde -- alli sigue, y me llega entero la proxima vez que suba al pueblo con vida.
func revertir_vistas_sesion(baseline: Dictionary) -> void:
	for p in _vistas_sesion.keys():
		var vb: Dictionary = baseline.get(p, {})
		_vistas_sesion[p] = vb.duplicate()


# Lo llama Game.comprometer_mapa al SUBIR AL PUEBLO con vida: mando lo que he cartografiado esta
# bajada y, de vuelta, recibo la libreta fusionada. El host fusiona y me la devuelve solo a mi.
func comprometer_mapa_sesion(trabajo: Dictionary) -> void:
	if not Net.activo or multiplayer.multiplayer_peer == null:
		return
	if Net.es_host:
		_fusionar_mapa(trabajo, _vistas_sesion)
		return
	_pedir_fusion_mapa.rpc_id(1, trabajo, _vistas_sesion)


@rpc("any_peer", "call_remote", "reliable")
func _pedir_fusion_mapa(trabajo: Dictionary, vistas: Dictionary) -> void:
	if not Net.es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	_fusionar_mapa(trabajo, vistas)
	# Solo A EL: los demas siguen con su copia vieja hasta que suban ellos.
	_set_mapa_sesion.rpc_id(quien, _mapa_sesion, _vistas_sesion)


# Solo host: mete en la libreta de la sesion lo que trae uno que acaba de subir al pueblo.
func _fusionar_mapa(trabajo: Dictionary, vistas: Dictionary) -> void:
	for p in vistas:
		var mia: Dictionary = vistas_sesion(int(p))
		for z in (vistas[p] as Dictionary):
			mia[z] = true
	for p in trabajo:
		var piso: int = int(p)
		if not _mapa_sesion.has(piso):
			_mapa_sesion[piso] = (trabajo[p] as Dictionary).duplicate(true)
			continue
		_fundir_snap(_mapa_sesion[piso], trabajo[p] as Dictionary)


# Fusiona DOS snapshots del mismo piso. Se puede porque los dos salen de la MISMA geometria (misma
# semilla): lo que cambia es cuanto ha visto cada uno, asi que la union es exacta. Se hace campo a
# campo y no reemplazando el snapshot entero, porque el que sube solo ha horneado SU niebla y
# reemplazar borraria del plano las zonas que descubrio el otro.
#
# ¡OJO! CAMPO A CAMPO SIGNIFICA QUE ESTA LISTA HAY QUE MANTENERLA. Lo que Game.capturar_mapa meta en
# el snapshot y no se copie AQUI se pierde en cada fusion, y solo en MULTIJUGADOR: en solitario
# comprometer_mapa reemplaza el diccionario entero y el campo nuevo llega igual. Asi se perdio
# "estanques" -- el plano pintaba los charcos en el editor y no en la partida con un compañero, que
# es el sitio donde nadie lo mira dos veces. Si añades una clave al snapshot, añadela abajo.
func _fundir_snap(base: Dictionary, nuevo: Dictionary) -> void:
	base["ancho"] = nuevo.get("ancho", base.get("ancho", 0))
	base["alto"] = nuevo.get("alto", base.get("alto", 0))
	_unir_celdas(base, nuevo, "suelo")
	_unir_por_celda(base, nuevo, "vivos")
	_unir_por_celda(base, nuevo, "escaleras")
	_unir_celdas(base, nuevo, "salidas")
	# EL CHARCO SE REEMPLAZA, no se suma: hay UNO por piso, y la captura nueva sale del piso tal como es. Sumando
	# por celda, un charco capturado de un piso mal generado (cuando el espejo generaba otro trazado) se quedaba
	# para siempre y viajaba en el guardado: el plano del piso 6 enseñaba DOS lagos (playtest). Asi se corrige
	# solo la proxima vez que alguien pase por ese piso.
	if not (nuevo.get("estanques", []) as Array).is_empty():
		base["estanques"] = (nuevo["estanques"] as Array).duplicate(true)
	# AGOTADOS: gana el sello mas NUEVO (es una cuenta atras de respawn; el ultimo picado es la verdad).
	var ag: Dictionary = base.get("agotados", {})
	for celda in (nuevo.get("agotados", {}) as Dictionary):
		var e = (nuevo["agotados"] as Dictionary)[celda]
		if not ag.has(celda) or _sello_de(e) >= _sello_de(ag[celda]):
			ag[celda] = e
	base["agotados"] = ag


# Union de una lista de CELDAS sueltas (suelo, salidas), sin repetir.
func _unir_celdas(base: Dictionary, nuevo: Dictionary, clave: String) -> void:
	var vistas: Dictionary = {}
	var out: Array = []
	for lista in [base.get(clave, []), nuevo.get(clave, [])]:
		for c in (lista as Array):
			if not vistas.has(c):
				vistas[c] = true
				out.append(c)
	base[clave] = out


# Union de una lista de DICTS que llevan su celda en "cell" (vivos, escaleras): una entrada por celda.
#
# Cuando la celda esta en las dos listas MANDA LA NUEVA, que es la lectura mas reciente de ese piso.
# Antes ganaba la de la base (se recorria primero y la otra se descartaba), asi que una celda que
# habia cambiado de material conservaba para siempre el color y el tipo de la primera vez que
# alguien paso por alli: el plano se quedaba anclado a la epoca -o al build- mas viejo de la sesion.
func _unir_por_celda(base: Dictionary, nuevo: Dictionary, clave: String) -> void:
	var por_celda: Dictionary = {}
	var orden: Array = []
	for lista in [base.get(clave, []), nuevo.get(clave, [])]:
		for d in (lista as Array):
			var c = (d as Dictionary).get("cell")
			if not por_celda.has(c):
				orden.append(c)
			por_celda[c] = d
	var out: Array = []
	for c in orden:
		out.append(por_celda[c])
	base[clave] = out


# El sello de tiempo de un 'agotado'. Los snapshots viejos guardaban solo el float; los nuevos, un
# dict con color y tipo (misma tolerancia que map_menu._dibujar).
func _sello_de(e) -> float:
	return float((e as Dictionary)["t"]) if e is Dictionary else float(e)


@rpc("authority", "call_remote", "reliable")
func _set_mapa_sesion(mapa: Dictionary, vistas: Dictionary) -> void:
	_mapa_sesion = mapa.duplicate(true)
	_vistas_sesion = vistas.duplicate(true)
