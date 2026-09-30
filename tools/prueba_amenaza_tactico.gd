# LA AMENAZA POR ENEMIGO EN EL TACTICO (30/09, plan stateless-sniffing-bentley). Sin ventana:
#   godot --headless --path . res://tools/prueba_amenaza_tactico.tscn
# La tabla de amenaza de cada enemigo (daño, curas, Provocacion, enfriado) y a quien se acerca: el de mas peso entre
# los que le llegan ESTE turno, salvo que le provoquen o le saquen mucha amenaza. Acaba con BIEN/MAL.
extends Node

const ENEMIGOS := ["jabali", "rata", "rey_rata", "arana", "segadora", "chillon", "slime_fuego"]
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
			jug.global_position + Vector2(-300 + 110 * i, 60 + 70 * (i % 2)), {})
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
		a.aggro_base = 1.0          # sin escudo: numeros limpios
		a.amenaza_gen = 1.0
		a.quitar_estado(StatusEffects.Id.SIGILO)
	var e: Combatant = combat._enemies[0]
	print("--- amenaza (paso A) ---")
	await _probar_tabla(combat, t, e, al)
	await _probar_presa(combat, t, e, al)
	print("--- pasivas (paso B) ---")
	await _probar_pasivas(combat, t, al)
	print("--- desplazamientos (paso C) ---")
	_probar_desplazar(combat, t, al)
	print("--- ir a interrumpir (paso D) ---")
	_probar_interrumpir(combat, t, al)
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


func _probar_tabla(combat, t, e: Combatant, al: Array) -> void:
	for x in combat._enemies:
		x.amenaza = {}
	combat._apuntar_dano(e, 10.0, al[0])
	_ver(is_equal_approx(float(e.amenaza.get(al[0], 0.0)), 10.0), "pegarle 10 da 10 de amenaza con el (%.1f)" % float(e.amenaza.get(al[0], 0.0)))
	_ver(combat._enemies[1].amenaza.get(al[0], 0.0) == 0.0, "y con el otro enemigo, nada")
	var grande: ShieldData = load("res://resources/shields/escudo_grande.tres")
	al[0].amenaza_gen = grande.amenaza_mult
	combat._apuntar_dano(e, 10.0, al[0])
	_ver(is_equal_approx(float(e.amenaza[al[0]]), 50.0), "con escudo grande genera x4 (%.1f)" % float(e.amenaza[al[0]]))
	al[0].amenaza_gen = 1.0
	var peq: ShieldData = load("res://resources/shields/escudo_pequeno.tres")
	var med: ShieldData = load("res://resources/shields/escudo_normal.tres")
	_ver(is_equal_approx(peq.amenaza_mult, 2.5) and is_equal_approx(med.amenaza_mult, 3.25) and is_equal_approx(grande.amenaza_mult, 4.0),
		"pequeño x2,5, mediano x3,25, grande x4")
	combat.objetivos.amenaza_por_cura(al[1], 20.0)
	var n_e: int = combat._vivos().size()
	_ver(is_equal_approx(float(e.amenaza.get(al[1], 0.0)), 10.0 / float(n_e)), "curar 20 reparte la mitad entre los %d enemigos (%.2f)" % [n_e, float(e.amenaza.get(al[1], 0.0))])
	combat.objetivos.provocar_amenaza(al[1], [e])
	_ver(e.primero_en_amenaza() == al[1], "la Provocacion le pone el primero de su tabla")
	var v: float = float(e.amenaza[al[1]])
	e.enfriar_amenaza()
	_ver(is_equal_approx(float(e.amenaza[al[1]]), v * 0.8), "y al empezar su turno se enfria un 20%")
	var w0: float = combat.objetivos._peso_aggro(al[0], e)
	var w1: float = combat.objetivos._peso_aggro(al[1], e)
	_ver(w1 > w0, "pesa mas el de mas amenaza (%.2f contra %.2f)" % [w1, w0])


