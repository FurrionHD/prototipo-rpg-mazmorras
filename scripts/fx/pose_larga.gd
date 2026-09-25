# ============================================================
#  pose_larga.gd
#  LAS POSES DE LA ESPADA LARGA Y DE LAS HABILIDADES DE ESCUDO (25/09/2026). Aparte de PoseJugador para no
#  engordarlo mas; las pide PoseJugador._pose antes que nada.
#  SUS REFERENCIAS (revision-poses-arma): CON ESCUDO, la del caballero (Crozet de Epic Seven): piernas muy
#  abiertas y de tres cuartos, el ESCUDO pegado delante del torso y el brazo del arma abierto con el puño a la
#  altura del pecho y la hoja ALZADA en diagonal hacia arriba y atras. SIN ESCUDO, la de la espada corta con
#  una: puño bajo delante de la cadera, hoja en diagonal arriba-fuera, la otra mano abierta estirada atras.
#  Los nombres: '<anim>_larga' sin escudo y '<anim>_larga_esc' con el (MunecoJugador pone el '_esc'). Los de
#  ESCUDO ('<anim>_escudo') valen con cualquier arma de una mano: la derecha solo sujeta.
#  Los ejes de la hoja van en el sistema del cuerpo: x = hacia la izquierda del personaje (fuera de la
#  derecha es -x), y = al frente, z = arriba. Brazos: 0 = colgando, PI = arriba; los arcos pasan POR ENCIMA.
#  Sus IMPACTOS en CombatFX.IMPACTO_ANIM_MAPA (fotograma del golpe x marcos / fps): retocar uno = retocar el otro.
# ============================================================
extends RefCounted
class_name PoseLarga

const EJE_SOLA := Vector3(-0.45, 0.55, 0.75)      # = PoseJugador.ESPADA_EJE (la de la espada corta)
const EJE_ESC := Vector3(-0.5, -0.35, 0.8)         # con escudo: alzada, hacia fuera y hacia ATRAS
const EJE_MANO := Vector3(-0.2, 0.55, 0.8)         # el arma que solo se sujeta (las de escudo)
# El brazo del escudo pegado delante del torso (como la defensa con escudo, algo mas bajo).
const ESCUDO_BRAZO := 1.15
const ESCUDO_JUNTA := 0.25

const ANIMS := ["guardia_larga", "guardia_larga_and", "guardia_larga_cor", "desenvainar_larga", "tajo_larga",
	"rota_larga", "pesado_larga", "desarme_larga", "estocada_larga", "voto_larga", "voz_larga"]
const ANIMS_ESCUDO := ["golpe_escudo", "embestida_escudo", "provoca_escudo", "amparo_escudo", "rodela_escudo",
	"carne_escudo", "escolta_escudo"]


static func pose(anim: String, t: float) -> Dictionary:
	if anim in ANIMS_ESCUDO:
		return _escudo(anim, t)
	var esc: bool = anim.ends_with("_esc")
	var base: String = anim.trim_suffix("_esc")
	if not base in ANIMS and base != "defensa_larga":
		return {}
	match base:
		"guardia_larga": return guardia(t, esc, 0)
		"guardia_larga_and": return guardia(t, esc, 1)
		"guardia_larga_cor": return guardia(t, esc, 2)
		"desenvainar_larga": return _desenvainar(t, esc)
		"defensa_larga": return _defensa(t)
		"voto_larga": return _voto(t, esc)
		"voz_larga": return _voz(t, esc)
	return _golpe(t, base, esc)


static func _k(t: float, keys: Array) -> float:
	return SpriteLienzo.tramos(t, keys)


# 'm': 0 quieta, 1 andando, 2 corriendo.
static func guardia(t: float, esc: bool, m: int) -> Dictionary:
	var s: float = sin(TAU * t)
	var p: Dictionary
	if esc:
		p = {"brazo_der": 1.35 + 0.03 * s, "brazo_izq": ESCUDO_BRAZO + 0.02 * s, "junta_izq": ESCUDO_JUNTA,
			"torsion": 0.45, "eje_der": EJE_ESC, "bote": 0.25 * s, "inclina": 0.08, "agacha": 0.34, "paso": 0.55}
	else:
		p = {"brazo_der": 0.85 + 0.03 * s, "brazo_izq": -1.25 + 0.04 * s, "torsion": 0.4, "eje_der": EJE_SOLA,
			"bote": 0.25 * s, "inclina": 0.06, "agacha": 0.30, "paso": 0.50}
	if m == 1:
		p["paso"] = float(p["paso"]) + 0.12 * s
		p["bote"] = 0.4 * absf(s)
		p["agacha"] = float(p["agacha"]) - 0.06
		p["inclina"] = float(p["inclina"]) + 0.04
	elif m == 2:
		p["paso"] = 0.58 * s
		p["bote"] = 0.95 * absf(s)
		p["agacha"] = 0.10
		p["inclina"] = 0.22
		p["torsion"] = float(p["torsion"]) * 0.6
	return p


