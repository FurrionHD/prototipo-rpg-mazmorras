# LOS CONSTRUCTOS EN EL TACTICO (30/09, paso 1): golem de arcilla, gargola y coloso. Sin ventana:
#   godot --headless --path . res://tools/prueba_constructos_tactico.tscn
# Alcances, la Machaca (circulo delante, a todos), el Barro blando (el agua le quita lo endurecido y le deja blando),
# el Picado y la Mirada de la gargola y su Posada (es piedra si no se ha movido), el Pisoton del coloso a tramos y su
# Imparable (no se le mueve ni se le corta la carga). Acaba con BIEN/MAL.
extends Node

const ENEMIGOS := ["golem_arcilla", "gargola", "coloso"]
const ALCANCES := {"golem_arcilla": 22.0, "gargola": 20.0, "coloso": 35.0}
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
		if clave == "golem_arcilla":
			await _probar_golem(combat, t, e, al)
		if clave == "gargola":
			await _probar_gargola(combat, t, e, al)
		if clave == "coloso":
			await _probar_coloso(combat, t, e, al)
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


func _probar_golem(combat, t, e, al: Array) -> void:
	var pe: Vector2 = t.pies_de(e)
	var mac: AbilityData = load("res://resources/abilities/golem_machaca.tres")
	_ver(mac.carga_turnos == 1, "la Machaca se carga un turno (huella roja)")
	var f = t.forma_de(mac, e, pe + Vector2(200, 0))
	_colocar(t, al, [f.centro + Vector2(-6, 0), f.centro + Vector2(10, 12)])
	await _esperar(2)
	var rep: Array = t._reparto_en(mac, e, f)
	_ver(_escala_de(rep, al[0]) == 1.0 and _escala_de(rep, al[1]) == 1.0, "la Machaca pega entera a los dos de dentro (%s)" % _txt(rep))
	_colocar(t, al, [f.centro + Vector2(-6, 0), f.centro + Vector2(0, 90)])
	await _esperar(2)
	_ver(_escala_de(t._reparto_en(mac, e, f), al[1]) < 0.0, "y al que se sale, nada")
	# Barro blando.
	e.ablandado = 0
	e.apply_status(StatusEffects.Id.FORTALEZA, 3)
	_ver(is_equal_approx(e.mult_pasiva_recibido(), 1.0), "seco recibe normal")
	e.quitar_estado(StatusEffects.Id.FORTALEZA)
	_golpe_de(al[0], e, Elementos.Elemento.FUEGO)
	_ver(e.ablandado == 0 and e.cocido == 2 and e.has_status(StatusEffects.Id.FORTALEZA), "el fuego lo cuece: se endurece solo")
	_ver(is_equal_approx(e.mult_pasiva_recibido(), 0.7), "cocido recibe x0,7 (%.2f)" % e.mult_pasiva_recibido())
	_golpe_de(al[0], e, Elementos.Elemento.AGUA)
	_ver(e.ablandado == 2 and not e.has_status(StatusEffects.Id.FORTALEZA), "el agua le quita lo endurecido y le deja blando 2 turnos")
	_ver(is_equal_approx(e.mult_pasiva_recibido(), 1.3) and e.cocido == 0, "blando recibe x1,3 (%.2f)" % e.mult_pasiva_recibido())
	e.ablandado = 0


