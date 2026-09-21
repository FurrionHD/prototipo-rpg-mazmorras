# ============================================================
#  sala.gd  (hijo de Net: /root/Net/Sala, SOLO en el proceso de la sala)
#  LA SALA: un Godot SIN VENTANA que tiene el MUNDO COMPARTIDO abierto (fase 3). Es el anfitrion de la
#  sesion y no es ningun jugador: el que abre el mundo entra como un cliente mas, igual que su hermano,
#  y la sala sigue viva mientras quede alguien dentro aunque quien la lanzo cierre su juego.
#
#  Como se lanza (lo hace el menu de multijugador, igual que Net lanza a los trabajadores):
#     <juego> --headless -- sala <clave_mundo> <puerto> <identidad_de_quien_la_lanza>
#  La CONTRASEÑA no va en la linea de ordenes (la veria cualquiera que listara los procesos): se deja en
#  user://salas/<clave>.pedido y la sala la lee y lo borra nada mas arrancar.
#
#  Lo que cuenta hacia fuera va en user://salas/<clave>.json, que es lo que mira quien la lanzo:
#     {"estado": "arrancando" | "lista" | "error" | "unirse" | "cerrando", "puerto", "pid",
#      "humanos", "mensaje", "direcciones"}
#  Al cerrarse, lo borra.
#
#  QUIEN ES: su Identidad.id es "sala:<clave>" (no se hace pasar por nadie al saludar ni al guardar),
#  pero el CERROJO de la nube va a nombre de quien la lanzo (Identidad.id_cerrojo): es su sesion, y la
#  nube solo deja abrir el mundo a sus miembros.
#
#  SE CIERRA SOLA: sin humanos durante SEG_VACIA (o si nadie llega a entrar en SEG_ESPERA), guarda, sube,
#  suelta el cerrojo, cierra a sus trabajadores y termina.
# ============================================================
extends Node

const ARG := "sala"
const CARPETA := "user://salas"
const FPS := 20                # no hay nada que pintar: lo que corre es la red y el reloj
const SEG_VACIA := 10.0        # sin nadie dentro este rato -> se cierra
const SEG_ESPERA := 60.0       # nadie ha llegado a entrar en este rato -> se cierra

var clave: String = ""
var puerto: int = 0
var _seg_vacia := SEG_VACIA
var _seg_espera := SEG_ESPERA
var _lista := false
var _hubo_alguien := false
var _t_vacia := 0.0
var _cerrando := false
var _humanos := -1
var _direcciones: Array = []   # las publicadas al abrir: van en CADA escritura del estado, no solo en la primera


# ¿Me han lanzado como sala? Lo que va detras de "--": sala <clave> <puerto> <identidad>.
static func argumentos() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	var i := args.find(ARG)
	if i < 0 or args.size() < i + 4:
		return PackedStringArray()
	return args.slice(i + 1, i + 4)


static func ruta_estado(clave_: String) -> String:
	return "%s/%s.json" % [CARPETA, clave_]


static func ruta_pedido(clave_: String) -> String:
	return "%s/%s.pedido" % [CARPETA, clave_]


