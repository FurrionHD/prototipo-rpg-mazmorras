# ============================================================
#  fishing_spot.gd
#  EL CHARCO. Una sala por piso lleva uno (ver DungeonFloor._elegir_estanque) y es el unico sitio
#  donde se pesca. A diferencia de una veta, el charco NO SE AGOTA: los peces vuelven.
#
#  Lo que lo separa de los otros tres oficios es que su minijuego NO TAPA EL MUNDO. Picar una veta
#  abre una pantalla negra y te saca de la mazmorra; pescar te deja plantado en la orilla, viendo
#  el agua, el hilo y al pez resistiendose. Por eso el ciclo vive AQUI, en un nodo del mundo, y la
#  barra de tension (fishing.gd) es solo una capa encima que no esconde nada.
#
#  EL CICLO:
#    LIBRE     no estas pescando. F lanza (hace falta CAÑA equipada: sin ella no hay pesca).
#    LANZANDO  el hilo vuela en ARCO desde el personaje hasta el agua (~0.4 s).
#    ESPERA    el corcho flota. Los peces nadan. El PRIMERO que choca con el corcho se engancha.
#    PICANDO   2-4 toques flojos: el corcho tiembla y vuelve. Pulsar aqui ESPANTA al pez.
#    TIRON     temblor fuerte y el corcho SE HUNDE. ESPACIO en esta ventana -> a la lucha.
#    LUCHA     la barra de tension (fishing.gd). El mundo sigue viendose.
#    COBRO     el pez viaja por el hilo hasta tus manos. El aviso de "has conseguido X" sale
#              cuando LLEGA, no cuando se llena la barra: el pez no es tuyo hasta que lo tienes.
#
#  UN PEZ A LA VEZ: mientras hay uno enganchado, los demas rebotan contra el corcho y siguen
#  nadando. Sin esa regla, con 6 peces dando vueltas en un charco de 4x3 celdas la mordida seria
#  instantanea y continua, y la espera -que es media pesca- desapareceria.
#
#  EL BANCO: el charco NO es una fuente infinita. Guarda hasta 10 peces y solo enseña 4-6 a la vez;
#  cada pieza que te llevas tarda 10 minutos en volver, con su propio contador. Dentro de una visita
#  la reposicion es rapida (4 s) y no te quedas mirando el agua vacia; el freno lo pone el banco, no
#  el temporizador. Ver el bloque de constantes para el porque de los dos relojes.
#
#  MULTIJUGADOR: nada que sincronizar, y es deliberado. No hay recurso unico que arbitrar (a
#  diferencia de la veta, que si necesita el candado de Net): cada uno pesca de su propio banco. Los
#  peces son cosmetica LOCAL determinista, sembrada con la semilla del piso + la celda + un nonce,
#  asi que los dos veis los mismos bichos nadando tambien despues de un respawn.
#
#  Aspecto placeholder por codigo (el arte va al final): el agua es un ColorRect y cada pez es un
#  rectangulo alargado mas oscuro que el agua, con el largo sacado de sus centimetros.
# ============================================================

extends Node2D

enum { LIBRE, LANZANDO, ESPERA, PICANDO, TIRON, LUCHA, COBRO }

# --- Lo que le pone DungeonFloor al crearlo ---
var celda: Vector2i = Vector2i.ZERO
var tam_celdas: Vector2i = Vector2i(4, 3)
var tabla: MaterialTable = null

# --- Peces nadando: [{rect: ColorRect, data, cm, vel: Vector2, largo, alto}] ---
var _peces: Array = []
var _estado: int = LIBRE
var _pez: Dictionary = {}        # el enganchado (vacio si ninguno)
var _t: float = 0.0              # cronometro del estado actual
var _toques: int = 0             # picotazos dados en PICANDO
var _toques_max: int = 3
var _ventana: float = 1.2        # duracion de la ventana del TIRON, en segundos
var _press_was: bool = false

# --- Aspecto ---
var _agua: ColorRect = null
var _lbl: Label = null
var _hilo: Line2D = null
var _corcho: ColorRect = null
var _corcho_base: Vector2 = Vector2.ZERO   # donde flota (sin el temblor encima)

