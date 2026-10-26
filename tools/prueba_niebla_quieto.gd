# Cubre: res://scripts/world/niebla.gd
# LA NIEBLA CON EL JUGADOR QUIETO (auditoria 13/10, fallo encontrado leyendo el codigo): la niebla se salta la
# pasada si nadie se mueve (es lo caro), y con ella se saltaba tambien el "quien esta a la luz". Un enemigo que
# entraba de la oscuridad a tu farolillo mientras estabas parado seguia INVISIBLE hasta que dabas un paso; y uno que
# se iba a lo oscuro seguia viendose.
# La prueba: piso 1 de la partida de referencia, COMO JUGADOR con su sala (etapa 4, 26/10: la niebla es de la maquina
# que pinta, y los enemigos que ve son los espejos que le manda la sala). Jugador quieto, un espejo clavado por la
# prueba lejos en lo oscuro y luego al lado del jugador. Tiene que aparecer y desaparecer sin que el jugador se mueva.
#   godot --headless --path . res://tools/prueba_niebla_quieto.tscn -- nube_local
extends Node

var j = null   # el jugador con su sala: tools/prueba_con_jugador.gd

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


# El espejo se arrastra hacia lo ultimo que le manda la sala (remote_enemy.ir_a): se le clava en 'pos' en cada
# fotograma mientras se espera, o la sala lo devolvia a su sitio y la prueba miraba otro punto.
func _clavar(bicho: Node2D, pos: Vector2, frames: int) -> void:
	for i in frames:
		bicho.fijar_en(pos)
		await get_tree().process_frame


func _correr() -> void:
	j = preload("res://tools/prueba_con_jugador.gd").new()
	add_child(j)
	if not await j.arrancar("prueba_niebla_quieto", 76, 1):
		_ver(false, "arranca la sala y entro al piso 1")
		await _fin()
		return
	var piso: Node = null
	var niebla: Node = null
	var jugador: Node2D = null
	for i in 600:
		await get_tree().process_frame
		piso = get_tree().get_first_node_in_group("dungeon_floor")
		jugador = get_tree().get_first_node_in_group("player") as Node2D
		niebla = piso.get_node_or_null("Niebla") if piso != null else null
		if niebla != null and jugador != null:
			break
	if niebla == null or jugador == null:
		_ver(false, "el piso se monta con niebla y jugador")
		await _fin()
		return
	await j._hasta(func(): return not get_tree().get_nodes_in_group("enemy").is_empty(), 10.0)

	# Un espejo de enemigo, clavado por la prueba.
	var bicho: Node2D = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e is Node2D and e.has_method("fijar_en"):
			bicho = e
			break
	if bicho == null:
		_ver(false, "hay algun espejo de enemigo en el piso")
		await _fin()
		return
	jugador.set_physics_process(false)   # el jugador no se mueve ni un pixel
	var yo: Vector2 = jugador.global_position

	# 1) Lejos: dentro de la ventana que se calcula, pero fuera del farolillo. Se busca un sitio a oscuras (una
	# antorcha o un cristal del piso pueden alumbrar el que tocara a ojo).
	var lejos := Vector2.INF
	for dist in [260.0, 220.0, 300.0]:
		for ang in 8:
			var p: Vector2 = yo + Vector2(dist, 0).rotated(TAU * ang / 8.0)
			await _clavar(bicho, p, 20)   # varias pasadas de la niebla (va a 15 por segundo)
			if not niebla._le_llega_luz(bicho):
				lejos = p
				break
		if lejos != Vector2.INF:
			break
	_ver(lejos != Vector2.INF, "hay un sitio a oscuras cerca (si no, la prueba no mira nada)")
	if lejos == Vector2.INF:
		await _fin()
		return
	_ver(not bicho.visible, "lejos y a oscuras: no se ve")

	# 2) Al lado del jugador, que sigue QUIETO
	await _clavar(bicho, yo + Vector2(40, 0), 20)
	_ver(niebla._le_llega_luz(bicho), "al lado del jugador le llega la luz")
	_ver(bicho.visible, "entra en la luz con el jugador QUIETO: se ve")

	# 3) Y se vuelve a ir a lo oscuro
	await _clavar(bicho, lejos, 20)
	_ver(not bicho.visible, "se va a lo oscuro con el jugador quieto: deja de verse")
	_ver(jugador.global_position.distance_to(yo) < 0.5, "el jugador no se ha movido en toda la prueba")
	await _fin()


func _fin() -> void:
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	await j.cerrar()
	get_tree().quit(0 if _mal == 0 else 1)
