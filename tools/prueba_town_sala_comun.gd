# LO QUE COMPARTEN LAS PRUEBAS town_* POR LA SALA (fase 2, 20/10, todo por la sala, paso 6), del lado de A, el proceso
# de la prueba. Ya no es el anfitrion: como en el juego, la partida la lleva su sala y A entra como un cliente mas.
#   1) preparar_mundo: una ranura temporal hecha de mundo_ref y convertida (Perfil.convertir_a_mundo), con A (tu
#      identidad) y B (IDENT_B) ya dentro, cada uno con su grupo. Asi B entra directo, sin pedir permiso.
#   2) abrir_sala_y_entrar: lanza su sala (con la sonda, ver tools/sonda_sala.gd) y A entra por 127.0.0.1.
#   3) lanzar_b: B entra por la misma sala (ver entrar_en_la_sala en prueba_town_dos_comun.gd).
# Lo que se miraba dentro del anfitrion se lee del registro de la sala (lineas "[S] dato ..."): dato_sala.
# Se lanzan con:  <godot> --headless --path . res://tools/prueba_town_<...>.tscn -- nube_local
extends "res://tools/prueba_town_dos_comun.gd"

const Sala = preload("res://scripts/net/sala.gd")
const CODIGO := "abc"
const IDENT_B := "prueba_town_b"
const GRUPO_A := ["Agirato ochinan", "Catalardio"]
const CASA_A := "Dawnsin"
const GRUPO_B := ["Dasui", "Daniel"]
const CASA_B := "Pruebas locas"

var slot := 0
var puerto := 0
var registro_b := ""          # user://logs/...
var registro_sala := ""
var falta_b := 0              # lo que da _dato_de_b si B no lo apunta en plazo
var uid_casa := {}            # "a"/"b" -> uid de su personaje de casa (no va en el equipo)
var _pid_sala := 0
var _pid_b := 0
var _peer_b := 0
var _nube_id := ""
var _entrado := false


func _ruta(log_: String) -> String:
	return ProjectSettings.globalize_path(log_)


func _lanzar(args: PackedStringArray, log_: String) -> int:
	var base: PackedStringArray = ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--log-file", _ruta(log_)]
	base.append_array(args)
	return OS.create_process(OS.get_executable_path(), base)


func _borrar_ranura() -> void:
	Perfil._cerrar_bd()
	PartidaBD.borrar(Perfil.ruta_bd(slot))


