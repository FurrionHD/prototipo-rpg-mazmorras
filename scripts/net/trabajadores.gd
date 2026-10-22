# ============================================================
#  trabajadores.gd  (hijo de Net: /root/Net/Trabajadores)
#  LOS TRABAJADORES DE PELEA: un Godot SIN VENTANA que espera dentro de un piso con gente y ejecuta la siguiente pelea
#  de ese piso; el jugador la ve en espejo, y ningun PC de jugador lleva la pelea.
#
#  Hasta la etapa 2 de la fase 2 (21/10) habia tambien trabajadores de PISO (el dueño de cada piso ocupado) y, si no
#  quedaba ninguno, el piso lo heredaba el PC de un jugador. Eso se fue: los PISOS los lleva la sala (net_pisos,
#  sala_montar / sala_congelar). Las peleas pasaran a la sala en la etapa 3 y entonces se va este archivo entero.
#
#  COMO ENCAJA: el trabajador es un CLIENTE mas de la sala, apuntado en Net._peers con "trabajador": true, que entra al
#  piso de ESPEJO como un jugador (Net.pisos._entrar_ok). NO se le cuenta como humano: ni avatar, ni cupo, ni recuento,
#  ni guardado, ni "¿queda alguien en el piso?" (ver Net.es_trabajador y sus usos).
#
#  EL CICLO (todo lo decide la sala):
#    - Al abrir la sala se lanzan los de RESERVA, que esperan en una escena vacia.
#    - Alguien entra a un piso -> uno de reserva entra a esperar peleas alli (asegurar_pelea) y se lanza otro.
#    - Empieza una pelea -> la ejecuta el que esperaba (y entra otro a esperar la siguiente).
#    - El piso se queda sin humanos -> los que esperaban alli vuelven a la reserva (o se cierran si sobran).
#
#  NADA ATADO AL PC DEL HOST: el trabajador recibe ip, puerto y token por argumentos, asi que el dia que
#  la sala viva en un servidor lanza los mismos procesos y ya.
#
#  El TOKEN existe para que nadie de fuera pueda registrarse como trabajador con el codigo de sala y
#  quedarse con un piso: lo genera el host al abrir y solo viaja en los argumentos del proceso.
# ============================================================
extends Node

const ARG := "trabajador"
# Cuantos se tienen esperando. Eran 1 (entrar a un piso es poco frecuente y arrancar otro son unos segundos), pero
# sin ninguno esperando el primero que baja se queda de dueño humano, y el 11/10 dos jugadores entrando y peleando a
# la vez lo agotaban: el piso o la pelea acababan en el PC de un jugador. Con 2 siempre queda uno (12/10).
const RESERVA := 2
# CUANTOS SE GUARDAN ANTES DE CERRAR NINGUNO. No es lo mismo que RESERVA: aquel es cuantos se LANZAN
# para tener a mano, y este cuantos se CONSERVAN cuando uno queda libre.
#
# Con los dos a 1 salia un proceso nuevo POR PELEA: el que esperaba entraba a pelear, se lanzaba otro
# para la siguiente y, al acabar, el que acababa de quedar libre sobraba y se cerraba. Medido en los
# logs del 19/09: 121 trabajadores lanzados y 110 cerrados para 97 peleas, y cada arranque es un Godot
# entero que ademas GENERA EL PISO al nacer, en la misma maquina que esta jugando. Conservando dos, el
# que se libera se reaprovecha para la pelea siguiente y no se lanza nada.
const RESERVA_MAX := 3   # uno mas que RESERVA (12/10: la reserva paso a 2)
# Si un trabajador lanzado no se ha presentado en este tiempo, se da por perdido (no arranco, se colgo).
const PLAZO_ARRANQUE := 30.0
# Tantos seguidos sin presentarse y se deja de lanzar: algo impide conectar y relanzar cada 30 s solo
# fabrica procesos (el 15/09 llegaron al 35). Se prueba uno cada ESPERA_TRAS_FALLOS, y en cuanto se
# presenta alguno se vuelve al ritmo normal.
const FALLOS_PARA_PARAR := 3
const ESPERA_TRAS_FALLOS := 120.0
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
# RESERVADO AL MANDARLE UNA PELEA (12/10, playtest 11/10): hasta entonces solo contaba como ocupado cuando el
# trabajador contestaba _pelea_empezada, y en ese rato una segunda pelea del mismo piso se le mandaba a EL; la
# rechazaba ("no puedo ejecutar ... la monta el") y acababa jugandose en el PC de un jugador: dos peleas en el
# mismo sitio y los dos actuando a la vez. peer_id -> msec hasta el que esta apartado (por si nunca contesta).
var _reservado_hasta: Dictionary = {}
const RESERVA_PELEA_MS := 8000
# El PROCESO de cada trabajador (su pid, que manda al presentarse). Para cerrar uno concreto: hoy lo usan las
# pruebas para tirar SOLO al dueño del piso y ver que la pelea de otro trabajador sigue.
var _pid_de: Dictionary = {}
var _n_lanzados: int = 0          # para numerar los ficheros de registro
var _fallos_seguidos: int = 0     # lanzados que no llegaron, desde el ultimo que si (ver FALLOS_PARA_PARAR)
var _reintento_en_marcha := false

