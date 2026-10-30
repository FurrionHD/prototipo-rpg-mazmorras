# PRUEBA (30/10, el jefe): RECOLOCAR LA MAGIA AL LANZARLA y ELEGIR OTRO ALIADO si el suyo huye. En una pelea tactica:
#   - la Descarga (1 frase) arrastrada 100 px se queda a 30 px de donde se apunto; el Rayo (2 frases), a 60;
#   - el Venablo (2 frases) girado 90 grados se queda en 30 grados;
#   - lo que llega del espejo pasa por el mismo recorte (aplicar_reapunte): no se puede mover mas de la cuenta;
#   - recolocada sobre el enemigo, le da (donde se apunto, no);
#   - un Filo (a un aliado) cuyo aliado huye: al lanzarlo pide elegir a otro, y le cae a ese;
#   - para elegir aliado, el circulo engancha al mas cercano en toda la zona (no hace falta clavarlo).
#   godot --headless --path . res://tools/prueba_magia_recolocar.tscn
extends Node

const DESCARGA := "res://resources/spells/descarga.tres"
const RAYO := "res://resources/spells/rayo.tres"
const VENABLO := "res://resources/spells/venablo_de_tormenta.tres"
const FILO := "res://resources/spells/filo_ardiente.tres"

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
	if not await sala.arrancar("prueba_magia_recolocar", Game.PISO_ARENA):
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
	var centro: Vector2 = t._arena().rect.get_center()
	for k in range(1, combat._aliados.size()):
		_colocar(t, combat._aliados[k], centro + Vector2(-140 + 50 * k, 130))
	_colocar(t, quien, centro + Vector2(-110, 0))
	_colocar(t, a, centro)
	await _esperar(3)
	var desc: SpellData = load(DESCARGA)
	var rayo: SpellData = load(RAYO)
	var ven: SpellData = load(VENABLO)

	# EL MARGEN, con el modo de arrastrar (lo que hace el raton).
	var base := centro + Vector2(0, 120)
	for sp in [desc, rayo]:
		t.empezar_recolocar(sp, quien, base)
		t.arrastrar_recolocar(base + Vector2(100, 0))
		var d: float = (t.punto_recolocado() as Vector2).distance_to(base)
		_ver(absf(d - 30.0 * sp.longitud()) < 0.5, "%s (%d frase/s) arrastrada 100 px: se queda a %.1f px (tope %d)" % [
			sp.nombre, sp.longitud(), d, 30 * sp.longitud()])
		t.acabar_recolocar()
	var pies: Vector2 = t.pies_de(quien)
	var base_l: Vector2 = pies + Vector2(150, 0)
	t.empezar_recolocar(ven, quien, base_l)
	t.arrastrar_recolocar(pies + Vector2(0, 150))
	var giro: float = rad_to_deg(absf((base_l - pies).angle_to((t.punto_recolocado() as Vector2) - pies)))
	_ver(absf(giro - 15.0 * ven.longitud()) < 0.5, "%s (%d frases) girado 90 grados: se queda en %.1f (tope %d)" % [
		ven.nombre, ven.longitud(), giro, 15 * ven.longitud()])
	t.acabar_recolocar()

	# LO QUE LLEGA DEL ESPEJO pasa por el mismo recorte.
	combat._player = quien
	combat._casteos[quien] = {"spell": desc, "idx": 1, "punto": base}
	combat.magia.aplicar_reapunte(base + Vector2(0, -500), null)
	var llego: Vector2 = combat._casteos[quien]["punto"]
	_ver(llego.distance_to(base) <= 30.5, "un punto de la red 500 px mas alla se queda a %.1f px" % llego.distance_to(base))
	combat._casteos.erase(quien)

	# RECOLOCADA SOBRE EL ENEMIGO, le da. Apuntada a 50 px de su cuerpo (fuera del iman) y arrastrada 30 hacia el.
	var r: Rect2 = t.bulto_de(a)
	var fuera: Vector2 = r.get_center() + Vector2(0.0, r.size.y * 0.5 + 50.0)
	_ver(int((await _soltar(combat, quien, desc, fuera, [a]))[0]) == 0, "la Descarga a 50 px de su cuerpo no le da")
	await _esperar_a(func() -> bool: return not combat._fx.ocupado(), 6.0)
	combat._fx.cancelar()
	combat._player = quien
	combat._state = combat.State.WAITING_PLAYER
	combat._casteos[quien] = {"spell": desc, "idx": 1, "punto": fuera}
	t.empezar_recolocar(desc, quien, fuera)
	t.arrastrar_recolocar(fuera + Vector2(0, -30))
	var g0: int = _golpes_a(combat, quien, a)
	combat.magia._disparar_hechizo()
	_ver(_golpes_a(combat, quien, a) > g0, "arrastrada 30 px hacia el y lanzada, le da")
	_ver(not t.recolocando(), "al lanzarla se deja de recolocar")
	combat._casteos.erase(quien)

	# A UN ALIADO QUE HUYE: el Filo iba a 'b', 'b' huye; al lanzarlo se pide a otro y le cae al elegido.
	var filo: SpellData = load(FILO)
	var b: Combatant = combat._aliados[1]
	var otro: Combatant = combat._aliados[2]
	await _esperar_a(func() -> bool: return not combat._fx.ocupado(), 6.0)
	combat._player = quien
	combat._state = combat.State.WAITING_PLAYER
	combat._casteos[quien] = {"spell": filo, "idx": filo.longitud(), "punto": t.pies_de(b), "aliado": b}
	combat._huidos[b] = true
	_ver(combat.magia._aliado_huyo(), "el Filo iba a %s, que ha huido: lo sabe" % b.nombre)
	combat.magia._pintar_disparo(filo.nombre, true)
	_ver(t.esta_apuntando(), "al lanzarlo pide elegir a otro (apuntando)")
	# El raton cerca (no encima) de 'otro': el circulo le engancha.
	var ro: Rect2 = t.bulto_de(otro)
	t.apunte = ro.get_center() - Vector2(ro.size.x * 0.5 + 20.0, 0.0)   # por su lado libre (a su derecha esta Daniel)
	t._hay_apunte = true
	var bajo: Array = t.aliados_de_huella(t._apuntando, quien)
	_ver(not bajo.is_empty() and bajo[0] == otro, "el circulo a 20 px de %s le engancha (pilla %s; huella %s r%.0f)" % [otro.nombre, str(bajo.map(func(x): return x.nombre)), t._apuntando.forma, t._apuntando.forma_radio])
	var antes_imb: String = otro.imbue_etiqueta()
	combat.magia._disparar_hechizo(otro)
	_ver(otro.imbue_etiqueta() != "" and otro.imbue_etiqueta() != antes_imb,
		"el Filo le cae a %s (%s)" % [otro.nombre, otro.imbue_etiqueta()])
	_ver(b.imbue_etiqueta() == "", "y no al que huyo")
	combat._huidos.erase(b)
	t._reeligiendo = null
	t._dejar_de_apuntar()
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
