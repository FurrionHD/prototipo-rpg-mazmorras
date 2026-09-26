# HOJAS DE LOS CIRCULOS MAGICOS (26/09/2026). Una hoja por magia, en una fila: cada frase al salir y ya
# asentada, el disparo y el fallo. Y un RESUMEN con todas completas, una al lado de otra, para ver que se
# distinguen. Suelo de losetas y tu en azul (14x26, como en ver_ataques_dirs) para medir el tamaño.
# CON VENTANA.
#   CIRCULOS_SALIDA=/carpeta [CIRCULOS_LISTA=brasa,eclipse] godot --path . res://tools/ver_circulos.tscn
extends Node2D

const LADO := 320
const ZOOM := 2.2
const PASO := 1.0 / 60.0
const ENTRE_FRASES := 1.2

var _cam: Camera2D
var _rotulo: Label
var _yo: ColorRect


func _ready() -> void:
	_cam = Camera2D.new()
	_cam.zoom = Vector2(ZOOM, ZOOM)
	_cam.position = Vector2(0, -6)
	add_child(_cam)
	_cam.make_current()
	_yo = ColorRect.new()
	_yo.color = Color(0.35, 0.6, 1.0)
	_yo.size = Vector2(14, 26)
	_yo.position = Vector2(-7, -26)
	_yo.z_as_relative = false
	_yo.z_index = Game.Z_PERSONAJES
	add_child(_yo)
	var capa := CanvasLayer.new()
	add_child(capa)
	_rotulo = Label.new()
	_rotulo.add_theme_font_size_override("font_size", 13)
	_rotulo.add_theme_color_override("font_outline_color", Color.BLACK)
	_rotulo.add_theme_constant_override("outline_size", 5)
	capa.add_child(_rotulo)
	call_deferred("_correr")


func _draw() -> void:
	for x in range(-240, 240, 16):
		for y in range(-240, 240, 16):
			var v: float = 0.17 + 0.015 * float((x / 16 + y / 16) % 2)
			draw_rect(Rect2(x, y, 16, 16), Color(v, v + 0.02, v + 0.035))
			draw_rect(Rect2(x, y, 16, 16), Color(0.11, 0.12, 0.14), false, 1.0)


func _hechizos() -> Array:
	var out: Array = []
	var pedidas: String = OS.get_environment("CIRCULOS_LISTA")
	var dir := DirAccess.open("res://resources/spells")
	var nombres: Array = []
	for f in dir.get_files():
		var limpio: String = f.trim_suffix(".remap")
		if limpio.ends_with(".tres"):
			nombres.append(limpio.get_basename())
	nombres.sort()
	for nom in nombres:
		if pedidas != "" and not (nom in pedidas.split(",")):
			continue
		var s: SpellData = load("res://resources/spells/%s.tres" % nom)
		if s != null:
			out.append(s)
	# Por frases y rareza: el resumen se lee de menos a mas.
	out.sort_custom(func(a, b): return a.longitud() < b.longitud() or (a.longitud() == b.longitud() and a.rareza < b.rareza))
	return out


func _correr() -> void:
	var salida: String = OS.get_environment("CIRCULOS_SALIDA")
	if salida == "":
		salida = "user://circulos"
	DirAccess.make_dir_recursive_absolute(salida)
	var lista: Array = _hechizos()
	for s in lista:
		var n: int = s.longitud()
		var celdas: Array = []   # [eventos, t, texto]
		var base: Array = []
		for e in n:
			base.append([ENTRE_FRASES * float(e), "frase", e + 1])
			celdas.append([base.duplicate(), ENTRE_FRASES * float(e) + 0.15, "frase %d sale" % (e + 1)])
			celdas.append([base.duplicate(), ENTRE_FRASES * float(e) + 0.9, "frase %d" % (e + 1)])
		var t_disp: float = ENTRE_FRASES * float(n)
		for dt in [0.2, 0.35, 0.5]:
			celdas.append([base + [[t_disp, "disparar", 0]], t_disp + dt, "disparo +%.2f" % dt])
		var fallo: Array = base.slice(0, n - 1)
		var t_fallo: float = ENTRE_FRASES * float(n - 1) + 0.9
		for dt in [0.15, 0.45]:
			celdas.append([fallo + [[t_fallo, "fallar", 0]], t_fallo + dt, "falla la %d +%.2f" % [n, dt]])
		var hoja := Image.create(LADO * celdas.size(), LADO, false, Image.FORMAT_RGBA8)
		for i in celdas.size():
			var c = celdas[i]
			var circ := await _simular(s, c[0], c[1])
			await _viñeta(hoja, i, 0, "%s · %s" % [s.nombre, c[2]])
			if is_instance_valid(circ):
				circ.queue_free()
		var ruta: String = "%s/%s.png" % [salida, SellosMagicos.clave_de(s)]
		hoja.save_png(ruta)
		print("[hoja] ", ruta)
	# EL RESUMEN: todas completas (asentadas), 6 por fila.
	if lista.size() > 1:
		var cols: int = 6
		var filas: int = ceili(float(lista.size()) / float(cols))
		var res := Image.create(LADO * cols, LADO * filas, false, Image.FORMAT_RGBA8)
		for i in lista.size():
			var s2: SpellData = lista[i]
			var ev: Array = []
			for e in s2.longitud():
				ev.append([ENTRE_FRASES * float(e), "frase", e + 1])
			var circ2 := await _simular(s2, ev, ENTRE_FRASES * float(s2.longitud() - 1) + 1.4)
			await _viñeta(res, i % cols, i / cols, "%s (%d)" % [s2.nombre, s2.longitud()])
			if is_instance_valid(circ2):
				circ2.queue_free()
		res.save_png("%s/_resumen.png" % salida)
		print("[hoja] ", salida, "/_resumen.png")
	get_tree().quit(0)


# Monta el circulo de la magia y lo lleva a mano hasta 't', con sus eventos por el camino.
func _simular(s: SpellData, eventos: Array, t: float) -> CirculoMagico:
	var c := CirculoMagico.crear(self, s)
	c.auto = false
	var ahora: float = 0.0
	var pend: Array = eventos.duplicate()
	while ahora < t - 0.0001:
		while not pend.is_empty() and float(pend[0][0]) <= ahora + 0.0001:
			var ev: Array = pend.pop_front()
			match str(ev[1]):
				"frase": c.a_la_frase(int(ev[2]))
				"disparar": c.disparar()
				"fallar": c.fallar()
		var dt: float = minf(PASO, t - ahora)
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			break
		c.avanzar(dt)
		ahora += dt
	await get_tree().process_frame
	return c


func _viñeta(hoja: Image, col: int, fila: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(6, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, fila * LADO))