# --- Numeros del ciclo ---
# CUANTOS peces se VEN nadando a la vez. Es el aforo del agua, no lo que hay: el charco guarda hasta
# STOCK_MAX y solo saca a la superficie hasta el aforo (ver el bloque de EL BANCO).
const PECES_MIN := 4
const PECES_MAX := 6
# Velocidad de crucero de un pez, px/s. El grande no nada mas rapido: nada mas RECTO (gira menos),
# que es lo que lo hace dificil de cruzarte y facil de ver venir.
const VEL_PEZ := 18.0
const VEL_PEZ_VAR := 10.0
# Cada cuanto un pez decide un rumbo nuevo (segundos, se tira entre los dos).
const GIRO_MIN := 1.2
const GIRO_MAX := 3.5
# Escala de la silueta: px de largo por centimetro de pez. Un gobio de 12 cm son ~7 px y un espejo
# abisal de 150 cm son ~90: se distinguen desde la otra punta de la sala, que es el objetivo.
const PX_POR_CM := 0.6
const LARGO_MIN := 6.0
# TECHO del largo, en fraccion del lado corto del charco. Sin el, un espejo abisal de 165 cm sale de
# 99 px y no CABE en un charco de 128x96: se quedaba clavado contra los bordes o asomando fuera.
# Los tamaños siguen distinguiendose (un gobio son 7 px y el trofeo llena media balsa), pero el
# charco manda: nada nada mas grande que el agua en la que nada.
const LARGO_MAX_FRAC := 0.42

# El vuelo del hilo al lanzar, y lo alto que sube el arco por encima del jugador.
const VUELO := 0.4
const ARCO_ALTO := 46.0

# PICOTEO: cada toque flojo dura esto y separa al siguiente. Es el aviso de que hay algo ahi.
const TOQUE_DUR := 0.35
const TOQUE_AMP := 2.0
# TIRON: la ventana base para clavarlo, y lo que la ALARGA cada punto de la caña (tool_mods).
# El mismo numero vive en MenuScaffold.VENTANA_TIRON_POR_PUNTO, que es quien lo enseña en la ficha.
const VENTANA_BASE := 1.1
const VENTANA_POR_PUNTO := 0.15
const TIRON_AMP := 7.0
# Lo que tarda el pez en llegar a tus manos por el hilo.
const COBRO_DUR := 0.55
# ============================================================
#  EL BANCO: cuantos peces hay de verdad, y cada cuanto vuelven
# ============================================================
#  Dos numeros distintos, y confundirlos es lo que hacia que la pesca fuese barra libre:
#
#    STOCK   lo que HAY en el charco. Hasta 10. Es el presupuesto de verdad.
#    AFORO   lo que se VE nadando a la vez. Entre 4 y 6. Es solo la superficie.
#
#  Los visibles SALEN del stock: no son peces aparte. Asi una visita da como mucho 10 piezas, se
#  vean 4 o 6 a la vez.
#
#  Los dos relojes:
#    - REPONER (4 s reales): sale uno del banco al agua. RAPIDO a proposito -- dentro de una visita
#      no quiero que estes mirando el agua vacia, quiero que el limite lo ponga el banco.
#    - STOCK_REGEN (10 min de tiempo_mazmorra): cada pez PESCADO vuelve al banco, con SU PROPIO
#      contador. Diez minutos despues del ultimo que sacaste, el charco vuelve a estar lleno.
#      Este es el gate de verdad, y usa el reloj de la mazmorra (que corre TAMBIEN en el pueblo,
#      igual que el respawn de las vetas): irte a vender no lo congela.
#
#  El AFORO se vuelve a sortear cada 10 min y NO mata a nadie: si baja de 6 a 4 con cinco nadando,
#  simplemente no repone hasta que queden menos de cuatro. El charco cambia de humor sin que
#  desaparezca nada delante de tus narices.
#
#  Y todo esto se PERSISTE por piso y celda (Game.persistente_piso -> "charcos"), como los sellos de
#  las vetas agotadas. Sin eso el gate de 10 minutos no valdria nada: bastaria con bajar un piso y
#  subir para encontrarte el charco lleno otra vez.
const STOCK_MAX := 10
const STOCK_REGEN := 600.0      # segundos de tiempo_mazmorra que tarda en volver UN pez pescado
const AFORO_REVISION := 600.0   # cada cuanto el charco vuelve a sortear su aforo

