# ============================================================
#  trabajadores.gd  (hijo de Net: /root/Net/Trabajadores)
#  LOS TRABAJADORES DE PISO: un Godot SIN VENTANA por cada piso ocupado, que es el DUEÑO de ese piso.
#
#  Por que existen: con el dueño por piso de siempre, el piso lo simulaba el PC de uno de los jugadores
#  que estaba dentro, y cada caida, relevo o carrera entre maquinas acababa en "para uno ha pasado y
#  para el otro no". Un trabajador es un dueño que no juega, no se va a por pociones y no se cuelga
#  porque alguien abra un menu: los humanos pasan a ser TODOS espejos del piso.
#
#  COMO ENCAJA CON LO QUE YA HABIA (y por que casi no toca nada): el trabajador es un CLIENTE mas de la
#  sala, apuntado en Net._peers con "trabajador": true. Todo lo que el host reparte "a los que estan en
#  ese piso" (posiciones, corchos, peleas, relevos de bichos) le llega igual que le llegaba al cliente
#  que era dueño. Lo unico que hay que hacer es NO contarle como humano: ni avatar, ni cupo, ni
#  recuento, ni guardado, ni "¿queda alguien en el piso?" (ver Net.es_trabajador y sus usos).
#
#  EL CICLO (todo lo decide el host):
#    - Al abrir la sala se lanza uno de RESERVA, que espera en una escena vacia.
#    - Alguien entra a un piso sin dueño -> se le da a un trabajador de reserva (Net.pisos._entrar_ok con
#      dueño=true y la foto congelada) y se lanza otro de repuesto. Si no hay ninguno listo, el dueño es
#      el humano, como siempre: nunca queda peor que antes.
#    - El piso se queda sin humanos -> se le pide la FOTO, se congela en _fotos_piso y el trabajador
#      vuelve a la reserva (o se cierra si ya sobra).
#
#  NADA ATADO AL PC DEL HOST: el trabajador recibe ip, puerto y token por argumentos, asi que el dia que
#  la sala viva en un servidor lanza los mismos procesos y ya.
#
#  El TOKEN existe para que nadie de fuera pueda registrarse como trabajador con el codigo de sala y
#  quedarse con un piso: lo genera el host al abrir y solo viaja en los argumentos del proceso.
# ============================================================
extends Node

const ARG := "trabajador"
# Cuantos se tienen esperando. Uno basta: entrar a un piso es poco frecuente y arrancar otro son unos
# segundos, pero sin ninguno esperando el primero que baja se quedaria de dueño humano.
const RESERVA := 1
# Si un trabajador lanzado no se ha presentado en este tiempo, se da por perdido (no arranco, se colgo).
const PLAZO_ARRANQUE := 30.0
# Cuanto aguanta el host a un trabajador que no contesta antes de darlo por caido (ver _saludar_trabajador).
const TIMEOUT_MIN_MS := 2000
const TIMEOUT_MAX_MS := 5000
# TOPE DE FOTOGRAMAS. Sin ventana no hay vsync que frene, y Godot da vueltas tan rapido como puede:
# medido, un trabajador de RESERVA que no hacia nada se comia un 25% de un nucleo. La fisica (IA y
# movimiento de los bichos) sigue a su ritmo fijo; esto solo limita las vueltas de _process.
const FPS_SIMULANDO := 30
const FPS_RESERVA := 5

# --- HOST ---
var _token := ""
var _puerto := 0
var _pids: Array[int] = []        # procesos lanzados por ESTA maquina (para cerrarlos al cerrar la sala)
# Lanzados que aun no se han presentado, por su numero de lanzamiento. Se saca el mas viejo al
# presentarse uno (no se sabe cual es cual, y da igual: solo importa CUANTOS faltan).
var _pendientes: Array[int] = []
var _estado: Dictionary = {}      # peer_id -> piso en el que esta (0 = en la reserva)
# LOS DE PELEA (Parte 3). Un trabajador con piso puede ser su DUEÑO (simula el piso) o estar alli DE
# PELEA: dentro como espejo, sin simular nada, esperando a ejecutar la proxima pelea de ese piso. Asi
# la pelea empieza al instante (no hay que cargar el piso) y ningun jugador la lleva en su PC.
var _de_pelea: Dictionary = {}    # peer_id -> true: esta en su piso para peleas
var _peleando: Dictionary = {}    # peer_id -> true: ejecutando una pelea ahora mismo
var _n_lanzados: int = 0          # para numerar los ficheros de registro

