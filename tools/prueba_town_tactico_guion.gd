# PRUEBA DEL COMBATE EN EL MAPA CON DOS JUGADORES, guion de A. El caso de su playtest del 23/09:
# la arena la lleva la SALA (los bichos no son de A ni de B), la pelea la EJECUTA ella y los dos la vemos en
# espejo; B se une a ella.
#   1) los dos entran en la arena; pongo dos bichos
#   2) abro la pelea: tiene que ser EN EL MAPA; B se une y la ve EN EL MAPA tambien (espejo tactico)
#   3) turnos: en el mio ando y B ve moverse a mi personaje; en el de un bicho, el bicho anda y B lo ve
#      moverse (su dueña es la sala: se le ha contado); en el de B, B anda en SU maquina y a mi
#      me llega su posicion sellada con su accion
# POR LA SALA (fase 2, paso 6): A y B entran como clientes en la sala de la RANURA 87 (ver prueba_town_sala_comun.gd).
extends "res://tools/prueba_town_sala_comun.gd"


func _ready() -> void:
	prefijo = ""
	slot = 87
	puerto = 24611
	registro_b = "user://logs/prueba_tactico_b.log"
	escribir_fase(0)
	if not await empezar("prueba_town_tactico_b"):
		await _fin()
		return

	# 1) LA ARENA, los dos.
	Game.entrar_arena_de_pruebas()
	escribir_fase(1)
	var t := 0.0
	while (Net._mi_lugar != "piso:%d" % Game.PISO_ARENA or piso_de_b() != Game.PISO_ARENA) and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(piso_de_b() == Game.PISO_ARENA, "los dos estamos en la arena (%.1f s)" % t)
	var dueno_arena: int = int(dato_sala("dueno_piso_%d" % Game.PISO_ARENA))
	print("[dev] la arena la lleva el peer %d (1 = la sala)" % dueno_arena)
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var slime := "res://scenes/actors/enemy/slime.tres"
	Net.pisos.pedir_spawn_arena(slime, yo.global_position + Vector2(0, 130), {})
	Net.pisos.pedir_spawn_arena(slime, yo.global_position + Vector2(90, 150), {})
	t = 0.0
	while Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() < 2 and t < 15.0:
		await _esperar(0.25)
		t += 0.25

	# 2) LA PELEA, en el mapa. La EJECUTA LA SALA y yo la veo en espejo, como B.
	await pelear_con(enemigo_libre())
	var p: Node = pantalla()
	t = 0.0
	while (p == null or not is_instance_valid(p)) and t < 10.0:
		await _esperar(0.25)
		t += 0.25
		p = pantalla()
	_ok(p != null and bool(p.tactico), "la pelea se abre EN EL MAPA")
	_ok(p != null and Net.peleas.espejando() and Net.peleas.ejecutor_de(Net.peleas._pelea_sigo) == 1,
		"la pelea la ejecuta la SALA (pelea %d) y yo la veo en espejo" % Net.peleas._pelea_sigo)
	_ok(Game.pelea_tactica_en_curso(), "con su arena montada en mi mapa")
	if p == null or not bool(p.tactico):
		await _fin()
		return
	var id_bicho: int = 0
	for e in p._enemies:
		var cb0: Node2D = p.turno_mapa.cuerpo_de(e)
		if cb0 != null and cb0.has_meta("net_id"):
			id_bicho = int(cb0.get_meta("net_id"))
			break
	_ok(id_bicho != 0, "encuentro el cuerpo del bicho de la pelea en mi mapa")
	escribir_fase(2, [id_bicho])
	var aliados_antes: int = p._aliados.size()
	_vigilar_cuerpos_b(p)
	var tm = p.turno_mapa
	var sentido := ["move_left", "move_up", "move_right"]
	# (En un diccionario: las lambdas capturan por valor.)
	var st := {"vuelta": 0, "yo": 0.0}
	# Mis turnos: andar y Defender (si no, el ATB se para en el mio y B no entra nunca).
	var turno_mio := func() -> void:
		if is_instance_valid(p) and int(p._state) == 1 and tm._fase == tm.Fase.MOVIENDO and not caja_abierta(p):
			var cuerpo: Node2D = tm._cuerpo
			var antes: Vector2 = cuerpo.global_position
			var tecla: String = sentido[int(st["vuelta"]) % sentido.size()]
			st["vuelta"] = int(st["vuelta"]) + 1
			Input.action_press(tecla)
			await _esperar(0.8)
			Input.action_release(tecla)
			var d: float = cuerpo.global_position.distance_to(antes)
			print("[dev] mi turno (%s): ando %.1f px (radio %.1f)" % [tm._quien.nombre, d, tm._radio])
			st["yo"] = maxf(float(st["yo"]), d)
			pulsar(3)
	# (11/10) B esta a mi lado: la zona le pilla dentro y entra SOLO al empezar (Game.zona_ajena), asi que puede
	# estar ya dentro antes de contar. Se mira que este, no que entre despues.
	t = 0.0
	while not _b_en_pelea(p) and t < 40.0:
		await turno_mio.call()
		await _esperar(0.25)
		t += 0.25
	_ok(_b_en_pelea(p), "B se une a la pelea (%.1f s; aliados al abrir %d)" % [t, aliados_antes])
	_ok(await _dato_de_b("espejo_tactico", 20.0) == 1, "B ve la pelea EN EL MAPA (su espejo es tactico)")

	# 2b) LO QUE ESTA DENTRO DE LA ARENA, PELEA: aparece un slime en una esquina de la arena, lejos de todos.
	var rect_a: Rect2 = tm._arena().rect
	var enemigos_antes: int = p._enemies.size()
	Net.pisos.pedir_spawn_arena(slime, rect_a.position + rect_a.size * 0.12, {})
	t = 0.0
	while p._enemies.size() <= enemigos_antes and t < 15.0:
		await turno_mio.call()
		await _esperar(0.25)
		t += 0.25
	_ok(p._enemies.size() > enemigos_antes, "un enemigo que aparece DENTRO de la arena entra a la pelea (%.1f s)" % t)

	# 3) LOS TURNOS: ando en los mios, y miro moverse a B y a los bichos (los mueve la sala).
	var cuerpo_b: Node2D = Game.cuerpo_de_red(_b(), 0)
	var b_desde: Vector2 = cuerpo_b.global_position if cuerpo_b != null else Vector2.ZERO
	var b_max := 0.0
	var bichos_desde: Dictionary = {}
	var bicho_max := 0.0
	var t0: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - t0) < 90000 and not (float(st["yo"]) > 10.0 and bicho_max > 5.0 and b_max > 10.0):
		if not is_instance_valid(p) or p.acabada():
			break
		for e in p._enemies:
			var cn: Node2D = tm.cuerpo_de(e)
			if cn != null and not bichos_desde.has(cn):
				bichos_desde[cn] = cn.global_position
		for cb in bichos_desde:
			if is_instance_valid(cb):
				bicho_max = maxf(bicho_max, (cb as Node2D).global_position.distance_to(bichos_desde[cb]))
		if is_instance_valid(cuerpo_b):
			b_max = maxf(b_max, cuerpo_b.global_position.distance_to(b_desde))
		await turno_mio.call()
		await _esperar(0.1)
	_ok(float(st["yo"]) > 10.0, "en mi turno ando (%.1f px)" % float(st["yo"]))
	_ok(bicho_max > 5.0, "veo andar a los bichos que mueve la sala (%.1f px)" % bicho_max)
	_ok(b_max > 10.0, "veo andar a B (%.1f px)" % b_max)

	# 3b) (10/10, el playtest del 09/10: "se llevaba el golpe Daniel y salia en o cerca de Agirato") CADA PERSONAJE DE B
	#     tiene SU cuerpo en mi pantalla (el lider el avatar, el compañero el suyo) y esta donde B dice que esta.
	if is_instance_valid(p):
		var lider_b = Net._avatares.get(_b())
		var comps_b: Array = Net._avatares_comp.get(_b(), [])
		for c in p._aliados:
			var fila: Dictionary = {}
			var idx: int = p._aliados.find(c)
			var filas: Array = tm.roster_red.get("aliados", [])
			if idx < filas.size():
				fila = filas[idx]
			if int(fila.get("peer", 0)) != _b():
				continue
			var cb: Node2D = tm.cuerpo_de(c)
			var k: int = int(fila.get("cuerpo", -1))
			var que: String = "el avatar" if cb == lider_b else ("el compañero %d" % comps_b.find(cb) if comps_b.has(cb) else str(cb))
			# B apunta donde queda cada uno AL ACABAR SU TURNO; si ahora esta en mitad de otro, el que anda ya no esta en
			# el ultimo numero que apunto (20/10: salian 13-31 px "de desfase" y era solo eso; mirandolo segundo a segundo,
			# A y B le ven en el mismo sitio). Se repite con su ultimo dato hasta que acabe ese turno.
			var bx := 0
			var by := 0
			var lejos := -1.0
			var tr := 0.0
			while tr < 6.0:
				bx = await _ultimo_de_b("b_pos_x_" + c.nombre, 2.0)
				by = await _ultimo_de_b("b_pos_y_" + c.nombre, 2.0)
				lejos = cb.global_position.distance_to(Vector2(bx, by)) if cb != null and (bx != 0 or by != 0) else -1.0
				if lejos < 5.0:
					break
				await _esperar(0.5)
				tr += 0.5
			print("[dev] %s (de B, cuerpo %d): en mi pantalla es %s, en %s; B lo tiene en (%d, %d): a %.1f px" % [
				c.nombre, k, que, str(cb.global_position.round()) if cb != null else "-", bx, by, lejos])
			if lejos >= 5.0 and cb != null:
				# (22/10, sale solo con carga) ¿llega bien lo de B y el cuerpo no lo sigue, o lo que llega ya es viejo?
				print("[dev]   %s: objetivo del cuerpo %s, ultima posicion de B por la red %s, metas %s, pelea en el mapa: pos %s" % [
					c.nombre, str(cb.get("_objetivo")), str(Net._peers.get(_b(), {}).get("pos", "-")),
					str(cb.get_meta_list()), str(tm._pos.get(c, "-"))])
			_ok(cb != null and (cb == lider_b) == (k == 0) and (k <= 0 or comps_b.find(cb) == k - 1),
				"%s de B tiene SU cuerpo en mi pantalla (%s)" % [c.nombre, que])
			# Y DONDE SE PINTAN SUS GOLPES (el numero y el efecto): el sitio que da su bloque tiene que ser SU cuerpo.
			var bq: Dictionary = p._bloque_de(c)
			var r_golpe: Rect2 = tm.rect_pantalla_de_bloque(bq)
			var xf: Transform2D = p.get_viewport().get_canvas_transform()
			var r_suyo: Rect2 = tm.bulto_visual(c)
			r_suyo = Rect2(xf * r_suyo.position, r_suyo.size * xf.get_scale().abs())
			var de_quien: Combatant = tm._de_bloque(bq)
			print("[dev] %s: su golpe se pinta en %s (su cuerpo %s); su bloque es de %s; bloques %d / aliados %d" % [
				c.nombre, str(r_golpe.get_center().round()), str(r_suyo.get_center().round()),
				de_quien.nombre if de_quien != null else "nadie", p._bloques_aliados.size(), p._aliados.size()])
			_ok(de_quien == c and r_golpe.get_center().distance_to(r_suyo.get_center()) < 2.0,
				"los golpes a %s de B se pintan en SU cuerpo" % c.nombre)
			if lejos >= 0.0:
				_ok(lejos < 5.0, "%s de B esta donde B dice (a %.1f px)" % [c.nombre, lejos])

	escribir_fase(3)
	_ok(await _dato_de_b("host_se_movio", 20.0) > 10, "B ve moverse a mi personaje")
	_ok(await _dato_de_b("bicho_se_movio", 5.0) > 5, "B ve moverse al bicho (lo mueve la sala)")
	_ok(await _dato_de_b("b_radio", 5.0) > 0, "a B le llega el radio de su turno")
	await _fin()


