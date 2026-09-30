# HOJAS DE LAS PASIVAS DEL REPASO y del INTERRUMPIDO (30/09, paso E; PasivaAire). Como ver_ataques_dirs: suelo de
# losetas, los tuyos en azul, una fila por direccion (N..S, del enemigo hacia el tuyo) y en cada columna un momento.
# CON VENTANA.
#   PASIVAS_SALIDA=/carpeta [PASIVAS_LISTA=camada,ojos] godot --path . res://tools/ver_pasivas.tscn
extends Node2D

const LADO := 420
const AZUL := Color(0.35, 0.6, 1.0)
const DIRS := [["N", Vector2(0, -1)], ["NE", Vector2(1, -1)], ["E", Vector2(1, 0)],
	["SE", Vector2(1, 1)], ["S", Vector2(0, 1)]]
const HOJAS := ["camada", "ojos", "cuerpo_ardiente", "emboscada", "filo_reflejo", "ecolocalizacion", "interrumpido",
	"empujon", "barra", "alcance"]

var _cam: Camera2D
var _rotulo: Label
var _textos: Array = []   # {lbl, en (mundo), t0}: el "¡INTERRUMPIDO!" sobre la figura


func _ready() -> void:
	_cam = Camera2D.new()
	add_child(_cam)
	_cam.make_current()
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


func _correr() -> void:
	var salida: String = OS.get_environment("PASIVAS_SALIDA")
	if salida == "":
		salida = "user://pasivas"
	DirAccess.make_dir_recursive_absolute(salida)
	var pedidas: String = OS.get_environment("PASIVAS_LISTA")
	for h in HOJAS:
		if pedidas != "" and not (String(h) in pedidas.split(",")):
			continue
		await call("_hoja_" + h, salida)
	get_tree().quit(0)


# ------------------------------------------------------------
#  PIEZAS
# ------------------------------------------------------------
func _figura(p: Vector2, col: Color) -> ColorRect:
	var fig := ColorRect.new()
	fig.color = col
	fig.size = Vector2(14, 26)
	fig.position = p - Vector2(7, 26)
	fig.z_index = Game.Z_PERSONAJES
	fig.z_as_relative = false
	add_child(fig)
	return fig


func _caja_fig(fig: ColorRect) -> Rect2:
	return Rect2(fig.position, fig.size)


# Un enemigo con los pies en 'pies', mirando hacia 'dvec'. {nodo, spr, rd (su caja relativa a los pies), ed}.
func _enemigo(nombre: String, pies: Vector2, dvec: Vector2) -> Dictionary:
	var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % nombre)
	var cuerpo := Node2D.new()
	cuerpo.z_index = Game.Z_PERSONAJES
	cuerpo.z_as_relative = false
	add_child(cuerpo)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = SpritesEnemigo.frames_de(ed, 0.5)
	spr.scale = Vector2.ONE * SpritesEnemigo.escala_de(ed)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cuerpo.add_child(spr)
	spr.play(&"idle_0")
	spr.pause()
	var rd: Rect2 = load("res://scripts/ui/combat_tactico.gd").rect_dibujo(cuerpo)
	spr.position = -Vector2(rd.get_center().x, rd.position.y + rd.size.y * ed.centro_suelo_real())
	cuerpo.position = pies
	var e := {"nodo": cuerpo, "spr": spr, "rd": Rect2(rd.position + spr.position, rd.size), "ed": ed}
	_mirar(e, dvec)
	return e


func _mirar(e: Dictionary, dvec: Vector2, anim: String = "idle", frame: int = 0) -> void:
	var spr: AnimatedSprite2D = e["spr"]
	var an := StringName("%s_%d" % [anim, SpriteLienzo.dir8(dvec)])
	if not spr.sprite_frames.has_animation(an):
		an = StringName("idle_%d" % SpriteLienzo.dir8(dvec))
	spr.animation = an
	spr.frame = clampi(frame, 0, spr.sprite_frames.get_frame_count(an) - 1)


