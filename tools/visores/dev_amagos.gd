# ============================================================
#  dev_amagos.gd  --  TODOS LOS AMAGOS DEL GACHA, uno detras de otro.
#
#  dev_ritual.bat enseña UNA animacion y con F se le enciende el amago. Esto es lo otro que hace
#  falta: ver los amagos SEGUIDOS y comparados, porque lo que hay que juzgar no es uno suelto sino
#  si la escalera se lee -- si un comun->epico se distingue de un comun->mitico, y si un
#  epico->legendario (el de una tanda con pity) se nota tanto como uno que sale de la nada.
#
#  QUE COMBINACIONES SALEN, y no son todas las posibles: son las que el juego puede dar de verdad
#  (ver maestro_menu._mostrar_ritual). El amago solo existe de EPICO para arriba, y se miente con el
#  SUELO QUE EL JUGADOR YA SABE -- el comun de normal, o el garantizado si esa tanda traia uno. De
#  ahi salen seis y no dieciocho.
#
#  A VELOCIDAD DE PERSONA. Por defecto va a 0,6x, que es cuando el cambio se puede mirar en vez de
#  intuir: a velocidad real el fogonazo dura tres fotogramas y lo unico que se puede decir de el es
#  "algo ha pasado". Con +/- se sube hasta la de verdad para comprobar el ritmo final, que es otra
#  pregunta distinta.
#
#  El reloj lo lleva ESTE nodo (plantar), igual que dev_ritual y por lo mismo: la capa no duplica ni
#  una linea de animacion, solo se le dice donde esta.
# ============================================================

extends Control

const GachaRitual = preload("res://scripts/ui/gacha_ritual.gd")

# LOS SEIS AMAGOS QUE EL JUEGO PUEDE DAR: [rareza fingida, rareza real].
# Las tres primeras son las corrientes (se miente con el comun); las tres de abajo son las de una
# tanda CON GARANTIZADO, donde mentir por debajo del suelo se delataria solo.
const AMAGOS := [
	[Upgrades.Rareza.COMUN, Upgrades.Rareza.EPICO],
	[Upgrades.Rareza.COMUN, Upgrades.Rareza.LEGENDARIO],
	[Upgrades.Rareza.COMUN, Upgrades.Rareza.MITICO],
	[Upgrades.Rareza.EPICO, Upgrades.Rareza.LEGENDARIO],
	[Upgrades.Rareza.EPICO, Upgrades.Rareza.MITICO],
	[Upgrades.Rareza.LEGENDARIO, Upgrades.Rareza.MITICO],
]

const NOMBRE := ["Común", "Poco común", "Raro", "Épico", "Legendario", "Mítico"]

# El sonido del brillo de cada rareza, IGUAL que la tabla del menu. Se copia y no se importa porque
# maestro_menu es una KinematicLayer entera con su estado: para un visor no se instancia un menu.
# Si alla se toca, tocarlo aqui (son cuatro lineas y el visor canta enseguida si se olvidan).
const SFX := {
	Upgrades.Rareza.COMUN: "gacha_brillo_comun",
	Upgrades.Rareza.POCO_COMUN: "gacha_brillo_comun",
	Upgrades.Rareza.RARO: "gacha_brillo_raro",
	Upgrades.Rareza.EPICO: "gacha_brillo_epico",
	Upgrades.Rareza.LEGENDARIO: "gacha_brillo_god",
	Upgrades.Rareza.MITICO: "gacha_brillo_god",
}

# LA PAUSA ENTRE UNO Y OTRO. Sin ella, el siguiente arranca en el mismo fotograma en que muere el
# anterior y los seis se leen como una sola cosa larga: lo que se quiere comparar es el remate de
# cada uno, y para eso hace falta un respiro en negro.
const RESPIRO := 0.8