# Lo que tarda en salir al agua el siguiente pez del banco.
const REPONER := 4.0
var _t_reponer: float = 0.0
# Peces que HAY (los que nadan mas los que esperan turno).
var _stock: int = STOCK_MAX
# Cuantos se ven a la vez ahora mismo. Se re-sortea cada AFORO_REVISION.
var _aforo: int = PECES_MIN
var _t_aforo: float = 0.0       # tiempo_mazmorra del ultimo sorteo
# Sellos de tiempo_mazmorra en los que vuelve al banco cada pez pescado. Uno por pieza: es lo que
# hace que diez capturas seguidas tarden diez minutos en volver y no diez veces diez.
var _vuelven: Array = []
# Contador de nacimientos, para sembrar cada pez nuevo (ver _rng_pez).
var _nonce: int = 0


func _ready() -> void:
	add_to_group("recolectable")
	# El ciclo tiene que seguir corriendo con el arbol PAUSADO: en solitario, plantarse a pescar
	# empuja un modal (ver interactuar) y eso para el arbol entero. Sin esto, el corcho se
	# congelaria en el aire y no habria pesca que jugar. Misma trampa que los menus (Game.abrir_menu).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_aspecto()
	_poblar()


# ------------------------------------------------------------
#  ASPECTO
# ------------------------------------------------------------
func tam_px() -> Vector2:
	return Vector2(tam_celdas) * float(DungeonGenerator.CELDA)


# Cuanto SOBRESALE el charco de su centro. Lo lee player._mas_cercano_en_grupo para medir la
# distancia contra el BORDE del agua y no contra su centro: si no, un charco de 4x3 celdas te
# obligaria a meterte dentro para que la F llegase.
var radio_extra: float:
	get: return tam_px().length() * 0.5


func _crear_aspecto() -> void:
	var tam: Vector2 = tam_px()
	_agua = ColorRect.new()
	_agua.size = tam
	_agua.position = -tam * 0.5
	_agua.color = Color(0.11, 0.19, 0.30, 0.85)
	add_child(_agua)

	# MURO INVISIBLE. El charco es agua, no suelo: se pesca DESDE LA ORILLA y no metido dentro. Es
	# la excepcion a la regla de resource_node.gd ("los recolectables no tienen colision, estorbar no
	# es interesante"): aqui la colision no estorba, DEFINE el sitio -- sin ella el jugador se planta
	# encima de los peces y el hilo, y toda la puesta en escena deja de tener sentido.
	# Capa por defecto, la misma que los muros del piso (ver DungeonFloor._construir_geometria).
	var cuerpo := StaticBody2D.new()
	var forma := RectangleShape2D.new()
	forma.size = tam
	var col := CollisionShape2D.new()
	col.shape = forma
	cuerpo.add_child(col)
	add_child(cuerpo)

	_lbl = Label.new()
	_lbl.text = "[F]"
	_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl.add_theme_font_size_override("font_size", 10)
	_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_lbl.add_theme_constant_override("outline_size", 3)
	_lbl.offset_left = -20.0
	_lbl.offset_top = -tam.y * 0.5 - 20.0
	_lbl.offset_right = 20.0
	_lbl.offset_bottom = -tam.y * 0.5 - 4.0
	add_child(_lbl)

	# El hilo y el corcho nacen escondidos: solo existen mientras pescas.
	_hilo = Line2D.new()
	_hilo.width = 1.5
	_hilo.default_color = Color(0.92, 0.90, 0.82, 0.9)
	_hilo.visible = false
	add_child(_hilo)

	_corcho = ColorRect.new()
	_corcho.size = Vector2(7, 5)
	_corcho.color = Color(0.90, 0.32, 0.22)
	_corcho.rotation = 0.35   # ligeramente inclinado, como en el boceto
	_corcho.visible = false
	add_child(_corcho)


