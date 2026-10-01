# EL MINOTAURO EN EL TACTICO (01/10, paso 1): las formas de sus tres habilidades, el empujon grande de la Cornada y la
# Rabia del guardian (por debajo del 30% de vida pega mas y corre mas). Sin ventana. Copiada de la de los constructos:
#   godot --headless --path . res://tools/prueba_constructos_tactico.tscn
# Alcances, la Machaca (circulo delante, a todos), el Barro blando (el agua le quita lo endurecido y le deja blando),
# el Picado y la Mirada de la gargola y su Posada (es piedra si no se ha movido), el Pisoton del coloso a tramos y su
# Imparable (no se le mueve ni se le corta la carga). Acaba con BIEN/MAL.
extends Node

const ENEMIGOS := ["guardian_rango"]
const ALCANCES := {"guardian_rango": 26.0}
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
			jug.global_position + Vector2(-220 + 220 * i, 70), {})
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
		await _probar_minotauro(combat, t, e, al)
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _escala_de(rep: Array, c) -> float:
	for d in rep:
		if d["c"] == c:
			return float(d["escala"])
	return -1.0


# Un golpe de 'q' con su arma imbuida de 'elem' (hasta que no lo esquive).
func _golpe_de(q: Combatant, e: Combatant, elem: int) -> void:
	var elem0: int = q.imbue_elemento
	var pct0: float = q.imbue_pct
	q.imbue_elemento = elem
	q.imbue_pct = 0.3
	for _k in 50:
		var res: Dictionary = StatsMath.resolve_attack(q, e, false)
		if not res.evaded:
			break
	q.imbue_elemento = elem0
	q.imbue_pct = pct0


func _probar_minotauro(combat, t, e, al: Array) -> void:
	var pe: Vector2 = t.pies_de(e)
	var r0: float = t.radio_pisa(e)
	# LA CORNADA: linea cargada, embiste y desplaza lejos (interrumpe).
	var cor: AbilityData = load("res://resources/abilities/minotauro_cornada.tres")
	_ver(cor.forma == CombatFormas.Tipo.LINEA and cor.carga and cor.carga_turnos == 1, "la Cornada es una linea cargada un turno")
	var f_c = t.forma_de(cor, e, pe + Vector2(200, 0))
	_colocar(t, al, [pe + Vector2(r0 + 60, 0), pe + Vector2(-200, 90)])
	await _esperar(2)
	var rep_c: Array = t._reparto_en(cor, e, f_c)
	_ver(_escala_de(rep_c, al[0]) > 0.0 and _escala_de(rep_c, al[1]) < 0.0, "le pilla al de la linea y no al de fuera (%s)" % _txt(rep_c))
	al[0].charging = cor
	al[0].charge_left = 1
	var txt: String = combat.desplazado(al[0], cor.tiron, e)
	_ver(absf(cor.tiron) >= combat.DESPLAZA_CORTA and txt != "" and al[0].charging == null, "el empujon de la Cornada (%.0f px) es grande: le corta la carga" % absf(cor.tiron))
	al[0].charging = null
	al[0].charge_left = 0
	# EL PISOTON: alrededor, a tramos, sin carga.
	var pis: AbilityData = load("res://resources/abilities/minotauro_pisoton.tres")
	_ver(pis.carga_turnos == 0, "el Pisoton sale sin cargar")
	var f_p = t.forma_de(pis, e, pe + Vector2(100, 0))
	_colocar(t, al, [pe + Vector2(r0 + 6, 0), pe + Vector2(-f_p.radio + 6, 0)])
	await _esperar(2)
	var rep_p: Array = t._reparto_en(pis, e, f_p)
	_ver(_escala_de(rep_p, al[0]) > _escala_de(rep_p, al[1]) and _escala_de(rep_p, al[1]) > 0.0, "el Pisoton pilla alrededor, mas a los de cerca (%s)" % _txt(rep_p))
	_colocar(t, al, [pe + Vector2(r0 + 6, 0), pe + Vector2(-f_p.radio - 50, 0)])
	await _esperar(2)
	_ver(_escala_de(t._reparto_en(pis, e, f_p), al[1]) < 0.0, "fuera del Pisoton, nada")
	# EL BRAMIDO: el circulo grande.
	var bra: AbilityData = load("res://resources/abilities/minotauro_bramido.tres")
	var f_b = t.forma_de(bra, e, pe + Vector2(100, 0))
	_colocar(t, al, [pe + Vector2(120, 0), pe + Vector2(-f_b.radio - 50, 0)])
	await _esperar(2)
	var rep_b: Array = t._reparto_en(bra, e, f_b)
	_ver(_escala_de(rep_b, al[0]) > 0.0 and _escala_de(rep_b, al[1]) < 0.0, "el Bramido llega a 120 px y no mas alla de su circulo (%s)" % _txt(rep_b))
	# LA RABIA.
	e.current_hp = e.max_hp * 0.5
	_ver(not e.en_rabia() and is_equal_approx(combat._mult_pasivas(e, al[0]), 1.0), "a media vida, sin rabia (x%.2f)" % combat._mult_pasivas(e, al[0]))
	e.current_hp = e.max_hp * 0.2
	_ver(e.en_rabia() and is_equal_approx(combat._mult_pasivas(e, al[0]), 1.3), "por debajo del 30%%, en rabia: pega x%.2f" % combat._mult_pasivas(e, al[0]))
	e.current_hp = e.max_hp


func _txt(rep: Array) -> String:
	var out: Array = []
	for d in rep:
		out.append("%s x%.2f" % [d["c"].nombre, float(d["escala"])])
	return "[%s]" % ", ".join(out)


func _colocar(t, al: Array, sitios: Array) -> void:
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else sitios[0] + Vector2(-260 - 40 * i, 90)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
