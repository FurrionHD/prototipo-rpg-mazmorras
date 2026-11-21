# PRUEBA (21/11, el jefe: "las magias van mas despacio... ¿siguen haciendo daño en el momento que deben, no antes o
# despues?"): LAS MAGIAS MAS DESPACIO (MagiaAire/MagiaMayor.LENTO) SIGUEN PEGANDO CON SU DIBUJO. En una pelea tactica en
# la sala, cada magia frenada se lanza por el camino de verdad contra un slime y, en cada golpe que cae
# (CombatFX.impacto_visto), se mira el RELOJ DE SU DIBUJO:
#   - el primero cae cuando el dibujo llega al bicho (su retraso sin estirar, en tiempo del dibujo);
#   - los de despues (los tirones de la Voragine, el agua del Shock, la luz del Eclipse) van separados en el dibujo lo
#     mismo que antes de frenarlas (lo que separa la pelea sus golpes, 'paso', partido por nada: se estira con el dibujo).
#   godot --headless --path . res://tools/prueba_magias_lentas.tscn
extends Node

const MAGIAS := ["chorro_agua", "bola_fuego", "voragine_sombra", "shock_termico", "tormenta", "eclipse", "estallido_solar"]
const TOL := 0.05   # segundos del dibujo

var sala
var _mal := 0


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


func _colocar(t, c: Combatant, pies: Vector2) -> void:
	t._colocar(c, t.cuerpo_de(c), pies - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))


func _lento(tipo: int) -> float:
	if tipo >= SueloRoto.Tipo.MAGIA_SOL:
		return MagiaMayor.lento(tipo - SueloRoto.Tipo.MAGIA_SOL)
	if tipo >= SueloRoto.Tipo.MAGIA_ALIENTO:
		return MagiaAire.lento(tipo - SueloRoto.Tipo.MAGIA_ALIENTO)
	return 1.0


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_magias_lentas", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(-200, 60), {})
	await _esperar(25)
	var combat: Node = await sala.pelear(get_tree().get_nodes_in_group("enemy"), false)
	if combat == null or not combat.tactico:
		print("MAL: no se abre la pelea tactica")
		get_tree().quit(1)
		return
	var t = combat.turno_mapa
	if not await _esperar_a(func() -> bool: return t._fase == t.Fase.MOVIENDO, 20.0):
		print("MAL: no llego un turno de los tuyos")
		get_tree().quit(1)
		return
	var quien: Combatant = combat._aliados[0]
	var a: Combatant = combat._enemies[0]
	for c in combat._aliados + combat._enemies:
		c.max_hp = 999999.0
		c.current_hp = 999999.0
		c.max_mp = 99999.0
		c.current_mp = 99999.0
		c.evasion_penal = 1.0   # que no esquive nadie (se miran los golpes que caen)
	var ar = t._arena()
	var centro: Vector2 = ar.rect.get_center()
	for k in range(1, combat._aliados.size()):
		_colocar(t, combat._aliados[k], centro + Vector2(-120 + 40 * k, 140))
	_colocar(t, quien, centro + Vector2(-90, 0))
	_colocar(t, a, centro)
	await _esperar(3)
	# EL RELOJ DEL DIBUJO EN CADA GOLPE
	var golpes: Array = []   # _t del dibujo en cada golpe que cae sobre 'a'
	var dibujo: Array = [null]
	var b_a = combat._bloque_de(a)
	combat._fx.impacto_visto.connect(func(ev):
		if is_same(ev["bv"], b_a) and dibujo[0] != null and is_instance_valid(dibujo[0]):
			golpes.append(float(dibujo[0].get("_t"))))
	for nom in MAGIAS:
		var sp: SpellData = load("res://resources/spells/%s.tres" % nom)
		var tipo: int = int(sp.suelo_mapa)
		var clase: String = "MagiaMayor" if tipo >= SueloRoto.Tipo.MAGIA_SOL else "MagiaAire"
		await _esperar_a(func() -> bool: return not combat._fx.ocupado(), 8.0)
		combat._fx.cancelar()
		_colocar(t, a, centro)   # (el empuje de la anterior)
		await _esperar(2)
		var antes: Array = CapaPixel.efectos_de(ar, clase)
		golpes.clear()
		dibujo[0] = null
		combat._player = quien
		combat._state = combat.State.WAITING_PLAYER
		var punto: Vector2 = t.pies_de(a) if int(sp.forma_apunte) == CombatFormas.Apunte.LIBRE else t.pies_de(a)
		combat._casteos[quien] = {"spell": sp, "idx": sp.longitud(), "punto": punto}
		# donde estaba al lanzar (el Torrente le empuja: despues ya no esta ahi)
		var bulto0: Rect2 = t.bulto_de(a)
		combat.magia._resolver_hechizo(sp, a)
		combat._casteos.erase(quien)
		if not combat._fx.ocupado():
			combat._fx.arrancar_cola()
		# su dibujo: el que acaba de salir (el suelo se lanza al arrancar la cola)
		await _esperar_a(func() -> bool:
			for e in CapaPixel.efectos_de(ar, clase):
				if not antes.has(e) and e.get("modo") == tipo - (SueloRoto.Tipo.MAGIA_SOL if clase == "MagiaMayor" else SueloRoto.Tipo.MAGIA_ALIENTO):
					dibujo[0] = e
					return true
			return false, 3.0)
		await _esperar_a(func() -> bool: return not combat._fx.ocupado(), 8.0)
		var lento: float = _lento(tipo)
		if dibujo[0] == null or golpes.is_empty():
			_ver(false, "%s: sin dibujo o sin golpes (%d golpes)" % [sp.nombre, golpes.size()])
			continue
		var e: Node2D = dibujo[0]
		var f = e.get("forma")
		var esperado: float = SueloRoto.retraso_caja(f, bulto0, tipo) / lento
		_ver(absf(float(golpes[0]) - esperado) <= TOL,
			"%s (x%.1f): el primer golpe cae con su dibujo (reloj del dibujo %.3f, su llegada %.3f)" % [sp.nombre, lento,
				float(golpes[0]), esperado])
		if golpes.size() > 1:
			# los de despues: la misma separacion en el dibujo que antes de frenarla (la de la pelea, sin estirar)
			var paso_orig: float = (float(golpes[1]) - float(golpes[0]))
			var t_enc: float = CombatFX.T_ENCADENADO_MAGIA
			var mal: Array = []
			for k in range(1, golpes.size()):
				var gap: float = float(golpes[k]) - float(golpes[k - 1])
				if absf(gap - paso_orig) > TOL:
					mal.append(snappedf(gap, 0.001))
			_ver(mal.is_empty() and absf(paso_orig - t_enc) <= TOL * 2.0,
				"%s: sus %d golpes, cada uno con su parte del dibujo (separados %.3f en el dibujo, como la pelea sin frenar: %.3f)%s" % [
					sp.nombre, golpes.size(), paso_orig, t_enc, "" if mal.is_empty() else " DESIGUALES %s" % str(mal)])
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