# --- TRABAJADOR ---
var _mi_token := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# EL PARTE DEL TRABAJADOR: sin ventana, su registro es lo unico que dice que esta haciendo. Cada
# PARTE_CADA segundos, una linea por piso: cuantos enemigos lleva, a que humanos ve y a que distancia
# tiene cada uno al enemigo mas cercano (y en que estado va ese enemigo).
const PARTE_CADA := 5.0
var _t_parte := 0.0

func _process(delta: float) -> void:
	if not Net.soy_trabajador or not Net._soy_dueno:
		return
	_t_parte -= delta
	if _t_parte > 0.0:
		return
	_t_parte = PARTE_CADA
	var enemigos: Array = get_tree().get_nodes_in_group("enemy").filter(
		func(e): return is_instance_valid(e) and not e.has_meta("es_espejo"))
	var humanos: Array = []
	for id in Net._avatares:
		var a = Net._avatares[id]
		if not is_instance_valid(a):
			continue
		var mejor := INF
		var estado := "-"
		for e in enemigos:
			var d: float = (e as Node2D).global_position.distance_to((a as Node2D).global_position)
			if d < mejor:
				mejor = d
				estado = "%s%s" % [str(e.get("_state")), " (pelea)" if e.get("_combat_triggered") else ""]
		humanos.append("peer %d a %.0f px de un enemigo en estado %s" % [id, mejor, estado])
	print("[trabajador] piso %d: %d enemigos | %s" % [Net.pisos.mi_piso(), enemigos.size(),
		", ".join(humanos) if not humanos.is_empty() else "sin humanos a la vista"])


# ============================================================
#  EN EL TRABAJADOR
# ============================================================

# ¿Me han lanzado como trabajador? Mira los argumentos de usuario (lo que va detras de "--").
static func argumentos() -> PackedStringArray:
	var args := OS.get_cmdline_user_args()
	var i := args.find(ARG)
	if i < 0 or args.size() < i + 4:
		return PackedStringArray()
	return args.slice(i + 1, i + 4)   # ip, puerto, token


func arrancar(args: PackedStringArray) -> void:
	var ip := args[0]
	var puerto := int(args[1])
	_mi_token = args[2]
	Net.soy_trabajador = true
	Engine.max_fps = FPS_RESERVA
	print("[trabajador] arrancando contra %s:%d" % [ip, puerto])
	# Fuera el menu principal: un trabajador no pinta nada y espera en una escena vacia.
	get_tree().change_scene_to_node(Node.new())
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, puerto)
	if err != OK:
		print("[trabajador] no se pudo crear el cliente (%d): me cierro" % err)
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	Net.activo = true
	Net.es_host = false
	Game._refrescar_pausa()


# Lo llama Net._on_connected_to_server en vez del saludo de un jugador.
func saludar() -> void:
	_saludar_trabajador.rpc_id(1, _mi_token, Net.PROTOCOLO)


# La sala se ha cerrado o no me ha aceptado: sin sala no tengo nada que simular.
func me_han_soltado(motivo: String) -> void:
	print("[trabajador] ", motivo, ": me cierro")
	get_tree().quit()


# El host pide la foto del piso que simulo, porque se ha quedado sin humanos. NO me voy todavia: si
# alguien entra mientras la foto viaja, el host la descarta y sigo siendo el dueño.
@rpc("authority", "call_remote", "reliable")
func _dame_foto(piso: int) -> void:
	if Net.pisos.mi_piso() != piso or not Net._soy_dueno:
		_foto.rpc_id(1, piso, {})
		return
	_foto.rpc_id(1, piso, Net.pisos._foto_de_mi_piso())


# El host se ha quedado la foto: a la reserva, a esperar otro piso.
@rpc("authority", "call_remote", "reliable")
func _a_la_reserva() -> void:
	print("[trabajador] piso %d congelado: vuelvo a la reserva" % Net.pisos.mi_piso())
	Net._soy_dueno = false
	Net.pisos._olvidar_mis_enemigos()
	Game.memoria_pisos.clear()
	get_tree().change_scene_to_node(Node.new())
	Net.anunciar_lugar(ARG)
	Engine.max_fps = FPS_RESERVA


# Me acaban de dar un piso (Net.pisos._entrar_ok): a ritmo de simulacion.
func al_recibir_piso() -> void:
	Engine.max_fps = FPS_SIMULANDO


