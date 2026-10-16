# ============================================================
#  retrato_horneado.gd -- EL RETRATO DE UNA FILA, HORNEADO (plan de optimizacion, fase 1D, 16/10/2026)
# ============================================================
# Cada retrato de las filas de personajes (personaje, maestro, altar, talleres, taberna, hogar) era un MunecoJugador
# VIVO: ~35 sprites, montar sus capas 2,2 ms y arrancar la animacion 1,1 ms, y la fila entera se rehace en cada clic
# (10 personas = ~36 ms, un tiron que se ve). Aqui se pinta UNA vez por personaje y aspecto: los 8 fotogramas de su
# respiracion ('idle_0', 4 fps) en una sola pasada por una SubViewport, y luego se dibuja como una imagen que va
# cambiando de fotograma. Se ve igual (respira) y cuesta como una imagen.
#
#   var e: Dictionary = RetratoHorneado.de(pj)      # {} si aun no esta (o si no se puede: sin ventana)
#   if not e.is_empty(): marco.add_child(RetratoHorneado.crear(e))
#   else: ...el muneco vivo de siempre... y RetratoHorneado.pedir(pj): la proxima vez ya estara
#
# LA HUELLA es lo mismo que mira el muneco para montarse (JugadorSprites.capas_de: capas, colores, acabados, sus
# hojas) + el tinte y la foto de la cara + la escala de la pantalla. Cualquier cambio de aspecto o de equipo da otra
# huella y se vuelve a hornear: no hay que avisar a nadie.
#
# SIN VENTANA (las pruebas, el servidor) no se dibuja nada, asi que no hay horneado: de() devuelve {} y se sigue con
# el muneco vivo, como antes.
#
# LA IMAGEN SALE PREMULTIPLICADA (la SubViewport mezcla sobre transparente: el color ya va multiplicado por su alfa),
# asi que se dibuja con BLEND_MODE_PREMULT_ALPHA. Con el modo normal los bordes saldrian oscuros.
class_name RetratoHorneado
extends Control

const ANIM := "idle_0"
# TOPE DE MEMORIA de la cache, en bytes de imagen (RGBA). Una fila de 8 fotogramas de 74 px a 1920x1080 son ~300 KB;
# una tarjeta del inventario ~1,4 MB. Si se pasa, se empieza de nuevo (lo que se vea se vuelve a hornear solo).
# Los munecos GRANDES (hogar, altar, ficha) no se hornean: se reutilizan vivos (ver plan 1D).
const MAX_BYTES := 48 * 1024 * 1024
static var _bytes: int = 0
# Lo que hay que mover al muneco para que el recorte deje cabeza y hombros (los mismos numeros que
# MenuScaffold._retrato, que salieron de mirar la captura): escala por lado del cuadro y donde va el origen.
const ESCALA_POR_LADO := 2.1
const ORIGEN_Y := 1.02

static var _cache: Dictionary = {}        # huella -> {"tex", "marcos", "fps", "lado"}
static var _horneando: Dictionary = {}    # huella -> true
static var _mat: CanvasItemMaterial = null


static func se_puede() -> bool:
	return DisplayServer.get_name() != "headless"


# La escala con la que la interfaz llega a la pantalla (stretch canvas_items sobre 1280x720): se hornea a esa
# resolucion para que el retrato no salga borroso en una pantalla grande.
static func escala_pantalla() -> float:
	var arbol := Engine.get_main_loop() as SceneTree
	if arbol == null:
		return 1.0
	return maxf(1.0, absf(arbol.root.get_stretch_transform().x.x))


static func huella(pj: PersonajeData, escala: float, modo: String = "fila") -> String:
	var partes := PackedStringArray([modo])
	for c in JugadorSprites.capas_de(pj):
		var claves: Array = (c as Dictionary).keys()
		claves.sort()
		for k in claves:
			var v = c[k]
			partes.append("%s=%s" % [k, str(v.get_instance_id()) if v is Object else str(v)])
		partes.append("/")
	partes.append(str(pj.color))
	partes.append("%d:%d" % [pj.imagen.size(), hash(pj.imagen)])
	partes.append("%.3f" % escala)
	return "|".join(partes)


