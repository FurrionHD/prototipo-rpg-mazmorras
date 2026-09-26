# ============================================================
#  pose_baston.gd
#  LAS POSES DEL BASTON Y LA FLORITURA DE LA VARITA (26/09/2026). Aparte de PoseJugador para no engordarlo mas;
#  las pide PoseJugador._pose antes que nada.
#  EL BASTON (su indicacion, 26/09): a DOS MANOS y CRUZADO EN DIAGONAL, "tipo baston de pelea": la derecha
#  (atras) baja junto a la cadera, la izquierda (delante) a la altura del pecho, y el palo pasa POR LAS DOS
#  MANOS con la cabeza (el orbe) arriba y al frente. Las manos van separadas: el palo lo pone 'palo' (lo que
#  asoma por detras de la mano derecha, en unidades de mundo; ver PoseJugador.agarre_arma).
#  LA VARITA va en la IZQUIERDA (la mano del escudo) y su gesto es la FLORITURA: la mano sube, la muñeca da un
#  par de vueltas y la punta sale hacia delante. Una generica para todo (decision suya): la derecha se queda en
#  la guardia de lo que lleve ('floritura' = con la guardia de siempre, 'floritura_daga' con la de la daga...).
#  Los ejes van en el sistema del cuerpo: x = hacia la izquierda del personaje, y = al frente, z = arriba.
#  Brazos: 0 = colgando, PI/2 = al frente, PI = arriba; 'abre_*' + = hacia fuera de su lado, - = cruza delante.
#  Sus IMPACTOS en CombatFX.IMPACTO_ANIM_MAPA (fotograma del golpe x marcos / fps): retocar uno = retocar el otro.
# ============================================================
extends RefCounted
class_name PoseBaston

const PALO := 5.0          # lo que asoma el palo por detras de la mano derecha en la guardia
const ANIMS := ["guardia_baston", "guardia_baston_and", "guardia_baston_cor", "desenvainar_baston",
	"defensa_baston", "golpe_baston", "bastonazo_baston", "sello_baston", "viento_baston", "foco_baston",
	"velo_baston"]
# Las guardias con las que puede ir la floritura (la de la mano derecha): '' = la de siempre.
const FLORITURAS := ["floritura", "floritura_daga", "floritura_estoque", "floritura_espada", "floritura_larga",
	"floritura_maza"]


static func pose(anim: String, t: float) -> Dictionary:
	if anim in FLORITURAS:
		return _floritura(anim, t)
	match anim:
		"guardia_baston": return guardia(t, 0)
		"guardia_baston_and": return guardia(t, 1)
		"guardia_baston_cor": return guardia(t, 2)
		"desenvainar_baston": return _desenvainar(t)
		"defensa_baston": return _defensa(t)
		"golpe_baston", "bastonazo_baston", "sello_baston", "viento_baston", "foco_baston", "velo_baston":
			return _golpe(anim, t)
	return {}


static func _k(t: float, keys: Array) -> float:
	return SpriteLienzo.tramos(t, keys)


# Lo mismo con vectores (el eje del palo): componente a componente.
static func _v(t: float, keys: Array) -> Vector3:
	var kx: Array = []
	var ky: Array = []
	var kz: Array = []
	for k in keys:
		var v: Vector3 = k[1]
		kx.append([k[0], v.x])
		ky.append([k[0], v.y])
		kz.append([k[0], v.z])
	return Vector3(_k(t, kx), _k(t, ky), _k(t, kz)).normalized()


# 'm': 0 quieta, 1 andando, 2 corriendo.
static func guardia(t: float, m: int) -> Dictionary:
	var s: float = sin(TAU * t)
	var p: Dictionary = {"brazo_der": 0.85 + 0.03 * s, "abre_der": -0.2, "brazo_izq": 2.05 + 0.03 * s,
		"abre_izq": -0.1, "torsion": -0.3, "palo": PALO, "bote": 0.25 * s, "inclina": 0.08, "agacha": 0.28,
		"paso": 0.45}
	if m == 1:
		# Las piernas se CRUZAN (la regla de la receta: nunca 'guardia + 0.12 * s').
		p["paso"] = 0.10 + 0.40 * s
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


