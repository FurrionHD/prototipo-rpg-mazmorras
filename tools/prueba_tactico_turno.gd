# ============================================================
#  PRUEBA: EL TURNO EN EL MAPA (fase 4 del combate tactico)
#  Sin ventana. Comprueba:
#    1) el RADIO sale de la Agilidad, con su suelo, su techo y el sobrepeso encima;
#    2) el PASO: se queda dentro del circulo y de la arena (paredes blandas: resbala), la roca lo
#       para, y contra una pared en diagonal DESLIZA por el eje que si se puede;
#    3) TU TURNO: con la tecla pulsada el personaje anda, y no sale de su circulo por mucho que
#       empuje; elegir accion cierra el turno y el circulo se va;
#    4) SU TURNO: el enemigo se acerca a su presa, se para a su lado o en el borde de su circulo, y
#       ACTUA -- la pelea no se queda en pausa para siempre;
#    5) el acercamiento tiene TOPE: un bicho que no puede avanzar actua igual.
#
#    godot --headless --path . res://tools/prueba_tactico_turno.tscn
# ============================================================
extends Node

const ESCENA := "res://scenes/ui/combat.tscn"
const Tactico = preload("res://scripts/ui/combat_tactico.gd")

var _fallos: int = 0


# El tema de siempre, pero con cuerpos de mentira: en la pelea de prueba no hay mazmorra, asi que
# cada combatiente recibe un Node2D suelto que hace de cuerpo.
class TacticoDePrueba extends "res://scripts/ui/combat_tactico.gd":
	var cuerpos: Dictionary = {}
	var bloqueado: bool = false   # true = nadie puede dar un paso (el caso del bicho atascado)

	func cuerpo_de(c: Combatant) -> Node2D:
		return cuerpos.get(c)

	func _puede_estar(p: Vector2, cuerpo: Node2D) -> bool:
		return not bloqueado and super._puede_estar(p, cuerpo)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	_probar_radio()
	_probar_paso()
	await _probar_turnos()
	print("[turno] RESULTADO: %s (%d fallos)" % ["TODO BIEN" if _fallos == 0 else "HAY FALLOS", _fallos])
	get_tree().quit(1 if _fallos > 0 else 0)


func _probar_radio() -> void:
	var base: float = StatsMath.radio_movimiento(100.0, 100.0)
	_afirmar(is_equal_approx(base, StatsMath.RADIO_MOV_BASE), "en el liston tendria que andar la base (%.1f)" % base)
	_afirmar(is_equal_approx(StatsMath.radio_movimiento(0.0, 100.0), StatsMath.RADIO_MOV_MIN),
		"con Agilidad 0 tendria que quedarse en el suelo")
	_afirmar(is_equal_approx(StatsMath.radio_movimiento(9999.0, 100.0), StatsMath.RADIO_MOV_MAX),
		"con Agilidad enorme tendria que quedarse en el techo")
	_afirmar(is_equal_approx(StatsMath.radio_movimiento(100.0, 100.0, 0.5), StatsMath.RADIO_MOV_BASE * 0.5),
		"el sobrepeso tendria que ir encima del clamp")


func _probar_paso() -> void:
	var todo := func(_p: Vector2) -> bool: return true
	var rect := Rect2(-500, -500, 1000, 1000)
	# Libre: anda lo que pide.
	var p: Vector2 = Tactico.paso(Vector2.ZERO, Vector2(10, 0), Vector2.ZERO, 96.0, rect, todo)
	_afirmar(p.is_equal_approx(Vector2(10, 0)), "paso libre: %s" % p)
	# El circulo: por mucho que empuje, se queda en su borde.
	p = Tactico.paso(Vector2(90, 0), Vector2(50, 0), Vector2.ZERO, 96.0, rect, todo)
	_afirmar(absf(p.length() - 96.0) < 0.01, "se sale del circulo: %s" % p)
	# ...y RESBALA por el: empujando de lado en el borde, avanza por la circunferencia.
	p = Tactico.paso(Vector2(96, 0), Vector2(20, 20), Vector2.ZERO, 96.0, rect, todo)
	_afirmar(p.y > 1.0 and p.length() <= 96.01, "no resbala por el borde del circulo: %s" % p)
	# La arena: tambien blanda.
	p = Tactico.paso(Vector2(0, 0), Vector2(0, 50), Vector2.ZERO, 96.0, Rect2(-100, -100, 200, 130), todo)
	_afirmar(is_equal_approx(p.y, 30.0), "se sale de la arena: %s" % p)
	# La roca es DURA, y contra ella en diagonal desliza por el eje libre.
	var muro := func(q: Vector2) -> bool: return q.x < 10.0
	p = Tactico.paso(Vector2(9, 0), Vector2(5, 5), Vector2.ZERO, 96.0, rect, muro)
	_afirmar(p.x < 10.0 and p.y > 4.0, "no desliza por la pared: %s" % p)
	p = Tactico.paso(Vector2(9, 0), Vector2(5, 0), Vector2.ZERO, 96.0, rect, muro)
	_afirmar(p.is_equal_approx(Vector2(9, 0)), "atraviesa la roca: %s" % p)


