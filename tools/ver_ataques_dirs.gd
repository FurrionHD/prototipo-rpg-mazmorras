# HOJAS DE LOS ATAQUES DEL MAPA, ENTEROS Y EN CINCO DIRECCIONES (lo pidio el usuario el 24/09, al estilo
# de ver_suelo_roto: suelo de losetas, tu en azul y enemigos en rojo). Una hoja por habilidad: una fila
# por direccion (N, NE, E, SE, S) y en cada fila la HUELLA al apuntar y cinco momentos de su efecto.
# La forma sale de la FICHA (de_habilidad_mapa, con el alcance de su arma), asi que es la de verdad.
# CON VENTANA.
#   ATAQUES_SALIDA=/carpeta ATAQUES_LISTA=tajo_del_verdugo godot --path . res://tools/ver_ataques_dirs.tscn
extends Node2D

const LADO := 420            # px de pantalla de cada viñeta
const HABILIDADES := [
	["martillo", "golpe_sismico"], ["martillo", "martillo_de_guerra"], ["martillo", "rompecorazas"],
	["martillo", "onda_expansiva"], ["martillo", "temblor"],
	["mandoble", "molinete"], ["mandoble", "segar"], ["mandoble", "tajo_devastador"],
	["mandoble", "tajo_del_verdugo"], ["mandoble", "grito_de_guerra"],
]
const ALCANCE := {"martillo": 32.25, "mandoble": 34.5}
const PISA := 6.0
const DIRS := [["N", Vector2(0, -1)], ["NE", Vector2(1, -1)], ["E", Vector2(1, 0)],
	["SE", Vector2(1, 1)], ["S", Vector2(0, 1)]]
# Los cinco momentos de cada efecto (segundos desde el golpe), por SueloRoto.Tipo.
const MOMENTOS := {
	0: [0.18, 0.45, 0.95, 1.55, 2.0],
	1: [0.18, 0.45, 0.95, 1.55, 2.0],
	2: [0.04, 0.1, 0.25, 0.55, 0.95],
	3: [0.07, 0.14, 0.2, 0.25, 0.4],
	4: [0.08, 0.17, 0.27, 0.36, 0.8],
	5: [0.06, 0.13, 0.2, 0.3, 0.45],
	6: [0.07, 0.14, 0.27, 0.34, 0.5],
	7: [0.08, 0.18, 0.3, 0.45, 0.7],
}
const COLOR_HUELLA := Color(1.0, 0.72, 0.25)

var _cam: Camera2D
var _huella: Node2D
var _forma_huella = null
var _rotulo: Label


func _ready() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
	_huella = Node2D.new()
	_huella.z_index = 1
	add_child(_huella)
	_huella.draw.connect(func():
		if _forma_huella != null:
			CombatFormas.dibujar(_forma_huella, _huella, COLOR_HUELLA))
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 17)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 6)
	capa.add_child(_rotulo)
	call_deferred("_correr")


func _draw() -> void:
	# Un suelo de losetas oscuro, como el de la mazmorra (el de ver_suelo_roto).
	var r: int = 400
	for x in range(-r, r, 16):
		for y in range(-r, r, 16):
			var v: float = 0.17 + 0.015 * float((x / 16 + y / 16) % 2)
			draw_rect(Rect2(x, y, 16, 16), Color(v, v + 0.02, v + 0.035))
			draw_rect(Rect2(x, y, 16, 16), Color(0.11, 0.12, 0.14), false, 1.0)


func _figura(p: Vector2, col: Color) -> void:
	var fig := ColorRect.new()
	fig.color = col
	fig.size = Vector2(14, 26)
	fig.position = p - Vector2(7, 26)
	fig.z_index = 1024
	fig.z_as_relative = false
	add_child(fig)