# SACARLO DE LA ESPALDA y quedarse en guardia (el ultimo fotograma ES la guardia): la derecha sube por encima del
# hombro, lo agarra y lo trae por delante; la izquierda lo coge al final.
static func _desenvainar(t: float) -> Dictionary:
	var fin: Dictionary = guardia(0.0, 0)
	return {"brazo_der": _k(t, [[0.0, 0.15], [0.3, 3.3], [0.45, 3.4], [0.75, 1.3], [1.0, float(fin["brazo_der"])]]),
		"abre_der": _k(t, [[0.0, 0.0], [0.45, 0.0], [1.0, float(fin["abre_der"])]]),
		"brazo_izq": _k(t, [[0.0, 0.1], [0.6, 0.5], [1.0, float(fin["brazo_izq"])]]),
		"abre_izq": _k(t, [[0.0, 0.0], [0.6, 0.0], [1.0, float(fin["abre_izq"])]]),
		"torsion": _k(t, [[0.0, 0.0], [1.0, float(fin["torsion"])]]),
		"agacha": _k(t, [[0.0, 0.08], [1.0, float(fin["agacha"])]]),
		"paso": _k(t, [[0.0, 0.0], [1.0, float(fin["paso"])]]),
		"inclina": _k(t, [[0.0, 0.04], [0.45, -0.06], [1.0, float(fin["inclina"])]]),
		"palo": PALO, "bote": 0.0,
		"sacando": -1.0 if t < 0.4 else clampf((t - 0.4) / 0.6, 0.0, 1.0)}


# EL DEFENDER: el palo ATRAVESADO delante del pecho, las manos bien separadas (la parada del baston de pelea).
static func _defensa(t: float) -> Dictionary:
	var s: float = sin(TAU * t)
	return {"brazo_der": 1.9 + 0.02 * s, "abre_der": 0.45, "brazo_izq": 1.9 + 0.02 * s, "abre_izq": 0.45,
		"torsion": 0.0, "palo": 7.0, "bote": 0.12 * s, "agacha": 0.36, "paso": 0.45, "inclina": 0.02}