# (10/10) CUANDO SE QUEDA SIN CUERPO un personaje de B en mi pantalla (el numero salia en su tarjeta): cada cambio, al log.
func _vigilar_cuerpos_b(p: Node) -> void:
	var antes: Dictionary = {}
	var t0: int = Time.get_ticks_msec()
	while is_instance_valid(p) and Time.get_ticks_msec() - t0 < 200000:
		var comps: Array = Net._avatares_comp.get(_b(), [])
		for c in p._aliados:
			var cb: Node2D = p.turno_mapa.cuerpo_de(c)
			var ahora: String = "SIN CUERPO" if cb == null else "con cuerpo"
			if String(antes.get(c, "")) != ahora:
				antes[c] = ahora
				print("[dev] [cuerpos] a los %d ms %s: %s (compañeros de B en mi pantalla: %d, aspectos: %d)" % [
					Time.get_ticks_msec() - t0, c.nombre, ahora, comps.size(),
					int(Net._peers.get(_b(), {}).get("comps", []).size())])
		await get_tree().process_frame


func _b_en_pelea(p: Node) -> bool:
	if not is_instance_valid(p):
		return false
	for fila in p.turno_mapa.roster_red.get("aliados", []):
		if int((fila as Dictionary).get("peer", 0)) == _b():
			return true
	return false


func _ultimo_de_b(clave: String, plazo: float) -> int:
	var t := 0.0
	while t <= plazo:
		var v := -999999
		for linea in _texto(registro_b).split("\n"):
			if linea.begins_with("[B] dato " + clave + "="):
				v = int(linea.get_slice("=", 1))
		if v != -999999:
			return v
		await _esperar(0.5)
		t += 0.5
	return 0
