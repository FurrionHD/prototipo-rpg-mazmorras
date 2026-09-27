# PRUEBA DEL COMBATE EN EL MAPA CON DOS JUGADORES, guion del HOST. El caso de su playtest del 23/09:
# la arena la lleva un TRABAJADOR (los bichos no son ni del host ni de B), la pelea la EJECUTA un trabajador
# de pelea (27/09) y los dos la vemos en espejo; B se une a ella.
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

	# 2) LA PELEA, en el mapa. Desde el 27/09 la EJECUTA UN TRABAJADOR DE PELEA y yo la veo en espejo, como B.
	await pelear_con(enemigo_libre())
	var p: Node = pantalla()
	t = 0.0
	while (p == null or not is_instance_valid(p)) and t < 10.0:
		await _esperar(0.25)
		t += 0.25
		p = pantalla()
	_ok(p != null and bool(p.tactico), "la pelea se abre EN EL MAPA")
	_ok(p != null and Net.peleas.espejando() and Net.es_trabajador(Net.peleas._pelea_anfitrion),
		"la pelea la ejecuta un TRABAJADOR (anfitrion=%d) y yo la veo en espejo" % Net.peleas._pelea_anfitrion)
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
	t = 0.0
	while p._aliados.size() <= aliados_antes and t < 40.0:
		await turno_mio.call()
		await _esperar(0.25)
		t += 0.25
	_ok(p._aliados.size() > aliados_antes, "B se une a la pelea (%.1f s)" % t)
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

	# 3) LOS TURNOS: ando en los mios, y miro moverse a B y a los bichos (los mueve el trabajador).
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
	_ok(bicho_max > 5.0, "veo andar a los bichos que mueve el trabajador (%.1f px)" % bicho_max)
	_ok(b_max > 10.0, "veo andar a B (%.1f px)" % b_max)

	escribir_fase(3)
	_ok(await _dato_de_b("host_se_movio", 20.0) > 10, "B ve moverse a mi personaje")
	_ok(await _dato_de_b("bicho_se_movio", 5.0) > 5, "B ve moverse al bicho (lo mueve el trabajador)")
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
