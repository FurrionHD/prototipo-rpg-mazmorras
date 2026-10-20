# PRUEBA (fase 2, 20/10, todo por la sala, paso 4): EL MENU PRINCIPAL ENTRA POR LA SALA. Este proceso hace de jugador
# y usa el menu de verdad (main_menu._cargar / _empezar):
#   1) Una ranura de solo guardada DENTRO del piso 2: el menu la convierte (con su copia), lanza su sala, entra y la
#      sala le devuelve a su piso. Este juego no lleva la ranura (Perfil.ranura_actual = 0).
#   2) Gano 7 monedas, "guardar y salir" (vuelve al menu PRINCIPAL) y la cargo otra vez enseguida: su sala seguia viva
#      y me reconecto a ella, con las 7.
#   3) Salgo y la sala se cierra sola: las 7 estan EN LA RANURA.
#   4) Partida nueva: el creador la guarda, el menu la convierte y entra por su sala.
# Usa las RANURAS 92 y 93 (no existen en el juego) y tu identidad.
# Se lanza con:  <godot> --headless --path . res://tools/prueba_menu_por_sala.tscn -- nube_local sala_vacia=6
extends Node

const SLOT := 93
const SLOT_NUEVA := 92
const MENU := "res://scenes/ui/main_menu.tscn"

var fallos := 0


func ok(c: bool, t: String) -> void:
	print(("  OK   " if c else "  FALLO ") + t)
	if not c:
		fallos += 1


