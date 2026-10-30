# PRUEBA (30/10, el jefe: "la Andanada tiene que dar siempre a los enemigos dentro del area; caen random y hay veces
# que ninguno de los golpes da a nadie"): LAS BOLAS DE LA ANDANADA, A LOS DE DENTRO. En una pelea tactica en la sala:
#   - con un enemigo dentro del circulo (no en el centro), lanzada desde 12 sitios: le dan TODAS las bolas cada vez;
#   - con nadie dentro, no le da (cae donde se apunto);
#   - los puntos de las bolas viajan al espejo: empaquetados y leidos salen iguales (MARCA_PUNTOS).
#   godot --headless --path . res://tools/prueba_andanada_dentro.tscn
extends Node

const ANDANADA := "res://resources/spells/bola_fuego.tres"

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


# Golpes DE VERDAD (no adornos) de 'de' contra 'a' en la cola de efectos.
func _golpes_a(combat, de: Combatant, a: Combatant) -> int:
	var ba = combat._bloque_de(de)
	var bv = combat._bloque_de(a)
	var n := 0
	for ev in combat._fx._cola:
		if is_same(ev["ba"], ba) and is_same(ev["bv"], bv) and not bool(ev.get("solo_dibujo", false)):
			n += 1
	return n


func _colocar(t, c: Combatant, pies: Vector2) -> void:
	t._colocar(c, t.cuerpo_de(c), pies - Vector2(0.0, PoseJugador.PIES_BAJO_NODO))


# Suelta 'sp' de 'quien' hacia 'punto' (ya recitada) y devuelve los golpes a cada uno de 'otros'.
func _soltar(combat, quien: Combatant, sp: SpellData, punto: Vector2, otros: Array) -> Array:
	await _esperar_a(func() -> bool: return not combat._fx.ocupado(), 6.0)
	combat._fx.cancelar()   # la cola limpia: se cuentan solo los golpes de este tiro
	var antes: Array = otros.map(func(o): return _golpes_a(combat, quien, o))
	combat._player = quien
	combat._casteos[quien] = {"spell": sp, "idx": sp.longitud(), "punto": punto}
	combat.magia._resolver_hechizo(sp, otros[0])
	combat._casteos.erase(quien)
	var out: Array = []
	for k in otros.size():
		out.append(_golpes_a(combat, quien, otros[k]) - int(antes[k]))
	return out


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_andanada_dentro", Game.PISO_ARENA):
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
	var ar = t._arena()
	var centro: Vector2 = ar.rect.get_center()
	for k in range(1, combat._aliados.size()):
		_colocar(t, combat._aliados[k], centro + Vector2(-120 + 40 * k, 120))
	_colocar(t, quien, centro + Vector2(-110, 0))
	_colocar(t, a, centro)
	await _esperar(3)
	var sp: SpellData = load(ANDANADA)
	var r: Rect2 = t.bulto_de(a)
	var n: int = sp.golpes()
	# Doce sitios alrededor del enemigo, con el centro del circulo a 70% del radio de el (dentro, pero no en el centro).
	var todas := 0
	var alguna_falla := 0
	for k in 12:
		var ang: float = TAU * float(k) / 12.0
		var punto: Vector2 = r.get_center() + Vector2(cos(ang), sin(ang)) * sp.forma_radio * 0.7
		var g: int = int((await _soltar(combat, quien, sp, punto, [a]))[0])
		if g >= n:
			todas += 1
		if g == 0:
			alguna_falla += 1
	_ver(todas == 12, "con el enemigo dentro, desde 12 sitios: le dan las %d bolas %d de 12 veces (ninguna: %d)" % [n, todas, alguna_falla])
	var lejos: Vector2 = r.get_center() + Vector2(0.0, sp.forma_radio + r.size.y + 30.0)
	_ver(int((await _soltar(combat, quien, sp, lejos, [a]))[0]) == 0, "con nadie dentro no le da")
	# LA RED: los puntos, empaquetados y leidos como en el espejo.
	var f := CombatFormas.circulo(Vector2(100.5, 200.25), 50.0)
	f.puntos = [Vector2(90.0, 210.0), Vector2(111.25, 190.5), Vector2(100.0, 200.0), Vector2(95.5, 199.0)]
	var paquete: PackedInt32Array = combat.espejo._bloques_suelo(43, f, 12345, 0.0)
	await _esperar_a(func() -> bool: return not combat._fx.ocupado(), 6.0)
	combat._fx.cancelar()
	var ya: Array = ar.find_children("*", "MagiaAire", true, false)
	combat._espejo = true
	combat.espejo._aplicar_impactos_ya(paquete)
	combat._espejo = false
	await _esperar(2)
	var leidos = null
	for m in ar.find_children("*", "MagiaAire", true, false):
		if not ya.has(m):
			leidos = m._puntos
	_ver(leidos != null and leidos == f.puntos, "los puntos de las bolas llegan iguales al espejo (%s)" % str(leidos))
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