func _probar_presa(combat, t, e: Combatant, al: Array) -> void:
	var pe: Vector2 = t.pies_de(e)
	var lejos: float = t.radio_de(e) + t.alcance_de(e) + t.radio_pisa(e) + 90.0
	_colocar(t, al, [pe + Vector2(lejos, 0), pe + Vector2(0, t.radio_pisa(e) + 30)])
	await _esperar(2)
	for a in al:
		a.provocar_turnos = 0
	e.amenaza = {al[0]: 12.0, al[1]: 10.0}
	_ver(t._presa_de(e) == al[1], "con poca diferencia va al que le llega este turno, no al lejano")
	e.amenaza = {al[0]: 200.0, al[1]: 1.0}
	_ver(t._presa_de(e) == al[0], "si el lejano le saca muchisima amenaza, va a por el")
	e.amenaza = {al[0]: 12.0, al[1]: 10.0}
	al[0].provocar_turnos = 2
	al[0].provocados = [e]
	_ver(t._presa_de(e) == al[0], "y si le provoca, tambien")
	al[0].provocar_turnos = 0
	al[0].provocados = []


func _de(combat, t, clave: String) -> Combatant:
	for x in combat._enemies:
		var ed = t.cuerpo_de(x).get("data") if t.cuerpo_de(x) != null else null
		if ed != null and String(ed.resource_path).get_file().get_basename() == clave:
			return x
	return null


func _al_lado(t, x: Combatant) -> Vector2:
	return t.pies_de(x) + Vector2(t.radio_pisa(x) + 10.0, 0.0)


