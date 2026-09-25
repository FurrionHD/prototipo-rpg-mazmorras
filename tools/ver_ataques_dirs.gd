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
	["estoque", "estocada_penetrante"], ["estoque", "fintas"], ["estoque", "punzada_al_nervio"],
	["estoque", "paso_ligero"], ["estoque", "danza_de_acero"], ["estoque", "en_guardia"],
	["espada", "basico"], ["espada", "tajo_quebrantador"], ["espada", "doble_tajo"], ["espada", "cambio_de_ritmo"],
	["espada", "senalar_el_hueco"], ["espada", "corte_de_tendones"],
	["larga", "basico"], ["larga", "tajo_pesado"], ["larga", "tajo_desarmante"], ["larga", "estocada_marcial"],
	["larga", "guardia_rota"],
	["escudo", "golpe_escudo_pequeno"], ["escudo", "golpe_escudo_normal"], ["escudo", "golpe_escudo_grande"],
]
const ALCANCE := {"martillo": 32.25, "mandoble": 34.5, "hacha": 32.25, "daga": 15.0, "estoque": 32.25,
	"espada": 18.75, "larga": 23.25, "escudo": 23.25}
# LA ESPADA CORTA (EspadaAire), como la daga: golpe a golpe sobre cada cuerpo. "basico" no tiene ficha: el
# tajo de siempre sobre el de delante.
const MOMENTOS_ESPADA := {
	"basico": [-0.04, -0.01, 0.02, 0.08, 0.16],
	"tajo_quebrantador": [0.03, 0.07, 0.11, 0.18, 0.35],
	"doble_tajo": [-0.06, -0.01, 0.12, 0.2, 0.34],
	"cambio_de_ritmo": [0.04, 0.1, 0.16, 0.24, 0.4],
	"senalar_el_hueco": [-0.02, 0.03, 0.12, 0.4, 0.8],
	"corte_de_tendones": [0.03, 0.07, 0.11, 0.18, 0.35],
	# LA ESPADA LARGA y el ESCUDO (25/09), por el mismo camino (EspadaAire, EstoqueAire, EscudoAire).
	"tajo_pesado": [-0.03, 0.02, 0.07, 0.14, 0.45],
	"tajo_desarmante": [0.03, 0.07, 0.12, 0.2, 0.4],
	"estocada_marcial": [-0.03, 0.0, 0.03, 0.08, 0.2],
	"guardia_rota": [0.04, 0.1, 0.2, 0.26, 0.4],
	"golpe_escudo_pequeno": [-0.03, 0.02, 0.07, 0.13, 0.3],
	"golpe_escudo_normal": [-0.03, 0.02, 0.07, 0.13, 0.3],
	"golpe_escudo_grande": [-0.03, 0.02, 0.07, 0.13, 0.3],
}
# EL ESTOQUE (EstoqueAire), como la daga: golpe a golpe sobre cada cuerpo.
const MOMENTOS_ESTOQUE := {
	"estocada_penetrante": [-0.03, 0.0, 0.03, 0.08, 0.2],
	"fintas": [-0.1, -0.05, 0.0, 0.07, 0.14],
	"punzada_al_nervio": [-0.03, 0.0, 0.05, 0.1, 0.2],
	"paso_ligero": [0.05, 0.12, 0.2, 0.24, 0.38],
	"danza_de_acero": [0.06, 0.16, 0.26, 0.36, 0.55],
	# Tres de la postura al activarla y dos de la esquiva en guardia (el golpe llega a los 0.6).
	"en_guardia": [0.05, 0.12, 0.2, 0.63, 0.72],
}
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
		var ab: AbilityData
		if nom == "basico":
			ab = AbilityData.new()
			ab.nombre = "Tajo (basico)"
			ab.forma = CombatFormas.Tipo.CIRCULO
			ab.forma_apunte = CombatFormas.Apunte.DELANTE
			ab.forma_radio = 10.0
		else:
			ab = load("res://resources/abilities/%s.tres" % nom)
		var tiempos: Array = MOMENTOS_DAGA.get(nom, []) if arma == "daga" \
			else (MOMENTOS_ESTOQUE.get(nom, []) if arma == "estoque" \
			else (MOMENTOS_ESPADA.get(nom, []) if arma in ["espada", "larga", "escudo"] \
			else MOMENTOS.get(ab.suelo_roto, [])))
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
			_forma_huella = f if int(ab.forma) >= 0 and nom != "basico" else null
			_huella.queue_redraw()
			await _viñeta(hoja, 0, fila, "%s · %s · apuntando" % [ab.nombre, dir_n])
			_forma_huella = null
			_huella.queue_redraw()
			if tiempos.is_empty():
				continue
			if arma == "daga":
				await _efecto_daga(ab, nom, f, fila, hoja, tiempos, dir_n, yo)
				continue
			if arma == "estoque":
				await _efecto_estoque(ab, nom, f, fila, hoja, tiempos, dir_n, yo)
				continue
			if arma in ["espada", "larga", "escudo"]:
				await _efecto_espada(ab, nom, f, fila, hoja, tiempos, dir_n, yo)
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