# ------------------------------------------------------------
#  LA FILA DE RETRATOS (MenuScaffold._retrato): cabeza y hombros, respirando
# ------------------------------------------------------------
# El retrato horneado de 'pj', o {} si aun no esta (o no se puede). Barato: lo de capas_de (~0,15 ms).
static func de(pj: PersonajeData) -> Dictionary:
	return de_modo(pj, "fila")


# Que se hornee, para la proxima vez. Si ya esta (o se esta haciendo), nada.
static func pedir(pj: PersonajeData) -> void:
	pedir_modo(pj, "fila", Vector2.ONE * MenuScaffold.LADO_RETRATO, -1,
		func(mu: MunecoJugador, tam: Vector2) -> void: colocar_fila(mu, tam.x))


# Donde va el muneco de la fila dentro de un cuadro de 'lado' (unidades de la interfaz): lo usan el vivo
# (MenuScaffold._retrato) y el horneado, para que encuadren igual.
static func colocar_fila(mu: MunecoJugador, lado: float) -> void:
	mu.scale = Vector2.ONE * (lado * ESCALA_POR_LADO / PoseJugador.ALTO_MUNDO)
	mu.position = Vector2(lado * 0.5, lado * ORIGEN_Y)


# ------------------------------------------------------------
#  CUALQUIER ENCUADRE: 'modo' distingue la cache (fila, cara de la barra de turnos...)
# ------------------------------------------------------------
static func de_modo(pj: PersonajeData, modo: String) -> Dictionary:
	if pj == null or not se_puede():
		return {}
	return _cache.get(huella(pj, escala_pantalla(), modo), {})


# 'tam' = el cuadro en unidades de la interfaz; 'marcos' = cuantos fotogramas de ANIM (-1 = todos: respira; 1 =
# quieto); 'colocar' = func(mu: MunecoJugador, tam: Vector2): deja el muneco EXACTAMENTE como lo deja quien lo pinta
# vivo en un cuadro de 'tam', en unidades de la interfaz (la escala de pantalla se le aplica despues, a todo junto:
# asi valen las cuentas con margenes fijos, como la tarjeta del inventario). El tamaño va dentro de 'modo' si cambia.
static func pedir_modo(pj: PersonajeData, modo: String, tam: Vector2, marcos: int, colocar: Callable,
		anim: String = ANIM) -> void:
	if pj == null or not se_puede() or tam.x <= 1.0 or tam.y <= 1.0:
		return
	var k: float = escala_pantalla()
	var h: String = huella(pj, k, modo)
	if _cache.has(h) or _horneando.has(h):
		return
	_hornear(pj, h, tam, k, marcos, colocar, anim)


# Al cerrar el juego, fuera: las imagenes guardadas en una variable estatica sobreviven al servidor de dibujo y Godot
# avisa de texturas sin soltar al salir.
static var _limpieza_puesta: bool = false

static func vaciar() -> void:
	_cache.clear()
	_bytes = 0


