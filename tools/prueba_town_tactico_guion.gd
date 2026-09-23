# PRUEBA DEL COMBATE EN EL MAPA CON DOS JUGADORES, guion del HOST. El caso de su playtest del 23/09:
# la arena la lleva un TRABAJADOR (los bichos no son ni del host ni de B), la pelea la lleva el host
# y B se une a ella.
#   1) los dos entran en la arena; pongo dos bichos
#   2) abro la pelea: tiene que ser EN EL MAPA; B se une y la ve EN EL MAPA tambien (espejo tactico)
#   3) turnos: en el mio ando y B ve moverse a mi personaje; en el de un bicho, el bicho anda y B lo ve
#      moverse (su dueño es el trabajador: se le ha contado); en el de B, B anda en SU maquina y a mi
#      me llega su posicion sellada con su accion
extends "res://tools/prueba_town_dos_comun.gd"

const PUERTO := 24611
const REGISTRO_B := "user://logs/prueba_tactico_b.log"
var _pid_b := 0


func _ready() -> void:
	prefijo = ""
	escribir_fase(0)
	if FileAccess.file_exists(REGISTRO_B):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(REGISTRO_B))
	cargar_grupo([4, 0])
	Game.semilla_mundo = 424242
	await _esperar(0.5)
	_ok(Net.hostear("abc", PUERTO) == OK, "sala abierta")
	_pid_b = _lanzar_b()
	var t := 0.0
	while Net._num_humanos < 2 and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net._num_humanos == 2, "B entra en la sala (%.1f s)" % t)
	if Net._num_humanos < 2:
		await _fin()
		return

	# 1) LA ARENA, los dos.
	Game.entrar_arena_de_pruebas()
	escribir_fase(1)
	t = 0.0
	while (Net._mi_lugar != "piso:%d" % Game.PISO_ARENA or Net.pisos._piso_de(_b()) != Game.PISO_ARENA) and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net.pisos._piso_de(_b()) == Game.PISO_ARENA, "los dos estamos en la arena (%.1f s)" % t)
	var dueno_arena: int = int(Net._dueno_piso.get(Game.PISO_ARENA, 0))
	print("[dev] la arena la lleva el peer %d (trabajador=%s)" % [dueno_arena, str(Net.es_trabajador(dueno_arena))])
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var slime := "res://scenes/actors/enemy/slime.tres"
	Net.pisos.pedir_spawn_arena(slime, yo.global_position + Vector2(0, 130), {})
	Net.pisos.pedir_spawn_arena(slime, yo.global_position + Vector2(90, 150), {})
	t = 0.0
	while Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() < 2 and t < 15.0:
		await _esperar(0.25)
		t += 0.25

	# 2) LA PELEA, en el mapa.
	await pelear_con(enemigo_libre())
	var p: Node = pantalla()
	_ok(p != null and bool(p.tactico), "la pelea se abre EN EL MAPA")
	_ok(p != null and not Net.peleas.espejando(), "la pelea la llevo yo")
	if p == null or not bool(p.tactico):
		await _fin()
		return
	var id_bicho: int = 0
	for n in Game._active_enemies:
		if is_instance_valid(n) and n.has_meta("net_id"):
			id_bicho = int(n.get_meta("net_id"))
			break
	escribir_fase(2, [id_bicho])
	var aliados_antes: int = p._aliados.size()
	t = 0.0
	while p._aliados.size() <= aliados_antes and t < 40.0:
		# Mientras B llega, mis turnos se juegan (si no, el ATB se para en el mio y a B no le llega nunca)
		pulsar(3)
		await _esperar(0.25)
		t += 0.25
	_ok(p._aliados.size() > aliados_antes, "B se une a mi pelea (%.1f s)" % t)
	_ok(await _dato_de_b("espejo_tactico", 20.0) == 1, "B ve la pelea EN EL MAPA (su espejo es tactico)")

	# 3) LOS TURNOS.
	var yo_anduve := 0.0
	var bicho_anduvo := 0.0
	var b_sellada := false
	var tm = p.turno_mapa
	var t0: int = Time.get_ticks_msec()
	var sentido := ["move_left", "move_up", "move_right"]
	var vuelta := 0
	while (Time.get_ticks_msec() - t0) < 90000 and not (yo_anduve > 0.0 and bicho_anduvo > 0.0 and b_sellada):
		if not is_instance_valid(p) or p.acabada():
			break
		if int(p._state) == 1 and tm._fase == tm.Fase.MOVIENDO and not caja_abierta(p):
			var cuerpo: Node2D = tm._cuerpo
			var antes: Vector2 = cuerpo.global_position
			# Cada turno hacia un lado: empujando siempre hacia el mismo se llega al borde de la arena
			# y de ahi ya no se anda.
			var tecla: String = sentido[vuelta % sentido.size()]
			vuelta += 1
			Input.action_press(tecla)
			await _esperar(0.8)
			Input.action_release(tecla)
			var d: float = cuerpo.global_position.distance_to(antes)
			print("[dev] turno de %s: ando %.1f px (radio %.1f)" % [tm._quien.nombre, d, tm._radio])
			yo_anduve = maxf(yo_anduve, d)
			pulsar(3)   # Defender: cierra el turno sin matar a nadie
		elif tm._fase == tm.Fase.ACERCANDO:
			var cb: Node2D = tm._cuerpo
			var desde: Vector2 = cb.global_position
			print("[dev] se acerca %s: radio %.1f, presa a %.1f px, cuerpo %s" % [tm._quien.nombre, tm._radio,
				cb.global_position.distance_to(tm._presa.global_position) if is_instance_valid(tm._presa) else -1.0,
				cb.get_script().resource_path.get_file() if cb.get_script() else "?"])
			while tm._fase == tm.Fase.ACERCANDO:
				await _esperar(0.05)
			var d2: float = cb.global_position.distance_to(desde)
			print("[dev] un bicho se acerca %.1f px" % d2)
			bicho_anduvo = maxf(bicho_anduvo, d2)
		elif tm._fase == tm.Fase.AJENO:
			var suyo: Combatant = tm._quien
			while tm._fase == tm.Fase.AJENO:
				await _esperar(0.05)
			await _esperar(0.3)
			if tm._pos.has(suyo):
				var bx: int = await _ultimo_de_b("b_pos_x_" + suyo.nombre, 5.0)
				var by: int = await _ultimo_de_b("b_pos_y_" + suyo.nombre, 5.0)
				var mia: Vector2 = tm._pos[suyo]
				print("[dev] posicion sellada de %s: %s (B dice %d,%d)" % [suyo.nombre, str(mia.round()), bx, by])
				if mia.distance_to(Vector2(bx, by)) < 2.0:
					b_sellada = true
		await _esperar(0.1)
	_ok(yo_anduve > 10.0, "en mi turno ando (%.1f px)" % yo_anduve)
	_ok(bicho_anduvo > 5.0, "en su turno el bicho anda (%.1f px)" % bicho_anduvo)
	_ok(b_sellada, "me llega la posicion de B sellada con su accion, la misma que tiene el")

	escribir_fase(3)
	_ok(await _dato_de_b("host_se_movio", 20.0) > 10, "B ve moverse a mi personaje")
	_ok(await _dato_de_b("bicho_se_movio", 5.0) > 5, "B ve moverse al bicho (su dueño es el trabajador)")
	_ok(await _dato_de_b("b_radio", 5.0) > 0, "a B le llega el radio de su turno")
	await _fin()