@rpc("authority", "call_remote", "reliable")
func _cierrate() -> void:
	me_han_soltado("sobro en la reserva")


# ============================================================
#  EN EL HOST
# ============================================================

func es_trabajador(peer_id: int) -> bool:
	return _estado.has(peer_id)


# Al abrir la sala: token nuevo y el primero de reserva en marcha.
func al_abrir_sala(puerto: int) -> void:
	_token = "%016x%016x" % [randi(), randi()]
	_puerto = puerto
	_rellenar_reserva()


# Al cerrar la sala: los que lance yo se cierran. Normalmente ya se cierran solos al perder la conexion
# (me_han_soltado), pero uno colgado se quedaria con memoria y CPU para siempre.
func al_cerrar_sala() -> void:
	for pid in _pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_pids.clear()
	_estado.clear()
	_de_pelea.clear()
	_peleando.clear()
	_pendientes.clear()
	_token = ""


func _libres() -> int:
	var n := 0
	for w in _estado:
		if int(_estado[w]) == 0:
			n += 1
	return n


func _rellenar_reserva() -> void:
	if not Net.es_host or _token == "":
		return
	while _libres() + _pendientes.size() < RESERVA:
		if not _lanzar():
			return


func _lanzar() -> bool:
	_n_lanzados += 1
	var registro := OS.get_user_data_dir().path_join("logs")
	DirAccess.make_dir_recursive_absolute(registro)
	var args: PackedStringArray = ["--headless"]
	# Desde el editor el ejecutable es el propio Godot: hay que decirle que proyecto abrir. En el .exe
	# exportado el proyecto va dentro.
	if OS.has_feature("editor"):
		args.append_array(["--path", ProjectSettings.globalize_path("res://")])
	args.append_array(["--log-file", registro.path_join("trabajador_%d.log" % _n_lanzados),
		"--", ARG, "127.0.0.1", str(_puerto), _token])
	var pid := OS.create_process(OS.get_executable_path(), args)
	if pid <= 0:
		push_warning("[trabajadores] no se pudo lanzar un trabajador: los pisos los llevaran los jugadores")
		return false
	_pids.append(pid)
	_pendientes.append(_n_lanzados)
	print("[trabajadores] lanzado el %d (pid %d)" % [_n_lanzados, pid])
	_plazo_de_arranque(_n_lanzados)
	return true


func _plazo_de_arranque(n: int) -> void:
	await get_tree().create_timer(PLAZO_ARRANQUE).timeout
	# Sigue pendiente: ese lanzamiento no va a llegar. Se quita y se repone la reserva.
	if _pendientes.has(n):
		_pendientes.erase(n)
		push_warning("[trabajadores] el trabajador %d no se presento a tiempo" % n)
		_rellenar_reserva()


@rpc("any_peer", "call_remote", "reliable")
func _saludar_trabajador(token: String, protocolo: int) -> void:
	if not Net.es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if _token == "" or token != _token or protocolo != Net.PROTOCOLO:
		Net._echar(quien, "No eres un trabajador de esta sala.")
		return
	if not _pendientes.is_empty():
		_pendientes.pop_front()
	_estado[quien] = 0
	# Si se CUELGA o lo matan, que se note pronto. Por defecto ENet tarda mas de 15 s en dar por muerta
	# una conexion que se corta sin avisar, y todo ese rato el piso se queda con sus bichos quietos para
	# los humanos de dentro. Un trabajador que no contesta en 5 s no va a contestar.
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null and enet.get_peer(quien) != null:
		enet.get_peer(quien).set_timeout(32, TIMEOUT_MIN_MS, TIMEOUT_MAX_MS)
	Net._peers[quien] = {"color": Color.WHITE, "metal": 0.0, "nombre": ARG, "lugar": ARG,
		"pos": Vector2.INF, "peleando": false, "comps": [], "imagen": PackedByteArray(),
		"alpha": 1.0, "piezas": {}, "trabajador": true}
	# Lo que necesita para generar la MISMA mazmorra (semilla) y ver al host...
	Net._presentarse.rpc_id(quien, Game.player_color, Game.player_metalico, Game.player_nombre,
		Net._mi_lugar, Game.semilla_mundo, Game.tienda_t2_abierta(), Game.player_imagen_png,
		Game.player_color_alpha, PackedInt32Array(Game.pisos_desbloqueados()),
		Game.lider().aspecto_completo()["piezas"])
	# ...y a los humanos que ya estaban: son sus presas, sus bichos tienen que verles.
	for otro in Net._peers:
		if otro == quien or es_trabajador(otro):
			continue
		var p: Dictionary = Net._peers[otro]
		Net._presentar_ajeno.rpc_id(quien, otro, p["color"], p["metal"], p["nombre"], p["lugar"],
			p.get("imagen", PackedByteArray()), float(p.get("alpha", 1.0)), p.get("comps", []),
			p.get("piezas", {}))
	print("[trabajadores] se presenta el peer %d (reserva: %d)" % [quien, _libres()])
	# ¿Hay algun piso con gente esperando a su trabajador de pelea? (el que salio de la reserva hacia falta.)
	for piso in Net._dueno_piso.keys():
		asegurar_pelea(int(piso))