# Los pies de una figura pegada DELANTE de su cuerpo (en 'dvec', a 'hueco' px de su borde).
func _delante_de(e: Dictionary, dvec: Vector2, hueco: float) -> Vector2:
	var b: Rect2 = _bulto(e)
	var borde: Vector2 = PasivaAire._borde(b, dvec) - b.get_center()
	var pies: Vector2 = (e["nodo"] as Node2D).position
	return pies + dvec * (borde.length() + hueco + 7.0) + Vector2(0, 13.0 * maxf(dvec.y, 0.0))


func _bulto(e: Dictionary) -> Rect2:
	var rd: Rect2 = e["rd"]
	return Rect2(rd.position + (e["nodo"] as Node2D).position, rd.size)


func _ojos(e: Dictionary, encendido: float) -> void:
	var spr: AnimatedSprite2D = e["spr"]
	if spr.material == null:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/ojos_camada.gdshader")
		spr.material = m
	(spr.material as ShaderMaterial).set_shader_parameter("encendido", encendido)


func _texto(texto: String, en: Vector2, t0: float, col: Color, tam: int = 9) -> void:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tam)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 4000
	l.z_as_relative = false
	add_child(l)
	_textos.append({"lbl": l, "en": en, "t0": t0})


# Pone todo en el instante 't' (las piezas: {n, t0}) y los textos subiendo.
func _en(piezas: Array, t: float) -> void:
	for pz in piezas:
		var n = pz["n"]
		if n == null or not is_instance_valid(n):
			continue
		n.set("_t", t - float(pz["t0"]))
		if n.has_method("aplicar_temblor"):
			n.call("aplicar_temblor")
		(n as Node2D).queue_redraw()
		for hijo in ["_suelo", "_delante", "_brillo"]:
			var su = n.get(hijo)
			if su is Node2D:
				(su as Node2D).queue_redraw()
	for tx in _textos:
		var l: Label = tx["lbl"]
		var k: float = t - float(tx["t0"])
		l.visible = k >= 0.0 and k < 0.9
		l.position = (tx["en"] as Vector2) - Vector2(l.size.x * 0.5, 14.0 + 18.0 * clampf(k / 0.65, 0.0, 1.0))
		l.modulate.a = 1.0 - smoothstep(0.55, 0.9, k)


func _limpiar(piezas: Array, nodos: Array) -> void:
	for pz in piezas:
		if pz["n"] != null and is_instance_valid(pz["n"]):
			(pz["n"] as Node).queue_free()
	for n in nodos:
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	for tx in _textos:
		(tx["lbl"] as Node).queue_free()
	_textos.clear()
	await get_tree().process_frame


func _viñeta(hoja: Image, col: int, fila: int, texto: String) -> void:
	var tam: Vector2 = get_viewport().get_visible_rect().size
	_rotulo.text = texto
	_rotulo.position = tam * 0.5 - Vector2(LADO, LADO) * 0.5 + Vector2(8, 4)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var cen: Vector2i = img.get_size() / 2
	hoja.blit_rect(img, Rect2i(cen - Vector2i(LADO, LADO) / 2, Vector2i(LADO, LADO)), Vector2i(col * LADO, fila * LADO))


func _zoom(medida: float) -> void:
	var z: float = float(LADO) / (2.0 * medida)
	_cam.zoom = Vector2(z, z)


func _guardar(hoja: Image, salida: String, nom: String) -> void:
	var ruta: String = "%s/%s.png" % [salida, nom]
	hoja.save_png(ruta)
	print("[hoja] ", ruta)


