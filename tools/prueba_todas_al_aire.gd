# PRUEBA (29/10, el jefe): TODAS LAS HABILIDADES SE VEN AUNQUE NO LE DEN A NADIE. "Las de desplazamiento, tanto de enemigos
# como de personajes, se haran, y las otras al menos se vera el ataque dandole al aire." En una pelea tactica en su sala,
# con todos LEJOS, cada habilidad con forma en el mapa:
#   - SE VE: sale un golpe de quien la lanza en la cola de efectos (al aire, efectos.golpe_al_aire) o su efecto por el suelo;
#   - las de MOVERSE (salto, carga, embestida, paso, avance, Oportunista) mueven a quien la lanza;
#   - no le da a nadie (si le da igual por su alcance, se apunta aparte: no es lo que se mira aqui).
# Recorre las de los ENEMIGOS (las que llevan sus fichas), las de tus ARMAS (armas, escudos, varitas) y las MAGIAS de ataque.
# Las de apoyo a los tuyos (forma_a_aliados) no se lanzan al aire a proposito.
#   godot --headless --path . res://tools/prueba_todas_al_aire.tscn
extends Node

var sala
var _mal := 0
var _no_se_ven: Array = []
var _no_se_mueven: Array = []
var _alcanzan: Array = []
var _probadas := 0
var _saltadas := 0


func _ready() -> void:
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


# Las rutas de habilidad que aparecen en los .tres de una carpeta.
func _rutas_en(carpetas: Array) -> Array:
	var out: Dictionary = {}
	var re := RegEx.new()
	re.compile("res://resources/abilities/[a-z_0-9]+\\.tres")
	for carpeta in carpetas:
		var d := DirAccess.open(carpeta)
		if d == null:
			continue
		for f in d.get_files():
			if not f.ends_with(".tres"):
				continue
			var txt: String = FileAccess.get_file_as_string(carpeta.path_join(f))
			for m in re.search_all(txt):
				out[m.get_string()] = true
	var l: Array = out.keys()
	l.sort()
	return l


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_todas_al_aire", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(-220, 70), {})
	await _esperar(25)
	if not (await sala.pelear(get_tree().get_nodes_in_group("enemy"), false) != null):
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var combat: Node = null
	await _esperar(5)
	for n in get_tree().root.get_children() + sala.capas():
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
	var e: Combatant = combat._enemies[0]
	for c in al + [e]:
		c.max_hp = 999999.0
		c.current_hp = 999999.0
		c.max_mp = 99999.0
		c.current_mp = 99999.0
		c.current_energy = 99999.0

	print("--- de los ENEMIGOS")
	for ruta in _rutas_en(["res://scenes/actors/enemy"]):
		await _una(combat, t, e, al, load(ruta), true)
	print("--- de los ENEMIGOS que NO PEGAN (30/10, playtest: el Brote 'no llegaba a nadie' y no sacaba crias)")
	await _no_pegan(combat, t, e, al)
	print("--- de tus ARMAS")
	for ruta in _rutas_en(["res://resources/weapons", "res://resources/shields", "res://resources/wands"]):
		await _una(combat, t, al[0], [e], load(ruta), false)
	print("--- MAGIAS de ataque")
	var d := DirAccess.open("res://resources/spells")
	for f in d.get_files():
		if f.ends_with(".tres"):
			var sp = load("res://resources/spells/" + f)
			if sp is SpellData and (sp as SpellData).tipo == SpellData.TipoEfecto.ATAQUE:
				await _magia(combat, t, al[0], [e], sp)

	print("probadas %d, saltadas %d (sin forma en el mapa, o de apoyo a los tuyos)" % [_probadas, _saltadas])
	if not _alcanzan.is_empty():
		print("llegan igual por su alcance (no cuentan): %s" % ", ".join(_alcanzan))
	_ver(_no_se_ven.is_empty(), "todas se ven aunque no le den a nadie%s" % (
		"" if _no_se_ven.is_empty() else ": NO SE VEN " + ", ".join(_no_se_ven)))
	_ver(_no_se_mueven.is_empty(), "las de moverse se mueven%s" % (
		"" if _no_se_mueven.is_empty() else ": NO SE MUEVEN " + ", ".join(_no_se_mueven)))
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)


