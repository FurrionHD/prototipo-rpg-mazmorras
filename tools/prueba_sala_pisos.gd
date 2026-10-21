# PRUEBA (fase 2, etapa 2, paso 2): LA SALA ES LA DUEÑA DE LOS PISOS. Un jugador solo, por la sala de su ranura, baja al
# piso 1: la sala lo monta y simula sus enemigos (el jugador es espejo). Sube y vuelve antes de 10 s: el piso sigue
# montado con los mismos enemigos. Sube y espera: la sala lo congela en su foto. Vuelve: lo monta desde la foto, con los
# mismos enemigos en los mismos sitios. Lo que mira el jugador va en prueba_sala_pisos_guion.gd; lo de la sala, en sus
# lineas "[S] dato" (tools/sonda_sala.gd).
# Cubre: net_pisos.gd (sala_montar, sala_vaciado, sala_reloj, sala_congelar, sala_fotos_vivas, _asegurar_dueno),
# servidor_pisos.gd, sala.gd y net_enemigos.gd (_pedir_enemigos por lugar).
# Usa la RANURA 85 (no existe en el juego) y tu identidad.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_sala_pisos.tscn -- nube_local
extends Node

const Sala = preload("res://scripts/net/sala.gd")
const SLOT := 85
const PUERTO := 24585
const CODIGO := "abc"
const LOG_SALA := "prueba_sala_pisos_sala.log"
const LOG_P := "prueba_sala_pisos_P.log"

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
	for l in [LOG_SALA, LOG_P]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join("logs/" + l))

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

	var clave: String = Mundos.clave_de_ranura(SLOT)
	DirAccess.make_dir_recursive_absolute(Sala.CARPETA)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string(CODIGO)
	f.close()
	var p_sala := _lanzar(["--", "sala", clave, str(PUERTO), Identidad.id, "nube_local", "sala_vacia=3",
		"sala_espera=30", "sonda"], LOG_SALA)
	var est: Dictionary = {}
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	ok(String(est.get("estado", "")) == "lista", "la sala esta lista (%s)" % str(est.get("mensaje", "")))

	var p_p := _lanzar(PackedStringArray(["res://tools/prueba_sala_pisos_cliente.tscn", "--", "cliente_pisos",
		str(PUERTO), CODIGO, Identidad.id, LOG_SALA, "nube_local"]), LOG_P)
	var t := 0.0
	while (OS.is_process_running(p_p) or OS.is_process_running(p_sala)) and t < 240.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	ok(not OS.is_process_running(p_p), "el jugador ha terminado")
	ok(not OS.is_process_running(p_sala), "y la sala se ha cerrado sola al quedarse vacia")
	for p in [p_p, p_sala]:
		if OS.is_process_running(p):
			OS.kill(p)
	var txt := _registro(LOG_P)
	for linea in txt.split("\n"):
		if linea.begins_with("[P]"):
			print("    " + linea)
	ok(txt.contains("[P] RESULTADO: TODO PASA"), "el jugador acaba bien")
	var sala_txt := _registro(LOG_SALA)
	ok(sala_txt.contains("[servidor] monto el piso 1"), "la sala ha montado el piso 1")
	ok(sala_txt.contains("[sala] piso 1 congelado"), "y lo ha congelado al quedarse vacio")
	ok(sala_txt.contains("[servidor] monto el piso 1 (juega como el 1) desde su foto"), "y lo ha vuelto a montar desde su foto")
	ok(not sala_txt.contains("[trabajadores] el piso 1 lo simula"), "ningun trabajador ha llevado el piso")
	ok(not sala_txt.contains("SCRIPT ERROR"), "sin errores de script en la sala")
	await Nube.partida_borrar(pid)
	_borrar_ranura()
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
