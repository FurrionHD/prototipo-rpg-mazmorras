# EL ENEMIGO QUE SE APARTA DE TU AREA tiene que ACABAR FUERA (10/10, playtest del 09/10: "los enemigos cuando se
# reposicionan aun asi se quedan dentro de la hitbox de los ataques"; en el registro, 3 de las 6 veces que el Minotauro
# "se coloca fuera de tu area", el Tajo / el Golpe sismico / el Segar le entraron igual). Sin ventana:
# el Minotauro rodeado de los tuyos, uno con una carga apuntada encima de el; en su turno se aparta y se mira DONDE ACABA.
# Varias tandas con los tuyos en sitios distintos.
#   godot --headless --path . res://tools/prueba_apartarse_fuera.tscn
extends Node

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
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/guardian_rango.tres", jug.global_position + Vector2(-220, 70), {})
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
	var t = combat.turno_mapa
	var al: Array = combat._aliados
	var e: Combatant = combat._enemies[0]
	e.max_hp = 99999.0
	e.current_hp = 99999.0
	for a in al:
		a.max_hp = 99999.0
		a.current_hp = 99999.0
	var cu_e: Node2D = t.cuerpo_de(e)
	e.prob_apartarse = 1.0   # aqui se mira DONDE acaba; la probabilidad (33 %) se mira al final
	var bajo_e: Vector2 = t._bajo_de(e)
	var habs: Array = ["tajo_devastador", "golpe_sismico", "segar"]
	# El Minotauro en un hueco libre de la arena (lejos de las paredes).
	var centro: Vector2 = t._arena().rect.get_center()
	var dentro_total: int = 0
	var tandas: int = 0
	for tanda in 9:
		if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
			print("MAL: no llego un turno de los tuyos")
			break
		e.charging = null
		e.retrasando = false
		t.olvidar_carga(e)
		t._colocar(e, cu_e, centro - bajo_e)
		await _esperar(2)
		var pe: Vector2 = t.pies_de(e)
		# Los tuyos pegados a el, en abanico (cambia con la tanda); el primero con la carga apuntada a el.
		var giro: float = TAU * float(tanda) / 9.0
		# (pegados los cuatro en abanico no hay sitio al que llegar: entonces pega desde donde esta, que es lo pedido)
		for i in al.size():
			var d: Vector2 = Vector2.from_angle(giro + 1.4 * float(i))
			var b: float = t._hasta_el_borde(pe, d, t.bulto_de(e))
			t._colocar(al[i], t.cuerpo_de(al[i]), pe + d * (b + (10.0 if i == 0 else 60.0)) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
		await _esperar(2)
		var c: Combatant = al[0]
		var ab: AbilityData = load("res://resources/abilities/%s.tres" % habs[tanda % habs.size()])
		t.apunte = t.bulto_de(e).get_center()
		t._hay_apunte = true
		c.charging = ab
		c.charge_left = 1
		c.retrasando = true
		combat._gauge[c] = combat.UMBRAL * 0.6   # que le toque antes de que el Minotauro vuelva a actuar (sin que salte mientras anda)
		t.guardar_carga(c, ab)
		var f = t.forma_de(ab, c, t.apunte)
		var antes_dentro: bool = f.toca(t.bulto_de(e))
		# (diagnostico: por que se descartan los sitios)
		var razones: Dictionary = {"pared/otro": 0, "en el area": 0, "no llega andando": 0, "no llega": 0, "vale": 0}
		var desde0: Vector2 = cu_e.global_position
		var off0: Vector2 = t.pies_de(e) - desde0
		var peligro0: Array = t.formas_peligro(e)
		var presa0: Combatant = t._presa_de(e)
		var quien0 = t._quien
		t._quien = e   # (como lo mira el: su turno)
		for anillo in [0.35, 0.65, 1.0]:
			for k in 16:
				var q: Vector2 = t._acotar(desde0 + Vector2.RIGHT.rotated(TAU * float(k) / 16.0) * t.radio_de(e) * anillo, desde0, t.radio_de(e), t._dentro(t._arena()))
				if not t._sobre_suelo(q, cu_e):
					razones["suelo"] = int(razones.get("suelo", 0)) + 1
				elif not t._en_arena(q):
					razones["arena"] = int(razones.get("arena", 0)) + 1
				elif not t._puede_estar(q, cu_e):
					razones["pared/otro"] += 1
				elif t._en_peligro(e, q + off0, peligro0):
					razones["en el area"] += 1
				elif t._ruta_hasta(desde0, q, cu_e, t.radio_de(e), t._dentro(t._arena()), INF).is_empty():
					razones["no llega andando"] += 1
				elif presa0 != null and t._hueco_desde(e, q + off0, presa0) > t.alcance_de(e) * t.ARRIMARSE:
					razones["no llega"] += 1
				else:
					razones["vale"] += 1
		t._quien = quien0
		print("     sitios: %s (peligros %d, radio %.0f, alcance %.0f)" % [str(razones), peligro0.size(), t.radio_de(e), t.alcance_de(e)])
		# Su turno: se aparta (o no) y pega.
		t.turno_enemigo(e)
		var se_aparta: bool = t._destino != null
		var destino = t._destino
		var ruta_dec: Array = t._ruta.duplicate()
		var primer_paso: bool = true
		if se_aparta:
			var m0: Vector2 = ruta_dec[0] if not ruta_dec.is_empty() else destino
			var q0: Vector2 = cu_e.global_position + (m0 - cu_e.global_position).normalized() * 2.5
			primer_paso = t._puede_estar(q0, cu_e)
		var off_antes: Vector2 = t.pies_de(e) - cu_e.global_position
		var caja_antes: Vector2 = t.bulto_de(e).size
		var t_ini: int = Time.get_ticks_msec()
		# DONDE ACABA DE APARTARSE (al llegar, ANTES de pegar: su golpe puede moverle, la Cornada le lleva por su linea).
		var llegada: Dictionary = {}
		var dest_ult = t._destino
		var ruta_ini: int = t._ruta.size()
		var vars_ult: Array = []
		while t._fase == t.Fase.ACERCANDO and Time.get_ticks_msec() - t_ini < 6000:
			if t._destino != null:
				dest_ult = t._destino
				vars_ult = [t._t_acercar, t._t_atasco, t._ruta.size(), t.pos_de(e)]
				llegada["caja"] = t.bulto_de(e)   # la ultima mientras va: donde llega, antes de que su golpe le mueva
			if se_aparta and t._destino == null and not llegada.has("dentro"):
				llegada["dentro"] = f.toca(t.bulto_de(e))
				if llegada["dentro"]:
					print("     (PARA DENTRO: le faltaban %.0f px a su sitio; t %.2f, atasco %.2f, puntos de paso %d de %d)" % [
						(vars_ult[3] as Vector2).distance_to(dest_ult) if not vars_ult.is_empty() else -1.0,
						vars_ult[0] if not vars_ult.is_empty() else -1.0, vars_ult[1] if not vars_ult.is_empty() else -1.0,
						vars_ult[2] if not vars_ult.is_empty() else -1, ruta_ini])
			await get_tree().process_frame
		# (si llega y pega en el mismo fotograma, el bucle sale sin verlo: su cuerpo aun no se ha movido por su golpe)
		if se_aparta and not llegada.has("dentro"):
			llegada["dentro"] = f.toca(llegada.get("caja", t.bulto_de(e)))
		if se_aparta and bool(llegada.get("dentro", false)):
			print("     (ruta al decidir %s; primer paso posible %s; quien %s)" % [str(ruta_dec), str(primer_paso), t._quien.nombre if t._quien != null else "-"])
			print("     (al salir: fase %d, destino %s, quien %s, estado %d, frames %d, t %.2f)" % [int(t._fase), str(t._destino),
				t._quien.nombre if t._quien != null else "-", int(combat._state), Engine.get_process_frames(), t._t_acercar])
			print("     (LLEGA DENTRO: iba a %s, esta en %s; pies-nodo %s -> %s; caja %s -> %s; forma %s)" % [str(destino),
				str(cu_e.global_position.round()), str(off_antes.round()), str((t.pies_de(e) - cu_e.global_position).round()),
				str(caja_antes), str(t.bulto_de(e).size), str(f)])
		if se_aparta:
			print("     (iba a %s desde %s; tardo %d ms; atasco %.2f, t %.2f)" % [str(destino), str(t.pos_de(e)),
				Time.get_ticks_msec() - t_ini, t._t_atasco, t._t_acercar])
		var acaba_dentro: bool = bool(llegada.get("dentro", f.toca(t.bulto_de(e))))
		print("     tanda %d (%s): dentro al empezar %s, se aparta %s, acaba %s (andado %.0f px)" % [tanda, ab.nombre,
			str(antes_dentro), str(se_aparta), "DENTRO" if acaba_dentro else "fuera", t.pies_de(e).distance_to(pe)])
		if se_aparta:
			tandas += 1
			if acaba_dentro:
				dentro_total += 1
		c.charging = null
		c.retrasando = false
		t.olvidar_carga(c)
		await _esperar(60)
	_ver(tandas > 0, "se ha apartado alguna vez (%d)" % tandas)
	# NO SIEMPRE (10/10, el jefe: "el 33 % de las veces o asi, si no nunca vamos a golpear a los enemigos"): con la de su
	# ficha, en el sitio de la tanda 0 (donde si tiene a donde ir), 90 turnos.
	e.prob_apartarse = load("res://scenes/actors/enemy/guardian_rango.tres").prob_apartarse
	await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0)
	var veces: int = 0
	for _k in 90:
		e.charging = null   # (que no este cargando lo suyo: cargando no anda)
		e.retrasando = false
		t.olvidar_carga(e)
		t._colocar(e, cu_e, centro - bajo_e)
		var pe2: Vector2 = t.pies_de(e)
		for i in al.size():
			var d2: Vector2 = Vector2.from_angle(1.4 * float(i))
			var b2: float = t._hasta_el_borde(pe2, d2, t.bulto_de(e))
			t._colocar(al[i], t.cuerpo_de(al[i]), pe2 + d2 * (b2 + (10.0 if i == 0 else 60.0)) - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
		var c2: Combatant = al[0]
		var ab2: AbilityData = load("res://resources/abilities/tajo_devastador.tres")
		t.apunte = t.bulto_de(e).get_center()
		t._hay_apunte = true
		c2.charging = ab2
		c2.retrasando = true
		combat._gauge[c2] = combat.UMBRAL * 0.97
		t.guardar_carga(c2, ab2)
		t.turno_enemigo(e)
		if t._destino != null:
			veces += 1
		t._terminar()
		t._destino = null
		t._ruta.clear()
		c2.charging = null
		c2.retrasando = false
		t.olvidar_carga(c2)
	print("     con su %.0f %%: se aparta %d de 90" % [e.prob_apartarse * 100.0, veces])
	_ver(veces >= 15 and veces <= 45, "se aparta mas o menos 1 de cada 3 veces (%d de 90)" % veces)
	_ver(dentro_total == 0, "siempre que se aparta, ACABA FUERA (%d de %d dentro)" % [dentro_total, tandas])
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
