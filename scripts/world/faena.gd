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
const REACCION := {
	"picar": {"fuerza": [0.35, 1.0, 1.6], "trozos": [3, 7, 12], "altura": 0.4,
		"sonido": ["picar_flojo", "picar_limpio", "picar_bruto"]},
	"talar": {"fuerza": [0.55, 1.0], "trozos": [9, 6], "hojas": [1, 4], "altura": 0.3,
		"sonido": ["talar_fallo", "talar_limpio"]},
	"segar": {"fuerza": [0.8, 0.45, 0.6], "trozos": [8, 5, 6], "altura": 0.25, "gravedad": 110.0,
		"sonido": ["segar_fallo", "segar_limpio", "segar_sucio"]},
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
	for s in [pref, -pref]:
		if gen == null or gen.es_suelo(nodo.celda + Vector2i(int(s), 0)):
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


func _dist() -> float:
	return float(DIST.get(faena, 20.0))


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
	if medidor == null or not is_instance_valid(medidor) or jugador == null:
		return
	var vp: Viewport = medidor.get_viewport()
	if vp == null:
		return
	var pant: Vector2 = vp.get_canvas_transform() * (jugador.global_position + Vector2(0.0, -18.0))
	var zoom: float = _cam.zoom.x if _cam != null and is_instance_valid(_cam) else 1.0
	var sep: float = HUECO_MEDIDOR * zoom
	var x: float = pant.x + sep if _lado > 0.0 else pant.x - sep - medidor.size.x
	var y: float = pant.y - medidor.size.y * 0.5
	var vis: Vector2 = vp.get_visible_rect().size
	medidor.position = Vector2(clampf(x, 8.0, vis.x - medidor.size.x - 8.0),
		clampf(y, 8.0, vis.y - medidor.size.y - 8.0)).round()


# ============================================================
#  EL GOLPE
# ============================================================
func _on_golpe(tipo: int) -> void:
	_golpe_tipo = tipo
	if jugador != null and jugador.has_method("faena_golpe"):
		jugador.faena_golpe()
	if _muneco == null:
		_impacto()
		return
	var desde: int = int(PoseJugador.FAENA_DESCARGA.get(faena, 0))
	var pega: int = int(PoseJugador.FAENA_IMPACTO.get(faena, desde))
	_muneco.animar_desde(_anim, desde)
	_descargando = true
	_rearme_t = 0.0
	_impacto_t = float(pega - desde) / maxf(1.0, PoseJugador.fps_de(faena))


# Lo que le pasa al recurso cuando la herramienta llega (ver REACCION): tiembla, saltan trozos del
# color de lo que es -- roca con su mineral, madera con su veta -- y, si es un arbol, caen hojas.
func _impacto() -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	var r: Dictionary = REACCION.get(faena, REACCION["picar"])
	var i: int = clampi(_golpe_tipo, 0, (r["fuerza"] as Array).size() - 1)
	var fuerza: float = float(r["fuerza"][i])
	if nodo.has_method("sacudir"):
		nodo.sacudir(fuerza)
	var base: Color = {"talar": COLOR_MADERA, "segar": COLOR_HOJA}.get(faena, COLOR_PIEDRA)
	var col: Color = base
	var md: MaterialData = nodo.get("material_data")
	if md != null:
		col = md.color.lerp(base, 0.45)
	var donde: Vector2 = nodo.punto_golpe(float(r["altura"])) if nodo.has_method("punto_golpe") \
		else nodo.global_position
	var padre: Node = nodo.get_parent()
	if padre != null:
		var p: CPUParticles2D = Particulas.esquirlas(padre, col, Vector2(-_lado, 0.0),
			int(r["trozos"][i]), 0.8 + 0.25 * fuerza, float(r.get("gravedad", 260.0)))
		p.global_position = donde
		p.z_index = 50
		# Las HOJAS caen despacio y en abanico ancho: un arbol sacudido suelta hojas, no piedras.
		if r.has("hojas") and int(r["hojas"][i]) > 0:
			var h: CPUParticles2D = Particulas.esquirlas(padre, COLOR_HOJA, Vector2(-_lado, 0.0),
				int(r["hojas"][i]), 0.35, 45.0)
			h.global_position = donde + Vector2(0.0, -10.0)
			h.z_index = 50
	Sonido.ui(String(r["sonido"][i]))


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