# --- TRABAJADOR ---
var _mi_token := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Las fotos de los pisos de la sala para el guardado (_fotos_periodicas). El "parte" que escribia el trabajador
# DUEÑO de un piso se fue con los trabajadores de piso (etapa 2): los pisos los lleva la sala.
func _process(delta: float) -> void:
	if Net.activo and Net.es_host and Net.soy_sala:
		_fotos_periodicas(delta)


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
	_saludar_trabajador.rpc_id(1, _mi_token, Net.PROTOCOLO, OS.get_process_id())


# La sala se ha cerrado o no me ha aceptado: sin sala no tengo nada que simular.
func me_han_soltado(motivo: String) -> void:
	print("[trabajador] ", motivo, ": me cierro")
	get_tree().quit()


# Ya no me necesitan en ese piso: a la reserva, a esperar otro.
@rpc("authority", "call_remote", "reliable")
func _a_la_reserva() -> void:
	print("[trabajador] dejo el piso %d: vuelvo a la reserva" % Net.pisos.mi_piso())
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
	_pid_de.clear()
	_pendientes.clear()
	_fallos_seguidos = 0
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
	if _fallos_seguidos >= FALLOS_PARA_PARAR:
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
		_fallos_seguidos += 1
		if _fallos_seguidos >= FALLOS_PARA_PARAR:
			if _reintento_en_marcha:
				return   # otro plazo vencido ya esta esperando para probar: con uno basta
			_reintento_en_marcha = true
			push_warning("[trabajadores] %d seguidos sin llegar: pruebo otro dentro de %d s"
				% [_fallos_seguidos, int(ESPERA_TRAS_FALLOS)])
			await get_tree().create_timer(ESPERA_TRAS_FALLOS).timeout
			_reintento_en_marcha = false
			if _token == "":
				return   # la sala se cerro mientras tanto
			# Uno solo de prueba: si tampoco llega, vuelve a caer aqui y espera otra vez.
			_fallos_seguidos = FALLOS_PARA_PARAR - 1
		_rellenar_reserva()


@rpc("any_peer", "call_remote", "reliable")
func _saludar_trabajador(token: String, protocolo: int, pid: int = 0) -> void:
	if not Net.es_host:
		return
	var quien := multiplayer.get_remote_sender_id()
	if _token == "" or token != _token or protocolo != Net.PROTOCOLO:
		Net._echar(quien, "No eres un trabajador de esta sala.")
		return
	if not _pendientes.is_empty():
		_pendientes.pop_front()
	_fallos_seguidos = 0
	_estado[quien] = 0
	_pid_de[quien] = pid
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
	# ...con MIS compañeros (a los humanos se les anuncia al saludarse; al trabajador no le llegaba nunca)...
	if not Net.soy_sala:
		Net.jugadores.anunciar_grupo_a(quien)
	# ...y a los humanos que ya estaban: son sus presas, sus bichos tienen que verles.
	for otro in Net._peers:
		if otro == quien or es_trabajador(otro):
			continue
		var p: Dictionary = Net._peers[otro]
		Net._presentar_ajeno.rpc_id(quien, otro, p["color"], p["metal"], p["nombre"], p["lugar"],
			p.get("imagen", PackedByteArray()), float(p.get("alpha", 1.0)), p.get("comps", []),
			p.get("piezas", {}))
	# ...y EN QUE PISO SE JUEGA LA ARENA (12/10, playtest 11/10: el Minotauro de la arena salia con 3553 de vida, al
	# volver tras huir con 1208 y luego otra vez con 3551). A los humanos se lo cuenta Net._registrar_peer; a un
	# trabajador que se presentaba DESPUES de cambiarlo no se lo decia nadie, y al montar la pelea de la arena sacaba
	# los numeros del piso 1.
	Net.pisos.contar_piso_arena(quien)
	# ...y si el unico humano tiene ahora el mundo parado (Net.pausa_solo), que nazca parado tambien.
	if Net.pausa_solo != 0:
		Net._pausa_solo.rpc_id(quien, Net.pausa_solo)
	print("[trabajadores] se presenta el peer %d (reserva: %d)" % [quien, _libres()])
	# ¿Hay algun piso con gente esperando a su trabajador de pelea? (el que salio de la reserva hacia falta.)
	for piso in Net._dueno_piso.keys():
		asegurar_pelea(int(piso))


