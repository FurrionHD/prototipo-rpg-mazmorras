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
	await _probar_copia_de_red()
	await _probar_red()
	await _probar_alcance()
	await _probar_huella()
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


# 6) LA COPIA DE RED de un bicho que esta en MI pelea tactica no hace caso de la posicion que le manda
#    su dueño (la de antes de la pelea): si no, andaba su turno y volvia andando a su sitio. Fuera de
#    la pelea, si le hace caso.
func _probar_copia_de_red() -> void:
	var copia: Node2D = load("res://scripts/actors/enemy/remote_enemy.gd").new()
	add_child(copia)
	await get_tree().process_frame
	const ID := 777
	Net.enemigos._enem_nodos[ID] = copia
	# El paquete de su dueño, por el MISMO canal que en el juego (el tick de enemigos).
	Net.enemigos._tick_enemigos([[ID, Vector2(100, 100)]])   # primer paquete: aparece ahi
	var arena := Node2D.new()
	add_child(arena)
	var antes_arena: Node = Game._arena_nodo
	var antes_enem: Array = Game._active_enemies
	Game._arena_nodo = arena
	Game._active_enemies = [copia]
	# El turno lo mueve, por el MISMO camino que en el juego.
	Tactico.new(null)._colocar(null, copia, Vector2(200, 100))
	Net.enemigos._tick_enemigos([[ID, Vector2(100, 100)]])   # y su dueño insiste en el sitio viejo
	for i in 30:
		await get_tree().physics_frame
	_afirmar(copia.global_position.distance_to(Vector2(200, 100)) < 1.0,
		"en la pelea, la copia vuelve al sitio que manda la red: %s" % str(copia.global_position))
	Game._arena_nodo = antes_arena
	Game._active_enemies = antes_enem
	Net.enemigos._tick_enemigos([[ID, Vector2(120, 100)]])
	for i in 60:
		await get_tree().physics_frame
	_afirmar(copia.global_position.distance_to(Vector2(120, 100)) < 5.0,
		"fuera de la pelea, la copia no sigue a la red: %s" % str(copia.global_position))
	Net.enemigos._enem_nodos.erase(ID)
	copia.queue_free()
	arena.queue_free()


# 7) LO QUE VIAJA: el circulo va y vuelve igual, y la posicion sellada de otro humano se recorta a su
#    circulo si se pasa (nunca se rechaza).
func _probar_red() -> void:
	var escena: PackedScene = load(ESCENA)
	var pelea: Node = escena.instantiate()
	pelea.process_mode = Node.PROCESS_MODE_ALWAYS
	pelea.tactico = true
	add_child(pelea)
	await get_tree().process_frame
	pelea._state = pelea.State.PAUSED
	pelea._pause_left = INF
	var t: TacticoDePrueba = TacticoDePrueba.new(pelea)
	pelea.turno_mapa = t
	var otro: Combatant = pelea._aliados[1]
	t.cuerpos[otro] = _cuerpo(Vector2(0, 0))
	pelea._dueno_aliado[otro] = 42   # lo mueve OTRO humano
	pelea._player = otro
	pelea._state = pelea.State.WAITING_PLAYER
	t.empezar_turno(otro, 100.0)
	_afirmar(t._fase == t.Fase.AJENO, "el personaje de otro humano tendria que ir en fase AJENO (va en %d)" % t._fase)
	_afirmar(is_equal_approx(t.radio_del_turno(), 100.0), "el radio del turno no es el que se pidio")
	var red: PackedFloat32Array = t.estado_red()
	_afirmar(red.size() == 4 and int(red[0]) == 1 and is_equal_approx(red[3], 100.0),
		"el circulo que viaja no es el suyo: %s" % str(red))
	# Se ha pasado 200 px de su circulo de 100: se recorta, no se tira.
	t.anotar_pos_remota(otro, [300.0, 0.0])
	_afirmar(t.pos_de(otro).distance_to(Vector2(100, 0)) < 0.5,
		"la posicion sellada no se recorta a su circulo: %s" % str(t.pos_de(otro)))
	# Y dentro del circulo, se respeta tal cual.
	t.anotar_pos_remota(otro, [30.0, 40.0])
	_afirmar(t.pos_de(otro).is_equal_approx(Vector2(30, 40)), "la posicion sellada valida se ha tocado")
	# El turno se va: la fase se apaga sola.
	pelea._state = pelea.State.PAUSED
	await get_tree().process_frame
	_afirmar(t._fase == t.Fase.NADA, "el turno ajeno no se apaga al irse el turno")
	pelea.queue_free()
	await get_tree().process_frame