func _probar_turnos() -> void:
	var escena: PackedScene = load(ESCENA)
	var pelea: Node = escena.instantiate()
	pelea.process_mode = Node.PROCESS_MODE_ALWAYS
	pelea.tactico = true
	add_child(pelea)
	await get_tree().process_frame
	await get_tree().process_frame
	# Congelado: los turnos se dan a mano, no los reparte el ATB.
	pelea._state = pelea.State.PAUSED
	pelea._pause_left = INF

	var t: TacticoDePrueba = TacticoDePrueba.new(pelea)
	pelea.turno_mapa = t
	# Cuerpos: los tuyos a la izquierda, los bichos a 300 px a la derecha.
	for i in pelea._aliados.size():
		t.cuerpos[pelea._aliados[i]] = _cuerpo(Vector2(0, i * 40))
	for i in pelea._enemies.size():
		t.cuerpos[pelea._enemies[i]] = _cuerpo(Vector2(300, i * 40))
	t.montar()
	_afirmar(not pelea._action_buttons[pelea.Action.FLEE].visible, "el boton de Huir tendria que irse en el mapa")

	# --- TU TURNO ---
	var yo: Combatant = pelea._aliados[0]
	var mi_cuerpo: Node2D = t.cuerpos[yo]
	pelea._player = yo
	pelea._state = pelea.State.WAITING_PLAYER
	pelea._mostrar_acciones()
	t.empezar_turno(yo)
	var radio: float = t.radio_de(yo)
	_afirmar(radio >= StatsMath.RADIO_MOV_MIN, "radio de mi turno: %.1f" % radio)
	# Hacia ARRIBA, donde no hay nadie: hacia la derecha se toparia con los bichos.
	Input.action_press("move_up")
	await _esperar(2.5)
	Input.action_release("move_up")
	var andado: float = mi_cuerpo.global_position.length()
	_afirmar(andado > radio * 0.9, "con la tecla pulsada 2,5 s solo anduvo %.1f de %.1f" % [andado, radio])
	_afirmar(andado <= radio + 0.1, "se salio de su circulo: %.1f de %.1f" % [andado, radio])
	# Elegir accion cierra el turno (la accion saca a la pelea de WAITING_PLAYER).
	pelea._state = pelea.State.PAUSED
	pelea._pause_left = INF
	await get_tree().process_frame
	_afirmar(t._fase == t.Fase.NADA, "al acabar el turno sigue en fase %d" % t._fase)

	# --- SU TURNO ---
	var bicho: Combatant = pelea._enemies[0]
	var su_cuerpo: Node2D = t.cuerpos[bicho]
	var desde: Vector2 = su_cuerpo.global_position
	var su_radio: float = t.radio_de(bicho)
	t.turno_enemigo(bicho)
	_afirmar(t._fase == t.Fase.ACERCANDO, "el bicho no empezo a acercarse")
	await _esperar_a(func() -> bool: return t._fase == t.Fase.NADA, 4.0)
	_afirmar(t._fase == t.Fase.NADA, "el bicho no termino de acercarse")
	var anduvo: float = su_cuerpo.global_position.distance_to(desde)
	_afirmar(anduvo > 10.0, "el bicho no se movio (%.1f)" % anduvo)
	_afirmar(anduvo <= su_radio + 0.1, "el bicho se salio de su circulo: %.1f de %.1f" % [anduvo, su_radio])
	_afirmar(pelea._pause_left != INF, "tras acercarse, el bicho no actuo: la pelea se queda en pausa")

	# --- ATASCADO: actua igual ---
	pelea._state = pelea.State.PAUSED
	pelea._pause_left = INF
	t.bloqueado = true
	var otro: Combatant = pelea._enemies[1]
	t.turno_enemigo(otro)
	var t0: int = Time.get_ticks_msec()
	await _esperar_a(func() -> bool: return t._fase == t.Fase.NADA, 4.0)
	var tardo: float = (Time.get_ticks_msec() - t0) / 1000.0
	_afirmar(t._fase == t.Fase.NADA, "un bicho atascado cuelga la pelea")
	_afirmar(tardo < Tactico.TOPE_ACERCARSE, "el atascado agoto el tope (%.2f s) en vez de rendirse antes" % tardo)

	pelea.queue_free()
	await get_tree().process_frame


func _cuerpo(p: Vector2) -> Node2D:
	var n := Node2D.new()
	add_child(n)
	n.global_position = p
	return n


func _esperar(seg: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < seg * 1000.0:
		await get_tree().process_frame


func _esperar_a(cond: Callable, tope: float) -> void:
	var t0: int = Time.get_ticks_msec()
	while not cond.call() and (Time.get_ticks_msec() - t0) < tope * 1000.0:
		await get_tree().process_frame


func _afirmar(ok: bool, mensaje: String) -> void:
	if not ok:
		_fallos += 1
		print("[turno] FALLO  %s" % mensaje)
