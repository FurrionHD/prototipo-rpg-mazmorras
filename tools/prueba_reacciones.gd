# HERRAMIENTA. No forma parte del juego.
#
#   godot --headless --path . res://tools/prueba_reacciones.tscn
#
# EL HIELO Y LAS REACCIONES (12/11/2026; la tabla y las reglas, con el jefe el 10/11 y el 12/11): la tabla nueva de
# elementos, el Frio / Congelado / Deshielo, y las reacciones en una pelea de mapa de verdad: se congela, se rompe, las
# esquirlas del rayo, se derrite, la sobrecarga (empuja 18 px) y lo que extiende el viento.
extends Node

var sala = null   # su sala: tools/prueba_sala_propia.gd

var _mal: int = 0

const H := Elementos.Elemento.HIELO
const ID := StatusEffects.Id


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


func _casi(a: float, b: float) -> bool:
	return absf(a - b) < 0.001


# Un combatiente de AFINIDAD pura del elemento 'elem', sin nada mas (el slime de siempre).
func _de(elem: int) -> Combatant:
	var c: Combatant = (load("res://scenes/actors/enemy/slime.tres") as EnemyData).crear_combatant(0.5, false)
	c.elemento = elem
	c.elemento_intensidad = Elementos.INTENSIDAD_PURA
	c.resist_elemental = {}
	return c


func _poner(tm, c: Combatant, p: Vector2) -> void:
	var cu: Node2D = tm.cuerpo_de(c)
	cu.global_position += p - tm.pies_de(c)
	tm._pos[c] = cu.global_position


func _empuja(tm, c: Combatant) -> float:
	for tr in tm._tirones:
		if tr.get("c") == c:
			return float(tr.get("px", 0.0))
	return 0.0


func _limpiar(lista: Array) -> void:
	for c in lista:
		(c as Combatant).statuses.clear()
		(c as Combatant).current_hp = (c as Combatant).max_hp


