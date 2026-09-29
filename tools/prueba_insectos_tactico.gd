# LOS INSECTOIDES EN EL TACTICO (29/09): araña, escarabajo, ciempies y segadora. Sin ventana:
#   godot --headless --path . res://tools/prueba_insectos_tactico.tscn
# Alcances y formas, y las cuatro mecanicas nuevas: la Telaraña que se queda en el suelo, la Embestida rodante que
# atraviesa, la Doble guadaña partida en dos mitades, el Ensarte que persigue a su presa (nunca al de mas aggro) y
# el Enrosque que clava a los dos. Acaba con BIEN/MAL.
extends Node

const ENEMIGOS := ["arana", "escarabajo", "ciempies", "segadora"]
const ALCANCES := {"arana": 20.0, "escarabajo": 20.0, "ciempies": 25.0, "segadora": 35.0}
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
			jug.global_position + Vector2(-150 + 100 * i, 60), {})
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
	if al.size() < 3:
		print("MAL: hacen falta tres de los tuyos y hay %d" % al.size())
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
		var pe: Vector2 = t.pies_de(e)
		var hueco: float = t.radio_pisa(e) + t.alcance_de(e) * 0.7

		if clave == "arana":
			_colocar(t, al, [pe + Vector2(hueco + 60, -6), pe + Vector2(hueco + 62, 12), pe + Vector2(-190, 0)])
			await _esperar(2)
			var tela: AbilityData = load("res://resources/abilities/arana_telarana.tres")
			var plan: Dictionary = t.mejor_apunte(e, tela, al[0])
			_ver(int(plan["n"]) >= 1, "la Telaraña llega lejos (pilla a %d)" % int(plan["n"]))
			combat.enemigos._enemy_use_ability(e, tela, al[0])
			combat._fx.arrancar_cola()
			await _segundos(1.0)
			_ver(t._charcos.has(e), "la Telaraña se queda en el suelo")
			if t._charcos.has(e):
				var fc = t._charcos[e]["f"]
				al[2].quitar_estado(StatusEffects.Id.PEGAJOSO)
				t._colocar(al[2], t.cuerpo_de(al[2]), fc.centro - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
				await _esperar(2)
				t.charcos_empezar_turno(al[2])
				_ver(t._pisado.has(al[2]), "empezar el turno dentro de la red la pisa")
				for _k in 3:
					t.charcos_turno_enemigo(e)
				_ver(not t._charcos.has(e), "la red se va a los 3 turnos de la araña")

		if clave == "escarabajo":
			# En fila por delante: el primero, el de detras, y el tercero lejos.
			_colocar(t, al, [pe + Vector2(hueco, 0), pe + Vector2(hueco + 40, 0), pe + Vector2(-190, 0)])
			await _esperar(2)
			var rodar: AbilityData = load("res://resources/abilities/escarabajo_rodar.tres")
			var f = t.forma_de(rodar, e, t.pies_de(al[1]))
			var rep: Array = t._reparto_en(rodar, e, f)
			print("  rodar: %s" % _txt(rep))
			_ver(rep.size() == 2 and rep[0]["c"] == al[0] and is_equal_approx(float(rep[0]["escala"]), 1.0)
				and is_equal_approx(float(rep[1]["escala"]), rodar.area_secundario),
				"la Embestida rodante pilla a los dos en fila: el primero entero, el de detras a %.1f" % rodar.area_secundario)
			var antes: Vector2 = t.pos_de(e)
			combat.enemigos._enemy_use_ability(e, rodar, al[0])
			combat._fx.arrancar_cola()
			await _segundos(3.0)
			var andado: float = (t.pos_de(e) - antes).dot(f.dir)
			print("  el escarabajo rueda %.1f px" % andado)
			_ver(andado > (t.pies_de(al[1]) - pe).dot(f.dir), "rueda ATRAVESANDO hasta pasar al de detras")

		if clave == "ciempies":
			_colocar(t, al, [pe + Vector2(hueco, -4), pe + Vector2(hueco + 20, 4), pe + Vector2(-190, 0)])
			await _esperar(2)
			var oleada: AbilityData = load("res://resources/abilities/ciempies_oleada.tres")
			var rep_o: Array = t._reparto_en(oleada, e, t.forma_de(oleada, e, t.pies_de(al[0])))
			print("  oleada: %s" % _txt(rep_o))
			_ver(rep_o.size() >= 1 and not _tiene(rep_o, al[2]), "la Oleada pilla a los de delante y no al de lejos")
			await _probar_enrosque(combat, t, e, al)

		if clave == "segadora":
			await _probar_guadanas(combat, t, e, al)
			await _probar_ensarte(combat, t, e, al)

	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _colocar(t, al: Array, sitios: Array) -> void:
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else sitios[0] + Vector2(-260 - 40 * i, 90)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))


