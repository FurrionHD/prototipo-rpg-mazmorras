# PRUEBA (Steam F2): ENTRAR A UN MUNDO POR STEAM, sin Hamachi. Dos procesos: la SALA (que entra en Steam
# como servidor de juego anonimo y publica "steam:<id>" al final de sus direcciones) y Ana (papel S del
# guion de prueba_sala_cliente_guion.gd), que se une con Mundos.unirse como un amigo de otra casa: la nube
# le da las direcciones y tiene que ir por el tunel de Steam. Echa 30 al bote y se va.
# Comprueba desde fuera: la direccion de Steam va la ULTIMA (el juego viejo solo mira la primera), Ana
# acaba bien, la sala vio llegar a alguien por el tunel, se cierra sola y el bote queda guardado en 30.
# Necesita Steam abierto (la cuenta hace de Ana). Se lanza con:
#   <godot> --headless --path . res://tools/prueba_sala_steam.tscn -- nube_local
extends Node

const Sala = preload("res://scripts/net/sala.gd")
const A_ID := "aaaaaaaaaaaaaaaaaaaaaaaa"
const PUERTO := 24596
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

	# --- Un mundo con Ana dentro ---
	Identidad.id_cerrojo = A_ID
	var clave: String = Nube.nuevo_id()
	ok((await Nube.crear_mundo(clave, CLAVE_SALA)).get("ok", false), "mundo creado (miembro: Ana)")
	Mundos._escribir_entrada(clave, {"nombre": "prueba sala steam", "mio": true, "id_nube": clave,
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
		"sala_espera=40"], "prueba_sala_steam_sala.log")
	var est: Dictionary = {}
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	ok(String(est.get("estado", "")) == "lista", "la sala esta lista")
	var dirs: Array = est.get("direcciones", [])
	ok(not dirs.is_empty() and String(dirs[-1]).begins_with("steam:"),
		"la de Steam va la ULTIMA de las direcciones: %s" % str(dirs))

	# --- Ana, por Steam ---
	var p_a := _lanzar(PackedStringArray(["res://tools/prueba_sala_cliente.tscn", "--", "cliente_sala",
		str(PUERTO), CLAVE_SALA, A_ID, "S", clave, "nube_local"]), "prueba_sala_steam_S.log")
	var t := 0.0
	while (OS.is_process_running(p_a) or OS.is_process_running(p_sala)) and t < 150.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	ok(not OS.is_process_running(p_a), "Ana ha terminado")
	ok(not OS.is_process_running(p_sala), "la sala se ha cerrado sola al irse Ana")
	for pid in [p_a, p_sala]:
		if OS.is_process_running(pid):
			OS.kill(pid)

	var txt := _registro("prueba_sala_steam_S.log")
	for linea in txt.split("\n"):
		if linea.begins_with("[S]"):
			print("    " + linea)
	ok(txt.contains("[S] TODO BIEN"), "Ana acaba bien")
	var txt_sala := _registro("prueba_sala_steam_sala.log")
	for linea in txt_sala.split("\n"):
		if linea.contains("[tunel]") or linea.contains("[steam]"):
			print("    sala: " + linea)
	ok(txt_sala.contains("[tunel] llega"), "la sala vio llegar a Ana por el tunel")

	var d: SaveData = SaveIO.inspeccionar_ruta(Mundos.ruta(clave)).get("datos") as SaveData
	ok(d != null and d.bote_dinero == 30, "el bote se guarda con 30 (%s)" % (str(d.bote_dinero) if d else "?"))
	Mundos.borrar(clave)
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
