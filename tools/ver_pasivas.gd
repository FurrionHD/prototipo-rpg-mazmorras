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
	"empujon", "barra", "alcance", "golem_basico", "golem_machaca", "golem_estados",
	"gargola_basico", "gargola_picado", "gargola_mirada", "gargola_estados",
	"coloso_basico", "coloso_pisoton", "coloso_estados",
	"mino_basico", "mino_esquiva", "mino_barrido", "mino_cornada", "mino_pisoton", "mino_bramido", "mino_rabia"]

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
		for hijo in ["_suelo", "_delante", "_brillo", "_atras"]:
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


# ------------------------------------------------------------
#  EL GOLEM (30/09, constructos paso 2, ConstructoAire). Carpeta enemigos/golem_arcilla/.
# ------------------------------------------------------------
const _TACTICO_G := preload("res://scripts/ui/combat_tactico.gd")

# Los pies de una figura justo al borde de su alcance en 'dvec' (como CombatTactico.hueco_entre).
func _al_alcance(e: Dictionary, dvec: Vector2, alc: float) -> Vector2:
	var pisa: float = (e["rd"] as Rect2).size.x * 0.33
	var pe: Vector2 = (e["nodo"] as Node2D).position
	var d: float = 0.0
	while d < 400.0:
		var pies_f: Vector2 = pe + dvec * d
		var caja := Rect2(pies_f - Vector2(7, 26), Vector2(14, 26))
		var cerca := Vector2(clampf(pe.x, caja.position.x, caja.end.x), clampf(pe.y, caja.position.y, caja.end.y))
		if cerca.distance_to(pe) - pisa >= alc:
			break
		d += 0.5
	return pe + dvec * d


# El fotograma de su 'embestida' en el instante 't' del golpe, COMO EN LA PELEA: arranca IMPACTO_ANIM_MAPA antes del
# golpe y se estira a ese adelanto mas la cola (CombatFX.T_ANIM_COLA).
# 'clave' = la de su tiempo de golpe; 'anim' = la animacion que pone.
func _marco_golpe(g: Dictionary, t: float, clave: String = "golem_golpe", anim: String = "embestida") -> int:
	var adel: float = float(CombatFX.IMPACTO_ANIM_MAPA.get(clave, CombatFX.T_ANIM_ADELANTO))
	var dur: float = adel + CombatFX.T_ANIM_COLA
	var n: int = (g["spr"] as AnimatedSprite2D).sprite_frames.get_frame_count(StringName(anim + "_0"))
	return clampi(int(floor((t + adel) / dur * float(n))), 0, n - 1)


func _carpeta_golem(salida: String) -> String:
	var c: String = "%s/golem_arcilla" % salida
	DirAccess.make_dir_recursive_absolute(c)
	return c


func _hoja_golem_basico(salida: String) -> void:
	var tiempos: Array = [-0.08, -0.03, 0.0, 0.04, 0.1, 0.2, 0.32, 0.5]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(74.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo("golem_arcilla", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var fig_p: Vector2 = _al_alcance(g, dvec, ed.alcance_real())
		var fig := _figura(fig_p, AZUL)
		var bg: Rect2 = _bulto(g)
		_cam.global_position = (bg.get_center() + fig_p) * 0.5
		var piezas: Array = [
			{"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.APLASTON, bg.get_center(), _caja_fig(fig), fig_p,
				ed.color_visual(0.5), 201 + fila, 0.0, 1.0), "t0": 0.0},
			{"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.PEGOTES, Vector2.ZERO, _caja_fig(fig), fig_p,
				ed.color_visual(0.5), 211 + fila, 0.0, 1.0), "t0": 0.02}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "basico", _marco_golpe(g, t, "golem_golpe", "basico"))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Golem · basico (y lento: pegotes) · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"], fig])
	_guardar(hoja, _carpeta_golem(salida), "basico")


var _huella_g: Node2D = null
var _forma_g = null

func _hoja_golem_machaca(salida: String) -> void:
	var tiempos: Array = [-0.1, 0.0, 0.05, 0.12, 0.2, 0.32, 0.5]
	var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	var ab: AbilityData = load("res://resources/abilities/golem_machaca.tres")
	_zoom(72.0)
	if _huella_g == null:
		_huella_g = Node2D.new()
		_huella_g.z_index = 1
		add_child(_huella_g)
		_huella_g.draw.connect(func():
			if _forma_g != null:
				CombatFormas.dibujar(_forma_g, _huella_g, Color(1.0, 0.3, 0.25)))
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo("golem_arcilla", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var rd: Rect2 = g["rd"]
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var frente: float = _TACTICO_G.frente_dibujo(g["nodo"], Vector2.ZERO, dvec)
		var f = CombatFormas.de_habilidad_mapa(ab, Vector2.ZERO, maxf(pisa, frente), ed.alcance_real(), dvec * 70.0, frente * 0.85)
		var sitios: Array = [f.centro + dvec.orthogonal() * f.radio * 0.4 + Vector2(0, 13), f.centro - dvec.orthogonal() * f.radio * 0.45 + dvec * 6.0 + Vector2(0, 13)]
		var figs: Array = []
		for sp in sitios:
			figs.append(_figura(sp, AZUL))
		_cam.global_position = (_bulto(g).get_center() + f.centro) * 0.5
		_mirar(g, dvec)
		_forma_g = f
		_huella_g.queue_redraw()
		await _viñeta(hoja, 0, fila, "Golem · Machaca · %s · cargando (huella roja)" % DIRS[fila][0])
		_forma_g = null
		_huella_g.queue_redraw()
		var piezas: Array = []
		var antes: int = get_child_count()
		SueloRoto.lanzar(self, f, ab.suelo_roto, 301 + fila, ab.forma_nucleo)
		for i in range(antes, get_child_count()):
			piezas.append({"n": get_child(i), "t0": 0.0})
		var bg: Rect2 = _bulto(g)
		for i in figs.size():
			var fg: ColorRect = figs[i]
			piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.APLASTON, bg.get_center(), _caja_fig(fg),
				sitios[i], ed.color_visual(0.5), 311 + fila * 3 + i, 0.0, 1.0, 1.5),
				"t0": SueloRoto.retraso(f, sitios[i], ab.suelo_roto)})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "golem_machaca", _marco_golpe(g, t, "golem_machaca", "golem_machaca"))
			_en(piezas, t)
			await _viñeta(hoja, c + 1, fila, "Golem · Machaca · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"]] + figs)
	_guardar(hoja, _carpeta_golem(salida), "machaca")