func _txt(rep: Array) -> String:
	var out: Array = []
	for d in rep:
		out.append("%s x%.2f" % [d["c"].nombre, float(d["escala"])])
	return "[%s]" % ", ".join(out)


func _tiene(rep: Array, c) -> bool:
	for d in rep:
		if d["c"] == c:
			return true
	return false


func _probar_enrosque(combat, t, e, al: Array) -> void:
	var enr: AbilityData = load("res://resources/abilities/ciempies_enrosque.tres")
	var presa = al[0]
	# Puede fallar (esquiva): se repite hasta que entre.
	for _k in 30:
		combat.enemigos._enemy_use_ability(e, enr, presa)
		combat._fx.arrancar_cola()
		await _segundos(0.3)
		if t.enrosque_de(e) != null:
			break
	_ver(t.enrosque_de(e) == presa, "el Enrosque entra y se queda enroscado en su presa")
	if t.enrosque_de(e) == null:
		return
	_ver(presa.enroscado() and e.enroscado(), "los dos llevan el Enroscado")
	_ver(t.radio_de(presa) == 0.0 and t.radio_de(e) == 0.0, "ni la presa ni el ciempies andan")
	var antes: Vector2 = t.pos_de(presa)
	t.pedir_desliz(presa, antes + Vector2(40, 0), 0, 1)
	await _esperar(20)
	_ver(t.pos_de(presa).distance_to(antes) < 1.0, "a la presa no la mueve nadie")
	var jugador_antes = combat._player
	combat._player = presa
	_ver(not combat._accion_disponible(combat.Action.ATTACK) and not combat._accion_disponible(combat.Action.HABILIDAD)
		and not combat._accion_disponible(combat.Action.MAGIC) and not combat._accion_disponible(combat.Action.OBJETO)
		and not combat._accion_disponible(combat.Action.DEFEND) and combat._accion_disponible(combat.Action.FLEE)
		and combat._huir_es_pasar(), "enroscado solo puede pasar")
	combat._player = jugador_antes
	# El apreton: daño de un basico cada turno suyo, sin soltarle.
	var hp0: float = presa.current_hp
	combat.enemigos._enemy_apretar(e, presa)
	await _esperar(2)
	_ver(presa.current_hp < hp0 and t.enrosque_de(e) == presa, "el apreton le quita vida y no le suelta")
	# Forcejear: tarde o temprano se suelta (30%).
	var intentos: int = 0
	while t.enrosque_de(e) != null and intentos < 60:
		t.forcejear(presa)
		intentos += 1
	_ver(t.enrosque_de(e) == null and not presa.enroscado() and not e.enroscado(),
		"forcejeando se suelta (a los %d intentos)" % intentos)
	# Los demas le sueltan pegandole el 35% de su vida.
	_ver(t.empezar_enrosque(e, presa), "se vuelve a enroscar")
	e.max_hp = maxf(e.max_hp, 100.0)
	e.current_hp = e.max_hp
	t._enroscados[e]["hp"] = e.current_hp
	e.current_hp -= e.max_hp * 0.34
	await _esperar(3)
	_ver(t.enrosque_de(e) == presa, "con el 34% de su vida no suelta")
	e.current_hp -= e.max_hp * 0.02
	await _esperar(3)
	_ver(t.enrosque_de(e) == null and not presa.enroscado(), "con el 35% de su vida suelta")
	# Y aturdiendole.
	e.current_hp = e.max_hp
	t.empezar_enrosque(e, presa)
	e.apply_status(StatusEffects.Id.ATURDIDO, 1)
	await _esperar(3)
	_ver(t.enrosque_de(e) == null and not presa.enroscado(), "aturdido suelta")
	e.quitar_estado(StatusEffects.Id.ATURDIDO)
	# Fuera de la pelea no se lleva el estado.
	t.empezar_enrosque(e, presa)
	var salen: Array = StatusEffects.estados_que_salen(presa.statuses)
	_ver(salen.filter(func(d): return int(d.get("id", -1)) == StatusEffects.Id.ENROSCADO).is_empty(),
		"el Enroscado no sale de la pelea")
	t.soltar_enrosque(e, "")