# 8) EL ALCANCE (fase 5): se mide por el HUECO entre cuerpos; el boton de Atacar se apaga si tu
#    objetivo no esta a tiro y pasa a Esperar si no llegas a nadie; el enemigo que no llega lo dice y
#    la pelea sigue; y la posicion de otro humano tiene su holgura.
func _probar_alcance() -> void:
	# Las fichas: vacio = lo de su familia, y la ficha manda si lo rellena.
	var daga := WeaponData.new()
	daga.tipo = WeaponData.Tipo.DAGA
	var mandoble := WeaponData.new()
	mandoble.tipo = WeaponData.Tipo.MANDOBLE
	_afirmar(daga.alcance_real() < mandoble.alcance_real(), "la daga tendria que llegar menos que el mandoble")
	daga.alcance = 50.0
	_afirmar(is_equal_approx(daga.alcance_real(), 50.0), "el alcance de la ficha no manda")
	_afirmar(is_equal_approx(EnemyData.new().alcance_real(), EnemyData.ALCANCE_BASE), "el enemigo sin alcance no usa el base")

	var escena: PackedScene = load(ESCENA)
	var pelea: Node = escena.instantiate()
	pelea.process_mode = Node.PROCESS_MODE_ALWAYS
	pelea.tactico = true
	add_child(pelea)
	await get_tree().process_frame
	await get_tree().process_frame
	pelea._state = pelea.State.PAUSED
	pelea._pause_left = INF
	var t: TacticoDePrueba = TacticoDePrueba.new(pelea)
	pelea.turno_mapa = t
	var yo: Combatant = pelea._aliados[0]
	yo.alcance = 20.0
	# Cuerpos base de 32x32: a 50 px de centro a centro hay 18 de hueco.
	t.cuerpos[yo] = _cuerpo(Vector2(0, 0))
	for i in pelea._aliados.size():
		if i > 0:
			t.cuerpos[pelea._aliados[i]] = _cuerpo(Vector2(-400, i * 40))
	var cerca: Combatant = pelea._enemies[0]
	var lejos: Combatant = pelea._enemies[1]
	t.cuerpos[cerca] = _cuerpo(Vector2(50, 0))
	t.cuerpos[lejos] = _cuerpo(Vector2(0, 300))
	for i in range(2, pelea._enemies.size()):
		t.cuerpos[pelea._enemies[i]] = _cuerpo(Vector2(600, i * 40))
	_afirmar(is_equal_approx(t.hueco_entre(yo, cerca), 18.0), "el hueco no se mide borde a borde: %.1f" % t.hueco_entre(yo, cerca))
	_afirmar(t.llega(yo, cerca) and not t.llega(yo, lejos), "el alcance no separa al de cerca del de lejos")

	pelea._player = yo
	pelea._state = pelea.State.WAITING_PLAYER
	pelea._target_idx = pelea._enemies.find(lejos)
	pelea._mostrar_acciones()
	var b: Button = pelea._action_buttons[pelea.Action.ATTACK]
	_afirmar(b.disabled and b.text == "Atacar", "con el objetivo lejos y otro a tiro, Atacar tendria que apagarse (disabled=%s, '%s')" % [b.disabled, b.text])
	pelea._target_idx = pelea._enemies.find(cerca)
	pelea._refresh_actions()
	_afirmar(not b.disabled, "con el objetivo a tiro, Atacar sigue apagado")
	# Lejos de todos: Esperar, encendido, y pulsarlo cede el turno sin pegar.
	t.cuerpos[yo].global_position = Vector2(-200, 0)
	pelea._refresh_actions()
	_afirmar(not b.disabled and b.text == "Esperar", "lejos de todos tendria que ser Esperar (disabled=%s, '%s')" % [b.disabled, b.text])
	var vida_antes: float = cerca.current_hp
	pelea._on_action(pelea.Action.ATTACK)
	_afirmar(pelea._state == pelea.State.ADVANCING, "Esperar no cede el turno (estado %d)" % pelea._state)
	_afirmar(is_equal_approx(cerca.current_hp, vida_antes), "Esperar ha pegado")

	# EL ENEMIGO QUE NO LLEGA: clavado (radio 0 por enraizado no: atascado) y lejos de todos.
	pelea._state = pelea.State.PAUSED
	pelea._pause_left = INF
	t.bloqueado = true
	var vidas: Array = []
	for c in pelea._aliados:
		vidas.append(c.current_hp)
	t.turno_enemigo(lejos)
	await _esperar_a(func() -> bool: return t._fase == t.Fase.NADA, 4.0)
	var dijo: bool = false
	for l in pelea._log_lines:
		if "no llega" in l:
			dijo = true
	_afirmar(dijo, "el enemigo que no llega no lo dice en el registro")
	_afirmar(pelea._pause_left != INF, "el enemigo que no llega cuelga la pelea")
	var pego: bool = false
	for i in pelea._aliados.size():
		if pelea._aliados[i].current_hp < float(vidas[i]):
			pego = true
	_afirmar(not pego, "el enemigo que no llega ha pegado igual")
	_afirmar(t.atacante == null, "el atacante se queda puesto despues de su turno")

	# EL DE AL LADO SI PEGA (o esquivan): su sorteo sale con alguien.
	t.cuerpos[yo].global_position = Vector2(0, 0)
	cerca.alcance = 20.0   # a 18 de hueco: con su alcance de serie (10) no llegaria
	t.atacante = cerca
	_afirmar(pelea.objetivos._elegir_objetivo_enemigo() == yo, "el sorteo del enemigo de al lado no se queda con el unico a tiro")
	t.atacante = null

	# LA HOLGURA de otro humano: a 3 px de mas de su alcance, en quien lleva la pelea, llega.
	var otro: Combatant = pelea._aliados[1]
	otro.alcance = 20.0
	pelea._dueno_aliado[otro] = 42
	# Su nodo esta en otra parte: lo que manda es la posicion SELLADA con su accion.
	t.cuerpos[otro].global_position = Vector2(-400, 0)
	t._pos[otro] = Vector2(0, 55)
	# Un enemigo en (0, 110): de 55 a 110 son 55 px de centro a centro, 23 de hueco. Alcance 20 + holgura.
	t.cuerpos[pelea._enemies[2]].global_position = Vector2(0, 110)
	_afirmar(is_equal_approx(t.hueco_entre(otro, pelea._enemies[2]), 23.0), "el hueco no sale de la posicion SELLADA: %.1f" % t.hueco_entre(otro, pelea._enemies[2]))
	_afirmar(t.llega(otro, pelea._enemies[2]), "a otro humano no se le da holgura")
	pelea.queue_free()
	await get_tree().process_frame


