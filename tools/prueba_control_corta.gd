# PRUEBA (30/10, playtest del 29/10): EL CONTROL CORTA LA CARGA AL INSTANTE. "En el instante en el que metes un cc deberia
# dejar de castear las habilidades y ataques de los enemigos, no cuando le llega el turno; incluso el miedo interrumpe los
# casteos aunque se limpie en su turno." En una pelea tactica en la sala:
#   - un enemigo CARGANDO (Carga de bestia) recibe Aturdido / Miedo -> la pierde en el momento, sin esperar a su turno;
#   - uno de los tuyos CARGANDO, y otro CONJURANDO, igual (ramas espejo);
#   - un estado que no es de control (Lento) NO le corta nada.
#   godot --headless --path . res://tools/prueba_control_corta.tscn
extends Node

const CARGA := "res://resources/abilities/bestia_carga.tres"
const HECHIZO := "res://resources/spells/bola_fuego.tres"

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


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	if not await sala.arrancar("prueba_control_corta", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	sala.poner("res://scenes/actors/enemy/guardian_rango.tres", Vector2(-220, 70), {})
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
	var e: Combatant = combat._enemies[0]
	var al: Array = combat._aliados
	for c in al + [e]:
		c.max_hp = 999999.0
		c.current_hp = 999999.0
		c.status_resist = 0.0
	var carga: AbilityData = load(CARGA)
	var sp: SpellData = load(HECHIZO)

	for id in [StatusEffects.Id.ATURDIDO, StatusEffects.Id.MIEDO, StatusEffects.Id.LENTO]:
		var nom: String = String(StatusEffects.def(id).get("nombre", "?"))
		var corta: bool = StatusEffects.es_control(id)
		for c in al + [e]:
			c.statuses.clear()
		# El enemigo cargando y uno de los tuyos cargando; otro de los tuyos conjurando.
		e.charging = carga
		e.charge_left = 2
		al[0].charging = carga
		al[0].charge_left = 2
		var conjura: Combatant = al[1] if al.size() > 1 else al[0]
		combat._casteos[conjura] = {"spell": sp, "idx": 0}
		e.apply_status(id, 3)
		al[0].apply_status(id, 3)
		conjura.apply_status(id, 3)
		await _esperar(3)   # unos fotogramas: no hace falta que le llegue el turno a nadie
		var verbo: String = "la pierde YA" if corta else "la sigue llevando"
		_ver((e.charging == null) == corta, "%s: el enemigo cargando %s" % [nom, verbo])
		_ver((al[0].charging == null) == corta, "%s: uno de los tuyos cargando %s" % [nom, verbo])
		_ver((not combat._casteos.has(conjura)) == corta, "%s: uno de los tuyos conjurando %s" % [nom, verbo])
		e.charging = null
		al[0].charging = null
		combat._casteos.erase(conjura)
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