# LOS ESTADOS: fila 1 se cuece (fuego o Endurecerse) y se queda duro; fila 2 lo mojan estando cocido (vapor) y se queda
# blando; fila 3 blando un rato (gotas y charquito). Mirando al S y al E.
func _hoja_golem_estados(salida: String) -> void:
	var tiempos: Array = [0.0, 0.15, 0.3, 0.5, 0.8, 1.2, 1.7]
	var filas: Array = [["se cuece y queda duro (terracota)", Vector2(0, 1)], ["duro -> lo mojan: vapor y queda blando", Vector2(0, 1)],
		["blando (barro mojado)", Vector2(1, 0.4)], ["duro visto de lado", Vector2(1, 0.4)]]
	var hoja := Image.create(LADO * tiempos.size(), LADO * filas.size(), false, Image.FORMAT_RGBA8)
	_zoom(52.0)
	_cam.global_position = Vector2(0, -30)
	for fila in filas.size():
		var dvec: Vector2 = (filas[fila][1] as Vector2).normalized()
		var g := _enemigo("golem_arcilla", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var bg: Rect2 = _bulto(g)
		var col: Color = ed.color_visual(0.5)
		var spr: AnimatedSprite2D = g["spr"]
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/tinte_constructo.gdshader")
		spr.material = mat
		var piezas: Array = []
		var tinte_de: Callable
		match fila:
			0:
				piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.COCERSE, Vector2.ZERO, bg, Vector2.ZERO, col, 401, 0.0, 1.0), "t0": 0.0})
				piezas.append({"n": ConstructoAire.estado(self, ConstructoAire.Modo.DURO, bg, Vector2.ZERO, col, 402), "t0": 0.0})
				tinte_de = func(t): return [clampf(t / 0.4, 0.0, 1.0), _TACTICO_G.TERRACOTA, 0.0]
			1:
				piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.VAPOR, Vector2.ZERO, bg, Vector2.ZERO, col, 403, 0.0, 1.0), "t0": 0.0})
				piezas.append({"n": ConstructoAire.estado(self, ConstructoAire.Modo.BLANDO, bg, Vector2.ZERO, col, 404), "t0": 0.0})
				tinte_de = func(t): return [1.0, _TACTICO_G.TERRACOTA if t < 0.15 else _TACTICO_G.BARRO_MOJADO, 0.0 if t < 0.15 else 1.0]
			2:
				piezas.append({"n": ConstructoAire.estado(self, ConstructoAire.Modo.BLANDO, bg, Vector2.ZERO, col, 405), "t0": 0.0})
				tinte_de = func(_t): return [1.0, _TACTICO_G.BARRO_MOJADO, 1.0]
			3:
				piezas.append({"n": ConstructoAire.estado(self, ConstructoAire.Modo.DURO, bg, Vector2.ZERO, col, 406), "t0": 0.0})
				tinte_de = func(_t): return [1.0, _TACTICO_G.TERRACOTA, 0.0]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			var ti: Array = tinte_de.call(t)
			mat.set_shader_parameter("fuerza", ti[0])
			mat.set_shader_parameter("tinte", ti[1])
			mat.set_shader_parameter("humedo", ti[2])
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Golem · %s · %.2f s" % [filas[fila][0], t])
		await _limpiar(piezas, [g["nodo"]])
	_guardar(hoja, _carpeta_golem(salida), "estados")


# ------------------------------------------------------------
#  LA GARGOLA (30/09, constructos paso 2, ConstructoAire). Carpeta enemigos/gargola/.
# ------------------------------------------------------------
func _carpeta_gargola(salida: String) -> String:
	var c: String = "%s/gargola" % salida
	DirAccess.make_dir_recursive_absolute(c)
	return c