# SACARLA de la cadera y quedarse EN SU GUARDIA: el ultimo fotograma es la guardia (con o sin escudo), sin
# salto. El escudo, si lo hay, se va colocando delante mientras tanto.
static func _desenvainar(t: float, esc: bool) -> Dictionary:
	var fin: Dictionary = guardia(0.0, esc, 0)
	var giro: float = clampf((t - 0.35) / 0.65, 0.0, 1.0)
	var colgando := Vector3(0.0, 0.35, -1.0).normalized()
	var p: Dictionary = {
		"brazo_der": _k(t, [[0.0, 0.15], [0.35, -0.10], [0.6, 0.6], [1.0, float(fin["brazo_der"])]]),
		"brazo_izq": _k(t, [[0.0, 0.10], [0.35, 0.0], [0.6, 0.6 if esc else -0.6], [1.0, float(fin["brazo_izq"])]]),
		"agacha": _k(t, [[0.0, 0.08], [0.35, 0.14], [1.0, float(fin["agacha"])]]),
		"paso": _k(t, [[0.0, 0.0], [1.0, float(fin["paso"])]]),
		"torsion": _k(t, [[0.0, 0.0], [1.0, float(fin["torsion"])]]),
		"inclina": _k(t, [[0.0, 0.04], [0.35, 0.12], [1.0, float(fin["inclina"])]]),
		"bote": 0.0,
		"eje_der": colgando.lerp(fin["eje_der"], giro),
		"sacando": -1.0 if t < 0.35 else giro}
	if esc:
		p["junta_izq"] = _k(t, [[0.0, 0.0], [1.0, ESCUDO_JUNTA]])
	return p


# EL DEFENDER sin escudo: la hoja atravesada delante del pecho y la otra mano apoyada (la de la espada corta).
static func _defensa(t: float) -> Dictionary:
	var s: float = sin(TAU * t)
	return {"bote": 0.12 * s, "agacha": 0.34, "paso": 0.5, "inclina": 0.0, "torsion": 0.25,
		"brazo_der": 1.4 + 0.02 * s, "brazo_izq": 1.3, "junta_izq": 0.6, "eje_der": Vector3(1.0, 0.25, 0.3)}


