# ============================================================
#  pose_distancia.gd  (class_name PoseDistancia)
#  LAS POSES DEL ARCO Y LA BALLESTA (03/10/2026). Aparte de PoseJugador, como PoseBaston; las pide
#  PoseJugador._pose antes que nada. El dibujo del arma es ArcoSprites, que lee de aqui hacia donde apunta.
#
#  LAS MANOS VAN A UN PUNTO ('mano_*_en', PoseJugador._codo_hacia): tensar es llevar la mano a la cara y el
#  brazo rigido no llega. Los puntos se escriben EN EL MARCO DEL PECHO GIRADO (y = hacia el blanco, x = su
#  izquierda, z = arriba) y _pecho los pasa al del cuerpo deshaciendo la torsion que les toca por su altura:
#  asi la mano cae donde se escribio aunque el tronco este girado tres cuartos.
#  OJO CON LOS BRAZOS CORTOS: del hombro a la mano hay 11,6 y los hombros estan a 9,8 del centro. Las dos manos
#  solo se juntan delante del pecho, y un punto mas lejos se queda en la recta, donde llegue.
#  Sus IMPACTOS en CombatFX.IMPACTO_ANIM_MAPA (fotograma de la suelta x marcos / fps): retocar uno = retocar el otro.
# ============================================================
extends RefCounted
class_name PoseDistancia

const ANIMS := ["guardia_arco", "guardia_arco_and", "guardia_arco_cor", "desenvainar_arco",
	"guardia_ballesta", "guardia_ballesta_and", "guardia_ballesta_cor", "desenvainar_ballesta",
	"disparo_arco", "disparo_ballesta"]

# EL ARCO: tres cuartos de lado, el hombro IZQUIERDO hacia el blanco. Con la torsion positiva es el izquierdo el
# que se adelanta (ver PoseJugador.proyectar).
const TOR_ARCO := 0.6
# LA BALLESTA: menos de lado, la culata junto al costado derecho.
const TOR_BALL := 0.45
# AL TENSAR, de lado del todo: los hombros en la linea del tiro (asi cabe la flecha entre la mano y la cara).
const TOR_TIRO := 1.15


static func pose(anim: String, t: float) -> Dictionary:
	match anim:
		"guardia_arco": return guardia_arco(t, 0)
		"guardia_arco_and": return guardia_arco(t, 1)
		"guardia_arco_cor": return guardia_arco(t, 2)
		"desenvainar_arco": return _desenvainar_arco(t)
		"guardia_ballesta": return guardia_ballesta(t, 0)
		"guardia_ballesta_and": return guardia_ballesta(t, 1)
		"guardia_ballesta_cor": return guardia_ballesta(t, 2)
		"desenvainar_ballesta": return _desenvainar_ballesta(t)
		"disparo_arco": return _disparo_arco(t)
		"disparo_ballesta": return _disparo_ballesta(t)
	return {}


static func _k(t: float, keys: Array) -> float:
	return SpriteLienzo.tramos(t, keys)


# Lo mismo con puntos (en el marco del pecho), componente a componente.
static func _p(t: float, keys: Array) -> Vector3:
	var kx: Array = []
	var ky: Array = []
	var kz: Array = []
	for k in keys:
		var v: Vector3 = k[1]
		kx.append([k[0], v.x])
		ky.append([k[0], v.y])
		kz.append([k[0], v.z])
	return Vector3(_k(t, kx), _k(t, ky), _k(t, kz))


# Un punto del marco del pecho (girado 'tor') al del cuerpo, deshaciendo la torsion que le toca por su altura
# (la misma cuenta que PoseJugador.ang_en, sin agacharse: los arqueros van casi de pie).
static func _pecho(tor: float, d: Vector3) -> Vector3:
	var fr: float = clampf((d.z - PoseJugador.CADERA.z) / PoseJugador.TORSION_TRAMO, 0.0, 1.0)
	var v: Vector2 = Vector2(d.x, d.y).rotated(-tor * fr)
	return Vector3(v.x, v.y, d.z)


