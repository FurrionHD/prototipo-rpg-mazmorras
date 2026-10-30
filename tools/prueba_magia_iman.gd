# PRUEBA (30/10, el jefe: "la Descarga es infumable de acertar, es un punto diminuto"): EL IMAN DE LAS MAGIAS
# (SpellData.forma_iman). En una pelea tactica en la sala, con el enemigo a ~100 px:
#   - Descarga y Rayo apuntadas a 20 px de su cuerpo (fuera del puntito, dentro del circulo de enganche): le dan;
#   - Venablo y los Pulsos apuntados para pasar a 10 px de su cuerpo (fuera de la linea fina, dentro de la franja): le dan;
#   - apuntadas LEJOS (70 px), no le dan (el iman no es un "siempre da");
#   - con DOS dentro del circulo de la Descarga, le cae al mas cercano al centro.
#   godot --headless --path . res://tools/prueba_magia_iman.tscn
extends Node

const PUNTOS := ["res://resources/spells/descarga.tres", "res://resources/spells/rayo.tres"]
const LINEAS := ["res://resources/spells/venablo_de_tormenta.tres", "res://resources/spells/pulso_menor.tres",
	"res://resources/spells/pulso_arcano.tres"]

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
	if not await sala.arrancar("prueba_magia_iman", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(-200, 60), {})
	sala.poner("res://scenes/actors/enemy/slime.tres", Vector2(-260, 60), {})
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
	var b: Combatant = combat._enemies[1]
	for c in combat._aliados + combat._enemies:
		c.max_hp = 999999.0
		c.current_hp = 999999.0
		c.max_mp = 99999.0
		c.current_mp = 99999.0
	var ar = t._arena()
	var centro: Vector2 = ar.rect.get_center()
	# Los demas de los tuyos, lejos (que la cadena o un rebote no los confunda).
	for k in range(1, combat._aliados.size()):
		_colocar(t, combat._aliados[k], centro + Vector2(-120 + 40 * k, 120))
	_colocar(t, quien, centro + Vector2(-100, 0))
	_colocar(t, a, centro)
	_colocar(t, b, centro + Vector2(0, -400))   # fuera de juego hasta el caso de los dos
	await _esperar(3)
	var r: Rect2 = t.bulto_de(a)
	print("  (el cuerpo del enemigo: %s)" % r)

	for ruta in PUNTOS:
		var sp: SpellData = load(ruta)
		var cerca: Vector2 = r.get_center() + Vector2(0.0, r.size.y * 0.5 + 20.0)
		var lejos: Vector2 = r.get_center() + Vector2(0.0, r.size.y * 0.5 + 70.0)
		_ver(int((await _soltar(combat, quien, sp, cerca, [a]))[0]) > 0, "%s a 20 px de su cuerpo: le da" % sp.nombre)
		_ver(int((await _soltar(combat, quien, sp, lejos, [a]))[0]) == 0, "%s a 70 px de su cuerpo: no le da" % sp.nombre)
	for ruta in LINEAS:
		var sp: SpellData = load(ruta)
		# Hacia un punto al lado del enemigo: la linea pasa a 10 px de su cuerpo (o a 70).
		var cerca: Vector2 = r.get_center() + Vector2(0.0, r.size.y * 0.5 + 10.0)
		var lejos: Vector2 = r.get_center() + Vector2(0.0, r.size.y * 0.5 + 70.0)
		_ver(int((await _soltar(combat, quien, sp, cerca, [a]))[0]) > 0, "%s pasando a 10 px de su cuerpo: le da" % sp.nombre)
		_ver(int((await _soltar(combat, quien, sp, lejos, [a]))[0]) == 0, "%s pasando a 70 px: no le da" % sp.nombre)

	# DOS DENTRO: 'b' pegado a 'a', y el punto mas cerca de 'b'.
	_colocar(t, b, centro + Vector2(0, 34))
	await _esperar(3)
	var rb: Rect2 = t.bulto_de(b)
	var punto: Vector2 = rb.get_center() + Vector2(0.0, rb.size.y * 0.5 + 12.0)
	var g: Array = await _soltar(combat, quien, load(PUNTOS[0]), punto, [b, a])
	_ver(int(g[0]) > 0, "Descarga con dos dentro: le cae al mas cercano al centro (golpes %s)" % str(g))
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