func _probar_pasivas(combat, t, al: Array) -> void:
	for x in combat._enemies:
		x.amenaza = {}
	# REY DE LA CAMADA
	var rey: Combatant = _de(combat, t, "rey_rata")
	var rata: Combatant = _de(combat, t, "rata")
	_ver(rey != null and rata != null, "hay rey rata y rata")
	if rey != null and rata != null:
		_ver(is_equal_approx(combat._mult_pasivas(rata, al[0]), 1.05), "con el rey vivo la rata pega un 5%% mas (%.2f)" % combat._mult_pasivas(rata, al[0]))
		_ver(is_equal_approx(combat._mult_pasivas(rey, al[0]), 1.0), "el rey no se da el empujon a si mismo")
		_colocar(t, al, [t.pies_de(rata) + Vector2(20, 0), t.pies_de(rata) + Vector2(-300, 100)])
		await _esperar(2)
		var txt: String = ""
		for _k in 20:
			combat._camada_hecha = false
			txt = combat._camada_salta(rey, al[0])
			if txt.find("falla") < 0:
				break
		_ver(txt != "", "cuando el rey pega, la rata de al lado salta detras (%s)" % txt)
		_ver(_hay_efecto(combat, CombatFX.Estilo.PASIVA_LLAMADA), "y se ve la llamada del rey")
		await _esperar(2)
		var spr_r = t.cuerpo_de(rata).get("_sprite") if t.cuerpo_de(rata) != null else null
		var mat_r = spr_r.material if spr_r is CanvasItem else null
		_ver(mat_r is ShaderMaterial and float(mat_r.get_shader_parameter("encendido")) == 1.0,
			"con el rey vivo a la rata le brillan los ojos")
		combat._camada_hecha = false
		_ver(combat._camada_salta(rey, al[1]) == "", "y a una victima lejos de las ratas no salta ninguna")
		_ver(combat._camada_salta(rey, al[0]) == "", "una sola vez por accion")
	# EMBOSCADA
	var ara: Combatant = _de(combat, t, "arana")
	if ara != null:
		al[0].apply_status(StatusEffects.Id.PEGAJOSO, 2)
		_ver(is_equal_approx(combat._mult_pasivas(ara, al[0]), 1.5), "la araña pega un 50%% mas al pegajoso (%.2f)" % combat._mult_pasivas(ara, al[0]))
		_ver(combat.objetivos._peso_aggro(al[0], ara) > combat.objetivos._peso_aggro(al[1], ara), "y va a por el")
		var ev_m := {"estilo": CombatFX.Estilo.INSECTO_QUELICEROS, "ba": combat._bloque_de(ara), "bv": combat._bloque_de(al[0]),
			"evadido": false}
		_ver(t.marca_numero(ev_m) == " ✱", "y su numero lleva la marca de la Emboscada")
		ev_m["bv"] = combat._bloque_de(al[1])
		_ver(t.marca_numero(ev_m) == "", "y al que no esta en la tela, no")
		al[0].quitar_estado(StatusEffects.Id.PEGAJOSO)
	# FILO DE REFLEJO
	var seg: Combatant = _de(combat, t, "segadora")
	if seg != null:
		var p0: float = seg.reflejo_prob
		seg.reflejo_prob = 1.0
		_colocar(t, al, [_al_lado(t, seg), t.pies_de(seg) + Vector2(-300, 100)])
		await _esperar(2)
		var tocado: bool = false
		for _k in 20:
			var hp0: float = al[0].current_hp
			combat._reflejo(seg, al[0])
			if al[0].current_hp < hp0:
				tocado = true
				break
		_ver(tocado, "la segadora devuelve el golpe al que le pega de cerca")
		_ver(_hay_efecto(combat, CombatFX.Estilo.PASIVA_DESTELLO), "con el destello en su guadaña")
		var hp1: float = al[1].current_hp
		combat._reflejo(seg, al[1])
		_ver(is_equal_approx(al[1].current_hp, hp1), "y al que le pega de lejos no")
		seg.reflejo_prob = p0
		seg.amenaza = {al[0]: 100.0, al[1]: 10.0}
		var con: float = combat.objetivos._peso_aggro(al[0], seg)
		seg.evita_tanque = false
		var sin: float = combat.objetivos._peso_aggro(al[0], seg)
		seg.evita_tanque = true
		_ver(con < sin, "y evita al primero de su tabla (%.2f contra %.2f)" % [con, sin])
		seg.amenaza = {}
	# ECOLOCALIZACION
	var chi: Combatant = _de(combat, t, "chillon")
	var jab: Combatant = _de(combat, t, "jabali")
	if chi != null and jab != null:
		al[0].apply_status(StatusEffects.Id.SIGILO, 2)
		var w_chi: float = combat.objetivos._peso_aggro(al[0], chi)
		var w_jab: float = combat.objetivos._peso_aggro(al[0], jab)
		_ver(w_chi > w_jab, "el chillon va a por el sigiloso (%.2f) y el jabali no (%.2f)" % [w_chi, w_jab])
		al[0].quitar_estado(StatusEffects.Id.SIGILO)
		chi.apply_status(StatusEffects.Id.CEGUERA, 2)
		_ver(not chi.has_status(StatusEffects.Id.CEGUERA), "al chillon no se le puede cegar")
		combat.aviso_inmune(chi, al[0])
		_ver(_hay_efecto(combat, CombatFX.Estilo.AVISO_INMUNE), "y sale el INMUNE")
	# CUERPO ARDIENTE
	var sf: Combatant = _de(combat, t, "slime_fuego")
	if sf != null:
		var pr: float = sf.al_ser_golpeado_prob
		sf.al_ser_golpeado_prob = 1.0
		_colocar(t, al, [_al_lado(t, sf), t.pies_de(sf) + Vector2(-300, 100)])
		await _esperar(2)
		for _k in 20:
			combat._pasiva_al_golpearle(sf, al[0])
			if al[0].has_status(StatusEffects.Id.QUEMADURA):
				break
		_ver(al[0].has_status(StatusEffects.Id.QUEMADURA), "pegarle de cerca al slime de fuego te puede quemar")
		_ver(_hay_efecto(combat, CombatFX.Estilo.PASIVA_ARDE), "con su lengua de fuego")
		sf.al_ser_golpeado_prob = pr


