# EL ACECHADOR Y SUS MUTANTES EN EL ESPEJO, guion del jugador (20/11, memoria acechador-mutante). Como en el juego: la pelea
# la lleva la SALA y yo la veo en espejo. Miro en MI pantalla:
#   1) la arena con la Sombra sin rostro y el Cazador lunar; la pelea en espejo
#   2) cada uno con su nombre, SU sprite de mutante y sus pasivas (Paciencia; el Cazador, Fases de la luna y Luz de luna)
#   3) LA LUNA DEL CIELO: sale, con la fase y los puntos de la Paciencia del Cazador
#   4) el Cazador CARGA la Caida: la luna tiembla
#   5) la CAIDA DE LA LUNA: la luna cae y suelta su golpe; la MEDIA LUNA; la MARCA (el estado y la creciente encima)
#   6) la Sombra se FUNDE en las sombras: su cuerpo se va
#   7) el set NOCHE DE LUNA: el chip de mi personaje con su fase (llena)
extends "res://tools/prueba_town_sala_comun.gd"

const ORDEN := "user://sonda_orden.txt"
const ACECHADOR := "res://scenes/actors/enemy/acechador.tres"
var _n_orden := 0


func _ready() -> void:
	prefijo = ""
	slot = 94
	puerto = 24626
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


func _origen(sf: SpriteFrames, anim: StringName) -> String:
	if sf == null or not sf.has_animation(anim) or sf.get_frame_count(anim) == 0:
		return ""
	var tx: Texture2D = sf.get_frame_texture(anim, 0)
	while tx is AtlasTexture and (tx as AtlasTexture).atlas != null:
		tx = (tx as AtlasTexture).atlas
	return tx.resource_path if tx != null else ""


func _sprite_de(t, c: Combatant) -> String:
	var cu: Node2D = t.cuerpo_de(c)
	var spr = cu.get("_sprite") if cu != null else null
	var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames if spr is AnimatedSprite2D else null
	return _origen(sf, &"idle_0")


# Las hojas en pixel que salen en mi arena durante 'plazo' segundos (se mira cada fotograma: los efectos duran poco).
func _vigilar(arena: Node, plazo: float) -> Dictionary:
	var hojas: Dictionary = {}
	var t := 0.0
	while t < plazo:
		for e in arena.find_children("*", "EfectoPixel", true, false):
			hojas[String(e.get_meta("hoja", ""))] = true
		await get_tree().process_frame
		t += get_process_delta_time()
	return hojas


func _luna() -> LunaCielo:
	return get_tree().get_first_node_in_group(LunaCielo.GRUPO) as LunaCielo