# ------------------------------------------------------------
#  LOS PECES
# ------------------------------------------------------------
# Nacen con su especie y su talla YA sorteadas: lo que ves nadar es exactamente lo que vas a sacar.
# El sorteo va sembrado con (semilla del piso, celda del charco, indice del pez) para que el
# invitado vea los mismos sin que viaje nada por la red.
func _poblar() -> void:
	if tabla == null:
		return
	_cargar_estado()
	# Al llegar a la sala los peces YA estan nadando: nadie se queda mirando el agua vacia 24 s.
	# Lo que sale es lo que el banco permite, que puede ser menos que el aforo si vienes de vaciarlo.
	for i in range(mini(_aforo, _stock)):
		_nacer_pez(_rng_pez())
	# Si el banco no da para llenar el agua, que empiece a contar ya para cuando le entre uno.
	_armar_reposicion()


# ------------------------------------------------------------
#  ESTADO PERSISTENTE del charco (por piso y celda)
# ------------------------------------------------------------
# Vive donde los sellos de las vetas agotadas: Game.persistente_piso(piso). Se escribe en el momento
# de cada cambio y no al salir de la escena, porque el nodo se libera de golpe al regenerar el piso y
# un _exit_tree no es sitio para tocar el save.
#
# MULTIJUGADOR: NO se escribe en el save (misma regla que DungeonFloor.marcar_agotado). Estas en el
# mundo del host y vaciarle un charco no debe dejar sellos en TU partida. En sesion el banco vive
# solo en RAM de este nodo, y no se sincroniza entre jugadores a proposito: el charco no es un
# recurso unico que arbitrar, cada uno pesca del suyo. Ver la cabecera.
func _guardar_estado() -> void:
	if Net.activo:
		return
	var piso: Dictionary = Game.persistente_piso(Game.current_floor)
	if not piso.has("charcos"):
		piso["charcos"] = {}   # las partidas anteriores a la pesca no traen la clave
	(piso["charcos"] as Dictionary)[celda] = {
		"stock": _stock, "vuelven": _vuelven.duplicate(),
		"aforo": _aforo, "t_aforo": _t_aforo,
	}


func _cargar_estado() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_semilla(), celda.x, celda.y])
	_aforo = rng.randi_range(PECES_MIN, PECES_MAX)
	_t_aforo = Game.tiempo_mazmorra
	_stock = STOCK_MAX
	_vuelven = []

	var guardado: Dictionary = {}
	if not Net.activo:
		guardado = ((Game.persistente_piso(Game.current_floor).get("charcos", {}) as Dictionary)
			.get(celda, {}) as Dictionary)
	if guardado.is_empty():
		return   # charco virgen: lleno, como debe estar
	_stock = int(guardado.get("stock", STOCK_MAX))
	_vuelven = (guardado.get("vuelven", []) as Array).duplicate()
	_aforo = int(guardado.get("aforo", _aforo))
	_t_aforo = float(guardado.get("t_aforo", Game.tiempo_mazmorra))
	# Lo que haya vencido mientras no mirabas entra ahora: el reloj corre aunque no estes en el piso.
	_cobrar_vueltas()
	_revisar_aforo()


# Devuelve al banco los peces cuyo contador de 10 minutos ya ha vencido.
func _cobrar_vueltas() -> void:
	var quedan: Array = []
	for t in _vuelven:
		if Game.tiempo_mazmorra >= float(t):
			_stock = mini(STOCK_MAX, _stock + 1)
		else:
			quedan.append(t)
	_vuelven = quedan


# Cada AFORO_REVISION el charco decide cuantos peces enseña. NO mata a los que ya nadan: si el aforo
# baja, simplemente deja de reponer hasta que sobren. El sorteo va sembrado con el TRAMO de tiempo,
# asi que los dos jugadores de una partida en red ven el mismo humor sin hablarse.
func _revisar_aforo() -> void:
	if Game.tiempo_mazmorra - _t_aforo < AFORO_REVISION:
		return
	var tramo: int = int(Game.tiempo_mazmorra / AFORO_REVISION)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_semilla(), celda.x, celda.y, tramo, "aforo"])
	_aforo = rng.randi_range(PECES_MIN, PECES_MAX)
	_t_aforo = Game.tiempo_mazmorra


func _semilla() -> int:
	var piso = get_tree().get_first_node_in_group("dungeon_floor")
	if piso != null and piso.has_method("_semilla_del_piso"):
		return int(piso._semilla_del_piso())
	return int(Game.semilla_mundo)