# LOS GOLPES Y LAS HABILIDADES. Salen de la guardia y vuelven a ella (primer y ultimo fotograma = la guardia).
#   golpe      el basico: la punta de delante sube y cae en diagonal sobre el de enfrente (golpe en 0,45)
#   bastonazo  el Bastonazo: el palo se carga a la derecha y BARRE de lado a la cintura hasta la izquierda, con
#              todo el tronco (arranca el barrido en 0,45: BastonAire.BARRE lo lleva el suelo)
#   sello      el Sello arcano: el palo al frente, la punta TRAZA el signo (una vuelta, de 0,25 a 0,65) y al final
#              lo CLAVA hacia delante (0,84), que es cuando se cierra (el suelo arranca en 0,25)
#   viento     el Viento limpio: un abanicazo de abajo a la derecha hacia arriba y al frente (sale en 0,5)
#   foco       el Foco arcano: plantas el palo de pie delante de ti, con las dos manos, y lo alzas un poco (0,45)
#   velo       el Velo umbrio: el palo por encima de la cabeza y te encoges debajo con el palo pegado (0,3)
static func _golpe(anim: String, t: float) -> Dictionary:
	var g: Dictionary = guardia(0.0, 0)
	var p: Dictionary = g.duplicate()
	var bd: float = float(g["brazo_der"])
	var ad: float = float(g["abre_der"])
	var bi: float = float(g["brazo_izq"])
	var ai: float = float(g["abre_izq"])
	var tr: float = float(g["torsion"])
	var ag: float = float(g["agacha"])
	var inc: float = float(g["inclina"])
	p["bote"] = 0.0
	match anim:
		"golpe_baston":
			p["brazo_izq"] = _k(t, [[0.0, bi], [0.3, 2.3], [0.45, 1.0], [0.6, 0.9], [1.0, bi]])
			p["abre_izq"] = _k(t, [[0.0, ai], [0.3, 0.25], [0.45, -0.35], [0.6, -0.3], [1.0, ai]])
			p["brazo_der"] = _k(t, [[0.0, bd], [0.3, 0.95], [0.45, 0.35], [1.0, bd]])
			p["torsion"] = _k(t, [[0.0, tr], [0.3, -0.5], [0.45, 0.15], [1.0, tr]])
			p["avance"] = _k(t, [[0.0, 0.0], [0.3, -0.6], [0.45, 2.5], [0.7, 1.6], [1.0, 0.0]])
			p["inclina"] = _k(t, [[0.0, inc], [0.3, inc - 0.1], [0.45, inc + 0.2], [1.0, inc]])
		"bastonazo_baston":
			# El palo HORIZONTAL delante, a la cintura, y lo que barre es el TRONCO entero (la torsion gira tambien el
			# arma): cargado a tu derecha, barre por delante y acaba a tu izquierda. Las manos juntas en el medio.
			p["eje_k"] = _k(t, [[0.0, 0.0], [0.22, 1.0], [0.8, 1.0], [1.0, 0.0]])
			p["eje_2m"] = _v(t, [[0.0, Vector3(-0.6, 0.6, 0.2)], [0.3, Vector3(-0.85, 0.5, 0.05)], [0.45, Vector3(0.0, 1.0, 0.0)],
				[0.62, Vector3(0.85, 0.5, 0.0)], [1.0, Vector3(0.6, 0.6, 0.2)]])
			p["palo"] = _k(t, [[0.0, PALO], [0.25, 12.0], [0.8, 12.0], [1.0, PALO]])
			p["brazo_der"] = _k(t, [[0.0, bd], [0.3, 1.1], [0.45, 1.25], [0.62, 1.15], [1.0, bd]])
			p["abre_der"] = _k(t, [[0.0, ad], [0.3, -0.25], [1.0, ad]])
			p["brazo_izq"] = _k(t, [[0.0, bi], [0.3, 1.1], [0.45, 1.25], [0.62, 1.15], [1.0, bi]])
			p["abre_izq"] = _k(t, [[0.0, ai], [0.3, -0.25], [1.0, ai]])
			p["torsion"] = _k(t, [[0.0, tr], [0.3, 0.9], [0.45, 0.0], [0.62, -0.9], [0.8, -0.7], [1.0, tr]])
			p["avance"] = _k(t, [[0.0, 0.0], [0.3, -0.4], [0.45, 1.8], [0.7, 1.4], [1.0, 0.0]])
			p["agacha"] = _k(t, [[0.0, ag], [0.3, ag + 0.08], [0.45, ag + 0.14], [1.0, ag]])
			p["inclina"] = _k(t, [[0.0, inc], [0.45, inc + 0.14], [1.0, inc]])
		"sello_baston":
			# El palo al frente y en alto, y la punta dando UNA vuelta (el signo); luego lo clava hacia delante.
			var fi: float = TAU * clampf((t - 0.25) / 0.4, 0.0, 1.0)
			var traza: float = _k(t, [[0.0, 0.0], [0.22, 1.0], [0.66, 1.0], [0.74, 0.0], [1.0, 0.0]])
			var gira := Vector3(0.45 * cos(fi), 0.8, 0.45 + 0.45 * sin(fi))
			var recto := Vector3(0.0, 1.0, 0.12)
			var kc: float = _k(t, [[0.0, 0.0], [0.7, 0.0], [0.82, 1.0], [1.0, 1.0]])
			p["eje_k"] = _k(t, [[0.0, 0.0], [0.2, 1.0], [0.88, 1.0], [1.0, 0.0]])
			p["eje_2m"] = Vector3(0.0, 0.8, 0.45).lerp(gira, traza).lerp(recto, kc).normalized()
			p["palo"] = _k(t, [[0.0, PALO], [0.2, 10.0], [0.88, 10.0], [1.0, PALO]])
			p["brazo_izq"] = _k(t, [[0.0, bi], [0.2, 1.7], [0.7, 1.7], [0.84, 1.5], [1.0, bi]]) + 0.25 * sin(fi) * traza
			p["abre_izq"] = _k(t, [[0.0, ai], [0.2, -0.25], [1.0, ai]]) + 0.25 * cos(fi) * traza
			p["brazo_der"] = _k(t, [[0.0, bd], [0.2, 1.4], [0.7, 1.4], [0.84, 1.5], [1.0, bd]]) + 0.25 * sin(fi) * traza
			p["abre_der"] = _k(t, [[0.0, ad], [0.2, -0.25], [1.0, ad]]) - 0.25 * cos(fi) * traza
			p["torsion"] = _k(t, [[0.0, tr], [0.2, -0.1], [0.84, 0.05], [1.0, tr]])
			p["avance"] = _k(t, [[0.0, 0.0], [0.7, 0.0], [0.84, 2.6], [0.92, 2.2], [1.0, 0.0]])
			p["inclina"] = _k(t, [[0.0, inc], [0.2, inc - 0.04], [0.84, inc + 0.18], [1.0, inc]])
		"viento_baston":
			# Un abanicazo: el palo sale de abajo a tu derecha y sube por delante hasta arriba a la izquierda.
			p["eje_k"] = _k(t, [[0.0, 0.0], [0.2, 1.0], [0.8, 1.0], [1.0, 0.0]])
			p["eje_2m"] = _v(t, [[0.0, Vector3(-0.5, 0.5, -0.2)], [0.3, Vector3(-0.8, 0.45, -0.5)], [0.5, Vector3(0.2, 0.7, 0.7)],
				[0.65, Vector3(0.45, 0.5, 0.75)], [1.0, Vector3(0.3, 0.5, 0.6)]])
			p["palo"] = _k(t, [[0.0, PALO], [0.25, 11.0], [0.8, 11.0], [1.0, PALO]])
			p["brazo_der"] = _k(t, [[0.0, bd], [0.3, 0.7], [0.5, 1.6], [0.65, 1.5], [1.0, bd]])
			p["abre_der"] = _k(t, [[0.0, ad], [0.3, 0.1], [0.5, -0.2], [1.0, ad]])
			p["brazo_izq"] = _k(t, [[0.0, bi], [0.3, 0.8], [0.5, 1.8], [0.65, 1.7], [1.0, bi]])
			p["abre_izq"] = _k(t, [[0.0, ai], [0.3, -0.5], [0.5, 0.0], [1.0, ai]])
			p["torsion"] = _k(t, [[0.0, tr], [0.3, 0.6], [0.5, -0.4], [1.0, tr]])
			p["agacha"] = _k(t, [[0.0, ag], [0.3, ag + 0.14], [0.5, ag - 0.04], [1.0, ag]])
			p["inclina"] = _k(t, [[0.0, inc], [0.3, inc + 0.12], [0.5, inc - 0.1], [1.0, inc]])
			p["avance"] = _k(t, [[0.0, 0.0], [0.5, 1.2], [1.0, 0.0]])
		"foco_baston":
			# De PIE delante de ti, el orbe por encima de la cabeza, las dos manos en el medio. Lo alzas un poco.
			var alza: float = _k(t, [[0.0, 0.0], [0.35, 0.0], [0.45, 0.18], [0.85, 0.14], [1.0, 0.0]])
			p["eje_k"] = _k(t, [[0.0, 0.0], [0.28, 1.0], [0.85, 1.0], [1.0, 0.0]])
			p["eje_2m"] = Vector3(0.0, 0.12, 1.0)
			p["palo"] = _k(t, [[0.0, PALO], [0.28, 17.0], [0.85, 17.0], [1.0, PALO]])
			p["brazo_der"] = _k(t, [[0.0, bd], [0.28, 1.15], [0.85, 1.15], [1.0, bd]]) + alza
			p["abre_der"] = _k(t, [[0.0, ad], [0.28, -0.35], [0.85, -0.35], [1.0, ad]])
			p["brazo_izq"] = _k(t, [[0.0, bi], [0.28, 1.35], [0.85, 1.35], [1.0, bi]]) + alza
			p["abre_izq"] = _k(t, [[0.0, ai], [0.28, -0.35], [0.85, -0.35], [1.0, ai]])
			p["torsion"] = _k(t, [[0.0, tr], [0.28, 0.0], [0.85, 0.0], [1.0, tr]])
			p["inclina"] = _k(t, [[0.0, inc], [0.28, -0.04], [0.45, -0.1], [0.85, -0.08], [1.0, inc]])
			p["agacha"] = _k(t, [[0.0, ag], [0.28, ag - 0.08], [0.85, ag - 0.08], [1.0, ag]])
		"velo_baston":
			# El palo ATRAVESADO por encima de la cabeza, y al caer la sombra te encoges con el palo de pie, pegado.
			p["eje_k"] = _k(t, [[0.0, 0.0], [0.18, 1.0], [0.85, 1.0], [1.0, 0.0]])
			p["eje_2m"] = _v(t, [[0.0, Vector3(0.6, 0.4, 0.5)], [0.22, Vector3(1.0, 0.1, 0.05)], [0.3, Vector3(1.0, 0.1, 0.05)],
				[0.42, Vector3(0.1, 0.25, 1.0)], [1.0, Vector3(0.1, 0.25, 1.0)]])
			p["palo"] = _k(t, [[0.0, PALO], [0.22, 17.0], [0.42, 17.0], [0.85, 17.0], [1.0, PALO]])
			p["brazo_der"] = _k(t, [[0.0, bd], [0.22, 2.9], [0.3, 2.9], [0.42, 1.2], [0.85, 1.2], [1.0, bd]])
			p["abre_der"] = _k(t, [[0.0, ad], [0.22, 0.2], [0.42, -0.3], [0.85, -0.3], [1.0, ad]])
			p["brazo_izq"] = _k(t, [[0.0, bi], [0.22, 2.9], [0.3, 2.9], [0.42, 1.35], [0.85, 1.35], [1.0, bi]])
			p["abre_izq"] = _k(t, [[0.0, ai], [0.22, 0.2], [0.42, -0.3], [0.85, -0.3], [1.0, ai]])
			p["torsion"] = _k(t, [[0.0, tr], [0.22, 0.0], [0.85, 0.0], [1.0, tr]])
			p["agacha"] = _k(t, [[0.0, ag], [0.22, ag - 0.1], [0.42, 0.62], [0.85, 0.6], [1.0, ag]])
			p["inclina"] = _k(t, [[0.0, inc], [0.22, -0.12], [0.42, 0.3], [0.85, 0.28], [1.0, inc]])
	return p