func _guion() -> void:
	# 1) LA ARENA Y LA PELEA
	Game.entrar_arena_de_pruebas()
	var t0 := await _hasta(func(): return Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, 40.0)
	if not _ok_y(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, "estoy en la arena (%.1f s)" % t0):
		return
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena(ACECHADOR, yo.global_position + Vector2(30, 120), {"mutacion": "sombra"})
	Net.pisos.pedir_spawn_arena(ACECHADOR, yo.global_position + Vector2(-40, 150), {"mutacion": "cazador"})
	await _hasta(func(): return Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() >= 2, 15.0)
	await pelear_con(enemigo_libre())
	await _hasta(func(): return pantalla() != null, 10.0)
	var p: Node = pantalla()
	if not _ok_y(p != null and bool(p.tactico), "la pelea se abre en el mapa"):
		return
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la lleva la SALA y yo la veo en espejo (como en el juego)")
	await _hasta(func(): return _de(p, &"sombra") != null and _de(p, &"cazador") != null, 15.0)
	_ok(await _ordenar("preparar") == "ok", "la sala les sube la vida (que la pelea no acabe sola)")
	var t = p.turno_mapa
	var arena: Node = t._arena()

	# 2) LOS DOS, CON SU NOMBRE, SU SPRITE Y SUS PASIVAS
	for par in [[&"sombra", "Sombra sin rostro", ["idle_0", "fundirse_0", "emerger_0"], [StatusEffects.Id.PACIENCIA]],
			[&"cazador", "Cazador lunar", ["idle_0", "media_luna_0", "aullido_0", "marca_0"],
				[StatusEffects.Id.PACIENCIA, StatusEffects.Id.FASES_LUNA, StatusEffects.Id.LUZ_LUNA]]]:
		var c: Combatant = _de(p, par[0])
		_ok(c != null and c.nombre.contains(par[1]), "en mi pantalla esta: %s (%s)" % [par[1], c.nombre if c != null else "?"])
		if c == null:
			continue
		var cu: Node2D = t.cuerpo_de(c)
		var spr = cu.get("_sprite") if cu != null else null
		var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames if spr is AnimatedSprite2D else null
		var faltan: Array = (par[2] as Array).filter(func(a): return sf == null or not sf.has_animation(StringName(a)))
		_ok(faltan.is_empty(), "%s: con sus anims (faltan %s)" % [par[1], str(faltan)])
		_ok(_sprite_de(t, c).contains("acechador_sdf_%s" % String(par[0])), "%s: el sprite es SUYO (%s)" % [par[1], _sprite_de(t, c)])
		var t_p := await _hasta(func(): return (par[3] as Array).all(func(id): return c.has_status(id)), 8.0)
		_ok((par[3] as Array).all(func(id): return c.has_status(id)), "%s: con sus pasivas a la vista (%.1f s)" % [par[1], t_p])

	# 3) LA LUNA DEL CIELO, con la fase y los puntos del Cazador
	var caz: Combatant = _de(p, &"cazador")
	var t_l := await _hasta(func(): return _luna() != null, 10.0)
	_ok(_luna() != null, "la luna sale en mi cielo (%.1f s)" % t_l)
	if _luna() != null and caz != null:
		await _hasta(func(): return _luna().fase == maxi(caz.fase_luna, 0) and _luna().puntos == caz.paciencia_carga, 6.0)
		_ok(_luna().fase == maxi(caz.fase_luna, 0) and _luna().puntos == caz.paciencia_carga,
			"con la fase (%d) y los puntos (%d) del Cazador" % [_luna().fase, _luna().puntos])

	# 4) CARGA LA CAIDA: LA LUNA TIEMBLA
	_ok((await _ordenar("acechador_cargar")).begins_with("ok:"), "la sala: el Cazador empieza a cargar la Caida")
	var t_tb := await _hasta(func(): return _luna() != null and _luna().temblando, 8.0)
	_ok(_luna() != null and _luna().temblando, "mientras carga, la luna tiembla en mi pantalla (%.1f s)" % t_tb)

	# 5) LA CAIDA, LA MEDIA LUNA Y LA MARCA
	var caidas0: int = _luna().caidas if _luna() != null else 0
	_ordenar("acechador_caida")
	var vistas: Dictionary = await _vigilar(arena, 4.0)
	_ok(_luna() != null and _luna().caidas > caidas0, "la Caida: la luna cae en mi pantalla (%d)" % (_luna().caidas if _luna() != null else -1))
	_ok(vistas.has("luna_golpe"), "y suelta su golpe (%s)" % str(vistas.keys()))
	_ordenar("acechador_media_luna")
	vistas = await _vigilar(arena, 3.0)
	_ok(vistas.has("media_luna"), "la Media luna, su hoja en pixel (%s)" % str(vistas.keys()))
	var r_m: String = await _ordenar("acechador_marca")
	var marcado: String = r_m.substr(3) if r_m.begins_with("ok:") else ""
	var t_m := await _hasta(func(): return p._aliados.any(func(a): return a.has_status(StatusEffects.Id.MARCA_LUNA)), 8.0)
	_ok(p._aliados.any(func(a): return a.has_status(StatusEffects.Id.MARCA_LUNA)), "la Marca le llega a %s (%.1f s)" % [marcado, t_m])
	vistas = await _vigilar(arena, 1.5)
	_ok(vistas.has("marca"), "con la creciente encima (%s)" % str(vistas.keys()))

	# 6) LA SOMBRA SE FUNDE: su cuerpo se va de mi pantalla
	var som: Combatant = _de(p, &"sombra")
	_ok((await _ordenar("acechador_esconder")).begins_with("ok:"), "la sala: la Sombra se funde en las sombras")
	var t_s := await _hasta(func(): return som != null and t.cuerpo_de(som) != null and not t.cuerpo_de(som).visible, 8.0)
	_ok(som != null and t.cuerpo_de(som) != null and not t.cuerpo_de(som).visible, "en mi pantalla deja de verse (%.1f s)" % t_s)

	# 7) EL SET NOCHE DE LUNA: el chip con la fase (llena) en mi personaje
	var r_n: String = await _ordenar("noche_luna")
	var quien: String = r_n.substr(3) if r_n.begins_with("ok:") else ""
	var mio: Combatant = null
	for a in p._aliados:
		if a.nombre == quien:
			mio = a
	var t_n := await _hasta(func(): return mio != null and mio.has_status(StatusEffects.Id.NOCHE_LUNA), 8.0)
	_ok(mio != null and mio.has_status(StatusEffects.Id.NOCHE_LUNA), "a %s le llega el chip de Noche de luna (%.1f s)" % [quien, t_n])
	if mio != null and mio.has_status(StatusEffects.Id.NOCHE_LUNA):
		var chip: Array = StatusEffects.chip_de_grupo(mio.statuses.filter(func(s): return s.id() == StatusEffects.Id.NOCHE_LUNA), mio)
		_ok(String(chip[5]) == "noche_luna_2", "con la lunita de su fase: llena (%s)" % chip[5])


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