# Un piso sin dueño vivo: se le da a uno de reserva. Devuelve si ha habido trabajador para el. Lo llaman
# _conceder_entrada y _conceder_piso ANTES de repartir al humano, para que el humano ya lo encuentre con
# dueño y entre de espejo.
func asegurar_dueno(piso: int) -> bool:
	if not Net.es_host or piso < 1:
		return false
	var actual: int = Net._dueno_piso.get(piso, 0)
	if actual != 0 and Net.pisos._sigue_en(actual, piso):
		return es_trabajador(actual)
	var w := 0
	for id in _estado:
		if int(_estado[id]) == 0:
			w = id
			break
	if w == 0:
		_rellenar_reserva()
		return false
	_estado[w] = piso
	Net._dueno_piso[piso] = w
	Net._viajando[w] = piso
	var mem: Dictionary = Net._fotos_piso.get(piso, {})
	Net._fotos_piso.erase(piso)
	Net.pisos._entrar_ok.rpc_id(w, piso, Net.recoleccion._agotados_sesion, true, mem, Net.pisos._restantes_boss(),
		Net.epoca_sesion, Net.recoleccion._nonces_sesion)
	print("[trabajadores] el piso %d lo simula el peer %d" % [piso, w])
	_rellenar_reserva()
	return true


# 'piso' puede haberse quedado sin humanos (alguien ha subido, bajado, muerto o se ha ido). Si lo
# simula un trabajador, se le pide la foto; el resto lo hace _foto al llegar.
func revisar_vacio(piso: int, salvo: int = 0) -> void:
	if not Net.es_host or piso < 1:
		return
	if Net.pisos._alguien_en(piso, salvo) != 0:
		return
	# Sin gente no hay peleas que esperar (lleve el piso quien lo lleve).
	_soltar_los_de_pelea(piso)
	var w: int = Net._dueno_piso.get(piso, 0)
	if not es_trabajador(w):
		return
	_dame_foto.rpc_id(w, piso)


@rpc("any_peer", "call_remote", "reliable")
func _foto(piso: int, foto: Dictionary) -> void:
	if not Net.es_host:
		return
	var w := multiplayer.get_remote_sender_id()
	if int(_estado.get(w, -1)) != piso:
		return
	# Alguien ha entrado mientras la foto venia: el trabajador sigue, la foto sobra.
	if Net.pisos._alguien_en(piso, 0) != 0:
		return
	# Una foto vacia es "no la tengo", no "piso vacio" (esa trae la clave aunque sea sin bichos).
	if not foto.is_empty() or not Net._fotos_piso.has(piso):
		Net._fotos_piso[piso] = foto
	if int(Net._dueno_piso.get(piso, 0)) == w:
		Net._dueno_piso.erase(piso)
	_estado[w] = 0
	if _libres() > RESERVA:
		_estado.erase(w)
		Net._peers.erase(w)
		_cierrate.rpc_id(w)
	else:
		_a_la_reserva.rpc_id(w)
	print("[trabajadores] piso %d congelado (%d enemigos)" % [piso, (foto.get("enemigos", []) as Array).size()])


# Se ha ido un trabajador (cerrado o caido). El piso que llevara lo hereda un humano que este dentro por
# el camino de siempre (_soltar_piso, que ya se ha llamado); aqui solo se repone la reserva.
func al_irse(peer_id: int) -> void:
	if not _estado.has(peer_id):
		return
	var piso: int = int(_estado[peer_id])
	_estado.erase(peer_id)
	_de_pelea.erase(peer_id)
	_peleando.erase(peer_id)
	_rellenar_reserva()
	if piso > 0:
		asegurar_pelea(piso)


