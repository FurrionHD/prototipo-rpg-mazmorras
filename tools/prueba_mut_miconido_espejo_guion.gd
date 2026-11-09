# LOS FLORECIDOS EN EL ESPEJO, guion del jugador (09/11, memoria miconido-mutante, punto 1). Como en el juego: la pelea la
# lleva la SALA y yo la veo en espejo. Lo que en una pelea pasa por suerte (que caiga uno infectado) se lo pido a la sala
# con las ORDENES de su sonda (tools/sonda_sala.gd), y miro en MI pantalla:
#   1) la arena, un Aventurero florecido y dos ratas; la pelea en el mapa, en espejo
#   2) una rata cae infectada: en mi pantalla se levanta, con SETAS y el GRIS de muerto
#   3) mi compañero cae infectado: se levanta en el bando del hongo con SU muñeco (la fila del roster trae 'peer'),
#      de pie, gris y con setas
#   4) lo tumban: su muñeco vuelve a caer (no se desvanece como un bicho) y las setas se van
#   (MICONIDO_CAPTURA=<ruta sin .png> y con ventana: la foto de MI pantalla con los dos florecidos)
extends "res://tools/prueba_town_sala_comun.gd"

const ORDEN := "user://sonda_orden.txt"
const MICONIDO := "res://scenes/actors/enemy/miconido.tres"
const RATA := "res://scenes/actors/enemy/rata.tres"
const COMPANERO := "Catalardio"   # el segundo de GRUPO_A
var _n_orden := 0


func _ready() -> void:
	prefijo = ""
	slot = 85
	puerto = 24619
	if FileAccess.file_exists(ORDEN):
		DirAccess.remove_absolute(_ruta(ORDEN))
	if not preparar_mundo(GRUPO_A, CASA_A, GRUPO_B, CASA_B) or not await abrir_sala_y_entrar():
		await _acabar()
		return
	await _guion()
	await _acabar()


# Le pide algo a la sala y espera su respuesta ("" si no contesta).
func _ordenar(orden: String, nombre := "") -> String:
	_n_orden += 1
	var f := FileAccess.open(ORDEN, FileAccess.WRITE)
	f.store_string("%d %s %s" % [_n_orden, orden, nombre])
	f.close()
	var clave := "orden_%d" % _n_orden
	await hasta_sala(clave, func(v): return v != "", 10.0)
	return dato_sala(clave)


# Espera hasta 'plazo' segundos a que se cumpla 'cond' (en MI pantalla).
func _hasta(cond: Callable, plazo: float) -> float:
	var t := 0.0
	while not cond.call() and t < plazo:
		await _esperar(0.1)
		t += 0.1
	return t


func _florecidos(p: Node, nombre := "") -> Array:
	return p._enemies.filter(func(o: Combatant) -> bool:
		return o.is_alive() and o.has_status(StatusEffects.Id.FLORECIDO) and (nombre == "" or o.nombre == nombre))


func _setas_de(t, c: Combatant):
	var s = t._hongos._setas.get(c) if t._hongos != null else null
	return s if s != null and is_instance_valid(s) else null


# EL GRIS QUE SE VE: el del bicho, el self_modulate de su sprite (el dibujo es ese nodo); el del muñeco, su MODULATE, que
# es lo que heredan sus capas (09/11: miraba su self_modulate, que no baja a las capas, y pasaba con el muñeco a todo color).
func _gris_de(cu: Node2D) -> Color:
	var mu = cu.get("_muneco") if cu != null else null
	if mu is CanvasItem:
		var hay_capas: bool = (mu as Node).find_children("*", "AnimatedSprite2D", false, false).size() > 0
		return (mu as CanvasItem).modulate if hay_capas else Color.WHITE
	var spr = cu.get("_sprite") if cu != null else null
	if spr is CanvasItem:
		return (spr as CanvasItem).self_modulate
	return Color.WHITE


