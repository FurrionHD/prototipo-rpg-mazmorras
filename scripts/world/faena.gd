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

# A cuanto del centro del recurso se planta el personaje, en pixeles de mundo. Lo justo para que el
# pico caiga encima de la veta y no delante ni detras.
const DIST := 19.0
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
		destino = nodo.global_position + Vector2(_lado * DIST, 0.0)
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
	var centro: Vector2 = Vector2(-_lado * DIST * 0.5, ALZA_CAMARA)
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
	# Entre golpe y golpe: el pico sube con la carga (fotogramas 0..DESCARGA-1).
	var tope: int = int(PoseJugador.FAENA_DESCARGA.get(faena, 1)) - 1
	var c: float = float(medidor.call("carga")) if medidor != null and is_instance_valid(medidor) \
		and medidor.has_method("carga") else 0.0
	_muneco.fijar(_anim, clampi(roundi(c * float(tope)), 0, tope))


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
	_impacto_t = float(pega - desde) / maxf(1.0, PoseJugador.fps_de(faena))


# Lo que le pasa a la veta cuando el pico llega. Un golpe FLOJO rebota (casi no se mueve y salta
# poca cosa), el LIMPIO la hace ceder y el BRUTO la revienta: mas temblor y mas esquirlas.
func _impacto() -> void:
	if nodo == null or not is_instance_valid(nodo):
		return
	var fuerza: float = [0.35, 1.0, 1.6][clampi(_golpe_tipo, 0, 2)]
	var cuantas: int = [3, 7, 12][clampi(_golpe_tipo, 0, 2)]
	if nodo.has_method("sacudir"):
		nodo.sacudir(fuerza)
	var col: Color = Color(0.55, 0.52, 0.48)
	var md: MaterialData = nodo.get("material_data")
	if md != null:
		col = md.color.lerp(Color(0.55, 0.52, 0.48), 0.45)
	var donde: Vector2 = nodo.punto_golpe() if nodo.has_method("punto_golpe") else nodo.global_position
	var padre: Node = nodo.get_parent()
	if padre != null:
		var p: CPUParticles2D = Particulas.esquirlas(padre, col, Vector2(-_lado, 0.0), cuantas,
			0.8 + 0.25 * fuerza)
		p.global_position = donde
		p.z_index = 50
	Sonido.ui(["picar_flojo", "picar_limpio", "picar_bruto"][clampi(_golpe_tipo, 0, 2)])


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
