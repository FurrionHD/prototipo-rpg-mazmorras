# PRUEBA (fase 3, F3.1): LA SALA arranca y guarda SIN JUGADOR.
# Crea un mundo de prueba con dos jugadores dentro (yo y "otro"), lanza la sala como proceso aparte
# (con el almacen local: `nube_local`) y comprueba:
#   - que abre y avisa "lista" en user://salas/<clave>.json,
#   - que, sin que entre nadie, se cierra sola: guarda, suelta el cerrojo y borra su fichero,
#   - que el save conserva a LOS DOS jugadores intactos, sin ninguna entrada "sala:" ni dueños cambiados,
#   - y que no ha tocado identidad.cfg.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_sala.tscn -- nube_local
extends Node

const Sala = preload("res://scripts/net/sala.gd")
const OTRO := "0123456789abcdef01234567"
const PUERTO := 24599

var fallos := 0

func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Nube.es_remota():
		print("Esta prueba tiene que ir con `-- nube_local` (si no, escribe en la nube de verdad).")
		get_tree().quit(1)
		return
	var yo: String = Identidad.id
	var t_identidad: int = FileAccess.get_modified_time(Identidad.RUTA)

	# --- Un mundo con dos jugadores dentro ---
	var clave: String = Nube.nuevo_id()
	var r: Dictionary = await Nube.crear_mundo(clave, "clave")
	ok(r.get("ok", false), "mundo creado en el almacen local")
	Mundos._escribir_entrada(clave, {"nombre": "prueba sala", "mio": true, "id_nube": clave,
		"contrasena": "clave", "direccion": "", "fecha": "", "cab": ""})
	Game.nueva_partida("Ana", {})
	var otro := JugadorData.new()
	otro.id = OTRO
	otro.nombre_visible = "Otro"
	var pj := PersonajeData.new()
	pj.nombre = "Berto"
	pj.dueno = OTRO
	pj.es_original = true
	Game.asegurar_uid(pj)
	otro.personajes = [pj]
	otro.equipo = [pj]
	otro.dinero = 77
	Game.jugadores_mundo[OTRO] = otro
	ok(Mundos.estrenar(clave), "mundo escrito en disco con Ana (yo) y Berto (otro)")
	Mundos.abandonar()

	# --- Lanzar la sala ---
	DirAccess.make_dir_recursive_absolute(Sala.CARPETA)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string("clave")
	f.close()
	var args: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", OS.get_user_data_dir().path_join("logs/sala_prueba.log"),
		"--", "sala", clave, str(PUERTO), yo, "nube_local", "sala_espera=4"]
	var pid := OS.create_process(OS.get_executable_path(), args)
	ok(pid > 0, "sala lanzada (pid %d)" % pid)

	var est: Dictionary = {}
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	ok(String(est.get("estado", "")) == "lista", "la sala avisa que esta lista: %s" % str(est))
	ok(int(est.get("puerto", 0)) == PUERTO and int(est.get("humanos", -1)) == 0, "en su puerto y sin nadie dentro")
	ok(not FileAccess.file_exists(Sala.ruta_pedido(clave)), "la contraseña ya no esta en disco")

	# --- Sin nadie, se cierra sola ---
	for i in 300:
		await get_tree().create_timer(0.1).timeout
		if not OS.is_process_running(pid):
			break
	ok(not OS.is_process_running(pid), "se ha cerrado sola al no entrar nadie")
	ok(Sala.leer_estado(clave).is_empty(), "y ha borrado su fichero de estado")
	var e: Dictionary = await Nube.consultar(clave, "clave")
	ok(e.get("ok", false) and not e.get("abierto", true) and e.get("tiene_save", false),
		"el cerrojo esta suelto y la partida subida")

	# --- El save, intacto ---
	var info: Dictionary = SaveIO.inspeccionar_ruta(Mundos.ruta(clave))
	var d: SaveData = info.get("datos") as SaveData
	ok(d != null, "el save se puede leer")
	if d != null:
		var claves: Array = d.jugadores.keys().map(func(k): return String(k))
		claves.sort()
		var esperadas: Array = [yo, OTRO]
		esperadas.sort()
		ok(claves == esperadas, "dentro estan exactamente yo y el otro: %s" % str(claves))
		var mio = d.jugadores.get(yo)
		var suyo = d.jugadores.get(OTRO)
		ok(mio is JugadorData and (mio as JugadorData).personajes.size() == 1
			and ((mio as JugadorData).personajes[0] as PersonajeData).nombre == "Ana"
			and String(((mio as JugadorData).personajes[0] as PersonajeData).dueno) == yo,
			"Ana sigue siendo mia")
		ok(suyo is JugadorData and ((suyo as JugadorData).personajes[0] as PersonajeData).nombre == "Berto"
			and String(((suyo as JugadorData).personajes[0] as PersonajeData).dueno) == OTRO
			and (suyo as JugadorData).dinero == 77, "Berto sigue siendo del otro, con su dinero")
		ok(d.nombre == "Ana", "la cabecera sale de quien la lanzo (%s)" % d.nombre)
	ok(FileAccess.get_modified_time(Identidad.RUTA) == t_identidad, "identidad.cfg sin tocar")

	Mundos.borrar(clave)
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
