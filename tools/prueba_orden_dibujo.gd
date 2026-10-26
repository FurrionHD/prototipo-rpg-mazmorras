# EL ORDEN DE DIBUJO ENEMIGO/PERSONAJES (10/10, el 5 del playtest 09/10): antes el enemigo iba ENTERO delante o detras de
# todos los personajes segun el aliado mas cercano de cada maquina. Ahora va en las bandas por altura de
# Game._ordenar_munecos, con los muñecos: el de detras (mas arriba) por debajo del enemigo, el de delante por encima. Con
# el Minotauro y el Rey Slime, uno de los tuyos detras y otro delante de cada uno. Sin ventana:
#   godot --headless --path . res://tools/prueba_orden_dibujo.tscn -- nube_local
# El orden lo pone la maquina que PINTA, la del jugador: desde la etapa 4 (26/10) la prueba es el jugador, con su sala
# (tools/prueba_con_jugador.gd), y pelea en espejo contra cada uno por turno.
extends Node

const ENEMIGOS := ["guardian_rango", "rey_slime"]
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


func _esperar(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


func _esperar_a(cond: Callable, tope_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while not cond.call():
		if Time.get_ticks_msec() - t0 > tope_s * 1000.0:
			return false
		await get_tree().process_frame
	return true


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	var j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_orden_dibujo", 70):
		print("MAL: no arranca la sala o no entro")
		await j.cerrar()
		get_tree().quit(1)
		return
	for nom in ENEMIGOS:
		var nodo: Node2D = await j.poner("res://scenes/actors/enemy/%s.tres" % nom, Vector2(0, 110), {"modo": 1, "hp": 5.0})
		var combat: Node = await j.pelear(nodo) if nodo != null else null
		if combat == null or not combat.tactico:
			_ver(false, "la pelea contra %s se abre en tactico" % nom)
			continue
		await _mirar(combat)
		combat.set_process(true)
		await j.pelear_hasta_el_final(60.0)
	await j.cerrar()
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _mirar(combat: Node) -> void:
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		_ver(false, "llega un turno de los tuyos")
		return
	combat.set_process(false)
	var al: Array = combat._aliados
	if al.size() < 2:
		_ver(false, "hacen falta dos de los tuyos y hay %d" % al.size())
		return
	for e in combat._enemies:
		var cu_e: Node2D = t.cuerpo_de(e)
		var suelo: Vector2 = Cuerpos.caja_de(cu_e).get_center()
		var caja: Rect2 = Cuerpos.caja_de(cu_e)
		print("%s (caja %s)" % [e.nombre, caja.size])
		# Uno DETRAS (sus pies justo por encima de la caja del enemigo) y otro DELANTE (justo por debajo), los dos pegados
		# a el y un poco de lado, que es donde antes uno de los dos salia mal.
		var detras: Vector2 = Vector2(suelo.x - 10.0, caja.position.y - 4.0)
		var delante: Vector2 = Vector2(suelo.x + 10.0, caja.end.y + 4.0)
		t._colocar(al[0], t.cuerpo_de(al[0]), detras - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		t._colocar(al[1], t.cuerpo_de(al[1]), delante - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		await _esperar(3)
		var z_e: int = cu_e.z_index
		var z_a: int = (t.cuerpo_de(al[0]).get("_muneco") as Node2D).z_index
		var z_b: int = (t.cuerpo_de(al[1]).get("_muneco") as Node2D).z_index
		print("    z: detras %d, %s %d, delante %d" % [z_a, e.nombre, z_e, z_b])
		_ver(z_a < z_e, "el de detras se pinta por debajo del %s" % e.nombre)
		_ver(z_e < z_b, "el de delante se pinta por encima del %s" % e.nombre)
		_ver(z_e >= Game.Z_PERSONAJES and z_e < Game.Z_ENCIMA_PERSONAJES, "el %s en las bandas de los personajes" % e.nombre)
		# Y al reves: se cambian de sitio y se cambia el orden.
		t._colocar(al[0], t.cuerpo_de(al[0]), delante - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		t._colocar(al[1], t.cuerpo_de(al[1]), detras - Vector2(0, PoseJugador.PIES_BAJO_NODO))
		await _esperar(3)
		z_e = cu_e.z_index
		z_a = (t.cuerpo_de(al[0]).get("_muneco") as Node2D).z_index
		z_b = (t.cuerpo_de(al[1]).get("_muneco") as Node2D).z_index
		_ver(z_b < z_e and z_e < z_a, "cambiados de sitio, cambia el orden (%d < %d < %d)" % [z_b, z_e, z_a])