# EL ESTOQUE: como la daga, y el Paso ligero y la Danza MUEVEN la figura azul (con su rastro).
func _efecto_estoque(ab: AbilityData, nom: String, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2) -> void:
	var semilla: int = 700 + fila * 13
	var alto := Vector2(0.0, -EstoqueAire.ALTO_TORSO)
	var cajas: Array = []
	for p in _enemigos:
		var r := Rect2(p - Vector2(7, 26), Vector2(14, 26))
		if f.toca(r):
			cajas.append(r)
	cajas.sort_custom(func(a, b): return a.get_center().distance_squared_to(yo) < b.get_center().distance_squared_to(yo))
	var piezas: Array = []   # {n, t0}
	var camino: Array = []   # [de, a, dur] si la figura se mueve
	var esquiva: EstoqueAire = null
	match nom:
		"en_guardia":
			# La hoja mira hacia la fila; la esquiva, de un golpe que viene de ahi.
			var hacia: Vector2 = (DIRS[fila][1] as Vector2).normalized()
			var mano: Vector2 = yo + Vector2(5.0, -EstoqueAire.ALTO_TORSO)
			piezas.append({"n": EstoqueAire.postura(self, EstoqueAire.Modo.GUARDIA, null, yo, hacia, semilla, 0.0, 1.0,
				mano), "t0": 0.0})
			esquiva = EstoqueAire.postura(self, EstoqueAire.Modo.ESQUIVA, _yo_fig, yo, hacia, semilla, 0.0, 1.0, mano,
				true, Rect2(yo - Vector2(7, 26), Vector2(14, 26)))
			piezas.append({"n": esquiva, "t0": 0.6})
		"estocada_penetrante":
			for i in cajas.size():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.PENETRANTE, yo + alto, cajas[i], false,
					i == 0, 0, semilla + i, 0.0, 1.0), "t0": 0.0})
		"fintas":
			var g: int = 2 + int(floor(0.7 * float(maxi(cajas.size(), 1) - 1)))
			for i in g:
				if cajas.is_empty():
					break
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.FINTA if i == 0 else EstoqueAire.Modo.PUNZADA,
					yo + alto, cajas[i % cajas.size()],
					false, i == 1, i, semilla + i, 0.0, 1.0), "t0": 0.075 * float(i)})
		"punzada_al_nervio":
			if not cajas.is_empty():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.NERVIO, yo + alto, cajas[0], false, false, 0,
					semilla, 0.0, 1.0), "t0": 0.0})
		"paso_ligero":
			# Nadie a tiro al empezar (el anillo esta lejos): das el paso y le pegas al que quede a tiro.
			var dest: Vector2 = f.centro
			for p in _enemigos:
				if dest.distance_to(p) < 22.0:
					dest = p + (dest - p).normalized() * 22.0
			camino = [yo, dest, 0.16]
			piezas.append({"n": EstoqueAire.rastro(self, yo, dest, 0.16, semilla), "t0": 0.0})
			var mejor: Rect2 = Rect2()
			var d_mejor: float = INF
			for p in _enemigos:
				var r2 := Rect2(p - Vector2(7, 26), Vector2(14, 26))
				var cerca := Vector2(clampf(dest.x, r2.position.x, r2.end.x), clampf(dest.y, r2.position.y, r2.end.y))
				var hueco: float = dest.distance_to(cerca) - PISA
				if hueco <= ALCANCE["estoque"] and hueco < d_mejor:
					d_mejor = hueco
					mejor = r2
			if mejor.has_area():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.PUNZADA, dest + alto, mejor, false, false, 0,
					semilla, 0.0, 1.0), "t0": 0.2})
		"danza_de_acero":
			# Cruzas la linea entera (sin acabar encima de nadie) y cada estocada cae al pasar a su lado.
			var fin: Vector2 = f.origen + f.dir * f.largo
			for p in _enemigos:
				if fin.distance_to(p) < 22.0:
					fin = p - f.dir * 22.0
			var dur: float = yo.distance_to(fin) / EstoqueAire.V_DANZA
			camino = [yo, fin, dur]
			piezas.append({"n": EstoqueAire.rastro(self, yo, fin, dur, semilla), "t0": 0.0})
			var g2: int = 3 + int(floor(0.7 * float(maxi(cajas.size(), 1) - 1)))
			for i in g2:
				if cajas.is_empty():
					break
				var r3: Rect2 = cajas[mini(i * cajas.size() / g2, cajas.size() - 1)]
				var cerca3 := Vector2(clampf(yo.x, r3.position.x, r3.end.x), clampf(yo.y, r3.position.y, r3.end.y))
				var t0: float = yo.distance_to(cerca3) / EstoqueAire.V_DANZA + 0.05 * float(i % 2)
				var ahi: Vector2 = yo.lerp(fin, clampf(t0 / maxf(dur, 0.01), 0.0, 1.0))
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.DANZA, ahi + alto - f.dir * 12.0, r3, false,
					i == 0, i, semilla + i, 0.0, 1.0), "t0": t0})
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).set_process(false)
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		for pz in piezas:
			var n: Node2D = pz["n"]
			if n == null:
				continue
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			var su = n.get("_suelo")
			if su is Node2D:
				(su as Node2D).queue_redraw()
		if not camino.is_empty():
			var u: float = clampf(t / float(camino[2]), 0.0, 1.0)
			_yo_fig.position = (camino[0] as Vector2).lerp(camino[1], u) - Vector2(7, 26)
		# La esquiva mueve la figura (en el juego lo hace su _process, aqui parado).
		if esquiva != null:
			_yo_fig.position = esquiva._base_muneco + esquiva._a * esquiva._lado * esquiva._cuanto_fuera(t - 0.6)
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, t])
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).queue_free()
	_yo_fig.position = yo - Vector2(7, 26)
	await get_tree().process_frame


