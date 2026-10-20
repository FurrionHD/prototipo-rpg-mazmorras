# PRUEBA (fase 2, 20/10, todo por la sala, paso 3): CON UN SOLO HUMANO SE JUEGA COMO EL SOLO DE SIEMPRE. Toda partida
# va por la sala, tambien la de uno; y con uno solo los menus paran el mundo y la pelea, la pelea para el mapa y la
# pelea deja ir a x2 (Net.pausa_solo). Lo que mira, en el guion del jugador (prueba_solo_por_sala_guion.gd).
# Usa la RANURA 94 (no existe en el juego) y tu identidad.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_solo_por_sala.tscn -- nube_local
extends Node

const Sala = preload("res://scripts/net/sala.gd")
const SLOT := 94
const PUERTO := 24594
const CODIGO := "abc"

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


func _borrar_ranura() -> void:
	Perfil._cerrar_bd()
	PartidaBD.borrar(Perfil.ruta_bd(SLOT))


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Nube.es_remota():
		print("Esta prueba tiene que ir con `-- nube_local` (si no, escribe en la nube de verdad).")
		get_tree().quit(1)
		return
	Identidad.clave()
	Perfil.nube_activa = false
	_borrar_ranura()

	# --- Una ranura de solo, convertida ---
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (ref is SaveData):
		print("FALLO: no esta tools/huellas/mundo_ref.tres")
		get_tree().quit(1)
		return
	var d: SaveData = ref
	d.mundo_compartido = false
	d.jugadores = {}
	d.en_mazmorra = false
	d.trazado = SaveData.TRAZADO_ACTUAL
	ok(Perfil._guardar_bd(SLOT, d), "ranura de prueba hecha")
	Perfil._cerrar_bd()
	ok(Perfil.convertir_a_mundo(SLOT).get("ok", false), "convertida a formato de mundo")
	var bd := PartidaBD.new()
	bd.abrir(Perfil.ruta_bd(SLOT))
	var pid: String = Perfil._nube_id_de(bd)
	bd.cerrar()

	# --- Su sala ---
	var clave: String = Mundos.clave_de_ranura(SLOT)
	DirAccess.make_dir_recursive_absolute(Sala.CARPETA)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string(CODIGO)
	f.close()
	var p_sala := _lanzar(["--", "sala", clave, str(PUERTO), Identidad.id, "nube_local", "sala_vacia=3",
		"sala_espera=30"], "prueba_solo_por_sala_sala.log")
	var est: Dictionary = {}
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	ok(String(est.get("estado", "")) == "lista", "la sala esta lista (%s)" % str(est.get("mensaje", "")))

	# --- Entro yo, solo ---
	var p_p := _lanzar(PackedStringArray(["res://tools/prueba_solo_por_sala_cliente.tscn", "--", "cliente_solo",
		str(PUERTO), CODIGO, Identidad.id, "nube_local"]), "prueba_solo_por_sala_P.log")
	var t := 0.0
	while (OS.is_process_running(p_p) or OS.is_process_running(p_sala)) and t < 220.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	ok(not OS.is_process_running(p_p), "el jugador ha terminado")
	ok(not OS.is_process_running(p_sala), "y la sala se ha cerrado sola al quedarse vacia")
	for p in [p_p, p_sala]:
		if OS.is_process_running(p):
			OS.kill(p)
	var txt := _registro("prueba_solo_por_sala_P.log")
	for linea in txt.split("\n"):
		if linea.begins_with("[P]"):
			print("    " + linea)
	ok(txt.contains("[P] RESULTADO: TODO PASA"), "el jugador acaba bien")
	var sala_txt := _registro("prueba_solo_por_sala_sala.log")
	ok(sala_txt.contains("[sala] pausa de solo: 0 -> 2"), "la sala ha parado el mundo por un menu")
	ok(sala_txt.contains("[sala] pausa de solo: 0 -> 1"), "y el mapa por una pelea")
	await Nube.partida_borrar(pid)   # de la nube LOCAL de pruebas: que no se quede ahi
	_borrar_ranura()
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
