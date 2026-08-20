# Banco de efectos por la TUBERIA REAL de CombatFX. Se le dice que estilos probar en ESTILOS y
# saca capturas. Llamar a CapaHechizos.alta() a mano NO vale: se salta la puerta del `vuelo > 0`
# y un estilo mudo parece que funciona.
# NO forma parte del juego: borrar este fichero, su .tscn y sus .uid al terminar.
extends Control

const LENTITUD := 0.13

# [estilo, "a_uno"|"al_grupo", color]
var ESTILOS: Array = [
	[CombatFX.Estilo.PISOTON, "al_grupo", Color(0.55, 0.5, 0.45)],
	[CombatFX.Estilo.PISOTON, "a_uno", Color(0.55, 0.5, 0.45)],
]

var _fx: CombatFX
var _t: float = 0.0
var _i: int = 0
var _capturas: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var fondo := ColorRect.new()
	fondo.color = Color(0.13, 0.12, 0.15)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var capa := Control.new()
	capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(capa)
	_fx = CombatFX.new()
	add_child(_fx)
	_fx.capa_numeros = capa
	_fx.escala_tiempo = LENTITUD

	var victimas: Array[Dictionary] = []
	for i in 4:
		victimas.append(_tarjeta(Vector2(180 + i * 240, 150), "v%d" % i))
	var atacante: Dictionary = _tarjeta(Vector2(540, 470), "bicho")

	var t: int = 0
	for cfg in ESTILOS:
		var estilo: int = cfg[0]
		var col: Color = cfg[2]
		if String(cfg[1]) == "al_grupo":
			# OJO: tanda() solo vale para el SIGUIENTE encolar, hay que repetirla o cada golpe cae
			# en su propia tanda y los estilos de grupo no se funden.
			for v in victimas:
				_fx.tanda(t)
				_fx.encolar(atacante, v, 7.0, false, false, col, estilo, 1.0)
		else:
			_fx.tanda(t)
			_fx.encolar(atacante, victimas[1], 12.0, false, false, col, estilo, 1.0)
		t += 1
	var dur: float = _fx.arrancar_cola()
	print("cola: %.2f s  (%d bloques)" % [dur, ESTILOS.size()])
	# Una captura por bloque, hacia la mitad de su tramo. 'dur' YA viene en segundos de reloj: lo
	# dice la cabecera de arrancar_cola -- lo devuelve dividido por escala_tiempo, porque ese numero
	# es el que se convierte en la pausa del turno. Volver a dividirlo por la lentitud dejaba las
	# capturas mucho despues del final y salian en negro.
	for i in ESTILOS.size():
		_capturas.append(dur * (float(i) + 0.80) / float(ESTILOS.size()))
	move_child(capa, get_child_count() - 1)


# El panel es un PanelContainer como en el juego: es un CONTENEDOR y por eso redimensiona a sus
# hijos, que es lo que le da tamaño a la CapaEstado. Con un Control pelado se queda a 0x0.
func _tarjeta(pos: Vector2, nombre: String) -> Dictionary:
	var hueco := Control.new()
	hueco.position = pos
	hueco.size = Vector2(150, 90)
	hueco.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hueco)
	var p := PanelContainer.new()
	p.size = Vector2(150, 90)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.28, 0.26, 0.30)
	p.add_theme_stylebox_override("panel", sb)
	hueco.add_child(p)
	# El panel va DENTRO de un hueco y a cero: CombatFX hace `panel.position = mov` cada frame para
	# el temblor, asi que la posicion real no puede vivir en el panel o se apilan en el origen.
	var b: Dictionary = {"panel": p, "nombre": nombre}
	_fx.registrar(b)
	return b


func _process(delta: float) -> void:
	_t += delta
	if _i >= _capturas.size():
		get_tree().quit()
		return
	if _t < float(_capturas[_i]):
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev_b_%d.png" % _i)
	print("captura %d en t %.2f (reloj fx %.3f)" % [_i, _t, float(_fx.get("_t"))])
	_i += 1