# LA ESPADA CORTA: cada golpe sobre las figuras que pilla su huella; Cambio de ritmo MUEVE la figura azul
# (avance, al compas de la Danza) y cada tajo cae al pasar.
func _efecto_espada(ab: AbilityData, nom: String, f, fila: int, hoja: Image, tiempos: Array, dir_n: String,
		yo: Vector2) -> void:
	BarridoAire.ritmo = 1.0
	var semilla: int = 500 + fila * 13
	var alto := Vector2(0.0, -EspadaAire.ALTO_TORSO)
	var cajas: Array = []
	for p in _enemigos:
		var r := Rect2(p - Vector2(7, 26), Vector2(14, 26))
		if f.toca(r):
			cajas.append(r)
	cajas.sort_custom(func(a, b): return a.get_center().distance_squared_to(yo) < b.get_center().distance_squared_to(yo))
	var piezas: Array = []   # {n, t0}
	var camino: Array = []
	var hacia_fila: Vector2 = f.dir
	match nom:
		"basico":
			# El basico no tiene huella: le pega al que tengas mas a mano hacia donde miras.
			var mejor: Rect2 = Rect2()
			var d_mejor: float = INF
			for p in _enemigos:
				var dd: float = absf(angle_difference((p - yo).angle(), hacia_fila.angle())) * 60.0 + (p - yo).length()
				if dd < d_mejor:
					d_mejor = dd
					mejor = Rect2(p - Vector2(7, 26), Vector2(14, 26))
			if mejor.has_area():
				piezas.append({"n": EspadaAire.golpe(self, EspadaAire.Modo.TAJO, yo + alto, mejor, false, false, 0,
					semilla, 0.0, 1.0), "t0": 0.0})
		"tajo_quebrantador", "corte_de_tendones", "doble_tajo":
			# El barrido (por el camino del suelo, como el juego) y, en cada cuerpo, lo suyo a su instante.
			var s_b: Node2D = SueloRoto.lanzar(self, f, ab.suelo_roto, semilla)
			# El Doble tajo acaba su primer barrido EN el golpe: arranca T_BARRE antes.
			piezas.append({"n": s_b, "t0": -EspadaAire.T_BARRE if nom == "doble_tajo" else 0.0})
			var m: int = EspadaAire.Modo.QUEBRANTADOR if nom == "tajo_quebrantador" \
				else (EspadaAire.Modo.TENDONES if nom == "corte_de_tendones" else EspadaAire.Modo.DOBLE)
			var golpes_b: int = 2 if nom == "doble_tajo" else 1
			for i in cajas.size():
				var pies_i: Vector2 = Vector2((cajas[i] as Rect2).get_center().x, (cajas[i] as Rect2).end.y)
				var llega: float = SueloRoto.retraso(f, pies_i, ab.suelo_roto)
				for g in golpes_b:
					var t_g: float = llega + EspadaAire.T_ENTRE * float(g)
					piezas.append({"n": EspadaAire.golpe(self, m, yo + alto, cajas[i], false, i == 0, g,
						semilla + i * 7 + g, 0.0, 1.0), "t0": t_g})
					SangreMapa.salpicar(self, (cajas[i] as Rect2).get_center(), pies_i,
						(pies_i - yo).normalized().rotated(PI * 0.5) * 0.85 + (pies_i - yo).normalized() * 0.45,
						0.6, 77 + i + g)
					var n_s: Node2D = get_child(get_child_count() - 1)
					piezas.append({"n": n_s, "t0": t_g, "sangre": true})
		"tajo_pesado", "tajo_desarmante", "guardia_rota":
			# El barrido o la raja (camino del suelo) y, en cada cuerpo, su corte cuando le llega. El Tajo pesado cae
			# T_CAE antes del golpe. La Guardia rota ademas mete el ESCUDAZO por su linea, un golpe despues.
			var s_l: Node2D = SueloRoto.lanzar(self, f, ab.suelo_roto, semilla)
			piezas.append({"n": s_l, "t0": -EspadaAire.T_CAE if nom == "tajo_pesado" else 0.0})
			var m_l: int = EspadaAire.Modo.PESADO_C if nom == "tajo_pesado" \
				else (EspadaAire.Modo.DESARME if nom == "tajo_desarmante" else EspadaAire.Modo.QUEBRANTADOR)
			for i in cajas.size():
				var pies_l: Vector2 = Vector2((cajas[i] as Rect2).get_center().x, (cajas[i] as Rect2).end.y)
				var llega_l: float = SueloRoto.retraso(f, pies_l, ab.suelo_roto)
				piezas.append({"n": EspadaAire.golpe(self, m_l, yo + alto, cajas[i], false, i == 0, 0,
					semilla + i * 7, 0.0, 1.0), "t0": llega_l})
				SangreMapa.salpicar(self, (cajas[i] as Rect2).get_center(), pies_l,
					(pies_l - yo).normalized() if nom == "tajo_pesado"
					else (pies_l - yo).normalized().rotated(PI * 0.5) * 0.85 + (pies_l - yo).normalized() * 0.45,
					0.6, 77 + i)
				piezas.append({"n": get_child(get_child_count() - 1), "t0": llega_l, "sangre": true})
			if nom == "guardia_rota":
				var linea_e = CombatFormas.linea(yo, f.dir, ab.forma_escudo_largo, ShieldData.ANCHO_ESCUDAZO[1])
				for p in _enemigos:
					var r_e := Rect2(p - Vector2(7, 26), Vector2(14, 26))
					if linea_e.toca(r_e):
						var t_e: float = SueloRoto.retraso(f, Vector2(r_e.get_center().x, r_e.end.y), ab.suelo_roto) \
							+ EspadaAire.T_ENTRE
						piezas.append({"n": EscudoAire.golpe(self, EscudoAire.Modo.ESCUDAZO, yo + alto, r_e, false, false, 1,
							semilla + 99, 0.0, 1.0, true), "t0": t_e})
		"estocada_marcial":
			for i in cajas.size():
				piezas.append({"n": EstoqueAire.golpe(self, EstoqueAire.Modo.PENETRANTE, yo + alto, cajas[i], false,
					i == 0, 0, semilla + i, 0.0, 1.0), "t0": 0.0})
		"golpe_escudo_pequeno", "golpe_escudo_normal", "golpe_escudo_grande":
			# UN escudazo: la onda (con la chapa delante de ti) y el impacto en cada uno cuando le llega.
			piezas.append({"n": SueloRoto.lanzar(self, f, ab.suelo_roto, semilla), "t0": 0.0})
			for i in cajas.size():
				var llega_z: float = SueloRoto.retraso_caja(f, cajas[i], ab.suelo_roto)
				piezas.append({"n": EscudoAire.golpe(self, EscudoAire.Modo.ESCUDAZO, yo + alto, cajas[i], false,
					i == 0, 0, semilla + i, 0.0, 1.0), "t0": llega_z})
		"senalar_el_hueco":
			if not cajas.is_empty():
				for g in 2:
					piezas.append({"n": EspadaAire.golpe(self, EspadaAire.Modo.SENALAR, yo + alto, cajas[0], false, false, g,
						semilla + g, 0.0, 1.0), "t0": 0.09 * float(g)})
		"cambio_de_ritmo":
			var fin: Vector2 = f.origen + f.dir * f.largo
			for p in _enemigos:
				if fin.distance_to(p) < 22.0:
					fin = p - f.dir * 22.0
			var dur: float = yo.distance_to(fin) / EstoqueAire.V_DANZA
			camino = [yo, fin, dur]
			piezas.append({"n": EstoqueAire.rastro(self, yo, fin, dur, semilla), "t0": 0.0})
			for i in cajas.size():
				var r3: Rect2 = cajas[i]
				var cerca3 := Vector2(clampf(yo.x, r3.position.x, r3.end.x), clampf(yo.y, r3.position.y, r3.end.y))
				var t0: float = yo.distance_to(cerca3) / EstoqueAire.V_DANZA
				var ahi: Vector2 = yo.lerp(fin, clampf(t0 / maxf(dur, 0.01), 0.0, 1.0))
				piezas.append({"n": EspadaAire.golpe(self, EspadaAire.Modo.RITMO, ahi + alto - f.dir * 12.0, r3, false,
					i == 0, i, semilla + i, 0.0, 1.0), "t0": t0})
	for pz in piezas:
		if pz["n"] != null:
			(pz["n"] as Node).set_process(false)
	for col in tiempos.size():
		var t: float = float(tiempos[col])
		for pz in piezas:
			var n: Node2D = pz["n"]
			if n == null:
				continue
			if bool(pz.get("sangre", false)):
				var quiere: float = t - float(pz["t0"])
				var hecho: float = float(pz.get("hecho", 0.0))
				while hecho + 0.01 <= quiere:
					n.call("_process", 0.01)
					hecho += 0.01
				pz["hecho"] = hecho
				n.visible = quiere >= 0.0
				continue
			n.set("_t", t - float(pz["t0"]))
			n.queue_redraw()
			for hijo in ["_suelo", "_atras", "_delante"]:
				var su = n.get(hijo)
				if su is Node2D:
					(su as Node2D).queue_redraw()
		if not camino.is_empty():
			var u: float = clampf(t / float(camino[2]), 0.0, 1.0)
			_yo_fig.position = (camino[0] as Vector2).lerp(camino[1], u) - Vector2(7, 26)
		await _viñeta(hoja, col + 1, fila, "%s · %s · %.2f s" % [ab.nombre, dir_n, t])
	for pz in piezas:
		if pz["n"] != null:
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