func _probar_desplazar(combat, t, al: Array) -> void:
	var e: Combatant = _de(combat, t, "jabali")
	var car: AbilityData = load("res://resources/abilities/jabali_embestida.tres")
	e.charging = car
	e.charge_left = 2
	var txt: String = combat.desplazado(e, 30.0, al[0])
	_ver(e.charging == null and txt != "", "un empujon grande le corta la carga al enemigo (%s)" % txt)
	_ver(_hay_efecto(combat, CombatFX.Estilo.AVISO_INTERRUMPIDO), "y se ve el INTERRUMPIDO")
	var sp: SpellData = load("res://resources/spells/bola_fuego.tres")
	combat._casteos[al[1]] = {"spell": sp, "idx": 1}
	txt = combat.desplazado(al[1], 30.0, e)
	_ver(not combat._casteos.has(al[1]) and txt != "", "y uno grande le corta el conjuro a uno de los tuyos (%s)" % txt)
	combat._casteos[al[1]] = {"spell": sp, "idx": 1}
	var g0: float = float(combat._gauge.get(al[1], 0.0))
	txt = combat.desplazado(al[1], 12.0, e)
	var g1: float = float(combat._gauge.get(al[1], 0.0))
	_ver(combat._casteos.has(al[1]) and txt == "", "uno pequeño no le corta el conjuro")
	_ver(g1 < g0 - 1.0, "pero le retrasa en la barra (%.1f -> %.1f)" % [g0, g1])
	_ver(_hay_efecto(combat, CombatFX.Estilo.AVISO_RETRASO, 0.75), "y se ve el RETRASADO (con cuanto y hacia donde en el peso)")
	combat._casteos.erase(al[1])


func _probar_interrumpir(combat, t, al: Array) -> void:
	var e: Combatant = _de(combat, t, "jabali")
	e.amenaza = {}
	e.ability_cooldowns.clear()
	for a in al:
		a.provocar_turnos = 0
		a.provocados = []
	_ver(combat.objetivos.puede_interrumpir(e), "el jabali tiene con que interrumpir (su Embestida aturde)")
	var sp: SpellData = load("res://resources/spells/bola_fuego.tres")
	var sin: float = combat.objetivos._peso_aggro(al[1], e)
	combat._casteos[al[1]] = {"spell": sp, "idx": 1}
	var con: float = combat.objetivos._peso_aggro(al[1], e)
	_ver(con > sin * 2.5, "el que recita pesa el triple para el (%.2f contra %.2f)" % [con, sin])
	var hab: AbilityData = combat.objetivos.habilidad_para_interrumpir(e, al[1])
	_ver(hab != null, "y elige la habilidad que se lo corta (%s)" % (hab.nombre if hab != null else "ninguna"))
	al[0].provocar_turnos = 2
	al[0].provocados = [e]
	var prov: float = combat.objetivos._peso_aggro(al[1], e)
	_ver(is_equal_approx(prov, sin), "PERO si le provoca otro, no va a cortarle nada (%.2f)" % prov)
	_ver(combat.objetivos.habilidad_para_interrumpir(e, al[1]) == null, "ni usa la habilidad para eso")
	al[0].provocar_turnos = 0
	al[0].provocados = []
	combat._casteos.erase(al[1])


# Hay en la cola de efectos uno de 'estilo' (y con ese peso, si se da).
func _hay_efecto(combat, estilo: int, peso: float = -1.0) -> bool:
	if combat._fx == null:
		return false
	for ev in combat._fx._cola:
		if int(ev.get("estilo", -1)) == estilo and (peso < 0.0 or is_equal_approx(float(ev.get("peso", -1.0)), peso)):
			return true
	return false


func _colocar(t, al: Array, sitios: Array) -> void:
	for i in al.size():
		var s: Vector2 = sitios[i] if i < sitios.size() else sitios[0] + Vector2(-260 - 40 * i, 90)
		t._colocar(al[i], t.cuerpo_de(al[i]), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
