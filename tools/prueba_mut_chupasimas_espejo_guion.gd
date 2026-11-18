# LA CHUPASIMAS Y SUS MUTANTES EN EL ESPEJO, guion del jugador (18/11, memoria chupasimas-mutante). Como en el juego: la
# pelea la lleva la SALA y yo la veo en espejo. Miro en MI pantalla:
#   1) la arena con la normal y los tres mutantes (Coagulo, Sanguijuela vidriada, Madre de las simas); la pelea en espejo
#   2) cada uno con su nombre, SU sprite de mutante y sus pasivas (la costra y la sed, de su ficha)
#   3) la COSTRA DE SANGRE se ve: le sale -> su hoja con costra; se rompe -> las postillas y vuelta a la de sin costra
#   4) el DRENAJE del Coagulo: las gotas de sangre y la costra que se cuaja, en pixel
#   5) el RAYO DE MANA lleno: el haz con el grosor de la carga (viaja en el peso del golpe) y sus chispas
extends "res://tools/prueba_town_sala_comun.gd"

const ORDEN := "user://sonda_orden.txt"
const CHUPASIMAS := "res://scenes/actors/enemy/chupasimas.tres"
var _n_orden := 0


func _ready() -> void:
	prefijo = ""
	slot = 92
	puerto = 24624
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


# De que fichero sale el primer fotograma de una anim (para saber de QUE carpeta es el sprite).
func _origen(sf: SpriteFrames, anim: StringName) -> String:
	if sf == null or not sf.has_animation(anim) or sf.get_frame_count(anim) == 0:
		return ""
	var tx: Texture2D = sf.get_frame_texture(anim, 0)
	while tx is AtlasTexture and (tx as AtlasTexture).atlas != null:
		tx = (tx as AtlasTexture).atlas
	return tx.resource_path if tx != null else ""


# Lo que sale en mi arena durante 'plazo' segundos (los efectos duran poco: se mira cada fotograma): las hojas en pixel que
# han salido y el haz mas gordo que se ha visto.
func _vigilar(arena: Node, plazo: float) -> Dictionary:
	var hojas: Dictionary = {}
	var grueso: float = 0.0
	var t := 0.0
	while t < plazo:
		for e in arena.find_children("*", "EfectoPixel", true, false):
			hojas[String(e.get_meta("hoja", ""))] = true
		for r in arena.find_children("*", "RayoPixel", true, false):
			grueso = maxf(grueso, float(r.get("_grueso")))
		await get_tree().process_frame
		t += get_process_delta_time()
	return {"hojas": hojas, "grueso": grueso}


func _sprite_de(t, c: Combatant) -> String:
	var cu: Node2D = t.cuerpo_de(c)
	var spr = cu.get("_sprite") if cu != null else null
	var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames if spr is AnimatedSprite2D else null
	return _origen(sf, &"idle_0")