# Una DIRECCION del marco del pecho al del cuerpo, a la altura 'z' (la del agarre: el arma gira entera con
# la torsion de la mano que la lleva, ver ArmaSprites.pintar).
static func _dir(tor: float, d: Vector3, z: float) -> Vector3:
	var fr: float = clampf((z - PoseJugador.CADERA.z) / PoseJugador.TORSION_TRAMO, 0.0, 1.0)
	var v: Vector2 = Vector2(d.x, d.y).rotated(-tor * fr)
	return Vector3(v.x, v.y, d.z).normalized()


# El eje de las palas: casi de pie, un poco caido hacia fuera, y perpendicular a donde apunta.
static func _eje_arco(f: Vector3, cae: float) -> Vector3:
	var e: Vector3 = Vector3(cae, 0.0, 1.0).normalized()
	return (e - f * e.dot(f)).normalized()


# ============================================================
#  EL ARCO
# ============================================================
# LA GUARDIA: tres cuartos de lado, las piernas abiertas, el arco BAJO en la izquierda, delante y algo caido
# hacia fuera, con la panza hacia el blanco. La derecha suelta junto a la cadera, lista para ir al carcaj.
# 'm': 0 quieta, 1 andando, 2 corriendo.
static func guardia_arco(t: float, m: int) -> Dictionary:
	var s: float = sin(TAU * t)
	var mano_i := Vector3(10.5, 11.0, 24.8 + 0.25 * s)
	var f: Vector3 = Vector3(0.0, 1.0, -0.45).normalized()
	var p: Dictionary = {"torsion": TOR_ARCO, "agacha": 0.16, "inclina": 0.04, "paso": 0.42, "bote": 0.2 * s,
		"brazo_der": 0.22 + 0.03 * s, "abre_der": 0.12}
	if m == 1:
		p["paso"] = 0.10 + 0.40 * s
		p["bote"] = 0.4 * absf(s)
		p["brazo_der"] = 0.22 - 0.25 * s
		mano_i.z += 0.5 * absf(s)
	elif m == 2:
		p["paso"] = 0.58 * s
		p["bote"] = 0.95 * absf(s)
		p["agacha"] = 0.08
		p["inclina"] = 0.2
		p["torsion"] = TOR_ARCO * 0.6
		p["brazo_der"] = 0.3 - 0.6 * s
		mano_i = Vector3(10.0, 8.5, 25.5 + 0.8 * absf(s))
	_arco_en(p, mano_i, f, 0.35)
	return p


# Coloca la mano del arco y lo orienta (todo en el marco del pecho).
static func _arco_en(p: Dictionary, mano_i: Vector3, f: Vector3, cae: float) -> void:
	var tor: float = float(p.get("torsion", 0.0))
	p["mano_izq_en"] = _pecho(tor, mano_i)
	p["codo_izq_hacia"] = Vector3(1.0, -0.3, -0.5)
	var fb: Vector3 = _dir(tor, f, mano_i.z)
	p["arco_f"] = fb
	p["arco_e"] = _eje_arco(fb, cae)


# SACAR EL ARCO: la izquierda sube por encima del hombro izquierdo (donde asoma la pala de arriba), lo agarra y lo
# trae por delante hasta la guardia (el ultimo fotograma ES la guardia). La capa de la espalda lo suelta a mitad
# ('sacando' >= 0,5) y desde ahi lo lleva la mano.
static func _desenvainar_arco(t: float) -> Dictionary:
	var fin: Dictionary = guardia_arco(0.0, 0)
	var tor: float = _k(t, [[0.0, 0.0], [0.5, 0.15], [1.0, TOR_ARCO]])
	var p: Dictionary = {"torsion": tor, "agacha": _k(t, [[0.0, 0.06], [1.0, float(fin["agacha"])]]),
		"inclina": _k(t, [[0.0, 0.0], [0.4, -0.06], [1.0, float(fin["inclina"])]]),
		"paso": _k(t, [[0.0, 0.0], [1.0, float(fin["paso"])]]), "bote": 0.0,
		"brazo_der": _k(t, [[0.0, 0.1], [1.0, float(fin["brazo_der"])]]), "abre_der": float(fin["abre_der"]),
		"sacando": -1.0 if t < 0.3 else clampf((t - 0.3) / 0.7, 0.0, 1.0)}
	# La mano: del costado al hombro (agarra), y de ahi a la guardia.
	var a := Vector3(9.0, 2.0, 22.0)
	var b := Vector3(7.5, -2.0, 38.0)
	var c := Vector3(10.5, 11.0, 24.8)
	var mano_i: Vector3
	if t < 0.45:
		mano_i = a.lerp(b, smoothstep(0.0, 0.45, t))
	else:
		mano_i = b.lerp(c, smoothstep(0.45, 1.0, t))
	# El arco, mientras viaja, gira de la espalda (las palas cruzadas) a la guardia.
	var k: float = smoothstep(0.45, 1.0, t)
	var f: Vector3 = Vector3(0.0, -1.0, 0.2).lerp(Vector3(0.0, 1.0, -0.45), k).normalized()
	if f.length() < 0.1:
		f = Vector3(1.0, 0.0, 0.0)
	_arco_en(p, mano_i, f, lerpf(-0.9, 0.35, k))
	return p


