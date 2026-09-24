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
	["hacha", "hachazo_brutal"], ["hacha", "carniceria"], ["hacha", "desgarro"], ["hacha", "hendedura"],
	["hacha", "sed_de_sangre"],
	["daga", "rafaga"], ["daga", "punalada"], ["daga", "filo_emponzonado"], ["daga", "desaparecer"],
	["daga", "oportunista"],
]
const ALCANCE := {"martillo": 32.25, "mandoble": 34.5, "hacha": 32.25, "daga": 15.0}
# LA DAGA (DagaAire) pinta golpe a golpe sobre cada cuerpo: sus momentos van por habilidad.
const MOMENTOS_DAGA := {
	"rafaga": [-0.02, 0.03, 0.09, 0.16, 0.3],
	"punalada": [-0.04, 0.0, 0.03, 0.07, 0.16],
	"filo_emponzonado": [0.08, 0.25, 0.45, 0.7, 1.2],
	"desaparecer": [0.05, 0.2, 0.3, 0.45, 1.6],
	"oportunista": [0.04, 0.09, 0.15, 0.2, 0.3],
}
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
	# El hacha (HachaAire): en su reloj, que en la Carniceria, el Desgarro y la Hendedura arranca antes del golpe.
	9: [0.05, 0.11, 0.17, 0.25, 0.6],
	10: [0.06, 0.1, 0.29, 0.5, 0.9],
	11: [0.04, 0.08, 0.12, 0.17, 0.3],
	12: [0.04, 0.08, 0.14, 0.24, 0.6],
	13: [0.05, 0.15, 0.3, 0.45, 0.65],
}
const COLOR_HUELLA := Color(1.0, 0.72, 0.25)

var _cam: Camera2D
var _enemigos: Array = []    # donde estan los pies de cada figura roja
var _huella: Node2D
var _forma_huella = null
var _rotulo: Label
var _yo_fig: ColorRect = null


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


func _figura(p: Vector2, col: Color) -> ColorRect:
	var fig := ColorRect.new()
	fig.color = col
	fig.size = Vector2(14, 26)
	fig.position = p - Vector2(7, 26)
	fig.z_index = 1024
	fig.z_as_relative = false
	add_child(fig)
	return fig


