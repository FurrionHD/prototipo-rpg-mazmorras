# LA PELEA DE OTRO VISTA DESDE FUERA, CON DOS JUGADORES DE VERDAD (11/10), guion del HOST. B se queda LEJOS (fuera de
# la zona y a mas de 320 px del golpe) y yo abro una pelea en la arena:
#   - B NO se queda quieto (esta lejos) y VE mi zona en su suelo;
#   - B anda hacia mi: la linea le FRENA, le sale la pregunta y dice que SI;
#   - B entra en mi pelea.
# El caso de "B esta dentro al empezar y entra solo" lo mira ya prueba_town_tactico (B empieza a mi lado).
#   godot --headless --path . res://tools/prueba_town_zona_ajena.tscn
extends "res://tools/prueba_town_dos_comun.gd"

const PUERTO := 24613
const REGISTRO_B := "user://logs/prueba_zona_ajena_b.log"
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

	Game.entrar_arena_de_pruebas()
	escribir_fase(1)
	t = 0.0
	while (Net._mi_lugar != "piso:%d" % Game.PISO_ARENA or Net.pisos._piso_de(_b()) != Game.PISO_ARENA) and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	_ok(Net.pisos._piso_de(_b()) == Game.PISO_ARENA, "los dos estamos en la arena (%.1f s)" % t)
	await _esperar(3.0)
	var yo: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	Net.pisos.pedir_spawn_arena("res://scenes/actors/enemy/slime.tres", yo.global_position + Vector2(0, 130), {})
	t = 0.0
	while Net.enemigos._enem_nodos.size() + Net.enemigos._enemigos.size() < 1 and t < 15.0:
		await _esperar(0.25)
		t += 0.25
	var presa: Node2D = enemigo_libre()
	_ok(presa != null, "hay un slime en la arena")
	if presa == null:
		await _fin()
		return
	# B se coloca LEJOS de donde voy a pegar (pelear_con me pone a 40 px a la derecha del slime).
	var donde: Vector2 = presa.global_position + Vector2(40, 0)
	escribir_fase(2, [int(donde.x), int(donde.y)])
	_ok(await _dato_de_b("colocado", 20.0) == 1, "B se ha colocado lejos")

	await pelear_con(presa)
	var p: Node = pantalla()
	_ok(p != null and bool(p.tactico), "abro la pelea EN EL MAPA")
	if p == null:
		await _fin()
		return
	escribir_fase(3)
	_ok(not _b_en_pelea(p), "B, lejos, NO entra solo")
	_ok(await _dato_de_b("quieto_lejos", 15.0) == 0, "B, lejos, no se queda quieto al golpe")
	_ok(await _dato_de_b("ve_zona", 5.0) == 1, "B ve mi zona en su suelo")
	_ok(await _dato_de_b("frenado", 40.0) == 1, "la linea frena a B")
	_ok(await _dato_de_b("pregunta", 5.0) == 1, "a B le sale la pregunta al chocar")
	# Mientras B decide y entra, juego mis turnos (Defender) para que la pelea no se pare en el mio.
	t = 0.0
	while not _b_en_pelea(p) and t < 40.0:
		pulsar(3)
		await _esperar(0.25)
		t += 0.25
	_ok(_b_en_pelea(p), "con el Si, B entra en mi pelea (%.1f s)" % t)
	_ok(await _dato_de_b("espejo", 20.0) == 1, "B ve la pelea desde dentro (espejo)")
	await _fin()


func _b_en_pelea(p: Node) -> bool:
	if not is_instance_valid(p):
		return false
	for fila in p.turno_mapa.roster_red.get("aliados", []):
		if int((fila as Dictionary).get("peer", 0)) == _b():
			return true
	return false


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
		"res://tools/prueba_town_zona_ajena_b.tscn", "--", "cliente", "127.0.0.1", str(PUERTO), "abc"])
	return OS.create_process(OS.get_executable_path(), args)


func _texto_b() -> String:
	if not FileAccess.file_exists(REGISTRO_B):
		return ""
	var f := FileAccess.open(REGISTRO_B, FileAccess.READ)
	var s := f.get_as_text()
	f.close()
	return s


# -1 = B no lo ha apuntado en plazo.
func _dato_de_b(clave: String, plazo: float) -> int:
	var t := 0.0
	while t <= plazo:
		for linea in _texto_b().split("\n"):
			if linea.begins_with("[B] dato " + clave + "="):
				return int(linea.get_slice("=", 1))
		await _esperar(0.5)
		t += 0.5
	return -1


func _fin() -> void:
	escribir_fase(9)
	await _esperar(6.0)
	var texto := _texto_b()
	var fallos_b := 0
	for linea in texto.split("\n"):
		if linea.begins_with("[B] [PASA]") or linea.begins_with("[B] [FALLA]") or linea.begins_with("[B] RESULTADO") \
				or linea.begins_with("[B] [dev]") or linea.contains("SCRIPT ERROR") or linea.begins_with("[zona ajena]"):
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