func _guion() -> void:
	# 1) LA ARENA Y LA PELEA
	Game.entrar_arena_de_pruebas()
	var t0 := await _hasta(func(): return Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, 40.0)
	if not _ok_y(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, "estoy en la arena (%.1f s)" % t0):
		return
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena(CHUPASIMAS, yo.global_position + Vector2(30, 120), {"mutacion": "coagulo"})
	Net.pisos.pedir_spawn_arena(CHUPASIMAS, yo.global_position + Vector2(-30, 120), {"mutacion": "vidriada"})
	Net.pisos.pedir_spawn_arena(CHUPASIMAS, yo.global_position + Vector2(0, 160), {"mutacion": "madre"})
	await _hasta(func(): return Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() >= 3, 15.0)
	await pelear_con(enemigo_libre())
	await _hasta(func(): return pantalla() != null, 10.0)
	var p: Node = pantalla()
	if not _ok_y(p != null and bool(p.tactico), "la pelea se abre en el mapa"):
		return
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la lleva la SALA y yo la veo en espejo (como en el juego)")
	await _hasta(func(): return _de(p, &"coagulo") != null and _de(p, &"vidriada") != null and _de(p, &"madre") != null, 15.0)
	_ok(await _ordenar("preparar") == "ok", "la sala les sube la vida (que la pelea no acabe sola)")
	var t = p.turno_mapa
	var arena: Node = t._arena()

	# 2) LOS TRES, CON SU NOMBRE, SU SPRITE Y SUS PASIVAS
	for par in [[&"coagulo", "Coágulo", ["idle_0", "drenaje_0", "adherirse_0"], [StatusEffects.Id.COSTRA_SANGRE]],
			[&"vidriada", "Sanguijuela vidriada", ["idle_0", "sorbo_0", "rayo_0"], [StatusEffects.Id.SED_MANA]],
			[&"madre", "Madre de las simas", ["idle_0", "rayo_0", "drenaje_0"],
				[StatusEffects.Id.COSTRA_SANGRE, StatusEffects.Id.SED_MANA]]]:
		var c: Combatant = _de(p, par[0])
		_ok(c != null and c.nombre.contains(par[1]), "en mi pantalla esta: %s (%s)" % [par[1], c.nombre if c != null else "?"])
		if c == null:
			continue
		var cu: Node2D = t.cuerpo_de(c)
		_ok(cu != null and cu.visible and t._de_las_chupasimas(cu), "%s: con su cuerpo en mi mapa, de las chupasimas" % par[1])
		var spr = cu.get("_sprite") if cu != null else null
		var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames if spr is AnimatedSprite2D else null
		var faltan: Array = (par[2] as Array).filter(func(a): return sf == null or not sf.has_animation(StringName(a)))
		_ok(faltan.is_empty(), "%s: con sus anims (faltan %s)" % [par[1], str(faltan)])
		var de := _sprite_de(t, c)
		_ok(de.contains("chupasimas_sdf_%s" % String(par[0])) and not de.contains("costra"),
			"%s: el sprite es SUYO, sin costra (%s)" % [par[1], de])
		var t_p := await _hasta(func(): return (par[3] as Array).all(func(id): return c.has_status(id)), 8.0)
		_ok((par[3] as Array).all(func(id): return c.has_status(id)), "%s: con sus pasivas a la vista (%.1f s)" % [par[1], t_p])
	var coa: Combatant = _de(p, &"coagulo")
	_ok(coa != null and coa.costra_sangre > 0.0, "el Coagulo de mi pantalla sabe que tiene Costra de sangre (para el chorreo)")

	# 3) LA COSTRA SE VE
	_ok((await _ordenar("costra")).begins_with("ok:"), "a la sala le sale la costra al Coagulo")
	var t_c := await _hasta(func(): return coa != null and _sprite_de(t, coa).contains("coagulo_costra"), 10.0)
	_ok(coa != null and _sprite_de(t, coa).contains("coagulo_costra"), "en mi pantalla se le pone la hoja con costra (%.1f s)" % t_c)
	_ordenar("romper_costra")
	var v_r: Dictionary = await _vigilar(arena, 3.0)
	_ok(v_r["hojas"].has("postillas_coagulo"), "al romperse, en mi pantalla saltan las postillas")
	_ok(coa != null and not _sprite_de(t, coa).contains("costra"), "y vuelve a la hoja sin costra")

	# 4) EL DRENAJE DEL COAGULO
	_ordenar("drenaje")
	var v_d: Dictionary = await _vigilar(arena, 4.0)
	_ok(v_d["hojas"].has("gota_entra_sangre"), "las gotas de sangre del Drenaje, en pixel (%s)" % str(v_d["hojas"].keys()))
	_ok(v_d["hojas"].has("cuaja_coagulo"), "y la costra que se le cuaja")

	# 5) EL RAYO LLENO
	_ordenar("rayo_lleno")
	var v_y: Dictionary = await _vigilar(arena, 4.0)
	_ok(absf(float(v_y["grueso"]) - 4.8) < 0.1, "el haz del rayo LLENO, gordo como en la sala (%.2f celdas)" % float(v_y["grueso"]))
	_ok(v_y["hojas"].has("rayo_boca_2") and v_y["hojas"].has("chispa_mana"), "con el mana en la boca y las chispas")


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