func _correr() -> void:
	var salida: String = OS.get_environment("ATAQUES_SALIDA")
	if salida == "":
		salida = "user://ataques"
	DirAccess.make_dir_recursive_absolute(salida)
	var yo := Vector2.ZERO
	_yo_fig = _figura(yo, Color(0.35, 0.6, 1.0))
	# Enemigos alrededor: un anillo cerca y unos cuantos mas lejos, para ver hasta donde llega cada uno.
	# ATAQUES_ANILLO=34 -> el anillo de cerca mas pegado (la daga no llega a 62).
	var anillo: float = float(OS.get_environment("ATAQUES_ANILLO")) if OS.get_environment("ATAQUES_ANILLO") != "" else 62.0
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + 0.2
		_figura(Vector2(cos(a), sin(a)) * anillo, Color(0.8, 0.35, 0.35))
		_enemigos.append(Vector2(cos(a), sin(a)) * anillo)
	for i in 5:
		var a2: float = TAU * float(i) / 5.0 + 0.9
		_figura(Vector2(cos(a2), sin(a2)) * 118.0, Color(0.8, 0.35, 0.35))
		_enemigos.append(Vector2(cos(a2), sin(a2)) * 118.0)
	var pedidas: String = OS.get_environment("ATAQUES_LISTA")
	for h in HABILIDADES:
		var arma: String = h[0]
		var nom: String = h[1]
		if pedidas != "" and not (nom in pedidas.split(",")):
			continue
		var ab: AbilityData = load("res://resources/abilities/%s.tres" % nom)
		var tiempos: Array = MOMENTOS_DAGA.get(nom, []) if arma == "daga" else MOMENTOS.get(ab.suelo_roto, [])
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
			# El Oportunista se pone ENCIMA de un enemigo: el mas cercano a esa direccion.
			if nom == "oportunista":
				var mejor: float = INF
				for p in _enemigos:
					var dd: float = absf(angle_difference((p - yo).angle(), (DIRS[fila][1] as Vector2).angle())) \
						+ (p - yo).length() * 0.002
					if dd < mejor:
						mejor = dd
						hacia = p + Vector2(0, -13)
			var f = CombatFormas.de_habilidad_mapa(ab, yo, PISA, ALCANCE[arma], hacia)
			# La camara, un poco hacia donde va el ataque (salvo los que caen a tu alrededor).
			var hacia_cam: float = 0.0 if int(ab.forma_apunte) == CombatFormas.Apunte.ALREDEDOR else 0.35
			_cam.global_position = yo + (DIRS[fila][1] as Vector2).normalized() * medida * hacia_cam / acerca
			# 1) Apuntando: la huella.
			_forma_huella = f if int(ab.forma) >= 0 else null
			_huella.queue_redraw()
			await _viñeta(hoja, 0, fila, "%s · %s · apuntando" % [ab.nombre, dir_n])
			_forma_huella = null
			_huella.queue_redraw()
			if tiempos.is_empty():
				continue
			if arma == "daga":
				await _efecto_daga(ab, nom, f, fila, hoja, tiempos, dir_n, yo)
				continue
			# 2) El efecto, en sus cinco momentos.
			var f_suelo = f
			if ab.suelo_roto == SueloRoto.Tipo.ESTELA:
				f_suelo = CombatFormas.cono(yo, f.centro - yo, EstelaGolpe.RADIO, 0.0)
			var s: Node2D = SueloRoto.lanzar(self, f_suelo, ab.suelo_roto, 1234 + fila, ab.forma_nucleo)
			s.set_process(false)
			# LA SANGRE DEL HACHA: sale en el juego cuando el golpe entra (CombatTactico._on_impacto); aqui se
			# simula sobre cada figura que pilla la huella, a su instante (retraso del efecto).
			var sangres: Array = []   # {n: SangreMapa, t0, hecho}
			if ab.suelo_roto >= SueloRoto.Tipo.HACHAZO and ab.suelo_roto != SueloRoto.Tipo.MIRADA:
				BarridoAire.ritmo = 1.0
				var antes: float = HachaAire._antes(ab.suelo_roto - SueloRoto.Tipo.HACHAZO)
				for p in _enemigos:
					if not f.toca(Rect2(p - Vector2(7, 26), Vector2(14, 26))):
						continue
					var radial: Vector2 = (p - yo).normalized()
					var dir_g: Vector2 = radial.rotated(PI * 0.5) * 0.85 + radial * 0.45
					var fuerza: float = 1.0
					match ab.suelo_roto:
						SueloRoto.Tipo.HACHAZO: fuerza = 1.4
						SueloRoto.Tipo.DESGARRO: dir_g = -radial
						SueloRoto.Tipo.HENDEDURA: dir_g = radial
					SangreMapa.salpicar(self, p - Vector2(0, 13), p, dir_g, fuerza, 77 + fila)
					var n: Node2D = get_child(get_child_count() - 1)
					n.set_process(false)
					sangres.append({"n": n, "t0": antes + SueloRoto.retraso(f_suelo, p, ab.suelo_roto), "hecho": 0.0})
			for col in tiempos.size():
				s.set("_t", float(tiempos[col]))
				for sg in sangres:
					var quiere: float = float(tiempos[col]) - float(sg["t0"])
					while float(sg["hecho"]) + 0.01 <= quiere:
						(sg["n"] as Node2D).call("_process", 0.01)
						sg["hecho"] = float(sg["hecho"]) + 0.01
					(sg["n"] as Node2D).visible = quiere >= 0.0
				for hijo in ["_geiser", "_aire", "_atras", "_delante"]:
					if s.get(hijo) != null:
						(s.get(hijo) as Node2D).queue_redraw()
				s.queue_redraw()
				await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, float(tiempos[col])])
			s.queue_free()
			for sg in sangres:
				if is_instance_valid(sg["n"]):
					(sg["n"] as Node).queue_free()
			await get_tree().process_frame
		var ruta: String = "%s/%s_%s.png" % [salida, arma, nom]
		hoja.save_png(ruta)
		print("[hoja] ", ruta)
	get_tree().quit(0)


