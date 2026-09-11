# ============================================================
#  faena.gd
#  LA FAENA EN EL MAPA: picar (y, por fases, talar, segar y extraer) sin salir de la mazmorra.
#
#  Hasta ahora cada minijuego era una pantalla negra con una barra encima (Game._abrir_pantalla
#  escondia el mundo entero). El jefe lo queria como la pesca: que SE VEA al personaje dando golpes al
#  recurso, en tiempo real, y la barra pequeña al lado. Esto es lo que lo monta:
#
#    1. COLOCA al personaje a un lado del recurso, izquierda o derecha -- el lado libre de pared,
#       prefiriendo por el que llegas -- y lo lleva andando hasta ahi. Solo dos lados A PROPOSITO: la
#       animacion se dibuja una vez mirando al este y el otro lado es la misma VOLTEADA (idea del jefe,
#       para no dibujar ocho direcciones de cada faena).
#    2. ACERCA LA CAMARA al hueco entre los dos, y la devuelve al acabar.
#    3. PONE LA HERRAMIENTA en la mano del muñeco y le dicta los fotogramas: el pico sube con lo que
#       llevas cargado y baja cuando sueltas (el minijuego avisa de cada golpe con su señal).
#    4. HACE REACCIONAR al recurso en el instante del impacto: sacudida y esquirlas.
#    5. Deja el MEDIDOR del minijuego al lado del personaje, en la pantalla, siguiendolo.
#
#  La LOGICA del minijuego no se toca: sigue en mining.gd, y Game la cierra por el mismo sitio que
#  antes (_on_mineria_finished -> _cerrar_recoleccion, que llama a 'cerrar' de aqui).
#
#  El arbol se PAUSA en solitario, igual que con la pesca: todo lo que se mueve aqui (este nodo, el
#  muñeco, la camara, los tweens, las esquirlas) va con PROCESS_MODE_ALWAYS o se salta la pausa.
# ============================================================

extends Node

# A cuanto del centro del recurso se planta el personaje, en pixeles de mundo, POR FAENA. Lo justo
# para que la herramienta caiga encima del recurso y no delante ni detras.
const DIST := {"picar": 19.0, "talar": 23.0, "segar": 20.0}
# Lo que tarda en volver a ARMARSE una faena de compas tras el golpe (ver PoseJugador.FAENA_CARGA).
const T_REARME := 0.32