# ============================================================
#  LA BALLESTA
# ============================================================
# LA GUARDIA: un poco de lado, la ballesta con las dos manos delante del pecho, apuntando adelante y abajo: la
# derecha en el gatillo, junto al costado, y la izquierda debajo de la punta.
static func guardia_ballesta(t: float, m: int) -> Dictionary:
	var s: float = sin(TAU * t)
	var p: Dictionary = {"torsion": TOR_BALL, "agacha": 0.2, "inclina": 0.05, "paso": 0.4, "bote": 0.2 * s}
	var mano_d := Vector3(-2.5, 3.0, 27.0 + 0.2 * s)
	var f: Vector3 = Vector3(0.12, 1.0, -0.2).normalized()
	if m == 1:
		p["paso"] = 0.10 + 0.40 * s
		p["bote"] = 0.4 * absf(s)
		mano_d.z += 0.4 * absf(s)
	elif m == 2:
		p["paso"] = 0.58 * s
		p["bote"] = 0.95 * absf(s)
		p["agacha"] = 0.08
		p["inclina"] = 0.2
		p["torsion"] = TOR_BALL * 0.5
		f = Vector3(0.3, 1.0, -0.7).normalized()
	_ballesta_en(p, mano_d, f)
	return p


# Coloca la ballesta: la derecha en el gatillo y la izquierda debajo, un palmo hacia la punta.
static func _ballesta_en(p: Dictionary, mano_d: Vector3, f: Vector3, sola_der: bool = false) -> void:
	var tor: float = float(p.get("torsion", 0.0))
	p["mano_der_en"] = _pecho(tor, mano_d)
	p["codo_der_hacia"] = Vector3(-1.0, -0.4, -0.6)
	p["ball_f"] = _dir(tor, f, mano_d.z)
	if not sola_der:
		p["mano_izq_en"] = _pecho(tor, mano_d + f * 6.5 + Vector3(0.0, 0.0, -1.2))
		p["codo_izq_hacia"] = Vector3(1.0, 0.0, -1.0)


# SACARLA: la derecha sube por encima del hombro derecho (donde asoma la punta), la agarra y la baja por delante;
# la izquierda la coge al final.
static func _desenvainar_ballesta(t: float) -> Dictionary:
	var fin: Dictionary = guardia_ballesta(0.0, 0)
	var p: Dictionary = {"torsion": _k(t, [[0.0, 0.0], [1.0, TOR_BALL]]),
		"agacha": _k(t, [[0.0, 0.06], [1.0, float(fin["agacha"])]]),
		"inclina": _k(t, [[0.0, 0.0], [0.4, -0.06], [1.0, float(fin["inclina"])]]),
		"paso": _k(t, [[0.0, 0.0], [1.0, float(fin["paso"])]]), "bote": 0.0,
		"brazo_izq": _k(t, [[0.0, 0.1], [0.7, 0.4], [1.0, 0.6]]),
		"sacando": -1.0 if t < 0.3 else clampf((t - 0.3) / 0.7, 0.0, 1.0)}
	var a := Vector3(-9.0, 2.0, 22.0)
	var b := Vector3(-7.5, -2.0, 38.0)
	var c := Vector3(-2.5, 3.0, 27.0)
	var mano_d: Vector3 = a.lerp(b, smoothstep(0.0, 0.45, t)) if t < 0.45 else b.lerp(c, smoothstep(0.45, 1.0, t))
	var k: float = smoothstep(0.45, 1.0, t)
	var f: Vector3 = Vector3(0.3, -0.2, 1.0).lerp(Vector3(0.12, 1.0, -0.2), k).normalized()
	_ballesta_en(p, mano_d, f, t < 0.8)
	return p


