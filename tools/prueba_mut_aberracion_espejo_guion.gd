# LA ABERRACION Y SUS MUTANTES EN EL ESPEJO, guion del jugador (13/11, memoria aberracion-mutante). Como en el juego: la
# pelea la lleva la SALA y yo la veo en espejo. Miro en MI pantalla:
#   1) la arena con los dos mutantes (Masa galvanica y Ojo de la tormenta); la pelea en el mapa, en espejo
#   2) cada uno con su nombre y SU sprite de mutante (la Masa de su carpeta; el Ojo con sus anims de algo que vuela)
#   3) el escudo de la JAULA DE FARADAY (su set) llega a mi pantalla y llega como el de la Jaula, no como el de la Marea
extends "res://tools/prueba_town_sala_comun.gd"

const ORDEN := "user://sonda_orden.txt"
const ABERRACION := "res://scenes/actors/enemy/aberracion.tres"
var _n_orden := 0


func _ready() -> void:
	prefijo = ""
	slot = 91
	puerto = 24623
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


func _guion() -> void:
	# 1) LA ARENA Y LA PELEA
	Game.entrar_arena_de_pruebas()
	var t0 := await _hasta(func(): return Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, 40.0)
	if not _ok_y(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, "estoy en la arena (%.1f s)" % t0):
		return
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	# Juntos (16/11, banco b11f6647: a 160 px el Ojo, que vuela y deambula, se quedaba a veces fuera de la zona de la pelea).
	Net.pisos.pedir_spawn_arena(ABERRACION, yo.global_position + Vector2(30, 150), {"mutacion": "galvanica"})
	Net.pisos.pedir_spawn_arena(ABERRACION, yo.global_position + Vector2(-30, 150), {"mutacion": "tormenta"})
	await _hasta(func(): return Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() >= 2, 15.0)
	await pelear_con(enemigo_libre())
	await _hasta(func(): return pantalla() != null, 10.0)
	var p: Node = pantalla()
	if not _ok_y(p != null and bool(p.tactico), "la pelea se abre en el mapa"):
		return
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la lleva la SALA y yo la veo en espejo (como en el juego)")
	await _hasta(func(): return _de(p, &"galvanica") != null and _de(p, &"tormenta") != null, 15.0)
	_ok(await _ordenar("preparar") == "ok", "la sala les sube la vida (que la pelea no acabe sola)")
	var t = p.turno_mapa

	# 2) LOS DOS, CON SU NOMBRE Y SU SPRITE
	for par in [[&"galvanica", "Masa galvánica", ["idle_0", "alarido_0", "mirada_0"]],
			[&"tormenta", "Ojo de la tormenta", ["idle_0", "rayo_0", "ojo_carga_0", "ojo_0", "tentaculos_0"]]]:
		var c: Combatant = _de(p, par[0])
		_ok(c != null and c.nombre.contains(par[1]), "en mi pantalla esta: %s (%s)" % [par[1], c.nombre if c != null else "?"])
		if c == null:
			continue
		var cu: Node2D = t.cuerpo_de(c)
		_ok(cu != null and cu.visible, "%s: con su cuerpo en mi mapa" % par[1])
		var spr = cu.get("_sprite") if cu != null else null
		var sf: SpriteFrames = (spr as AnimatedSprite2D).sprite_frames if spr is AnimatedSprite2D else null
		var faltan: Array = (par[2] as Array).filter(func(a): return sf == null or not sf.has_animation(StringName(a)))
		_ok(faltan.is_empty(), "%s: con sus anims (faltan %s)" % [par[1], str(faltan)])
		var de := _origen(sf, &"idle_0")
		_ok(de.contains("aberracion_sdf_%s" % String(par[0])), "%s: el sprite es SUYO (%s)" % [par[1], de])

	# 3) EL ESCUDO DE LA JAULA DE FARADAY
	var r := await _ordenar("escudo_jaula")
	if _ok_y(r.begins_with("ok:"), "la sala le pone el escudo de la Jaula a uno de los mios (%s)" % r):
		var quien := r.substr(3)
		var al: Combatant = null
		for c in p._aliados:
			if (c as Combatant).nombre == quien:
				al = c
		var t_e := await _hasta(func(): return al != null and al.runa_escudo_agua > 0.0, 10.0)
		_ok(al != null and is_equal_approx(al.runa_escudo_agua, 50.0), "el escudo llega a mi pantalla (%.1f s, %.1f)"
			% [t_e, al.runa_escudo_agua if al != null else -1.0])
		_ok(al != null and al.escudo_es_jaula(), "y llega como el de la Jaula, no como el de la Marea")


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