# LO QUE LE PASA AL RECURSO EN CADA GOLPE, por faena y por tipo de golpe (el indice es el enum Golpe
# de su minijuego): cuanto tiembla, cuantos trozos saltan, a que altura del dibujo pega y como suena.
#   picar: FLOJO rebota, LIMPIO hace ceder la veta, BRUTO la revienta.
#   talar: FALLO (a destiempo) astilla sin morder, LIMPIO muerde el tronco.
#   segar: FALLO (en falso) destroza la mata, LIMPIO la corta, SUCIO la magulla. Lo que salta son
#          BRIZNAS: pocas, ligeras y cayendo despacio ('gravedad' baja), del verde de la planta.
#
# EL RUIDO DE CADA GOLPE ('ruido', en las mismas unidades que la velocidad: ver Player.hacer_ruido).
# Solo pesa en MULTIJUGADOR, que es donde el mundo no se para mientras trabajas: un bicho lo oye a
# ruido x hearing_factor (0,66) con tope en hearing_max (130 px), y a la mitad a traves de la roca.
# Picar es lo que mas se oye y el bruto llega al tope; talar un poco menos; segar es casi callado y
# extraer, un cuchillo en un cadaver, apenas nada. 'alboroto' es lo que suma cada golpe al medidor de
# brotes del piso (Game.sumar_alboroto): antes se sumaba entero al CERRAR, y ahora se reparte por
# golpe para que la maquina que simula el piso lo cuente tambien cuando el que trabaja es otro.
const RUIDO_DUR := 0.9
const REACCION := {
	"picar": {"fuerza": [0.35, 1.0, 1.6], "trozos": [3, 7, 12], "altura": 0.4,
		"ruido": [120.0, 170.0, 260.0], "alboroto": 3.5,
		"sonido": ["picar_flojo", "picar_limpio", "picar_bruto"]},
	"talar": {"fuerza": [0.55, 1.0], "trozos": [9, 6], "hojas": [1, 4], "altura": 0.3,
		"ruido": [170.0, 200.0], "alboroto": 3.5,
		"sonido": ["talar_fallo", "talar_limpio"]},
	"segar": {"fuerza": [0.8, 0.45, 0.6], "trozos": [8, 5, 6], "altura": 0.25, "gravedad": 110.0,
		"ruido": [110.0, 70.0, 90.0], "alboroto": 2.0,
		"sonido": ["segar_fallo", "segar_limpio", "segar_sucio"]},
	#   extraer: FALLO raja el cristal (esquirlas rojas del cuerpo), ACIERTO lo va soltando (destellos
	#            violeta, del color de los cristales), SALVADO es el fallo que perdona el cuchillo (se
	#            ve fallar, pero salta cristal y no carne).
	"extraer": {"fuerza": [0.7, 0.35, 0.5], "trozos": [6, 5, 5], "altura": 0.0, "gravedad": 180.0,
		"colores": [Color(0.55, 0.10, 0.10), Color(0.78, 0.55, 1.0), Color(0.95, 0.80, 0.45)],
		"ruido": [80.0, 50.0, 60.0], "alboroto": 0.0,
		"sonido": ["extraer_fallo", "extraer_acierto", "extraer_salvado"]},
}
const COLOR_PIEDRA := Color(0.55, 0.52, 0.48)
const COLOR_MADERA := Color(0.62, 0.45, 0.28)
const COLOR_HOJA := Color(0.36, 0.58, 0.26)
const T_LLEGAR := 0.22        # lo que tarda en ponerse en su sitio
const ZOOM_EXTRA := 1.6       # cuanto se acerca la camara sobre la que tengas
const T_CAMARA := 0.35
# Donde se mira: un poco por encima de los pies, que es donde pasa todo.
const ALZA_CAMARA := -14.0
# El medidor, respecto al personaje EN PANTALLA: al lado contrario del recurso, separado del cuerpo.
const HUECO_MEDIDOR := 34.0

var faena: String = ""            # "picar"
var nodo = null                   # el recurso (sin tipar: resource_node.gd no tiene class_name)
var jugador = null                # el Player
var medidor: Control = null       # el minijuego (mining.gd...), que es ademas el que manda
var layer: CanvasLayer = null     # la capa del medidor; Game la tiene como _active_layer

var _muneco: MunecoJugador = null
var _anim: String = ""
var _volteado: bool = false        # true = el personaje esta a la DERECHA y mira al oeste
var _lado: float = -1.0            # -1 izquierda del recurso, +1 derecha
var _listo: bool = false           # ya ha llegado a su sitio
var _descargando: bool = false
var _impacto_t: float = -1.0
var _golpe_tipo: int = 1
var _rearme_t: float = INF        # faenas de compas: tiempo desde el ultimo golpe (INF = armada)

var _cam: Camera2D = null
var _cam_zoom0 := Vector2.ONE
var _cam_offset0 := Vector2.ZERO
var _cam_pm0: int = Node.PROCESS_MODE_INHERIT
var _tw_cam: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