func _hoja_gargola_basico(salida: String) -> void:
	var tiempos: Array = [-0.3, -0.15, -0.05, 0.0, 0.05, 0.12, 0.25, 0.45]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(72.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo("gargola", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var fig_p: Vector2 = _al_alcance(g, dvec, ed.alcance_real())
		var fig := _figura(fig_p, AZUL)
		var bg: Rect2 = _bulto(g)
		_cam.global_position = (bg.get_center() + fig_p) * 0.5
		var piezas: Array = [
			{"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.SURCOS, bg.get_center(), _caja_fig(fig), fig_p,
				ed.color_visual(0.5), 501 + fila, 0.0, 1.0), "t0": 0.0},
			{"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.POLVO, Vector2.ZERO, _caja_fig(fig), fig_p,
				ed.color_visual(0.5), 511 + fila, 0.0, 1.0), "t0": 0.02}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "embestida", _marco_golpe(g, t, String(ed.anim_basico)))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Gargola · zarpazo (y lento: polvo) · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"], fig])
	_guardar(hoja, _carpeta_gargola(salida), "basico")


# EL PICADO: columna 1 cargando (suspendida en el aire, la sombra en el suelo, la huella roja); luego el salto a la
# huella con su arco (el de CombatTactico.mover_enemigo: T_SALTO_BICHO, y aterriza en el golpe) mientras hace 'picar'.
func _hoja_gargola_picado(salida: String) -> void:
	var tiempos: Array = [-0.4, -0.25, -0.12, -0.04, 0.0, 0.05, 0.12, 0.22, 0.4]
	var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	var ab: AbilityData = load("res://resources/abilities/gargola_picado.tres")
	_zoom(112.0)
	if _huella_g == null:
		_huella_g = Node2D.new()
		_huella_g.z_index = 1
		add_child(_huella_g)
		_huella_g.draw.connect(func():
			if _forma_g != null:
				CombatFormas.dibujar(_forma_g, _huella_g, Color(1.0, 0.3, 0.25)))
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo("gargola", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var rd: Rect2 = g["rd"]
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var f = CombatFormas.de_habilidad_mapa(ab, Vector2.ZERO, pisa, ed.alcance_real(), dvec * 80.0, pisa)
		# Los dos de dentro, a los lados de donde cae (ella cae en medio).
		var sitios: Array = [f.centro + dvec.orthogonal() * f.radio * 0.6 + Vector2(0, 4),
			f.centro - dvec.orthogonal() * f.radio * 0.6 + Vector2(0, 4)]
		var figs: Array = []
		for sp in sitios:
			figs.append(_figura(sp, AZUL))
		_cam.global_position = f.centro * 0.5 + Vector2(0, -28)
		var spr: AnimatedSprite2D = g["spr"]
		var sp0: Vector2 = spr.position
		# 1) CARGANDO: suspendida (el vuelo, un marco de en medio).
		_mirar(g, dvec, "vuelo", 2)
		_forma_g = f
		_huella_g.queue_redraw()
		await _viñeta(hoja, 0, fila, "Gargola · Picado · %s · cargando (en el aire)" % DIRS[fila][0])
		_forma_g = null
		_huella_g.queue_redraw()
		var piezas: Array = []
		var antes: int = get_child_count()
		SueloRoto.lanzar(self, f, ab.suelo_roto, 601 + fila, ab.forma_nucleo)
		for i in range(antes, get_child_count()):
			piezas.append({"n": get_child(i), "t0": 0.0})
		for i in figs.size():
			var fg: ColorRect = figs[i]
			piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.PICADO, f.centro + Vector2(0, -30),
				_caja_fig(fg), sitios[i], ed.color_visual(0.5), 611 + fila * 3 + i, 0.0, 1.0, 1.3),
				"t0": SueloRoto.retraso_caja(f, _caja_fig(fg), ab.suelo_roto)})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		var arco: float = _TACTICO_G.ALTO_SALTO_BICHO * clampf(pisa / 10.0, 1.0, 2.5)
		var t_salto: float = _TACTICO_G.T_SALTO_BICHO
		for c in tiempos.size():
			var t: float = tiempos[c]
			var u: float = clampf((t + t_salto) / t_salto, 0.0, 1.0)
			var k: float = 1.0 - (1.0 - u) * (1.0 - u)
			(g["nodo"] as Node2D).position = Vector2.ZERO.lerp(f.centro, k)
			spr.position = sp0 - Vector2(0.0, sin(PI * u) * arco)
			_mirar(g, dvec, "picar", _marco_golpe(g, t, "picar", "picar"))
			_en(piezas, t)
			await _viñeta(hoja, c + 1, fila, "Gargola · Picado · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"]] + figs)
	_guardar(hoja, _carpeta_gargola(salida), "picado")


