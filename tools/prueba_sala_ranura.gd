# PRUEBA (fase 2, 20/10, todo por la sala, paso 2): LA SALA ABRE TU RANURA. Toda partida va por la sala, tambien la de
# solo; la ranura se convierte a formato de mundo (Perfil.convertir_a_mundo) y su sala la abre como "ranura_<n>": la
# misma BD de la ranura, sin cerrojo de la nube de mundos (uno de fichero) y subiendo a tu nube PERSONAL.
# Tres cosas desde fuera: el jugador entra con lo de su ranura, lo que gana se guarda EN LA RANURA, y la sala lo sube
# a la nube personal (la local de pruebas). Al irse, la sala se cierra sola y suelta su cerrojo.
# Usa la RANURA 95 (no existe en el juego) y tu identidad (la sala tiene que encontrar su clave en identidad.cfg).
# Se lanza con:  <godot> --headless --path . res://tools/prueba_sala_ranura.tscn -- nube_local
extends Node

const Sala = preload("res://scripts/net/sala.gd")
const SLOT := 95
const PUERTO := 24597
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


func _dinero_en_la_ranura() -> int:
	var d: SaveData = Perfil._inspeccionar_bd(SLOT, BDFilas.Ids.new()).get("datos")
	var jd = d.jugadores.get(Identidad.id) if d != null else null
	return (jd as JugadorData).dinero if jd is JugadorData else -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Nube.es_remota():
		print("Esta prueba tiene que ir con `-- nube_local` (si no, escribe en la nube de verdad).")
		get_tree().quit(1)
		return
	Identidad.clave()   # que mi identidad tenga clave (la sala la lee de identidad.cfg para subir a mi nube)
	Perfil.nube_activa = false   # ESTE proceso no sube nada: lo hace la sala
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
	var dinero_antes: int = _dinero_en_la_ranura()
	ok(dinero_antes >= 0, "mi ficha esta en la ranura (dinero %d)" % dinero_antes)
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
		"sala_espera=30"], "prueba_sala_ranura_sala.log")
	var est: Dictionary = {}
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	ok(String(est.get("estado", "")) == "lista", "la sala esta lista (%s)" % str(est.get("mensaje", "")))
	ok(FileAccess.file_exists(Mundos.ruta_cerrojo(clave)), "y tiene puesto el cerrojo de la ranura")

	# --- Entro yo ---
	var p_r := _lanzar(PackedStringArray(["res://tools/prueba_sala_cliente.tscn", "--", "cliente_sala", str(PUERTO),
		CODIGO, Identidad.id, "R", "nube_local"]), "prueba_sala_ranura_R.log")
	var t := 0.0
	while (OS.is_process_running(p_r) or OS.is_process_running(p_sala)) and t < 150.0:
		await get_tree().create_timer(0.5).timeout
		t += 0.5
	ok(not OS.is_process_running(p_r), "el jugador ha terminado")
	ok(not OS.is_process_running(p_sala), "y la sala se ha cerrado sola al quedarse vacia")
	for p in [p_r, p_sala]:
		if OS.is_process_running(p):
			OS.kill(p)
	var txt := _registro("prueba_sala_ranura_R.log")
	for linea in txt.split("\n"):
		if linea.begins_with("[R]"):
			print("    " + linea)
	ok(txt.contains("[R] TODO BIEN"), "el jugador acaba bien")
	ok(txt.contains("[R] dato dinero_al_entrar=%d" % dinero_antes), "y entro con el dinero de mi ranura (%d)" % dinero_antes)

	# --- Lo guardado ---
	ok(not FileAccess.file_exists(Mundos.ruta_cerrojo(clave)), "la sala ha soltado el cerrojo")
	var dinero_despues: int = _dinero_en_la_ranura()
	ok(dinero_despues == dinero_antes + 25, "lo que gane esta EN LA RANURA (%d -> %d)" % [dinero_antes, dinero_despues])
	ok(Perfil.es_mundo(SLOT), "y sigue en formato de mundo")
	var lista: Dictionary = await Nube.cuenta_lista()
	var en_nube: Dictionary = lista.get("partidas", {}) if lista.get("ok", false) else {}
	var subida: bool = en_nube.has(pid) and int((en_nube[pid] as Dictionary).get("rev", 0)) > 0
	ok(subida, "la sala la ha subido a mi nube personal (partida %s)" % pid)
	await Nube.partida_borrar(pid)   # de la nube LOCAL de pruebas: que no se quede ahi
	_borrar_ranura()
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
