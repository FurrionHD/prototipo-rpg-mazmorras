# EL CHILLON Y SUS MUTANTES EN EL ESPEJO, guion del jugador (18/11, memoria chillon-mutante). Como en el juego: la pelea la
# lleva la SALA y yo la veo en espejo. Miro en MI pantalla:
#   1) la arena con el Apagaluces y la Piña negra; la pelea en espejo
#   2) cada uno con su nombre, SU sprite de mutante y sus pasivas (Bebe la luz; la Piña, tambien el Racimo)
#   3) el CHILLIDO DE OSCURIDAD: la sombra por el suelo, en pixel; al que se queda A oscuras, su luz que se apaga
#   4) LA PIÑA SUELTA UNA CRIA: me llega con su sprite de cria y Bebe la luz
#   5) ECOLOCALIZACION: con el set puesto (viaja en mi fila del roster), en mi turno el escondido se ve y se puede elegir
extends "res://tools/prueba_town_sala_comun.gd"

const ORDEN := "user://sonda_orden.txt"
const CHILLON := "res://scenes/actors/enemy/chillon.tres"
var _n_orden := 0


func _ready() -> void:
	prefijo = ""
	slot = 93
	puerto = 24625
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
	Net.pisos.pedir_spawn_arena(CHILLON, yo.global_position + Vector2(30, 120), {"mutacion": "apagaluces"})
	Net.pisos.pedir_spawn_arena(CHILLON, yo.global_position + Vector2(-40, 150), {"mutacion": "pina"})
	await _hasta(func(): return Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() >= 2, 15.0)
	await pelear_con(enemigo_libre())
	await _hasta(func(): return pantalla() != null, 10.0)
	var p: Node = pantalla()
	if not _ok_y(p != null and bool(p.tactico), "la pelea se abre en el mapa"):
		return
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la lleva la SALA y yo la veo en espejo (como en el juego)")
	await _hasta(func(): return _de(p, &"apagaluces") != null and _de(p, &"pina") != null, 15.0)
	_ok(await _ordenar("preparar") == "ok", "la sala les sube la vida (que la pelea no acabe sola)")
	var t = p.turno_mapa
	var arena: Node = t._arena()

	# 2) LOS DOS, CON SU NOMBRE, SU SPRITE Y SUS PASIVAS
	for par in [[&"apagaluces", "Apagaluces", ["idle_0", "chillido_oscuro_0", "embestida_0"], [StatusEffects.Id.BEBE_LUZ]],
			[&"pina", "Piña negra", ["idle_0", "chillido_oscuro_0", "soltar_0"], [StatusEffects.Id.BEBE_LUZ, StatusEffects.Id.RACIMO]]]:
		var c: Combatant = _de(p, par[0])
		_ok(c != null and c.nombre.contains(par[1]), "en mi pantalla esta: %s (%s)" % [par[1], c.nombre if c != null else "?"])
		if c == null:
			continue
		var cu: Node2D = t.cuerpo_de(c)
		_ok(cu != null and t._de_los_chillones(cu), "%s: con su cuerpo en mi mapa, de los chillones" % par[1])
		var spr = cu.get("_sprite") if cu != null else null
		var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames if spr is AnimatedSprite2D else null
		var faltan: Array = (par[2] as Array).filter(func(a): return sf == null or not sf.has_animation(StringName(a)))
		_ok(faltan.is_empty(), "%s: con sus anims (faltan %s)" % [par[1], str(faltan)])
		_ok(_sprite_de(t, c).contains("chillon_sdf_%s" % String(par[0])), "%s: el sprite es SUYO (%s)" % [par[1], _sprite_de(t, c)])
		var t_p := await _hasta(func(): return (par[3] as Array).all(func(id): return c.has_status(id)), 8.0)
		_ok((par[3] as Array).all(func(id): return c.has_status(id)), "%s: con sus pasivas a la vista (%.1f s)" % [par[1], t_p])

	# 3) EL CHILLIDO DE OSCURIDAD (95 %: hasta 3 intentos para que alguno se quede a oscuras)
	var vista: Dictionary = {}
	var a_oscuras := false
	for intento in 3:
		_ordenar("chillido_oscuro")
		var v: Dictionary = await _vigilar(arena, 3.0)
		vista.merge(v["hojas"])
		a_oscuras = p._aliados.any(func(a): return a.has_status(StatusEffects.Id.A_OSCURAS))
		if a_oscuras and vista.has("farol"):
			break
	_ok(vista.has("sombra70"), "la sombra del Chillido por el suelo, en pixel (%s)" % str(vista.keys()))
	_ok(a_oscuras, "a uno de los mios le llega A oscuras")
	_ok(vista.has("farol") and vista.has("mota_entra"), "y en mi pantalla se le apaga la luz y las motas van al bicho")

	# 4) LA PIÑA SUELTA UNA CRIA
	var antes: int = p._enemies.filter(func(e): return e.is_alive()).size()
	_ok((await _ordenar("soltar_cria")).begins_with("ok:"), "la Piña suelta una cria en la sala")
	var t_c := await _hasta(func(): return p._enemies.any(func(e): return e.is_alive() and e.nombre.contains("Cría")), 10.0)
	var cria: Combatant = null
	for e in p._enemies:
		if e.is_alive() and e.nombre.contains("Cría"):
			cria = e
	_ok(cria != null, "me llega la cria (%.1f s; antes %d en pie)" % [t_c, antes])
	if cria != null:
		await _hasta(func(): return t.cuerpo_de(cria) != null and _sprite_de(t, cria) != "", 8.0)
		_ok(_sprite_de(t, cria).contains("chillon_sdf_cria"), "con su sprite de cria (%s)" % _sprite_de(t, cria))
		await _hasta(func(): return cria.has_status(StatusEffects.Id.BEBE_LUZ), 6.0)
		_ok(cria.has_status(StatusEffects.Id.BEBE_LUZ), "y con Bebe la luz a la vista")

	# 5) ECOLOCALIZACION: el set viaja en mi fila del roster; en MI turno el escondido se ve y se puede elegir
	var r_eco: String = await _ordenar("eco_sombras")
	_ok(r_eco.begins_with("ok:"), "la sala me pone el set y esconde al Apagaluces (%s)" % r_eco)
	var apa: Combatant = _de(p, &"apagaluces")
	var t_e := await _hasta(func(): return p._aliados.size() > 0 and p._aliados[0].runa_eco, 10.0)
	_ok(p._aliados.size() > 0 and p._aliados[0].runa_eco, "mi maniqui sabe que lleva Ecolocalizacion (%.1f s)" % t_e)
	await _hasta(func(): return apa != null and apa.en_sombras(), 6.0)
	_ok(apa != null and apa.en_sombras(), "el Apagaluces esta En las sombras en mi pantalla")
	# (19/11) MI GRUPO SON DOS (Agirato y Catalardio) y los dos los llevo yo: si le toca antes a Catalardio, la pelea le
	# espera a EL y nadie le movia (fallaba 2 de 5: "llega mi turno (40 s)", segun quien llegara antes en la barra). Como
	# haria el jugador, se le pone a defender y se sigue esperando el de Agirato.
	var t_t := 0.0
	var pasados := 0
	while t_t < 40.0:
		if p._state == p.State.WAITING_PLAYER and p._player == p._aliados[0]:
			break
		if p._state == p.State.WAITING_PLAYER and p._player != null and p._aliados.has(p._player):
			print("[dev] le toca a %s (no es el que espero): defiende" % p._player.nombre)
			p._accion_defender()
			pasados += 1
			await _esperar(0.5)
			t_t += 0.5
			continue
		await _esperar(0.1)
		t_t += 0.1
	if not (p._state == p.State.WAITING_PLAYER and p._player == p._aliados[0]):
		print("[dev] sin mi turno: estado %s, turno de %s" % [str(p._state), p._player.nombre if p._player != null else "-"])
	await _esperar(0.3)
	_ok(p._state == p.State.WAITING_PLAYER and p._player == p._aliados[0], "llega mi turno (%.1f s; pase %d de otro mio)" % [t_t, pasados])
	_ok(Combatant.ve_sombras and apa != null and not apa.no_elegible(), "en mi turno puedo elegir al escondido")
	var cu_a: Node2D = t.cuerpo_de(apa) if apa != null else null
	_ok(cu_a != null and cu_a.visible, "y se le ve (a medias)")


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
