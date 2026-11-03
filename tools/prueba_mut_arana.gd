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
	_fin()


func _fin() -> void:
	print("FIN: %s" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(1 if _mal > 0 else 0)