# 'piso' puede haberse quedado sin humanos (alguien ha subido, bajado, muerto o se ha ido). Si lo
# simula un trabajador, se le pide la foto; el resto lo hace _foto al llegar.
func revisar_vacio(piso: int, salvo: int = 0) -> void:
	if not Net.es_host or piso < 1:
		return
	var queda: int = Net.pisos._alguien_en(piso, salvo)
	if queda != 0:
		if Net.soy_sala:
			print("[sala] piso %d: se va %d pero queda %d" % [piso, salvo, queda])
		return
	# Sin gente no hay peleas que esperar.
	_soltar_los_de_pelea(piso)
	# El piso es de la sala (etapa 2): se congela a los 10 s si sigue vacio.
	Net.pisos.sala_vaciado(piso)


# CADA SEG_FOTOS_VIVAS, la foto de cada piso que simula un trabajador: solo para el guardado del mundo
# (Net._fotos_vivas). Asi, si la sala se cae, el mundo vuelve con esos pisos como estaban hace un momento.
const SEG_FOTOS_VIVAS := 30.0
var _t_fotos := 0.0

func _fotos_periodicas(delta: float) -> void:
	_t_fotos += delta
	if _t_fotos < SEG_FOTOS_VIVAS:
		return
	_t_fotos = 0.0
	Net.pisos.sala_fotos_vivas()   # los pisos son de la sala: la foto se saca aqui mismo


# Se ha ido un trabajador (cerrado o caido): se repone la reserva y, si esperaba peleas en un piso, que entre otro.
func al_irse(peer_id: int) -> void:
	if not _estado.has(peer_id):
		return
	var piso: int = int(_estado[peer_id])
	_estado.erase(peer_id)
	_pid_de.erase(peer_id)
	_de_pelea.erase(peer_id)
	_peleando.erase(peer_id)
	_reservado_hasta.erase(peer_id)
	_rellenar_reserva()
	if piso > 0:
		asegurar_pelea(piso)


# ============================================================
#  TRABAJADORES DE PELEA (en el host)
# ============================================================

# El de pelea que esta en 'piso' y libre para una pelea nueva (0 = ninguno).
func pelea_libre_en(piso: int) -> int:
	var ahora: int = Time.get_ticks_msec()
	for w in _de_pelea:
		# Uno que ya se ha ido NO esta libre (21/10, cabo 2 de town_trabajadores): al caerse, Net._olvidar_peer lo
		# quita de _peers y pide otro ejecutor ANTES de que al_irse lo quite de aqui, y como su reserva ya habia
		# vencido (la caida tarda ~5 s en notarse) se le volvia a mandar la pelea a el.
		if not Net._peers.has(w):
			continue
		if int(_estado.get(w, 0)) == piso and not _peleando.has(w) and ahora >= int(_reservado_hasta.get(w, 0)):
			return w
	return 0


# Se le acaba de mandar una pelea a 'w': ya no esta libre para otra, y que entre otro para la siguiente.
func reservar_pelea(w: int) -> void:
	_reservado_hasta[w] = Time.get_ticks_msec() + RESERVA_PELEA_MS
	asegurar_pelea(int(_estado.get(w, 0)))


# ¿Hay trabajadores en esta sala? (si no, las peleas van en el PC de quien pelea, como siempre)
func hay_trabajadores() -> bool:
	return Net.es_host and _token != "" and _fallos_seguidos < FALLOS_PARA_PARAR


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
	Net.pisos._entrar_ok.rpc_id(w, piso, Net.recoleccion._agotados_sesion, Net.pisos._restantes_boss(),
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
	_reservado_hasta.erase(w)
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
	if _libres() > RESERVA_MAX:   # el que queda libre se guarda caliente: ver RESERVA_MAX
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
