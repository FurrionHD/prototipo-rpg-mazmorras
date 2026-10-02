# HOJAS DE LOS DISPAROS DEL ARCO Y LA BALLESTA (02/10), al estilo de ver_ataques_dirs: suelo de losetas, tu en azul y
# los enemigos en rojo, una fila por direccion (N, NE, E, SE, S) y en cada fila el disparo en varios momentos, hasta
# lo que se queda CLAVADO (la ultima columna, ya quieto). Una hoja por el basico y por cada habilidad, y la de las
# PUNTAS (madera y los nueve metales). CON VENTANA.
#   DISPAROS_SALIDA=/carpeta [DISPAROS_LISTA=lluvia_flechas,perno_impacto] godot --path . res://tools/ver_disparos.tscn
#
# Los golpes salen COMO EN LA PELEA: los de una misma accion, a la vez (la cadena de DistanciaAire hace que lo que
# atraviesa se vea como UN proyectil). Cada evento sale lo que tarda en volar antes de su impacto.
extends Node2D

const LADO := 420
const DIRS := [["N", Vector2(0, -1)], ["NE", Vector2(1, -1)], ["E", Vector2(1, 0)],
	["SE", Vector2(1, 1)], ["S", Vector2(0, 1)]]
const ROJO := Color(0.8, 0.35, 0.35)
const AZUL := Color(0.35, 0.6, 1.0)
const ESPERA := 0.2   # el vuelo que le da la pelea (CombatFX.T_VUELO) de tope
const M := DistanciaAire.Modo
# nombre -> enemigos [distancia, lateral] (en la direccion de la fila), eventos [modo, a quien (-1 = a ti), impacto,
# fallo] y momentos.
const ESCENAS := {
	"arco_basico": {"e": [[100, 0]], "ev": [[M.FLECHA, 0, 0.3, false]], "t": [0.12, 0.2, 0.3, 0.36, 0.45, 0.9]},
	"arco_falla": {"e": [[100, 0]], "ev": [[M.FLECHA, 0, 0.3, true]], "t": [0.12, 0.2, 0.3, 0.36, 0.45, 0.9]},
	"ballesta_basico": {"e": [[100, 0]], "ev": [[M.VIROTE, 0, 0.3, false]], "t": [0.15, 0.22, 0.3, 0.34, 0.42, 0.9]},
	"ballesta_atraviesa": {"e": [[60, 0], [108, 0]], "ev": [[M.VIROTE_PASA, 0, 0.3, false], [M.VIROTE, 1, 0.3, false]],
		"t": [0.15, 0.24, 0.3, 0.35, 0.42, 0.9]},
	"disparo_cargado": {"e": [[110, 0]], "ev": [[M.TENSA, -1, 0.1, false], [M.FLECHA_GORDA, 0, 0.9, false]],
		"t": [0.1, 0.35, 0.6, 0.8, 0.9, 0.98, 1.5]},
	"lluvia_flechas": {"e": [[105, -20], [118, 16], [92, 6]],
		"ev": [[M.LLUVIA, 0, 0.35, false], [M.LLUVIA, 1, 0.35, false], [M.LLUVIA, 2, 0.35, false],
			[M.LLUVIA, 0, 0.47, false], [M.LLUVIA, 1, 0.47, false], [M.LLUVIA, 2, 0.47, false],
			[M.LLUVIA, 0, 0.59, false], [M.LLUVIA, 1, 0.59, false], [M.LLUVIA, 2, 0.59, false]],
		"t": [0.2, 0.33, 0.45, 0.58, 0.7, 1.3]},
	"disparo_perforante": {"e": [[55, 0], [90, 2], [125, -2]],
		"ev": [[M.FLECHA_PASA, 0, 0.3, false], [M.FLECHA_PASA, 1, 0.3, false], [M.FLECHA_PASA, 2, 0.3, false]],
		"t": [0.12, 0.2, 0.26, 0.32, 0.4, 0.9]},
	"flecha_clavadora": {"e": [[100, 0]], "ev": [[M.FLECHA_PIES, 0, 0.3, false]], "t": [0.15, 0.25, 0.3, 0.36, 0.5, 1.0]},
	"virote_pesado": {"e": [[55, 0], [90, 2], [125, -2]],
		"ev": [[M.VIROTE_GORDO, 0, 0.3, false], [M.VIROTE_GORDO, 1, 0.3, false], [M.VIROTE_GORDO, 2, 0.3, false]],
		"t": [0.15, 0.22, 0.27, 0.32, 0.4, 0.9]},
	"perno_impacto": {"e": [[95, 0]], "ev": [[M.PERNO, 0, 0.3, false]], "t": [0.15, 0.24, 0.3, 0.36, 0.48, 1.0]},
	"andanada": {"e": [[100, -32], [112, 0], [100, 32]],
		"ev": [[M.VIROTE, 0, 0.3, false], [M.VIROTE, 1, 0.3, false], [M.VIROTE, 2, 0.3, false]],
		"t": [0.15, 0.24, 0.3, 0.36, 0.45, 0.9]},
	"recarga_rapida": {"e": [], "ev": [[M.RECARGA, -1, 0.1, false]], "t": [0.0, 0.12, 0.25, 0.38, 0.5, 0.62]},
	"virote_clavo": {"e": [[100, 0]], "ev": [[M.VIROTE_PIES, 0, 0.3, false]], "t": [0.15, 0.24, 0.3, 0.36, 0.5, 1.0]},
}

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