# El RNG del PROXIMO pez que nazca en este charco. Sembrado con (semilla del piso, celda, nonce),
# igual que el material de una veta al reaparecer (ver DungeonFloor._material_del_sitio): asi el
# invitado ve nadar exactamente los mismos bichos que el host sin que viaje nada por el cable, y
# eso sigue siendo cierto DESPUES del primer respawn.
#
# Antes el pez repuesto salia del randf() global y en multi cada uno veia una especie distinta en el
# mismo charco. En solitario no se notaba; en cuanto hay dos, la escena deja de ser la misma.
func _rng_pez() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([_semilla(), celda.x, celda.y, _nonce])
	_nonce += 1
	return r


func _nacer_pez(rng: RandomNumberGenerator = null) -> void:
	var r: RandomNumberGenerator = rng if rng != null else _rng_pez()
	var d: MaterialData = tabla.elegir(Game.current_floor, r)
	if d == null:
		return
	var cm: float = d.talla_desde(MaterialData.tirada_talla(r))
	var tam_agua: Vector2 = tam_px()
	var largo: float = clampf(cm * PX_POR_CM, LARGO_MIN,
		minf(tam_agua.x, tam_agua.y) * LARGO_MAX_FRAC)
	var alto: float = maxf(2.0, largo / maxf(1.2, d.esbeltez))

	var rect := ColorRect.new()
	rect.size = Vector2(largo, alto)
	# GIRA SOBRE SU CENTRO. Un Control pivota por defecto en su esquina superior izquierda: sin
	# esto, orientar al pez con su rumbo lo hacia describir un arco alrededor de esa esquina y se
	# le veia asomar FUERA del agua mientras su posicion logica seguia dentro.
	rect.pivot_offset = rect.size * 0.5
	# La SOMBRA no es el color del pez: es el agua oscurecida. Todos los peces se ven igual de
	# oscuros bajo el agua; lo que los distingue de un vistazo es el TAMAÑO, no el tono.
	rect.color = Color(0.04, 0.07, 0.12, 0.45)
	add_child(rect)

	var margen: float = largo * 0.5 + 1.0
	var pos := Vector2(
		r.randf_range(-tam_agua.x * 0.5 + margen, tam_agua.x * 0.5 - margen),
		r.randf_range(-tam_agua.y * 0.5 + margen, tam_agua.y * 0.5 - margen))
	var ang: float = r.randf() * TAU
	var vel: float = VEL_PEZ + r.randf_range(-VEL_PEZ_VAR, VEL_PEZ_VAR)
	_peces.append({
		"rect": rect, "data": d, "cm": cm, "largo": largo, "alto": alto,
		"pos": pos, "vel": Vector2(cos(ang), sin(ang)) * vel,
		"t_giro": r.randf_range(GIRO_MIN, GIRO_MAX),
	})
	_colocar(_peces.back())


func _colocar(p: Dictionary) -> void:
	var rect: ColorRect = p["rect"]
	rect.position = (p["pos"] as Vector2) - rect.size * 0.5


func _nadar(delta: float) -> void:
	var tam: Vector2 = tam_px()
	for p in _peces:
		# El pez ENGANCHADO no deambula: se queda forcejeando junto al corcho.
		if _pez_es(p) and _estado != ESPERA:
			continue
		p["t_giro"] = float(p["t_giro"]) - delta
		if float(p["t_giro"]) <= 0.0:
			# Giro SUAVE (no un rumbo nuevo de cero): un pez no da volantazos de 180 grados.
			var v: Vector2 = p["vel"]
			p["vel"] = v.rotated(randf_range(-1.1, 1.1))
			p["t_giro"] = randf_range(GIRO_MIN, GIRO_MAX)
		var pos: Vector2 = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
		# Rebote en las paredes del charco. El margen es MEDIO LARGO EN LOS DOS EJES, no largo en x
		# y alto en y: el pez esta GIRADO, asi que nadando en diagonal su morro ocupa en vertical
		# casi tanto como su largo. Midiendolo por ejes, una anguila cruzando en diagonal se salia
		# del agua por la punta.
		var margen: float = float(p["largo"]) * 0.5 + 1.0
		var lim: Vector2 = (tam * 0.5 - Vector2(margen, margen)).maxf(2.0)
		if absf(pos.x) > lim.x:
			pos.x = clampf(pos.x, -lim.x, lim.x)
			p["vel"] = Vector2(-(p["vel"] as Vector2).x, (p["vel"] as Vector2).y)
		if absf(pos.y) > lim.y:
			pos.y = clampf(pos.y, -lim.y, lim.y)
			p["vel"] = Vector2((p["vel"] as Vector2).x, -(p["vel"] as Vector2).y)
		p["pos"] = pos
		# El cuerpo se orienta con el rumbo: asi la anguila se lee como anguila al cruzar el charco.
		(p["rect"] as ColorRect).rotation = (p["vel"] as Vector2).angle()
		_colocar(p)


