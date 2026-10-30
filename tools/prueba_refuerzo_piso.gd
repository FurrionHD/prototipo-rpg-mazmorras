# PRUEBA (30/10, playtest del 29/10): LOS QUE ENTRAN A MITAD DE PELEA, CON LAS STATS DE SU PISO. En el piso 6, un slime de
# veneno del arranque tenia ~90 de vida y el que se unio despues ~32 (el de piso 1): el refuerzo y las crias del Brote
# salian con Game.current_floor, que en la sala (lleva varios pisos a la vez) no es el piso de la pelea.
# Pelea en el piso 6 contra un slime de veneno, con current_floor a 1 como en la sala; se une otro igual y el Brote saca
# crias: los tres con la vida de piso 6.
#   godot --headless --path . res://tools/prueba_refuerzo_piso.tscn
extends Node

const VENENO := "res://scenes/actors/enemy/slime_veneno.tres"
const PISO := 6

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


func _ver(ok: bool, que: String) -> void:
	print("  %s: %s" % ["BIEN" if ok else "MAL", que])
	if not ok:
		_mal += 1


func _correr() -> void:
	sala = preload("res://tools/prueba_sala_propia.gd").new()
	add_child(sala)
	Game.arena_piso_juego = PISO   # la arena (donde se pueden poner enemigos) jugando como el piso 6
	if not await sala.arrancar("prueba_refuerzo_piso", Game.PISO_ARENA):
		print("MAL: no arranca la sala")
		get_tree().quit(1)
		return
	for n in sala.enemigos():
		if is_instance_valid(n):
			n.queue_free()
	await _esperar(5)
	sala.poner(VENENO, Vector2(60, 0))
	await _esperar(10)
	var primero: Array = sala.enemigos().filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())
	var combat: Node = await sala.pelear(primero)
	if combat == null:
		print("MAL: no se abre la pelea")
		get_tree().quit(1)
		return
	var esperado: float = (load(VENENO) as EnemyData).crear_combatant(0.5, false, false, &"", PISO).max_hp
	var del_arranque: float = combat._enemies[0].max_hp
	# LA SALA lleva varios pisos: su current_floor no es el de esta pelea.
	Game.current_floor = 1
	sala.poner(VENENO, Vector2(-60, 0))
	await _esperar(10)
	var otro = null
	for n in sala.enemigos():
		if is_instance_valid(n) and not primero.has(n):
			otro = n
	_ver(otro != null and sala.unir(otro), "se une un segundo slime de veneno")
	await _esperar(5)
	var refuerzo: Combatant = combat._enemies[combat._enemies.size() - 1] if combat._enemies.size() > 1 else null
	print("  vida: piso %d (t=0.5) %.1f, el del arranque %.1f, el refuerzo %.1f" % [PISO, esperado, del_arranque,
		refuerzo.max_hp if refuerzo != null else -1.0])
	# La vida varia con la 't' de cada uno (su color): se compara con la de piso 1, que es mucho menor.
	var de_piso_1: float = (load(VENENO) as EnemyData).crear_combatant(1.0, false, false, &"", 1).max_hp
	_ver(refuerzo != null and refuerzo.max_hp > de_piso_1 * 1.5, "el refuerzo entra con la vida de su piso (piso 1 seria <= %.1f)" % de_piso_1)
	var cria: Combatant = combat.altas._invocar_slime(load(VENENO))
	_ver(cria != null and cria.max_hp > de_piso_1 * 1.5, "la cria del Brote nace con la vida de su piso (%.1f)" % (
		cria.max_hp if cria != null else -1.0))
	print("=== FIN (%s) ===" % ("TODO BIEN" if _mal == 0 else "%d MAL" % _mal))
	get_tree().quit(0 if _mal == 0 else 1)