# LA DAGA: cada golpe sobre las figuras que pilla su huella, en su instante (como en el juego, donde los
# pinta CombatTactico._on_dibujo_mapa golpe a golpe).
func _efecto_daga(ab: AbilityData, nom: String, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2) -> void:
	BarridoAire.ritmo = 1.0
	var mano: Vector2 = yo + Vector2(0.0, -DagaAire.ALTO_TORSO)
	var cajas: Array = []
	if int(ab.forma) >= 0:
		for p in _enemigos:
			var r := Rect2(p - Vector2(7, 26), Vector2(14, 26))
			if f.toca(r):
				cajas.append(r)
	var cu: Vector2 = f.centro_util()
	cajas.sort_custom(func(a, b): return a.get_center().distance_squared_to(cu) < b.get_center().distance_squared_to(cu))
	var piezas: Array = []   # {n, t0}
	var salta_a: Vector2 = Vector2.INF
	var semilla: int = 900 + fila * 13
	match nom:
		"rafaga":
			var g: int = 3 + mini(4, int(floor(1.15 * float(maxi(cajas.size(), 1) - 1))))
			for i in g:
				if cajas.is_empty():
					break
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.RAFAGA, mano, cajas[i % cajas.size()],
					false, i == 2, i, semilla + i, 0.0, 1.0), "t0": 0.075 * float(i)})
		"punalada":
			for i in mini(cajas.size(), 2):
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.PUNALADA, mano, cajas[i], false, i == 0, 0,
					semilla + i, 0.0, 1.0), "t0": 0.0})
		"desaparecer":
			piezas.append({"n": SueloRoto.lanzar(self, f, SueloRoto.Tipo.HUMO, semilla), "t0": 0.0})
			for i in cajas.size():
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.TAJO, mano, cajas[i], false, false, i,
					semilla + i, 0.0, 1.0), "t0": DagaAire.T_HUMO_ABRE + 0.075 * float(i)})
		"oportunista":
			if not cajas.is_empty():
				var r0: Rect2 = cajas[0]
				var pies_v := Vector2(r0.get_center().x, r0.end.y - 2.0)
				salta_a = pies_v + (pies_v - yo).normalized() * (8.0 + 3.0 + 2.0)
				piezas.append({"n": DagaAire.sombra(self, yo, salta_a, semilla, 1.0), "t0": 0.0})
				piezas.append({"n": DagaAire.golpe(self, DagaAire.Modo.PUNALADA, salta_a + Vector2(0.0, -DagaAire.ALTO_TORSO),
					r0, false, true, 0, semilla, 0.0, 1.0), "t0": 0.2})
		"filo_emponzonado":
			piezas.append({"n": DagaAire.ponzona(self, null, semilla, 0.0, 1.0, mano + Vector2(6.0, 0.0)), "t0": 0.0})
	for pz in piezas:
		(pz["n"] as Node).set_process(false)
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		for pz in piezas:
			var n: Node2D = pz["n"]
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			var su = n.get("_suelo")
			if su is Node2D:
				(su as Node2D).queue_redraw()
		if salta_a != Vector2.INF:
			_yo_fig.position = (salta_a if t >= 0.08 else yo) - Vector2(7, 26)
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, t])
	for pz in piezas:
		(pz["n"] as Node).queue_free()
	_yo_fig.position = yo - Vector2(7, 26)
	await get_tree().process_frame


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