func _hoja_gargola_mirada(salida: String) -> void:
	var tiempos: Array = [-0.2, 0.0, 0.1, 0.2, 0.3, 0.45, 0.7, 1.1]
	var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	var ab: AbilityData = load("res://resources/abilities/gargola_mirada.tres")
	_zoom(82.0)
	if _huella_g == null:
		_huella_g = Node2D.new()
		_huella_g.z_index = 1
		add_child(_huella_g)
		_huella_g.draw.connect(func():
			if _forma_g != null:
				CombatFormas.dibujar(_forma_g, _huella_g, Color(1.0, 0.3, 0.25)))
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo("gargola", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var rd: Rect2 = g["rd"]
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var frente: float = _TACTICO_G.frente_dibujo(g["nodo"], Vector2.ZERO, dvec)
		var f = CombatFormas.de_habilidad_mapa(ab, Vector2.ZERO, maxf(pisa, frente), ed.alcance_real(), dvec * 90.0, frente * 0.85)
		var sitios: Array = [f.origen + dvec * f.radio * 0.4 + Vector2(0, 13), f.origen + dvec.rotated(0.2) * f.radio * 0.78 + Vector2(0, 13)]
		var figs: Array = []
		for sp in sitios:
			figs.append(_figura(sp, AZUL))
		_cam.global_position = f.origen + dvec * f.radio * 0.4 + Vector2(0, -10)
		_mirar(g, dvec)
		_forma_g = f
		_huella_g.queue_redraw()
		await _viñeta(hoja, 0, fila, "Gargola · Mirada petrea · %s · apuntando (cono)" % DIRS[fila][0])
		_forma_g = null
		_huella_g.queue_redraw()
		var piezas: Array = []
		var antes: int = get_child_count()
		SueloRoto.lanzar(self, f, ab.suelo_roto, 701 + fila, ab.forma_nucleo)
		for i in range(antes, get_child_count()):
			piezas.append({"n": get_child(i), "t0": 0.0})
		var bg: Rect2 = _bulto(g)
		for i in figs.size():
			var fg: ColorRect = figs[i]
			piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.PETREA, bg.get_center(), _caja_fig(fg),
				sitios[i], ed.color_visual(0.5), 711 + fila * 3 + i, 0.0, 1.0),
				"t0": SueloRoto.retraso_caja(f, _caja_fig(fg), ab.suelo_roto)})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "mirada", _marco_golpe(g, t, "mirada", "mirada"))
			_en(piezas, t)
			await _viñeta(hoja, c + 1, fila, "Gargola · Mirada petrea · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"]] + figs)
	_guardar(hoja, _carpeta_gargola(salida), "mirada")


# LOS ESTADOS: fila 1 se posa y se hace estatua (gris); fila 2 le pegan posada (destello seco y chispas); fila 3 se
# mueve y deja de ser piedra (vuelve el color y le caen trocitos); fila 4 en el aire (el vuelo de la carga, en bucle).
func _hoja_gargola_estados(salida: String) -> void:
	var tiempos: Array = [0.0, 0.1, 0.2, 0.35, 0.5, 0.7, 1.0]
	var filas: Array = [["se posa: estatua", Vector2(0, 1)], ["le pegan posada: la mitad", Vector2(1, 0.4)],
		["se mueve: deja de ser piedra", Vector2(0, 1)], ["en el aire (cargando el Picado)", Vector2(1, 0.4)]]
	var hoja := Image.create(LADO * tiempos.size(), LADO * filas.size(), false, Image.FORMAT_RGBA8)
	_zoom(52.0)
	_cam.global_position = Vector2(0, -30)
	for fila in filas.size():
		var dvec: Vector2 = (filas[fila][1] as Vector2).normalized()
		var g := _enemigo("gargola", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var bg: Rect2 = _bulto(g)
		var col: Color = ed.color_visual(0.5)
		var spr: AnimatedSprite2D = g["spr"]
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/tinte_constructo.gdshader")
		mat.set_shader_parameter("tinte", Vector3.ONE)
		mat.set_shader_parameter("piedra", 1.0)
		spr.material = mat
		var piezas: Array = []
		var gris_de: Callable
		match fila:
			0:
				gris_de = func(t): return clampf(t / _TACTICO_G.T_A_PIEDRA, 0.0, 1.0)
			1:
				piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.ESTATUA, bg.get_center() - dvec * 40.0,
					bg, Vector2.ZERO, col, 801, 0.0, 1.0), "t0": 0.1})
				gris_de = func(_t): return 1.0
			2:
				piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.DESPEREZA, Vector2.ZERO, bg, Vector2.ZERO,
					col, 802, 0.0, 1.0), "t0": 0.0})
				gris_de = func(t): return 1.0 - clampf(t / _TACTICO_G.T_A_PIEDRA, 0.0, 1.0)
			3:
				gris_de = func(_t): return 0.0
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			mat.set_shader_parameter("fuerza", gris_de.call(t))
			if fila == 3:
				_mirar(g, dvec, "vuelo", c % 6)
			elif fila == 2:
				_mirar(g, dvec, "walk" if t > 0.0 else "idle", c)
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Gargola · %s · %.2f s" % [filas[fila][0], t])
		await _limpiar(piezas, [g["nodo"]])
	_guardar(hoja, _carpeta_gargola(salida), "estados")


# ------------------------------------------------------------
#  EL COLOSO (01/10, constructos paso 2, ConstructoAire). Carpeta enemigos/coloso/.
# ------------------------------------------------------------
func _carpeta_coloso(salida: String) -> String:
	var c: String = "%s/coloso" % salida
	DirAccess.make_dir_recursive_absolute(c)
	return c