func _probar_gargola(combat, t, e, al: Array) -> void:
	var pe: Vector2 = t.pies_de(e)
	var pic: AbilityData = load("res://resources/abilities/gargola_picado.tres")
	_colocar(t, al, [pe + Vector2(105, 10), pe + Vector2(-260, 80)])
	await _esperar(2)
	var plan: Dictionary = t.mejor_apunte(e, pic, al[0])
	_ver(int(plan["n"]) >= 1 and pic.salta and pic.carga_turnos == 1, "el Picado llega a 105 px, cargado y se queda alli")
	var mir: AbilityData = load("res://resources/abilities/gargola_mirada.tres")
	var r0: float = t.radio_pisa(e)
	_colocar(t, al, [pe + Vector2(r0 + 50, 0), pe + Vector2(-r0 - 50, 0)])
	await _esperar(2)
	var rep_m: Array = t._reparto_en(mir, e, t.forma_de(mir, e, t.pies_de(al[0])))
	_ver(rep_m.size() == 1 and rep_m[0]["c"] == al[0], "la Mirada solo a los de su cono (%s)" % _txt(rep_m))
	# Posada.
	t.marcar_inicio_turno(e)
	await _esperar(2)
	_ver(e.posada and is_equal_approx(e.mult_pasiva_recibido(), 0.5), "posada recibe la mitad (%.2f)" % e.mult_pasiva_recibido())
	var nodo: Node2D = t.cuerpo_de(e)
	var antes: Vector2 = nodo.global_position
	t._colocar(e, nodo, antes + Vector2(30, 0))
	await _esperar(2)
	_ver(not e.posada and is_equal_approx(e.mult_pasiva_recibido(), 1.0), "si se mueve deja de ser piedra (%.2f)" % e.mult_pasiva_recibido())
	t.marcar_inicio_turno(e)
	await _esperar(2)
	_ver(e.posada, "y en su siguiente turno, si no se mueve, lo vuelve a ser")
	# En el aire mientras carga el Picado.
	_colocar(t, al, [t.pies_de(e) + Vector2(t.radio_pisa(e) + 8, 0), t.pies_de(e) + Vector2(-260, 80)])
	await _esperar(2)
	_ver(t.llega(al[0], e), "en el suelo, el de al lado le llega")
	e.charging = pic
	e.charge_left = 1
	_ver(not t.llega(al[0], e), "cargando el Picado esta en el aire: el cuerpo a cuerpo no le llega")
	var r: Dictionary = {"damage": 10.0, "evaded": false}
	combat._aplicar_pasivas(r, al[0], e)
	_ver(bool(r.evaded), "y un golpe de arma le falla")
	var sp: Dictionary = StatsMath.resolve_spell(al[0], e, load("res://resources/spells/bola_fuego.tres"))
	_ver(float(sp.get("damage", 0.0)) > 0.0, "la magia si le entra")
	e.charging = null
	e.charge_left = 0


func _probar_coloso(combat, t, e, al: Array) -> void:
	var pe: Vector2 = t.pies_de(e)
	var r0: float = t.radio_pisa(e)
	var pis: AbilityData = load("res://resources/abilities/coloso_pisoton.tres")
	_ver(pis.carga_turnos == 1, "el Pisoton se carga un turno")
	var f = t.forma_de(pis, e, pe + Vector2(100, 0))
	_colocar(t, al, [pe + Vector2(r0 + 6, 0), pe + Vector2(-f.radio + 6, 0)])
	await _esperar(2)
	var rep: Array = t._reparto_en(pis, e, f)
	var cerca: float = _escala_de(rep, al[0])
	var lejos: float = _escala_de(rep, al[1])
	_ver(cerca > 0.0 and lejos > 0.0 and cerca > lejos, "el Pisoton pilla a todos alrededor, mas a los de cerca (%s)" % _txt(rep))
	_colocar(t, al, [pe + Vector2(r0 + 6, 0), pe + Vector2(-f.radio - 60, 0)])
	await _esperar(2)
	_ver(_escala_de(t._reparto_en(pis, e, f), al[1]) < 0.0, "fuera de la huella, nada")
	# Imparable.
	e.charging = pis
	e.charge_left = 1
	var txt: String = combat.desplazado(e, 40.0, al[0])
	_ver(txt == "" and e.charging == pis, "un empujon grande no le corta la carga")
	e.charging = null
	e.charge_left = 0
	var n0: int = t._tirones.size()
	t.pedir_tiron(e, al[0], 60.0)
	_ver(t._tirones.size() == n0, "y los tirones no le mueven")


func _txt(rep: Array) -> String:
	var out: Array = []
	for d in rep:
		out.append("%s x%.2f" % [d["c"].nombre, float(d["escala"])])
	return "[%s]" % ", ".join(out)


func _colocar(t, al: Array, sitios: Array) -> void:
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else sitios[0] + Vector2(-260 - 40 * i, 90)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