# Lo que la sala cuenta de si misma, leido desde FUERA (el menu). Vacio = no hay fichero.
static func leer_estado(clave_: String) -> Dictionary:
	var ruta := ruta_estado(clave_)
	if not FileAccess.file_exists(ruta):
		return {}
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func arrancar(args: PackedStringArray) -> void:
	clave = args[0]
	puerto = int(args[1])
	var lanza: String = args[2]
	# Plazos cambiables para las pruebas (sala_vacia=3 sala_espera=5).
	for a in OS.get_cmdline_user_args():
		if a.begins_with("sala_vacia="):
			_seg_vacia = float(a.substr(11))
		elif a.begins_with("sala_espera="):
			_seg_espera = float(a.substr(12))
	Net.soy_sala = true
	Engine.max_fps = FPS
	DirAccess.make_dir_recursive_absolute(CARPETA)
	_escribir({"estado": "arrancando"})
	print("[sala] arrancando el mundo %s en el puerto %d (lo lanza %s)" % [clave, puerto, lanza])
	# Nadie delante: fuera el menu principal.
	get_tree().change_scene_to_node(Node.new())
	Identidad.id = "sala:" + clave
	Identidad.id_cerrojo = lanza
	Game.sin_jugador = true
	Game.sala_dueno = lanza

	var contrasena := _leer_pedido()
	var r: Dictionary = await Mundos.abrir(clave, contrasena, OS.get_cmdline_user_args().has("forzar_build"))
	if not r.get("ok", false):
		_acabar({"estado": "error", "error": String(r.get("error", "")),
			"mensaje": String(r.get("mensaje", "No se pudo abrir el mundo."))})
		return
	match String(r.get("resultado", "")):
		"unirse":
			# Otro lo ha abierto justo ahora: no hay nada que llevar. Quien me lanzo se une a el.
			_acabar({"estado": "unirse", "direcciones": r.get("direcciones", []),
				"quien": String(r.get("quien", ""))})
			return
		"nuevo":
			# Mundo recien creado: se estrena VACIO (sin nadie dentro). El primero que entre se hace el
			# personaje por el camino de siempre, como quien entra por primera vez al mundo de otro.
			Game.nueva_partida()
			Game.plantilla.clear()
			Game.party.clear()
			if not Mundos.estrenar(clave):
				_acabar({"estado": "error", "mensaje": "No se pudo guardar el mundo nuevo."})
				return
		_:
			if not Mundos.cargar(clave):
				_acabar({"estado": "error", "mensaje": "No se pudo cargar el mundo."})
				return
	# Mi LUGAR no es ninguno de los del juego: asi ningun "¿estoy yo en ese piso?" del anfitrion me cuenta,
	# y a los clientes no les sale mi cuerpo (me presento con este lugar y nadie esta nunca en el).
	Net._mi_lugar = ARG
	if Net.hostear(contrasena, puerto) != OK:
		await Mundos.cerrar_y_subir()
		_acabar({"estado": "error", "mensaje": "No se pudo abrir el puerto %d (¿otro juego abierto?)." % puerto})
		return
	_lista = true
	_direcciones = r.get("direcciones", [])
	_escribir({"estado": "lista"})
	print("[sala] lista: esperando jugadores")


func _process(delta: float) -> void:
	if not _lista or _cerrando:
		return
	var n := humanos()
	if n != _humanos:
		_humanos = n
		_escribir({"estado": "lista"})
	if n > 0:
		_hubo_alguien = true
		_t_vacia = 0.0
		return
	_t_vacia += delta
	if _t_vacia >= (_seg_vacia if _hubo_alguien else _seg_espera):
		print("[sala] %s: me cierro" % ("sin nadie dentro" if _hubo_alguien else "no ha entrado nadie"))
		cerrar()


# Los HUMANOS conectados (los trabajadores no cuentan, y los que estan en la puerta si).
func humanos() -> int:
	var n := 0
	for pid in multiplayer.get_peers():
		if not Net.es_trabajador(pid):
			n += 1
	return n


# Guardar, subir, soltar el cerrojo, cerrar a los trabajadores y terminar.
func cerrar() -> void:
	if _cerrando:
		return
	_cerrando = true
	_escribir({"estado": "cerrando"})
	var r: Dictionary = await Mundos.cerrar_y_subir()
	if not r.get("ok", false):
		push_warning("[sala] al cerrar: %s" % String(r.get("mensaje", "")))
	Net.desconectar()
	_acabar({})


func _acabar(estado: Dictionary) -> void:
	if estado.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta_estado(clave)))
	else:
		_escribir(estado)
		push_warning("[sala] termino: %s" % str(estado))
	# Un respiro para que salga lo que haya en la red antes de cortar.
	await get_tree().create_timer(0.3).timeout
	get_tree().quit()


func _leer_pedido() -> String:
	var ruta := ruta_pedido(clave)
	var f := FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return ""
	var s := f.get_as_text()
	f.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))
	return s


func _escribir(campos: Dictionary) -> void:
	var d := {"puerto": puerto, "pid": OS.get_process_id(), "humanos": maxi(0, _humanos),
		"direcciones": _direcciones}
	d.merge(campos, true)
	var f := FileAccess.open(ruta_estado(clave), FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.close()