var _i: int = 0
var _vel: float = 0.6
var _pausa: bool = false
var _solo: bool = false        # quedarse en el mismo en vez de pasar al siguiente
var _espera: float = 0.0
var _ritual: Control = null
var _hud: Label = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# ALWAYS por lo mismo que dev_ritual: en el juego esto vive dentro de un menu que para el arbol.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var fondo := ColorRect.new()
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.color = Color(0.02, 0.02, 0.03)
	add_child(fondo)

	_hud = Label.new()
	_hud.position = Vector2(16, 12)
	_hud.add_theme_font_size_override("font_size", 14)
	# Por encima del ritual, que llega a z 2600: si no, el fogonazo se come el cartel justo cuando
	# hace falta leer cual se esta mirando.
	_hud.z_index = 3000
	add_child(_hud)

	_lanzar()


func _lanzar() -> void:
	if _ritual != null and is_instance_valid(_ritual):
		# remove_child ADEMAS de queue_free: queue_free no saca del arbol hasta el final del frame y
		# dos pases seguidos se dibujarian superpuestos. Misma trampa que en el menu.
		if _ritual.get_parent() != null:
			_ritual.get_parent().remove_child(_ritual)
		_ritual.queue_free()
	_ritual = GachaRitual.new()
	var falso: int = int(AMAGOS[_i][0])
	var real: int = int(AMAGOS[_i][1])
	_ritual.montar(self, Upgrades.rareza_color(real), _acabado,
		String(SFX[real]), "",
		Upgrades.rareza_color(falso), String(SFX[falso]))
	# Su reloj apagado: lo lleva este visor. Con los dos corriendo la animacion va al doble de
	# velocidad, que en un visor de ritmo es el peor fallo posible -- no da error, y lo que se juzga
	# es una mentira.
	_ritual.set_process(false)
	_pintar_hud()


# Al terminar uno, un respiro y el siguiente (o el mismo otra vez, con S).
func _acabado() -> void:
	_espera = RESPIRO


func _pintar_hud() -> void:
	var falso: int = int(AMAGOS[_i][0])
	var real: int = int(AMAGOS[_i][1])
	_hud.text = "%d/%d   %s  →  %s%s     ·  x%.2f%s     ·  ESPACIO repite  ←/→ cual  S fijar  P pausa  ,/. paso  +/- velocidad" % [
		_i + 1, AMAGOS.size(), NOMBRE[falso], NOMBRE[real],
		"   (con garantizado)" if falso > Upgrades.Rareza.COMUN else "",
		_vel, "  (EN PAUSA)" if _pausa else ""]
	_hud.add_theme_color_override("font_color", Upgrades.rareza_color(real))


func _process(delta: float) -> void:
	if _espera > 0.0:
		_espera -= delta * _vel
		if _espera <= 0.0:
			if not _solo:
				_i = (_i + 1) % AMAGOS.size()
			_lanzar()
		return
	if _ritual == null or not is_instance_valid(_ritual) or _pausa:
		return
	_ritual.plantar(_ritual.reloj() + delta * _vel)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and (e as InputEventKey).pressed and not (e as InputEventKey).echo):
		return
	match (e as InputEventKey).keycode:
		KEY_ESCAPE:
			get_tree().quit()
		KEY_SPACE:
			_espera = 0.0
			_lanzar()
		KEY_RIGHT:
			_i = (_i + 1) % AMAGOS.size()
			_espera = 0.0
			_lanzar()
		KEY_LEFT:
			_i = (_i - 1 + AMAGOS.size()) % AMAGOS.size()
			_espera = 0.0
			_lanzar()
		KEY_S:
			_solo = not _solo
			_pintar_hud()
		KEY_P:
			_pausa = not _pausa
			_pintar_hud()
		KEY_COMMA:
			if _ritual != null and is_instance_valid(_ritual):
				_ritual.plantar(_ritual.reloj() - 0.05)
		KEY_PERIOD:
			if _ritual != null and is_instance_valid(_ritual):
				_ritual.plantar(_ritual.reloj() + 0.05)
		KEY_EQUAL, KEY_KP_ADD:
			_vel = minf(_vel * 1.25, 4.0)
			_pintar_hud()
		KEY_MINUS, KEY_KP_SUBTRACT:
			_vel = maxf(_vel / 1.25, 0.15)
			_pintar_hud()
