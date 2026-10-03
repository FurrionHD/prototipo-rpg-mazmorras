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
	"guardia_ballesta", "guardia_ballesta_and", "guardia_ballesta_cor", "desenvainar_ballesta"]

# EL ARCO: tres cuartos de lado, el hombro IZQUIERDO hacia el blanco. Con la torsion positiva es el izquierdo el
# que se adelanta (ver PoseJugador.proyectar).
const TOR_ARCO := 0.6
# LA BALLESTA: menos de lado, la culata junto al costado derecho.
const TOR_BALL := 0.45


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
	return {}


static func _k(t: float, keys: Array) -> float:
	return SpriteLienzo.tramos(t, keys)


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