func _probar_guadanas(combat, t, e, al: Array) -> void:
	var gua: AbilityData = load("res://resources/abilities/segadora_guadanas.tres")
	var pe: Vector2 = t.pies_de(e)
	# El cono hacia ARRIBA: su izquierda es -x y su derecha +x. Uno a cada lado y el tercero en medio.
	var alto: float = t.radio_pisa(e) + 18.0
	_colocar(t, al, [pe + Vector2(-26, -alto), pe + Vector2(26, -alto), pe + Vector2(0, -alto - 4)])
	await _esperar(2)
	var f = t.forma_de(gua, e, pe + Vector2(0, -60))
	t.ultima_forma_enemigo = f
	var m: Array = []
	for k in 3:
		m.append(t.mitades_que_toca(al[k]))
		print("  %s (%s): mitades %s" % [al[k].nombre, str(t.bulto_de(al[k])), str(m[k])])
	_ver(m[0] == [0] and m[1] == [1] and m[2] == [0, 1],
		"la Doble guadaña: la izquierda al de la izquierda, la derecha al de la derecha, las dos al de en medio")


func _probar_ensarte(combat, t, e, al: Array) -> void:
	var ens: AbilityData = load("res://resources/abilities/segadora_ensarte.tres")
	var pe: Vector2 = t.pies_de(e)
	var hueco: float = t.radio_pisa(e) + 20.0
	_colocar(t, al, [pe + Vector2(hueco, -30), pe + Vector2(hueco + 10, 30), pe + Vector2(hueco + 30, 0)])
	await _esperar(2)
	# El de mas aggro es el primero: nunca le toca a el.
	var aggro_antes: Array = []
	for a in al:
		aggro_antes.append(a.aggro_base)
	al[0].aggro_base = 50.0
	var nunca_tanque: bool = true
	for _k in 12:
		t.guardar_carga_enemigo(e, ens, al[0])
		if t._presas_carga.get(e) == al[0] or t._presas_carga.get(e) == null:
			nunca_tanque = false
		t.olvidar_carga(e)
	_ver(nunca_tanque, "el Ensarte nunca marca al de mas aggro")
	combat.enemigos._enemy_begin_charge(e, ens, al[0])
	var presa = t._presas_carga.get(e)
	_ver(presa != null and presa != al[0] and e.charging == ens, "empieza a cargar y marca a una presa")
	if presa == null:
		return
	_ver(t._huellas_red.has(t._cod(e) * t.CLASES_HUELLA + t.CLASE_CARGA), "la marca viaja como huella de carga")
	# La presa se mueve: la marca la sigue, y al soltar sale hacia donde esta ahora.
	var nuevo: Vector2 = pe + Vector2(-hueco - 40, 20)
	var otro = al[1] if presa != al[1] else al[2]
	t._colocar(otro, t.cuerpo_de(otro), pe + Vector2(0, 160) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	t._colocar(presa, t.cuerpo_de(presa), nuevo - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(3)
	_ver((t._cargas[e][1] as Vector2).distance_to(t.pies_de(presa)) < 1.0, "la marca sigue a la presa")
	e.charging = null
	combat.enemigos._enemy_use_ability(e, ens)
	combat._fx.arrancar_cola()
	var f = t.ultima_forma_enemigo
	_ver(f != null and f.dir.dot((t.bulto_de(presa).get_center() - f.origen).normalized()) > 0.95,
		"al soltar, la linea sale hacia donde esta la presa ahora")
	await _segundos(3.0)
	# Meter a otro en medio: se lo come el.
	pe = t.pies_de(e)
	var medio = al[1] if presa != al[1] else al[2]
	var hacia: Vector2 = t.pies_de(presa)
	var dir: Vector2 = (hacia - pe).normalized()
	t._colocar(medio, t.cuerpo_de(medio), pe + dir * (t.radio_pisa(e) + 14.0) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	await _esperar(2)
	var rep: Array = t._reparto_en(ens, e, t.forma_de(ens, e, t.bulto_de(presa).get_center()))
	print("  ensarte con uno en medio: %s" % _txt(rep))
	_ver(rep.size() == 1 and rep[0]["c"] == medio, "con otro en medio, se lo come el de en medio")
	for i in al.size():
		al[i].aggro_base = aggro_antes[i]