# LOS GOLPES: salen de la guardia y vuelven a ella (primer y ultimo fotograma = la guardia); el brazo del
# escudo se queda donde estaba.
#   tajo      el basico: se arma alto y fuera y baja en diagonal hacia dentro (golpe a 0,42)
#   rota      el tajo de la Guardia rota, mas cargado (golpe a 0,42); le sigue el golpe de escudo
#   pesado    el Tajo pesado: la hoja sube por encima de la cabeza y cae EN VERTICAL, cargando el peso y
#             agachandose (golpe a 0,62)
#   desarme   el Tajo desarmante: la hoja TUMBADA a la altura del brazo, de fuera a dentro (golpe a 0,45)
#   estocada  la Estocada marcial: la punta al frente por encima del escudo, a fondo (golpe a 0,45)
static func _golpe(t: float, base: String, esc: bool) -> Dictionary:
	var g: Dictionary = guardia(0.0, esc, 0)
	var p: Dictionary = g.duplicate()
	var a0: float = float(g["brazo_der"])
	var e0: Vector3 = g["eje_der"]
	var t0: float = float(g["torsion"])
	var i0: float = float(g["inclina"])
	var ag0: float = float(g["agacha"])
	var a_keys: Array
	var x_keys: Array = [[0.0, 0.0], [1.0, 0.0]]
	var tor: Array
	var av: Array
	var incl: Array
	var tumbada: bool = false
	var al_frente: bool = false
	match base:
		"tajo_larga", "rota_larga":
			var alto: float = 3.75 if base == "rota_larga" else 3.6
			a_keys = [[0.0, a0], [0.28, alto], [0.42, 1.75], [0.55, 0.45], [0.78, 0.6], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.28, 0.55], [0.55, -0.7], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.28, 0.5], [0.45, -0.4], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.28, -1.0], [0.45, 3.4], [0.7, 2.2], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.28, -0.16], [0.45, 0.24], [1.0, 0.0]]
		"pesado_larga":
			# Sube despacio por encima de la cabeza (se ve venir), aguanta arriba y cae de golpe.
			a_keys = [[0.0, a0], [0.35, 3.55], [0.5, 3.35], [0.62, 0.95], [0.75, 0.55], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.35, 0.1], [0.62, 0.0], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.35, 0.15], [0.62, -0.15], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.35, -1.5], [0.62, 4.0], [0.8, 3.0], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.35, -0.22], [0.62, 0.36], [0.8, 0.3], [1.0, 0.0]]
			p["agacha"] = _k(t, [[0.0, ag0], [0.35, ag0 - 0.06], [0.62, ag0 + 0.22], [0.8, ag0 + 0.18], [1.0, ag0]])
		"desarme_larga":
			tumbada = true
			a_keys = [[0.0, a0], [0.3, 1.6], [0.45, 1.7], [0.62, 1.65], [1.0, a0]]
			x_keys = [[0.0, 0.0], [0.3, 1.0], [0.45, 0.0], [0.62, -1.0], [1.0, 0.0]]
			tor = [[0.0, 0.0], [0.3, 0.9], [0.45, 0.0], [0.62, -0.8], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.3, -0.6], [0.45, 2.8], [0.62, 2.3], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.3, -0.06], [0.45, 0.12], [1.0, 0.0]]
		_:   # estocada_larga
			al_frente = true
			a_keys = [[0.0, a0], [0.3, 1.25], [0.45, 1.6], [0.7, 1.6], [1.0, a0]]
			tor = [[0.0, 0.0], [0.3, 0.25], [0.45, -0.1], [1.0, 0.0]]
			av = [[0.0, 0.0], [0.3, -1.2], [0.45, 5.5], [0.7, 5.0], [1.0, 0.0]]
			incl = [[0.0, 0.0], [0.3, -0.05], [0.45, 0.2], [0.7, 0.18], [1.0, 0.0]]
			p["paso"] = _k(t, [[0.0, float(g["paso"])], [0.45, 0.8], [0.7, 0.78], [1.0, float(g["paso"])]])
	var a: float = _k(t, a_keys)
	var x: float = _k(t, x_keys)
	p["brazo_der"] = a
	p["torsion"] = t0 + _k(t, tor)
	p["avance"] = _k(t, av)
	p["inclina"] = i0 + _k(t, incl)
	p["bote"] = 0.0
	var ek: Vector3
	if tumbada:
		ek = Vector3(-x, 0.55 + 0.5 * (1.0 - absf(x)), 0.2)
	elif al_frente:
		ek = Vector3(-0.05, 1.0, 0.08)
	else:
		ek = Vector3(-x, sin(a), -cos(a))
	var k: float = _k(t, [[0.0, 0.0], [0.15, 1.0], [0.85, 1.0], [1.0, 0.0]])
	p["eje_der"] = e0.lerp(ek.normalized(), k)
	return p


# EL VOTO DE GUARDIA: te plantas. Pies muy abiertos, bajas el cuerpo de un golpe (el pisoton), la espada
# recogida en vertical delante del pecho y el escudo adelantado. Se queda asi (luego, la postura de defensa).
static func _voto(t: float, esc: bool) -> Dictionary:
	var g: Dictionary = guardia(0.0, esc, 0)
	var k: float = _k(t, [[0.0, 0.0], [0.3, 1.0], [1.0, 1.0]])
	var p: Dictionary = {
		"brazo_der": lerpf(float(g["brazo_der"]), 1.15, k),
		"eje_der": (g["eje_der"] as Vector3).lerp(Vector3(0.1, 0.3, 1.0).normalized(), k),
		"agacha": _k(t, [[0.0, float(g["agacha"])], [0.25, 0.58], [0.4, 0.5], [1.0, 0.5]]),
		"paso": lerpf(float(g["paso"]), 0.7, k),
		"torsion": lerpf(float(g["torsion"]), 0.1, k),
		"inclina": lerpf(float(g["inclina"]), 0.02, k),
		"bote": 0.0}
	if esc:
		p["brazo_izq"] = lerpf(float(g["brazo_izq"]), 1.45, k)
		p["junta_izq"] = lerpf(ESCUDO_JUNTA, 0.15, k)
	else:
		p["brazo_izq"] = lerpf(float(g["brazo_izq"]), 1.3, k)
		p["junta_izq"] = 0.7 * k   # la otra mano al pomo
	return p


