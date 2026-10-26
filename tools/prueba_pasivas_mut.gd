# LAS PASIVAS DE LAS MUTACIONES DEL SLIME (06/10): ESPINAS (al pegarle cuerpo a cuerpo, 50 % de su ataque a los que le
# rodean; aqui con la probabilidad forzada) y DIVIDIRSE al morir (salen dos slimes normales; su cadaver se queda). Sin ventana:
#   godot --headless --path . res://tools/prueba_pasivas_mut.tscn
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
	# EN SU SALA (etapa 4, 26/10): la prueba es la sala y la pelea se abre por donde la abre ella.
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_pasivas_mut", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(70, 0), {})
	await _esperar(25)
	var nodo = get_tree().get_nodes_in_group("enemy")[0]
	nodo.mutante = true
	nodo.mutacion = &"brotado_punzante"
	if not (await sala.pelear([nodo], false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	await _esperar(8)
	var combat: Node = null
	for n in get_tree().root.get_children() + sala.capas():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	var tm = combat.turno_mapa
	var e: Combatant = combat._enemies[0]
	var al: Combatant = combat._aliados[0]
	print("enemigo: %s (grado %d, ataque %.1f)" % [e.nombre, e.grado_mut, e.atk()])
	_ver(e.nombre == "Slime brotado punzante", "en la pelea es el brotado punzante")
	_ver(e.espinas and e.se_divide and is_equal_approx(e.espinas_prob, 0.3) and is_equal_approx(e.espinas_dano, 0.5),
		"el brotado punzante trae espinas (30 %, 50 %) y se divide")
	print("1) espinas: le pegas cuerpo a cuerpo")
	var cu_e: Node2D = tm.cuerpo_de(e)
	var cu_a: Node2D = tm.cuerpo_de(al)
	cu_a.global_position = cu_e.global_position + Vector2(-34, 0)
	tm._pos[al] = cu_a.global_position
	e.espinas_prob = 1.0
	var hp0: float = al.current_hp
	combat._pasiva_al_golpearle(e, al)
	var quito: float = hp0 - al.current_hp
	print("    hueco %.1f px, le quita %.1f (50 %% de su ataque = %.1f)" % [tm.hueco_entre(al, e), quito, e.atk() * 0.5])
	_ver(absf(quito - e.atk() * 0.5) < 0.6, "las puas le hacen el 50 % de su ataque")
	print("1b) una RAFAGA (4 golpes en la misma accion): UNA tirada, no cuatro (playtest 08/10)")
	var hp_r: float = al.current_hp
	for _g in 3:
		combat._pasiva_al_golpearle(e, al, 10.0)
	_ver(is_equal_approx(hp_r, al.current_hp), "los golpes 2..4 de la misma accion no vuelven a soltar puas")
	combat.enemigos._abrir_turno_enemigo()
	_ver(combat._pasiva_hecha.is_empty(), "el turno de un enemigo abre otra accion")
	combat._pasiva_al_golpearle(e, al, 10.0)
	_ver(al.current_hp < hp_r - 0.5, "en la accion siguiente vuelve a tirar")
	combat._pasiva_hecha.clear()
	print("1c) obsidiana: devolver corte, una vez por accion")
	var e_dev: float = e.devuelve_corte_prob
	var esp: bool = e.espinas
	e.espinas = false
	e.devuelve_corte_prob = 1.0
	var e_frac: float = e.devuelve_corte_frac
	e.devuelve_corte_frac = 0.5   # el de la obsidiana (este es un punzante)
	var tipo0: int = al.dano_tipo
	al.dano_tipo = 0
	var hp_d: float = al.current_hp
	for _g in 4:
		combat._pasiva_al_golpearle(e, al, 20.0)
	var vuelto: float = hp_d - al.current_hp
	print("    devuelto %.2f (la mitad de UN golpe de 20 = %.2f)" % [vuelto, 20.0 * e.devuelve_corte_frac])
	_ver(absf(vuelto - 20.0 * e.devuelve_corte_frac) < 0.01, "devuelve la mitad de un solo golpe")
	e.devuelve_corte_prob = e_dev
	e.devuelve_corte_frac = e_frac
	e.espinas = esp
	al.dano_tipo = tipo0
	combat._pasiva_hecha.clear()
	print("2) de lejos no (magia o arco)")
	cu_a.global_position = cu_e.global_position + Vector2(-200, 0)
	tm._pos[al] = cu_a.global_position
	var hp1: float = al.current_hp
	combat._pasiva_al_golpearle(e, al)
	_ver(is_equal_approx(hp1, al.current_hp), "a distancia no le saltan")
	print("3) se divide al morir")
	var antes: int = 0
	for x in combat._enemies:
		if x.is_alive():
			antes += 1
	var caja_b: Rect2 = tm.bulto_de(e)
	var cuerpo_b: Node2D = tm.cuerpo_de(e)
	e.current_hp = 0.0
	combat._morir_enemigo(e)
	# Que vuelen y caigan (T_VUELO_CRIA) y se levanten.
	var t_v: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t_v < 2000:
		await get_tree().process_frame
	var vivos: Array = []
	for x in combat._enemies:
		if x.is_alive():
			vivos.append(x.nombre)
	print("    vivos: %s" % [vivos])
	_ver(vivos.size() == antes - 1 + 2, "salen dos (%d vivos)" % vivos.size())
	_ver(vivos.count("Slime") == 2, "y son slimes NORMALES")
	print("4) las crias se VEN y salen LANZADAS (playtest 08/10: invisibles o pegadas)")
	var crias: Array = []
	for x in combat._enemies:
		if x.is_alive():
			crias.append(x)
	var cajas: Array = []
	for cr in crias:
		var cc: Node2D = tm.cuerpo_de(cr)
		_ver(cc != null and cc != cuerpo_b, "la cria tiene SU cuerpo (no el del brotado)")
		if cc == null:
			continue
		var cr_caja: Rect2 = tm.bulto_de(cr)
		cajas.append(cr_caja)
		var hueco: float = Cuerpos.hueco_entre(cr_caja, caja_b)
		print("    cria en %s: alfa %.2f, visible %s, %.1f px del borde del brotado" % [str(cc.global_position.round()),
			cc.modulate.a, cc.is_visible_in_tree(), hueco])
		_ver(cc.modulate.a > 0.95 and cc.is_visible_in_tree(), "y se ve")
		_ver(hueco >= 42.0 and hueco <= 115.0, "cae a 50-80 px del borde del brotado (%.0f px)" % hueco)
		_ver(not cc.has_meta("gesto_pelea") or String((cc.get("_sprite") as AnimatedSprite2D).animation).begins_with("nacer"),
			"y se ha levantado (o se esta levantando)")
	if cajas.size() == 2:
		_ver(Cuerpos.hueco_entre(cajas[0], cajas[1]) > 0.0, "las dos no se pisan")
		_ver(((cajas[0] as Rect2).get_center() - caja_b.get_center()).dot((cajas[1] as Rect2).get_center() - caja_b.get_center()) < 0.0,
			"y salen a lados opuestos")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