# Lo monta Game.start_mineria. 'tier' es el de la herramienta (el color del pico en la mano) y
# 'mejoras' su +N, igual que su icono.
func empezar(faena_: String, nodo_, jugador_, medidor_: Control, layer_: CanvasLayer,
		tier: int, mejoras: int) -> void:
	faena = faena_
	nodo = nodo_
	jugador = jugador_
	medidor = medidor_
	layer = layer_
	_anim = "%s_%d" % [faena, PoseJugador.ancla_de(faena)]
	if medidor.has_signal("golpe"):
		medidor.golpe.connect(_on_golpe)
	if nodo.has_method("en_faena"):
		nodo.en_faena(true)

	# 1. EL LADO. Primero el del jugador (no le hagas cruzar por delante de la veta), y si ahi hay
	# pared, el otro. Si los dos estan tapados se queda donde esta y solo se encara.
	var pref: float = 1.0 if jugador.global_position.x >= nodo.global_position.x else -1.0
	_lado = pref
	var destino: Vector2 = jugador.global_position
	var gen = _generador()
	var libre: bool = false
	var celda: Vector2i = _celda_de(nodo)
	for s in [pref, -pref]:
		if gen == null or gen.es_suelo(celda + Vector2i(int(s), 0)):
			_lado = s
			libre = true
			break
	if libre:
		destino = nodo.global_position + Vector2(_lado * _dist(), 0.0)
	# La animacion mira al ESTE, o sea que la de la izquierda del recurso va tal cual y la de la
	# derecha, volteada.
	_volteado = _lado > 0.0

	# Andando hasta alli. El paso se le ve: el muñeco anda hacia su sitio y luego se planta.
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var hacia: Vector2 = destino - jugador.global_position
	if hacia.length() > 2.0:
		var m: MunecoJugador = jugador.get("_muneco")
		if m != null:
			m.process_mode = Node.PROCESS_MODE_ALWAYS
			m.animar("walk_%d" % SpriteLienzo.dir8(hacia))
		tw.tween_property(jugador, "global_position", destino, T_LLEGAR)
	else:
		tw.tween_interval(0.01)
	tw.tween_callback(_plantarse.bind(tier, mejoras))
	_acercar_camara()
	# Colocado YA: si no, el primer fotograma sale en la esquina de la pantalla.
	_colocar_medidor()


func _plantarse(tier: int, mejoras: int) -> void:
	_muneco = jugador.empezar_faena(faena, _volteado, tier)
	if _muneco != null:
		for tn in ArmaSprites.HERRAMIENTA_ANIM:
			if String(ArmaSprites.HERRAMIENTA_ANIM[tn]) == faena:
				_muneco.poner_herramienta(JugadorSprites.capa_herramienta(tn, tier, mejoras))
		_muneco.fijar(_anim, 0)
	_listo = true


# EL CADAVER va aparte: no es un recurso del mapa sino un bicho muerto, y los hay desde una rata hasta
# un jefe. Se aparta la mitad de lo que mide su cuerpo (el mismo tam_cuerpo con el que choca en vida)
# mas un margen, para arrodillarse AL LADO y no encima.
func _dist() -> float:
	if faena == "extraer" and nodo != null and is_instance_valid(nodo):
		var tam = nodo.get("_tam_cuerpo")
		var ancho: float = (tam as Vector2).x if tam is Vector2 and tam != Vector2.ZERO else 24.0
		return 12.0 + ancho * 0.5
	return float(DIST.get(faena, 20.0))


# La casilla del recurso. Los del mapa la traen; el cadaver se la calcula por donde ha caido.
func _celda_de(n) -> Vector2i:
	var c = n.get("celda")
	if c is Vector2i:
		return c
	var lado: float = float(DungeonGenerator.CELDA)
	return Vector2i(floori(n.global_position.x / lado), floori(n.global_position.y / lado))


func _generador():
	var piso: Node = get_tree().get_first_node_in_group("dungeon_floor")
	return piso.get("gen") if piso != null else null


# ============================================================
#  LA CAMARA
# ============================================================
func _acercar_camara() -> void:
	_cam = jugador.get_node_or_null("Camera2D") as Camera2D
	if _cam == null:
		return
	_cam_zoom0 = _cam.zoom
	_cam_offset0 = _cam.offset
	_cam_pm0 = _cam.process_mode
	# El suavizado de la camara corre en su _process: con el arbol en pausa se quedaria a medio
	# camino del sitio nuevo del jugador.
	_cam.process_mode = Node.PROCESS_MODE_ALWAYS
	# El centro, a medio camino entre el personaje (ya en su sitio) y el recurso.
	var centro: Vector2 = Vector2(-_lado * _dist() * 0.5, ALZA_CAMARA)
	_tw_cam = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tw_cam.tween_property(_cam, "zoom", _cam_zoom0 * ZOOM_EXTRA, T_CAMARA)
	_tw_cam.tween_property(_cam, "offset", _cam_offset0 + centro, T_CAMARA)