func _b() -> int:
	for pid in Net._peers:
		if not Net.es_trabajador(pid):
			return pid
	return 0


func _lanzar_b() -> int:
	var args: PackedStringArray = ["--headless"]
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", ProjectSettings.globalize_path(REGISTRO_B),
		"res://tools/prueba_town_tactico_b.tscn", "--", "cliente", "127.0.0.1", str(PUERTO), "abc"])
	return OS.create_process(OS.get_executable_path(), args)


func _texto_b() -> String:
	if not FileAccess.file_exists(REGISTRO_B):
		return ""
	var f := FileAccess.open(REGISTRO_B, FileAccess.READ)
	var s := f.get_as_text()
	f.close()
	return s


func _dato_de_b(clave: String, plazo: float) -> int:
	var t := 0.0
	while t <= plazo:
		for linea in _texto_b().split("\n"):
			if linea.begins_with("[B] dato " + clave):
				return int(linea.get_slice("=", 1)) if linea.contains("=") else 1
		await _esperar(0.5)
		t += 0.5
	return 0


# El ULTIMO valor que B apunto con esa clave (la apunta en cada turno suyo).
func _ultimo_de_b(clave: String, plazo: float) -> int:
	var t := 0.0
	while t <= plazo:
		var v := -999999
		for linea in _texto_b().split("\n"):
			if linea.begins_with("[B] dato " + clave + "="):
				v = int(linea.get_slice("=", 1))
		if v != -999999:
			return v
		await _esperar(0.5)
		t += 0.5
	return 0


func _fin() -> void:
	escribir_fase(9)
	await _esperar(6.0)
	var texto := _texto_b()
	var fallos_b := 0
	for linea in texto.split("\n"):
		if linea.begins_with("[B] [PASA]") or linea.begins_with("[B] [FALLA]") or linea.begins_with("[B] RESULTADO") \
				or linea.begins_with("[B] [dev]") or linea.contains("SCRIPT ERROR"):
			print(linea)
		if linea.begins_with("[B] [FALLA]"):
			fallos_b += 1
	if not texto.contains("[B] RESULTADO"):
		_ok(false, "B no ha llegado al final de su guion")
	var pids: Array = Net._trab._pids.duplicate()
	Net.desconectar()
	await _esperar(3.0)
	if _pid_b > 0 and OS.is_process_running(_pid_b):
		OS.kill(_pid_b)
	for x in pids:
		if OS.is_process_running(x):
			OS.kill(x)
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() and fallos_b == 0 else "FALLAN %d (+%d de B)" % [fallos.size(), fallos_b])
	get_tree().quit()
