# PRUEBA (fase 2, 20/10, todo por la sala, paso 5): LA LAN POR LA SALA. Tu partida la lleva su sala, que entra con una
# contraseña que nadie escribe; para que entre un amigo de casa, su dueño la abre a la LAN con un codigo (Net.abrir_lan)
# y el amigo entra como en un mundo compartido: se hace su personaje DENTRO de tu partida (decision del usuario).
#   O (el dueño) abre la LAN y acepta; L (el amigo) entra con el codigo de LAN, no puede abrirla el, gana 3 y se va.
#   Antes de abrirla, con ese mismo codigo no se entra.
# Usa la RANURA 90 (no existe en el juego) y tu identidad para el dueño.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_lan_por_sala.tscn -- nube_local
extends Node

const Sala = preload("res://scripts/net/sala.gd")
const SLOT := 90
const PUERTO := 24590
const CODIGO := "abc"
const AMIGO := "prueba_lan_amigo"
const SEÑAL_LAN := "user://logs/prueba_lan_abrir.txt"

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


func _cliente(rol: String, codigo: String, ident: String) -> int:
	return _lanzar(PackedStringArray(["res://tools/prueba_sala_cliente.tscn", "--", "cliente_sala", str(PUERTO),
		codigo, ident, rol, "nube_local"]), "prueba_lan_por_sala_%s.log" % rol)


func _esperar_proceso(pid: int, tope: float) -> void:
	var t := 0.0
	while OS.is_process_running(pid) and t < tope:
		await get_tree().create_timer(0.5).timeout
		t += 0.5


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
	var pid_nube: String = Perfil._nube_id_de(bd)
	bd.cerrar()

	# --- Su sala ---
	var clave: String = Mundos.clave_de_ranura(SLOT)
	DirAccess.make_dir_recursive_absolute(Sala.CARPETA)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string(CODIGO)
	f.close()
	var p_sala := _lanzar(["--", "sala", clave, str(PUERTO), Identidad.id, "nube_local", "sala_vacia=3",
		"sala_espera=30"], "prueba_lan_por_sala_sala.log")
	var est: Dictionary = {}
	for i in 400:
		await get_tree().create_timer(0.1).timeout
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	ok(String(est.get("estado", "")) == "lista", "la sala esta lista (%s)" % str(est.get("mensaje", "")))

	# --- Entro yo (el dueño) ---
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEÑAL_LAN))
	var p_o := _cliente("O", CODIGO, Identidad.id)
	# Mientras esta cerrada a la LAN, con el codigo de LAN no se entra.
	var t := 0.0
	while not _registro("prueba_lan_por_sala_O.log").contains("[O] OK    mi partida empieza cerrada") and t < 60.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	var p_antes := _cliente("X", "casa", AMIGO + "_antes")
	await _esperar_proceso(p_antes, 100.0)   # el guion espera 60 s a entrar antes de rendirse
	if OS.is_process_running(p_antes):
		OS.kill(p_antes)
	ok(_registro("prueba_lan_por_sala_X.log").contains("[X] FALLO entro en el mundo"),
		"antes de abrirla a la LAN, con ese codigo no se entra")
	var fs := FileAccess.open(SEÑAL_LAN, FileAccess.WRITE)   # el dueño ya puede abrirla
	fs.store_string("1")
	fs.close()

	# --- La abre: entra el amigo ---
	t = 0.0
	while not _registro("prueba_lan_por_sala_O.log").contains("[O] dato lan_abierta=1") and t < 30.0:
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	var p_l := _cliente("L", "casa", AMIGO)
	await _esperar_proceso(p_l, 120.0)
	await _esperar_proceso(p_o, 60.0)
	await _esperar_proceso(p_sala, 30.0)
	ok(not OS.is_process_running(p_sala), "la sala se cierra sola al quedarse vacia")
	for p in [p_o, p_l, p_sala]:
		if OS.is_process_running(p):
			OS.kill(p)
	for rol in ["O", "L"]:
		var txt := _registro("prueba_lan_por_sala_%s.log" % rol)
		for linea in txt.split("\n"):
			if linea.begins_with("[%s]" % rol):
				print("    " + linea)
		ok(txt.contains("[%s] TODO BIEN" % rol), "%s acaba bien" % rol)
	ok(_registro("prueba_lan_por_sala_sala.log").contains("[sala] ABIERTA a la LAN"), "la sala dice que se abrio a la LAN")

	# --- El amigo se queda DENTRO de mi partida ---
	var datos: SaveData = Perfil._inspeccionar_bd(SLOT, BDFilas.Ids.new()).get("datos")
	var jd = datos.jugadores.get(AMIGO) if datos != null else null
	ok(jd is JugadorData and (jd as JugadorData).dinero == 3,
		"su personaje (y sus 3 monedas) se quedan en mi ranura (%s)" % (str((jd as JugadorData).dinero) if jd is JugadorData else "no esta"))
	ok(datos != null and datos.jugadores.has(Identidad.id), "y el mio sigue ahi")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SEÑAL_LAN))
	await Nube.partida_borrar(pid_nube)
	_borrar_ranura()
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