func _devolver_camara() -> void:
	if _cam == null or not is_instance_valid(_cam):
		return
	if _tw_cam != null and _tw_cam.is_valid():
		_tw_cam.kill()
	var cam: Camera2D = _cam
	var pm: int = _cam_pm0
	# El tween va en la CAMARA y no en este nodo: este se borra al cerrar y se llevaria el tween con
	# el, dejando la camara a medio volver.
	var tw := cam.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "zoom", _cam_zoom0, T_CAMARA)
	tw.tween_property(cam, "offset", _cam_offset0, T_CAMARA)
	tw.chain().tween_callback(func() -> void: cam.process_mode = pm)


# ============================================================
#  CADA FOTOGRAMA
# ============================================================
func _process(delta: float) -> void:
	# SI TE SACAN DEL PISO A MEDIAS (multijugador: otro cambia de piso y te lleva), el jugador y su
	# muñeco se van con la escena vieja. La extraccion se auto-cancela sola (extraction.gd) y Game
	# cierra esto; mientras tanto, no se toca nada que ya no existe.
	if jugador == null or not is_instance_valid(jugador):
		_muneco = null
		return
	_colocar_medidor()
	# La oscuridad sigue a la camara aunque el juego este en pausa (ver Niebla.seguir_en_pausa).
	var niebla: Node = get_tree().get_first_node_in_group("niebla")
	if niebla != null and niebla.has_method("seguir_en_pausa"):
		niebla.seguir_en_pausa(delta)
	if not _listo or _muneco == null:
		return
	if _impacto_t >= 0.0:
		_impacto_t -= delta
		if _impacto_t < 0.0:
			_impacto()
	if _descargando:
		if _muneco.terminada():
			_descargando = false
		else:
			return
	# Entre golpe y golpe, los fotogramas 0..DESCARGA-1 (el armado):
	#   - las de CARGA (picar) los sacan de lo que llevas cargado: el pico sube mientras mantienes;
	#   - las de COMPAS (talar...) se rearman solas tras el golpe y esperan ARMADAS al siguiente.
	var tope: int = int(PoseJugador.FAENA_DESCARGA.get(faena, 1)) - 1
	var f: float
	if PoseJugador.FAENA_CARGA.has(faena):
		f = float(medidor.call("carga")) if medidor != null and is_instance_valid(medidor) \
			and medidor.has_method("carga") else 0.0
	else:
		_rearme_t += delta
		f = clampf(_rearme_t / T_REARME, 0.0, 1.0)
	_muneco.fijar(_anim, clampi(roundi(f * float(tope)), 0, tope))


# El medidor sigue al personaje en pantalla, al lado CONTRARIO al recurso (que no tape el golpe).
func _colocar_medidor() -> void:
	if medidor == null or not is_instance_valid(medidor) or jugador == null \
			or not is_instance_valid(jugador):
		return
	var vp: Viewport = medidor.get_viewport()
	if vp == null:
		return
	# CON LOS DEDOS, MAS GRANDE: en un movil la pantalla es pequeña en la mano y una zona estrecha de
	# reto alto se quedaba en nada (ver MedidorFaena.CARRIL).
	var esc: float = MedidorFaena.ESCALA_TACTIL if Tactil.activo else 1.0
	medidor.scale = Vector2.ONE * esc
	var tam: Vector2 = medidor.size * esc
	var pant: Vector2 = vp.get_canvas_transform() * (jugador.global_position + Vector2(0.0, -18.0))
	var zoom: float = _cam.zoom.x if _cam != null and is_instance_valid(_cam) else 1.0
	var sep: float = HUECO_MEDIDOR * zoom
	var x: float = pant.x + sep if _lado > 0.0 else pant.x - sep - tam.x
	var y: float = pant.y - tam.y * 0.5
	var vis: Vector2 = vp.get_visible_rect().size
	medidor.position = Vector2(clampf(x, 8.0, vis.x - tam.x - 8.0),
		clampf(y, 8.0, vis.y - tam.y - 8.0)).round()


