# LOS CUERPOS DE LOS HUMANOS EN SU PISO DE LA SALA (fase 2, etapa 2, paso 1). La sala lleva varios pisos a la vez y no
# tiene "escena actual": el cuerpo de cada jugador tiene que nacer en el piso de SU lugar, para que lo vean y lo
# persigan los enemigos de ese piso y NO los de otro. Se monta una sala de mentira en este proceso (pisos 2 y 5, sin
# red) y tres jugadores: Ana en el 2, Bea en el 5 y Cris en el pueblo.
# Cubre: net.gd (_crear_avatar_nodo, _cambiar_lugar, montar_cuerpos_del_lugar), net_pisos.gd (_mover_companeros,
# personajes_en_mi_piso), net_jugadores.gd (jugadores_remotos_aqui) y spawn_zone.gd (_lugar, brote_tamano).
#   godot --headless --path . res://tools/prueba_servidor_cuerpos.tscn
extends Node

const _SERVIDOR := preload("res://scripts/net/servidor_pisos.gd")
const ANA := 101
const BEA := 102
const CRIS := 103

var _mal: int = 0


func _ready() -> void:
	call_deferred("_empezar")


func _empezar() -> void:
	reparent(get_tree().root)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var hueco := Node.new()
	get_tree().root.add_child(hueco)
	get_tree().current_scene = hueco
	_correr()


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _esperar(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _hasta_poblado(pv: PisoVivo, tope: int = 600) -> void:
	var n: int = 0
	while n < tope:
		var suelo: Node = pv.primero(&"dungeon_floor")
		if suelo != null and suelo.get("gen") != null and not pv.nodos(&"enemy").is_empty():
			return
		await get_tree().physics_frame
		n += 1


func _una_zona(n: Node) -> Node:
	for h in n.get_children():
		if h is SpawnZone:
			return h
		var z: Node = _una_zona(h)
		if z != null:
			return z
	return null


func _cuerpo(pid: int):
	var a = Net._avatares.get(pid)
	return a if a != null and is_instance_valid(a) else null


func _registrar(pid: int, nombre: String, lugar: String) -> void:
	Net._registrar_peer(pid, Color.WHITE, 0.0, nombre, lugar, 0, 1.0, false)


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 4016831469
	Game.current_floor = 1
	# La sala, sin red: lo que mira el codigo de los cuerpos es que soy la sala y el anfitrion, con sesion abierta.
	Net.soy_sala = true
	Net.es_host = true
	Net.activo = true
	Net._mi_lugar = "sala"
	var srv: Node = _SERVIDOR.new()
	get_tree().root.add_child(srv)
	var a: PisoVivo = srv.montar(2, 2)
	var b: PisoVivo = srv.montar(5, 5)
	await _hasta_poblado(a)
	await _hasta_poblado(b)

	print("1) cada cuerpo nace en el piso de su lugar")
	_registrar(ANA, "Ana", "piso:2")
	_registrar(BEA, "Bea", "piso:5")
	_registrar(CRIS, "Cris", "pueblo")
	var ca = _cuerpo(ANA)
	var cb = _cuerpo(BEA)
	_ver(ca != null and PisoVivo.de(ca) == a, "Ana (piso 2) tiene cuerpo y cuelga del piso 2")
	_ver(cb != null and PisoVivo.de(cb) == b, "Bea (piso 5) tiene cuerpo y cuelga del piso 5")
	_ver(_cuerpo(CRIS) == null, "Cris (pueblo, que la sala no lleva) no tiene cuerpo")
	_ver(ca != null and ca.get_parent() != get_tree().current_scene, "ninguno cae en la escena actual (la sala no tiene)")

	print("2) los enemigos de cada piso solo ven a los suyos")
	# La trampa: Ana y Bea EN LAS MISMAS COORDENADAS, encima de un enemigo del piso 2. Si los pisos se mezclaran, ese
	# enemigo veria a las dos.
	var e2: Node2D = a.nodos(&"enemy")[0] as Node2D
	var e5: Node2D = b.nodos(&"enemy")[0] as Node2D
	if ca != null and cb != null:
		(ca as Node2D).global_position = e2.global_position + Vector2(10, 0)
		(cb as Node2D).global_position = e2.global_position + Vector2(10, 0)
	await _esperar(2)
	var aliados2: Array = e2.call("_aliados")
	var aliados5: Array = e5.call("_aliados")
	_ver(aliados2.has(ca) and not aliados2.has(cb), "el enemigo del 2 ve a Ana y no a Bea (%d aliados)" % aliados2.size())
	_ver(aliados5.has(cb) and not aliados5.has(ca), "el enemigo del 5 ve a Bea y no a Ana (%d aliados)" % aliados5.size())
	_ver(e2.call("_aliado_mas_cercano") == ca, "la presa mas cercana del enemigo del 2 es Ana")

	print("3) las zonas de parto cuentan a la gente de SU piso")
	var z2: Node = _una_zona(a)
	var z5: Node = _una_zona(b)
	if z2 != null and z5 != null:
		var d2: Array = Net.jugadores.jugadores_remotos_aqui(String(z2.call("_lugar")))
		var d5: Array = Net.jugadores.jugadores_remotos_aqui(String(z5.call("_lugar")))
		# Las posiciones de red llegan por _recibir_estado; aqui se apuntan a mano.
		_ver(String(z2.call("_lugar")) == "piso:2" and String(z5.call("_lugar")) == "piso:5", "cada zona sabe su lugar")
		print("    (sin posicion de red aun: %d y %d)" % [d2.size(), d5.size()])
		Net.pisos._recibir_estado(ANA, Vector2(100, 100), Vector2.RIGHT)
		Net.pisos._recibir_estado(BEA, Vector2(200, 200), Vector2.RIGHT)
		d2 = Net.jugadores.jugadores_remotos_aqui(String(z2.call("_lugar")))
		d5 = Net.jugadores.jugadores_remotos_aqui(String(z5.call("_lugar")))
		_ver(d2.size() == 1 and d2[0]["pos"] == Vector2(100, 100), "la zona del 2 solo ve a Ana")
		_ver(d5.size() == 1 and d5[0]["pos"] == Vector2(200, 200), "la zona del 5 solo ve a Bea")
		# La sala no cuenta su propio grupo (es un personaje inventado): solo Ana (+ su sequito, vacio) = 1.
		_ver(Net.pisos.personajes_en_mi_piso("piso:2") == 1, "en el piso 2 hay 1 personaje (la sala no cuenta: %d)" % Net.pisos.personajes_en_mi_piso("piso:2"))
		_ver(int(z2.call("brote_tamano")) == 2, "el brote del piso 2 es de 2 (%d)" % int(z2.call("brote_tamano")))
	else:
		_ver(false, "hay zona de parto en los dos pisos")

	print("4) pasar de un piso a otro rehace el cuerpo en el piso nuevo")
	Net._cambiar_lugar(ANA, "piso:5")
	await _esperar(2)
	var ca2 = _cuerpo(ANA)
	_ver(ca2 != null and PisoVivo.de(ca2) == b, "Ana ya tiene cuerpo en el piso 5")
	_ver(ca == null or not is_instance_valid(ca), "su cuerpo del piso 2 se ha ido")
	_ver(not (e2.call("_aliados") as Array).has(ca2), "el enemigo del 2 ya no la ve")
	Net._cambiar_lugar(ANA, "pueblo")
	await _esperar(2)
	_ver(_cuerpo(ANA) == null, "al subir al pueblo, la sala ya no tiene su cuerpo")
	Net._cambiar_lugar(ANA, "piso:2")
	await _esperar(1)
	_ver(_cuerpo(ANA) != null and PisoVivo.de(_cuerpo(ANA)) == a, "al volver a bajar al 2, cuerpo otra vez en el 2")

	print("5) un piso que se monta despues recibe a los que ya estaban en el")
	Net._cambiar_lugar(CRIS, "piso:7")
	_ver(_cuerpo(CRIS) == null, "Cris va al 7, que aun no esta montado: sin cuerpo")
	var c7: PisoVivo = srv.montar(7, 7)
	await _hasta_poblado(c7)
	Net.montar_cuerpos_del_lugar("piso:7")
	_ver(_cuerpo(CRIS) != null and PisoVivo.de(_cuerpo(CRIS)) == c7, "al montar el 7, Cris tiene cuerpo en el")

	print("6) los acompañantes van con su jugador")
	Net._peers[BEA]["comps"] = [{"nombre": "Perro", "color": Color.WHITE}]
	Net.pisos._mover_companeros(BEA, [Vector2(50, 50)])
	var comps: Array = Net._avatares_comp.get(BEA, [])
	_ver(comps.size() == 1 and PisoVivo.de(comps[0]) == b, "el acompañante de Bea nace en el piso 5")

	print("7) cada charco de pesca, en su piso (paso 3)")
	var charcos := 0
	for pv in [a, b, c7]:
		for ch in pv.nodos(&"estanque"):
			if not is_instance_valid(ch):
				continue
			charcos += 1
			_ver(Net.pesca._charco_de(pv.lugar) == ch, "el charco del %s esta apuntado en su lugar" % pv.lugar)
			_ver(int(ch.call("_piso")) == pv.numero, "y lee su piso (%d)" % int(ch.call("_piso")))
	if charcos < 2:
		# Se busca otro piso con charco: los charcos no salen en todos.
		for n in range(3, 16):
			var pv_n: PisoVivo = srv.montar(n, n)
			await _hasta_poblado(pv_n)
			var hay: bool = not pv_n.nodos(&"estanque").is_empty()
			if hay:
				var ch2: Node = pv_n.nodos(&"estanque")[0]
				charcos += 1
				_ver(Net.pesca._charco_de(pv_n.lugar) == ch2, "el charco del %s esta apuntado en su lugar" % pv_n.lugar)
				_ver(int(ch2.call("_piso")) == n, "y lee su piso (%d)" % int(ch2.call("_piso")))
			srv.desmontar(n)
			if charcos >= 2:
				break
	_ver(charcos >= 2, "hay al menos dos charcos en pisos distintos para mirarlo (%d)" % charcos)

	for pid in [ANA, BEA, CRIS]:
		Net._olvidar_peer(pid)
	srv.desmontar(2)
	srv.desmontar(5)
	srv.desmontar(7)
	PisoVivo.por_piso = false
	Net.activo = false
	Net.es_host = false
	Net.soy_sala = false
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(0 if _mal == 0 else 1)