func _correr() -> void:
	var salida: String = OS.get_environment("DISPAROS_SALIDA")
	if salida == "":
		salida = "user://disparos"
	DirAccess.make_dir_recursive_absolute(salida)
	var pedidas: String = OS.get_environment("DISPAROS_LISTA")
	BarridoAire.ritmo = 1.0
	for nombre in ESCENAS:
		if pedidas != "" and not (nombre in pedidas.split(",")):
			continue
		await _hoja(salida, nombre, ESCENAS[nombre])
	if pedidas == "" or "puntas" in pedidas.split(","):
		await _hoja_puntas(salida)
	get_tree().quit(0)


func _hoja(salida: String, nombre: String, esc: Dictionary) -> void:
	var tiempos: Array = esc["t"]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	for fila in DIRS.size():
		var dir: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var lado: Vector2 = dir.orthogonal()
		var yo := Vector2.ZERO
		var tu: Node2D = _figura(yo, AZUL)
		var cuerpos: Array = []
		var lejos: float = 20.0
		for e in esc["e"]:
			var p: Vector2 = yo + dir * float(e[0]) + lado * float(e[1])
			cuerpos.append(_figura(p, ROJO))
			lejos = maxf(lejos, float(e[0]))
		_cam.global_position = yo + dir * lejos * 0.5 + Vector2(0, -12)
		# Que quepa todo: de ti al mas lejano, con margen para lo que se clava detras.
		var z: float = minf(3.0, float(LADO) * 0.5 / (lejos * 0.5 + 25.0))
		_cam.zoom = Vector2(z, z)
		var efectos: Array = []
		var pendientes: Array = (esc["ev"] as Array).duplicate()
		var t: float = minf(float(tiempos[0]), 0.0) - 0.01
		for col in tiempos.size():
			var hasta: float = float(tiempos[col])
			while t + 0.005 <= hasta:
				t += 0.005
				# Los que tocan salir ya (lo que tardan en volar antes de su impacto), todos los de este instante juntos.
				var salen: Array = pendientes.filter(func(ev): return t >= float(ev[2]) - ESPERA)
				for ev in salen:
					pendientes.erase(ev)
					var quien: int = int(ev[1])
					var p_v: Vector2 = yo if quien < 0 else (cuerpos[quien] as Node2D).global_position
					var cu: Node2D = tu if quien < 0 else cuerpos[quien]
					var d := DistanciaAire.disparo(self, int(ev[0]), _caja(yo).get_center(), _caja(p_v), cu,
						bool(ev[3]), false, hash("%s%d%d%f" % [nombre, fila, quien, float(ev[2])]), ESPERA, 1.0, 4)
					d.set_process(false)
					efectos.append(d)
				for n in efectos + get_tree().get_nodes_in_group(DistanciaAire.GRUPO_CLAVADAS):
					if is_instance_valid(n) and n.has_method("_process"):
						n._process(0.005)
			await _viñeta(hoja, col, fila, "%s · %s · %.2f s" % [nombre, DIRS[fila][0], hasta])
		for e in efectos:
			if is_instance_valid(e):
				e.queue_free()
		DistanciaAire.quitar_clavadas(get_tree())
		tu.queue_free()
		for c in cuerpos:
			(c as Node).queue_free()
		# La sangre del clavo (SangreMapa) se queda en el suelo: fuera tambien.
		for n in get_children():
			if n is SangreMapa:
				n.queue_free()
		await get_tree().process_frame
	var ruta: String = "%s/%s.png" % [salida, nombre]
	hoja.save_png(ruta)
	print("[hoja] ", ruta)


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
		var p1: Vector2 = yo + Vector2(84, 0)
		var cuerpo: Node2D = _figura(p1, ROJO)
		_cam.global_position = yo + Vector2(42, -12)
		var d := DistanciaAire.disparo(self, DistanciaAire.Modo.FLECHA, _caja(yo).get_center(), _caja(p1), cuerpo,
			false, false, 77 + idx, 0.2, 1.0, idx)
		d.set_process(false)
		var hecho: float = -d._vuelo
		var nombre: String = "madera" if idx == 0 else String((Game.municiones()[idx - 1] as MaterialData).nombre)
		for c in tiempos.size():
			while hecho + 0.005 <= float(tiempos[c]):
				for n in [d] + get_tree().get_nodes_in_group(DistanciaAire.GRUPO_CLAVADAS):
					if is_instance_valid(n):
						n._process(0.005)
				hecho += 0.005
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
