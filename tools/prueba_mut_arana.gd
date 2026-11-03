# LOS MUTANTES DE LA ARAÑA (03/11): Araña -> TEJEDORA DE BRASAS -> ARAÑA TORMENTOSA. El arbol y sus stats (las seis, suma
# 180, la araña estrena Voluntad) y LAS CARGAS: una al empezar su turno y otra al darle con su elemento (que la cura); en
# cuanto llega a 4 estalla, sea su turno o no, y vuelve a 0; aturdirla, asustarla o retrasarla le quita una, y el agua a la
# de fuego. Y el calor de la Tejedora: su veneno pasa a Quemadura sin subir la probabilidad total.
# Sin ventana:
#   godot --headless --path . res://tools/prueba_mut_arana.tscn
extends Node

var sala = null   # su sala: tools/prueba_sala_propia.gd
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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	print("1) EL ARBOL Y LAS STATS")
	var ed: EnemyData = load("res://scenes/actors/enemy/arana.tres")
	var tej: MutacionData = ed.mutacion_de(&"tejedora")
	var tor: MutacionData = ed.mutacion_de(&"tormentosa")
	_ver(tej != null and tej.grado == 1, "la Tejedora es la 1a")
	_ver(tor != null and tor.grado == 2 and tor.desde.has(&"tejedora"), "la Tormentosa, la 2a, sale de ella")
	var suma_n: int = ed.fuerza + ed.resistencia + ed.destreza + ed.agilidad + ed.magia + ed.voluntad
	for m in [tej, tor]:
		var s: int = 0
		for k in m.pesos:
			s += int(m.pesos[k])
		_ver(s == suma_n, "%s suma lo mismo que la araña (%d de %d)" % [m.nombre, s, suma_n])

	print("2) LAS CARGAS")
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_mut_arana", Game.PISO_ARENA):
		_ver(false, "arranca la sala")
		return _fin()
	sala.poner("res://scenes/actors/enemy/arana.tres", Vector2(30, 0), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	nodos[0].aplicar_mutacion(&"tejedora", 0.0)
	await _esperar(5)
	if await sala.pelear(nodos, false) == null:
		_ver(false, "arranca la pelea")
		return _fin()
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)
	var en = combat.enemigos
	var e: Combatant = combat._enemies[0]
	_ver(e.mutacion == &"tejedora" and e.carga_elemento == Elementos.Elemento.FUEGO and e.carga_tope == 4, "en la pelea, una Tejedora con 4 cargas de fuego")
	e.invulnerable = false

	en.sumar_carga(e)
	en.sumar_carga(e)
	_ver(e.cargas == 2, "suma de una en una")
	e.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(e.cargas == 1, "aturdirla le quita una")
	e.quitar_estado(StatusEffects.Id.ATURDIDO)
	e.apply_status(StatusEffects.Id.MOJADO)
	_ver(e.cargas == 0, "y el agua, a la de fuego, otra")
	e.quitar_estado(StatusEffects.Id.MOJADO)
	e.apply_status(StatusEffects.Id.ATURDIDO)
	_ver(e.cargas == 0, "sin cargas no baja de cero")
	e.quitar_estado(StatusEffects.Id.ATURDIDO)

	print("3) SU ELEMENTO LA CURA Y LE DA CARGA, AUNQUE ESTE ATURDIDA")
	e.take_damage(20.0)
	var hp0: float = e.current_hp
	var cargas0: int = e.cargas
	e.apply_status(StatusEffects.Id.ATURDIDO)
	en.absorber_elemento(e, Elementos.Elemento.FUEGO, 0.2)
	_ver(e.cargas == cargas0 + 1, "le dan con fuego: una carga mas")
	_ver(is_equal_approx(e.current_hp, minf(e.max_hp, hp0 + 0.2 / 0.01 * 0.25)), "y se cura la cuarta parte de lo que habria hecho (%.1f de %.1f)" % [e.current_hp, hp0])
	en.absorber_elemento(e, Elementos.Elemento.AGUA, 5.0)
	_ver(e.cargas == cargas0 + 1, "otro elemento no le da nada")

	print("4) A LAS 4 ESTALLA EN EL INSTANTE")
	e.cargas = 3
	var yo: Combatant = combat._aliados[0]
	combat.turno_mapa.cuerpo_de(yo).global_position = combat.turno_mapa.cuerpo_de(e).global_position + Vector2(20, 0)
	var vida0: float = yo.current_hp
	en.absorber_elemento(e, Elementos.Elemento.FUEGO, 0.2)
	_ver(e.cargas == 0, "ha vuelto a cero")
	_ver(yo.current_hp < vida0, "y le ha hecho daño al que estaba cerca (%.1f de %.1f)" % [yo.current_hp, vida0])
	yo.current_hp = vida0
	e.quitar_estado(StatusEffects.Id.ATURDIDO)

	print("5) EL CALOR: LA QUEMADURA SUSTITUYE AL VENENO")
	var v := Combatant.new("Victima", 1, Abilities.new(), 100000.0, 3.0, 3.0, 3.0)
	seed(11)
	e.on_hit = e.on_hit.filter(func(a): return a.estado == StatusEffects.Id.VENENO)
	for carga in [0, 3]:
		e.cargas = carga
		var venenos: int = 0
		var quemaduras: int = 0
		var n: int = 1500
		for i in n:
			for nom in e.roll_on_hit(v):
				if nom == "Veneno":
					venenos += 1
				elif nom == "Quemadura":
					quemaduras += 1
			v.quitar_estado(StatusEffects.Id.VENENO)
			v.quitar_estado(StatusEffects.Id.QUEMADURA)
		print("    con %d cargas: %d venenos y %d quemaduras de %d" % [carga, venenos, quemaduras, n])
		if carga == 0:
			_ver(quemaduras == 0, "sin calor, ninguna Quemadura")
		else:
			_ver(quemaduras > venenos, "con 3 de calor, mas Quemadura (30 %%) que veneno (15 %%)")
	e.cargas = 0

	print("6) LOS RAYOS DE LA TORMENTOSA")
	var tm = combat.turno_mapa
	var efe = combat.efectos
	var uno: Combatant = combat._aliados[0]
	var otro: Combatant = combat._aliados[1] if combat._aliados.size() > 1 else null
	_ver(otro != null, "hay dos personajes para rebotar")
	if otro != null:
		e.rebote_mult = 0.7
		e.rebote_radio = 60.0
		tm.cuerpo_de(uno).global_position = Vector2(500, 500)
		tm.cuerpo_de(otro).global_position = Vector2(2000, 500)
		var h1: float = otro.current_hp
		efe._fx_golpe(e, uno, 5.0, false, false)
		_ver(is_equal_approx(otro.current_hp, h1), "sin nadie a 60 px, el rebote se pierde")
		tm.cuerpo_de(otro).global_position = Vector2(520, 500)
		var h_u: float = uno.current_hp
		efe._fx_golpe(e, uno, 5.0, false, false)
		_ver(otro.current_hp < h1, "a tiro, el rebote le entra (%.1f de %.1f)" % [otro.current_hp, h1])
		_ver(is_equal_approx(uno.current_hp, h_u), "y sin Electrizado no sigue la cadena")
		otro.apply_status(StatusEffects.Id.RAYO)
		var h_u2: float = uno.current_hp
		var h_o2: float = otro.current_hp
		efe._fx_golpe(e, uno, 5.0, false, false)
		_ver(otro.current_hp < h_o2 and uno.current_hp < h_u2, "si el que lo recibe esta Electrizado, salta otra vez, y puede volver al primero")
		# Cada rebote sale una vez aunque la cadena pase por Electrizados: el tope son 2 por golpe.
		uno.apply_status(StatusEffects.Id.RAYO)
		h_u2 = uno.current_hp
		h_o2 = otro.current_hp
		efe._fx_golpe(e, uno, 5.0, false, false)
		var perdio_o: float = h_o2 - otro.current_hp
		var perdio_u: float = h_u2 - uno.current_hp
		_ver(perdio_o > 0.0 and perdio_u > 0.0 and perdio_o < perdio_u * 1.6 and perdio_u < perdio_o * 1.6, "tope 2 rebotes: uno a cada uno (%.1f y %.1f)" % [perdio_o, perdio_u])
		e.rebote_mult = 0.0
	print("8) EL CAPULLO")
	_ver(e.es_inmune(StatusEffects.Id.QUEMADURA), "la Tejedora no se quema")
	var presa: Combatant = combat._aliados[0]
	var n0: int = combat._enemies.size()
	en.poner_capullo(e, presa)
	await _esperar(20)
	var cap: Combatant = combat._enemies[combat._enemies.size() - 1]
	_ver(combat._enemies.size() == n0 + 1 and cap.capullo_madre == e, "nace un enemigo de verdad, en la lista de enemigos")
	_ver(is_equal_approx(cap.max_hp, e.max_hp * 0.35) and is_equal_approx(cap.current_hp, cap.max_hp), "con el 35 %% de la vida de la Tejedora (%.1f de %.1f)" % [cap.max_hp, e.max_hp])
	_ver(presa.has_status(StatusEffects.Id.ENCAPULLADO) and presa.enraizado(), "y el atrapado se queda clavado")
	_ver(not combat._bloque_de(cap).is_empty(), "tiene su bloque: su barra de vida, y se le puede elegir")
	combat.figuras._seleccionar(combat._enemies.find(cap))
	_ver(combat._objetivo() == cap, "se le puede elegir de objetivo")
	cap.current_hp = 0.0
	combat._morir_enemigo(cap)
	_ver(not presa.has_status(StatusEffects.Id.ENCAPULLADO), "al romperse, suelta al atrapado")
	en.poner_capullo(e, presa)
	await _esperar(20)
	var cap2: Combatant = combat._enemies[combat._enemies.size() - 1]
	presa.quitar_estado(StatusEffects.Id.ENCAPULLADO)
	en.revisar_capullos()
	_ver(not cap2.is_alive(), "se le acaban los turnos al atrapado: el capullo se deshace")
	var pre3 = presa
	en.poner_capullo(e, pre3)
	await _esperar(20)
	var cap3: Combatant = combat._enemies[combat._enemies.size() - 1]
	en.al_morir_capullo(e)
	_ver(not cap3.is_alive() and not pre3.has_status(StatusEffects.Id.ENCAPULLADO), "si muere la Tejedora, se deshace y lo suelta")
	print("7) LO QUE SE VE")
	var rayos := AranaAire.rayos(self, Vector2.ZERO, 80.0, 3)
	var fog := AranaAire.fogonazo(self, Vector2.ZERO, 60.0, 3)
	await _esperar(3)
	_ver(is_instance_valid(rayos) and is_instance_valid(fog), "los efectos nacen sin petar")
	_ver(AranaAire.CIAN.b > AranaAire.CIAN.r, "los rayos, en azul y no en amarillo")
	e.cargas = 2
	combat.turno_mapa._arana.tick()
	_ver(combat.turno_mapa._arana._cargas.has(e), "la cargada lleva su contador encima")
	e.cargas = 0
	var ed2: EnemyData = load("res://scenes/actors/enemy/arana.tres")
	var m_tej: Array = ed2.mutacion_de(&"tejedora").habilidades.map(func(a): return a.nombre)
	var m_tor: Array = ed2.mutacion_de(&"tormentosa").habilidades.map(func(a): return a.nombre)
	_ver(not m_tej.has("Mordisco ponzoñoso") and m_tej.has("Hilo al rojo"), "la Tejedora no lleva el Mordisco (%s)" % str(m_tej))
	_ver(m_tor.size() == 4 and m_tor.has("Mordisco eléctrico"), "la Tormentosa lleva sus cuatro (%s)" % str(m_tor))
	var mor: AbilityData = ed2.mutacion_de(&"tormentosa").habilidades[1]
	_ver(mor.efectos[0].estado == StatusEffects.Id.PARALISIS, "su Mordisco pone Paralisis")
	_fin()


func _fin() -> void:
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(1 if _mal > 0 else 0)
