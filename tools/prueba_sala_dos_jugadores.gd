# PRUEBA (fase 3, F3.2): LA SALA CON DOS JUGADORES, tres procesos: la sala, A (Ana, la dueña, con
# personaje) y B (Berto, nuevo). Ver el guion de los dos en prueba_sala_cliente_guion.gd.
# Comprueba desde fuera que la sala sigue con B cuando A se va, que al irse B se cierra sola, y que el
# save guarda a los dos con lo que hicieron: A 70 monedas, B 10, el bote 20.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_sala_dos_jugadores.tscn -- nube_local
extends Node

const Sala = preload("res://scripts/net/sala.gd")
const A_ID := "aaaaaaaaaaaaaaaaaaaaaaaa"
const B_ID := "bbbbbbbbbbbbbbbbbbbbbbbb"
const PUERTO := 24598
const CLAVE_SALA := "clave"

var fallos := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


func _lanzar(args: PackedStringArray, log_: String) -> int:
	var base: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", OS.get_user_data_dir().path_join("logs/" + log_)]
	base.append_array(args)
	return OS.create_process(OS.get_executable_path(), base)


func _registro(log_: String) -> String:
	var f := FileAccess.open(OS.get_user_data_dir().path_join("logs/" + log_), FileAccess.READ)
	return f.get_as_text() if f != null else ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Nube.es_remota():
		print("Esta prueba tiene que ir con `-- nube_local` (si no, escribe en la nube de verdad).")
		get_tree().quit(1)
		return

	# --- Un mundo con Ana dentro (y nadie mas: este proceso no se mete) ---
	Identidad.id_cerrojo = A_ID   # el mundo es de Ana: ella es su miembro
	var clave: String = Nube.nuevo_id()
	ok((await Nube.crear_mundo(clave, CLAVE_SALA)).get("ok", false), "mundo creado (miembro: Ana)")
	Mundos._escribir_entrada(clave, {"nombre": "prueba sala 2", "mio": true, "id_nube": clave,
		"contrasena": CLAVE_SALA, "direccion": "", "fecha": "", "cab": ""})
	Game.nueva_partida()
	Game.sin_jugador = true
	Game.plantilla.clear()
	Game.party.clear()
	var ana := JugadorData.new()
	ana.id = A_ID
	ana.nombre_visible = "Ana"
	var pj := PersonajeData.new()
	pj.nombre = "Ana"
	pj.dueno = A_ID
	pj.es_original = true
	Game.asegurar_uid(pj)
	ana.personajes = [pj]
	ana.equipo = [pj]
	ana.dinero = 100
	Game.jugadores_mundo[A_ID] = ana
	Game.sala_dueno = A_ID
	ok(Mundos.estrenar(clave), "mundo escrito con Ana")
	Game.sin_jugador = false
	Mundos.abandonar()
	Identidad.id_cerrojo = ""

	# --- La sala ---
	DirAccess.make_dir_recursive_absolute(Sala.CARPETA)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string(CLAVE_SALA)
	f.close()
	var p_sala := _lanzar(["--", "sala", clave, str(PUERTO), A_ID, "nube_local", "sala_vacia=3",
		"sala_espera=30"], "prueba_sala2_sala.log")
	var est: Dictionary = {}
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	ok(String(est.get("estado", "")) == "lista", "la sala esta lista")

	# --- A entra; B un poco despues (A tiene que estar dentro para aceptarle) ---
	var args_cli := ["res://tools/prueba_sala_cliente.tscn", "--", "cliente_sala", str(PUERTO), CLAVE_SALA]
	var p_a := _lanzar(PackedStringArray(args_cli + [A_ID, "A", "nube_local"]), "prueba_sala2_A.log")
	await get_tree().create_timer(12.0).timeout
	var p_b := _lanzar(PackedStringArray(args_cli + [B_ID, "B", "nube_local"]), "prueba_sala2_B.log")

	# --- A se va antes; la sala tiene que seguir mientras B este dentro ---
	var t := 0.0
	while OS.is_process_running(p_a) and t < 150.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	ok(not OS.is_process_running(p_a), "A ha terminado")
	ok(OS.is_process_running(p_sala), "la sala sigue viva sin A (B sigue dentro)")
	t = 0.0
	while (OS.is_process_running(p_b) or OS.is_process_running(p_sala)) and t < 120.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	ok(not OS.is_process_running(p_b), "B ha terminado")
	ok(not OS.is_process_running(p_sala), "y la sala se ha cerrado sola al quedarse vacia")
	for pid in [p_a, p_b, p_sala]:
		if OS.is_process_running(pid):
			OS.kill(pid)

	# --- Lo que dicen los jugadores ---
	for rol in ["A", "B"]:
		var txt := _registro("prueba_sala2_%s.log" % rol)
		for linea in txt.split("\n"):
			if linea.begins_with("[%s]" % rol):
				print("    " + linea)
		ok(txt.contains("[%s] TODO BIEN" % rol), "el jugador %s acaba bien" % rol)

	# --- El save ---
	var e: Dictionary = await Nube.consultar(clave, CLAVE_SALA)
	ok(e.get("ok", false) and not e.get("abierto", true), "el cerrojo esta suelto")
	var d: SaveData = SaveIO.inspeccionar_ruta(Mundos.ruta(clave)).get("datos") as SaveData
	ok(d != null, "el save se puede leer")
	if d != null:
		var claves: Array = d.jugadores.keys().map(func(k): return String(k))
		claves.sort()
		ok(claves == [A_ID, B_ID], "dentro estan Ana y Berto y nadie mas: %s" % str(claves))
		var ja = d.jugadores.get(A_ID)
		var jb = d.jugadores.get(B_ID)
		ok(ja is JugadorData and (ja as JugadorData).dinero == 70, "Ana guardada con 70 monedas (%s)" %
			(str((ja as JugadorData).dinero) if ja is JugadorData else "?"))
		ok(jb is JugadorData and ((jb as JugadorData).personajes[0] as PersonajeData).nombre == "Berto"
			and (jb as JugadorData).dinero == 10, "Berto guardado, con sus 10 monedas")
		ok(d.bote_dinero == 20, "el bote se queda en 20 (%d)" % d.bote_dinero)
	Mundos.borrar(clave)
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