# ------------------------------------------------------------
#  REY DE LA CAMADA: el rey muerde, llama, y dos ratas saltan detras de su victima y muerden (mas flojo)
# ------------------------------------------------------------
func _hoja_camada(salida: String) -> void:
	var tiempos: Array = [-0.06, 0.04, 0.14, 0.24, 0.34, 0.46, 0.6, 0.8]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(62.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var rey := _enemigo("rey_rata", Vector2.ZERO, dvec)
		var fig_p: Vector2 = _delante_de(rey, dvec, 8.0)
		var fig := _figura(fig_p, AZUL)
		var caja_f: Rect2 = _caja_fig(fig)
		_cam.global_position = fig_p * 0.5 + Vector2(0, -10)
		# Dos ratas a los lados, un poco atras; saltan a la espalda de la figura (cada una a un lado).
		var lat: Vector2 = dvec.orthogonal()
		var ratas: Array = []
		var desde_r: Array = [lat * 38.0 - dvec * 4.0, -lat * 40.0 + dvec * 8.0]
		var hasta_r: Array = [fig_p + dvec * 13.0 + lat * 9.0, fig_p + dvec * 13.0 - lat * 9.0]
		var t_salto: Array = [0.12, 0.26]
		for i in 2:
			var rt := _enemigo("rata", desde_r[i], (fig_p - (desde_r[i] as Vector2)).normalized())
			_ojos(rt, 1.0)
			ratas.append(rt)
		var piezas: Array = []
		var bulto_rey: Rect2 = _bulto(rey)
		piezas.append({"n": BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.MORDISCO, bulto_rey.get_center(), caja_f, 11 + fila,
			0.14, 1.0, bulto_rey.size.x), "t0": 0.0})
		piezas.append({"n": PasivaAire.sobre_cuerpo(self, PasivaAire.Modo.LLAMADA, bulto_rey, caja_f, fig_p, 21 + fila, 0.0, 1.0),
			"t0": 0.04})
		# Los mordiscos de las ratas, al aterrizar: desde detras, y MAS PEQUEÑOS (pegan menos que un basico).
		for i in 2:
			var br: Rect2 = Rect2((ratas[i]["rd"] as Rect2).position + (hasta_r[i] as Vector2), (ratas[i]["rd"] as Rect2).size)
			piezas.append({"n": BestiaAire.sobre_cuerpo(self, BestiaAire.Modo.MORDISCO, br.get_center(), caja_f, 31 + fila * 3 + i,
				0.08, 1.0, br.size.x * 0.7), "t0": float(t_salto[i]) + 0.2})
		for pz in piezas:
			if pz["n"] != null:
				(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(rey, dvec, "basico", int(floor((t + 0.16) * 12.0)))
			for i in 2:
				var u: float = clampf((t - float(t_salto[i])) / 0.2, 0.0, 1.0)
				var a: Vector2 = desde_r[i]
				var b: Vector2 = hasta_r[i]
				(ratas[i]["nodo"] as Node2D).position = a.lerp(b, u) - Vector2(0.0, 26.0 * 4.0 * u * (1.0 - u))
				_mirar(ratas[i], (fig_p - (ratas[i]["nodo"] as Node2D).position).normalized() if u < 1.0 else -dvec,
					"basico" if u >= 1.0 else "idle", int(floor((t - float(t_salto[i]) - 0.2 + 0.16) * 12.0)))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Rey de la camada · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [rey["nodo"], fig, ratas[0]["nodo"], ratas[1]["nodo"]])
	_guardar(hoja, salida, "camada")


