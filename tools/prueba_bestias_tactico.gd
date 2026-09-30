# LAS BESTIAS EN EL TACTICO (30/09): acorazada, acechador y aberracion. Sin ventana:
#   godot --headless --path . res://tools/prueba_bestias_tactico.tscn
# Alcances, la Carga acorazada con su pisoton, el Caparazon (de frente la mitad, volcada mas), el Olor a sangre del
# acechador (presa y daño) y su Salto a la yugular, las formas de la aberracion y su Carne que se cierra (la luz la
# corta). Acaba con BIEN/MAL.
extends Node

const ENEMIGOS := ["bestia_acorazada", "acechador", "aberracion"]
const ALCANCES := {"bestia_acorazada": 20.0, "acechador": 20.0, "aberracion": 35.0}
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


func _segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _correr() -> void:
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if ref is SaveData:
		Game.importar_partida(ref)
	Game.semilla_mundo = 424242
	get_tree().change_scene_to_file("res://scenes/levels/town.tscn")
	await _esperar(5)
	Game.entrar_arena_de_pruebas()
	await _esperar(15)
	var jug: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	for i in ENEMIGOS.size():
		Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/%s.tres" % ENEMIGOS[i],
			jug.global_position + Vector2(-200 + 200 * i, 60), {})
	await _esperar(25)
	if not Game.start_combat(get_tree().get_nodes_in_group("enemy"), false):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children():
		if n is CanvasLayer:
			for h in n.get_children():
				if h.get("tactico") != null:
					combat = h
	if combat == null or not combat.tactico:
		print("MAL: la pelea no es tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var al: Array = combat._aliados
	if al.size() < 2:
		print("MAL: hacen falta dos de los tuyos y hay %d" % al.size())
		get_tree().quit(1)
		return
	for a in al:
		a.max_hp = 99999.0
		a.current_hp = 99999.0
	for e in combat._enemies:
		var ed: EnemyData = t.cuerpo_de(e).get("data") if t.cuerpo_de(e) != null else null
		if ed == null:
			continue
		var clave: String = String(ed.resource_path).get_file().get_basename()
		if not ALCANCES.has(clave):
			continue
		print("--- %s (alcance %.0f) ---" % [clave, t.alcance_de(e)])
		_ver(is_equal_approx(t.alcance_de(e), float(ALCANCES[clave])), "alcance del basico %.0f" % ALCANCES[clave])
		if clave == "bestia_acorazada":
			await _probar_acorazada(combat, t, e, al)
		if clave == "acechador":
			await _probar_acechador(combat, t, e, al)
		if clave == "aberracion":
			await _probar_aberracion(combat, t, e, al)
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _escala_de(rep: Array, c) -> float:
	for d in rep:
		if d["c"] == c:
			return float(d["escala"])
	return -1.0


func _mirar(t, e, dir: Vector2) -> void:
	t.cuerpo_de(e).set("_facing", dir)


func _probar_acorazada(combat, t, e, al: Array) -> void:
	var car: AbilityData = load("res://resources/abilities/bestia_carga.tres")
	var pe: Vector2 = t.pies_de(e)
	var f = t.forma_de(car, e, pe + Vector2(200, 0))
	var fin: Vector2 = f.origen + f.dir * f.largo
	# Uno en medio de la linea y otro fuera de ella, al lado del final: solo le pilla el pisoton.
	_colocar(t, al, [f.origen + f.dir * 40.0, fin + Vector2(0, 26)])
	await _esperar(2)
	var rep: Array = t._reparto_en(car, e, f)
	print("  carga: %s" % _txt(rep))
	_ver(_escala_de(rep, al[0]) == 1.0, "la Carga arrolla al de la linea")
	_ver(_escala_de(rep, al[1]) == 1.0, "el pisoton del final pilla entero al de al lado del final")
	_colocar(t, al, [f.origen + f.dir * 40.0, fin + Vector2(0, 80)])
	await _esperar(2)
	_ver(_escala_de(t._reparto_en(car, e, f), al[1]) < 0.0, "y lejos del final no")
	_ver(t.pisoton_de(car, f) != null, "el pisoton tiene su circulo (se pinta en rojo al cargar)")
	# El Caparazon.
	_colocar(t, al, [pe + Vector2(t.radio_pisa(e) + 12, 0), pe + Vector2(-240, 60)])
	await _esperar(2)
	_mirar(t, e, Vector2.RIGHT)
	_ver(is_equal_approx(combat._mult_pasivas(al[0], e), 0.5), "de frente le entra la mitad (%.2f)" % combat._mult_pasivas(al[0], e))
	_colocar(t, al, [pe + Vector2(-t.radio_pisa(e) - 12, 0), pe + Vector2(-240, 60)])
	await _esperar(2)
	_mirar(t, e, Vector2.RIGHT)
	_ver(is_equal_approx(combat._mult_pasivas(al[0], e), 1.0), "por la espalda, entero (%.2f)" % combat._mult_pasivas(al[0], e))
	_colocar(t, al, [pe + Vector2(t.radio_pisa(e) + 12, 0), pe + Vector2(-240, 60)])
	await _esperar(2)
	_mirar(t, e, Vector2.RIGHT)
	e.apply_status(StatusEffects.Id.ATURDIDO, 1)
	_ver(is_equal_approx(combat._mult_pasivas(al[0], e), 1.5), "aturdida se vuelca: +50%% aunque sea de frente (%.2f)" % combat._mult_pasivas(al[0], e))
	e.quitar_estado(StatusEffects.Id.ATURDIDO)
	var r: Dictionary = {"damage": 10.0, "evaded": false}
	combat._aplicar_pasivas(r, al[0], e)
	_ver(is_equal_approx(float(r.damage), 5.0), "y el golpe que se resuelve de frente se queda en la mitad")


func _probar_acechador(combat, t, e, al: Array) -> void:
	var pe: Vector2 = t.pies_de(e)
	_colocar(t, al, [pe + Vector2(200, 0), pe + Vector2(40, 0)])
	await _esperar(2)
	for a in al:
		a.quitar_estado(StatusEffects.Id.SANGRADO)
	al[0].current_hp = al[0].max_hp * 0.5
	al[1].current_hp = al[1].max_hp
	_ver(t._presa_de(e) == al[0], "sin nadie sangrando va a por el de menos vida, aunque este lejos")
	al[0].current_hp = al[0].max_hp
	al[1].current_hp = al[1].max_hp * 0.3
	al[0].apply_status(StatusEffects.Id.SANGRADO, 3)
	_ver(t._presa_de(e) == al[0], "con uno sangrando va a por el, aunque otro tenga menos vida")
	_ver(combat.objetivos.presa_por_olor(e, al) == al[0], "y le pega a el")
	_ver(is_equal_approx(combat._mult_pasivas(e, al[0]), 1.3), "al que sangra le pega un 30%% mas (%.2f)" % combat._mult_pasivas(e, al[0]))
	_ver(is_equal_approx(combat._mult_pasivas(e, al[1]), 1.0), "al que no sangra, normal")
	al[1].current_hp = al[1].max_hp
	# El Salto a la yugular: cae sobre su presa y se queda.
	var sal: AbilityData = load("res://resources/abilities/acechador_salto.tres")
	_colocar(t, al, [pe + Vector2(90, 10), pe + Vector2(-240, 60)])
	await _esperar(2)
	var antes: Vector2 = t.pos_de(e)
	var hp0: float = al[0].current_hp
	var plan: Dictionary = t.mejor_apunte(e, sal, al[0])
	_ver(int(plan["n"]) >= 1, "el Salto llega a su presa a 90 px")
	for _k in 10:
		combat.enemigos._enemy_use_ability(e, sal, al[0])
		combat._fx.arrancar_cola()
		await _segundos(1.2)
		if al[0].current_hp < hp0:
			break
	print("  salto: acabo a %.0f px de donde estaba" % t.pos_de(e).distance_to(antes))
	_ver(t.pos_de(e).distance_to(antes) > 40.0, "salta hasta su presa y se queda alli")
	_ver(al[0].current_hp < hp0, "y la muerde")
	al[0].quitar_estado(StatusEffects.Id.SANGRADO)


func _probar_aberracion(combat, t, e, al: Array) -> void:
	var pe: Vector2 = t.pies_de(e)
	var r0: float = t.radio_pisa(e)
	var lat: AbilityData = load("res://resources/abilities/aberracion_latigazo.tres")
	_colocar(t, al, [pe + Vector2(r0 + 30, 0), pe + Vector2(-r0 - 50, 10)])
	await _esperar(2)
	var rep: Array = t._reparto_en(lat, e, t.forma_de(lat, e, pe))
	_ver(rep.size() == 2 and lat.forma_reparte, "el Latigazo llega a los dos de alrededor y se reparte (%s)" % _txt(rep))
	var ala: AbilityData = load("res://resources/abilities/aberracion_alarido.tres")
	_ver(t._reparto_en(ala, e, t.forma_de(ala, e, pe)).size() == 2, "el Alarido pilla a todos los de alrededor")
	var mir: AbilityData = load("res://resources/abilities/aberracion_mirada.tres")
	_colocar(t, al, [pe + Vector2(r0 + 60, 0), pe + Vector2(r0 + 20, 60)])
	await _esperar(2)
	var rep_m: Array = t._reparto_en(mir, e, t.forma_de(mir, e, t.pies_de(al[0])))
	_ver(rep_m.size() == 1 and rep_m[0]["c"] == al[0], "la Mirada solo a quien tiene delante (%s)" % _txt(rep_m))
	# Carne que se cierra.
	e.regen_cortada = 0
	e.current_hp = e.max_hp * 0.5
	combat.enemigos._regenerar(e)
	_ver(is_equal_approx(e.current_hp, e.max_hp * 0.58), "al empezar su turno se cura el 8%% (%.1f de %.1f)" % [e.current_hp, e.max_hp])
	# La luz de un arma imbuida se la corta.
	var q = al[0]
	var elem0: int = q.imbue_elemento
	var pct0: float = q.imbue_pct
	q.imbue_elemento = Elementos.Elemento.LUZ
	q.imbue_pct = 0.3
	for _k in 50:
		var res: Dictionary = StatsMath.resolve_attack(q, e, false)
		if not res.evaded:
			break
	q.imbue_elemento = elem0
	q.imbue_pct = pct0
	_ver(e.regen_cortada == 2, "un golpe con luz le corta la regeneracion")
	var hp1: float = e.current_hp
	combat.enemigos._regenerar(e)
	combat.enemigos._regenerar(e)
	_ver(is_equal_approx(e.current_hp, hp1), "dos turnos suyos sin curarse")
	combat.enemigos._regenerar(e)
	_ver(e.current_hp > hp1, "y al tercero vuelve a curarse")
	# El fuego no se la corta.
	q.imbue_elemento = Elementos.Elemento.FUEGO
	q.imbue_pct = 0.3
	e.regen_cortada = 0
	for _k in 50:
		var res2: Dictionary = StatsMath.resolve_attack(q, e, false)
		if not res2.evaded:
			break
	q.imbue_elemento = elem0
	q.imbue_pct = pct0
	_ver(e.regen_cortada == 0, "el fuego no se la corta")


func _txt(rep: Array) -> String:
	var out: Array = []
	for d in rep:
		out.append("%s x%.2f" % [d["c"].nombre, float(d["escala"])])
	return "[%s]" % ", ".join(out)


func _colocar(t, al: Array, sitios: Array) -> void:
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else sitios[0] + Vector2(-260 - 40 * i, 90)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