# ============================================================
#  LOS BASICOS
# ============================================================
# EL DISPARO DEL ARCO (12 marcos a 18 fps): la derecha va al CARCAJ (sobre el hombro derecho) y saca una flecha,
# la pone en la cuerda con el arco aun bajo, y se gira de lado del todo mientras sube el arco y TENSA hasta la cara;
# aguanta un instante y SUELTA en el marco 8 (0,44 s: CombatFX.IMPACTO_ANIM_MAPA lo cuenta, con el vuelo de la
# flecha encima). Despues la mano sale hacia atras y vuelve a la guardia.
const ARCO_MANO_REPOSO := Vector3(-8.1, -3.0, 21.5)   # donde cuelga la derecha en la guardia
const ARCO_CARCAJ := Vector3(0.9, -8.5, 36.5)          # la boca del carcaj, a media vuelta
const ARCO_EN_ALTO := Vector3(4.3, 19.2, 33.3)         # el brazo del arco estirado hacia el blanco
const ARCO_CARA := Vector3(-2.5, -0.5, 36.0)           # la mano que tensa, junto a la cara

static func _disparo_arco(t: float) -> Dictionary:
	var g: Dictionary = guardia_arco(0.0, 0)
	var tor: float = _k(t, [[0.0, TOR_ARCO], [0.18, 0.5], [0.38, 0.35], [0.62, TOR_TIRO], [0.85, TOR_TIRO], [1.0, TOR_ARCO]])
	var p: Dictionary = {"torsion": tor, "bote": 0.0,
		"agacha": _k(t, [[0.0, float(g["agacha"])], [0.62, 0.22], [0.85, 0.22], [1.0, float(g["agacha"])]]),
		"inclina": _k(t, [[0.0, 0.04], [0.62, -0.02], [0.8, 0.0], [1.0, 0.04]]),
		"paso": _k(t, [[0.0, float(g["paso"])], [0.62, 0.55], [0.85, 0.55], [1.0, float(g["paso"])]])}
	var mano_i: Vector3 = _p(t, [[0.0, Vector3(10.5, 11.0, 24.8)], [0.18, Vector3(6.0, 11.0, 27.0)],
		[0.38, Vector3(-1.0, 9.0, 29.0)], [0.62, ARCO_EN_ALTO], [0.85, ARCO_EN_ALTO], [1.0, Vector3(10.5, 11.0, 24.8)]])
	var mano_d: Vector3 = _p(t, [[0.0, ARCO_MANO_REPOSO], [0.18, ARCO_CARCAJ], [0.38, Vector3(-1.0, 5.5, 29.5)],
		[0.62, ARCO_CARA], [0.71, ARCO_CARA], [0.76, Vector3(-5.0, -10.0, 35.0)], [0.85, Vector3(-5.5, -9.5, 33.0)],
		[1.0, ARCO_MANO_REPOSO]])
	var apunta: Vector3 = (ARCO_EN_ALTO - ARCO_CARA).normalized()
	var f: Vector3 = _p(t, [[0.0, Vector3(0.0, 1.0, -0.45)], [0.38, Vector3(0.0, 1.0, -0.1)], [0.62, apunta],
		[0.85, apunta], [1.0, Vector3(0.0, 1.0, -0.45)]]).normalized()
	_arco_en(p, mano_i, f, _k(t, [[0.0, 0.35], [0.62, 0.12], [0.85, 0.12], [1.0, 0.35]]))
	p["mano_der_en"] = _pecho(tor, mano_d)
	p["codo_der_hacia"] = Vector3(-1.0, -0.6, 0.2)
	p["tensa"] = _k(t, [[0.0, 0.0], [0.38, 0.0], [0.62, 1.0], [0.71, 1.0], [0.72, 0.0]])
	p["flecha"] = 1.0 if t >= 0.3 and t < 0.72 else 0.0
	return p


