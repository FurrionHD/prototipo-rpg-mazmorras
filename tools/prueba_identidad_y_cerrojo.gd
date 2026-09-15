# PRUEBA (headless): las identidades que se multiplicaban y el cerrojo que robaba otra ventana.
#
#   godot --headless --path . --script res://tools/prueba_identidad_y_cerrojo.gd
#
# NO TOCA TUS DATOS:
#   - la identidad solo se LEE (con el arreglo, arrancar ya no escribe identidad.cfg): se comprueba que
#     el fichero sale byte a byte igual tras lanzar ocho copias del juego a la vez.
#   - el cerrojo usa un mundo de prueba con id propio dentro del almacen falso, y se borra al final.
extends SceneTree

const COPIAS := 8
var _fallos := 0


func _initialize() -> void:
	await _prueba_identidad()
	_prueba_cerrojo()
	print("FIN, %d fallo(s)" % _fallos)
	quit(1 if _fallos > 0 else 0)


func _ok(cond: bool, que: String) -> void:
	print("  %s  %s" % ["ok " if cond else "MAL", que])
	if not cond:
		_fallos += 1


# Ocho juegos arrancando A LA VEZ, como los trabajadores de pelea al abrir un mundo.
func _prueba_identidad() -> void:
	print("[identidad]")
	var ruta: String = ProjectSettings.globalize_path("user://identidad.cfg")
	var antes: PackedByteArray = FileAccess.get_file_as_bytes(ruta)
	var logs: Array = []
	var pids: Array = []
	for i in COPIAS:
		var log: String = ProjectSettings.globalize_path("user://logs/prueba_identidad_%d.log" % i)
		logs.append(log)
		var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", log, "--quit-after", "2"]
		# La mitad como TRABAJADOR, que es quien de verdad arranca en racimo.
		if i % 2 == 0:
			args.append_array(["--", "trabajador"])   # sin ip/puerto: solo marca la identidad como de trabajador
		pids.append(OS.create_process(OS.get_executable_path(), args))
	# Esperar a que acaben (con tope).
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 60000:
		var vivos := 0
		for p in pids:
			if OS.is_process_running(int(p)):
				vivos += 1
		if vivos == 0:
			break
		await create_timer(0.25).timeout
	var despues: PackedByteArray = FileAccess.get_file_as_bytes(ruta)
	_ok(antes == despues, "identidad.cfg sigue IDENTICO tras %d arranques simultaneos" % COPIAS)
	var ids: Dictionary = {}
	for log in logs:
		var txt: String = FileAccess.get_file_as_string(log)
		for linea in txt.split("\n"):
			if linea.begins_with("[identidad]"):
				# Solo el id: los trabajadores añaden "[solo lectura]" detras y eso no es otra identidad.
				ids[linea.get_slice("(", 1).get_slice(")", 0)] = linea.contains("NUEVA")
		DirAccess.remove_absolute(log)
	_ok(ids.size() == 1, "todas las copias leen la MISMA identidad (%s)" % ", ".join(ids.keys()))
	_ok(not ids.values().has(true), "ninguna estrena identidad")


func _prueba_cerrojo() -> void:
	print("[cerrojo]")
	var nube := NubeAlmacenLocal.new()
	var id: String = "prueba%018x" % (randi() % 0xffffffff)
	var yo: String = "0123456789abcdef01234567"
	nube.crear(id, "clave")
	var r1: Dictionary = nube.abrir(id, "clave", [], 999, "", false, yo)
	_ok(bool(r1.get("ok", false)), "la primera ventana abre el mundo")

	# OTRA VENTANA VIVA de este equipo: se hace pasar el cerrojo por el de un proceso que sigue abierto.
	var otro: int = OS.create_process("ping", ["-n", "30", "127.0.0.1"])
	var c: Dictionary = nube._leer_json(nube._ruta_cerrojo(id))
	c["pid"] = otro
	nube._escribir_json(nube._ruta_cerrojo(id), c)
	var r2: Dictionary = nube.abrir(id, "clave", [], 999, "", false, yo)
	_ok(String(r2.get("error", "")) == "ya_abierto", "la segunda ventana NO se lo quita (%s)" % str(r2.get("error", r2.get("resultado"))))

	# Esa ventana se ha cerrado (o colgado): el cerrojo mio se recoge como siempre.
	OS.kill(otro)
	OS.delay_msec(300)
	var r3: Dictionary = nube.abrir(id, "clave", [], 999, "", false, yo)
	_ok(bool(r3.get("ok", false)), "con la otra cerrada, se recoge el cerrojo propio")

	# Un cerrojo VIEJO sin pid (de antes del arreglo) se sigue recogiendo.
	c = nube._leer_json(nube._ruta_cerrojo(id))
	c.erase("pid")
	nube._escribir_json(nube._ruta_cerrojo(id), c)
	var r4: Dictionary = nube.abrir(id, "clave", [], 999, "", false, yo)
	_ok(bool(r4.get("ok", false)), "un cerrojo viejo sin pid se recoge")

	for ruta in [nube._ruta_cerrojo(id), nube._ruta_mundo(id), nube._ruta_save(id)]:
		if FileAccess.file_exists(ruta):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