func _hoja_coloso_basico(salida: String) -> void:
	var tiempos: Array = [-0.4, -0.25, -0.1, 0.0, 0.05, 0.12, 0.25, 0.45]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(110.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo("coloso", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var fig_p: Vector2 = _al_alcance(g, dvec, ed.alcance_real())
		var fig := _figura(fig_p, AZUL)
		var bg: Rect2 = _bulto(g)
		_cam.global_position = (bg.get_center() + fig_p) * 0.5
		var piezas: Array = [
			{"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.MAZO, bg.get_center(), _caja_fig(fig), fig_p,
				ed.color_visual(0.5), 901 + fila, 0.0, 1.0, 1.5), "t0": 0.0},
			{"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.POLVO, Vector2.ZERO, _caja_fig(fig), fig_p,
				ed.color_visual(0.5), 911 + fila, 0.0, 1.0), "t0": 0.02}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "basico", _marco_golpe(g, t, String(ed.anim_basico), "basico"))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Coloso · manotazo (y lento: polvo) · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"], fig])
	_guardar(hoja, _carpeta_coloso(salida), "basico")


func _hoja_coloso_pisoton(salida: String) -> void:
	var tiempos: Array = [-0.3, -0.05, 0.0, 0.08, 0.16, 0.26, 0.4, 0.7]
	var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	var ab: AbilityData = load("res://resources/abilities/coloso_pisoton.tres")
	_zoom(120.0)
	if _huella_g == null:
		_huella_g = Node2D.new()
		_huella_g.z_index = 1
		add_child(_huella_g)
		_huella_g.draw.connect(func():
			if _forma_g != null:
				CombatFormas.dibujar(_forma_g, _huella_g, Color(1.0, 0.3, 0.25)))
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo("coloso", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var rd: Rect2 = g["rd"]
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var f = CombatFormas.de_habilidad_mapa(ab, Vector2.ZERO, pisa, ed.alcance_real(), dvec * 40.0, pisa)
		# Tres de los tuyos: uno cerca, uno a media distancia y otro al borde.
		var sitios: Array = [f.centro + dvec * f.radio * 0.4 + Vector2(0, 8),
			f.centro + dvec.rotated(1.2) * f.radio * 0.65, f.centro + dvec.rotated(-1.0) * f.radio * 0.9]
		var figs: Array = []
		for sp in sitios:
			figs.append(_figura(sp, AZUL))
		_cam.global_position = f.centro + Vector2(0, -30)
		_mirar(g, dvec)
		_forma_g = f
		_huella_g.queue_redraw()
		await _viñeta(hoja, 0, fila, "Coloso · Pisoton sismico · %s · cargando (huella roja)" % DIRS[fila][0])
		_forma_g = null
		_huella_g.queue_redraw()
		var piezas: Array = []
		var antes: int = get_child_count()
		SueloRoto.lanzar(self, f, ab.suelo_roto, 921 + fila, ab.forma_nucleo)
		for i in range(antes, get_child_count()):
			piezas.append({"n": get_child(i), "t0": 0.0})
		for i in figs.size():
			var fg: ColorRect = figs[i]
			piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.SISMO, Vector2.ZERO, _caja_fig(fg),
				sitios[i], ed.color_visual(0.5), 931 + fila * 3 + i, 0.0, 1.0),
				"t0": SueloRoto.retraso_caja(f, _caja_fig(fg), ab.suelo_roto)})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "sismico", _marco_golpe(g, t, "sismico", "sismico"))
			_en(piezas, t)
			await _viñeta(hoja, c + 1, fila, "Coloso · Pisoton sismico · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"]] + figs)
	_guardar(hoja, _carpeta_coloso(salida), "pisoton")


# LOS ESTADOS: fila 1 la Muralla (se planta: el pulso de las runas y los sillares), mirando al S; fila 2 igual de lado;
# fila 3 con la Muralla puesta (las runas brillan); fila 4 le intentan empujar (Imparable: se clava).
func _hoja_coloso_estados(salida: String) -> void:
	var tiempos: Array = [0.0, 0.15, 0.3, 0.45, 0.6, 0.9, 1.3]
	var filas: Array = [["Muralla: se planta", Vector2(0, 1)], ["Muralla de lado", Vector2(1, 0.4)],
		["con la Muralla: runas encendidas", Vector2(0, 1)], ["le empujan: Imparable", Vector2(1, 0.4)]]
	var hoja := Image.create(LADO * tiempos.size(), LADO * filas.size(), false, Image.FORMAT_RGBA8)
	_zoom(78.0)
	_cam.global_position = Vector2(0, -60)
	for fila in filas.size():
		var dvec: Vector2 = (filas[fila][1] as Vector2).normalized()
		var g := _enemigo("coloso", Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var bg: Rect2 = _bulto(g)
		var col: Color = ed.color_visual(0.5)
		var spr: AnimatedSprite2D = g["spr"]
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/tinte_constructo.gdshader")
		mat.set_shader_parameter("tinte", Vector3.ONE)
		spr.material = mat
		var piezas: Array = []
		match fila:
			0, 1:
				piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.MURALLA, Vector2.ZERO, bg, Vector2.ZERO,
					col, 941 + fila, 0.0, 1.0), "t0": _TACTICO_G.RUNAS_ESPERA})
			3:
				piezas.append({"n": ConstructoAire.sobre_cuerpo(self, ConstructoAire.Modo.CLAVADO, Vector2.ZERO, bg, Vector2.ZERO,
					col, 951, 0.0, 1.0), "t0": 0.0})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			var enc: float = 0.0
			if fila < 2:
				enc = 1.0 if t >= _TACTICO_G.RUNAS_ESPERA else 0.0
				_mirar(g, dvec, "muralla", mini(int(t / 0.125), 7))
			elif fila == 2:
				enc = 1.0
			mat.set_shader_parameter("fuerza", enc)
			mat.set_shader_parameter("runas", enc)
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Coloso · %s · %.2f s" % [filas[fila][0], t])
		await _limpiar(piezas, [g["nodo"]])
	_guardar(hoja, _carpeta_coloso(salida), "estados")