func _pez_es(p: Dictionary) -> bool:
	return not _pez.is_empty() and p["rect"] == _pez["rect"]


# ------------------------------------------------------------
#  ENTRADA: la F del jugador
# ------------------------------------------------------------
func interactuar() -> void:
	if _estado != LIBRE:
		return
	# Sin CAÑA no se pesca, y punto. Es la unica herramienta sin version "de serie" (ver Game.cana):
	# picar a mano se puede, pescar sin sedal no.
	if Game.cana() == null:
		_decir("Necesitas una caña de pescar. Te la forja el herrero.")
		return
	if _peces.is_empty():
		# Puede ser por dos motivos y conviene distinguirlos: o lo has vaciado (y toca esperar a que
		# el banco se reponga) o simplemente aun no ha salido el siguiente.
		if _stock <= 0:
			_decir("Has dejado el charco seco. Dale un rato y volverán.")
		else:
			_decir("El agua está quieta. Espera un momento.")
		return
	_lanzar()


func _decir(txt: String) -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("mostrar_toast"):
		hud.mostrar_toast(txt)


# ------------------------------------------------------------
#  EL CICLO
# ------------------------------------------------------------
func _lanzar() -> void:
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		return
	# El modal BLOQUEA al jugador (player consulta Game.hay_modal para no moverse ni atacar) y en
	# solitario ademas pausa el arbol, que es justo lo que quiero: los bichos se paran mientras
	# peleas con el pez. Ojo: por eso este nodo es PROCESS_MODE_ALWAYS.
	Game.entrar_modal(Game.Modal.RECOLECCION, self)

	# El corcho cae en un punto del agua del lado por el que estas: el hilo no cruza el charco entero.
	var hacia: Vector2 = to_local(jugador.global_position).normalized()
	var tam: Vector2 = tam_px()
	_corcho_base = Vector2(
		clampf(hacia.x * tam.x * 0.28, -tam.x * 0.4, tam.x * 0.4),
		clampf(hacia.y * tam.y * 0.28, -tam.y * 0.4, tam.y * 0.4))

	_estado = LANZANDO
	_t = 0.0
	_press_was = true   # la F de lanzar no debe contar como el ESPACIO del tiron
	_hilo.visible = true
	_corcho.visible = true
	_pintar_corcho(Vector2.ZERO)


func _process(delta: float) -> void:
	_nadar(delta)
	_reponer(delta)
	if _estado == LIBRE:
		return
	_t += delta
	match _estado:
		LANZANDO: _paso_lanzando()
		ESPERA: _paso_espera()
		PICANDO: _paso_picando()
		TIRON: _paso_tiron()
		# Mientras luchas, el hilo VIBRA: es lo que hace que la barra de tension de la capa de
		# arriba se lea como algo que esta pasando en el agua y no como un widget suelto.
		LUCHA: _pintar_corcho(Vector2(randf_range(-2.0, 2.0), randf_range(-1.0, 3.0)))
		COBRO: _paso_cobro(delta)
	_press_was = Input.is_key_pressed(KEY_SPACE)


