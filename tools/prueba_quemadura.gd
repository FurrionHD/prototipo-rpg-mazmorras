# EL FUEGO CON CRITERIO (06/10): la Quemadura arde un % del GOLPE que la prende y NO se suma (arde solo la mas fuerte,
# las flojas se gastan por debajo). Su ejemplo: turno 1 un fuego de 8, turno 2 uno de 3 -> arde el 8; turno 3 se va el
# 8 y arde el 3; turno 4, nada. Y el RESCOLDO: la mitad, 3 turnos, fallas mas, el agua lo apaga. Sin ventana:
#   godot --headless --path . res://tools/prueba_quemadura.tscn
extends Node

var _mal: int = 0


func _ready() -> void:
	call_deferred("_correr")


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _victima() -> Combatant:
	var c := Combatant.new("Muñeco", 1, Abilities.new(), 1000.0, 5.0, 5.0, 5.0)
	c.max_hp = 1000.0
	c.current_hp = 1000.0
	return c


# Un turno: lo que le quita.
func _turno(c: Combatant) -> float:
	var antes: float = c.current_hp
	c.tick_statuses()
	return antes - c.current_hp


func _correr() -> void:
	var Q: int = StatusEffects.Id.QUEMADURA
	print("1) su ejemplo: 8 y luego 3")
	var c := _victima()
	c.apply_status(Q, 2, 8.0)
	var t1: float = _turno(c)
	c.apply_status(Q, 2, 3.0)
	var t2: float = _turno(c)
	var t3: float = _turno(c)
	var t4: float = _turno(c)
	print("    turnos: %.1f %.1f %.1f %.1f" % [t1, t2, t3, t4])
	_ver(is_equal_approx(t1, 8.0), "turno 1 arde el 8")
	_ver(is_equal_approx(t2, 8.0), "turno 2 sigue el 8 (no se suma el 3)")
	_ver(is_equal_approx(t3, 3.0), "turno 3 se va el 8 y arde el 3")
	_ver(is_zero_approx(t4), "turno 4 nada")

	print("2) el fuego segun el golpe")
	var m_daga: float = StatusEffects.magnitud_por_golpe(Q, 10.0, 10.0)
	var m_martillo: float = StatusEffects.magnitud_por_golpe(Q, 30.0, 30.0 * 1.5)
	print("    daga (golpe 10) %.1f/turno, martillo (golpe 45) %.1f/turno" % [m_daga, m_martillo])
	_ver(is_equal_approx(m_daga, 3.0) and is_equal_approx(m_martillo, 13.5), "30 % del golpe")
	_ver(is_equal_approx(StatusEffects.magnitud_por_golpe(Q, 20.0), 6.0), "sin golpe, del ataque de quien la pone")
	var app := StatusApplication.new()
	app.estado = Q
	_ver(is_equal_approx(StatusEffects.app_magnitude(app, 20.0, 1.0, 40.0), 12.0), "app_magnitude usa el golpe")

	print("3) el rescoldo")
	var R: int = StatusEffects.Id.RESCOLDO
	var c2 := _victima()
	var mr: float = StatusEffects.magnitud_por_golpe(R, 0.0, 40.0)
	_ver(is_equal_approx(mr, 6.0), "15 % del golpe (40 -> 6)")
	c2.apply_status(R, -1, mr)
	c2.apply_status(R, -1, 2.0)
	_ver(is_equal_approx(c2.status_precision_flat(), -0.08), "fallas un 8 % mas (UNA vez aunque lleve dos)")
	var r1: float = _turno(c2)
	_ver(is_equal_approx(r1, 6.0), "arde el mas fuerte (6)")
	var turnos: int = 0
	for e in c2.statuses:
		if e.id() == R:
			turnos = maxi(turnos, e.turns)
	_ver(turnos == 2, "dura 3 turnos (le quedan 2)")
	c2.apply_status(StatusEffects.Id.MOJADO)
	_ver(not c2.has_status(R), "el agua lo apaga")

	print("4) el slime de fuego: su Llamarada quema segun su ataque")
	var ed: EnemyData = load("res://scenes/actors/enemy/slime_fuego.tres")
	var ll: AbilityData = load("res://resources/abilities/slime_llamarada.tres")
	var e_atk: float = 12.0
	var esperado: float = e_atk * ll.dano_mult * 0.30
	var a_q = null
	for a in ll.efectos:
		if a.estado == Q:
			a_q = a
	_ver(a_q != null and is_equal_approx(StatusEffects.app_magnitude(a_q, e_atk, 1.0, e_atk * ll.dano_mult), esperado),
		"Llamarada con ataque 12: %.2f/turno" % esperado)
	_ver(ed != null, "la ficha carga")
	print("FIN: %s (%d MAL)" % ["TODO BIEN" if _mal == 0 else "HAY FALLOS", _mal])
	get_tree().quit(1 if _mal > 0 else 0)