# ============================================================
#  TRABAJADORES DE PELEA (en el host)
# ============================================================

# El de pelea que esta en 'piso' y libre para una pelea nueva (0 = ninguno).
func pelea_libre_en(piso: int) -> int:
	for w in _de_pelea:
		if int(_estado.get(w, 0)) == piso and not _peleando.has(w):
			return w
	return 0


# Que 'piso' tenga uno de pelea esperando dentro, si hay gente y queda alguno en la reserva. Se llama al
# dar un piso a alguien, al presentarse uno nuevo y cuando uno se pone a pelear (para la siguiente).
# 'entra_alguien': lo llama quien le esta dando el piso a un humano, que aun no cuenta como dentro.
func asegurar_pelea(piso: int, entra_alguien: bool = false) -> void:
	if not Net.es_host or piso < 1 or pelea_libre_en(piso) != 0:
		return
	if not entra_alguien and Net.pisos._alguien_en(piso, 0) == 0:
		return
	var w := 0
	for id in _estado:
		if int(_estado[id]) == 0:
			w = id
			break
	if w == 0:
		_rellenar_reserva()   # cuando se presente, _saludar_trabajador vuelve a llamar aqui
		return
	_estado[w] = piso
	_de_pelea[w] = true
	Net._viajando[w] = piso
	# Entra como ESPEJO (dueño=false): ve los enemigos del dueño igual que un jugador.
	Net.pisos._entrar_ok.rpc_id(w, piso, Net.recoleccion._agotados_sesion, false, {}, Net.pisos._restantes_boss(),
		Net.epoca_sesion, Net.recoleccion._nonces_sesion)
	print("[trabajadores] el peer %d espera peleas en el piso %d" % [w, piso])
	_rellenar_reserva()


# Corre en EL HOST: un trabajador de pelea ha empezado una. Ya no esta libre: que entre otro para la siguiente.
@rpc("any_peer", "call_remote", "reliable")
func _pelea_empezada() -> void:
	var w := multiplayer.get_remote_sender_id()
	if not Net.es_host or not _de_pelea.has(w):
		return
	_peleando[w] = true
	asegurar_pelea(int(_estado.get(w, 0)))


# Corre en EL HOST: ha cerrado su pelea. Si ya hay otro esperando en ese piso (o el piso se ha quedado sin
# gente), este sobra ahi y vuelve a la reserva.
@rpc("any_peer", "call_remote", "reliable")
func _pelea_acabada() -> void:
	var w := multiplayer.get_remote_sender_id()
	if not Net.es_host or not _de_pelea.has(w):
		return
	_peleando.erase(w)
	var piso: int = int(_estado.get(w, 0))
	for otro in _de_pelea:
		if otro != w and int(_estado.get(otro, 0)) == piso and not _peleando.has(otro):
			_soltar_de_pelea(w)
			return
	if Net.pisos._alguien_en(piso, 0) == 0:
		_soltar_de_pelea(w)


# El piso se queda sin gente: los de pelea que no esten peleando vuelven a la reserva (el que pelea lo
# hara al acabar, ver _pelea_acabada).
func _soltar_los_de_pelea(piso: int) -> void:
	for w in _de_pelea.keys():
		if int(_estado.get(w, 0)) == piso and not _peleando.has(w):
			_soltar_de_pelea(w)


func _soltar_de_pelea(w: int) -> void:
	_de_pelea.erase(w)
	_peleando.erase(w)
	_estado[w] = 0
	Net._viajando.erase(w)
	if _libres() > RESERVA:
		_estado.erase(w)
		Net._peers.erase(w)
		_cierrate.rpc_id(w)
	else:
		_a_la_reserva.rpc_id(w)
	print("[trabajadores] el peer %d deja de esperar peleas" % w)


# ============================================================
#  TRABAJADOR DE PELEA (en el trabajador): avisos al host
# ============================================================

func avisar_pelea_empezada() -> void:
	if Net.soy_trabajador and multiplayer.multiplayer_peer != null:
		_pelea_empezada.rpc_id(1)


func avisar_pelea_acabada() -> void:
	if Net.soy_trabajador and multiplayer.multiplayer_peer != null:
		_pelea_acabada.rpc_id(1)