# LA FLORITURA DE LA VARITA: la derecha en la guardia de lo que lleve y la izquierda sube, da dos vueltas con la
# muñeca y suelta la punta hacia delante (en 0,72). Primer y ultimo fotograma = la guardia.
static func _floritura(anim: String, t: float) -> Dictionary:
	var guardia_de: String = anim.replace("floritura", "guardia")
	var g: Dictionary = PoseJugador._pose(guardia_de, 0.0)
	var p: Dictionary = g.duplicate()
	var bi: float = float(g.get("brazo_izq", -0.3))
	var ai: float = float(g.get("abre_izq", 0.0))
	var fi: float = 2.0 * TAU * clampf((t - 0.2) / 0.45, 0.0, 1.0)
	var vueltas: float = _k(t, [[0.0, 0.0], [0.2, 1.0], [0.62, 1.0], [0.7, 0.0], [1.0, 0.0]])
	p["brazo_izq"] = _k(t, [[0.0, bi], [0.2, 1.4], [0.62, 1.45], [0.72, 1.65], [0.86, 1.55], [1.0, bi]]) \
		+ 0.12 * sin(fi) * vueltas
	p["abre_izq"] = _k(t, [[0.0, ai], [0.2, 0.1], [0.62, 0.1], [0.72, -0.05], [1.0, ai]]) + 0.14 * cos(fi) * vueltas
	p.erase("junta_izq")
	# La varita: hacia arriba y al frente, girando con la muñeca; al soltar, recta al frente.
	var girando := Vector3(0.45 * cos(fi), 0.6, 0.55 + 0.35 * sin(fi))
	var suelta := Vector3(0.0, 1.0, 0.1)
	var k_suelta: float = _k(t, [[0.0, 0.0], [0.64, 0.0], [0.72, 1.0], [0.88, 1.0], [1.0, 0.0]])
	var k_gira: float = _k(t, [[0.0, 0.0], [0.15, 1.0], [0.9, 1.0], [1.0, 0.0]])
	var reposo: Vector3 = g.get("eje_izq", Vector3(0.0, 0.35, -1.0))
	p["eje_izq"] = reposo.lerp(girando.lerp(suelta, k_suelta).normalized(), k_gira).normalized()
	p["torsion"] = float(g.get("torsion", 0.0)) + _k(t, [[0.0, 0.0], [0.2, -0.12], [0.72, -0.2], [1.0, 0.0]])
	p["bote"] = 0.0
	return p