func _guion() -> void:
	# 1) LA ARENA Y LA PELEA
	Game.entrar_arena_de_pruebas()
	var t0 := await _hasta(func(): return Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, 40.0)
	if not _ok_y(Net._mi_lugar == "piso:%d" % Game.PISO_ARENA, "estoy en la arena (%.1f s)" % t0):
		return
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena(MICONIDO, yo.global_position + Vector2(0, 140), {"mutacion": "florecido"})
	Net.pisos.pedir_spawn_arena(RATA, yo.global_position + Vector2(90, 120), {})
	Net.pisos.pedir_spawn_arena(RATA, yo.global_position + Vector2(-90, 120), {})
	await _hasta(func(): return Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() >= 3, 15.0)
	await pelear_con(enemigo_libre())
	await _hasta(func(): return pantalla() != null, 10.0)
	var p: Node = pantalla()
	if not _ok_y(p != null and bool(p.tactico), "la pelea se abre en el mapa"):
		return
	_ok(Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la lleva la SALA y yo la veo en espejo (como en el juego)")
	await _hasta(func(): return p._enemies.size() >= 3, 10.0)
	var nombres: Array = p._enemies.map(func(o): return o.nombre)
	_ok(p._enemies.any(func(o): return o.mutacion == &"florecido"), "en mi pantalla esta el Aventurero florecido (%s)" % str(nombres))
	_ok(p._enemies.filter(func(o): return o.nombre.to_lower().contains("rata")).size() >= 1, "y alguna rata para infectar")
	_ok(await _ordenar("preparar") == "ok", "la sala les sube la vida (que la pelea no acabe sola)")
	var t = p.turno_mapa

	# 2) UNA RATA CAE INFECTADA: se levanta con setas y gris, EN MI PANTALLA
	var r := await _ordenar("florecer_bicho")
	_ok(r.begins_with("ok"), "la sala tumba a una rata infectada (%s)" % r)
	var espera := await _hasta(func(): return not _florecidos(p).is_empty() and _setas_de(t, _florecidos(p)[0]) != null, 15.0)
	var flor: Array = _florecidos(p)
	_ok(flor.size() == 1, "en mi pantalla se levanta florecida (%d, %.1f s)" % [flor.size(), espera])
	if flor.size() == 1:
		var fl: Combatant = flor[0]
		_ok(fl.nombre.to_lower().contains("rata"), "es la rata (%s)" % fl.nombre)
		var cu: Node2D = t.cuerpo_de(fl)
		_ok(cu != null and cu.visible, "tiene su cuerpo en mi mapa")
		_ok(cu != null and cu.has_meta(TacticoHongos.MARCA), "con la marca del gris de muerto")
		var mo := _gris_de(cu)
		_ok(mo.r < 0.8 and mo.g < 0.8, "y se ve apagada (self_modulate %s)" % str(mo))
		var s = _setas_de(t, fl)
		_ok(s != null and not s._plantadas.is_empty(), "le brotan setas (%d)" % (s._plantadas.size() if s != null else 0))
		_ok(cu == null or not cu.has_meta("muerto_en_pelea") or cu.modulate.a > 0.9, "y no se desvanece como un muerto")

	# 3) MI COMPAÑERO CAE INFECTADO: se levanta contra mi, con SU muñeco
	var al_e: Combatant = null
	for c in p._aliados:
		if (c as Combatant).nombre == COMPANERO:
			al_e = c
	if not _ok_y(al_e != null, "%s esta en la pelea" % COMPANERO):
		return
	var cu_al: Node2D = t.cuerpo_de(al_e)
	_ok(cu_al != null, "y tiene su muñeco en mi mapa")
	_ok(await _ordenar("florecer_aliado", COMPANERO) == "ok", "la sala tumba a %s infectado" % COMPANERO)
	espera = await _hasta(func(): return not _florecidos(p, COMPANERO).is_empty(), 15.0)
	var fps: Array = _florecidos(p, COMPANERO)
	_ok(fps.size() == 1, "en mi pantalla %s se levanta en el bando del hongo (%.1f s)" % [COMPANERO, espera])
	if fps.size() == 1:
		var fp: Combatant = fps[0]
		_ok(t.cuerpo_prestado(fp), "su fila del roster trae la direccion de un personaje (peer): %s" % str(
			t.roster_red.get("enemigos", [])[p._enemies.find(fp)] if p._enemies.find(fp) < t.roster_red.get("enemigos", []).size() else {}))
		var cu_fp: Node2D = t.cuerpo_de(fp)
		_ok(cu_fp != null and cu_fp == cu_al, "usa el MUÑECO de %s (el mismo nodo)" % COMPANERO)
		await _hasta(func(): return cu_fp != null and not cu_fp.has_meta(t.MARCA_CAIDO) and _setas_de(t, fp) != null, 10.0)
		_ok(cu_fp != null and not cu_fp.has_meta(t.MARCA_CAIDO), "y el muñeco esta DE PIE")
		_ok(cu_fp != null and cu_fp.has_meta(TacticoHongos.MARCA), "con el gris de muerto")
		var mo2 := _gris_de(cu_fp)
		_ok(mo2.r < 0.8 and mo2.g < 0.8, "que se ve (self_modulate del muñeco %s)" % str(mo2))
		var s2 = _setas_de(t, fp)
		_ok(s2 != null and not s2._plantadas.is_empty(), "y le brotan setas (%d)" % (s2._plantadas.size() if s2 != null else 0))
		# (fase 2) pelea con SU ENERGIA de jugador: su barra llega a mi pantalla
		_ok(fp.max_energy > 0.0, "su energia llega a mi pantalla (%.0f/%.0f)" % [fp.current_energy, fp.max_energy])
		await _foto(p, t)

		# 4) LO TUMBAN: el muñeco vuelve a caer
		_ok(await _ordenar("tumbar", COMPANERO) == "ok", "la sala tumba al %s florecido" % COMPANERO)
		espera = await _hasta(func(): return cu_fp != null and cu_fp.has_meta(t.MARCA_CAIDO), 15.0)
		_ok(cu_fp != null and cu_fp.has_meta(t.MARCA_CAIDO), "en mi pantalla su muñeco vuelve a caer (%.1f s)" % espera)
		await _esperar(2.0)
		_ok(cu_fp != null and cu_fp.modulate.a > 0.9, "sin desvanecerse (alfa %.2f)" % (cu_fp.modulate.a if cu_fp != null else -1.0))
		_ok(_setas_de(t, fp) == null, "y sus setas se van")
		_ok(cu_fp == null or not cu_fp.has_meta(TacticoHongos.MARCA), "y su gris tambien")
		var mo3 := _gris_de(cu_fp)
		_ok(mo3.is_equal_approx(Color.WHITE), "su muñeco vuelve a su color (%s)" % str(mo3))


# LA FOTO DE MI PANTALLA (MICONIDO_CAPTURA=<ruta sin .png>, con ventana): lo que ve el jugador.
func _foto(p: Node, t) -> void:
	var salida: String = OS.get_environment("MICONIDO_CAPTURA")
	if salida == "" or DisplayServer.get_name() == "headless":
		return
	var flor: Array = _florecidos(p)
	if flor.is_empty():
		return
	# Sin los paneles (la camara de la pelea manda y no se deja acercar): la pantalla entera sin nada encima, y al lado
	# un recorte ampliado de cada florecido, sacado de donde cae su cuerpo en la pantalla.
	var capas: Array = []
	for n in get_tree().root.find_children("*", "CanvasLayer", true, false):
		if (n as CanvasLayer).visible:
			capas.append(n)
			(n as CanvasLayer).visible = false
	await _esperar(0.5)
	var img: Image = get_tree().root.get_viewport().get_texture().get_image()
	for n in capas:
		(n as CanvasLayer).visible = true
	img.save_png(salida + "_pantalla.png")
	const LADO := 110
	const AUMENTO := 4
	var hoja := Image.create(LADO * AUMENTO * flor.size(), LADO * AUMENTO, false, img.get_format())
	for k in flor.size():
		var cu: Node2D = t.cuerpo_de(flor[k])
		if cu == null:
			continue
		var en_pantalla: Vector2 = cu.get_global_transform_with_canvas().origin
		var r := Rect2i(Vector2i(en_pantalla) - Vector2i(LADO / 2, LADO * 3 / 4), Vector2i(LADO, LADO))
		r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var trozo: Image = img.get_region(r)
		trozo.resize(r.size.x * AUMENTO, r.size.y * AUMENTO, Image.INTERPOLATE_NEAREST)
		hoja.blit_rect(trozo, Rect2i(Vector2i.ZERO, trozo.get_size()), Vector2i(k * LADO * AUMENTO, 0))
		print("[dev] foto: %s en %s" % [flor[k].nombre, str(en_pantalla)])
	hoja.save_png(salida + ".png")
	print("[dev] captura: %s.png (y %s_pantalla.png)" % [salida, salida])


# Como _fin, sin jugador B.
func _acabar() -> void:
	if FileAccess.file_exists(ORDEN):
		DirAccess.remove_absolute(_ruta(ORDEN))
	for linea in _texto(registro_sala).split("\n"):
		if linea.contains("SCRIPT ERROR") or linea.begins_with("[florecer]") or linea.begins_with("[S] dato orden_"):
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