func _correr() -> void:
	var salida: String = OS.get_environment("ATAQUES_SALIDA")
	if salida == "":
		salida = "user://ataques"
	DirAccess.make_dir_recursive_absolute(salida)
	var yo := Vector2.ZERO
	_figura(yo, Color(0.35, 0.6, 1.0))
	# Enemigos alrededor: un anillo cerca y unos cuantos mas lejos, para ver hasta donde llega cada uno.
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + 0.2
		_figura(Vector2(cos(a), sin(a)) * 62.0, Color(0.8, 0.35, 0.35))
	for i in 5:
		var a2: float = TAU * float(i) / 5.0 + 0.9
		_figura(Vector2(cos(a2), sin(a2)) * 118.0, Color(0.8, 0.35, 0.35))
	var pedidas: String = OS.get_environment("ATAQUES_LISTA")
	for h in HABILIDADES:
		var arma: String = h[0]
		var nom: String = h[1]
		if pedidas != "" and not (nom in pedidas.split(",")):
			continue
		var ab: AbilityData = load("res://resources/abilities/%s.tres" % nom)
		var tiempos: Array = MOMENTOS.get(ab.suelo_roto, [])
		var cols: int = 1 + tiempos.size()
		# El zoom de toda la hoja: que quepa la forma mas larga de esta habilidad, en cualquier direccion.
		var f0 = CombatFormas.de_habilidad_mapa(ab, yo, PISA, ALCANCE[arma], yo + Vector2(70, 0))
		var medida: float = maxf(maxf(f0.radio, f0.largo), 40.0)
		if int(ab.forma_apunte) == CombatFormas.Apunte.DELANTE and int(ab.forma) == CombatFormas.Tipo.CIRCULO:
			medida += PISA + ALCANCE[arma]
		# ATAQUES_ACERCA=3 -> tres veces mas cerca (para mirar un efecto de cerca).
		var acerca: float = maxf(float(OS.get_environment("ATAQUES_ACERCA")), 1.0) if OS.get_environment("ATAQUES_ACERCA") != "" else 1.0
		var zoom: float = float(LADO) / (2.0 * (medida + 30.0)) * acerca
		_cam.zoom = Vector2(zoom, zoom)
		var hoja := Image.create(LADO * cols, LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
		for fila in DIRS.size():
			var dir_n: String = DIRS[fila][0]
			var hacia: Vector2 = yo + (DIRS[fila][1] as Vector2).normalized() * 70.0
			var f = CombatFormas.de_habilidad_mapa(ab, yo, PISA, ALCANCE[arma], hacia)
			# La camara, un poco hacia donde va el ataque (salvo los que caen a tu alrededor).
			var hacia_cam: float = 0.0 if int(ab.forma_apunte) == CombatFormas.Apunte.ALREDEDOR else 0.35
			_cam.global_position = yo + (DIRS[fila][1] as Vector2).normalized() * medida * hacia_cam / acerca
			# 1) Apuntando: la huella.
			_forma_huella = f
			_huella.queue_redraw()
			await _viñeta(hoja, 0, fila, "%s · %s · apuntando" % [ab.nombre, dir_n])
			_forma_huella = null
			_huella.queue_redraw()
			if tiempos.is_empty():
				continue
			# 2) El efecto, en sus cinco momentos.
			var f_suelo = f
			if ab.suelo_roto == SueloRoto.Tipo.ESTELA:
				f_suelo = CombatFormas.cono(yo, f.centro - yo, EstelaGolpe.RADIO, 0.0)
			var s: Node2D = SueloRoto.lanzar(self, f_suelo, ab.suelo_roto, 1234 + fila, ab.forma_nucleo)
			s.set_process(false)
			for col in tiempos.size():
				s.set("_t", float(tiempos[col]))
				for hijo in ["_geiser", "_aire", "_atras", "_delante"]:
					if s.get(hijo) != null:
						(s.get(hijo) as Node2D).queue_redraw()
				s.queue_redraw()
				await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, float(tiempos[col])])
			s.queue_free()
			await get_tree().process_frame
		var ruta: String = "%s/%s_%s.png" % [salida, arma, nom]
		hoja.save_png(ruta)
		print("[hoja] ", ruta)
	get_tree().quit(0)


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
