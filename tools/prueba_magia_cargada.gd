# PRUEBA (04/11, el jefe): EL CONJURO QUE ENTRA EN LA PELEA DESDE EL MAPA. Lo que hace quien lleva la pelea:
#   - cargado y con sitio: en su turno sale solo, sin boton, sin volver a cobrarlo, y le da a quien este en ESE sitio;
#   - cargado sin sitio: en su turno apunta, y sale al elegirlo;
#   - interrumpido a media frase: en su turno apunta y sigue recitando POR ESA FRASE;
#   - lo que llega del espejo: el primer sitio se acepta, y la nota de Game viaja y vuelve bien.
#   godot --headless --path . res://tools/prueba_magia_cargada.tscn
extends Node

const DESCARGA := "res://resources/spells/descarga.tres"
const RAYO := "res://resources/spells/rayo.tres"

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


# Prepara el turno de 'quien' con el conjuro sembrado como llega de la ficha.
func _sembrar(combat, quien: Combatant, d: Dictionary) -> void:
	await _esperar_a(func() -> bool: return not combat._fx.ocupado(), 6.0)
	combat.magia._limpiar_casteo()
	combat._casteos.erase(quien)
	combat._player = quien
	combat._state = combat.State.WAITING_PLAYER
	combat.aplicar_casteo_entrante(combat._aliados.find(quien), d)


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_magia_cargada", Game.PISO_ARENA):
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
	var sobre: Vector2 = t.bulto_de(a).get_center()
	var lejos: Vector2 = t.pies_de(quien) + Vector2(0.0, 160.0)

	# 1) CARGADO Y CON SITIO: sale solo y no se cobra otra vez.
	await _sembrar(combat, quien, {"ruta": DESCARGA, "frase": desc.longitud(), "pagado": true, "punto": [sobre.x, sobre.y]})
	var mp0: float = quien.current_mp
	var g0: int = _golpes_a(combat, quien, a)
	combat.magia._mostrar_disparo()
	_ver(_golpes_a(combat, quien, a) > g0, "con sitio sobre el enemigo: en su turno sale solo y le da")
	_ver(is_equal_approx(quien.current_mp, mp0), "y no se cobra otra vez (ya lo pago al recitarlo)")
	_ver(not combat._casteos.has(quien), "y el conjuro se gasta")

	# 2) CON SITIO DONDE YA NO HAY NADIE: se pierde ("si se han ido, te jodes").
	await _sembrar(combat, quien, {"ruta": DESCARGA, "frase": desc.longitud(), "pagado": true, "punto": [lejos.x, lejos.y]})
	g0 = _golpes_a(combat, quien, a)
	combat.magia._mostrar_disparo()
	_ver(_golpes_a(combat, quien, a) == g0, "con sitio donde no hay nadie: se pierde")
	_ver(not combat._casteos.has(quien), "y se gasta igual")

	# 3) CARGADO SIN SITIO: apunta en su turno y sale al elegir.
	await _sembrar(combat, quien, {"ruta": DESCARGA, "frase": desc.longitud(), "pagado": true})
	combat.magia._mostrar_disparo()
	_ver(t.esta_apuntando(), "sin sitio: en su turno apunta")
	_ver(combat._casteos.has(quien), "y aun no ha salido")
	g0 = _golpes_a(combat, quien, a)
	t.confirmar_sitio(sobre)
	_ver(not t.esta_apuntando() and _golpes_a(combat, quien, a) > g0, "al elegir el sitio sale y le da")

	# 4) INTERRUMPIDO EN LA FRASE 1 DE 2 (ya dicha la primera): apunta y sigue POR ESA FRASE.
	await _sembrar(combat, quien, {"ruta": RAYO, "frase": 1, "pagado": false})
	combat.magia._mostrar_test(combat._cast_index)
	_ver(t.esta_apuntando(), "interrumpido: en su turno apunta primero")
	_ver(not combat._cast_box.visible, "y aun sin frases delante")
	t.confirmar_sitio(sobre)
	await _esperar(1)
	_ver(combat._cast_box.visible and combat._cast_index == 1, "al elegir, sigue por su frase (la %d)" % (combat._cast_index + 1))
	_ver((combat._casteos[quien] as Dictionary).get("punto") == sobre, "con el sitio guardado para cuando lo suelte")
	combat._ocultar_cajas()

	# 5) LO QUE LLEGA DEL ESPEJO: el primer sitio se acepta tal cual; si ya tenia, el recorte de siempre.
	await _sembrar(combat, quien, {"ruta": DESCARGA, "frase": desc.longitud(), "pagado": true})
	combat.magia.aplicar_reapunte(lejos, null)
	_ver((combat._casteos[quien] as Dictionary).get("punto") == lejos, "el espejo elige el sitio que faltaba")
	combat.magia.aplicar_reapunte(lejos + Vector2(500, 0), null)
	_ver(((combat._casteos[quien] as Dictionary).get("punto") as Vector2).distance_to(lejos) <= 30.5, "uno que ya tiene sitio solo se mueve su margen")
	combat.magia._limpiar_casteo()
	combat._casteos.erase(quien)

	# 6) LA NOTA DE GAME: viaja con su sitio, una vez, y si no te dejan entrar vuelve SIN sitio y sigue cargada.
	var pj: PersonajeData = Game.lider()
	Game.cargar_conjuro(desc, pj)
	Game.sitio_de_conjuro(sobre)
	_ver(Game.conjuro_cargado() == desc and Game.conjuro_con_sitio(), "cargado y con sitio")
	var d: Dictionary = Game.casteo_para_viajar(pj)
	_ver(int(d.get("frase", -1)) == desc.longitud() and bool(d.get("pagado", false)) and (d.get("punto", []) as Array).size() == 2,
		"viaja entero, pagado y con su sitio")
	_ver(Game.conjuro_cargado() == null and Game.casteo_para_viajar(pj).is_empty(), "y sale una sola vez")
	# (la llamada de arriba vacia no borra lo que hay en vuelo)
	Game.devolver_casteo_en_vuelo()
	_ver(Game.conjuro_cargado() == desc and not Game.conjuro_con_sitio(), "denegada: sigue cargado y hay que elegir sitio otra vez")
	Game.olvidar_conjuro_cargado()
	_ver(Game.conjuro_cargado() == null, "deshecho")

	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
