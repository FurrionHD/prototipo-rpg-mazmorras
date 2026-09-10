# ============================================================
#  dev_amagos.gd  --  EL AMAGO DE LA CARTA, los seis, uno detras de otro.
#
#  El amago (el "fakeout") pasa AL VOLTEAR: la carta sale con la cara del comun, se queda asi el rato
#  justo para que te la creas, y entonces revienta en blanco y sale la de verdad. En el juego cae en
#  el 22% de las tandas de epico o mejor, asi que verlo a base de tirar seria cosa de veinte tiradas
#  por cada combinacion: esto las pone las seis en fila.
#
#  QUE COMBINACIONES SALEN, y no son todas las posibles: son las que el juego puede dar (ver
#  maestro_menu._mostrar_ritual). Solo hay amago de EPICO para arriba, y se finge el SUELO QUE EL
#  JUGADOR YA SABE -- el comun de normal, o el garantizado si esa tanda traia pity. De ahi salen seis.
#
#  LOS TIEMPOS SALEN DE maestro_menu, no copiados aqui. Es lo unico que impide que el visor y el
#  juego se separen: el dia que la espera del amago cambie alla, esto cambia solo. Lo que si es una
#  MAQUETA es el resto -- aqui no hay menu, ni pool, ni tirada: una carta, su volteo y su
#  transformacion, que es exactamente lo que hay que mirar.
#
#  A VELOCIDAD DE PERSONA: 0,6x por defecto, que es cuando el fogonazo se puede mirar en vez de
#  intuir. Con + se sube a la de verdad, que es otra pregunta (esa es de ritmo, no de lectura).
# ============================================================

extends Control

const GachaBanner = preload("res://scripts/ui/gacha_banner.gd")
# El menu no tiene class_name, asi que se precarga el script para leerle las constantes. No se
# instancia nada suyo: es una CanvasLayer con su estado, su pool y su guardado.
const MM = preload("res://scripts/ui/maestro_menu.gd")

# [rareza fingida, rareza real]. Las tres primeras son las corrientes (se miente con el comun); las
# tres de abajo son las de una tanda CON GARANTIZADO, donde mentir por debajo del suelo se delataria.
const AMAGOS := [
	[Upgrades.Rareza.COMUN, Upgrades.Rareza.EPICO],
	[Upgrades.Rareza.COMUN, Upgrades.Rareza.LEGENDARIO],
	[Upgrades.Rareza.COMUN, Upgrades.Rareza.MITICO],
	[Upgrades.Rareza.EPICO, Upgrades.Rareza.LEGENDARIO],
	[Upgrades.Rareza.EPICO, Upgrades.Rareza.MITICO],
	[Upgrades.Rareza.LEGENDARIO, Upgrades.Rareza.MITICO],
]

const NOMBRE := ["Común", "Poco común", "Raro", "Épico", "Legendario", "Mítico"]

# Misma tabla que la del menu, para que se oiga lo que se va a oir en el juego.
const SFX_VOLTEA := {
	Upgrades.Rareza.RARO: "gacha_voltea_bueno",
	Upgrades.Rareza.EPICO: "gacha_voltea_bueno",
	Upgrades.Rareza.LEGENDARIO: "gacha_voltea_god",
	Upgrades.Rareza.MITICO: "gacha_voltea_god",
}

const ANCHO := 250.0
const ALTO := 340.0
# El respiro entre uno y otro. Sin el, el siguiente arranca en el fotograma en que muere el anterior
# y los seis se leen como una sola cosa larga, justo cuando lo que se compara es el remate de cada uno.
const RESPIRO := 1.0

var _i: int = 0
var _vel: float = 0.6
var _pausa: bool = false
var _solo: bool = false      # quedarse en el mismo en vez de pasar al siguiente
var _t: float = 0.0          # reloj de la maqueta, en segundos "de juego"
var _fase: int = 0           # 0 dorso, 1 cara fingida, 2 ya transformada
var _carta: Control = null
var _banner: Control = null
var _hud: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ALWAYS por lo mismo que dev_ritual: en el juego esto vive dentro de un menu que para el arbol.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.04, 0.04, 0.06)
	add_child(fondo)

	# El banner es quien sabe DIBUJAR un tomo. Se cuelga del arbol invisible en vez de dejarlo
	# suelto: asi se libera con el visor y no hay que acordarse de nada.
	_banner = GachaBanner.new()
	_banner.visible = false
	add_child(_banner)

	_carta = Control.new()
	_carta.set_anchors_preset(Control.PRESET_CENTER)
	_carta.custom_minimum_size = Vector2(ANCHO, ALTO)
	_carta.size = Vector2(ANCHO, ALTO)
	_carta.offset_left = -ANCHO * 0.5
	_carta.offset_right = ANCHO * 0.5
	_carta.offset_top = -ALTO * 0.5
	_carta.offset_bottom = ALTO * 0.5
	_carta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# EL PIVOTE EN EL CENTRO, igual que en el menu: con el de fabrica (la esquina) el volteo manda la
	# carta hacia la izquierda en vez de girarla sobre si misma.
	_carta.pivot_offset = Vector2(ANCHO, ALTO) * 0.5
	_carta.draw.connect(_dibujar)
	add_child(_carta)

	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 14)
	add_child(_hud)

	_lanzar()