# ------------------------------------------------------------
#  EL MINOTAURO (02/10, paso 2, MinotauroAire). Carpeta enemigos/minotauro/. Su ficha es guardian_rango.
# ------------------------------------------------------------
const _MINO := "guardian_rango"

func _carpeta_mino(salida: String) -> String:
	var c: String = "%s/minotauro" % salida
	DirAccess.make_dir_recursive_absolute(c)
	return c


func _huella_lista() -> void:
	if _huella_g == null:
		_huella_g = Node2D.new()
		_huella_g.z_index = 1
		add_child(_huella_g)
		_huella_g.draw.connect(func():
			if _forma_g != null:
				CombatFormas.dibujar(_forma_g, _huella_g, Color(1.0, 0.3, 0.25)))


# Lo que se queda sobre el (escarbar, rabioso): suelta sus tandas hasta 't' (en el juego lo hace su _process).
func _estado_hasta(n: MinotauroAire, t: float) -> void:
	while n._siguiente <= t:
		n._t = n._siguiente
		n._soltar_tanda()
	n._t = t


func _hoja_mino_basico(salida: String) -> void:
	var tiempos: Array = [-0.4, -0.2, -0.08, -0.04, 0.0, 0.05, 0.12, 0.25]
	var hoja := Image.create(LADO * tiempos.size(), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	_zoom(100.0)
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo(_MINO, Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var fig_p: Vector2 = _al_alcance(g, dvec, ed.alcance_real())
		var fig := _figura(fig_p, AZUL)
		var bg: Rect2 = _bulto(g)
		_cam.global_position = (bg.get_center() + fig_p) * 0.5
		var piezas: Array = [{"n": MinotauroAire.sobre_cuerpo(self, MinotauroAire.Modo.HACHAZO, bg.get_center(),
			_caja_fig(fig), fig_p, 1201 + fila, 0.0, 1.0), "t0": 0.0}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "basico", _marco_golpe(g, t, String(ed.anim_basico), "basico"))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Minotauro · hachazo · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"], fig])
	_guardar(hoja, _carpeta_mino(salida), "basico")


# Si lo esquiva: el filo se clava en el suelo a su lado.
func _hoja_mino_esquiva(salida: String) -> void:
	var tiempos: Array = [-0.08, -0.04, 0.0, 0.05, 0.12, 0.25, 0.45]
	var filas: Array = [DIRS[2], DIRS[3], DIRS[4]]
	var hoja := Image.create(LADO * tiempos.size(), LADO * filas.size(), false, Image.FORMAT_RGBA8)
	_zoom(100.0)
	for fila in filas.size():
		var dvec: Vector2 = (filas[fila][1] as Vector2).normalized()
		var g := _enemigo(_MINO, Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var fig_p: Vector2 = _al_alcance(g, dvec, ed.alcance_real())
		var fig := _figura(fig_p, AZUL)
		var bg: Rect2 = _bulto(g)
		_cam.global_position = (bg.get_center() + fig_p) * 0.5
		var piezas: Array = [{"n": MinotauroAire.sobre_cuerpo(self, MinotauroAire.Modo.HACHAZO, bg.get_center(),
			_caja_fig(fig), fig_p, 1211 + fila, 0.0, 1.0, true), "t0": 0.0}]
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "basico", _marco_golpe(g, t, String(ed.anim_basico), "basico"))
			_en(piezas, t)
			await _viñeta(hoja, c, fila, "Minotauro · hachazo ESQUIVADO · %s · %.2f s" % [filas[fila][0], t])
		await _limpiar(piezas, [g["nodo"], fig])
	_guardar(hoja, _carpeta_mino(salida), "basico_esquivado")


func _hoja_mino_barrido(salida: String) -> void:
	var tiempos: Array = [-0.3, -0.1, 0.0, 0.06, 0.12, 0.2, 0.32, 0.6]
	var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	var ab: AbilityData = load("res://resources/abilities/minotauro_barrido.tres")
	_zoom(100.0)
	_huella_lista()
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo(_MINO, Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var rd: Rect2 = g["rd"]
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var frente: float = _TACTICO_G.frente_dibujo(g["nodo"], Vector2.ZERO, dvec)
		var f = CombatFormas.de_habilidad_mapa(ab, Vector2.ZERO, maxf(pisa, frente), ed.alcance_real(), dvec * 70.0, frente * 0.85)
		# Tres de los tuyos repartidos por el cono: a un lado, delante y al otro.
		var sitios: Array = [f.origen + dvec.rotated(1.0) * f.radio * 0.7 + Vector2(0, 13),
			f.origen + dvec * f.radio * 0.55 + Vector2(0, 13), f.origen + dvec.rotated(-1.05) * f.radio * 0.8 + Vector2(0, 13)]
		var figs: Array = []
		for sp in sitios:
			figs.append(_figura(sp, AZUL))
		_cam.global_position = f.origen + dvec * f.radio * 0.3 + Vector2(0, -25)
		_mirar(g, dvec)
		_forma_g = f
		_huella_g.queue_redraw()
		await _viñeta(hoja, 0, fila, "Minotauro · Barrido · %s · apuntando (cono)" % DIRS[fila][0])
		_forma_g = null
		_huella_g.queue_redraw()
		var piezas: Array = []
		var antes: int = get_child_count()
		SueloRoto.lanzar(self, f, ab.suelo_roto, 1221 + fila, ab.forma_nucleo)
		for i in range(antes, get_child_count()):
			piezas.append({"n": get_child(i), "t0": 0.0})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, "mino_barrido", _marco_golpe(g, t, "mino_barrido", "mino_barrido"))
			_en(piezas, t)
			await _viñeta(hoja, c + 1, fila, "Minotauro · Barrido · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"]] + figs)
	_guardar(hoja, _carpeta_mino(salida), "barrido")