# ============================================================
#  EL GOLPE
# ============================================================
func _on_golpe(tipo: int) -> void:
	_golpe_tipo = tipo
	var r: Dictionary = REACCION.get(faena, REACCION["picar"])
	if jugador != null and is_instance_valid(jugador):
		if jugador.has_method("faena_golpe"):
			jugador.faena_golpe(tipo)
		# EL RUIDO, al dar el golpe y no al impacto: es lo que te delata, y el golpe ya esta dado.
		if jugador.has_method("hacer_ruido"):
			jugador.hacer_ruido(float(r["ruido"][clampi(tipo, 0, (r["ruido"] as Array).size() - 1)]),
				RUIDO_DUR)
	# Y el ALBOROTO del piso, por golpe (ver REACCION). Game solo lo cuenta si ESTA maquina simula el
	# piso; si lo simula otro, lo cuenta el al ver el golpe en tu pose (RemotePlayer).
	Game.sumar_alboroto(float(r.get("alboroto", 0.0)))
	if _muneco == null:
		_impacto()
		return
	var desde: int = int(PoseJugador.FAENA_DESCARGA.get(faena, 0))
	var pega: int = int(PoseJugador.FAENA_IMPACTO.get(faena, desde))
	_muneco.animar_desde(_anim, desde)
	_descargando = true
	_rearme_t = 0.0
	_impacto_t = float(pega - desde) / maxf(1.0, PoseJugador.fps_de(faena))


func _impacto() -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	reaccionar(nodo, faena, _golpe_tipo, _lado)
	# El tuyo suena entero: lo estas haciendo tu. Los demas lo oyen por distancia (ver sonar_lejos).
	Sonido.ui(sonido_de(faena, _golpe_tipo))


static func sonido_de(f: String, tipo: int) -> String:
	var r: Dictionary = REACCION.get(f, REACCION["picar"])
	return String(r["sonido"][clampi(tipo, 0, (r["sonido"] as Array).size() - 1)])


# LO QUE LE PASA AL RECURSO cuando la herramienta llega (ver REACCION): tiembla, saltan trozos del
# color de lo que es -- roca con su mineral, madera con su veta -- y, si es un arbol, caen hojas.
# ESTATICA porque la usan DOS: esta faena y el jugador REMOTO, que ve al otro trabajar y tiene que ver
# temblar la misma veta (ver RemotePlayer._faena_golpe_remoto). 'lado' es por donde esta quien golpea
# (-1 izquierda, +1 derecha): los trozos saltan hacia el lado contrario.
static func reaccionar(n: Node2D, f: String, tipo: int, lado: float) -> void:
	var r: Dictionary = REACCION.get(f, REACCION["picar"])
	var i: int = clampi(tipo, 0, (r["fuerza"] as Array).size() - 1)
	var fuerza: float = float(r["fuerza"][i])
	if n.has_method("sacudir"):
		n.sacudir(fuerza)
	else:
		_sacudir(n, fuerza)
	var base: Color = {"talar": COLOR_MADERA, "segar": COLOR_HOJA}.get(f, COLOR_PIEDRA)
	var col: Color = base
	var md = n.get("material_data")
	if md is MaterialData:
		col = (md as MaterialData).color.lerp(base, 0.45)
	if r.has("colores"):
		col = r["colores"][i]
	var donde: Vector2 = n.punto_golpe(float(r["altura"])) if n.has_method("punto_golpe") \
		else n.global_position + Vector2(0.0, -4.0)
	var padre: Node = n.get_parent()
	if padre == null:
		return
	var p: CPUParticles2D = Particulas.esquirlas(padre, col, Vector2(-lado, 0.0),
		int(r["trozos"][i]), 0.8 + 0.25 * fuerza, float(r.get("gravedad", 260.0)))
	p.global_position = donde
	p.z_index = 50
	# Las HOJAS caen despacio y en abanico ancho: un arbol sacudido suelta hojas, no piedras.
	if r.has("hojas") and int(r["hojas"][i]) > 0:
		var h: CPUParticles2D = Particulas.esquirlas(padre, COLOR_HOJA, Vector2(-lado, 0.0),
			int(r["hojas"][i]), 0.35, 45.0)
		h.global_position = donde + Vector2(0.0, -10.0)
		h.z_index = 50