func _esperar(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _hasta(cond: Callable, tope: float) -> bool:
	var t := 0.0
	while not cond.call() and t < tope:
		await _esperar(0.25)
		t += 0.25
	return cond.call()


func _borrar(slot: int) -> void:
	Perfil._cerrar_bd()
	PartidaBD.borrar(Perfil.ruta_bd(slot))


func _dinero_en_la_ranura(slot: int) -> int:
	var d: SaveData = Perfil._inspeccionar_bd(slot, BDFilas.Ids.new()).get("datos")
	var jd = d.jugadores.get(Identidad.id) if d != null else null
	return (jd as JugadorData).dinero if jd is JugadorData else -1


func _pid_sala(slot: int) -> int:
	return int(Mundos._SALA.leer_estado(Mundos.clave_de_ranura(slot)).get("pid", 0))


func _menu() -> Node:
	var arbol := get_tree()
	arbol.change_scene_to_file(MENU)
	await arbol.process_frame
	await arbol.process_frame
	return arbol.current_scene


# "Guardar y salir" como el menu de pausa del invitado.
func _guardar_y_salir() -> String:
	await Ventana.pedir_guardado_al_anfitrion()
	await _esperar(0.2)
	Game.limpiar_modales()
	var menu: String = Mundos.menu_al_salir()
	Net.desconectar()
	return menu


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if Nube.es_remota():
		print("Esta prueba tiene que ir con `-- nube_local` (si no, escribe en la nube de verdad).")
		get_tree().quit(1)
		return
	# Que cambiar de escena no me lleve por delante: la escena actual pasa a ser un nodo vacio, que es el que se va.
	var hueco := Node.new()
	get_tree().root.add_child.call_deferred(hueco)
	await get_tree().process_frame
	get_tree().current_scene = hueco
	Identidad.clave()
	Perfil.nube_activa = false   # ESTE juego no sube nada: lo hace la sala
	_borrar(SLOT)
	_borrar(SLOT_NUEVA)

	# --- Una ranura de solo, guardada dentro del piso 2 ---
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (ref is SaveData):
		print("FALLO: no esta tools/huellas/mundo_ref.tres")
		get_tree().quit(1)
		return
	var d: SaveData = ref
	d.mundo_compartido = false
	d.jugadores = {}
	d.trazado = SaveData.TRAZADO_ACTUAL
	d.en_mazmorra = true
	d.current_floor = 2
	d.pos_jugador = Vector2(400, 400)
	if not d.memoria_pisos.has(2):
		d.memoria_pisos[2] = {"enemigos": [], "suelo": []}
	ok(Perfil._guardar_bd(SLOT, d), "ranura de prueba hecha (dentro del piso 2)")
	Perfil._cerrar_bd()
	var dinero_antes: int = d.money

	# --- 1) Cargarla desde el menu ---
	var menu: Node = await _menu()
	menu._cargar(SLOT)
	ok(await _hasta(func(): return Net.activo and Mundos.uniendome == Mundos.clave_de_ranura(SLOT), 60.0),
		"el menu lanza su sala y entro por ella")
	ok(Perfil.es_mundo(SLOT), "la ranura esta ya en formato de mundo")
	ok(Perfil.ranura_actual == 0, "y este juego no la lleva (la lleva su sala)")
	ok(await _hasta(func(): return Net._mi_lugar == "piso:2", 60.0), "la sala me devuelve a mi piso (%s)" % Net._mi_lugar)
	ok(Game.money == dinero_antes, "con mi dinero (%d)" % Game.money)
	var pid_sala: int = _pid_sala(SLOT)
	await _esperar(2.0)

	# --- 2) Guardar y salir, y volver enseguida ---
	Game.money += 7
	var a_donde: String = await _guardar_y_salir()
	ok(a_donde == Mundos.MENU_PRINCIPAL, "al salir de mi ranura se vuelve al menu PRINCIPAL")
	menu = await _menu()
	menu._cargar(SLOT)
	ok(await _hasta(func(): return Net.activo and Net._num_humanos == 1 and Game.lider() != null \
		and Mundos.uniendome == Mundos.clave_de_ranura(SLOT), 30.0), "la cargo otra vez")
	ok(_pid_sala(SLOT) == pid_sala, "y es la MISMA sala, que seguia viva (pid %d)" % pid_sala)
	ok(await _hasta(func(): return Game.money == dinero_antes + 7, 10.0), "con las 7 monedas (%d)" % Game.money)
	await _esperar(3.0)

	# --- 3) Salir de verdad: la sala se cierra y lo mio queda en la ranura ---
	await _guardar_y_salir()
	ok(await _hasta(func(): return not OS.is_process_running(pid_sala), 40.0), "la sala se cierra sola al quedarse vacia")
	ok(_dinero_en_la_ranura(SLOT) == dinero_antes + 7, "las 7 estan EN LA RANURA (%d)" % _dinero_en_la_ranura(SLOT))

	# El registro de esta sala, aparte: la de la partida nueva lo pisa (logs/sala.log).
	var logs: String = OS.get_user_data_dir().path_join("logs")
	DirAccess.copy_absolute(logs.path_join("sala.log"), logs.path_join("prueba_menu_por_sala_sala1.log"))

	# --- 4) Partida nueva ---
	menu = await _menu()
	menu._empezar(SLOT_NUEVA, "Nueva", {})
	ok(await _hasta(func(): return Net.activo and Mundos.uniendome == Mundos.clave_de_ranura(SLOT_NUEVA) \
		and Net._mi_lugar == "pueblo", 60.0), "la partida nueva entra por su sala, al pueblo")
	ok(Perfil.es_mundo(SLOT_NUEVA), "ya en formato de mundo")
	ok(Game.lider() != null and Game.lider().nombre == "Nueva", "con mi personaje nuevo (%s)" % (
		Game.lider().nombre if Game.lider() != null else "-"))
	var pid_nueva: int = _pid_sala(SLOT_NUEVA)
	await _esperar(2.0)
	await _guardar_y_salir()
	await _hasta(func(): return not OS.is_process_running(pid_nueva), 40.0)

	for s in [SLOT, SLOT_NUEVA]:
		var bd := PartidaBD.new()
		if bd.abrir(Perfil.ruta_bd(s)):
			var pid: String = Perfil._nube_id_de(bd)
			bd.cerrar()
			if pid != "":
				await Nube.partida_borrar(pid)   # de la nube LOCAL de pruebas
		_borrar(s)
	for p in [pid_sala, pid_nueva]:
		if p > 0 and OS.is_process_running(p):
			OS.kill(p)
	print("TODO BIEN" if fallos == 0 else "%d FALLOS" % fallos)
	get_tree().quit(0 if fallos == 0 else 1)