# Tres columnas cargando (escarba) y luego el desliz y el enganche.
func _hoja_mino_cornada(salida: String) -> void:
	var cargas: Array = [0.3, 0.9, 1.5]
	var tiempos: Array = [-0.2, -0.12, -0.05, 0.0, 0.05, 0.12, 0.25, 0.45]
	var hoja := Image.create(LADO * (cargas.size() + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	var ab: AbilityData = load("res://resources/abilities/minotauro_cornada.tres")
	_zoom(115.0)
	_huella_lista()
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo(_MINO, Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var rd: Rect2 = g["rd"]
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var frente: float = _TACTICO_G.frente_dibujo(g["nodo"], Vector2.ZERO, dvec)
		var f = CombatFormas.de_habilidad_mapa(ab, Vector2.ZERO, maxf(pisa, frente), ed.alcance_real(), dvec * 90.0, frente * 0.85)
		var vic: Vector2 = f.origen + dvec * f.largo * 0.72 + Vector2(0, 13.0 * maxf(dvec.y, 0.0))
		var fig := _figura(vic, AZUL)
		# Donde se para: pegado a ella (como CombatTactico.mover_enemigo).
		var fin: Vector2 = vic - dvec * (8.0 + pisa)
		_cam.global_position = fin * 0.5 + Vector2(0, -30)
		var nodo: Node2D = g["nodo"]
		# CARGANDO: agazapado escarbando, con la huella roja.
		var esc: MinotauroAire = MinotauroAire.sobre_el(self, MinotauroAire.Modo.ESCARBA, _bulto(g), Vector2.ZERO, dvec, 1231 + fila)
		esc.set_process(false)
		_forma_g = f
		_huella_g.queue_redraw()
		for c in cargas.size():
			_mirar(g, dvec, "mino_agazapado", int(cargas[c] * 6.0) % 4)
			_estado_hasta(esc, cargas[c])
			_en([{"n": esc, "t0": 0.0}], cargas[c])
			await _viñeta(hoja, c, fila, "Minotauro · Cornada · %s · cargando (escarba) %.1f s" % [DIRS[fila][0], cargas[c]])
		esc.queue_free()
		_forma_g = null
		_huella_g.queue_redraw()
		var piezas: Array = []
		var antes: int = get_child_count()
		SueloRoto.lanzar(self, f, ab.suelo_roto, 1241 + fila, ab.forma_nucleo)
		for i in range(antes, get_child_count()):
			piezas.append({"n": get_child(i), "t0": 0.0})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		var bg0: Rect2 = _bulto(g)
		var engancha: MinotauroAire = MinotauroAire.sobre_cuerpo(self, MinotauroAire.Modo.CORNADA, bg0.get_center() + fin,
			_caja_fig(fig), vic, 1251 + fila, 0.0, 1.0)
		engancha.set_process(false)
		piezas.append({"n": engancha, "t0": 0.0})
		for c in tiempos.size():
			var t: float = tiempos[c]
			# El desliz: de sus pies al sitio donde se para, en los 0,2 s de antes del golpe.
			nodo.position = Vector2.ZERO.lerp(fin, clampf((t + 0.2) / 0.2, 0.0, 1.0))
			_mirar(g, dvec, "mino_cornada", _marco_golpe(g, t, "mino_cornada", "mino_cornada"))
			_en(piezas, t)
			await _viñeta(hoja, cargas.size() + c, fila, "Minotauro · Cornada · %s · %.2f s" % [DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"], fig])
	_guardar(hoja, _carpeta_mino(salida), "cornada")


# El Pisoton y el Bramido: circulo a su alrededor, tres de los tuyos (cerca, a media distancia y al borde).
func _hoja_mino_area(salida: String, nom: String, titulo: String, anim: String, zoom: float, tiempos: Array) -> void:
	var hoja := Image.create(LADO * (1 + tiempos.size()), LADO * DIRS.size(), false, Image.FORMAT_RGBA8)
	var ab: AbilityData = load("res://resources/abilities/minotauro_%s.tres" % nom)
	_zoom(zoom)
	_huella_lista()
	for fila in DIRS.size():
		var dvec: Vector2 = (DIRS[fila][1] as Vector2).normalized()
		var g := _enemigo(_MINO, Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var rd: Rect2 = g["rd"]
		var pisa: float = maxf(rd.size.x * 0.33, 4.0)
		var f = CombatFormas.de_habilidad_mapa(ab, Vector2.ZERO, pisa, ed.alcance_real(), dvec * 40.0, pisa)
		var sitios: Array = [f.centro + dvec * f.radio * 0.4 + Vector2(0, 8),
			f.centro + dvec.rotated(1.2) * f.radio * 0.65, f.centro + dvec.rotated(-1.0) * f.radio * 0.9]
		var figs: Array = []
		for sp in sitios:
			figs.append(_figura(sp, AZUL))
		_cam.global_position = f.centro + Vector2(0, -30)
		_mirar(g, dvec)
		_forma_g = f
		_huella_g.queue_redraw()
		await _viñeta(hoja, 0, fila, "Minotauro · %s · %s · su huella" % [titulo, DIRS[fila][0]])
		_forma_g = null
		_huella_g.queue_redraw()
		var piezas: Array = []
		var antes: int = get_child_count()
		SueloRoto.lanzar(self, f, ab.suelo_roto, 1261 + fila, ab.forma_nucleo)
		for i in range(antes, get_child_count()):
			piezas.append({"n": get_child(i), "t0": 0.0})
		for i in figs.size():
			var fg: ColorRect = figs[i]
			var t0: float = SueloRoto.retraso_caja(f, _caja_fig(fg), ab.suelo_roto)
			if nom == "pisoton":
				piezas.append({"n": MinotauroAire.sobre_cuerpo(self, MinotauroAire.Modo.SISMO, Vector2.ZERO, _caja_fig(fg),
					sitios[i], 1271 + fila * 3 + i, 0.0, 1.0), "t0": t0})
			piezas.append({"n": BestiaAire.temblor(self, fg, _caja_fig(fg), 1281 + fila * 3 + i, 0.0, 1.0), "t0": t0})
		for pz in piezas:
			(pz["n"] as Node).set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			_mirar(g, dvec, anim, _marco_golpe(g, t, anim, anim))
			_en(piezas, t)
			await _viñeta(hoja, c + 1, fila, "Minotauro · %s · %s · %.2f s" % [titulo, DIRS[fila][0], t])
		await _limpiar(piezas, [g["nodo"]] + figs)
	_guardar(hoja, _carpeta_mino(salida), nom)


func _hoja_mino_pisoton(salida: String) -> void:
	await _hoja_mino_area(salida, "pisoton", "Pisoton atronador", "mino_pisoton", 110.0,
		[-0.25, -0.05, 0.0, 0.06, 0.14, 0.24, 0.4, 0.75])


func _hoja_mino_bramido(salida: String) -> void:
	await _hoja_mino_area(salida, "bramido", "Bramido embravecido", "mino_bramido", 170.0,
		[-0.3, -0.05, 0.05, 0.15, 0.3, 0.45, 0.7, 1.0])


# LA RABIA: al cruzar el umbral (cuerno que vuela, fogonazo, vaho) y despues (ojos rojos, rojizo y vaho a ratos).
func _hoja_mino_rabia(salida: String) -> void:
	var tiempos: Array = [-0.1, 0.05, 0.15, 0.3, 0.5, 0.7, 1.2, 2.6]
	var filas: Array = [DIRS[4], DIRS[2], DIRS[1], DIRS[0]]
	var hoja := Image.create(LADO * tiempos.size(), LADO * filas.size(), false, Image.FORMAT_RGBA8)
	_zoom(80.0)
	for fila in filas.size():
		var dvec: Vector2 = (filas[fila][1] as Vector2).normalized()
		var g := _enemigo(_MINO, Vector2.ZERO, dvec)
		var ed: EnemyData = g["ed"]
		var spr: AnimatedSprite2D = g["spr"]
		var normal: SpriteFrames = spr.sprite_frames
		var roto: SpriteFrames = SpritesEnemigo.frames_roto_de(ed, 0.5)
		var mat := ShaderMaterial.new()
		mat.shader = load("res://shaders/rabia_minotauro.gdshader")
		spr.material = mat
		var bg: Rect2 = _bulto(g)
		_cam.global_position = bg.get_center() + Vector2(0, 10)
		var rab: MinotauroAire = MinotauroAire.sobre_el(self, MinotauroAire.Modo.RABIA, bg, Vector2.ZERO, dvec, 1291 + fila)
		var rabioso: MinotauroAire = MinotauroAire.sobre_el(self, MinotauroAire.Modo.RABIOSO, bg, Vector2.ZERO, dvec, 1295 + fila)
		rab.set_process(false)
		rabioso.set_process(false)
		for c in tiempos.size():
			var t: float = tiempos[c]
			spr.sprite_frames = roto if t >= 0.0 and roto != null else normal
			_mirar(g, dvec, "idle", c % 8)
			mat.set_shader_parameter("encendido", 1.0 if t >= 0.0 else 0.0)
			_en([{"n": rab, "t0": 0.0}], t)
			if t >= 0.0:
				_estado_hasta(rabioso, t)
				_en([{"n": rabioso, "t0": 0.0}], t)
			await _viñeta(hoja, c, fila, "Minotauro · entra en RABIA · %s · %.2f s" % [filas[fila][0], t])
		await _limpiar([{"n": rab}, {"n": rabioso}], [g["nodo"]])
	_guardar(hoja, _carpeta_mino(salida), "rabia")