static func _hornear(pj: PersonajeData, h: String, tam_ui: Vector2, k: float, marcos_pide: int, colocar: Callable,
		anim: String) -> void:
	if not _limpieza_puesta:
		_limpieza_puesta = true
		(Engine.get_main_loop() as SceneTree).root.tree_exiting.connect(vaciar)
	var tam := Vector2i(ceili(tam_ui.x * k), ceili(tam_ui.y * k))
	var escala_img := Vector2(float(tam.x) / tam_ui.x, float(tam.y) / tam_ui.y)
	_horneando[h] = true
	var arbol := Engine.get_main_loop() as SceneTree
	# Cada fotograma va en el centro de un hueco TRES veces mas ancho: el muneco a esta escala se sale de su cuadro
	# por los lados, y con los huecos pegados se colaria en el de al lado.
	var lado: int = tam.x   # el ANCHO de cada fotograma (el alto es tam.y)
	var hueco: int = lado * 3
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# EN DIFERIDO: se pide desde quien monta una fila de retratos, y eso puede pasar en el _ready de una pantalla,
	# con la raiz aun montando sus hijos (add_child falla y no se pinta nada).
	arbol.root.add_child.call_deferred(vp)
	var marcos: int = maxi(1, marcos_pide)
	var fps: float = 1.0
	var i: int = 0
	while i < marcos:
		var mu := MunecoJugador.new()
		mu.montar(pj)
		mu.tenir(pj.color, 0.0)
		mu.poner_cara(pj.textura())
		colocar.call(mu, tam_ui)
		# De unidades de la interfaz a pixeles de la imagen, todo junto. Por lo que MIDE la imagen (109 px para un cuadro
		# de 74 a escala 1,47, no 108,78): asi al estirarla a su cuadro cae cada pixel donde lo pinta el vivo.
		mu.scale *= escala_img.x
		mu.position *= escala_img
		mu.position += Vector2(float(i * hueco + lado), 0.0)   # al cuadro del medio de su hueco
		vp.add_child(mu)
		mu.fijar(anim, i)
		if i == 0:
			if marcos_pide < 0:
				marcos = maxi(1, int(mu.get("_marcos")))
			fps = maxf(0.1, float(mu.get("_fps")))
		i += 1
	vp.size = Vector2i(hueco * marcos, tam.y)
	# Dos vueltas: en la primera se monta todo (y la viewport toma su tamaño); en la segunda ya se ha pintado.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image() if is_instance_valid(vp) else null
	if is_instance_valid(vp):
		vp.queue_free()
	_horneando.erase(h)
	if img == null or img.is_empty():
		return
	var atlas := Image.create(lado * marcos, tam.y, false, img.get_format())
	for m in marcos:
		atlas.blit_rect(img, Rect2i(m * hueco + lado, 0, lado, tam.y), Vector2i(m * lado, 0))
	var bytes: int = atlas.get_width() * atlas.get_height() * 4
	if _bytes + bytes > MAX_BYTES:
		_cache.clear()
		_bytes = 0
	_bytes += bytes
	_cache[h] = {"tex": ImageTexture.create_from_image(atlas), "marcos": marcos, "fps": fps, "lado": lado, "alto": tam.y}


# ------------------------------------------------------------
#  EL NODO QUE LO DIBUJA
# ------------------------------------------------------------
var _e: Dictionary = {}
var _t: float = 0.0
var _i: int = 0


static func crear(e: Dictionary) -> RetratoHorneado:
	var r := RetratoHorneado.new()
	r._e = e
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _mat == null:
		_mat = CanvasItemMaterial.new()
		_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	r.material = _mat
	# PIXEL DURO, como las capas del muneco: con el filtro por defecto, estirar la imagen a su cuadro (59 px en 58,8)
	# la emborronaba, y en una cara de 40 px eso se come los ojos (visto el 16/10 en la captura a 1920x1080).
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.set_process(int(e["marcos"]) > 1)   # quieto: nada que avanzar
	return r


func _process(delta: float) -> void:
	_t += delta
	var i: int = int(_t * float(_e["fps"])) % int(_e["marcos"])
	if i != _i:
		_i = i
		queue_redraw()


func _draw() -> void:
	# Estirado al cuadro. Con una escala de pantalla NO entera (1,47 en 1920x1080) los bordes de algunos pixeles caen
	# una columna al lado de donde los pinta el muneco vivo; tambien el vivo los cambia segun donde caiga en pantalla
	# (probado 16/10 con tools/capturas_retratos: a 1280x720 salen identicos; dibujarlo 1:1 daba MAS diferencias).
	var lado: float = float(_e["lado"])
	draw_texture_rect_region(_e["tex"], Rect2(Vector2.ZERO, size), Rect2(float(_i) * lado, 0.0, lado, float(_e["alto"])))