# 9) LA HUELLA (fase 5, el martillo): el GOLPE SISMICO cae en la punta del arma hacia donde apuntas,
#    nunca mas lejos; el nucleo cobra entero, el anillo area_secundario, lo de fuera nada; sin tope de
#    enemigos; y apuntar al vacio no pilla a nadie (golpea el suelo).
func _probar_huella() -> void:
	var sismico: AbilityData = load("res://resources/abilities/golpe_sismico.tres")
	_afirmar(sismico.forma_apunte == CombatFormas.Apunte.DELANTE and sismico.forma_nucleo > 0.0,
		"la ficha del golpe sismico no trae su huella del mapa")
	var escena: PackedScene = load(ESCENA)
	var pelea: Node = escena.instantiate()
	pelea.process_mode = Node.PROCESS_MODE_ALWAYS
	pelea.tactico = true
	add_child(pelea)
	await get_tree().process_frame
	await get_tree().process_frame
	pelea._state = pelea.State.PAUSED
	pelea._pause_left = INF
	var t: TacticoDePrueba = TacticoDePrueba.new(pelea)
	pelea.turno_mapa = t
	_afirmar(t.usa_huella(sismico), "en el mapa el golpe sismico no usa su huella")
	var yo: Combatant = pelea._aliados[0]
	yo.alcance = 43.0
	t.cuerpos[yo] = _cuerpo(Vector2(0, 0))
	for i in range(1, pelea._aliados.size()):
		t.cuerpos[pelea._aliados[i]] = _cuerpo(Vector2(-600, i * 40))
	# Apuntando MUY lejos a la derecha: el centro se queda en la punta del arma (16 de medio cuerpo
	# + 43 de alcance = x 59).
	var f = t.forma_de(sismico, yo, Vector2(1000, 0))
	_afirmar(absf(f.centro.x - 59.0) < 0.5 and absf(f.centro.y) < 0.5, "el centro pasa de la punta del arma: %s" % str(f.centro))
	# Uno en el NUCLEO (en el centro), otro en el ANILLO, otro FUERA, y el resto lejos.
	var en_nucleo: Combatant = pelea._enemies[0]
	var en_anillo: Combatant = pelea._enemies[1]
	var fuera: Combatant = pelea._enemies[2]
	t.cuerpos[en_nucleo] = _cuerpo(Vector2(59, 0))
	t.cuerpos[en_anillo] = _cuerpo(Vector2(59, 60))   # su caja empieza a 44 del centro: dentro de 65
	t.cuerpos[fuera] = _cuerpo(Vector2(59, 200))
	for i in range(3, pelea._enemies.size()):
		t.cuerpos[pelea._enemies[i]] = _cuerpo(Vector2(600, i * 40))
	t.anotar_apunte([1000.0, 0.0])
	var rep: Array = t.reparto_habilidad(sismico, yo)
	var por: Dictionary = {}
	for o in rep:
		por[o["c"]] = float(o["escala"])
	_afirmar(is_equal_approx(float(por.get(en_nucleo, -1.0)), 1.0), "el del nucleo no cobra entero: %s" % str(por.get(en_nucleo)))
	_afirmar(is_equal_approx(float(por.get(en_anillo, -1.0)), sismico.area_secundario), "el del anillo no cobra el secundario: %s" % str(por.get(en_anillo)))
	_afirmar(not por.has(fuera), "le da al que esta fuera de la huella")
	_afirmar(not rep.is_empty() and rep[0]["c"] == en_nucleo, "el principal no es el del centro")
	# SIN TOPE: cuatro dentro, cuatro pillados.
	for i in range(3, pelea._enemies.size()):
		t.cuerpos[pelea._enemies[i]].global_position = Vector2(59 + i * 6, -30)
	_afirmar(t.reparto_habilidad(sismico, yo).size() == 2 + pelea._enemies.size() - 3,
		"con todos dentro no los pilla a todos: hay tope")
	# LA ONDA EXPANSIVA, un cono hacia donde apuntas: el de delante entra, el de detras no.
	var onda: AbilityData = load("res://resources/abilities/onda_expansiva.tres")
	var temblor: AbilityData = load("res://resources/abilities/temblor.tres")
	t.cuerpos[en_nucleo].global_position = Vector2(40, 0)
	t.cuerpos[fuera].global_position = Vector2(-40, 0)
	t.anotar_apunte([1000.0, 0.0])
	var por_onda: Array = t.reparto_habilidad(onda, yo).map(func(o): return o["c"])
	_afirmar(por_onda.has(en_nucleo) and not por_onda.has(fuera), "el cono no pilla al de delante o pilla al de detras")
	# EL TEMBLOR, alrededor tuyo y al 70% para todos: los dos de antes (delante y detras) entran.
	var rep_t: Array = t.reparto_habilidad(temblor, yo)
	var por_t: Dictionary = {}
	for o in rep_t:
		por_t[o["c"]] = float(o["escala"])
	_afirmar(por_t.has(en_nucleo) and por_t.has(fuera), "el temblor no pilla a los que tienes alrededor")
	_afirmar(is_equal_approx(float(por_t.get(fuera, 0.0)), temblor.forma_escala), "el temblor no pega su 70%")
	t.cuerpos[fuera].global_position = Vector2(-300, 0)
	_afirmar(not t.reparto_habilidad(temblor, yo).map(func(o): return o["c"]).has(fuera), "el temblor pilla al que esta lejos")
	t.cuerpos[en_nucleo].global_position = Vector2(59, 0)
	t.cuerpos[fuera].global_position = Vector2(59, 200)

	# AL VACIO: hacia la izquierda no hay nadie.
	t.anotar_apunte([-1000.0, 0.0])
	_afirmar(t.reparto_habilidad(sismico, yo).is_empty(), "apuntando al vacio pilla a alguien")
	# Y RESUELTA DE VERDAD (por _usar_habilidad de siempre): al del nucleo le baja la vida o esquiva;
	# al de fuera, nada.
	t.anotar_apunte([1000.0, 0.0])
	pelea._player = yo
	pelea._state = pelea.State.WAITING_PLAYER
	yo.current_energy = yo.max_energy
	var vida_fuera: float = fuera.current_hp
	pelea.habilidades._usar_habilidad(sismico)
	_afirmar(is_equal_approx(fuera.current_hp, vida_fuera), "el golpe sismico le ha pegado al de fuera")
	var dijo: bool = false
	for l in pelea._log_lines:
		if "Golpe sísmico" in l:
			dijo = true
	_afirmar(dijo, "el golpe sismico no sale en el registro")

	# QUE LOS DEMAS LA VEAN: quien lleva la pelea la apunta en su lista, la empaqueta, y un espejo la
	# pinta en SU arena con el mismo centro y el mismo nucleo.
	var f_red = t.forma_de(sismico, yo, Vector2(1000, 0))
	t._anotar_huella_red(yo, t.CLASE_APUNTANDO, f_red, sismico.forma_nucleo)
	var datos: PackedFloat32Array = t.estado_huellas()
	_afirmar(datos.size() == t.FLOATS_HUELLA, "el paquete de huellas no mide lo que tiene que medir: %d" % datos.size())
	var espejo: Node = escena.instantiate()
	espejo.process_mode = Node.PROCESS_MODE_ALWAYS
	espejo.tactico = true
	add_child(espejo)
	await get_tree().process_frame
	espejo._espejo = true
	espejo._state = espejo.State.PAUSED
	var t2: TacticoDePrueba = TacticoDePrueba.new(espejo)
	espejo.turno_mapa = t2
	var arena := ArenaCombate.new()
	add_child(arena)
	var antes_arena = Game._arena_nodo
	Game._arena_nodo = arena
	t2.aplicar_huellas(datos)
	_afirmar(arena.huellas.size() == 1, "el espejo no pinta la huella que le llega (%d)" % arena.huellas.size())
	for k in arena.huellas:
		var h: Dictionary = arena.huellas[k]
		_afirmar((h["forma"].centro as Vector2).distance_to(f_red.centro) < 0.01 and is_equal_approx(float(h["nucleo"]), sismico.forma_nucleo),
			"la huella del espejo no es la de quien apunta")
	# Llega un paquete sin ella: se quita.
	t2.aplicar_huellas(PackedFloat32Array())
	_afirmar(arena.huellas.is_empty(), "la huella se queda pintada cuando ya no llega")
	# La de un espejo que NO tiene el turno (o que no es su dueño) no se acepta.
	pelea._state = pelea.State.WAITING_PLAYER
	pelea._player = yo
	t._huellas_red.clear()
	t.huella_de_espejo(t._empaquetar(0, t.CLASE_APUNTANDO, f_red, 0.0), 42)
	_afirmar(t._huellas_red.is_empty(), "acepta la huella de un humano que no es el dueño del que tiene el turno")
	Game._arena_nodo = antes_arena
	arena.queue_free()
	espejo.queue_free()
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