# La ranura de la prueba, con A y B dentro. 'grupo_*' (dos personajes cada uno, el cupo de dos humanos) y 'casa_*' (uno
# que no va en el equipo) son NOMBRES de mundo_ref: el orden de su plantilla cambia segun como se cargue. Los de
# siempre (los de cargar_grupo): GRUPO_A/CASA_A y GRUPO_B/CASA_B. Ojo con Dawnsin: es un personaje enorme que acaba
# las peleas antes de que a los demas les llegue un turno. 'retocar' cambia el SaveData antes de convertirlo.
func preparar_mundo(grupo_a: Array, casa_a: String, grupo_b: Array, casa_b: String, retocar := Callable()) -> bool:
	if Nube.es_remota():
		print("Esta prueba tiene que ir con `-- nube_local` (si no, escribe en la nube de verdad).")
		return false
	registro_sala = "user://logs/prueba_ranura_%d_sala.log" % slot
	for r in [registro_b, registro_sala]:
		if FileAccess.file_exists(r):
			DirAccess.remove_absolute(_ruta(r))
	Identidad.clave()
	Perfil.nube_activa = false
	_borrar_ranura()
	var ref = ResourceLoader.load("res://tools/huellas/mundo_ref.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	if not (ref is SaveData):
		_ok(false, "esta tools/huellas/mundo_ref.tres")
		return false
	var d: SaveData = ref
	d.mundo_compartido = false
	d.jugadores = {}
	d.en_mazmorra = false
	d.trazado = SaveData.TRAZADO_ACTUAL
	d.semilla_mundo = 424242
	if retocar.is_valid():
		retocar.call(d)
	_ok(Perfil._guardar_bd(slot, d), "ranura de prueba hecha (%d)" % slot)
	Perfil._cerrar_bd()
	if not _ok_y(Perfil.convertir_a_mundo(slot).get("ok", false), "convertida a formato de mundo"):
		return false

	# Los dos jugadores, con su grupo. convertir_a_mundo deja la ranura cargada en Game: de ahi salen sus fichas.
	var pl := {}
	for pj in Game.plantilla:
		pl[(pj as PersonajeData).nombre] = pj
	for n in grupo_a + [casa_a] + grupo_b + [casa_b]:
		if not pl.has(n):
			_ok(false, "%s esta en mundo_ref" % n)
			return false
	var de_b: Array = (grupo_b + [casa_b]).map(func(n): return pl[n])
	uid_casa["a"] = String((pl[casa_a] as PersonajeData).uid)
	uid_casa["b"] = String((pl[casa_b] as PersonajeData).uid)
	var ident_a: String = Identidad.id
	Game.party.assign(grupo_a.map(func(n): return pl[n]))
	Game.lider_idx = 0
	var jd_a: JugadorData = Game._mi_jugador_data(false, null)   # con toda la plantilla: su baul no se lleva lo de B
	jd_a.personajes = jd_a.personajes.filter(func(pj): return not de_b.has(pj))
	Identidad.id = IDENT_B
	Game.party.assign(grupo_b.map(func(n): return pl[n]))
	var jd_b: JugadorData = Game._mi_jugador_data(false, null)
	Identidad.id = ident_a
	jd_b.personajes = de_b
	jd_b.nombre_visible = "B"
	jd_b.baul = []
	for pj in jd_a.personajes:
		(pj as PersonajeData).dueno = ident_a
	var ids := BDFilas.Ids.new()
	Perfil._abrir_bd(slot)
	var datos: SaveData = Perfil._inspeccionar_bd(slot, ids).get("datos")
	datos.jugadores = {ident_a: jd_a, IDENT_B: jd_b}
	Perfil._ids = ids
	_ok(Perfil._guardar_bd(slot, datos), "A y B dentro de la ranura")
	_nube_id = Perfil._nube_id_de(Perfil._bd)
	Perfil._cerrar_bd()
	Perfil.ranura_actual = 0
	return fallos.is_empty()


# Los tres pasos seguidos: la ranura, su sala con A dentro y B. Devuelve si estan los dos.
func empezar(escena_b: String, retocar := Callable(), grupo_a := GRUPO_A, casa_a := CASA_A, grupo_b := GRUPO_B,
		casa_b := CASA_B) -> bool:
	if not preparar_mundo(grupo_a, casa_a, grupo_b, casa_b, retocar):
		return false
	if not await abrir_sala_y_entrar():
		return false
	return await lanzar_b(escena_b)


func _ok_y(c: bool, t: String) -> bool:
	_ok(c, t)
	return c


# Lanza la sala de la ranura y A entra en ella, al pueblo. Escribe la fase 0 con lo que B necesita saber de A.
func abrir_sala_y_entrar() -> bool:
	var clave: String = Mundos.clave_de_ranura(slot)
	DirAccess.make_dir_recursive_absolute(Sala.CARPETA)
	var f := FileAccess.open(Sala.ruta_pedido(clave), FileAccess.WRITE)
	f.store_string(CODIGO)
	f.close()
	_pid_sala = _lanzar(["--", "sala", clave, str(puerto), Identidad.id, "nube_local", "sala_vacia=3",
		"sala_espera=30", "sonda"], registro_sala)
	var est: Dictionary = {}
	for i in 400:
		await _esperar(0.1)
		est = Sala.leer_estado(clave)
		if String(est.get("estado", "")) in ["lista", "error"]:
			break
	if not _ok_y(String(est.get("estado", "")) == "lista", "la sala esta lista (%s)" % str(est.get("mensaje", ""))):
		return false
	Net.partida.entrada_lista.connect(func():
		var arbol := get_tree()
		arbol.change_scene_to_file("res://scenes/levels/town.tscn")
		await arbol.process_frame
		Net.anunciar_lugar("pueblo")
		_entrado = true)
	_ok(Net.unirse("127.0.0.1", CODIGO, puerto, true) == OK, "me conecto a la sala")
	var t := 0.0
	while not _entrado and t < 60.0:
		await _esperar(0.25)
		t += 0.25
	if not _ok_y(_entrado, "entro en el mundo con mi grupo (%.1f s)" % t):
		return false
	print("[dev] mi grupo: ", ", ".join(Game.party.map(func(p): return p.nombre)))
	escribir_fase(0, [multiplayer.get_unique_id(), uid_casa["a"]])
	return true


# B entra por la misma sala. Devuelve si ha entrado (los dos humanos dentro, segun la sala).
func lanzar_b(escena: String) -> bool:
	_pid_b = _lanzar(PackedStringArray(["res://tools/%s.tscn" % escena, "--", "cliente", "127.0.0.1", str(puerto),
		CODIGO, IDENT_B, "nube_local"]), registro_b)
	_ok(_pid_b > 0, "jugador B lanzado")
	var t := 0.0
	while (Net._num_humanos < 2 or _b() == 0) and t < 40.0:
		await _esperar(0.5)
		t += 0.5
	return _ok_y(Net._num_humanos == 2 and _b() != 0, "B entra en la sala (%.1f s)" % t)


# El peer de B (lo apunta el al entrar).
func _b() -> int:
	if _peer_b == 0:
		_peer_b = int(_linea(_texto(registro_b), "[B] dato mi_peer", "0"))
	return _peer_b


func _texto(ruta: String) -> String:
	if not FileAccess.file_exists(ruta):
		return ""
	var f := FileAccess.open(ruta, FileAccess.READ)
	var s := f.get_as_text()
	f.close()
	return s


# El valor de la ULTIMA linea "<clave>=<valor>" (o "1" si la linea es "<clave>" sin valor), o 'si_no'.
func _linea(texto: String, clave: String, si_no: String) -> String:
	var v := si_no
	for linea in texto.split("\n"):
		if linea == clave:
			v = "1"
		elif linea.begins_with(clave + "="):
			v = linea.substr(clave.length() + 1).strip_edges()
	return v


func _hay_linea_b(clave: String) -> bool:
	return _linea(_texto(registro_b), "[B] dato " + clave, "") != ""


# Lo que B apunto como "[B] dato clave=valor" (falta_b si no aparece en el plazo). Con 'ultimo', el ultimo valor.
func _dato_de_b(clave: String, plazo: float) -> int:
	var t := 0.0
	while t <= plazo:
		var v := _linea(_texto(registro_b), "[B] dato " + clave, "")
		if v != "":
			return int(v)
		await _esperar(0.25)
		t += 0.25
	return falta_b


# Lo que la sala dice AHORA de 'clave' (su ultima linea "[S] dato clave=valor"; "" si nunca lo ha dicho).
func dato_sala(clave: String) -> String:
	return _linea(_texto(registro_sala), "[S] dato " + clave, "")


# Espera a que la sala diga de 'clave' algo que cumpla 'cond' (recibe el texto). Devuelve si llego en plazo.
func hasta_sala(clave: String, cond: Callable, plazo: float) -> bool:
	var t := 0.0
	while not cond.call(dato_sala(clave)) and t < plazo:
		await _esperar(0.25)
		t += 0.25
	return cond.call(dato_sala(clave))


# En que piso pone la sala a B (-1 si en ninguno).
func piso_de_b() -> int:
	var v := dato_sala("piso_" + IDENT_B)
	return int(v) if v != "" else -1


func es_trabajador(peer: int) -> bool:
	return peer != 0 and dato_sala("trabajadores").split(",").has(str(peer))


func _fin() -> void:
	escribir_fase(9)
	await _esperar(6.0)   # que B apunte su resultado y se vaya
	var texto := _texto(registro_b)
	var fallos_b := 0
	for linea in texto.split("\n"):
		if linea.begins_with("[B] [PASA]") or linea.begins_with("[B] [FALLA]") or linea.begins_with("[B] RESULTADO") \
				or linea.begins_with("[B] [dev]") or linea.contains("SCRIPT ERROR") or linea.begins_with("[zona ajena]"):
			print(linea)
		if linea.begins_with("[B] [FALLA]"):
			fallos_b += 1
	if not texto.contains("[B] RESULTADO"):
		_ok(false, "B no ha llegado al final de su guion")
	for linea in _texto(registro_sala).split("\n"):
		if linea.contains("SCRIPT ERROR"):
			print("[sala] ", linea)
	var pids: Array = Array(dato_sala("pids_trab").split(",", false)).map(func(x): return int(x))
	Net.desconectar()
	var t := 0.0
	while OS.is_process_running(_pid_sala) and t < 20.0:
		await _esperar(0.5)
		t += 0.5
	_ok(not OS.is_process_running(_pid_sala), "la sala se cierra sola al irnos (%.1f s)" % t)
	await _esperar(2.0)
	var vivos := pids.filter(func(x): return OS.is_process_running(x))
	_ok(vivos.is_empty(), "los trabajadores se cierran con la sala (%d vivos)" % vivos.size())
	for p in [_pid_b, _pid_sala] + pids:
		if p > 0 and OS.is_process_running(p):
			OS.kill(p)
	if _nube_id != "":
		await Nube.partida_borrar(_nube_id)   # de la nube LOCAL de pruebas: que no se quede ahi
	_borrar_ranura()
	print("[dev] RESULTADO: ", "TODO PASA" if fallos.is_empty() and fallos_b == 0 else "FALLAN %d (+%d de B)" % [fallos.size(), fallos_b])
	get_tree().quit()