func _correr() -> void:
	var E := Elementos.Elemento
	print("1) LA TABLA (10/11)")
	for fila in [[E.FUEGO, H, 0.5], [E.FUEGO, E.AGUA, 1.5], [E.AGUA, H, 1.5], [E.AGUA, E.RAYO, 1.5],
			[E.AGUA, E.FUEGO, 0.5], [E.RAYO, E.VIENTO, 1.5], [E.RAYO, E.RAYO, 0.5], [E.VIENTO, E.RAYO, 1.5],
			[E.VIENTO, E.VIENTO, 0.5], [H, E.FUEGO, 1.5], [H, H, 0.5], [H, E.AGUA, 1.0], [E.NINGUNO, H, 1.0]]:
		var m: float = Elementos.mult_recibido(fila[1], _de(fila[0]))
		_ver(_casi(m, fila[2]), "%s recibe %s a x%s (sale %.2f)" % [Elementos.nombre(fila[0]), Elementos.nombre(fila[1]),
			fila[2], m])
	_ver(H == 7 and Elementos.Elemento.VIENTO == 6, "el hielo va al final (no renumera a nadie)")
	_ver(Elementos.TODOS.has(H) and not Elementos.AZAR_MAGIA.has(H), "sale en las fichas, no al azar en las magias")
	_ver(Elementos.nombre(H) == "Hielo" and Elementos.tiene_color(H), "tiene nombre y color")

	print("2) FRIO, CONGELADO Y DESHIELO")
	_ver(String(StatusEffects.def(ID.CONGELACION)["nombre"]) == "Frío", "la Congelacion de antes se llama Frio")
	var c: Combatant = _de(E.NINGUNO)
	c.apply_status(ID.CONGELADO)
	var t1: Dictionary = c.tick_statuses()
	_ver(bool(t1.get("stunned", false)), "Congelado: pierde el turno entero")
	_ver(not c.has_status(ID.CONGELADO) and c.has_status(ID.DESHIELO), "y se le va dejando el Deshielo")
	c.apply_status(ID.CONGELADO)
	_ver(not c.has_status(ID.CONGELADO), "con Deshielo no se le puede volver a congelar")
	var t2: Dictionary = c.tick_statuses()
	_ver(not bool(t2.get("stunned", false)) and c.has_status(ID.DESHIELO), "el turno siguiente actua, aun con Deshielo")
	c.tick_statuses()
	_ver(c.has_status(ID.DESHIELO), "y el otro tambien (dos turnos)")
	c.tick_statuses()
	_ver(not c.has_status(ID.DESHIELO), "luego se va")
	c.apply_status(ID.CONGELADO)
	_ver(c.has_status(ID.CONGELADO), "y ya se le puede congelar otra vez")
	_ver(_casi(Elementos.mult_recibido(E.NINGUNO, c), 1.5), "un golpe fisico al congelado: x1,5 (Se rompe)")
	_ver(_casi(Elementos.mult_recibido(E.FUEGO, c), 1.0), "(uno de fuego, no)")
	c.quitar_estado(ID.CONGELADO)
	_ver(c.has_status(ID.DESHIELO), "quitarle el hielo a mano tambien deja Deshielo")
	_ver(_de(H).es_inmune(ID.CONGELADO) and _de(H).es_inmune(ID.CONGELACION), "al de hielo ni frio ni congelado")
	var q: Combatant = _de(E.NINGUNO)
	q.apply_status(ID.QUEMADURA)
	_ver(_casi(Elementos.mult_recibido(E.RAYO, q), 1.5), "rayo sobre quemado: x1,5 (Sobrecarga)")

	print("3) LA PELEA")
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_reacciones", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(70, 0), {})
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(90, 40), {})
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(110, -40), {})
	await _esperar(25)
	var nodos: Array = get_tree().get_nodes_in_group("enemy")
	if not (await sala.pelear(nodos, false) != null):
		print("FIN: HAY FALLOS (no arranca la pelea)")
		get_tree().quit(1)
		return
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	combat.set_process(false)   # la barra la movemos a mano
	var tm = combat.turno_mapa
	var re = combat.reacciones
	var en: Array = combat._enemies.duplicate()
	var yo: Combatant = combat._player
	_ver(en.size() >= 3 and combat.tactico, "tres slimes en el mapa")
	if en.size() < 3:
		print("FIN: HAY FALLOS (%d MAL)" % _mal)
		get_tree().quit(1)
		return
	for e in en:
		(e as Combatant).status_resist = 0.0
		(e as Combatant).max_hp = 9999.0
	# a (el que recibe) y b pegados; lejos, a 300 px.
	var a: Combatant = en[0]
	var b: Combatant = en[1]
	var lejos: Combatant = en[2]
	var p: Vector2 = tm.pies_de(a)
	_poner(tm, b, p + Vector2(24, 0))
	_poner(tm, lejos, p + Vector2(300, 0))
	_poner(tm, yo, p + Vector2(-60, 0))
	_ver(tm.hueco_entre(a, b) <= re.PEGADOS and tm.hueco_entre(a, lejos) > re.PEGADOS,
		"b pegado a a (%.0f px), el otro lejos (%.0f px)" % [tm.hueco_entre(a, b), tm.hueco_entre(a, lejos)])

	print("4) SE CONGELA")
	_limpiar(en)
	a.apply_status(ID.MOJADO)
	re.al_entrar(yo, a, 5.0, H)
	_ver(a.has_status(ID.CONGELADO) and not a.has_status(ID.MOJADO), "hielo sobre mojado: Congelado, y se gasta el Mojado")
	_limpiar(en)
	re.al_entrar(yo, a, 5.0, H)
	_ver(not a.has_status(ID.CONGELADO), "(seco, no)")
	a.apply_status(ID.DESHIELO)
	a.apply_status(ID.MOJADO)
	re.al_entrar(yo, a, 5.0, H)
	_ver(not a.has_status(ID.CONGELADO) and a.has_status(ID.MOJADO), "con Deshielo no se congela (y sigue mojado)")

	print("5) SE ROMPE")
	_limpiar(en)
	a.apply_status(ID.CONGELADO)
	re.al_entrar(yo, a, 5.0, E.NINGUNO)
	_ver(not a.has_status(ID.CONGELADO) and a.has_status(ID.DESHIELO), "un golpe fisico lo suelta (y queda el Deshielo)")
	_ver(_casi(b.current_hp, b.max_hp), "(no le salta nada a los de al lado)")

	print("6) ESQUIRLAS")
	_limpiar(en)
	a.apply_status(ID.CONGELADO)
	re.al_entrar(yo, a, 20.0, E.RAYO)
	_ver(not a.has_status(ID.CONGELADO), "el rayo lo suelta")
	var hb: float = b.max_hp - b.current_hp
	_ver(_casi(hb, 20.0 * re.ESQUIRLAS_DANO * Elementos.mult_recibido(H, b)),
		"al pegado le saltan esquirlas de hielo (%.1f, la mitad del golpe)" % hb)
	_ver(_casi(lejos.current_hp, lejos.max_hp), "al de lejos, no")
	await _esperar(2)

	print("7) SE DERRITE")
	_limpiar(en)
	a.apply_status(ID.CONGELACION)
	re.al_entrar(yo, a, 5.0, E.FUEGO)
	_ver(not a.has_status(ID.CONGELACION) and a.has_status(ID.MOJADO), "fuego sobre Frio: se va el frio y queda Mojado")
	_limpiar(en)
	a.apply_status(ID.CONGELADO)
	re.al_entrar(yo, a, 5.0, E.FUEGO)
	_ver(not a.has_status(ID.CONGELADO) and a.has_status(ID.MOJADO) and a.has_status(ID.DESHIELO),
		"fuego sobre Congelado: suelto, Mojado y con Deshielo")
	a.apply_status(ID.QUEMADURA)
	_ver(not a.has_status(ID.QUEMADURA), "(y mojado no arde)")

	print("8) SOBRECARGA")
	_limpiar(en)
	tm._tirones.clear()
	await _esperar(1)
	a.apply_status(ID.QUEMADURA)
	re.al_entrar(yo, a, 5.0, E.RAYO)
	_ver(_casi(_empuja(tm, b), re.SOBRECARGA_EMPUJE), "rayo sobre quemado: aparta al pegado (%.0f px)" % _empuja(tm, b))
	_ver(_casi(_empuja(tm, lejos), 0.0) and _casi(_empuja(tm, a), 0.0), "ni al de lejos ni al quemado")
	var tr_b: Dictionary = {}
	for tr in tm._tirones:
		if tr.get("c") == b:
			tr_b = tr
	_ver(tr_b.get("espera_a") == a, "el empujon arranca con el golpe del quemado, no con uno suyo (a b no le pega nadie)")
	tm._on_golpe_encajado(combat._bloque_de(a), 0.0)
	_ver(float(tr_b.get("t", -1.0)) >= 0.0, "y arranca al verse ese golpe")
	# UN CUERPO, UN TIRON: otro que arranca en b sustituye al que llevaba en marcha (antes se pisaban).
	tm.pedir_tiron(b, yo, -18.0)
	var nuevo_b: Dictionary = tm._tirones.back()
	tm._arrancar_tiron(nuevo_b)
	_ver(not tm._tirones.has(tr_b) and tm._tirones.has(nuevo_b), "un empujon nuevo en el mismo cuerpo sustituye al que iba")
	tm._tirones.clear()

	print("9) EL VIENTO EXTIENDE")
	_limpiar(en)
	await _esperar(1)
	a.apply_status(ID.QUEMADURA, 3, 4.0)
	a.apply_status(ID.RAYO)
	seed(4242)
	re.al_entrar(yo, a, 5.0, E.VIENTO)
	_ver(b.has_status(ID.QUEMADURA) and b.has_status(ID.RAYO), "quemado y electrizado saltan al pegado")
	_ver(not lejos.has_status(ID.QUEMADURA) and not lejos.has_status(ID.RAYO), "al de lejos, no")
	_limpiar(en)
	await _esperar(1)
	a.apply_status(ID.CONGELACION)
	seed(4242)
	re.al_entrar(yo, a, 5.0, E.VIENTO)
	_ver(b.has_status(ID.CONGELACION), "el frio tambien")
	_limpiar(en)
	await _esperar(1)
	a.apply_status(ID.CONGELADO)
	seed(4242)
	re.al_entrar(yo, a, 5.0, E.VIENTO)
	_ver(b.has_status(ID.CONGELACION) and not b.has_status(ID.CONGELADO), "un congelado soplado: a los pegados, Frio (no los congela)")
	_ver(a.has_status(ID.CONGELADO), "y el congelado sigue congelado (el viento no lo rompe)")
	_limpiar(en)
	await _esperar(1)
	a.apply_status(ID.MOJADO)
	seed(4242)
	re.al_entrar(yo, a, 5.0, E.VIENTO)
	_ver(b.has_status(ID.MOJADO), "y el mojado")
	_limpiar(en)
	await _esperar(1)
	a.apply_status(ID.VENENO)
	re.al_entrar(yo, a, 5.0, E.VIENTO)
	_ver(not b.has_status(ID.VENENO), "el veneno no es de elemento: no salta")

	print("10) EL ROTULO DE LA PROPAGACION, DEL COLOR DE LO QUE SALTA")
	var R = re.Reaccion
	for fila in [[E.FUEGO, "fuego"], [E.RAYO, "rayo"], [H, "hielo"], [E.AGUA, "agua"]]:
		var peso: float = float(R.EXTIENDE) / 10.0 + float(fila[0]) / 1000.0
		_ver(re.de_peso(peso) == R.EXTIENDE and re.color_rotulo(peso) == Elementos.color(fila[0]),
			"propaga %s: rotulo de su color" % fila[1])
	for r in [R.CONGELA, R.ROMPE, R.ESQUIRLAS, R.DERRITE, R.SOBRECARGA, R.ESQUIRLA]:
		_ver(re.de_peso(float(r) / 10.0) == r, "el peso de la reaccion %d vuelve entero" % r)
	_ver(re.ROTULO[R.EXTIENDE] == "¡PROPAGACIÓN!", "se llama Propagacion")

	print("11) EN LOS ESPEJOS NO")
	_limpiar(en)
	combat._espejo = true
	a.apply_status(ID.MOJADO)
	re.al_entrar(yo, a, 5.0, H)
	_ver(not a.has_status(ID.CONGELADO), "solo lo resuelve quien lleva la pelea")
	combat._espejo = false

	print("")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
