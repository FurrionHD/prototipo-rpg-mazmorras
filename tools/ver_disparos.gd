# HOJAS DE LOS DISPAROS DEL ARCO Y LA BALLESTA (02/10), al estilo de ver_ataques_dirs: suelo de losetas, tu en azul y
# los enemigos en rojo, una fila por direccion (N, NE, E, SE, S) y en cada fila el disparo en varios momentos, hasta
# lo que se queda CLAVADO (la ultima columna, ya quieto). CON VENTANA.
#   DISPAROS_SALIDA=/carpeta godot --path . res://tools/ver_disparos.tscn
extends Node2D

const LADO := 420
const DIRS := [["N", Vector2(0, -1)], ["NE", Vector2(1, -1)], ["E", Vector2(1, 0)],
	["SE", Vector2(1, 1)], ["S", Vector2(0, 1)]]
const ROJO := Color(0.8, 0.35, 0.35)
const AZUL := Color(0.35, 0.6, 1.0)
const LEJOS := 84.0
# [nombre de la hoja, modo, fallo, en linea (dos enemigos), momentos]
const HOJAS := [
	["arco_basico", DistanciaAire.Modo.FLECHA, false, false, [-0.09, -0.04, 0.0, 0.05, 0.14, 0.6]],
	["arco_falla", DistanciaAire.Modo.FLECHA, true, false, [-0.09, -0.04, 0.0, 0.05, 0.14, 0.6]],
	["ballesta_basico", DistanciaAire.Modo.VIROTE, false, false, [-0.06, -0.03, 0.0, 0.04, 0.12, 0.6]],
	["ballesta_atraviesa", DistanciaAire.Modo.VIROTE, false, true, [-0.05, 0.0, 0.04, 0.08, 0.14, 0.7]],
]

var _cam: Camera2D
var _rotulo: Label


func _ready() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_cam.zoom = Vector2(3.0, 3.0)
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 17)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 6)
	capa.add_child(_rotulo)
	call_deferred("_correr")


func _draw() -> void:
	var r: int = 400
	for x in range(-r, r, 16):
		for y in range(-r, r, 16):
			var v: float = 0.17 + 0.015 * float((x / 16 + y / 16) % 2)
			draw_rect(Rect2(x, y, 16, 16), Color(v, v + 0.02, v + 0.035))
			draw_rect(Rect2(x, y, 16, 16), Color(0.11, 0.12, 0.14), false, 1.0)


# Una figura (14x26, los pies en 'p') y su "cuerpo": un Node2D en los pies, a la altura de los personajes, del que
# cuelga lo que se le clava (como el cuerpo de verdad en la pelea).
func _figura(p: Vector2, col: Color) -> Node2D:
	var cuerpo := Node2D.new()
	cuerpo.z_as_relative = false
	cuerpo.z_index = Game.Z_PERSONAJES
	add_child(cuerpo)
	cuerpo.global_position = p
	var fig := ColorRect.new()
	fig.color = col
	fig.size = Vector2(14, 26)
	fig.position = Vector2(-7, -26)
	cuerpo.add_child(fig)
	return cuerpo


func _caja(p: Vector2) -> Rect2:
	return Rect2(p - Vector2(7, 26), Vector2(14, 26))


# Avanza un efecto (y lo que haya clavado) hasta el instante 't' a pasitos, como la pelea.
func _llevar(nodos: Array, hasta: float, hecho: Array) -> void:
	while hecho[0] + 0.005 <= hasta:
		for n in nodos:
			if is_instance_valid(n) and n.has_method("_process"):
				n._process(0.005)
		hecho[0] += 0.005