# El temblor de lo que no sabe temblar solo (el cadaver): un vaiven corto de lado a lado que vuelve
# a su sitio. Mismo gesto que ResourceNode.sacudir, saltandose la pausa igual. El sitio de reposo va
# en una META del propio nodo (la funcion es estatica): con dos golpes seguidos, el segundo tiene que
# volver al sitio de verdad y no al que dejo el primero a medio temblar.
static func _sacudir(n: Node2D, fuerza: float) -> void:
	if not n.has_meta("faena_reposo"):
		n.set_meta("faena_reposo", n.position)
	var base: Vector2 = n.get_meta("faena_reposo")
	var viejo = n.get_meta("faena_temblor", null)
	if viejo is Tween and (viejo as Tween).is_valid():
		(viejo as Tween).kill()
	n.position = base
	var a: float = 1.8 * fuerza
	var tw: Tween = n.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for k in [1.0, -0.7, 0.4, 0.0]:
		tw.tween_property(n, "position", base + Vector2(a * k, 0.0), 0.035)
	n.set_meta("faena_temblor", tw)


# EL SONIDO DE LA FAENA DE OTRO, por DISTANCIA a ti: entero de cerca, bajando, y nada cuando ya no
# cabe en tu pantalla. Mismos umbrales que el espadazo de otro jugador (RemotePlayer.OYE_LLENO/NADA)
# y el mismo mando de peso (1 = de lleno, 0,2 = lo mas flojo), pasado a decibelios.
static func sonar_lejos(f: String, tipo: int, donde: Vector2, yo: Vector2, lleno: float,
		nada: float) -> void:
	var d: float = donde.distance_to(yo)
	if d >= nada:
		return
	var peso: float = 1.0
	if d > lleno:
		peso = lerpf(1.0, 0.2, (d - lleno) / (nada - lleno))
	Sonido.ui(sonido_de(f, tipo), Sonido.UI_DB + linear_to_db(peso))


# EL RECURSO QUE ESTA TRABAJANDO OTRO JUGADOR, visto desde aqui: no viaja (seria un mensaje mas por
# golpe), se deduce. Es el de su tipo mas cercano a su avatar, dentro de lo que alcanza una faena.
static func buscar_objetivo(arbol: SceneTree, f: String, pos: Vector2) -> Node2D:
	var grupo: String = "corpse" if f == "extraer" else "recolectable"
	var mejor: Node2D = null
	var mejor_d: float = 60.0
	for n in arbol.get_nodes_in_group(grupo):
		if not (n is Node2D) or not is_instance_valid(n):
			continue
		if f == "picar" and not (n.has_method("es_veta") and n.es_veta()):
			continue
		if f == "talar" and not (n.has_method("es_madera") and n.es_madera()):
			continue
		if f == "segar" and (not n.has_method("es_veta") or n.es_veta() or n.es_madera()):
			continue
		var d: float = (n as Node2D).global_position.distance_to(pos)
		if d < mejor_d:
			mejor_d = d
			mejor = n as Node2D
	return mejor


# ============================================================
#  CERRAR (lo llama Game._cerrar_recoleccion)
# ============================================================
func cerrar() -> void:
	_devolver_camara()
	# Si se abandona a medias la veta sigue ahi: que vuelva a decir [F].
	if nodo != null and is_instance_valid(nodo) and nodo.has_method("en_faena"):
		nodo.en_faena(false)
	if jugador != null and is_instance_valid(jugador) and jugador.has_method("terminar_faena"):
		var mirada: Vector2 = Vector2(-_lado, 0.0)
		jugador.terminar_faena(mirada)
	queue_free()
