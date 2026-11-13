# LA POLILLA Y SUS MUTANTES EN EL ESPEJO, guion del jugador (12/11, memoria polilla-mutante). Como en el juego: la pelea
# la lleva la SALA y yo la veo en espejo. Miro en MI pantalla:
#   1) la arena con las tres mutantes (Vigilia dorada, Mortaja alada y Polilla insomne); la pelea en el mapa, en espejo
#   2) cada una con su nombre y SU sprite de mutante (la Insomne con su Ojo; la Mortaja con su Amortajarse)
#   3) la PASIVA QUE SE VE: la Insomne lleva Ojos en vela en mi pantalla (viaja con los estados), su ficha dice que es
#      pasiva y no se puede disipar, y el 50 % sale del dato
#   4) sus OJOS PARPADEAN POR SEPARADO: seis capas de parpados que van por turnos
extends "res://tools/prueba_town_sala_comun.gd"

const ORDEN := "user://sonda_orden.txt"
const PAVON := "res://scenes/actors/enemy/polilla.tres"
const LUTO := "res://scenes/actors/enemy/polilla_luto.tres"
var _n_orden := 0


func _ready() -> void:
	prefijo = ""
	slot = 90
	puerto = 24622
	if FileAccess.file_exists(ORDEN):
		DirAccess.remove_absolute(_ruta(ORDEN))
	if not preparar_mundo(GRUPO_A, CASA_A, GRUPO_B, CASA_B) or not await abrir_sala_y_entrar():
		await _acabar()
		return
	await _guion()
	await _acabar()


func _ordenar(orden: String, nombre := "") -> String:
	_n_orden += 1
	var f := FileAccess.open(ORDEN, FileAccess.WRITE)
	f.store_string("%d %s %s" % [_n_orden, orden, nombre])
	f.close()
	var clave := "orden_%d" % _n_orden
	await hasta_sala(clave, func(v): return v != "", 10.0)
	return dato_sala(clave)


func _hasta(cond: Callable, plazo: float) -> float:
	var t := 0.0
	while not cond.call() and t < plazo:
		await _esperar(0.1)
		t += 0.1
	return t


func _de(p: Node, mut: StringName) -> Combatant:
	for o in p._enemies:
		if (o as Combatant).mutacion == mut:
			return o
	return null


func _guion() -> void:
	# 1) LA ARENA Y LA PELEA
	Game.entrar_arena_de_pruebas()
	var t0 := await _hasta(func(): return Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, 40.0)
	if not _ok_y(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, "estoy en la arena (%.1f s)" % t0):
		return
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena(PAVON, yo.global_position + Vector2(0, 150), {"mutacion": "vigilia"})
	Net.pisos.pedir_spawn_arena(LUTO, yo.global_position + Vector2(110, 130), {"mutacion": "mortaja"})
	Net.pisos.pedir_spawn_arena(PAVON, yo.global_position + Vector2(-110, 130), {"mutacion": "insomne"})
	await _hasta(func(): return Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() >= 3, 15.0)
	await pelear_con(enemigo_libre())
	await _hasta(func(): return pantalla() != null, 10.0)
	var p: Node = pantalla()
	if not _ok_y(p != null and bool(p.tactico), "la pelea se abre en el mapa"):
		return
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la lleva la SALA y yo la veo en espejo (como en el juego)")
	await _hasta(func(): return _de(p, &"vigilia") != null and _de(p, &"mortaja") != null and _de(p, &"insomne") != null, 15.0)
	_ok(await _ordenar("preparar") == "ok", "la sala les sube la vida (que la pelea no acabe sola)")
	var t = p.turno_mapa

	# 2) LAS TRES, CON SU NOMBRE Y SU SPRITE
	for par in [[&"vigilia", "Vigilia dorada", "evolucion_0"], [&"mortaja", "Mortaja alada", "amortajarse_0"],
			[&"insomne", "Polilla insomne", "ojo_carga_0"]]:
		var c: Combatant = _de(p, par[0])
		_ok(c != null and c.nombre == par[1], "en mi pantalla esta la %s (%s)" % [par[1], c.nombre if c != null else "?"])
		if c == null:
			continue
		var cu: Node2D = t.cuerpo_de(c)
		_ok(cu != null and cu.visible, "%s: con su cuerpo en mi mapa" % par[1])
		var spr = cu.get("_sprite") if cu != null else null
		var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames if spr is AnimatedSprite2D else null
		_ok(sf != null and sf.has_animation(StringName(par[2])), "%s: con SU sprite de mutante ('%s')" % [par[1], par[2]])

	# 3) LA PASIVA QUE SE VE
	var ins: Combatant = _de(p, &"insomne")
	if ins != null:
		var t_p := await _hasta(func(): return ins.has_status(StatusEffects.Id.OJOS_INSOMNES), 10.0)
		_ok(ins.has_status(StatusEffects.Id.OJOS_INSOMNES), "la Insomne lleva Ojos en vela en mi pantalla (%.1f s)" % t_p)
		var txt := ""
		for e in ins.statuses:
			if e.id() == StatusEffects.Id.OJOS_INSOMNES:
				txt = e.resumen()
		_ok(txt.contains("pasiva (no se puede disipar)") and txt.contains("50 %"), "su ficha: %s" % txt.replace("\n", " | "))

		# 4) LOS OJOS PARPADEAN POR SEPARADO
		var cu_i: Node2D = t.cuerpo_de(ins)
		var spr_i = cu_i.get("_sprite") if cu_i != null else null
		var capas: Array = []
		if spr_i is Node:
			capas = (spr_i as Node).get_children().filter(func(h): return h is Parpadeo)
		_ok(capas.size() == 6, "sus seis ojos de ala, una capa de parpados cada uno (%d)" % capas.size())
		_ok(not capas.is_empty() and capas.all(func(h): return h._en_turnos and is_equal_approx(h._cada, 3.0)),
			"y van POR TURNOS (uno cada 3 s)")


# Como _fin, sin jugador B.
func _acabar() -> void:
	if FileAccess.file_exists(ORDEN):
		DirAccess.remove_absolute(_ruta(ORDEN))
	for linea in _texto(registro_sala).split("\n"):
		if linea.contains("SCRIPT ERROR") or linea.begins_with("[S] dato orden_"):
			print("[sala] ", linea)
	Net.desconectar()
	var t := 0.0
	while OS.is_process_running(_pid_sala) and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not OS.is_process_running(_pid_sala), "la sala se cierra sola al irme (%.1f s)" % t)
	if proceso_vivo(_pid_sala):
		OS.kill(_pid_sala)
	if _nube_id != "":
		await Nube.partida_borrar(_nube_id)
	_borrar_ranura()
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() else "FALLAN %d" % fallos.size())
	get_tree().quit(0 if fallos.is_empty() else 1)