# EL DISPARO DE LA BALLESTA (14 marcos a 18 fps): se la sube al hombro y apunta, DISPARA en el marco 4 (0,22 s) con
# un culatazo que le echa los hombros atras y la punta arriba, y RECARGA (decidido el 03/10: la recarga es lo que la
# hace lenta y tiene que verse): baja la punta, la sujeta con la izquierda, tira de la cuerda con la derecha desde el
# arco hasta la nuez y pone el virote. Vuelve a la guardia.
const BALL_HOMBRO := Vector3(-3.0, 1.5, 32.5)
const BALL_GUARDIA := Vector3(-2.5, 3.0, 27.0)

static func _disparo_ballesta(t: float) -> Dictionary:
	var g: Dictionary = guardia_ballesta(0.0, 0)
	var tor: float = TOR_BALL
	var p: Dictionary = {"torsion": tor, "bote": 0.0, "paso": float(g["paso"]),
		"agacha": _k(t, [[0.0, float(g["agacha"])], [0.23, 0.18], [0.5, 0.26], [0.85, 0.26], [1.0, float(g["agacha"])]]),
		"inclina": _k(t, [[0.0, 0.05], [0.23, 0.0], [0.31, 0.0], [0.38, -0.1], [0.5, 0.14], [0.85, 0.14], [1.0, 0.05]])}
	if t < 0.45:
		var mano_d: Vector3 = _p(t, [[0.0, BALL_GUARDIA], [0.23, BALL_HOMBRO], [0.31, BALL_HOMBRO],
			[0.38, Vector3(-3.5, -0.5, 33.5)], [0.45, Vector3(-3.0, 1.0, 31.0)]])
		var f: Vector3 = _p(t, [[0.0, Vector3(0.12, 1.0, -0.2)], [0.23, Vector3(0.05, 1.0, 0.0)], [0.31, Vector3(0.05, 1.0, 0.0)],
			[0.38, Vector3(0.05, 1.0, 0.4)], [0.45, Vector3(0.05, 1.0, 0.1)]]).normalized()
		_ballesta_en(p, mano_d, f)
		p["ball_cuerda"] = 1.0 if t < 0.3 else 0.0
		p["virote"] = 1.0 if t < 0.3 else 0.0
		return p
	# LA RECARGA: la sujeta la IZQUIERDA (ArcoSprites: 'ball_izq'), con la punta abajo y adelante.
	var f2: Vector3 = _p(t, [[0.45, Vector3(0.05, 1.0, 0.1)], [0.52, Vector3(0.1, 0.7, -1.0)], [0.88, Vector3(0.1, 0.7, -1.0)],
		[1.0, Vector3(0.12, 1.0, -0.2)]]).normalized()
	var izq: Vector3 = _p(t, [[0.45, Vector3(-3.0, 1.0, 31.0) + Vector3(0.05, 1.0, 0.1).normalized() * 6.5],
		[0.52, Vector3(1.0, 6.5, 26.0)], [0.88, Vector3(1.0, 6.5, 26.0)],
		[1.0, BALL_GUARDIA + Vector3(0.12, 1.0, -0.2).normalized() * 6.5]])
	var gatillo: Vector3 = izq - f2 * 6.5
	var arco_b: Vector3 = gatillo + f2 * ArcoSprites.CULATA_DELANTE + Vector3(0.0, 0.0, 1.5)
	var nuez: Vector3 = gatillo + f2 * ArcoSprites.NUEZ + Vector3(0.0, 0.0, 1.5)
	var tira: float = _k(t, [[0.52, 0.0], [0.6, 0.0], [0.78, 1.0]])
	var mano_d2: Vector3
	if t < 0.6:
		mano_d2 = Vector3(-3.0, 1.0, 31.0).lerp(arco_b, smoothstep(0.45, 0.6, t))
	elif t < 0.88:
		mano_d2 = arco_b.lerp(nuez, tira)
	else:
		mano_d2 = nuez.lerp(BALL_GUARDIA, smoothstep(0.88, 1.0, t))
	p["mano_izq_en"] = _pecho(tor, izq)
	p["codo_izq_hacia"] = Vector3(1.0, 0.0, -1.0)
	p["mano_der_en"] = _pecho(tor, mano_d2)
	p["codo_der_hacia"] = Vector3(-1.0, -0.4, -0.2)
	p["ball_f"] = _dir(tor, f2, izq.z)
	p["ball_izq"] = 1.0 if t < 0.97 else 0.0
	p["ball_cuerda"] = tira
	p["virote"] = 1.0 if t >= 0.84 else 0.0
	return p
