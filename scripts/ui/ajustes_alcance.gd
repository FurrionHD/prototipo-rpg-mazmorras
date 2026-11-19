# ============================================================
#  ajustes_alcance.gd  (VBoxContainer creado por codigo; Ajustes > Juego, con scroll)
#  LOS CIRCULOS DEL MAPA TACTICO (18-19/11, sus decisiones). Dos botones, PERSONAJES y ENEMIGOS; cada uno abre debajo
#  sus dos circulos, el de ALCANCE y el de MOVIMIENTO, cada uno con sus mandos (ajustes_circulo.gd). Pulsar otra vez el
#  abierto lo CIERRA, y de serie esta todo cerrado: «si no abulta un monton si es que metemos mas opciones en un futuro».
#  Los de alcance vienen APAGADOS de serie; los de movimiento, visibles.
# ============================================================

extends VBoxContainer

const AjustesCirculo = preload("res://scripts/ui/ajustes_circulo.gd")

const ANCHO := 420.0
const HUECO := 12.0
const MEDIO := (ANCHO - HUECO) / 2.0
const AMBAR := Color(0.95, 0.72, 0.36)
const GRIS := Color(0.62, 0.64, 0.70)
# Cada bando: su boton y sus dos circulos (clave de Preferencias.alcance y titulo).
const BANDOS := [
	{"clave": "tuyos", "titulo": "Personajes", "circulos": [["tuyos", "Círculo de alcance"],
		["mov_tuyos", "Círculo de movimiento"]]},
	{"clave": "enemigos", "titulo": "Enemigos", "circulos": [["enemigos", "Círculo de alcance"],
		["mov_enemigos", "Círculo de movimiento"]]},
]

var abierto: String = ""   # el bando abierto ("" = los dos cerrados)
var _botones: Dictionary = {}   # bando -> Button
var _cuerpos: Dictionary = {}   # bando -> VBoxContainer con sus circulos
var _bloques: Array = []


func _ready() -> void:
	add_theme_constant_override("separation", 6)

	var tit := Label.new()
	tit.text = "Círculos de movimiento y alcance"
	tit.add_theme_font_size_override("font_size", 15)
	tit.add_theme_color_override("font_color", AMBAR)
	add_child(tit)

	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", int(HUECO))
	add_child(fila)
	for b in BANDOS:
		var k: String = String(b["clave"])
		var boton := Button.new()
		boton.text = String(b["titulo"])
		boton.custom_minimum_size = Vector2(MEDIO, 34)
		boton.add_theme_font_size_override("font_size", 14)
		boton.pressed.connect(_pulsar.bind(k))
		boton.draw.connect(_flecha.bind(boton, k))
		fila.add_child(boton)
		_botones[k] = boton

	for b in BANDOS:
		var k: String = String(b["clave"])
		var cuerpo := VBoxContainer.new()
		cuerpo.add_theme_constant_override("separation", 14)
		add_child(cuerpo)
		_cuerpos[k] = cuerpo
		for c in b["circulos"]:
			var bloque = AjustesCirculo.new()
			bloque.clave = String(c[0])
			bloque.titulo = String(c[1])
			cuerpo.add_child(bloque)
			_bloques.append(bloque)

	_pintar_bandos()


func refrescar() -> void:
	for b in _bloques:
		b.refrescar()


# Pulsar el cerrado lo abre (y cierra el otro); pulsar el abierto lo cierra.
func _pulsar(k: String) -> void:
	abierto = "" if abierto == k else k
	_pintar_bandos()


func _pintar_bandos() -> void:
	for b in BANDOS:
		var k: String = String(b["clave"])
		var abre: bool = abierto == k
		_cuerpos[k].visible = abre
		var boton: Button = _botones[k]
		# El abierto en AMBAR, como la pestaña elegida de arriba.
		for estado in ["font_color", "font_pressed_color", "font_hover_pressed_color", "font_hover_color"]:
			boton.add_theme_color_override(estado, AMBAR if abre else GRIS)
		boton.queue_redraw()


# LA FLECHA, dibujada en pixel a la izquierda del boton (no una letra: nada que no sea pixel a la vista): apunta a la
# derecha cerrado y hacia abajo abierto.
func _flecha(boton: Button, k: String) -> void:
	var abre: bool = abierto == k
	var col: Color = AMBAR if abre else GRIS
	const P := 2.0   # cada pixel de la flecha, 2 x 2
	var o := Vector2(12.0, (boton.size.y - 7.0 * P) * 0.5).floor()
	for i in 4:
		if abre:   # hacia abajo: filas que se estrechan
			boton.draw_rect(Rect2(o + Vector2(i * P, (i + 1.5) * P), Vector2((7 - 2 * i) * P, P)), col)
		else:      # a la derecha: columnas que se acortan
			boton.draw_rect(Rect2(o + Vector2(i * P, i * P), Vector2(P, (7 - 2 * i) * P)), col)