# Pone a 'quien' en el centro y a 'otros' lejos, al otro lado.
func _separar(t, quien: Combatant, otros: Array) -> void:
	var ar = t._arena()
	var centro: Vector2 = ar.rect.get_center() if ar != null else t.pies_de(quien)
	var lejos := Vector2.LEFT if t._en_arena(centro + Vector2(-300, 0)) else Vector2.RIGHT
	t._colocar(quien, t.cuerpo_de(quien), centro - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))
	for i in otros.size():
		var o: Combatant = otros[i]
		var s: Vector2 = centro + lejos * (300 + 25 * (i % 2)) + Vector2(0, -60 + 40 * i)
		t._colocar(o, t.cuerpo_de(o), s - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))


func _golpes_de(combat, c: Combatant) -> int:
	if combat._fx == null:
		return 0
	var b = combat._bloque_de(c)
	var n := 0
	for ev in combat._fx._cola:
		if is_same(ev["ba"], b):
			n += 1
	return n


# Golpes DE VERDAD (no al aire) de 'de' contra alguno de 'a': si los hay, la habilidad le ha llegado a alguien. Por la cola
# y no por la vida: un estado de antes (un veneno, una quemadura) le baja la vida en la espera y engañaba (29/10).
func _golpes_a(combat, de: Combatant, a: Array) -> int:
	if combat._fx == null:
		return 0
	var ba = combat._bloque_de(de)
	var bvs: Array = a.map(func(o): return combat._bloque_de(o))
	var n := 0
	for ev in combat._fx._cola:
		if is_same(ev["ba"], ba) and not bool(ev.get("solo_dibujo", false)) and bvs.any(func(b): return is_same(b, ev["bv"])):
			n += 1
	return n


func _mueve(ab: AbilityData, enemigo: bool) -> bool:
	if enemigo:
		return ab.salta or ((ab.carga or ab.recorre) and int(ab.forma) == CombatFormas.Tipo.LINEA)
	return ab.salto_espalda or ab.paso or ab.avance or ab.carga


func _una(combat, t, quien: Combatant, otros: Array, ab: AbilityData, enemigo: bool) -> void:
	if ab == null:
		return
	if not t.usa_huella(ab) or ab.forma_a_aliados or ab.constelacion or ab.mirada:
		_saltadas += 1
		return
	await _esperar_a(func() -> bool: return t._deslices.is_empty() and t._saltos.is_empty(), 6.0)
	_separar(t, quien, otros)
	await _esperar(3)
	var a0: int = _golpes_a(combat, quien, otros)
	var suelos: Array = []
	var oye := func(tipo: int, _espera: float): suelos.append(tipo)
	combat._fx.suelo_lanzado.connect(oye)
	var g0: int = _golpes_de(combat, quien)
	var desde: Vector2 = t.pies_de(quien)
	var n_d: int = t._deslices.size()
	var n_s: int = t._saltos.size()
	quien.ability_cooldowns.erase(ab)
	if enemigo:
		combat.enemigos._enemy_use_ability(quien, ab, otros[0])
	else:
		# Apuntada hacia el lado contrario de los otros, cerca: no pilla a nadie.
		var lejos: Vector2 = (t.pies_de(quien) - t.pies_de(otros[0])).normalized()
		combat._player = quien
		combat._state = combat.State.WAITING_PLAYER
		t.anotar_apunte([t.pies_de(quien).x + lejos.x * 40.0, t.pies_de(quien).y + lejos.y * 40.0])
		combat.habilidades._usar_habilidad(ab, true)   # 'soltando': sin cobrar ni cargar, sale ya
	var golpes: int = _golpes_de(combat, quien) - g0
	var tocado: bool = _golpes_a(combat, quien, otros) > a0
	var se_mueve_pedido: bool = t._deslices.size() > n_d or t._saltos.size() > n_s
	await _esperar_a(func() -> bool: return t._deslices.is_empty() and t._saltos.is_empty(), 3.0)
	await get_tree().create_timer(0.6).timeout
	combat._fx.suelo_lanzado.disconnect(oye)
	_probadas += 1
	var nombre: String = "%s (%s)" % [ab.nombre, ab.resource_path.get_file().get_basename()]
	if tocado:
		_alcanzan.append(nombre)
		return
	if golpes <= 0 and suelos.is_empty():
		_no_se_ven.append(nombre)
	if _mueve(ab, enemigo) and not se_mueve_pedido and t.pies_de(quien).distance_to(desde) < 4.0:
		_no_se_mueven.append(nombre)