# Saca UNO del banco al agua cada REPONER segundos, y RE-ARMA el reloj mientras el agua siga por
# debajo del aforo. Sin ese re-armado solo volvia un pez por temporizador: quitar dos seguidos
# (pescar uno y perder otro) dejaba el charco permanentemente corto.
#
# Aqui tambien se atienden los dos relojes lentos, que corren aunque no estes pescando: los peces que
# vuelven al banco y la revision del aforo.
func _reponer(delta: float) -> void:
	var antes: int = _stock
	_cobrar_vueltas()
	_revisar_aforo()
	if _stock != antes:
		_guardar_estado()
		_armar_reposicion()   # ha entrado uno al banco: que salga al agua si hace falta

	if _t_reponer <= 0.0:
		return
	_t_reponer -= delta
	if _t_reponer > 0.0:
		return
	if _hay_sitio_en_el_agua():
		_nacer_pez()
	_armar_reposicion()


# ¿Cabe otro pez en el agua? Hacen falta las DOS cosas: hueco en la superficie (aforo) y una pieza
# en el banco. Es lo que separa "solo se ven cuatro" de "solo quedan cuatro".
func _hay_sitio_en_el_agua() -> bool:
	return _peces.size() < _aforo and _peces.size() < _stock


func _armar_reposicion() -> void:
	if _t_reponer <= 0.0 and _hay_sitio_en_el_agua():
		_t_reponer = REPONER


func _paso_lanzando() -> void:
	var t: float = clampf(_t / VUELO, 0.0, 1.0)
	_pintar_hilo(_corcho_base, t)
	if t >= 1.0:
		_estado = ESPERA
		_t = 0.0


# El pez que CHOCA con el corcho se engancha. Solo puede haber uno: si ya hay enganchado, este
# metodo ni corre (el estado ya no es ESPERA) y los demas siguen nadando tan tranquilos.
func _paso_espera() -> void:
	_pintar_corcho(Vector2(0.0, sin(_t * 2.2) * 1.2))   # cabeceo tonto en el agua
	for p in _peces:
		var d: Vector2 = (p["pos"] as Vector2) - _corcho_base
		if absf(d.x) < float(p["largo"]) * 0.5 + 6.0 and absf(d.y) < float(p["alto"]) * 0.5 + 6.0:
			_morder(p)
			return


func _morder(p: Dictionary) -> void:
	_pez = p
	_estado = PICANDO
	_t = 0.0
	_toques = 0
	_toques_max = randi_range(2, 4)
	# La CAÑA se cobra AQUI: su 'golpes_menos' no quita tirones (no hay), alarga la ventana en la
	# que puedes clavarlo. Es donde de verdad se pierden los peces cuando empiezas.
	var tm: Dictionary = Game.tool_mods(Game.cana())
	_ventana = VENTANA_BASE + float(int(tm["golpes_menos"])) * VENTANA_POR_PUNTO


func _paso_picando() -> void:
	# Pulsar durante el picoteo ESPANTA al pez: el toque flojo es una finta, no la mordida.
	if _espacio_nuevo():
		_escapar("Has tirado demasiado pronto: el pez suelta el cebo.")
		return
	var fase: float = _t / TOQUE_DUR
	_pintar_corcho(Vector2(0.0, sin(fase * TAU) * TOQUE_AMP))
	if fase >= 1.0:
		_t = 0.0
		_toques += 1
		if _toques >= _toques_max:
			_estado = TIRON


func _paso_tiron() -> void:
	# El corcho SE HUNDE y tiembla fuerte: es la señal, y dura lo que dure la ventana.
	_pintar_corcho(Vector2(randf_range(-1.5, 1.5), TIRON_AMP + randf_range(-2.0, 2.0)))
	if _espacio_nuevo():
		_pelear()
		return
	if _t >= _ventana:
		_escapar("Se te ha escapado: has tardado en tirar.")


func _espacio_nuevo() -> bool:
	return Input.is_key_pressed(KEY_SPACE) and not _press_was


func _pelear() -> void:
	_estado = LUCHA
	_t = 0.0
	Game.start_pesca(self, _pez["data"], float(_pez["cm"]))


# Lo llama Game al terminar el minijuego. 'logrado' = has llenado la barra de tension.
func terminar_lucha(logrado: bool) -> void:
	if _estado != LUCHA:
		return
	if not logrado:
		_escapar("El pez se suelta y se va al fondo.")
		return
	_estado = COBRO
	_t = 0.0