# LOS OJOS DE LA CAMADA: cada rata en las 5 direcciones, con el rey muerto (apagados) y vivo (encendidos).
func _hoja_ojos(salida: String) -> void:
	var hoja := Image.create(LADO * 2, LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(26.0)
	_cam.global_position = Vector2(0, -6)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var rt := _enemigo("rata", Vector2.ZERO, dvec)
		for c in 2:
			_ojos(rt, float(c))
			await _viñeta(hoja, c, fila, "Rata · %s · %s" % [DIRS[fila][0], "rey muerto" if c == 0 else "rey vivo: ojos rojos"])
		await _limpiar([], [rt["nodo"]])
	_guardar(hoja, salida, "ojos_camada")


# ------------------------------------------------------------
#  CUERPO ARDIENTE: le pegas cuerpo a cuerpo y la lengua de fuego te revienta encima
# ------------------------------------------------------------
func _hoja_cuerpo_ardiente(salida: String) -> void:
	var tiempos: Array = [0.0, 0.05, 0.1, 0.16, 0.24, 0.34, 0.48, 0.65]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(48.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var sl := _enemigo("slime_fuego", Vector2.ZERO, dvec)
		var fig_p: Vector2 = _delante_de(sl, dvec, 10.0)
		var fig := _figura(fig_p, AZUL)
		_cam.global_position = fig_p * 0.5 + Vector2(0, -10)
		var piezas: Array = [{"n": PasivaAire.sobre_cuerpo(self, PasivaAire.Modo.ARDE, _bulto(sl), _caja_fig(fig), fig_p,
			41 + fila, 0.0, 1.0), "t0": 0.0}]
		(piezas[0]["n"] as Node).set_process(false)
		for c in tiempos.size():
			_en(piezas, tiempos[c])
			await _viñeta(hoja, c, fila, "Cuerpo ardiente · %s · %.2f s" % [DIRS[fila][0], tiempos[c]])
		await _limpiar(piezas, [sl["nodo"], fig])
	_guardar(hoja, salida, "cuerpo_ardiente")


# ------------------------------------------------------------
#  EMBOSCADA: la araña muerde al que esta en su tela; la tela late y el mordisco sale mas grande
# ------------------------------------------------------------
func _hoja_emboscada(salida: String) -> void:
	var tiempos: Array = [-0.14, -0.07, -0.02, 0.02, 0.07, 0.14, 0.24, 0.38]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(52.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var ar := _enemigo("arana", Vector2.ZERO, dvec)
		var fig_p: Vector2 = _delante_de(ar, dvec, 8.0)
		var fig := _figura(fig_p, AZUL)
		_cam.global_position = fig_p * 0.5 + Vector2(0, -10)
		var ba: Rect2 = _bulto(ar)
		var red: InsectoAire = InsectoAire.red(self, CombatFormas.circulo(fig_p, 22.0), 51 + fila, 0.0)
		red.set_process(false)
		red._t = 1.0
		var piezas: Array = [
			{"n": InsectoAire.sobre_cuerpo(self, InsectoAire.Modo.QUELICEROS, ba.get_center(), _caja_fig(fig), 61 + fila, 0.14, 1.0,
				ba.size.x * 1.5), "t0": 0.0},
			{"n": PasivaAire.sobre_cuerpo(self, PasivaAire.Modo.LATIDO, ba, _caja_fig(fig), fig_p, 71 + fila, 0.14, 1.0), "t0": 0.0}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			_mirar(ar, dvec, "basico", int(floor((tiempos[c] + 0.16) * 12.0)))
			_en(piezas, tiempos[c])
			for hijo in ["_suelo", "_delante", "_brillo"]:
				var su = red.get(hijo)
				if su is Node2D:
					(su as Node2D).queue_redraw()
			await _viñeta(hoja, c, fila, "Emboscada · %s · %.2f s" % [DIRS[fila][0], tiempos[c]])
		await _limpiar(piezas, [ar["nodo"], fig, red])
	_guardar(hoja, salida, "emboscada")


# ------------------------------------------------------------
#  FILO DE REFLEJO: el tuyo le pega, la guadaña destella y ella devuelve el tajo
# ------------------------------------------------------------
func _hoja_filo_reflejo(salida: String) -> void:
	var tiempos: Array = [0.0, 0.05, 0.12, 0.2, 0.28, 0.34, 0.42, 0.56]
	var t_tajo: float = 0.3
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(56.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var sg := _enemigo("segadora", Vector2.ZERO, dvec)
		var fig_p: Vector2 = _delante_de(sg, dvec, 8.0)
		var fig := _figura(fig_p, AZUL)
		_cam.global_position = fig_p * 0.5 + Vector2(0, -10)
		var bs: Rect2 = _bulto(sg)
		var piezas: Array = [
			{"n": PasivaAire.sobre_cuerpo(self, PasivaAire.Modo.DESTELLO, _caja_fig(fig), bs, Vector2.ZERO, 81 + fila, 0.0, 1.0),
				"t0": 0.0},
			{"n": InsectoAire.sobre_cuerpo(self, InsectoAire.Modo.TAJO, bs.get_center(), _caja_fig(fig), 91 + fila, 0.14, 1.0,
				bs.size.x, 1.0, -1.0), "t0": t_tajo}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			# Encaja el golpe y, al devolverlo, su 'basico'.
			if t < t_tajo - 0.16:
				_mirar(sg, dvec)
			else:
				_mirar(sg, dvec, "basico", int(floor((t - t_tajo + 0.16) * 12.0)))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Filo de reflejo · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [sg["nodo"], fig])
	_guardar(hoja, salida, "filo_reflejo")


# ------------------------------------------------------------
#  ECOLOCALIZACION: el chillon va a por el que va en sigilo (medio transparente); el eco lo pilla y se le ve entero
# ------------------------------------------------------------
func _hoja_ecolocalizacion(salida: String) -> void:
	var tiempos: Array = [-0.4, -0.28, -0.16, -0.06, 0.0, 0.08, 0.2, 0.45]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(54.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var ch := _enemigo("chillon", Vector2.ZERO, dvec)
		var fig_p: Vector2 = _delante_de(ch, dvec, 16.0)
		var fig := _figura(fig_p, AZUL)
		_cam.global_position = fig_p * 0.5 + Vector2(0, -10)
		var bc: Rect2 = _bulto(ch)
		var piezas: Array = [
			{"n": PasivaAire.sobre_cuerpo(self, PasivaAire.Modo.ECO, bc, _caja_fig(fig), fig_p, 101 + fila, 0.42, 1.0), "t0": 0.0},
			{"n": SimaAire.sobre_cuerpo(self, SimaAire.Modo.PALETOS, bc, _caja_fig(fig), fig_p, (ch["ed"] as EnemyData).color_visual(0.5),
				111 + fila, 0.1, 1.0), "t0": 0.0}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			# EN SIGILO (alfa 0.45, CombatTactico.ALFA_SIGILO) hasta que le llega el eco: entonces entero un momento.
			fig.color = Color(AZUL, 1.0 if t >= 0.0 and t < 0.8 else 0.45)
			_mirar(ch, dvec, "basico", int(floor((t + 0.16) * 12.0)))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Ecolocalizacion · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [ch["nodo"], fig])
	_guardar(hoja, salida, "ecolocalizacion")


# ------------------------------------------------------------
#  INTERRUMPIDO: fila 1 una carga de arma, fila 2 un conjuro (su circulo se rompe), fila 3 el empujon pequeño
#  (retrasa la barra: solo tiembla). Y fila 4: el chillon INMUNE a la ceguera.
# ------------------------------------------------------------
func _hoja_interrumpido(salida: String) -> void:
	var tiempos: Array = [-0.04, 0.02, 0.07, 0.14, 0.24, 0.38, 0.55, 0.75]
	var hoja := Image.create(LADO * tiempos.size(), LADO * 3, false, Image.FORMAT_RGBA8)
	_zoom(40.0)
	_cam.global_position = Vector2(0, -12)
	var spell: SpellData = load("res://resources/spells/bola_fuego.tres")
	var rotulos: Array = ["carga de arma cortada", "conjuro cortado", "chillon: INMUNE a la ceguera"]
	for fila in 3:
		var fig := _figura(Vector2(0, 13), AZUL)
		var caja: Rect2 = _caja_fig(fig)
		var piezas: Array = []
		var nodos: Array = [fig]
		var circ: CirculoMagico = null
		var ch: Dictionary = {}
		match fila:
			0, 1:
				piezas.append({"n": PasivaAire.sobre_cuerpo(self, PasivaAire.Modo.ESQUIRLAS, Rect2(), caja, Vector2(0, 13), 121 + fila,
					0.0, 1.0, 1.0 if fila == 0 else 0.0), "t0": 0.0})
				_texto("¡INTERRUMPIDO!", Vector2(0, -16), 0.0, Color(1.0, 0.55, 0.35))
				if fila == 1:
					circ = CirculoMagico.crear(self, spell, Vector2(0, 13))
					circ.set_process(false)
					circ.a_la_frase(2)
					circ.avanzar(1.2)
			2:
				fig.visible = false
				ch = _enemigo("chillon", Vector2(0, 13), Vector2(0, 1))
				nodos.append(ch["nodo"])
				piezas.append({"n": SimaAire.sobre_cuerpo(self, SimaAire.Modo.POLVO, Rect2(), _bulto(ch), Vector2(0, 13), Color.WHITE,
					141, 0.0, 1.0), "t0": 0.0})
				_texto("INMUNE", Vector2(0, -18), 0.12, Color(0.8, 0.85, 0.95))
		for pz in piezas:
			if pz["n"] != null:
				(pz["n"] as Node).set_process(false)
		var t_prev: float = -0.1
		for c in tiempos.size():
			var t: float = tiempos[c]
			if circ != null and is_instance_valid(circ):
				if t >= 0.0 and t_prev < 0.0:
					circ.fallar()
				circ.avanzar(maxf(t - t_prev, 0.0))
			t_prev = t
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "%s · %.2f s" % [rotulos[fila], t])
		if circ != null:
			nodos.append(circ)
		await _limpiar(piezas, nodos)
	_guardar(hoja, salida, "interrumpido")


# ------------------------------------------------------------
#  EL EMPUJON PEQUEÑO: le mueven menos de 24 px (no le corta nada, le retrasa la barra): arrastre, polvo y "RETRASADO"
# ------------------------------------------------------------
func _hoja_empujon(salida: String) -> void:
	var tiempos: Array = [0.0, 0.06, 0.12, 0.2, 0.3, 0.45, 0.65, 0.9]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(40.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var quien := _figura(-dvec * 6.0 + Vector2(0, 13), Color(0.8, 0.35, 0.35))
		var p0: Vector2 = dvec * 24.0 + Vector2(0, 13)
		var p1: Vector2 = p0 + dvec * 18.0
		var fig := _figura(p0, AZUL)
		_cam.global_position = (p0 + p1) * 0.5 + Vector2(0, -10)
		var piezas: Array = [{"n": PasivaAire.arrastre(self, p0, p1, 14.0, 151 + fila, 1.0), "t0": 0.0}]
		(piezas[0]["n"] as Node).set_process(false)
		_texto("RETRASADO", p1 + Vector2(0, -26), 0.05, Color(0.72, 0.74, 0.8), 5)
		for c in tiempos.size():
			var t: float = tiempos[c]
			var u: float = clampf(t / PasivaAire.T_ARRASTRE, 0.0, 1.0)
			var pies: Vector2 = p0.lerp(p1, 1.0 - (1.0 - u) * (1.0 - u))
			# Al frenar, un tambaleo corto.
			var tam: float = sin(clampf((t - PasivaAire.T_ARRASTRE) / 0.18, 0.0, 1.0) * PI * 3.0) * 1.5
			fig.position = pies - Vector2(7, 26) + dvec.orthogonal() * tam
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Empujon pequeño · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [quien, fig])
	_guardar(hoja, salida, "empujon")


# LA BARRA DE TURNOS con el empujon (tu ficha retrocede con su estela y destella) y el numero de la EMBOSCADA con su
# marca, tal como salen en la pelea (misma fuente y tamaño que CombatFX._soltar_numero_de).
func _hoja_barra(salida: String) -> void:
	var tiempos: Array = [-0.05, 0.0, 0.15, 0.35, 0.6]
	var hoja := Image.create(LADO * tiempos.size(), LADO, false, Image.FORMAT_RGBA8)
	_cam.zoom = Vector2.ONE
	_cam.global_position = Vector2.ZERO
	var tl: Control = load("res://scripts/ui/turn_timeline.gd").new()
	tl.size = Vector2(400, 60)
	tl.position = Vector2(-200, -150)
	add_child(tl)
	var yo := Combatant.new("Tu", 1, Abilities.new(), 50, 5, 5, 5)
	var rata := Combatant.new("Rata", 1, Abilities.new(), 50, 5, 5, 5)
	rata.sprite_res = "res://scenes/actors/enemy/rata.tres"
	var arana := Combatant.new("Araña", 1, Abilities.new(), 50, 5, 5, 5)
	arana.sprite_res = "res://scenes/actors/enemy/arana.tres"
	tl.anadir(yo, AZUL, null, "")
	tl.anadir(rata, Color(0.6, 0.45, 0.35), null, "1")
	tl.anadir(arana, Color(0.45, 0.4, 0.6), null, "2")
	var ratios := {yo: 0.72, rata: 0.4, arana: 0.15}
	tl.set_ratios(ratios)
	var num := Label.new()
	num.text = "134.42 ✱"
	num.add_theme_font_size_override("font_size", 19)
	num.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
	num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	num.add_theme_constant_override("outline_size", 4)
	num.position = Vector2(-60, 20)
	add_child(num)
	var num2 := num.duplicate() as Label
	num2.text = "134.42"
	num2.position = Vector2(-60, 60)
	add_child(num2)
	for c in tiempos.size():
		var t: float = tiempos[c]
		if t >= 0.0 and tl.get("_estelas").is_empty():
			tl.retrasar(yo, 0.72)
			ratios[yo] = 0.52
			tl.set_ratios(ratios)
			for tw in get_tree().get_processed_tweens():
				tw.kill()
			tl.set_process(false)
		if t >= 0.0:
			tl.get("_estelas")[0]["t"] = t
			var marcador: Control = (tl.get("_marcadores")[yo]["marco"] as Control).get_child(0)
			marcador.modulate = Color(2.2, 1.7, 1.1).lerp(Color.WHITE, clampf(t / 0.45, 0.0, 1.0))
			tl.queue_redraw()
		await _viñeta(hoja, c, 0, "Barra: tu ficha pierde turno · %.2f s   (abajo: numero con y sin Emboscada)" % t)
	tl.queue_free()
	num.queue_free()
	num2.queue_free()
	await get_tree().process_frame
	_guardar(hoja, salida, "barra_turnos")


# ------------------------------------------------------------
#  EL ALCANCE DE LOS GRANDES (30/09, constructos paso 1): el golpe de su cuerpo ('embestida') en N..S, con una figura
#  JUSTO en el borde de su alcance (azul) y otra pegada (verde). El alcance se cuenta como en la pelea
#  (CombatTactico.hueco_entre): de sus pies menos lo que pisa (PISA del ancho de su dibujo) a la caja del que recibe.
#  PASIVAS_ALCANCE=golem_arcilla:22,coloso:35
# ------------------------------------------------------------
func _hoja_alcance(salida: String) -> void:
	var pedido: String = OS.get_environment("PASIVAS_ALCANCE")
	if pedido == "":
		pedido = "golem_arcilla:22,coloso:35"
	for par in pedido.split(","):
		var nom: String = par.split(":")[0]
		var alc: float = float(par.split(":")[1])
		var ed: EnemyData = load("res://scenes/actors/enemy/%s.tres" % nom)
		var e0 := _enemigo(nom, Vector2.ZERO, Vector2.RIGHT)
		var spr: AnimatedSprite2D = e0["spr"]
		var n_frames: int = spr.sprite_frames.get_frame_count(&"embestida_0")
		var cols: int = 7
		var hoja := Image.create(LADO * cols, LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
		var rd: Rect2 = e0["rd"]
		var pisa: float = rd.size.x * 0.33
		_zoom(maxf(rd.size.y, rd.size.x) * 0.5 + alc + 30.0)
		for fila in DIRS.size():
			var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
			# La figura en el borde: se aleja hasta que el hueco (de sus pies menos lo que pisa a su caja) = alcance.
			var d: float = 0.0
			while d < 400.0:
				var pies_f: Vector2 = dvec * d
				var caja := Rect2(pies_f - Vector2(7, 26), Vector2(14, 26))
				var cerca := Vector2(clampf(0.0, caja.position.x, caja.end.x), clampf(0.0, caja.position.y, caja.end.y))
				if cerca.length() - pisa >= alc:
					break
				d += 0.5
			var lejos := _figura(dvec * d, AZUL)
			# Y otra pegada a el (hueco 0), para comparar.
			var d0: float = 0.0
			while d0 < 400.0:
				var pies_0: Vector2 = dvec.rotated(0.9) * d0
				var caja0 := Rect2(pies_0 - Vector2(7, 26), Vector2(14, 26))
				var cerca0 := Vector2(clampf(0.0, caja0.position.x, caja0.end.x), clampf(0.0, caja0.position.y, caja0.end.y))
				if cerca0.length() - pisa >= 0.0:
					break
				d0 += 0.5
			var pegada := _figura(dvec.rotated(0.9) * d0, Color(0.35, 0.8, 0.45))
			_cam.global_position = dvec * d * 0.4 + Vector2(0, -rd.size.y * 0.3)
			for c in cols:
				var fr: int = int(round(float(c) / float(cols - 1) * float(n_frames - 1)))
				_mirar(e0, dvec, "embestida", fr)
				await _viñeta(hoja, c, fila, "%s · alcance %d · %s · fotograma %d/%d" % [ed.enemy_name, int(alc), DIRS[fila][0],
					fr + 1, n_frames])
			lejos.queue_free()
			pegada.queue_free()
		(e0["nodo"] as Node).queue_free()
		await get_tree().process_frame
		_guardar(hoja, salida, "alcance_%s" % nom)