func _lanzar() -> void:
	_t = 0.0
	_fase = 0
	_carta.scale.x = 1.0
	_carta.modulate = Color.WHITE
	_carta.queue_redraw()
	_pintar_hud()


func _falso() -> int:
	return int(AMAGOS[_i][0])


func _real() -> int:
	return int(AMAGOS[_i][1])


# El color de una rareza. Aqui SIEMPRE es un grimorio (es lo unico que tiene amago), asi que basta
# con la escala de rarezas -- en el menu se pasa ademas por la seccion de biblioteca.
func _col(r: int) -> Color:
	return Upgrades.rareza_color(r)


func _dibujar() -> void:
	if _fase == 0:
		_banner.dibujar_dorso(_carta)
		return
	var r: int = _falso() if _fase == 1 else _real()
	_banner.dibujar_tomo(_carta, _col(r), r >= Upgrades.Rareza.EPICO, GachaBanner.FAM_GRIMORIO)


# LA LINEA DE TIEMPOS, la misma que teje el menu con sus tweens:
#   0                        empieza a cerrarse (ensena el dorso)
#   VOLTEO_MEDIO             de canto: se cambia el dibujo por el FINGIDO
#   VOLTEO_MEDIO*2           ya esta abierta del todo
#   + AMAGO_ESPERA           se rompe: sale la de verdad y el fogonazo
#   + AMAGO_FOGONAZO         el blanco se ha ido
func _process(delta: float) -> void:
	if _pausa:
		return
	var antes: float = _t
	_t += delta * _vel
	var medio: float = MM.VOLTEO_MEDIO
	var rompe: float = medio * 2.0 + MM.AMAGO_ESPERA

	# EL VOLTEO: se cierra en X hasta cero y se vuelve a abrir. Es un escalado, ni 3D ni shader, y se
	# lee perfectamente como "se ha dado la vuelta".
	if _t < medio:
		_carta.scale.x = maxf(0.02, 1.0 - _t / medio)
	elif _t < medio * 2.0:
		_carta.scale.x = maxf(0.02, (_t - medio) / medio)
	else:
		_carta.scale.x = 1.0

	if _fase == 0 and _t >= medio:
		_fase = 1
		_carta.queue_redraw()
		# El volteo suena a la rareza QUE SE VE, no a la que es: el dorado sobre una carta que se ve
		# comun cantaria el truco antes que la imagen.
		Sonido.ui(String(SFX_VOLTEA.get(_falso(), "gacha_voltea")))
	if _fase == 1 and _t >= rompe:
		_fase = 2
		_carta.queue_redraw()
		_carta.modulate = Color(2.4, 2.4, 2.4)
		Sonido.ui("gacha_voltea_god")
		Sonido.estrellas(_real() + 1)
		_pintar_hud()
	if _fase == 2 and antes < rompe + MM.AMAGO_FOGONAZO:
		# El fogonazo cayendo a su color. A mano y no con un tween para que + y - lo afecten igual
		# que a todo lo demas: un tween con su propio reloj se veria a otra velocidad.
		var k: float = clampf((_t - rompe) / MM.AMAGO_FOGONAZO, 0.0, 1.0)
		_carta.modulate = Color(2.4, 2.4, 2.4).lerp(Color.WHITE, k)

	if _t >= rompe + MM.AMAGO_FOGONAZO + RESPIRO:
		if not _solo:
			_i = (_i + 1) % AMAGOS.size()
		_lanzar()


func _pintar_hud() -> void:
	_hud.text = "%d/%d   %s  →  %s%s     ·  x%.2f%s     ·  ESPACIO repite  ←/→ cual  S fijar  P pausa  +/- velocidad" % [
		_i + 1, AMAGOS.size(), NOMBRE[_falso()], NOMBRE[_real()],
		"   (tanda con garantizado)" if _falso() > Upgrades.Rareza.COMUN else "",
		_vel, "  (EN PAUSA)" if _pausa else ""]
	_hud.add_theme_color_override("font_color",
		_col(_real() if _fase == 2 else _falso()))


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo):
		return
	match (e as InputEventKey).keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			_lanzar()
		KEY_RIGHT:
			_i = (_i + 1) % AMAGOS.size()
			_lanzar()
		KEY_LEFT:
			_i = (_i - 1 + AMAGOS.size()) % AMAGOS.size()
			_lanzar()
		KEY_S:
			_solo = not _solo
			_pintar_hud()
		KEY_P:
			_pausa = not _pausa
			_pintar_hud()
		KEY_EQUAL, KEY_KP_ADD:
			_vel = minf(_vel * 1.25, 4.0)
			_pintar_hud()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_vel = maxf(_vel / 1.25, 0.15)
			_pintar_hud()