# Se te ha escapado. El pez se va DEL AGUA (si se quedase volveria a morder a los tres segundos y
# fallar no costaria nada) pero NO SALE DEL BANCO: sigue vivo en el charco y vuelve a salir en unos
# segundos. Perder una pieza cuesta el rato y la excelia, no tu presupuesto de diez minutos.
func _escapar(motivo: String) -> void:
	_decir(motivo)
	_quitar_pez(false)
	_soltar()


# 'pescado' distingue las dos formas de salir del agua:
#   true  -> te lo llevas: sale del BANCO y arranca SU contador de 10 minutos para volver.
#   false -> se te ha escapado: el banco no se toca, solo vuelve a la cola de salida.
func _quitar_pez(pescado: bool) -> void:
	if _pez.is_empty():
		return
	var i: int = _peces.find(_pez)
	if i >= 0:
		(_peces[i]["rect"] as ColorRect).queue_free()
		_peces.remove_at(i)
	_pez = {}
	if pescado:
		_stock = maxi(0, _stock - 1)
		# SU propio sello, no uno compartido: diez capturas seguidas son diez vueltas escalonadas y
		# no una sola espera. Es lo que hace que vaciar el charco cueste de verdad.
		_vuelven.append(Game.tiempo_mazmorra + STOCK_REGEN)
		_guardar_estado()
	_armar_reposicion()


func _soltar() -> void:
	_estado = LIBRE
	_t = 0.0
	_hilo.visible = false
	_corcho.visible = false
	Game.salir_modal(self)
	# El minijuego se juega a espaciazos y lanzar es F: sin esto, la ultima pulsacion vuelve a
	# echar el sedal (o te lanza contra el bicho que tengas al lado) nada mas soltar.
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador != null and jugador.has_method("bloquear_interaccion"):
		jugador.bloquear_interaccion()


# --- COBRO: el pez viene por el hilo, y SOLO al llegar es tuyo ---
func _paso_cobro(_delta: float) -> void:
	var jugador = get_tree().get_first_node_in_group("player")
	var destino: Vector2 = to_local(jugador.global_position) if jugador != null else Vector2.ZERO
	var t: float = clampf(_t / COBRO_DUR, 0.0, 1.0)
	var aqui: Vector2 = _corcho_base.lerp(destino, ease(t, 0.4))
	_pintar_corcho_en(aqui)
	if not _pez.is_empty():
		var rect: ColorRect = _pez["rect"]
		rect.position = aqui - rect.size * 0.5
	if t >= 1.0:
		_cobrar()


func _cobrar() -> void:
	var d: MaterialData = _pez.get("data", null)
	var cm: float = float(_pez.get("cm", 0.0))
	_quitar_pez(true)   # este SI sale del banco: te lo llevas puesto
	_soltar()
	if d == null:
		return
	Game.cobrar_pesca(d, cm)


# ------------------------------------------------------------
#  PINTAR la caña
# ------------------------------------------------------------
# El hilo NO es una recta: sale del personaje, sube a un pico por encima de el y cae al agua, tal y
# como se lanza de verdad. 'vuelo' < 1 lo dibuja a medio camino (el lanzamiento).
func _pintar_hilo(punta: Vector2, vuelo: float = 1.0) -> void:
	var jugador = get_tree().get_first_node_in_group("player")
	if jugador == null:
		_hilo.visible = false
		return
	var ini: Vector2 = to_local(jugador.global_position) + Vector2(0.0, -10.0)
	var fin: Vector2 = ini.lerp(punta, clampf(vuelo, 0.0, 1.0))
	# El pico del arco: el punto medio, subido. Se dibuja con una parabola de tres puntos por
	# Bezier cuadratica, muestreada en unos pocos tramos (un Line2D no curva solo).
	var alto: Vector2 = (ini + fin) * 0.5 + Vector2(0.0, -ARCO_ALTO * clampf(vuelo, 0.2, 1.0))
	var pts := PackedVector2Array()
	for i in range(9):
		var u: float = float(i) / 8.0
		pts.append(ini.lerp(alto, u).lerp(alto.lerp(fin, u), u))
	_hilo.points = pts


func _pintar_corcho(desvio: Vector2) -> void:
	_pintar_corcho_en(_corcho_base + desvio)


func _pintar_corcho_en(pos: Vector2) -> void:
	_corcho.position = pos - _corcho.size * 0.5
	_pintar_hilo(pos)