# Con todos LEJOS: la invocacion saca sus crias igual, y lo que se echa encima (la Furia del Bramido) se lo queda aunque su
# parte contra los tuyos no pille a nadie. Las de solo echarse algo encima (Muralla...) ya iban; se miran tambien.
func _no_pegan(combat, t, e: Combatant, al: Array) -> void:
	var casos := {
		"res://resources/abilities/rey_slime_invocacion.tres": "crias",
		"res://resources/abilities/minotauro_bramido.tres": "propio",
		"res://resources/abilities/coloso_muralla.tres": "propio",
		"res://resources/abilities/slime_afilarse.tres": "propio",
	}
	for ruta in casos:
		var ab: AbilityData = load(ruta)
		await _esperar_a(func() -> bool: return t._deslices.is_empty() and t._saltos.is_empty(), 6.0)
		_separar(t, e, al)
		await _esperar(3)
		e.statuses.clear()
		e.ability_cooldowns.erase(ab)
		var vivos0: int = combat._vivos().size()
		# Sin alcance de verdad: el guardian es a distancia y llegaria a todos (el Rey, cuerpo a cuerpo, no).
		# Y que el sorteo de a quien pega mire SU alcance, como en su turno (turno_mapa.atacante).
		var alcance0: float = e.alcance
		var atacante0 = t.atacante
		e.alcance = 0.0
		t.atacante = e
		combat.enemigos._enemy_use_ability(e, ab, null)
		e.alcance = alcance0
		t.atacante = atacante0
		await get_tree().create_timer(0.6).timeout
		if casos[ruta] == "crias":
			_ver(combat._vivos().size() > vivos0, "%s con todos lejos saca crias (%d -> %d enemigos)" % [ab.nombre, vivos0,
				combat._vivos().size()])
		else:
			var propio: int = -1
			for a in ab.efectos:
				if not a.en_objetivo:
					propio = a.estado
			_ver(propio >= 0 and e.has_status(propio), "%s con todos lejos se echa encima lo suyo" % ab.nombre)


func _magia(combat, t, quien: Combatant, otros: Array, sp: SpellData) -> void:
	await _esperar_a(func() -> bool: return t._deslices.is_empty() and t._saltos.is_empty(), 6.0)
	_separar(t, quien, otros)
	await _esperar(3)
	var lejos: Vector2 = (t.pies_de(quien) - t.pies_de(otros[0])).normalized()
	var punto: Vector2 = t.pies_de(quien) + lejos * 60.0
	if not t.usa_huella_hechizo(sp):
		_saltadas += 1
		return
	var a0: int = _golpes_a(combat, quien, otros)
	var suelos: Array = []
	var oye := func(tipo: int, _espera: float): suelos.append(tipo)
	combat._fx.suelo_lanzado.connect(oye)
	var g0: int = _golpes_de(combat, quien)
	combat._player = quien
	combat._casteos[quien] = {"spell": sp, "idx": 0, "punto": punto}
	combat.magia._resolver_hechizo(sp, otros[0])
	var golpes: int = _golpes_de(combat, quien) - g0
	var tocado: bool = _golpes_a(combat, quien, otros) > a0
	await get_tree().create_timer(0.8).timeout
	combat._fx.suelo_lanzado.disconnect(oye)
	combat._casteos.erase(quien)
	_probadas += 1
	if tocado:
		_alcanzan.append(sp.nombre)
		return
	if golpes <= 0 and suelos.is_empty():
		_no_se_ven.append("%s (magia)" % sp.nombre)