# LA VOZ DE MANDO: la espada al cielo y el pecho fuera, dando la orden. El escudo baja.
static func _voz(t: float, esc: bool) -> Dictionary:
	var g: Dictionary = guardia(0.0, esc, 0)
	var k: float = _k(t, [[0.0, 0.0], [0.35, 1.0], [1.0, 1.0]])
	var tiembla: float = 0.0 if t < 0.35 else 0.3 * sin(t * 40.0)
	var p: Dictionary = {
		"brazo_der": lerpf(float(g["brazo_der"]), 3.0, k),
		"eje_der": (g["eje_der"] as Vector3).lerp(Vector3(-0.1, 0.35, 1.0).normalized(), k),
		"agacha": lerpf(float(g["agacha"]), 0.12, k),
		"paso": lerpf(float(g["paso"]), 0.35, k),
		"torsion": lerpf(float(g["torsion"]), 0.15, k),
		"inclina": lerpf(float(g["inclina"]), -0.2, k),
		"bote": tiembla}
	p["brazo_izq"] = lerpf(float(g["brazo_izq"]), 0.55 if esc else 0.9, k)
	if esc:
		p["junta_izq"] = lerpf(ESCUDO_JUNTA, 0.0, k)
	return p


# ------------------------------------------------------------
#  LAS DE ESCUDO (con cualquier arma de una mano)
# ------------------------------------------------------------
#   golpe      el escudazo: se recoge y lo estampa al frente con el hombro (golpe a 0,45)
#   embestida  la carga: hombro bajado detras del escudo, cuerpo echado adelante y las piernas corriendo;
#              el choque al final (golpe a 0,6)
#   provoca    la Provocacion: dos golpes del arma contra el escudo y el pecho fuera (golpe a 0,3)
#   amparo     Cobertura y Muro: el escudo adelantado y plantado, bien abajo (golpe a 0,35)
#   rodela     la Postura de rodela: el escudo ALTO y el arma recogida atras, lista para devolver (0,35)
#   carne      la Guardia de carne: brazos abiertos y pecho fuera, "pegame" (0,35)
#   escolta    un paso al frente señalando con el arma (0,35)
static func _escudo(anim: String, t: float) -> Dictionary:
	var s: float = sin(TAU * t)
	var p: Dictionary = {"brazo_der": 0.6, "eje_der": EJE_MANO, "brazo_izq": ESCUDO_BRAZO, "junta_izq": ESCUDO_JUNTA,
		"torsion": 0.3, "agacha": 0.3, "paso": 0.5, "inclina": 0.06, "bote": 0.0}
	match anim:
		"golpe_escudo":
			p["brazo_izq"] = _k(t, [[0.0, ESCUDO_BRAZO], [0.3, 0.75], [0.45, 1.75], [0.65, 1.65], [1.0, ESCUDO_BRAZO]])
			p["junta_izq"] = _k(t, [[0.0, ESCUDO_JUNTA], [0.45, 0.1], [1.0, ESCUDO_JUNTA]])
			p["torsion"] = _k(t, [[0.0, 0.3], [0.3, 0.7], [0.45, -0.25], [0.7, -0.15], [1.0, 0.3]])
			p["avance"] = _k(t, [[0.0, 0.0], [0.3, -1.2], [0.45, 4.5], [0.7, 3.5], [1.0, 0.0]])
			p["inclina"] = _k(t, [[0.0, 0.06], [0.3, -0.04], [0.45, 0.24], [1.0, 0.06]])
			p["brazo_der"] = _k(t, [[0.0, 0.6], [0.3, 0.9], [0.45, 0.35], [1.0, 0.6]])
		"embestida_escudo":
			p["brazo_izq"] = 1.3
			p["junta_izq"] = 0.12
			p["torsion"] = -0.15
			p["inclina"] = _k(t, [[0.0, 0.1], [0.2, 0.34], [0.6, 0.38], [0.75, 0.2], [1.0, 0.1]])
			p["agacha"] = _k(t, [[0.0, 0.3], [0.2, 0.36], [1.0, 0.3]])
			p["paso"] = 0.6 * sin(TAU * t * 1.5) if t < 0.6 else _k(t, [[0.6, 0.7], [1.0, 0.5]])
			p["bote"] = 0.8 * absf(sin(TAU * t * 1.5)) if t < 0.6 else 0.0
			p["avance"] = _k(t, [[0.0, 0.0], [0.6, 3.5], [0.7, 5.0], [1.0, 0.0]])
			p["brazo_der"] = 0.35
		"provoca_escudo":
			# Dos golpes del arma contra la cara del escudo (el arma cruza hacia tu izquierda) y luego el pecho fuera.
			p["brazo_der"] = _k(t, [[0.0, 0.6], [0.18, 1.9], [0.3, 1.3], [0.42, 1.9], [0.54, 1.3], [0.7, 1.9],
				[1.0, 1.9]])
			p["eje_der"] = EJE_MANO.lerp(Vector3(0.85, 0.35, 0.4).normalized(), _k(t, [[0.0, 0.0], [0.15, 1.0],
				[0.6, 1.0], [0.8, 0.0], [1.0, 0.0]]))
			p["brazo_izq"] = _k(t, [[0.0, ESCUDO_BRAZO], [0.15, 1.35], [0.6, 1.35], [0.8, 0.8], [1.0, 0.8]])
			p["inclina"] = _k(t, [[0.0, 0.06], [0.6, 0.08], [0.8, -0.22], [1.0, -0.2]])
			p["agacha"] = _k(t, [[0.0, 0.3], [0.6, 0.3], [0.8, 0.12], [1.0, 0.12]])
			p["torsion"] = _k(t, [[0.0, 0.3], [0.6, 0.35], [0.8, 0.0], [1.0, 0.0]])
			p["bote"] = 0.0 if t < 0.7 else 0.3 * sin(t * 40.0)
		"amparo_escudo":
			var k: float = _k(t, [[0.0, 0.0], [0.35, 1.0], [1.0, 1.0]])
			p["brazo_izq"] = lerpf(ESCUDO_BRAZO, 1.5, k)
			p["junta_izq"] = lerpf(ESCUDO_JUNTA, 0.08, k)
			p["agacha"] = _k(t, [[0.0, 0.3], [0.3, 0.5], [0.45, 0.44], [1.0, 0.44]])
			p["paso"] = lerpf(0.5, 0.66, k)
			p["inclina"] = lerpf(0.06, 0.14, k)
			p["torsion"] = lerpf(0.3, 0.05, k)
			p["brazo_der"] = lerpf(0.6, 0.4, k)
		"rodela_escudo":
			var k2: float = _k(t, [[0.0, 0.0], [0.35, 1.0], [1.0, 1.0]])
			p["brazo_izq"] = lerpf(ESCUDO_BRAZO, 1.95, k2)
			p["junta_izq"] = lerpf(ESCUDO_JUNTA, 0.05, k2)
			p["brazo_der"] = lerpf(0.6, 2.1, k2)
			p["eje_der"] = EJE_MANO.lerp(Vector3(-0.3, -0.55, 0.75).normalized(), k2)
			p["agacha"] = lerpf(0.3, 0.4, k2)
			p["paso"] = lerpf(0.5, 0.6, k2)
			p["torsion"] = lerpf(0.3, 0.5, k2)
			p["bote"] = 0.1 * s * k2
		"carne_escudo":
			var k3: float = _k(t, [[0.0, 0.0], [0.35, 1.0], [1.0, 1.0]])
			p["brazo_der"] = lerpf(0.6, 2.2, k3)
			p["brazo_izq"] = lerpf(ESCUDO_BRAZO, 2.2, k3)
			p["junta_izq"] = lerpf(ESCUDO_JUNTA, 0.0, k3)
			p["eje_der"] = EJE_MANO.lerp(Vector3(-0.7, 0.2, 0.7).normalized(), k3)
			p["inclina"] = lerpf(0.06, -0.24, k3)
			p["agacha"] = lerpf(0.3, 0.06, k3)
			p["paso"] = lerpf(0.5, 0.42, k3)
			p["torsion"] = lerpf(0.3, 0.0, k3)
			p["bote"] = 0.0 if t < 0.35 else 0.25 * sin(t * 30.0)
		"escolta_escudo":
			p["brazo_der"] = _k(t, [[0.0, 0.6], [0.35, 1.65], [0.8, 1.6], [1.0, 1.6]])
			p["eje_der"] = EJE_MANO.lerp(Vector3(-0.05, 1.0, 0.15).normalized(), _k(t, [[0.0, 0.0], [0.35, 1.0], [1.0, 1.0]]))
			p["avance"] = _k(t, [[0.0, 0.0], [0.35, 3.0], [1.0, 2.5]])
			p["paso"] = _k(t, [[0.0, 0.5], [0.35, 0.7], [1.0, 0.65]])
			p["inclina"] = _k(t, [[0.0, 0.06], [0.35, 0.16], [1.0, 0.12]])
			p["torsion"] = _k(t, [[0.0, 0.3], [0.35, 0.05], [1.0, 0.05]])
	return p