func _correr() -> void:
	var salida: String = OS.get_environment("DISPAROS_SALIDA")
	if salida == "":
		salida = "user://disparos"
	DirAccess.make_dir_recursive_absolute(salida)
	BarridoAire.ritmo = 1.0
	for h in HOJAS:
		var nombre: String = h[0]
		var modo: int = h[1]
		var fallo: bool = h[2]
		var en_linea: bool = h[3]
		var tiempos: Array = h[4]
		var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
		for fila in DIRS.size():
			var dir: Vector2 = (DIRS[fila][1] as Vector2).normalized()
			var yo := Vector2.ZERO
			var tu: Node2D = _figura(yo, AZUL)
			var cuerpos: Array = [_figura(yo + dir * (LEJOS * (0.62 if en_linea else 1.0)), ROJO)]
			if en_linea:
				cuerpos.append(_figura(yo + dir * LEJOS * 1.15, ROJO))
			var lejos_cam: float = LEJOS * (1.15 if en_linea else 1.0) + (28.0 if fallo else 0.0)
			_cam.global_position = yo + dir * lejos_cam * 0.5 + Vector2(0, -12)
			var desde: Vector2 = _caja(yo).get_center()
			var efectos: Array = []
			var p1: Vector2 = (cuerpos[0] as Node2D).global_position
			var primero: int = DistanciaAire.Modo.VIROTE_PASA if en_linea else modo
			var d1 := DistanciaAire.disparo(self, primero, desde, _caja(p1), cuerpos[0], fallo, false,
				hash("%s%d" % [nombre, fila]), 0.2, 1.0)
			d1.set_process(false)
			efectos.append(d1)
			var hecho: Array = [-d1._vuelo]
			var t0: float = -d1._vuelo
			var segundo: DistanciaAire = null
			for col in tiempos.size():
				var t: float = float(tiempos[col])
				# EL QUE ATRAVIESA: el segundo virote sale de la espalda del primero en cuanto entra.
				if en_linea and segundo == null and t >= 0.0:
					_llevar(efectos, 0.006, hecho)
					var p2: Vector2 = (cuerpos[1] as Node2D).global_position
					segundo = DistanciaAire.disparo(self, modo, desde, _caja(p2), cuerpos[1], false, false,
						hash("%s%d b" % [nombre, fila]), 0.2, 1.0)
					segundo.set_process(false)
					# Su reloj empieza en su vuelo: se le adelanta lo que ya ha pasado desde el impacto del primero.
					segundo._t = -segundo._vuelo
					efectos.append(segundo)
				_llevar(efectos + get_tree().get_nodes_in_group(DistanciaAire.GRUPO_CLAVADAS), t, hecho)
				await _viñeta(hoja, col, fila, "%s · %s · %.2f s" % [nombre, DIRS[fila][0], t])
			for e in efectos:
				if is_instance_valid(e):
					e.queue_free()
			DistanciaAire.quitar_clavadas(get_tree())
			tu.queue_free()
			for c in cuerpos:
				(c as Node).queue_free()
			await get_tree().process_frame
		var ruta: String = "%s/%s.png" % [salida, nombre]
		hoja.save_png(ruta)
		print("[hoja] ", ruta)
	await _hoja_puntas(salida)
	get_tree().quit(0)


# LAS PUNTAS (02/10): una fila por material (la normal de madera y los nueve metales, de 2 en 2), disparando hacia
# el este: en vuelo, al entrar y ya clavada.
func _hoja_puntas(salida: String) -> void:
	var puntas: Array = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
	var tiempos: Array = [-0.05, 0.0, 0.6]
	var hoja := Image.create(LADO * tiempos.size() * 2, LADO * 5, false, Image.FORMAT_RGBA8)
	for i in puntas.size():
		var idx: int = puntas[i]
		var fila: int = i / 2
		var col0: int = (i % 2) * tiempos.size()
		var yo := Vector2.ZERO
		var tu: Node2D = _figura(yo, AZUL)
		var p1: Vector2 = yo + Vector2(LEJOS, 0)
		var cuerpo: Node2D = _figura(p1, ROJO)
		_cam.global_position = yo + Vector2(LEJOS * 0.5, -12)
		var d := DistanciaAire.disparo(self, DistanciaAire.Modo.FLECHA, _caja(yo).get_center(), _caja(p1), cuerpo,
			false, false, 77 + idx, 0.2, 1.0, idx)
		d.set_process(false)
		var hecho: Array = [-d._vuelo]
		var nombre: String = "madera" if idx == 0 else String((Game.municiones()[idx - 1] as MaterialData).nombre)
		for c in tiempos.size():
			_llevar([d] + get_tree().get_nodes_in_group(DistanciaAire.GRUPO_CLAVADAS), float(tiempos[c]), hecho)
			await _viñeta(hoja, col0 + c, fila, "%s · %.2f s" % [nombre, float(tiempos[c])])
		if is_instance_valid(d):
			d.queue_free()
		DistanciaAire.quitar_clavadas(get_tree())
		tu.queue_free()
		cuerpo.queue_free()
		await get_tree().process_frame
	var ruta: String = "%s/puntas.png" % salida
	hoja.save_png(ruta)
	print("[hoja] ", ruta)


func _viñeta(hoja: Image, col: int, fila: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(8, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)),
		Vector2i(col * LADO, fila * LADO))
